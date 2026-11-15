"""The rest of the Animal Stations beta pool (decision 0037), to the Rhino's standard: jointed
pieces (body, head, four legs, tail) with a dangerous look. Each animal has a basic model and one
rare variant with a new skin and glowing `_glow` pieces. Facing Blender -Y; left is +X.

The Jackal, Cheetah, Lion and Meerkat share one predator body with their own numbers. The
Tortoise, Elephant and Flamingo are built on their own. The Flamingo has two legs: its wings are
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


def claws_at(foot, foot_r, claw, toes=3):
    out = []
    for a in (-36, 0, 36) if toes == 3 else (-48, -16, 16, 48):
        d = k.outward(a, 0)
        base = foot + d * foot_r * 0.72
        pts = [base, base + d * foot_r * 0.45 - Vector((0, 0, 0.05)), base + d * foot_r * 0.7 - Vector((0, 0, foot_r * 0.42))]
        out.append(k.horn(pts, [foot_r * 0.28, foot_r * 0.2, 0.0], claw, n=6, steps=5, name="claw"))
    return out


def cat_leg(skin, x, y, top, r, foot_r, claw, name, front, foot_rgb=None):
    """A big cat's leg. Front: a shoulder blade, the elbow behind it, a tapering forearm and a broad
    paw. Back: a heavy thigh, the knee forward, the hock pointing back, a slim shin and the paw."""
    s = 1 if x > 0 else -1
    foot = Vector((x, y - 0.12, foot_r * 0.5))
    if front:
        elbow = Vector((x, y + 0.14, top * 0.6))
        wrist = Vector((x, y - 0.02, foot_r * 1.25))
        parts = [
            (Vector((x, y - 0.02, top - 0.05)), r * 1.35, (0.8, 1.35, 1.0)),
            ("capsule", Vector((x, y, top - 0.1)), elbow, r * 1.12),
            (elbow, r * 1.02, (0.9, 1.0, 0.9)),
            ("capsule", elbow, wrist, r * 0.78),
            (wrist, r * 0.7, (1.0, 1.0, 0.9)),
        ]
    else:
        knee = Vector((x, y - 0.32, top * 0.58))
        hock = Vector((x, y + 0.3, top * 0.3))
        parts = [
            (Vector((x, y + 0.05, top - 0.15)), r * 1.75, (0.82, 1.35, 1.2)),  # the thigh
            ("capsule", Vector((x, y, top - 0.15)), knee, r * 1.1),
            (knee, r * 0.95, (0.95, 1.0, 0.9)),
            ("capsule", knee, hock, r * 0.82),
            (hock, r * 0.66, (1.0, 1.0, 1.0)),
            ("capsule", hock, Vector((x, y + 0.02, foot_r * 1.1)), r * 0.58),
        ]
    parts.append((tuple(foot), foot_r, (0.98, 1.2, 0.55)))
    ob = k.fuse(parts, skin, tris=600, soft=0.24, name=name)
    if foot_rgb:
        k.zone(skin, foot_rgb, (x, y - 0.1, 0.1), (foot_r * 1.6, foot_r * 1.8, foot_r * 0.8), soft=0.5)
    return [ob, *claws_at(foot, foot_r, claw)]


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
            *c.get("torso_extra", []),
        ],
        skin,
        tris=c.get("torso_tris", 1900),
        soft=c.get("torso_soft", 0.22),
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
        **(
            {
                "leg_fl": cat_leg(skin, fx, 0, cz, lr, fr, claw, "leg_fl", True, c.get("foot_rgb")),
                "leg_fr": cat_leg(skin, -fx, 0, cz, lr, fr, claw, "leg_fr", True, c.get("foot_rgb")),
                "leg_bl": cat_leg(skin, bx, L, cz, lr, fr, claw, "leg_bl", False, c.get("foot_rgb")),
                "leg_br": cat_leg(skin, -bx, L, cz, lr, fr, claw, "leg_br", False, c.get("foot_rgb")),
            }
            if c.get("cat")
            else {
                "leg_fl": leg(skin, fx, 0, cz, lr, lr2, fr, claw, "leg_fl", c.get("foot_rgb")),
                "leg_fr": leg(skin, -fx, 0, cz, lr, lr2, fr, claw, "leg_fr", c.get("foot_rgb")),
                "leg_bl": leg(skin, bx, L, cz, lr, lr2, fr, claw, "leg_bl", c.get("foot_rgb")),
                "leg_br": leg(skin, -bx, L, cz, lr, lr2, fr, claw, "leg_br", c.get("foot_rgb")),
            }
        ),
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


# Lion ----------------------------------------------------------------------------------------------

LION = dict(chest_z=2.0, chest_r=0.96, waist_r=0.66, hip_r=0.8, len=2.15, leg_r=0.3, foot_r=0.4, head_r=0.62, neck=0.55, head_up=0.72, neck_r=0.5, snout=0.5, muzzle=1.25, ears="round", tail_len=2.1, tail_r=0.12, cat=True, torso_tris=2600, torso_soft=0.34,
            torso_extra=[*k.pair((0.5, 0.35, 2.3), 0.5, (0.65, 1.3, 1.0)), ((0, 1.1, 2.62), 0.34, (0.7, 4.0, 0.7))])  # shoulder blades, a ridge of spine
FLAME = (255, 140, 24)


def lion_head(c, hy, hz):
    """Cheek masses and a raised nose bridge, so the face is broad and square, not a ball."""
    extra = list(c.get("head_extra", []))
    extra += k.pair((0.4, hy - 0.08, hz - 0.3), 0.3, (0.75, 1.0, 0.8))
    extra.append(("capsule", (0, hy - 0.3, hz + 0.2), (0, hy - 0.85, hz - 0.02), 0.17))
    c["head_extra"] = extra


def lion_fur(c, groups, skull, hc, coat, mane=None, whisker=(236, 226, 200), seed=3):
    """The lion's small detail: whiskers, ear tufts, a fringe of chest tufts,
    a tufted tail tip and, with `mane` (two colours), locks clumped out of the ruff and a beard."""
    rng = random.Random(seed)
    R, L = c["head_r"], c["len"]
    cz, cr = c["chest_z"], c["chest_r"]
    tuft, white = k.flat(coat), k.flat(whisker)
    head, body = groups["head"], groups["body"]
    tip = hc + Vector((0, -R * 0.75 - c["snout"], -R * 0.2))
    for side in (-1, 1):
        for i in range(3):  # whiskers fanned out of the muzzle
            b = Vector((side * R * 0.3, tip.y + R * 0.55 - i * 0.04, tip.z + 0.1 - i * 0.05))
            d = Vector((side * 1.0, -0.15 - i * 0.12, 0.12 - i * 0.2)).normalized()
            head.append(k.horn([b, b + d * 0.35 + Vector((0, 0, 0.04)), b + d * 0.75 + Vector((0, 0.05, -0.1))], [0.022, 0.016, 0.0], white, n=4, steps=4, name="whisker"))
        ear = Vector((side * R * 0.72, hc.y + R * 0.3, hc.z + R * 0.72))
        head.append(k.horn([ear + Vector((0, 0, 0.1)), ear + Vector((side * 0.05, 0.04, 0.35)), ear + Vector((side * 0.1, 0.1, 0.62))], [0.07, 0.05, 0.0], tuft, n=5, steps=4, name="eartuft"))
    fx, bx = cr * 0.5, c["hip_r"] * 0.5
    for side in (-1, 1):
        for j in range(3):  # fur hanging behind each elbow and hock breaks the leg's outline
            e = Vector((side * fx, 0.2 + j * 0.03, cz - 0.7 - j * 0.12))
            groups["leg_fl" if side > 0 else "leg_fr"].append(k.horn([e, e + Vector((side * 0.04, 0.22, -0.12)), e + Vector((side * 0.06, 0.45, -0.34))], [0.1, 0.07, 0.0], tuft, n=5, steps=3, name="elbow"))
            h = Vector((side * bx, L + 0.35 + j * 0.03, cz - 1.15 - j * 0.14))
            groups["leg_bl" if side > 0 else "leg_br"].append(k.horn([h, h + Vector((side * 0.04, 0.22, -0.1)), h + Vector((side * 0.05, 0.44, -0.3))], [0.1, 0.07, 0.0], tuft, n=5, steps=3, name="hock"))
    for j in range(8):  # a fringe along the belly
        y = 0.1 + j * 0.28
        for side in (-1, 1):
            b = Vector((side * (0.42 - abs(j - 3.5) * 0.03), y, cz - 0.62 + abs(j - 3.5) * 0.05))
            body.append(k.horn([b, b + Vector((side * 0.02, 0.06, -0.18)), b + Vector((side * 0.03, 0.14, -0.38))], [0.09, 0.07, 0.0], tuft, n=5, steps=3, name="belly"))
    for j in range(9):
        x = (j - 4) * 0.13
        b = Vector((x, -cr * 0.74 - 0.06, cz + 0.38 - abs(j - 4) * 0.08))
        body.append(k.horn([b, b + Vector((x * 0.15, -0.08, -0.3)), b + Vector((x * 0.3, -0.04, -0.62 - rng.uniform(0, 0.15)))], [0.12, 0.09, 0.0], tuft, n=5, steps=4, name="chest"))
    t = Vector(c["tail_tip"])
    for i in range(6):  # the tail's tuft, as locks
        a = i / 6 * math.tau
        d = Vector((math.cos(a) * 0.3, 0.12 + rng.uniform(0, 0.1), -0.55 + math.sin(a) * 0.15))
        groups["tail"].append(k.horn([t, t + d * 0.5, t + d * 1.1], [0.1, 0.1, 0.0], tuft, n=5, steps=4, name="lock"))
    if mane:  # two tones of locks, clumped out of the ruff: a full ring, then a beard under the chin
        tones = [k.flat(mane[0]), k.flat(mane[1])]
        for i in range(24):
            a = i / 24 * math.tau + rng.uniform(-0.08, 0.08)
            r = rng.uniform(0.85, 1.05)
            base = hc + Vector((math.cos(a) * r, 0.4, math.sin(a) * r))
            d = Vector((math.cos(a) * 0.85, 0.5, math.sin(a) * 0.6 - 0.35)).normalized()
            n = rng.uniform(0.5, 0.85)
            head.append(k.horn([base - d * 0.25, base + d * n * 0.5 + Vector((0, 0, -0.06)), base + d * n + Vector((0, 0.05, -0.18))], [0.2, 0.17, 0.0], tones[i % 2], n=6, steps=5, name="lock"))
        for i in range(6):
            x = (i - 2.5) * 0.19
            base = hc + Vector((x, -0.3, -0.72 - abs(i - 2.5) * 0.05))
            head.append(k.horn([base, base + Vector((x * 0.3, 0.12, -0.28)), base + Vector((x * 0.55, 0.3, -0.52 - rng.uniform(0, 0.12)))], [0.17, 0.14, 0.0], tones[i % 2], n=6, steps=5, name="beard"))
    # Flat-coloured hair needs only a few texels: without this every lock and tuft takes an island of
    # the one atlas and the body's texture shrinks to mush.
    hair = ("whisker", "eartuft", "elbow", "hock", "belly", "chest", "lock", "beard")
    for part in groups.values():
        k.texel([ob for ob in part if ob.name.startswith(hair)], 0.2)


def lion_coat(c, hy, hz, belly, spine, hi, bridge, spots, paw):
    """Fur markings painted on the fused bodies: a pale belly and chest, a darker spine, lighter
    shoulders and haunches that read as muscle, a dark nose bridge and whisker spots."""
    m = c["skin"]
    k.zone(m, belly, (0, 1.0, 1.3), (0.75, 1.9, 0.6), soft=0.5, jag=0.12, jag_scale=9)
    k.zone(m, belly, (0, -0.55, 1.75), (0.6, 0.65, 0.65), soft=0.5, jag=0.12, jag_scale=9)
    k.zone(m, spine, (0, 1.0, 2.95), (0.32, 2.1, 0.3), soft=0.6, jag=0.15, jag_scale=8)
    for side in (-1, 1):
        k.zone(m, hi, (side * 0.62, 0.3, 2.4), (0.35, 0.8, 0.6), soft=0.5, jag=0.1, jag_scale=8)  # shoulder
        k.zone(m, hi, (side * 0.6, 2.05, 2.25), (0.4, 0.75, 0.65), soft=0.5, jag=0.1, jag_scale=8)  # haunch
        for i, (dy, dz) in enumerate(((0.62, 0.02), (0.7, -0.07), (0.78, -0.16), (0.6, -0.12))):  # whisker spots
            k.zone(m, spots, (side * (0.15 + i * 0.03), hy - dy, hz + dz - 0.1), (0.04, 0.04, 0.04), soft=0.3)
    k.zone(m, bridge, (0, hy - 0.62, hz + 0.04), (0.13, 0.5, 0.14), soft=0.6)
    c["foot_rgb"] = paw


def lion(variant=False):
    c = dict(LION)
    hy, hz = -0.96 * 0.72 - 0.55, 2.0 + 0.96 * 0.42 + 0.72  # the head's middle
    if not variant:  # the mane: a ruff of big locks behind the face, part of the head
        c["head_extra"] = [((math.cos(a) * 0.72, hy + 0.5, hz - 0.1 + math.sin(a) * 0.72), 0.5, (1.0, 1.15, 1.0)) for a in [i / 9 * math.tau for i in range(9)]] + [((0, hy + 0.85, hz - 0.2), 0.95, (1.0, 0.9, 1.05))]
        c["skin"] = k.paint("li_tawny", [(0, (150, 110, 62)), (0.5, (196, 152, 86)), (1, (182, 140, 82))], 0, 3.8, rest=True, grain=(0.18, 15))
        c.update(iris=(240, 176, 36), socket=(70, 48, 30))
        lion_coat(c, hy, hz, (232, 206, 158), (140, 100, 54), (216, 172, 102), (122, 86, 52), (74, 48, 30), (112, 82, 50))
    else:  # Sun Lion: pale gold, a mane of flames, burning eyes and tail
        c["skin"] = k.paint("li_sun", [(0, (206, 160, 92)), (1, (246, 218, 150))], 0, 3.8, rest=True, grain=(0.12, 15))
        c.update(iris=FLAME, socket=(120, 80, 40), glow_eyes=True, claw=(255, 170, 60))
        lion_coat(c, hy, hz, (240, 216, 160), (214, 164, 90), (252, 232, 176), (190, 146, 92), (140, 94, 52), (206, 160, 92))
    lion_head(c, hy, hz)
    groups, torso, skull, hc = predator(c)
    if variant:
        rng, glow = random.Random(5), k.glow(FLAME)
        flames = []
        for ring_r, n, long in ((0.62, 11, 1.25), (0.5, 8, 0.85)):
            for i in range(n):
                a = i / n * math.tau + rng.uniform(-0.15, 0.15)
                d = Vector((math.cos(a), 0.55, math.sin(a) * 1.05)).normalized()
                base = hc + Vector((math.cos(a) * ring_r, 0.42, math.sin(a) * ring_r))
                flames.append(shard(base - d * 0.2, base + d * long * rng.uniform(0.75, 1.15), 0.2, glow))
        for i in range(8):  # licks of flame along the spine and haunches, shorter towards the tail
            base = Vector((rng.uniform(-0.1, 0.1), 0.45 + i * 0.26, c["chest_z"] + 0.8 - i * 0.03))
            flames.append(shard(base, base + Vector((0, 0.3, 0.7 - i * 0.05)), 0.14, glow))
        groups["head_glow"] += flames
        tip = c["tail_tip"]
        groups["tail_glow"] = [k.horn([tip, tip + Vector((0, 0.1, -0.3)), tip + Vector((0, 0.3, -0.85))], [0.1, 0.27, 0.0], glow, n=10, steps=8, name="flame")]
    else:
        k.zone(c["skin"], (92, 58, 34), (0, hy + 0.75, hz - 0.15), (1.5, 0.95, 1.6), soft=0.25, jag=0.15)  # the mane is darker
        k.zone(c["skin"], (236, 218, 180), (0, hy - 0.75, hz - 0.35), (0.42, 0.5, 0.36), soft=0.4)  # pale muzzle
        groups["tail"].append(k.blob(0.26, tuple(c["tail_tip"]), k.flat((70, 44, 28)), scale=(0.9, 0.9, 1.5), name="tuft"))
    lion_fur(c, groups, skull, hc, (176, 136, 80) if not variant else (232, 206, 150), None if variant else ((74, 46, 28), (130, 92, 52)))
    return groups, c["joints"]


SHADOW = (170, 90, 255)


def shadow_lion(variant=True):
    """Shadow Lion (legendary): a coal-black lion, the mane a swept-back ruff of black locks with violet
    shards raking back from it and down the spine, violet eyes, claws and tail-tip."""
    c = dict(LION)
    hy, hz = -0.96 * 0.72 - 0.55, 2.0 + 0.96 * 0.42 + 0.72
    c["head_extra"] = [((math.cos(a) * 0.72, hy + 0.5, hz - 0.1 + math.sin(a) * 0.72), 0.5, (1.0, 1.15, 1.0)) for a in [i / 9 * math.tau for i in range(9)]] + [((0, hy + 0.85, hz - 0.2), 0.95, (1.0, 0.9, 1.05))]
    c["skin"] = k.paint("li_shadow", [(0, (18, 16, 26)), (0.6, (40, 36, 56)), (1, (60, 52, 82))], 0, 3.8, rest=True, grain=(0.16, 15))
    c.update(iris=SHADOW, socket=(8, 6, 14), glow_eyes=True, claw=(190, 130, 255))
    lion_coat(c, hy, hz, (30, 26, 46), (10, 8, 18), (78, 62, 112), (12, 10, 20), (150, 110, 230), (10, 8, 16))
    lion_head(c, hy, hz)
    groups, torso, skull, hc = predator(c)
    k.zone(c["skin"], (92, 66, 140), (0, hy + 0.75, hz - 0.15), (1.5, 0.95, 1.6), soft=0.3, jag=0.2)  # the mane glints violet
    rng, glow = random.Random(11), k.glow(SHADOW)
    shards = []
    for i in range(12):  # a crest raked back from the mane, longest at the top
        a = i / 12 * math.tau + rng.uniform(-0.12, 0.12)
        top = max(0.0, math.sin(a)) * 0.9
        d = Vector((math.cos(a) * 0.5, 1.0, 0.3 + math.sin(a) * 0.7)).normalized()
        base = hc + Vector((math.cos(a) * 0.62, 0.5, 0.15 + math.sin(a) * 0.62))
        shards.append(shard(base, base + d * (0.9 + top + rng.uniform(0, 0.3)), 0.17, glow))
    for i in range(7):  # and down the spine, shorter towards the tail
        y = 0.55 + i * 0.3
        base = Vector((0, y, c["chest_z"] + 0.78 - i * 0.02))
        shards.append(shard(base, base + Vector((0, 0.35, 0.78 - i * 0.07)), 0.14, glow))
    groups["head_glow"] += shards
    tip = c["tail_tip"]
    groups["tail_glow"] = [k.horn([tip, tip + Vector((0, 0.1, -0.3)), tip + Vector((0, 0.3, -0.85))], [0.1, 0.27, 0.0], glow, n=10, steps=8, name="flame")]
    lion_fur(c, groups, skull, hc, (44, 38, 62), ((34, 28, 54), (84, 56, 130)), whisker=(190, 150, 255), seed=7)
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


# Elephant (the Titan) ------------------------------------------------------------------------------

ICE = (120, 220, 255)


def elephant(variant=False):
    """The Titan: a war elephant with wide ears, a heavy brow, a long trunk and long tusks.
    Variant: the Frost Mammoth, shaggy and pale with huge glowing ice tusks and ice down its back."""
    if variant:
        skin = k.paint("el_frost", [(0, (120, 140, 170)), (0.5, (190, 208, 230)), (1, (236, 244, 252))], 0, 4.8, rest=True, grain=(0.2, 6))
        iris, socket, fold = ICE, (60, 76, 104), (90, 108, 140)
        tusk_m, grow = k.glow(ICE), 1.3
    else:
        skin = k.paint("el_grey", [(0, (70, 66, 68)), (0.5, (112, 110, 116)), (1, (146, 146, 152))], 0, 4.8, rest=True, grain=(0.16, 7))
        iris, socket, fold = (236, 160, 36), (40, 38, 44), (44, 42, 48)
        tusk_m, grow = k.paint("el_tusk", [(0, (150, 132, 100)), (1, (244, 236, 214))], 2.2, 3.4, rest=True), 1.0
    torso = k.fuse(
        [
            ((0, -0.5, 3.0), 1.35, (1.0, 1.05, 1.1)),
            ((0, -0.4, 3.95), 0.8, (0.8, 1.2, 0.7)),  # the hump over the shoulders
            ((0, 0.75, 2.9), 1.3, (1.0, 1.3, 1.02)),
            ((0, 1.95, 2.85), 1.2, (1.0, 0.95, 1.0)),
            *k.pair((0.95, -0.5, 3.0), 0.8, (0.5, 1.0, 1.15)),
            *k.pair((0.9, 1.9, 2.8), 0.76, (0.5, 0.95, 1.1)),
            *([((0, y, 3.75), 0.75, (0.9, 0.7, 0.6)) for y in (0.4, 1.2, 2.0)] if variant else []),  # shaggy back
        ],
        skin,
        tris=2600,
        soft=0.24,
        name="torso",
    )
    for y in (-1.7, 0.2, 1.3):
        k.zone(skin, fold, (0, y, 3.0), (1.9, 0.07, 1.9), soft=0.8)
    hc, R = Vector((0, -2.05, 3.55)), 0.95
    skull = k.fuse(
        [
            (tuple(hc), R, (0.95, 1.05, 1.05)),
            ((0, -1.3, 3.3), 1.0, (0.95, 1.0, 0.95)),  # neck, hidden in the body
            ((0, -2.15, 4.3), 0.62, (0.95, 0.9, 0.7)),  # domed forehead
            ("capsule", (0, -2.7, 3.2), (0, -3.2, 2.35), 0.44),  # the trunk, in three bends
            ("capsule", (0, -3.2, 2.35), (0, -3.3, 1.45), 0.36),
            ("capsule", (0, -3.3, 1.45), (0, -2.95, 0.72), 0.27),
            *k.pair((0.5, -2.75, 3.05), 0.42, (0.8, 1.0, 0.9)),  # tusk roots
            *k.pair((0.46, -2.55, 4.05), 0.34, (0.9, 1.5, 0.5), (20, 0, 0)),  # brow
            *k.pair((1.3, -1.7, 3.75), 1.0, (0.16, 0.78, 1.18), (0, 14, 20)),  # ears
        ],
        skin,
        tris=3200,
        soft=0.22,
        name="skull",
    )
    face, glows = eyes(skull, skin, hc, 50, 12, 0.11, iris, socket, variant)
    k.texel(face, k.FACE_TEXEL)
    tusks = []
    for side in (-1, 1):
        pts = [(side * 0.5, -2.75, 2.95), (side * 0.66, -3.45, 2.3), (side * 0.72, -4.1 * (1 + (grow - 1) * 0.3), 2.4), (side * 0.6, -4.5 * (1 + (grow - 1) * 0.3), 3.0 * grow)]
        tusks.append(k.horn(pts, [0.23 * grow, 0.2 * grow, 0.12, 0.0], tusk_m, name="tusk"))
    k.rest(tusks)
    claw = k.flat((190, 180, 160))
    tail = k.rest(k.horn([(0, 3.0, 3.3), (0, 3.4, 3.0), (0, 3.55, 2.3), (0, 3.5, 1.8)], [0.17, 0.12, 0.09, 0.085], skin, n=8, steps=8, name="tail"))
    tuft = k.blob(0.22, (0, 3.5, 1.62), k.flat((30, 28, 34)), scale=(0.85, 0.85, 1.5), name="tuft")
    groups = {
        "body": [torso],
        "head": [skull, *face] + ([] if variant else tusks),
        "leg_fl": leg(skin, 0.82, -0.5, 2.4, 0.52, 0.47, 0.56, claw, "leg_fl", fold, toes=4),
        "leg_fr": leg(skin, -0.82, -0.5, 2.4, 0.52, 0.47, 0.56, claw, "leg_fr", fold, toes=4),
        "leg_bl": leg(skin, 0.82, 1.85, 2.4, 0.52, 0.47, 0.56, claw, "leg_bl", fold, toes=4),
        "leg_br": leg(skin, -0.82, 1.85, 2.4, 0.52, 0.47, 0.56, claw, "leg_br", fold, toes=4),
        "tail": [tail, tuft],
    }
    if variant:
        rng, glow = random.Random(9), k.glow(ICE)
        ice = []
        for i, h in enumerate((0.9, 1.3, 1.1, 0.9, 0.7, 0.5)):
            y = -0.9 + 0.62 * i
            p, _ = k.land(torso, (0, y, 3.0), (rng.uniform(-0.1, 0.1), 0, 1))
            lean = Vector((rng.uniform(-0.12, 0.12), 0.35, 1)).normalized()
            ice.append(shard(p - lean * 0.25, p + lean * h, 0.14 + h * 0.18, glow))
        groups["body_glow"] = ice
        groups["head_glow"] = tusks + glows
    joints = {"head": (0, -1.3, 3.4), "leg_fl": (0.82, -0.5, 2.3), "leg_fr": (-0.82, -0.5, 2.3), "leg_bl": (0.82, 1.85, 2.3), "leg_br": (-0.82, 1.85, 2.3), "tail": (0, 3.0, 3.3)}
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
    asset("creature_lion", lion, False, 1.7, {}, "Lion: heavy, maned.", 12500),
    asset("creature_lion_sun", lion, True, 2.1, {"head_glow": FLAME, "tail_glow": FLAME}, "Sun Lion (mythic): a mane and tail of Neon flame.", 12500),
    asset("creature_lion_shadow", shadow_lion, True, 1.9, {"head_glow": SHADOW, "tail_glow": SHADOW}, "Shadow Lion (legendary): coal black, violet shards raked back from the mane and down the spine.", 12500),
    asset("creature_meerkat", meerkat, False, 1.0, {}, "Meerkat: small and quick."),
    asset("creature_meerkat_storm", meerkat, True, 1.25, {"head_glow": STORM, "body_glow": STORM, "tail_glow": STORM}, "Storm Meerkat (legendary): Neon bands and tail charge."),
    asset("creature_tortoise", tortoise, False, 1.6, {}, "Tortoise: plated shell with a spiked rim."),
    asset("creature_tortoise_gemshell", tortoise, True, 2.0, {"head_glow": GEM, "body_glow": GEM}, "Gemshell Tortoise (legendary): a Neon crystal on every plate.", 12500),
    asset("creature_flamingo", flamingo, False, 1.3, {}, "Flamingo: two legs; its wings are the back-leg pieces.", 9000),
    asset("creature_flamingo_phoenix", flamingo, True, 1.6, {"head_glow": EMBER, "tail_glow": EMBER, "leg_bl_glow": EMBER, "leg_br_glow": EMBER}, "Phoenix Flamingo (mythic): Neon crest, wing tips and tail.", 10000),
    asset("creature_elephant", elephant, False, 3.0, {}, "Elephant, the Titan.", 14000),
    asset("creature_elephant_frost", elephant, True, 3.5, {"head_glow": ICE, "body_glow": ICE}, "Frost Mammoth (mythic Titan): Neon ice tusks and back spikes.", 15000),
]
