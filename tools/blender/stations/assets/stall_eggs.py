"""Concept: the egg vendor's market stall (render only, not a game model yet).

A carved wooden stall in purple and gold: chunky posts and braces, a planked two-tier counter with
ten straw nests holding the game's own eggs (built by assets/eggs.py, their ground dressing left
off, at 0.55 size), a striped purple awning with a scalloped, gold-trimmed valance and tassels, a
draped back curtain, purple banners and a counter runner with egg emblems, a gold-framed sign board
with a crowned egg crest (its face left plain for the game's lettering), two iron lanterns, crates,
sacks, a barrel, a chalkboard easel, a vine, a brass scale and a coin pouch, glowing violet
crystals, on a patch of stone paving. No vendor: the game stands its own there.

Built where it stands (front towards -Y, the paving's top z = 0.3); the pieces are sorted by
stage.sort_pieces into `body` and a Neon piece for each glowing colour.
"""

import importlib.util
import math
import os
import random

import bpy
import facet as F
import kit as k
import stage as S
from mathutils import Matrix, Vector

_spec = importlib.util.spec_from_file_location("eggs_for_vendor", os.path.join(os.path.dirname(os.path.abspath(__file__)), "eggs.py"))
E = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(E)

Z0 = 0.3  # the top of the paving
WOOD, WOOD_DARK, WOOD_LIGHT, WOOD_MID = (170, 112, 64), (112, 70, 42), (204, 150, 92), (186, 126, 74)
PURPLE, PURPLE_DEEP, PURPLE_PALE = (134, 62, 196), (92, 38, 146), (176, 120, 226)
GOLD, BRASS = (252, 200, 70), (214, 160, 70)
IRON = (64, 62, 74)
STRAW, STRAW_DARK = (236, 200, 112), (196, 150, 74)
LEAF = (78, 150, 70)
VIOLET, VIOLET_PALE = (176, 96, 255), (226, 186, 255)
FLAME, FLAME_CORE = (255, 156, 48), (255, 232, 150)
X, Y, ZV = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FRONT = (X, ZV, -Y)  # a plate frame on a face looking towards -Y

TOP_EGGS = ("egg_legend", "egg_mythic", "egg_crown", "egg_celestial", "egg_divine")
LOW_EGGS = ("egg_meadow", "egg_safari", "egg_golden", "egg_dusk", "egg_oasis")


def gold(ob, rng):
    return S.paint(ob, GOLD, rng, kind=E.SHINE)


def placed(matrix, fn, *a, **kw):
    """Runs fn (which builds pieces about the origin) and moves every new piece by `matrix`."""
    before = {ob.name for ob in bpy.data.objects}
    fn(*a, **kw)
    for ob in bpy.data.objects:
        if ob.name not in before and ob.type == "MESH":
            ob.data.transform(matrix)


def at(p, yaw=0.0, tilt=0.0):
    return Matrix.Translation(Vector(p)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(tilt), 4, "X")


def sheet(f, nu, nv, thick, rgb, rng, kind=F.WARM, surface=None, chance=0.12):
    """A closed cloth (or board) of thickness `thick` round the surface f(u, v) -> point, u and v in 0..1."""
    top, bot = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            p = Vector(f(u, v))
            du = Vector(f(min(u + 1e-3, 1), v)) - Vector(f(max(u - 1e-3, 0), v))
            dv = Vector(f(u, min(v + 1e-3, 1))) - Vector(f(u, max(v - 1e-3, 0)))
            n = du.cross(dv).normalized()
            top.append(p + n * thick / 2)
            bot.append(p - n * thick / 2)
    N = len(top)

    def idx(i, j):
        return j * (nu + 1) + i

    faces = []
    for j in range(nv):
        for i in range(nu):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            faces += [(a, b, c, d), (N + d, N + c, N + b, N + a)]
    rim = [idx(i, 0) for i in range(nu)] + [idx(nu, j) for j in range(nv)] + [idx(i, nv) for i in range(nu, 0, -1)] + [idx(0, j) for j in range(nv, 0, -1)]
    for m in range(len(rim)):
        a, b = rim[m], rim[(m + 1) % len(rim)]
        faces.append((a, b, N + b, N + a))
    return F.mesh("cloth", top + bot, faces, F.tone(rgb, kind), rng, chance=chance, surface=surface)


def egg2d(w, h, n=20):
    """An egg's outline, w wide and h tall, round its middle."""
    out = []
    for i in range(n):
        a = math.tau * i / n
        y = -math.cos(a)
        out.append((math.sin(a) * (1 - 0.14 * y) * w / 2, y * h / 2))
    return out


def plate(p, outline, thick, rgb, rng, frame=FRONT, kind=F.WARM, **kw):
    return F.plate("plate", Vector(p), frame, outline, thick, F.tone(rgb, kind), rng, **kw)


def tassel(top, rng, length=0.5):
    S.post(0.05, 0.22, Vector(top) - Vector((0, 0, 0.1)), GOLD, rng, n=6, r2=0.15, kind=E.SHINE)
    for i in range(3):
        d = Vector((math.cos(i * 2.09 + 0.4), math.sin(i * 2.09 + 0.4), 0)) * 0.08
        S.shard(Vector(top) + d * 0.5, Vector(top) + d - Vector((0, 0, length)), 0.07, 0.04, GOLD, rng, kind=E.SHINE, at=0.25)


# The ground -------------------------------------------------------------------------------------------


def paving(rng):
    S.box((34.4, 14.4, 0.2), (0, -1.5, 0.0), (92, 88, 92), rng, kind=F.COOL)  # the grout under the stones
    stones = ((178, 170, 160), (160, 156, 150), (192, 182, 166), (150, 146, 146))
    y = -8.6
    row = 0
    while y < 5.5:
        h = rng.uniform(1.8, 2.2)
        x = -17.1 + (0.0 if row % 2 else -1.0)
        while x < 17.1:
            w = rng.uniform(2.1, 2.8)
            x0, x1 = max(x, -17.1), min(x + w, 17.1)
            y1 = min(y + h, 5.6)
            if x1 - x0 > 0.4:
                j = [rng.uniform(-0.06, 0.06) for _ in range(8)]
                outline = [(x0 + 0.08 + j[0], y + 0.08 + j[1]), (x1 - 0.08 + j[2], y + 0.08 + j[3]), (x1 - 0.08 + j[4], y1 - 0.08 + j[5]), (x0 + 0.08 + j[6], y1 - 0.08 + j[7])]
                S.prism(outline, (0, 0, 0.0), Z0 + rng.uniform(-0.03, 0.03), rng.choice(stones), rng, kind=F.COOL, surface="rock")
            x += w
        y += h
        row += 1


# The stall ----------------------------------------------------------------------------------------------


def post(x, y, top, rng):
    """A chunky carved post: a plinth, an eight-sided shaft with collars, a flared capital."""
    S.box((1.7, 1.7, 0.7), (x, y, Z0), WOOD_DARK, rng, bevel=0.12)
    S.post(0.62, top - Z0, (x, y, Z0), WOOD, rng, n=8, surface="horn")
    for z in (Z0 + 0.7, 4.4, 9.0):
        S.post(0.74, 0.32, (x, y, z), WOOD_DARK, rng, n=8)
    S.post(0.62, 0.7, (x, y, top - 0.7), WOOD_DARK, rng, n=8, r2=0.9)


def stall(rng):
    for sx in (-13.6, 13.6):
        post(sx, -4.2, 12.2, rng)
        post(sx, 3.6, 14.6, rng)
        S.pipe([(sx, -4.2, 12.75), (sx, 3.6, 15.1)], 0.45, WOOD_DARK, rng, n=4)  # the side beams
        s = 1 if sx > 0 else -1
        S.pipe([(sx, -4.2, 9.6), (sx - s * 2.6, -4.2, 12.3)], 0.24, WOOD_DARK, rng, n=4)  # knee braces
        S.pipe([(sx, 3.6, 12.0), (sx - s * 2.6, 3.6, 14.7)], 0.24, WOOD_DARK, rng, n=4)
        S.pipe([(sx, -3.6, 10.4), (sx, -1.0, 13.4)], 0.22, WOOD_DARK, rng, n=4)
        S.box((0.4, 7.0, 4.0), (sx, -0.3, Z0), WOOD, rng, surface="horn")  # the side boards
        for yy in (-2.6, -0.3, 2.0):
            S.box((0.5, 0.25, 4.0), (sx, yy, Z0), WOOD_DARK, rng)
    S.box((29.6, 0.9, 1.1), (0, -4.2, 12.2), WOOD_DARK, rng, surface="horn")  # the front beam
    S.box((29.6, 0.9, 1.0), (0, 3.6, 14.6), WOOD_DARK, rng, surface="horn")  # the back beam
    S.box((27.0, 0.4, 14.3), (0, 3.4, Z0), WOOD_DARK, rng, surface="horn")  # the back wall
    for i in range(13):
        S.box((0.3, 0.2, 14.3), (-12.6 + i * 2.1, 3.7, Z0), WOOD, rng)  # battens on its back

    # the lower counter
    S.box((25.6, 3.0, 4.0), (0, -1.9, Z0), WOOD_DARK, rng)
    S.box((26.4, 3.6, 0.5), (0, -1.9, Z0), WOOD_DARK, rng, bevel=0.06)
    for i in range(25):
        x = -12.48 + i * 1.04
        S.box((0.98, 0.18, 3.15), (x, -3.49, Z0 + 0.5), WOOD if i % 2 else WOOD_MID, rng, surface="horn")
    S.box((26.4, 0.3, 0.35), (0, -3.6, Z0 + 3.65), WOOD_DARK, rng)
    for i, yy in enumerate((-3.25, -2.12, -0.99)):
        S.box((26.6, 1.1, 0.3), (0, yy, Z0 + 4.0), WOOD_LIGHT if i % 2 else WOOD, rng, surface="horn", bevel=0.04)
    gold(k.box((26.6, 0.08, 0.12), (0, -3.84, 4.44)), rng)
    # the upper tier
    S.box((25.6, 3.2, 6.3), (0, 1.2, Z0), WOOD_DARK, rng)
    for i in range(25):
        x = -12.48 + i * 1.04
        S.box((0.98, 0.18, 1.7), (x, -0.49, 4.6), WOOD_MID if i % 2 else WOOD, rng, surface="horn")
    S.box((26.4, 0.3, 0.3), (0, -0.55, 6.3), WOOD_DARK, rng)
    for i, yy in enumerate((-0.17, 0.98, 2.13)):
        S.box((26.6, 1.15, 0.3), (0, yy, 6.6), WOOD_LIGHT if i % 2 else WOOD, rng, surface="horn", bevel=0.04)
    gold(k.box((26.6, 0.08, 0.12), (0, -0.79, 6.74)), rng)
    # carved egg rosettes on the counter's corner boards
    for sx in (-12.48, 12.48):
        plate((sx, -3.58, 2.4), egg2d(0.62, 0.86), 0.06, WOOD_DARK, rng)
        gold(F.plate("plate", Vector((sx, -3.64, 2.4)), FRONT, egg2d(0.3, 0.42), 0.05, F.tone(GOLD, E.SHINE), rng), rng)


def curtain(rng):
    """The purple drape behind the eggs, on a gold rod."""
    sheet(lambda u, v: (-13.0 + 26.0 * u, 3.02 - 0.2 * (1 - math.cos(math.tau * u * 13)) / 2, 14.3 - v * 7.6), 39, 1, 0.06, PURPLE_DEEP, rng)
    S.pipe([(-13.3, 2.92, 14.32), (13.3, 2.92, 14.32)], 0.09, GOLD, rng, kind=E.SHINE)
    for x in range(-13, 14, 2):  # rings on the rod
        gold(k.cyl(0.14, 0.08, (x, 2.92, 14.32), (0, 90, 0), n=8), rng)


def awning(rng):
    """Ten folded purple panels, a scalloped valance with gold piping and tassels front and sides."""
    x0, w, slope = -14.6, 2.92, 0.3
    edge = []
    for p in range(10):
        rgb = PURPLE if p % 2 == 0 else PURPLE_DEEP

        def roof(u, v, p=p):
            y = -5.4 + v * 9.3
            return (x0 + (p + u) * w, y, 13.0 + (y + 5.4) * slope + 0.32 * math.sin(math.pi * u))

        sheet(roof, 6, 1, 0.12, rgb, rng)

        def valance(u, v, p=p):
            drop = 0.55 + 0.75 * math.sin(math.pi * u) ** 0.7
            return (x0 + (p + u) * w, -5.42 - 0.1 * math.sin(math.pi * u), 13.0 + 0.32 * math.sin(math.pi * u) - v * drop)

        sheet(valance, 8, 1, 0.08, rgb, rng)
        edge += [Vector(valance(i / 4, 1)) + Vector((0, -0.05, 0)) for i in range(4 + (p == 9))]
        tassel(Vector(valance(0.5, 1)) + Vector((0, -0.06, -0.06)), rng)
        S.pipe([(x0 + p * w, -5.4, 13.03), (x0 + p * w, 3.9, 13.03 + 9.3 * slope)], 0.06, GOLD, rng, kind=E.SHINE, n=4)  # seams
    S.pipe([(14.6, -5.4, 13.03), (14.6, 3.9, 13.03 + 9.3 * slope)], 0.06, GOLD, rng, kind=E.SHINE, n=4)
    S.pipe(edge, 0.07, GOLD, rng, kind=E.SHINE, n=4)
    S.pipe([(x0 + w * i / 4, -5.5, 13.0 + 0.32 * math.sin(math.pi * (i % 4) / 4) + 0.02) for i in range(41)], 0.07, GOLD, rng, kind=E.SHINE, n=4)
    for sx in (-14.66, 14.66):  # the side valances
        side = []
        s = 1 if sx > 0 else -1
        for t in range(5):

            def flap(u, v, t=t):
                y = -5.4 + (t + u) * 1.86
                drop = 0.5 + 0.6 * math.sin(math.pi * u) ** 0.7
                return (sx + s * 0.08 * math.sin(math.pi * u), y, 13.0 + (y + 5.4) * slope - v * drop)

            sheet(flap, 6, 1, 0.08, PURPLE if t % 2 else PURPLE_DEEP, rng)
            side += [Vector(flap(i / 3, 1)) + Vector((s * 0.05, 0, 0)) for i in range(3 + (t == 4))]
            tassel(Vector(flap(0.5, 1)) + Vector((s * 0.06, 0, -0.06)), rng, 0.4)
        S.pipe(side, 0.06, GOLD, rng, kind=E.SHINE, n=4)


def sign(rng):
    """The sign board over the awning: three planks in a gold frame, carved eggs at its ends (the middle
    is left plain for the game's lettering), a crowned egg crest on top with gold leaves."""
    for sx in (-7.5, 7.5):
        S.box((0.7, 0.7, 15.4), (sx, 4.75, Z0), WOOD_DARK, rng, surface="horn")
    S.box((17.6, 0.2, 4.5), (0, 4.5, 15.5), WOOD_DARK, rng)
    for i in range(3):
        S.box((17.6, 0.4, 1.46), (0, 4.35, 15.5 + i * 1.5), WOOD_LIGHT if i == 1 else (214, 162, 104), rng, surface="horn")
    for z in (15.1, 19.98):
        S.box((18.6, 0.6, 0.5), (0, 4.1, z), GOLD, rng, kind=E.SHINE, bevel=0.08)
    for sx in (-9.05, 9.05):
        S.box((0.6, 0.6, 5.38), (sx, 4.1, 15.1), GOLD, rng, kind=E.SHINE, bevel=0.08)
        gold(k.ico(0.42, (sx, 4.1, 20.85), subdiv=1), rng)
        S.shard((sx, 4.1, 21.15), (sx, 4.1, 21.95), 0.3, 0.3, GOLD, rng, kind=E.SHINE)
        for sz in (15.35, 20.23):
            gold(k.ico(0.34, (sx, 3.78, sz), subdiv=1), rng)
    for sx in (-6.7, 6.7):  # carved eggs, each in a little laurel
        plate((sx, 4.15, 17.75), egg2d(1.5, 2.0), 0.08, WOOD_DARK, rng)
        plate((sx, 4.07, 17.75), egg2d(1.0, 1.38), 0.08, (226, 176, 116), rng)
        for s in (-1, 1):
            for j in range(4):
                b = Vector((sx + s * (0.95 + 0.1 * j), 4.1, 16.9 + j * 0.45))
                S.shard(b, b + Vector((s * 0.2, 0, 0.42)), 0.2, 0.06, GOLD, rng, kind=E.SHINE, face=(0, -1, 0))
    # the crest
    c = Vector((0, 4.15, 21.25))
    plate(c, egg2d(3.0, 3.9, 24), 0.36, GOLD, rng, kind=E.SHINE)
    plate(c - Vector((0, 0.36, 0)), egg2d(2.3, 3.1, 24), 0.12, PURPLE_DEEP, rng)
    plate(c - Vector((0, 0.48, 0)) + Vector((0, 0, -0.1)), egg2d(1.2, 1.6, 20), 0.18, GOLD, rng, kind=E.SHINE)
    for j in range(6):  # a ring of little gold beads round the purple
        a = math.tau * (j + 0.5) / 6
        gold(k.ico(0.1, c + Vector((math.sin(a) * 0.95, -0.5, math.cos(a) * 1.3)), subdiv=1), rng)
    crown = [(-0.8, 0), (0.8, 0), (0.8, 0.35), (1.0, 1.0), (0.45, 0.55), (0, 1.2), (-0.45, 0.55), (-1.0, 1.0), (-0.8, 0.35)]
    plate(c + Vector((0, 0, 1.8)), crown, 0.36, GOLD, rng, kind=E.SHINE)
    for gx, gz, rgb in ((-1.0, 1.0, (220, 40, 70)), (1.0, 1.0, (220, 40, 70)), (0.0, 1.2, (220, 40, 70)), (0.0, 0.17, PURPLE_PALE)):
        S.lump(c + Vector((gx, -0.42, 1.8 + gz)), 0.14, rgb, rng, surface="gem", kind=F.COOL)
    for s in (-1, 1):  # gold leaves sweeping out from the crest
        for j, (dx, dz, ln) in enumerate(((1.3, -0.9, 1.9), (1.45, -0.3, 1.6), (1.35, 0.4, 1.2))):
            b = c + Vector((s * dx, -0.1, dz))
            S.shard(b, b + Vector((s * ln, 0, -0.25 + j * 0.25)), 0.55 - j * 0.08, 0.12, GOLD, rng, kind=E.SHINE, face=(0, -1, 0), at=0.35)


def banner(x, rng, y=-4.2, top=10.55, hw=0.8, drop=3.9):
    """A purple swallowtail banner on a gold rod hung under a lantern arm, a gold egg on it."""
    S.pipe([(x - hw - 0.2, y, top + 0.05), (x + hw + 0.2, y, top + 0.05)], 0.07, GOLD, rng, kind=E.SHINE)
    for s in (-1, 1):
        gold(k.ico(0.13, (x + s * (hw + 0.25), y, top + 0.05), subdiv=1), rng)
        S.pipe([(x + s * hw * 0.7, y, 10.9), (x + s * hw * 0.7, y, top + 0.05)], 0.035, IRON, rng, n=4)

    def cloth(u, v):
        d = drop - 0.9 * (1 - abs(2 * u - 1))
        return (x - hw + 2 * hw * u, y - 0.05 * math.sin(3 * math.pi * u), top - v * d)

    sheet(cloth, 9, 3, 0.06, PURPLE, rng)
    S.pipe([Vector(cloth(i / 9, 1)) + Vector((0, -0.04, 0)) for i in range(10)], 0.045, GOLD, rng, kind=E.SHINE, n=4)
    for u in (0.0, 1.0):
        S.pipe([Vector(cloth(u, v / 4)) + Vector((0, -0.03, 0)) for v in range(5)], 0.045, GOLD, rng, kind=E.SHINE, n=4)
        tassel(Vector(cloth(u, 1)) + Vector((0, -0.03, -0.04)), rng, 0.35)
    S.pipe([Vector(cloth(i / 9, 0.08)) + Vector((0, -0.05, 0)) for i in range(10)], 0.045, GOLD, rng, kind=E.SHINE, n=4)
    plate((x, y - 0.1, top - 1.75), egg2d(0.9, 1.22), 0.06, GOLD, rng, kind=E.SHINE)
    plate((x, y - 0.16, top - 1.73), egg2d(0.5, 0.7), 0.05, PURPLE_PALE, rng)


def runner(rng):
    """The cloth draped over the counter's front, ending in a point, with a crowned gold egg."""
    path = [(-2.95, 4.64), (-3.82, 4.64), (-3.92, 4.52), (-3.93, 3.4), (-3.93, 1.8)]

    def cloth(u, v):
        t = v * (len(path) - 1)
        i = min(int(t), len(path) - 2)
        f = t - i
        y = path[i][0] + (path[i + 1][0] - path[i][0]) * f
        z = path[i][1] + (path[i + 1][1] - path[i][1]) * f
        if v > 0.5:  # the hanging part folds and ends in a point
            hang = (v - 0.5) * 2
            y -= 0.06 * math.sin(4 * math.pi * u) * hang
            z -= 0.9 * (1 - abs(2 * u - 1)) * hang
        return (-4.0 + 8.0 * u, y, z)

    sheet(cloth, 16, 8, 0.06, PURPLE_DEEP, rng)
    S.pipe([Vector(cloth(i / 16, 1)) + Vector((0, -0.05, 0)) for i in range(17)], 0.06, GOLD, rng, kind=E.SHINE, n=4)
    for u in (0.0, 1.0):
        S.pipe([Vector(cloth(u, v / 8)) + Vector((0, -0.04, 0.03)) for v in range(9)], 0.05, GOLD, rng, kind=E.SHINE, n=4)
    tassel(Vector(cloth(0.5, 1)) + Vector((0, -0.05, -0.05)), rng, 0.5)
    for i in range(9):  # fringe of little gold drops along the bottom edge
        u = (i + 0.5) / 9
        p = Vector(cloth(u, 1)) + Vector((0, -0.04, 0))
        S.shard(p, p - Vector((0, 0, 0.28)), 0.08, 0.05, GOLD, rng, kind=E.SHINE)
    c = Vector((0, -4.05, 2.75))
    plate(c, egg2d(1.5, 2.0), 0.06, GOLD, rng, kind=E.SHINE)
    plate(c + Vector((0, -0.06, 0)), egg2d(1.0, 1.4), 0.05, PURPLE_PALE, rng)
    plate(c + Vector((0, -0.11, -0.1)), egg2d(0.5, 0.7), 0.05, GOLD, rng, kind=E.SHINE)
    crown = [(-0.6, 0), (0.6, 0), (0.6, 0.25), (0.75, 0.75), (0.32, 0.4), (0, 0.9), (-0.32, 0.4), (-0.75, 0.75), (-0.6, 0.25)]
    plate(c + Vector((0, 0, 0.95)), crown, 0.08, GOLD, rng, kind=E.SHINE)
    for s in (-1, 1):  # a laurel round the egg
        for j in range(5):
            a = math.radians(-70 + j * 32)
            b = c + Vector((s * 0.95 * math.cos(a), -0.02, 1.1 * math.sin(a)))
            S.shard(b, b + Vector((s * 0.12, 0, 0.32)), 0.18, 0.04, GOLD, rng, kind=E.SHINE, face=(0, -1, 0))


# The eggs -----------------------------------------------------------------------------------------------


def nest(p, rng):
    """A straw nest: a bowl of hay, a rim of clumps, straws laid round it and a few poking out."""
    p = Vector(p)
    S.lump(p + Vector((0, 0, 0.16)), (1.0, 1.0, 0.24), STRAW_DARK, rng, surface="fur")
    for i in range(10):
        a = math.tau * i / 10 + rng.uniform(-0.1, 0.1)
        S.lump(p + Vector((math.cos(a) * 0.82, math.sin(a) * 0.82, 0.3)), (0.36, 0.36, 0.22), rng.choice((STRAW, STRAW_DARK, (226, 186, 96))), rng, surface="fur")
    for i in range(18):
        a = math.tau * i / 18 + rng.uniform(-0.1, 0.1)
        r = rng.uniform(0.85, 1.05)
        b = p + Vector((math.cos(a) * r, math.sin(a) * r, rng.uniform(0.3, 0.5)))
        e = p + Vector((math.cos(a + 0.8) * r, math.sin(a + 0.8) * r, rng.uniform(0.3, 0.55)))
        S.shard(b, e, 0.09, 0.05, rng.choice((STRAW, (250, 222, 140))), rng)
    for i in range(7):
        a = math.tau * i / 7 + rng.uniform(-0.3, 0.3)
        b = p + Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.25))
        S.shard(b, b + Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, rng.uniform(-0.1, 0.15))), 0.08, 0.04, STRAW, rng)


def egg(name, p, yaw, rng, size=0.6):
    """The game's egg `name` (its builder in eggs.py) standing in a nest at p: the pieces of its ground
    dressing (a stand, a plinth, a pool, grass round it) are left off, so it sits in the straw."""
    asset = next(a for a in E.ASSETS if a["name"] == name)
    groups = asset["build"]()
    move = Matrix.Translation(Vector(p) + Vector((0, 0, 0.3))) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(size, 4)
    for part, objs in groups.items():
        for ob in objs:
            lo, hi = k._ground_dims([ob])
            reach = max(abs(lo.x), abs(hi.x), abs(lo.y), abs(hi.y))
            # shortcut: the Legend Egg's banners and the Oasis Egg's palms stand apart from the egg, dropped by name; a new egg with dressing off to the side needs its own rule
            banners = name in ("egg_legend", "egg_oasis") and Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2)).length > 1.3
            if hi.z < 0.45 or (lo.z < 0.3 and reach > 1.3) or reach > 2.6 or banners:
                bpy.data.objects.remove(ob)
                continue
            ob.data.transform(move)
            if part.endswith("_glow"):
                S.neon(ob, asset["glow"].get(part, k.GLOW_RGB))
            elif k._tris(ob) > 12:
                thin(ob, 0.3)


def thin(ob, ratio):
    """Collapses a mesh to `ratio` of its triangles (the eggs are game models of their own; at this size
    a stall full of them only needs about half their facets)."""
    mod = ob.modifiers.new("thin", "DECIMATE")
    mod.ratio = ratio
    bpy.context.view_layer.update()
    old = ob.data
    ob.data = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    ob.modifiers.remove(mod)
    bpy.data.meshes.remove(old)


def eggs(rng):
    xs = (-7.9, -3.95, 0.0, 3.95, 7.9)
    for i, (x, name) in enumerate(zip(xs, LOW_EGGS)):
        nest((x, -1.9, 4.6), rng)
        egg(name, (x, -1.9, 4.6), (-12, 6, 0, -6, 12)[i], rng)
    for i, (x, name) in enumerate(zip(xs, TOP_EGGS)):
        nest((x, 1.2, 6.9), rng)
        egg(name, (x, 1.2, 6.9), (-10, 5, 0, -5, 10)[i], rng)


# The dressing -------------------------------------------------------------------------------------------


def lantern(rng):
    """An iron lantern hanging from the origin: cap, cage, candle and flame."""
    for z in (-0.12, -0.32, -0.52):  # chain
        S.lump((0, 0, z), (0.07, 0.07, 0.11), IRON, rng)
    S.post(0.6, 0.45, (0, 0, -1.1), IRON, rng, n=6, r2=0.15)
    S.post(0.5, 0.12, (0, 0, -1.22), IRON, rng, n=6)
    gold(k.ico(0.12, (0, 0, -0.62), subdiv=1), rng)
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        S.pipe([(0.44 * math.cos(a), 0.44 * math.sin(a), -1.22), (0.44 * math.cos(a), 0.44 * math.sin(a), -2.35)], 0.045, IRON, rng, n=4)
    S.post(0.55, 0.15, (0, 0, -2.5), IRON, rng, n=6)
    S.post(0.05, 0.35, (0, 0, -2.85), IRON, rng, n=6, r2=0.3)
    S.post(0.14, 0.4, (0, 0, -2.35), (240, 230, 210), rng, n=6, kind=F.PALE)
    S.neon(F.shard((0, 0, -1.98), (0, 0, -1.35), 0.32, 0.32, None, rng, m=k.mat("gem", FLAME, kind="flat"), at=0.35), FLAME, 3.0)
    S.neon(F.shard((0, 0, -1.94), (0, 0, -1.6), 0.16, 0.16, None, rng, m=k.mat("gem", FLAME, kind="flat"), at=0.4), FLAME_CORE, 3.0)


def lanterns(rng):
    for s in (-1, 1):
        x = s * 14.2
        S.pipe([(x, -4.2, 10.9), (s * 17.45, -4.2, 10.9)], 0.1, IRON, rng, n=4)
        S.pipe([(x, -4.2, 9.5), (s * 15.0, -4.2, 10.3), (s * 15.6, -4.2, 10.85)], 0.07, IRON, rng, n=4)
        gold(k.ico(0.14, (s * 17.5, -4.2, 10.9), subdiv=1), rng)
        placed(at((s * 17.0, -4.2, 10.82)), lantern, rng)
    placed(at((11.3, 1.5, 8.9)) @ Matrix.Scale(0.8, 4), lantern, rng)  # a third stands on the upper tier


def crystals(p, rng, s=1.0):
    p = Vector(p)
    S.lump(p + Vector((0, 0, 0.25 * s)), (0.8 * s, 0.7 * s, 0.4 * s), (74, 64, 96), rng, surface="rock", kind=F.COOL)
    for i, (az, lean, ln) in enumerate(((0, 0, 1.9), (70, 28, 1.3), (150, 35, 1.1), (220, 30, 1.4), (290, 32, 1.0), (110, 50, 0.7), (330, 55, 0.8))):
        d = Vector((math.sin(math.radians(lean)) * math.cos(math.radians(az)), math.sin(math.radians(lean)) * math.sin(math.radians(az)), math.cos(math.radians(lean))))
        base = p + Vector((math.cos(math.radians(az)), math.sin(math.radians(az)), 0)) * (0.25 * s if i else 0) + Vector((0, 0, 0.3 * s))
        S.gem(base, base + d * ln * s, (0.42 if i == 0 else 0.3) * s, VIOLET if i % 3 else VIOLET_PALE, 2.6, rng)


def crate(s, rng, straw=False):
    S.box((s, s, s), (0, 0, 0), WOOD_LIGHT, rng, surface="horn")
    for cx in (-1, 1):
        for cy in (-1, 1):
            S.box((0.24, 0.24, s), (cx * (s / 2 - 0.08), cy * (s / 2 - 0.08), 0), WOOD_DARK, rng)
    for z in (0.0, s - 0.22):
        S.box((s + 0.08, s + 0.08, 0.22), (0, 0, z), WOOD_DARK, rng)
    for y in (-s / 2 - 0.03, s / 2 + 0.03):
        S.pipe([(-s / 2 + 0.2, y, 0.3), (s / 2 - 0.2, y, s - 0.3)], 0.08, WOOD_DARK, rng, n=4)
    if straw:
        for i in range(6):
            S.lump((rng.uniform(-0.4, 0.4) * s, rng.uniform(-0.4, 0.4) * s, s + 0.05), (0.42 * s, 0.42 * s, 0.14), STRAW, rng, surface="fur")


def spare_egg(p, rng, rgb=(246, 236, 210), tilt=0.0):
    ob = k.lathe([(0.0, 0.0)] + [(E.radius(z) * 0.3, z * 0.3) for z in (0.25, 0.9, 1.6, 2.3, 2.8)] + [(0.0, 0.9)], (0, 0, 0), n=8)
    ob.data.transform(Matrix.Translation(Vector(p)) @ Matrix.Rotation(math.radians(tilt), 4, "Y"))
    S.paint(ob, rgb, rng, surface="shell", kind=F.PALE)


def sack(rng, open_=False):
    S.lump((0, 0, 0.85), (0.85, 0.75, 0.9), (200, 166, 112), rng, surface="fur")
    if open_:
        S.lump((0, 0, 1.6), (0.62, 0.55, 0.22), (238, 206, 110), rng)
        for i in range(8):
            S.lump((rng.uniform(-0.3, 0.3), -0.85 - rng.uniform(0, 0.4), 0.05), 0.08, (238, 206, 110), rng)
    else:
        S.lump((0, 0, 1.75), (0.32, 0.3, 0.3), (190, 156, 104), rng, surface="fur")
        S.pipe([(0.33 * math.cos(a * math.tau / 10), 0.31 * math.sin(a * math.tau / 10), 1.62) for a in range(11)], 0.05, (140, 100, 60), rng, n=4)
        for a in range(5):
            d = Vector((math.cos(a * 1.26), math.sin(a * 1.26), 0))
            S.shard(Vector((0, 0, 1.9)), Vector((0, 0, 2.15)) + d * 0.3, 0.2, 0.05, (190, 156, 104), rng)


def barrel(rng):
    S.turn([(0.82, 0.0), (0.98, 0.45), (1.06, 1.15), (0.98, 1.85), (0.82, 2.3)], (0, 0, 0), WOOD, rng, n=12, surface="horn")
    for z, r in ((0.12, 0.92), (0.78, 1.07), (1.36, 1.08), (1.98, 0.94)):
        S.turn([(r, z), (r, z + 0.18)], (0, 0, 0), IRON, rng, n=12)
    S.post(0.78, 0.05, (0, 0, 2.3), WOOD_DARK, rng, n=12)
    S.box((1.1, 0.9, 0.18), (0.05, 0.0, 2.35), PURPLE, rng, yaw=20)  # a folded cloth on the lid
    S.box((1.1, 0.06, 0.12), (0.05, 0.0, 2.38), GOLD, rng, yaw=20, kind=E.SHINE)


def easel(rng):
    """A chalkboard on an easel, a chalk egg drawn on it."""
    for s in (-1, 1):
        S.pipe([(s * 0.85, -0.4, 0), (s * 0.38, 0.2, 3.9)], 0.08, WOOD_DARK, rng, n=4)
    S.pipe([(0, 1.3, 0), (0, 0.25, 3.7)], 0.07, WOOD_DARK, rng, n=4)
    S.box((2.1, 0.32, 0.1), (0, -0.2, 1.25), WOOD, rng)

    def board():
        S.box((2.1, 0.1, 1.85), (0, 0.06, -0.92), WOOD, rng)
        S.box((1.8, 0.1, 1.55), (0, 0.0, -0.77), (38, 44, 40), rng, kind=F.COOL)
        chalk = (240, 240, 232)
        pts = [Vector((x - 0.35, -0.06, z + 0.05)) for x, z in egg2d(0.6, 0.82, 18)]
        S.pipe(pts + [pts[0]], 0.03, chalk, rng, n=4, kind=F.PALE)
        S.pipe([(-0.62, -0.06, 0.36), (-0.35, -0.06, 0.56), (-0.08, -0.06, 0.36)], 0.025, chalk, rng, n=4, kind=F.PALE)  # a crown over it
        for j, ln in enumerate((0.7, 0.5, 0.6)):
            S.pipe([(0.12, -0.06, 0.3 - j * 0.3), (0.12 + ln, -0.06, 0.3 - j * 0.3 + 0.02)], 0.03, chalk, rng, n=4, kind=F.PALE)
        S.box((0.12, 0.08, 0.06), (0.6, -0.06, -0.7), chalk, rng, kind=F.PALE)  # a stick of chalk on the ledge

    placed(at((0, 0.0, 2.3), tilt=-10), board)


def vine(x, y, rng):
    pts = [Vector((x + 0.74 * math.cos(t * 0.66 + 1.0), y + 0.74 * math.sin(t * 0.66 + 1.0), Z0 + 0.2 + t * 0.355)) for t in range(32)]
    S.pipe(pts, 0.07, (70, 110, 56), rng, n=5)
    for i in range(1, len(pts) - 1):
        out = (pts[i] - Vector((x, y, pts[i].z))).normalized()
        side = out.cross(ZV) * (1 if i % 2 else -1)
        S.shard(pts[i], pts[i] + out * 0.35 + side * 0.25 + ZV * 0.1, 0.3, 0.05, rng.choice((LEAF, (100, 172, 82), (62, 128, 60))), rng, face=out, at=0.45)
        if i % 6 == 3:
            S.lump(pts[i] + out * 0.18, 0.13, rng.choice((PURPLE_PALE, (250, 246, 236))), rng)


def scale(rng):
    S.post(0.45, 0.14, (0, 0, 0), BRASS, rng, n=8, kind=E.SHINE)
    S.post(0.07, 1.7, (0, 0, 0.14), BRASS, rng, n=6, kind=E.SHINE)
    S.pipe([(-0.8, 0, 1.75), (0.8, 0, 1.75)], 0.05, BRASS, rng, n=4, kind=E.SHINE)
    gold(k.ico(0.11, (0, 0, 1.9), subdiv=1), rng)
    for s, z in ((-1, 0.82), (1, 0.92)):
        S.turn([(0.12, 0.0), (0.42, 0.12), (0.44, 0.16)], (s * 0.8, 0, z), BRASS, rng, n=10, kind=E.SHINE)
        for i in range(3):
            a = math.tau * i / 3
            S.pipe([(s * 0.8, 0, 1.73), (s * 0.8 + 0.4 * math.cos(a), 0.4 * math.sin(a), z + 0.15)], 0.015, IRON, rng, n=3)
    S.post(0.15, 0.05, (-0.8, 0, 0.98), GOLD, rng, n=10, kind=E.SHINE)  # a coin on one pan
    spare_egg((0.8, 0, 1.08), rng, (250, 232, 200))  # a little egg on the other


def pouch(rng):
    S.lump((0, 0, 0.42), (0.52, 0.48, 0.45), PURPLE, rng, surface="fur")
    S.lump((0, 0, 0.95), (0.2, 0.2, 0.18), PURPLE, rng, surface="fur")
    S.pipe([(0.21 * math.cos(a * math.tau / 10), 0.21 * math.sin(a * math.tau / 10), 0.82) for a in range(11)], 0.04, GOLD, rng, n=4, kind=E.SHINE)
    for x, y, n in ((-0.75, -0.55, 5), (0.55, -0.75, 3)):
        for i in range(n):
            S.post(0.22, 0.06, (x + rng.uniform(-0.02, 0.02), y, i * 0.065), GOLD, rng, n=8, kind=E.SHINE)
    for x, y in ((0.0, -0.9), (-0.35, -1.05)):
        S.post(0.22, 0.05, (x, y, 0.0), GOLD, rng, n=8, kind=E.SHINE)


def dressing(rng):
    vine(-13.6, -4.2, rng)
    lanterns(rng)
    crystals((-12.4, -6.6, Z0), rng, 1.3)
    crystals((12.4, -7.0, Z0), rng, 1.1)
    crystals((-16.2, 3.6, Z0), rng, 0.7)
    placed(at((-15.7, -6.6, Z0), yaw=28), easel, rng)
    placed(at((-15.8, -1.6, Z0), yaw=8), crate, 2.2, rng)
    placed(at((-15.7, -1.5, Z0 + 2.2), yaw=-12), crate, 1.6, rng, True)
    for i, (dx, rgb) in enumerate(((-0.3, (246, 236, 210)), (0.25, (226, 238, 214)), (0.0, (236, 216, 236)))):
        spare_egg((-15.7 + dx, -1.6 + (i - 1) * 0.35, Z0 + 3.85), rng, rgb, tilt=(i - 1) * 18)
    placed(at((-15.6, 1.8, Z0), yaw=-6), crate, 1.9, rng)
    placed(at((15.5, -5.1, Z0)), barrel, rng)
    placed(at((15.7, -2.2, Z0), yaw=20), sack, rng)
    placed(at((15.8, -0.3, Z0), yaw=-15), sack, rng, True)
    placed(at((15.6, 2.0, Z0), yaw=10), crate, 2.0, rng, True)
    placed(at((-11.7, -2.0, 4.6)), scale, rng)
    placed(at((11.8, -1.8, 4.6), yaw=10), pouch, rng)


def piece(name, fn, *a):
    """Runs fn and marks every new mesh as part of the game piece `name` (a mesh may hold 20,000 triangles)."""
    before = {ob.name for ob in bpy.data.objects}
    fn(*a)
    for ob in bpy.data.objects:
        if ob.name not in before and ob.type == "MESH":
            ob["piece"] = name


def build_stall(rng):
    piece("body", paving, rng)
    piece("body", stall, rng)
    piece("body", curtain, rng)
    piece("cloth", awning, rng)
    piece("cloth", sign, rng)
    for x in (-15.15, 15.15):
        piece("cloth", banner, x, rng)
    piece("cloth", runner, rng)
    piece("eggs", eggs, rng)
    piece("props", dressing, rng)


def concept(name, note):
    asset = dict(name=name, budget=60000, joints={}, glow={}, finalize={"center": False, "ao_floor": 0.7}, notes=note)

    def build():
        rng = random.Random(11)
        build_stall(rng)
        for ob in list(bpy.data.objects):  # the hay, sacks and blossoms: rounded lumps need fewer facets at this size
            if ob.type == "MESH" and ob.name.startswith("lump") and k._tris(ob) >= 80:
                thin(ob, 0.5)
        groups = S.sort_pieces(rng, asset)
        for ob in list(groups["body"]):  # the painted pieces apart, each its own mesh
            if ob.get("piece", "body") != "body":
                groups["body"].remove(ob)
                part = ob["piece"]
                if part == "eggs" and k._ground_dims([ob])[0].z > 6.0:  # the upper row its own mesh
                    part = "eggs_top"
                groups.setdefault(part, []).append(ob)
        for part, objs in groups.items():
            print(f"[stations] {name} {part}: {sum(k._tris(o) for o in objs)} tris", flush=True)
        print(f"[stations] {name}: {sum(k._tris(o) for objs in groups.values() for o in objs)} tris", flush=True)
        return groups

    asset["build"] = build
    return asset


ASSETS = [concept("stall_eggs", "The egg vendor's stall on each ranch (SHANNON's pick, 2026-11-24): purple and gold, ten eggs in straw nests on a two-tier counter.")]
