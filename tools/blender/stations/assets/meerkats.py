"""The meerkats (decision 0055), in the build of the rhinos (flat face tones under a surface texture): the
Meerkat, the Storm Meerkat and the Star Meerkat. A meerkat stands upright, a sentinel: a pear of a body
with a pale belly, short haunches over long feet, thin arms held at the chest, a pointed face with dark
eye patches, dark bands across the back, a long thin tail propped on the ground behind it.

Jointed like every creature, with the names the clips know: its arms are the "front legs" (leg_fl,
leg_fr) and the legs it stands on are the "back legs" (leg_bl, leg_br). Facing Blender -Y; left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Vector

loft, oval, round_z, yring, shard, plate, tone, rough = F.loft, F.oval, F.round_z, F.yring, F.shard, F.plate, F.tone, F.rough

NIGHT = ((0.62, 0.58, 0.8), (1.25, 1.2, 1.3), (14, 10, 26))  # a dark coat whose lights turn violet
STORM = (60, 210, 255)
STAR = (255, 206, 70)
PARTS = ("body", "head", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br")
# level sections as (height, depth, half width, half depth): the body, and the pale belly proud of its front
SPINE = ((0.5, 0.22, 0.32, 0.28), (0.85, 0.2, 0.52, 0.46), (1.3, 0.12, 0.55, 0.47), (1.8, 0.02, 0.46, 0.4), (2.2, -0.05, 0.4, 0.34), (2.42, -0.08, 0.26, 0.24))
BELLY = ((0.72, 0.14, 0.2, 0.36), (0.95, 0.1, 0.36, 0.44), (1.3, 0.04, 0.38, 0.45), (1.8, -0.06, 0.31, 0.38), (2.15, -0.12, 0.24, 0.32), (2.32, -0.1, 0.12, 0.27))
# upright sections as (depth, middle height, half width, up, down): the head, back to nose
HEAD = ((0.26, 2.84, 0.16, 0.16, 0.16), (0.08, 2.87, 0.35, 0.35, 0.33), (-0.2, 2.86, 0.38, 0.34, 0.34), (-0.46, 2.8, 0.27, 0.22, 0.25), (-0.7, 2.75, 0.15, 0.12, 0.14), (-0.82, 2.73, 0.07, 0.06, 0.07))
STAR4 = [(0, 1), (0.24, 0.24), (1, 0), (0.24, -0.24), (0, -1), (-0.24, -0.24), (-1, 0), (-0.24, 0.24)]


def back(z):
    """A ray onto the torso at height z, and the directions across the back, flank to flank."""
    for a, b in zip(SPINE, SPINE[1:]):
        if a[0] <= z <= b[0]:
            y = a[1] + (b[1] - a[1]) * (z - a[0]) / (b[0] - a[0])
            return [((0, y, z), (math.sin(math.radians(t)), math.cos(math.radians(t)), 0)) for t in (-72, -40, -12, 12, 40, 72)]
    raise ValueError(f"no torso at z = {z}")


def meerkat_model(p, seed):
    """The meerkat from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", F.WARM)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    fur, belly, dark = T("fur"), T("belly"), T("dark")
    coat = p.get("coat", "fur")
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {name: [] for name in PARTS}
    groups.update({name + "_glow": [] for name in PARTS})

    def hide(ob, tones, bulge=0.025):
        return rough(ob, tones, rng, bulge, 1.6)

    def limb(points, radii, tones, name):
        return F.colour(k.tube([Vector(q) for q in points], radii, m=F.material(surface=coat), n=6, name=name), tones, rng)

    # the body: standing tall, a pear leaning a little forward at the shoulders, a pale belly
    torso = hide(loft("torso", [round_z(0, y, z, wx, wy, 12) for z, y, wx, wy in SPINE], fur, rng, surface=coat), fur)
    front = hide(loft("belly", [round_z(0, y, z, wx, wy, 12) for z, y, wx, wy in BELLY], belly, rng, surface=coat), belly, 0.015)
    groups["body"] += [torso, front]

    for s, side in ((1, "l"), (-1, "r")):
        # the legs it stands on: a haunch at the hip over a long flat foot
        x = s * 0.42
        groups["leg_b" + side] += [
            hide(loft("haunch", [oval(0.55, 0.62, 0.17, 0.26, 0.3, 8, x), oval(0.2, 0.62, 0.25, 0.42, 0.4, 8, x), oval(-0.2, 0.5, 0.2, 0.3, 0.34, 8, x)], fur, rng, surface=coat), fur, 0.02),
            loft("foot", [yring(0.3, 0.1, 0.13, 0.1, 0.1, 0.04, x), yring(-0.25, 0.11, 0.17, 0.11, 0.11, 0.05, x), yring(-0.55, 0.08, 0.16, 0.07, 0.08, 0.04, x)], T("paw"), rng, surface=coat),
        ]
        for dx in (-0.1, 0.0, 0.1):
            groups["leg_b" + side].append(shard((x + dx, -0.5, 0.07), (x + dx * 1.5, -0.74, 0.03), 0.07, 0.06, dark, rng, face=(0, 0, 1), at=0.3, name="claw"))
        # the arms: thin, held at the chest, the paws hanging
        wrist = Vector((s * 0.3, -0.56, 1.58))
        groups["leg_f" + side] += [
            limb([(s * 0.4, -0.1, 2.12), (s * 0.52, -0.3, 1.7), wrist], [0.13, 0.1, 0.085], fur, "arm"),
            shard(wrist + Vector((0, 0.04, 0.06)), wrist + Vector((-s * 0.04, -0.12, -0.26)), 0.17, 0.12, T("paw"), rng, at=0.4, name="paw", surface=coat),
        ]
        for dx in (-0.05, 0.0, 0.05):
            groups["leg_f" + side].append(shard(wrist + Vector((dx - s * 0.03, -0.1, -0.2)), wrist + Vector((dx * 1.6 - s * 0.04, -0.15, -0.38)), 0.045, 0.04, dark, rng, at=0.3, name="claw"))

    # the head on a short neck: a round skull narrowing to a pointed nose, dark patches round the eyes,
    # small dark ears low on its sides
    head = groups["head"]
    head.append(hide(loft("neck", [round_z(0, -0.07, 2.3, 0.25, 0.23, 8), round_z(0, -0.04, 2.72, 0.23, 0.22, 8)], fur, rng, surface=coat), fur, 0.015))
    skull = hide(loft("skull", [oval(*r) for r in HEAD], fur, rng, surface=coat), fur, 0.02)
    head.append(skull)
    head.append(hide(loft("chin", [oval(0.0, 2.7, 0.24, 0.12, 0.16, 8), oval(-0.3, 2.68, 0.22, 0.12, 0.15, 8), oval(-0.66, 2.69, 0.1, 0.07, 0.08, 8)], belly, rng, surface=coat), belly, 0.01))
    head.append(shard((0, -0.76, 2.76), (0, -0.9, 2.73), 0.13, 0.11, tone(F.INK), rng, at=0.4, name="nose"))
    for s in (1, -1):
        at, n = k.land(skull, (s * 0.2, -0.33, 2.9), (s * 0.8, -0.55, 0.3))
        ex, ey, ez = k._frame(n)
        frame = (ex * s, ey, ez)
        head.append(plate("patch", at, frame, [(-0.17, -0.07), (-0.08, 0.1), (0.1, 0.12), (0.2, 0.0), (0.06, -0.11)], 0.015, dark, rng, lift=0.012))
        slit = [(-0.085, -0.03), (0.0, 0.05), (0.1, 0.04), (0.03, -0.04)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, frame, slit, 0.02, None, rng, lift=0.03, m=glow))
        else:
            head.append(plate("eye", at, frame, slit, 0.018, tone(p["iris"], F.WARM), rng, lift=0.03))
            head.append(plate("pupil", at, frame, [(0.0, -0.025), (0.03, 0.0), (0.025, 0.035), (-0.004, 0.012)], 0.01, tone(F.INK), rng, lift=0.05))
        head.append(shard((s * 0.3, 0.0, 2.9), (s * 0.5, 0.1, 3.06), 0.22, 0.1, dark, rng, face=(0, -1, 0), at=0.5, name="ear"))

    # dark bands across the back
    band = p.get("bands", True)
    for z in (1.0, 1.3, 1.6, 1.9) if band else ():
        groups["body"].append(F.colour(k.vein(torso, back(z), 0.055, F.material(), lift=0.0, name="band"), dark, rng))

    # the tail: long and thin, its end on the ground behind, a dark tip
    t0, tip = Vector((0, 0.5, 0.78)), Vector((0, 2.05, 0.3))
    groups["tail"].append(limb([t0, (0, 1.05, 0.34), (0, 1.6, 0.16), tip], [0.14, 0.11, 0.085, 0.06], fur, "tail"))
    if p.get("tip", True):
        groups["tail"].append(shard(tip - Vector((0, 0.1, 0.02)), tip + Vector((0, 0.34, 0.12)), 0.14, 0.14, dark, rng, at=0.35, name="tip"))

    if p.get("extra"):
        p["extra"](groups, dict(torso=torso, belly=front, skull=skull, tip=tip), rng, glow)
    joints = {"head": (0, -0.05, 2.45), "leg_fl": (0.4, -0.1, 2.1), "leg_fr": (-0.4, -0.1, 2.1), "leg_bl": (0.42, 0.2, 0.75), "leg_br": (-0.42, 0.2, 0.75), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def meerkat():
    """Meerkat: sandy, a cream belly, dark bands across the back, dark eye patches and amber eyes."""
    return meerkat_model(dict(fur=(204, 164, 110), belly=(236, 214, 170), dark=(92, 66, 48), paw=(150, 114, 78), iris=(240, 170, 40)), 3)


def bolt(points, width, rng, glow):
    """A bolt of lightning through `points`: Neon shards end to end."""
    return [shard(a, b, width, width * 0.5, None, rng, face=(0, -1, 0.2), m=glow, name="bolt") for a, b in zip(points, points[1:])]


def storm_extra(groups, pieces, rng, glow):
    """Forked lightning down the back for bands, a ruff of thundercloud at the neck, a crest of sparks,
    bolts leaping from the shoulders, a ball of lightning between the paws, a charged tail tip."""
    orb = Vector((0, -0.7, 1.5))
    for i in range(10):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 0.6), rng.uniform(-1, 1))).normalized()
        groups["body_glow"].append(shard(orb - d * 0.08, orb + d * rng.uniform(0.16, 0.3), 0.13, 0.13, None, rng, at=0.3, m=glow, name="orb"))
    cloud = tone((150, 160, 186), F.COOL)
    for z in (1.0, 1.3, 1.6, 1.9):  # the bands, as zigzags
        landed = [k.land(pieces["torso"], c, d) for c, d in back(z)]
        pts = [at + n * 0.03 + Vector((0, 0, 0.09 * (-1) ** i)) for i, (at, n) in enumerate(landed)]
        groups["body_glow"] += bolt(pts, 0.1, rng, glow)
    for i in range(9):  # the ruff
        a = i * math.tau / 9
        at = Vector((math.cos(a) * 0.36, -0.06 + math.sin(a) * 0.32, 2.36 + 0.05 * math.sin(a * 2)))
        groups["body"].append(F.lump(at, (0.19, 0.19, 0.19), cloud, rng, surface=None))
    for s in (1, -1):
        base = Vector((s * 0.44, 0.02, 2.2))
        groups["body_glow"] += bolt([base, base + Vector((s * 0.3, 0.1, 0.3)), base + Vector((s * 0.22, 0.14, 0.55)), base + Vector((s * 0.5, 0.2, 0.9))], 0.11, rng, glow)
    for i, h in enumerate((0.3, 0.46, 0.34)):  # a crest of sparks
        base = Vector((0, 0.12 - i * 0.15, 3.16))
        groups["head_glow"].append(shard(base - Vector((0, 0, 0.08)), base + Vector(((i - 1) * 0.06, 0.12, h)), 0.12, 0.08, None, rng, face=(1, 0, 0), at=0.35, m=glow, name="spark"))
    tip = pieces["tip"]
    groups["tail_glow"] += bolt([tip, tip + Vector((0.14, 0.2, 0.3)), tip + Vector((-0.1, 0.3, 0.52)), tip + Vector((0.08, 0.42, 0.9))], 0.16, rng, glow)
    for dx in (-0.2, 0.22):
        groups["tail_glow"].append(shard(tip, tip + Vector((dx, 0.3, 0.3)), 0.1, 0.07, None, rng, m=glow, name="bolt"))


def storm_meerkat():
    """Storm Meerkat (legendary): a thundercloud coat, forked lightning down the back, a ruff of cloud, a
    crest of sparks, a charged tail, glowing eyes."""
    return meerkat_model(
        dict(kind=F.COOL, fur=(58, 68, 96), belly=(112, 126, 156), dark=(26, 30, 46), paw=(40, 48, 70), glow=STORM, glow_eyes=True, bands=False, tip=False, extra=storm_extra),
        7,
    )


def star_extra(groups, pieces, rng, glow):
    """Stars across the coat joined into constellations, a great star on the chest, a star on the brow
    and a ring of them round the head, a comet for a tail tip."""
    torso = pieces["torso"]
    at, n = k.land(pieces["belly"], (0, 0, 1.72), (0, -1, 0.1))
    groups["body_glow"].append(plate("star", at, k._frame(n), [(u * 0.24, v * 0.24) for u, v in STAR4], 0.025, None, rng, lift=0.02, m=glow))
    for i in range(6):  # the ring, tilted
        a = i * math.tau / 6 + 0.3
        out = Vector((math.cos(a), math.sin(a), 0))
        at = Vector((0, -0.15, 3.42)) + out * 0.5 + Vector((0, 0, 0.12 * math.sin(a)))
        size = 0.1 if i % 2 else 0.07
        groups["head_glow"].append(plate("star", at, k._frame(out), [(u * size, v * size) for u, v in STAR4], 0.03, None, rng, lift=0.0, m=glow))
    sky = [(0.5, 1.95, 62), (-0.35, 1.7, 30), (0.2, 1.4, -8), (-0.45, 1.15, -50), (0.4, 0.95, 20), (0.0, 2.1, -75), (0.1, 1.05, 80), (-0.1, 1.6, 110), (0.1, 1.25, 96), (-0.1, 1.9, -98), (0.1, 0.95, -104), (0.0, 1.45, -112)]
    landed = []
    for i, (lift, z, turn) in enumerate(sky):  # all round the body: turn 0 is the middle of the back
        d = Vector((math.sin(math.radians(turn)), math.cos(math.radians(turn)), lift * 0.3))
        at, n = k.land(torso, (0, 0.1, z), d)
        landed.append(at + n * 0.02)
        size = (0.13, 0.09, 0.11, 0.075)[i % 4]
        groups["body_glow"].append(plate("star", at, k._frame(n), [(u * size, v * size) for u, v in STAR4], 0.02, None, rng, lift=0.02, m=glow))
    for chain in ((0, 1, 2, 3), (5, 1), (2, 4, 6), (7, 8, 9)):  # constellations
        for a, b in zip(chain, chain[1:]):
            groups["body_glow"].append(shard(landed[a], landed[b], 0.035, 0.03, None, rng, face=(0, 1, 0), m=glow, name="line"))
    at, n = k.land(pieces["skull"], (0, -0.2, 2.9), (0, -0.5, 1))
    groups["head_glow"].append(plate("star", at, k._frame(n, up=(0, 1, 0)), [(u * 0.15, v * 0.15) for u, v in STAR4], 0.025, None, rng, lift=0.02, m=glow))
    tip = pieces["tip"]
    for d, size in (((0, 0.5, 0.5), 0.5), ((0.3, 0.3, 0.6), 0.3), ((-0.3, 0.3, 0.6), 0.3), ((0, 0.8, 0.1), 0.3), ((0, 0.0, 0.8), 0.28)):  # a comet's head
        d = Vector(d).normalized()
        groups["tail_glow"].append(shard(tip - d * 0.14, tip + d * size, 0.2, 0.2, None, rng, at=0.3, m=glow, name="comet"))


def star_meerkat():
    """Star Meerkat (mythic): a coat of night sky, deep violet with a sparkle of far stars, golden stars
    joined into constellations, a star on the brow, a comet for a tail tip, glowing eyes."""
    return meerkat_model(
        dict(kind=NIGHT, fur=(52, 36, 112), belly=(104, 70, 170), dark=(24, 16, 60), paw=(36, 24, 84), glow=STAR, glow_eyes=True, bands=False, tip=False, coat="gem", extra=star_extra),
        11,
    )


ASSETS = [
    F.asset("creature_meerkat", meerkat, 1.5, {}, "Meerkat: an upright sentinel, sandy with dark bands and eye patches."),
    F.asset("creature_meerkat_storm", storm_meerkat, 1.85, {"head_glow": STORM, "body_glow": STORM, "tail_glow": STORM}, "Storm Meerkat (legendary): thundercloud coat, Neon lightning down the back, a charged tail."),
    F.asset("creature_meerkat_star", star_meerkat, 2.05, {"head_glow": STAR, "body_glow": STAR, "tail_glow": STAR}, "Star Meerkat (mythic): a coat of night sky, Neon stars and constellations, a comet tail."),
]
