"""Egg Garden v0.4 art (GARDEN-031, docs/architecture/garden.md 9.2): the Lantern Moth, the Starlit
fence post and rail, and the Clover Pads decal. The moth follows the README "Creature standard" (one
mesh, stands on the origin facing -Y); its lantern is baked bright, no Neon."""

import importlib.util
import math
import os
import sys

import kit as k
from mathutils import Matrix, Vector

_spec = importlib.util.spec_from_file_location("creatures_b", os.path.join(os.path.dirname(os.path.abspath(__file__)), "creatures_b.py"))
cb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cb)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creatures_a import petal, xf  # noqa: E402
from v05_exclusives import paddle, settle  # noqa: E402

NAVY = (40, 45, 100)
STARLIGHT = (235, 230, 255)


# Lantern Moth (rare, V2.4) --------------------------------------------------------------------


MOTH_SIZE = [3.9, 3.2, 1.6]


def creature_moth():
    """Remade from the Roblox AI reference (assets/garden/refs/moth_*.jpg): a fluffy cream moth
    with a big round head, huge glossy plum eyes, a tiny cream snout, a scalloped frill collar,
    tall pink feather antennae, rounded orange wings with white spots, and a small glowing lantern
    hanging from each hand (the "Lantern Moth"). The lanterns are baked bright, no Neon."""
    fluff = k.paint("mo_fluff", [(0, (214, 192, 162)), (0.45, (236, 222, 198)), (1, (250, 242, 226))], 0, 3.0, rest=True, grain=(0.08, 26))
    head, R = Vector((0, 0, 2.0)), 0.86
    hand = Vector((0.82, -0.4, 1.0))
    body = k.fuse(
        [
            (head, R, (1.1, 1.0, 0.95)),
            ((0, -0.88, 1.78), 0.13, (1.1, 1.2, 0.85)),  # tiny snout
            ((0, 0.06, 0.88), 0.6, (1.05, 1.0, 1.1)),  # body
            ((0, 0.08, 0.42), 0.62, (1.15, 1.08, 0.62)),  # round seat
            *[("capsule", (s * 0.45, -0.1, 1.1), (s * hand.x, hand.y, hand.z), 0.14) for s in (-1, 1)],  # arms out to the lanterns
            *k.pair(tuple(hand), 0.15),
        ],
        fluff,
        tris=1950,
        soft=0.25,
    )
    parts = [body]

    def frill(u, v):  # a scalloped collar round the neck, twelve soft points
        a = 2 * math.pi * u
        wave = (0.5 + 0.5 * math.cos(12 * a)) ** 2
        r = 0.4 + v * (0.34 + 0.12 * wave * v)
        return (r * math.sin(a), 0.05 - r * math.cos(a), 1.42 - v * (0.32 + 0.1 * wave))

    collar = k.rest(k.surface(60, 2, frill, m=k.paint("mo_frill", [(0, (226, 210, 186)), (1, (252, 246, 234))], 1.0, 1.42, rest=True), thickness=0.05, name="collar"))
    parts.append(collar)
    # Rounded orange wings spread at the sides: a big forewing and a smaller hindwing.
    for s in (-1, 1):
        for length, width, rise, sweep, z in ((2.0, 0.58, 14, -4, 1.12), (1.5, 0.46, -14, 4, 0.78)):
            e = math.radians(rise)
            frame = Matrix.Translation((0.45, 0.22, z)) @ k.rot_z(sweep) @ Matrix(((math.cos(e), -math.sin(e), 0), (0, 0, -1), (math.sin(e), math.cos(e), 0))).to_4x4()
            w = k.rest(paddle(length, width, None, thick=0.14, n=10, root=0.4, name="wing"))
            spots = [((250, 238, 222), (length * u, width * v, 0), 0, r) for u, v, r in ((0.62, 0.2, 0.24 * width), (0.42, -0.3, 0.18 * width))]
            w.data.materials.append(k.paint(f"mo_wing_{length}", [(0, (206, 100, 40)), (0.45, (232, 136, 70)), (0.85, (244, 176, 120)), (1, (226, 128, 66))], 0, length, axis="X", rest=True, marks=spots))
            if s < 0:
                frame = Matrix.Diagonal((-1, 1, 1, 1)) @ frame
            w.data.transform(frame)
            parts += k.texel([w], 0.6)
    # Lanterns hanging from the hands: a cream glass body between dark caps, glowing.
    rim, glass = k.flat((140, 100, 72)), k.flat((255, 234, 186), emit=0.3)
    for s in (-1, 1):
        x, y, z = s * hand.x, hand.y - 0.05, hand.z - 0.6
        parts += [k.lathe([(0.1, 0.02), (0.15, 0.06), (0.16, 0.2), (0.15, 0.34), (0.1, 0.38)], loc=(x, y, z), m=glass, n=16, name="lantern"),
                  k.lathe([(0, 0), (0.12, 0), (0.13, 0.04), (0, 0.05)], loc=(x, y, z - 0.02), m=rim, n=16, name="cap"),
                  k.lathe([(0, 0.37), (0.12, 0.37), (0.13, 0.41), (0, 0.46)], loc=(x, y, z), m=rim, n=16, name="cap"),
                  k.capsule((x, y, z + 0.44), (x, y, hand.z - 0.1), 0.02, 0.02, rim, n=6, name="bail")]
    # Tall pink feather antennae, a short quill then a broad plume, leaning out.
    pink = k.paint("mo_plume", [(0, (222, 146, 146)), (1, (248, 200, 196))], 2.7, 4.0)
    for s in (-1, 1):
        root = Vector((s * 0.32, -0.02, 2.7))
        plume = petal(1.5, 0.36, pink, droop=-0.14, tip=0.7, base=0.35, n=8, steps=10, flat=0.18, name="plume")
        plume.data.transform(Matrix.Translation((0.1, 0, 0)))
        quill = k.tube([(-0.12, 0, 0), (0.5, 0, 0.02), (1.25, 0, -0.06)], [0.035, 0.028, 0.012], m=k.flat((250, 226, 222)), n=6, name="quill")
        parts += xf([plume, quill], root, yaw=-8, pitch=50, roll=90, mirror=s < 0)
    parts += k.face(body, head, R, skin=(246, 234, 214), iris=(56, 28, 62), nose=None, mouth_kind=None, eye_r=0.29, eye_wide=0.9, spread=31, eye_phi=-10, sheen=True, blush_theta=48, blush_phi=-28)
    settle(parts, MOTH_SIZE)
    return parts


# Starlit fence (V4 milestone 60) --------------------------------------------------------------


def _starry(name, lo, hi):
    return k.paint(name, [(0, NAVY), (1, (75, 70, 160))], lo, hi, dots=[(STARLIGHT, 7, 0.09)])


def fence_starlit_post():
    pale = k.flat(STARLIGHT, emit=0.5)
    parts = [k.box((0.88, 0.88, 3.3), (0, 0, 1.65), m=_starry("fs_post", 0, 3.6), bevel=0.1, seg=2, name="post")]
    parts.append(k.lathe([(0.5, 3.3), (0.32, 3.45), (0.1, 3.5)], m=k.flat(NAVY), n=10, name="cap"))
    # Star finial facing the front, and a small star gem on each face.
    parts += cb.aim(k.star(0.42, pale, inner=0.48, depth=0.14), (0, 0, 3.52), (0, -1, 0))
    for theta in (0, 90, 180, 270):
        d = cb.outward(theta, 0)
        parts += cb.aim(k.star(0.16, pale, depth=0.06), Vector((0, 0, 2.3)) + d * 0.44, d)
        parts += cb.aim(k.star(0.11, pale, depth=0.05), Vector((0, 0, 1.2)) + d * 0.44 + Vector((-d.y, d.x, 0)) * 0.2, d)
    return parts


def fence_starlit_rail():
    pale = k.flat(STARLIGHT, emit=0.5)
    parts = [k.box((6.0, 0.24, 0.4), (0, 0, 0.2), m=_starry("fs_rail", -3, 3), bevel=0.05, name="rail")]
    for x in (-2.0, 0.0, 2.0):
        for s in (1, -1):
            parts += cb.aim(k.star(0.13, pale, depth=0.03), (x, s * 0.12, 0.2), (0, s, 0))
    return parts


# Clover Pads decal (V4 milestone 40) ----------------------------------------------------------


def _clover_paint():
    """Four-leaf clovers scattered on pad green: four offset copies of one 2D Voronoi cell pattern
    give four lobes round each cell point, with a lighter lobe inside each."""
    name = "pad_clover"
    if name in k._night._materials:
        return k._night._materials[name]
    m = k.mat(name, (120, 190, 90), kind="flat", rough=0.5)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    colour = None
    # Offsets are in studs, sizes in Voronoi units (studs x scale): lobes 0.14 wide, 0.11 apart.
    for rgb, size in (((60, 140, 65), 0.17), ((140, 210, 105), 0.08)):
        for dx, dy in ((0.1, 0.1), (-0.1, 0.1), (0.1, -0.1), (-0.1, -0.1)):
            shift = nt.nodes.new("ShaderNodeVectorMath")
            shift.operation = "ADD"
            shift.inputs[1].default_value = (dx, dy, 0)
            nt.links.new(coord.outputs["Object"], shift.inputs[0])
            cells = nt.nodes.new("ShaderNodeTexVoronoi")
            cells.voronoi_dimensions = "2D"
            cells.inputs["Scale"].default_value = 1.2
            cells.inputs["Randomness"].default_value = 0.6
            nt.links.new(shift.outputs[0], cells.inputs["Vector"])
            hit = nt.nodes.new("ShaderNodeMath")
            hit.operation = "LESS_THAN"
            hit.inputs[1].default_value = size
            nt.links.new(cells.outputs["Distance"], hit.inputs[0])
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            nt.links.new(hit.outputs[0], mix.inputs[0])
            if colour is None:
                mix.inputs[6].default_value = k.lin((120, 190, 90))
            else:
                nt.links.new(colour, mix.inputs[6])
            mix.inputs[7].default_value = k.lin(rgb)
            colour = mix.outputs[2]
    nt.links.new(colour, bsdf.inputs["Base Color"])
    return m


def pad_clover():
    # One flat 5 x 5 square (the pad top), so its single UV island fills the baked texture and
    # the PNG works as the Decal; the FBX is only the carrier the upload step needs.
    return [k.surface(4, 4, lambda u, v: (5 * u - 2.5, 5 * v - 2.5, 0.02), m=_clover_paint(), name="pad")]


ASSETS = [
    dict(name="creature_moth", build=creature_moth, budget=k.CREATURE_BUDGET, finalize=k.HD, size=MOTH_SIZE, priority=1, order=40, replaces="none (new species)",
         notes="Lantern Moth (rare, V2.4). One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are. The lantern is baked bright, no Neon.", glow={}),
    dict(name="fence_starlit_post", build=fence_starlit_post, budget=1200, size=[1, 4, 1], priority=2, order=50, replaces="Plots.refresh fence post part when fence == starlit",
         notes="Stands on the origin, star finial facing -Y. Plots places the PointLights (one per 3 posts), not the model.", glow={}),
    dict(name="fence_starlit_rail", build=fence_starlit_rail, budget=600, size=[6, 0.4, 0.3], priority=2, order=51, replaces="Plots.refresh fence rail part when fence == starlit",
         notes="Runs along X, stands on the origin; stars on both faces so either side can face out.", glow={}),
    dict(name="pad_clover", build=pad_clover, budget=100, size=[5, 0.1, 5], priority=2, order=52, replaces="plain green pad (Decal on the pad top when pad == clover)",
         notes="A decal, not a model: use the texture id on a Decal on the pad top face over pad colour (120, 190, 90); the flat quad FBX only carries it through the upload. 1024 baked, downscale to 256 at upload if required.", glow={}, decal_only=True),
]
