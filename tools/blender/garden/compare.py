"""Before/after render of rebuilt creatures, close up and at game distance (hd_compare.png).

blender --background --factory-startup --python tools/blender/garden/compare.py -- creature_bunny [...]

Old is the committed assets/garden/<name>.fbx/.png at git HEAD (what the game has); new is the
build in build/blender/garden/. Each row: old and new close up, new from behind, then old and new
at 20 studs at the pixel size a 1080p player sees (Roblox default 70 degree field of view), at 2x.
"""

import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import kit  # noqa: E402
import lineup  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

TILE = 512
GAME = TILE // 2
DIST = 20
PX_PER_STUD = 1080 / (2 * DIST * math.tan(math.radians(35)))
TILES = os.path.join(kit.OUT, "compare")


def _old(name):
    """The committed FBX and PNG at HEAD, written next to the tiles."""
    os.makedirs(TILES, exist_ok=True)
    paths = {}
    for ext in ("fbx", "png"):
        data = subprocess.run(["git", "-C", kit.ROOT, "show", f"HEAD:assets/garden/{name}.{ext}"], capture_output=True, check=True).stdout
        paths[ext] = os.path.join(TILES, f"{name}_old.{ext}")
        with open(paths[ext], "wb") as f:
            f.write(data)
    return paths


def _shot(path, lo, hi, size, scale, direction, label=None):
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = size
    centre = (lo + hi) / 2
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale
    cam_data.clip_end = 200
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    d = Vector(direction).normalized()
    cam.location = centre + d * 50
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    if label:
        text = bpy.data.curves.new("label", "FONT")
        text.body = label
        text.size = scale * 0.045
        ob = bpy.data.objects.new("label", text)
        ob.data.materials.append(kit.mat("pv_label", (70, 60, 90), kind="flat", emit=1.0))
        scene.collection.objects.link(ob)
        ob.parent = cam
        ob.location = (-scale * 0.47, -scale * 0.47, -5)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    a = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(size, size, 4)


def render(name, version, entry):
    kit.reset()
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 32
    scene.render.image_settings.file_format = "PNG"
    ground = kit._studio(scene)
    meshes = lineup._load(name, entry)
    bpy.context.view_layer.update()
    corners = [ob.matrix_world @ Vector(c) for ob in meshes for c in ob.bound_box]
    lo, hi = Vector(map(min, *corners)), Vector(map(max, *corners))
    kit.cyl(30, 0.02, ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z - 0.011), m=ground, n=48)
    tris = sum(kit._tris(o) for o in meshes)
    size = max((hi - lo).length, 1)
    close = _shot(os.path.join(TILES, f"{name}_{version}_close.png"), lo, hi, TILE, size * 0.82, (-0.35, -1, 0.3), f"{version}: {tris} tris")
    back = _shot(os.path.join(TILES, f"{name}_{version}_back.png"), lo, hi, TILE, size * 0.82, (0.5, 1, 0.35), f"{version}, back")
    game = _shot(os.path.join(TILES, f"{name}_{version}_game.png"), lo, hi, GAME, GAME / PX_PER_STUD, (-0.3, -1, 0.55))
    return close, back, np.repeat(np.repeat(game, 2, axis=0), 2, axis=1)  # nearest 2x: shows the real pixels


def main():
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    columns = (("old", 0), ("new", 0), ("new", 1), ("old", 2), ("new", 2))
    sheet = np.full((len(names) * TILE, len(columns) * TILE, 4), 0.5, dtype=np.float32)
    sheet[..., 3] = 1
    for r, name in enumerate(names):
        entry = manifest[name]
        old = _old(name)
        tiles = {"old": render(name, "old", {**entry, "fbx": old["fbx"], "png": old["png"]})}
        if os.path.exists(os.path.join(kit.ROOT, entry["fbx"])):
            tiles["new"] = render(name, "new", entry)
        y0 = (len(names) - 1 - r) * TILE  # Blender pixel rows start at the bottom
        for c, (version, kind) in enumerate(columns):
            if version in tiles:
                sheet[y0 : y0 + TILE, c * TILE : (c + 1) * TILE] = tiles[version][kind]
    out = bpy.data.images.new("compare", len(columns) * TILE, len(names) * TILE, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    path = os.path.join(kit.OUT, "hd_compare.png")
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    print(f"[garden] compare: {path}", flush=True)


main()
