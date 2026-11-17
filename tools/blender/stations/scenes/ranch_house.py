"""A new Ranch House (concept, decision 0074): a classic farmhouse of fieldstone and timber, in three looks
for the house's levels: a homesteader's cottage, a farmhouse with a stone ground floor and a long porch,
and a great farmhouse with a second floor, a cross wing and a porch round its corner.

It is written like the homestead's buildings (scenes/homestead.py): round its own middle, its front
towards -Y, and no bigger than the place the house has on the homestead (56 studs wide, 40 deep). Concept
only: nothing here is a game model yet.
"""

import math

import bpy
import stage as S
from mathutils import Matrix, Vector
from stage import bench, box, bush, flowers, lantern, lump, neon, pine, polar, post, roof, tree, words

FIELD = (172, 164, 150)  # fieldstone
BOARD = (200, 154, 102)  # timber boards
BEAM = (108, 74, 48)
TRIM = (242, 232, 210)
SHINGLE = (124, 86, 62)
SHUTTER = (68, 110, 84)
DOOR = (152, 60, 48)
DECK = (168, 120, 78)
LIT = (255, 226, 150)
PATH = (214, 196, 160)
GROUND = 0.15

_now = {"first": 0, "last": S.TOP}


def _tag():
    for ob in bpy.data.objects:
        if ob.type == "MESH" and "first" not in ob:
            ob["first"], ob["last"] = _now["first"], _now["last"]


def lv(first=0, last=S.TOP):
    """What is built from here on stands from level stage `first` to `last` on the card."""
    _tag()
    _now.update(first=first, last=last)


class Wall:
    """A wall's own frame: x along it, `out` away from it, standing on `at`; `yaw` 0 faces -Y, 90 faces +X."""

    def __init__(self, at, yaw):
        self.at, self.yaw = Vector(at), yaw
        self.c, self.s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def p(self, x, out=0.0, z=0.0):
        return (self.at.x + x * self.c + out * self.s, self.at.y + x * self.s - out * self.c, self.at.z + z)

    def box(self, size, x, out, z, rgb, rng, **look):
        return box(size, self.p(x, out, z), rgb, rng, yaw=self.yaw, **look)

    def lit(self, w, h, x, out, z):
        px, py, pz = self.p(x, out, z)
        return neon(S.k.box((w, 0.3, h), (px, py, pz + h / 2), (0, 0, self.yaw)), LIT, 1.3)


def slab(w, length, thick, matrix, rgb, rng, **look):
    """A flat board `w` wide and `length` long, put where `matrix` says: roofs are made of these."""
    ob = S.k.box((w, length, thick), (0, 0, 0), (0, 0, 0))
    ob.data.transform(matrix)
    return S.paint(ob, rgb, rng, **look)


def slope(w, run, rise, at, rgb, rng, yaw=0.0, thick=0.5):
    """One side of a roof: from its top edge at `at` it runs `run` out (towards -Y at yaw 0) and `rise` down."""
    a, length = math.atan2(rise, run), math.hypot(run, rise)
    middle = Vector((0, -length / 2 * math.cos(a), -length / 2 * math.sin(a))) + Vector((0, -math.sin(a), math.cos(a))) * thick / 2
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Translation(middle) @ Matrix.Rotation(a, 4, "X")
    return slab(w, length, thick, m, rgb, rng)


def gable(w, d, rise, at, rng, yaw=0.0, over=1.3, ends=BOARD, rgb=SHINGLE):
    """A gabled roof over a box `w` by `d` whose top's middle is `at`: its ridge runs along x (turned by
    `yaw`), its two gable ends are filled with `ends`, and it hangs `over` past the walls."""
    roof(w, d, rise * 0.985, at, ends, rng, yaw=yaw, ridge=w)  # the gable ends, under the two sides
    top = (at[0], at[1], at[2] + rise)
    run = d / 2 + over
    for side in (0, 180):
        slope(w + 2 * over, run, rise * run / (d / 2), top, rgb, rng, yaw=yaw + side)
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    box((w + 2 * over + 0.2, 0.9, 0.5), (at[0], at[1], top[2] + 0.15), BEAM, rng, yaw=yaw)  # the ridge board
    return c, s


def walls(cx, cy, w, d, z0):
    """The four walls of a block as frames: front (-Y), back, left (-X), right."""
    return {
        "front": Wall((cx, cy - d / 2, z0), 0),
        "back": Wall((cx, cy + d / 2, z0), 180),
        "left": Wall((cx - w / 2, cy, z0), 270),
        "right": Wall((cx + w / 2, cy, z0), 90),
    }


def stone_floor(cx, cy, w, d, z0, h, rng):
    """A storey of fieldstone: rough walls with bigger corner stones."""
    box((w, d, h), (cx, cy, z0), FIELD, rng, surface="rock", kind=S.COOL)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for i in range(int(h // 1.8)):
                long = 1.9 if i % 2 else 1.3
                box((long, long, 1.5), (cx + sx * (w / 2 - long / 2 + 0.15), cy + sy * (d / 2 - long / 2 + 0.15), z0 + 0.1 + i * 1.8), (190, 184, 172), rng, surface="rock", kind=S.PALE)
    return walls(cx, cy, w, d, z0)


def timber_floor(cx, cy, w, d, z0, h, rng):
    """A storey of timber: boards laid along every wall, a beam under and over them, posts at the corners."""
    box((w - 0.4, d - 0.4, h), (cx, cy, z0), BOARD, rng)
    ws = walls(cx, cy, w, d, z0)
    rows = max(1, round(h / 1.05))
    for name, length in (("front", w), ("back", w), ("left", d), ("right", d)):
        for i in range(rows):
            ws[name].box((length - 0.5, 0.3, h / rows - 0.12), 0, 0.0, i * h / rows + 0.06, BOARD, rng, chance=0.5)
        ws[name].box((length + 0.3, 0.5, 0.6), 0, 0.1, -0.3, BEAM, rng)
        ws[name].box((length + 0.3, 0.5, 0.5), 0, 0.1, h - 0.25, BEAM, rng)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.9, 0.9, h), (cx + sx * (w / 2 - 0.2), cy + sy * (d / 2 - 0.2), z0), BEAM, rng)
    return ws


def window(wall, x, z, rng, w=3.0, h=3.6, shutters=True, planter=False):
    """A lit window with a pale frame and a cross; green shutters; a box of flowers under it."""
    wall.lit(w, h, x, 0.25, z)
    wall.box((w + 0.9, 0.5, 0.45), x, 0.3, z + h, TRIM, rng)
    wall.box((w + 1.1, 0.7, 0.45), x, 0.4, z - 0.45, TRIM, rng)
    for sx in (-1, 1):
        wall.box((0.4, 0.5, h), x + sx * (w / 2 + 0.2), 0.3, z, TRIM, rng)
    wall.box((0.22, 0.4, h), x, 0.42, z, TRIM, rng)
    wall.box((w, 0.4, 0.22), x, 0.42, z + h / 2 - 0.11, TRIM, rng)
    if shutters:
        for sx in (-1, 1):
            wall.box((w * 0.4, 0.3, h + 0.2), x + sx * (w * 0.7 + 0.5), 0.3, z - 0.1, SHUTTER, rng)
    if planter:
        wall.box((w + 0.6, 0.9, 0.7), x, 0.7, z - 1.15, BEAM, rng)
        px, py, pz = wall.p(x, 0.7, z - 0.45)
        flowers((px, py, pz), rng, n=8, spread=w * 0.36)


def door(wall, x, z, rng, w=4.2, h=6.8):
    """The front door: red boards in a pale frame, a lamp beside it."""
    wall.box((w, 0.5, h), x, 0.25, z, DOOR, rng)
    wall.box((0.5, 0.7, h + 0.4), x - w / 2 - 0.25, 0.3, z, TRIM, rng)
    wall.box((0.5, 0.7, h + 0.4), x + w / 2 + 0.25, 0.3, z, TRIM, rng)
    wall.box((w + 1.6, 0.8, 0.6), x, 0.35, z + h, TRIM, rng)
    wall.box((0.3, 0.3, 0.6), x + w / 2 - 0.7, 0.6, z + h * 0.45, (250, 196, 60), rng)
    px, py, pz = wall.p(x + w / 2 + 1.5, 0.5, z + h * 0.72)
    neon(S.k.cyl(0.4, 0.8, (px, py, pz), n=6), LIT)


def chimney(x, y, z_top, rng, w=3.6, d=3.0, smoke=True):
    """A fieldstone chimney up the outside of a wall, from the ground to above the ridge."""
    box((w + 0.8, d + 0.8, 5.0), (x, y, GROUND), FIELD, rng, surface="rock", kind=S.COOL)
    box((w, d, z_top - GROUND), (x, y, GROUND), FIELD, rng, surface="rock", kind=S.COOL)
    box((w + 0.8, d + 0.8, 0.7), (x, y, z_top), (150, 144, 134), rng, surface="rock", kind=S.COOL)
    for dx in (-0.8, 0.8):
        post(0.5, 1.2, (x + dx, y, z_top + 0.7), (168, 96, 70), rng, n=7)
    if smoke:
        for k in range(3):
            lump((x + k * 0.9, y + k * 0.3, z_top + 3.2 + k * 2.0), 1.0 + k * 0.4, S.WHITE, rng, kind=S.PALE)


def porch(wall, x0, x1, depth, floor_z, eave_z, rng, steps=0.0, rail=True, roofed=True):
    """A porch along a wall from x0 to x1: a deck on stone piers, posts, a rail with a gap at the steps, and
    a roof that leans on the wall."""
    length, mid = x1 - x0, (x0 + x1) / 2
    wall.box((length, depth, 0.5), mid, depth / 2, floor_z - 0.5, DECK, rng, chance=0.4)
    for i in range(int(length // 2.2)):  # the deck's boards
        wall.box((1.9, depth - 0.2, 0.12), x0 + 1.1 + i * 2.2, depth / 2, floor_z, (176, 128, 84) if i % 2 else DECK, rng)
    n = max(2, round(length / 6.5) + 1)
    xs = [x0 + 0.6 + i * (length - 1.2) / (n - 1) for i in range(n)]
    for x in xs:
        wall.box((1.2, 1.2, floor_z - 0.5), x, depth - 0.7, 0.0, FIELD, rng, surface="rock", kind=S.COOL)
        if roofed:
            wall.box((0.6, 0.6, eave_z - floor_z - 2.2), x, depth - 0.7, floor_z, BEAM, rng)
            wall.box((1.5, 0.5, 0.5), x, depth - 0.7, eave_z - 2.9, BEAM, rng)
    if rail:
        for a, b in zip(xs, xs[1:]):
            if a < steps < b:
                continue
            wall.box((b - a - 0.6, 0.25, 0.3), (a + b) / 2, depth - 0.7, floor_z + 2.6, BEAM, rng)
            for k in range(int((b - a) // 1.2)):
                wall.box((0.22, 0.22, 2.5), a + 0.9 + k * 1.2, depth - 0.7, floor_z + 0.1, TRIM, rng)
    for k in range(3):  # the steps
        wall.box((5.0, 1.3, floor_z - 0.5 - k * (floor_z - 0.5) / 3), steps, depth + 0.65 + k * 1.3, 0.0, FIELD, rng, surface="rock", kind=S.PALE)
    if roofed:
        px, py, pz = wall.p(mid, -0.2, eave_z)
        slope(length + 1.6, depth + 1.4, 1.9, (px, py, pz), SHINGLE, rng, yaw=wall.yaw, thick=0.45)
        wall.box((length + 1.0, 0.5, 0.6), mid, depth - 0.7, eave_z - 2.2, BEAM, rng)


def dormer(x, y_front, z, rng, w=4.6, depth=5.0, h=3.4):
    """A dormer window standing out of the front of a roof, under a little gable of its own."""
    cy = y_front + depth / 2
    box((w, depth, h), (x, cy, z), BOARD, rng)
    front = Wall((x, y_front, z), 0)
    window(front, 0, 0.5, rng, w=2.4, h=2.4, shutters=False)
    gable(depth + 0.6, w, 2.2, (x, cy, z + h), rng, yaw=90, over=0.5)


def woodpile(at, rng, yaw=0.0):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    for row in range(3):
        for i in range(5 - row):
            x = (i - (4 - row) / 2) * 1.25
            post(0.6, 4.4, (at[0] + x * c, at[1] + x * s, at[2] + 0.6 + row * 1.05), (176, 128, 84), rng, n=7, rot=(90, 0, yaw))


def rocker(at, rng, yaw=0.0):
    """A rocking chair for the porch; it faces along its local -Y."""
    w = Wall(at, yaw)
    w.box((2.2, 2.0, 0.25), 0, 0, 1.3, BEAM, rng)
    w.box((2.2, 0.25, 2.6), 0, -1.0, 1.4, BEAM, rng)
    for sx in (-1, 1):
        w.box((0.25, 2.6, 0.3), sx * 1.0, 0, 0.0, BEAM, rng)
        w.box((0.22, 0.22, 1.3), sx * 1.0, 0.8, 0.1, BEAM, rng)


# The three looks ---------------------------------------------------------------------------------------------


def cottage(rng):
    """Look 1 (levels 0 and 1): a homesteader's cottage: timber on a fieldstone footing, a stone chimney up
    its end, a small roofed stoop."""
    w, d, foot, h, rise = 20, 14, 1.6, 8.0, 6.0
    box((w + 1.2, d + 1.2, foot), (0, 0, GROUND), FIELD, rng, surface="rock", kind=S.COOL)
    ws = timber_floor(0, 0, w, d, GROUND + foot, h, rng)
    gable(w, d, rise, (0, 0, GROUND + foot + h), rng)
    chimney(w / 2 + 1.7, 1.0, GROUND + foot + h + rise + 1.8, rng, w=3.2)
    door(ws["front"], 0, 0.0, rng, h=6.4)
    for x in (-6.2, 6.2):
        window(ws["front"], x, 2.4, rng, planter=True)
    window(ws["left"], 0, 2.4, rng, w=2.6)
    window(ws["back"], -4, 2.4, rng, w=2.6, shutters=False)
    porch(ws["front"], -4.6, 4.6, 5.0, 0.0, 7.6, rng, steps=0.0, rail=False)
    woodpile((-w / 2 - 2.2, -1.0, GROUND), rng, yaw=90)
    post(1.3, 2.8, (w / 2 - 2, -d / 2 - 2.2, GROUND), BEAM, rng, n=8)  # a rain barrel
    words("RANCH HOUSE", (0, -d / 2 - 5.6, GROUND + foot + 7.4), 0.95, S.WHITE, glow=0.5)
    box((9.2, 0.4, 1.7), (0, -d / 2 - 5.3, GROUND + foot + 6.55), BEAM, rng)


def farmhouse(rng):
    """Look 2 (levels 2 and 3): a farmhouse: a fieldstone ground floor, a timber half floor under the roof
    with two dormers, a porch the length of its front."""
    w, d, h, knee, rise = 28, 18, 9.0, 2.6, 8.0
    ws = stone_floor(0, 0, w, d, GROUND, h, rng)
    up = timber_floor(0, 0, w, d, GROUND + h, knee, rng)
    top = GROUND + h + knee
    gable(w, d, rise, (0, 0, top), rng)
    chimney(-w / 2 - 1.8, 1.5, top + rise + 2.0, rng)
    door(ws["front"], 0, 1.6, rng)
    for x in (-10.4, -5.4, 5.4, 10.4):
        window(ws["front"], x, 3.6, rng, w=2.8, h=3.4, planter=abs(x) > 8)
    for name in ("left", "right"):
        window(ws[name], -4.5 if name == "left" else 0, 3.6, rng, w=2.8, h=3.4)
        window(up[name], 0, 2.6, rng, w=2.6, h=2.8, shutters=False)  # in the gable end, under the ridge
    window(ws["back"], -7, 3.6, rng, w=2.8, h=3.4)
    window(ws["back"], 7, 3.6, rng, w=2.8, h=3.4)
    porch(ws["front"], -w / 2 - 0.5, w / 2 + 0.5, 6.4, 1.6, GROUND + h + 1.2, rng, steps=0.0)
    for x in (-7.5, 7.5):
        dormer(x, -d / 2 + 3.0, top + rise * 0.3, rng)
    rocker((-9.5, -d / 2 - 2.6, GROUND + 1.6), rng, yaw=0)
    for sx in (-1, 1):
        lantern((sx * 4.4, -d / 2 - 10.4, GROUND), rng, h=6.0)
    woodpile((w / 2 + 2.4, 3.0, GROUND), rng, yaw=90)
    words("RANCH HOUSE", (0, -d / 2 - 7.15, GROUND + h - 2.3), 1.1, S.WHITE, glow=0.5)
    box((11.0, 0.4, 2.0), (0, -d / 2 - 6.85, GROUND + h - 3.3), BEAM, rng)


def great_house(rng):
    """Look 3 (level 4): a great farmhouse: two floors, fieldstone below and timber above, a cross wing with
    its gable to the front, a porch round the corner between them, two chimneys, a cupola."""
    w, d, h, up_h, rise = 30, 20, 9.0, 8.0, 8.5
    mx = -5.0  # the main block's middle; the wing stands at its right end
    ws = stone_floor(mx, 0, w, d, GROUND, h, rng)
    up = timber_floor(mx, 0, w, d, GROUND + h, up_h, rng)
    top = GROUND + h + up_h
    gable(w, d, rise, (mx, 0, top), rng)
    ww, wd, wx, wy = 13, 19, mx + w / 2 + 4.5, -3.5
    wing = stone_floor(wx, wy, ww, wd, GROUND, h, rng)
    wing_up = timber_floor(wx, wy, ww, wd, GROUND + h, up_h - 1.2, rng)
    gable(wd, ww, 6.4, (wx, wy, top - 1.2), rng, yaw=90)
    chimney(mx - w / 2 - 1.8, 2.0, top + rise + 2.0, rng)
    chimney(wx + ww / 2 + 1.7, wy + 3.0, top + 6.6, rng, w=3.2)
    # the main block: the door, five windows over it, four beside it
    door(ws["front"], -1.0, 1.6, rng)
    for x in (-11.0, -6.2, 4.2):
        window(ws["front"], x, 3.6, rng, w=2.8, h=3.4)
    for x in (-11.0, -6.0, -1.0, 4.0):
        window(up["front"], x, 2.2, rng, w=2.6, h=3.4, planter=True)
    for wall_set in (ws, up):
        window(wall_set["left"], -4.6, 3.4 if wall_set is ws else 2.2, rng, w=2.8, h=3.4)
        window(wall_set["back"], -8.0, 3.4 if wall_set is ws else 2.2, rng, w=2.8, h=3.4)
        window(wall_set["back"], 4.0, 3.4 if wall_set is ws else 2.2, rng, w=2.8, h=3.4)
    # the wing: a wide window below, a pair above, a round one in its gable
    window(wing["front"], 0, 3.2, rng, w=5.2, h=3.8)
    for x in (-2.6, 2.6):
        window(wing_up["front"], x, 1.6, rng, w=2.2, h=3.2, planter=True)
    neon(S.k.cyl(1.1, 0.3, (wx, wy - wd / 2 - 0.3, top + 1.2), n=10, rot=(90, 0, 0)), LIT, 1.3)
    window(wing["right"], 2.0, 3.4, rng, w=2.8, h=3.4)
    window(wing_up["right"], 2.0, 1.6, rng, w=2.6, h=3.2)
    window(wing["back"], 0, 3.4, rng, w=2.8, h=3.4)
    # the porch: along the main block's front as far as the wing
    porch(ws["front"], -w / 2 - 0.5, w / 2 - 4.6, 6.6, 1.6, GROUND + h + 1.2, rng, steps=-1.0)
    rocker((mx - 10.5, -d / 2 - 2.8, GROUND + 1.6), rng)
    rocker((mx - 6.6, -d / 2 - 2.8, GROUND + 1.6), rng)
    for sx in (-1, 1):
        lantern((mx - 1.0 + sx * 9.5, -d / 2 - 10.8, GROUND), rng, h=6.4)  # clear of the name over the steps
    # a cupola on the ridge, with a weather vane
    box((4.0, 4.0, 3.0), (mx, 0, top + rise - 0.6), BOARD, rng)
    for face in walls(mx, 0, 4.0, 4.0, top + rise - 0.6).values():
        face.lit(1.6, 1.6, 0, 0.2, 0.8)
    roof(5.4, 5.4, 2.6, (mx, 0, top + rise + 2.4), SHINGLE, rng)
    post(0.12, 3.2, (mx, 0, top + rise + 5.0), S.INK, rng, n=4)
    box((2.6, 0.12, 0.9), (mx + 0.4, 0, top + rise + 7.2), (250, 196, 60), rng)
    woodpile((mx - w / 2 - 2.4, -5.0, GROUND), rng, yaw=90)
    bench((wx + 1.0, wy - wd / 2 - 2.4, GROUND), rng, yaw=180)
    words("RANCH HOUSE", (mx - 1.0, -d / 2 - 7.35, GROUND + h - 2.3), 1.2, S.WHITE, glow=0.5)
    box((12.0, 0.4, 2.2), (mx - 1.0, -d / 2 - 7.05, GROUND + h - 3.4), BEAM, rng)


LOOKS = (cottage, farmhouse, great_house)


def build(rng):
    for t, maker in enumerate(LOOKS):
        lv(t * 2, t * 2 + 1)
        maker(rng)
    lv(0)
    box((7, 46, 0.25), (-1, -38, 0.02), PATH, rng, kind=S.PALE, chance=0.3)  # the path to its door
    for i in range(26):
        a, r = rng.uniform(15, 165), rng.uniform(56, 110)
        p = polar(r, a)
        (pine if rng.random() < 0.4 else tree)((p.x, p.y, 0), rng, s=rng.uniform(1.4, 2.4))
    for x, y in ((-26, -16), (27, -20), (-24, 10), (30, 12), (-30, -30), (33, -34)):
        bush((x, y, GROUND), rng, s=rng.uniform(1.6, 2.4))
    for x, y in ((-12, -24), (10, -26), (-18, -34), (16, -38)):
        flowers((x, y, GROUND), rng, n=12, spread=3.0)
    for i in range(34):
        p = polar(rng.uniform(560, 700), i * 10.6 + rng.uniform(-3, 3))
        foot, tall = rng.uniform(80, 140), rng.uniform(100, 210)
        post(foot, tall, (p.x, p.y, -2), (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        if tall > 150:
            post(foot * 0.36, tall * 0.28, (p.x, p.y, tall * 0.74 - 2), S.WHITE, rng, n=7, r2=foot * 0.1, kind=S.PALE)
    _tag()


SAME = ((-36, -50, 21), (0, -2, 9))
SCENES = [
    dict(
        name="ranch_house",
        build=build,
        ground=(104, 164, 78),
        shots=[
            ((-50, -64, 26), (0, -2, 11), 32, 4),  # the great farmhouse: the house at its top level
            (*SAME, 34, 0),  # the cottage: a new ranch
            (*SAME, 34, 2),  # the farmhouse: levels 2 and 3
            (*SAME, 34, 4),  # the great farmhouse: level 4
            ((46, 40, 24), (2, 0, 10), 30, 4),  # from behind
            ((-17, -27, 7.5), (-6, -9, 6), 22, 4),  # on the porch
            ((-50, 2, 13), (-10, 0, 11), 30, 4),  # its end, and the chimney up it
        ],
    ),
]
