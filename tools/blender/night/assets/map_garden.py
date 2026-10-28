"""Map v2 garden dressing (NIGHT-010): bamboo clumps, Japanese black pine, hydrangea bushes,
mossy garden rocks, the raked-gravel zen garden and pond lily pads. New props placed by
src/night/Arena.luau (garden()); with a nil model id they are simply skipped. All decorative:
the code ghosts them (no collision, no queries)."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit as k  # noqa: E402
from map_landmarks import _stone  # noqa: E402
from trees import _branch  # noqa: E402


def _leaf(at, yaw, pitch, length, width, m):
    """A thin lance-shaped leaf from `at`, pointing along yaw/pitch (degrees)."""
    pts = [(0, 0), (length * 0.35, width / 2), (length, 0), (length * 0.35, -width / 2)]
    return k.poly(pts, 0.03, loc=at, rot=(90, -pitch, yaw), m=m)


def bamboo_cluster():
    rng = random.Random(8)
    culm = k.mat("culm", (56, 96, 52), kind="stripes", rgb2=(156, 172, 108), scale=0.3)
    wave = culm.node_tree.nodes.get("Wave Texture")
    wave.bands_direction = "Z"
    wave.inputs["Distortion"].default_value = 0
    culm.node_tree.nodes.get("Color Ramp").color_ramp.elements[1].position = 0.94
    leaf = k.mat("bamboo_leaf", (60, 116, 54), var=0.25, scale=1.2, rgb2=(110, 156, 74))
    ground = k.mat("litter", (70, 58, 40), var=0.25, scale=1.5)
    p = [k.cyl(3.6, 0.4, (0, 0, 0.2), m=ground, n=10, r2=2.8)]
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.3, 0.3)
        d = rng.uniform(0.6, 2.8)
        base = (math.cos(a) * d, math.sin(a) * d, 0)
        height = rng.uniform(18, 25)
        lean = rng.uniform(3, 9)
        la = a + rng.uniform(-0.6, 0.6)  # lean outward, so the crown spreads
        r = rng.uniform(0.26, 0.36)

        def at(f, base=base, lean=lean, la=la, height=height):
            off = math.tan(math.radians(lean)) * height * f ** 1.5
            return (base[0] + math.cos(la) * off, base[1] + math.sin(la) * off, height * f)

        p.append(k.tube([at(j / 5) for j in range(6)], [r * 1.1, r, r, r * 0.9, r * 0.75, r * 0.5], m=culm, n=6))
        # Drooping leaf fans on short twigs over the top half.
        for t in range(4):
            f = 0.5 + 0.14 * t + rng.uniform(-0.03, 0.03)
            node = at(f)
            yaw0 = math.degrees(la) + rng.uniform(-100, 100)
            tip = (node[0] + math.cos(math.radians(yaw0)) * 1.4, node[1] + math.sin(math.radians(yaw0)) * 1.4, node[2] + 0.3)
            p.append(k.tube([node, tip], [0.06, 0.03], m=culm, n=3))
            for q in range(6):
                p.append(_leaf(tip, yaw0 + (q - 2.5) * 26 + rng.uniform(-8, 8), -rng.uniform(25, 50), rng.uniform(2.0, 2.6), 0.5, leaf))
    return p


def _pad(rng, at, r, m, squash=0.36):
    """Flat lumpy needle pad (pine cloud)."""
    pad = k.ico(r, at, m=m, scale=(1, rng.uniform(0.8, 1.0), squash), subdiv=3, rot=(0, 0, rng.uniform(0, 360)))
    k.displace(pad, r * 0.22, size=r * 0.35, seed=rng.randint(1, 60))
    return pad


def pine_tree():
    """Japanese black pine (kuromatsu): leaning twisted trunk, level limbs ending in flat needle pads."""
    rng = random.Random(31)
    bark = k.mat("bark", (66, 50, 44), var=0.3, scale=1.8, kind="wood")
    needles = k.mat("needles", (30, 66, 44), var=0.28, scale=0.9, rgb2=(66, 110, 66))
    pts = [(0, 0, -0.3), (0.4, 0, 3), (1.6, 0.5, 6.5), (1.4, 1.0, 10), (2.6, 0.6, 13.5), (3.2, 0.2, 16)]
    p = [k.tube(pts, [1.3, 0.95, 0.8, 0.65, 0.5, 0.3], m=bark, n=9)]
    for i in range(4):
        a = 2 * math.pi * i / 4 + rng.uniform(-0.3, 0.3)
        p.append(k.tube([(0, 0, 0.6), (math.cos(a) * 1.8, math.sin(a) * 1.8, 0.0)], [0.7, 0.2], m=bark, n=6))
    limbs = [((1.5, 0.5, 6.5), 200, 7.0, 6.2, 3.4), ((1.4, 1.0, 9.5), 20, 6.5, 9.0, 3.1), ((1.6, 0.8, 11.5), 140, 5.0, 11.5, 2.8),
             ((2.4, 0.6, 13.0), 300, 4.5, 13.5, 2.6)]
    for start, yaw, reach, z, size in limbs:
        a = math.radians(yaw)
        end = (start[0] + math.cos(a) * reach, start[1] + math.sin(a) * reach, z)
        p.append(_branch(start, end, 0.45, 0.15, bark, droop=0.8, n=6))
        p.append(_pad(rng, (end[0], end[1], end[2] + 0.8), size, needles))
    p.append(_pad(rng, (3.3, 0.2, 16.8), 3.2, needles, squash=0.42))
    return p


def hydrangea_bush():
    rng = random.Random(12)
    leaves = k.mat("leaves", (34, 72, 44), var=0.3, scale=1.6, rgb2=(60, 104, 58))
    blooms = [k.mat("bloom_blue", (92, 130, 240), var=0.22, scale=5), k.mat("bloom_violet", (162, 108, 230), var=0.22, scale=5),
              k.mat("bloom_pale", (200, 206, 252), var=0.18, scale=5)]
    p = []
    for i in range(2):
        blob = k.ico(1.9, (i * 1.6 - 0.8, 0, 1.2), m=leaves, scale=(1.25, 1.1, 0.75), subdiv=3)
        k.displace(blob, 0.45, size=0.6, seed=rng.randint(1, 50))
        p.append(blob)
    for i in range(12):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.2, 1.0)
        x, y = math.cos(a) * d * 2.6, math.sin(a) * d * 1.9
        z = 1.2 + 1.45 * math.sqrt(max(0.0, 1 - d * d)) + 0.25
        head = k.ico(rng.uniform(0.7, 0.9), (x, y, z), m=blooms[i % 3], subdiv=2)
        k.displace(head, 0.22, size=0.16, seed=rng.randint(1, 50))
        p.append(head)
    return p


def garden_rocks():
    rng = random.Random(4)
    stone = k.mat("mossy", (116, 114, 108), kind="grad", rgb2=(72, 104, 62))
    return [
        _stone(rng, (0, 0, 1.0), 2.4, (1.0, 0.85, 0.9), stone),
        _stone(rng, (2.9, 0.8, 0.6), 1.5, (1.1, 0.9, 0.7), stone),
        _stone(rng, (-2.4, 1.2, 0.4), 1.1, (1.0, 1.0, 0.7), stone),
    ]


def zen_garden():
    """Karesansui: raked gravel in a low stone curb, three mossy rocks with raked rings."""
    rng = random.Random(21)
    W, D = 18.0, 11.0
    curb = k.mat("curb", (92, 90, 96), var=0.2, scale=1.5)
    gravel = k.mat("gravel", (196, 192, 182), kind="stripes", rgb2=(150, 146, 140), scale=0.8)
    wave = gravel.node_tree.nodes.get("Wave Texture")
    wave.bands_direction = "Y"
    wave.inputs["Distortion"].default_value = 0.4
    ridge = k.mat("ridge", (210, 206, 196), var=0.05, scale=4)
    plain = k.mat("plain", (176, 172, 164), var=0.08, scale=3)
    moss = k.mat("moss", (52, 92, 50), var=0.3, scale=1.5)
    stone = k.mat("mossy", (118, 114, 108), kind="grad", rgb2=(76, 104, 64))
    p = [k.box((W - 0.4, D - 0.4, 0.3), (0, 0, 0.15), m=gravel)]
    for sx in (-1, 1):
        p.append(k.box((0.7, D + 0.7, 0.55), (sx * W / 2, 0, 0.27), m=curb, bevel=0.1))
    for sy in (-1, 1):
        p.append(k.box((W + 0.7, 0.7, 0.55), (0, sy * D / 2, 0.27), m=curb, bevel=0.1))
    for (x, y, r) in ((-4.5, 1.0, 1.8), (2.5, -1.5, 1.3), (5.8, 2.2, 0.9)):
        # Plain gravel under the rings hides the straight raking there.
        p.append(k.cyl(r + 2.6, 0.04, (x, y, 0.31), m=plain, n=24))
        p.append(k.cyl(r + 0.6, 0.12, (x, y, 0.36), m=moss, n=14))
        p.append(_stone(rng, (x, y, 0.3 + r * 0.35), r, (1.0, 0.9, 0.95), stone))
        for j in range(3):
            p.append(k.ring(r + 1.0 + 0.55 * j, 0.34, 0.08, ridge, n=22, sides=3, centre=(x, y)))
    return p


def lily_pads():
    rng = random.Random(3)
    pad = k.mat("pad", (46, 96, 50), var=0.25, scale=2, rgb2=(80, 130, 60))
    petal = k.mat("petal", (255, 170, 205), kind="grad", rgb2=(255, 236, 245), emit=0.5)
    heart = k.mat("heart", (250, 210, 90), kind="flat", emit=1.0)
    p = []
    spots = [(0, 0, 1.2), (2.4, 0.8, 0.9), (-2.0, 1.4, 1.0), (0.8, -2.2, 0.8), (-1.2, -1.8, 0.7), (3.0, -1.5, 1.1), (-3.3, -0.6, 0.75)]
    for x, y, r in spots:
        gap = math.radians(rng.uniform(0, 360))
        pts = [(math.cos(gap + 0.35 + t / 13 * (2 * math.pi - 0.7)) * r, math.sin(gap + 0.35 + t / 13 * (2 * math.pi - 0.7)) * r) for t in range(14)]
        p.append(k.poly([(0, 0)] + pts, 0.06, loc=(x, y, 0.03), rot=(90, 0, 0), m=pad))
    for x, y in ((0.3, 0.2), (-2.0, 1.4)):
        for i in range(8):
            a = 2 * math.pi * i / 8
            leaf = k.ico(0.42, (x + math.cos(a) * 0.32, y + math.sin(a) * 0.32, 0.42), m=petal, scale=(1.0, 0.45, 0.22), subdiv=1,
                         rot=(0, -50, math.degrees(a)))
            p.append(leaf)
        p.append(k.cyl(0.2, 0.25, (x, y, 0.3), m=heart, n=8))
    return p


ASSETS = [
    dict(name="bamboo_cluster", build=bamboo_cluster, budget=3600, size=[12, 26, 12], priority=4, order=7,
         replaces="New dressing: bamboo clumps behind the stalls, behind the pond and outside the wall (src/night/Arena.luau garden())"),
    dict(name="pine_tree", build=pine_tree, budget=2800, size=[16, 19, 14], priority=4, order=8,
         replaces="New dressing: black pines along the wall and by the pond (src/night/Arena.luau garden())"),
    dict(name="hydrangea_bush", build=hydrangea_bush, budget=1800, size=[6.5, 3.6, 5], priority=4, order=9,
         replaces="New dressing: hydrangea bushes at the wall foot (src/night/Arena.luau garden())"),
    dict(name="garden_rocks", build=garden_rocks, budget=1100, size=[8, 3, 5], priority=4, order=10,
         replaces="New dressing: mossy rock groups at the pond rim and wall foot (src/night/Arena.luau garden())"),
    dict(name="zen_garden", build=zen_garden, budget=2600, size=[18.7, 3, 11.7], priority=4, order=11,
         replaces="New dressing: raked-gravel garden west of the spawn (src/night/Arena.luau garden())",
         notes="Low (rocks under 3 studs); ghosted so players and telegraphs pass over it."),
    dict(name="lily_pads", build=lily_pads, budget=800, size=[8, 0.8, 5], priority=4, order=12,
         replaces="New dressing: lily pads and lotus on the koi pond (src/night/Arena.luau pond())"),
]
