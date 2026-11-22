"""Render one animal's concepts on its built FBX.

blender --background --factory-startup --python render.py -- <asset> <out dir> keys|full [only,...]

keys: one still per clip key (and six per idle) for checking the poses, plus fit.json.
full: every frame at 24 fps (idles at 12): the idle loop; a clip held between half a second of the
shared idle before and after, as the game plays it.
Each clip key is fitted first: where it pushes the feet under the ground the body is raised by as much
(skinned models get no lift in the game), and the fitted keys are written to fit.json."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import concepts as C  # noqa: E402
import rig as R  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1 :]
asset, out, mode = args[0], os.path.abspath(args[1]), args[2]
only = set(args[3].split(",")) if len(args) > 3 else None
name, spec = C.CONCEPTS[asset]
DIST = {"creature_meerkat_forge": 1.3, "creature_flamingo_forge": 1.25}  # their dives and burrow go far ahead
r = R.Rig(asset, view=(-1.0, -0.55, 0.24), dist=DIST.get(asset, 1.0), res=(640, 480))
HOLD = 0.5


def shown(pose):
    return C.upright_tail(pose) if r.upright else pose


def lifted(pose):
    """the pose with its body raised by however far it pushes the feet under the ground"""
    r.pose(shown(pose))
    s = r.sink()
    if s <= 0.005:
        return pose, s
    pose = {j: list(v) + [0] * (6 - len(v)) for j, v in pose.items()}
    body = pose.setdefault("body", [0] * 6)
    body[4] = round(body[4] + s / r.scale, 3)
    return pose, s


if mode == "full":  # the empty floor, so the GIFs can be cropped to where the animal goes
    r.body.hide_render = True
    r.shot(os.path.join(out, "bg.png"))
    r.body.hide_render = False
fit = {"asset": asset, "name": name, "scale": r.scale, "upright": r.upright, "clips": {}, "idles": {}}
os.makedirs(os.path.join(out, "frames"), exist_ok=True)
os.makedirs(os.path.join(out, "keys"), exist_ok=True)
for kind in ("attack", "power"):
    for key, item in spec[kind].items():
        if only and key not in only:
            continue
        label, text, keys = item[:3]
        flags = item[3] if len(item) > 3 else {}
        fitted, raised = [], []
        for t, pose in keys:
            p, s = (pose, 0.0) if flags.get("dig") else lifted(pose)
            fitted.append((t, p))
            raised.append(round(max(0.0, s), 3))
        length = keys[-1][0]
        worst = 0.0
        if not flags.get("dig"):
            for i in range(int(length * 48) + 1):
                r.pose(shown(C.sample(fitted, i / 48)))
                worst = max(worst, r.sink())
        fit["clips"][key] = {"kind": kind, "label": label, "text": text, "length": length, "flags": flags,
                             "keys": fitted, "raised": raised, "sink_between": round(worst, 3)}
        print("FIT", asset, key, "raised", raised, "worst between keys", round(worst, 3))
        if mode == "keys":
            for i, (t, p) in enumerate(fitted):
                r.pose(shown(p))
                r.shot(os.path.join(out, "keys", f"{key}_{i:02d}_{t:.2f}.png"))
        else:
            n = round((HOLD + length + HOLD) * 24)
            for i in range(n + 1):
                tt = i / 24
                tc = tt - HOLD
                p = C.sample(fitted, tc) if 0 <= tc <= length else C.neutral(tt, r.upright)
                r.pose(shown(p))
                r.shot(os.path.join(out, "frames", f"{key}_{i:03d}.png"))
for key, (label, text, fn) in spec["idle"].items():
    if only and key not in only:
        continue
    fps = 12
    n = round(C.LOOP * fps)
    raised = 0.0
    for i in range(n):
        p, s = lifted(fn(i / fps))
        raised = max(raised, s)
        if mode == "full":
            r.pose(shown(p))
            r.shot(os.path.join(out, "frames", f"{key}_{i:03d}.png"))
        elif i % (n // 6) == 0:
            r.pose(shown(p))
            r.shot(os.path.join(out, "keys", f"{key}_{i:02d}_{i / fps:.2f}.png"))
    fit["idles"][key] = {"label": label, "text": text, "raised_most": round(raised, 3)}
    print("IDLE", asset, key, "raised at most", round(raised, 3))
json.dump(fit, open(os.path.join(out, f"fit_{mode}.json"), "w"), indent=1)
print("DONE", asset)
