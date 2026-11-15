"""The tortoises (decision 0055), in the build of the rhinos (flat face tones under a surface texture): the
Tortoise, the Gemshell Tortoise and the Island Tortoise. A high domed shell of six-sided plates, each a
mound in tiers (four down the spine, four down each flank, sixteen round the rim), on thick scaly legs
splayed out to the sides, a wrinkled neck, a blunt head with a hooked beak, a stub of a tail.

Each tortoise makes its own plates (`p["plate"]`): horn with a spiked rim, cut gems in gold settings,
or mossy stone under a little island.

Jointed like every creature: body, head, four legs, tail, and Neon `_glow` pieces. Facing Blender -Y;
left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Vector

loft, oval, round_z, shard, plate, tone, rough, lump = F.loft, F.oval, F.round_z, F.shard, F.plate, F.tone, F.rough, F.lump

GEM = ((0.5, 0.46, 0.66), (1.2, 1.2, 1.2), (36, 36, 36))  # a gem's dark faces stay coloured, its bright ones flash
ROSE = (255, 60, 190)
GOLD = (255, 206, 80)
PARTS = ("body", "head", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br")
CENTRE = Vector((0, 0.5, 1.0))  # the middle of the shell: its plates are placed by rays from here
# level sections of the shell as (height, half width, half length), and upright sections of the head
# as (depth, middle height, half width, up, down)
SHELL = ((0.6, 1.15, 1.5), (0.84, 1.62, 2.02), (1.0, 1.6, 2.0), (1.35, 1.45, 1.84), (1.75, 1.12, 1.46), (2.05, 0.7, 0.95), (2.2, 0.28, 0.4))
HEAD = ((-1.85, 1.31, 0.28, 0.27, 0.27), (-2.13, 1.38, 0.4, 0.36, 0.34), (-2.43, 1.36, 0.38, 0.3, 0.32), (-2.68, 1.3, 0.27, 0.19, 0.23), (-2.81, 1.26, 0.15, 0.09, 0.13))


def out(az, el):
    """The direction `az` degrees round from the left (+X) towards the tail (+Y), `el` degrees up."""
    a, e = math.radians(az), math.radians(el)
    return Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))


# the shell's plates as (kind, direction, size)
PLATES = (
    [("spine", out(90 if t > 0 else -90, 90 - abs(t)), 0.44) for t in (-57, -19, 19, 57)]
    + [("flank", out(az if s > 0 else 180 - az, 35), 0.45) for s in (1, -1) for az in (-57, -19, 19, 57)]
    + [("rim", out((i + 0.5) * 22.5, 1), 0.27) for i in range(16)]
)


def tiers(shell, d, size, rows, tones, rng, **kw):
    """A six-sided mound on the shell where the ray `d` from its middle meets it, in tiers: `rows` of (width,
    height) as shares of `size`. tones: one for each tier's sides, then the top's. Returns (it, where, normal)."""
    at, n = k.land(shell, CENTRE, d)
    ex, ey, ez = k._frame(n)
    rings = [[at + ez * h * size + (ex * math.cos(i * math.tau / 6) + ey * math.sin(i * math.tau / 6)) * f * size for i in range(6)] for f, h in rows]
    each = None if kw.get("m") else [t for t in tones[:-1] for _ in range(6)] + [tones[0], tones[-1]]
    return loft("plate", rings, each, rng, **kw), at, n


def tortoise_model(p, seed):
    """The tortoise from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", F.WARM)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    skin, claw = T("skin"), T("claw")
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {name: [] for name in PARTS}
    groups.update({name + "_glow": [] for name in PARTS})

    def hide(ob, tones, bulge=0.025):
        return rough(ob, tones, rng, bulge, 1.4)

    # the shell: a dome over a flared rim and a flat belly, and its plates
    shell = hide(loft("shell", [round_z(0, CENTRE.y, z, wx, wy, 14) for z, wx, wy in SHELL], T("shell"), rng, surface=p.get("dome", "horn")), T("shell"), 0.02)
    groups["body"].append(shell)
    for i, (which, d, size) in enumerate(PLATES):
        p["plate"](groups, shell, which, i, d, size, rng, glow)

    # legs: thick scaly columns splayed out to the sides, four claws on each foot
    for s, side in ((1, "l"), (-1, "r")):
        for front in (True, False):
            y, dy = (-0.5, -0.32) if front else (1.5, 0.28)
            name = ("leg_f" if front else "leg_b") + side
            groups[name].append(hide(loft("leg", [round_z(s * 0.95, y, 1.0, 0.36, 0.36, 8), round_z(s * 1.27, y + dy * 0.5, 0.5, 0.33, 0.35, 8), round_z(s * 1.36, y + dy, 0.0, 0.42, 0.44, 8)], skin, rng, surface="scales"), skin))
            for i in range(4):
                a = math.radians((-35 if front else 35) + (i - 1.5) * 30)  # fanned round the way the foot points
                d = Vector((s * math.cos(a), math.sin(a), 0))
                base = Vector((s * 1.36, y + dy, 0.1)) + d * 0.36
                groups[name].append(shard(base - d * 0.1 + Vector((0, 0, 0.06)), base + d * 0.24 - Vector((0, 0, 0.07)), 0.17, 0.15, claw, rng, face=(0, 0, 1), at=0.35, name="claw", emit=p.get("claw_emit", 0.0), surface="horn"))

    # the head on a wrinkled neck: blunt, a hooked beak, a heavy brow
    head = groups["head"]
    head.append(F.colour(k.tube([Vector((0, -1.0, 0.85)), Vector((0, -1.55, 0.95)), Vector((0, -1.98, 1.3))], [0.36, 0.3, 0.27], m=F.material(surface="scales"), n=8, name="neck"), skin, rng))
    skull = hide(loft("skull", [oval(*r, 10) for r in HEAD], skin, rng, surface="scales"), skin, 0.02)
    head.append(skull)
    head.append(shard((0, -2.63, 1.28), (0, -2.97, 1.02), 0.3, 0.26, T("beak"), rng, face=(1, 0, 0), at=0.4, name="beak", surface="horn"))
    for s in (1, -1):
        at, n = k.land(skull, (s * 0.2, -2.35, 1.46), (s * 0.9, -0.35, 0.3))
        ex, ey, ez = k._frame(n)
        slit = [(-0.1, -0.035), (0.0, 0.055), (0.12, 0.045), (0.04, -0.04)]
        head.append(shard(at + n * 0.02 + Vector((0, 0.14, 0.1)), at + n * 0.02 + Vector((0, -0.18, 0.06)), 0.1, 0.08, skin, rng, face=n, name="brow"))
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.02, None, rng, lift=0.02, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.018, tone(p["iris"], F.WARM), rng, lift=0.02))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.025), (0.03, 0.0), (0.025, 0.035), (-0.004, 0.012)], 0.01, tone(F.INK), rng, lift=0.04))
        a, n = k.land(skull, (0, -2.73, 1.22), (s, -0.25, -0.3))
        b, _ = k.land(skull, (0, -2.25, 1.22), (s, 0, -0.3))
        head.append(shard(a + n * 0.015, b + n * 0.015, 0.05, 0.03, tone(p["claw"], kind), rng, face=n, name="mouth"))

    t0 = Vector((0, 2.42, 0.9))
    groups["tail"].append(shard(t0 - Vector((0, 0.25, 0)), t0 + Vector((0, 0.62, -0.42)), 0.36, 0.32, skin, rng, face=(0, 0, 1), at=0.35, name="tail", surface="scales"))

    if p.get("extra"):
        p["extra"](groups, dict(shell=shell, skull=skull, tail=t0 + Vector((0, 0.62, -0.42))), rng, glow)
    joints = {"head": (0, -1.05, 0.9), "leg_fl": (0.95, -0.5, 0.92), "leg_fr": (-0.95, -0.5, 0.92), "leg_bl": (0.95, 1.5, 0.92), "leg_br": (-0.95, 1.5, 0.92), "tail": (0, 2.3, 0.9)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


HORN = ((1.0, -0.12), (0.93, 0.08), (0.66, 0.24), (0.34, 0.33))  # a plate of horn: three tiers of growth


def horn_plate(groups, shell, which, i, d, size, rng, glow):
    """A plate of horn, dark at its edge and pale on top; a bone spike on every other plate of the rim."""
    ob, at, n = tiers(shell, d, size, HORN, [tone(c, F.WARM) for c in ((84, 64, 42), (128, 100, 58), (176, 146, 84), (206, 180, 112))], rng, surface="horn")
    groups["body"].append(ob)
    if which == "rim" and i % 2 == 0:
        lean = (n + Vector((0, 0, 0.35))).normalized()
        groups["body"].append(shard(at - lean * 0.05, at + lean * 0.5, 0.26, 0.24, tone(F.BONE, F.PALE), rng, at=0.3, name="spike", surface="horn"))


def tortoise():
    """Tortoise: a war tortoise, olive and scaly, a high shell of horn plates with a spiked rim."""
    return tortoise_model(dict(skin=(120, 132, 84), shell=(74, 58, 40), claw=(56, 48, 38), beak=(88, 72, 48), iris=(240, 176, 40), plate=horn_plate), 3)


def gem_plate(groups, shell, which, i, d, size, rng, glow):
    """A cut gem in a gold setting: rose down the spine (Neon) and on the flanks, rose and violet in turn
    round the rim, a gold bead between the rim's gems."""
    gold = tone((236, 180, 56), F.WARM)
    setting, at, n = tiers(shell, d, size, ((1.0, -0.12), (0.96, 0.07), (0.8, 0.1)), (gold, gold, gold), rng)
    groups["body"].append(setting)
    cut = ((0.8, 0.06), (0.74, 0.2), (0.44, 0.36), (0.2, 0.4))  # girdle, crown, table
    if which == "spine":
        groups["body_glow"].append(tiers(shell, d, size, cut, None, rng, m=glow)[0])
        return
    rgb = (226, 40, 160) if which == "flank" or i % 2 else (150, 70, 240)
    deep, pale = tone(k.mix(rgb, (0, 0, 40), 0.3), GEM), tone(k.mix(rgb, (255, 255, 255), 0.4), GEM)
    groups["body"].append(tiers(shell, d, size, cut, (deep, tone(rgb, GEM), pale, pale), rng, emit=0.7, surface="gem")[0])
    if which == "rim":
        bead = at + k._frame(n)[0] * size * 1.15 + n * 0.02
        groups["body"].append(lump(bead, (0.09, 0.09, 0.09), gold, rng, surface=None))


def gemshell_tortoise():
    """Gemshell Tortoise (legendary): a midnight shell set with cut rose gems in gold, the spine's glowing;
    deep teal skin, gold claws and beak, glowing eyes."""
    return tortoise_model(
        dict(kind=F.COOL, skin=(40, 92, 104), shell=(40, 32, 70), claw=(236, 180, 56), claw_emit=0.3, beak=(236, 180, 56), glow=ROSE, glow_eyes=True, plate=gem_plate),
        7,
    )


def stone_plate(groups, shell, which, i, d, size, rng, glow):
    """A plate of weathered stone under moss, and grass on top; vines hang from the rim."""
    stone, moss, grass = tone((126, 122, 108), F.COOL), tone((82, 124, 58), F.WARM), tone((126, 176, 72), F.WARM)
    ob, at, n = tiers(shell, d, size, HORN, (stone, moss, grass, grass), rng, surface="rock")
    groups["body"].append(ob)
    if which == "rim" and i % 3 != 1:
        for j in range(2):
            top = at + k._frame(n)[0] * (j - 0.5) * size * 0.9 + n * 0.03
            groups["body"].append(shard(top + Vector((0, 0, 0.1)), top - Vector((0, 0, rng.uniform(0.3, 0.6))), 0.12, 0.05, moss, rng, face=n, at=0.3, name="vine"))


def island_extra(groups, pieces, rng, glow):
    """The island on its back: an acacia with a flat crown and glowing fruit, rocks, tufts of grass,
    glowing flowers; a sprout on its head."""
    shell, body = pieces["shell"], groups["body"]
    bark, leaf, dark_leaf, stone = tone((104, 74, 46), F.WARM), tone((96, 160, 62), F.WARM), tone((62, 122, 54), F.WARM), tone((140, 136, 124), F.COOL)
    root = Vector((0.1, 0.35, 2.3))
    fork = root + Vector((-0.1, 0.25, 1.05))
    body.append(F.colour(k.tube([root - Vector((0, 0, 0.2)), root + Vector((-0.14, 0.08, 0.5)), fork], [0.2, 0.14, 0.11], m=F.material(surface="horn"), n=6, name="trunk"), bark, rng))
    for end, r in ((Vector((0.75, -0.35, 0.55)), 0.75), (Vector((-0.8, 0.1, 0.5)), 0.7), (Vector((0.1, 0.85, 0.6)), 0.72), (Vector((0.0, 0.1, 0.8)), 0.6)):
        body.append(F.colour(k.tube([fork - Vector((0, 0, 0.05)), fork + end * 0.55, fork + end], [0.09, 0.07, 0.05], m=F.material(surface="horn"), n=5, name="branch"), bark, rng))
        body.append(lump(fork + end + Vector((0, 0, 0.1)), (r, r, 0.2), leaf if r > 0.65 else dark_leaf, rng, surface="scales"))
        for j in range(2):  # fruit hanging under the crown
            at = fork + end + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), -0.16))
            groups["body_glow"].append(shard(at, at - Vector((0, 0, 0.26)), 0.14, 0.14, None, rng, at=0.6, m=glow, name="fruit"))
    for d, size in ((out(-70, 62), 0.3), (out(150, 55), 0.36), (out(40, 66), 0.24), (out(-150, 48), 0.3)):  # rocks
        at, n = k.land(shell, CENTRE, d)
        body.append(lump(at + n * 0.12, (size, size * 1.2, size * 0.8), stone, rng))
    for i in range(14):  # tufts of grass, a glowing flower in some
        at, n = k.land(shell, CENTRE, out(rng.uniform(0, 360), rng.uniform(38, 80)))
        for j in range(3):
            lean = (n + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0.4))).normalized()
            body.append(shard(at + n * 0.08, at + n * 0.08 + lean * rng.uniform(0.25, 0.42), 0.09, 0.05, leaf, rng, face=(1, 0, 0), at=0.3, name="grass"))
        if i % 2 == 0:
            groups["body_glow"].append(shard(at + n * 0.2, at + n * 0.44, 0.15, 0.15, None, rng, m=glow, name="flower"))
    at, n = k.land(pieces["skull"], (0, -2.18, 1.36), (0, 0.1, 1))
    for dx in (-1, 1):  # the sprout: two leaves
        groups["head"].append(shard(at, at + Vector((dx * 0.22, 0.02, 0.3)), 0.16, 0.05, leaf, rng, face=(0, -1, 0.3), at=0.6, name="sprout"))
    groups["tail"].append(shard(pieces["tail"] - Vector((0, 0.1, 0)), pieces["tail"] + Vector((0, 0.3, 0.26)), 0.2, 0.06, leaf, rng, face=(0, 0, 1), at=0.6, name="leaf"))


def island_tortoise():
    """Island Tortoise (mythic): an ancient tortoise of mossy stone carrying an island: an acacia with
    glowing fruit, rocks, grass and glowing flowers; vines hang from its rim, a sprout grows on its head."""
    return tortoise_model(
        dict(kind=F.COOL, skin=(112, 128, 104), shell=(98, 94, 82), dome="rock", claw=(70, 66, 58), beak=(96, 90, 74), glow=GOLD, glow_eyes=True, plate=stone_plate, extra=island_extra),
        11,
    )


ASSETS = [
    F.asset("creature_tortoise", tortoise, 1.5, {}, "Tortoise: a war tortoise, a high shell of horn plates with a spiked rim."),
    F.asset("creature_tortoise_gemshell", gemshell_tortoise, 2.0, {"head_glow": ROSE, "body_glow": ROSE}, "Gemshell Tortoise (legendary): cut rose gems in gold settings, the spine's Neon."),
    F.asset("creature_tortoise_island", island_tortoise, 2.2, {"head_glow": GOLD, "body_glow": GOLD}, "Island Tortoise (mythic): mossy stone carrying an island, an acacia with Neon fruit."),
]
