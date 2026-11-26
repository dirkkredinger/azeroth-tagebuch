# WoW-Tagebuch – Projektkontext für Claude Code

Sprache mit dem Nutzer: **Deutsch**. Entwickelt wird auf macOS (Apple Silicon) für World of Warcraft Retail.

## Ziel
Ein Tagebuch für WoW-Charaktere:
1. **Addon** `AzerothTagebuch` loggt im Spiel Quests, Reisewege, Zonen, Level-ups, Erfolge, Tode und Notizen. Es loggt **nur** und automatisiert nichts (Blizzard-ToS: kein Botting).
2. **macOS-App** `WoWTagebuch` (SwiftUI) liest die SavedVariables und zeigt ein Dashboard.
3. **Später (V2):** Prosa-Tagebucheinträge pro Charakter über die Claude-API und Bilder zur Szene über eine externe Bild-API (z. B. OpenAI). API-Schlüssel kommen in den macOS-Schlüsselbund. In Bild-Prompts den Charakter allgemein beschreiben (Rasse, Rüstung, Farben), keine Blizzard-Figuren oder Marken nennen.

## Ordner
- **`kern/`** – Rust-Bibliothek `tagebuch-kern` (Lua-Parser, Archiv/Zusammenführen, Kampflog-Parser, `LogReader`, Beispieldaten). Plattformunabhängig, später auch für den Server. Tests: `cargo test` in `kern/`; echte Daten prüfen: `cargo run --example pruefen`.
- **`app/`** – neue App mit **Tauri 2 + SvelteKit (Svelte 5, TypeScript)** für macOS, Windows, später Android/iOS/Web. `app/src-tauri` = Desktop-Hülle (Hintergrund-Thread prüft alle 2 s SavedVariables + Kampflog, Befehle `lade_daten`, `positionen`, `neu_einlesen`, `beispieldaten`, `setze_wow_ordner`, Ereignisse `tagebuch-aktualisiert`, `live-kampf`). `app/src` = Oberfläche; Auswertungen in `src/lib/analyse.ts`. Archiv: `~/Library/Application Support/de.wowtagebuch.app/archiv.json`. Start: `cd app && npm run tauri dev` (Rust über Homebrew-rustup: `export PATH=/opt/homebrew/opt/rustup/bin:$PATH`). Browser-Vorschau mit Beispieldaten: `npm run dev` (liest `static/demo.json`, erzeugt mit `cargo run --example demo_json` in `kern/`).
- **`wowbilder/`** – Rust-Crate: CascLib (in `wowbilder/casclib`, gebaut per `cc` + `libz-sys`), DB2-Leser, BLP-Decoder, Kartenbilder inkl. Erkundungs-Overlays, Symbole. Die Tauri-App liefert sie über das Protokoll `wowbild://karte/<uiMapID>` bzw. `wowbild://symbol/<FileDataID>` (Cache im App-Ordner `Karten/v1`, `Symbole/v1`; im Frontend `src/lib/bild.ts`).
- **Sprache:** Oberfläche Deutsch/Englisch (`app/src/lib/i18n.svelte.ts`, `t('deutscher Text')`, Übersetzungen in `app/src/lib/sprache/en.ts`; „kontext|Text“ für gleiche deutsche Wörter mit verschiedener Übersetzung). Beispieldaten gibt es auf Englisch über `tools/sample_en.py` (→ `kern/beispiel/*_en.*`, `app/static/demo-en.json`). Eigene Fantasy-Karten für die Beispieldaten: `tools/make_demo_maps.py` → `app/static/demo-karten/`.
- Stand Tauri: **Phase 1 + 2** fertig – alle Reiter (Übersicht, Quests, Karte, Zeitleiste, Statistik, Kampf, Heilung, Ausrüstung, Instanzen, Bosskämpfe, Beute, Lager, Klasse) und globale Suche. **Bosskämpfe** (`tabs/Bosse.svelte`, Auswertung `lib/boss.ts`): Hinweise aus dem Dungeonkompendium je Rolle, Unterbrechen/Entfernen je Spezialisierung (Tabelle `KITS`, nur Grundfähigkeiten), eigene Bilanz je Boss. Kommt von selbst nach vorn, wenn das Kampflog `ZONE_CHANGE` in eine Instanz oder `ENCOUNTER_START` meldet (Tauri-Ereignis `live-ort`, `LiveLocation` im Kern; beim Start wird der letzte Ortswechsel vor dem gespeicherten Offset nachgelesen). Reiter liegen in `app/src/lib/tabs/`, Diagramme selbst gezeichnet (`XYChart`, `Columns`, `HBars`, `Donut`, `StackedBars`). Phase 3: Sync (Cloud-Ordner, verschlüsselt) + Mobil-Apps. Phase 4: optionaler Docker-Server.
- Die SwiftUI-App (unten) bleibt bis zur Ablösung die Referenz.
- `Package.swift`, `Sources/WoWTagebuch/` – die App als Swift-Paket (macOS 14+, Swift-Tools 5.9, Sprachmodus 5)
- `Sources/WoWTagebuch/Resources/Beispiel.lua` – Beispieldaten (zwei erfundene Charaktere)
- `Addon/AzerothTagebuch/` – **Quelle** des Addons. Installiert ist es unter `/Applications/World of Warcraft/_retail_/Interface/AddOns/AzerothTagebuch`. Nach Änderungen dorthin kopieren.
- `tools/make_sample.py` – erzeugt `Beispiel.lua` (`python3 tools/make_sample.py > Sources/WoWTagebuch/Resources/Beispiel.lua`)
- `tools/check_parser.py` – Python-Nachbau des Lua-Parsers zum Prüfen von Dateien

## Bauen & Starten
- `swift build`, dann `swift run` (oder `Package.swift` in Xcode öffnen, Ziel „My Mac“, ⌘R)
- **Stand (21.11.2026):** App baut fehlerfrei. Reiter: Übersicht, Quests, Karte (Kartenbild aus der WoW-Installation inkl. Erkundungs-Overlays), Zeitleiste, Statistik, Kampf, Heilung (aus dem Kampflog, live), Ausrüstung, Beute (Kills aus dem Kampflog + Beute vom Addon → Dropraten), Lager (Taschen, Bank, Kriegsmeute, Gildenbank), Klasse (Wowhead-Links, Talentcode). Item-Symbole liest `IconStore` ebenfalls lokal aus dem CASC-Archiv (Cache `Symbole/v1`). Eigenes WoW-Theme (`Theme.swift`). Addon 1.3.0 schreibt zusätzlich Gegenstandsstufe, Ausrüstung, Beute, Lager und Talente. Account-Übersicht mit Ruhmeshalle, globale Suche (Toolbar) inkl. „Wo liegt …?“.

## Daten
- WoW-Client 12.1.5, Interface 120105 (die TOC listet 120100, 120105, 120107, 120200)
- SavedVariables: `/Applications/World of Warcraft/_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AzerothTagebuch.lua`. WoW schreibt sie erst beim Ausloggen oder nach `/reload`.
- Archiv der App: `~/Library/Application Support/WoWTagebuch/archiv.json`. Neue Ereignisse werden über `WowEvent.dedupeKey` zusammengeführt, damit nichts verloren geht, wenn das Addon alte Einträge löscht.
- Struktur: `AzerothTagebuchDB = { version, locale, maps = {[mapID] = {n, p, ty}}, chars = {["Name-Realm"] = {name, realm, class, classLocal, race, raceLocal, faction, level, spec, money, events = {...}}} }`
- Ereignistypen (`e`) und Felder:
  - `login` (lv, g), `logout` (dauer, g, dg)
  - `zone` (z, sz; in Instanzen zusätzlich inst, it, diff)
  - `pos` (m, x, y, mo) – alle 10 s bei Bewegung; mo ∈ zu_fuss, reittier, flug, schwimmen, taxi
  - `taxi_start`, `taxi_ende`
  - `quest_an` (q, n, c, z), `quest_ab` (q, n, c, xp, g, z, lv), `quest_weg` (q)
  - `level` (lv), `erfolg` (a, n, p), `tod` (z, sz), `notiz` (txt, z)
  - `ausr` (il, ilg, lv) – Gegenstandsstufe bei Änderung; `talente` (sid, spec, rolle, code, lo, lv) – Spezialisierung/Talentcode bei Änderung
  - `gegenstand` (slot, id, n, q = Qualität, il, ic = Symbol-FileDataID, alt, altil) – Ausrüstungswechsel
  - `beute` (src = GUID der Leiche/des Vorkommens, npc, art, sn, items = {{id, n, q, ic, c, cur, gold}}, z) – ein Eintrag je geplünderter Quelle
  - Instanzen (Addon 1.4): `inst_an` (iid, inst, it = party/raid/delve/scenario, did = Schwierigkeits-ID, diff, lv, il, grp, tier bei Tiefen, ml = Schlüsselsteinstufe), `inst_ab` (iid, inst, dauer), `inst_fertig` (iid, inst, art = szenario/mythisch_plus/dungeonbrowser, dauer, ml, zeit, imzeit), `boss` (eid, n, did, ok = 1/0, dauer, grp, iid, inst). Laufender Lauf steht in `char.curInst` (überlebt /reload). Läufe baut die App in `analyse.ts` (`instanceRuns`), Wiedereinstieg < 20 Min. = derselbe Lauf.
  - Dungeonkompendium (Addon 1.5): `AzerothTagebuchDB.journal = {v, loc, build, inst = {[journalInstanceID] = {n, d, raid, map = Instanz-Karten-ID wie im Kampflog/inst_an.iid, area, did, t, enc = {{id, deid = DungeonEncounterID, n, d, s = {{id, lv = Tiefe, t, d, ht = headerType (3 = Überblick), ic, sp, fl = Symbol-Flags, fd}}}}}}}`. Beim Einloggen wird die aktuelle Erweiterung (Dungeons + Schlachtzüge) gelesen, beim Betreten anderer Instanzen deren Eintrag (dafür muss per `EJ_SelectTier` deren Erweiterung ausgewählt sein, sonst liefert das Kompendium keine Bosse; Einträge ohne Bosse werden nicht gespeichert); neu bei anderem Build/Locale. Im Archiv: `journal`. Demo-Bosse: `tools/demo_journal.py`.
  - Lager-Schnappschüsse `{t, tabs = {{name, ic, items = {{id, n, q, ic, c, il}}}}, g, by}`: je Charakter `bags`, `bank`; account-weit `warband`; `guilds["Gilde-Realm"]` (Gildenbank, nur sichtbare Fächer). Bank nur bei geöffneter Bank lesbar – leere Scans überschreiben keinen alten Stand.
  - Charakterfelder zusätzlich: guild, specID, role, specDesc, primaryStat, talentCode, ilvl, gear = {[slot] = {id, n, link, q, il, ic, st = {krit, tempo, meist, viel, str, bew, int, aus}}}
  - Fast jedes Ereignis hat zusätzlich m, x, y (Position). Gold steht immer in Kupfer.
- Ingame-Befehle: `/tb`, `/tb stats`, `/tb notiz <Text>`, `/tb kampflog an|aus`, `/tb bosse` (Kompendium der aktuellen Instanz neu auslesen)
- Kampflog: `_retail_/Logs/WoWCombatLog*.txt`, Parser in `Sources/WoWTagebuch/Combat/`. Kämpfe und gelesene Datei-Offsets stehen im Archiv (`fights`, `logOffsets`, `combatParserVersion` – bei Parser-Änderungen `CombatLogParser.version` erhöhen, dann wird neu eingelesen). Eigenheiten des echten Logs (12.1.5): Windows-Zeilenenden `\r\n`, Zeit ohne Jahr-Zeitzone wie `11/21/2026 11:03:22.1361`, erweiterter Datenblock hat 19 Felder (früher 17) – der Parser sucht sein Ende am Muster PosX,PosY,MapID,Blickrichtung; das letzte Feld ist bei Spielern die Gegenstandsstufe. Beispiel-Log: `python3 tools/make_combatlog.py > Sources/WoWTagebuch/Resources/BeispielKampflog.txt` (nach `make_sample.py`).

## Hinweise
- Die App **liefert keine Blizzard-Grafiken mit** (geplante Veröffentlichung: Addon auf CurseForge, App separat). Kartenbilder liest die App beim Nutzer selbst aus dessen WoW-Installation (CASC-Archiv `/Applications/World of Warcraft/Data` über CascLib, Tabellen UiMapXMapArt/UiMapArt/UiMapArtStyleLayer/UiMapArtTile, BLP-Kacheln) und speichert sie nur unter `~/Library/Application Support/WoWTagebuch/Karten`. Code: `Sources/WoWTagebuch/Maps/`, CascLib liegt in `Sources/CCascLib/` (MIT).
- Kampf- und Heilstatistiken kommen aus dem offiziellen Kampflog (`_retail_/Logs/WoWCombatLog*.txt`), das die App live mitliest. Das Addon schaltet das Kampflog ein (abschaltbar mit `/tb kampflog aus`).
- Talent-Builds nicht von Wowhead abgreifen (Nutzungsbedingungen) – nur verlinken.
- Midnight (12.x) schränkt Addon-APIs im Kampf ein. Das Addon fängt riskante Aufrufe mit `pcall` ab.
