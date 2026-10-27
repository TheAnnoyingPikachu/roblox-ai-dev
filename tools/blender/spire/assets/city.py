"""City and lot props: the city crest sculpture (src/spire-client/City.client.luau 108-143), the
searchlight turrets (179-204), the maglev viaduct deck (285-298), the Top Spires / Market board
frame (server src/spire/City.luau 54-69, client neon frame City.client.luau 216-239), and the lot
pieces built by the server in src/spire/Lots.luau: the BUILD terminal (320-321) and the lot sign
(334-345). Front +Y (Roblox -Z)."""

import math

import kit as k


def _band(radius, tilt, spin, z0, m, section=0.35, n=64, sides=8):
    """Torus of `radius` tilted `tilt` degrees about X, then turned `spin` about Z, centred at z0."""
    pts = []
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        v = k.Vector((radius * math.cos(a), radius * math.sin(a), 0))
        v.rotate(k.Matrix.Rotation(math.radians(tilt), 3, "X"))
        v.rotate(k.Matrix.Rotation(math.radians(spin), 3, "Z"))
        pts.append((v.x, v.y, v.z + z0))
    return k.tube(pts, section, m=m, n=sides, cap=False)


def city_crest():
    body = k.metal("crest_body", (60, 70, 96), var=0.1)
    dark = k.metal("crest_dark", k.STEEL)
    glows = [k.neon(k.CYAN), k.neon(k.MAGENTA), k.neon(k.VIOLET)]
    p, gl = [], [[], [], []]
    # Pedestal and a faceted central spire.
    p.append(k.lathe([(3.2, 0), (3.2, 0.6), (2.4, 1.0), (1.6, 1.6), (1.2, 2.2)], m=dark, n=6))
    p.append(k.lathe([(1.2, 2.2), (1.0, 8.0), (0.7, 16.0), (0.25, 21.0), (0, 22.5)], m=body, n=6))
    for i in range(6):
        a = math.radians(60 * i)
        gl[0].append(k.strip((1.12 * math.cos(a), 1.12 * math.sin(a), 2.6), (0.3 * math.cos(a), 0.3 * math.sin(a), 20.5), 0.08, glows[0]))
    # Three interlocking rings: metal bands with neon edges.
    for r, (radius, tilt, spin, z) in enumerate(((5.0, 62, 0, 12.0), (6.2, 62, 120, 12.5), (7.4, 62, 240, 13.0))):
        p.append(_band(radius, tilt, spin, z, body, section=0.6, n=64, sides=8))
        gl[r].append(_band(radius + 0.62, tilt, spin, z, glows[r], section=0.14, n=64, sides=4))
        gl[r].append(_band(radius - 0.62, tilt, spin, z, glows[r], section=0.14, n=64, sides=4))
    # Glowing core held in the middle of the rings, with a collar on the spire.
    gl[0].append(k.ico(1.5, (0, 0, 12.5), m=glows[0], subdiv=2))
    p.append(k.lathe([(1.0, 9.6), (1.9, 10.2), (1.9, 10.5), (1.0, 10.8)], m=dark, n=12))
    p.append(k.lathe([(0.8, 14.2), (1.6, 14.6), (1.6, 14.9), (0.7, 15.3)], m=dark, n=12))
    # Floating crest glyph: an octahedron at the top.
    gl[2].append(k.ico(0.9, (0, 0, 24.0), m=glows[2], subdiv=1, scale=(1, 1, 1.5)))
    return {"": p, "glow": gl[0], "glow2": gl[1], "glow3": gl[2]}


def searchlight():
    body = k.metal("sl_body", (50, 58, 78))
    dark = k.metal("sl_dark", k.ASPHALT)
    lens = k.mat("sl_lens", k.ICE, kind="flat", emit=4)
    glow_m = k.neon(k.ICE)
    p, g = [], []
    p.append(k.lathe([(1.7, 0), (1.7, 0.4), (1.4, 0.6), (1.0, 0.7)], m=dark, n=12))
    p.append(k.cyl(0.9, 0.6, (0, 0, 1.0), m=body, n=12))
    # Yoke and a drum lamp pointing up and forward.
    for x in (-1.15, 1.15):
        p.append(k.rounded((0.3, 0.8, 1.8), (x, 0, 1.9), m=body, r=0.08))
    p.append(k.cyl(0.95, 1.6, (0, 0.2, 2.4), (-25, 0, 0), m=dark, n=16))
    p.append(k.cyl(1.05, 0.25, (0, 0.55, 3.15), (-25, 0, 0), m=body, n=16))
    p.append(k.cyl(0.85, 0.05, (0, 0.62, 3.3), (-25, 0, 0), m=lens, n=16))
    g.append(k.ring(1.72, 0.42, 0.06, glow_m, n=24, sides=4))
    return {"": p, "glow": g}


def viaduct_segment():
    deck = k.mat("via_deck", (46, 50, 64), var=0.15, scale=3, rough=0.4)
    body = k.metal("via_body", k.STEEL)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    L = 29.2
    # Deck with chamfered underside, parapets and the centre maglev rail.
    p.append(k.poly([(-5, 0.6), (5, 0.6), (5, 2.0), (-5, 2.0)], L, rot=(0, 0, 0), m=deck))
    p.append(k.poly([(-4.2, 0), (4.2, 0), (5, 0.6), (-5, 0.6)], L, m=body))
    for x in (-4.8, 4.8):
        p.append(k.box((0.4, L, 0.9), (x, 0, 2.45), m=body))
    p.append(k.box((1.2, L, 0.5), (0, 0, 2.25), m=body))
    p.append(k.box((0.6, L, 0.2), (0, 0, 2.55), m=k.metal("via_rail", k.CHROME, var=0.05)))
    for y in (-L / 2 + 2, 0, L / 2 - 2):
        p.append(k.box((10.2, 0.6, 0.3), (0, y, 0.15), m=body))
    g.append(k.box((10.4, L, 0.12), (0, 0, 0.62), m=glow_m))
    return {"": p, "glow": g}


def board_frame():
    body = k.metal("bf_body", (36, 42, 60))
    dark = k.metal("bf_dark", k.ASPHALT)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    W, H, cz = 16.0, 10.0, 9.0  # the server board: 16 x 10 centred 9 studs up
    t = 0.7
    # Frame around the board opening (the board part with its SurfaceGui sits inside).
    for z, w in ((cz + H / 2 + t / 2, W + 2 * t), (cz - H / 2 - t / 2, W + 2 * t)):
        p.append(k.rounded((w, 1.2, t), (0, 0, z), m=body, r=0.12))
    for x in (-W / 2 - t / 2, W / 2 + t / 2):
        p.append(k.rounded((t, 1.2, H), (x, 0, cz), m=body, r=0.12))
    p.append(k.box((W, 0.2, H), (0, -0.55, cz), m=dark))
    # Two legs, feet and a crown cap.
    for x in (-5.5, 5.5):
        p.append(k.box((0.8, 0.8, cz - H / 2 - t), (x, -0.2, (cz - H / 2 - t) / 2), m=body))
        p.append(k.rounded((1.6, 1.8, 0.4), (x, -0.2, 0.2), m=dark, r=0.1))
    p.append(k.rounded((6.0, 1.0, 0.8), (0, 0, cz + H / 2 + t + 0.4), m=body, r=0.2))
    # Neon edge just inside the frame on the front.
    for z in (cz + H / 2 + 0.05, cz - H / 2 - 0.05):
        g.append(k.box((W + 0.2, 0.1, 0.12), (0, 0.62, z), m=glow_m))
    for x in (-W / 2 - 0.05, W / 2 + 0.05):
        g.append(k.box((0.12, 0.1, H), (x, 0.62, cz), m=glow_m))
    g.append(k.box((5.4, 0.1, 0.15), (0, 0.52, cz + H / 2 + t + 0.4), m=glow_m))
    return {"": p, "glow": g}


def lot_sign():
    body = k.metal("ls_body", (36, 42, 60))
    dark = k.metal("ls_dark", k.ASPHALT)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    W, H, cz = 8.0, 4.0, 5.0  # the server sign: 8 x 4 centred 5 studs up
    t = 0.4
    p.append(k.rounded((W + 2 * t, 0.8, t), (0, 0, cz + H / 2 + t / 2), m=body, r=0.08))
    p.append(k.rounded((W + 2 * t, 0.8, t), (0, 0, cz - H / 2 - t / 2), m=body, r=0.08))
    for x in (-W / 2 - t / 2, W / 2 + t / 2):
        p.append(k.rounded((t, 0.8, H), (x, 0, cz), m=body, r=0.08))
    p.append(k.box((0.6, 0.6, cz - H / 2 - t), (0, -0.1, (cz - H / 2 - t) / 2), m=body))
    p.append(k.rounded((2.0, 1.4, 0.3), (0, -0.1, 0.15), m=dark, r=0.08))
    g.append(k.box((W + 0.4, 0.1, 0.1), (0, 0.42, cz + H / 2 + t + 0.08), m=glow_m))
    g.append(k.box((W + 0.4, 0.1, 0.1), (0, 0.42, cz - H / 2 - t - 0.08), m=glow_m))
    return {"": p, "glow": g}


def build_terminal():
    body = k.metal("bt_body", (40, 46, 68))
    screen = k.mat("bt_screen", (0, 200, 230), var=0.3, scale=5, emit=2)
    glow_m = k.neon(k.CYAN)
    p, g = [], []
    p.append(k.rounded((3.0, 1.6, 0.4), (0, 0, 0.2), m=body, r=0.1))
    # Side profile (y, z) extruded 2.4 wide: front lower, so the top screen faces the player.
    p.append(k.poly([(-0.6, 0.4), (0.6, 0.4), (0.6, 3.8), (-0.6, 4.6)], 2.4, rot=(0, 0, 90), m=body, bevel=0.06))
    p.append(k.rounded((2.7, 1.6, 0.2), (0, 0, 4.25), (-33.7, 0, 0), m=body, r=0.06))
    p.append(k.box((2.2, 1.1, 0.05), (0, 0.072, 4.358), (-33.7, 0, 0), m=screen))
    # Hologram of a little tower floating above, inside a projector ring.
    p.append(k.cyl(0.9, 0.2, (0, -0.2, 5.4), m=body, n=16))
    g.append(k.ring(0.9, 5.52, 0.05, glow_m, n=20, sides=4, centre=(0, -0.2)))
    for i, (w, h) in enumerate(((0.9, 0.8), (0.75, 0.8), (0.6, 0.7), (0.45, 0.6))):
        z = 5.8 + sum(hh for _, hh in ((0.9, 0.8), (0.75, 0.8), (0.6, 0.7), (0.45, 0.6))[:i]) + h / 2
        for s in (-1, 1):
            g.append(k.box((0.05, w, h), (s * w / 2, -0.2, z), m=glow_m))
            g.append(k.box((w, 0.05, h), (0, -0.2 + s * w / 2, z), m=glow_m))
        g.append(k.box((w, w, 0.05), (0, -0.2, z + h / 2), m=glow_m))
    g.append(k.cyl(0.03, 1.0, (0, -0.2, 9.2), m=glow_m, n=4))
    return {"": p, "glow": g}


ASSETS = [
    dict(name="city_crest", build=city_crest, budget=8000, size=[16, 25, 16], priority=1, order=10,
         replaces="City crest rings (src/spire-client/City.client.luau 108-143, Kit.mesh hook cityCrest); art bible 10 #14",
         glow={"glow": k.CYAN, "glow2": k.MAGENTA, "glow3": k.VIOLET},
         notes="Hero. Stands on the existing dais at y 1.3; code spins the whole model slowly (Kit.spin)."),
    dict(name="searchlight", build=searchlight, budget=1200, size=[3.4, 3.4, 3.4], priority=2, order=11,
         replaces="Searchlight housings (City.client.luau 182-184); the Beam stays", glow={"glow": k.ICE}),
    dict(name="viaduct_segment", build=viaduct_segment, budget=600, size=[10.4, 2.9, 29.2], priority=2, order=12,
         replaces="Maglev viaduct deck, glow strip and rail (City.client.luau 285-298), 48 copies", glow={"glow": k.CYAN},
         notes="Length along Roblox Z; code recolours alternate segments violet. Pillars stay parts."),
    dict(name="board_frame", build=board_frame, budget=1200, size=[17.4, 15.9, 1.6], priority=2, order=13,
         replaces="Board post (src/spire/City.luau 56) and client neon frame (City.client.luau 216-239)",
         glow={"glow": k.CYAN}, notes="Opening fits the 16 x 10 board centred 9 studs up; the board part keeps its SurfaceGui."),
    dict(name="lot_sign", build=lot_sign, budget=600, size=[8.8, 7.9, 1.2], priority=2, order=14,
         replaces="Lot sign post and frame (src/spire/Lots.luau 334-345)", glow={"glow": k.CYAN},
         notes="Opening fits the 8 x 4 sign centred 5 studs up; the sign part keeps its SurfaceGui."),
    dict(name="build_terminal", build=build_terminal, budget=1500, size=[3.0, 9.7, 1.6], priority=1, order=15,
         replaces="BUILD terminal box (src/spire/Lots.luau 320-321); art bible 5.2 kiosk with a holo tower",
         glow={"glow": k.CYAN}, notes="Server keeps the terminal part (invisible) for the Build prompt."),
]
