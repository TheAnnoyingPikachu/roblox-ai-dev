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


_night.preview = preview
_garden.preview = preview
