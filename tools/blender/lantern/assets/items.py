"""Lantern Express carried items (docs/architecture/lantern.md section 9): coal sack, parts bag, oil
can, supply crate and critter crate. Chunky toy props in the art bible palette, each with its own
colour so a player tells them apart at 20 studs: plum-grey coal sack with black lumps, teal tool bag
with a brass cog, amber oil can, timber supply crate, timber-and-teal critter carrier. Built at stud
scale, base at z = 0, front -Y. Code bobs them and lights them in the rarity colour."""

import math

import kit as k
from mathutils import Matrix

COAL = (40, 34, 52)
ROPE = (214, 186, 130)
TEAL = [(0, (40, 92, 104)), (1, (76, 142, 150))]


def gear(r, teeth, depth, m, loc, rot=(0, 0, 0), name="gear"):
    """A flat toy cog in local x/z, extruded along local y."""
    pts = []
    for i in range(teeth):
        a0 = 2 * math.pi * i / teeth
        for da, rr in ((-0.3, 0.74), (-0.16, 1.0), (0.16, 1.0), (0.3, 0.74)):
            a = a0 + da * 2 * math.pi / teeth
            pts.append((r * rr * math.cos(a), r * rr * math.sin(a)))
    return k.poly(pts, depth, loc=loc, rot=rot, m=m, name=name)


def item_coal_sack():
    # Two cream stencil stripes round the middle: rings of a distant centre below the sack (a
    # disc label with a dark dot read as an eye).
    sack = k.paint("ic_sack", [(0, (70, 60, 88)), (0.6, (104, 92, 128)), (1, (124, 112, 150))], 0, 1.2, grain=(0.08, 6, "wave"),
                   marks=[(k.CREAM, (0, 0, -6), 6.5, 6.58), (k.CREAM, (0, 0, -6), 6.68, 6.76)])
    coal = k.paint("ic_coal", [(0, COAL), (1, (62, 54, 78))], 1.1, 1.4, dots=[((112, 100, 132), 9, 0.1)])
    rope = k.flat(ROPE)
    body = [
        k.lathe([(0.6, 0), (0.74, 0.06), (0.8, 0.25), (0.8, 0.55), (0.72, 0.82), (0.52, 0.98), (0.36, 1.05), (0.4, 1.12), (0.52, 1.18), (0.57, 1.2)],
                m=sack, n=18, scale=(1, 0.76, 1), name="sack"),
        k.lathe([(0.52, 1.1), (0.44, 1.24), (0.22, 1.3), (0, 1.32)], m=coal, n=12, scale=(1, 0.75, 1), name="coal"),
    ]
    for x, y, z, r in ((0.2, 0.02, 1.28, 0.15), (-0.22, 0.08, 1.26, 0.14), (0.0, -0.16, 1.24, 0.13), (-0.04, 0.16, 1.29, 0.12)):
        body.append(k.ico(r, (x, y, z), m=coal, subdiv=1, scale=(1, 1, 0.8), name="lump"))
    body.append(k.tube([(0.39 * math.cos(2 * math.pi * i / 12), 0.3 * math.sin(2 * math.pi * i / 12), 1.05) for i in range(13)], 0.05, m=rope, n=5, cap=False, name="tie"))
    body.append(k.sphere(0.08, (0, -0.31, 1.05), m=rope, seg=8, rings=4, name="knot"))
    for dx in (-1, 1):
        body.append(k.tube([(0, -0.32, 1.04), (dx * 0.1, -0.36, 0.9), (dx * 0.14, -0.37, 0.78)], 0.035, m=rope, n=4, name="tail"))
    return body


def item_parts_bag():
    canvas = k.paint("ip_canvas", TEAL, 0, 1.1, grain=(0.08, 6, "wave"))
    leather = k.paint("ip_leather", [(0, (104, 66, 48)), (1, (138, 92, 64))], 0, 1.2)
    brass = k.brass("ip_brass", 0, 1.2)
    body = [
        k.box((1.6, 1.1, 0.8), (0, 0, 0.4), m=canvas, bevel=0.28, seg=2, name="bag"),
        k.lathe([(0, -0.78), (0.3, -0.76), (0.4, -0.66), (0.4, 0.66), (0.3, 0.76), (0, 0.78)], loc=(0, 0, 0.74), rot=(0, 90, 0), m=leather, n=14, scale=(1.0, 0.9, 1), name="frame"),
        k.box((1.5, 0.08, 0.06), (0, -0.37, 0.98), m=brass, name="seam"),
        k.box((0.26, 0.12, 0.2), (0, -0.4, 0.86), m=brass, bevel=0.04, name="clasp"),
        gear(0.24, 8, 0.05, brass, (0, -0.575, 0.4), name="cog"),
        k.cyl(0.08, 0.04, (0, -0.6, 0.4), rot=(90, 0, 0), m=leather, n=8, name="hub"),
    ]
    for x in (-0.48, 0.48):
        for s in (-1, 1):
            body.append(k.box((0.16, 0.06, 0.62), (x, s * 0.555, 0.4), m=leather, name="strap"))
    for y in (-0.12, 0.12):
        pts = [(-0.34 + 0.68 * i / 8, y, 1.0 + 0.15 * math.sin(math.pi * i / 8)) for i in range(9)]
        body.append(k.tube(pts, 0.05, m=leather, n=6, name="handle"))
    return body


def item_oil_can():
    """A lamp-oil can: amber body with a teal label, a domed shoulder, a long brass spout and a
    handle at the back. 1.0 x 1.6 x 1.0 (the can is a little oval, wider than deep)."""
    # The teal label is a hard band in the ramp (stops 0.002 apart), the logo two marks on it.
    tin = k.paint("io_tin", [(0, (206, 136, 46)), (0.27, (226, 156, 60)), (0.272, (44, 98, 110)), (0.636, (70, 136, 144)), (0.638, (240, 176, 74)), (1, (255, 206, 120))], 0, 1.1,
                  marks=[(k.CREAM, (0, -0.42, 0.5), 0, 0.16), (k.AMBER, (0, -0.44, 0.5), 0, 0.07)])
    brass = k.brass("io_brass", 0, 1.6)
    iron = k.flat(k.IRON)
    body = [
        k.lathe([(0.36, 0), (0.42, 0.04), (0.44, 0.1), (0.44, 0.78), (0.4, 0.88), (0.26, 1.0), (0.14, 1.05), (0.12, 1.1)], loc=(0, 0.04, 0), m=tin, n=18, scale=(1.13, 1, 1), name="can"),
        k.capsule((0, -0.02, 1.0), (0, -0.38, 1.565), 0.1, 0.035, brass, n=8, name="spout"),
        k.lathe([(0.16, 0), (0.13, 0.08), (0.13, 0.12)], loc=(0, 0.04, 1.06), m=brass, n=10, name="collar"),
    ]
    pts = [(0, 0.36 + 0.18 * math.sin(math.pi * i / 8), 0.42 + 0.52 * i / 8) for i in range(9)]
    body.append(k.tube(pts, 0.055, m=iron, n=6, name="handle"))
    return body


def item_supply_crate():
    """A 3-stud plank crate: timber battens round every edge, iron corner caps, rope handles, a
    cream roundel with an amber lantern dot on each side."""
    marks = []
    for n in ((0, -1.5, 1.5), (0, 1.5, 1.5), (-1.5, 0, 1.5), (1.5, 0, 1.5), (0, 0, 3.0)):
        marks += [(k.CREAM, n, 0, 0.55), (k.AMBER, n, 0, 0.22)]
    board = k.paint("is_board", [(0, (150, 106, 78)), (1, (178, 128, 92))], 0, 3, bands=((134, 94, 68), 0.6), grain=(0.08, 4, "wave"), marks=marks)
    batten = k.paint("is_batten", [(0, (110, 72, 52)), (1, (134, 92, 64))], 0, 3, grain=(0.1, 4, "wave"))
    iron = k.paint("is_iron", [(0, (64, 56, 90)), (1, (116, 104, 148))], 0, 3)
    rope = k.flat(ROPE)
    body = [k.box((2.84, 2.84, 2.84), (0, 0, 1.5), m=board, bevel=0.06, name="crate")]
    h, t = 1.35, 0.3
    for a in (-1, 1):
        for b in (-1, 1):
            body.append(k.box((t, t, 3.0), (a * h, b * h, 1.5), m=batten, bevel=0.05, name="batten"))
            body.append(k.box((3.0, t, t), (0, a * h, 1.5 + b * h), m=batten, bevel=0.05, name="batten"))
            body.append(k.box((t, 3.0, t), (a * h, 0, 1.5 + b * h), m=batten, bevel=0.05, name="batten"))
    for a in (-1, 1):
        for b in (-1, 1):
            for c in (-1, 1):
                body.append(k.box((0.42, 0.42, 0.42), (a * 1.29, b * 1.29, 1.5 + c * 1.29), m=iron, name="corner"))
    for s in (-1, 1):
        pts = [(s * 1.45, -0.45 + 0.9 * i / 6, 2.45 - 0.28 * math.sin(math.pi * i / 6)) for i in range(7)]
        body.append(k.tube(pts, 0.05, m=rope, n=6, name="rope_handle"))
        for y in (-0.45, 0.45):
            body.append(k.cyl(0.11, 0.08, (s * 1.44, y, 2.45), rot=(0, 90, 0), m=iron, n=5, name="eye"))
    return body


def item_critter_crate():
    """A toy pet carrier for two: a plank body under a round vault, teal ends, a round porthole on
    the front (a glow mesh code can tint to the rarity colour), rows of air holes, brass carry bars
    at both ends (the two carriers' handles) and runners. 3.6 x 3 x 2.6."""
    L, R, ZV = 1.5, 1.25, 1.75  # half length (x), half depth (y) and the vault's axis height
    holes = []
    for i in range(5):
        x = -1.0 + 0.5 * i
        for a in (55, 90, 125):
            t = math.radians(a)
            holes.append((COAL, (x, R * math.cos(t), ZV + R * math.sin(t)), 0, 0.1))
        holes.append((COAL, (x, R, 1.1), 0, 0.1))
    wood = k.paint("ic_wood", [(0, (150, 106, 78)), (1, (182, 132, 96))], 0, 3, axis="Z", bands=((134, 94, 68), 0.42), grain=(0.08, 4, "wave"), marks=holes)
    ends = k.paint("ic_ends", TEAL, 0, 3, grain=(0.08, 5, "wave"), marks=[(COAL, (s * L, y, 2.4), 0, 0.09) for s in (-1, 1) for y in (-0.5, 0, 0.5)])
    brass = k.brass("ic_brass", 0, 3)
    iron = k.flat(k.IRON)
    lamp = k.flat(k.LAMP_GLOW)
    body = [
        k.box((2 * L, 2 * R, ZV - 0.1), (0, 0, (ZV + 0.1) / 2), m=wood, bevel=0.12, seg=2, name="box"),
        k.surface(16, 2, lambda u, v: (-L + 2 * L * v, (R - 0.05) * math.cos(math.pi * u), ZV + (R - 0.05) * math.sin(math.pi * u)), m=wood, thickness=0.1, name="vault"),
    ]
    # Teal end caps: the box end and the vault's half disc, slightly proud, with a brass rim.
    for s in (-1, 1):
        cap = [(R, 0.12)] + [(R * math.cos(math.pi * i / 12), ZV + R * math.sin(math.pi * i / 12)) for i in range(13)] + [(-R, 0.12)]
        body.append(k.poly([(-y, z) for y, z in cap], 0.16, loc=(s * (L + 0.02), 0, 0), rot=(0, 0, 90), m=ends, name="end"))
        body.append(k.ring(R - 0.07, 0, 0.06, brass, n=13, sides=4, name="end_rim"))
        body[-1].data.transform(Matrix.Translation((s * (L + 0.1), 0, ZV)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
        # Carry bar: a brass U standing off the end, the carrier's grip.
        bar = [(s * (L + 0.06), -0.7, 1.55), (s * (L + 0.2), -0.62, 1.55), (s * (L + 0.22), 0.0, 1.55), (s * (L + 0.2), 0.62, 1.55), (s * (L + 0.06), 0.7, 1.55)]
        body.append(k.tube(bar, 0.08, m=brass, n=6, name="handle"))
    for y in (-0.95, 0.95):
        body.append(k.box((3.1, 0.3, 0.2), (0, y, 0.1), m=iron, bevel=0.06, name="runner"))
    # Front porthole (the window): a brass ring round a glass pane, two bars, a tag below.
    body.append(k.ring(0.62, 0, 0.08, brass, n=20, sides=4, name="window_ring"))
    body[-1].data.transform(Matrix.Translation((0, -R - 0.01, 1.6)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    glow = [k.cyl(0.6, 0.05, (0, -R - 0.02, 1.6), rot=(90, 0, 0), m=lamp, n=20, name="window")]
    for x in (-0.2, 0.2):
        body.append(k.box((0.07, 0.07, 1.2), (x, -R - 0.05, 1.6), m=brass, name="window_bar"))
    tag = k.paint("ic_tag", [(0, k.CREAM), (1, k.CREAM)], 0, 1, marks=[(k.AMBER, (0, -R - 0.03, 0.6), 0, 0.12)])
    body.append(k.box((0.7, 0.05, 0.42), (0, -R - 0.02, 0.6), m=tag, bevel=0.03, name="tag"))
    return {"": body, "glow": glow}


ASSETS = [
    dict(name="item_coal_sack", build=item_coal_sack, budget=800, finalize=k.HD, size=[1.6, 1.4, 1.2], priority=1, order=20,
         replaces="coal item fallback (dark block)",
         notes="Coal sack, 1.6 x 1.4 x 1.2, base centre origin: plum-grey sack with two cream stripes, coal heaped in its open neck. One mesh. Welded to backs when carried (code).", glow={}),
    dict(name="item_parts_bag", build=item_parts_bag, budget=800, finalize=k.HD, size=[1.6, 1.2, 1.2], priority=1, order=21,
         replaces="parts item fallback (brown block)",
         notes="Spare-parts tool bag, 1.6 x 1.2 x 1.2: teal canvas, leather straps and handles, a brass cog on the front (-Z). One mesh.", glow={}),
    dict(name="item_oil_can", build=item_oil_can, budget=600, finalize=k.HD, size=[1.0, 1.6, 1.0], priority=1, order=22,
         replaces="oil item fallback (yellow cylinder)",
         notes="Lamp-oil can, 1.0 x 1.6 x 1.0: amber can, teal label on the front (-Z), spout leaning forward, handle at the back. One mesh.", glow={}),
    dict(name="item_supply_crate", build=item_supply_crate, budget=900, finalize=k.HD, size=[3, 3, 3], priority=1, order=23,
         replaces="supply crate fallback (wooden block)",
         notes="Supply crate, 3 x 3 x 3: planks, battens, iron corners, rope handles on the left and right, cream-and-amber roundels on four sides and the top. One mesh. Carried in front (code).", glow={}),
    dict(name="item_critter_crate", build=item_critter_crate, budget=1200, finalize=k.HD, size=[3.6, 3, 2.6], priority=1, order=24,
         replaces="critter crate fallback (block with handles)",
         notes=("Critter carrier, 3.6 x 3 x 2.6: the long axis is x, brass carry bars at both ends (1.55 up) for the two carriers in line; air holes on the "
                "vault and back, runners underneath. Two meshes: item_critter_crate (textured) and item_critter_crate_glow (the round front window on -Z, "
                "1.2 across, centre 1.6 up: Neon, warm by default; code may tint it to the rarity colour beside its rarity light)."),
         glow={"glow": k.LAMP_GLOW}),
]
