"""The rest of the Animal Stations beta pool (decision 0037), to the Rhino's standard: jointed
pieces (body, head, four legs, tail) with a dangerous look. Each animal has a basic model and one
rare variant with a new skin and glowing `_glow` pieces. Facing Blender -Y; left is +X.

The Jackal, Cheetah and Meerkat share one predator body with their own numbers. The
Tortoise and Flamingo are built on their own; the lions are in lions.py, the elephants in elephants.py. The Flamingo has two legs: its wings are
the "back legs", so the same joints and moves work for it.
"""

import math
import random

import kit as k
from mathutils import Vector

INK = (16, 13, 18)
BONE = (214, 200, 172)
GOLD = (255, 196, 64)


def shard(base, tip, r, m, name="shard"):
    b, t = Vector(base), Vector(tip)
    return k.tube([b, b + (t - b) * 0.45, t], [r, r * 0.74, 0.0], m=m, n=5, name=name)


def ring(centre, axis, r, thick, m, name="ring"):
    """A band round `axis` at `centre` (a collar, an anklet)."""
    axis = Vector(axis).normalized()
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(axis)
    pts = [Vector(centre) + (side * math.cos(a) + up * math.sin(a)) * r for a in [i / 16 * math.tau for i in range(17)]]
    return k.tube(pts, [thick] * 17, m=m, n=6, name=name)


def leg(skin, x, y, top, r, r2, foot_r, claw, name, foot_rgb=None, toes=3):
    """A leg from `top` (inside the body) down to a clawed foot on the ground."""
    knee = (x, y - 0.05, top * 0.52)
    foot = Vector((x, y - 0.12, foot_r * 0.5))
    ob = k.fuse(
        [
            ("capsule", (x, y, top), knee, r),
            (knee, r * 1.06, (1.0, 1.0, 0.85)),
            ("capsule", knee, (x, y - 0.07, foot_r * 0.9), r2),
            (tuple(foot), foot_r, (0.95, 1.15, 0.55)),
        ],
        skin,
        tris=420,
        soft=0.22,
        name=name,
    )
    if foot_rgb:
        k.zone(skin, foot_rgb, (x, y - 0.1, 0.1), (foot_r * 1.6, foot_r * 1.8, foot_r * 0.8), soft=0.5)
    claws = []
    for a in (-36, 0, 36) if toes == 3 else (-48, -16, 16, 48):
        d = k.outward(a, 0)
        base = foot + d * foot_r * 0.72
        pts = [base, base + d * foot_r * 0.45 - Vector((0, 0, 0.05)), base + d * foot_r * 0.7 - Vector((0, 0, foot_r * 0.42))]
        claws.append(k.horn(pts, [foot_r * 0.28, foot_r * 0.2, 0.0], claw, n=6, steps=5, name="claw"))
    return [ob, *claws]


def eyes(skull, skin, hc, theta, phi, r, iris, socket, glowing):
    """Slanted eyes in dark sockets. Returns (baked parts, glowing parts)."""
    parts, glows = [], []
    for side in (-1, 1):
        d = k.outward(side * theta, phi)
        p, n = k.land(skull, hc, d)
        k.zone(skin, socket, p, (r * 2.4, r * 2.9, r * 1.9), soft=0.5)
        dome = k.lens(skull, hc, d, r, k.flat(iris, emit=0.3 if glowing else 0.0), scale=(1.3, 0.78), thick=0.5, sink=0.5, up=(0, -0.42, 1), seg=14, name="eye")
        if glowing:
            glows.append(dome)
        else:
            parts.append(dome)
            parts.append(k.lens(dome, p, n, r * 0.48, k.flat(INK), scale=(0.62, 1.0), thick=0.3, sink=0.4, up=(0, -0.42, 1), seg=10, name="pupil"))
    return parts, glows


def predator(c):
    """A four-legged hunter from the numbers in `c`. Returns (groups, torso, skull, head centre)."""
    skin, claw = c["skin"], k.flat(c.get("claw", (40, 34, 36)))
    cz, cr, wr, hr, L = c["chest_z"], c["chest_r"], c["waist_r"], c["hip_r"], c["len"]
    torso = k.fuse(
        [
            ((0, 0, cz), cr, (0.82, 1.05, 1.0)),
            ((0, L * 0.5, cz + 0.03), wr, (0.82, L * 0.62 / wr, 0.92)),
            ((0, L, cz + 0.05), hr, (0.86, 1.0, 0.98)),
            *k.pair((cr * 0.5, -0.05, cz + 0.05), cr * 0.66, (0.55, 1.0, 1.12)),
            *k.pair((hr * 0.5, L, cz), hr * 0.7, (0.55, 1.0, 1.12)),
        ],
        skin,
        tris=1900,
        soft=0.22,
        name="torso",
    )
    fx, bx = cr * 0.5, hr * 0.5
    lr, lr2, fr = c["leg_r"], c["leg_r"] * 0.76, c["foot_r"]
    R, snout = c["head_r"], c["snout"]
    neck = Vector((0, -cr * 0.72, cz + cr * 0.42))
    hc = neck + Vector((0, -c["neck"], c["head_up"]))
    tip = hc + Vector((0, -R * 0.75 - snout, -R * 0.2))
    if c["ears"] == "point":
        ears = k.pair((R * 0.55, hc.y + R * 0.35, hc.z + R * 0.95), R * 0.34, (0.5, 0.42, 1.9 * c.get("ear", 1)), (-14, 14, 0))
    else:
        ears = k.pair((R * 0.72, hc.y + R * 0.3, hc.z + R * 0.72), R * 0.3 * c.get("ear", 1), (0.9, 0.45, 1.0), (-10, 20, 0))
    skull = k.fuse(
        [
            (tuple(hc), R, (0.95, 1.08, 0.95)),
            ("capsule", tuple(neck + Vector((0, 0.35, -0.2))), tuple(hc), c["neck_r"]),
            ((0, (hc.y - R * 0.6 + tip.y) / 2, hc.z - R * 0.2), R * 0.52 * c.get("muzzle", 1), (0.9, (snout + R * 0.9) / (R * 1.04), 0.8)),
            ((0, tip.y + R * 0.28, tip.z - R * 0.3), R * 0.36, (0.9, 1.5, 0.6)),  # jaw
            *k.pair((R * 0.42, hc.y - R * 0.5, hc.z + R * 0.52), R * 0.3, (0.9, 1.5, 0.5), (20, 0, 0)),  # brow
            *ears,
            *c.get("head_extra", []),
        ],
        skin,
        tris=2000,
        soft=0.22,
        name="skull",
    )
    face, glows = eyes(skull, skin, hc, 46, 14, R * 0.19, c["iris"], c["socket"], c.get("glow_eyes", False))
    nose = hc + Vector((0, -R * 0.6 - snout, -R * 0.1))
    face.append(k.lens(skull, nose, (0, -1, 0.35), R * 0.17, k.flat(INK), scale=(1.2, 0.85), thick=0.6, sink=0.4, seg=12, name="nose"))
    line = [((0, tip.y + R * 0.45, tip.z - R * 0.05), k.outward(a, -4)) for a in (-95, -60, -25, 0, 25, 60, 95)]
    face.append(k.vein(skull, line, R * 0.05, k.flat(INK), name="mouth"))
    for side in (-1, 1):  # fangs
        p, _ = k.land(skull, (0, tip.y + R * 0.3, tip.z), k.outward(side * 38, -30))
        face.append(k.horn([p + Vector((0, 0, 0.04)), p - Vector((0, 0, R * 0.3))], [R * 0.09, 0.0], k.flat(BONE), n=6, steps=3, name="fang"))
    k.texel(face, k.FACE_TEXEL)
    t0 = Vector((0, L + hr * 0.75, cz + hr * 0.35))
    tl, tr = c["tail_len"], c["tail_r"]
    tail = k.rest(k.horn([t0, t0 + Vector((0, tl * 0.35, -tl * 0.12)), t0 + Vector((0, tl * 0.7, -tl * 0.45)), t0 + Vector((0, tl * 0.9, -tl * 0.8))], [tr * 0.8, tr * c.get("tail_fat", 1), tr * c.get("tail_fat", 1) * 0.9, tr * 0.3], skin, n=8, steps=10, name="tail"))
    groups = {
        "body": [torso],
        "head": [skull, *face],
        "leg_fl": leg(skin, fx, 0, cz, lr, lr2, fr, claw, "leg_fl", c.get("foot_rgb")),
        "leg_fr": leg(skin, -fx, 0, cz, lr, lr2, fr, claw, "leg_fr", c.get("foot_rgb")),
        "leg_bl": leg(skin, bx, L, cz, lr, lr2, fr, claw, "leg_bl", c.get("foot_rgb")),
        "leg_br": leg(skin, -bx, L, cz, lr, lr2, fr, claw, "leg_br", c.get("foot_rgb")),
        "tail": [tail],
    }
    if glows:
        groups["head_glow"] = glows
    c["joints"] = {
        "head": tuple(neck),
        "leg_fl": (fx, 0, cz - 0.1),
        "leg_fr": (-fx, 0, cz - 0.1),
        "leg_bl": (bx, L, cz - 0.1),
        "leg_br": (-bx, L, cz - 0.1),
        "tail": tuple(t0),
    }
    c["tail_tip"] = t0 + Vector((0, tl * 0.9, -tl * 0.8))
    return groups, torso, skull, hc


def side_point(c, a, y):
    """A ray onto the predator torso: `a` degrees round from the top (towards +X), at `y`."""
    return (0, y, c["chest_z"]), Vector((math.sin(math.radians(a)), 0, math.cos(math.radians(a))))


# Jackal ---------------------------------------------------------------------------------------------

JACKAL = dict(chest_z=1.75, chest_r=0.62, waist_r=0.5, hip_r=0.56, len=1.7, leg_r=0.2, foot_r=0.26, head_r=0.42, neck=0.55, head_up=0.72, neck_r=0.34, snout=0.72, ears="point", ear=1.25, tail_len=1.7, tail_r=0.2, tail_fat=1.5)


def jackal(variant=False):
    c = dict(JACKAL)
    if variant:  # Pharaoh Jackal: black, gold collar and anklets, turquoise eyes and brow gem
        c["skin"] = k.paint("jk_night", [(0, (18, 18, 26)), (1, (44, 44, 60))], 0, 3.2, rest=True, grain=(0.12, 9))
        c.update(iris=(60, 230, 220), socket=(8, 8, 12), glow_eyes=True, claw=GOLD)
    else:
        c["skin"] = k.paint("jk_sand", [(0, (120, 96, 66)), (0.5, (176, 146, 100)), (1, (150, 126, 96))], 0, 3.2, rest=True, grain=(0.14, 9))
        c.update(iris=(236, 170, 40), socket=(60, 46, 36), foot_rgb=(70, 56, 44))
    groups, torso, skull, hc = predator(c)
    skin = c["skin"]
    if variant:
        gold = k.flat(GOLD, emit=0.15)
        neck = Vector(c["joints"]["head"])
        groups["head"].append(ring(neck + (hc - neck) * 0.45, hc - neck, c["neck_r"] * 1.22, 0.07, gold, "collar"))
        groups["head"].append(ring(neck + (hc - neck) * 0.62, hc - neck, c["neck_r"] * 1.16, 0.045, gold, "collar"))
        for part, x, y in (("leg_fl", 0.31, 0), ("leg_fr", -0.31, 0), ("leg_bl", 0.28, 1.7), ("leg_br", -0.28, 1.7)):
            groups[part].append(ring((x, y - 0.06, 0.62), (0, 0, 1), 0.2, 0.05, gold, "anklet"))
        p, n = k.land(skull, hc, k.outward(0, 40))
        groups["head_glow"].append(shard(p - n * 0.05, p + n * 0.22, 0.09, k.glow((60, 230, 220))))
        k.zone(skin, GOLD, c["tail_tip"], (0.36, 0.5, 0.5), soft=0.4)
    else:
        k.zone(skin, (64, 52, 44), (0, 0.85, 2.45), (0.5, 1.5, 0.5), soft=0.6)  # dark saddle
        k.zone(skin, (206, 190, 156), (0, 0.7, 1.15), (0.5, 1.5, 0.42), soft=0.5)  # pale belly
        k.zone(skin, (40, 32, 30), c["tail_tip"], (0.36, 0.5, 0.5), soft=0.4)
    return groups, c["joints"]


# Cheetah -------------------------------------------------------------------------------------------

CHEETAH = dict(chest_z=1.95, chest_r=0.66, waist_r=0.44, hip_r=0.54, len=2.05, leg_r=0.19, foot_r=0.25, head_r=0.4, neck=0.5, head_up=0.68, neck_r=0.3, snout=0.4, ears="round", tail_len=2.6, tail_r=0.15)
BOLT = (90, 190, 255)


def cheetah(variant=False):
    c = dict(CHEETAH)
    if variant:  # Lightning Cheetah: storm-dark coat, electric spots, glowing bolts down both flanks
        c["skin"] = k.paint("ch_storm", [(0, (16, 22, 44)), (1, (36, 48, 84))], 0, 3.4, rest=True, dots=[((90, 190, 255), 5.5, 0.17)])
        c.update(iris=BOLT, socket=(6, 8, 16), glow_eyes=True, claw=(120, 200, 255))
    else:
        c["skin"] = k.paint("ch_gold", [(0, (176, 130, 70)), (0.5, (214, 164, 84)), (1, (196, 150, 80))], 0, 3.4, rest=True, dots=[((34, 26, 22), 5.5, 0.2)])
        c.update(iris=(240, 180, 40), socket=(40, 30, 24))
    groups, torso, skull, hc = predator(c)
    for side in (-1, 1):  # tear marks from the eyes down to the mouth
        marks = [(tuple(hc), k.outward(side * (40 - 6 * i), 6 - 13 * i)) for i in range(4)]
        groups["head"].append(k.vein(skull, marks, 0.035, k.flat(INK), name="tear"))
    if variant:
        rng, glow = random.Random(11), k.glow(BOLT)
        bolts = []
        for side in (-1, 1):
            for y0 in (-0.1, 0.9, 1.8):
                y, pts = y0, []
                for step in range(6):
                    y += rng.uniform(-0.22, 0.22)
                    pts.append(side_point(c, side * (16 + step * 17 + rng.uniform(-6, 6)), min(max(y, -0.4), 2.3)))
                bolts.append(k.vein(torso, pts, 0.045, glow))
        groups["body_glow"] = bolts
        groups["tail_glow"] = [k.blob(0.2, tuple(c["tail_tip"]), glow, name="spark")]
    else:
        k.zone(c["skin"], (236, 222, 196), (0, 0.9, 1.4), (0.42, 1.6, 0.4), soft=0.5)
        k.zone(c["skin"], (34, 26, 22), c["tail_tip"], (0.3, 0.4, 0.5), soft=0.3)
    return groups, c["joints"]


# Meerkat -------------------------------------------------------------------------------------------

MEERKAT = dict(chest_z=1.05, chest_r=0.42, waist_r=0.4, hip_r=0.45, len=1.45, leg_r=0.14, foot_r=0.18, head_r=0.34, neck=0.32, head_up=0.5, neck_r=0.26, snout=0.34, muzzle=0.85, ears="round", ear=0.7, tail_len=1.6, tail_r=0.1)
STORM = (80, 220, 255)


def meerkat(variant=False):
    c = dict(MEERKAT)
    if variant:  # Storm Meerkat: thundercloud coat, glowing bands across the back, a charged tail
        c["skin"] = k.paint("mk_storm", [(0, (44, 52, 70)), (1, (96, 108, 134))], 0, 2.0, rest=True, grain=(0.14, 10))
        c.update(iris=STORM, socket=(14, 18, 28), glow_eyes=True, claw=(160, 220, 255))
    else:
        c["skin"] = k.paint("mk_tan", [(0, (150, 122, 84)), (0.6, (196, 166, 116)), (1, (170, 140, 100))], 0, 2.0, rest=True, grain=(0.12, 10))
        c.update(iris=(230, 160, 40), socket=(34, 26, 22))  # the dark eye patches
    groups, torso, skull, hc = predator(c)
    bands = []
    for y in (0.15, 0.45, 0.75, 1.05, 1.35):
        pts = [side_point(c, a, y) for a in (-58, -30, 0, 30, 58)]
        bands.append(k.vein(torso, pts, 0.05 if variant else 0.04, k.glow(STORM) if variant else k.flat((96, 74, 52)), name="band"))
    if variant:
        groups["body_glow"] = bands
        groups["tail_glow"] = [k.blob(0.2, tuple(c["tail_tip"]), k.glow(STORM), name="charge")]
    else:
        groups["body"] += bands
        k.zone(c["skin"], (40, 30, 26), c["tail_tip"], (0.2, 0.3, 0.4), soft=0.3)
        k.zone(c["skin"], (222, 204, 166), (0, 0.6, 0.72), (0.3, 1.2, 0.26), soft=0.5)
    return groups, c["joints"]


# Tortoise ------------------------------------------------------------------------------------------

GEM = (255, 70, 200)


def tortoise(variant=False):
    """A war tortoise: a high plated shell with a spiked rim, thick clawed legs, a hooked beak.
    Variant: the Gemshell Tortoise, with a glowing crystal on every plate."""
    if variant:
        skin = k.paint("to_deep", [(0, (26, 46, 52)), (1, (52, 86, 92))], 0, 2.4, rest=True, grain=(0.16, 8))
        shell_m = k.paint("to_shell_v", [(0, (20, 22, 34)), (1, (52, 46, 76))], 0.6, 2.5, rest=True, grain=(0.2, 6))
        iris, socket = GEM, (10, 16, 20)
    else:
        skin = k.paint("to_skin", [(0, (74, 86, 60)), (1, (118, 128, 88))], 0, 2.4, rest=True, grain=(0.16, 8))
        shell_m = k.paint("to_shell", [(0, (52, 44, 32)), (0.6, (104, 88, 54)), (1, (138, 122, 76))], 0.6, 2.5, rest=True, grain=(0.2, 6))
        iris, socket = (230, 170, 40), (34, 40, 28)
    sc = Vector((0, 0.6, 1.25))
    plates = []
    for ring_r, n, lift in ((0.0, 1, 1.0), (0.62, 6, 0.74), (1.02, 10, 0.36)):
        for i in range(n):
            a = i / n * math.tau + ring_r
            plates.append(Vector((math.cos(a) * ring_r * 1.5, math.sin(a) * ring_r * 1.85, lift * 1.08)))
    shell = k.fuse(
        [(tuple(sc), 1.5, (1.0, 1.25, 0.72))] + [(tuple(sc + p), 0.44, (1.0, 1.0, 0.55)) for p in plates],
        shell_m,
        tris=2400,
        soft=0.2,
        name="shell",
    )
    belly = k.fuse([((0, 0.6, 0.86), 1.3, (0.95, 1.22, 0.36))], skin, tris=500, name="belly")
    bone, rng = k.flat(BONE), random.Random(3)
    rim = []
    for i in range(12):  # spikes round the shell's rim
        a = i / 12 * math.tau + 0.26
        d = Vector((math.cos(a), math.sin(a) * 0.9, 0.22)).normalized()
        base = sc + Vector((math.cos(a) * 1.42, math.sin(a) * 1.8, -0.3))
        rim.append(k.horn([base - d * 0.1, base + d * 0.3, base + d * rng.uniform(0.5, 0.7)], [0.16, 0.1, 0.0], bone, n=6, steps=4, name="spike"))
    claw = k.flat((40, 36, 30))
    hc, R = Vector((0, -1.78, 1.45)), 0.42
    skull = k.fuse(
        [
            (tuple(hc), R, (0.9, 1.15, 0.86)),
            ("capsule", (0, -0.8, 1.02), tuple(hc), 0.3),
            ((0, hc.y - 0.42, hc.z - 0.08), 0.26, (0.9, 1.2, 0.8)),
            *k.pair((0.2, hc.y - 0.12, hc.z + 0.3), 0.2, (0.9, 1.5, 0.5), (20, 0, 0)),
        ],
        skin,
        tris=1300,
        soft=0.22,
        name="skull",
    )
    face, glows = eyes(skull, skin, hc, 52, 12, 0.085, iris, socket, variant)
    beak = hc + Vector((0, -0.62, -0.06))
    face.append(k.horn([beak + Vector((0, 0.16, 0.06)), beak + Vector((0, -0.08, 0.0)), beak + Vector((0, -0.16, -0.2))], [0.2, 0.14, 0.0], k.flat((60, 50, 36)), n=8, steps=5, name="beak"))
    k.texel(face, k.FACE_TEXEL)
    tail = k.rest(k.horn([(0, 2.3, 0.95), (0, 2.7, 0.8), (0, 3.0, 0.55)], [0.2, 0.13, 0.0], skin, n=8, steps=5, name="tail"))
    groups = {
        "body": [shell, belly, *rim],
        "head": [skull, *face],
        "leg_fl": leg(skin, 1.05, -0.35, 0.95, 0.34, 0.3, 0.4, claw, "leg_fl", toes=4),
        "leg_fr": leg(skin, -1.05, -0.35, 0.95, 0.34, 0.3, 0.4, claw, "leg_fr", toes=4),
        "leg_bl": leg(skin, 1.05, 1.5, 0.95, 0.34, 0.3, 0.4, claw, "leg_bl", toes=4),
        "leg_br": leg(skin, -1.05, 1.5, 0.95, 0.34, 0.3, 0.4, claw, "leg_br", toes=4),
        "tail": [tail],
    }
    if variant:
        glow = k.glow(GEM)
        gems = []
        for p in plates:
            top, n = k.land(shell, tuple(sc + p * 0.5), p)
            gems.append(shard(top - n * 0.15, top + n * rng.uniform(0.4, 0.75), 0.17, glow))
        groups["body_glow"] = gems
        groups["head_glow"] = glows
    joints = {"head": (0, -0.85, 1.05), "leg_fl": (1.05, -0.35, 0.9), "leg_fr": (-1.05, -0.35, 0.9), "leg_bl": (1.05, 1.5, 0.9), "leg_br": (-1.05, 1.5, 0.9), "tail": (0, 2.3, 0.95)}
    return groups, joints


# Flamingo ------------------------------------------------------------------------------------------

EMBER = (255, 110, 20)


def flamingo(variant=False):
    """A tall wading bird with a hooked beak and a hard stare. It stands on two legs: the wings are
    built as the "back legs" so it shares the other animals' joints. Variant: the Phoenix Flamingo,
    with a crest, wing tips and tail of flame."""
    if variant:
        skin = k.paint("fl_fire", [(0, (120, 20, 16)), (0.5, (214, 60, 24)), (1, (255, 150, 40))], 0, 6.2, rest=True, grain=(0.1, 9))
        iris, socket, tipc = EMBER, (70, 12, 10), (60, 10, 10)
    else:
        skin = k.paint("fl_pink", [(0, (214, 90, 120)), (0.5, (246, 130, 150)), (1, (255, 170, 176))], 0, 6.2, rest=True, grain=(0.08, 9))
        iris, socket, tipc = (240, 210, 60), (150, 50, 80), (40, 30, 34)
    body = k.fuse([((0, 0.25, 3.35), 0.78, (0.8, 1.3, 0.85)), ((0, -0.45, 3.5), 0.5, (0.8, 1.0, 0.9)), ((0, 1.0, 3.4), 0.45, (0.7, 1.1, 0.7))], skin, tris=1400, soft=0.24, name="body")
    neck = k.rest(k.horn([(0, -0.6, 3.6), (0, -1.15, 4.3), (0, -0.85, 5.1), (0, -1.0, 5.75)], [0.3, 0.2, 0.17, 0.19], skin, n=10, steps=14, name="neck"))
    hc = Vector((0, -1.05, 5.9))
    skull = k.fuse([(tuple(hc), 0.34, (0.9, 1.15, 0.95)), *k.pair((0.16, hc.y - 0.1, hc.z + 0.24), 0.16, (0.9, 1.5, 0.5), (22, 0, 0))], skin, tris=700, soft=0.22, name="skull")
    face, glows = eyes(skull, skin, hc, 58, 10, 0.075, iris, socket, variant)
    b0 = hc + Vector((0, -0.3, -0.04))
    face.append(k.horn([b0, b0 + Vector((0, -0.38, -0.06)), b0 + Vector((0, -0.6, -0.26))], [0.19, 0.16, 0.12], k.flat((246, 226, 214)), n=8, steps=6, name="beak"))
    face.append(k.horn([b0 + Vector((0, -0.58, -0.24)), b0 + Vector((0, -0.7, -0.5)), b0 + Vector((0, -0.6, -0.78))], [0.125, 0.09, 0.0], k.flat(tipc), n=8, steps=6, name="beak_tip"))
    k.texel(face, k.FACE_TEXEL)
    legm = k.flat((200, 80, 110) if not variant else (90, 20, 16))

    def stilt(x, name):
        pts = [(x, 0.3, 3.0), (x, 0.5, 1.7), (x, 0.2, 0.2)]
        shank = k.horn(pts, [0.12, 0.085, 0.08], legm, n=8, steps=10, name=name)
        knee = k.blob(0.14, pts[1], legm, name="knee")
        toes = [k.horn([(x, 0.2, 0.12), (x + math.sin(math.radians(a)) * 0.5, 0.2 - math.cos(math.radians(a)) * 0.5, 0.05)], [0.07, 0.0], legm, n=6, steps=3, name="toe") for a in (-35, 0, 35)]
        return [shank, knee, *toes]

    def wing(side, name):
        return [k.fuse([((side * 0.66, 0.3, 3.45), 0.72, (0.22, 1.45, 0.82)), ((side * 0.72, 1.25, 3.2), 0.46, (0.2, 1.5, 0.6))], skin, tris=500, soft=0.25, name=name)]

    k.zone(skin, tipc, (0, 1.75, 3.1), (1.2, 0.5, 0.6), soft=0.4)  # dark wing tips
    plume_m = k.glow(EMBER) if variant else skin
    plumes = [k.horn([(x, 1.2, 3.4), (x * 1.6, 1.8, 3.3), (x * 2.2, 2.4 + abs(x), 2.9)], [0.16, 0.12, 0.0], plume_m, n=6, steps=6, name="plume") for x in (-0.18, 0, 0.18)]
    if not variant:
        k.rest(plumes)
    groups = {
        "body": [body],
        "head": [neck, skull, *face],
        "leg_fl": stilt(0.3, "leg_fl"),
        "leg_fr": stilt(-0.3, "leg_fr"),
        "leg_bl": wing(1, "leg_bl"),
        "leg_br": wing(-1, "leg_br"),
        "tail": [k.blob(0.2, (0, 1.2, 3.4), skin, name="rump")] if variant else plumes,
    }
    if variant:
        glow, rng = k.glow(EMBER), random.Random(4)
        crest = []
        for i in range(5):
            a = math.radians(-50 + i * 25)
            d = Vector((math.sin(a) * 0.5, 0.45, math.cos(a))).normalized()
            p = hc + Vector((math.sin(a) * 0.2, 0.05, 0.28))
            crest.append(shard(p - d * 0.08, p + d * rng.uniform(0.5, 0.85), 0.09, glow))
        groups["head_glow"] = glows + crest
        groups["tail_glow"] = plumes
        for side, part in ((1, "leg_bl_glow"), (-1, "leg_br_glow")):
            groups[part] = [shard((side * 0.74, 1.5 + 0.2 * i, 3.2 - 0.08 * i), (side * (0.9 + 0.1 * i), 2.3 + 0.3 * i, 2.8 - 0.25 * i), 0.13, glow) for i in range(3)]
    joints = {"head": (0, -0.6, 3.6), "leg_fl": (0.3, 0.3, 2.95), "leg_fr": (-0.3, 0.3, 2.95), "leg_bl": (0.6, -0.3, 3.8), "leg_br": (-0.6, -0.3, 3.8), "tail": (0, 1.2, 3.4)}
    return groups, joints


# Assets ---------------------------------------------------------------------------------------------


def asset(name, maker, variant, scale, glow, note, budget=11000):
    joints = {}

    def build():
        groups, j = maker(variant)
        joints.update(j)
        return groups

    return dict(name=name, build=build, scale=scale, budget=budget, finalize=k.HD, joints=joints, glow=glow, notes=note)


ASSETS = [
    asset("creature_jackal", jackal, False, 1.25, {}, "Jackal: lean pack hunter."),
    asset("creature_jackal_pharaoh", jackal, True, 1.55, {"head_glow": (60, 230, 220)}, "Pharaoh Jackal (legendary): black with gold bands; eyes and brow gem are Neon."),
    asset("creature_cheetah", cheetah, False, 1.4, {}, "Cheetah: spotted sprinter."),
    asset("creature_cheetah_lightning", cheetah, True, 1.75, {"head_glow": BOLT, "body_glow": BOLT, "tail_glow": BOLT}, "Lightning Cheetah (mythic): storm coat, Neon bolts."),
    asset("creature_meerkat", meerkat, False, 1.0, {}, "Meerkat: small and quick."),
    asset("creature_meerkat_storm", meerkat, True, 1.25, {"head_glow": STORM, "body_glow": STORM, "tail_glow": STORM}, "Storm Meerkat (legendary): Neon bands and tail charge."),
    asset("creature_tortoise", tortoise, False, 1.6, {}, "Tortoise: plated shell with a spiked rim."),
    asset("creature_tortoise_gemshell", tortoise, True, 2.0, {"head_glow": GEM, "body_glow": GEM}, "Gemshell Tortoise (legendary): a Neon crystal on every plate.", 12500),
    asset("creature_flamingo", flamingo, False, 1.3, {}, "Flamingo: two legs; its wings are the back-leg pieces.", 9000),
    asset("creature_flamingo_phoenix", flamingo, True, 1.6, {"head_glow": EMBER, "tail_glow": EMBER, "leg_bl_glow": EMBER, "leg_br_glow": EMBER}, "Phoenix Flamingo (mythic): Neon crest, wing tips and tail.", 10000),
]
