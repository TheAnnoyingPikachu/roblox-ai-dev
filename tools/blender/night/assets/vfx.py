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
    """Bat/demon wing in the y/z plane (thin along x): arm bones from the shoulder at the origin,
    four finger bones fanning back from the wrist, a scalloped billowing membrane between them."""
    white = k.mat("white", (255, 255, 255), kind="flat")
    V = k.Vector

    def P(h, v):  # 2D wing coords (h = back, v = up) to Blender (x, y, z)
        return V((0, -h, v))

    shoulder, elbow, wrist = P(0, 0), P(0.75, 1.35), P(0.45, 2.75)
    tips = [P(1.5, 3.45), P(2.6, 2.75), P(3.0, 1.45), P(2.55, 0.15)]
    body = P(0.55, -0.7)

    def panel(p0, p1, q0, q1, scallop=0.22, billow=0.12):
        # Ruled surface between edges p0-p1 and q0-q1; the far edge bows inward (scallop) and
        # the middle bulges sideways (billow) so the membrane reads as stretched skin.
        def fn(u, v):
            a = p0.lerp(q0, u)
            b = p1.lerp(q1, u)
            vv = v * (1 - scallop * math.sin(math.pi * u))
            pt = a.lerp(b, vv)
            pt.x += billow * math.sin(math.pi * u) * math.sin(math.pi * min(1.0, v * 1.2))
            return tuple(pt)

        return k.surface(6, 6, fn, m=white, thickness=0.04, name="membrane")

    p = [panel(shoulder, elbow, shoulder, wrist, scallop=0.0, billow=0.04)]
    edges = [wrist] + tips
    for a_tip, b_tip in zip(tips, tips[1:]):
        p.append(panel(wrist, a_tip, wrist, b_tip))
    p.append(panel(wrist, tips[-1], shoulder, body, scallop=0.18))

    def bone(pts, r0, r1):
        p.append(k.tube([tuple(q) for q in pts], [r0 + (r1 - r0) * i / (len(pts) - 1) for i in range(len(pts))], m=white, n=6))

    bone([shoulder, elbow], 0.12, 0.09)
    bone([elbow, wrist], 0.09, 0.07)
    for q in (shoulder, elbow, wrist):
        p.append(k.sphere(0.12, tuple(q), m=white, seg=8, rings=5))
    for tip in tips:
        mid = wrist.lerp(tip, 0.5) + V((0, 0, 0.08))
        p.append(k.tube([tuple(wrist), tuple(mid), tuple(tip)], [0.06, 0.045, 0.0], m=white, n=6))
        p.append(k.sphere(0.06, tuple(mid), m=white, seg=6, rings=4))
    # Thumb claw hooking forward off the wrist.
    p.append(k.tube([tuple(wrist), tuple(wrist + V((0, 0.25, 0.3))), tuple(wrist + V((0, 0.42, 0.25)))], [0.06, 0.04, 0.0], m=white, n=6))
    for ob in p:  # fit the planned 3.5 stud height
        ob.data.transform(k.Matrix.Diagonal((0.82, 0.82, 0.82, 1)))
    return p


def koi():
    body_m = k.mat("koi", (255, 120, 40), kind="patches", rgb2=(250, 245, 240), scale=3.5)
    fin = k.mat("fin", (255, 170, 120), var=0.1, scale=6)
    eye = k.mat("eye", (10, 8, 10), kind="flat")
    # Body along +Y (head) to -Y (tail): blunt head, widest a third back, thin tail peduncle.
    profile = [(0, -0.6), (0.035, -0.58), (0.05, -0.5), (0.08, -0.36), (0.13, -0.18), (0.18, 0.02), (0.205, 0.2),
               (0.2, 0.34), (0.17, 0.47), (0.11, 0.58), (0.04, 0.64), (0, 0.65)]
    body = k.lathe(profile, m=body_m, n=12, rot=(-90, 0, 0))
    body.data.transform(k.Matrix.Diagonal((0.72, 1, 0.85, 1)))
    body.data.transform(k.move(0, 0, 0.2))

    def fin_y(points, x=0.0, depth=0.025):
        # Flat fin in the y/z plane from (y, z) points.
        return k.poly(list(points), depth, loc=(x, 0, 0), rot=(0, 0, 90), m=fin)

    # Forked caudal fin, dorsal fin along the back.
    tail = [(-0.56, 0.23), (-0.7, 0.33), (-0.86, 0.41), (-0.78, 0.27), (-0.74, 0.2), (-0.78, 0.13), (-0.86, -0.01), (-0.7, 0.07), (-0.56, 0.17)]
    dorsal = [(0.22, 0.36), (0.12, 0.43), (-0.05, 0.44), (-0.25, 0.36), (-0.32, 0.3), (-0.05, 0.33)]
    p = [body, fin_y(tail), fin_y(dorsal)]
    for side in (-1, 1):
        # Pectoral and pelvic fins: small rounded paddles angled down and back.
        for y, x0, z, size, ang in ((0.3, 0.1, 0.07, 0.17, 35), (-0.12, 0.06, 0.1, 0.12, 30)):
            fan = [(0, 0), (size * 0.5, -size * 0.25), (size, -size * 0.55), (size * 0.75, -size), (size * 0.2, -size * 0.7)]
            pf = k.poly([(x, zz) for x, zz in fan], 0.02, m=fin)
            pf.data.transform(k.Matrix.Rotation(math.radians(-90), 4, "X"))  # lay flat (x/y), pointing back
            if side < 0:
                pf.data.transform(k.Matrix.Diagonal((-1, 1, 1, 1)))
            pf.data.transform(k.Matrix.Rotation(math.radians(side * ang), 4, "Y"))  # droop down
            pf.data.transform(k.move(side * x0, y, z))
            p.append(pf)
        p.append(k.sphere(0.028, (side * 0.1, 0.47, 0.26), m=eye, seg=6, rings=4))
        # Barbels at the mouth.
        p.append(k.tube([(side * 0.03, 0.63, 0.16), (side * 0.08, 0.66, 0.1), (side * 0.1, 0.62, 0.06)], [0.012, 0.008, 0.0], m=fin, n=4))
    return p


ASSETS = [
    dict(name="slash_arc", build=slash_arc, budget=300, size=[7.2, 0.1, 4.0], priority=3, order=25,
         replaces="Slash crescent parts in src/night-client/CombatFx.client.luau 144-178",
         notes="Untextured white: set Color and Transparency in code; scale to the swing radius."),
    dict(name="demon_wing", build=demon_wing, budget=900, size=[0.3, 3.5, 3], priority=3, order=25.1,
         replaces="Trigger wing WedgeParts in src/night-client/CombatFx.client.luau 1218-1233",
         notes="Untextured white, Neon, Color TRIGGER_A; mirror for the left wing."),
    dict(name="koi", build=koi, budget=500, size=[0.6, 0.3, 1.6], priority=3, order=26,
         replaces="Koi parts in src/night/Arena.luau 478-490"),
]
