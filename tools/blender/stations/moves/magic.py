"""Magic power attacks: two for each base animal, one for each variant. Each is (label, text, keys, flags,
draw): the body's keys (1.6 s, the impact at 0.92 s, as concepts.py) and draw(f), which adds the spell's
effects for the frame at clip time f.t (see render_magic.Frame and fxkit.Kit)."""
import math

from mathutils import Vector

from concepts import P, crouch
import fxkit
from fxkit import bez, ease, env, mix, seg

IMPACT = 0.92
Z = lambda z: Vector((0, 0, z))  # noqa: E731

SILVER, MOON, JADE, SUN, WHITE = (0.8, 0.88, 1.0), (0.55, 0.75, 1.0), (0.25, 1.0, 0.55), (1.0, 0.75, 0.2), (1, 1, 1)
MINT, AMBER, PINK, AQUA, GOLD = (0.55, 1.0, 0.8), (1.0, 0.5, 0.12), (1.0, 0.4, 0.75), (0.3, 0.85, 1.0), (1.0, 0.72, 0.15)
LAV, VIOLET, TURQ, SAND, ROSE = (0.72, 0.6, 1.0), (0.6, 0.25, 1.0), (0.15, 1.0, 0.9), (0.95, 0.75, 0.42), (1.0, 0.3, 0.5)
SEA, LEAF, STAR, ALIEN, ELEC = (0.15, 0.55, 1.0), (0.35, 0.9, 0.25), (1.0, 0.88, 0.35), (0.35, 1.0, 0.25), (0.35, 0.8, 1.0)
YELLOW, STORM, LAVA, FIRE, FROST = (1.0, 0.9, 0.2), (0.55, 0.4, 1.0), (1.0, 0.32, 0.03), (1.0, 0.45, 0.08), (0.6, 0.92, 1.0)
EMBER, SHADOW, DIAMOND, ROCK, DARK = (1.0, 0.25, 0.08), (0.6, 0.2, 1.0), (0.45, 0.8, 1.0), (0.3, 0.27, 0.26), (0.05, 0.02, 0.08)
RAINBOW = [(1, 0.2, 0.2), (1, 0.55, 0.1), (1, 0.95, 0.2), (0.3, 1, 0.3), (0.2, 0.7, 1), (0.35, 0.3, 1), (0.85, 0.3, 1)]


def impact(f, rgb, R=3.0, seed=1, ring=True, flash=True):
    """the hit at the dummy: a flash, a ring rolling out on the ground, sparks (hot: a star flash and crisp rings)"""
    u = seg(f.t, IMPACT, IMPACT + 0.5)
    if u is None:
        return
    k = f.k
    if fxkit.HOT:
        if flash:
            f.kit.star(f.TC, 4 * k * (0.6 + 0.4 * ease(min(1, u * 4))), rgb, (1 - u) ** 1.5)
            f.kit.light(f.TC, rgb, 8 * (1 - u) * k * k)
        if ring:
            f.kit.shock(f.T + Z(0.08), (0.6 + R * 1.4 * ease(u)) * k, 0.09 * k, rgb, 1 - u)
        f.kit.burst(f.TC, u, 12, 4 * k, rgb, seed, 0.12 * k)
        return
    if flash:
        f.kit.orb(f.TC + Vector((0, 0.6, 0)) * k, (0.4 + 1.0 * ease(min(1, u * 3))) * k, rgb, 6, 0.75 * (1 - u) ** 2)
        f.kit.light(f.TC, rgb, 8 * (1 - u) * k * k)
    if ring:
        f.kit.ring(f.T + Z(0.1), (0.5 + R * ease(u)) * k, 0.12 * k, rgb, 6, 1 - u)
    f.kit.burst(f.TC, u, 16, 4 * k, rgb, seed, 0.14 * k)


def flight(f, a, b, t0, t1, height, draw_at, trail=None, n=8):
    """something drawn at points along a curve from a to b between t0 and t1, with a trail behind it"""
    u = seg(f.t, t0, t1)
    if u is None:
        return None
    p = bez(a, (a + b) / 2 + Z(height), b, u)
    draw_at(p, u)
    if trail:
        rgb, w = trail
        f.kit.trail([bez(a, (a + b) / 2 + Z(height), b, max(0.0, u - i * 0.03)) for i in range(n)], w, rgb, 4, 0.55)
    return p


# ============================================================================================= base animals
# ---- jackal: moonlight and spirits -------------------------------------------------------------------------------
HOWL_SIT = [
    (0.00, {}),
    (0.30, P(body=[22, 0, 0, 0, -0.05, 0.25], leg_fl=[-20], leg_fr=[-20], leg_bl=[26], leg_br=[26], head=[38], tail=[24])),
    (0.72, P(body=[26, 0, 0, 0, -0.05, 0.25], leg_fl=[-24], leg_fr=[-24], leg_bl=[28], leg_br=[28], head=[56], tail=[26, 10])),
    (0.86, P(body=[-4, 0, 0, 0, 0, -0.15], leg_fl=[-6], leg_fr=[-6], leg_bl=[4], leg_br=[4], head=[-22], tail=[-10])),
    (1.10, P(body=[-2, 0, 0, 0, 0, -0.1], head=[-10])),
    (1.60, {}),
]


def moonfang(f):
    k, t = f.k, f.t
    howl = env(t, 0.25, 0.4, 0.75, 0.86)
    f.kit.aura(MOON, 0.22 * howl)
    for i in range(3):  # its howl: rings rising off its muzzle
        u = seg(t, 0.3 + i * 0.15, 0.75 + i * 0.05)
        if u is not None:
            f.kit.ring(f.A["nose"] + Z((0.3 + 3 * u) * k), (0.3 + 1.2 * u) * k, 0.05 * k, SILVER, 5, (1 - u) * 0.8)
    top = f.TC + Z(f.sky * 0.6)
    grow = env(t, 0.3, 0.75, 2, 3)
    drop = seg(t, 0.8, IMPACT)
    if t < 0.8 and grow > 0:  # the crescent forms in the sky over the dummy
        f.kit.crescent(top, 2.2 * k * grow, 0.22 * k, SILVER, Vector((1, 0, 0)), Vector((0, 0, -1)), 7, grow)
        f.kit.orb(top + Z(0.4 * k), 0.4 * k * grow, MOON, 5, 0.5 * grow, core=False)
        f.kit.light(top, MOON, 3 * grow)
    elif drop is not None:  # falls blade-first onto it
        p = top.lerp(f.T + Z(1.6 * k), ease(drop))
        f.kit.crescent(p, 2.2 * k, 0.22 * k, SILVER, Vector((1, 0, 0)), Vector((0, 0, -1)), 9)
        f.kit.trail([top.lerp(f.T + Z(1.6 * k), ease(max(0, drop - i * 0.1))) for i in range(7)], 0.5 * k, MOON, 3, 0.3)
    stuck = seg(t, IMPACT, 1.45)
    if stuck is not None:  # it bites into the ground and fades
        f.kit.crescent(f.T + Z(1.4 * k), 2.2 * k, 0.22 * k, SILVER, Vector((1, 0, 0)), Vector((0, 0, -1)), 7, 1 - stuck)
    impact(f, SILVER, 3.5, 3)


SPIRIT_LEAP = P(body=[8, 0, 0, 0, 0.3, 0], leg_fl=[52], leg_fr=[48], leg_bl=[-36], leg_br=[-36], tail=[-26], head=[-6])


def spirit_pack(f):
    k, t = f.k, f.t
    f.kit.aura(AQUA, 0.2 * env(t, 0.25, 0.45, 0.8, 0.95))
    for side in (1, -1):
        u = seg(t, 0.45, 1.05)
        if u is None:
            continue
        start = Vector((side * 0.35 * f.L, 0.2 * f.L, 0))
        end = (f.T - f.kit.r.mid) * (1 / f.U) + Vector((side * 0.2 * f.L, -0.15 * f.L, 0))
        end.z = 0
        arc = (0.75 if side > 0 else 0.2) * f.H
        p = bez(start, (start + end) / 2 + Z(arc), end, ease(u))
        fade = env(t, 0.45, 0.55, 0.95, 1.05)
        f.kit.ghost(SPIRIT_LEAP, p, (0.3, 0.75, 1.0), 5, 0.9 * fade, scale=0.85, now=f.pose)
        tail = [f.kit.r.mid + bez(start, (start + end) / 2 + Z(arc), end, ease(max(0, u - i * 0.04))) * f.U for i in range(8)]
        f.kit.trail(tail, 0.5 * k, AQUA, 4, 0.4 * fade)
    impact(f, AQUA, 3.5, 5)
    u = seg(t, IMPACT, 1.3)
    if u is not None:  # blue spirit flames on the dummy
        for i in range(6):
            a = i / 6 * math.tau + t * 3
            f.kit.spike(f.T + Vector((math.cos(a), math.sin(a), 0)) * 0.9 * k, f.T + Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 0)) * k + Z((2 + 1.5 * math.sin(i)) * k * (1 - u)), 0.3 * k, AQUA, 6, 0.7 * (1 - u))


# ---- tortoise: jade runes and stone ------------------------------------------------------------------------------
REAR_SLAM = [
    (0.00, {}),
    (0.40, P(body=[16, 0, 0, 0, 0.25, 0.15], leg_fl=[45], leg_fr=[45], leg_bl=[-16], leg_br=[-16], head=[10], tail=[-8])),
    (0.56, P(body=[-8, 0, 0, 0, -0.1, -0.2], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], head=[-14])),
    (0.92, P(body=[-6, 0, 0, 0, -0.08, -0.15], leg_fl=[-10], leg_fr=[-10], leg_bl=[6], leg_br=[6], head=[-10])),
    (1.20, P(body=[-2, 0, 0, 0, 0, -0.05], head=[-4])),
    (1.60, {}),
]


def rune_pillars(f):
    k, t = f.k, f.t
    f.kit.aura(JADE, 0.25 * env(t, 0.1, 0.35, 0.5, 0.65))
    a = f.A["chest"].copy()
    a.z = f.T.z
    n = 5
    for i in range(n):
        u0 = 0.56 + (IMPACT - 0.56) * i / (n - 1)
        u = seg(t, u0, u0 + 0.75)
        if u is None:
            continue
        p = a.lerp(f.T, (i + 1) / n) if i < n - 1 else f.T + Vector((0, -0.2, 0)) * k
        big = 1.6 if i == n - 1 else 1.0
        h = (2.2 + 0.7 * i) * big * k * ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
        if i == n - 1:  # the last rises right under the dummy and lifts it
            f.dummy = Z(h * 0.5)
        off = Vector((0.9 if i % 2 else -0.9, 0, 0)) * k if i < n - 1 else Vector()
        base = p + off
        f.kit.beam(base, base + Z(h), 0.6 * big * k, ROCK, 0.0, 1.0, core=False)
        for b in range(2):
            f.kit.ring(base + Z(h * (0.35 + 0.35 * b)), 0.64 * big * k, 0.08 * k, JADE, 7, 1.0)
        f.kit.burst(base, min(1, u * 3), 6, 1.5 * k, ROCK, i, 0.18 * k, glow=0)
    u = seg(t, 0.56, 1.3)
    if u is not None:  # a jade crack runs along the ground to the dummy
        reach = min(1.0, (t - 0.56) / (IMPACT - 0.56))
        f.kit.tube([a.lerp(f.T, reach * s / 10) + Z(0.05) for s in range(11)], 0.12 * k, JADE, 7, 1 - ease(max(0, (t - 1.0) / 0.3)))
    impact(f, JADE, 3, 7, flash=False)


SHELL_IN = P(head=[0, 0, 0, 0, 0.05, 0.75], tail=[0, 0, 0, 0, 0.15, 0.25],
             leg_fl=[0, 0, 0, 0, 0.4, 0], leg_fr=[0, 0, 0, 0, 0.4, 0], leg_bl=[0, 0, 0, 0, 0.4, 0], leg_br=[0, 0, 0, 0, 0.4, 0])
SHELL_NOVA_KEYS = [
    (0.00, {}),
    (0.25, P(SHELL_IN, body=[0, 0, 0, 0, -0.12, 0])),
    (0.80, P(SHELL_IN, body=[0, 0, 0, 0, -0.08, 0])),
    (0.92, P(SHELL_IN, body=[0, 0, 0, 0, 0.12, 0])),
    (1.05, P(SHELL_IN, body=[0, 0, 0, 0, -0.1, 0])),
    (1.40, P(head=[8])),
    (1.60, {}),
]


def shell_nova(f):
    k, t = f.k, f.t
    charge = env(t, 0.2, 0.85, 0.92, 1.0)
    f.kit.aura(JADE, (0.15 + 0.35 * charge) if 0.2 < t < 1.0 else 0.0, glow=4 + 6 * charge)
    under = f.kit.r.mid.copy()
    under.z = f.T.z
    if charge > 0:
        f.kit.circle(under, 0.75 * f.L * charge, JADE, t * 2, 6, charge)
    u = seg(t, IMPACT, IMPACT + 0.45)
    if u is not None:
        reach = (under - f.T).length / f.U + 2 * k
        R = 0.4 * f.L + reach * ease(u)
        f.kit.orb(f.kit.r.mid, R, JADE, 2, 0.1 * (1 - u), core=False)
        f.kit.ring(under + Z(0.1), R, 0.2 * k, JADE, 7, 1 - u)
        f.kit.light(f.kit.r.mid, JADE, 10 * (1 - u))
    hit = seg(t, IMPACT + 0.12, IMPACT + 0.6)
    if hit is not None:
        f.kit.orb(f.TC, (0.6 + 1.2 * ease(hit)) * k, JADE, 7, 0.8 * (1 - hit))
        f.kit.burst(f.TC, hit, 14, 3 * k, JADE, 9, 0.14 * k)


# ---- meerkat: the sun ------------------------------------------------------------------------------------------------
SUN_THROW = [
    (0.00, {}),
    (0.30, P(leg_fl=[175], leg_fr=[175], body=[8, 0, 0, 0, 0.05, 0.1], head=[18], leg_bl=[-6], leg_br=[-6])),
    (0.62, P(leg_fl=[185], leg_fr=[185], body=[12, 0, 0, 0, 0.08, 0.15], head=[22], leg_bl=[-10], leg_br=[-10])),
    (0.74, P(leg_fl=[60], leg_fr=[60], body=[-16, 0, 0, 0, 0, -0.3], head=[4], leg_bl=[16], leg_br=[16])),
    (0.92, P(leg_fl=[50], leg_fr=[50], body=[-10, 0, 0, 0, 0, -0.25], leg_bl=[10], leg_br=[10])),
    (1.25, P(leg_fl=[30], leg_fr=[30])),
    (1.60, {}),
]


def sun_orb(f):
    k, t = f.k, f.t
    hands = (f.A["paw_l"] + f.A["paw_r"]) / 2
    grow = seg(t, 0.2, 0.7)
    if grow is not None:
        p = hands + Z(0.5 * k)
        R = 0.9 * k * ease(grow)
        f.kit.orb(p, R, SUN, 7, 1, light=4)
        for i in range(8):  # rays turning round it
            a = t * 4 + i / 8 * math.tau
            d = Vector((0.2 * math.sin(a), math.cos(a), math.sin(a)))
            f.kit.spike(p + d * R, p + d * R * 1.9, 0.12 * k, SUN, 7, 0.8 * ease(grow))
    flight(f, hands + Z(0.5 * k), f.TC, 0.7, IMPACT, 2.5 * k,
           lambda p, u: f.kit.orb(p, 0.9 * k, SUN, 8, 1, light=4), trail=(SUN, 0.8 * k))
    impact(f, SUN, 3.5, 11)
    u = seg(t, IMPACT, IMPACT + 0.45)
    if u is not None:
        f.kit.orb(f.TC, (1 + 2.6 * ease(u)) * k, FIRE, 5, 0.6 * (1 - u), core=False)


BEACON_KEYS = [
    (0.00, {}),
    (0.30, P(leg_fl=[178], leg_fr=[172], body=[6, 0, 0, 0, 0.06, 0.05], head=[30])),
    (0.80, P(leg_fl=[180], leg_fr=[176], body=[8, 0, 0, 0, 0.08, 0.05], head=[34])),
    (0.90, P(leg_fl=[70], leg_fr=[66], body=[-12, 0, 0, 0, 0, -0.15], head=[-6], leg_bl=[12], leg_br=[12])),
    (1.20, P(leg_fl=[40], leg_fr=[40], body=[-4])),
    (1.60, {}),
]


def sky_beacon(f):
    k, t = f.k, f.t
    hands = (f.A["paw_l"] + f.A["paw_r"]) / 2
    up = env(t, 0.3, 0.45, 0.8, 0.9)
    if up > 0:  # a thin beam from its paws to the sky
        f.kit.beam(hands, hands + Z(f.sky), 0.08 * k, SUN, 6, up)
    sig = env(t, 0.45, 0.8, 0.95, 1.3)
    top = f.T + Z(f.sky)
    if sig > 0:
        f.kit.circle(top, 2.6 * k * sig, SUN, -t * 2, 6, sig)
    u = seg(t, 0.86, 1.35)
    if u is not None:  # the pillar of sunlight comes down
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        w = 1.3 * k * (1 - 0.7 * max(0, (t - IMPACT) / 0.43))
        f.kit.beam(top, top.lerp(f.T, reach), w, SUN, 7, 0.9 * (1 - max(0, (t - 1.1) / 0.25)))
        f.kit.light(f.TC, SUN, 8)
    impact(f, SUN, 3.5, 13)


# ---- cheetah: the wind -------------------------------------------------------------------------------------------
BLADE_KEYS = [
    (0.00, {}),
    (0.20, P(crouch(30, -14), body=[-4, 0, 0, 0, -0.1, 0.2])),
    (0.42, P(body=[14, 8, 0, 0, 0.25, 0], leg_fr=[80], leg_fl=[20], head=[6], tail=[-14])),
    (0.50, P(body=[-2, -6, 0, 0, 0, -0.2], leg_fr=[-10], leg_fl=[30])),
    (0.62, P(body=[14, -8, 0, 0, 0.25, 0], leg_fl=[80], leg_fr=[20], tail=[-14])),
    (0.70, P(body=[-2, 6, 0, 0, 0, -0.2], leg_fl=[-10], leg_fr=[30])),
    (0.80, P(body=[20, 0, 0, 0, 0.35, 0.1], leg_fl=[85], leg_fr=[85], head=[8], tail=[-20])),
    (0.88, P(body=[-6, 0, 0, 0, 0, -0.3], leg_fl=[-10], leg_fr=[-10])),
    (1.20, P(body=[-2])),
    (1.60, {}),
]


def wind_blades(f):
    k, t = f.k, f.t
    for i, (t0, paw, tilt) in enumerate(((0.5, "paw_r", 0.6), (0.7, "paw_l", -0.6), (0.86, "paw_l", 0.0))):
        big = 1.7 if i == 2 else 1.0
        t1 = t0 + (0.18 if i < 2 else IMPACT - 0.86 + 0.0001)
        a = f.kit.r.mid + Vector((0, -0.45 * f.L, 0.1 * f.H))
        u = seg(t, t0, t1)
        if u is not None:
            p = a.lerp(f.TC, ease(u))
            f.kit.crescent(p, 1.3 * big * k, 0.13 * big * k, MINT, Vector((math.sin(tilt), 0, math.cos(tilt))), Vector((0, -1, 0)), 7)
            f.kit.trail([a.lerp(f.TC, ease(max(0, u - j * 0.08))) for j in range(6)], 0.45 * big * k, MINT, 2, 0.2)
        h = seg(t, t1, t1 + 0.3)
        if h is not None:  # a slash mark on the dummy
            d = Vector((0.7, 0, 0.7 if i != 1 else -0.7)).normalized() if i < 2 else Vector((1, 0, 0))
            f.kit.tube([f.TC - d * 1.6 * big * k + Vector((0, -0.4, 0)), f.TC + d * 1.6 * big * k + Vector((0, -0.4, 0))], 0.1 * big * k, WHITE, 9, 1 - h,
                       taper=lambda x: math.sin(math.pi * x))
    impact(f, MINT, 3, 15, flash=False)


CYCLONE_KEYS = [
    (0.00, {}),
    (0.30, P(crouch(34, -18), body=[-4, 0, 0, 0, -0.15, 0.2], head=[-10], tail=[-20, 40])),
    (0.45, P(crouch(34, -18), body=[-4, 0, 0, 0, -0.15, 0.2], head=[-10], tail=[-20, -40])),
    (0.60, P(crouch(34, -18), body=[-4, 0, 0, 0, -0.15, 0.2], head=[-10], tail=[-20, 40])),
    (0.75, P(crouch(34, -18), body=[-4, 0, 0, 0, -0.15, 0.2], head=[-10], tail=[-20, -40])),
    (0.92, P(body=[10, 0, 0, 0, 0.12, -0.3], head=[16], leg_fl=[20], leg_fr=[20], leg_bl=[-14], leg_br=[-14], tail=[-14])),
    (1.25, P(body=[2], head=[4])),
    (1.60, {}),
]


def cyclone(f):
    k, t = f.k, f.t
    u = seg(t, 0.3, 0.85)
    if u is not None:  # wind streaming off its tail to the dummy
        for j in range(3):
            v = (u * 2 + j / 3) % 1
            p = f.A["tail"].lerp(f.T + Z(1 + j * 0.8), v)
            f.kit.trail([p + Vector((0, 0.6 * i, 0.15 * math.sin(i + j))) * k for i in range(6)], 0.25 * k, MINT, 3, 0.5 * math.sin(math.pi * v))
    grow = env(t, 0.45, IMPACT, 1.15, 1.5)
    if grow > 0:
        f.kit.vortex(f.T, 1.8 * k * (0.5 + 0.5 * grow), 7 * k * grow, MINT, t, n=5, glow=4, alpha=0.55 * grow)
        f.kit.vortex(f.T, 1.2 * k * (0.5 + 0.5 * grow), 6 * k * grow, WHITE, t * 1.3 + 1, n=3, glow=3, alpha=0.4 * grow)
        f.kit.disc(f.T, 2.2 * k * grow, MINT, 1.5, 0.3 * grow)
    lift = env(t, 0.75, IMPACT, 1.15, 1.4)
    f.dummy = Z(2.2 * k * lift)
    f.dummy_yaw = t * 14 * lift
    impact(f, MINT, 3, 17)


# ---- rhino: amber force ------------------------------------------------------------------------------------------
LANCE_KEYS = [
    (0.00, {}),
    (0.30, P(head=[-26], body=[-6, 0, 0, 0, -0.1, 0.3], leg_fl=[14], leg_fr=[14], leg_bl=[-12], leg_br=[-12], tail=[-10])),
    (0.80, P(head=[-30], body=[-7, 0, 0, 0, -0.12, 0.35], leg_fl=[16], leg_fr=[16], leg_bl=[-14], leg_br=[-14], tail=[-14])),
    (0.88, P(head=[6], body=[4, 0, 0, 0, 0.04, 0.5], leg_fl=[6], leg_fr=[6], leg_bl=[-6], leg_br=[-6], tail=[16])),
    (1.15, P(head=[4], body=[2, 0, 0, 0, 0, 0.4])),
    (1.60, {}),
]


def horn_lance(f):
    k, t = f.k, f.t
    horn = f.A["horn"]
    charge = env(t, 0.2, 0.8, 0.86, 0.9)
    if charge > 0:
        f.kit.orb(horn, 0.5 * k * charge, AMBER, 8, 1, light=3 * charge)
        for i in range(6):  # motes drawn in to the horn
            a = i / 6 * math.tau + t * 3
            v = (t * 2 + i / 6) % 1
            f.kit.spark(horn + Vector((math.cos(a), -0.5, math.sin(a))) * (1 - v) * 2.2 * k, 0.1 * k, AMBER, 8, v)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        w = 0.55 * k * (1 - ease(max(0, (t - 1.0) / 0.2)))
        end = horn.lerp(f.TC, reach)
        f.kit.beam(horn, end, w, AMBER, 8, 1)
        for i in range(4):  # rings spiralling along the beam
            v = (t * 3 + i / 4) % 1 * reach
            f.kit.ring(horn.lerp(f.TC, v), 0.9 * k, 0.06 * k, AMBER, 6, 0.8, normal=f.TC - horn)
        f.kit.light(end, AMBER, 6)
    impact(f, AMBER, 3.5, 19)


QUAKE_KEYS = [
    (0.00, {}),
    (0.35, P(body=[18, 0, 0, 0, 0.3, 0.2], leg_fl=[40], leg_fr=[36], leg_bl=[-18], leg_br=[-18], head=[20], tail=[-14])),
    (0.70, P(body=[22, 0, 0, 0, 0.36, 0.25], leg_fl=[48], leg_fr=[44], leg_bl=[-22], leg_br=[-22], head=[26], tail=[-16])),
    (0.82, P(body=[-10, 0, 0, 0, -0.08, -0.35], leg_fl=[-16], leg_fr=[-16], leg_bl=[10], leg_br=[10], head=[-24], tail=[18])),
    (1.10, P(body=[-6, 0, 0, 0, -0.05, -0.3], head=[-14])),
    (1.60, {}),
]


def quake_rings(f):
    k, t = f.k, f.t
    base = f.A["chest"].copy()
    base.z = f.T.z
    glow = env(t, 0.15, 0.5, 0.82, 0.95)
    if glow > 0:
        f.kit.circle(base + Vector((0, 0.3 * f.L, 0)), 0.55 * f.L, AMBER, t * 2, 3, glow * 0.8)
    dist = (base - f.T).length
    for j in range(3):
        u = seg(t, 0.82 + j * 0.05, IMPACT + j * 0.05)
        if u is None:
            u2 = seg(t, IMPACT + j * 0.05, IMPACT + j * 0.05 + 0.3)
            if u2 is not None:
                f.kit.ring(base, dist + 1.5 * k * u2, 0.18 * k, AMBER, 6, (1 - u2) * 0.8, arc=(-math.pi / 2 - 0.9, -math.pi / 2 + 0.9))
            continue
        R = 0.5 + dist * ease(u)
        f.kit.ring(base, R, 0.18 * k, AMBER, 6, 0.9, arc=(-math.pi / 2 - 0.9, -math.pi / 2 + 0.9))
        for i in range(5):  # rocks popping up along its edge
            a = -math.pi / 2 + (i - 2) * 0.35
            q = base + Vector((math.cos(a), math.sin(a), 0)) * R
            f.kit.box(q + Z(0.4 * k * math.sin(math.pi * u)), (0.5 * k, 0.5 * k, 0.4 * k), ROCK, 0, 1)
    u = seg(t, IMPACT, 1.4)
    if u is not None:  # spikes of rock under the dummy
        for i in range(4):
            a = i / 4 * math.tau + 0.4
            b = f.T + Vector((math.cos(a), math.sin(a), 0)) * 1.3 * k
            h = 4.5 * k * ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
            f.kit.spike(b, b + Z(h) + Vector((math.cos(a), math.sin(a), 0)) * 0.8 * k, 0.9 * k, ROCK, 0, 1)
            f.kit.spike(b + Z(h * 0.6), b + Z(h) + Vector((math.cos(a), math.sin(a), 0)) * 0.6 * k, 0.25 * k, AMBER, 7, 1)
    impact(f, AMBER, 3.5, 21)


# ---- flamingo: pink water and feathers ---------------------------------------------------------------------------
DART_KEYS = [
    (0.00, {}),
    (0.25, P(leg_bl=[0, 0, 70], leg_br=[0, 0, -70], body=[6, 0, 0, 0, 0, 0.15], head=[14], tail=[-10])),
    (0.62, P(leg_bl=[-10, 0, 80], leg_br=[-10, 0, -80], body=[8, 0, 0, 0, 0, 0.2], head=[18], tail=[-12])),
    (0.76, P(leg_bl=[40, 0, 25], leg_br=[40, 0, -25], body=[-10, 0, 0, 0, 0, -0.3], head=[-16])),
    (0.92, P(leg_bl=[30, 0, 20], leg_br=[30, 0, -20], body=[-8, 0, 0, 0, 0, -0.25], head=[-12])),
    (1.25, P(leg_bl=[0, 0, 20], leg_br=[0, 0, -20])),
    (1.60, {}),
]


def feather_darts(f):
    k, t = f.k, f.t
    for i in range(8):
        wing = "wing_l" if i % 2 == 0 else "wing_r"
        side = 1 if i % 2 == 0 else -1
        j = i // 2
        show = env(t, 0.25 + j * 0.06, 0.4 + j * 0.06, 2, 3)
        t0 = 0.72 + j * 0.03
        held = f.A[wing] + Vector((side * -0.3 * j, 0.2 * j, 0.3 * j)) * k
        if t < t0 and show > 0:
            f.kit.spike(held, held + Vector((0, -1.1, 0.2)) * k, 0.18 * k, PINK, 7, show)
        u = seg(t, t0, t0 + 0.18)
        if u is not None:
            p = bez(held, (held + f.TC) / 2 + Z(1.5 * k), f.TC + Vector((side * 0.3 * j, 0, 0.4 * j - 0.6)) * k, u)
            q = bez(held, (held + f.TC) / 2 + Z(1.5 * k), f.TC, min(1, u + 0.05))
            f.kit.spike(p - (q - p).normalized() * 0.9 * k, p + (q - p).normalized() * 0.4 * k, 0.17 * k, PINK, 8, 1)
            f.kit.trail([bez(held, (held + f.TC) / 2 + Z(1.5 * k), f.TC, max(0, u - m * 0.05)) for m in range(5)], 0.25 * k, PINK, 3, 0.5)
        h = seg(t, t0 + 0.18, t0 + 0.5)
        if h is not None:
            f.kit.spark(f.TC + Vector((side * 0.3 * j, -0.5, 0.4 * j - 0.6)) * k, 0.25 * k * (1 - h), WHITE, 9, 1 - h)
    impact(f, PINK, 3, 23)


GEYSER_KEYS = [
    (0.00, {}),
    (0.25, P(leg_fr=[-30, 0, 0, 0, 0.3, 0], leg_bl=[0, 0, 30], leg_br=[0, 0, -30], head=[-10])),
    (0.50, P(leg_fr=[-30, 0, 0, 0, 0.3, 0], leg_bl=[0, 0, 40], leg_br=[0, 0, -40], head=[-55], body=[-6])),
    (0.85, P(leg_fr=[-30, 0, 0, 0, 0.3, 0], leg_bl=[0, 0, 60], leg_br=[0, 0, -60], head=[24], body=[4])),
    (0.92, P(leg_bl=[0, 0, 65], leg_br=[0, 0, -65], head=[20], body=[2])),
    (1.30, P(leg_bl=[0, 0, 20], leg_br=[0, 0, -20])),
    (1.60, {}),
]


def lake_geyser(f):
    k, t = f.k, f.t
    feet = (f.A["paw_l"] + f.A["paw_r"]) / 2
    feet.z = f.T.z
    u = seg(t, 0.5, 0.85)
    if u is not None:
        f.kit.ring(feet + Z(0.05), (0.4 + 2 * u) * k, 0.06 * k, PINK, 5, 1 - u)
        p = feet.lerp(f.T, ease(u))  # bubbles racing along the ground
        for i in range(5):
            f.kit.spark(p.lerp(feet, i * 0.06) + Z(0.2 + 0.1 * math.sin(t * 20 + i)), 0.18 * k, AQUA, 4, 1 - i * 0.18)
    pool = env(t, 0.8, 0.88, 1.2, 1.5)
    if pool > 0:
        f.kit.disc(f.T, 2.4 * k * pool, AQUA, 2, 0.55 * pool)
        f.kit.ring(f.T + Z(0.05), 2.4 * k * pool, 0.08 * k, PINK, 5, pool)
    g = seg(t, IMPACT - 0.04, 1.5)
    if g is not None:  # the geyser: a column of water, foam on top, droplets
        h = 8 * k * ease(min(1, g * 3)) * (1 - ease(max(0, (g - 0.55) / 0.45)))
        f.kit.beam(f.T, f.T + Z(h), 1.1 * k, AQUA, 2, 0.55, core=False)
        f.kit.beam(f.T, f.T + Z(h * 0.95), 0.6 * k, PINK, 4, 0.5, core=False)
        for i in range(7):
            a = i / 7 * math.tau + t * 2
            f.kit.ball(f.T + Z(h) + Vector((math.cos(a), math.sin(a), 0.3)) * 0.8 * k, 0.55 * k, (0.85, 0.95, 1.0), 1.5, 0.75)
        f.kit.burst(f.T + Z(h), g, 14, 3 * k, AQUA, 25, 0.16 * k, rise=0.6, glow=3)
        f.dummy = Z(min(h, 3.5 * k) * 0.8)
        f.dummy_yaw = t * 6 * min(1, g * 3)
    impact(f, AQUA, 3, 25, flash=False)


# ---- lion: royal gold ----------------------------------------------------------------------------------------------
ROAR_KEYS = [
    (0.00, {}),
    (0.40, P(body=[12, 0, 0, 0, 0.16, 0.35], head=[28], leg_fl=[24], leg_fr=[22], leg_bl=[-12], leg_br=[-12], tail=[-16])),
    (0.78, P(body=[16, 0, 0, 0, 0.22, 0.45], head=[34], leg_fl=[30], leg_fr=[28], leg_bl=[-14], leg_br=[-14], tail=[-22])),
    (0.88, P(body=[-8, 0, 0, 0, -0.08, -0.3], head=[-4, 0, 0, 0, 0, -0.15], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[-18])),
    (1.00, P(body=[-8, 0, 0, 0, -0.08, -0.3], head=[-2, 0, 4, 0, 0, -0.15], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[-18])),
    (1.12, P(body=[-8, 0, 0, 0, -0.08, -0.3], head=[-2, 0, -4, 0, 0, -0.15], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[-18])),
    (1.35, P(body=[-2], head=[-2], tail=[-10])),
    (1.60, {}),
]


def golden_roar(f):
    k, t = f.k, f.t
    f.kit.aura(GOLD, 0.16 * env(t, 0.25, 0.75, 0.86, 1.0), glow=5)
    mouth = f.A["nose"]
    u = seg(t, 0.86, 1.3)
    if u is not None:
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        fade = 1 - ease(max(0, (t - 1.05) / 0.25))
        end = mouth.lerp(f.TC, reach)
        d = (f.TC - mouth).normalized()
        f.kit.spike(end + d * 0.1, mouth, 2.4 * k * reach, GOLD, 3, 0.3 * fade)  # the cone of the roar, wide at the dummy
        for i in range(4):
            v = ((t - 0.86) * 3 + i / 4) % 1 * reach
            f.kit.ring(mouth.lerp(f.TC, v), (0.3 + 2.2 * v) * k, 0.08 * k, GOLD, 7, 0.9 * fade, normal=d)
        f.kit.light(mouth, GOLD, 5 * fade)
    impact(f, GOLD, 3.5, 27)


POUNCE = P(body=[10, 0, 0, 0, 0.3, 0], head=[8], leg_fl=[58], leg_fr=[54], leg_bl=[-38], leg_br=[-38], tail=[-22])
SPIRIT_ROAR_KEYS = [
    (0.00, {}),
    (0.35, P(body=[10, 0, 0, 0, 0.12, 0.25], head=[40], leg_fl=[20], leg_fr=[18], leg_bl=[-10], leg_br=[-10], tail=[-20])),
    (0.80, P(body=[12, 0, 0, 0, 0.14, 0.3], head=[44], leg_fl=[22], leg_fr=[20], leg_bl=[-10], leg_br=[-10], tail=[-24])),
    (0.92, P(body=[-6, 0, 0, 0, -0.06, -0.2], head=[-8], leg_fl=[-8], leg_fr=[-8], leg_bl=[6], leg_br=[6], tail=[-14])),
    (1.30, P(head=[-2])),
    (1.60, {}),
]


def spirit_lion(f):
    k, t = f.k, f.t
    f.kit.aura(GOLD, 0.25 * env(t, 0.3, 0.5, 0.85, 0.95))
    u = seg(t, 0.4, 1.15)
    if u is not None:
        start = Vector((0, 0.15 * f.L, 0.55 * f.H))
        end = (f.T - f.kit.r.mid) * (1 / f.U) + Vector((0, 0.2 * f.L, 0.1 * f.H))
        end.z = max(end.z, 0.1 * f.H)
        p = bez(start, (start + end) / 2 + Z(0.6 * f.H), end, ease(seg(t, 0.4, IMPACT) or (1 if t > IMPACT else 0)))
        fade = env(t, 0.4, 0.55, IMPACT, 1.15)
        f.kit.ghost(POUNCE, p, GOLD, 3, 0.5 * fade, scale=1.5, now=f.pose)
    impact(f, GOLD, 4, 29)
    f.kit.burst(f.TC + Z(1), seg(t, IMPACT, 1.5), 24, 5 * k, GOLD, 31, 0.16 * k)


# ---- giraffe: the sky --------------------------------------------------------------------------------------------
SKY_KEYS = [
    (0.00, {}),
    (0.35, P(head=[28], body=[6, 0, 0, 0, 0.04, 0.1], leg_fl=[4], leg_fr=[4], tail=[0, 15])),
    (0.80, P(head=[34], body=[7, 0, 0, 0, 0.05, 0.12], leg_fl=[5], leg_fr=[5], tail=[0, -15])),
    (0.90, P(head=[-34], body=[-6, 0, 0, 0, -0.03, -0.1], leg_fl=[-6], leg_fr=[-6], leg_bl=[4], leg_br=[4], tail=[0, 10])),
    (1.30, P(head=[-8])),
    (1.60, {}),
]


def halo_strike(f):
    k, t = f.k, f.t
    crown = f.A["crown"]
    form = seg(t, 0.25, 0.62)
    if form is not None:
        p = crown + Z((0.6 + 1.6 * form) * k)
        f.kit.ring(p, (0.8 + 1.2 * ease(form)) * k, 0.14 * k, LAV, 8, ease(min(1, form * 2)))
        f.kit.light(p, LAV, 3)
    over = f.T + Z(f.sky * 0.5)
    u = seg(t, 0.62, 0.86)
    if u is not None:
        p = bez(crown + Z(2.2 * k), (crown + over) / 2 + Z(2 * k), over, ease(u))
        f.kit.ring(p, (2 + 1.6 * u) * k, 0.16 * k, LAV, 8, 1)
        f.kit.light(p, LAV, 3)
    u = seg(t, 0.86, IMPACT)
    if u is not None:
        f.kit.ring(over.lerp(f.T + Z(0.2), ease(u)), 3.6 * k, 0.2 * k, WHITE, 9, 1)
    u = seg(t, IMPACT, 1.4)
    if u is not None:  # the halo lands round it: a wall of light rising off the ring
        f.kit.ring(f.T + Z(0.2), 3.6 * k, 0.2 * k, LAV, 8, 1 - u)
        f.kit.beam(f.T, f.T + Z(5 * k * (1 - u)), 3.4 * k, LAV, 2, 0.25 * (1 - u), core=False)
        f.kit.circle(f.T, 3.6 * k, LAV, t * 3, 6, 1 - u)
    impact(f, LAV, 3, 33, ring=False)


def sky_lance(f):
    k, t = f.k, f.t
    crown = f.A["crown"]
    up = env(t, 0.3, 0.45, 0.8, 0.9)
    if up > 0:
        f.kit.beam(crown, crown + Z(f.sky * 1.2), 0.1 * k, LAV, 6, up)
    top = f.T + Z(f.sky)
    form = env(t, 0.4, 0.82, 2, 3)
    if t < 0.86 and form > 0:
        f.kit.spike(top + Z(2.5 * k), top - Z(3.5 * k * form), 0.7 * k * form, WHITE, 9, form)
        f.kit.orb(top + Z(2.5 * k), 1.2 * k * form, LAV, 5, 0.6 * form, core=False)
        f.kit.ring(top, 2.4 * k * form, 0.1 * k, LAV, 6, form)
    u = seg(t, 0.86, IMPACT)
    if u is not None:
        tip = top.lerp(f.T + Z(0.6 * k), ease(u))
        f.kit.spike(tip + Z(6 * k), tip, 0.7 * k, WHITE, 10, 1)
        f.kit.trail([tip + Z((6 + 2 * i) * k) for i in range(5)], 1.4 * k, LAV, 4, 0.5)
    u = seg(t, IMPACT, 1.45)
    if u is not None:
        f.kit.spike(f.T + Z(6 * k), f.T - Z(0.5 * k), 0.7 * k, WHITE, 9, 1 - u)
        for i in range(6):  # shards kicked up
            a = i / 6 * math.tau
            q = f.T + Vector((math.cos(a), math.sin(a), 0)) * (1 + 2 * u) * k + Z(2.5 * k * math.sin(math.pi * min(1, u * 1.5)))
            f.kit.diamond(q, 0.25 * k, 0.6 * k, LAV, 6, 1 - u, spin=t * 8)
    impact(f, LAV, 4, 35)


# ---- elephant: the Titan's power -----------------------------------------------------------------------------------
ORB_KEYS = [
    (0.00, {}),
    (0.35, P(body=[12, 0, 0, 0, 0.15, 0.3], head=[34], leg_fl=[26], leg_fr=[22], leg_bl=[-12], leg_br=[-12], tail=[-14])),
    (0.74, P(body=[14, 0, 0, 0, 0.18, 0.35], head=[38], leg_fl=[30], leg_fr=[26], leg_bl=[-14], leg_br=[-14], tail=[-16])),
    (0.82, P(body=[-6, 0, 0, 0, -0.06, -0.3], head=[4], leg_fl=[-10], leg_fr=[-10], leg_bl=[8], leg_br=[8], tail=[14])),
    (1.20, P(body=[-2], head=[0])),
    (1.60, {}),
]


def titan_orb(f):
    k, t = f.k, f.t
    tip = f.A["trunk"]
    grow = seg(t, 0.25, 0.8)
    if grow is not None:
        R = 1.5 * k * ease(grow)
        f.kit.orb(tip + Z(R * 0.6), R, VIOLET, 7, 1, light=5)
        for i in range(10):  # sparks drawn in
            a = i / 10 * math.tau + t * 4
            v = (t * 2.5 + i / 10) % 1
            f.kit.spark(tip + Z(R * 0.6) + Vector((math.cos(a), math.sin(a) * 0.5, math.sin(a))) * (1 - v) * 4 * k, 0.14 * k, GOLD, 8, v)
    flight(f, tip + Z(1.5 * k * 0.6), f.TC, 0.8, IMPACT, 2 * k,
           lambda p, u: f.kit.orb(p, 1.5 * k, VIOLET, 8, 1, light=5), trail=(VIOLET, 1.4 * k))
    impact(f, VIOLET, 5, 37)
    u = seg(t, IMPACT, IMPACT + 0.5)
    if u is not None:
        f.kit.orb(f.TC, (1.5 + 3.5 * ease(u)) * k, GOLD, 4, 0.5 * (1 - u), core=False)


QUAKE_TITAN_KEYS = [
    (0.00, {}),
    (0.38, P(body=[18, 0, 0, 0, 0.25, 0.25], head=[30], leg_fl=[44], leg_fr=[40], leg_bl=[-18], leg_br=[-18], tail=[-14])),
    (0.72, P(body=[22, 0, 0, 0, 0.3, 0.3], head=[36], leg_fl=[52], leg_fr=[48], leg_bl=[-22], leg_br=[-22], tail=[-16])),
    (0.82, P(body=[-10, 0, 0, 0, -0.1, -0.5], head=[-20], leg_fl=[-16], leg_fr=[-14], leg_bl=[10], leg_br=[10], tail=[18])),
    (1.15, P(body=[-4, 0, 0, 0, -0.03, -0.25], head=[-8])),
    (1.60, {}),
]


def titan_quake(f):
    k, t = f.k, f.t
    base = f.A["chest"].copy()
    base.z = f.T.z
    u = seg(t, 0.82, IMPACT)
    if u is not None:  # glowing cracks race out to the dummy
        for j in (-1, 0, 1):
            end = f.T + Vector((j * 1.5, 0, 0)) * k
            f.kit.tube([base.lerp(end, ease(u) * s / 8) + Vector((0.3 * math.sin(s * 2.3 + j), 0, 0.05)) * k for s in range(9)], 0.12 * k, VIOLET, 7, 1)
    c = env(t, 0.82, 0.9, 1.15, 1.45)
    if c > 0:
        f.kit.circle(f.T, 5 * k * c, VIOLET, t * 3, 7, c, spokes=10)
    u = seg(t, IMPACT, 1.5)
    if u is not None:  # a ring of stone spikes bursts up round it
        for i in range(8):
            a = i / 8 * math.tau
            b = f.T + Vector((math.cos(a), math.sin(a), 0)) * 3.2 * k
            h = 4.5 * k * ease(min(1, u * 5)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
            tip = b + Z(h) - Vector((math.cos(a), math.sin(a), 0)) * 1.2 * k
            f.kit.spike(b, tip, 0.8 * k, ROCK, 0, 1)
            f.kit.spike(b.lerp(tip, 0.6), tip, 0.35 * k, VIOLET, 8, 1)
    impact(f, VIOLET, 5, 39)


# ================================================================================================= variants
def anubis(f):  # Pharaoh Jackal
    k, t = f.k, f.t
    f.kit.aura(TURQ, 0.25 * env(t, 0.25, 0.45, 0.82, 0.92))
    top = f.T + Z(f.sky * 0.55)
    form = env(t, 0.3, 0.75, 2, 3)
    u = seg(t, 0.84, IMPACT)
    p = top if u is None else top.lerp(f.T + Z(2.2 * k), ease(u))
    if t < IMPACT + 0.01 and form > 0:  # a golden ankh in the sky, then down like a hammer
        s = 1.4 * k
        f.kit.ring(p + Z(1.1 * s), 0.6 * s, 0.13 * s, GOLD, 8, form, normal=Vector((1, 0, 0)))
        f.kit.tube([p + Z(0.55 * s), p - Z(1.8 * s)], 0.15 * s, GOLD, 8, form)
        f.kit.tube([p + Vector((0, -1.0, 0)) * s, p + Vector((0, 1.0, 0)) * s], 0.15 * s, GOLD, 8, form)
        f.kit.orb(p + Z(1.1 * s), 0.3 * s, TURQ, 8, form)
        f.kit.light(p, GOLD, 4 * form)
    beam = env(t, 0.5, 0.6, 0.84, 0.9)
    if beam > 0:  # its brow gem holds a turquoise beam on the ankh
        f.kit.beam(f.A["crown"], p + Z(1.5 * k), 0.12 * k, TURQ, 8, beam)
    u = seg(t, IMPACT, 1.5)
    if u is not None:
        for i in range(10):  # a ring of glyphs rising off the ground
            a = i / 10 * math.tau + t
            q = f.T + Vector((math.cos(a), math.sin(a), 0)) * 2.8 * k + Z(1.5 * k * u)
            f.kit.box(q, (0.4 * k, 0.1 * k, 0.6 * k), GOLD if i % 2 else TURQ, 6, 1 - u)
    impact(f, TURQ, 4, 41)


def sandstorm(f):  # Sphinx Jackal
    k, t = f.k, f.t
    disc = env(t, 0.2, 0.5, 0.95, 1.1)
    if disc > 0:
        f.kit.orb(f.A["crown"] + Z(0.4 * k), 0.55 * k, SUN, 8, disc, light=3 * disc)
    storm = env(t, 0.4, 0.8, 1.15, 1.5)
    if storm > 0:
        f.kit.vortex(f.T, 2.6 * k, 6 * k * storm, SAND, t, n=6, glow=1.5, alpha=0.6 * storm, w=0.25)
        for i in range(8):
            a = -t * 5 + i / 8 * math.tau
            q = f.T + Vector((math.cos(a), math.sin(a), 0)) * 3.2 * k + Z((1 + 0.5 * math.sin(a * 2)) * k)
            f.kit.box(q, (0.35 * k, 0.08 * k, 0.5 * k), GOLD, 7, storm)
        f.kit.burst(f.T + Z(1.5 * k), (t * 1.5) % 1, 12, 3 * k, SAND, 43, 0.12 * k, glow=1)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        a = f.A["crown"] + Z(0.4 * k)
        f.kit.beam(a, a.lerp(f.TC, reach), 0.35 * k * (1 - u * 0.7), SUN, 9, 1)
    impact(f, SUN, 4, 45)


def gem_barrage(f):  # Gemshell Tortoise
    k, t = f.k, f.t
    back = f.A["back"]
    cols = [ROSE, TURQ, (0.9, 0.3, 1.0), GOLD, ROSE, TURQ]
    for i in range(6):
        rise = seg(t, 0.2 + i * 0.04, 0.55 + i * 0.04)
        hold_at = back + Vector((0.3, (i - 2.5) * 0.9, 1.8 + 0.4 * math.sin(i))) * k
        t0 = 0.6 + i * 0.054
        if t < t0:
            if rise is not None or t > 0.55 + i * 0.04:
                p = back.lerp(hold_at, ease(rise if rise is not None else 1))
                f.kit.diamond(p, 0.35 * k, 0.9 * k, cols[i], 6, 1, spin=t * 6 + i)
                f.kit.light(p, cols[i], 1)
            continue
        u = seg(t, t0, t0 + 0.2)
        if u is not None:
            end = f.TC + Vector((0, (i - 2.5) * 0.3, (i % 3 - 1) * 0.6)) * k
            p = bez(hold_at, (hold_at + end) / 2 + Z(2 * k), end, u)
            f.kit.diamond(p, 0.35 * k, 0.9 * k, cols[i], 8, 1, spin=t * 12, axis=end - hold_at)
            f.kit.trail([bez(hold_at, (hold_at + end) / 2 + Z(2 * k), end, max(0, u - m * 0.06)) for m in range(5)], 0.3 * k, cols[i], 4, 0.5)
        h = seg(t, t0 + 0.2, t0 + 0.55)
        if h is not None:
            f.kit.burst(f.TC, h, 8, 2 * k, cols[i], 47 + i, 0.14 * k)
    impact(f, ROSE, 3.5, 49, flash=True)


def island_surge(f):  # Island Tortoise
    k, t = f.k, f.t
    start = f.A["chest"].copy()
    start.z = f.T.z
    start += Vector((0, -1.0, 0)) * k
    rise = seg(t, 0.45, 0.82)
    roll = seg(t, 0.82, IMPACT + 0.06)
    if rise is not None or roll is not None:
        p = start if roll is None else start.lerp(f.T, ease(roll))
        h = 4 * k * (ease(rise) if rise is not None else 1)
        fwd = Vector((0, -1, 0))
        R = h / 2
        for j in range(5):  # a curling wall of water across its path: bottom, up the back, over the top
            c = p + Vector(((j - 2) * 1.0 * k, 0, 0)) + Z(R)
            pts = [c - fwd * R * math.sin(a) - Z(R * math.cos(a)) for a in [x / 14 * 1.3 * math.pi for x in range(15)]]
            f.kit.tube(pts, 0.55 * k, SEA, 2, 0.6, taper=lambda x: 1.2 - 0.9 * x)
            f.kit.spark(pts[-1], 0.3 * k, (0.9, 0.97, 1), 3, 0.9)
        f.kit.burst(p + Z(h) + fwd * R * 0.6, (t * 2) % 1, 8, 1.2 * k, (0.9, 0.97, 1), 51, 0.18 * k, glow=2)
    u = seg(t, IMPACT, 1.5)
    if u is not None:
        f.kit.burst(f.TC, u, 22, 4 * k, AQUA, 53, 0.22 * k, glow=3)
        f.kit.disc(f.T, 3 * k * min(1, u * 3), SEA, 1.5, 0.5 * (1 - u))
        g = ease(min(1, (u - 0.15) * 3)) if u > 0.15 else 0
        for i in range(6):  # vines and glowing flowers spring up round it
            a = i / 6 * math.tau + 0.3
            b = f.T + Vector((math.cos(a), math.sin(a), 0)) * 1.6 * k
            tip = b + Z(2.8 * k * g) - Vector((math.cos(a), math.sin(a), 0)) * 0.9 * k * g
            if g > 0:
                f.kit.tube([b, b.lerp(tip, 0.5) + Vector((math.cos(a + 1), math.sin(a + 1), 0)) * 0.4 * k, tip], 0.12 * k, LEAF, 1, 1)
                f.kit.orb(tip, 0.35 * k * g, (PINK, STAR)[i % 2], 7, 1, core=False)
    impact(f, AQUA, 3.5, 55, flash=False)


def comet_strike(f):  # Comet Meerkat
    k, t = f.k, f.t
    hand = f.A["paw_r"]
    f.kit.aura(STAR, 0.2 * env(t, 0.25, 0.4, 0.82, 0.92))
    far = f.T + Vector((6, 10, f.sky * 1.4)) * k
    u = seg(t, 0.35, IMPACT)
    if u is not None:
        p = far.lerp(f.TC, ease(u) ** 1.6)
        d = (far - f.TC).normalized()
        f.kit.orb(p, 1.0 * k, STAR, 9, 1, light=4)
        f.kit.spike(p, p + d * 7 * k, 1.0 * k, VIOLET, 4, 0.55)
        f.kit.spike(p, p + d * 5 * k, 0.6 * k, STAR, 6, 0.7)
        for i in range(6):
            f.kit.spark(p + d * (1.5 + i) * k + Vector((math.sin(i * 3 + t * 20), 0, math.cos(i * 2 + t * 17))) * 0.6 * k, 0.15 * k, WHITE, 9, 1 - i / 6)
    line = env(t, 0.3, 0.45, 0.8, 0.9)
    if line > 0:  # it points the way with a thin line of starlight
        f.kit.beam(hand, hand + (far - hand).normalized() * 6 * k, 0.05 * k, STAR, 7, line)
    u = seg(t, IMPACT, 1.55)
    if u is not None:
        f.kit.disc(f.T, 3 * k, DARK, 0, 0.7 * (1 - u))
        for i in range(10):
            a = i / 10 * math.tau
            q = f.T + Vector((math.cos(a), math.sin(a), 0)) * (1 + 4 * ease(u)) * k + Z(3 * k * math.sin(math.pi * u))
            f.kit.spike(q - Z(0.3 * k), q + Z(0.3 * k), 0.25 * k, STAR, 8, 1 - u)
            f.kit.spike(q + Z(0.3 * k), q - Z(0.3 * k), 0.25 * k, STAR, 8, 1 - u)
    impact(f, STAR, 5, 57)


def abduction(f):  # Alien Meerkat
    k, t = f.k, f.t
    hover = f.T + Z(f.sky * 0.7)
    come = seg(t, 0.25, 0.55)
    if t >= 0.25:
        p = hover + Vector((-8, 6, 4)) * k * (1 - ease(come)) if come is not None else hover
        if t > 1.1:
            p = hover + Vector((8, -4, 5)) * k * ease(min(1, (t - 1.1) / 0.35))
        p = p + Z(0.2 * k * math.sin(t * 9))
        f.kit._obj("sphere", (0.55, 0.6, 0.66), 0.2, 1.0, p, scale=(2.6 * k, 2.6 * k, 0.5 * k))  # the saucer
        f.kit.orb(p + Z(0.5 * k), 1.0 * k, ALIEN, 3, 0.6, core=False)
        for i in range(8):
            a = i / 8 * math.tau + t * 6
            f.kit.spark(p + Vector((math.cos(a), math.sin(a), -0.05)) * 2.4 * k, 0.22 * k, (ALIEN, YELLOW)[i % 2], 9, 1)
    beam = env(t, 0.55, 0.62, 0.86, IMPACT)
    if beam > 0:  # the tractor beam lifts the dummy
        f.kit.spike(f.T, hover, 2.0 * k, ALIEN, 3, 0.3 * beam)
        f.kit.light(f.TC, ALIEN, 5 * beam)
        for i in range(5):
            v = (t * 1.5 + i / 5) % 1
            f.kit.ring(f.T.lerp(hover, v), 2.0 * k * (1 - v) + 0.4, 0.06 * k, ALIEN, 7, beam * (1 - v))
    lift = env(t, 0.6, 0.86, 0.86, IMPACT)
    f.dummy = Z(3.5 * k * lift)
    f.dummy_yaw = t * 6 * lift
    u = seg(t, 0.86, 1.0)
    if u is not None:  # and zaps it down
        f.kit.bolt(hover - Z(0.5 * k), f.TC + f.dummy * f.U, ALIEN, 0.12 * k, 0.12, seed=int(t * 30))
    impact(f, ALIEN, 4, 59)


def chain_lightning(f):  # Lightning Cheetah
    k, t = f.k, f.t
    tail = f.A["tail"]
    f.kit.aura(YELLOW, 0.15 * env(t, 0.25, 0.4, 0.86, 0.95), glow=6)
    if 0.3 <= t <= 0.86:  # crackling at the tail tip
        for j in range(2):
            f.kit.bolt(tail, tail + Vector((math.sin(t * 40 + j), math.cos(t * 33 + j), 0.8)) * 1.2 * k, YELLOW, 0.05 * k, 0.25, 4, seed=int(t * 24) + j)
        f.kit.orb(tail, 0.35 * k, YELLOW, 8, 1, light=2)
    apex = f.kit.r.mid + Vector((0, -0.2 * f.L, 1.3 * f.H))
    hops = [(0.84, tail, apex), (0.86, apex, f.TC), (IMPACT + 0.06, f.TC, f.T + Vector((3.5, -4, 0)) * k),
            (IMPACT + 0.14, f.T + Vector((3.5, -4, 0)) * k, f.T + Vector((-3.5, -6, 0)) * k)]
    for i, (t0, a, b) in enumerate(hops):
        u = seg(t, t0, t0 + 0.2)
        if u is not None:
            f.kit.bolt(a, b, YELLOW, 0.13 * k, 0.12, seed=int(t * 30) + i, fork=2, alpha=1 - u * 0.5)
            f.kit.light(b, YELLOW, 6)
        if i > 1:
            h = seg(t, t0, t0 + 0.4)
            if h is not None:
                f.kit.ring(b + Z(0.1), (0.4 + 2 * h) * k, 0.1 * k, YELLOW, 7, 1 - h)
                f.kit.burst(b, h, 8, 2 * k, YELLOW, 61 + i, 0.12 * k)
    impact(f, YELLOW, 3.5, 63)


def thunderhead(f):  # Thunder Cheetah
    k, t = f.k, f.t
    start = f.kit.r.mid + Z(f.H * 0.9)
    over = f.T + Z(f.sky * 0.65)
    g = env(t, 0.15, 0.5, 1.2, 1.55)
    if g > 0:
        u = seg(t, 0.5, 0.82)
        p = start if t < 0.5 else (start.lerp(over, ease(u)) if u is not None else over)
        f.kit.cloud(p, 2.6 * k * g, (0.42, 0.36, 0.75), seed=3, alpha=0.95, glow=0.6)
        if int(t * 20) % 3 == 0:  # flickers inside it
            f.kit.light(p, STORM, 8 * g)
        if t > 0.86:
            for i in range(14):  # rain
                q = p + Vector(((i % 5 - 2) * 1.0, (i // 5 - 1) * 1.0, -1.5)) * k - Z(((t * 6 + i * 0.37) % 1) * (f.sky * 0.6))
                f.kit.tube([q, q - Z(0.8 * k)], 0.04 * k, (0.7, 0.75, 1.0), 2, 0.6 * g)
    for i in range(3):
        u = seg(t, 0.86 + i * 0.05, 0.98 + i * 0.05)
        if u is not None:
            end = f.TC + Vector(((i - 1) * 0.6, 0, (1 - i) * 0.4)) * k
            f.kit.bolt(over - Z(1.5 * k), end, STORM, 0.16 * k, 0.1, seed=i * 5 + int(t * 25), fork=2)
            f.kit.light(end, STORM, 8)
    u = seg(t, IMPACT, 1.4)
    if u is not None:  # the thunderclap
        for j in range(2):
            f.kit.ring(f.T + Z(0.2 + 1.2 * j), (0.8 + 5 * ease(u)) * k, 0.12 * k, STORM, 7, 1 - u)
    impact(f, STORM, 3, 65)


def magma(f):  # Lava Rhino
    k, t = f.k, f.t
    base = f.A["chest"].copy()
    base.z = f.T.z
    u = seg(t, 0.82, IMPACT)
    reach = 1.0 if t > IMPACT else (ease(u) if u is not None else 0)
    if t >= 0.82:  # lava cracks race to the dummy
        fade = 1 - ease(max(0, (t - 1.2) / 0.3))
        for j in (-1, 1, 0):
            f.kit.tube([base.lerp(f.T + Vector((j * 1.2, 0, 0)) * k, reach * s / 8) + Vector((0.35 * math.sin(s * 2.1 + j), 0, 0.05)) * k for s in range(9)],
                       0.16 * k, LAVA, 8, fade)
    pool = env(t, 0.88, IMPACT, 1.25, 1.5)
    if pool > 0:
        f.kit.disc(f.T, 1.8 * k * pool, (0.9, 0.18, 0.02), 3, 0.9 * pool)
    u = seg(t, IMPACT, 1.55)
    if u is not None:  # the eruption
        h = 6 * k * ease(min(1, u * 3)) * (1 - ease(max(0, (u - 0.5) / 0.5)))
        f.kit.spike(f.T, f.T + Z(h), 1.5 * k, FIRE, 6, 0.85)
        f.kit.spike(f.T, f.T + Z(h * 0.8), 0.8 * k, YELLOW, 8, 0.9)
        f.kit.light(f.TC, LAVA, 10 * (1 - u))
        for i in range(7):  # molten rocks thrown up
            a = i / 7 * math.tau + 0.5
            d = Vector((math.cos(a), math.sin(a), 0))
            q = f.T + d * 4 * k * u + Z(6 * k * u - 7 * k * u * u + 1 * k)
            f.kit.ball(q, 0.4 * k, (0.12, 0.05, 0.04), 0)
            f.kit.orb(q, 0.45 * k, LAVA, 6, 0.6, core=False)
    impact(f, LAVA, 3.5, 67, flash=False)


def prism(f):  # Crystal Rhino
    k, t = f.k, f.t
    horn = f.A["horn"]
    c = env(t, 0.2, 0.75, 0.86, 0.92)
    if c > 0:
        for i, rgb in enumerate(RAINBOW):  # seven motes circling in to the horn
            a = t * 6 + i / 7 * math.tau
            rr = (1 - ease(seg(t, 0.2, 0.86) or 1)) * 2.5 * k + 0.4 * k
            f.kit.orb(horn + Vector((math.cos(a), math.sin(a) * 0.4, math.sin(a))) * rr, 0.25 * k, rgb, 8, c, core=False)
        f.kit.orb(horn, 0.45 * k * c, WHITE, 9, c, light=3 * c)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        end = horn.lerp(f.TC, reach)
        fade = 1 - ease(max(0, (t - 1.02) / 0.18))
        f.kit.beam(horn, end, 0.18 * k, WHITE, 9, fade, core=False)
        d = (f.TC - horn).normalized()
        side = d.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(d)
        for i, rgb in enumerate(RAINBOW):  # the colours twisting round it
            a = i / 7 * math.tau + t * 10
            off = (side * math.cos(a) + up * math.sin(a)) * 0.6 * k
            f.kit.beam(horn + off * 0.3, end + off, 0.15 * k, rgb, 7, fade, core=False)
    u = seg(t, IMPACT, 1.5)
    if u is not None:  # crystals of seven colours burst out round it
        for i, rgb in enumerate(RAINBOW):
            a = i / 7 * math.tau + 0.2
            d = Vector((math.cos(a), math.sin(a), 0.7)).normalized()
            g = ease(min(1, u * 5)) * (1 - ease(max(0, (u - 0.65) / 0.35)))
            f.kit.diamond(f.T + d * 1.4 * k + Z(0.5 * k), 0.55 * k * g, 2.4 * k * g, rgb, 6, 1, axis=d)
    impact(f, WHITE, 4, 69)


def royal_fan(f):  # King Flamingo
    k, t = f.k, f.t
    tail = f.A["tail"]
    behind = tail + Vector((0, 0.6, 1.2)) * k
    show = env(t, 0.2, 0.55, 0.95, 1.15)
    eyes = []
    for i in range(9):  # eye spots glow in a fan behind it
        a = math.pi * (0.15 + 0.7 * i / 8)
        q = behind + (Vector((0.5, 0.85, 0)) * math.cos(a) * 3.2 + Vector((0, 0.3, 0)) + Z(math.sin(a) * 2.6)) * k
        eyes.append(q)
        if show > 0:
            f.kit.orb(q, 0.4 * k * show, (TURQ, GOLD, SEA)[i % 3], 8, show)
    if show > 0:
        f.kit.light(behind, TURQ, 4 * show)
    for i, q in enumerate(eyes):
        u = seg(t, 0.8 + i * 0.012, 1.15)
        if u is not None:
            reach = ease(min(1, (t - 0.8 - i * 0.012) / 0.1))
            f.kit.beam(q, q.lerp(f.TC, reach), 0.08 * k, (TURQ, GOLD, SEA)[i % 3], 8, 1 - ease(max(0, (t - 1.0) / 0.15)), core=False)
    u = seg(t, IMPACT, 1.5)
    if u is not None:  # a crown of light over the dummy
        p = f.TC + Z((2.2 + 0.8 * u) * k)
        f.kit.ring(p, 1.2 * k, 0.12 * k, GOLD, 8, 1 - u)
        for i in range(5):
            a = i / 5 * math.tau
            b = p + Vector((math.cos(a), math.sin(a), 0)) * 1.2 * k
            f.kit.spike(b, b + Z(0.9 * k), 0.2 * k, GOLD, 8, 1 - u)
    impact(f, TURQ, 3.5, 71)


FIREBIRD = P(leg_bl=[0, 0, 80], leg_br=[0, 0, -80], body=[-20, 0, 0, 0, 0.2, 0], head=[-10], leg_fl=[-30], leg_fr=[-30], tail=[-10])


def firebird(f):  # Phoenix Flamingo
    k, t = f.k, f.t
    f.kit.aura(FIRE, 0.3 * env(t, 0.2, 0.5, 0.75, 0.9), glow=7)
    for i in range(5):  # flames licking up round it
        v = (t * 2 + i / 5) % 1
        a = i / 5 * math.tau
        p = f.kit.r.mid + Vector((math.cos(a) * 0.4 * f.L, math.sin(a) * 0.3 * f.L, -0.3 * f.H + v * 0.9 * f.H))
        f.kit.spike(p, p + Z(1.2 * k), 0.3 * k * (1 - v), FIRE, 7, env(t, 0.2, 0.4, 0.8, 0.9) * (1 - v))
    u = seg(t, 0.5, 1.05)
    if u is not None:
        start = Vector((0, 0, 0.5 * f.H))
        end = (f.T - f.kit.r.mid) * (1 / f.U) + Vector((0, 0.2 * f.L, 0.25 * f.H))
        w = ease(seg(t, 0.5, IMPACT) or 1)
        p = bez(start, (start + end) / 2 + Z(0.8 * f.H), end, w)
        fade = env(t, 0.5, 0.6, IMPACT, 1.05)
        f.kit.ghost(FIREBIRD, p, FIRE, 3, 0.45 * fade, scale=1.4, now=f.pose)
        f.kit.light(f.kit.r.mid + p * f.U, FIRE, 6 * fade)
        f.kit.trail([f.kit.r.mid + bez(start, (start + end) / 2 + Z(0.8 * f.H), end, max(0, w - i * 0.05)) * f.U for i in range(8)], 1.5 * k, EMBER, 5, 0.5 * fade)
    u = seg(t, IMPACT, 1.5)
    if u is not None:
        f.kit.orb(f.TC, (1 + 3 * ease(u)) * k, FIRE, 6, 0.7 * (1 - u), core=False)
        f.kit.ring(f.T + Z(0.1), (1 + 3.5 * u) * k, 0.3 * k, FIRE, 7, 1 - u)
        f.kit.burst(f.TC, u, 20, 4 * k, EMBER, 73, 0.15 * k, rise=0.8)
    impact(f, FIRE, 3, 75, ring=False)


def solar_flare(f):  # Sun Lion
    k, t = f.k, f.t
    head = f.A["crown"] + Vector((0, 1.2, 1.4)) * k
    g = env(t, 0.2, 0.7, 0.95, 1.2)
    if g > 0:  # a sun with twelve rays rises behind its head
        f.kit.orb(head, 1.3 * k * g, SUN, 8, g, light=6 * g)
        for i in range(12):
            a = t * 1.5 + i / 12 * math.tau
            d = Vector((0.0, math.cos(a), math.sin(a)))
            f.kit.spike(head + d * 1.4 * k * g, head + d * (2.6 + 0.4 * (i % 2)) * k * g, 0.22 * k, YELLOW, 8, g)
    u = seg(t, 0.86, 1.2)
    if u is not None:
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        fade = 1 - ease(max(0, (t - 1.02) / 0.18))
        f.kit.beam(head, head.lerp(f.TC, reach), 0.75 * k, SUN, 9, fade)
        f.kit.light(f.TC, SUN, 10 * fade)
    u = seg(t, IMPACT, 1.4)
    if u is not None:  # a starburst of rays
        for i in range(12):
            a = i / 12 * math.tau
            d = Vector((math.cos(a), -0.2, math.sin(a))).normalized()
            f.kit.spike(f.TC, f.TC + d * (1 + 5 * ease(u)) * k, 0.3 * k * (1 - u), YELLOW, 9, 1 - u)
    impact(f, SUN, 4, 77)


# (its legs within about 25 degrees: it is stone blocks cut apart at the joints, see concepts.SAHARA_LION)
JUDGEMENT_KEYS = [
    (0.00, {}),
    (0.22, P(crouch(14, -8), body=[-5, 0, 0, 0, -0.16, 0.2], head=[-18], tail=[6])),
    (0.50, P(body=[9, 0, 0, 0, 0.2, 0.45], head=[30], leg_fl=[20], leg_fr=[16], leg_bl=[-10], leg_br=[-10], tail=[-30])),
    (0.80, P(body=[11, 0, 0, 0, 0.26, 0.5], head=[38], leg_fl=[22], leg_fr=[20], leg_bl=[-12], leg_br=[-12], tail=[-38, 12])),
    (0.90, P(body=[-7, 0, 0, 0, -0.12, -0.6], head=[-14, 0, 0, 0, 0, -0.1], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[-24])),
    (1.02, P(body=[-7, 0, 0, 0, -0.12, -0.6], head=[-12, 0, 5, 0, 0, -0.1], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[-24])),
    (1.14, P(body=[-7, 0, 0, 0, -0.12, -0.6], head=[-12, 0, -5, 0, 0, -0.1], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[-24])),
    (1.38, P(body=[-2], head=[-4], tail=[-10])),
    (1.60, {}),
]


def sun_judgement(f):  # Sahara Guardian
    k, t = f.k, f.t
    # the middle of the sun halo it wears: the crown anchor is the tip of one of its spikes (studs at its built 12.6 height)
    halo = f.A["crown"] + Vector((-2.44, 1.22, -3.33)) * (f.H / 12.6)
    top = f.T + Z(11 * k)
    f.kit.aura(GOLD, 0.2 * env(t, 0.1, 0.6, 0.9, 1.1), 5)
    g = env(t, 0.1, 0.5, 1.0, 1.3)
    if g > 0:  # its halo blazes: a ring of light, sixteen turning rays, four gems circling
        f.kit.ring(halo, 1.3 * k * (1 + 0.25 * g), 0.1 * k, SUN, 9, g, Vector((0, 1, 0)), n=24)
        for i in range(16):
            a = t * 2.5 + i / 16 * math.tau
            d = Vector((math.cos(a), 0.0, math.sin(a)))
            f.kit.spike(halo + d * 1.4 * k, halo + d * (2.2 + 1.2 * (1 - i % 2)) * k * g, 0.16 * k, YELLOW, 9, g)
        for i in range(4):
            a = -t * 4 + i / 4 * math.tau
            f.kit.diamond(halo + Vector((math.cos(a), 0.0, math.sin(a))) * 2.0 * k, 0.22 * k, 0.5 * k, VIOLET, 7, g, spin=t * 6)
    w = env(t, 0.1, 0.4, 0.8, 0.95)
    if w > 0:  # sand whirls up round it as it rears
        f.kit.vortex(Vector((halo.x, halo.y + 2.5 * k, f.T.z)), 2.4 * k, 4.5 * k * w, SAND, t, n=5, glow=1.5, alpha=0.45 * w, w=0.2)
    s = env(t, 0.3, 0.75, 1.15, 1.4)
    if s > 0:  # a second, greater halo opens in the sky over the target
        f.kit.ring(top, 3.2 * k * s, 0.14 * k, SUN, 9, s, n=28)
        f.kit.ring(top, 2.4 * k * s, 0.06 * k, VIOLET, 7, s, n=20)
        for i in range(12):
            a = -t * 2 + i / 12 * math.tau
            d = Vector((math.cos(a), math.sin(a), 0.0))
            f.kit.spike(top + d * 3.3 * k * s, top + d * (4.3 + 0.9 * (i % 2)) * k * s, 0.2 * k, YELLOW, 9, s)
        for i in range(3):  # rings drop down the column, closing on the target
            v = ((t - 0.3) * 2.2 + i / 3) % 1
            f.kit.ring(top.lerp(f.T, v), (3.0 - 1.6 * v) * k, 0.05 * k, GOLD, 6, 0.7 * s * (1 - v), n=16)
    u = seg(t, 0.86, 1.45)
    if u is not None:  # the judgement: a pillar of sunlight slams down, and its roar strikes with it
        reach = ease(min(1, (t - 0.86) / (IMPACT - 0.86)))
        fade = 1 - ease(max(0, (t - 1.15) / 0.3))
        f.kit.beam(top, top.lerp(f.T, reach), 1.7 * k, SUN, 10, fade)
        f.kit.beam(top, top.lerp(f.T, reach), 2.3 * k, VIOLET, 5, 0.35 * fade, core=False)
        f.kit.beam(f.A["nose"], f.A["nose"].lerp(f.TC, reach), 0.35 * k, GOLD, 8, 0.8 * fade)
        f.kit.light(f.TC, SUN, 14 * fade)
    u = seg(t, IMPACT, 1.55)
    if u is not None:
        rise = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
        for i in range(16):  # a crown of sun spikes bursts out of the ground round the target
            a = i / 16 * math.tau
            out = Vector((math.cos(a), math.sin(a), 0.0))
            base = f.T + out * 2.4 * k
            f.kit.spike(base, base + (out * 0.45 + Z(1)).normalized() * (3.2 + 2.0 * (1 - i % 2)) * k * rise, 0.42 * k, GOLD if i % 2 else YELLOW, 8, rise)
        for i in range(2):  # two shock rings roll out, the second one violet
            v = u - i * 0.16
            if v > 0:
                f.kit.shock(f.T + Z(0.08), (1 + 7 * ease(min(1, v))) * k, 0.1 * k, VIOLET if i == 1 else SUN, 1 - min(1, v))
        for i in range(8):  # gems fly up and out
            a = i / 8 * math.tau + 0.4
            p = f.TC + Vector((math.cos(a), math.sin(a), 0.0)) * 2.2 * k * (0.4 + ease(u)) + Z((5 * u - 4 * u * u) * k)
            f.kit.diamond(p, 0.3 * k, 0.7 * k, VIOLET, 7, 1 - u, spin=u * 9)
        if u < 0.5:  # lightning down the pillar
            for i in range(4):
                a = i / 4 * math.tau + 0.8
                out = Vector((math.cos(a), math.sin(a), 0.0))
                f.kit.bolt(top + out * 2.0 * k, f.T + out * 3.0 * k, YELLOW, 0.1 * k, 0.14, seed=int(t * 30) + i, alpha=1 - u * 2)
    impact(f, SUN, 5.5, 91)


SHADOW_KEYS = [
    (0.00, {}),
    (0.35, P(crouch(30, -16), body=[-6, 0, 0, 0, -0.2, 0.2], head=[-16], tail=[-6, 20])),
    (0.80, P(crouch(32, -18), body=[-7, 0, 0, 0, -0.22, 0.25], head=[-18], tail=[-6, -20])),
    (0.88, P(body=[6, 0, 0, 0, 0.08, -0.2], leg_fr=[70, 0, 20], leg_fl=[10], head=[-4], tail=[-12])),
    (0.94, P(body=[-6, 0, 0, 0, -0.05, -0.35], leg_fr=[-10, 0, -10], leg_fl=[0], head=[-10], tail=[-12])),
    (1.30, P(body=[-2])),
    (1.60, {}),
]


def shadow_claws(f):  # Shadow Lion
    k, t = f.k, f.t
    paws = (f.A["paw_l"] + f.A["paw_r"]) / 2
    paws.z = f.T.z
    spread = seg(t, 0.3, 0.86)
    reach = ease(spread) if spread is not None else (1.0 if t > 0.86 else 0)
    fade = 1 - ease(max(0, (t - 1.25) / 0.3))
    if reach > 0 and fade > 0:  # a pool of shadow spreads to the dummy
        for s in range(6):
            p = paws.lerp(f.T, reach * s / 5)
            f.kit.disc(p, (1.0 + 1.6 * s / 5) * k, DARK, 0, 0.85 * fade)
        f.kit.ring(f.T + Z(0.05), 2.6 * k * reach, 0.08 * k, SHADOW, 7, fade)
    u = seg(t, 0.88, 1.5)
    if u is not None:  # three great claws rake up out of it
        for i in range(3):
            x = (i - 1) * 1.0 * k
            g = ease(min(1, (u - i * 0.05) * 5)) if u > i * 0.05 else 0
            g *= 1 - ease(max(0, (u - 0.7) / 0.3))
            if g <= 0:
                continue
            base = f.T + Vector((x, 2.2 * k, 0))
            pts = [base + Vector((0, -(1 - math.cos(a)) * 3.6, math.sin(a) * 5.6)) * k * g for a in [j / 10 * 1.4 for j in range(11)]]
            f.kit.tube(pts, 0.6 * k, DARK, 0.3, 1, taper=lambda x: 1 - 0.9 * x)
            f.kit.tube(pts, 0.68 * k, SHADOW, 5, 0.45, taper=lambda x: 1 - 0.9 * x)
    if 0.2 < t < 1.2:
        f.kit.orb(f.A["tail"], 0.4 * k, SHADOW, 8, 1, core=False, light=2)
    impact(f, SHADOW, 3.5, 79)


def thorn_grove(f):  # Acacia Giraffe
    k, t = f.k, f.t
    feet = (f.A["paw_l"] + f.A["paw_r"]) / 2
    feet.z = f.T.z
    u = seg(t, 0.45, 0.9)
    if u is not None or t > 0.9:  # roots burrow along under the ground, leaves sparkling where they pass
        reach = ease(u) if u is not None else 1.0
        fade = 1 - ease(max(0, (t - 1.2) / 0.3))
        for j in (-1, 1):
            f.kit.tube([feet.lerp(f.T, reach * s / 8) + Vector((j * (0.5 + 0.4 * math.sin(s * 1.7)), 0, 0.08)) * k for s in range(9)], 0.18 * k, (0.35, 0.22, 0.1), 0, fade)
        f.kit.spark(feet.lerp(f.T, reach) + Z(0.3 * k), 0.25 * k, LEAF, 7, fade)
    u = seg(t, 0.88, 1.55)
    if u is not None:  # thorny branches erupt round it
        g = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.65) / 0.35)))
        for i in range(6):
            a = i / 6 * math.tau + 0.2
            d = Vector((math.cos(a), math.sin(a), 0))
            b = f.T + d * 2.0 * k
            pts = [b + (d * -0.8 * s / 5 + Z(3.5 * s / 5) + d * 0.4 * math.sin(s)) * k * g for s in range(6)]
            f.kit.tube(pts, 0.22 * k, (0.35, 0.22, 0.1), 0.2, 1, taper=lambda x: 1 - 0.7 * x)
            for s in (2, 3, 4):
                q = pts[s]
                f.kit.spike(q, q + (d + Z(0.5)).normalized() * 0.8 * k * g, 0.1 * k, (0.95, 0.9, 0.7), 1, 1)
            f.kit.ball(pts[-1], 0.55 * k * g, LEAF, 1.5, 1)
        f.kit.burst(f.TC, u, 16, 4 * k, LEAF, 81, 0.18 * k, glow=4)
    impact(f, LEAF, 3, 83, flash=False)


def diamond_prison(f):  # Diamond Giraffe
    k, t = f.k, f.t
    crown = f.A["crown"]
    g = env(t, 0.25, 0.65, 0.8, 0.88)
    if g > 0:
        f.kit.orb(crown, 0.6 * k * g, DIAMOND, 9, g, light=3 * g)
    u = seg(t, 0.62, 0.84)
    if u is not None:  # a shard of light arcs over to the dummy
        p = bez(crown, (crown + f.TC) / 2 + Z(4 * k), f.TC + Z(4 * k), ease(u))
        f.kit.diamond(p, 0.4 * k, 1.2 * k, DIAMOND, 9, 1, spin=t * 10)
    u = seg(t, 0.82, 1.55)
    if u is not None:  # diamond pillars slam down round it into a cage, then shatter
        close = ease(min(1, (t - 0.82) / (IMPACT - 0.82)))
        shatter = seg(t, 1.15, 1.55)
        for i in range(6):
            a = i / 6 * math.tau
            d = Vector((math.cos(a), math.sin(a), 0))
            if shatter is None:
                p = f.T + d * (2.0 - 0.6 * close) * k + Z((2.2 + 6 * (1 - close)) * k)
                f.kit.diamond(p, 0.5 * k, 4.6 * k, DIAMOND, 6, 0.85, spin=a)
            else:
                for j in range(3):
                    q = f.T + d * (1.4 + 3 * shatter) * k + Z((1 + j * 1.4) * k + 2 * k * shatter - 3 * k * shatter * shatter)
                    f.kit.diamond(q, 0.3 * k, 0.8 * k, DIAMOND, 7, 1 - shatter, spin=t * 9 + j)
        if shatter is None and t >= IMPACT:
            f.kit.ring(f.T + Z(4.4 * k), 1.6 * k, 0.12 * k, WHITE, 8, 1)
    impact(f, DIAMOND, 3.5, 85)


def frozen_tomb(f):  # Frost Mammoth
    k, t = f.k, f.t
    tip = f.A["trunk"]
    breath = env(t, 0.3, 0.45, 0.72, 0.82)
    if breath > 0:  # frost swirling off its raised trunk
        f.kit.vortex(tip, 0.8 * k, 3 * k, FROST, t, n=3, glow=3, alpha=0.5 * breath, w=0.1)
    base = f.A["chest"].copy()
    base.z = f.T.z
    for i in range(7):  # a line of ice spikes racing to the dummy
        t0 = 0.82 + (IMPACT - 0.82) * i / 6
        u = seg(t, t0, t0 + 0.65)
        if u is None:
            continue
        p = base.lerp(f.T, (i + 0.5) / 7.5) + Vector((0.8 if i % 2 else -0.8, 0, 0)) * k
        h = (1.6 + 0.3 * i) * k * ease(min(1, u * 5)) * (1 - ease(max(0, (u - 0.6) / 0.4)))
        f.kit.spike(p, p + Z(h) + Vector((0, -0.4, 0)) * k, 0.55 * k, FROST, 4, 0.85)
    u = seg(t, IMPACT, 1.55)
    if u is not None:  # the dummy frozen in a block of ice, which shatters
        if u < 0.55:
            g = ease(min(1, u * 5))
            f.kit.box(f.T + Z(2.6 * k), (3.0 * k * g, 3.0 * k * g, 5.6 * k * g), FROST, 1.5, 0.45)
        else:
            s = (u - 0.55) / 0.45
            for i in range(10):
                a = i / 10 * math.tau
                q = f.T + Vector((math.cos(a), math.sin(a), 0)) * (1.2 + 3 * s) * k + Z((1 + (i % 3) * 1.6) * k + 2 * k * s - 3 * k * s * s)
                f.kit.diamond(q, 0.35 * k, 0.9 * k, FROST, 3, 1 - s, spin=t * 8 + i)
    impact(f, FROST, 4, 87)


def burning_volley(f):  # War Elephant
    k, t = f.k, f.t
    back = f.A["back"] + Z(1.5 * k)
    rune = env(t, 0.25, 0.5, 0.72, 0.85)
    if rune > 0:  # a war rune flares over its back
        f.kit.circle(back, 2.6 * k * rune, EMBER, t * 3, 7, rune, spokes=6)
        f.kit.light(back, EMBER, 5 * rune)
    for i in range(8):
        t0 = 0.6 + i * 0.02
        u = seg(t, t0, 0.84 + i * 0.012)
        if u is None:
            continue
        a = back + Vector((0, (i % 4 - 1.5) * 0.9, 0.4 * (i // 4))) * k
        end = f.T + Vector(((i // 4 - 0.5) * 1.4, (i % 4 - 1.5) * 0.9, 0)) * k
        ctrl = (a + end) / 2 + Z(f.sky * 0.8)
        p = bez(a, ctrl, end, u)
        q = bez(a, ctrl, end, min(1, u + 0.04))
        d = (q - p).normalized()
        f.kit.spike(p - d * 1.4 * k, p, 0.16 * k, (0.25, 0.2, 0.18), 0, 1)
        f.kit.orb(p, 0.4 * k, FIRE, 7, 0.9, core=False)
        f.kit.trail([bez(a, ctrl, end, max(0, u - m * 0.04)) for m in range(6)], 0.45 * k, EMBER, 5, 0.55)
    u = seg(t, 0.86, 1.5)
    if u is not None:
        for i in range(8):
            q = f.T + Vector(((i // 4 - 0.5) * 1.4, (i % 4 - 1.5) * 0.9, 0)) * k
            f.kit.spike(q, q + Z(1.5 * k * (1 - u)), 0.45 * k, FIRE, 7, 1 - u)
        f.kit.burst(f.TC, u, 20, 4 * k, EMBER, 89, 0.16 * k, rise=0.8)
    impact(f, FIRE, 4, 91)


AXE_KEYS = [
    (0.00, {}),
    (0.35, P(body=[14, 0, 0, 0, 0.18, 0.25], head=[44], leg_fl=[30], leg_fr=[26], leg_bl=[-14], leg_br=[-14], tail=[-14])),
    (0.76, P(body=[22, 0, 0, 0, 0.28, 0.32], head=[54], leg_fl=[48], leg_fr=[44], leg_bl=[-22], leg_br=[-22], tail=[-18])),
    (0.90, P(body=[-10, 0, 0, 0, -0.1, -0.5], head=[-12], leg_fl=[-18], leg_fr=[-16], leg_bl=[12], leg_br=[12], tail=[20])),
    (1.15, P(body=[-5, 0, 0, 0, -0.04, -0.3], head=[-10])),
    (1.60, {}),
]
IRON, HAFT = (0.1, 0.08, 0.08), (0.28, 0.15, 0.07)


def dawnbreaker(f):  # Sahara Mammoth
    k, t = f.k, f.t
    paws = (f.A["paw_l"] + f.A["paw_r"]) / 2
    feet = Vector((paws.x, paws.y, f.T.z))
    back = f.A["back"]  # the tip of the sun spike on its back
    f.kit.aura(GOLD, 0.2 * env(t, 0.1, 0.6, 0.9, 1.1), 5)
    g = env(t, 0.1, 0.5, 0.95, 1.25)
    if g > 0:  # a sun wheel blazes over its back and its tusks glow
        f.kit.ring(back, 1.5 * k * g, 0.1 * k, SUN, 9, g, Vector((0, 1, 0)), n=24)
        for i in range(12):
            a = t * 2 + i / 12 * math.tau
            d = Vector((math.cos(a), 0.0, math.sin(a)))
            f.kit.spike(back + d * 1.6 * k * g, back + d * (2.6 + 0.8 * (i % 2)) * k * g, 0.16 * k, YELLOW, 9, g)
        f.kit.orb(f.A["nose"], 0.45 * k * g, SUN, 8, g)
    s = env(t, 0.25, 0.7, 1.2, 1.5)
    if s > 0:  # a sun sigil turns on the ground under the target, gems circling over it
        f.kit.circle(f.T, 3.4 * k * s, GOLD, t * 1.5, 6, 0.9 * s, 12)
        for i in range(4):
            a = t * 3 + i / 4 * math.tau
            f.kit.diamond(f.TC + Vector((math.cos(a), math.sin(a), 0.0)) * 2.6 * k + Z(1.5 * k), 0.25 * k, 0.6 * k, VIOLET, 7, s, spin=t * 6)
    u = seg(t, 0.84, 1.3)
    if u is not None:  # it stamps: a shock rolls out from its feet and a line of sun spikes races to the target
        run = ease(min(1, (t - 0.84) / (IMPACT - 0.84)))
        sink = 1 - ease(max(0, (t - 1.05) / 0.25))
        f.kit.shock(feet + Z(0.08), (1 + 4 * ease(min(1, u * 2))) * k, 0.1 * k, SUN, 1 - min(1, u * 2))
        for i in range(9):
            v = (i + 1) / 10
            if v <= run and sink > 0:
                side = Vector((0.5 if i % 2 else -0.5, 0.0, 0.0)) * k
                p = feet.lerp(f.T, v) + side
                f.kit.spike(p, p + side * 0.6 + Z((1.2 + 1.8 * v) * k * sink), 0.35 * k, GOLD if i % 2 else YELLOW, 8, sink)
    u = seg(t, IMPACT, 1.55)
    if u is not None:
        rise = ease(min(1, u * 3.5)) * (1 - ease(max(0, (u - 0.65) / 0.35)))
        if rise > 0:  # two colossal tusks of light erupt either side of the target and cross over it
            for sgn in (-1, 1):
                pts = []
                for j in range(11):
                    a = j / 10 * 1.4
                    pts.append(f.T + Vector((sgn * (3.2 - 4.2 * (1 - math.cos(a))), 0.0, 7.5 * math.sin(a))) * k * rise)
                f.kit.tube(pts, 0.75 * k, SUN, 6, rise, taper=lambda x: 1 - 0.92 * x)
                f.kit.tube(pts, 0.85 * k, GOLD, 3, 0.35 * rise, taper=lambda x: 1 - 0.92 * x)
            f.kit.light(f.TC, SUN, 14 * rise)
        for i in range(12):  # a starburst of rays
            a = i / 12 * math.tau
            d = Vector((math.cos(a), math.sin(a), 0.35)).normalized()
            f.kit.spike(f.TC, f.TC + d * (1 + 6 * ease(u)) * k, 0.3 * k * (1 - u), YELLOW, 9, 1 - u)
        f.kit.shock(f.T + Z(0.08), (1 + 8 * ease(u)) * k, 0.1 * k, VIOLET, 1 - u)
        for i in range(8):  # gems fly up and out
            a = i / 8 * math.tau + 0.4
            p = f.TC + Vector((math.cos(a), math.sin(a), 0.0)) * 2.2 * k * (0.4 + ease(u)) + Z((5 * u - 4 * u * u) * k)
            f.kit.diamond(p, 0.3 * k, 0.7 * k, VIOLET, 7, 1 - u, spin=u * 9)
    impact(f, SUN, 6, 93)


def sun_barrage(f):  # Sunfire War-Tortoise
    k, t = f.k, f.t
    muzzle = f.A["chest"]  # the cannon's mouth: the body's frontmost point
    g = env(t, 0.15, 0.75, 0.85, 1.0)
    if g > 0:  # the cannon drinks in the sun: an orb swells at its mouth, rings closing in
        f.kit.orb(muzzle, 0.9 * k * g, SUN, 8, g, light=5 * g)
        for i in range(3):
            v = ((t - 0.15) * 2 + i / 3) % 1
            f.kit.ring(muzzle, (2.2 - 1.8 * v) * k * g, 0.05 * k, GOLD, 6, 0.8 * g * v)
    for i, t0 in enumerate((0.84, 0.92, 1.0)):  # three sun shells arc out of the cannon, one after another
        side = Vector(((i - 1) * 2.2, 0, 0)) * k
        land = f.T + side

        def shell(p, u):
            f.kit.orb(p, 0.55 * k, SUN, 9, 1.0)
        flight(f, muzzle, land + Z(0.4 * k), t0, t0 + 0.28, 6 * k, shell, trail=(GOLD, 0.3 * k))
        u = seg(t, t0 + 0.28, t0 + 0.75)
        if u is not None:  # each bursts in a ring of sunfire
            f.kit.shock(land + Z(0.08), (0.5 + 4 * ease(u)) * k, 0.09 * k, SUN, 1 - u)
            f.kit.orb(land + Z(0.8 * k), (0.4 + 1.4 * ease(min(1, u * 3))) * k, YELLOW, 8, (1 - u) ** 1.5)
            f.kit.burst(land + Z(0.6 * k), u, 10, 3 * k, GOLD, 50 + i, 0.12 * k)
    if 0.82 < t < 1.1:  # the cannon's flash
        f.kit.star(muzzle, 2.4 * k, SUN, 1 - (t - 0.82) / 0.28)
    impact(f, SUN, 5, 95)


def sunfire_horn(f):  # Molten Sun Rhino
    k, t = f.k, f.t
    horn = f.A["horn"]
    paws = (f.A["paw_l"] + f.A["paw_r"]) / 2
    feet = Vector((paws.x, paws.y, f.T.z))
    g = env(t, 0.15, 0.7, 0.9, 1.05)
    if g > 0:  # its horn takes fire and molten cracks glow under its feet
        f.kit.orb(horn, 0.6 * k * g, SUN, 9, g, light=4 * g)
        f.kit.disc(feet, 2.2 * k * g, LAVA, 3, 0.5 * g)
    u = seg(t, 0.8, 1.25)
    if u is not None:  # a molten crack races to the target and sun spikes burst up along it
        run = ease(min(1, (t - 0.8) / (IMPACT - 0.8)))
        fade = 1 - ease(max(0, (t - 1.05) / 0.2))
        f.kit.beam(feet + Z(0.05), feet.lerp(f.T, run) + Z(0.05), 0.25 * k, LAVA, 8, fade)
        for i in range(7):
            v = (i + 1) / 8
            if v <= run:
                p = feet.lerp(f.T, v)
                f.kit.spike(p, p + Z((0.8 + 2.2 * v) * k * fade), 0.4 * k, SUN if i % 2 else LAVA, 8, fade)
        f.kit.beam(horn, horn.lerp(f.TC, run), 0.4 * k, SUN, 10, fade)
    u = seg(t, IMPACT, 1.5)
    if u is not None:  # a pillar of molten sun erupts under the target
        rise = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.5) / 0.5)))
        f.kit.beam(f.T, f.T + Z(9 * k * rise), 1.3 * k, LAVA, 8, rise)
        f.kit.beam(f.T, f.T + Z(9 * k * rise), 0.7 * k, YELLOW, 10, rise)
        f.kit.shock(f.T + Z(0.08), (1 + 6 * ease(u)) * k, 0.1 * k, SUN, 1 - u)
    impact(f, SUN, 5, 96)


def war_axe(f):  # War Elephant
    """the axe in its trunk grows into a huge axe of iron and fire, which it swings up over its head and brings
    down through the target, splitting the ground"""
    k, t = f.k, f.t
    pivot = f.A["trunk"]  # its trunk's grip
    g = ease(min(1.0, max(0.0, (t - 0.42) / 0.48)))  # how far it has grown: most of it in the swing
    sc = 0.3 + 0.7 * g
    bd = 3.4 * k  # how far the blade's edge stands off the haft, full grown
    v = f.TC - pivot
    full = math.sqrt(max(v.length ** 2 - bd ** 2, 1.0))
    reach = 1.0 * k + (full - 1.0 * k) * g
    hit = math.atan2(-v.y, v.z) - math.atan2(bd, full)  # the angle (0 = straight up, + forward) the edge meets the target
    back = -1.25  # raised behind its head, over its back
    d = lambda a: Vector((0, -math.sin(a), math.cos(a)))  # noqa: E731  along the haft
    s = lambda a: Vector((0, -math.cos(a), -math.sin(a)))  # noqa: E731  the way the edge faces (the swing)
    form = env(t, 0.25, 0.4, 2, 3)
    swing = seg(t, 0.76, IMPACT)
    gone = seg(t, 1.12, 1.45)
    if t < 0.76:
        a = 0.35 + (back - 0.35) * ease(min(1, max(0, (t - 0.3) / 0.45)))  # drawn back over its head as it grows
    elif swing is not None:
        a = back + (hit - back) * swing ** 2.2  # faster and faster
    else:
        a = hit + 0.05 * ease(min(1, (t - IMPACT) / 0.1))  # bites in a little further
    alpha = form if t < 1.12 else (1 - gone if gone is not None else 0.0)

    rune = env(t, 0.2, 0.45, 0.8, 0.95)  # the war rune flares over its back
    top = f.A["back"] + Z(1.5 * k)
    if rune > 0:
        f.kit.circle(top, 2.6 * k * rune, EMBER, t * 3, 5, 0.7 * rune, spokes=6)
        f.kit.light(top, EMBER, 3 * rune)
    if 0.25 < t < 0.76:  # embers stream from the rune into the axe as it grows
        for i in range(8):
            u = (t * 2.2 + i / 8) % 1
            q = pivot + d(a) * reach * ((i % 6) / 6)
            f.kit.spark(top.lerp(q, ease(u)), 0.12 * k, FIRE, 6, 0.7 * (1 - u) * form)

    if alpha > 0.01:
        hd = pivot + d(a) * reach  # the axe's head
        f.kit.tube([pivot - d(a) * 1.0 * k * sc, hd + d(a) * 1.0 * k * sc], 0.26 * k * sc, HAFT, 0.0, alpha)  # the haft
        for j in range(4):  # iron bands with glowing runes
            f.kit.ring(pivot + d(a) * (reach * (0.15 + 0.22 * j)), 0.32 * k * sc, 0.09 * k * sc, EMBER, 4, alpha, normal=d(a), n=16)
        f.kit.spike(hd + d(a) * 0.8 * k * sc, hd + d(a) * 2.2 * k * sc, 0.4 * k * sc, IRON, 0, alpha)  # the top spike
        f.kit.spike(hd - s(a) * 0.3 * k * sc, hd - s(a) * 1.8 * k * sc, 0.45 * k * sc, IRON, 0, alpha)  # the back spike
        # the blade: a great half moon off the haft, iron with a molten edge
        re, span = 3.0 * k * sc, 0.95
        c = hd + s(a) * (bd * sc - re)
        edge = [c + (s(a) * math.cos(x) + d(a) * math.sin(x)) * re for x in [-span + 2 * span * i / 14 for i in range(15)]]
        inner = [hd - d(a) * 0.8 * k * sc, hd + d(a) * 0.8 * k * sc]
        for side in (-0.12, 0.12):  # two faces a little apart, so it reads as a thick blade
            off = Vector((side * k, 0, 0))
            verts = [hd + s(a) * 0.3 * k * sc + off, inner[0] + off] + [p + off for p in edge] + [inner[1] + off]
            faces = [(0, i, i + 1) for i in range(1, len(verts) - 1)]
            f.kit._mesh(verts, faces, IRON, 0.0, alpha)
        hot = 1.0 if swing is not None or t >= IMPACT else 0.6
        f.kit.tube(edge, 0.18 * k * sc, FIRE, 6 * hot, alpha, taper=lambda x: 0.5 + 0.5 * math.sin(math.pi * x))
        f.kit.ring(hd + s(a) * 1.1 * k * sc, 0.7 * k * sc, 0.08 * k * sc, EMBER, 4, 0.6 * alpha, normal=Vector((1, 0, 0)))  # a rune ring on the blade
        if swing is not None:  # a sheet of fire behind the edge as it sweeps
            for w, rgb, g, al in ((1.1, EMBER, 4, 0.3), (0.45, YELLOW, 6, 0.35)):
                pts = []
                for i in range(10):
                    ai = back + (hit - back) * max(0.0, swing - i * 0.07) ** 2.2
                    pts.append(pivot + d(ai) * reach + s(ai) * bd)
                f.kit.trail(pts, w * k, rgb, g, al)

    u = seg(t, IMPACT, 1.55)
    if u is not None:  # the ground splits along the cut
        fwd = Vector((0, -1, 0))
        g = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.55) / 0.45)))
        f.kit.tube([f.T - fwd * 3.5 * k * g + Z(0.05), f.T + fwd * 3.5 * k * g + Z(0.05)], 0.25 * k, LAVA, 6, 0.8 * g)
        for i in range(6):
            q = f.T + fwd * (i - 2.5) * 1.3 * k * g + Vector(((0.7 if i % 2 else -0.7) * k, 0, 0))
            f.kit.spike(q, q + Z(1.4 * k * g) + Vector(((0.5 if i % 2 else -0.5) * k, 0, 0)), 0.5 * k, ROCK, 0, 1)
        f.kit.burst(f.TC, u, 14, 4 * k, EMBER, 93, 0.15 * k, rise=0.9)
    if gone is not None:  # the axe bursts into embers
        hd = pivot + d(a) * reach
        f.kit.burst(hd + s(a) * 1.2 * k, gone, 10, 3 * k, FIRE, 95, 0.13 * k, rise=1.2)
    impact(f, FIRE, 4, 97)


# ---- the body moves the variants borrow from their species' new ones, or their own ---------------------------------
BEACON_ONE_ARM = [
    (0.00, {}),
    (0.30, P(leg_fr=[160, 0, -10], leg_fl=[60], body=[4, 0, 0, 0, 0.04, 0], head=[20])),
    (0.80, P(leg_fr=[165, 0, -10], leg_fl=[60], body=[5, 0, 0, 0, 0.05, 0], head=[24])),
    (0.90, P(leg_fr=[70], leg_fl=[50], body=[-10, 0, 0, 0, 0, -0.15], head=[-4], leg_bl=[10], leg_br=[10])),
    (1.25, P(leg_fr=[30], leg_fl=[30])),
    (1.60, {}),
]
TRUMPET = [
    (0.00, {}),
    (0.35, P(body=[16, 0, 0, 0, 0.2, 0.25], head=[40], leg_fl=[36], leg_fr=[32], leg_bl=[-16], leg_br=[-16], tail=[-14])),
    (0.72, P(body=[20, 0, 0, 0, 0.26, 0.3], head=[46], leg_fl=[46], leg_fr=[42], leg_bl=[-20], leg_br=[-20], tail=[-16])),
    (0.82, P(body=[-10, 0, 0, 0, -0.1, -0.5], head=[-16], leg_fl=[-16], leg_fr=[-14], leg_bl=[10], leg_br=[10], tail=[18])),
    (1.15, P(body=[-4, 0, 0, 0, -0.03, -0.25], head=[-6])),
    (1.60, {}),
]
PECK_WINGS = [
    (0.00, {}),
    (0.30, P(leg_bl=[0, 0, 75], leg_br=[0, 0, -75], head=[26], body=[6], tail=[-30])),
    (0.80, P(leg_bl=[0, 0, 85], leg_br=[0, 0, -85], head=[30], body=[8], tail=[-34])),
    (0.90, P(leg_bl=[30, 0, 30], leg_br=[30, 0, -30], head=[-20], body=[-8, 0, 0, 0, 0, -0.2], tail=[-10])),
    (1.30, P(leg_bl=[0, 0, 20], leg_br=[0, 0, -20])),
    (1.60, {}),
]

# ---- the Sahara pair's regular attacks: effects on the 0.95 s attack clip, the hit at HIT (Spells' "<asset>@attack") --
HIT = 0.44


def sunfang(f):  # Sahara Guardian
    k, t = f.k, f.t
    halo = f.A["crown"] + Vector((-2.44, 1.22, -3.33)) * (f.H / 12.6)
    g = env(t, 0.1, 0.3, 0.5, 0.7)
    if g > 0:  # its halo flares as it lunges
        f.kit.ring(halo, 1.3 * k * (1 + 0.2 * g), 0.08 * k, SUN, 9, g, Vector((0, 1, 0)), n=24)
    u = seg(t, 0.36, 0.8)
    if u is not None:  # three claws of sunlight rake across the target
        reach = ease(min(1, u * 4))
        fade = 1 - ease(max(0, (u - 0.4) / 0.6))
        for i in (-1, 0, 1):
            a = f.TC + Vector((-2.2, 0.0, 1.6 + 0.9 * i)) * k
            b = f.TC + Vector((2.2, 0.0, -1.6 + 0.9 * i)) * k
            f.kit.beam(a, a.lerp(b, reach), 0.16 * k, YELLOW, 9, fade)
        f.kit.star(f.TC, 3 * k * (0.6 + 0.4 * reach), SUN, fade)
        f.kit.shock(f.T + Z(0.08), (0.5 + 3.5 * ease(u)) * k, 0.07 * k, SUN, 1 - u)
        f.kit.burst(f.TC, u, 10, 3 * k, GOLD, 31, 0.1 * k)


def tusk_heave(f):  # Sahara Mammoth
    k, t = f.k, f.t
    g = env(t, 0.15, 0.3, 0.5, 0.65)
    if g > 0:  # its tusks glow as it drives in
        f.kit.orb(f.A["nose"], 0.4 * k * g, SUN, 8, g)
    u = seg(t, 0.38, 0.85)
    if u is not None:
        rise = ease(min(1, u * 4)) * (1 - ease(max(0, (u - 0.55) / 0.45)))
        for i in range(-2, 3):  # the ground breaks into stone spikes under the target
            p = f.T + Vector((0.9 * i, 0.0, 0.0)) * k
            f.kit.spike(p, p + Z((1.4 + 0.8 * (2 - abs(i))) * k * rise), 0.4 * k, SAND if i % 2 else GOLD, 3, rise)
        # a crescent of sunlight follows the tusks up
        f.kit.crescent(f.TC + Z((-1 + 3 * ease(u)) * k), 2.6 * k, 0.5 * k, SUN, Vector((1, 0, 0)), Vector((0, -0.5, 1)), 8, 1 - u)
        f.kit.shock(f.T + Z(0.08), (0.5 + 4 * ease(u)) * k, 0.08 * k, VIOLET, 1 - u)
        f.kit.burst(f.TC, u, 10, 3 * k, SAND, 37, 0.12 * k)


STRIKES = {"creature_lion_sahara_forge": sunfang, "creature_elephant_sahara_forge": tusk_heave}

CONCEPTS = {
    "creature_jackal_forge": ("Jackal", {
        "m_moonfang": ("Moonfang", "Sits back and howls at the sky; a silver crescent moon forms over the target and falls on it like a blade.", HOWL_SIT, {}, moonfang),
        "m_pack": ("Spirit Pack", "Howls up two ghostly jackals of blue light, which leap from its sides and tear through the target.", HOWL_SIT, {}, spirit_pack),
    }),
    "creature_tortoise_forge": ("Tortoise", {
        "m_pillars": ("Rune Pillars", "Rears and stamps; a jade crack runs to the target and stone pillars banded with glowing runes burst up along it, the last lifting the target.", REAR_SLAM, {}, rune_pillars),
        "m_nova": ("Shell Nova", "Pulls into its shell over a spinning jade rune circle, glowing brighter, then bursts in a dome of jade light that rolls out over the target.", SHELL_NOVA_KEYS, {}, shell_nova),
    }),
    "creature_meerkat_forge": ("Meerkat", {
        "m_sunorb": ("Sun Orb", "Holds its paws up and gathers a little sun overhead, rays turning round it, then hurls it at the target.", SUN_THROW, {}, sun_orb),
        "m_beacon": ("Sky Beacon", "Points both paws to the sky; a sun sigil opens over the target and a pillar of sunlight slams down on it.", BEACON_KEYS, {}, sky_beacon),
    }),
    "creature_cheetah_forge": ("Cheetah", {
        "m_blades": ("Wind Blades", "Two quick swipes send crescents of wind at the target, then a double swipe sends a big one at the impact.", BLADE_KEYS, {}, wind_blades),
        "m_cyclone": ("Cyclone", "Lashes its tail round and round; the wind streams off it into a cyclone that lifts and spins the target.", CYCLONE_KEYS, {}, cyclone),
    }),
    "creature_rhino_forge": ("Rhino", {
        "m_lance": ("Horn Lance", "Lowers its head while light gathers on its horn, then fires an amber beam from the horn into the target.", LANCE_KEYS, {}, horn_lance),
        "m_quake": ("Quake Rings", "Rears over a glowing circle and slams down; waves of force roll across the ground and rock spikes burst up under the target.", QUAKE_KEYS, {}, quake_rings),
    }),
    "creature_flamingo_forge": ("Flamingo", {
        "m_darts": ("Feather Darts", "Spreads its wings as glowing pink feathers form along them, then sweeps them forward and fires the feathers in a volley.", DART_KEYS, {}, feather_darts),
        "m_geyser": ("Lake Geyser", "Taps the ground with its beak; bubbles race to the target, a pool opens under it and a geyser of water throws it up.", GEYSER_KEYS, {}, lake_geyser),
    }),
    "creature_lion_forge": ("Lion", {
        "m_roar": ("Golden Roar", "Glows gold as it draws in a breath, then roars a cone of golden light with rings of sound rolling down it.", ROAR_KEYS, {}, golden_roar),
        "m_spirit": ("Spirit Lion", "Roars up a giant lion of golden light, which rises over it and pounces on the target.", SPIRIT_ROAR_KEYS, {}, spirit_lion),
    }),
    "creature_giraffe_forge": ("Giraffe", {
        "m_halo": ("Halo Strike", "A ring of light forms over its horns, floats over to the target, grows and drops round it in a wall of light.", SKY_KEYS, {}, halo_strike),
        "m_lance": ("Sky Lance", "Points its head at the sky; a great spear of light forms high over the target and plunges into it.", SKY_KEYS, {}, sky_lance),
    }),
    "creature_elephant_forge": ("Elephant", {
        "m_orb": ("Titan Orb", "Rears with its trunk high, gathering a huge violet orb at its tip, then throws it with its trunk.", ORB_KEYS, {}, titan_orb),
        "m_quake": ("Titan Quake", "Rears and slams down; violet cracks race to the target, a rune circle opens under it and a ring of stone spikes bursts up.", QUAKE_TITAN_KEYS, {}, titan_quake),
    }),
    "creature_jackal_pharaoh_forge": ("Pharaoh Jackal", {
        "m_anubis": ("Judgement of Anubis", "Sits like a temple statue; a golden ankh appears over the target, held by a turquoise beam from its brow gem, then slams down; glyphs rise round the target.", HOWL_SIT, {}, anubis),
    }),
    "creature_jackal_sphinx_forge": ("Sphinx Jackal", {
        "m_sand": ("Sandstorm Riddle", "The sun disc between its ears blazes as a sandstorm with golden glyphs whirls round the target, then the disc fires a beam of sunlight into it.", HOWL_SIT, {}, sandstorm),
    }),
    "creature_tortoise_gemshell_forge": ("Gemshell Tortoise", {
        "m_gems": ("Gem Barrage", "Six glowing gems lift off its shell and hover, then fire at the target one after another and shatter on it.", REAR_SLAM, {}, gem_barrage),
    }),
    "creature_tortoise_island_forge": ("Island Tortoise", {
        "m_surge": ("Island Surge", "Rears and stamps; a wave rises before it and rolls over the target, and vines and glowing flowers spring up round it.", REAR_SLAM, {}, island_surge),
    }),
    "creature_meerkat_star_forge": ("Comet Meerkat", {
        "m_comet": ("Comet Strike", "Points to the sky with a line of starlight; a comet streaks across the sky and crashes onto the target in a shower of stars.", BEACON_ONE_ARM, {}, comet_strike),
    }),
    "creature_meerkat_storm_forge": ("Alien Meerkat", {
        "m_ufo": ("Abduction Beam", "Calls a flying saucer over the target, lifts it up in a green tractor beam, then zaps it back down.", BEACON_ONE_ARM, {}, abduction),
    }),
    "creature_cheetah_lightning_forge": ("Lightning Cheetah", {
        "m_chain": ("Chain Lightning", "Lightning crackles at its tail tip, then a bolt leaps to the target and chains on to two more behind it.", CYCLONE_KEYS, {}, chain_lightning),
    }),
    "creature_cheetah_thunder_forge": ("Thunder Cheetah", {
        "m_thunder": ("Thunderhead", "A storm cloud boils up over its back, drifts over the target and hammers it with three bolts and a thunderclap.", CYCLONE_KEYS, {}, thunderhead),
    }),
    "creature_rhino_lava_forge": ("Lava Rhino", {
        "m_magma": ("Magma Eruption", "Rears and slams; lava cracks race to the target, a pool of lava opens under it and erupts, throwing up molten rocks.", QUAKE_KEYS, {}, magma),
    }),
    "creature_rhino_crystal_forge": ("Crystal Rhino", {
        "m_prism": ("Prism Beam", "Seven coloured lights circle into its crystal horn, then it fires a white beam wound with all seven colours; crystals of each colour burst from the target.", LANCE_KEYS, {}, prism),
    }),
    "creature_flamingo_peacock_forge": ("King Flamingo", {
        "m_fan": ("Royal Fan", "Raises its great fan; every eye spot lights up, then they all fire beams into the target and a crown of light forms over it.", PECK_WINGS, {}, royal_fan),
    }),
    "creature_flamingo_phoenix_forge": ("Phoenix Flamingo", {
        "m_firebird": ("Firebird", "Wreathed in flames, it spreads its wings and sends a giant bird of fire diving onto the target, which bursts in a ring of fire.", PECK_WINGS, {}, firebird),
    }),
    "creature_lion_sun_forge": ("Sun Lion", {
        "m_solar": ("Solar Flare", "A sun with twelve rays rises behind its head, then fires a blazing beam that bursts into a star of light on the target.", ROAR_KEYS, {}, solar_flare),
    }),
    "creature_lion_sahara_forge": ("Sahara Guardian", {
        "m_judgement": ("Sun's Judgement", "Rears up as its halo blazes and sand whirls round it; a greater halo opens in the sky over the target, then it slams down and a pillar of sunlight falls through it, a crown of sun spikes bursting from the ground.", JUDGEMENT_KEYS, {}, sun_judgement),
    }),
    "creature_lion_shadow_forge": ("Shadow Lion", {
        "m_claws": ("Shadow Claws", "Crouches low as a pool of shadow spreads from its paws under the target, then swipes and three giant claws rake up out of it.", SHADOW_KEYS, {}, shadow_claws),
    }),
    "creature_giraffe_acacia_forge": ("Acacia Giraffe", {
        "m_thorns": ("Thorn Grove", "Stamps; roots burrow to the target and thorny acacia branches erupt all round it, leaves flying.", SKY_KEYS, {}, thorn_grove),
    }),
    "creature_giraffe_diamond_forge": ("Diamond Giraffe", {
        "m_prison": ("Diamond Prison", "Its horns flash and throw a diamond over the target; diamond pillars slam down round it into a cage, then shatter.", SKY_KEYS, {}, diamond_prison),
    }),
    "creature_elephant_frost_forge": ("Frost Mammoth", {
        "m_tomb": ("Frozen Tomb", "Trumpets a swirl of frost, slams down and sends a line of ice spikes racing to the target, freezing it in a block of ice that shatters.", TRUMPET, {}, frozen_tomb),
    }),
    "creature_elephant_sahara_forge": ("Sahara Mammoth", {
        "m_dawn": ("Dawnbreaker", "A sun wheel blazes over its back as a sun sigil turns under the target; it stamps, a line of sun spikes races along the ground, and two colossal tusks of light erupt either side of the target and cross over it.", AXE_KEYS, {}, dawnbreaker),
    }),
    "creature_tortoise_sahara_forge": ("Sunfire War-Tortoise", {
        "m_barrage": ("Sun Barrage", "Hunkers down as its sun cannon drinks in the light, then fires three blazing sun shells that arc onto the target and burst in rings of sunfire.", SHELL_NOVA_KEYS, {}, sun_barrage),
    }),
    "creature_rhino_sahara_forge": ("Molten Sun Rhino", {
        "m_sunhorn": ("Sunfire Horn", "Its horn takes fire as molten cracks glow under it; a crack races to the target with sun spikes bursting along it, its horn fires, and a pillar of molten sun erupts.", LANCE_KEYS, {}, sunfire_horn),
    }),
    "creature_elephant_war_forge": ("War Elephant", {
        "m_volley": ("Burning Volley", "A war rune flares over its back and fires a volley of flaming spears high into the air, which rain down on the target.", TRUMPET, {}, burning_volley),
        "m_axe": ("War Axe", "Its war rune forges a huge axe of iron and fire over its head, which swings up and over and cleaves down through the target, splitting the ground.", AXE_KEYS, {}, war_axe),
    }),
}
