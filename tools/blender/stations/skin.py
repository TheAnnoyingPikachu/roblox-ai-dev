"""A skinned creature (decision 0090, trial on the Lion): one unbroken ForgeGUI mesh bent by a skeleton,
instead of the seven rigid pieces of assets/forge.py.

blender --background --factory-startup --python tools/blender/stations/skin.py -- <asset> [--preview]

Writes assets/stations/skin_<species>.fbx and .png (mesh and armature, no animation: the game plays the
clips), tools/blender/stations/clips/<species>.json (the clips) and, with --preview, an mp4 of every clip
in build/blender/stations/skin/.

The skeleton is found from the same cuts as forge.py: hips over the back legs, chest over the front
ones, a neck to the head's joint, a three-bone tail, and three bones a leg (upper, lower, paw). Weights
are painted from each face's piece (forge.PLANS) and the distance to that piece's bones, blended
smoothly at every joint: Blender's automatic weights fail on these meshes of loose pieces.

Clips are turns in the creature's own frame (pitch lifts the nose, yaw turns it left, roll rolls it
right, degrees) and moves along it (right, up, forward, studs), per bone, relative to its parent. Each
engine turns them into the bone's own axes from the bone's rest frame, so Blender's preview and the
game's playback agree whatever axes the FBX import picks. Facing Blender -Y, standing on z = 0.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "assets"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import forge  # noqa: E402
import kit as k  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

ROOT = k.ROOT
FILES = os.path.join(ROOT, "assets", "stations")
CLIPS = os.path.join(HERE, "clips")
PREVIEW = os.path.join(k.OUT, "skin")

LEGS = ("fl", "fr", "bl", "br")
FORWARD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
RIGHT = FORWARD.cross(UP)  # -X: the creature's right


# Skeleton ------------------------------------------------------------------------------------------


def landmarks(ob, plan):
    """The pieces' extents and joints, from a cut of a copy of `ob`."""
    copy = ob.copy()
    copy.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(copy)
    pieces, joints = forge.cut(copy, forge.PLANS[plan])
    boxes = {}
    for name, piece in pieces.items():
        vs = [v.co.copy() for v in piece.data.vertices]
        boxes[name] = vs
        bpy.data.objects.remove(piece)
    return boxes, {n: Vector(j) for n, j in joints.items()}


def skeleton(boxes, joints):
    """{bone: (head, tail, parent)} in model space."""
    zs = [v.z for v in boxes["body"]]
    back = (joints["leg_bl"] + joints["leg_br"]) / 2
    front = (joints["leg_fl"] + joints["leg_fr"]) / 2
    spine_z = (max(zs) + min(zs)) / 2
    hips = Vector((0, back.y, spine_z))
    chest = Vector((0, front.y, spine_z))
    mid = (hips + chest) / 2
    neck = Vector((0, joints["head"].y, joints["head"].z))
    head_vs = boxes["head"]
    nose = min(head_vs, key=lambda v: v.y)  # -Y is forward
    bones = {
        "hips": (hips, mid, None),
        "chest": (mid, chest, "hips"),
        # the neck starts part way to the head: from the shoulders it would drag the chest and mane with it
        "neck": (chest.lerp(neck, 0.45), neck, "chest"),
        "head": (neck, Vector((0, nose.y, neck.z)), "neck"),
    }
    if "tail" in boxes:
        base = joints["tail"]
        tip = max(boxes["tail"], key=lambda v: (v - base).length)
        pts = [base.lerp(tip, i / 3) for i in range(4)]
        bones["tail1"] = (pts[0], pts[1], "hips")
        bones["tail2"] = (pts[1], pts[2], "tail1")
        bones["tail3"] = (pts[2], pts[3], "tail2")
    for leg in LEGS:
        top = joints[f"leg_{leg}"]
        vs = boxes[f"leg_{leg}"]
        low = min(v.z for v in vs)
        ankle = Vector((top.x, top.y, low + (top.z - low) * 0.14))
        knee = top.lerp(ankle, 0.5)
        toe = Vector((top.x, min(v.y for v in vs if v.z < ankle.z + 0.2), low))
        parent = "chest" if leg[0] == "f" else "hips"
        bones[f"{leg}_upper"] = (top, knee, parent)
        bones[f"{leg}_lower"] = (knee, ankle, f"{leg}_upper")
        bones[f"{leg}_paw"] = (ankle, Vector((ankle.x, toe.y, low + 0.05)), f"{leg}_lower")
    return bones


def build_armature(bones):
    arm = bpy.data.armatures.new("rig")
    ob = bpy.data.objects.new("rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, _) in bones.items():
        b = arm.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.roll = 0
    for name, (_, _, parent) in bones.items():
        if parent:
            arm.edit_bones[name].parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


# Weights -------------------------------------------------------------------------------------------


def _seg(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


ALLOWED = {
    "body": ("hips", "chest"),
    "head": ("neck", "head", "chest"),
    "tail": ("tail1", "tail2", "tail3", "hips"),
}
for _leg in LEGS:
    ALLOWED[f"leg_{_leg}"] = (f"{_leg}_upper", f"{_leg}_lower", f"{_leg}_paw", "chest" if _leg[0] == "f" else "hips")


def paint(mesh_ob, bones, plan, blur=0.06, passes=3):
    """Weights in three steps, so the mesh never tears. ForgeGUI's meshes are loose triangles laid edge to
    edge: two corners at one spot are two vertices, and weighted apart they pull apart.

    1. Raw: each vertex goes to the bones of its piece (forge.PLANS) by inverse distance (power 4).
    2. Blur: each vertex takes the gaussian-weighted mean of every vertex within `blur` of the model's
       height, `passes` times, so corners at one spot share weights exactly and every change from one
       bone to the next is gradual (loose mane shards follow the body they sit on).
    3. Each vertex keeps its four strongest bones (Roblox's most), normalised."""
    from mathutils import kdtree

    lo, hi = k._ground_dims([mesh_ob])
    size, mid = hi - lo, (lo + hi) / 2
    rules = forge.PLANS[plan]
    bm = bmesh.new()
    bm.from_mesh(mesh_ob.data)
    piece_of = {}
    for face in bm.faces:
        c = face.calc_center_median()
        f = (hi.y - c.y) / size.y
        h = (c.z - lo.z) / size.z
        s = (c.x - mid.x) / (size.x / 2)
        piece = next((n for n, test in rules if test(f, h, s)), "body")
        for v in face.verts:
            piece_of.setdefault(v.index, piece)
    bm.free()
    names = list(bones)
    verts = mesh_ob.data.vertices
    raw = []
    for v in verts:
        piece = piece_of.get(v.index, "body")
        if piece == "tail" and "tail1" not in bones:
            piece = "body"
        allowed = ALLOWED[piece]
        if v.co.z - lo.z < 0.12 * size.z:  # by the ground it is a foot (of the nearest leg), whatever its face said
            leg = min(LEGS, key=lambda g: (bones[f"{g}_paw"][0].xy - v.co.xy).length)
            allowed = [f"{leg}_paw", f"{leg}_lower"]
        w = {}
        for name in allowed:
            a, b, _ = bones[name]
            w[name] = 1.0 / (_seg(v.co, a, b) ** 4 + 1e-6)
        total = sum(w.values())
        raw.append({n: x / total for n, x in w.items()})

    tree = kdtree.KDTree(len(verts))
    for v in verts:
        tree.insert(v.co, v.index)
    tree.balance()
    radius = blur * size.z
    near = [tree.find_range(v.co, radius) for v in verts]
    weights = raw
    for _ in range(passes):
        out = []
        for found in near:
            acc, total = {}, 0.0
            for _co, j, d in found:
                g = math.exp(-((d / (radius * 0.5)) ** 2))
                total += g
                for n, x in weights[j].items():
                    acc[n] = acc.get(n, 0.0) + x * g
            out.append({n: x / total for n, x in acc.items()})
        weights = out

    groups = {name: mesh_ob.vertex_groups.new(name=name) for name in names}
    for v, w in zip(verts, weights):
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        total = sum(x for _, x in top)
        for n, x in top:
            if x / total > 0.01:
                groups[n].add([v.index], x / total, "REPLACE")
    return mesh_ob.modifiers.new("rig", "ARMATURE")


# Clips ---------------------------------------------------------------------------------------------


def turn(v):
    """A turn in the creature's frame: yaw about up, then pitch about right, then roll about forward."""
    p, y, r = (math.radians(x) for x in (v + [0, 0, 0])[:3])
    return Quaternion(UP, y) @ Quaternion(RIGHT, p) @ Quaternion(FORWARD, r)


def shift(v):
    x, y, z = (v + [0] * 6)[3:6]
    return RIGHT * x + UP * y + FORWARD * z


def ease(u):
    return u * u * (3 - 2 * u)


def sample(clip, t):
    keys = clip["keys"]
    if clip.get("loop"):
        t %= clip["length"]
    t = min(t, clip["length"])
    for i in range(len(keys) - 1):
        t0, t1 = keys[i][0], keys[i + 1][0]
        if t0 <= t <= t1:
            u = ease((t - t0) / max(t1 - t0, 1e-6))
            a, b = keys[i][1], keys[i + 1][1]
            out = {}
            for bone in set(a) | set(b):
                va, vb = (a.get(bone, []) + [0] * 6)[:6], (b.get(bone, []) + [0] * 6)[:6]
                out[bone] = [x + (y - x) * u for x, y in zip(va, vb)]
            return out
    return keys[-1][1]


def pose(rig, pose_):
    """Sets every pose bone from a sampled pose (turns about its own head, in model axes)."""
    for pb in rig.pose.bones:
        v = pose_.get(pb.name)
        rest = pb.bone.matrix_local.to_quaternion()
        if v is None:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
            continue
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = rest.inverted() @ turn(v) @ rest
        pb.location = rest.inverted() @ shift(v)


# Preview -------------------------------------------------------------------------------------------


def preview(rig, mesh_ob, clips, name, stills=None):
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_backface_culling = True
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.78, 0.8, 0.82)
    sc.render.resolution_x, sc.render.resolution_y = 640, 400
    sc.render.fps = 30
    if hasattr(sc.render.image_settings, "media_type"):  # Blender 5: video is a media type
        sc.render.image_settings.media_type = "VIDEO"
    sc.render.image_settings.file_format = "FFMPEG"
    sc.render.ffmpeg.format = "MPEG4"
    sc.render.ffmpeg.codec = "H264"
    floor = bpy.data.meshes.new("floor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    bm.to_mesh(floor)
    bm.free()
    fl = bpy.data.objects.new("floor", floor)
    sc.collection.objects.link(fl)
    mat = bpy.data.materials.new("floor")
    mat.diffuse_color = (0.55, 0.62, 0.45, 1)
    floor.materials.append(mat)
    lo, hi = k._ground_dims([mesh_ob])
    c, r = (lo + hi) / 2, (hi - lo).length
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 40
    d = Vector((-1.0, -0.75, 0.32)).normalized()
    cam.location = c + d * r * 1.25 + Vector((0, 0, 0))
    cam.rotation_euler = (c + Vector((0, 0, -0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    if stills:  # key moments of every clip as images (no video player needed to look)
        sc.render.image_settings.media_type = "IMAGE" if hasattr(sc.render.image_settings, "media_type") else None
        sc.render.image_settings.file_format = "PNG"
        sc.render.resolution_x, sc.render.resolution_y = 360, 240
        for clip_name, clip in clips.items():
            for i, t in enumerate(stills.get(clip_name, [clip["length"] * u for u in (0.25, 0.5, 0.75)])):
                pose(rig, sample(clip, t))
                bpy.context.view_layer.update()
                sc.render.filepath = os.path.join(PREVIEW, "stills", f"{clip_name}_{i}.png")
                bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(fl)
        return
    for clip_name, clip in clips.items():
        length = clip["length"] * (2 if clip.get("loop") else 1) + 0.4
        frames = int(length * sc.render.fps)
        for fr in range(frames):
            pose(rig, sample(clip, fr / sc.render.fps))
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=fr + 1)
                pb.keyframe_insert("location", frame=fr + 1)
        sc.frame_start, sc.frame_end = 1, frames
        sc.render.filepath = os.path.join(PREVIEW, f"{name}_{clip_name}.mp4")
        bpy.ops.render.render(animation=True)
        rig.animation_data_clear()
        print(f"[skin] preview {clip_name}: {frames} frames", flush=True)
    bpy.data.objects.remove(fl)


def _drop_pedestal(ob, share):
    """Drops the display base a website model stands on: every face whose middle is in the lowest `share`
    of the model's height (the base's top is where the paws stand)."""
    lo, hi = k._ground_dims([ob])
    cut = lo.z + share * (hi.z - lo.z)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < cut], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()



# A creature built in Blender ------------------------------------------------------------------------


def _smooth01(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def _box(objs):
    lo, hi = k._ground_dims(objs)
    return lo, hi, (lo + hi) / 2


def _rigid(ob, weights):
    """Every vertex of `ob` the same weights: the piece keeps its shape and follows its bones."""
    idx = [v.index for v in ob.data.vertices]
    for name, w in weights.items():
        if w > 0.005:
            g = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
            g.add(idx, w, "REPLACE")


def _per_vertex(ob, fn):
    for v in ob.data.vertices:
        for name, w in fn(ob.matrix_world @ v.co).items():
            if w > 0.005:
                g = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
                g.add([v.index], w, "REPLACE")


def built(src):
    """A creature from a maker in assets/ (`module:function`, e.g. lions:sun_lion), whole and clean: its
    pieces are closed shapes that overlap at the joints, so each follows its bone without tearing. Returns
    (the joined mesh, bones). Legs: the upper piece (arm, thigh, with what sits on it), the lower (forearm,
    shin) and the paw each follow their own bone; the torso blends from hips to chest; the head's pieces
    follow the head; each mane leaf follows head, neck or chest by where it grows, whole; the tail's tube
    bends along its three bones and its flame rides the tip."""
    import importlib.util

    module, fn = src["maker"].split(":")
    spec = importlib.util.spec_from_file_location(module, os.path.join(HERE, "assets", f"{module}.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    groups, joints = getattr(mod, fn)()
    every = [o for obs in groups.values() for o in obs]
    s = src["scale"]
    for o in every:
        o.data.transform(Matrix.Scale(s, 4))
    lo, hi, _ = _box(every)
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in every:
        o.data.transform(Matrix.Translation(offset))
    J = {n: Vector(j) * s + offset for n, j in joints.items()}

    def named(objs, *prefixes):
        return [o for o in objs if o.name.split(".")[0] in prefixes]

    # the skeleton, from the pieces
    torso = named(groups["body"], "torso")
    tlo, thi, tmid = _box(torso)
    back, front = (J["leg_bl"] + J["leg_br"]) / 2, (J["leg_fl"] + J["leg_fr"]) / 2
    hips, chest = Vector((0, back.y, tmid.z)), Vector((0, front.y, tmid.z))
    mid = (hips + chest) / 2
    head_at = J["head"]
    nose_y = min(v.co.y for o in groups["head"] for v in o.data.vertices)
    bones = {
        "hips": (hips, mid, None),
        "chest": (mid, chest, "hips"),
        "neck": (chest.lerp(head_at, 0.5), head_at, "chest"),
        "head": (head_at, Vector((0, nose_y, head_at.z)), "neck"),
    }
    tube = named(groups["tail"], "tail")[0]
    t0 = J["tail"]
    tip = max((v.co for v in tube.data.vertices), key=lambda c: (c - t0).length)
    pts = [t0.lerp(tip, i / 3) for i in range(4)]
    for i in range(3):
        bones[f"tail{i + 1}"] = (pts[i], pts[i + 1], "hips" if i == 0 else f"tail{i}")
    for leg in LEGS:
        objs = groups[f"leg_{leg}"]
        upper = named(objs, "arm", "thigh")
        lower = named(objs, "forearm", "shin")
        paw = named(objs, "paw", "toe")
        ulo, uhi, umid = _box(upper)
        llo, lhi, lmid = _box(lower)
        plo, phi, pmid = _box(paw)
        top = Vector((umid.x, umid.y, uhi.z - 0.15 * (uhi.z - ulo.z)))
        knee = Vector((lmid.x, (umid.y + lmid.y) / 2, (ulo.z + lhi.z) / 2))
        ankle = Vector((pmid.x, pmid.y, phi.z))
        toe = Vector((pmid.x, plo.y, plo.z + 0.1 * s))
        parent = "chest" if leg[0] == "f" else "hips"
        bones[f"{leg}_upper"] = (top, knee, parent)
        bones[f"{leg}_lower"] = (knee, ankle, f"{leg}_upper")
        bones[f"{leg}_paw"] = (ankle, toe, f"{leg}_lower")
        for o in objs:
            base = o.name.split(".")[0]
            part = "lower" if base in ("forearm", "shin") else "paw" if base in ("paw", "toe") else "upper"
            _rigid(o, {f"{leg}_{part}": 1.0})

    # the torso (and anything else on the body) blends from hips to chest along its length
    span = hips.y - chest.y

    def along(p):
        t = _smooth01((p.y - chest.y) / span * 1.2 - 0.1)
        return {"hips": t, "chest": 1 - t}

    for o in groups.get("body", []) + groups.get("body_glow", []):
        if o.name.split(".")[0] == "torso":
            _per_vertex(o, along)
        else:
            _rigid(o, along(_box([o])[2]))

    # the head and mane: forward of the head's joint the head; behind it the neck, then the chest
    reach = 0.9 * s

    def mane(p):
        d = head_at.y - p.y  # how far forward of the head's joint (-Y is forward)
        a = _smooth01((d + 0.5 * reach) / reach)
        b = _smooth01((d + 1.6 * reach) / reach)
        return {"head": a, "neck": (1 - a) * b, "chest": (1 - a) * (1 - b)}

    face = ("skull", "lips", "mouth", "chin", "nose", "philtrum", "bridge", "brow", "ear", "eye", "pupil", "fang")
    for o in groups.get("head", []) + groups.get("head_glow", []):
        base = o.name.split(".")[0]
        if base in face:
            _rigid(o, {"head": 1.0})
        elif base == "core":
            _per_vertex(o, mane)
        else:  # a leaf: by where it grows (its end nearest the head's middle), whole
            root = min((o.matrix_world @ v.co for v in o.data.vertices), key=lambda c: (c - head_at).length)
            _rigid(o, mane(root))

    # the tail's tube bends along its bones; the flame rides the last one
    tails = [n for n in bones if n.startswith("tail")]

    def bend(p):
        near = sorted((_seg(p, bones[n][0], bones[n][1]), n) for n in tails)[:2]
        ws = [(1.0 / (d**4 + 1e-6), n) for d, n in near]
        total = sum(w for w, _ in ws)
        return {n: w / total for w, n in ws}

    for o in groups.get("tail", []) + groups.get("tail_glow", []):
        if o is tube:
            _per_vertex(o, bend)
        else:
            _rigid(o, {"tail3": 1.0})

    # one mesh
    for o in bpy.context.scene.objects:
        o.select_set(o in every)
    bpy.context.view_layer.objects.active = torso[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    return ob, bones


def bake_texture(ob, png):
    """The faceted colours (and glows) baked into one 1024 texture on a fresh UV map, as kit.finalize does."""
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o is ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0)
    bpy.ops.uv.pack_islands(margin=0.006, rotate=True, margin_method="FRACTION", shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")
    lo, hi = k._ground_dims([ob])
    final = k._bake([ob], max(hi - lo), ao_samples=96, ao_blur=0.8, ao_floor=0.35, toplight=0.14, margin=10)
    final.filepath_raw, final.file_format = png, "PNG"
    final.save()
    mat = bpy.data.materials.new("skin")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png, check_existing=False)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)


# Main ----------------------------------------------------------------------------------------------


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    asset = args[0]
    # a model of its own (skin_sources.json: used whole, no cuts), or a creature's ForgeGUI source
    own = os.path.join(HERE, "skin_sources.json")
    skins = json.load(open(own, encoding="utf-8")) if os.path.exists(own) else {}
    src = skins.get(asset) or forge._sources()[asset]
    species = src.get("species") or asset.split("_")[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    png = os.path.join(FILES, f"skin_{species}.png")
    if src.get("maker"):  # built in Blender, whole
        k.reset()
        ob, bones = built(src)
        ob.name = ob.data.name = f"skin_{species}"
        rig = build_armature(bones)
        mod = ob.modifiers.new("rig", "ARMATURE")
        mod.object = rig
        ob.parent = rig
        bake_texture(ob, png)
        finish(asset, species, ob, rig, bones, args)
        return
    ob = forge._import(forge._fetch(asset, src["url"]))
    if src.get("pedestal"):
        _drop_pedestal(ob, src["pedestal"])
    lo, hi = k._ground_dims([ob])
    scale = src["height"] / (hi.z - lo.z)
    ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    ob.data.transform(Matrix.Scale(scale, 4))
    ob.name = ob.data.name = f"skin_{species}"
    for poly in ob.data.polygons:
        poly.use_smooth = True
    boxes, joints = landmarks(ob, src["plan"])
    bones = skeleton(boxes, joints)
    rig = build_armature(bones)
    paint(ob, bones, src["plan"]).object = rig
    ob.parent = rig

    # the texture: the model's own image, at 1024
    img = next(n.image for m in ob.data.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    img.scale(1024, 1024)
    img.filepath_raw, img.file_format = png, "PNG"
    img.save()
    finish(asset, species, ob, rig, bones, args)


def finish(asset, species, ob, rig, bones, args):
    """Exports the skinned mesh and its armature, records the rest frame, renders what was asked."""
    with open(os.path.join(CLIPS, f"{species}.json"), encoding="utf-8") as f:
        clips = json.load(f)["clips"]

    # the rest frame the game needs: every bone's head, in the manifest's axes (x right, y up, z to the head)
    rest = {n: [round(h.x, 3), round(h.z, 3), round(-h.y, 3)] for n, (h, _, _) in bones.items()}
    fbx = os.path.join(FILES, f"skin_{species}.fbx")
    for o in bpy.context.scene.objects:
        o.select_set(o in (ob, rig))
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="STRIP",
        embed_textures=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
    )
    lo2, hi2 = k._ground_dims([ob])
    dims = hi2 - lo2
    print(f"[skin] {asset}: {len(bones)} bones, {len(ob.data.polygons)} faces, {fbx}", flush=True)
    with open(os.path.join(k.OUT, f"skin_{species}.json"), "w", encoding="utf-8") as f:
        json.dump({"bones": rest, "size_studs": [round(dims.x, 2), round(dims.z, 2), round(dims.y, 2)], "faces": len(ob.data.polygons)}, f, indent=1)
    if "--preview" in args:
        preview(rig, ob, clips, species)
    if "--stills" in args:
        preview(rig, ob, clips, species, {"idle": [0.8], "walk": [0.0, 0.25, 0.5], "attack": [0.28, 0.44, 0.62], "magic": [0.4, 0.8, 0.92, 1.1], "hit": [0.1], "die": [0.55, 1.2], "win": [0.6]})


main()
