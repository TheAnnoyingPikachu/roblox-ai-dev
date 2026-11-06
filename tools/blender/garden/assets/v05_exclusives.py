"""v0.5 exclusives (GARDEN-054, GDD X3.4, architecture 9.3): the six login-reward species and the
Weekly and Monthly Eggs. The species follow the README "Creature standard" (HD pass), richer than
the common creatures as earned rewards; one mesh each, facing Blender -Y."""

import math
import os
import sys

import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creatures_a import capsules, spline, xf  # noqa: E402
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
    tris = sum(k._tris(ob) for ob in parts)  # over k.CREATURE_BUDGET, finalize silently decimates
    print(f"[v05] fit scale x {s[0]:.2f} y {s[1]:.2f} z {s[2]:.2f}, {tris} tris", flush=True)
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
    """Remade from the Roblox AI reference (assets/garden/refs/puffin_*.jpg): a knitted-toy black
    puffin, a huge round head over a small body, a white face mask round both eyes, a white belly,
    a big orange bill with pale stripes, a tuft on top, and a grey pebble hugged to the chest under
    the left flipper (the "Pebble Puffin")."""
    fur = k.paint("pf_body", [(0, (10, 10, 14)), (0.5, (22, 22, 28)), (1, (40, 40, 48))], 0, 3.0, rest=True)
    white = (244, 242, 246)
    head, R = Vector((0, 0, 1.98)), 1.02
    body = k.fuse(
        [
            (head, R, (1.1, 0.98, 0.95)),
            ((0, 0.05, 0.7), 0.7, (1.02, 0.98, 0.98)),  # small bell-shaped body
            ((-0.66, 0.05, 0.78), 0.34, (0.32, 0.62, 1.1), (0, -12, 0)),  # right flipper at the side
            ((0.45, -0.4, 0.88), 0.34, (0.35, 0.95, 0.6), (0, 0, -42)),  # left flipper, round the pebble
            ("capsule", (0, 0.05, 2.85), (0.04, 0.12, 3.05), 0.05),  # tuft
        ],
        fur,
        tris=2900,
    )
    for side in (-1, 1):  # white mask round each eye, black between them
        k.zone(fur, white, head + k.outward(side * 36, -14) * R * 0.95, (0.44, 0.42, 0.54), soft=0.06)
    k.zone(fur, white, (0, -0.62, 0.66), (0.44, 0.45, 0.56), soft=0.06)  # belly
    parts = [body]
    p, n = k.land(body, head, k.outward(0, -14))
    upper = k.sphere(0.42, p + n * 0.12, rot=(-10, 0, 0), m=k.flat((246, 120, 56)), scale=(1.15, 0.8, 0.42), seg=28, rings=14, name="bill")
    lower = k.sphere(0.34, p + n * 0.07 - Vector((0, 0, 0.13)), rot=(-10, 0, 0), m=k.flat((224, 98, 44)), scale=(1.05, 0.75, 0.32), seg=24, rings=12, name="bill_lo")
    stripes = [k.lens(upper, p + n * 0.12, (s * 0.2, -0.5, 1), 0.24, k.flat((252, 222, 196)), scale=(0.1, 1), thick=0.25, sink=0.5, seg=12, up=(0, -1, 0), name="stripe") for s in (-1, 1)]
    parts += k.texel([upper, lower, *stripes], k.FACE_TEXEL)
    parts.append(k.sphere(0.24, (0.18, -0.72, 0.9), rot=(0, 0, 20), m=k.flat((150, 152, 160)), scale=(1.0, 0.6, 1.15), seg=24, rings=12, name="pebble"))
    parts += k.face(body, head, R, skin=white, nose=None, mouth_kind=None, eye_r=0.22, eye_wide=0.9, spread=34, eye_phi=-6, sheen=True, blush_theta=48, blush_phi=-24)
    settle(parts, SIZE["creature_puffin"])
    return parts


# River Otter (rare, weekly) ------------------------------------------------------------------


def creature_otter():
    """Remade from the Roblox AI reference (assets/garden/refs/otter_*.jpg): a chocolate-brown
    otter sitting up, a cream muzzle, cheeks and belly, a black button nose, small dark eyes, small
    round ears, a flat paddle tail on the ground, and a blue spiral shell hugged in both paws."""
    fur = k.paint("ot_fur", [(0, (78, 42, 24)), (0.5, (110, 62, 36)), (1, (134, 82, 50))], 0, 3.4, rest=True, grain=(0.06, 30))
    cream = (238, 222, 192)
    head, R = Vector((0, -0.1, 2.45)), 0.85
    muzzle = Vector((0, -0.78, 2.2))
    paw = Vector((0.5, -0.92, 1.2))
    tail = spline([(0.3, 0.75, 0.2), (0.6, 1.12, 0.1), (0.85, 1.38, 0.07)], [0.3, 0.26, 0.16], 8)
    body = k.fuse(
        [
            (head, R, (1.3, 1.02, 0.95)),
            *k.pair((0.3, -0.66, 2.16), 0.38, (1.0, 0.85, 0.82)),  # puffy muzzle cheeks
            ((0, 0.08, 1.3), 0.86, (1.14, 1.0, 1.12)),  # pear body
            ((0, 0.1, 0.5), 0.9, (1.32, 1.12, 0.6)),  # round seat
            *k.pair((0.9, -0.02, 2.86), 0.19, (1.0, 0.6, 0.9)),  # small round ears
            ("capsule", (0.8, -0.2, 1.75), (paw.x, paw.y, paw.z), 0.21),  # arms round the shell
            ("capsule", (-0.8, -0.2, 1.75), (-paw.x, paw.y, paw.z), 0.21),
            *k.pair(tuple(paw), 0.2, (1.0, 1.0, 0.9)),
            *k.pair((0.55, -0.74, 0.15), 0.25, (1.0, 1.4, 0.6)),  # hind feet
            *[e for (a, ra), (b, rb) in zip(tail, tail[1:]) for e in [(tuple((a + b) / 2), (ra + rb) / 2, (1.0, 1.0, 0.4), (0, 0, -35))]],  # flat paddle tail
        ],
        fur,
        tris=2900,
    )
    k.zone(fur, cream, muzzle + Vector((0, 0.05, 0.02)), (0.84, 0.5, 0.44), soft=0.15)  # muzzle and cheeks
    k.zone(fur, cream, (0, -0.76, 1.05), (0.66, 0.45, 0.82), soft=0.15)  # belly
    k.zone(fur, (150, 108, 82), tail[-1][0], (0.5, 0.5, 0.4), soft=0.4)  # paler tail tip
    parts = [body]
    # The blue spiral shell, held upright on the belly: concentric grooves painted round its middle.
    c, d = Vector((0, -1.0, 1.25)), Vector((0, -1, 0.25)).normalized()
    shell = k.rest(k.lathe([(0, -0.12), (0.42, -0.12), (0.55, -0.05), (0.57, 0.05), (0.5, 0.13), (0.3, 0.2), (0, 0.22)], m=None, n=32, name="shell"))
    shell.data.materials.append(k.paint("ot_shell", [(0, (22, 96, 204)), (1, (48, 136, 234))], -0.12, 0.22, rest=True,
                                        marks=[((26, 84, 184), (0, 0, 0.22), r - 0.025, r) for r in (0.1, 0.24, 0.38, 0.5)]))
    shell.data.transform(Matrix.Translation(c) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
    parts.append(shell)
    face = [k.lens(body, muzzle, k.outward(0, 30), 0.18, k.flat((26, 22, 26)), scale=(1.35, 0.95), thick=0.8, sink=0.4, seg=16, name="nose"),
            k.mouth(body, muzzle, k.outward(0, -14), 0.16, k.flat(k.INKY), "w")]
    parts += k.texel(face, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=(120, 82, 62), nose=None, mouth_kind=None, eye_r=0.18, eye_wide=0.9, spread=33, eye_phi=6, sheen=True, blush_theta=50, blush_phi=-22, blush_r=0.13)
    settle(parts, SIZE["creature_otter"])
    return parts


# Spa Capybara (epic, weekly) -----------------------------------------------------------------


def creature_capybara():
    """Remade from the Roblox AI reference (assets/garden/refs/capybara_*.jpg): a golden-tan
    capybara loaf, the head melting into the body, a long blunt darker muzzle, small dark eyes,
    pink cheeks, small round ears, a mandarin with a leaf and a sprig of lilac on its head, and a
    rolled white towel tucked under its left arm (the "Spa Capybara")."""
    tan = (210, 146, 80)
    fur = k.paint("ca_fur", [(0, (166, 104, 52)), (0.45, tan), (1, (226, 170, 104))], 0, 2.6, rest=True, grain=(0.06, 30))
    head, R = Vector((0, -0.38, 1.85)), 0.85
    snout = Vector((0, -1.1, 1.6))
    ear = (0.66, -0.05, 2.5)
    body = k.fuse(
        [
            (head, R, (1.1, 1.12, 0.9)),
            (snout, 0.44, (0.95, 1.0, 1.08)),  # long blunt muzzle
            ((0, 0.25, 0.9), 0.95, (1.12, 1.15, 0.95)),  # loaf body
            ((0, 0.25, 0.42), 0.95, (1.16, 1.18, 0.5)),  # flat round seat
            *k.pair(ear, 0.2, (1.0, 0.55, 0.9), (0, 20, 0)),  # small round ears
        ],
        fur,
        tris=2800,
    )
    k.zone(fur, (140, 86, 56), snout + Vector((0, -0.24, -0.04)), (0.38, 0.34, 0.5), soft=0.12)  # darker muzzle
    k.zone(fur, (232, 190, 132), (0, -0.85, 0.75), (0.6, 0.4, 0.55), soft=0.4)  # paler chest
    parts = [body]
    for s in (-1, 1):
        axis = (s * math.sin(math.radians(20)), 0, math.cos(math.radians(20)))
        parts.append(k.lens(body, (s * ear[0], ear[1], ear[2]), (0, -1, 0), 0.14, k.flat((150, 96, 74)), scale=(0.7, 0.8), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    ink = k.flat((60, 36, 30))
    face = [k.lens(body, snout, k.outward(s * 18, 8), 0.05, ink, scale=(0.8, 1.3), thick=0.5, sink=0.5, seg=12, name="nostril") for s in (-1, 1)]
    face.append(k.mouth(body, snout, k.outward(0, -26), 0.14, ink, "w"))
    parts += k.texel(face, k.FACE_TEXEL)
    # Rolled towel under the left arm (+X), its end pointing forwards and out.
    towel = k.capsule((0.8, 0.2, 1.0), (1.12, -0.82, 1.02), 0.25, 0.25, k.flat((248, 248, 244)), n=20, name="towel")
    swirl = k.lens(towel, (1.12, -0.82, 1.02), (0.3, -0.95, 0), 0.15, k.flat((214, 216, 214)), thick=0.2, sink=0.6, seg=12, name="towel_end")
    parts += [towel, swirl]
    # Mandarin on top, with a stem, a leaf and a lilac sprig behind it.
    p, n = k.land(body, head, (0, 0.25, 1))
    top = p + Vector((0, 0, 0.3))
    orange = k.rest(k.blob(0.36, top, None, scale=(1, 1, 0.88), name="mandarin"))
    orange.data.materials.append(k.paint("ca_mandarin", [(0, (228, 108, 40)), (1, (248, 150, 70))], top.z - 0.3, top.z + 0.3, rest=True, grain=(0.08, 40)))
    stem = k.capsule(top + Vector((0, 0, 0.28)), top + Vector((0.02, 0.02, 0.38)), 0.035, 0.03, k.flat((92, 70, 48)), n=8, name="stem")
    leaves = xf(k.leaf(0.36, 0.14, k.flat((105, 175, 85)), droop=0.25, n=8, steps=8), top + Vector((0.02, 0.02, 0.36)), yaw=-30, pitch=12)
    lilac = [k.flat((196, 160, 226)), k.flat((222, 186, 236))]
    sprig = [ob for i, yaw in enumerate((60, 90, 120, 75, 105)) for ob in xf(k.leaf(0.54 - 0.08 * (i // 3), 0.15, lilac[i % 2], droop=-0.1, n=8, steps=8), top + Vector((0, 0.24, -0.05)), yaw=yaw, pitch=58 - 14 * (i // 3))]
    parts += [orange, stem, *leaves, *sprig]
    parts += k.face(body, head, R, skin=(220, 166, 104), nose=None, mouth_kind=None, eye_r=0.15, eye_wide=0.9, spread=40, eye_phi=10, sheen=True, blush_theta=52, blush_phi=-12, blush_r=0.16)
    settle(parts, SIZE["creature_capybara"])
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
    """Remade from the Roblox AI reference (assets/garden/refs/redpanda_*.jpg): an orange red panda
    cub sitting low with its front legs stretched out on the ground, a huge head, big white-rimmed
    ears, white cheek patches, brow dots and muzzle, a black nose, dark red tear marks under the
    eyes, dark maroon legs and paws with pale soles, a bushy ringed tail lying out behind on its
    right, and a red maple leaf standing on its head (the "Maple Red Panda")."""
    orange = (226, 108, 48)
    white, maroon, tear = (252, 246, 238), (88, 36, 36), (176, 40, 36)
    fur = k.paint("rp_fur", [(0, (170, 64, 34)), (0.4, orange), (1, (240, 136, 62))], 0, 3.2, rest=True, grain=(0.05, 30))
    head, R = Vector((0, -0.32, 1.86)), 1.04
    muzzle = Vector((0, -1.2, 1.58))
    ear, tilt = Vector((0.98, -0.2, 2.52)), 36
    paw = Vector((0.5, -1.02, 0.14))
    hind = Vector((0.66, 0.62, 0.3))
    path = spline([(-0.25, 0.9, 0.44), (-0.5, 1.4, 0.46), (-0.86, 1.7, 0.44), (-1.24, 1.76, 0.44)], [0.38, 0.46, 0.46, 0.4], 12)
    body = k.fuse(
        [
            (head, R, (1.26, 0.95, 0.88)),
            *k.pair((0.6, -0.62, 1.58), 0.46, (1.0, 0.85, 0.8)),  # full cheeks
            (muzzle, 0.27, (1.25, 0.9, 0.8)),
            *k.pair(tuple(ear), 0.5, (0.64, 0.32, 1.0), (0, tilt, 0)),  # big ears up and out
            ((0, -0.15, 0.86), 0.62, (1.08, 0.98, 0.92)),  # chest
            ((0, 0.28, 0.5), 0.8, (1.15, 1.2, 0.66)),  # low seat
            ("capsule", (0.4, -0.5, 0.6), (paw.x, paw.y + 0.08, paw.z + 0.06), 0.24),  # short front legs, paws forward
            ("capsule", (-0.4, -0.5, 0.6), (-paw.x, paw.y + 0.08, paw.z + 0.06), 0.24),
            *k.pair(tuple(paw), 0.26, (1.0, 1.25, 0.6)),
            *k.pair(tuple(hind), 0.38, (0.95, 1.05, 0.95)),  # big hind feet, soles back
            *capsules(path),
        ],
        fur,
        tris=3300,
    )
    soft = dict(soft=0.15)
    for s in (-1, 1):
        k.zone(fur, maroon, (s * 0.48, -0.86, 0.26), (0.36, 0.44, 0.36), **soft)  # front legs and paws
        k.zone(fur, maroon, (s * hind.x, hind.y, hind.z), (0.42, 0.4, 0.38), **soft)  # hind feet
        k.zone(fur, (240, 220, 196), (s * hind.x, hind.y + 0.3, hind.z), (0.28, 0.12, 0.28), soft=0.3)  # pale soles
        k.zone(fur, (40, 26, 28), (s * ear.x, ear.y + 0.14, ear.z), (0.48, 0.2, 0.56), soft=0.2)  # dark ear backs
        k.zone(fur, white, (s * ear.x, ear.y - 0.14, ear.z), (0.5, 0.17, 0.58), soft=0.2)  # white ear fronts
        for theta, phi, r, rgb in ((54, -16, (0.34, 0.34, 0.3), white), (20, 30, (0.09, 0.09, 0.09), white), (24, -24, (0.2, 0.2, 0.2), tear), (14, -34, (0.14, 0.14, 0.12), tear)):
            p, _ = k.land(body, head, k.outward(s * theta, phi))
            k.zone(fur, rgb, p, r, soft=0.25)  # cheek patch, brow dot, tear mark
    k.zone(fur, white, muzzle + Vector((0, -0.08, -0.02)), (0.36, 0.26, 0.24), soft=0.2)  # white muzzle
    for i in range(4, len(path) - 2, 3):  # dark rings round the tail
        q, r = path[i]
        rr = math.sqrt(r * r * 1.4 + 0.1 ** 2)
        k.zone(fur, (120, 44, 34), q, (rr, rr, rr), soft=0.08)
    k.zone(fur, (238, 196, 150), path[-1][0] + Vector((-0.12, -0.04, 0)), (0.3, 0.3, 0.4), soft=0.2)  # pale tip
    parts = [body]
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    for s in (-1, 1):
        parts.append(k.lens(body, Vector((s * ear.x, ear.y, ear.z)) + Vector((s * axis.x, 0, axis.z)) * 0.12, (0, -1, 0), 0.4, k.flat((132, 76, 62)), scale=(0.4, 0.9), thick=0.2, sink=0.6, up=(s * axis.x, 0, axis.z), name="ear_in"))
    face = [k.lens(body, muzzle, k.outward(0, 24), 0.11, k.flat((26, 22, 26)), scale=(1.35, 0.95), thick=0.7, sink=0.4, seg=16, name="nose"),
            k.mouth(body, muzzle, k.outward(0, -18), 0.11, k.flat(k.INKY), "w")]
    parts += k.texel(face, k.FACE_TEXEL)
    # Maple leaf standing up on the crown.
    leaf = maple_leaf(0.62, k.flat((236, 84, 44)))
    p, _ = k.land(body, head, (0, 0.1, 1))
    for ob in leaf:
        ob.data.transform(Matrix.Translation(p + Vector((0, 0, 0.24))) @ Matrix.Rotation(math.radians(-12), 4, "X"))
    parts.append(k.capsule(p - Vector((0, 0, 0.05)), p + Vector((0, 0, 0.1)), 0.045, 0.04, k.flat((140, 54, 36)), n=8, name="stem"))
    parts += leaf
    parts += k.face(body, head, R, skin=white, iris=(56, 30, 24), nose=None, mouth_kind=None, eye_r=0.24, eye_wide=0.9, spread=29, eye_phi=-4, sheen=True, blush_theta=46, blush_phi=-26, blush_r=0.13)
    settle(parts, SIZE["creature_redpanda"])
    lo, hi = k._ground_dims(leaf)
    swap(leaf[0], k.paint("rp_maple", [(0, (196, 44, 34)), (0.5, (236, 84, 44)), (1, (250, 132, 60))], lo.z, hi.z))
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
    ("creature_puffin", creature_puffin, [2.2, 3.0, 2.35], "Pebble Puffin (uncommon)"),
    ("creature_otter", creature_otter, [1.89, 2.6, 2.19], "River Otter (rare)"),
    ("creature_capybara", creature_capybara, [3.03, 4.2, 3.56], "Spa Capybara (epic)"),
    ("creature_redpanda", creature_redpanda, [4.11, 5.0, 5.01], "Maple Red Panda (legendary)"),
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
