"""Oni statue: red oni with a studded kanabo club. Replaces the generated oni mesh
(src/relay/Models.luau 13-17): the boss-pit guardians (src/night/Arena.luau 341-344) and the Oni
General's body (src/night/Enemies.luau 367-412)."""

import math

import kit as k
from mathutils import Vector


def build():
    skin = k.mat("skin", (178, 40, 34), var=0.08, scale=1.2)
    dark = k.mat("skin_dark", (110, 22, 22), var=0.15, scale=2)
    tiger = k.mat("tiger", (232, 170, 40), kind="stripes", rgb2=(30, 20, 18), scale=0.7)
    horn = k.mat("horn", k.BONE, var=0.1, scale=4, kind="wood")
    hair = k.mat("hair", k.INK, var=0.2, scale=3)
    gold = k.mat("gold", k.GOLD, var=0.15, scale=6)
    iron = k.mat("iron", (60, 58, 66), var=0.2, scale=3)
    eye = k.mat("eye", (255, 220, 90), kind="flat", emit=3)
    mouth = k.mat("mouth", (40, 6, 10), kind="flat")
    rope = k.mat("rope", k.ROPE, var=0.2, scale=8, kind="wood")
    p = []

    def s(r, loc, scale=(1, 1, 1), m=skin, rot=(0, 0, 0), seg=14, rings=9):
        p.append(k.sphere(r, loc, rot, m=m, scale=scale, seg=seg, rings=rings))

    # Legs in a wide stance.
    for side in (-1, 1):
        s(1.1, (side * 3.4, 0.7, 0.55), (1.15, 1.6, 0.55), m=dark)
        p.append(k.tube([(side * 3.3, 0.1, 0.9), (side * 3.5, -0.1, 3.0), (side * 3.4, 0.1, 4.6)], [1.0, 1.1, 1.25], m=skin, n=12))
        s(1.35, (side * 3.3, 0.2, 4.7), m=skin)
        p.append(k.tube([(side * 3.3, 0.1, 4.8), (side * 2.6, 0, 6.6), (side * 1.9, 0, 7.8)], [1.35, 1.55, 1.6], m=skin, n=12))
        p.append(k.ring(1.15, 1.2, 0.18, gold, n=14, sides=6, centre=(side * 3.35, 0.05)))
    # Tiger-skin loincloth and rope belt.
    p.append(k.lathe([(2.9, 6.0), (3.35, 6.6), (3.35, 7.8), (3.0, 8.7)], m=tiger, n=18, scale=(1, 0.8, 1)))
    p.append(k.ring(3.05, 8.7, 0.3, rope, n=20, sides=6))
    p[-1].data.transform(k.Matrix.Diagonal((1, 0.8, 1, 1)))
    # Torso.
    s(1.0, (0, 0.5, 9.8), (3.1, 2.4, 2.3))
    s(1.0, (0, 0.2, 12.0), (3.7, 2.5, 2.4))
    for side in (-1, 1):
        s(1.0, (side * 1.5, 1.6, 12.3), (1.6, 0.9, 1.2))  # pecs
        s(1.55, (side * 3.9, 0, 12.8))  # shoulders
    # Left arm: fist on the hip.
    p.append(k.tube([(-4.0, 0, 12.6), (-5.3, 0.3, 10.2), (-5.0, 1.0, 8.2)], [1.2, 1.05, 1.0], m=skin, n=12))
    s(1.1, (-4.9, 1.3, 7.6), m=skin)
    p.append(k.ring(0.95, 8.7, 0.22, gold, n=14, sides=6, centre=(-5.05, 0.9)))
    # Right arm raised, holding the club over the shoulder.
    p.append(k.tube([(4.0, 0, 12.6), (5.6, 0.9, 10.6), (5.0, 2.2, 12.4)], [1.2, 1.05, 1.0], m=skin, n=12))
    s(1.05, (4.8, 2.4, 12.9), m=skin)
    p.append(k.ring(0.95, 11.6, 0.22, gold, n=14, sides=6, centre=(5.3, 1.6)))
    a, b = Vector((5.0, 3.6, 11.2)), Vector((3.2, -3.6, 19.4))
    axis = (b - a)
    pts = [a + axis * t for t in (0, 0.15, 0.5, 0.9, 1.0)]
    p.append(k.tube(pts, [0.35, 0.45, 0.85, 1.0, 0.7], m=iron, n=12))
    side_dir = axis.normalized().cross(Vector((1, 0, 0))).normalized()
    up_dir = axis.normalized().cross(side_dir)
    for i in range(14):
        t = 0.35 + 0.6 * (i // 4) / 3 + 0.03 * (i % 2)
        ang = i * 1.6
        r = 0.45 + 0.55 * t
        c = a + axis * t + (side_dir * math.cos(ang) + up_dir * math.sin(ang)) * r
        p.append(k.ico(0.28, tuple(c), m=gold, subdiv=1))
    # Head.
    s(1.0, (0, 0.5, 14.3), (1.6, 1.5, 1.2))  # neck
    s(1.0, (0, 0.7, 15.6), (2.2, 2.0, 2.2), seg=16, rings=10)
    s(1.0, (0, 1.6, 14.6), (1.9, 1.4, 1.0))  # jaw
    p.append(k.box((4.0, 0.9, 0.7), (0, 2.4, 16.4), (-12, 0, 0), m=dark, bevel=0.25))  # brow ridge
    s(0.55, (0, 2.85, 15.4), (1.2, 1, 0.9), m=dark)  # nose
    p.append(k.box((2.2, 0.5, 0.5), (0, 2.85, 14.4), m=mouth, bevel=0.15))
    for side in (-1, 1):
        s(0.48, (side * 0.95, 2.45, 15.9), m=eye)
        p.append(k.cyl(0.24, 0.9, (side * 0.75, 2.95, 14.5), m=horn, n=8, r2=0.0))  # tusks
        pts = [(side * 1.2, 0.5, 17.2), (side * 1.9, 0.4, 18.4), (side * 2.7, 0.0, 19.3), (side * 2.9, -0.3, 20.2)]
        p.append(k.tube(pts, [0.6, 0.45, 0.25, 0.0], m=horn, n=10))
        s(0.6, (side * 2.25, 0.3, 15.8), (0.5, 0.8, 1.0))  # ears
    # Wild hair spikes from the back of the head.
    for i in range(9):
        a = math.radians(-80 + 160 * i / 8)
        base = (math.sin(a) * 1.6, -0.6, 16.4 + math.cos(a) * 0.9)
        tip = (math.sin(a) * 3.2, -2.6, 15.8 + math.cos(a) * 2.0)
        mid = ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2 - 0.2, (base[2] + tip[2]) / 2 + 0.5)
        p.append(k.tube([base, mid, tip], [0.7, 0.45, 0.0], m=hair, n=7))
    return p


ASSETS = [
    dict(
        name="oni_statue",
        build=build,
        budget=8000,
        size=[15, 19, 13],
        priority=1,
        order=7,
        replaces="oni mesh (src/relay/Models.luau 13-17): pit guardians src/night/Arena.luau 341-344 and Oni General body src/night/Enemies.luau 367-412",
        notes="General: code keeps its neon eyes (offset -3.6 z) and chains; recheck the eye offsets against this mesh when wiring.",
    )
]
