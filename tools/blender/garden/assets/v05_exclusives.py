"""v0.5 exclusives (GARDEN-054, GDD X3.4, architecture 9.3): the six login-reward species and the
Weekly and Monthly Eggs. The species follow the README "Creature standard" (HD pass), richer than
the common creatures as earned rewards; one mesh each, facing Blender -Y."""

import math
import os
import sys

import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creatures_a import xf  # noqa: E402
from creatures_b import WHITE, blob  # noqa: E402
from eggs import fit  # noqa: E402


# HD helpers (README "Creature standard") -----------------------------------------------------


def settle(parts, size):
    """creatures_a.fit plus finalize's centring, done here: scales the parts to `size` [x, height,
    depth] and stands them on the origin. Paints made after it can place marks exactly (the README
    rule against paint marks is only that fit moves them). Returns the matrix applied."""
    lo, hi = k._ground_dims(parts)
    d = hi - lo
    s = (size[0] / d.x, size[2] / d.y, size[1] / d.z)
    print(f"[v05] fit scale x {s[0]:.2f} y {s[1]:.2f} z {s[2]:.2f}", flush=True)
    m = Matrix.Translation((-(lo.x + hi.x) / 2 * s[0], -(lo.y + hi.y) / 2 * s[1], -lo.z * s[2])) @ Matrix.Diagonal((*s, 1))
    for ob in parts:
        ob.data.transform(m)
    return m


def mark(m, rgb, p, r, r_in=0.0, below=None):
    """paint() mark (disc or ring) at build point p, radius r in build studs, after settle(m);
    `below`: only under that build height."""
    s = sum(m.to_scale()) / 3
    out = (rgb, m @ Vector(p), r_in * s, r * s)
    return out if below is None else out + ((m @ Vector((0, 0, below))).z,)


def paddle(length, width, m, thick=0.12, n=10, root=0.3, ease=1.0, name="paddle"):
    """Flat blade along +X, `root` as wide at the root, round at the tip (feathers, wings); lies
    in local XY. Built as k.leaf is, with an elliptical tip instead of a point. ease > 1 keeps
    it thin (a quill) further out."""
    pts, radii = [], []
    for i in range(7):  # root to the widest point
        s = 0.62 * i / 6
        pts.append((length * s, 0, 0))
        radii.append(width * (root + (1 - root) * math.sin(math.pi / 2 * i / 6) ** ease))
    for i in range(1, 9):  # elliptical tip
        a = math.pi / 2 * i / 8
        pts.append((length * (0.62 + 0.38 * math.sin(a)), 0, 0))
        radii.append(width * math.cos(a) if i < 8 else 0)
    ob = k.tube(pts, radii, m=m, n=n, name=name)
    ob.data.transform(Matrix.Diagonal((1, 1, thick, 1)))
    return ob


def swap(ob, m):
    ob.data.materials[0] = m
    return ob


# Pebble Puffin (uncommon, weekly) ------------------------------------------------------------


def creature_puffin():
    """HD standard: one fused body; white face and belly are paint marks placed after settle."""
    orange = k.flat((255, 130, 45))
    head, R = Vector((0, -0.05, 2.1)), 0.82
    body = k.fuse(
        [
            (head, R, (1.1, 0.98, 0.95)),
            ((0, 0.1, 1.25), 0.82, (1.02, 0.98, 0.95)),
            ((0, 0.1, 0.85), 0.7, (1.1, 1.0, 0.6)),  # round seat
            *k.pair((0.8, 0.2, 1.3), 0.32, (0.42, 0.9, 1.25), (0, 16, 0)),  # wings
            ((0, 0.9, 0.82), 0.24, (0.9, 1.0, 0.45), (-25, 0, 0)),  # tail
        ],
        k.flat((50, 50, 66)),
        tris=2700,
    )
    # Tall puffin beak, flat at the sides, a triangle from the side, as its own fused shape.
    beak = k.fuse(
        [((0, -0.84, 1.93), 0.34, (0.58, 0.6, 1.0)), ((0, -1.04, 1.85), 0.25, (0.58, 0.9, 0.85)), ((0, -1.25, 1.76), 0.12, (0.65, 1.0, 0.9))],
        k.flat((255, 140, 50)),
        tris=450,
        name="beak",
    )
    pebble = k.sphere(1.0, (0, 0.05, 0.26), m=k.flat((170, 170, 185)), scale=(1.2, 1.05, 0.28), seg=36, rings=8, name="pebble")
    parts = [pebble, body, beak]
    for s in (-1, 1):
        parts.append(k.sphere(0.22, (s * 0.34, -0.55, 0.55), m=orange, scale=(0.95, 1.45, 0.42), seg=20, rings=8, name="foot"))
        parts.append(k.lens(body, (s * 0.21, 0, 1.79), (0, -1, 0), 0.075, k.flat((255, 196, 70)), thick=0.5, sink=0.4, seg=12, name="rosette"))
    # Sea pinks (thrift) growing from the pebble: round pink heads on stems.
    thrift = []
    for base, top, r in (((-0.95, 0.15, 0.4), (-1.0, 0.05, 1.0), 0.17), ((-0.8, 0.45, 0.4), (-0.86, 0.5, 0.82), 0.14)):
        parts.append(k.capsule(base, top, 0.035, 0.03, k.flat((100, 175, 90)), n=8, name="stem"))
        thrift.append(k.sphere(r, top, m=k.flat((250, 130, 185)), seg=20, rings=8, name="thrift"))
    parts += thrift
    parts += k.face(body, head, R, skin=WHITE, nose=None, mouth_kind=None, eye_phi=8, spread=36)
    k.texel(beak, k.FACE_TEXEL)

    m = settle(parts, SIZE["creature_puffin"])
    ink = (32, 32, 46)
    swap(body, k.paint("pf_body", [(0, ink), (1, (70, 72, 96))], 0.5, 3.0, marks=[
        mark(m, WHITE, (0, -1.25, 1.0), 1.0),  # belly
        mark(m, (238, 238, 244), (0, -1.3, 1.95), 1.02),  # face, a touch greyer than the belly
        # Collar: a shell round a point behind the neck, so it crosses only the white front.
        mark(m, (46, 47, 64), (0, 0.6, 2.1), 1.53, r_in=1.44, below=1.85),
    ]))
    pink = k.paint("pf_thrift", [(0, (235, 105, 165)), (1, (255, 165, 205))], 0.7, 1.2, dots=[((255, 215, 235), 28, 0.14)])
    for ob in thrift:
        swap(ob, pink)
    slate, yellow = (125, 140, 172), (255, 215, 70)
    y0, y1 = (m @ Vector((0, -0.84, 0))).y, (m @ Vector((0, -1.37, 0))).y
    swap(beak, k.paint("pf_beak", [(0, (245, 90, 40)), (0.5, (255, 140, 50)), (0.56, yellow), (0.7, yellow), (0.76, slate), (1, slate)], y1, y0, axis="Y"))
    swap(pebble, k.paint("pf_pebble", [(0, (140, 140, 158)), (1, (205, 205, 218))], 0, 0.6, dots=[((182, 182, 198), 6, 0.18)]))
    return parts


# River Otter (rare, weekly) ------------------------------------------------------------------


def scallop(r, m, ribs=7, thick=0.05, name="shell"):
    """Ribbed scallop shell with a wavy rim, hinge at the origin, opening along local +Y, domed
    towards +Z; solid, so it shows from behind too (Roblox culls back faces)."""

    def fn(u, v):
        a = math.radians(-72 + 144 * u)
        rib = math.cos(2 * math.pi * ribs * u)
        rr = r * v * (1 + 0.035 * rib * v)
        z = r * (0.24 * math.sin(math.pi * v) ** 0.8 * math.cos(a) ** 0.5 + 0.035 * rib * v)
        return (rr * math.sin(a), rr * math.cos(a), z)

    return k.surface(ribs * 4, 4, fn, m=m, thickness=thick, name=name)


def creature_otter():
    """HD standard: floating on its back in a pool, head raised, a scallop held on its chest."""
    # The face tilts up (it lies on its back) and the shell is held up over the chest, so a
    # player looking down from the front sees the face, the shell above it and the feet behind.
    head, R = Vector((0, -1.75, 1.3)), 0.84
    snout = Vector((0, -2.44, 1.52))
    paw = Vector((0.5, -0.68, 1.98))
    body = k.fuse(
        [
            (head, R, (1.12, 0.95, 0.94)),
            (snout, 0.35, (1.3, 0.8, 0.72), (-28, 0, 0)),
            ((0, -0.8, 1.0), 0.85, (1.0, 1.0, 0.82)),  # chest
            ((0, 0.4, 0.72), 0.95, (1.0, 1.62, 0.74)),  # long body, back in the water
            *k.pair((0.8, -1.45, 1.87), 0.2, (1.0, 0.75, 1.0)),  # small round ears
            *[("capsule", (s * 0.72, -1.0, 1.3), (s * paw.x, paw.y, paw.z - 0.06), 0.18) for s in (-1, 1)],  # arms up to the shell
            *k.pair(paw, 0.21, (0.85, 0.9, 1.0)),  # paws gripping the shell's sides
            *k.pair((0.5, 1.75, 1.1), 0.3, (0.9, 0.6, 1.2), (-35, 0, 0)),  # hind feet up out of the water
            ((0, 2.15, 0.42), 0.38, (1.0, 1.4, 0.55)),  # flat tail
            ((0, 2.65, 0.34), 0.28, (1.0, 1.4, 0.5)),
            ((0, 3.0, 0.3), 0.17, (1.0, 1.3, 0.55)),
        ],
        k.flat((150, 105, 75)),
        tris=3000,
    )
    pool = k.lathe([(0, 0), (1.95, 0), (2.0, 0.06), (1.94, 0.13), (1.6, 0.15), (0, 0.15)], m=k.flat((150, 205, 245)), n=48, scale=(1, 1.3, 1), name="pool")
    f, up = Vector((0, -0.87, 0.5)), Vector((0, 0.5, 0.87))  # shell faces the viewer, top leaning back
    shell = scallop(0.8, k.flat((255, 190, 175)))
    shell.data.transform(Matrix.Translation((0, -0.78, 1.62)) @ Matrix((up.cross(f), up, f)).transposed().to_4x4())
    p, n = k.land(body, (0.3, -0.15, 0), (0, 0, 1))
    pearl = k.sphere(0.13, p + n * 0.11, m=k.flat((250, 245, 255)), seg=20, rings=10, name="pearl")
    dark, ink = k.flat((70, 45, 40)), k.flat(k.INKY)
    parts = [pool, body, shell, pearl]
    parts.append(k.lens(body, snout, k.outward(0, 30), 0.14, dark, scale=(1.3, 0.85), thick=0.55, sink=0.4, seg=16, name="nose"))
    parts.append(k.mouth(body, snout, k.outward(0, -30), 0.2, ink, "w"))
    for s in (-1, 1):
        for dz in (0.06, -0.06):
            p, n = k.land(body, snout, k.outward(s * 62, dz * 80))
            parts.append(k.tube([p - n * 0.02, p + n * 0.25 + Vector((s * 0.2, 0, dz)), p + n * 0.42 + Vector((s * 0.38, 0.06, dz * 2.5))], [0.02, 0.016, 0.006], m=dark, n=4, name="whisker"))
    k.texel(parts[4:], k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=(225, 200, 170), nose=None, mouth_kind=None, eye_phi=24, spread=36)

    m = settle(parts, SIZE["creature_otter"])
    fur = (150, 104, 74)
    swap(body, k.paint("ot_fur", [(0, (100, 66, 48)), (0.6, fur), (1, (175, 125, 88))], 0, 2.2, marks=[
        mark(m, (232, 208, 176), (0, -0.55, 2.2), 1.0),  # belly
        mark(m, (232, 208, 176), (0, 0.35, 2.0), 0.88),
        mark(m, (222, 196, 162), head + Vector((0, -0.1, 0)), 0.98),  # pale sea-otter head
        mark(m, fur, (0.8, -1.45, 1.87), 0.27),  # ears stay brown
        mark(m, fur, (-0.8, -1.45, 1.87), 0.27),
        mark(m, (245, 228, 205), snout + Vector((0, -0.25, 0)), 0.42),  # muzzle
        mark(m, (95, 62, 46), paw, 0.26),  # dark paws
        mark(m, (95, 62, 46), (-paw.x, paw.y, paw.z), 0.26),
        mark(m, (120, 80, 58), (0.5, 1.95, 1.3), 0.32),  # darker soles on the raised feet
        mark(m, (120, 80, 58), (-0.5, 1.95, 1.3), 0.32),
    ]))
    ripple = (205, 235, 255)
    c = (0.6, -1.0, 0.15)
    swap(pool, k.paint("ot_water", [(0, (110, 180, 235)), (1, (160, 215, 250))], 0, 0.2, marks=[
        mark(m, ripple, c, 1.45, r_in=1.38), mark(m, ripple, c, 1.9, r_in=1.84), mark(m, ripple, (-1.0, 1.4, 0.15), 0.62, r_in=0.56),
        mark(m, ripple, (-1.0, 1.4, 0.15), 0.95, r_in=0.9),
    ]))
    lo, hi = (m @ Vector((0, 0, 1.6))).z, (m @ Vector((0, 0, 2.35))).z
    swap(shell, k.paint("ot_shell", [(0, (245, 120, 140)), (1, (255, 215, 200))], lo, hi))
    return parts


# Spa Capybara (epic, weekly) -----------------------------------------------------------------


def creature_capybara():
    """HD standard: a round loaf with a big blunt head, closed happy eyes (its identity, so the
    face is built here without k.face's open eyes), a towel draped on its head, a yuzu on top."""
    tan = (204, 148, 88)
    fur = k.paint("ca_fur", [(0, (146, 96, 56)), (0.55, tan), (1, (222, 170, 108))], 0.2, 3.3)
    dark, ink = k.flat((92, 62, 48)), k.flat(k.EYE_INK)
    head, R = Vector((0, -0.95, 2.25)), 1.2
    snout = Vector((0, -2.08, 1.95))
    ear = (0.84, -0.4, 2.95)
    body = k.fuse(
        [
            (head, R, (1.18, 1.08, 0.88)),
            (snout, 0.72, (1.12, 0.95, 0.82)),  # long, deep, blunt capybara muzzle
            ((0, 0.5, 1.4), 1.25, (1.18, 1.3, 0.95)),  # barrel body
            *k.pair(ear, 0.24, (1.0, 0.55, 0.85), (0, 20, 0)),  # small round ears
            *[("capsule", (s * 0.72, y, 0.3), (s * 0.72, y + 0.05, 0.9), 0.3) for s in (-1, 1) for y in (-0.55, 1.3)],  # stubby legs
            *[e for y in (-0.6, 1.25) for e in k.pair((0.74, y, 0.2), 0.32, (0.9, 1.4, 0.62))],  # feet: flat beans
        ],
        fur,
        tris=3200,
    )
    parts = [body]
    for s in (-1, 1):
        axis = (s * math.sin(math.radians(20)), 0, math.cos(math.radians(20)))
        parts.append(k.lens(body, (s * ear[0], ear[1], ear[2]), (0, -1, 0), 0.2, k.flat((150, 95, 80)), scale=(0.6, 0.8), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    # Face: happy closed eyes (k.mouth's U turned over), blush, the dark nose pad and a "w" mouth.
    k.texel(body, k.FACE_TEXEL, k.land(body, head, k.outward(0, -12))[0], R * 1.2)
    face = []
    for s in (-1, 1):
        face.append(k.mouth(body, head, k.outward(s * 33, 15), R * 0.16, ink, "smile", r=R * 0.036, up=(0, 0, -1)))
        face.append(k.lens(body, head, k.outward(s * 52, -12), R * 0.17, k.flat(k.mix(tan, k.BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
    face.append(k.lens(body, snout, k.outward(0, 28), 0.2, dark, scale=(1.5, 0.75), thick=0.5, sink=0.4, seg=16, name="nose"))
    face.append(k.mouth(body, snout, k.outward(0, -22), 0.2, k.flat(k.INKY), "w"))
    parts += k.texel(face, k.FACE_TEXEL)

    # Towel draped over the crown: a grid cast down onto the head, given thickness.
    def drape(u, v):  # solidify centres the 0.16 thickness: bottom 0.02 under the fur
        p, n = k.land(body, (1.16 * u - 0.58, -1.41 + 0.86 * v, 0), (0, 0, 1))
        return tuple(p + n * 0.06)

    towel = k.surface(12, 10, drape, m=k.flat(WHITE), thickness=0.16, name="towel")
    top = Vector(k.land(body, (0, -0.98, 0), (0, 0, 1))[0]) + Vector((0, 0, 0.14))
    yuzu = k.blob(0.34, top + Vector((0, 0, 0.31)), k.flat((255, 210, 60)), scale=(1, 1, 0.92), name="yuzu")
    stem = k.capsule(top + Vector((0, 0, 0.6)), top + Vector((0.03, 0.02, 0.72)), 0.04, 0.03, dark, n=8, name="stem")
    green = k.flat((105, 185, 85))
    leaves = xf(k.leaf(0.48, 0.18, green, droop=0.25, n=8, steps=8), top + Vector((0.03, 0.02, 0.68)), yaw=-30, pitch=12)
    leaves += xf(k.leaf(0.36, 0.14, k.flat((140, 210, 100)), droop=0.25, n=8, steps=8), top + Vector((0.03, 0.02, 0.68)), yaw=160, pitch=18)
    parts += [towel, yuzu, stem, *leaves]

    settle(parts, SIZE["creature_capybara"])
    swap(towel, k.paint("ca_towel", [(0, (255, 255, 252)), (1, (250, 252, 255))], -1, 1, axis="X", bands=((130, 195, 240), 0.42)))
    lo, hi = k._ground_dims([yuzu])
    swap(yuzu, k.paint("ca_yuzu", [(0, (245, 180, 40)), (1, (255, 232, 100))], lo.z, hi.z, grain=(0.08, 40)))
    return parts


# Maple Red Panda (legendary, monthly) --------------------------------------------------------


def maple_leaf(size, m, vein=None, n=60):
    """Five pointed lobes with fine teeth, flat in local XZ (front -Y) round the origin, stem
    down (-Z), veins on the front when `vein` is given. Triangulated: the outline is concave."""
    lobes = ((90, 1.0), (22, 0.88), (158, 0.88), (-38, 0.55), (218, 0.55))
    outline = []
    for i in range(n):
        t = 360 * i / n
        r = 0.4
        for a, length in lobes:
            r = max(r, length * (1 - (abs((t - a + 180) % 360 - 180) / 50) ** 1.3))
        r *= 1 - 0.06 * abs((t / 6) % 2 - 1)  # serrated edge
        outline.append((size * r * math.cos(math.radians(t)), size * r * math.sin(math.radians(t))))
    leaf = k.poly(outline, size * 0.07, m=m, name="maple")
    bm = k.bmesh.new()
    bm.from_mesh(leaf.data)
    k.bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(leaf.data)
    bm.free()
    if vein is None:
        return [leaf]
    veins = []
    for a, length in lobes:
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        y = Vector((0, -size * 0.04, 0))
        veins.append(k.tube([y - d * size * 0.2, y + d * size * length * 0.45, y + d * size * length * 0.82], [size * 0.025, size * 0.018, size * 0.006], m=vein, n=4, name="vein"))
    veins.append(k.capsule((0, 0, -size * 0.2), (0, 0, -size * 0.75), size * 0.04, size * 0.03, vein, n=8, name="stem"))
    return [leaf, *veins]


def creature_redpanda():
    """HD standard: one fused body with its mask, dark limbs and belly painted after settle; the
    big ringed tail is its own fused shape, so its rings can be measured on it."""
    head, R = Vector((0, -0.2, 3.35)), 1.2
    muzzle = Vector((0, -1.18, 3.02))
    ear = (0.98, -0.05, 4.22)
    tilt = 22
    paw = Vector((0.62, -1.08, 2.1))
    body = k.fuse(
        [
            (head, R, (1.18, 0.95, 0.9)),
            (muzzle, 0.42, (1.25, 0.8, 0.72)),
            ((0, 0.15, 1.75), 1.0, (1.0, 0.95, 1.05)),  # chest
            ((0, 0.2, 0.9), 1.0, (1.12, 1.05, 0.72)),  # round seat
            *k.pair(ear, 0.46, (0.55, 0.28, 1.0), (0, tilt, 0)),  # big pointed-round ears
            *k.pair((0.55, -0.72, 0.2), 0.32, (0.9, 1.45, 0.62)),  # feet
            *[("capsule", (s * 0.88, -0.15, 2.3), (s * paw.x, paw.y, paw.z), 0.22) for s in (-1, 1)],  # arms round the leaf
            *k.pair(paw, 0.23, (0.95, 0.9, 1.0)),
        ],
        k.flat((205, 88, 42)),
        tris=3000,
    )
    path = []  # tail: from under the seat round the right side to the front, thick and bushy
    pts = [Vector(p) for p in ((0.3, 1.0, 0.75), (0.85, 1.75, 0.78), (1.75, 1.6, 0.78), (2.2, 0.7, 0.72), (2.05, -0.35, 0.7), (1.5, -1.15, 0.72), (0.95, -1.55, 0.8))]
    for a, b in zip(pts, pts[1:]):
        for j in range(4):
            path.append(a.lerp(b, j / 4))
    path.append(pts[-1])
    radii = [0.44 + 0.24 * math.sin(math.pi * min(1, 1.15 * i / (len(path) - 1))) - 0.14 * (i / (len(path) - 1)) ** 3 for i in range(len(path))]
    tail = k.fuse([("capsule", a, b, (ra + rb) / 2) for a, b, ra, rb in zip(path, path[1:], radii, radii[1:])], k.flat((205, 88, 42)), tris=1000, name="tail")
    parts = [body, tail]
    cream, rust_in = k.flat((255, 246, 232)), k.flat((120, 42, 30))
    for s in (-1, 1):
        axis = (s * math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt)))
        parts.append(k.lens(body, (s * ear[0], ear[1], ear[2] - 0.05), (0, -1, 0), 0.38, rust_in, scale=(0.4, 0.95), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    # Maple leaf held up in both paws, tilted back; a small one pinned by the left ear.
    leaf = maple_leaf(0.98, k.flat((240, 100, 40)), k.flat((185, 45, 30)))
    for ob in leaf:
        ob.data.transform(Matrix.Translation((0, -1.36, 2.02)) @ Matrix.Rotation(math.radians(-18), 4, "X"))
    pin = maple_leaf(0.32, k.flat((255, 150, 50)))
    p, n = k.land(body, head, k.outward(-50, 44))
    pin[0].data.transform(Matrix.Translation(p + n * 0.03) @ Vector((0, -1, 0)).rotation_difference(n).to_matrix().to_4x4() @ Matrix.Rotation(math.radians(25), 4, "Y"))
    parts += leaf + pin
    parts += k.face(body, head, R, skin=(255, 246, 232))
    rings = []  # buff rings: each a sphere a little wider than the measured tail
    for i in range(3, len(path) - 4, 4):
        r = (k.land(tail, path[i], (0, 0, 1))[0] - path[i]).length
        rings.append((path[i], math.sqrt(r * r + 0.26 ** 2)))

    m = settle(parts, SIZE["creature_redpanda"])
    rust, white, dark = (214, 92, 44), (255, 246, 232), (66, 38, 34)
    swap(body, k.paint("rp_fur", [(0, (150, 58, 30)), (0.45, rust), (1, (236, 120, 58))], 0.3, 4.6, marks=[
        *[mark(m, dark, (s * p[0], p[1], p[2]), r) for s in (-1, 1) for p, r in (((0.55, -0.72, 0.2), 0.48), ((0.8, -0.35, 2.15), 0.3), ((0.7, -0.75, 2.12), 0.3), (paw, 0.3))],
        *[mark(m, white, (s * 0.98, -0.3, 4.25), 0.34) for s in (-1, 1)],  # white ear fronts
        mark(m, white, muzzle + Vector((0, -0.2, -0.1)), 0.5),  # muzzle
        *[mark(m, white, head + Vector((s * 0.85, -0.75, -0.42)), 0.36) for s in (-1, 1)],  # cheeks
        *[mark(m, white, head + Vector((s * 0.48, -0.9, 0.42)), 0.17) for s in (-1, 1)],  # brows
    ]))
    marks = [mark(m, (242, 182, 112), p, r) for p, r in rings]
    marks.append(mark(m, (92, 44, 34), path[-1], 0.55))  # dark tip
    swap(tail, k.paint("rp_tail", [(0, (180, 70, 34)), (1, (222, 98, 46))], 0.2, 1.4, marks=marks))
    lo, hi = k._ground_dims(leaf[:1])
    swap(leaf[0], k.paint("rp_maple", [(0, (215, 50, 40)), (0.5, (250, 115, 40)), (1, (255, 185, 60))], lo.z, hi.z))
    return parts


# Jewel Peacock (mythic, monthly) -------------------------------------------------------------


def creature_peacock():
    """HD standard: one fused bird, a gold beak and feet, a crest of three jewel drops and a fan of
    seven quill feathers, each eye-spot painted after settle as gold, sapphire, teal and a gem
    core with a glint, on both faces."""
    head, R = Vector((0, -0.35, 3.3)), 0.92
    body = k.fuse(
        [
            (head, R, (1.1, 1.0, 0.95)),
            ((0, -0.2, 2.5), 0.55),  # neck
            ((0, 0.1, 1.45), 1.0, (0.95, 1.05, 1.0)),  # egg-shaped body
            ((0, 0.15, 0.72), 0.75, (0.9, 0.95, 0.6)),  # round seat
            *k.pair((0.8, 0.3, 1.6), 0.36, (0.4, 0.95, 1.15), (0, -12, 0)),  # folded wings
            ((0, 0.95, 1.4), 0.45, (0.9, 1.0, 0.9)),  # tail base the fan grows from
        ],
        k.flat((150, 215, 225)),
        tris=2500,
    )
    gold = k.flat((248, 196, 80))
    parts = [body, k.capsule((0, -1.08, 3.06), (0, -1.46, 2.97), 0.14, 0.04, gold, n=12, name="beak")]
    for s in (-1, 1):
        parts.append(k.sphere(0.24, (s * 0.4, -0.5, 0.18), m=gold, scale=(0.9, 1.45, 0.55), seg=20, rings=6, name="foot"))
    # Crest: three gold wires, each topped with a teardrop jewel.
    crest = []
    for dx, h in ((-0.34, 0.62), (0, 0.78), (0.34, 0.62)):
        root, tip = head + Vector((dx * 0.25, 0.05, 0.8)), head + Vector((dx, 0.12, 0.8 + h))
        parts.append(k.tube([root, tip], [0.035, 0.025], m=gold, n=4, name="wire"))
        crest.append(k.capsule(tip - Vector((0, 0, 0.1)), tip + Vector((0, 0, 0.16)), 0.12, 0.03, k.flat((60, 200, 210)), n=10, name="jewel"))
    parts += crest
    # The fan, leaning back 25 degrees behind the body.
    base, lean = Vector((0, 0.95, 1.7)), Matrix.Rotation(math.radians(-25), 4, "X")
    fan, eyes_at = [], []
    for i, (a, length) in enumerate(((-66, 2.45), (-44, 3.05), (-22, 3.45), (0, 3.6), (22, 3.45), (44, 3.05), (66, 2.45))):
        t, length = math.radians(a), length * 1.08
        d, w = Vector((math.sin(t), 0, math.cos(t))), Vector((math.cos(t), 0, -math.sin(t)))
        frame = Matrix.Translation(base + Vector((0, 0.04 * abs(i - 3), 0))) @ lean @ Matrix((d, w, (0, 1, 0))).transposed().to_4x4()
        f = paddle(length, 0.47, k.flat((60, 170, 160)), thick=0.1, n=8, root=0.1, ease=2.2, name="feather")
        f.data.transform(frame)
        fan.append(f)
        eyes_at.append((frame @ Vector((length * 0.76, 0, 0)), frame @ Vector((length * 0.76 + 0.09, 0.07, 0))))
    parts += fan
    parts += k.face(body, head, R, skin=(240, 248, 255), nose=None, mouth_kind=None)

    m = settle(parts, SIZE["creature_peacock"])
    swap(body, k.paint("pc_body", [(0, (40, 140, 165)), (0.35, (80, 190, 210)), (0.62, (220, 240, 250)), (1, (252, 254, 255))], 0.2, 4.6))
    spots = []
    for c, glint in eyes_at:
        spots += [mark(m, (255, 205, 80), c, 0.42), mark(m, (70, 80, 200), c, 0.32), mark(m, (40, 190, 200), c, 0.22),
                  mark(m, (30, 40, 120), c, 0.13), mark(m, (235, 245, 255), glint, 0.045)]
    feather = k.paint("pc_feather", [(0, (25, 120, 95)), (0.5, (45, 170, 140)), (1, (95, 215, 200))], 1.6, 5.6, marks=spots)
    for f in fan:
        swap(f, feather)
    for j in crest:
        lo, hi = k._ground_dims([j])
        swap(j, k.paint(f"pc_jewel_{len(spots)}_{lo.x:.2f}", [(0, (30, 120, 190)), (1, (110, 230, 230))], lo.z, hi.z))
    return parts


# Frost Leopard (divine, monthly) -------------------------------------------------------------


def creature_snowleopard():
    """HD standard: one fused cub and its own fused tail; rosettes are rings painted at points
    found on the real surface (none on the face), frost on the ears and tail tip, and a frost
    snowflake on the forehead."""
    head, R = Vector((0, -0.35, 3.95)), 1.3
    ear = (1.0, -0.12, 4.85)
    tilt = 18
    body = k.fuse(
        [
            (head, R, (1.15, 0.95, 0.9)),
            ((0, -1.28, 3.6), 0.42, (1.3, 0.75, 0.72)),  # small muzzle
            ((0, 0.15, 2.15), 1.22, (1.15, 0.95, 1.05)),  # chubby chest
            ((0, 0.25, 1.05), 1.25, (1.2, 1.05, 0.75)),  # round seat
            *k.pair((1.0, 0.35, 0.9), 0.7, (0.8, 1.0, 0.9)),  # haunches
            *k.pair(ear, 0.42, (0.55, 0.28, 0.85), (0, tilt, 0)),  # round cub ears
            *[("capsule", (s * 0.6, -0.55, 1.7), (s * 0.6, -0.9, 0.38), 0.33) for s in (-1, 1)],  # front legs
            *k.pair((0.6, -1.0, 0.2), 0.34, (0.9, 1.45, 0.62)),  # front paws
            *k.pair((1.08, -0.3, 0.2), 0.3, (0.9, 1.45, 0.62)),  # hind paws
        ],
        k.flat((220, 228, 242)),
        tris=3000,
    )
    path = []  # the huge tail: from the back, round the right side, its tip by the front paws
    pts = [Vector(p) for p in ((0.2, 1.3, 0.62), (1.0, 2.05, 0.66), (2.0, 1.6, 0.68), (2.3, 0.45, 0.68), (1.95, -0.65, 0.7), (1.2, -1.35, 0.8), (0.55, -1.55, 0.95))]
    for a, b in zip(pts, pts[1:]):
        for j in range(4):
            path.append(a.lerp(b, j / 4))
    path.append(pts[-1])
    last = len(path) - 1
    radii = [0.5 + 0.24 * math.sin(math.pi * min(1, 1.1 * i / last)) - 0.1 * (i / last) ** 3 for i in range(len(path))]
    tail = k.fuse([("capsule", a, b, (ra + rb) / 2) for a, b, ra, rb in zip(path, path[1:], radii, radii[1:])], k.flat((220, 228, 242)), tris=1000, name="tail")
    parts = [body, tail]
    for s in (-1, 1):
        axis = (s * math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt)))
        # High on the ear: lower down, a ray from the front meets the head before the ear.
        parts.append(k.lens(body, (s * 1.06, ear[1], 5.05), (0, -1, 0), 0.26, k.flat((235, 190, 205)), scale=(0.45, 0.85), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    # Frost snowflake on the forehead: six arms laid on the surface.
    flake, crown = [], k.outward(0, 34)
    for i in range(6):
        a = math.radians(60 * i)
        arm = []
        for t in (0.0, 0.5, 1.0):
            d = crown + Vector((math.cos(a) * 0.2 * t, 0, math.sin(a) * 0.2 * t))
            p, n = k.land(body, head, d)
            arm.append(p + n * 0.025)
        flake.append(k.tube(arm, [0.05, 0.04, 0.022], m=k.flat((150, 215, 255), emit=0.3), n=6, name="flake"))
    parts += k.texel(flake, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=(240, 244, 252), iris=(28, 36, 72), nose=(240, 150, 170))
    # Rosettes on the body (not the front or the face) and along the tail, measured before settle.
    def fibonacci(count):
        for i in range(count):
            z = 1 - 2 * (i + 0.5) / count
            yield Vector((math.sqrt(1 - z * z) * math.cos(i * 2.39996), math.sqrt(1 - z * z) * math.sin(i * 2.39996), z))

    rings = [k.land(body, (0, 0.25, 1.6), d)[0] for d in fibonacci(52) if d.y > -0.6 and -0.35 < d.z < 0.7]
    dots = [k.land(body, head, d)[0] for d in fibonacci(20) if d.z > 0.35 and d.y > -0.1]  # crown and nape
    tail_rings = []
    for i in range(2, last - 3, 2):
        t = (path[i + 1] - path[i - 1]).normalized()
        for side in (-1, 1):  # mostly from above, so a ray never reaches the other arm of the curl
            out = (t.cross(Vector((0, 0, 1))) * side * 0.6 + Vector((0, 0, 1))).normalized()
            tail_rings.append(k.land(tail, path[i], out)[0])

    m = settle(parts, SIZE["creature_snowleopard"])
    # Slate rosettes with frost-blue hearts, sizes varied so they never read as a pattern.
    rosette, inner, white, frost = (88, 96, 132), (168, 202, 238), (250, 252, 255), (150, 205, 250)

    def ring(p, i, big=0.2):
        r = big * (0.75 + 0.25 * ((i * 7) % 5) / 4)
        return [mark(m, rosette, p, r, r_in=r * 0.55), mark(m, inner, p, r * 0.55)]

    marks = [x for i, p in enumerate(rings) for x in ring(p, i)] + [mark(m, rosette, p, 0.1) for p in dots]
    marks += [mark(m, white, (0, -1.6, 2.1), 1.0), mark(m, white, (0, -1.7, 3.5), 0.62)]  # chest, muzzle over the rosettes
    marks += [mark(m, white, (s * x, y, 0.2), 0.42) for s in (-1, 1) for x, y in ((0.6, -1.0), (1.08, -0.3))]  # white mittens
    marks += [mark(m, frost, (s * 1.12, -0.12, 5.3), 0.3) for s in (-1, 1)]  # frosty ear tips
    fur = [(0, (186, 194, 214)), (0.45, (222, 228, 242)), (1, (242, 246, 253))]
    swap(body, k.paint("sl_fur", fur, 0.2, 5.2, marks=marks, dots=[((255, 255, 255), 14, 0.035)]))
    tail_marks = [x for i, p in enumerate(tail_rings) for x in ring(p, i, 0.19)]
    tail_marks += [mark(m, (214, 234, 255), path[-1], 0.85), mark(m, (178, 216, 252), path[-1], 0.62)]  # frost tip, soft edge
    swap(tail, k.paint("sl_tail", fur, 0.2, 1.8, marks=tail_marks, dots=[((255, 255, 255), 14, 0.035)]))
    return parts


# Weekly Egg ----------------------------------------------------------------------------------


def egg_weekly():
    e = dict(H=2.62, R=1.06)
    sky = (205, 232, 255)
    band = (255, 252, 240)
    # Seven suns and seven moons alternate round the ribbon band; a moon is a cream disc with a
    # band-coloured disc over it, offset round the shell.
    marks = []
    for i in range(14):
        c = k.egg_at(i * 360 / 14, 0.5, **e)[0]
        if i % 2 == 0:
            marks += [((255, 180, 70), c, 0, 0.13), ((255, 222, 90), c, 0, 0.1)]
        else:
            marks += [((255, 228, 150), c, 0, 0.1), (band, k.egg_at(i * 360 / 14 + 4.2, 0.5, **e)[0], 0, 0.1)]
    shell = k.paint(
        "wk_shell",
        [(0, sky), (0.405, (215, 238, 255)), (0.41, band), (0.58, band), (0.585, (215, 238, 255)), (1, (228, 244, 255))],
        0,
        2.62,
        marks=marks,
    )
    gold = k.paint("wk_gold", [(0, k.GOLD_MID), (1, k.GOLD_HI)], 2.3, 3.2, emit=0.08)
    trim = k.flat((255, 240, 200))

    parts = [k.shell(shell, nu=30, nv=13, **e)]
    for v in (0.4, 0.595):
        parts.append(k.ridge([(i * 30, v) for i in range(13)], 0.03, 0.03, trim, **e))
    # Gold bow on top: two loops, a knot, two ribbon tails trailing down the front.
    for s in (1, -1):
        parts.append(blob(0.34, (s * 0.4, 0, 2.78), gold, scale=(1.3, 0.55, 0.75), rot=(0, s * -22, 0), seg=10, rings=6, name="loop"))
        parts.append(k.ridge([(s * 10, 0.98), (s * 14, 0.92), (s * 9, 0.86), (s * 13, 0.8), (s * 10, 0.74)], [0.07, 0.07, 0.065, 0.06, 0.02], 0.03, gold, **e))
    parts.append(k.sphere(0.17, (0, 0, 2.72), m=gold, seg=10, rings=6, name="knot"))
    for theta, v in ((-50, 0.7), (130, 0.72), (40, 0.28), (220, 0.3)):
        parts.append(k.stick(k.star(0.11, gold), theta, v, 0.01, spin=theta, **e))
    return parts


# Monthly Egg ---------------------------------------------------------------------------------


def egg_monthly():
    e = dict(H=2.62, R=1.06)
    teal = (18, 92, 98)
    navy = (12, 56, 70)
    bright = (255, 226, 140)
    # Eight moon phases round the middle, full at the front: a gold disc with a navy disc shifted
    # across it; new is covered and keeps its gold outline.
    marks = []
    for i, cover in enumerate((None, 6.5, 4.0, 1.8, 0.0, -1.8, -4.0, -6.5)):
        theta = i * 45
        c = k.egg_at(theta, 0.5, **e)[0]
        marks += [((235, 190, 90), c, 0, 0.16), (bright, c, 0, 0.13)]
        if cover is not None:
            marks.append((navy, k.egg_at(theta + cover, 0.5, **e)[0], 0, 0.13))
    shell = k.paint(
        "mn_shell",
        [(0, teal), (0.405, (24, 118, 120)), (0.41, navy), (0.59, navy), (0.595, (24, 118, 120)), (1, (36, 140, 136))],
        0,
        2.62,
        # Lace bands either side of the moon ring; tiny gold specks over the dome.
        splat=[((225, 180, 90), 6, 0.78, 0.6, 0.9, "swirl"), ((225, 180, 90), 6, 0.78, 1.72, 2.0, "swirl")],
        marks=marks,
        dots=[((235, 200, 110), 7, 0.05)],
    )
    gold = k.paint("mn_gold", [(0, (240, 180, 70)), (1, (255, 230, 150))], 0, 3.4, emit=0.08)
    light = k.glow(bright)

    parts = [k.shell(shell, nu=32, nv=13, **e)]
    for v in (0.4, 0.6):
        parts.append(k.ridge([(i * 30, v) for i in range(13)], 0.04, 0.04, gold, **e))
    for i in range(4):
        theta = i * 90 + 45
        parts.append(k.ridge([(theta, 0.64 + 0.3 * j / 3) for j in range(4)], [0.05, 0.04, 0.03, 0.012], 0.035, gold, **e))
        parts.append(k.stick(k.star(0.12, light, points=4, inner=0.3), theta - 45, 0.8, 0.015, **e))
    parts.append(k.lathe([(0.6, 0.0), (0.62, 0.08), (0.46, 0.14), (0, 0.2)], m=gold, n=14, name="foot"))
    # Crescent finial on a short gold stub.
    top = 2.62
    parts.append(k.lathe([(0.2, top - 0.08), (0.14, top + 0.08), (0.06, top + 0.2)], m=gold, n=8, name="stub"))
    centre = Vector((0, 0, top + 0.42))
    pts, radii = [], []
    for i in range(9):
        s = i / 8 * 2 - 1
        a = s * math.radians(120)
        pts.append(centre + Vector((math.sin(a) * 0.26, 0, -math.cos(a) * 0.26)))
        radii.append(0.02 + 0.08 * math.cos(s * math.pi / 2))
    parts.append(k.tube(pts, radii, m=light, n=8, name="crescent"))
    return parts


NOTES = "One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are."
EGG_NOTES = "One mesh for Plots.egg through Models.nightPart (architecture section 9); never on the cart. Gold is baked bright."
SPECIES = (
    ("creature_puffin", creature_puffin, [2.6, 3.0, 2.6], "Pebble Puffin (uncommon)"),
    ("creature_otter", creature_otter, [4.0, 2.6, 5.8], "River Otter (rare)"),  # lies on its back: 9.3's 3.6 tall would be 7 long
    ("creature_capybara", creature_capybara, [3.2, 4.2, 4.6], "Spa Capybara (epic)"),
    ("creature_redpanda", creature_redpanda, [4.2, 5.0, 4.0], "Maple Red Panda (legendary)"),
    ("creature_peacock", creature_peacock, [5.0, 5.6, 4.0], "Jewel Peacock (mythic)"),
    ("creature_snowleopard", creature_snowleopard, [4.6, 5.8, 4.6], "Frost Leopard (divine)"),
)
SIZE = {name: size for name, _, size, _ in SPECIES}
ASSETS = [
    dict(name=name, build=build, budget=k.CREATURE_BUDGET, finalize=k.HD, size=size, priority=1,
         order=40 + i, replaces="none (new species, login rewards)", notes=f"{label}. {NOTES}", glow={})
    for i, (name, build, size, label) in enumerate(SPECIES)
] + [
    dict(name="egg_weekly", build=fit(egg_weekly), budget=2500, size=[2.2, 3, 2.2], priority=1, order=46, replaces="Plots.egg weekly (part fallback)", notes=f"Weekly Egg. {EGG_NOTES}"),
    dict(name="egg_monthly", build=fit(egg_monthly), budget=3000, size=[2.2, 3, 2.2], priority=1, order=47, replaces="Plots.egg monthly (part fallback)", notes=f"Monthly Egg. {EGG_NOTES}"),
]
