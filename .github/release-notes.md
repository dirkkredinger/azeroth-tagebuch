Erste Testversion des Azeroth-Tagebuchs: **App 0.2.0** und **Addon 1.3.0**.

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
- Klasse mit Wowhead-Links, globale Suche („Wo liegt …?“), Item-Tooltips im WoW-Stil

## Gut zu wissen

- Das Addon **loggt nur** und automatisiert nichts. Die App liest nur Dateien von der Festplatte und greift nie auf das laufende Spiel zu.
- Die App liefert keine Blizzard-Grafiken mit: Karten und Symbole entstehen beim Nutzer aus seiner eigenen WoW-Installation.
- Das Addon schaltet das Kampflog ein (abschaltbar mit `/tb kampflog aus`).
- Testversion: Fehler bitte melden – am besten mit Screenshot und Beschreibung, was du gerade gemacht hast.
