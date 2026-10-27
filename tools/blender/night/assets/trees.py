"""Trees: the sacred camphor tree (src/night/Arena.luau 376-426, generated sacredTree mesh in
src/relay/Models.luau 55-59), the sakura ring (Arena.luau 732-745, sakura mesh Models.luau 33-37)
and the far forest cedars (Arena.luau 747-775)."""

import math
import random

import kit as k


def _trunk(rng, height, base_r, top_r, strands, twist, bark):
    p = []
    for i in range(strands):
        pts, radii = [], []
        for j in range(9):
            f = j / 8
            z = -0.5 + height * f
            a = 2 * math.pi * i / strands + math.radians(twist) * f
            spread = base_r * (1 - f) + top_r * f + (base_r * 0.6 if j == 0 else 0)
            pts.append((math.cos(a) * spread * 0.55, math.sin(a) * spread * 0.55, z))
            radii.append((base_r * 0.55 * (1 - f) + top_r * 0.6 * f) * (1.3 if j == 0 else 1))
        p.append(k.tube(pts, radii, m=bark, n=10))
    return p


def _branch(start, end, r0, r1, bark, droop=0.0, n=8):
    sx, sy, sz = start
    ex, ey, ez = end
    mid = ((sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2 + droop)
    return k.tube([start, mid, end], [r0, (r0 + r1) / 2, r1], m=bark, n=n)


def _cluster(rng, at, r, m, squash=0.68):
    blob = k.ico(r, at, m=m, scale=(1, 1, squash), subdiv=2, rot=(0, 0, rng.uniform(0, 360)))
    k.displace(blob, r * 0.24, size=r * 0.5, seed=rng.randint(1, 50))
    return blob


def sacred_tree():
    rng = random.Random(45)
    bark = k.mat("bark", (82, 60, 46), var=0.25, scale=1.5, kind="wood")
    leaf = k.mat("leaf", (34, 78, 46), var=0.25, scale=0.8, rgb2=(70, 120, 60))
    rope = k.mat("rope", k.ROPE, var=0.2, scale=6, kind="wood")
    white = k.mat("paper", k.WHITE, kind="flat")
    p = _trunk(rng, 21, 5.2, 2.6, 5, 70, bark)
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.2, 0.2)
        reach = rng.uniform(7.5, 10.5)
        p.append(k.tube(
            [(math.cos(a) * 2.2, math.sin(a) * 2.2, 2.2), (math.cos(a) * reach * 0.55, math.sin(a) * reach * 0.55, 0.9),
             (math.cos(a) * reach, math.sin(a) * reach, -0.3)], [1.5, 0.9, 0.25], m=bark, n=8))
    # Broad camphor crown: long limbs reaching out almost level, carrying three tiers of wide,
    # flat foliage pads (low wide ring, middle ring, top) for a ~44 stud spread.
    def pad(at, r, squash=0.42):
        return _cluster(rng, at, r, leaf, squash=squash)

    for i in range(10):
        a = 2 * math.pi * i / 10 + rng.uniform(-0.12, 0.12)
        reach = rng.uniform(14.8, 16.0)
        z = rng.uniform(25, 29)
        start = (math.cos(a) * 1.6, math.sin(a) * 1.6, rng.uniform(15, 19))
        end = (math.cos(a) * reach * 0.9, math.sin(a) * reach * 0.9, z - 1.5)
        p.append(_branch(start, end, 1.35 if i % 2 else 1.1, 0.35, bark, droop=-1.5))
        p.append(pad((math.cos(a) * reach, math.sin(a) * reach, z), rng.uniform(7.0, 8.0), squash=0.36))
    for i in range(7):
        a = 2 * math.pi * i / 7 + 0.35 + rng.uniform(-0.15, 0.15)
        reach = rng.uniform(8.5, 10.0)
        z = rng.uniform(31, 34)
        p.append(_branch((0, 0, 20), (math.cos(a) * reach * 0.8, math.sin(a) * reach * 0.8, z - 1.5), 1.0, 0.3, bark))
        p.append(pad((math.cos(a) * reach, math.sin(a) * reach, z), rng.uniform(7.0, 7.8), squash=0.38))
    for i in range(4):
        a = 2 * math.pi * i / 4 + 1.0
        p.append(pad((math.cos(a) * 4.0, math.sin(a) * 4.0, 37.5 + rng.uniform(-1, 1)), 6.5, squash=0.45))
    p.append(_branch((0, 0, 19), (0.5, -0.5, 36), 2.0, 0.7, bark))
    # Shimenawa rope around the trunk at 9 studs, with shide.
    p.append(k.ring(4.75, 9, 0.75, rope, n=28, sides=8, wobble=0.15))
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        p.append(k.shide((math.cos(a) * 5.55, math.sin(a) * 5.55, 8.6), math.degrees(a) - 90, white, s=1.4))
    return p


def sakura_tree():
    rng = random.Random(110)
    bark = k.mat("bark", k.BARK, var=0.25, scale=2, kind="wood")
    bloom = k.mat("bloom", (255, 170, 205), var=0.2, scale=1.2, rgb2=(255, 220, 235))
    p = _trunk(rng, 7, 1.6, 0.9, 3, 80, bark)
    tips = []
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        reach = rng.uniform(4.5, 6.5)
        start = (math.cos(a) * 0.4, math.sin(a) * 0.4, rng.uniform(5.5, 7))
        end = (math.cos(a) * reach, math.sin(a) * reach, rng.uniform(9, 11.5))
        p.append(_branch(start, end, 0.6, 0.18, bark, droop=1.0, n=6))
        tips.append(end)
    for t in tips:
        p.append(_cluster(rng, (t[0], t[1], t[2] + 1.0), rng.uniform(3.2, 4.0), bloom, squash=0.72))
    p.append(_cluster(rng, (0, 0, 12.2), 4.4, bloom, squash=0.7))
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.8
        p.append(_cluster(rng, (math.cos(a) * 3.2, math.sin(a) * 3.2, 10.5), 2.8, bloom, squash=0.8))
    return p


def cedar_tree():
    trunk = k.mat("trunk", (60, 42, 32), var=0.2, scale=2, kind="wood")
    green = k.mat("needles", (30, 70, 45), var=0.2, scale=1.5, rgb2=(44, 92, 58))
    p = [k.cyl(0.6, 26, (0, 0, 13), m=trunk, n=6, r2=0.3)]
    for layer, (z, r, h) in enumerate(((7, 5.4, 9), (12.5, 4.2, 8), (17.5, 3.0, 7), (21.5, 1.8, 5))):
        p.append(k.lathe([(r, z), (r * 0.82, z + 0.6), (0, z + h)], m=green, n=8, rot=(0, 0, layer * 22)))
    return p


ASSETS = [
    dict(name="sacred_tree", build=sacred_tree, budget=9000, size=[44, 49, 44], priority=1, order=6,
         replaces="sacredTree mesh (src/relay/Models.luau 55-59) in src/night/Arena.luau 376-426 (with the rope and shide 397-414)",
         notes="Rope and shide are in the mesh, so the code's rope parts can go; keep the stone fence and fireflies."),
    dict(name="sakura_tree", build=sakura_tree, budget=5000, size=[16, 16, 16], priority=2, order=18,
         replaces="sakura mesh (src/relay/Models.luau 33-37, shared with Relay) in src/night/Arena.luau 732-745",
         notes="Night-only asset; leave Relay on its own sakura mesh."),
    dict(name="cedar_tree", build=cedar_tree, budget=400, size=[11, 26, 11], priority=3, order=23,
         replaces="Forest cedar parts in src/night/Arena.luau 747-775 (x140)"),
]
