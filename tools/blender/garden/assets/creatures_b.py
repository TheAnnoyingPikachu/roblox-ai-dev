"""Ten new Egg Garden creatures (batch B): chibi toy animals, one mesh each, standing on the origin
and facing Blender -Y. Eyes and markings are small spheres and discs sitting just proud of the body
or paint() gradients and dots: both bake into the one texture."""

import math

import kit as k
from mathutils import Matrix, Vector

DARK = (48, 40, 56)
WHITE = k.SNOW
CHEEK = (255, 160, 180)


# Helpers -------------------------------------------------------------------------------------


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


def flame(root, tip, r, m, bend=0.3, n=6):
    """Rounded flame tongue from root to tip, bowing sideways by `bend` of its length."""
    root, tip = Vector(root), Vector(tip)
    along = tip - root
    side = along.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side = side.normalized() * along.length * bend
    pts = [root + along * s + side * math.sin(s * math.pi) for s in (0, 0.3, 0.6, 0.85, 1.0)]
    return k.tube(pts, [r * 0.8, r, r * 0.7, r * 0.35, 0], m=m, n=n, name="flame")


# Puddle Duckling (common) ---------------------------------------------------------------------


def creature_duck():
    yellow = k.paint("du_body", [(0, (255, 214, 90)), (1, (255, 238, 140))], 0.2, 3.0)
    wing = k.flat((250, 200, 80))
    orange = k.flat((255, 150, 60))
    water = k.paint("du_water", [(0, (120, 190, 245)), (1, (170, 220, 255))], -1.4, 1.4, axis="Y")
    ripple = k.flat((225, 245, 255))
    pad = k.flat((110, 200, 110))
    bud = k.flat(k.ROSE)

    parts = [
        k.cyl(1.38, 0.1, (0, 0, 0.05), m=water, n=28, name="puddle"),
        k.ring(1.0, 0.1, 0.04, ripple, n=28, sides=4, name="ripple"),
        blob(0.86, (0, 0.05, 1.05), yellow, scale=(1, 1.08, 0.94), seg=16, rings=10, name="body"),
        blob(0.7, (0, -0.2, 2.25), yellow, seg=16, rings=10, name="head"),
        # Bill, feet, wings, a tuft of a tail.
        blob(0.3, (0, -0.82, 2.08), orange, scale=(1.15, 1, 0.42), seg=12, rings=6, name="bill"),
        blob(0.3, (0.38, -0.3, 0.14), orange, scale=(1, 1.45, 0.3), seg=10, rings=5, name="foot"),
        blob(0.3, (-0.38, -0.3, 0.14), orange, scale=(1, 1.45, 0.3), seg=10, rings=5, name="foot"),
        blob(0.34, (0.78, 0.1, 1.1), wing, scale=(0.5, 1.2, 0.9), seg=10, rings=6, name="wing"),
        blob(0.34, (-0.78, 0.1, 1.1), wing, scale=(0.5, 1.2, 0.9), seg=10, rings=6, name="wing"),
        blob(0.26, (0, 0.95, 1.35), wing, scale=(0.8, 1, 0.6), seg=8, rings=5, name="tail"),
    ]
    parts += eyes((0, -0.2, 2.25), 0.7, theta=30, phi=10, r=0.19)
    parts += cheeks((0, -0.2, 2.25), 0.7, theta=52, phi=-8, r=0.14)
    # Lily pad hat: a notched disc, a pink bud at the notch.
    hat = k.lathe([(0, 2.86), (0.5, 2.87), (0.52, 2.93), (0, 2.96)], m=pad, n=16, name="pad")
    hat.data.transform(Matrix.Translation((0, -0.2, 2.9)) @ Matrix.Rotation(math.radians(-10), 4, "X") @ Matrix.Translation((0, 0.2, -2.9)))
    parts.append(hat)
    parts.append(blob(0.14, (0.3, -0.5, 3.02), bud, scale=(1, 1, 1.35), seg=8, rings=6, name="bud"))
    return parts


# Clover Lamb (uncommon) -----------------------------------------------------------------------


def creature_lamb():
    fleece = k.paint("la_fleece", [(0, (240, 228, 205)), (1, (255, 250, 238))], 1.0, 3.7)
    grey = k.flat((170, 168, 185))
    pink = k.flat((255, 150, 175))
    green = k.flat((95, 190, 95))
    green_hi = k.flat((150, 225, 110))

    parts = [blob(0.95, (0, 0.2, 1.6), fleece, scale=(1, 1.15, 0.95), seg=12, rings=8, name="core")]
    for x, y, z, r in (
        (1.05, 0.0, 1.95, 0.55), (-1.05, 0.0, 1.95, 0.55), (0.75, 0.95, 1.85, 0.5), (-0.75, 0.95, 1.85, 0.5),
        (0.0, 1.25, 1.75, 0.52), (0.0, 0.3, 2.45, 0.58), (0.75, 0.7, 2.4, 0.46), (-0.75, 0.7, 2.4, 0.46),
        (0.95, 0.1, 1.15, 0.46), (-0.95, 0.1, 1.15, 0.46),
    ):
        parts.append(k.puff(r, (x, y, z), fleece, scale=(1, 1, 0.85), name="puff"))
    for x, y in ((0.5, -0.45), (-0.5, -0.45), (0.5, 0.75), (-0.5, 0.75)):
        parts += leg(x, y, 0.8, 0.25, grey)
    head = (0, -1.05, 2.45)
    parts.append(blob(0.7, head, grey, scale=(1, 1.05, 1), seg=14, rings=9, name="head"))
    for x, y, z, r in ((0, -0.95, 3.12, 0.46), (0.44, -0.7, 3.0, 0.4), (-0.44, -0.7, 3.0, 0.4)):
        parts.append(k.puff(r, (x, y, z), fleece, scale=(1, 1, 0.8), name="cap"))
    parts.append(blob(0.3, (0.78, -0.95, 2.4), grey, scale=(1, 0.5, 0.55), seg=8, rings=5, name="ear"))
    parts.append(blob(0.3, (-0.78, -0.95, 2.4), grey, scale=(1, 0.5, 0.55), seg=8, rings=5, name="ear"))
    parts.append(stud(head, 0.7, 0, -22, 0.15, pink, flat=0.6, scale=(1, 1.05, 1), name="nose"))
    parts += eyes(head, 0.7, theta=30, phi=8, r=0.21, scale=(1, 1.05, 1))
    parts += cheeks(head, 0.7, theta=52, phi=-10, r=0.15, scale=(1, 1.05, 1))
    # Four-leaf clovers tucked in the fleece (heart the same green, so the lobes read as leaves).
    for loc, direction in (((1.0, 0.05, 2.5), (0.6, -0.1, 1)), ((-0.85, 0.6, 2.75), (-0.5, 0, 1)), ((0.0, -0.9, 3.5), (0, -0.2, 1))):
        parts += aim(k.flower(0.34, green, green, lobes=4), loc, direction)
    return parts


# Acorn Hedgehog (rare) ------------------------------------------------------------------------


def creature_hedgehog():
    brown = k.paint("hh_quill", [(0, (150, 100, 70)), (1, (190, 135, 90))], 1.0, 2.4)
    quill = k.flat((125, 82, 58))
    cream = k.flat((255, 236, 205))
    cap = k.paint("hh_cap", [(0, (165, 110, 65)), (1, (165, 110, 65))], 0, 1, dots=[((130, 85, 50), 7, 0.3)])
    stalk = k.flat((120, 80, 50))

    body = (0, 0.15, 1.1)
    parts = [blob(1.0, body, brown, scale=(1.42, 1.35, 1.02), seg=14, rings=9, name="body")]
    for theta, phi, r in (
        (0, 74, 0.38), (45, 58, 0.36), (-45, 58, 0.36), (85, 38, 0.36), (-85, 38, 0.36), (125, 50, 0.36), (-125, 50, 0.36),
        (165, 30, 0.38), (-165, 30, 0.38), (180, 66, 0.36),
    ):
        d = outward(theta, phi)
        p = Vector(body) + Vector((d.x * 1.42, d.y * 1.35, d.z * 1.02)) * 0.9
        parts.append(k.puff(r, p, quill, scale=(1, 1, 1), name="quill"))
    face = (0, -1.1, 0.98)
    parts.append(blob(0.66, face, cream, scale=(1, 1.25, 0.95), seg=14, rings=9, name="face"))
    parts.append(blob(0.55, (0, -0.5, 0.55), cream, scale=(1.1, 1.1, 0.8), seg=10, rings=6, name="belly"))
    parts.append(stud(face, 0.66, 0, -8, 0.16, k.flat(DARK), lift=0.02, flat=0.8, scale=(1, 1.25, 0.95), name="nose"))
    parts += eyes(face, 0.66, theta=30, phi=18, r=0.19, scale=(1, 1.25, 0.95))
    parts += cheeks(face, 0.66, theta=46, phi=-4, r=0.15, scale=(1, 1.25, 0.95))
    for s in (1, -1):
        parts.append(blob(0.2, (s * 0.6, -0.95, 1.55), cream, scale=(1, 0.5, 1), seg=8, rings=4, name="ear"))
    for x, y in ((0.55, -0.9), (-0.55, -0.9), (0.6, 0.9), (-0.6, 0.9)):
        parts.append(blob(0.24, (x, y, 0.12), cream, scale=(1, 1.3, 0.5), seg=8, rings=4, name="foot"))
    # Acorn cap worn like a beret, tipped to one side.
    beret = [
        k.lathe([(0.0, -0.05), (0.62, -0.02), (0.64, 0.12), (0.5, 0.3), (0.2, 0.42), (0, 0.44)], m=cap, n=16, name="beret"),
        k.tube([(0, 0, 0.4), (0.08, 0.02, 0.6), (0.22, 0.05, 0.74)], [0.1, 0.08, 0.05], m=stalk, n=6, name="stalk"),
    ]
    parts += aim(beret, (0.15, -0.7, 2.05), (0.3, -0.35, 1))
    return parts


# Blossom Fawn (epic) --------------------------------------------------------------------------


def creature_deer():
    tan = k.paint("de_coat", [(0, (255, 232, 200)), (0.4, (236, 180, 120)), (1, (226, 165, 105))], 1.6, 3.2)
    hoof = k.flat((120, 85, 70))
    cream = k.flat((255, 244, 222))
    pink = k.flat(k.BLUSH)
    rose = k.flat(k.ROSE)
    sun = k.flat(k.SUNNY)

    parts = []
    for x, y in ((0.48, -0.6), (-0.48, -0.6), (0.48, 0.8), (-0.48, 0.8)):
        parts += leg(x, y, 1.3, 0.21, tan, hoof=hoof, hoof_h=0.3)
    body = (0, 0.15, 2.2)
    parts.append(blob(0.98, body, tan, scale=(1.05, 1.45, 1), seg=14, rings=9, name="body"))
    parts.append(k.tube([(0, -0.5, 2.6), (0, -0.6, 3.2), (0, -0.6, 3.6)], 0.42, m=tan, n=10, name="neck"))
    head = (0, -0.55, 3.95)
    parts.append(blob(0.82, head, tan, seg=14, rings=9, name="head"))
    parts.append(blob(0.42, (0, -1.22, 3.62), cream, scale=(1.1, 1, 0.8), seg=10, rings=6, name="muzzle"))
    parts.append(k.sphere(0.14, (0, -1.58, 3.68), m=k.flat(DARK), scale=(1.2, 0.7, 0.8), seg=8, rings=5, name="nose"))
    parts += eyes(head, 0.82, theta=30, phi=6, r=0.24)
    parts += cheeks(head, 0.82, theta=50, phi=-14, r=0.16)
    for s in (1, -1):
        parts.append(blob(0.42, (s * 1.35, -0.35, 4.25), tan, scale=(1, 0.45, 0.62), rot=(0, s * 25, 0), seg=10, rings=6, name="ear"))
        parts.append(blob(0.26, (s * 1.35, -0.48, 4.25), pink, scale=(1, 0.3, 0.62), rot=(0, s * 25, 0), seg=8, rings=4, name="ear_in"))
        # Antler nubs with a pink blossom on each tip.
        tip = Vector((s * 0.35, -0.35, 5.0))
        parts.append(k.tube([(s * 0.3, -0.4, 4.6), tip], [0.12, 0.09], m=hoof, n=6, name="nub"))
        parts += aim(k.flower(0.26, rose, sun, lobes=5), tip, (s * 0.3, -0.3, 1))
    # Cherry blossom spots across the back, a white tail.
    for theta, phi in ((0, 78), (60, 50), (-60, 50), (105, 20), (-105, 20), (150, 45), (-150, 45)):
        d = outward(theta, phi)
        p = Vector(body) + Vector((d.x * 1.05, d.y * 1.45, d.z * 1.0)) * 0.98
        parts += aim(k.flower(0.32, cream, pink, lobes=5), p - d * 0.03, d)
    parts.append(k.puff(0.26, (0, 1.4, 2.5), k.flat(WHITE), name="tail"))
    return parts


# Bamboo Panda (epic) --------------------------------------------------------------------------


def creature_panda():
    white = k.paint("pa_fur", [(0, (235, 235, 240)), (1, (255, 255, 255))], 0.2, 4.4)
    # White belly, black shoulder collar where the head sits.
    fur = k.paint("pa_body", [(0, (240, 240, 245)), (0.74, (255, 255, 255)), (0.745, (52, 50, 62)), (1, (52, 50, 62))], 0.2, 2.9)
    black = k.flat((52, 50, 62))
    green = k.flat((110, 200, 100))
    leaf = k.flat((140, 220, 110))

    body = (0, 0.1, 1.5)
    parts = [blob(1.45, body, fur, scale=(1.25, 1.08, 1.02), seg=16, rings=10, name="body")]
    for s in (1, -1):
        parts.append(blob(0.55, (s * 1.15, -1.2, 0.5), black, scale=(1, 1.45, 0.85), seg=12, rings=7, name="leg"))
        parts.append(k.tube([(s * 1.65, -0.1, 2.3), (s * 1.4, -0.9, 1.9), (s * 0.6, -1.5, 1.7)], [0.44, 0.42, 0.36], m=black, n=10, name="arm"))
        parts.append(blob(0.36, (s * 0.55, -1.55, 1.7), black, seg=8, rings=5, name="paw"))
    head = (0, -0.25, 3.4)
    parts.append(blob(1.05, head, white, scale=(1.1, 1, 0.95), seg=16, rings=10, name="head"))
    for s in (1, -1):
        parts.append(blob(0.38, (s * 0.95, -0.05, 4.15), black, seg=10, rings=6, name="ear"))
        parts.append(stud(head, 1.05, s * 27, 4, 0.32, black, flat=0.45, scale=(1.1, 1, 0.95), name="patch"))
        patch = Vector(head) + Vector((outward(s * 27, 4).x * 1.1, outward(s * 27, 4).y, outward(s * 27, 4).z * 0.95)) * 1.05
        parts.append(k.sphere(0.1, patch + outward(s * 27 - 4 * s, 12) * 0.2, m=k.flat(WHITE), seg=6, rings=4, name="glint"))
    parts.append(stud(head, 1.05, 0, -16, 0.15, black, flat=0.7, scale=(1.1, 1, 0.95), name="nose"))
    parts += cheeks(head, 1.05, theta=50, phi=-16, r=0.17, scale=(1.1, 1, 0.95))
    # Bamboo stalk held across the paws, leaves on top and one on the head.
    stalk = [(0.55, -1.95, 0.3), (0.72, -2.0, 1.6), (0.9, -2.05, 3.3)]
    parts.append(k.tube(stalk, 0.14, m=green, n=8, name="bamboo"))
    for z in (1.2, 2.2):
        f = (z - 0.3) / 3.0
        parts.append(k.ring(0.16, z, 0.05, leaf, n=8, sides=3, centre=(0.55 + 0.35 * f, -1.95 - 0.1 * f), name="node"))
    for spin, lift in ((20, 0.0), (-60, 0.15), (120, -0.1)):
        blade = k.leaf(0.85, 0.26, leaf, droop=0.3)
        blade.data.transform(Matrix.Translation((0.9, -2.05, 3.1 + lift)) @ k.rot_z(spin))
        parts.append(blade)
    crown = k.leaf(0.95, 0.32, leaf, droop=0.4)
    crown.data.transform(Matrix.Translation((0.15, -0.25, 4.35)) @ k.rot_z(-140))
    parts.append(crown)
    return parts


# Daisy Unicorn (legendary) --------------------------------------------------------------------


def creature_unicorn():
    # Golden hooves are painted: the coat is gold below 0.34 and only the legs reach there.
    coat = k.paint("un_coat", [(0, k.GOLD_MID), (0.066, k.GOLD_MID), (0.068, (255, 232, 200)), (1, (255, 246, 228))], 0, 5.0)
    horn = k.paint("un_horn", [(0, (250, 200, 90)), (1, (255, 236, 150))], 4.6, 5.8, bands=((225, 160, 60), 0.26))
    white = k.flat((255, 255, 255))
    sun = k.flat((255, 215, 80))
    pink = k.flat(k.BLUSH)

    parts = []
    for x, y in ((0.5, -0.6), (-0.5, -0.6), (0.5, 0.8), (-0.5, 0.8)):
        parts += leg(x, y, 1.6, 0.22, coat)
    body = (0, 0.15, 2.4)
    parts.append(blob(0.92, body, coat, scale=(1.05, 1.5, 1), seg=14, rings=9, name="body"))
    parts.append(k.tube([(0, -0.7, 2.75), (0, -0.95, 3.35), (0, -1.05, 3.8)], 0.44, m=coat, n=10, name="neck"))
    head = (0, -1.0, 4.15)
    parts.append(blob(0.85, head, coat, seg=14, rings=9, name="head"))
    parts.append(blob(0.46, (0, -1.7, 3.78), coat, scale=(1.05, 1, 0.8), seg=10, rings=6, name="muzzle"))
    parts += eyes(head, 0.85, theta=32, phi=6, r=0.24, iris=(80, 60, 110))
    parts += cheeks(head, 0.85, theta=52, phi=-14, r=0.17)
    for s in (1, -1):
        parts.append(blob(0.3, (s * 0.62, -0.85, 4.85), pink, scale=(0.7, 0.5, 1), rot=(0, s * 25, 0), seg=8, rings=5, name="ear"))
    # Spiral horn (painted bands) wrapped in daisies, climbing to the tip.
    up = Vector((0, -0.25, 1)).normalized()
    base = Vector((0, -1.15, 4.85))
    parts += aim(k.lathe([(0.2, 0), (0.17, 0.35), (0.1, 0.7), (0, 1.0)], m=horn, n=10, name="horn"), base, up)
    for h, theta in ((0.25, -60), (0.6, 120)):
        d = outward(theta, 0)
        parts += aim(k.flower(0.18, white, sun, lobes=5), base + up * h + d * (0.19 - 0.15 * h), d + Vector((0, 0, 0.3)))
    # Mane: daisies from the forelock over the crown and down both sides of the neck, all facing
    # up and out so they show from every side; tail: a fan of daisies facing back.
    for p, d, r in (
        ((0, -1.55, 4.7), (0, -0.7, 0.7), 0.4), ((0, -0.9, 5.0), (0, 0, 1), 0.4),
        ((0.4, -0.4, 4.75), (0.6, 0.3, 0.8), 0.38), ((-0.4, -0.4, 4.75), (-0.6, 0.3, 0.8), 0.38),
        ((0.42, -0.4, 4.2), (0.8, 0.3, 0.5), 0.38), ((-0.42, -0.4, 4.2), (-0.8, 0.3, 0.5), 0.38),
        ((0.4, -0.3, 3.55), (0.8, 0.2, 0.6), 0.38), ((-0.4, -0.3, 3.55), (-0.8, 0.2, 0.6), 0.38),
        ((0, 1.5, 3.0), (0, 1, 0.3), 0.44), ((0.75, 1.35, 2.6), (0.4, 1, 0.0), 0.4), ((-0.75, 1.35, 2.6), (-0.4, 1, 0.0), 0.4),
        ((0, 1.55, 2.25), (0, 1, -0.4), 0.38),
    ):
        parts += aim(k.flower(r, white, sun, lobes=6), p, d)
    return parts


# Ember Phoenix (mythic) -----------------------------------------------------------------------


def creature_phoenix():
    body = k.paint("ph_body", [(0, (255, 120, 50)), (0.5, (255, 170, 60)), (1, (255, 215, 90))], 0.3, 4.3)
    fire = k.paint("ph_fire", [(0, (255, 110, 40)), (0.45, (255, 175, 50)), (1, (255, 245, 160))], 3.2, 5.6)
    tail = k.paint("ph_tail", [(0, (255, 110, 40)), (0.5, (255, 180, 60)), (1, (255, 245, 170))], 0.8, 2.6, axis="Y")
    belly = k.flat((255, 236, 150))
    beak = k.flat((255, 200, 80))

    core = (0, 0.1, 1.55)
    parts = [blob(1.25, core, body, scale=(1, 1.05, 1.0), seg=16, rings=10, name="body")]
    parts.append(blob(0.72, (0, -0.95, 1.25), belly, scale=(1, 0.5, 1.1), seg=12, rings=7, name="belly"))
    head = (0, -0.3, 3.35)
    parts.append(blob(1.0, head, body, seg=16, rings=10, name="head"))
    parts.append(k.cyl(0.24, 0.5, (0, -1.3, 3.15), rot=(-100, 0, 0), m=beak, n=7, r2=0, name="beak"))
    parts += eyes(head, 1.0, theta=28, phi=8, r=0.25)
    parts += cheeks(head, 1.0, theta=50, phi=-12, r=0.2)
    for s in (1, -1):
        parts.append(blob(0.55, (s * 1.65, 0.2, 1.85), body, scale=(0.5, 1.2, 1.3), rot=(0, s * 40, 0), seg=10, rings=6, name="wing"))
        parts.append(blob(0.3, (s * 0.5, -0.5, 0.16), beak, scale=(1, 1.4, 0.4), seg=8, rings=5, name="foot"))
    # Flame crest and tail, orange at the root to bright yellow tips.
    for root, tip, r, bend in (
        ((0, -0.2, 4.2), (0, -0.1, 5.5), 0.3, 0.12), ((0.35, -0.1, 4.15), (1.0, 0.3, 5.1), 0.26, 0.18), ((-0.35, -0.1, 4.15), (-1.0, 0.3, 5.1), 0.26, -0.18),
        ((0, 0.3, 4.1), (0.15, 1.0, 4.9), 0.24, 0.1),
    ):
        parts.append(flame(root, tip, r, fire, bend=bend))
    for root, tip, r in (
        ((0, 1.1, 1.6), (0, 2.5, 3.0), 0.36), ((0.5, 1.0, 1.5), (2.0, 2.2, 2.5), 0.3), ((-0.5, 1.0, 1.5), (-2.0, 2.2, 2.5), 0.3),
        ((0.3, 1.1, 1.1), (1.1, 2.5, 1.2), 0.26), ((-0.3, 1.1, 1.1), (-1.1, 2.5, 1.2), 0.26),
    ):
        parts.append(flame(root, tip, r, tail, bend=0.1))
    return parts


# Aurora Whale (divine) ------------------------------------------------------------------------


def creature_whale():
    back = k.paint(
        "wh_back",
        [(0, (120, 215, 210)), (0.45, (110, 170, 230)), (1, (180, 130, 255))],
        1.6,
        3.5,
        dots=[((255, 255, 255), 5, 0.1), ((255, 236, 150), 3, 0.07)],
    )
    belly = k.flat((232, 240, 255))
    cloud = k.paint("wh_cloud", [(0, (225, 232, 248)), (1, (255, 255, 255))], 0, 1.2)
    dark = k.flat((60, 60, 110))

    parts = []
    for x, y, z, r in ((0, 0, 0.6, 0.95), (1.5, 0.3, 0.55, 0.8), (-1.5, 0.3, 0.55, 0.8), (0.8, -1.2, 0.5, 0.75), (-0.8, -1.2, 0.5, 0.75), (1.0, 1.5, 0.5, 0.75), (-1.0, 1.5, 0.5, 0.75), (0, 2.1, 0.45, 0.6), (2.3, -0.5, 0.4, 0.55), (-2.3, -0.5, 0.4, 0.55)):
        parts.append(k.puff(r, (x, y, z), cloud, scale=(1, 1, 0.75), name="cloud"))
    body = (0, 0.1, 2.6)
    parts.append(blob(1.3, body, back, scale=(1.05, 1.7, 0.95), seg=20, rings=12, name="body"))
    parts.append(blob(1.05, (0, -0.3, 2.25), belly, scale=(1.1, 1.5, 0.7), seg=14, rings=8, name="belly"))
    # Tail flukes held high, long side flippers.
    for s in (1, -1):
        parts.append(blob(0.65, (s * 0.8, 2.75, 3.95), back, scale=(1.1, 0.8, 0.3), rot=(25, 0, s * 20), seg=12, rings=6, name="fluke"))
        parts.append(blob(0.8, (s * 1.95, -0.5, 2.05), belly, scale=(1.2, 0.55, 0.28), rot=(0, s * -25, s * -20), seg=12, rings=6, name="flipper"))
    parts.append(k.tube([(0, 1.8, 3.1), (0, 2.3, 3.5), (0, 2.6, 3.85)], [0.5, 0.36, 0.28], m=back, n=10, name="tail_stem"))
    # Happy closed eyes, a smile, rosy cheeks, a star on the back.
    for s in (1, -1):
        c = Vector(body) + Vector((s * 0.82, -1.65, 0.3))
        arc = [c + Vector((s * 0.28 * math.cos(a), -0.1 * math.sin(a), 0.22 * math.sin(a))) for a in (0, 0.8, 1.6, 2.4, 3.14)]
        parts.append(k.tube(arc, 0.09, m=dark, n=5, name="eye"))
    parts += cheeks(body, 1.3, theta=44, phi=-16, r=0.24, scale=(1.05, 1.7, 0.95))
    smile = [Vector((x, -1.62 - 0.1 * (1 - (x / 0.5) ** 2), 1.85 + 0.2 * (x / 0.5) ** 2)) for x in (-0.5, -0.25, 0, 0.25, 0.5)]
    parts.append(k.tube(smile, 0.08, m=dark, n=5, name="smile"))
    parts += aim(k.star(0.3, k.flat(k.GOLD_HI)), (0.45, 0.6, 3.5), (0.3, 0.2, 1))
    parts += aim(k.star(0.2, k.flat(k.GOLD_HI)), (-0.6, 1.1, 3.35), (-0.3, 0.3, 1))
    return parts


# Nimbus Kirin (divine) ------------------------------------------------------------------------


def creature_kirin():
    # Golden hooves are painted: the coat is gold below 0.36 and only the legs reach there.
    coat = k.paint("ki_coat", [(0, k.GOLD_MID), (0.066, k.GOLD_MID), (0.068, (200, 230, 255)), (1, (235, 245, 255))], 0, 5.4)
    scales = k.paint("ki_scales", [(0, (175, 215, 250)), (1, (205, 232, 255))], 1.5, 3.6, bands=((150, 195, 240), 0.4), axis="Y")
    gold = k.flat(k.GOLD_MID)
    cloud = k.flat(WHITE)
    muzzle = k.flat((240, 248, 255))

    parts = []
    for x, y in ((0.52, -0.65), (-0.52, -0.65), (0.52, 0.85), (-0.52, 0.85)):
        parts += leg(x, y, 1.9, 0.24, coat)
    body = (0, 0.15, 2.75)
    parts.append(blob(0.98, body, coat, scale=(1.05, 1.55, 1), seg=14, rings=9, name="body"))
    parts.append(blob(0.98, (0, 0.35, 2.9), scales, scale=(0.9, 1.45, 0.95), seg=14, rings=8, name="scales"))
    parts.append(k.tube([(0, -0.75, 3.15), (0, -1.0, 3.8), (0, -1.1, 4.3)], 0.45, m=coat, n=10, name="neck"))
    head = (0, -1.05, 4.7)
    parts.append(blob(0.9, head, coat, seg=14, rings=9, name="head"))
    parts.append(blob(0.5, (0, -1.75, 4.3), muzzle, scale=(1.05, 1, 0.8), seg=10, rings=6, name="muzzle"))
    parts.append(k.sphere(0.12, (0, -2.22, 4.37), m=k.flat((120, 110, 150)), scale=(1.2, 0.7, 0.8), seg=8, rings=5, name="nose"))
    parts += eyes(head, 0.9, theta=32, phi=6, r=0.25, iris=(70, 70, 120))
    parts += cheeks(head, 0.9, theta=52, phi=-14, r=0.18)
    gem = k.sharpen(k.ico(0.2, subdiv=1, m=gold, name="gem"))
    parts += aim(gem, Vector(head) + outward(0, 36) * 0.9, outward(0, 36))
    for s in (1, -1):
        parts.append(blob(0.3, (s * 0.72, -0.85, 5.25), coat, scale=(0.7, 0.5, 1), rot=(0, s * 30, 0), seg=8, rings=5, name="ear"))
        # Small branching antlers, spread wide.
        a = Vector((s * 0.4, -0.7, 5.4))
        b = a + Vector((s * 0.7, 0.15, 0.4))
        parts.append(k.tube([a, b, b + Vector((s * 0.75, 0.2, 0.2))], [0.13, 0.11, 0.07], m=gold, n=6, name="antler"))
        parts.append(k.tube([b, b + Vector((s * 0.1, -0.25, 0.42))], [0.1, 0.06], m=gold, n=6, name="tine"))
    # Cloud-puff mane down both sides of the neck and over the brow, cloud tail.
    for x, y, z, r in (
        (0, -0.7, 5.3, 0.42), (0, -0.3, 4.85, 0.4), (0, -0.15, 4.25, 0.4), (0, 0.0, 3.7, 0.38),
        (0.55, -0.95, 5.05, 0.34), (-0.55, -0.95, 5.05, 0.34), (0.6, -0.5, 4.5, 0.36), (-0.6, -0.5, 4.5, 0.36), (0.6, -0.35, 3.9, 0.34), (-0.6, -0.35, 3.9, 0.34),
    ):
        parts.append(k.puff(r, (x, y, z), cloud, name="mane"))
    for x, y, z, r in ((0, 1.65, 3.0, 0.46), (0.45, 1.95, 2.55, 0.38), (-0.45, 1.95, 2.55, 0.38), (0, 2.1, 2.0, 0.34)):
        parts.append(k.puff(r, (x, y, z), cloud, name="tail"))
    return parts


# Stardust Axolotl (secret) --------------------------------------------------------------------


def creature_axolotl():
    skin = k.paint("ax_skin", [(0, (235, 170, 225)), (1, (248, 200, 240))], 0.2, 2.2)
    gill = k.paint("ax_gill", [(0, (255, 130, 185)), (1, (255, 175, 215))], 1.0, 3.0)
    galaxy = k.paint(
        "ax_galaxy",
        [(0, (60, 50, 130)), (0.5, (90, 60, 160)), (1, (55, 45, 120))],
        -0.5,
        3.0,
        axis="Y",
        dots=[((255, 255, 255), 7, 0.11), ((255, 220, 130), 4, 0.07)],
    )
    dark = k.flat((110, 60, 110))

    body = (0, 0.5, 1.0)
    parts = [blob(0.85, body, skin, scale=(1.0, 1.9, 0.95), seg=16, rings=10, name="body")]
    parts.append(blob(0.74, (0, 0.55, 1.4), galaxy, scale=(1.0, 1.9, 0.6), seg=14, rings=8, name="galaxy"))
    head = (0, -1.1, 1.4)
    parts.append(blob(1.05, head, skin, scale=(1.15, 1.0, 0.9), seg=18, rings=11, name="head"))
    parts.append(blob(0.7, (0, -1.0, 1.85), galaxy, scale=(1.1, 0.9, 0.5), seg=12, rings=7, name="crown"))
    parts += eyes(head, 1.05, theta=38, phi=14, r=0.21, scale=(1.15, 1.0, 0.9))
    parts += cheeks(head, 1.05, theta=56, phi=-6, r=0.19, scale=(1.15, 1.0, 0.9))
    smile = [Vector((x, -2.07 - 0.12 * (1 - (x / 0.6) ** 2), 1.12 + 0.3 * (x / 0.6) ** 2)) for x in (-0.6, -0.3, 0, 0.3, 0.6)]
    parts.append(k.tube(smile, 0.08, m=dark, n=5, name="smile"))
    # Six feathery gills, three a side, fanning up and back from the head: smooth fat stalks with
    # round fronds along the top edge.
    for s in (1, -1):
        for i, (dy, dz, length) in enumerate(((-0.2, 0.55, 1.1), (0.15, 0.3, 1.15), (0.4, 0.0, 1.0))):
            root = Vector((s * 0.95, -1.0 + dy, 1.4 + dz))
            out = Vector((s * 0.7, 0.4 + 0.15 * i, 0.75 - 0.25 * i)).normalized()
            parts += aim(k.sphere(0.22, (0, 0, 0), m=gill, scale=(1, 0.8, length / 0.44), seg=8, rings=5, name="gill"), root + out * length * 0.5, out)
            for t in (0.3, 0.6, 0.9):
                parts.append(k.sphere(0.16, root + out * length * t + Vector((0, 0, 0.16)), m=gill, seg=6, rings=3, name="frond"))
    for x, y in ((0.7, -0.55), (-0.7, -0.55), (0.65, 1.3), (-0.65, 1.3)):
        parts.append(blob(0.3, (x, y, 0.22), skin, scale=(1, 1.25, 0.65), seg=8, rings=4, name="foot"))
    # Long flat tail, curling to the side.
    curve = [(0, 1.9, 1.0), (0, 2.3, 1.0), (0.3, 2.65, 1.05), (0.9, 2.85, 1.1), (1.5, 2.75, 1.15), (1.9, 2.4, 1.2)]
    tail = k.tube(curve, [0.72, 0.64, 0.54, 0.42, 0.3, 0], m=skin, n=10, name="tail")
    tail.data.transform(Matrix.Diagonal((0.55, 1, 1, 1)))
    parts.append(tail)
    fin = k.tube([(0, 1.6, 1.5), (0, 2.3, 1.65), (0.2, 2.65, 1.65), (0.55, 2.85, 1.55)], [0.1, 0.32, 0.3, 0.0], m=gill, n=5, name="fin")
    fin.data.transform(Matrix.Diagonal((0.35, 1, 1, 1)))
    parts.append(fin)
    return parts


NOTES = "One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are."
ASSETS = [
    dict(name=name, build=build, budget=budget, size=size, priority=1, order=20 + i, replaces="none (new species)", notes=f"{label}. {NOTES}", glow={})
    for i, (name, build, budget, size, label) in enumerate(
        (
            ("creature_duck", creature_duck, 2500, [2.8, 3.0, 2.8], "Puddle Duckling (common)"),
            ("creature_lamb", creature_lamb, 2500, [3.2, 3.8, 3.4], "Clover Lamb (uncommon)"),
            ("creature_hedgehog", creature_hedgehog, 2500, [3.0, 2.8, 3.4], "Acorn Hedgehog (rare)"),
            ("creature_deer", creature_deer, 2500, [3.6, 5.0, 3.0], "Blossom Fawn (epic)"),
            ("creature_panda", creature_panda, 2500, [4.4, 4.5, 4.0], "Bamboo Panda (epic)"),
            ("creature_unicorn", creature_unicorn, 2500, [4.0, 5.5, 4.8], "Daisy Unicorn (legendary)"),
            ("creature_phoenix", creature_phoenix, 2500, [4.6, 5.5, 4.2], "Ember Phoenix (mythic)"),
            ("creature_whale", creature_whale, 3000, [6.0, 4.5, 5.0], "Aurora Whale (divine)"),
            ("creature_kirin", creature_kirin, 3000, [4.6, 6.0, 5.2], "Nimbus Kirin (divine)"),
            ("creature_axolotl", creature_axolotl, 2500, [3.4, 3.0, 5.0], "Stardust Axolotl (secret)"),
        )
    )
]
