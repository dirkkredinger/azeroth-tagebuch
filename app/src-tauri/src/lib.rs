//! Desktop-Hülle des Azeroth-Tagebuchs: beobachtet SavedVariables und Kampflog im Hintergrund,
//! hält das Archiv und gibt es an die Oberfläche (Svelte) weiter.

mod bilder;

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};
use tagebuch_kern::{self as kern, Archive, Fight};
use tauri::{AppHandle, Emitter, Manager, State};

#[derive(Default, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase", default)]
struct Settings {
    wow_folder: Option<PathBuf>,
}

struct Inner {
    archive: Archive,
    archive_path: PathBuf,
    settings_path: PathBuf,
    settings: Settings,
    demo: bool,
    mtimes: HashMap<PathBuf, SystemTime>,
    log_reader: kern::LogReader,
    live: Option<Fight>,
    status: String,
    last_check: Option<SystemTime>,
    last_save: Instant,
    dirty: bool,
    found_files: usize,
}

type Shared = Arc<Mutex<Inner>>;

impl Inner {
    fn wow_folder(&self) -> PathBuf {
        self.settings.wow_folder.clone().unwrap_or_else(kern::guess_wow_folder)
    }

    /// Prüft SavedVariables und Kampflog. Gibt zurück, ob sich die Daten geändert haben.
    fn refresh(&mut self, force: bool) -> bool {
        if self.demo { return false; }
        let folder = self.wow_folder();
        let files = kern::find_saved_variables(&folder);
        self.found_files = files.len();
        let mut changed = false;
        let mut errors = Vec::new();
        let mut added = 0;
        for (account, path) in &files {
            let m = kern::modified(path);
            if !force && m.is_some() && self.mtimes.get(path) == m.as_ref() { continue; }
            match std::fs::read(path) {
                Ok(data) => match kern::ingest::ingest_saved_variables(&data, Some(account), &mut self.archive) {
                    Ok(n) => {
                        added += n;
                        changed = true; // auch ohne neue Einträge können sich Lager/Ausrüstung geändert haben
                        if let Some(m) = m { self.mtimes.insert(path.clone(), m); }
                    }
                    Err(e) => errors.push(format!("{account}: {e}")),
                },
                Err(e) => errors.push(format!("{account}: {e}")),
            }
        }

        let now = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0);
        let mut offsets = std::mem::take(&mut self.archive.log_offsets);
        let up = self.log_reader.poll(&folder.join("Logs"), &mut offsets, now);
        self.archive.log_offsets = offsets;
        let new_fights = kern::ingest::merge_fights(up.fights, &mut self.archive);
        if new_fights > 0 { changed = true; }
        if up.bytes_read > 0 { self.dirty = true; }
        let live = up.live.map(|mut f| { f.char = kern::ingest::resolve_char_key(&f.char, &self.archive); f });
        if live != self.live { self.live = live; }

        if changed { self.dirty = true; }
        if !errors.is_empty() {
            self.status = format!("Fehler: {}", errors.join("; "));
        } else if files.is_empty() && self.archive.characters.is_empty() {
            self.status = "Noch keine Tagebuch-Daten gefunden".into();
        } else if added > 0 || new_fights > 0 {
            self.status = format!("{added} neue Einträge, {new_fights} neue Kämpfe");
        } else if changed || force {
            self.status = "Alles aktuell".into();
        }
        self.last_check = Some(SystemTime::now());
        if self.dirty && (changed || self.last_save.elapsed() > Duration::from_secs(60)) { self.save(); }
        changed
    }

    fn save(&mut self) {
        if self.demo { return; }
        match kern::save_archive(&self.archive, &self.archive_path) {
            Ok(()) => { self.dirty = false; self.last_save = Instant::now(); }
            Err(e) => self.status = format!("Archiv konnte nicht gespeichert werden: {e}"),
        }
    }
}

/// Was die Oberfläche bekommt. Positionsproben ("pos") gibt es getrennt, weil es sehr viele sind.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Snapshot<'a> {
    archive: ArchiveView<'a>,
    status: &'a str,
    demo: bool,
    wow_folder: String,
    wow_folder_exists: bool,
    found_files: usize,
    last_check: Option<u64>,
    live: Option<&'a Fight>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ArchiveView<'a> {
    characters: Vec<CharacterView<'a>>,
    maps: &'a std::collections::BTreeMap<String, kern::MapInfo>,
    fights: &'a std::collections::BTreeMap<String, Vec<Fight>>,
    warbands: &'a std::collections::BTreeMap<String, kern::Storage>,
    guilds: &'a std::collections::BTreeMap<String, kern::Storage>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CharacterView<'a> {
    #[serde(flatten)]
    info: CharacterInfo<'a>,
    events: Vec<&'a kern::WowEvent>,
    position_count: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CharacterInfo<'a> {
    key: &'a str,
    name: &'a str,
    realm: &'a str,
    class_token: &'a Option<String>,
    class_name: &'a Option<String>,
    race: &'a Option<String>,
    faction: &'a Option<String>,
    level: &'a Option<i64>,
    spec: &'a Option<String>,
    money: &'a Option<i64>,
    account: &'a Option<String>,
    spec_id: &'a Option<i64>,
    role: &'a Option<String>,
    spec_desc: &'a Option<String>,
    primary_stat: &'a Option<i64>,
    talent_code: &'a Option<String>,
    item_level: &'a Option<f64>,
    guild: &'a Option<String>,
    gear: &'a std::collections::BTreeMap<String, kern::GearItem>,
    bags: &'a Option<kern::Storage>,
    bank: &'a Option<kern::Storage>,
}

fn snapshot_json(inner: &Inner) -> serde_json::Value {
    let a = &inner.archive;
    let characters = a
        .characters
        .values()
        .map(|c| CharacterView {
            info: CharacterInfo {
                key: &c.key, name: &c.name, realm: &c.realm, class_token: &c.class_token, class_name: &c.class_name,
                race: &c.race, faction: &c.faction, level: &c.level, spec: &c.spec, money: &c.money, account: &c.account,
                spec_id: &c.spec_id, role: &c.role, spec_desc: &c.spec_desc, primary_stat: &c.primary_stat,
                talent_code: &c.talent_code, item_level: &c.item_level, guild: &c.guild, gear: &c.gear,
                bags: &c.bags, bank: &c.bank,
            },
            events: c.events.iter().filter(|e| e.e != "pos").collect(),
            position_count: c.events.iter().filter(|e| e.e == "pos").count(),
        })
        .collect();
    let folder = inner.wow_folder();
    serde_json::to_value(Snapshot {
        archive: ArchiveView { characters, maps: &a.maps, fights: &a.fights, warbands: &a.warbands, guilds: &a.guilds },
        status: &inner.status,
        demo: inner.demo,
        wow_folder: folder.display().to_string(),
        wow_folder_exists: folder.exists(),
        found_files: inner.found_files,
        last_check: inner.last_check.and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok()).map(|d| d.as_secs()),
        live: inner.live.as_ref(),
    })
    .unwrap_or_default()
}

// ---------- Befehle für die Oberfläche ----------

#[tauri::command]
fn lade_daten(state: State<Shared>) -> serde_json::Value {
    snapshot_json(&state.lock().unwrap())
}

#[tauri::command]
fn positionen(state: State<Shared>, key: String) -> Vec<kern::WowEvent> {
    let inner = state.lock().unwrap();
    inner.archive.characters.get(&key).map(|c| c.events.iter().filter(|e| e.e == "pos").cloned().collect()).unwrap_or_default()
}

#[tauri::command]
fn neu_einlesen(state: State<Shared>, app: AppHandle) -> serde_json::Value {
    let mut inner = state.lock().unwrap();
    if inner.demo {
        inner.demo = false;
        inner.archive = kern::load_archive(&inner.archive_path);
        inner.mtimes.clear();
        inner.log_reader = kern::LogReader::new();
    }
    inner.refresh(true);
    let _ = app.emit("tagebuch-aktualisiert", ());
    snapshot_json(&inner)
}

#[tauri::command]
fn beispieldaten(state: State<Shared>, sprache: Option<String>) -> serde_json::Value {
    let mut inner = state.lock().unwrap();
    if !inner.demo && inner.dirty { inner.save(); }
    inner.demo = true;
    inner.archive = kern::demo_archive_lang(sprache.as_deref().unwrap_or("de"));
    inner.live = None;
    inner.status = "Beispieldaten – echte Daten mit „Neu einlesen“".into();
    snapshot_json(&inner)
}

#[tauri::command]
fn setze_wow_ordner(state: State<Shared>, pfad: String) -> serde_json::Value {
    let mut inner = state.lock().unwrap();
    let mut p = PathBuf::from(pfad);
    if p.file_name().map(|n| n == "WTF").unwrap_or(false) { p.pop(); }
    // Wer den Hauptordner wählt, meint den Ordner _retail_ darin
    if p.join("_retail_").exists() { p = p.join("_retail_"); }
    inner.settings.wow_folder = Some(p);
    let settings = inner.settings.clone();
    if let Ok(json) = serde_json::to_vec_pretty(&settings) {
        let _ = std::fs::create_dir_all(inner.settings_path.parent().unwrap());
        let _ = std::fs::write(&inner.settings_path, json);
    }
    inner.mtimes.clear();
    inner.log_reader = kern::LogReader::new();
    inner.demo = false;
    inner.refresh(true);
    snapshot_json(&inner)
}

// ---------- Start ----------

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        // Kartenbilder und Symbole aus der WoW-Installation (wowbild://karte/<id>, wowbild://symbol/<id>)
        .register_asynchronous_uri_scheme_protocol("wowbild", |ctx, request, responder| {
            let app = ctx.app_handle().clone();
            let path = request.uri().path().to_string();
            std::thread::spawn(move || {
                let retail = app.state::<Shared>().lock().unwrap().wow_folder();
                let bilder = app.state::<std::sync::Arc<bilder::Bilder>>();
                responder.respond(bilder.respond(&path, retail));
            });
        })
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let dir = app.path().app_data_dir().expect("App-Datenordner");
            let archive_path = dir.join("archiv.json");
            let settings_path = dir.join("einstellungen.json");
            let settings: Settings = std::fs::read(&settings_path).ok().and_then(|d| serde_json::from_slice(&d).ok()).unwrap_or_default();
            let inner = Inner {
                archive: kern::load_archive(&archive_path),
                archive_path,
                settings_path,
                settings,
                demo: false,
                mtimes: HashMap::new(),
                log_reader: kern::LogReader::new(),
                live: None,
                status: "Lese Daten …".into(),
                last_check: None,
                last_save: Instant::now(),
                dirty: false,
                found_files: 0,
            };
            let shared: Shared = Arc::new(Mutex::new(inner));
            app.manage(shared.clone());
            app.manage(Arc::new(bilder::Bilder::new(dir.clone())));

            // Hintergrund: alle 2 Sekunden SavedVariables und Kampflog prüfen
            let handle = app.handle().clone();
            std::thread::spawn(move || {
                let mut first = true;
                let mut last_live: Option<Fight> = None;
                loop {
                    let (changed, live) = {
                        let mut inner = shared.lock().unwrap();
                        let changed = inner.refresh(first);
                        (changed || first, inner.live.clone())
                    };
                    first = false;
                    if changed { let _ = handle.emit("tagebuch-aktualisiert", ()); }
                    if live != last_live {
                        let _ = handle.emit("live-kampf", &live);
                        last_live = live;
                    }
                    std::thread::sleep(Duration::from_secs(2));
                }
            });
            Ok(())
        })
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { .. } = event {
                if let Some(state) = window.try_state::<Shared>() {
                    let mut inner = state.lock().unwrap();
                    if inner.dirty { inner.save(); }
                }
            }
        })
        .invoke_handler(tauri::generate_handler![lade_daten, positionen, neu_einlesen, beispieldaten, setze_wow_ordner])
        .run(tauri::generate_context!())
        .expect("Fehler beim Starten der App");
}
