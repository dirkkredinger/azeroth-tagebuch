//! Bild-Protokoll `wowbild://`: liefert Kartenbilder und Gegenstandssymbole aus der lokalen
//! WoW-Installation. Einmal erzeugte Bilder liegen im App-Ordner (Karten/v1, Symbole/v1).

use std::path::PathBuf;
use std::sync::Mutex;
use tauri::http::{Response, StatusCode};

pub struct Bilder {
    cache: PathBuf,
    /// geöffnetes CASC-Archiv (für einen Spielordner); Zugriffe nacheinander
    wow: Mutex<Option<(PathBuf, Result<wowbilder::WowBilder, String>)>>,
}

impl Bilder {
    pub fn new(cache: PathBuf) -> Self { Bilder { cache, wow: Mutex::new(None) } }

    /// Antwort für einen Pfad wie "karte/2395" oder "symbol/133071"
    pub fn respond(&self, path: &str, retail: PathBuf) -> Response<Vec<u8>> {
        // convertFileSrc kodiert Schrägstriche ("karte%2F63") – daher erst dekodieren
        let path = percent_decode(path);
        let mut parts = path.trim_matches('/').split('/');
        let (kind, id) = (parts.next().unwrap_or(""), parts.next().and_then(|x| x.split('.').next()).and_then(|x| x.parse::<u32>().ok()));
        let Some(id) = id else { return not_found("ungültige Adresse") };
        let (file, mime) = match kind {
            "karte" => (self.cache.join("Karten/v1").join(format!("{id}.jpg")), "image/jpeg"),
            "symbol" => (self.cache.join("Symbole/v1").join(format!("{id}.png")), "image/png"),
            _ => return not_found("unbekannte Art"),
        };
        if let Ok(data) = std::fs::read(&file) { return ok(data, mime); }

        let game = wowbilder::game_folder_for(&retail);
        let mut guard = self.wow.lock().unwrap();
        if guard.as_ref().map(|(p, _)| p != &game).unwrap_or(true) {
            *guard = Some((game.clone(), wowbilder::WowBilder::open(&game)));
        }
        let Some((_, Ok(wow))) = guard.as_mut() else {
            let msg = guard.as_ref().and_then(|(_, r)| r.as_ref().err().cloned()).unwrap_or_default();
            return not_found(&msg);
        };
        let data = match kind {
            "karte" => match wow.map(id) {
                Ok(Some(img)) => wowbilder::to_jpeg(&img, 2560, 85),
                Ok(None) => return not_found("keine Kartengrafik"),
                Err(e) => Err(e),
            },
            _ => wow.icon(id).and_then(|img| wowbilder::to_png(&img)),
        };
        match data {
            Ok(bytes) => {
                if let Some(dir) = file.parent() { let _ = std::fs::create_dir_all(dir); }
                let _ = std::fs::write(&file, &bytes);
                ok(bytes, mime)
            }
            Err(e) => not_found(&e),
        }
    }
}

fn percent_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            if let Ok(v) = u8::from_str_radix(&s[i + 1..i + 3], 16) { out.push(v); i += 3; continue; }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

#[cfg(test)]
mod tests {
    #[test]
    fn dekodiert_pfade() {
        assert_eq!(super::percent_decode("/karte%2F63"), "/karte/63");
        assert_eq!(super::percent_decode("/symbol/133071"), "/symbol/133071");
        assert_eq!(super::percent_decode("%"), "%");
    }
}

fn ok(data: Vec<u8>, mime: &str) -> Response<Vec<u8>> {
    Response::builder()
        .header("Content-Type", mime)
        .header("Cache-Control", "max-age=31536000")
        .header("Access-Control-Allow-Origin", "*")
        .body(data)
        .unwrap()
}

fn not_found(msg: &str) -> Response<Vec<u8>> {
    Response::builder()
        .status(StatusCode::NOT_FOUND)
        .header("Content-Type", "text/plain; charset=utf-8")
        .header("Access-Control-Allow-Origin", "*")
        .body(msg.as_bytes().to_vec())
        .unwrap()
}
