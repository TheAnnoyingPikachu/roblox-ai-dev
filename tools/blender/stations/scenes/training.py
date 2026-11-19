"""A large area for each of the six training activities of a ranch (concepts, decisions 0059 and 0061):
the Speed Track, the Strength Gym, the Swim Pool, the Magic Library, the Healing Spring and the Guard
Yard. Each stands in a clearing of its own in the mountains round the ranch, reached by a pass, and
grows with the Training Grounds upgrade: six looks, level 0 (a new ranch) to level 5.

An area is written as a yard 64 by 48 units behind a gateway on its south side (-Y) and then grown K
times, so its kit is the size of the animals that use it (an elephant is 24 studs long): 160 by 120
studs, with room for the six animals that can train at once. `lv` says from which upgrade level what
follows stands; `cast` stands an animal in the area at its real size.
"""

import math

import bpy
import stage as S
from mathutils import Matrix, Vector
from stage import actor, bench, box, bunting, disc, fence, flag, flowers, gem, lantern, lump, moved, neon, pine, pipe, polar, post, prism, rock, roof, shard, slab, spin, tree, turn, words

SPEED, STRENGTH, STAMINA = (60, 150, 255), (235, 70, 70), (170, 90, 245)
MANA, HEALTH, DEFENCE = (60, 215, 225), (70, 205, 120), (255, 165, 50)
HAY = (228, 196, 110)
RED = (224, 64, 60)
IRON = (86, 88, 100)
W, D = 64, 48  # a yard, as it is written
K = 2.5  # and how many times it is grown
OPEN = False  # with no floor or fence of its own: it stands on land that is shaped for it (scenes/ranch_valley.py)
KIT = True  # with the kit that moves: the game leaves it out of an area's models and stands it itself, to move it

_now = {"first": 0, "last": S.TOP}
_cast = []


def _tag():
    for ob in bpy.data.objects:
        if ob.type == "MESH" and "first" not in ob:
            ob["first"], ob["last"] = _now["first"], _now["last"]


def lv(first, last=S.TOP):
    """What is built from here on stands from upgrade level `first` to level `last`."""
    _tag()
    _now.update(first=first, last=last)


def cast(name, at, yaw=0.0, first=0, last=S.TOP):
    """An animal in the area: standing at `at` (in the yard's units) from level `first` to `last`."""
    _cast.append((name, at, yaw, first, last))


def area(maker, rng, at=(0.0, 0.0), yaw=0.0, animals=True):
    """Builds one area: `maker(rng)` as it is written, grown K times, its animals at their real size (or
    none: the game stands its own), then all of it turned `yaw` degrees and moved to `at`. Returns its pieces."""
    old = {ob.name for ob in bpy.data.objects}
    for ob in bpy.data.objects:  # what stands already is not part of it: it stands at every level
        if ob.type == "MESH" and "first" not in ob:
            ob["first"], ob["last"] = 0, S.TOP
    _cast.clear()
    lv(0)
    maker(rng)
    _tag()
    new = [ob for ob in bpy.data.objects if ob.type == "MESH" and ob.name not in old]
    for ob in new:
        ob.data.transform(Matrix.Scale(K, 4))
    for name, pos, turned, first, last in _cast if animals else ():
        for ob in actor(name, Vector(pos) * K, turned):
            ob["first"], ob["last"] = first, last
            new.append(ob)
    place = Matrix.Translation((at[0], at[1], 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    for ob in new:
        ob.data.transform(place)
    _now.update(first=0, last=S.TOP)
    return new


def yard(rng, name, colour, ground, kind=S.PALE, bare=(146, 170, 96)):
    """What every area shares, and when it comes: a worn patch and a name board on a new ranch (level 0),
    the floor and a fence (1), the gateway with its sign (2), a pennant at each corner (3)."""
    hw, hd = W / 2, D / 2
    z = 0.25
    lv(0, 0)
    for i, (x, y, r) in enumerate(((-9.0, 1.0, 15.0), (8.0, 2.0, 14.0), (0.0, -5.0, 16.0))):
        disc(r, (x, y, 0), z - 0.01 * i, bare, rng, n=11, chance=0.3)
    # no name board here: the ranch's signs by the homestead name every area (SHANNON, 2026-11-19)
    lv(1)
    if not OPEN:
        box((W + 3, D + 3, 0.25), (0, 0, 0), ground, rng, kind=kind, chance=0.12)
        for a, b in (((-hw, -hd), (-8, -hd)), ((8, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))):
            fence((*a, z), (*b, z), rng, gap=4.0)
    lv(3)
    for sx in (-1, 1) if not OPEN else ():
        for sy in (-1, 1):
            post(0.28, 8.5, (sx * hw, sy * hd, z), S.WOOD_DARK, rng, n=6)
            flag((sx * hw + 1.0, sy * hd, 8.6), 2.0, 3.0, colour, rng)
            lump((sx * hw, sy * hd, 8.95), 0.36, S.GOLD, rng)
    lv(2)
    for sx in (-1, 1):  # the gateway
        box((1.5, 1.5, 0.8), (sx * 7.5, -hd, z), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((1.1, 1.1, 8.6), (sx * 7.5, -hd, z + 0.8), S.WOOD_DARK, rng)
        spin(lantern((sx * 9.6, -hd - 0.4, z), rng, h=5.0), (sx * 9.6, -hd - 0.4), 90 - 90 * sx)
        flag((sx * 7.5, -hd - 0.62, 7.6), 1.3, 3.6, colour, rng)
    box((17.5, 1.2, 1.0), (0, -hd, 9.4), S.WOOD_DARK, rng)  # the lintel; its name board is gone (the ranch's signs name it)
    roof(17.0, 2.4, 1.3, (0, -hd, 10.4), S.WOOD_DARK, rng, ridge=17.0)
    lv(0)


def clearing(rng, r=132.0, gap=(-118.0, 46.0), at=(0.0, 0.0), yaw=0.0):
    """The clearing an area stands in (in studs, round the origin): a ring of mountains `r` out, open over
    `gap` (its middle and half its width, in degrees: where the pass comes in, and where a card's camera
    looks from), woods at their feet and the path in from the south. Then turned and moved like `area`."""
    old = {ob.name for ob in bpy.data.objects}
    hw, hd = W * K / 2, D * K / 2
    for i in range(26):
        a = i * 360 / 26 + rng.uniform(-3, 3)
        if abs((a - gap[0] + 180) % 360 - 180) < gap[1]:
            continue
        foot, tall = rng.uniform(40, 58), rng.uniform(70, 125)
        post(foot, tall, polar(r + foot * 0.72, a), (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        if tall > 98:
            post(foot * 0.36, tall * 0.28, polar(r + foot * 0.72, a, tall * 0.74), S.WHITE, rng, n=7, r2=foot * 0.1, rot=(0, 0, rng.uniform(0, 50)), kind=S.PALE)
    box((16.0, r, 0.12), (0, -hd - r / 2, 0.02), (206, 190, 160), rng, kind=S.PALE)  # the path in from the pass
    for _ in range(90):
        a, d = rng.uniform(0, 360), rng.uniform(64, r + 4)
        p = polar(d, a)
        if abs(p.x) < hw + 7 and abs(p.y) < hd + 7 or abs(p.x) < 13 and p.y < 0 or abs((a - gap[0] + 180) % 360 - 180) < gap[1] - 12:
            continue  # in the yard, on the path, or in the way of the view
        roll = rng.random()
        if roll < 0.4:
            tree(p, rng, rng.uniform(1.6, 2.6))
        elif roll < 0.62:
            pine(p, rng, rng.uniform(1.8, 2.8))
        elif roll < 0.8:
            rock(p, rng, rng.uniform(1.4, 3.2))
        else:
            flowers(p, rng, n=9, spread=2.6)
    place = Matrix.Translation((at[0], at[1], 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name not in old:
            ob.data.transform(place)


def brazier(at, rng, flame=(255, 150, 50)):
    x, y, z = at
    post(0.16, 2.2, at, IRON, rng, n=5)
    turn([(0.25, 0.0), (0.75, 0.5), (0.85, 0.75)], (x, y, z + 2.2), IRON, rng, n=8)
    for dx, dy, h in ((0, 0, 1.3), (0.25, 0.1, 0.9), (-0.22, -0.12, 1.0)):
        neon(S.k.cyl(0.36, h, (x + dx, y + dy, z + 2.9 + h / 2), n=5, r2=0.0), flame, 2.2)


def cone(at, rng):
    post(0.5, 0.12, at, (240, 130, 40), rng, n=8)
    post(0.36, 1.1, (at[0], at[1], at[2] + 0.12), (240, 130, 40), rng, n=8, r2=0.06)
    post(0.27, 0.22, (at[0], at[1], at[2] + 0.45), S.WHITE, rng, n=8, r2=0.2)


def barrel(at, rng, rgb=S.WOOD):
    turn([(0.7, 0.0), (0.9, 0.7), (0.7, 1.5)], at, rgb, rng, n=10)
    for z in (0.3, 1.2):
        turn([(0.84, 0.0), (0.88, 0.1), (0.84, 0.2)], (at[0], at[1], at[2] + z), IRON, rng, n=10)


def palm(at, rng, s=1.0):
    x, y, z = at
    lean = rng.uniform(0, math.tau)
    pts = [(x + math.cos(lean) * 0.25 * i * i * 0.12 * s, y + math.sin(lean) * 0.25 * i * i * 0.12 * s, z + i * 1.25 * s) for i in range(7)]
    pipe(pts, [0.5 * s - 0.03 * i for i in range(7)], (150, 116, 78), rng, n=6)
    top = Vector(pts[-1])
    for i in range(8):
        a = i * 45 + rng.uniform(-10, 10)
        shard(top, top + polar(3.9 * s, a, -1.1 * s), 1.3 * s, 0.2, (70, 160, 80), rng, face=(0, 0, 1), at=0.35)
    for i in range(3):
        lump(top + polar(0.5, i * 120, -0.5), 0.34, (120, 80, 50), rng)


# Speed ----------------------------------------------------------------------------------------------------


def speed(rng):
    yard(rng, "SPEED TRACK", SPEED, (118, 176, 84))
    track, lane = (204, 112, 84), 2.4
    cx, half = 13.0, 13.0  # the middle of each bend, and half a straight
    lv(0, 0)  # a new ranch: an oval beaten into the dirt, a line of stones to start from
    for side in (-1, 1):
        slab(5.0, 5.0 + 4 * lane, -90 if side > 0 else 90, 90 if side > 0 else 270, 0.25, 0.1, S.DIRT, rng, centre=(side * cx, 0), step=10, chance=0.3)
        box((2 * half, 4 * lane, 0.1), (0, side * (5.0 + 2 * lane), 0.25), S.DIRT, rng, chance=0.3)
    for i in range(6):
        rock((-4.0, -(5.4 + i * 1.8), 0.3), rng, 0.4)
    lv(1)  # the track
    for side in (-1, 1):  # two bends and two straights: four lanes of clay with white lines
        for i in range(4):
            r0 = 5.0 + i * lane
            slab(r0, r0 + lane - 0.14, -90 if side > 0 else 90, 90 if side > 0 else 270, 0.25, 0.18, track, rng, centre=(side * cx, 0), step=10, chance=0.1)
            box((2 * half, lane - 0.14, 0.18), (0, side * (r0 + lane / 2 - 0.07), 0.25), track, rng, chance=0.1)
    box((0.5, 4 * lane, 0.04), (-4.0, -(5.0 + 2 * lane), 0.43), S.WHITE, rng)  # the start line
    for i in range(8):  # the finish line, chequered
        for j in range(2):
            box((0.5, 1.2, 0.04), (4.0 + j * 0.5, -(5.0 + 0.6 + i * 1.2), 0.43), S.INK if (i + j) % 2 else S.WHITE, rng)
    lv(2)
    for x in (-8.0, 0.0, 8.0):  # hurdles down the far straight
        for i in range(4):
            y = 5.0 + i * lane + lane / 2
            for sx in (-0.9, 0.9):
                post(0.09, 1.5, (x, y + sx, 0.43), S.WHITE, rng, n=5)
            box((0.14, 2.0, 0.3), (x, y, 1.75), SPEED if i % 2 else S.WHITE, rng)
    for side in (-1, 1):  # bales outside the bends
        for i in range(7):
            a = (-75 + i * 25) if side > 0 else (105 + i * 25)
            p = Vector((side * cx, 0, 0.25)) + polar(15.6, a)
            box((2.6, 1.3, 1.2), p, HAY, rng, yaw=a + 90)
    lv(5)
    for side in (-1, 1):  # glowing arrows round the bends
        for i in range(5):
            a = (-60 + i * 30) if side > 0 else (120 + i * 30)
            p = Vector((side * cx, 0, 0.46)) + polar(5.0 + 2 * lane, a)
            neon(prism([(-0.7, -0.9), (0.7, 0), (-0.7, 0.9), (-0.3, 0)], p, 0.05, SPEED, rng, yaw=a + 90), SPEED, 2.0)
    lv(1)
    # the infield: a slalom, a tyre run, a pond
    box((2 * half, 9.4, 0.12), (0, 0, 0.25), (104, 168, 76), rng, chance=0.12)
    for side in (-1, 1):
        slab(0, 4.7, -90 if side > 0 else 90, 90 if side > 0 else 270, 0.25, 0.12, (104, 168, 76), rng, centre=(side * cx, 0), step=15)
    lv(3)
    for i in range(9):
        post(0.14, 2.4, (-11.0 + i * 2.0, 2.2 if i % 2 else 3.6, 0.37), SPEED if i % 2 else S.WHITE, rng, n=6)
        flag((-11.0 + i * 2.0 + 0.5, 2.2 if i % 2 else 3.6, 2.7), 0.9, 0.7, (255, 210, 60), rng, point=False)
    for i in range(8):
        slab(0.42, 0.95, 0, 360, 0.37, 0.4, (48, 46, 54), rng, centre=(-10.5 + i * 1.6, -2.3 + (0.7 if i % 2 else -0.7)), step=45)
    disc(3.2, (12.0, 0.2, 0.3), 0.14, S.WATER, rng, n=14, surface="gem", kind=S.COOL, emit=0.2)
    for a in range(0, 360, 40):
        rock(Vector((12.0, 0.2, 0.3)) + polar(3.4, a), rng, 0.5)
    lv(4)
    # the stand, the timing tower, the kit
    for i in range(4):
        box((22.0, 2.2, 1.1 + i * 1.1), (-4.0, 17.0 + i * 2.2, 0.25), S.WOOD if i % 2 else (176, 124, 78), rng)
    for sx in (-14.5, -4.0, 6.5):
        box((0.5, 0.5, 9.5), (sx, 24.2, 0.25), S.WOOD_DARK, rng)
    for i in range(11):
        box((2.0, 9.6, 0.25), (-14.0 + i * 2.0, 20.4, 9.4), SPEED if i % 2 else S.WHITE, rng, tilt=(10, 0))
    lv(5)
    box((5.0, 5.0, 9.0), (21.5, 18.5, 0.25), S.WOOD, rng)  # the timing tower
    box((6.0, 6.0, 0.5), (21.5, 18.5, 9.25), S.WOOD_DARK, rng)
    roof(7.0, 7.0, 2.6, (21.5, 18.5, 13.0), SPEED, rng)
    for sx in (-2.6, 2.6):
        for sy in (-2.6, 2.6):
            box((0.4, 0.4, 3.3), (21.5 + sx, 18.5 + sy, 9.75), S.WOOD_DARK, rng)
    post(2.3, 0.5, (21.5, 15.7, 5.6), S.GOLD, rng, n=16, rot=(90, 0, 0))  # its stopwatch
    post(2.0, 0.56, (21.5, 15.72, 5.6), S.WHITE, rng, n=16, rot=(90, 0, 0), kind=S.PALE)
    box((0.22, 0.2, 1.7), (21.5, 15.05, 5.6), S.INK, rng)
    box((1.2, 0.2, 0.22), (22.0, 15.05, 5.5), RED, rng)
    lv(2)
    for i, p in enumerate(((-25.0, -18.0), (-22.5, -18.5), (-27.5, -15.5), (25.0, -19.0), (27.5, -16.0), (-28.0, 12.0), (28.0, 6.0))):
        cone((*p, 0.25), rng)
    lv(3)
    barrel((-27.0, 18.5, 0.25), rng, SPEED)
    barrel((-25.0, 19.4, 0.25), rng)
    lv(1)
    for sx in (-30.0, 30.0):
        tree((sx, 22.0, 0.25), rng, 0.8)
    lv(5)
    for i in (0, 1, 4, 5):  # flags along the front fence, clear of the gateway
        bunting((-30.0 + i * 10, -23.6, 6.0), (-20.0 + i * 10, -23.6, 6.0), 0.9, rng, (SPEED, S.WHITE, (255, 210, 60)), n=7, size=0.8)
    # the runners
    cast("creature_cheetah", (-8.0, -6.2, 0.43), 90)  # a lane each down the home straight
    cast("creature_cheetah_lightning", (-13.0, -8.6, 0.43), 90)
    cast("creature_lion", (-19.0, -11.0, 0.43), 90)
    cast("creature_rhino", (-10.0, -13.4, 0.43), 90)
    cast("creature_flamingo", (13.0, 6.2, 0.43), -90)  # and two on the far one
    cast("creature_jackal", (3.5, 8.6, 0.43), -90)


# Strength -------------------------------------------------------------------------------------------------


def weight(at, r, rng, band, axis=0.0):
    """A stone weight disc standing on its rim, its axle along `axis` degrees."""
    c = Vector(at) + Vector((0, 0, r))
    post(r, 0.7, c - polar(0.35, axis), (150, 146, 142), rng, n=12, rot=(0, 90, axis), surface="rock", kind=S.COOL)
    post(r * 0.62, 0.76, c - polar(0.38, axis), band, rng, n=12, rot=(0, 90, axis))
    post(r * 0.2, 0.84, c - polar(0.42, axis), IRON, rng, n=8, rot=(0, 90, axis))


def barbell(rng, x=-17.0, y=12.0, z=5.75):
    """The gym's barbell on its stands: a bar and four stone discs. It moves: the animal under it lifts it."""
    pipe([(x - 8.5, y, z), (x + 8.5, y, z)], 0.28, (190, 194, 204), rng, n=8)
    for sx, r in ((-7.6, 2.6), (-6.6, 2.1), (6.6, 2.1), (7.6, 2.6)):
        post(r, 0.8, (x + sx - 0.4, y, z), (150, 146, 142), rng, n=12, rot=(0, 90, 0), surface="rock", kind=S.COOL)
        post(r * 0.6, 0.86, (x + sx - 0.43, y, z), STRENGTH, rng, n=12, rot=(0, 90, 0))


def strength(rng):
    yard(rng, "STRENGTH GYM", STRENGTH, (214, 188, 140), bare=(204, 182, 134))
    lv(0, 1)  # a new ranch: a boulder to push and two stones to lift
    lump((6.0, 14.0, 1.1), (1.0, 1.0, 0.9), (168, 160, 150), rng, surface="rock", kind=S.COOL)
    lump((10.0, 15.0, 1.5), (1.4, 1.4, 1.3), (168, 160, 150), rng, surface="rock", kind=S.COOL)
    lv(2)  # the lifting deck and its barbell
    # the lifting deck under a timber frame, a great barbell on its stands
    box((22.0, 13.0, 0.6), (-17.0, 12.0, 0.25), S.WOOD, rng)
    for i in range(11):
        box((1.9, 12.6, 0.1), (-27.0 + i * 2.0, 12.0, 0.85), (166, 116, 72) if i % 2 else (176, 126, 80), rng)
    lv(4)  # the timber frame over it
    for sx in (-27.5, -6.5):
        for sy in (6.0, 18.0):
            box((1.0, 1.0, 10.0), (sx, sy, 0.25), S.WOOD_DARK, rng)
    for sy in (6.0, 18.0):
        box((23.0, 1.0, 1.0), (-17.0, sy, 10.25), S.WOOD_DARK, rng)
    for i in range(7):
        box((0.7, 14.0, 0.7), (-26.0 + i * 3.0, 12.0, 11.25), S.WOOD, rng)
    lv(2)
    for sx in (-21.0, -13.0):
        box((0.7, 0.7, 4.2), (sx, 12.0, 0.95), IRON, rng)
        box((1.5, 0.9, 0.4), (sx, 12.0, 5.15), IRON, rng)
    if KIT:
        barbell(rng)
    lv(3)
    box((2.6, 1.6, 1.2), (-9.0, 16.4, 0.95), S.STONE, rng, kind=S.PALE)  # the chalk trough
    lump((-9.0, 16.4, 2.25), (1.0, 0.55, 0.3), S.WHITE, rng)
    for i, r in enumerate((1.0, 1.3, 1.6, 1.9)):  # spare weights against the back posts
        weight((-27.0 + i * 0.5, 16.2 - i * 2.4, 0.95), r, rng, STRENGTH if i % 2 else S.GOLD, axis=20)
    lv(1)
    # the boulder run: two rails, a boulder, marks every few studs
    for sy in (-15.4, -10.6):
        box((40.0, 0.5, 0.5), (-7.0, sy, 0.25), S.WOOD_DARK, rng)
    box((40.0, 4.3, 0.1), (-7.0, -13.0, 0.25), (190, 160, 116), rng, chance=0.1)
    for i in range(8):
        box((0.3, 4.3, 0.06), (-25.0 + i * 5.0, -13.0, 0.36), S.WHITE if i < 7 else STRENGTH, rng)
    lv(0)
    lump((-8.0, -13.0, 2.95), (2.9, 2.9, 2.75), (140, 134, 128), rng, surface="rock", kind=S.COOL)
    lv(3)
    box((1.0, 5.6, 4.6), (13.6, -13.0, 0.25), S.WOOD_DARK, rng)  # the stop at its end, with a bell
    neon(S.k.ico(0.5, (13.0, -13.0, 5.3), subdiv=1), (255, 210, 60), 1.4)
    lv(2)
    # the stones: five on plinths, light to heavy
    for i, r in enumerate((0.9, 1.15, 1.4, 1.7, 2.05)):
        x = 3.0 + i * 5.2
        post(1.6 + i * 0.14, 1.1, (x, 16.0, 0.25), S.STONE_DARK, rng, n=8, surface="rock", kind=S.COOL)
        lump((x, 16.0, 1.35 + r * 0.92), (r, r, r * 0.95), (168, 160, 150), rng, surface="rock", kind=S.COOL)
        post(0.5, 0.1, (x, 14.3, 0.6), (STRENGTH, S.GOLD)[i % 2], rng, n=8, rot=(60, 0, 0))
    lv(1)
    # the log sled and its yoke
    box((7.0, 4.4, 0.5), (-14.0, -3.0, 0.45), S.WOOD_DARK, rng)
    for sy in (-4.9, -1.1):
        box((8.4, 0.4, 0.4), (-14.0, sy, 0.25), IRON, rng)
    for j, (n, z) in enumerate(((3, 0.95), (2, 2.1), (1, 3.25))):
        for i in range(n):
            y = -3.0 + (i - (n - 1) / 2) * 1.3
            post(0.62, 6.6, (-17.3, y, z + 0.62), (156, 108, 66), rng, n=8, rot=(0, 90, 0))
            post(0.5, 0.06, (-10.72, y, z + 0.62), (222, 190, 140), rng, n=8, rot=(0, 90, 0))
    pipe([(-10.5, -4.4, 0.9), (-6.0, -3.6, 1.6), (-3.0, -3.0, 2.4)], 0.12, IRON, rng, n=5)
    pipe([(-10.5, -1.6, 0.9), (-6.0, -2.4, 1.6), (-3.0, -3.0, 2.4)], 0.12, IRON, rng, n=5)
    box((0.5, 3.6, 0.5), (-3.0, -3.0, 2.15), S.WOOD, rng)
    lv(3)
    # tyres to flip, a striking post, a climbing rope with a bell
    for i in range(3):
        slab(1.5, 2.8, 0, 360, 0.25 + i * 1.0, 0.95, (52, 50, 58), rng, centre=(22.0 + 0.3 * i, 3.0 - 0.2 * i), step=30)
    slab(1.5, 2.8, 0, 360, 0.25, 0.95, (52, 50, 58), rng, centre=(15.5, 4.2), step=30)
    post(0.7, 6.0, (10.0, 4.5, 0.25), S.WOOD_DARK, rng, n=8)
    for z in (1.6, 2.6, 3.6, 4.6):
        turn([(0.78, 0.0), (0.92, 0.35), (0.78, 0.7)], (10.0, 4.5, z), HAY, rng, n=8)
    lv(5)
    box((0.9, 0.9, 13.0), (27.0, 17.5, 0.25), S.WOOD_DARK, rng)
    box((6.4, 0.7, 0.7), (24.2, 17.5, 12.8), S.WOOD_DARK, rng)
    pipe([(21.6, 17.5, 12.8), (21.6, 17.5, 1.2)], 0.2, HAY, rng, n=6)
    for z in range(3, 12, 2):
        lump((21.6, 17.5, z), 0.34, HAY, rng)
    neon(S.k.ico(0.55, (21.6, 17.5, 13.7), subdiv=1), (255, 210, 60), 1.4)
    lv(4)
    # a rack of kettlebells and an anvil
    box((9.0, 1.6, 0.4), (-2.0, 21.0, 2.2), S.WOOD, rng)
    for sx in (-6.0, 2.0):
        box((0.6, 1.6, 2.0), (sx, 21.0, 0.25), S.WOOD_DARK, rng)
    for i in range(5):
        r = 0.55 + i * 0.12
        lump((-5.4 + i * 1.75, 21.0, 2.6 + r * 0.9), r, IRON, rng, kind=S.COOL)
        slab(r * 0.45, r * 0.7, 0, 360, 2.6 + r * 1.7, 0.2, (STRENGTH, S.GOLD)[i % 2], rng, centre=(-5.4 + i * 1.75, 21.0), step=45)
    prism([(-1.6, -0.6), (1.9, -0.6), (1.0, 0.0), (1.9, 0.6), (-1.6, 0.6)], (27.0, -1.5, 1.45), 1.0, IRON, rng, kind=S.COOL)
    box((1.6, 1.0, 1.2), (27.0, -1.5, 0.25), S.WOOD_DARK, rng)
    lv(5)
    for p in ((-30.0, -21.5), (30.0, -21.5), (-30.0, 22.0), (30.0, 22.0), (-5.0, -20.5), (5.0, -20.5)):
        brazier((*p, 0.25), rng)
    for i in range(5):
        bunting((-29.0 + i * 12, 22.5, 6.5), (-17.0 + i * 12, 22.5, 6.5), 1.0, rng, (STRENGTH, S.WHITE, S.GOLD), n=8, size=0.9)
    # the lifters
    cast("creature_rhino", (-14.0, -13.0, 0.35), 90)  # shoulder to the boulder
    cast("creature_jackal", (6.0, 11.4, 0.25), 180)  # at the stones
    cast("creature_lion", (0.4, -3.0, 0.25), 90, first=1)  # in the yoke
    cast("creature_elephant", (-17.0, 12.0, 0.95), 0, first=2)  # under the bar
    cast("creature_cheetah", (10.0, 0.4, 0.25), 180, first=3)  # at the striking post
    cast("creature_meerkat", (19.0, 14.5, 0.25), 150, first=5)  # at the rope


# Stamina --------------------------------------------------------------------------------------------------


def parasol(at, r, h, rgb, rng):
    """A striped sunshade: eight gores, its rim at `at`."""
    top = Vector(at) + Vector((0, 0, h))
    for q in range(8):
        a, b = Vector(at) + polar(r, q * 45), Vector(at) + polar(r, q * 45 + 45)
        down = Vector((0, 0, -0.12))
        S.F.mesh("gore", [top, a, b, top + down, a + down, b + down], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], S.F.tone(rgb if q % 2 else S.WHITE), rng)


def stamina(rng):
    yard(rng, "SWIM POOL", STAMINA, (232, 222, 200))
    z0, deck = 0.25, 1.5  # the pool is cut into a raised deck
    x0, x1, y0, y1 = -24.0, 16.0, -8.0, 10.0
    tile_a, tile_b = (214, 204, 184), (190, 198, 206)
    lv(0, 0)  # a new ranch: a pond to swim in
    for i, (x, y, r) in enumerate(((-9.0, 1.0, 8.0), (-1.0, 2.5, 7.0), (5.5, 0.0, 6.0))):
        disc(r, (x, y, 0.2), 0.12 - 0.01 * i, S.WATER, rng, n=12, surface="gem", kind=S.COOL, emit=0.25, chance=0.06)
    for a in range(0, 360, 24):
        rock(Vector((-2.0, 1.0, 0.25)) + Vector((14.0 * math.cos(math.radians(a)), 8.6 * math.sin(math.radians(a)), 0)), rng, rng.uniform(0.5, 0.9))
    lv(1)  # the pool
    for ix in range(-14, 13):  # the deck: tiles everywhere but over the water
        for iy in range(-7, 8):
            cx, cy = ix * 2.2 + 1.1, iy * 2.2 + 1.1
            if x0 - 0.2 < cx < x1 + 0.2 and y0 - 0.2 < cy < y1 + 0.2 or abs(cy) > 15.6 or cx > 28 or cx < -30:
                continue
            box((2.1, 2.1, deck), (cx, cy, z0), tile_a if (ix + iy) % 2 else tile_b, rng, kind=S.PALE, chance=0.1)
    box((x1 - x0, y1 - y0, 1.15), ((x0 + x1) / 2, (y0 + y1) / 2, z0), S.WATER, rng, surface="gem", kind=S.COOL, emit=0.25, chance=0.05)
    for y in (y0 - 0.2, y1 + 0.2):  # a rim of violet tiles round the water
        box((x1 - x0 + 0.8, 0.4, deck + 0.08), ((x0 + x1) / 2, y, z0), STAMINA, rng, chance=0.08)
    for a in (x0 - 0.2, x1 + 0.2):
        box((0.4, y1 - y0 + 0.8, deck + 0.08), (a, (y0 + y1) / 2, z0), STAMINA, rng, chance=0.08)
    lv(2)
    for lane in range(1, 5):  # lane ropes of floats
        y = y0 + lane * (y1 - y0) / 5
        for i in range(34):
            x = x0 + 0.9 + i * 1.16
            lump((x, y, z0 + 1.2), (0.42, 0.3, 0.3), STAMINA if i % 2 else S.WHITE, rng)
    for lane in range(5):  # starting blocks, numbered by colour
        y = y0 + (lane + 0.5) * (y1 - y0) / 5
        box((1.6, 1.8, 0.9), (x0 - 1.4, y, z0 + deck), S.WHITE, rng, kind=S.PALE)
        box((1.7, 1.9, 0.16), (x0 - 1.5, y, z0 + deck + 0.9), (RED, (255, 190, 60), (90, 200, 120), SPEED, STAMINA)[lane], rng, tilt=(0, 8))
    lv(1)
    for x, y in ((x1 - 1.0, y0), (x1 - 1.0, y1), (x0 + 6.0, y1)):  # ladders
        for dx in (-0.45, 0.45):
            s = 1 if y > 0 else -1
            pipe([(x + dx, y - 0.6 * s, z0 + 0.3), (x + dx, y - 0.6 * s, z0 + deck + 1.3), (x + dx, y + 0.8 * s, z0 + deck + 1.3), (x + dx, y + 0.8 * s, z0 + deck)], 0.09, (220, 224, 232), rng, n=5)
    lv(4)
    # the diving tower: three boards
    tx, ty = 20.5, 1.0
    for sx in (-1.3, 1.3):
        for sy in (-1.3, 1.3):
            box((0.45, 0.45, 12.4), (tx + sx, ty + sy, z0 + deck), (220, 224, 232), rng)
    for i, (h, reach) in enumerate(((3.6, 4.6), (7.6, 5.4), (11.6, 6.2))):
        box((3.4, 3.4, 0.35), (tx, ty, z0 + deck + h), S.WHITE, rng, kind=S.PALE)
        box((reach, 1.5, 0.22), (tx - 1.7 - reach / 2, ty, z0 + deck + h + 0.35), STAMINA if i % 2 == 0 else SPEED, rng)
        for k in range(8):  # rungs up the back
            box((0.2, 1.4, 0.14), (tx + 1.85, ty, z0 + deck + h - 3.6 + k * 0.5), (220, 224, 232), rng)
    lv(5)
    # the slide: a tower and a tube that winds down into the water
    sx0, sy0 = 6.0, 17.5
    for dx in (-1.6, 1.6):
        for dy in (-1.6, 1.6):
            box((0.5, 0.5, 11.0), (sx0 + dx, sy0 + dy, z0 + deck), S.WOOD_DARK, rng)
    box((4.2, 4.2, 0.4), (sx0, sy0, z0 + deck + 9.0), S.WOOD, rng)
    roof(5.6, 5.6, 2.4, (sx0, sy0, z0 + deck + 12.6), STAMINA, rng)
    for k in range(18):
        box((0.3, 2.0, 0.16), (sx0 + 2.4 + k * 0.42, sy0, z0 + deck + 0.3 + k * 0.5), S.WOOD, rng)
    turns = 1.6
    pts = []
    for i in range(41):
        t = i / 40
        a = math.pi / 2 + turns * math.tau * t
        r = 4.6 + 1.2 * t
        pts.append((sx0 - 5.4 + r * math.cos(a), sy0 - 5.6 + r * math.sin(a) * 0.82, z0 + deck + 9.4 - 8.0 * t))
    pipe(pts, 1.25, STAMINA, rng, n=10, chance=0.3)
    for i in range(0, 41, 8):
        box((0.4, 0.4, pts[i][2] - z0 - deck), (pts[i][0], pts[i][1], z0 + deck), S.WOOD_DARK, rng)
    lv(3)
    # the lifeguard's chair, rings, loungers under parasols, palms
    cx_, cy_ = -4.0, -13.0
    for dx in (-1.0, 1.0):
        for dy in (-0.9, 0.9):
            pipe([(cx_ + dx * 1.3, cy_ + dy * 1.3, z0 + deck), (cx_ + dx, cy_ + dy, z0 + deck + 5.6)], 0.14, S.WHITE, rng, n=5)
    box((2.4, 2.2, 0.3), (cx_, cy_, z0 + deck + 5.6), S.WHITE, rng, kind=S.PALE)
    box((2.4, 0.3, 2.0), (cx_, cy_ - 1.1, z0 + deck + 5.9), RED, rng)
    post(2.6, 1.0, (cx_, cy_, z0 + deck + 9.0), RED, rng, n=8, r2=0.1)
    pipe([(cx_, cy_ - 1.0, z0 + deck + 5.9), (cx_, cy_ - 1.0, z0 + deck + 9.2)], 0.08, S.WHITE, rng, n=4)
    for x, y in ((-18.0, -11.0), (10.0, -11.0), (18.0, 12.5)):
        post(0.14, 2.6, (x, y, z0 + deck), S.WHITE, rng, n=5)
        for q in range(8):
            slab(0.55, 1.05, q * 45, q * 45 + 45, z0 + deck + 1.5, 0.3, RED if q % 2 else S.WHITE, rng, centre=(x, y - 0.3), step=45)
    lv(4)
    for i, (x, y) in enumerate(((-18.0, 15.5), (-11.0, 15.5), (-26.0, -13.0), (22.0, -13.0), (27.5, 15.0))):
        post(0.12, 5.2, (x, y, z0 + deck), S.WHITE, rng, n=5)
        parasol((x, y, z0 + deck + 4.9), 3.1, 1.1, (STAMINA, (255, 190, 60), SPEED, RED, HEALTH)[i], rng)
        box((1.5, 4.2, 0.3), (x + 2.6, y, z0 + deck + 0.5), S.WHITE, rng, kind=S.PALE)
        box((1.5, 1.6, 0.3), (x + 2.6, y + 2.2, z0 + deck + 0.9), S.WHITE, rng, kind=S.PALE, tilt=(-40, 0))
        box((1.3, 3.0, 0.1), (x + 2.6, y - 0.4, z0 + deck + 0.8), (STAMINA, (255, 190, 60), SPEED, RED, HEALTH)[i], rng)
    lv(2)
    for x, y in ((-30.0, 20.0), (30.0, 20.5), (-30.5, -20.0), (29.5, -20.0), (-22.0, 21.5), (16.0, 21.5)):
        palm((x, y, z0), rng, rng.uniform(0.9, 1.15))
    lv(3)
    for x, y, rgb in ((-9.0, 3.0, RED), (5.0, -4.5, (255, 210, 60)), (11.0, 6.5, HEALTH)):  # floats on the water
        slab(0.7, 1.4, 0, 360, z0 + 1.15, 0.45, rgb, rng, centre=(x, y), step=30)
    lump((-25.0, 14.0, z0 + deck + 0.9), 0.9, (255, 210, 60), rng)  # a beach ball
    lump((24.0, 9.0, z0 + deck + 0.8), 0.8, RED, rng)
    lv(1)
    for i in range(4):  # steps up from the gate
        box((12.0, 1.0, deck * (4 - i) / 4), (0, -15.9 - i * 1.0, z0), tile_a, rng, kind=S.PALE)
    # the swimmers
    cast("creature_tortoise", (-8.0, 1.0, 0.1), 90, last=0)  # in the pond
    cast("creature_flamingo", (3.0, 2.0, 0.1), -60, last=0)
    cast("creature_rhino", (-10.0, -6.2, z0 + 0.3), 90, first=1)  # a lane each
    cast("creature_lion", (3.0, -2.6, z0 + 0.3), 90, first=1)
    cast("creature_tortoise", (-12.0, 1.0, z0 + 0.35), 90, first=1)
    cast("creature_tortoise_gemshell", (7.0, 4.6, z0 + 0.3), -90, first=1)
    cast("creature_flamingo", (-17.0, 8.2, z0 + 0.5), 90, first=1)
    cast("creature_meerkat", (cx_, cy_, z0 + deck + 5.9), 180, first=3)  # the lifeguard
    cast("creature_jackal", (tx - 6.4, ty, z0 + deck + 11.95 + 0.22), -90, first=4)  # on the top board


# Mana -----------------------------------------------------------------------------------------------------


def shelf(rng, at, yaw, tall=9.0):
    """A bookcase facing local -Y, its shelves full of books."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def p(x, y, z):
        return (at[0] + x * c - y * s, at[1] + x * s + y * c, at[2] + z)

    box((6.4, 1.6, tall), p(0, 0.2, 0), S.WOOD_DARK, rng, yaw)
    box((7.0, 2.0, 0.5), p(0, 0.2, tall), S.WOOD, rng, yaw)
    spines = ((170, 60, 70), (60, 110, 180), (70, 150, 100), (220, 180, 80), (130, 80, 170), (220, 220, 210), (200, 110, 60))
    for row in range(int((tall - 0.8) // 1.9)):
        zz = 0.5 + row * 1.9
        box((6.0, 1.4, 0.16), p(0, -0.1, zz), S.WOOD, rng, yaw)
        x = -2.85
        while x < 2.7:
            w, h = rng.uniform(0.22, 0.5), rng.uniform(1.0, 1.55)
            lean = rng.uniform(-9, 9) if rng.random() < 0.15 else 0
            box((w, 1.0, h), p(x + w / 2, -0.55, zz + 0.16), spines[rng.randrange(len(spines))], rng, yaw, tilt=(0, lean))
            x += w + 0.04


def crystal(rng):
    """The library's great crystal over the open book: five shards in a gold band. It moves: it turns."""
    for i, (h, w, off) in enumerate(((7.0, 2.2, (0, 0)), (4.0, 1.3, (1.6, 0.6)), (3.4, 1.1, (-1.5, -0.5)), (2.8, 0.9, (0.3, -1.6)), (2.6, 0.9, (-0.6, 1.5)))):
        base = Vector((off[0], 2 + off[1], 8.0 + i * 0.25))
        gem(base, base + Vector((off[0] * 0.25, off[1] * 0.25, h)), w, (MANA, (150, 120, 255))[i % 2], rng=rng)
        gem(base, base - Vector((off[0] * 0.1, off[1] * 0.1, h * 0.45)), w, (MANA, (150, 120, 255))[i % 2], rng=rng)
    slab(1.25, 1.5, 0, 360, 8.3, 0.34, S.GOLD, rng, centre=(0, 2), step=45)  # the band that holds them


def mana(rng):
    yard(rng, "MAGIC LIBRARY", MANA, (72, 74, 104), kind=S.COOL)
    slate, pale = (82, 84, 118), (112, 116, 156)
    lv(0, 0)  # a new ranch: a rug, a book on a stand, one low case of scrolls, a candle
    box((9.0, 6.0, 0.08), (0, 1.5, 0.25), (150, 60, 90), rng, chance=0.08)
    box((8.0, 5.0, 0.09), (0, 1.5, 0.25), S.GOLD, rng, chance=0.08)
    box((7.6, 4.6, 0.1), (0, 1.5, 0.25), (150, 60, 90), rng, chance=0.08)
    post(0.3, 2.6, (0, 2.0, 0.35), S.WOOD_DARK, rng, n=6)
    box((2.4, 1.7, 0.2), (0, 2.0, 2.95), S.WHITE, rng, kind=S.PALE, tilt=(-18, 0))
    shelf(rng, (-7.5, 6.0, 0.25), 20, tall=4.6)
    post(0.1, 0.9, (3.2, 1.0, 0.35), S.WHITE, rng, n=5)
    neon(S.k.ico(0.2, (3.2, 1.0, 1.45), subdiv=1), (255, 200, 90), 3.0)
    lv(1)  # the floor
    for band, (r0, r1, n) in enumerate(((0.0, 4.6, 8), (4.8, 10.4, 16), (10.6, 16.6, 24))):  # the floor: rings of slate
        for i in range(n):
            slab(r0, r1, i * 360 / n + 0.3, (i + 1) * 360 / n - 0.3, 0.25, 0.3, slate if (i + band) % 2 else pale, rng, centre=(0, 2), step=7.5, kind=S.COOL, chance=0.3)
    lv(5)
    for i in range(24):  # the rune ring, and a star of gold inlay
        a = i * 15
        neon(prism([(-0.2, -0.75), (0.2, -0.75), (0.2, 0.75), (-0.2, 0.75)], Vector((0, 2, 0.56)) + polar(10.5, a), 0.05, MANA, rng, yaw=a), MANA, 2.2)
    lv(3)
    for i in range(8):
        prism([(4.9, -0.5), (10.0, 0), (4.9, 0.5)], (0, 2, 0.55), 0.04, S.GOLD, rng, yaw=i * 45, chance=0.1)
    lv(1)
    # the heart: a great crystal turning over an open book
    turn([(3.0, 0.0), (3.3, 0.5), (2.2, 0.9), (1.6, 2.6), (2.4, 3.2)], (0, 2, 0.55), (150, 152, 190), rng, n=10, kind=S.COOL)
    for side in (-1, 1):
        box((2.6, 3.4, 0.4), (side * 1.32, 2.0, 3.9), S.WHITE, rng, kind=S.PALE, tilt=(0, side * 12))
        box((2.8, 3.6, 0.2), (side * 1.36, 2.0, 3.72), (130, 60, 90), rng, tilt=(0, side * 12))
    lv(3)
    if KIT:
        crystal(rng)
    lv(5)
    for i in range(3):  # rings of light round it
        neon(S.k.ring(3.4 + i * 0.9, 9.0 + i * 1.5, 0.09, None, n=28, sides=5, centre=(0, 2)), (150, 120, 255), 2.0)
    lv(4)
    for i in range(9):  # books adrift round the crystal
        a, r, zz = i * 40 + 12, 6.2 + (i % 3) * 1.1, 5.0 + (i * 1.7) % 5.5
        p = Vector((0, 2, zz)) + polar(r, a)
        box((1.5, 1.1, 0.34), p, ((170, 60, 70), (60, 110, 180), (220, 180, 80))[i % 3], rng, yaw=a * 2.3, tilt=(18, -14))
        neon(S.k.ico(0.16, (p.x, p.y, p.z - 0.3), subdiv=1), MANA, 2.5)
    lv(2)
    # the shelves: a half ring of bookcases between columns under an arcade
    for i in range(7):
        if i == 3:  # the middle bay is the window's
            continue
        a = 30 + i * 20
        c = Vector((0, 2, 0.55)) + polar(21.0, a)
        shelf(rng, c, a - 90, tall=9.5 if i % 2 else 11.0)
    lv(4)
    for i in range(8):
        a = 20 + i * 20
        c = Vector((0, 2, 0.55)) + polar(20.2, a)
        post(1.0, 0.6, c, (150, 152, 190), rng, n=8, kind=S.COOL)
        post(0.7, 12.4, c + Vector((0, 0, 0.6)), (196, 198, 226), rng, n=8, kind=S.COOL)
        post(1.05, 0.6, c + Vector((0, 0, 13.0)), S.GOLD, rng, n=8)
        neon(S.k.ico(0.5, tuple(c + Vector((0, 0, 14.4))), subdiv=1), MANA, 2.4)
    for i in range(7):
        slab(19.3, 21.1, 21 + i * 20, 39 + i * 20, 14.15, 1.0, (150, 152, 190), rng, centre=(0, 2), step=6, kind=S.COOL)
    # the great window behind: a pointed arch of coloured light
    wx, wy = 0.0, 22.8
    for i, (x, h) in enumerate(((-2.1, 9.0), (0.0, 11.5), (2.1, 9.0))):
        for j in range(4):  # panes of coloured light
            neon(S.k.box((1.8, 0.3, h / 4 - 0.12), (wx + x, wy, 2.55 + (j + 0.5) * h / 4)), ((255, 120, 170), (120, 150, 255), MANA, (190, 130, 255), (255, 210, 110))[(i + j) % 5], 1.5)
        box((0.3, 0.6, h + 0.6), (wx + x + 1.05, wy, 2.3), (60, 60, 90), rng, kind=S.COOL)
    box((0.3, 0.6, 9.6), (wx - 3.15, wy, 2.3), (60, 60, 90), rng, kind=S.COOL)
    box((7.4, 1.2, 2.0), (wx, wy, 0.55), (150, 152, 190), rng, kind=S.COOL)
    lv(3)
    # an orrery, a telescope on a turret, an hourglass, desks and candles
    ox, oy = -21.0, -10.0
    turn([(1.8, 0.0), (1.2, 0.5), (0.4, 1.0), (0.3, 3.4)], (ox, oy, 0.25), S.GOLD, rng, n=10)
    neon(S.k.ico(0.9, (ox, oy, 4.6), subdiv=1), (255, 200, 90), 2.2)
    for i, (r, rgb, tilt) in enumerate(((2.2, (120, 170, 255), 12), (3.3, (255, 130, 110), -18), (4.5, (150, 230, 160), 26))):
        hoop = moved(S.k.ring(r, 0.0, 0.07, None, n=28, sides=5), Matrix.Translation((ox, oy, 4.6)) @ Matrix.Rotation(math.radians(tilt), 4, "X"))
        S.paint(hoop, S.GOLD, rng)
        q = Vector((ox, oy, 4.6)) + Vector((r * math.cos(i * 2.1), r * math.sin(i * 2.1) * math.cos(math.radians(tilt)), r * math.sin(i * 2.1) * math.sin(math.radians(tilt))))
        lump(q, 0.34 + 0.1 * i, rgb, rng)
    lv(5)
    tx, ty = 23.0, 14.0
    post(4.0, 9.0, (tx, ty, 0.25), (150, 152, 190), rng, n=10, surface="rock", kind=S.COOL)
    post(4.5, 0.6, (tx, ty, 9.25), (196, 198, 226), rng, n=10, kind=S.COOL)
    turn([(4.2, 0.0), (3.7, 1.9), (2.2, 3.3), (0.0, 3.9)], (tx, ty, 9.85), (64, 80, 150), rng, n=10, kind=S.COOL)
    pipe([(tx - 1.0, ty - 1.0, 11.3), (tx - 5.4, ty - 5.2, 14.8)], [0.75, 0.5], S.GOLD, rng, n=8)
    neon(S.k.ico(0.42, (tx - 5.5, ty - 5.3, 14.9), subdiv=1), MANA, 1.6)
    for k in range(4):  # lit windows round the turret
        a = 200 + k * 25
        neon(S.k.box((0.9, 0.2, 1.6), tuple(Vector((tx, ty, 5.4)) + polar(3.9, a)), (0, 0, a + 90)), (255, 214, 130), 1.4)
    lv(4)
    hx, hy = 21.0, -11.0
    for zz in (0.25, 5.25):
        post(1.5, 0.4, (hx, hy, zz), S.WOOD_DARK, rng, n=8)
    for a in range(0, 360, 90):
        post(0.14, 5.0, Vector((hx, hy, 0.45)) + polar(1.3, a + 45), S.WOOD_DARK, rng, n=5)
    turn([(1.15, 0.0), (0.16, 2.3), (1.15, 4.6)], (hx, hy, 0.65), (200, 226, 240), rng, n=10, kind=S.PALE)
    neon(S.k.cyl(0.95, 1.2, (hx, hy, 1.3), n=10, r2=0.3), (255, 214, 130), 1.2)
    lv(1)
    for x, y, yaw in ((-10.0, -9.0, 20), (9.5, -9.5, -15)):
        spin([box((5.0, 2.4, 0.3), (x, y, 2.4), S.WOOD, rng)] + [box((0.4, 0.4, 2.2), (x + dx, y + dy, 0.25), S.WOOD_DARK, rng) for dx in (-2.1, 2.1) for dy in (-0.9, 0.9)], (x, y), yaw)
        for i in range(3):
            box((1.1, 0.8, 0.26), (x - 1.2 + i * 0.2, y + 0.2, 2.7 + i * 0.27), ((170, 60, 70), (60, 110, 180), (220, 180, 80))[i], rng, yaw=yaw + i * 12)
        post(0.1, 0.8, (x + 1.6, y, 2.7), S.WHITE, rng, n=5)
        neon(S.k.ico(0.2, (x + 1.6, y, 3.7), subdiv=1), (255, 200, 90), 3.0)
    lv(2)
    for p in ((-30.0, -21.5), (30.0, -21.5), (-12.0, -18.0), (12.0, -18.0), (-29.0, 6.0), (29.0, 2.0)):
        post(0.2, 4.0, (*p, 0.25), (60, 60, 90), rng, n=6, kind=S.COOL)
        gem((p[0], p[1], 4.3), (p[0], p[1], 6.3), 0.9, MANA, 2.6, rng)
    lv(1)
    for x, y in ((-27.0, 18.0), (-23.0, 21.0), (28.0, -8.0)):
        pine((x, y, 0.25), rng, 1.2)
    lv(3)
    # a font of mana, low cases of scrolls along the sides, rugs to read on
    fx, fy = 14.0, -14.5
    turn([(2.6, 0.0), (2.9, 0.5), (2.0, 0.9), (1.5, 1.6), (2.8, 2.1), (3.0, 2.5), (2.6, 2.5)], (fx, fy, 0.25), (150, 152, 190), rng, n=10, kind=S.COOL)
    neon(S.k.cyl(2.6, 0.16, (fx, fy, 2.72), n=10), MANA, 2.0)
    for i in range(5):
        neon(S.k.ico(0.2 + 0.05 * i, (fx + math.cos(i * 1.9) * 1.2, fy + math.sin(i * 1.9) * 1.2, 3.4 + i * 0.6), subdiv=1), MANA, 2.6)
    lv(2)
    for side in (-1, 1):
        for i in range(3):
            shelf(rng, (side * 27.0, -8.0 + i * 7.2, 0.25), -90 * side, tall=4.6)
    lv(1)
    for x, y, yaw, rgb in ((-10.0, -9.0, 20, (150, 60, 90)), (9.5, -9.5, -15, (60, 80, 150)), (-16.0, -17.0, 8, (90, 60, 140))):
        box((8.6, 5.6, 0.06), (x, y, 0.25), rgb, rng, yaw=yaw, chance=0.08)
        box((7.6, 4.6, 0.07), (x, y, 0.25), S.GOLD, rng, yaw=yaw, chance=0.08)
        box((7.2, 4.2, 0.08), (x, y, 0.25), rgb, rng, yaw=yaw, chance=0.08)
    for i in range(4):  # cushions on the third rug
        lump((-18.4 + i * 1.6, -17.0 + (0.8 if i % 2 else -0.6), 0.6), (0.75, 0.75, 0.32), ((200, 80, 110), MANA, S.GOLD, (150, 120, 255))[i], rng)
    # the readers
    cast("creature_meerkat_storm", (-3.4, -3.0, 0.55), -25)
    cast("creature_jackal_pharaoh", (8.0, -5.0, 0.55), 40)
    cast("creature_flamingo", (-13.0, 3.0, 0.55), -70)
    cast("creature_tortoise_gemshell", (12.0, 6.5, 0.55), 110, first=1)
    cast("creature_lion", (-15.0, -15.5, 0.33), 20, first=1)  # on the cushions
    cast("creature_rhino", (15.0, -4.0, 0.33), 60, first=2)


# Health ---------------------------------------------------------------------------------------------------

AQUA = (96, 214, 206)
PINK = (255, 170, 200)


def pool(rng, at, r, depth=0.5):
    """A rock pool: a ring of boulders round warm water."""
    x, y, z = at
    disc(r, (x, y, z), depth, AQUA, rng, n=14, surface="gem", kind=S.COOL, emit=0.3, chance=0.06)
    n = max(8, int(r * 2.2))
    for i in range(n):
        a = i * 360 / n + rng.uniform(-6, 6)
        s = rng.uniform(0.9, 1.5)
        lump(Vector((x, y, z + 0.3)) + polar(r + 0.4, a), (s, s * 0.9, s * 0.75), (150, 142, 132), rng, surface="rock", kind=S.COOL)


def steam(rng, at, n=4):
    for i in range(n):
        p = Vector(at) + Vector((rng.uniform(-1.4, 1.4), rng.uniform(-1.4, 1.4), 1.4 + i * 1.3))
        ob = lump(p, (0.9 - i * 0.12, 0.9 - i * 0.12, 0.6 - i * 0.06), S.WHITE, rng, kind=S.PALE)
        ob.data.materials.clear()
        ob.data.materials.append(S.k.mat("steam", (255, 255, 255), kind="flat", emit=0.5, rough=1.0))


def stone_lantern(at, rng):
    x, y, z = at
    post(0.7, 0.4, at, (150, 142, 132), rng, n=6, surface="rock", kind=S.COOL)
    post(0.3, 1.9, (x, y, z + 0.4), (168, 160, 150), rng, n=6, kind=S.COOL)
    post(0.8, 0.3, (x, y, z + 2.3), (150, 142, 132), rng, n=6, kind=S.COOL)
    neon(S.k.box((0.8, 0.8, 0.8), (x, y, z + 3.0)), (255, 220, 150), 2.0)
    post(1.2, 0.8, (x, y, z + 3.4), (120, 114, 108), rng, n=6, r2=0.15, kind=S.COOL)


def bamboo(at, rng, n=7):
    for _ in range(n):
        x, y = at[0] + rng.uniform(-1.6, 1.6), at[1] + rng.uniform(-1.6, 1.6)
        h = rng.uniform(7.0, 11.0)
        for k in range(int(h // 1.6)):
            post(0.16, 1.5, (x, y, at[2] + k * 1.6), (120, 180, 90), rng, n=5)
            post(0.2, 0.1, (x, y, at[2] + k * 1.6 + 1.5), (90, 150, 70), rng, n=5)
        for k in range(4):
            a = rng.uniform(0, 360)
            top = Vector((x, y, at[2] + h - k * 1.2))
            shard(top, top + polar(1.7, a, 0.3), 0.5, 0.08, (104, 176, 84), rng, face=(0, 0, 1))


def soak(rng, at, r, band):
    """A bath: warm water inside a marble rim with a band of tiles round it."""
    x, y, z = at
    slab(r, r + 0.9, 0, 360, z, 0.75, S.MARBLE, rng, centre=(x, y), step=30, kind=S.PALE)
    slab(r + 0.9, r + 1.25, 0, 360, z, 0.5, band, rng, centre=(x, y), step=30)
    disc(r, (x, y, z), 0.5, AQUA, rng, n=12, surface="gem", kind=S.COOL, emit=0.3, chance=0.06)


def health(rng):
    """The Healing Spring (second design): a round terrace about the source, the Spring Tree growing from
    its rock, and six baths round it like petals, each fed by a channel of the spring's water."""
    yard(rng, "HEALING SPRING", HEALTH, (150, 196, 120), bare=(128, 176, 96))
    cx, cy, z = 0.0, 1.0, 0.45
    lv(0, 0)  # a new ranch: a warm spring among rocks
    pool(rng, (cx, cy, 0.1), 5.0)
    steam(rng, (cx, cy, 0.5), n=3)
    for a in (40, 150, 260):
        flowers(Vector((cx, cy, 0.25)) + polar(8.0, a), rng, n=8, spread=1.6)
    lv(1)  # the terrace, the source in its basin on a rock
    disc(22.6, (cx, cy, 0.25), 0.2, (236, 230, 214), rng, n=28, kind=S.PALE, chance=0.25)
    soak(rng, (cx, cy, z), 4.8, HEALTH)
    for i in range(7):
        lump(Vector((cx, cy, z + 0.9)) + polar(1.5 if i else 0.0, i * 51), (1.5, 1.4, 1.5 if i else 2.3), (150, 142, 132), rng, surface="rock", kind=S.COOL)
    for i, a in enumerate((240, 300, 0, 180, 60, 120)):  # the baths: two at first, two more at each of the next levels
        lv(1 + i // 2)
        p = Vector((cx, cy, z)) + polar(13.6, a)
        soak(rng, p, 4.0, HEALTH if i % 2 else PINK)
        steam(rng, p + Vector((0, 0, 0.3)), n=3)
        neon(S.k.box((2.4, 0.5, 0.1), tuple(Vector((cx, cy, z + 0.05)) + polar(7.25, a)), (0, 0, a)), (150, 240, 226), 1.6)  # its channel from the source
        for side in (-1, 1):  # a step in at each side
            box((1.6, 1.0, 0.4), p + polar(5.6, a + 180 + side * 24), S.MARBLE, rng, yaw=a + side * 24, kind=S.PALE)
    lv(2)  # a ring of tiles round the terrace, mats to dry off on, towels on a rail, bamboo behind
    for i in range(48):
        slab(21.3, 22.5, i * 7.5 + 0.2, (i + 1) * 7.5 - 0.2, z, 0.06, HEALTH if i % 2 else S.WHITE, rng, centre=(cx, cy), chance=0.2)
    for i in range(3):
        y = -15.0 + i * 5.0
        box((5.0, 3.6, 0.3), (27.4, y, 0.25), S.WOOD, rng)
        box((4.4, 3.0, 0.2), (27.4, y, 0.55), (S.WHITE, HEALTH, PINK)[i], rng)
        lump((29.0, y, 0.95), (0.6, 1.1, 0.3), S.WHITE, rng, kind=S.PALE)
    for sy in (-18.6, -1.4):
        box((0.3, 0.3, 2.6), (23.6, sy, 0.25), S.WOOD_DARK, rng)
    box((0.2, 17.4, 0.2), (23.6, -10.0, 2.7), S.WOOD_DARK, rng)
    for i, rgb in enumerate((S.WHITE, HEALTH, PINK, S.WHITE, HEALTH)):
        box((0.3, 1.6, 1.5), (23.6, -16.6 + i * 3.3, 1.3), rgb, rng)
    for x, y in ((-15.0, 22.6), (15.0, 22.6), (-19.5, 21.4), (19.5, 21.4)):
        bamboo((x, y, 0.25), rng)
    lv(2, 3)  # a young tree on the rock
    tree((cx, cy, z + 2.6), rng, 1.0, leaf=(120, 190, 110))
    lv(3)  # a herb garden in rows, a cross of healing at the way in, blossom trees
    for row in range(5):
        y = -15.0 + row * 3.0
        box((6.4, 1.5, 0.4), (-27.6, y, 0.25), (120, 88, 60), rng)
        for i in range(5):
            p = (-30.0 + i * 1.2, y, 0.65)
            lump((p[0], p[1], p[2] + 0.3), (0.45, 0.45, 0.4), (86, 160, 84), rng)
            if (i + row) % 2:
                lump((p[0], p[1], p[2] + 0.75), 0.22, (PINK, (255, 224, 90), (190, 150, 255), S.WHITE, HEALTH)[row], rng)
    disc(2.6, (cx, -17.8, z), 0.05, S.WHITE, rng, n=12, kind=S.PALE)
    for size in ((3.4, 1.1, 0.1), (1.1, 3.4, 0.1)):
        box(size, (cx, -17.8, z), HEALTH, rng, chance=0.05)
    for x, y in ((-29.0, -21.0), (29.0, -21.0)):
        tree((x, y, 0.25), rng, 0.9, leaf=(244, 160, 186))
    lv(4)  # the Spring Tree, grown: its roots over the rock, blossom in its crown; a pavilion to rest in
    bark = (124, 92, 66)
    pipe([(cx, cy, z + 1.8), (cx + 0.5, cy + 0.2, z + 5.0), (cx - 0.3, cy - 0.2, z + 8.0), (cx + 0.2, cy, z + 10.5)], [1.5, 1.1, 0.9, 0.6], bark, rng, n=8)
    for i in range(6):
        a = i * 60 + 20
        pipe([(cx, cy, z + 3.2), tuple(Vector((cx, cy, z + 1.7)) + polar(2.5, a)), tuple(Vector((cx, cy, z + 0.4)) + polar(4.3, a))], [0.5, 0.36, 0.16], bark, rng, n=5)
    for i in range(5):
        a = i * 72 + 10
        pipe([(cx, cy, z + 8.0), tuple(Vector((cx, cy, z + 10.2)) + polar(2.4, a)), tuple(Vector((cx, cy, z + 11.4)) + polar(4.4, a))], [0.6, 0.4, 0.2], bark, rng, n=5)
    crown = [(0.0, 0.0, 13.6, 3.6)] + [(*polar(3.9, i * 72 + 10)[:2], 12.0, 3.0) for i in range(5)] + [(*polar(2.2, i * 120 + 50)[:2], 15.4, 2.5) for i in range(3)]
    for dx, dy, dz, r in crown:
        lump((cx + dx, cy + dy, z + dz), (r, r, r * 0.74), (98 + rng.randrange(30), 176, 104), rng)
    for i in range(14):
        a, r = rng.uniform(0, 360), rng.uniform(1.5, 6.0)
        lump(Vector((cx, cy, z + rng.uniform(11.4, 16.6))) + polar(r, a), 0.85, (255, 176, 204), rng)
    px, py = 27.3, 12.0
    disc(4.6, (px, py, 0.25), 0.5, (236, 230, 214), rng, n=12, kind=S.PALE)
    for i in range(6):
        post(0.36, 5.6, Vector((px, py, 0.75)) + polar(3.8, i * 60 + 30), S.MARBLE, rng, n=8, kind=S.PALE)
    slab(3.2, 4.4, 0, 360, 6.35, 0.5, S.MARBLE, rng, centre=(px, py), step=30, kind=S.PALE)
    turn([(4.7, 0.0), (4.1, 1.4), (2.6, 2.5), (0.0, 3.0)], (px, py, 6.85), HEALTH, rng, n=12)
    lump((px, py, 10.1), 0.4, S.GOLD, rng)
    for i in range(3):
        lump(Vector((px, py, 1.05)) + polar(1.7, i * 120), (0.9, 0.9, 0.35), (PINK, S.WHITE, HEALTH)[i], rng)
    for x, y in ((-22.0, 22.6), (22.6, 21.6)):
        tree((x, y, 0.25), rng, 0.9, leaf=(244, 160, 186))
    lv(5)  # lanterns of healing light in its boughs, crystals at the source, a glasshouse, stone lanterns
    for i in range(10):
        p = Vector((cx, cy, z + 9.4 + (i % 2) * 0.8)) + polar(2.6 + (i % 3) * 1.5, i * 36 + 8)
        pipe([tuple(p + Vector((0, 0, 1.8))), tuple(p)], 0.04, S.INK, rng, n=4)
        neon(S.k.ico(0.42, tuple(p), subdiv=1), (150, 255, 170), 2.6)
    for h, w, lean in ((2.6, 0.9, (2.7, -2.1)), (1.8, 0.7, (-3.0, -1.6)), (2.0, 0.8, (0.4, -3.5))):
        base = Vector((cx + lean[0], cy + lean[1], z + 0.6))
        gem(base, base + Vector((0.2, 0.1, h)), w, HEALTH, 2.4, rng)
    gx, gy = -27.4, 13.0
    box((7.4, 11.4, 0.8), (gx, gy, 0.25), (236, 230, 214), rng, kind=S.PALE)
    for dx in (-3.5, 3.5):
        for dy in (-5.5, 0.0, 5.5):
            box((0.3, 0.3, 4.2), (gx + dx, gy + dy, 1.05), S.WHITE, rng, kind=S.PALE)
        neon(S.k.box((0.12, 10.6, 3.6), (gx + dx, gy, 3.0)), (170, 240, 220), 0.5)
    for dy in (-5.5, 5.5):
        neon(S.k.box((6.6, 0.12, 3.6), (gx, gy + dy, 3.0)), (170, 240, 220), 0.5)
    roof(12.0, 8.0, 2.6, (gx, gy, 5.25), (150, 226, 204), rng, yaw=90, ridge=8.0)
    for i in range(4):
        lump((gx - 1.5 + (i % 2) * 3.0, gy - 3.0 + (i // 2) * 6.0, 2.0), (1.1, 1.1, 1.0), (86, 160, 84), rng)
    for a in (20, 90, 160, 222, 318):
        stone_lantern(Vector((cx, cy, z)) + polar(20.2, a), rng)
    for i in range(4):
        bunting((-30.0 + i * 15.0, 23.6, 6.5), (-15.0 + i * 15.0, 23.6, 6.5), 1.0, rng, (HEALTH, S.WHITE, PINK), n=9, size=0.9)
    # the bathers
    cast("creature_tortoise", (cx, cy - 3.0, 0.3), 20, last=0)
    cast("creature_tortoise_gemshell", (cx - 6.8, cy - 11.8, z + 0.1), 30, first=1)
    cast("creature_flamingo", (cx + 6.8, cy - 11.8, z + 0.1), -30, first=1)
    cast("creature_rhino", (cx + 13.6, cy, z + 0.1), 90, first=2)
    cast("creature_lion", (cx - 13.6, cy, z + 0.1), -90, first=2)
    cast("creature_jackal", (cx + 6.8, cy + 11.8, z + 0.1), 200, first=3)
    cast("creature_meerkat", (px, py, 0.75), 250, first=4)


# Defence --------------------------------------------------------------------------------------------------

WALL = (178, 178, 192)
LOG = (156, 108, 66)


def shield(at, yaw, rng, rgb, tall=3.2, wide=2.3):
    """A shield standing on `at`, its face towards local -Y."""
    ob = prism([(-wide / 2, 0), (-wide / 2, tall * 0.55), (0, tall), (wide / 2, tall * 0.55), (wide / 2, 0), (0, -tall * 0.2)], (0, 0, 0), 0.3, rgb, rng)
    ob.data.transform(Matrix.Translation(Vector(at) + Vector((0, 0, tall * 0.2))) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X"))
    S.paint(ob, rgb, rng, chance=0.12)
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    lump((at[0] + 0.2 * s, at[1] - 0.2 * c, at[2] + tall * 0.62), (0.4, 0.4, 0.4), S.GOLD, rng)
    return ob


def dummy(at, yaw, rng, rgb):
    """A straw man on a post behind a shield, facing local -Y."""
    x, y, z = at
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    post(0.3, 5.2, at, S.WOOD_DARK, rng, n=6)
    box((4.0, 0.36, 0.36), (x, y, z + 3.6), S.WOOD_DARK, rng, yaw=yaw)
    lump((x, y, z + 3.2), (1.0, 0.75, 1.3), HAY, rng)
    lump((x, y, z + 5.5), 0.75, HAY, rng)
    post(0.85, 0.5, (x, y, z + 5.9), IRON, rng, n=8, r2=0.5, kind=S.COOL)
    shield((x + 0.9 * s - 0.3 * c, y - 0.9 * c - 0.3 * s, z + 1.6), yaw, rng, rgb)
    post(1.1, 0.3, at, HAY, rng, n=8)


def pad(rng, x, y, r=3.0):
    """Where an animal braces: a ring in the yard's colour on the floor."""
    slab(r - 0.5, r, 0, 360, 0.37, 0.08, DEFENCE, rng, centre=(x, y), step=30)
    disc(r - 0.5, (x, y, 0.37), 0.05, (240, 232, 210), rng, n=12, kind=S.PALE)


def ram_log(rng, x=0.0, y=8.0):
    """A ram's log with its padded head and iron bands. It moves: it swings at the animal on the pad."""
    post(1.0, 8.4, (x, y + 4.0, 3.6), LOG, rng, n=8, rot=(90, 0, 0))
    post(1.3, 1.5, (x, y - 4.3, 3.6), HAY, rng, n=8, rot=(90, 0, 0))
    for dy in (-3.9, 2.6):
        post(1.08, 0.4, (x, y + dy, 3.6), IRON, rng, n=8, rot=(90, 0, 0), kind=S.COOL)


def ram(rng, x, y):
    """A ram: a log slung from a frame, its padded head towards the pad to its south, where an animal
    braces against it."""
    for sx in (-3.4, 3.4):
        for sy in (-1, 1):
            pipe([(x + sx, y + sy * 4.0, 0.25), (x + sx, y + sy * 0.3, 9.2)], 0.36, (150, 104, 64), rng, n=6)
        lump((x + sx, y, 9.3), 0.6, S.GOLD, rng)
    box((7.8, 0.8, 0.8), (x, y, 8.6), S.WOOD_DARK, rng)
    if KIT:
        ram_log(rng, x, y)
        for dy in (-2.4, 2.4):  # the ropes it hangs by (the game draws its own, which follow the log)
            pipe([(x, y + dy * 0.2, 8.6), (x, y + dy, 4.6)], 0.09, IRON, rng, n=4)
    pad(rng, x, y - 9.0)


def thrower(rng, x, y, yaw):
    """A ball thrower on wheels, its barrel along `yaw` degrees, padded balls piled beside it."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    box((4.6, 2.6, 0.7), (x, y, 1.0), S.WOOD_DARK, rng, yaw=yaw)
    for side in (-1, 1):
        post(1.25, 0.5, (x - s * (1.6 * side + 0.25), y + c * (1.6 * side + 0.25), 1.5), S.WOOD, rng, n=10, rot=(90, 0, yaw))
    post(0.95, 5.4, (x - c * 1.8, y - s * 1.8, 2.3), IRON, rng, n=8, rot=(0, 68, yaw), kind=S.COOL)
    post(1.12, 0.6, (x - c * 1.8, y - s * 1.8, 2.3), DEFENCE, rng, n=8, rot=(0, 68, yaw))
    for i in range(6):
        along, row = (i % 3 - 1) * 1.25, i // 3
        lump((x - s * 3.4 + c * (along + row * 0.6), y + c * 3.4 + s * (along + row * 0.6), 0.85 + row * 0.95), 0.62, DEFENCE if i % 2 else S.WHITE, rng)


def keep(rng, x, y):
    """A round stone tower with a crenellated top."""
    post(4.2, 11.0, (x, y, 0.25), WALL, rng, n=10, surface="rock", kind=S.COOL)
    post(4.8, 0.8, (x, y, 11.25), (206, 206, 216), rng, n=10, kind=S.COOL)
    for i in range(10):
        box((1.5, 0.8, 1.3), Vector((x, y, 12.05)) + polar(4.3, i * 36), (206, 206, 216), rng, yaw=i * 36 + 90, kind=S.COOL)
    for zz in (4.0, 8.0):
        box((0.7, 0.3, 1.8), (x, y - 4.1, zz), (60, 56, 70), rng, kind=S.COOL)  # arrow slits


def defence(rng):
    """The Guard Yard (second design): a stone court below a castle wall, where animals brace against
    rams and ball throwers and spar with straw men."""
    yard(rng, "GUARD YARD", DEFENCE, (222, 204, 166), bare=(206, 186, 140))
    lv(0)  # a new ranch: two straw men to stand up to
    for x in (-3.5, 3.5):
        dummy((x, -12.5, 0.25), 0, rng, DEFENCE if x > 0 else (210, 70, 60))
    lv(1)  # a court of flagstones, the first ram
    for ix in range(10):
        for iy in range(7):
            box((4.9, 4.9, 0.12), (-22.5 + ix * 5.0, -17.0 + iy * 5.0, 0.25), (238, 226, 198) if (ix + iy) % 2 else (226, 212, 180), rng, kind=S.PALE, chance=0.15)
    ram(rng, 0.0, 8.0)
    lv(2)  # a second ram, sandbags between the pads, a rack of shields
    ram(rng, -17.0, 8.0)
    for bx in (-8.5, 8.5):
        for row in range(3):
            for i in range(4 - row):
                lump((bx - (4 - row) * 0.9 + i * 1.8 + 0.9, -1.0, 0.37 + 0.45 + row * 0.8), (0.95, 0.6, 0.45), (196, 176, 136), rng)
    box((1.0, 12.4, 0.7), (-30.3, 7.0, 0.25), S.WOOD_DARK, rng)
    for i in range(5):
        shield((-29.6, 2.2 + i * 2.4, 0.9), 90, rng, (DEFENCE, (210, 70, 60), SPEED, HEALTH, S.GOLD)[i], tall=2.8, wide=1.8)
    lv(3)  # the wall, two ball throwers and the shields to stand behind, armour on stands
    box((40.0, 2.4, 7.0), (0, 19.0, 0.25), WALL, rng, surface="rock", kind=S.COOL)
    box((40.6, 3.0, 0.5), (0, 19.0, 7.25), (206, 206, 216), rng, kind=S.COOL)
    box((6.4, 0.3, 5.4), (0, 17.72, 0.25), (62, 52, 50), rng)  # its gate
    for sx in (-3.6, 3.6):
        box((0.9, 0.6, 5.9), (sx, 17.6, 0.25), (206, 206, 216), rng, kind=S.COOL)
    box((8.1, 0.6, 0.9), (0, 17.6, 5.75), (206, 206, 216), rng, kind=S.COOL)
    for side in (-1, 1):
        thrower(rng, side * 27.0, -13.0, 90 + 90 * side)
        pad(rng, side * 14.0, -13.0)
        shield((side * 17.4, -13.0, 0.37), 90 * side, rng, DEFENCE, tall=4.6, wide=3.2)
    for i in range(4):
        x, y = 29.8, 2.5 + i * 3.0
        post(0.16, 3.6, (x, y, 0.25), S.WOOD_DARK, rng, n=5)
        box((0.3, 2.2, 0.3), (x, y, 3.2), S.WOOD_DARK, rng)
        lump((x, y, 2.5), (0.6, 0.95, 1.0), IRON, rng, kind=S.COOL)
        post(0.6, 0.5, (x, y, 3.9), IRON, rng, n=8, r2=0.4, kind=S.COOL)
    lv(4)  # a third ram, battlements and a tower at each end of the wall, braziers
    ram(rng, 17.0, 8.0)
    for i in range(13):
        box((1.6, 0.7, 1.3), (-19.2 + i * 3.2, 17.85, 7.75), (206, 206, 216), rng, kind=S.COOL)
    for sx in (-23.5, 23.5):
        keep(rng, sx, 19.0)
        post(4.6, 5.2, (sx, 19.0, 13.35), DEFENCE, rng, n=10, r2=0.0)
    for p in ((-30.0, -21.5), (30.0, -21.5), (-6.5, 15.5), (6.5, 15.5)):
        brazier((*p, 0.25), rng)
    lv(5)  # the great shield over the gate, banners, flags on the towers, pennants between the rams
    shield((0, 17.3, 7.4), 0, rng, DEFENCE, tall=5.4, wide=4.4)
    for x in (-15.0, -9.0, 9.0, 15.0):
        flag((x, 17.7, 6.8), 2.6, 5.0, DEFENCE if abs(x) > 10 else (210, 70, 60), rng)
    for sx in (-23.5, 23.5):
        post(0.14, 4.2, (sx, 19.0, 18.5), S.WOOD_DARK, rng, n=5)
        flag((sx + 1.1, 19.0, 22.5), 2.2, 3.0, DEFENCE, rng)
    for a, b in ((-17.0, 0.0), (0.0, 17.0)):
        bunting((a + 3.4, 8.0, 9.5), (b - 3.4, 8.0, 9.5), 1.2, rng, (DEFENCE, S.WHITE, (210, 70, 60)), n=9, size=1.0)
    # the guards
    cast("creature_cheetah", (-3.5, -18.3, 0.25), 180)  # sparring with a straw man
    cast("creature_rhino", (0.0, -0.6, 0.37), 180, first=1)  # braced against the first ram
    cast("creature_tortoise", (-17.0, 0.3, 0.37), 180, first=2)
    cast("creature_lion", (-13.6, -13.0, 0.37), -90, first=3)  # behind a shield, facing a thrower
    cast("creature_jackal", (13.9, -13.0, 0.37), 90, first=3)
    cast("creature_elephant", (17.0, -2.7, 0.37), 180, first=4)
    cast("creature_meerkat", (-8.0, 19.0, 7.75), 0, first=4)  # on watch on the wall


# The ranch and its six clearings ---------------------------------------------------------------------------

AREAS = (("SPEED TRACK", SPEED, "speed"), ("STRENGTH GYM", STRENGTH, "strength"), ("SWIM POOL", STAMINA, "stamina"), ("MAGIC LIBRARY", MANA, "mana"), ("HEALING SPRING", HEALTH, "health"), ("GUARD YARD", DEFENCE, "defence"))
OUT = 400.0  # a ranch's middle to the middle of a clearing
RING = 132.0  # a clearing's middle to the feet of its mountains
VALLEY = 134.0  # and to the feet of the mountains round the ranch (World.luau's RING)


def mountain(rng, at, foot, tall):
    post(foot, tall, at, (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
    if tall > 98:
        post(foot * 0.36, tall * 0.28, (at[0], at[1], tall * 0.74), S.WHITE, rng, n=7, r2=foot * 0.1, rot=(0, 0, rng.uniform(0, 50)), kind=S.PALE)


def ranch_map(rng):
    """One ranch and its six training areas: each in a clearing of its own beyond the ranch's mountains, at
    the end of a pass that leaves the ranch through a gateway in its stat's colour. The pass to the hub
    leaves to the south; the six others fan out round the rest of the ring."""
    makers = (speed, strength, stamina, mana, health, defence)
    ways = [-90 + (i + 1) * 360 / 7 for i in range(6)]
    # the ranch: its fenced plot (150 studs square) with the house, the barn and the hatchery sketched in
    box((150, 150, 0.3), (0, 0, 0), (120, 176, 84), rng, chance=0.15)
    for a, b in (((-75, -75), (-9, -75)), ((9, -75), (75, -75)), ((75, -75), (75, 75)), ((75, 75), (-75, 75)), ((-75, 75), (-75, -75))):
        fence((*a, 0.3), (*b, 0.3), rng, h=4.2, gap=6.0)
    box((30, 22, 13), (-34, 34, 0.3), (232, 214, 180), rng, kind=S.PALE)  # the house
    roof(34, 26, 9, (-34, 34, 13.3), (176, 70, 60), rng, ridge=14)
    box((30, 20, 13), (36, 36, 0.3), (196, 64, 54), rng)  # the barn
    roof(33, 23, 9, (36, 36, 13.3), (84, 72, 76), rng, ridge=20)
    disc(13, (0, -22, 0.3), 0.6, (226, 214, 190), rng, n=16, kind=S.PALE)  # the hatchery
    for i in range(5):
        actor("egg_meadow" if i % 2 else "egg_wild", Vector((0, -22, 0.9)) + polar(8.0, i * 72), 0, scale=1.6)
    box((14, 60, 0.36), (0, -52, 0), (206, 190, 160), rng, kind=S.PALE)
    actor("creature_lion", (-12, -2, 0.3), 30)
    actor("creature_elephant", (26, -6, 0.3), -60)
    actor("creature_flamingo", (-30, -30, 0.3), 100)
    # the mountains round the ranch, open to the hub's pass (south) and to each area's pass
    for i in range(34):
        a = i * 360 / 34 + rng.uniform(-2, 2)
        foot = rng.uniform(34, 50)
        if min(abs((a - w + 180) % 360 - 180) for w in ways + [-90]) * math.radians(1) * (VALLEY + foot * 0.75) < foot + 12:
            continue  # it would stand in a pass
        mountain(rng, polar(VALLEY + foot * 0.75, a), foot, rng.uniform(60, 105))
    box((18, 240, 0.12), (0, -75 - 120, 0.02), (206, 190, 160), rng, kind=S.PALE)  # the road down to the hub
    words("TO THE HUB", (0, -330, 30), 18, S.WHITE, glow=0.6)
    for (name, colour, _), maker, way in zip(AREAS, makers, ways):
        c = polar(OUT, way)
        area(maker, rng, at=(c.x, c.y), yaw=way - 90)
        clearing(rng, r=RING, gap=(-90.0, 27.0), at=(c.x, c.y), yaw=way - 90)
        # the pass: a path from the plot's fence, through a gateway in the stat's colour, between the mountains
        length = OUT - D * K / 2 - 60  # from near the fence to the area's own gateway
        box((length, 14, 0.1), polar(60 + length / 2, way), (206, 190, 160), rng, yaw=way, kind=S.PALE)
        g = polar(VALLEY - 14, way)
        for side in (-1, 1):
            p = g + polar(11.0, way + 90 * side)
            box((4.0, 4.0, 22.0), p, S.STONE, rng, yaw=way, surface="rock", kind=S.PALE)
            neon(S.k.cyl(1.4, 2.6, (p.x, p.y, 23.6), n=6), colour, 2.4)
            flag(p + polar(2.1, way + 180, 19.0), 3.0, 9.0, colour, rng, yaw=way + 90)
        box((30.0, 3.0, 2.6), g + Vector((0, 0, 22.0)), S.WOOD_DARK, rng, yaw=way + 90)
        box((22.0, 1.0, 6.0), g + Vector((0, 0, 14.5)), colour, rng, yaw=way + 90, chance=0.08)
        for side in (-1, 1):  # the walls of the pass
            for k in range(5):
                foot = rng.uniform(30, 40)
                mountain(rng, polar(VALLEY + 22 + k * 28, way) + polar(26 + foot * 0.8, way + 90 * side), foot, rng.uniform(55, 90))
        label = polar(OUT, way, 150.0)
        words(name, label, 20, colour, glow=1.2)  # read from the south, where the card looks from


# The cards -------------------------------------------------------------------------------------------------

HERO = ((-150, -175, 150), (0, 8, 5), 34)


def site(maker):
    """An area alone in its clearing, its pass to the south."""

    def build(rng):
        area(maker, rng)
        clearing(rng, r=RING, gap=(-118.0, 46.0))

    return build


def shots(close):
    """The finished area, the same view at upgrade levels 0 to 4, and one close look."""
    return [(*HERO, S.TOP)] + [(*HERO[:2], 44, level) for level in range(S.TOP)] + [(*close, S.TOP)]


SCENES = [
    dict(name="train_speed", build=site(speed), shots=shots(((-74, -52, 15), (12, -22, 9), 28))),
    dict(name="train_strength", build=site(strength), shots=shots(((-88, -22, 16), (-42, 30, 13), 28))),
    dict(name="train_stamina", build=site(stamina), shots=shots(((-92, -34, 20), (-18, 4, 6), 28))),
    dict(name="train_mana", build=site(mana), shots=shots(((-12, -60, 13), (0, 10, 22), 24))),
    dict(name="train_health", build=site(health), shots=shots(((-10, -58, 12), (0, 6, 15), 24))),
    dict(name="train_defence", build=site(defence), shots=shots(((-44, -56, 13), (0, 18, 10), 26))),
    dict(
        name="ranch_map",
        build=ranch_map,
        shots=[
            ((-190, -830, 1080), (0, 40, 0), 30),  # the ranch and its six clearings from the south
            ((0, -1, 2300), (0, 0, 0), 50),  # the plan
            ((70, -60, 58), (-124, 100, 10), 28),  # from the ranch: the gateways of two of the passes
            ((-141, 32, 15), (-390, 89, 16), 30),  # in a pass, looking into its clearing
        ],
    ),
]
