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


# The eggs of the later waves -------------------------------------------------------------------

AMBER = (255, 170, 50)
LAUREL = (255, 214, 90)
RUNE = (255, 160, 235)
HALO = (255, 214, 110)
STARLIGHT = (190, 220, 255)
PRISM = (255, 255, 255)
RAINBOW = ((240, 40, 50), (255, 140, 30), (255, 220, 40), (50, 200, 80), (40, 140, 255), (90, 60, 220), (200, 70, 230))
FLAT = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))  # a frame lying on the ground


def grade(ob, low, high, kind, rng):
    """Repaint a shell from `low` at its foot to `high` at its top."""
    return F.colour(ob, [tone(k.mix(low, high, min(1.0, max(0.0, p.center.z / H))), kind) for p in ob.data.polygons], rng, 0.26)


def ngon(r, n=6, turn=0.0, sx=1.0):
    return [(math.cos(turn + i * math.tau / n) * r * sx, math.sin(turn + i * math.tau / n) * r) for i in range(n)]


def star(r, inner=0.45, points=5):
    return [(math.cos(math.pi / 2 + i * math.pi / points) * r * (1 if i % 2 == 0 else inner), math.sin(math.pi / 2 + i * math.pi / points) * r * (1 if i % 2 == 0 else inner)) for i in range(points * 2)]


def circle(c, r, normal, n=36):
    """A closed loop of points round `c` in the plane whose normal is `normal`."""
    ex, ey, _ = k._frame(Vector(normal), up=(0, 1, 0) if abs(Vector(normal).normalized().z) > 0.9 else (0, 0, 1))
    return [Vector(c) + (ex * math.cos(i * math.tau / n) + ey * math.sin(i * math.tau / n)) * r for i in range(n + 1)]


def stroke(egg, a, b, width, tones, rng, lift=0.025, m=None):
    """A short straight line on the shell from (az, el) `a` to `b`."""
    pa, na = k.land(egg, CENTRE, out(*a))
    pb, nb = k.land(egg, CENTRE, out(*b))
    return shard(pa + na * lift, pb + nb * lift, width, width * 0.5, tones, rng, face=(na + nb).normalized(), at=0.5, m=m, name="stroke")


def on_shell(egg, az, el, lift=0.0):
    """A point on the shell, lifted off it, and the frame there."""
    at, n = k.land(egg, CENTRE, out(az, el))
    return at + n * lift, k._frame(n)


def glyph(into, p, frame, kind, s, tones, rng):
    """A hieroglyph-like mark `s` high round the point p: a reed, the sun, water, an ankh or an eye."""
    ex, ey, ez = frame

    def put(outline, dy=0.0):
        into.append(plate("glyph", p + ey * dy, frame, outline, 0.02, tones, rng, lift=0.0))

    if kind == 0:
        put([(-0.03, -s), (0.03, -s), (0.04, s), (-0.02, s * 1.1)])
    elif kind == 1:
        put(ngon(s * 0.5, 7))
    elif kind == 2:
        for dy in (-s * 0.45, s * 0.45):
            top = [(x * s * 0.8, 0.035 + 0.07 * (i % 2)) for i, x in enumerate((-1, -0.5, 0, 0.5, 1))]
            put(top + [(x, y - 0.07) for x, y in reversed(top)], dy)
    elif kind == 3:
        put([(-0.028, -s), (0.028, -s), (0.028, s * 0.2), (-0.028, s * 0.2)])
        put([(-s * 0.4, -0.025), (s * 0.4, -0.025), (s * 0.4, 0.025), (-s * 0.4, 0.025)], s * 0.12)
        put(ngon(s * 0.32, 6, sx=0.8), s * 0.55)
    else:
        put([(-s, 0), (-s * 0.4, s * 0.45), (s * 0.4, s * 0.45), (s, 0), (s * 0.4, -s * 0.4), (-s * 0.4, -s * 0.4)])


def dusk_egg():
    """Dusk Egg: an Egyptian twilight. An indigo-to-violet shell with early stars, two gold bands of
    hieroglyphs, a winged gold scarab holding up a glowing sun on its front, glowing eyes of Horus on its
    sides, a crescent moon on top, on a sandstone step among sand drifts, lamps and two obelisks."""
    rng, g = new_egg(11)
    body, lit, glow = g["body"], g["body_glow"], k.glow(AMBER)
    egg = shell(tone((70, 56, 150), F.COOL), rng)
    grade(egg, (36, 30, 104), (140, 80, 196), F.COOL, rng)
    body.append(egg)
    gold, pale, ink = tone((236, 184, 64), SHINE), tone((255, 224, 140), SHINE), tone((44, 30, 96), F.COOL)
    for z, h, count in ((1.66, 0.3, 18), (0.76, 0.24, 14)):  # the bands and their hieroglyphs
        body.append(band(z, h, 0.03, gold, rng))
        for edge in (h / 2, -h / 2):
            body.append(band(z + edge, 0.04, 0.05, pale, rng))
        for i in range(count):
            at, n = k.land(egg, (0, 0, z), out((i + 0.5) * 360 / count, 0))
            glyph(body, at + n * 0.045, k._frame(n), (i * 3) % 5, h * 0.33, ink, rng)
    p, (ex, ey, ez) = on_shell(egg, 0, -5, 0.02)  # the scarab on the front
    body.append(lump(p + ez * 0.06, (0.15, 0.08, 0.19), gold, rng, surface=None))
    body.append(lump(p + ey * 0.2 + ez * 0.06, (0.09, 0.06, 0.07), pale, rng, surface=None))
    for s in (1, -1):
        body.append(shard(p + ez * 0.05 + ex * s * 0.08, p + ex * s * 0.5 + ey * 0.1 + ez * 0.03, 0.2, 0.03, (gold, pale), rng, face=ez, at=0.35, name="wing"))
        body.append(shard(p + ez * 0.05 + ex * s * 0.06 - ey * 0.05, p + ex * s * 0.36 - ey * 0.12 + ez * 0.03, 0.13, 0.03, gold, rng, face=ez, at=0.35, name="wing"))
        for dy in (-0.1, 0.02):
            body.append(shard(p + ez * 0.04 + ey * dy, p + ex * s * 0.2 + ey * (dy - 0.1) + ez * 0.02, 0.03, 0.03, gold, rng, face=ez, name="leg"))
    body.append(plate("ring", p + ey * 0.38, (ex, ey, ez), ngon(0.13, 10), 0.03, gold, rng, lift=0.0))
    lit.append(plate("sun", p + ey * 0.38, (ex, ey, ez), ngon(0.1, 10), 0.03, None, rng, lift=0.02, m=glow))
    for az in (90, -90):  # an eye of Horus on each side
        p, (ex, ey, ez) = on_shell(egg, az, -3, 0.02)
        body.append(plate("eye", p, (ex, ey, ez), [(-0.24, 0), (-0.09, 0.1), (0.09, 0.1), (0.24, 0), (0.09, -0.09), (-0.09, -0.09)], 0.025, gold, rng, lift=0.0))
        body.append(plate("eye", p, (ex, ey, ez), [(-0.17, 0), (-0.06, 0.06), (0.06, 0.06), (0.17, 0), (0.06, -0.055), (-0.06, -0.055)], 0.02, ink, rng, lift=0.02))
        lit.append(plate("iris", p, (ex, ey, ez), ngon(0.055, 8), 0.02, None, rng, lift=0.035, m=glow))
        body.append(shard(p - ex * 0.24 + ey * 0.16, p + ex * 0.26 + ey * 0.17, 0.06, 0.03, gold, rng, face=ez, name="brow"))
        body.append(shard(p - ey * 0.08, p - ey * 0.34 - ex * 0.06, 0.06, 0.03, gold, rng, face=ez, at=0.3, name="tear"))
        body.append(shard(p - ey * 0.08 + ex * 0.08, p - ey * 0.26 + ex * 0.26, 0.06, 0.03, gold, rng, face=ez, at=0.3, name="tail"))
    for i in range(16):  # the first stars
        p, frame = on_shell(egg, i * 137.5 + 15, 44 + (i * 23) % 36, 0.015)
        body.append(plate("star", p, frame, star(rng.uniform(0.06, 0.09)), 0.02, pale, rng, lift=0.0))
    top = Vector((0, 0, H + 0.38))  # the crescent moon, horns up
    arc = [top + Vector((math.cos(math.radians(a)) * 0.36, 0, math.sin(math.radians(a)) * 0.36)) for a in range(155, 386, 21)]
    body.append(F.colour(k.tube(arc, [0.13 * math.sin(math.pi * i / (len(arc) - 1)) ** 0.8 for i in range(len(arc))], m=F.material(), n=6, name="moon"), pale, rng))
    body.append(lump(Vector((0, 0, H - 0.02)), (0.12, 0.12, 0.08), gold, rng, surface=None))
    sand, stone = tone((240, 204, 136), F.WARM), [tone(c, F.WARM) for c in ((222, 176, 112), (206, 158, 98))]
    for z0, z1, w, tones in ((0.0, 0.18, 1.8, stone[1]), (0.18, 0.36, 1.4, stone[0])):  # the sandstone step
        body.append(loft("step", [round_z(0, 0, z0, w, w, 4), round_z(0, 0, z1, w, w, 4)], tones, rng, surface="rock"))
    for a, ring, size in ((-20, 1.55, 0.42), (40, 1.65, 0.36), (100, 1.5, 0.45), (165, 1.6, 0.4), (-120, 1.55, 0.44), (-75, 1.75, 0.3), (-160, 1.75, 0.3)):  # sand drifts against it
        body.append(lump(out(a, 0) * ring + Vector((0, 0, 0.04)), (size, size * 0.7, 0.1), sand, rng, surface=None))
    for x in (1.08, -1.08):
        bowl = Vector((x, -1.08, 0.24))  # a lamp at each front corner
        body.append(lump(bowl, (0.14, 0.14, 0.07), gold, rng, surface=None))
        lit.append(shard(bowl + Vector((0, 0, 0.02)), bowl + Vector((0, 0, 0.42)), 0.16, 0.16, None, rng, at=0.3, m=glow, name="flame"))
        foot = Vector((x, 1.08, 0.18))  # an obelisk at each back corner
        body.append(loft("obelisk", [round_z(x, 1.08, 0.18, 0.16, 0.16, 4), round_z(x, 1.08, 1.3, 0.1, 0.1, 4)], stone[0], rng, surface="rock"))
        body.append(shard(foot + Vector((0, 0, 1.12)), foot + Vector((0, 0, 1.4)), 0.15, 0.15, gold, rng, at=0.2, name="tip"))
        for j in range(3):
            body.append(plate("glyph", foot + Vector((0, -0.125 + 0.005 * j, 0.45 + j * 0.25)), (Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))), ngon(0.04, (6, 3, 4)[j]), 0.015, ink, rng, lift=0.0))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def lotus(into, at, rng, size=1.0):
    pink, light = tone((255, 130, 176), F.WARM), tone((255, 200, 220), F.PALE)
    for i in range(8):
        d = out(i * 45, 0)
        into.append(shard(at, at + d * 0.2 * size + Vector((0, 0, 0.14 * size)), 0.14 * size, 0.04, (pink, light), rng, face=d, at=0.5, name="petal"))
    for i in range(5):
        d = out(i * 72 + 20, 0)
        into.append(shard(at, at + d * 0.07 * size + Vector((0, 0, 0.26 * size)), 0.12 * size, 0.04, (pink, light), rng, face=d, at=0.5, name="petal"))
    into.append(lump(at + Vector((0, 0, 0.06 * size)), (0.06 * size,) * 3, tone((255, 216, 70), F.WARM), rng, surface=None))


def oasis_egg():
    """Oasis Egg: a turquoise shell swept with pink flamingo-feather stripes, standing in a ring of
    shallow water with lily pads, a pink lotus and a bud, a sandy rim, reeds, two small palms behind and
    pink feathers dropped round it."""
    rng, g = new_egg(13)
    body = g["body"]
    egg = shell(tone((70, 206, 200), F.WARM), rng)
    grade(egg, (36, 168, 178), (120, 228, 212), F.WARM, rng)
    body.append(egg)
    pinks = [tone(c, F.WARM) for c in ((250, 110, 156), (255, 160, 190))]
    for i in range(6):  # flamingo feathers sweeping down round the shell: a quill, vanes either side
        rays = [(tuple(CENTRE), out(i * 60 + j * 5, 74 - j * 9)) for j in range(12)]
        body.append(F.colour(k.vein(egg, rays, 0.05, F.material(), lift=0.01, name="quill"), tone((255, 226, 234), F.PALE), rng))
        pts = [k.land(egg, CENTRE, d) for _, d in rays]
        for j in range(1, 11):
            (p, n), (q, _) = pts[j], pts[j + 1]
            along = (q - p).normalized()
            side = n.cross(along).normalized()
            reach = 0.1 + 0.16 * math.sin(math.pi * j / 11)
            for s in (1, -1):
                body.append(shard(p + n * 0.025, p + side * s * reach + along * reach * 0.3 + n * 0.05, 0.13, 0.025, pinks[j % 2], rng, face=n, at=0.35, name="vane"))
    water, light = tone((34, 128, 196), F.COOL), tone((150, 230, 240), F.PALE)
    body.append(loft("water", [round_z(0, 0, 0.0, 1.85, 1.85, 20), round_z(0, 0, 0.07, 1.85, 1.85, 20)], water, rng))
    for a, ring, w in ((-60, 1.15, 0.3), (30, 1.4, 0.24), (150, 1.25, 0.28), (-140, 1.5, 0.22)):  # ripples
        c = out(a, 0) * ring + Vector((0, 0, 0.07))
        body.append(plate("ripple", c, FLAT, ngon(w, 10, sx=1.6), 0.008, tone((90, 190, 230), F.PALE), rng, lift=0.0))
    sand = [tone(c, F.WARM) for c in ((236, 204, 140), (214, 180, 116))]
    for i in range(24):  # a sandy rim
        body.append(lump(out(i * 15 + rng.uniform(-4, 4), 0) * 1.9 + Vector((0, 0, 0.05)), (0.22, 0.22, 0.1), rng.choice(sand), rng, surface=None))
    green = [tone(c, F.WARM) for c in ((80, 176, 84), (60, 150, 70))]
    pads = ((-40, 1.42, 0.24), (20, 1.5, 0.2), (75, 1.3, 0.22), (130, 1.55, 0.19), (-95, 1.35, 0.2), (-160, 1.45, 0.18))
    for i, (a, ring, r) in enumerate(pads):
        turn = rng.uniform(0, math.tau)
        edge = [(0.0, 0.0)] + [(math.cos(turn + 0.35 + t * (math.tau - 0.7) / 8) * r, math.sin(turn + 0.35 + t * (math.tau - 0.7) / 8) * r) for t in range(9)]
        body.append(plate("pad", out(a, 0) * ring + Vector((0, 0, 0.07)), FLAT, edge, 0.02, green[i % 2], rng, lift=0.0))
    lotus(body, out(-40, 0) * 1.42 + Vector((0, 0, 0.09)), rng, 1.2)
    lotus(body, out(130, 0) * 1.55 + Vector((0, 0, 0.09)), rng, 0.8)
    bud = out(75, 0) * 1.3 + Vector((0, 0, 0.08))
    body.append(shard(bud, bud + Vector((0, 0, 0.34)), 0.13, 0.13, (pinks[0], pinks[1]), rng, at=0.4, name="bud"))
    trunk_t = [tone(c, F.WARM) for c in ((150, 108, 64), (120, 84, 50))]
    frond = [tone(c, F.WARM) for c in ((70, 170, 70), (100, 196, 80), (50, 140, 64))]
    for s in (1, -1):  # two small palms behind
        root = Vector((s * 0.85, 1.25, 0.05))
        top = Vector((s * 1.25, 1.4, 2.35))
        pts = [root.lerp(top, t) + Vector((s * 0.18 * math.sin(math.pi * t), 0, 0)) for t in (0, 0.25, 0.5, 0.75, 1.0)]
        body.append(F.colour(k.tube(pts, [0.11, 0.1, 0.09, 0.08, 0.07], m=F.material(surface="horn"), n=6, name="trunk"), trunk_t[0], rng))
        for j in range(4):
            body.append(band_at(pts[j].lerp(pts[j + 1], 0.5), 0.1 - j * 0.01, trunk_t[1], rng))
        for j in range(7):
            d = out(j * 360 / 7 + (25 if s > 0 else 0), 0)
            mid = top + d * 0.45 + Vector((0, 0, 0.18))
            body.append(shard(top, mid, 0.26, 0.04, frond[j % 3], rng, face=(0, 0, 1), at=0.6, name="frond"))
            body.append(shard(mid, top + d * 0.9 - Vector((0, 0, 0.28)), 0.24, 0.04, frond[(j + 1) % 3], rng, face=(0, 0, 1), at=0.25, name="frond"))
        for j in range(3):
            body.append(lump(top + out(j * 120 + 60, 0) * 0.1 - Vector((0, 0, 0.08)), (0.07, 0.07, 0.07), trunk_t[1], rng, surface=None))
    for a, ring in ((-75, 1.62), (55, 1.65), (170, 1.6)):  # reeds with brown heads
        at = out(a, 0) * ring
        for j in range(3):
            tip = at + Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), rng.uniform(0.55, 0.8)))
            body.append(shard(at, tip, 0.05, 0.04, green[1], rng, at=0.3, name="reed"))
            if j == 0:
                body.append(shard(tip - Vector((0, 0, 0.18)), tip + Vector((0, 0, 0.02)), 0.08, 0.08, trunk_t[0], rng, name="head"))
    for a, ring, turn in ((-15, 1.75, 40), (105, 1.72, -30), (-120, 1.68, 80), (8, 1.2, 120)):  # dropped feathers
        p = out(a, 0) * ring + Vector((0, 0, 0.1))
        d = out(a + turn, 0)
        body.append(shard(p, p + d * 0.5 + Vector((0, 0, 0.04)), 0.16, 0.03, (pinks[1], pinks[0]), rng, face=(0, 0, 1), at=0.4, name="feather"))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def band_at(c, r, tones, rng):
    """A ring round a palm trunk at the point c."""
    return lump(c, (r * 1.25, r * 1.25, 0.04), tones, rng, surface=None)


def ivory_egg():
    """Ivory Egg (the Titan egg): an ivory shell in ochre and red war paint, two great tusks rising from
    its foot and curving up round its sides, a rhino's horn on its top, on a base of rock and old bones."""
    rng, g = new_egg(17)
    body = g["body"]
    egg = shell(tone((248, 238, 214), F.PALE), rng, surface="horn")
    body.append(egg)
    ochre, red = tone((220, 146, 46), F.WARM), tone((190, 52, 40), F.WARM)
    for az in (0, 180):  # chevrons, red over ochre, front and back
        for (a, b, c), tones in ((((-38, 42), (0, 14), (38, 42)), red), (((-38, 18), (0, -10), (38, 18)), ochre)):
            body.append(F.colour(k.vein(egg, [(tuple(CENTRE), out(az + x, y)) for x, y in (a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), b)] + [(tuple(CENTRE), out(az + x, y)) for x, y in (((b[0] + c[0]) / 2, (b[1] + c[1]) / 2), c)], 0.11, F.material(), lift=0.0, name="paint"), tones, rng))
    for az in (90, -90):  # three slashes on each side
        for j in (-1, 0, 1):
            body.append(F.colour(k.vein(egg, [(tuple(CENTRE), out(az + j * 14 + t * 4, 44 - t * 16)) for t in range(5)], 0.08, F.material(), lift=0.0, name="paint"), ochre if j else red, rng))
    for i in range(18):  # a row of red dots low down
        body.append(blotch(egg, i * 20, -32, 0.06, red, rng, sides=6))
    for i in range(10):  # ochre dots round the crown
        body.append(blotch(egg, i * 36 + 18, 62, 0.07, ochre, rng, sides=6))
    bone = [tone(c, F.PALE) for c in ((236, 224, 196), (250, 244, 226))]
    for s in (1, -1):  # the tusks: from the foot, out and up round the sides, their points turned forward
        ctrl = [(s * 30, 1.05, 0.25), (s * 95, 1.95, 1.0), (s * 38, 1.5, 2.45)]
        pts = []
        for i in range(11):
            t = i / 10
            az, ring, z = ((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for p0, p1, p2 in zip(*ctrl))
            pts.append(out(az, 0) * ring + Vector((0, 0, z)))
        radii = [0.2 * (1 - i / 10) ** 0.7 + 0.004 for i in range(11)]
        body.append(F.colour(k.tube(pts, radii, m=F.material(surface="horn"), n=8, name="tusk"), tone((236, 214, 168), F.WARM), rng))
        body.append(lump(pts[0] - Vector((0, 0, 0.05)), (0.3, 0.3, 0.2), tone((150, 132, 112), F.COOL), rng))
        for j, tones in ((2, red), (3, ochre)):
            body.append(F.colour(k.tube(circle(pts[j], radii[j] + 0.02, pts[j + 1] - pts[j - 1], 12), 0.04, m=F.material(), n=5, name="binding"), tones, rng))
    body.append(shard(Vector((0, 0.04, H - 0.3)), Vector((0, -0.24, H + 0.85)), 0.5, 0.44, (tone((180, 168, 146), F.WARM), tone((236, 226, 204), F.PALE)), rng, at=0.2, name="horn", surface="horn"))
    body.append(shard(Vector((0, 0.36, H - 0.25)), Vector((0, 0.5, H + 0.22)), 0.26, 0.24, tone((200, 188, 164), F.WARM), rng, at=0.25, name="horn", surface="horn"))
    earth = tone((140, 112, 84), F.WARM)
    body.append(loft("ground", [round_z(0, 0, 0.0, 1.7, 1.7, 14), round_z(0, 0, 0.12, 1.6, 1.6, 14)], earth, rng, surface="rock"))
    rock = [tone(c, F.COOL) for c in ((150, 136, 120), (124, 112, 100))]
    for a, ring, size in ((15, 1.4, 0.26), (60, 1.5, 0.3), (150, 1.45, 0.34), (-150, 1.5, 0.28), (-60, 1.45, 0.3), (-100, 1.55, 0.22), (110, 1.6, 0.2)):
        body.append(lump(out(a, 0) * ring + Vector((0, 0, 0.12 + size * 0.4)), (size, size * 1.1, size * 0.8), rng.choice(rock), rng))
    for a, ring, turn, length in ((-20, 1.35, 70, 0.6), (40, 1.25, -50, 0.5), (-130, 1.2, 30, 0.55), (175, 1.3, 90, 0.45)):  # old bones
        c = out(a, 0) * ring + Vector((0, 0, 0.17))
        d = out(a + turn, 0) * length / 2
        body.append(F.colour(k.tube([c - d, c + d], 0.05, m=F.material(surface="horn"), n=6, name="bone"), bone[0], rng))
        for e in (c - d, c + d):
            for side in (1, -1):
                body.append(lump(e + out(a + turn + 90, 0) * side * 0.04, (0.06, 0.06, 0.06), bone[0], rng, surface=None))
    for i in range(4):  # a ribcage behind
        x = -0.45 + i * 0.3
        rib = [Vector((x + 0.05 * math.sin(t * math.pi), 1.05 + 0.6 * t, 0.12 + 0.62 * math.sin(t * math.pi))) for t in (0, 0.2, 0.4, 0.6, 0.8, 1.0)]
        body.append(F.colour(k.tube(rib, [0.05, 0.05, 0.045, 0.04, 0.035, 0.02], m=F.material(surface="horn"), n=5, name="rib"), bone[i % 2], rng))
    body.append(F.colour(k.tube([Vector((-0.6, 1.35, 0.68)), Vector((0.6, 1.35, 0.68))], 0.06, m=F.material(surface="horn"), n=6, name="spine"), bone[0], rng))
    dry = [tone(c, F.WARM) for c in ((214, 180, 96), (190, 150, 76))]
    for a in (-50, 80, -165, 130):
        tuft(body, out(a, 0) * 1.55 + Vector((0, 0, 0.1)), 4, dry, rng, 0.6, 0.5)
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def wreath(into, egg, z, gold, pale, rng, count=30):
    """A laurel wreath round the shell at height z: a stem with pairs of leaves."""
    pts = []
    for i in range(count + 1):
        at, n = k.land(egg, (0, 0, z), out(i * 360 / count, 0))
        pts.append((at + n * 0.05, n))
    into.append(F.colour(k.tube([p for p, _ in pts], 0.03, m=F.material(), n=5, name="stem"), gold, rng))
    for i in range(count):
        (p, n), (q, _) = pts[i], pts[i + 1]
        along = (q - p).normalized()
        for s in (1, -1):
            into.append(shard(p, p + along * 0.2 + Vector((0, 0, s * 0.11)) + n * 0.03, 0.11, 0.03, pale if (i + (s > 0)) % 2 else gold, rng, face=n, at=0.45, name="leaf"))


def legend_egg():
    """Legend Egg: a royal blue shell wrapped in two gold laurel wreaths, scattered with gold stars, a
    gold shield on its front bearing a glowing star, on a white marble plinth trimmed in gold between two
    crimson banners."""
    rng, g = new_egg(19)
    body, lit, glow = g["body"], g["body_glow"], k.glow(LAUREL)
    egg = shell(tone((40, 74, 196), F.COOL), rng)
    grade(egg, (26, 46, 150), (64, 104, 220), F.COOL, rng)
    body.append(egg)
    gold, pale, deep = tone((255, 200, 60), SHINE), tone((255, 228, 140), SHINE), tone((206, 140, 30), SHINE)
    wreath(body, egg, 0.82, gold, pale, rng)
    wreath(body, egg, 2.2, gold, pale, rng, 24)
    p, (ex, ey, ez) = on_shell(egg, 0, 8, -0.035)  # the shield
    outline = [(-0.32, 0.32), (0.32, 0.32), (0.32, 0.0), (0.2, -0.24), (0.0, -0.4), (-0.2, -0.24), (-0.32, 0.0)]
    body.append(plate("shield", p, (ex, ey, ez), outline, 0.07, deep, rng, lift=0.0))
    body.append(plate("shield", p, (ex, ey, ez), [(x * 0.92, y * 0.92 + 0.01) for x, y in outline], 0.08, gold, rng, lift=0.0))
    body.append(plate("shield", p, (ex, ey, ez), [(x * 0.75, y * 0.75 + 0.02) for x, y in outline], 0.09, tone((190, 30, 50), F.WARM), rng, lift=0.0))
    lit.append(plate("star", p + ey * 0.02, (ex, ey, ez), star(0.19), 0.04, None, rng, lift=0.08, m=glow))
    for i in range(12):  # gold stars
        q, frame = on_shell(egg, i * 30 + 15 + (i % 2) * 8, 30 + (i % 3) * 12 if i % 4 else -28, 0.01)
        if abs(((i * 30 + 15 + 180) % 360) - 180) < 28 and 15 < 30 + (i % 3) * 12 < 52:
            continue  # leave the shield clear
        body.append(plate("star", q, frame, star(0.09), 0.02, pale, rng, lift=0.0))
    for i in range(8):  # gold bosses round the top
        body.append(stud(egg, i * 45, 68, 0.07, ((1.0, 0.0), (0.7, 0.9), (0.3, 1.1)), (pale, pale, pale), rng))
    body.append(lump(Vector((0, 0, H)), (0.13, 0.13, 0.1), gold, rng, surface=None))
    body.append(shard(Vector((0, 0, H + 0.05)), Vector((0, 0, H + 0.35)), 0.1, 0.1, pale, rng, at=0.3, name="finial"))
    marble = [tone(c, F.PALE) for c in ((242, 238, 230), (226, 222, 214))]
    rings = [round_z(0, 0, z, w, w, 8) for z, w in ((0.0, 1.65), (0.13, 1.65), (0.15, 1.42), (0.4, 1.34), (0.42, 1.5), (0.54, 1.5))]
    body.append(loft("plinth", rings, marble[0], rng))
    body.append(loft("trim", [round_z(0, 0, z, 1.52, 1.52, 8) for z in (0.45, 0.5)], gold, rng))
    body.append(loft("trim", [round_z(0, 0, z, 1.67, 1.67, 8) for z in (0.06, 0.1)], gold, rng))
    for i in range(8):  # fluting on the plinth's waist
        a = (i + 0.5) * math.tau / 8
        c = Vector((math.cos(a) * 1.25, math.sin(a) * 1.25, 0.27))
        body.append(lump(c, (0.07, 0.07, 0.09), marble[1], rng, surface=None))
    crimson, dark = tone((196, 26, 44), F.WARM), tone((150, 16, 34), F.WARM)
    for s in (1, -1):  # the banners
        pole = Vector((s * 1.62, 0.45, 0.0))
        body.append(F.colour(k.tube([pole, pole + Vector((0, 0, 2.95))], 0.04, m=F.material(), n=6, name="pole"), gold, rng))
        body.append(lump(pole + Vector((0, 0, 2.98)), (0.07, 0.07, 0.07), pale, rng, surface=None))
        body.append(shard(pole + Vector((0, 0, 3.0)), pole + Vector((0, 0, 3.28)), 0.12, 0.05, pale, rng, face=(0, -1, 0), at=0.3, name="spike"))
        bar = pole + Vector((0, -0.06, 2.78))
        body.append(F.colour(k.tube([bar - Vector((0.3, 0, 0)), bar + Vector((0.3, 0, 0))], 0.03, m=F.material(), n=5, name="bar"), gold, rng))
        front = (Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)))
        cloth = [(-0.27, 0.0), (-0.27, -1.15), (0.0, -0.92), (0.27, -1.15), (0.27, 0.0)]
        body.append(plate("banner", bar - Vector((0, 0, 0.03)), front, cloth, 0.03, crimson, rng, lift=0.0))
        body.append(plate("banner", bar - Vector((0, 0, 0.03)), front, [(x * 0.8, y * 0.92 - 0.05) for x, y in cloth], 0.03, dark, rng, lift=0.012))
        body.append(plate("star", bar - Vector((0, 0, 0.42)), front, star(0.13), 0.02, pale, rng, lift=0.03))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def mythic_egg():
    """Mythic Egg: a magenta crystal cut into broad facets, glowing pink runes on it, crystal shards
    floating round it, on a dark crystal cluster."""
    rng, g = new_egg(23)
    body, lit, glow = g["body"], g["body_glow"], k.glow(RUNE)
    heights = (0.04, 0.4, 0.82, 1.2, 1.66, 2.14, 2.58, 2.9)
    rings = [[(math.cos((j + 0.5 * (i % 2)) * math.tau / 8) * radius(z) * 1.06, math.sin((j + 0.5 * (i % 2)) * math.tau / 8) * radius(z) * 1.06, z) for j in range(8)] for i, z in enumerate(heights)]
    faces = (len(rings) - 1) * 8 + 2
    egg = loft("shell", rings, [tone(rng.choice(((170, 22, 120), (150, 18, 110), (190, 34, 140))), F.COOL) for _ in range(faces)], rng, surface="gem", emit=0.1)
    body.append(egg)
    runes = (((0, 0), (0, 22), (10, 14)), ((-10, 6), (0, 16), (10, 6), (0, -4), (-10, 6)), ((-8, 20), (8, 20), (-8, 0), (8, 0)), ((0, 0), (0, 22), (-9, 10), (9, 10)), ((-9, 0), (0, 20), (9, 0)))
    for i, (az, el) in enumerate(((0, -6), (60, 20), (120, -10), (180, 14), (240, -8), (300, 18), (30, 42), (150, 44), (270, 46), (-25, -36), (95, -38), (215, -36))):
        shape = runes[i % len(runes)]
        for a, b in zip(shape, shape[1:]):
            lit.append(stroke(egg, (az + a[0] * 1.3, el + a[1] * 1.3), (az + b[0] * 1.3, el + b[1] * 1.3), 0.12, None, rng, lift=0.04, m=glow))
    lit.append(shard(Vector((0, 0, H - 0.2)), Vector((0, 0, H + 0.55)), 0.3, 0.3, None, rng, at=0.35, m=glow, name="spire"))
    pink = (tone((240, 90, 190), F.COOL), tone((255, 190, 236), F.PALE))
    violet = (tone((150, 60, 210), F.COOL), tone((220, 160, 255), F.PALE))
    for i in range(9):  # shards floating round it
        a, z = i * 40 + rng.uniform(-8, 8), 0.7 + (i * 0.67) % 2.0
        c = out(a, 0) * rng.uniform(1.6, 1.85) + Vector((0, 0, z))
        lean = (out(a, 0) * rng.uniform(-0.2, 0.3) + Vector((0, 0, 1))).normalized()
        size = rng.uniform(0.38, 0.6)
        if i % 3 == 0:
            lit.append(shard(c - lean * size * 0.3, c + lean * size * 0.5, size * 0.3, size * 0.3, None, rng, at=0.4, m=glow, name="shard"))
        else:
            body.append(shard(c - lean * size / 2, c + lean * size / 2, size * 0.4, size * 0.36, pink if i % 2 else violet, rng, at=0.4, name="shard", surface="gem", emit=0.3))
    dark = [tone(c, F.COOL) for c in ((70, 34, 96), (96, 46, 126), (52, 26, 74))]
    body.append(loft("base", [round_z(0, 0, 0.0, 1.5, 1.5, 9), round_z(0, 0, 0.16, 1.3, 1.3, 9)], tone((40, 26, 56), F.COOL), rng, surface="rock"))
    for i in range(22):  # the cluster: dark crystals leaning out from under it
        a = i * 360 / 22 + rng.uniform(-6, 6)
        d = out(a, 0)
        root = d * rng.uniform(0.6, 1.1) + Vector((0, 0, 0.08))
        tall = rng.uniform(0.45, 0.95) * (1.25 if i % 4 == 0 else 1.0)
        tip = root + (d * rng.uniform(0.35, 0.7) + Vector((0, 0, 1))).normalized() * tall
        if i % 5 == 2:
            lit.append(shard(root, tip, 0.18, 0.18, None, rng, at=0.35, m=glow, name="crystal"))
        else:
            body.append(shard(root, tip, rng.uniform(0.2, 0.3), 0.22, (dark[i % 3], tone((150, 80, 180), F.COOL)), rng, at=0.35, name="crystal", surface="gem", emit=0.1))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def divine_egg():
    """Divine Egg: a pearl-white shell traced with gold filigree, a pair of white feathered wings from its
    sides, a glowing gold halo above it, on a bank of white cloud."""
    rng, g = new_egg(29)
    body, lit, glow = g["body"], g["body_glow"], k.glow(HALO)
    egg = shell(tone((252, 246, 238), F.PALE), rng)
    body.append(egg)
    gold, pale = tone((240, 190, 70), SHINE), tone((255, 226, 140), SHINE)
    for i in range(8):  # filigree: a gold stem down each side with leaves, a curl at each end
        az = i * 45 + 22.5
        rays = [(tuple(CENTRE), out(az + 4 * math.sin(j * 0.5), 66 - j * 11)) for j in range(10)]
        body.append(F.colour(k.vein(egg, rays, 0.05, F.material(), lift=0.005, name="filigree"), gold, rng))
        pts = [k.land(egg, CENTRE, d) for _, d in rays]
        for j in range(1, 9):
            (p, n), (q, _) = pts[j], pts[j + 1]
            along = (q - p).normalized()
            side = n.cross(along).normalized() * (1 if j % 2 else -1)
            body.append(shard(p + n * 0.01, p + side * 0.15 - along * 0.08 + n * 0.01, 0.08, 0.02, pale, rng, face=n, at=0.5, name="leaf"))
        for cel in (-36, 75):
            for j in range(6):
                body.append(stroke(egg, (az + 6 * math.cos(j * 1.05), cel + 6 * math.sin(j * 1.05)), (az + 6 * math.cos(j * 1.05 + 1.05), cel + 6 * math.sin(j * 1.05 + 1.05)), 0.05, gold, rng, lift=0.01))
    body.append(band(1.25, 0.06, 0.02, pale, rng))
    body.append(band(0.42, 0.06, 0.02, gold, rng))
    for i in range(16):
        at, n = k.land(egg, (0, 0, 1.25), out(i * 22.5, 0))
        body.append(lump(at + n * 0.05, (0.05, 0.05, 0.05), tone((250, 244, 236), F.PALE), rng, surface=None))
    white = [tone(c, F.PALE) for c in ((255, 255, 255), (232, 238, 252), (244, 246, 255))]
    for s in (1, -1):  # the wings: an arm swept up and out, feathers hanging from it, longest at the tip
        root, n = k.land(egg, CENTRE, out(s * 92, 14))
        side, back = Vector((s, 0, 0)), Vector((0, 0.18, 0))
        arm = [root + side * 0.02, root + side * 0.5 + Vector((0, 0.08, 0.5)), root + side * 0.95 + Vector((0, 0.16, 1.1))]
        body.append(F.colour(k.tube(arm, [0.1, 0.08, 0.04], m=F.material(), n=6, name="arm"), white[0], rng))
        for row, (count, reach, width) in enumerate(((9, 1.25, 0.32), (7, 0.7, 0.3), (5, 0.4, 0.28))):
            for j in range(count):
                t = (j + 0.5) / count
                a = arm[0].lerp(arm[1], t * 2) if t < 0.5 else arm[1].lerp(arm[2], t * 2 - 1)
                d = (Vector((0, 0, -1)) + side * (0.25 + 0.45 * t) + back).normalized()
                length = reach * (0.45 + 0.55 * t)
                base = a + Vector((0, -0.05 * row, 0))
                body.append(shard(base, base + d * length, width, 0.05, white[(j + row) % 3], rng, face=(0, -1, 0), at=0.4, name="feather"))
        body.append(lump(root + side * 0.06, (0.15, 0.12, 0.15), white[0], rng, surface=None))
        body.append(lump(arm[2], (0.06, 0.06, 0.06), pale, rng, surface=None))
    halo = circle(Vector((0, 0.06, H + 0.42)), 0.58, Vector((0, 0.25, 1)), 30)
    lit.append(k.tube(halo, 0.065, m=glow, n=6, name="halo"))
    cloud = [tone(c, F.PALE) for c in ((255, 255, 255), (236, 240, 252), (222, 230, 248))]
    for i in range(20):  # the cloud bank
        a = i * 360 / 20 + rng.uniform(-6, 6)
        ring = 1.05 + (i % 3) * 0.25
        size = rng.uniform(0.32, 0.44)
        body.append(lump(out(a, 0) * ring + Vector((0, 0, size * 0.55 + (i % 2) * 0.08)), (size, size, size * 0.75), cloud[i % 3], rng, surface=None))
    for i in range(6):
        body.append(lump(out(i * 60 + 30, 0) * 0.75 + Vector((0, 0, 0.3)), (0.4, 0.4, 0.3), cloud[0], rng, surface=None))
    for a, ring, z in ((-40, 1.85, 0.9), (55, 1.9, 1.6), (150, 1.8, 2.2), (-130, 1.85, 1.3)):  # sparkles
        c = out(a, 0) * ring + Vector((0, 0, z))
        for d in (Vector((0, 0, 0.16)), Vector((0.12, 0, 0))):
            body.append(shard(c - d, c + d, 0.07, 0.04, pale, rng, face=(0, -1, 0), name="sparkle"))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def celestial_egg():
    """Celestial Egg: a night-sky shell scattered with glowing stars and constellations, two tilted orbits
    round it carrying small planets, a glowing star on its top, on a dark base set with a glowing crescent."""
    rng, g = new_egg(31)
    body, lit, glow = g["body"], g["body_glow"], k.glow(STARLIGHT)
    egg = shell(tone((28, 34, 90), F.COOL), rng)
    grade(egg, (14, 18, 56), (44, 52, 130), F.COOL, rng)
    body.append(egg)
    for i in range(34):  # stars
        at, n = k.land(egg, CENTRE, out(i * 137.5, -50 + (i * 47) % 120))
        r = rng.uniform(0.025, 0.045)
        lit.append(lump(at + n * 0.01, (r, r, r), None, rng, m=glow))
    for pattern in (((-30, 30), (-14, 40), (2, 34), (14, 46), (30, 40)), ((100, -10), (112, 6), (128, 2), (122, -16), (100, -10)), ((200, 20), (214, 34), (230, 26), (240, 42)), ((290, -20), (300, 0), (316, 4), (330, -12))):
        for a, b in zip(pattern, pattern[1:]):
            lit.append(stroke(egg, a, b, 0.03, None, rng, lift=0.02, m=glow))
        for az, el in pattern:
            at, n = k.land(egg, CENTRE, out(az, el))
            lit.append(lump(at + n * 0.03, (0.06, 0.06, 0.06), None, rng, m=glow))
    top = Vector((0, 0, H + 0.32))  # a star on its top
    for d in (Vector((0, 0, 0.3)), Vector((0.22, 0, 0))):
        lit.append(shard(top - d, top + d, 0.14, 0.08, None, rng, face=(0, -1, 0), m=glow, name="star"))
    silver, brass = tone((206, 214, 236), F.COOL), tone((236, 196, 110), SHINE)
    for r, normal, tones in ((1.58, (0.36, 0.1, 0.93), brass), (1.8, (-0.2, -0.46, 0.87), silver)):
        body.append(F.colour(k.tube(circle(CENTRE, r, normal, 48), 0.04, m=F.material(), n=6, cap=False, name="orbit"), tones, rng))
    orbit1 = circle(CENTRE, 1.58, (0.36, 0.1, 0.93), 48)
    orbit2 = circle(CENTRE, 1.8, (-0.2, -0.46, 0.87), 48)
    planets = ((orbit1[8], 0.17, (240, 140, 60)), (orbit1[30], 0.1, (200, 200, 214)), (orbit2[20], 0.14, (80, 200, 190)), (orbit2[40], 0.11, (230, 90, 110)))
    for c, size, rgb in planets:
        body.append(lump(c, (size, size, size), tone(rgb, F.WARM), rng, surface=None))
    ringed = planets[2]
    body.append(F.colour(k.tube(circle(ringed[0], 0.24, (0.3, -0.3, 1), 16), 0.025, m=F.material(), n=4, cap=False, name="ring"), silver, rng))
    body.append(loft("base", [round_z(0, 0, 0.0, 1.6, 1.6, 14), round_z(0, 0, 0.18, 1.6, 1.6, 14), round_z(0, 0, 0.26, 1.45, 1.45, 14)], tone((30, 32, 62), F.COOL), rng, surface="rock"))
    arc = [out(a, 0) * 1.25 + Vector((0, 0, 0.27)) for a in range(-80, 81, 10)]
    lit.append(k.tube([p + out(0, 0) * 0.14 * math.sin(math.pi * i / (len(arc) - 1)) for i, p in enumerate(arc)], [0.12 * math.sin(math.pi * i / (len(arc) - 1)) ** 0.8 + 0.005 for i in range(len(arc))], m=glow, n=6, name="crescent"))
    for i in range(10):  # rocks of night round the base
        a = i * 36 + 18
        if -90 < ((a + 180) % 360) - 180 < 90:
            continue
        body.append(lump(out(a, 0) * 1.55 + Vector((0, 0, 0.2)), (0.24, 0.24, 0.18), tone((44, 44, 82), F.COOL), rng))
    for i in range(6):
        lit.append(lump(out(i * 60 + 10, 0) * 1.45 + Vector((0, 0, 0.27)), (0.03, 0.03, 0.03), None, rng, m=glow))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


def squircle(z, w, n=16, p=0.35):
    return [(math.copysign(abs(math.cos((i + 0.5) * math.tau / n)) ** p, math.cos((i + 0.5) * math.tau / n)) * w, math.copysign(abs(math.sin((i + 0.5) * math.tau / n)) ** p, math.sin((i + 0.5) * math.tau / n)) * w, z) for i in range(n)]


def crown_egg():
    """Crown Egg (for clearing wave 300): a ruby shell in a gold filigree cage, girdled with rainbow gems,
    crowned with a tall arched crown set with rainbow gems round a glowing diamond, on a red velvet
    cushion with gold piping and tassels."""
    rng, g = new_egg(37)
    body, lit, glow = g["body"], g["body_glow"], k.glow(PRISM)
    egg = shell(tone((206, 34, 58), F.WARM), rng, surface="gem")
    grade(egg, (150, 16, 40), (236, 64, 86), F.WARM, rng)
    body.append(egg)
    gold, pale, deep = tone((255, 200, 60), SHINE), tone((255, 228, 140), SHINE), tone((206, 140, 30), SHINE)
    for i in range(6):  # the cage: gold wires wound both ways
        for turns in (0.45, -0.45):
            body.append(wound(egg, turns, 0.3, 2.55, 0.04, gold, rng, phase=i * math.tau / 6, steps=18)[0])
    for z, h in ((1.2, 0.16), (0.42, 0.08)):
        body.append(band(z, h, 0.04, pale, rng))
        body.append(band(z + h * 0.6, 0.03, 0.055, deep, rng))
        body.append(band(z - h * 0.6, 0.03, 0.055, deep, rng))
    cut = ((1.0, 0.0), (0.9, 0.3), (0.5, 0.52), (0.22, 0.56))
    el = math.degrees(math.atan2(1.2 - CENTRE.z, R))
    for i in range(14):  # rainbow gems round the girdle, gold bosses between
        rgb = RAINBOW[i % 7]
        gem = (tone(k.mix(rgb, (0, 0, 40), 0.3), SHINE), tone(rgb, F.COOL), tone(k.mix(rgb, (255, 255, 255), 0.4), F.COOL), tone(k.mix(rgb, (255, 255, 255), 0.6), F.COOL))
        body.append(stud(egg, i * 360 / 14, el, 0.15, ((1.0, 0.0), (1.0, 0.14), (0.85, 0.18)), (deep, pale, pale), rng))
        body.append(stud(egg, i * 360 / 14, el, 0.15, [(f * 0.78, 0.18 + h_) for f, h_ in cut], gem, rng, emit=0.7, surface="gem"))
    for i in range(12):  # pearls where the wires cross, round the middle of the cage
        at, n = k.land(egg, (0, 0, 1.85), out(i * 30 + 15, 0))
        body.append(lump(at + n * 0.06, (0.05, 0.05, 0.05), tone((250, 244, 236), F.PALE), rng, surface=None))
    # the crown
    body.append(lump(Vector((0, 0, H - 0.08)), (0.62, 0.62, 0.3), tone((170, 20, 46), F.WARM), rng, surface="fur"))
    body.append(loft("circlet", [round_z(0, 0, z, w, w, 20) for z, w in ((2.5, 0.8), (2.56, 0.86), (2.86, 0.82), (2.92, 0.86), (2.96, 0.8))], gold, rng, surface="horn"))
    for i in range(10):  # points round the circlet, a gem on each, painted in turn
        d = out(i * 36, 0)
        tall = 0.78 if i % 2 == 0 else 0.5
        body.append(shard(Vector((0, 0, 2.86)) + d * 0.8, Vector((0, 0, 2.92 + tall)) + d * 0.88, 0.3, 0.1, (gold, pale), rng, face=d, at=0.3, name="point"))
        rgb = RAINBOW[i % 7]
        body.append(lump(Vector((0, 0, 2.96 + tall)) + d * 0.89, (0.06, 0.06, 0.06), tone(rgb, F.COOL), rng, surface="gem"))
        body.append(lump(Vector((0, 0, 2.72)) + d * 0.88, (0.08, 0.05, 0.08) if abs(d.y) > 0.7 else (0.05, 0.08, 0.08), tone(RAINBOW[(i + 3) % 7], F.COOL), rng, surface="gem"))
    for a in (0, 90):  # two arches over the top
        d = out(a, 0)
        pts = [Vector((0, 0, 2.94)) + d * 0.8 * math.cos(math.pi * t / 10) + Vector((0, 0, 0.95 * math.sin(math.pi * t / 10))) for t in range(11)]
        body.append(F.colour(k.tube(pts, 0.055, m=F.material(), n=6, name="arch"), gold, rng))
        for t in (2, 8):
            body.append(lump(pts[t], (0.06, 0.06, 0.06), tone(RAINBOW[(t + a // 30) % 7], F.COOL), rng, surface="gem"))
    orb = Vector((0, 0, 3.98))
    body.append(lump(orb, (0.14, 0.14, 0.14), gold, rng, surface=None))
    lit.append(shard(orb + Vector((0, 0, 0.08)), orb + Vector((0, 0, 0.5)), 0.08, 0.08, None, rng, at=0.5, m=glow, name="cross"))
    lit.append(shard(orb + Vector((-0.14, 0, 0.32)), orb + Vector((0.14, 0, 0.32)), 0.08, 0.08, None, rng, at=0.5, m=glow, name="cross"))
    lit.append(shard(Vector((0, 0, 3.05)), Vector((0, 0, 3.6)), 0.4, 0.4, None, rng, at=0.4, m=glow, name="diamond"))
    # the cushion
    velvet = tone((156, 18, 44), F.WARM)
    body.append(loft("cushion", [squircle(z, w) for z, w in ((0.0, 1.32), (0.1, 1.55), (0.22, 1.5), (0.33, 1.15))], velvet, rng, surface="fur"))
    body.append(F.colour(k.tube([Vector(p) for p in squircle(0.1, 1.57)] + [Vector(squircle(0.1, 1.57)[0])], 0.04, m=F.material(), n=5, name="piping"), gold, rng))
    for i in range(4):  # gold tassels at the corners
        cx, cy = (1.0 if i in (0, 3) else -1.0), (1.0 if i < 2 else -1.0)
        corner = Vector((cx * 1.36, cy * 1.36, 0.2))
        body.append(lump(corner, (0.12, 0.12, 0.1), pale, rng, surface=None))
        for j in range(7):
            foot = corner + Vector((cx, cy, 0)).normalized() * 0.12 + Vector((math.cos(j * 0.9), math.sin(j * 0.9), 0)) * 0.09
            body.append(shard(corner, Vector((foot.x, foot.y, 0.01)), 0.08, 0.04, gold, rng, at=0.25, name="tassel"))
    return {name: parts for name, parts in g.items() if parts}, {}  # no empty pieces


ASSETS = [
    F.asset("egg_meadow", meadow_egg, 1.0, {}, "Meadow Egg: cream dappled green, in a nest of grass and daisies, a flowering vine, a butterfly."),
    F.asset("egg_wild", wild_egg, 1.0, {"body_glow": SPORE}, "Wild Egg: leaf-green with bark spots, bound in thorned vines, ferns and Neon mushrooms at its foot."),
    F.asset("egg_safari", safari_egg, 1.0, {}, "Safari Egg: sand-gold, spotted and painted, roped and strapped, hung with feathers and a tooth."),
    F.asset("egg_golden", golden_egg, 1.0, {"body_glow": ROYAL}, "Golden Egg: beaten gold, hooped and ribbed, set with Neon violet gems, crowned, on a clawed stand."),
    F.asset("egg_dusk", dusk_egg, 1.0, {"body_glow": AMBER}, "Dusk Egg: indigo to violet, gold hieroglyph bands, a scarab, Neon eyes of Horus and lamps, a crescent moon, on a sandstone step."),
    F.asset("egg_oasis", oasis_egg, 1.0, {}, "Oasis Egg: turquoise with pink flamingo-feather stripes, in a pool with lily pads and a lotus, two palms behind."),
    F.asset("egg_ivory", ivory_egg, 1.0, {}, "Ivory Egg: ivory in ochre and red war paint, two great tusks round its sides, a rhino horn, on rocks and bones."),
    F.asset("egg_legend", legend_egg, 1.0, {"body_glow": LAUREL}, "Legend Egg: royal blue in gold laurel wreaths, a shield with a Neon star, on a marble plinth between crimson banners."),
    F.asset("egg_mythic", mythic_egg, 1.0, {"body_glow": RUNE}, "Mythic Egg: a faceted magenta crystal with Neon pink runes, floating shards, on a dark crystal cluster."),
    F.asset("egg_divine", divine_egg, 1.0, {"body_glow": HALO}, "Divine Egg: pearl white with gold filigree, white feathered wings, a Neon gold halo, on a bank of cloud."),
    F.asset("egg_celestial", celestial_egg, 1.0, {"body_glow": STARLIGHT}, "Celestial Egg: a night sky of Neon stars and constellations, two orbits with planets, on a base with a Neon crescent."),
    F.asset("egg_crown", crown_egg, 1.0, {"body_glow": PRISM}, "Crown Egg: ruby in a gold cage, rainbow gems, a tall arched crown round a Neon diamond, on a velvet cushion."),
]
