"""Gashadokuro boss: the giant skull and the bone hand (used twice). Replaces the generated
bossSkull and boneHand meshes (src/relay/Models.luau 45-54) in src/night/Enemies.luau 493-548."""

import math

import kit as k
from mathutils import Vector


def skull():
    bone = k.mat("bone", k.BONE, var=0.12, scale=1.2, rgb2=(205, 188, 150))
    socket = k.mat("socket", (30, 10, 16), kind="flat")
    glow = k.mat("glow", k.EMBER, kind="flat", emit=4)
    crack = k.mat("crack", (60, 30, 40), kind="flat")
    tooth = k.mat("tooth", (240, 232, 205), var=0.08, scale=6)
    throat = k.mat("throat", (24, 6, 12), kind="flat", emit=0.4)

    cranium = k.sphere(1.0, (0, -1.0, 14.5), m=bone, scale=(8.2, 9.6, 9.2), seg=32, rings=18)
    k.displace(cranium, 0.35, size=3.0)
    face = k.sphere(1.0, (0, 5.0, 10.2), m=bone, scale=(6.2, 5.0, 4.6), seg=24, rings=12)
    for side in (-1, 1):
        k.boolean(cranium, k.sphere(1.0, (side * 3.4, 8.3, 14.6), m=socket, scale=(2.6, 3.0, 2.9), seg=20, rings=12))
        k.boolean(face, k.sphere(1.0, (side * 3.4, 8.3, 14.6), m=socket, scale=(2.6, 3.0, 2.9), seg=20, rings=12))
    nose = k.poly([(-1.4, 9.6), (1.4, 9.6), (0.3, 12.6), (-0.3, 12.6)], 6, loc=(0, 9.5, 0), m=socket)
    k.boolean(face, nose)
    k.boolean(cranium, nose)
    k.apply_cuts()
    p = [cranium, face]
    for side in (-1, 1):
        p.append(k.sphere(1.0, (side * 5.6, 5.6, 11.6), m=bone, scale=(2.0, 3.0, 1.8), seg=14, rings=8))  # cheekbones
        p.append(k.sphere(1.0, (side * 3.4, 6.2, 14.6), m=socket, scale=(2.2, 1.0, 2.4), seg=14, rings=8))  # socket backs
        p.append(k.sphere(1.0, (side * 3.4, 6.9, 14.4), m=glow, scale=(1.05, 0.6, 1.15), seg=14, rings=8))  # burning eyes
        p.append(k.box((4.6, 2.4, 1.2), (side * 3.4, 8.3, 17.8), (-10, side * -14, 0), m=bone, bevel=0.5))  # brow
    # Upper jaw and lower jaw (mandible), mouth open on a glowing throat.
    p.append(k.sphere(1.0, (0, 7.0, 6.9), m=bone, scale=(5.0, 3.8, 1.6), seg=20, rings=10))
    p.append(k.sphere(1.0, (0, 4.5, 4.9), m=throat, scale=(4.6, 4.2, 2.0), seg=16, rings=8))
    mandible = [(-6.0, -0.5, 8.5), (-6.0, 1.5, 4.5), (-4.6, 5.5, 1.8), (-2.0, 9.2, 1.3), (0, 9.8, 1.3), (2.0, 9.2, 1.3), (4.6, 5.5, 1.8), (6.0, 1.5, 4.5), (6.0, -0.5, 8.5)]
    p.append(k.tube(mandible, [1.0, 1.4, 1.5, 1.6, 1.7, 1.6, 1.5, 1.4, 1.0], m=bone, n=12))
    # Jagged teeth on both jaws, following the jaw arc.
    for i in range(11):
        f = i / 10
        a = math.pi * (0.12 + 0.76 * f)
        x, y = -math.cos(a) * 4.8, 4.0 + math.sin(a) * 5.2
        length = 1.6 + 0.7 * math.sin(i * 2.3) ** 2
        p.append(k.cyl(0.45, length, (x, y, 5.5 - length / 2 + 0.3), (180, 0, 0), m=tooth, n=6, r2=0.0))
        if 1 <= i <= 9:
            lx, ly = -math.cos(a) * 4.5, 3.6 + math.sin(a) * 5.4
            l2 = 1.2 + 0.6 * math.cos(i * 1.7) ** 2
            p.append(k.cyl(0.4, l2, (lx, ly, 2.4 + l2 / 2), m=tooth, n=6, r2=0.0))
    # Cracks across the cranium, painted on as thin dark ridges hugging the surface.
    centre, radii = Vector((0, -1.0, 14.5)), Vector((8.2, 9.6, 9.2))

    def on_skull(theta, phi):
        d = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta)))
        return tuple(centre + Vector((d.x * radii.x, d.y * radii.y, d.z * radii.z)) * 1.02)

    for theta0, phi0, dt, dp in ((0.35, 1.2, 0.09, 0.12), (0.5, 2.4, 0.1, -0.08), (0.7, 0.4, 0.07, 0.1), (0.3, -1.6, 0.1, 0.09)):
        pts = [on_skull(theta0 + dt * j, phi0 + dp * j + 0.08 * math.sin(j * 2.1)) for j in range(7)]
        p.append(k.tube(pts, [0.12, 0.16, 0.14, 0.13, 0.1, 0.07, 0.0], m=crack, n=5))
    return p


def hand():
    bone = k.mat("bone", k.BONE, var=0.12, scale=2.0, rgb2=(205, 188, 150))
    claw = k.mat("claw", (60, 30, 40), var=0.15, scale=4)
    p = []
    for x in (-0.9, 0.9):
        p.append(k.tube([(x, 0, 0), (x * 1.1, 0.1, 2.2), (x, 0, 4.0)], [0.75, 0.6, 0.85], m=bone, n=10))
    for i in range(7):
        a = i / 7 * 2 * math.pi
        p.append(k.ico(0.7, (math.cos(a) * 1.3, math.sin(a) * 0.4, 4.6 + 0.2 * math.sin(a * 2)), m=bone, subdiv=1))
    p.append(k.sphere(1.0, (0, 0, 4.7), m=bone, scale=(1.9, 0.8, 0.9), seg=12, rings=8))

    def finger(base, knuckle, lengths, radii, curl, spread):
        pts = [Vector(base), Vector(knuckle)]
        p.append(k.tube([base, knuckle], [radii[0] * 0.9, radii[0]], m=bone, n=8))
        p.append(k.sphere(radii[0] * 1.25, knuckle, m=bone, seg=10, rings=6))
        direction = (Vector(knuckle) - Vector(base)).normalized()
        here = Vector(knuckle)
        for j, length in enumerate(lengths):
            angle = math.radians(curl[j])
            # Curl forward (+Y) about the finger's side axis.
            side = direction.cross(Vector((0, 1, 0))).normalized()
            direction = (k.Matrix.Rotation(angle, 3, side) @ direction).normalized()
            nxt = here + direction * length
            last = j == len(lengths) - 1
            if last:
                mid = here + direction * length * 0.55 + Vector((0, 0.25, 0))
                p.append(k.tube([tuple(here), tuple(mid), tuple(nxt + Vector((0, 0.5, 0)))], [radii[j + 1], radii[j + 1] * 0.8, 0.0], m=claw, n=8))
            else:
                p.append(k.tube([tuple(here), tuple(nxt)], [radii[j + 1], radii[j + 1] * 0.85], m=bone, n=8))
                p.append(k.sphere(radii[j + 1] * 1.2, tuple(nxt), m=bone, seg=10, rings=6))
            here = nxt

    for i, x in enumerate((-2.9, -1.0, 1.0, 2.9)):
        spread = (i - 1.5) * 0.18
        knuckle = (x * 1.08, 0.3, 9.0 - abs(i - 1.5) * 0.5)
        lengths = [2.4, 1.9, 1.9] if i in (1, 2) else [2.1, 1.7, 1.7]
        finger((x * 0.45, 0, 5.0), knuckle, lengths, [0.6, 0.55, 0.48, 0.44], [12, 22, 26], spread)
    # Thumb out to the side, curling in front of the palm.
    finger((1.5, 0.3, 4.6), (3.6, 1.0, 6.2), [1.9, 1.8], [0.62, 0.55, 0.5], [18, 30], 0)
    return p


ASSETS = [
    dict(name="boss_skull", build=skull, budget=10000, size=[17, 24, 23], priority=1, order=13,
         replaces="bossSkull mesh (src/relay/Models.luau 45-49) in src/night/Enemies.luau 513-536",
         notes="Code eye lights sit at skull centre + (+-3.5, 3, -9); the glowing sockets are at about that spot."),
    dict(name="boss_hand", build=hand, budget=6000, size=[10, 16, 4], priority=1, order=14,
         replaces="boneHand mesh (src/relay/Models.luau 50-54) in src/night/Enemies.luau 537-548 (used twice)",
         notes="Palm faces Roblox -Z, fingers up (+Y), as the old mesh; code turns it palm-down with FLAT."),
]
