"""Measures a four-legged model's landmarks and writes its species.json (what quadrig.py places the rig from), so no
creature is measured by hand. blender -b --factory-startup -P autoland.py -- <raw.glb> <species.json> [clip set]
Expects the model as ForgeGUI makes it from a neutral-stance concept: standing, head at -Y (checked), +X its left.
How each landmark is found (model units, about 0.96 long):
  feet      the four clusters of the lowest vertices; left and right are averaged into one mirrored pair
  legs      each foot's column of vertices followed upwards slice by slice; the joint line is midway up the body
            between the belly (the lowest midline point between the legs) and the rump's top
  spine     from just behind the hind legs' tops to just ahead of the front legs', a little above the leg tops
  head      everything ahead of 40 % of the way from the front legs to the nose
  tail      the narrow run behind the hind legs, cut into bones along its own length (hanging or held out)
Prints the numbers; exits 2 if the head is at +Y or four feet are not found."""
import bpy, json, math, sys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
clipset = args[2] if len(args) > 2 else "quad"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
P = np.concatenate([np.array([o.matrix_world @ v.co for v in o.data.vertices]) for o in bpy.data.objects if o.type == "MESH"])
lo, hi = P.min(0), P.max(0)
floor, height, length = float(lo[2]), float(hi[2] - lo[2]), float(hi[1] - lo[1])
r3 = lambda v: [round(float(x), 3) for x in v]


def kmeans(p, k):
    best = None
    rng = np.random.default_rng(0)
    for _ in range(10):
        c = p[rng.choice(len(p), k, replace=False)]
        for _ in range(40):
            lab = np.argmin(((p[:, None] - c[None]) ** 2).sum(-1), 1)
            c = np.array([p[lab == j].mean(0) if (lab == j).any() else c[j] for j in range(k)])
        sse = ((p - c[lab]) ** 2).sum()
        if best is None or sse < best[0]:
            best = (sse, c)
    return best[1]


# --- feet -------------------------------------------------------------------------------------------------------------
low = P[P[:, 2] < floor + 0.06 * height][:, :2]
feet = kmeans(low, 4)
feet = feet[np.argsort(feet[:, 1])]  # front (low y) first
front, hind = feet[:2], feet[2:]
if abs(front[0, 0] - front[1, 0]) < 0.04 or abs(hind[0, 0] - hind[1, 0]) < 0.04:
    print("AUTOLAND FAIL: four feet not found", r3(feet.ravel())); sys.exit(2)
# the head end is the wide one (a tail is narrow): it must be at -Y
def end_width(a, b):
    e = P[(P[:, 1] >= a) & (P[:, 1] <= b)]
    return float(np.abs(e[:, 0]).max()) if len(e) else 0.0
if end_width(hi[1] - 0.12 * length, hi[1]) > end_width(lo[1], lo[1] + 0.12 * length) + 0.01:
    print("AUTOLAND FAIL: head at +Y"); sys.exit(2)
fx, fy = float(np.abs(front[:, 0]).mean()), float(front[:, 1].mean())
hx, hy = float(np.abs(hind[:, 0]).mean()), float(hind[:, 1].mean())


def column(x, y):
    """A leg's centre line: [(z, x, y)] followed up from its foot, using both sides mirrored."""
    pts = P.copy(); pts[:, 0] = np.abs(pts[:, 0])
    c, line = np.array([x, y]), []
    for z in np.arange(floor, floor + 0.7 * height, 0.02):
        s = pts[(pts[:, 2] >= z) & (pts[:, 2] < z + 0.02)]
        near = s[np.hypot(*(s[:, :2] - c).T) < 0.085]
        if len(near) < 4:
            line.append((z + 0.01, c[0], c[1])); continue
        m = near[:, :2].mean(0)
        c = 0.5 * c + 0.5 * m
        line.append((z + 0.01, float(c[0]), float(c[1])))
    return line


def at(line, z):
    return min(line, key=lambda p: abs(p[0] - z))[1:]


# --- the body's lines -------------------------------------------------------------------------------------------------
def slices(a, b, pick, half=None, wide=None):
    """pick(z values) of each 0.03-long slice of the body between y a and b (within |x| < half when given; only
    slices at least `wide` across, so a tail is not taken for the rump)."""
    out = []
    for y in np.arange(a, b, 0.03):
        s = P[(P[:, 1] >= y) & (P[:, 1] < y + 0.03)]
        if wide is not None and (not len(s) or np.abs(s[:, 0]).max() < wide):
            continue
        if half is not None:
            s = s[np.abs(s[:, 0]) < half]
        if len(s) > 3:
            out.append(float(pick(s[:, 2])))
    return out

inner = 0.6 * min(fx, hx)  # between the legs, clear of them
bl = slices(fy + 0.08, hy - 0.06, np.min, inner)
belly = float(np.median(bl)) if bl else floor + 0.45 * height
# the rump's top: the lowest of the top line over the hind legs (a crest, a mane or a moon stands higher elsewhere)
rl = slices(hy - 0.02, hy + 0.1, np.max, wide=0.7 * hx)
rump_top = min(rl) if rl else floor + 0.8 * height
joint_z = belly + 0.65 * (rump_top - belly)  # the line of the shoulders and hips
leg = joint_z - floor
knee_z, ankle_z = floor + 0.5 * leg, floor + 0.12 * leg
legs = {}
for key, x, y in (("f", fx, fy), ("h", hx, hy)):
    line = column(x, y)
    # the shank: the leg's column above the paw and below the body, where it is cleanly a leg (higher, it merges
    # into the chest and its centre drifts); a neutral leg stands straight up from it
    sh = np.array([(lx, ly) for z, lx, ly in line if floor + 0.15 * leg <= z <= floor + 0.5 * leg])
    sx, sy = (float(sh[:, 0].mean()), float(sh[:, 1].mean())) if len(sh) else (x, y)
    ax, ay = at(line, ankle_z)
    ax, ay = 0.5 * (ax + sx), 0.5 * (ay + sy)
    bend = (0.06 if key == "f" else -0.06) * leg  # a slight bend the way the knee folds (front back, hind forward): a
    # dead-straight leg gives the rig no direction to bend it in
    legs[key] = {"top": r3((sx * 0.9, sy, joint_z)), "knee": r3((sx, sy + bend, knee_z)), "ankle": r3((ax, ay, ankle_z)),
                 "toe": r3((ax, ay - 0.16 * leg, floor + 0.004))}
f_top_y, h_top_y = legs["f"]["top"][1], legs["h"]["top"][1]
nose_y = float(lo[1])
neck_end_y = f_top_y + 0.4 * (nose_y - f_top_y)
chest_end_y = f_top_y + 0.3 * (neck_end_y - f_top_y)
hips_y = h_top_y + 0.03
sz = joint_z + 0.03
head_pts = P[P[:, 1] < neck_end_y]
head_z = float(np.median(head_pts[:, 2]))
tip = P[P[:, 1] < nose_y + 0.08 * length]
spine = [(0, hips_y, sz - 0.02), (0, hips_y + (chest_end_y - hips_y) / 3, sz), (0, hips_y + 2 * (chest_end_y - hips_y) / 3, sz + 0.01),
         (0, chest_end_y, sz + 0.02), (0, neck_end_y, max(sz + 0.02, 0.5 * (sz + head_z))), (0, nose_y, float(np.median(tip[:, 2])))]

# --- tail -------------------------------------------------------------------------------------------------------------
behind = P[(P[:, 1] > hy + 0.04)]
tail = []
if len(behind):
    # the tail is what is left of the rear once the hind legs (wide, low) and rump are cut away: narrow about the middle
    ys = np.arange(hy + 0.04, hi[1], 0.02)
    root_y = None
    for y in ys:
        s = behind[(behind[:, 1] >= y) & (behind[:, 1] < y + 0.02)]
        if len(s) and np.abs(s[:, 0]).max() < 0.07 and (s[:, 2].min() > floor + 0.2 * leg or np.ptp(s[:, 2]) < 0.6 * leg):
            root_y = float(y); break
    if root_y is not None:
        t = behind[(behind[:, 1] >= root_y) & (np.abs(behind[:, 0]) < 0.09)]
        yz = t[:, 1:]
        c = yz.mean(0)
        axis = np.linalg.eigh(np.cov((yz - c).T))[1][:, -1]
        near_body = yz[np.argmin(yz[:, 0])]
        if (near_body - c) @ axis > 0:
            axis = -axis  # from the body outwards
        along = (yz - c) @ axis
        a0, a1 = np.percentile(along, 1), np.percentile(along, 99)
        n = 4 if a1 - a0 > 0.22 else 3
        for q in np.linspace(a0, a1, n + 1):
            s = yz[np.abs(along - q) < 0.035]
            p = s.mean(0) if len(s) else c + axis * q
            tail.append((0, float(p[0]), float(p[1])))
        tail[0] = (0, root_y - 0.01, tail[0][2])
if len(tail) < 3:  # no tail found: a stub, so the rig's shape is the same for every animal
    tail = [(0, hi[1] - 0.06, joint_z), (0, hi[1] - 0.03, joint_z - 0.01), (0, hi[1], joint_z - 0.02)]

S = {"name": "", "clips": clipset, "floor": round(floor, 3),
     "rate": 0.83, "step": round(0.3 * leg, 3), "lift": round(0.14 * leg, 3), "duty": 0.62,
     "spine": [r3(p) for p in spine], "tail": [r3(p) for p in tail], "trunk": [], "legs": legs,
     "head_from_y": round(neck_end_y + 0.02, 3), "leg_from_z": round(joint_z - 0.02, 3),
     "back_z": round(rump_top + 0.07, 3), "smooth": [0.8, 100]}
json.dump(S, open(out, "w"), indent=1)
print("AUTOLAND belly", round(belly, 3), "rump", round(rump_top, 3), "joint", round(joint_z, 3), "feet f", round(fx, 3), round(fy, 3), "h", round(hx, 3), round(hy, 3))
print("AUTOLAND legs", legs)
print("AUTOLAND spine", S["spine"], "tail", S["tail"], "head_from", S["head_from_y"], "leg_from", S["leg_from_z"], "back", S["back_z"])
