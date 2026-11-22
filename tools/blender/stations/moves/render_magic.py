"""Render magic power attack concepts: the animal casts (its keys, fitted so its feet stay on the ground) and
the spell plays out on a target dummy ahead of it.

blender --background --factory-startup --python render_magic.py -- <asset> <out dir> keys|full [only,...]"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import concepts as C  # noqa: E402
import fxkit  # noqa: E402
import magic as M  # noqa: E402
import rig as R  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1 :]
asset, out, mode = args[0], os.path.abspath(args[1]), args[2]
only = set(args[3].split(",")) if len(args) > 3 else None
name, spec = M.CONCEPTS[asset]
r = R.Rig(asset, res=(640, 400))
U = r.unit
HOLD = 0.5
sc = r.sc

# -- the animal's sizes and its anchor points (vertices tracked as it moves) -----------------------------------------
rest = r.points()
lo, hi = rest.min(0), rest.max(0)
H = (hi[2] - lo[2]) / U
L = (hi[1] - lo[1]) / U
groups = {g.index: g.name for g in r.body.vertex_groups}
top = []
for v in r.body.data.vertices:
    ws = sorted(((g.weight, groups[g.group]) for g in v.groups), reverse=True)
    top.append(ws[0][1] if ws else "body")
top = np.array(top)


def pick(group, score):
    idx = np.nonzero(top == group)[0]
    if len(idx) == 0:
        idx = np.arange(len(rest))
    return int(idx[np.argmax(score(rest[idx]))])


head = rest[top == "head"] if (top == "head").any() else rest
hy0 = head[:, 1].min()
hlen = head[:, 1].max() - hy0
front = lambda p: np.where(p[:, 1] < hy0 + 0.3 * hlen, p[:, 2], -1e9)  # noqa: E731
body_mid = rest[top == "body"].mean(0)
ANCHORS = {
    "nose": pick("head", lambda p: -p[:, 1]),
    "crown": pick("head", lambda p: p[:, 2]),
    "horn": pick("head", front),
    "trunk": pick("head", lambda p: -p[:, 2] - 0.3 * p[:, 1]),
    "paw_l": pick("leg_fl", lambda p: -p[:, 2]),
    "paw_r": pick("leg_fr", lambda p: -p[:, 2]),
    "wing_l": pick("leg_bl", lambda p: p[:, 0]),
    "wing_r": pick("leg_br", lambda p: -p[:, 0]),
    "tail": pick("tail", lambda p: np.linalg.norm(p - body_mid, axis=1)),
    "back": pick("body", lambda p: p[:, 2]),
    "chest": pick("body", lambda p: -p[:, 1] - 0.2 * np.abs(p[:, 0])),
}
r.mid = Vector(((lo + hi) / 2).tolist())

# -- the stage: a target dummy ahead, the camera framing both, bloom on what glows ----------------------------------
gap = max(0.55 * L, 1.1 * H, 6.0)
T = Vector((float(r.mid.x), float(lo[1]) - gap * U, float(r.floor)))
mats = {}


def plain(rgb, rough=0.8, glow=0.0):
    m = bpy.data.materials.new("dummy")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if glow:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = glow
    return m


dummy = bpy.data.objects.new("dummy", None)
sc.collection.objects.link(dummy)
dummy.location = T
for kind, loc, size, rgb, glow in (
    ("cyl", (0, 0, 2.0), (0.32, 0.32, 4.0), (0.16, 0.12, 0.2), 0),
    ("sphere", (0, 0, 4.35), (0.75, 0.75, 0.75), (0.2, 0.14, 0.26), 0),
    ("cube", (0, 0, 3.1), (2.6, 0.32, 0.32), (0.16, 0.12, 0.2), 0),
    ("sphere", (0.28, -0.6, 4.5), (0.13, 0.13, 0.13), (0.85, 0.3, 1.0), 6),
    ("sphere", (-0.28, -0.6, 4.5), (0.13, 0.13, 0.13), (0.85, 0.3, 1.0), 6),
    ("cyl", (0, 0, 0.08), (1.1, 1.1, 0.16), (0.12, 0.1, 0.14), 0),
):
    if kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=1, vertices=16)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=16, ring_count=8)
    ob = bpy.context.object
    ob.scale = Vector(size) * U
    ob.location = Vector(loc) * U
    ob.data.materials.append(plain(rgb, glow=glow))
    ob.parent = dummy
TC = T + Vector((0, 0, 2.6)) * U  # the dummy's middle

span_y = (float(hi[1]) - T.y) / U + 4
sky = max(H, 5.0) * 1.7 if H < 10 else H * 1.1  # how high the sky effects go
span_z = max(H, 5.0) + sky + 1.5
mid = Vector((float(r.mid.x), (float(hi[1]) + T.y) / 2, float(r.floor) + span_z * 0.47 * U))
view = Vector((-1.0, -0.12, 0.32)).normalized()
cam = sc.camera
cam.data.lens = 30
fov_h, fov_v = 2 * math.atan(18 / 30), 2 * math.atan(18 / 30 * 400 / 640)
dist = max(span_y / 2 / math.tan(fov_h / 2), span_z / 2 / math.tan(fov_v / 2)) * 1.12 * U
cam.location = mid + view * dist
cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.clip_end = dist * 10
for ob in sc.objects:  # the floor reaches past the dummy
    if ob.name.startswith("floor"):
        ob.scale = (4, 4, 1)
tree = bpy.data.node_groups.new("comp", "CompositorNodeTree")
rl = tree.nodes.new("CompositorNodeRLayers")
gl = tree.nodes.new("CompositorNodeGlare")
gl.inputs["Type"].default_value = "Bloom"
gl.inputs["Threshold"].default_value = 1.2
gl.inputs["Strength"].default_value = 0.7
gl.inputs["Size"].default_value = 0.5
tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
go = tree.nodes.new("NodeGroupOutput")
tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
tree.links.new(gl.outputs["Image"], go.inputs[0])
sc.compositing_node_group = tree
sc.render.use_compositing = True

kit = fxkit.Kit(r, U, cam.location)


class Frame:
    """what a spell's drawing function gets each frame"""

    def __init__(self, t, pts, pose):
        self.t, self.kit, self.U = t, kit, U
        self.A = {k: Vector(pts[i].tolist()) for k, i in ANCHORS.items()}
        self.T, self.TC, self.H, self.L, self.pose = T, TC, H, L, pose
        self.k = max(1.0, min(3.0, max(H, L * 0.6) / 7))  # effect size for this animal
        self.sky = sky
        self.dummy = Vector()
        self.dummy_yaw = 0.0
        self.fwd = Vector((0, -1, 0))
        self.right = Vector((-1, 0, 0))


def shown(pose):
    return C.upright_tail(pose) if r.upright else pose


def lifted(pose):
    r.pose(shown(pose))
    s = r.sink()
    if s <= 0.005:
        return pose
    pose = {j: list(v) + [0] * (6 - len(v)) for j, v in pose.items()}
    body = pose.setdefault("body", [0] * 6)
    body[4] = round(body[4] + s / r.scale, 3)
    return pose


fit = {"asset": asset, "name": name, "clips": {}}
os.makedirs(os.path.join(out, "frames"), exist_ok=True)
os.makedirs(os.path.join(out, "keys"), exist_ok=True)
for key, item in spec.items():
    if only and key not in only:
        continue
    label, text, keys, flags, draw = item
    fitted = [(t, pose if flags.get("dig") else lifted(pose)) for t, pose in keys]
    length = keys[-1][0]
    fit["clips"][key] = {"kind": "power", "label": label, "text": text, "length": length, "flags": {k: v for k, v in flags.items()}, "keys": fitted}
    if mode == "keys":
        times = [0.3, 0.6, 0.8, 0.88, 0.92, 1.0, 1.15, 1.4]
    else:
        times = [i / 24 - HOLD for i in range(round((HOLD + length + HOLD) * 24) + 1)]
    for i, tc in enumerate(times):
        tt = tc + HOLD
        pose = C.sample(fitted, tc) if 0 <= tc <= length else C.neutral(tt, r.upright)
        pose = shown(pose)
        r.pose(pose)
        kit.clear()
        f = Frame(tc, r.points(), pose)
        draw(f)
        dummy.location = T + f.dummy * U
        dummy.rotation_euler = (0, 0, f.dummy_yaw)
        path = os.path.join(out, "keys" if mode == "keys" else "frames", f"{key}_{i:03d}_{tc:.2f}.png" if mode == "keys" else f"{key}_{i:03d}.png")
        r.shot(path)
    print("MAGIC", asset, key, len(times))
kit.clear()
json.dump(fit, open(os.path.join(out, f"fit_magic_{mode}.json"), "w"), indent=1)
print("DONE", asset)
