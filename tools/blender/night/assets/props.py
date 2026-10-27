"""Festival props built from parts in src/night/Arena.luau: stalls (508-581), hanging paper
lanterns (126-133), arched bridges (430-457), the leaderboard frame (641-667), the taiko drum
(306-314) and the courtyard wall (224-246). All face +Y (Roblox -Z), toward the courtyard."""

import math

import kit as k

RED = (200, 40, 40)
CLOTH_WHITE = (240, 240, 235)
INDIGO = (40, 50, 120)


def stall(main, accent):
    def build():
        wood = k.mat("wood", k.WOOD, var=0.18, scale=4, kind="wood")
        post = k.mat("post", k.DARKWOOD, var=0.18, scale=4, kind="wood")
        cloth = k.mat("cloth", main, var=0.06, scale=8)
        trim = k.mat("trim", accent, var=0.06, scale=8)
        ink = k.mat("ink", k.INK, var=0.1)
        crate = k.mat("crate", (150, 110, 70), var=0.18, scale=5, kind="wood")
        p = []
        # Counter facing the courtyard, with a cloth banner and crest.
        p.append(k.box((9, 2.5, 3), (0, 2.5, 1.5), m=wood, bevel=0.08))
        p.append(k.box((9.4, 2.9, 0.25), (0, 2.5, 3.1), m=post, bevel=0.05))
        p.append(k.box((8.4, 0.08, 2.2), (0, 3.8, 1.75), m=cloth))
        p.append(k.cyl(0.65, 0.06, (0, 3.86, 1.8), (90, 0, 0), m=trim, n=20))
        p.append(k.cyl(0.42, 0.07, (0, 3.88, 1.8), (90, 0, 0), m=cloth, n=20))
        # Posts and back wall.
        for x in (-4.3, 4.3):
            for y in (3.6, -3.0):
                p.append(k.box((0.5, 0.5, 8.6), (x, y, 4.3), m=post, bevel=0.06))
        p.append(k.box((9, 0.2, 6), (0, -3.0, 3.2), m=post))
        p.append(k.box((9.2, 0.3, 0.4), (0, -3.0, 6.4), m=wood))
        # Striped fabric awning sloping down to the front, and a scalloped valance.
        for s, colour in ((-1, trim), (0, cloth), (1, trim)):
            p.append(k.box((3.4, 9.4, 0.22), (s * 3.4, 0.4, 8.5), (-14, 0, 0), m=colour, bevel=0.05))
        for i in range(9):
            x = -4.6 + i * 1.15
            p.append(k.cyl(0.58, 0.08, (x, 4.95, 7.3), (90, 0, 0), m=trim if i % 2 else cloth, n=10))
        p.append(k.box((10.4, 0.2, 0.3), (0, 4.95, 7.55), m=ink))
        # Goods on the counter and crates at the side.
        hues = [(255, 120, 40), (240, 60, 70), (255, 200, 70)]
        for g in range(-1, 2):
            p.append(k.box((2.0, 1.4, 0.15), (g * 2.6, 2.5, 3.3), m=wood))
            for j in range(4):
                p.append(k.sphere(0.32, (g * 2.6 + (j % 2 - 0.5) * 0.7, 2.5 + (j // 2 - 0.5) * 0.6, 3.68), m=k.mat(f"good{g}", hues[g + 1], var=0.1), seg=8, rings=6))
        p.append(k.box((2, 2, 2), (5.8, 1.0, 1.0), m=crate, bevel=0.1))
        p.append(k.box((1.6, 1.6, 1.6), (5.6, 0.8, 2.8), (0, 0, 23), m=crate, bevel=0.1))
        return p

    return build


def paper_lantern(colour):
    def build():
        paper = k.mat("paper", colour, var=0.06, scale=4, emit=1.2)
        ink = k.mat("ink", k.INK, var=0.1)
        tassel = k.mat("tassel", k.GOLD, var=0.1, scale=6, kind="wood")
        prof = []
        for i in range(11):
            z = 0.35 + 2.2 * i / 10
            r = 0.88 * math.sqrt(max(0.0, 1 - ((z - 1.45) / 1.2) ** 2))
            prof.append((max(r, 0.45) * (0.95 if i % 2 else 1.0), z))
        p = [k.lathe(prof, m=paper, n=16)]
        p.append(k.lathe([(0.5, 2.5), (0.52, 2.78), (0.3, 2.85)], m=ink, n=12))
        p.append(k.lathe([(0.3, 0.25), (0.52, 0.32), (0.5, 0.6)], m=ink, n=12))
        p.append(k.cyl(0.05, 0.4, (0, 0, 3.05), m=ink, n=4))
        p.append(k.cyl(0.12, 0.3, (0, 0, 0.12), m=tassel, n=6, r2=0.05))
        return p

    return build


def arched_bridge():
    red = k.mat("vermilion", k.VERMILION, var=0.1, scale=1.5, kind="wood")
    deck_m = k.mat("deck", (150, 40, 30), var=0.15, scale=3, kind="wood")
    dark = k.mat("pier", k.DARKWOOD, var=0.15, scale=3, kind="wood")
    bronze = k.mat("bronze", (190, 150, 70), var=0.15, scale=5)
    half, rise = 15, 3.0

    def h(s):
        return 0.4 + rise * math.sin(math.pi * s)

    p = [k.surface(20, 1, lambda u, v: (-half + 2 * half * u, -3 + 6 * v, h(u)), m=deck_m, thickness=0.6)]
    for side in (-3.15, 3.15):
        top = [(-half + 2 * half * i / 20, h(i / 20) + 0.1) for i in range(21)]
        bottom = [(x, z - 1.0) for x, z in reversed(top)]
        p.append(k.poly(top + bottom, 0.3, loc=(0, side, 0), m=red))
        for rail_z in (1.7, 0.9):
            p.append(k.tube([(x, side, z + rail_z) for x, z in top[1:-1]], 0.14, m=red, n=6))
        for i in range(1, 20, 3):
            x, z = top[i]
            p.append(k.box((0.4, 0.4, 1.9), (x, side, z + 0.9), m=red))
        for i in (1, 19):
            x, z = top[i]
            p.append(k.box((0.55, 0.55, 2.4), (x, side, z + 1.1), m=red))
            p.append(k.lathe([(0.3, 0), (0.38, 0.25), (0.2, 0.55), (0.05, 0.75), (0, 0.8)], (x, side, z + 2.3), m=bronze, n=10))
    for x in (-7, 7):
        z = h((x + half) / (2 * half)) - 0.3
        for y in (-2.2, 2.2):
            p.append(k.cyl(0.35, z, (x, y, z / 2), m=dark, n=8))
        p.append(k.box((0.5, 5.2, 0.5), (x, 0, z - 0.4), m=dark))
    return p


def leaderboard_frame():
    red = k.mat("vermilion", k.VERMILION, var=0.1, scale=1.5, kind="wood")
    ink = k.mat("ink", k.INK, var=0.12, scale=3)
    roof = k.mat("roof", k.ROOF, var=0.25, scale=10, kind="wood")
    wood = k.mat("wood", k.DARKWOOD, var=0.18, scale=3, kind="wood")
    p = []
    for x in (-8.6, 8.6):
        p.append(k.cyl(0.5, 14.4, (x, 0, 7.2), m=red, n=12))
        p.append(k.cyl(0.75, 0.6, (x, 0, 0.3), m=ink, n=12))
    p.append(k.box((16.6, 0.8, 12.6), (0, -0.55, 7.0), m=wood, bevel=0.08))  # backing; the text board sits in front
    p.append(k.box((18.6, 0.7, 0.7), (0, 0, 13.6), m=red))
    p.append(k.box((17.6, 0.6, 0.5), (0, 0, 0.75), m=red))
    p += k.hip_roof(10.2, 1.8, 8.6, 14.1, 15.6, roof, lift=0.4, thickness=0.3, nu=10, nv=2)
    p.append(k.box((17.6, 0.5, 0.4), (0, 0, 15.75), m=ink))
    return p


def taiko_drum():
    body = k.mat("drum", (120, 30, 24), var=0.12, scale=3, kind="wood")
    skin = k.mat("skin", (232, 214, 176), var=0.06, scale=4)
    gold = k.mat("gold", k.GOLD, var=0.1, scale=6)
    wood = k.mat("wood", k.WOOD, var=0.18, scale=4, kind="wood")
    ink = k.mat("ink", k.INK, var=0.1)
    cz = 2.25
    # Barrel along x.
    p = [k.lathe([(1.5, -1.2), (1.68, -0.6), (1.75, 0), (1.68, 0.6), (1.5, 1.2)], (0, 0, cz), (0, 90, 0), m=body, n=20)]
    for side in (-1, 1):
        p.append(k.cyl(1.56, 0.08, (side * 1.22, 0, cz), (0, 90, 0), m=skin, n=20))
        p.append(k.cyl(0.5, 0.09, (side * 1.24, 0, cz), (0, 90, 0), m=k.mat("tomoe", k.VERMILION, kind="flat"), n=12))
        for i in range(18):
            a = 2 * math.pi * i / 18
            p.append(k.sphere(0.07, (side * 1.2, math.cos(a) * 1.45, cz + math.sin(a) * 1.45), m=gold, seg=6, rings=4))
    p.append(k.ring(1.72, 0, 0.05, ink, n=20, sides=4))
    p[-1].data.transform(k.move(0, 0, cz) @ k.Matrix.Rotation(math.pi / 2, 4, "Y"))
    # Cradle stand.
    for x in (-0.9, 0.9):
        p.append(k.poly([(-1.5, 0), (1.5, 0), (1.0, 1.3), (-1.0, 1.3)], 0.3, loc=(x, 0, 0), rot=(0, 0, 90), m=wood))
    p.append(k.box((2.2, 2.6, 0.3), (0, 0, 0.15), m=wood))
    return p


def wall_segment():
    stone = k.mat("stone", k.STONE, var=0.22, scale=0.9)
    block = k.mat("block", k.shade(k.STONE, 0.85), var=0.2, scale=1.2)
    cap = k.mat("cap", (60, 56, 64), var=0.15, scale=2)
    wood = k.mat("wood", k.WOOD, var=0.18, scale=4, kind="wood")
    w = 14.0
    p = [k.box((w, 2, 6), (0, 0, 3), m=stone, bevel=0.12)]
    for side in (-1, 1):
        for row, z in enumerate((1.2, 3.4)):
            for i in range(3):
                x = -w / 2 + 2.4 + i * 4.6 + (1.2 if row else 0)
                p.append(k.box((3.6, 0.15, 1.7), (x, side * 1.02, z), m=block))
    p.append(k.box((w + 0.1, 2.4, 0.5), (0, 0, 6.25), m=cap, bevel=0.1))
    p.append(k.box((0.5, 0.5, 3), (w / 2 - 0.3, 0, 8.0), m=wood))
    for z in (7.2, 8.6):
        p.append(k.box((w, 0.35, 0.35), (0, 0, z), m=wood))
    return p


ASSETS = [
    dict(name="festival_stall_red", build=stall(RED, CLOTH_WHITE), budget=3000, size=[12, 10, 9.2], priority=2, order=15,
         replaces="Stall parts in src/night/Arena.luau 508-581 (stalls 1 and 4)",
         notes="Sign text and the hanging lanterns stay in code."),
    dict(name="festival_stall_white", build=stall(CLOTH_WHITE, RED), budget=3000, size=[12, 10, 9.2], priority=2, order=15.1,
         replaces="Stall parts in src/night/Arena.luau 508-581 (stall 2)"),
    dict(name="festival_stall_indigo", build=stall(INDIGO, CLOTH_WHITE), budget=3000, size=[12, 10, 9.2], priority=2, order=15.2,
         replaces="Stall parts in src/night/Arena.luau 508-581 (stalls 3 and 5)"),
    dict(name="paper_lantern_red", build=paper_lantern((255, 90, 60)), budget=600, size=[1.8, 3.2, 1.8], priority=2, order=16,
         replaces="paperLantern parts in src/night/Arena.luau 126-133 (red ones: stage, hall, board, stall left)",
         notes="Origin at the tassel bottom; code hangs it by the top (3.2 above origin). Keep the PointLight."),
    dict(name="paper_lantern_cream", build=paper_lantern((255, 200, 120)), budget=600, size=[1.8, 3.2, 1.8], priority=2, order=16.1,
         replaces="paperLantern parts in src/night/Arena.luau 126-133 (cream ones on the stalls)"),
    dict(name="arched_bridge", build=arched_bridge, budget=2500, size=[31, 5.6, 6.6], priority=2, order=17,
         replaces="bridge parts in src/night/Arena.luau 430-457 (x2)",
         notes="Walked on: keep the deck parts for collision, or set CollisionFidelity PreciseConvexDecomposition."),
    dict(name="leaderboard_frame", build=leaderboard_frame, budget=1500, size=[21, 16, 4], priority=2, order=19,
         replaces="Leaderboard posts in src/night/Arena.luau 641-647",
         notes="The 16 x 12 text board part with the SurfaceGui stays, just in front of the backing."),
    dict(name="taiko_drum", build=taiko_drum, budget=1000, size=[3.4, 4, 3.4], priority=2, order=20,
         replaces="Taiko drum part in src/night/Arena.luau 306-314"),
    dict(name="wall_segment", build=wall_segment, budget=600, size=[14, 8.8, 2.4], priority=2, order=21,
         replaces="Wall and fence parts in src/night/Arena.luau 224-246 (42 segments)",
         notes="Origin at the wall foot; code sinks walls 1 stud (wall centre y 2, height 6)."),
]
