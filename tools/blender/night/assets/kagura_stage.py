"""Kagura dance stage (centre). Replaces the part stage in src/night/Arena.luau 251-315."""

import kit as k


def build():
    plank = k.mat("plank", k.DECK, var=0.15, scale=5, kind="wood")
    ramp_m = k.mat("ramp", (140, 98, 66), var=0.15, scale=5, kind="wood")
    ink = k.mat("ink", k.INK, var=0.1)
    red = k.mat("vermilion", k.VERMILION, var=0.1, scale=1.5, kind="wood")
    roof = k.mat("roof", k.ROOF, var=0.25, scale=10, kind="wood")
    rope = k.mat("rope", k.ROPE, var=0.2, scale=8, kind="wood")
    white = k.mat("paper", k.WHITE, kind="flat")
    gold = k.mat("gold", k.GOLD, var=0.15, scale=6)
    p = []
    # Deck on an ink skirt, with plank seams.
    p.append(k.box((32, 32, 3.4), (0, 0, 2.3), m=plank, bevel=0.15))
    p.append(k.box((33, 33, 0.6), (0, 0, 0.3), m=ink, bevel=0.1))
    for i in range(-7, 8):
        p.append(k.box((0.12, 32.02, 0.05), (i * 2, 0, 4.0), m=ink))
    p.append(k.box((32.6, 32.6, 0.3), (0, 0, 3.85), m=red))
    # Ramps on all four sides (8 wide, 10 long, 4 high), rising toward the deck.
    for rot in (0, 90, 180, 270):
        ramp = k.poly([(16, 0), (26, 0), (16, 4)], 8, m=ramp_m)
        ramp.data.transform(k.rot_z(rot))
        p.append(ramp)
    # Pillars with ink footings and gold caps.
    for x in (-15, 15):
        for y in (-15, 15):
            p.append(k.cyl(0.8, 12, (x, y, 10), m=red, n=14))
            p.append(k.cyl(1.0, 0.5, (x, y, 4.25), m=ink, n=14))
            p.append(k.box((2, 2, 0.6), (x, y, 15.8), m=gold, bevel=0.1))
    # Head beams.
    for s in (-15, 15):
        p.append(k.box((31.6, 0.9, 1.0), (0, s, 15.0), m=red))
        p.append(k.box((0.9, 31.6, 1.0), (s, 0, 15.0), m=red))
    # Eaves slab and a gabled hip roof along x.
    p.append(k.box((36, 36, 0.8), (0, 0, 16.4), m=ink, bevel=0.1))
    p += k.hip_roof(19.5, 19.5, 13, 16.9, 22.2, roof, lift=1.4, thickness=0.7, nu=12, nv=6)
    p.append(k.box((27, 1.2, 1.0), (0, 0, 22.5), m=ink, bevel=0.15))
    for side in (-1, 1):
        p.append(k.cyl(0.6, 0.3, (side * 13.6, 0, 22.4), (0, 90, 0), m=gold, n=12))
    # Shimenawa rope with shide front and back.
    for y in (15.8, -15.8):
        p.append(k.rope((-14.6, y, 14.4), (14.6, y, 14.4), 1.4, 0.6, rope, n=10, steps=14))
        for i in range(-2, 3):
            x = i * 5.5
            sag = 1.4 * 4 * (0.5 + x / 29.2) * (0.5 - x / 29.2)
            p.append(k.shide((x, y, 13.8 - sag), 0, white, s=1.0))
    return p


ASSETS = [
    dict(
        name="kagura_stage",
        build=build,
        budget=6000,
        size=[52, 23, 52],
        priority=1,
        order=2,
        replaces="Part stage in src/night/Arena.luau 251-315 (deck, ramps, pillars, roof, rope, shide)",
        notes="Walked on: keep the invisible deck and ramp parts for collision, mesh CanCollide false. Code adds the corner lanterns and the taiko drum.",
    )
]
