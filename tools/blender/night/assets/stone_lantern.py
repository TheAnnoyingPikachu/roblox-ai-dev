"""Stone lantern (Kasuga toro). Replaces Props.lantern (src/relay/Props.luau 152-168)."""

import math

import kit as k


def build():
    stone = k.mat("stone", k.STONE, var=0.2, scale=3)
    dark = k.mat("stone_dark", k.shade(k.STONE, 0.7), var=0.2, scale=3)
    fire = k.mat("fire", k.WARM, kind="flat", emit=3)
    hexa = 6
    parts = [
        k.lathe([(1.45, 0), (1.45, 0.3), (1.15, 0.5), (0.7, 0.62)], m=dark, n=hexa, rot=(0, 0, 30)),
        k.lathe([(0.48, 0.6), (0.4, 0.8), (0.36, 1.7), (0.4, 2.4), (0.5, 2.55)], m=stone, n=10),
        k.lathe([(0.55, 2.5), (1.05, 2.8), (1.05, 3.02), (0.85, 3.08)], m=stone, n=hexa, rot=(0, 0, 30)),
        k.lathe([(0.62, 3.05), (0.62, 4.25)], m=fire, n=hexa, rot=(0, 0, 30)),
        k.lathe([(1.5, 4.2), (1.62, 4.38), (1.25, 4.62), (0.55, 5.05), (0.3, 5.18)], m=dark, n=hexa, rot=(0, 0, 30)),
        k.lathe([(0.22, 5.12), (0.36, 5.32), (0.3, 5.58), (0.12, 5.75), (0, 5.88)], m=stone, n=10),
    ]
    # Firebox frame: corner posts around the glowing core, and a slab under the roof.
    for i in range(hexa):
        a = math.radians(30 + 60 * i)
        parts.append(k.box((0.22, 0.22, 1.2), (math.cos(a) * 0.72, math.sin(a) * 0.72, 3.65), (0, 0, 30 + 60 * i), stone, bevel=0.04))
        # Curled roof corners (warabite).
        c, s = math.cos(a), math.sin(a)
        parts.append(k.tube([(c * 1.45, s * 1.45, 4.42), (c * 1.68, s * 1.68, 4.5), (c * 1.78, s * 1.78, 4.72)], [0.14, 0.12, 0.0], m=dark, n=6))
    parts.append(k.lathe([(0.85, 4.2), (0.85, 4.3)], m=stone, n=hexa, rot=(0, 0, 30)))
    return parts


ASSETS = [
    dict(
        name="stone_lantern",
        build=build,
        budget=1000,
        size=[3, 6, 3],
        priority=1,
        order=5,
        replaces="Props.lantern (src/relay/Props.luau 152-168) via src/night/Arena.luau 639 and 670-687 (16 rim lanterns)",
        notes="Glowing firebox baked bright; keep the PointLight (range 18) in code.",
    )
]
