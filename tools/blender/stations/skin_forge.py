"""Skins a whole ForgeGUI creature model (one mesh, never cut) to the Animal Stations rig (decision 0102).

blender --background --factory-startup --python tools/blender/stations/skin_forge.py -- <name> <source.glb> [--test]

The model keeps every face where ForgeGUI made it. What is added is a skeleton with our joints' names
(`body` the root, then `head`, `leg_fl`, `leg_fr`, `leg_bl`, `leg_br`, `tail`), each bone standing at
the point that piece turns on, and the skin: each vertex's weights come from where it is (`REGIONS`, per
asset, in the model's own measurements), blending across a band at each joint so long pieces (the
torso, the tail, the legs) bend there. A loose piece smaller than `small` takes its average weights, so
it moves whole. First `tidy` joins the vertices that sit at one spot (ForgeGUI exports every facet
loose), turns every face outwards and sets the shading. Writes build/blender/stations/<name>.fbx (armature and skinned mesh) and .png
(the model's own texture), the manifest entry (`skinned: true`, `joints` in the manifest's axes) and,
with --test, renders of a few bent poses to check every piece follows the right bone.

Facing: the source looks along Blender -Y with +X its left, as every Stations creature does.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

MANIFEST = os.path.join(HERE, "manifest.json")

# Per asset, in the source model's own units (Blender axes after the glTF import, before scaling):
# `length` the studs it is long (nose to tail), `joints` where each piece turns, `weights(p)` the bones a
# vertex at `p` follows ({ bone: weight }, summing to 1) and `small` the size under which an island moves
# whole.
def ramp(a, b, x):
    """0 at a, 1 at b, smooth between (a may be above b)."""
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lion_weights(p):
    """The ForgeGUI lion of 2026-11-19 ("Low poly, Game-ready, Stylized roblox lion with NO baseplate"):
    a big mane from the nose back to y -0.24, short front legs under it (paws at x 0.15, y -0.64), a
    slender body, staggered hind legs (paws at y 0.02 and 0.15) and a long tail with a big tuft."""
    tail = ramp(0.25, 0.31, p.y)
    head = ramp(-0.22, -0.32, p.y)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if abs(abs(p.x) - 0.14) < 0.12 and abs(p.y + 0.6) < 0.17:
        leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.19, -0.27, p.z)
    elif abs(abs(p.x) - 0.1) < 0.12 and -0.11 < p.y < 0.3:
        leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.14, -0.22, p.z)
    if leg and down > 0:  # the leg's share grows below the body
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def jackal_weights(p):
    """SHANNON's "Low-Poly Anubis with Egyptian Headdress" (ForgeGUI artifact d3835931), the Jackal: sandy,
    the head and headdress at y < -0.3, front legs at x +-0.095, y -0.25 (apart below z -0.1), wide hind
    legs at x +-0.135, y 0.12 (apart below z -0.09), and a tail that is a piece of its own behind."""
    tail = ramp(0.17, 0.22, p.y)
    head = ramp(-0.29, -0.35, p.y) * ramp(-0.08, 0.0, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if -0.33 < p.y < -0.15 and 0.03 < abs(p.x) < 0.15:
        leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.07, -0.13, p.z)
    elif 0.03 < p.y < 0.2 and 0.06 < abs(p.x) < 0.19:
        leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.06, -0.12, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def sphinx_weights(p):
    """SHANNON's "Sphinx variant" (ForgeGUI artifact dd7695be), the Sphinx Jackal: a sandy lion's body, the
    face, beard and striped headdress at y < -0.2, front legs at x +-0.12 with the paws reaching forward
    (apart below z -0.12), hind legs at x +-0.085, y 0.08 (apart below z -0.1), and a long tail hanging
    from y 0.18 to a tuft by the ground."""
    tail = ramp(0.17, 0.21, p.y)
    head = ramp(-0.17, -0.25, p.y) * ramp(-0.13, -0.06, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if -0.42 < p.y < -0.2 and 0.06 < abs(p.x) < 0.18:
        leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.12, -0.2, p.z)
    elif -0.01 < p.y < 0.18 and 0.03 < abs(p.x) < 0.15:
        leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.1, -0.17, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def tortoise_weights(p):
    """The ForgeGUI tortoise (job bfdcf1b3): a wide shell, the head out on a neck from y -0.31, short legs
    under the shell's sides (front y -0.3..0, hind y 0..0.17, |x| 0.07..0.25) leaving it below z -0.07,
    and a spiky tail along the ground from y 0.22."""
    head = ramp(-0.30, -0.345, p.y)
    tail = ramp(0.215, 0.26, p.y) * ramp(0.0, -0.04, p.z)
    w = {"body": (1 - head) * (1 - tail), "head": head, "tail": tail}
    leg, down = None, 0.0
    if 0.07 < abs(p.x) < 0.25:
        if -0.31 < p.y < 0.0:
            leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.07, -0.11, p.z)
        elif -0.02 < p.y < 0.17:  # lower: the shell's underside spans the back half at z -0.1
            leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.095, -0.13, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def pharaoh_weights(p):
    """SHANNON's "Anubis Guardian in Gold and Blue" (ForgeGUI artifact 518bf4a5), the Pharaoh Jackal:
    symmetric, the head and its headdress at y < -0.3, front legs at x +-0.11, y -0.29 (apart below
    z -0.12), hind legs at x +-0.12, y 0.08 (apart below z -0.1), small wings on the back (they ride on the
    body) and a long tail hanging behind from y 0.16."""
    tail = ramp(0.15, 0.2, p.y)
    head = ramp(-0.27, -0.34, p.y) * ramp(-0.06, 0.02, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if 0.06 < abs(p.x) < 0.17:
        if -0.37 < p.y < -0.18:
            leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.08, -0.15, p.z)
        elif -0.01 < p.y < 0.16:
            leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.07, -0.14, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


REGIONS = {
    "creature_jackal_pharaoh_forge": {
        "length": 9.1,  # the Blender Pharaoh Jackal's length (StationAssets.creature_jackal_pharaoh.size)
        "joints": {
            "body": (0.0, -0.08, 0.0),
            "head": (0.0, -0.3, 0.1),
            "leg_fl": (0.11, -0.26, -0.1),
            "leg_fr": (-0.11, -0.26, -0.1),
            "leg_bl": (0.1, 0.08, -0.07),
            "leg_br": (-0.1, 0.08, -0.07),
            "tail": (0.0, 0.16, -0.04),
        },
        "weights": pharaoh_weights,
        "small": 0.06,
        "notes": "Pharaoh Jackal: SHANNON's Anubis Guardian from ForgeGUI (artifact 518bf4a5), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_jackal_forge": {
        "length": 7.4,  # the Blender jackal's length (StationAssets.creature_jackal.size)
        "joints": {
            "body": (0.0, -0.06, 0.0),
            "head": (0.0, -0.3, 0.12),
            "leg_fl": (0.095, -0.25, -0.08),
            "leg_fr": (-0.095, -0.25, -0.08),
            "leg_bl": (0.12, 0.12, -0.07),
            "leg_br": (-0.12, 0.12, -0.07),
            "tail": (0.0, 0.19, -0.02),
        },
        "weights": jackal_weights,
        "small": 0.06,
        "notes": "Jackal: SHANNON's Anubis with Egyptian Headdress from ForgeGUI (artifact d3835931), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_jackal_sphinx_forge": {
        "length": 9.6,  # the Blender Sphinx Jackal's length (StationAssets.creature_jackal_sphinx.size)
        "joints": {
            "body": (0.0, -0.08, 0.0),
            "head": (0.0, -0.22, 0.05),
            "leg_fl": (0.12, -0.3, -0.13),
            "leg_fr": (-0.12, -0.3, -0.13),
            "leg_bl": (0.085, 0.08, -0.1),
            "leg_br": (-0.085, 0.08, -0.1),
            "tail": (0.0, 0.18, 0.0),
        },
        "weights": sphinx_weights,
        "small": 0.06,
        "notes": "Sphinx Jackal: SHANNON's Sphinx variant from ForgeGUI (artifact dd7695be), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_tortoise_forge": {
        "length": 10.1,  # the Blender tortoise's length (StationAssets.creature_tortoise.size)
        "joints": {
            "body": (0.0, -0.05, 0.0),
            "head": (0.0, -0.31, 0.0),
            "leg_fl": (0.15, -0.17, -0.08),
            "leg_fr": (-0.15, -0.17, -0.08),
            "leg_bl": (0.15, 0.07, -0.1),
            "leg_br": (-0.15, 0.07, -0.1),
            "tail": (0.0, 0.22, -0.09),
        },
        "weights": tortoise_weights,
        "small": 0.06,
        "tris": 5000,
        "shade": "smooth",
        "notes": "Tortoise: the ForgeGUI model (job bfdcf1b3), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_lion_forge": {
        "length": 13.0,  # the Blender lion's length (StationAssets.creature_lion.size)
        "joints": {
            "body": (0.0, -0.05, -0.1),
            "head": (0.0, -0.28, 0.0),
            "leg_fl": (0.14, -0.58, -0.2),
            "leg_fr": (-0.14, -0.58, -0.2),
            "leg_bl": (0.1, 0.09, -0.15),
            "leg_br": (-0.1, 0.09, -0.15),
            "tail": (0.0, 0.27, -0.07),
        },
        "weights": lion_weights,
        "small": 0.06,
        "shade": "flat",  # a low-poly model: every facet crisp
        "notes": "Lion: the ForgeGUI model (Low poly, Game-ready, Stylized roblox lion), one mesh, skinned to the Stations rig (decision 0102).",
    },
}


def tidy(me, weld, shade, turn=True):
    """ForgeGUI's faceted models come as thousands of loose pieces that mostly touch, a third of their faces
    turned inwards. Roblox draws only a face's front, so those show as holes. Join the vertices that sit at
    the same spot (`weld`, in the source's units; each face keeps its own UVs), then turn every face out:
    rays from its centre on each side, and the side more of them escape from is outside."""
    bm = bmesh.new()
    bm.from_mesh(me)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    flipped = 0
    for f in bm.faces:
        n = f.normal
        if n.length < 0.5:
            continue
        c = f.calc_center_median()
        a = n.orthogonal().normalized()
        b = n.cross(a)
        rays = [Vector((0, 0, 0))] + [(a * x + b * y) * 0.6 for x, y in ((1, 0), (-1, 0), (0, 1), (0, -1))]

        def escapes(side):
            out = 0
            for r in rays:
                d = (n * side + r).normalized()
                hit = tree.ray_cast(c + d * 1e-4, d)
                out += 1 if hit[0] is None else 0
            return out

        if turn and escapes(-1) > escapes(1):
            f.normal_flip()
            flipped += 1
    bm.normal_update()
    # shading: "flat" keeps every facet of a low-poly model crisp, "smooth" runs the light evenly over the
    # joined surface; the game draws the mesh two-sided (MeshPart.DoubleSided), so a thin piece shows from
    # behind too
    for f in bm.faces:
        f.smooth = shade == "smooth"
    for e in bm.edges:
        e.smooth = shade == "smooth"
    bm.to_mesh(me)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("TIDY verts", before, "->", len(me.vertices), "faces turned out", flipped, "tris", tris)
    if tris > 20000:
        raise RuntimeError(f"{tris} triangles is over Roblox's 20,000 for one mesh")


def roblox(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    name, src = args[0], args[1]
    test = "--test" in args
    spec = REGIONS[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"{name}: expected one mesh, found {[o.name for o in meshes]}")
    for o in list(bpy.context.scene.objects):  # nothing but the one mesh: no plates, lights or helpers
        if o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    body = meshes[0]
    body.name = f"{name}_body"
    body.data.name = f"{name}_body"
    body.parent = None
    body.data.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    # the file's own normals (one per facet, a third of them inward) would override any shading: drop them
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    tidy(body.data, spec.get("weld", 0.0005), spec.get("shade", "flat"), spec.get("turn", True))
    have = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if have > spec.get("tris", have):  # a dense model is thinned, so a crowd of them stays smooth
        thin = body.modifiers.new("thin", "DECIMATE")
        thin.ratio = spec["tris"] / have
        bpy.ops.object.modifier_apply(modifier=thin.name)
        print("THINNED", have, "->", sum(len(p.vertices) - 2 for p in body.data.polygons))

    # each vertex's weights from where it is; a small island takes its average, so it moves whole
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    weights = [spec["weights"](v.co) for v in bm.verts]
    seen = set()
    whole, islands = 0, 0
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, island = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            island.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        islands += 1
        ilo = Vector((min(bm.verts[i].co[k] for i in island) for k in range(3)))
        ihi = Vector((max(bm.verts[i].co[k] for i in island) for k in range(3)))
        if (ihi - ilo).length < spec["small"]:
            whole += 1
            mean = {}
            for i in island:
                for k, w in weights[i].items():
                    mean[k] = mean.get(k, 0) + w / len(island)
            for i in island:
                weights[i] = mean
    bm.free()
    counts = {}
    for w in weights:
        top = max(w, key=w.get)
        counts[top] = counts.get(top, 0) + 1
    print("ISLANDS", islands, "moving whole", whole, "VERTS BY MAIN BONE", counts)

    # to studs, standing on the ground under its middle
    lo = Vector((min(v.co[k] for v in body.data.vertices) for k in range(3)))
    hi = Vector((max(v.co[k] for v in body.data.vertices) for k in range(3)))
    scale = spec["length"] / (hi.y - lo.y)
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    place = Matrix.Scale(scale, 4) @ Matrix.Translation(offset)
    body.data.transform(place)
    joints = {k: place @ Vector(j) for k, j in spec["joints"].items()}

    # the skeleton: every bone stands straight up from its joint, the root's children all of it
    arm_data = bpy.data.armatures.new(f"{name}_rig")
    arm = bpy.data.objects.new(f"{name}_rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_data.edit_bones.new("body")
    root.head, root.tail, root.roll = joints["body"], joints["body"] + Vector((0, 0, 1)), 0
    for k, j in joints.items():
        if k == "body":
            continue
        b = arm_data.edit_bones.new(k)
        b.head, b.tail, b.roll = j, j + Vector((0, 0, 1)), 0
        b.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")

    # the skin
    groups = {k: body.vertex_groups.new(name=k) for k in joints}
    for v, w in zip(body.data.vertices, weights):
        for bone, x in w.items():
            groups[bone].add([v.index], x, "REPLACE")
    body.parent = arm
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = arm

    out = kit.OUT
    os.makedirs(out, exist_ok=True)
    # the model's own texture, as the PNG the upload sends
    image = next((img for img in bpy.data.images if img.size[0] > 0), None)
    if image is None:
        raise RuntimeError(f"{name}: the model has no texture")
    png = os.path.join(out, f"{name}.png")
    if image.size[0] > 1024:  # what a Roblox texture shows at most
        image.scale(1024, 1024)
    image.filepath_raw = png
    image.file_format = "PNG"
    image.save()
    print("TEXTURE", image.size[0], image.size[1])

    if test:  # bend it: the head, a front and a hind leg forward, the tail up
        for mat in body.data.materials:  # draw only fronts, as Roblox does
            mat.use_backface_culling = True
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
        scene.render.resolution_x, scene.render.resolution_y = 520, 420
        world = bpy.data.worlds.new("w")
        world.color = (0.8, 0.85, 0.9)
        scene.world = world
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        size = Vector((hi - lo)) * scale
        mid = Vector((0, 0, size.z / 2))
        cam.location = mid + Vector((1.0, -0.35, 0.25)).normalized() * size.length * 1.25
        cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
        poses = {
            "rest": {},
            "bent": {"head": (0, 0, 35), "leg_fl": (40, 0, 0), "leg_br": (-40, 0, 0), "tail": (50, 0, 0)},
            "crouch": {"head": (-25, 0, 0), "leg_fr": (-35, 0, 0), "leg_bl": (35, 0, 0), "tail": (0, 0, -60)},
        }
        for pose_name, pose in poses.items():
            for pb in arm.pose.bones:
                r = pose.get(pb.name, (0, 0, 0))
                pb.rotation_mode = "XYZ"
                # bones point up: pose rotations are in the bone's own axes (x across, y up, z back)
                pb.rotation_euler = Euler([math.radians(a) for a in r], "XYZ")
            bpy.context.view_layer.update()
            scene.render.filepath = os.path.join(out, "previews", f"{name}_{pose_name}.png")
            bpy.ops.render.render(write_still=True)
        for pb in arm.pose.bones:
            pb.rotation_euler = Euler((0, 0, 0))
        bpy.context.view_layer.update()

    fbx = os.path.join(out, f"{name}.fbx")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=False,
        use_armature_deform_only=True,
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        path_mode="STRIP",
        embed_textures=False,
        bake_anim=False,
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    size = (hi - lo) * scale
    centre = Vector((0, 0, size.z / 2))
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    manifest[name] = {
        "fbx": os.path.relpath(fbx, kit.ROOT).replace("\\", "/"),
        "png": os.path.relpath(png, kit.ROOT).replace("\\", "/"),
        "preview": f"build/blender/stations/previews/{name}_rest.png",
        "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)],
        "tris": tris,
        "parts": {f"{name}_body": tris},
        "tris_budget": 20000,
        "script": "tools/blender/stations/skin_forge.py",
        "notes": spec["notes"],
        "glow": {},
        "centres": {f"{name}_body": roblox(centre)},
        "joints": {f"{name}_{k}": roblox(j) for k, j in joints.items() if k != "body"},
        "skinned": True,
        "root": roblox(joints["body"]),
    }
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    print(f"[stations] {name}: skinned, {tris} tris, size {manifest[name]['size_studs']}")


main()
