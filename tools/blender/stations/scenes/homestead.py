"""A ranch's homestead (decisions 0071 and 0072): the middle of the ranch as an open green, not a fenced
square. The herd's meadow is at its heart, a ring path runs round it, and the buildings stand round the
path with open ground between them, so every way out to a training ground is in sight. It fills the
round the valley levels for it (224 studs across) and has eight buildings to upgrade.

The eight buildings are the game's models too (assets/homestead.py): each is written round its own
middle with its front towards -Y, in three looks. With `LIVE` off a building is built without what the
game stands itself: the eggs, their racks, the Titan, the windmill's sails. The sizes at the top are
repeated in src/stations/Ranch.luau (`SOLID`, where the nests go): change the two together.

`lv` says at which stages of building up what follows stands on the card (0: a new ranch, 5: everything
bought); `place` stands a building at its place round the meadow.
"""

import importlib.util
import math
import os

import bpy
import stage as S
from mathutils import Matrix, Vector
from stage import actor, bench, box, bunting, bush, disc, flag, flowers, gem, lantern, lump, neon, pine, pipe, polar, post, rock, roof, slab, tree, turn, words

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(f"scene_{name}", os.path.join(HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


H = _load("hub")
RH = _load("ranch_house")  # the Ranch House: a farmhouse of fieldstone and timber (decision 0074)

LIVE = True  # with what the game stands itself
R = 112.0  # the homestead's radius: src/shared/ValleyMap.luau's HOME
MEADOW = 34.0  # the herd's meadow in its middle
RING = (37.0, 45.0)  # the path round the meadow

# (width, depth, wall height) of each building's three looks
BARN = ((18, 14, 8), (26, 20, 11), (34, 24, 14))
BARN_DOOR = ((7, 6), (10, 8.5), (13, 10.5))
HATCHERY = ((None, None), (11.5, 8), (14.0, 10))  # (radius, posts) of the round ones
CELLAR = (None, ((9, 8, 6), (11, 7.5)), ((11, 9, 7.5), (16, 9)))  # the mound's half sizes, its stone front
BROODER = ((10, 7, 6.5), (15, 9, 7.5), (20, 11, 8.5))
MILL = (None, (6.5, 22.0, 26.0), (7.5, 28.0, 34.0))  # (foot radius, height, the sails' span) of the towers
LODGE = (None, (20, 12, 8), (28, 15, 10))
# the Titan's Den: a hall dug into a hill, its mouth `HALF` either side and `TALL` high, `DEEP` back from
# its face (ValleyMap.DEN): only its front is a model, the hall is the hill's own rock
DEN_HALF, DEN_TALL, DEN_DEEP = 17.5, 21.5, 32.0

PATH = (214, 196, 160)
LAWN = (118, 180, 84)
CREAM = (236, 220, 188)
ROOF_RED = (176, 70, 60)
BARN_RED = (196, 64, 54)
SLATE = (84, 82, 104)
HAY = (228, 196, 110)
THATCH = (198, 164, 96)
GLASS = (170, 224, 236)
IVORY = (240, 232, 208)
SHUTTER = (96, 150, 110)
LIT = (255, 226, 150)
HEAT = (255, 160, 70)
FLAME = (255, 150, 60)
EGGS = ((150, 210, 120), (240, 170, 90), (232, 200, 130), (250, 196, 60), (170, 150, 240))
BANNERS = ((150, 80, 200), (224, 64, 60), (250, 196, 60), (60, 150, 255), (70, 205, 120))

# The ways out to the training grounds: name, the angle it leaves at in ValleyMap's plan (90 is away from
# the hub), its stat's colour. The road to the hub leaves at 270. `plan` turns such an angle into a place.
WAYS = (
    ("SPEED TRACK", 13, (60, 150, 255)),
    ("GUARD YARD", 62, (255, 165, 50)),
    ("HEALING SPRING", 110, (70, 205, 120)),
    ("MAGIC LIBRARY", 158, (60, 215, 225)),
    ("STRENGTH GYM", 206, (235, 70, 70)),
    ("SWIM POOL", 325, (170, 90, 245)),
)
HUB = 270

_now = {"first": 0, "last": S.TOP}


def _tag():
    for ob in bpy.data.objects:
        if ob.type == "MESH" and "first" not in ob:
            ob["first"], ob["last"] = _now["first"], _now["last"]


def lv(first=0, last=S.TOP):
    """What is built from here on stands from stage `first` to stage `last`."""
    _tag()
    _now.update(first=first, last=last)


def plan(r, deg, z=0.0):
    """The point `r` studs out at `deg` degrees of ValleyMap's plan (and Ranch.luau's), seen from above: the
    plan's x runs to the left when its z, away from the hub, runs up the page."""
    return polar(r, 180 - deg, z)


def place(maker, r, deg, rng, flip=False):
    """Builds `maker(rng)` and stands it `r` studs from the middle at the plan's angle `deg`, its front to
    the middle (or away from it)."""
    old = {ob.name for ob in bpy.data.objects}
    maker(rng)
    m = Matrix.Translation(plan(r, deg)) @ Matrix.Rotation(math.radians(90 - deg + (180 if flip else 0)), 4, "Z")
    seen = set()
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name not in old and ob.data.name not in seen:
            seen.add(ob.data.name)
            ob.data.transform(m)


def sign(text, at, rng, size=1.4, board=S.WOOD_DARK):
    """A name board facing -Y, its middle at `at`."""
    box((len(text) * size * 0.72 + 1.6, 0.5, size * 1.9), (at[0], at[1], at[2] - size * 0.95), board, rng)
    words(text, (at[0], at[1] - 0.33, at[2]), size, S.WHITE, glow=0.5)


def window(size, at):
    """A lit window, standing on `at`: it glows (Neon in the game)."""
    return neon(S.k.box(size, (at[0], at[1], at[2] + size[2] / 2), (0, 0, 0)), LIT, 1.3)


def egg(at, rng, i=0, s=1.0):
    lump((at[0], at[1], at[2] + 1.15 * s), (0.85 * s, 0.85 * s, 1.15 * s), EGGS[i % len(EGGS)], rng)


def nest(at, rng, i=0):
    post(2.0, 0.7, at, HAY, rng, n=8)
    egg((at[0], at[1], at[2] + 0.5), rng, i)


def rack(x, y, cols, rows, rng):
    """The egg storage's rack as the game builds it, with eggs on it: for the card only."""
    for sx in (-1, 1):
        post(0.3, rows * 2.3 + 1.4, (x + sx * cols * 1.3, y, 0.15), S.WOOD_DARK, rng, n=5)
    for j in range(rows):
        box((cols * 2.6 + 0.4, 2.2, 0.35), (x, y, 1.0 + j * 2.3), S.WOOD, rng)
        for i in range(cols):
            egg((x - (cols - 1) * 1.3 + i * 2.6, y, 1.3 + j * 2.3), rng, i + j, s=0.7)


def plot(name, w, d):
    """The ground kept for a building that is not bought yet: stakes, a rope, its name on a board."""

    def make(rng):
        for sx in (-1, 1):
            for sy in (-1, 1):
                post(0.35, 2.4, (sx * w / 2, sy * d / 2, 0.15), S.WOOD_DARK, rng, n=5)
            box((0.14, d, 0.14), (sx * w / 2, 0, 1.9), HAY, rng)
            box((w, 0.14, 0.14), (0, sx * d / 2, 1.9), HAY, rng)
            post(0.3, 6.4, (sx * 4.2, -d / 2 - 3, 0.15), S.WOOD_DARK, rng, n=5)
        box((w - 3, d - 3, 0.12), (0, 0, 0.15), (176, 150, 110), rng, chance=0.3)
        sign(name, (0, -d / 2 - 3, 5.2), rng, size=1.0, board=S.WOOD)

    return make


# The buildings -------------------------------------------------------------------------------------------


def house(t):
    """The Ranch House (animals training at once): the farmhouse of scenes/ranch_house.py: a cottage, a
    farmhouse with a long porch, a great farmhouse with a cross wing. The ranch menu opens at its door."""

    def make(rng):
        RH.LOOKS[t](rng)

    return make


def barn(t):
    """The Barn (animals you can keep): a shed, a barn with a silo, a great barn with two."""

    def make(rng):
        w, d, h = BARN[t]
        dw, dh = BARN_DOOR[t]
        front = -d / 2
        box((w, d, h), (0, 0, 0.3), BARN_RED, rng)
        roof(w + 3, d + 3, h * 0.62, (0, 0, h + 0.3), SLATE, rng, ridge=w * 0.72)
        box((dw, 0.5, dh), (0, front - 0.1, 0.3), S.WOOD_DARK, rng)
        box((dw + 1.6, 0.6, 0.8), (0, front - 0.15, dh + 0.3), S.WHITE, rng, kind=S.PALE)
        box((w + 0.3, d + 0.3, 0.7), (0, 0, h * 0.52), S.WHITE, rng, kind=S.PALE)  # a white band round it
        for sx in (-1, 1):
            box((0.8, 0.6, dh), (sx * (dw / 2 + 0.4), front - 0.15, 0.3), S.WHITE, rng, kind=S.PALE)
            for sy in (-1, 1):
                box((0.8, 0.6, h), (sx * (w / 2 - 0.4), sy * (front - 0.15), 0.3), S.WHITE, rng, kind=S.PALE)
        if t >= 1:  # the loft door, at the back
            box((3.8, 0.5, 3.8), (0, -front + 0.1, h * 0.52 + 1.2), S.WOOD_DARK, rng)
            box((5.0, 0.6, 0.6), (0, -front + 0.15, h * 0.52 + 5.0), S.WHITE, rng, kind=S.PALE)
        lean = math.degrees(math.atan2(dh, dw))
        for way in (lean, -lean):  # braces across the doors
            box((math.hypot(dw, dh) * 0.94, 0.25, 0.5), (0, front - 0.4, 0.3 + dh / 2 - 0.25), S.WHITE, rng, tilt=(0, way), kind=S.PALE)
        for i in range(3 + 3 * t):  # hay beside it
            box((2.6, 1.4, 1.3), (-w / 2 - 2.4 - (i % 3) * 2.8, front + 2 + (i // 3) * 1.8, 0.15), HAY, rng, yaw=8)
        if t >= 1:
            post(4.6, h + 7, (w / 2 + 6, 2, 0.15), (205, 210, 215), rng, n=10)
            post(5.0, 4.2, (w / 2 + 6, 2, h + 7.15), BARN_RED, rng, n=10, r2=0.4)
        if t == 2:
            post(3.8, h + 2, (w / 2 + 5.4, -9, 0.15), (205, 210, 215), rng, n=10)
            post(4.2, 3.6, (w / 2 + 5.4, -9, h + 2.15), BARN_RED, rng, n=10, r2=0.4)
            top = h + 0.3 + h * 0.62
            post(0.15, 4, (0, 0, top), S.INK, rng, n=4)
            box((2.8, 0.14, 1.0), (0, 0, top + 3.2), S.GOLD, rng)
            box((6.4, 3.6, 1.2), (-w / 2 - 7, front - 6, 1.5), S.WOOD, rng, yaw=20)  # a hay cart
            box((5.8, 3.0, 1.5), (-w / 2 - 7, front - 6, 2.7), HAY, rng, yaw=20)
            for dx in (-2.4, 2.4):
                post(1.5, 0.5, (-w / 2 - 7 + dx, front - 6 + dx * 0.36, 0.15), S.WOOD_DARK, rng, n=8)
        size = (0.9, 1.2, 1.5)[t]
        sign("BARN", (0, front - 0.6, dh + 0.9 + size), rng, size=size)

    return make


def hatchery(t):
    """The Hatchery (eggs hatching at once): an open shed under a gabled canvas, a round pavilion, a great one under
    a two-tiered roof. The game stands the nests in it, as many as its level gives."""

    def make(rng):
        if t == 0:  # an open shed: a plank floor, four posts and beams, a gabled canvas with a scalloped edge
            box((17, 12, 0.3), (0, 0, 0.15), S.WOOD, rng)
            disc(6.4, (0, 0, 0.45), 0.25, HAY, rng, n=12)
            px, py, ph = 7.4, 4.8, 7.0
            for sx in (-1, 1):
                for sy in (-1, 1):
                    post(0.45, ph, (sx * px, sy * py, 0.45), S.WOOD_DARK, rng, n=6)
                    box((1.9, 0.3, 0.3), (sx * (px - 0.8), sy * py, ph - 0.95), S.WOOD_DARK, rng, tilt=(0, sx * 45))  # knee braces
                box((0.5, py * 2 + 0.9, 0.5), (sx * px, 0, ph), S.WOOD_DARK, rng)
                box((px * 2 + 1.4, 0.5, 0.5), (0, sx * py, ph), S.WOOD_DARK, rng)
            roof(px * 2 + 3, py * 2 + 3, 3.4, (0, 0, ph + 0.5), (236, 224, 196), rng, ridge=px * 2 + 1, kind=S.PALE)
            for sy in (-1, 1):  # the canvas's scalloped edge, red and cream
                for i in range(9):
                    x = -px - 0.4 + i * (px * 2 + 0.8) / 8
                    if sy < 0 and abs(x) < 4.6:
                        continue  # the name board hangs here
                    flag((x, sy * (py + 1.5), ph + 0.55), 1.9, 1.4, (BARN_RED, CREAM)[i % 2], rng)
            box((px * 2 + 1.6, 0.9, 0.5), (0, 0, ph + 3.7), BARN_RED, rng)  # the ridge
            sign("HATCHERY", (0, -py - 0.45, ph - 0.2), rng, size=0.9)
            lantern((-px - 1.6, -py - 1.0, 0.15), rng, h=5.5)
            for i, (x, y) in enumerate(((px + 2.2, py - 1.0), (px + 2.2, py - 3.4), (px + 2.2, py - 2.2))):
                box((1.6, 2.2, 1.2), (x, y, 0.15 + (1.2 if i == 2 else 0)), HAY, rng, yaw=4)
            if LIVE:
                for i in range(3):
                    nest((-3.5 + i * 3.5, 0.5, 0.5), rng, i)
            return
        r, n = HATCHERY[t]
        hh = 8.5 + t
        disc(r, (0, 0, 0.15), 0.6, (226, 214, 190), rng, n=16, kind=S.PALE)
        for i in range(n):  # no post stands in the middle of the front
            post(0.55, hh, Vector((0, 0, 0.75)) + polar(r - 1.5, i * 360 / n + (22.5 if n == 8 else 0)), S.WOOD_DARK, rng, n=6)
        post(r + 2.3, 5.5 + t, (0, 0, hh + 0.75), (240, 168, 72), rng, n=12, r2=(1.0, 6.0)[t - 1])
        top = hh + 0.75 + 5.5 + t
        if t == 2:
            post(5.6, 2.2, (0, 0, top), (226, 214, 190), rng, n=12, kind=S.PALE)
            post(7.6, 4.2, (0, 0, top + 2.2), (240, 168, 72), rng, n=12, r2=0.6)
            top += 6.4
            for a in (45, 135, 225, 315):
                lantern(Vector((0, 0, 0.15)) + polar(r + 3.5, a), rng, h=6.5)
        gem((0, 0, top - 0.3), (0, 0, top + 3.0), 1.6, LIT, rng=rng)
        sign("HATCHERY", (0, -(r + 0.4), hh - 0.7), rng, size=1.1)  # in front of the posts, under the roof's edge
        if LIVE:
            for i in range(6):
                nest(Vector((0, 0, 0.75)) + polar((7, 9.5)[t - 1], i * 60 + 30), rng, i)
            if t == 2:
                for i in range(4):
                    nest(Vector((0, 0, 0.75)) + polar(4.2, i * 90), rng, i + 2)

    return make


def cellar(t):
    """The Egg Cellar (eggs you can store): a thatched shelter over the egg rack, a cellar dug into a
    grassy mound, a bigger one with two doors. The game stands the rack and the eggs on it."""

    def make(rng):
        if t == 0:
            for sx in (-1, 1):
                post(0.4, 11.5, (sx * 6.4, 2.4, 0.15), S.WOOD_DARK, rng, n=6)
                post(0.4, 10.4, (sx * 6.4, -2.4, 0.15), S.WOOD_DARK, rng, n=6)
            box((14.4, 6.6, 0.4), (0, 0, 10.9), THATCH, rng, tilt=(-9, 0))
            if LIVE:
                rack(0, 0, 4, 3, rng)
            return
        (mw, md, mh), (fw, fh) = CELLAR[t]
        lump((0, 4, mh * 0.42), (mw, md, mh), (112, 172, 80), rng)  # the mound
        yf = 4 - md * 0.72
        box((fw, 1.6, fh), (0, yf, 0.15), S.STONE, rng, surface="rock", kind=S.COOL)
        for x in ((0,), (-4, 4))[t - 1]:
            box((4.2, 0.5, 5.4), (x, yf - 0.9, 0.15), S.WOOD_DARK, rng)
            box((5.2, 0.7, 0.7), (x, yf - 0.95, 5.55), S.STONE_DARK, rng)
            neon(S.k.cyl(0.4, 0.7, (x + 2.9, yf - 1.1, 4.4), n=6), LIT)
        for x, y in ((2.6, 6), (-3.4, 4.6))[:t]:  # air pipes
            post(0.6, 3.0, (x, y, mh * 1.2), S.STONE_DARK, rng, n=6)
        for a in range(5):
            bush(Vector((0, 4, mh * 0.9)) + polar(mw * 0.5, a * 72 + 20), rng, s=1.2)
        if t == 2:
            lantern((-fw / 2 - 1.6, yf - 4, 0.15), rng, h=6)
        sign("EGG CELLAR", (0, yf - 1.15, fh - 0.25), rng, size=(0.9, 1.2)[t - 1])
        if LIVE:
            rack(-(fw / 2 + 9), yf - 1, 6, 4, rng)  # on its left, away from the guard yard's path

    return make


def brooder(t):
    """The Brooder (hatching speed): warm straw beds under heat lamps and a glass roof; the biggest has a
    boiler."""

    def make(rng):
        w, d, h = BROODER[t]
        box((w, d, 0.6), (0, 0, 0.15), S.STONE, rng, kind=S.PALE)
        nx = (2, 3, 5)[t]
        for i in range(nx):
            for sy in (-1, 1):
                post(0.35, h, (-w / 2 + 0.6 + i * (w - 1.2) / (nx - 1), sy * (d / 2 - 0.6), 0.75), S.WHITE, rng, n=6, kind=S.PALE)
        roof(w + 1.5, d + 1.5, 3.0, (0, 0, h + 0.75), GLASS, rng, ridge=w * 0.75, kind=S.PALE)
        cols, rows = ((2, 1), (2, 2), (3, 2))[t]
        for i in range(cols):
            for j in range(rows):
                x, y = (i - (cols - 1) / 2) * 4.6, (j - (rows - 1) / 2) * 4.2
                box((3.4, 3.0, 0.9), (x, y, 0.75), HAY, rng)
                post(0.08, 1.3, (x, y, h - 0.55), S.INK, rng, n=4)
                neon(S.k.cyl(0.6, 0.9, (x, y, h - 1.0), n=6), HEAT)
                if LIVE:
                    egg((x, y, 1.4), rng, i + j, s=0.9)
        if t == 2:  # the boiler, on the side away from the path
            post(2.2, 7, (-w / 2 - 3.2, 1, 0.15), S.STONE_DARK, rng, n=8, surface="rock", kind=S.COOL)
            post(0.7, 5.5, (-w / 2 - 3.2, 1, 7.15), S.INK, rng, n=6)
            for k in range(3):
                lump((-w / 2 - 3.2 - k * 0.9, 1, 13.6 + k * 1.9), 1.2 + k * 0.35, S.WHITE, rng, kind=S.PALE)
        sign("BROODER", (0, -d / 2 - 0.6, h + 0.35), rng, size=(0.8, 1.0, 1.2)[t])

    return make


def mill_hub(t):
    """Where the windmill's sails turn, in its own numbers: (how far in front of its middle, how high, the
    sails' span, how many arms). The game stands the sails there and turns them."""
    if t == 0:
        return 5.4, 12.2, 18.0, 4
    r0, h, span = MILL[t]
    return r0 * 0.66 + 1.6, h - 1.5, span, (4, 8)[t - 1]


def windmill(t):
    """The Windmill (coins while you are away): a post mill, a stone tower mill, a tall one with a store."""

    def make(rng):
        if t == 0:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    post(0.5, 6, (sx * 3, sy * 3, 0.15), S.WOOD_DARK, rng, n=5)
            box((9, 9, 9), (0, 0, 6.15), S.WOOD, rng)
            roof(10.5, 10.5, 4, (0, 0, 15.15), ROOF_RED, rng, ridge=5)
            sign("WINDMILL", (0, -4.8, 8.0), rng, size=0.8)
        else:
            r0, h, _ = MILL[t]
            post(r0, h, (0, 0, 0.15), S.STONE, rng, n=10, r2=r0 * 0.64, surface="rock", kind=S.PALE)
            post(r0 * 0.78, 6.0, (0, 0, h + 0.15), S.WOOD_DARK, rng, n=10, r2=0.5)
            box((4, 0.6, 6.4), (0, -r0 + 0.5, 0.15), S.WOOD_DARK, rng)
            window((2.4, 0.5, 2.8), (0, -r0 * 0.84, h * 0.46))
            sign("WINDMILL", (0, -r0 * 0.93, 9.0), rng, size=1.0 + 0.15 * (t - 1))
        y, hub, span, arms = mill_hub(t)
        box((1.6, 2.2, 1.6), (0, -y + 0.9, hub - 0.8), S.INK, rng)
        if LIVE:
            for i in range(arms // 2):
                box((span, 0.45, 3.0 if arms == 4 else 2.4), (0, -y, hub - 1.5), S.WHITE, rng, tilt=(0, i * 360 / arms + 20), kind=S.PALE)
        if t == 2:  # a gallery, a store, sacks of what it earned
            r0, h, _ = MILL[t]
            disc(9.6, (0, 0, 11.0), 0.5, S.WOOD, rng, n=10)
            for i in range(10):
                post(0.25, 2.4, Vector((0, 0, 11.5)) + polar(9.1, i * 36), S.WOOD_DARK, rng, n=4)
            box((10, 8, 6), (-r0 - 8, 3, 0.15), S.WOOD, rng)
            roof(12, 10, 3.6, (-r0 - 8, 3, 6.15), ROOF_RED, rng, ridge=7)
            for i in range(6):
                lump((-r0 - 2.5 - (i % 3) * 2.2, -5 - (i // 3) * 2.0, 1.1), (1.1, 1.0, 1.1), S.GOLD if i % 2 else (232, 214, 170), rng)
            post(0.14, 5, (0, 0, h + 6.15), S.INK, rng, n=4)
            flag((1.5, 0, h + 10.9), 3.0, 2.6, (224, 64, 60), rng, point=False)

    return make


def cup(at, rng, s=1.0):
    turn([(0.9 * s, 0), (0.5 * s, 0.3 * s), (0.25 * s, 1.1 * s), (1.0 * s, 1.9 * s), (1.25 * s, 3.0 * s), (1.05 * s, 3.0 * s)], at, S.GOLD, rng, n=8)


def plinth(at, rng, s=1.0):
    box((2.6 * s, 2.6 * s, 2.2 * s), at, S.MARBLE, rng, kind=S.PALE)
    cup((at[0], at[1], at[2] + 2.2 * s), rng, s)


def brazier(at, rng):
    turn([(1.0, 0), (0.5, 0.5), (0.5, 3.0), (1.8, 4.0), (1.5, 4.0)], at, S.INK, rng, n=8)
    gem((at[0], at[1], at[2] + 3.9), (at[0], at[1], at[2] + 7.0), 1.6, FLAME, rng=rng)


def lodge(t):
    """The Trophy Lodge (more coins from waves): a first cup between two banners, a hall of cups, a great
    hall with the great cup in the middle."""

    def make(rng):
        if t == 0:
            plinth((0, 0, 0.15), rng)
            for sx in (-1, 1):
                post(0.3, 11, (sx * 4.5, 1.5, 0.15), S.WOOD_DARK, rng, n=6)
                flag((sx * 4.5, 1.2, 10.8), 2.6, 5.0, BANNERS[(sx + 1) // 2], rng)
            sign("TROPHY LODGE", (0, -2.4, 1.8), rng, size=0.7)
            return
        w, d, h = LODGE[t]
        box((w + 2, d + 2, 0.6), (0, 0, 0.15), S.MARBLE, rng, kind=S.PALE)
        box((w, 1.2, h), (0, d / 2 - 0.6, 0.75), CREAM, rng, kind=S.PALE)
        for sx in (-1, 1):
            box((1.2, d * 0.55, h), (sx * (w / 2 - 0.6), d * 0.225, 0.75), CREAM, rng, kind=S.PALE)
        nc = (4, 6)[t - 1]
        for i in range(nc):
            post(0.9, h, (-w / 2 + 1.2 + i * (w - 2.4) / (nc - 1), -d / 2 + 1.2, 0.75), S.MARBLE, rng, n=8, kind=S.PALE)
        for i in range(nc - 1):  # a banner between each pair of columns
            flag((-w / 2 + 1.2 + (i + 0.5) * (w - 2.4) / (nc - 1), -d / 2 + 1.2, h + 0.6), 2.6, 3.4, BANNERS[i % 5], rng)
        for i in range(3):  # and on its back wall
            flag(((i - 1) * w * 0.3, d / 2 + 0.1, h - 0.4), 3.0, 5.2, BANNERS[(i + 2) % 5], rng)
        box((w + 1, d + 1, 1.0), (0, 0, h + 0.75), S.MARBLE, rng, kind=S.PALE)
        roof(w + 3, d + 3, 5 + t, (0, 0, h + 1.75), (70, 84, 130), rng, ridge=w * 0.6)
        cups = (3, 5)[t - 1]
        for i in range(cups):
            if t == 2 and i == cups // 2:
                box((5.6, 5.6, 1.0), (0, 1, 0.75), S.MARBLE, rng, kind=S.PALE)
                plinth((0, 1, 1.75), rng, s=1.6)
            else:
                plinth(((i - (cups - 1) / 2) * (w - 7) / (cups - 1), 2.2, 0.75), rng)
        if t == 2:
            box((w + 1.3, 0.3, 0.4), (0, -d / 2 - 0.55, h + 0.8), S.GOLD, rng)
            for sx in (-1, 1):
                brazier((sx * (w / 2 + 3), -d / 2 - 2, 0.15), rng)
        size = (0.95, 1.25)[t - 1]
        sign("TROPHY LODGE", (0, -d / 2 - 0.5, h - 0.45), rng, size=size, board=S.INK)  # under the cornice, before the columns

    return make


def den(t):
    """The Titan's Den (the Titan's strength in waves): the front of a hall dug into the hill behind it (the
    hall itself is the hill's rock, cut by the game). A timber frame in the cave's mouth, a stone gate, a
    great stone gate with tusks. Inside: a stone floor, a bed of hay, a trough, lamps on the back wall. The
    game stands the owner's Titan in it."""

    def make(rng):
        half, tall, deep = DEN_HALF, DEN_TALL, DEN_DEEP
        rock = dict(surface="rock", kind=S.COOL)
        box((half * 2 - 1, deep - 1, 0.3), (0, deep / 2, 0.0), (150, 144, 136), rng, **rock)  # the floor
        disc(9 + t, (0, deep * 0.55, 0.3), 0.4, HAY, rng, n=12)
        box((8, 2.4, 1.8), (half - 6, deep * 0.3, 0.3), S.WOOD, rng)  # the trough
        box((7.2, 1.6, 0.3), (half - 6, deep * 0.3, 2.0), S.WATER, rng, chance=0.0)
        for x in (-half * 0.55, 0, half * 0.55):  # lamps on the back wall
            box((1.2, 1.0, 0.3), (x, deep - 1.1, 9.0), S.INK, rng)
            neon(S.k.cyl(0.7, 1.6, (x, deep - 1.5, 9.4), n=6), LIT)
        if t == 0:  # a timber frame in the mouth of the cave
            for sx in (-1, 1):
                post(1.3, tall - 4, (sx * (half - 1.5), 0.5, 0.15), S.WOOD_DARK, rng, n=7)
                box((2.0, 2.0, 1.2), (sx * (half - 1.5), 0.5, 0.0), S.STONE, rng, **rock)
            box((half * 2 + 2, 2.4, 2.2), (0, 0.5, tall - 4), S.WOOD_DARK, rng)
            box((half * 2 + 4, 6.0, 0.5), (0, -2.2, tall - 3.0), THATCH, rng, tilt=(-14, 0))
            sign("TITAN'S DEN", (0, -0.9, tall - 6.2), rng, size=1.3)
        else:  # a stone gate across the mouth, its sides and top running into the hill
            stone = S.STONE_DARK if t == 1 else (176, 170, 160)
            for sx in (-1, 1):
                box((9.0, 4.0, tall + 4), (sx * (half + 1.5), 0.6, 0.0), stone, rng, **rock)
                box((10.0, 5.0, 1.4), (sx * (half + 1.5), 0.4, 0.0), S.STONE, rng, kind=S.PALE)
            box((half * 2 + 21, 4.0, 6.0), (0, 0.6, tall - 2.0), stone, rng, **rock)
            box((half * 2 + 22, 4.6, 0.8), (0, 0.4, tall + 4.0), S.STONE, rng, kind=S.PALE)
            box((half * 2 - 3, 0.8, 2.6), (0, -1.5, tall - 4.6), S.WOOD_DARK, rng)
            sign("TITAN'S DEN", (0, -1.7, tall + 0.9), rng, size=(1.8, 2.1)[t - 1], board=S.INK)
            for sx in (-1, 1):
                lantern((sx * (half + 7.5), -2.6, 0.15), rng, h=9)
        if t == 2:
            box((half * 2 + 22.4, 0.5, 0.6), (0, -1.45, tall - 2.6), S.GOLD, rng)
            for sx in (-1, 1):  # tusks either side of the gate
                x = sx * (half - 0.5)
                pipe([(x, -1.5, 0.2), (x + sx * 2.2, -4.2, 7.0), (x - sx * 0.5, -5.8, 13.6), (x - sx * 5.2, -5.2, 18.6)], [1.8, 1.4, 0.95, 0.25], IVORY, rng, n=7, kind=S.PALE)
                flag((sx * (half + 1.5), -1.5, tall - 5.4), 4.4, 8.0, (224, 64, 60), rng)
                brazier((sx * (half + 8.5), -8, 0.15), rng)
        if LIVE:
            actor(("creature_elephant", "creature_elephant", "creature_elephant_war")[t], (0, deep * 0.55, 0.7), 0)

    return make


# name, maker, how far out, at what angle, its plot's size, the stages on the card of its empty plot and
# of its three looks. src/stations/Ranch.luau stands the buildings at the same places.
BUILDINGS = (
    ("RANCH HOUSE", house, 84, 86, None, (None, (0, 1), (2, 3), (4, 5))),
    ("BARN", barn, 84, 238, None, (None, (0, 1), (2, 3), (4, 5))),
    ("HATCHERY", hatchery, 70, 37.5, None, (None, (0, 1), (2, 3), (4, 5))),
    ("EGG CELLAR", cellar, 98, 52, None, (None, (0, 1), (2, 3), (4, 5))),
    ("BROODER", brooder, 98, 25.5, (18, 11), ((0, 0), (1, 2), (3, 4), (5, 5))),
    ("WINDMILL", windmill, 86, 349, (18, 16), ((0, 1), (2, 2), (3, 4), (5, 5))),
    ("TROPHY LODGE", lodge, 82, 182, (26, 15), ((0, 1), (2, 3), (4, 4), (5, 5))),
    ("TITAN'S DEN", den, 116, 134, (30, 24), ((0, 2), (3, 3), (4, 4), (5, 5))),  # its front on its hill's face
)


# The rest of the homestead, for the card -------------------------------------------------------------------


def spoke(deg, r0, r1, width, rng):
    mid = plan((r0 + r1) / 2, deg)
    box((r1 - r0, width, 0.3), (mid.x, mid.y, 0.02), PATH, rng, yaw=180 - deg, kind=S.PALE, chance=0.3)


def waypost(name, colour):
    """Where a path leaves for a training ground: its name on a board over the path, in its stat's colour."""

    def make(rng):
        for sx in (-1, 1):
            post(0.6, 11.5, (sx * 8.6, 0, 0.15), S.WOOD_DARK, rng, n=6)
        box((19, 0.8, 4.2), (0, 0, 8.2), colour, rng, chance=0.08)
        words(name, (0, -0.5, 10.3), 1.5, S.WHITE, glow=0.7)

    return make


def market(rng):
    """The two vendors, by the way in."""
    lv(0)
    H.stall(rng, (-6, 0, 0.15), 0, (226, 90, 80))
    H.stall(rng, (6, 0, 0.15), 0, (80, 150, 220))
    sign("EGGS", (-6, -2.9, 8.7), rng, size=1.0)
    sign("GEAR", (6, -2.9, 8.7), rng, size=1.0)
    lv(2)
    for i, x in enumerate((-12.6, -15.2, 12.8)):
        box((2.4, 2.4, 2.4), (x, 1 - i, 0.15), S.WOOD, rng, yaw=i * 14)
    lv(4)
    for sx in (-1, 1):
        lantern((sx * 11.5, -5, 0.15), rng, h=7)
    bunting((-11.5, -5, 7.2), (11.5, -5, 7.2), 1.5, rng, BANNERS, n=12, size=1.0)


def gate(rng):
    """The way in from the hub: two stone posts under a beam with the owner's name. No fence leads off it:
    a low wall each side stops after a few steps."""
    lv(0)
    for sx in (-1, 1):
        box((4, 4, 9), (sx * 11, 0, 0.15), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((4.8, 4.8, 0.8), (sx * 11, 0, 9.15), S.STONE, rng, kind=S.PALE)
        post(0.8, 5.6, (sx * 11, 0, 9.95), S.WOOD_DARK, rng, n=6)
        neon(S.k.cyl(0.75, 1.5, (sx * 11, -2.9, 6.4), n=6), LIT)
        box((14, 2.2, 3.0), (sx * 20, 0, 0.15), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((3, 3, 4.2), (sx * 28, 0, 0.15), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        flowers((sx * 20, -2.6, 0.15), rng, n=14, spread=3.6)
    box((26, 1.4, 1.2), (0, 0, 14.9), S.WOOD_DARK, rng)
    sign("YOUR RANCH", (0, -0.9, 12.9), rng, size=1.9, board=S.WOOD)


def well(rng):
    turn([(3.4, 0.0), (3.8, 2.0), (3.2, 2.4)], (0, 0, 0.15), S.STONE, rng, n=10, kind=S.PALE)
    for sx in (-2.7, 2.7):
        post(0.3, 5.6, (sx, 0, 2.4), S.WOOD_DARK, rng, n=5)
    roof(7.6, 5.2, 2.2, (0, 0, 8.0), ROOF_RED, rng, ridge=5.0)


def meadow(rng):
    """The herd's meadow, in the middle of everything: a pond, a shade tree, a low kerb with a gap at
    every way, and the animals themselves. It fills as the barn does."""
    lv(0)
    disc(R, (0, 0, 0), 0.15, LAWN, rng, n=48, chance=0.0)
    disc(MEADOW, (0, 0, 0.05), 0.17, (136, 194, 94), rng, n=40, chance=0.0)
    slab(RING[0], RING[1], 0, 360, 0.02, 0.3, PATH, rng, kind=S.PALE)
    ways = sorted([deg for _, deg, _ in WAYS] + [HUB])
    for i, a in enumerate(ways):
        b = ways[(i + 1) % len(ways)] + (360 if i == len(ways) - 1 else 0)
        slab(MEADOW + 0.4, MEADOW + 1.8, 180 - (b - 11), 180 - (a + 11), 0.15, 1.3, S.STONE_DARK, rng, kind=S.COOL)
    disc(9, (10, 6, 0.2), 0.12, S.WATER, rng, n=14, chance=0.0)  # the pond
    for i in range(9):
        p = Vector((10, 6, 0.15)) + plan(9.4, i * 40 + rng.uniform(-6, 6))
        rock(p, rng, s=rng.uniform(0.9, 1.7))
    for i in range(7):
        p = Vector((10, 6, 0.2)) + plan(rng.uniform(6, 8), 200 + i * 16)
        post(0.12, rng.uniform(2.0, 3.2), p, (88, 150, 70), rng, n=4)
    tree((-12, -7, 0.2), rng, s=3.0)
    box((7, 2.0, 1.5), (-6, 18, 0.2), S.WOOD, rng, yaw=-14)  # a feeding trough
    box((6.4, 1.4, 0.4), (-6, 18, 1.5), HAY, rng, yaw=-14)
    actor("creature_jackal", (4, -16, 0.2), -40)
    actor("creature_meerkat", (-17, 10, 0.2), 160)
    actor("creature_tortoise", (20, 17, 0.2), 240)
    lv(1)
    for _ in range(7):
        p = plan(rng.uniform(6, 30), rng.uniform(0, 360))
        if (p - Vector((10, 6, 0))).length > 12:
            flowers((p.x, p.y, 0.2), rng, n=8, spread=2.0)
    lv(2)
    actor("creature_lion", (-21, -20, 0.2), 60)
    actor("creature_flamingo", (22, 1, 0.2), 270)
    actor("creature_cheetah", (-1, 26, 0.2), 200)
    lv(4)
    actor("creature_rhino", (7, -27, 0.2), -20)
    actor("creature_lion_sun", (-27, 5, 0.2), 110)
    actor("creature_flamingo_phoenix", (17, -6, 0.2), 60)
    actor("creature_jackal_pharaoh", (-9, -27, 0.2), 250)
    actor("creature_cheetah_lightning", (2, 10, 0.2), 130)
    for sx in (-1, 1):  # a shelter from the rain
        for sy in (-1, 1):
            post(0.5, 6.5, (21 + sx * 5, -15 + sy * 3.6, 0.2), S.WOOD_DARK, rng, n=6)
    roof(13, 10, 3.0, (21, -15, 6.7), THATCH, rng, ridge=7)
    for i in range(4):
        disc(1.1, Vector((10, 6, 0.33)) + plan(rng.uniform(2, 6), i * 90 + 20), 0.08, (96, 170, 96), rng, n=7)


def grounds(rng):
    """What stands between the buildings: the paths, the gate, the vendors, lamps, benches, an orchard, a
    field, a garden, hives."""
    ways = [deg for _, deg, _ in WAYS] + [HUB]
    lv(0)
    for name, deg, colour in WAYS:
        spoke(deg, RING[1], 190, 10, rng)
        place(waypost(name, colour), R - 6, deg, rng)
    spoke(HUB, RING[1], 250, 16, rng)
    for _, _, r, deg, _, _ in BUILDINGS:
        spoke(deg, RING[1], r - 11, 6, rng)
    spoke(298, RING[1], 58, 6, rng)
    place(market, 62, 298, rng)
    lv(0)
    place(gate, R - 4, HUB, rng, flip=True)
    place(well, 58, 100, rng)
    pad = plan(99, 279.5)  # the teleport pad to the hub, just inside the gate
    disc(5.0, (pad.x, pad.y, 0.15), 0.4, S.STONE, rng, n=12, kind=S.PALE)
    neon(S.k.cyl(3.7, 0.14, (pad.x, pad.y, 0.62), n=12), (90, 220, 255), 2.2)
    for k in range(3):  # an avenue up the road from the hub
        for side in (-1, 1):
            p = plan(58 + k * 13, HUB) + plan(13 * side, HUB + 90)
            tree((p.x, p.y, 0.15), rng, s=1.5)
    for _, deg, _ in WAYS:  # two trees where each way leaves
        for side in (-1, 1):
            p = plan(R - 2, deg) + plan(13 * side, deg + 90)
            (pine if deg in (110, 158, 206) else tree)((p.x, p.y, 0.15), rng, s=1.8)
    for a in range(0, 360, 8):  # bushes and rocks along the rim, none across a way
        if all(abs((a - w + 180) % 360 - 180) > 9 for w in ways):
            p = plan(R + rng.uniform(-3, 2), a + rng.uniform(-2, 2))
            if rng.random() < 0.75:
                bush((p.x, p.y, 0.15), rng, s=rng.uniform(1.6, 2.4))
            else:
                rock((p.x, p.y, 0.15), rng, s=rng.uniform(1.6, 2.8))
    lv(1)
    for a in (0, 74, 122, 170, 222, 310):
        p = plan(RING[1] + 3, a)
        bench((p.x, p.y, 0.15), rng, yaw=90 - a)
    for i in range(8):  # an orchard between the windmill and the track's path
        p = plan(72 + (i // 2) * 10, 358.5 + (i % 2) * 6.5)
        tree((p.x, p.y, 0.15), rng, s=1.3, leaf=(96, 168, 70))
        lump((p.x + 1.4, p.y - 1.0, 7.2), 0.45, (226, 60, 50), rng)
    lv(2)
    for a in (37.5, 86, 134, 182, 238, 298, 349):
        p = plan(RING[1] + 2, a + 12)
        lantern((p.x, p.y, 0.15), rng, h=7)
    for i in range(4):  # a field behind the market
        a = 295.5 + i * 2.4
        q = plan(90, a)
        box((28, 2.0, 0.25), (q.x, q.y, 0.12), (150, 110, 76), rng, yaw=180 - a)
        for j in range(6):
            p = plan(78 + j * 4.8, a)
            lump((p.x, p.y, 0.9), (0.9, 0.9, 0.8), (110, 180, 80) if i % 2 else (232, 140, 50), rng)
    scare = plan(106, 299)
    post(0.25, 7, (scare.x, scare.y, 0.15), S.WOOD_DARK, rng, n=5)
    box((6, 0.4, 0.4), (scare.x, scare.y, 5.0), S.WOOD_DARK, rng, yaw=151)
    lump((scare.x, scare.y, 7.6), 0.9, HAY, rng)
    lv(3)
    bed = plan(82, 287.5)  # a garden between the road and the field
    disc(6.5, (bed.x, bed.y, 0.15), 0.5, (150, 110, 76), rng, n=12)
    for i in range(7):
        q = Vector((bed.x, bed.y, 0.65)) + plan(4.0 if i else 0, i * 60)
        flowers((q.x, q.y, q.z), rng, n=9, spread=1.7)
    turn([(1.0, 0), (0.5, 0.4), (0.45, 2.6), (1.1, 3.0)], (bed.x, bed.y, 0.65), S.MARBLE, rng, n=8, kind=S.PALE)
    fire = plan(92, 313.5)  # a fire to sit round, between the field and the pool's path
    disc(3.6, (fire.x, fire.y, 0.15), 0.3, S.STONE_DARK, rng, n=9, surface="rock", kind=S.COOL)
    gem((fire.x, fire.y, 0.5), (fire.x, fire.y, 3.8), 1.8, FLAME, rng=rng)
    for i in range(5):
        q = plan(7.4, i * 72 + 20)
        box((4.6, 1.3, 1.2), (fire.x + q.x, fire.y + q.y, 0.15), S.WOOD_DARK, rng, yaw=250 - i * 72)
    lv(4)
    for a in (37.5, 86, 134, 182, 238, 298, 349):
        p = plan(RING[1] + 2, a - 12)
        lantern((p.x, p.y, 0.15), rng, h=7)
    for i in range(3):  # hives
        p = plan(92 + i * 5, 165.5)
        box((2.6, 2.6, 0.5), (p.x, p.y, 0.15), S.WOOD_DARK, rng, yaw=15)
        box((2.2, 2.2, 2.6), (p.x, p.y, 0.65), (240, 210, 110), rng, yaw=15)
        roof(3.0, 3.0, 1.0, (p.x, p.y, 3.25), S.WOOD, rng, yaw=15)
    lv(5)
    for a in range(0, 360, 60):  # strings of flags round the ring for a finished ranch
        p, q = plan(RING[1] + 2, a + 12), plan(RING[1] + 2, a + 42)
        bunting((p.x, p.y, 7.0), (q.x, q.y, 7.0), 1.2, rng, BANNERS, n=9, size=1.0)


def beyond(rng):
    """What lies round the homestead, to frame it: woods that keep clear of the ways, far mountains."""
    lv(0)
    ways = [deg for _, deg, _ in WAYS] + [HUB]
    for _ in range(150):
        a, r = rng.uniform(0, 360), rng.uniform(R + 10, 340)
        if any(abs((a - w + 180) % 360 - 180) < 5 + 900 / r for w in ways):
            continue
        p = plan(r, a)
        (pine if rng.random() < 0.45 else tree)((p.x, p.y, 0), rng, s=rng.uniform(1.5, 2.6))
    for i in range(40):
        p = plan(rng.uniform(640, 800), i * 9 + rng.uniform(-3, 3))
        foot, tall = rng.uniform(90, 150), rng.uniform(110, 230)
        post(foot, tall, (p.x, p.y, -2), (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        q = p + plan(foot * 0.7, rng.uniform(0, 360))
        post(foot * 0.7, tall * 0.6, (q.x, q.y, -2), (112, 116, 140), rng, n=6, r2=foot * 0.1, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        if tall > 160:
            post(foot * 0.36, tall * 0.28, (p.x, p.y, tall * 0.74 - 2), S.WHITE, rng, n=7, r2=foot * 0.1, kind=S.PALE)


def build(rng):
    meadow(rng)
    grounds(rng)
    for name, maker, r, deg, lot, stages in BUILDINGS:
        if maker is den:
            lv(0)
            place(lambda rng: lump((0, DEN_DEEP / 2 + 4, 10), (DEN_HALF + 14, DEN_DEEP / 2 + 12, 30), (112, 168, 80), rng), r, deg, rng)
        if stages[0]:
            lv(*stages[0])
            place(plot(name, *lot), r + (14 if maker is den else 0), deg, rng)
        for t in range(3):
            lv(*stages[t + 1])
            place(maker(t), r, deg, rng)
    beyond(rng)
    _tag()


HERO = ((-128, -250, 164), (0, 6, 3))
SCENES = [
    dict(
        name="homestead",
        build=build,
        ground=(104, 164, 78),
        shots=[
            (*HERO, 36, S.TOP),  # the finished homestead from over the road to the hub
            ((0, -1, 570), (0, 0, 0), 50, S.TOP),  # the plan
            (*HERO, 36, 0),  # a new ranch
            (*HERO, 36, 3),  # half way
            ((0, -100, 11), (0, 45, 8), 24, S.TOP),  # in at the gate: the meadow, the house behind it
            ((-21, 39, 13), (-62, 56, 5), 24, S.TOP),  # the egg corner: hatchery, cellar
            ((20, 35, 12), (58, 60, 9), 24, S.TOP),  # the Titan's den
        ],
    ),
]
