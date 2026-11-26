-- Azeroth-Tagebuch: protokolliert Quests, Reisen und Meilensteine pro Charakter.
-- Reines Logging in SavedVariables. Das Addon steuert nichts und automatisiert nichts.

local ADDON = ...
local VERSION = 4
local SAMPLE_SECONDS = 10      -- Abstand der Positionsproben
local MIN_MOVE = 0.004         -- Mindestbewegung (Kartenanteil) für eine neue Probe
local MAX_EVENTS = 60000       -- Sicherheitslimit pro Charakter

local f = CreateFrame("Frame")
local char, charKey, session
local lastPos = { map = nil, x = nil, y = nil, mode = nil }
local wasOnTaxi = false
local checkInstance, journalForCurrentInstance   -- weiter unten definiert

------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------
local function safe(fn, ...)
  -- alle Rückgabewerte durchreichen (GetLootSlotInfo liefert 10, GetLootSourceInfo beliebig viele)
  local res = { pcall(fn, ...) }
  if res[1] then return unpack(res, 2, table.maxn(res)) end
end

local function round(v, n)
  if type(v) ~= "number" then return nil end
  local m = 10 ^ (n or 4)
  return math.floor(v * m + 0.5) / m
end

local function mapInfo(mapID)
  if not mapID then return nil end
  local info = safe(C_Map.GetMapInfo, mapID)
  return info
end

local function currentLocation()
  local mapID = safe(C_Map.GetBestMapForUnit, "player")
  local x, y
  if mapID then
    local pos = safe(C_Map.GetPlayerMapPosition, mapID, "player")
    if pos then x, y = pos:GetXY() end
  end
  return mapID, round(x), round(y)
end

local function moveMode()
  if UnitOnTaxi and UnitOnTaxi("player") then return "taxi" end
  if IsFlying and IsFlying() then return "flug" end
  if IsSwimming and IsSwimming() then return "schwimmen" end
  if IsMounted and IsMounted() then return "reittier" end
  return "zu_fuss"
end

local function log(evType, data)
  if not char then return end
  data = data or {}
  data.t = time()
  data.e = evType
  if not data.m then
    local m, x, y = currentLocation()
    data.m, data.x, data.y = m, x, y
  end
  local ev = char.events
  if #ev >= MAX_EVENTS then table.remove(ev, 1) end
  ev[#ev + 1] = data
end

local function registerMap(mapID)
  -- Kartenname und Elternkarte merken, damit das Dashboard Zonen benennen kann
  if not mapID or AzerothTagebuchDB.maps[mapID] then return end
  local info = mapInfo(mapID)
  if info then
    AzerothTagebuchDB.maps[mapID] = { n = info.name, p = info.parentMapID, ty = info.mapType }
    registerMap(info.parentMapID)
  end
end

local function questClassification(questID)
  local c = safe(C_QuestInfoSystem.GetQuestClassification, questID)
  if c and Enum and Enum.QuestClassification then
    for k, v in pairs(Enum.QuestClassification) do
      if v == c then return k end
    end
  end
  if safe(C_QuestLog.IsWorldQuest, questID) then return "WorldQuest" end
  return c
end

local function questTitle(questID)
  return safe(C_QuestLog.GetTitleForQuestID, questID) or ("Quest " .. tostring(questID))
end

local function updateCharInfo()
  char.name = UnitName("player")
  char.realm = GetRealmName()
  char.class = select(2, UnitClass("player"))
  char.classLocal = UnitClass("player")
  char.race = select(2, UnitRace("player"))
  char.raceLocal = UnitRace("player")
  char.faction = UnitFactionGroup("player")
  char.level = UnitLevel("player")
  char.sex = UnitSex("player")
  local spec = safe(GetSpecialization)
  if spec then
    local _, specName = safe(GetSpecializationInfo, spec)
    char.spec = specName
  end
  char.money = GetMoney()
  local guild, _, _, guildRealm = safe(GetGuildInfo, "player")
  char.guild = guild and (guild .. "-" .. (guildRealm or GetRealmName())) or nil
end

------------------------------------------------------------
-- Ausrüstung (Gegenstandsstufe) und Talente
------------------------------------------------------------
local function checkItemLevel()
  if not char then return end
  local overall, equipped = safe(GetAverageItemLevel)
  if not equipped then return end
  local il = round(equipped, 1)
  if char.ilvl ~= il then
    char.ilvl = il
    log("ausr", { il = il, ilg = round(overall, 1), lv = UnitLevel("player") })
  end
end

local function checkTalents()
  if not char then return end
  local specIndex = safe(GetSpecialization)
  if not specIndex then return end
  local specID, specName, desc, _, role, primaryStat = safe(GetSpecializationInfo, specIndex)
  if not specID then return end
  char.spec, char.specID, char.role, char.specDesc, char.primaryStat = specName, specID, role, desc, primaryStat
  local code, loadout
  local configID = safe(C_ClassTalents.GetActiveConfigID)
  if configID then
    code = safe(C_Traits.GenerateImportString, configID)
    local info = safe(C_Traits.GetConfigInfo, configID)
    loadout = info and info.name
  end
  if char.specID_logged ~= specID or (code and char.talentCode ~= code) then
    char.specID_logged = specID
    char.talentCode = code or char.talentCode
    log("talente", { sid = specID, spec = specName, rolle = role, code = code, lo = loadout, lv = UnitLevel("player") })
  end
end

-- Angelegte Ausrüstung: Schnappschuss je Platz, Wechsel als Ereignis "gegenstand"
local GEAR_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19 }
local STAT_KEYS = {
  ITEM_MOD_CRIT_RATING_SHORT = "krit", ITEM_MOD_HASTE_RATING_SHORT = "tempo",
  ITEM_MOD_MASTERY_RATING_SHORT = "meist", ITEM_MOD_VERSATILITY = "viel",
  ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "bew", ITEM_MOD_INTELLECT_SHORT = "int",
  ITEM_MOD_STAMINA_SHORT = "aus",
}

local function linkName(link)
  return link and link:match("%[(.-)%]")
end

local function itemEntry(slot)
  local link = safe(GetInventoryItemLink, "player", slot)
  if not link then return nil end
  local id = tonumber(link:match("item:(%d+)"))
  local il
  if ItemLocation and C_Item and C_Item.GetCurrentItemLevel then
    local loc = safe(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
    if loc then il = safe(C_Item.GetCurrentItemLevel, loc) end
  end
  if not il then il = safe(C_Item.GetDetailedItemLevelInfo, link) end
  local stats = {}
  local raw = safe(C_Item.GetItemStats, link)
  if type(raw) == "table" then
    for k, v in pairs(raw) do
      local short = STAT_KEYS[k]
      if short then stats[short] = v end
    end
  end
  return {
    id = id, n = linkName(link), link = link,
    q = safe(GetInventoryItemQuality, "player", slot),
    il = il, ic = safe(GetInventoryItemTexture, "player", slot),
    st = stats,
  }
end

local function snapshotGear()
  if not char then return end
  local first = char.gear == nil
  char.gear = char.gear or {}
  for _, slot in ipairs(GEAR_SLOTS) do
    local new = itemEntry(slot)
    local old = char.gear[slot]
    local changed = (old and old.link) ~= (new and new.link)
    if changed then
      char.gear[slot] = new
      if not first and new then
        log("gegenstand", { slot = slot, id = new.id, n = new.n, q = new.q, il = new.il, ic = new.ic,
                            alt = old and old.n, altil = old and old.il })
      end
    end
  end
end

------------------------------------------------------------
-- Beute: was hat welcher Gegner (oder welches Vorkommen) fallen gelassen?
------------------------------------------------------------
local lootedSources = {}   -- in dieser Sitzung schon erfasste Leichen/Vorkommen

local function npcIDFromGUID(guid)
  if not guid then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" or kind == "GameObject" then return tonumber(id), kind end
end

local function nameForGUID(guid)
  for _, unit in ipairs({ "target", "mouseover", "focus" }) do
    if safe(UnitGUID, unit) == guid then return safe(UnitName, unit) end
  end
end

local function recordLoot()
  if not char then return end
  local n = safe(GetNumLootItems) or 0
  local bySource = {}
  for i = 1, n do
    local icon, name, quantity, currencyID, quality, _, _, _, _, isCoin = safe(GetLootSlotInfo, i)
    local link = safe(GetLootSlotLink, i)
    local item = {
      id = link and tonumber(link:match("item:(%d+)")), n = name or linkName(link),
      q = quality, ic = icon, cur = currencyID,
    }
    if isCoin then item.gold = true end
    local src = { safe(GetLootSourceInfo, i) }
    if #src == 0 then src = { "unbekannt", quantity } end
    for k = 1, #src, 2 do
      local guid, qty = src[k], src[k + 1]
      if guid then
        local entry = bySource[guid] or { items = {} }
        local copy = {}
        for key, v in pairs(item) do copy[key] = v end
        copy.c = qty or quantity
        entry.items[#entry.items + 1] = copy
        bySource[guid] = entry
      end
    end
  end
  for guid, entry in pairs(bySource) do
    if not lootedSources[guid] then
      lootedSources[guid] = true
      local npc, kind = npcIDFromGUID(guid)
      log("beute", { src = guid, npc = npc, art = kind, sn = nameForGUID(guid), items = entry.items,
                     z = GetZoneText() })
    end
  end
end

-- Mehrere schnelle Ereignisse (z. B. beim Umziehen) zu einem Aufruf bündeln
local pending = {}
local function later(key, delay, fn)
  if pending[key] then return end
  pending[key] = true
  C_Timer.After(delay, function() pending[key] = nil; pcall(fn) end)
end

------------------------------------------------------------
-- Lager: Taschen, Charakterbank, Kriegsmeutenbank, Gildenbank
------------------------------------------------------------
-- Jeder Inhalt wird als Schnappschuss gespeichert (nicht als Ereignis), gleiche Gegenstände
-- je Fach zusammengefasst: { t = Zeit, tabs = { { name, ic, items = { {id, n, q, ic, c, il}, … } } } }

local function addItem(list, index, info)
  if not info then return end
  local link = info.hyperlink
  local id = info.itemID or (link and tonumber(link:match("item:(%d+)")))
  local key = link or tostring(id)
  if not key then return end
  local entry = index[key]
  if entry then
    entry.c = entry.c + (info.stackCount or 1)
    return
  end
  entry = { id = id, n = info.itemName or linkName(link), q = info.quality, ic = info.iconFileID, c = info.stackCount or 1 }
  -- Gegenstandsstufe nur bei Ausrüstung
  if link then
    local _, _, _, equipLoc = safe(C_Item.GetItemInfoInstant, link)
    if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
      entry.il = safe(C_Item.GetDetailedItemLevelInfo, link)
    end
  end
  index[key] = entry
  list[#list + 1] = entry
end

local function scanBags(bagIDs)
  local items, index = {}, {}
  for _, bag in ipairs(bagIDs) do
    local slots = safe(C_Container.GetContainerNumSlots, bag) or 0
    for slot = 1, slots do
      addItem(items, index, safe(C_Container.GetContainerItemInfo, bag, slot))
    end
  end
  return items
end

-- Taschen-IDs der Charakter- bzw. Kriegsmeutenbank (Namen ändern sich zwischen Versionen, daher suchen)
local function bankBagIDs(prefix)
  local ids = {}
  if Enum and Enum.BagIndex then
    for name, id in pairs(Enum.BagIndex) do
      if type(name) == "string" and name:find("^" .. prefix) then ids[#ids + 1] = id end
    end
  end
  table.sort(ids)
  return ids
end

local function bankTabs(bankType, prefix)
  local tabs = {}
  local data = (C_Bank and C_Bank.FetchPurchasedBankTabData and bankType) and safe(C_Bank.FetchPurchasedBankTabData, bankType)
  if type(data) == "table" and #data > 0 then
    for _, tab in ipairs(data) do
      tabs[#tabs + 1] = { name = tab.name, ic = tab.icon, items = scanBags({ tab.ID }) }
    end
  else
    for i, id in ipairs(bankBagIDs(prefix)) do
      tabs[#tabs + 1] = { name = "Fach " .. i, items = scanBags({ id }) }
    end
  end
  return tabs
end

local function snapshotBags()
  if not char then return end
  local ids = {}
  for name, id in pairs(Enum and Enum.BagIndex or {}) do
    if name == "Backpack" or name:find("^Bag_%d") or name == "ReagentBag" then ids[#ids + 1] = id end
  end
  if #ids == 0 then ids = { 0, 1, 2, 3, 4, 5 } end
  table.sort(ids)
  char.bags = { t = time(), tabs = { { name = "Taschen", items = scanBags(ids) } } }
end

local bankOpen = false
local function snapshotBank()
  if not char or not bankOpen then return end
  local charType = Enum and Enum.BankType and Enum.BankType.Character
  local accType = Enum and Enum.BankType and Enum.BankType.Account
  local tabs = bankTabs(charType, "CharacterBankTab")
  if #tabs == 0 then
    -- ältere Bankform: eine große Bank plus Banktaschen
    local ids = { -1 }
    for _, id in ipairs(bankBagIDs("BankBag")) do ids[#ids + 1] = id end
    tabs = { { name = "Bank", items = scanBags(ids) } }
  end
  local total = 0
  for _, t in ipairs(tabs) do total = total + #t.items end
  if total == 0 and char.bank then return end   -- Bank noch nicht geladen: alten Stand behalten
  char.bank = { t = time(), tabs = tabs }
  local warband = bankTabs(accType, "AccountBankTab")
  if #warband > 0 then
    AzerothTagebuchDB.warband = {
      t = time(), tabs = warband,
      g = accType and safe(C_Bank.FetchDepositedMoney, accType),
    }
  end
end

local function guildKey()
  local guild, _, _, realm = safe(GetGuildInfo, "player")
  if not guild then return nil end
  return guild .. "-" .. (realm or GetRealmName())
end

local function snapshotGuildBank()
  local key = guildKey()
  if not key then return end
  local tabs = {}
  local n = safe(GetNumGuildBankTabs) or 0
  for tab = 1, n do
    local name, icon, viewable = safe(GetGuildBankTabInfo, tab)
    if viewable then
      local items, index = {}, {}
      for slot = 1, 98 do
        local link = safe(GetGuildBankItemLink, tab, slot)
        if link then
          local icon2, count, _, _, quality = safe(GetGuildBankItemInfo, tab, slot)
          addItem(items, index, { hyperlink = link, stackCount = count, quality = quality, iconFileID = icon2 })
        end
      end
      tabs[#tabs + 1] = { name = name, ic = icon, items = items }
    end
  end
  AzerothTagebuchDB.guilds = AzerothTagebuchDB.guilds or {}
  local old = AzerothTagebuchDB.guilds[key]
  -- leere Ergebnisse (Fächer noch nicht geladen) überschreiben keinen alten Stand
  local count = 0
  for _, t in ipairs(tabs) do count = count + #t.items end
  if count == 0 and old then return end
  AzerothTagebuchDB.guilds[key] = { t = time(), tabs = tabs, g = safe(GetGuildBankMoney), by = charKey }
end

------------------------------------------------------------
-- Kampflog (für Kampf- und Heilstatistiken in der App)
------------------------------------------------------------
-- Das Addon schaltet nur das offizielle Kampflog von WoW ein. Die App liest die Datei
-- außerhalb des Spiels. Abschaltbar mit /tb kampflog aus.
local function ensureCombatLog()
  local db = AzerothTagebuchDB
  if db.kampflog == false then return end
  if not safe(LoggingCombat) then
    safe(LoggingCombat, true)
  end
  if safe(GetCVar, "advancedCombatLogging") ~= "1" then
    safe(SetCVar, "advancedCombatLogging", "1")
  end
end

------------------------------------------------------------
-- Positionsproben (Reisewege)
------------------------------------------------------------
local function samplePosition()
  if not char then return end
  local mapID, x, y = currentLocation()
  local mode = moveMode()

  -- Flugmeister-Start/-Ende
  local onTaxi = mode == "taxi"
  if onTaxi ~= wasOnTaxi then
    log(onTaxi and "taxi_start" or "taxi_ende", { m = mapID, x = x, y = y })
    wasOnTaxi = onTaxi
  end

  if not mapID or not x then return end
  local moved = (lastPos.map ~= mapID) or (lastPos.mode ~= mode)
    or not lastPos.x
    or math.abs(x - lastPos.x) > MIN_MOVE or math.abs(y - lastPos.y) > MIN_MOVE
  if moved then
    registerMap(mapID)
    log("pos", { m = mapID, x = x, y = y, mo = mode })
    lastPos.map, lastPos.x, lastPos.y, lastPos.mode = mapID, x, y, mode
  end
end

------------------------------------------------------------
-- Instanzen und Tiefen: Betreten, Bosse, Abschluss, Verlassen
------------------------------------------------------------
local DELVE_DIFFICULTY = 208
local encounterStart = {}

local function delveTier()
  -- Stufe der Tiefe, soweit der Client sie verrät (sonst nil)
  local tier = tonumber(safe(GetCVar, "lastSelectedDelvesTier") or "")
  return tier
end

local function instanceData()
  local iname, instType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  local d = { inst = iname, it = instType, did = difficultyID, diff = difficultyName, iid = instanceID,
              lv = UnitLevel("player"), grp = safe(GetNumGroupMembers) or 0 }
  local _, avg = safe(GetAverageItemLevel)
  d.il = round(avg, 1)
  if difficultyID == DELVE_DIFFICULTY then
    d.it = "delve"
    d.tier = delveTier()
  end
  if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
    local level = safe(C_ChallengeMode.GetActiveKeystoneInfo)
    if level and level > 0 then d.ml = level end
  end
  return d
end

checkInstance = function()
  if not char then return end
  local inInstance = IsInInstance()
  local cur = char.curInst
  if inInstance then
    local _, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if cur and cur.iid == instanceID and cur.did == difficultyID then return end   -- /reload oder Unterzone
    if cur then log("inst_ab", { iid = cur.iid, inst = cur.inst, dauer = time() - (cur.t or time()) }) end
    local d = instanceData()
    log("inst_an", d)
    char.curInst = { iid = d.iid, did = d.did, inst = d.inst, t = time() }
    later("journal_inst", 4, journalForCurrentInstance)
    later("journal_inst2", 25, journalForCurrentInstance)
  elseif cur then
    log("inst_ab", { iid = cur.iid, inst = cur.inst, dauer = time() - (cur.t or time()) })
    char.curInst = nil
  end
end

local function instanceDone(kind, extra)
  if not char or not char.curInst or char.curInst.fertig then return end
  local d = { iid = char.curInst.iid, inst = char.curInst.inst, art = kind,
              dauer = time() - (char.curInst.t or time()) }
  for k, v in pairs(extra or {}) do d[k] = v end
  log("inst_fertig", d)
  char.curInst.fertig = true
end

------------------------------------------------------------
-- Dungeonkompendium: Bosse und Fähigkeiten der aktuellen Saison
-- (für den Boss-Reiter der App; nur Lesen der Journal-Texte, außerhalb des Kampfes)
------------------------------------------------------------
local JOURNAL_VERSION = 1
local journalJob          -- laufender Export (Coroutine)

local function sectionFlags(sectionID)
  local flags = C_EncounterJournal and C_EncounterJournal.GetSectionIconFlags and safe(C_EncounterJournal.GetSectionIconFlags, sectionID)
  if type(flags) ~= "table" or #flags == 0 then return nil end
  local out = {}
  for _, v in ipairs(flags) do out[#out + 1] = v end
  return out
end

-- Abschnitte eines Bosses als flache Liste mit Tiefe (lv); Überblick und Fähigkeiten in Journal-Reihenfolge
local function encounterSections(rootID)
  local out, stack, guard = {}, {}, 0
  local function push(id, depth) if id and id > 0 then stack[#stack + 1] = { id, depth } end end
  -- Geschwister rückwärts auf den Stapel, damit sie in der richtigen Reihenfolge herauskommen
  local function pushChain(firstID, depth)
    local chain, id = {}, firstID
    while id and id > 0 and #chain < 200 do
      chain[#chain + 1] = id
      local info = safe(C_EncounterJournal.GetSectionInfo, id)
      id = info and info.siblingSectionID
    end
    for i = #chain, 1, -1 do push(chain[i], depth) end
  end
  pushChain(rootID, 0)
  while #stack > 0 and guard < 600 do
    guard = guard + 1
    local top = table.remove(stack)
    local info = safe(C_EncounterJournal.GetSectionInfo, top[1])
    if info then
      out[#out + 1] = {
        id = top[1], lv = top[2], t = info.title, d = info.description, ht = info.headerType,
        ic = (info.abilityIcon and info.abilityIcon > 0) and info.abilityIcon or nil,
        sp = (info.spellID and info.spellID > 0) and info.spellID or nil,
        fl = sectionFlags(top[1]), fd = info.filteredByDifficulty and 1 or nil,
      }
      if info.firstChildSectionID and info.firstChildSectionID > 0 then pushChain(info.firstChildSectionID, top[2] + 1) end
    end
  end
  return out
end

-- Das Kompendium liefert die Bosse einer Instanz nur, wenn ihre Erweiterung ausgewählt ist
local function selectTierFor(jiid)
  local n = safe(EJ_GetNumTiers) or 0
  for tier = n, 1, -1 do
    safe(EJ_SelectTier, tier)
    for _, raid in ipairs({ false, true }) do
      for i = 1, 80 do
        local id = safe(EJ_GetInstanceByIndex, i, raid)
        if not id then break end
        if id == jiid then return tier, raid end
      end
    end
  end
end

-- höchste gültige Schwierigkeit: zeigt alle Fähigkeiten, Heroisch/Mythisch-Markierungen stehen in den Flags
-- (alte Schlachtzüge kennen nur 40 Spieler / 10 / 25, alte Dungeons nur Normal/Heroisch)
local RAID_DIFFS = { 16, 15, 14, 9, 6, 5, 4, 3, 17 }
local DUNGEON_DIFFS = { 23, 2, 1, 8, 24 }

local function bestDifficulty(isRaid)
  local list = isRaid and RAID_DIFFS or DUNGEON_DIFFS
  if not EJ_IsValidInstanceDifficulty then return list[1] end
  for _, d in ipairs(list) do
    if safe(EJ_IsValidInstanceDifficulty, d) then return d end
  end
  return list[1]
end

local function exportInstance(db, jiid, isRaid)
  local tier, raid = selectTierFor(jiid)
  if raid ~= nil then isRaid = raid end
  safe(EJ_SelectInstance, jiid)
  local diff = bestDifficulty(isRaid)
  safe(EJ_SetDifficulty, diff)
  local name, desc, _, _, _, _, areaMap, _, _, mapID = safe(EJ_GetInstanceInfo, jiid)
  local inst = { n = name, d = desc, raid = isRaid and 1 or nil, area = areaMap, map = mapID, did = diff, t = time(), enc = {} }
  for i = 1, 30 do
    -- falls zwischen zwei Schritten etwas anderes ausgewählt wurde
    if tier then safe(EJ_SelectTier, tier) end
    safe(EJ_SelectInstance, jiid)
    safe(EJ_SetDifficulty, diff)
    local ename, edesc, jeid, rootID, _, _, deid = safe(EJ_GetEncounterInfoByIndex, i, jiid)
    if not ename then break end
    inst.enc[#inst.enc + 1] = { id = jeid, deid = deid, n = ename, d = edesc, s = encounterSections(rootID) }
    coroutine.yield()
  end
  -- ohne Bosse nichts speichern, damit es beim nächsten Betreten erneut versucht wird
  if #inst.enc > 0 then db.journal.inst[jiid] = inst else db.journal.inst[jiid] = nil end
end

local function haveJournal(jiid)
  local db = AzerothTagebuchDB
  local e = db.journal and db.journal.inst and db.journal.inst[jiid]
  return e and e.enc and #e.enc > 0
end

local function journalWork(onlyJiid)
  local db = AzerothTagebuchDB
  local build = select(4, GetBuildInfo())
  if not db.journal or db.journal.v ~= JOURNAL_VERSION or db.journal.loc ~= GetLocale() or db.journal.build ~= build then
    db.journal = { v = JOURNAL_VERSION, loc = GetLocale(), build = build, inst = {} }
  end
  local todo = {}
  if onlyJiid then
    todo[1] = { onlyJiid, select(2, IsInInstance()) == "raid" }
  else
    -- aktuelle Erweiterung: Dungeons und Schlachtzüge
    safe(EJ_SelectTier, safe(EJ_GetNumTiers) or 1)
    for _, raid in ipairs({ false, true }) do
      for i = 1, 40 do
        local jiid = safe(EJ_GetInstanceByIndex, i, raid)
        if not jiid then break end
        todo[#todo + 1] = { jiid, raid }
      end
    end
  end
  for _, job in ipairs(todo) do
    if not haveJournal(job[1]) then exportInstance(db, job[1], job[2]) end
  end
end

local pendingJiid      -- Instanz, die nach dem laufenden Export noch dran ist

local function runJournal(onlyJiid)
  if not EJ_GetEncounterInfoByIndex or not C_EncounterJournal then return end
  if journalJob then
    if onlyJiid then pendingJiid = onlyJiid end
    return
  end
  journalJob = coroutine.create(journalWork)
  local first, ticker = true, nil
  ticker = C_Timer.NewTicker(0.2, function()
    -- nicht im Kampf und nicht, während der Spieler selbst im Kompendium blättert
    if InCombatLockdown() or (EncounterJournal and EncounterJournal:IsShown()) then return end
    local ok = coroutine.resume(journalJob, first and onlyJiid or nil)
    first = false
    if not ok or coroutine.status(journalJob) == "dead" then
      ticker:Cancel()
      journalJob = nil
      if pendingJiid then
        local nextJiid = pendingJiid
        pendingJiid = nil
        if not haveJournal(nextJiid) then runJournal(nextJiid) end
      end
    end
  end)
end

journalForCurrentInstance = function(force)
  if not IsInInstance() or not EJ_GetInstanceForMap then return end
  local mapID = currentLocation()
  local jiid = mapID and safe(EJ_GetInstanceForMap, mapID)
  if not jiid or jiid <= 0 then return end
  if force and AzerothTagebuchDB.journal and AzerothTagebuchDB.journal.inst then AzerothTagebuchDB.journal.inst[jiid] = nil end
  if not haveJournal(jiid) then runJournal(jiid) end
  return jiid
end

------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------
local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= ADDON then return end
  AzerothTagebuchDB = AzerothTagebuchDB or {}
  local db = AzerothTagebuchDB
  db.version = VERSION
  db.chars = db.chars or {}
  db.maps = db.maps or {}
  db.locale = GetLocale()
end

function handlers.PLAYER_LOGIN()
  charKey = UnitName("player") .. "-" .. GetRealmName()
  local db = AzerothTagebuchDB
  db.chars[charKey] = db.chars[charKey] or { events = {}, created = time() }
  char = db.chars[charKey]
  updateCharInfo()
  session = { start = time(), money = GetMoney(), level = UnitLevel("player") }
  C_Timer.NewTicker(SAMPLE_SECONDS, samplePosition)
  later("ausr", 5, checkItemLevel)
  later("talente", 5, checkTalents)
  later("gear", 6, snapshotGear)
  later("taschen", 8, snapshotBags)
  later("journal", 15, function() runJournal() end)
end

function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
  if isLogin then
    log("login", { lv = UnitLevel("player"), g = GetMoney() })
  end
  handlers.ZONE_CHANGED_NEW_AREA()
  later("kampflog", 3, ensureCombatLog)
  later("journal_inst", 6, journalForCurrentInstance)
end

function handlers.ZONE_CHANGED_NEW_AREA()
  if not char then return end
  local mapID = currentLocation()
  registerMap(mapID)
  local inInstance, instType = IsInInstance()
  local data = { z = GetZoneText(), sz = GetSubZoneText() }
  if inInstance then
    local iname, _, difficultyID, difficultyName = GetInstanceInfo()
    data.inst = iname
    data.it = instType
    data.diff = difficultyName
  end
  log("zone", data)
  pcall(checkInstance)
end

function handlers.QUEST_ACCEPTED(questID)
  if type(questID) ~= "number" then return end
  log("quest_an", { q = questID, n = questTitle(questID), c = questClassification(questID), z = GetZoneText() })
end

function handlers.QUEST_TURNED_IN(questID, xp, money)
  log("quest_ab", {
    q = questID, n = questTitle(questID), c = questClassification(questID),
    xp = xp, g = money, z = GetZoneText(), lv = UnitLevel("player"),
  })
end

function handlers.QUEST_REMOVED(questID)
  -- Wird auch beim Abgeben gefeuert; das Dashboard gleicht das mit quest_ab ab.
  if type(questID) ~= "number" then return end
  C_Timer.After(1, function()
    if not safe(C_QuestLog.IsQuestFlaggedCompleted, questID) then
      log("quest_weg", { q = questID })
    end
  end)
end

function handlers.PLAYER_LEVEL_UP(level)
  log("level", { lv = level })
  if char then char.level = level end
  later("ausr", 3, checkItemLevel)
end

function handlers.PLAYER_EQUIPMENT_CHANGED()
  later("ausr", 2, checkItemLevel)
  later("gear", 2, snapshotGear)
end

function handlers.LOOT_READY()
  pcall(recordLoot)
end

function handlers.BANKFRAME_OPENED()
  bankOpen = true
  later("bank", 1, snapshotBank)
end

function handlers.BANKFRAME_CLOSED()
  -- nach dem Schließen liefert WoW den Bankinhalt nicht mehr – daher hier nur die Taschen
  bankOpen = false
  pcall(snapshotBags)
end

-- Neuere Clients melden Bank und Gildenbank über den Interaktions-Manager
function handlers.PLAYER_INTERACTION_MANAGER_FRAME_SHOW(kind)
  local T = Enum and Enum.PlayerInteractionType
  if not T then return end
  if kind == T.Banker or kind == T.AccountBanker or kind == T.CharacterBanker then
    handlers.BANKFRAME_OPENED()
  elseif kind == T.GuildBanker then
    handlers.GUILDBANKFRAME_OPENED()
  end
end

function handlers.BAG_UPDATE_DELAYED()
  if bankOpen then later("bank", 2, snapshotBank) end
end

function handlers.GUILDBANKFRAME_OPENED()
  -- Fächer beim Server anfragen, danach kommt GUILDBANKBAGSLOTS_CHANGED
  for tab = 1, (safe(GetNumGuildBankTabs) or 0) do safe(QueryGuildBankTab, tab) end
  later("gildenbank", 3, snapshotGuildBank)
end

function handlers.GUILDBANKBAGSLOTS_CHANGED()
  later("gildenbank", 2, snapshotGuildBank)
end

function handlers.GUILDBANKFRAME_CLOSED()
  pcall(snapshotGuildBank)
end

function handlers.PLAYER_SPECIALIZATION_CHANGED(unit)
  if unit and unit ~= "player" then return end
  later("talente", 2, checkTalents)
end

function handlers.TRAIT_CONFIG_UPDATED()
  later("talente", 2, checkTalents)
end

function handlers.ENCOUNTER_START(encounterID)
  encounterStart[encounterID] = time()
end

local encounterNames = {}

function handlers.ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
  encounterNames[encounterID] = encounterName
  local started = encounterStart[encounterID]
  encounterStart[encounterID] = nil
  log("boss", { eid = encounterID, n = encounterName, did = difficultyID, grp = groupSize,
                ok = (success == 1 or success == true) and 1 or 0,
                dauer = started and (time() - started) or nil,
                iid = char and char.curInst and char.curInst.iid, inst = char and char.curInst and char.curInst.inst })
end

-- Persönliche Beute von Bossen landet direkt in den Taschen (kein Beutefenster).
-- Alles, was kurz nacheinander für denselben Boss kommt, wird zu einem Beute-Eintrag gebündelt.
local encounterLoot = {}

function handlers.ENCOUNTER_LOOT_RECEIVED(encounterID, itemID, itemLink, quantity, playerName)
  if not char or not encounterID then return end
  local me = safe(UnitName, "player")
  if playerName and me and Ambiguate(playerName, "short") ~= me then return end
  local id = itemID or (itemLink and tonumber(itemLink:match("item:(%d+)")))
  local _, _, _, _, icon = safe(C_Item.GetItemInfoInstant, id or itemLink)
  local entry = encounterLoot[encounterID]
  if not entry then
    entry = { t = time(), items = {} }
    encounterLoot[encounterID] = entry
  end
  entry.items[#entry.items + 1] = {
    id = id, n = linkName(itemLink), c = quantity or 1, ic = icon,
    q = id and safe(C_Item.GetItemQualityByID, id),
  }
  later("bossbeute" .. encounterID, 3, function()
    local e = encounterLoot[encounterID]
    encounterLoot[encounterID] = nil
    if not e or #e.items == 0 then return end
    -- Encounter 0 = persönliche Beute eines normalen Gegners (die App ordnet sie dem letzten Kill zu)
    local boss = encounterID ~= 0
    log("beute", { src = "Encounter-" .. encounterID .. "-" .. e.t, art = boss and "Boss" or nil, eid = boss and encounterID or nil,
                   sn = boss and encounterNames[encounterID] or nil, items = e.items, z = GetZoneText() })
  end)
end

function handlers.SCENARIO_COMPLETED()
  -- Tiefen und Szenarien
  instanceDone("szenario")
end

function handlers.CHALLENGE_MODE_COMPLETED()
  local extra = {}
  if C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo then
    local info = safe(C_ChallengeMode.GetChallengeCompletionInfo)
    if type(info) == "table" then
      extra.ml = info.level
      extra.zeit = info.time and math.floor(info.time / 1000)
      extra.imzeit = info.onTime and 1 or 0
    end
  end
  instanceDone("mythisch_plus", extra)
end

function handlers.LFG_COMPLETION_REWARD()
  instanceDone("dungeonbrowser")
end

function handlers.ACHIEVEMENT_EARNED(achID)
  local _, name, points = safe(GetAchievementInfo, achID)
  log("erfolg", { a = achID, n = name, p = points })
end

function handlers.PLAYER_DEAD()
  log("tod", { z = GetZoneText(), sz = GetSubZoneText() })
end

function handlers.PLAYER_LOGOUT()
  if not char then return end
  updateCharInfo()
  pcall(snapshotGear)
  pcall(snapshotBags)
  local s = session or {}
  log("logout", { dauer = time() - (s.start or time()), g = GetMoney(), dg = GetMoney() - (s.money or GetMoney()) })
end

f:SetScript("OnEvent", function(_, event, ...)
  local h = handlers[event]
  if h then pcall(h, ...) end
end)
-- pcall: unbekannte Ereignisse (andere Spielversion) dürfen das Addon nicht stoppen
for ev in pairs(handlers) do pcall(f.RegisterEvent, f, ev) end

------------------------------------------------------------
-- Slash-Befehle: /tagebuch
------------------------------------------------------------
SLASH_AZEROTHTAGEBUCH1 = "/tagebuch"
SLASH_AZEROTHTAGEBUCH2 = "/tb"
SlashCmdList.AZEROTHTAGEBUCH = function(msg)
  msg = msg or ""
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "kampflog" then
    local on = rest:lower() ~= "aus"
    AzerothTagebuchDB.kampflog = on
    if on then ensureCombatLog() else safe(LoggingCombat, false) end
    print("|cffd4a017Tagebuch:|r Kampflog " .. (on and "eingeschaltet" or "ausgeschaltet") .. ".")
  elseif cmd == "bosse" then
    if not IsInInstance() then
      print("|cffd4a017Tagebuch:|r Betritt zuerst eine Instanz – dann liest /tb bosse ihre Bosse aus dem Dungeonkompendium.")
    elseif journalForCurrentInstance(true) then
      print("|cffd4a017Tagebuch:|r Bosse werden ausgelesen. Danach /reload, damit die App sie sieht.")
    else
      print("|cffd4a017Tagebuch:|r Für diese Instanz gibt es keinen Eintrag im Dungeonkompendium.")
    end
  elseif cmd == "notiz" and rest ~= "" then
    log("notiz", { txt = rest, z = GetZoneText() })
    print("|cffd4a017Tagebuch:|r Notiz gespeichert.")
  elseif cmd == "stats" or cmd == "" then
    local q, lv, km = 0, 0, 0
    for _, e in ipairs(char.events) do
      if e.e == "quest_ab" then q = q + 1 elseif e.e == "level" then lv = lv + 1 end
    end
    print(("|cffd4a017Tagebuch|r %s: %d Quests abgegeben, %d Level-ups, %d Einträge."):format(charKey, q, lv, #char.events))
    print("  /tb notiz <Text>  – eigene Notiz fürs Tagebuch")
    print("  /tb kampflog an|aus  – Kampflog für die Kampfstatistik der App")
    print("  /tb bosse  – Bosse der aktuellen Instanz für die App auslesen")
  else
    print("|cffd4a017Tagebuch:|r /tb, /tb stats, /tb notiz <Text>, /tb kampflog an|aus, /tb bosse")
  end
end
