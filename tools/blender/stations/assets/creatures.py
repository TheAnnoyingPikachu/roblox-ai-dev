"""Animal Stations creatures: heavy, dangerous-looking beasts (decision 0033), built with the Egg
Garden kit (fused bodies, painted skin, HD bake) but in pieces: a body, a head, four legs and a
tail, which the game joins and animates. Each piece runs on into its neighbour (the neck and the
leg tops are hidden inside the body), so nothing opens up when a joint turns. Facing Blender -Y;
the animal's left is +X.

The look: real proportions rather than toy ones (a small head on a big body, long legs), a heavy
brow over small slanted eyes, a grim mouth, big horns and claws, dark skin with darker creases,
scars. Shapes are written at a handy size and each asset's `scale` makes it its real size: big
animals are big, and a rare variant is bigger than its basic version.

A variant is the same animal with another skin and extra pieces (spikes, more horns). Its glowing
pieces are separate `_glow` meshes that the game sets to Neon.
"""

import math
import random

import kit as k
from mathutils import Matrix, Vector

LAVA = (255, 128, 30)

# Where each piece turns (Blender coordinates, as built, before `scale`). Every piece hangs off
# the body.
RHINO_JOINTS = {
    "head": (0, -1.3, 2.4),
    "leg_fl": (0.72, -0.6, 1.75),
    "leg_fr": (-0.72, -0.6, 1.75),
    "leg_bl": (0.72, 1.55, 1.75),
    "leg_br": (-0.72, 1.55, 1.75),
    "tail": (0, 2.5, 2.45),
}


def shard(base, tip, r, m, name="shard"):
    """A five-sided rock spike from `base` to its point at `tip`."""
    b, t = Vector(base), Vector(tip)
    return k.tube([b, b + (t - b) * 0.45, t], [r, r * 0.74, 0.0], m=m, n=5, name=name)


def rhino(variant="basic"):
    """A war rhino: high shoulders over a deep chest, armour plates, a long low head with a heavy
    brow, a scimitar front horn and a second one behind it, pillar legs with three claws each.
    variant "lava": obsidian skin, molten horns, eyes and cracks, a row of rock spikes down the
    spine and on the shoulders, two more horns over the brow, a burning tail."""
    lava = variant == "lava"
    if lava:
        skin = k.paint(
            "rh_lava",
            [(0, (20, 17, 21)), (0.5, (38, 32, 37)), (1, (58, 50, 55))],
            0,
            3.8,
            rest=True,
            grain=(0.3, 5),
            splat=[((104, 36, 20), 2.2, 0.66, 0.0, 4.6)],
        )
        belly_rgb, fold_rgb, foot_rgb, muzzle_rgb = (64, 36, 30), (8, 7, 10), (12, 10, 13), (26, 22, 26)
        claw = k.flat((255, 120, 36), emit=0.3)  # low: the bake keeps the hue
        iris = LAVA
        horn_m = k.glow(LAVA)
        scar_rgb = None
    else:
        skin = k.paint(
            "rh_skin",
            [(0, (46, 42, 44)), (0.45, (88, 88, 96)), (1, (134, 136, 146))],
            0,
            3.8,
            rest=True,
            grain=(0.16, 8),
            splat=[((72, 62, 56), 3.0, 0.6, 0.0, 1.7)],  # dried mud up the legs and belly
        )
        belly_rgb, fold_rgb, foot_rgb, muzzle_rgb = (74, 66, 64), (34, 33, 40), (40, 37, 40), (60, 58, 66)
        claw = k.flat((196, 182, 156))
        iris = (236, 164, 36)
        horn_m = k.paint(
            "rh_horn",
            [(0, (62, 52, 46)), (0.3, (150, 130, 102)), (1, (238, 228, 204))],
            2.2,
            4.2,
            rest=True,
            grain=(0.1, 14, "wave"),
        )
        scar_rgb = (176, 160, 160)
    ink = k.flat((16, 13, 18))

    # Body ------------------------------------------------------------------------------------
    torso = k.fuse(
        [
            ((0, -0.6, 2.15), 1.2, (1.0, 1.0, 1.05)),  # chest and shoulders
            ((0, -0.45, 3.05), 0.7, (0.75, 1.2, 0.75)),  # the hump over the shoulders
            ((0, 0.55, 2.1), 1.1, (0.98, 1.3, 0.96)),  # barrel
            ((0, 1.6, 2.15), 1.02, (1.0, 0.95, 1.0)),  # rump
            *k.pair((0.86, -0.6, 2.25), 0.74, (0.5, 1.0, 1.15)),  # shoulder plates
            *k.pair((0.84, 1.55, 2.05), 0.68, (0.5, 0.95, 1.1)),  # hip plates
        ],
        skin,
        tris=2600,
        soft=0.22,
        name="torso",
    )
    k.zone(skin, belly_rgb, (0, 0.4, 1.0), (0.9, 1.9, 0.5), soft=0.4)
    for y in (-1.6, 0.22, 0.98):  # creases: behind the head, behind the shoulder plate, before the hip
        k.zone(skin, fold_rgb, (0, y, 2.2), (1.7, 0.06, 1.7), soft=0.8)

    # Legs ------------------------------------------------------------------------------------
    def leg(x, y, name):
        knee, foot = (x, y - 0.06, 1.0), Vector((x, y - 0.14, 0.27))
        ob = k.fuse(
            [
                ("capsule", (x, y, 1.9), knee, 0.5),  # the top stays inside the body
                (knee, 0.52, (1.0, 1.0, 0.85)),
                ("capsule", knee, (x, y - 0.08, 0.45), 0.4),
                (tuple(foot), 0.5, (0.95, 1.12, 0.52)),
            ],
            skin,
            tris=560,
            soft=0.22,
            name=name,
        )
        k.zone(skin, foot_rgb, (x, y - 0.1, 0.1), (0.85, 0.95, 0.42), soft=0.5)
        claws = []
        for a in (-40, 0, 40):  # three claws curving forward and down to the ground
            d = k.outward(a, 0)
            base = foot + d * 0.36
            claws.append(k.horn([base, base + d * 0.24 - Vector((0, 0, 0.06)), base + d * 0.36 - Vector((0, 0, 0.24))], [0.15, 0.11, 0.0], claw, n=8, steps=6, name="claw"))
        return [ob, *claws]

    # Head ------------------------------------------------------------------------------------
    hc, R = Vector((0, -2.05, 2.2)), 0.7
    snout = Vector((0, -2.95, 1.92))
    ear = Vector((0.5, -1.62, 2.92))
    skull = k.fuse(
        [
            (tuple(hc), R, (0.95, 1.15, 0.98)),
            ((0, -1.35, 2.35), 0.85, (0.95, 1.0, 0.95)),  # neck, hidden in the body
            (tuple(snout), 0.5, (1.0, 1.5, 0.86)),  # long muzzle
            ((0, -3.5, 1.8), 0.42, (1.15, 0.8, 0.85)),  # square upper lip
            ((0, -2.5, 1.62), 0.46, (0.95, 1.5, 0.7)),  # jaw
            ((0, -3.05, 2.22), 0.34, (0.9, 1.1, 0.7)),  # horn boss
            *k.pair((0.4, -2.32, 2.7), 0.27, (0.9, 1.5, 0.5), (18, 0, 0)),  # brow ridges, lower at the front
            *k.pair((0.5, -2.2, 2.05), 0.4, (0.8, 1.0, 0.9)),  # cheekbones
            *k.pair(tuple(ear), 0.24, (0.55, 0.45, 2.0), (-32, 20, 0)),  # ears, swept back
        ],
        skin,
        tris=2600,
        soft=0.22,
        name="skull",
    )
    k.zone(skin, muzzle_rgb, snout + Vector((0, -0.45, -0.1)), (0.7, 0.7, 0.6), soft=0.4)
    face, eyes = [], []
    slant = (0, -0.42, 1)  # eyes lower at the front: a scowl
    for side in (-1, 1):
        d = k.outward(side * 60, 17)
        p, n = k.land(skull, hc, d)
        k.zone(skin, fold_rgb, p, (0.3, 0.36, 0.24), soft=0.5)  # dark socket
        dome = k.lens(skull, hc, d, 0.125, k.flat(iris, emit=0.3 if lava else 0.0), scale=(1.3, 0.78), thick=0.5, sink=0.5, up=slant, seg=16, name="eye")
        if lava:
            eyes.append(dome)  # all glow, no pupil
        else:
            face.append(dome)
            face.append(k.lens(dome, p, n, 0.06, ink, scale=(0.62, 1.0), thick=0.3, sink=0.4, up=slant, seg=12, name="pupil"))
        face.append(k.lens(skull, snout + Vector((0, -0.5, -0.1)), k.outward(side * 30, 12), 0.07, ink, scale=(1, 1.4), thick=0.4, sink=0.6, seg=12, name="nostril"))
        face.append(k.lens(skull, (side * ear.x, ear.y, ear.z), (side * 0.6, -1, 0.1), 0.075, ink, scale=(0.7, 1.8), thick=0.25, sink=0.6, seg=12, name="ear_in"))
    # a grim mouth: along both sides of the muzzle and across the lip, corners turned down
    line = [((0, y, z), (side, 0, -0.2)) for side, pts in ((-1, ((-2.5, 1.56), (-2.85, 1.64))), (1, ((-2.85, 1.64), (-2.5, 1.56)))) for y, z in pts]
    line[2:2] = [((0, -3.2, 1.7), k.outward(a, -6)) for a in (-75, -45, -15, 15, 45, 75)]
    face.append(k.vein(skull, line, 0.04, ink, name="mouth"))
    if scar_rgb:  # an old cut down through the right brow
        cut = [(tuple(hc), k.outward(-60 + 5 * i, 44 - 13 * i)) for i in range(5)]
        face.append(k.vein(skull, cut, 0.028, k.flat(scar_rgb), name="scar"))
    k.texel(face, k.FACE_TEXEL)
    grow = 1.15 if lava else 1.0
    horns = k.rest(
        [
            k.horn([(0, -3.05, 2.2), (0, -3.42, 2.95), (0, -3.4, 3.65), (0, -3.02, 4.2 * grow)], [0.36 * grow, 0.28 * grow, 0.16, 0.0], horn_m, name="horn"),
            k.horn([(0, -2.62, 2.6), (0, -2.76, 3.12), (0, -2.6, 3.55 * grow)], [0.22 * grow, 0.14, 0.0], horn_m, steps=10, name="horn_small"),
        ]
    )

    # Tail ------------------------------------------------------------------------------------
    tail = k.rest(k.horn([(0, 2.5, 2.45), (0, 2.85, 2.25), (0, 2.98, 1.75), (0, 2.95, 1.35)], [0.15, 0.11, 0.09, 0.085], skin, n=10, steps=10, name="tail"))
    if lava:  # a flame for a tuft
        tuft = k.horn([(0, 2.95, 1.45), (0, 3.0, 1.18), (0, 2.97, 0.82), (0, 2.82, 0.4)], [0.08, 0.27, 0.16, 0.0], horn_m, n=12, steps=12, name="flame")
    else:
        tuft = k.blob(0.2, (0, 2.95, 1.2), k.flat((30, 28, 34)), scale=(0.85, 0.85, 1.5), name="tuft")

    groups = {
        "body": [torso],
        "head": [skull, *face] + ([] if lava else horns),
        "leg_fl": leg(0.72, -0.6, "leg_fl"),
        "leg_fr": leg(-0.72, -0.6, "leg_fr"),
        "leg_bl": leg(0.72, 1.55, "leg_bl"),
        "leg_br": leg(-0.72, 1.55, "leg_br"),
        "tail": [tail] if lava else [tail, tuft],
    }

    def round_body(a, y):  # a: degrees round the body from the top, positive towards +X
        d = Vector((0, 0, 1))
        d.rotate(Matrix.Rotation(math.radians(a), 3, "Y"))
        return (0, min(max(y, -1.45), 2.3), 2.15), d  # stay on the body

    if not lava:  # a row of bone studs over the shoulders
        for i, h in enumerate((0.3, 0.42, 0.36, 0.26)):
            p, _ = k.land(torso, *round_body(0, -1.05 + 0.42 * i))
            lean = Vector((0, 0.5, 1)).normalized()
            groups["body"].append(k.rest(k.horn([p - lean * 0.15, p + lean * h * 0.6, p + lean * h], [0.17, 0.11, 0.0], horn_m, n=8, steps=6, name="stud")))
    if scar_rgb:  # three claw marks across the left shoulder plate
        scar = k.flat(scar_rgb)
        for i in range(3):
            marks = [round_body(34 + 12 * t, -1.0 + 0.27 * i + 0.1 * t) for t in range(4)]
            groups["body"].append(k.vein(torso, marks, 0.03, scar, name="scar"))

    if lava:
        rng = random.Random(7)
        glow = k.glow(LAVA)
        rock = k.flat((22, 18, 24))

        # obsidian spikes down the spine, tallest over the shoulders, a molten one between each
        spikes, molten = [], []
        heights = (0.95, 1.3, 1.1, 0.85, 0.72, 0.62, 0.5, 0.4)
        for i, h in enumerate(heights):
            y = -1.2 + 0.47 * i
            p, _ = k.land(torso, *round_body(0, y))
            lean = Vector((rng.uniform(-0.1, 0.1), 0.42, 1)).normalized()
            spikes.append(shard(p - lean * 0.25, p + lean * h, 0.12 + h * 0.19, rock))
            q, _ = k.land(torso, *round_body(rng.choice((-9, 9)), y + 0.24))
            molten.append(shard(q - lean * 0.2, q + lean * h * 0.5, 0.07 + h * 0.08, glow))
        # and three on each shoulder plate, fanned out
        for side in (-1, 1):
            for a, y, h in ((30, -0.95, 0.85), (46, -0.5, 1.05), (60, -0.1, 0.7)):
                p, n = k.land(torso, *round_body(side * a, y))
                out = (n + Vector((0, 0.35, 0.5))).normalized()
                spikes.append(shard(p - out * 0.25, p + out * h, 0.11 + h * 0.17, rock))
        groups["body"] += spikes

        # jagged glowing cracks round the body and along the spine
        cracks = []
        for side in (-1, 1):
            for y0 in (-0.95, -0.1, 0.72, 1.5, 2.15):
                y, points = y0, []
                for step in range(7):
                    y += rng.uniform(-0.2, 0.2)
                    points.append(round_body(side * (14 + step * 15 + rng.uniform(-5, 5)), y))
                cracks.append(k.vein(torso, points, 0.055, glow))
                branch = [points[3], round_body(side * 70, y0 + rng.choice((-0.42, 0.42))), round_body(side * 88, y0 + rng.choice((-0.6, 0.6)))]
                cracks.append(k.vein(torso, branch, 0.04, glow))
        groups["body_glow"] = cracks + molten

        head_cracks = []
        for side in (-1, 1):
            for theta, phi, dt, dp in ((24, 62, 56, -40), (100, 34, 30, -50), (150, 44, -30, -36)):
                points = [(tuple(hc), k.outward(side * (theta + dt * s / 4 + rng.uniform(-6, 6)), phi + dp * s / 4 + rng.uniform(-5, 5))) for s in range(5)]
                head_cracks.append(k.vein(skull, points, 0.042, glow))
            # a crown: a rock horn sweeping back over each brow
            groups["head"].append(k.horn([(side * 0.42, -2.25, 2.72), (side * 0.66, -1.98, 3.3), (side * 0.7, -1.5, 3.72)], [0.17, 0.11, 0.0], rock, n=8, steps=8, name="brow_horn"))
        groups["head_glow"] = horns + eyes + head_cracks
        groups["tail_glow"] = [tuft]
    return groups


ASSETS = [
    dict(
        name="creature_rhino",
        build=lambda: rhino("basic"),
        scale=2.0,
        budget=13000,
        finalize=k.HD,
        joints=RHINO_JOINTS,
        glow={},
        notes="Jointed: body, head, four legs, tail (Creatures.luau rigs them with Motor6Ds).",
    ),
    dict(
        name="creature_rhino_lava",
        build=lambda: rhino("lava"),
        scale=2.6,
        budget=17000,
        finalize=k.HD,
        joints=RHINO_JOINTS,
        glow={"body_glow": LAVA, "head_glow": LAVA, "tail_glow": LAVA},
        notes="The mythic Lava Rhino, 1.3 times the Rhino: obsidian skin and spikes; horns, eyes, cracks and tail flame are Neon `_glow` meshes.",
    ),
]
