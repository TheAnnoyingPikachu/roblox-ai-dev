"""Ten Egg Garden creatures (batch B) to the HD standard (tools/blender/garden/README.md "Creature
standard"): one fused body per colour, the kit face, smooth separate props. One mesh each, standing
on the origin, facing Blender -Y. Second colours on a fused body (hooves, quill coat, galaxy back,
whale belly) are cut along a plane (`split`), so the edge is clean and sits exactly where placed."""

import math

import bmesh
import kit as k
from mathutils import Matrix, Vector

INK = k.INKY
DARK = (48, 40, 56)
WHITE = k.SNOW
CHEEK = (255, 160, 180)


# Pre-HD helpers: v04.py (moth) and v05_exclusives.py import these; keep them unchanged -----------


def outward(theta, phi):
    """Unit vector: theta degrees round from the front (-Y, positive towards +X), phi up."""
    t, p = math.radians(theta), math.radians(phi)
    return Vector((math.sin(t) * math.cos(p), -math.cos(t) * math.cos(p), math.sin(p)))


def stud(centre, R, theta, phi, r, m, lift=0.0, flat=0.55, seg=8, rings=5, scale=(1, 1, 1), name="stud"):
    """A flattened sphere stuck to the surface of a (scaled) sphere: eyes, noses, cheeks, spots."""
    d = outward(theta, phi)
    p = Vector(centre) + Vector((d.x * R * scale[0], d.y * R * scale[1], d.z * R * scale[2])) + d * lift
    ob = k.sphere(r, m=m, scale=(1, 1, flat), seg=seg, rings=rings, name=name)
    ob.data.transform(Matrix.Translation(p) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
    return ob


def eyes(centre, R, theta=28, phi=6, r=0.2, iris=DARK, scale=(1, 1, 1), lift=0.0):
    """Big round eyes with a highlight dot, mirrored about x."""
    parts = []
    for s in (1, -1):
        parts.append(stud(centre, R, s * theta, phi, r, k.flat(iris), lift=lift, flat=0.5, scale=scale, name="eye"))
        parts.append(stud(centre, R, s * theta - 4 * s, phi + 7, r * 0.36, k.flat(WHITE), lift=lift + r * 0.42, flat=0.5, seg=6, rings=4, scale=scale, name="glint"))
    return parts


def cheeks(centre, R, theta=48, phi=-14, r=0.17, scale=(1, 1, 1)):
    return [stud(centre, R, s * theta, phi, r, k.flat(CHEEK), flat=0.35, seg=8, rings=4, scale=scale, name="cheek") for s in (1, -1)]


def blob(r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), seg=14, rings=9, name="blob"):
    return k.sphere(r, loc, rot=rot, m=m, scale=scale, seg=seg, rings=rings, name=name)


def leg(x, y, h, r, m, hoof=None, hoof_h=0.3, n=8):
    """Rounded stubby leg standing on z = 0, optional hoof colour at the foot."""
    parts = [k.lathe([(r * 0.8, 0.0), (r, h * 0.12), (r, h), (r * 0.6, h * 1.1), (0, h * 1.15)], loc=(x, y, 0), m=m, n=n, name="leg")]
    if hoof:
        parts.append(k.lathe([(r * 0.86, 0.0), (r * 1.06, hoof_h * 0.3), (r * 1.06, hoof_h), (0, hoof_h + 0.02)], loc=(x, y, 0), m=hoof, n=n, name="hoof"))
    return parts


def placed(objs, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Moves objects built at the origin (local +Z up) with a translate, degrees rotation, scale."""
    objs = objs if isinstance(objs, (list, tuple)) else [objs]
    for ob in objs:
        ob.data.transform(k._xf(loc, rot, scale))
    return objs


def aim(objs, loc, direction, spin=0.0, scale=1.0):
    """Moves objects built at the origin so local +Z points along `direction`."""
    direction = Vector(direction).normalized()
    m = Matrix.Translation(loc) @ Vector((0, 0, 1)).rotation_difference(direction).to_matrix().to_4x4() @ k.rot_z(spin) @ Matrix.Scale(scale, 4)
    objs = objs if isinstance(objs, (list, tuple)) else [objs]
    for ob in objs:
        ob.data.transform(m)
    return objs


# HD helpers -----------------------------------------------------------------------------------


def xf(obs, loc=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0, mirror=False):
    """Moves parts built at the origin along +X (leaves): roll about X, pitch (the +X tip rises),
    yaw about Z, then to loc. mirror flips the result through x = 0 (loc included)."""
    m = Matrix.Translation(Vector(loc)) @ k.rot_z(yaw) @ Matrix.Rotation(math.radians(-pitch), 4, "Y") @ Matrix.Rotation(math.radians(roll), 4, "X")
    if mirror:
        m = Matrix.Diagonal((-1, 1, 1, 1)) @ m
    obs = obs if isinstance(obs, (list, tuple)) else [obs]
    for ob in obs:
        ob.data.transform(m)
    return obs


def onto(objs, target, centre, d, up=(0, 0, 1), spin=0.0, sink=0.0):
    """Moves objects built at the origin facing +Z onto `target`'s real surface (k.land)."""
    p, n = k.land(target, centre, d)
    x, y, z = k._frame(n, up)
    m = Matrix.Translation(p - z * sink) @ Matrix((x, y, z)).transposed().to_4x4() @ k.rot_z(spin)
    objs = objs if isinstance(objs, (list, tuple)) else [objs]
    for ob in objs:
        ob.data.transform(m)
    return objs


def fit(target):
    """Scales the finished creature to its target [x, height, depth] studs (Roblox order)."""

    def wrap(build):
        def built():
            parts = build()
            lo, hi = k._ground_dims(parts)
            d = hi - lo
            s = (target[0] / d.x, target[2] / d.y, target[1] / d.z)
            tris = sum(k._tris(ob) for ob in parts)  # over k.CREATURE_BUDGET, finalize silently decimates
            print(f"[creatures_b] {build.__name__} fit scale x {s[0]:.2f} y {s[1]:.2f} z {s[2]:.2f}, {tris} tris", flush=True)
            for ob in parts:
                ob.data.transform(Matrix.Diagonal((*s, 1)))
            return parts

        return built

    return wrap


def split(ob, m, co, no, where=None):
    """Gives the faces of `ob` on the +no side of the plane through co the material m, cutting the
    faces along the plane first (a clean edge, not a jagged face boundary). where(point): only
    faces whose centre passes it."""
    mats = ob.data.materials
    if m.name not in [x.name for x in mats]:
        mats.append(m)
    index = [x.name for x in mats].index(m.name)
    co, no = Vector(co), Vector(no).normalized()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
    for f in bm.faces:
        p = f.calc_center_median()
        if (p - co).dot(no) > 0 and (where is None or where(p)):
            f.material_index = index
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def curve(points, step=0.25):
    """Smooth points through `points` (Catmull-Rom), about `step` studs apart."""
    p = [Vector(x) for x in points]
    p = [p[0]] + p + [p[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1 : i + 3]
        steps = max(1, round((p2 - p1).length / step))
        for j in range(steps):
            t = j / steps
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(p[-2])
    return out


def chain(points, r0, r1, step=0.25):
    """Fuse capsules along a smooth curve, radius r0 to r1: tails and arms without beads."""
    pts = curve(points, step)
    rs = [r0 + (r1 - r0) * i / (len(pts) - 1) for i in range(len(pts))]
    return [("capsule", tuple(a), tuple(b), (ra + rb) / 2) for a, b, ra, rb in zip(pts, pts[1:], rs, rs[1:])]


def petals(lobes, depth=0.45, power=0.6):
    """Rim shape for `disc`: `lobes` round petals, notches `depth` deep."""
    return lambda a: 1 - depth + depth * abs(math.cos(lobes * a / 2)) ** power


def clover(a):
    """Four heart-shaped leaves."""
    return 0.15 + 0.85 * abs(math.sin(2 * a)) ** 0.5 * (1 - 0.4 * (1 - abs(math.sin(4 * a))) ** 4)


def star(a):
    return 0.48 + 0.52 * abs(math.cos(5 * a / 2)) ** 2.5


def disc(r, shape, m, heart=None, n=32, cup=0.15, thick=0.12, hr=0.26, dome=0.12, closed=True, name="disc"):
    """Flat lobed piece at the origin facing +Z (flowers, clover, lily pad, star, spots): rim at
    r * shape(angle), a lens `thick` r thick in the middle, the rim cupped `cup` r up. `heart`: a
    second colour on a domed middle hr r across. closed=False leaves the underside open, for pieces
    set into a surface. 3n triangles on top (5n with a heart), n underneath."""
    bm = bmesh.new()
    angles = [2 * math.pi * i / n for i in range(n)]

    def z(t):
        return r * (cup * t * t + thick * (1 - t * t))

    def ring(radius, h):
        return [bm.verts.new((radius(a) * math.cos(a), radius(a) * math.sin(a), h)) for a in angles]

    rings = [ring(lambda a: r * shape(a), r * cup), ring(lambda a: r * (hr + 0.55 * (shape(a) - hr)), z(0.6))]
    if heart:
        rings.append(ring(lambda a: r * hr, z(hr)))
    top = bm.verts.new((0, 0, z(0) + (r * dome if heart else 0)))
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(n):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], top)).material_index = 1 if heart else 0
    if closed:
        bottom = bm.verts.new((0, 0, -r * thick * 0.4))
        for i in range(n):
            bm.faces.new((rings[0][(i + 1) % n], rings[0][i], bottom))
    ob = k._obj(name, bm, m)
    if heart:
        ob.data.materials.append(heart)
    return ob


def flame(root, tip, r, m, bend=0.15, n=12, name="flame"):
    """Flame tongue from root to tip: an S-curve, fattest a third of the way, to a point."""
    root, tip = Vector(root), Vector(tip)
    along = tip - root
    side = along.cross(Vector((0, 0, 1)))
    side = (side if side.length > 1e-3 else Vector((1, 0, 0))).normalized() * along.length * bend
    ts = [i / 8 for i in range(9)]
    pts = [root + along * t + side * math.sin(t * math.pi * 1.5) for t in ts]
    radii = [r * math.sin(math.pi * (0.3 + 0.7 * t)) ** 0.8 for t in ts]
    return k.tube(pts, radii, m=m, n=n, name=name)


def horn(base, d, length, r0, m, n=16, rings=14, name="horn"):
    """Twisted horn: three ridges spiralling round a taper to a soft point."""
    bm = bmesh.new()
    angles = [2 * math.pi * i / n for i in range(n)]
    loops = []
    for i in range(rings):
        t = i / rings
        rad = r0 * (1 - t) ** 0.85
        loops.append([bm.verts.new((rad * (1 + 0.13 * math.sin(3 * a + 8 * t)) * math.cos(a), rad * (1 + 0.13 * math.sin(3 * a + 8 * t)) * math.sin(a), length * t)) for a in angles])
    tip, foot = bm.verts.new((0, 0, length)), bm.verts.new((0, 0, 0))
    for a, b in zip(loops, loops[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((loops[-1][i], loops[-1][j], tip))
        bm.faces.new((loops[0][j], loops[0][i], foot))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = k._obj(name, bm, m)
    return aim(ob, base, d)[0]


def toward(loc, d, r, scale):
    """Fuse ellipsoid at loc with its local z axis along d."""
    e = Vector((0, 0, 1)).rotation_difference(Vector(d)).to_euler("XYZ")
    return (tuple(loc), r, scale, tuple(math.degrees(a) for a in e))


def snout_face(body, head, R, snout, skin, mouth_w, nostril=0.065, phi=8, spread=36):
    """Snouted species: eyes just above the snout line, nostrils and a smile on the snout."""
    ink = k.flat(INK)
    parts = [k.lens(body, snout, k.outward(s * 20, 14), nostril, ink, thick=0.5, sink=0.5, seg=12, name="nostril") for s in (-1, 1)]
    parts.append(k.mouth(body, snout, k.outward(0, -32), mouth_w, ink, "smile"))
    k.texel(parts, k.FACE_TEXEL)
    return parts + k.face(body, head, R, skin=skin, nose=None, mouth_kind=None, eye_phi=phi, spread=spread)


def ears_in(body, ears, axis_tilt, m, r, lean=(0, -1, 0)):
    """Inner ears: k.lens on each ear's front, along the ear's axis."""
    parts = []
    for side in (-1, 1):
        x, y, z = ears
        t = math.radians(axis_tilt)
        axis = (side * math.sin(t), 0, math.cos(t))
        parts.append(k.lens(body, (side * x, y, z), lean, r, m, scale=(0.34, 1), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    return parts


# Puddle Duckling (common) ---------------------------------------------------------------------


def creature_duck():
    """Remade from the Roblox AI reference (assets/garden/refs/duck_*.jpg): a round butter-yellow
    fluffy duckling, a huge head over a round body, a wide smiling orange bill, big dark-navy eyes,
    small wing stubs held forward, a tail tuft, and a blue raindrop on its head (the "Puddle
    Duckling")."""
    yellow = k.paint("du_body", [(0, (226, 176, 92)), (0.45, (248, 214, 132)), (1, (255, 234, 166))], 0, 2.8, rest=True, grain=(0.06, 14))
    orange, orange_lo = k.flat((246, 132, 52)), k.flat((222, 104, 40))
    head, R = Vector((0, -0.05, 1.8)), 0.92
    body = k.fuse(
        [
            (head, R, (1.1, 0.98, 0.95)),
            *k.pair((0.5, -0.3, 1.5), 0.45, (1.0, 0.85, 0.8)),  # full cheeks
            ((0, 0.1, 0.72), 0.82, (1.1, 1.05, 0.85)),  # round body
            ((0, 0.92, 0.72), 0.3, (0.85, 0.9, 0.6), (35, 0, 0)),  # tail tuft, tipped up
            *k.pair((0.86, -0.2, 0.86), 0.3, (0.6, 0.85, 0.9), (0, 0, 30)),  # wing stubs, held forward
        ],
        yellow,
        tris=3200,
    )
    parts = [body]
    p, n = k.land(body, head, k.outward(0, -18))
    upper = k.sphere(0.36, p + n * 0.04, rot=(-12, 0, 0), m=orange, scale=(1.25, 0.6, 0.36), seg=28, rings=14, name="bill")
    lower = k.sphere(0.3, p + n * 0.02 - Vector((0, 0, 0.1)), rot=(-12, 0, 0), m=orange_lo, scale=(1.15, 0.55, 0.3), seg=24, rings=12, name="bill_lo")
    parts += k.texel([upper, lower], k.FACE_TEXEL)
    # The raindrop on the right of the head (+X), a soft point upwards.
    p, n = k.land(body, head, k.outward(48, 40))
    root = p - n * 0.04
    parts.append(k.capsule(root, root + (n + Vector((0, 0, 1.2))).normalized() * 0.26, 0.12, 0.015, k.flat((118, 186, 240)), n=16, name="drop"))
    parts += k.face(body, head, R, skin=(248, 226, 160), iris=(26, 30, 70), nose=None, mouth_kind=None, eye_r=0.24, eye_wide=0.9, spread=32, eye_phi=-2, sheen=True, blush_theta=48, blush_phi=-18)
    return parts


# Clover Lamb (uncommon) -----------------------------------------------------------------------


def creature_lamb():
    """Remade from the Roblox AI reference (assets/garden/refs/lamb_*.jpg): a big cloud of white
    fleece round a peach face, peach ears out to the sides, a small fleece body on peach stubs,
    and a four-leaf clover on the left of its head (the "Clover Lamb")."""
    skin_rgb = (248, 216, 200)
    skin = k.paint("la_skin", [(0, (232, 170, 156)), (0.5, (244, 200, 184)), (1, skin_rgb)], 0, 2.6, rest=True)
    fleece = k.paint("la_fleece", [(0, (222, 214, 208)), (0.5, (244, 238, 232)), (1, (255, 251, 244))], 0.2, 3.4, rest=True)
    green = k.flat((76, 176, 76))
    head, R = Vector((0, -0.08, 2.2)), 0.84
    ear = (1.08, -0.05, 2.12)
    face_body = k.fuse(
        [
            (head, R, (1.08, 0.92, 0.95)),
            *k.pair(ear, 0.38, (1.0, 0.5, 0.42), (0, 15, -10)),  # ears out to the sides, drooping
            *k.pair((0.84, -0.12, 0.66), 0.18, (0.9, 0.9, 1.6), (0, -14, 0)),  # arm stubs, outside the fleece
            *k.pair((0.28, -0.18, 0.1), 0.18, (1.0, 1.25, 0.6)),  # feet
        ],
        skin,
        tris=1700,
    )
    k.zone(skin, (240, 170, 170), (1.25, -0.1, 2.06), (0.3, 0.4, 0.3), soft=0.4)  # pinker ear tips
    k.zone(skin, (240, 170, 170), (-1.25, -0.1, 2.06), (0.3, 0.4, 0.3), soft=0.4)
    # Fleece: a hood of puffs round the head, leaving the face open, and a cloud body.
    puffs = [((0, 0.15, 2.28), 0.86, (1.0, 0.95, 1.0)), ((0, 0.05, 0.66), 0.62, (1.3, 1.1, 1.0))]
    for i in range(32):
        z = 1 - 2 * (i + 0.5) / 32
        a = i * 2.39996
        d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
        if d.dot(Vector((0, -1, 0.05)).normalized()) < 0.45:
            puffs.append((head + d * Vector((0.92, 0.84, 0.86)), 0.34))
    for i in range(14):
        z = 0.7 - 1.3 * (i + 0.5) / 14
        a = i * 2.39996
        d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
        puffs.append((Vector((0, 0.05, 0.66)) + d * Vector((0.72, 0.58, 0.46)), 0.28))
    coat = k.fuse(puffs, fleece, tris=2600, soft=0.4, name="fleece")
    parts = [face_body, *k.texel([coat], 0.6)]
    parts += onto([disc(0.48, clover, green, n=48, cup=0.25, thick=0.14)], coat, head, k.outward(40, 48), spin=20, sink=0.03)
    parts += k.face(face_body, head, R, skin=skin_rgb, nose=(230, 140, 120), eye_r=0.29, eye_wide=0.9, spread=30, eye_phi=-14, nose_phi=-21, nose_r=0.06, mouth_phi=-27, mouth_w=0.11, sheen=True, blush_theta=44, blush_phi=-28)
    return parts


# Acorn Hedgehog (rare) ------------------------------------------------------------------------


def creature_hedgehog():
    cream_rgb = (255, 238, 214)
    cream = k.paint("hh_cream", [(0, (240, 214, 186)), (1, cream_rgb)], 0, 2.2)
    quill = k.paint("hh_quill", [(0, (140, 92, 64)), (1, (196, 140, 96))], 0.6, 2.6)
    cap = k.paint("hh_cap", [(0, (150, 98, 58)), (1, (190, 132, 78))], 0, 0.5, dots=[((118, 76, 44), 9, 0.22)])
    stalk, leaf, pink, nose = k.flat((120, 80, 52)), k.flat((120, 200, 95)), k.flat((255, 170, 195)), k.flat((90, 58, 70))
    c, radii = Vector((0, 0.22, 1.16)), Vector((1.21, 1.19, 1.06))
    beret_d = k.outward(18, 58)
    spikes = []  # a dense coat of soft quills, staggered rows over the back and crown
    for phi, thetas in ((-8, (75, 100, 125, 150, 175)), (12, (62, 86, 110, 134, 158, 180)), (32, (52, 76, 100, 124, 148, 172)),
                        (52, (40, 68, 96, 124, 152, 180)), (70, (20, 60, 100, 140, 180)), (86, (0,))):
        for theta in thetas:
            for s in ((1, -1) if theta % 180 else (1,)):
                d = k.outward(s * theta, phi)
                if d.angle(beret_d) < math.radians(34):
                    continue
                n = Vector((d.x / radii.x, d.y / radii.y, d.z / radii.z)).normalized()
                p = c + Vector((d.x * radii.x, d.y * radii.y, d.z * radii.z)) * 0.97
                spikes.append(toward(p + n * 0.04, n, 0.26, (0.62, 0.62, 1.3)))
    head, R = Vector((0, -0.55, 1.07)), 0.8
    snout = Vector((0, -1.3, 0.95))
    ear = (0.62, -0.68, 1.78)
    body = k.fuse(
        [
            (c, 1.08, (1.12, 1.1, 0.98)),
            ((0, -0.5, 1.02), 0.82, (1.05, 0.9, 0.92)),  # face
            (snout, 0.32, (0.88, 1.3, 0.78)),
            *k.pair(ear, 0.26, (1.0, 0.55, 1.0)),
            *k.pair((0.5, -0.75, 0.15), 0.26, (0.9, 1.4, 0.6)),  # feet
            *k.pair((0.55, 0.95, 0.15), 0.26, (0.9, 1.4, 0.6)),
            *k.pair((0.86, -0.82, 0.75), 0.18, (0.85, 0.9, 1.2)),  # arms
            *spikes,
        ],
        cream,
        tris=3400,
        soft=0.25,
    )
    split(body, quill, (0, -0.5, 1.3), (0, 0.55, 0.85))  # quill coat over the back and crown
    split(body, cream, (0, 0, 0.45), (0, 0, -1))  # cream underneath
    parts = [body]
    for s in (-1, 1):  # round ears: a round inner ear
        parts.append(k.lens(body, (s * ear[0], ear[1], ear[2]), (s * 0.3, -1, 0.1), 0.16, pink, scale=(0.75, 0.95), thick=0.2, sink=0.6, name="ear_in"))
    parts.append(k.lens(body, snout, k.outward(0, 10), 0.13, nose, scale=(1.25, 0.9), thick=0.55, sink=0.4, seg=16, name="nose"))
    parts.append(k.mouth(body, snout, k.outward(0, -38), 0.17, k.flat(INK), "smile"))
    k.texel(parts[-2:], k.FACE_TEXEL)
    # Acorn cap worn as a beret, tipped to the right, a stalk and an oak leaf.
    beret = [k.lathe([(0, 0.14), (0.35, 0.1), (0.58, 0.0), (0.66, 0.06), (0.67, 0.14), (0.6, 0.25), (0.46, 0.33), (0.26, 0.39), (0, 0.41)], m=cap, n=32, name="beret")]
    beret.append(k.capsule((0, 0, 0.36), (0.08, 0.04, 0.6), 0.07, 0.05, stalk, n=12, name="stalk"))
    beret += xf(k.leaf(0.42, 0.16, leaf, droop=0.25, n=8, steps=8), (0.04, 0.02, 0.42), yaw=-30, pitch=20)
    parts += onto(beret, body, c, beret_d, up=(0, 1, 0), sink=0.12)
    parts += k.face(body, head, R, skin=cream_rgb, nose=None, mouth_kind=None, eye_phi=8, spread=36)
    return parts


# Blossom Fawn (epic) --------------------------------------------------------------------------


def creature_deer():
    skin_rgb = (240, 186, 128)
    tan = k.paint("de_coat", [(0, (214, 150, 96)), (1, skin_rgb)], 0.3, 4.3)
    hoof, cream, wood = k.flat((132, 90, 74)), k.flat((255, 242, 222)), k.flat((170, 120, 88))
    pale, deep = k.flat((255, 236, 230)), k.flat((242, 110, 140))
    rose, sunny, pink, nose = k.flat((255, 128, 160), emit=0.2), k.flat(k.SUNNY), k.flat((255, 170, 195)), k.flat((96, 60, 70))
    head, R = Vector((0, -0.38, 3.3)), 1.0
    snout = Vector((0, -1.22, 2.98))
    ear, tilt = (1.15, -0.2, 3.62), 66
    legs = []
    for x, y, r in ((0.4, -0.38, 0.2), (0.42, 0.82, 0.21)):
        for s in (-1, 1):
            legs += [("capsule", (s * x, y, 0.22), (s * x, y, 1.45), r), ((s * x, y, 0.19), r + 0.02, (1, 1.05, 0.85))]
    body_c = Vector((0, 0.25, 1.78))
    body = k.fuse(
        [
            (head, R, (1.1, 0.96, 0.94)),
            (snout, 0.42, (1.1, 0.92, 0.76)),
            ((0, -0.15, 2.5), 0.5, (1.0, 1.0, 1.15)),  # neck
            (body_c, 0.8, (1.0, 1.2, 0.86)),
            *k.pair(ear, 0.52, (0.5, 0.25, 1.0), (0, tilt, 0)),
            *legs,
        ],
        tan,
        tris=2150,
    )
    split(body, hoof, (0, 0, 0.3), (0, 0, -1))
    parts = [body, k.sphere(0.24, (0, 1.22, 2.1), m=cream, seg=20, rings=10, name="tail")]
    parts += ears_in(body, ear, tilt, pink, 0.42)
    parts.append(k.lens(body, body_c, (0, -1, 0.1), 0.34, cream, scale=(0.8, 1.25), thick=0.22, sink=0.6, name="chest"))
    muzzle = k.lens(body, snout, k.outward(0, -22), 0.34, cream, scale=(1.15, 0.8), thick=0.25, sink=0.6, name="muzzle")
    face = [muzzle, k.lens(body, snout, k.outward(0, 22), 0.12, nose, scale=(1.3, 0.85), thick=0.55, sink=0.4, seg=12, name="nose")]
    face.append(k.mouth(muzzle, snout, k.outward(0, -30), 0.2, k.flat(INK), "smile"))
    parts += k.texel(face, k.FACE_TEXEL)
    # Cherry blossom spots on both flanks and over the rump; antler nubs, a blossom on each tip.
    for theta, phi in ((75, 5), (105, 30), (130, 2), (150, 35), (180, 12)):  # about 35 degrees apart
        for s in ((1, -1) if theta % 180 else (1,)):
            parts += onto([disc(0.27, petals(5, 0.4), pale, heart=deep, n=20, cup=-0.12, thick=0.14, hr=0.3, dome=0.1, closed=False, name="spot")], body, body_c, k.outward(s * theta, phi), spin=s * theta, sink=0.012)
    for s in (-1, 1):
        base, tip = Vector((s * 0.36, -0.3, 4.0)), Vector((s * 0.56, -0.18, 4.6))
        parts.append(k.capsule(base, tip, 0.13, 0.1, wood, n=12, name="antler"))
        parts += aim([disc(0.36, petals(5, 0.4), rose, heart=sunny, n=25, cup=0.35, thick=0.16)], tip + (tip - base).normalized() * 0.05, tip - base + Vector((s * 0.3, -0.5, 0)))
    parts += k.face(body, head, R, skin=skin_rgb, nose=None, mouth_kind=None, eye_phi=8, spread=36)
    return parts


# Bamboo Panda (epic) --------------------------------------------------------------------------


def creature_panda():
    white = k.paint("pa_fur", [(0, (226, 226, 236)), (1, (255, 255, 255))], 0.2, 4.2)
    black = k.paint("pa_black", [(0, (40, 38, 50)), (1, (70, 66, 82))], 0.2, 4.2)
    bamboo = k.paint("pa_bamboo", [(0, (92, 176, 84)), (1, (150, 218, 112))], 0, 4.2)
    leaf, leaf_hi, pad = k.flat((110, 200, 100)), k.flat((150, 224, 112)), k.flat((214, 150, 172))
    head, R = Vector((0, -0.3, 3.1)), 1.2
    body = k.fuse([(head, R, (1.22, 0.98, 0.92)), ((0, 0.15, 1.4), 1.3, (1.1, 1.1, 0.95)), ((0, 1.55, 0.75), 0.25)], white, tris=2000)
    limbs = k.fuse(
        [
            *k.pair((0.98, -0.15, 4.0), 0.36, (1.0, 0.7, 1.0)),  # ears
            ((0, 0.45, 2.2), 1.05, (1.2, 0.9, 0.4)),  # shoulder band
            *chain([(1.3, -0.05, 2.25), (1.35, -0.95, 1.8), (1.05, -1.5, 2.15)], 0.36, 0.32),
            *chain([(-1.3, -0.05, 2.25), (-0.95, -1.2, 1.65), (0.7, -1.6, 1.6)], 0.36, 0.32),
            *k.pair((0.88, -0.8, 0.48), 0.52, (0.95, 1.4, 0.85), (-12, 0, 0)),  # legs, soles forward
        ],
        black,
        tris=1250,
        name="limbs",
    )
    parts = [body, limbs]
    for s in (-1, 1):
        parts.append(k.lens(limbs, (s * 0.88, -0.8, 0.48), (0, -1, 0.15), 0.22, pad, scale=(1, 1.15), thick=0.2, sink=0.6, name="sole"))
        parts.append(k.lens(body, head, k.outward(s * 31, -5), R * 0.3, black, scale=(0.8, 1.2), thick=0.2, sink=0.6, up=(-s * 0.45, 0, 1), name="patch"))
    k.texel(parts[-2:], k.FACE_TEXEL)
    # Bamboo held upright in both paws, leaves at its top and a sprig on the head.
    a, b = Vector((0.82, -1.75, 0.12)), Vector((1.4, -1.62, 4.0))
    nodes = [a.lerp(b, t) for t in (0, 0.32, 0.62, 1.0)]
    for p, q in zip(nodes, nodes[1:]):
        parts.append(k.capsule(p, q, 0.13, 0.155, bamboo, n=12, name="bamboo"))
    for yaw, pitch, length, m in ((-20, 25, 0.95, leaf), (60, 35, 0.85, leaf_hi), (170, 20, 0.8, leaf)):
        parts += xf(k.leaf(length, 0.25, m, droop=0.3, n=8, steps=8), b, yaw=yaw, pitch=pitch)
    parts += xf(k.leaf(0.85, 0.27, leaf_hi, droop=0.35, n=8, steps=8), (-0.25, -0.35, 4.12), yaw=160, pitch=28)
    parts += k.face(body, head, R, skin=(255, 255, 255), nose=(52, 50, 62), nose_r=0.09)
    return parts


# Daisy Unicorn (legendary) --------------------------------------------------------------------


def creature_unicorn():
    skin_rgb = (255, 244, 234)
    coat = k.paint("un_coat", [(0, (236, 220, 216)), (1, skin_rgb)], 0.3, 5.2)
    gold = k.paint("un_gold", [(0, (200, 120, 40)), (1, (250, 192, 84))], 0, 0.5, emit=0.15)
    mane = k.paint("un_mane", [(0, (255, 160, 208)), (0.5, (236, 170, 250)), (1, (190, 172, 255))], 1.2, 5.5)
    horn_m = k.paint("un_horn", [(0, (240, 168, 60)), (1, (255, 228, 150))], 4.7, 5.8, emit=0.25)
    white, sunny, pink = k.flat((255, 255, 255)), k.flat((255, 205, 60)), k.flat((255, 172, 198))
    head, R = Vector((0, -1.0, 4.0)), 1.25
    snout = Vector((0, -2.05, 3.55))
    ear, tilt = (0.9, -0.75, 5.0), 28
    legs = []
    for x, y, r in ((0.62, -0.35, 0.3), (0.62, 1.05, 0.31)):
        for s in (-1, 1):
            legs += [("capsule", (s * x, y, 0.26), (s * x, y, 1.75), r), ((s * x, y, 0.22), r + 0.05, (1, 1.05, 0.78))]
    body = k.fuse(
        [
            (head, R, (1.28, 0.95, 0.92)),
            (snout, 0.52, (1.1, 0.85, 0.75)),
            ((0, -0.55, 3.0), 0.55, (1.0, 1.0, 1.3)),  # neck
            ((0, 0.35, 2.15), 1.0, (1.25, 1.25, 0.85)),
            *k.pair(ear, 0.42, (0.5, 0.25, 1.0), (0, tilt, 0)),
            *legs,
        ],
        coat,
        tris=2050,
        res=0.05,  # 0.04 gives ~90k triangles, and decimating that to 2k left a sliver on a leg
    )
    split(body, gold, (0, 0, 0.42), (0, 0, -1))
    # Smooth locks: a crest from the brow down the neck, two side locks, a tail swishing out to +x.
    crest = chain([(0, -1.35, 5.1), (0, -0.7, 5.25), (0, -0.15, 4.9), (0, 0.1, 4.3), (0, 0.3, 3.4)], 0.42, 0.3)
    crest += chain([(0.3, -0.9, 5.15), (0.5, -0.4, 4.85), (0.45, -0.1, 4.25)], 0.3, 0.22) + chain([(-0.3, -0.9, 5.15), (-0.5, -0.4, 4.85), (-0.45, -0.1, 4.25)], 0.3, 0.22)
    crest += k.pair((0.34, -1.72, 4.85), 0.26)  # forelock either side of the horn
    tail = chain([(0.05, 1.6, 2.5), (0.5, 2.0, 2.3), (1.05, 2.1, 1.9)], 0.3, 0.42) + chain([(1.05, 2.1, 1.9), (1.5, 1.95, 1.4), (1.62, 1.75, 0.95)], 0.42, 0.18)
    hair = k.fuse(crest + tail, mane, tris=850, soft=0.3, name="mane")
    parts = [body, hair, *ears_in(body, ear, tilt, pink, 0.34)]
    base = k.land(body, head, k.outward(0, 40))[0]
    parts.append(horn(base - Vector((0, -0.05, 0.08)), (0, -0.35, 1), 1.05, 0.25, horn_m))

    def daisy():
        return disc(0.27, petals(8, 0.55, 1.2), white, heart=sunny, n=32, cup=0.25, thick=0.14, hr=0.3, dome=0.18, closed=False, name="daisy")

    for centre, d in (
        ((0.34, -1.72, 4.85), (0.4, -1, 0.5)), ((-0.34, -1.72, 4.85), (-0.4, -1, 0.5)),  # horn crown
        ((0.5, -0.4, 4.85), (1, 0.1, 0.6)), ((-0.45, -0.1, 4.3), (-1, 0.2, 0.3)), ((0, -0.15, 4.9), (0.2, 0.2, 1)),
        ((1.05, 2.1, 1.9), (0.5, 1, 0.3)),
    ):
        parts += onto([daisy()], hair, centre, d, sink=0.02)
    parts += snout_face(body, head, R, snout, skin_rgb, 0.28)
    return parts


# Ember Phoenix (mythic) -----------------------------------------------------------------------


def creature_phoenix():
    skin_rgb = (255, 112, 58)
    plumage = k.paint("ph_body", [(0, (210, 40, 64)), (0.45, skin_rgb), (1, (255, 150, 64))], 0.3, 4.1, emit=0.15)
    gold = k.paint("ph_gold", [(0, (210, 128, 40)), (1, (255, 200, 80))], 0, 0.4, emit=0.3)
    fire = [(0, (225, 36, 60)), (0.35, (255, 84, 40)), (0.7, (255, 132, 40)), (1, (255, 190, 76))]  # gold, not pale, tips: pale yellow goes lime in cool light
    crest = k.paint("ph_crest", fire, 3.9, 5.5, emit=0.35)
    tail = k.paint("ph_tail", fire, 1.2, 3.6, emit=0.35)
    belly = k.paint("ph_belly", [(0, (255, 160, 70)), (1, (255, 214, 120))], 0.6, 2.2, emit=0.5)
    beak = k.flat(k.GOLD_MID)
    head, R = Vector((0, -0.3, 2.95)), 1.15
    body = k.fuse(
        [
            (head, R, (1.12, 1.0, 0.95)),
            ((0, 0.15, 1.32), 1.15, (1.08, 1.05, 0.95)),
            ((0, 1.2, 1.15), 0.4, (0.9, 1.0, 0.8)),  # rump under the tail
            *k.pair((0.45, -0.62, 0.16), 0.28, (0.9, 1.45, 0.6)),  # feet
        ],
        plumage,
        tris=2300,
    )
    split(body, gold, (0, 0, 0.4), (0, 0, -1), where=lambda p: p.y < -0.3)  # the feet, not the seat
    parts = [body, k.lens(body, (0, 0.15, 1.2), (0, -1, -0.05), 0.6, belly, scale=(0.9, 1.1), thick=0.3, sink=0.6, name="belly")]
    parts.append(k.capsule((0, -1.25, 2.74), (0, -1.62, 2.6), 0.2, 0.05, beak, n=16, name="beak"))
    k.texel(parts[-1], k.FACE_TEXEL)
    for root, tip, r, bend in (((0, -0.35, 3.85), (0, -0.15, 5.4), 0.3, 0.12), ((0.42, -0.25, 3.8), (0.98, 0.05, 4.95), 0.25, -0.15),
                               ((-0.42, -0.25, 3.8), (-0.98, 0.05, 4.95), 0.25, 0.15), ((0, 0.25, 3.7), (0, 0.8, 4.65), 0.23, 0.1)):
        parts.append(flame(root, tip, r, crest, bend=bend, n=10))
    for root, tip, r, bend in (((0, 1.2, 1.25), (0, 2.35, 3.3), 0.36, 0.1), ((0.4, 1.2, 1.2), (1.3, 2.2, 2.8), 0.3, -0.12), ((-0.4, 1.2, 1.2), (-1.3, 2.2, 2.8), 0.3, 0.12),
                               ((0.35, 1.25, 0.95), (1.6, 2.1, 1.6), 0.26, -0.1), ((-0.35, 1.25, 0.95), (-1.6, 2.1, 1.6), 0.26, 0.1)):
        parts.append(flame(root, tip, r, tail, bend=bend, n=10))
    for s in (-1, 1):
        wing = k.paint(f"ph_wing{s}", fire, s * 1.0, s * 2.4, axis="X", emit=0.35)
        for length, width, pitch, yaw in ((1.5, 0.52, 42, 15), (1.3, 0.48, 15, 25), (1.05, 0.42, -10, 35)):
            parts += k.texel(xf(k.leaf(length, width, wing, droop=0.15, n=8, steps=8), (1.0, 0.15, 1.85), yaw=yaw, pitch=pitch, roll=90, mirror=s < 0), 0.5)
    parts += k.face(body, head, R, skin=skin_rgb, nose=None, mouth_kind=None, eye_phi=2)
    return parts


# Aurora Whale (divine) ------------------------------------------------------------------------


def creature_whale():
    skin_rgb = (236, 242, 255)  # the face is on the pale belly, so the blush mixes from that
    aurora = k.paint(
        "wh_back",
        [(0, (40, 196, 204)), (0.3, (60, 132, 236)), (0.65, (124, 78, 230)), (1, (200, 90, 214))],
        1.5,
        4.2,
        dots=[((255, 255, 255), 6, 0.13), ((255, 222, 120), 3.5, 0.1)],
        emit=0.2,
    )
    belly = k.paint("wh_belly", [(0, (200, 220, 252)), (1, (240, 246, 255))], 1.0, 2.6)
    cloud = k.paint("wh_cloud", [(0, (214, 216, 246)), (1, (255, 255, 255))], 0, 1.4)
    gold = k.flat((255, 190, 60), emit=0.2)
    head, R = Vector((0, -0.75, 2.6)), 1.4
    tail = chain([(0, 1.0, 2.55), (0, 1.75, 2.85), (0, 2.25, 3.35), (0, 2.45, 3.85)], 0.72, 0.28)
    body = k.fuse(
        [
            ((0, -0.25, 2.5), 1.55, (1.12, 1.2, 0.92)),
            *tail,
            *k.pair((0.62, 2.5, 4.0), 0.55, (1.3, 0.65, 0.25), (15, -20, 0)),  # flukes
            *k.pair((1.62, -0.7, 1.9), 0.64, (1.25, 0.6, 0.28), (0, 25, 20)),  # flippers
        ],
        aurora,
        tris=2800,
    )
    split(body, belly, (0, -0.4, 2.3), (0, -0.3, -1))  # pale face, throat and belly, higher at the front
    puffs = [((0, 0, 0.5), 1.3, (1.5, 1.3, 0.5))]
    for i in range(10):
        a = math.radians(36 * i + 10)
        puffs.append(((2.05 * math.cos(a), 1.6 * math.sin(a), 0.5), 0.62, (1, 1, 0.78)))
    for i in range(5):
        a = math.radians(72 * i + 40)
        puffs.append(((1.2 * math.cos(a), 0.9 * math.sin(a), 0.85), 0.55, (1, 1, 0.8)))
    nimbus = k.fuse(puffs, cloud, tris=1200, soft=0.35, name="cloud")
    parts = [body, *k.texel([nimbus], 0.5)]
    for theta, phi, r in ((150, 52, 0.38), (-150, 34, 0.3), (35, 60, 0.3), (-70, 48, 0.24)):
        parts += onto([disc(r, star, gold, n=40, cup=0.0, thick=0.3, closed=False, name="star")], body, (0, -0.25, 2.5), k.outward(theta, phi), spin=90, sink=0.02)
    parts.append(k.mouth(body, head, k.outward(0, -26), 0.42, k.flat(INK), "smile"))
    k.texel(parts[-1], k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=skin_rgb, nose=None, mouth_kind=None)
    return parts


# Nimbus Kirin (divine) ------------------------------------------------------------------------


def creature_kirin():
    skin_rgb = (236, 244, 255)
    coat = k.paint("ki_coat", [(0, (196, 218, 252)), (0.5, (226, 238, 255)), (1, skin_rgb)], 0.3, 5.4)
    hoof = k.paint("ki_hoof", [(0, (210, 134, 40)), (1, (252, 196, 84))], 0, 0.5, emit=0.15)
    gold = k.paint("ki_gold", [(0, (222, 140, 40)), (1, (255, 192, 72))], 5.0, 6.2, emit=0.12)
    cloud = k.paint("ki_cloud", [(0, (236, 238, 255)), (1, (255, 255, 255))], 0, 5.5, emit=0.1)
    gems = [k.flat(rgb, emit=0.3) for rgb in ((110, 236, 226), (40, 186, 206), (24, 118, 170))]
    pink = k.flat((255, 180, 205))
    head, R = Vector((0, -1.0, 4.2)), 1.32
    snout = Vector((0, -2.2, 3.72))
    ear, tilt = (0.95, -0.75, 5.12), 40
    legs = []
    for x, y, r in ((0.78, -0.4, 0.33), (0.78, 1.38, 0.35)):
        for s in (-1, 1):
            legs += [("capsule", (s * x, y, 0.26), (s * x, y, 1.8), r), ((s * x, y, 0.22), r + 0.04, (1, 1.05, 0.75))]
    body = k.fuse(
        [
            (head, R, (1.18, 0.97, 0.95)),
            (snout, 0.56, (1.05, 0.95, 0.74)),
            ((0, -0.55, 3.2), 0.76),  # neck
            ((0, 0.5, 2.32), 1.2, (1.3, 1.32, 0.9)),
            *k.pair(ear, 0.42, (0.5, 0.25, 1.0), (0, tilt, 0)),
            *legs,
        ],
        coat,
        tris=2000,
        res=0.05,
    )
    split(body, hoof, (0, 0, 0.36), (0, 0, -1))
    # Cloud mane: puffs along the crest and out behind both cheeks (so it shows from the front),
    # and a cloud tail.
    puffs = [((0, -0.6, 5.3), 0.48), ((0, -0.15, 5.0), 0.5), ((0, 0.15, 4.45), 0.5), ((0, 0.35, 3.85), 0.46), ((0, 0.5, 3.3), 0.4)]
    puffs += [*k.pair((0.5, -0.2, 4.7), 0.38), *k.pair((0.5, 0.15, 4.05), 0.36), *k.pair((1.25, -0.15, 4.05), 0.4), *k.pair((1.1, 0.1, 3.45), 0.36)]
    puffs += [((0, 1.9, 2.65), 0.45), ((0, 2.25, 2.3), 0.5), ((0, 2.45, 1.8), 0.42), *k.pair((0.38, 2.15, 2.05), 0.36), *k.pair((0.3, 1.95, 2.55), 0.32)]  # tail
    mane = k.fuse(puffs, cloud, tris=1400, soft=0.28, name="mane")
    parts = [body, mane, *ears_in(body, ear, tilt, pink, 0.34)]
    for s in (-1, 1):
        beam = [Vector((s * 0.45, -0.85, 5.2)), Vector((s * 0.98, -0.75, 5.72)), Vector((s * 2.0, -0.52, 5.95))]
        parts.append(k.capsule(beam[0], beam[1], 0.15, 0.12, gold, n=10, name="antler"))
        parts.append(k.capsule(beam[1], beam[2], 0.12, 0.07, gold, n=10, name="antler"))
        parts.append(k.capsule(beam[1], beam[1] + Vector((s * 0.05, -0.2, 0.52)), 0.1, 0.06, gold, n=10, name="tine"))
    gem = k.ico(0.27, m=gems[0], subdiv=1, scale=(1, 1, 0.7), name="gem")
    onto([gem], body, head, k.outward(0, 42), sink=0.05)
    parts.append(k.texel(k.facet(gem, gems), k.FACE_TEXEL))
    parts += snout_face(body, head, R, snout, skin_rgb, 0.32)
    return parts


# Stardust Axolotl (secret) --------------------------------------------------------------------


def creature_axolotl():
    skin_rgb = (250, 196, 232)
    skin = k.paint("ax_skin", [(0, (232, 160, 214)), (1, skin_rgb)], 0.2, 2.2)
    galaxy = k.paint(
        "ax_galaxy",
        [(0, (58, 44, 128)), (0.5, (98, 58, 170)), (1, (60, 46, 136))],
        -1.0,
        3.0,
        axis="Y",
        dots=[((255, 255, 255), 7, 0.1), ((255, 222, 130), 4, 0.07)],
        emit=0.5,
    )
    gill = k.paint("ax_gill", [(0, (255, 80, 156)), (1, (255, 146, 200))], 1.3, 2.9, emit=0.3)
    gold = k.flat((255, 196, 70), emit=0.2)
    head, R = Vector((0, -0.95, 1.4)), 1.05
    tail = []
    pts = curve([(0, 1.4, 0.98), (0, 2.0, 1.04), (0.15, 2.5, 1.14), (0.45, 2.9, 1.3)], 0.2)
    for i, (p, q) in enumerate(zip(pts, pts[1:] + [pts[-1] + (pts[-1] - pts[-2])])):
        t = i / (len(pts) - 1)
        tail.append((tuple(p), 0.5 - 0.36 * t, (0.42, 1.0, 1.3), (0, 0, math.degrees(math.atan2(-(q - p).x, (q - p).y)))))
    legs = []  # stubby: a short capsule out and down from the body to a flat bean
    for x, y, foot in ((0.5, -0.45, (0.78, -0.62, 0.14)), (0.48, 0.9, (0.72, 1.08, 0.14))):
        for s in (-1, 1):
            legs += [("capsule", (s * x, y, 0.48), (s * foot[0], foot[1], foot[2] + 0.06), 0.24), ((s * foot[0], foot[1], foot[2]), 0.24, (1, 1.3, 0.55))]
    body = k.fuse(
        [
            (head, R, (1.22, 0.95, 0.88)),
            ((0, 0.4, 0.98), 0.78, (1.0, 1.5, 0.85)),
            *tail,
            *legs,
        ],
        skin,
        tris=2700,
    )
    split(body, galaxy, (0, 0.3, 1.48), (0, 0.3, 1))  # galaxy along the spine and over the crown
    # Six gills, three a side, swept up and back: a stalk with a scalloped row of soft fronds
    # along its back edge and a round tip.
    fronds = []
    for s in (-1, 1):
        for root, d in (((0.95, -0.75, 1.95), (0.28, 0.38, 0.88)), ((1.1, -0.65, 1.65), (0.6, 0.5, 0.62)), ((1.18, -0.55, 1.3), (0.68, 0.6, 0.42))):
            root, d = Vector((s * root[0], root[1], root[2])), Vector((s * d[0], d[1], d[2])).normalized()
            fronds.append(("capsule", tuple(root), tuple(root + d * 0.7), 0.12))
            fronds.append((tuple(root + d * 0.73), 0.15))
            back = (Vector((0, 1, 0.3)) - d * d.dot(Vector((0, 1, 0.3)))).normalized()
            for t in (0.3, 0.55, 0.8):  # spaced wider than they are thick, so the notches show
                fronds.append(toward(root + d * 0.7 * t + back * 0.15, back + d * 0.3, 0.105, (0.8, 0.8, 1.6)))
    gills = k.fuse(fronds, gill, tris=1300, soft=0.15, name="gills")
    parts = [body, gills]
    for theta, phi, r in ((160, 60, 0.22), (-25, 72, 0.18)):  # gold stars in the galaxy
        parts += onto([disc(r, star, gold, n=40, cup=0.0, thick=0.3, closed=False, name="star")], body, (0, 0.4, 0.98), k.outward(theta, phi), spin=90, sink=0.02)
    parts.append(k.mouth(body, head, k.outward(0, -22), 0.4, k.flat(INK), "smile"))
    k.texel(parts[-1], k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=skin_rgb, nose=None, mouth_kind=None, spread=40, eye_phi=0)
    return parts


NOTES = "One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are."
ASSETS = [
    dict(name=name, build=fit(size)(build), budget=k.CREATURE_BUDGET, finalize=k.HD, size=size, priority=1, order=20 + i, replaces="none (new species)", notes=f"{label}. {NOTES}", glow={})
    for i, (name, build, size, label) in enumerate(
        (
            ("creature_duck", creature_duck, [2.4, 3.0, 2.6], "Puddle Duckling (common)"),
            ("creature_lamb", creature_lamb, [3.2, 3.8, 2.3], "Clover Lamb (uncommon)"),
            ("creature_hedgehog", creature_hedgehog, [3.0, 2.8, 3.4], "Acorn Hedgehog (rare)"),
            ("creature_deer", creature_deer, [3.6, 5.0, 3.0], "Blossom Fawn (epic)"),
            ("creature_panda", creature_panda, [4.4, 4.5, 4.0], "Bamboo Panda (epic)"),
            ("creature_unicorn", creature_unicorn, [4.0, 5.5, 4.8], "Daisy Unicorn (legendary)"),
            ("creature_phoenix", creature_phoenix, [4.6, 5.5, 4.2], "Ember Phoenix (mythic)"),
            ("creature_whale", creature_whale, [6.0, 4.5, 5.0], "Aurora Whale (divine)"),
            ("creature_kirin", creature_kirin, [4.6, 6.0, 5.2], "Nimbus Kirin (divine)"),
            ("creature_axolotl", creature_axolotl, [3.4, 3.0, 5.0], "Stardust Axolotl (secret)"),
        )
    )
]
