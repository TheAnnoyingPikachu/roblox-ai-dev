"""The rhinos (decision 0054), after the lions, elephants, jackals and cheetahs: the Rhino, the Lava
Rhino and the Crystal Rhino. SHANNON's note with the cheetahs' go-ahead: the models need not be
low-poly, only not very detailed, so this family is rounder: a massive barrel of twelve-sided
sections with a high shoulder hump, round pillar legs, a long low head with a scimitar horn, and two
raised plates of armour (shoulders and rump) with a fold of bare hide between them. The colours are
still one flat tone a face.

Jointed like every creature: body, head, four legs, tail, and Neon `_glow` pieces. Facing Blender -Y;
left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Matrix, Vector

loft, oval, round_z, quad, shard, plate, tone, rough = F.loft, F.oval, F.round_z, F.quad, F.shard, F.plate, F.tone, F.rough

SLATE = ((0.78, 0.78, 0.82), (1.1, 1.1, 1.12), (6, 6, 10))
VIVID = ((0.8, 0.74, 0.9), (1.12, 1.1, 1.04), (10, 8, 4))  # crystal: shadows stay violet
LAVA = (255, 84, 12)
AMETHYST = (176, 110, 255)
HIND = 1.9  # how far behind the front legs the hind legs stand
FADE = 2.6  # the hide darkens below this height
DROP = 0.35  # the body, head and tail are written for long legs and lowered by this: a rhino is slung low
# the barrel's sections: (depth, middle height, half width, up, down)
BARREL = ((-1.55, 2.45, 0.8, 0.85, 0.8), (-0.7, 2.45, 1.2, 1.3, 1.05), (0.6, 2.35, 1.25, 1.05, 1.1), (1.9, 2.35, 1.2, 1.05, 1.0), (2.7, 2.3, 0.9, 0.85, 0.8), (3.0, 2.25, 0.5, 0.5, 0.45))


def girth(y):
    """The barrel's section at depth y, between its rings: (middle height, half width, up, down)."""
    for a, b in zip(BARREL, BARREL[1:]):
        if a[0] <= y <= b[0]:
            u = (y - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * u for i in range(1, 5))
    raise ValueError(f"no barrel at y = {y}")


def armour(ys, thick, low=0.35):
    """The sections of a plate of armour over the barrel at the depths `ys`: `thick` proud of the hide
    over the back and down the flanks, its lower edge `low` under the barrel's middle."""
    rings = []
    for y in ys:
        zc, w, up, _ = girth(y)
        rings.append(oval(y, zc - low, w + thick, up + low + thick, 0.3))
    return rings


def rhino_model(p, seed):
    """The rhino from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", SLATE)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    hide_t, plate_t, legs_t = T("hide"), T("plate"), T("legs")
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "head_glow": [], "body_glow": [], "tail": [], "tail_glow": []}

    def hide(ob, tones, bulge=0.03):
        return rough(ob, tones, rng, bulge, FADE)

    def horn(points, radii, name):
        """A curved horn: of bone, or glowing."""
        if p.get("horn") == "glow":
            groups["head_glow"].append(k.horn(points, radii, glow, n=p.get("horn_sides", 8), steps=8, name=name))
        else:
            groups["head"].append(F.colour(k.horn(points, radii, F.material(), n=8, steps=8, name=name), tone(p["horn"], F.PALE), rng))

    # the body: the barrel, and a plate of armour over the shoulders and another over the rump
    torso = hide(loft("torso", [oval(y, zc, w, up, down) for y, zc, w, up, down in BARREL], hide_t, rng), hide_t)
    shoulder = hide(loft("shoulder", armour((-1.3, -0.7, 0.1), 0.07), plate_t, rng), plate_t, 0.02)
    rump = hide(loft("rump", armour((0.45, 1.2, 1.9, 2.65), 0.07), plate_t, rng), plate_t, 0.02)
    groups["body"] += [torso, shoulder, rump]

    # legs: round pillars, a flared foot with three pale nails
    for s in (1, -1):
        for front in (True, False):
            x, y = s * 0.72, (-0.6 if front else HIND)
            top = (0.52, 0.62) if front else (0.56, 0.74)
            parts = [
                hide(loft("leg", [round_z(x, y, 2.0 - DROP, *top), round_z(x, y, 0.85, 0.46, 0.52)], hide_t, rng), hide_t, 0.02),
                hide(loft("shank", [round_z(x, y, 0.9, 0.44, 0.5), round_z(x, y, 0.3, 0.45, 0.5), round_z(x, y - 0.03, 0.0, 0.55, 0.62)], legs_t, rng), legs_t, 0.02),
            ]
            for dx in (-0.3, 0.0, 0.3):
                parts.append(loft("nail", [quad(y - 0.56, 0.14, 0.12, 0.12, 0.14, x + dx), quad(y - 0.7, 0.11, 0.1, 0.07, 0.11, x + dx)], T("nail"), rng))
            groups[("leg_f" if front else "leg_b") + ("l" if s > 0 else "r")] = parts

    # the head: long and carried low, a hooked lip, small ears, a scimitar of a horn and a short one behind it
    skull = hide(loft("skull", [oval(*r) for r in ((-1.3, 2.5, 0.64, 0.64, 0.62), (-2.2, 2.3, 0.56, 0.56, 0.54), (-3.0, 2.05, 0.47, 0.43, 0.43), (-3.7, 1.9, 0.43, 0.37, 0.37), (-3.98, 1.8, 0.32, 0.27, 0.24), (-4.14, 1.7, 0.16, 0.12, 0.14))], hide_t, rng), hide_t, 0.02)
    head = groups["head"]
    head.append(skull)
    horn([(0, -3.55, 2.15), (0, -3.8, 2.8), (0, -3.62, 3.4), (0, -3.25, 3.85)], [0.3, 0.22, 0.12, 0.0], "horn")
    dark = tone(p["dark"], kind)
    for s in (1, -1):
        nose, n = k.land(skull, (s * 0.2, -3.86, 1.9), (s * 0.5, -1, 0.6))
        head.append(plate("nostril", nose, k._frame(n), [(-0.07, -0.04), (0.07, -0.04), (0.09, 0.03), (-0.05, 0.05)], 0.012, dark, rng, lift=0.025))
        a, n = k.land(skull, (0, -3.85, 1.68), (s, -0.2, -0.3))
        b, _ = k.land(skull, (0, -3.1, 1.76), (s, 0, -0.3))
        head.append(shard(a + n * 0.02, b + n * 0.02, 0.07, 0.04, dark, rng, face=n, name="mouth"))
    horn([(0, -2.95, 2.4), (0, -3.02, 2.9), (0, -2.88, 3.25)], [0.2, 0.12, 0.0], "horn")
    for s in (1, -1):
        head.append(shard((s * 0.42, -1.75, 2.9), (s * 0.66, -1.62, 3.5), 0.34, 0.2, hide_t, rng, at=0.45, name="ear"))
        head.append(shard((s * 0.1, -2.5, 2.74), (s * 0.56, -2.2, 2.9), 0.2, 0.16, plate_t, rng, face=(0, -1, 0.5), name="brow"))
        at, n = k.land(skull, (s * 0.4, -2.35, 2.5), (s * 0.85, -0.5, 0.2))
        ex, ey, ez = k._frame(n)
        slit = [(-0.13, -0.045), (0.01, 0.055), (0.16, 0.05), (0.05, -0.04)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.03, None, rng, lift=0.025, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.025, tone(p["iris"], F.WARM), rng, lift=0.025))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.03), (0.035, 0.0), (0.03, 0.045), (-0.004, 0.015)], 0.012, tone(F.INK), rng, lift=0.052))

    # the tail: short and thin, with a tuft
    t0, end = Vector((0, 2.95, 2.7)), Vector((0, 3.45, 1.55))
    tail = k.tube([t0, Vector((0, 3.35, 2.3)), end], [0.13, 0.1, 0.08], m=F.material(), n=6, name="tail")
    groups["tail"].append(F.colour(tail, hide_t, rng))
    if p.get("tuft") == "flame":
        for i in range(5):
            d = Vector(((i - 2) * 0.22, 0.35 + 0.1 * (i % 2), 0.9 - 0.15 * abs(i - 2))).normalized()
            groups["tail_glow"].append(shard(end - d * 0.1, end + d * (0.9 - 0.1 * abs(i - 2)), 0.3, 0.2, None, rng, face=(0, 1, 0), at=0.35, m=glow, name="flame"))
    else:
        for i in range(3):
            d = Vector(((i - 1) * 0.35, 0.15, -1)).normalized()
            groups["tail"].append(shard(end - d * 0.1, end + d * 0.6, 0.26, 0.18, T("tuft"), rng, face=(0, 1, 0), at=0.4, name="tuft"))

    extra = p.get("extra")
    if extra:
        extra(groups, {"torso": torso, "shoulder": shoulder, "rump": rump, "skull": skull}, rng, glow)
    for name, parts in groups.items():  # slung low on its short legs
        if not name.startswith("leg"):
            for ob in parts:
                ob.data.transform(Matrix.Translation((0, 0, -DROP)))
    joints = {"head": (0, -1.4, 2.5 - DROP), "leg_fl": (0.72, -0.6, 1.9 - DROP), "leg_fr": (-0.72, -0.6, 1.9 - DROP), "leg_bl": (0.72, HIND, 1.9 - DROP), "leg_br": (-0.72, HIND, 1.9 - DROP), "tail": (0, t0.y, t0.z - DROP)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def crack(target, into, points, s, rng, glow, width=0.14, tones=None):
    """A jagged line across a plate, following its curve: shards end to end through `points` (depth,
    height). Glowing (a crack of lava), or painted in `tones` (a scar)."""
    landed = []
    for y, z in points:
        at, n = k.land(target, (0, y, z), (s, 0, 0.3))
        landed.append(at + n * 0.03)
    for a, b in zip(landed, landed[1:]):
        into.append(shard(a, b, width, 0.06, tones, rng, face=(s, 0, 0.3), m=None if tones else glow, name="crack"))


def war_extra(groups, pieces, rng, glow):
    """Bone studs on the shoulder plate and three claw scars across the rump."""
    bone = tone((226, 214, 186), F.PALE)
    for s in (1, -1):
        for row, tilt in enumerate((0.25, 0.75)):
            for i in range(3):
                at, n = k.land(pieces["shoulder"], (0, -1.05 + i * 0.42 + row * 0.2, 2.6), (s * tilt, 0, 1 - tilt * 0.6))
                groups["body"].append(shard(at - n * 0.06, at + n * 0.3, 0.26, 0.26, bone, rng, at=0.3, name="stud"))
    for i in range(3):  # on its right flank
        crack(pieces["rump"], groups["body"], [(1.15 + i * 0.3 + j * 0.2, 3.0 - j * 0.27) for j in range(4)], -1, rng, glow, 0.13, tone((214, 190, 180), F.PALE))


def rhino():
    """Rhino: a war rhino in slate, armour plates with bone studs, a bone scimitar horn, claw scars."""
    return rhino_model(
        dict(hide=(108, 116, 132), plate=(88, 96, 114), legs=(124, 132, 148), nail=(226, 214, 186), horn=(232, 222, 196), iris=(240, 176, 40), tuft=(40, 42, 52), dark=(46, 50, 62), extra=war_extra),
        5,
    )


def band(y, proud, name, tones, rng, m=None):
    """A narrow ring round the barrel at depth y, `proud` of the hide (a seam of lava in a fold)."""
    rings = []
    for dy in (-0.06, 0.06):
        zc, w, up, down = girth(y + dy)
        rings.append(oval(y + dy, zc, w + proud, up + proud, down + proud))
    return F.mesh(name, [q for ring in rings for q in ring], [(i, (i + 1) % 12, 12 + (i + 1) % 12, 12 + i) for i in range(12)] + [tuple(range(12))[::-1], tuple(range(12, 24))], tones, rng, m=m)


def lava_extra(groups, pieces, rng, glow):
    """Lava in the folds between the plates and in cracks across them, rock spikes down the back, a crown
    of two rock horns."""
    rock = tone((58, 46, 44), SLATE)
    for y in (-1.42, 0.27, 2.82):
        groups["body_glow"].append(band(y, 0.03, "seam", None, rng, m=glow))
    for s in (1, -1):
        crack(pieces["shoulder"], groups["body_glow"], ((-1.1, 3.3), (-0.8, 2.95), (-0.95, 2.65), (-0.55, 2.35), (-0.7, 2.1)), s, rng, glow)
        crack(pieces["shoulder"], groups["body_glow"], ((-0.3, 3.2), (-0.1, 2.85), (-0.3, 2.55)), s, rng, glow, 0.11)
        crack(pieces["rump"], groups["body_glow"], ((0.8, 3.1), (1.1, 2.8), (0.95, 2.5), (1.35, 2.2)), s, rng, glow)
        crack(pieces["rump"], groups["body_glow"], ((1.9, 3.1), (2.15, 2.75), (2.0, 2.45), (2.3, 2.15)), s, rng, glow, 0.11)
        groups["head"].append(shard((s * 0.4, -2.3, 2.75), (s * 0.72, -1.7, 3.5), 0.3, 0.26, rock, rng, at=0.3, name="crown"))
    for i, h in enumerate((0.7, 1.0, 0.85, 0.6, 0.8, 0.95, 0.7, 0.5)):
        y = -1.1 + i * 0.5
        piece = pieces["shoulder"] if y < 0.1 else pieces["rump"] if y > 0.45 else pieces["torso"]
        at, _ = k.land(piece, (0, y, 2.5), (0, 0, 1))
        lean = Vector((rng.uniform(-0.12, 0.12), 0.35, 1)).normalized()
        groups["body"].append(shard(at - lean * 0.15, at + lean * h, 0.5, 0.42, rock, rng, face=(1, 0, 0), at=0.3, name="spike"))


def lava_rhino():
    """Lava Rhino (mythic): obsidian plates split by glowing cracks, lava in the folds between them, molten
    horns, rock spikes down the back, a burning tail, glowing eyes."""
    return rhino_model(
        dict(hide=(64, 40, 36), plate=(40, 34, 38), legs=(52, 40, 40), nail=(255, 150, 60), horn="glow", glow=LAVA, glow_eyes=True, tuft="flame", dark=(20, 16, 18), extra=lava_extra),
        9,
    )


def cluster(target, into, hearts, centre, direction, sizes, rng, glow):
    """A cluster of crystals growing out of `target`: shards fanned round the surface's normal, pale at the
    tips; the tallest has a glowing heart."""
    at, n = k.land(target, centre, direction)
    side = n.cross(Vector((0, 1, 0)))
    side = (side if side.length > 1e-3 else Vector((1, 0, 0))).normalized()
    fore = n.cross(side).normalized()
    deep, light = tone((104, 54, 196), VIVID), tone((190, 140, 255), VIVID)
    for i, size in enumerate(sizes):
        a = i * math.tau / max(1, len(sizes) - 1)
        d = n if i == 0 else (n + (side * math.cos(a) + fore * math.sin(a)) * rng.uniform(0.45, 0.75)).normalized()
        base = at + (d - n) * 0.25
        into.append(shard(base - d * 0.12, base + d * size, size * 0.42, size * 0.36, (deep, light), rng, face=side, at=0.3, name="crystal"))
        if i == 0:
            hearts.append(shard(base, base + d * size * 0.7, size * 0.2, size * 0.2, None, rng, face=side, at=0.35, m=glow, name="crystal"))


def crystal_extra(groups, pieces, rng, glow):
    """Crystals growing through the armour: a great cluster on the shoulder hump and one on the rump,
    smaller ones on each shoulder and haunch and along the spine, and one for a tail tuft."""
    body, hearts = groups["body"], groups["body_glow"]
    cluster(pieces["shoulder"], body, hearts, (0, -0.65, 2.6), (0, 0, 1), (1.7, 1.1, 0.95, 1.15, 0.85, 1.0), rng, glow)
    cluster(pieces["rump"], body, hearts, (0, 1.75, 2.6), (0, 0, 1), (1.3, 0.85, 0.95, 0.75, 0.9), rng, glow)
    cluster(pieces["rump"], body, hearts, (0, 0.95, 2.6), (0, 0, 1), (0.8, 0.55, 0.6), rng, glow)
    for s in (1, -1):
        cluster(pieces["shoulder"], body, hearts, (0, -0.45, 2.95), (s, 0, 0.45), (1.0, 0.65, 0.7, 0.55), rng, glow)
        cluster(pieces["rump"], body, hearts, (0, 1.85, 2.8), (s, 0, 0.4), (0.85, 0.55, 0.6), rng, glow)
        groups["head"].append(shard((s * 0.36, -2.25, 2.78), (s * 0.6, -1.9, 3.35), 0.26, 0.24, (tone((104, 54, 196), VIVID), tone((190, 140, 255), VIVID)), rng, at=0.3, name="crystal"))


def crystal_rhino():
    """Crystal Rhino (legendary): a dark stone hide with clusters of amethyst growing through its armour,
    horns of glowing crystal, glowing violet eyes."""
    return rhino_model(
        dict(hide=(74, 70, 98), plate=(58, 56, 82), legs=(88, 84, 114), nail=(214, 180, 255), horn="glow", horn_sides=5, glow=AMETHYST, glow_eyes=True, tuft=(150, 96, 230), dark=(30, 28, 44), extra=crystal_extra),
        13,
    )


ASSETS = [
    F.asset("creature_rhino", rhino, 1.8, {}, "Rhino: a massive slate war rhino, armour plates with bone studs, a scimitar horn."),
    F.asset("creature_rhino_lava", lava_rhino, 2.31, {"head_glow": LAVA, "body_glow": LAVA, "tail_glow": LAVA}, "Lava Rhino (mythic): obsidian plates, Neon lava in the folds and cracks, molten horns, a burning tail."),
    F.asset("creature_rhino_crystal", crystal_rhino, 2.07, {"head_glow": AMETHYST, "body_glow": AMETHYST}, "Crystal Rhino (legendary): dark stone, clusters of amethyst through the armour, Neon crystal horns."),
]
