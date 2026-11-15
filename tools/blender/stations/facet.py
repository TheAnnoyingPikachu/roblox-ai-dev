"""The faceted low-poly helpers shared by the lions, the elephants, the jackals and the cheetahs (decisions
0050 to 0053). A piece is a closed solid of flat faces; every face has one colour (the `lp` colour attribute),
picked from three tones (shadow, base, light) by which way the face points plus a little chance, so the
facets read in any light and bake straight into the texture. kit.py drops the attribute after the bake:
left on the mesh it would be exported as vertex colours, which Roblox multiplies the texture by.
"""

import bmesh
import bpy
import kit as k
from mathutils import Vector

ATTR = "lp"  # the per-face colour
LIGHT = Vector((-0.35, -0.45, 0.82)).normalized()  # where the painted light comes from
INK = (16, 13, 18)
BONE = (224, 212, 184)

WARM = ((0.86, 0.70, 0.62), (1.05, 1.13, 1.25), (8, 10, 16))  # shadows turn red, lights turn yellow
COOL = ((0.5, 0.5, 0.56), (1.55, 1.6, 1.7), (10, 12, 18))
PALE = ((0.88, 0.84, 0.78), (1.03, 1.04, 1.06), (4, 5, 8))
FIRE = ((0.95, 0.66, 0.42), (1.0, 1.05, 1.25), (0, 6, 16))  # the shadows of a flame are deep orange


def tone(rgb, kind=WARM):
    """(shadow, base, light) from one colour."""
    lo, hi, add = kind
    return (
        tuple(c * f for c, f in zip(rgb, lo)),
        tuple(rgb),
        tuple(min(255, c * f + a) for c, f, a in zip(rgb, hi, add)),
    )


def material(emit=0.0):
    """The one material of every faceted piece: it shows the face colours, optionally lit from within."""
    name = f"lp_facets_{emit}"
    known = name in k._materials
    m = k.mat(name, (255, 255, 255), kind="flat", rough=0.6)
    if not known:
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        colour = nt.nodes.new("ShaderNodeAttribute")
        colour.attribute_name = ATTR
        nt.links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])
        if emit:
            nt.links.new(colour.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emit
    return m


def colour(ob, tones, rng, chance=0.2, bias=None):
    """One colour for each face of `ob`. tones: a (shadow, base, light) triple, or one per face.
    bias(centre): added to a face's light from where it is (the elephants darken towards the ground)."""
    me = ob.data
    attr = me.color_attributes.get(ATTR) or me.color_attributes.new(ATTR, "FLOAT_COLOR", "CORNER")
    each = not isinstance(tones[0][0], (int, float))
    for poly in me.polygons:
        shadow, base, light = tones[poly.index] if each else tones
        t = max(-1.0, min(1.0, poly.normal.dot(LIGHT) * 0.8 + rng.uniform(-chance, chance) + (bias(poly.center) if bias else 0)))
        rgb = k.mix(base, light, t) if t > 0 else k.mix(base, shadow, -t)
        c = k.lin(rgb)
        for i in poly.loop_indices:
            attr.data[i].color = c
    return ob


def rough(ob, tones, rng, bulge=0.04, fade=3.0):
    """A hide of facets: every face is broken into triangles round a slightly raised middle and painted
    again, each triangle its own tone, darker towards the ground (below the height `fade`). Big flat
    faces looked plain."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    middles = bmesh.ops.poke(bm, faces=bm.faces[:])["verts"]
    bm.normal_update()
    for v in middles:
        v.co += v.normal * bulge * rng.uniform(0.4, 1.0)
    bm.to_mesh(ob.data)
    bm.free()
    return colour(ob, tones, rng, 0.26, bias=lambda c: -0.4 * max(0.0, 1 - c.z / fade))


def mesh(name, verts, faces, tones, rng, emit=0.0, m=None, chance=0.2):
    """A closed faceted piece. With `m` (a glow material) it is left unpainted."""
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(m or material(emit))
    return ob if m else colour(ob, tones, rng, chance)


def loft(name, rings, tones, rng, **kw):
    """A solid through `rings` (lists of points, equal length), capped at both ends."""
    n = len(rings[0])
    faces = []
    for r in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i))
    faces.append(tuple(range(n))[::-1])
    faces.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    return mesh(name, [p for ring in rings for p in ring], faces, tones, rng, **kw)


def yring(y, zc, w, up, down, c, x=0.0):
    """An upright rectangle with cut corners at depth y (a section of a body, a head, a paw). A big
    cut `c` makes an even octagon: chunky, with no thin bevel faces."""
    top, bot = zc + up, zc - down
    return [(x + w - c, y, top), (x + w, y, top - c), (x + w, y, bot + c), (x + w - c, y, bot), (x + c - w, y, bot), (x - w, y, bot + c), (x - w, y, top - c), (x + c - w, y, top)]


def zring(x, y, z, wx, wy, c):
    """A level rectangle with cut corners at height z (a section of a leg)."""
    return [(x + wx - c, y - wy, z), (x + wx, y - wy + c, z), (x + wx, y + wy - c, z), (x + wx - c, y + wy, z), (x - wx + c, y + wy, z), (x - wx, y + wy - c, z), (x - wx, y - wy + c, z), (x - wx + c, y - wy, z)]


def quad(y, zc, w, up, down, x=0.0):
    """A plain upright rectangle at depth y (a toe)."""
    return [(x + w, y, zc + up), (x + w, y, zc - down), (x - w, y, zc - down), (x - w, y, zc + up)]


def shard(base, tip, width, thick, tones, rng, face=(0, -1, 0), at=0.5, m=None, emit=0.0, name="shard"):
    """A crystal shard: a stretched eight-faced gem from base to tip, `width` across and `thick` through
    at its widest (`at` of the way along), its broad faces turned towards `face`. tones: one triple, or
    (root, tip) for a shard that lightens towards its point."""
    b, t = Vector(base), Vector(tip)
    axis = t - b
    side = axis.cross(Vector(face))
    if side.length < 1e-4:
        side = axis.cross(Vector((1, 0, 0)))
    side.normalize()
    out = side.cross(axis).normalized()
    mid = b + axis * at
    verts = [b, mid + side * width / 2, mid + out * thick / 2, mid - side * width / 2, mid - out * thick / 2, t]
    faces = [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1), (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)]
    if not m and not isinstance(tones[0][0], (int, float)):
        tones = [tones[0]] * 4 + [tones[1]] * 4
    return mesh(name, verts, faces, tones, rng, emit=emit, m=m, chance=0.3)


def plate(name, p, frame, outline, thick, tones, rng, lift=0.004, m=None):
    """A flat piece on a surface: `outline` [(across, up), ...] round the point p, raised by `thick`."""
    x, y, z = frame
    n = len(outline)
    lo = [p + x * u + y * v + z * lift for u, v in outline]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh(name, lo + [q + z * thick for q in lo], faces, tones, rng, m=m)


def small_paw(x, y, tones, rng):
    """A small block of a paw with three stubby toes (the jackals' and the cheetahs')."""
    parts = [loft("paw", [yring(y + 0.16, 0.14, 0.15, 0.13, 0.14, 0.05, x), yring(y - 0.2, 0.15, 0.18, 0.14, 0.15, 0.06, x)], tones, rng)]
    for dx in (-0.12, 0.0, 0.12):
        parts.append(loft("toe", [quad(y - 0.17, 0.11, 0.055, 0.1, 0.11, x + dx), quad(y - 0.36, 0.08, 0.05, 0.05, 0.08, x + dx)], tones, rng))
    return parts


def asset(name, maker, scale, glow, note):
    joints = {}

    def build():
        groups, j = maker()
        joints.update(j)
        return groups

    # the budget is only a ceiling for the build's check: these models are a thousand or two triangles
    return dict(name=name, build=build, scale=scale, budget=20000, finalize=k.HD, joints=joints, glow=glow, notes=note)
