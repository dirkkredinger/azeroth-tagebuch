// Englische Texte. Schlüssel = deutscher Text aus der Oberfläche (siehe i18n.svelte.ts).
// Begriffe wie im englischen WoW-Client: Delves, Tier, Mythic+, Warband Bank, item level …

export const en: Record<string, string> = {
  // Reiter
  'Übersicht': 'Overview', 'Quests': 'Quests', 'Karte': 'Map', 'Zeitleiste': 'Timeline', 'Statistik': 'Statistics',
  'Kampf': 'Combat', 'Heilung': 'Healing', 'Ausrüstung': 'Gear', 'Instanzen': 'Dungeons', 'Beute': 'Loot',
  'Lager': 'Storage', 'Klasse': 'Class',

  // Instanzen & Tiefen
  'Stufe {n}': 'Level {n}', 'tier|Stufe {n}': 'Tier {n}', 'Mythisch +{n}': 'Mythic +{n}', 'von {name}': 'from {name}',
  'in {a} von {b} Läufen erbeutet': 'looted in {a} of {b} runs',
  'Klicken auf den Namen: auf Wowhead ansehen': 'Click the name to view on Wowhead',
  'Dungeon-Läufe': 'Dungeon runs', 'Tiefen': 'Delves', 'Schlachtzüge': 'Raids', 'Abgeschlossen': 'Completed',
  'Bosse besiegt': 'Bosses defeated', 'Gegenstände': 'Items', 'Gold': 'Gold', 'Alle': 'All', 'Dungeons': 'Dungeons',
  'Alle Charaktere': 'All characters', '{n}× betreten': 'entered {n}×', '{n}× abgeschlossen': 'completed {n}×',
  'beste Stufe {n}': 'best tier {n}', 'bester +{n}': 'best +{n}', 'Bosse': 'Bosses', '{n}× besiegt': 'defeated {n}×',
  '{n}× gescheitert': 'wiped {n}×', 'schnellster {d}': 'fastest {d}',
  'Noch keine Bossbegegnung erfasst.': 'No boss encounters recorded yet.', '{n} Stück': '{n} pcs',
  'Keine Beute erfasst.': 'No loot recorded.', 'Läufe': 'Runs', 'abgeschlossen': 'completed',
  'nicht abgeschlossen': 'not completed', 'in der Zeit': 'in time', 'über der Zeit': 'over time',
  '{n} Tod': '{n} death', '{n} Tode': '{n} deaths', 'Noch keine Instanzen erfasst': 'No dungeons recorded yet',
  'Ab Addon-Version 1.4 schreibt das Tagebuch mit, wann du einen Dungeon, eine Tiefe oder einen Schlachtzug betrittst, welche Bosse fallen, ob der Lauf abgeschlossen wurde (bei Tiefen mit Stufe, bei Mythisch+ mit Schlüsselstein) und was du dabei erbeutest.':
    'From addon version 1.4 on, the journal records when you enter a dungeon, delve or raid, which bosses fall, whether the run was completed (with tier for delves and keystone level for Mythic+) and what you looted.',
  'Letzte Läufe': 'Recent runs', '{n} Gegenstand': '{n} item', '{n} Gegenstände': '{n} items',
  '{n} Boss': '{n} boss', '{n} Bosse': '{n} bosses', 'Instanzläufe': 'Instance runs',
  'Dungeon': 'Dungeon', 'Tiefe': 'Delve', 'Schlachtzug': 'Raid', 'Szenario': 'Scenario', 'PvP': 'PvP', 'Instanz': 'Instance',

  // Beute
  'Droprate: {p} % ({a} von {b})': 'Drop rate: {p}% ({a} of {b})', 'insgesamt {n} Stück erbeutet': '{n} looted in total',
  'Gegner besiegt': 'Enemies defeated', 'Verschiedene Gegner': 'Different enemies', 'Geplündert': 'Looted',
  'Gegenstände erbeutet': 'Items looted', 'Seltene Funde (grün+)': 'Notable finds (green+)', 'Gegner': 'Enemies',
  'Vorkommen & Truhen': 'Nodes & chests', 'Kills': 'Kills', 'Zuletzt': 'Recent', 'Name': 'Name',
  'Gegner oder Gegenstand suchen': 'Search enemy or item', '{n}× geplündert': 'looted {n}×', '{a} von {b}': '{a} of {b}',
  'Keine Gegenstände.': 'No items.', 'Nie geplündert – kein Beutefenster erfasst.': 'Never looted – no loot window recorded.',
  'Noch keine Vorkommen geplündert': 'No nodes looted yet', 'Noch keine Beute erfasst': 'No loot recorded yet',
  'Besiegte Gegner kommen aus dem Kampflog, die Beute schreibt das Addon (ab Version 1.2) mit, sobald ein Beutefenster aufgeht – auch mit automatischem Plündern. Droprate = wie oft ein Gegenstand dabei war ÷ geplünderte Leichen dieses Gegners.':
    'Kills come from the combat log; the addon (version 1.2 and later) records loot whenever a loot window opens – auto loot included. Drop rate = how often an item dropped ÷ looted corpses of that enemy.',
  'Seltene Funde': 'Notable finds', 'Unbekannt': 'Unknown',

  // Statistik
  'Quests pro Tag': 'Quests per day', 'Spielzeit pro Tag': 'Playtime per day', 'Top-Zonen nach Quests': 'Top zones by quests',
  'Noch keine Daten': 'No data yet', 'Arten der Quests': 'Quest types', 'Stufenverlauf': 'Level progression',
  'Noch zu wenig Stufendaten': 'Not enough level data yet',

  // Kampf
  'Noch keine Kämpfe': 'No fights yet', 'Noch keine Heilung': 'No healing yet',
  'Die Statistik entsteht aus dem offiziellen Kampflog von WoW. Das Addon schaltet es beim Einloggen automatisch ein (abschaltbar mit /tb kampflog aus). Die App liest „Logs/WoWCombatLog….txt“ live mit – laufende Kämpfe siehst du hier, während du spielst.':
    'These statistics come from WoW’s official combat log. The addon turns it on when you log in (disable with /tb kampflog aus). The app reads “Logs/WoWCombatLog….txt” live – you see ongoing fights here while you play.',
  'Kämpfe': 'Fights', 'Schaden gesamt': 'Total damage', 'Heilung gesamt': 'Total healing', 'Ø {unit} gesamt': 'Avg. {unit} overall',
  'Ø {unit} letzte 10': 'Avg. {unit} last 10', 'Bester Kampf': 'Best fight', 'Erlittener Schaden': 'Damage taken',
  'Bosskämpfe': 'Boss fights', 'Überheilung': 'Overhealing', 'Davon Schilde': 'Of which shields', '{unit} je Kampf': '{unit} per fight',
  'Kampf Nr. (Linie: Schnitt der letzten 5, gold: Bosse)': 'Fight no. (line: average of last 5, gold: bosses)',
  '{unit} nach Stufe': '{unit} by level', 'Stufe': 'Level', '{unit} nach Gegenstandsstufe': '{unit} by item level',
  'Gegenstandsstufe (gestrichelt: Trend)': 'Item level (dashed: trend)', 'Stärkste Fähigkeiten': 'Top abilities',
  'Stärkste Heilzauber': 'Top heals', 'Letzte Kämpfe': 'Recent fights', 'besiegt': 'defeated', 'gescheitert': 'wiped',
  'GS {n}': 'ilvl {n}', 'Schaden': 'Damage', 'Erlitten': 'Taken', '{n}× gestorben': 'died {n}×',
  '{n} Gegner besiegt': '{n} enemies defeated', 'krit.': 'crit',

  // Lager
  'Taschen': 'Bags', 'Bank': 'Bank', 'Kriegsmeute': 'Warband', 'Gildenbank': 'Guild bank', 'Raster': 'Grid', 'Liste': 'List',
  'Gegenstand suchen': 'Search item', 'Stand: {d}': 'As of {d}', 'zuletzt gesehen von {name}': 'last seen by {name}',
  'gemeinsam für alle Charaktere des Accounts': 'shared by all characters of the account',
  '{name} · {n} Plätze belegt': '{name} · {n} slots used', 'leer': 'empty', 'Noch kein Inhalt erfasst': 'No contents recorded yet',
  'Kriegsmeutenbank': 'Warband bank',
  'Die Taschen speichert das Addon (ab Version 1.3) beim Ausloggen und beim Schließen der Bank.':
    'The addon (version 1.3 and later) saves your bags when you log out and when you close the bank.',
  'Öffne im Spiel einmal deine Bank – das Addon (ab Version 1.3) merkt sich dann den Inhalt.':
    'Open your bank in the game once – the addon (version 1.3 and later) then remembers its contents.',
  'Öffne im Spiel einmal die Bank mit dem Kriegsmeuten-Reiter. Der Inhalt gilt für alle Charaktere des Accounts.':
    'Open the bank with the Warband tab in the game once. Its contents are shared by all characters of the account.',
  'Öffne im Spiel einmal die Gildenbank – erfasst werden alle Fächer, die du sehen darfst.':
    'Open the guild bank in the game once – all tabs you are allowed to see are recorded.',
  'Dieser Charakter ist (laut Addon) in keiner Gilde.': 'This character is not in a guild (according to the addon).',

  // Karte
  'Karte {n}': 'Map {n}', 'Noch keine Reisewege': 'No routes yet',
  'Sobald du mit dem Addon unterwegs warst, erscheint hier deine Route.': 'Once you have travelled with the addon, your route appears here.',
  'Zone': 'Zone', 'Tag': 'Day', 'Alle Tage': 'All days', 'Meine Route': 'My route', 'Ganze Zone': 'Whole zone',
  'Quest': 'Quest', 'Tod': 'Death', 'Notiz': 'Note',
  'Kartenbild wird aus deiner WoW-Installation geladen …': 'Loading the map image from your WoW installation …',
  'Kein Kartenbild für diese Zone': 'No map image for this zone', '{n} Quests abgeschlossen': '{n} quests completed',
  '{n} Wegpunkte': '{n} waypoints', 'Zeitraum {d}': 'Time span {d}',
  'Fahre mit der Maus über eine Markierung für Details': 'Hover over a marker for details',
  'Reisezeit nach Fortbewegung (alle Zonen)': 'Travel time by mode (all zones)',
  'Zu Fuß': 'On foot', 'Reittier': 'Mount', 'Fliegen': 'Flying', 'Schwimmen': 'Swimming', 'Flugmeister': 'Flight master',

  // Zeitleiste
  'Noch keine Einträge.': 'No entries yet.', 'Ältere Tage anzeigen ({n})': 'Show older days ({n})',

  // Klasse
  'Rüstung': 'Armor', 'Ressource': 'Resource', 'Gegenstandsstufe': 'Item level', 'Spezialisierung': 'Specialization',
  'Die Beschreibung erscheint, sobald das Addon (ab Version 1.1) die Spezialisierung mitgeschrieben hat.':
    'The description appears once the addon (version 1.1 and later) has recorded your specialization.',
  'Primärwert': 'Primary stat', 'Guides & Talent-Builds (Wowhead)': 'Guides & talent builds (Wowhead)',
  'Die empfohlenen Builds stammen von Wowhead und öffnen sich im Browser. Den Build übernimmst du im Spiel über „Laden/Teilen → Importieren“.':
    'The recommended builds are from Wowhead and open in your browser. In the game, apply a build via “Loadouts → Import”.',
  'Noch keine Spezialisierung bekannt.': 'No specialization known yet.', 'Dein Talent-Build': 'Your talent build',
  'Kopiert': 'Copied', 'Code kopieren': 'Copy code',
  'Noch kein Talentcode – er wird vom Addon beim nächsten Einloggen gespeichert.': 'No talent code yet – the addon saves it the next time you log in.',
  'Verlauf: Talente & Ausrüstung': 'History: talents & gear',
  'Talent-Builds': 'Talent builds', 'Überblick': 'Overview', 'Rotation & Abklingzeiten': 'Rotation & cooldowns', 'Werte-Prioritäten': 'Stat priority',
  'Ausrüstung (Best in Slot)': 'Gear (best in slot)', 'Klassen-Guides': 'Class guides',
  'Meine Talente im Talentrechner': 'My talents in the talent calculator',
  'Tank': 'Tank', 'Heiler': 'Healer',
  'Platte': 'Plate', 'Leder': 'Leather', 'Kette': 'Mail', 'Stoff': 'Cloth',
  'Runen & Runenmacht': 'Runes & Runic Power', 'Zorn / Qual': 'Fury / Pain', 'Mana, Energie, Wut, Astrale Macht': 'Mana, Energy, Rage, Astral Power',
  'Mana & Essenz': 'Mana & Essence', 'Fokus': 'Focus', 'Mana': 'Mana', 'Energie, Chi, Mana': 'Energy, Chi, Mana',
  'Mana & Heilige Kraft': 'Mana & Holy Power', 'Mana / Wahnsinn': 'Mana / Insanity', 'Energie & Combopunkte': 'Energy & Combo Points',
  'Mana / Mahlstrom': 'Mana / Maelstrom', 'Mana & Seelensplitter': 'Mana & Soul Shards', 'Wut': 'Rage',
  'Untote Ritter, die Frost, Seuche und Blut beherrschen.': 'Undead knights who command frost, plague and blood.',
  'Wendige Jäger, die dämonische Kräfte gegen ihre Feinde wenden.': 'Agile hunters who turn demonic powers against their foes.',
  'Gestaltwandler, die jede Rolle übernehmen können.': 'Shapeshifters who can fill any role.',
  'Drachenblütige Zauberwirker mit aufladbaren Fähigkeiten.': 'Dragon-blooded spellcasters with empowered abilities.',
  'Fernkämpfer mit Tiergefährten und Fallen.': 'Ranged fighters with animal companions and traps.',
  'Gelehrte der Arkan-, Feuer- und Frostmagie.': 'Scholars of arcane, fire and frost magic.',
  'Kampfkünstler, die Chi lenken.': 'Martial artists who channel chi.',
  'Streiter des Lichts für Schutz, Heilung und Vergeltung.': 'Champions of the Light for protection, healing and retribution.',
  'Heiler und Schattenwirker.': 'Healers and wielders of shadow.',
  'Meister der Klingen, Gifte und Heimlichkeit.': 'Masters of blades, poisons and stealth.',
  'Rufen die Elemente und stellen Totems auf.': 'Call upon the elements and place totems.',
  'Beschwören Dämonen und lassen Gebrechen wirken.': 'Summon demons and inflict afflictions.',
  'Waffenmeister in Rüstung, im Angriff wie in der Verteidigung.': 'Armored weapon masters, in offense and defense alike.',

  // Quests
  'Quest {n}': 'Quest {n}', 'Art': 'Type', 'EP': 'XP', 'Datum': 'Date', 'Abgeschlossen ({n})': 'Completed ({n})',
  'Offen ({n})': 'Open ({n})', 'Quest oder Zone suchen': 'Search quest or zone', 'Normal': 'Normal',
  'Keine Quests gefunden': 'No quests found',
  'Kampagne': 'Campaign', 'Weltquest': 'World quest', 'Wichtig': 'Important', 'Legendär': 'Legendary', 'Berufung': 'Calling',
  'Meta': 'Meta', 'Wiederholbar': 'Repeatable', 'Questreihe': 'Questline', 'Bonusziel': 'Bonus objective', 'Bedrohung': 'Threat',

  // Ausrüstung
  'Auf Wowhead ansehen': 'View on Wowhead', 'Klicken: auf Wowhead ansehen': 'Click to view on Wowhead',
  'Noch keine Ausrüstung erfasst': 'No gear recorded yet',
  'Das Addon (ab Version 1.2) speichert deine angelegten Gegenstände beim Einloggen, bei jedem Wechsel und beim Ausloggen. Einmal /reload genügt.':
    'The addon (version 1.2 and later) saves your equipped items when you log in, on every change and when you log out. A single /reload is enough.',
  'Werte der Ausrüstung': 'Gear stats', 'Gegenstandsstufe im Verlauf': 'Item level over time',
  'Noch zu wenig Einträge': 'Not enough entries yet', 'Ausrüstungswechsel': 'Gear changes', 'ersetzt {name}': 'replaces {name}',
  'Noch keine Wechsel erfasst.': 'No changes recorded yet.',
  'Kopf': 'Head', 'Hals': 'Neck', 'Schultern': 'Shoulders', 'Hemd': 'Shirt', 'Brust': 'Chest', 'Taille': 'Waist', 'Beine': 'Legs',
  'Füße': 'Feet', 'Handgelenke': 'Wrists', 'Hände': 'Hands', 'Finger 1': 'Finger 1', 'Finger 2': 'Finger 2',
  'Schmuck 1': 'Trinket 1', 'Schmuck 2': 'Trinket 2', 'Rücken': 'Back', 'Waffenhand': 'Main hand', 'Schildhand': 'Off hand',
  'Wappenrock': 'Tabard',
  'Stärke': 'Strength', 'Beweglichkeit': 'Agility', 'Intellekt': 'Intellect', 'Ausdauer': 'Stamina', 'Krit': 'Crit',
  'Tempo': 'Haste', 'Meisterschaft': 'Mastery', 'Vielseitigkeit': 'Versatility',
  'Schlecht': 'Poor', 'Gewöhnlich': 'Common', 'Selten': 'Uncommon', 'Rar': 'Rare', 'Episch': 'Epic', 'Artefakt': 'Artifact',
  'Erbstück': 'Heirloom',
  'Gegenstandsstufe {n}': 'Item Level {n}', 'Anzahl: {n}': 'Count: {n}',

  // Leerer Zustand, Suche, Übersicht
  'Noch keine Tagebuch-Daten': 'No journal data yet',
  'Spiel mit aktiviertem Addon „Azeroth-Tagebuch“ und logg dich aus oder tippe /reload. Die App liest die Daten dann automatisch ein.':
    'Play with the “Azeroth-Tagebuch” addon enabled, then log out or type /reload. The app reads the data automatically.',
  'Gesucht wird in: {pfad}': 'Looking in: {pfad}',
  'Dieser Ordner existiert nicht – bitte den WoW-Ordner wählen.': 'This folder does not exist – please choose your WoW folder.',
  'Beispieldaten anzeigen': 'Show sample data', 'WoW-Ordner wählen …': 'Choose WoW folder …',
  'Suche: „{q}“': 'Search: “{q}”',
  '{a} im Lager · {b} Quests · {c} Gegenstände · {d} Gegner · {e} Notizen': '{a} in storage · {b} quests · {c} items · {d} enemies · {e} notes',
  'Nichts gefunden. Gesucht wird in Questnamen, Zonen, Beute, Gegnern, Notizen sowie Taschen und Banken aller Charaktere.':
    'Nothing found. The search covers quest names, zones, loot, enemies, notes and the bags and banks of all characters.',
  'Wo liegt …?': 'Where is …?', 'offen': 'open', 'Gegner & Vorkommen': 'Enemies & nodes', 'Notizen': 'Notes',
  'Höchste DPS': 'Highest DPS', '{name} gegen {gegner}': '{name} vs. {gegner}', 'Höchste HPS': 'Highest HPS',
  'Liebster Gegner': 'Favourite enemy', 'Bester Fund': 'Best find', 'von {name} · {p} % Droprate': 'from {name} · {p}% drop rate',
  'Längste Sitzung': 'Longest session', 'Reichster Charakter': 'Richest character', 'Charaktere': 'Characters',
  'Spielzeit gesamt': 'Total playtime', 'Gold gesamt': 'Total gold', 'Quests gesamt': 'Total quests',
  'Stufenaufstiege': 'Level-ups', 'Erfolge': 'Achievements', 'Tode': 'Deaths', 'Deine Helden': 'Your heroes',
  '{n} Quests': '{n} quests', '{n} Kämpfe': '{n} fights', 'zuletzt gespielt {when}': 'last played {when}',
  'Ruhmeshalle': 'Hall of fame', 'Spielzeit der letzten 14 Tage': 'Playtime of the last 14 days',
  'Gold je Charakter': 'Gold per character', 'Zuletzt bei allen Charakteren': 'Recently, across all characters',
  'Im Kampf': 'In combat', 'Allianz': 'Alliance', 'Quests abgeschlossen': 'Quests completed', 'Offene Quests': 'Open quests',
  'Spielzeit': 'Playtime', 'Gold aus Quests': 'Gold from quests', 'EP aus Quests': 'XP from quests',
  'Zonen besucht': 'Zones visited', 'Gold aktuell': 'Current gold', 'Deine Notizen': 'Your notes', 'Zuletzt passiert': 'Recent events',

  // Über, Seitenleiste, Werkzeugleiste
  'Version {v}': 'Version {v}',
  'Ein Tagebuch für deine World-of-Warcraft-Charaktere: Quests, Reisen, Kämpfe, Instanzen, Beute und Lager – automatisch aus dem Addon und dem Kampflog.':
    'A journal for your World of Warcraft characters: quests, travels, fights, dungeons, loot and storage – automatically from the addon and the combat log.',
  'Unterstütze das Projekt auf Ko-fi': 'Support the project on Ko-fi',
  'Das Tagebuch ist kostenlos und quelloffen. Wenn es dir gefällt, freue ich mich über einen Kaffee.':
    'The journal is free and open source. If you like it, I’d be happy about a coffee.',
  'Quellcode auf GitHub': 'Source code on GitHub', 'Neue Versionen': 'New versions', 'Fehler melden': 'Report a bug',
  'Sprache': 'Language',
  'Von dirkkredinger, entwickelt mit Unterstützung von Claude (Anthropic).': 'By dirkkredinger, developed with the help of Claude (Anthropic).',
  'Lizenz: GNU GPL v3.0. Inoffizielles Fan-Projekt, nicht mit Blizzard Entertainment verbunden. World of Warcraft ist eine Marke von Blizzard Entertainment, Inc. Karten und Symbole stammen aus deiner eigenen Spielinstallation und werden nicht mitgeliefert.':
    'License: GNU GPL v3.0. Unofficial fan project, not affiliated with Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc. Maps and icons come from your own game installation and are not distributed with the app.',
  'Schließen': 'Close', '{n} Charakter im Überblick': '{n} character at a glance', '{n} Charaktere im Überblick': '{n} characters at a glance',
  'Unterstützen': 'Support', 'Über': 'About', 'Lade …': 'Loading …', 'Geprüft {when}': 'Checked {when}', 'Min.': 'min',
  'Ordner „_retail_“ deiner WoW-Installation wählen': 'Choose the “_retail_” folder of your WoW installation',
  'Quests, Beute, Gegner, Lager suchen': 'Search quests, loot, enemies, storage',
  'Zur Übersicht aller Charaktere': 'Overview of all characters', 'SavedVariables und Kampflog neu einlesen': 'Re-read SavedVariables and combat log',
  'WoW-Ordner wählen': 'Choose WoW folder', 'Lade Tagebuch …': 'Loading journal …',

  // Tagebucheinträge
  'Eingeloggt (Stufe {lv})': 'Logged in (level {lv})', 'Eingeloggt': 'Logged in', 'Ausgeloggt nach {d}': 'Logged out after {d}',
  'Instanz betreten: {name}': 'Entered instance: {name}', 'Unterwegs in {ort}': 'Travelling in {ort}',
  'Quest angenommen: {name}': 'Quest accepted: {name}', 'Quest abgeschlossen: {name}': 'Quest completed: {name}',
  'Quest abgebrochen: {name}': 'Quest abandoned: {name}', 'Stufe {n} erreicht!': 'Reached level {n}!',
  'Erfolg errungen: {name}': 'Achievement earned: {name}', '({n} Punkte)': '({n} points)', 'Gestorben in {ort}': 'Died in {ort}',
  'Flug mit dem Flugmeister gestartet': 'Took a flight', 'Mit dem Flugmeister gelandet': 'Landed at the flight master',
  'Talente: {spec}': 'Talents: {spec}', 'Neu angelegt: {name}': 'Equipped: {name}', 'Beute von {von}': 'Loot from {von}',
  '(Stufe {n})': '(tier {n})', 'Instanz verlassen: {name}': 'Left instance: {name}', 'Abgeschlossen: {name}': 'Completed: {name}',
  'Boss besiegt: {name}': 'Boss defeated: {name}', 'Gescheitert an: {name}': 'Wiped on: {name}', '{n} EP': '{n} XP',
  'gerade eben': 'just now', 'Vorkommen #{n}': 'Node #{n}', 'Gegner #{n}': 'Enemy #{n}', 'Unbekannte Quelle': 'Unknown source',

  // Status der Desktop-App
  '{a} neue Einträge, {b} neue Kämpfe': '{a} new entries, {b} new fights',
  'Browser-Vorschau mit Beispieldaten': 'Browser preview with sample data', 'Fehler: {msg}': 'Error: {msg}',
  'Archiv konnte nicht gespeichert werden: {msg}': 'Could not save the archive: {msg}',
  'Noch keine Tagebuch-Daten gefunden': 'No journal data found yet', 'Alles aktuell': 'Up to date',
  'Beispieldaten – echte Daten mit „Neu einlesen“': 'Sample data – load your own data with “Re-read”', 'Lese Daten …': 'Reading data …',

  // Bosskämpfe
  'Noch keine Bossdaten': 'No boss data yet',
  'Ab Addon-Version 1.5 liest das Tagebuch beim Einloggen die Bosse und Fähigkeiten der aktuellen Saison aus dem Dungeonkompendium (und beim Betreten jeder anderen Instanz deren Bosse). WoW speichert sie beim Ausloggen oder nach /reload – danach erscheinen sie hier.':
    'From addon version 1.5 on, the journal reads the bosses and abilities of the current season from the Adventure Guide when you log in (and those of any other instance when you enter it). WoW saves them on logout or after /reload – after that they show up here.',
  'Du bist gerade in {name}.': 'You are in {name} right now.', 'Du bist hier': 'You are here',
  'Kampf läuft: {name}': 'Fighting: {name}', 'Kampf läuft': 'In combat', 'als Nächstes': 'up next',
  'Du kannst unterbrechen': 'You can interrupt', 'Kein Unterbrechen': 'No interrupt', 'Du entfernst: {list}': 'You remove: {list}',
  'Grundfähigkeiten der Spezialisierung, Talente nicht berücksichtigt': 'baseline spec abilities, talents not considered',
  'Ansicht als {role}': 'Viewing as {role}', 'beste {n} DPS': 'best {n} DPS', 'beste {n} HPS': 'best {n} HPS',
  'zuletzt {d}': 'last {d}', 'Noch nie gekämpft': 'Never fought', 'Mit World of Warcraft starten': 'Start with World of Warcraft', 'Öffnet das Tagebuch im Hintergrund, sobald WoW startet – falls es nicht schon läuft.': 'Opens the diary in the background as soon as WoW starts – unless it is already running.', 'Englisch': 'English', 'Deutsch': 'German', 'Die deutschen Guides leiten teils zu 4Fansites weiter.': 'The German guides sometimes redirect to 4Fansites.', 'Deine Beute': 'Your loot',
  'Tödlich / Wichtig': 'Deadly / important', 'Unterbrechen': 'Interrupt', 'Entfernen': 'Remove', 'Kannst du entfernen': 'You can remove',
  'Für dich als {role}': 'For you as {role}', 'Das Kompendium hat für diese Rolle keine eigenen Hinweise.': 'The Adventure Guide has no specific notes for this role.',
  'Keine besonders markierten Fähigkeiten.': 'No specially marked abilities.', 'Alle Fähigkeiten': 'All abilities',
  'Texte aus dem Dungeonkompendium deines WoW-Clients, ausgelesen vom Addon.': "Texts from your WoW client's Adventure Guide, read by the addon.",
  'Heroisch': 'Heroic', 'Mythisch': 'Mythic', 'Mythisch+': 'Mythic+', 'LFR': 'LFR', 'Zeitwanderung': 'Timewalking',
  'Tödlich': 'Deadly', 'Unterbrechbar': 'Interruptible', 'Magie': 'Magic', 'Fluch': 'Curse', 'Gift': 'Poison',
  'Krankheit': 'Disease', 'effekt|Wut': 'Enrage', 'Blutung': 'Bleed',
};
