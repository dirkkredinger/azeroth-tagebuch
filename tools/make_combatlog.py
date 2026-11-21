"""Erzeugt ein Beispiel-Kampflog (Format von WoWCombatLog.txt, erweitertes Logging) passend zu Beispiel.lua.

python3 tools/make_combatlog.py > Sources/WoWTagebuch/Resources/BeispielKampflog.txt

Zeitangaben stehen wie im echten Log in lokaler Zeit. Zauber- und Gegnernamen sind frei erfunden.
"""
import os, random, sys, time

sys.path.insert(0, os.path.dirname(__file__))
import make_sample as S  # erzeugt die Beispielcharaktere

random.seed(11)
lines = []

def ts(t):
    lt = time.localtime(t)
    ms = int((t - int(t)) * 1000)
    return "%d/%d/%d %02d:%02d:%02d.%03d-0" % (lt.tm_mon, lt.tm_mday, lt.tm_year, lt.tm_hour, lt.tm_min, lt.tm_sec, ms)

def emit(t, text):
    lines.append((t, ts(t) + "  " + text))

ZONES = {2393: "Silbermond", 2395: "Immersangwald", 2437: "Zul'Aman", 2413: "Harandar"}

CHARS = {
    "Lyraen-Antonidas": dict(guid="Player-1234-0A11CE01", name="Lyraen-Antonidas-EU", sim=S.p,
        attacks=[(20271, "Richturteil", 0x2, 1.0), (85256, "Klingenschlag", 0x2, 1.6), (53385, "Lichtsturm", 0x2, 1.3),
                 (255937, "Zornesglut", 0x6, 2.2)],
        heals=[(85673, "Wort der Gnade", 0x2, 3.0)], swing=True),
    "Brakk-Antonidas": dict(guid="Player-1234-0B22AC02", name="Brakk-Antonidas-EU", sim=S.k,
        attacks=[(23881, "Blutdurst", 0x1, 1.1), (85288, "Wutschlag", 0x1, 1.4), (184367, "Raserei", 0x1, 2.0),
                 (5308, "Vollstrecken", 0x1, 2.5)],
        heals=[(34428, "Siegesrausch", 0x1, 2.0)], swing=True),
}

MOBS = ["Verdorbener Luchs", "Leerenwandler", "Amani-Späher", "Schattenpirscher", "Wilder Falke", "Splitterkreatur"]

def adv(c, x, y, m, ilvl, hp=900000):
    return "%s,0000000000000000,%d,%d,40000,40000,30000,0,0,100,100,0,%.2f,%.2f,%d,1.57,%d" % (
        c["guid"], hp, hp, x * 1000, y * 1000, m, round(ilvl))

def mob_adv(guid, x, y, m):
    return "%s,0000000000000000,500000,1000000,0,0,0,0,-1,0,0,0,%.2f,%.2f,%d,0.0,82" % (guid, x * 1000, y * 1000, m)

def fight(key, start, ev, ilvl, length, mob, boss=False, die=False, guid=None):
    c = CHARS[key]
    m, x, y = ev.get("m", 2395), ev.get("x", 0.5), ev.get("y", 0.5)
    mob_guid = guid or "Creature-0-1-%d-1-%d-0000%06X" % (m, 299999, random.randint(0, 0xFFFFFF))
    me = '%s,"%s",0x511,0x0' % (c["guid"], c["name"])
    foe = '%s,"%s",0x10a48,0x0' % (mob_guid, mob)
    power = (ilvl - 560) / 40 + 1.0            # bessere Ausrüstung → mehr Schaden
    t = start
    while t < start + length:
        t += random.uniform(0.9, 1.6)
        if c["swing"] and random.random() < 0.5:
            amt = int(random.uniform(9000, 14000) * power)
            crit = random.random() < 0.25
            if crit: amt *= 2
            emit(t, "SWING_DAMAGE,%s,%s,%s,%d,%d,-1,1,0,0,0,%s,nil,nil,nil" % (me, foe, adv(c, x, y, m, ilvl), amt, amt, "1" if crit else "nil"))
        sid, sname, school, mult = random.choice(c["attacks"])
        amt = int(random.uniform(15000, 24000) * mult * power)
        crit = random.random() < 0.3
        if crit: amt *= 2
        emit(t + 0.2, 'SPELL_DAMAGE,%s,%s,%d,"%s",0x%x,%s,%d,%d,-1,%d,0,0,0,%s,nil,nil,nil' % (
            me, foe, sid, sname, school, adv(c, x, y, m, ilvl), amt, amt, school, "1" if crit else "nil"))
        # Schaden durch den Gegner
        hit = int(random.uniform(8000, 16000) * (1.8 if boss else 1.0))
        emit(t + 0.5, "SWING_DAMAGE,%s,%s,%s,%d,%d,-1,1,0,0,0,nil,nil,nil,nil" % (foe, me, mob_adv(mob_guid, x, y, m), hit, hit))
        if random.random() < 0.12:
            hid, hname, hschool, hmult = c["heals"][0]
            amt = int(random.uniform(30000, 45000) * hmult * power)
            over = int(amt * random.uniform(0, 0.4))
            emit(t + 0.7, 'SPELL_HEAL,%s,%s,%d,"%s",0x%x,%s,%d,%d,%d,0,%s' % (
                me, me, hid, hname, hschool, adv(c, x, y, m, ilvl), amt, amt, over, "1" if random.random() < 0.2 else "nil"))
    if die:
        emit(t + 1, 'UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,%s,0' % me)
    else:
        emit(t + 1, 'UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,%s,0' % foe)

for key, c in CHARS.items():
    sim = c["sim"]
    ilvl = sim.ev[0].get("il", 580)
    zone_m = None
    for ev in sim.ev:
        if ev["e"] == "ausr":
            ilvl = ev["il"]
        if ev["e"] == "login":
            emit(ev["t"] + 1, "COMBAT_LOG_VERSION,22,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,12.1.5,PROJECT_ID,1")
        if ev.get("m") and ev.get("m") != zone_m and ev["e"] in ("zone", "login"):
            zone_m = ev["m"]
            emit(ev["t"] + 2, 'ZONE_CHANGE,%d,"%s",0' % (zone_m, ZONES.get(zone_m, "Unbekannt")))
        if ev["e"] == "beute":
            # Kampf endet kurz vor dem Plündern, gleiche GUID wie im Beutefenster
            fight(key, ev["t"] - 34, ev, ilvl, random.uniform(12, 26), ev["sn"], guid=ev["src"])
            if random.random() < 0.3:   # ab und zu ein Gegner, der nicht geplündert wurde
                g = ev["src"][:-4] + "%04X" % random.randint(0, 0xFFFF)
                fight(key, ev["t"] + 8, ev, ilvl, random.uniform(10, 18), ev["sn"], guid=g)
        if ev["e"] == "tod":
            fight(key, ev["t"] - 40, ev, ilvl, 22, "Leerenwandler", die=True, guid="Creature-0-1-2395-1-240002-00099AAAA1")
        if ev["e"] == "zone" and ev.get("inst"):
            t0 = ev["t"] + 600
            emit(t0, 'ENCOUNTER_START,3071,"Akil\'zon",2,5,2575')
            fight(key, t0 + 1, ev, ilvl, 95, "Akil'zon", boss=True, guid="Creature-0-1-2437-1-240100-00099BBBB1")
            emit(t0 + 100, 'ENCOUNTER_END,3071,"Akil\'zon",2,5,1,99000')

lines.sort(key=lambda l: l[0])
sys.stdout.write("\n".join(l for _, l in lines) + "\n")
