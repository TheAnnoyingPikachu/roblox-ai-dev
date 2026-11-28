"""The rig drawn inside the animal: the body see-through, each bone a coloured stick, its joint a ball; the foot targets
green, the knee aims white. blender -b <rig.blend> -P bones.py -- <outdir>"""
import bpy, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rigpose as rp
from mathutils import Vector

outdir = sys.argv[sys.argv.index("--") + 1]
os.makedirs(outdir, exist_ok=True)
rig = rp.Rig()
GROUPS = [("hips spine chest", (1.0, 0.75, 0.1)), ("neck head", (0.65, 0.35, 1.0)), ("tail", (1.0, 0.45, 0.1)),
          ("upper lower foot", (0.15, 0.55, 1.0)), ("trunk jaw ear wing", (0.95, 0.2, 0.6)), ("ik", (0.1, 0.85, 0.3)),
          ("pole", (0.95, 0.95, 0.95))]


def colour(name):
    for keys, c in GROUPS:
        if any(name.startswith(k) for k in keys.split()):
            return c
    return (0.8, 0.8, 0.8)


def mat(c, emit=1.5):
    m = bpy.data.materials.new("m"); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Emission Color"].default_value = (*c, 1)
    b.inputs["Emission Strength"].default_value = emit
    return m


for b in rig.arm.data.bones:
    if b.name == "root":
        continue
    h, t = b.head_local, b.tail_local
    c = colour(b.name)
    m = mat(c)
    r = 0.012 if b.use_deform else 0.006
    if b.use_deform or b.name.startswith("ik"):
        d = t - h
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(h + t) / 2, vertices=10)
        cy = bpy.context.object
        cy.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        cy.data.materials.append(m)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r * 1.6, location=h, segments=12, ring_count=8)
    bpy.context.object.data.materials.append(m)
# the skin see-through
for o in (rig.body, rig.kit):
    if not o:
        continue
    for slot in o.material_slots:
        m = slot.material
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            b.inputs["Alpha"].default_value = 0.22
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        if hasattr(m, "blend_method"):
            m.blend_method = "BLEND"
cam = rp.stage(rig.floor, res=(1000, 640), bg=(0.12, 0.12, 0.16))
for tag, d, dist in (("side", (-1.0, -0.02, 0.05), 1.85), ("q", (-0.75, -0.85, 0.45), 1.95)):
    rp.aim(cam, (0, 0, rig.floor + 0.22), d, dist)
    rp.shot(os.path.join(outdir, f"bones_{tag}.png"))
print("BONES", len(rig.arm.data.bones), "deforming", sum(1 for b in rig.arm.data.bones if b.use_deform))
