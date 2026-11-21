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
end

function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
  if isLogin then
    log("login", { lv = UnitLevel("player"), g = GetMoney() })
  end
  handlers.ZONE_CHANGED_NEW_AREA()
  later("kampflog", 3, ensureCombatLog)
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
  else
    print("|cffd4a017Tagebuch:|r /tb, /tb stats, /tb notiz <Text>, /tb kampflog an|aus")
  end
end
