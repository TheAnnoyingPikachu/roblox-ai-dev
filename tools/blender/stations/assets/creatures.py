"""Animal Stations creatures as jointed toys, to the Egg Garden creature standard (fused bodies,
the kit eyes, painted skin) but in pieces: a body, a head, four legs and a tail, which the game
joins and animates. Each piece runs on into its neighbour (the neck and the leg tops are hidden
inside the body), so nothing opens up when a joint turns. Facing Blender -Y; the animal's left
is +X.

A variant is the same shapes with another skin. Its glowing pieces are separate `_glow` meshes
that the game sets to Neon.
"""

import math
import random

import kit as k
from mathutils import Matrix, Vector

IVORY = (246, 238, 216)
LAVA = (255, 140, 40)

# Where each piece turns (Blender coordinates, as built). Every piece hangs off the body.
RHINO_JOINTS = {
    "head": (0, -0.9, 2.12),
    "leg_fl": (0.58, -0.45, 1.45),
    "leg_fr": (-0.58, -0.45, 1.45),
    "leg_bl": (0.6, 1.38, 1.45),
    "leg_br": (-0.6, 1.38, 1.45),
    "tail": (0, 2.25, 2.18),
}


def rhino(variant="basic"):
    """A chunky grey rhino: barrel body with two armour folds, a big head with a long muzzle, a
    curved front horn and a small second one, round ears, stubby legs with three nails each, a
    thin tail with a tuft. variant "lava": black rock skin, molten horns and glowing cracks."""
    lava = variant == "lava"
    if lava:
        skin = k.paint(
            "rh_lava",
            [(0, (30, 26, 30)), (0.5, (50, 44, 48)), (1, (72, 62, 64))],
            0,
            3.4,
            rest=True,
            grain=(0.24, 6),
            splat=[((98, 44, 30), 2.4, 0.64, 0.0, 4.0)],
        )
        belly_rgb, fold_rgb, foot_rgb, muzzle_rgb = (86, 58, 50), (18, 16, 20), (22, 20, 24), (78, 62, 60)
        nail = k.flat((255, 140, 50), emit=0.3)  # low: the bake keeps the hue
        iris = (255, 176, 60)
        horn_m = k.glow(LAVA)
    else:
        skin = k.paint(
            "rh_skin",
            [(0, (118, 126, 150)), (0.5, (158, 166, 190)), (1, (190, 197, 218))],
            0,
            3.4,
            rest=True,
            grain=(0.05, 16),
        )
        belly_rgb, fold_rgb, foot_rgb, muzzle_rgb = (208, 212, 228), (116, 122, 148), (104, 110, 134), (198, 204, 224)
        nail = k.flat(IVORY)
        iris = k.EYE_INK
        horn_m = k.paint("rh_horn", [(0, (226, 210, 178)), (1, (252, 246, 230))], 2.1, 3.5)

    # Body ------------------------------------------------------------------------------------
    torso = k.fuse(
        [
            ((0, 0.55, 1.9), 1.12, (1.0, 1.36, 0.98)),  # barrel
            ((0, -0.42, 2.1), 1.0, (1.02, 0.9, 1.0)),  # shoulders, a little higher than the rump
            ((0, 1.42, 1.94), 1.0, (1.0, 0.95, 1.0)),  # rump
            *k.pair((0.76, -0.38, 1.86), 0.6, (0.5, 0.95, 1.05)),  # shoulder plates
            *k.pair((0.78, 1.36, 1.8), 0.6, (0.5, 0.95, 1.05)),  # hip plates
        ],
        skin,
        tris=1900,
        name="torso",
    )
    k.zone(skin, belly_rgb, (0, 0.55, 1.02), (0.85, 1.55, 0.52), soft=0.35)
    for y in (0.12, 1.0):  # the two armour folds round the body
        k.zone(skin, fold_rgb, (0, y, 1.95), (1.5, 0.07, 1.4), soft=0.7)

    # Legs ------------------------------------------------------------------------------------
    def leg(x, y, name):
        foot = (x, y - 0.1, 0.3)
        ob = k.fuse(
            [("capsule", (x, y, 1.5), (x, y - 0.02, 0.5), 0.44), (foot, 0.52, (1.0, 1.15, 0.58))],  # the top stays inside the body
            skin,
            tris=430,
            name=name,
        )
        k.zone(skin, foot_rgb, (x, y - 0.1, 0.1), (0.75, 0.85, 0.34), soft=0.5)
        nails = [
            k.lens(ob, (x, y - 0.1, 0.2), k.outward(a, 0), 0.13, nail, scale=(1.0, 1.1), thick=0.6, sink=0.35, seg=12, name="nail")
            for a in (-38, 0, 38)
        ]
        return [ob, *nails]

    # Head ------------------------------------------------------------------------------------
    hc, R = Vector((0, -1.5, 2.27)), 0.98
    snout = Vector((0, -2.34, 1.9))
    ear = Vector((0.64, -1.22, 3.1))
    skull = k.fuse(
        [
            (tuple(hc), R, (1.0, 1.05, 0.97)),
            ((0, -0.8, 2.1), 0.8, (0.95, 1.0, 0.95)),  # neck, hidden in the body
            (tuple(snout), 0.66, (1.05, 1.25, 0.9)),  # muzzle
            *k.pair((0.44, -1.98, 1.98), 0.5, (0.9, 1.0, 0.9)),  # cheeks
            ((0, -2.7, 1.8), 0.5, (1.18, 0.8, 0.82)),  # broad upper lip
            *k.pair(tuple(ear), 0.28, (0.72, 0.5, 1.3), (0, 16, 0)),  # ears
        ],
        skin,
        tris=2100,
        name="skull",
    )
    k.zone(skin, muzzle_rgb, snout + Vector((0, -0.2, -0.12)), (0.7, 0.6, 0.5), soft=0.35)
    face = []
    for side in (-1, 1):
        face += k.eye(skull, hc, k.outward(side * 46, 6), R * 0.235, iris, wide=0.85, sheen=True)
        face.append(k.lens(skull, snout, k.outward(side * 22, 10), 0.075, k.flat((60, 52, 70)), scale=(1, 1.4), thick=0.4, sink=0.6, seg=12, name="nostril"))
        inner = (86, 40, 34) if lava else (236, 176, 190)
        face.append(k.lens(skull, (side * ear.x, ear.y, ear.z), (side * 0.25, -1, 0.1), 0.15, k.flat(inner), scale=(0.7, 1.25), thick=0.25, sink=0.6, seg=14, name="ear_in"))
        if not lava:
            p, _ = k.land(skull, hc, k.outward(side * 66, -16))
            k.zone(skin, k.mix((176, 182, 204), k.BLUSH_PINK, 0.55), p, (0.24, 0.24, 0.16), soft=0.45)
    face.append(k.mouth(skull, snout, k.outward(0, -36), 0.3, k.flat(k.INKY), "smile"))
    k.texel(face, k.FACE_TEXEL)
    horns = [
        k.horn([(0, -2.56, 2.14), (0, -2.8, 2.66), (0, -2.86, 3.14), (0, -2.74, 3.46)], [0.36, 0.27, 0.15, 0.0], horn_m, name="horn"),
        k.horn([(0, -2.1, 2.72), (0, -2.2, 3.1), (0, -2.17, 3.38)], [0.21, 0.13, 0.0], horn_m, steps=10, name="horn_small"),
    ]

    # Tail ------------------------------------------------------------------------------------
    tail = k.rest(k.horn([(0, 2.25, 2.2), (0, 2.55, 2.02), (0, 2.66, 1.62), (0, 2.64, 1.34)], [0.13, 0.1, 0.085, 0.08], skin, n=10, steps=10, name="tail"))
    tuft = k.blob(0.2, (0, 2.64, 1.24), k.flat((255, 140, 50) if lava else (92, 98, 122), emit=0.3 if lava else 0.0), scale=(0.9, 0.9, 1.25), name="tuft")

    groups = {
        "body": [torso],
        "head": [skull, *face] + ([] if lava else horns),
        "leg_fl": leg(0.58, -0.45, "leg_fl"),
        "leg_fr": leg(-0.58, -0.45, "leg_fr"),
        "leg_bl": leg(0.6, 1.38, "leg_bl"),
        "leg_br": leg(-0.6, 1.38, "leg_br"),
        "tail": [tail, tuft],
    }

    if lava:  # molten horns and jagged glowing cracks, as separate Neon meshes
        rng = random.Random(7)
        glow = k.glow(LAVA)

        def round_body(a, y):  # a: degrees round the body from the top, positive towards +X
            d = Vector((0, 0, 1))
            d.rotate(Matrix.Rotation(math.radians(a), 3, "Y"))
            return (0, min(max(y, -1.1), 2.1), 1.9), d  # stay on the body

        cracks = []
        for side in (-1, 1):
            for y0 in (-0.6, 0.32, 1.2, 1.95):
                y, points = y0, []
                for step in range(7):
                    y += rng.uniform(-0.2, 0.2)
                    points.append(round_body(side * (8 + step * 15 + rng.uniform(-5, 5)), y))
                cracks.append(k.vein(torso, points, 0.05, glow))
                branch = [points[3], round_body(side * 62, y0 + rng.choice((-0.42, 0.42))), round_body(side * 78, y0 + rng.choice((-0.6, 0.6)))]
                cracks.append(k.vein(torso, branch, 0.038, glow))
        cracks.append(k.vein(torso, [round_body(rng.uniform(-6, 6), y) for y in (-0.9, -0.3, 0.3, 0.9, 1.5, 2.1)], 0.055, glow))  # along the spine
        groups["body_glow"] = cracks
        head_cracks = []
        for side in (-1, 1):
            for theta, phi, dt, dp in ((18, 66, 62, -44), (96, 30, 30, -52), (150, 40, -30, -36)):
                points = [(tuple(hc), k.outward(side * (theta + dt * s / 4 + rng.uniform(-6, 6)), phi + dp * s / 4 + rng.uniform(-5, 5))) for s in range(5)]
                head_cracks.append(k.vein(skull, points, 0.042, glow))
        groups["head_glow"] = horns + head_cracks
    return groups


ASSETS = [
    dict(
        name="creature_rhino",
        build=lambda: rhino("basic"),
        budget=10000,
        finalize=k.HD,
        joints=RHINO_JOINTS,
        glow={},
        notes="Jointed: body, head, four legs, tail (Creatures.luau rigs them with Motor6Ds).",
    ),
    dict(
        name="creature_rhino_lava",
        build=lambda: rhino("lava"),
        budget=12500,
        finalize=k.HD,
        joints=RHINO_JOINTS,
        glow={"body_glow": LAVA, "head_glow": LAVA},
        notes="The mythic Lava Rhino: the rhino's shapes with rock skin; horns and cracks are Neon `_glow` meshes.",
    ),
]
