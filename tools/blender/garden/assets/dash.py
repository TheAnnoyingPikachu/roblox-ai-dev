"""Splash Dash: the cheerful toy obstacle kit (docs/assets/garden-blender-plan.md). Pieces that move
are separate meshes in one FBX, so code can spin or swing them: `<asset>_arm`, `<asset>_hammer`.
Courses run along Roblox Z, so the front of every piece (Blender -Y) meets an oncoming player."""

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


def dash_sweeper():
    candy = k.paint("sw_post", [(0, k.SNOW), (1, k.SNOW)], 0, 8, bands=((255, 120, 160), 1.8))
    base = k.paint("sw_base", [(0, (70, 195, 205)), (1, (130, 230, 215))], 0, 1.2)
    hub_m = k.flat(k.SUNNY)
    heart = k.flat((255, 150, 90))
    a, b = k.flat((255, 110, 130)), k.flat((255, 236, 170))
    end = k.flat(k.TEAL)
    height = 4.6

    post = [
        k.lathe([(4.2, 0), (4.3, 0.3), (3.7, 0.7), (2.0, 1.1), (1.15, 1.8), (1.0, 2.4)], m=base, n=24, name="base"),
        k.lathe([(1.0, 2.2), (0.9, 3.0), (0.86, height - 0.9), (0.98, height - 0.8), (0.98, height + 2.4), (0.78, height + 2.8), (0, height + 3.0)], m=candy, n=16, name="post"),
    ]

    # The arm is symmetric about the axis so its bounding box centre is the spin centre.
    half = 12.0
    tip = 1.45
    span = half - tip
    path = [(span * (i / 12 - 1) * 1.0, 0, height) for i in range(25)]
    radii = [1.02 + 0.3 * abs(math.cos(i * math.pi / 3)) for i in range(25)]
    arm = _pad(path, radii, a, b, every=2)
    for x in (-span, span):
        arm.append(k.sphere(tip, (x, 0, height), m=end, scale=(1, 1, 1), seg=14, rings=8, name="bumper"))
    arm.append(k.lathe([(1.9, -1.15), (2.05, -0.6), (2.05, 0.6), (1.9, 1.15)], loc=(0, 0, height), rot=(90, 0, 0), m=hub_m, n=20, name="hub"))
    for y in (-1.15, 1.15):
        f = k.flower(1.5, k.flat((255, 170, 120)), heart, lobes=6)
        turn = Matrix.Translation((0, y, height)) @ Matrix.Rotation(math.radians(90 if y < 0 else -90), 4, "X")
        for ob in f:
            ob.data.transform(turn)
        arm += f
    return {"": post, "arm": arm}


def dash_ball():
    shell_m = k.paint("ba_shell", [(0, (255, 150, 90)), (0.5, (255, 130, 130)), (1, (255, 120, 175))], 0, 12)
    spot = k.flat(k.BUTTER)
    spot2 = k.flat(k.SKY)
    valve = k.flat((240, 240, 250))
    parts = [k.sphere(6, (0, 0, 6), m=shell_m, seg=32, rings=18, name="ball")]
    # Fibonacci spread of raised dots, so no axis looks bald as it rolls.
    count = 22
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(count):
        z = 1 - 2 * (i + 0.5) / count
        r = math.sqrt(1 - z * z)
        n = Vector((r * math.cos(i * golden), r * math.sin(i * golden), z))
        size = 1.2 if i % 3 else 0.85
        cap = k.lathe([(size, -0.3), (size * 0.95, 0.08), (0, 0.17)], m=spot2 if i % 2 else spot, n=14, name="dot")
        cap.data.transform(
            Matrix.Translation(n * 5.92 + Vector((0, 0, 6))) @ Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
        )
        parts.append(cap)
    parts.append(k.lathe([(0.34, -0.2), (0.3, 0.18), (0.16, 0.34), (0, 0.36)], loc=(0, 0, 11.92), m=valve, n=10, name="valve"))
    return parts


def dash_pendulum():
    leg = k.paint("pe_leg", [(0, k.SNOW), (1, k.SNOW)], 0, 18, bands=((110, 200, 240), 2.4))
    beam_m = k.paint("pe_beam", [(0, (120, 215, 240)), (1, (120, 215, 240))], -12, 12, axis="X", bands=(k.SNOW, 4.0))
    foot = k.paint("pe_foot", [(0, (70, 195, 205)), (1, (130, 230, 215))], 0, 1.5)
    ball = k.flat(k.SUNNY)
    a, b = k.flat((255, 110, 130)), k.flat((255, 236, 170))
    rod = k.flat((255, 196, 96))
    cap = k.flat(k.TEAL)

    span, top = 22.0, 18.0
    frame = [k.tube([(-span / 2, 0, top), (span / 2, 0, top)], 1.0, m=beam_m, n=14, name="beam")]
    for x in (-span / 2, span / 2):
        frame.append(k.lathe([(2.6, 0), (2.7, 0.3), (2.0, 0.9), (1.05, 1.5)], loc=(x, 0, 0), m=foot, n=18, name="foot"))
        frame.append(k.tube([(x, 0, 0.8), (x, 0, top)], 0.92, m=leg, n=14, name="leg"))
        frame.append(k.sphere(1.5, (x, 0, top), m=ball, seg=14, rings=8, name="knob"))
    frame.append(k.lathe([(1.3, -1.5), (1.45, -1.1), (1.45, 1.1), (1.3, 1.5)], loc=(0, 0, top), rot=(90, 0, 0), m=ball, n=18, name="axle"))

    # The hammer hangs from the axle at (0, 0, top); it swings across the course, along X.
    head_z = 5.2
    hub = k.lathe([(0.9, -1.0), (1.0, -0.8), (1.0, 0.8), (0.9, 1.0)], loc=(0, 0, top), rot=(90, 0, 0), m=rod, n=16, name="hub")
    arm = k.tube([(0, 0, top), (0, 0, head_z + 2)], 0.5, m=rod, n=10, name="rod")
    path = [(-4.2 + 8.4 * i / 16, 0, head_z) for i in range(17)]
    radii = [2.1 + 0.34 * abs(math.cos(i * math.pi / 4)) for i in range(17)]
    head = _pad(path, radii, a, b, every=2, n=16)
    for x in (-4.5, 4.5):
        head.append(k.sphere(2.0, (x, 0, head_z), m=cap, scale=(0.72, 1, 1), seg=16, rings=9, name="bumper"))
    for y in (-2.3, 2.3):
        f = k.flower(1.3, k.flat(k.SNOW), k.flat(k.SUNNY), lobes=6)
        turn = Matrix.Translation((0, y, head_z)) @ Matrix.Rotation(math.radians(90 if y < 0 else -90), 4, "X")
        for ob in f:
            ob.data.transform(turn)
        head += f
    return {"": frame, "hammer": [hub, arm] + head}


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
    top = 4.2
    deck = k.paint("pl_deck", [(0, (255, 224, 110)), (1, (255, 240, 170))], 0, 5.6, dots=[((255, 200, 90), 0.9, 0.2)])
    petal_a = k.paint("pl_a", [(0, (255, 200, 225)), (1, (255, 120, 170))], -8, 8, axis="X")
    petal_b = k.paint("pl_b", [(0, (255, 120, 170)), (1, (255, 200, 225))], -8, 8, axis="X")
    under = k.paint("pl_under", [(0, (255, 110, 165)), (1, (255, 95, 150))], 2, 4)
    leaf_m = k.paint("pl_leaf", [(0, (95, 195, 105)), (1, (150, 228, 120))], 0, 3)
    stem = k.paint("pl_stem", [(0, (95, 185, 100)), (1, (140, 215, 110))], 0, 3.6)

    parts = [
        k.cyl(5.6, 0.5, (0, 0, top - 0.24), m=deck, n=32, name="deck"),
        k.lathe([(5.6, top - 0.5), (4.6, top - 1.4), (1.5, top - 2.5), (1.0, top - 3)], m=under, n=24, name="bowl"),
        k.lathe([(1.5, 0), (1.3, 0.3), (0.9, 1.0), (1.0, 2.2), (1.5, 2.8)], m=stem, n=14, name="stem"),
    ]
    # Upper petals lie flush with the deck, so the top is one flat walkable surface; a lower ring
    # sits under the gaps.
    count = 9
    for i in range(count):
        a = i * 360 / count
        parts.append(_petal(4.6, 2.5, 0.7, petal_a if i % 2 else petal_b, a, top - 0.02, 3.4))
        parts.append(_petal(4.3, 2.3, 0.6, under, a + 180 / count, top - 0.7, 3.2))
    for i, a in enumerate((20, 140, 262)):
        blade = k.leaf(8.0, 1.9, leaf_m, droop=-0.04, n=8, steps=7, name="sepal")
        blade.data.transform(Matrix.Translation((0, 0, 1.1)) @ k.rot_z(a) @ Matrix.Diagonal((1, 1, 0.55, 1)) @ Matrix.Rotation(math.radians(-14), 4, "Y"))
        parts.append(blade)
    return parts


def dash_arch():
    colours = [k.flat(c) for c in ((255, 130, 150), (255, 190, 110), (255, 232, 130), (130, 225, 160), (110, 205, 240), (190, 160, 255))]
    board = k.paint("ar_board", [(0, k.SNOW), (1, k.SNOW)], 0, 1)
    frame_m = k.flat((255, 196, 96))
    foot = k.paint("ar_foot", [(0, (70, 195, 205)), (1, (130, 230, 215))], 0, 2)
    strip = k.glow((120, 255, 190))

    # Balloon arch: fat segments in a rainbow round a superellipse; the glow strip runs inside.
    width, height, thick = 11.4, 15.2, 1.9

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
        parts.append(k.lathe([(3.1, 0), (3.2, 0.3), (2.5, 1.0), (1.7, 1.7)], loc=(x, 0, 0), m=foot, n=16, name="foot"))
        parts.append(k.sphere(1.0, (x, 0, 2.2), m=colours[2], seg=10, rings=6, name="stud"))

    # Blank board for a SurfaceGui (START, CHECKPOINT, FINISH) on both faces.
    bz = height + 2.6
    parts.append(k.box((14, 1.0, 5.0), (0, 0, bz), m=frame_m, bevel=0.42, seg=2, name="frame"))
    for y in (-0.54, 0.54):
        parts.append(k.box((12.6, 0.1, 3.8), (0, y, bz), m=board, bevel=0.03, name="board"))
    for x in (-7.4, 7.4):
        parts += [k.sphere(1.0, (x, 0, bz + 1.8), m=colours[0], seg=10, rings=6, name="ball")]

    glow_pts = [arc(i / 40, inset=thick * 1.22) for i in range(41)]
    return {"": parts, "glow": [k.tube(glow_pts, 0.38, m=strip, n=6, name="strip")]}


def dash_ready_pad():
    rim = k.paint("rp_rim", [(0, (70, 195, 205)), (1, (120, 230, 215))], 0, 1.2)
    top = k.flat(k.SNOW)
    band = k.flat((255, 150, 190))
    star_m = k.flat(k.SUNNY)
    post_m = k.paint("rp_post", [(0, k.SNOW), (1, k.SNOW)], 0, 11, bands=((255, 150, 190), 1.6))
    board = k.flat(k.SNOW)
    frame_m = k.flat((255, 196, 96))
    pad_top = 1.1

    parts = [
        k.lathe([(7.0, 0), (7.0, 0.5), (6.7, 0.8), (6.3, pad_top - 0.1), (0, pad_top - 0.1)], m=rim, n=36, name="base"),
        k.cyl(5.7, 0.2, (0, 0, pad_top - 0.1), m=band, n=32, name="ring"),
        k.cyl(4.9, 0.2, (0, 0, pad_top - 0.02), m=top, n=32, name="top"),
    ]
    # Sunny chevrons point the way in; a flower marks the middle.
    for i in range(8):
        a = i * 45
        c = k.poly([(-0.5, 0), (0.5, 0), (0.5, 1.0), (0, 1.5), (-0.5, 1.0)], 0.16, loc=(0, -6.0, pad_top + 0.0), rot=(-90, 0, 0), m=star_m, name="chevron")
        c.data.transform(k.rot_z(a))
        parts.append(c)
    for ob in k.flower(3.4, k.flat((255, 170, 200)), star_m, lobes=8):
        ob.data.transform(Matrix.Translation((0, 0, pad_top + 0.08)) @ Matrix.Diagonal((1, 1, 0.3, 1)))
        parts.append(ob)
    # Sign post at the back; the board faces the front for a SurfaceGui.
    y = 5.8
    parts.append(k.cyl(0.42, 9.6, (0, y, 4.8), m=post_m, n=12, name="post"))
    parts.append(k.lathe([(0.9, 0), (0.9, 1.3), (0.6, 1.5)], loc=(0, y, 0.0), m=frame_m, n=12, name="collar"))
    parts.append(k.box((7.4, 0.6, 3.9), (0, y - 0.1, 8.0), m=frame_m, bevel=0.3, seg=2, name="sign"))
    parts.append(k.box((6.4, 0.08, 2.9), (0, y - 0.42, 8.0), m=board, bevel=0.02, name="face"))
    parts.append(k.sphere(0.72, (0, y, 10.5), m=band, seg=12, rings=7, name="knob"))
    return parts


def _island_edge(rng):
    waves = [(rng.randint(2, 7), rng.uniform(0, 6.28), rng.uniform(0.7, 1.7)) for _ in range(5)]

    def edge(a):
        return sum(h * math.sin(f * a + p) for f, p, h in waves)

    return edge


def dash_island():
    rng = random.Random(11)
    edge = _island_edge(rng)
    grass = k.paint("is_grass", [(0, (140, 222, 120)), (1, (176, 236, 130))], -40, 40, axis="X", dots=[((190, 242, 140), 0.09, 0.25)])
    lip = k.paint("is_lip", [(0, (120, 208, 112)), (1, (150, 226, 120))], 20, 32)
    rock = k.paint("is_rock", [(0, (214, 190, 250)), (0.42, (255, 200, 214)), (0.72, (255, 224, 180)), (1, (255, 214, 170))], 8, 30)
    trunk = k.flat((205, 150, 105))
    crowns = [k.flat(c) for c in ((255, 180, 210), (190, 235, 150), (255, 210, 150), (200, 200, 255))]
    bush = k.flat((130, 212, 120))
    cap = k.flat((255, 120, 130))
    stem = k.flat(k.SNOW)
    water = k.paint("is_water", [(0, (190, 245, 250)), (1, (95, 210, 240))], 5, 32, axis="Z", bands=((165, 235, 248), 2.4))
    heart = k.flat(k.SUNNY)
    petals = [k.flat(c) for c in (k.ROSE, k.SNOW, k.VIOLET, k.PEACH)]

    # Top sheet, grass lip, then rock tapering down in ledges to a few hanging points.
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
                face = bm.faces.new((low[i], low[j], high[j], high[i]))
                face.material_index = m_index
        return made

    under = loft(
        [
            ring(lambda i: r(i, 0.03), lambda i: 0.4 + 2.0 * math.sin(i * 0.7)),
            ring(lambda i: r(i, 0.2, 1.2), lambda i: 5 + 1.2 * math.sin(i * 1.1)),
            ring(lambda i: r(i, 0.42, 2.0), lambda i: 11 + 1.2 * math.sin(i * 0.9)),
            ring(lambda i: r(i, 0.62, 2.0), lambda i: 16 + 0.9 * math.sin(i * 1.3)),
            ring(lambda i: r(i, 0.78, 1.6), lambda i: 20 + 0.7 * math.sin(i * 1.7)),
            ring(lambda i: r(i, 0.92, 1.0), lambda i: 25 + 0.5 * math.sin(i * 0.8)),
            ring(lambda i: r(i, 1.0), lambda i: top - 2.6),
            ring(lambda i: r(i, 1.03), lambda i: top - 1.5),
        ],
        0,
    )
    grassy = loft(
        [
            ring(lambda i: r(i, 1.03), lambda i: top - 1.5),
            ring(lambda i: r(i, 1.045), lambda i: top - 0.5),
            ring(lambda i: r(i, 1.02), lambda i: top),
            ring(lambda i: r(i, 0.96), lambda i: top),
        ],
        1,
    )
    cap_ring = grassy[-1]
    middle = bm.verts.new((0, 0, top))
    for i in range(n):
        bm.faces.new((cap_ring[i], cap_ring[(i + 1) % n], middle)).material_index = 2
    tip = bm.verts.new((0, 0, 0))
    for i in range(n):
        bm.faces.new((under[0][(i + 1) % n], under[0][i], tip)).material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    land = k._obj("land", bm, rock)
    land.data.materials.append(lip)
    land.data.materials.append(grass)
    parts = [land]

    # Hanging rock points.
    for i, (a, rr, length, w) in enumerate(((20, 19, 11, 3.6), (140, 15, 12, 3.4), (250, 21, 10, 3.6), (320, 13, 9, 3.0))):
        x, y = rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a))
        z = 11.5 + rr * 0.32
        parts.append(k.cyl(w, length, (x, y, z - length / 2 + 1), m=rock, n=7, r2=0.0, name="spire"))
        parts[-1].data.transform(Matrix.Translation((0, 0, 0)))
    # Flip each point so the tip hangs down.
    for ob in parts[1:]:
        lo = min(v.co.z for v in ob.data.vertices)
        hi = max(v.co.z for v in ob.data.vertices)
        for v in ob.data.vertices:
            v.co.z = lo + hi - v.co.z

    # Decoration stays on the rim, so the middle can carry the course.
    def rim_spot(a, inset):
        rad = (37.6 + edge(a)) * inset
        return Vector((rad * math.cos(a), rad * math.sin(a), top))

    for i, a in enumerate((0.5, 1.6, 2.7, 3.9, 5.2)):
        p = rim_spot(a, 0.84)
        h = rng.uniform(7, 10)
        parts.append(k.lathe([(1.5, top - 0.2), (1.0, top + 1), (0.7, top + h)], loc=(p.x, p.y, 0), m=trunk, n=9, name="trunk"))
        c = crowns[i % 4]
        parts.append(k.puff(5.2, (p.x, p.y, top + h + 2), c, scale=(1, 1, 0.9), name="crown"))
        parts.append(k.puff(3.4, (p.x + 3.4, p.y - 1.4, top + h + 0.2), c, name="crown"))
        parts.append(k.puff(3.0, (p.x - 3.2, p.y + 1.6, top + h + 0.6), c, name="crown"))
    for a in (1.0, 2.2, 3.3, 5.8):
        p = rim_spot(a, 0.88)
        parts.append(k.puff(3.0, (p.x, p.y, top + 0.8), bush, name="bush"))
        parts.append(k.puff(2.0, (p.x + 2.8, p.y + 1, top + 0.4), bush, name="bush"))
    for a in (0.9, 2.0, 5.5):
        p = rim_spot(a, 0.8)
        for ob in k.mushroom(2.0, 3.0, cap, stem):
            ob.data.transform(Matrix.Translation((p.x, p.y, top - 0.1)))
            parts.append(ob)
    for i in range(8):
        a = i * 2 * math.pi / 8 + rng.uniform(-0.1, 0.1)
        p = rim_spot(a, rng.uniform(0.7, 0.94))
        for ob in k.flower(1.5, petals[i % 4], heart, lobes=5):
            ob.data.transform(Matrix.Translation((p.x, p.y, top + 0.25)))
            parts.append(ob)

    # A pond at the front rim spills off the edge as a curtain, ending in mist.
    start = rim_spot(-math.pi / 2, 1.0)
    pond = rim_spot(-math.pi / 2, 0.84)
    parts.append(k.cyl(7.5, 0.2, (pond.x, pond.y, top + 0.02), m=water, n=16, name="pond"))
    parts[-1].data.transform(Matrix.Translation((pond.x, pond.y, 0)) @ Matrix.Diagonal((1, 0.8, 1, 1)) @ Matrix.Translation((-pond.x, -pond.y, 0)))

    def curtain(u, v):
        width = 8.5 - 3.0 * v
        return (start.x + (u - 0.5) * width, start.y + 5 - 8.5 * min(1.0, v * 3) ** 0.5, top + 0.3 - 21 * v**1.5)

    parts.append(k.surface(4, 8, curtain, m=water, thickness=0.5, name="fall"))
    bottom = top + 0.3 - 21
    for x, r in ((-2.4, 2.3), (2.2, 2.6)):
        parts.append(k.puff(r, (start.x + x, start.y - 3.5, bottom), k.flat(k.SNOW), name="mist"))
    return parts


GHOST = "Decorative: keep part collision for play, mesh CanCollide false."
ASSETS = [
    dict(name="dash_sweeper", build=dash_sweeper, budget=3000, size=[24, 8, 24], priority=2, order=1, replaces="New: Splash Dash mini-game",
         notes="dash_sweeper_arm is 24 long and symmetric, so its bounding box centre is the spin axis. Spin it about Y in code; weld nothing to the post."),
    dict(name="dash_ball", build=dash_ball, budget=3000, size=[12, 12, 12], priority=2, order=2, replaces="New: Splash Dash mini-game",
         notes="Roll or bounce it as a Ball part with this mesh welded; keep the mesh CanCollide false."),
    dict(name="dash_pendulum", build=dash_pendulum, budget=3000, size=[24, 19, 3], priority=2, order=3, replaces="New: Splash Dash mini-game",
         notes="dash_pendulum_hammer hangs from the axle: pivot it about the Z axis through the hub, 1 stud (at height scale 1) below the top of the hammer mesh's bounding box. Swings along X, across the course."),
    dict(name="dash_platform", build=dash_platform, budget=3000, size=[16, 4.2, 16], priority=2, order=4, replaces="New: Splash Dash mini-game",
         notes="Flat walkable top at the top of the mesh. Use an invisible 16-wide cylinder for collision at that height."),
    dict(name="dash_arch", build=dash_arch, budget=3000, size=[28, 21, 4.5], priority=2, order=5, replaces="New: Splash Dash mini-game",
         notes="One arch for start, checkpoint and finish: tint dash_arch_glow per role, and put the word on a SurfaceGui over the blank board, on both faces. Opening about 19 wide. " + GHOST, glow={"glow": (120, 255, 190)}),
    dict(name="dash_ready_pad", build=dash_ready_pad, budget=3000, size=[14, 11, 14], priority=2, order=6, replaces="New: Splash Dash plaza ready pad",
         notes="Blank sign board faces the front for a SurfaceGui. " + GHOST),
    dict(name="dash_island", build=dash_island, budget=5000, size=[80, 45, 80], priority=2, order=7, replaces="New: Splash Dash floating island base",
         notes="Grass top is flat at 30 studs above the lowest rock; decoration stays near the rim. The waterfall spills off the front. " + GHOST),
]
