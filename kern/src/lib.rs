//! Kern des Azeroth-Tagebuchs. Plattformunabhängig (macOS, Windows, Linux, später Server).
//!
//! - liest die SavedVariables des Addons (`lua`, `ingest`)
//! - wertet das offizielle Kampflog aus (`combatlog`, `LogReader`)
//! - speichert alles in einem Archiv (`Archive`, JSON)

pub mod combatlog;
pub mod ingest;
pub mod lua;
pub mod model;

pub use model::*;

use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::SystemTime;

pub const SAVED_VARIABLES_FILE: &str = "AzerothTagebuch.lua";

/// Übliche Installationsorte von WoW (Ordner `_retail_`)
pub fn default_wow_folders() -> Vec<PathBuf> {
    let mut v = Vec::new();
    if cfg!(target_os = "macos") {
        v.push(PathBuf::from("/Applications/World of Warcraft/_retail_"));
    } else if cfg!(target_os = "windows") {
        for base in ["C:\\Program Files (x86)", "C:\\Program Files", "D:\\Program Files (x86)", "D:\\Games", "C:\\Games"] {
            v.push(PathBuf::from(base).join("World of Warcraft").join("_retail_"));
        }
    } else {
        v.push(PathBuf::from("/opt/World of Warcraft/_retail_"));
    }
    v
}

/// Erster vorhandener Standardordner (oder der erste Vorschlag)
pub fn guess_wow_folder() -> PathBuf {
    let all = default_wow_folders();
    all.iter().find(|p| p.exists()).cloned().unwrap_or_else(|| all[0].clone())
}

/// Findet alle SavedVariables-Dateien des Addons: (Account, Pfad)
pub fn find_saved_variables(wow_folder: &Path) -> Vec<(String, PathBuf)> {
    let accounts = wow_folder.join("WTF").join("Account");
    let Ok(dirs) = fs::read_dir(&accounts) else { return vec![] };
    let mut out: Vec<(String, PathBuf)> = dirs
        .filter_map(|d| d.ok())
        .filter_map(|d| {
            let file = d.path().join("SavedVariables").join(SAVED_VARIABLES_FILE);
            file.exists().then(|| (d.file_name().to_string_lossy().into_owned(), file))
        })
        .collect();
    out.sort();
    out
}

pub fn modified(path: &Path) -> Option<SystemTime> { fs::metadata(path).and_then(|m| m.modified()).ok() }

// ---------- Archiv laden/speichern ----------

pub fn load_archive(path: &Path) -> Archive {
    let mut a: Archive = fs::read(path).ok().and_then(|d| serde_json::from_slice(&d).ok()).unwrap_or_default();
    // Neuer Kampflog-Parser → Kampflogs komplett neu auswerten
    if a.combat_parser_version != combatlog::PARSER_VERSION {
        a.fights.clear();
        a.log_offsets.clear();
        a.combat_parser_version = combatlog::PARSER_VERSION;
    }
    a.format = ARCHIVE_FORMAT;
    a
}

pub fn save_archive(archive: &Archive, path: &Path) -> std::io::Result<()> {
    if let Some(dir) = path.parent() { fs::create_dir_all(dir)?; }
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, serde_json::to_vec(archive).map_err(std::io::Error::other)?)?;
    fs::rename(tmp, path)
}

// ---------- Kampflog live lesen ----------

/// Liest neue Zeilen aus `_retail_/Logs/WoWCombatLog*.txt` – beim Start alles Ungelesene, danach inkrementell.
#[derive(Default)]
pub struct LogReader {
    parsers: HashMap<String, combatlog::CombatLogParser>,
}

pub struct LogUpdate {
    pub fights: Vec<Fight>,
    pub live: Option<Fight>,
    pub bytes_read: u64,
}

impl LogReader {
    pub fn new() -> Self { Self::default() }

    pub fn log_files(logs: &Path) -> Vec<PathBuf> {
        let Ok(dir) = fs::read_dir(logs) else { return vec![] };
        let mut v: Vec<PathBuf> = dir
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| {
                let n = p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
                n.starts_with("WoWCombatLog") && n.to_lowercase().ends_with(".txt")
            })
            .collect();
        v.sort();
        v
    }

    /// Liest alles Neue; `offsets` (Dateiname → gelesene Bytes) wird fortgeschrieben.
    pub fn poll(&mut self, logs: &Path, offsets: &mut std::collections::BTreeMap<String, u64>, now: f64) -> LogUpdate {
        let mut fights = Vec::new();
        let mut read_total = 0;
        let files = Self::log_files(logs);
        for path in &files {
            let name = path.file_name().unwrap().to_string_lossy().into_owned();
            let size = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
            let mut offset = *offsets.get(&name).unwrap_or(&0);
            if size < offset { offset = 0; } // Datei neu angelegt
            if size <= offset { continue; }
            let Ok(mut file) = File::open(path) else { continue };
            if file.seek(SeekFrom::Start(offset)).is_err() { continue; }
            let parser = self.parsers.entry(name.clone()).or_insert_with(combatlog::CombatLogParser::new);
            // in Stücken lesen, damit auch große Dateien den Speicher nicht sprengen
            let mut buf = vec![0u8; 8 * 1024 * 1024];
            let mut carry: Vec<u8> = Vec::new();
            loop {
                let n = match file.read(&mut buf) { Ok(0) | Err(_) => break, Ok(n) => n };
                carry.extend_from_slice(&buf[..n]);
                let Some(last_nl) = carry.iter().rposition(|&b| b == b'\n') else { continue };
                let complete: Vec<u8> = carry.drain(..=last_nl).collect();
                let text = String::from_utf8_lossy(&complete);
                for line in text.lines() { parser.parse_line(line); }
                offset += complete.len() as u64;
                read_total += complete.len() as u64;
                fights.extend(parser.take_finished());
            }
            offsets.insert(name, offset);
        }
        // Offene Kämpfe schließen, wenn nichts mehr passiert; live ist nur die neueste Datei
        let newest = files.last().map(|p| p.file_name().unwrap().to_string_lossy().into_owned());
        let mut live = None;
        for (name, p) in self.parsers.iter_mut() {
            p.close_if_idle(now);
            if Some(name) == newest.as_ref() { live = p.current.clone(); }
            fights.extend(p.take_finished());
        }
        LogUpdate { fights, live, bytes_read: read_total }
    }
}

// ---------- Beispieldaten ----------

/// Archiv mit zwei erfundenen Charakteren, zum Ausprobieren ohne WoW
pub fn demo_archive() -> Archive {
    let mut a = Archive { format: ARCHIVE_FORMAT, combat_parser_version: combatlog::PARSER_VERSION, ..Default::default() };
    let _ = ingest::ingest_saved_variables(include_bytes!("../beispiel/Beispiel.lua"), Some("DEMO"), &mut a);
    let fights = combatlog::parse_all(include_str!("../beispiel/BeispielKampflog.txt"));
    ingest::merge_fights(fights, &mut a);
    a
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_hat_daten() {
        let a = demo_archive();
        assert_eq!(a.characters.len(), 2);
        let ly = &a.characters["Lyraen-Antonidas"];
        assert!(ly.events.len() > 300);
        assert!(!ly.gear.is_empty());
        assert!(ly.bank.is_some());
        assert!(a.fights["Lyraen-Antonidas"].len() > 10);
        assert!(!a.warbands.is_empty() && !a.guilds.is_empty());
        // Zusammenführen ist idempotent
        let mut b = a.clone();
        let added = ingest::ingest_saved_variables(include_bytes!("../beispiel/Beispiel.lua"), Some("DEMO"), &mut b).unwrap();
        assert_eq!(added, 0);
    }
}
