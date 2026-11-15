"""The lions (decision 0050): the Lion, the Sun Lion and the Shadow Lion as faceted low-poly cats, after
SHANNON's Sun Lion reference card. Blocky lofted bodies, big paws with three toes, an angular face
with slit eyes, and a mane of layered crystal shards. Nothing is smooth: every face has one colour
(the `lp` colour attribute), picked from three tones by which way the face points plus a little
chance, so the facets read in any light and bake straight into the texture.

Jointed like every creature: body, head (with the mane), four legs, tail, and Neon `_glow` pieces.
Facing Blender -Y; left is +X.
"""

import math
import random

import bmesh
import bpy
import kit as k
from mathutils import Matrix, Vector

ATTR = "lp"  # the per-face colour
HEAD = 1.2  # the face is built small and grown by this: a big head, as on the reference
LIGHT = Vector((-0.35, -0.45, 0.82)).normalized()  # where the painted light comes from
INK = (16, 13, 18)
BONE = (224, 212, 184)
SUNFIRE = (255, 222, 90)
SHADOW = (110, 255, 90)  # a sickly green glow

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


def colour(ob, tones, rng, chance=0.2):
    """One colour for each face of `ob`. tones: a (shadow, base, light) triple, or one per face."""
    me = ob.data
    attr = me.color_attributes.get(ATTR) or me.color_attributes.new(ATTR, "FLOAT_COLOR", "CORNER")
    each = not isinstance(tones[0][0], (int, float))
    for poly in me.polygons:
        shadow, base, light = tones[poly.index] if each else tones
        t = max(-1.0, min(1.0, poly.normal.dot(LIGHT) * 0.8 + rng.uniform(-chance, chance)))
        rgb = k.mix(base, light, t) if t > 0 else k.mix(base, shadow, -t)
        c = k.lin(rgb)
        for i in poly.loop_indices:
            attr.data[i].color = c
    return ob


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
    """An upright rectangle with cut corners at depth y (a section of a body, a head, a paw)."""
    top, bot = zc + up, zc - down
    return [(x + w - c, y, top), (x + w, y, top - c), (x + w, y, bot + c), (x + w - c, y, bot), (x + c - w, y, bot), (x - w, y, bot + c), (x - w, y, top - c), (x + c - w, y, top)]


def zring(x, y, z, wx, wy, c):
    """A level rectangle with cut corners at height z (a section of a leg)."""
    return [(x + wx - c, y - wy, z), (x + wx, y - wy + c, z), (x + wx, y + wy - c, z), (x + wx - c, y + wy, z), (x - wx + c, y + wy, z), (x - wx, y + wy - c, z), (x - wx, y - wy + c, z), (x - wx + c, y - wy, z)]


def shard(base, tip, width, thick, tones, rng, face=(0, -1, 0), at=0.36, m=None, emit=0.0, name="shard"):
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


def paw(x, y, tones, rng, claw=None):
    """A broad block of a paw with three toes, from the heel at y + 0.42 to the toes at y - 0.9."""
    parts = [loft("paw", [yring(y + 0.42, 0.24, 0.4, 0.2, 0.24, 0.1, x), yring(y + 0.1, 0.3, 0.5, 0.28, 0.3, 0.12, x), yring(y - 0.42, 0.26, 0.52, 0.22, 0.26, 0.1, x)], tones, rng)]
    for dx in (-0.35, 0.0, 0.35):
        parts.append(loft("toe", [yring(y - 0.38, 0.2, 0.155, 0.2, 0.2, 0.05, x + dx), yring(y - 0.72, 0.17, 0.15, 0.15, 0.17, 0.05, x + dx), yring(y - 0.9, 0.11, 0.11, 0.07, 0.11, 0.04, x + dx)], tones, rng))
        if claw:
            parts.append(shard((x + dx, y - 0.84, 0.15), (x + dx, y - 1.12, 0.02), 0.11, 0.09, claw, rng, face=(0, 0, 1), name="claw"))
    return parts


def lion_model(p, seed):
    """The faceted lion from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    T = lambda key: tone(p[key], p.get("kind", WARM))  # noqa: E731
    body, fore, cream = T("body"), T("fore"), tone(p["paw"], p.get("paw_kind", PALE))
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "head_glow": [], "body_glow": [], "tail": [], "tail_glow": []}

    # the torso: a deep chest, a tucked waist, square hips
    torso = loft("torso", [yring(*r) for r in ((-1.0, 2.35, 0.55, 0.6, 0.65, 0.22), (-0.45, 2.3, 0.92, 0.95, 0.95, 0.28), (0.5, 2.3, 0.9, 0.9, 0.9, 0.28), (1.35, 2.38, 0.74, 0.78, 0.68, 0.24), (2.2, 2.35, 0.88, 0.85, 0.8, 0.28), (2.85, 2.35, 0.7, 0.7, 0.6, 0.24), (3.15, 2.4, 0.4, 0.4, 0.35, 0.15))], body, rng)
    groups["body"].append(torso)

    # legs: the upper leg in the body's colour, the lower lighter, a pale paw
    thighs = {}
    for s in (1, -1):
        x = s * 0.6
        front = [
            loft("arm", [zring(x, 0.0, 2.5, 0.42, 0.55, 0.14), zring(x, 0.02, 1.9, 0.44, 0.56, 0.14), zring(x, 0.08, 1.25, 0.38, 0.46, 0.12)], body, rng),
            loft("forearm", [zring(x, 0.08, 1.3, 0.35, 0.42, 0.11), zring(x, 0.02, 0.8, 0.32, 0.38, 0.1), zring(x, 0.0, 0.42, 0.34, 0.4, 0.1)], fore, rng),
            *paw(x, 0.0, cream, rng, p.get("claw") and tone(p["claw"], PALE)),
        ]
        thigh = loft("thigh", [zring(x, 2.22, 2.75, 0.4, 0.74, 0.16), zring(x, 2.1, 2.1, 0.48, 0.86, 0.18), zring(x, 1.95, 1.45, 0.42, 0.6, 0.14)], body, rng)
        back = [
            thigh,
            loft("shin", [zring(x, 1.95, 1.5, 0.36, 0.5, 0.12), zring(x, 2.32, 0.95, 0.31, 0.4, 0.1)], body, rng),
            loft("hock", [zring(x, 2.32, 1.0, 0.3, 0.36, 0.1), zring(x, 2.24, 0.42, 0.32, 0.38, 0.1)], fore, rng),
            *paw(x, 2.15, cream, rng, p.get("claw") and tone(p["claw"], PALE)),
        ]
        thighs[s] = thigh
        groups["leg_f" + ("l" if s > 0 else "r")] = front
        groups["leg_b" + ("l" if s > 0 else "r")] = back

    # the head: a boxy muzzle stepping up to a broad brow
    hc = Vector((0, -1.5, 3.2))
    skull = loft("skull", [yring(*r) for r in ((-2.45, 2.98, 0.3, 0.22, 0.22, 0.09), (-2.28, 2.98, 0.4, 0.32, 0.3, 0.11), (-2.0, 3.0, 0.46, 0.42, 0.36, 0.13), (-1.65, 3.15, 0.76, 0.64, 0.52, 0.22), (-1.25, 3.2, 0.78, 0.68, 0.55, 0.24), (-0.8, 3.15, 0.64, 0.6, 0.5, 0.22))], body, rng)
    head = groups["head"]
    head.append(skull)
    muzzle = tone(p["muzzle"], p.get("paw_kind", PALE))
    head.append(loft("lips", [yring(-2.48, 2.88, 0.315, 0.1, 0.13, 0.07), yring(-2.28, 2.86, 0.415, 0.12, 0.15, 0.09), yring(-2.08, 2.84, 0.455, 0.1, 0.13, 0.09)], muzzle, rng))
    head.append(loft("mouth", [yring(-2.44, 2.72, 0.27, 0.025, 0.025, 0.02), yring(-2.0, 2.7, 0.42, 0.025, 0.025, 0.02)], tone(p["nose"]), rng))
    head.append(loft("chin", [yring(-2.4, 2.62, 0.24, 0.085, 0.07, 0.05), yring(-2.22, 2.6, 0.33, 0.09, 0.09, 0.07), yring(-1.98, 2.6, 0.4, 0.09, 0.1, 0.08)], muzzle, rng))
    head.append(loft("nose", [yring(-2.52, 3.1, 0.18, 0.08, 0.1, 0.05), yring(-2.34, 3.14, 0.24, 0.1, 0.1, 0.06), yring(-2.26, 3.2, 0.17, 0.06, 0.06, 0.04)], tone(p["nose"]), rng))
    head.append(loft("bridge", [yring(-2.27, 3.3, 0.16, 0.04, 0.04, 0.03), yring(-2.0, 3.43, 0.2, 0.05, 0.05, 0.04), yring(-1.66, 3.78, 0.25, 0.05, 0.1, 0.05)], T("bridge"), rng))
    for s in (1, -1):
        head.append(shard((s * 0.1, -2.0, 3.5), (s * 0.8, -1.68, 3.86), 0.28, 0.24, T("brow"), rng, face=(0, -1, 0.3), at=0.45, name="brow"))
        head.append(shard((s * 0.5, -1.3, 3.7), (s * 0.72, -1.22, 4.34), 0.52, 0.22, body, rng, at=0.45, name="ear"))
        head.append(shard((s * 0.53, -1.41, 3.8), (s * 0.69, -1.36, 4.2), 0.28, 0.1, T("ear_in"), rng, at=0.45, name="ear"))
        # a slanted slit of an eye on the plane between the muzzle and the cheek
        at, n = k.land(skull, (s * 0.55, -1.8, 3.24), (s * 0.6, -0.8, 0.0))
        fx, fy, fz = k._frame(n)
        slit = [(-0.21, -0.075), (0.0, 0.07), (0.25, 0.095), (0.07, -0.045)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (fx * s, fy, fz), slit, 0.04, None, rng, m=glow))
        else:
            head.append(plate("eye", at, (fx * s, fy, fz), slit, 0.035, tone(p["iris"]), rng))
            head.append(plate("pupil", at, (fx * s, fy, fz), [(0.0, -0.05), (0.055, 0.0), (0.045, 0.075), (-0.005, 0.02)], 0.02, tone(INK), rng, lift=0.036))
        for j, (dz, long_) in enumerate(((0.0, 0.75), (-0.22, 0.6))):  # cheek tufts
            c0 = Vector((s * 0.7, -1.55, 2.95 + dz))
            head.append(shard(c0, c0 + Vector((s * 0.75, 0.25, -0.4 - j * 0.2)).normalized() * long_, 0.34, 0.16, (tone(p["mane_root"], p.get("mane_kind", p.get("kind", WARM))), tone(p["mane"][j % len(p["mane"])], p.get("mane_kind", p.get("kind", WARM)))), rng, face=(0, -1, 0.2)))
    if p.get("fang"):
        for s in (1, -1):
            head.append(shard((s * 0.24, -2.36, 2.74), (s * 0.24, -2.38, 2.42), 0.11, 0.09, tone(p["fang"], PALE), rng, name="fang"))

    grow = Matrix.Translation((0, -1.0, 3.1)) @ Matrix.Scale(HEAD, 4) @ Matrix.Translation((0, 1.0, -3.1))
    for ob in head + groups["head_glow"]:
        ob.data.transform(grow)

    # the mane: a dark core, then rings of shards raked back, long on top, and a bib down the chest
    head.append(loft("core", [yring(-1.2, 3.15, 0.8, 0.8, 0.75, 0.3), yring(-0.6, 3.05, 1.1, 1.05, 1.0, 0.4), yring(0.05, 2.95, 1.05, 1.0, 0.95, 0.4), yring(0.5, 2.9, 0.7, 0.7, 0.65, 0.28)], T("core"), rng, emit=p.get("lit", 0.0)))
    kind, lit = p.get("mane_kind", p.get("kind", WARM)), p.get("lit", 0.0)

    def lock(base, tip, width, tips, root, face, spark):
        if spark and glow:
            groups["head_glow"].append(shard(base, tip, width * 0.4, width * 0.22, None, rng, face=face, at=0.5, m=glow))
        else:
            head.append(shard(base, tip, width, width * 0.4, (root, tone(rng.choice(tips), kind)), rng, face=face, at=0.5, emit=lit))

    def ring(y, zc, radius, n, length, width, sweep, a0, a1, tips, root):
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * (i + 0.5) / n + rng.uniform(-5, 5))
            out = Vector((math.cos(a), 0, math.sin(a)))
            d = (out + Vector((0, sweep, -0.3 if out.z < -0.2 else 0.12))).normalized()
            base = Vector((0, y, zc)) + out * radius
            long_ = length * rng.uniform(0.9, 1.1) * (1 + 0.22 * max(0.0, out.z))
            face = Vector((rng.uniform(-0.12, 0.12), -0.7, rng.uniform(-0.1, 0.12))) + out
            lock(base - d * 0.25, base + d * long_, width * rng.uniform(0.85, 1.15), tips, root, face, p.get("sparks") and i % p["sparks"] == 1)

    root, deep = tone(p["mane_root"], kind), tone(p["bib_root"], kind)
    ring(-1.2, 3.3, 0.92, 13, 0.8, 0.66, 0.1, -40, 220, p["mane"], root)
    ring(-0.98, 3.25, 1.02, 15, 1.1, 0.92, 0.3, -62, 242, p["mane"], root)
    ring(-0.6, 3.2, 1.08, 15, 1.25, 1.05, 0.5, -52, 232, p["mane"], root)
    ring(-0.2, 3.12, 1.02, 12, 1.15, 1.0, 0.7, -32, 212, p["mane"], root)
    for y, z, half, n, long_, width, lean in ((-1.62, 2.5, 0.55, 5, 0.75, 0.52, -0.1), (-1.25, 2.55, 0.85, 7, 1.15, 0.7, -0.05), (-0.92, 2.35, 0.95, 7, 1.35, 0.78, 0.08)):
        for i in range(n):
            x = half * (2 * i / (n - 1) - 1)
            base = Vector((x, y, z - abs(x) * 0.25))
            d = Vector((x * 0.38, lean, -1)).normalized()
            lock(base - d * 0.2, base + d * long_ * rng.uniform(0.85, 1.15), width, p["bib"], deep, (rng.uniform(-0.2, 0.2), -1, 0), False)

    # the tail: thin, rising from the rump and falling to a flame of a tuft
    t0, tip = Vector((0, 3.05, 2.55)), Vector((0, 5.1, 1.75))
    tail = k.tube([t0, Vector((0, 3.6, 2.85)), Vector((0, 4.25, 2.75)), Vector((0, 4.8, 2.3)), tip], [0.17, 0.15, 0.13, 0.12, 0.1], m=material(), n=5, name="tail")
    groups["tail"].append(colour(tail, body, rng))
    for i in range(13):
        a = math.radians(-55 + 115 * (i * 5 % 13) / 12)  # from down and back round to up and back
        d = Vector((rng.uniform(-0.4, 0.4), math.cos(a), math.sin(a))).normalized()
        long_ = rng.uniform(1.1, 1.5) + 0.5 * math.cos(a - 0.2)
        width = rng.uniform(0.6, 0.9)
        if glow and p.get("sparks") and i % 5 == 2:
            groups["tail_glow"].append(shard(tip - d * 0.1, tip + d * long_ * 0.75, width * 0.7, width * 0.4, None, rng, face=(1, 0, 0.3), at=0.42, m=glow))
        else:
            groups["tail"].append(shard(tip - d * 0.25, tip + d * long_, width, width * 0.5, (root, tone(rng.choice(p["mane"]), kind)), rng, face=(rng.choice((-1, 1)), 0, 0.3), at=0.42, emit=lit))

    extra = p.get("extra")
    if extra:
        extra(groups, torso, thighs, rng, glow)
    joints = {"head": (0, -0.75, 2.75), "leg_fl": (0.6, 0, 2.0), "leg_fr": (-0.6, 0, 2.0), "leg_bl": (0.6, 2.15, 2.0), "leg_br": (-0.6, 2.15, 2.0), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def lion():
    """Lion: tawny, a dark brown mane, pale paws and muzzle, amber eyes."""
    return lion_model(
        dict(body=(214, 158, 80), fore=(226, 178, 102), paw=(236, 218, 180), muzzle=(238, 222, 188), nose=(62, 40, 34), brow=(176, 122, 58), bridge=(232, 188, 118), ear_in=(150, 96, 50), iris=(244, 180, 40),
             core=(74, 44, 24), mane_root=(88, 52, 26), mane=[(142, 92, 44), (168, 114, 56), (114, 72, 34), (188, 134, 70)], bib_root=(70, 42, 22), bib=[(120, 76, 36), (142, 92, 46)]),
        3,
    )


def sun_extra(groups, torso, thighs, rng, glow):
    """A sun on each haunch: a disc and eight rays, raised a hair off the thigh."""
    gold = tone((255, 228, 120))
    for s in (1, -1):
        at, n = k.land(thighs[s], (s * 0.5, 2.1, 2.2), (s, 0, 0))
        fx, fy, fz = k._frame(n)
        frame = (fx, fy, fz)
        side = "leg_b" + ("l" if s > 0 else "r")
        groups[side].append(plate("sun", at, frame, [(0.19 * math.cos(i * math.tau / 8), 0.19 * math.sin(i * math.tau / 8)) for i in range(8)], 0.03, gold, rng))
        for i in range(8):
            a = (i + 0.5) * math.tau / 8
            c, s_ = math.cos(a), math.sin(a)
            ray = [(0.25 * c - 0.07 * s_, 0.25 * s_ + 0.07 * c), (0.46 * c, 0.46 * s_), (0.25 * c + 0.07 * s_, 0.25 * s_ - 0.07 * c)]
            groups[side].append(plate("ray", at, frame, ray, 0.03, gold, rng))


def sun_lion():
    """Sun Lion (mythic): a golden coat, a blazing mane of yellow crystal with white-hot sparks, a sun
    on each haunch, a flame of a tail."""
    return lion_model(
        dict(body=(242, 150, 38), fore=(252, 184, 64), paw=(250, 226, 176), muzzle=(250, 228, 180), mane_kind=FIRE, nose=(118, 62, 38), brow=(226, 122, 30), bridge=(255, 198, 86), ear_in=(206, 96, 30),
             core=(214, 104, 22), mane_root=(240, 140, 24), mane=[(255, 210, 44), (255, 222, 70), (255, 196, 36), (255, 226, 84)], bib_root=(214, 104, 22), bib=[(248, 164, 36), (255, 190, 46), (255, 210, 60)],
             glow=SUNFIRE, glow_eyes=True, sparks=6, lit=0.08, extra=sun_extra),
        5,
    )


def shadow_extra(groups, torso, thighs, rng, glow):
    """Glowing ribs down both flanks and a spine of bone."""
    for s in (1, -1):
        for i in range(5):
            y = 0.78 + i * 0.25
            top, _ = k.land(torso, (0, y, 2.85), (s, 0, 0))
            low, _ = k.land(torso, (0, y + 0.14, 1.95 + abs(i - 3) * 0.04), (s, 0, 0))
            groups["body_glow"].append(shard(top + Vector((s * 0.02, 0, 0)), low + Vector((s * 0.02, 0, 0)), 0.15, 0.07, None, rng, face=(s, 0, 0), at=0.25, m=glow, name="rib"))
    for i in range(8):
        base = Vector((0, 1.0 + i * 0.26, 3.1 - abs(i - 4.5) * 0.02))
        groups["body"].append(shard(base, base + Vector((0, 0.22, 0.6 - i * 0.03)), 0.3, 0.2, tone(BONE, PALE), rng, face=(1, 0, 0), name="spine"))


def shadow_lion():
    """Shadow Lion (legendary): ink black, a bone mask and spine, a mane of black crystal shot with green
    shards, glowing green ribs, eyes and tail."""
    return lion_model(
        dict(kind=COOL, paw_kind=COOL, body=(30, 32, 44), fore=(40, 44, 60), paw=(58, 62, 80), muzzle=BONE, nose=(14, 16, 20), brow=BONE, bridge=BONE, ear_in=(66, 76, 98), claw=BONE, fang=BONE,
             core=(8, 9, 13), mane_root=(10, 11, 16), mane=[(34, 40, 56), (22, 26, 38), (50, 58, 78), (16, 18, 26)], bib_root=(8, 9, 13), bib=[(26, 30, 42), (38, 44, 60)],
             glow=SHADOW, glow_eyes=True, sparks=5, extra=shadow_extra),
        7,
    )


def asset(name, maker, scale, glow, note):
    joints = {}

    def build():
        groups, j = maker()
        joints.update(j)
        return groups

    # the budget is only a ceiling for the build's check: these models are a few thousand triangles
    return dict(name=name, build=build, scale=scale, budget=20000, finalize=k.HD, joints=joints, glow=glow, notes=note)


# scales keep each lion about as long as the model it replaces (13, 16 and 15 studs), tail flame included
ASSETS = [
    asset("creature_lion", lion, 1.3, {}, "Lion: a faceted tawny cat with a mane of brown crystal shards."),
    asset("creature_lion_sun", sun_lion, 1.65, {"head_glow": SUNFIRE, "tail_glow": SUNFIRE}, "Sun Lion (mythic): golden, a blazing mane of yellow crystal, a sun on each haunch."),
    asset("creature_lion_shadow", shadow_lion, 1.5, {"head_glow": SHADOW, "body_glow": SHADOW, "tail_glow": SHADOW}, "Shadow Lion (legendary): ink black, a bone mask and spine, glowing green ribs and shards."),
]
