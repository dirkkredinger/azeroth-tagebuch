"""Übersetzt die Beispieldaten ins Englische (wie sie ein englischer WoW-Client schreiben würde).

python3 tools/sample_en.py kern/beispiel/Beispiel.lua > kern/beispiel/Beispiel_en.lua
python3 tools/sample_en.py kern/beispiel/BeispielKampflog.txt > kern/beispiel/BeispielKampflog_en.txt

Ersetzt wird nur innerhalb von "…" – Schlüssel und Kürzel bleiben unberührt.
"""
import re, sys

EN = {
    # Orte
    "Immersangwald": "Eversong Woods", "Silbermond": "Silvermoon", "Sonnenzornturm": "Sunfury Spire",
    "Falkenwacht": "Falconwing Square", "Morgenruhs Hain": "Dawnrest Grove", "Verseuchte Lichtung": "Blighted Glade",
    "Amani-Pass": "Amani Pass", "Ruinen von Morgenstern": "Ruins of Morningstar",
    # Instanzen, Bosse, Schwierigkeit
    "Amanikammer": "Amani Vault", "Sonnenhof-Krypta": "Sunhall Crypt", "Schimmerhöhle": "Glimmer Cavern",
    "Pilzgrotte": "Fungal Grotto", "Hexer Zul'jin-Ra": "Hexer Zul'jin-Ra", "Akilzons Brut": "Brood of Akilzon",
    "Häuptling Mok'tar": "Chieftain Mok'tar", "Wächterin Aelira": "Warden Aelira", "Der Bleiche Prinz": "The Pale Prince",
    "Kristallfresser": "Crystal Devourer", "Morchelmutter": "Mother Morel",
    "Heroisch": "Heroic", "Mythisch+": "Mythic+", "Tiefen": "Delves",
    # Gegner
    "Verdorbener Luchs": "Corrupted Lynx", "Leerenwandler": "Voidwalker", "Amani-Späher": "Amani Scout",
    "Schattenpirscher": "Shadowstalker", "Wilder Falke": "Wild Hawk", "Splitterkreatur": "Shard Creature",
    # Beute und Lager
    "Zerfetztes Luchsfell": "Torn Lynx Pelt", "Scharfe Kralle": "Sharp Claw", "Pirschermantel": "Stalker's Cloak",
    "Leerensplitter": "Void Shard", "Flimmernder Staub": "Shimmering Dust", "Ring des Abgrunds": "Ring of the Abyss",
    "Leinenstoff": "Linen Cloth", "Trollknochen": "Troll Bone", "Amani-Armschienen": "Amani Bracers",
    "Schattenhafte Klaue": "Shadowy Claw", "Zähes Fleisch": "Tough Meat", "Glänzende Feder": "Shiny Feather",
    "Splitterkern": "Shard Core", "Kettenhemd des Wächters": "Warden's Chainmail", "Klinge der Morgenröte": "Blade of the Dawn",
    "Heiltrank": "Healing Potion", "Amethyst": "Amethyst",
    "Taschen": "Bags", "Fach 1": "Tab 1", "Handwerk": "Crafting", "Kriegsmeute 1": "Warband 1", "Sammlung": "Collection",
    "Allgemein": "General", "Ausrüstung": "Gear", "Offiziere": "Officers",
    # Ausrüstung (Präfix + Teil)
    "Sonnenzorn-": "Sunfury ", "Morgenruh-": "Dawnrest ", "Amani-": "Amani ", "Leerengezeichnete ": "Voidmarked ",
    "Falkenwacht-": "Falconwing ", "Immersang-": "Eversong ",
    "Halskette": "Necklace", "Schulterstücke": "Shoulderguards", "Umhang": "Cloak", "Brustplatte": "Breastplate",
    "Leinenhemd": "Linen Shirt", "Armschienen": "Bracers", "Handschuhe": "Gauntlets", "Gürtel": "Girdle",
    "Beinschützer": "Legguards", "Stiefel": "Boots", "Siegelring": "Signet", "Talisman": "Talisman", "Perle": "Pearl",
    "Klinge": "Blade", "Streitaxt": "Battleaxe",
    # Quests, Erfolge, Notizen
    "Rückkehr nach Quel'Thalas": "Return to Quel'Thalas", "Das Licht am Sonnenbrunnen": "The Light at the Sunwell",
    "Verdorbene Wurzeln": "Tainted Roots", "Luchse im Unterholz": "Lynxes in the Undergrowth",
    "Heimkehr der Sin'dorei": "Homecoming of the Sin'dorei", "Schatten über dem Hain": "Shadows over the Grove",
    "Die verschwundene Späherin": "The Missing Scout", "Splitter der Leere": "Shards of the Void",
    "Bedrohung aus der Leere": "Threat from the Void", "Die Trolle von Zul'Aman": "The Trolls of Zul'Aman",
    "Opfergaben für Akil'zon": "Offerings for Akil'zon", "Federn des Adlers": "Feathers of the Eagle",
    "Der Pfad des Luchses": "The Path of the Lynx", "Ein Ruf aus Harandar": "A Call from Harandar",
    "Ärger an der Grenze": "Trouble at the Border", "Wildes Blutdistelkraut": "Wild Bloodthistle",
    "Ein Brief für Falkenwacht": "A Letter for Falconwing Square", "Die Schatzkiste am See": "The Treasure Chest by the Lake",
    "Brücke nach Zul'Aman": "Bridge to Zul'Aman", "Stufe 80": "Level 80",
    "Endlich wieder in Silbermond. Die Stadt ist kaum wiederzuerkennen.": "Finally back in Silvermoon. The city is barely recognizable.",
    "Bin gegen den Leerenwandler gestorben. Nächstes Mal Gottesschild früher!": "Died to the Voidwalker. Divine Shield earlier next time!",
    "Morgen geht es nach Harandar.": "Off to Harandar tomorrow.",
    "Zwei Tode hintereinander. Ich brauche bessere Ausrüstung.": "Two deaths in a row. I need better gear.",
    # Charaktere, Talente, Fähigkeiten
    "Vergeltung": "Retribution", "Furor": "Fury", "Blutelf": "Blood Elf", "Krieger": "Warrior",
    "Questen": "Questing", "Leveln": "Leveling", "Hüter des Lichts": "Keepers of the Light",
    "Beispieltext: Ein Streiter des Lichts, der mit Zweihandwaffen und heiligem Zorn kämpft.":
        "Sample text: A champion of the Light who fights with two-handed weapons and holy wrath.",
    "Beispieltext: Ein wütender Berserker, der mit zwei Waffen gleichzeitig zuschlägt.":
        "Sample text: A raging berserker who strikes with two weapons at once.",
    "Richturteil": "Judgment", "Klingenschlag": "Blade of Justice", "Lichtsturm": "Divine Storm",
    "Zornesglut": "Wake of Ashes", "Wort der Gnade": "Word of Glory", "Blutdurst": "Bloodthirst",
    "Wutschlag": "Raging Blow", "Raserei": "Rampage", "Vollstrecken": "Execute", "Siegesrausch": "Victory Rush",
    "Unbekannt": "Unknown", "deDE": "enUS",
}
KEYS = sorted(EN, key=len, reverse=True)

def tr(s: str) -> str:
    for k in KEYS:
        if k in s:
            s = s.replace(k, EN[k])
    return s

if __name__ == "__main__":
    text = open(sys.argv[1], encoding="utf-8", newline="").read()
    sys.stdout.write(re.sub(r'"((?:[^"\\\n]|\\.)*)"', lambda m: '"' + tr(m.group(1)) + '"', text))
