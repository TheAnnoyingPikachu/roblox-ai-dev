"""Yokai enemies (src/night/Enemies.luau BUILD table 168-413). Each faces +Y (Roblox -Z), the way
the code's eyes and tongues point. Code keeps its PointLights, Fire and Trail on the root."""

import math

import kit as k
from mathutils import Vector


def lantern_yokai():
    """Chochin-obake: ribbed paper lantern split into a grin, one eye, long tongue."""
    paper = k.mat("paper", k.PAPER, var=0.08, scale=3, emit=0.5, rgb2=(255, 214, 160))
    lacquer = k.mat("lacquer", k.INK, var=0.12)
    band = k.mat("band", k.LACQUER, var=0.1)
    mouth = k.mat("mouth", (70, 8, 16), kind="flat", emit=0.3)
    tongue = k.mat("tongue", k.TONGUE, var=0.1, scale=4)
    white = k.mat("eye", k.WHITE, kind="flat")
    iris = k.mat("iris", (255, 190, 40), kind="flat", emit=1.0)
    pupil = k.mat("pupil", (10, 6, 10), kind="flat")
    tooth = k.mat("tooth", (250, 245, 230), kind="flat")
    zc, half, rmax = 2.75, 2.0, 1.75
    prof = []
    for i in range(17):
        z = zc - half + 2 * half * i / 16
        r = rmax * math.sqrt(max(0.0, 1 - ((z - zc) / (half * 1.08)) ** 2))
        prof.append((r * (0.95 if i % 2 else 1.0), z))
    body = k.lathe(prof, m=paper, n=20)
    cutter = k.sphere(1.0, (0, 1.75, 2.35), (0, 0, 0), m=mouth, scale=(1.45, 0.9, 0.48), seg=16, rings=8)
    k.boolean(body, cutter)
    k.apply_cuts()
    p = [body]
    p.append(k.lathe([(0.9, 4.65), (1.05, 4.75), (1.05, 4.95), (0.55, 5.1), (0, 5.12)], m=lacquer, n=16))
    p.append(k.lathe([(0, 0.4), (0.55, 0.42), (1.05, 0.6), (1.05, 0.8), (0.9, 0.9)], m=lacquer, n=16))
    p.append(k.tube([(-0.35, 0, 5.05), (-0.3, 0, 5.45), (0, 0, 5.62), (0.3, 0, 5.45), (0.35, 0, 5.05)], 0.07, m=lacquer, n=6))
    for z in (1.25, 4.25):
        r = rmax * math.sqrt(max(0.0, 1 - ((z - zc) / (half * 1.08)) ** 2)) + 0.03
        p.append(k.ring(r, z, 0.06, band, n=20, sides=4))
    # One big eye above the grin, slightly off-centre.
    p.append(k.sphere(0.72, (0.15, 1.38, 3.55), m=white, scale=(1, 0.62, 1), seg=14, rings=8))
    p.append(k.sphere(0.4, (0.15, 1.78, 3.55), m=iris, scale=(1, 0.4, 1), seg=12, rings=6))
    p.append(k.box((0.12, 0.08, 0.55), (0.15, 1.95, 3.55), m=pupil))
    for x in (-0.7, -0.35, 0.35, 0.7):
        p.append(k.cyl(0.11, 0.3, (x, 1.62, 2.66), (180, 0, 0), m=tooth, n=5, r2=0.0))
    # Long lolling tongue out of the grin, curling down in front.
    pts = [(0, 1.0, 2.25), (0, 1.9, 2.2), (0.1, 2.5, 1.8), (0.15, 2.7, 1.1), (0.05, 2.45, 0.55), (-0.1, 2.15, 0.45)]
    t = k.tube(pts, [0.32, 0.34, 0.32, 0.28, 0.22, 0.0], m=tongue, n=10)
    t.data.transform(k.Matrix.Translation((0, 0, 0)))
    p.append(t)
    return p


def kasa_obake():
    """Kasa-obake: red paper umbrella with ribs, one eye, a tongue and one leg in a geta sandal."""
    red = k.mat("red", (200, 45, 40), var=0.1, scale=3, kind="wood")
    paper = k.mat("paper", k.PAPER, var=0.06, scale=4)
    bamboo = k.mat("bamboo", (140, 100, 60), var=0.12, scale=6, kind="wood")
    ink = k.mat("ink", k.INK, var=0.1)
    under = k.mat("under", (120, 40, 34), var=0.1, scale=3)
    skin = k.mat("skin", (240, 220, 190), var=0.06, scale=3)
    white = k.mat("eye", k.WHITE, kind="flat")
    pupil = k.mat("pupil", (10, 6, 10), kind="flat")
    mouth = k.mat("mouth", (60, 8, 14), kind="flat")
    tongue = k.mat("tongue", k.TONGUE, var=0.1, scale=4)
    geta = k.mat("geta", k.WOOD, var=0.15, scale=5, kind="wood")
    thong = k.mat("thong", k.VERMILION, kind="flat")
    n = 12
    p = [
        k.lathe([(2.85, 2.45), (2.3, 3.15)], m=red, n=n),
        k.lathe([(2.3, 3.15), (1.45, 3.85)], m=paper, n=n),
        k.lathe([(1.45, 3.85), (0.6, 4.45), (0.3, 4.6)], m=red, n=n),
        k.lathe([(0.3, 4.6), (0.32, 4.85), (0.12, 5.05), (0, 5.1)], m=ink, n=8),
        k.lathe([(0, 3.05), (2.8, 2.42)], m=under, n=n),
    ]
    # Ribs over the canopy (folds) and spokes under it.
    for i in range(n):
        a = 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        p.append(k.tube([(c * 0.35, s * 0.35, 4.62), (c * 1.5, s * 1.5, 3.87), (c * 2.35, s * 2.35, 3.17), (c * 2.92, s * 2.92, 2.42)], 0.05, m=bamboo, n=4))
        if i % 2 == 0:
            p.append(k.tube([(0, 0, 2.6), (c * 1.6, s * 1.6, 2.72)], 0.04, m=bamboo, n=4))
    # Face on the front of the canopy.
    # Flattened along the canopy normal at the front (tilted 51 degrees toward +Y).
    p.append(k.sphere(0.8, (0, 1.95, 3.5), (51, 0, 0), m=white, scale=(1, 0.45, 1), seg=14, rings=8))
    p.append(k.sphere(0.38, (0, 2.17, 3.76), (51, 0, 0), m=pupil, scale=(1, 0.4, 1), seg=10, rings=6))
    p.append(k.sphere(0.55, (0, 2.62, 2.78), (51, 0, 0), m=mouth, scale=(1, 0.35, 0.5), seg=12, rings=6))
    p.append(k.tube([(0, 2.62, 2.85), (0, 3.15, 2.6), (0.05, 3.3, 2.0), (0, 3.1, 1.55)], [0.26, 0.27, 0.22, 0.0], m=tongue, n=8))
    # The handle becomes one hairy leg in a geta.
    p.append(k.tube([(0, 0, 2.7), (0, -0.25, 1.75), (0, 0.05, 0.75)], [0.18, 0.34, 0.3], m=skin, n=10))
    p.append(k.sphere(0.4, (0, 0.25, 0.55), m=skin, scale=(0.9, 1.4, 0.6), seg=10, rings=6))
    p.append(k.box((0.9, 1.9, 0.2), (0, 0.2, 0.32), m=geta, bevel=0.04))
    for y in (-0.4, 0.75):
        p.append(k.box((0.8, 0.25, 0.22), (0, y, 0.11), m=geta))
    p.append(k.tube([(-0.4, 0.15, 0.42), (0, 0.65, 0.62), (0.4, 0.15, 0.42)], 0.06, m=thong, n=5))
    return p


def _arc_plate(r0, r1, a0, a1, z0, z1, m, thick=0.08, nu=6, sy=1.0):
    """Curved armour lame: part of a cone between angles a0..a1 (radians, 0 = +Y)."""

    def fn(u, v):
        a = a0 + (a1 - a0) * u
        r = r0 + (r1 - r0) * v
        return (math.sin(a) * r, math.cos(a) * r * sy, z0 + (z1 - z0) * v)

    return k.surface(nu, 1, fn, m=m, thickness=thick)


def yoroi():
    """Possessed Yoroi: hovering empty samurai armour (enemy kind `oni`)."""
    lacquer = k.mat("lacquer", k.LACQUER, var=0.1, scale=3)
    ink = k.mat("ink", (34, 28, 36), var=0.12, scale=3)
    gold = k.mat("gold", k.GOLD, var=0.15, scale=6)
    lacing = k.mat("lacing", (40, 60, 140), var=0.12, scale=8, kind="wood")
    ember = k.mat("ember", k.EMBER, kind="flat", emit=3)
    p = []
    # Cuirass (do) with laced rows.
    p.append(k.lathe([(1.25, 2.0), (1.45, 2.5), (1.6, 3.4), (1.62, 4.2), (1.3, 4.75), (0.9, 4.8)], m=lacquer, n=16, scale=(1, 0.72, 1)))
    for z in (2.5, 3.0, 3.5, 4.0):
        r = 1.45 + 0.17 * min(1, (z - 2.5) / 0.9)
        rr = k.ring(r + 0.03, z, 0.05, gold if z == 4.0 else lacing, n=20, sides=4)
        rr.data.transform(k.Matrix.Diagonal((1, 0.72, 1, 1)))
        p.append(rr)
    # Glowing void at the neck opening and a red heart glow in the chest.
    p.append(k.sphere(0.85, (0, 0, 4.6), m=ember, scale=(1, 0.7, 0.4), seg=12, rings=6))
    p.append(k.sphere(0.5, (0, 1.12, 3.5), m=ember, scale=(1, 0.3, 1), seg=10, rings=6))
    # Kusazuri: five skirt panels of three lames each.
    for i in range(5):
        a = math.radians(-144 + 72 * i)
        for row in range(3):
            z1 = 2.1 - row * 0.55
            p.append(_arc_plate(1.35 + row * 0.12, 1.5 + row * 0.12, a - 0.6, a + 0.6, z1, z1 - 0.65, lacquer, sy=0.75))
            p.append(_arc_plate(1.5 + row * 0.12, 1.51 + row * 0.12, a - 0.6, a + 0.6, z1 - 0.62, z1 - 0.68, gold, sy=0.75, thick=0.1))
    # Sode: shoulder guards of four lames hanging off each shoulder.
    for side in (-1, 1):
        p.append(k.sphere(0.6, (side * 1.55, 0, 4.55), m=ink, seg=12, rings=8))
        for row in range(4):
            z = 4.7 - row * 0.5
            plate = k.box((0.14, 1.5, 0.55), (side * (2.05 + row * 0.1), 0, z), (0, side * -18, 0), m=lacquer, bevel=0.04)
            p.append(plate)
            p.append(k.box((0.16, 1.52, 0.06), (side * (2.05 + row * 0.1), 0, z - 0.26), (0, side * -18, 0), m=gold))
    # Kabuto: ridged bowl, flared neck guard, turnbacks, gold horns and crest.
    p.append(k.lathe([(1.05, 5.25), (1.08, 5.6), (0.9, 6.2), (0.5, 6.55), (0, 6.65)], m=ink, n=16))
    for i in range(8):
        a = 2 * math.pi * i / 8
        pts = [(math.cos(a) * r, math.sin(a) * r, z) for r, z in ((1.1, 5.3), (0.95, 6.15), (0.55, 6.55), (0.1, 6.66))]
        p.append(k.tube(pts, 0.05, m=gold, n=4))
    for row in range(3):
        p.append(_arc_plate(1.1 + row * 0.25, 1.35 + row * 0.25, math.radians(70), math.radians(290), 5.35 - row * 0.32, 5.0 - row * 0.32, lacquer, nu=10))
    for side in (-1, 1):
        p.append(k.box((0.12, 0.5, 0.45), (side * 1.15, 0.75, 5.25), (0, 0, side * 30), m=lacquer, bevel=0.03))
        horn = [(side * 0.25, 1.0, 5.55), (side * 0.75, 1.05, 6.2), (side * 1.25, 0.95, 7.0), (side * 1.45, 0.8, 7.5)]
        p.append(k.tube(horn, [0.13, 0.12, 0.09, 0.0], m=gold, n=6))
    p.append(k.sphere(0.25, (0, 1.05, 5.6), m=gold, scale=(1, 0.5, 1), seg=10, rings=6))
    # Menpo face mask with burning eyes, under the brim.
    p.append(k.sphere(0.75, (0, 0.55, 4.95), m=ink, scale=(0.95, 0.75, 0.85), seg=14, rings=8))
    for side in (-1, 1):
        p.append(k.box((0.38, 0.2, 0.16), (side * 0.32, 1.12, 5.12), (0, 0, side * -12), m=ember))
    p.append(k.box((0.7, 0.1, 0.12), (0, 1.2, 4.62), m=gold))
    return p


def wisp():
    """Hitodama: teardrop soul flame with a tail curling back."""
    flame = k.mat("flame", (170, 220, 255), kind="grad", rgb2=(50, 110, 255), emit=2.0)
    core = k.mat("core", (255, 255, 255), kind="flat", emit=4)
    spine = [
        ((0, 0, 0.0), 0.0),
        ((0, 0, 0.12), 0.7),
        ((0, 0, 0.45), 1.15),
        ((0, 0, 0.95), 1.35),
        ((0, -0.05, 1.55), 1.25),
        ((0, -0.2, 2.15), 0.95),
        ((0, -0.5, 2.7), 0.62),
        ((0.15, -0.95, 3.15), 0.36),
        ((0.3, -1.45, 3.4), 0.16),
        ((0.35, -1.9, 3.35), 0.0),
    ]
    p = [k.tube([s[0] for s in spine], [s[1] for s in spine], m=flame, n=14)]
    for side in (-1, 1):
        pts = [(side * 0.9, 0, 1.3), (side * 1.25, -0.2, 1.9), (side * 1.2, -0.45, 2.4), (side * 1.0, -0.6, 2.65)]
        p.append(k.tube(pts, [0.42, 0.3, 0.15, 0.0], m=flame, n=8))
    p.append(k.sphere(0.6, (0, 0.85, 1.0), m=core, scale=(1, 0.5, 1.2), seg=12, rings=6))
    return p


ASSETS = [
    dict(name="lantern_yokai", build=lantern_yokai, budget=3000, size=[3.5, 5.3, 4.5], priority=1, order=9,
         replaces="lanternYokai mesh (src/relay/Models.luau 65-69) in src/night/Enemies.luau 210-243",
         notes="Modelled at in-game size: spawn at scale 1, not 0.75."),
    dict(name="kasa_obake", build=kasa_obake, budget=2500, size=[5.6, 5.4, 5.6], priority=1, order=10,
         replaces="Kasa-obake parts in src/night/Enemies.luau 246-302"),
    dict(name="yoroi", build=yoroi, budget=4000, size=[6.5, 7, 3.5], priority=1, order=11,
         replaces="Possessed Yoroi parts (kind oni) in src/night/Enemies.luau 305-364",
         notes="Hovers: bottom of the skirt is y = 0; code offsets the root."),
    dict(name="wisp", build=wisp, budget=800, size=[3, 4.5, 3], priority=1, order=12,
         replaces="Hitodama parts in src/night/Enemies.luau 170-207, idle wisp src/night/Arena.luau 615-631, spirit flame src/night-client/CombatFx.client.luau 1104",
         notes="Set Material Neon or keep the texture; Fire, Trail and PointLight stay in code."),
]
