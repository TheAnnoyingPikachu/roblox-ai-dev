"""Shared Blender helpers for the Egg Garden assets (docs/assets/garden-blender-plan.md).

Reuses the proven Night kit (tools/blender/night/kit.py: materials, primitives, finalize, bake,
contact sheet) with Garden output folders, a bright toy-like preview and shell helpers.
Conventions as Night (1 unit = 1 stud, origin at base centre) except the front: Garden models face
Blender -Y, not +Y. NIGHT-010 measured uploaded models arriving with their Blender +Y side on
Roblox +Z at yaw 0, so a -Y front reaches Roblox -Z, the LookVector of an unrotated CFrame.

A `glow` part (mesh `<asset>_glow`) stays untextured and the game sets it to Neon in the colour under
`glow` in manifest.json. Only multi-mesh assets can have one: eggs and moving pieces are one mesh
(docs/architecture/garden.md section 9), so their glowing pieces are baked bright.
"""

import importlib.util
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

_spec = importlib.util.spec_from_file_location(
    "nightkit", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "night", "kit.py")
)
_night = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_night)

# Re-export the Night primitives and pipeline.
for _name in dir(_night):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_night, _name)

ROOT = _night.ROOT
OUT = os.path.join(ROOT, "build", "blender", "garden")
PREVIEWS = os.path.join(OUT, "previews")
_night.OUT = OUT
_night.PREVIEWS = PREVIEWS

# Palette (sRGB 0-255): src/garden/Plots.luau PASTELS and FLOWERS, EGG_COLOURS, toy brights.
CREAM = (255, 242, 215)
BLUSH = (255, 200, 220)
SKY = (200, 230, 255)
BUTTER = (255, 240, 180)
MINT = (210, 255, 210)
LILAC = (230, 210, 255)
ROSE = (255, 150, 190)
SUNNY = (255, 230, 120)
VIOLET = (190, 160, 255)
PEACH = (255, 170, 120)
CORAL = (255, 105, 105)
GRASS = (130, 205, 95)
TEAL = (95, 215, 205)
BERRY = (235, 70, 120)
WOODY = (190, 135, 90)
SNOW = (255, 253, 248)
INKY = (70, 50, 60)
GOLD_HI = (255, 225, 130)
GOLD_MID = (245, 185, 70)
GOLD_LO = (205, 130, 40)


# Materials -----------------------------------------------------------------------------------


def paint(name, stops, lo=0.0, hi=3.0, axis="Z", dots=(), bands=None, rough=0.4, grain=None, splat=(), rays=None, marks=(), emit=0.0, rest=False):
    """Baked colour: `stops` [(0-1, rgb), ...] along an object axis from lo to hi, then optional
    hard polka `dots` [(rgb, scale, size), ...] and `bands` (rgb, period in studs).
    rest=True reads every coordinate from the `rest` attribute that `fuse` stores (positions at
    build time) instead of object space, so the paint stays put when `fit` rescales the model,
    and `zone` can add markings to it. Only for fused bodies.
    grain (amount, scale[, "noise"|"wave"]) shades the colour by a fine texture (linen, bark).
    splat [(rgb, scale, threshold, z0, z1[, "noise"|"wave"|"swirl"]), ...]: hard patches of a texture
    above the threshold between two object heights (moss, filigree, snow).
    rays (rgb, count, z0, width): angular stripes round the object axis above z0 (a sun crest).
    marks [(rgb, centre, r_in, r_out[, below_z]), ...]: painted discs and rings round an object
    point, optionally only below a height (craters, clover leaves, a smile).
    emit: emission strength of the whole colour, so the bake comes out bright."""
    if name in _night._materials:
        return _night._materials[name]
    m = mat(name, stops[0][1], kind="flat", rough=rough)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if rest:
        node = nt.nodes.new("ShaderNodeAttribute")
        node.name, node.attribute_name = "rest", "rest"
        pos = node.outputs["Vector"]
    else:
        pos = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(pos, sep.inputs[0])
    span = nt.nodes.new("ShaderNodeMapRange")
    span.inputs["From Min"].default_value = lo
    span.inputs["From Max"].default_value = hi
    nt.links.new(sep.outputs[axis], span.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], lin(stops[0][1])
    elements[1].position, elements[1].color = stops[-1][0], lin(stops[-1][1])
    for at, rgb in stops[1:-1]:
        elements.new(at).color = lin(rgb)
    nt.links.new(span.outputs["Result"], ramp.inputs["Fac"])
    colour = ramp.outputs["Color"]

    def over(mask, rgb):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(mask, mix.inputs[0])
        nt.links.new(colour, mix.inputs[6])
        mix.inputs[7].default_value = lin(rgb)
        return mix.outputs[2]

    def op(operation, a, b=None):
        """Math node on sockets or numbers."""
        node = nt.nodes.new("ShaderNodeMath")
        node.operation = operation
        for i, x in enumerate((a,) if b is None else (a, b)):
            if isinstance(x, (int, float)):
                node.inputs[i].default_value = x
            else:
                nt.links.new(x, node.inputs[i])
        return node.outputs[0]

    def texture(kind, scale):
        tex = nt.nodes.new("ShaderNodeTexNoise" if kind == "noise" else "ShaderNodeTexWave")
        tex.inputs["Scale"].default_value = scale
        if kind == "noise":
            tex.inputs["Detail"].default_value = 6
        else:  # "wave": vertical grain; "swirl": diagonal, heavily distorted (filigree)
            tex.inputs["Distortion"].default_value = 4 if kind == "wave" else 9
            tex.inputs["Detail"].default_value = 3
            if kind == "swirl":
                tex.bands_direction = "DIAGONAL"
        nt.links.new(pos, tex.inputs["Vector"])
        return tex.outputs["Fac"]

    if grain:
        amount, scale, kind = (tuple(grain) + ("noise",))[:3]
        shade_ = nt.nodes.new("ShaderNodeMapRange")
        shade_.inputs["To Min"].default_value = 1 - amount
        shade_.inputs["To Max"].default_value = 1 + amount
        nt.links.new(texture(kind, scale), shade_.inputs["Value"])
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        nt.links.new(colour, mul.inputs[6])
        nt.links.new(shade_.outputs["Result"], mul.inputs[7])
        colour = mul.outputs[2]
    for rgb, scale, threshold, z0, z1, *kind in splat:
        hit = op("GREATER_THAN", texture(kind[0] if kind else "noise", scale), threshold)
        zone = op("MULTIPLY", op("GREATER_THAN", sep.outputs["Z"], z0), op("LESS_THAN", sep.outputs["Z"], z1))
        colour = over(op("MULTIPLY", hit, zone), rgb)
    if rays:
        rgb, count, z0, width = rays
        angle = op("ARCTAN2", sep.outputs["Y"], sep.outputs["X"])
        stripe = op("GREATER_THAN", op("SINE", op("MULTIPLY", angle, count)), 1 - width)
        colour = over(op("MULTIPLY", stripe, op("GREATER_THAN", sep.outputs["Z"], z0)), rgb)
    for rgb, centre, r_in, r_out, *below in marks:
        dist = nt.nodes.new("ShaderNodeVectorMath")
        dist.operation = "DISTANCE"
        dist.inputs[1].default_value = tuple(centre)
        nt.links.new(pos, dist.inputs[0])
        mask = op("MULTIPLY", op("LESS_THAN", dist.outputs["Value"], r_out), op("GREATER_THAN", dist.outputs["Value"], r_in))
        if below:
            mask = op("MULTIPLY", mask, op("LESS_THAN", sep.outputs["Z"], below[0]))
        colour = over(mask, rgb)
    for rgb, scale, size in dots:
        cells = nt.nodes.new("ShaderNodeTexVoronoi")
        cells.inputs["Scale"].default_value = scale
        nt.links.new(pos, cells.inputs["Vector"])
        colour = over(op("LESS_THAN", cells.outputs["Distance"], size), rgb)
    if bands:
        rgb, period = bands
        wave = nt.nodes.new("ShaderNodeMath")
        wave.operation = "MULTIPLY"
        wave.inputs[1].default_value = 2 * math.pi / period
        nt.links.new(sep.outputs[axis], wave.inputs[0])
        sine = nt.nodes.new("ShaderNodeMath")
        sine.operation = "SINE"
        nt.links.new(wave.outputs[0], sine.inputs[0])
        hit = nt.nodes.new("ShaderNodeMath")
        hit.operation = "GREATER_THAN"
        nt.links.new(sine.outputs[0], hit.inputs[0])
        colour = over(hit.outputs[0], rgb)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    if emit > 0:
        nt.links.new(colour, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def zone(m, rgb, centre, radii, soft=0.12, jag=0.0, jag_scale=7.0):
    """A soft-edged fur marking on a `paint(..., rest=True)` material: everything inside the
    ellipsoid at `centre` with half axes `radii` (studs, build-time coordinates) turns `rgb`.
    soft: edge blur as a fraction of the radius. jag: noise added to the edge (0.1 to 0.3) for a
    tufted fur line, like a fox's white tail tip. Layers in call order (the last one wins). Use for
    muzzles, cheeks, bibs, paws, ear and tail tips, soft blush: no extra triangles, the colour
    follows the fused surface exactly and fit cannot move it."""
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    colour = bsdf.inputs["Base Color"].links[0].from_socket

    def vec(op, a, b):
        node = nt.nodes.new("ShaderNodeVectorMath")
        node.operation = op
        nt.links.new(a, node.inputs[0])
        node.inputs[1].default_value = b
        return node.outputs["Vector"]

    rel = vec("DIVIDE", vec("SUBTRACT", nt.nodes["rest"].outputs["Vector"], tuple(centre)), tuple(radii))
    length = nt.nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    nt.links.new(rel, length.inputs[0])
    d = length.outputs["Value"]
    edge = nt.nodes.new("ShaderNodeMapRange")
    edge.interpolation_type = "SMOOTHSTEP"
    edge.inputs["From Min"].default_value, edge.inputs["From Max"].default_value = 1 - soft, 1 + soft
    edge.inputs["To Min"].default_value, edge.inputs["To Max"].default_value = 1, 0
    if jag:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = jag_scale
        noise.inputs["Detail"].default_value = 1
        nt.links.new(rel, noise.inputs["Vector"])
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "MULTIPLY_ADD"
        nt.links.new(noise.outputs["Fac"], add.inputs[0])
        add.inputs[1].default_value = 2 * jag
        nt.links.new(d, add.inputs[2])
        sub = nt.nodes.new("ShaderNodeMath")
        sub.inputs[1].default_value = jag  # noise is 0 to 1: centre it on 0
        sub.operation = "SUBTRACT"
        nt.links.new(add.outputs[0], sub.inputs[0])
        d = sub.outputs[0]
    nt.links.new(d, edge.inputs["Value"])
    mix_ = nt.nodes.new("ShaderNodeMix")
    mix_.data_type = "RGBA"
    nt.links.new(edge.outputs["Result"], mix_.inputs[0])
    nt.links.new(colour, mix_.inputs[6])
    mix_.inputs[7].default_value = lin(rgb)
    nt.links.new(mix_.outputs[2], bsdf.inputs["Base Color"])
    return m


def flat(rgb, name=None, emit=0.0):
    return mat(name or f"flat_{rgb[0]}_{rgb[1]}_{rgb[2]}_{emit}", rgb, kind="flat", emit=emit, rough=0.45)


def glow(rgb):
    return flat(rgb, emit=0.4)  # low: stays the hue in the bake; Neon does the glowing in game


# The egg: every shell decoration is placed in shell coordinates ------------------------------


def egg_at(theta, v, lift=0.0, H=3.0, R=1.1):
    """Point and outward normal on the egg. theta: degrees round from the front (0 = -Y, 90 = +X),
    v: 0 bottom to 1 top. lift: studs along the normal."""
    phi = math.pi * min(max(v, 0.0), 1.0)
    c, s = math.cos(phi), math.sin(phi)
    r = R * s * (1 + 0.2 * c) / 1.019
    dr = R * (c * (1 + 0.2 * c) - 0.2 * s * s) / 1.019
    dz = H / 2 * s
    size = math.hypot(dr, dz)
    t = math.radians(theta)
    out = Vector((math.sin(t), -math.cos(t), 0))
    normal = out * (dz / size) + Vector((0, 0, -dr / size))
    return out * r + Vector((0, 0, H / 2 * (1 - c))) + normal * lift, normal


def shell(m, nu=28, nv=14, v0=0.0, v1=1.0, warp=None, name="shell", **egg):
    """Egg surface between v0 and v1 (numbers, or functions of theta for a jagged edge).
    warp(theta, v) lifts the surface in studs."""
    low = v0 if callable(v0) else (lambda t: v0)
    high = v1 if callable(v1) else (lambda t: v1)

    def fn(u, v):
        t = 360 * u
        w = low(t) + (high(t) - low(t)) * v
        return tuple(egg_at(t, w, warp(t, w) if warp else 0.0, **egg)[0])

    return surface(nu, nv, fn, m=m, name=name)


def stick(objs, theta, v, lift=0.0, spin=0.0, s=1.0, **egg):
    """Moves objects built at the origin (local +Z out) onto the shell."""
    p, n = egg_at(theta, v, lift, **egg)
    matrix = (
        Matrix.Translation(p)
        @ Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
        @ rot_z(spin)
        @ Matrix.Scale(s, 4)
    )
    for ob in objs if isinstance(objs, (list, tuple)) else [objs]:
        ob.data.transform(matrix)
    return objs


def ridge(path, width, height, m, name="ridge", **egg):
    """Raised relief on the shell along [(theta, v), ...]. width: studs, or one per point. Closed
    so the normals recalculate reliably."""
    widths = width if isinstance(width, (list, tuple)) else [width] * len(path)
    pts = [egg_at(t, v, **egg) for t, v in path]
    bm = bmesh.new()
    rows = []
    for i, (p, n) in enumerate(pts):
        along = pts[min(i + 1, len(pts) - 1)][0] - pts[max(i - 1, 0)][0]
        side = along.cross(n).normalized() * max(widths[i], 0.004)
        rows.append([bm.verts.new(p + side - n * 0.03), bm.verts.new(p + n * height), bm.verts.new(p - side - n * 0.03)])
    for a, b in zip(rows, rows[1:]):
        for k in range(3):
            j = (k + 1) % 3
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(rows[0])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m)


# Toy parts, built at the origin facing local +Z ---------------------------------------------


def _fans(rim, top, bottom, m, name):
    bm = bmesh.new()
    ring = [bm.verts.new(p) for p in rim]
    a, b = bm.verts.new(top), bm.verts.new(bottom)
    for i, v in enumerate(ring):
        w = ring[(i + 1) % len(ring)]
        bm.faces.new((v, w, a))
        bm.faces.new((w, v, b))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m)


def star(r, m, points=5, inner=0.45, depth=None, name="star"):
    """Faceted gem star (20 tris for 5 points)."""
    depth = r * 0.42 if depth is None else depth
    rim = []
    for i in range(points * 2):
        a = math.pi * i / points + math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        rim.append((rr * math.cos(a), rr * math.sin(a), 0))
    return _fans(rim, (0, 0, depth), (0, 0, -depth * 0.5), m, name)


def flower(r, petal, heart, lobes=6, name="flower"):
    """One-piece lobed flower with a domed heart."""
    n = lobes * 4
    rim = []
    for i in range(n):
        a = 2 * math.pi * i / n
        f = 0.5 + 0.5 * abs(math.cos(lobes * a / 2)) ** 0.6
        rim.append((r * f * math.cos(a), r * f * math.sin(a), r * 0.22 * f))
    body = _fans(rim, (0, 0, r * 0.03), (0, 0, -r * 0.2), petal, name)
    dome = lathe([(r * 0.36, r * 0.03), (r * 0.3, r * 0.2), (0, r * 0.3)], m=heart, n=8, name=f"{name}_heart")
    return [body, dome]


def leaf(length, width, m, droop=0.25, n=6, steps=6, name="leaf"):
    """Curved blade along +X, flattened to a thin lens."""
    pts, radii = [], []
    for i in range(steps + 1):
        s = i / steps
        pts.append((length * s, 0, length * droop * math.sin(s * math.pi * 0.8)))
        radii.append(width * math.sin(s * math.pi) ** 0.7)
    ob = tube(pts, radii, m=m, n=n, name=name)
    ob.data.transform(Matrix.Diagonal((1, 1, 0.3, 1)))
    return ob


def blade(root, out, height, r, m, name="blade"):
    """Grass blade: 3-sided taper from root, curving along the unit vector `out`."""
    root = Vector(root)
    up = Vector((0, 0, 1))
    pts = [root, root + up * height * 0.55 + out * height * 0.14, root + up * height + out * height * 0.5]
    return tube(pts, [r, r * 0.62, 0], m=m, n=3, name=name)


def puff(r, loc, m, scale=(1, 1, 0.8), name="puff"):
    """Round cloud or bush lump (80 tris; fine enough to smooth-shade)."""
    return ico(r, loc, m=m, scale=scale, subdiv=2, name=name)


def mushroom(r, h, cap, stem, name="mushroom"):
    """Stubby toy mushroom standing on local z = 0."""
    return [
        lathe([(r * 0.42, 0), (r * 0.34, h * 0.5), (r * 0.42, h * 0.8)], m=stem, n=8, name=f"{name}_stem"),
        lathe(
            [(r * 0.5, h * 0.72), (r * 0.98, h * 0.72), (r, h * 0.86), (r * 0.78, h * 1.12), (r * 0.36, h * 1.32), (0, h * 1.38)],
            m=cap,
            n=12,
            name=f"{name}_cap",
        ),
    ]


def sharpen(ob):
    """Marks every edge sharp so a low-poly gem keeps its facets through finalize."""
    for edge in ob.data.edges:
        edge.use_edge_sharp = True
    return ob


def facet(ob, mats, skip=()):
    """Gem look: a fixed pre-lit shade per face (mats run bright to dark), so the cut reads under
    any Roblox lighting. Call once the object is in its final place. `skip`: face indices left
    on the last material."""
    light = Vector((-0.45, -0.75, 0.5)).normalized()
    ob.data.materials.clear()
    for m in mats:
        ob.data.materials.append(m)
    last = len(mats) - 1
    if skip:
        last -= 1
    for poly in ob.data.polygons:
        lit = (poly.normal.dot(light) + 1) / 2
        poly.material_index = last + 1 if poly.index in skip else min(last, int((1 - lit) * (last + 1)))
    return sharpen(ob)


# Creature standard (HD pass, README "Creature standard") --------------------------------------
# Every creature: one fused body (fuse), the standard face (face), separate smooth props (blob,
# capsule, lens, leaf with n >= 8), budget CREATURE_BUDGET, finalize settings HD.

CREATURE_BUDGET = 6000
FACE_TEXEL = 2.0
EYE_INK = (40, 30, 52)
NOSE = (120, 70, 90)
BLUSH_PINK = (255, 120, 160)


def texel(objs, w, centre=None, radius=None):
    """Texel density weight for the HD unwrap (2 = twice the texels per stud, 0.5 = half), on
    every face of objs or only those within `radius` of `centre`. face() marks the face at
    FACE_TEXEL; mark big plain parts (wings, petals, shells) about 0.5."""
    for ob in objs if isinstance(objs, (list, tuple)) else [objs]:
        attr = ob.data.attributes.get("texel") or ob.data.attributes.new("texel", "FLOAT", "FACE")
        for poly in ob.data.polygons:
            if centre is None or (poly.center - Vector(centre)).length < radius:
                attr.data[poly.index].value = w
    return objs


def weigh_islands(objs):
    """finalize uv_hook: scales each UV island by the largest `texel` weight of its faces
    (unmarked = 1) before packing, which keeps relative island sizes."""
    for ob in objs:
        if "texel" not in ob.data.attributes:
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        uv = bm.loops.layers.uv.active
        weight = bm.faces.layers.float.get("texel")
        bm.faces.ensure_lookup_table()
        root = list(range(len(bm.faces)))

        def find(i):
            while root[i] != i:
                root[i] = root[root[i]]
                i = root[i]
            return i

        for e in bm.edges:  # faces share an island where their UVs agree along a shared edge
            if len(e.link_faces) != 2:
                continue
            f, g = e.link_faces
            a = {l.vert: l[uv].uv for l in f.loops if l.vert in e.verts}
            b = {l.vert: l[uv].uv for l in g.loops if l.vert in e.verts}
            if all((a[v] - b[v]).length < 1e-6 for v in a):
                root[find(f.index)] = find(g.index)
        islands = {}
        for f in bm.faces:
            islands.setdefault(find(f.index), []).append(f)
        for faces in islands.values():
            s = max(f[weight] or 1.0 for f in faces)
            if s != 1.0:
                loops = [l for f in faces for l in f.loops]
                c = sum((l[uv].uv for l in loops), Vector((0, 0))) / len(loops)
                for l in loops:
                    l[uv].uv = c + (l[uv].uv - c) * s
        bm.to_mesh(ob.data)
        bm.free()


# 192-sample AO blurred 0.8 texels (reach 3, half the 6 px island gap, so it never mixes
# islands), deeper (35% floor) for the toy look, a baked top light, a 10 px bake margin, and
# texel weights (the face at FACE_TEXEL).
HD = dict(ao_samples=192, ao_blur=0.8, ao_floor=0.35, toplight=0.14, margin=10, uv_margin=0.006, uv_hook=weigh_islands)


def outward(theta, phi):
    """Unit vector theta degrees round from the front (-Y, positive towards +X), phi degrees up."""
    t, p = math.radians(theta), math.radians(phi)
    return Vector((math.sin(t) * math.cos(p), -math.cos(t) * math.cos(p), math.sin(p)))


def pair(loc, r, scale=(1, 1, 1), rot=(0, 0, 0)):
    """A fuse element and its mirror through x = 0 (ears, arms, feet)."""
    x, y, z = loc
    return [(loc, r, scale, rot), ((-x, y, z), r, scale, (rot[0], -rot[1], -rot[2]))]


def fuse(elements, m, tris=3200, soft=0.3, res=0.04, name="body"):
    """One smooth organic mesh from overlapping shapes (metaballs): head, body, snout, paws, ears
    and tail melt together with soft creases instead of hard intersections, and hidden insides cost
    no triangles or texture. Then decimated to about `tris`.

    elements: (loc, r[, scale[, rot]]) ellipsoids, r the visible radius in studs before blending,
    scale per axis, rot degrees XYZ; or ("capsule", a, b, r), a rounded segment.
    soft: blend reach as a fraction of each radius, 0.15 (tight creases) to 0.5 (dough). Shapes
    swell a little where they overlap."""
    assert 0.15 <= soft <= 0.6, "soft outside 0.15 to 0.6: metaball stiffness would clamp"
    x = 1 / (1 + soft)
    stiff = 0.1 / (1 - x * x) ** 3  # Blender's falloff: stiffness * (1 - d^2 / R^2)^3 = threshold
    mb = bpy.data.metaballs.new(name)
    mb.threshold = 0.1
    mb.resolution = mb.render_resolution = res
    for e in elements:
        if e[0] == "capsule":
            _, a, b, r = e
            a, b = Vector(a), Vector(b)
            el = mb.elements.new(type="CAPSULE")
            el.co = (a + b) / 2
            el.rotation = Vector((1, 0, 0)).rotation_difference(b - a)
            el.size_x = (b - a).length / 2
        else:
            loc, r, scale, rot = tuple(e) + ((1, 1, 1), (0, 0, 0))[len(e) - 2 :]
            el = mb.elements.new(type="ELLIPSOID")
            el.co = loc
            el.size_x, el.size_y, el.size_z = scale
            el.rotation = Euler([math.radians(a) for a in rot], "XYZ").to_quaternion()
        el.radius = r / x
        el.stiffness = stiff
    mb.materials.append(m)
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    _select([ob])
    bpy.context.view_layer.update()
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    bpy.data.metaballs.remove(mb)
    have = _tris(ob)
    if have > tris:
        mod = ob.modifiers.new("decimate", "DECIMATE")
        mod.ratio = tris / have
        _select([ob])
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print(f"[fuse] {name}: {have} -> {_tris(ob)} tris", flush=True)
    co = [0.0] * (3 * len(ob.data.vertices))
    ob.data.vertices.foreach_get("co", co)
    ob.data.attributes.new("rest", "FLOAT_VECTOR", "POINT").data.foreach_set("vector", co)  # for paint(rest=True)
    return ob


def land(target, centre, d):
    """(point, normal) where a ray from far outside along `d` towards `centre` meets `target`:
    snaps features onto the real (fused) surface, so nothing floats or sinks."""
    d = Vector(d).normalized()
    bpy.context.view_layer.update()
    hit, p, n, _ = target.ray_cast(Vector(centre) + d * 50, -d, depsgraph=bpy.context.evaluated_depsgraph_get())
    if not hit:
        raise ValueError(f"land: nothing of {target.name} along {tuple(d)} from {tuple(centre)}")
    return p, n


def _frame(n, up=(0, 0, 1)):
    """Surface axes: x across (the viewer's right on a front face), y towards `up`, z out."""
    z = Vector(n).normalized()
    up = Vector(up)
    y = up - z * z.dot(up)
    if y.length < 1e-4:
        y = Vector((0, 1, 0)) - z * z.y
    y.normalize()
    return y.cross(z), y, z


def lens(target, centre, d, r, m, scale=(1, 1), thick=0.35, sink=0.35, up=(0, 0, 1), seg=16, name="lens"):
    """A flattened sphere set into `target` where `land` finds it: eyes, catchlights, blush, noses,
    inner ears, belly patches, spots. r: radius in studs, scale stretches it along the surface (x
    across, y towards `up`), thick: thickness as a fraction of r, sink: share of that thickness
    buried, so the rim never floats on a curved surface. Only the outer half is built: the buried
    half would cost triangles and texture for nothing."""
    p, n = land(target, centre, d)
    x, y, z = _frame(n, up)
    ob = sphere(r, m=m, scale=(scale[0], scale[1], thick), seg=seg, rings=2 * max(2, seg // 4), name=name)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < 0], context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.transform(Matrix.Translation(p - z * r * thick * sink) @ Matrix((x, y, z)).transposed().to_4x4())
    return ob


def eye(target, centre, d, r, iris=EYE_INK, name="eye", wide=0.8, sheen=False):
    """The standard eye: a glossy dark dome, `wide` (0.8) as wide as tall (r is half its height),
    standing 0.25 r proud so it catches the light; no white of the eye (a white ring reads googly).
    A big catchlight at the viewer's upper left and a small one at the lower right, the same on
    both eyes: one light for the whole family. sheen: a soft lighter crescent low in the eye, the
    reflected-sky glint that makes the reference plush eyes read glassy rather than flat black."""
    dome = lens(target, centre, d, r, flat(iris), scale=(wide, 1), thick=0.5, sink=0.5, seg=24, name=name)
    p, n = land(target, centre, d)
    x, y, _ = _frame(n)
    parts = [dome]
    if sheen:
        parts.append(lens(dome, p - y * r * 0.58, n, r * 0.34, flat(mix(iris, (150, 160, 200), 0.3)), scale=(wide * 1.5, 0.6), thick=0.25, sink=0.45, seg=16, name="sheen"))
    for u, v, s in ((-0.3, 0.36, 0.36), (0.3, -0.38, 0.16)):
        spot = p + (x * u * 0.8 + y * v) * r
        parts.append(lens(dome, spot, n, r * s, flat(SNOW), thick=0.3, sink=0.4, seg=12, name="catchlight"))
    return parts


def mouth(target, centre, d, width, m, kind="w", r=None, up=(0, 0, 1)):
    """Small mouth along the surface: "w" (the cat mouth, default), "smile" (a U) or "o" (a dot,
    surprised). width: half width in studs; r: line radius, default width / 7."""
    p, n = land(target, centre, d)
    r = r or width / 7
    if kind == "o":
        return lens(target, centre, d, r * 1.6, m, scale=(1, 1.15), thick=0.4, sink=0.5, seg=12, name="mouth")
    x, y, _ = _frame(n, up)
    pts, radii = [], []
    for i in range(13):
        u = i / 6 - 1
        v = -0.4 * abs(math.sin(math.pi * u)) if kind == "w" else 0.35 * (u * u - 1)
        q, qn = land(target, p + (x * u + y * v) * width, n)
        pts.append(q + qn * r * 0.2)
        radii.append(r * (0.6 + 0.4 * math.sin(math.pi * i / 12)))
    return tube(pts, radii, m=m, n=6, name="mouth")


def face(target, centre, R, skin, iris=EYE_INK, nose=NOSE, mouth_kind="w", eye_r=0.24, spread=34, eye_phi=-6,
         nose_phi=-17, mouth_phi=-26, blush=True, nose_r=0.075, eye_wide=0.8, sheen=False, blush_theta=54,
         blush_phi=-25, blush_r=0.17, mouth_w=0.17):
    """The standard face on a head of radius R centred at `centre` (front -Y), as fractions of R:
    eyes 0.24 R (half height), 34 degrees each side of the front and 6 below the head's middle, so
    wide apart and low (a big forehead is the baby look); nose 0.075 R at 17 below; mouth 0.17 R
    wide at 26 below; blush ovals 0.17 R at 54 degrees round, 25 below, the skin mixed 55% to pink.
    nose=None or mouth_kind=None leave them out (put them on a snout yourself). Marks the face
    (within R of its middle) and its parts at FACE_TEXEL.
    On a body painted with paint(..., rest=True) the blush is a soft painted `zone` (the plush
    look of the reference creatures) instead of a hard-edged lens; `skin` is then the colour
    under the blush. The reference-remake values are in README "Reference remakes"."""
    texel(target, FACE_TEXEL, land(target, centre, outward(0, -12))[0], R)
    painted = target.data.materials[0] if "rest" in target.data.materials[0].node_tree.nodes else None
    parts = []
    for side in (-1, 1):
        parts += eye(target, centre, outward(side * spread, eye_phi), R * eye_r, iris, wide=eye_wide, sheen=sheen)
        if blush and painted:
            p, _ = land(target, centre, outward(side * blush_theta, blush_phi))
            r = R * blush_r
            zone(painted, mix(skin, BLUSH_PINK, 0.55), p, (r * 1.5, r * 1.5, r * 0.95), soft=0.45)
        elif blush:
            parts.append(lens(target, centre, outward(side * blush_theta, blush_phi), R * blush_r, flat(mix(skin, BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
    if nose:
        parts.append(lens(target, centre, outward(0, nose_phi), R * nose_r, flat(nose), scale=(1.35, 0.9), thick=0.55, sink=0.4, seg=12, name="nose"))
    if mouth_kind:
        parts.append(mouth(target, centre, outward(0, mouth_phi), R * mouth_w, flat(INKY), mouth_kind))
    return texel(parts, FACE_TEXEL)


def blob(r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), name="blob"):
    """A separate smooth round piece (tail puff, pom-pom, bud): 24 x 12, round in silhouette."""
    return sphere(r, loc, rot=rot, m=m, scale=scale, seg=24, rings=12, name=name)


def capsule(a, b, ra, rb, m, n=16, name="capsule"):
    """Rounded limb, horn or stem from a to b: round ends of radius ra and rb (small rb: a soft
    point) on a straight taper. Use for every separate limb or horn, never an 8-sided prism."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    angles = [math.radians(90 - 22.5 * i) for i in range(5)]
    profile = [(ra * math.cos(t), -ra * math.sin(t)) for t in angles]
    profile += [(rb * math.cos(t), length + rb * math.sin(t)) for t in reversed(angles)]
    ob = lathe(profile, m=m, n=n, name=name)
    ob.data.transform(Matrix.Translation(a) @ Vector((0, 0, 1)).rotation_difference(b - a).to_matrix().to_4x4())
    return ob


# Preview: a bright toy shelf instead of the Night slate ---------------------------------------


def _studio(scene, ground_rgb=(214, 240, 226)):
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = scene.world or bpy.data.worlds.new("garden")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = lin((190, 226, 250))
    bg.inputs["Strength"].default_value = 0.8

    def sun(name, energy, rot):
        light = bpy.data.lights.new(name, "SUN")
        light.color = lin((255, 246, 232))[:3]
        light.energy = energy
        light.angle = math.radians(24)
        ob = bpy.data.objects.new(name, light)
        ob.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(ob)

    sun("key", 2.3, (55, 0, -35))
    sun("fill", 0.5, (65, 0, 70))
    return mat("pv_ground", ground_rgb, kind="flat")


def _glow_material(baked):
    """Stands in for Roblox Neon on `_glow` parts in the previews."""
    neon = baked.copy()
    nt = neon.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    nt.links.remove(bsdf.inputs["Base Color"].links[0])
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    return neon


def preview(name, parts, lo, hi):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    try:
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.film_transparent = False
    ground_mat = _studio(scene)

    for p in parts:
        if p.name.endswith("_glow"):
            p.data.materials[0] = _glow_material(p.data.materials[0])

    centre = (lo + hi) / 2
    size = max((hi - lo).length, 1)
    cyl(size * 2, 0.02, (centre.x, centre.y, -0.011), m=ground_mat, n=48)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    # Front is -Y: look at it from the front, a little to the left, a little above.
    direction = Vector((-0.42, -1.0, 0.42)).normalized()
    cam.location = centre + direction * size * 3
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for x in (lo.x, hi.x):
        for y in (lo.y, hi.y):
            for z in (lo.z, hi.z):
                p = inv @ Vector((x, y, z))
                xs.append(p.x)
                ys.append(p.y)
    extent = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.14
    cam_data.ortho_scale = extent
    cam_data.clip_end = size * 10
    cam.location = cam.matrix_world @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
    scene.camera = cam

    text_data = bpy.data.curves.new("label", "FONT")
    text_data.body = name
    text_data.size = extent * 0.05
    label = bpy.data.objects.new("label", text_data)
    label.data.materials.append(mat("pv_label", (70, 60, 90), kind="flat", emit=1.0))
    scene.collection.objects.link(label)
    label.parent = cam
    label.location = (-extent / 2 + extent * 0.03, -extent / 2 + extent * 0.03, -size * 0.5)

    scene.render.filepath = os.path.join(PREVIEWS, f"{name}.png")
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


_night.preview = preview
