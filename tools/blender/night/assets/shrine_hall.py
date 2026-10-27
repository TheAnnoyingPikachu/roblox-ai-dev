"""Shrine main hall (honden). Replaces the generated shrineHall mesh (src/relay/Models.luau 60-64)
spawned in src/night/Arena.luau 347-374. Front (+Y) faces the courtyard."""

import math

import kit as k


def build():
    stone = k.mat("stone", k.STONE, var=0.18, scale=1.2)
    red = k.mat("vermilion", k.VERMILION, var=0.1, scale=1.5, kind="wood")
    wood = k.mat("wood", k.DARKWOOD, var=0.18, scale=3, kind="wood")
    plank = k.mat("plank", k.DECK, var=0.15, scale=4, kind="wood")
    plaster = k.mat("plaster", (226, 218, 200), var=0.06, scale=2)
    paper = k.mat("shoji", (255, 214, 150), kind="flat", emit=1.6)
    roof = k.mat("roof", k.ROOF, var=0.25, scale=10, kind="wood")
    ink = k.mat("ink", k.INK, var=0.1)
    gold = k.mat("gold", k.GOLD, var=0.15, scale=6)
    rope = k.mat("rope", k.ROPE, var=0.2, scale=8, kind="wood")
    white = k.mat("paper", k.WHITE, kind="flat")
    p = []

    # Stone podium and front steps (front is +Y).
    p.append(k.box((34, 28, 2.2), (0, 0, 1.1), m=stone, bevel=0.25))
    for i in range(5):
        p.append(k.box((12, 1.1, 0.44 * (5 - i)), (0, 14 + 0.55 + i * 1.1, 0.22 * (5 - i)), m=stone, bevel=0.08))
    # Raised wooden floor and veranda edge.
    p.append(k.box((30, 24, 0.8), (0, 0, 2.6), m=plank, bevel=0.1))
    p.append(k.box((30.4, 24.4, 0.3), (0, 0, 2.15), m=ink))

    # Pillars on a 5 x 4 grid, and the walls set back inside them.
    xs = [-13, -6.5, 0, 6.5, 13]
    ys = [-10.5, -3.5, 3.5, 10.5]
    for x in xs:
        for y in ys:
            if abs(x) == 13 or abs(y) == 10.5:
                p.append(k.cyl(0.6, 12, (x, y, 9), m=red, n=12))
                p.append(k.cyl(0.8, 0.4, (x, y, 3.2), m=ink, n=12))
    p.append(k.box((24, 18, 9.4), (0, -0.5, 7.7), m=wood, bevel=0.05))
    p.append(k.box((24.2, 18.2, 2.2), (0, -0.5, 13.3), m=plaster))
    # Front: glowing shoji doors with lattice, between the middle pillars.
    for x0 in (-9.75, -3.25, 3.25, 9.75):
        p.append(k.box((5.6, 0.2, 8), (x0, 8.55, 7.3), m=paper))
        for j in range(1, 5):
            p.append(k.box((5.6, 0.18, 0.14), (x0, 8.72, 3.3 + j * 1.6), m=ink))
        for j in range(-2, 3):
            p.append(k.box((0.14, 0.18, 8), (x0 + j * 1.12, 8.72, 7.3), m=ink))
        p.append(k.box((5.8, 0.4, 0.4), (x0, 8.75, 11.4), m=wood))
    # Tie beams (nuki) and the head beam ring, with bracket blocks over each pillar.
    for z, h in ((11.6, 0.6), (14.4, 1.0)):
        for y in (-10.5, 10.5):
            p.append(k.box((27.4, 0.7, h), (0, y, z), m=red))
        for x in (-13, 13):
            p.append(k.box((0.7, 21.4, h), (x, 0, z), m=red))
    for x in xs:
        for y in ys:
            if abs(x) == 13 or abs(y) == 10.5:
                p.append(k.box((1.6, 1.6, 0.7), (x, y, 15.25), m=wood, bevel=0.1))
                p.append(k.box((2.4, 0.8, 0.5), (x, y, 15.8), m=gold, bevel=0.06))
    # Veranda railing on the sides and back.
    for side in (-1, 1):
        p.append(k.box((0.25, 24, 0.25), (side * 15, 0, 4.4), m=red))
        for y in range(-11, 12, 3):
            p.append(k.box((0.3, 0.3, 1.5), (side * 15, y, 3.75), m=red))
    p.append(k.box((30, 0.25, 0.25), (0, -12, 4.4), m=red))

    # Main roof: big curved hip roof with deep eaves; front porch roof (kohai) over the steps.
    p += k.hip_roof(20, 17, 9, 16.2, 29, roof, lift=1.8, thickness=0.9, nu=12, nv=7)
    p.append(k.box((19.5, 1.4, 1.6), (0, 0, 29.4), m=ink, bevel=0.2))
    p.append(k.box((20.2, 0.6, 0.5), (0, 0, 30.2), m=gold))
    # Chigi (crossed boards) at the ridge ends and katsuogi logs along the ridge.
    for side in (-1, 1):
        for lean in (-1, 1):
            p.append(k.box((0.5, 0.35, 6.5), (side * 9.6, lean * 1.0, 31.6), (lean * 32, 0, 0), m=wood, bevel=0.05))
        p.append(k.cyl(0.55, 0.3, (side * 9.7, 1.1, 29.5), (90, 0, 0), m=gold, n=12))
    for x in (-6, -2, 2, 6):
        p.append(k.cyl(0.55, 3.2, (x, 0, 30.6), (90, 0, 0), m=wood, n=10))
        for y in (-1.65, 1.65):
            p.append(k.cyl(0.6, 0.15, (x, y, 30.6), (90, 0, 0), m=gold, n=10))
    # Porch roof: a smaller hip roof whose back edge tucks under the main eaves.
    p += k.hip_roof(8, 4.5, 4.5, 13.6, 17.4, roof, lift=0.9, thickness=0.6, nu=8, nv=4, centre=(0, 16.5))
    for x in (-6, 6):
        p.append(k.cyl(0.45, 11.2, (x, 19.5, 7.6), m=red, n=10))
        p.append(k.cyl(0.65, 0.3, (x, 19.5, 2.15), m=ink, n=10))
    p.append(k.box((13, 0.6, 0.8), (0, 19.5, 13.0), m=red))
    p.append(k.box((13, 0.6, 0.5), (0, 19.5, 11.6), m=red))
    # Shimenawa rope with shide under the porch, and an offering box on the top step.
    p.append(k.rope((-5.6, 19.1, 11.0), (5.6, 19.1, 11.0), 1.2, 0.45, rope, n=10))
    for x in (-3.5, 0, 3.5):
        p.append(k.shide((x, 19.1, 10.4 - (1.2 - 1.2 * (x / 5.6) ** 2)), 0, white, s=0.9))
    p.append(k.box((4, 2, 1.6), (0, 12.6, 3.8), m=wood, bevel=0.1))
    for i in range(6):
        p.append(k.box((3.6, 0.2, 0.15), (0, 11.8 + i * 0.32, 4.65), m=ink))
    return p


ASSETS = [
    dict(
        name="shrine_hall",
        build=build,
        budget=9000,
        size=[40, 39, 42],
        priority=1,
        order=1,
        replaces="shrineHall mesh (src/relay/Models.luau 60-64) in src/night/Arena.luau 347-374",
        notes="Spawn at scale 1 (old mesh used 1.3). Code adds its own hanging lanterns at x +-22.",
    )
]
