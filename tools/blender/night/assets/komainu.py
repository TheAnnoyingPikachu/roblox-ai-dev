"""Komainu (seated stone lion-dog). Replaces the generated komainu mesh (src/relay/Models.luau 38-42)
at the entrance, src/night/Arena.luau 638. Sits on the code's own 4 x 2 x 5 plinth."""

import math

import kit as k


def build():
    stone = k.mat("stone", k.STONE, var=0.2, scale=2.5, rgb2=(128, 136, 108))
    dark = k.mat("stone_dark", k.shade(k.STONE, 0.62), var=0.2, scale=2.5)
    bib = k.mat("bib", k.VERMILION, var=0.12, scale=6, kind="wood")
    eye = k.mat("eye", (255, 200, 120), kind="flat", emit=1.2)
    seg, rings = 12, 8
    p = []

    def s(r, loc, scale=(1, 1, 1), m=stone, rot=(0, 0, 0)):
        p.append(k.sphere(r, loc, rot, m=m, scale=scale, seg=seg, rings=rings))

    p.append(k.box((4.4, 6.0, 0.4), (0, 0, 0.2), m=dark, bevel=0.15))
    for side in (-1, 1):
        s(1.3, (side * 1.15, -1.3, 1.6), (1.0, 1.35, 1.0))  # haunch
        s(0.6, (side * 1.4, 0.2, 0.75), (1.0, 1.5, 0.8))  # rear paw
        p.append(k.tube([(side * 0.85, 1.0, 3.6), (side * 0.9, 1.5, 2.0), (side * 0.9, 1.7, 0.7)], [0.62, 0.52, 0.5], m=stone, n=10))
        s(0.55, (side * 0.9, 2.0, 0.65), (1.0, 1.35, 0.75))  # front paw
        for t in (-1, 0, 1):
            s(0.2, (side * 0.9 + t * 0.28, 2.65, 0.55), m=dark)
        s(0.45, (side * 1.25, 0.9, 7.15), (0.7, 0.5, 1.0), rot=(0, side * 25, 0))  # ear
        s(0.36, (side * 0.55, 2.55, 6.75), m=eye)  # bulging eye
        p.append(k.box((0.8, 0.4, 0.3), (side * 0.6, 2.55, 7.2), (0, side * -12, 0), m=dark, bevel=0.1))  # brow
    s(1.0, (0, -0.4, 3.2), (1.5, 1.6, 2.1), rot=(-15, 0, 0))  # torso
    s(1.0, (0, 0.9, 3.9), (1.35, 1.15, 1.45))  # chest
    s(1.0, (0, 1.75, 4.5), (1.35, 0.45, 1.0), m=bib)  # red bib (yodarekake)
    s(1.0, (0, 1.2, 6.3), (1.3, 1.15, 1.15))  # head
    s(1.0, (0, 2.45, 5.95), (0.95, 0.75, 0.62))  # snout
    s(0.32, (0, 3.15, 6.2), m=dark)  # nose
    s(1.0, (0, 2.3, 5.25), (0.8, 0.6, 0.35), m=dark)  # open mouth
    for side in (-1, 1):
        p.append(k.cyl(0.14, 0.5, (side * 0.45, 2.75, 5.45), m=stone, n=6, r2=0.0))  # fangs
    # Curly mane: rings of curls around the head and down the neck.
    for row, (rad, z0, count) in enumerate(((1.55, 6.3, 11), (1.35, 5.0, 9))):
        for i in range(count):
            a = math.pi * (0.05 + 0.9 * i / (count - 1))
            x = math.cos(a) * rad * 1.15
            z = z0 + math.sin(a) * rad * 0.9 - (0.5 if row else 0)
            p.append(k.ico(0.55 - 0.08 * row, (x, 0.3 - 0.3 * row, z), m=stone, subdiv=1))
            p.append(k.ring(0.28, 0, 0.08, dark, n=8, sides=4, centre=(0, 0)))
            p[-1].data.transform(k.move(x, 0.3 - 0.3 * row + 0.5, z) @ k.Matrix.Rotation(math.pi / 2, 4, "X"))
    for i in range(5):
        p.append(k.ico(0.5, (0, -1.0 - i * 0.35, 5.3 - i * 0.6), m=stone, subdiv=1))
    # Flame-like tail rising behind.
    for i, dx in enumerate((-0.6, 0, 0.6)):
        pts = [(dx * 0.6, -2.5, 1.6), (dx, -3.0, 3.0), (dx * 1.3, -2.7, 4.3), (dx * 1.1, -2.1, 5.0), (dx * 0.6, -2.3, 5.4)]
        p.append(k.tube(pts, [0.55, 0.5, 0.42, 0.28, 0.0], m=stone, n=8))
    return p


ASSETS = [
    dict(
        name="komainu",
        build=build,
        budget=3000,
        size=[4.6, 8, 6.4],
        priority=1,
        order=8,
        replaces="komainu mesh (src/relay/Models.luau 38-42) in src/night/Arena.luau 638",
        notes="Code spawns two, yaw 180, on 4 x 2 x 5 plinths; the second could be mirrored.",
    )
]
