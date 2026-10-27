"""Weapons for the run Tool (src/night/Gear.luau SHAPES 19-23, buildTool 76-129). The blade is its
own mesh (<weapon>_blade) so the code can keep tinting it with the Blade Art colour (Neon,
untextured) and keep the trail attachments; the hilt is textured."""

import math

import kit as k

SHAPES = {"katana": (4.2, 1.4), "kodachi": (2.6, 1.0), "nodachi": (6.0, 2.0)}


def weapon(blade_len, grip):
    def build():
        steel = k.mat("steel", (220, 225, 235), var=0.04, scale=8, rgb2=(245, 248, 255))
        wrap = k.mat("wrap", (28, 30, 64), var=0.15, scale=20, kind="wood")
        ray = k.mat("ray", (236, 230, 214), var=0.06, scale=10)
        gold = k.mat("gold", k.GOLD, var=0.12, scale=8)
        ink = k.mat("ink", k.INK, var=0.1)
        hilt = []
        # Grip from z = -grip to 0: rayskin core and a diamond wrap (alternating rings).
        hilt.append(k.cyl(0.15, grip, (0, 0, -grip / 2), m=ray, n=10, rot=(0, 0, 0)))
        steps = max(4, int(grip / 0.22))
        prof = [(0.185 if i % 2 else 0.155, -grip + grip * i / steps) for i in range(steps + 1)]
        wrapped = k.lathe(prof, m=wrap, n=8, scale=(1, 0.8, 1))
        hilt.append(wrapped)
        hilt.append(k.lathe([(0.17, -grip - 0.12), (0.2, -grip - 0.05), (0.19, -grip + 0.05)], m=gold, n=10, scale=(1, 0.8, 1)))
        hilt.append(k.sphere(0.07, (0.17, 0, -grip * 0.45), m=gold, scale=(0.6, 1, 1.6), seg=8, rings=5))
        # Tsuba (oval guard) with a rim, and the habaki collar.
        hilt.append(k.cyl(0.45, 0.08, (0, 0, 0.04), m=gold, n=16))
        hilt[-1].data.transform(k.Matrix.Diagonal((0.68, 1, 1, 1)))
        hilt.append(k.ring(0.43, 0.04, 0.03, ink, n=16, sides=4))
        hilt[-1].data.transform(k.Matrix.Diagonal((0.68, 1, 1, 1)))
        hilt.append(k.box((0.1, 0.34, 0.16), (0, -0.01, 0.16), m=gold, bevel=0.02))
        # Curved blade: outline in y/z, edge at +Y, curving back toward -Y at the tip.
        n = 14
        edge, spine = [], []
        for i in range(n + 1):
            s = i / n
            z = 0.12 + blade_len * s
            bend = -0.22 * (blade_len / 4.2) * s * s
            width = 0.32 - 0.07 * s
            if s > 0.9:
                width *= max(0.0, (1 - s) / 0.1) ** 0.6
            spine.append((bend - 0.16, z))
            edge.append((bend - 0.16 + width, z))
        spine[-1] = edge[-1]
        outline = edge + list(reversed(spine[:-1]))
        blade = k.poly(outline, 0.06, m=steel)
        blade.data.transform(k.Matrix.Rotation(math.radians(90), 4, "Z"))
        return {"": hilt, "blade": [blade]}

    return build


ASSETS = [
    dict(name=name, build=weapon(blade, grip), budget=800, size=[0.9, round(blade + grip + 0.3, 1), 0.6], priority=2, order=22 + i * 0.1,
         replaces=f"{name} Tool parts in src/night/Gear.luau 19-23 and 76-129",
         notes="<name>_blade: set TextureID empty, Material Neon, Color = Blade Art tint; add TrailTop/TrailBottom attachments in code. Origin is the pommel end.")
    for i, (name, (blade, grip)) in enumerate(SHAPES.items())
]
