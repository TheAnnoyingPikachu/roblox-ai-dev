"""Hatchling Valley props for v0.5 (docs/architecture/garden.md 9.3, GDD X2): the large sakura,
the horizon hill meshes, the spawn pad and the path lantern. Origin at the base centre, 1 unit = 1
stud, one baked 1024 texture each. Nothing here moves, so no pivot rules beyond the trunk collider:
each sakura trunk stays inside a 2.5-radius cylinder at the origin."""

import math
import random

import kit as k
from mathutils import Vector


# Sakura -----------------------------------------------------------------------------------------


def _sakura(height, canopy, seed):
    rng = random.Random(seed)
    top = height - canopy * 0.4  # canopy clumps are centred this far up
    bark = k.paint(f"sk_bark{seed}", [(0, (120, 80, 70)), (1, (150, 105, 85))], 0, top, grain=(0.25, 2.5, "wave"))
    # Deep pink in the shade grading to pale tips, with soft lighter patches on the upper lumps.
    bloom = k.paint(
        f"sk_bloom{seed}",
        [(0, (235, 120, 165)), (0.55, (255, 170, 200)), (1, (255, 222, 236))],
        top - canopy * 0.45,
        height,
        grain=(0.12, 1.2),
        splat=[((255, 232, 242), 0.5, 0.62, top, height + 1)],
    )
    r0 = 2.5
    parts = [k.lathe([(r0, 0), (r0, 0.5), (r0 * 0.78, top * 0.35), (r0 * 0.6, top * 0.7), (r0 * 0.5, top * 0.92), (0, top + 1.5)], m=bark, n=12, name="trunk")]
    count = rng.choice((4, 5))
    clumps = [(0, 0, top + canopy * 0.15, canopy * 0.3)]
    for i in range(count - 1):
        a = 2 * math.pi * i / (count - 1) + rng.uniform(-0.3, 0.3)
        spread = canopy * rng.uniform(0.26, 0.3)
        clumps.append((spread * math.cos(a), spread * math.sin(a), top + rng.uniform(-canopy * 0.12, canopy * 0.05), canopy * rng.uniform(0.21, 0.25)))
    for i, (x, y, z, r) in enumerate(clumps):
        # Branch from the trunk to the clump, then a lumpy ball of blossom.
        parts.append(k.tube([(0, 0, top * 0.72), (x * 0.5, y * 0.5, (top * 0.72 + z) / 2), (x, y, z)], [r0 * 0.5, r0 * 0.32, r0 * 0.18], m=bark, n=6, name="branch"))
        ball = k.ico(r, (x, y, z), m=bloom, scale=(1, 1, 0.82), subdiv=3, name="clump")
        k.displace(ball, r * 0.5, size=r * 0.55, seed=seed * 10 + i + 1)
        parts.append(ball)
        for j in range(2):  # small lumps hanging off the side make the silhouette fluffier
            b = 2 * math.pi * (j + rng.random()) / 2
            parts.append(k.puff(r * 0.5, (x + r * 0.75 * math.cos(b), y + r * 0.75 * math.sin(b), z - r * 0.25), bloom, name="lump"))
    return parts


def sakura_large_a():
    return _sakura(34, 30, 1)


def sakura_large_b():
    return _sakura(42, 36, 2)


def sakura_large_c():
    return _sakura(45, 36, 3)


# Hills --------------------------------------------------------------------------------------------

HILL_W, HILL_H, HILL_D = 220.0, 160.0, 120.0


def _hill(shape, seed, nu=36, nv=14):
    """Heightfield dome over a 220 x 120 ellipse, normalised to 160 tall: green turf grading to
    blue-grey rock, a jagged snowline and solid snow above 70% (both bands at scale 1 and 2.5)."""
    rng = random.Random(seed)
    waves = [(rng.randint(2, 5), rng.uniform(0, 6.28), rng.uniform(0.03, 0.07)) for _ in range(4)]

    def raw(u, v):
        a = 2 * math.pi * u
        x = math.cos(a) * v
        if shape == "dome":
            h = math.cos(v * math.pi / 2) ** 1.2
        elif shape == "double":
            h = math.cos(v * math.pi / 2) ** 0.8 * (0.62 - 0.38 * math.cos(2 * math.pi * x))
        else:  # long saddle along X
            h = math.cos(v ** 1.8 * math.pi / 2) * (0.9 - 0.1 * math.cos(2 * math.pi * x)) * (0.7 + 0.3 * abs(math.cos(a)))
        bump = 1 + v * sum(amp * math.sin(f * a + p) for f, p, amp in waves)
        return max(h * bump, 0.0)

    peak = max(raw(i / nu, j / nv) for i in range(nu + 1) for j in range(nv + 1))

    def fn(u, v):
        a = 2 * math.pi * u
        return (HILL_W / 2 * v * math.cos(a), HILL_D / 2 * v * math.sin(a), HILL_H * raw(u, v) / peak)

    turf = k.paint(
        f"hill{seed}",
        [(0, (112, 190, 100)), (0.3, (140, 200, 125)), (0.55, (170, 190, 175)), (0.75, (178, 190, 205)), (1, (190, 200, 215))],
        0,
        HILL_H,
        grain=(0.08, 0.04),
        splat=[(k.SNOW, 0.05, 0.42, HILL_H * 0.62, HILL_H * 0.7), (k.SNOW, 0.05, -1.0, HILL_H * 0.7, HILL_H + 1)],
    )
    return [k.surface(nu, nv, fn, m=turf, name="hill")]


def hill_a():
    return _hill("dome", 1)


def hill_b():
    return _hill("double", 2)


def hill_c():
    return _hill("saddle", 3)


# Spawn pad ------------------------------------------------------------------------------------------


def spawn_pad():
    petals = [(k.ROSE, 0.0), (k.BLUSH, 0.0)]
    marks = [(k.GOLD_MID, (0, 0, 0.6), 0, 0.9), (k.SNOW, (0, 0, 0.6), 0.9, 1.15)]
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        marks.append((petals[i % 2][0], (2.0 * math.cos(a), 2.0 * math.sin(a), 0.6), 0, 1.0))
    for i in range(12):  # an outer ring of small petals
        a = 2 * math.pi * i / 12
        marks.append((k.BLUSH if i % 2 else k.SNOW, (3.9 * math.cos(a), 3.9 * math.sin(a), 0.6), 0, 0.42))
    stone = k.paint(
        "pad_stone",
        [(0, (150, 140, 135)), (1, (205, 198, 192))],
        0,
        0.6,
        grain=(0.18, 1.6),
        dots=[((165, 158, 150), 0.9, 0.12)],
        marks=marks,
    )
    return [k.lathe([(4.6, 0), (5.0, 0.25), (4.9, 0.55), (4.6, 0.6), (0, 0.6)], m=stone, n=48, name="disc")]


# Lantern ------------------------------------------------------------------------------------------


def lantern():
    stone = k.paint("ln_stone", [(0, (140, 135, 130)), (1, (185, 180, 175))], 0, 4.5, grain=(0.2, 2.0))
    wood = k.flat((95, 65, 50))
    paper = k.paint("ln_paper", [(0, (255, 150, 60)), (1, (255, 200, 120))], 3.0, 4.2, emit=0.5)
    shade_z = 3.6
    parts = [
        k.lathe([(0.6, 0), (0.6, 0.3), (0.4, 0.5), (0.25, 0.6)], m=stone, n=10, name="base"),
        k.box((0.3, 0.3, 2.5), (0, 0, 1.8), m=wood, name="post"),
        k.box((0.9, 0.9, 1.2), (0, 0, shade_z), m=paper, name="shade"),
        k.lathe([(0.85, 4.15), (0.6, 4.35), (0.15, 4.5)], m=wood, n=4, rot=(0, 0, 45), name="roof"),
        k.box((1.1, 1.1, 0.12), (0, 0, 3.0), m=wood, name="sill"),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(k.box((0.16, 0.16, 1.3), (sx * 0.48, sy * 0.48, shade_z), m=wood, name="bar"))
    return parts


ASSETS = [
    dict(name="sakura_large_a", build=sakura_large_a, budget=2500, size=[30, 34, 30], priority=1, order=1, replaces="World.largeSakura (Props.sakura fallback)",
         notes="Plaza sakura: 34 tall, canopy 30. Trunk inside a 2.5-radius cylinder at the origin so a part collider matches; the canopy has no collision."),
    dict(name="sakura_large_b", build=sakura_large_b, budget=2500, size=[36, 42, 36], priority=1, order=2, replaces="World.largeSakura (Props.sakura fallback)",
         notes="Rim sakura: 42 tall, canopy 36. Trunk inside a 2.5-radius cylinder at the origin; the canopy has no collision."),
    dict(name="sakura_large_c", build=sakura_large_c, budget=2500, size=[36, 45, 36], priority=1, order=3, replaces="World.largeSakura (Props.sakura fallback)",
         notes="Rim sakura: 45 tall, canopy 36. Trunk inside a 2.5-radius cylinder at the origin; the canopy has no collision."),
    dict(name="hill_a", build=hill_a, budget=1200, size=[220, 160, 120], priority=1, order=4, replaces="World.hills band 2 and 3",
         notes="Single dome, open underneath. Snow baked above 70% of the height; band 2 at scale 1, band 3 at 2.5. No collision."),
    dict(name="hill_b", build=hill_b, budget=1200, size=[220, 160, 120], priority=1, order=5, replaces="World.hills band 2 and 3",
         notes="Double ridge along X, open underneath. Snow baked above 70% of the height. No collision."),
    dict(name="hill_c", build=hill_c, budget=1200, size=[220, 160, 120], priority=1, order=6, replaces="World.hills band 2 and 3",
         notes="Long saddle along X, open underneath. Snow baked above 70% of the height. No collision."),
    dict(name="spawn_pad", build=spawn_pad, budget=1500, size=[10, 0.6, 10], priority=1, order=7, replaces="World.spawnPad (Cobblestone cylinder, 4 pastel posts)",
         notes="Stone disc with a painted petal mosaic; the SpawnLocation is a separate invisible part under it. No posts, so the top stays 0.6 high."),
    dict(name="lantern", build=lantern, budget=600, size=[1.2, 4.5, 1.2], priority=1, order=8, replaces="World.lanterns (post and Neon cube)",
         notes="Stone base, wooden post and frame, paper shade baked warm; shade centre at 3.6 up, the PointLight attachment point."),
]
