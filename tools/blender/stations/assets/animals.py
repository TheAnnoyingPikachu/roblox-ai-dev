"""Helpers of the first Animal Stations models (decision 0037), on the smooth body kit: `shard`, `ring`,
`leg`, `eyes` and the four-legged `predator` body. The enemies (foes.py) are still built on them. The
animals themselves have all moved to the faceted kit (lions.py, elephants.py, jackals.py, cheetahs.py,
rhinos.py, meerkats.py, tortoises.py, flamingos.py), so this file builds nothing of its own.
"""

import math
import random

import kit as k
from mathutils import Vector

INK = (16, 13, 18)
BONE = (214, 200, 172)


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


ASSETS = []
