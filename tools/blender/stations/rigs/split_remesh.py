"""Pipeline step 2-3: split a ForgeGUI model into its body and its armour kit, remesh only the body into one closed
skin of clean quads with its painted texture baked on, and keep every kit piece exactly as generated.
blender -b --factory-startup -P split_remesh.py -- <model.glb> <outdir> [voxel] [kit_tris]
- kit: loose pieces mostly metal (the metal map) or purple (the Eternals' regalia); the rest is body
- body: voxel remesh (fills the holes under the armour), smart UV, Cycles bake of the body pieces' colour
- the kit is thinned to about kit_tris triangles if it has more (body + kit must stay under Roblox's 20,000)
Writes <outdir>/body.glb, <outdir>/kit.glb, <outdir>/split.json (counts)."""
import bpy, colorsys, json, os, sys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, outdir = args[0], args[1]
voxel = float(args[2]) if len(args) > 2 else 0.012
kit_tris = int(args[3]) if len(args) > 3 else 6000
os.makedirs(outdir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
for x in list(bpy.data.objects):
    if x.type != "MESH":
        bpy.data.objects.remove(x, do_unlink=True)
bpy.context.view_layer.objects.active = o; o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mat = o.material_slots[0].material
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bsdf.inputs["Base Color"].links[0].from_node.image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
# the metal map (glTF metallic-roughness, through a Separate Color node): armour is metal, fur is not. The links were
# cut above, so read it from the material's nodes
mpx = None
for nd in mat.node_tree.nodes:
    if nd.type == "SEPARATE_COLOR" and nd.inputs[0].is_linked:
        mimg = nd.inputs[0].links[0].from_node.image
        MW, MH = mimg.size
        mpx = np.array(mimg.pixels[:], dtype=np.float32).reshape(MH, MW, 4)[:, :, 2]  # glTF: metal in blue
print("METAL MAP", mpx is not None)
for name in ("Normal", "Roughness", "Metallic"):
    for l in list(bsdf.inputs[name].links):
        mat.node_tree.links.remove(l)

bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
pieces = [x for x in bpy.data.objects if x.type == "MESH"]
kit, body = [], []
for p in pieces:
    me = p.data
    uv = me.uv_layers.active.data
    polys = list(me.polygons)
    votes = n = 0
    for poly in polys[:: max(1, len(polys) // 60)]:
        u = sum(uv[i].uv[0] for i in poly.loop_indices) / poly.loop_total
        v = sum(uv[i].uv[1] for i in poly.loop_indices) / poly.loop_total
        r, g, b = px[min(H - 1, int((v % 1) * H)), min(W - 1, int((u % 1) * W)), :3]
        h, s, val = colorsys.rgb_to_hsv(r, g, b)
        purple = 0.68 < h < 0.92 and s > 0.3
        # armour gold is pale and yellow (hue over 0.112, bright); gold fur, even glowing, is a deeper orange-gold
        # (hue about 0.10, darker) and the metal map marks some of it as metal, so it cannot decide alone
        gold = h > 0.112 and h < 0.18 and val > 0.82
        votes += 1 if (gold or purple) else 0
        n += 1
    (kit if votes > 0.5 * n and not os.environ.get("NOKIT") else body).append(p)  # NOKIT: all body (a creature whose own material is purple, like crystal)
# the biggest piece is always body (it may be gold-furred)
big = max(pieces, key=lambda x: len(x.data.polygons))
if big in kit:
    kit.remove(big); body.append(big)

def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for x in objs:
        x.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active
    j.name = name
    return j

bodysrc = join(body, "bodysrc")
kitobj = join(kit, "kit") if kit else None
counts = {"pieces": len(pieces), "kit_pieces": len(kit), "body_pieces": len(body)}

# the body skin: a remeshed copy of the body pieces
bpy.ops.object.select_all(action="DESELECT"); bodysrc.select_set(True); bpy.context.view_layer.objects.active = bodysrc
bpy.ops.object.duplicate()
skin = bpy.context.view_layer.objects.active; skin.name = "body"
skin.data.materials.clear()
skin.data.remesh_voxel_size = voxel
bpy.ops.object.voxel_remesh()
# keep only the main shell (the voxel pass leaves a few tiny bubbles)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
shells = sorted([x for x in bpy.data.objects if x.name.startswith("body")], key=lambda x: -len(x.data.polygons))
skin = [x for x in shells if x is not bodysrc][0]
for x in shells:
    if x is not skin and x is not bodysrc:
        bpy.data.objects.remove(x, do_unlink=True)
skin.name = "body"
for p in skin.data.polygons:
    p.use_smooth = True
counts["body_quads"] = len(skin.data.polygons)
bpy.context.view_layer.objects.active = skin; bpy.ops.object.select_all(action="DESELECT"); skin.select_set(True)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
bimg = bpy.data.images.new("body_tex", 2048, 2048, alpha=False)
bmat = bpy.data.materials.new("body"); bmat.use_nodes = True
tex = bmat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = bimg
bmat.node_tree.links.new(tex.outputs["Color"], bmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
skin.data.materials.append(bmat); bmat.node_tree.nodes.active = tex
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 4
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = voxel * 3
sc.render.bake.max_ray_distance = voxel * 8
sc.render.bake.margin = 6
bpy.ops.object.select_all(action="DESELECT"); bodysrc.select_set(True); skin.select_set(True)
bpy.context.view_layer.objects.active = skin
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
bimg.filepath_raw = os.path.join(outdir, "body_tex.png"); bimg.file_format = "PNG"; bimg.save()
bpy.data.objects.remove(bodysrc, do_unlink=True)

if kitobj:
    have = sum(len(p.vertices) - 2 for p in kitobj.data.polygons)
    if have > kit_tris:
        bpy.ops.object.select_all(action="DESELECT"); kitobj.select_set(True); bpy.context.view_layer.objects.active = kitobj
        m = kitobj.modifiers.new("thin", "DECIMATE"); m.ratio = kit_tris / have
        bpy.ops.object.modifier_apply(modifier=m.name)
    counts["kit_tris"] = sum(len(p.vertices) - 2 for p in kitobj.data.polygons)
counts["body_tris"] = sum(len(p.vertices) - 2 for p in skin.data.polygons)

for name, obj in (("body.glb", skin), ("kit.glb", kitobj)):
    if not obj:
        continue
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(outdir, name), export_format="GLB", use_selection=True)
json.dump(counts, open(os.path.join(outdir, "split.json"), "w"), indent=1)
print("SPLIT", counts)
