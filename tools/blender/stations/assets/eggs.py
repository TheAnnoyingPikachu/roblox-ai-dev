"""The eggs (decision 0057), in the build of the animals (flat face tones under a surface texture), each
dressed for where its animals come from: the Meadow Egg in a nest of grass and daisies, the Wild Egg
bound in jungle vines with glowing mushrooms at its foot, the Safari Egg painted, roped and hung with
charms on cracked earth, the Golden Egg banded, jewelled and crowned on a clawed stand.

An egg is one piece (`body`) and, where it glows, Neon `body_glow`. It is three studs tall before its
dressing and stands on z = 0, its front towards Blender -Y.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Vector

loft, round_z, shard, plate, tone, rough, lump = F.loft, F.round_z, F.shard, F.plate, F.tone, F.rough, F.lump

SHINE = ((0.7, 0.54, 0.3), (1.06, 1.12, 1.5), (10, 16, 40))  # gold: deep amber shadows, pale lights
SPORE = (90, 255, 200)
ROYAL = (170, 70, 255)
H, WAIST, R = 3.0, 1.2, 1.12  # an egg's height, the height of its widest part, and its radius there
CENTRE = Vector((0, 0, 1.3))


def radius(z):
    """The shell's radius at height z."""
    return R * math.sqrt(max(0.0, 1 - ((z - WAIST) / (WAIST if z < WAIST else H - WAIST)) ** 2))


def out(az, el):
    """The direction `az` degrees round from the front (-Y) towards the left (+X), `el` degrees up."""
    a, e = math.radians(az), math.radians(el)
    return Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))


def new_egg(seed):
    return random.Random(seed), {"body": [], "body_glow": []}


def shell(tones, rng, surface="shell"):
    rings = [round_z(0, 0, z, radius(z), radius(z), 18) for z in [0.04 + (H - 0.08) * i / 13 for i in range(14)]]
    return rough(loft("shell", rings, tones, rng, surface=surface), tones, rng, 0.02, 1.0)


def blotch(egg, az, el, size, tones, rng, sides=9, **kw):
    """A painted mark on the shell: an uneven patch."""
    at, n = k.land(egg, CENTRE, out(az, el))
    turn = rng.uniform(0, math.tau)
    edge = [(math.cos(turn + i * math.tau / sides) * size * r, math.sin(turn + i * math.tau / sides) * size * r) for i, r in enumerate(rng.uniform(0.62, 1.2) for _ in range(sides))]
    return plate("mark", at, k._frame(n), edge, 0.02, tones, rng, lift=0.006, **kw)


def wound(egg, turns, z0, z1, r, tones, rng, phase=0.0, steps=36, surface=None):
    """A vine or a rope wound round the shell from height z0 to z1. Returns (it, its points, their normals)."""
    pts, normals = [], []
    for i in range(steps + 1):
        t = i / steps
        a = phase + turns * math.tau * t
        at, n = k.land(egg, (0, 0, z0 + (z1 - z0) * t), (math.cos(a), math.sin(a), 0))
        pts.append(at + n * r * 0.55)
        normals.append(n)
    return F.colour(k.tube(pts, [r] * len(pts), m=F.material(surface=surface), n=6, name="wound"), tones, rng), pts, normals


def band(z, h, proud, tones, rng, **kw):
    """A hoop round the shell at height z, `h` tall and `proud` of it."""
    return loft("band", [round_z(0, 0, z + dz, radius(z + dz) + proud, radius(z + dz) + proud, 18) for dz in (-h / 2, 0, h / 2)], tones, rng, **kw)


def stud(egg, az, el, size, rows, tones, rng, **kw):
    """A six-sided mound on the shell (a cut gem, a boss): `rows` of (width, height) as shares of `size`."""
    at, n = k.land(egg, CENTRE, out(az, el))
    ex, ey, ez = k._frame(n)
    rings = [[at + ez * h * size + (ex * math.cos(i * math.tau / 6) + ey * math.sin(i * math.tau / 6)) * f * size for i in range(6)] for f, h in rows]
    if not kw.get("m"):  # tones: one for each tier's sides, then the top's
        tones = [t for t in tones[:-1] for _ in range(6)] + [tones[0], tones[-1]]
    return loft("stud", rings, tones, rng, **kw)


def tuft(into, at, blades, tones, rng, height=0.6, spread=0.5):
    """Blades of grass growing from the point `at`."""
    for _ in range(blades):
        lean = Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), 1)).normalized()
        into.append(shard(at, Vector(at) + lean * height * rng.uniform(0.6, 1.0), 0.1, 0.04, rng.choice(tones), rng, face=(lean.y, -lean.x, 0), at=0.3, name="blade"))


def daisy(into, at, n, rng, size=0.17, petal=(250, 248, 240), heart=(250, 200, 50)):
    """A flower flat on a surface whose normal is `n`."""
    ex, ey, ez = k._frame(n)
    at = Vector(at) + ez * 0.03
    for i in range(8):
        d = ex * math.cos(i * math.tau / 8) + ey * math.sin(i * math.tau / 8)
        into.append(shard(at, at + d * size + ez * 0.03, size * 0.5, 0.03, tone(petal, F.PALE), rng, face=ez, at=0.6, name="petal"))
    into.append(lump(at + ez * 0.03, (size * 0.3,) * 3, tone(heart, F.WARM), rng, surface=None))


def meadow_egg():
    """Meadow Egg: a cream shell dappled green, in a nest of grass, clover and daisies, a flowering vine
    climbing it, a ladybird on its side and a butterfly at its top."""
    rng, g = new_egg(3)
    body = g["body"]
    egg = shell(tone((250, 240, 204), F.PALE), rng)
    body.append(egg)
    greens = [tone(c, F.WARM) for c in ((120, 200, 100), (86, 168, 84), (156, 214, 110))]
    for az, el, size in ((-20, 10, 0.24), (35, 32, 0.2), (80, -8, 0.26), (140, 20, 0.22), (-150, 28, 0.25), (-90, 0, 0.2), (-60, 42, 0.17), (170, 52, 0.16), (10, 58, 0.15), (110, 55, 0.14), (-120, -22, 0.18), (30, -25, 0.17)):
        body.append(blotch(egg, az, el, size, rng.choice(greens), rng))
    for i in range(34):  # the nest: a ring of grass, taller behind
        a = i * math.tau / 34 + rng.uniform(-0.06, 0.06)
        ring = rng.uniform(0.85, 1.25)
        at = Vector((math.sin(a) * ring, -math.cos(a) * ring, 0))
        tall = 0.5 + 0.35 * (1 - math.cos(a)) / 2
        tuft(body, at, 2, greens, rng, tall, 0.45)
    for a in range(0, 360, 45):  # clover leaves lying round it
        at = out(a + 12, 0) * 1.45
        for j in range(3):
            d = out(a + 12 + j * 120, 0)
            body.append(shard(at + Vector((0, 0, 0.05)), at + d * 0.2 + Vector((0, 0, 0.07)), 0.2, 0.04, greens[1], rng, face=(0, 0, 1), at=0.65, name="clover"))
    for a, ring in ((-40, 1.35), (25, 1.5), (95, 1.3), (160, 1.45), (-110, 1.4)):  # daisies in the grass
        stem = out(a, 0) * ring
        body.append(shard(stem, stem + Vector((0, 0, 0.5)), 0.05, 0.05, greens[1], rng, name="stem"))
        daisy(body, stem + Vector((0, 0, 0.5)), out(a, 55), rng)
    vine, pts, normals = wound(egg, 1.3, 0.25, 2.5, 0.05, greens[1], rng, phase=-1.2)
    body.append(vine)
    for i in range(3, len(pts) - 1, 4):  # leaves along the vine, a flower on every other one
        side = normals[i].cross(pts[i + 1] - pts[i]).normalized() * (1 if i % 8 < 4 else -1)
        body.append(shard(pts[i], pts[i] + side * 0.26 + normals[i] * 0.05, 0.16, 0.04, greens[i % 3], rng, face=normals[i], at=0.5, name="leaf"))
        if i % 8 >= 4:
            daisy(body, pts[i] - side * 0.08 + normals[i] * 0.04, normals[i], rng, 0.11, (255, 170, 200), (255, 230, 120))
    at, n = k.land(egg, CENTRE, out(-48, 18))  # a ladybird
    body.append(lump(at + n * 0.05, (0.1, 0.12, 0.08), tone((220, 40, 36), F.WARM), rng, surface=None))
    body.append(lump(at + n * 0.05 + k._frame(n)[1] * 0.11, (0.05, 0.05, 0.05), tone(F.INK), rng, surface=None))
    top = Vector((0.05, -0.1, H))
    for s in (1, -1):  # a butterfly, wings up
        for back, size in ((0.0, 0.34), (0.16, 0.24)):
            body.append(shard(top + Vector((0, back, 0.02)), top + Vector((s * size * 0.8, back + 0.06, size)), size * 0.75, 0.03, tone((255, 150, 40) if back == 0 else (255, 200, 70), F.WARM), rng, face=(0, 1, 0), at=0.6, name="wing"))
    body.append(shard(top + Vector((0, -0.08, 0.02)), top + Vector((0, 0.24, 0.06)), 0.05, 0.05, tone(F.INK), rng, name="butterfly"))
    twig = [tone(c, F.WARM) for c in ((132, 98, 62), (104, 76, 48), (160, 124, 80))]
    for i in range(44):  # the nest itself: twigs woven round its foot
        a = i * 360 / 44 + rng.uniform(-4, 4)
        d, across = out(a, 0), out(a + 90, 0)
        at = d * rng.uniform(0.95, 1.3) + Vector((0, 0, rng.uniform(0.05, 0.32)))
        body.append(shard(at - across * 0.48, at + across * 0.48 + Vector((0, 0, rng.uniform(-0.1, 0.12))), 0.07, 0.06, rng.choice(twig), rng, name="twig"))
    for i in range(22):  # small dots between the patches
        body.append(blotch(egg, i * 137.5 + 20, -30 + (i * 37) % 100, rng.uniform(0.05, 0.08), rng.choice(greens), rng, sides=5))
    for a, ring, rgb in ((-75, 1.5, (120, 150, 255)), (5, 1.62, (255, 170, 200)), (60, 1.55, (120, 150, 255)), (130, 1.62, (255, 220, 90)), (-150, 1.6, (255, 170, 200)), (-18, 1.32, (255, 220, 90))):
        daisy(body, out(a, 0) * ring + Vector((0, 0, 0.2)), out(a, 60), rng, 0.1, rgb, (255, 240, 160))  # small flowers low in the grass
    vine, pts, normals = wound(egg, -1.1, 0.3, 2.3, 0.04, greens[0], rng, phase=1.9)  # a second, finer vine the other way
    body.append(vine)
    for i in range(2, len(pts) - 1, 3):
        side = normals[i].cross(pts[i + 1] - pts[i]).normalized() * (1 if i % 2 else -1)
        body.append(shard(pts[i], pts[i] + side * 0.2 + normals[i] * 0.04, 0.13, 0.04, greens[i % 3], rng, face=normals[i], at=0.5, name="leaf"))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def wild_egg():
    """Wild Egg: a leaf-green shell with bark-brown spots and claw marks, bound in thorned jungle vines,
    broad leaves and ferns at its foot, moss on its shoulder, glowing mushrooms growing round it."""
    rng, g = new_egg(5)
    body, glow = g["body"], k.glow(SPORE)
    egg = shell(tone((146, 206, 116), F.WARM), rng)
    body.append(egg)
    browns = [tone(c, F.WARM) for c in ((104, 76, 48), (128, 96, 58))]
    leaf = [tone(c, F.WARM) for c in ((40, 130, 66), (66, 160, 74), (30, 104, 60))]
    for az, el, size in ((-30, 30, 0.22), (20, 5, 0.26), (70, 38, 0.2), (125, 5, 0.25), (175, 30, 0.22), (-135, 12, 0.24), (-85, 40, 0.19), (-60, -12, 0.2), (95, -22, 0.2), (0, 56, 0.16), (150, 58, 0.15), (-165, -20, 0.2)):
        body.append(blotch(egg, az, el, size, rng.choice(browns), rng, sides=6))
        if rng.random() < 0.6:
            body.append(blotch(egg, az + rng.uniform(8, 14), el + rng.uniform(-9, 9), size * 0.4, browns[0], rng, sides=5))
    for i in range(3):  # claw marks down the front
        body.append(F.colour(k.vein(egg, [(tuple(CENTRE), out(-6 + i * 11 - j * 3, 46 - j * 9)) for j in range(5)], 0.04, F.material(), lift=0.0, name="claw"), tone((226, 240, 200), F.PALE), rng))
    for phase, turns, z0, z1, r in ((0.4, 1.6, 0.15, 2.7, 0.085), (3.3, -1.35, 0.2, 2.45, 0.07)):  # two vines, crossing
        vine, pts, normals = wound(egg, turns, z0, z1, r, browns[0] if r > 0.08 else leaf[2], rng, phase=phase, surface="horn")
        body.append(vine)
        for i in range(2, len(pts) - 1, 3):
            along = (pts[i + 1] - pts[i]).normalized()
            side = normals[i].cross(along).normalized() * (1 if i % 2 else -1)
            body.append(shard(pts[i], pts[i] + normals[i] * 0.17 + side * 0.04, 0.08, 0.07, tone((70, 50, 34), F.WARM), rng, at=0.3, name="thorn"))
            if i % 6 == 2:
                body.append(shard(pts[i], pts[i] + side * 0.34 + normals[i] * 0.08, 0.2, 0.04, rng.choice(leaf), rng, face=normals[i], at=0.45, name="leaf"))
    for i in range(11):  # broad leaves and ferns round its foot
        a = i * 360 / 11 + rng.uniform(-8, 8)
        d = out(a, 0)
        root = d * 0.95
        if i % 2:
            body.append(shard(root, root + d * 0.75 + Vector((0, 0, rng.uniform(0.4, 0.7))), 0.48, 0.05, rng.choice(leaf), rng, face=(0, 0, 1), at=0.45, name="leaf"))
        else:  # a fern: a rib with fronds
            tip = root + d * 0.6 + Vector((0, 0, 0.95))
            body.append(shard(root, tip, 0.05, 0.05, leaf[2], rng, name="rib"))
            across = Vector((-d.y, d.x, 0))
            for j in range(1, 6):
                at = root + (tip - root) * (j / 6)
                for s in (1, -1):
                    body.append(shard(at, at + across * s * (0.3 - j * 0.035) + Vector((0, 0, 0.05)), 0.12, 0.03, leaf[j % 3], rng, face=d, at=0.4, name="frond"))
    for az, el in ((60, 62), (-110, 55), (160, 40)):  # moss
        at, n = k.land(egg, CENTRE, out(az, el))
        body.append(lump(at + n * 0.02, (0.26, 0.22, 0.06), leaf[1], rng, surface="scales"))
    for a, ring, size in ((-35, 1.3, 1.0), (-12, 1.5, 0.7), (48, 1.35, 0.85), (130, 1.4, 1.0), (150, 1.6, 0.6), (-125, 1.3, 0.8), (-150, 1.55, 0.55)):  # mushrooms, their caps alight
        root = out(a, 0) * ring
        cap = root + Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.55 * size))
        body.append(shard(root, cap + Vector((0, 0, 0.05)), 0.12 * size, 0.12 * size, tone((226, 220, 196), F.PALE), rng, at=0.2, name="stalk"))
        g["body_glow"].append(lump(cap + Vector((0, 0, 0.04)), (0.26 * size, 0.26 * size, 0.13 * size), None, rng, m=glow))
    for i in range(7):  # dark stripes over its crown
        body.append(F.colour(k.vein(egg, [(tuple(CENTRE), out(i * 51 + j * 7, 80 - j * 11)) for j in range(4)], 0.06, F.material(), lift=0.0, name="stripe"), browns[0], rng))
    for az, el, rgb in ((-40, 18, (255, 140, 30)), (62, 28, (255, 90, 120)), (150, 12, (255, 140, 30)), (-120, 34, (255, 90, 120)), (8, 44, (255, 200, 60)), (-80, 8, (255, 200, 60))):  # orchids
        at, n = k.land(egg, CENTRE, out(az, el))
        daisy(body, at + n * 0.1, n, rng, 0.17, rgb, (255, 240, 120))
    for i in range(9):  # roots spreading from under it
        d = out(i * 40 + rng.uniform(-10, 10), 0)
        body.append(F.colour(k.tube([d * 0.7 + Vector((0, 0, 0.12)), d * 1.25 + Vector((0, 0, 0.1)), d * 1.8], [0.1, 0.07, 0.03], m=F.material(surface="horn"), n=5, name="root"), browns[i % 2], rng))
    for az in (-70, 15, 100, 190):  # hanging moss
        at, n = k.land(egg, CENTRE, out(az, 24))
        for j in range(4):
            top = at + k._frame(n)[0] * (j - 1.5) * 0.1 + n * 0.03
            body.append(shard(top, top - Vector((0, 0, rng.uniform(0.3, 0.6))), 0.07, 0.03, leaf[j % 3], rng, face=n, at=0.3, name="moss"))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def safari_egg():
    """Safari Egg: a sand-gold shell with a cheetah's spots above and a painted band of zigzags, roped
    twice round and strapped with leather and a brass buckle, a paw print on its front, hung with
    feathers, a tooth and beads, standing on cracked earth among dry grass and stones."""
    rng, g = new_egg(7)
    body = g["body"]
    egg = shell(tone((244, 200, 112), F.WARM), rng)
    body.append(egg)
    ink, cream, red = tone((66, 46, 32), F.WARM), tone((250, 232, 190), F.PALE), tone((196, 70, 40), F.WARM)
    for i in range(26):  # spots above the band
        body.append(blotch(egg, i * 137.5, 30 + (i % 5) * 9 + rng.uniform(-3, 3), rng.uniform(0.1, 0.16), ink, rng, sides=5))
    for z, tones in ((1.52, red), (0.98, red)):  # the band's edges
        body.append(band(z, 0.07, 0.012, tones, rng))
    for i in range(18):  # zigzags between them
        a = i * 20
        lo, _ = k.land(egg, (0, 0, 1.02), (math.sin(math.radians(a)), -math.cos(math.radians(a)), 0))
        hi, n = k.land(egg, (0, 0, 1.48), (math.sin(math.radians(a + 10)), -math.cos(math.radians(a + 10)), 0))
        nxt, _ = k.land(egg, (0, 0, 1.02), (math.sin(math.radians(a + 20)), -math.cos(math.radians(a + 20)), 0))
        for a_, b_ in ((lo, hi), (hi, nxt)):
            body.append(shard(a_ + n * 0.012, b_ + n * 0.012, 0.09, 0.03, ink if i % 2 else cream, rng, face=n, name="zigzag"))
    at, n = k.land(egg, CENTRE, out(0, -22))  # a paw print on the front
    ex, ey, ez = k._frame(n)
    body.append(plate("pad", at, (ex, ey, ez), [(-0.13, -0.1), (0.13, -0.1), (0.16, 0.03), (0.0, 0.12), (-0.16, 0.03)], 0.02, ink, rng, lift=0.008))
    for dx, dy in ((-0.2, 0.17), (-0.07, 0.26), (0.07, 0.26), (0.2, 0.17)):
        body.append(plate("toe", at + ex * dx + ey * dy, (ex, ey, ez), [(0.05 * math.cos(i * math.tau / 6), 0.065 * math.sin(i * math.tau / 6)) for i in range(6)], 0.02, ink, rng, lift=0.012))
    rope_t = tone((176, 140, 86), F.WARM)
    for z0, z1, phase in ((2.0, 2.12, 0.3), (2.14, 2.02, 2.9)):  # the rope, twice round, knotted at the front
        rope, pts, normals = wound(egg, 1.0, z0, z1, 0.06, rope_t, rng, phase=phase, surface="fur")
        body.append(rope)
    knot, n = k.land(egg, (0, 0, 2.07), (0.25, -1, 0))
    body.append(lump(knot + n * 0.1, (0.13, 0.1, 0.11), rope_t, rng, surface="fur"))
    for dx, length, what in ((-0.16, 0.75, "feather"), (-0.04, 0.5, "tooth"), (0.1, 0.9, "feather"), (0.22, 0.42, "bead")):  # the charms
        top = knot + n * 0.14 + k._frame(n)[0] * dx
        end = top + Vector((0, 0, -length))
        body.append(shard(top, end, 0.03, 0.03, rope_t, rng, name="cord"))
        if what == "feather":
            body.append(shard(end + Vector((0, 0, 0.12)), end + Vector((dx * 0.4, -0.05, -0.5)), 0.2, 0.03, (red, cream) if dx < 0 else (cream, ink), rng, face=n, at=0.45, name="feather"))
        elif what == "tooth":
            body.append(shard(end + Vector((0, 0, 0.05)), end + Vector((0.03, -0.02, -0.26)), 0.1, 0.09, tone(F.BONE, F.PALE), rng, at=0.25, name="tooth", surface="horn"))
        else:
            for j, c in enumerate(((60, 150, 190), (226, 160, 50), (196, 70, 40))):
                body.append(lump(end + Vector((0, 0, -0.06 - j * 0.11)), (0.055, 0.055, 0.055), tone(c, F.WARM), rng, surface=None))
    strap = tone((120, 76, 44), F.WARM)  # a leather strap from the rope down under the egg, and its buckle
    for a in (90, -90):
        pts = [k.land(egg, (0, 0, z), (math.sin(math.radians(a)), -math.cos(math.radians(a)), 0)) for z in (2.02, 1.6, 1.2, 0.8, 0.4, 0.14)]
        for (p0, n0), (p1, n1) in zip(pts, pts[1:]):
            body.append(shard(p0 + n0 * 0.02, p1 + n1 * 0.02, 0.2, 0.05, strap, rng, face=n0, name="strap"))
    at, n = k.land(egg, (0, 0, 1.25), (1, 0, 0))
    ex, ey, ez = k._frame(n)
    brass = tone((226, 176, 60), SHINE)
    body.append(plate("buckle", at, (ex, ey, ez), [(-0.16, -0.13), (0.16, -0.13), (0.16, 0.13), (-0.16, 0.13)], 0.05, brass, rng, lift=0.045))
    body.append(plate("buckle", at, (ex, ey, ez), [(-0.09, -0.07), (0.09, -0.07), (0.09, 0.07), (-0.09, 0.07)], 0.06, strap, rng, lift=0.05))
    earth = [tone(c, F.WARM) for c in ((176, 132, 84), (150, 110, 70), (196, 150, 96))]
    for i in range(12):  # cracked earth: flat slabs round its foot
        d = out(i * 30 + rng.uniform(-8, 8), 0) * rng.uniform(0.9, 1.5)
        body.append(lump(d + Vector((0, 0, 0.03)), (rng.uniform(0.24, 0.36), rng.uniform(0.24, 0.36), 0.06), rng.choice(earth), rng))
    dry = [tone(c, F.WARM) for c in ((214, 180, 96), (190, 150, 76))]
    for a, ring in ((-60, 1.3), (-20, 1.55), (70, 1.35), (120, 1.5), (175, 1.3), (-130, 1.45)):
        tuft(body, out(a, 0) * ring, 5, dry, rng, 0.75, 0.6)
    for a, ring, size in ((30, 1.45, 0.16), (-95, 1.6, 0.2), (150, 1.7, 0.13)):
        body.append(lump(out(a, 0) * ring + Vector((0, 0, size * 0.6)), (size, size * 1.2, size * 0.8), tone((150, 140, 128), F.COOL), rng))
    for z in (1.6, 0.9):  # rows of cream dots along the band
        for i in range(30):
            at, n = k.land(egg, (0, 0, z), (math.sin(i * math.tau / 30), -math.cos(i * math.tau / 30), 0))
            body.append(lump(at + n * 0.01, (0.035, 0.035, 0.035), cream, rng, surface=None))
    for i in range(14):  # a row of painted teeth below the band
        d = (math.sin(i * math.tau / 14), -math.cos(i * math.tau / 14), 0)
        base, n = k.land(egg, (0, 0, 0.78), d)
        tip, _ = k.land(egg, (0, 0, 0.5), d)
        body.append(shard(base + n * 0.012, tip + n * 0.012, 0.2, 0.03, red if i % 2 else ink, rng, face=n, at=0.15, name="tooth"))
    for i in range(22):  # a string of beads under the rope
        a = i * math.tau / 22
        at, n = k.land(egg, (0, 0, 1.84 + 0.04 * math.sin(a * 3)), (math.sin(a), -math.cos(a), 0))
        body.append(lump(at + n * 0.05, (0.05, 0.05, 0.05), tone(((60, 150, 190), (226, 160, 50), (196, 70, 40), (250, 232, 190))[i % 4], F.WARM), rng, surface=None))
    for dx, lean, tones in ((-0.3, -0.3, (ink, cream)), (0.0, 0.0, (red, cream)), (0.3, 0.3, (ink, cream))):  # three tall feathers tucked into the rope behind
        root = Vector((dx, 0.93, 2.05))
        body.append(shard(root, root + Vector((lean, 0.3, 1.4)), 0.36, 0.04, tones, rng, face=(0, 1, 0), at=0.55, name="plume"))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def golden_egg():
    """Golden Egg: a shell of beaten gold, hooped with bands of bosses and cut violet gems (glowing),
    ribbed with filigree, crowned with a ring of points round a great glowing gem, on a stand with three
    clawed feet."""
    rng, g = new_egg(9)
    body, glow = g["body"], k.glow(ROYAL)
    gold, pale, deep = tone((255, 200, 60), SHINE), tone((255, 226, 130), SHINE), tone((206, 140, 30), SHINE)
    egg = shell(gold, rng, surface="horn")
    body.append(egg)
    for z, h in ((1.2, 0.2), (2.05, 0.12), (0.5, 0.12)):  # the hoops
        body.append(band(z, h, 0.035, pale, rng))
        body.append(band(z + h * 0.62, 0.035, 0.05, deep, rng))
        body.append(band(z - h * 0.62, 0.035, 0.05, deep, rng))
    cut = ((1.0, 0.0), (0.9, 0.3), (0.5, 0.52), (0.22, 0.56))  # girdle, crown, table
    for i in range(8):  # round the widest hoop: great gems, with bosses between
        el = math.degrees(math.atan2(1.2 - CENTRE.z, R))
        body.append(stud(egg, i * 45, el, 0.2, ((1.0, 0.0), (1.0, 0.16), (0.82, 0.2)), (deep, pale, pale), rng))
        g["body_glow"].append(stud(egg, i * 45, el, 0.2, [(f * 0.8, 0.2 + h_) for f, h_ in cut], None, rng, m=glow))
        body.append(stud(egg, i * 45 + 22.5, el, 0.09, ((1.0, 0.0), (0.7, 0.9), (0.3, 1.1)), (pale, pale, pale), rng))
    violet, rose = (150, 60, 235), (230, 60, 170)
    for i in range(6):  # smaller gems on the upper hoop, painted
        rgb = violet if i % 2 else rose
        gem = (tone(k.mix(rgb, (0, 0, 40), 0.3), SHINE), tone(rgb, F.COOL), tone(k.mix(rgb, (255, 255, 255), 0.4), F.COOL), tone(k.mix(rgb, (255, 255, 255), 0.6), F.COOL))
        body.append(stud(egg, i * 60 + 30, math.degrees(math.atan2(2.05 - CENTRE.z, radius(2.05))), 0.13, cut, gem, rng, emit=0.7, surface="gem"))
    for i in range(12):  # leaves of gold up the crown of the shell
        body.append(blotch(egg, i * 30, 62 + (i % 2) * 10, 0.13, pale if i % 2 else deep, rng, sides=4))
    top = Vector((0, 0, H - 0.1))
    body.append(loft("collar", [round_z(0, 0, H - 0.34, 0.5, 0.5, 12), round_z(0, 0, H - 0.2, 0.44, 0.44, 12), round_z(0, 0, H - 0.1, 0.46, 0.46, 12)], pale, rng))
    for i in range(8):  # the crown: a ring of points
        d = out(i * 45, 0)
        body.append(shard(top + d * 0.4 - Vector((0, 0, 0.1)), top + d * 0.52 + Vector((0, 0, 0.5 if i % 2 else 0.36)), 0.2, 0.1, gold, rng, face=d, at=0.3, name="point"))
        body.append(lump(top + d * 0.53 + Vector((0, 0, 0.53 if i % 2 else 0.39)), (0.045, 0.045, 0.045), pale, rng, surface=None))
    g["body_glow"].append(shard(top - Vector((0, 0, 0.12)), top + Vector((0, 0, 0.62)), 0.42, 0.42, None, rng, at=0.45, m=glow, name="gem"))
    body.append(loft("stand", [round_z(0, 0, 0.0, 1.0, 1.0, 14), round_z(0, 0, 0.1, 1.02, 1.02, 14), round_z(0, 0, 0.26, 0.8, 0.8, 14), round_z(0, 0, 0.36, 0.72, 0.72, 14)], deep, rng))
    for i in range(3):  # three clawed feet
        d = out(i * 120, 0)
        across = Vector((-d.y, d.x, 0))
        body.append(lump(d * 1.05 + Vector((0, 0, 0.14)), (0.22, 0.22, 0.15), gold, rng, surface=None))
        for j in (-1, 0, 1):
            toe = d * 1.2 + across * j * 0.13
            body.append(shard(toe + Vector((0, 0, 0.14)), toe + d * 0.2 + Vector((0, 0, 0.02)), 0.11, 0.1, pale, rng, face=(0, 0, 1), at=0.3, name="claw"))
    for z0, z1 in ((1.42, 1.92), (0.62, 1.02)):  # a quilting of small lozenges between the hoops
        for row in range(3):
            for i in range(16):
                a = math.radians(i * 22.5 + row * 11.25)
                at, n = k.land(egg, (0, 0, z0 + (z1 - z0) * (row + 0.5) / 3), (math.sin(a), -math.cos(a), 0))
                body.append(plate("lozenge", at, k._frame(n), [(0, 0.075), (0.06, 0), (0, -0.075), (-0.06, 0)], 0.02, pale if (i + row) % 2 else deep, rng, lift=0.008))
    pearl = tone((250, 244, 236), F.PALE)
    for z in (1.4, 1.0):  # pearls along both edges of the great hoop
        for i in range(32):
            at, n = k.land(egg, (0, 0, z), (math.sin(i * math.tau / 32), -math.cos(i * math.tau / 32), 0))
            body.append(lump(at + n * 0.05, (0.04, 0.04, 0.04), pearl, rng, surface=None))
    for i in range(6):  # chains swagged between the upper gems
        pts = []
        for j in range(7):
            a = math.radians(i * 60 + 30 + j * 10)
            at, n = k.land(egg, (0, 0, 1.95 - 0.17 * math.sin(j / 6 * math.pi)), (math.sin(a), -math.cos(a), 0))
            pts.append(at + n * 0.04)
        body.append(F.colour(k.tube(pts, [0.022] * 7, m=F.material(), n=5, name="chain"), pale, rng))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


ASSETS = [
    F.asset("egg_meadow", meadow_egg, 1.0, {}, "Meadow Egg: cream dappled green, in a nest of grass and daisies, a flowering vine, a butterfly."),
    F.asset("egg_wild", wild_egg, 1.0, {"body_glow": SPORE}, "Wild Egg: leaf-green with bark spots, bound in thorned vines, ferns and Neon mushrooms at its foot."),
    F.asset("egg_safari", safari_egg, 1.0, {}, "Safari Egg: sand-gold, spotted and painted, roped and strapped, hung with feathers and a tooth."),
    F.asset("egg_golden", golden_egg, 1.0, {"body_glow": ROYAL}, "Golden Egg: beaten gold, hooped and ribbed, set with Neon violet gems, crowned, on a clawed stand."),
]
