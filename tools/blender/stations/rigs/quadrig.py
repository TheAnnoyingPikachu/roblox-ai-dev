"""The quadruped rig template (the base animal's), placed from one species' landmarks, with its walk keyed.
blender -b --factory-startup -P quadrig.py -- <species.json> <body.glb> <kit.glb|-> <outdir>
species.json (model units, head at -Y, +X its left):
  floor, rate (strides a second in the game), step, lift, duty,
  spine: [hips start, ..., chest end, neck end, head end] points, neck_from (index where the neck starts),
  tail: points, trunk: points or [],
  legs: {"f": {"top","knee","ankle","toe"} for the left front leg, "h": the same for the left hind leg} (mirrored),
  head_from_y (everything ahead of it is rigid head), leg_from_z (no leg weight above it), back_z (above: back only)
Bones: root > hips > spine > chest > neck[1..] > head (> trunk1-3), hips > tail1..n,
  chest > upper/lower/foot per front leg, hips > the same per hind leg; IK targets along each foot, knee poles.
The body is weighted by bone heat and fixed by rule; each kit piece follows its nearest bone rigidly.
Writes <outdir>/rig.blend, <outdir>/walk_side_###.png and walk_q_###.png."""
import bpy, json, math, os, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
S = json.load(open(args[0]))
body_path, kit_path, outdir = args[1], args[2], args[3]
os.makedirs(outdir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def load(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in new if o.name in bpy.data.objects and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.name = name
    return o

body = load(body_path, "body")
kit = load(kit_path, "kit") if kit_path != "-" and os.path.exists(kit_path) else None
# weld the body's UV seams (bone heat fails on a split skin) and keep its main shell
bpy.ops.object.select_all(action="DESELECT"); body.select_set(True); bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.remove_doubles(threshold=1e-5)
bpy.ops.object.mode_set(mode="OBJECT")
floor = S["floor"]

# --- bones -------------------------------------------------------------------------------------------------------
B = {}
def bone(name, h, t, parent=None, connect=False, deform=True):
    B[name] = (Vector(h), Vector(t), parent, connect, deform)

sp = S["spine"]
bone("root", (0, 0, floor), (0, 0, floor + 0.08), deform=False)
names = ["hips", "spine", "chest"] + [f"neck{i + 1}" for i in range(len(sp) - 5)] + ["head"]
for i, n in enumerate(names):
    # (a tortoise's head is not joined to its neck bone: it slides back into the shell)
    bone(n, sp[i], sp[i + 1], "root" if i == 0 else names[i - 1], i > 0 and not (n == "head" and S.get("loose_head")))
for i in range(len(S["trunk"]) - 1):
    bone(f"trunk{i + 1}", S["trunk"][i], S["trunk"][i + 1], "head" if i == 0 else f"trunk{i}", i > 0)
for e in S.get("extras", []):  # what a family has more (ears, a banner, wings): a bone each, on a spring when it is posed
    bone(e["name"], e["head"], e["tail"], e["parent"])
tl = S["tail"]
for i in range(len(tl) - 1):
    bone(f"tail{i + 1}", tl[i], tl[i + 1], "hips" if i == 0 else f"tail{i}", i > 0)
LEGS = {}
for end, parent in (("f", "chest"), ("h", "hips")):
    L = S["legs"][end]
    for side, s in (("l", 1), ("r", -1)):
        m = lambda p: (s * p[0], p[1], p[2])
        n = f"{end}{side}"
        bone(f"upper_{n}", m(L["top"]), m(L["knee"]), parent)
        bone(f"lower_{n}", m(L["knee"]), m(L["ankle"]), f"upper_{n}", True)
        bone(f"foot_{n}", m(L["ankle"]), m(L["toe"]), f"lower_{n}", True)
        bone(f"ik_{n}", m(L["ankle"]), m(L["toe"]), "root", deform=False)  # along the foot: copying its turn keeps it
        k = m(L["knee"])
        pole = (k[0], k[1] + (0.3 if end == "f" else -0.3), k[2])
        bone(f"pole_{n}", pole, (pole[0], pole[1], pole[2] + 0.04), "root", deform=False)
        LEGS[n] = Vector(m(L["ankle"]))

arm_data = bpy.data.armatures.new("rig")
arm = bpy.data.objects.new("rig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name, (h, t, parent, connect, deform) in B.items():
    eb = arm_data.edit_bones.new(name); eb.head, eb.tail, eb.roll = h, t, 0.0; eb.use_deform = deform
for name, (h, t, parent, connect, deform) in B.items():
    if parent:
        eb = arm_data.edit_bones[name]; eb.parent = arm_data.edit_bones[parent]; eb.use_connect = connect
bpy.ops.object.mode_set(mode="OBJECT")
arm["upright"] = 1 if S.get("upright") else 0

# --- body weights: bone heat, then the rules ------------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT"); body.select_set(True); arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

def ramp(a, b, x):
    return max(0.0, min(1.0, (x - a) / (b - a)))
groups = {g.name: g for g in body.vertex_groups}
legs = [g for g in groups if g.startswith(("upper_", "lower_", "foot_"))]
if S.get("upright"):  # an upright animal's front "legs" are its arms, high on its body: only its legs keep below the hips
    legs = [g for g in legs if g.endswith(("_hl", "_hr"))]
trunks = [g for g in groups if g.startswith("trunk")]
EXTRA = tuple(e["name"] for e in S.get("extras", [])) or ("-none-",)
unweighted = 0
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    w = {body.vertex_groups[g.group].name: g.weight for g in v.groups}
    if not w:
        unweighted += 1
    if sum(x for k, x in w.items() if k.startswith(EXTRA)) > 0.5:  # an ear or a banner keeps what bone heat gave it
        continue
    keep = ramp(S["leg_from_z"], S["leg_from_z"] - S.get("leg_band", 0.08), p.z)  # no leg above the belly line
    for g in legs:
        if g in w:
            w[g] *= keep
    head = ramp(S["head_from_y"], S["head_from_y"] - 0.04, p.y)
    if "head_from_z" in S:  # (an upright animal's head is what is above its neck)
        head = ramp(S["head_from_z"], S["head_from_z"] + 0.04, p.z)
    if p.z > S["back_z"] and head == 0:  # the saddle and the crest: the back only
        w = {k: x for k, x in w.items() if k in ("hips", "spine", "chest")}
    if head > 0:  # the whole head is one rigid block (a trunk keeps its own)
        trunk = sum(w.get(k, 0) for k in trunks) if abs(p.x) < 0.07 else 0
        w = {k: x * (1 - head) for k, x in w.items() if not k.startswith("trunk")} | {k: w[k] for k in trunks if k in w and trunk}
        w["head"] = w.get("head", 0) + head * (1 - trunk)
    total = sum(w.values())
    if total < 1e-6:
        w, total = {"spine": 1.0}, 1.0
    for k in groups:
        groups[k].remove([v.index])
    for k, x in sorted(w.items(), key=lambda kv: -kv[1])[:4]:  # Roblox keeps four bones a vertex
        if x / total > 0.01:
            groups[k].add([v.index], x / total, "REPLACE")
print("BODY unweighted before the rules:", unweighted, "of", len(body.data.vertices))
# smooth the weights so no region changes bone abruptly (stretched faces sat inside one bone's area), then keep four
# bones a vertex, normalised
sm = S.get("smooth", [0.0, 0])
if sm[1]:
    import numpy as np
    me = body.data
    names = [g.name for g in body.vertex_groups]
    W = np.zeros((len(me.vertices), len(names)))
    for v in me.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    E = np.array([e.vertices[:] for e in me.edges])
    deg = np.bincount(E.ravel(), minlength=len(W)).astype(float)[:, None]
    for _ in range(int(sm[1])):
        acc = np.zeros_like(W)
        np.add.at(acc, E[:, 0], W[E[:, 1]]); np.add.at(acc, E[:, 1], W[E[:, 0]])
        W = (1 - sm[0]) * W + sm[0] * acc / np.maximum(deg, 1)
    for v in me.vertices:
        row = W[v.index]
        keep = np.argsort(-row)[:4]
        tot = row[keep].sum()
        for gi in range(len(names)):
            body.vertex_groups[gi].remove([v.index])
        for gi in keep:
            if tot > 0 and row[gi] / tot > 0.01:
                body.vertex_groups[gi].add([v.index], float(row[gi] / tot), "REPLACE")
    print("SMOOTHED", sm)

# --- the kit: each loose piece rigid on its nearest deforming bone -------------------------------------------------
if kit:
    import bmesh
    deform = [b for b in arm_data.bones if b.use_deform]
    def nearest(c):
        best = None
        high = c.z > S["leg_from_z"] - 0.06  # a banner or plate high on the body never rides a leg
        for b in deform:
            if high and b.name.startswith(("upper_", "lower_", "foot_")):
                continue
            a, t = b.head_local, b.tail_local
            d = t - a
            u = max(0.0, min(1.0, (c - a).dot(d) / d.length_squared))
            dist = (a + d * u - c).length
            if best is None or dist < best[0]:
                best = (dist, b.name)
        return best[1]
    bm = bmesh.new(); bm.from_mesh(kit.data); bm.verts.ensure_lookup_table()
    seen, pieces = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop(); isl.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index); stack.append(y)
        pieces.append(isl)
    kg = {}
    for isl in pieces:
        c = sum((bm.verts[i].co for i in isl), Vector()) / len(isl)
        name = nearest(c)
        if c.z > S["back_z"] and c.y > S["head_from_y"]:  # the crest and the saddle's pieces ride the back
            name = "spine" if c.y > sp[2][1] else "chest"
        kg.setdefault(name, []).extend(isl)
    bm.free()
    for name, idx in kg.items():
        kit.vertex_groups.new(name=name).add(idx, 1.0, "REPLACE")
    mod = kit.modifiers.new("rig", "ARMATURE"); mod.object = arm
    kit.parent = arm
    print("KIT", len(pieces), "pieces:", {k: len(v) for k, v in kg.items()})

# --- IK and knee directions ----------------------------------------------------------------------------------------
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
P = arm.pose.bones
for n in LEGS:
    c = P[f"lower_{n}"].constraints.new("IK")
    c.target, c.subtarget = arm, f"ik_{n}"
    c.pole_target, c.pole_subtarget = arm, f"pole_{n}"
    c.chain_count = 2
    cr = P[f"foot_{n}"].constraints.new("COPY_ROTATION"); cr.target, cr.subtarget = arm, f"ik_{n}"

def place(n, offset):
    m = arm_data.bones[f"ik_{n}"].matrix_local.copy()
    m.translation = m.translation + offset
    P[f"ik_{n}"].matrix = m

for n, ankle in LEGS.items():  # front knees bend back, hind knees forward: try the pole angles and keep the right one
    want = 1 if n[0] == "f" else -1
    c = P[f"lower_{n}"].constraints["IK"]
    best = None
    for deg in (-90, 90, 0, 180):
        c.pole_angle = math.radians(deg)
        place(n, Vector((0, 0, 0.03)))
        bpy.context.view_layer.update()
        top, knee, end = P[f"upper_{n}"].head, P[f"lower_{n}"].head, P[f"lower_{n}"].tail
        mid = (top + end) / 2
        score = want * (knee.y - mid.y) - 3 * abs(knee.x - mid.x)
        if best is None or score > best[0]:
            best = (score, deg)
    c.pole_angle = math.radians(best[1])
    P[f"ik_{n}"].matrix_basis = Matrix.Identity(4)
    print("POLE", n, best[1])
bpy.context.view_layer.update()

# --- the walk ------------------------------------------------------------------------------------------------------
FPS = 30
N = round(FPS / S["rate"])
DUTY, STEP, LIFT = S["duty"], S["step"], S["lift"]
START = {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}
sc = bpy.context.scene
sc.render.fps = FPS; sc.frame_start, sc.frame_end = 0, N - 1

def foot(c, start):
    u = (c - start) % 1
    if u < DUTY:
        return -STEP + 2 * STEP * u / DUTY, 0.0
    k = (u - DUTY) / (1 - DUTY)
    e = 0.5 - 0.5 * math.cos(math.pi * k)
    return STEP - 2 * STEP * e, LIFT * math.sin(math.pi * k)

def rot(pb, x=0.0, y=0.0, z=0.0):
    pb.rotation_mode = "XYZ"; pb.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))

tails = [b for b in P.keys() if b.startswith("tail")]
necks = [b for b in P.keys() if b.startswith("neck")]
for f in range(N):
    c = f / N
    beat = math.cos(2 * math.tau * c)
    for n in LEGS:
        dy, dz = foot(c, START[n])
        place(n, Vector((0, dy, dz)))
        P[f"ik_{n}"].keyframe_insert("location", frame=f)
    roll = 2.0 * math.sin(math.tau * (c - 0.125))
    rot(P["hips"], 0.6 * beat, 2.0 * math.sin(math.tau * c), roll)
    rot(P["spine"], 0, -1.2 * math.sin(math.tau * c), -0.4 * roll)
    rot(P["chest"], -0.6 * beat, -1.2 * math.sin(math.tau * c), -0.6 * roll)
    for nb in necks:
        rot(P[nb], 0.8 * math.cos(2 * math.tau * c + 0.9), 0.8 * math.sin(math.tau * c), 0)
    rot(P["head"], 1.0 * math.cos(2 * math.tau * c + 1.3), -1.5 * math.sin(math.tau * c), 0.5 * roll)  # a cat keeps its head steady
    for i, tb in enumerate(tails):
        rot(P[tb], 2 * math.sin(math.tau * c - 0.5 * i), 0, (5 + 3 * i) * math.sin(math.tau * c - 0.7 - 0.5 * i))
    for b in ["hips", "spine", "chest", "head"] + necks + tails:
        P[b].keyframe_insert("rotation_euler", frame=f)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(outdir, "rig.blend"))
if os.environ.get("NORENDER"):
    print("DONE saved"); sys.exit(0)

# --- renders -------------------------------------------------------------------------------------------------------
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(45), 0, math.radians(-30))
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.64, 0.68, 1)
bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, floor))
sc.render.engine = "BLENDER_EEVEE"; sc.render.resolution_x, sc.render.resolution_y = 720, 480
sc.view_settings.view_transform = "Standard"
mid = Vector((0, 0, floor + 0.2))
for tag, d, dist in (("side", (-1.0, -0.05, 0.1), 1.9), ("q", (-0.8, -0.9, 0.3), 1.9)):
    v = Vector(d).normalized()
    cam.location = mid + v * dist
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    for f in range(0, N, 2):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(outdir, f"walk_{tag}_{f:03d}.png")
        bpy.ops.render.render(write_still=True)
print("DONE", N, "frames")
