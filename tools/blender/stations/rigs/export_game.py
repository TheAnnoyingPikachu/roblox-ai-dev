"""A pipeline creature into the game: its skinned model with every bone of the rig, and its picked clips baked bone by
bone for stations-client/Clips to play.

blender -b <creature>/rig/rig_full.blend -P export_game.py -- <repo> <asset> <length in studs> <clip set> \
    idle=<clip> walk=<clip> attack=<clip> magic=<clip> hit=<clip> die=<clip> win=<clip>

Writes build/blender/stations/<asset>.fbx and .png, the asset's entry in tools/blender/stations/manifest.json (as
skin_forge.py does) and src/stations-client/Clips/<asset>.luau.

The game's names: the hips are "body", an upper leg "leg_fl" (the hind ones "bl", "br"), the first tail bone "tail";
the server and the spells find those. The model is in studs, standing on the ground under its middle, head at -Y.

A clip is one string a frame. Each bone's turn is a quaternion's x, y, z (w is positive) and, for the first `moved`
bones (root and body), where it has moved to, three characters a number (18 bits). Both are written in the Root's
axes (x right, y up, -z forward) about the bone's own joint, each on top of its parent's: the game turns them into
the bone's axes with the rest frame it measures, so it does not matter how an importer lays a bone's axes."""
import importlib
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rigpose as rp  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
repo, asset, length, setname = args[0], args[1], float(args[2]), args[3]
picks = dict(a.split("=") for a in args[4:])
S = importlib.import_module("clipsets." + setname)
BAKE = 60
FPS = {"idle": 10}  # frames a second kept (30 for the rest): the game eases between them
REACH = 32.0  # studs a moved bone can be from its rest place
A64 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
TOP = 64 ** 3 - 1
ROOT_AXES = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # ours (x its left, -y forward, z up) to the Root's


def game(name):
    name = {"hips": "body", "tail1": "tail"}.get(name, name).replace("upper_", "leg_")
    return name.replace("_hl", "_bl").replace("_hr", "_br")


def enc(x, lo, hi):
    v = round((min(max(x, lo), hi) - lo) / (hi - lo) * TOP)
    return A64[v >> 12] + A64[(v >> 6) & 63] + A64[v & 63]


def dec(s, lo, hi):
    return lo + (A64.index(s[0]) * 4096 + A64.index(s[1]) * 64 + A64.index(s[2])) / TOP * (hi - lo)


rig = rp.Rig()
arm, body = rig.arm, rig.body
assert arm.matrix_world == Matrix.Identity(4) and body.matrix_world == Matrix.Identity(4), "apply the objects' transforms first"
bones = [b for b in arm.data.bones if b.name == "root" or b.use_deform]
# a bone that carries no skin, and none of whose children do, is left out: Roblox drops it on import, and a clip that
# lists a bone the model lacks cannot be played
skinned = {body.vertex_groups[g.group].name for v in body.data.vertices for g in v.groups if g.weight > 1e-4}
carries = lambda b: b.name in skinned or any(carries(c) for c in b.children)
bare = [b.name for b in bones if b.name != "root" and not carries(b)]
if bare:
    print("BARE bones left out:", bare)
bones = [b for b in bones if b.name not in bare]
names = [b.name for b in bones]
assert names[:2] == ["root", "hips"], names
for i, b in enumerate(bones):
    assert b.parent is None or b.parent.name in names[:i], f"{b.name}: its parent must come before it"
MOVED = 2
pts = [v.co for v in body.data.vertices]
lo = Vector([min(p[k] for p in pts) for k in range(3)])
hi = Vector([max(p[k] for p in pts) for k in range(3)])
U = length / (hi.y - lo.y)  # studs a model unit


def own(frame):
    """One frame of bake(): each bone's turn and move on top of its parent's, in the Root's axes."""
    out = []
    for b in bones:
        M = frame[b.name]
        if b.parent:
            m = (b.parent.matrix_local.inverted() @ b.matrix_local).inverted() @ (frame[b.parent.name].inverted() @ M)
        else:
            m = b.matrix_local.inverted() @ M
        rest = b.matrix_local.to_3x3()
        q = (ROOT_AXES @ rest @ m.to_quaternion().to_matrix() @ rest.inverted() @ ROOT_AXES.transposed()).to_quaternion()
        out.append((q, ROOT_AXES @ (rest @ m.translation) * U))
    return out


def between(a, b, k):
    """The pose a share k of the way from one baked frame to the next."""
    out = []
    for (qa, pa), (qb, pb) in zip(a, b):
        if qa.dot(qb) < 0:
            qb = -qb
        out.append((qa.slerp(qb, k), pa.lerp(pb, k)))
    return out


def packed(pose):
    row, worst = [], 0.0
    for i, (q, p) in enumerate(pose):
        if q.w < 0:
            q = -q
        turn = enc(q.x, -1, 1) + enc(q.y, -1, 1) + enc(q.z, -1, 1)
        row.append(turn)
        if i < MOVED:
            row.append("".join(enc(c, -REACH, REACH) for c in p))
            # (self-check: what the game will read back is what was baked)
            back = Vector([dec(row[-1][k:k + 3], -REACH, REACH) for k in (0, 3, 6)])
            assert (back - p).length < 1e-3, (bones[i].name, p, back)
        else:
            worst = max(worst, p.length)
        x, y, z = (dec(turn[k:k + 3], -1, 1) for k in (0, 3, 6))
        got = Quaternion((math.sqrt(max(0.0, 1 - x * x - y * y - z * z)), x, y, z))
        assert q.rotation_difference(got).angle < 1e-3, (bones[i].name, q, got)
    return "".join(row), worst


def stride(frames, secs):
    """Studs of ground a walk covers in one cycle: how fast its planted feet sweep back under it."""
    speeds = []
    for foot in ("foot_fl", "foot_fr", "foot_hl", "foot_hr"):
        at = [f[foot].translation for f in frames]
        low = min(p.z for p in at)
        span = max(p.z for p in at) - low
        for a, b in zip(at, at[1:] + at[:1]):
            if a.z < low + 0.05 * span and b.z < low + 0.05 * span:
                speeds.append((b.y - a.y) * BAKE)
    return sum(speeds) / len(speeds) * secs * U


# bake every clip first: which bones move off their joints decides how many carry a position
done = {}
for name in ("idle", "walk", "attack", "magic", "hit", "die", "win"):
    title, kind, desc, secs, fn, loop = S.CLIPS[picks[name]]
    frames = rig.bake(fn, secs, loop, BAKE, getattr(S, "SPRING", (2.6, 0.32)))
    done[name] = (frames, [own(f) for f in frames])
    if name == "attack":  # for a check in Studio: where four bones' joints are at its blow, in the Root's axes, studs
        mid = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        k = round(0.44 * BAKE)
        last = sorted((n for n in names if n.startswith("tail")), key=lambda n: int(n[4:]))[-1]
        print("CHECK", f"{k / BAKE:.4f}", {game(b): [round(c, 2) for c in ROOT_AXES @ (frames[k][b].translation - mid) * U]
                                          for b in ("head", "foot_fl", "foot_hr", last)})
far = [max(p.length for _, baked in done.values() for pose in baked for p in [pose[i][1]]) for i in range(len(bones))]
MOVED = max([2] + [i + 1 for i, d in enumerate(far) if d > 0.02])  # (a tortoise's head slides: it and all before it)

clips = []
for name, (frames, baked) in done.items():
    key = picks[name]
    title, kind, desc, secs, fn, loop = S.CLIPS[key]
    m = round(secs * FPS.get(name, 30))
    rows = []
    for i in range(m if loop else m + 1):  # evenly through the clip, each between the two baked frames round it
        at = i * secs / m * BAKE
        k = min(int(at), len(baked) - 1)
        nxt = (k + 1) % len(baked) if loop else min(k + 1, len(baked) - 1)
        rows.append(packed(between(baked[k], baked[nxt], at - k))[0])
    lines = [f"		{name} = {{", f"			-- {title} ({key}): {desc}", f"			length = {secs:g},", f"			loop = {'true' if loop else 'false'},"]
    if name == "walk":
        lines.append(f"			stride = {stride(frames, secs):.3f},")
    lines.append("			data = {")
    lines += [f'				"{s}",' for s in rows]
    lines += ["			},", "		},"]
    clips.append(chr(10).join(lines))
    print("CLIP", name, key, len(rows), "frames")
print("MOVED", MOVED, [names[i] for i in range(MOVED)])

# --- the model ---------------------------------------------------------------------------------------------------
rig.ik(False)
for pb in arm.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
    for c in list(pb.constraints):
        pb.constraints.remove(c)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for eb in list(arm.data.edit_bones):
    if eb.name not in names:
        arm.data.edit_bones.remove(eb)
bpy.ops.object.mode_set(mode="OBJECT")
for b in arm.data.bones:
    b.use_deform = True  # (the root too: only deforming bones are exported)
    b.name = game(b.name)  # (the mesh's vertex groups are renamed with their bones)
names = [game(n) for n in names]

# Roblox skins a vertex to four bones at most
groups = {g.index: g for g in body.vertex_groups}
cut = 0
for v in body.data.vertices:
    ws = sorted(((g.weight, g.group) for g in v.groups if groups[g.group].name in names), reverse=True)
    for g in [g.group for g in v.groups]:
        groups[g].remove([v.index])
    cut += len(ws) > 4
    ws = ws[:4] or [(1.0, body.vertex_groups["body"].index)]
    total = sum(w for w, _ in ws)
    for w, g in ws:
        groups[g].add([v.index], w / total, "REPLACE")
print("WEIGHTS", cut, "vertices cut to four bones")

place = Matrix.Scale(U, 4) @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
body.data.transform(place)
arm.data.transform(place)
body.data.update()
bpy.context.view_layer.update()
body.name = f"{asset}_body"
arm.name = f"{asset}_rig"
size = (hi - lo) * U
joints = {b.name: b.head_local.copy() for b in arm.data.bones}

out = os.path.join(repo, "build", "blender", "stations")
os.makedirs(out, exist_ok=True)
image = next(n.image for m in body.data.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0)
png = os.path.join(out, f"{asset}.png")
if image.size[0] > 1024:  # what a Roblox texture shows at most
    image.scale(1024, 1024)
image.filepath_raw = png
image.file_format = "PNG"
image.save()

fbx = os.path.join(out, f"{asset}.fbx")
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(  # skin_forge.py's settings
    filepath=fbx, use_selection=True, object_types={"ARMATURE", "MESH"}, axis_forward="-Z", axis_up="Y",
    apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", mesh_smooth_type="FACE", use_mesh_modifiers=False,
    use_armature_deform_only=True, add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X",
    path_mode="STRIP", embed_textures=False, bake_anim=False,
)


def roblox(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
assert tris <= 20000, f"{tris} triangles: Roblox takes 20,000"
manifest_path = os.path.join(repo, "tools", "blender", "stations", "manifest.json")
manifest = json.load(open(manifest_path, encoding="utf-8"))
manifest[asset] = {
    "fbx": f"build/blender/stations/{asset}.fbx",
    "png": f"build/blender/stations/{asset}.png",
    "preview": f"build/blender/stations/previews/{asset}_rest.png",
    "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)],
    "tris": tris,
    "parts": {f"{asset}_body": tris},
    "tris_budget": 20000,
    "script": "tools/blender/stations/rigs/export_game.py",
    "notes": f"Made by the rig pipeline (tools/blender/stations/rigs): {len(names)} bones, clips baked from the {setname} set into src/stations-client/Clips.",
    "glow": {},
    "centres": {f"{asset}_body": roblox(Vector((0, 0, size.z / 2)))},
    "joints": {f"{asset}_{k}": roblox(j) for k, j in joints.items() if k != "body"},
    "skinned": True,
    "root": roblox(joints["body"]),
}
with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")

listed = chr(10).join(f'{chr(9) * 2}"{n}",' for n in names)
src = f"""--!strict
-- Generated by tools/blender/stations/rigs/export_game.py from the {setname} clip set: do not edit by hand.
-- {asset}'s clips, baked bone by bone (Clips reads them: the format is described there).

return {{
	height = {size.z:.3f},
	moved = {MOVED},
	bones = {{
{listed}
	}},
	clips = {{
{chr(10).join(clips)}
	}},
}}
"""
os.makedirs(os.path.join(repo, "src", "stations-client", "Clips"), exist_ok=True)
open(os.path.join(repo, "src", "stations-client", "Clips", f"{asset}.luau"), "w", encoding="utf-8", newline="\n").write(src)
print(f"[stations] {asset}: {tris} tris, {len(names)} bones, size {manifest[asset]['size_studs']}, leg joint {roblox(joints['leg_fl'])}")
