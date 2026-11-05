"""v0.5 exclusives (GARDEN-054, GDD X3.4, architecture 9.3): the six login-reward species and the
Weekly and Monthly Eggs. Chibi toys in the creatures_b style, one mesh each, facing Blender -Y."""

import math
import os
import sys

import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creatures_b import DARK, WHITE, aim, blob, cheeks, eyes, leg, outward, placed, stud  # noqa: E402
from eggs import fit, moved  # noqa: E402


def happy_eye(centre, R, theta, phi, m, w=0.26, h=0.18, scale=(1, 1, 1)):
    """Closed, smiling eye: a raised arc painted dark on a scaled sphere."""
    d = outward(theta, phi)
    p = Vector(centre) + Vector((d.x * R * scale[0], d.y * R * scale[1], d.z * R * scale[2])) + d * 0.03
    right = Vector((0, 0, 1)).cross(d).normalized()
    up = d.cross(right).normalized()
    arc = [p + right * w * math.cos(a) + up * h * math.sin(a) for a in (0, 0.8, 1.6, 2.4, 3.14)]
    return k.tube(arc, 0.07, m=m, n=5, name="eye")


def centred(parts):
    """Moves the parts so finalize's own centring is a no-op; returns the shift it applied, so
    painted marks can be placed in final coordinates."""
    lo, hi = k._ground_dims(parts)
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    moved(parts, *shift)
    return shift


# Pebble Puffin (uncommon, weekly) ------------------------------------------------------------


def creature_puffin():
    black = k.paint("pf_body", [(0, (40, 38, 52)), (1, (62, 60, 78))], 0.6, 2.9)
    white = k.flat(WHITE)
    orange = k.flat((255, 140, 50))
    # Striped beak: orange with yellow bands along its length (it points down -Y).
    beak = k.paint("pf_beak", [(0, (255, 120, 40)), (1, (255, 150, 60))], -1.7, -0.8, axis="Y", bands=((255, 225, 90), 0.44))
    pebble = k.paint("pf_pebble", [(0, (150, 150, 165)), (1, (200, 200, 212))], 0, 0.6, dots=[((175, 175, 190), 6, 0.2)])

    body = (0, 0.0, 1.75)
    parts = [
        blob(1.0, (0, 0.0, 0.3), pebble, scale=(1.25, 1.1, 0.34), seg=14, rings=7, name="pebble"),
        blob(1.0, body, black, scale=(1, 1, 1.15), seg=16, rings=10, name="body"),
        blob(0.72, (0, -0.45, 1.35), white, scale=(1, 0.75, 1.1), seg=12, rings=7, name="belly"),
    ]
    # White face discs either side of the beak, black cap above, grey-white under the chin.
    for s in (1, -1):
        parts.append(stud(body, 1.0, s * 26, 24, 0.5, white, lift=0.02, flat=0.3, seg=10, rings=6, scale=(1, 1, 1.15), name="face"))
        parts.append(blob(0.4, (s * 0.92, 0.15, 1.65), black, scale=(0.45, 1.1, 0.9), rot=(0, s * -12, 0), seg=10, rings=6, name="wing"))
        parts.append(blob(0.26, (s * 0.32, -0.45, 0.68), orange, scale=(1, 1.5, 0.35), seg=10, rings=5, name="foot"))
    beak_ob = k.cyl(0.52, 1.1, (0, 0, 0), m=beak, n=10, r2=0.05, name="beak")
    parts += placed(beak_ob, loc=(0, -1.3, 1.9), rot=(100, 0, 0), scale=(0.7, 1.25, 1))
    parts += eyes(body, 1.0, theta=27, phi=34, r=0.17, scale=(1, 1, 1.15), lift=0.1)
    parts += cheeks(body, 1.0, theta=46, phi=14, r=0.13, scale=(1, 1, 1.15))
    parts.append(blob(0.3, (0, 1.0, 1.3), black, scale=(0.8, 1, 0.5), rot=(-30, 0, 0), seg=8, rings=5, name="tail"))
    return parts


# River Otter (rare, weekly) ------------------------------------------------------------------


def creature_otter():
    brown = k.paint("ot_fur", [(0, (120, 80, 55)), (1, (160, 112, 78))], 0.2, 3.6)
    pale = k.flat((230, 205, 170))
    dark = k.flat((70, 48, 40))
    water = k.paint("ot_water", [(0, (120, 190, 245)), (1, (170, 225, 255))], -2.2, 2.2, axis="Y")
    shell = k.paint("ot_shell", [(0, (255, 190, 170)), (1, (255, 228, 215))], 1.9, 2.6)
    pearl = k.flat((255, 252, 240))

    # Floating on its back: a long flat body, the head lifted at the front looking up at the shell.
    # The body tilts feet-up, so the belly and shell face the camera over the low head.
    body = (0, 0.4, 1.15)
    head = (0, -1.9, 1.55)
    parts = [
        k.cyl(2.0, 0.1, (0, 0.2, 0.05), m=water, n=28, name="river"),
        blob(1.0, body, brown, scale=(1.15, 1.8, 0.9), rot=(-14, 0, 0), seg=16, rings=10, name="body"),
        blob(0.85, (0, 0.25, 1.68), pale, scale=(0.9, 1.5, 0.6), rot=(-14, 0, 0), seg=12, rings=7, name="belly"),
        blob(0.8, head, brown, scale=(1.15, 1, 0.95), seg=16, rings=10, name="head"),
        blob(0.42, (0, -2.6, 1.8), pale, scale=(1.25, 0.8, 0.8), seg=12, rings=7, name="muzzle"),
        k.sphere(0.13, (0, -2.83, 2.08), m=dark, scale=(1.2, 0.7, 0.8), seg=8, rings=5, name="nose"),
    ]
    parts += eyes(head, 0.8, theta=32, phi=48, r=0.2, scale=(1.15, 1, 0.95))
    parts += cheeks(head, 0.8, theta=56, phi=22, r=0.15, scale=(1.15, 1, 0.95))
    for s in (1, -1):
        parts.append(blob(0.22, (s * 0.8, -1.55, 2.1), brown, scale=(1, 0.6, 1), seg=8, rings=5, name="ear"))
        for dz, dy in ((0.0, 0.0), (-0.1, 0.06), (0.1, 0.06)):
            parts.append(k.tube([(s * 0.3, -2.7 + dy, 1.95 + dz), (s * 0.95, -2.6 + dy, 2.1 + dz * 2)], 0.025, m=dark, n=3, name="whisker"))
        # Paws holding the shell on the belly, webbed hind feet up at the back.
        parts.append(blob(0.26, (s * 0.7, -0.75, 1.95), brown, scale=(1, 1.1, 0.8), seg=8, rings=5, name="paw"))
        parts.append(blob(0.32, (s * 0.5, 2.1, 2.2), dark, scale=(1, 0.5, 1.4), rot=(-35, 0, 0), seg=8, rings=5, name="foot"))
    parts += aim(k.flower(0.62, shell, pearl, lobes=7), (0, -0.45, 2.12), (0, -0.45, 1), spin=180)
    tail = k.tube([(0, 2.1, 1.0), (0, 2.6, 1.25), (0, 2.95, 1.6)], [0.42, 0.34, 0.1], m=brown, n=8, name="tail")
    tail.data.transform(Matrix.Translation((0, 0, 1.1)) @ Matrix.Diagonal((1, 1, 0.45, 1)) @ Matrix.Translation((0, 0, -1.1)))
    parts.append(tail)
    return parts


# Spa Capybara (epic, weekly) -----------------------------------------------------------------


def creature_capybara():
    tan = k.paint("ca_fur", [(0, (165, 118, 72)), (1, (205, 160, 105))], 0.6, 4.0)
    dark = k.flat((80, 58, 45))
    towel = k.paint("ca_towel", [(0, (255, 255, 252)), (1, (255, 255, 252))], 0, 1, axis="X", bands=((150, 205, 240), 0.5))
    yuzu = k.paint("ca_yuzu", [(0, (255, 205, 50)), (1, (255, 232, 95))], 3.2, 4.1, grain=(0.12, 30))
    leaf = k.flat((110, 190, 90))

    body = (0, 0.3, 2.15)
    head = (0, -1.65, 2.95)
    parts = []
    for x, y in ((0.62, -0.6), (-0.62, -0.6), (0.62, 1.1), (-0.62, 1.1)):
        parts += leg(x, y, 1.2, 0.3, tan)
    parts += [
        blob(1.35, body, tan, scale=(1.05, 1.45, 1.0), seg=16, rings=10, name="body"),
        blob(0.95, head, tan, scale=(1, 1.3, 0.95), seg=16, rings=10, name="head"),
        blob(0.6, (0, -2.75, 2.65), tan, scale=(1.05, 0.8, 0.8), seg=12, rings=7, name="muzzle"),
        k.sphere(0.18, (0, -3.2, 2.78), m=dark, scale=(1.4, 0.6, 0.7), seg=8, rings=5, name="nose"),
    ]
    for s in (1, -1):
        parts.append(blob(0.22, (s * 0.72, -1.3, 3.75), tan, scale=(1, 0.7, 1), seg=8, rings=5, name="ear"))
        parts.append(happy_eye(head, 0.95, s * 34, 16, dark, scale=(1, 1.3, 0.95)))
    parts += cheeks(head, 0.95, theta=56, phi=-4, r=0.17, scale=(1, 1.3, 0.95))
    # Folded towel on the head, a yuzu riding on the back.
    towel_ob = k.box((1.3, 1.0, 0.3), (0, 0, 0), m=towel, bevel=0.08, name="towel")
    parts += placed(towel_ob, loc=(0, -1.55, 3.95), rot=(8, 0, 0))
    parts.append(blob(0.42, (0.25, 0.7, 3.5), yuzu, seg=12, rings=7, name="yuzu"))
    parts.append(k.tube([(0.25, 0.7, 3.88), (0.28, 0.72, 4.02)], 0.04, m=dark, n=5, name="stem"))
    sprig = k.leaf(0.45, 0.16, leaf, droop=0.2)
    sprig.data.transform(Matrix.Translation((0.28, 0.72, 3.95)) @ k.rot_z(140))
    parts.append(sprig)
    return parts


# Maple Red Panda (legendary, monthly) --------------------------------------------------------


def creature_redpanda():
    rust = k.paint("rp_fur", [(0, (185, 70, 35)), (1, (225, 105, 50))], 0.4, 5.0)
    dark = k.flat((60, 38, 36))
    cream = k.flat((255, 240, 215))
    maple = k.paint("rp_maple", [(0, (240, 100, 40)), (1, (255, 160, 50))], 1.6, 3.2)

    body = (0, 0.1, 1.75)
    head = (0, -0.3, 3.85)
    parts = [
        blob(1.2, body, rust, scale=(1, 1, 1.1), seg=16, rings=10, name="body"),
        blob(0.95, (0, -0.4, 1.7), dark, scale=(0.85, 0.85, 1.0), seg=12, rings=7, name="belly"),
        blob(1.05, head, rust, scale=(1.15, 1, 0.95), seg=16, rings=10, name="head"),
        blob(0.5, (0, -1.1, 3.6), cream, scale=(1.2, 0.8, 0.85), seg=12, rings=7, name="muzzle"),
        k.sphere(0.15, (0, -1.5, 3.72), m=dark, scale=(1.2, 0.7, 0.8), seg=8, rings=5, name="nose"),
    ]
    for s in (1, -1):
        # Cream mask: brow tear-drops and cheek patches; big round ears tipped white.
        parts.append(stud(head, 1.05, s * 28, 38, 0.3, cream, flat=0.3, seg=8, rings=5, scale=(1.15, 1, 0.95), name="brow"))
        parts.append(stud(head, 1.05, s * 60, -2, 0.4, cream, flat=0.3, seg=10, rings=5, scale=(1.15, 1, 0.95), name="patch"))
        parts.append(blob(0.4, (s * 1.08, -0.15, 4.6), rust, scale=(1, 0.6, 1), seg=10, rings=6, name="ear"))
        parts.append(blob(0.22, (s * 1.12, -0.3, 4.72), cream, scale=(1, 0.5, 1), seg=8, rings=4, name="ear_in"))
        parts.append(blob(0.4, (s * 0.7, -0.9, 0.42), dark, scale=(1, 1.3, 0.6), seg=8, rings=5, name="foot"))
        parts.append(k.tube([(s * 1.05, -0.2, 2.5), (s * 0.95, -1.0, 2.1), (s * 0.5, -1.45, 2.2)], [0.32, 0.3, 0.26], m=rust, n=8, name="arm"))
        parts.append(blob(0.3, (s * 0.5, -1.5, 2.2), dark, seg=8, rings=5, name="paw"))
    parts += eyes(head, 1.05, theta=28, phi=10, r=0.22, scale=(1.15, 1, 0.95))
    parts += cheeks(head, 1.05, theta=50, phi=-14, r=0.16, scale=(1.15, 1, 0.95))
    # Maple leaf held in both paws, a ringed tail curled round the right side.
    # Five big lobes with one tooth a side, so it still reads as a maple leaf at 20 studs.
    half = [(0, 1.0), (0.1, 0.78), (0.2, 0.82), (0.14, 0.55), (0.42, 0.66), (0.5, 0.78), (0.72, 0.72), (0.6, 0.5), (0.68, 0.42), (0.52, 0.28), (0.8, 0.2), (0.86, 0.3), (0.98, 0.05), (0.7, 0.0), (0.5, -0.15), (0.66, -0.4), (0.62, -0.6), (0.42, -0.42), (0.18, -0.4), (0.06, -0.65)]
    outline = [(x * 0.95, z * 0.95) for x, z in half] + [(-x * 0.95, z * 0.95) for x, z in reversed(half)]
    parts.append(k.poly(outline, 0.08, loc=(0, -1.62, 2.55), rot=(-18, 0, 0), m=maple, name="maple"))
    parts.append(k.tube([(0, -1.5, 1.6), (0, -1.6, 1.95)], 0.05, m=dark, n=5, name="stem"))
    curve = [(0.4, 1.1, 0.5), (1.1, 1.25, 0.5), (1.65, 0.75, 0.5), (1.8, 0.05, 0.5), (1.6, -0.65, 0.48), (1.15, -1.15, 0.45), (0.6, -1.5, 0.4)]
    for i, p in enumerate(curve):
        parts.append(blob(0.5 - 0.02 * i, p, dark if i % 2 else rust, seg=10, rings=6, name="tail"))
    return parts


# Jewel Peacock (mythic, monthly) -------------------------------------------------------------


def creature_peacock():
    body = k.paint("pc_body", [(0, (236, 244, 255)), (1, (255, 255, 255))], 0.8, 4.6)
    teal = k.flat((60, 190, 185))
    gold = k.flat(k.GOLD_MID)
    dark = k.flat((60, 60, 90))

    core = (0, 0.3, 1.9)
    head = (0, -0.75, 4.15)
    parts = [
        blob(0.9, core, body, scale=(1, 1.25, 1), seg=16, rings=10, name="body"),
        k.tube([(0, -0.3, 2.5), (0, -0.6, 3.3), (0, -0.75, 3.85)], [0.34, 0.3, 0.3], m=body, n=10, name="neck"),
        blob(0.56, head, body, seg=14, rings=9, name="head"),
        k.cyl(0.14, 0.4, (0, 0, 0), m=gold, n=7, r2=0, name="beak"),
    ]
    placed(parts[-1], loc=(0, -1.35, 4.05), rot=(90, 0, 0))
    parts += eyes(head, 0.56, theta=30, phi=10, r=0.15, iris=(60, 60, 90))
    parts += cheeks(head, 0.56, theta=52, phi=-10, r=0.11)
    for s in (1, -1):
        parts.append(blob(0.45, (s * 0.85, 0.3, 2.0), body, scale=(0.45, 1.1, 0.9), rot=(0, s * -15, 0), seg=10, rings=6, name="wing"))
        parts.append(k.tube([(s * 0.3, -0.1, 1.2), (s * 0.32, -0.2, 0.15)], 0.08, m=gold, n=5, name="leg"))
        parts.append(blob(0.24, (s * 0.32, -0.35, 0.1), gold, scale=(1, 1.5, 0.35), seg=8, rings=4, name="foot"))
    # Crown: three wires with teal drops.
    for dx, dz in ((0, 0.75), (0.32, 0.62), (-0.32, 0.62)):
        tip = Vector(head) + Vector((dx, 0.05, dz))
        parts.append(k.tube([Vector(head) + Vector((dx * 0.3, 0, 0.45)), tip], 0.03, m=dark, n=4, name="wire"))
        parts.append(blob(0.11, tip, teal, scale=(1, 1, 1.4), seg=7, rings=4, name="drop"))
    # Fan of seven feathers standing behind, painted after centring so the eye-spots land.
    base = Vector((0, 1.0, 2.2))
    fan = []
    for a, length in ((-66, 2.6), (-44, 3.0), (-22, 3.25), (0, 3.35), (22, 3.25), (44, 3.0), (66, 2.6)):
        d = Vector((math.sin(math.radians(a)), 0.2, math.cos(math.radians(a)))).normalized()
        f = k.leaf(length, 0.5, teal, droop=0.0, n=6, steps=5, name="feather")
        f.data.transform(k.rot_z(90) @ Matrix.Rotation(math.radians(-90), 4, "Y"))
        aim(f, base, d)
        fan.append((f, base + d * length * 0.74))
    parts += [f for f, _ in fan]
    shift = centred(parts)
    marks = []
    for f, c in fan:
        c = c + shift
        marks += [((120, 90, 200), c, 0, 0.3), ((60, 190, 185), c, 0, 0.21), (k.GOLD_HI, c, 0, 0.11)]
    feather = k.paint("pc_feather", [(0, (40, 140, 130)), (1, (90, 210, 190))], 2.0, 5.6, marks=marks)
    for f, _ in fan:
        f.data.materials[0] = feather
    return parts


# Frost Leopard (divine, monthly) -------------------------------------------------------------


def creature_snowleopard():
    # Rosettes: two voronoi dot layers at one scale share cells, so the light disc centres the dark.
    fur = k.paint(
        "sl_fur",
        [(0, (200, 212, 232)), (1, (232, 240, 252))],
        0.3,
        5.8,
        dots=[((110, 118, 150), 2.4, 0.2), ((190, 200, 222), 2.4, 0.12), ((255, 255, 255), 11, 0.045)],
    )
    face = k.paint("sl_face", [(0, (215, 225, 240)), (1, (236, 243, 252))], 3.5, 5.8, dots=[((120, 128, 160), 4.5, 0.09), ((255, 255, 255), 11, 0.04)])
    white = k.flat(WHITE)
    frost = k.flat((170, 220, 255))
    pink = k.flat((240, 160, 180))

    body = (0, 0.3, 2.0)
    head = (0, -0.5, 4.5)
    parts = [
        blob(1.4, body, fur, scale=(1.0, 1.1, 1.2), seg=16, rings=10, name="body"),
        blob(0.85, (0, -0.8, 1.9), white, scale=(0.9, 0.8, 1.1), seg=12, rings=7, name="chest"),
        blob(1.2, head, face, scale=(1.15, 1, 1), seg=16, rings=10, name="head"),
        blob(0.55, (0, -1.5, 4.1), white, scale=(1.3, 0.8, 0.8), seg=12, rings=7, name="muzzle"),
        k.sphere(0.15, (0, -1.92, 4.25), m=pink, scale=(1.3, 0.7, 0.8), seg=8, rings=5, name="nose"),
    ]
    for s in (1, -1):
        parts.append(blob(0.42, (s * 1.05, -0.3, 5.35), face, scale=(1, 0.6, 1), seg=10, rings=6, name="ear"))
        parts.append(blob(0.24, (s * 1.12, -0.32, 5.6), frost, scale=(1, 0.6, 0.8), seg=8, rings=4, name="ear_tip"))
        parts += leg(s * 0.65, -1.0, 1.7, 0.34, fur, hoof=white, hoof_h=0.4)
        parts.append(blob(0.72, (s * 1.25, 0.7, 0.95), fur, scale=(1, 1.2, 1.1), seg=12, rings=7, name="haunch"))
        parts.append(blob(0.34, (s * 1.15, -0.4, 0.3), white, scale=(1, 1.4, 0.55), seg=8, rings=5, name="hind"))
    parts += eyes(head, 1.2, theta=28, phi=8, r=0.25, iris=(70, 110, 160), scale=(1.15, 1, 1))
    parts += cheeks(head, 1.2, theta=50, phi=-14, r=0.19, scale=(1.15, 1, 1))
    # Thick fluffy tail wrapped round the right side to the front paws.
    curve = [(0.6, 1.5, 0.6), (1.7, 1.1, 0.58), (2.1, -0.1, 0.55), (1.6, -1.3, 0.52), (0.5, -1.85, 0.5)]
    parts.append(k.tube(curve, [0.5, 0.58, 0.6, 0.55, 0.45], m=fur, n=10, name="tail"))
    parts.append(k.puff(0.5, (0.3, -1.9, 0.5), white, name="tail_tip"))
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
ASSETS = [
    dict(name=name, build=build, budget=2500, size=size, priority=1, order=40 + i, replaces="none (new species, login rewards)", notes=f"{label}. {NOTES}", glow={})
    for i, (name, build, size, label) in enumerate(
        (
            ("creature_puffin", creature_puffin, [2.6, 3.0, 2.6], "Pebble Puffin (uncommon)"),
            ("creature_otter", creature_otter, [4.0, 2.6, 5.8], "River Otter (rare)"),  # lies on its back: 9.3's 3.6 tall would be 7 long
            ("creature_capybara", creature_capybara, [3.2, 4.2, 4.6], "Spa Capybara (epic)"),
            ("creature_redpanda", creature_redpanda, [4.2, 5.0, 4.0], "Maple Red Panda (legendary)"),
            ("creature_peacock", creature_peacock, [5.0, 5.6, 4.0], "Jewel Peacock (mythic)"),
            ("creature_snowleopard", creature_snowleopard, [4.6, 5.8, 4.6], "Frost Leopard (divine)"),
        )
    )
] + [
    dict(name="egg_weekly", build=fit(egg_weekly), budget=2500, size=[2.2, 3, 2.2], priority=1, order=46, replaces="Plots.egg weekly (part fallback)", notes=f"Weekly Egg. {EGG_NOTES}"),
    dict(name="egg_monthly", build=fit(egg_monthly), budget=3000, size=[2.2, 3, 2.2], priority=1, order=47, replaces="Plots.egg monthly (part fallback)", notes=f"Monthly Egg. {EGG_NOTES}"),
]
