//! Liest Zeilen aus WoWCombatLog*.txt und fasst die Ereignisse des eigenen Charakters
//! (inkl. Begleiter) zu Kämpfen zusammen. Zustandsbehaftet, damit Datei-Stücke live verarbeitet werden können.
//!
//! Eigenheiten des echten Logs (12.1.5): Windows-Zeilenenden, Zeit wie `11/21/2026 11:03:22.1361`,
//! erweiterter Datenblock mit 19 Feldern (früher 17) – sein Ende wird am Muster PosX,PosY,MapID,Blickrichtung gesucht.

use crate::model::{Fight, FightKill, FightSpell};
use chrono::{Datelike, Local, NaiveDate, TimeZone};
use std::collections::HashMap;

/// Erhöhen, wenn sich die Auswertung ändert – die App liest dann alle Kampflogs neu ein.
pub const PARSER_VERSION: u32 = 3;
/// Pause ohne Kampfgeschehen, nach der ein Kampf als beendet gilt (Sekunden)
pub const GAP: f64 = 6.0;

/// Wo sich der eigene Charakter laut Kampflog gerade befindet (ZONE_CHANGE, ENCOUNTER_START)
#[derive(Debug, Clone, Default, PartialEq, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LiveLocation {
    /// Charakter-Schlüssel "Name-Realm", sobald im Log erkennbar
    pub char: Option<String>,
    /// Instanz-Karten-ID (bei Instanzen wie JournalInstance.map_id)
    pub instance_id: i64,
    pub name: String,
    /// 0 = offene Welt
    pub difficulty_id: i64,
    pub t: f64,
    pub encounter: Option<LiveEncounter>,
}

#[derive(Debug, Clone, Default, PartialEq, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LiveEncounter {
    pub id: i64,
    pub name: String,
    pub difficulty_id: i64,
    pub t: f64,
}

#[derive(Default)]
pub struct CombatLogParser {
    pub location: Option<LiveLocation>,
    finished: Vec<Fight>,
    pub current: Option<Fight>,
    advanced: bool,
    zone: Option<String>,
    map_id: Option<i64>,
    encounter: Option<String>,
    my_guid: Option<String>,
    my_key: Option<String>,
    last_activity: f64,
    spell_index: HashMap<String, usize>,
    target_damage: HashMap<String, i64>,
    recently_hit: HashMap<String, f64>,
}

/// "Name-Realm-EU" → "Name-Realm"
pub fn default_key(log_name: &str) -> String {
    let parts: Vec<&str> = log_name.split('-').collect();
    if parts.len() >= 3 { parts[..parts.len() - 1].join("-") } else { log_name.to_string() }
}

impl CombatLogParser {
    pub fn new() -> Self { CombatLogParser { advanced: true, ..Default::default() } }

    /// Gibt abgeschlossene Kämpfe zurück und leert die Liste.
    pub fn take_finished(&mut self) -> Vec<Fight> { std::mem::take(&mut self.finished) }

    /// Beendet einen offenen Kampf, wenn seit dem letzten Geschehen genug Zeit vergangen ist.
    pub fn close_if_idle(&mut self, now: f64) {
        if self.current.is_some() && now - self.last_activity > GAP { self.close_fight(); }
    }

    pub fn flush(&mut self) { self.close_fight(); }

    pub fn parse_line(&mut self, line: &str) {
        let line = line.trim_end_matches(['\r', '\n']);
        let Some(sep) = line.find("  ") else { return };
        let Some(time) = parse_time(&line[..sep]) else { return };
        let body = &line[sep + 2..];
        let event = body.split(',').next().unwrap_or("");

        if self.current.is_some() && time - self.last_activity > GAP { self.close_fight(); }

        match event {
            "COMBAT_LOG_VERSION" => {
                let f = fields(body);
                if let Some(i) = f.iter().position(|x| x == "ADVANCED_LOG_ENABLED") {
                    if i + 1 < f.len() { self.advanced = f[i + 1] == "1"; }
                }
            }
            "ZONE_CHANGE" => {
                let f = fields(body);
                if f.len() > 2 { self.zone = Some(f[2].clone()); }
                // ZONE_CHANGE,instanceID,"Name",difficultyID
                if let Some(id) = f.get(1).and_then(|x| x.parse().ok()) {
                    self.location = Some(LiveLocation {
                        char: self.my_key.clone(),
                        instance_id: id,
                        name: f.get(2).cloned().unwrap_or_default(),
                        difficulty_id: f.get(3).and_then(|x| x.parse().ok()).unwrap_or(0),
                        t: time,
                        encounter: None,
                    });
                }
            }
            "MAP_CHANGE" => {
                let f = fields(body);
                if let Some(m) = f.get(1).and_then(|x| x.parse().ok()) { self.map_id = Some(m); }
            }
            "ENCOUNTER_START" => {
                let f = fields(body);
                self.close_fight();
                self.encounter = f.get(2).cloned();
                // ENCOUNTER_START,encounterID,"Name",difficultyID,groupSize,instanceID
                let enc = LiveEncounter {
                    id: f.get(1).and_then(|x| x.parse().ok()).unwrap_or(0),
                    name: f.get(2).cloned().unwrap_or_default(),
                    difficulty_id: f.get(3).and_then(|x| x.parse().ok()).unwrap_or(0),
                    t: time,
                };
                let inst: Option<i64> = f.get(5).and_then(|x| x.parse().ok());
                let key = self.my_key.clone();
                match self.location.as_mut() {
                    Some(loc) if inst.is_none() || inst == Some(loc.instance_id) => loc.encounter = Some(enc),
                    _ => {
                        self.location = Some(LiveLocation {
                            char: key, instance_id: inst.unwrap_or(0), name: self.zone.clone().unwrap_or_default(),
                            difficulty_id: enc.difficulty_id, t: time, encounter: Some(enc),
                        })
                    }
                }
            }
            "ENCOUNTER_END" => {
                let f = fields(body);
                if let Some(cur) = self.current.as_mut() {
                    cur.encounter = self.encounter.clone();
                    cur.success = f.get(5).map(|x| x == "1");
                    self.last_activity = time;
                    self.close_fight();
                }
                self.encounter = None;
                if let Some(loc) = self.location.as_mut() { loc.encounter = None; }
            }
            "SWING_DAMAGE" | "RANGE_DAMAGE" | "SPELL_DAMAGE" | "SPELL_PERIODIC_DAMAGE" | "SPELL_BUILDING_DAMAGE"
            | "DAMAGE_SHIELD" | "DAMAGE_SPLIT" | "ENVIRONMENTAL_DAMAGE" => self.handle_damage(event, &fields(body), time),
            "SPELL_HEAL" | "SPELL_PERIODIC_HEAL" => self.handle_heal(&fields(body), time),
            "SPELL_ABSORBED" => self.handle_absorb(&fields(body), time),
            "UNIT_DIED" | "UNIT_DESTROYED" => {
                let f = fields(body);
                if f.len() <= 7 { return; }
                if is_my_player(&f[7]) {
                    if let Some(c) = self.current.as_mut() { c.deaths += 1; }
                }
                if let Some(hit) = self.recently_hit.remove(&f[5]) {
                    if time - hit < 120.0 {
                        let kill = FightKill { guid: f[5].clone(), npc_id: npc_id(&f[5]), name: f[6].clone(), t: time };
                        if let Some(c) = self.current.as_mut() {
                            c.kills.push(kill);
                        } else if let Some(last) = self.finished.last_mut() {
                            if time - last.end < 30.0 { last.kills.push(kill); }
                        }
                    }
                }
            }
            _ => {}
        }
    }

    fn handle_damage(&mut self, event: &str, f: &[String], time: f64) {
        if f.len() <= 9 { return; }
        let pre = if event.starts_with("SWING_") { 0 } else if event.starts_with("ENVIRONMENTAL_") { 1 } else { 3 };
        let s = self.suffix_start(f, 9 + pre);
        let Some(amount) = f.get(s).and_then(|x| x.parse::<i64>().ok()) else { return };
        let src_flags = flags(&f[3]);
        let dst_flags = flags(&f[7]);

        if is_mine(src_flags) && !is_mine(dst_flags) {
            self.note_me(f);
            self.begin(time);
            let name = if pre == 3 { f[10].clone() } else if event.starts_with("SWING") { "Nahkampf".into() } else { "Umgebung".into() };
            let crit = critical(f, s, false);
            if let Some(c) = self.current.as_mut() { c.damage += amount; }
            self.add_spell(&name, amount, 0, 0, crit);
            *self.target_damage.entry(f[6].clone()).or_default() += amount;
            if f[5].starts_with("Creature-") || f[5].starts_with("Vehicle-") {
                self.recently_hit.insert(f[5].clone(), time);
                if self.recently_hit.len() > 2000 { self.recently_hit.retain(|_, t| time - *t < 120.0); }
            }
            if self.advanced && f[9 + pre] == f[1] && is_my_player(&f[3]) { self.read_advanced(f, s); }
        } else if is_my_player(&f[7]) && !is_mine(src_flags) {
            self.note_me_as_target(f);
            self.begin(time);
            if let Some(c) = self.current.as_mut() { c.taken += amount; }
        }
    }

    fn handle_heal(&mut self, f: &[String], time: f64) {
        if f.len() <= 12 || !is_mine(flags(&f[3])) { return; }
        let s = self.suffix_start(f, 12);
        if f.len() <= s + 1 { return; }
        let Ok(amount) = f[s].parse::<i64>() else { return };
        let rest = f.len() - s;
        let over: i64 = (if rest >= 5 { &f[s + 2] } else { &f[s + 1] }).parse().unwrap_or(0);
        let effective = (amount - over).max(0);
        self.note_me(f);
        // Reine Überheilung außerhalb eines Kampfes ist kein Kampfbeginn
        if self.current.is_none() && effective == 0 { return; }
        self.begin(time);
        if let Some(c) = self.current.as_mut() { c.healing += effective; c.overheal += over; }
        let crit = critical(f, s, true);
        self.add_spell(&f[10].clone(), 0, effective, over, crit);
        if self.advanced && f[12] == f[1] && is_my_player(&f[3]) { self.read_advanced(f, s); }
    }

    fn handle_absorb(&mut self, f: &[String], time: f64) {
        // SPELL_ABSORBED, Angreifer(4), Ziel(4), [Zauber des Angreifers(3)], Schildwirker(4), Schildzauber(3), Menge, …
        if f.len() <= 16 { return; }
        let a = if looks_like_guid(&f[9]) { 9 } else { 12 };
        if f.len() <= a + 7 || !is_mine(flags(&f[a + 2])) { return; }
        let Ok(amount) = f[a + 7].parse::<i64>() else { return };
        self.note_me(f);
        if self.current.is_none() && amount <= 0 { return; }
        self.begin(time);
        if let Some(c) = self.current.as_mut() { c.healing += amount; c.absorb += amount; }
        self.add_spell(&f[a + 5].clone(), 0, amount, 0, false);
    }

    /// Index des ersten Feldes nach dem erweiterten Datenblock (Menge bei Schaden/Heilung).
    fn suffix_start(&self, f: &[String], a: usize) -> usize {
        if !self.advanced { return a; }
        let mut i = a + 10;
        while i + 4 < f.len() {
            let dec = |x: &String| x.contains('.') && x.parse::<f64>().is_ok();
            if dec(&f[i]) && dec(&f[i + 1]) && f[i + 2].parse::<i64>().is_ok() && dec(&f[i + 3]) {
                return i + 5;
            }
            i += 1;
        }
        a + 17
    }

    fn read_advanced(&mut self, f: &[String], s: usize) {
        if s < 5 || s > f.len() { return; }
        if let Ok(m) = f[s - 3].parse::<i64>() {
            if m > 0 {
                self.map_id = Some(m);
                if let Some(c) = self.current.as_mut() { c.map_id = Some(m); }
            }
        }
        if let Ok(il) = f[s - 1].parse::<f64>() {
            if il > 0.0 { if let Some(c) = self.current.as_mut() { c.item_level = Some(il); } }
        }
    }

    fn note_me(&mut self, f: &[String]) {
        if is_my_player(&f[3]) && f[1].starts_with("Player-") && self.my_guid.as_deref() != Some(&f[1]) {
            self.my_guid = Some(f[1].clone());
            self.my_key = Some(default_key(&f[2]));
            self.location_char();
        }
    }

    fn location_char(&mut self) {
        let key = self.my_key.clone();
        if let Some(loc) = self.location.as_mut() { if loc.char.is_none() { loc.char = key; } }
    }

    fn note_me_as_target(&mut self, f: &[String]) {
        if f[5].starts_with("Player-") && self.my_guid.as_deref() != Some(&f[5]) {
            self.my_guid = Some(f[5].clone());
            self.my_key = Some(default_key(&f[6]));
            self.location_char();
        }
    }

    fn begin(&mut self, time: f64) {
        if self.current.is_none() {
            self.current = Some(Fight {
                char: self.my_key.clone().unwrap_or_else(|| "?".into()),
                start: time,
                end: time,
                zone: self.zone.clone(),
                map_id: self.map_id,
                encounter: self.encounter.clone(),
                ..Default::default()
            });
            self.spell_index.clear();
            self.target_damage.clear();
        }
        let key = self.my_key.clone();
        if let Some(c) = self.current.as_mut() {
            if c.char == "?" { if let Some(k) = key { c.char = k; } }
            c.end = time;
        }
        self.last_activity = time;
    }

    fn add_spell(&mut self, name: &str, damage: i64, healing: i64, overheal: i64, crit: bool) {
        let Some(c) = self.current.as_mut() else { return };
        if let Some(&i) = self.spell_index.get(name) {
            let sp = &mut c.spells[i];
            sp.damage += damage;
            sp.healing += healing;
            sp.overheal += overheal;
            sp.hits += 1;
            if crit { sp.crits += 1; }
        } else {
            self.spell_index.insert(name.to_string(), c.spells.len());
            c.spells.push(FightSpell { name: name.into(), damage, healing, overheal, hits: 1, crits: crit as i64 });
        }
    }

    fn close_fight(&mut self) {
        let Some(mut fight) = self.current.take() else { return };
        fight.target = self.target_damage.iter().max_by_key(|(_, v)| **v).map(|(k, _)| k.clone());
        fight.spells.sort_by(|a, b| (b.damage + b.healing).cmp(&(a.damage + a.healing)));
        // Kleinstkämpfe (ein einzelner Treffer, kurze Selbstheilung) verwerfen
        let total = fight.damage + fight.healing + fight.taken;
        if fight.char == "?" || total <= 0 || (fight.end - fight.start < 2.0 && fight.encounter.is_none()) { return; }
        self.finished.push(fight);
    }
}

fn critical(f: &[String], s: usize, heal: bool) -> bool {
    // Krit-Feld: bei Heilung das letzte, bei Schaden das 8. bzw. 7. Feld nach der Menge
    if heal { return f.last().map(|x| x == "1").unwrap_or(false); }
    let rest = f.len() - s;
    let idx = if rest >= 11 { s + 7 } else { s + 6 };
    f.get(idx).map(|x| x == "1").unwrap_or(false)
}

pub fn flags(s: &str) -> u32 { u32::from_str_radix(s.trim_start_matches("0x"), 16).unwrap_or(0) }
/// Gehört zum eigenen Spieler (inkl. Begleiter, Wächter, Totems)
pub fn is_mine(flags: u32) -> bool { flags & 0x1 != 0 }
pub fn is_my_player(flag_str: &str) -> bool { let f = flags(flag_str); f & 0x1 != 0 && f & 0x400 != 0 }

/// NPC-ID aus einer GUID wie "Creature-0-1-530-1-16879-0000000001" (sechstes Feld)
pub fn npc_id(guid: &str) -> Option<i64> { guid.split('-').nth(5).and_then(|x| x.parse().ok()) }

fn looks_like_guid(s: &str) -> bool {
    ["Player-", "Creature-", "Pet-", "Vehicle-", "GameObject-"].iter().any(|p| s.starts_with(p)) || s == "0000000000000000"
}

/// Zerlegt die Felder einer Zeile (Komma-getrennt, Texte in Anführungszeichen).
pub fn fields(s: &str) -> Vec<String> {
    let mut out = Vec::with_capacity(40);
    let mut cur = String::new();
    let mut in_quotes = false;
    for ch in s.chars() {
        match ch {
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => out.push(std::mem::take(&mut cur)),
            '\r' => {}
            _ => cur.push(ch),
        }
    }
    out.push(cur);
    out
}

/// "11/21/2026 20:15:03.1234-1" oder "11/21 20:15:03.123" → Unix-Zeit (lokale Zeit)
pub fn parse_time(s: &str) -> Option<f64> {
    let mut parts = s.split(' ');
    let date = parts.next()?;
    let mut time = parts.next()?;
    let d: Vec<&str> = date.split('/').collect();
    if d.len() < 2 { return None; }
    let month: u32 = d[0].parse().ok()?;
    let day: u32 = d[1].parse().ok()?;
    let year: i32 = d.get(2).and_then(|y| y.parse().ok()).unwrap_or_else(|| Local::now().year());
    if let Some(tz) = time.rfind(['-', '+']) { time = &time[..tz]; }
    let t: Vec<&str> = time.split(':').collect();
    if t.len() != 3 { return None; }
    let h: u32 = t[0].parse().ok()?;
    let mi: u32 = t[1].parse().ok()?;
    let sec: f64 = t[2].parse().ok()?;
    let naive = NaiveDate::from_ymd_opt(year, month, day)?.and_hms_opt(h, mi, sec.trunc() as u32)?;
    let local = Local.from_local_datetime(&naive).earliest()?;
    Some(local.timestamp() as f64 + sec.fract())
}

/// Liest einen ganzen Text (z. B. Beispieldaten) und gibt alle Kämpfe zurück.
pub fn parse_all(text: &str) -> Vec<Fight> {
    let mut p = CombatLogParser::new();
    for line in text.lines() { p.parse_line(line); }
    p.flush();
    p.take_finished()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn beispiel_log() {
        let text = include_str!("../beispiel/BeispielKampflog.txt");
        let fights = parse_all(text);
        assert!(fights.len() > 20, "nur {} Kämpfe", fights.len());
        let kills: usize = fights.iter().map(|f| f.kills.len()).sum();
        assert!(kills > 20);
        assert!(fights.iter().any(|f| f.encounter.is_some()));
    }

    #[test]
    fn echte_zeile_midnight() {
        // Echte Zeile aus 12.1.5: erweiterter Block mit 19 Feldern, \r\n am Ende
        let text = "11/21/2026 11:03:22.1361  SWING_DAMAGE,Player-1-0000ABCD,\"Testheld-Antonidas-EU\",0x511,0x80000000,Creature-0-1-530-1-16879-0000000001,\"Verhungernder Hölleneber\",0x10a48,0x80000000,Player-1-0000ABCD,0000000000000000,2031,2031,81,46,39,202,0,0,3,100,100,0,-452.29,2548.68,100,1.1906,7,274,192,-1,1,0,0,0,1,nil,nil\r\n\
11/21/2026 11:03:24.4851  UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,Creature-0-1-530-1-16879-0000000001,\"Verhungernder Hölleneber\",0x10a48,0x80000000,0\r\n\
11/21/2026 11:03:25.1511  SPELL_HEAL,Player-1-0000ABCD,\"Testheld-Antonidas-EU\",0x511,0x80000000,Player-1-0000ABCD,\"Testheld-Antonidas-EU\",0x511,0x80000000,322101,\"Schadensumleitung\",0x8,Player-1-0000ABCD,0000000000000000,2031,2031,81,46,39,202,0,0,3,69,100,0,-452.29,2548.68,100,1.1798,7,540,540,457,0,nil\r\n";
        let fights = parse_all(text);
        assert_eq!(fights.len(), 1);
        let f = &fights[0];
        assert_eq!(f.char, "Testheld-Antonidas");
        assert_eq!(f.damage, 274);
        assert_eq!(f.healing, 83);
        assert_eq!(f.item_level, Some(7.0));
        assert_eq!(f.map_id, Some(100));
        assert_eq!(f.kills.len(), 1);
        assert_eq!(f.kills[0].npc_id, Some(16879));
    }

    #[test]
    fn ort_und_boss_live() {
        let mut p = CombatLogParser::new();
        p.parse_line("11/21/2026 20:00:00.0000  ZONE_CHANGE,2652,\"Das Steingewölbe\",23\r\n");
        let loc = p.location.clone().unwrap();
        assert_eq!((loc.instance_id, loc.difficulty_id, loc.name.as_str()), (2652, 23, "Das Steingewölbe"));
        p.parse_line("11/21/2026 20:03:00.0000  ENCOUNTER_START,2854,\"E.D.N.A.\",23,5,2652\r\n");
        assert_eq!(p.location.as_ref().unwrap().encounter.as_ref().map(|e| e.id), Some(2854));
        p.parse_line("11/21/2026 20:05:00.0000  ENCOUNTER_END,2854,\"E.D.N.A.\",23,5,1,120000\r\n");
        assert!(p.location.as_ref().unwrap().encounter.is_none());
        p.parse_line("11/21/2026 20:30:00.0000  ZONE_CHANGE,2552,\"Khaz Algar\",0\r\n");
        assert_eq!(p.location.as_ref().unwrap().difficulty_id, 0);
    }
}
