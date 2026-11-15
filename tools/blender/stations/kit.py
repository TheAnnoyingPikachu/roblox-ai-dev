"""Blender helpers for the Animal Stations creatures.

Reuses the Egg Garden kit (tools/blender/garden/kit.py: fused toy bodies, the kit face, painted
skin, HD bake) with Stations output folders. What is new here: creatures are jointed. A creature
is several meshes (body, head, four legs, tail) that the game joins with Motor6Ds and animates, so
build.py also records where each joint is. The preview renders four views, with `_glow` parts in
their Neon colour.

Conventions as Garden: 1 unit = 1 stud, standing on z = 0, facing Blender -Y (Roblox -Z).
"""

import importlib.util
import math
import os

import bpy
import numpy as np
from mathutils import Vector

_spec = importlib.util.spec_from_file_location(
    "gardenkit", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "garden", "kit.py")
)
_garden = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_garden)

for _name in dir(_garden):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_garden, _name)

_night = _garden._night
ROOT = _garden.ROOT
OUT = os.path.join(ROOT, "build", "blender", "stations")
PREVIEWS = os.path.join(OUT, "previews")
for _module in (_garden, _night):
    _module.OUT = OUT
    _module.PREVIEWS = PREVIEWS

# Neon colour (sRGB) for `_glow` parts in the previews; build.py sets it per asset.
GLOW_RGB = (255, 150, 40)

# Camera directions (from the model towards the camera). The first is the contact-sheet view.
VIEWS = (
    ("", (-0.55, -1.0, 0.4)),
    ("_side", (-1.0, -0.1, 0.16)),
    ("_front", (0.0, -1.0, 0.14)),
    ("_back", (0.62, 1.0, 0.42)),
)


def spline(points, radii, steps):
    """steps + 1 (point, radius) samples on a Catmull-Rom curve through points."""
    p = [Vector(q) for q in points]
    p = [2 * p[0] - p[1]] + p + [2 * p[-1] - p[-2]]
    spans = len(points) - 1
    out = []
    for i in range(steps + 1):
        t = i / steps * spans
        j = min(int(t), spans - 1)
        u = t - j
        a, b, c, d = p[j : j + 4]
        q = 0.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (3 * b - a - 3 * c + d) * u**3)
        out.append((q, radii[j] + (radii[j + 1] - radii[j]) * u))
    return out


def horn(points, radii, m, n=14, steps=14, name="horn"):
    """A smooth curved horn (or tail) through `points` with the given radii; 0 ends in a point."""
    samples = spline(points, radii, steps)
    return _garden.tube([p for p, _ in samples], [r for _, r in samples], m=m, n=n, name=name)


def vein(target, points, r, m, lift=0.012, name="vein"):
    """A thin raised line along `target`'s real surface through (centre, direction) rays, tapering
    to nothing at both ends: glowing cracks."""
    pts = []
    for centre, d in points:
        p, n = _garden.land(target, centre, d)
        pts.append(p + n * lift)
    last = len(pts) - 1
    radii = [r * math.sin(math.pi * (0.12 + 0.88 * i / last)) ** 0.6 if 0 < i < last else 0.0 for i in range(len(pts))]
    return _garden.tube(pts, radii, m=m, n=6, name=name)


def preview(name, parts, lo, hi):
    """Four views on the Garden toy shelf; `_glow` parts shine in GLOW_RGB."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    try:
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.film_transparent = False
    ground = _garden._studio(scene)
    neon = _garden.mat("pv_neon", GLOW_RGB, kind="flat", emit=2.2, rough=0.4)
    for p in parts:
        if p.name.endswith("_glow"):
            p.data.materials.clear()
            p.data.materials.append(neon)

    centre = (lo + hi) / 2
    size = max((hi - lo).length, 1)
    _garden.cyl(size * 2, 0.02, (centre.x, centre.y, -0.011), m=ground, n=48)
    os.makedirs(PREVIEWS, exist_ok=True)
    scene.render.image_settings.file_format = "PNG"
    for suffix, direction in VIEWS:
        cam_data = bpy.data.cameras.new("cam")
        cam_data.type = "ORTHO"
        cam = bpy.data.objects.new("cam", cam_data)
        scene.collection.objects.link(cam)
        direction = Vector(direction).normalized()
        cam.location = centre + direction * size * 3
        cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        inv = cam.matrix_world.inverted()
        xs, ys = [], []
        for x in (lo.x, hi.x):
            for y in (lo.y, hi.y):
                for z in (lo.z, hi.z):
                    q = inv @ Vector((x, y, z))
                    xs.append(q.x)
                    ys.append(q.y)
        cam_data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.14
        cam_data.clip_end = size * 10
        cam.location = cam.matrix_world @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
        scene.camera = cam
        scene.render.filepath = os.path.join(PREVIEWS, f"{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)


BEAUTY = os.path.join(OUT, "beauty")


def _pixels(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[..., :3]


def _bloom(rgb):
    """A soft glow over the brightest parts, standing in for Roblox's bloom on Neon and pale colours."""
    lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    small = (rgb * np.clip((lum - 0.72) / 0.2, 0, 1)[..., None])[::4, ::4]
    out = rgb
    for sigma, strength in ((3, 0.6), (16, 0.9)):
        halo = np.stack([_night._blur(small[..., c], sigma) for c in range(3)], axis=-1)
        halo = np.repeat(np.repeat(halo, 4, axis=0), 4, axis=1)[: rgb.shape[0], : rgb.shape[1]]
        halo = np.stack([_night._blur(halo[..., c], 2) for c in range(3)], axis=-1)
        out = 1 - (1 - out) * (1 - np.clip(halo * strength, 0, 1))
    return out


def beauty(name, groups, lo, hi):
    """A presentation card of one asset, not a build output: a three-quarter hero shot on a stone
    pedestal over front, side and back views, with `_glow` parts shining and a bloom on top.
    Written to build/blender/stations/beauty/<name>.png."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    try:
        scene.eevee.taa_render_samples = 64
    except AttributeError:
        pass
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = scene.world or bpy.data.worlds.new("beauty")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    # the camera sees a blue sky; the model is lit by a warm white one, so yellows stay yellow
    nt = world.node_tree
    sky = next(n for n in nt.nodes if n.type == "BACKGROUND")
    height, ramp = nt.nodes.new("ShaderNodeSeparateXYZ"), nt.nodes.new("ShaderNodeValToRGB")  # pale at the horizon
    nt.links.new(nt.nodes.new("ShaderNodeTexCoord").outputs["Generated"], height.inputs[0])
    nt.links.new(height.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color, ramp.color_ramp.elements[1].color = _garden.lin((196, 228, 250)), _garden.lin((84, 150, 226))
    ramp.color_ramp.elements[1].position = 0.45
    nt.links.new(ramp.outputs["Color"], sky.inputs["Color"])
    ambient = nt.nodes.new("ShaderNodeBackground")
    ambient.inputs["Color"].default_value = _garden.lin((255, 240, 218))
    ambient.inputs["Strength"].default_value = 0.5
    path, both = nt.nodes.new("ShaderNodeLightPath"), nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(path.outputs["Is Camera Ray"], both.inputs[0])
    nt.links.new(ambient.outputs[0], both.inputs[1])
    nt.links.new(sky.outputs[0], both.inputs[2])
    nt.links.new(both.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_WORLD").inputs[0])

    neon = _garden.mat("pv_neon", GLOW_RGB, kind="flat", emit=2.0, rough=0.4)
    for part, objs in groups.items():
        if part.endswith("_glow"):
            for ob in objs:
                ob.data.materials.clear()
                ob.data.materials.append(neon)

    centre = (lo + hi) / 2
    r = max(hi.x - lo.x, hi.y - lo.y) * 0.52
    stone = _garden.mat("pv_stone", (132, 134, 146), kind="flat", rough=0.9)
    gold = _garden.mat("pv_gold", (255, 206, 70), kind="flat", emit=1.2)
    grass = _garden.mat("pv_grass", (84, 150, 72), kind="flat", rough=1.0)
    _garden.cyl(r * 40, 0.02, (centre.x, centre.y, -r * 0.09), m=grass, n=48)
    _garden.cyl(r, r * 0.08, (centre.x, centre.y, -r * 0.04 - 0.002), m=stone, n=14)
    for i, (radius, m) in enumerate(((0.9, gold), (0.84, stone), (0.7, gold), (0.655, stone))):  # two glowing rings
        _garden.cyl(r * radius, 0.002 * r, (centre.x, centre.y, 0.002 * r * i), m=m, n=14)

    def sun(label, energy, source, rgb):
        light = bpy.data.lights.new(label, "SUN")
        light.color = _garden.lin(rgb)[:3]
        light.energy = energy
        light.angle = math.radians(12)
        ob = bpy.data.objects.new(label, light)
        ob.rotation_euler = (-Vector(source)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(ob)

    sun("key", 2.0, (-1.2, -0.3, 1.2), (255, 244, 226))
    sun("rim", 1.2, (0.9, 0.9, 0.6), (255, 226, 170))
    sun("fill", 0.5, (-0.3, -1.0, 0.2), (200, 220, 255))
    os.makedirs(BEAUTY, exist_ok=True)

    def shot(suffix, direction, w, h, lens=60, fill=1.0):
        cam_data = bpy.data.cameras.new("cam")
        cam_data.lens = lens
        cam = bpy.data.objects.new("cam", cam_data)
        scene.collection.objects.link(cam)
        d = Vector(direction).normalized()
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.location = centre
        bpy.context.view_layer.update()
        right, up = cam.matrix_world.col[0].xyz, cam.matrix_world.col[1].xyz
        tx = 18 / lens * (1 if w >= h else w / h)
        ty = tx * h / w
        dist = 0.0
        for x in (lo.x, hi.x):  # far enough back for the whole box to show
            for y in (lo.y, hi.y):
                for z in (lo.z, hi.z):
                    q = Vector((x, y, z)) - centre
                    dist = max(dist, abs(q.dot(right)) * fill / tx + q.dot(d), abs(q.dot(up)) * fill / ty + q.dot(d))
        cam.location = centre + d * dist
        cam_data.clip_end = dist * 60
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = w, h
        scene.render.filepath = os.path.join(BEAUTY, f"{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)
        return _bloom(_pixels(scene.render.filepath))

    hero = shot("_hero", (-0.9, -1.0, 0.22), 1536, 1024, fill=0.8)
    views = [shot(s, d, 512, 512, fill=0.9) for s, d in (("_front", (0.0, -1.0, 0.12)), ("_side", (-1.0, -0.08, 0.12)), ("_back", (0.55, 1.0, 0.3)))]
    card = np.concatenate([np.concatenate(views, axis=1), hero], axis=0)  # image rows run bottom to top
    rgba = np.concatenate([card, np.ones((*card.shape[:2], 1), dtype=np.float32)], axis=-1)
    out = bpy.data.images.new("card", card.shape[1], card.shape[0], alpha=False)
    out.pixels.foreach_set(rgba.astype(np.float32).ravel())
    out.filepath_raw = os.path.join(BEAUTY, f"{name}.png")
    out.file_format = "PNG"
    out.save()


_night.preview = preview
_garden.preview = preview
