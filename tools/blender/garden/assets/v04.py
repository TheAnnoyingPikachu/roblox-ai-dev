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
from creatures_a import xf  # noqa: E402
from v05_exclusives import mark, paddle, settle, swap  # noqa: E402

NAVY = (40, 45, 100)
STARLIGHT = (235, 230, 255)


# Lantern Moth (rare, V2.4) --------------------------------------------------------------------


def creature_moth():
    """HD standard (README "Creature standard"): one fused fluffy body with a scalloped ruff, the
    kit face, feather-plume antennae, four quill-free wings with eye-spots painted after settle
    on both faces, and a glowing paper lantern held in both hands (baked bright)."""
    head, R = Vector((0, -0.2, 1.95)), 0.8
    hand = Vector((0.13, -1.0, 1.2))
    ruff = [(Vector((0.72 * math.cos(a), 0.05 + 0.66 * math.sin(a), 1.45)), 0.28) for a in (math.radians(22.5 + 45 * i) for i in range(8))]
    body = k.fuse(
        [
            (head, R, (1.15, 0.95, 0.92)),
            ((0, 0.25, 1.15), 0.72, (1.05, 1.0, 1.0)),  # thorax
            ((0, 0.25, 0.55), 0.6, (1.1, 1.0, 0.6)),  # round seat the feet fuse to
            ((0, 0.95, 0.85), 0.55, (0.95, 1.25, 0.85)),  # round abdomen behind
            ((0, 1.45, 0.72), 0.3),
            *ruff,  # fluffy scalloped collar
            *k.pair((0.38, -0.2, 0.18), 0.22, (0.9, 1.4, 0.65)),  # feet
            *[("capsule", (s * 0.55, -0.3, 1.25), (s * hand.x, hand.y, hand.z), 0.15) for s in (-1, 1)],  # arms to the lantern
            *k.pair(hand, 0.15),
        ],
        k.flat((250, 238, 215)),
        tris=2800,
    )
    parts = [body]
    # Paper lantern on the ground in front, its bail in both hands.
    ly = -1.05
    lantern = k.lathe([(0.2, 0.08), (0.36, 0.13), (0.45, 0.28), (0.49, 0.5), (0.45, 0.72), (0.36, 0.86), (0.2, 0.92)], loc=(0, ly, 0), m=k.flat((255, 230, 140)), n=24, name="lantern")
    rim = k.flat((205, 80, 60))
    parts += [lantern,
              k.lathe([(0, 0), (0.25, 0), (0.27, 0.05), (0.25, 0.11), (0, 0.11)], loc=(0, ly, 0), m=rim, n=24, name="cap"),
              k.lathe([(0, 0.89), (0.23, 0.89), (0.25, 0.94), (0.23, 1.0), (0, 1.0)], loc=(0, ly, 0), m=rim, n=24, name="cap"),
              k.tube([(-0.17, ly, 0.98), (-0.15, ly, 1.14), (0, ly, 1.24), (0.15, ly, 1.14), (0.17, ly, 0.98)], 0.028, m=k.flat((120, 70, 60)), n=6, name="bail")]
    # Feather-plume antennae: a quill and a striped plume, leaning out and a little forward.
    for s in (-1, 1):
        root = Vector((s * 0.4, -0.42, 2.52))
        plume = k.leaf(0.95, 0.19, k.flat((225, 190, 140)), droop=0.0, n=8, steps=10, name="plume")
        plume.data.transform(Matrix.Translation((0.28, 0, 0)))  # a bare quill first, then the plume
        quill = k.tube([(-0.12, -0.02, 0), (0.6, -0.02, 0), (1.25, -0.02, 0)], [0.032, 0.024, 0.008], m=k.flat((125, 85, 70)), n=6, name="quill")
        parts += xf([plume, quill], root, yaw=-15, pitch=42, roll=90, mirror=s < 0)
    # Wings: a big forewing swept up and back, a smaller hindwing below it, each side.
    wings = {"fore": [], "hind": []}
    for s in (-1, 1):
        for kind, length, width, rise, sweep in (("fore", 2.4, 0.76, 26, 28), ("hind", 1.55, 0.56, -30, 40)):
            e = math.radians(rise)
            # columns: along the wing (rising e), across it, and its face towards -Y
            frame = Matrix.Translation((0.4, 0.45, 1.6)) @ k.rot_z(sweep) @ Matrix(((math.cos(e), -math.sin(e), 0), (0, 0, -1), (math.sin(e), math.cos(e), 0))).to_4x4()
            if s < 0:
                frame = Matrix.Diagonal((-1, 1, 1, 1)) @ frame
            w = paddle(length, width, k.flat((200, 170, 240)), thick=0.1, n=8, root=0.35, name="wing")
            w.data.transform(frame)
            wings[kind].append((w, frame, length, s))
    parts += [w for kind in wings.values() for w, _, _, _ in kind]
    parts += k.face(body, head, R, skin=(252, 242, 222), nose=None)

    m = settle(parts, [4.8, 3.2, 3.4])
    swap(body, k.paint("mo_fluff", [(0, (226, 204, 170)), (0.5, (246, 232, 206)), (1, (255, 250, 236))], 0.2, 2.8))
    # Dusk gradient on each wing, from deep violet at the body to pale lilac-pink at the tip.
    dusk = {"fore": [(0, (120, 78, 200)), (0.5, (170, 135, 235)), (1, (225, 195, 250))], "hind": [(0, (140, 85, 195)), (0.6, (205, 140, 225)), (1, (245, 185, 225))]}
    for kind, items in wings.items():
        for w, frame, length, s in items:
            marks = []
            if kind == "fore":
                c = frame @ Vector((length * 0.64, 0.05, 0))
                g = frame @ Vector((length * 0.64 - 0.08, 0.12, 0))
                marks += [mark(m, (255, 214, 120), c, 0.4), mark(m, (90, 45, 140), c, 0.3), mark(m, (255, 236, 175), c, 0.18),
                          mark(m, (55, 28, 85), c, 0.1), mark(m, (255, 255, 255), g, 0.04)]
            else:
                marks += [mark(m, (255, 225, 150), frame @ Vector((length * 0.68, 0, 0)), 0.2), mark(m, (90, 45, 140), frame @ Vector((length * 0.68, 0, 0)), 0.13)]
            x0, x1 = (m @ (frame @ Vector((0, 0, 0)))).x, (m @ (frame @ Vector((length, 0, 0)))).x
            swap(w, k.paint(f"mo_{kind}_{s}", dusk[kind], x0, x1, axis="X", marks=marks))
    lo, hi = k._ground_dims([lantern])
    swap(lantern, k.paint("mo_lamp", [(0, (255, 150, 55)), (0.5, (255, 192, 98)), (1, (255, 168, 68))], lo.z, hi.z, bands=((255, 178, 85), 0.09), emit=0.45))  # the glow adds 27%: brighter stops clip green to lime
    for ob in parts:
        if ob.name.startswith("plume"):
            swap(ob, k.paint("mo_plume", [(0, (205, 160, 112)), (1, (238, 210, 165))], 2.4, 3.3, bands=((212, 172, 128), 0.06)))
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
    dict(name="creature_moth", build=creature_moth, budget=k.CREATURE_BUDGET, finalize=k.HD, size=[4.8, 3.2, 3.4], priority=1, order=40, replaces="none (new species)",
         notes="Lantern Moth (rare, V2.4). One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are. The lantern is baked bright, no Neon.", glow={}),
    dict(name="fence_starlit_post", build=fence_starlit_post, budget=1200, size=[1, 4, 1], priority=2, order=50, replaces="Plots.refresh fence post part when fence == starlit",
         notes="Stands on the origin, star finial facing -Y. Plots places the PointLights (one per 3 posts), not the model.", glow={}),
    dict(name="fence_starlit_rail", build=fence_starlit_rail, budget=600, size=[6, 0.4, 0.3], priority=2, order=51, replaces="Plots.refresh fence rail part when fence == starlit",
         notes="Runs along X, stands on the origin; stars on both faces so either side can face out.", glow={}),
    dict(name="pad_clover", build=pad_clover, budget=100, size=[5, 0.1, 5], priority=2, order=52, replaces="plain green pad (Decal on the pad top when pad == clover)",
         notes="A decal, not a model: use the texture id on a Decal on the pad top face over pad colour (120, 190, 90); the flat quad FBX only carries it through the upload. 1024 baked, downscale to 256 at upload if required.", glow={}),
]
