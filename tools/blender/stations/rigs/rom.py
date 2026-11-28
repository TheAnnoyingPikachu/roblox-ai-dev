"""Range of motion: each joint alone at the edge of its budget, the body's stretch measured and the stretched faces red.
blender -b <rig.blend> -P rom.py -- <outdir>
Budgets (the stretch-room rules): leg swing +-30, knee 60 (front: foot forward, hind: foot back), spine +-12 pitch and
yaw a bone, neck +-20, head +-25, tail +-40 spread along it. The left legs stand for the right (mirrored).
Writes <outdir>/<test>.png and <outdir>/rom.json ({test: stretch %})."""
import bpy, json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rigpose as rp
from rigpose import R

outdir = sys.argv[sys.argv.index("--") + 1]
os.makedirs(outdir, exist_ok=True)
rig = rp.Rig()
rig.ik(False)
cam = rp.stage(rig.floor, res=(420, 300))
rp.aim(cam, (0, 0, rig.floor + 0.22), (-1.0, -0.25, 0.25), 1.55)
red = bpy.data.materials.new("stretched"); red.use_nodes = True
red.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 0.05, 0.03, 1)
rig.body.data.materials.append(red)
RED = len(rig.body.data.materials) - 1

tails = rig.tails
TESTS = {
    "front leg forward 30": {"upper_fl": R(30)}, "front leg back 30": {"upper_fl": R(-30)}, "front knee 60": {"lower_fl": R(60)},
    "hind leg forward 30": {"upper_hl": R(30)}, "hind leg back 30": {"upper_hl": R(-30)}, "hind knee 60": {"lower_hl": R(-60)},
    "spine arch up 12": {"spine": R(12), "chest": R(12)}, "spine arch down 12": {"spine": R(-12), "chest": R(-12)},
    "spine bend side 12": {"spine": R(0, 12), "chest": R(0, 12)},
    "neck up 20": {b: R(20 / len(rig.necks)) for b in rig.necks}, "neck down 20": {b: R(-20 / len(rig.necks)) for b in rig.necks},
    "neck side 20": {b: R(0, 20 / len(rig.necks)) for b in rig.necks},
    "head up 25": {"head": R(25)}, "head down 25": {"head": R(-25)}, "head side 25": {"head": R(0, 25)},
    "tail up 40": {b: R(-40 / len(tails)) for b in tails}, "tail down 40": {b: R(40 / len(tails)) for b in tails},
    "tail side 40": {b: R(0, 40 / len(tails)) for b in tails},
}
out = {}
for i, (name, rots) in enumerate(TESTS.items()):
    rig.apply({})
    for b, M in rots.items():
        rig.setrot(b, M)
    bpy.context.view_layer.update()
    both, s, sq, bad = rig.stretch(split=True)
    out[name] = round(s, 2)
    for f, b in zip(rig.body.data.polygons, bad):
        f.material_index = RED if b else 0
    rp.shot(os.path.join(outdir, f"rom_{i:02d}.png"))
    print("ROM", name, round(s, 2))
for f in rig.body.data.polygons:
    f.material_index = 0
json.dump({"tests": list(TESTS), "stretch": out, "note": "stretched only (edges longer by a quarter); red = stretched"}, open(os.path.join(outdir, "rom.json"), "w"), indent=1)
print("DONE")
