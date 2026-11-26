//! „Mit World of Warcraft starten“ (macOS): ein kleiner LaunchAgent prüft alle 5 Sekunden, ob WoW läuft,
//! und öffnet das Tagebuch einmal, sobald WoW startet. Die App selbst muss dafür nicht im Hintergrund laufen.
//! Schließt man das Tagebuch, während WoW läuft, wird es erst beim nächsten WoW-Start wieder geöffnet.

use std::path::PathBuf;
use std::process::Command;

const LABEL: &str = "de.wowtagebuch.app.wowstart";
const BUNDLE_ID: &str = "de.wowtagebuch.app";

fn home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

fn plist_path() -> Option<PathBuf> {
    home().map(|h| h.join("Library/LaunchAgents").join(format!("{LABEL}.plist")))
}

fn uid() -> Option<String> {
    let out = Command::new("/usr/bin/id").arg("-u").output().ok()?;
    let s = String::from_utf8(out.stdout).ok()?.trim().to_string();
    (!s.is_empty()).then_some(s)
}

/// Shell-Skript des Dienstes. Die Markierungsdatei merkt sich, dass WoW schon lief,
/// damit das Tagebuch nur beim Start von WoW geöffnet wird und nicht immer wieder.
fn script(marker: &str) -> String {
    format!(
        "M='{marker}'; if /usr/bin/pgrep -xq 'World of Warcraft'; then \
         if [ ! -e \"$M\" ]; then /usr/bin/touch \"$M\"; /usr/bin/open -g -b {BUNDLE_ID}; fi; \
         else /bin/rm -f \"$M\"; fi"
    )
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;")
}

pub fn enabled() -> bool {
    plist_path().map(|p| p.exists()).unwrap_or(false)
}

pub fn set(on: bool, data_dir: &std::path::Path) -> Result<bool, String> {
    let path = plist_path().ok_or("Kein Benutzerordner gefunden")?;
    let uid = uid().ok_or("Benutzer-ID nicht ermittelbar")?;
    let domain = format!("gui/{uid}");
    // alten Dienst immer erst abmelden (Fehler, wenn er nicht lief, sind egal)
    let _ = Command::new("/bin/launchctl").args(["bootout", &format!("{domain}/{LABEL}")]).output();
    if !on {
        let _ = std::fs::remove_file(&path);
        return Ok(false);
    }
    std::fs::create_dir_all(data_dir).map_err(|e| e.to_string())?;
    let marker = data_dir.join(".wow-laeuft");
    // Läuft WoW gerade, gilt dieser Start schon als bemerkt – sonst ginge sofort ein zweites Fenster auf
    let running = Command::new("/usr/bin/pgrep").args(["-xq", "World of Warcraft"]).status().map(|s| s.success()).unwrap_or(false);
    if running { let _ = std::fs::write(&marker, b""); }
    let plist = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>{LABEL}</string>
  <key>ProgramArguments</key>
  <array><string>/bin/sh</string><string>-c</string><string>{}</string></array>
  <key>StartInterval</key><integer>5</integer>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>LowPriorityIO</key><true/>
</dict>
</plist>
"#,
        xml_escape(&script(&marker.display().to_string().replace('\'', "'\\''")))
    );
    std::fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
    std::fs::write(&path, plist).map_err(|e| e.to_string())?;
    let out = Command::new("/bin/launchctl").args(["bootstrap", &domain, &path.display().to_string()]).output().map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).trim().to_string());
    }
    Ok(true)
}
