"""Clip options for a rigged animal (its rig.blend), baked as they will play (timing curves, steps, follow-through:
rigpose.py), rendered side-on, and every frame's stretch measured.
blender -b <rig.blend> -P clips.py -- <outdir> [set] [only]
  set: a module in clipsets/ (a species' own moves; "quad" is the shared four-legged set)
  MEASURE=1: no renders, only the numbers.
Writes <outdir>/<clip>/f_##.png and <outdir>/clips.json."""
import bpy, importlib, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rigpose as rp

args = sys.argv[sys.argv.index("--") + 1:]
outdir = args[0]
setname = args[1] if len(args) > 1 else "quad"
only = args[2] if len(args) > 2 else None
S = importlib.import_module(f"clipsets.{setname}")
CONTACT = {"attack": 0.44, "power": 0.92}  # when the blow lands (the game's ATTACK_CONTACT and MAGIC_IMPACT)
BAKE, SHOW = 60, {"idle": 12}  # baked frames a second; shown frames a second by kind (20 otherwise)

rig = rp.Rig()
cam = rp.stage(rig.floor)
dims = rig.body.dimensions  # frame by the animal's size: a tall one rears higher
mid = (0, 0.0, rig.floor + 0.55 * dims.z)
rp.aim(cam, mid, (-1.0, -0.12, 0.12), 1.95 * max(dims.y, 1.9 * dims.z))
info = {}
for key, (name, kind, desc, secs, fn, loop) in S.CLIPS.items():
    if only and only not in key:
        continue
    d = os.path.join(outdir, key)
    os.makedirs(d, exist_ok=True)
    frames = rig.bake(fn, secs, loop, BAKE, getattr(S, "SPRING", (2.6, 0.32)))
    fps = SHOW.get(kind, 20)
    picks = frames[:: BAKE // fps]
    worst = [0.0, 0.0, 0.0]
    for i, fr in enumerate(picks):
        rig.show(fr)
        both, longer, shorter, _ = rig.stretch(split=True)
        worst = [max(a, b) for a, b in zip(worst, (both, longer, shorter))]
        if not os.environ.get("MEASURE"):
            rp.shot(os.path.join(d, f"f_{i:02d}.png"))
    info[key] = {"name": name, "kind": kind, "desc": desc, "seconds": secs, "frames": len(picks), "fps": fps, "loop": loop,
                 "contact": CONTACT.get(kind), "worst_stretch": round(worst[1], 2), "worst_squash": round(worst[2], 2),
                 "worst_both": round(worst[0], 2)}
    print("CLIP", key, len(picks), [round(x, 2) for x in worst])
path = os.path.join(outdir, "clips.json")
old = json.load(open(path)) if os.path.exists(path) and only else {}
old.update(info)
json.dump(old, open(path, "w"), indent=1)
print("DONE")
