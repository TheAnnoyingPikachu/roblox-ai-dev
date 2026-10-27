"""Vehicles for the hover traffic, maglev and blimp (art bible 7 and 10 #2, #3, #8, #9). No code
spawns them yet (Traffic.client.luau is planned in SPIRE-007), so they are built and registered
but not wired. Length runs along +Y (the nose is the front, Roblox -Z)."""

import math

import kit as k


def loft(length, half_w, half_h, centre_z, m, nu=16, nv=16, power=2.6, y0=None, name="hull"):
    """Closed streamlined body: superellipse sections along y from the tail (u = 0) to the nose
    (u = 1); half_w, half_h and centre_z are functions of u. Ends of radius 0 close to points."""
    y0 = -length / 2 if y0 is None else y0

    def fn(u, v):
        a = 2 * math.pi * v
        c, s = math.cos(a), math.sin(a)
        x = half_w(u) * math.copysign(abs(c) ** (2 / power), c)
        z = half_h(u) * math.copysign(abs(s) ** (2 / power), s)
        return (x, y0 + length * u, centre_z(u) + z)

    return k.surface(nu, nv, fn, m=m, name=name)


def _ease(u, nose=0.25, tail=0.15):
    """1 in the middle, rounding to 0 at both ends."""
    if u < tail:
        return math.sqrt(max(0.0, 1 - ((tail - u) / tail) ** 2))
    if u > 1 - nose:
        return math.sqrt(max(0.0, 1 - ((u - (1 - nose)) / nose) ** 2))
    return 1.0


def hover_car():
    paint = k.mat("car_paint", (60, 30, 120), var=0.06, scale=4, rough=0.25)
    dark = k.metal("car_dark", k.ASPHALT)
    glass = k.mat("car_glass", (30, 60, 100), var=0.15, scale=3, emit=0.3, rough=0.05)
    head = k.mat("car_head", k.WHITE, kind="flat", emit=4)
    glow_m = k.neon(k.CYAN)
    tail_m = k.neon(k.MAGENTA)
    p, g, g2 = [], [], []
    L = 12.0
    p.append(loft(L, lambda u: 2.4 * _ease(u, 0.3, 0.12) + 0.05, lambda u: 0.8 * _ease(u, 0.35, 0.1) + 0.05,
                  lambda u: 1.4 + 0.15 * u, paint, nu=20, nv=16))
    # Canopy bubble set back from the nose.
    p.append(loft(5.0, lambda u: 1.6 * _ease(u, 0.45, 0.35) + 0.02, lambda u: 0.75 * _ease(u, 0.45, 0.35) + 0.02,
                  lambda u: 2.0, glass, nu=12, nv=12, y0=-2.8))
    # Side intakes, hover pods and lights.
    for s in (-1, 1):
        p.append(loft(5.0, lambda u: 0.55 * _ease(u, 0.3, 0.3) + 0.02, lambda u: 0.45 * _ease(u, 0.3, 0.3) + 0.02,
                      lambda u: 0.95, dark, nu=10, nv=10, y0=-4.8))
        p[-1].data.transform(k.move(s * 2.1, 0, 0))
        g.append(k.cyl(0.42, 0.06, (s * 2.1, -2.3, 0.48), m=glow_m, n=12))
        p.append(k.box((0.7, 0.08, 0.18), (s * 1.3, 5.75, 1.45), (0, 0, s * -12), m=head))
    for s in (-1, 1):
        g.append(k.cyl(0.42, 0.06, (s * 1.8, 3.2, 0.95), m=glow_m, n=12))
    g2.append(k.box((3.8, 0.08, 0.14), (0, -5.95, 1.55), m=tail_m))
    p.append(k.box((4.4, 0.6, 0.12), (0, -5.6, 2.25), (-10, 0, 0), m=dark))  # spoiler
    return {"": p, "glow": g, "glow2": g2}


def hover_taxi():
    paint = k.mat("taxi_paint", (255, 184, 0), var=0.05, scale=4, rough=0.3)
    check = k.mat("taxi_check", (20, 20, 26), kind="stripes", rgb2=(240, 240, 240), scale=6)
    dark = k.metal("taxi_dark", k.ASPHALT)
    glass = k.mat("taxi_glass", (30, 60, 100), var=0.15, scale=3, emit=0.3, rough=0.05)
    head = k.mat("taxi_head", k.WHITE, kind="flat", emit=4)
    glow_m = k.neon(k.CYAN)
    sign_m = k.neon(k.AMBER)
    p, g, g2 = [], [], []
    L = 13.0
    p.append(loft(L, lambda u: 2.7 * _ease(u, 0.18, 0.1) + 0.05, lambda u: 1.4 * _ease(u, 0.2, 0.08) + 0.05,
                  lambda u: 1.9, paint, nu=20, nv=16, power=3.5))
    p.append(loft(7.0, lambda u: 2.3 * _ease(u, 0.3, 0.2) + 0.02, lambda u: 1.0 * _ease(u, 0.3, 0.2) + 0.02,
                  lambda u: 3.1, glass, nu=12, nv=12, y0=-4.0, power=3.5))
    p.append(k.box((5.5, 9.0, 0.35), (0, -0.3, 1.9), m=check))
    for s in (-1, 1):
        for y in (-3.8, 3.6):
            p.append(k.cyl(0.8, 0.5, (s * 2.6, y, 0.75), (0, 90, 0), m=dark, n=14))
            g.append(k.cyl(0.65, 0.52, (s * 2.6, y, 0.75), (0, 90, 0), m=glow_m, n=14))
        p.append(k.box((0.9, 0.08, 0.3), (s * 1.6, 6.45, 2.0), m=head))
    # Roof light sign.
    p.append(k.rounded((2.0, 0.9, 0.2), (0, -0.6, 4.1), m=dark, r=0.06))
    g2.append(k.rounded((1.8, 0.7, 0.6), (0, -0.6, 4.5), m=sign_m, r=0.12))
    g2.append(k.box((4.6, 0.08, 0.2), (0, -6.45, 2.2), m=k.neon(k.MAGENTA, "taxi_tail")))
    return {"": p, "glow": g, "glow2": g2}


def maglev_car():
    paint = k.mat("train_paint", (215, 225, 240), kind="flat", rough=0.25)
    stripe = k.mat("train_stripe", k.VIOLET, kind="flat", emit=0.5)
    window = k.mat("train_window", (140, 220, 255), kind="flat", emit=3.0)
    dark = k.metal("train_dark", k.ASPHALT)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    L = 20.0
    p.append(loft(L, lambda u: 2.0 * _ease(u, 0.32, 0.03) + 0.05, lambda u: 1.7 * _ease(u, 0.35, 0.03) + 0.05,
                  lambda u: 2.2 - 0.6 * max(0.0, u - 0.68) / 0.32, paint, nu=24, nv=16, power=3.0))
    # Window band, livery stripe, bogie skirt and an underside light line.
    for s in (-1, 1):
        p.append(k.box((0.16, 12.0, 1.0), (s * 1.96, -1.5, 2.75), m=window))
        p.append(k.box((0.08, 13.5, 0.25), (s * 2.0, -0.5, 1.75), m=stripe))
    p.append(k.box((0.08, 1.2, 0.6), (0, 8.6, 2.6), (0, 0, 90), m=window))
    p.append(k.box((3.4, 18.0, 0.6), (0, -0.6, 0.45), m=dark))
    g.append(k.box((3.0, 17.0, 0.08), (0, -0.6, 0.12), m=glow_m))
    return {"": p, "glow": g}


def blimp():
    skin = k.mat("blimp_skin", (190, 198, 215), var=0.04, scale=0.5, rough=0.4)
    dark = k.metal("blimp_dark", k.STEEL)
    band = k.mat("blimp_band", k.MAGENTA, kind="grad", rgb2=k.CYAN, emit=2.5)
    glow_m = k.neon(k.MAGENTA)
    nav = k.neon((255, 40, 60))
    p, g, g2 = [], [], []
    L, R = 80.0, 11.0
    prof = []
    for i in range(25):
        t = i / 24
        r = R * math.sqrt(max(0.0, math.sin(math.pi * t))) * (1 - 0.25 * (1 - t))
        prof.append((max(r, 0.0) if 0 < i < 24 else 0.0, -L / 2 + L * t))
    env = k.lathe(prof, m=skin, n=28, rot=(-90, 0, 0), loc=(0, 0, R + 4))
    p.append(env)
    # Screen band around the middle (ad band; code can put a SurfaceGui on a part over it).
    p.append(k.cyl(R * 0.98 + 0.12, 16.0, (0, -2.0, R + 4), (90, 0, 0), m=band, n=28))
    # Tail fins and a gondola.
    for a in (0, 90, 180, 270):
        # Profile (length from the tail, radial out) in the y-z plane, then turned about the axis.
        fin = k.poly([(0, 1.5), (14, 3.5), (6, 11), (0, 12)], 0.6, rot=(0, 0, 90), m=dark)
        fin.data.transform(k.move(0, -L / 2 + 1, 0))
        fin.data.transform(k.Matrix.Rotation(math.radians(a), 4, "Y"))
        fin.data.transform(k.move(0, 0, R + 4))
        p.append(fin)
    p.append(k.rounded((4.0, 14.0, 3.0), (0, 4.0, 2.0), m=dark, r=0.8))
    p.append(k.box((3.6, 10.0, 1.0), (0, 4.5, 2.4), m=k.mat("gondola_window", (140, 220, 255), kind="flat", emit=2)))
    g.append(k.box((4.1, 13.0, 0.15), (0, 4.0, 0.6), m=glow_m))
    for s in (-1, 1):
        g2.append(k.sphere(0.6, (s * R * 0.8, 6.0, R + 4), m=nav, seg=8, rings=5))
    g2.append(k.sphere(0.6, (0, -L / 2 + 0.5, R + 4 + 9.5), m=nav, seg=8, rings=5))
    return {"": p, "glow": g, "glow2": g2}


NOT_WIRED = "Not wired: no traffic code yet (Traffic.client.luau, SPIRE-007)."
ASSETS = [
    dict(name="hover_car", build=hover_car, budget=4000, size=[5.0, 3.0, 12.0], priority=3, order=51,
         replaces="Hover traffic car A (art bible 7, 10 #2)", glow={"glow": k.CYAN, "glow2": k.MAGENTA}, notes=NOT_WIRED),
    dict(name="hover_taxi", build=hover_taxi, budget=4000, size=[5.8, 5.0, 13.0], priority=3, order=52,
         replaces="Hover traffic taxi B (art bible 7, 10 #3)", glow={"glow": k.CYAN, "glow2": k.AMBER}, notes=NOT_WIRED),
    dict(name="maglev_car", build=maglev_car, budget=3000, size=[4.1, 4.0, 20.0], priority=3, order=53,
         replaces="Maglev train on the viaduct (art bible 8, 10 #8), three cars per train", glow={"glow": k.CYAN}, notes=NOT_WIRED),
    dict(name="blimp", build=blimp, budget=6000, size=[22, 26, 80], priority=3, order=54,
         replaces="Advertising blimp at 380 studs (art bible 7, 10 #9)", glow={"glow": k.MAGENTA, "glow2": (255, 40, 60)}, notes=NOT_WIRED),
]
