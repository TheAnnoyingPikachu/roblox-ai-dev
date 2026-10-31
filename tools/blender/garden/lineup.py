"""Renders all seven eggs in a row from their exported FBX and PNG files (eggs_lineup.png).

blender --background --factory-startup --python tools/blender/garden/lineup.py

Importing the exports, not the build scripts, also proves the FBX files load with their parts
and sizes. build.py calls render() at the end of a full build.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import kit  # noqa: E402
from mathutils import Vector  # noqa: E402

EGGS = ["egg_starter", "egg_meadow", "egg_forest", "egg_sunset", "egg_moon", "egg_star", "egg_celestial"]
GAP = 0.9  # studs between eggs


def _load(name, entry):
    """Imports one egg, applies its texture, fits the manifest height, returns its mesh objects."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(kit.ROOT, entry["fbx"]))
    meshes = [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]
    missing = set(entry["parts"]) - {o.name for o in meshes}
    if missing:
        raise RuntimeError(f"{name}: FBX lacks {sorted(missing)}")

    tex_mat = bpy.data.materials.new(f"{name}_tex")
    try:
        tex_mat.use_nodes = True
    except Exception:
        pass
    nt = tex_mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.42
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(kit.ROOT, entry["png"]), check_existing=False)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for ob in meshes:
        ob.data.materials.clear()
        rgb = entry["glow"].get(ob.name)
        ob.data.materials.append(kit.flat(tuple(rgb), emit=2.5) if rgb else tex_mat)

    bpy.context.view_layer.update()
    corners = [ob.matrix_world @ Vector(c) for ob in meshes for c in ob.bound_box]
    lo = Vector(map(min, *corners))
    hi = Vector(map(max, *corners))
    scale = entry["size_studs"][1] / (hi.z - lo.z)
    for ob in meshes:
        ob.parent = None
        ob.matrix_world = (kit.Matrix.Scale(scale, 4) @ ob.matrix_world).copy()
    return meshes


def render(manifest, samples=256):
    kit.reset()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 2800
    scene.render.resolution_y = 1100
    scene.render.film_transparent = False
    ground = kit._studio(scene, (232, 246, 226))
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = kit.lin((205, 234, 252))

    x = 0.0
    tallest = 0.0
    for name in EGGS:
        entry = manifest[name]
        width = entry["size_studs"][0]
        offset = x + width / 2
        for ob in _load(name, entry):
            ob.matrix_world = kit.Matrix.Translation((offset, 0, 0)) @ ob.matrix_world
        x += width + GAP
        tallest = max(tallest, entry["size_studs"][1])
    width = x - GAP
    centre = Vector((width / 2, 0, tallest * 0.5))

    kit.cyl(width * 3, 0.02, (centre.x, 0, -0.011), m=ground, n=64)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 90
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    direction = Vector((0, -1, 0.13)).normalized()
    # Distance that fits the row across the sensor at this lens, with a margin.
    distance = width * 1.08 / (2 * math.tan(cam_data.angle_x / 2))
    cam.location = centre + direction * distance
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_end = distance * 4
    scene.camera = cam

    path = os.path.join(kit.OUT, "eggs_lineup.png")
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print(f"[garden] lineup: {path}", flush=True)


if __name__ == "__main__":
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        render(json.load(f))
