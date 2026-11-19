"""The hub as a watering hole (decision 0095): a savanna oasis in the middle of the plaza, a ring path round
it and five stops on the ring, as SHANNON chose from the hub designs ("go for the watering hole but add the
monthly rainbow statue"). The plaza keeps its size (48 studs to its kerb, World.PLAZA) and its four roads
(north to the wave arena; east, south and west to the ranches).

Its own numbers: x east, y north, z up, in studs from the plaza's middle, the lawn's top at z = 0.05.
src/stations/World.luau stands the models on the plaza's middle, puts unseen solid blocks where these
pieces are, stands the statue (the month's rainbow animal) on the rock and the Hall of Fame's animals on
their pedestals, and writes the notice board: change the two together.
"""

import math

import stage as S
from stage import box, bunting, bush, disc, flowers, lantern, lump, neon, pipe, polar, post, rock, slab, turn, words

GROUND = 0.05  # the lawn's top
PATH = 0.15  # the ring path's top
RING = (22.0, 30.0)  # the ring path's two edges
POND = (0.0, 3.0, 12.5, 9.5)  # its middle (x, y) and half sizes
ROCK = (0.0, -12.5, 3.6, 3.4)  # the statue's rock: middle, radius, height (the statue stands on its top)
ACACIA = (-10.5, 10.5)
STOPS = {  # each stop's middle on the ring (radius, angle; 0 east, 90 north), facing the middle
    "trading": (38.0, 45.0),
    "gifts": (38.0, 135.0),
    "camp": (38.0, 225.0),
    "fame": (38.0, 315.0),
    "board": (37.0, 258.0),
}
FAME = 4  # pedestals in the Hall of Fame
LAWN = (128, 184, 86)
COBBLE_A, COBBLE_B = (214, 196, 160), (198, 178, 144)
WATER = (90, 176, 226)
SAND = (226, 206, 160)
ACACIA_LEAF = (110, 168, 66)
STRIPES = ((226, 90, 80), (250, 190, 60), (80, 150, 220), (90, 190, 120), (190, 120, 240))
WHEEL = ((255, 181, 46), (92, 191, 74), (74, 166, 232), (226, 80, 122), (255, 225, 150), (170, 220, 140), (166, 216, 245), (247, 163, 189))


def local(at, yaw):
    """A function from a piece's own (x, y, z) to the plaza, for a piece standing on `at` turned `yaw` degrees."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return lambda x, y, z=0.0: (at[0] + x * c - y * s, at[1] + x * s + y * c, at[2] + z)


def stop(name):
    """A stop's middle on the lawn, and the yaw that turns its front (local -Y) to the plaza's middle."""
    r, a = STOPS[name]
    return tuple(polar(r, a, GROUND)), a - 90


def ground(rng):
    """The lawn, the ring path of cobbles, the four roads in from the kerb, a kerb of stone round it all."""
    disc(48.4, (0, 0, -0.4), 0.45, LAWN, rng, n=64, chance=0.3)
    n = 40
    for i in range(n):
        a = i * 360 / n
        slab(RING[0], RING[1], a + 0.3, a + 360 / n - 0.3, 0.0, PATH, COBBLE_A if i % 2 else COBBLE_B, rng, kind=S.PALE, chance=0.4)
    for road in (0, 90, 180, 270):
        for k in range(5):
            r0 = RING[1] + k * 3.6
            slab(r0, r0 + 3.4, road - 9 + 0.4 * (k % 2), road + 9, 0.0, PATH, COBBLE_A if k % 2 else COBBLE_B, rng, step=3, kind=S.PALE, chance=0.4)
    for i in range(48):
        a = i * 7.5
        if min(abs((a + 3.75 - road + 180) % 360 - 180) for road in (0, 90, 180, 270)) > 10:
            slab(46.8, 48.4, a + 0.2, a + 7.3, 0.0, 0.45, S.STONE_DARK, rng, surface="rock", kind=S.COOL)


def acacia(at, rng, s=1.0):
    """A savanna acacia: a leaning trunk that forks, and a wide flat crown."""
    x, y = at
    pipe([(x, y, GROUND), (x + 0.8 * s, y - 0.4 * s, 4.5 * s), (x + 1.4 * s, y - 1.0 * s, 8.0 * s)], [0.9 * s, 0.6 * s, 0.4 * s], S.WOOD_DARK, rng)
    pipe([(x + 0.8 * s, y - 0.4 * s, 4.5 * s), (x - 1.6 * s, y + 1.2 * s, 8.4 * s)], [0.45 * s, 0.3 * s], S.WOOD_DARK, rng)
    for dx, dy, w, z in ((1.4, -1.0, 7.5, 9.2), (-1.8, 1.4, 6.0, 9.4), (3.4, 1.2, 4.6, 8.8), (-0.6, -2.8, 4.8, 8.9)):
        lump((x + dx * s, y + dy * s, z * s), (w * s, w * 0.8 * s, 1.1 * s), ACACIA_LEAF, rng)


def pond(rng):
    """The watering hole: water in a sandy rim with stones, lily pads and reeds; the acacia leaning over it,
    and on its south bank the rock the month's rainbow animal stands on as a statue."""
    px, py, hx, hy = POND
    k = S.k
    rim = k.cyl(1.0, 0.18, (px, py, 0.02), n=40)
    rim.data.transform(_scale_about((px, py), hx + 2.4, hy + 2.4))
    S.paint(rim, SAND, rng, kind=S.PALE)
    water = k.cyl(1.0, 0.1, (px, py, 0.14), n=40)
    water.data.transform(_scale_about((px, py), hx, hy))
    S.paint(water, WATER, rng, kind=S.COOL, chance=0.1)
    for i in range(22):  # stones round the edge, the gap on the south for the rock
        a = i * 360 / 22 + rng.uniform(-4, 4)
        if abs((a - 270 + 180) % 360 - 180) < 22:
            continue
        r = 1.0 + rng.uniform(0.02, 0.12)
        rock((px + math.cos(math.radians(a)) * (hx + 1.3) * r, py + math.sin(math.radians(a)) * (hy + 1.3) * r, 0.0), rng, s=rng.uniform(0.9, 1.6))
    for _ in range(7):  # lily pads
        a, d = rng.uniform(0, 360), rng.uniform(0.2, 0.75)
        at = (px + math.cos(math.radians(a)) * hx * d, py + math.sin(math.radians(a)) * hy * d, 0.25)
        disc(1.0, at, 0.06, (70, 160, 80), rng, n=8)
        lump((at[0] + 0.35, at[1], 0.35), 0.28, (255, 150, 190), rng)
    for a in (30, 150, 200, 330):  # reeds
        for j in range(4):
            x = px + math.cos(math.radians(a)) * (hx - 0.6) + j * 0.35
            y = py + math.sin(math.radians(a)) * (hy - 0.6)
            post(0.08, 2.6 + j * 0.3, (x, y, 0.2), (90, 140, 70), rng, n=4)
            post(0.16, 0.7, (x, y, 2.6 + j * 0.3), (120, 84, 50), rng, n=5)
    acacia(ACACIA, rng, s=1.3)
    rx, ry, rr, rh = ROCK  # the statue's rock: a stepped boulder with a flat top
    post(rr + 1.2, rh * 0.45, (rx, ry, 0.0), S.STONE_DARK, rng, n=9, r2=rr + 0.6, surface="rock", kind=S.COOL)
    post(rr, rh * 0.55, (rx, ry, rh * 0.45), S.STONE, rng, n=9, r2=rr - 0.3, surface="rock", kind=S.COOL)
    disc(rr - 0.2, (rx, ry, rh), 0.12, (232, 220, 196), rng, n=18, kind=S.PALE)
    box((5.6, 0.4, 1.2), (rx, ry - rr - 1.15, 0.6), S.WOOD_DARK, rng)  # its name plate on a stand
    words("RAINBOW OF THE MONTH", (rx, ry - rr - 1.4, 1.2), 0.42, S.WHITE, glow=0.6)
    for sx in (-1, 1):
        flowers((rx + sx * 3.6, ry - 2.8, GROUND), rng, n=6, spread=1.2)


def _scale_about(at, sx, sy):
    from mathutils import Matrix

    t = Matrix.Translation((at[0], at[1], 0))
    return t @ Matrix.Diagonal((sx, sy, 1.0, 1.0)) @ t.inverted()


def booth(p, yaw, rng, stripe, name):
    """A stall with a striped roof, its counter to the front (local -Y), a sign board over it."""
    box((9.0, 6.0, 0.35), p(0, 0, 0), S.WOOD, rng, yaw)
    box((8.6, 1.4, 2.7), p(0, -2.0, 0.35), S.WOOD_DARK, rng, yaw)
    box((9.0, 1.8, 0.3), p(0, -2.0, 3.05), S.WOOD, rng, yaw)
    box((8.6, 0.4, 5.6), p(0, 2.8, 0.35), S.WOOD_DARK, rng, yaw)  # the back wall
    for sx in (-4.2, 4.2):
        for sy in (-2.6, 2.6):
            box((0.45, 0.45, 6.8), p(sx, sy, 0.35), S.WOOD_DARK, rng, yaw)
    for i in range(9):
        box((1.0, 7.0, 0.22), p(-4.0 + i, -0.3, 6.9), stripe if i % 2 else S.WHITE, rng, yaw, tilt=(-10, 0))
    box((len(name) * 0.62 + 1.6, 0.4, 1.6), p(0, -3.6, 7.4), S.WOOD_DARK, rng, yaw)
    words(name, p(0, -3.85, 8.2), 0.9, S.WHITE, glow=0.6, yaw=yaw)


def trading(rng):
    """The Trading Post: a stall with two stools at its counter and two crates of straw; the game puts a
    prompt here that opens the trade menu."""
    at, yaw = stop("trading")
    p = local(at, yaw)
    booth(p, yaw, rng, (255, 181, 46), "TRADING POST")
    for sx in (-2.2, 2.2):
        turn([(0.7, 0), (0.55, 0.2), (0.4, 1.4), (0.75, 1.6), (0.75, 1.75)], p(sx, -3.6, 0.0), S.WOOD, rng, n=8)
    for i in range(2):
        box((1.6, 1.6, 1.4), p(-5.6, -1.0 + i * 1.9, 0.0), (190, 140, 90), rng, yaw)
        lump(p(-5.6, -1.0 + i * 1.9, 1.5), (0.8, 0.8, 0.3), (228, 196, 110), rng)


def gifts(rng):
    """The Gift Stand: a stall with a big prize wheel on its back wall and gift boxes on the counter; the
    game puts a prompt here that opens Gifts."""
    at, yaw = stop("gifts")
    p = local(at, yaw)
    booth(p, yaw, rng, (92, 191, 74), "DAILY GIFTS")
    wheel_at = p(0, 2.3, 4.0)
    face = S.k.cyl(2.3, 0.35, wheel_at, n=24, rot=(90, 0, yaw))
    S.paint(face, S.WHITE, rng, kind=S.PALE)
    for i, rgb in enumerate(WHEEL):  # its eight slices as spokes of colour
        a = math.radians(i * 45 + 22.5)
        sx, sz = math.cos(a) * 1.25, math.sin(a) * 1.25
        q = p(sx, 1.95, 4.0 + sz)
        box((1.2, 0.2, 1.2), (q[0], q[1], q[2] - 0.6), rgb, rng, yaw)
    lump(p(0, 1.9, 4.0), 0.45, S.GOLD, rng)
    neon(S.k.cyl(0.25, 0.6, p(0, 1.85, 6.5), n=6, r2=0.0, rot=(180, 0, 0)), (226, 80, 122), 1.5)  # the pointer
    for i in range(4):
        x = -3.0 + i * 2.0
        box((1.1, 1.1, 1.0), p(x, -2.0, 3.35), STRIPES[i], rng, yaw)
        box((1.2, 0.2, 0.25), p(x, -2.0, 4.0), S.GOLD, rng, yaw)


def fame(rng):
    """The Hall of Fame: four pedestals in an arc behind a low hedge, a gold name plate before each, an arch
    over them; the game stands this server's best animals on the pedestals."""
    at, yaw = stop("fame")
    p = local(at, yaw)
    for i in range(FAME):
        x = (i - (FAME - 1) / 2) * 4.4
        y = 0.8 + abs(i - (FAME - 1) / 2) * 0.8
        turn([(1.7, 0), (1.5, 0.3), (1.2, 0.5), (1.1, 1.6), (1.5, 1.8), (1.5, 2.0)], p(x, y, 0.0), S.MARBLE, rng, n=12, kind=S.PALE)
        box((1.6, 0.25, 0.5), p(x, y - 1.6, 0.9), S.GOLD, rng, yaw)
    for sx in (-9.2, 9.2):
        post(0.5, 7.0, p(sx, 1.4, 0.0), S.MARBLE, rng, n=8, kind=S.PALE)
        lump(p(sx, 1.4, 7.2), 0.7, S.GOLD, rng)
    box((19.2, 0.6, 1.0), p(0, 1.4, 7.0), S.MARBLE, rng, yaw, kind=S.PALE)
    box((10.4, 0.4, 1.5), p(0, 1.1, 7.6), S.WOOD_DARK, rng, yaw)
    words("HALL OF FAME", p(0, 0.85, 8.35), 0.9, S.GOLD, glow=0.6, yaw=yaw)
    for sx in (-1, 1):
        bush(p(sx * 10.6, -0.2, 0.0), rng, s=0.9)


def board(rng):
    """The notice board: a roofed board on two posts. The game writes on it (the month's rainbow, news)."""
    at, yaw = stop("board")
    p = local(at, yaw)
    for sx in (-3.4, 3.4):
        post(0.3, 7.2, p(sx, 0, 0.0), S.WOOD_DARK, rng, n=6)
    box((7.4, 0.4, 4.4), p(0, 0, 1.6), S.WOOD, rng, yaw)
    box((6.8, 0.1, 3.8), p(0, -0.25, 1.9), (244, 232, 206), rng, yaw, kind=S.PALE)  # the paper the game writes on
    box((8.4, 1.6, 0.25), p(0, 0, 7.2), S.WOOD_DARK, rng, yaw, tilt=(-14, 0))
    box((5.4, 0.3, 1.0), p(0, -0.3, 6.25), S.WOOD_DARK, rng, yaw)
    words("NOTICE BOARD", p(0, -0.5, 6.75), 0.55, S.WHITE, glow=0.6, yaw=yaw)


def camp(rng):
    """The campfire where everyone arrives: a stone ring and flames, four logs to sit on, lanterns."""
    at, _ = stop("camp")
    x, y = at[0], at[1]
    for i in range(12):
        lump((x + math.cos(i * math.pi / 6) * 2.4, y + math.sin(i * math.pi / 6) * 2.4, 0.4), (0.7, 0.6, 0.5), (150, 144, 136), rng, surface="rock", kind=S.COOL)
    disc(2.0, (x, y, GROUND), 0.1, (60, 52, 50), rng, n=10)
    for i in range(5):
        pipe([(x + math.cos(i * 1.256) * 1.6, y + math.sin(i * 1.256) * 1.6, 0.1), (x, y, 2.6)], [0.3, 0.2], (112, 78, 50), rng, n=6)
    for dx, dy, r, h, rgb in ((0, 0, 1.0, 3.4, (255, 150, 40)), (0.5, 0.2, 0.7, 2.4, (255, 200, 70)), (-0.4, 0.4, 0.7, 2.6, (255, 110, 40))):
        neon(S.k.cyl(r, h, (x + dx, y + dy, 0.5 + h / 2), n=6, r2=0.0), rgb, 2.6)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        cx, cy = x + math.cos(a) * 6.2, y + math.sin(a) * 6.2
        log = pipe([(cx - math.sin(a) * 2.4, cy + math.cos(a) * 2.4, 0.6), (cx + math.sin(a) * 2.4, cy - math.cos(a) * 2.4, 0.6)], [0.6, 0.6], S.WOOD, rng, n=7)
        del log
    for i in range(3):
        a = i * 120 + 20
        lantern(tuple(polar(9.4, a, 0.0) + __import__("mathutils").Vector((x, y, 0))), rng, h=5.0)


def lights(rng):
    """Lamps round the ring path (none on a road or a stop), and strings of flags from post to post."""
    taken = [0, 90, 180, 270] + [a for _, a in STOPS.values()]
    tops = []
    for i in range(16):
        a = i * 22.5 + 11.25
        if min(abs((a - t + 180) % 360 - 180) for t in taken) < 9:
            continue
        lantern(tuple(polar(RING[1] + 1.6, a, 0.0)), rng, h=6.0)
        tops.append(tuple(polar(RING[1] + 1.6, a, 6.6)))
    for a, b in zip(tops, tops[1:] + tops[:1]):
        if (__import__("mathutils").Vector(a) - __import__("mathutils").Vector(b)).length < 16:
            bunting(a, b, 1.2, rng, STRIPES, n=7, size=0.7)
    for i in range(10):  # flowers and bushes on the lawn inside the ring
        a = i * 36 + 18
        if abs((a - 270 + 180) % 360 - 180) > 25:
            flowers(tuple(polar(RING[0] - 2.2, a, GROUND)), rng, n=5, spread=1.0)


MAKERS = (("hub_ground", ground), ("hub_pond", pond), ("hub_trading", trading), ("hub_gifts", gifts), ("hub_fame", fame), ("hub_board", board), ("hub_camp", camp), ("hub_lights", lights))
