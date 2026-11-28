"""Measures an upright animal's landmarks (a meerkat: standing on its hind legs, arms hanging clear of its sides) and
writes its species.json for quadrig.py. blender -b --factory-startup -P autoland_up.py -- <raw.glb> <species.json> [clip set]
The rig is the four-legged one stood up: the "hind legs" are its legs, planted by IK; the "front legs" are its arms,
chains from shoulder to hand that ride with the body and are posed by where the hands go; the spine runs upwards.
  feet    the two low clusters ahead of the tail (the tail lies on the ground behind)
  hips    just above the crotch: the lowest point along the middle between the legs
  arms    from the shoulder (just under the neck) straight to the hand (what reaches furthest sideways above the legs)
  spine   up the middle from the hips to the shoulders, the neck (the narrowest slice above them) and the crown
  tail    everything low and behind the body, ordered by distance from its root and cut into four bones"""
import bpy, json, sys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
clipset = args[2] if len(args) > 2 else "meerkat"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
rng, parts = np.random.default_rng(1), []
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    me = o.data
    me.calc_loop_triangles()
    V = np.array([o.matrix_world @ v.co for v in me.vertices])
    T = np.array([t.vertices[:] for t in me.loop_triangles])
    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    k = rng.choice(len(T), size=150000, p=area / area.sum())
    u, v = rng.random(len(k)), rng.random(len(k))
    over = u + v > 1
    u[over], v[over] = 1 - u[over], 1 - v[over]
    parts += [V, a[k] + u[:, None] * (b[k] - a[k]) + v[:, None] * (c[k] - a[k])]
P = np.concatenate(parts)
lo, hi = P.min(0), P.max(0)
floor, H = float(lo[2]), float(hi[2] - lo[2])
r3 = lambda p: [round(float(x), 3) for x in p]


def band(z0, z1):
    return P[(P[:, 2] >= z0) & (P[:, 2] < z1)]


def mid_y(z):
    """The body's middle from front to back at a height (the tail, behind, left out by taking the front two thirds)."""
    s = band(z - 0.02, z + 0.02)
    s = s[np.abs(s[:, 0]) < 0.06]
    ys = np.sort(s[:, 1])
    return float(np.median(ys[: max(1, 2 * len(ys) // 3)])) if len(ys) else 0.0


# the body's depth where it is only body: halfway up
waist = band(floor + 0.45 * H, floor + 0.55 * H)
waist = waist[np.abs(waist[:, 0]) < 0.06]
body_y, depth = float(np.median(waist[:, 1])), float(waist[:, 1].max() - waist[:, 1].min())

# --- feet and legs ----------------------------------------------------------------------------------------------------
low = band(floor, floor + 0.04 * H)
feet = low[low[:, 1] < body_y + 0.35 * depth]  # (ahead of the tail)
foot = feet[np.abs(feet[:, 0]) > 0.03]
fx, fy = float(np.abs(foot[:, 0]).mean()), float(foot[:, 1].mean())
strip = P[(np.abs(P[:, 0]) < 0.025) & (np.abs(P[:, 1] - body_y) < 0.3 * depth)]
crotch = float(strip[:, 2].min())
hip_z = max(crotch + 0.03, floor + 0.16 * H)  # (a meerkat sits on its haunches: no gap between its legs to find)
leg = hip_z - floor
hip_y = mid_y(hip_z)
f0, f1 = float(np.percentile(foot[:, 1], 2)), float(np.percentile(foot[:, 1], 98))  # toe and heel
ankle_y = f1 - 0.3 * (f1 - f0)
legs = {"h": {"top": r3((0.85 * fx, hip_y, hip_z)), "knee": r3((fx, 0.5 * (hip_y + ankle_y) - 0.12 * leg, floor + 0.55 * leg)),
              "ankle": r3((fx, ankle_y, floor + 0.15 * leg)), "toe": r3((fx, f0, floor + 0.004))}}

# --- arms -------------------------------------------------------------------------------------------------------------
up = P[P[:, 2] > hip_z + 0.05]
reach = float(np.abs(up[:, 0]).max())
hand = up[np.abs(up[:, 0]) > 0.9 * reach].copy()
hand[:, 0] = np.abs(hand[:, 0])
hand = hand.mean(0)
# the neck: the narrowest slice of the upper half, under the head
zs = np.arange(floor + 0.55 * H, float(hi[2]) - 0.1 * H, 0.02)
neck_z = float(zs[int(np.argmin([float(np.abs(band(z, z + 0.02)[:, 0]).max()) if len(band(z, z + 0.02)) else 9.0 for z in zs]))])
# the shoulder: just under the neck, inside the body's edge there; the arm runs straight from it to the hand (a line
# fitted through the arm's points is pulled upright by the body's sides)
sz = neck_z - 0.08 * H
shoulder = np.array([0.8 * float(np.abs(band(sz - 0.02, sz + 0.02)[:, 0]).max()), mid_y(sz), sz])
wrist, tip = shoulder + 0.85 * (hand - shoulder), shoulder + 1.04 * (hand - shoulder)
elbow = 0.5 * (shoulder + wrist) + np.array([0, 0.05 * np.linalg.norm(wrist - shoulder), 0])  # a slight bend backwards
legs["f"] = {"top": r3(shoulder), "knee": r3(elbow), "ankle": r3(wrist), "toe": r3(tip)}

# --- spine ------------------------------------------------------------------------------------------------------------
head = P[P[:, 2] > neck_z + 0.02]
z0, z1 = hip_z + 0.02, float(shoulder[2])
spine = [(0, mid_y(z0), z0), (0, mid_y(z0 + (z1 - z0) / 3), z0 + (z1 - z0) / 3), (0, mid_y(z0 + 2 * (z1 - z0) / 3), z0 + 2 * (z1 - z0) / 3),
         (0, mid_y(z1), z1), (0, mid_y(neck_z), neck_z), (0, float(np.median(head[:, 1])), float(hi[2]))]

# --- tail -------------------------------------------------------------------------------------------------------------
root = np.array([0.0, body_y + 0.4 * depth, hip_z])
behind = P[(P[:, 1] > body_y + 0.55 * depth) & (P[:, 2] < hip_z + 0.1 * H)]
tail = []
if len(behind) > 200:
    dist = np.linalg.norm(behind - root, axis=1)
    cuts = np.quantile(dist, [0.25, 0.5, 0.75])
    tail = [tuple(root)] + [tuple(behind[(dist > q - 0.03) & (dist < q + 0.03)].mean(0)) for q in cuts] + [tuple(behind[dist > np.quantile(dist, 0.97)].mean(0))]
if len(tail) < 3:
    tail = [tuple(root), tuple(root + [0, 0.05, -0.02]), tuple(root + [0, 0.1, -0.04])]

S = {"name": "", "clips": clipset, "upright": True, "floor": round(floor, 3),
     "rate": 0.83, "step": round(0.3 * leg, 3), "lift": round(0.14 * leg, 3), "duty": 0.62,
     "spine": [r3(p) for p in spine], "tail": [r3(p) for p in tail], "trunk": [], "extras": [], "legs": legs,
     "head_from_z": round(neck_z + 0.01, 3), "head_from_y": -99, "leg_from_z": round(hip_z + 0.01, 3), "leg_band": 0.04,
     "back_z": 99, "smooth": [0.8, 100]}
json.dump(S, open(out, "w"), indent=1)
print("AUTOLAND upright: feet", round(fx, 3), round(fy, 3), "crotch", round(crotch, 3), "hips", round(hip_z, 3), "neck", round(neck_z, 3), "reach", round(reach, 3))
print("AUTOLAND arm", legs["f"], "leg", legs["h"])
print("AUTOLAND spine", S["spine"], "tail", S["tail"])
