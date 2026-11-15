"""The flamingos (decision 0055), in the build of the rhinos (flat face tones under a surface texture): the
Flamingo, the Phoenix Flamingo and the Peacock Flamingo. A plump feathered body high on two stilts
with webbed feet, a long neck in an S, a small head with a heavy hooked beak, folded wings with dark
flight feathers, short tail plumes.

Jointed like every creature, with the names the clips know: it stands on its "front legs" (leg_fl,
leg_fr) and its wings are the "back legs" (leg_bl, leg_br), so the same joints and moves work for it.
Facing Blender -Y; left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Vector

loft, oval, shard, plate, tone, rough, lump = F.loft, F.oval, F.shard, F.plate, F.tone, F.rough, F.lump

EMBER = (255, 110, 20)
JADE = (40, 235, 190)
PARTS = ("body", "head", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br")
# upright sections as (depth, middle height, half width, up, down): the body, the head, and a wing (its
# sections stand off the body's side)
BODY = ((-0.8, 3.52, 0.26, 0.3, 0.28), (-0.45, 3.46, 0.52, 0.52, 0.5), (0.15, 3.38, 0.64, 0.6, 0.6), (0.8, 3.38, 0.54, 0.48, 0.44), (1.3, 3.44, 0.3, 0.26, 0.2), (1.62, 3.5, 0.1, 0.08, 0.07))
HEAD = ((-0.78, 5.86, 0.18, 0.18, 0.18), (-1.02, 5.9, 0.3, 0.3, 0.28), (-1.28, 5.86, 0.25, 0.23, 0.23), (-1.46, 5.8, 0.16, 0.14, 0.15))
WING = ((-0.5, 3.62, 0.07, 0.3, 0.3, 0.52), (0.2, 3.56, 0.13, 0.5, 0.46, 0.66), (0.9, 3.5, 0.1, 0.38, 0.3, 0.6), (1.5, 3.44, 0.04, 0.15, 0.1, 0.4))
NECK = ((0, -0.6, 3.6), (0, -1.2, 4.2), (0, -0.92, 5.0), (0, -1.02, 5.72))
ROOT = Vector((0, 1.45, 3.48))  # where the tail grows


def flamingo_model(p, seed):
    """The flamingo from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", F.WARM)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    body_t, neck_t, wing_t, leg_t = T("body"), T("neck"), T("wing"), T("leg")
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {name: [] for name in PARTS}
    groups.update({name + "_glow": [] for name in PARTS})

    def tube(points, radii, tones, name, n=6, surface=None):
        return F.colour(k.horn([Vector(q) for q in points], radii, F.material(surface=surface), n=n, steps=2 * len(points), name=name), tones, rng)

    groups["body"].append(rough(loft("body", [oval(*r) for r in BODY], body_t, rng, surface="scales"), body_t, rng, 0.03, 4.2))

    # the neck and head: an S of a neck, a small head, a heavy beak hooked down, a hard stare
    head = groups["head"]
    head.append(tube(NECK, [0.28, 0.19, 0.16, 0.17], neck_t, "neck", 8, "scales"))
    skull = rough(loft("skull", [oval(*r, 10) for r in HEAD], neck_t, rng, surface="scales"), neck_t, rng, 0.015, 9.0)
    head.append(skull)
    head.append(tube([(0, -1.4, 5.8), (0, -1.64, 5.78), (0, -1.86, 5.68)], [0.15, 0.15, 0.13], T("beak"), "beak", surface="horn"))
    head.append(tube([(0, -1.82, 5.7), (0, -2.0, 5.5), (0, -1.9, 5.16)], [0.135, 0.11, 0.0], T("beak_tip"), "beak_tip"))
    for s in (1, -1):
        at, n = k.land(skull, (s * 0.1, -1.12, 5.94), (s * 0.9, -0.35, 0.25))
        ex, ey, ez = k._frame(n)
        slit = [(-0.075, -0.025), (0.0, 0.045), (0.09, 0.035), (0.03, -0.035)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.02, None, rng, lift=0.015, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.016, tone(p["iris"], F.WARM), rng, lift=0.015))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.02), (0.025, 0.0), (0.02, 0.03), (-0.003, 0.01)], 0.01, tone(F.INK), rng, lift=0.033))

    for s, side in ((1, "l"), (-1, "r")):
        # the stilts: a thin leg with a knob of a knee, a webbed foot
        x = s * 0.28
        groups["leg_f" + side] += [
            tube([(x, 0.3, 3.05), (x, 0.46, 1.65), (x, 0.2, 0.1)], [0.12, 0.08, 0.075], leg_t, "leg"),
            lump((x, 0.46, 1.65), (0.13, 0.13, 0.13), leg_t, rng, surface=None),
            shard((x, 0.3, 0.05), (x, -0.5, 0.03), 0.62, 0.06, leg_t, rng, face=(0, 0, 1), at=0.72, name="foot"),
        ]
        # the wings, folded: a blade down the body's side, rows of feathers over its lower edge, the
        # flight feathers behind
        wing = groups["leg_b" + side]
        wing.append(rough(loft("wing", [oval(y, zc, w, up, down, 8, s * x0) for y, zc, w, up, down, x0 in WING], wing_t, rng, surface="scales"), wing_t, rng, 0.02, 4.2))
        for i in range(5):
            y = -0.3 + i * 0.32
            wing.append(shard((s * 0.74, y, 3.6 - i * 0.03), (s * 0.7, y + 0.5, 2.98 + i * 0.03), 0.3, 0.08, T("covert"), rng, face=(s, 0, 0), at=0.45, name="covert", surface="scales"))
        for i in range(4):
            base = Vector((s * 0.6, 1.0 + i * 0.12, 3.5 - i * 0.08))
            tip = base + Vector((-s * 0.1, 0.75 + i * 0.1, -0.3 - i * 0.06))
            if p.get("flight") == "glow":
                groups["leg_b" + side + "_glow"].append(shard(base, tip, 0.2, 0.08, None, rng, face=(s, 0, 0), at=0.4, m=glow, name="flight"))
            else:
                wing.append(shard(base, tip, 0.2, 0.08, T("flight"), rng, face=(s, 0, 0), at=0.4, name="flight"))

    if p.get("plumes", True):  # short tail plumes
        for dx in (-0.2, 0.0, 0.2):
            groups["tail"].append(shard(ROOT - Vector((0, 0.2, 0)), ROOT + Vector((dx * 1.6, 0.6, -0.22 - abs(dx) * 0.3)), 0.24, 0.1, body_t, rng, face=(0, 0, 1), at=0.4, name="plume", surface="scales"))

    if p.get("extra"):
        p["extra"](groups, dict(skull=skull), rng, glow)
    joints = {"head": NECK[0], "leg_fl": (0.28, 0.3, 2.95), "leg_fr": (-0.28, 0.3, 2.95), "leg_bl": (0.6, -0.3, 3.8), "leg_br": (-0.6, -0.3, 3.8), "tail": tuple(ROOT)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def flamingo():
    """Flamingo: pink, coral wings with black flight feathers, a pale beak with a black hook, yellow eyes."""
    return flamingo_model(
        dict(body=(248, 124, 152), neck=(255, 158, 176), wing=(236, 92, 124), covert=(250, 140, 160), flight=(40, 30, 36), leg=(228, 112, 138), beak=(250, 228, 216), beak_tip=(36, 28, 32), iris=(250, 214, 70)),
        3,
    )


def phoenix_extra(groups, pieces, rng, glow):
    """A crest of flame, long streamers of flame for a tail, licks of gold flame painted up the breast."""
    for i, h in enumerate((0.5, 0.8, 0.95, 0.7, 0.45)):
        base = Vector((0, -1.2 + i * 0.12, 6.12))
        groups["head_glow"].append(shard(base - Vector((0, 0, 0.1)), base + Vector(((i - 2) * 0.05, 0.25 + i * 0.06, h)), 0.16, 0.1, None, rng, face=(1, 0, 0), at=0.3, m=glow, name="crest"))
    for i, (dx, length) in enumerate(((-0.5, 2.2), (-0.22, 2.9), (0.0, 3.4), (0.22, 2.9), (0.5, 2.2))):
        a = ROOT - Vector((0, 0.15, 0))
        b = ROOT + Vector((dx * 1.2, length * 0.45, 0.25))
        c = ROOT + Vector((dx * 2.2, length * 0.85, -0.5 - abs(dx)))
        groups["tail_glow"] += [shard(a, b, 0.3, 0.1, None, rng, face=(0, 0, 1), at=0.6, m=glow, name="streamer"), shard(b - (b - a) * 0.15, c, 0.36, 0.1, None, rng, face=(0, 0, 1), at=0.35, m=glow, name="streamer")]
    gold = tone((255, 196, 50), F.FIRE)
    for i in range(7):
        a = (i - 3) * 0.3
        base = Vector((math.sin(a) * 0.5, -0.5 - math.cos(a) * 0.3, 3.05 + abs(i - 3) * 0.05))
        groups["body"].append(shard(base, base + Vector((math.sin(a) * 0.15, -0.12, 0.55 - abs(i - 3) * 0.06)), 0.2, 0.1, gold, rng, face=(math.sin(a), -math.cos(a), 0), at=0.3, name="lick", emit=0.6))


def phoenix_flamingo():
    """Phoenix Flamingo (mythic): fire-red with a gold neck, a crest and long tail streamers of flame, flight
    feathers of flame, gold flames up the breast, glowing eyes."""
    return flamingo_model(
        dict(kind=F.FIRE, body=(226, 62, 24), neck=(255, 150, 36), wing=(170, 30, 20), covert=(250, 110, 26), flight="glow", leg=(110, 30, 22), beak=(255, 206, 80), beak_tip=(70, 20, 16), glow=EMBER, glow_eyes=True, plumes=False, extra=phoenix_extra),
        7,
    )


def peacock_extra(groups, pieces, rng, glow):
    """A fan of long tail feathers, each with a glowing eye near its tip, and a crest of three fine plumes."""
    green, blue, bronze = tone((24, 150, 96), F.COOL), tone((30, 70, 200), F.COOL), tone((206, 150, 60), F.WARM)
    for i in range(11):
        a = math.radians(-80 + i * 16)
        d = Vector((math.sin(a), 0.5, math.cos(a))).normalized()
        length = 2.9 - abs(i - 5) * 0.14
        tip = ROOT + d * length
        groups["tail"].append(shard(ROOT - d * 0.1, tip, 0.5, 0.06, (bronze, green), rng, face=(0, -1, 0.4), at=0.78, name="feather", surface="scales"))
        spot = ROOT + d * length * 0.76
        groups["tail"].append(shard(spot - d * 0.28, spot + d * 0.24, 0.34, 0.12, blue, rng, face=(0, -1, 0.4), at=0.5, name="eye"))
        groups["tail_glow"].append(shard(spot - d * 0.15, spot + d * 0.13, 0.18, 0.2, None, rng, face=(0, -1, 0.4), at=0.5, m=glow, name="eye"))
    for dx in (-0.12, 0.0, 0.12):
        base = Vector((dx * 0.5, -1.02, 6.14))
        top = base + Vector((dx * 1.5, 0.12, 0.5 - abs(dx)))
        groups["head"].append(shard(base, top, 0.035, 0.035, blue, rng, name="stalk"))
        groups["head_glow"].append(shard(top - Vector((0, 0, 0.08)), top + Vector((0, 0, 0.12)), 0.11, 0.11, None, rng, m=glow, name="bead"))


def peacock_flamingo():
    """Peacock Flamingo (legendary): teal with a royal blue neck, emerald wings with bronze flight feathers, a
    great fan of tail feathers with glowing eyes, a crest of three beaded plumes."""
    return flamingo_model(
        dict(kind=F.COOL, body=(20, 150, 160), neck=(34, 84, 210), wing=(24, 150, 96), covert=(40, 180, 150), flight=(206, 150, 60), leg=(150, 136, 110), beak=(246, 232, 200), beak_tip=(50, 44, 40), glow=JADE, glow_eyes=True, plumes=False, extra=peacock_extra),
        11,
    )


ASSETS = [
    F.asset("creature_flamingo", flamingo, 1.3, {}, "Flamingo: two legs; its wings are the back-leg pieces."),
    F.asset("creature_flamingo_phoenix", phoenix_flamingo, 1.6, {"head_glow": EMBER, "tail_glow": EMBER, "leg_bl_glow": EMBER, "leg_br_glow": EMBER}, "Phoenix Flamingo (mythic): Neon crest, flight feathers and tail streamers of flame."),
    F.asset("creature_flamingo_peacock", peacock_flamingo, 1.45, {"head_glow": JADE, "tail_glow": JADE}, "Peacock Flamingo (legendary): a fan of tail feathers with Neon eyes, a beaded crest."),
]
