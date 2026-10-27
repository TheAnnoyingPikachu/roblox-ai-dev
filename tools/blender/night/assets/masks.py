"""Locker masks (src/night/Gear.luau MASKS 134-212), one textured mesh per mask in the cosmetic's
colours (src/shared/NightProgress.luau 80-86). Front faces +Y; origin at the bottom of the mask.

Each mask is a sculpted face shell (a height field over a per-mask outline: brow ridge,
cheekbones, nose, chin), solidified, with eye (and mouth) holes cut by booleans, plus modelled
horns, ears, noses, teeth, brows and side ties. Outline + relief + extras give each its silhouette."""

import math

import bpy

import kit as k

COLOURS = {
    "kitsune": ((255, 255, 255), (220, 40, 40)),
    "tengu": ((200, 30, 30), (20, 20, 20)),
    "oni": ((170, 20, 20), (255, 210, 80)),
    "eclipse": ((20, 0, 30), (255, 140, 0)),
    "okame": ((255, 245, 235), (230, 90, 110)),
    "hannya": ((240, 230, 200), (120, 0, 0)),
}

H = 1.5  # face height (chin to forehead), horns and ears extra
THICK = 0.05
EYE_Z = 0.92


def g(x, z, cx, cz, sx, sz):
    return math.exp(-(((x - cx) / sx) ** 2) - (((z - cz) / sz) ** 2))


def prof(points):
    """Smooth half-width profile through (v, half width) points, v in [0, 1]."""

    def f(v):
        for (v0, w0), (v1, w1) in zip(points, points[1:]):
            if v <= v1:
                t = (v - v0) / (v1 - v0)
                t = t * t * (3 - 2 * t)
                return w0 + (w1 - w0) * t
        return points[-1][1]

    return f


class Face:
    def __init__(self, outline, relief, top_round=0.16, bottom_round=0.06):
        self.outline, self.relief = outline, relief
        self.top_round, self.bottom_round = top_round, bottom_round

    def depth(self, x, z):
        xn = x / 0.66
        return 0.3 * math.sqrt(max(0.0, 1 - xn * xn)) - 0.1 * ((z / H) * 2 - 1) ** 2 + self.relief(x, z)

    def point(self, u, v):
        s = (2 * u - 1) ** 2
        z = v * H - self.top_round * v**4 * s**2 + self.bottom_round * (1 - v) ** 4 * s**2
        x = (2 * u - 1) * self.outline(v)
        return (x, self.depth(x, z), z)

    def on(self, x, z, off=0.0):
        return (x, self.depth(x, z) + THICK / 2 + off, z)

    def shell(self, m):
        ob = k.surface(16, 20, self.point, m=m, thickness=THICK, name="shell")
        k._select([ob])
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        return ob


def almond(cx, cz, w, h, tilt=0.0, low=1.0, n=10):
    """Closed 2D outline (x, z): upper arc h/2, lower arc h/2*low (negative low = crescent)."""
    a = math.radians(tilt)
    pts = [(-w / 2 + w * i / n, h / 2 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    pts += [(w / 2 - w * i / n, -h / 2 * low * math.sin(math.pi * i / n)) for i in range(1, n)]
    return [(cx + px * math.cos(a) - pz * math.sin(a), cz + px * math.sin(a) + pz * math.cos(a)) for px, pz in pts]


def cut(face, shell, outline):
    cx = sum(p[0] for p in outline) / len(outline)
    cz = sum(p[1] for p in outline) / len(outline)
    k.boolean(shell, k.poly(outline, 0.7, loc=(0, face.depth(cx, cz), 0), name="cutter"))


def rim(face, outline, m, r=0.018):
    pts = [face.on(x, z, 0.005) for x, z in outline + outline[:1]]
    return k.tube(pts, r, m=m, n=5, cap=False)


def patch(face, cx, cz, rx, rz, m, off=0.015):
    """Thin paint patch (blush, brow dots) that follows the face surface."""

    def fn(u, v):
        a = 2 * math.pi * u
        x, z = cx + math.cos(a) * rx * v, cz + math.sin(a) * rz * v
        return face.on(x, z, off)

    return k.surface(10, 3, fn, m=m)


def stroke(face, pts2d, radii, m, off=0.0, n=6):
    return k.tube([face.on(x, z, off) for x, z in pts2d], radii, m=m, n=n)


def ties(face, m, v=0.62):
    """Cords leaving both temples, running back and hanging in a tassel."""
    p = []
    for side in (-1, 1):
        x, y, z = face.point(0 if side < 0 else 1, v)
        pts = [(x - side * 0.03, y, z), (x + side * 0.04, y - 0.14, z), (x + side * 0.06, y - 0.28, z - 0.08),
               (x + side * 0.05, y - 0.34, z - 0.28), (x + side * 0.04, y - 0.36, z - 0.45)]
        p.append(k.tube(pts, [0.03, 0.03, 0.028, 0.026, 0.024], m=m, n=6))
        p.append(k.sphere(0.05, (x + side * 0.04, y - 0.36, z - 0.47), m=m, seg=8, rings=5))
        p.append(k.cyl(0.055, 0.16, (x + side * 0.04, y - 0.36, z - 0.6), m=m, n=8, r2=0.025))
    return p


def mask(name):
    base_rgb, accent_rgb = COLOURS[name]

    def build():
        base = k.mat("base", base_rgb, var=0.06, scale=6)
        accent = k.mat("accent", accent_rgb, var=0.05, scale=6)
        glow = k.mat("glow", accent_rgb, kind="flat", emit=2.0)
        hole = k.mat("hole", (8, 6, 10), kind="flat")
        gold = k.mat("gold", (255, 205, 70), var=0.12, scale=8)
        tooth = k.mat("tooth", (250, 245, 230), kind="flat")
        black = k.mat("black", (18, 16, 20), var=0.1, scale=8)
        p = []

        def eyes(face, shell, w, h, tilt, low=1.0, z=EYE_Z, x=0.21, rim_m=None):
            for side in (-1, 1):
                o = almond(side * x, z, w, h, side * tilt, low)
                cut(face, shell, o)
                if rim_m is not None:
                    p.append(rim(face, o, rim_m))

        if name == "kitsune":
            face = Face(
                prof([(0, 0.09), (0.25, 0.24), (0.5, 0.44), (0.72, 0.53), (0.9, 0.48), (1, 0.3)]),
                lambda x, z: 0.3 * g(x, z, 0, 0.42, 0.11, 0.3) + 0.08 * g(x, z, 0, 0.8, 0.08, 0.2)
                + 0.04 * g(abs(x), z, 0.2, 1.06, 0.16, 0.06) + 0.04 * g(abs(x), z, 0.32, 0.68, 0.12, 0.12),
            )
            shell = face.shell(base)
            p.append(shell)
            eyes(face, shell, 0.2, 0.07, 18, rim_m=accent)
            for side in (-1, 1):
                ear = [(side * 0.16, 1.28), (side * 0.48, 1.2), (side * 0.43, 1.78)]
                inner = [(side * 0.23, 1.31), (side * 0.43, 1.27), (side * 0.41, 1.62)]
                if side < 0:
                    ear, inner = ear[::-1], inner[::-1]
                y = face.depth(side * 0.36, 1.35)
                p.append(k.poly(ear, 0.09, loc=(0, y - 0.04, 0), m=base, bevel=0.02))
                p.append(k.poly(inner, 0.04, loc=(0, y + 0.02, 0), m=accent))
                # Flame liner over the eye and cheek stripes.
                p.append(stroke(face, [(side * 0.1, 0.99), (side * 0.22, 1.02), (side * 0.34, 1.07), (side * 0.42, 1.16)], [0.012, 0.02, 0.018, 0.0], accent))
                for dz in (0.0, 0.07):
                    p.append(stroke(face, [(side * 0.22, 0.66 - dz), (side * 0.34, 0.7 - dz), (side * 0.42, 0.76 - dz)], [0.0, 0.016, 0.0], accent))
            p.append(k.sphere(0.07, face.on(0, 1.2, -0.01), m=accent, scale=(0.7, 0.4, 1.3), seg=10, rings=6))
            p.append(k.sphere(0.065, face.on(0, 0.4, -0.02), m=hole, scale=(1.2, 0.9, 0.8), seg=10, rings=6))
            p.append(stroke(face, [(-0.14, 0.24), (-0.06, 0.2), (0, 0.22), (0.06, 0.2), (0.14, 0.24)], 0.012, accent))
            p += ties(face, accent)
        elif name == "tengu":
            face = Face(
                prof([(0, 0.3), (0.18, 0.44), (0.45, 0.52), (0.75, 0.53), (0.92, 0.46), (1, 0.34)]),
                lambda x, z: 0.1 * g(abs(x), z, 0.2, 1.07, 0.17, 0.07) - 0.03 * g(x, z, 0, 1.05, 0.04, 0.1)
                + 0.07 * g(abs(x), z, 0.3, 0.62, 0.12, 0.1) - 0.03 * g(abs(x), z, 0.2, 0.45, 0.04, 0.15)
                + 0.04 * g(x, z, 0, 0.12, 0.15, 0.1) - 0.05 * g(abs(x), z, 0.21, 0.92, 0.1, 0.06),
            )
            shell = face.shell(base)
            p.append(shell)
            eyes(face, shell, 0.16, 0.08, 10, rim_m=gold)
            y0 = face.depth(0, 0.76)
            p.append(k.tube([(0, y0 - 0.05, 0.76), (0, y0 + 0.25, 0.72), (0, y0 + 0.5, 0.74), (0, y0 + 0.7, 0.8), (0, y0 + 0.78, 0.84)],
                            [0.13, 0.1, 0.08, 0.06, 0.0], m=base, n=10))
            for side in (-1, 1):
                p.append(stroke(face, [(side * 0.05, 1.03), (side * 0.14, 1.09), (side * 0.25, 1.14), (side * 0.36, 1.16), (side * 0.45, 1.13)],
                                [0.025, 0.045, 0.05, 0.04, 0.0], accent, 0.015, n=8))
                p.append(stroke(face, [(side * 0.04, 0.6), (side * 0.12, 0.57), (side * 0.2, 0.52), (side * 0.25, 0.44), (side * 0.24, 0.36)],
                                [0.03, 0.035, 0.032, 0.025, 0.0], accent, 0.012, n=8))
            p.append(stroke(face, [(-0.16, 0.28), (0, 0.31), (0.16, 0.28)], 0.02, hole))
            bx, by, bz = face.on(0, 0.14)
            p.append(k.tube([(0, by - 0.04, bz + 0.06), (0, by + 0.02, bz - 0.06), (0, by - 0.02, bz - 0.2)], [0.09, 0.07, 0.0], m=accent, n=8))
            p += ties(face, accent)
        elif name == "oni":
            face = Face(
                prof([(0, 0.4), (0.12, 0.54), (0.35, 0.6), (0.65, 0.58), (0.9, 0.5), (1, 0.36)]),
                lambda x, z: 0.13 * g(abs(x), z, 0.2, 1.08, 0.2, 0.08) - 0.05 * g(x, z, 0, 1.0, 0.05, 0.12)
                + 0.16 * g(x, z, 0, 0.68, 0.12, 0.12) + 0.08 * g(abs(x), z, 0.12, 0.6, 0.07, 0.06)
                + 0.09 * g(abs(x), z, 0.33, 0.7, 0.12, 0.1) - 0.04 * g(x, z, 0, 0.32, 0.25, 0.07)
                + 0.04 * g(x, z, 0, 0.1, 0.25, 0.08),
                top_round=0.1, bottom_round=0.03,
            )
            shell = face.shell(base)
            p.append(shell)
            eyes(face, shell, 0.2, 0.1, 25, rim_m=gold)
            for side in (-1, 1):
                x, y, z = face.on(side * 0.3, 1.36)
                p.append(k.tube([(x, y - 0.06, z), (x + side * 0.12, y - 0.04, z + 0.24), (x + side * 0.1, y - 0.1, z + 0.48), (x + side * 0.02, y - 0.14, z + 0.62)],
                                [0.12, 0.085, 0.05, 0.0], m=gold, n=10))
                band = k.ring(0.13, 0, 0.025, accent, n=12, sides=5)
                band.data.transform(k.move(x, y - 0.04, z + 0.02))
                p.append(band)
                fx, fy, fz = face.on(side * 0.18, 0.25)
                p.append(k.cyl(0.05, 0.24, (fx, fy + 0.02, fz + 0.1), (-10, 0, 0), m=tooth, n=6, r2=0.0))
            p.append(k.sphere(1.0, face.on(0, 0.33, -0.02), m=hole, scale=(0.24, 0.04, 0.08), seg=14, rings=6))
            for i in range(-2, 3):
                p.append(k.box((0.07, 0.05, 0.06), face.on(i * 0.075, 0.39, 0.0), m=tooth, bevel=0.01))
            p += ties(face, gold)
        elif name == "eclipse":
            face = Face(
                prof([(0, 0.22), (0.2, 0.42), (0.5, 0.52), (0.8, 0.5), (1, 0.32)]),
                lambda x, z: 0.04 * g(abs(x), z, 0.2, 1.06, 0.18, 0.07) + 0.07 * g(x, z, 0, 0.7, 0.06, 0.2)
                + 0.04 * g(abs(x), z, 0.3, 0.68, 0.14, 0.12),
                top_round=0.22,
            )
            shell = face.shell(base)
            p.append(shell)
            eyes(face, shell, 0.24, 0.1, 6, low=-0.4, rim_m=glow)
            # Corona: tapered rays around the rim (left side, top, right side), longer at the top.
            cx, cz = 0.0, 0.8
            for i in range(17):
                if i < 8:
                    ex, ey, ez = face.point(0, 0.15 + 0.85 * i / 8)
                elif i == 8:
                    ex, ey, ez = face.point(0.5, 1)
                else:
                    ex, ey, ez = face.point(1, 0.15 + 0.85 * (16 - i) / 8)
                dx, dz = ex - cx, ez - cz
                ln = math.hypot(dx, dz)
                dx, dz = dx / ln, dz / ln
                length = 0.16 + 0.16 * max(0.0, dz) + (0.06 if i % 2 else 0.0)
                bx, bz = ex - dx * 0.05, ez - dz * 0.05
                ray = [(bx - dz * 0.06, bz + dx * 0.06), (bx + dz * 0.06, bz - dx * 0.06), (ex + dx * length, ez + dz * length)]
                p.append(k.poly(ray, 0.04, loc=(0, ey - 0.03, 0), m=glow))
            moon = almond(0, 1.24, 0.22, 0.12, 0, low=-0.5)
            p.append(k.poly(moon, 0.03, loc=(0, face.depth(0, 1.24) + 0.03, 0), m=glow))
            p.append(stroke(face, [(-0.12, 0.3), (0, 0.27), (0.12, 0.3)], 0.014, glow))
            p += ties(face, glow)
        elif name == "okame":
            face = Face(
                prof([(0, 0.28), (0.12, 0.5), (0.32, 0.6), (0.55, 0.54), (0.8, 0.46), (1, 0.3)]),
                lambda x, z: 0.15 * g(abs(x), z, 0.3, 0.45, 0.17, 0.17) + 0.06 * g(x, z, 0, 1.2, 0.3, 0.2)
                + 0.06 * g(x, z, 0, 0.68, 0.05, 0.07) + 0.05 * g(x, z, 0, 0.12, 0.12, 0.08)
                - 0.02 * g(x, z, 0, 0.28, 0.08, 0.05),
                top_round=0.26,
            )
            shell = face.shell(base)
            p.append(shell)
            eyes(face, shell, 0.21, 0.13, -6, low=-0.3, rim_m=black)
            for side in (-1, 1):
                p.append(patch(face, side * 0.17, 1.28, 0.07, 0.04, black))
                p.append(patch(face, side * 0.32, 0.47, 0.13, 0.1, accent))
                p.append(k.sphere(0.03, face.on(side * 0.025, 0.29, 0.0), m=accent, scale=(1.2, 0.8, 0.9), seg=8, rings=5))
            # Black hair along the top edge, parted in the middle.
            for side in (-1, 1):
                hair = [face.point(0.5 + side * t, 0.97 - 0.25 * t * t) for t in (0.02, 0.15, 0.28, 0.4, 0.5)]
                hair = [(x, y + 0.02, z) for x, y, z in hair]
                p.append(k.tube(hair, [0.05, 0.06, 0.055, 0.045, 0.0], m=black, n=8))
            p += ties(face, accent)
        elif name == "hannya":
            face = Face(
                prof([(0, 0.12), (0.15, 0.38), (0.35, 0.56), (0.6, 0.52), (0.85, 0.46), (1, 0.32)]),
                lambda x, z: 0.11 * g(abs(x), z, 0.14, 1.08, 0.14, 0.08) - 0.04 * g(x, z, 0, 1.12, 0.04, 0.12)
                - 0.05 * g(abs(x), z, 0.3, 0.6, 0.1, 0.12) + 0.07 * g(abs(x), z, 0.33, 0.78, 0.1, 0.06)
                + 0.1 * g(x, z, 0, 0.68, 0.06, 0.15) + 0.06 * g(abs(x), z, 0.25, 0.28, 0.12, 0.12),
            )
            shell = face.shell(base)
            p.append(shell)
            eyes(face, shell, 0.18, 0.09, 30, rim_m=gold)
            mouth = almond(0, 0.3, 0.46, 0.12, 0, low=1.6)
            cut(face, shell, mouth)
            p.append(rim(face, mouth, accent, r=0.022))
            for side in (-1, 1):
                x, y, z = face.on(side * 0.24, 1.36)
                p.append(k.tube([(x, y - 0.06, z), (x + side * 0.14, y - 0.14, z + 0.24), (x + side * 0.15, y - 0.2, z + 0.48), (x + side * 0.06, y - 0.14, z + 0.68)],
                                [0.09, 0.07, 0.045, 0.0], m=gold, n=10))
                fx, fy, fz = face.on(side * 0.16, 0.36, -0.01)
                p.append(k.cyl(0.035, 0.16, (fx, fy, fz - 0.04), (180, 0, 0), m=tooth, n=6, r2=0.0))
                fx, fy, fz = face.on(side * 0.19, 0.2, -0.01)
                p.append(k.cyl(0.035, 0.14, (fx, fy, fz + 0.06), m=tooth, n=6, r2=0.0))
                for j in range(3):
                    hx = side * (0.38 + 0.05 * j)
                    p.append(k.tube([face.on(hx, 1.3, -0.01), face.on(hx + side * 0.04, 1.05, -0.02), face.on(hx + side * 0.05, 0.8 - j * 0.06, -0.03)],
                                    [0.03, 0.022, 0.0], m=black, n=5))
            for i in range(-2, 3):
                p.append(k.box((0.055, 0.04, 0.05), face.on(i * 0.055, 0.34, -0.01), m=tooth, bevel=0.01))
            p += ties(face, accent)
        k.apply_cuts()
        return p

    return build


ASSETS = [
    dict(name=f"mask_{name}", build=mask(name), budget=3000, size=[1.3, 1.6, 1.2], priority=3, order=24 + i * 0.1,
         replaces=f"{name} mask parts in src/night/Gear.luau 134-212",
         notes="Colours baked from the cosmetic; neon accents baked bright. Horns, ears and ties add to the size: use size_studs.")
    for i, name in enumerate(COLOURS)
]
