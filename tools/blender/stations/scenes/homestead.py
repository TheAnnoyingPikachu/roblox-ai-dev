"""A ranch's homestead reworked (concept, decision 0071): the middle of the ranch as an open green, not a
fenced square. The herd's meadow is at its heart, a ring path runs round it, and the buildings stand
round the path with open ground between them, so every way out to a training ground is in sight. It is
300 studs across (the fenced plot is 150) and has eight buildings to upgrade where the plot has two.

`lv` says at which stages of building up what follows stands (0: a new ranch, 5: everything bought). A
building is written round its own middle with its front towards -Y, in three looks, and stood by `place`.
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

R = 150.0  # the homestead's radius
MEADOW = 50.0  # the herd's meadow in its middle
RING = (54.0, 64.0)  # the path round the meadow
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
LIT = (255, 226, 150)
EGGS = ((150, 210, 120), (240, 170, 90), (232, 200, 130), (250, 196, 60), (170, 150, 240))
BANNERS = ((150, 80, 200), (224, 64, 60), (250, 196, 60), (60, 150, 255), (70, 205, 120))

# The ways out to the training grounds: name, the angle it leaves at (0 is east, 90 is away from the hub:
# the angles of src/shared/ValleyMap.luau's grounds), its stat's colour. The road to the hub leaves south.
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


def place(maker, r, deg, rng, flip=False):
    """Builds `maker(rng)` and stands it `r` studs from the middle at angle `deg`, its front to the middle
    (or away from it)."""
    old = {ob.name for ob in bpy.data.objects}
    maker(rng)
    m = Matrix.Translation(polar(r, deg)) @ Matrix.Rotation(math.radians(deg - 90 + (180 if flip else 0)), 4, "Z")
    seen = set()
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name not in old and ob.data.name not in seen:
            seen.add(ob.data.name)
            ob.data.transform(m)


def sign(text, at, rng, size=1.4, board=S.WOOD_DARK):
    """A name board facing -Y, its middle at `at`."""
    box((len(text) * size * 0.72 + 1.6, 0.5, size * 1.9), (at[0], at[1], at[2] - size * 0.95), board, rng)
    words(text, (at[0], at[1] - 0.33, at[2]), size, S.WHITE, glow=0.5)


def egg(at, rng, i=0, s=1.0):
    lump((at[0], at[1], at[2] + 1.15 * s), (0.85 * s, 0.85 * s, 1.15 * s), EGGS[i % len(EGGS)], rng)


def nest(at, rng, i=0):
    post(2.2, 0.7, at, HAY, rng, n=8)
    egg((at[0], at[1], at[2] + 0.5), rng, i)


def plot(name, w, d):
    """The ground kept for a building that is not bought yet: stakes, a rope, its name on a board."""

    def make(rng):
        for sx in (-1, 1):
            for sy in (-1, 1):
                post(0.35, 2.4, (sx * w / 2, sy * d / 2, 0.15), S.WOOD_DARK, rng, n=5)
            box((0.14, d, 0.14), (sx * w / 2, 0, 1.9), HAY, rng)
            box((w, 0.14, 0.14), (0, sx * d / 2, 1.9), HAY, rng)
            post(0.3, 6.4, (sx * 4.2, -d / 2 - 3, 0.15), S.WOOD_DARK, rng, n=5)
        box((w - 4, d - 4, 0.12), (0, 0, 0.15), (176, 150, 110), rng, chance=0.3)
        sign(name, (0, -d / 2 - 3, 5.2), rng, size=1.0, board=S.WOOD)
        box((3.0, 0.5, 1.5), (0, -d / 2 - 3, 2.2), S.GOLD, rng)

    return make


# The buildings -------------------------------------------------------------------------------------------


def house(t):
    """The Ranch House (animals training at once): a cabin, a farmhouse with a porch, a house with wings
    and a tower. The ranch menu opens at its door."""

    def make(rng):
        w, d, h = ((24, 18, 9), (38, 24, 12), (50, 28, 14))[t]
        front = -d / 2
        box((w + 3, d + 3, 0.5), (0, 0, 0.1), S.STONE, rng, kind=S.PALE)
        box((w, d, h), (0, 0, 0.6), CREAM, rng, kind=S.PALE)
        roof(w + 4, d + 4, h * 0.7, (0, 0, h + 0.6), ROOF_RED, rng, ridge=w * 0.55)
        box((3.2, 3.2, h * 0.8), (w * 0.3, d * 0.12, h + 0.6), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((4.6, 0.5, 7.4), (0, front - 0.1, 0.6), S.WOOD_DARK, rng)
        box((5.8, 0.6, 0.6), (0, front - 0.15, 8.0), S.WOOD, rng)
        for i in range(t + 1):  # lit windows either side of the door
            for sx in (-1, 1):
                x = sx * (5.6 + i * 6.2)
                box((3.6, 0.4, 3.8), (x, front - 0.1, 3.4), LIT, rng, chance=0.0)
                box((4.4, 0.5, 0.5), (x, front - 0.15, 2.8), S.WOOD, rng)
                for side in (-1, 1):
                    box((0.9, 0.3, 3.8), (x + side * 2.3, front - 0.12, 3.4), (96, 150, 110), rng)
                if t == 2:
                    box((3.2, 0.4, 3.0), (x, front - 0.1, 10.2), LIT, rng, chance=0.0)
        pw = w * 0.62
        if t >= 1:  # a porch
            box((pw, 7, 0.6), (0, front - 3.5, 0.3), S.WOOD, rng)
            for i in range(4):
                post(0.4, 7.2, (-pw / 2 + 0.8 + i * (pw - 1.6) / 3, front - 6.4, 0.9), S.WOOD_DARK, rng, n=6)
            roof(pw + 2, 8.5, 2.2, (0, front - 3.6, 8.1), (150, 60, 52), rng, ridge=pw * 0.8)
        if t == 2:  # two wings and a tower
            for sx in (-1, 1):
                box((14, 18, 10), (sx * (w / 2 + 6), 3, 0.6), CREAM, rng, kind=S.PALE)
                roof(17, 21, 7, (sx * (w / 2 + 6), 3, 10.6), ROOF_RED, rng, yaw=90, ridge=10)
                box((3.4, 0.4, 3.6), (sx * (w / 2 + 6), -6.1, 3.6), LIT, rng, chance=0.0)
                lantern((sx * (pw / 2 + 3), front - 10, 0.15), rng, h=6.5)
                flowers((sx * (pw / 2 + 7), front - 3, 0.15), rng, n=12, spread=3.0)
            post(5.2, 26, (-w / 2 + 3, d / 2 - 2, 0.6), CREAM, rng, n=8, kind=S.PALE)
            post(6.6, 9, (-w / 2 + 3, d / 2 - 2, 26.6), ROOF_RED, rng, n=8, r2=0.3)
            post(0.14, 4, (-w / 2 + 3, d / 2 - 2, 35.4), S.INK, rng, n=4)
            flag((-w / 2 + 4.4, d / 2 - 2, 39.2), 2.8, 2.4, S.GOLD, rng, point=False)
        sign("RANCH HOUSE", (0, front - (7.4 if t else 0.6), (9.7, 9.9, 9.9)[t] if t else 9.0), rng, size=(1.0, 1.3, 1.5)[t])

    return make


def barn(t):
    """The Barn (animals you can keep): a shed, a barn with a silo, a great barn with two."""

    def make(rng):
        w, d, h = ((22, 16, 9), (34, 24, 13), (46, 30, 16))[t]
        front = -d / 2
        box((w, d, h), (0, 0, 0.3), BARN_RED, rng)
        roof(w + 3, d + 3, h * 0.62, (0, 0, h + 0.3), SLATE, rng, ridge=w * 0.72)
        dw, dh = ((8, 7), (12, 10), (15, 12))[t]
        box((dw, 0.5, dh), (0, front - 0.1, 0.3), S.WOOD_DARK, rng)
        box((dw + 1.6, 0.6, 0.8), (0, front - 0.15, dh + 0.3), S.WHITE, rng, kind=S.PALE)
        for sx in (-1, 1):
            box((0.8, 0.6, dh), (sx * (dw / 2 + 0.4), front - 0.15, 0.3), S.WHITE, rng, kind=S.PALE)
            box((0.8, 0.6, h), (sx * (w / 2 - 0.4), front - 0.15, 0.3), S.WHITE, rng, kind=S.PALE)
        box((w + 0.3, d + 0.3, 0.7), (0, 0, h * 0.52), S.WHITE, rng, kind=S.PALE)  # a white band, and the back's trim
        for sx in (-1, 1):
            box((0.8, 0.6, h), (sx * (w / 2 - 0.4), -front + 0.15, 0.3), S.WHITE, rng, kind=S.PALE)
        if t >= 1:  # the loft door, at the back
            box((4.2, 0.5, 4.2), (0, -front + 0.1, h * 0.52 + 1.4), S.WOOD_DARK, rng)
            box((5.4, 0.6, 0.6), (0, -front + 0.15, h * 0.52 + 5.6), S.WHITE, rng, kind=S.PALE)
        lean = math.degrees(math.atan2(dh, dw))
        for turn_ in (lean, -lean):
            box((math.hypot(dw, dh) * 0.94, 0.25, 0.5), (0, front - 0.4, 0.3 + dh / 2 - 0.25), S.WHITE, rng, tilt=(0, turn_), kind=S.PALE)
        for i in range(3 + 3 * t):  # hay beside it
            box((2.6, 1.4, 1.3), (-w / 2 - 3 - (i % 3) * 2.9, front + 2 + (i // 3) * 1.8, 0.15), HAY, rng, yaw=8)
        if t >= 1:
            post(5.4, h + 8, (w / 2 + 7, 2, 0.15), (205, 210, 215), rng, n=10)
            post(5.8, 4.6, (w / 2 + 7, 2, h + 8.15), BARN_RED, rng, n=10, r2=0.4)
        if t == 2:
            post(4.4, h + 2, (w / 2 + 6, -10, 0.15), (205, 210, 215), rng, n=10)
            post(4.8, 4.0, (w / 2 + 6, -10, h + 2.15), BARN_RED, rng, n=10, r2=0.4)
            top = h + 0.3 + h * 0.62
            post(0.15, 4, (0, 0, top), S.INK, rng, n=4)
            box((2.8, 0.14, 1.0), (0, 0, top + 3.2), S.GOLD, rng)
            box((7, 3.8, 1.2), (-w / 2 - 9, front - 7, 1.5), S.WOOD, rng, yaw=20)  # a hay cart
            box((6.4, 3.2, 1.6), (-w / 2 - 9, front - 7, 2.7), HAY, rng, yaw=20)
            for dx in (-2.6, 2.6):
                post(1.5, 0.5, (-w / 2 - 9 + dx, front - 7 + dx * 0.36, 0.15), S.WOOD_DARK, rng, n=8)
        size = (1.0, 1.4, 1.6)[t]
        sign("BARN", (0, front - 0.6, dh + 0.9 + size), rng, size=size)

    return make


def hatchery(t):
    """The Hatchery (eggs hatching at once): three nests under a canvas, a round pavilion of six, a great
    one of ten under a two-tiered roof."""

    def make(rng):
        if t == 0:
            disc(8, (0, 0, 0.15), 0.35, HAY, rng, n=10)
            for i in range(3):
                nest((-4.4 + i * 4.4, 0.5, 0.5), rng, i)
            for sx in (-1, 1):
                post(0.4, 7.5, (sx * 6.6, 3.8, 0.15), S.WOOD_DARK, rng, n=6)
                post(0.4, 5.8, (sx * 6.6, -3.8, 0.15), S.WOOD_DARK, rng, n=6)
            box((15, 9.4, 0.35), (0, 0, 6.5), (232, 222, 200), rng, tilt=(-11, 0), kind=S.PALE)
            sign("HATCHERY", (0, -4.6, 6.6), rng, size=0.9)
            return
        r, n = ((13, 8), (17, 10))[t - 1]
        hh = 8.5 + t
        disc(r, (0, 0, 0.15), 0.6, (226, 214, 190), rng, n=16, kind=S.PALE)
        for i in range(n):  # no post stands in the middle of the front
            post(0.55, hh, Vector((0, 0, 0.75)) + polar(r - 1.5, i * 360 / n + (22.5 if n == 8 else 0)), S.WOOD_DARK, rng, n=6)
        post(r + 2.5, 5.5 + t, (0, 0, hh + 0.75), (240, 168, 72), rng, n=12, r2=(1.0, 6.5)[t - 1])
        top = hh + 0.75 + 5.5 + t
        if t == 2:
            post(6.0, 2.4, (0, 0, top), (226, 214, 190), rng, n=12, kind=S.PALE)
            post(8.2, 4.4, (0, 0, top + 2.4), (240, 168, 72), rng, n=12, r2=0.6)
            top += 6.8
            for a in (45, 135, 225, 315):
                lantern(Vector((0, 0, 0.15)) + polar(r + 4, a), rng, h=6.5)
        gem((0, 0, top - 0.3), (0, 0, top + 3.2), 1.7, LIT, rng=rng)
        for i in range(6):
            nest(Vector((0, 0, 0.75)) + polar((7, 11)[t - 1], i * 60 + 30), rng, i)
        if t == 2:
            for i in range(4):
                nest(Vector((0, 0, 0.75)) + polar(4.6, i * 90), rng, i + 2)
        sign("HATCHERY", (0, -(r - 1.2), hh - 0.5), rng, size=1.2)

    return make


def cellar(t):
    """The Egg Cellar (eggs you can store): a rack under a thatch, a cellar dug into a grassy mound, a
    bigger one with two doors."""

    def rack(x, y, n, rng):
        for sx in (-1, 1):
            post(0.3, 6.4, (x + sx * (n * 1.1 + 0.2), y, 0.15), S.WOOD_DARK, rng, n=5)
        for j in range(2):
            box((n * 2.2 + 0.8, 2.0, 0.3), (x, y, 1.0 + j * 2.7), S.WOOD, rng)
            for i in range(n):
                egg((x - (n - 1) * 1.1 + i * 2.2, y, 1.3 + j * 2.7), rng, i + j, s=0.75)

    def make(rng):
        if t == 0:
            rack(0, 0, 4, rng)
            box((11.5, 4.4, 0.35), (0, 0, 6.6), THATCH, rng, tilt=(-9, 0))
            sign("EGG CELLAR", (0, -2.4, 8.0), rng, size=0.8)
            return
        mw, md, mh = ((12, 11, 7), (17, 14, 9))[t - 1]
        lump((0, 4, mh * 0.42), (mw, md, mh), (112, 172, 80), rng)  # the mound
        fw, fh = ((13, 8), (20, 10))[t - 1]
        yf = 4 - md * 0.72
        box((fw, 1.6, fh), (0, yf, 0.15), S.STONE, rng, surface="rock", kind=S.COOL)
        for x in ((0,), (-5, 5))[t - 1]:
            box((4.4, 0.5, 5.6), (x, yf - 0.9, 0.15), S.WOOD_DARK, rng)
            box((5.4, 0.7, 0.7), (x, yf - 0.95, 5.75), S.STONE_DARK, rng)
            neon(S.k.cyl(0.4, 0.7, (x + 3.1, yf - 1.1, 4.6), n=6), LIT)
        for x, y in ((3, 7), (-4, 5))[: t]:  # air pipes
            post(0.6, 3.2, (x, y, mh * 1.2), S.STONE_DARK, rng, n=6)
        for a in range(5):
            bush(Vector((0, 4, mh * 0.9)) + polar(mw * 0.5, a * 72 + 20), rng, s=1.3)
        rack(-fw / 2 - 6.5, yf - 1.5, 3 + (t - 1), rng)
        if t == 2:
            rack(fw / 2 + 6.5, yf - 1.5, 4, rng)
            for sx in (-1, 1):
                lantern((sx * (fw / 2 + 1.6), yf - 5, 0.15), rng, h=6)
        size = (1.0, 1.3)[t - 1]
        sign("EGG CELLAR", (0, yf - 1.15, fh - 0.2), rng, size=size)

    return make


def brooder(t):
    """The Brooder (hatching speed): warm beds under heat lamps and a glass roof; the biggest has a boiler."""

    def make(rng):
        w, d, h = ((12, 8, 6.5), (18, 11, 7.5), (26, 14, 8.5))[t]
        box((w, d, 0.6), (0, 0, 0.15), S.STONE, rng, kind=S.PALE)
        nx = (2, 3, 5)[t]
        for i in range(nx):
            for sy in (-1, 1):
                post(0.35, h, (-w / 2 + 0.6 + i * (w - 1.2) / (nx - 1), sy * (d / 2 - 0.6), 0.75), S.WHITE, rng, n=6, kind=S.PALE)
        roof(w + 1.5, d + 1.5, 3.2, (0, 0, h + 0.75), GLASS, rng, ridge=w * 0.75, kind=S.PALE)
        cols, rows = ((2, 1), (2, 2), (3, 2))[t]
        for i in range(cols):
            for j in range(rows):
                x, y = (i - (cols - 1) / 2) * 4.8, (j - (rows - 1) / 2) * 4.6
                box((3.6, 3.2, 0.9), (x, y, 0.75), HAY, rng)
                egg((x, y, 1.4), rng, i + j, s=0.9)
                post(0.08, 1.3, (x, y, h - 0.55), S.INK, rng, n=4)
                neon(S.k.cyl(0.6, 0.9, (x, y, h - 1.0), n=6), (255, 160, 70))
        if t == 2:  # the boiler
            post(2.4, 7, (w / 2 + 3.6, 1, 0.15), S.STONE_DARK, rng, n=8, surface="rock", kind=S.COOL)
            post(0.7, 5.5, (w / 2 + 3.6, 1, 7.15), S.INK, rng, n=6)
            for k in range(3):
                lump((w / 2 + 3.6 + k * 0.9, 1, 13.6 + k * 1.9), 1.2 + k * 0.35, S.WHITE, rng, kind=S.PALE)
        sign("BROODER", (0, -d / 2 - 0.6, h + 0.35), rng, size=(0.8, 1.0, 1.2)[t])

    return make


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
            hub, arm, y, blades = 12.2, 18.0, -5.4, 2
        else:
            r0, h = ((7.0, 24.0), (8.6, 32.0))[t - 1]
            post(r0, h, (0, 0, 0.15), S.STONE, rng, n=10, r2=r0 * 0.64, surface="rock", kind=S.PALE)
            post(r0 * 0.78, 6.0, (0, 0, h + 0.15), S.WOOD_DARK, rng, n=10, r2=0.5)
            box((4, 0.6, 6.4), (0, -r0 + 0.5, 0.15), S.WOOD_DARK, rng)
            box((2.4, 0.5, 2.8), (0, -r0 * 0.84, h * 0.46), LIT, rng, chance=0.0)
            sign("WINDMILL", (0, -r0 * 0.93, 9.0), rng, size=1.0 + 0.2 * (t - 1))
            hub, arm, y, blades = h - 1.5, (30.0, 40.0)[t - 1], -r0 * 0.66 - 1.6, (2, 4)[t - 1]
        box((1.6, 2.2, 1.6), (0, y + 0.9, hub - 0.8), S.INK, rng)
        for i in range(blades):
            box((arm, 0.45, 3.0 if blades == 2 else 2.4), (0, y, hub - 1.5), S.WHITE, rng, tilt=(0, i * 180 / blades + 20), kind=S.PALE)
        if t == 2:  # a gallery, a store, sacks of what it earned
            disc(11.0, (0, 0, 12.0), 0.5, S.WOOD, rng, n=10)
            for i in range(10):
                post(0.25, 2.4, Vector((0, 0, 12.5)) + polar(10.5, i * 36), S.WOOD_DARK, rng, n=4)
            box((12, 9, 7), (-r0 - 9, 3, 0.15), S.WOOD, rng)
            roof(14, 11, 4, (-r0 - 9, 3, 7.15), ROOF_RED, rng, ridge=8)
            for i in range(6):
                lump((-r0 - 2.5 - (i % 3) * 2.2, -6 - (i // 3) * 2.0, 1.1), (1.1, 1.0, 1.1), S.GOLD if i % 2 else (232, 214, 170), rng)
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
    gem((at[0], at[1], at[2] + 3.9), (at[0], at[1], at[2] + 7.0), 1.6, (255, 150, 60), rng=rng)


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
        w, d, h = ((24, 14, 9), (36, 18, 11))[t - 1]
        box((w + 2, d + 2, 0.6), (0, 0, 0.15), S.MARBLE, rng, kind=S.PALE)
        box((w, 1.2, h), (0, d / 2 - 0.6, 0.75), CREAM, rng, kind=S.PALE)
        for sx in (-1, 1):
            box((1.2, d * 0.55, h), (sx * (w / 2 - 0.6), d * 0.225, 0.75), CREAM, rng, kind=S.PALE)
        nc = (4, 6)[t - 1]
        for i in range(nc):
            post(0.9, h, (-w / 2 + 1.2 + i * (w - 2.4) / (nc - 1), -d / 2 + 1.2, 0.75), S.MARBLE, rng, n=8, kind=S.PALE)
        for i in range(nc - 1):  # a banner between each pair of columns
            flag((-w / 2 + 1.2 + (i + 0.5) * (w - 2.4) / (nc - 1), -d / 2 + 1.2, h + 0.6), 3.0, 3.6, BANNERS[i % 5], rng)
        box((w + 1, d + 1, 1.0), (0, 0, h + 0.75), S.MARBLE, rng, kind=S.PALE)
        roof(w + 3, d + 3, 5 + t, (0, 0, h + 1.75), (70, 84, 130), rng, ridge=w * 0.6)
        for i in range(3):  # banners on its back wall too
            flag(((i - 1) * w * 0.3, d / 2 + 0.1, h - 0.4), 3.2, 5.6, BANNERS[(i + 2) % 5], rng)
        cups = (3, 5)[t - 1]
        for i in range(cups):
            if t == 2 and i == cups // 2:
                box((6.4, 6.4, 1.0), (0, 1, 0.75), S.MARBLE, rng, kind=S.PALE)
                plinth((0, 1, 1.75), rng, s=1.8)
            else:
                plinth(((i - (cups - 1) / 2) * (w - 8) / (cups - 1), 2.5, 0.75), rng)
        if t == 2:
            box((w + 1.3, 0.3, 0.4), (0, -d / 2 - 0.55, h + 0.8), S.GOLD, rng)
            for sx in (-1, 1):
                brazier((sx * (w / 2 + 3.5), -d / 2 - 2, 0.15), rng)
        size = (1.0, 1.3)[t - 1]
        sign("TROPHY LODGE", (0, -d / 2 - 0.8, h + 1.25 + size * 0.45), rng, size=size, board=S.INK)

    return make


def den(t):
    """The Titan's Den (the Titan's strength in waves): a great thatched shelter, a stone stable with a gate
    the Titan walks through, a hall with tusks at its gate. The Titan stands in it."""

    def make(rng):
        w, d, h = ((34, 28, 19), (38, 28, 19), (46, 32, 23))[t]
        front = -d / 2
        disc(11 + t, (0, 1, 0.15), 0.4, HAY, rng, n=12)
        box((9, 2.6, 1.8), (w / 2 - 8, front + 6, 0.15), S.WOOD, rng)
        box((8.2, 1.8, 0.3), (w / 2 - 8, front + 6, 1.85), S.WATER, rng, chance=0.0)
        if t == 0:
            for sx in (-1, 1):
                for sy in (-1, 0, 1):
                    post(1.2, h, (sx * (w / 2 - 1.5), sy * (d / 2 - 1.5), 0.15), S.WOOD_DARK, rng, n=7)
            roof(w + 6, d + 6, 9, (0, 0, h + 0.15), THATCH, rng, ridge=w * 0.55)
            sign("TITAN'S DEN", (0, front - 2.5, 2.4), rng, size=1.0)
        else:
            wall = dict(surface="rock", kind=S.COOL)
            box((w, 2.4, h), (0, d / 2 - 1.2, 0.15), S.STONE_DARK, rng, **wall)
            for sx in (-1, 1):
                box((2.4, d, h), (sx * (w / 2 - 1.2), 0, 0.15), S.STONE_DARK, rng, **wall)
                box((w * 0.2, 2.4, h), (sx * w * 0.4, front + 1.2, 0.15), S.STONE_DARK, rng, **wall)
                lantern((sx * (w * 0.5 + 3), front - 3, 0.15), rng, h=9)
            box((w, 3.0, 3.0), (0, front + 1.5, h - 2.85), S.WOOD_DARK, rng)
            roof(w + 5, d + 5, 10 + 3 * (t - 1), (0, 0, h + 0.15), SLATE, rng, ridge=w * 0.5)
            sign("TITAN'S DEN", (0, front - 0.2, h - 1.35 + (0.7, 0.9)[t - 1]), rng, size=(1.5, 1.9)[t - 1], board=S.INK)
        if t == 2:
            box((w + 0.4, 0.5, 0.6), (0, front - 0.1, h - 3.5), S.GOLD, rng)
            for sx in (-1, 1):  # tusks either side of the gate
                x = sx * w * 0.34
                pipe([(x, front - 1.5, 0.2), (x + sx * 2.4, front - 4.5, 8), (x - sx * 0.5, front - 6.2, 16), (x - sx * 6.5, front - 5.6, 22)], [1.9, 1.5, 1.0, 0.25], IVORY, rng, n=7, kind=S.PALE)
                flag((sx * w * 0.2, front - 0.2, h - 3.6), 4.2, 7.0, (224, 64, 60), rng)
                brazier((sx * (w * 0.5 + 3), front - 10, 0.15), rng)
        actor(("creature_elephant", "creature_elephant", "creature_elephant_war")[t], (0, 1, 0.5), 0)

    return make


# name, maker, how far out, at what angle, its plot's size, the stages of its empty plot and its three looks
BUILDINGS = (
    ("RANCH HOUSE", house, 118, 86, None, (None, (0, 1), (2, 3), (4, 5))),
    ("BARN", barn, 114, 238, None, (None, (0, 1), (2, 3), (4, 5))),
    ("HATCHERY", hatchery, 96, 37, None, (None, (0, 1), (2, 3), (4, 5))),
    ("EGG CELLAR", cellar, 134, 50, None, (None, (0, 1), (2, 3), (4, 5))),
    ("BROODER", brooder, 134, 24, (22, 14), ((0, 0), (1, 2), (3, 4), (5, 5))),
    ("WINDMILL", windmill, 120, 349, (22, 20), ((0, 1), (2, 2), (3, 4), (5, 5))),
    ("TROPHY LODGE", lodge, 112, 182, (32, 20), ((0, 1), (2, 3), (4, 4), (5, 5))),
    ("TITAN'S DEN", den, 116, 134, (40, 30), ((0, 2), (3, 3), (4, 4), (5, 5))),
)


# The rest of the homestead ---------------------------------------------------------------------------------


def spoke(deg, r0, r1, width, rng):
    mid = polar((r0 + r1) / 2, deg)
    box((r1 - r0, width, 0.3), (mid.x, mid.y, 0.02), PATH, rng, yaw=deg, kind=S.PALE, chance=0.3)


def waypost(name, colour):
    """Where a path leaves for a training ground: its name on a board in its stat's colour."""

    def make(rng):
        for sx in (-1, 1):
            post(0.6, 15, (sx * (len(name) * 0.7 + 1.2), 0, 0.15), S.WOOD_DARK, rng, n=6)
        box((len(name) * 1.4 + 4.4, 0.8, 5.2), (0, 0, 9.6), colour, rng, chance=0.08)
        words(name, (0, -0.5, 12.2), 1.9, S.WHITE, glow=0.7)

    return make


def market(rng):
    """The two vendors, by the way in."""
    lv(0)
    H.stall(rng, (-7, 0, 0.15), 0, (226, 90, 80))
    H.stall(rng, (7, 0, 0.15), 0, (80, 150, 220))
    sign("EGGS", (-7, -2.9, 8.7), rng, size=1.0)
    sign("GEAR", (7, -2.9, 8.7), rng, size=1.0)
    lv(2)
    for i, x in enumerate((-14.5, -17.2, 14.6)):
        box((2.4, 2.4, 2.4), (x, 1 - i, 0.15), S.WOOD, rng, yaw=i * 14)
    post(1.2, 2.8, (17.6, 0, 0.15), S.WOOD_DARK, rng, n=8)
    lv(4)
    for sx in (-1, 1):
        lantern((sx * 13, -5, 0.15), rng, h=7)
    bunting((-13, -5, 7.2), (13, -5, 7.2), 1.6, rng, BANNERS, n=13, size=1.1)


def gate(rng):
    """The way in from the hub: two stone posts under a beam with the owner's name. No fence leads off it:
    a low wall each side stops after a few steps."""
    lv(0)
    for sx in (-1, 1):
        box((4, 4, 9), (sx * 11, 0, 0.15), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((4.8, 4.8, 0.8), (sx * 11, 0, 9.15), S.STONE, rng, kind=S.PALE)
        post(0.8, 5.6, (sx * 11, 0, 9.95), S.WOOD_DARK, rng, n=6)
        neon(S.k.cyl(0.75, 1.5, (sx * 11, -2.9, 6.4), n=6), LIT)
        box((16, 2.2, 3.0), (sx * 21, 0, 0.15), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((3, 3, 4.2), (sx * 30, 0, 0.15), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        flowers((sx * 21, -2.6, 0.15), rng, n=14, spread=4.0)
    box((26, 1.4, 1.2), (0, 0, 14.9), S.WOOD_DARK, rng)
    sign("YOUR RANCH", (0, -0.9, 12.9), rng, size=1.9, board=S.WOOD)


def well(rng):
    turn([(4.0, 0.0), (4.4, 2.2), (3.8, 2.6)], (0, 0, 0.15), S.STONE, rng, n=10, kind=S.PALE)
    for sx in (-3.2, 3.2):
        post(0.3, 6.0, (sx, 0, 2.6), S.WOOD_DARK, rng, n=5)
    roof(9.0, 6.0, 2.4, (0, 0, 8.6), ROOF_RED, rng, ridge=6.0)


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
        slab(MEADOW + 0.5, MEADOW + 2.0, a + 9, b - 9, 0.15, 1.3, S.STONE_DARK, rng, kind=S.COOL)
    disc(13, (-14, 8, 0.2), 0.12, S.WATER, rng, n=14, chance=0.0)  # the pond
    for i in range(11):
        p = Vector((-14, 8, 0.15)) + polar(13.4, i * 33 + rng.uniform(-6, 6))
        rock(p, rng, s=rng.uniform(1.0, 2.0))
    for i in range(9):
        p = Vector((-14, 8, 0.2)) + polar(rng.uniform(9, 12), 200 + i * 14)
        post(0.12, rng.uniform(2.0, 3.4), p, (88, 150, 70), rng, n=4)
    tree((17, -10, 0.2), rng, s=3.6)
    box((8, 2.2, 1.6), (8, 24, 0.2), S.WOOD, rng, yaw=14)  # a feeding trough
    box((7.4, 1.6, 0.4), (8, 24, 1.6), HAY, rng, yaw=14)
    actor("creature_jackal", (-6, -22, 0.2), 40)
    actor("creature_meerkat", (24, 14, 0.2), 200)
    actor("creature_tortoise", (-28, 24, 0.2), 120)
    lv(1)
    for _ in range(9):
        p = polar(rng.uniform(8, 44), rng.uniform(0, 360))
        if (p - Vector((-14, 8, 0))).length > 16:
            flowers((p.x, p.y, 0.2), rng, n=9, spread=2.4)
    lv(2)
    actor("creature_lion", (30, -28, 0.2), -60)
    actor("creature_flamingo", (-31, 2, 0.2), 90)
    actor("creature_cheetah", (2, 36, 0.2), 160)
    box((6, 2.0, 1.4), (-22, -30, 0.2), S.WOOD, rng, yaw=-30)
    box((5.4, 1.4, 0.3), (-22, -30, 1.5), S.WATER, rng, yaw=-30, chance=0.0)
    lv(4)
    actor("creature_rhino", (-10, -40, 0.2), 20)
    actor("creature_lion_sun", (38, 8, 0.2), 250)
    actor("creature_flamingo_phoenix", (-24, -8, 0.2), 300)
    actor("creature_jackal_pharaoh", (14, -36, 0.2), 110)
    actor("creature_meerkat_storm", (-36, 14, 0.2), 60)
    actor("creature_tortoise_island", (20, 30, 0.2), 310)
    actor("creature_cheetah_lightning", (-2, 14, 0.2), 230)
    for sx in (-1, 1):  # a shelter from the rain
        for sy in (-1, 1):
            post(0.5, 7, (-30 + sx * 7, -20 + sy * 5, 0.2), S.WOOD_DARK, rng, n=6)
    roof(18, 14, 3.4, (-30, -20, 7.2), THATCH, rng, ridge=10)
    for i in range(4):
        disc(1.3, Vector((-14, 8, 0.33)) + polar(rng.uniform(3, 9), i * 90 + 20), 0.08, (96, 170, 96), rng, n=7)


def grounds(rng):
    """What stands between the buildings, and comes with the stages: paths, lamps, benches, an orchard, a
    field, a garden, hives."""
    lv(0)
    for name, deg, colour in WAYS:
        spoke(deg, RING[1], 250, 12, rng)
        place(waypost(name, colour), R - 14, deg + 7.5, rng)
    spoke(HUB, RING[1], 330, 18, rng)
    for _, _, r, deg, _, _ in BUILDINGS:
        spoke(deg, RING[1], r - 9, 7, rng)
    spoke(298, RING[1], 92, 7, rng)
    place(market, 98, 298, rng)
    lv(0)
    place(gate, R - 2, HUB, rng, flip=True)
    place(well, 80, 100, rng)
    pad = polar(128, 279)  # the teleport pad to the hub, just inside the gate
    disc(5.4, (pad.x, pad.y, 0.15), 0.4, S.STONE, rng, n=12, kind=S.PALE)
    neon(S.k.cyl(4.0, 0.14, (pad.x, pad.y, 0.62), n=12), (90, 220, 255), 2.2)
    for k in range(5):  # an avenue up the road from the hub
        for side in (-1, 1):
            p = polar(78 + k * 14, HUB) + polar(15 * side, HUB + 90)
            tree((p.x, p.y, 0.15), rng, s=1.7)
    for _, deg, _ in WAYS:  # two trees where each way leaves
        for side in (-1, 1):
            p = polar(R - 4, deg) + polar(13 * side, deg + 90)
            (pine if deg in (110, 158, 206) else tree)((p.x, p.y, 0.15), rng, s=2.0)
    for a in range(0, 360, 6):  # bushes and rocks along the rim, none across a way
        if all(abs((a - w + 180) % 360 - 180) > 7 for w in [deg for _, deg, _ in WAYS] + [HUB]):
            p = polar(R + rng.uniform(-3, 2), a + rng.uniform(-2, 2))
            if rng.random() < 0.75:
                bush((p.x, p.y, 0.15), rng, s=rng.uniform(1.6, 2.6))
            else:
                rock((p.x, p.y, 0.15), rng, s=rng.uniform(1.6, 3.0))
    lv(1)
    for a in (0, 74, 122, 170, 222, 310):
        p = polar(RING[1] + 3.5, a)
        bench((p.x, p.y, 0.15), rng, yaw=a - 90)
    for i in range(8):  # an orchard between the windmill and the pool's path
        p = polar(104 + (i // 2) * 12, 333 + (i % 2) * 7)
        tree((p.x, p.y, 0.15), rng, s=1.5, leaf=(96, 168, 70))
        lump((p.x + 1.6, p.y - 1.2, 8.2), 0.5, (226, 60, 50), rng)
    lv(2)
    for a in (37, 86, 134, 182, 238, 298, 349):
        p = polar(RING[1] + 2.2, a + 11)
        lantern((p.x, p.y, 0.15), rng, h=7)
    for i in range(4):  # a field between the barn and the road
        for j in range(8):
            p = polar(100 + j * 5, 254.8 + i * 2.2)
            if j == 0:
                q = polar(117.5, 254.8 + i * 2.2)
                box((40, 2.2, 0.25), (q.x, q.y, 0.12), (150, 110, 76), rng, yaw=254.8 + i * 2.2)
            lump((p.x, p.y, 0.9), (0.9, 0.9, 0.8), (110, 180, 80) if i % 2 else (232, 140, 50), rng)
    scare = polar(144, 258)
    post(0.25, 7, (scare.x, scare.y, 0.15), S.WOOD_DARK, rng, n=5)
    box((6, 0.4, 0.4), (scare.x, scare.y, 5.0), S.WOOD_DARK, rng, yaw=347)
    lump((scare.x, scare.y, 7.6), 0.9, HAY, rng)
    lv(3)
    bed = polar(112, 282)  # a garden between the market and the road
    disc(9, (bed.x, bed.y, 0.15), 0.5, (150, 110, 76), rng, n=12)
    for i in range(7):
        q = Vector((bed.x, bed.y, 0.65)) + polar(5.4 if i else 0, i * 60)
        flowers((q.x, q.y, q.z), rng, n=10, spread=2.2)
    turn([(1.2, 0), (0.6, 0.4), (0.5, 3.0), (1.3, 3.4)], (bed.x, bed.y, 0.65), S.MARBLE, rng, n=8, kind=S.PALE)
    fire = polar(116, 312)  # a picnic green between the market and the pool's path
    disc(4.2, (fire.x, fire.y, 0.15), 0.3, S.STONE_DARK, rng, n=9, surface="rock", kind=S.COOL)
    gem((fire.x, fire.y, 0.5), (fire.x, fire.y, 4.2), 2.0, (255, 150, 60), rng=rng)
    for i in range(5):
        q = polar(8.5, i * 72 + 20)
        box((5.2, 1.4, 1.3), (fire.x + q.x, fire.y + q.y, 0.15), S.WOOD_DARK, rng, yaw=i * 72 + 110)
    for i in range(2):
        q = polar(17, 150 + i * 150)
        box((7, 3.4, 0.4), (fire.x + q.x, fire.y + q.y, 2.4), S.WOOD, rng, yaw=312)
        for side in (-1, 1):
            box((7, 1.0, 0.3), (fire.x + q.x + polar(2.9 * side, 42).x, fire.y + q.y + polar(2.9 * side, 42).y, 1.3), S.WOOD, rng, yaw=312)
            box((0.5, 5.4, 2.4), (fire.x + q.x + polar(2.6 * side, 312).x, fire.y + q.y + polar(2.6 * side, 312).y, 0.15), S.WOOD_DARK, rng, yaw=312)
    lv(4)
    for a in (37, 86, 134, 182, 238, 298, 349):
        p = polar(RING[1] + 2.2, a - 11)
        lantern((p.x, p.y, 0.15), rng, h=7)
    for i in range(3):  # hives
        p = polar(124 + i * 5, 166)
        box((2.6, 2.6, 0.5), (p.x, p.y, 0.15), S.WOOD_DARK, rng, yaw=166)
        box((2.2, 2.2, 2.6), (p.x, p.y, 0.65), (240, 210, 110), rng, yaw=166)
        roof(3.0, 3.0, 1.0, (p.x, p.y, 3.25), S.WOOD, rng, yaw=166)
    lv(5)
    for a in range(0, 360, 30):  # strings of flags round the ring for a finished ranch
        p, q = polar(RING[1] + 2.2, a + 11), polar(RING[1] + 2.2, a + 41)
        if a % 60 == 0:
            bunting((p.x, p.y, 7.0), (q.x, q.y, 7.0), 1.4, rng, BANNERS, n=11, size=1.0)


def beyond(rng):
    """What lies round the homestead, to frame it: woods that keep clear of the ways, far mountains."""
    lv(0)
    ways = [deg for _, deg, _ in WAYS] + [HUB]
    for _ in range(170):
        a, r = rng.uniform(0, 360), rng.uniform(R + 8, 440)
        if any(abs((a - w + 180) % 360 - 180) < 5 + 900 / r for w in ways):
            continue
        p = polar(r, a)
        (pine if rng.random() < 0.45 else tree)((p.x, p.y, 0), rng, s=rng.uniform(1.6, 2.8))
    for i in range(40):
        p = polar(rng.uniform(820, 1000), i * 9 + rng.uniform(-3, 3))
        foot, tall = rng.uniform(110, 190), rng.uniform(130, 280)
        post(foot, tall, (p.x, p.y, -2), (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        q = p + polar(foot * 0.7, rng.uniform(0, 360))
        post(foot * 0.7, tall * 0.6, (q.x, q.y, -2), (112, 116, 140), rng, n=6, r2=foot * 0.1, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        if tall > 190:
            post(foot * 0.36, tall * 0.28, (p.x, p.y, tall * 0.74 - 2), S.WHITE, rng, n=7, r2=foot * 0.1, kind=S.PALE)


def build(rng):
    meadow(rng)
    grounds(rng)
    for name, maker, r, deg, lot, stages in BUILDINGS:
        if stages[0]:
            lv(*stages[0])
            place(plot(name, *lot), r, deg, rng)
        for t in range(3):
            lv(*stages[t + 1])
            place(maker(t), r, deg, rng)
    beyond(rng)
    _tag()


HERO = ((170, -330, 215), (0, 8, 4))
SCENES = [
    dict(
        name="homestead",
        build=build,
        ground=(104, 164, 78),
        shots=[
            (*HERO, 36, S.TOP),  # the finished homestead from over the road to the hub
            ((0, -1, 760), (0, 0, 0), 50, S.TOP),  # the plan
            (*HERO, 36, 0),  # a new ranch
            (*HERO, 36, 3),  # half way
            ((0, -134, 13), (0, 60, 10), 24, S.TOP),  # in at the gate: the meadow, the house behind it
            ((50, 29, 13), (93, 73, 6), 26, S.TOP),  # the egg corner: hatchery, brooder, cellar
            ((-22, 18, 15), (-84, 86, 11), 24, S.TOP),  # the Titan's den, the lodge beside it
        ],
    ),
]
