# CurseForge-Projekt: Angaben zum Anlegen

- **Name:** Azeroth-Tagebuch
- **Kurzbeschreibung (Summary):** A diary for your characters: logs quests, travels, instances, bosses, loot and more – view it all in the free companion app.
- **Kategorien:** Data Export, Quests & Leveling, Boss Encounters, Bags & Inventory
- **Lizenz:** GNU General Public License version 3 (GPLv3)
- **Quellcode-Link:** https://github.com/dirkkredinger/azeroth-tagebuch
- **Issues-Link:** https://github.com/dirkkredinger/azeroth-tagebuch/issues
- **Spendenlink (Ko-fi):** https://ko-fi.com/mbmf17/
- **Bilder:** nur Screenshots der App mit Beispieldaten (ohne Blizzard-Karten und -Symbole)

## Beschreibung

---

**Azeroth-Tagebuch** keeps a diary for each of your characters. The addon quietly records what happens while you play – the free companion app for **macOS and Windows** turns it into a dashboard.

### What the addon records
- Quests accepted and turned in, level-ups, achievements, deaths and your own notes (`/tb notiz <text>`)
- Zones and travel routes (on foot, mounted, flying, taxi)
- Dungeons, delves and raids: runs, bosses, Mythic+ keys and timers
- Boss abilities from the Adventure Guide, per role and spec
- Loot per enemy (for drop rates), gear changes, item level and talents
- Bags, bank, warband bank and guild bank
- Total playtime (`/played`, read quietly on login)
- It switches on the official combat log, which the app uses for damage, healing and boss fights (`/tb kampflog aus` turns it off)

### What the app shows
Overview of all characters, quests, a map with your routes, timeline, statistics, damage and healing (live), gear, instances, **boss guide that opens when you enter an instance**, loot with drop rates across all characters, storage search („where is …?") and class guides on Wowhead.

**Download the app:** https://github.com/dirkkredinger/azeroth-tagebuch/releases
Mac also via Homebrew: `brew install --cask dirkkredinger/tap/azeroth-tagebuch`

### Safe to use
The addon **only records** – it automates nothing and never plays for you. The app only reads files from your disk (SavedVariables and the combat log) and never touches the running game. It ships no Blizzard artwork: maps and icons are read from your own WoW installation.

### Commands
`/tb` overview · `/tb stats` · `/tb notiz <text>` · `/tb kampflog an|aus` · `/tb bosse` (re-read the bosses of the current instance)

Free and open source (GPL-3.0). If you like it, you can support it on [Ko-fi](https://ko-fi.com/mbmf17/) ☕

---

🇩🇪 **Deutsch:** Das Addon schreibt Quests, Reisen, Instanzen, Bosse, Beute, Lager und Spielzeit je Charakter mit – nur Logging, keine Automatisierung. Die kostenlose App für macOS und Windows zeigt alles als Tagebuch, inklusive Boss-Guide beim Betreten einer Instanz und Dropraten über alle Charaktere.
