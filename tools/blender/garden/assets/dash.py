"""Splash Dash: the cheerful toy obstacle kit (docs/assets/garden-blender-plan.md).

Sizes and shapes follow docs/architecture/garden.md section 9. Pivots are not kept on import: the
loader rebuilds each asset into a Model whose pivot is its bounding box centre, and DashFx moves the
whole Model. So every moving piece is one mesh with its bounding box centre where the code expects
it, and nothing static goes in a moving model."""

import math
import random

import bmesh
import kit as k
from mathutils import Matrix, Vector


def _pad(path, radii, a, b, every=3, n=12):
    """Padded bumper: tube sections along `path`, alternating two colours."""
    out = []
    for i in range(0, len(path) - 1, every):
        j = min(i + every, len(path) - 1)
        out.append(k.tube(path[i : j + 1], radii[i : j + 1], m=a if (i // every) % 2 == 0 else b, n=n, name="pad"))
    return out


def _face_flowers(r, y, z, petal, heart):
    """A flower on each side of a bumper, facing -Y and +Y."""
    out = []
    for side in (-1, 1):
        for ob in k.flower(r, petal, heart, lobes=6):
            ob.data.transform(Matrix.Translation((0, side * y, z)) @ Matrix.Rotation(math.radians(90 * -side * -1), 4, "X"))
            out.append(ob)
    return out


def dash_sweeper():
    candy = k.paint("sw_post", [(0, k.SNOW), (1, k.SNOW)], 0, 12, bands=((255, 120, 160), 2.2))
    flange = k.paint("sw_base", [(0, (70, 195, 205)), (1, (130, 230, 215))], 0, 12)
    hub_m = k.flat(k.SUNNY)
    a, b = k.flat((255, 110, 130)), k.flat((255, 236, 170))
    end = k.flat(k.TEAL)

    # Mirrored top and bottom about the hub, so the bounding box centre is the hub on every axis.
    hub = 6.0
    half = 20.0
    tip = 2.3
    post = [(2.9, 0), (3.0, 0.4), (2.0, 0.9), (1.1, 1.8), (0.95, 2.6), (0.95, hub)]
    parts = [
        k.lathe(post, m=flange, n=16, name="base"),
        k.lathe([(r, 2 * hub - z) for r, z in reversed(post)], m=flange, n=16, name="crown"),
        k.lathe([(1.0, 2.4), (1.0, 2 * hub - 2.4)], m=candy, n=14, name="post"),
    ]
    span = half - tip
    path = [(-span + 2 * span * i / 24, 0, hub) for i in range(25)]
    radii = [1.42 + 0.36 * abs(math.cos(i * math.pi / 3)) for i in range(25)]
    parts += _pad(path, radii, a, b, every=2)
    for rot in (90, -90):
        x = span if rot > 0 else -span
        parts.append(k.lathe([(1.78, 0), (1.72, 0.8), (1.22, 1.75), (0.6, 2.2), (0, tip)], loc=(x, 0, hub), rot=(0, rot, 0), m=end, n=14, name="bumper"))
    parts.append(k.lathe([(2.3, -1.45), (2.5, -0.7), (2.5, 0.7), (2.3, 1.45)], loc=(0, 0, hub), rot=(90, 0, 0), m=hub_m, n=20, name="hub"))
    parts += _face_flowers(1.9, 1.45, hub, k.flat((255, 170, 120)), k.flat((255, 150, 90)))
    return parts


def dash_ball():
    shell_m = k.paint("ba_shell", [(0, (255, 150, 90)), (0.5, (255, 130, 130)), (1, (255, 120, 175))], 0, 10)
    spot = k.flat(k.BUTTER)
    spot2 = k.flat(k.SKY)
    radius = 5.0
    parts = [k.sphere(radius, (0, 0, 5), m=shell_m, seg=32, rings=18, name="ball")]
    # Fibonacci spread of raised dots, so no axis looks bald as it rolls.
    count = 22
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(count):
        z = 1 - 2 * (i + 0.5) / count
        r = math.sqrt(1 - z * z)
        n = Vector((r * math.cos(i * golden), r * math.sin(i * golden), z))
        size = 1.0 if i % 3 else 0.7
        cap = k.lathe([(size, -0.25), (size * 0.95, 0.07), (0, 0.15)], m=spot2 if i % 2 else spot, n=14, name="dot")
        cap.data.transform(Matrix.Translation(n * (radius - 0.06) + Vector((0, 0, 5))) @ Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4())
        parts.append(cap)
    return parts


def dash_pendulum():
    a, b = k.flat((255, 110, 130)), k.flat((255, 236, 170))
    rod = k.paint("pe_rod", [(0, (255, 196, 96)), (1, (255, 214, 120))], 0, 30, bands=((255, 170, 80), 3.0))
    collar = k.flat(k.SUNNY)
    cap = k.flat(k.TEAL)

    # The whole model swings, so it is rod and bob only: the hinge is the top face centre, the bob
    # centre 26 below it (DASH reach), the bob 8 wide (size 4).
    length = 30.0
    head_z = 4.0
    parts = [
        k.tube([(0, 0, head_z + 3.2), (0, 0, length - 1)], 0.62, m=rod, n=12, name="rod"),
        k.lathe([(0.62, length - 2.2), (1.25, length - 1.2), (1.25, length)], m=collar, n=14, name="collar"),
        k.lathe([(1.5, head_z + 3.0), (0.9, head_z + 4.6), (0.62, head_z + 5.4)], m=collar, n=14, name="socket"),
    ]
    path = [(-3 + 6 * i / 12, 0, head_z) for i in range(13)]
    radii = [3.5 + 0.5 * abs(math.cos(i * math.pi / 3)) for i in range(13)]
    parts += _pad(path, radii, a, b, every=2, n=16)
    for rot in (90, -90):
        x = 3.0 if rot > 0 else -3.0
        parts.append(k.lathe([(3.5, 0), (3.2, 0.5), (2.1, 0.88), (0, 1.0)], loc=(x, 0, head_z), rot=(0, rot, 0), m=cap, n=16, name="bumper"))
    parts += _face_flowers(1.8, 3.6, head_z, k.flat(k.SNOW), k.flat(k.SUNNY))
    return parts


def _petal(length, width, thick, m, angle, z, inner):
    """Flat-topped rounded petal, its top at z, pointing out along `angle` degrees."""
    n = 9
    pts = []
    for i in range(n):
        t = i / (n - 1) * math.pi
        pts.append((inner + length * (0.5 - 0.5 * math.cos(t)) ** 0.9, width * math.sin(t) ** 0.8))
    for i in range(n - 2, 0, -1):
        pts.append((pts[i][0], -pts[i][1]))
    ob = k.poly(pts, thick, loc=(0, 0, z - thick / 2), rot=(90, 0, 0), m=m, name="petal")
    ob.data.transform(k.rot_z(angle))
    return ob


def dash_platform():
    top = 2.0
    deck = k.paint("pl_deck", [(0, (255, 224, 110)), (1, (255, 240, 170))], 0, 4.2, dots=[((255, 200, 90), 1.2, 0.2)])
    petal_a = k.paint("pl_a", [(0, (255, 200, 225)), (1, (255, 120, 170))], -6, 6, axis="X")
    petal_b = k.paint("pl_b", [(0, (255, 120, 170)), (1, (255, 200, 225))], -6, 6, axis="X")
    under = k.paint("pl_under", [(0, (95, 195, 105)), (1, (150, 228, 120))], 0, 1.4)

    parts = [
        k.cyl(4.2, 0.5, (0, 0, top - 0.24), m=deck, n=32, name="deck"),
        k.lathe([(4.2, top - 0.5), (3.4, top - 1.2), (1.6, 0.0), (0, 0.0)], m=under, n=24, name="bowl"),
    ]
    # Upper petals lie flush with the deck, so the top is one flat walkable surface; leaf-green
    # sepals sit under the gaps, and nothing goes below the 2-stud height.
    count = 9
    for i in range(count):
        a = i * 360 / count
        parts.append(_petal(3.54, 1.9, 0.6, petal_a if i % 2 else petal_b, a, top - 0.02, 2.55))
        parts.append(_petal(3.3, 1.75, 0.5, under, a + 180 / count, top - 0.62, 2.4))
    return parts


def dash_arch():
    colours = [k.flat(c) for c in ((255, 130, 150), (255, 190, 110), (255, 232, 130), (130, 225, 160), (110, 205, 240), (190, 160, 255))]
    board = k.flat(k.SNOW, name="ar_board")
    frame_m = k.flat((255, 196, 96))
    foot = k.paint("ar_foot", [(0, (70, 195, 205)), (1, (130, 230, 215))], 0, 2)
    strip = k.glow((120, 255, 190))

    # Balloon arch: fat segments in a rainbow round a superellipse; the glow strip runs inside.
    width, height, thick = 11.0, 12.4, 1.9

    def arc(t, inset=0.0):
        a = math.pi * t
        return Vector(((width - inset) * math.cos(a), 0, (height - inset) * math.sin(a) ** 0.55))

    parts = []
    count = 13
    for i in range(count):
        t0, t1 = i / count, (i + 1) / count
        pts = [arc(t0 + (t1 - t0) * j / 4) for j in range(5)]
        parts.append(k.tube(pts, [thick * 0.72, thick * 0.97, thick * 1.05, thick * 0.97, thick * 0.72], m=colours[i % 6], n=12, name="balloon"))
    for x in (-width, width):
        parts.append(k.lathe([(2.9, 0), (3.0, 0.3), (2.4, 1.0), (1.7, 1.7)], loc=(x, 0, 0), m=foot, n=16, name="foot"))
        parts.append(k.sphere(1.0, (x, 0, 2.2), m=colours[2], seg=10, rings=6, name="stud"))

    # Blank board for a SurfaceGui (START, CHECKPOINT, FINISH) on both faces.
    bz = 15.2
    parts.append(k.box((14, 1.0, 5.0), (0, 0, bz), m=frame_m, bevel=0.42, seg=2, name="frame"))
    for y in (-0.54, 0.54):
        parts.append(k.box((12.6, 0.1, 3.8), (0, y, bz), m=board, bevel=0.03, name="board"))
    for x in (-7.4, 7.4):
        parts.append(k.sphere(1.0, (x, 0, bz + 1.8), m=colours[0], seg=10, rings=6, name="ball"))

    glow_pts = [arc(i / 40, inset=thick * 1.22) for i in range(41)]
    return {"": parts, "glow": [k.tube(glow_pts, 0.38, m=strip, n=6, name="strip")]}


def dash_ready_pad():
    rim = k.paint("rp_rim", [(0, (70, 195, 205)), (1, (120, 230, 215))], 0, 1.0)
    top = k.flat(k.SNOW)
    band = k.flat((255, 150, 190))
    star_m = k.flat(k.SUNNY)
    pad_top = 0.9

    parts = [
        k.lathe([(6.0, 0), (6.0, 0.4), (5.75, 0.68), (5.4, pad_top), (0, pad_top)], m=rim, n=36, name="base"),
        k.cyl(4.9, 0.2, (0, 0, pad_top), m=band, n=32, name="ring"),
        k.cyl(4.2, 0.2, (0, 0, pad_top + 0.08), m=top, n=32, name="top"),
    ]
    # Sunny chevrons point the way in; a flower marks the middle.
    for i in range(8):
        c = k.poly([(-0.42, 0), (0.42, 0), (0.42, 0.85), (0, 1.28), (-0.42, 0.85)], 0.16, loc=(0, -5.3, pad_top + 0.1), rot=(-90, 0, 0), m=star_m, name="chevron")
        c.data.transform(k.rot_z(i * 45))
        parts.append(c)
    for ob in k.flower(2.9, k.flat((255, 170, 200)), star_m, lobes=8):
        ob.data.transform(Matrix.Translation((0, 0, pad_top + 0.18)) @ Matrix.Diagonal((1, 1, 0.22, 1)))
        parts.append(ob)
    return parts


def _island_edge(rng):
    waves = [(rng.randint(2, 7), rng.uniform(0, 6.28), rng.uniform(0.7, 1.7)) for _ in range(5)]

    def edge(a):
        return sum(h * math.sin(f * a + p) for f, p, h in waves)

    return edge


def dash_island():
    rng = random.Random(11)
    edge = _island_edge(rng)
    # Modelled round, then stretched to about 300 x 160 from above: the course runs along X.
    sx, sy, sz = 3.77, 1.93, 1.6
    stretch = Matrix.Diagonal((sx, sy, sz, 1))
    grass = k.paint("is_grass", [(0, (140, 222, 120)), (1, (176, 236, 130))], -150, 150, axis="X", dots=[((190, 242, 140), 0.05, 0.22)])
    lip = k.paint("is_lip", [(0, (120, 208, 112)), (1, (150, 226, 120))], 32, 48)
    rock = k.paint("is_rock", [(0, (214, 190, 250)), (0.42, (255, 200, 214)), (0.72, (255, 224, 180)), (1, (255, 214, 170))], 12, 48)
    basin = k.flat((150, 226, 236), name="is_basin")
    trunk = k.flat((205, 150, 105))
    crowns = [k.flat(c) for c in ((255, 180, 210), (190, 235, 150), (255, 210, 150), (200, 200, 255))]
    bush = k.flat((130, 212, 120))
    cap = k.flat((255, 120, 130))
    stem = k.flat(k.SNOW)
    water = k.paint("is_water", [(0, (190, 245, 250)), (1, (95, 210, 240))], 8, 50, axis="Z", bands=((165, 235, 248), 3.6))
    mist = k.flat(k.SNOW)
    heart = k.flat(k.SUNNY)
    petals = [k.flat(c) for c in (k.ROSE, k.SNOW, k.VIOLET, k.PEACH)]

    # Rock tapering down in ledges, a grass rim, then a shallow basin for the DashWorld water plane.
    top = 30.0
    n = 64

    def ring(r_at, z_at):
        return [(r_at(i) * math.cos(2 * math.pi * i / n), r_at(i) * math.sin(2 * math.pi * i / n), z_at(i)) for i in range(n)]

    def r(i, f=1.0, wob=0.0):
        a = 2 * math.pi * i / n
        return (37.6 + edge(a) + wob * math.sin(a * 9 + f * 8)) * f

    bm = bmesh.new()

    def loft(rings, m_index):
        made = [[bm.verts.new(p) for p in row] for row in rings]
        for low, high in zip(made, made[1:]):
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((low[i], low[j], high[j], high[i])).material_index = m_index
        return made

    under = loft(
        [
            ring(lambda i: r(i, 0.03), lambda i: 0.4 + 2.0 * math.sin(i * 0.7)),
            ring(lambda i: r(i, 0.2, 1.2), lambda i: 5 + 1.2 * math.sin(i * 1.1)),
            ring(lambda i: r(i, 0.42, 2.0), lambda i: 11 + 1.2 * math.sin(i * 0.9)),
            ring(lambda i: r(i, 0.62, 2.0), lambda i: 16 + 0.9 * math.sin(i * 1.3)),
            ring(lambda i: r(i, 0.82, 1.6), lambda i: 21 + 0.7 * math.sin(i * 1.7)),
            ring(lambda i: r(i, 1.0), lambda i: top - 2.6),
            ring(lambda i: r(i, 1.03), lambda i: top - 1.5),
        ],
        0,
    )
    loft(
        [
            ring(lambda i: r(i, 1.03), lambda i: top - 1.5),
            ring(lambda i: r(i, 1.045), lambda i: top - 0.5),
            ring(lambda i: r(i, 1.02), lambda i: top),
        ],
        1,
    )
    rim = ring(lambda i: r(i, 1.02), lambda i: top)
    shelf = loft([rim, ring(lambda i: r(i, 0.93), lambda i: top), ring(lambda i: r(i, 0.89), lambda i: top - 1.9)], 2)
    floor_ring = shelf[-1]
    middle = bm.verts.new((0, 0, top - 1.9))
    for i in range(n):
        bm.faces.new((floor_ring[i], floor_ring[(i + 1) % n], middle)).material_index = 3
    tip = bm.verts.new((0, 0, 0))
    for i in range(n):
        bm.faces.new((under[0][(i + 1) % n], under[0][i], tip)).material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    land = k._obj("land", bm, rock)
    for m in (lip, grass, basin):
        land.data.materials.append(m)
    parts = [land]

    # Hanging rock points, tip down.
    for a, rr, length, w in ((20, 19, 11, 3.6), (140, 15, 12, 3.4), (250, 21, 10, 3.6), (320, 13, 9, 3.0)):
        x, y = rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a))
        z = 11.5 + rr * 0.32
        parts.append(k.cyl(0.0, length, (x, y, z - length / 2 + 1), m=rock, n=7, r2=w, name="spire"))
    for ob in parts:
        ob.data.transform(stretch)

    top *= sz

    # Decoration stays on the rim and under 18 tall: the decks pass 22 above the pool.
    def rim_spot(a, inset):
        rad = (37.6 + edge(a)) * inset
        return Vector((rad * math.cos(a) * sx, rad * math.sin(a) * sy, top))

    for i, a in enumerate((0.4, 1.3, 2.1, 2.9, 3.9, 4.0 + 1.1, 5.9)):
        p = rim_spot(a, 0.975)
        h = rng.uniform(6, 8)
        parts.append(k.lathe([(1.5, top - 0.2), (1.0, top + 1), (0.7, top + h)], loc=(p.x, p.y, 0), m=trunk, n=9, name="trunk"))
        c = crowns[i % 4]
        parts.append(k.puff(5.2, (p.x, p.y, top + h + 3), c, scale=(1, 1, 0.9), name="crown"))
        parts.append(k.puff(3.4, (p.x + 3.4, p.y - 1.4, top + h + 1.2), c, name="crown"))
    for a in (0.9, 1.7, 2.5, 3.4, 5.5):
        p = rim_spot(a, 0.98)
        parts.append(k.puff(3.2, (p.x, p.y, top + 0.9), bush, name="bush"))
    for a in (0.15, 2.3, 5.45):
        p = rim_spot(a, 0.97)
        for ob in k.mushroom(2.0, 3.0, cap, stem):
            ob.data.transform(Matrix.Translation((p.x, p.y, top - 0.1)))
            parts.append(ob)
    for i in range(8):
        a = i * 2 * math.pi / 8 + rng.uniform(-0.1, 0.1)
        p = rim_spot(a, rng.uniform(0.95, 0.99))
        for ob in k.flower(1.6, petals[i % 4], heart, lobes=5):
            ob.data.transform(Matrix.Translation((p.x, p.y, top + 0.25)))
            parts.append(ob)

    # The pool spills off the front rim as a curtain, ending in mist.
    start = rim_spot(-math.pi / 2, 1.02)

    def curtain(u, v):
        width = 26 - 9 * v
        return (start.x + (u - 0.5) * width, start.y + 3 - 7 * min(1.0, v * 3) ** 0.5, top + 0.4 - 34 * v**1.5)

    parts.append(k.surface(4, 8, curtain, m=water, thickness=0.6, name="fall"))
    bottom = top + 0.4 - 34
    for x, s in ((-7, 3.6), (6, 4.2)):
        parts.append(k.puff(s, (start.x + x, start.y - 4, bottom), mist, name="mist"))
    return parts


GHOST = "Decor from DashWorld; no mesh collision."
ASSETS = [
    dict(name="dash_sweeper", build=dash_sweeper, budget=3000, size=[40, 12, 6], priority=2, order=1, replaces="DashFx sweeper fallback (bar and hub of parts)",
         notes="One mesh: DashFx moves the whole Model, whose pivot is its bounding box centre, and that is exactly the hub on all three axes. Arm lies along X at angle 0, 20 each side of the hub, with a post above and below. The hub sits at the pose: if at.y is the deck surface, add about 3 so the arm rides in the 0 to 6 knock band."),
    dict(name="dash_ball", build=dash_ball, budget=3000, size=[10, 10, 10], priority=2, order=2, replaces="DashFx ball fallback (Ball part)",
         notes="One mesh; bounding box centre is the ball centre, so PivotTo the pose."),
    dict(name="dash_pendulum", build=dash_pendulum, budget=3000, size=[8, 30, 8], priority=2, order=3, replaces="DashFx pendulum fallback (rod and Ball)",
         notes="One mesh, rod and bob only, because the whole Model swings. The hinge is the centre of the top face; the bob centre is 26 below it. DashFx pivots at the hinge and places the Model half its height below along the rod. The beam it hangs from is static, so it is not in this model: DashWorld needs one at the hinge height."),
    dict(name="dash_platform", build=dash_platform, budget=3000, size=[12, 2, 12], priority=2, order=4, replaces="DashFx platform fallback (Block part)",
         notes="One mesh; flat walkable top, 1 above the bounding box centre. CanCollide true (DashFx); the carry raycast finds this part."),
    dict(name="dash_arch", build=dash_arch, budget=3000, size=[28, 18, 4], priority=2, order=5, replaces="DashWorld arch fallback (parts)",
         notes="One arch for start, checkpoint and finish: tint dash_arch_glow per role and put the word on a SurfaceGui over the blank board, on both faces. Opening about 18 wide, 10 high. The barrier is a separate invisible part. " + GHOST, glow={"glow": (120, 255, 190)}),
    dict(name="dash_ready_pad", build=dash_ready_pad, budget=3000, size=[12, 1, 12], priority=2, order=6, replaces="DashWorld ready pad fallback (Cylinder part)",
         notes="Low, as section 9 asks, so no sign post: DashWorld's flat part carries the prompt and its label. " + GHOST),
    dict(name="dash_island", build=dash_island, budget=5000, size=[300, 66, 160], priority=2, order=7, replaces="None: the decks stand alone without it",
         notes="Long axis X, the course direction. The grass rim is 48 above the lowest rock and the basin floor 3 below the rim, so base.Y 70 puts the rim level with the water plane at y 118; centre it on about (-10, 350). Decoration stays on the rim, under 18 tall, below the decks at y 140. The waterfall spills off the front. " + GHOST),
]
