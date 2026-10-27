"""Tower kit: the seven department modules (SpireConfig.DEPTS module names, src/shared/SpireConfig.luau
92-155), today a 6 x (1.5 + level) x 6 box per slot in src/spire-client/TowerView.client.luau
136-155; the roof antenna and beacon (TowerView 157-170); and the lift ring (TowerView 114-123,
server lift pad src/spire/Lots.luau 305-316). Modules fit a 6 x 6 slot, front +Y (Roblox -Z).
The glow mesh is the department colour (art bible 2)."""

import math

import kit as k


def _base(p, body, w=5.6, d=5.6):
    p.append(k.rounded((w, d, 0.4), (0, 0, 0.2), m=body, r=0.12))


def server_rack():
    body = k.metal("rack_body", (30, 36, 54))
    face = k.mat("rack_face", (14, 18, 30), var=0.2, scale=12)
    led = k.mat("rack_led", (120, 255, 160), kind="flat", emit=2.5)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    _base(p, body)
    for x in (-1.4, 1.4):
        p.append(k.rounded((2.4, 3.0, 5.2), (x, 0, 3.0), m=body, r=0.12))
        for u in range(9):
            z = 1.0 + u * 0.48
            p.append(k.box((2.0, 0.08, 0.38), (x, 1.52, z), m=face))
            for j in range(3):
                p.append(k.box((0.08, 0.04, 0.08), (x - 0.75 + j * 0.18, 1.57, z), m=led))
        g.append(k.box((0.08, 0.08, 4.9), (x - 1.12, 1.52, 3.0), m=glow_m))
        g.append(k.box((0.08, 0.08, 4.9), (x + 1.12, 1.52, 3.0), m=glow_m))
    # Cable tray on top.
    p.append(k.box((5.2, 0.6, 0.25), (0, -0.6, 5.75), m=body))
    for i in range(5):
        p.append(k.tube([(-2.4 + i * 1.2, -0.6, 5.9), (-2.4 + i * 1.2, -0.6, 6.1), (-2.0 + i * 1.0, 0.2, 6.05)], 0.06, m=face, n=4))
    return {"": p, "glow": g}


def fusion_cell():
    body = k.metal("fusion_body", (40, 44, 60))
    core = k.mat("fusion_core", (255, 200, 80), kind="grad", rgb2=(255, 120, 20), emit=3)
    glow_m = k.neon(k.AMBER)
    p, g = [], []
    p.append(k.lathe([(2.8, 0), (2.8, 0.5), (2.2, 0.7), (1.6, 0.8)], m=body, n=8, rot=(0, 0, 22.5)))
    p.append(k.cyl(0.9, 4.0, (0, 0, 2.8), m=core, n=16))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.append(k.box((0.4, 0.4, 4.6), (2.0 * math.cos(a), 2.0 * math.sin(a), 3.0), m=body))
    p.append(k.lathe([(1.6, 4.8), (2.6, 5.0), (2.6, 5.4), (1.0, 5.7), (0, 5.8)], m=body, n=8, rot=(0, 0, 22.5)))
    # Containment rings around the core.
    for z in (1.6, 2.8, 4.0):
        g.append(k.ring(1.3, z, 0.12, glow_m, n=24, sides=6))
    return {"": p, "glow": g}


def holo_projector():
    body = k.metal("proj_body", (40, 36, 60))
    lens = k.mat("proj_lens", (255, 120, 200), kind="flat", emit=2)
    glow_m = k.neon(k.MAGENTA)
    p, g = [], []
    p.append(k.lathe([(2.4, 0), (2.5, 0.3), (2.2, 0.9), (1.2, 1.3), (1.0, 1.6)], m=body, n=16))
    p.append(k.cyl(0.5, 0.2, (0, 0, 1.7), m=lens, n=12))
    # Floating holo screen frame and the ad pane (glow), with a light cone.
    g.append(k.box((3.8, 0.08, 2.2), (0, 0, 4.0), m=glow_m))
    p.append(k.box((4.0, 0.12, 0.12), (0, 0, 5.15), m=body))
    p.append(k.box((4.0, 0.12, 0.12), (0, 0, 2.85), m=body))
    for x in (-2.0, 2.0):
        p.append(k.box((0.12, 0.12, 2.4), (x, 0, 4.0), m=body))
    g.append(k.cyl(0.4, 1.2, (0, 0, 2.3), m=glow_m, n=8, r2=1.2))
    return {"": p, "glow": g}


def bio_printer():
    body = k.mat("bio_body", (210, 225, 230), var=0.04, scale=6, rough=0.3)
    dark = k.metal("bio_dark", k.STEEL)
    vat = k.mat("bio_vat", (150, 255, 80), var=0.3, scale=3, emit=1.5)
    glow_m = k.neon(k.LIME)
    p, g = [], []
    _base(p, dark)
    p.append(k.rounded((5.0, 2.0, 3.0), (0, -1.6, 1.9), m=body, r=0.3))
    # Gantry with a print head over a glowing vat.
    p.append(k.cyl(1.4, 1.4, (0, 1.0, 1.1), m=dark, n=16))
    p.append(k.cyl(1.25, 0.05, (0, 1.0, 1.82), m=vat, n=16))
    for x in (-2.2, 2.2):
        p.append(k.box((0.3, 0.3, 4.6), (x, 1.0, 2.7), m=dark))
    p.append(k.box((4.8, 0.4, 0.4), (0, 1.0, 5.0), m=dark))
    p.append(k.rounded((0.8, 0.8, 0.9), (0.4, 1.0, 4.4), m=body, r=0.15))
    p.append(k.cyl(0.1, 1.0, (0.4, 1.0, 3.5), m=dark, n=6, r2=0.02))
    # Diagonal lime tubes (art bible 5.1).
    for i in range(3):
        g.append(k.tube([(-2.3 + i * 0.6, -0.6, 0.5), (-1.5 + i * 0.6, -0.6, 2.0), (-0.3 + i * 0.6, -0.6, 3.3)], 0.1, m=glow_m, n=6))
    g.append(k.ring(1.42, 1.86, 0.06, glow_m, n=20, sides=4, centre=(0, 1.0)))
    return {"": p, "glow": g}


def drone_dock():
    pad = k.metal("dock_pad", (36, 40, 58))
    stripe = k.mat("dock_stripe", (255, 140, 90), kind="stripes", rgb2=(30, 30, 40), scale=3)
    glow_m = k.neon(k.CORAL)
    p, g = [], []
    p.append(k.lathe([(2.8, 0), (2.8, 0.5), (2.6, 0.6), (0, 0.6)], m=pad, n=8, rot=(0, 0, 22.5)))
    p.append(k.cyl(2.2, 0.04, (0, 0, 0.62), m=stripe, n=8, rot=(0, 0, 22.5)))
    g.append(k.ring(2.65, 0.58, 0.08, glow_m, n=24, sides=4))
    # Charging mast.
    p.append(k.box((0.4, 0.4, 3.4), (2.2, -2.2, 2.2), m=pad))
    p.append(k.tube([(2.2, -2.2, 3.8), (1.4, -1.4, 3.9), (0.6, -0.6, 2.5)], 0.08, m=pad, n=4))
    _drone(p, g, (0, 0, 1.1), pad, glow_m, 0.75)
    return {"": p, "glow": g}


def _drone(p, g, at, body_m, glow_m, s=1.0):
    """Quadcopter: rounded body, four arms with rotor rings, a parcel underneath."""
    x0, y0, z0 = at
    shell = k.mat("drone_shell", (220, 228, 240), kind="flat", rough=0.3)
    parcel = k.mat("drone_parcel", (255, 180, 60), var=0.1, scale=8, emit=0.8)
    p.append(k.sphere(0.9 * s, (x0, y0, z0 + 0.9 * s), m=shell, scale=(1.2, 1.0, 0.55), seg=14, rings=8))
    p.append(k.rounded((0.9 * s, 0.9 * s, 0.7 * s), (x0, y0, z0 + 0.3 * s), m=parcel, r=0.08 * s))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        ex, ey = x0 + 1.6 * s * math.cos(a), y0 + 1.6 * s * math.sin(a)
        p.append(k.strip((x0, y0, z0 + 0.95 * s), (ex, ey, z0 + 1.0 * s), 0.18 * s, body_m))
        p.append(k.cyl(0.12 * s, 0.4 * s, (ex, ey, z0 + 1.1 * s), m=body_m, n=6))
        g.append(k.ring(0.6 * s, z0 + 1.25 * s, 0.05 * s, glow_m, n=16, sides=4, centre=(ex, ey)))
        p.append(k.box((1.1 * s, 0.1 * s, 0.03 * s), (ex, ey, z0 + 1.32 * s), (0, 0, 30 * i), m=body_m))
    g.append(k.box((0.6 * s, 0.06 * s, 0.12 * s), (x0, y0 + 0.88 * s, z0 + 0.95 * s), m=glow_m))


def courier_drone():
    body = k.metal("drone_body", k.GUNMETAL)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    _drone(p, g, (0, 0, 0), body, glow_m, 1.0)
    return {"": p, "glow": g}


def q_mind():
    body = k.metal("q_body", (34, 30, 56))
    orb = k.mat("q_orb", (190, 150, 255), var=0.4, scale=3, emit=2.5)
    glow_m = k.neon(k.VIOLET)
    p, g = [], []
    p.append(k.lathe([(2.8, 0), (2.8, 0.4), (2.0, 0.8), (1.4, 0.9)], m=body, n=6))
    p.append(k.lathe([(1.4, 5.4), (2.0, 5.5), (2.4, 5.9), (0, 6.0)], m=body, n=6))
    for i in range(3):
        a = math.radians(120 * i + 30)
        p.append(k.tube([(2.3 * math.cos(a), 2.3 * math.sin(a), 0.6), (2.6 * math.cos(a), 2.6 * math.sin(a), 3.2), (2.1 * math.cos(a), 2.1 * math.sin(a), 5.7)], 0.18, m=body, n=6))
    p.append(k.ico(1.1, (0, 0, 3.2), m=orb, subdiv=3))
    # Gyroscope rings around the orb.
    for tilt in (0, 60, 120):
        pts = []
        for i in range(25):
            a = 2 * math.pi * i / 24
            v = k.Vector((1.7 * math.cos(a), 1.7 * math.sin(a), 0))
            v.rotate(k.Matrix.Rotation(math.radians(70), 3, "X"))
            v.rotate(k.Matrix.Rotation(math.radians(tilt), 3, "Z"))
            pts.append((v.x, v.y, v.z + 3.2))
        g.append(k.tube(pts, 0.07, m=glow_m, n=5, cap=False))
    return {"": p, "glow": g}


def uplink_dish():
    body = k.metal("dish_body", (60, 68, 88))
    dish = k.mat("dish_white", (175, 188, 208), kind="flat", rough=0.35)
    glow_m = k.neon(k.WHITE)
    p, g = [], []
    p.append(k.lathe([(2.4, 0), (2.4, 0.4), (1.6, 0.6)], m=body, n=10))
    # Lattice mast.
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.append(k.strip((1.3 * math.cos(a), 1.3 * math.sin(a), 0.5), (0.45 * math.cos(a), 0.45 * math.sin(a), 3.4), 0.14, body))
    for z in (1.4, 2.4):
        r = 1.3 - (z - 0.5) * 0.3
        p.append(k.ring(r * 1.414 * 0.75, z, 0.06, body, n=4, sides=4))
    p.append(k.cyl(0.4, 0.8, (0, 0, 3.6), m=body, n=10))
    # Dish tilted up toward the sky, facing front.
    prof = [(0.0, 0.0)] + [(2.6 * t, 0.9 * t * t) for t in [i / 6 for i in range(1, 7)]]
    p.append(k.lathe([(r, z) for r, z in prof], loc=(0, 0.3, 4.3), rot=(-50, 0, 0), m=dish, n=20))
    p.append(k.tube([(0, 0.3, 4.3), (0, 1.2, 5.4), (0, 1.75, 6.0)], 0.06, m=body, n=4))
    g.append(k.sphere(0.2, (0, 1.75, 6.05), m=glow_m, seg=8, rings=5))
    g.append(k.ring(2.58, 0, 0.06, glow_m, n=28, sides=4))
    g[-1].data.transform(k.move(0, 0.3, 4.3) @ k.Matrix.Rotation(math.radians(-50), 4, "X") @ k.move(0, 0, 0.9))
    return {"": p, "glow": g}


def roof_antenna():
    body = k.metal("ant_body", k.STEEL)
    dark = k.metal("ant_dark", k.ASPHALT)
    glow_m = k.neon(k.CYAN)
    beacon = k.neon((255, 40, 60))
    p, g, g2 = [], [], []
    p.append(k.rounded((6.0, 6.0, 1.2), (0, 0, 0.6), m=dark, r=0.2))
    p.append(k.rounded((4.0, 4.0, 1.4), (0, 0, 1.9), m=body, r=0.2))
    # Tapering lattice mast.
    h = 18.0
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.append(k.strip((1.3 * math.cos(a), 1.3 * math.sin(a), 2.6), (0.25 * math.cos(a), 0.25 * math.sin(a), 2.6 + h), 0.18, body))
    for j in range(6):
        z = 3.5 + j * 2.8
        r = 1.3 - (z - 2.6) / h * 1.05
        for i in range(4):
            a0, a1 = math.radians(45 + 90 * i), math.radians(135 + 90 * i)
            p.append(k.strip((r * math.cos(a0), r * math.sin(a0), z), (r * math.cos(a1), r * math.sin(a1), z + 1.4), 0.08, body))
        g.append(k.ring(r * 0.75, z, 0.05, glow_m, n=4, sides=4))
    p.append(k.cyl(0.08, 2.0, (0, 0, 2.6 + h + 1.0), m=body, n=6))
    g2.append(k.sphere(0.7, (0, 0, 2.6 + h + 0.2), m=beacon, seg=12, rings=8))
    # Side dishes.
    for s in (-1, 1):
        p.append(k.lathe([(0.0, 0.0), (0.6, 0.1), (1.0, 0.3)], loc=(s * 1.0, 0, 9.0), rot=(0, s * 70, 0), m=body, n=12))
    return {"": p, "glow": g, "glow2": g2}


def lift_ring():
    body = k.metal("lift_body", k.GUNMETAL)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    p.append(k.lathe([(4.0, 0), (4.0, 0.15), (3.6, 0.25), (0, 0.25)], m=body, n=32))
    g.append(k.lathe([(3.75, 0.24), (3.75, 0.3), (3.45, 0.3), (3.45, 0.24)], m=glow_m, n=32))
    # Chevrons pointing in, and a centre disc.
    for i in range(8):
        a = 2 * math.pi * i / 8
        g.append(k.poly([(-0.3, 0), (0, 0.35), (0.3, 0), (0.15, 0), (0, 0.17), (-0.15, 0)], 0.04,
                        loc=(2.6 * math.cos(a), 2.6 * math.sin(a), 0.27), rot=(90, 0, math.degrees(a) + 90), m=glow_m))
    p.append(k.cyl(1.2, 0.05, (0, 0, 0.27), m=k.metal("lift_disc", k.STEEL), n=24))
    return {"": p, "glow": g}


DEPT = "src/spire-client/TowerView.client.luau 136-155 (module box per slot)"
ASSETS = [
    dict(name="server_rack", build=server_rack, budget=2500, size=[5.6, 6.2, 5.6], priority=1, order=1,
         replaces=f"Data Farm module (Server Rack): {DEPT}", glow={"glow": k.CYAN}),
    dict(name="fusion_cell", build=fusion_cell, budget=2000, size=[5.6, 5.8, 5.6], priority=1, order=2,
         replaces=f"Fusion Core module (Fusion Cell): {DEPT}", glow={"glow": k.AMBER}),
    dict(name="holo_projector", build=holo_projector, budget=1500, size=[5.0, 5.2, 5.0], priority=1, order=3,
         replaces=f"Holo Ad Agency module (Holo Projector): {DEPT}", glow={"glow": k.MAGENTA}),
    dict(name="bio_printer", build=bio_printer, budget=2500, size=[5.6, 5.2, 5.6], priority=1, order=4,
         replaces=f"Synth Lab module (Bio-Printer): {DEPT}", glow={"glow": k.LIME}),
    dict(name="drone_dock", build=drone_dock, budget=2500, size=[5.6, 4.8, 5.6], priority=1, order=5,
         replaces=f"Drone Port module (Courier Drone): {DEPT}", glow={"glow": k.CORAL}),
    dict(name="q_mind", build=q_mind, budget=2500, size=[5.6, 6.0, 5.6], priority=1, order=6,
         replaces=f"Quantum Core module (Q-Mind): {DEPT}", glow={"glow": k.VIOLET},
         notes="Art bible 5.1: violet orb visible through the glass."),
    dict(name="uplink_dish", build=uplink_dish, budget=2500, size=[5.2, 6.4, 5.2], priority=1, order=7,
         replaces=f"Orbital Uplink module (Uplink Dish): {DEPT}; art bible 10 #13", glow={"glow": k.WHITE}),
    dict(name="roof_antenna", build=roof_antenna, budget=3000, size=[6, 22, 6], priority=1, order=8,
         replaces="Roof antenna and beacon: src/spire-client/TowerView.client.luau 166-170 (art bible 5.4 default crown)",
         glow={"glow": k.CYAN, "glow2": (255, 40, 60)}, notes="glow2 is the beacon (code blinks it); company sign BillboardGui stays."),
    dict(name="lift_ring", build=lift_ring, budget=1200, size=[8, 0.3, 8], priority=1, order=9,
         replaces="Lift ring per floor (TowerView.client.luau 114-123) and lobby lift pad (src/spire/Lots.luau 305-316)",
         glow={"glow": k.CYAN}, notes="Floor decal-like disc; the server pad stays invisible with its prompt."),
    dict(name="courier_drone", build=courier_drone, budget=1500, size=[4.4, 1.5, 4.4], priority=3, order=50,
         replaces="City drones (art bible 7, Traffic.client.luau, SPIRE-007, not built yet); art bible 10 #1",
         glow={"glow": k.CYAN}, notes="Not wired: no drone code exists yet."),
]
