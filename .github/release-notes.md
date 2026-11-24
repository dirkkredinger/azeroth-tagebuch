**App 0.4.0** und **Addon 1.5.0** · 🇬🇧 English below

## Neu in 0.4.0
- **Bosskämpfe:** neuer Reiter, der beim Betreten eines Dungeons oder Schlachtzugs von selbst aufgeht (erkannt live im Kampflog). Je Boss: Hinweise aus dem Dungeonkompendium für deine Rolle (Tank, Heiler, Schaden – umschaltbar), tödliche und wichtige Fähigkeiten, was deine Spezialisierung unterbrechen oder entfernen kann, und deine eigene Bilanz (Siege, Wipes, schnellster Kill, beste DPS/HPS). Der laufende bzw. nächste Boss ist hervorgehoben.
- Das Addon 1.5.0 liest dafür beim Einloggen das Dungeonkompendium der aktuellen Erweiterung aus (und beim Betreten anderer Instanzen deren Bosse). Nach dem ersten Einloggen einmal `/reload` eingeben.

### New in 0.4.0 (English)
- **Boss fights:** new tab that opens by itself when you enter a dungeon or raid (detected live from the combat log). Per boss: notes from the Adventure Guide for your role (tank, healer, damage – switchable), deadly and important abilities, what your spec can interrupt or remove, and your own record (kills, wipes, fastest kill, best DPS/HPS). The current or next boss is highlighted.
- Addon 1.5.0 reads the Adventure Guide of the current expansion when you log in (and the bosses of any other instance you enter). Type `/reload` once after your first login.

## Was du brauchst

| Datei | Für |
|---|---|
| `AzerothTagebuch-Addon-….zip` | das WoW-Addon (für alle) |
| `Azeroth-Tagebuch_…_universal.dmg` | macOS (Apple-Chip und Intel) |
| `Azeroth-Tagebuch_…_x64-setup.exe` oder `…_x64_en-US.msi` | Windows (eine der beiden genügt) |

## Installation

1. **Addon:** ZIP entpacken und den Ordner `AzerothTagebuch` nach `World of Warcraft/_retail_/Interface/AddOns/` kopieren. Im Spiel in der Addon-Liste aktivieren.
2. **App installieren.** Sie ist noch nicht signiert:
   - **Mac:** App in „Programme“ ziehen, beim ersten Start **Rechtsklick → Öffnen**.
   - **Windows:** Bei der SmartScreen-Warnung **„Weitere Informationen“ → „Trotzdem ausführen“**.
3. Im Spiel einmal `/reload` eingeben. Die App liest die Daten danach automatisch ein. Liegt WoW nicht am Standardort, in der App über das Ordner-Symbol den Ordner `_retail_` wählen.

Ohne WoW lässt sich die App mit „Beispieldaten anzeigen“ ausprobieren.

## Was drin ist

- Account-Übersicht mit Ruhmeshalle, Spielzeit, Gold und Ereignissen aller Charaktere
- Pro Charakter: Übersicht, Quests, **Karte mit Route** (Kartenbild aus der eigenen WoW-Installation), Zeitleiste, Statistik
- **Kampf und Heilung** aus dem offiziellen Kampflog – live während des Spielens, DPS/HPS nach Stufe und Gegenstandsstufe
- **Ausrüstung** als Charakterbogen, **Beute mit Dropraten**, **Lager** (Taschen, Bank, Kriegsmeute, Gildenbank)
- **Bosskämpfe** mit Hinweisen für Rolle und Spezialisierung, öffnen sich beim Betreten einer Instanz
- Klasse mit Wowhead-Links, globale Suche („Wo liegt …?“), Item-Tooltips im WoW-Stil

## Gut zu wissen

- Das Addon **loggt nur** und automatisiert nichts. Die App liest nur Dateien von der Festplatte und greift nie auf das laufende Spiel zu.
- Die App liefert keine Blizzard-Grafiken mit: Karten und Symbole entstehen beim Nutzer aus seiner eigenen WoW-Installation.
- Das Addon schaltet das Kampflog ein (abschaltbar mit `/tb kampflog aus`).
- Testversion: Fehler bitte melden – am besten mit Screenshot und Beschreibung, was du gerade gemacht hast.
