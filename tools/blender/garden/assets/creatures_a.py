"""The nine Egg Garden creatures as chibi toys, all to the HD standard (tools/blender/garden/README.md
"Creature standard"): one fused body, the kit face, smooth separate props, one theme prop each.
One mesh per creature, standing on the origin, facing Blender -Y. Replaces the Roblox-generated
meshes in src/relay/Models.luau MESHES."""

import math
import os
import sys

import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creatures_b import disc, onto, toward  # noqa: E402

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
            tris = sum(k._tris(ob) for ob in parts)  # over k.CREATURE_BUDGET, finalize silently decimates
            print(f"[creatures_a] {build.__name__} fit scale x {s[0]:.2f} y {s[1]:.2f} z {s[2]:.2f}, {tris} tris", flush=True)
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
    """Remade from the Roblox AI reference (assets/garden/refs/frog_*.jpg): a squat green frog
    under a big red toadstool cap with white spots and a cream rim, a round head with big low
    eyes, a cream belly strip, wide flat feet and a short minty tail."""
    skin = k.paint("fr_skin", [(0, (76, 160, 84)), (0.45, (118, 198, 104)), (1, (152, 224, 128))], 0, 2.1, rest=True)
    cap = k.paint("fr_cap", [(0, (206, 54, 60)), (1, (244, 98, 92))], 1.9, 3.1)
    spot, rim = k.flat((250, 246, 236)), k.flat((244, 232, 214))
    head, R = Vector((0, -0.05, 1.28)), 0.8
    tail = spline([(-0.2, 0.5, 0.36), (-0.42, 0.98, 0.24), (-0.58, 1.36, 0.15)], [0.32, 0.23, 0.12], 8)
    body = k.fuse(
        [
            (head, R, (1.2, 0.95, 0.88)),
            *k.pair((0.5, -0.28, 1.08), 0.42, (1.0, 0.85, 0.8)),  # full cheeks
            ((0, 0.08, 0.55), 0.66, (1.3, 1.12, 0.85)),  # squat wide body
            *k.pair((0.68, 0.12, 0.38), 0.48, (0.95, 1.25, 0.8)),  # bulging haunches
            ("capsule", (0.32, -0.38, 0.75), (0.38, -0.56, 0.18), 0.2),  # short front legs, against the chest
            ("capsule", (-0.32, -0.38, 0.75), (-0.38, -0.56, 0.18), 0.2),
            *k.pair((0.42, -0.7, 0.09), 0.24, (1.3, 1.15, 0.42), (0, 0, -15)),  # wide flat front feet
            *k.pair((0.86, -0.3, 0.09), 0.26, (1.25, 1.3, 0.42), (0, 0, 25)),  # back feet
            *capsules(tail),
        ],
        skin,
        tris=2900,
    )
    k.zone(skin, (128, 206, 172), (-0.3, 1.1, 0.3), (1.0, 0.9, 0.55), soft=0.5)  # minty back and tail
    k.zone(skin, (238, 230, 196), (0, -0.66, 0.58), (0.22, 0.3, 0.4), soft=0.25)  # cream belly strip
    parts = [body]
    top = Vector((0, 0.08, 1.66))
    profile = [(r * 1.22, z * 1.15) for r, z in [(0, 0), (0.85, 0.02), (1.18, 0.08), (1.27, 0.18), (1.24, 0.34), (1.1, 0.56), (0.86, 0.78), (0.56, 0.93), (0.28, 1.0), (0, 1.02)]]
    cap_ob = k.lathe(profile, loc=top, rot=(8, 0, 0), m=cap, n=32, name="cap")
    parts.append(cap_ob)
    parts.append(k.sphere(1.42, top + Vector((0, 0, 0.07)), rot=(8, 0, 0), m=rim, scale=(1, 1, 0.06), seg=32, rings=6, name="rim"))
    centre = top + Vector((0, 0, 0.1))
    for d, r in [((0, 0, 1), 0.22)] + [(k.outward(a, 50), 0.19) for a in range(-144, 216, 72)] + [(k.outward(a, 18), 0.16) for a in range(-108, 252, 72)]:
        parts.append(k.lens(cap_ob, centre, d, r, spot, scale=(1.15, 1), thick=0.4, sink=0.45, seg=12, name="spot"))
    k.texel([cap_ob], 0.6)
    face = [k.lens(body, head, k.outward(s * 7, -17), R * 0.035, k.flat((50, 96, 56)), thick=0.5, sink=0.5, seg=12, name="nostril") for s in (-1, 1)]
    parts += k.texel(face, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=(126, 204, 112), nose=None, eye_r=0.29, eye_wide=0.9, spread=33, eye_phi=-8, mouth_phi=-28, mouth_w=0.1, sheen=True, blush_theta=50, blush_phi=-22)
    return parts


def creature_pup():
    """Remade from the Roblox AI reference (assets/garden/refs/pup_*.jpg): a cream-gold pup with
    long black floppy ears, a short muzzle and a big black nose, sitting, with black bee stripes,
    a black collar, black hindquarters and tail, and two pairs of bee wings."""
    gold = k.paint("pu_fur", [(0, (204, 150, 72)), (0.4, (236, 198, 122)), (1, (250, 228, 164))], 0, 3.6, rest=True)
    black = (42, 36, 40)
    ink = k.paint("pu_ear", [(0, (30, 26, 30)), (1, (66, 60, 66))], 1.4, 3.2)
    wing = k.flat((212, 214, 220))
    head, R = Vector((0, -0.1, 2.5)), 1.0
    snout = Vector((0, -0.98, 2.1))
    tail = spline([(0, 0.85, 0.5), (0.05, 1.25, 0.46), (0.12, 1.5, 0.64)], [0.17, 0.15, 0.13], 8)
    body = k.fuse(
        [
            (head, R, (1.1, 0.95, 0.95)),
            (snout, 0.4, (1.05, 1.1, 0.8)),
            ((0, -0.05, 1.32), 0.62, (1.0, 1.0, 1.05)),  # chest
            ((0, 0.25, 0.64), 0.72, (1.05, 1.2, 0.85)),  # seat
            *k.pair((0.55, 0.35, 0.5), 0.4, (0.9, 1.2, 0.85)),  # haunches
            ("capsule", (0.36, -0.42, 1.2), (0.36, -0.52, 0.25), 0.19),  # front legs
            ("capsule", (-0.36, -0.42, 1.2), (-0.36, -0.52, 0.25), 0.19),
            *k.pair((0.36, -0.6, 0.14), 0.21, (1.0, 1.25, 0.75)),  # front paws
            *k.pair((0.68, -0.25, 0.15), 0.24, (0.95, 1.35, 0.7)),  # hind feet
            *capsules(tail),
        ],
        gold,
        tris=3000,
    )
    for z, ry in ((1.64, 0.1), (1.2, 0.17), (0.72, 0.17)):  # collar, then two bee stripes
        k.zone(gold, black, (0, 0.15, z), (0.7, 1.2, ry), soft=0.12)
    k.zone(gold, black, (0, 1.15, 0.45), (1.2, 0.7, 0.7), soft=0.15)  # black rump and tail
    # Long floppy ears from the top of the head, flaring out below the cheeks.
    ears = k.fuse([*k.pair((0.9, 0.0, 2.95), 0.45, (0.55, 0.8, 0.9)), *k.pair((1.12, -0.04, 2.1), 0.85, (0.36, 0.72, 1.0), (0, -16, 0))], ink, tris=900, name="ears")
    parts = [body, ears]
    for side in (-1, 1):
        for length, width, pitch, yaw in ((1.35, 0.5, 40, 30), (0.95, 0.38, 12, 45)):
            parts += k.texel(xf(petal(length, width, wing, droop=0.06, base=0.45, n=8, steps=10), (0.22, 0.58, 1.7), yaw=yaw, pitch=pitch, roll=90, mirror=side < 0), 0.5)
    face = [
        k.lens(body, snout, k.outward(0, 24), 0.21, k.flat((30, 26, 32)), scale=(1.35, 0.95), thick=0.7, sink=0.4, seg=20, name="nose"),
        k.mouth(body, snout, k.outward(0, -28), 0.17, k.flat(k.INKY), "w"),
    ]
    for s in (-1, 1):
        face.append(k.lens(body, head, k.outward(s * 22, 24), 0.12, k.flat((80, 52, 40)), scale=(1.6, 0.3), thick=0.3, sink=0.5, seg=12, up=(s * 0.25, 0, 1), name="brow"))
    parts += k.texel(face, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=(244, 214, 150), nose=None, mouth_kind=None, eye_r=0.19, eye_wide=0.9, spread=24, eye_phi=6, sheen=True, blush_theta=44, blush_phi=-14)
    return parts


def creature_cat():
    """Remade from the Roblox AI reference (assets/garden/refs/cat_*.jpg): a lavender kitten with
    a huge wide head, a white muzzle, big dark eyes, purple whiskers, pointed ears with pink
    insides, a thick curled tail, and a red berry cluster with a leaf by its left ear (the
    "Berry Cat")."""
    fur = k.paint("ca_fur", [(0, (124, 72, 182)), (0.45, (164, 108, 214)), (1, (206, 168, 236))], 0, 3.8, rest=True)
    pink, whisker = k.flat((250, 176, 200)), k.flat((150, 92, 210))
    head, R = Vector((0, -0.05, 2.15)), 1.2
    tilt = 18
    ear = Vector((1.0, 0.05, 3.2))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    tail = spline([(0.4, 0.6, 0.3), (0.82, 0.8, 0.36), (1.0, 0.85, 0.66), (0.9, 0.78, 0.88)], [0.2, 0.25, 0.27, 0.24], 10)
    body = k.fuse(
        [
            (head, R, (1.3, 0.95, 0.9)),
            *k.pair((0.78, -0.25, 1.78), 0.58, (1.0, 0.85, 0.8)),  # full cheeks
            ((0, 0.02, 1.0), 0.54, (1.05, 1.0, 0.95)),  # chest
            ((0, 0.12, 0.55), 0.7, (1.08, 1.1, 0.8)),  # seat
            *k.pair((0.5, 0.15, 0.45), 0.42, (0.9, 1.2, 0.85)),  # haunches
            ("capsule", (0.3, -0.36, 0.85), (0.3, -0.5, 0.25), 0.22),  # front legs, against the chest
            ("capsule", (-0.3, -0.36, 0.85), (-0.3, -0.5, 0.25), 0.22),
            *k.pair((0.3, -0.6, 0.14), 0.21, (1.0, 1.25, 0.75)),  # front paws
            *k.pair((0.66, -0.3, 0.15), 0.24, (0.95, 1.35, 0.7)),  # hind feet
            *k.pair(ear, 0.66, (0.66, 0.32, 1.0), (0, tilt, 0)),  # pointed ears
            *capsules(tail),
        ],
        fur,
        tris=2600,
    )
    k.zone(fur, (238, 214, 242), (0, 0.95, 2.5), (1.7, 0.8, 1.2), soft=0.6)  # pale back of the head
    k.zone(fur, (250, 244, 250), (0, -1.12, 1.7), (0.66, 0.45, 0.44), soft=0.35)  # white muzzle
    parts = [body]
    for side in (-1, 1):
        mid = ear + axis * 0.0
        parts.append(k.lens(body, (side * mid.x, mid.y, mid.z), (0, -1, 0), 0.42, pink, scale=(0.62, 1), thick=0.2, sink=0.6, up=(side * axis.x, 0, axis.z), seg=16, name="ear_in"))
        for a in (5, -5):  # two short thick whiskers a side, out from the cheeks
            p, n = k.land(body, head, k.outward(side * 56, -16 + a))
            out = (n + Vector((side * 0.9, 0, a * 0.04))).normalized()
            parts.append(k.capsule(p - n * 0.05, p + out * 0.42, 0.045, 0.035, whisker, n=10, name="whisker"))
    # Berry cluster and a leaf by the left ear (+X).
    p, n = k.land(body, head, k.outward(42, 44))
    red = k.paint("ca_berry", [(0, (196, 30, 52)), (1, (236, 70, 80))], 2.9, 3.6, dots=[((250, 190, 190), 30, 0.08)])
    x, y, _ = k._frame(n)
    for u, v, r in ((0, 0, 0.24), (0.28, -0.06, 0.2), (-0.06, 0.26, 0.19)):
        parts.append(k.sphere(r, p + n * (r * 0.6) + x * u + y * v, m=red, seg=20, rings=10, name="berry"))
    parts += xf(petal(0.5, 0.22, k.flat((92, 176, 84)), droop=0.15, tip=0.8, base=0.45, n=8, steps=8), p + n * 0.1 - x * 0.12 + y * 0.12, yaw=150, pitch=30)
    parts += k.face(body, head, R, skin=(196, 160, 232), nose=(244, 140, 170), eye_r=0.35, eye_wide=0.92, spread=33, eye_phi=-14, nose_phi=-24, nose_r=0.07, mouth_phi=-31, mouth_w=0.1, sheen=True, blush_theta=46, blush_phi=-26)
    return parts


def creature_owl():
    """Remade from the Roblox AI reference (assets/garden/refs/owl_*.jpg): a boxy pumpkin-orange
    owl, head and body one shape with faint pumpkin ribs, big white eye masks round black eyes, a
    small yellow beak, pointed ear tufts, a cream belly with brown spots, brown feathered wings at
    the sides, brown bumps on the back and a curly green pumpkin stem with a round leaf on top
    (the "Pumpkin Owl")."""
    fur = k.paint("ow_body", [(0, (214, 104, 34)), (0.45, (240, 136, 52)), (1, (250, 160, 74))], 0, 3.6, rays=((228, 120, 44), 9, 2.2, 0.04), rest=True)
    white, cream = (250, 248, 244), (240, 222, 178)
    brown = k.paint("ow_wing", [(0, (98, 54, 34)), (1, (146, 88, 54))], 0.2, 1.8, bands=((118, 68, 42), 0.18))
    spot = k.flat((150, 92, 60))
    head, R = Vector((0, 0, 2.4)), 1.0
    tilt = 24
    ear = Vector((1.02, 0.0, 3.0))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    body = k.fuse(
        [
            (head, R, (1.42, 1.1, 0.98)),
            ((0, 0.05, 1.3), 1.1, (1.34, 1.12, 1.0)),  # body: one boxy block with the head
            ((0, 0.05, 0.5), 1.0, (1.3, 1.1, 0.55)),  # flat round seat
            *k.pair(ear, 0.5, (0.85, 0.42, 0.8), (0, tilt, 0)),  # pointed ear tufts: a wide base...
            *k.pair(ear + axis * 0.4, 0.26, (0.7, 0.4, 1.0), (0, tilt, 0)),  # ...to a soft point
        ],
        fur,
        tris=2600,
    )
    for side in (-1, 1):  # white eye masks, a rounded square round each eye, nearly meeting
        k.zone(fur, white, head + k.outward(side * 27, -4) * 1.18 + Vector((0, 0, 0.04)), (0.64, 0.5, 0.56), soft=0.07)
    k.zone(fur, cream, (0, -1.1, 0.92), (0.82, 0.6, 0.72), soft=0.06)  # cream belly
    parts = [body]
    wings = k.fuse([*k.pair((1.44, -0.12, 1.02), 0.74, (0.36, 0.78, 1.0), (0, -10, 14))], brown, tris=800, name="wings")
    parts.append(wings)
    k.texel([wings], 0.6)
    for x, z, r in ((0, 1.3, 0.08), (-0.32, 1.0, 0.075), (0.3, 0.98, 0.075), (0.02, 0.72, 0.08), (-0.4, 0.55, 0.07), (0.38, 0.58, 0.07)):
        parts.append(k.lens(body, (x, 0, z), (0, -1, 0), r, spot, thick=0.6, sink=0.4, seg=12, name="spot"))
    for theta, z, r in ((150, 0.55, 0.17), (172, 0.85, 0.12), (198, 0.5, 0.15), (130, 0.95, 0.1), (222, 0.9, 0.11), (180, 0.3, 0.12), (120, 0.4, 0.1)):
        parts.append(k.lens(body, (0, 0.05, z), k.outward(theta, 0), r, spot, thick=0.9, sink=0.3, seg=12, name="back_spot"))
    p, n = k.land(body, head, (0, 0, 1))
    stem = spline([tuple(p - n * 0.1), (0.0, 0.0, 3.5), (0.08, -0.06, 3.72), (0.28, -0.12, 3.74)], [0.13, 0.11, 0.1, 0.09], 10)
    parts.append(k.tube([q for q, _ in stem], [r for _, r in stem], m=k.flat((70, 150, 62)), n=12, name="stem"))
    leaf = k.flat((84, 172, 76))
    for yaw in (30, 150, 270):  # a round three-lobed leaf at the curl
        parts += xf(petal(0.36, 0.26, leaf, droop=0.05, tip=0.4, base=0.6, n=8, steps=8), (0.28, -0.12, 3.76), yaw=yaw, pitch=15)
    p, n = k.land(body, head, k.outward(0, -16))
    beak = k.capsule(p - n * 0.06, p + n * 0.16 - Vector((0, 0, 0.18)), 0.13, 0.035, k.flat((246, 196, 60)), n=12, name="beak")
    parts += k.texel([beak], k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=white, nose=None, mouth_kind=None, eye_r=0.27, eye_wide=0.92, spread=27, eye_phi=-4, sheen=True, blush_theta=56, blush_phi=-32, blush_r=0.11)
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
    """Remade from the Roblox AI reference (assets/garden/refs/turtle_*.jpg): a mint-green turtle
    standing up, a huge round head, big dark-red eyes, a small smile, a peach plastron with scute
    lines, green stubby arms and feet, and a pink spiky shell on its back, veined like a lotus bud,
    with a cream rim (the "Lotus Turtle")."""
    skin = k.paint("tu_skin", [(0, (64, 156, 120)), (0.45, (98, 190, 150)), (1, (128, 210, 170))], 0, 3.1, rest=True)
    plate, line = (236, 152, 84), (196, 112, 56)
    head, R = Vector((0, -0.05, 2.22)), 0.9
    body = k.fuse(
        [
            (head, R, (1.12, 1.0, 0.95)),
            *k.pair((0.46, -0.4, 1.9), 0.42, (1.0, 0.85, 0.8)),  # full cheeks
            ((0, 0.04, 0.92), 0.78, (1.24, 1.08, 1.08)),  # round pot belly
            ((0, 0.1, 0.42), 0.72, (1.2, 1.05, 0.6)),  # seat
            ("capsule", (0.74, -0.12, 1.3), (0.92, -0.32, 0.8), 0.2),  # stubby arms
            ("capsule", (-0.74, -0.12, 1.3), (-0.92, -0.32, 0.8), 0.2),
            *k.pair((0.94, -0.36, 0.76), 0.2, (0.95, 1.0, 1.1)),
            *k.pair((0.38, -0.36, 0.12), 0.22, (1.0, 1.35, 0.6)),  # feet
            ("capsule", (0, 0.7, 0.4), (0, 1.0, 0.25), 0.1),  # little tail
        ],
        skin,
        tris=2500,
    )
    k.zone(skin, plate, (0, -0.76, 0.9), (0.84, 0.44, 0.8), soft=0.06)  # peach plastron
    for z in (0.66, 1.08):  # scute lines across it, and one down the middle
        k.zone(skin, line, (0, -0.8, z), (0.62, 0.3, 0.025), soft=0.3)
    k.zone(skin, line, (0, -0.8, 0.87), (0.025, 0.3, 0.42), soft=0.3)
    k.zone(skin, (226, 150, 120), (0, -0.7, 0.42), (0.4, 0.3, 0.2), soft=0.5)  # warmer low belly
    parts = [body]
    # Pink spiky shell on the back over a cream rim.
    pink = k.paint("tu_shell", [(0, (252, 168, 176)), (0.5, (240, 116, 134)), (1, (224, 92, 112))], 0.35, 1.5, axis="Y", rest=True)
    c = Vector((0, 0.8, 1.0))
    spikes = []
    for theta, phi in ((180, 0), (180, 42), (180, -38), (140, 18), (220, 18), (140, -22), (220, -22), (120, 50), (240, 50), (105, -5), (255, -5)):
        d = k.outward(theta, phi)
        e = Vector((0, 0, 1)).rotation_difference(d).to_euler("XYZ")  # the spike's long axis along d
        spikes.append((c + Vector((d.x * 1.14, d.y * 0.91, d.z * 1.08)), 0.13, (0.7, 0.7, 1.4), tuple(math.degrees(t) for t in e)))
    shell = k.fuse([(c, 1.14, (1.0, 0.8, 0.95)), *spikes], pink, tris=1300, soft=0.3, name="shell")
    rim = k.sphere(1.1, (0, 0.32, 0.98), m=k.flat((236, 216, 184)), scale=(1.0, 0.14, 0.96), seg=32, rings=12, name="rim")
    parts += k.texel([shell, rim], 0.6)
    parts += k.face(body, head, R, skin=(112, 202, 162), iris=(74, 14, 24), nose=None, mouth_kind="smile", eye_r=0.27, eye_wide=0.88, spread=30, eye_phi=-8, mouth_phi=-24, mouth_w=0.11, sheen=True, blush_theta=46, blush_phi=-26)
    return parts


def creature_lion():
    """Remade from the Roblox AI reference (assets/garden/refs/lion_*.jpg): a small sitting cub in
    ribbed tan fur, a round face with a white muzzle, a big brown nose and small black eyes, round
    ears, a sunflower mane (a ring of rust-brown ruffles inside two rows of pointed yellow petals)
    nearly as tall as the whole lion, a white chest tuft, and a tail ending in a big seed-pod tuft
    that rises up its back (the "Sunflower Lion")."""
    tan_rgb = (218, 138, 82)
    fur = k.paint("li_fur", [(0, (184, 104, 58)), (0.45, tan_rgb), (1, (234, 164, 104))], 0, 3.2, rest=True, grain=(0.1, 34, "wave"))
    head, R = Vector((0, -0.2, 2.02)), 0.74
    snout = Vector((0, -0.8, 1.76))
    mane_c = Vector((0, -0.02, 2.1))
    ear = Vector((0.52, -0.24, 2.58))
    body = k.fuse(
        [
            (head, R, (1.1, 1.0, 1.0)),
            *k.pair((0.34, -0.6, 1.78), 0.3, (1.0, 0.85, 0.8)),  # muzzle cheeks
            (snout, 0.3, (1.25, 0.95, 0.85)),
            *k.pair(tuple(ear), 0.24, (1.0, 0.6, 0.95)),  # round ears
            ((0, 0.04, 0.96), 0.58, (1.05, 0.95, 1.0)),  # chest
            ((0, 0.18, 0.5), 0.74, (1.15, 1.1, 0.72)),  # seat
            ("capsule", (0.3, -0.3, 1.0), (0.31, -0.48, 0.2), 0.2),  # front legs
            ("capsule", (-0.3, -0.3, 1.0), (-0.31, -0.48, 0.2), 0.2),
            *k.pair((0.31, -0.58, 0.13), 0.21, (1.0, 1.3, 0.68)),  # front paws
            *k.pair((0.68, -0.32, 0.16), 0.27, (0.95, 1.4, 0.68), (0, 0, 14)),  # big hind feet
        ],
        fur,
        tris=1950,
    )
    k.zone(fur, (252, 244, 232), snout + Vector((0, -0.05, -0.04)), (0.46, 0.32, 0.3), soft=0.2)  # white muzzle
    k.zone(fur, (252, 244, 232), (0, -0.56, 0.86), (0.14, 0.2, 0.3), soft=0.15, jag=0.25)  # chest tuft
    for s in (-1, 1):
        k.zone(fur, (240, 186, 140), (s * 0.68, -0.66, 0.12), (0.24, 0.2, 0.16), soft=0.3)  # paler toes
    parts = [body]
    for s in (-1, 1):
        parts.append(k.lens(body, (s * ear.x, ear.y, ear.z), (s * 0.2, -1, 0.2), 0.14, k.flat((240, 178, 132)), scale=(1, 0.95), thick=0.25, sink=0.6, seg=16, name="ear_in"))
    # Sunflower mane round the face: rust ruffles, then two rows of pointed yellow petals.
    rust = k.paint("li_ruff", [(0, (136, 54, 34)), (1, (184, 84, 50))], 1.2, 3.2, rest=True)
    ruffles = []
    for i in range(24):  # rolled ruffles, radial all round the face
        a = math.radians(i * 15 + 7.5)
        d = Vector((math.cos(a), 0.1, math.sin(a)))
        ruffles.append(toward(mane_c + Vector((math.cos(a) * 0.9, -0.16, math.sin(a) * 0.9)), d, 0.14, (0.95, 0.65, 2.5)))
    ruff = k.fuse([(mane_c + Vector((0, -0.02, 0)), 1.0, (1.08, 0.26, 1.08)), *ruffles], rust, tris=900, soft=0.2, name="ruff")
    parts.append(ruff)
    k.texel([ruff], 0.7)
    # Each row is one lobed disc: 14 broad pointed petals, cupped forwards, behind the ruff.
    for r, rgb, spin, lift in ((1.8, (230, 152, 38), 0, 0.2), (1.58, (252, 200, 62), 180 / 14, 0.1)):
        flower = disc(r, lambda a: 0.58 + 0.42 * abs(math.cos(7 * a)) ** 1.1, k.flat(rgb), n=98, cup=0.12, thick=0.05, name="petals")
        flower.data.transform(Matrix.Translation(mane_c + Vector((0, lift, 0))) @ Matrix.Rotation(math.radians(90), 4, "X") @ k.rot_z(spin))
        parts.append(k.texel(flower, 0.5))
    # Seed-pod tail tuft up the back, and a leaf at its root.
    pod_m = k.paint("li_pod", [(0, (230, 140, 60)), (1, (250, 190, 110))], 0.6, 1.9, rest=True, grain=(0.12, 18), dots=[((164, 112, 70), 22, 0.12)])
    pod = k.fuse(capsules(spline([(0, 0.7, 0.42), (0.08, 1.22, 0.84), (0.08, 1.2, 1.34), (0.04, 0.96, 1.68), (0, 0.6, 1.84)], [0.2, 0.38, 0.4, 0.32, 0.14], 12)), pod_m, tris=550, soft=0.3, name="pod")
    parts.append(pod)
    parts += xf(petal(0.4, 0.16, k.flat((70, 140, 60)), droop=0.1, tip=1.0, base=0.45, n=8, steps=8), (-0.3, 0.7, 0.06), yaw=150, pitch=10)
    face = [k.lens(body, snout, k.outward(0, 24), 0.15, k.flat((92, 42, 36)), scale=(1.35, 1.0), thick=0.7, sink=0.4, seg=16, name="nose"),
            k.mouth(body, snout, k.outward(0, -24), 0.13, k.flat(k.INKY), "w")]
    parts += k.texel(face, k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=tan_rgb, nose=None, mouth_kind=None, eye_r=0.17, eye_wide=0.9, spread=27, eye_phi=8, sheen=True, blush_theta=50, blush_phi=-14, blush_r=0.14)
    return parts


def creature_dragon():
    """Remade from the Roblox AI reference (assets/garden/refs/dragon_*.jpg): a lavender baby dragon
    sitting up, a huge round head with big dark eyes and pink cheeks, a white crescent moon on the
    forehead, two big curved pink-tipped horns with a cherry blossom at each base, pointed ears with
    pink insides and three purple frills behind each cheek, a cream belly with plate lines, paws
    held to the chest, big feet with pink soles, small purple bat wings, and a tail curling round its
    right side to the front, tipped with pink spikes (the "Moonblossom Dragon")."""
    lilac_rgb = (184, 158, 236)
    skin = k.paint("dr_skin", [(0, (140, 112, 204)), (0.4, lilac_rgb), (1, (212, 194, 250))], 0, 3.3, rest=True)
    pink_rgb, cream, line = (236, 150, 204), (244, 222, 188), (214, 184, 150)
    head, R = Vector((0, -0.22, 2.45)), 0.88
    snout = Vector((0, -1.0, 2.12))
    ear, tilt = Vector((1.0, -0.12, 2.9)), 52
    foot = Vector((0.6, -0.54, 0.2))
    tail = spline([(0, 0.78, 0.4), (-0.55, 1.05, 0.3), (-1.02, 0.55, 0.26), (-1.08, -0.15, 0.28), (-0.86, -0.62, 0.4)], [0.36, 0.3, 0.24, 0.18, 0.12], 16)
    frills = []
    for theta, phi, size in ((94, 2, 0.19), (98, -16, 0.18), (102, -34, 0.15)):  # three frills behind each cheek
        for s in (-1, 1):
            d = k.outward(s * theta, phi)
            frills.append(toward(head + Vector((d.x * 0.98, d.y * 0.86, d.z * 0.82)), d + Vector((0, 0.15, 0)), size, (0.55, 0.45, 2.4)))
    spikes = [toward(tail[-1][0] + Vector((0, -0.04, 0.06)), (dx, -0.5, 1), 0.1, (0.6, 0.6, 2.0)) for dx in (-0.6, 0, 0.6)]
    body = k.fuse(
        [
            (head, R, (1.15, 0.98, 0.95)),
            *k.pair((0.5, -0.56, 2.18), 0.4, (1.0, 0.85, 0.8)),  # full cheeks
            (snout, 0.24, (1.3, 0.9, 0.78)),  # small muzzle
            ((0, -0.02, 1.25), 0.6, (1.0, 0.95, 1.12)),  # chest
            ((0, 0.14, 0.56), 0.84, (1.18, 1.1, 0.7)),  # broad seat
            *k.pair((0.56, -0.08, 0.5), 0.42, (0.9, 1.15, 0.85)),  # haunches
            *k.pair(ear, 0.58, (0.5, 0.24, 1.0), (0, tilt, 0)),  # big pointed ears, up and out
            ("capsule", (0.62, -0.18, 1.48), (0.36, -0.62, 1.12), 0.17),  # arms, paws to the chest
            ("capsule", (-0.62, -0.18, 1.48), (-0.36, -0.62, 1.12), 0.17),
            *k.pair((0.33, -0.66, 1.1), 0.17, (1.0, 1.0, 0.9)),
            *k.pair(tuple(foot), 0.27, (1.0, 1.35, 0.75)),  # big feet, soles forward
            *capsules(tail),
            *spikes,
        ],
        skin,
        tris=2650,
    )
    k.zone(skin, cream, (0, -0.62, 0.95), (0.46, 0.4, 0.7), soft=0.08)  # cream belly
    for z in (0.62, 0.9, 1.18, 1.46):  # plate lines across it
        k.zone(skin, line, (0, -0.7, z), (0.44, 0.3, 0.022), soft=0.4)
    for s in (-1, 1):
        k.zone(skin, pink_rgb, (s * foot.x, foot.y - 0.3, foot.z + 0.02), (0.2, 0.12, 0.15), soft=0.15)  # sole pad
        for dx, dz in ((-0.14, 0.16), (0, 0.2), (0.14, 0.16)):  # toe beans
            k.zone(skin, pink_rgb, (s * foot.x + dx, foot.y - 0.28, foot.z + dz), (0.06, 0.1, 0.055), soft=0.2)
    k.zone(skin, pink_rgb, tail[-1][0] + Vector((0, -0.04, 0.3)), (0.3, 0.3, 0.2), soft=0.25)  # pink tail spikes
    parts = [body]
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    for s in (-1, 1):
        parts.append(k.lens(body, (s * ear.x, ear.y, ear.z), (0, -1, 0.3), 0.5, k.flat((244, 168, 196)), scale=(0.38, 1), thick=0.2, sink=0.6, up=(s * axis.x, 0, axis.z), name="ear_in"))
    # Horns: big, rising and curving out, pink at the tips; a nub in the middle and two behind.
    horn_m = k.paint("dr_horn", [(0, (176, 112, 204)), (0.45, (220, 128, 196)), (1, (244, 166, 204))], 3.0, 3.6, rest=True)
    horns = []
    for s in (-1, 1):
        horns += capsules(spline([(s * 0.36, -0.2, 3.0), (s * 0.44, -0.12, 3.32), (s * 0.62, 0.02, 3.52), (s * 0.82, 0.16, 3.6)], [0.21, 0.18, 0.14, 0.1], 12))
        horns.append(toward((s * 0.3, 0.42, 3.1), (s * 0.2, 0.5, 1), 0.1, (0.7, 0.7, 1.5)))
    horns.append(toward((0, -0.42, 3.16), (0, -0.25, 1), 0.11, (0.7, 0.7, 1.5)))
    parts.append(k.fuse(horns, horn_m, tris=560, soft=0.2, name="horns"))
    parts.append(k.fuse(frills, k.flat((186, 128, 224)), tris=420, soft=0.2, name="frills"))
    # Small bat wings on the back: two rounded vanes a side.
    wing = k.flat((190, 140, 222))
    for s in (-1, 1):
        for length, width, pitch, yaw in ((1.15, 0.4, 42, 28), (0.95, 0.34, 10, 40)):
            parts += k.texel(xf(petal(length, width, wing, droop=0.12, tip=0.8, base=0.5, n=8, steps=8), (0.36, 0.52, 1.5), yaw=yaw, pitch=pitch, roll=90, mirror=s < 0), 0.5)
    # Cherry blossoms at the horn bases.
    blossom, heart = k.flat((250, 176, 200)), k.flat((236, 112, 150))
    for s in (-1, 1):
        parts += onto([disc(0.24, lambda a: 0.6 + 0.4 * abs(math.cos(2.5 * a)) ** 0.6, blossom, heart=heart, n=25, cup=0.3, thick=0.16, hr=0.3, dome=0.15)], body, head, k.outward(s * 26, 50))
    # Crescent moon on the forehead: a tapered arc on the surface, horns up.
    f = k.outward(0, 28)
    pts, radii = [], []
    for i in range(11):
        t = i / 10 * 2 - 1
        a = math.radians(125 * t)
        p, n = k.land(body, head, f + Vector((0.24 * math.sin(a), 0, -0.24 * math.cos(a))))
        r = 0.02 + 0.06 * (1 - t * t) ** 0.6
        pts.append(p + n * r * 0.3)
        radii.append(r)
    parts.append(k.tube(pts, radii, m=k.flat((252, 248, 250)), n=6, name="crescent"))
    ink = k.flat((70, 50, 80))
    face = [parts[-1]] + [k.lens(body, snout, k.outward(s * 18, 12), 0.04, ink, scale=(0.8, 1.2), thick=0.5, sink=0.5, seg=12, name="nostril") for s in (-1, 1)]
    face.append(k.mouth(body, snout, k.outward(0, -26), 0.13, k.flat(k.INKY), "w"))
    parts += k.texel(face[1:], k.FACE_TEXEL)
    k.texel(face[0], k.FACE_TEXEL)
    parts += k.face(body, head, R, skin=lilac_rgb, nose=None, mouth_kind=None, eye_r=0.3, eye_wide=0.9, spread=30, eye_phi=-10, sheen=True, blush_theta=46, blush_phi=-24)
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
            ("frog", "Toadstool Frog", creature_frog, [3.8, 3.5, 3.7]),
            ("pup", "Bumble Pup", creature_pup, [3.3, 3.8, 3.4]),
            ("cat", "Berry Cat", creature_cat, [3.4, 4.2, 2.6]),
            ("owl", "Pumpkin Owl", creature_owl, [3.99, 4.5, 2.9]),
            ("fox", "Cactus Fox", creature_fox, [3.6, 4.5, 2.9]),
            ("turtle", "Lotus Turtle", creature_turtle, [2.83, 3.5, 3.16]),
            ("lion", "Sunflower Lion", creature_lion, [4.83, 5.2, 3.76]),
            ("dragon", "Moonblossom Dragon", creature_dragon, [4.38, 5.5, 3.83]),
        ),
        20,
    )
]
