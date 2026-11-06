"""Petal Catch: the prize wheel stand and disc, the basket, the drops and the blossom tree.

Sizes and pivots follow docs/architecture/garden-wheel.md section 6. Pivots are not kept on import
(the loader keeps bounding box centres), so the disc is symmetric about its axle on every axis and
the stand's pointer is the highest point at the top centre. Front is Blender -Y."""

import math

import bmesh
import kit as k
from mathutils import Matrix

# Disc order clockwise from the pointer (GardenConfig.WHEEL.wedges); colours are
# ClientState.EGG_COLOURS pairs, Coins in gold.
WEDGES = [
    ("meadow", (200, 245, 190), (150, 220, 150)),
    ("forest", (120, 170, 90), (110, 85, 60)),
    ("sunset", (255, 170, 80), (255, 120, 170)),
    ("coins", k.GOLD_MID, k.GOLD_HI),
    ("moon", (60, 70, 140), (30, 30, 80)),
    ("star", (255, 252, 235), (255, 205, 90)),
    ("celestial", (255, 246, 205), (170, 150, 255)),
    ("aurora", (60, 130, 150), (80, 50, 140)),
]


def _sector(r0, r1, a0, a1, h, m, steps=6, name="sector"):
    """Thick annular sector in the XY plane from math angle a0 to a1 (degrees), z from -h to h."""
    bm = bmesh.new()
    rows = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        c, s = math.cos(a), math.sin(a)
        rows.append([bm.verts.new((r * c, r * s, z)) for r, z in ((r0, -h), (r1, -h), (r1, h), (r0, h))])
    for a, b in zip(rows, rows[1:]):
        for q in range(4):
            j = (q + 1) % 4
            bm.faces.new((a[q], a[j], b[j], b[q]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return k._obj(name, bm, m)


def wheel_disc():
    rim = k.flat(k.SNOW, name="wd_rim")
    hub = k.flat(k.SUNNY)
    star_m = k.flat(k.CORAL)
    h = 0.27
    parts = []
    # Built face-up in XY (wedge 0 centred on +Y, clockwise towards +X), then tipped to face -Y.
    for i, (_, outer, inner) in enumerate(WEDGES):
        a1 = 112.5 - 45 * i
        a0 = a1 - 45
        parts.append(_sector(1.45, 2.72, a0, a1, h, k.flat(outer), name="wedge"))
        parts.append(_sector(0.5, 1.45, a0, a1, h, k.flat(inner), name="wedge"))
        parts.append(_sector(2.72, 3.0, a0, a1, 0.3, rim, name="rim"))
        parts.append(k.box((0.12, 2.24, 0.58), (1.61 * math.cos(math.radians(a1)), 1.61 * math.sin(math.radians(a1)), 0), rot=(0, 0, a1 - 90), m=rim, name="spoke"))
    parts.append(k.cyl(0.55, 0.6, m=hub, n=16, name="hub"))
    for side in (1, -1):
        s = k.star(0.42, star_m, depth=0.04, name="star")
        s.data.transform(Matrix.Translation((0, 0, side * 0.26)) @ Matrix.Rotation(0 if side > 0 else math.pi, 4, "X"))
        parts.append(s)
    for ob in parts:
        ob.data.transform(Matrix.Rotation(math.radians(90), 4, "X"))  # +Z face -> -Y front, +Y -> up
    return parts


def wheel_stand():
    foot = k.paint("ws_foot", [(0, (70, 195, 205)), (1, (130, 230, 215))], 0, 1.0)
    post = k.paint("ws_post", [(0, k.SNOW), (1, k.SNOW)], 0, 3, bands=((255, 120, 160), 0.6))
    board = k.paint("ws_board", [(0, k.CREAM), (1, k.SNOW)], 2, 8)
    bulb_a, bulb_b = k.flat(k.CORAL), k.flat(k.SUNNY)
    pointer = k.flat(k.CORAL)

    # Depth 2 centred on y 0: the disc (a separate model) turns at y -0.5, z 5, radius 3, so the
    # board starts at y 0 behind it and the pointer hangs in front at y -1, its top the model's top.
    parts = [
        k.lathe([(2.4, 0), (2.4, 0.3), (1.6, 0.7), (0.7, 1.0)], m=foot, n=20, scale=(1, 0.4, 1), name="foot"),
        k.lathe([(0.55, 0.9), (0.55, 2.4)], loc=(0, 0.3, 0), m=post, n=12, name="post"),
        k.box((7.0, 1.0, 5.2), (0, 0.5, 4.8), m=board, bevel=0.5, seg=3, name="board"),
        k.poly([(-0.5, 8.0), (0.5, 8.0), (0, 7.1)], 0.2, loc=(0, -0.9, 0), m=pointer, bevel=0.04, name="pointer"),
    ]
    for i, (x, z) in enumerate(((-3.1, 2.7), (-3.1, 5.0), (-3.1, 7.0), (3.1, 2.7), (3.1, 5.0), (3.1, 7.0), (-2.4, 7.2), (2.4, 7.2))):
        parts.append(k.sphere(0.26, (x, -0.1, z), m=bulb_a if i % 2 else bulb_b, seg=10, rings=6, name="bulb"))
    return parts


def wheel_basket():
    weave = k.paint("wb_weave", [(0, (205, 150, 95)), (1, (238, 195, 135))], 0, 0.9, bands=((180, 125, 75), 0.14))
    trim = k.flat((165, 110, 65))
    parts = [k.lathe([(0.42, 0), (0.68, 0.12), (0.75, 0.5), (0.7, 0.82), (0.57, 0.82), (0.6, 0.55), (0.52, 0.22), (0, 0.2)], m=weave, n=16, name="bowl")]
    for z, r in ((0.13, 0.67), (0.5, 0.74), (0.82, 0.63)):
        ring = [(r * math.cos(2 * math.pi * i / 16), r * math.sin(2 * math.pi * i / 16), z) for i in range(17)]
        parts.append(k.tube(ring, 0.06, m=trim, n=6, cap=False, name="hoop"))
    arc = [(-0.72 * math.cos(t), 0, 0.72 + 0.72 * math.sin(t)) for t in (math.radians(a) for a in range(0, 181, 18))]
    parts.append(k.tube(arc, 0.07, m=trim, n=6, name="handle"))
    return parts


PETAL = [(-0.6, 0), (-0.45, 0.14), (-0.2, 0.3), (0.1, 0.4), (0.35, 0.4), (0.52, 0.3), (0.6, 0.16), (0.48, 0.0), (0.6, -0.16), (0.52, -0.3), (0.35, -0.4), (0.1, -0.4), (-0.2, -0.3), (-0.45, -0.14)]


def _petal(m):
    # Flat in XY (Roblox horizontal), notched tip along +X, 1.2 long.
    return [k.poly(PETAL, 0.1, rot=(90, 0, 0), m=m, name="petal")]


def petal_pink():
    return _petal(k.paint("pp", [(0, k.BLUSH), (1, k.ROSE)], -0.6, 0.6, axis="X"))


def petal_gold():
    return _petal(k.paint("pg", [(0, (255, 250, 200)), (1, (255, 200, 80))], -0.6, 0.6, axis="X"))


def _scaled(profile, m, n, name):
    """Lathe whose rings alternate a half-segment twist, so the bulges read as round scales."""
    bm = bmesh.new()
    rings = []
    for i, (r, z) in enumerate(profile):
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        off = math.pi / n if i % 2 else 0
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * q / n + off), r * math.sin(2 * math.pi * q / n + off), z)) for q in range(n)])
    for a, b in zip(rings, rings[1:]):
        for q in range(n):
            j = (q + 1) % n
            if len(a) == 1:
                bm.faces.new((a[0], b[q], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[q], a[j], b[0]))
            else:
                bm.faces.new((a[q], a[j], b[q]))
                bm.faces.new((a[j], b[j], b[q]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return k._obj(name, bm, m)


def pinecone():
    brown = k.paint("pc", [(0, (125, 82, 55)), (1, (185, 132, 90))], 0, 0.95, bands=((210, 160, 112), 0.19))
    return [
        _scaled([(0, 0), (0.24, 0.06), (0.3, 0.17), (0.37, 0.3), (0.35, 0.47), (0.33, 0.62), (0.25, 0.75), (0.14, 0.86), (0, 0.92)], brown, 8, "cone"),
        k.tube([(0, 0, 0.88), (0, 0, 1.0)], 0.05, m=k.flat((120, 90, 60)), n=4, name="stem"),
    ]


def wheel_tree():
    bark = k.paint("wt_bark", [(0, (150, 100, 70)), (1, (195, 140, 100))], 0, 14)
    bloom = k.paint("wt_bloom", [(0, (255, 165, 200)), (1, (255, 215, 232))], 12, 20, dots=[((255, 242, 248), 1.1, 0.16)])
    deep = k.paint("wt_deep", [(0, (240, 120, 170)), (1, (255, 180, 210))], 12, 20, dots=[((255, 228, 238), 1.1, 0.16)])

    # Trunk at the origin, canopy 24 across with its blobs in symmetric rings so the bounding box
    # centre stays on the trunk; underside about 13, top 20.
    parts = [k.lathe([(2.7, 0), (2.3, 0.6), (2.0, 2.0), (1.8, 9), (1.4, 14)], m=bark, n=14, name="trunk")]
    puffs = [((0, 0, 16.9), 3.6, bloom)]
    for i in range(8):
        a = math.radians(45 * i)
        puffs.append(((8.6 * math.cos(a), 8.6 * math.sin(a), 16.5), 3.4, bloom if i % 2 else deep))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        puffs.append(((5.5 * math.cos(a), 5.5 * math.sin(a), 15.0), 2.6, deep))
    for loc, r, m in puffs:
        parts.append(k.puff(r, loc, m, scale=(1, 1, 0.85), name="crown"))
    for loc, _, _ in puffs[1:9]:
        parts.append(k.tube([(0, 0, 12.0), (loc[0] * 0.45, loc[1] * 0.45, 14.0), (loc[0] * 0.8, loc[1] * 0.8, loc[2] - 1.5)], [0.75, 0.5, 0.3], m=bark, n=6, name="branch"))
    return parts


CLIENT = "Client-only clone from NightModels; no collision."
ASSETS = [
    dict(name="wheel_stand", build=wheel_stand, budget=3000, size=[7, 8, 2], priority=2, order=8, replaces="WheelWorld stand fallback (Wood post and board)",
         notes="Static decor. Front on Blender -Y (Roblox -Z at yaw 0). The pointer is the top centre of the bounding box. The disc is not in this model: its axle is 5 up and 0.5 in front of the bounding box centre, so the board face sits at depth 0 and the pointer hangs in front of the disc."),
    dict(name="wheel_disc", build=wheel_disc, budget=3000, size=[6, 6, 0.6], priority=2, order=9, replaces="WheelFx disc fallback (Cylinder and 8 wedge parts)",
         notes="One mesh, symmetric about the axle on all three axes, so the bounding box centre is the axle. Faces Blender -Y; the client turns it about Roblox z. Wedges clockwise from the top at rest: meadow, forest, sunset, coins, moon, star, celestial, aurora (EGG_COLOURS pairs, Coins gold), 45 degrees each, meadow centred under the pointer at angle 0. " + CLIENT),
    dict(name="wheel_basket", build=wheel_basket, budget=1500, size=[1.6, 1.5, 1.6], priority=2, order=10, replaces="WheelFx basket fallback (Cylinder)",
         notes="Handle arcs along x. Welded to the right hand by the client. " + CLIENT),
    dict(name="petal_pink", build=petal_pink, budget=100, size=[1.2, 0.1, 0.8], priority=2, order=11, replaces="WheelFx pink drop fallback (flattened Ball)",
         notes="Flat, lying horizontal, notched tip along +x. " + CLIENT),
    dict(name="petal_gold", build=petal_gold, budget=100, size=[1.2, 0.1, 0.8], priority=2, order=12, replaces="WheelFx gold drop fallback (flattened Ball)",
         notes="Same shape as petal_pink, baked bright gold. " + CLIENT),
    dict(name="pinecone", build=pinecone, budget=200, size=[0.8, 1, 0.8], priority=2, order=13, replaces="WheelFx cone drop fallback (brown Ball)",
         notes="Upright, stem at the top, round scales. " + CLIENT),
    dict(name="wheel_tree", build=wheel_tree, budget=3000, size=[24, 20, 24], priority=3, order=14, replaces="Props.sakura canopy fallback in WheelWorld",
         notes="Trunk (radius about 2 at the canopy) at the bounding box centre in x and z; canopy underside about 13, top 20. Decor: WheelWorld's own trunk Cylinder collides."),
]
