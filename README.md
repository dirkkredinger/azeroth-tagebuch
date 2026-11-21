<p align="center">
  <img src="app/src-tauri/icons/128x128@2x.png" width="128" alt="Azeroth-Tagebuch">
</p>

<h1 align="center">Azeroth-Tagebuch</h1>

<p align="center">
  <b>Das Tagebuch für deine World-of-Warcraft-Charaktere</b><br>
  Quests, Reisewege, Kämpfe, Beute und Lager – automatisch mitgeschrieben, schön aufbereitet.
</p>

<p align="center">
  <a href="https://github.com/dirkkredinger/azeroth-tagebuch/releases/latest"><b>⬇ Herunterladen</b></a> ·
  <a href="#installation">Installation</a> ·
  <a href="#häufige-fragen">Fragen</a> ·
  <a href="https://github.com/dirkkredinger/azeroth-tagebuch/issues">Fehler melden</a> ·
  <a href="https://ko-fi.com/mbmf17/">☕ Unterstützen</a>
</p>

![Account-Übersicht](docs/bilder/1-uebersicht.png)

## Was es kann

Ein kleines **Addon** schreibt im Spiel mit, was deine Charaktere erleben. Die **App** auf deinem Rechner
liest das automatisch ein und zeigt es als Tagebuch und Dashboard – während du spielst sogar live.

- **Account-Übersicht** mit Ruhmeshalle, Spielzeit, Gold und den letzten Ereignissen aller Charaktere
- **Quests**, **Zeitleiste** und **Statistik** pro Charakter
- **Karte** mit deiner Route – eingefärbt nach Fortbewegung, mit Quests, Toden und Notizen
- **Kampf und Heilung** aus dem offiziellen Kampflog: DPS/HPS je Kampf, nach Stufe und nach Gegenstandsstufe
- **Ausrüstung** als Charakterbogen mit Werten und Wechselverlauf
- **Beute mit Dropraten**: welcher Gegner was wie oft fallen lässt
- **Lager**: Taschen, Bank, Kriegsmeutenbank und Gildenbank – und die Suche „**Wo liegt …?**“
- **Klasse & Spezialisierung** mit Links zu Guides und deinem Talent-Build
- Eigenes Design im Stil alter Abenteuerbücher, Item-Tooltips im WoW-Stil

| | |
|---|---|
| ![Kampfstatistik](docs/bilder/2-kampf.png) | ![Routenkarte](docs/bilder/3-karte.png) |
| ![Beute mit Dropraten](docs/bilder/4-beute.png) | ![Ausrüstung mit Tooltip](docs/bilder/5-ausruestung.png) |

## Installation

1. **[Neueste Version herunterladen](https://github.com/dirkkredinger/azeroth-tagebuch/releases/latest)** – unter „Assets“:
   - `AzerothTagebuch-Addon-….zip` – das Addon (für alle)
   - **Mac:** `Azeroth-Tagebuch_…_universal.dmg` (Apple-Chip und Intel)
   - **Windows:** `Azeroth-Tagebuch_…_x64-setup.exe`
2. **Addon:** ZIP entpacken, den Ordner `AzerothTagebuch` nach `World of Warcraft/_retail_/Interface/AddOns/` kopieren und im Spiel aktivieren.
3. **App installieren.** Sie ist (noch) nicht signiert:
   - **Mac:** in „Programme“ ziehen, beim ersten Start **Rechtsklick → Öffnen**.
   - **Windows:** bei der SmartScreen-Warnung **„Weitere Informationen“ → „Trotzdem ausführen“**.
4. Im Spiel einmal `/reload` – fertig. Liegt WoW nicht am Standardort, wählst du in der App über das Ordner-Symbol den Ordner `_retail_`.

Ohne WoW lässt sich die App über „Beispieldaten anzeigen“ ausprobieren.

**Im Spiel:** `/tb` zeigt eine kurze Statistik, `/tb notiz <Text>` schreibt eine eigene Tagebuchnotiz,
`/tb kampflog an|aus` schaltet das Kampflog für die Kampfstatistik.

## Häufige Fragen

**Kann ich dafür gebannt werden?**
Das Addon schreibt nur mit und automatisiert nichts – wie jedes Statistik-Addon. Die App liest ausschließlich
Dateien von deiner Festplatte (die gespeicherten Addon-Daten, das offizielle Kampflog und die Spieldaten für
Karten und Symbole). Sie greift nie auf das laufende Spiel zu, sendet keine Eingaben und verändert nichts.
Der Quellcode ist offen – jeder kann das nachprüfen.

**Woher kommen Karten und Item-Symbole?**
Aus deiner eigenen WoW-Installation. Die App liefert keine Blizzard-Grafiken mit, sondern liest sie bei Bedarf
lokal aus und speichert sie nur auf deinem Rechner.

**Werden meine Daten irgendwohin geschickt?**
Nein. Alles bleibt auf deinem Rechner.

**Warum zeigt die Kampfstatistik nichts?**
Sie entsteht aus dem Kampflog, das das Addon beim Einloggen einschaltet. Kämpfe vor der Installation fehlen daher.

## Unterstützen

Das Azeroth-Tagebuch ist kostenlos und quelloffen. Wenn es dir gefällt, freue ich mich über einen Kaffee:

<p align="center"><a href="https://ko-fi.com/mbmf17/"><img src="https://img.shields.io/badge/Ko--fi-Unterst%C3%BCtzen-FF5E5B?logo=ko-fi&logoColor=white&style=for-the-badge" alt="Auf Ko-fi unterstützen"></a></p>

Genauso hilft ein Stern ⭐ hier auf GitHub, eine Fehlermeldung oder eine Idee unter [Issues](https://github.com/dirkkredinger/azeroth-tagebuch/issues).

## Für Entwickler

| Ordner | Inhalt |
|---|---|
| `Addon/AzerothTagebuch` | WoW-Addon (Lua) |
| `app/` | App mit Tauri 2 + Svelte 5 (macOS, Windows; geplant: Android, iOS, Web) |
| `kern/` | Rust: liest SavedVariables und Kampflog, führt alles im Archiv zusammen |
| `wowbilder/` | Rust: Kartenbilder und Symbole aus der lokalen Installation (CascLib) |
| `Sources/`, `Package.swift` | erste Mac-App (SwiftUI), wird abgelöst |
| `tools/` | erzeugt Beispieldaten |

```bash
cd app
npm install
npm run tauri dev      # App mit automatischem Neuladen (braucht Rust und Node.js)
npm run tauri build    # fertige App
npm run dev            # nur die Oberfläche im Browser, mit Beispieldaten
```

Tests des Kerns: `cd kern && cargo test`. GitHub Actions baut bei jedem Push Windows- und Mac-Version;
ein Tag `v…` veröffentlicht ein Release mit App und Addon.

## Lizenz

[GNU GPL v3.0](LICENSE) – Fremd-Code und Hinweise siehe [THIRD_PARTY.md](THIRD_PARTY.md).

*World of Warcraft ist eine Marke von Blizzard Entertainment, Inc. Dies ist ein inoffizielles Fan-Projekt
und steht in keiner Verbindung zu Blizzard Entertainment.*

<sub>Entwickelt von dirkkredinger – mit Unterstützung von Claude (Anthropic).</sub>
