"""Reference vs remake sheets: each Roblox AI reference shot (assets/garden/refs/<id>_<view>.jpg) over
a render of the built creature from the same camera, cropped to the same window.

blender --background --factory-startup --python tools/blender/garden/refcompare.py -- frog duck ...

Needs each creature built first (build.py). Writes build/blender/garden/refcompare/<id>_vs_ref.png.
The composing step runs in the system Python (Pillow): `python -P refcompare.py <id> ...` redoes
only that from the renders already there.

The render reproduces the Studio screen_capture camera (docs/production/ai-reference-pipeline.md):
70 degree vertical field of view, 1452 x 793, the same camera offsets, looking at the middle of the
reference's bounding box, with the remake scaled to the reference's height. So the silhouettes
compare like for like: a head that looks smaller in the bottom row is smaller.
"""

import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
REFS = os.path.join(ROOT, "assets", "garden", "refs")
OUT = os.path.join(ROOT, "build", "blender", "garden", "refcompare")
W, H, FOV = 1452, 793, 70
# Camera offsets from the reference's base centre, Roblox (x, y, z): the pipeline doc's four shots.
VIEWS = {"front": (0, 3, -7), "34": (5, 3.5, -5), "side": (6.5, 3, 0), "back": (0, 3, 7)}
# Degrees the generated mesh is turned from -Z towards +X (measured from the shots): the frog to cat and owl to
# capybara batches came out facing the "34" camera.
TURN = {"frog": 45, "duck": 45, "pup": 45, "lamb": 45, "puffin": 45, "cat": 45, "owl": 45, "hedgehog": 45, "otter": 45, "moth": 45, "turtle": 45, "capybara": 45}
TILE, PAD = 420, 16


def to_blender(id, v):
    """A Roblox offset from the reference into the remake's frame (front -Y, its right -X)."""
    a = math.radians(TURN.get(id, 0))
    x, y, z = v
    fwd = x * math.sin(a) - z * math.cos(a)  # along the reference's facing
    right = x * math.cos(a) + z * math.sin(a)
    return (-right, -fwd, y)


def window(id, size):
    """Crop box (x0, y0, x1, y1) per view: the reference bounding box projected, padded."""
    boxes = {}
    sx, sy, sz = size
    for view, cam in VIEWS.items():
        c = cam
        look = (0, sy / 2, 0)
        f = [look[i] - c[i] for i in range(3)]
        n = math.sqrt(sum(t * t for t in f))
        f = [t / n for t in f]
        r = [-f[2], 0, f[0]]  # f x up(0,1,0), Roblox right-handed
        n = math.sqrt(r[0] ** 2 + r[2] ** 2)
        r = [t / n for t in r]
        u = [r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0]]
        k = (H / 2) / math.tan(math.radians(FOV / 2))
        xs, ys = [], []
        for dx in (-sx / 2, sx / 2):
            for dy in (0, sy):
                for dz in (-sz / 2, sz / 2):
                    p = [dx - c[0], dy - c[1], dz - c[2]]
                    depth = sum(p[i] * f[i] for i in range(3))
                    xs.append(W / 2 + k * sum(p[i] * r[i] for i in range(3)) / depth)
                    ys.append(H / 2 - k * sum(p[i] * u[i] for i in range(3)) / depth)
        pad = 0.12 * (max(ys) - min(ys))
        boxes[view] = tuple(round(t) for t in (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad))
    return boxes


def render(ids):
    import bpy

    sys.path.insert(0, HERE)
    import kit
    import lineup
    from mathutils import Matrix, Vector

    refs = json.load(open(os.path.join(REFS, "generated.json"), encoding="utf-8"))
    manifest = json.load(open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    for id in ids:
        name = f"creature_{id}"
        h = refs[id]["size"][1]
        for view, cam in VIEWS.items():
            kit.reset()
            scene = bpy.context.scene
            scene.render.engine = "BLENDER_EEVEE"
            scene.eevee.taa_render_samples = 32
            scene.render.resolution_x, scene.render.resolution_y = W, H
            scene.render.film_transparent = True
            kit._studio(scene)
            meshes = lineup._load(name, manifest[name])
            bpy.context.view_layer.update()
            cs = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
            lo, hi = Vector(map(min, *cs)), Vector(map(max, *cs))
            m = Matrix.Scale(h / (hi.z - lo.z), 4) @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
            for o in meshes:
                o.matrix_world = m @ o.matrix_world
            data = bpy.data.cameras.new("cam")
            data.sensor_fit, data.angle = "VERTICAL", math.radians(FOV)
            ob = bpy.data.objects.new("cam", data)
            scene.collection.objects.link(ob)
            ob.location = Vector(to_blender(id, cam))
            ob.rotation_euler = (Vector((0, 0, h / 2)) - ob.location).to_track_quat("-Z", "Y").to_euler()
            scene.camera = ob
            scene.render.filepath = os.path.join(OUT, f"{id}_{view}.png")
            bpy.ops.render.render(write_still=True)


def compose(ids):
    from PIL import Image, ImageDraw

    refs = json.load(open(os.path.join(REFS, "generated.json"), encoding="utf-8"))
    for id in ids:
        boxes = window(id, refs[id]["size"])
        rows = [[], []]
        for view, box in boxes.items():
            ref = os.path.join(REFS, f"{id}_{view}.jpg")
            got = os.path.join(OUT, f"{id}_{view}.png")
            if not (os.path.exists(ref) and os.path.exists(got)):
                continue
            for row, im in enumerate((Image.open(ref).convert("RGBA"), Image.open(got).convert("RGBA"))):
                if row:
                    bg = Image.new("RGBA", im.size, (226, 236, 244, 255))
                    im = Image.alpha_composite(bg, im)
                im = im.crop(box)
                s = TILE / im.height
                rows[row].append(im.resize((round(im.width * s), TILE), Image.LANCZOS).convert("RGB"))
        w = sum(t.width + PAD for t in rows[0]) + PAD
        sheet = Image.new("RGB", (w, 2 * TILE + 3 * PAD), (255, 255, 255))
        for r, tiles in enumerate(rows):
            x = PAD
            for t in tiles:
                sheet.paste(t, (x, PAD + r * (TILE + PAD)))
                x += t.width + PAD
        d = ImageDraw.Draw(sheet)
        d.text((PAD + 4, PAD + 4), f"{id}: Roblox AI reference", fill=(40, 40, 60))
        d.text((PAD + 4, 2 * PAD + TILE + 4), "Blender remake, same camera", fill=(40, 40, 60))
        path = os.path.join(OUT, f"{id}_vs_ref.png")
        sheet.save(path)
        print(path, flush=True)


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
    except ImportError:
        compose(sys.argv[1:])
    else:
        ids = sys.argv[sys.argv.index("--") + 1 :]
        render(ids)
        subprocess.run(["python", "-P", os.path.abspath(__file__), *ids], check=True)
