"""Better visuals for the spells: three directions, each shown on three spells (Sun Orb, Horn Lance, Shadow Claws),
with no particle effects. Importing this adds them to magic.CONCEPTS as v1_core, v2_element and v3_arcane.

1 Hot core: energy in layers, a white-hot core in a coloured body in a soft glowing edge (Roblox: Neon parts and a
  ForceField-material shell); rings close in as it charges; a sharp star flash and a crisp shock ring on the impact.
2 Elemental: the magic as stuff: flame tongues, a molten banded beam, ink tendrils, obsidian blades; glowing cracks.
3 Arcane: detailed magic circles (rune marks, turning polygons) the spell passes through; a sigil and a light pillar
  pin the target."""
import math
import random

from mathutils import Vector

import magic as M
from fxkit import bez, ease, env, seg
from magic import AMBER, DARK, EMBER, FIRE, GOLD, IMPACT, LAVA, ROCK, SHADOW, SUN, WHITE, YELLOW, Z, impact

UP = Vector((0, 0, 1))
TAU = math.tau
VIOLET_HOT = (0.85, 0.6, 1.0)


# -- shared pieces ------------------------------------------------------------------------------------------------
def basis(normal):
    n = normal.normalized()
    a = n.cross(Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))).normalized()
    return a, n.cross(a)


def to_cam(f, p):
    return (f.kit.cam_from - p).normalized()


def shell(f, p, r, rgb, glow, alpha):
    """a soft glowing edge round a shape (a ForceField-material shell in Roblox)"""
    ob = f.kit._obj("sphere", rgb, glow, alpha, p, scale=(r, r, r))
    if ob:
        ob.material_slots[0].material = f.kit.rim(rgb, glow, alpha)


def plasma(f, p, r, rgb, alpha=1.0, glow=8):
    """a ball of energy in three layers: a white-hot core, a coloured body, a glowing edge"""
    if alpha <= 0.01 or r <= 0.001:
        return
    f.kit.orb(p, r * 0.42, WHITE, glow * 1.3, alpha, core=False)
    f.kit.orb(p, r * 0.8, rgb, glow, 0.5 * alpha, core=False)
    shell(f, p, r * 1.4, rgb, glow * 0.7, 0.8 * alpha)


def rod(f, a, b, r, rgb, alpha=1.0, glow=8):
    """a beam in the same three layers"""
    if alpha <= 0.01 or (b - a).length < 1e-3:
        return
    f.kit.beam(a, b, r * 0.32, WHITE, glow * 1.3, alpha, core=False)
    f.kit.beam(a, b, r * 0.75, rgb, glow, 0.5 * alpha, core=False)
    mid, q, n = f.kit._along(a, b)
    ob = f.kit._obj("cyl", rgb, glow, alpha, mid, rot=q, scale=(r * 1.35, r * 1.35, n))
    if ob:
        ob.material_slots[0].material = f.kit.rim(rgb, glow * 0.7, 0.8 * alpha)


def star(f, p, R, rgb, alpha, n=8, spin=0.3):
    """an impact flash: thin streaks out from p, facing the camera, long and short in turn"""
    if alpha <= 0.01:
        return
    a, b = basis(to_cam(f, p))
    for i in range(n):
        ang = spin + i / n * TAU
        d = a * math.cos(ang) + b * math.sin(ang)
        L = R * (1.0 if i % 2 == 0 else 0.5)
        f.kit.spike(p, p + d * L, 0.05 * R, WHITE, 11, alpha)
        f.kit.spike(p, p + d * L * 0.85, 0.11 * R, rgb, 7, 0.55 * alpha)
    plasma(f, p, 0.25 * R, rgb, alpha)


def shock(f, p, R, w, rgb, alpha, normal=UP):
    """a crisp shock ring: a bright leading edge with a fainter wash behind it"""
    if alpha <= 0.01:
        return
    f.kit.ring(p, R, w, WHITE, 9, alpha, normal=normal)
    f.kit.ring(p, R * 0.94, w * 2.0, rgb, 6, 0.55 * alpha, normal=normal)
    f.kit.ring(p, R * 0.8, w * 0.7, rgb, 4, 0.25 * alpha, normal=normal)


def converge(f, p, R, rgb, t, t0, t1, n=3):
    """rings closing in on p as it charges, facing the camera"""
    u0 = seg(t, t0, t1)
    if u0 is None:
        return
    for i in range(n):
        u = (u0 * 2.2 + i / n) % 1
        f.kit.ring(p, R * (1 - u) + 0.05, 0.05 * R * (0.6 + u), rgb, 7, u * 0.9, normal=to_cam(f, p), n=28)


RUNES = [  # rune strokes in a unit box (x across, y up), each a polyline
    [[(0, -0.5), (0, 0.5)], [(0, 0.2), (0.35, 0.5)], [(0, -0.05), (0.35, 0.25)]],
    [[(0, -0.5), (0, 0.5)], [(0, 0.5), (0.35, 0.25), (0, 0)]],
    [[(-0.3, -0.5), (0, 0.5), (0.3, -0.5)], [(-0.18, -0.1), (0.18, -0.1)]],
    [[(0, -0.5), (0, 0.5)], [(-0.3, 0.3), (0.3, -0.1)]],
    [[(-0.3, 0.5), (0.3, -0.5)], [(0.3, 0.5), (-0.3, -0.5)]],
    [[(0, -0.5), (0, 0.5)], [(0, 0.1), (-0.3, 0.45)], [(0, 0.1), (0.3, 0.45)]],
    [[(-0.25, -0.5), (-0.25, 0.5), (0.25, 0.2), (-0.25, -0.1)]],
]


def glyph(f, c, size, a, b, rgb, glow, alpha, seed, w=0.035):
    for stroke in RUNES[seed % len(RUNES)]:
        f.kit.tube([c + (a * x + b * y) * size for x, y in stroke], w * size / 0.5 * 0.5, rgb, glow, alpha)


def polygon(f, c, R, sides, a, b, spin, rgb, glow, alpha, w, step=1):
    pts = [c + (a * math.cos(spin + i * step / sides * TAU) + b * math.sin(spin + i * step / sides * TAU)) * R for i in range(sides)]
    f.kit.tube(pts, w, rgb, glow, alpha, closed=True)


def sigil(f, c, R, rgb, spin, alpha, normal=UP, glyphs=12, seed=1):
    """a detailed magic circle: a double outer ring, a band of runes, a turning hexagram, an inner ring"""
    if alpha <= 0.01 or R <= 0.01:
        return
    a, b = basis(normal)
    c = c + normal.normalized() * 0.04
    f.kit.ring(c, R, 0.035 * R, rgb, 8, alpha, normal=normal, n=40)
    f.kit.ring(c, R * 0.93, 0.018 * R, WHITE, 9, alpha, normal=normal, n=40)
    for i in range(glyphs):
        ang = -spin * 0.5 + i / glyphs * TAU
        d = a * math.cos(ang) + b * math.sin(ang)
        tang = a * -math.sin(ang) + b * math.cos(ang)
        glyph(f, c + d * R * 0.81, R * 0.11, tang, d, rgb, 8, alpha, seed + i, w=0.03)
    f.kit.ring(c, R * 0.68, 0.025 * R, rgb, 8, alpha, normal=normal, n=36)
    polygon(f, c, R * 0.66, 3, a, b, spin, rgb, 8, alpha, 0.02 * R)
    polygon(f, c, R * 0.66, 3, a, b, spin + math.pi, rgb, 8, alpha, 0.02 * R)
    polygon(f, c, R * 0.33, 6, a, b, -spin * 1.5, WHITE, 9, alpha * 0.8, 0.015 * R)
    f.kit.ring(c, R * 0.18, 0.02 * R, rgb, 9, alpha, normal=normal, n=20)


def pillar(f, base, r, h, rgb, alpha):
    """a pillar of light standing on base"""
    if alpha <= 0.01:
        return
    rod(f, base, base + Z(h), r * 0.55, rgb, 0.55 * alpha)


def cracks(f, c, R, rgb, seed, grow, alpha, n=7, k=1.0):
    """jagged glowing cracks out across the ground from c"""
    if alpha <= 0.01 or grow <= 0.01:
        return
    rng = random.Random(seed)
    for i in range(n):
        ang = i / n * TAU + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        side = Vector((-d.y, d.x, 0))
        L = R * rng.uniform(0.6, 1.0) * grow
        pts = [c + Z(0.04) + d * L * j / 6 + side * rng.uniform(-0.12, 0.12) * R * (j > 0) for j in range(7)]
        f.kit.tube(pts, 0.14 * k, DARK, 0.0, alpha, taper=lambda x: 1 - 0.8 * x)
        f.kit.tube(pts, 0.06 * k, rgb, 9, alpha, taper=lambda x: 1 - 0.8 * x)


def flame(f, base, tip, r, rgb, alpha, core=YELLOW):
    """a flame tongue: a coloured cone with a hot core inside"""
    if alpha <= 0.01 or (tip - base).length < 1e-3:
        return
    f.kit.spike(base, tip, r, rgb, 6, 0.75 * alpha)
    f.kit.spike(base, base.lerp(tip, 0.6), r * 0.45, core, 9, alpha)


def tendril(f, base, h, phase, t, r, alpha, sway, k):
    """a writhing tendril of shadow: dark, edged in violet light"""
    if alpha <= 0.01 or h <= 0.01:
        return
    pts = []
    for j in range(9):
        u = j / 8
        pts.append(base + Z(h * u) + Vector((math.sin(u * 3 + phase + t * 6), math.cos(u * 2.4 + phase * 1.3 + t * 5), 0)) * sway * u * k)
    f.kit.tube(pts, r, DARK, 0.3, alpha, taper=lambda x: 1 - 0.85 * x)
    f.kit.tube(pts, r * 1.15, SHADOW, 6, 0.35 * alpha, taper=lambda x: 1 - 0.85 * x)


def facing(f, d, p):
    """a circle across the path d, turned halfway to the camera so it reads from the side (in the game: along d)"""
    return (d.normalized() + to_cam(f, p) * 1.3).normalized()


def hands_of(f):
    return (f.A["paw_l"] + f.A["paw_r"]) / 2 + Z(0.5 * f.k)


# -- Sun Orb ---------------------------------------------------------------------------------------------------------
def sun_core(f):
    k, t = f.k, f.t
    hands = hands_of(f)
    grow = seg(t, 0.2, 0.7)
    if grow is not None:
        plasma(f, hands, 0.9 * k * ease(grow), SUN, 1)
        f.kit.light(hands, SUN, 4 * ease(grow))
    converge(f, hands, 3 * k, SUN, t, 0.2, 0.68)
    u = seg(t, 0.7, IMPACT)
    if u is not None:
        c = (hands + f.TC) / 2 + Z(2.5 * k)
        p = bez(hands, c, f.TC, u)
        plasma(f, p, 0.9 * k, SUN, 1)
        pts = [bez(hands, c, f.TC, max(0.0, u - i * 0.035)) for i in range(9)]
        f.kit.trail(pts, 0.8 * k, SUN, 6, 0.45)
        f.kit.trail(pts, 0.25 * k, WHITE, 9, 0.85)
        f.kit.light(p, SUN, 5)
    u = seg(t, IMPACT, IMPACT + 0.45)
    if u is not None:
        star(f, f.TC, 4.5 * k * (0.6 + 0.4 * ease(min(1, u * 4))), SUN, (1 - u) ** 1.5)
        plasma(f, f.TC, 1.3 * k * (1 - u), SUN, 1 - u)
        shock(f, f.T + Z(0.08), (0.8 + 6 * ease(u)) * k, 0.1 * k, SUN, 1 - u)
        f.kit.light(f.TC, SUN, 10 * (1 - u) * k * k)


def sun_element(f):
    k, t = f.k, f.t
    hands = hands_of(f)

    def sun(p, R, back=None, alpha=1.0):  # a churning sun: a core in a corona of flame tongues
        f.kit.orb(p, R, SUN, 8, alpha, core=True)
        for i in range(10):
            ang = i / 10 * TAU + t * 2.5
            d = Vector((0.3 * math.sin(ang * 1.7), math.cos(ang), math.sin(ang))).normalized()
            if back is not None:  # in flight the tongues stream back
                d = (d * 0.6 + back * 1.0).normalized()
            L = R * (1.0 + 0.45 * math.sin(t * 17 + i * 2.1))
            flame(f, p + d * R * 0.7, p + d * (R + L), R * 0.32, FIRE, alpha, core=YELLOW)
        f.kit.ring(p, R * 1.5, 0.05 * R, EMBER, 6, 0.5 * alpha, normal=to_cam(f, p))

    grow = seg(t, 0.2, 0.7)
    if grow is not None:
        sun(hands, 0.8 * k * ease(grow))
        f.kit.light(hands, FIRE, 4 * ease(grow))
    u = seg(t, 0.7, IMPACT)
    if u is not None:
        c = (hands + f.TC) / 2 + Z(2.5 * k)
        p = bez(hands, c, f.TC, u)
        q = bez(hands, c, f.TC, max(0.0, u - 0.05))
        sun(p, 0.8 * k, back=(q - p).normalized() if (q - p).length > 1e-4 else None)
        pts = [bez(hands, c, f.TC, max(0.0, u - i * 0.04)) for i in range(8)]
        f.kit.trail(pts, 0.7 * k, EMBER, 5, 0.5)
        f.kit.light(p, FIRE, 5)
    u = seg(t, IMPACT, 1.5)
    if u is not None:  # it bursts into flame and scorches the ground
        g = ease(min(1, u * 3)) * (1 - ease(max(0, (u - 0.5) / 0.5)))
        for i in range(12):
            ang = i / 12 * TAU
            d = Vector((math.cos(ang), math.sin(ang), 0.9 + 0.4 * math.sin(i * 2.3))).normalized()
            flame(f, f.T + Z(0.3), f.T + Z(0.3) + d * (2.5 + 1.2 * math.sin(i)) * k * g, 0.55 * k * g, FIRE, g)
        f.kit.disc(f.T, 3.2 * k * min(1, u * 4), DARK, 0, 0.7 * (1 - u))
        cracks(f, f.T, 3.5 * k, EMBER, 11, min(1, u * 4), 1 - u, k=k)
        f.kit.light(f.TC, FIRE, 9 * (1 - u) * k * k)


def sun_arcane(f):
    k, t = f.k, f.t
    hands = hands_of(f)
    fwd = (f.TC - hands).normalized()
    form = env(t, 0.15, 0.4, 0.75, 0.9)
    sigil(f, hands + fwd * 0.4 * k, 1.6 * k * form, GOLD, t * 2.4, form, normal=facing(f, fwd, hands), glyphs=10, seed=3)
    sigil(f, Vector((hands.x, hands.y, f.T.z)), 2.6 * k * form, GOLD, -t * 1.5, 0.8 * form, glyphs=14, seed=5)
    grow = seg(t, 0.25, 0.7)
    if grow is not None:
        f.kit.orb(hands + fwd * 0.4 * k, 0.7 * k * ease(grow), SUN, 8, 1)
    gates = [(1 / 3, 0), (2 / 3, 1)]
    u = seg(t, 0.62, 1.15)
    if u is not None:  # two gates stand on its path and flash as it passes through
        line = 1 - ease(max(0, (u - 0.6) / 0.4))
        f.kit.beam(hands, f.TC, 0.03 * k, GOLD, 8, 0.6 * line, core=False)
        for s, i in gates:
            q = hands.lerp(f.TC, s) + Z(math.sin(s * math.pi) * 1.2 * k)
            fly = seg(t, 0.7, IMPACT)
            passed = fly is not None and abs(fly - s) < 0.12
            sigil(f, q, 1.1 * k, WHITE if passed else GOLD, t * 3 + i, line * (1.0 if passed else 0.7), normal=facing(f, fwd, q), glyphs=8, seed=7 + i)
    u = seg(t, 0.7, IMPACT)
    if u is not None:
        p = hands.lerp(f.TC, u) + Z(math.sin(u * math.pi) * 1.2 * k)
        f.kit.orb(p, 0.75 * k, SUN, 9, 1, light=4)
    u = seg(t, IMPACT, 1.55)
    if u is not None:  # a sigil pins the target and a pillar of light stands on it
        g = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
        sigil(f, f.T, 3.4 * k * (0.7 + 0.3 * ease(min(1, u * 3))), GOLD, t * 2, g, glyphs=16, seed=9)
        pillar(f, f.T, 1.3 * k * g, f.sky * 1.1, SUN, g)
        for j in range(3):  # rune rings rise up the pillar
            h = ((u * 1.6 + j / 3) % 1) * f.sky * 0.8
            f.kit.ring(f.T + Z(h), 1.8 * k, 0.04 * k, GOLD, 8, g * (1 - h / (f.sky * 0.8)), n=24)
    impact(f, SUN, 3, 41, ring=False)


# -- Horn Lance ------------------------------------------------------------------------------------------------------
def lance_reach(t):
    return ease(min(1, (t - 0.86) / (IMPACT - 0.86))) if t >= 0.86 else 0.0


def lance_core(f):
    k, t = f.k, f.t
    horn = f.A["horn"]
    charge = env(t, 0.2, 0.8, 0.86, 0.9)
    if charge > 0:
        plasma(f, horn, 0.6 * k * charge, AMBER, 1)
        f.kit.light(horn, AMBER, 3 * charge)
    converge(f, horn, 2.6 * k, AMBER, t, 0.2, 0.84)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        end = horn.lerp(f.TC, lance_reach(t))
        w = 0.6 * k * (1 - ease(max(0, (t - 1.0) / 0.2))) * (1 + 0.12 * math.sin(t * 60))
        rod(f, horn, end, w, AMBER, 1)
        star(f, horn, 1.6 * k, AMBER, 0.8 * (1 - u), n=6)  # the flash at the horn as it fires
        f.kit.light(end, AMBER, 6)
    u = seg(t, IMPACT, IMPACT + 0.45)
    if u is not None:
        star(f, f.TC, 4 * k, AMBER, (1 - u) ** 1.5)
        shock(f, f.TC, (0.6 + 4 * ease(u)) * k, 0.08 * k, AMBER, 1 - u, normal=f.TC - horn)
        shock(f, f.T + Z(0.08), (0.8 + 5 * ease(u)) * k, 0.09 * k, AMBER, 1 - u)


def lance_element(f):
    k, t = f.k, f.t
    horn = f.A["horn"]
    charge = env(t, 0.2, 0.8, 0.86, 0.9)
    if charge > 0:  # the horn glows white-hot and drips molten rock
        f.kit.orb(horn, 0.45 * k * charge, LAVA, 8, 1)
        for i in range(4):
            v = (t * 1.6 + i / 4) % 1
            f.kit.ball(horn + Vector((0.2 * math.sin(i * 2), 0, -v * 1.6)) * k, 0.12 * k * (1 - v), LAVA, 7, charge)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        end = horn.lerp(f.TC, lance_reach(t))
        w = 0.5 * k * (1 - ease(max(0, (t - 1.0) / 0.2)))
        d = end - horn
        if d.length > 1e-3:
            f.kit.beam(horn, end, w * 0.5, (1.0, 0.78, 0.35), 9, 1, core=False)
            f.kit.beam(horn, end, w, LAVA, 7, 0.7, core=False)
            a, b = basis(d)
            for s in (0, math.pi):  # two dark molten bands winding round it
                pts = [horn + d * (j / 24) + (a * math.cos(s + j * 0.7 - t * 30) + b * math.sin(s + j * 0.7 - t * 30)) * w * 1.05 for j in range(25)]
                f.kit.tube(pts, 0.16 * w, (0.16, 0.04, 0.02), 0.0, 0.9)
            for i in range(6):  # embers thrown off it
                v = (t * 4 + i / 6) % 1
                q = horn + d * ((i + 0.5) / 6) + (a * math.cos(i * 2.3) + b * math.sin(i * 2.3)) * w * (1 + 3 * v) + Z(-2 * v * v * k)
                f.kit.ball(q, 0.12 * k * (1 - v), EMBER, 6, 1 - v)
        f.kit.light(end, LAVA, 6)
    u = seg(t, IMPACT, 1.55)
    if u is not None:  # a molten splash: glowing cracks, a dark crater, rock thrown out
        g = min(1, u * 4)
        f.kit.disc(f.T, 2.4 * k * g, DARK, 0, 0.7 * (1 - u))
        cracks(f, f.T, 4 * k, LAVA, 23, g, 1 - u, n=8, k=k)
        for i in range(7):
            ang = i / 7 * TAU
            q = f.T + Vector((math.cos(ang), math.sin(ang), 0)) * (1 + 3 * u) * k + Z((2.5 * u - 3 * u * u) * k + 0.3)
            f.kit.ball(q, 0.3 * k, ROCK, 0, 1 - u)
            f.kit.ball(q, 0.16 * k, LAVA, 7, 1 - u)
    impact(f, LAVA, 3, 29, ring=False)


def lance_arcane(f):
    k, t = f.k, f.t
    horn = f.A["horn"]
    d = (f.TC - horn).normalized()
    form = env(t, 0.15, 0.45, 1.0, 1.2)
    sigil(f, horn + d * 0.8 * k, 1.5 * k * form, AMBER, t * (2 + 8 * env(t, 0.5, 0.85, 1, 1.2)), form, normal=facing(f, d, horn), glyphs=10, seed=13)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        reach = lance_reach(t)
        end = horn.lerp(f.TC, reach)
        w = 0.4 * k * (1 - ease(max(0, (t - 1.0) / 0.2)))
        f.kit.beam(horn, end, w, AMBER, 9, 1)
        for i, s in enumerate((0.38, 0.68)):  # the beam passes through two more circles on its way
            if reach > s:
                q = horn.lerp(f.TC, s)
                sigil(f, q, 1.0 * k * (1 - 0.3 * i), AMBER, -t * 4 + i, 1 - ease(max(0, (t - 1.05) / 0.15)), normal=facing(f, d, q), glyphs=8, seed=15 + i)
        f.kit.light(end, AMBER, 6)
    u = seg(t, IMPACT, 1.55)
    if u is not None:
        g = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
        sigil(f, f.TC - d * 0.4 * k, 2.2 * k * (0.6 + 0.4 * ease(min(1, u * 3))), AMBER, t * 3, g, normal=facing(f, -d, f.TC), glyphs=12, seed=19)
        sigil(f, f.T, 3.0 * k, AMBER, -t * 2, g, glyphs=14, seed=21)
        pillar(f, f.T, 1.0 * k * g, f.sky, AMBER, g)
    impact(f, AMBER, 3, 31, ring=False)


# -- Shadow Claws ----------------------------------------------------------------------------------------------------
def claw_curve(f, x, g):
    base = f.T + Vector((x, 2.2 * f.k, 0))
    return [base + Vector((0, -(1 - math.cos(a)) * 3.6, math.sin(a) * 5.6)) * f.k * g for a in [j / 10 * 1.4 for j in range(11)]]


def claw_grow(u, i):
    g = ease(min(1, (u - i * 0.05) * 5)) if u > i * 0.05 else 0
    return g * (1 - ease(max(0, (u - 0.7) / 0.3)))


def pool_reach(t):
    spread = seg(t, 0.3, 0.86)
    return ease(spread) if spread is not None else (1.0 if t > 0.86 else 0.0)


def claws_core(f):
    k, t = f.k, f.t
    paws = (f.A["paw_l"] + f.A["paw_r"]) / 2
    paws.z = f.T.z
    reach, fade = pool_reach(t), 1 - ease(max(0, (t - 1.25) / 0.3))
    if reach > 0 and fade > 0:  # the pool: dark, with a crisp bright edge, rings closing on the target
        for s in range(6):
            p = paws.lerp(f.T, reach * s / 5)
            f.kit.disc(p, (1.0 + 1.6 * s / 5) * k, DARK, 0, 0.85 * fade)
        f.kit.ring(f.T + Z(0.06), 2.6 * k * reach, 0.05 * k, VIOLET_HOT, 10, fade)
        f.kit.ring(f.T + Z(0.06), 2.6 * k * reach * 0.96, 0.12 * k, SHADOW, 6, 0.5 * fade)
    converge(f, f.TC, 3 * k, SHADOW, t, 0.45, 0.88)
    u = seg(t, 0.88, 1.5)
    if u is not None:  # three claws: a dark core, a violet glowing edge, a white-hot rim along the cutting side
        for i in range(3):
            g = claw_grow(u, i)
            if g <= 0:
                continue
            pts = claw_curve(f, (i - 1) * 1.0 * k, g)
            f.kit.tube(pts, 0.55 * k, DARK, 0.3, 1, taper=lambda x: 1 - 0.9 * x)
            f.kit.tube(pts, 0.7 * k, SHADOW, 6, 0.4, taper=lambda x: 1 - 0.9 * x)
            edge = [p + Vector((0, -0.45 * k * (1 - j / 10), 0)) for j, p in enumerate(pts)]
            f.kit.tube(edge, 0.09 * k, VIOLET_HOT, 11, 1, taper=lambda x: 1 - 0.9 * x)
    u = seg(t, IMPACT, IMPACT + 0.45)
    if u is not None:
        star(f, f.TC, 4 * k, SHADOW, (1 - u) ** 1.5)
        shock(f, f.T + Z(0.08), (0.8 + 5 * ease(u)) * k, 0.09 * k, SHADOW, 1 - u)


def claws_element(f):
    k, t = f.k, f.t
    paws = (f.A["paw_l"] + f.A["paw_r"]) / 2
    paws.z = f.T.z
    reach, fade = pool_reach(t), 1 - ease(max(0, (t - 1.25) / 0.3))
    if reach > 0 and fade > 0:  # ink spreads, and tendrils of shadow writhe up round the target
        for s in range(6):
            p = paws.lerp(f.T, reach * s / 5)
            f.kit.disc(p, (1.0 + 1.6 * s / 5) * k, DARK, 0, 0.9 * fade)
        cracks(f, f.T, 3.5 * k, SHADOW, 37, reach, fade, n=8, k=k)
        for i in range(6):
            ang = i / 6 * TAU + 0.3
            base = f.T + Vector((math.cos(ang), math.sin(ang), 0)) * 2.1 * k
            h = (1.5 + 0.8 * math.sin(i * 1.7)) * k * ease(max(0, (reach - 0.5) * 2)) * fade
            tendril(f, base, h, i * 1.9, t, 0.28 * k, fade, 0.5, k)
    u = seg(t, 0.88, 1.5)
    if u is not None:  # obsidian blades with violet light in their cracks
        for i in range(3):
            g = claw_grow(u, i)
            if g <= 0:
                continue
            pts = claw_curve(f, (i - 1) * 1.0 * k, g)
            f.kit.tube(pts, 0.62 * k, (0.06, 0.04, 0.09), 0.0, 1, taper=lambda x: 1 - 0.9 * x)
            seam = [p + Vector((0.32 * k, 0, 0)) for p in pts]
            f.kit.tube(seam, 0.07 * k, VIOLET_HOT, 10, 1, taper=lambda x: 1 - 0.9 * x)
            f.kit.tube([p + Vector((-0.32 * k, 0, 0)) for p in pts], 0.07 * k, VIOLET_HOT, 10, 1, taper=lambda x: 1 - 0.9 * x)
    impact(f, SHADOW, 3, 43, ring=False)


def claws_arcane(f):
    k, t = f.k, f.t
    paws = (f.A["paw_l"] + f.A["paw_r"]) / 2
    paws.z = f.T.z
    reach, fade = pool_reach(t), 1 - ease(max(0, (t - 1.25) / 0.3))
    if reach > 0 and fade > 0:  # a dark sigil runs from its paws and opens under the target
        f.kit.beam(paws + Z(0.05), paws.lerp(f.T, reach) + Z(0.05), 0.06 * k, SHADOW, 8, fade, core=False)
        sigil(f, paws, 1.6 * k * min(1, reach * 3), SHADOW, -t * 2, fade, glyphs=10, seed=27)
        sigil(f, f.T, 3.2 * k * reach, SHADOW, t * 2.5, fade, glyphs=16, seed=29)
    u = seg(t, 0.88, 1.5)
    if u is not None:  # the claws: blades of light drawn out of the sigil
        for i in range(3):
            g = claw_grow(u, i)
            if g <= 0:
                continue
            pts = claw_curve(f, (i - 1) * 1.0 * k, g)
            f.kit.tube(pts, 0.32 * k, SHADOW, 8, 0.8, taper=lambda x: 1 - 0.9 * x)
            f.kit.tube(pts, 0.12 * k, WHITE, 10, 1, taper=lambda x: 1 - 0.9 * x)
    u = seg(t, IMPACT, 1.55)
    if u is not None:  # a sigil pins the target and a dark pillar stands on it
        g = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
        sigil(f, f.TC + Vector((0, 0.6 * k, 0)), 2.0 * k, SHADOW, t * 3, g, normal=facing(f, Vector((0, 1, 0)), f.TC), glyphs=12, seed=31)
        pillar(f, f.T, 1.1 * k * g, f.sky, SHADOW, g)
    impact(f, SHADOW, 3, 47, ring=False)


# -- added to the spells' table ----------------------------------------------------------------------------------------
DIRECTIONS = [("v1_core", "1 Hot core"), ("v2_element", "2 Elemental"), ("v3_arcane", "3 Arcane")]
EXTRA = {
    "creature_meerkat_forge": ("Sun Orb", M.SUN_THROW, [sun_core, sun_element, sun_arcane]),
    "creature_rhino_forge": ("Horn Lance", M.LANCE_KEYS, [lance_core, lance_element, lance_arcane]),
    "creature_lion_shadow_forge": ("Shadow Claws", M.SHADOW_KEYS, [claws_core, claws_element, claws_arcane]),
}
TEXT = {
    "v1_core": "Energy in layers: a white-hot core in a coloured body in a soft glowing edge; rings close in as it charges; a sharp star flash and a crisp shock ring on the hit.",
    "v2_element": "The magic as stuff: flame tongues, molten bands and embers, ink tendrils and obsidian blades; the ground cracks and glows.",
    "v3_arcane": "Detailed magic circles with rune marks and turning polygons that the spell passes through; a sigil and a pillar of light pin the target.",
}
for asset, (spell, keys, draws) in EXTRA.items():
    for (key, label), draw in zip(DIRECTIONS, draws):
        M.CONCEPTS[asset][1][key] = (f"{spell}: {label}", TEXT[key], keys, {}, draw)
