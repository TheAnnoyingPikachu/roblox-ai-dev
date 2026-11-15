"""The lions (decision 0050): the Lion, the Sun Lion and the Shadow Lion as chunky low-poly cats, after
SHANNON's Sun Lion reference card. A few big blocks: a lofted body and legs, paws with three toes, a
boxy head with slit eyes, and a mane of some thirty large crystal shards. Nothing is smooth: every
face has one colour (the `lp` colour attribute), picked from three tones by which way the face points
plus a little chance, so the facets read in any light and bake straight into the texture.

Keep it plain: SHANNON found a denser version (75 shards, bevelled sections, small face pieces) too
detailed. Add a piece only if it reads from across the arena.

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
LIFT = 0.4  # the head and mane are written for a low body and raised by this
HIND = 3.2  # how far behind the front legs the hind legs stand: a long body, as on the reference
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


def paw(x, y, tones, rng):
    """A compact block of a paw, a little wider than the leg, with three short toes: from the heel at
    y + 0.4 to the toes at y - 0.62."""
    parts = [loft("paw", [yring(y + 0.4, 0.26, 0.4, 0.24, 0.26, 0.12, x), yring(y - 0.3, 0.28, 0.46, 0.27, 0.28, 0.13, x)], tones, rng)]
    for dx in (-0.3, 0.0, 0.3):
        parts.append(loft("toe", [quad(y - 0.26, 0.24, 0.14, 0.22, 0.24, x + dx), quad(y - 0.62, 0.18, 0.13, 0.12, 0.18, x + dx)], tones, rng))
    return parts


def lion_model(p, seed):
    """The lion from a palette `p` (see the three makers below). Returns (groups, joints)."""
    rng = random.Random(seed)
    kind = p.get("kind", WARM)
    T = lambda key: tone(p[key], kind)  # noqa: E731
    body, fore, cream = T("body"), T("fore"), tone(p["paw"], p.get("paw_kind", PALE))
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "head_glow": [], "body_glow": [], "tail": [], "tail_glow": []}

    # the torso: a deep chest, a tucked waist, square hips
    torso = loft("torso", [yring(*r) for r in ((-1.0, 2.75, 0.6, 0.65, 0.7, 0.3), (-0.3, 2.7, 0.92, 0.95, 0.92, 0.4), (1.7, 2.77, 0.76, 0.78, 0.66, 0.34), (HIND + 0.1, 2.73, 0.86, 0.82, 0.78, 0.38), (HIND + 0.95, 2.8, 0.45, 0.45, 0.4, 0.2))], body, rng)
    groups["body"].append(torso)

    # legs: the upper leg in the body's colour, the lower lighter, a pale paw
    thighs = {}
    for s in (1, -1):
        x = s * 0.6
        thigh = loft("thigh", [zring(x, HIND + 0.05, 3.15, 0.42, 0.76, 0.2), zring(x, HIND - 0.05, 2.4, 0.5, 0.86, 0.22), zring(x, HIND - 0.25, 1.7, 0.4, 0.56, 0.17)], body, rng)
        thighs[s] = thigh
        groups["leg_f" + ("l" if s > 0 else "r")] = [
            loft("arm", [zring(x, 0.0, 2.9, 0.44, 0.56, 0.2), zring(x, 0.06, 1.5, 0.38, 0.46, 0.17)], body, rng),
            loft("forearm", [zring(x, 0.06, 1.55, 0.36, 0.46, 0.16), zring(x, 0.0, 0.45, 0.34, 0.42, 0.15)], fore, rng),
            *paw(x, 0.0, cream, rng),
        ]
        groups["leg_b" + ("l" if s > 0 else "r")] = [
            thigh,
            loft("shin", [zring(x, HIND - 0.25, 1.75, 0.36, 0.5, 0.15), zring(x, HIND + 0.32, 1.05, 0.33, 0.42, 0.14), zring(x, HIND + 0.18, 0.45, 0.34, 0.42, 0.14)], fore, rng),
            *paw(x, HIND + 0.12, cream, rng),
        ]

    # the head: a boxy muzzle stepping up to a broad brow, one pale block for the lips and chin
    skull = loft("skull", [yring(*r) for r in ((-2.45, 2.98, 0.32, 0.24, 0.24, 0.12), (-2.0, 3.0, 0.46, 0.42, 0.36, 0.16), (-1.65, 3.15, 0.76, 0.64, 0.52, 0.28), (-1.25, 3.2, 0.78, 0.68, 0.55, 0.3), (-0.8, 3.15, 0.64, 0.6, 0.5, 0.26))], body, rng)
    head = groups["head"]
    head.append(skull)
    head.append(loft("muzzle", [yring(-2.5, 2.8, 0.34, 0.14, 0.2, 0.1), yring(-2.08, 2.76, 0.47, 0.14, 0.26, 0.13)], tone(p["muzzle"], p.get("paw_kind", PALE)), rng))
    head.append(loft("nose", [yring(-2.54, 3.12, 0.2, 0.09, 0.1, 0.07), yring(-2.3, 3.18, 0.22, 0.08, 0.08, 0.07)], tone(p["nose"]), rng))
    for s in (1, -1):
        head.append(shard((s * 0.1, -2.0, 3.5), (s * 0.8, -1.68, 3.86), 0.28, 0.24, T("brow"), rng, face=(0, -1, 0.3), at=0.45, name="brow"))
        head.append(shard((s * 0.5, -1.3, 3.7), (s * 0.72, -1.22, 4.34), 0.52, 0.22, body, rng, at=0.45, name="ear"))
        # a slanted slit of an eye on the plane between the muzzle and the cheek
        at, n = k.land(skull, (s * 0.55, -1.8, 3.24), (s * 0.6, -0.8, 0.0))
        fx, fy, fz = k._frame(n)
        slit = [(-0.21, -0.075), (0.0, 0.07), (0.25, 0.095), (0.07, -0.045)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (fx * s, fy, fz), slit, 0.04, None, rng, m=glow))
        else:
            head.append(plate("eye", at, (fx * s, fy, fz), slit, 0.035, tone(p["iris"]), rng))
            head.append(plate("pupil", at, (fx * s, fy, fz), [(0.0, -0.05), (0.055, 0.0), (0.045, 0.075), (-0.005, 0.02)], 0.02, tone(INK), rng, lift=0.036))
        if p.get("fang"):
            head.append(shard((s * 0.24, -2.36, 2.62), (s * 0.24, -2.38, 2.28), 0.13, 0.1, tone(p["fang"], PALE), rng, name="fang"))
    grow = Matrix.Translation((0, -1.0, 3.1 + LIFT)) @ Matrix.Scale(HEAD, 4) @ Matrix.Translation((0, 1.0, -3.1))
    for ob in head + groups["head_glow"]:
        ob.data.transform(grow)

    # the mane: a core, three rings of big shards raked back, and a bib down the chest
    mane_kind, lit = p.get("mane_kind", kind), p.get("lit", 0.0)
    root, deep = tone(p["mane_root"], mane_kind), tone(p["bib_root"], mane_kind)
    head.append(loft("core", [yring(-1.2, 3.15 + LIFT, 0.85, 0.85, 0.8, 0.36), yring(-0.5, 3.05 + LIFT, 1.15, 1.1, 1.05, 0.48), yring(0.4, 2.95 + LIFT, 0.8, 0.8, 0.75, 0.34)], T("core"), rng, emit=lit))
    count = 0

    def lock(base, tip, width, tips, tones, face):
        nonlocal count
        count += 1
        if glow and p.get("sparks") and count % p["sparks"] == 0:  # every so many, a glowing one
            groups["head_glow"].append(shard(base, tip, width * 0.6, width * 0.3, None, rng, face=face, m=glow))
        else:
            head.append(shard(base, tip, width, width * 0.45, (tones, tone(rng.choice(tips), mane_kind)), rng, face=face, emit=lit))

    for y, zc, radius, n, length, width, sweep, a0, a1 in ((-1.15, 3.3, 0.95, 8, 0.95, 1.0, 0.15, -40, 220), (-0.8, 3.22, 1.05, 9, 1.35, 1.3, 0.45, -58, 238), (-0.3, 3.12, 1.0, 7, 1.3, 1.3, 0.75, -30, 210)):
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * (i + 0.5) / n + rng.uniform(-5, 5))
            out = Vector((math.cos(a), 0, math.sin(a)))
            d = (out + Vector((0, sweep, -0.3 if out.z < -0.2 else 0.12))).normalized()
            base = Vector((0, y, zc + LIFT)) + out * radius
            long_ = length * rng.uniform(0.9, 1.1) * (1 + 0.4 * max(0.0, out.z))
            lock(base - d * 0.25, base + d * long_, width * rng.uniform(0.9, 1.1), p["mane"], root, Vector((0, -0.7, 0)) + out)
    for y, z, half, n, long_, width, lean in ((-1.5, 2.55, 0.5, 3, 1.0, 0.75, -0.08), (-1.0, 2.45, 0.85, 4, 1.6, 0.95, 0.05)):
        for i in range(n):
            x = half * (2 * i / (n - 1) - 1)
            base = Vector((x, y, z + LIFT - abs(x) * 0.25))
            d = Vector((x * 0.38, lean, -1)).normalized()
            lock(base - d * 0.2, base + d * long_ * rng.uniform(0.9, 1.1), width, p["bib"], deep, (0, -1, 0))

    # the tail: thin, rising from the rump and falling to a fan of six shards
    t0, tip = Vector((0, HIND + 0.85, 2.95)), Vector((0, HIND + 3.0, 2.0))
    tail = k.tube([t0, Vector((0, HIND + 1.55, 3.25)), Vector((0, HIND + 2.45, 2.85)), tip], [0.18, 0.16, 0.13, 0.11], m=material(), n=4, name="tail")
    groups["tail"].append(colour(tail, body, rng))
    for i in range(6):
        a = math.radians(-55 + 23 * i)  # from down and back round to up and back
        d = Vector(((i % 3 - 1) * 0.3, math.cos(a), math.sin(a))).normalized()
        long_ = 1.3 + 0.55 * math.cos(a - 0.2)
        if glow and p.get("sparks") and i == 3:
            groups["tail_glow"].append(shard(tip - d * 0.2, tip + d * long_, 0.6, 0.35, None, rng, face=(1, 0, 0.3), at=0.42, m=glow))
        else:
            groups["tail"].append(shard(tip - d * 0.25, tip + d * long_, 0.95, 0.5, (root, tone(p["mane"][i % len(p["mane"])], mane_kind)), rng, face=(1 if i % 2 else -1, 0, 0.3), at=0.42, emit=lit))

    extra = p.get("extra")
    if extra:
        extra(groups, torso, thighs, rng, glow)
    joints = {"head": (0, -0.75, 3.15), "leg_fl": (0.6, 0, 2.4), "leg_fr": (-0.6, 0, 2.4), "leg_bl": (0.6, HIND, 2.4), "leg_br": (-0.6, HIND, 2.4), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def lion():
    """Lion: tawny, a dark brown mane, pale paws and muzzle, amber eyes."""
    return lion_model(
        dict(body=(214, 158, 80), fore=(226, 178, 102), paw=(236, 218, 180), muzzle=(238, 222, 188), nose=(62, 40, 34), brow=(176, 122, 58), iris=(244, 180, 40),
             core=(74, 44, 24), mane_root=(88, 52, 26), mane=[(142, 92, 44), (168, 114, 56), (114, 72, 34), (188, 134, 70)], bib_root=(70, 42, 22), bib=[(120, 76, 36), (142, 92, 46)]),
        3,
    )


def sun_extra(groups, torso, thighs, rng, glow):
    """A sun on each haunch: one eight-pointed star, raised a hair off the thigh."""
    star = [((0.44 if i % 2 == 0 else 0.2) * math.cos(i * math.tau / 16), (0.44 if i % 2 == 0 else 0.2) * math.sin(i * math.tau / 16)) for i in range(16)]
    for s in (1, -1):
        at, n = k.land(thighs[s], (s * 0.5, HIND - 0.05, 2.6), (s, 0, 0))
        groups["leg_b" + ("l" if s > 0 else "r")].append(plate("sun", at, k._frame(n), star, 0.03, tone((255, 228, 120)), rng))


def sun_lion():
    """Sun Lion (mythic): a golden coat, a mane of yellow crystal, a sun on each haunch, glowing eyes, a
    flame of a tail."""
    return lion_model(
        dict(body=(242, 150, 38), fore=(252, 184, 64), paw=(250, 226, 176), muzzle=(250, 228, 180), mane_kind=FIRE, nose=(118, 62, 38), brow=(226, 122, 30),
             core=(214, 104, 22), mane_root=(240, 140, 24), mane=[(255, 210, 44), (255, 222, 70), (255, 196, 36), (255, 226, 84)], bib_root=(214, 104, 22), bib=[(248, 164, 36), (255, 190, 46), (255, 210, 60)],
             glow=SUNFIRE, glow_eyes=True, lit=0.08, extra=sun_extra),
        5,
    )


def shadow_extra(groups, torso, thighs, rng, glow):
    """Three glowing ribs down each flank and a spine of four bone plates."""
    for s in (1, -1):
        for i in range(3):
            y = 0.9 + i * 0.6
            top, _ = k.land(torso, (0, y, 3.15), (s, 0, 0))
            low, _ = k.land(torso, (0, y + 0.16, 2.45), (s, 0, 0))
            groups["body_glow"].append(shard(top + Vector((s * 0.02, 0, 0)), low + Vector((s * 0.02, 0, 0)), 0.24, 0.08, None, rng, face=(s, 0, 0), at=0.3, m=glow, name="rib"))
    for i in range(4):
        base = Vector((0, 1.0 + i * 0.75, 3.45))
        groups["body"].append(shard(base, base + Vector((0, 0.3, 0.8 - i * 0.08)), 0.5, 0.26, tone(BONE, PALE), rng, face=(1, 0, 0), at=0.4, name="spine"))


def shadow_lion():
    """Shadow Lion (legendary): ink black, a bone mask and spine, a mane of black crystal with a few green
    shards, glowing green ribs, eyes and tail."""
    return lion_model(
        dict(kind=COOL, paw_kind=COOL, body=(30, 32, 44), fore=(40, 44, 60), paw=(58, 62, 80), muzzle=BONE, nose=(14, 16, 20), brow=BONE, fang=BONE,
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

    # the budget is only a ceiling for the build's check: these models are about a thousand triangles
    return dict(name=name, build=build, scale=scale, budget=20000, finalize=k.HD, joints=joints, glow=glow, notes=note)


# scales keep each lion about as long as the model it replaces (13, 16 and 15 studs), tail flame included
ASSETS = [
    asset("creature_lion", lion, 1.17, {}, "Lion: a chunky low-poly tawny cat with a mane of big brown shards."),
    asset("creature_lion_sun", sun_lion, 1.48, {"head_glow": SUNFIRE}, "Sun Lion (mythic): golden, a mane of big yellow shards, a sun on each haunch, glowing eyes."),
    asset("creature_lion_shadow", shadow_lion, 1.35, {"head_glow": SHADOW, "body_glow": SHADOW, "tail_glow": SHADOW}, "Shadow Lion (legendary): ink black, a bone mask and spine, glowing green ribs and shards."),
]
