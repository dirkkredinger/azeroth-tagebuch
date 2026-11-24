"""Erfundenes Dungeonkompendium für die Beispieldaten (Bosse der Beispiel-Instanzen, keine echten Blizzard-Texte).

Wird von make_sample.py (deutsch) und sample_en.py (englische Übersetzung über EN) benutzt.
Flags wie C_EncounterJournal.GetSectionIconFlags: 0 Tank, 1 Schaden, 2 Heilung, 3 Heroisch, 4 Tödlich,
5 Wichtig, 6 Unterbrechbar, 7 Magie, 8 Fluch, 9 Gift, 10 Krankheit, 11 Wut, 12 Mythisch, 13 Blutung.
"""

OVERVIEW = 3

# Boss: (encounterID, Name, Beschreibung, Überblick, {Rolle: [Hinweise]}, [Fähigkeiten (Titel, Text, Flags, [Unterfähigkeiten])])
BOSSES = {
    9101: ("Amanikammer", [
        (3101, "Hexer Zul'jin-Ra", "Ein Hexendoktor, der die Geister der Amani-Ahnen an sich bindet.",
         "Zul'jin-Ra beschwört Ahnengeister und verflucht seine Gegner. Bei 50 % Gesundheit zieht er sich in einen Geisterkreis zurück.",
         {0: ["Dreht den Boss von der Gruppe weg, damit die Geisterklaue nur euch trifft."],
          1: ["Tötet die Ahnengeister schnell, bevor sie den Boss erreichen.", "Unterbrecht Geisterruf, sooft es geht."],
          2: ["Entfernt den Fluch der Ahnen schnell – er verringert die erhaltene Heilung stark."]},
         [("Geisterklaue", "Fügt dem aktuellen Ziel hohen körperlichen Schaden zu und verursacht eine Blutung.", [0, 13], []),
          ("Geisterruf", "Ruft zwei Ahnengeister herbei, die zum Boss laufen und ihn heilen.", [6, 5], [
              ("Ahnengeist", "Erreicht ein Geist den Boss, heilt er ihn um 5 % seiner Gesundheit.", [1], [])]),
          ("Fluch der Ahnen", "Verflucht einen Spieler und verringert die erhaltene Heilung um 50 % für 12 Sek.", [8, 2], []),
          ("Geisterkreis", "Bei 50 % Gesundheit: Der Boss wird unverwundbar, bis alle Totems zerstört sind.", [5], []),
          ("Seelensog", "Mythisch: Zieht alle Spieler zum Boss und fügt ihnen Schattenschaden zu.", [12, 4], [])]),
        (3102, "Akilzons Brut", "Drei junge Sturmadler, die ihr Nest gemeinsam verteidigen.",
         "Die drei Adler teilen sich ihre Gesundheit. Immer wieder lädt einer von ihnen einen Spieler mit Blitzen auf.",
         {0: ["Haltet alle drei Adler nah beieinander, damit der Flächenschaden alle trifft."],
          1: ["Bleibt verteilt, damit die Gewitterladung niemanden zusätzlich trifft."],
          2: ["Vor dem Sturmschrei die ganze Gruppe auffüllen."]},
         [("Gewitterladung", "Lädt einen Spieler auf. Nach 6 Sek. springt der Blitz auf alle Spieler in 8 Metern über.", [4, 7], []),
          ("Sturmschrei", "Fügt allen Spielern Naturschaden zu.", [2], []),
          ("Schnabelhieb", "Ein schneller Hieb auf das aktuelle Ziel.", [0], []),
          ("Federsturm", "Heroisch: Wirbelnde Federn bewegen sich durch den Raum.", [3], [])]),
        (3103, "Häuptling Mok'tar", "Der Anführer der Amanikammer und ein gefürchteter Krieger.",
         "Mok'tar gerät mit sinkender Gesundheit immer mehr in Raserei. Sein Kriegsstampfen betäubt alle Spieler in der Nähe.",
         {0: ["Spart eine Verteidigungsfähigkeit für den Kriegsrausch auf."],
          1: ["Bleibt beim Kriegsstampfen auf Abstand."],
          2: ["Während des Kriegsrausches steigt der Schaden am Tank stark an."]},
         [("Kriegsrausch", "Mok'tar gerät in Wut und verursacht 30 % mehr Schaden.", [11, 0], []),
          ("Kriegsstampfen", "Betäubt alle Spieler in 10 Metern für 3 Sek.", [5], []),
          ("Giftspeer", "Schleudert einen Speer, der ein Gift hinterlässt.", [9], []),
          ("Kampfruf", "Ruft zwei Amani-Krieger zu Hilfe.", [6, 1], [])]),
    ]),
    9102: ("Sonnenhof-Krypta", [
        (3111, "Wächterin Aelira", "Eine gefallene Hüterin, die die Krypta noch immer bewacht.",
         "Aelira wechselt zwischen Licht- und Schattenphasen. In der Schattenphase hinterlässt sie Leerenzonen.",
         {0: ["Zieht die Wächterin aus den Leerenzonen heraus."],
          1: ["Unterbrecht die Lichtwelle, sonst trifft sie die ganze Gruppe."],
          2: ["Die Seuche der Krypta muss schnell gereinigt werden."]},
         [("Lichtwelle", "Eine Welle heiligen Lichts, die allen Spielern Schaden zufügt.", [6, 4], []),
          ("Leerenzone", "Hinterlässt eine Zone, die Schattenschaden verursacht.", [5], []),
          ("Seuche der Krypta", "Eine Krankheit, die jede Sekunde Schaden verursacht.", [10, 2], [])]),
        (3112, "Der Bleiche Prinz", "Ein untoter Prinz, der die tiefsten Gewölbe der Krypta beherrscht.",
         "Der Prinz saugt seinen Gegnern das Leben aus und belegt sie mit Magie.",
         {0: ["Der Lebensentzug heilt den Prinzen – setzt Verteidigungsfähigkeiten früh ein."],
          1: ["Bannt den Schattenschild vom Prinzen."],
          2: ["Bannt den Blutbann sofort."]},
         [("Lebensentzug", "Entzieht dem Tank Leben und heilt den Prinzen.", [0, 5], []),
          ("Blutbann", "Magie: Ein Spieler erleidet 8 Sek. lang Schattenschaden.", [7, 2], []),
          ("Schattenschild", "Ein magischer Schild, der 50 % des Schadens absorbiert.", [7, 1], []),
          ("Bleicher Schrei", "Mythisch: Furcht auf alle Spieler.", [12, 4, 6], [])]),
    ]),
}

EN = {
    "Ein Hexendoktor, der die Geister der Amani-Ahnen an sich bindet.": "A witch doctor who binds the spirits of the Amani ancestors.",
    "Zul'jin-Ra beschwört Ahnengeister und verflucht seine Gegner. Bei 50 % Gesundheit zieht er sich in einen Geisterkreis zurück.":
        "Zul'jin-Ra summons ancestral spirits and curses his foes. At 50% health he retreats into a spirit circle.",
    "Dreht den Boss von der Gruppe weg, damit die Geisterklaue nur euch trifft.": "Face the boss away from the group so Spirit Claw only hits you.",
    "Tötet die Ahnengeister schnell, bevor sie den Boss erreichen.": "Kill the ancestral spirits quickly before they reach the boss.",
    "Unterbrecht Geisterruf, sooft es geht.": "Interrupt Spirit Call whenever you can.",
    "Entfernt den Fluch der Ahnen schnell – er verringert die erhaltene Heilung stark.": "Remove Curse of the Ancestors quickly – it greatly reduces healing received.",
    "Fügt dem aktuellen Ziel hohen körperlichen Schaden zu und verursacht eine Blutung.": "Deals heavy physical damage to the current target and causes a bleed.",
    "Ruft zwei Ahnengeister herbei, die zum Boss laufen und ihn heilen.": "Summons two ancestral spirits that walk to the boss and heal him.",
    "Erreicht ein Geist den Boss, heilt er ihn um 5 % seiner Gesundheit.": "If a spirit reaches the boss, it heals him for 5% of his health.",
    "Verflucht einen Spieler und verringert die erhaltene Heilung um 50 % für 12 Sek.": "Curses a player, reducing healing received by 50% for 12 sec.",
    "Bei 50 % Gesundheit: Der Boss wird unverwundbar, bis alle Totems zerstört sind.": "At 50% health the boss becomes immune until all totems are destroyed.",
    "Mythisch: Zieht alle Spieler zum Boss und fügt ihnen Schattenschaden zu.": "Mythic: Pulls all players to the boss and deals Shadow damage.",
    "Drei junge Sturmadler, die ihr Nest gemeinsam verteidigen.": "Three young storm eagles defending their nest together.",
    "Die drei Adler teilen sich ihre Gesundheit. Immer wieder lädt einer von ihnen einen Spieler mit Blitzen auf.":
        "The three eagles share their health. Again and again one of them charges a player with lightning.",
    "Haltet alle drei Adler nah beieinander, damit der Flächenschaden alle trifft.": "Keep all three eagles close together so area damage hits them all.",
    "Bleibt verteilt, damit die Gewitterladung niemanden zusätzlich trifft.": "Stay spread so Thunder Charge doesn't hit anyone else.",
    "Vor dem Sturmschrei die ganze Gruppe auffüllen.": "Top off the whole group before Storm Screech.",
    "Lädt einen Spieler auf. Nach 6 Sek. springt der Blitz auf alle Spieler in 8 Metern über.": "Charges a player. After 6 sec the lightning jumps to all players within 8 yards.",
    "Fügt allen Spielern Naturschaden zu.": "Deals Nature damage to all players.",
    "Ein schneller Hieb auf das aktuelle Ziel.": "A quick strike at the current target.",
    "Heroisch: Wirbelnde Federn bewegen sich durch den Raum.": "Heroic: Whirling feathers move through the room.",
    "Der Anführer der Amanikammer und ein gefürchteter Krieger.": "The leader of the Amani Vault and a feared warrior.",
    "Mok'tar gerät mit sinkender Gesundheit immer mehr in Raserei. Sein Kriegsstampfen betäubt alle Spieler in der Nähe.":
        "Mok'tar becomes more and more frenzied as his health drops. His War Stomp stuns all nearby players.",
    "Spart eine Verteidigungsfähigkeit für den Kriegsrausch auf.": "Save a defensive cooldown for Frenzy.",
    "Bleibt beim Kriegsstampfen auf Abstand.": "Keep your distance during War Stomp.",
    "Während des Kriegsrausches steigt der Schaden am Tank stark an.": "Damage on the tank rises sharply during Frenzy.",
    "Mok'tar gerät in Wut und verursacht 30 % mehr Schaden.": "Mok'tar becomes enraged and deals 30% more damage.",
    "Betäubt alle Spieler in 10 Metern für 3 Sek.": "Stuns all players within 10 yards for 3 sec.",
    "Schleudert einen Speer, der ein Gift hinterlässt.": "Hurls a spear that leaves a poison behind.",
    "Ruft zwei Amani-Krieger zu Hilfe.": "Calls two Amani warriors for help.",
    "Eine gefallene Hüterin, die die Krypta noch immer bewacht.": "A fallen warden who still guards the crypt.",
    "Aelira wechselt zwischen Licht- und Schattenphasen. In der Schattenphase hinterlässt sie Leerenzonen.":
        "Aelira alternates between light and shadow phases. In the shadow phase she leaves void zones behind.",
    "Zieht die Wächterin aus den Leerenzonen heraus.": "Pull the warden out of the void zones.",
    "Unterbrecht die Lichtwelle, sonst trifft sie die ganze Gruppe.": "Interrupt Wave of Light, or it hits the whole group.",
    "Die Seuche der Krypta muss schnell gereinigt werden.": "Crypt Plague must be cleansed quickly.",
    "Eine Welle heiligen Lichts, die allen Spielern Schaden zufügt.": "A wave of holy light that damages all players.",
    "Hinterlässt eine Zone, die Schattenschaden verursacht.": "Leaves a zone that deals Shadow damage.",
    "Eine Krankheit, die jede Sekunde Schaden verursacht.": "A disease that deals damage every second.",
    "Ein untoter Prinz, der die tiefsten Gewölbe der Krypta beherrscht.": "An undead prince who rules the deepest vaults of the crypt.",
    "Der Prinz saugt seinen Gegnern das Leben aus und belegt sie mit Magie.": "The prince drains the life of his foes and afflicts them with magic.",
    "Der Lebensentzug heilt den Prinzen – setzt Verteidigungsfähigkeiten früh ein.": "Life Drain heals the prince – use defensive cooldowns early.",
    "Bannt den Schattenschild vom Prinzen.": "Dispel Shadow Shield from the prince.",
    "Bannt den Blutbann sofort.": "Dispel Blood Curse immediately.",
    "Entzieht dem Tank Leben und heilt den Prinzen.": "Drains life from the tank and heals the prince.",
    "Magie: Ein Spieler erleidet 8 Sek. lang Schattenschaden.": "Magic: A player takes Shadow damage for 8 sec.",
    "Ein magischer Schild, der 50 % des Schadens absorbiert.": "A magic shield that absorbs 50% of damage taken.",
    "Mythisch: Furcht auf alle Spieler.": "Mythic: Fears all players.",
    # Titel
    "Geisterklaue": "Spirit Claw", "Geisterruf": "Spirit Call", "Ahnengeist": "Ancestral Spirit", "Fluch der Ahnen": "Curse of the Ancestors",
    "Geisterkreis": "Spirit Circle", "Seelensog": "Soul Pull", "Gewitterladung": "Thunder Charge", "Sturmschrei": "Storm Screech",
    "Schnabelhieb": "Beak Strike", "Federsturm": "Feather Storm", "Kriegsrausch": "War Frenzy", "Kriegsstampfen": "War Stomp",
    "Giftspeer": "Poison Spear", "Kampfruf": "Battle Cry", "Lichtwelle": "Wave of Light", "Leerenzone": "Void Zone",
    "Seuche der Krypta": "Crypt Plague", "Lebensentzug": "Life Drain", "Blutbann": "Blood Curse", "Schattenschild": "Shadow Shield",
    "Bleicher Schrei": "Pale Scream", "Überblick": "Overview", "Tanks": "Tanks", "Schadensverursacher": "Damage Dealers", "Heiler": "Healers",
    "Fähigkeiten": "Abilities",
}

ROLE_TITLE = {0: "Tanks", 1: "Schadensverursacher", 2: "Heiler"}


def journal(t):
    """Tabelle wie AzerothTagebuchDB.journal"""
    sid = [40000]

    def nid():
        sid[0] += 1
        return sid[0]

    def ability(title, text, flags, subs, lv):
        out = [{"id": nid(), "lv": lv, "t": title, "d": text, "ht": 0, "fl": flags}]
        for s in subs:
            out += ability(*s, lv + 1)
        return out

    inst = {}
    for iid, (name, bosses) in BOSSES.items():
        enc = []
        for k, (deid, bname, desc, overview, roles, abilities) in enumerate(bosses):
            secs = [{"id": nid(), "lv": 0, "t": "Überblick", "d": overview, "ht": OVERVIEW}]
            for role in (0, 2, 1):
                secs.append({"id": nid(), "lv": 1, "t": ROLE_TITLE[role], "ht": OVERVIEW, "fl": [role]})
                for tip in roles[role]:
                    secs.append({"id": nid(), "lv": 2, "t": "", "d": tip, "ht": OVERVIEW})
            for a in abilities:
                secs += ability(*a, 0)
            enc.append({"id": 2000 + deid, "deid": deid, "n": bname, "d": desc, "s": secs})
        inst[iid - 8000] = {"n": name, "map": iid, "did": 23, "t": t, "enc": enc}
    return {"v": 1, "loc": "deDE", "build": 120105, "inst": inst}
