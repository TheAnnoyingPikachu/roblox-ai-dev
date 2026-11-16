"""The hub's centre as a place to gather (concept, decision 0063): a second design, asked for as "less
shrine like and more communal". No statues, shrines or great monument: a fire pit ringed by benches in
the middle, a market, a cafe with tables, a stage with seats before it, and a green with a meeting tree,
a pond and a trough for the animals, under strings of lights. The plaza keeps its size (48 studs to its
kerb, World.PLAZA) and its four roads, so it fits where the built centre stands.
"""

import importlib.util
import math
import os

import stage as S
from mathutils import Vector
from stage import bench, box, bunting, bush, disc, flag, flowers, lantern, lump, neon, pipe, polar, post, prism, rock, roof, shard, slab, spin, tree, turn, words

_spec = importlib.util.spec_from_file_location("scene_hub", os.path.join(os.path.dirname(os.path.abspath(__file__)), "hub.py"))
H = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(H)

COBBLE_A, COBBLE_B = (214, 196, 160), (198, 178, 144)
BRICK = (190, 104, 78)
HAY = (228, 196, 110)
IRON = (86, 88, 100)
PARTY = H.PARTY
Z = 0.3  # the top of the paving
CAST = True  # with the animals and eggs in it (the game stands its own on the models)


def actor(*args, **kw):
    return S.actor(*args, **kw) if CAST else []


def local(at, yaw):
    """A function from a piece's own (x, y, z) to the scene, for a piece standing on `at` turned `yaw` degrees."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return lambda x, y, z=0.0: (at[0] + x * c - y * s, at[1] + x * s + y * c, at[2] + z)


def floor(rng):
    """Warm cobbles in rings, a round of pale flags in the middle, a band of brick between."""
    disc(48.4, (0, 0, -0.3), 0.5, (112, 106, 100), rng, n=64)
    for i in range(48):
        slab(46.6, 48.5, i * 7.5 + 0.15, (i + 1) * 7.5 - 0.15, 0.0, 0.5, S.STONE_DARK, rng, surface="rock", kind=S.COOL)
    for band, (r0, r1, n) in enumerate(((0.0, 6.6, 9), (6.8, 14.4, 18), (15.6, 25.4, 26), (25.6, 35.8, 36), (36.0, 46.5, 46))):
        for i in range(n):
            a = (i + 0.5 * (band % 2)) * 360 / n
            tint = (S.MARBLE if (i + band) % 2 else (226, 216, 196)) if band < 2 else (COBBLE_A if (i + band) % 2 else COBBLE_B)
            slab(r0, r1, a + 0.25, a + 360 / n - 0.25, 0.0, Z, tint, rng, kind=S.PALE, chance=0.4)
    for i in range(64):
        slab(14.5, 15.5, i * 5.625 + 0.3, (i + 1) * 5.625 - 0.3, 0.0, Z + 0.03, BRICK if i % 2 else (214, 150, 110), rng, chance=0.3)


def fire(rng):
    """The fire pit: a ring of stones, logs leaning together, flames; two rows of curved benches round it,
    the back one higher, open towards each road."""
    for i in range(14):
        lump(polar(3.5, i * 360 / 14, Z + 0.45), (0.85, 0.7, 0.6), (150, 144, 136), rng, surface="rock", kind=S.COOL)
    disc(3.0, (0, 0, Z), 0.12, (60, 52, 50), rng, n=12)
    for i in range(6):
        pipe([tuple(polar(2.2, i * 60 + 10, Z + 0.1)), (0, 0, Z + 3.4)], [0.38, 0.26], (112, 78, 50), rng, n=6)
    for dx, dy, r, h, rgb in ((0, 0, 1.3, 4.6, (255, 150, 40)), (0.7, 0.3, 0.9, 3.2, (255, 200, 70)), (-0.6, 0.5, 0.9, 3.4, (255, 110, 40)), (0.1, -0.7, 0.8, 2.8, (255, 220, 110))):
        neon(S.k.cyl(r, h, (dx, dy, Z + 0.6 + h / 2), n=6, r2=0.0), rgb, 2.6)
    for q in range(4):
        a = q * 90 + 45
        slab(8.2, 9.8, a - 31, a + 31, Z, 1.15, S.WOOD, rng, step=8)  # the front row
        slab(8.0, 8.5, a - 31, a + 31, Z + 1.15, 0.08, S.WOOD_DARK, rng, step=8)
        slab(11.9, 13.5, a - 33, a + 33, Z, 2.0, S.WOOD, rng, step=8)  # the back row, a step up
        slab(13.2, 13.8, a - 33, a + 33, Z + 2.0, 1.3, S.WOOD_DARK, rng, step=8)  # and its back
        slab(10.0, 11.8, a - 33, a + 33, Z, 0.85, (176, 150, 118), rng, step=8, kind=S.PALE)  # the step between
        for j in range(5):
            lump(polar(9.0, a - 24 + j * 12, Z + 1.35), (0.7, 0.7, 0.24), PARTY[(q + j) % 5], rng)  # cushions


def stall_row(rng):
    """The market: five stalls in an arc on the south-west, their counters to the middle, crates and
    barrels between, and the egg seller's cart with the Golden Egg on it."""
    stripes = ((226, 90, 80), (80, 150, 220), (250, 190, 60), (90, 190, 120), (190, 120, 240))
    for i, a in enumerate((193, 208, 223, 238, 253)):
        H.stall(rng, tuple(polar(38.5, a, Z)), a - 90, stripes[i])
        board = local(tuple(polar(34.6, a, Z)), a - 90)
        box((3.4, 0.2, 1.0), board(0, 0, 7.2), stripes[i], rng, yaw=a + 90)  # its hanging sign
        for dx in (-1.4, 1.4):
            pipe([board(dx, 0, 8.2), board(dx, 0, 7.6)], 0.05, S.INK, rng, n=4)
    for a, r in ((200.5, 34.5), (215.5, 35.0), (230.5, 34.5), (245.5, 35.0)):
        p = polar(r, a, Z)
        box((1.6, 1.6, 1.5), p, S.WOOD, rng, yaw=a + 20)
        box((1.3, 1.3, 1.2), p + polar(1.9, a + 100), S.WOOD_DARK, rng, yaw=a - 15)
        turn([(0.7, 0.0), (0.9, 0.7), (0.7, 1.5)], p + polar(2.0, a - 80), S.WOOD, rng, n=10)
        lump(p + Vector((0, 0, 1.9)), (0.6, 0.6, 0.45), ((230, 80, 70), (250, 200, 80), (120, 200, 110), (240, 150, 60))[int(a) % 4], rng)
    cart = local((-20.0, -17.0, Z), 215)  # the egg seller's cart
    box((7.0, 4.2, 0.5), cart(0, 0, 1.7), S.WOOD, rng, yaw=215)
    for sx in (-2.6, 2.6):
        for sy in (-2.35, 2.35):
            post(1.5, 0.4, cart(sx, sy - 0.2, 1.5), S.WOOD_DARK, rng, n=10, rot=(90, 0, 215))
    for dx in (-3.5, 3.5):
        box((0.3, 4.2, 1.2), cart(dx, 0, 2.2), S.WOOD_DARK, rng, yaw=215)
    pipe([cart(3.5, -1.2, 2.0), cart(7.2, -1.2, 0.5)], 0.14, S.WOOD_DARK, rng, n=5)
    pipe([cart(3.5, 1.2, 2.0), cart(7.2, 1.2, 0.5)], 0.14, S.WOOD_DARK, rng, n=5)
    for i in range(10):
        lump(cart(1.6 * math.cos(i * 0.63), 1.5 * math.sin(i * 0.63), 2.5), (0.8, 0.6, 0.35), HAY, rng)
    actor("egg_golden", cart(0, 0, 2.5), 35, scale=1.5)
    for i, name in enumerate(("egg_meadow", "egg_wild", "egg_safari")):
        actor(name, cart(-2.4 + i * 0.3, -1.4 + i * 1.4, 2.2), 35, scale=0.55)


def cafe(rng):
    """The cafe on the north-west: an open hut with a counter, round tables under parasols, stools."""
    at, yaw = (-30.0, 30.0, Z), 45
    p = local(at, yaw)  # its front (local -Y) faces the middle
    box((15.0, 9.0, 0.4), p(0, 0), S.WOOD, rng, yaw=yaw)
    for sx in (-7.0, 7.0):
        for sy in (-4.0, 4.0):
            box((0.6, 0.6, 7.2), p(sx, sy, 0.4), S.WOOD_DARK, rng, yaw=yaw)
    box((14.6, 0.5, 6.4), p(0, 4.0, 0.4), (232, 214, 180), rng, yaw=yaw, kind=S.PALE)
    box((13.0, 1.6, 2.9), p(0, -2.6, 0.4), S.WOOD_DARK, rng, yaw=yaw)
    box((13.6, 2.2, 0.3), p(0, -2.6, 3.3), S.WOOD, rng, yaw=yaw)
    roof(17.0, 11.5, 3.6, p(0, 0, 7.6), (176, 70, 60), rng, yaw=yaw, ridge=9.0)
    for i in range(9):  # a striped awning over the counter
        box((1.62, 3.4, 0.2), p(-6.5 + i * 1.62, -5.2, 6.6), (226, 90, 80) if i % 2 else S.WHITE, rng, yaw=yaw, tilt=(-16, 0))
    box((6.0, 0.3, 1.5), p(0, -4.5, 8.4), S.WOOD_DARK, rng, yaw=yaw)
    words("CAFE", p(0, -4.7, 9.15), 1.1, S.WHITE, yaw=yaw)
    for i in range(5):  # jugs and cakes on the counter, shelves of jars behind
        lump(p(-5.0 + i * 2.5, -2.6, 3.9), (0.45, 0.45, 0.5), ((240, 200, 120), (230, 120, 130), (160, 200, 240), (250, 240, 220), (150, 100, 70))[i], rng)
    for row in range(2):
        box((10.0, 0.9, 0.2), p(0, 3.4, 3.6 + row * 1.6), S.WOOD, rng, yaw=yaw)
        for i in range(7):
            post(0.3, 0.7, p(-4.2 + i * 1.4, 3.4, 3.8 + row * 1.6), PARTY[(i + row) % 5], rng, n=6)
    shades = ((226, 90, 80), (250, 190, 60), (80, 150, 220), (90, 190, 120))
    for i, (x, y) in enumerate(((-21.0, 17.5), (-14.5, 24.5), (-17.5, 34.5), (-36.0, 16.0))):  # the tables
        post(1.7, 0.22, (x, y, Z + 2.3), S.WOOD, rng, n=10)
        post(0.3, 2.3, (x, y, Z), S.WOOD_DARK, rng, n=6)
        post(0.1, 6.4, (x, y, Z), S.WHITE, rng, n=5)
        post(3.4, 1.2, (x, y, Z + 6.0), shades[i], rng, n=8, r2=0.1)
        lump((x + 0.5, y - 0.3, Z + 2.75), 0.28, S.WHITE, rng, kind=S.PALE)
        for k in range(4):
            post(0.5, 1.35, Vector((x, y, Z)) + polar(2.7, k * 90 + i * 20), S.WOOD, rng, n=7)


def stage(rng):
    """The stage on the north-east: a roofed platform with a painted back, lamps along its front, three
    rows of benches before it."""
    at, yaw = (30.0, 30.0, Z), 135
    p = local(at, yaw)  # its front (local +Y) faces the middle
    box((19.0, 10.0, 1.6), p(0, 0), S.WOOD, rng, yaw=yaw)
    for i in range(3):
        box((6.0, 1.0, 1.6 - 0.4 * (i + 1)), p(0, 5.5 + i * 1.0), S.WOOD_DARK, rng, yaw=yaw)  # steps
    for sx in (-9.0, 9.0):
        for sy in (-4.4, 4.4):
            box((0.7, 0.7, 9.6), p(sx, sy, 1.6), S.WOOD_DARK, rng, yaw=yaw)
    box((18.4, 0.5, 8.6), p(0, -4.4, 1.6), (70, 110, 170), rng, yaw=yaw, chance=0.1)  # the painted back: sky, hills, a sun
    for dx, w, h, rgb in ((-5.5, 8.0, 3.0, (96, 170, 96)), (4.0, 10.0, 4.0, (76, 150, 90))):
        box((w, 0.2, h), p(dx, -4.1, 1.6), rgb, rng, yaw=yaw)
    post(1.6, 0.2, p(5.6, -4.05, 7.6), (255, 214, 90), rng, n=12, rot=(90, 0, yaw))
    roof(22.0, 12.5, 3.4, p(0, 0, 11.2), (64, 130, 150), rng, yaw=yaw, ridge=14.0)
    for i in range(7):
        neon(S.k.ico(0.34, p(-7.5 + i * 2.5, 4.6, 2.0), subdiv=1), S.LANTERN, 2.6)  # lamps along the front
    bunting(p(-9.0, 4.4, 10.6), p(9.0, 4.4, 10.6), 1.6, rng, PARTY, n=13, size=1.1)
    turn([(1.0, 0.0), (1.2, 0.9), (1.0, 1.8)], p(-5.5, -1.0, 1.6), (176, 70, 60), rng, n=10)  # a drum
    box((0.5, 0.5, 4.0), p(4.0, 1.0, 1.6), S.INK, rng, yaw=yaw)  # a stand to sing at
    lump(p(4.0, 1.0, 5.9), 0.4, IRON, rng, kind=S.COOL)
    for row in range(3):
        for dx in (-5.6, 0.0, 5.6):
            spin(bench(p(dx, 11.5 + row * 3.6), rng), p(dx, 11.5 + row * 3.6), yaw)
    actor("creature_meerkat", p(-1.5, 0.5, 1.6), yaw + 180)
    actor("creature_meerkat_star", p(2.0, -0.5, 1.6), yaw + 200)


def green(rng):
    """The green on the south-east: the meeting tree with a bench round its trunk and a swing, a pond
    with a little pier, a trough and a rail for the animals, hay."""
    tx, ty = 25.0, -25.0
    disc(11.0, (tx, ty, Z), 0.5, (104, 168, 76), rng, n=16, chance=0.3)
    bark = (124, 92, 66)
    pipe([(tx, ty, Z), (tx + 0.4, ty + 0.3, 7.0), (tx - 0.3, ty - 0.2, 12.5), (tx + 0.2, ty, 16.5)], [2.5, 1.9, 1.5, 1.0], bark, rng, n=8)
    for i in range(6):
        a = i * 60 + 15
        pipe([(tx, ty, 11.0), tuple(Vector((tx, ty, 15.0)) + polar(5.0, a)), tuple(Vector((tx, ty, 17.0)) + polar(9.5, a))], [0.9, 0.6, 0.3], bark, rng, n=5)
        pipe([(tx, ty, 3.0), tuple(Vector((tx, ty, 1.2)) + polar(3.0, a + 30)), tuple(Vector((tx, ty, Z + 0.4)) + polar(5.4, a + 30))], [0.8, 0.5, 0.2], bark, rng, n=5)
    crown = [(0.0, 0.0, 22.0, 6.4)] + [(*polar(8.2, i * 60 + 15)[:2], 18.6, 5.6) for i in range(6)] + [(*polar(4.6, i * 120 + 70)[:2], 24.5, 4.6) for i in range(3)]
    for dx, dy, dz, r in crown:
        lump((tx + dx, ty + dy, dz), (r, r, r * 0.72), (92 + rng.randrange(30), 170, 92), rng)
    slab(4.4, 6.2, 0, 360, Z + 0.5, 1.2, S.WOOD, rng, centre=(tx, ty), step=30)  # the bench round the trunk
    slab(4.2, 4.6, 0, 360, Z + 1.7, 1.1, S.WOOD_DARK, rng, centre=(tx, ty), step=30)
    for i in range(9):  # lanterns in its boughs
        q = Vector((tx, ty, 13.2 + (i % 3) * 0.9)) + polar(4.0 + (i % 2) * 3.4, i * 40 + 5)
        pipe([tuple(q + Vector((0, 0, 2.2))), tuple(q)], 0.05, S.INK, rng, n=4)
        neon(S.k.ico(0.5, tuple(q), subdiv=1), S.LANTERN, 2.6)
    sw = Vector((tx, ty, 16.8)) + polar(8.6, 195)  # the swing
    for dx in (-0.9, 0.9):
        pipe([(sw.x + dx, sw.y, sw.z), (sw.x + dx, sw.y, Z + 2.2)], 0.06, HAY, rng, n=4)
    box((2.4, 0.9, 0.2), (sw.x, sw.y, Z + 2.1), S.WOOD, rng)
    px, py = 36.5, -9.5  # the pond
    disc(6.2, (px, py, Z - 0.05), 0.3, S.WATER, rng, n=14, surface="gem", kind=S.COOL, emit=0.25, chance=0.06)
    for i in range(16):
        s = rng.uniform(0.8, 1.3)
        lump(Vector((px, py, Z + 0.3)) + polar(6.5, i * 22.5 + rng.uniform(-5, 5)), (s, s * 0.9, s * 0.7), (150, 144, 136), rng, surface="rock", kind=S.COOL)
    for i in range(5):
        q = Vector((px, py, Z + 0.28)) + polar(rng.uniform(1.5, 4.6), i * 72 + 20)
        post(rng.uniform(0.6, 0.9), 0.06, q, (70, 150, 84), rng, n=7)
        if i % 2 == 0:
            for j in range(6):
                shard(q + Vector((0, 0, 0.06)), q + polar(0.5, j * 60, 0.55), 0.3, 0.1, (255, 170, 200), rng)
    for i in range(5):  # the pier
        box((1.3, 3.0, 0.2), (px - 7.4 + i * 1.4, py - 1.0, Z + 0.7), S.WOOD, rng)
    for dx in (-7.6, -1.8):
        for dy in (-2.4, 0.4):
            post(0.2, 1.6, (px + dx, py + dy, Z - 0.1), S.WOOD_DARK, rng, n=5)
    for i in range(6):  # reeds
        q = Vector((px, py, Z)) + polar(5.6, 40 + i * 9)
        post(0.07, rng.uniform(2.0, 3.2), q, (96, 150, 80), rng, n=4)
        lump(q + Vector((0, 0, 3.0)), (0.14, 0.14, 0.5), (120, 84, 56), rng)
    qx, qy = 9.5, -37.5  # the trough and the rail
    box((9.0, 2.6, 1.6), (qx, qy, Z), S.WOOD_DARK, rng, yaw=8)
    box((8.4, 2.0, 0.2), (qx, qy, Z + 1.5), S.WATER, rng, yaw=8, surface="gem", kind=S.COOL, emit=0.25)
    for dx in (-4.0, 0.0, 4.0):
        post(0.3, 3.4, (qx + dx, qy - 4.4, Z), S.WOOD_DARK, rng, n=6)
    box((8.8, 0.3, 0.3), (qx, qy - 4.4, Z + 3.0), S.WOOD, rng)
    for i, (dx, dy) in enumerate(((7.5, -1.0), (9.2, 1.8), (8.2, 0.2))):
        box((2.6, 1.6, 1.4), (qx + dx, qy + dy, Z + (1.4 if i == 2 else 0)), HAY, rng, yaw=20 + i * 30)
    for x, y, yaw in ((12.0, -14.0, 20), (38.0, -28.0, -30)):  # picnic tables
        t = local((x, y, Z), yaw)
        box((5.4, 2.4, 0.25), t(0, 0, 2.3), S.WOOD, rng, yaw=yaw)
        for sy in (-2.0, 2.0):
            box((5.4, 0.9, 0.2), t(0, sy, 1.3), S.WOOD, rng, yaw=yaw)
        for sx in (-2.0, 2.0):
            box((0.3, 4.8, 0.3), t(sx, 0, 1.0), S.WOOD_DARK, rng, yaw=yaw)
            box((0.3, 0.3, 2.3), t(sx, 0, 0), S.WOOD_DARK, rng, yaw=yaw)
        lump(t(0.6, 0.2, 2.75), (0.7, 0.5, 0.3), (226, 90, 80), rng)


def lights(rng):
    """Lamps on the kerb, strings of flags from a ring of poles out to them, planters and bushes between."""
    poles = []
    for i in range(8):
        a = 22.5 + i * 45
        q = polar(18.2, a, Z)
        post(0.45, 0.5, q, S.WOOD_DARK, rng, n=6)
        post(0.2, 9.0, q + Vector((0, 0, 0.5)), S.WOOD_DARK, rng, n=6)
        lump(q + Vector((0, 0, 9.7)), 0.34, S.GOLD, rng)
        poles.append(q + Vector((0, 0, 9.4)))
        lamp = polar(45.4, a, 0.5)
        spin(lantern(lamp, rng, h=6.6), lamp, a + 180)
        bunting(poles[-1], lamp + Vector((0, 0, 7.0)), 1.8, rng, PARTY, n=14, size=0.8)
        turn([(1.0, 0.0), (1.4, 1.0), (1.3, 1.25)], polar(44.0, a + 9, Z), S.STONE, rng, n=8, kind=S.PALE)
        flowers(polar(44.0, a + 9, Z + 1.2), rng, n=8, spread=0.8)
        bush(polar(44.6, a - 9, Z), rng, 0.8)
    for a, b in zip(poles, poles[1:] + poles[:1]):
        bunting(a, b, 1.5, rng, PARTY, n=10, size=0.8)


def signs(rng):
    """A finger post at each road, the notice board, the plain arch over the south walk."""
    signs = {90: ("WAVE ARENA", (88, 52, 140)), 0: ("RANCHES", (70, 140, 80)), 180: ("RANCHES", (70, 140, 80)), 270: ("WAY IN", (60, 120, 200))}
    for a, (name, rgb) in signs.items():  # a finger post beside each road
        q = polar(44.5, a + 13, Z)
        post(0.28, 7.6, q, S.WOOD_DARK, rng, n=6)
        prism([(-3.0, -0.6), (2.4, -0.6), (3.2, 0.0), (2.4, 0.6), (-3.0, 0.6)], (0, 0, 0), 0.26, rgb, rng).data.transform(S.k._xf((q.x, q.y, 6.3), (90, 0, a)))
        for face in (-1, 1):
            words(name, q + polar(0.08 if face > 0 else -0.34, a + 90) + Vector((0, 0, 6.3)), 0.62, S.WHITE, yaw=a + 90 + 90 * face)
        box((2.6, 0.2, 0.8), q + Vector((0, 0, 4.6)), (176, 150, 118), rng, yaw=a + 40)
    nb = local((-41.6, 5.8, Z), -82)  # the notice board
    for sx in (-3.0, 3.0):
        box((0.4, 0.4, 6.0), nb(sx, 0), S.WOOD_DARK, rng, yaw=-82)
    box((6.6, 0.3, 3.8), nb(0, 0, 2.0), (176, 140, 96), rng, yaw=-82)
    roof(7.6, 1.6, 0.9, nb(0, 0, 6.0), (176, 70, 60), rng, yaw=-82, ridge=7.6)
    for i in range(8):
        box((1.1, 0.06, 1.3), nb(-2.4 + (i % 4) * 1.6, -0.2, 2.3 + (i // 4) * 1.7), (S.WHITE, (255, 236, 150), (190, 226, 255), (255, 200, 210))[i % 4], rng, yaw=-82, tilt=(0, rng.uniform(-6, 6)))
    mid = polar(50.5, 270)  # the arch over the south walk: two trunks, a beam, a board on chains
    for side in (-1, 1):
        post(0.9, 10.0, mid + Vector((side * 9.4, 0, 0)), (124, 92, 66), rng, n=7, r2=0.7)
        spin(lantern(mid + Vector((side * 11.6, -0.6, 0)), rng, h=5.4), mid + Vector((side * 11.6, -0.6, 0)), 90 - 90 * side)
    box((22.0, 1.3, 1.1), mid + Vector((0, 0, 9.6)), S.WOOD_DARK, rng)
    box((12.5, 0.4, 2.6), mid + Vector((0, 0, 6.2)), S.WOOD, rng)
    for sx in (-5.0, 5.0):
        pipe([(mid.x + sx, mid.y, 9.6), (mid.x + sx, mid.y, 8.8)], 0.07, S.INK, rng, n=4)
    for face in (-1, 1):
        words("ANIMAL STATIONS", mid + Vector((0, 0.24 * face, 7.5)), 1.0, S.WHITE, yaw=90 + 90 * face)
    bunting(mid + Vector((-9.4, 0, 9.0)), mid + Vector((9.4, 0, 9.0)), 1.4, rng, PARTY, n=13, size=0.9)


def build(rng):
    floor(rng)
    fire(rng)
    stall_row(rng)
    cafe(rng)
    stage(rng)
    green(rng)
    lights(rng)
    signs(rng)
    for a in (0, 90, 180, 270):  # the roads out
        way = polar(72.5, a)
        box((45.0, 10.5, 0.14), way, (206, 190, 160), rng, yaw=a, kind=S.PALE)
    H.surroundings(rng)
    # who is here
    actor("creature_lion", (-11.5, 0.0, Z), 90)  # by the fire
    actor("creature_cheetah", (0.5, -21.5, Z), 180)
    actor("creature_jackal", (-14.0, -27.0, Z), 300)  # at the market
    actor("creature_tortoise", (-23.0, 9.0, Z), 100)  # on its way to the cafe
    actor("creature_flamingo", (30.5, -5.0, Z), 200)  # at the pond
    actor("creature_rhino", (9.5, -29.0, Z), 0)  # at the trough
    actor("creature_elephant", (-6.0, 37.5, Z), 100)  # coming in from the arena road


SCENES = [
    dict(
        name="hub_commons",
        build=build,
        shots=[
            ((-70, -112, 74), (0, 2, 4), 34),  # the whole plaza from the south-west
            ((2.5, -74, 4.6), (0, 0, 8.0), 30),  # walking in from the south road
            ((-14, -19, 8.5), (2, 4, 3.0), 28),  # the fire and its benches
            ((-4.0, -9.0, 6.5), (-30, -28, 4.5), 28),  # the market
        ],
    ),
]
