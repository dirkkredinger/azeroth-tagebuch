"""Erzeugt Beispiel-SavedVariables im WoW-Format für die App."""
import math, random, sys, zlib

random.seed(7)
T0 = 1763625600 + 18 * 3600  # 20.11.2025 abends (nur Demo)

MAPS = {
    2537: ("Quel'Thalas", None, 2),
    2395: ("Immersangwald", 2537, 3),
    2393: ("Silbermond", 2395, 4),
    2437: ("Zul'Aman", 2537, 3),
    2413: ("Harandar", 2537, 3),
}

def lua(v, ind=0):
    pad = "\t" * ind
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int,)): return str(v)
    if isinstance(v, float): return repr(round(v, 4))
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        out = "{\n"
        for k, item in enumerate(v, 1):
            out += pad + "\t" + lua(item, ind + 1) + ", -- [%d]\n" % k
        return out + pad + "}"
    if isinstance(v, dict):
        out = "{\n"
        for k, item in v.items():
            key = "[%d]" % k if isinstance(k, int) else '["%s"]' % k
            out += pad + "\t" + key + " = " + lua(item, ind + 1) + ",\n"
        return out + pad + "}"
    raise TypeError(v)

class Sim:
    def __init__(self, level, money, ilvl=590.0):
        self.ev, self.t, self.level, self.money = [], T0, level, money
        self.ilvl = ilvl
        self.m, self.x, self.y = 2393, 0.55, 0.6
        self.cur_inst = None
    def add(self, e, **kw):
        if e in ("tod", "notiz", "erfolg"): self.t += 45
        d = {"t": self.t, "e": e}
        d.update(kw)
        if "m" not in d:
            d.update(m=self.m)
            if self.x is not None: d.update(x=round(self.x, 4), y=round(self.y, 4))
        self.ev.append(d)
    def walk(self, tx, ty, mode="zu_fuss", speed=0.006):
        steps = max(2, int(math.hypot(tx - self.x, ty - self.y) / speed))
        sx, sy = self.x, self.y
        for k in range(1, steps + 1):
            f = k / steps
            self.x = sx + (tx - sx) * f + random.uniform(-0.004, 0.004)
            self.y = sy + (ty - sy) * f + random.uniform(-0.004, 0.004)
            self.x, self.y = min(max(self.x, 0.02), 0.98), min(max(self.y, 0.02), 0.98)
            self.t += 10
            self.add("pos", mo=mode)
    def zone(self, m, z, sz="", x=None, y=None, **kw):
        self.m = m
        if x is not None: self.x, self.y = x, y
        self.add("zone", z=z, sz=sz, **kw)

def session(sim, start, plan):
    sim.t = start
    s_money = sim.money
    sim.add("login", lv=sim.level, g=sim.money)
    sim.t += 5
    sim.add("ausr", il=sim.ilvl, ilg=sim.ilvl + 3.5, lv=sim.level)
    t_start = sim.t
    plan(sim)
    sim.t += 30
    sim.add("logout", dauer=sim.t - t_start, g=sim.money, dg=sim.money - s_money)

QID = [90000]
def quest(sim, name, zone, kind="Normal", xp=None, gold=None, accept_only=False):
    QID[0] += 1
    q = QID[0]
    sim.t += 5
    sim.add("quest_an", q=q, n=name, c=kind, z=zone)
    if accept_only: return q
    return q

# Erfundene Gegner mit Beutetabellen (Symbole sind FileDataIDs aus der WoW-Installation)
MOBS = {
    "Verdorbener Luchs": (240001, [("Zerfetztes Luchsfell", 1, 134366, 0.85), ("Scharfe Kralle", 0, 134297, 0.55),
                                   ("Pirschermantel", 2, 133754, 0.12)]),
    "Leerenwandler":     (240002, [("Leerensplitter", 1, 134075, 0.7), ("Flimmernder Staub", 0, 133726, 0.4),
                                   ("Ring des Abgrunds", 3, 133347, 0.06)]),
    "Amani-Späher":      (240003, [("Leinenstoff", 1, 132889, 0.65), ("Trollknochen", 0, 133726, 0.5),
                                   ("Amani-Armschienen", 2, 132606, 0.15)]),
    "Schattenpirscher":  (240004, [("Schattenhafte Klaue", 0, 134297, 0.6), ("Leinenstoff", 1, 132889, 0.35)]),
    "Wilder Falke":      (240005, [("Zähes Fleisch", 1, 133971, 0.75), ("Glänzende Feder", 1, 133726, 0.45)]),
    "Splitterkreatur":   (240006, [("Leerensplitter", 1, 134075, 0.8), ("Splitterkern", 2, 134123, 0.18)]),
}
GUIDN = [0]

def mob_guid(sim, npc):
    GUIDN[0] += 1
    return "Creature-0-1-%d-1-%d-%010X" % (sim.m, npc, 0x5000000 + GUIDN[0])

def loot(sim, mob):
    npc, table = MOBS[mob]
    items = []
    for item_name, q, icon, chance in table:
        if random.random() < chance:
            items.append({"id": 250000 + zlib.crc32(item_name.encode()) % 9999, "n": item_name, "q": q, "ic": icon,
                          "c": random.randint(1, 3) if q <= 1 else 1})
    sim.t += 4
    sim.add("beute", src=mob_guid(sim, npc), npc=npc, art="Creature", sn=mob, items=items, z=ZONE_NAMES.get(sim.m, sim.cur_inst or ""))

ZONE_NAMES = {2393: "Silbermond", 2395: "Immersangwald", 2437: "Zul'Aman", 2413: "Harandar"}
MOB_FOR_ZONE = {2393: ["Wilder Falke"], 2395: ["Verdorbener Luchs", "Leerenwandler", "Splitterkreatur"],
                2437: ["Amani-Späher", "Schattenpirscher", "Wilder Falke"]}

def turnin(sim, q, name, zone, kind="Normal", xp=None, gold=None):
    mob = random.choice(MOB_FOR_ZONE.get(sim.m, ["Wilder Falke"]))
    for _ in range(random.randint(2, 4)):
        sim.t += 40
        loot(sim, mob)
    sim.t += 5
    xp = xp if xp is not None else random.randint(8000, 22000)
    gold = gold if gold is not None else random.randint(30000, 180000)
    sim.money += gold
    sim.add("quest_ab", q=q, n=name, c=kind, xp=xp, g=gold, z=zone, lv=sim.level)

def levelup(sim):
    sim.level += 1
    sim.t += 2
    sim.add("level", lv=sim.level)
    gear(sim, random.uniform(5, 9))

GEAR_NAMES = {
    1: ("Helm", 133071), 2: ("Halskette", 133294), 3: ("Schulterstücke", 135033), 15: ("Umhang", 133754),
    5: ("Brustplatte", 132751), 4: ("Leinenhemd", 135030), 9: ("Armschienen", 132606), 10: ("Handschuhe", 132938),
    6: ("Gürtel", 132502), 7: ("Beinschützer", 134584), 8: ("Stiefel", 132539), 11: ("Siegelring", 133345),
    12: ("Ring", 133347), 13: ("Talisman", 133440), 14: ("Perle", 134123), 16: ("Klinge", 135349),
}
PREFIX = ["Sonnenzorn-", "Morgenruh-", "Amani-", "Leerengezeichnete ", "Falkenwacht-", "Immersang-"]

def make_item(slot, ilvl, q):
    name, icon = GEAR_NAMES[slot]
    if slot == 16 and getattr(make_item, "two", None): name, icon = make_item.two
    stats = {"aus": int(ilvl * 4)}
    stats[random.choice(["str", "str"])] = int(ilvl * 1.8) if slot not in (2, 11, 12, 13, 14, 4) else 0
    for k in random.sample(["krit", "tempo", "meist", "viel"], 2):
        stats[k] = int(ilvl * random.uniform(0.6, 1.1))
    stats = {k: v for k, v in stats.items() if v}
    if slot == 4: stats = {}
    return {"id": 230000 + slot * 100 + int(ilvl), "n": (random.choice(PREFIX) + name if slot != 4 else name), "q": q, "il": float(int(ilvl)),
            "ic": icon, "st": stats, "link": "[" + name + "]"}

def init_gear(sim):
    sim.gear = {}
    for slot in GEAR_NAMES:
        q = 1 if slot == 4 else random.choice([2, 3, 3, 4]) if slot != 16 else 4
        sim.gear[slot] = make_item(slot, sim.ilvl + random.uniform(-6, 6) if slot != 4 else 1, q)

def gear(sim, plus):
    sim.ilvl = round(sim.ilvl + plus, 1)
    sim.t += 3
    sim.add("ausr", il=sim.ilvl, ilg=sim.ilvl + 3.5, lv=sim.level)
    # ein bis zwei Plätze werden aufgewertet
    for slot in random.sample([s for s in GEAR_NAMES if s != 4], 2):
        old = sim.gear[slot]
        new = make_item(slot, sim.ilvl + random.uniform(2, 9), random.choice([3, 3, 4]))
        sim.gear[slot] = new
        sim.t += 2
        sim.add("gegenstand", slot=slot, id=new["id"], n=new["n"], q=new["q"], il=new["il"], ic=new["ic"],
                alt=old["n"], altil=old["il"])

DEMO_CODE = "DEMO-Talentcode-nur-Beispiel"

def talents(sim, sid, spec, role, loadout):
    sim.t += 3
    sim.add("talente", sid=sid, spec=spec, rolle=role, code=DEMO_CODE + "-" + str(sid), lo=loadout, lv=sim.level)

# ---------------- Charakter 1: Paladin ----------------
p = Sim(80, 4_350_000, 588.0)
init_gear(p)


# ---------------- Instanzen und Tiefen (erfunden) ----------------
INSTANCES = {
    "Amanikammer":       dict(iid=9101, it="party", bosses=[(3101, "Hexer Zul'jin-Ra"), (3102, "Akilzons Brut"), (3103, "Häuptling Mok'tar")],
                              mobs=["Amani-Späher", "Schattenpirscher"]),
    "Sonnenhof-Krypta":  dict(iid=9102, it="party", bosses=[(3111, "Wächterin Aelira"), (3112, "Der Bleiche Prinz")],
                              mobs=["Leerenwandler", "Splitterkreatur"]),
    "Schimmerhöhle":     dict(iid=9201, it="delve", bosses=[(3201, "Kristallfresser")], mobs=["Splitterkreatur"]),
    "Pilzgrotte":        dict(iid=9202, it="delve", bosses=[(3211, "Morchelmutter")], mobs=["Verdorbener Luchs"]),
}
BOSS_LOOT = [("Kettenhemd des Wächters", 3, 132624), ("Klinge der Morgenröte", 4, 135349), ("Ring des Abgrunds", 3, 133347),
             ("Splitterkern", 2, 134123), ("Leerensplitter", 1, 134075)]

def boss_loot(sim, eid, name):
    items = [{"id": 250000 + zlib.crc32(n.encode()) % 9999, "n": n, "q": q, "ic": ic, "c": 1}
             for n, q, ic in random.sample(BOSS_LOOT, random.randint(1, 2))]
    if random.random() < 0.6:
        items.append({"n": "Gold", "gold": True, "c": random.randint(150000, 900000)})
    sim.t += 6
    GUIDN[0] += 1
    sim.add("beute", src="Creature-0-1-%d-1-%d-%010X" % (sim.m, 260000 + eid, 0x6000000 + GUIDN[0]),
            npc=260000 + eid, art="Creature", sn=name, items=items, z=sim.cur_inst)

def run_instance(sim, name, did, diff, tier=None, ml=None, wipe=False, finish=True, extra=None):
    inf = INSTANCES[name]
    sim.cur_inst = name
    outside = (sim.m, sim.x, sim.y)
    sim.m, sim.x, sim.y = inf["iid"], None, None   # in der Instanz: eigene Karte, hier ohne Position
    t0 = sim.t
    d = dict(iid=inf["iid"], inst=name, it=inf["it"], did=did, diff=diff, lv=sim.level, il=sim.ilvl,
             grp=1 if inf["it"] == "delve" else 5)
    if tier: d["tier"] = tier
    if ml: d["ml"] = ml
    sim.add("zone", z=name, sz="", inst=name, it="scenario" if inf["it"] == "delve" else "party", diff=diff)
    sim.add("inst_an", **d)
    for i, (eid, boss) in enumerate(inf["bosses"]):
        for _ in range(random.randint(2, 4)):
            sim.t += random.randint(40, 90)
            loot(sim, random.choice(inf["mobs"]))
        if wipe and i == len(inf["bosses"]) - 1:
            sim.t += 60
            sim.add("boss", eid=eid, n=boss, did=did, ok=0, dauer=random.randint(70, 140), iid=inf["iid"], inst=name, grp=d["grp"])
            sim.add("tod", z=name, sz="")
        sim.t += random.randint(60, 150)
        sim.add("boss", eid=eid, n=boss, did=did, ok=1, dauer=random.randint(45, 160), iid=inf["iid"], inst=name, grp=d["grp"])
        boss_loot(sim, eid, boss)
    if finish:
        sim.t += 20
        f = dict(iid=inf["iid"], inst=name, art="szenario" if inf["it"] == "delve" else ("mythisch_plus" if ml else "dungeonbrowser"),
                 dauer=sim.t - t0)
        if ml:
            f.update(ml=ml, zeit=sim.t - t0, imzeit=1 if sim.t - t0 < 1900 else 0)
        sim.add("inst_fertig", **f)
    sim.t += 30
    sim.add("inst_ab", iid=inf["iid"], inst=name, dauer=sim.t - t0)
    sim.cur_inst = None
    sim.m, sim.x, sim.y = outside

def p_day1(s):
    s.zone(2393, "Silbermond", "Sonnenzornturm", 0.52, 0.58)
    talents(s, 70, "Vergeltung", "DAMAGER", "Questen")
    q1 = quest(s, "Rückkehr nach Quel'Thalas", "Silbermond", "Campaign")
    s.walk(0.62, 0.42)
    turnin(s, q1, "Rückkehr nach Quel'Thalas", "Silbermond", "Campaign", 25000, 150000)
    q2 = quest(s, "Das Licht am Sonnenbrunnen", "Silbermond", "Campaign")
    s.add("notiz", txt="Endlich wieder in Silbermond. Die Stadt ist kaum wiederzuerkennen.", z="Silbermond")
    s.walk(0.48, 0.18, "reittier", 0.01)
    turnin(s, q2, "Das Licht am Sonnenbrunnen", "Silbermond", "Campaign", 25000, 150000)
    s.add("taxi_start")
    s.zone(2395, "Immersangwald", "Falkenwacht", 0.45, 0.30)
    s.walk(0.42, 0.55, "taxi", 0.02)
    s.add("taxi_ende")
    q3 = quest(s, "Verdorbene Wurzeln", "Immersangwald")
    q4 = quest(s, "Luchse im Unterholz", "Immersangwald")
    s.walk(0.35, 0.62)
    s.walk(0.30, 0.70)
    turnin(s, q4, "Luchse im Unterholz", "Immersangwald")
    s.walk(0.38, 0.74)
    turnin(s, q3, "Verdorbene Wurzeln", "Immersangwald")
    levelup(s)
    s.add("erfolg", a=61001, n="Heimkehr der Sin'dorei", p=10)
    s.walk(0.50, 0.66, "reittier", 0.01)

def p_day2(s):
    s.zone(2395, "Immersangwald", "Morgenruhs Hain", 0.50, 0.66)
    for name in ["Schatten über dem Hain", "Die verschwundene Späherin", "Splitter der Leere"]:
        q = quest(s, name, "Immersangwald", "Campaign" if "Leere" in name else "Normal")
        s.walk(random.uniform(0.55, 0.8), random.uniform(0.45, 0.8), random.choice(["zu_fuss", "reittier"]), 0.008)
        turnin(s, q, name, "Immersangwald", "Campaign" if "Leere" in name else "Normal")
    s.add("tod", z="Immersangwald", sz="Verseuchte Lichtung")
    s.walk(0.70, 0.55, "zu_fuss", 0.01)
    q = quest(s, "Bedrohung aus der Leere", "Immersangwald", "WorldQuest")
    turnin(s, q, "Bedrohung aus der Leere", "Immersangwald", "WorldQuest", 18000, 400000)
    s.add("notiz", txt="Bin gegen den Leerenwandler gestorben. Nächstes Mal Gottesschild früher!", z="Immersangwald")
    s.walk(0.85, 0.40, "flug", 0.02)
    s.zone(2437, "Zul'Aman", "Amani-Pass", 0.15, 0.55)
    s.walk(0.30, 0.50, "flug", 0.02)
    s.walk(0.40, 0.42, "zu_fuss")
    q = quest(s, "Die Trolle von Zul'Aman", "Zul'Aman", "Campaign")
    s.walk(0.52, 0.38)
    turnin(s, q, "Die Trolle von Zul'Aman", "Zul'Aman", "Campaign", 30000, 220000)
    levelup(s)
    talents(s, 70, "Vergeltung", "DAMAGER", "Dungeon")

def p_day3(s):
    s.zone(2437, "Zul'Aman", "Amani-Pass", 0.52, 0.38)
    run_instance(s, "Amanikammer", 1, "Normal")
    run_instance(s, "Amanikammer", 2, "Heroisch", wipe=True)
    s.add("erfolg", a=61020, n="Heroisch: Amanikammer", p=10)
    run_instance(s, "Sonnenhof-Krypta", 2, "Heroisch")
    run_instance(s, "Schimmerhöhle", 208, "Tiefen", tier=3)
    run_instance(s, "Schimmerhöhle", 208, "Tiefen", tier=5, wipe=True)
    run_instance(s, "Pilzgrotte", 208, "Tiefen", tier=5)
    run_instance(s, "Amanikammer", 8, "Mythisch+", ml=4)
    run_instance(s, "Sonnenhof-Krypta", 8, "Mythisch+", ml=5, wipe=True)
    run_instance(s, "Pilzgrotte", 208, "Tiefen", tier=8, finish=False)
    gear(s, 11.5)
    s.zone(2437, "Zul'Aman", "Amani-Pass", 0.52, 0.38)
    for name in ["Opfergaben für Akil'zon", "Federn des Adlers", "Der Pfad des Luchses"]:
        q = quest(s, name, "Zul'Aman")
        s.walk(random.uniform(0.45, 0.85), random.uniform(0.25, 0.75), random.choice(["zu_fuss", "reittier", "flug"]), 0.009)
        turnin(s, q, name, "Zul'Aman")
    quest(s, "Ein Ruf aus Harandar", "Zul'Aman", "Campaign")
    s.add("notiz", txt="Morgen geht es nach Harandar.", z="Zul'Aman")

session(p, T0, p_day1)
session(p, T0 + 86400, p_day2)
session(p, T0 + 2 * 86400, p_day3)

# ---------------- Charakter 2: Krieger ----------------
make_item.two = ("Streitaxt", 132400)
k = Sim(78, 980_000, 565.0)
init_gear(k)

def k_day1(s):
    s.zone(2395, "Immersangwald", "Falkenwacht", 0.45, 0.30)
    talents(s, 72, "Furor", "DAMAGER", "Leveln")
    for name in ["Ärger an der Grenze", "Wildes Blutdistelkraut", "Ein Brief für Falkenwacht"]:
        q = quest(s, name, "Immersangwald")
        s.walk(random.uniform(0.25, 0.6), random.uniform(0.2, 0.5), random.choice(["zu_fuss", "reittier"]), 0.008)
        turnin(s, q, name, "Immersangwald")
    levelup(s)
    s.add("tod", z="Immersangwald", sz="Ruinen von Morgenstern")
    s.add("tod", z="Immersangwald", sz="Ruinen von Morgenstern")
    s.add("notiz", txt="Zwei Tode hintereinander. Ich brauche bessere Ausrüstung.", z="Immersangwald")
    s.walk(0.30, 0.25, "schwimmen", 0.005)
    q = quest(s, "Die Schatzkiste am See", "Immersangwald")
    turnin(s, q, "Die Schatzkiste am See", "Immersangwald", "Normal", 9000, 600000)

def k_day2(s):
    s.zone(2395, "Immersangwald", "Falkenwacht", 0.30, 0.25)
    s.walk(0.55, 0.35, "reittier", 0.012)
    levelup(s)
    s.add("erfolg", a=61005, n="Stufe 80", p=10)
    q = quest(s, "Brücke nach Zul'Aman", "Immersangwald", "Campaign")
    s.walk(0.88, 0.45, "flug", 0.02)
    turnin(s, q, "Brücke nach Zul'Aman", "Immersangwald", "Campaign", 0, 250000)
    run_instance(s, "Pilzgrotte", 208, "Tiefen", tier=2)
    run_instance(s, "Schimmerhöhle", 208, "Tiefen", tier=3)

session(k, T0 + 3600 * 4, k_day1)
session(k, T0 + 86400 + 3600 * 3, k_day2)

def char(name, realm, cls, clsl, race, racel, sim, spec, sid, desc, stat):
    return {"name": name, "realm": realm, "class": cls, "classLocal": clsl, "race": race,
            "raceLocal": racel, "faction": "Horde", "level": sim.level, "sex": 3,
            "spec": spec, "specID": sid, "role": "DAMAGER", "specDesc": desc, "primaryStat": stat,
            "talentCode": DEMO_CODE + "-" + str(sid), "ilvl": sim.ilvl, "gear": sim.gear,
            "money": sim.money, "created": T0, "events": sim.ev, "guild": "Hüter des Lichts-Antonidas"}

# Lager-Beispiele (Symbole: FileDataIDs aus der WoW-Installation)
STUFF = [("Leinenstoff", 1, 132889), ("Leerensplitter", 1, 134075), ("Zähes Fleisch", 1, 133971),
         ("Zerfetztes Luchsfell", 1, 134366), ("Trollknochen", 0, 133726), ("Scharfe Kralle", 0, 134297),
         ("Splitterkern", 2, 134123), ("Amethyst", 3, 134075), ("Heiltrank", 1, 133971)]

def storage(t, tabs, gold=None, by=None):
    out = {"t": t, "tabs": []}
    for name, entries in tabs:
        out["tabs"].append({"name": name, "items": [
            {"id": 260000 + zlib.crc32(n.encode()) % 9999, "n": n, "q": q, "ic": ic, "c": c, **({"il": il} if il else {})}
            for n, q, ic, c, il in entries]})
    if gold: out["g"] = gold
    if by: out["by"] = by
    return out

def stacks(k):
    return [(n, q, ic, random.choice([1, 5, 12, 20, 87, 200]), None) for n, q, ic in random.sample(STUFF, k)]

def gearstack(sim, k):
    return [(it["n"], it["q"], it["ic"], 1, it["il"] - random.randint(8, 25))
            for it in random.sample(list(sim.gear.values()), k)]

p_bags = storage(p.t, [("Taschen", stacks(6) + gearstack(p, 2))])
p_bank = storage(p.t - 3000, [("Fach 1", stacks(5) + gearstack(p, 3)), ("Handwerk", stacks(4))])
k_bags = storage(k.t, [("Taschen", stacks(4) + gearstack(k, 1))])
warband = storage(p.t - 2000, [("Kriegsmeute 1", stacks(5) + gearstack(k, 2)), ("Sammlung", stacks(3))], gold=12_500_000)
guild = storage(p.t - 1000, [("Allgemein", stacks(6)), ("Ausrüstung", gearstack(p, 4)), ("Offiziere", stacks(2))],
                gold=88_400_000, by="Lyraen-Antonidas")

db = {
    "version": 4,
    "warband": warband,
    "guilds": {"Hüter des Lichts-Antonidas": guild},
    "locale": "deDE",
    "maps": {mid: {"n": n, **({"p": par} if par else {}), "ty": ty} for mid, (n, par, ty) in MAPS.items()},
    "chars": {
        "Lyraen-Antonidas": char("Lyraen", "Antonidas", "PALADIN", "Paladin", "BloodElf", "Blutelf", p, "Vergeltung", 70,
                                 "Beispieltext: Ein Streiter des Lichts, der mit Zweihandwaffen und heiligem Zorn kämpft.", 1),
        "Brakk-Antonidas": char("Brakk", "Antonidas", "WARRIOR", "Krieger", "Orc", "Orc", k, "Furor", 72,
                                "Beispieltext: Ein wütender Berserker, der mit zwei Waffen gleichzeitig zuschlägt.", 1),
    },
}

db["chars"]["Lyraen-Antonidas"].update(bags=p_bags, bank=p_bank)
db["chars"]["Brakk-Antonidas"].update(bags=k_bags)

if __name__ == "__main__":
    sys.stdout.write("\nAzerothTagebuchDB = " + lua(db) + "\n")
