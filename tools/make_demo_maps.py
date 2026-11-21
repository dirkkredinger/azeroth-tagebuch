"""Zeichnet eigene Fantasy-Karten für die Beispieldaten (keine Blizzard-Grafik!).

python3 tools/make_demo_maps.py app/static/demo-karten

Die Karten sind frei erfunden und nur grob an die Stimmung der Zonen angelehnt
(Wald, Stadt, Dschungel). Alles ist SVG; Papierstruktur und raue Küsten
entstehen im Browser über SVG-Filter.
"""
import math, os, random, sys

W, H = 1002, 668   # Seitenverhältnis wie die Zonenkarten (1,5)


def noise_poly(cx, cy, r, n=60, rough=0.18, seed=0, sx=1.0, sy=1.0):
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(4)]
    pts = []
    for i in range(n):
        a = i / n * math.tau
        k = 1 + rough * (0.6 * math.sin(3 * a + ph[0]) + 0.3 * math.sin(5 * a + ph[1]) + 0.2 * math.sin(9 * a + ph[2])) \
            + rnd.uniform(-rough, rough) * 0.25
        pts.append((cx + math.cos(a) * r * k * sx, cy + math.sin(a) * r * k * sy))
    return pts


def smooth_path(pts, closed=True):
    """Catmull-Rom → kubische Bézier"""
    n = len(pts)
    d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[i]
        p1, p2 = pts[i], pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}"
    return d + (" Z" if closed else "")


def wobbly_line(points, seed, amp=14, steps=8):
    rnd = random.Random(seed)
    out = []
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        for s in range(steps):
            f = s / steps
            out.append((x0 + (x1 - x0) * f + rnd.uniform(-amp, amp) * (0 < s), y0 + (y1 - y0) * f + rnd.uniform(-amp, amp) * (0 < s)))
    out.append(points[-1])
    return out


def defs(theme):
    return f"""
<defs>
  <filter id="paper" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="3" seed="4" result="n"/>
    <feColorMatrix in="n" type="matrix" values="0 0 0 0 0.35  0 0 0 0 0.25  0 0 0 0 0.12  0 0 0 0.10 0"/>
    <feComposite in2="SourceGraphic" operator="in"/>
    <feBlend in="SourceGraphic" mode="multiply"/>
  </filter>
  <filter id="rough" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves="3" seed="9" result="t"/>
    <feDisplacementMap in="SourceGraphic" in2="t" scale="26"/>
  </filter>
  <filter id="soft"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="blotch" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.006 0.009" numOctaves="4" seed="{theme['seed']}" result="t"/>
    <feColorMatrix in="t" type="matrix" values="0 0 0 0 {theme['blotch'][0]}  0 0 0 0 {theme['blotch'][1]}  0 0 0 0 {theme['blotch'][2]}  0 0 0 0.55 -0.12"/>
    <feComposite in2="SourceGraphic" operator="in"/>
  </filter>
  <radialGradient id="vignette" cx="50%" cy="50%" r="72%">
    <stop offset="62%" stop-color="#000" stop-opacity="0"/><stop offset="100%" stop-color="#2a1a08" stop-opacity="0.55"/>
  </radialGradient>
  <linearGradient id="sea" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{theme['sea'][0]}"/><stop offset="1" stop-color="{theme['sea'][1]}"/>
  </linearGradient>
  <linearGradient id="land" x1="0" y1="0" x2="0.4" y2="1">
    <stop offset="0" stop-color="{theme['land'][0]}"/><stop offset="1" stop-color="{theme['land'][1]}"/>
  </linearGradient>
  <symbol id="tree" viewBox="-10 -16 20 22">
    <path d="M0,-15 C6,-10 9,-4 6,1 C4,4 -4,4 -6,1 C-9,-4 -6,-10 0,-15Z" fill="{theme['tree'][0]}" stroke="{theme['tree'][1]}" stroke-width="1.2"/>
    <path d="M0,2 L0,6" stroke="{theme['tree'][1]}" stroke-width="1.6"/>
  </symbol>
  <symbol id="mount" viewBox="-20 -22 40 24">
    <path d="M-19,1 L-3,-20 L4,-11 L8,-15 L19,1 Z" fill="{theme['mount'][0]}" stroke="#4a3520" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M-3,-20 L-1,-8 L4,-11 M8,-15 L7,-6" fill="none" stroke="#4a3520" stroke-width="1"/>
    <path d="M-3,-20 L4,-11 L8,-15 L19,1 L-1,1 L-1,-8 Z" fill="#000" opacity="0.18"/>
  </symbol>
</defs>"""


def compass(x, y, s=1.0):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        r = 46 * s if i % 2 == 0 else 20 * s
        pts.append(f"{x + math.cos(a) * r:.1f},{y + math.sin(a) * r:.1f}")
        a2 = a + math.pi / 8
        pts.append(f"{x + math.cos(a2) * 9 * s:.1f},{y + math.sin(a2) * 9 * s:.1f}")
    return f"""<g opacity="0.85">
  <circle cx="{x}" cy="{y}" r="{34 * s}" fill="none" stroke="#5a3d1c" stroke-width="1.5"/>
  <circle cx="{x}" cy="{y}" r="{38 * s}" fill="none" stroke="#5a3d1c" stroke-width="0.8"/>
  <polygon points="{' '.join(pts)}" fill="#c9a25a" stroke="#5a3d1c" stroke-width="1.2"/>
  <text x="{x}" y="{y - 52 * s}" text-anchor="middle" font-family="Georgia,serif" font-size="{18 * s}" font-weight="bold" fill="#5a3d1c">N</text>
</g>"""


def scatter(rnd, n, inside, sym, size, jitter=1.0):
    out = []
    tries = 0
    while len(out) < n and tries < n * 40:
        tries += 1
        x, y = rnd.uniform(20, W - 20), rnd.uniform(20, H - 20)
        if inside(x, y):
            s = size * rnd.uniform(0.75, 1.25) * jitter
            out.append((y, f'<use href="#{sym}" x="{x - s / 2:.1f}" y="{y - s:.1f}" width="{s:.1f}" height="{s * 1.1:.1f}"/>'))
    return [o for _, o in sorted(out)]


def in_poly(x, y, poly):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            c = not c
        j = i
    return c


def blob(cx, cy, r, seed, sx=1, sy=1):
    return noise_poly(cx, cy, r, 48, 0.28, seed, sx, sy)


def make(theme):
    rnd = random.Random(theme["seed"])
    land = noise_poly(W * theme["land_c"][0], H * theme["land_c"][1], 430, 90, 0.16, theme["seed"], 1.25, 0.95)
    on_land = lambda x, y: in_poly(x, y, land)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">', defs(theme)]
    # Meer + Papier
    parts.append(f'<rect width="{W}" height="{H}" fill="url(#sea)"/>')
    for k in range(1, 7):   # Wellenlinien
        y = k * H / 7
        parts.append(f'<path d="M0,{y:.0f} q40,-8 80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0 t80,0" '
                     f'fill="none" stroke="#fff" stroke-opacity="0.12" stroke-width="1.2"/>')
    # Küste: Flachwasser, Strand, Land
    d = smooth_path(land)
    parts.append(f'<g filter="url(#rough)">')
    parts.append(f'<path d="{d}" fill="{theme["shallow"]}" stroke="{theme["shallow"]}" stroke-width="44" stroke-linejoin="round" opacity="0.7"/>')
    parts.append(f'<path d="{d}" fill="#e8d3a0" stroke="#e8d3a0" stroke-width="12"/>')
    parts.append(f'<path d="{d}" fill="url(#land)" stroke="#6b4a24" stroke-width="2.2"/>')
    parts.append(f'<path d="{d}" fill="#fff" filter="url(#blotch)"/>')
    # Felder / Regionen
    for i, (fx, fy, fr, col) in enumerate(theme["regions"]):
        parts.append(f'<path d="{smooth_path(blob(W * fx, H * fy, fr, theme["seed"] + i * 7, 1.3, 0.9))}" fill="{col}" opacity="0.55"/>')
    parts.append('</g>')
    # See
    if theme.get("lake"):
        lx, ly, lr = theme["lake"]
        parts.append(f'<path filter="url(#rough)" d="{smooth_path(blob(W * lx, H * ly, lr, 77, 1.4, 0.8))}" fill="url(#sea)" stroke="#3d6c7a" stroke-width="2"/>')
    # Fluss
    for i, river in enumerate(theme["rivers"]):
        pts = wobbly_line([(W * x, H * y) for x, y in river], theme["seed"] + 30 + i, 10, 6)
        rd = smooth_path(pts, closed=False)
        parts.append(f'<path d="{rd}" fill="none" stroke="#e8d3a0" stroke-width="13" stroke-linecap="round" opacity="0.7"/>')
        parts.append(f'<path d="{rd}" fill="none" stroke="{theme["sea"][0]}" stroke-width="7" stroke-linecap="round"/>')
    # Straßen
    for i, road in enumerate(theme["roads"]):
        pts = wobbly_line([(W * x, H * y) for x, y in road], theme["seed"] + 50 + i, 7, 5)
        parts.append(f'<path d="{smooth_path(pts, closed=False)}" fill="none" stroke="#7a5228" stroke-width="2.4" '
                     f'stroke-dasharray="7 5" stroke-linecap="round" opacity="0.85"/>')
    # Wälder und Berge (nach y sortiert, damit sie sich richtig überdecken)
    forest_zones = [blob(W * x, H * y, r, theme["seed"] + 100 + i, 1.4, 0.9) for i, (x, y, r) in enumerate(theme["forests"])]
    mountain_zones = [blob(W * x, H * y, r, theme["seed"] + 200 + i, 1.5, 0.8) for i, (x, y, r) in enumerate(theme["mountains"])]
    items = []
    for z in forest_zones:
        items += scatter(rnd, theme["trees"] // max(1, len(forest_zones)), lambda x, y, z=z: on_land(x, y) and in_poly(x, y, z), "tree", 19)
    for z in mountain_zones:
        items += scatter(rnd, 26, lambda x, y, z=z: on_land(x, y) and in_poly(x, y, z), "mount", 42)
    parts += items
    # Siedlungen
    for x, y, big in theme["towns"]:
        X, Y = W * x, H * y
        if big:
            wall = noise_poly(X, Y, 46, 10, 0.08, 5, 1.2, 1.0)
            parts.append(f'<path d="{smooth_path(wall)}" fill="#d9c08a" stroke="#5a3d1c" stroke-width="3"/>')
            for k in range(7):
                a = k / 7 * math.tau
                parts.append(f'<rect x="{X + math.cos(a) * 52 - 5:.1f}" y="{Y + math.sin(a) * 44 - 5:.1f}" width="10" height="10" fill="#b0884a" stroke="#5a3d1c"/>')
            for k in range(9):
                bx, by = X + rnd.uniform(-34, 30), Y + rnd.uniform(-28, 24)
                parts.append(f'<rect x="{bx:.1f}" y="{by:.1f}" width="{rnd.uniform(7, 14):.1f}" height="{rnd.uniform(6, 11):.1f}" fill="{theme["roof"]}" stroke="#4a3520" stroke-width="0.8"/>')
            parts.append(f'<circle cx="{X:.1f}" cy="{Y:.1f}" r="9" fill="{theme["roof"]}" stroke="#4a3520" stroke-width="1.5"/>')
        else:
            for k in range(4):
                bx, by = X + rnd.uniform(-14, 10), Y + rnd.uniform(-10, 8)
                parts.append(f'<path d="M{bx:.1f},{by + 8:.1f} v-6 l5,-5 l5,5 v6 z" fill="{theme["roof"]}" stroke="#4a3520" stroke-width="0.9"/>')
    # Rahmen, Kompass, Struktur
    parts.append(compass(W - 78, H - 84, 0.9))
    parts.append(f'<rect width="{W}" height="{H}" fill="url(#vignette)"/>')
    parts.append(f'<rect width="{W}" height="{H}" fill="#fff" opacity="0.001" filter="url(#paper)"/>')
    parts.append(f'<rect x="7" y="7" width="{W - 14}" height="{H - 14}" fill="none" stroke="#3a2612" stroke-width="3"/>')
    parts.append(f'<rect x="13" y="13" width="{W - 26}" height="{H - 26}" fill="none" stroke="#c9a25a" stroke-width="1.2" opacity="0.8"/>')
    parts.append('</svg>')
    return "\n".join(parts)


THEMES = {
    # Waldland mit goldenem Laub, Küste im Westen
    2395: dict(seed=11, land_c=(0.56, 0.5), sea=("#5f9aa6", "#3f7380"), shallow="#8fc2c4", land=("#c9c27a", "#a7a85a"),
               blotch=(0.85, 0.55, 0.2), tree=("#d98a2b", "#6e3d12"), mount=("#c8b48a",), roof="#b8452f",
               regions=[(0.35, 0.7, 120, "#b7b35f"), (0.75, 0.3, 110, "#d4b36a")],
               forests=[(0.32, 0.62, 150), (0.62, 0.68, 120), (0.48, 0.28, 110), (0.82, 0.62, 90)],
               mountains=[(0.86, 0.22, 80)], trees=300, lake=(0.66, 0.44, 42),
               rivers=[[(0.12, 0.55), (0.3, 0.5), (0.45, 0.46), (0.62, 0.45)]],
               roads=[[(0.45, 0.3), (0.42, 0.55), (0.5, 0.66), (0.7, 0.55), (0.88, 0.45)], [(0.42, 0.55), (0.3, 0.7), (0.36, 0.75)]],
               towns=[(0.45, 0.3, False), (0.5, 0.66, False), (0.3, 0.72, False)]),
    # Stadt am Wasser
    2393: dict(seed=23, land_c=(0.5, 0.52), sea=("#5c94a8", "#3b6b82"), shallow="#93c3cc", land=("#d8c48e", "#c2ab70"),
               blotch=(0.8, 0.6, 0.3), tree=("#c98f34", "#6e3d12"), mount=("#cbb995",), roof="#a83a2a",
               regions=[(0.5, 0.45, 160, "#e0cf9f")],
               forests=[(0.2, 0.75, 80), (0.82, 0.72, 80)], mountains=[], trees=90, lake=None,
               rivers=[],
               roads=[[(0.52, 0.58), (0.62, 0.42)], [(0.52, 0.58), (0.48, 0.18)], [(0.52, 0.58), (0.3, 0.8)], [(0.52, 0.58), (0.8, 0.75)]],
               towns=[(0.52, 0.5, True), (0.62, 0.42, False), (0.48, 0.2, False)]),
    # Dschungel mit Gebirge
    2437: dict(seed=37, land_c=(0.5, 0.5), sea=("#4f8d8a", "#2f625e"), shallow="#7fb5a5", land=("#7fa35a", "#5d8443"),
               blotch=(0.2, 0.35, 0.1), tree=("#3f7a35", "#1f3d18"), mount=("#a39a7a",), roof="#8a5a2a",
               regions=[(0.3, 0.5, 120, "#6f9a4c"), (0.7, 0.4, 130, "#8aa865")],
               forests=[(0.25, 0.65, 130), (0.62, 0.7, 120), (0.75, 0.3, 90), (0.4, 0.3, 80)],
               mountains=[(0.5, 0.45, 110), (0.85, 0.6, 70)], trees=320, lake=None,
               rivers=[[(0.08, 0.3), (0.25, 0.4), (0.38, 0.55), (0.55, 0.85)]],
               roads=[[(0.15, 0.55), (0.3, 0.5), (0.4, 0.42), (0.52, 0.38), (0.7, 0.4), (0.85, 0.3)]],
               towns=[(0.52, 0.38, False), (0.15, 0.55, False), (0.85, 0.3, False)]),
    # Sumpfiges Hochland
    2413: dict(seed=41, land_c=(0.5, 0.5), sea=("#5a7f8a", "#37555f"), shallow="#89a9a0", land=("#9aa06a", "#7c8650"),
               blotch=(0.3, 0.3, 0.15), tree=("#5b8a4a", "#24401b"), mount=("#a89f82",), roof="#7a4a2a",
               regions=[(0.5, 0.5, 150, "#8f9a5e")], forests=[(0.3, 0.4, 120), (0.7, 0.65, 120)],
               mountains=[(0.75, 0.25, 90)], trees=220, lake=(0.45, 0.62, 60),
               rivers=[], roads=[[(0.2, 0.5), (0.5, 0.45), (0.8, 0.5)]], towns=[(0.5, 0.45, False)]),
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "app/static/demo-karten"
    os.makedirs(out, exist_ok=True)
    for mid, th in THEMES.items():
        with open(os.path.join(out, f"{mid}.svg"), "w", encoding="utf-8") as fh:
            fh.write(make(th))
    print("geschrieben:", ", ".join(f"{m}.svg" for m in THEMES))
