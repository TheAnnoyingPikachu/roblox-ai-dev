"""The ForgeGUI creatures (decision 0088): every animal and variant remade as a ForgeGUI 3D model from
SHANNON's chosen concept sheets, then cut here into the seven jointed pieces the game animates (body,
head, tail, leg_fl, leg_fr, leg_bl, leg_br), so every clip in Creatures.client keeps working.

The models are not committed (about 6 MB each): forge_sources.json lists each one's ForgeGUI URL and
build.py downloads it once into build/blender/stations/forge/. Each is scaled to the height its
hand-built model had, so arenas, cameras and cards still fit.

Cutting: each face goes to the first piece whose rule its centre meets, in the box's own measures:
f is how far forward (0 tail end, 1 nose), h how high (0 ground, 1 top), s the side (-1 right, +1
left; left is +X). The cut edges are capped so a turned piece shows no hole. A joint sits at the
middle of the edge its piece shares with the body (or, for a piece that does not touch it, at the
middle of the piece's top). Facing Blender -Y, standing on z = 0, as every Stations model.

Glow: these models carry their glow in the texture, so they have no Neon `_glow` pieces.
"""

import json
import os
import urllib.request

import bmesh
import bpy
import kit as k
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = os.path.join(HERE, "..", "forge_sources.json")
CACHE = os.path.join(k.OUT, "forge")

# The game overrides the hand-built assets of the same names with these (build.py `specs`).
OVERRIDES = True


# Cutting rules per body plan: (piece, test(f, h, s)), first match wins; the rest is the body.
def quad(head=(0.78, 0.45), tail=(0.12, 0.35), legs=0.42, front=0.5):
    hf, hh = head
    tf, th = tail
    return [
        ("head", lambda f, h, s: f > hf and h > hh),
        ("tail", lambda f, h, s: f < tf and h > th),
        ("leg_fl", lambda f, h, s: h < legs and f >= front and s >= 0),
        ("leg_fr", lambda f, h, s: h < legs and f >= front and s < 0),
        ("leg_bl", lambda f, h, s: h < legs and f < front and s >= 0),
        ("leg_br", lambda f, h, s: h < legs and f < front and s < 0),
    ]


def tortoise(head=0.84, tail=0.07, legs=0.36, side=0.3):
    return [
        ("head", lambda f, h, s: f > head),
        ("tail", lambda f, h, s: f < tail and h < 0.5),
        ("leg_fl", lambda f, h, s: h < legs and abs(s) > side and f >= 0.5 and s > 0),
        ("leg_fr", lambda f, h, s: h < legs and abs(s) > side and f >= 0.5 and s < 0),
        ("leg_bl", lambda f, h, s: h < legs and abs(s) > side and f < 0.5 and s > 0),
        ("leg_br", lambda f, h, s: h < legs and abs(s) > side and f < 0.5 and s < 0),
    ]


def meerkat(head=0.78, arms=(0.45, 0.72, 0.5), legs=0.22, tail=0.4):
    a0, a1, af = arms
    return [
        ("head", lambda f, h, s: h > head),
        ("tail", lambda f, h, s: f < tail and h < 0.45),
        # standing up: its arms are the front legs, its feet the back legs (as the hand-built ones)
        ("leg_fl", lambda f, h, s: a0 < h < a1 and f > af and s > 0.2),
        ("leg_fr", lambda f, h, s: a0 < h < a1 and f > af and s < -0.2),
        ("leg_bl", lambda f, h, s: h < legs and s >= 0),
        ("leg_br", lambda f, h, s: h < legs and s < 0),
    ]


def bird(head=(0.55, 0.62), legs=0.45, wing=(0.42, 0.45, 0.85), tail=0.15, leg_from=0.0):
    hf, hh = head
    ws, w0, w1 = wing
    return [
        ("head", lambda f, h, s: f > hf and h > hh),
        # two legs are the front legs, the wings the back legs (as the hand-built flamingos)
        ("leg_fl", lambda f, h, s: h < legs and f > leg_from and s >= 0),
        ("leg_fr", lambda f, h, s: h < legs and f > leg_from and s < 0),
        ("tail", lambda f, h, s: f < tail and h >= legs),
        ("leg_bl", lambda f, h, s: w0 < h < w1 and s > ws),
        ("leg_br", lambda f, h, s: w0 < h < w1 and s < -ws),
    ]


PLANS = {
    "jackal": quad(head=(0.76, 0.5), tail=(0.27, 0.5), legs=0.38),
    "cheetah": quad(head=(0.8, 0.5), tail=(0.25, 0.2), legs=0.42),
    "lion": quad(head=(0.68, 0.35), tail=(0.12, 0.3), legs=0.38),
    "rhino": quad(head=(0.74, 0.25), tail=(0.06, 0.3), legs=0.33),
    "elephant": quad(head=(0.7, 0.25), tail=(0.05, 0.3), legs=0.38),
    "giraffe": quad(head=(0.6, 0.55), tail=(0.12, 0.3), legs=0.45),
    "tortoise": tortoise(),
    "meerkat": meerkat(arms=(0.45, 0.72, 0.6)),
    "flamingo": bird(),
    # one model's shape differs from its kind's
    "jackal_pharaoh": quad(head=(0.76, 0.5), tail=(0.3, 0.25), legs=0.38),  # its tail hangs low
    "jackal_sphinx": quad(head=(0.76, 0.5), tail=(0.1, 0.3), legs=0.38),  # its wings reach back over the tail
    # its cloud raises the top; arms high and legs low enough that the game still stands it upright
    "meerkat_storm": meerkat(head=0.6, arms=(0.42, 0.58, 0.6), legs=0.13),
    "tortoise_island": tortoise(legs=0.2),  # its palm raises the top
    "flamingo_phoenix": bird(leg_from=0.3),  # its flame streamers hang low behind its legs
    "rhino_crystal": quad(head=(0.74, 0.25), tail=(0.1, 0.12), legs=0.33),  # its crystal mace hangs low
}


def _sources():
    with open(SOURCES, encoding="utf-8") as f:
        return json.load(f)


def _fetch(name, url):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f"{name}.glb")
    if not os.path.exists(path):
        urllib.request.urlretrieve(url, path)
    return path


def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in meshes:
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    if len(meshes) > 1:
        with bpy.context.temp_override(active_object=meshes[0], selected_editable_objects=meshes):
            bpy.ops.object.join()
    return meshes[0]


def _keep_texture(ob):
    """Keep the model's own UVs as `forge` for the bake to read; finalize unwraps a new active map."""
    ob.data.uv_layers[0].name = "forge"
    for m in ob.data.materials:
        tree = m.node_tree
        uv = tree.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "forge"
        for node in tree.nodes:
            if node.type == "TEX_IMAGE":
                tree.links.new(uv.outputs["UV"], node.inputs["Vector"])
    ob.data.uv_layers.new(name="UVMap")
    ob.data.uv_layers.active = ob.data.uv_layers["UVMap"]


# Roblox draws only a face's front, and ForgeGUI builds manes, ears and fins from single open sheets, so
# kit's bake gives every face a back (`both_sides`) and a piece is kept to half Roblox's 20,000 triangles.
HALF = 9800


def _thin(piece):
    if len(piece.data.polygons) <= HALF:
        return
    mod = piece.modifiers.new("decimate", "DECIMATE")
    mod.ratio = HALF / len(piece.data.polygons) * 0.98
    with bpy.context.temp_override(object=piece, active_object=piece, selected_objects=[piece]):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def _sweep(ob):
    """Drops loose bits lying on the ground round the feet (gems a model was made with, from its concept):
    a loose piece that is low and small and touches no other piece."""
    lo, hi = k._ground_dims([ob])
    tall, wide = hi.z - lo.z, max(hi.x - lo.x, hi.y - lo.y)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen, litter = set(), []
    for start in bm.faces:
        if start.index in seen:
            continue
        island, todo = [], [start]
        seen.add(start.index)
        while todo:
            f = todo.pop()
            island.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        todo.append(g)
        vs = [v.co for f in island for v in f.verts]
        top = max(v.z for v in vs)
        span = max(max(v.x for v in vs) - min(v.x for v in vs), max(v.y for v in vs) - min(v.y for v in vs))
        if top - lo.z < 0.06 * tall and span < 0.08 * wide:
            litter += island
    bmesh.ops.delete(bm, geom=litter, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()


def _smooth(objs):
    """finalize shades by angle (right for the hand-built facets); a ForgeGUI model is smooth-shaded."""
    for o in objs:
        for name in ("sharp_edge", "sharp_face"):
            if name in o.data.attributes:
                o.data.attributes.remove(o.data.attributes[name])
        o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))


def cut(ob, rules):
    """Splits `ob` into {piece: object} by `rules` and returns (pieces, joints)."""
    lo, hi = k._ground_dims([ob])
    size = hi - lo
    mid = (lo + hi) / 2
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    names = ["body"] + [n for n, _ in rules]
    which = {}
    for face in bm.faces:
        c = face.calc_center_median()
        f = (hi.y - c.y) / size.y
        h = (c.z - lo.z) / size.z
        s = (c.x - mid.x) / (size.x / 2)
        which[face.index] = next((n for n, test in rules if test(f, h, s)), "body")
    # where each piece meets the body: the vertices shared by both
    shared = {n: [] for n in names}
    for v in bm.verts:
        mine = {which[f.index] for f in v.link_faces}
        if "body" in mine:
            for n in mine - {"body"}:
                shared[n].append(v.co.copy())
    bm.free()

    pieces, joints = {}, {}
    for n in names:
        keep = {i for i, p in which.items() if p == n}
        if not keep:
            continue
        piece = ob.copy()
        piece.data = ob.data.copy()
        piece.name = piece.data.name = n
        bpy.context.scene.collection.objects.link(piece)
        bm = bmesh.new()
        bm.from_mesh(piece.data)
        bm.faces.ensure_lookup_table()
        # no caps: the models are many loose open pieces, so filling "holes" sprays faces over them
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        bm.to_mesh(piece.data)
        bm.free()
        _thin(piece)
        pieces[n] = piece
        if n == "body":
            continue
        if shared[n]:
            joints[n] = tuple(sum(shared[n], Vector()) / len(shared[n]))
        else:
            plo, phi = k._ground_dims([piece])
            joints[n] = ((plo.x + phi.x) / 2, (plo.y + phi.y) / 2, phi.z)
    bpy.data.objects.remove(ob)
    return pieces, joints


def maker(name, src):
    def build():
        ob = _import(_fetch(name, src["url"]))
        if src.get("sweep"):
            _sweep(ob)
        lo, hi = k._ground_dims([ob])
        scale = src["height"] / (hi.z - lo.z)
        ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
        ob.data.transform(Matrix.Scale(scale, 4))
        _keep_texture(ob)
        pieces, joints = cut(ob, PLANS[src["plan"]])
        return {n: [p] for n, p in pieces.items()}, joints

    return build


# No AO or top light: the ForgeGUI texture already carries its own shading.
BAKE = dict(ao_samples=1, ao_floor=1.0, toplight=0.0, margin=10, uv_margin=0.006, uv_hook=_smooth)

ASSETS = [
    dict(name=name, build=maker(name, src), scale=1, budget=7 * HALF, finalize=BAKE, joints={}, glow={}, notes=src["notes"])
    for name, src in _sources().items()
]


def _joints_of(asset):
    """build.py reads `joints` after build(): fill the dict in place."""
    inner = asset["build"]

    def build():
        groups, j = inner()
        asset["joints"].update(j)
        return groups

    asset["build"] = build


for _a in ASSETS:
    _joints_of(_a)
