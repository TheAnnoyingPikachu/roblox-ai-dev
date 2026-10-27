"""Plaza decor and small hype items (SpireConfig.ITEMS, src/shared/SpireConfig.luau 215-233),
today greybox boxes with a neon cap in src/spire-client/PlazaView.client.luau 38-56. Footprints
are PLAZA cells of 4 studs (PlazaRules.footprint), so a 1x1 item stays inside 3.4 x 3.4.
Front faces +Y (Roblox -Z). Neon pieces are the `glow` mesh (Neon in game, colour from `glow`)."""

import math

import kit as k


def neon_bench():
    body = k.metal("bench_steel", k.GUNMETAL)
    seat_m = k.mat("bench_seat", (40, 46, 66), var=0.1, scale=10, rough=0.3)
    glow_m = k.neon(k.MAGENTA)
    p, g = [], []
    # Two C-shaped side frames, seat, backrest slats.
    for x in (-1.45, 1.45):
        p.append(k.rounded((0.22, 1.4, 0.18), (x, 0.0, 0.09), m=body, r=0.06))
        p.append(k.rounded((0.22, 0.2, 1.0), (x, 0.55, 0.55), m=body, r=0.06))
        p.append(k.rounded((0.22, 0.2, 1.9), (x, -0.55, 0.95), (-8, 0, 0), m=body, r=0.06))
        p.append(k.rounded((0.22, 1.3, 0.16), (x, 0.0, 1.0), m=body, r=0.06))
    p.append(k.rounded((3.3, 1.25, 0.16), (0, 0.05, 1.12), m=seat_m, r=0.06))
    for z in (1.55, 1.95):
        p.append(k.rounded((3.3, 0.12, 0.3), (0, -0.62 - (z - 1.5) * 0.14, z), (-8, 0, 0), m=seat_m, r=0.05))
    # Neon underglow along the seat front and the top of the backrest.
    g.append(k.box((3.0, 0.08, 0.08), (0, 0.66, 1.02), m=glow_m))
    g.append(k.box((3.0, 0.08, 0.08), (0, -0.72, 2.16), (-8, 0, 0), m=glow_m))
    return {"": p, "glow": g}


def holo_palm():
    body = k.metal("palm_steel", k.STEEL)
    ring_m = k.metal("palm_ring", k.GUNMETAL)
    leaf_m = k.neon(k.CYAN)
    pot = k.mat("palm_pot", (34, 40, 58), var=0.12, scale=5, rough=0.4)
    p, g = [], []
    p.append(k.lathe([(1.5, 0), (1.55, 0.2), (1.4, 0.9), (1.2, 1.0), (0, 1.0)], m=pot, n=8, rot=(0, 0, 22.5)))
    # Segmented trunk leaning slightly, like a palm.
    pts = [(0, 0, 0.9), (0.1, 0, 3.0), (0.35, 0, 5.2), (0.7, 0, 7.4)]
    p.append(k.tube(pts, [0.32, 0.28, 0.24, 0.2], m=body, n=8))
    for i in range(9):
        t = (i + 0.5) / 9
        z = 1.1 + t * 6.2
        x = 0.7 * t**1.6
        p.append(k.ring(0.32 - 0.12 * t, z, 0.06, ring_m, n=10, sides=4, centre=(x, 0)))
    top = (0.7, 0, 7.45)
    p.append(k.sphere(0.32, top, m=ring_m, seg=10, rings=6))
    # Fronds: thin drooping blades of light.
    for i in range(7):
        a = 2 * math.pi * i / 7 + 0.3
        c, s = math.cos(a), math.sin(a)

        def frond(u, v, c=c, s=s):
            r = 0.2 + 2.6 * u
            w = 0.42 * math.sin(math.pi * min(1.0, u * 1.15 + 0.05)) * (v - 0.5) * 2
            z = top[2] + 0.5 * math.sin(math.pi * u * 0.8) - 1.6 * u * u
            return (top[0] + c * r - s * w, top[1] + s * r + c * w, z + abs(w) * 0.25)

        g.append(k.surface(8, 2, frond, m=leaf_m, thickness=0.05))
    return {"": p, "glow": g}


def street_lamp():
    body = k.metal("lamp_steel", k.STEEL)
    dark = k.metal("lamp_dark", k.ASPHALT, var=0.1)
    glow_m = k.neon(k.ICE)
    p, g = [], []
    p.append(k.lathe([(0.75, 0), (0.75, 0.25), (0.45, 0.5), (0.32, 0.9)], m=dark, n=10))
    p.append(k.cyl(0.3, 11.2, (0, 0, 6.4), m=body, n=12, r2=0.22))
    p.append(k.cyl(0.38, 0.3, (0, 0, 4.4), m=dark, n=12))
    p.append(k.box((0.12, 0.12, 2.4), (0, 0, 3.0), m=k.neon(k.ICE, "lamp_pole_glow")))
    # Swan-neck arm forward to the head.
    p.append(k.tube([(0, 0, 11.6), (0, 0.6, 12.1), (0, 1.8, 12.15), (0, 2.6, 11.95)], 0.16, m=body, n=8))
    p.append(k.rounded((1.6, 2.6, 0.5), (0, 2.9, 11.7), (-6, 0, 0), m=dark, r=0.18))
    g.append(k.box((1.3, 2.2, 0.08), (0, 2.9, 11.43), (-6, 0, 0), m=glow_m))
    g.append(k.box((0.1, 0.1, 2.4), (0.25, 0, 3.0), m=glow_m))
    return {"": p, "glow": g}


def bollard():
    body = k.metal("bollard_steel", k.GUNMETAL)
    glow_m = k.neon(k.AMBER)
    p = [k.lathe([(0.42, 0), (0.42, 1.45), (0.36, 1.7), (0.18, 1.82), (0, 1.84)], m=body, n=14)]
    g = [k.cyl(0.44, 0.14, (0, 0, 1.2), m=glow_m, n=14), k.cyl(0.44, 0.06, (0, 0, 0.3), m=glow_m, n=14)]
    return {"": p, "glow": g}


def planter():
    box_m = k.mat("planter_box", (36, 42, 60), var=0.12, scale=6, rough=0.4)
    soil = k.mat("planter_soil", (25, 20, 22), var=0.2, scale=8)
    leaf = k.mat("planter_leaf", k.LEAF, var=0.25, scale=3)
    leaf2 = k.mat("planter_leaf2", (20, 80, 70), var=0.25, scale=3)
    glow_m = k.neon(k.LIME)
    p, g = [], []
    p.append(k.rounded((3.3, 3.3, 1.3), (0, 0, 0.65), m=box_m, r=0.18))
    p.append(k.box((2.9, 2.9, 0.1), (0, 0, 1.28), m=soil))
    for i, (x, y, r) in enumerate([(-0.6, -0.5, 0.9), (0.7, 0.4, 0.85), (0.5, -0.8, 0.6), (-0.7, 0.8, 0.65), (0, 0, 1.0)]):
        bush = k.ico(r, (x, y, 1.4 + r * 0.6), m=leaf if i % 2 else leaf2, subdiv=2, scale=(1, 1, 0.85))
        k.displace(bush, 0.25, 0.6, seed=i + 1)
        p.append(bush)
    # Neon kerb strip around the base.
    for a in range(4):
        r = math.radians(90 * a)
        g.append(k.box((3.36, 0.06, 0.08), (-1.66 * math.sin(r), 1.66 * math.cos(r), 0.22), (0, 0, 90 * a), m=glow_m))
    return {"": p, "glow": g}


def neon_arrow():
    body = k.metal("arrow_steel", k.GUNMETAL)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    p.append(k.rounded((2.8, 0.9, 0.3), (0, 0, 0.15), m=body, r=0.1))
    for x in (-1.1, 1.1):
        p.append(k.box((0.2, 0.2, 1.4), (x, 0, 0.9), m=body))
    # Frame and a big chevron pointing forward-up (towards the tower).
    p.append(k.rounded((3.0, 0.35, 1.9), (0, 0, 2.5), m=body, r=0.12))
    chev = [(-0.95, -0.6), (-0.2, 0.15), (-0.95, 0.9), (-0.45, 0.9), (0.3, 0.15), (-0.45, -0.6)]
    for dx in (0, 0.85):
        g.append(k.poly([(x + dx - 0.1, z) for x, z in chev], 0.5, loc=(0, 0, 2.35), m=glow_m))
    return {"": p, "glow": g}


def trash_bot():
    shell = k.mat("bot_shell", (180, 195, 220), kind="flat", rough=0.3)
    dark = k.metal("bot_dark", k.STEEL)
    bristle = k.mat("bot_bristle", (230, 170, 40), var=0.2, scale=12)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    p.append(k.lathe([(1.25, 0.25), (1.35, 0.5), (1.35, 0.9), (1.2, 1.4), (0.85, 1.9), (0.4, 2.15), (0, 2.2)], m=shell, n=20))
    p.append(k.lathe([(1.4, 0.15), (1.45, 0.3), (1.45, 0.55), (1.38, 0.6)], m=dark, n=20))
    for x in (-0.8, 0.8):
        p.append(k.cyl(0.28, 0.3, (x, 0, 0.28), (0, 90, 0), m=dark, n=10))
    # Visor face and antenna.
    g.append(k.surface(6, 2, lambda u, v: (1.0 * math.sin((u - 0.5) * 1.6), 1.0 * math.cos((u - 0.5) * 1.6) + 0.33, 1.45 + v * 0.3), m=glow_m))
    p.append(k.cyl(0.04, 0.6, (0.3, -0.2, 2.4), m=dark, n=4))
    g.append(k.sphere(0.1, (0.3, -0.2, 2.72), m=glow_m, seg=8, rings=4))
    # Broom arm out to the side and forward.
    p.append(k.tube([(1.2, 0, 1.2), (1.7, 0.3, 1.1), (1.9, 0.9, 0.5)], 0.08, m=dark, n=6))
    p.append(k.box((0.25, 0.9, 0.25), (1.9, 1.0, 0.35), (0, 0, 20), m=dark))
    p.append(k.box((0.3, 0.8, 0.35), (1.9, 1.0, 0.1), (0, 0, 20), m=bristle))
    return {"": p, "glow": g}


def cable_arch():
    body = k.metal("arch_steel", k.STEEL)
    cable = k.metal("arch_cable", (20, 22, 30), var=0.05)
    glow_m = k.neon(k.MAGENTA)
    glow2 = k.neon(k.CYAN)
    p, g, g2 = [], [], []
    for x in (-3.3, 3.3):
        p.append(k.rounded((0.8, 0.8, 0.4), (x, 0, 0.2), m=body, r=0.1))
        p.append(k.box((0.45, 0.45, 7.2), (x, 0, 3.9), m=body))
        p.append(k.rounded((0.7, 0.7, 0.3), (x, 0, 7.6), m=body, r=0.08))
        g2.append(k.box((0.08, 0.5, 5.8), (x * 0.94, 0, 3.8), m=glow2))
    p.append(k.box((7.1, 0.3, 0.3), (0, 0, 7.3), m=body))
    # Sagging cables with hanging lights.
    for y, sag in ((-0.25, 1.2), (0.25, 1.7)):
        p.append(k.rope((-3.2, y, 7.1), (3.2, y, 7.1), sag, 0.05, cable, n=5, steps=12))
    for i in range(7):
        t = (i + 1) / 8
        x = -3.2 + 6.4 * t
        z = 7.1 - 4 * 1.45 * t * (1 - t)
        g.append(k.sphere(0.2, (x, 0, z - 0.3), m=glow_m, seg=8, rings=5))
    return {"": p, "glow": g, "glow2": g2}


def holo_koi():
    stone = k.mat("koi_rim", (40, 46, 64), var=0.12, scale=5, rough=0.35)
    water = k.mat("koi_water", (6, 22, 48), var=0.3, scale=2, emit=0.12, rough=0.1)
    fish_m = k.neon(k.CORAL)
    rim_m = k.neon(k.CYAN)
    p, g, g2 = [], [], []
    p.append(k.lathe([(3.7, 0), (3.7, 0.7), (3.3, 0.75), (3.2, 0.45), (0, 0.45)], m=stone, n=8, rot=(0, 0, 22.5)))
    p.append(k.cyl(3.2, 0.05, (0, 0, 0.5), m=water, n=8, rot=(0, 0, 22.5)))
    g2.append(k.lathe([(3.25, 0.62), (3.3, 0.66)], m=rim_m, n=8, rot=(0, 0, 22.5)))
    # Three koi swimming in a circle, hovering just above the water.
    for i in range(3):
        a = 2 * math.pi * i / 3
        pts, radii = [], []
        for s in range(7):
            t = s / 6
            ang = a + t * 0.9
            r = 1.8 + 0.15 * math.sin(t * 6)
            pts.append((r * math.cos(ang), r * math.sin(ang), 1.2 + 0.25 * i + 0.1 * math.sin(t * 3)))
            radii.append(0.32 * math.sin(math.pi * min(0.98, 0.15 + t * 0.85)) + 0.02)
        g.append(k.tube(pts, radii, m=fish_m, n=8))
        tail = pts[0]
        ang = a - 0.15
        g.append(k.poly([(0, 0), (-0.5, 0.35), (-0.5, -0.35)], 0.04, loc=tail, rot=(90, 0, math.degrees(ang) + 90), m=fish_m))
    return {"": p, "glow": g, "glow2": g2}


def vending_bot():
    shell = k.mat("vend_shell", (40, 48, 70), var=0.08, scale=6, rough=0.3)
    trim = k.metal("vend_trim", k.GUNMETAL)
    screen = k.mat("vend_screen", (10, 14, 30), kind="flat", rough=0.1)
    face = k.neon(k.CYAN, "vend_face")
    cans = [k.mat(f"vend_can{i}", c, kind="flat", emit=1.5) for i, c in enumerate([k.MAGENTA, k.LIME, k.AMBER, k.VIOLET])]
    glow_m = k.neon(k.MAGENTA)
    p, g = [], []
    p.append(k.rounded((3.0, 2.2, 5.0), (0, 0, 2.7), m=shell, r=0.35))
    p.append(k.rounded((3.1, 2.3, 0.3), (0, 0, 0.15), m=trim, r=0.1))
    # Screen face with two happy eyes.
    p.append(k.rounded((2.2, 0.1, 1.3), (0, 1.12, 4.25), m=screen, r=0.08))
    for x in (-0.45, 0.45):
        p.append(k.poly([(x - 0.25, 4.15), (x, 4.5), (x + 0.25, 4.15), (x + 0.15, 4.15), (x, 4.33), (x - 0.15, 4.15)], 0.06, loc=(0, 1.2, 0), m=face))
    # Product window with rows of cans.
    p.append(k.rounded((2.2, 0.1, 2.0), (0, 1.12, 2.4), m=screen, r=0.06))
    for row in range(3):
        for col in range(4):
            p.append(k.cyl(0.17, 0.45, (-0.75 + col * 0.5, 1.05, 1.75 + row * 0.62), m=cans[(row + col) % 4], n=8))
    p.append(k.box((1.6, 0.25, 0.4), (0, 1.12, 0.9), m=trim))
    # Little arms waving.
    for s in (-1, 1):
        p.append(k.tube([(s * 1.5, 0.2, 3.4), (s * 1.95, 0.4, 2.9), (s * 2.05, 0.7, 2.3)], 0.14, m=trim, n=6))
        p.append(k.sphere(0.26, (s * 2.05, 0.75, 2.15), m=shell, seg=8, rings=6))
    g.append(k.box((3.06, 0.08, 0.1), (0, 1.12, 5.05), m=glow_m))
    for s in (-1, 1):
        g.append(k.box((0.08, 0.1, 4.4), (s * 1.53, 1.0, 2.75), m=glow_m))
    return {"": p, "glow": g}


ASSETS = [
    dict(name="neon_bench", build=neon_bench, budget=1500, size=[3.4, 2.3, 1.6], priority=1, order=20,
         replaces="Plaza item bench: greybox in src/spire-client/PlazaView.client.luau 38-56", glow={"glow": k.MAGENTA},
         notes="1x1 cell; faces the walkway."),
    dict(name="holo_palm", build=holo_palm, budget=2500, size=[3.4, 9, 3.4], priority=1, order=21,
         replaces="Plaza item palm: greybox in PlazaView.client.luau 38-56", glow={"glow": k.CYAN},
         notes="Fronds are the Neon glow mesh (hologram leaves)."),
    dict(name="street_lamp", build=street_lamp, budget=1200, size=[1.5, 12.2, 3.8], priority=1, order=22,
         replaces="City lamps (src/spire-client/City.client.luau 62-68, 146-152, 258-260) and plaza item lamp (PlazaView 38-56)",
         glow={"glow": k.ICE}, notes="Pole at the back end (+Z in Roblox), head 3 studs forward; code keeps the PointLight and recolours the glow."),
    dict(name="bollard", build=bollard, budget=400, size=[0.85, 1.85, 0.85], priority=2, order=23,
         replaces="City bollards (City.client.luau 261-265) and plaza item bollard", glow={"glow": k.AMBER}),
    dict(name="planter", build=planter, budget=2000, size=[3.4, 3.0, 3.4], priority=2, order=24,
         replaces="Plaza item planter: greybox in PlazaView.client.luau 38-56", glow={"glow": k.LIME}),
    dict(name="neon_arrow", build=neon_arrow, budget=600, size=[3.0, 3.5, 0.9], priority=2, order=25,
         replaces="Plaza item arrow: greybox in PlazaView.client.luau 38-56", glow={"glow": k.CYAN}),
    dict(name="trash_bot", build=trash_bot, budget=1500, size=[3.3, 2.8, 3.0], priority=2, order=26,
         replaces="Plaza item trashbot: greybox in PlazaView.client.luau 38-56 (art bible 10 #10)", glow={"glow": k.CYAN}),
    dict(name="cable_arch", build=cable_arch, budget=1500, size=[7.4, 7.8, 0.9], priority=2, order=27,
         replaces="Plaza item arch: greybox in PlazaView.client.luau 38-56", glow={"glow": k.MAGENTA, "glow2": k.CYAN}),
    dict(name="holo_koi", build=holo_koi, budget=2000, size=[7.4, 2.0, 7.4], priority=2, order=28,
         replaces="Plaza item koi: greybox in PlazaView.client.luau 38-56 (art bible 10 #11)", glow={"glow": k.CORAL, "glow2": k.CYAN}),
    dict(name="vending_bot", build=vending_bot, budget=2500, size=[4.4, 5.2, 2.6], priority=1, order=29,
         replaces="City vending kiosks (City.client.luau 274-281) and plaza item vending (PlazaView 38-56); art bible 10 #4",
         glow={"glow": k.MAGENTA}),
]
