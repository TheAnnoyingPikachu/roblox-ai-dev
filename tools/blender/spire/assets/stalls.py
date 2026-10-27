"""Big hype items (SpireConfig.ITEMS, src/shared/SpireConfig.luau 215-233), today greybox boxes in
src/spire-client/PlazaView.client.luau 38-56: noodle stall, arcade kiosk, holo fountain, maglev
stop, mega billboard and the hologram idol (art bible 10 #5-7). Footprint W x D cells of 4 studs
minus 0.6, front +Y (Roblox -Z)."""

import math

import kit as k


def noodle_stall():
    body = k.metal("noodle_body", (44, 50, 72))
    counter = k.mat("noodle_counter", (90, 60, 50), var=0.15, scale=6, kind="wood")
    roof = k.mat("noodle_roof", (150, 30, 50), var=0.08, scale=6, rough=0.4)
    pot = k.metal("noodle_pot", k.CHROME, var=0.08)
    bowl = k.mat("noodle_bowl", (240, 240, 235), kind="flat")
    lantern = k.mat("noodle_lantern", (255, 90, 70), var=0.05, scale=4, emit=2.0)
    stool = k.metal("noodle_stool", k.GUNMETAL)
    glow_m = k.neon(k.MAGENTA)
    glow2 = k.neon(k.AMBER)
    p, g, g2 = [], [], []
    # Back cabinet, counter, posts and a sloped roof.
    p.append(k.rounded((7.2, 1.2, 4.6), (0, -1.0, 2.3), m=body, r=0.15))
    p.append(k.rounded((7.0, 1.3, 2.4), (0, 0.6, 1.2), m=body, r=0.12))
    p.append(k.rounded((7.3, 1.6, 0.22), (0, 0.65, 2.5), m=counter, r=0.06))
    for x in (-3.4, 3.4):
        p.append(k.box((0.25, 0.25, 4.9), (x, 1.2, 2.45), m=body))
    p.append(k.rounded((7.6, 3.4, 0.25), (0, 0.2, 5.15), (8, 0, 0), m=roof, r=0.08))
    p.append(k.box((7.7, 0.2, 0.6), (0, 1.9, 4.85), m=roof))
    g.append(k.box((7.7, 0.06, 0.12), (0, 2.02, 4.7), m=glow_m))
    # Steaming pot and bowls on the counter.
    p.append(k.lathe([(0.55, 2.6), (0.6, 2.7), (0.6, 3.3), (0.66, 3.35)], m=pot, n=14, scale=(1, 1, 1), loc=(-2.2, 0.4, 0)))
    p.append(k.cyl(0.55, 0.05, (-2.2, 0.4, 3.25), m=k.mat("broth", (200, 140, 60), kind="flat")))
    for i, x in enumerate((0.0, 1.2, 2.4)):
        p.append(k.lathe([(0.12, 2.61), (0.3, 2.7), (0.38, 2.92)], m=bowl, n=10, loc=(x, 1.0, 0)))
    # Hanging lanterns and a vertical sign.
    for x in (-1.8, 1.8):
        p.append(k.cyl(0.02, 0.5, (x, 1.9, 4.45), m=stool, n=4))
        p.append(k.sphere(0.4, (x, 1.9, 3.95), m=lantern, scale=(1, 1, 1.3), seg=10, rings=6))
    p.append(k.rounded((1.0, 0.3, 3.0), (3.0, -1.1, 6.6), m=body, r=0.1))
    g2.append(k.box((0.75, 0.06, 2.6), (3.0, -0.92, 6.6), m=glow2))
    # Two stools in front.
    for x in (-1.2, 1.2):
        p.append(k.cyl(0.08, 1.3, (x, 2.1, 0.65), m=stool, n=6))
        p.append(k.cyl(0.4, 0.15, (x, 2.1, 1.35), m=roof, n=12))
    return {"": p, "glow": g, "glow2": g2}


def arcade_kiosk():
    body = k.metal("arcade_body", (36, 40, 62))
    cab = [k.mat("arcade_cab0", (90, 30, 160), var=0.06, scale=6, rough=0.3), k.mat("arcade_cab1", (20, 90, 150), var=0.06, scale=6, rough=0.3)]
    screen = [k.mat("arcade_scr0", (255, 80, 160), var=0.4, scale=3, emit=2.0), k.mat("arcade_scr1", (60, 230, 255), var=0.4, scale=3, emit=2.0)]
    knob = k.mat("arcade_knob", (255, 60, 60), kind="flat")
    glow_m = k.neon(k.VIOLET)
    glow2 = k.neon(k.CYAN)
    p, g, g2 = [], [], []
    p.append(k.rounded((7.4, 7.4, 0.3), (0, 0, 0.15), m=body, r=0.1))
    # Awning on four posts.
    for x in (-3.4, 3.4):
        for y in (-3.4, 3.4):
            p.append(k.box((0.3, 0.3, 6.6), (x, y, 3.6), m=body))
    p.append(k.rounded((7.8, 7.8, 0.35), (0, 0, 7.0), m=body, r=0.1))
    p.append(k.rounded((7.0, 7.0, 0.6), (0, 0, 7.45), m=body, r=0.2))
    for a in range(4):
        r = math.radians(90 * a)
        g.append(k.box((7.82, 0.08, 0.14), (-3.92 * math.sin(r), 3.92 * math.cos(r), 6.95), (0, 0, 90 * a), m=glow_m))
    # Two cabinets back to back, facing front and back.
    for i, (x, face) in enumerate(((-1.6, 1), (1.6, 1))):
        y0 = 0.6
        p.append(k.poly([(-0.9, 0), (0.9, 0), (0.9, 5.2), (-0.9, 5.2)], 2.2, loc=(x, y0 - 1.1, 0), m=cab[i], bevel=0.06))
        p.append(k.box((1.6, 0.8, 0.3), (x, y0 + 0.4, 2.75), (-20, 0, 0), m=cab[i]))
        p.append(k.box((1.5, 0.1, 1.3), (x, y0 + 0.02, 3.8), (-12, 0, 0), m=screen[i]))
        p.append(k.box((1.6, 0.3, 0.5), (x, y0 - 0.1, 4.85), m=screen[i]))
        p.append(k.cyl(0.05, 0.3, (x - 0.4, y0 + 0.45, 3.05), m=body, n=6))
        p.append(k.sphere(0.11, (x - 0.4, y0 + 0.45, 3.22), m=knob, seg=8, rings=5))
        for b in range(3):
            p.append(k.cyl(0.08, 0.06, (x + 0.1 + b * 0.25, y0 + 0.5, 2.98), m=knob, n=8))
        g2.append(k.box((0.06, 0.06, 5.0), (x - 0.92, y0 + 1.1, 2.6), m=glow2))
        g2.append(k.box((0.06, 0.06, 5.0), (x + 0.92, y0 + 1.1, 2.6), m=glow2))
    # A third cabinet facing sideways at the back.
    p.append(k.poly([(-1.1, 0), (1.1, 0), (1.1, 5.2), (-1.1, 5.2)], 1.8, loc=(0, -2.2, 0), m=cab[0], bevel=0.06))
    return {"": p, "glow": g, "glow2": g2}


def holo_fountain():
    stone = k.mat("fount_stone", (44, 50, 70), var=0.12, scale=5, rough=0.35)
    water = k.mat("fount_water", (10, 60, 110), var=0.3, scale=2, emit=0.3, rough=0.1)
    glow_m = k.neon(k.CYAN)
    glow2 = k.neon(k.VIOLET)
    p, g, g2 = [], [], []
    p.append(k.lathe([(3.7, 0), (3.7, 0.9), (3.4, 0.95), (3.3, 0.5), (0, 0.5)], m=stone, n=24))
    p.append(k.cyl(3.3, 0.05, (0, 0, 0.75), m=water, n=24))
    p.append(k.lathe([(1.0, 0.5), (0.7, 1.4), (0.55, 2.8), (1.4, 3.1), (1.45, 3.35), (0.3, 3.3), (0, 3.3)], m=stone, n=16))
    p.append(k.cyl(1.25, 0.05, (0, 0, 3.25), m=water, n=16))
    g2.append(k.lathe([(3.42, 0.86), (3.46, 0.9)], m=glow2, n=24))
    # Arcing holographic jets: thin neon ribbons from the top bowl down to the pool.
    for i in range(8):
        a = 2 * math.pi * i / 8
        c, s = math.cos(a), math.sin(a)
        pts = []
        for t in [j / 8 for j in range(9)]:
            r = 0.4 + 2.4 * t
            pts.append((c * r, s * r, 3.6 + 2.2 * t - 4.6 * t * t))
        g.append(k.tube(pts, [0.09] * 8 + [0.02], m=glow_m, n=5))
    g.append(k.tube([(0, 0, 3.3), (0, 0, 4.8), (0, 0, 5.7)], [0.14, 0.12, 0.0], m=glow_m, n=8))
    return {"": p, "glow": g, "glow2": g2}


def maglev_stop():
    body = k.metal("stop_body", (40, 46, 68))
    floor_m = k.mat("stop_floor", (30, 34, 48), var=0.15, scale=8, rough=0.3)
    glass = k.mat("stop_glass", (50, 110, 160), var=0.1, scale=4, emit=0.3, rough=0.05)
    seat = k.mat("stop_seat", (150, 40, 80), kind="flat")
    glow_m = k.neon(k.CYAN)
    glow2 = k.neon(k.AMBER)
    p, g, g2 = [], [], []
    p.append(k.rounded((11.4, 7.0, 0.4), (0, 0, 0.2), m=floor_m, r=0.12))
    g2.append(k.box((11.0, 0.3, 0.06), (0, 3.2, 0.42), m=glow2))  # platform edge warning strip
    # Shelter: back glass wall, canopy with a curved front, four posts.
    p.append(k.box((10.6, 0.15, 5.0), (0, -3.0, 2.9), m=glass))
    for x in (-5.2, 0, 5.2):
        p.append(k.box((0.3, 0.3, 6.6), (x, -3.1, 3.5), m=body))
    for x in (-5.2, 5.2):
        p.append(k.box((0.3, 0.3, 6.2), (x, 1.2, 3.3), m=body))

    def canopy(u, v):
        x = -5.7 + 11.4 * u
        y = -3.4 + 5.6 * v
        return (x, y, 6.8 + 0.5 * math.sin(math.pi * v) - 0.3 * v)

    p.append(k.surface(6, 8, canopy, m=body, thickness=0.25))
    g.append(k.box((11.4, 0.08, 0.12), (0, 2.25, 6.42), m=glow_m))
    # Bench, route board and a ticket pylon.
    p.append(k.rounded((6.0, 1.1, 0.25), (0, -2.2, 1.4), m=seat, r=0.08))
    for x in (-2.6, 2.6):
        p.append(k.box((0.3, 0.9, 1.2), (x, -2.3, 0.8), m=body))
    p.append(k.rounded((4.0, 0.25, 1.4), (0, 1.0, 5.4), m=body, r=0.08))
    g.append(k.box((3.6, 0.06, 0.18), (0, 1.15, 5.65), m=glow_m))
    g2.append(k.box((3.6, 0.06, 0.12), (0, 1.15, 5.2), m=glow2))
    p.append(k.rounded((0.9, 0.7, 3.2), (4.3, 0.2, 2.0), m=body, r=0.12))
    g.append(k.box((0.6, 0.06, 0.9), (4.3, 0.57, 2.8), m=glow_m))
    # Maglev rail stub in front.
    p.append(k.box((11.4, 0.8, 0.4), (0, 3.0, 0.2), m=body))
    return {"": p, "glow": g, "glow2": g2}


def mega_billboard():
    body = k.metal("bb_body", (36, 40, 60))
    screen = k.mat("bb_screen", (255, 42, 109), kind="grad", rgb2=(123, 47, 255), emit=2.5)
    glow_m = k.neon(k.MAGENTA)
    p, g = [], []
    p.append(k.rounded((3.0, 2.0, 0.6), (0, 0, 0.3), m=body, r=0.15))
    for x in (-0.7, 0.7):
        p.append(k.box((0.45, 0.45, 8.0), (x, 0, 4.4), m=body))
    p.append(k.box((1.8, 0.3, 0.3), (0, 0, 5.0), m=body))
    p.append(k.rounded((7.4, 1.0, 4.6), (0, 0, 10.4), m=body, r=0.2))
    p.append(k.box((6.8, 0.1, 4.0), (0, 0.5, 10.4), m=screen))
    p.append(k.box((6.8, 0.1, 4.0), (0, -0.5, 10.4), m=screen))
    for z in (8.05, 12.75):
        g.append(k.box((7.5, 1.1, 0.1), (0, 0, z), m=glow_m))
    for x in (-3.72, 3.72):
        g.append(k.box((0.1, 1.1, 4.6), (x, 0, 10.4), m=glow_m))
    # Rooftop spotlights.
    for x in (-2.5, 2.5):
        p.append(k.cyl(0.25, 0.6, (x, 0.8, 13.0), (60, 0, 0), m=body, n=8))
    return {"": p, "glow": g}


def hologram_idol():
    stage = k.metal("idol_stage", (36, 40, 62))
    floor_m = k.mat("idol_floor", (20, 24, 40), var=0.3, scale=4, rough=0.15)
    glow_m = k.neon(k.MAGENTA)
    glow2 = k.neon(k.CYAN)
    p, g, g2 = [], [], []
    p.append(k.lathe([(5.6, 0), (5.7, 0.4), (5.4, 1.0), (0, 1.0)], m=stage, n=28))
    p.append(k.cyl(5.0, 0.05, (0, 0, 1.0), m=floor_m, n=28))
    g2.append(k.lathe([(5.42, 0.95), (5.5, 1.02)], m=glow2, n=28))
    g2.append(k.lathe([(2.0, 1.02), (2.1, 1.06)], m=glow2, n=24))
    # Projector ring of four emitters.
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.append(k.rounded((0.8, 0.8, 0.6), (4.6 * math.cos(a), 4.6 * math.sin(a), 1.3), m=stage, r=0.15))
        g2.append(k.cyl(0.25, 0.08, (4.6 * math.cos(a), 4.6 * math.sin(a), 1.62), m=glow2, n=10))
    # Abstract singer silhouette made of light ribbons (not a real person): three helical ribbons
    # trace a flared dress, waist, shoulders and head; one arm raises a mic, hair streams back.
    def radius(z):
        t = (z - 1.2) / 8.4
        if t < 0.55:  # skirt: wide at the hem, narrowing to the waist
            return 0.55 + 1.5 * (1 - t / 0.55) ** 1.6
        if t < 0.85:  # torso up to the shoulders
            return 0.55 + 0.35 * math.sin(math.pi * (t - 0.55) / 0.3 * 0.5)
        return 0.9 - 2.4 * (t - 0.85)  # shoulders closing to the neck

    for phase in range(3):
        pts = []
        for i in range(60):
            t = i / 59
            z = 1.2 + 8.4 * t
            a = t * 5 * math.pi + phase * 2 * math.pi / 3
            r = radius(z)
            pts.append((r * math.cos(a), r * 0.8 * math.sin(a), z))
        g.append(k.tube(pts, 0.07, m=glow_m, n=4, cap=False))
    for z in (1.25, 5.8):
        g.append(k.ring(radius(z), z, 0.08, glow_m, n=28, sides=4))
        g[-1].data.transform(k.Matrix.Diagonal((1, 0.8, 1, 1)))
    g.append(k.sphere(0.6, (0, 0, 10.3), m=glow_m, scale=(0.9, 0.9, 1.1), seg=12, rings=8))
    g.append(k.cyl(0.18, 0.6, (0, 0, 9.6), m=glow_m, n=6))
    # Raised arm with the mic, the other arm out to the side.
    g.append(k.tube([(0.75, 0, 8.9), (1.4, 0.2, 9.6), (1.25, 0.5, 10.6), (0.7, 0.6, 10.9)], [0.13, 0.12, 0.1, 0.09], m=glow_m, n=6))
    g.append(k.sphere(0.2, (0.62, 0.62, 10.95), m=glow2, seg=8, rings=5))
    g.append(k.tube([(-0.75, 0, 8.9), (-1.5, 0.1, 8.3), (-2.2, 0.3, 8.0), (-2.6, 0.4, 8.2)], [0.13, 0.11, 0.09, 0.04], m=glow_m, n=6))
    # Hair streaming back in cyan ribbons.
    for i in range(5):
        off = (i - 2) * 0.22
        g.append(k.tube([(off, -0.3, 10.7), (off * 1.4, -1.0, 10.5), (off * 1.8 - 0.3, -1.7, 9.7), (off * 2.2 - 0.6, -2.1, 8.6)],
                        [0.09, 0.08, 0.06, 0.01], m=glow2, n=4))
    # Rising light rings around the figure.
    for z, r in ((2.6, 2.6), (4.6, 2.2), (6.8, 1.8)):
        g2.append(k.ring(r, z, 0.04, glow2, n=32, sides=3))
    return {"": p, "glow": g, "glow2": g2}


ASSETS = [
    dict(name="noodle_stall", build=noodle_stall, budget=3000, size=[7.7, 8.1, 3.4], priority=1, order=30,
         replaces="Plaza item noodle: greybox in src/spire-client/PlazaView.client.luau 38-56 (art bible 10 #5)",
         glow={"glow": k.MAGENTA, "glow2": k.AMBER}),
    dict(name="arcade_kiosk", build=arcade_kiosk, budget=3000, size=[7.8, 7.8, 7.8], priority=1, order=31,
         replaces="Plaza item arcade: greybox in PlazaView.client.luau 38-56 (art bible 10 #6)",
         glow={"glow": k.VIOLET, "glow2": k.CYAN}),
    dict(name="holo_fountain", build=holo_fountain, budget=3000, size=[7.4, 5.7, 7.4], priority=1, order=32,
         replaces="Plaza item fountain: greybox in PlazaView.client.luau 38-56", glow={"glow": k.CYAN, "glow2": k.VIOLET}),
    dict(name="maglev_stop", build=maglev_stop, budget=3000, size=[11.4, 7.4, 7.0], priority=1, order=33,
         replaces="Plaza item maglev: greybox in PlazaView.client.luau 38-56", glow={"glow": k.CYAN, "glow2": k.AMBER}),
    dict(name="mega_billboard", build=mega_billboard, budget=1500, size=[7.5, 13.3, 1.6], priority=1, order=34,
         replaces="Plaza item billboard: greybox in PlazaView.client.luau 38-56", glow={"glow": k.MAGENTA},
         notes="Screens are baked magenta-to-violet; code may add a SurfaceGui ad on a part in front."),
    dict(name="hologram_idol", build=hologram_idol, budget=6000, size=[11.4, 11.2, 11.4], priority=1, order=35,
         replaces="Plaza item idol: greybox in PlazaView.client.luau 38-56 (art bible 10 #7, abstract, not a real person)",
         glow={"glow": k.MAGENTA, "glow2": k.CYAN}, notes="Hero item. Figure is all glow mesh; code may spin it with Kit.spin."),
]
