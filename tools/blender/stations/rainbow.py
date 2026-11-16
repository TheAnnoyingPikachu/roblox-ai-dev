"""Paints the rainbow coat of every Animal Stations creature (decision 0058): a second texture for the
model that is already uploaded, with the same shading and markings in the colours of a rainbow running
from its nose to its tail.

blender --background --factory-startup --python tools/blender/stations/rainbow.py -- [--card] [asset ...]

Run after export_assets.py. Reads assets/stations/<asset>.fbx and .png (the files the upload sends, so
the coat fits the uploaded mesh's UVs) and writes build/blender/stations/rainbow/<asset>.png;
`export_assets.py --rainbow` then copies the coats into assets/stations/<asset>_rainbow.png.
With no names, paints every creature in the manifest. --card also renders a presentation card of each
(build/blender/stations/beauty/<asset>_rainbow.png).

How: the position of every texel is baked through the model's own UVs. A texel's hue comes from where
it is on the animal; how light it is comes from the painted texture, stretched so that a dark animal
is as bright a rainbow as a pale one.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import kit  # noqa: E402
import numpy as np  # noqa: E402

FILES = os.path.join(kit.ROOT, "assets", "stations")
OUT = os.path.join(kit.OUT, "rainbow")
BANDS = 1.5  # rainbows from the nose (and the top) to the tail (and the feet)
CARD_GLOW = ((255, 70, 90), (70, 220, 255), (255, 210, 60), (170, 90, 255), (90, 255, 130))  # a card's Neon pieces


def pixels(img):
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)[..., :3]


def hsv(h, s, v):
    """Arrays of hue, saturation and value (0 to 1) to RGB."""
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    return np.stack(
        [np.choose(i, [v, q, p, p, t, v]), np.choose(i, [t, v, v, q, p, p]), np.choose(i, [p, p, t, v, v, q])],
        axis=-1,
    )


def coat(name):
    """Imports the exported model, bakes where each texel is and returns (the coat as an image, the model's
    painted meshes, its Neon meshes)."""
    kit.reset()
    bpy.ops.import_scene.fbx(filepath=os.path.join(FILES, f"{name}.fbx"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    kit._select(meshes)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    painted = [o for o in meshes if not o.name.endswith("_glow")]
    source = bpy.data.images.load(os.path.join(FILES, f"{name}.png"), check_existing=False)
    size = source.size[0]

    where = bpy.data.images.new("where", size, size, alpha=False, float_buffer=True)
    where.colorspace_settings.name = "Non-Color"
    target = bpy.data.materials.new("target")
    target.use_nodes = True
    node = target.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = where
    target.node_tree.nodes.active = node
    for ob in painted:
        ob.data.materials.clear()
        ob.data.materials.append(target)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    kit._select(painted)
    bpy.ops.object.bake(type="POSITION", use_clear=True, margin=16)

    at = pixels(where)
    on = np.abs(at).sum(axis=-1) > 1e-6  # texels the model uses (and the margin round them)
    if not on.any():
        raise ValueError(f"{name}: the position bake is empty")
    lo, hi = at[on].min(axis=0), at[on].max(axis=0)
    n = (at - lo) / np.maximum(hi - lo, 1e-6)  # the model faces -Y: n.y is 0 at the nose, n.z 1 at the top
    span = hi - lo
    along = (n[..., 1] * span[1] + (1 - n[..., 2]) * span[2] * 0.8) / (span[1] + span[2] * 0.8)
    hue = BANDS * along + 0.1 * np.abs(n[..., 0] - 0.5) + 0.035 * np.sin(n[..., 2] * 7 * np.pi)

    rgb = pixels(source)
    lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    dark, light = np.percentile(lum[on], (4, 96))
    t = np.clip((lum - dark) / max(light - dark, 1e-3), 0, 1)
    out = hsv(hue % 1.0, 0.9 - 0.24 * t, 0.4 + 0.6 * t**0.8)
    out[~on] = 0.5

    img = bpy.data.images.new(f"{name}_rainbow", size, size, alpha=False)
    img.pixels.foreach_set(np.concatenate([out, np.ones((size, size, 1))], axis=-1).astype(np.float32).ravel())
    os.makedirs(OUT, exist_ok=True)
    img.filepath_raw = os.path.join(OUT, f"{name}.png")
    img.file_format = "PNG"
    img.save()
    return img, painted, [o for o in meshes if o.name.endswith("_glow")]


def card(name, img, painted, neon):
    m = bpy.data.materials.new("coat")
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    shader = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    nt.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.6
    for ob in painted:
        ob.data.materials.clear()
        ob.data.materials.append(m)
    groups = {ob.name[len(name) + 1 :]: [ob] for ob in painted + neon}
    glow = {part: CARD_GLOW[i % len(CARD_GLOW)] for i, part in enumerate(p for p in groups if p.endswith("_glow"))}
    lo, hi = kit._ground_dims(painted + neon)
    kit.beauty(f"{name}_rainbow", groups, lo, hi, glow)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    wanted = [a for a in args if not a.startswith("--")]
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        names = [n for n in json.load(f) if n.startswith("creature_")]
    for name in wanted:
        if name not in names:
            raise SystemExit(f"unknown creature {name}")
    for name in wanted or names:
        img, painted, neon = coat(name)
        print(f"[rainbow] {name}", flush=True)
        if "--card" in args:
            card(name, img, painted, neon)


main()
