"""Ten Egg Garden creatures (batch B) to the HD standard (tools/blender/garden/README.md "Creature
standard"): one fused body per colour, the kit face, smooth separate props. One mesh each, standing
on the origin, facing Blender -Y. Markings are k.zone paint on rest-painted bodies."""

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
    """Remade from the Roblox AI reference (assets/garden/refs/hedgehog_*.jpg): a cream bean of a
    hedgehog with a round ball of shaggy brown quills over its back, round ears with pink insides,
    small dark eyes, a black button nose on a tiny snout, pink cheeks, little arms with brown
    paws, and a big ribbed acorn cap worn on its head (the "Acorn Hedgehog")."""
    cream_rgb = (234, 222, 200)
    cream = k.paint("hh_cream", [(0, (204, 188, 166)), (0.45, (228, 216, 196)), (1, cream_rgb)], 0, 3.0, rest=True)
    quill = k.paint("hh_quill", [(0, (116, 80, 56)), (0.5, (156, 114, 82)), (1, (184, 144, 108))], 0.2, 3.0, grain=(0.28, 12), dots=[((232, 214, 194), 16, 0.09), ((74, 54, 44), 13, 0.07)], rest=True)
    cap = k.paint("hh_cap", [(0, (132, 78, 40)), (1, (200, 136, 80))], 2.6, 3.5, rays=((110, 62, 32), 16, 2.6, 0.12), rest=True)
    head, R = Vector((0, -0.2, 1.95)), 0.9
    snout = Vector((0, -1.12, 1.7))
    ear = (0.8, -0.25, 2.55)
    body = k.fuse(
        [
            (head, R, (1.18, 1.0, 0.95)),
            *k.pair((0.48, -0.5, 1.68), 0.42, (1.0, 0.85, 0.8)),  # full cheeks
            (snout, 0.22, (1.1, 1.0, 0.9)),  # tiny snout
            ((0, 0.05, 0.85), 0.92, (1.12, 1.1, 0.95)),  # bean body
            *k.pair(ear, 0.3, (1.0, 0.5, 1.0), (0, 18, 0)),  # round ears
            ("capsule", (0.62, -0.45, 1.3), (0.5, -0.86, 0.9), 0.17),  # little arms, paws forward
            ("capsule", (-0.62, -0.45, 1.3), (-0.5, -0.86, 0.9), 0.17),
            *k.pair((0.5, -0.9, 0.86), 0.17, (1.0, 1.1, 0.9)),
            ((0, 0.05, 0.4), 0.95, (1.18, 1.12, 0.5)),  # flat round seat
        ],
        cream,
        tris=2100,
    )
    for side in (-1, 1):
        k.zone(cream, (150, 104, 84), (side * 0.5, -0.94, 0.86), (0.2, 0.2, 0.2), soft=0.25)  # brown paws
    # The quill coat: a ball over the back and crown, shaggy with short fused spikes.
    c = Vector((0, 0.38, 1.42))
    radii = Vector((1.5, 1.22, 1.44))
    spikes = []
    for phi in range(-40, 90, 16):
        ring = max(1, round(10 * math.cos(math.radians(phi))))
        for i in range(ring):
            theta = 70 + 220 * i / max(1, ring - 1) + (phi % 28) * 0.5
            d = k.outward(theta, phi)
            if d.y < -0.3 and phi < 60:
                continue
            n = Vector((d.x / radii.x, d.y / radii.y, d.z / radii.z)).normalized()
            p = c + Vector((d.x * radii.x, d.y * radii.y, d.z * radii.z)) * 0.95
            spikes.append(toward(p, n + Vector((0, 0.5, -0.25)), 0.26, (0.95, 0.7, 1.1)))
    coat = k.fuse([(c, 1.0, tuple(radii)), *spikes], quill, tris=1650, soft=0.45, name="quills")
    parts = [body, coat]
    k.texel([coat], 0.6)
    for s in (-1, 1):
        axis = (s * math.sin(math.radians(18)), 0, math.cos(math.radians(18)))
        parts.append(k.lens(body, (s * ear[0], ear[1], ear[2]), (s * 0.25, -1, 0), 0.2, k.flat((236, 168, 160)), scale=(0.8, 0.9), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    face = [k.lens(body, snout, (0, -1, 0.15), 0.15, k.flat((40, 34, 40)), scale=(1.3, 1.0), thick=0.8, sink=0.4, seg=16, name="nose"),
            k.mouth(body, snout, k.outward(0, -40), 0.09, k.flat(INK), "w")]
    parts += k.texel(face, k.FACE_TEXEL)
    # Acorn cap: a ribbed dome over the crown, a stalk and a little leaf.
    top = Vector((0, -0.14, 2.42))
    parts.append(k.rest(k.lathe([(0, 0.0), (0.66, 0.0), (0.88, 0.08), (0.94, 0.26), (0.9, 0.5), (0.74, 0.74), (0.48, 0.9), (0.2, 0.97), (0, 0.98)], loc=top, rot=(-14, 0, 0), m=cap, n=32, name="cap")))
    stalk = k.flat((120, 70, 40))
    parts.append(k.capsule(top + Vector((0, 0.18, 0.86)), top + Vector((0.02, 0.2, 1.02)), 0.07, 0.06, stalk, n=12, name="stalk"))
    parts += xf(k.leaf(0.36, 0.14, k.flat((120, 196, 92)), droop=0.2, n=8, steps=8), top + Vector((0.04, 0.2, 0.98)), yaw=-40, pitch=30)
    parts += k.face(body, head, R, skin=cream_rgb, nose=None, mouth_kind=None, eye_r=0.16, eye_wide=0.9, spread=31, eye_phi=-4, sheen=True, blush_theta=44, blush_phi=-26)
    return parts


# Blossom Fawn (epic) --------------------------------------------------------------------------


def creature_deer():
    """Remade from the Roblox AI reference (assets/garden/refs/deer_*.jpg): a tan fawn standing on
    four short legs, a huge head with a white lower face and a small muzzle, wide ears held out
    flat to the sides with cream insides, short forked antlers with a pink blossom at each base,
    white spots on the crown and back, a shaggy white chest ruff, dark hooves and a white-tipped
    tail flicked up (the "Blossom Fawn")."""
    tan_rgb, white = (222, 150, 88), (252, 246, 238)
    tan = k.paint("de_coat", [(0, (188, 118, 66)), (0.45, tan_rgb), (1, (236, 174, 112))], 0, 3.4, rest=True, grain=(0.05, 30))
    head, R = Vector((0, -0.45, 2.5)), 0.9
    snout = Vector((0, -1.2, 2.18))
    ear, tilt = Vector((1.12, -0.34, 2.54)), 96
    feet = ((0.36, -0.45), (0.38, 0.72))
    legs = []
    for x, y in feet:
        for s in (-1, 1):
            legs += [("capsule", (s * x, y, 0.75), (s * x, y, 0.22), 0.25), ((s * x, y, 0.17), 0.27, (1.0, 1.08, 0.7))]
    body_c = Vector((0, 0.18, 0.96))
    bib = Vector((0, -0.6, 1.1))
    ruff = [(bib, 0.44, (1.15, 0.62, 1.25))]  # shaggy chest ruff: a fluffy bib, tufts hanging from its lower edge
    for i, a in enumerate(range(-75, 76, 25)):
        t = math.radians(a)
        d = Vector((math.sin(t) * 0.6, -0.5, -1)).normalized()
        ruff.append(toward(bib + Vector((math.sin(t) * 0.4, -0.1, -0.36 - 0.1 * math.cos(t))), d, 0.14 + 0.03 * (i % 2), (0.85, 0.8, 1.6)))
    body = k.fuse(
        [
            (head, R, (1.18, 0.95, 0.95)),
            *k.pair((0.5, -0.8, 2.22), 0.4, (1.0, 0.85, 0.8)),  # full cheeks
            (snout, 0.3, (1.1, 0.95, 0.8)),  # small muzzle
            (body_c, 0.72, (1.0, 1.26, 0.86)),  # plump barrel body
            ((0, -0.42, 1.18), 0.5),  # chest
            *ruff,
            *k.pair(ear, 0.62, (0.6, 0.28, 1.0), (0, tilt, 0)),  # big ears out flat to the sides
            *legs,
        ],
        tan,
        tris=2700,
    )
    k.zone(tan, (250, 236, 220), (0, -1.12, 2.3), (0.8, 0.52, 0.6), soft=0.25)  # cream lower face and muzzle
    k.zone(tan, white, bib + Vector((0, -0.2, -0.1)), (0.6, 0.4, 0.74), soft=0.1, jag=0.3)  # chest ruff
    for x, y in feet:
        for s in (-1, 1):
            k.zone(tan, (98, 62, 48), (s * x, y, 0.06), (0.32, 0.32, 0.17), soft=0.15)  # hooves
    for theta, phi, r in ((0, 72, 0.07), (-24, 60, 0.06), (24, 60, 0.06), (0, 50, 0.05)):  # crown spots
        p, _ = k.land(body, head, k.outward(theta, phi))
        k.zone(tan, white, p, (r, r, r), soft=0.3)
    for theta, phi, r in ((180, 70, 0.09), (150, 55, 0.08), (210, 55, 0.08), (120, 40, 0.08), (240, 40, 0.08), (100, 20, 0.07), (260, 20, 0.07), (165, 30, 0.07), (195, 30, 0.07), (135, 15, 0.06), (225, 15, 0.06)):
        p, _ = k.land(body, body_c + Vector((0, 0.15, 0)), k.outward(theta, phi))
        k.zone(tan, white, p, (r, r, r), soft=0.3)  # back and flank spots
    parts = [body]
    # Tail: a short tuft flicked up, three soft points, white underneath.
    tuft = [toward((0, 0.98 + 0.06 * i, 1.32 + 0.14 * i), (0.25 * (i - 1), 0.45, 1), 0.13 - 0.01 * i, (0.8, 0.8, 1.6)) for i in range(3)]
    tail_m = k.paint("de_tail", [(0, (252, 244, 232)), (0.5, tan_rgb), (1, (226, 156, 96))], 1.25, 1.75, rest=True)
    parts.append(k.fuse([((0, 0.92, 1.25), 0.18, (1.0, 1.1, 1.2)), *tuft], tail_m, tris=420, soft=0.3, name="tail"))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    for s in (-1, 1):
        parts.append(k.lens(body, (s * ear.x, ear.y, ear.z), (0, -1, 0.3), 0.54, k.flat((250, 228, 214)), scale=(0.5, 1), thick=0.2, sink=0.6, up=(s * axis.x, 0, axis.z), name="ear_in"))
    # Short forked antlers: a thick beam rising and curving back and out, a tine forward; a blossom at each base.
    wood, rose, deep = k.flat((132, 84, 58)), k.flat((250, 176, 196)), k.flat((236, 120, 150))
    for s in (-1, 1):
        beam = curve([(s * 0.3, -0.44, 3.1), (s * 0.4, -0.44, 3.44), (s * 0.54, -0.32, 3.72), (s * 0.6, -0.12, 3.82)], 0.1)
        parts.append(k.tube(beam[:-1], [0.15 - 0.04 * i / (len(beam) - 2) for i in range(len(beam) - 1)], m=wood, n=10, name="antler"))
        parts.append(k.capsule(beam[-2], beam[-1], 0.11, 0.1, wood, n=12, name="antler_tip"))  # round tip
        parts.append(k.capsule((s * 0.43, -0.44, 3.5), (s * 0.4, -0.66, 3.72), 0.1, 0.09, wood, n=12, name="tine"))
        parts += onto([disc(0.22, petals(5, 0.4), rose, heart=deep, n=25, cup=0.3, thick=0.16, hr=0.3, dome=0.15)], body, head, k.outward(s * 30, 52), sink=0.02)
    parts += k.face(body, head, R, skin=(250, 236, 220), nose=(40, 30, 36), mouth_kind="w", eye_r=0.27, eye_wide=0.9, spread=31, eye_phi=-8, nose_phi=-20, nose_r=0.08, mouth_phi=-27, mouth_w=0.1, sheen=True, blush_theta=46, blush_phi=-22)
    return parts


# Bamboo Panda (epic) --------------------------------------------------------------------------


def creature_panda():
    """Remade from the Roblox AI reference (assets/garden/refs/panda_*.jpg): a sitting panda cub, a
    huge round white head with round black ears, big black eye patches, a small white muzzle with a
    black nose, a black band round the shoulders, black arms held out at the sides and black legs,
    a round white belly, and a bamboo shoot with two leaves growing from the top of its head (the
    "Bamboo Panda")."""
    white = (246, 246, 248)
    black = (34, 32, 38)
    fur = k.paint("pa_fur", [(0, (214, 214, 222)), (0.4, (238, 238, 242)), (1, (255, 255, 255))], 0, 3.0, rest=True)
    head, R = Vector((0, -0.1, 2.12)), 1.0
    snout = Vector((0, -0.96, 1.9))
    ear = Vector((0.88, 0.02, 2.86))
    paw = Vector((0.98, -0.5, 0.84))
    body = k.fuse(
        [
            (head, R, (1.26, 0.95, 0.9)),
            *k.pair((0.64, -0.4, 1.86), 0.48, (1.0, 0.85, 0.8)),  # full cheeks
            (snout, 0.3, (1.3, 0.9, 0.8)),  # small muzzle
            ((0, 0.05, 1.1), 0.76, (1.08, 0.98, 0.9)),  # chest
            ((0, 0.1, 0.58), 0.96, (1.12, 1.05, 0.62)),  # wide round seat
            *k.pair(ear, 0.34, (1.0, 0.62, 1.0)),  # round ears
            ("capsule", (0.78, 0.0, 1.3), tuple(paw), 0.33),  # big arms down the sides
            ("capsule", (-0.78, 0.0, 1.3), (-paw.x, paw.y, paw.z), 0.33),
            *k.pair(tuple(paw), 0.31, (0.95, 1.1, 0.9)),
            *k.pair((0.74, -0.4, 0.18), 0.24, (1.0, 1.15, 0.72)),  # small legs, tucked at the sides
        ],
        fur,
        tris=3000,
    )
    soft = dict(soft=0.1)
    k.zone(fur, black, (0, 0.05, 1.34), (1.3, 1.2, 0.26), **soft)  # shoulder band
    for s in (-1, 1):
        k.zone(fur, black, (s * ear.x, ear.y, ear.z), (0.42, 0.36, 0.42), **soft)  # ears
        k.zone(fur, black, (s * 0.96, -0.2, 1.0), (0.46, 0.6, 0.66), **soft)  # arms
        k.zone(fur, black, (s * paw.x, paw.y, paw.z), (0.42, 0.44, 0.42), **soft)  # paws
        k.zone(fur, black, (s * 0.74, -0.4, 0.18), (0.36, 0.4, 0.32), **soft)  # legs
        e, _ = k.land(body, head, k.outward(s * 30, -8))
        k.zone(fur, black, e + Vector((0, 0, 0.03)), (0.34, 0.34, 0.36), soft=0.15)  # eye patch: round...
        k.zone(fur, black, e + Vector((s * 0.14, 0.06, -0.18)), (0.28, 0.3, 0.3), soft=0.18)  # ...drooping outwards
    parts = [body]
    face = [k.lens(body, snout, k.outward(0, 22), 0.13, k.flat((30, 28, 34)), scale=(1.4, 0.9), thick=0.7, sink=0.4, seg=16, name="nose"),
            k.mouth(body, snout, k.outward(0, -20), 0.12, k.flat(k.INKY), "w")]
    parts += k.texel(face, k.FACE_TEXEL)
    # Bamboo shoot from the crown: two stalk segments with a node ring, two leaves in a V.
    green, green_hi = k.flat((84, 176, 70)), k.flat((120, 206, 90))
    p, _ = k.land(body, head, (0, 0, 1))
    base = p - Vector((0, 0, 0.08))
    mid, top = base + Vector((0, 0, 0.26)), base + Vector((0, 0, 0.5))
    parts.append(k.capsule(base, mid, 0.1, 0.1, green, n=12, name="bamboo"))
    parts.append(k.capsule(mid, top, 0.095, 0.09, green, n=12, name="bamboo"))
    parts.append(k.capsule(mid - Vector((0, 0, 0.03)), mid + Vector((0, 0, 0.03)), 0.115, 0.115, green_hi, n=12, name="node"))
    for yaw in (0, 180):
        parts += xf(k.leaf(0.7, 0.21, green_hi, droop=0.15, n=8, steps=8), top - Vector((0, 0, 0.04)), yaw=yaw, pitch=38)
    parts += k.face(body, head, R, skin=white, nose=None, mouth_kind=None, eye_r=0.21, eye_wide=0.9, spread=30, eye_phi=-8, sheen=True, blush_theta=52, blush_phi=-28)
    return parts


# Daisy Unicorn (legendary) --------------------------------------------------------------------


def creature_unicorn():
    """Remade from the Roblox AI reference (assets/garden/refs/unicorn_*.jpg): a white chibi pony on
    four stubby legs, a huge head with a soft round muzzle, big dark-blue eyes, pink-lined ears, a
    tan spiral cone horn, a thick pink mane of locks with a forelock curling down the right side of
    the face, a long pink tail curling at the ground, and a white daisy in the mane by its left
    ear (the "Daisy Unicorn")."""
    white = (252, 242, 232)
    coat = k.paint("un_coat", [(0, (230, 200, 186)), (0.4, (246, 232, 220)), (1, white)], 0, 3.6, rest=True)
    head, R = Vector((0, -0.42, 2.6)), 0.86
    snout = Vector((0, -1.12, 2.22))
    ear, tilt = Vector((0.7, -0.14, 3.46)), 24
    legs = []
    for x, y in ((0.34, -0.28), (0.35, 0.7)):
        for s in (-1, 1):
            legs += [("capsule", (s * x, y, 0.8), (s * x, y, 0.22), 0.26), ((s * x, y, 0.17), 0.28, (1.0, 1.05, 0.72))]
    body = k.fuse(
        [
            (head, R, (1.12, 1.0, 1.0)),
            *k.pair((0.44, -0.72, 2.36), 0.4, (1.0, 0.85, 0.8)),  # full cheeks
            (snout, 0.4, (1.15, 0.9, 0.82)),  # soft round muzzle
            ((0, -0.2, 1.7), 0.44, (1.0, 1.0, 1.15)),  # neck
            ((0, 0.22, 1.0), 0.68, (1.0, 1.3, 0.86)),  # plump barrel body
            *k.pair(ear, 0.46, (0.7, 0.38, 1.0), (0, tilt, 0)),
            *legs,
        ],
        coat,
        tris=2600,
    )
    k.zone(coat, (244, 214, 204), (0, -1.36, 2.2), (0.36, 0.2, 0.3), soft=0.5)  # faintly pink muzzle tip
    parts = [body]
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    for s in (-1, 1):
        parts.append(k.lens(body, (s * ear.x, ear.y, ear.z), (0, -1, 0), 0.4, k.flat((248, 170, 182)), scale=(0.5, 1), thick=0.2, sink=0.6, up=(s * axis.x, 0, axis.z), name="ear_in"))
    # The mane: separate locks fused softly enough that each one keeps its rounded edge.
    pink = k.paint("un_mane", [(0, (232, 116, 136)), (0.5, (244, 150, 166)), (1, (252, 186, 196))], 0.6, 3.6, rest=True, grain=(0.12, 26, "wave"))
    locks = []
    for _, pts, r0, r1 in (
        (0, [(0, -0.72, 3.38), (0, -0.3, 3.52), (0, 0.15, 3.34), (0, 0.42, 2.94), (0, 0.52, 2.35)], 0.36, 0.24),  # crest
        (1, [(0.3, -0.62, 3.34), (0.52, -0.25, 3.32), (0.64, 0.1, 3.0), (0.6, 0.3, 2.5), (0.48, 0.42, 2.05)], 0.3, 0.16),  # side locks
        (-1, [(-0.3, -0.62, 3.34), (-0.52, -0.25, 3.32), (-0.64, 0.1, 3.0), (-0.6, 0.3, 2.5), (-0.48, 0.42, 2.05)], 0.3, 0.16),
        (1, [(0.24, 0.0, 3.46), (0.34, 0.42, 3.15), (0.3, 0.62, 2.6), (0.22, 0.62, 2.0)], 0.28, 0.17),
        (-1, [(-0.24, 0.0, 3.46), (-0.34, 0.42, 3.15), (-0.3, 0.62, 2.6), (-0.22, 0.62, 2.0)], 0.28, 0.17),
        (-1, [(-0.08, -0.95, 3.32), (-0.42, -1.1, 3.12), (-0.78, -0.95, 2.86), (-0.9, -0.78, 2.6), (-0.82, -0.78, 2.42)], 0.22, 0.1),  # forelock, curling down the right
        (1, [(0.12, -0.95, 3.3), (0.42, -0.98, 3.24), (0.62, -0.8, 3.12)], 0.17, 0.1),
    ):
        locks += chain(pts, r0, r1, step=0.12)
    tail = chain([(0, 1.0, 1.4), (0, 1.36, 1.3), (-0.06, 1.62, 0.95), (0.0, 1.7, 0.5), (0.14, 1.56, 0.2), (0.24, 1.32, 0.3)], 0.38, 0.16, step=0.1)
    tail += chain([(0.12, 1.0, 1.36), (0.3, 1.3, 1.1), (0.4, 1.46, 0.72), (0.46, 1.4, 0.4)], 0.28, 0.12, step=0.1)
    hair = k.fuse(locks + tail, pink, tris=1300, soft=0.26, name="mane")
    parts.append(hair)
    # Tan cone horn with spiral ridges, between the ears.
    p, _ = k.land(body, head, k.outward(0, 58))
    parts.append(horn(p - Vector((0, -0.04, 0.12)), (0, -0.25, 1), 1.38, 0.31, k.paint("un_horn", [(0, (200, 120, 58)), (1, (236, 172, 104))], 3.3, 4.7), n=12, rings=12))
    daisy = disc(0.2, petals(8, 0.55, 1.2), k.flat((255, 255, 255)), heart=k.flat(k.SUNNY), n=32, cup=0.25, thick=0.14, hr=0.3, dome=0.18, closed=False, name="daisy")
    parts += onto([daisy], hair, (0.6, 0.1, 2.8), (1, 0.3, 0.1), sink=0.02)
    ink = k.flat((60, 46, 56))
    face = [k.lens(body, snout, k.outward(s * 20, 6), 0.05, ink, scale=(0.8, 1.2), thick=0.5, sink=0.5, seg=12, name="nostril") for s in (-1, 1)]
    face.append(k.mouth(body, snout, k.outward(0, -26), 0.16, k.flat(k.INKY), "smile"))
    parts += k.texel(face, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=white, iris=(22, 32, 92), nose=None, mouth_kind=None, eye_r=0.31, eye_wide=0.88, spread=31, eye_phi=-4, sheen=True, blush_theta=50, blush_phi=-24)
    return parts


# Ember Phoenix (mythic) -----------------------------------------------------------------------


def frond(length, width, m, lobes=0, depth=0.3, steps=10, n=8, flat=0.25, fan=False, name="frond"):
    """A feather along +X, flat face up, widest past the middle, to a point (fan=True: widening to
    a round end, like a gill). lobes > 0 notches both edges (`depth` deep) into a fringe."""
    pts, radii = [], []
    for i in range(steps + 1):
        s = i / steps
        pts.append((length * s, 0, length * 0.06 * math.sin(math.pi * s)))
        fringe = 1 - depth + depth * abs(math.cos(math.pi * lobes * s)) ** 0.25 if lobes else 1
        if fan:
            shape = (0.3 + 0.7 * s / 0.65) if s < 0.65 else math.sqrt(max(0.0, 1 - ((s - 0.65) / 0.35) ** 2))
        else:
            shape = math.sin(math.pi * s) ** 0.55 * (0.45 + 0.55 * s)
        radii.append(width * shape * fringe)
    ob = k.tube(pts, radii, m=m, n=n, name=name)
    ob.data.transform(Matrix.Diagonal((1, 1, flat, 1)))
    return ob


def plant(objs, root, d, face=(0, -1, 0)):
    """Moves parts built along +X, flat face up, so +X runs from root along d and the flat face
    looks towards `face`."""
    x = Vector(d).normalized()
    z = Vector(face) - x * x.dot(Vector(face))
    z.normalize()
    m = Matrix.Translation(Vector(root)) @ Matrix((x, z.cross(x), z)).transposed().to_4x4()
    objs = objs if isinstance(objs, (list, tuple)) else [objs]
    for ob in objs:
        ob.data.transform(m)
    return objs


def trail(points, radii, step=0.15):
    """(point, radius) samples along a smooth curve through points, radii eased between them."""
    pts = curve(points, step)
    out = []
    for i, p in enumerate(pts):
        t = i / (len(pts) - 1) * (len(radii) - 1)
        j = min(int(t), len(radii) - 2)
        out.append((p, radii[j] + (radii[j + 1] - radii[j]) * (t - j)))
    return out


def links(samples):
    """Fuse capsules between trail samples."""
    return [("capsule", tuple(a), tuple(b), (ra + rb) / 2) for (a, ra), (b, rb) in zip(samples, samples[1:])]


def capsules_of(points, r0, r1):
    """Fuse capsules along points, radius r0 to r1."""
    rs = [r0 + (r1 - r0) * i / (len(points) - 1) for i in range(len(points))]
    return [("capsule", tuple(a), tuple(b), (ra + rb) / 2) for a, b, ra, rb in zip(points, points[1:], rs, rs[1:])]


def creature_phoenix():
    """Remade from the Roblox AI reference (assets/garden/refs/phoenix_*.jpg): a scarlet phoenix chick
    sitting low, a cream face and chest, a hooked cream beak, big dark eyes with a red glint, spiky
    feather tufts round the head under a crest of flame tongues, two wings of pointed feathers raised
    in a V, red at the root and gold at the tips, and a long ragged flame tail trailing behind its
    left side with a curled tip (the "Ember Phoenix")."""
    red_rgb = (226, 70, 46)
    cream_rgb = (252, 226, 188)
    plume = k.paint("ph_plume", [(0, (170, 34, 40)), (0.35, red_rgb), (0.75, (240, 104, 52)), (1, (246, 138, 66))], 0, 4.4, rest=True, grain=(0.12, 22))
    fire = [(0, (200, 40, 40)), (0.45, (240, 92, 44)), (0.8, (252, 160, 60)), (1, (255, 214, 120))]
    head, R = Vector((0, -0.25, 3.3)), 1.1
    tufts = []  # spiky feather tufts round the crown, sides and back of the head
    for theta, phi in ((70, 30), (100, 10), (125, -10), (110, 40), (145, 20), (180, 30), (165, 50), (75, 55)):
        for s in ((-1, 1) if theta != 180 else (1,)):
            d = k.outward(s * theta, phi)
            tufts.append(toward(head + d * R * 0.95, d + Vector((0, 0.3, 0.5)), 0.27, (0.5, 0.42, 2.1)))
    ruff = []  # a ragged hem of feather points round the seat
    for a in range(0, 360, 30):
        d = k.outward(a + 15, 0)
        ruff.append(toward(Vector((0, 0.3, 0.55)) + Vector((d.x * 0.95, d.y * 1.1, 0)), d + Vector((0, 0, -0.5)), 0.22, (0.6, 0.4, 1.8)))
    body = k.fuse(
        [
            (head, R, (1.1, 0.98, 1.0)),
            *k.pair((0.55, -0.62, 3.02), 0.46, (1.0, 0.85, 0.8)),  # full cheeks
            ((0, 0.15, 1.25), 0.95, (1.0, 1.05, 1.15)),  # pear body
            ((0, 0.35, 0.5), 1.0, (1.05, 1.2, 0.5)),  # low seat
            *tufts,
            *ruff,
        ],
        plume,
        tris=1900,
        soft=0.2,
    )
    k.zone(plume, (246, 150, 70), (0, -0.9, 3.0), (1.05, 0.8, 1.0), soft=0.2, jag=0.25)  # orange round the face
    k.zone(plume, cream_rgb, (0, -1.0, 2.95), (0.85, 0.7, 0.72), soft=0.2, jag=0.2)  # cream face
    k.zone(plume, (250, 210, 160), (0, -0.85, 1.5), (0.6, 0.5, 0.8), soft=0.1, jag=0.35)  # cream chest
    k.zone(plume, (196, 48, 40), (0, 1.0, 1.5), (1.1, 0.8, 1.2), soft=0.3, jag=0.35)  # deeper red, ragged, over the back
    parts = [body]
    # Beak: hooked, cream, between and below the eyes.
    p, n = k.land(body, head, k.outward(0, -26))
    parts.append(k.texel(k.capsule(p - n * 0.1, p + n * 0.18 - Vector((0, 0, 0.16)), 0.22, 0.08, k.flat((250, 220, 150)), n=16, name="beak"), k.FACE_TEXEL))
    # Crest: flame tongues, the tallest curling back.
    crest_m = k.paint("ph_crest", fire, 4.1, 5.5, rest=True)
    for root, tip, r, bend in (((0, -0.3, 4.15), (0, 0.05, 5.5), 0.3, 0.14), ((0.4, -0.15, 4.05), (0.85, 0.15, 4.9), 0.22, -0.15), ((-0.4, -0.15, 4.05), (-0.85, 0.15, 4.9), 0.22, 0.15)):
        parts.append(k.rest(flame(root, tip, r, crest_m, bend=bend, n=10)))
    # Wings raised in a V: five pointed feathers each, fanned up and out from the shoulder.
    for s in (-1, 1):
        wing = k.paint(f"ph_wing{s}", fire, s * 0.7, s * 3.3, axis="X", rest=True)
        for length, width, pitch, yaw, y in ((2.2, 0.42, 72, 22, 0.42), (2.8, 0.46, 58, 22, 0.42), (3.0, 0.48, 44, 22, 0.42), (2.7, 0.46, 30, 22, 0.42), (2.1, 0.42, 16, 22, 0.42),
                                             (1.4, 0.4, 66, 10, 0.3), (1.6, 0.42, 46, 10, 0.3), (1.3, 0.38, 26, 10, 0.3)):  # flight feathers, then coverts in front
            f = frond(length, width, wing, lobes=0, n=6, steps=8)
            xf(f, (0.62, y, 2.0), yaw=yaw, pitch=pitch, roll=90, mirror=s < 0)
            parts.append(k.texel(k.rest(f), 0.5))
    # Flame tail: a ragged chain lying out behind the left side, its tip curling up.
    path = trail([(0.0, 0.9, 0.42), (0.5, 1.7, 0.32), (1.2, 2.3, 0.32), (1.75, 2.45, 0.66), (1.7, 2.15, 1.12)], [0.52, 0.46, 0.38, 0.28, 0.14], 0.18)
    tail = links(path)
    for i in range(2, len(path) - 2, 2):
        (q, r), (q2, _) = path[i], path[i + 1]
        t = (q2 - q).normalized()
        side = t.cross(Vector((0, 0, 1))).normalized()
        for sd in (-1, 1):
            tail.append(toward(q + side * sd * r * 0.8 + Vector((0, 0, 0.1)), side * sd + t * 1.1 + Vector((0, 0, 0.3)), r * 0.65, (0.5, 0.36, 2.3)))
    tail_m = k.paint("ph_tail", fire, 0.8, 2.5, axis="Y", rest=True, grain=(0.1, 14))
    parts.append(k.fuse(tail, tail_m, tris=750, soft=0.17, name="tail"))
    parts += k.face(body, head, R, skin=cream_rgb, iris=(70, 22, 26), nose=None, mouth_kind=None, eye_r=0.28, eye_wide=0.88, spread=30, eye_phi=-10, sheen=True, blush_theta=50, blush_phi=-30)
    return parts


# Aurora Whale (divine) ------------------------------------------------------------------------


def creature_whale():
    """Remade from the Roblox AI reference (assets/garden/refs/whale_*.jpg) for shape and face: a
    round plush whale resting on its white belly, small eyes low on the sides, pink cheeks, a
    little smile, flippers out at the front and a tail rising behind to upturned flukes. The colours
    keep the Aurora Whale concept (the reference came from a simpler prompt): soft teal, violet and
    mint aurora stripes round the body (the "Aurora Whale")."""
    teal, violet, mint, blue, rose = (64, 196, 196), (146, 108, 222), (150, 236, 206), (88, 128, 226), (214, 150, 230)
    stripes = [(0, (226, 232, 246)), (0.25, (246, 248, 254))]  # pale belly, then soft bands upwards
    z = 0.265
    for rgb, width in ((mint, 0.03), (violet, 0.1), (teal, 0.09), (rose, 0.03), (blue, 0.09), (mint, 0.03), (violet, 0.08), (teal, 0.08), (rose, 0.03), (blue, 0.07), (mint, 0.03), (teal, 0.2)):
        stripes += [(z, rgb), (min(1, z + width - 0.015), rgb)]
        z += width
    skin = k.paint("wh_skin", stripes, 0, 4.5, rest=True, grain=(0.05, 20, "wave"))
    head, R = Vector((0, -0.55, 1.8)), 2.0
    tail = chain([(0, 1.3, 2.1), (0, 2.3, 2.55), (0, 2.95, 3.2), (0, 3.2, 3.8)], 1.0, 0.34, step=0.2)
    body = k.fuse(
        [
            (head, R, (0.95, 1.2, 0.9)),
            *tail,
            *k.pair((0.72, 3.35, 4.0), 0.75, (1.25, 0.6, 0.2), (20, -25, 0)),  # flukes, upturned
            *k.pair((1.78, -0.3, 0.8), 0.86, (1.3, 0.55, 0.22), (0, 30, 40)),  # flippers, forward and down
        ],
        skin,
        tris=3800,
    )
    for s in (-1, 1):
        k.zone(skin, teal, (s * 2.0, -0.45, 0.6), (1.05, 0.8, 0.55), soft=0.15)  # teal flippers
        k.zone(skin, mint, (s * 2.4, -0.75, 0.42), (0.4, 0.4, 0.4), soft=0.4)  # paler tips
    parts = [body]
    parts.append(k.texel(k.mouth(body, head, k.outward(0, -14), 0.24, k.flat(INK), "smile"), k.FACE_TEXEL))
    parts += k.face(body, head, R, skin=(246, 248, 254), nose=None, mouth_kind=None, eye_r=0.17, eye_wide=0.9, spread=68, eye_phi=-2, sheen=True, blush_theta=76, blush_phi=-22, blush_r=0.12)
    return parts


# Nimbus Kirin (divine) ------------------------------------------------------------------------


def creature_kirin():
    """Remade from the Roblox AI reference (assets/garden/refs/kirin_*.jpg): a mint fawn-kirin standing
    on four short legs, a big head with a white lower face, a black button nose, big dark-teal eyes,
    pointed ears out to the sides with pink insides, thick tan antlers with two tines each, white
    cloud puffs on its brow, shoulders and hips, a white chest, a scale pattern over the back and a
    short tail with a white puff (the "Nimbus Kirin")."""
    mint_rgb = (168, 226, 206)
    coat = k.paint("ki_coat", [(0, (112, 184, 164)), (0.4, mint_rgb), (1, (200, 242, 226))], 0, 4.6, rest=True)
    white = (252, 252, 250)
    head, R = Vector((0, -0.7, 3.45)), 1.38
    snout = Vector((0, -1.9, 3.0))
    ear, tilt = Vector((1.62, -0.5, 4.0)), 68
    legs = []
    for y in (-0.55, 0.85):
        for s in (-1, 1):
            legs += [("capsule", (s * 0.52, y, 1.3), (s * 0.52, y, 0.28), 0.27), ((s * 0.52, y, 0.18), 0.3, (1.0, 1.1, 0.65))]
    body_c = Vector((0, 0.15, 1.5))
    body = k.fuse(
        [
            (head, R, (1.12, 0.95, 0.95)),
            *k.pair((0.6, -1.2, 3.05), 0.5, (1.0, 0.85, 0.8)),  # full cheeks
            (snout, 0.36, (1.15, 0.85, 0.8)),  # small muzzle
            ((0, -0.55, 2.35), 0.5),  # neck
            ((0, -0.45, 1.7), 0.62),  # chest
            (body_c, 0.85, (0.95, 1.3, 0.82)),  # barrel body
            *k.pair(tuple(ear), 0.66, (0.5, 0.25, 1.0), (0, tilt, 0)),  # pointed ears, out to the sides
            toward((0, 1.25, 1.95), (0, 0.6, 1), 0.2, (0.8, 0.8, 1.5)),  # short tail, flicked up
            *legs,
        ],
        coat,
        tris=2700,
    )
    k.zone(coat, white, (0, -1.85, 2.8), (1.3, 0.9, 0.75), soft=0.2)  # white lower face
    k.zone(coat, white, (0, -0.95, 1.75), (0.5, 0.4, 0.75), soft=0.2, jag=0.25)  # white chest
    # Scales over the back and flanks: a darker crescent under each, in staggered rows.
    for row, z in enumerate((2.05, 1.8, 1.55, 1.3)):
        for i in range(-4, 5):
            a = 90 + 22 * i + (11 if row % 2 else 0)
            for s in (-1, 1):
                p, n = k.land(body, body_c, k.outward(s * a, 30 - 18 * row))
                if p.y < -0.5 or p.z < 1.0:
                    continue
                k.zone(coat, (130, 196, 176), p, (0.16, 0.16, 0.16), soft=0.2)
                k.zone(coat, (184, 234, 214), p + Vector((0, 0, 0.06)), (0.14, 0.14, 0.13), soft=0.25)
    parts = [body, *ears_in(body, ear, tilt, k.flat((246, 180, 192)), 0.4)]
    # Antlers: thick tan beams rising and out, two tines each, fused with round tips.
    beams = []
    for s in (-1, 1):
        beams += capsules_of(curve([(s * 0.38, -0.6, 4.3), (s * 0.55, -0.55, 4.85), (s * 0.85, -0.45, 5.35), (s * 1.2, -0.35, 5.85)], 0.12), 0.24, 0.17)
        beams += capsules_of(curve([(s * 0.58, -0.55, 4.95), (s * 0.48, -0.75, 5.3), (s * 0.45, -0.85, 5.55)], 0.12), 0.17, 0.15)
        beams += capsules_of(curve([(s * 0.95, -0.42, 5.45), (s * 0.85, -0.6, 5.8), (s * 0.82, -0.66, 6.0)], 0.12), 0.15, 0.14)
    antler = k.paint("ki_antler", [(0, (190, 120, 72)), (1, (226, 166, 112))], 4.3, 6.0, rest=True)
    parts.append(k.fuse(beams, antler, tris=700, soft=0.2, name="antlers"))
    # Cloud puffs: a forelock on the brow, one on each shoulder and hip, and the tail tip.
    puffs = []
    for i in range(9):  # a big cloud forelock over the brow
        a = math.radians(i * 40)
        puffs.append(((0.72 * math.cos(a), -0.9 + 0.5 * math.sin(a), 4.55 + 0.06 * math.sin(3 * a)), 0.36))
    puffs += [((0, -0.9, 4.8), 0.48), ((0, -1.4, 4.42), 0.34), ((0.35, -1.3, 4.38), 0.28), ((-0.35, -1.3, 4.38), 0.28)]
    for s in (-1, 1):
        for c, r in (((s * 0.6, -0.4, 1.95), 0.22), ((s * 0.68, -0.2, 1.75), 0.2), ((s * 0.56, -0.6, 1.7), 0.18),  # shoulders
                     ((s * 0.58, 0.8, 1.95), 0.22), ((s * 0.66, 0.95, 1.74), 0.18)):  # hips, sunk half into the coat
            puffs.append((c, r, (0.7, 1, 0.8)))
    puffs += [((0, 1.45, 2.3), 0.22), ((0.1, 1.4, 2.15), 0.17), ((-0.1, 1.4, 2.15), 0.17)]  # tail tip
    cloud = k.paint("ki_cloud", [(0, (226, 234, 240)), (1, (255, 255, 255))], 1.0, 4.8, rest=True)
    parts.append(k.texel(k.fuse(puffs, cloud, tris=1000, soft=0.3, name="clouds"), 0.7))
    face = [k.lens(body, snout, k.outward(0, 22), 0.12, k.flat((30, 26, 30)), scale=(1.35, 0.95), thick=0.7, sink=0.4, seg=16, name="nose"),
            k.mouth(body, snout, k.outward(0, -22), 0.12, k.flat(INK), "w")]
    parts += k.texel(face, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=(240, 246, 244), iris=(18, 86, 94), nose=None, mouth_kind=None, eye_r=0.29, eye_wide=0.9, spread=32, eye_phi=-8, sheen=True, blush_theta=48, blush_phi=-24)
    return parts


# Stardust Axolotl (secret) --------------------------------------------------------------------


def creature_axolotl():
    """Remade from the Roblox AI reference (assets/garden/refs/axolotl_*.jpg): a pink axolotl sitting
    up, a wide round head with big black eyes far apart and a small smile, three big feathery gill
    fronds a side fanned up and out with gold-flecked fringes, a pear body with little hands, gold
    stardust flecks, and a tail lying out behind its left side with a scalloped fin along the top
    (the "Stardust Axolotl")."""
    pink_rgb = (244, 176, 186)
    skin = k.paint("ax_skin", [(0, (214, 126, 146)), (0.45, (236, 160, 174)), (1, (250, 196, 204))], 0, 2.3, rest=True)
    gold = (236, 196, 90)
    head, R = Vector((0, -0.05, 1.67)), 0.75
    path = trail([(0.05, 0.45, 0.35), (0.35, 0.95, 0.24), (0.75, 1.3, 0.2), (1.15, 1.45, 0.2)], [0.3, 0.22, 0.15, 0.07], 0.1)
    fin = []
    for i in range(1, len(path) - 1):
        q, r = path[i]
        if i % 3:
            continue
        fin.append(toward(q + Vector((0, 0, r + 0.06)), (0.2, 0.6, 1), 0.13, (0.35, 1.2, 1.6)))  # a few soft fin points
    hands = []
    for s in (-1, 1):
        hand = Vector((s * 0.74, -0.32, 0.5))
        hands += [("capsule", (s * 0.55, -0.1, 0.85), tuple(hand), 0.11), (tuple(hand), 0.12, (1.0, 1.0, 0.9))]
        for dx in (-0.08, 0.0, 0.08):
            hands.append(("capsule", tuple(hand), tuple(hand + Vector((s * 0.06 + dx, -0.08, -0.14))), 0.05))
    body = k.fuse(
        [
            (head, R, (1.08, 0.95, 0.86)),
            *k.pair((0.42, -0.35, 1.45), 0.36, (1.0, 0.85, 0.8)),  # full cheeks
            ((0, 0.0, 0.62), 0.6, (1.05, 0.95, 1.0)),  # pear body
            ((0, 0.05, 0.25), 0.62, (1.05, 1.0, 0.45)),  # seat
            *k.pair((0.4, -0.38, 0.1), 0.15, (1.0, 1.4, 0.6)),  # little feet
            *hands,
            *links(path),
            *fin,
        ],
        skin,
        tris=2050,
        res=0.03,
    )
    k.zone(skin, (252, 214, 214), (0, -0.55, 0.55), (0.48, 0.3, 0.48), soft=0.4)  # paler belly
    for c, r in (((0.12, -0.58, 0.75), 0.1), ((-0.2, -0.55, 0.45), 0.07), ((0.25, -0.5, 1.95), 0.07), ((-0.3, -0.4, 2.1), 0.08), ((0.0, 0.2, 2.3), 0.09), ((0.3, 0.5, 0.7), 0.08), ((-0.35, 0.45, 0.9), 0.07), ((0.6, 1.1, 0.42), 0.07)):
        k.zone(skin, gold, c, (r, r, r * 1.3), soft=0.15)  # stardust flecks
    parts = [body]
    # Gills: three feathery fronds a side, fanned up and out from the back of the head.
    gill = k.paint("ax_gill", [(0, (232, 120, 156)), (1, (250, 176, 196))], 1.4, 3.0, rest=True, dots=[(gold, 16, 0.1)])
    fringe = []
    for s in (-1, 1):
        for root, d, length in (((0.5, 0.1, 2.0), (0.35, 0.15, 1), 1.3), ((0.66, 0.15, 1.82), (0.85, 0.2, 0.8), 1.3), ((0.76, 0.2, 1.56), (1, 0.25, 0.15), 1.05)):
            f = frond(length, 0.5, gill, steps=22, n=6, flat=0.22, fan=True)
            base, x = Vector((s * root[0], root[1], root[2])), Vector((s * d[0], d[1], d[2])).normalized()
            plant(f, base, x, face=(0, -1, 0.1))
            parts.append(k.rest(f))
            z = Vector((0, -1, 0.1)) - x * x.dot(Vector((0, -1, 0.1)))
            y = z.normalized().cross(x)
            mid = base + x * length * 0.6
            for t in range(-6, 7):  # filaments round the rim of the fan, from one side over the tip to the other
                a = math.radians(t * 15)
                edge = mid + (x * math.cos(a) * 0.4 * length + y * math.sin(a) * 0.5) * 0.98
                out = (edge - mid).normalized()
                fringe.append(toward(edge + out * 0.03, out, 0.075, (0.6, 0.45, 1.45)))
    tips = k.paint("ax_fringe", [(0, (236, 132, 164)), (1, (248, 168, 192))], 1.4, 3.2, rest=True, dots=[(gold, 10, 0.16)])
    parts.append(k.texel(k.fuse(fringe, tips, tris=900, soft=0.15, res=0.025, name="fringe"), 0.6))
    parts.append(k.texel(k.mouth(body, head, k.outward(0, -30), 0.09, k.flat(INK), "smile"), k.FACE_TEXEL))
    parts += k.face(body, head, R, skin=pink_rgb, iris=(22, 20, 30), nose=None, mouth_kind=None, eye_r=0.24, eye_wide=0.9, spread=42, eye_phi=-16, sheen=True, blush_theta=52, blush_phi=-32)
    return parts


NOTES = "One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are."
ASSETS = [
    dict(name=name, build=fit(size)(build), budget=k.CREATURE_BUDGET, finalize=k.HD, size=size, priority=1, order=20 + i, replaces="none (new species)", notes=f"{label}. {NOTES}", glow={})
    for i, (name, build, size, label) in enumerate(
        (
            ("creature_duck", creature_duck, [2.4, 3.0, 2.6], "Puddle Duckling (common)"),
            ("creature_lamb", creature_lamb, [3.2, 3.8, 2.3], "Clover Lamb (uncommon)"),
            ("creature_hedgehog", creature_hedgehog, [2.57, 2.8, 2.45], "Acorn Hedgehog (rare)"),
            ("creature_deer", creature_deer, [4.38, 5.0, 3.40], "Blossom Fawn (epic)"),
            ("creature_panda", creature_panda, [3.08, 4.5, 2.78], "Bamboo Panda (epic)"),
            ("creature_unicorn", creature_unicorn, [2.50, 5.5, 4.14], "Daisy Unicorn (legendary)"),
            ("creature_phoenix", creature_phoenix, [5.4, 5.5, 4.33], "Ember Phoenix (mythic)"),
            ("creature_whale", creature_whale, [5.22, 4.5, 6.77], "Aurora Whale (divine)"),
            ("creature_kirin", creature_kirin, [4.34, 6.0, 3.8], "Nimbus Kirin (divine)"),
            ("creature_axolotl", creature_axolotl, [3.35, 3.0, 2.02], "Stardust Axolotl (secret)"),
        )
    )
]
