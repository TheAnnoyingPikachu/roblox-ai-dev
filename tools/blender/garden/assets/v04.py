"""Egg Garden v0.4 art (GARDEN-031, docs/architecture/garden.md 9.2): the Lantern Moth, the Starlit
fence post and rail, and the Clover Pads decal. The moth follows the creatures_b style (chibi, one
mesh, stands on the origin facing -Y); its lantern is baked bright, no Neon."""

import importlib.util
import math
import os

import kit as k
from mathutils import Vector

_spec = importlib.util.spec_from_file_location("creatures_b", os.path.join(os.path.dirname(os.path.abspath(__file__)), "creatures_b.py"))
cb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cb)

NAVY = (40, 45, 100)
STARLIGHT = (235, 230, 255)


# Lantern Moth (rare, V2.4) --------------------------------------------------------------------


def creature_moth():
    fluff = k.paint("mo_fluff", [(0, (240, 222, 190)), (1, (255, 246, 228))], 0.6, 3.0)
    wing = k.paint("mo_wing", [(0, (150, 110, 215)), (1, (222, 200, 255))], 0.8, 3.4)
    spot = k.flat((95, 60, 150))
    spot_ring = k.flat((255, 225, 150))
    brown = k.flat((120, 85, 70))
    tan = k.flat((200, 160, 120))
    lamp = k.flat((255, 222, 110), emit=1.3)
    lamp_rim = k.flat((200, 90, 60))

    body = (0, 0.1, 1.45)
    head = (0, -0.55, 2.3)
    parts = [cb.blob(0.78, body, fluff, scale=(1, 1.1, 1), seg=14, rings=9, name="body")]
    parts.append(cb.blob(0.66, head, fluff, scale=(1.08, 1, 1), seg=14, rings=9, name="head"))
    # Fluffy collar between head and body.
    for x, y, z, r in ((0.55, -0.35, 1.95, 0.32), (-0.55, -0.35, 1.95, 0.32), (0, -0.2, 2.0, 0.3), (0.5, 0.3, 2.0, 0.3), (-0.5, 0.3, 2.0, 0.3)):
        parts.append(cb.blob(r, (x, y, z), fluff, seg=10, rings=6, name="collar"))
    parts += cb.eyes(head, 0.66, theta=30, phi=6, r=0.24, scale=(1.08, 1, 1))
    parts += cb.cheeks(head, 0.66, theta=52, phi=-12, r=0.15, scale=(1.08, 1, 1))
    # Feathery antennae: a curving stalk with fronds along the inner side.
    for s in (1, -1):
        root = Vector((s * 0.3, -0.5, 2.9))
        stalk = [root, root + Vector((s * 0.25, -0.1, 0.5)), root + Vector((s * 0.35, -0.15, 0.95))]
        parts.append(k.tube(stalk, [0.06, 0.05, 0.03], m=brown, n=5, name="antenna"))
        for t, r in ((0.3, 0.13), (0.55, 0.15), (0.8, 0.13), (1.0, 0.1)):
            p = root + Vector((s * 0.35, -0.15, 0.95)) * t
            parts.append(k.sphere(r, p + Vector((-s * 0.1, 0, 0.02)), m=tan, scale=(1.6, 0.5, 1), seg=6, rings=3, name="frond"))
    # Wings: a big round forewing and a smaller hindwing, thin, swept up and back; one painted
    # eye-spot on each forewing (three stacked discs), built upright at the origin then placed.
    for s in (1, -1):
        w = [
            k.sphere(1.0, (0, 0, 0), m=wing, scale=(1.25, 0.2, 0.95), seg=12, rings=8, name="forewing"),
            k.sphere(1.0, (s * -0.3, 0.02, -0.85), m=wing, scale=(0.95, 0.18, 0.62), seg=12, rings=7, name="hindwing"),
            k.sphere(0.4, (s * 0.15, -0.19, 0.1), m=spot, scale=(1, 0.3, 1), seg=10, rings=5, name="spot"),
            k.sphere(0.27, (s * 0.15, -0.25, 0.1), m=spot_ring, scale=(1, 0.3, 1), seg=10, rings=5, name="spot"),
            k.sphere(0.13, (s * 0.18, -0.3, 0.14), m=k.flat(cb.DARK), scale=(1, 0.3, 1), seg=8, rings=4, name="spot"),
        ]
        parts += cb.placed(w, loc=(s * 1.35, 0.45, 2.25), rot=(-12, s * -28, s * 18))
    # Paper lantern held under the body: bright barrel, dark rims, tiny feet gripping the ring.
    ly = -0.7
    parts.append(k.lathe([(0.16, 0.12), (0.42, 0.3), (0.5, 0.58), (0.42, 0.86), (0.16, 1.02)], loc=(0, ly, 0), m=lamp, n=12, name="lantern"))
    parts.append(k.ring(0.18, 0.12, 0.04, lamp_rim, n=10, sides=4, centre=(0, ly), name="rim"))
    parts.append(k.ring(0.18, 1.02, 0.04, lamp_rim, n=10, sides=4, centre=(0, ly), name="rim"))
    parts.append(k.ring(0.12, 1.12, 0.03, lamp_rim, n=8, sides=4, centre=(0, ly), name="handle"))
    for s in (1, -1):
        parts.append(k.sphere(0.12, (s * 0.2, ly + 0.05, 1.12), m=brown, scale=(1, 1.3, 0.7), seg=6, rings=4, name="foot"))
        parts.append(k.sphere(0.2, (s * 0.4, 0.25, 0.2), m=fluff, scale=(1, 1.4, 0.6), seg=8, rings=4, name="foot"))
    for ob in parts:  # modelled at wing scale; 9.2 wants a height of about 3.2
        ob.data.transform(k.Matrix.Scale(0.82, 4))
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
    dict(name="creature_moth", build=creature_moth, budget=2500, size=[4.8, 3.2, 3.4], priority=1, order=40, replaces="none (new species)",
         notes="Lantern Moth (rare, V2.4). One mesh, stands on the origin facing -Y; scale to the manifest height as the eggs are. The lantern is baked bright, no Neon.", glow={}),
    dict(name="fence_starlit_post", build=fence_starlit_post, budget=1200, size=[1, 4, 1], priority=2, order=50, replaces="Plots.refresh fence post part when fence == starlit",
         notes="Stands on the origin, star finial facing -Y. Plots places the PointLights (one per 3 posts), not the model.", glow={}),
    dict(name="fence_starlit_rail", build=fence_starlit_rail, budget=600, size=[6, 0.4, 0.3], priority=2, order=51, replaces="Plots.refresh fence rail part when fence == starlit",
         notes="Runs along X, stands on the origin; stars on both faces so either side can face out.", glow={}),
    dict(name="pad_clover", build=pad_clover, budget=100, size=[5, 0.1, 5], priority=2, order=52, replaces="plain green pad (Decal on the pad top when pad == clover)",
         notes="A decal, not a model: use the texture id on a Decal on the pad top face over pad colour (120, 190, 90); the flat quad FBX only carries it through the upload. 1024 baked, downscale to 256 at upload if required.", glow={}),
]
