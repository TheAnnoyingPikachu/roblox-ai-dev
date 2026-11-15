"""The jackals (decision 0052), in the faceted low-poly style of the lions and elephants: the Jackal,
the Pharaoh Jackal and the Moon Jackal. A lean body with a deep chest and a tucked waist on long thin
legs, a long narrow muzzle, tall pointed ears, a dark saddle over the back and a bushy tail of leaf
shards. The hide is textured with facets (`rough`), as on the elephants.

Jointed like every creature: body, head (with the neck and ears), four legs, tail, and Neon `_glow`
pieces. Facing Blender -Y; left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Matrix, Vector

loft, yring, zring, quad, shard, plate, tone, rough = F.loft, F.yring, F.zring, F.quad, F.shard, F.plate, F.tone, F.rough

SAND = ((0.82, 0.74, 0.66), (1.06, 1.08, 1.12), (6, 8, 10))
MOONLIT = ((0.74, 0.8, 0.92), (1.05, 1.05, 1.03), (6, 6, 4))  # shadows turn blue
GOLD = (236, 184, 64)
TURQUOISE = (60, 230, 220)
MOON = (160, 205, 255)
HIND = 1.9  # how far behind the front legs the hind legs stand
FADE = 1.6  # the hide darkens below this height
NOD = 14  # degrees the head and neck are tipped down about the neck: a hunter carries its head low


def foot(x, y, tones, rng):
    """A small block of a paw with three stubby toes."""
    parts = [loft("paw", [yring(y + 0.16, 0.14, 0.15, 0.13, 0.14, 0.05, x), yring(y - 0.2, 0.15, 0.18, 0.14, 0.15, 0.06, x)], tones, rng)]
    for dx in (-0.12, 0.0, 0.12):
        parts.append(loft("toe", [quad(y - 0.17, 0.11, 0.055, 0.1, 0.11, x + dx), quad(y - 0.36, 0.08, 0.05, 0.05, 0.08, x + dx)], tones, rng))
    return parts


def jackal_model(p, seed):
    """The jackal from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", SAND)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    coat, legs, dark, pale = T("coat"), T("legs"), T("dark"), T("pale")
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "head_glow": [], "tail": [], "tail_glow": []}

    def hide(ob, tones, bulge=0.012):
        return rough(ob, tones, rng, bulge, FADE)

    # the torso: a deep chest and a tucked waist, with a dark saddle from the shoulders to the hips
    barrel = ((-0.55, 1.85, 0.34, 0.42, 0.45, 0.14), (-0.1, 1.8, 0.5, 0.55, 0.6, 0.18), (0.9, 1.88, 0.42, 0.45, 0.42, 0.15), (1.8, 1.85, 0.47, 0.48, 0.45, 0.16), (2.3, 1.9, 0.26, 0.28, 0.25, 0.1))

    def girth(y):
        """The torso's section at depth y, between its rings: (zc, half width, up, down, cut)."""
        for a, b in zip(barrel, barrel[1:]):
            if a[0] <= y <= b[0]:
                u = (y - a[0]) / (b[0] - a[0])
                return tuple(a[i] + (b[i] - a[i]) * u for i in range(1, 6))
        raise ValueError(f"no torso at y = {y}")

    groups["body"].append(hide(loft("torso", [yring(*r) for r in barrel], coat, rng), coat))
    saddle = [(y, *girth(y)) for y in (-0.3, 0.9, 1.95)]
    groups["body"].append(hide(loft("saddle", [yring(y, zc + 0.12, w + 0.035, up - 0.085, 0.2, c + 0.01) for y, zc, w, up, _, c in saddle], dark, rng), dark, 0.006))

    # legs: long and thin, the lower half lighter, small dark paws
    thighs = {}
    for s in (1, -1):
        x, side = s * 0.33, "l" if s > 0 else "r"
        thighs[s] = hide(loft("thigh", [zring(x, HIND + 0.02, 1.9, 0.2, 0.36, 0.07), zring(x, HIND - 0.05, 1.35, 0.22, 0.4, 0.08), zring(x, HIND - 0.18, 1.0, 0.17, 0.24, 0.06)], coat, rng), coat)
        groups["leg_f" + side] = [
            hide(loft("arm", [zring(x, 0.0, 1.75, 0.2, 0.26, 0.07), zring(x, 0.05, 1.05, 0.17, 0.2, 0.06)], coat, rng), coat),
            hide(loft("forearm", [zring(x, 0.05, 1.08, 0.14, 0.16, 0.05), zring(x, 0.0, 0.28, 0.13, 0.15, 0.05)], legs, rng), legs),
            *foot(x, 0.0, T("paw"), rng),
        ]
        groups["leg_b" + side] = [
            thighs[s],
            hide(loft("shin", [zring(x, HIND - 0.18, 1.03, 0.14, 0.2, 0.05), zring(x, HIND + 0.22, 0.62, 0.12, 0.15, 0.04), zring(x, HIND + 0.12, 0.28, 0.13, 0.15, 0.05)], legs, rng), legs),
            *foot(x, HIND + 0.08, T("paw"), rng),
        ]

    # the head: a long narrow muzzle widening to the skull, a pale lower jaw, a dark nose, a neck
    skull = hide(loft("skull", [yring(*r) for r in ((-1.9, 2.52, 0.11, 0.1, 0.1, 0.04), (-1.45, 2.55, 0.17, 0.15, 0.14, 0.06), (-1.1, 2.62, 0.3, 0.26, 0.22, 0.1), (-0.8, 2.66, 0.36, 0.3, 0.26, 0.12), (-0.5, 2.6, 0.3, 0.26, 0.26, 0.1))], coat, rng), coat, 0.008)
    head = groups["head"]
    head.append(skull)
    head.append(hide(loft("neck", [yring(-0.78, 2.42, 0.24, 0.26, 0.3, 0.09), yring(-0.3, 2.0, 0.32, 0.34, 0.4, 0.11)], coat, rng), coat))
    head.append(loft("chin", [yring(-1.84, 2.4, 0.09, 0.035, 0.05, 0.03), yring(-1.15, 2.36, 0.22, 0.05, 0.08, 0.05)], pale, rng))
    head.append(loft("nose", [quad(-1.94, 2.6, 0.075, 0.045, 0.07), quad(-1.8, 2.62, 0.085, 0.05, 0.05)], tone(p["nose"]), rng))
    for s in (1, -1):
        # big pointed ears with a coloured inside, and a brow
        head.append(shard((s * 0.2, -0.72, 2.86), (s * 0.38, -0.62, 3.5), 0.44, 0.16, coat, rng, at=0.4, name="ear"))
        head.append(shard((s * 0.21, -0.8, 2.96), (s * 0.36, -0.7, 3.36), 0.26, 0.06, T("ear_in"), rng, at=0.4, name="ear"))
        head.append(shard((s * 0.06, -1.14, 2.84), (s * 0.4, -0.92, 2.99), 0.14, 0.11, dark, rng, face=(0, -1, 0.5), name="brow"))
        # a slit of an eye on the side of the head
        at, n = k.land(skull, (s * 0.25, -0.98, 2.72), (s * 0.7, -0.7, 0.15))
        ex, ey, ez = k._frame(n)
        slit = [(-0.1, -0.035), (0.01, 0.045), (0.13, 0.04), (0.04, -0.03)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.025, None, rng, lift=0.012, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.02, tone(p["iris"], F.WARM), rng, lift=0.012))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.025), (0.03, 0.0), (0.025, 0.035), (-0.003, 0.012)], 0.01, tone(F.INK), rng, lift=0.033))

    # the tail: a brush of leaf shards hanging back, the tip its own colour (or glowing)
    t0, flow = Vector((0, 2.22, 1.95)), Vector((0, 0.82, -0.57))
    end = t0 + flow * 2.1
    brush = (coat, T("tail"))
    groups["tail"].append(shard(t0 - flow * 0.15, end, 0.62, 0.5, brush, rng, face=(0, 1, 1), name="brush"))
    for i in range(4):
        a = i * math.tau / 4 + 0.6
        off = Vector((math.cos(a) * 0.2, 0, math.sin(a) * 0.17))
        base = t0 + flow * (0.3 + 0.25 * i) + off
        groups["tail"].append(shard(base, base + (flow + off * 1.2).normalized() * (1.25 - 0.1 * i), 0.42, 0.3, brush, rng, face=off + Vector((0, 0.2, 0)), at=0.45, name="brush"))
    if p.get("tip") == "glow":
        groups["tail_glow"].append(shard(end - flow * 0.6, end + flow * 0.35, 0.44, 0.38, None, rng, face=(0, 1, 1), m=glow, name="tip"))
    else:
        groups["tail"].append(shard(end - flow * 0.6, end + flow * 0.35, 0.44, 0.38, T("tip"), rng, face=(0, 1, 1), name="tip"))

    extra = p.get("extra")
    if extra:
        extra(groups, skull, thighs, rng, glow)
    neck = Vector((0, -0.42, 2.1))
    nod = Matrix.Translation(neck) @ Matrix.Rotation(math.radians(NOD), 4, "X") @ Matrix.Translation(-neck)
    for ob in groups["head"] + groups["head_glow"]:
        ob.data.transform(nod)
    joints = {"head": tuple(neck), "leg_fl": (0.33, 0, 1.5), "leg_fr": (-0.33, 0, 1.5), "leg_bl": (0.33, HIND, 1.5), "leg_br": (-0.33, HIND, 1.5), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def jackal():
    """Jackal: lean and sandy, a dark saddle, big pointed ears, dark paws and tail tip, amber eyes."""
    return jackal_model(
        dict(coat=(198, 158, 102), legs=(210, 174, 120), dark=(86, 62, 46), pale=(234, 216, 178), paw=(84, 62, 46), nose=(34, 26, 24), ear_in=(152, 104, 82), iris=(240, 176, 40),
             tail=(160, 120, 76), tip=(44, 34, 30)),
        2,
    )


def pharaoh_extra(groups, skull, thighs, rng, glow):
    """Gold: two collars round the neck, an anklet on every leg, tips on the ears; a glowing gem on the brow."""
    gold = tone(GOLD)
    for y, zc, w, up, down, thick in ((-0.56, 2.23, 0.306, 0.326, 0.375, 0.05), (-0.42, 2.11, 0.33, 0.35, 0.405, 0.03)):
        groups["head"].append(loft("collar", [yring(y + dy, zc, w, up, down, 0.1) for dy in (-thick, thick)], gold, rng))
    for s in (1, -1):
        side = "l" if s > 0 else "r"
        for leg, y in (("leg_f" + side, 0.02), ("leg_b" + side, HIND + 0.17)):
            groups[leg].append(loft("anklet", [zring(s * 0.33, y, z, 0.165, 0.185, 0.05) for z in (0.52, 0.42)], gold, rng))
        groups["head"].append(shard((s * 0.34, -0.645, 3.26), (s * 0.395, -0.61, 3.6), 0.22, 0.12, gold, rng, at=0.3, name="eartip"))
    groups["head_glow"].append(shard((0, -1.02, 2.86), (0, -0.98, 3.16), 0.13, 0.11, None, rng, at=0.4, m=glow, name="gem"))


def pharaoh_jackal():
    """Pharaoh Jackal (legendary): a black coat, gold collars, anklets and ear tips, a gold tail tip,
    turquoise glowing eyes and a glowing gem on the brow."""
    return jackal_model(
        dict(kind=F.COOL, coat=(32, 32, 44), legs=(42, 42, 58), dark=(18, 18, 26), pale=(74, 76, 96), paw=(22, 22, 30), nose=(10, 10, 12), ear_in=(196, 148, 52),
             tail=(50, 50, 70), tip=GOLD, glow=TURQUOISE, glow_eyes=True, extra=pharaoh_extra),
        8,
    )


def moon_extra(groups, skull, thighs, rng, glow):
    """A glowing crescent on the brow and on each haunch, and glowing tips on the ears."""
    arc = [math.radians(a) for a in range(60, 301, 40)]
    crescent = [(0.16 * math.cos(a), 0.16 * math.sin(a)) for a in arc] + [(0.07 + 0.125 * math.cos(a), 0.125 * math.sin(a)) for a in reversed(arc)]
    at, n = k.land(skull, (0, -0.92, 2.7), (0, -0.3, 1))
    groups["head_glow"].append(plate("crescent", at, k._frame(n, (0, -1, 0)), crescent, 0.025, None, rng, lift=0.012, m=glow))
    for s in (1, -1):
        groups["head_glow"].append(shard((s * 0.34, -0.645, 3.26), (s * 0.395, -0.61, 3.6), 0.22, 0.12, None, rng, at=0.3, m=glow, name="eartip"))
        at, n = k.land(thighs[s], (s * 0.3, HIND - 0.02, 1.55), (s, 0, 0))
        fx, fy, fz = k._frame(n)
        side = "leg_b" + ("l" if s > 0 else "r") + "_glow"
        groups.setdefault(side, []).append(plate("crescent", at, (fx * s, fy, fz), [(u * 1.5, v * 1.5) for u, v in crescent], 0.025, None, rng, lift=0.014, m=glow))


def moon_jackal():
    """Moon Jackal (mythic): a silver-white coat with a deep blue saddle and socks, a glowing crescent on
    the brow, glowing eyes, ear tips and tail tip."""
    return jackal_model(
        dict(kind=MOONLIT, coat=(182, 198, 228), legs=(204, 216, 240), dark=(48, 62, 124), pale=(236, 242, 252), paw=(52, 66, 126), nose=(38, 46, 80), ear_in=(128, 150, 202),
             tail=(168, 186, 226), tip="glow", glow=MOON, glow_eyes=True, extra=moon_extra),
        12,
    )


ASSETS = [
    F.asset("creature_jackal", jackal, 1.18, {}, "Jackal: a lean faceted pack hunter with a dark saddle and a bushy tail."),
    F.asset("creature_jackal_pharaoh", pharaoh_jackal, 1.45, {"head_glow": TURQUOISE}, "Pharaoh Jackal (legendary): black with gold bands; eyes and brow gem are Neon."),
    F.asset("creature_jackal_moon", moon_jackal, 1.53, {"head_glow": MOON, "tail_glow": MOON, "leg_bl_glow": MOON, "leg_br_glow": MOON}, "Moon Jackal (mythic): silver with a deep blue saddle, a Neon crescent on the brow."),
]
