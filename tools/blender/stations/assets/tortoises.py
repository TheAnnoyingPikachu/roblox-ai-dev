"""The tortoises (decisions 0055 and 0062), in the build of the rhinos (flat face tones under a surface
texture): the Tortoise, the Gemshell Tortoise and the Island Tortoise. A high domed shell covered in
plates that share their edges like a real tortoise's (five down the spine, four down each flank, one
over the neck and one over the tail, twenty-four round the rim), each raised in tiers; thick legs
splayed out to the sides, the forelegs armoured with scales; a ribbed neck, a broad horned head with a
hooked beak, a spiked tail, a pale belly.

Each tortoise makes its own plates (`p["plate"]`): horn with a keel of spikes and a spiked rim, cut gems
in gold settings, or mossy stone under a little island.

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
NECK = ((-0.9, 0.86, 0.4, 0.36, 0.34), (-1.15, 0.92, 0.34, 0.31, 0.29), (-1.38, 1.02, 0.38, 0.34, 0.31), (-1.6, 1.14, 0.31, 0.28, 0.27), (-1.8, 1.24, 0.35, 0.31, 0.29), (-1.98, 1.32, 0.29, 0.27, 0.27))
HEAD = ((-1.8, 1.3, 0.3, 0.26, 0.26), (-2.05, 1.38, 0.46, 0.36, 0.32), (-2.35, 1.4, 0.47, 0.34, 0.32), (-2.65, 1.36, 0.38, 0.25, 0.28), (-2.9, 1.31, 0.27, 0.16, 0.22), (-3.05, 1.27, 0.16, 0.08, 0.14))

AX, AY = 1.6, 2.0  # the shell's half width and half length where it is widest
SEAMS = (-0.7, -0.42, -0.14, 0.14, 0.42, 0.7)  # where the spine's plates meet, as shares of the half length
W_SEAM, W_MID = 0.17, 0.25  # a spine plate's half width at a seam and at its middle, as shares of the half width
EDGE, FOOT = 0.4, -0.3  # how high on the shell's side the flank's plates meet the rim's, and where the rim's end
RIM = 24  # plates round the rim


def out(az, el):
    """The direction `az` degrees round from the left (+X) towards the tail (+Y), `el` degrees up."""
    a, e = math.radians(az), math.radians(el)
    return Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))


def cells():
    """The shell's plates as (kind, outline). Neighbours share their corners, so the plates meet in
    grooves with no bare shell between. A corner is ("top", u, v): a point seen from above, as shares of
    the half width and half length; or ("side", degrees, rise): a point on the shell's side, that far
    round and that high."""
    mids = [(a + b) / 2 for a, b in zip(SEAMS, SEAMS[1:])]

    def edge(deg):
        return ("side", deg, EDGE)

    found = []
    for i, m in enumerate(mids):  # five six-sided plates down the spine
        a, b = SEAMS[i], SEAMS[i + 1]
        found.append(("spine", [("top", -W_SEAM, a), ("top", W_SEAM, a), ("top", W_MID, m), ("top", W_SEAM, b), ("top", -W_SEAM, b), ("top", -W_MID, m)]))
    for s in (1, -1):  # four down each flank, each above two of the rim's
        for j in range(4):
            lo, hi = -60 + j * 30, -30 + j * 30
            found.append(("flank", [("top", s * W_MID, mids[j]), ("top", s * W_SEAM, SEAMS[j + 1]), ("top", s * W_MID, mids[j + 1])] + [edge(d if s > 0 else 180 - d) for d in (hi, (lo + hi) / 2, lo)]))
    found.append(("end", [("top", -W_SEAM, SEAMS[0]), ("top", W_SEAM, SEAMS[0]), ("top", W_MID, mids[0])] + [edge(d) for d in (-60, -75, -90, -105, -120)] + [("top", -W_MID, mids[0])]))  # over the neck
    found.append(("end", [("top", W_SEAM, SEAMS[-1]), ("top", -W_SEAM, SEAMS[-1]), ("top", -W_MID, mids[-1])] + [edge(d) for d in (120, 105, 90, 75, 60)] + [("top", W_MID, mids[-1])]))  # over the tail
    step = 360 / RIM
    for i in range(RIM):
        found.append(("rim", [edge(i * step), edge((i + 1) * step), ("side", (i + 1) * step, FOOT), ("side", i * step, FOOT)]))
    return found


def on_shell(shell, corner):
    """Where a corner of a plate lies on the shell."""
    if corner[0] == "top":
        return k.land(shell, (corner[1] * AX, CENTRE.y + corner[2] * AY, 0), (0, 0, 1))[0]
    a = math.radians(corner[1])
    return k.land(shell, CENTRE, (AX * math.cos(a), AY * math.sin(a), corner[2]))[0]


def middle(shell, ring):
    """(the point on the shell under a plate's middle, the shell's normal there, the plate's size)."""
    mid = sum(ring, Vector()) / len(ring)
    at, n = k.land(shell, CENTRE, mid - CENTRE)
    return at, n, sum((q - mid).length for q in ring) / len(ring)


def scute(shell, ring, rows, tones, rng, **kw):
    """A plate over the patch of shell inside `ring` (its corners, on the shell), raised in tiers that
    follow the shell's curve: `rows` of (width, height) as shares of its size. tones: one for each tier's
    sides, then the top's."""
    mid = sum(ring, Vector()) / len(ring)
    size = sum((q - mid).length for q in ring) / len(ring)
    tiers = []
    for f, h in rows:
        tier = []
        for q in ring:
            at, n = k.land(shell, CENTRE, mid + (q - mid) * f - CENTRE)
            tier.append(at + n * h * size)
        tiers.append(tier)
    each = None if kw.get("m") else [t for t in tones[:-1] for _ in ring] + [tones[0], tones[-1]]
    return loft("plate", tiers, each, rng, **kw)


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

    # the shell: a dome over a flared rim, covered in plates; a pale belly under it
    shell = hide(loft("shell", [round_z(0, CENTRE.y, z, wx, wy, 14) for z, wx, wy in SHELL], T("shell"), rng, surface=p.get("dome", "horn")), T("shell"), 0.02)
    groups["body"].append(shell)
    count = {}
    for which, outline in cells():
        count[which] = count.get(which, 0) + 1
        p["plate"](groups, shell, which, count[which] - 1, [on_shell(shell, c) for c in outline], rng, glow)
    belly = tone(p.get("belly", (198, 180, 124)), kind)
    groups["body"].append(loft("belly", [round_z(0, CENTRE.y, 0.64, 1.12, 1.46, 14), round_z(0, CENTRE.y, 0.5, 0.98, 1.3, 14)], belly, rng, surface="horn"))

    # legs: thick scaly columns splayed out to the sides, bent at the knee, five claws on each broad
    # foot; the forelegs wear rows of big scales
    scale = tone(p.get("scale", tuple(min(255, c * 1.1 + 6) for c in p["skin"])), kind)
    for s, side in ((1, "l"), (-1, "r")):
        for front in (True, False):
            y, dy = (-0.5, -0.36) if front else (1.5, 0.3)
            name = ("leg_f" if front else "leg_b") + side
            axis = ((0.98, 0.0, 1.05, 0.42), (1.16, 0.3, 0.76, 0.37), (1.32, 0.62, 0.5, 0.41), (1.36, 0.86, 0.24, 0.35), (1.38, 1.0, 0.0, 0.48))  # out, along, height, radius
            leg = hide(loft("leg", [round_z(s * x, y + dy * t, z, r, r * 1.04, 8) for x, t, z, r in axis], skin, rng, surface="scales"), skin)
            groups[name].append(leg)
            for i in range(5):
                a = math.radians((-35 if front else 35) + (i - 2) * 24)  # fanned round the way the foot points
                d = Vector((s * math.cos(a), math.sin(a), 0))
                base = Vector((s * 1.38, y + dy, 0.1)) + d * 0.4
                groups[name].append(shard(base - d * 0.12 + Vector((0, 0, 0.07)), base + d * 0.3 - Vector((0, 0, 0.08)), 0.2, 0.17, claw, rng, face=(0, 0, 1), at=0.35, name="claw", emit=p.get("claw_emit", 0.0), surface="horn"))
            if front:
                for row, z in enumerate((0.84, 0.58, 0.33)):
                    x, t = 0.98 + (1.05 - z) * 0.38, (1.05 - z) / 1.05
                    for da in (-42, 0, 42) if row % 2 == 0 else (-21, 21):
                        a = math.radians(-35 + da)
                        at, n = k.land(leg, (s * x, y + dy * t, z), (s * math.cos(a), math.sin(a), 0.1))
                        hexagon = [(0.17 * math.cos(i * math.tau / 6), 0.17 * math.sin(i * math.tau / 6)) for i in range(6)]
                        groups[name].append(plate("scale", at, k._frame(n), hexagon, 0.06, scale, rng, lift=-0.01, surface="horn"))

    # the head on a ribbed neck: broad at the back, a heavy brow over each eye, two horns behind it and
    # one on each cheek, a hooked beak over a shorter lower one
    head = groups["head"]
    bone = tone(p.get("horn", F.BONE), F.PALE)
    head.append(hide(loft("neck", [oval(*r, 10) for r in NECK], skin, rng, surface="scales"), skin, 0.015))
    skull = hide(loft("skull", [oval(*r, 10) for r in HEAD], skin, rng, surface="scales"), skin, 0.02)
    head.append(skull)
    head.append(shard((0, -2.84, 1.36), (0, -3.32, 0.98), 0.38, 0.32, T("beak"), rng, face=(1, 0, 0), at=0.4, name="beak", surface="horn"))
    head.append(shard((0, -2.66, 1.1), (0, -3.1, 1.13), 0.27, 0.18, T("beak"), rng, face=(1, 0, 0), at=0.5, name="beak", surface="horn"))
    for s in (1, -1):
        at, n = k.land(skull, (s * 0.2, -2.5, 1.48), (s * 0.9, -0.35, 0.3))
        ex, ey, ez = k._frame(n)
        slit = [(-0.135, -0.047), (0.0, 0.074), (0.162, 0.06), (0.054, -0.054)]
        head.append(shard(at + Vector((0, 0.2, 0.11)), at + Vector((0, -0.24, 0.07)), 0.14, 0.1, skin, rng, face=n, name="brow"))
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.02, None, rng, lift=0.02, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.018, tone(p["iris"], F.WARM), rng, lift=0.02))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.034), (0.04, 0.0), (0.034, 0.047), (-0.005, 0.016)], 0.01, tone(F.INK), rng, lift=0.04))
        for centre, d, reach, width in (((s * 0.2, -2.02, 1.5), (s * 0.7, 0.3, 0.65), Vector((s * 0.2, 0.36, 0.3)), 0.22), ((s * 0.2, -2.04, 1.3), (s, 0.25, -0.1), Vector((s * 0.32, 0.3, 0.02)), 0.19)):
            at, n = k.land(skull, centre, d)
            head.append(shard(at - n * 0.04, at + reach, width, width * 0.8, bone, rng, face=(0, 0, 1), at=0.3, name="horn", surface="horn"))
        at, n = k.land(skull, (s * 0.07, -2.95, 1.33), (s * 0.4, -0.6, 0.7))
        head.append(plate("nostril", at, k._frame(n), [(-0.03, -0.02), (0.03, -0.02), (0.035, 0.02), (-0.02, 0.025)], 0.01, tone(F.INK), rng, lift=0.006))
        a, n = k.land(skull, (0, -2.92, 1.2), (s, -0.25, -0.3))
        b, _ = k.land(skull, (0, -2.3, 1.2), (s, 0, -0.3))
        head.append(shard(a + n * 0.015, b + n * 0.015, 0.06, 0.03, tone(p["claw"], kind), rng, face=n, name="mouth"))

    t0 = Vector((0, 2.42, 0.9))
    tip = t0 + Vector((0, 0.7, -0.45))
    groups["tail"].append(shard(t0 - Vector((0, 0.3, 0)), tip, 0.46, 0.4, skin, rng, face=(0, 0, 1), at=0.35, name="tail", surface="scales"))
    groups["tail"].append(shard(tip - Vector((0, 0.16, -0.08)), tip + Vector((0, 0.3, -0.1)), 0.17, 0.15, bone, rng, face=(0, 0, 1), at=0.3, name="spike", surface="horn"))

    if p.get("extra"):
        p["extra"](groups, dict(shell=shell, skull=skull, tail=tip), rng, glow)
    joints = {"head": (0, -1.05, 0.9), "leg_fl": (0.95, -0.5, 0.92), "leg_fr": (-0.95, -0.5, 0.92), "leg_bl": (0.95, 1.5, 0.92), "leg_br": (-0.95, 1.5, 0.92), "tail": (0, 2.3, 0.9)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


HORN = ((1.0, -0.12), (0.93, 0.08), (0.66, 0.24), (0.34, 0.33))  # a plate of horn: three tiers of growth


def horn_plate(groups, shell, which, i, ring, rng, glow):
    """A plate of horn, dark in its grooves and pale on top; a keel of bone spikes swept back down the
    spine, and a spike on every other plate of the rim."""
    groups["body"].append(scute(shell, ring, HORN, [tone(c, F.WARM) for c in ((66, 48, 34), (120, 90, 52), (176, 142, 82), (214, 186, 118))], rng, surface="horn"))
    at, n, size = middle(shell, ring)
    bone = tone(F.BONE, F.PALE)
    if which == "spine":
        lean = (n + Vector((0, 0.5, 0.15))).normalized()
        groups["body"].append(shard(at + n * 0.08, at + lean * (0.5 + 0.22 * math.sin(math.pi * (i + 0.5) / 5)), 0.36, 0.22, bone, rng, face=(1, 0, 0), at=0.3, name="keel", surface="horn"))
    elif which == "rim" and i % 2 == 0:
        lean = (n + Vector((0, 0, 0.35))).normalized()
        groups["body"].append(shard(at + n * 0.02, at + lean * 0.46, 0.26, 0.22, bone, rng, at=0.3, name="spike", surface="horn"))


def tortoise():
    """Tortoise: a war tortoise, olive and scaly, a high shell of horn plates with a spiked rim."""
    return tortoise_model(dict(skin=(112, 128, 78), shell=(58, 44, 32), claw=(56, 48, 38), beak=(92, 74, 48), iris=(244, 170, 36), plate=horn_plate), 3)


def gem_plate(groups, shell, which, i, ring, rng, glow):
    """A cut gem in a gold setting, the shape of its plate: rose down the spine (Neon) and on the flanks,
    rose and violet in turn round the rim, a gold bead at each corner of the rim's."""
    gold = tone((236, 180, 56), F.WARM)
    groups["body"].append(scute(shell, ring, ((1.0, -0.12), (0.96, 0.07), (0.8, 0.1)), (gold, gold, gold), rng))
    cut = ((0.8, 0.06), (0.74, 0.2), (0.44, 0.36), (0.2, 0.4))  # girdle, crown, table
    if which == "spine":
        groups["body_glow"].append(scute(shell, ring, cut, None, rng, m=glow))
        return
    rgb = (226, 40, 160) if which != "rim" or i % 2 else (150, 70, 240)
    deep, pale = tone(k.mix(rgb, (0, 0, 40), 0.3), GEM), tone(k.mix(rgb, (255, 255, 255), 0.4), GEM)
    groups["body"].append(scute(shell, ring, cut, (deep, tone(rgb, GEM), pale, pale), rng, emit=0.7, surface="gem"))
    if which == "rim":
        _, n, _ = middle(shell, ring)
        groups["body"].append(lump(ring[0] + n * 0.05, (0.09, 0.09, 0.09), gold, rng, surface=None))


def gemshell_tortoise():
    """Gemshell Tortoise (legendary): a midnight shell set with cut rose gems in gold, the spine's glowing;
    deep teal skin, gold claws and beak, glowing eyes."""
    return tortoise_model(
        dict(kind=F.COOL, skin=(40, 92, 104), shell=(40, 32, 70), claw=(236, 180, 56), claw_emit=0.3, beak=(236, 180, 56), glow=ROSE, glow_eyes=True, plate=gem_plate),
        7,
    )


def stone_plate(groups, shell, which, i, ring, rng, glow):
    """A plate of weathered stone under moss, and grass on top; vines hang from the rim."""
    stone, moss, grass = tone((126, 122, 108), F.COOL), tone((82, 124, 58), F.WARM), tone((126, 176, 72), F.WARM)
    groups["body"].append(scute(shell, ring, HORN, (stone, moss, grass, grass), rng, surface="rock"))
    if which == "rim" and i % 3 != 1:
        at, n, size = middle(shell, ring)
        for j in range(2):
            top = at + k._frame(n)[0] * (j - 0.5) * size * 0.9 + n * 0.06
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
