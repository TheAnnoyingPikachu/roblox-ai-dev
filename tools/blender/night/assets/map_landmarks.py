"""Map v2 landmarks and backdrop (NIGHT-010, docs/assets/night-blender-plan.md "Map v2"): the
five-storey pagoda, the senbon-torii tunnel gate and stone stair flight of the south sando, the
distant castle, the waterfall cliff and the misty mountain range. New props (no part version
today): with a nil model id src/night/Arena.luau simply skips them. Front faces +Y (Roblox -Z)."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit as k  # noqa: E402
from mathutils import Vector, noise  # noqa: E402
from torii import gate  # noqa: E402


def _ring_of(p, build_side):
    """Builds one side's objects and copies them to the other three sides (square plans)."""
    side = build_side()
    p += side
    for deg in (90, 180, 270):
        p += [k.copy(ob, k.rot_z(deg)) for ob in side]


def _glow(p, material):
    """Splits off the pieces using `material` as a <name>_glow mesh: textures are not emissive in
    Roblox, so code sets this mesh to real Neon (Models leaves *_glow untextured)."""
    glow = [ob for ob in p if ob.data.materials and ob.data.materials[0] == material]
    return {"": [ob for ob in p if ob not in glow], "glow": glow}


def _stone(rng, at, r, scale, m, cuts=6):
    """Chiselled rock: a noisy sphere with a few random planar cuts and a flat base."""
    ob = k.ico(1.0, m=m, subdiv=3)
    seed = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    planes = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.4, 1))).normalized(), rng.uniform(0.7, 0.9)) for _ in range(cuts)]
    planes.append((Vector((0, 0, -1)), 0.4))
    yaw = rng.uniform(0, 2 * math.pi)
    c, s = math.cos(yaw), math.sin(yaw)
    for v in ob.data.vertices:
        d = v.co.normalized()
        q = d * (1 + 0.2 * noise.fractal(d * 1.5 + seed, 0.5, 2.0, 4))
        for n, dist in planes:
            excess = q.dot(n) - dist
            if excess > 0:
                q -= n * excess
        x, y = q.x * c - q.y * s, q.x * s + q.y * c
        v.co = Vector((at[0] + x * r * scale[0], at[1] + y * r * scale[1], at[2] + q.z * r * scale[2]))
    return ob


def pagoda():
    S = 1.3
    red = k.mat("vermilion", k.VERMILION, var=0.1, scale=1.5, kind="wood")
    plaster = k.mat("plaster", (226, 218, 200), var=0.06, scale=2)
    wood = k.mat("wood", k.DARKWOOD, var=0.18, scale=3, kind="wood")
    roof = k.mat("roof", k.ROOF, var=0.25, scale=10, kind="wood")
    stone = k.mat("stone", k.STONE, var=0.2, scale=1.2)
    gold = k.mat("gold", k.GOLD, var=0.15, scale=6)
    door = k.mat("door", (255, 196, 120), kind="flat", emit=1.8)
    ink = k.mat("ink", k.INK, var=0.1)
    p = []
    # Stone plinth with a short flight of steps on every side.
    p.append(k.box((17 * S, 17 * S, 1.4 * S), (0, 0, 0.7 * S), m=stone, bevel=0.2))
    _ring_of(p, lambda: [k.box((5 * S, 0.7 * S, (1.4 - 0.45 * i) * S), (0, (8.85 + 0.7 * i) * S, (0.7 - 0.225 * i) * S), m=stone, bevel=0.05) for i in range(3)])
    z = 1.4 * S
    for i in range(5):
        b = (4.6 - 0.35 * i) * S
        h = (4.4 if i == 0 else 3.3) * S
        p.append(k.box((2 * b - 0.5, 2 * b - 0.5, h), (0, 0, z + h / 2), m=plaster))
        posts = sorted({(x, y) for t in (-1, -1 / 3, 1 / 3, 1) for x, y in ((t * b, -b), (t * b, b), (-b, t * b), (b, t * b))})
        for x, y in posts:
            p.append(k.box((0.55 * S, 0.55 * S, h), (x, y, z + h / 2), m=red))

        def face(b=b, h=h, z=z, i=i):
            # Middle bay: a glowing door on the ground storey, dark lattice shutters above.
            w = 2 * b / 3 - 0.6 * S
            objs = [k.box((w, 0.2, h * 0.75), (0, b - 0.05, z + h * 0.42), m=door if i == 0 else wood)]
            for j in (-1, 0, 1):
                objs.append(k.box((0.1 * S, 0.3, h * 0.75), (j * w / 3, b + 0.05, z + h * 0.42), m=ink))
            objs.append(k.box((w, 0.3, 0.12 * S), (0, b + 0.05, z + h * 0.62), m=ink))
            # Balcony rail on the upper storeys.
            if i > 0:
                objs.append(k.box((2 * b + 1.4 * S, 0.18 * S, 0.18 * S), (0, b + 0.7 * S, z + 0.75 * S), m=red))
            return objs

        _ring_of(p, face)
        # Head beam, then two stepped bracket bands (tokyo) carrying the eaves.
        p.append(k.box((2 * b + 0.5, 2 * b + 0.5, 0.45 * S), (0, 0, z + h - 0.2 * S), m=red))
        p.append(k.box((2 * b + 1.2 * S, 2 * b + 1.2 * S, 0.45 * S), (0, 0, z + h + 0.22 * S), m=wood, bevel=0.05))
        p.append(k.box((2 * b + 2.2 * S, 2 * b + 2.2 * S, 0.4 * S), (0, 0, z + h + 0.62 * S), m=gold if i == 0 else wood, bevel=0.05))
        ze = z + h + 0.85 * S
        e = b + 3.4 * S
        lift = 1.3 * S
        p += k.hip_roof(e, e, 0.02, ze, ze + 2.6 * S, roof, lift=lift, thickness=0.5 * S, nu=10, nv=4)
        # Wind bells under the upturned corners.
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(k.cyl(0.04 * S, 0.6 * S, (sx * e * 0.98, sy * e * 0.98, ze + lift - 0.3 * S), m=ink, n=4))
                p.append(k.lathe([(0.0, 0.0), (0.28 * S, 0.05 * S), (0.2 * S, 0.45 * S), (0, 0.55 * S)], (sx * e * 0.98, sy * e * 0.98, ze + lift - 1.1 * S), m=gold, n=8))
        top = ze + 2.6 * S
        z = ze + 0.55 * S
    # Sorin spire: base box, upturned bowl, nine rings, flame plates and the jewel.
    p.append(k.box((1.8 * S, 1.8 * S, 0.9 * S), (0, 0, top + 0.2 * S), m=wood, bevel=0.05))
    p.append(k.lathe([(0.5 * S, top + 0.6 * S), (1.0 * S, top + 0.9 * S), (0.9 * S, top + 1.4 * S), (0.3 * S, top + 1.6 * S)], m=gold, n=10))
    p.append(k.cyl(0.16 * S, 11 * S, (0, 0, top + 6.5 * S), m=gold, n=8))
    for j in range(9):
        p.append(k.cyl((0.75 - 0.03 * j) * S, 0.16 * S, (0, 0, top + (2.3 + 0.72 * j) * S), m=gold, n=12))
    for a in range(4):
        p.append(k.poly([(0, 0), (0.7 * S, 0.5 * S), (0.55 * S, 1.3 * S), (0.15 * S, 1.8 * S), (0, 1.2 * S)], 0.06 * S, loc=(0, 0, top + 9.0 * S), rot=(0, 0, a * 90), m=gold))
    p.append(k.sphere(0.4 * S, (0, 0, top + 11.9 * S), m=gold, seg=10, rings=6))
    return _glow(p, door)


def senbon_torii():
    """One gate of the senbon-torii tunnel: vermilion, black kasagi and black-dipped feet."""
    red = k.mat("vermilion", (214, 54, 30), var=0.1, scale=1.5, kind="wood")
    ink = k.mat("ink", k.INK, var=0.12, scale=3)
    p = gate(12, 15, red, red, ink, ink, pillar_r=0.75)
    # The donor inscription strip down the back of each pillar.
    for side in (-1, 1):
        p.append(k.box((0.5, 0.1, 6), (side * 6, -0.8, 6.5), m=ink))
    for ob in p:
        ob.data.transform(k.Matrix.Scale(0.58, 4))
    return p


def sando_stairs():
    """One stone stair flight of the south sando: 8 steps of 0.75 over 12 studs, climbing toward -Y
    (Roblox +Z) from its front edge, with sloped side blocks (sode-ishi) the torii pillars sit on."""
    stone = k.mat("stone", k.STONE, var=0.22, scale=1.0)
    worn = k.mat("worn", k.shade(k.STONE, 0.86), var=0.24, scale=1.3)
    block = k.mat("block", k.shade(k.STONE, 0.7), var=0.22, scale=1.6)
    moss = k.mat("moss", (62, 92, 52), var=0.25, scale=2)
    steps, rise, run, width = 8, 0.75, 1.5, 7.0
    length = steps * run
    p = []
    for i in range(steps):
        front = length / 2 - i * run
        depth = front + length / 2
        p.append(k.box((width, depth, (i + 1) * rise), (0, front - depth / 2, (i + 1) * rise / 2), m=stone if i % 2 else worn, bevel=0.07))
    for side in (-1, 1):
        x = side * (width / 2 + 0.55)
        pts = [(-length / 2, 0), (-length / 2, steps * rise + 1.0), (length / 2, 1.0), (length / 2, 0)]
        # poly lays points in local x/z; rotate so local x runs along -Y (the climb).
        p.append(k.poly(pts, 1.1, loc=(x, 0, 0), rot=(0, 0, -90), m=block, bevel=0.08))
        p.append(k.box((1.12, 1.6, 0.12), (x, length / 2 - 2.4, 0.95 + 2.4 / length * steps * rise), (math.degrees(math.atan2(steps * rise, length)), 0, 0), m=moss))
    return p


def castle():
    """Distant castle keep (tenshu) on a curved stone base, for the north-west ridge. Lit windows
    keep it readable at 400+ studs."""
    rock = k.mat("ishigaki", (96, 92, 90), var=0.25, scale=0.6)
    plaster = k.mat("plaster", (214, 210, 200), var=0.06, scale=2)
    roof = k.mat("roof", (40, 46, 64), var=0.2, scale=6, kind="wood")
    dark = k.mat("dark", (40, 34, 36), var=0.15, scale=3, kind="wood")
    lit = k.mat("lit", (255, 190, 110), kind="flat", emit=2.4)
    gold = k.mat("gold", k.GOLD, var=0.15, scale=6)
    p = [k.lathe([(30, 0), (27.5, 6), (25.8, 11), (25.2, 14)], rot=(0, 0, 45), scale=(1, 0.74, 1), m=rock, n=4)]
    tiers = [(30, 22, 8.0), (25, 18, 7.0), (20, 14, 6.5), (15, 11, 6.5), (11, 8, 6.0)]
    z = 14
    for i, (w, d, h) in enumerate(tiers):
        p.append(k.box((w, d, h), (0, 0, z + h / 2), m=plaster))
        p.append(k.box((w + 0.2, d + 0.2, 1.0), (0, 0, z + 0.5), m=dark))
        # Window rows: lit on the front and sides, every other one dark.
        n = int(w // 3.4)
        for j in range(n):
            x = -w / 2 + (j + 0.5) * w / n
            p.append(k.box((1.1, 0.3, 1.5), (x, d / 2 + 0.05, z + h * 0.55), m=lit if (i + j) % 2 == 0 else dark))
        for j in range(max(2, int(d // 3.4))):
            y = -d / 2 + (j + 0.5) * d / max(2, int(d // 3.4))
            for sx in (-1, 1):
                p.append(k.box((0.3, 1.1, 1.5), (sx * (w / 2 + 0.05), y, z + h * 0.55), m=lit if (i + j) % 3 == 0 else dark))
        ze = z + h + 0.3
        top = i == len(tiers) - 1
        p += k.hip_roof(w / 2 + 2.6, d / 2 + 2.6, w * 0.3 if top else w * 0.18, ze, ze + (4.5 if top else 3.0), roof, lift=1.2, thickness=0.6, nu=8, nv=3)
        if not top:
            # Chidori gable on the front of the roof.
            p.append(k.poly([(-4, 0), (4, 0), (0, 3.4)], 0.5, loc=(0, d / 2 + 1.8, ze + 0.2), m=plaster))
            p.append(k.poly([(-4.8, -0.2), (4.8, -0.2), (0, 4.0), (0, 3.4)], 0.6, loc=(0, d / 2 + 2.0, ze + 0.2), m=roof))
        z = ze + 1.2
    # Ridge and gold shachihoko at both ends.
    p.append(k.box((11 * 0.3 * 2 + 0.6, 0.9, 0.9), (0, 0, z + 3.4), m=dark))
    for sx in (-1, 1):
        x = sx * (11 * 0.3 + 0.4)
        p.append(k.tube([(x, 0, z + 3.6), (x + sx * 0.5, 0, z + 4.6), (x + sx * 0.2, 0, z + 5.6), (x - sx * 0.4, 0, z + 6.0)], [0.55, 0.5, 0.35, 0.0], m=gold, n=6))
    return _glow(p, lit)


def waterfall():
    """Waterfall cliff for the west backdrop: a ledged rock amphitheatre open toward +Y with a
    notch at the top, a cascade sheet falling into a foaming plunge pool, moss and cedars on top.
    Code adds the falling spray and mist particles."""
    rng = random.Random(77)
    rock = k.mat("rock", (70, 72, 86), kind="grad", rgb2=(52, 66, 58))
    moss = k.mat("moss", (40, 68, 44), var=0.3, scale=0.15)
    cedar = k.mat("cedar", (26, 56, 40), var=0.2, scale=0.5, rgb2=(40, 78, 54))
    water = k.mat("water", (120, 160, 205), kind="stripes", rgb2=(225, 238, 252), scale=0.9, emit=0.25)
    wave = water.node_tree.nodes.get("Wave Texture")
    wave.bands_direction = "X"
    wave.inputs["Distortion"].default_value = 2.0
    pool = k.mat("pool", (34, 60, 98), var=0.15, scale=0.2)
    foam = k.mat("foam", (220, 234, 250), var=0.1, scale=2, emit=0.3)
    R, notch = 24.0, 0.5

    def top(u):
        return 80 + 8 * noise.fractal(Vector((u * 5, 0.5, 0.2)), 0.6, 2.0, 3) - 14 * math.exp(-(((u - notch) / 0.07) ** 2))

    def cliff(u, v):
        a = math.radians(-115 + 230 * u)
        ledge = 1.6 * (math.floor(v * 10) % 2)
        r = R + 7 * noise.fractal(Vector((u * 7, v * 5, 1.3)), 0.6, 2.0, 3) + ledge + 9 * (1 - v) ** 2
        return (math.sin(a) * r, -math.cos(a) * r, top(u) * v)

    p = [k.surface(44, 14, cliff, m=rock, thickness=5, name="cliff")]
    # Mossy crown along the rim, with a few cedars standing on it.
    for i in range(9):
        u = (i + 0.5) / 9
        if abs(u - notch) < 0.08:
            continue
        a = math.radians(-115 + 230 * u)
        r = R + 3
        cap = k.ico(7, (math.sin(a) * r, -math.cos(a) * r - 3, top(u) - 1), m=moss, scale=(1.2, 1.1, 0.4), subdiv=2)
        k.displace(cap, 2.2, size=3, seed=rng.randint(1, 60))
        p.append(cap)
        if i % 2 == 0:
            h = rng.uniform(12, 18)
            p.append(k.lathe([(2.6, 0), (0, h)], (math.sin(a) * (r + 2), -math.cos(a) * (r + 2) - 4, top(u) + 0.5), m=cedar, n=7))

    # Cascade from the notch lip, bowing out and widening into the pool.
    lip = top(notch)

    def sheet(u, v):
        w = 4.5 + 5 * v
        return ((u - 0.5) * 2 * w, -R + 2 + 9 * math.sin(math.pi * 0.5 * v) + 0.5 * math.sin(u * 9), lip + 1 - (lip - 1) * v)

    p.append(k.surface(8, 16, sheet, m=water, thickness=0.8))
    p.append(k.cyl(15, 1.2, (0, -6, 0.6), m=pool, n=24))
    p.append(k.ring(7, 1.3, 1.4, foam, n=20, sides=6, centre=(0, -12), wobble=0.4))
    for i in range(8):
        a = math.pi * (0.05 + 0.9 * i / 7)
        r = rng.uniform(2.5, 4.5)
        p.append(_stone(rng, (math.cos(a) * 16, -6 + math.sin(a) * 13, 0.8), r, (1.2, 1.0, 0.8), rock))
    return _glow(p, water)


def mountain_range():
    """A 70-degree arc of misty mountains for the far backdrop (radius 560 about +Y): a near ridge
    and a taller far one, each with a few pointed peaks, gullies down the face and lower ends so
    neighbouring copies blend. Placed around the arena several times with varied yaw and scale.
    Closed shells so both sides render."""
    rng = random.Random(560)
    near = k.mat("mtn_near", (92, 102, 138), kind="grad", rgb2=(30, 36, 58))
    far = k.mat("mtn_far", (110, 122, 158), kind="grad", rgb2=(52, 60, 92))
    span = math.radians(70)
    p = []
    for layer, (radius, depth, base_h, mat) in enumerate(((560, 110, 50, near), (650, 120, 90, far))):
        peaks = [(rng.uniform(0.1, 0.9), rng.uniform(120, 190) + 40 * layer, rng.uniform(0.14, 0.24)) for _ in range(4)]

        def height(u, peaks=peaks, base_h=base_h, layer=layer):
            h = base_h
            for c, ph, w in peaks:
                h = max(h, ph * max(0.0, 1 - abs(u - c) / w) ** 1.3)
            h += 9 * noise.fractal(Vector((u * 28, layer * 7.0, 0.5)), 0.7, 2.0, 4)
            return h * (0.4 + 0.6 * math.sin(math.pi * u))

        def fn(u, v, radius=radius, depth=depth, height=height, layer=layer):
            a = -span / 2 + span * u
            r = radius - depth * (1 - v) ** 1.2 + 10 * noise.fractal(Vector((u * 30, v * 3, layer + 2.0)), 0.6, 2.0, 3) * v
            return (math.sin(a) * r, 560 - math.cos(a) * r, height(u) * v ** 0.85)

        p.append(k.surface(60, 7, fn, m=mat, thickness=3, name=f"ridge{layer}"))
    return p


ASSETS = [
    dict(name="pagoda", build=pagoda, budget=8000, size=[25, 56, 25], priority=4, order=1,
         replaces="New landmark (no part version): north-east, outside the wall near the shrine hall (src/night/Arena.luau backdrop())",
         notes="Ghosted. pagoda_glow is the ground-storey doors: code sets Neon, warm. Stone lanterns stand at the plinth corners."),
    dict(name="senbon_torii", build=senbon_torii, budget=700, size=[11.5, 9.5, 1.3], priority=4, order=2,
         replaces="New prop: the senbon-torii tunnel up the south sando stairs (src/night/Arena.luau sando())",
         notes="Pillars 7 studs apart (inner gap 6.2), so they straddle the 7-stud sando_stairs."),
    dict(name="sando_stairs", build=sando_stairs, budget=1200, size=[9.2, 7, 12], priority=4, order=3,
         replaces="New prop: stone stair flights of the south sando (src/night/Arena.luau sando())",
         notes="Low end faces -Z; climbs 6 studs over 12 toward +Z. Ghosted: an invisible WedgePart per flight is the walkable slope."),
    dict(name="castle", build=castle, budget=4000, size=[44, 68, 33], priority=4, order=4,
         replaces="New backdrop: castle keep on the north-west ridge (src/night/Arena.luau backdrop())",
         notes="Far scenery: no shadows, ghosted. castle_glow is the lit windows: code sets Neon, warm, so they read at 400+ studs."),
    dict(name="waterfall", build=waterfall, budget=4000, size=[70, 96, 55], priority=4, order=5,
         replaces="New backdrop: waterfall cliff in the west (src/night/Arena.luau backdrop())",
         notes="waterfall_glow is the cascade: code sets Neon, pale blue, slightly transparent, and adds spray and mist particles."),
    dict(name="mountain_range", build=mountain_range, budget=4000, size=[750, 170, 290], priority=4, order=6,
         replaces="Terrain mountain balls in src/night/Arena.luau ground() (kept as the nil-id fallback)",
         notes="One 70-degree arc; placed 6 times, bounding box at radius 510 (ridges at 560 and 650), leaving a gap at the moon bearing."),
]
