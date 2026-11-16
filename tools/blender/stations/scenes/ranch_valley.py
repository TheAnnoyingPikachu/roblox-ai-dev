"""A whole ranch reworked as one valley (concept, decision 0068): the homestead on a plateau in the middle,
the six training grounds set into the land round it, each where it belongs: the Magic Library on a high
ledge, the Healing Spring in a basin under a waterfall, the Guard Yard in the mouth of a pass, the
Strength Gym in a quarry cut, and the Swim Pool and the Speed Track down on the beach of a bay. A stream
runs from the spring past the homestead to the sea. Everything is nearer than in the six clearings of
decision 0065: the whole ranch is about 820 studs across where that one is 1,260.

The land is one faceted mesh made from a height function (`height`): mountains, flattened where
something stands (`PADS`), cut where a path runs (`WAYS`), and sloping to the sea in the south-east.
"""

import importlib.util
import math
import os

import stage as S
from mathutils import Matrix, Vector, noise
from stage import actor, box, bush, disc, fence, flag, flowers, lump, neon, pine, pipe, polar, post, rock, roof, tree, turn, words

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(f"scene_{name}", os.path.join(HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


T = _load("training")
H = _load("hub")

SEA_LEVEL = -20.0
SEAWARD = Vector((0.62, -0.78)).normalized()  # the way down to the bay
HALF, CELL = 640, 8  # the land that is modelled, and the size of one of its facets

# Where things stand: name, middle, the radius that is levelled, its height. The first is the homestead.
HOME = ("home", (0.0, 0.0), 112.0, 0.0)
GROUNDS = (
    ("mana", "MAGIC LIBRARY", (-196.0, 192.0), 46.0, (72, 74, 104)),
    ("health", "HEALING SPRING", (12.0, 268.0), 30.0, (150, 196, 120)),
    ("defence", "GUARD YARD", (222.0, 168.0), 16.0, (222, 204, 166)),
    ("strength", "STRENGTH GYM", (-262.0, -14.0), 8.0, (214, 188, 140)),
    ("stamina", "SWIM POOL", (132.0, -238.0), -15.0, (232, 222, 200)),
    ("speed", "SPEED TRACK", (306.0, -66.0), -13.0, (118, 176, 84)),
)
PAD = 106.0  # the radius levelled for a training ground
STREAM = ((12.0, 380.0), (12.0, 268.0), (58.0, 168.0), (118.0, 84.0), (150.0, -20.0), (228.0, -120.0), (330.0, -210.0))
HUB_ROAD = ((0.0, 0.0), (-150.0, -260.0), (-330.0, -640.0))

PATH = (206, 190, 160)
SAND = (236, 216, 164)
ROCK = (132, 128, 148)
SNOW = (244, 244, 250)


def smooth(a, b, x):
    """0 at a, 1 at b, eased; a may be above b."""
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def ridge(x, y, f):
    return 1 - abs(noise.noise(Vector((x * f, y * f, 3.7))))


def near(p, a, b):
    """(distance from p to the segment a to b, how far along it the nearest point is: 0 to 1)."""
    ab = b - a
    t = min(1.0, max(0.0, (p - a).dot(ab) / ab.dot(ab)))
    return (p - (a + ab * t)).length, t


def along(p, line):
    """(distance from p to a line of points, how far along the whole line the nearest point is)."""
    best, at = 1e9, 0.0
    for i in range(len(line) - 1):
        d, t = near(p, Vector(line[i]), Vector(line[i + 1]))
        if d < best:
            best, at = d, (i + t) / (len(line) - 1)
    return best, at


def ways():
    """The paths: from the homestead to each ground, as (from, to, height at one end, at the other)."""
    out = []
    for _, _, c, h, _ in GROUNDS:
        c = Vector(c)
        u = c.normalized()
        out.append((u * (HOME[2] - 6), c - u * (PAD - 6), 0.0, h))
    return out


WAYS = ways()


def height(x, y):
    """The land's height at (x, y)."""
    p = Vector((x, y))
    r, s = p.length, p.dot(SEAWARD)
    n = 0.6 * ridge(x, y, 0.0036) + 0.4 * ridge(x + 900, y, 0.0085)
    inland = smooth(-80, 300, -s)  # 0 on the bay's side, 1 deep among the mountains
    # low knolls between the grounds, and mountains that rise behind them, highest inland
    land = 10 + 30 * n * (0.4 + 0.6 * inland) + max(0.0, r - 290) * 0.42 * (0.2 + 0.8 * inland) * (0.5 + 0.95 * n)
    land -= 0.1 * max(0.0, s)  # lower towards the bay
    beach = -8 - 20 * smooth(230, 420, s + 26 * noise.noise(Vector((x * 0.006, y * 0.006, 1.0))))
    z = land + (beach - land) * smooth(150, 262, s)
    d, t = along(p, STREAM)  # the stream cuts a little gully, from the spring's height to the sea
    if d < 40:
        bed = 30 - 52 * smooth(0.18, 1.0, t)
        z += (min(z, bed) - z) * smooth(40, 10, d)
    d, t = along(p, HUB_ROAD)  # the road down to the hub
    if d < 60:
        z += (-26 * t - z) * smooth(60, 16, d)
    for a, b, h0, h1 in WAYS:
        d, t = near(p, a, b)
        if d < 44:
            z += (h0 + (h1 - h0) * t - z) * smooth(44, 11, d)
    for _, c, radius, h in [HOME] + [(g[0], g[2], PAD, g[3]) for g in GROUNDS]:
        d = (p - Vector(c)).length
        if d < radius + 46:
            z += (h - z) * smooth(radius + 46, radius, d)
    d, t = along(p, STREAM)
    if 0.05 < t and d < 9:
        z -= 2.2 * smooth(9, 3, d)
    return z


def colour_of(c, n):
    """The colour of a facet of land from where it is and how it lies."""
    p = Vector((c.x, c.y))
    for _, _, centre, _, ground in GROUNDS:
        if (p - Vector(centre)).length < 86:
            return ground
    if p.length < HOME[2] - 4:
        return (120, 180, 86)
    steep = 1 - n.z
    if c.z < -3.5 and p.dot(SEAWARD) > 150 and steep < 0.2:
        return SAND
    if steep > 0.2:
        return ROCK if c.z < 165 else (190, 190, 206)
    if c.z > 150:
        return SNOW
    k = min(1.0, max(0.0, c.z / 120))
    return (104 - 26 * k, 168 - 30 * k, 76 + 8 * k)


def land(rng):
    """The land as one faceted mesh, each facet in the colour of what it is."""
    n = 2 * HALF // CELL
    zs = [[height(-HALF + i * CELL, -HALF + j * CELL) for i in range(n + 1)] for j in range(n + 1)]
    verts = [(-HALF + i * CELL, -HALF + j * CELL, zs[j][i]) for j in range(n + 1) for i in range(n + 1)]
    faces, tones = [], []
    for j in range(n):
        for i in range(n):
            a, b, c, d = j * (n + 1) + i, j * (n + 1) + i + 1, (j + 1) * (n + 1) + i + 1, (j + 1) * (n + 1) + i
            pa, pb, pc, pd = Vector(verts[a]), Vector(verts[b]), Vector(verts[c]), Vector(verts[d])
            if max(pa.z, pb.z, pc.z, pd.z) < SEA_LEVEL - 4:
                continue  # under the sea
            normal = (pc - pa).cross(pd - pb).normalized()
            if normal.z < 0:
                normal = -normal
            faces.append((a, b, c, d))
            rgb = colour_of((pa + pb + pc + pd) / 4, normal)
            kind = S.COOL if rgb in (ROCK, SNOW) else S.WARM
            tones.append(S.F.tone(rgb, kind))
    used = sorted({v for f in faces for v in f})
    index = {v: k for k, v in enumerate(used)}
    return S.F.mesh("land", [verts[v] for v in used], [tuple(index[v] for v in f) for f in faces], tones, rng, chance=0.16)


def on(x, y, up=0.0):
    return Vector((x, y, height(x, y) + up))


def ribbon(line, width, rgb, rng, lift=0.35, smoothed=False, start=0.0):
    """A strip laid on the land along a line of points: a path, the stream. `start`: how far along to begin."""
    pts = [Vector((x, y, 0)) for x, y in line]
    if smoothed:
        pts = [q for q, _ in S.k.spline(pts, [0] * len(pts), 12 * (len(pts) - 1))]
    samples = []
    for a, b in zip(pts, pts[1:]):
        steps = max(1, int((b - a).length / 5))
        samples += [a.lerp(b, i / steps) for i in range(steps)]
    samples.append(pts[-1])
    samples = samples[int(start * len(samples)) :]
    verts = []
    for i, q in enumerate(samples):
        ahead = (samples[min(i + 1, len(samples) - 1)] - samples[max(i - 1, 0)]).normalized()
        side = Vector((-ahead.y, ahead.x, 0)) * width / 2
        for edge in (q - side, q + side):
            verts.append((edge.x, edge.y, max(height(edge.x, edge.y), SEA_LEVEL) + lift))
    faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(samples) - 1)]
    return S.F.mesh("ribbon", verts, faces, S.F.tone(rgb), rng, chance=0.1)


def ribbons(rng):
    """The paths from the homestead to each ground, the road down to the hub, the stream to the sea."""
    for a, b, _, _ in WAYS:
        ribbon([tuple(a - (b - a).normalized() * 70), tuple(b)], 13, PATH, rng)
    ribbon(HUB_ROAD, 17, PATH, rng)
    ribbon(STREAM, 10, S.WATER, rng, lift=0.9, smoothed=True, start=0.16)


def far_mountains(rng):
    """Beyond the modelled land, inland: the range the valley lies under."""
    for i in range(22):
        a = 20 + i * 10.5 + rng.uniform(-3, 3)  # round the north and the west
        r = rng.uniform(760, 980)
        foot, tall = rng.uniform(150, 230), rng.uniform(230, 380)
        post(foot, tall, polar(r, a, -20), (118, 122, 148), rng, n=7, r2=foot * 0.12, rot=(0, 0, rng.uniform(0, 50)), kind=S.COOL, chance=0.3)
        post(foot * 0.42, tall * 0.3, polar(r, a, -20 + tall * 0.72), S.WHITE, rng, n=7, r2=foot * 0.1, rot=(0, 0, rng.uniform(0, 50)), kind=S.PALE)


def sea(rng):
    S.paint(S.k.cyl(3200, 0.5, (0, 0, SEA_LEVEL - 0.25), n=48), (46, 128, 196), rng, surface="gem", kind=S.COOL, emit=0.06, chance=0.05)
    for i in range(9):  # a line of surf along the beach
        x, y = SEAWARD.x * 318 + SEAWARD.y * (i - 4) * 62, SEAWARD.y * 318 - SEAWARD.x * (i - 4) * 62
        if height(x, y) < SEA_LEVEL + 3:
            lump((x, y, SEA_LEVEL + 0.2), (20, 5, 0.5), S.WHITE, rng, kind=S.PALE)


def waterfall(rng):
    """Down the cliff behind the spring, into its basin."""
    for dx in (-5, 0, 5):
        pts = [tuple(on(12 + dx, 268 + PAD + 44 - k * 9, 1.2)) for k in range(7)]
        neon(S.k.tube(pts, [2.6, 2.8, 3.0, 3.0, 3.0, 3.2, 3.6], n=6), (170, 226, 248) if dx else (214, 240, 252), 0.7)
    lump(tuple(on(12, 268 + PAD - 4, 1.5)), (12, 6, 2.2), S.WHITE, rng, kind=S.PALE)


def homestead(rng):
    """The middle of the ranch, round a cobbled yard: the house at the back, the barn and its silo, the
    hatchery under its round roof, the two vendors by the way in, the paddock where the animals roam."""
    disc(26, (0, 0, 0.05), 0.3, (214, 196, 160), rng, n=20, kind=S.PALE, chance=0.3)  # the yard
    turn([(4.0, 0.0), (4.4, 2.2), (3.8, 2.6)], (0, 0, 0.3), S.STONE, rng, n=10, kind=S.PALE)  # the well
    for sx in (-3.2, 3.2):
        post(0.3, 6.0, (sx, 0, 2.6), S.WOOD_DARK, rng, n=5)
    roof(9.0, 6.0, 2.4, (0, 0, 8.6), (176, 70, 60), rng, ridge=6.0)
    # the house: two floors, a porch, a chimney
    box((40, 26, 13), (0, 70, 0.3), (232, 214, 180), rng, kind=S.PALE)
    roof(44, 30, 10, (0, 70, 13.3), (176, 70, 60), rng, ridge=20)
    box((16, 6, 0.6), (0, 54, 0.3), S.WOOD, rng)
    for sx in (-7, 7):
        post(0.4, 8.0, (sx, 52, 0.9), S.WOOD_DARK, rng, n=6)
    roof(18, 8, 2.0, (0, 54, 8.9), (150, 60, 52), rng, ridge=14)
    box((5, 0.4, 8), (0, 56.8, 0.9), S.WOOD_DARK, rng)
    for sx in (-12, 12):
        box((5, 0.3, 5), (sx, 56.9, 5.0), (255, 226, 150), rng)
    box((4, 4, 9), (12, 76, 14), S.STONE_DARK, rng, surface="rock", kind=S.COOL)
    # the barn and its silo
    box((34, 24, 14), (-68, 26, 0.3), (196, 64, 54), rng, yaw=24)
    roof(38, 28, 10, (-68, 26, 14.3), (84, 72, 76), rng, yaw=24, ridge=22)
    post(6.0, 22, (-88, 2, 0.3), (205, 210, 215), rng, n=10)
    post(6.4, 5.0, (-88, 2, 22.3), (196, 64, 54), rng, n=10, r2=0.4)
    for i in range(5):
        box((2.6, 1.4, 1.3), (-52 + i * 2.9, 6 - i * 1.0, 0.3), (228, 196, 110), rng, yaw=24)
    # the hatchery: six nests under a round roof
    hx, hy = 70, 30
    disc(15, (hx, hy, 0.1), 0.5, (226, 214, 190), rng, n=14, kind=S.PALE)
    for i in range(8):
        post(0.5, 9.0, Vector((hx, hy, 0.6)) + polar(13.5, i * 45), S.WOOD_DARK, rng, n=6)
    post(17, 6.0, (hx, hy, 9.6), (250, 196, 60), rng, n=12, r2=0.8)
    for i in range(6):
        p = Vector((hx, hy, 0.6)) + polar(8.0, i * 60)
        post(2.4, 0.7, p, (228, 196, 110), rng, n=8)
        actor(("egg_meadow", "egg_wild", "egg_safari", "egg_golden")[i % 4], p + Vector((0, 0, 0.6)), i * 60 + 90, scale=1.0)
    # the vendors' stalls, either side of the way in
    H.stall(rng, (-22, -84, height(-22, -84)), 200, (226, 90, 80))
    H.stall(rng, (22, -84, height(22, -84)), 160, (80, 150, 220))
    # the paddock, and the animals in it
    px, py = 52, -46
    for i in range(18):
        a, b = Vector((px, py, 0.3)) + polar(36, i * 20), Vector((px, py, 0.3)) + polar(36, i * 20 + 20)
        if i not in (7, 8):
            fence(a, b, rng, h=4.2, gap=6.5)
    for i in range(4):
        box((2.6, 1.4, 1.3), (px - 20 + i * 2.8, py + 24, 0.3), (228, 196, 110), rng, yaw=10)
    actor("creature_lion", (px - 8, py + 6, 0.3), 40)
    actor("creature_elephant", (px + 12, py - 8, 0.3), -70)
    actor("creature_flamingo", (px - 16, py - 14, 0.3), 120)
    actor("creature_jackal", (px + 4, py + 20, 0.3), 200)
    actor("creature_tortoise", (-18, 18, 0.3), 150)
    # a windmill on the rise behind the barn
    wx, wy = -70, -52
    post(7.0, 26, (wx, wy, 0.3), S.STONE, rng, n=8, r2=4.6, surface="rock", kind=S.PALE)
    post(5.4, 6.0, (wx, wy, 26.3), S.WOOD_DARK, rng, n=8, r2=0.4)
    for i in range(2):  # its sails: two crossed boards
        box((30.0, 0.5, 3.4), (wx, wy - 5.4, 24.0), S.WHITE, rng, tilt=(0, i * 90 + 20), kind=S.PALE)


def signpost(rng, a, colour, name):
    """Where a path leaves the homestead: a post with the ground's name in its stat's colour."""
    p = polar(HOME[2] - 14, a)
    post(0.7, 13, on(p.x, p.y), S.WOOD_DARK, rng, n=6)
    for face in (-1, 1):
        words(name, on(p.x, p.y, 10.5) + polar(1.0 * face, a + 90), 2.4, S.WHITE, yaw=a + 90 * face, glow=0.5)
    box((0.9, 20.0, 4.6), on(p.x, p.y, 8.2), colour, rng, yaw=a, chance=0.08)


def woods(rng):
    clear = [(Vector(HOME[1]), HOME[2] + 8)] + [(Vector(g[2]), PAD + 4) for g in GROUNDS]
    done = 0
    while done < 300:
        x, y = rng.uniform(-HALF + 40, HALF - 40), rng.uniform(-HALF + 40, HALF - 40)
        p = Vector((x, y))
        z = height(x, y)
        if z < -5 or z > 120 or any((p - c).length < r for c, r in clear):
            continue
        if along(p, STREAM)[0] < 12 or along(p, HUB_ROAD)[0] < 14 or any(near(p, a, b)[0] < 13 for a, b, _, _ in WAYS):
            continue
        if abs(height(x + 6, y) - z) + abs(height(x, y + 6) - z) > 5.0:
            continue  # too steep to root
        done += 1
        roll = rng.random()
        if roll < 0.45:
            tree((x, y, z), rng, rng.uniform(1.8, 2.8))
        elif roll < 0.8:
            pine((x, y, z), rng, rng.uniform(2.0, 3.2))
        else:
            rock((x, y, z), rng, rng.uniform(2.0, 4.0))
    for _ in range(26):  # palms and parasols on the beach
        x, y = rng.uniform(-HALF, HALF), rng.uniform(-HALF, HALF)
        p, z = Vector((x, y)), height(x, y)
        if -12 < z < -5 and p.dot(SEAWARD) > 190 and not any((p - c).length < r for c, r in clear):
            T.palm((x, y, z), rng, rng.uniform(2.0, 2.8))


# One animal at work in each ground (a ground trains one at a time): where, in the yard's own numbers.
AT_WORK = {
    "speed": ("creature_cheetah", (-13.0, -8.6, 0.43), 90),
    "strength": ("creature_elephant", (-17.0, 12.0, 0.95), 0),
    "stamina": ("creature_tortoise", (-6.0, 1.0, 0.6), 90),
    "mana": ("creature_meerkat_storm", (0.0, -3.0, 0.55), 180),
    "health": ("creature_flamingo", (-6.8, -10.8, 0.55), 30),
    "defence": ("creature_rhino", (0.0, -0.6, 0.37), 180),
}


def build(rng):
    land(rng)
    sea(rng)
    far_mountains(rng)
    ribbons(rng)
    waterfall(rng)
    homestead(rng)
    T.OPEN = True
    for maker, name, c, h, _ in GROUNDS:
        c = Vector(c)
        to_home = -c.normalized()
        yaw = math.degrees(math.atan2(to_home.x, -to_home.y))  # its gateway faces the homestead
        lift = Matrix.Translation((0, 0, h - 0.5))
        for ob in T.area(getattr(T, maker), rng, at=(c.x, c.y), yaw=yaw, animals=False):
            ob.data.transform(lift)
        who, at, turned = AT_WORK[maker]
        spot = Matrix.Rotation(math.radians(yaw), 4, "Z") @ (Vector(at) * T.K)
        actor(who, (c.x + spot.x, c.y + spot.y, h - 0.5 + spot.z), turned + yaw)
        signpost(rng, math.degrees(math.atan2(c.y, c.x)), getattr(T, maker.upper()), name)
    T.OPEN = False
    woods(rng)
    for x, y, yaw in ((92, 112, 60), (140, 6, 20)):  # bridges where a path crosses the stream
        z = height(x, y) + 3.4
        box((20, 9, 0.8), (x, y, z), S.WOOD, rng, yaw=yaw)
        for side in (-1, 1):
            off = polar(4.2 * side, yaw + 90)
            box((20, 0.5, 2.2), (x + off.x, y + off.y, z + 0.8), S.RED, rng, yaw=yaw)
    words("TO THE HUB", tuple(on(-128, -224, 30)), 13, S.WHITE, yaw=36, glow=0.8)


def above(x, y, up):
    """A camera's place: `up` studs over the highest land near (x, y)."""
    return (x, y, max(height(x + dx, y + dy) for dx in (-14, 0, 14) for dy in (-14, 0, 14)) + up)


SCENES = [
    dict(
        name="ranch_valley",
        build=build,
        ground=None,
        shots=[
            ((540, -740, 500), (10, 14, 6), 34),  # the whole valley from over the bay
            ((0, -2, 1500), (0, 0, 0), 50),  # the plan
            (above(-6, -64, 30), (-70, 236, 46), 26),  # from the homestead up to the spring and the library
            ((322, -322, 12), (196, -150, -6), 28),  # the beach: the pool and the track, the homestead above
            (above(44, -116, 36), (0, 40, 8), 30),  # the homestead's yard
            (above(118, 66, 30), (222, 168, 26), 30),  # the guard yard in its pass
            (above(-128, -56, 30), (-262, -14, 18), 30),  # the gym in its cut
        ],
    ),
]
