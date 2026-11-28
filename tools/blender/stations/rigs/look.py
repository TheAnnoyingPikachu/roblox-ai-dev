"""Two close looks at a rigged model at rest, as Roblox draws it (fronts only): rear and front three-quarter.
blender -b <rig_full.blend> -P look.py -- <out prefix>"""
import bpy, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rigpose as rp
out = sys.argv[sys.argv.index("--") + 1]
rig = rp.Rig()
for m in rig.body.data.materials:
    m.use_backface_culling = True
cam = rp.stage(rig.floor, res=(1000, 700))
mid = (0, 0, rig.floor + 0.2)
for name, d in (("rear", (-0.8, 1.0, 0.3)), ("front", (-1.0, -0.7, 0.25))):
    rp.aim(cam, mid, d, 1.7)
    rp.shot(f"{out}_{name}.png")
