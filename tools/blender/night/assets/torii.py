"""Torii gates: the vermilion entrance torii (Props.torii, src/relay/Props.luau 105-149, called
from src/night/Arena.luau 635) and the black demon gates (src/night/Arena.luau 587-613)."""

import math

import kit as k


def kasagi(width, z, thick, depth, sweep, m):
    """Top beam with upswept ends: an extruded x/z outline."""
    n = 16
    half = width / 2
    top, bottom = [], []
    for i in range(n + 1):
        x = -half + width * i / n
        lift = sweep * (abs(x) / half) ** 3
        top.append((x, z + thick + lift + 0.15 * (abs(x) / half) ** 2))
        bottom.append((x, z + lift))
    pts = bottom + list(reversed(top))
    return k.poly(pts, depth, m=m, bevel=0.0)


def gate(width, height, pillar_m, beam_m, cap_m, foot_m, pillar_r=0.8):
    p = []
    for side in (-1, 1):
        x = side * width / 2
        p.append(k.lathe([(pillar_r * 1.08, 0.9), (pillar_r * 0.95, height * 0.5), (pillar_r * 0.9, height)], (x, 0, 0), m=pillar_m, n=16))
        p.append(k.lathe([(pillar_r * 1.65, 0), (pillar_r * 1.65, 0.7), (pillar_r * 1.25, 1.1)], (x, 0, 0), m=foot_m, n=16))
    # Nuki tie beam passing through both pillars, with wedges.
    p.append(k.box((width + 3, 0.7, 0.9), (0, 0, height - 2.6), m=beam_m, bevel=0.05))
    for side in (-1, 1):
        p.append(k.box((0.3, 0.9, 0.5), (side * (width / 2 + 1.0), 0, height - 2.6), m=cap_m))
    # Shimaki and kasagi, with a central strut (gakuzuka) for the plaque.
    p.append(kasagi(width + 5, height - 0.3, 0.9, 1.4, 0.5, beam_m))
    p.append(kasagi(width + 6.2, height + 0.6, 0.65, 1.8, 0.75, cap_m))
    p.append(k.box((0.7, 0.6, 2.4), (0, 0, height - 1.3), m=beam_m))
    return p


def entrance():
    red = k.mat("vermilion", k.VERMILION, var=0.1, scale=1.5, kind="wood")
    ink = k.mat("ink", k.INK, var=0.12, scale=3)
    stone = k.mat("stone", k.shade(k.STONE, 0.6), var=0.2, scale=3)
    return gate(18, 16, red, red, ink, stone)


def demon():
    charred = k.mat("charred", k.INK, var=0.35, scale=4)
    cap = k.mat("ink", (12, 10, 16), var=0.2, scale=3)
    stone = k.mat("stone", k.shade(k.SLATE, 0.6), var=0.2, scale=3)
    paper = k.mat("ofuda", (236, 222, 190), var=0.08, scale=6)
    seal = k.mat("seal", k.EMBER, kind="flat", emit=1.0)
    neon = k.mat("neon", k.PURPLE, kind="flat", emit=4.0)
    p = gate(12, 14, charred, charred, cap, stone, pillar_r=0.9)
    # Torn ofuda talismans hanging from the nuki, each with a red seal.
    for i, x in enumerate((-4.5, -1.5, 1.8, 4.6)):
        drop = 1.6 + 0.4 * (i % 2)
        p.append(k.box((0.7, 0.04, drop), (x, -0.5, 14 - 2.6 - 0.45 - drop / 2), (0, 0, 8 * (i - 1.5)), m=paper))
        p.append(k.box((0.35, 0.05, 0.35), (x, -0.53, 14 - 2.6 - 0.45 - drop * 0.45), (0, 0, 8 * (i - 1.5)), m=seal))
    # Cracks: thin dark grooves wrapping the pillars.
    crack = k.mat("crack", (40, 10, 60), kind="flat", emit=1.5)
    for side in (-1, 1):
        x = side * 6
        pts = [(x + 0.92 * math.cos(a), 0.92 * math.sin(a), 2 + 1.6 * j) for j, a in enumerate([0.3, 0.9, 0.5, 1.2, 0.8, 1.4])]
        p.append(k.tube(pts, 0.07, m=crack, n=4))
    # Neon strips on the front faces (+Y = toward the courtyard), exported as their own mesh.
    glow = []
    for side in (-1, 1):
        glow.append(k.box((0.3, 0.3, 12), (side * 6, 0.95, 7), m=neon))
    glow.append(k.box((18, 0.2, 0.2), (0, 0.95, 13.7), m=neon))
    return {"": p, "glow": glow}


ASSETS = [
    dict(
        name="entrance_torii",
        build=entrance,
        budget=2000,
        size=[24, 17.5, 2.4],
        priority=1,
        order=4,
        replaces="Props.torii (src/relay/Props.luau 105-149) via src/night/Arena.luau 635",
        notes="Plaque with the 百鬼夜行 text stays a part with SurfaceGuis at height 14.8.",
    ),
    dict(
        name="demon_gate",
        build=demon,
        budget=2000,
        size=[19, 15.5, 2],
        priority=1,
        order=3,
        replaces="Demon gate parts in src/night/Arena.luau 587-613 (x4)",
        notes="demon_gate_glow is the neon strips: set Material Neon, Color purple. Portal disc, floor glow and particles stay parts.",
    ),
]
