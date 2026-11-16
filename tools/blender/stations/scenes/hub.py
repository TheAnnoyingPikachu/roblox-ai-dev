"""The hub's centre, finished (concept, decision 0059): the Hatchery Fountain with the Golden Egg on a
lotus above two pools, a sunburst of paving, a ring of statues of the eight animals, a shrine for each
of the four eggs, raised gardens, lamps strung with flags and a gateway on each of the four roads.
The plaza keeps its size (48 studs to its kerb, World.PLAZA), so it fits where the plain one stands.
"""

import math

import stage as S
from mathutils import Vector
from stage import actor, bench, box, bunting, bush, disc, face_in, flag, flowers, lantern, lump, neon, pine, pipe, polar, post, prism, rock, roof, shard, slab, spin, tree, turn, words

SPECIES = ("jackal", "tortoise", "meerkat", "cheetah", "rhino", "flamingo", "lion", "elephant")
EGGS = (("meadow", (124, 196, 108)), ("wild", (58, 128, 84)), ("safari", (226, 146, 66)), ("golden", (250, 196, 60)))
SUN_A, SUN_B = (240, 178, 66), (224, 118, 66)
TEAL = (64, 158, 166)
PARTY = ((240, 80, 80), (250, 190, 60), (90, 200, 120), (80, 160, 240), (190, 120, 240))


def paving(rng):
    for i in range(48):  # the kerb
        slab(46.6, 48.5, i * 7.5 + 0.15, (i + 1) * 7.5 - 0.15, 0.0, 0.55, S.STONE_DARK, rng, surface="rock", kind=S.COOL)
    for band, (r0, r1) in enumerate(((17.1, 26.9), (27.9, 36.5), (37.5, 46.5))):  # three rings of slabs, laid like bricks
        n = (20, 28, 36)[band]
        for i in range(n):
            a = (i + 0.5 * (band % 2)) * 360 / n
            tint = S.SAND if (i + band) % 2 else (236, 220, 184)
            slab(r0, r1, a + 0.22, a + 360 / n - 0.22, 0.0, 0.3, tint, rng, kind=S.PALE, chance=0.35)
    for r0, r1, n in ((27.0, 27.8, 72), (36.6, 37.4, 96)):  # two bands of small tiles
        for i in range(n):
            slab(r0, r1, i * 360 / n + 0.3, (i + 1) * 360 / n - 0.3, 0.0, 0.33, TEAL if i % 2 else S.WHITE, rng, chance=0.3)
    for i in range(48):  # the mosaic round the fountain
        slab(15.1, 17.0, i * 7.5 + 0.2, (i + 1) * 7.5 - 0.2, 0.0, 0.34, (TEAL, S.GOLD, S.WHITE)[i % 3], rng, chance=0.3)
    for i in range(16):  # the sunburst: long rays, short rays between them
        a, long = i * 22.5, i % 2 == 0
        tip, half = (35.5 if long else 26.0), (2.0 if long else 1.4)
        prism([(17.3, -half), (tip, 0), (17.3, half)], (0, 0, 0.3), 0.06, SUN_A if long else SUN_B, rng, yaw=a, chance=0.1)


def fountain(rng, cast=True):
    """`cast`: with the Golden Egg and the four stone tortoises (the game stands its own on the model)."""
    for i in range(16):  # the lower basin: a wall of sixteen stones under a lip, a gold boss on each
        a0, a1 = i * 22.5 + 0.25, (i + 1) * 22.5 - 0.25
        slab(13.4, 15.0, a0, a1, 0.3, 1.5, S.MARBLE, rng, kind=S.PALE)
        slab(13.1, 15.4, a0, a1, 1.8, 0.35, S.STONE, rng, kind=S.PALE)
        lump(polar(15.05, i * 22.5 + 11.25, 1.05), (0.22, 0.42, 0.42), S.GOLD, rng)
    disc(13.4, (0, 0, 0.3), 1.05, S.WATER, rng, n=32, surface="gem", kind=S.COOL, emit=0.25, chance=0.08)
    for i in range(11):  # lily pads, some in flower, and a few koi
        a, r = rng.uniform(0, 360), rng.uniform(9.6, 12.6)
        p = polar(r, a, 1.36)
        post(rng.uniform(0.55, 0.9), 0.06, p, (70, 150, 84), rng, n=7)
        if i % 2 == 0:
            for j in range(6):
                shard(p + Vector((0, 0, 0.06)), p + polar(0.5, j * 60, 0.55), 0.3, 0.1, (255, 170, 200), rng)
            lump(p + Vector((0, 0, 0.3)), 0.14, (255, 224, 90), rng)
    for i in range(7):
        a, r = rng.uniform(0, 360), rng.uniform(9.8, 12.4)
        p, q = polar(r, a, 1.34), polar(r, a + 8, 1.34)
        shard(p, q, 0.5, 0.2, ((255, 140, 50), S.WHITE, (250, 200, 70))[i % 3], rng, face=(0, 0, 1))
    # the stem and the upper bowl
    turn([(7.2, 0.0), (7.4, 0.7), (5.4, 1.3), (4.2, 3.0), (4.0, 4.4), (4.8, 5.2), (7.0, 5.9), (9.0, 6.4), (9.3, 6.9), (8.7, 6.9), (8.5, 6.5)], (0, 0, 0.3), S.MARBLE, rng, n=16, kind=S.PALE)
    for z, r in ((1.75, 5.45), (4.75, 4.2)):
        turn([(r, 0), (r + 0.25, 0.14), (r, 0.28)], (0, 0, z), S.GOLD, rng, n=16)
    disc(8.7, (0, 0, 6.6), 0.42, S.WATER, rng, n=32, surface="gem", kind=S.COOL, emit=0.25, chance=0.08)
    for i in range(16):  # gold leaves under the bowl's rim, and eight spouts of water from it
        a = i * 22.5
        shard(polar(8.9, a, 6.9), polar(10.3, a, 5.5), 1.5, 0.3, S.GOLD, rng, face=polar(1, a))
        if i % 2 == 0:
            pts = [polar(9.2 + 2.6 * t, a + 11.25, 7.0 + 1.3 * t - 7.0 * t * t) for t in [j / 10 for j in range(11)]]
            neon(S.k.tube(pts, [0.34 - 0.1 * abs(j - 5) / 5 for j in range(11)], n=6), (150, 220, 255), 0.9)
            lump(polar(11.8, a + 11.25, 1.4), (0.9, 0.9, 0.25), S.WHITE, rng)  # where it lands
    for i in range(4):  # four stone tortoises on the lip spit into the pool
        a = 45 + i * 90
        if cast:
            actor("creature_tortoise", polar(14.2, a, 2.15), face_in(a), statue=S.MARBLE, rng=rng, fit=2.6, surface=None)
        pts = [polar(13.0 - 2.4 * t, a, 3.1 + 1.2 * t - 3.0 * t * t) for t in [j / 8 for j in range(9)]]
        neon(S.k.tube(pts, 0.13, n=5), (150, 220, 255), 0.9)
    # the lotus and the Golden Egg
    turn([(3.4, 0.0), (4.6, 0.5), (4.2, 1.0), (2.9, 1.5), (2.7, 2.3)], (0, 0, 6.9), S.GOLD, rng, n=12)
    for ring, (n, r0, r1, z0, z1, w) in enumerate(((12, 2.8, 6.2, 8.2, 9.6, 2.4), (12, 2.6, 4.9, 8.6, 11.2, 2.0))):
        for i in range(n):
            a = (i + 0.5 * ring) * 360 / n
            shard(polar(r0, a, z0), polar(r1, a, z1), w, 0.4, ((255, 190, 214), (255, 228, 236))[ring], rng, face=polar(1, a), at=0.45)
    if cast:
        actor("egg_golden", (0, 0, 9.0), 0, scale=13 / 3.54)


def plinth(rng, a):
    """A statue's plinth at angle `a` round the fountain, its name plate on the outer side. Returns its foot."""
    p = polar(24.5, a)
    post(3.5, 0.6, p, S.STONE_DARK, rng, n=8, rot=(0, 0, a + 22.5), surface="rock", kind=S.COOL)
    post(2.9, 2.3, p + Vector((0, 0, 0.6)), S.MARBLE, rng, n=8, rot=(0, 0, a + 22.5), kind=S.PALE)
    post(3.0, 0.26, p + Vector((0, 0, 1.9)), S.GOLD, rng, n=8, rot=(0, 0, a + 22.5))
    post(3.25, 0.4, p + Vector((0, 0, 2.9)), S.STONE, rng, n=8, rot=(0, 0, a + 22.5), kind=S.PALE)
    box((1.7, 0.16, 0.8), polar(24.5 + 2.76, a, 0.95), S.GOLD, rng, yaw=a + 90)  # its name plate
    for j in range(5):  # flowers at its foot
        flowers(p + polar(4.3, a + 140 + j * 20), rng, n=4, spread=0.6)
    return p


def statues(rng):
    for i, species in enumerate(SPECIES):
        a = 22.5 + 45 * i
        actor(f"creature_{species}", plinth(rng, a) + Vector((0, 0, 3.3)), a + 90, statue=(238, 232, 220), rng=rng, fit=6.2, surface=None)


def shrine(rng, at, a, egg, tiles):
    """A round shrine for one egg: six columns under a tiled cone, the egg on a stand (None: an empty stand)."""
    x, y, z = at
    disc(4.3, at, 0.35, S.STONE_DARK, rng, n=12, surface="rock", kind=S.COOL)
    disc(3.9, (x, y, z + 0.35), 0.3, S.MARBLE, rng, n=12, kind=S.PALE)
    for j in range(6):
        c = Vector(at) + polar(3.2, j * 60 + 30, 0.65)
        post(0.5, 0.35, c, S.STONE, rng, n=8, kind=S.PALE)
        post(0.34, 4.6, c + Vector((0, 0, 0.35)), S.MARBLE, rng, n=8, kind=S.PALE)
        post(0.52, 0.3, c + Vector((0, 0, 4.95)), S.GOLD, rng, n=8)
    slab(2.7, 3.8, 0, 360, z + 5.9, 0.55, S.MARBLE, rng, centre=(x, y), step=30, kind=S.PALE)
    post(4.5, 2.9, (x, y, z + 6.45), tiles, rng, n=12, r2=0.5)
    for j in range(12):  # ribs down the cone
        pipe([Vector(at) + polar(4.55, j * 30, 6.45), Vector(at) + polar(0.5, j * 30, 9.35)], 0.12, S.GOLD, rng, n=4)
    lump((x, y, z + 9.6), 0.45, S.GOLD, rng)
    turn([(1.3, 0.0), (1.0, 0.4), (1.15, 1.1)], (x, y, z + 0.65), S.STONE, rng, n=10, kind=S.PALE)
    if egg:
        actor(f"egg_{egg}", (x, y, z + 1.75), a + 90, scale=0.92)


def garden(rng, q):
    """The raised garden of quarter `q` (0: north-east, then round to the left), without its shrine."""
    q0 = q * 90
    slab(38.3, 45.9, q0 + 11.5, q0 + 78.5, 0.3, 0.75, S.STONE, rng, kind=S.PALE)  # the bed's wall
    slab(38.8, 45.4, q0 + 12.3, q0 + 77.7, 0.6, 0.55, (96, 162, 80), rng, step=4, chance=0.3)  # its lawn
    for a in (22, 45, 68):
        tree(polar(42.2, q0 + a, 1.1), rng, s=rng.uniform(0.85, 1.05), leaf=((76, 150, 72), (110, 170, 70), (236, 150, 170))[(q + a) % 3])
    for _ in range(9):
        a, r = q0 + rng.uniform(14, 76), rng.uniform(39.8, 44.6)
        if rng.random() < 0.45:
            bush(polar(r, a, 1.1), rng, s=rng.uniform(0.6, 0.9))
        else:
            flowers(polar(r, a, 1.15), rng, n=9, spread=1.3)
    rock(polar(44.0, q0 + 33, 1.1), rng, 0.8)
    lamps = []
    for a in (16, 36, 54, 74):  # lamps on the wall, their lanterns over the walk
        p = polar(37.6, q0 + a, 0.3)
        spin(lantern(p, rng, h=6.4), p, q0 + a + 180)
        lamps.append(p + Vector((0, 0, 6.9)))
    for a, b in zip(lamps, lamps[1:]):
        bunting(a, b, 1.1, rng, PARTY, n=8)
    for a in (26, 64):
        p = polar(34.4, q0 + a, 0.3)
        bench(p, rng, face_in(q0 + a))
        for side in (-1, 1):  # a stone planter at each end of the bench
            c = p + polar(3.4, q0 + a + 90 * side)
            turn([(0.8, 0.0), (1.1, 0.9), (1.0, 1.1)], c, S.STONE, rng, n=8, kind=S.PALE)
            flowers(c + Vector((0, 0, 1.0)), rng, n=6, spread=0.6)


def gardens(rng):
    for q in range(4):
        garden(rng, q)
        egg, tiles = EGGS[q]
        shrine(rng, polar(32.2, q * 90 + 45, 0.3), q * 90 + 45, egg, tiles)


def gateway(rng, a, name, sign, banner, glow, half=7.0, road=True):
    """A gateway across a road: two stone piers with lanterns `half` studs either side of its middle, a
    roofed beam and a hanging board. `road`: with a stretch of the road it stands on."""
    mid = polar(50.5, a)
    for side in (-1, 1):
        c = mid + polar(half, a + 90 * side)
        box((2.8, 2.8, 1.0), c, S.STONE_DARK, rng, yaw=a, surface="rock", kind=S.COOL)
        box((2.2, 2.2, 8.4), c + Vector((0, 0, 1.0)), S.STONE, rng, yaw=a, surface="rock", kind=S.PALE)
        box((2.8, 2.8, 0.6), c + Vector((0, 0, 9.4)), S.MARBLE, rng, yaw=a, kind=S.PALE)
        neon(S.k.cyl(0.7, 1.3, (c.x, c.y, 10.9), n=6), glow)
        post(0.95, 0.45, c + Vector((0, 0, 11.55)), S.INK, rng, n=6, r2=0.15)
        flag(c + polar(1.16, a + 180, 8.6), 1.7, 5.2, banner, rng, yaw=a + 90)
        flag(c + polar(1.16, a, 8.6), 1.7, 5.2, banner, rng, yaw=a + 90)
    box((2 * half + 4.4, 1.6, 1.3), mid + Vector((0, 0, 10.0)), S.WOOD_DARK, rng, yaw=a + 90)
    roof(2 * half + 6.0, 3.4, 2.2, mid + Vector((0, 0, 11.3)), (176, 70, 60), rng, yaw=a + 90, ridge=2 * half + 6.0)
    box((9.5, 0.35, 2.2), mid + Vector((0, 0, 7.2)), sign, rng, yaw=a + 90)
    box((10.1, 0.25, 2.8), mid + Vector((0, 0, 6.9)), S.GOLD, rng, yaw=a + 90)
    for face in (-1, 1):  # where the road leads, on both sides
        words(name, mid + polar(0.2 * face, a) + Vector((0, 0, 8.3)), 1.25, S.WHITE, yaw=a + 90 * face)
    for side in (-1, 1):
        c = mid + polar(3.6, a + 90 * side)
        pipe([c + Vector((0, 0, 10.0)), c + Vector((0, 0, 9.4))], 0.07, S.INK, rng, n=4)
    if not road:
        return
    way = polar(72.5, a)
    box((45.0, 10.5, 0.14), way, (206, 190, 160), rng, yaw=a, kind=S.PALE)
    for side in (-1, 1):
        box((45.0, 0.6, 0.3), way + polar(5.5, a + 90 * side), S.STONE_DARK, rng, yaw=a, surface="rock", kind=S.COOL)


def stall(rng, at, yaw, stripe):
    """A market stall with a striped awning; its counter faces local -Y."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def p(x, y, z):
        return (at[0] + x * c - y * s, at[1] + x * s + y * c, at[2] + z)

    box((8.0, 5.0, 0.35), p(0, 0, 0), S.WOOD, rng, yaw)
    box((7.6, 1.4, 2.6), p(0, -1.6, 0.35), S.WOOD_DARK, rng, yaw)
    box((8.0, 1.8, 0.3), p(0, -1.6, 2.95), S.WOOD, rng, yaw)
    for sx in (-3.7, 3.7):
        for sy in (-2.2, 2.2):
            box((0.4, 0.4, 6.6), p(sx, sy, 0.35), S.WOOD_DARK, rng, yaw)
    for i in range(8):
        box((1.0, 6.4, 0.22), p(-3.5 + i, -0.4, 6.4), stripe if i % 2 else S.WHITE, rng, yaw, tilt=(-12, 0))
    for i in range(5):  # wares on the counter
        lump(p(-3.0 + i * 1.5, -1.6, 3.55), (0.42, 0.42, 0.52), ((250, 240, 200), (150, 210, 120), (245, 200, 110), S.GOLD, (190, 150, 255))[i], rng)


def surroundings(rng):
    for i in range(30):  # the mountains round the hub, snow on the tall ones
        a, r = i * 12 + rng.uniform(-3, 3), rng.uniform(250, 300)
        foot, tall = rng.uniform(52, 84), rng.uniform(70, 130)
        post(foot, tall, polar(r, a), (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        if tall > 92:
            post(foot * 0.36, tall * 0.28, polar(r, a, tall * 0.74), S.WHITE, rng, n=7, r2=foot * 0.1, rot=(0, 0, rng.uniform(0, 50)), kind=S.PALE)
    for _ in range(230):
        a, r = rng.uniform(0, 360), rng.uniform(54, 200)
        off = min(abs((a - road + 180) % 360 - 180) for road in (0, 90, 180, 270))
        if math.radians(off) * r < 10:  # keep the roads clear
            continue
        p = polar(r, a)
        roll = rng.random()
        if roll < 0.5:
            tree(p, rng, s=rng.uniform(0.9, 1.4))
        elif roll < 0.72:
            pine(p, rng, s=rng.uniform(1.0, 1.5))
        elif roll < 0.9:
            bush(p, rng, s=rng.uniform(0.8, 1.3))
        else:
            rock(p, rng, rng.uniform(0.9, 1.8))
    for _ in range(40):
        a, r = rng.uniform(0, 360), rng.uniform(50, 80)
        if min(abs((a - road + 180) % 360 - 180) for road in (0, 90, 180, 270)) > 9:
            flowers(polar(r, a), rng, n=6, spread=1.4)


def build(rng):
    disc(48.4, (0, 0, -0.3), 0.5, (112, 106, 100), rng, n=64)  # the bed the slabs lie in: it shows in the joints
    paving(rng)
    fountain(rng)
    statues(rng)
    gardens(rng)
    gateway(rng, 90, "WAVE ARENA", (64, 40, 104), (88, 52, 140), (150, 255, 70))  # north: the wave arena, in the Hexbound's colours
    gateway(rng, 270, "WELCOME", (60, 120, 200), (70, 140, 220), S.LANTERN)  # south: the walk in from the teleport pad
    gateway(rng, 0, "RANCHES", (70, 140, 80), (90, 170, 90), S.LANTERN)  # east and west: the passes up to the ranches
    gateway(rng, 180, "RANCHES", (70, 140, 80), (90, 170, 90), S.LANTERN)
    stall(rng, (-13.5, 60, 0), -90, (226, 90, 80))
    stall(rng, (13.5, 60, 0), 90, (80, 150, 220))
    surroundings(rng)
    # a few of the living, for scale
    actor("creature_lion", (33.0, -4.0, 0.3), 70)
    actor("creature_flamingo", (-19.0, -9.5, 0.3), 120)
    actor("creature_meerkat_star", (20.5, 6.0, 0.3), 250)
    actor("creature_cheetah", (-6.0, 41.5, 0.3), 20)


SCENES = [
    dict(
        name="hub_centre",
        build=build,
        shots=[
            ((-70, -112, 74), (0, 2, 4), 34),  # the whole plaza from the south-west
            ((2.5, -74, 4.6), (0, 0, 10.5), 30),  # walking in from the south road
            ((-21, -27, 11.5), (0, 0, 9.0), 32),  # the fountain
            ((-2.0, -37.0, 5.4), (15.0, -23.0, 5.6), 30),  # statues and a shrine
        ],
    ),
]
