"""VFX shapes the client tints at runtime (src/night-client/CombatFx.client.luau): the slash
crescent (slash 144-178) and the Demon Trigger wing (addAura 1218-1233), plus the pond koi
(src/night/Arena.luau 478-490). VFX meshes are baked white; use them untextured and set Color."""

import math

import kit as k


def slash_arc():
    white = k.mat("white", (255, 255, 255), kind="flat")
    outer, inner, span = 4.0, 3.3, math.radians(130)
    n = 24
    pts_out, pts_in = [], []
    for i in range(n + 1):
        a = -span / 2 + span * i / n
        pts_out.append((math.sin(a) * outer, math.cos(a) * outer))
        taper = math.sin(math.pi * i / n)
        r = outer - (outer - inner) * taper
        pts_in.append((math.sin(a) * r, math.cos(a) * r))
    outline = pts_out + list(reversed(pts_in[1:-1]))
    # Flat in the horizontal plane (x/y), thin in z, the arc bulging toward +Y.
    ob = k.poly(outline, 0.1, m=white)
    ob.data.transform(k.Matrix.Rotation(math.radians(-90), 4, "X"))
    return [ob]


def demon_wing():
    white = k.mat("white", (255, 255, 255), kind="flat")
    # Bat wing outline in the y/z plane (thin along x): shoulder at the origin, tips trailing back.
    outline = [(0, 0), (-0.6, 0.8), (-1.6, 2.6), (-2.6, 3.4), (-2.2, 2.2), (-2.8, 1.9), (-2.1, 1.1), (-2.6, 0.5), (-1.6, 0.2), (-1.0, -0.5)]
    wing = k.poly(outline, 0.1, m=white)
    wing.data.transform(k.Matrix.Rotation(math.radians(90), 4, "Z"))
    bones = [k.tube([(0, 0, 0), (0, -1.6, 2.6), (0, -2.6, 3.4)], [0.08, 0.06, 0.0], m=white, n=5)]
    for tip in ((0, -2.8, 1.9), (0, -2.6, 0.5)):
        bones.append(k.tube([(0, -0.6, 0.8), tip], [0.06, 0.0], m=white, n=5))
    return [wing] + bones


def koi():
    body_m = k.mat("koi", (255, 120, 40), kind="patches", rgb2=(250, 245, 240), scale=3.5)
    fin = k.mat("fin", (255, 170, 120), var=0.1, scale=6)
    eye = k.mat("eye", (10, 8, 10), kind="flat")
    body = k.lathe([(0, -0.62), (0.08, -0.5), (0.22, -0.15), (0.26, 0.15), (0.2, 0.45), (0.1, 0.62), (0, 0.66)], m=body_m, n=10, rot=(-90, 0, 0), scale=(0.7, 1, 1))
    body.data.transform(k.Matrix.Diagonal((0.75, 1, 0.7, 1)))
    body.data.transform(k.move(0, 0, 0.15))
    tail = k.poly([(0, 0), (0.35, -0.3), (0.12, 0), (0.35, 0.3)], 0.03, m=fin)
    tail.data.transform(k.Matrix.Rotation(math.radians(90), 4, "Y"))
    tail.data.transform(k.Matrix.Rotation(math.radians(90), 4, "Z"))
    tail.data.transform(k.move(0, -0.6, 0.15))
    p = [body, tail]
    for side in (-1, 1):
        p.append(k.box((0.22, 0.12, 0.02), (side * 0.2, 0.15, 0.08), (0, side * 20, 0), m=fin))
        p.append(k.sphere(0.03, (side * 0.11, 0.48, 0.2), m=eye, seg=6, rings=4))
    return p


ASSETS = [
    dict(name="slash_arc", build=slash_arc, budget=300, size=[7.2, 0.1, 4.0], priority=3, order=25,
         replaces="Slash crescent parts in src/night-client/CombatFx.client.luau 144-178",
         notes="Untextured white: set Color and Transparency in code; scale to the swing radius."),
    dict(name="demon_wing", build=demon_wing, budget=300, size=[0.2, 3.9, 2.8], priority=3, order=25.1,
         replaces="Trigger wing WedgeParts in src/night-client/CombatFx.client.luau 1218-1233",
         notes="Untextured white, Neon, Color TRIGGER_A; mirror for the left wing."),
    dict(name="koi", build=koi, budget=200, size=[0.6, 0.3, 1.6], priority=3, order=26,
         replaces="Koi parts in src/night/Arena.luau 478-490"),
]
