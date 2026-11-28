"""Keep the generated model exactly as made and give it the rig: blender -b <rig.blend> -P transfer_rig.py -- <raw.glb> <out.blend>
The remeshed skin in rig.blend (smoothly weighted by quadrig.py) is only a weight proxy now. The original model is
tidied (pieces welded, every face turned to face out, as skin_forge.py does: a face is drawn from its front only) and
each of its vertices takes the bone weights of the nearest point of the proxy; a small loose piece (a plate, a band, a
gem) takes its average so it moves whole. The original mesh then replaces the proxy (and the kit) as "body"."""
import bpy, bmesh, os, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
SMALL = float(os.environ.get("SMALL", 0.12))  # a loose piece smaller than this (its box's diagonal, model units) moves whole
arm = bpy.data.objects["rig"]
proxy = bpy.data.objects["body"]
kit = bpy.data.objects.get("kit")

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=src)
new = [o for o in bpy.data.objects if o not in before]
model = [o for o in new if o.type == "MESH"][0]
for o in new:
    if o is not model:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
model.select_set(True); bpy.context.view_layer.objects.active = model
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
model.parent = None
mat = model.material_slots[0].material
b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
for name in ("Normal", "Roughness", "Metallic"):  # the game shows the colour map only
    for l in list(b.inputs[name].links):
        mat.node_tree.links.remove(l)

# tidy: weld coincident vertices, turn every face out (rays from its centre: the side more escape from is outside)
me = model.data
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.faces.ensure_lookup_table()
tree = BVHTree.FromBMesh(bm)
flipped = 0
for f in bm.faces:
    n = f.normal
    if n.length < 0.5:
        continue
    c = f.calc_center_median()
    a = n.orthogonal().normalized(); bb = n.cross(a)
    rays = [Vector((0, 0, 0))] + [(a * x + bb * y) * 0.6 for x, y in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    def escapes(side):
        return sum(1 for r in rays if tree.ray_cast(c + (n * side + r).normalized() * 1e-4, (n * side + r).normalized())[0] is None)
    if escapes(-1) > escapes(1):
        f.normal_flip(); flipped += 1
bm.normal_update()
for f in bm.faces:
    f.smooth = False
bm.to_mesh(me); bm.free()
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("TIDY faces turned out", flipped, "tris", tris)
if tris > 20000:
    raise RuntimeError(f"{tris} triangles is over Roblox's 20,000")

# weights from the proxy: nearest point on its surface, its triangle's corner weights blended by distance
pb = bmesh.new(); pb.from_mesh(proxy.data); bmesh.ops.triangulate(pb, faces=pb.faces); pb.faces.ensure_lookup_table()
ptree = BVHTree.FromBMesh(pb)
names = [g.name for g in proxy.vertex_groups]
pw = [{names[g.group]: g.weight for g in v.groups} for v in proxy.data.vertices]
W = []
for v in me.vertices:
    loc, nrm, fi, dist = ptree.find_nearest(v.co)
    f = pb.faces[fi]
    acc = {}
    ws = [1.0 / max((loc - vv.co).length, 1e-6) for vv in f.verts]
    tot = sum(ws)
    for vv, k in zip(f.verts, ws):
        for g, x in pw[vv.index].items():
            acc[g] = acc.get(g, 0) + x * k / tot
    W.append(acc)

# small loose pieces move whole
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seen, rigid = set(), 0
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
    lo = Vector((min(bm.verts[i].co[k] for i in isl) for k in range(3)))
    hi = Vector((max(bm.verts[i].co[k] for i in isl) for k in range(3)))
    if (hi - lo).length < SMALL:
        mean = {}
        for i in isl:
            for g, x in W[i].items():
                mean[g] = mean.get(g, 0) + x / len(isl)
        for i in isl:
            W[i] = mean
        rigid += 1
bm.free()
groups = {n: model.vertex_groups.new(name=n) for n in names}
for i, w in enumerate(W):
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]  # Roblox keeps four bones a vertex
    t = sum(x for _, x in top) or 1
    for g, x in top:
        if x / t > 0.01:
            groups[g].add([i], x / t, "REPLACE")
print("WEIGHTS", len(W), "vertices,", rigid, "small pieces rigid")

# the original model replaces the proxy and the kit
for o in (proxy, kit):
    if o:
        bpy.data.objects.remove(o, do_unlink=True)
model.name = "body"
model.parent = arm
mod = model.modifiers.new("rig", "ARMATURE"); mod.object = arm
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED", out)

# a plain, big-faceted model comes out as loose shards rather than a skin (a third of its edges open, against 2 to 4 %),
# many of them inside out: whole when drawn two-sided, as the game draws it, but worth a look
import bmesh  # noqa: E402
bm = bmesh.new(); bm.from_mesh(model.data)
share = 100 * sum(1 for e in bm.edges if len(e.link_faces) == 1) / max(1, len(bm.edges))
print("HOLES", round(share, 1), "% of its edges are open", "SHARDS: look at it with look.py before going on" if share > 15 else "")
