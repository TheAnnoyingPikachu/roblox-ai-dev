"""The nine Egg Garden creatures as chibi toys, all to the HD standard (tools/blender/garden/README.md
"Creature standard"): one fused body, the kit face, smooth separate props, one theme prop each.
One mesh per creature, standing on the origin, facing Blender -Y. Replaces the Roblox-generated
meshes in src/relay/Models.luau MESHES."""

import math

import kit as k
from mathutils import Matrix, Vector

WHITE = k.SNOW


# Helpers --------------------------------------------------------------------------------------


def xf(obs, loc=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0, mirror=False):
    """Moves parts built at the origin along +X: roll about X, pitch (the +X tip rises), yaw about
    Z, then to loc. mirror flips the result through x = 0 (loc included)."""
    m = Matrix.Translation(Vector(loc)) @ k.rot_z(yaw) @ Matrix.Rotation(math.radians(-pitch), 4, "Y") @ Matrix.Rotation(math.radians(roll), 4, "X")
    if mirror:
        m = Matrix.Diagonal((-1, 1, 1, 1)) @ m
    obs = obs if isinstance(obs, (list, tuple)) else [obs]
    for ob in obs:
        ob.data.transform(m)
    return obs


def petal(length, width, m, droop=0.15, tip=0.5, base=0.55, n=10, steps=12, flat=0.28, name="petal"):
    """A smooth petal, wing or leaf along +X, flat face up: narrow root, widest past the middle.
    tip 0.5 ends round, 1.0 pointed. Rings bunch towards both ends (cosine spacing), so the
    outline stays smooth where it turns fastest."""
    pts, radii = [], []
    for i in range(steps + 1):
        s = (1 - math.cos(math.pi * i / steps)) / 2
        pts.append((length * s, 0, length * droop * math.sin(s * math.pi * 0.8)))
        radii.append(width * math.sin(math.pi * s) ** tip * (base + (1 - base) * s))
    ob = k.tube(pts, radii, m=m, n=n, name=name)
    ob.data.transform(Matrix.Diagonal((1, 1, flat, 1)))
    return ob


def spline(points, radii, steps):
    """steps + 1 (point, radius) samples on a Catmull-Rom curve through points."""
    p = [Vector(q) for q in points]
    p = [2 * p[0] - p[1]] + p + [2 * p[-1] - p[-2]]
    spans = len(points) - 1
    out = []
    for i in range(steps + 1):
        t = i / steps * spans
        j = min(int(t), spans - 1)
        u = t - j
        a, b, c, d = p[j : j + 4]
        q = 0.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (3 * b - a - 3 * c + d) * u ** 3)
        out.append((q, radii[j] + (radii[j + 1] - radii[j]) * u))
    return out


def capsules(samples):
    """Fuse elements along spline samples: short capsules, so a thin end never turns into beads."""
    return [("capsule", a, b, (ra + rb) / 2) for (a, ra), (b, rb) in zip(samples, samples[1:])]


def band(target, x, y, z0, z1, m, nu=56, nv=3, lift=0.02, name="band"):
    """A stripe all round `target` between heights z0 and z1, cast onto its real surface by rays
    towards the vertical axis through (x, y): the inner rows stand `lift` proud, the edge rows dip
    just under the skin, so it never floats and shows nearly its full width."""

    def fn(u, v):
        p, n = k.land(target, (x, y, z0 + (z1 - z0) * v), k.outward(360 * u, 0))
        return p + n * (lift if 0 < v < 1 else -0.006)

    return k.surface(nu, nv, fn, m=m, name=name)


def snout_face(body, snout, muzzle_rgb, nose_rgb, nose_r=0.11, mouth_w=0.22, muzzle_r=0.4, muzzle_scale=(1.2, 0.85)):
    """Snouted species: a pale muzzle cap set into the snout, the nose on its top front and the
    smile under it (README: nose=None, mouth_kind=None in face, then these)."""
    muzzle = k.lens(body, snout, k.outward(0, -6), muzzle_r, k.flat(muzzle_rgb), scale=muzzle_scale, thick=0.8, sink=0.55, seg=20, name="muzzle")
    nose = k.lens(muzzle, snout, k.outward(0, 20), nose_r, k.flat(nose_rgb), scale=(1.4, 0.95), thick=0.6, sink=0.4, seg=16, name="nose")
    mouth = k.mouth(muzzle, snout, k.outward(0, -26), mouth_w, k.flat(k.INKY), "smile")
    return k.texel([muzzle, nose, mouth], k.FACE_TEXEL)


def fit(target):
    """Scales the finished creature to its target [x, height, depth] studs (Roblox order)."""

    def wrap(build):
        def built():
            parts = build()
            lo, hi = k._ground_dims(parts)
            d = hi - lo
            s = (target[0] / d.x, target[2] / d.y, target[1] / d.z)
            print(f"[creatures_a] {build.__name__} fit scale x {s[0]:.2f} y {s[1]:.2f} z {s[2]:.2f}", flush=True)
            for ob in parts:
                ob.data.transform(Matrix.Diagonal((*s, 1)))
            return parts

        return built

    return wrap


# Creatures ------------------------------------------------------------------------------------


def creature_bunny():
    """Remade from the Roblox AI reference (assets/garden/refs/bunny_*.jpg): a wide mochi head
    over half the height, a small pear body, tall paddle ears, a two-leaf sprout, a green
    scalloped collar and green-tinted cream fur."""
    fur = k.paint("bu_fur", [(0, (218, 210, 156)), (0.35, (238, 232, 188)), (1, (252, 246, 216))], 0, 3.0, rest=True)
    pink, cream = k.flat((246, 178, 170)), k.flat((250, 248, 232))
    greens = [k.flat((168, 222, 150)), k.flat((140, 206, 128))]
    sprout = k.flat((120, 200, 96))
    head, R = Vector((0, 0, 2.02)), 1.0
    ear = (0.5, 0.08, 3.42)
    tilt = 14
    body = k.fuse(
        [
            (head, R, (1.08, 0.88, 0.9)),
            *k.pair((0.56, -0.2, 1.74), 0.5, (1.0, 0.85, 0.8)),  # full cheeks: the head is widest low down
            ((0, 0.02, 0.62), 0.6, (1.05, 0.98, 1.05)),  # pear body
            ((0, 0.02, 1.02), 0.42),  # neck fill
            *k.pair(ear, 0.7, (0.55, 0.38, 1.0), (0, tilt, 0)),  # tall paddle ears
            *k.pair((0.6, -0.04, 0.78), 0.19, (0.85, 0.85, 1.35), (0, -24, 0)),  # stubby arms
            *k.pair((0.27, -0.3, 0.12), 0.2, (0.95, 1.3, 0.6)),  # little feet
        ],
        fur,
        tris=3300,
    )
    for side in (-1, 1):  # green-tinted sleeves under the collar, as on the reference
        k.zone(fur, (196, 228, 176), (side * 0.62, -0.04, 0.98), (0.32, 0.34, 0.3), soft=0.35)
    parts = [body, k.blob(0.2, (0, 0.6, 0.5), cream, name="tail")]
    for side in (-1, 1):
        axis = (side * math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt)))
        parts.append(k.lens(body, (side * ear[0], ear[1], ear[2] + 0.02), (0, -1, 0), 0.46, pink, scale=(0.42, 1), thick=0.2, sink=0.6, up=axis, name="ear_in"))
    # Scalloped collar: round petals lying on the shoulders all round the neck.
    for i in range(10):
        yaw = i * 36 + 18
        a = math.radians(yaw)
        parts += xf(petal(0.5, 0.27, greens[i % 2], droop=0.1, tip=0.5, base=0.6, n=8, steps=8), (0.3 * math.cos(a), 0.02 + 0.27 * math.sin(a), 1.2), yaw=yaw, pitch=-50)
    parts.append(k.capsule((0, -0.25, 2.8), (0, -0.3, 3.48), 0.045, 0.04, sprout, n=10, name="stem"))
    for yaw in (0, 180):
        parts += xf(petal(0.5, 0.27, greens[1], droop=0.15, tip=0.5, base=0.45, n=10, steps=10), (0, -0.3, 3.46), yaw=yaw, pitch=10, roll=90)
    parts += k.face(body, head, R, skin=(244, 240, 214), nose=(236, 140, 150), eye_r=0.24, eye_wide=0.9, spread=29, eye_phi=-12, nose_phi=-15, mouth_phi=-21, mouth_w=0.12, nose_r=0.06, sheen=True, blush_theta=46, blush_phi=-24)
    return parts


def creature_frog():
    """The eyes sit on two bumps fused onto the top of the head (the frog look)."""
    skin = k.paint("fr_skin", [(0, (112, 192, 128)), (0.5, (148, 218, 150)), (1, (172, 234, 166))], 0, 3.0)
    cap = k.paint("fr_cap", [(0, (214, 56, 70)), (1, (246, 92, 96))], 2.4, 3.4)
    belly, spot, ink = k.flat((228, 246, 206)), k.flat((255, 250, 240)), k.flat(k.INKY)
    head, R = Vector((0, -0.2, 1.75)), 1.05
    bumps = [Vector((side * 0.62, -0.68, 2.42)) for side in (-1, 1)]
    body = k.fuse(
        [
            (head, R, (1.32, 1.0, 0.82)),
            ((0, 0.25, 0.82), 1.05, (1.2, 1.15, 0.78)),  # round seat
            *[(b, 0.47) for b in bumps],
            *k.pair((1.02, 0.3, 0.52), 0.5, (0.75, 1.25, 0.72)),  # folded back legs
            *k.pair((1.18, -0.45, 0.14), 0.3, (0.9, 1.5, 0.55), (0, 0, -18)),  # back feet
            ("capsule", (0.58, -0.55, 0.68), (0.62, -0.86, 0.24), 0.21),  # front legs
            ("capsule", (-0.58, -0.55, 0.68), (-0.62, -0.86, 0.24), 0.21),
            *k.pair((0.64, -0.98, 0.15), 0.27, (0.9, 1.4, 0.6)),  # front paws
        ],
        skin,
        tris=3200,
    )
    parts = [body]
    cap_ob = k.lathe(
        [(0, -0.02), (0.6, 0.0), (0.98, 0.05), (1.06, 0.13), (1.05, 0.25), (0.96, 0.4), (0.78, 0.57), (0.53, 0.7), (0.27, 0.78), (0, 0.81)],
        loc=(0, 0.5, 2.36),
        rot=(-22, 5, 0),
        m=cap,
        n=32,
        scale=(0.9, 0.9, 0.95),
        name="cap",
    )
    parts.append(cap_ob)
    top = Vector((0, 0.5, 2.46))
    for d, r in [((0, 0, 1), 0.17)] + [(k.outward(a, 38), 0.15) for a in range(-150, 210, 72)] + [(k.outward(a, 12), 0.12) for a in range(-114, 246, 72)]:
        parts.append(k.lens(cap_ob, top, d, r, spot, thick=0.3, sink=0.5, seg=12, name="spot"))
    parts.append(k.lens(body, (0, 0.25, 0.6), (0, -1, 0), 0.62, belly, scale=(1.15, 0.8), thick=0.2, sink=0.6, name="belly"))
    # Face by hand: the eyes look out from the bumps, not from the head sphere.
    k.texel(body, k.FACE_TEXEL, head + Vector((0, -R, 0.2)), R * 1.1)
    face = []
    for side, b in zip((-1, 1), bumps):
        face += k.eye(body, b, k.outward(side * 14, 6), R * 0.24)
        face.append(k.lens(body, head, k.outward(side * 50, -14), R * 0.17, k.flat(k.mix((150, 220, 150), k.BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
        face.append(k.lens(body, head, k.outward(side * 7, 2), 0.035, k.flat(k.NOSE), thick=0.5, sink=0.5, seg=12, name="nostril"))
    face.append(k.mouth(body, head, k.outward(0, -18), 0.5, ink, "smile", r=0.045))
    parts += k.texel(face, k.FACE_TEXEL)
    return parts


def creature_pup():
    """Bee stripes are bands cast all round the body, so they read from the front three-quarter
    view too, not only from behind."""
    gold = k.paint("pu_fur", [(0, (236, 176, 80)), (1, (255, 214, 122))], 0, 3.5)
    stripe, wing = k.flat((92, 66, 58)), k.flat((232, 244, 255))
    head, R = Vector((0, -0.3, 2.45)), 1.0
    snout = Vector((0, -1.25, 2.12))
    tail = spline([(0, 1.0, 0.62), (0, 1.38, 0.82), (0.04, 1.52, 1.22)], [0.17, 0.14, 0.1], 6)
    body = k.fuse(
        [
            (head, R, (1.24, 0.98, 0.95)),
            (snout, 0.42, (1.25, 0.95, 0.78)),
            ((0, 0.1, 1.2), 0.88, (1.05, 1.1, 0.95)),  # chest
            ((0, 0.25, 0.66), 0.85, (1.15, 1.2, 0.74)),  # round seat
            *k.pair((1.12, -0.22, 2.26), 0.52, (0.32, 0.55, 1.0), (0, -10, 0)),  # floppy ears
            *k.pair((0.5, -0.5, 0.2), 0.3, (0.9, 1.45, 0.62)),  # feet
            *k.pair((0.74, -0.42, 1.64), 0.2, (0.85, 0.9, 1.3)),  # arms, above the stripes
        ],
        gold,
        tris=2900,
    )
    parts = [band(body, 0, 0.2, z0, z0 + 0.3, stripe, name="stripe") for z0 in (0.5, 1.02)]
    # The tail is its own fused piece, added after the stripes so they run under it, not over it.
    parts += [body, k.fuse(capsules(tail), gold, tris=300, name="tail")]
    for side in (-1, 1):
        for length, width, pitch, yaw in ((1.45, 0.5, 58, 20), (1.05, 0.4, 20, 34)):
            parts += k.texel(xf(petal(length, width, wing, droop=0.06, base=0.45, n=8, steps=10), (0.22, 0.72, 1.95), yaw=yaw, pitch=pitch, roll=90, mirror=side < 0), 0.5)
    parts += snout_face(body, snout, (255, 240, 212), k.NOSE)
    parts += k.face(body, head, R, skin=(250, 200, 110), nose=None, mouth_kind=None, eye_phi=8, spread=36)
    return parts


def creature_cat():
    """A strawberry cat: seeds are small set-in lenses kept off the face, a calyx of leaves for a
    collar."""
    red = k.paint("ca_fur", [(0, (214, 52, 76)), (1, (246, 92, 112))], 0, 3.8)
    pink, seed, cream = k.flat((255, 170, 195)), k.flat((255, 228, 150)), (255, 238, 222)
    greens = [k.flat((96, 184, 88)), k.flat((134, 212, 98))]
    head, R = Vector((0, -0.15, 2.55)), 1.1
    tilt = 16
    ear = (0.66, -0.05, 3.52)
    tail = spline([(0.15, 0.95, 0.42), (0.5, 1.4, 0.55), (0.7, 1.58, 1.1), (0.6, 1.42, 1.6), (0.36, 1.25, 1.82)], [0.17, 0.17, 0.16, 0.15, 0.14], 14)
    body = k.fuse(
        [
            (head, R, (1.28, 0.98, 0.92)),
            ((0, 0.1, 1.25), 0.85, (1.05, 1.05, 0.95)),  # chest
            ((0, 0.2, 0.68), 0.88, (1.18, 1.15, 0.77)),  # round seat
            *k.pair(ear, 0.6, (0.5, 0.25, 1.0), (0, tilt, 0)),  # pointed ears
            *k.pair((0.5, -0.55, 0.2), 0.3, (0.9, 1.45, 0.62)),  # feet
            *k.pair((0.72, -0.5, 1.2), 0.19, (0.85, 0.9, 1.3)),  # arms
            *capsules(tail),
        ],
        red,
        tris=2700,
    )
    parts = [body]
    for side in (-1, 1):
        axis = (side * math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt)))
        parts.append(k.lens(body, (side * ear[0], ear[1], ear[2] + 0.02), (0, -1, 0), 0.46, pink, scale=(0.4, 1), thick=0.2, sink=0.6, up=axis, seg=12, name="ear_in"))
    for i in range(7):
        yaw = i * 360 / 7 - 90
        a = math.radians(yaw)
        parts += xf(petal(0.86, 0.32, greens[i % 2], droop=0.12, tip=1.0, base=0.5, n=8, steps=8), (0.55 * math.cos(a), 0.05 + 0.55 * math.sin(a), 1.78), yaw=yaw, pitch=-24)
    # Seeds: a golden-angle spiral of directions, off the face and the collar.
    for i in range(64):
        z = 1 - 2 * (i + 0.5) / 64
        a = i * 2.39996
        d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
        if -0.6 < z < 0.2:
            centre = Vector((0, 0.15, 0.95))
        elif d.y > 0.15 and z > -0.2 or z > 0.7 and d.y > -0.3:
            centre = head
        else:
            continue
        parts.append(k.lens(body, centre, d, 0.09, seed, scale=(0.75, 1), thick=0.4, sink=0.4, seg=8, name="seed"))
    face = k.face(body, head, R, skin=(240, 90, 110), nose=None, mouth_kind=None)
    muzzle = k.lens(body, head, k.outward(0, -22), 0.36, k.flat(cream), scale=(1.35, 0.8), thick=0.45, sink=0.55, seg=20, name="muzzle")
    face += k.texel([muzzle, k.lens(muzzle, head, k.outward(0, -14), R * 0.08, pink, scale=(1.35, 0.9), thick=0.55, sink=0.4, seg=12, name="nose"), k.mouth(muzzle, head, k.outward(0, -24), R * 0.15, k.flat(k.INKY), "w")], k.FACE_TEXEL)
    return parts + face


def creature_owl():
    """A pumpkin owl: eight lobes fused round a core make the ribbed pumpkin, a smooth front
    carries a heart-shaped face mask (one fused piece, wider than the eyes, so it never reads as
    the whites of googly eyes) and the belly."""
    orange = k.paint("ow_body", [(0, (226, 110, 40)), (0.5, (250, 148, 60)), (1, (255, 180, 96))], 0, 3.6)
    peach, beak = (255, 210, 158), k.flat((240, 150, 50))
    brown, green = k.flat((120, 80, 50)), k.flat((120, 200, 95))
    c, R = Vector((0, 0, 1.55)), 1.6
    centre = Vector((0, 0, 2.1))  # the face's middle
    lobes = [((c.x + 0.78 * math.sin(math.radians(a)), c.y - 0.78 * math.cos(math.radians(a)), c.z), 1.2, (0.6, 0.78, 1.25), (0, 0, a)) for a in (22.5 + 45 * i for i in range(8))]
    body = k.fuse(
        [
            (c, 1.5, (1.05, 1.0, 0.95)),
            *lobes,
            ((0, -0.85, 1.7), 1.2, (1.12, 0.6, 1.08)),  # smooth front for the face and belly
            *k.pair((1.7, 0.05, 1.45), 0.82, (0.32, 0.7, 1.0), (0, -15, 0)),  # wings
            *k.pair((0.84, -0.12, 3.0), 0.5, (0.5, 0.25, 1.0), (0, 24, 0)),  # ear tufts
        ],
        orange,
        tris=2800,
    )
    # Two big overlapping lobes make one heart mask, peach not white, the eyes in its outer
    # halves; the belly below. Set 0.2 into the skin and turned to it, so their rims bury.
    lobes = []
    for side in (-1, 1):
        p, n = k.land(body, centre, k.outward(side * 16, -5))
        lobes.append((p - n * 0.2, 0.84, (1.0, 0.42, 1.0), (0, 0, side * 16)))
    p, n = k.land(body, (0, 0, 0.82), (0, -1, 0))
    lobes.append((p - n * 0.12, 0.72, (1.05, 0.42, 0.88)))
    mask = k.fuse(lobes, k.flat(peach), tris=700, soft=0.25, name="mask")
    parts = [body, mask]
    for side in (-1, 1):
        parts.append(k.sphere(0.26, (side * 0.52, -1.3, 0.12), m=beak, scale=(0.9, 1.45, 0.62), seg=20, rings=10, name="foot"))
    parts.append(k.tube([(0, 0.05, 2.9), (0.02, 0.05, 3.4), (0.12, 0.02, 3.72), (0.3, -0.04, 3.92)], [0.2, 0.18, 0.16, 0.15], m=brown, n=12, name="stem"))
    parts += xf(petal(0.75, 0.28, green, droop=0.25, tip=1.0, base=0.5, n=10, steps=10), (0.05, 0.05, 3.55), yaw=150, pitch=12)
    # Face by hand: the eyes sit on the mask, the beak between them.
    k.texel([body, mask], k.FACE_TEXEL, centre + Vector((0, -R, -0.1)), R * 0.95)
    face = []
    for side in (-1, 1):
        face += k.eye(mask, centre, k.outward(side * 28, -2), R * 0.22)
        face.append(k.lens(body, centre, k.outward(side * 50, -24), R * 0.14, k.flat(k.mix((250, 150, 62), k.BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
    p, n = k.land(mask, centre, k.outward(0, -12))
    face.append(k.capsule(p - n * 0.12, p + n * 0.2 - Vector((0, 0, 0.2)), 0.14, 0.04, beak, n=12, name="beak"))
    parts += k.texel(face, k.FACE_TEXEL)
    return parts


def creature_fox():
    """Remade from the Roblox AI reference (assets/garden/refs/fox_*.jpg): sitting, a huge round
    head with a white cheek ruff, big dark-tipped ears, a fat upright tail with a tufted white tip
    on its left (+X), and a pink flower with a tiny cactus by the left ear (the "Cactus Fox").
    Every marking is a painted zone on the one fused body."""
    orange = (234, 96, 32)
    white, cream, brown = (252, 246, 236), (246, 226, 186), (92, 50, 34)
    fur = k.paint("fx_fur", [(0, (204, 82, 30)), (0.5, orange), (1, (244, 128, 56))], 0, 4.2, rest=True)
    head, R = Vector((0, -0.05, 2.86)), 1.0
    tilt = 25
    ear = Vector((0.98, 0.02, 3.52))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    tip_at = ear + axis * 0.95
    tail = spline([(0.45, 0.7, 0.32), (0.95, 1.05, 0.7), (1.15, 1.12, 1.35), (1.0, 0.95, 1.95)], [0.32, 0.58, 0.62, 0.42], 12)
    body = k.fuse(
        [
            (head, R, (1.4, 0.98, 0.98)),
            *k.pair((1.1, -0.26, 2.44), 0.26, (0.95, 0.7, 0.5), (0, 22, 0)),  # cheek ruff, out and down
            ((0, 0.02, 1.38), 0.6, (1.0, 0.95, 1.05)),  # chest
            ((0, 0.12, 0.62), 0.74, (1.05, 1.05, 0.82)),  # round seat
            *k.pair((0.58, 0.08, 0.55), 0.44, (0.9, 1.2, 0.85)),  # haunches
            *k.pair(ear, 0.64, (1.0, 0.38, 0.9), (0, tilt, 0)),  # big ears: a wide base...
            *k.pair(ear + axis * 0.55, 0.4, (0.62, 0.32, 1.0), (0, tilt, 0)),  # ...tapering to a soft tip
            ("capsule", (0.3, -0.42, 1.25), (0.3, -0.6, 0.3), 0.21),  # straight front legs
            ("capsule", (-0.3, -0.42, 1.25), (-0.3, -0.6, 0.3), 0.21),
            *k.pair((0.3, -0.66, 0.17), 0.22, (1.0, 1.2, 0.8)),  # front paws
            *k.pair((0.74, -0.52, 0.2), 0.27, (0.95, 1.4, 0.75), (0, 0, 12)),  # big hind feet, forwards
            *capsules(tail),
        ],
        fur,
        tris=3300,
    )
    jag = dict(soft=0.08, jag=0.22)
    k.zone(fur, white, (0, -0.3, 2.2), (2.0, 1.4, 0.34), **jag)  # white lower face and cheek ruff
    k.zone(fur, cream, (0, -0.6, 1.48), (0.3, 0.4, 0.45), soft=0.15)  # chest bib
    k.zone(fur, white, tail[-1][0] + Vector((0, 0, 0.1)), (0.75, 0.75, 0.62), **jag)  # tail tip
    for side in (-1, 1):
        k.zone(fur, brown, (side * tip_at.x, tip_at.y, tip_at.z), (0.5, 0.5, 0.46), soft=0.2)  # ear tips
        k.zone(fur, brown, (side * 0.3, -0.66, 0.12), (0.3, 0.32, 0.22), soft=0.2)  # front paws
        k.zone(fur, brown, (side * 0.74, -0.62, 0.18), (0.38, 0.42, 0.24), soft=0.2)  # hind feet
    parts = [body]
    for side in (-1, 1):
        up = (side * axis.x, 0, axis.z)
        mid = ear + axis * 0.15
        parts.append(k.lens(body, (side * mid.x, mid.y, mid.z), (0, -1, 0), 0.5, k.flat(cream), scale=(0.6, 1), thick=0.2, sink=0.6, up=up, seg=16, name="ear_in"))
    # The pink flower by the left ear, a tiny cactus just behind it.
    d = k.outward(60, 36)
    p, n = k.land(body, head, d)
    x, y, z = k._frame(n)
    place = Matrix.Translation(p + n * 0.02) @ Matrix((x, y, z)).transposed().to_4x4()
    for i in range(5):
        for ob in xf(petal(0.36, 0.19, k.flat((252, 160, 196)), droop=0.2, tip=0.5, base=0.4, n=8, steps=8), yaw=72 * i + 18, pitch=14):
            ob.data.transform(place)
            parts.append(ob)
    parts.append(k.lens(body, head, d, 0.1, k.flat(k.SUNNY), thick=0.9, sink=0.1, seg=12, name="bloom_heart"))
    cactus = k.flat((96, 176, 92))
    p, n = k.land(body, head, k.outward(80, 44))
    root = p - n * 0.05
    top = root + (n * 0.4 + Vector((0, 0, 1))).normalized() * 0.38
    parts.append(k.capsule(root, top, 0.11, 0.1, cactus, n=12, name="cactus"))
    elbow = root + (top - root) * 0.45
    side_dir = n.cross(Vector((0, 0, 1))).normalized()
    parts.append(k.capsule(elbow, elbow + side_dir * 0.16 + Vector((0, 0, 0.12)), 0.07, 0.065, cactus, n=10, name="cactus_arm"))
    parts += k.face(body, head, R, skin=white, nose=(48, 34, 42), eye_r=0.27, eye_wide=0.92, spread=31, eye_phi=-24, nose_phi=-24, nose_r=0.1, mouth_phi=-32, mouth_w=0.1, sheen=True, blush_theta=44, blush_phi=-34)
    return parts


def creature_turtle():
    """A lotus turtle: low round body, big head, the shell a lotus whose petals blush pinker
    towards their tips."""
    teal = k.paint("tu_skin", [(0, (96, 190, 182)), (1, (150, 228, 214))], 0, 2.4)
    lotus = k.paint("tu_petal", [(0, (255, 236, 242)), (0.55, (255, 186, 212)), (1, (255, 132, 178))], 1.6, 3.2)
    pod, dot = k.flat((236, 222, 120)), k.flat((196, 176, 80))
    head, R = Vector((0, -1.15, 1.5)), 1.0
    body = k.fuse(
        [
            (head, R, (1.15, 0.95, 0.95)),
            ((0, 0.25, 0.85), 1.15, (1.42, 1.1, 0.8)),
            ((0, 0.3, 0.95), 1.2, (1.4, 1.12, 0.36)),  # the shell's rim, a soft ledge over the legs
            ((0, -0.5, 1.05), 0.6),  # neck
            *k.pair((1.34, -0.5, 0.2), 0.36, (0.95, 1.3, 0.6)),  # front legs
            *k.pair((1.34, 0.85, 0.2), 0.36, (0.95, 1.3, 0.6)),  # back legs
            ("capsule", (0, 1.3, 0.5), (0, 1.72, 0.38), 0.14),  # tail
        ],
        teal,
        tris=2700,
    )
    parts = [body]
    top = Vector((0, 0.25, 1.7))
    petals = []
    for i in range(8):
        yaw = i * 45 + 22.5
        a = math.radians(yaw)
        petals += xf(petal(1.65, 0.62, lotus, droop=-0.12, tip=1.0, base=0.45, n=8, steps=10), top + Vector((0.35 * math.cos(a), 0.35 * math.sin(a), 0)), yaw=yaw, pitch=32)
    for i in range(5):
        yaw = i * 72 + 90
        a = math.radians(yaw)
        petals += xf(petal(1.5, 0.55, lotus, droop=-0.12, tip=1.0, base=0.45, n=8, steps=10), top + Vector((0.15 * math.cos(a), 0.15 * math.sin(a), 0.05)), yaw=yaw, pitch=70)
    parts += k.texel(petals, 0.5)
    heart = k.lathe([(0.42, 0), (0.44, 0.22), (0.38, 0.4), (0.24, 0.5), (0, 0.53)], loc=top + Vector((0, 0, 0.1)), m=pod, n=24, name="pod")
    parts.append(heart)
    for d in [(0, 0, 1)] + [k.outward(a, 55) for a in range(0, 360, 72)]:
        parts.append(k.lens(heart, top + Vector((0, 0, 0.3)), d, 0.05, dot, thick=0.4, sink=0.6, seg=8, name="seed"))
    parts += k.face(body, head, R, skin=(120, 205, 195), mouth_kind="smile")
    return parts


def creature_lion():
    """A sunflower lion: the mane is a seed ring with petals round the head; snout, round ears
    and a tail with a tuft."""
    gold = k.paint("li_fur", [(0, (232, 170, 76)), (1, (255, 212, 112))], 0, 5.0)
    yellows = [k.flat((255, 196, 46)), k.flat((255, 216, 80))]
    seed = k.paint("li_seed", [(0, (104, 68, 46)), (1, (104, 68, 46))], 0, 1, dots=[((140, 98, 66), 9, 0.32)])
    pink, brown = k.flat((255, 176, 196)), k.flat((120, 78, 52))
    head, R = Vector((0, -0.5, 3.0)), 1.2
    snout = Vector((0, -1.55, 2.68))
    tail = spline([(0.15, 1.2, 0.55), (0.45, 1.85, 0.62), (0.62, 2.12, 1.1), (0.56, 2.05, 1.52)], [0.13, 0.12, 0.11, 0.1], 10)
    body = k.fuse(
        [
            (head, R, (1.12, 0.95, 0.93)),
            (snout, 0.5, (1.25, 0.85, 0.72)),
            ((0, 0.15, 1.45), 0.95, (1.05, 1.12, 0.95)),  # chest
            ((0, 0.3, 0.78), 0.95, (1.15, 1.2, 0.8)),  # round seat
            *k.pair((0.86, -0.5, 4.0), 0.36),  # round ears
            *k.pair((0.6, -0.65, 0.22), 0.34, (0.9, 1.45, 0.62)),  # feet
            *k.pair((0.86, -0.55, 1.45), 0.22, (0.85, 0.9, 1.3)),  # arms
            *capsules(tail),
        ],
        gold,
        tris=2500,
    )
    parts = [body, k.sphere(0.25, tail[-1][0] + Vector((0, -0.02, 0.12)), m=brown, scale=(1, 1, 1.15), seg=20, rings=10, name="tuft")]
    for side in (-1, 1):
        parts.append(k.lens(body, (side * 0.86, -0.5, 4.0), (0, -1, 0.1), 0.2, pink, thick=0.3, sink=0.6, seg=12, name="ear_in"))
    ring = k.ring(1.38, 0, 0.3, seed, n=24, sides=8, name="mane")
    ring.data.transform(Matrix.Translation((0, -0.32, 3.0)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    parts.append(ring)
    for i in range(16):
        a = i * 22.5 + 11.25
        if abs(a - 270) < 30:
            continue  # these would point down into the chest
        rad = math.radians(a)
        p = petal(1.05, 0.42, yellows[i % 2], droop=0.08, tip=0.9, base=0.5, n=8, steps=7)
        p.data.transform(Matrix.Translation((1.45 * math.cos(rad), -0.25 + 0.03 * (i % 2), 3.0 + 1.45 * math.sin(rad))) @ Matrix.Rotation(math.radians(-a), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "X"))
        parts.append(k.texel(p, 0.5))
    parts += snout_face(body, snout, (255, 240, 212), (120, 78, 52), nose_r=0.14, mouth_w=0.26, muzzle_r=0.5)
    parts += k.face(body, head, R, skin=(250, 200, 110), nose=None, mouth_kind=None, eye_phi=8, spread=36)
    return parts


def creature_dragon():
    """Body, head, snout, shouldered arms, feet and the curled tail are one fused shape; the
    moon-flower wings are soft round-tipped petals."""
    lilac = k.paint("dr_skin", [(0, (184, 156, 234)), (1, (222, 204, 255))], 0, 5.0)
    belly, white, vein = k.flat((246, 236, 255)), k.flat((255, 250, 255)), k.flat((200, 170, 240))
    horn, moon, ink = k.flat((255, 240, 210)), k.flat((255, 236, 160)), k.flat(k.INKY)
    head, R = Vector((0, -0.85, 3.35)), 1.4
    snout = Vector((0, -2.0, 2.95))
    tail = []
    for i in range(25):  # short capsules, or the thin tip turns into beads
        t = i / 24
        a = math.radians(-100 + 300 * t)
        rr = 0.65 - 0.35 * t
        tail.append((Vector((0.3, 1.8, 1.4)) + Vector((0, rr * math.cos(a), rr * math.sin(a))), 0.3 - 0.19 * t))
    body = k.fuse(
        [
            (head, R, (1.08, 0.98, 0.94)),
            ((0, 0.3, 1.5), 1.25, (1.0, 1.18, 1.0)),
            (snout, 0.6, (1.3, 0.85, 0.72)),
            *k.pair((0.7, -0.8, 0.3), 0.42, (0.95, 1.3, 0.7)),  # front feet
            *k.pair((0.8, 0.95, 0.32), 0.45, (0.95, 1.3, 0.7)),  # back feet
            *k.pair((0.86, -0.3, 2.0), 0.34, (0.9, 1.0, 1.0)),  # shoulders
            ("capsule", (0.94, -0.42, 1.95), (0.86, -0.88, 1.5), 0.22),  # arms
            ("capsule", (-0.94, -0.42, 1.95), (-0.86, -0.88, 1.5), 0.22),
            *k.pair((0.82, -0.98, 1.42), 0.25, (1.0, 1.1, 0.85)),  # small paws
            *capsules(tail),
        ],
        lilac,
        tris=2700,
    )
    parts = [body]
    for side in (-1, 1):
        parts.append(k.capsule((side * 0.55, -0.7, 4.35), (side * 0.8, -0.5, 5.1), 0.22, 0.06, horn, n=10, name="horn"))
        parts.append(k.lens(body, snout, k.outward(side * 20, 14), 0.065, ink, thick=0.5, sink=0.5, seg=12, name="nostril"))
        for length, width, pitch, yaw in ((2.8, 1.15, 35, 10), (2.45, 1.0, 8, 18), (2.1, 0.88, -18, 24)):
            wing = petal(length, width, white, droop=0.1, n=10, steps=12)
            # The vein lies on the petal's flattened top face (same profile as petal()).
            top = [(length * s, 0, 0.28 * (length * 0.1 * math.sin(s * math.pi * 0.8) + width * math.sin(math.pi * s) ** 0.5 * (0.55 + 0.45 * s)) + 0.01) for s in (0.1, 0.4, 0.7, 0.9)]
            rib = k.tube(top, [0.045, 0.04, 0.03, 0.02], m=vein, n=4, name="vein")
            parts += k.texel(xf([wing, rib], (0.5, 0.55, 2.5), yaw=yaw, pitch=pitch, roll=90, mirror=side < 0), 0.5)
    parts.append(k.mouth(body, snout, k.outward(0, -32), 0.32, ink, "smile"))
    # Crescent moon on the forehead: a tapered arc on the surface, horns up.
    f = Vector((0, -1, 0.55)).normalized()
    pts, radii = [], []
    for i in range(11):
        t = i / 10 * 2 - 1
        a = math.radians(125 * t)
        p, n = k.land(body, head, f + Vector((0.3 * math.sin(a), 0, -0.3 * math.cos(a))))
        r = 0.02 + 0.075 * (1 - t * t) ** 0.6
        pts.append(p + n * r * 0.3)
        radii.append(r)
    parts.append(k.tube(pts, radii, m=moon, n=6, name="crescent"))
    k.texel([p for p in parts if p.name.startswith(("nostril", "mouth", "crescent"))], k.FACE_TEXEL)
    for z in (0.95, 1.45, 1.95):
        parts.append(k.lens(body, (0, 0.3, z), (0, -1, 0), 0.55, belly, scale=(1.0, 0.4), thick=0.5, sink=0.6, seg=12, name="plate"))
    # With a snout, the eyes sit just above its top line, not low on the head.
    parts += k.face(body, head, R, skin=(215, 195, 250), nose=None, mouth_kind=None, eye_phi=8, spread=36)
    return parts


NOTES = "One mesh (Plots.luau creature through Models.nightPart). Scale to the manifest height. Chibi toy: head near half the height, baked eyes and markings."
ASSETS = [
    dict(
        name=f"creature_{id}",
        build=fit(size)(build),
        budget=k.CREATURE_BUDGET,
        finalize=k.HD,
        size=size,
        priority=1,
        order=order,
        replaces=f"Roblox-generated {label} mesh (src/relay/Models.luau MESHES.{id})",
        notes=NOTES,
        glow={},
    )
    for order, (id, label, build, size) in enumerate(
        (
            ("bunny", "Sprout Bunny", creature_bunny, [2.3, 4.0, 1.8]),
            ("frog", "Toadstool Frog", creature_frog, [3.2, 3.5, 3.2]),
            ("pup", "Bumble Pup", creature_pup, [3.0, 3.8, 3.6]),
            ("cat", "Berry Cat", creature_cat, [3.2, 4.2, 3.0]),
            ("owl", "Pumpkin Owl", creature_owl, [4.2, 4.5, 3.8]),
            ("fox", "Cactus Fox", creature_fox, [3.6, 4.5, 2.9]),
            ("turtle", "Lotus Turtle", creature_turtle, [3.8, 3.5, 3.8]),
            ("lion", "Sunflower Lion", creature_lion, [4.6, 5.2, 4.6]),
            ("dragon", "Moonblossom Dragon", creature_dragon, [6.0, 5.5, 4.8]),
        ),
        20,
    )
]
