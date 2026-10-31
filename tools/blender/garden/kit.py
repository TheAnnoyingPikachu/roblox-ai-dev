"""Shared Blender helpers for the Egg Garden assets (docs/assets/garden-blender-plan.md).

Reuses the proven Night kit (tools/blender/night/kit.py: materials, primitives, finalize, bake,
contact sheet) with Garden output folders, a bright toy-like preview and shell helpers.
Conventions as Night (1 unit = 1 stud, origin at base centre) except the front: Garden models face
Blender -Y, not +Y. NIGHT-010 measured uploaded models arriving with their Blender +Y side on
Roblox +Z at yaw 0, so a -Y front reaches Roblox -Z, the LookVector of an unrotated CFrame.

Glowing pieces go in a separate `glow` part (mesh `<asset>_glow`): the game leaves them untextured
and sets them to Neon in the colour listed under `glow` in manifest.json.
"""

import importlib.util
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

_spec = importlib.util.spec_from_file_location(
    "nightkit", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "night", "kit.py")
)
_night = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_night)

# Re-export the Night primitives and pipeline.
for _name in dir(_night):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_night, _name)

ROOT = _night.ROOT
OUT = os.path.join(ROOT, "build", "blender", "garden")
PREVIEWS = os.path.join(OUT, "previews")
_night.OUT = OUT
_night.PREVIEWS = PREVIEWS

# Palette (sRGB 0-255): src/garden/Plots.luau PASTELS and FLOWERS, EGG_COLOURS, toy brights.
CREAM = (255, 242, 215)
BLUSH = (255, 200, 220)
SKY = (200, 230, 255)
BUTTER = (255, 240, 180)
MINT = (210, 255, 210)
LILAC = (230, 210, 255)
ROSE = (255, 150, 190)
SUNNY = (255, 230, 120)
VIOLET = (190, 160, 255)
PEACH = (255, 170, 120)
CORAL = (255, 105, 105)
GRASS = (130, 205, 95)
TEAL = (95, 215, 205)
BERRY = (235, 70, 120)
WOODY = (190, 135, 90)
SNOW = (255, 253, 248)
INKY = (70, 50, 60)
GOLD_HI = (255, 225, 130)
GOLD_MID = (245, 185, 70)
GOLD_LO = (205, 130, 40)


# Materials -----------------------------------------------------------------------------------


def paint(name, stops, lo=0.0, hi=3.0, axis="Z", dots=(), bands=None, rough=0.4):
    """Baked colour: `stops` [(0-1, rgb), ...] along an object axis from lo to hi, then optional
    hard polka `dots` [(rgb, scale, size), ...] and `bands` (rgb, period in studs)."""
    if name in _night._materials:
        return _night._materials[name]
    m = mat(name, stops[0][1], kind="flat", rough=rough)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs[0])
    span = nt.nodes.new("ShaderNodeMapRange")
    span.inputs["From Min"].default_value = lo
    span.inputs["From Max"].default_value = hi
    nt.links.new(sep.outputs[axis], span.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], lin(stops[0][1])
    elements[1].position, elements[1].color = stops[-1][0], lin(stops[-1][1])
    for pos, rgb in stops[1:-1]:
        elements.new(pos).color = lin(rgb)
    nt.links.new(span.outputs["Result"], ramp.inputs["Fac"])
    colour = ramp.outputs["Color"]

    def over(mask, rgb):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(mask, mix.inputs[0])
        nt.links.new(colour, mix.inputs[6])
        mix.inputs[7].default_value = lin(rgb)
        return mix.outputs[2]

    for rgb, scale, size in dots:
        cells = nt.nodes.new("ShaderNodeTexVoronoi")
        cells.inputs["Scale"].default_value = scale
        nt.links.new(coord.outputs["Object"], cells.inputs["Vector"])
        hit = nt.nodes.new("ShaderNodeMath")
        hit.operation = "LESS_THAN"
        hit.inputs[1].default_value = size
        nt.links.new(cells.outputs["Distance"], hit.inputs[0])
        colour = over(hit.outputs[0], rgb)
    if bands:
        rgb, period = bands
        wave = nt.nodes.new("ShaderNodeMath")
        wave.operation = "MULTIPLY"
        wave.inputs[1].default_value = 2 * math.pi / period
        nt.links.new(sep.outputs[axis], wave.inputs[0])
        sine = nt.nodes.new("ShaderNodeMath")
        sine.operation = "SINE"
        nt.links.new(wave.outputs[0], sine.inputs[0])
        hit = nt.nodes.new("ShaderNodeMath")
        hit.operation = "GREATER_THAN"
        nt.links.new(sine.outputs[0], hit.inputs[0])
        colour = over(hit.outputs[0], rgb)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    return m


def flat(rgb, name=None, emit=0.0):
    return mat(name or f"flat_{rgb[0]}_{rgb[1]}_{rgb[2]}_{emit}", rgb, kind="flat", emit=emit, rough=0.45)


def glow(rgb):
    return flat(rgb, emit=3.0)


# The egg: every shell decoration is placed in shell coordinates ------------------------------


def egg_at(theta, v, lift=0.0, H=3.0, R=1.1):
    """Point and outward normal on the egg. theta: degrees round from the front (0 = -Y, 90 = +X),
    v: 0 bottom to 1 top. lift: studs along the normal."""
    phi = math.pi * min(max(v, 0.0), 1.0)
    c, s = math.cos(phi), math.sin(phi)
    r = R * s * (1 + 0.2 * c) / 1.019
    dr = R * (c * (1 + 0.2 * c) - 0.2 * s * s) / 1.019
    dz = H / 2 * s
    size = math.hypot(dr, dz)
    t = math.radians(theta)
    out = Vector((math.sin(t), -math.cos(t), 0))
    normal = out * (dz / size) + Vector((0, 0, -dr / size))
    return out * r + Vector((0, 0, H / 2 * (1 - c))) + normal * lift, normal


def shell(m, nu=28, nv=14, v0=0.0, v1=1.0, warp=None, name="shell", **egg):
    """Egg surface between v0 and v1 (numbers, or functions of theta for a jagged edge).
    warp(theta, v) lifts the surface in studs."""
    low = v0 if callable(v0) else (lambda t: v0)
    high = v1 if callable(v1) else (lambda t: v1)

    def fn(u, v):
        t = 360 * u
        w = low(t) + (high(t) - low(t)) * v
        return tuple(egg_at(t, w, warp(t, w) if warp else 0.0, **egg)[0])

    return surface(nu, nv, fn, m=m, name=name)


def stick(objs, theta, v, lift=0.0, spin=0.0, s=1.0, **egg):
    """Moves objects built at the origin (local +Z out) onto the shell."""
    p, n = egg_at(theta, v, lift, **egg)
    matrix = (
        Matrix.Translation(p)
        @ Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
        @ rot_z(spin)
        @ Matrix.Scale(s, 4)
    )
    for ob in objs if isinstance(objs, (list, tuple)) else [objs]:
        ob.data.transform(matrix)
    return objs


def ridge(path, width, height, m, name="ridge", **egg):
    """Raised relief on the shell along [(theta, v), ...]. width: studs, or one per point. Closed
    so the normals recalculate reliably."""
    widths = width if isinstance(width, (list, tuple)) else [width] * len(path)
    pts = [egg_at(t, v, **egg) for t, v in path]
    bm = bmesh.new()
    rows = []
    for i, (p, n) in enumerate(pts):
        along = pts[min(i + 1, len(pts) - 1)][0] - pts[max(i - 1, 0)][0]
        side = along.cross(n).normalized() * max(widths[i], 0.004)
        rows.append([bm.verts.new(p + side - n * 0.03), bm.verts.new(p + n * height), bm.verts.new(p - side - n * 0.03)])
    for a, b in zip(rows, rows[1:]):
        for k in range(3):
            j = (k + 1) % 3
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(rows[0])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m)


# Toy parts, built at the origin facing local +Z ---------------------------------------------


def _fans(rim, top, bottom, m, name):
    bm = bmesh.new()
    ring = [bm.verts.new(p) for p in rim]
    a, b = bm.verts.new(top), bm.verts.new(bottom)
    for i, v in enumerate(ring):
        w = ring[(i + 1) % len(ring)]
        bm.faces.new((v, w, a))
        bm.faces.new((w, v, b))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m)


def star(r, m, points=5, inner=0.45, depth=None, name="star"):
    """Faceted gem star (20 tris for 5 points)."""
    depth = r * 0.42 if depth is None else depth
    rim = []
    for i in range(points * 2):
        a = math.pi * i / points + math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        rim.append((rr * math.cos(a), rr * math.sin(a), 0))
    return _fans(rim, (0, 0, depth), (0, 0, -depth * 0.5), m, name)


def flower(r, petal, heart, lobes=6, name="flower"):
    """One-piece lobed flower with a domed heart."""
    n = lobes * 4
    rim = []
    for i in range(n):
        a = 2 * math.pi * i / n
        f = 0.5 + 0.5 * abs(math.cos(lobes * a / 2)) ** 0.6
        rim.append((r * f * math.cos(a), r * f * math.sin(a), r * 0.22 * f))
    body = _fans(rim, (0, 0, r * 0.03), (0, 0, -r * 0.2), petal, name)
    dome = lathe([(r * 0.36, r * 0.03), (r * 0.3, r * 0.2), (0, r * 0.3)], m=heart, n=8, name=f"{name}_heart")
    return [body, dome]


def leaf(length, width, m, droop=0.25, name="leaf"):
    """Curved blade along +X, flattened to a thin lens."""
    pts, radii = [], []
    for i in range(7):
        s = i / 6
        pts.append((length * s, 0, length * droop * math.sin(s * math.pi * 0.8)))
        radii.append(width * math.sin(s * math.pi) ** 0.7)
    ob = tube(pts, radii, m=m, n=6, name=name)
    ob.data.transform(Matrix.Diagonal((1, 1, 0.3, 1)))
    return ob


def blade(root, out, height, r, m, name="blade"):
    """Grass blade: 3-sided taper from root, curving along the unit vector `out`."""
    root = Vector(root)
    up = Vector((0, 0, 1))
    pts = [root, root + up * height * 0.55 + out * height * 0.14, root + up * height + out * height * 0.5]
    return tube(pts, [r, r * 0.62, 0], m=m, n=3, name=name)


def puff(r, loc, m, scale=(1, 1, 0.8), name="puff"):
    """Round cloud or bush lump (80 tris; fine enough to smooth-shade)."""
    return ico(r, loc, m=m, scale=scale, subdiv=2, name=name)


def mushroom(r, h, cap, stem, name="mushroom"):
    """Stubby toy mushroom standing on local z = 0."""
    return [
        lathe([(r * 0.42, 0), (r * 0.34, h * 0.5), (r * 0.42, h * 0.8)], m=stem, n=8, name=f"{name}_stem"),
        lathe(
            [(r * 0.5, h * 0.72), (r * 0.98, h * 0.72), (r, h * 0.86), (r * 0.78, h * 1.12), (r * 0.36, h * 1.32), (0, h * 1.38)],
            m=cap,
            n=12,
            name=f"{name}_cap",
        ),
    ]


def sharpen(ob):
    """Marks every edge sharp so a low-poly gem keeps its facets through finalize."""
    for edge in ob.data.edges:
        edge.use_edge_sharp = True
    return ob


def facet(ob, mats):
    """Gem look: a fixed pre-lit shade per face (mats run bright to dark), so the cut reads under
    any Roblox lighting. Call once the object is in its final place."""
    light = Vector((-0.45, -0.75, 0.5)).normalized()
    ob.data.materials.clear()
    for m in mats:
        ob.data.materials.append(m)
    last = len(mats) - 1
    for poly in ob.data.polygons:
        lit = (poly.normal.dot(light) + 1) / 2
        poly.material_index = min(last, int((1 - lit) * (last + 1)))
    return sharpen(ob)


# Preview: a bright toy shelf instead of the Night slate ---------------------------------------


def _studio(scene, ground_rgb=(214, 240, 226)):
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = scene.world or bpy.data.worlds.new("garden")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = lin((190, 226, 250))
    bg.inputs["Strength"].default_value = 0.8

    def sun(name, energy, rot):
        light = bpy.data.lights.new(name, "SUN")
        light.color = lin((255, 246, 232))[:3]
        light.energy = energy
        light.angle = math.radians(24)
        ob = bpy.data.objects.new(name, light)
        ob.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(ob)

    sun("key", 2.3, (55, 0, -35))
    sun("fill", 0.5, (65, 0, 70))
    return mat("pv_ground", ground_rgb, kind="flat")


def _glow_material(baked):
    """Stands in for Roblox Neon on `_glow` parts in the previews."""
    neon = baked.copy()
    nt = neon.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.9
    return neon


def preview(name, parts, lo, hi):
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
    ground_mat = _studio(scene)

    for p in parts:
        if p.name.endswith("_glow"):
            p.data.materials[0] = _glow_material(p.data.materials[0])

    centre = (lo + hi) / 2
    size = max((hi - lo).length, 1)
    cyl(size * 2, 0.02, (centre.x, centre.y, -0.011), m=ground_mat, n=48)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    # Front is -Y: look at it from the front, a little to the left, a little above.
    direction = Vector((-0.42, -1.0, 0.42)).normalized()
    cam.location = centre + direction * size * 3
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for x in (lo.x, hi.x):
        for y in (lo.y, hi.y):
            for z in (lo.z, hi.z):
                p = inv @ Vector((x, y, z))
                xs.append(p.x)
                ys.append(p.y)
    extent = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.14
    cam_data.ortho_scale = extent
    cam_data.clip_end = size * 10
    cam.location = cam.matrix_world @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
    scene.camera = cam

    text_data = bpy.data.curves.new("label", "FONT")
    text_data.body = name
    text_data.size = extent * 0.05
    label = bpy.data.objects.new("label", text_data)
    label.data.materials.append(mat("pv_label", (70, 60, 90), kind="flat", emit=1.0))
    scene.collection.objects.link(label)
    label.parent = cam
    label.location = (-extent / 2 + extent * 0.03, -extent / 2 + extent * 0.03, -size * 0.5)

    scene.render.filepath = os.path.join(PREVIEWS, f"{name}.png")
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


_night.preview = preview
