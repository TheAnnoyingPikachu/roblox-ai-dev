"""Shared Blender helpers for the Hundred Demon Night assets (docs/assets/night-blender-plan.md).

Every asset script builds plain mesh objects with these primitives (world-space geometry, identity
object transforms), then `finalize` joins, centres, UV-unwraps, bakes, exports and renders them.
Conventions: 1 Blender unit = 1 stud, front faces +Y (exported as Roblox -Z), origin at base centre.
"""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "build", "blender", "night")
PREVIEWS = os.path.join(OUT, "previews")
TEX = 1024

# Palette from src/night/Arena.luau 22-29 and src/night/Enemies.luau 149-153 (sRGB 0-255).
INK = (22, 18, 26)
VERMILION = (196, 40, 28)
WOOD = (110, 70, 45)
DARKWOOD = (70, 46, 32)
DECK = (150, 105, 70)
SLATE = (88, 86, 96)
STONE = (150, 148, 140)
PURPLE = (170, 60, 255)
WARM = (255, 170, 90)
PAPER = (245, 232, 200)
LACQUER = (120, 22, 26)
GOLD = (220, 175, 60)
EMBER = (255, 60, 40)
ROPE = (214, 190, 120)
ROOF = (46, 50, 70)
BONE = (235, 228, 210)
WISP = (200, 235, 255)
WISP_DEEP = (90, 160, 255)
PINK = (255, 183, 210)
BARK = (78, 52, 46)
LEAF = (40, 90, 50)
WHITE = (250, 248, 244)
TONGUE = (220, 40, 60)


# Scene ---------------------------------------------------------------------------------------


def reset():
    for collection in (
        bpy.data.objects,
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.lights,
        bpy.data.cameras,
        bpy.data.curves,
        bpy.data.textures,
        bpy.data.worlds,
    ):
        for item in list(collection):
            collection.remove(item)
    _materials.clear()


def lin(rgb):
    """sRGB 0-255 to linear RGBA."""

    def ch(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (ch(rgb[0]), ch(rgb[1]), ch(rgb[2]), 1.0)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(rgb, f):
    return tuple(max(0, min(255, c * f)) for c in rgb)


# Materials -----------------------------------------------------------------------------------

_materials = {}


def mat(name, rgb, var=0.12, scale=2.0, kind="noise", emit=0.0, rgb2=None, rough=0.6):
    """Simple bake-friendly material: base colour with procedural variation, optional glow.

    kind: "flat", "noise" (mottled stone/paper), "wood" (grain bands along z), "grad" (rgb at the
    bottom to rgb2 at the top of the object, in object z).
    """
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        nodes.clear()
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        out = nodes.new("ShaderNodeOutputMaterial")
        links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Roughness"].default_value = rough
    lo = shade(rgb, 1 - var)
    hi = shade(rgb, 1 + var) if rgb2 is None else rgb2
    if kind == "flat":
        bsdf.inputs["Base Color"].default_value = lin(rgb)
    else:
        coord = nodes.new("ShaderNodeTexCoord")
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = lin(lo)
        ramp.color_ramp.elements[1].color = lin(hi)
        if kind == "noise":
            tex = nodes.new("ShaderNodeTexNoise")
            tex.inputs["Scale"].default_value = scale
            tex.inputs["Detail"].default_value = 6
            links.new(coord.outputs["Object"], tex.inputs["Vector"])
            ramp.color_ramp.elements[0].position = 0.3
            ramp.color_ramp.elements[1].position = 0.7
            links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        elif kind == "wood":
            tex = nodes.new("ShaderNodeTexWave")
            tex.inputs["Scale"].default_value = scale
            tex.inputs["Distortion"].default_value = 6
            tex.inputs["Detail"].default_value = 3
            links.new(coord.outputs["Object"], tex.inputs["Vector"])
            links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        elif kind == "grad":
            sep = nodes.new("ShaderNodeSeparateXYZ")
            links.new(coord.outputs["Generated"], sep.inputs[0])
            links.new(sep.outputs["Z"], ramp.inputs["Fac"])
            ramp.color_ramp.elements[0].color = lin(rgb)
            ramp.color_ramp.elements[1].color = lin(rgb2 or rgb)
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = lin(hi if kind != "flat" else rgb)
        bsdf.inputs["Emission Strength"].default_value = emit
    _materials[name] = m
    return m


# Geometry ------------------------------------------------------------------------------------


def _xf(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    r = [math.radians(a) for a in rot]
    return (
        Matrix.Translation(Vector(loc))
        @ Matrix.Rotation(r[2], 4, "Z")
        @ Matrix.Rotation(r[1], 4, "Y")
        @ Matrix.Rotation(r[0], 4, "X")
        @ Matrix.Diagonal((*scale, 1))
    )


def _obj(name, bm, material, matrix=None):
    if matrix is not None:
        bm.transform(matrix)
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material is not None:
        me.materials.append(material)
    return ob


def _bevel(bm, width, segments=1):
    if width > 0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.verts) + list(bm.edges),
            offset=width,
            offset_type="OFFSET",
            segments=segments,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.0, seg=1, name="box"):
    """Box of `size` centred on loc. Bevel is in studs, applied before rotation."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bm.transform(Matrix.Diagonal((*size, 1)))
    _bevel(bm, min(bevel, min(size) * 0.45), seg)
    return _obj(name, bm, m, _xf(loc, rot))


def cyl(r, h, loc=(0, 0, 0), rot=(0, 0, 0), m=None, n=16, r2=None, bevel=0.0, name="cyl"):
    """Cylinder (or cone/frustum with r2) along local z, centred on loc."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r, radius2=r if r2 is None else r2, depth=h)
    _bevel(bm, bevel, 1)
    return _obj(name, bm, m, _xf(loc, rot))


def sphere(r, loc=(0, 0, 0), rot=(0, 0, 0), m=None, scale=(1, 1, 1), seg=16, rings=10, name="sphere"):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    return _obj(name, bm, m, _xf(loc, rot, scale))


def ico(r, loc=(0, 0, 0), m=None, scale=(1, 1, 1), subdiv=2, rot=(0, 0, 0), name="ico"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    return _obj(name, bm, m, _xf(loc, rot, scale))


def lathe(profile, loc=(0, 0, 0), rot=(0, 0, 0), m=None, n=16, scale=(1, 1, 1), name="lathe"):
    """Surface of revolution around local z. profile: [(radius, z), ...] bottom to top.
    Ends with radius 0 close to a point; others get a flat cap."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append(
                [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z)) for i in range(n)]
            )
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(n):
            j = (i + 1) % n
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m, _xf(loc, rot, scale))


def tube(points, radii, m=None, n=8, cap=True, name="tube"):
    """Swept tube along a polyline of world points; radii is a number or one per point.
    A radius of 0 at an end makes a point (horns, claws, flame tips)."""
    pts = [Vector(p) for p in points]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    bm = bmesh.new()
    tangents = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tangents.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangents[0].cross(ref).normalized()
    rings = []
    for i, p in enumerate(pts):
        t = tangents[i]
        normal = (normal - t * normal.dot(t)).normalized()  # parallel transport
        binormal = t.cross(normal)
        r = radii[i]
        if r <= 1e-6:
            rings.append([bm.verts.new(p)])
            continue
        rings.append(
            [
                bm.verts.new(p + (normal * math.cos(2 * math.pi * k / n) + binormal * math.sin(2 * math.pi * k / n)) * r)
                for k in range(n)
            ]
        )
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[j], b[0]))
            else:
                bm.faces.new((a[k], a[j], b[j], b[k]))
    if cap:
        if len(rings[0]) > 1:
            bm.faces.new(list(reversed(rings[0])))
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m)


def surface(nu, nv, fn, m=None, thickness=0.0, name="surface"):
    """Grid surface: fn(u, v) -> (x, y, z) for u, v in [0, 1]; optional solidify thickness."""
    bm = bmesh.new()
    grid = [[bm.verts.new(fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    ob = _obj(name, bm, m)
    if thickness:
        mod = ob.modifiers.new("solid", "SOLIDIFY")
        mod.thickness = thickness
        mod.offset = 0
    return ob


def poly(points2d, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.0, name="poly"):
    """Extruded flat shape: points2d in local x/z, extruded `depth` along local y (centred)."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, -depth / 2, z)) for x, z in points2d]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in ext["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co.y += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _bevel(bm, bevel, 1)
    return _obj(name, bm, m, _xf(loc, rot))


# Modifiers (applied in finalize) --------------------------------------------------------------


def mirror_x(ob):
    mod = ob.modifiers.new("mirror", "MIRROR")
    mod.use_axis[0] = True
    mod.use_mirror_merge = False
    return ob


def subsurf(ob, levels=1):
    mod = ob.modifiers.new("subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return ob


def displace(ob, strength, size=1.0, kind="CLOUDS", seed=0):
    tex = bpy.data.textures.new(f"disp{len(bpy.data.textures)}", kind)
    if kind == "CLOUDS":
        tex.noise_scale = size
    elif kind == "VORONOI":
        tex.noise_scale = size
    mod = ob.modifiers.new("disp", "DISPLACE")
    mod.texture = tex
    mod.strength = strength
    mod.mid_level = 0.5
    mod.texture_coords = "GLOBAL"
    if seed:
        # Shift the sampling point so copies of one shape do not look identical.
        empty = bpy.data.objects.new(f"dispoff{seed}", None)
        empty.location = (seed * 7.3, seed * 3.1, seed * 5.7)
        bpy.context.scene.collection.objects.link(empty)
        mod.texture_coords = "OBJECT"
        mod.texture_coords_object = empty
    return ob


def bevel_mod(ob, width, segments=1, angle=40):
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    return ob


def copy(ob, matrix):
    """Duplicate (with its modifiers applied later) and transform by a world matrix."""
    dup = ob.copy()
    dup.data = ob.data.copy()
    dup.data.transform(matrix)
    bpy.context.scene.collection.objects.link(dup)
    return dup


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def move(x, y, z):
    return Matrix.Translation((x, y, z))


# Finalize: join, centre, UV, bake, export, preview ------------------------------------------


def _select(objs, active=None):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def _tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def _join(name, objs):
    objs = [o for o in objs if o.type == "MESH"]
    _select(objs)
    bpy.ops.object.convert(target="MESH")
    objs = [o for o in bpy.context.selected_objects]
    _select(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.0001)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def _bake_image(name):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    img.generated_color = (0, 0, 0, 1)
    return img


def _bake(objs, size):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 8
    if scene.world is None:
        scene.world = bpy.data.worlds.new("bake")
    scene.world.light_settings.distance = max(0.4, min(4.0, size * 0.12))
    images = {k: _bake_image(f"bake_{k}") for k in ("col", "ao", "emit")}
    nodes = []
    for ob in objs:
        for slot in ob.material_slots:
            m = slot.material
            node = m.node_tree.nodes.get("BakeTarget")
            if node is None:
                node = m.node_tree.nodes.new("ShaderNodeTexImage")
                node.name = "BakeTarget"
                nodes.append(node)
            m.node_tree.nodes.active = node
    _select(objs)
    for kind, bake_type, samples in (("col", "DIFFUSE", 1), ("ao", "AO", 24), ("emit", "EMIT", 1)):
        for node in nodes:
            node.image = images[kind]
        scene.cycles.samples = samples
        if bake_type == "DIFFUSE":
            bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=8)
        else:
            bpy.ops.object.bake(type=bake_type, use_clear=True, margin=8)

    def px(img):
        a = np.empty(TEX * TEX * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        return a.reshape(TEX, TEX, 4)

    col, ao, emit = px(images["col"]), px(images["ao"]), px(images["emit"])
    out = col.copy()
    out[..., :3] = np.clip(col[..., :3] * (0.5 + 0.5 * ao[..., :1]) + emit[..., :3] * 0.6, 0, 1)
    out[..., 3] = 1
    final = bpy.data.images.new("final", TEX, TEX, alpha=False)
    final.pixels.foreach_set(out.ravel())
    return final


def _ground_dims(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def finalize(name, groups, budget, center=True):
    """groups: {part: [objects]} or a list (one part named after the asset).
    Returns stats for the manifest."""
    if isinstance(groups, (list, tuple)):
        groups = {"": groups}
    parts = []
    for part, objs in groups.items():
        parts.append(_join(f"{name}_{part}" if part else name, objs))
    # Drop helper empties used by displace modifiers.
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY":
            bpy.data.objects.remove(o)

    total = sum(_tris(p) for p in parts)
    if total > budget:
        ratio = budget / total * 0.97
        for p in parts:
            mod = p.modifiers.new("decimate", "DECIMATE")
            mod.ratio = ratio
            _select([p])
            bpy.ops.object.modifier_apply(modifier=mod.name)
        total = sum(_tris(p) for p in parts)

    lo, hi = _ground_dims(parts)
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)) if center else Vector((0, 0, -lo.z))
    for p in parts:
        p.data.transform(Matrix.Translation(offset))
        p.matrix_world = Matrix.Identity(4)
        bm = bmesh.new()
        bm.from_mesh(p.data)
        bm.to_mesh(p.data)
        bm.free()
        _select([p])
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
        except Exception:
            bpy.ops.object.shade_flat()
    lo, hi = _ground_dims(parts)
    dims = hi - lo

    # One shared UV atlas for all parts.
    _select(parts)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0)
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")

    os.makedirs(PREVIEWS, exist_ok=True)
    final = _bake(parts, max(dims))
    png = os.path.join(OUT, f"{name}.png")
    final.filepath_raw = png
    final.file_format = "PNG"
    final.save()

    baked = bpy.data.materials.new(f"{name}_baked")
    try:
        baked.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in baked.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.75
    tex = baked.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png, check_existing=False)
    baked.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for p in parts:
        p.data.materials.clear()
        p.data.materials.append(baked)

    fbx = os.path.join(OUT, f"{name}.fbx")
    _select(parts)
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        path_mode="STRIP",
        embed_textures=False,
        add_leaf_bones=False,
        bake_anim=False,
    )
    preview(name, parts, lo, hi)
    return {
        "fbx": os.path.relpath(fbx, ROOT).replace("\\", "/"),
        "png": os.path.relpath(png, ROOT).replace("\\", "/"),
        "preview": os.path.relpath(os.path.join(PREVIEWS, f"{name}.png"), ROOT).replace("\\", "/"),
        # Roblox axes: x = width, y = height (Blender z), z = depth (Blender y).
        "size_studs": [round(dims.x, 2), round(dims.z, 2), round(dims.y, 2)],
        "tris": total,
        "parts": {p.name: _tris(p) for p in parts},
    }


# Preview ------------------------------------------------------------------------------------


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
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in type(scene.view_settings).bl_rna.properties["view_transform"].enum_items] else "Standard"

    world = scene.world or bpy.data.worlds.new("night")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = lin((34, 36, 70))
    bg.inputs["Strength"].default_value = 1.0

    centre = (lo + hi) / 2
    size = max((hi - lo).length, 1)

    # Dark slate ground disc at y = 0 shows whether the model stands on the ground.
    ground = cyl(size * 0.9, 0.02, (centre.x, centre.y, -0.011), m=mat("pv_ground", (36, 34, 46), kind="flat"), n=48)

    def sun(name, rgb, energy, rot):
        light = bpy.data.lights.new(name, "SUN")
        light.color = lin(rgb)[:3]
        light.energy = energy
        light.angle = math.radians(8)
        ob = bpy.data.objects.new(name, light)
        ob.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(ob)

    sun("key", (255, 200, 150), 3.2, (50, 0, 150))
    sun("rim", (120, 150, 255), 2.5, (60, 0, -30))
    sun("fill", (180, 170, 255), 0.8, (70, 0, 60))

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    direction = Vector((0.85, 1.25, 0.8)).normalized()
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
    extent = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.18
    cam_data.ortho_scale = extent
    cam_data.clip_end = size * 10
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    scene.camera = cam

    text_data = bpy.data.curves.new("label", "FONT")
    text_data.body = name
    text_data.size = extent * 0.055
    label = bpy.data.objects.new("label", text_data)
    label.data.materials.append(mat("pv_label", (255, 225, 170), kind="flat", emit=4.0))
    scene.collection.objects.link(label)
    label.parent = cam
    label.location = (-extent / 2 + extent * 0.03, -extent / 2 + extent * 0.03, -size * 0.5)

    scene.render.filepath = os.path.join(PREVIEWS, f"{name}.png")
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def contact_sheet(names, cols=6, tile=320):
    images = []
    for n in names:
        path = os.path.join(PREVIEWS, f"{n}.png")
        if os.path.exists(path):
            images.append(bpy.data.images.load(path, check_existing=False))
    if not images:
        return None
    rows = math.ceil(len(images) / cols)
    sheet = np.zeros((rows * tile, cols * tile, 4), dtype=np.float32)
    sheet[..., 3] = 1
    for i, img in enumerate(images):
        w, h = img.size
        a = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        a = a.reshape(h, w, 4)
        ys = (np.arange(tile) * h / tile).astype(int)
        xs = (np.arange(tile) * w / tile).astype(int)
        small = a[ys][:, xs]
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * tile  # Blender pixel rows start at the bottom
        sheet[y0 : y0 + tile, c * tile : (c + 1) * tile] = small
    out = bpy.data.images.new("contact", cols * tile, rows * tile, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    path = os.path.join(OUT, "contact_sheet.png")
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    return path
