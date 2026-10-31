"""Sword contact sheet: build/blender/night/swords_sheet.png. Run after build.py.

blender --background --factory-startup --python tools/blender/night/swords_sheet.py

Works from the exported FBX and PNG files and fits art blades with the same root and stretch maths
as src/night/Gear.luau, so a misaligned blade or a flipped strip shows here (backface culling is
on, as in Roblox). Tints are the Blade Art colours and blades glow as they do in game.
"""

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import kit  # noqa: E402

with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
    MANIFEST = json.load(f)

OUT = os.path.join(kit.OUT, "swords")
WIDTHS = {"katana": 0.32, "kodachi": 0.28, "nodachi": 0.38}  # SHAPES in Gear.luau
LENGTHS = {"katana": 4.2, "kodachi": 2.6, "nodachi": 6.0}
STEEL = ((220, 225, 235), (140, 150, 165))
TINTS = {
    "inferno": ((255, 255, 200), (255, 120, 0)),
    "lightning": ((255, 255, 140), (120, 160, 255)),
    "void": ((0, 0, 0), (90, 0, 140)),
    "galaxy": ((40, 0, 90), (160, 60, 255)),
    "gold": ((255, 230, 120), (200, 140, 20)),
    "shadow": ((120, 0, 40), (20, 0, 30)),
    "sakura": ((255, 183, 210), (255, 255, 255)),
}


def bounds(objs):
    points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)])


def centre(ob):
    lo, hi = bounds([ob])
    return (lo + hi) / 2


def roblox(v):
    return Vector((v[0], -v[2], v[1]))


def neon(rgb):
    return kit.mat(f"neon{rgb}", rgb, kind="flat", emit=0.55, rough=0.35)


def textured(name):
    m = bpy.data.materials.get(f"tex_{name}")
    if m is None:
        m = bpy.data.materials.new(f"tex_{name}")
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 0.42
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(kit.ROOT, MANIFEST[name]["png"]), check_existing=True)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def load(name, tint=STEEL):
    """Imports an asset at its manifest height; returns {part name: object}."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(kit.ROOT, MANIFEST[name]["fbx"]), axis_forward="-Z", axis_up="Y")
    added = [o for o in bpy.data.objects if o not in before]
    parts = {}
    for o in added:
        if o.type != "MESH":
            continue
        matrix = o.matrix_world.copy()
        o.parent = None
        o.data.transform(matrix)
        o.matrix_world = Matrix.Identity(4)
        parts[o.name.split(".")[0]] = o
    for o in added:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    objs = list(parts.values())
    lo, hi = bounds(objs)
    scale = MANIFEST[name]["size_studs"][1] / (hi.z - lo.z)
    bpy.context.view_layer.update()
    for part, o in parts.items():
        o.data.transform(Matrix.Scale(scale, 4))
        o.data.materials.clear()
        if part.endswith("_blade"):
            m = neon(tint[0])
        elif part.endswith("_glow"):
            m = neon(tint[1])
        else:
            m = textured(name)
        m.use_backface_culling = True
        o.data.materials.append(m)
    return parts


def sword(weapon, art=None):
    tint = TINTS.get(art, STEEL)
    parts = load(weapon, tint)
    if art in (None, "sakura"):
        return parts
    blade, glow = parts.pop(f"{weapon}_blade"), parts.pop(f"{weapon}_glow")
    target = centre(blade) + roblox(MANIFEST[weapon]["root"])
    bpy.data.objects.remove(blade)
    bpy.data.objects.remove(glow)
    name = f"blade_{art}"
    new = load(name, tint)
    source = centre(new[f"{name}_blade"]) + roblox(MANIFEST[name]["root"])
    width, length = WIDTHS[weapon] / WIDTHS["katana"], LENGTHS[weapon] / LENGTHS["katana"]
    fit = Matrix.Translation(target) @ Matrix.Diagonal((width, width, length, 1)) @ Matrix.Translation(-source)
    for o in new.values():
        o.data.transform(fit)
    parts.update(new)
    return parts


def move(parts, matrix):
    for o in parts.values():
        o.data.transform(matrix)


def backdrop(scene, target, direction, reach):
    world = bpy.data.worlds.new("sheet")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = kit.lin((12, 12, 26))
    bg.inputs["Strength"].default_value = 1
    scene.world = world
    # Soft lantern-coloured pool of light behind the sword.
    glow = kit.mat("backdrop", (10, 10, 20), kind="flat")
    nodes, links = glow.node_tree.nodes, glow.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    ramp = nodes.new("ShaderNodeValToRGB")
    grad = nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    coord = nodes.new("ShaderNodeTexCoord")
    links.new(coord.outputs["Object"], grad.inputs["Vector"])
    links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs[0], out.inputs[0])
    ramp.color_ramp.elements[0].color = kit.lin((12, 12, 26))
    ramp.color_ramp.elements[1].color = kit.lin((58, 44, 78))
    plate = kit.cyl(reach * 3, 0.01, m=glow, n=48)
    plate.scale = (1 / (reach * 2), 1 / (reach * 2), 1)
    plate.data.transform(Matrix.Scale(reach * 2, 4))
    plate.scale = (1, 1, 1)
    plate.data.transform(Matrix.Diagonal((1 / (reach * 2), 1 / (reach * 2), 1, 1)))
    plate.matrix_world = Matrix.Translation(target - direction * 12) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Scale(reach * 2, 4)


def shot(file, parts_list, label, w=600, h=600, direction=(1, -0.12, 0.1), crop=None, pad=1.1):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.view_settings.view_transform = "Standard"
    objs = [o for parts in parts_list for o in parts.values()]
    lo, hi = crop or bounds(objs)
    target = (lo + hi) / 2
    direction = Vector(direction).normalized()
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = target + direction * 30
    cam.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    corners = [inv @ Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    us, vs = [c.x for c in corners], [c.y for c in corners]
    wide, tall = max(us) - min(us), max(vs) - min(vs)
    cam_data.ortho_scale = max(wide, tall * w / h) * pad
    cam_data.clip_end = 80
    cam.location = cam.matrix_world @ Vector(((max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2, 0))
    scene.camera = cam
    backdrop(scene, target, direction, max(wide, tall) * 0.8)

    def sun(name, rgb, energy, rot):
        light = bpy.data.lights.new(name, "SUN")
        light.color = kit.lin(rgb)[:3]
        light.energy = energy
        light.angle = math.radians(10)
        ob = bpy.data.objects.new(name, light)
        ob.rotation_euler = rot.to_track_quat("Z", "Y").to_euler()
        scene.collection.objects.link(ob)

    side = Vector((0, 0, 1)).cross(direction).normalized()
    up = direction.cross(side).normalized()
    sun("key", (255, 205, 150), 3.4, direction + up * 0.8 - side * 0.5)
    sun("fill", (170, 170, 255), 1.1, direction - up * 0.4 + side * 0.9)
    sun("rim", (120, 150, 255), 3.0, -direction + up * 0.9 + side * 0.4)

    text = bpy.data.curves.new("label", "FONT")
    text.body = label
    text.size = cam_data.ortho_scale * (0.02 if w > h else 0.038)
    note = bpy.data.objects.new("label", text)
    note.data.materials.append(kit.mat("label", (255, 225, 170), kind="flat", emit=3.0))
    scene.collection.objects.link(note)
    note.parent = cam
    y = h / w / 2 - 0.04 if w > h else -h / w / 2 + 0.03  # top left on wide shots, clear of the swords
    note.location = (-cam_data.ortho_scale * 0.47, cam_data.ortho_scale * y, -2)
    path = os.path.join(OUT, f"{file}.png")
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    return path


def tilt(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def hero_tile(weapon):
    kit.reset()
    blade = sword(weapon)
    case = load(f"{weapon}_saya")
    lo, hi = bounds(list(blade.values()))
    move(case, Matrix.Translation((0, 1.0 + LENGTHS[weapon] * 0.03, lo.z + 0.25)))
    pair = {**blade, **case}
    move(pair, tilt(48))
    tris = MANIFEST[weapon]["tris"]
    return shot(f"hero_{weapon}", [pair], f"{weapon}  {tris} tris   {weapon}_saya  {MANIFEST[weapon + '_saya']['tris']}")


def hilt_tile(weapon):
    kit.reset()
    parts = sword(weapon)
    lo, hi = bounds(list(parts.values()))
    grip = {"katana": 1.4, "kodachi": 1.0, "nodachi": 2.0}[weapon]
    crop = (Vector((lo.x, lo.y, lo.z)), Vector((hi.x, hi.y, lo.z + grip + 0.75)))
    return shot(f"hilt_{weapon}", [parts], f"{weapon} hilt", direction=(1, -0.75, 0.4), crop=crop, pad=1.05)


def tsuba_tile(weapon):
    kit.reset()
    parts = sword(weapon)
    lo, hi = bounds(list(parts.values()))
    size = {"katana": 0.56, "kodachi": 0.5, "nodachi": 0.72}[weapon]
    grip = hi.z - lo.z - LENGTHS[weapon] - 0.24
    z = lo.z + grip + 0.2
    crop = (Vector((-size, -size, z - 0.05)), Vector((size, size, z + 0.05)))
    return shot(f"tsuba_{weapon}", [parts], f"{weapon} tsuba", direction=(0.22, 0.12, 1), crop=crop, pad=1.25)


def art_tile(art):
    kit.reset()
    parts = sword("katana", art)
    move(parts, tilt(48))
    name = f"blade_{art}"
    return shot(f"art_{art}", [parts], f"{name}  {MANIFEST[name]['tris']} tris" if name in MANIFEST else art)


def lineup(file, entries, label):
    kit.reset()
    rows = []
    z = 0.0
    for build in entries:
        parts = build()
        move(parts, Matrix.Rotation(math.radians(-90), 4, "X"))
        lo, hi = bounds(list(parts.values()))
        move(parts, Matrix.Translation((0, -lo.y, z - lo.z)))
        z += hi.z - lo.z + 0.28
        rows.append(parts)
    return shot(file, rows, label, w=1800, h=1000, direction=(1, 0, 0), pad=1.03)


def compose(rows, path):
    width = 1800
    images = []
    for row in rows:
        loaded = [bpy.data.images.load(p, check_existing=False) for p in row]
        images.append(loaded)
    height = sum(row[0].size[1] for row in images)
    sheet = np.zeros((height, width, 4), dtype=np.float32)
    sheet[..., 3] = 1
    top = height
    for row in images:
        tall = row[0].size[1]
        top -= tall
        left = 0
        for img in row:
            w, h = img.size
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            sheet[top : top + h, left : left + w] = px.reshape(h, w, 4)
            left += w
    out = bpy.data.images.new("swords", width, height, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()


def main():
    os.makedirs(OUT, exist_ok=True)
    heroes = ("katana", "kodachi", "nodachi")
    arts = ("inferno", "lightning", "void", "galaxy", "gold", "shadow")
    rows = [
        [lineup("lineup", [lambda w=w: sword(w) for w in reversed(heroes)] + [lambda w=w: load(f"{w}_saya") for w in reversed(heroes)], "lineup")],
        [hero_tile(w) for w in heroes],
        [hilt_tile(w) for w in heroes],
        [tsuba_tile(w) for w in heroes],
        [art_tile(a) for a in arts[:3]],
        [art_tile(a) for a in arts[3:]],
    ]
    pairs = [("kodachi", "inferno"), ("nodachi", "lightning"), ("kodachi", "void"), ("nodachi", "galaxy"), ("kodachi", "gold"), ("nodachi", "shadow")]
    rows.append([lineup("art_fit", [lambda w=w, a=a: sword(w, a) for w, a in pairs], "art blades fitted to kodachi and nodachi")])
    kit.reset()
    compose(rows, os.path.join(kit.OUT, "swords_sheet.png"))
    print("[night] sheet written")


main()
