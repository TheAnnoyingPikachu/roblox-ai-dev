"""A large area for each of the six training activities on a ranch (concepts, decision 0059), in place
of today's six small courts: the Speed Track, the Strength Gym, the Swim Pool, the Magic Library, the
Healing Spring and the Guard Yard. Each is a fenced yard about 64 by 48 studs behind a gateway in its
stat's colour (Ranch.luau's STAT_COLOUR), with the game's own animals in it for scale.
The gateway is on the south side (-Y).
"""

import math

import stage as S
from mathutils import Matrix, Vector
from stage import actor, bench, box, bunting, disc, fence, flag, flowers, gem, lantern, lump, moved, neon, pine, pipe, polar, post, prism, rock, roof, shard, slab, spin, tree, turn, words

SPEED, STRENGTH, STAMINA = (60, 150, 255), (235, 70, 70), (170, 90, 245)
MANA, HEALTH, DEFENCE = (60, 215, 225), (70, 205, 120), (255, 165, 50)
HAY = (228, 196, 110)
RED = (224, 64, 60)
IRON = (86, 88, 100)
W, D = 64, 48  # a yard


def yard(rng, name, colour, ground, kind=S.PALE):
    """What every area shares: its floor, its fence with a pennant at each corner, its gateway and sign."""
    hw, hd = W / 2, D / 2
    box((W + 3, D + 3, 0.25), (0, 0, 0), ground, rng, kind=kind, chance=0.12)
    z = 0.25
    for a, b in (((-hw, -hd), (-8, -hd)), ((8, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))):
        fence((*a, z), (*b, z), rng, gap=4.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            post(0.28, 8.5, (sx * hw, sy * hd, z), S.WOOD_DARK, rng, n=6)
            flag((sx * hw + 1.0, sy * hd, 8.6), 2.0, 3.0, colour, rng)
            lump((sx * hw, sy * hd, 8.95), 0.36, S.GOLD, rng)
    for sx in (-1, 1):  # the gateway
        box((1.5, 1.5, 0.8), (sx * 7.5, -hd, z), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
        box((1.1, 1.1, 8.6), (sx * 7.5, -hd, z + 0.8), S.WOOD_DARK, rng)
        spin(lantern((sx * 9.6, -hd - 0.4, z), rng, h=5.0), (sx * 9.6, -hd - 0.4), 90 - 90 * sx)
        flag((sx * 7.5, -hd - 0.62, 7.6), 1.3, 3.6, colour, rng)
    box((17.5, 1.2, 1.0), (0, -hd, 9.4), S.WOOD_DARK, rng)
    box((14.6, 0.5, 3.2), (0, -hd, 10.4), colour, rng, chance=0.08)
    box((15.4, 0.3, 4.0), (0, -hd, 10.0), S.GOLD, rng)
    roof(17.0, 2.4, 1.3, (0, -hd, 14.0), S.WOOD_DARK, rng, ridge=17.0)
    words(name, (0, -hd - 0.3, 12.0), 1.7, S.WHITE)
    box((13.0, 60.0, 0.08), (0, -hd - 30.0, 0.05), (206, 190, 160), rng, kind=S.PALE)  # the path in
    for _ in range(46):  # the ranch round it: trees, bushes, flowers
        x, y = rng.uniform(-hw - 46, hw + 46), rng.uniform(-hd - 40, hd + 46)
        if abs(x) < hw + 5 and abs(y) < hd + 5 or abs(x) < 10 and y < 0:
            continue
        roll = rng.random()
        if roll < 0.4:
            tree((x, y, 0), rng, rng.uniform(0.9, 1.3))
        elif roll < 0.55:
            pine((x, y, 0), rng, rng.uniform(1.0, 1.4))
        elif roll < 0.75:
            rock((x, y, 0), rng, rng.uniform(0.7, 1.4))
        else:
            flowers((x, y, 0), rng, n=7, spread=1.6)


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
    for side in (-1, 1):  # two bends and two straights: four lanes of clay with white lines
        for i in range(4):
            r0 = 5.0 + i * lane
            slab(r0, r0 + lane - 0.14, -90 if side > 0 else 90, 90 if side > 0 else 270, 0.25, 0.18, track, rng, centre=(side * cx, 0), step=10, chance=0.1)
            box((2 * half, lane - 0.14, 0.18), (0, side * (r0 + lane / 2 - 0.07), 0.25), track, rng, chance=0.1)
    box((0.5, 4 * lane, 0.04), (-4.0, -(5.0 + 2 * lane), 0.43), S.WHITE, rng)  # the start line
    for i in range(8):  # the finish line, chequered
        for j in range(2):
            box((0.5, 1.2, 0.04), (4.0 + j * 0.5, -(5.0 + 0.6 + i * 1.2), 0.43), S.INK if (i + j) % 2 else S.WHITE, rng)
    # the gantry over the line
    for sy in (-4.2, -15.4):
        box((0.8, 0.8, 8.0), (4.25, sy, 0.25), IRON, rng)
    box((1.0, 12.2, 1.6), (4.25, -9.8, 8.25), SPEED, rng, chance=0.08)
    words("FINISH", (3.7, -9.8, 9.05), 1.1, S.WHITE, yaw=-90)
    for i, rgb in enumerate(((255, 60, 60), (255, 210, 60), (80, 240, 110))):
        neon(S.k.ico(0.42, (3.7, -12.0 + i * 1.1, 7.6), subdiv=1), rgb, 2.5)
    for i in range(10):
        for j in range(2):
            box((0.12, 1.2, 0.7), (4.8, -15.2 + i * 1.2, 6.9 + j * 0.7), S.INK if (i + j) % 2 else S.WHITE, rng)
    for x in (-8.0, 0.0, 8.0):  # hurdles down the far straight
        for i in range(4):
            y = 5.0 + i * lane + lane / 2
            for sx in (-0.9, 0.9):
                post(0.09, 1.5, (x, y + sx, 0.43), S.WHITE, rng, n=5)
            box((0.14, 2.0, 0.3), (x, y, 1.75), SPEED if i % 2 else S.WHITE, rng)
    for side in (-1, 1):  # glowing arrows round the bends, bales outside them
        for i in range(5):
            a = (-60 + i * 30) if side > 0 else (120 + i * 30)
            p = Vector((side * cx, 0, 0.46)) + polar(5.0 + 2 * lane, a)
            neon(prism([(-0.7, -0.9), (0.7, 0), (-0.7, 0.9), (-0.3, 0)], p, 0.05, SPEED, rng, yaw=a + 90), SPEED, 2.0)
        for i in range(7):
            a = (-75 + i * 25) if side > 0 else (105 + i * 25)
            p = Vector((side * cx, 0, 0.25)) + polar(15.6, a)
            box((2.6, 1.3, 1.2), p, HAY, rng, yaw=a + 90)
    # the infield: a slalom, a tyre run, a pond
    box((2 * half, 9.4, 0.12), (0, 0, 0.25), (104, 168, 76), rng, chance=0.12)
    for side in (-1, 1):
        slab(0, 4.7, -90 if side > 0 else 90, 90 if side > 0 else 270, 0.25, 0.12, (104, 168, 76), rng, centre=(side * cx, 0), step=15)
    for i in range(9):
        post(0.14, 2.4, (-11.0 + i * 2.0, 2.2 if i % 2 else 3.6, 0.37), SPEED if i % 2 else S.WHITE, rng, n=6)
        flag((-11.0 + i * 2.0 + 0.5, 2.2 if i % 2 else 3.6, 2.7), 0.9, 0.7, (255, 210, 60), rng, point=False)
    for i in range(8):
        slab(0.42, 0.95, 0, 360, 0.37, 0.4, (48, 46, 54), rng, centre=(-10.5 + i * 1.6, -2.3 + (0.7 if i % 2 else -0.7)), step=45)
    disc(3.2, (12.0, 0.2, 0.3), 0.14, S.WATER, rng, n=14, surface="gem", kind=S.COOL, emit=0.2)
    for a in range(0, 360, 40):
        rock(Vector((12.0, 0.2, 0.3)) + polar(3.4, a), rng, 0.5)
    # the stand, the timing tower, the kit
    for i in range(4):
        box((22.0, 2.2, 1.1 + i * 1.1), (-4.0, 17.0 + i * 2.2, 0.25), S.WOOD if i % 2 else (176, 124, 78), rng)
    for sx in (-14.5, -4.0, 6.5):
        box((0.5, 0.5, 9.5), (sx, 24.2, 0.25), S.WOOD_DARK, rng)
    for i in range(11):
        box((2.0, 9.6, 0.25), (-14.0 + i * 2.0, 20.4, 9.4), SPEED if i % 2 else S.WHITE, rng, tilt=(10, 0))
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
    for i, p in enumerate(((-25.0, -18.0), (-22.5, -18.5), (-27.5, -15.5), (25.0, -19.0), (27.5, -16.0), (-28.0, 12.0), (28.0, 6.0))):
        cone((*p, 0.25), rng)
    barrel((-27.0, 18.5, 0.25), rng, SPEED)
    barrel((-25.0, 19.4, 0.25), rng)
    spin(bench((26.0, -6.0, 0.25), rng), (26.0, -6.0), 90)
    for sx in (-30.0, 30.0):
        tree((sx, 22.0, 0.25), rng, 0.8)
    for i in (0, 1, 4, 5):  # flags along the front fence, clear of the gateway
        bunting((-30.0 + i * 10, -23.6, 6.0), (-20.0 + i * 10, -23.6, 6.0), 0.9, rng, (SPEED, S.WHITE, (255, 210, 60)), n=7, size=0.8)
    # the runners
    actor("creature_cheetah", (-9.0, -7.2, 0.43), 90)
    actor("creature_cheetah_lightning", (-13.0, -12.4, 0.43), 90)
    actor("creature_jackal", (-17.5, -9.8, 0.43), 90)
    actor("creature_flamingo", (13.0, 10.0, 0.43), -90)


# Strength -------------------------------------------------------------------------------------------------


def weight(at, r, rng, band, axis=0.0):
    """A stone weight disc standing on its rim, its axle along `axis` degrees."""
    c = Vector(at) + Vector((0, 0, r))
    post(r, 0.7, c - polar(0.35, axis), (150, 146, 142), rng, n=12, rot=(0, 90, axis), surface="rock", kind=S.COOL)
    post(r * 0.62, 0.76, c - polar(0.38, axis), band, rng, n=12, rot=(0, 90, axis))
    post(r * 0.2, 0.84, c - polar(0.42, axis), IRON, rng, n=8, rot=(0, 90, axis))


def strength(rng):
    yard(rng, "STRENGTH GYM", STRENGTH, (214, 188, 140))
    # the lifting deck under a timber frame, a great barbell on its stands
    box((22.0, 13.0, 0.6), (-17.0, 12.0, 0.25), S.WOOD, rng)
    for i in range(11):
        box((1.9, 12.6, 0.1), (-27.0 + i * 2.0, 12.0, 0.85), (166, 116, 72) if i % 2 else (176, 126, 80), rng)
    for sx in (-27.5, -6.5):
        for sy in (6.0, 18.0):
            box((1.0, 1.0, 10.0), (sx, sy, 0.25), S.WOOD_DARK, rng)
    for sy in (6.0, 18.0):
        box((23.0, 1.0, 1.0), (-17.0, sy, 10.25), S.WOOD_DARK, rng)
    for i in range(7):
        box((0.7, 14.0, 0.7), (-26.0 + i * 3.0, 12.0, 11.25), S.WOOD, rng)
    for sx in (-21.0, -13.0):
        box((0.7, 0.7, 4.2), (sx, 12.0, 0.95), IRON, rng)
        box((1.5, 0.9, 0.4), (sx, 12.0, 5.15), IRON, rng)
    pipe([(-25.5, 12.0, 5.75), (-8.5, 12.0, 5.75)], 0.28, (190, 194, 204), rng, n=8)
    for sx, r in ((-24.6, 2.6), (-23.6, 2.1), (-10.4, 2.1), (-9.4, 2.6)):
        post(r, 0.8, (sx - 0.4, 12.0, 5.75), (150, 146, 142), rng, n=12, rot=(0, 90, 0), surface="rock", kind=S.COOL)
        post(r * 0.6, 0.86, (sx - 0.43, 12.0, 5.75), STRENGTH, rng, n=12, rot=(0, 90, 0))
    box((2.6, 1.6, 1.2), (-17.0, 16.6, 0.95), S.STONE, rng, kind=S.PALE)  # the chalk trough
    lump((-17.0, 16.6, 2.25), (1.0, 0.55, 0.3), S.WHITE, rng)
    for i, r in enumerate((1.0, 1.3, 1.6, 1.9)):  # spare weights against the back posts
        weight((-27.0 + i * 0.5, 16.2 - i * 2.4, 0.95), r, rng, STRENGTH if i % 2 else S.GOLD, axis=20)
    # the boulder run: two rails, a boulder, marks every few studs
    for sy in (-15.4, -10.6):
        box((40.0, 0.5, 0.5), (-7.0, sy, 0.25), S.WOOD_DARK, rng)
    box((40.0, 4.3, 0.1), (-7.0, -13.0, 0.25), (190, 160, 116), rng, chance=0.1)
    for i in range(8):
        box((0.3, 4.3, 0.06), (-25.0 + i * 5.0, -13.0, 0.36), S.WHITE if i < 7 else STRENGTH, rng)
    lump((-8.0, -13.0, 2.95), (2.9, 2.9, 2.75), (140, 134, 128), rng, surface="rock", kind=S.COOL)
    box((1.0, 5.6, 4.6), (13.6, -13.0, 0.25), S.WOOD_DARK, rng)  # the stop at its end, with a bell
    neon(S.k.ico(0.5, (13.0, -13.0, 5.3), subdiv=1), (255, 210, 60), 1.4)
    # the stones: five on plinths, light to heavy
    for i, r in enumerate((0.9, 1.15, 1.4, 1.7, 2.05)):
        x = 3.0 + i * 5.2
        post(1.6 + i * 0.14, 1.1, (x, 16.0, 0.25), S.STONE_DARK, rng, n=8, surface="rock", kind=S.COOL)
        lump((x, 16.0, 1.35 + r * 0.92), (r, r, r * 0.95), (168, 160, 150), rng, surface="rock", kind=S.COOL)
        post(0.5, 0.1, (x, 14.3, 0.6), (STRENGTH, S.GOLD)[i % 2], rng, n=8, rot=(60, 0, 0))
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
    # tyres to flip, a striking post, a climbing rope with a bell
    for i in range(3):
        slab(1.5, 2.8, 0, 360, 0.25 + i * 1.0, 0.95, (52, 50, 58), rng, centre=(22.0 + 0.3 * i, 3.0 - 0.2 * i), step=30)
    slab(1.5, 2.8, 0, 360, 0.25, 0.95, (52, 50, 58), rng, centre=(15.5, 4.2), step=30)
    post(0.7, 6.0, (10.0, 4.5, 0.25), S.WOOD_DARK, rng, n=8)
    for z in (1.6, 2.6, 3.6, 4.6):
        turn([(0.78, 0.0), (0.92, 0.35), (0.78, 0.7)], (10.0, 4.5, z), HAY, rng, n=8)
    box((0.9, 0.9, 13.0), (27.0, 17.5, 0.25), S.WOOD_DARK, rng)
    box((6.4, 0.7, 0.7), (24.2, 17.5, 12.8), S.WOOD_DARK, rng)
    pipe([(21.6, 17.5, 12.8), (21.6, 17.5, 1.2)], 0.2, HAY, rng, n=6)
    for z in range(3, 12, 2):
        lump((21.6, 17.5, z), 0.34, HAY, rng)
    neon(S.k.ico(0.55, (21.6, 17.5, 13.7), subdiv=1), (255, 210, 60), 1.4)
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
    for p in ((-30.0, -21.5), (30.0, -21.5), (-30.0, 22.0), (30.0, 22.0), (-5.0, -20.5), (5.0, -20.5)):
        brazier((*p, 0.25), rng)
    for i in range(5):
        bunting((-29.0 + i * 12, 22.5, 6.5), (-17.0 + i * 12, 22.5, 6.5), 1.0, rng, (STRENGTH, S.WHITE, S.GOLD), n=8, size=0.9)
    # the lifters
    actor("creature_rhino", (-16.6, -13.0, 0.35), 90)  # shoulder to the boulder
    actor("creature_lion", (-17.0, 9.2, 0.95), 180)  # under the bar
    actor("creature_cheetah", (1.5, -3.0, 0.25), 90)  # in the yoke


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
    for lane in range(1, 5):  # lane ropes of floats
        y = y0 + lane * (y1 - y0) / 5
        for i in range(34):
            x = x0 + 0.9 + i * 1.16
            lump((x, y, z0 + 1.2), (0.42, 0.3, 0.3), STAMINA if i % 2 else S.WHITE, rng)
    for lane in range(5):  # starting blocks, numbered by colour
        y = y0 + (lane + 0.5) * (y1 - y0) / 5
        box((1.6, 1.8, 0.9), (x0 - 1.4, y, z0 + deck), S.WHITE, rng, kind=S.PALE)
        box((1.7, 1.9, 0.16), (x0 - 1.5, y, z0 + deck + 0.9), (RED, (255, 190, 60), (90, 200, 120), SPEED, STAMINA)[lane], rng, tilt=(0, 8))
    for x, y in ((x1 - 1.0, y0), (x1 - 1.0, y1), (x0 + 6.0, y1)):  # ladders
        for dx in (-0.45, 0.45):
            s = 1 if y > 0 else -1
            pipe([(x + dx, y - 0.6 * s, z0 + 0.3), (x + dx, y - 0.6 * s, z0 + deck + 1.3), (x + dx, y + 0.8 * s, z0 + deck + 1.3), (x + dx, y + 0.8 * s, z0 + deck)], 0.09, (220, 224, 232), rng, n=5)
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
    for i, (x, y) in enumerate(((-18.0, 15.5), (-11.0, 15.5), (-26.0, -13.0), (22.0, -13.0), (27.5, 15.0))):
        post(0.12, 5.2, (x, y, z0 + deck), S.WHITE, rng, n=5)
        parasol((x, y, z0 + deck + 4.9), 3.1, 1.1, (STAMINA, (255, 190, 60), SPEED, RED, HEALTH)[i], rng)
        box((1.5, 4.2, 0.3), (x + 2.6, y, z0 + deck + 0.5), S.WHITE, rng, kind=S.PALE)
        box((1.5, 1.6, 0.3), (x + 2.6, y + 2.2, z0 + deck + 0.9), S.WHITE, rng, kind=S.PALE, tilt=(-40, 0))
        box((1.3, 3.0, 0.1), (x + 2.6, y - 0.4, z0 + deck + 0.8), (STAMINA, (255, 190, 60), SPEED, RED, HEALTH)[i], rng)
    for x, y in ((-30.0, 20.0), (30.0, 20.5), (-30.5, -20.0), (29.5, -20.0), (-22.0, 21.5), (16.0, 21.5)):
        palm((x, y, z0), rng, rng.uniform(0.9, 1.15))
    for x, y, rgb in ((-9.0, 3.0, RED), (5.0, -4.5, (255, 210, 60)), (11.0, 6.5, HEALTH)):  # floats on the water
        slab(0.7, 1.4, 0, 360, z0 + 1.15, 0.45, rgb, rng, centre=(x, y), step=30)
    lump((-25.0, 14.0, z0 + deck + 0.9), 0.9, (255, 210, 60), rng)  # a beach ball
    lump((24.0, 9.0, z0 + deck + 0.8), 0.8, RED, rng)
    for i in range(4):  # steps up from the gate
        box((12.0, 1.0, deck * (4 - i) / 4), (0, -19.3 - i * 1.0, z0), tile_a, rng, kind=S.PALE)
    # the swimmers
    actor("creature_tortoise", (-12.0, 1.0, z0 + 0.35), 90)
    actor("creature_tortoise_gemshell", (7.0, 5.6, z0 + 0.3), -90)
    actor("creature_flamingo", (-20.5, 7.8, z0 + 0.5), 60)
    actor("creature_meerkat", (cx_, cy_, z0 + deck + 5.9), 180, scale=0.8)  # the lifeguard
    actor("creature_jackal", (tx - 6.4, ty, z0 + deck + 11.95 + 0.22), -90)  # on the top board


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


def mana(rng):
    yard(rng, "MAGIC LIBRARY", MANA, (72, 74, 104), kind=S.COOL)
    slate, pale = (82, 84, 118), (112, 116, 156)
    for band, (r0, r1, n) in enumerate(((0.0, 4.6, 8), (4.8, 10.4, 16), (10.6, 16.6, 24))):  # the floor: rings of slate
        for i in range(n):
            slab(r0, r1, i * 360 / n + 0.3, (i + 1) * 360 / n - 0.3, 0.25, 0.3, slate if (i + band) % 2 else pale, rng, centre=(0, 2), step=7.5, kind=S.COOL, chance=0.3)
    for i in range(24):  # the rune ring, and a star of gold inlay
        a = i * 15
        neon(prism([(-0.2, -0.75), (0.2, -0.75), (0.2, 0.75), (-0.2, 0.75)], Vector((0, 2, 0.56)) + polar(10.5, a), 0.05, MANA, rng, yaw=a), MANA, 2.2)
    for i in range(8):
        prism([(4.9, -0.5), (10.0, 0), (4.9, 0.5)], (0, 2, 0.55), 0.04, S.GOLD, rng, yaw=i * 45, chance=0.1)
    # the heart: a great crystal turning over an open book
    turn([(3.0, 0.0), (3.3, 0.5), (2.2, 0.9), (1.6, 2.6), (2.4, 3.2)], (0, 2, 0.55), (150, 152, 190), rng, n=10, kind=S.COOL)
    for side in (-1, 1):
        box((2.6, 3.4, 0.4), (side * 1.32, 2.0, 3.9), S.WHITE, rng, kind=S.PALE, tilt=(0, side * 12))
        box((2.8, 3.6, 0.2), (side * 1.36, 2.0, 3.72), (130, 60, 90), rng, tilt=(0, side * 12))
    for i, (h, w, off) in enumerate(((7.0, 2.2, (0, 0)), (4.0, 1.3, (1.6, 0.6)), (3.4, 1.1, (-1.5, -0.5)), (2.8, 0.9, (0.3, -1.6)), (2.6, 0.9, (-0.6, 1.5)))):
        base = Vector((off[0], 2 + off[1], 8.0 + i * 0.25))
        gem(base, base + Vector((off[0] * 0.25, off[1] * 0.25, h)), w, (MANA, (150, 120, 255))[i % 2], rng=rng)
        gem(base, base - Vector((off[0] * 0.1, off[1] * 0.1, h * 0.45)), w, (MANA, (150, 120, 255))[i % 2], rng=rng)
    for i in range(3):  # rings of light round it
        neon(S.k.ring(3.4 + i * 0.9, 9.0 + i * 1.5, 0.09, None, n=28, sides=5, centre=(0, 2)), (150, 120, 255), 2.0)
    for i in range(9):  # books adrift round the crystal
        a, r, zz = i * 40 + 12, 6.2 + (i % 3) * 1.1, 5.0 + (i * 1.7) % 5.5
        p = Vector((0, 2, zz)) + polar(r, a)
        box((1.5, 1.1, 0.34), p, ((170, 60, 70), (60, 110, 180), (220, 180, 80))[i % 3], rng, yaw=a * 2.3, tilt=(18, -14))
        neon(S.k.ico(0.16, (p.x, p.y, p.z - 0.3), subdiv=1), MANA, 2.5)
    # the shelves: a half ring of bookcases between columns under an arcade
    for i in range(7):
        if i == 3:  # the middle bay is the window's
            continue
        a = 30 + i * 20
        c = Vector((0, 2, 0.55)) + polar(21.0, a)
        shelf(rng, c, a - 90, tall=9.5 if i % 2 else 11.0)
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
    # an orrery, a telescope on a turret, an hourglass, desks and candles
    ox, oy = -21.0, -10.0
    turn([(1.8, 0.0), (1.2, 0.5), (0.4, 1.0), (0.3, 3.4)], (ox, oy, 0.25), S.GOLD, rng, n=10)
    neon(S.k.ico(0.9, (ox, oy, 4.6), subdiv=1), (255, 200, 90), 2.2)
    for i, (r, rgb, tilt) in enumerate(((2.2, (120, 170, 255), 12), (3.3, (255, 130, 110), -18), (4.5, (150, 230, 160), 26))):
        hoop = moved(S.k.ring(r, 0.0, 0.07, None, n=28, sides=5), Matrix.Translation((ox, oy, 4.6)) @ Matrix.Rotation(math.radians(tilt), 4, "X"))
        S.paint(hoop, S.GOLD, rng)
        q = Vector((ox, oy, 4.6)) + Vector((r * math.cos(i * 2.1), r * math.sin(i * 2.1) * math.cos(math.radians(tilt)), r * math.sin(i * 2.1) * math.sin(math.radians(tilt))))
        lump(q, 0.34 + 0.1 * i, rgb, rng)
    tx, ty = 23.0, 14.0
    post(4.0, 9.0, (tx, ty, 0.25), (150, 152, 190), rng, n=10, surface="rock", kind=S.COOL)
    post(4.5, 0.6, (tx, ty, 9.25), (196, 198, 226), rng, n=10, kind=S.COOL)
    turn([(4.2, 0.0), (3.7, 1.9), (2.2, 3.3), (0.0, 3.9)], (tx, ty, 9.85), (64, 80, 150), rng, n=10, kind=S.COOL)
    pipe([(tx - 1.0, ty - 1.0, 11.3), (tx - 5.4, ty - 5.2, 14.8)], [0.75, 0.5], S.GOLD, rng, n=8)
    neon(S.k.ico(0.42, (tx - 5.5, ty - 5.3, 14.9), subdiv=1), MANA, 1.6)
    for k in range(4):  # lit windows round the turret
        a = 200 + k * 25
        neon(S.k.box((0.9, 0.2, 1.6), tuple(Vector((tx, ty, 5.4)) + polar(3.9, a)), (0, 0, a + 90)), (255, 214, 130), 1.4)
    hx, hy = 21.0, -11.0
    for zz in (0.25, 5.25):
        post(1.5, 0.4, (hx, hy, zz), S.WOOD_DARK, rng, n=8)
    for a in range(0, 360, 90):
        post(0.14, 5.0, Vector((hx, hy, 0.45)) + polar(1.3, a + 45), S.WOOD_DARK, rng, n=5)
    turn([(1.15, 0.0), (0.16, 2.3), (1.15, 4.6)], (hx, hy, 0.65), (200, 226, 240), rng, n=10, kind=S.PALE)
    neon(S.k.cyl(0.95, 1.2, (hx, hy, 1.3), n=10, r2=0.3), (255, 214, 130), 1.2)
    for x, y, yaw in ((-10.0, -9.0, 20), (9.5, -9.5, -15)):
        spin([box((5.0, 2.4, 0.3), (x, y, 2.4), S.WOOD, rng)] + [box((0.4, 0.4, 2.2), (x + dx, y + dy, 0.25), S.WOOD_DARK, rng) for dx in (-2.1, 2.1) for dy in (-0.9, 0.9)], (x, y), yaw)
        for i in range(3):
            box((1.1, 0.8, 0.26), (x - 1.2 + i * 0.2, y + 0.2, 2.7 + i * 0.27), ((170, 60, 70), (60, 110, 180), (220, 180, 80))[i], rng, yaw=yaw + i * 12)
        post(0.1, 0.8, (x + 1.6, y, 2.7), S.WHITE, rng, n=5)
        neon(S.k.ico(0.2, (x + 1.6, y, 3.7), subdiv=1), (255, 200, 90), 3.0)
    for p in ((-30.0, -21.5), (30.0, -21.5), (-12.0, -18.0), (12.0, -18.0), (-29.0, 6.0), (29.0, 2.0)):
        post(0.2, 4.0, (*p, 0.25), (60, 60, 90), rng, n=6, kind=S.COOL)
        gem((p[0], p[1], 4.3), (p[0], p[1], 6.3), 0.9, MANA, 2.6, rng)
    for x, y in ((-27.0, 18.0), (-23.0, 21.0), (28.0, -8.0)):
        pine((x, y, 0.25), rng, 1.2)
    # a font of mana, low cases of scrolls along the sides, rugs to read on
    fx, fy = 14.0, -14.5
    turn([(2.6, 0.0), (2.9, 0.5), (2.0, 0.9), (1.5, 1.6), (2.8, 2.1), (3.0, 2.5), (2.6, 2.5)], (fx, fy, 0.25), (150, 152, 190), rng, n=10, kind=S.COOL)
    neon(S.k.cyl(2.6, 0.16, (fx, fy, 2.72), n=10), MANA, 2.0)
    for i in range(5):
        neon(S.k.ico(0.2 + 0.05 * i, (fx + math.cos(i * 1.9) * 1.2, fy + math.sin(i * 1.9) * 1.2, 3.4 + i * 0.6), subdiv=1), MANA, 2.6)
    for side in (-1, 1):
        for i in range(3):
            shelf(rng, (side * 27.0, -8.0 + i * 7.2, 0.25), -90 * side, tall=4.6)
    for x, y, yaw, rgb in ((-10.0, -9.0, 20, (150, 60, 90)), (9.5, -9.5, -15, (60, 80, 150)), (-16.0, -17.0, 8, (90, 60, 140))):
        box((8.6, 5.6, 0.06), (x, y, 0.25), rgb, rng, yaw=yaw, chance=0.08)
        box((7.6, 4.6, 0.07), (x, y, 0.25), S.GOLD, rng, yaw=yaw, chance=0.08)
        box((7.2, 4.2, 0.08), (x, y, 0.25), rgb, rng, yaw=yaw, chance=0.08)
    for i in range(4):  # cushions on the third rug
        lump((-18.4 + i * 1.6, -17.0 + (0.8 if i % 2 else -0.6), 0.6), (0.75, 0.75, 0.32), ((200, 80, 110), MANA, S.GOLD, (150, 120, 255))[i], rng)
    # the readers
    actor("creature_meerkat_storm", (-2.6, -1.4, 0.55), -25)
    actor("creature_jackal_pharaoh", (8.0, -5.0, 0.55), 40)
    actor("creature_flamingo", (-14.5, 4.0, 0.55), -70)


# Health ---------------------------------------------------------------------------------------------------


def pool(rng, at, r, depth=0.5):
    """A rock pool: a ring of boulders round warm water."""
    x, y, z = at
    disc(r, (x, y, z), depth, (96, 214, 206), rng, n=14, surface="gem", kind=S.COOL, emit=0.3, chance=0.06)
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


def health(rng):
    yard(rng, "HEALING SPRING", HEALTH, (126, 178, 96))
    # a hill of rock at the back, three pools stepping down it
    for i, (x, y, r, h) in enumerate(((2.0, 17.0, 13.0, 6.2), (-9.0, 15.0, 9.5, 4.4), (13.0, 14.0, 9.0, 4.0), (0.0, 8.0, 13.5, 2.6), (-14.0, 6.0, 8.0, 2.4), (15.0, 5.0, 8.5, 2.2))):
        lump((x, y, h * 0.45), (r, r * 0.8, h), (140, 134, 124), rng, surface="rock", kind=S.COOL)
    pool(rng, (2.0, 17.5, 6.4), 4.2)
    pool(rng, (0.5, 9.0, 3.6), 6.4)
    pool(rng, (0.0, -6.0, 0.3), 12.5, depth=0.45)
    for (x, y, z0, z1, w) in ((1.6, 13.0, 6.6, 4.0, 3.0), (0.2, 2.2, 3.8, 0.7, 4.6)):  # the falls between them
        for k in range(int(w / 0.5)):
            dx = -w / 2 + 0.25 + k * 0.5
            neon(S.k.tube([(x + dx, y + 0.9, z0), (x + dx, y, z0 - 0.3), (x + dx, y - 0.7, z1 + (z0 - z1) * 0.45), (x + dx, y - 1.0, z1)], [0.2, 0.24, 0.26, 0.3], n=5), (170, 236, 240) if k % 2 else (130, 220, 230), 0.8)
        lump((x, y - 1.2, z1 + 0.25), (w * 0.6, 0.9, 0.35), S.WHITE, rng, kind=S.PALE)
    for p in ((2.0, 17.5, 6.9), (0.5, 9.0, 4.1), (-5.0, -4.0, 0.8), (5.5, -8.5, 0.8), (0.0, -1.0, 0.8)):
        steam(rng, p)
    for i, (h, w, lean) in enumerate(((4.4, 1.5, (0, 0)), (2.6, 1.0, (1.1, 0.3)), (2.2, 0.9, (-0.9, 0.5)))):  # the source: a crystal of healing
        base = Vector((2.0 + lean[0], 20.6 + lean[1], 7.4))
        gem(base, base + Vector((lean[0] * 0.4, lean[1] * 0.4, h)), w, HEALTH, 2.4, rng)
    for i in range(9):  # stones in from the gate
        post(1.3, 0.14, (math.sin(i * 0.9) * 1.6, -22.5 + i * 0.95, 0.25), (176, 168, 156), rng, n=7, surface="rock", kind=S.COOL)
    for x in (-6.5, 6.5):  # a deck at the water's edge, towels on a rail
        box((5.0, 3.4, 0.4), (x, -19.6, 0.25), S.WOOD, rng)
        box((0.3, 0.3, 2.4), (x - 2.0, -20.8, 0.65), S.WOOD_DARK, rng)
        box((0.3, 0.3, 2.4), (x + 2.0, -20.8, 0.65), S.WOOD_DARK, rng)
        box((4.4, 0.2, 0.2), (x, -20.8, 2.9), S.WOOD_DARK, rng)
        for i, rgb in enumerate((S.WHITE, HEALTH, (255, 170, 200))):
            box((1.1, 0.3, 1.5), (x - 1.4 + i * 1.4, -20.8, 1.5), rgb, rng)
    # lilies and lotus on the low pool, stepping stones across it
    for i in range(10):
        a, r = rng.uniform(0, 360), rng.uniform(4.0, 11.0)
        p = Vector((0, -6.0, 0.78)) + polar(r, a)
        post(rng.uniform(0.6, 1.0), 0.06, p, (70, 150, 84), rng, n=7)
        if i % 2:
            for j in range(6):
                shard(p + Vector((0, 0, 0.06)), p + polar(0.55, j * 60, 0.6), 0.32, 0.1, (255, 170, 200), rng)
    for i in range(7):
        post(1.0, 0.5, (-9.0 + i * 3.0, -6.0 + 1.6 * math.sin(i * 1.1), 0.45), (168, 160, 150), rng, n=7, surface="rock", kind=S.COOL)
    # glowing herbs and crystals of healing among the rocks
    for i in range(16):
        a, r = rng.uniform(0, 360), rng.uniform(13.2, 15.5)
        p = Vector((0, -6.0, 0.3)) + polar(r, a)
        if p.y > 4:
            continue
        for k in range(3):
            base = p + polar(0.4, k * 120)
            gem(base, base + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0.9, 1.8))), 0.4, HEALTH, 2.2, rng)
    # bamboo pipes that pour, a bath house, a bridge, lanterns
    for x, y, yaw in ((-10.5, 0.5, -30), (11.5, -1.0, 210)):
        post(0.2, 2.6, (x, y, 0.3), (120, 180, 90), rng, n=6)
        tip = Vector((x, y, 2.7)) + polar(2.6, yaw, -0.5)
        pipe([(x, y, 2.9), tuple(tip)], 0.22, (120, 180, 90), rng, n=6)
        neon(S.k.tube([tuple(tip), tuple(tip + polar(0.5, yaw, -1.0)), tuple(tip + polar(0.7, yaw, -2.0))], [0.12, 0.14, 0.18], n=5), (170, 236, 240), 0.8)
    bx, by = -22.5, 12.0
    box((11.0, 9.0, 0.7), (bx, by, 0.25), S.WOOD, rng)
    for dx in (-4.8, 4.8):
        for dy in (-3.8, 3.8):
            box((0.6, 0.6, 6.0), (bx + dx, by + dy, 0.95), S.WOOD_DARK, rng)
    roof(13.5, 11.5, 3.6, (bx, by, 6.95), (70, 120, 100), rng, ridge=5.0)
    box((9.6, 0.3, 3.0), (bx, by + 3.8, 0.95), (236, 228, 208), rng, kind=S.PALE)
    for i in range(3):
        box((2.2, 0.9, 0.5), (bx - 3.0 + i * 3.0, by + 2.4, 0.95), S.WOOD, rng)
        box((1.6, 0.7, 0.3), (bx - 3.0 + i * 3.0, by + 2.4, 1.45), (S.WHITE, HEALTH, (255, 170, 200))[i], rng)
    barrel((bx + 3.6, by - 2.0, 0.95), rng)
    barrel((bx + 2.0, by - 2.6, 0.95), rng, (120, 180, 90))
    for i in range(9):  # an arched bridge over the outflow
        t = i / 8
        x = 14.0 + (t - 0.5) * 9.0
        zz = 0.5 + 1.5 * math.sin(math.pi * t)
        box((1.15, 3.6, 0.3), (x, -17.0, zz), S.WOOD, rng, tilt=(0, -math.degrees(math.atan(1.5 * math.pi / 9.0 * math.cos(math.pi * t)))))
        for sy in (-1.8, 1.8):
            post(0.12, 1.4, (x, -17.0 + sy, zz + 0.3), RED, rng, n=5)
    for sy in (-1.8, 1.8):
        pipe([(14.0 + (i / 8 - 0.5) * 9.0, -17.0 + sy, 2.2 + 1.5 * math.sin(math.pi * i / 8)) for i in range(9)], 0.12, RED, rng, n=5)
    box((9.4, 2.6, 0.2), (14.0, -17.0, 0.25), (96, 214, 206), rng, surface="gem", kind=S.COOL, emit=0.3)
    for p in ((-15.0, -12.0), (15.5, -9.5), (-6.5, 4.5), (8.0, 3.0), (-17.5, 3.0), (21.0, -19.0), (7.0, -19.5)):
        stone_lantern((*p, 0.25), rng)
    # a herb garden in rows, blossom trees, bamboo at the back
    for row in range(4):
        box((10.0, 1.3, 0.4), (-23.0, -8.0 - row * 2.4, 0.25), (120, 88, 60), rng)
        for i in range(8):
            p = (-27.4 + i * 1.25, -8.0 - row * 2.4, 0.65)
            lump((p[0], p[1], p[2] + 0.3), (0.42, 0.42, 0.36), (86, 160, 84), rng)
            if (i + row) % 2:
                lump((p[0], p[1], p[2] + 0.72), 0.2, ((255, 170, 200), (255, 224, 90), (190, 150, 255), S.WHITE)[row], rng)
    for x, y in ((-29.0, 21.0), (27.0, 20.0), (24.0, -4.0), (-28.5, -3.0)):
        tree((x, y, 0.25), rng, rng.uniform(0.85, 1.1), leaf=(244, 160, 186))
    for x, y in ((-14.0, 21.5), (-18.0, 20.0), (17.0, 21.5), (21.0, 19.5), (29.0, 9.0)):
        bamboo((x, y, 0.25), rng)
    spin(bench((24.5, -13.0, 0.25), rng), (24.5, -13.0), 100)
    for _ in range(14):
        flowers((rng.uniform(-30, 30), rng.uniform(-22, -15), 0.25), rng, n=5, spread=1.0)
    # the bathers
    actor("creature_tortoise_gemshell", (-4.0, -7.5, 0.35), 150)
    actor("creature_flamingo", (6.5, -3.5, 0.5), -40)
    actor("creature_rhino", (-1.0, 9.0, 3.5), 170, scale=0.8)
    actor("creature_meerkat", (-20.5, 9.5, 0.95), 200)


# Defence --------------------------------------------------------------------------------------------------


def log_wall(a, b, rng, h=7.0):
    """A palisade from a to b: pointed logs side by side."""
    a, b = Vector(a), Vector(b)
    n = max(1, round((b - a).length / 1.25))
    for i in range(n + 1):
        p = a.lerp(b, i / n)
        hh = h + rng.uniform(-0.5, 0.5)
        post(0.62, hh, p, (150, 104, 64), rng, n=6)
        post(0.62, 1.2, (p.x, p.y, p.z + hh), (176, 128, 82), rng, n=6, r2=0.0)
    mid = (a + b) / 2
    yaw = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
    box(((b - a).length, 1.5, 0.45), (mid.x, mid.y, mid.z + h * 0.62), IRON, rng, yaw=yaw)


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


def tower(at, rng, colour):
    x, y, z = at
    for dx in (-2.6, 2.6):
        for dy in (-2.6, 2.6):
            post(0.6, 13.0, (x + dx, y + dy, z), (150, 104, 64), rng, n=6)
    for zz in (4.0, 8.0):
        for dx, dy, w, d in ((0, -2.6, 5.8, 0.4), (0, 2.6, 5.8, 0.4), (-2.6, 0, 0.4, 5.8), (2.6, 0, 0.4, 5.8)):
            box((w, d, 0.5), (x + dx, y + dy, z + zz), S.WOOD_DARK, rng)
    box((7.4, 7.4, 0.5), (x, y, z + 10.5), S.WOOD, rng)
    for dx, dy, w, d in ((0, -3.6, 7.4, 0.3), (0, 3.6, 7.4, 0.3), (-3.6, 0, 0.3, 7.4), (3.6, 0, 0.3, 7.4)):
        box((w, d, 1.6), (x + dx, y + dy, z + 11.0), (150, 104, 64), rng)
    roof(9.0, 9.0, 3.6, (x, y, z + 15.0), (120, 70, 50), rng)
    for dx in (-3.3, 3.3):
        for dy in (-3.3, 3.3):
            post(0.3, 4.0, (x + dx, y + dy, z + 11.0), S.WOOD_DARK, rng, n=5)
    post(0.14, 4.0, (x, y, z + 18.4), S.WOOD_DARK, rng, n=5)
    flag((x + 1.0, y, z + 22.3), 2.0, 2.8, colour, rng)
    flag((x, y - 3.78, z + 10.2), 2.4, 5.0, colour, rng)


def defence(rng):
    yard(rng, "GUARD YARD", DEFENCE, (206, 180, 132))
    # a palisade round the drill ground, a tower at each front corner
    x0, x1, y0, y1 = -27.0, 27.0, -15.0, 20.0
    log_wall((x0, y0, 0.25), (-9.5, y0, 0.25), rng)
    log_wall((9.5, y0, 0.25), (x1, y0, 0.25), rng)
    log_wall((x0, y0, 0.25), (x0, y1, 0.25), rng)
    log_wall((x1, y0, 0.25), (x1, y1, 0.25), rng)
    log_wall((x0, y1, 0.25), (x1, y1, 0.25), rng)
    tower((-9.5, y0, 0.25), rng, DEFENCE)
    tower((9.5, y0, 0.25), rng, DEFENCE)
    box((14.0, 1.2, 1.2), (0, y0, 9.0), S.WOOD_DARK, rng)  # the beam over the gate
    for sx in (-1, 1):  # the gates, standing open
        box((0.5, 6.4, 7.6), (sx * 6.6, y0 + 3.4, 0.25), (150, 104, 64), rng, yaw=sx * 12)
        for zz in (1.6, 5.6):
            box((0.6, 6.4, 0.5), (sx * 6.6, y0 + 3.4, zz), IRON, rng, yaw=sx * 12)
    # a rank of straw men behind shields
    for i in range(6):
        dummy((-20.0 + i * 5.0, 14.0, 0.25), 0, rng, DEFENCE if i % 2 else (210, 70, 60))
    # the ram: a log slung from a frame, swung at a braced wall of shields
    rx, ry = -15.0, -1.0
    for sx in (-4.5, 4.5):
        for sy in (-2.6, 2.6):
            pipe([(rx + sx, ry + sy * 1.5, 0.25), (rx + sx, ry + sy * 0.2, 8.6)], 0.34, (150, 104, 64), rng, n=6)
    box((10.2, 0.8, 0.8), (rx, ry, 8.4), S.WOOD_DARK, rng)
    post(1.0, 9.0, (rx - 4.5, ry, 3.6), (156, 108, 66), rng, n=8, rot=(0, 90, 0))
    post(1.15, 1.2, (rx + 4.5, ry, 3.6), IRON, rng, n=8, rot=(0, 90, 0), kind=S.COOL)
    for sx in (-3.0, 3.0):
        pipe([(rx + sx, ry, 8.4), (rx + sx, ry, 4.5)], 0.1, IRON, rng, n=4)
    for i in range(4):
        shield((rx + 8.2, ry - 3.0 + i * 2.0, 0.25), -90, rng, DEFENCE if i % 2 else (210, 70, 60), tall=4.0, wide=1.9)
    for i in range(3):
        pipe([(rx + 8.6, ry - 2.0 + i * 2.0, 2.6), (rx + 11.4, ry - 2.0 + i * 2.0, 0.3)], 0.2, S.WOOD_DARK, rng, n=5)
    # the thrower: an arm that lobs sacks at a wall of shields
    tx, ty = 14.0, 3.0
    box((7.0, 3.6, 0.6), (tx, ty, 0.25), S.WOOD_DARK, rng)
    for sy in (-1.5, 1.5):
        pipe([(tx - 1.5, ty + sy, 0.8), (tx, ty + sy, 4.8), (tx + 1.5, ty + sy, 0.8)], 0.26, (150, 104, 64), rng, n=6)
        post(1.0, 0.5, (tx - 3.0, ty + sy * 1.3 - 0.25, 1.0), S.WOOD, rng, n=10, rot=(90, 0, 0))
        post(1.0, 0.5, (tx + 3.0, ty + sy * 1.3 - 0.25, 1.0), S.WOOD, rng, n=10, rot=(90, 0, 0))
    pipe([(tx, ty - 1.7, 4.8), (tx, ty + 1.7, 4.8)], 0.2, IRON, rng, n=6)
    pipe([(tx + 2.2, ty, 2.4), (tx - 4.6, ty, 8.6)], [0.4, 0.26], (156, 108, 66), rng, n=6)
    turn([(0.3, 0.0), (0.95, 0.45), (1.0, 0.8)], (tx - 4.8, ty, 8.3), S.WOOD_DARK, rng, n=8)
    lump((tx - 4.8, ty, 9.3), 0.72, (190, 170, 130), rng)
    box((1.6, 1.6, 1.6), (tx + 2.6, ty, 1.3), IRON, rng, kind=S.COOL)
    for i in range(6):
        lump((tx + 5.4 + (i % 3) * 1.3, ty - 2.6 + (i // 3) * 1.3, 0.25 + 0.55), (0.62, 0.62, 0.5), (190, 170, 130), rng)
    # barricades: sandbags, and crossed stakes
    for bx, by, n in ((0.0, -10.0, 7), (18.0, -9.0, 5), (-3.0, 6.0, 5)):
        for row in range(3):
            for i in range(n - row):
                lump((bx - (n - row) * 0.9 + i * 1.8 + 0.9, by, 0.25 + 0.45 + row * 0.8), (0.95, 0.6, 0.45), (196, 176, 136), rng)
    for bx, by in ((22.0, 14.0), (-22.0, -9.0)):
        pipe([(bx - 3.6, by, 1.4), (bx + 3.6, by, 1.4)], 0.3, S.WOOD_DARK, rng, n=6)
        for i in range(6):
            x = bx - 3.0 + i * 1.2
            for side in (-1, 1):
                pipe([(x, by - 1.6 * side, 0.25), (x, by + 1.6 * side, 3.0)], [0.2, 0.02], (176, 128, 82), rng, n=5)
    # racks of shields and armour, braziers, a drum
    for i in range(5):
        shield((21.5, -11.5 + i * 2.2 - 0.0, 0.9), 90, rng, (DEFENCE, (210, 70, 60), SPEED, HEALTH, S.GOLD)[i], tall=2.8, wide=1.8)
    box((1.0, 11.5, 0.7), (22.6, -7.2, 0.25), S.WOOD_DARK, rng)
    for i in range(3):
        x = -22.0 + i * 3.0
        post(0.16, 3.6, (x, 5.5, 0.25), S.WOOD_DARK, rng, n=5)
        box((2.2, 0.3, 0.3), (x, 5.5, 3.2), S.WOOD_DARK, rng)
        lump((x, 5.5, 2.5), (0.95, 0.6, 1.0), IRON, rng, kind=S.COOL)
        post(0.6, 0.5, (x, 5.5, 3.9), IRON, rng, n=8, r2=0.4, kind=S.COOL)
    for p in ((-24.5, -12.5), (24.5, -12.5), (-24.5, 17.5), (24.5, 17.5), (-5.5, -18.5), (5.5, -18.5)):
        brazier((*p, 0.25), rng)
    post(1.5, 2.0, (4.0, 16.5, 0.25), (150, 60, 50), rng, n=10)
    post(1.56, 0.2, (4.0, 16.5, 2.25), (236, 226, 200), rng, n=10, kind=S.PALE)
    for i in range(4):
        bunting((-26.0 + i * 13.5, 19.6, 8.5), (-12.5 + i * 13.5, 19.6, 8.5), 1.2, rng, (DEFENCE, S.WHITE, (210, 70, 60)), n=9, size=1.0)
    # the guards
    actor("creature_rhino", (rx + 16.2, ry, 0.25), -90, scale=0.85)  # braced behind the shield wall
    actor("creature_tortoise", (0.0, -6.8, 0.25), 180)
    actor("creature_lion", (15.0, 13.0, 0.25), 200)
    actor("creature_meerkat", (-9.5, -15.0, 11.25), 180, scale=0.8)  # on watch


def shots(low, a, b, hero=((-46, -68, 40), (0, 0, 3), 34)):
    """A hero from the south-west, then three closer looks."""
    return [hero, low, a, b]


SCENES = [
    dict(name="train_speed", build=speed, shots=shots(((-30, -30, 5), (4, -8, 4), 28), ((18, -22, 6), (4, -9, 5), 30), ((30, -4, 12), (0, 8, 3), 30))),
    dict(name="train_strength", build=strength, shots=shots(((-34, -6, 5), (-17, 12, 5), 28), ((-27, -22, 5), (-8, -12, 3), 30), ((31, 3, 9), (12, 15, 2), 28))),
    dict(name="train_stamina", build=stamina, shots=shots(((-36, -12, 7), (-8, 2, 2), 28), ((30, -14, 9), (14, 4, 6), 28), ((-17, -4, 7), (4, 13, 6), 24))),
    dict(name="train_mana", build=mana, shots=shots(((-4, -22, 5), (0, 4, 8), 24), ((-20, -18, 6), (-6, 10, 7), 28), ((24, -20, 8), (8, 4, 6), 28))),
    dict(name="train_health", build=health, shots=shots(((-3, -21, 4.5), (0, 4, 4), 24), ((20, -22, 5), (4, -4, 2), 30), ((-8, -18, 6), (-21, 8, 3), 26))),
    dict(name="train_defence", build=defence, shots=shots(((0, -40, 6), (0, -12, 6), 24), ((-22, -11, 6), (-12, 3, 4), 26), ((22, -9, 7), (6, 8, 3), 26), hero=((-38, -58, 56), (0, 3, 2), 34))),
]
