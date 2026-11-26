//! Übernimmt SavedVariables-Dateien und Kämpfe ins Archiv.

use crate::lua::{self, Lua};
use crate::model::*;
use std::collections::HashSet;

/// Übernimmt neue Einträge aus einer SavedVariables-Datei. Gibt die Anzahl neuer Einträge zurück.
pub fn ingest_saved_variables(data: &[u8], account: Option<&str>, target: &mut Archive) -> Result<usize, lua::ParseError> {
    let vars = lua::parse_assignments(data)?;
    let Some(db) = vars.get("AzerothTagebuchDB") else { return Ok(0) };

    if let Some(maps) = db.get("maps").and_then(Lua::table) {
        for (key, v) in &maps.dict {
            if let Some(name) = lua::s(v, "n") {
                target.maps.insert(key.clone(), MapInfo { name, parent: lua::i(v, "p"), kind: lua::i(v, "ty") });
            }
        }
    }

    if let Some(w) = Storage::from_lua(db.get("warband")) {
        let acc = account.unwrap_or("?").to_string();
        if w.t >= target.warbands.get(&acc).map(|s| s.t).unwrap_or(0) {
            target.warbands.insert(acc, w);
        }
    }
    if let Some(guilds) = db.get("guilds").and_then(Lua::table) {
        for (name, gv) in &guilds.dict {
            if let Some(g) = Storage::from_lua(Some(gv)) {
                if g.t >= target.guilds.get(name).map(|s| s.t).unwrap_or(0) {
                    target.guilds.insert(name.clone(), g);
                }
            }
        }
    }

    if let Some(j) = db.get("journal") {
        let locale = lua::s(j, "loc");
        if let Some(inst) = j.get("inst").and_then(Lua::table) {
            let mut entries: Vec<(String, &Lua)> = inst.dict.iter().map(|(k, v)| (k.clone(), v)).collect();
            entries.extend(inst.array.iter().enumerate().map(|(i, v)| ((i + 1).to_string(), v)));
            for (key, v) in entries {
                if let Some(ji) = JournalInstance::from_lua(&key, v, locale.as_deref()) {
                    if ji.encounters.is_empty() { continue; }
                    let newer = target.journal.get(&key).map(|old| ji.t >= old.t || old.locale != ji.locale).unwrap_or(true);
                    if newer { target.journal.insert(key, ji); }
                }
            }
        }
    }

    let mut added = 0;
    let Some(chars) = db.get("chars").and_then(Lua::table) else { return Ok(0) };
    for (key, cv) in &chars.dict {
        let ch = target.characters.entry(key.clone()).or_insert_with(|| Character {
            key: key.clone(),
            name: lua::s(cv, "name").unwrap_or_else(|| key.clone()),
            realm: lua::s(cv, "realm").unwrap_or_default(),
            ..Default::default()
        });
        if let Some(v) = lua::s(cv, "name") { ch.name = v; }
        if let Some(v) = lua::s(cv, "realm") { ch.realm = v; }
        if let Some(v) = lua::s(cv, "class") { ch.class_token = Some(v); }
        if let Some(v) = lua::s(cv, "classLocal") { ch.class_name = Some(v); }
        if let Some(v) = lua::s(cv, "raceLocal").or_else(|| lua::s(cv, "race")) { ch.race = Some(v); }
        if let Some(v) = lua::s(cv, "faction") { ch.faction = Some(v); }
        if let Some(v) = lua::i(cv, "level") { ch.level = Some(v); }
        if let Some(v) = lua::s(cv, "spec") { ch.spec = Some(v); }
        if let Some(v) = lua::i(cv, "money") { ch.money = Some(v); }
        if let Some(v) = lua::i(cv, "specID") { ch.spec_id = Some(v); }
        if let Some(v) = lua::s(cv, "role") { ch.role = Some(v); }
        if let Some(v) = lua::s(cv, "specDesc") { ch.spec_desc = Some(v); }
        if let Some(v) = lua::i(cv, "primaryStat") { ch.primary_stat = Some(v); }
        if let Some(v) = lua::s(cv, "talentCode") { ch.talent_code = Some(v); }
        if let Some(v) = lua::f(cv, "ilvl") { ch.item_level = Some(v); }
        if let Some(v) = lua::s(cv, "guild") { ch.guild = Some(v); }
        // /played nur übernehmen, wenn es neuer ist als der gespeicherte Stand
        if let (Some(p), Some(pt)) = (lua::i(cv, "played"), lua::i(cv, "playedT")) {
            if pt >= ch.played_t.unwrap_or(0) {
                ch.played = Some(p);
                ch.played_t = Some(pt);
                ch.played_level = lua::i(cv, "playedLevel");
            }
        }
        if let Some(a) = account { ch.account = Some(a.to_string()); }
        if let Some(b) = Storage::from_lua(cv.get("bags")) {
            if b.t >= ch.bags.as_ref().map(|s| s.t).unwrap_or(0) { ch.bags = Some(b); }
        }
        if let Some(b) = Storage::from_lua(cv.get("bank")) {
            if b.t >= ch.bank.as_ref().map(|s| s.t).unwrap_or(0) { ch.bank = Some(b); }
        }
        if let Some(gear) = cv.get("gear").and_then(Lua::table) {
            let mut out = std::collections::BTreeMap::new();
            for (k, v) in &gear.dict {
                if let Some(item) = GearItem::from_lua_pub(v) { out.insert(k.clone(), item); }
            }
            // Array-Teil: Plätze 1, 2, 3 … ohne Schlüssel geschrieben
            for (idx, v) in gear.array.iter().enumerate() {
                let k = (idx + 1).to_string();
                if !out.contains_key(&k) {
                    if let Some(item) = GearItem::from_lua_pub(v) { out.insert(k, item); }
                }
            }
            ch.gear = out;
        }

        let known: HashSet<String> = ch.events.iter().map(WowEvent::dedupe_key).collect();
        let fresh: Vec<WowEvent> = cv
            .get("events")
            .and_then(Lua::table)
            .map(|t| t.items().into_iter().filter_map(WowEvent::from_lua).filter(|e| !known.contains(&e.dedupe_key())).collect())
            .unwrap_or_default();
        if !fresh.is_empty() {
            added += fresh.len();
            ch.events.extend(fresh);
            ch.events.sort_by_key(|e| e.t);
        }
    }
    Ok(added)
}

impl GearItem {
    pub fn from_lua_pub(v: &Lua) -> Option<GearItem> {
        v.table()?;
        let mut stats = std::collections::BTreeMap::new();
        if let Some(st) = v.get("st").and_then(Lua::table) {
            for (k, val) in &st.dict {
                if let Some(n) = val.int() { stats.insert(k.clone(), n); }
            }
        }
        Some(GearItem {
            item_id: lua::i(v, "id"),
            name: lua::s(v, "n"),
            link: lua::s(v, "link"),
            quality: lua::i(v, "q"),
            item_level: lua::f(v, "il"),
            icon: lua::i(v, "ic"),
            stats,
        })
    }
}

/// Ordnet "Name-Realm" aus dem Kampflog einem bekannten Charakter zu (Realmnamen stehen dort ohne Leerzeichen).
pub fn resolve_char_key(log_key: &str, archive: &Archive) -> String {
    if archive.characters.contains_key(log_key) { return log_key.to_string(); }
    fn norm(s: &str) -> String { s.to_lowercase().chars().filter(|c| c.is_alphanumeric()).collect() }
    let n = norm(log_key);
    archive.characters.keys().find(|k| norm(k) == n).cloned().unwrap_or_else(|| log_key.to_string())
}

/// Fügt Kämpfe ein (ohne Doppelte). Gibt die Anzahl neuer Kämpfe zurück.
pub fn merge_fights(fights: Vec<Fight>, target: &mut Archive) -> usize {
    let mut added = 0;
    for mut f in fights {
        f.char = resolve_char_key(&f.char, target);
        let list = target.fights.entry(f.char.clone()).or_default();
        let id = f.id();
        if list.iter().any(|x| x.id() == id) { continue; }
        list.push(f);
        list.sort_by(|a, b| a.start.partial_cmp(&b.start).unwrap_or(std::cmp::Ordering::Equal));
        added += 1;
    }
    added
}
