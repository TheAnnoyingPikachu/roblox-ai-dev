"""Shared Blender helpers for the Lantern Express assets (docs/game-design/game6-art-bible.md).

Imports the Egg Garden kit (tools/blender/garden/kit.py: paint, the HD creature standard, the bright
preview) and through it the Night kit (primitives, finalize, bake, contact sheet), with Lantern
output folders, the art bible palette, a dusk preview and two prop helpers (hull, brick).
Conventions as Garden: 1 unit = 1 stud, origin at the base centre, front Blender -Y.

Glow parts (`<asset>_<part>_glow`, untextured) are set to Neon in game in the colour under `glow`
in manifest.json; build.py puts the asset's colours in GLOW so the preview lights them too.
"""

import importlib.util
import math
import os

import bmesh
import bpy
from mathutils import Vector

_spec = importlib.util.spec_from_file_location(
    "gardenkit", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "garden", "kit.py")
)
_garden = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_garden)
_night = _garden._night  # the one Night instance whose finalize, OUT and preview are used

for _name in dir(_garden):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_garden, _name)

ROOT = _night.ROOT
OUT = os.path.join(ROOT, "build", "blender", "lantern")
PREVIEWS = os.path.join(OUT, "previews")
_night.OUT = _garden.OUT = OUT
_night.PREVIEWS = _garden.PREVIEWS = PREVIEWS

# Art bible palette (sRGB 0-255), section 2.
DUSK_VIOLET = (58, 44, 110)
DUSK_TEAL = (62, 128, 140)
HORIZON = (246, 168, 140)
FOG = (190, 180, 210)
AMBER = (255, 176, 64)
AMBER_CORE = (255, 226, 150)
EMBER = (255, 122, 52)
CREAM = (255, 238, 210)
BRICK = (178, 84, 66)
MORTAR = (226, 206, 184)
TIMBER = (128, 84, 60)
CRANBERRY = (196, 52, 62)
CRANBERRY_DEEP = (146, 36, 54)
IRON = (58, 48, 74)
BRASS_LO = (196, 134, 56)
BRASS_HI = (255, 214, 128)
ROOF_PLUM = (128, 70, 116)
ROOF_PLUM_HI = (164, 100, 150)
PERIWINKLE = (148, 164, 250)
PERIWINKLE_DEEP = (100, 110, 214)

# Neon colours of the glow parts (manifest `glow`).
LAMP_GLOW = (255, 206, 110)
FIRE_GLOW = (255, 128, 48)
WINDOW_GLOW = (255, 196, 104)

GLOW = {}  # part name -> sRGB for the preview; build.py fills it per asset


# Props ----------------------------------------------------------------------------------------


def hull(points, m, name="hull"):
    """Convex hull of world points: wedges and cowcatchers without hand-made faces."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _night._obj(name, bm, m)


def brick(name, rgb=BRICK, mortar=MORTAR, size=(1.0, 0.5), lo=0.0, hi=3.0, dark=0.82, around=None):
    """Baked brick bond (bricks `size` studs wide and tall) on vertical walls, darker towards the
    ground (lo to hi). The brick node is 2D, so it is fed (x + y, z) for flat walls, or with
    around=(cx, cy, r) the arc length round that axis, for round walls."""
    if name in _night._materials:
        return _night._materials[name]
    m = _night.mat(name, rgb, kind="flat", rough=0.7)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    xyz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], xyz.inputs[0])

    def op(operation, a, b):
        node = nt.nodes.new("ShaderNodeMath")
        node.operation = operation
        for i, x in enumerate((a, b)):
            if isinstance(x, (int, float)):
                node.inputs[i].default_value = x
            else:
                nt.links.new(x, node.inputs[i])
        return node.outputs[0]

    if around:
        cx, cy, r = around
        across = op("MULTIPLY", op("ARCTAN2", op("SUBTRACT", xyz.outputs["Y"], cy), op("SUBTRACT", xyz.outputs["X"], cx)), r)
    else:
        across = op("ADD", xyz.outputs["X"], xyz.outputs["Y"])
    vec = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(across, vec.inputs[0])
    nt.links.new(xyz.outputs["Z"], vec.inputs[1])
    tex = nt.nodes.new("ShaderNodeTexBrick")
    tex.inputs["Scale"].default_value = 1.0
    tex.inputs["Brick Width"].default_value = size[0]
    tex.inputs["Row Height"].default_value = size[1]
    tex.inputs["Mortar Size"].default_value = 0.05
    tex.inputs["Mortar Smooth"].default_value = 0.3
    tex.inputs["Color1"].default_value = lin(rgb)
    tex.inputs["Color2"].default_value = lin(shade(rgb, 0.86))
    tex.inputs["Mortar"].default_value = lin(mortar)
    tex.offset = 0.5
    nt.links.new(vec.outputs[0], tex.inputs["Vector"])
    span = nt.nodes.new("ShaderNodeMapRange")
    span.inputs["From Min"].default_value = lo
    span.inputs["From Max"].default_value = hi
    span.inputs["To Min"].default_value = dark
    nt.links.new(xyz.outputs["Z"], span.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mul.inputs[6])
    nt.links.new(span.outputs["Result"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    return m


def brass(name, lo, hi):
    """Toy brass: dark gold at the bottom to pale gold at the top of [lo, hi] (object z)."""
    return paint(name, [(0, BRASS_LO), (0.6, (240, 186, 88)), (1, BRASS_HI)], lo, hi, rough=0.3)


# Preview: dusk instead of the Garden toy shelf ---------------------------------------------------


def _dusk(scene, ground_rgb=(62, 78, 92)):
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = scene.world or bpy.data.worlds.new("dusk")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = lin((96, 84, 150))
    bg.inputs["Strength"].default_value = 0.9

    def sun(name, rgb, energy, rot):
        light = bpy.data.lights.new(name, "SUN")
        light.color = lin(rgb)[:3]
        light.energy = energy
        light.angle = math.radians(20)
        ob = bpy.data.objects.new(name, light)
        ob.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(ob)

    sun("key", (255, 196, 150), 2.6, (60, 0, -35))
    sun("rim", (170, 160, 255), 1.4, (60, 0, 150))
    return mat("pv_ground", ground_rgb, kind="flat")


def preview(name, parts, lo, hi):
    for p in parts:
        if p.name in GLOW:
            p.data.materials[0] = flat(GLOW[p.name], emit=3.0)
    _garden.preview(name, parts, lo, hi)


_garden._studio = _dusk
_garden._glow_material = lambda m: m  # preview() already lit the glow parts in their own colour
_night.preview = preview
