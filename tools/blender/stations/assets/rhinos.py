"""The rhinos (decision 0054), after the lions, elephants, jackals and cheetahs: the Rhino, the Lava
Rhino and the Crystal Rhino. SHANNON's note with the cheetahs' go-ahead: the models need not be
low-poly, only not very detailed, so this family is rounder: a massive barrel of twelve-sided
sections with a high shoulder hump, round pillar legs under sleeves of armour, a short deep head with
a scimitar horn, and two raised plates of armour (shoulders and rump) with a fold of bare hide between
them. Every face still has one flat tone, and over the tones each piece carries a surface texture
(`facet.material`): leathery hide, rock, a crust of lava, gem, horn.

Jointed like every creature: body, head, four legs, tail, and Neon `_glow` pieces. Facing Blender -Y;
left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Matrix, Vector

loft, oval, round_z, quad, shard, plate, tone, rough, boulder = F.loft, F.oval, F.round_z, F.quad, F.shard, F.plate, F.tone, F.rough, F.lump

SLATE = ((0.78, 0.78, 0.82), (1.1, 1.1, 1.12), (6, 6, 10))
STONE = ((0.64, 0.64, 0.7), (1.2, 1.19, 1.16), (10, 10, 8))  # rock: shadow and light far apart, so every chip reads
GEM = ((0.5, 0.46, 0.66), (1.2, 1.2, 1.2), (36, 36, 36))  # a gem's dark faces stay coloured, its bright ones flash
LAVA = (255, 84, 12)
GEMS = dict(ruby=(226, 30, 66), citrine=(255, 122, 30), topaz=(255, 190, 40), emerald=(24, 190, 100), aqua=(50, 214, 226), sapphire=(40, 96, 236), amethyst=(158, 82, 240), rose=(255, 110, 186), diamond=(214, 236, 255))
PARTS = ("body", "head", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br")
HIND = 1.9  # how far behind the front legs the hind legs stand
FADE = 2.6  # the hide darkens below this height
DROP = 0.35  # the body, head and tail are written for long legs and lowered by this: a rhino is slung low
# sections as (depth, middle height, half width, up, down): the barrel, and the head (short and deep)
BARREL = ((-1.55, 2.45, 0.8, 0.85, 0.8), (-0.7, 2.45, 1.2, 1.3, 1.05), (0.6, 2.35, 1.25, 1.05, 1.1), (1.9, 2.35, 1.2, 1.05, 1.0), (2.7, 2.3, 0.9, 0.85, 0.8), (3.0, 2.25, 0.5, 0.5, 0.45))
HEAD = ((-1.3, 2.5, 0.66, 0.66, 0.64), (-1.85, 2.42, 0.66, 0.64, 0.64), (-2.35, 2.28, 0.6, 0.54, 0.6), (-2.75, 2.14, 0.56, 0.47, 0.54), (-3.02, 2.05, 0.52, 0.4, 0.48), (-3.2, 1.98, 0.42, 0.28, 0.36))


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


def chip(ob, rng, amount):
    """Knocks every point of `ob` in or out a little: hewn rock, not a turned shape."""
    for v in ob.data.vertices:
        v.co += v.normal * rng.uniform(-amount, amount)
    return ob


def rhino_model(p, seed):
    """The rhino from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", SLATE)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    hide_t, plate_t, legs_t = T("hide"), T("plate"), T("legs")
    skin, shell = p.get("skin", "hide"), p.get("shell", "hide")  # the surfaces of the bare hide and of the armour
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {name: [] for name in PARTS}
    groups.update({name + "_glow": [] for name in PARTS})
    pieces = {}

    def hide(ob, tones, bulge=0.03):
        if p.get("chip"):
            chip(ob, rng, p["chip"])
        return rough(ob, tones, rng, bulge * p.get("bulge", 1.0), FADE)

    def horn(points, radii, name):
        """A curved horn: of bone, or glowing. The Crystal Rhino grows its own."""
        if p["horn"] == "glow":
            groups["head_glow"].append(k.horn(points, radii, glow, n=8, steps=8, name=name))
        elif p["horn"]:
            groups["head"].append(F.colour(k.horn(points, radii, F.material(surface="horn"), n=8, steps=8, name=name), tone(p["horn"], F.PALE), rng))

    # the body: the barrel, and a plate of armour over the shoulders and another over the rump
    torso = hide(loft("torso", [oval(*r) for r in BARREL], hide_t, rng, surface=skin), hide_t)
    shoulder = hide(loft("shoulder", armour((-1.3, -0.7, 0.1), 0.08), plate_t, rng, surface=shell), plate_t, 0.025)
    rump = hide(loft("rump", armour((0.45, 1.2, 1.9, 2.65), 0.08), plate_t, rng, surface=shell), plate_t, 0.025)
    groups["body"] += [torso, shoulder, rump]
    pieces.update(torso=torso, shoulder=shoulder, rump=rump)

    # legs: round pillars under a sleeve of armour, a flared foot with three pale nails
    for s in (1, -1):
        for front in (True, False):
            x, y = s * 0.72, (-0.6 if front else HIND)
            top = (0.52, 0.62) if front else (0.56, 0.74)
            name = ("leg_f" if front else "leg_b") + ("l" if s > 0 else "r")

            def around(z, proud, x=x, y=y, top=top):
                """The upper leg's section at height z, `proud` of it."""
                u = (z - 0.85) / (2.0 - DROP - 0.85)
                return round_z(x, y, z, 0.46 + (top[0] - 0.46) * u + proud, 0.52 + (top[1] - 0.52) * u + proud)

            pieces[name] = hide(loft("sleeve", [around(1.75, 0.07), around(1.08, 0.09), around(0.97, 0.02)], plate_t, rng, surface=shell), plate_t, 0.02)
            groups[name] += [
                hide(loft("leg", [around(2.0 - DROP, 0), around(0.85, 0)], hide_t, rng, surface=skin), hide_t, 0.02),
                pieces[name],
                hide(loft("shank", [round_z(x, y, 0.9, 0.44, 0.5), round_z(x, y, 0.3, 0.45, 0.5), round_z(x, y - 0.03, 0.0, 0.55, 0.62)], legs_t, rng, surface=skin), legs_t, 0.02),
            ]
            for dx in (-0.3, 0.0, 0.3):  # the outer two sit back round the foot
                at = y - 0.5 + abs(dx) * 0.3
                nail = [oval(at, 0.17, 0.14, 0.17, 0.17, 8, x + dx, 2.0), oval(at - 0.15, 0.13, 0.12, 0.11, 0.13, 8, x + dx, 2.0), oval(at - 0.21, 0.09, 0.07, 0.05, 0.09, 8, x + dx, 2.0)]
                groups[name].append(loft("nail", nail, T("nail"), rng, emit=p.get("nail_emit", 0.0), surface=p.get("nail_surface", "horn")))

    # the head: short, deep and carried low, a blunt muzzle, small ears, a scimitar of a horn on the nose
    # and a short one behind it
    skull = hide(loft("skull", [oval(*r) for r in HEAD], hide_t, rng, surface=skin), hide_t, 0.02)
    pieces["skull"] = skull
    head = groups["head"]
    head.append(skull)
    horn([(0, -2.85, 2.4), (0, -3.08, 3.05), (0, -2.95, 3.7), (0, -2.6, 4.2)], [0.3, 0.23, 0.13, 0.0], "horn")
    horn([(0, -2.3, 2.7), (0, -2.37, 3.15), (0, -2.23, 3.48)], [0.2, 0.12, 0.0], "horn")
    dark = tone(p["dark"], kind)
    for s in (1, -1):
        nose, n = k.land(skull, (s * 0.2, -3.05, 2.05), (s * 0.5, -1, 0.6))
        head.append(plate("nostril", nose, k._frame(n), [(-0.07, -0.04), (0.07, -0.04), (0.09, 0.03), (-0.05, 0.05)], 0.012, dark, rng, lift=0.025))
        a, n = k.land(skull, (0, -3.1, 1.75), (s, -0.25, -0.3))
        b, _ = k.land(skull, (0, -2.45, 1.82), (s, 0, -0.3))
        head.append(shard(a + n * 0.02, b + n * 0.02, 0.07, 0.04, dark, rng, face=n, name="mouth"))
        head.append(shard((s * 0.42, -1.75, 2.9), (s * 0.68, -1.6, 3.55), 0.36, 0.2, hide_t, rng, at=0.45, name="ear", surface=skin))
        at, n = k.land(skull, (s * 0.4, -2.0, 2.52), (s * 0.85, -0.45, 0.25))
        if p.get("brow", True):  # a heavy brow, low towards the nose: a scowl
            head.append(shard(at + n * 0.05 + Vector((0, 0.26, 0.24)), at + n * 0.05 + Vector((0, -0.3, 0.1)), 0.2, 0.16, plate_t, rng, face=n, name="brow", surface=shell))
        ex, ey, ez = k._frame(n)
        slit = [(-0.15, -0.05), (0.01, 0.065), (0.18, 0.06), (0.06, -0.045)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (ex * s, ey, ez), slit, 0.03, None, rng, lift=0.025, m=glow))
        else:
            head.append(plate("eye", at, (ex * s, ey, ez), slit, 0.025, tone(p["iris"], F.WARM), rng, lift=0.025))
            head.append(plate("pupil", at, (ex * s, ey, ez), [(0.0, -0.035), (0.04, 0.0), (0.035, 0.05), (-0.004, 0.017)], 0.012, tone(F.INK), rng, lift=0.052))

    # the tail: short and thin, with a tuft
    t0, end = Vector((0, 2.95, 2.7)), Vector((0, 3.45, 1.55))
    tail = k.tube([t0, Vector((0, 3.35, 2.3)), end], [0.13, 0.1, 0.08], m=F.material(surface=skin), n=6, name="tail")
    groups["tail"].append(F.colour(tail, hide_t, rng))
    pieces["tail_end"] = end
    if p["tuft"] == "flame":
        for i in range(5):
            d = Vector(((i - 2) * 0.22, 0.35 + 0.1 * (i % 2), 0.9 - 0.15 * abs(i - 2))).normalized()
            groups["tail_glow"].append(shard(end - d * 0.1, end + d * (0.9 - 0.1 * abs(i - 2)), 0.3, 0.2, None, rng, face=(0, 1, 0), at=0.35, m=glow, name="flame"))
    elif p["tuft"]:
        for i in range(3):
            d = Vector(((i - 1) * 0.35, 0.15, -1)).normalized()
            groups["tail"].append(shard(end - d * 0.1, end + d * 0.6, 0.26, 0.18, T("tuft"), rng, face=(0, 1, 0), at=0.4, name="tuft"))

    p["extra"](groups, pieces, rng, glow)
    for name, parts in groups.items():  # slung low on its short legs
        if not name.startswith("leg"):
            for ob in parts:
                ob.data.transform(Matrix.Translation((0, 0, -DROP)))
    joints = {"head": (0, -1.4, 2.5 - DROP), "leg_fl": (0.72, -0.6, 1.9 - DROP), "leg_fr": (-0.72, -0.6, 1.9 - DROP), "leg_bl": (0.72, HIND, 1.9 - DROP), "leg_br": (-0.72, HIND, 1.9 - DROP), "tail": (0, t0.y, t0.z - DROP)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def crack(target, into, points, s, rng, glow, width=0.14, tones=None, **kw):
    """A jagged line across a plate, following its curve: shards end to end through `points` (depth,
    height). Glowing (a crack of lava), or painted in `tones` (a scar, a vein of gem)."""
    landed = []
    for y, z in points:
        at, n = k.land(target, (0, y, z), (s, 0, 0.3))
        landed.append(at + n * 0.03)
    for a, b in zip(landed, landed[1:]):
        into.append(shard(a, b, width, 0.06, tones, rng, face=(s, 0, 0.3), m=None if tones else glow, name="crack", **kw))


def war_extra(groups, pieces, rng, glow):
    """Bone studs on the shoulder plate and three claw scars across the rump."""
    bone = tone((226, 214, 186), F.PALE)
    for s in (1, -1):
        for row, tilt in enumerate((0.25, 0.75)):
            for i in range(3):
                at, n = k.land(pieces["shoulder"], (0, -1.05 + i * 0.42 + row * 0.2, 2.6), (s * tilt, 0, 1 - tilt * 0.6))
                groups["body"].append(shard(at - n * 0.06, at + n * 0.3, 0.26, 0.26, bone, rng, at=0.3, name="stud", surface="horn"))
    for i in range(3):  # on its right flank
        scar = k.vein(pieces["rump"], [((0, 1.05 + i * 0.3 + j * 0.17, 3.05 - j * 0.24), (-1, 0, 0.3)) for j in range(5)], 0.06, F.material(), lift=0.0, name="scar")
        groups["body"].append(F.colour(scar, tone((216, 178, 170), F.PALE), rng))


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
    """Lava in the folds between the plates, in cracks across them and round each knee, rock spikes with
    hot tips down the back, a crown of two rock horns."""
    rock, hot = tone((58, 46, 44), SLATE), tone((255, 132, 30), F.FIRE)
    for y in (-1.42, 0.27, 2.82):
        groups["body_glow"].append(band(y, 0.03, "seam", None, rng, m=glow))
    for s in (1, -1):
        crack(pieces["shoulder"], groups["body_glow"], ((-1.1, 3.3), (-0.8, 2.95), (-0.95, 2.65), (-0.55, 2.35), (-0.7, 2.1)), s, rng, glow)
        crack(pieces["shoulder"], groups["body_glow"], ((-0.3, 3.2), (-0.1, 2.85), (-0.3, 2.55)), s, rng, glow, 0.11)
        crack(pieces["rump"], groups["body_glow"], ((0.8, 3.1), (1.1, 2.8), (0.95, 2.5), (1.35, 2.2)), s, rng, glow)
        crack(pieces["rump"], groups["body_glow"], ((1.9, 3.1), (2.15, 2.75), (2.0, 2.45), (2.3, 2.15)), s, rng, glow, 0.11)
        groups["head"].append(shard((s * 0.34, -2.1, 2.8), (s * 0.6, -1.9, 3.6), 0.3, 0.26, (rock, hot), rng, at=0.3, name="crown", emit=0.5, surface="rock"))
        for front in (True, False):
            x, y = s * 0.72, (-0.6 if front else HIND)
            name = ("leg_f" if front else "leg_b") + ("l" if s > 0 else "r")
            groups[name + "_glow"].append(loft("seam", [round_z(x, y, 0.95, 0.5, 0.56), round_z(x, y, 0.84, 0.5, 0.56)], None, rng, m=glow))
    for i, h in enumerate((0.7, 1.0, 0.85, 0.6, 0.8, 0.95, 0.7, 0.5)):
        y = -1.1 + i * 0.5
        piece = pieces["shoulder"] if y < 0.1 else pieces["rump"] if y > 0.45 else pieces["torso"]
        at, _ = k.land(piece, (0, y, 2.5), (0, 0, 1))
        lean = Vector((rng.uniform(-0.12, 0.12), 0.35, 1)).normalized()
        groups["body"].append(shard(at - lean * 0.15, at + lean * h, 0.5, 0.42, (rock, hot), rng, face=(1, 0, 0), at=0.5, name="spike", emit=0.5, surface="rock"))


def lava_rhino():
    """Lava Rhino (mythic): obsidian plates with lava in their cracks, lava in the folds between them and
    round the knees, molten horns, rock spikes with hot tips down the back, a burning tail, glowing eyes."""
    return rhino_model(
        dict(hide=(70, 42, 36), plate=(44, 36, 40), legs=(56, 40, 40), nail=(255, 150, 60), nail_emit=0.6, horn="glow", glow=LAVA, glow_eyes=True, tuft="flame", dark=(20, 16, 18), skin="rock", shell="crust", extra=lava_extra),
        9,
    )


def crystal(base, tip, radius, rgb, rng, m=None):
    """A six-sided crystal from `base` to a point at `tip`: deep in colour at the root, pale at the point,
    lit from within. With `m` (a glow material) it is left unpainted."""
    b, t = Vector(base), Vector(tip)
    axis = t - b
    side = axis.cross(Vector((0.31, 0.17, 1.0)))
    if side.length < 1e-4:
        side = axis.cross(Vector((1, 0, 0)))
    side.normalize()
    fore = side.cross(axis).normalized()
    turn = rng.uniform(0, math.tau)

    def ring(at, r):
        return [b + axis * at + (side * math.cos(turn + i * math.tau / 6) + fore * math.sin(turn + i * math.tau / 6)) * r for i in range(6)]

    verts = ring(0.0, radius * 0.8) + ring(rng.uniform(0.6, 0.8), radius) + [t]
    faces = [(i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i) for i in range(6)] + [(6 + i, 6 + (i + 1) % 6, 12) for i in range(6)] + [tuple(range(6))[::-1]]
    if m:
        return F.mesh("crystal", verts, faces, None, rng, m=m)
    deep, pale = tone(k.mix(rgb, (0, 0, 40), 0.3), GEM), tone(k.mix(rgb, (255, 255, 255), 0.35), GEM)
    return F.mesh("crystal", verts, faces, [deep] * 6 + [pale] * 6 + [deep], rng, emit=0.7, chance=0.5, surface="gem")


def spray(at, n, into, sizes, colours, rng, heart=None, glow=None):
    """A cluster of crystals growing from the point `at` along `n`: the first stands straight (Neon, in the
    group `heart`, when one is given), the others lean out round it, in `colours` in turn."""
    n = Vector(n).normalized()
    side = n.cross(Vector((0, 1, 0)))
    side = (side if side.length > 1e-3 else Vector((1, 0, 0))).normalized()
    fore = n.cross(side).normalized()
    for i, size in enumerate(sizes):
        a = i * 2.4 + rng.uniform(-0.3, 0.3)  # the golden angle: no two lean the same way
        out = side * math.cos(a) + fore * math.sin(a)
        d = n if i == 0 else (n + out * rng.uniform(0.45, 0.85)).normalized()
        base = Vector(at) + (out * (0.14 + size * 0.14) if i else Vector())
        if i == 0 and heart is not None:
            heart.append(crystal(base - d * 0.15, base + d * size, 0.05 + size * 0.14, None, rng, m=glow))
        else:
            into.append(crystal(base - d * 0.15, base + d * size, 0.05 + size * 0.14, colours[i % len(colours)], rng))


def cluster(target, centre, direction, *a, lean=(0, 0, 0), rubble=None, **kw):
    """A `spray` of crystals growing out of the surface of `target`, leaning by `lean`. rubble (tones,
    count): lumps of rock round its root."""
    at, n = k.land(target, centre, direction)
    n = (n + Vector(lean)).normalized()
    spray(at, n, *a, **kw)
    if rubble:
        into, rng = a[0], a[3]
        side = n.cross(Vector((0.2, 1, 0.1))).normalized()
        for i in range(rubble[1]):
            turn = i * math.tau / rubble[1] + rng.uniform(-0.3, 0.3)
            out = side * math.cos(turn) + n.cross(side) * math.sin(turn)
            into.append(boulder(at + out * rng.uniform(0.38, 0.6) - n * 0.05, [rng.uniform(0.16, 0.28) for _ in range(3)], rubble[0], rng))


def crystal_extra(groups, pieces, rng, glow):
    """Living rock grown through with gemstones of every colour: great clusters on the shoulder hump and
    the rump, a ridge of them down the spine, clusters on each shoulder, haunch and knee, veins of gem
    across the plates, gems studding the hide, lumps of rock along the plates' edges and over the eyes,
    horns of crystal, a mace of crystals for a tail."""
    G = GEMS
    body, hearts, head = groups["body"], groups["body_glow"], groups["head"]
    stone, pale = tone((132, 128, 132), STONE), tone((160, 156, 156), STONE)
    shoulder, rump, skull = pieces["shoulder"], pieces["rump"], pieces["skull"]

    # the spine: the great cluster on the hump (its tallest crystal Neon), the rump's, and a ridge between
    cluster(shoulder, (0, -0.65, 2.6), (0, 0, 1), body, (1.9, 1.15, 1.0, 1.25, 0.9, 1.05, 0.8, 0.7), (G["amethyst"], G["sapphire"], G["rose"], G["aqua"], G["amethyst"], G["diamond"]), rng, hearts, glow, rubble=(stone, 7))
    cluster(rump, (0, 1.8, 2.6), (0, 0, 1), body, (1.4, 0.9, 1.0, 0.8, 0.95, 0.7), (G["emerald"], G["emerald"], G["topaz"], G["aqua"], G["emerald"], G["citrine"]), rng, hearts, glow, rubble=(pale, 6))
    for y, size, rgb in ((-1.25, 0.6, G["rose"]), (0.25, 0.75, G["topaz"]), (0.75, 0.95, G["citrine"]), (1.15, 0.7, G["ruby"]), (2.45, 0.7, G["sapphire"]), (2.75, 0.5, G["aqua"])):
        at, _ = k.land(shoulder if -1.3 < y < 0.1 else rump if 0.45 < y < 2.65 else pieces["torso"], (0, y, 2.5), (0, 0, 1))
        lean = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.1, 0.3), 1)).normalized()
        body.append(crystal(at - lean * 0.15, at + lean * size, 0.07 + size * 0.13, rgb, rng))

    for s, fore, aft in ((1, (G["ruby"], G["citrine"], G["rose"]), (G["sapphire"], G["aqua"], G["amethyst"])), (-1, (G["sapphire"], G["aqua"], G["diamond"]), (G["ruby"], G["rose"], G["topaz"]))):
        # a cluster on each shoulder and haunch, a vein of gem across each plate, gems studding the hide
        cluster(shoulder, (0, -0.45, 2.95), (s, 0, 0.45), body, (1.05, 0.7, 0.75, 0.6, 0.5), fore, rng, rubble=(pale, 5))
        cluster(rump, (0, 1.85, 2.8), (s, 0, 0.4), body, (0.9, 0.6, 0.65, 0.5), aft, rng, rubble=(stone, 5))
        for target, points, rgb in (  # thin veins of gem in the plates
            (shoulder, ((-1.15, 2.95), (-0.95, 2.7), (-1.05, 2.4), (-0.8, 2.15), (-0.9, 1.9)), G["emerald"]),
            (rump, ((0.75, 3.0), (1.0, 2.75), (0.85, 2.45), (1.15, 2.2), (1.05, 1.95)), G["amethyst"]),
            (rump, ((2.3, 2.9), (2.45, 2.6), (2.3, 2.35), (2.5, 2.1)), G["topaz"]),
        ):
            line = k.vein(target, [((0, y, z), (s, 0, 0.3)) for y, z in points], 0.05, F.material(1.2, "gem"), lift=0.0, name="vein")
            body.append(F.colour(line, tone(rgb, GEM), rng, 0.4))
        for target, y, z in ((shoulder, -0.3, 2.4), (shoulder, 0.0, 1.95), (rump, 1.4, 2.5), (rump, 2.05, 2.05), (rump, 0.6, 2.05), (pieces["torso"], 0.27, 2.45), (pieces["torso"], -1.45, 2.0)):
            cluster(target, (0, y, z), (s, 0, 0.15), body, (rng.uniform(0.4, 0.55), 0.32, 0.26), rng.sample(list(G.values()), 3), rng, lean=(0, 0, 0.5))
        for y in (-1.2, -0.6, 0.0, 0.55, 1.2, 1.9, 2.5):  # hewn lumps along the plates' lower edges
            at, n = k.land(shoulder if y < 0.2 else rump, (0, y, 1.92), (s, 0, -0.1))
            body.append(boulder(at - n * 0.08, (rng.uniform(0.2, 0.3), rng.uniform(0.26, 0.38), rng.uniform(0.2, 0.3)), rng.choice((stone, pale)), rng))

        # the head: a lump of rock for a brow with gems behind it, a gem on the cheek
        at, n = k.land(skull, (s * 0.4, -2.0, 2.52), (s * 0.85, -0.45, 0.25))
        head.append(boulder(at + n * 0.02 + Vector((0, 0.02, 0.2)), (0.14, 0.34, 0.12), stone, rng))
        cluster(skull, (0, -1.95, 2.9), (s * 0.7, 0.1, 1), head, (0.55, 0.38, 0.32), (G["aqua"], G["rose"], G["topaz"]) if s > 0 else (G["rose"], G["aqua"], G["emerald"]), rng)
        at, n = k.land(skull, (0, -2.45, 2.05), (s, -0.1, -0.1))
        head.append(crystal(at - n * 0.08, at + n * 0.22, 0.13, G["citrine"] if s > 0 else G["emerald"], rng))

        # the legs: a cluster on each knee, its tallest crystal Neon in the leg's own colour, and gems in the sleeve
        for front in (True, False):
            x, y = s * 0.72, (-0.6 if front else HIND)
            name = ("leg_f" if front else "leg_b") + ("l" if s > 0 else "r")
            cluster(pieces[name], (x, y, 1.3), (s, -0.25 if front else 0.25, 0.2), groups[name], (0.62, 0.42, 0.38, 0.32), fore if front else aft, rng, groups[name + "_glow"], glow, lean=(0, 0, 0.9))
            for dy, z in ((-0.3, 1.45), (0.3, 1.3)):
                at, n = k.land(pieces[name], (x, y + dy, z), (s, dy, 0.1))
                groups[name].append(crystal(at - n * 0.06, at + n * 0.2, 0.11, rng.choice(list(G.values())), rng))

    # horns of crystal: a great Neon one on the nose with small ones round its root, and a rose one behind
    groups["head_glow"].append(crystal((0, -2.85, 2.3), (0, -3.12, 4.35), 0.3, None, rng, m=glow))
    for dx, dy, rgb, size in ((0.3, 0.12, G["sapphire"], 0.7), (-0.3, 0.1, G["amethyst"], 0.62), (0.16, -0.26, G["aqua"], 0.45), (-0.17, -0.25, G["diamond"], 0.5), (0.0, 0.3, G["sapphire"], 0.55)):
        d = Vector((dx * 1.6, dy * 1.6 - 0.1, 1)).normalized()
        head.append(crystal(Vector((dx, -2.85 + dy, 2.35)), Vector((dx, -2.85 + dy, 2.5)) + d * size, 0.07 + size * 0.11, rgb, rng))
    head.append(crystal((0, -2.3, 2.65), (0, -2.2, 3.6), 0.2, G["rose"], rng))
    for dx, rgb in ((0.2, G["ruby"]), (-0.2, G["amethyst"])):
        head.append(crystal((dx, -2.3, 2.65), (dx * 2.6, -2.15, 3.15), 0.11, rgb, rng))

    # the tail: a mace of crystals, the middle one Neon
    spray(pieces["tail_end"] + Vector((0, -0.03, 0.08)), (0, 0.5, -0.8), groups["tail"], (0.85, 0.5, 0.55, 0.45, 0.5), (G["emerald"], G["aqua"], G["topaz"], G["rose"], G["sapphire"]), rng, groups["tail_glow"], glow)


# deep colours: Neon washes a pale one out to white
CRYSTAL_GLOW = dict(head_glow=(40, 190, 255), body_glow=(160, 60, 255), tail_glow=(30, 235, 120), leg_fl_glow=(255, 40, 90), leg_fr_glow=(50, 110, 255), leg_bl_glow=(255, 170, 20), leg_br_glow=(255, 70, 190))


def crystal_rhino():
    """Crystal Rhino (legendary): living rock grown through with gemstones of every colour, horns and a
    tail of crystal, glowing eyes."""
    return rhino_model(
        dict(kind=STONE, hide=(92, 90, 100), plate=(124, 120, 124), legs=(106, 104, 114), nail=GEMS["diamond"], nail_emit=0.5, nail_surface="gem", horn=None, glow=CRYSTAL_GLOW["body_glow"], glow_eyes=True, tuft=None, brow=False, dark=(40, 38, 46), skin="rock", shell="rock", chip=0.035, bulge=2.4, extra=crystal_extra),
        13,
    )


ASSETS = [
    F.asset("creature_rhino", rhino, 2.02, {}, "Rhino: a massive slate war rhino, armour plates with bone studs, a scimitar horn."),
    F.asset("creature_rhino_lava", lava_rhino, 2.59, {name + "_glow": LAVA for name in PARTS}, "Lava Rhino (mythic): obsidian plates with lava in their cracks, Neon lava in the folds and round the knees, molten horns, a burning tail."),
    F.asset("creature_rhino_crystal", crystal_rhino, 2.15, CRYSTAL_GLOW, "Crystal Rhino (legendary): living rock grown through with gemstones of every colour, Neon crystal horns."),
]
