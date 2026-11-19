"""The cheetahs (decision 0053), in the faceted low-poly style of the lions, elephants and jackals:
the Cheetah, the Lightning Cheetah and the Fire Cheetah. A slender body with a deep chest and a high
tucked waist on very long thin legs, a small head with a short muzzle, round ears and tear marks,
spots as small flat diamonds on the hide, and a very long tail. The hide is textured with facets.

Jointed like every creature: body, head (with the neck and ears), four legs, tail, and Neon `_glow`
pieces. Facing Blender -Y; left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Matrix, Vector

loft, yring, zring, quad, shard, plate, tone, rough = F.loft, F.yring, F.zring, F.quad, F.shard, F.plate, F.tone, F.rough

GOLDEN = ((0.84, 0.72, 0.6), (1.06, 1.08, 1.14), (6, 8, 10))
BRIGHT = ((0.92, 0.92, 0.92), (1.04, 1.04, 1.04), (4, 4, 4))  # spots that must stay their colour
BOLT = (90, 190, 255)
FLAME = (255, 150, 40)
HIND = 2.1  # how far behind the front legs the hind legs stand
FADE = 1.7  # the hide darkens below this height
NOD = 8  # degrees the head and neck are tipped down about the neck
HEAD = 0.9  # the head is shrunk by this about the neck: a cheetah's head is small
TAIL = ((0, 2.4, 2.25), (0, 3.1, 2.0), (0, 3.85, 1.55), (0, 4.6, 1.4), (0, 5.25, 1.6), (0, 5.7, 2.0))


LICK = [(-0.22, 0.0), (0.22, 0.0), (0.34, 0.4), (0.5, 1.0), (0.05, 0.55), (-0.2, 0.3)]  # (back, up): a tongue of flame, leaning back
BLAZE = [(-0.2, 0.0), (0.2, 0.0), (0.3, 0.4), (0.0, 1.0), (-0.3, 0.4)]  # an upright one, for the chest
HOT, HEART = (255, 150, 36), (255, 230, 124)  # a painted flame's body and its heart
ROOT, TIP = (232, 78, 26), (255, 214, 84)  # a standing flame, from its root to its tip


def gradient(ob, stops, rng, kind):
    """Repaints a piece by height: `stops` [(z, rgb), ...] from low to high (the Fire Cheetah's coat)."""

    def at(z):
        for (z0, c0), (z1, c1) in zip(stops, stops[1:]):
            if z <= z1:
                return k.mix(c0, c1, max(0.0, min(1.0, (z - z0) / (z1 - z0))))
        return stops[-1][1]

    return F.colour(ob, [tone(at(poly.center.z), kind) for poly in ob.data.polygons], rng, 0.2)


def lick(target, into, centre, s, size, rng, direction=None, outline=LICK):
    """A tongue of flame painted on `target` (on its side, unless `direction` says where it faces):
    orange with a yellow heart, leaning back."""
    try:
        at, n = k.land(target, centre, direction or (s, 0, 0))
    except ValueError:
        return  # the ray misses the piece here
    fx, fy, fz = k._frame(n)
    frame = (fx * s, fy, fz)  # across is towards the tail on both sides
    into.append(plate("lick", at, frame, [(u * size, v * size) for u, v in outline], 0.012, tone(HOT, BRIGHT), rng, lift=0.018))
    into.append(plate("lick", at + frame[0] * 0.05 * size + fy * 0.06 * size, frame, [(u * size * 0.55, v * size * 0.6) for u, v in outline], 0.01, tone(HEART, BRIGHT), rng, lift=0.032))


def flame(base, lean, height, width, into, hearts, rng, glow, face=(1, 0, 0)):
    """A flame standing on `base`: a painted tongue, red at the root and yellow at the tip, round a
    glowing heart that shows on both sides."""
    into.append(shard(base - lean * 0.12, base + lean * height, width, width * 0.26, (tone(ROOT, F.FIRE), tone(TIP, F.FIRE)), rng, face=face, at=0.35, name="flame"))
    hearts.append(shard(base - lean * 0.08, base + lean * height * 0.62, width * 0.4, width * 0.34, None, rng, face=face, at=0.35, m=glow, name="flame"))


def cheetah_model(p, seed):
    """The cheetah from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", GOLDEN)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    coat, legs, pale, dark = T("coat"), T("legs"), T("pale"), T("dark")
    spot = tone(p["spot"], p.get("spot_kind", kind))
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "head_glow": [], "body_glow": [], "tail": [], "tail_glow": []}

    flames, grade = p.get("flames", False), p.get("grade")  # the Fire Cheetah: flames for spots, a coat graded by height

    def hide(ob, tones, bulge=0.01):
        ob = rough(ob, tones, rng, bulge, FADE)
        return gradient(ob, grade, rng, kind) if grade else ob

    def spots(target, into, centres, direction, size=0.085):
        """Flat diamond spots on `target`, where rays through `centres` along `direction` meet it."""
        for c in centres:
            try:
                at, n = k.land(target, c, direction)
            except ValueError:
                continue  # the ray misses the piece here
            r, turn = size * rng.uniform(0.75, 1.25), rng.uniform(0, math.tau)
            outline = [(r * math.cos(turn + i * math.tau / 4), r * 0.8 * math.sin(turn + i * math.tau / 4)) for i in range(4)]
            into.append(plate("spot", at, k._frame(n), outline, 0.012, spot, rng, lift=0.016))

    # the torso: a deep chest, a high tucked waist, narrow hips
    torso = hide(loft("torso", [yring(*r) for r in ((-0.6, 2.05, 0.3, 0.38, 0.42, 0.12), (-0.15, 2.0, 0.44, 0.5, 0.62, 0.16), (1.0, 2.14, 0.33, 0.4, 0.32, 0.12), (1.95, 2.08, 0.4, 0.44, 0.42, 0.14), (2.45, 2.12, 0.22, 0.24, 0.22, 0.08))], coat, rng), coat)
    groups["body"].append(torso)
    for s in (1, -1):
        flank = [(0, -0.3 + i * 0.3 + (row % 2) * 0.15 + rng.uniform(-0.04, 0.04), 1.54 + row * 0.24 + rng.uniform(-0.03, 0.03)) for row in (() if flames else range(4)) for i in range(8)]
        # not where a leg covers the flank
        flank = [c for c in flank if not ((abs(c[1]) < 0.3 or abs(c[1] - HIND) < 0.46) and c[2] < 2.12)]
        spots(torso, groups["body"], flank, (s, 0, 0.1))
        spots(torso, groups["body"], [(s * 0.1, -0.1 + i * 0.4, 2.2) for i in range(6)], (s * 0.55, 0, 0.83))

    # legs: very long and thin, the lower half lighter, small paws
    limbs = {}
    for s in (1, -1):
        x, side = s * 0.3, "l" if s > 0 else "r"
        forearm = hide(loft("forearm", [zring(x, 0.05, 1.18, 0.115, 0.13, 0.04), zring(x, 0.0, 0.26, 0.11, 0.125, 0.04)], legs, rng), legs)
        shin = hide(loft("shin", [zring(x, HIND - 0.2, 1.13, 0.12, 0.18, 0.04), zring(x, HIND + 0.26, 0.68, 0.105, 0.13, 0.035), zring(x, HIND + 0.14, 0.26, 0.11, 0.125, 0.04)], legs, rng), legs)
        arm = hide(loft("arm", [zring(x, 0.0, 1.95, 0.17, 0.24, 0.06), zring(x, 0.05, 1.15, 0.14, 0.17, 0.05)], coat, rng), coat)
        thigh = hide(loft("thigh", [zring(x, HIND + 0.02, 2.1, 0.18, 0.36, 0.06), zring(x, HIND - 0.05, 1.5, 0.2, 0.42, 0.07), zring(x, HIND - 0.2, 1.1, 0.15, 0.22, 0.05)], coat, rng), coat)
        groups["leg_f" + side] = [
            arm,
            forearm,
            *F.small_paw(x, 0.0, T("paw"), rng),
        ]
        groups["leg_b" + side] = [
            thigh,
            shin,
            *F.small_paw(x, HIND + 0.1, T("paw"), rng),
        ]
        limbs["arm", s], limbs["thigh", s] = arm, thigh
        if flames:
            continue  # its legs carry flames, not spots
        spots(arm, groups["leg_f" + side], [(0, 0.02, 1.75), (0, -0.08, 1.48), (0, 0.1, 1.3)], (s, 0, 0))
        spots(thigh, groups["leg_b" + side], [(0, HIND + 0.12, 1.9), (0, HIND - 0.18, 1.72), (0, HIND + 0.1, 1.5), (0, HIND - 0.12, 1.3)], (s, 0, 0))
        spots(forearm, groups["leg_f" + side], [(0, 0.04, 0.98), (0, 0.0, 0.68)], (s, 0, 0), 0.05)
        spots(shin, groups["leg_b" + side], [(0, HIND - 0.02, 0.95), (0, HIND + 0.2, 0.6)], (s, 0, 0), 0.05)

    # the head: small, a short muzzle, round ears, tear marks from the eyes to the mouth
    hc = (0, -1.0, 2.92)
    skull = hide(loft("skull", [yring(*r) for r in ((-1.5, 2.8, 0.15, 0.12, 0.12, 0.05), (-1.34, 2.82, 0.21, 0.18, 0.16, 0.07), (-1.12, 2.9, 0.31, 0.27, 0.23, 0.11), (-0.85, 2.93, 0.33, 0.28, 0.25, 0.12), (-0.6, 2.87, 0.27, 0.24, 0.24, 0.1))], coat, rng), coat, 0.007)
    head = groups["head"]
    head.append(skull)
    neck_piece = hide(loft("neck", [yring(-0.82, 2.66, 0.21, 0.24, 0.27, 0.08), yring(-0.35, 2.2, 0.29, 0.32, 0.38, 0.1)], coat, rng), coat)
    head.append(neck_piece)
    limbs["neck"] = neck_piece
    head.append(loft("chin", [yring(-1.47, 2.69, 0.11, 0.035, 0.04, 0.03), yring(-1.18, 2.66, 0.18, 0.045, 0.055, 0.05)], pale, rng))
    head.append(loft("nose", [quad(-1.53, 2.86, 0.075, 0.04, 0.06), quad(-1.44, 2.88, 0.085, 0.045, 0.045)], tone(p["nose"]), rng))
    ear = [(-0.16, 0.0), (-0.15, 0.13), (-0.07, 0.23), (0.07, 0.23), (0.15, 0.13), (0.16, 0.0)]  # small and round
    for s in (1, -1):
        frame = k._frame(Vector((s * 0.35, -1, 0)), (s * 0.3, 0, 1))
        at = Vector((s * 0.25, -0.72, 3.1))
        head.append(plate("ear", at, frame, ear, 0.09, coat, rng))
        head.append(plate("ear", at + frame[2] * 0.09, frame, [(u * 0.6, 0.02 + v * 0.62) for u, v in ear], 0.02, dark, rng))
        head.append(shard((s * 0.05, -1.2, 3.09), (s * 0.36, -0.98, 3.2), 0.13, 0.1, coat, rng, face=(0, -1, 0.5), name="brow"))
        eye, n = k.land(skull, (s * 0.25, -1.08, 2.99), (s * 0.7, -0.7, 0.15))
        ex, ey, ez = k._frame(n)
        slit = [(-0.09, -0.032), (0.01, 0.042), (0.12, 0.036), (0.035, -0.028)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", eye, (ex * s, ey, ez), slit, 0.022, None, rng, lift=0.011, m=glow))
        else:
            head.append(plate("eye", eye, (ex * s, ey, ez), slit, 0.018, tone(p["iris"], F.WARM), rng, lift=0.011))
            head.append(plate("pupil", eye, (ex * s, ey, ez), [(0.0, -0.022), (0.027, 0.0), (0.022, 0.032), (-0.003, 0.011)], 0.009, tone(F.INK), rng, lift=0.03))
        marks = [(hc, k.outward(s * (38 - 5 * i), 2 - 13 * i)) for i in range(4)]
        head.append(k.vein(skull, marks, 0.022, k.flat(p["tear"]), name="tear"))
        spots(skull, head, [(0, -0.72, 3.02), (0, -0.9, 3.12)], (s * 0.5, 0, 0.87), 0.05)
        spots(neck_piece, head, [(0, -0.68, 2.6), (0, -0.52, 2.38), (0, -0.62, 2.3), (0, -0.44, 2.18)], (s, 0, 0.1), 0.06)

    # the tail: very long, with two dark rings towards the end; the tip is its own colour, or glows
    path = [Vector(q) for q in p.get("tail_path", TAIL)]
    last = len(path) - 1
    for i in range(last):
        seg = k.tube([path[i], path[i + 1]], [0.13 - 0.04 * i / last, 0.13 - 0.04 * (i + 1) / last], m=F.material(), n=5, name="tail")
        ring = dark if last - 1 - i in (0, 2) else coat  # two dark rings before the tip
        if p.get("tail_hot"):  # or hotter and hotter towards a tip of flame
            ring = tone(k.mix(p["coat"], p["tail_hot"], i / (last - 1)), kind)
        groups["tail"].append(F.colour(seg, ring, rng))
    end, flow = path[-1], (path[-1] - path[-2]).normalized()
    if p.get("tip") == "glow":
        groups["tail_glow"].append(shard(end - flow * 0.1, end + flow * 0.7, 0.26, 0.14, None, rng, face=(1, 0, 0), at=0.4, m=glow, name="tip"))
    elif p.get("tip") == "flame":
        for i in range(5):
            a = math.radians(-40 + 20 * i)
            d = Vector(((i % 3 - 1) * 0.3, flow.y * math.cos(a) - flow.z * math.sin(a), flow.z * math.cos(a) + flow.y * math.sin(a))).normalized()
            groups["tail_glow"].append(shard(end - d * 0.15, end + d * (1.0 - 0.12 * abs(i - 2)), 0.3, 0.22, None, rng, face=(1, 0, 0.3), at=0.38, m=glow, name="flame"))
            groups["tail"].append(shard(end - d * 0.2, end + d * (1.4 - 0.16 * abs(i - 2)), 0.52, 0.13, (tone(ROOT, F.FIRE), tone(TIP, F.FIRE)), rng, face=(1, 0, 0.3), at=0.38, name="flame"))
    else:
        groups["tail"].append(shard(end - flow * 0.1, end + flow * 0.4, 0.22, 0.2, T("tip"), rng, face=(1, 0, 0), at=0.4, name="tip"))

    extra = p.get("extra")
    if extra:
        extra(groups, torso, limbs, rng, glow)
    neck = Vector((0, -0.42, 2.3))
    nod = Matrix.Translation(neck) @ Matrix.Rotation(math.radians(NOD), 4, "X") @ Matrix.Scale(HEAD, 4) @ Matrix.Translation(-neck)
    for ob in groups["head"] + groups["head_glow"]:
        ob.data.transform(nod)
    joints = {"head": tuple(neck), "leg_fl": (0.3, 0, 1.65), "leg_fr": (-0.3, 0, 1.65), "leg_bl": (0.3, HIND, 1.65), "leg_br": (-0.3, HIND, 1.65), "tail": tuple(path[0])}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def cheetah():
    """Cheetah: a slender golden sprinter with black spots and tear marks, a ringed tail with a pale tip."""
    return cheetah_model(
        dict(coat=(226, 172, 86), legs=(234, 188, 106), pale=(246, 232, 202), dark=(40, 30, 26), paw=(238, 198, 122), spot=(40, 30, 26), nose=(30, 22, 20), tear=(24, 18, 18),
             iris=(240, 180, 40), tip=(246, 238, 216)),
        4,
    )


def lightning_extra(groups, torso, limbs, rng, glow):
    """A jagged bolt of lightning down each flank behind the shoulder and before the haunch, and a crest
    of three short bolts on the back of the neck."""
    for s in (1, -1):
        for y0 in (0.38, 1.05):
            pts = []
            for dy, dz in ((0.0, 2.42), (0.3, 2.2), (0.1, 2.04), (0.42, 1.8)):
                at, n = k.land(torso, (0, y0 + dy, dz), (s, 0, 0.15))
                pts.append(at + n * 0.035)
            for a, b in zip(pts, pts[1:]):
                groups["body_glow"].append(shard(a, b, 0.13, 0.05, None, rng, face=(s, 0, 0), m=glow, name="bolt"))
    for i in range(3):
        base = Vector((0, -0.66 + i * 0.16, 2.95 - i * 0.2))
        groups["head_glow"].append(shard(base, base + Vector((0, 0.3, 0.34 - i * 0.04)), 0.16, 0.07, None, rng, face=(1, 0, 0), at=0.4, m=glow, name="crest"))


def lightning_cheetah():
    """Lightning Cheetah (mythic): a storm-dark coat with electric blue spots, glowing bolts down both
    flanks and a crest of them on the neck, a zigzag tail with a glowing tip, glowing eyes."""
    return cheetah_model(
        dict(kind=F.COOL, coat=(30, 40, 78), legs=(40, 52, 98), pale=(110, 132, 194), dark=(14, 18, 38), paw=(22, 28, 56), spot=(96, 204, 255), spot_kind=BRIGHT, nose=(12, 14, 24),
             tear=(96, 204, 255), glow=BOLT, glow_eyes=True, tip="glow", extra=lightning_extra,
             tail_path=((0, 2.4, 2.25), (0, 3.0, 2.5), (0, 3.5, 1.9), (0, 4.2, 2.2), (0, 4.75, 1.55), (0, 5.3, 1.9))),
        10,
    )


def fire_extra(groups, torso, limbs, rng, glow):
    """Flame, painted and glowing: a mane of it from between the ears down the neck and the spine,
    tongues of it licking up the flanks, shoulders, haunches and throat, and a flame trailing from every heel."""
    body, head = groups["body"], groups["head"]
    for i, h in enumerate((0.6, 0.9, 0.66, 0.96, 0.7, 0.86, 0.6, 0.68, 0.46)):  # down the spine, high and low by turns, streaming back
        at, _ = k.land(torso, (0, -0.4 + i * 0.33, 2.1), (0, 0, 1))
        lean = Vector((rng.uniform(-0.14, 0.14), 1.05, 1)).normalized()
        flame(at, lean, h, 0.6, body, groups["body_glow"], rng, glow)
    for y, z, h in ((-0.95, 3.16, 0.5), (-0.74, 3.1, 0.62), (-0.7, 2.8, 0.55), (-0.56, 2.68, 0.66), (-0.43, 2.57, 0.6)):  # between the ears, down the neck
        flame(Vector((0, y, z)), Vector((0, 1.0, 1)).normalized(), h, 0.46, head, groups["head_glow"], rng, glow)
    lick(limbs["neck"], head, (0, -0.48, 1.98), 1, 0.42, rng, direction=(0, -0.6, -0.8), outline=BLAZE)  # a blaze up the throat
    for s in (1, -1):
        side, x = "l" if s > 0 else "r", s * 0.3
        # big and small by turns, each standing on the flank's flat side (it runs from about 1.72 to 1.96, by
        # the waist, up to 2.4): on the bevel below it a flat tongue would stick out
        for y, z, size in ((0.36, 1.77, 0.56), (0.64, 1.87, 0.34), (0.9, 1.96, 0.42), (1.2, 1.96, 0.3), (1.45, 1.93, 0.42)):
            lick(torso, body, (0, y, z), s, size, rng)
        lick(limbs["arm", s], groups["leg_f" + side], (0, 0.03, 1.2), s, 0.44, rng, outline=BLAZE)  # upright: the arm is narrow
        lick(limbs["thigh", s], groups["leg_b" + side], (0, HIND - 0.16, 1.22), s, 0.6, rng)
        for leg, y in (("leg_f" + side, 0.1), ("leg_b" + side, HIND + 0.24)):
            for base, tip, width in (((x, y, 0.52), (x, y + 0.56, 0.9), 0.22), ((x, y, 0.36), (x, y + 0.38, 0.5), 0.16)):
                groups[leg].append(shard(base, tip, width, width * 0.5, (tone(ROOT, F.FIRE), tone(TIP, F.FIRE)), rng, face=(s, 0, 0), at=0.35, name="heel"))


def fire_cheetah():
    """Fire Cheetah (legendary): a coat that burns from scorched black legs through red to an orange back,
    tongues of flame painted up its flanks and legs, a mane of flame from brow to tail, flames at its
    heels and for a tail tip, glowing eyes."""
    return cheetah_model(
        dict(kind=F.WARM, coat=(208, 74, 30), legs=(120, 44, 28), pale=(255, 204, 120), dark=(52, 26, 22), paw=(46, 28, 26), spot=(255, 208, 84), spot_kind=BRIGHT, nose=(40, 22, 20),
             tear=(52, 26, 22), glow=FLAME, glow_eyes=True, tip="flame", flames=True, tail_hot=(255, 186, 56), extra=fire_extra,
             grade=((0.25, (58, 30, 26)), (0.9, (124, 38, 24)), (1.6, (204, 62, 26)), (2.15, (232, 104, 30)), (2.5, (246, 142, 38)), (2.85, (222, 92, 28)), (3.3, (214, 80, 28)))),
        14,
    )


# scales keep each cheetah as tall as the model it replaces (4.65 and 6 studs); the tail is longer than before
ASSETS = [
    F.asset("creature_cheetah", cheetah, 1.45, {}, "Cheetah: a slender faceted sprinter with black spots and tear marks."),
    F.asset("creature_cheetah_lightning", lightning_cheetah, 1.88, {"head_glow": BOLT, "body_glow": BOLT, "tail_glow": BOLT}, "Lightning Cheetah (mythic): storm coat, Neon bolts down the flanks, a zigzag tail."),
    F.asset("creature_cheetah_fire", fire_cheetah, 1.62, {"head_glow": FLAME, "body_glow": FLAME, "tail_glow": FLAME}, "Fire Cheetah (legendary): a coat graded from scorched black to orange, painted flames, a Neon mane of flame."),
]
