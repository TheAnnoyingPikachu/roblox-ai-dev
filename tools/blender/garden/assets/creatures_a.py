"""The nine Egg Garden creatures as chibi toys: a head near half the height, big round eyes with a
glint, pink cheeks, rounded limbs and one theme prop each. One mesh per creature, standing on the
origin, facing Blender -Y. Replaces the Roblox-generated meshes in src/relay/Models.luau MESHES."""

import math

import kit as k
from mathutils import Matrix, Vector

INK = (60, 45, 55)
WHITE = k.SNOW
PINK = (255, 170, 195)


# Helpers --------------------------------------------------------------------------------------


def ball(r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), seg=14, rings=9, name="ball"):
    return k.sphere(r, loc, rot=rot, m=m, scale=scale, seg=seg, rings=rings, name=name)


def small(r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), name="small"):
    return ball(r, loc, m, scale=scale, rot=rot, seg=8, rings=5, name=name)


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


def on(head, d, depth=0.0):
    """Point on a scaled sphere (centre, r, scale) along direction d, `depth` studs inward."""
    c, r, s = head
    d = Vector(d).normalized()
    return Vector(c) + Vector((d.x * s[0], d.y * s[1], d.z * s[2])) * r - d * depth


def eyeball(c, d, r, white, ink, drop=0.0):
    d = Vector(d).normalized()
    pupil = Vector(c) + d * r * 0.55 + Vector((0, 0, -drop * r))
    return [
        ball(r, c, white, seg=10, rings=6, name="eye"),
        ball(r * 0.62, pupil, ink, seg=8, rings=5, name="pupil"),
        ball(r * 0.2, pupil + d * r * 0.58 + Vector((-r * 0.18, 0, r * 0.22)), white, seg=5, rings=3, name="glint"),
    ]


def eyes(head, white, ink, r=0.26, spread=0.42, up=0.1, lid=None):
    parts = []
    for side in (-1, 1):
        d = Vector((side * spread, -1, up)).normalized()
        c = on(head, d, r * 0.4)
        parts += eyeball(c, d, r, white, ink, drop=0.15 if lid else 0.0)
        if lid is not None:
            parts.append(ball(r * 1.06, c + Vector((0, 0, r * 0.7)) + d * r * 0.08, lid, seg=10, rings=6, name="lid"))
    return parts


def cheeks(head, pink, spread=0.8, down=-0.3, r=0.2):
    return [ball(r, on(head, (side * spread, -1, down), r * 0.75), pink, seg=8, rings=5, name="cheek") for side in (-1, 1)]


def smile(head, ink, w=0.28, down=-0.42, r=0.04, curve=0.12):
    pts = []
    for i in range(7):
        t = i / 6 * 2 - 1
        pts.append(on(head, (w * t, -1, down - curve * (1 - t * t)), -0.01))
    return k.tube(pts, r, m=ink, n=4, name="smile")


def paws(m, x, y_front, y_back, r=0.32, back_r=None, scale=(1, 1.25, 0.8), seg=10, rings=6):
    back_r = back_r or r
    parts = []
    for side in (-1, 1):
        parts.append(ball(r, (side * x, y_front, r * scale[2]), m, scale=scale, seg=seg, rings=rings, name="paw"))
        parts.append(ball(back_r, (side * x * 1.05, y_back, back_r * scale[2]), m, scale=scale, seg=seg, rings=rings, name="paw"))
    return parts


def cone_ears(x, y, z, r, h, m, inner=None, tilt=16.0, lean=0.0):
    parts = []
    for side in (-1, 1):
        rot = (lean, side * tilt, 0)
        parts.append(k.cyl(r, h, (side * x, y, z), rot=rot, m=m, n=8, r2=0, name="ear"))
        if inner is not None:
            parts.append(k.cyl(r * 0.6, h * 0.72, (side * x, y - r * 0.5, z - h * 0.06), rot=rot, m=inner, n=8, r2=0, name="ear_in"))
    return parts


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
    fur = k.paint("bu_fur", [(0, (238, 220, 188)), (1, (255, 246, 226))], 0, 3.2)
    pink, ink, white = k.flat(PINK), k.flat(INK), k.flat(WHITE)
    green, green_hi = k.flat((110, 200, 95)), k.flat((150, 225, 110))
    head = ((0, -0.15, 2.2), 1.0, (1.05, 0.95, 0.95))
    parts = [ball(1.0, (0, 0.1, 1.05), fur, scale=(1.05, 1.0, 0.95), name="body"), ball(head[1], head[0], fur, scale=head[2], name="head")]
    for side in (-1, 1):
        rot = (0, side * 14, 0)
        parts.append(ball(0.68, (side * 0.42, -0.05, 3.4), fur, scale=(0.42, 0.22, 1.0), rot=rot, seg=12, rings=7, name="ear"))
        parts.append(small(0.68, (side * 0.42, -0.19, 3.4), pink, scale=(0.25, 0.1, 0.74), rot=rot, name="ear_in"))
    parts.append(k.tube([(0, -0.1, 3.0), (0.03, -0.12, 3.32), (0.08, -0.15, 3.58)], [0.08, 0.06, 0.05], m=green, n=6, name="stem"))
    parts += xf(k.leaf(0.62, 0.22, green_hi, droop=0.3, n=5, steps=4), (0.08, -0.15, 3.52), yaw=20, pitch=25)
    parts += xf(k.leaf(0.5, 0.19, green, droop=0.3, n=5, steps=4), (0.08, -0.15, 3.52), yaw=200, pitch=30)
    parts.append(k.puff(0.32, (0, 1.05, 1.0), white, name="tail"))
    parts += paws(fur, 0.5, -0.7, 0.3, 0.3, back_r=0.4, scale=(1, 1.5, 0.75))
    parts += eyes(head, white, ink, r=0.27, spread=0.42, up=0.08)
    parts.append(small(0.09, on(head, (0, -1, -0.12)), pink, scale=(1.3, 1, 0.8), name="nose"))
    parts.append(smile(head, ink, w=0.16, down=-0.3, curve=0.06, r=0.03))
    parts += cheeks(head, pink)
    return parts


def creature_frog():
    skin = k.paint("fr_skin", [(0, (235, 250, 225)), (0.55, (150, 222, 165)), (1, (125, 208, 148))], -1.1, 0.2, axis="Y")
    cap = k.paint("fr_cap", [(0, (232, 70, 78)), (1, (240, 85, 90))], 2.3, 3.5, dots=[((255, 250, 240), 1.7, 0.3)])
    pink, ink, white = k.flat((255, 180, 200)), k.flat(INK), k.flat(WHITE)
    body = ((0, 0, 1.2), 1.35, (1.1, 1.0, 0.85))
    parts = [ball(body[1], body[0], skin, scale=body[2], seg=16, rings=10, name="body")]
    for side in (-1, 1):
        parts += eyeball((side * 0.62, -0.82, 2.2), (side * 0.12, -1, 0.1), 0.42, white, ink)
    parts.append(
        k.lathe(
            [(0.55, 0), (1.1, 0), (1.14, 0.14), (0.9, 0.44), (0.42, 0.68), (0, 0.76)],
            loc=(0, 0.28, 2.32),
            rot=(-9, 0, 0),
            m=cap,
            n=14,
            name="cap",
        )
    )
    for side in (-1, 1):
        parts.append(small(0.3, (side * 0.78, -1.0, 0.24), skin, scale=(1, 1.3, 0.7), name="arm"))
        parts.append(small(0.5, (side * 1.22, 0.35, 0.5), skin, scale=(0.8, 1.2, 0.9), name="leg"))
        parts.append(small(0.32, (side * 1.28, -0.35, 0.2), skin, scale=(1, 1.5, 0.6), name="foot"))
    parts.append(smile(body, ink, w=0.42, down=0.28, curve=0.14, r=0.045))
    parts += cheeks(body, pink, spread=0.95, down=0.1, r=0.22)
    return parts


def creature_pup():
    gold = k.paint("pu_fur", [(0, (238, 182, 88)), (1, (255, 212, 120))], 0, 3.5)
    stripes = k.paint("pu_stripes", [(0, (250, 200, 105)), (1, (250, 200, 105))], 0, 1, axis="Y", bands=((82, 60, 50), 0.7))
    dark = k.flat((215, 150, 70))
    cream, ink, white, pink, wing = k.flat((255, 240, 210)), k.flat(INK), k.flat(WHITE), k.flat(PINK), k.flat((226, 240, 255))
    body = ((0, 0.35, 1.15), 1.05, (1.15, 1.2, 0.95))
    head = ((0, -0.8, 2.45), 1.05, (1.1, 1.0, 1.0))
    parts = [ball(body[1], body[0], gold, scale=body[2], name="body"), ball(head[1], head[0], gold, scale=head[2], name="head")]

    # Bee saddle: a thin shell over the back, banded across Y.
    c, r, s = body

    def saddle(u, v):
        a = math.radians(-95 + 190 * u)
        y = 0.1 + 1.65 * v
        f = math.sqrt(max(0.0, 1 - ((y - c[1]) / (r * s[1])) ** 2))
        return (r * s[0] * f * math.sin(a) * 1.015, y, c[2] + r * s[2] * f * math.cos(a) * 1.015)

    parts.append(k.surface(16, 8, saddle, m=stripes, name="saddle"))
    for side in (-1, 1):
        parts.append(ball(0.45, (side * 1.05, -0.8, 2.0), dark, scale=(0.45, 0.8, 1.45), rot=(0, side * 8, 0), seg=12, rings=7, name="ear"))
        for length, width, pitch, yaw in ((1.5, 0.6, 50, 10), (1.1, 0.5, 15, 16)):
            parts += xf(k.leaf(length, width, wing, droop=0.15, n=5, steps=4), (0.45, 0.6, 2.1), yaw=yaw, pitch=pitch, roll=90, mirror=side < 0)
    muzzle = ((0, -1.75, 2.2), 0.48, (1.25, 0.8, 0.75))
    parts.append(ball(muzzle[1], muzzle[0], cream, scale=muzzle[2], seg=12, rings=7, name="muzzle"))
    parts.append(small(0.17, (0, -2.1, 2.36), ink, scale=(1.2, 0.8, 0.8), name="nose"))
    parts.append(smile(muzzle, ink, w=0.6, down=-0.45, curve=0.2, r=0.035))
    parts.append(k.tube([(0, 1.5, 1.4), (0, 1.85, 1.75), (-0.05, 1.95, 2.15)], [0.16, 0.13, 0.06], m=gold, n=6, name="tail"))
    parts += paws(gold, 0.55, -0.75, 0.95, 0.33)
    parts += eyes(head, white, ink, r=0.26, spread=0.42, up=0.12)
    parts += cheeks(head, pink)
    return parts


def creature_cat():
    red = k.paint("ca_fur", [(0, (222, 58, 84)), (1, (250, 95, 115))], 0, 3.4, dots=[((255, 226, 190), 4, 0.3)])
    pink, ink, white, cream = k.flat(PINK), k.flat(INK), k.flat(WHITE), k.flat((255, 240, 220))
    greens = [k.flat((100, 190, 90)), k.flat((135, 215, 100))]
    body = ((0, 0.1, 1.1), 1.0, (1.0, 1.05, 0.95))
    head = ((0, -0.25, 2.5), 1.05, (1.08, 0.95, 0.95))
    parts = [ball(body[1], body[0], red, scale=body[2], name="body"), ball(head[1], head[0], red, scale=head[2], name="head")]
    parts += cone_ears(0.62, -0.15, 3.55, 0.4, 0.85, red, inner=pink, tilt=18)
    muzzle = ((0, -1.1, 2.3), 0.4, (1.4, 0.7, 0.7))
    parts.append(ball(muzzle[1], muzzle[0], cream, scale=muzzle[2], seg=12, rings=7, name="muzzle"))
    parts.append(small(0.1, (0, -1.38, 2.42), pink, scale=(1.3, 0.8, 0.8), name="nose"))
    parts.append(smile(muzzle, ink, w=0.5, down=-0.4, curve=0.2, r=0.03))
    for i in range(7):
        yaw = i * 360 / 7 - 90
        a = math.radians(yaw)
        parts += xf(k.leaf(0.78, 0.34, greens[i % 2], droop=0.1, n=5, steps=4), (0.5 * math.cos(a), -0.05 + 0.5 * math.sin(a), 1.85), yaw=yaw, pitch=-22)
    centre = Vector((0.25, 1.45, 1.55))
    pts, radii = [], []
    for i in range(10):
        t = i / 9
        a = math.radians(-90 + 300 * t)
        rr = 0.62 - 0.3 * t
        pts.append(centre + Vector((0, rr * math.cos(a), rr * math.sin(a))))
        radii.append(0.2 - 0.08 * t)
    parts.append(k.tube(pts, radii, m=red, n=7, name="tail"))
    parts += paws(red, 0.52, -0.65, 0.6, 0.3)
    parts += eyes(head, white, ink, r=0.27, spread=0.42, up=0.1)
    parts += cheeks(head, pink)
    return parts


def creature_owl():
    orange = k.paint("ow_body", [(0, (232, 118, 45)), (0.5, (255, 160, 70)), (1, (255, 186, 98))], 0, 3.6)
    face, amber, ink, white = k.flat((255, 240, 212)), k.flat((255, 190, 60)), k.flat(INK), k.flat(WHITE)
    beak, brown, green, pink = k.flat((240, 150, 50)), k.flat((120, 80, 50)), k.flat((120, 200, 95)), k.flat(PINK)
    R, cz = 1.75, 1.9

    def pumpkin(u, v):
        t, p = 2 * math.pi * u, math.pi * v
        r = R * (1 + 0.09 * math.cos(8 * t) * math.sin(p)) * math.sin(p)
        return (r * math.cos(t), r * math.sin(t) * 0.9, cz + R * 0.92 * math.cos(p))

    parts = [k.surface(32, 12, pumpkin, m=orange, name="body")]
    for side in (-1, 1):
        parts.append(ball(0.8, (side * 0.6, -1.42, 2.25), face, scale=(1, 0.32, 0.95), seg=12, rings=7, name="disc"))
        parts += eyeball((side * 0.58, -1.6, 2.3), (side * 0.05, -1, 0.05), 0.45, amber, ink)
        parts.append(k.cyl(0.32, 0.6, (side * 0.85, 0.1, 3.5), rot=(0, side * 25, 0), m=orange, n=8, r2=0, name="tuft"))
        parts.append(ball(0.75, (side * 1.62, 0.15, 1.85), orange, scale=(0.35, 0.75, 1.0), rot=(0, side * 10, 0), seg=12, rings=7, name="wing"))
        parts.append(small(0.25, (side * 0.5, -1.1, 0.15), beak, scale=(1, 1.6, 0.6), name="foot"))
    parts.append(ball(0.95, (0, -1.3, 1.3), face, scale=(1, 0.3, 1.0), seg=12, rings=7, name="belly"))
    parts.append(k.cyl(0.16, 0.42, (0, -1.78, 1.92), rot=(101, 0, 0), m=beak, n=8, r2=0, name="beak"))
    parts.append(k.tube([(0, 0.15, 3.4), (0.05, 0.1, 3.75), (0.18, 0.0, 4.0)], [0.2, 0.15, 0.13], m=brown, n=7, name="stem"))
    parts += xf(k.leaf(0.7, 0.28, green, droop=0.25, n=5, steps=4), (0.05, 0.1, 3.7), yaw=150, pitch=15)
    parts += cheeks(((0, 0, cz), R, (1, 0.9, 0.92)), pink, spread=0.75, down=-0.05, r=0.2)
    return parts


def creature_fox():
    green = k.paint("fx_fur", [(0, (225, 245, 205)), (0.45, (120, 185, 115)), (1, (100, 170, 105))], -1.0, 0.3, axis="Y")
    plain, pale = k.flat((110, 178, 110)), k.flat((232, 250, 215))
    cream, ink, white, pink = k.flat((245, 250, 225)), k.flat(INK), k.flat(WHITE), k.flat(PINK)
    body = ((0, 0.15, 1.2), 1.05, (1.0, 1.2, 0.95))
    head = ((0, -0.75, 2.6), 1.1, (1.0, 1.0, 0.92))
    parts = [ball(body[1], body[0], green, scale=body[2], name="body"), ball(head[1], head[0], plain, scale=head[2], name="head")]
    parts += cone_ears(0.72, -0.5, 3.75, 0.5, 1.2, plain, inner=pink, tilt=22)
    for side in (-1, 1):
        parts.append(ball(0.45, on(head, (side, -0.55, -0.3), 0.2), cream, scale=(0.55, 0.85, 0.75), seg=10, rings=6, name="ruff"))
    muzzle = ((0, -1.8, 2.3), 0.5, (1.0, 1.3, 0.7))
    parts.append(ball(muzzle[1], muzzle[0], cream, scale=muzzle[2], seg=12, rings=7, name="muzzle"))
    parts.append(small(0.15, (0, -2.42, 2.4), ink, scale=(1.2, 0.8, 0.8), name="nose"))
    parts.append(smile(muzzle, ink, w=0.5, down=-0.45, curve=0.2, r=0.03))
    # The bushy tail swings out to the left, so it shows in the silhouette from the front.
    tail = [Vector(p) for p in ((-0.3, 1.1, 0.9), (-0.95, 1.6, 1.2), (-1.35, 1.5, 1.9), (-1.4, 1.2, 2.5))]
    parts.append(k.tube(tail, [0.25, 0.5, 0.58, 0.3], m=plain, n=9, name="tail"))
    parts.append(ball(0.45, tail[-1] + Vector((0, 0, 0.12)), cream, seg=12, rings=7, name="tail_tip"))
    # Soft spine studs down the back and the tail.
    c, r, s = body
    studs = [(0, c[1] + r * s[1] * math.sin(math.radians(a)), c[2] + r * s[2] * math.cos(math.radians(a))) for a in (-30, -5, 20, 45, 70)]
    studs += [on(head, (0, -0.1, 1)), on(head, (0, -0.45, 1))]
    studs += [Vector(p) + Vector(out) for p, out in ((tail[1], (-0.1, 0.5, -0.1)), (tail[2], (-0.1, 0.56, 0)), ((-1.4, 1.35, 2.2), (0, 0.42, 0.1)))]
    for p in studs:
        parts.append(ball(0.12, p, pale, scale=(1, 1, 0.8), seg=6, rings=3, name="stud"))
    d = Vector((0.72, -0.4, 0.72)).normalized()
    bloom = k.flower(0.34, k.flat((255, 140, 180)), k.flat(k.SUNNY), lobes=6)
    place = Matrix.Translation(on(head, d, -0.02)) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
    for ob in bloom:
        ob.data.transform(place)
    parts += bloom
    parts += paws(plain, 0.55, -0.75, 0.8, 0.32, seg=8, rings=5)
    parts += eyes(head, white, ink, r=0.27, spread=0.42, up=0.1)
    parts += cheeks(head, pink)
    return parts


def creature_turtle():
    teal = k.paint("tu_skin", [(0, (105, 200, 190)), (1, (150, 228, 215))], 0, 2.4)
    pink, pink_hi, cream, yellow = k.flat((255, 160, 192)), k.flat((255, 200, 222)), k.flat((255, 245, 220)), k.flat((255, 215, 110))
    ink, white, blush = k.flat(INK), k.flat(WHITE), k.flat(PINK)
    body = ((0, 0.1, 0.95), 1.15, (1.0, 1.05, 0.8))
    head = ((0, -1.55, 1.35), 0.85, (1.0, 1.0, 0.95))
    parts = [ball(body[1], body[0], teal, scale=body[2], name="body"), ball(head[1], head[0], teal, scale=head[2], name="head")]
    for i in range(8):
        yaw = i * 45 + 22.5
        a = math.radians(yaw)
        parts += xf(k.leaf(1.4, 0.62, pink, droop=0.35, n=5, steps=4), (0.4 * math.cos(a), 0.1 + 0.4 * math.sin(a), 1.5), yaw=yaw, pitch=38)
    for i in range(5):
        yaw = i * 72 + 90
        a = math.radians(yaw)
        parts += xf(k.leaf(1.15, 0.52, pink_hi, droop=0.35, n=5, steps=4), (0.2 * math.cos(a), 0.1 + 0.2 * math.sin(a), 1.65), yaw=yaw, pitch=62)
    parts.append(k.lathe([(0.5, 0), (0.46, 0.4), (0.28, 0.72), (0, 0.85)], loc=(0, 0.1, 1.55), m=cream, n=12, name="heart"))
    parts.append(small(0.18, (0, 0.1, 2.42), yellow, name="bud"))
    for side in (-1, 1):
        for y in (-0.85, 0.95):
            parts.append(small(0.38, (side * 0.98, y, 0.3), teal, scale=(1, 1.1, 0.8), name="leg"))
    parts.append(k.cyl(0.16, 0.5, (0, 1.35, 0.5), rot=(-100, 0, 0), m=teal, n=8, r2=0, name="tail"))
    parts += eyes(head, white, ink, r=0.23, spread=0.5, up=0.05, lid=teal)
    parts.append(smile(head, ink, w=0.3, down=-0.3, curve=0.1, r=0.03))
    parts += cheeks(head, blush, spread=0.85, down=-0.2, r=0.17)
    return parts


def creature_lion():
    gold = k.paint("li_fur", [(0, (235, 175, 80)), (1, (255, 212, 112))], 0, 4.5)
    petals = [k.flat((255, 205, 60)), k.flat((255, 225, 100))]
    seed = k.paint("li_seed", [(0, (100, 65, 45)), (1, (100, 65, 45))], 0, 1, dots=[((138, 96, 66), 9, 0.35)])
    cream, brown, ink, white, pink = k.flat((255, 240, 212)), k.flat((110, 72, 50)), k.flat(INK), k.flat(WHITE), k.flat(PINK)
    body = ((0, 0.2, 1.3), 1.15, (1.0, 1.2, 0.95))
    head = ((0, -0.6, 3.0), 1.25, (1.05, 0.95, 0.95))
    parts = [ball(body[1], body[0], gold, scale=body[2], name="body"), ball(head[1], head[0], gold, scale=head[2], name="head")]
    ruff = k.ring(1.45, 0, 0.3, seed, n=16, sides=5, name="ruff")
    ruff.data.transform(Matrix.Translation((0, -0.15, 3.0)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    parts.append(ruff)
    for i in range(14):
        a = i * 360 / 14 + 90 / 7
        rad = math.radians(a)
        petal = k.leaf(1.15, 0.42, petals[i % 2], droop=0.05, n=4, steps=3)
        petal.data.transform(Matrix.Translation((1.25 * math.cos(rad), -0.05, 3.0 + 1.25 * math.sin(rad))) @ Matrix.Rotation(math.radians(-a), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "X"))
        parts.append(petal)
    for side in (-1, 1):
        parts.append(ball(0.3, (side * 0.85, -0.55, 3.95), gold, seg=7, rings=4, name="ear"))
        parts.append(ball(0.18, (side * 0.85, -0.72, 3.95), pink, seg=6, rings=4, name="ear_in"))
    muzzle = ((0, -1.65, 2.75), 0.5, (1.4, 0.8, 0.7))
    parts.append(ball(muzzle[1], muzzle[0], cream, scale=muzzle[2], seg=12, rings=7, name="muzzle"))
    parts.append(small(0.16, (0, -1.98, 2.88), brown, scale=(1.3, 0.8, 0.8), name="nose"))
    parts.append(smile(muzzle, ink, w=0.55, down=-0.45, curve=0.2, r=0.035))
    parts.append(k.tube([(0, 1.5, 1.3), (0.1, 2.0, 1.6), (0.1, 2.2, 2.1)], [0.14, 0.1, 0.08], m=gold, n=6, name="tail"))
    parts.append(k.puff(0.26, (0.1, 2.2, 2.22), brown, name="tuft"))
    parts += paws(gold, 0.65, -0.85, 1.0, 0.38, seg=8, rings=5)
    parts += eyes(head, white, ink, r=0.3, spread=0.4, up=0.1)
    parts += cheeks(head, pink, r=0.22)
    return parts


def creature_dragon():
    lilac = k.paint("dr_skin", [(0, (192, 166, 238)), (1, (222, 202, 255))], 0, 4.8)
    belly, petal, vein = k.flat((246, 236, 255)), k.flat((255, 252, 255)), k.flat((196, 164, 238))
    horn, moon, ink, white, pink = k.flat((255, 240, 210)), k.flat((255, 240, 170)), k.flat(INK), k.flat(WHITE), k.flat((255, 180, 205))
    body = ((0, 0.3, 1.5), 1.3, (1.0, 1.25, 1.0))
    head = ((0, -0.9, 3.3), 1.4, (1.05, 1.0, 0.95))
    parts = [ball(body[1], body[0], lilac, scale=body[2], name="body"), ball(head[1], head[0], lilac, scale=head[2], name="head")]
    snout = ((0, -2.1, 2.95), 0.6, (1.3, 0.8, 0.7))
    parts.append(ball(snout[1], snout[0], lilac, scale=snout[2], seg=12, rings=7, name="snout"))
    for side in (-1, 1):
        parts.append(small(0.07, on(snout, (side * 0.4, -1, 0.3)), ink, name="nostril"))
        parts.append(k.cyl(0.24, 0.65, (side * 0.62, -0.75, 4.55), rot=(-15, side * 25, 0), m=horn, n=8, r2=0, name="horn"))
        for length, width, pitch, yaw in ((2.4, 0.9, 35, 10), (2.1, 0.8, 8, 18), (1.8, 0.7, -18, 24)):
            wing = k.leaf(length, width, petal, droop=0.1, n=5, steps=4)
            rib = k.tube([(length * s, 0, length * 0.1 * math.sin(s * math.pi * 0.8) + width * 0.3 * math.sin(s * math.pi) ** 0.7) for s in (0.1, 0.4, 0.7, 0.92)], [0.045, 0.04, 0.03, 0.02], m=vein, n=3, name="vein")
            parts += xf([wing, rib], (0.5, 0.55, 2.5), yaw=yaw, pitch=pitch, roll=90, mirror=side < 0)
    parts.append(smile(snout, ink, w=0.6, down=-0.4, curve=0.2, r=0.035))
    # Crescent moon on the forehead: a tapered arc, horns up.
    f = Vector((0, -1, 0.5)).normalized()
    pts, radii = [], []
    for i in range(9):
        t = i / 8 * 2 - 1
        a = math.radians(125 * t)
        pts.append(on(head, f + Vector((0.3 * math.sin(a), 0, -0.3 * math.cos(a))), -0.02))
        radii.append(0.02 + 0.075 * (1 - t * t) ** 0.6)
    parts.append(k.tube(pts, radii, m=moon, n=5, name="crescent"))
    for z in (0.95, 1.45, 1.95):
        parts.append(ball(0.6, on(body, (0, -1, (z - body[0][2]) / (body[1] * body[2][2])), 0.1), belly, scale=(1.2, 0.3, 0.45), seg=8, rings=4, name="plate"))
    centre = Vector((0.3, 2.0, 1.4))
    pts, radii = [], []
    for i in range(11):
        t = i / 10
        a = math.radians(-100 + 300 * t)
        rr = 0.75 - 0.4 * t
        pts.append(centre + Vector((0, rr * math.cos(a), rr * math.sin(a))))
        radii.append(0.3 - 0.2 * t)
    parts.append(k.tube(pts, radii, m=lilac, n=6, name="tail"))
    parts += paws(lilac, 0.65, -0.8, 1.1, 0.4, seg=8, rings=5)
    parts += eyes(head, white, ink, r=0.3, spread=0.4, up=0.1)
    parts += cheeks(head, pink, r=0.22)
    return parts


NOTES = "One mesh (Plots.luau creature through Models.nightPart). Scale to the manifest height. Chibi toy: head near half the height, baked eyes and markings."
ASSETS = [
    dict(name=f"creature_{id}", build=fit(size)(build), budget=2500, size=size, priority=1, order=order, replaces=f"Roblox-generated {label} mesh (src/relay/Models.luau MESHES.{id})", notes=NOTES, glow={})
    for order, (id, label, build, size) in enumerate(
        (
            ("bunny", "Sprout Bunny", creature_bunny, [2.6, 4.0, 2.4]),
            ("frog", "Toadstool Frog", creature_frog, [3.2, 3.5, 3.2]),
            ("pup", "Bumble Pup", creature_pup, [3.0, 3.8, 3.6]),
            ("cat", "Berry Cat", creature_cat, [3.2, 4.2, 3.0]),
            ("owl", "Pumpkin Owl", creature_owl, [4.2, 4.5, 3.8]),
            ("fox", "Cactus Fox", creature_fox, [3.6, 4.5, 4.2]),
            ("turtle", "Lotus Turtle", creature_turtle, [3.8, 3.5, 3.8]),
            ("lion", "Sunflower Lion", creature_lion, [4.6, 5.2, 4.6]),
            ("dragon", "Moonblossom Dragon", creature_dragon, [6.0, 5.5, 4.8]),
        ),
        20,
    )
]
