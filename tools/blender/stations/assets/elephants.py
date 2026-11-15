"""The elephants (decision 0051), in the faceted low-poly style of the lions (decision 0050): the
Elephant (the Titan), the Frost Mammoth and the War Elephant. A boxy body on four pillars of legs
with pale toenails, a tall head with flared plate ears, a ringed trunk of tapering blocks and curved
tusks. Every face has one flat colour, as on the lions; the hide's big faces are broken into facets
(`rough`), with folds of skin at the shoulders, hips, knees and ankles, so they do not look plain.

Jointed like every creature: body, head (with the trunk, ears and tusks), four legs, tail, and Neon
`_glow` pieces. Facing Blender -Y; left is +X.
"""

import math
import random

import facet as L
import kit as k
from mathutils import Vector

loft, yring, zring, quad, shard, plate, tone, rough = L.loft, L.yring, L.zring, L.quad, L.shard, L.plate, L.tone, L.rough

GREY = ((0.76, 0.76, 0.8), (1.12, 1.12, 1.14), (6, 6, 10))
FROSTY = ((0.74, 0.82, 0.94), (1.05, 1.05, 1.03), (6, 6, 4))  # the shadows of snow are blue
ICE = (120, 220, 255)
EMBER = (255, 150, 40)
HIND = 2.35  # how far behind the front legs the hind legs stand
EAR = [(0.0, 0.75), (0.75, 1.15), (1.5, 0.8), (1.75, 0.0), (1.4, -0.9), (0.6, -1.25), (0.0, -0.7)]  # (out, up)


def elephant_model(p, seed):
    """The elephant from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", GREY)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    body, fore, pale = T("body"), T("fore"), tone(p["nail"], L.PALE)
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "head_glow": [], "body_glow": [], "tail": []}

    # the torso: a deep barrel, highest over the shoulders (a mammoth has a hump there)
    hump = p.get("hump", 0.0)
    barrel = ((-1.75, 3.05, 1.0, 1.0, 1.05, 0.35), (-0.9, 3.1, 1.4, 1.45 + hump, 1.3, 0.45), (0.9, 3.05, 1.45, 1.35 + hump * 0.4, 1.3, 0.45), (2.6, 2.95, 1.35, 1.3, 1.2, 0.42), (3.45, 2.85, 0.95, 1.0, 0.9, 0.32))

    def girth(y):
        """The torso's section at depth y, between its rings: (zc, half width, up, down, cut)."""
        for a, b in zip(barrel, barrel[1:]):
            if a[0] <= y <= b[0]:
                u = (y - a[0]) / (b[0] - a[0])
                return tuple(a[i] + (b[i] - a[i]) * u for i in range(1, 6))
        raise ValueError(f"no torso at y = {y}")

    torso = rough(loft("torso", [yring(*r) for r in barrel], body, rng), body, rng)
    groups["body"].append(torso)
    for y in (-0.15, 1.9):  # a fold of skin behind the shoulders and before the hips
        zc, w, up, down, c = girth(y)
        groups["body"].append(loft("fold", [yring(y + dy, zc, w + 0.06, up + 0.06, down + 0.06, c) for dy in (-0.05, 0.05)], T("brow"), rng))

    # legs: pillars, the lower half lighter, a flared foot with three pale toenails
    for s in (1, -1):
        for front in (True, False):
            x, y = s * 0.85, (-0.5 if front else HIND)
            parts = [
                rough(loft("leg", [zring(x, y, 2.6, 0.55, 0.6, 0.15), zring(x, y, 1.3, 0.5, 0.54, 0.14)], body, rng), body, rng),
                rough(loft("shank", [zring(x, y, 1.35, 0.47, 0.5, 0.13), zring(x, y, 0.32, 0.5, 0.54, 0.13), zring(x, y - 0.04, 0.0, 0.58, 0.64, 0.14)], fore, rng), fore, rng),
            ]
            for z in (1.32, 0.42):  # creases at the knee and the ankle
                parts.append(loft("crease", [zring(x, y, z + dz, 0.57, 0.61, 0.15) for dz in (0.05, -0.05)], T("brow"), rng))
            for dx in (-0.32, 0.0, 0.32):
                parts.append(loft("nail", [quad(y - 0.6, 0.15, 0.13, 0.13, 0.15, x + dx), quad(y - 0.74, 0.12, 0.11, 0.08, 0.12, x + dx)], pale, rng))
            groups[("leg_f" if front else "leg_b") + ("l" if s > 0 else "r")] = parts

    # the head: a domed skull narrowing to the face, the trunk hanging from it in four bends
    skull = rough(loft("skull", [yring(*r) for r in ((-2.95, 3.35, 0.6, 0.7, 0.55, 0.2), (-2.6, 3.65, 0.9, 0.95, 0.85, 0.3), (-2.0, 3.75, 1.05, 1.1, 1.0, 0.34), (-1.3, 3.6, 0.95, 0.95, 0.9, 0.3))], body, rng), body, rng, 0.03)
    head = groups["head"]
    head.append(skull)
    bends = [zring(0, -2.9, 3.2, 0.5, 0.5, 0.14), zring(0, -3.25, 2.45, 0.44, 0.44, 0.12), zring(0, -3.4, 1.65, 0.36, 0.36, 0.1), zring(0, -3.35, 0.95, 0.29, 0.29, 0.08), zring(0, -3.65, 0.5, 0.24, 0.24, 0.07)]
    for i in range(4):  # ringed: every other segment a shade darker
        ring = body if i % 2 == 0 else T("brow")
        head.append(rough(loft("trunk", bends[i : i + 2], ring, rng), ring, rng, 0.03))
    size = p.get("ear", 1.0)
    for s in (1, -1):
        # ears: flat plates flared forward and out, a lighter inside
        fx, fy, fz = k._frame(Vector((s * 0.5, -1, 0)), (0, 0, 1))
        frame, at = (fx * s, fy, fz), Vector((s * 0.95, -1.75, 3.95))
        head.append(rough(plate("ear", at, frame, [(u * size, v * size) for u, v in EAR], 0.14, body, rng), body, rng, 0.03))
        head.append(rough(plate("ear", at + fz * 0.17, frame, [((0.16 + u * 0.72) * size, v * 0.72 * size) for u, v in EAR], 0.03, T("ear_in"), rng), T("ear_in"), rng, 0.01))
        # a heavy brow over a slit of an eye
        head.append(shard((s * 0.2, -2.95, 3.95), (s * 0.98, -2.45, 4.15), 0.36, 0.28, T("brow"), rng, face=(0, -1, 0.5), name="brow"))
        at, n = k.land(skull, (s * 0.6, -2.6, 3.8), (s * 0.75, -0.65, 0.1))
        ex, ey, ez = k._frame(n)
        slit = [(-0.26, -0.08), (0.03, 0.1), (0.31, 0.09), (0.08, -0.065)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.05, None, rng, lift=0.035, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.04, tone(p["iris"], L.WARM), rng, lift=0.035))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.06), (0.065, 0.0), (0.06, 0.09), (-0.005, 0.03)], 0.02, tone(L.INK), rng, lift=0.077))
        # a tusk: a curved four-sided horn through the palette's points, tapering to its tip
        path, radii = [Vector((s * x, y, z)) for x, y, z, _ in p["tusks"]], [r for _, _, _, r in p["tusks"]]
        if p.get("tusk_glow"):
            groups["head_glow"].append(k.tube(path, radii, m=glow, n=4, name="tusk"))
        else:
            head.append(L.colour(k.tube(path, radii, m=L.material(), n=4, name="tusk"), tone(p["tusk"], L.PALE), rng))

    # the tail: short, with a dark tuft
    t0, end = Vector((0, 3.4, 3.2)), Vector((0, 3.95, 2.0))
    tail = k.tube([t0, Vector((0, 3.85, 2.8)), end], [0.17, 0.13, 0.1], m=L.material(), n=4, name="tail")
    groups["tail"].append(L.colour(tail, body, rng))
    for i in range(3):
        d = Vector(((i - 1) * 0.35, 0.15, -1)).normalized()
        groups["tail"].append(shard(end - d * 0.1, end + d * 0.7, 0.3, 0.2, T("tuft"), rng, face=(0, 1, 0), at=0.4))

    extra = p.get("extra")
    if extra:
        extra(groups, torso, rng, glow, girth)
    joints = {"head": (0, -1.3, 3.5), "leg_fl": (0.85, -0.5, 2.3), "leg_fr": (-0.85, -0.5, 2.3), "leg_bl": (0.85, HIND, 2.3), "leg_br": (-0.85, HIND, 2.3), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def elephant():
    """Elephant (the Titan): blue-grey, wide ears, a heavy brow, a long trunk, pale tusks, amber eyes."""
    return elephant_model(
        dict(body=(118, 124, 140), fore=(136, 142, 158), nail=(230, 220, 196), ear_in=(176, 142, 152), brow=(96, 102, 118), iris=(244, 180, 40), tuft=(40, 40, 50),
             tusk=(242, 234, 210), tusks=[(0.55, -2.6, 3.0, 0.24), (0.72, -3.4, 2.72, 0.22), (0.86, -4.2, 2.78, 0.14), (0.86, -4.8, 3.15, 0.0)]),
        4,
    )


def frost_extra(groups, torso, rng, glow, girth):
    """A shaggy skirt of pale fur down both flanks, a mop on the crown, and ice down the back."""
    fur, tips = tone((122, 152, 198), FROSTY), tone((224, 236, 250), FROSTY)
    for s in (1, -1):
        for row, (z, long_) in enumerate(((3.25, 1.5), (2.5, 1.3))):
            for i in range(7):
                at, _ = k.land(torso, (0, -0.9 + i * 0.6 + row * 0.3, z), (s, 0, 0))
                d = Vector((s * 0.18, 0.1, -1)).normalized()
                groups["body"].append(shard(at - d * 0.2, at + d * long_ * rng.uniform(0.9, 1.1), 0.78, 0.3, (fur, tips), rng, face=(s, 0, 0), at=0.4, name="fur"))
    for i in range(5):
        x = (i - 2) * 0.4
        base = Vector((x, -2.3, 4.75 - abs(x) * 0.2))
        groups["head"].append(shard(base, base + Vector((x * 0.3, 0.9, 0.55)), 0.6, 0.3, (fur, tips), rng, face=(0, -0.3, 1), at=0.4, name="fur"))
    for i, h in enumerate((1.0, 1.5, 1.3, 1.0, 0.8, 0.6)):
        at, _ = k.land(torso, (0, -1.0 + i * 0.68, 3.0), (0, 0, 1))
        lean = Vector((rng.uniform(-0.12, 0.12), 0.3, 1)).normalized()
        groups["body_glow"].append(shard(at - lean * 0.25, at + lean * h, 0.3 + h * 0.3, 0.3, None, rng, face=(1, 0, 0), at=0.35, m=glow, name="ice"))


def frost_mammoth():
    """Frost Mammoth (mythic): pale and shaggy, a hump over the shoulders, small ears, huge curved tusks
    of glowing ice, ice spikes down its back, glowing eyes."""
    return elephant_model(
        dict(kind=FROSTY, body=(146, 174, 214), fore=(176, 198, 232), nail=(236, 244, 252), ear_in=(104, 132, 180), brow=(110, 138, 186), tuft=(90, 116, 164),
             hump=0.4, ear=0.62, glow=ICE, glow_eyes=True, tusk_glow=True, extra=frost_extra,
             tusks=[(0.6, -2.6, 3.0, 0.32), (1.0, -3.6, 2.3, 0.3), (1.25, -4.6, 2.25, 0.24), (1.05, -5.4, 3.1, 0.14), (0.65, -5.65, 4.0, 0.0)]),
        9,
    )


def war_extra(groups, torso, rng, glow, girth):
    """War gear: a red blanket with a gold hem, a wooden deck carrying a cannon over the head, a steel
    plate and a spike on the brow, gold caps on the tusks. The muzzle and the fuse glow."""
    steel, gold, red = tone((78, 84, 98), GREY), tone((226, 176, 60)), tone((172, 40, 40))
    wood, iron = tone((126, 88, 52)), tone((50, 52, 60), GREY)
    body, head = groups["body"], groups["head"]
    drape = [(y, *girth(y)) for y in (-0.75, 0.9, 2.3)]  # cut to the torso, a hand proud of its facets
    body.append(rough(loft("blanket", [yring(y, 3.75, w + 0.1, zc + up + 0.1 - 3.75, 0.95, c + 0.02) for y, zc, w, up, _, c in drape], red, rng), red, rng, 0.02))
    body.append(loft("hem", [yring(y, 2.86, w + 0.14, 0.08, 0.08, 0.03) for y, _, w, _, _, _ in drape], gold, rng))
    body.append(loft("deck", [yring(-0.55, 4.72, 0.95, 0.2, 0.3, 0.1), yring(2.05, 4.58, 0.95, 0.2, 0.3, 0.1)], wood, rng))
    for x in (-0.42, 0.42):  # the carriage's cheeks
        body.append(loft("cheek", [quad(1.5, 5.15, 0.1, 0.32, 0.3, x), quad(-0.3, 5.3, 0.1, 0.3, 0.3, x)], wood, rng))
    body.append(loft("barrel", [yring(y, z, r, r, r, r * 0.42) for y, z, r in ((1.55, 5.5, 0.4), (1.4, 5.5, 0.5), (0.6, 5.58, 0.46), (-1.7, 5.82, 0.36), (-1.85, 5.84, 0.45), (-2.05, 5.86, 0.45))], iron, rng))
    body.append(loft("band", [yring(0.3, 5.61, 0.5, 0.5, 0.5, 0.21), yring(0.1, 5.63, 0.5, 0.5, 0.5, 0.21)], gold, rng))
    bore = [(0.3 * math.cos(i * math.tau / 8), 0.3 * math.sin(i * math.tau / 8)) for i in range(8)]
    groups["body_glow"].append(plate("bore", Vector((0, -2.06, 5.86)), (Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))), bore, 0.03, None, rng, m=glow))
    groups["body_glow"].append(shard((0, 1.3, 5.95), (0.1, 1.5, 6.45), 0.16, 0.14, None, rng, m=glow, name="fuse"))
    head.append(loft("chamfron", [yring(-3.0, 3.5, 0.5, 0.6, 0.35, 0.18), yring(-2.66, 3.85, 0.72, 0.8, 0.45, 0.26), yring(-2.3, 4.3, 0.75, 0.62, 0.3, 0.3)], steel, rng))
    head.append(shard((0, -2.75, 4.45), (0, -3.5, 5.1), 0.32, 0.3, gold, rng, face=(1, 0, 0), at=0.3, name="spike"))
    for s in (1, -1):
        head.append(shard((s * 0.86, -4.25, 2.8), (s * 0.86, -4.95, 3.25), 0.3, 0.28, gold, rng, at=0.3, name="cap"))


def war_elephant():
    """War Elephant (legendary): a dark elephant in war gear with a cannon on its back, ember eyes."""
    return elephant_model(
        dict(body=(104, 100, 104), fore=(122, 118, 122), nail=(226, 214, 188), ear_in=(150, 116, 118), brow=(80, 78, 84), tuft=(30, 28, 32),
             tusk=(240, 230, 204), tusks=[(0.55, -2.6, 3.0, 0.24), (0.72, -3.4, 2.72, 0.22), (0.86, -4.2, 2.78, 0.14), (0.86, -4.8, 3.15, 0.0)], glow=EMBER, glow_eyes=True, extra=war_extra),
        6,
    )


ASSETS = [
    L.asset("creature_elephant", elephant, 2.76, {}, "Elephant, the Titan: a faceted blue-grey elephant with flared ears and pale tusks."),
    L.asset("creature_elephant_frost", frost_mammoth, 3.08, {"head_glow": ICE, "body_glow": ICE}, "Frost Mammoth (mythic Titan): pale and shaggy, Neon ice tusks and back spikes."),
    L.asset("creature_elephant_war", war_elephant, 2.99, {"head_glow": EMBER, "body_glow": EMBER}, "War Elephant (legendary Titan): war gear and a cannon on its back, a glowing muzzle."),
]
