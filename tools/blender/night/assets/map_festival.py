"""Map v2 festival dressing (NIGHT-010): nobori banners (red and indigo) for the sando, the stall
row and the wall, and the stacked sake-barrel offering (komodaru) beside the shrine hall and the
stage. New props placed by src/night/Arena.luau; with a nil model id they are simply skipped."""

import math

import kit as k


def _sakura_mon(at, facing, colour, white, size=0.62):
    """White disc with a five-petal sakura crest in `colour`, facing +Y (facing=1) or -Y (-1)."""
    x, y, z = at
    p = [k.cyl(size, 0.04, (x, y, z), (90, 0, 0), m=white, n=16)]
    petal = [(-0.07, 0), (-0.12, 0.14), (-0.06, 0.25), (0, 0.21), (0.06, 0.25), (0.12, 0.14), (0.07, 0)]
    for i in range(5):
        a = 72 * i
        pts = [(px * size * 1.5, (pz + 0.08) * size * 1.5) for px, pz in petal]
        # poly lies in local x/z; spin each petal about the disc normal (y).
        p.append(k.poly(pts, 0.03, loc=(x, y + facing * 0.035, z), rot=(0, a, 0), m=colour))
    p.append(k.cyl(size * 0.12, 0.05, (x, y + facing * 0.04, z), (90, 0, 0), m=white, n=8))
    return p


def nobori(cloth_rgb, trim_rgb):
    def build():
        pole = k.mat("pole", (92, 70, 46), var=0.15, scale=6, kind="wood")
        cloth = k.mat("cloth", cloth_rgb, var=0.08, scale=3)
        trim = k.mat("trim", trim_rgb, var=0.05, scale=6)
        stone = k.mat("stone", k.shade(k.STONE, 0.75), var=0.2, scale=2)
        p = [k.cyl(0.13, 11, (0, 0, 5.5), m=pole, n=8), k.box((1.1, 1.1, 0.7), (0, 0, 0.35), m=stone, bevel=0.08)]
        p.append(k.lathe([(0.2, 11), (0.24, 11.15), (0, 11.5)], m=trim, n=8))
        p.append(k.cyl(0.08, 1.75, (0.85, 0, 10.4), (0, 90, 0), m=pole, n=6))
        # Cloth hanging from the cross pole, with a gentle wave, trim along the free edge and hem.
        x0, x1, z0, z1 = 0.18, 1.62, 2.8, 10.3

        # The ripple fades toward the top so the crest stays flat on the cloth.
        def wave(u, v):
            return (x0 + (x1 - x0) * u, 0.14 * math.sin(v * 6 + 1) * u * (1 - v), z0 + (z1 - z0) * v)

        p.append(k.surface(3, 10, wave, m=cloth, thickness=0.05))
        p.append(k.box((0.16, 0.08, z1 - z0), (x0 + 0.1, 0, (z0 + z1) / 2), m=trim))
        p.append(k.box((x1 - x0, 0.08, 0.3), ((x0 + x1) / 2, 0, z0 + 0.15), m=trim))
        for i in range(7):
            p.append(k.ring(0.2, z0 + 0.4 + i * 1.15, 0.05, trim, n=8, sides=3))
        for side in (1, -1):
            p += _sakura_mon((0.95, side * 0.07, 8.7), side, cloth, trim)
        return p

    return build


def sake_barrels():
    """Komodaru: straw-wrapped sake barrels stacked 5-4-3 on a low stand, coloured labels with crests."""
    straw = k.mat("straw", (200, 174, 116), var=0.2, scale=5, kind="wood")
    rope = k.mat("rope", (120, 92, 56), var=0.15, scale=8, kind="wood")
    lid = k.mat("lid", k.DARKWOOD, var=0.2, scale=4, kind="wood")
    stand = k.mat("stand", k.WOOD, var=0.18, scale=3, kind="wood")
    white = k.mat("white", (240, 236, 226), kind="flat")
    labels = [k.mat("label_red", (200, 40, 40), var=0.05, scale=4), k.mat("label_indigo", (40, 52, 124), var=0.05, scale=4),
              k.mat("label_black", (30, 26, 30), var=0.05, scale=4), k.mat("label_white", (236, 230, 216), var=0.05, scale=4)]
    p = [k.box((9.6, 3.2, 0.5), (0, 0, 0.25), m=stand, bevel=0.06), k.box((7.8, 1.8, 1.7), (0, -0.9, 1.35), m=stand, bevel=0.06)]
    n = 0
    for row, count in enumerate((5, 4, 3)):
        z = 0.5 + row * 1.72
        y = 0.55 - row * 0.75
        for i in range(count):
            x = (i - (count - 1) / 2) * 1.75
            p.append(k.lathe([(0.78, 0), (0.86, 0.5), (0.86, 1.2), (0.78, 1.7)], (x, y, z), m=straw, n=12))
            p.append(k.cyl(0.72, 0.06, (x, y, z + 1.71), m=lid, n=12))
            for rz in (0.28, 1.42):
                p.append(k.ring(0.86, z + rz, 0.06, rope, n=12, sides=3, centre=(x, y)))
            label = labels[n % 4]
            p.append(k.box((1.0, 0.12, 0.95), (x, y + 0.84, z + 0.85), m=label))
            if label is not labels[3]:
                p.append(k.cyl(0.26, 0.04, (x, y + 0.91, z + 0.95), (90, 0, 0), m=white, n=10))
            n += 1
    return p


ASSETS = [
    dict(name="nobori_red", build=nobori((196, 40, 32), (244, 238, 226)), budget=900, size=[2, 11.5, 1.2], priority=4, order=13,
         replaces="New dressing: festival banners on the sando, the stall row and the wall (src/night/Arena.luau banners())",
         notes="Cloth faces -Z (front) with a white sakura crest on both sides; ghosted."),
    dict(name="nobori_indigo", build=nobori((40, 52, 124), (244, 238, 226)), budget=900, size=[2, 11.5, 1.2], priority=4, order=13.1,
         replaces="New dressing: festival banners, indigo variant (src/night/Arena.luau banners())"),
    dict(name="sake_barrels", build=sake_barrels, budget=3200, size=[9.6, 5.7, 3.2], priority=4, order=14,
         replaces="New dressing: komodaru offering stacks beside the shrine hall and the stage (src/night/Arena.luau shrineHall(), stage())"),
]
