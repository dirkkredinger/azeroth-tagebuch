//! Datenmodell des Tagebuchs. Wird als JSON gespeichert und an die Oberfläche gegeben.

use crate::lua::{self, Lua};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Ein Eintrag aus dem Addon. Kurze Feldnamen wie in der SavedVariables-Datei.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct WowEvent {
    pub t: i64,
    pub e: String,
    #[serde(skip_serializing_if = "Option::is_none")] pub m: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub x: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub y: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub mo: Option<String>,
    /// Quest-ID
    #[serde(skip_serializing_if = "Option::is_none")] pub q: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub n: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub c: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub z: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub sz: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub xp: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub g: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub lv: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub inst: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub it: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub diff: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub a: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub p: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub txt: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub dauer: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub dg: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub il: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub ilg: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub sid: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub spec: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub rolle: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub lo: Option<String>,
    // Ausrüstungswechsel
    #[serde(skip_serializing_if = "Option::is_none")] pub slot: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none", rename = "itemId")] pub item_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub quality: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub ic: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub alt: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub altil: Option<f64>,
    // Beute
    #[serde(skip_serializing_if = "Option::is_none")] pub src: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub npc: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub art: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub sn: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub items: Option<Vec<LootItem>>,
}

impl WowEvent {
    pub fn from_lua(v: &Lua) -> Option<WowEvent> {
        let t = lua::i(v, "t")?;
        let e = lua::s(v, "e")?;
        let mut ev = WowEvent {
            t,
            e,
            m: lua::i(v, "m"),
            x: lua::f(v, "x"),
            y: lua::f(v, "y"),
            mo: lua::s(v, "mo"),
            q: lua::i(v, "q"),
            n: lua::s(v, "n"),
            c: lua::s(v, "c"),
            z: lua::s(v, "z"),
            sz: lua::s(v, "sz"),
            xp: lua::i(v, "xp"),
            g: lua::i(v, "g"),
            lv: lua::i(v, "lv"),
            inst: lua::s(v, "inst"),
            it: lua::s(v, "it"),
            diff: lua::s(v, "diff"),
            a: lua::i(v, "a"),
            p: lua::i(v, "p"),
            txt: lua::s(v, "txt"),
            dauer: lua::i(v, "dauer"),
            dg: lua::i(v, "dg"),
            il: lua::f(v, "il"),
            ilg: lua::f(v, "ilg"),
            sid: lua::i(v, "sid"),
            spec: lua::s(v, "spec"),
            rolle: lua::s(v, "rolle"),
            code: lua::s(v, "code"),
            lo: lua::s(v, "lo"),
            slot: lua::i(v, "slot"),
            item_id: lua::i(v, "id"),
            quality: None,
            ic: lua::i(v, "ic"),
            alt: lua::s(v, "alt"),
            altil: lua::f(v, "altil"),
            src: lua::s(v, "src"),
            npc: lua::i(v, "npc"),
            art: lua::s(v, "art"),
            sn: lua::s(v, "sn"),
            items: v.get("items").and_then(Lua::table).map(|t| t.items().into_iter().filter_map(LootItem::from_lua).collect()),
        };
        if ev.e == "gegenstand" {
            // dort steht q für die Qualität, nicht für eine Quest
            ev.quality = ev.q.take();
        }
        Some(ev)
    }

    /// Schlüssel zum Zusammenführen: gleiche Einträge aus verschiedenen Dateistand-Versionen nur einmal
    pub fn dedupe_key(&self) -> String {
        fn o<T: std::fmt::Display>(v: &Option<T>, d: &str) -> String {
            v.as_ref().map(|x| x.to_string()).unwrap_or_else(|| d.to_string())
        }
        format!(
            "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
            self.t, self.e, o(&self.q, "0"), o(&self.a, "0"), o(&self.m, "0"), o(&self.x, "-1"), o(&self.y, "-1"),
            o(&self.txt, ""), o(&self.code, ""), o(&self.il, "0"), o(&self.src, ""), o(&self.slot, "0"), o(&self.item_id, "0")
        )
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct LootItem {
    #[serde(skip_serializing_if = "Option::is_none")] pub item_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")] pub quality: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub icon: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub currency: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")] pub gold: Option<bool>,
}

impl LootItem {
    fn from_lua(v: &Lua) -> Option<LootItem> {
        v.table()?;
        Some(LootItem {
            item_id: lua::i(v, "id"),
            name: lua::s(v, "n"),
            quality: lua::i(v, "q"),
            icon: lua::i(v, "ic"),
            count: lua::i(v, "c"),
            currency: lua::i(v, "cur"),
            gold: v.get("gold").and_then(Lua::bool),
        })
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct GearItem {
    pub item_id: Option<i64>,
    pub name: Option<String>,
    pub link: Option<String>,
    pub quality: Option<i64>,
    pub item_level: Option<f64>,
    pub icon: Option<i64>,
    pub stats: BTreeMap<String, i64>,
}

/// Inhalt eines Lagers (Taschen, Bank, Kriegsmeutenbank, Gildenbank) zu einem Zeitpunkt
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct Storage {
    pub t: i64,
    pub tabs: Vec<StorageTab>,
    pub gold: Option<i64>,
    pub seen_by: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct StorageTab {
    pub name: String,
    pub icon: Option<i64>,
    pub items: Vec<StoredItem>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct StoredItem {
    pub item_id: Option<i64>,
    pub name: Option<String>,
    pub quality: Option<i64>,
    pub icon: Option<i64>,
    pub count: i64,
    pub item_level: Option<f64>,
}

impl Storage {
    pub fn from_lua(v: Option<&Lua>) -> Option<Storage> {
        let v = v?;
        let t = lua::i(v, "t")?;
        let tabs = v
            .get("tabs")
            .and_then(Lua::table)
            .map(|t| {
                t.items()
                    .into_iter()
                    .enumerate()
                    .map(|(idx, tab)| StorageTab {
                        name: lua::s(tab, "name").unwrap_or_else(|| format!("Fach {}", idx + 1)),
                        icon: lua::i(tab, "ic"),
                        items: tab
                            .get("items")
                            .and_then(Lua::table)
                            .map(|it| {
                                it.items()
                                    .into_iter()
                                    .map(|x| StoredItem {
                                        item_id: lua::i(x, "id"),
                                        name: lua::s(x, "n"),
                                        quality: lua::i(x, "q"),
                                        icon: lua::i(x, "ic"),
                                        count: lua::i(x, "c").unwrap_or(1),
                                        item_level: lua::f(x, "il"),
                                    })
                                    .collect()
                            })
                            .unwrap_or_default(),
                    })
                    .collect()
            })
            .unwrap_or_default();
        Some(Storage { t, tabs, gold: lua::i(v, "g"), seen_by: lua::s(v, "by") })
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct Character {
    pub key: String,
    pub name: String,
    pub realm: String,
    pub class_token: Option<String>,
    pub class_name: Option<String>,
    pub race: Option<String>,
    pub faction: Option<String>,
    pub level: Option<i64>,
    pub spec: Option<String>,
    pub money: Option<i64>,
    pub account: Option<String>,
    pub spec_id: Option<i64>,
    pub role: Option<String>,
    pub spec_desc: Option<String>,
    pub primary_stat: Option<i64>,
    pub talent_code: Option<String>,
    pub item_level: Option<f64>,
    pub guild: Option<String>,
    /// Angelegte Ausrüstung je Platz ("1" = Kopf … "19" = Wappenrock)
    pub gear: BTreeMap<String, GearItem>,
    pub bags: Option<Storage>,
    pub bank: Option<Storage>,
    pub events: Vec<WowEvent>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct MapInfo {
    pub name: String,
    pub parent: Option<i64>,
    #[serde(rename = "type")]
    pub kind: Option<i64>,
}

// ---------- Kampflog ----------

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct FightSpell {
    pub name: String,
    pub damage: i64,
    pub healing: i64,
    pub overheal: i64,
    pub hits: i64,
    pub crits: i64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct FightKill {
    pub guid: String,
    pub npc_id: Option<i64>,
    pub name: String,
    pub t: f64,
}

/// Ein zusammenhängender Kampf eines Charakters, berechnet aus dem offiziellen Kampflog.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct Fight {
    pub char: String,
    pub start: f64,
    pub end: f64,
    pub zone: Option<String>,
    pub map_id: Option<i64>,
    pub encounter: Option<String>,
    pub success: Option<bool>,
    pub damage: i64,
    /// wirksame Heilung inkl. Schilde
    pub healing: i64,
    pub overheal: i64,
    pub absorb: i64,
    pub taken: i64,
    pub deaths: i64,
    pub item_level: Option<f64>,
    pub target: Option<String>,
    pub spells: Vec<FightSpell>,
    pub kills: Vec<FightKill>,
}

impl Fight {
    pub fn id(&self) -> String { format!("{}|{}", self.char, (self.start * 10.0) as i64) }
}

// ---------- Archiv ----------

/// Alles, was die App dauerhaft speichert. Neue Ereignisse werden über `WowEvent::dedupe_key`
/// zusammengeführt, damit nichts verloren geht, wenn das Addon alte Einträge löscht.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
pub struct Archive {
    pub format: u32,
    pub characters: BTreeMap<String, Character>,
    pub maps: BTreeMap<String, MapInfo>,
    /// Kämpfe je Charakter-Schlüssel
    pub fights: BTreeMap<String, Vec<Fight>>,
    /// Gelesene Bytes je Kampflog-Datei
    pub log_offsets: BTreeMap<String, u64>,
    /// Version des Kampflog-Parsers, mit dem `fights` entstanden sind
    pub combat_parser_version: u32,
    /// Kriegsmeutenbank je WoW-Account
    pub warbands: BTreeMap<String, Storage>,
    /// Gildenbanken ("Gilde-Realm")
    pub guilds: BTreeMap<String, Storage>,
}

pub const ARCHIVE_FORMAT: u32 = 1;
