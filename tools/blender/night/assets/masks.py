"""Locker masks (src/night/Gear.luau MASKS 134-212), one textured mesh per mask in the cosmetic's
colours (src/shared/NightProgress.luau 80-86). Front faces +Y; origin at the bottom of the mask.
Code welds it to the head at the same offset it uses now (about 0.62 in front of the head centre)."""

import math

import kit as k

COLOURS = {
    "kitsune": ((255, 255, 255), (220, 40, 40)),
    "tengu": ((200, 30, 30), (20, 20, 20)),
    "oni": ((170, 20, 20), (255, 210, 80)),
    "eclipse": ((20, 0, 30), (255, 140, 0)),
    "okame": ((255, 245, 235), (230, 90, 110)),
    "hannya": ((240, 230, 200), (120, 0, 0)),
}


def face_plate(m, w=0.58, h=0.72, depth=0.36):
    def fn(u, v):
        a = math.radians(-75 + 150 * u)
        b = math.radians(-65 + 140 * v)
        return (math.sin(a) * math.cos(b) * w, math.cos(a) * math.cos(b) * depth, math.sin(b) * h)

    return k.surface(8, 7, fn, m=m, thickness=0.06)


def mask(name):
    base_rgb, accent_rgb = COLOURS[name]

    def build():
        base = k.mat("base", base_rgb, var=0.06, scale=6)
        accent = k.mat("accent", accent_rgb, var=0.05, scale=6)
        glow = k.mat("glow", accent_rgb, kind="flat", emit=2.0)
        hole = k.mat("hole", (8, 6, 10), kind="flat")
        gold = k.mat("gold", (255, 210, 80), var=0.1, scale=8)
        p = [face_plate(base)]

        def eyes(shape=(0.16, 0.06), tilt=12, m=hole, y=0.3, z=0.2):
            for side in (-1, 1):
                p.append(k.box((shape[0], 0.06, shape[1]), (side * 0.2, y, z), (0, side * -tilt, 0), m=m))

        if name == "kitsune":
            for side in (-1, 1):
                p.append(k.poly([(-0.15, 0), (0.15, 0), (0.03, 0.42)], 0.08, loc=(side * 0.33, 0.05, 0.55), rot=(0, side * -18, 0), m=base))
                p.append(k.poly([(-0.08, 0.03), (0.08, 0.03), (0.02, 0.27)], 0.09, loc=(side * 0.33, 0.08, 0.56), rot=(0, side * -18, 0), m=accent))
                p.append(k.box((0.22, 0.03, 0.03), (side * 0.32, 0.3, -0.12), (0, side * 15, 0), m=accent))
            p.append(k.cyl(0.2, 0.45, (0, 0.5, -0.1), (-90, 0, 0), m=base, n=10, r2=0.04))
            p.append(k.sphere(0.06, (0, 0.73, -0.1), m=hole, seg=8, rings=4))
            p.append(k.box((0.3, 0.04, 0.05), (0, 0.33, 0.42), m=glow))
            eyes()
        elif name == "tengu":
            p.append(k.tube([(0, 0.3, 0.0), (0, 0.7, 0.03), (0, 1.0, 0.08)], [0.11, 0.08, 0.04], m=base, n=8))
            for side in (-1, 1):
                p.append(k.box((0.3, 0.08, 0.1), (side * 0.2, 0.3, 0.33), (0, side * 18, 0), m=accent, bevel=0.03))
                p.append(k.sphere(0.06, (side * 0.2, 0.33, 0.2), m=gold, seg=8, rings=5))
            p.append(k.box((0.3, 0.05, 0.04), (0, 0.32, -0.32), m=accent))
        elif name == "oni":
            for side in (-1, 1):
                p.append(k.tube([(side * 0.3, 0.05, 0.5), (side * 0.42, 0.05, 0.75), (side * 0.38, 0.0, 0.95)], [0.09, 0.06, 0.0], m=accent, n=8))
                p.append(k.box((0.28, 0.08, 0.08), (side * 0.2, 0.32, 0.34), (0, side * -25, 0), m=hole))
                p.append(k.cyl(0.04, 0.16, (side * 0.13, 0.33, -0.26), m=k.mat("fang", (250, 245, 230), kind="flat"), n=5, r2=0.0))
            eyes(m=k.mat("eyeglow", accent_rgb, kind="flat", emit=2))
            p.append(k.box((0.38, 0.05, 0.08), (0, 0.32, -0.3), m=accent))
        elif name == "eclipse":
            for z in (0.6, -0.5):
                p.append(k.tube([(x, 0.36 * math.cos(math.asin(min(1, abs(x) / 0.6))) + 0.02, z) for x in (-0.55, -0.3, 0, 0.3, 0.55)], 0.04, m=glow, n=5))
            eyes(shape=(0.24, 0.05), tilt=0, m=glow)
            p.append(k.ring(0.16, 0, 0.03, glow, n=14, sides=4))
            p[-1].data.transform(k.move(0, 0.36, -0.1) @ k.Matrix.Rotation(math.pi / 2, 4, "X"))
        elif name == "okame":
            for side in (-1, 1):
                p.append(k.sphere(0.17, (side * 0.3, 0.2, -0.12), m=base, scale=(1, 0.8, 1), seg=10, rings=6))
                p.append(k.sphere(0.1, (side * 0.32, 0.31, -0.12), m=accent, scale=(1, 0.3, 0.8), seg=10, rings=6))
                p.append(k.sphere(0.04, (side * 0.18, 0.31, 0.5), m=hole, seg=6, rings=4))
            eyes(shape=(0.14, 0.03), tilt=-8, z=0.18)
            p.append(k.sphere(0.06, (0, 0.34, -0.33), m=accent, scale=(1.3, 0.5, 0.8), seg=8, rings=5))
        elif name == "hannya":
            for side in (-1, 1):
                p.append(k.tube([(side * 0.3, 0.0, 0.55), (side * 0.38, -0.1, 0.8), (side * 0.32, -0.25, 1.0)], [0.08, 0.06, 0.0], m=base, n=8))
                p.append(k.box((0.24, 0.07, 0.08), (side * 0.2, 0.31, 0.32), (0, side * 28, 0), m=accent))
            eyes(m=k.mat("eyeglow", (255, 210, 80), kind="flat", emit=2))
            p.append(k.box((0.5, 0.06, 0.16), (0, 0.32, -0.32), m=accent, bevel=0.03))
            for i in range(-2, 3):
                p.append(k.cyl(0.03, 0.08, (i * 0.09, 0.35, -0.26), m=k.mat("teeth", (250, 245, 230), kind="flat"), n=4))
        return p

    return build


ASSETS = [
    dict(name=f"mask_{name}", build=mask(name), budget=600, size=[1.3, 1.6, 1.2], priority=3, order=24 + i * 0.1,
         replaces=f"{name} mask parts in src/night/Gear.luau 134-212",
         notes="Colours baked from the cosmetic; neon accents baked bright.")
    for i, name in enumerate(COLOURS)
]
