"""The lions (decision 0050): the Lion, the Sun Lion and the Shadow Lion as chunky low-poly cats, after
SHANNON's Sun Lion reference card. Big blocks: a long boxy body on thick square legs, paws with three
short toes, a head after the reference, and a full mane of about sixty broad leaves. Nothing is smooth: every
face has one colour (the `lp` colour attribute), picked from three tones by which way the face points
plus a little chance, so the facets read in any light and bake straight into the texture.

The measure is the reference card: SHANNON asked for the lions to match it. A version with thin
shards, bevelled sections and small extra pieces was too detailed, a plainer one with thirty shards
too sparse. Keep faces big and flat; add a piece only if the reference has it.

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
    parts = [loft("paw", [yring(y + 0.44, 0.26, 0.47, 0.24, 0.26, 0.12, x), yring(y - 0.32, 0.28, 0.55, 0.27, 0.28, 0.13, x)], tones, rng)]
    for dx in (-0.36, 0.0, 0.36):
        parts.append(loft("toe", [quad(y - 0.28, 0.24, 0.165, 0.22, 0.24, x + dx), quad(y - 0.66, 0.18, 0.15, 0.12, 0.18, x + dx)], tones, rng))
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
    torso = loft("torso", [yring(*r) for r in ((-1.0, 2.75, 0.66, 0.68, 0.72, 0.2), (-0.3, 2.7, 1.0, 1.0, 0.95, 0.24), (1.7, 2.77, 0.84, 0.82, 0.7, 0.22), (HIND + 0.1, 2.73, 0.94, 0.86, 0.8, 0.24), (HIND + 0.95, 2.8, 0.5, 0.48, 0.42, 0.15))], body, rng)
    groups["body"].append(torso)

    # legs: the upper leg in the body's colour, the lower lighter, a pale paw
    thighs = {}
    for s in (1, -1):
        x = s * 0.68
        thigh = loft("thigh", [zring(x, HIND + 0.05, 3.15, 0.5, 0.8, 0.13), zring(x, HIND - 0.05, 2.2, 0.58, 0.92, 0.15), zring(x, HIND - 0.25, 1.7, 0.46, 0.62, 0.12)], body, rng)
        thighs[s] = thigh
        groups["leg_f" + ("l" if s > 0 else "r")] = [
            loft("arm", [zring(x, 0.0, 2.9, 0.52, 0.62, 0.13), zring(x, 0.06, 1.5, 0.46, 0.52, 0.11)], body, rng),
            loft("forearm", [zring(x, 0.06, 1.55, 0.44, 0.5, 0.11), zring(x, 0.0, 0.45, 0.42, 0.48, 0.1)], fore, rng),
            *paw(x, 0.0, cream, rng),
        ]
        groups["leg_b" + ("l" if s > 0 else "r")] = [
            thigh,
            loft("shin", [zring(x, HIND - 0.25, 1.75, 0.44, 0.56, 0.11), zring(x, HIND + 0.32, 1.05, 0.4, 0.48, 0.1), zring(x, HIND + 0.18, 0.45, 0.42, 0.48, 0.1)], fore, rng),
            *paw(x, HIND + 0.12, cream, rng),
        ]

    # the head, after the reference: a short deep muzzle with a blunt front, stepping up to a broad
    # brow; the pale lips wrap the front of the snout under a dark wedge of a nose, the chin sits a
    # little back under a dark line of a mouth. The lips, mouth and chin have small corner cuts and
    # stand just proud of the skull, or its own cut corners swallow them
    skull = loft("skull", [yring(*r) for r in ((-2.4, 2.95, 0.34, 0.3, 0.3, 0.12), (-2.0, 3.0, 0.44, 0.42, 0.38, 0.15), (-1.7, 3.18, 0.74, 0.66, 0.56, 0.28), (-1.25, 3.22, 0.78, 0.7, 0.58, 0.3), (-0.8, 3.15, 0.64, 0.6, 0.5, 0.26))], body, rng)
    head = groups["head"]
    head.append(skull)
    pale, dark = tone(p["muzzle"], p.get("paw_kind", PALE)), tone(p["nose"])
    head.append(loft("lips", [yring(-2.44, 2.93, 0.36, 0.19, 0.185, 0.04), yring(-1.98, 2.92, 0.475, 0.19, 0.19, 0.05)], pale, rng))
    head.append(loft("mouth", [yring(-2.42, 2.725, 0.34, 0.025, 0.025, 0.02), yring(-1.9, 2.705, 0.47, 0.025, 0.03, 0.02)], dark, rng))
    head.append(loft("chin", [yring(-2.4, 2.63, 0.35, 0.075, 0.08, 0.05), yring(-1.95, 2.61, 0.46, 0.075, 0.07, 0.06)], pale, rng))
    # the nose: wide on top, narrow below, wrapped over the front edge, with a line down to the mouth
    head.append(loft("nose", [[(0.24, -2.47, 3.27), (0.1, -2.47, 3.0), (-0.1, -2.47, 3.0), (-0.24, -2.47, 3.27)], [(0.26, -2.2, 3.37), (0.14, -2.2, 3.2), (-0.14, -2.2, 3.2), (-0.26, -2.2, 3.37)]], dark, rng))
    head.append(loft("philtrum", [quad(-2.46, 2.87, 0.02, 0.13, 0.13), quad(-2.43, 2.87, 0.02, 0.13, 0.13)], dark, rng))
    head.append(loft("bridge", [yring(-2.2, 3.35, 0.15, 0.02, 0.03, 0.015), yring(-1.72, 3.83, 0.22, 0.02, 0.06, 0.015)], T("bridge"), rng))
    ear = [(-0.27, 0.0), (-0.25, 0.2), (-0.12, 0.37), (0.12, 0.37), (0.25, 0.2), (0.27, 0.0)]  # rounded
    for s in (1, -1):
        # a ledge of a brow over the eye, low at the nose and a little higher outside
        head.append(shard((s * 0.16, -2.02, 3.42), (s * 0.84, -1.66, 3.58), 0.3, 0.22, T("brow"), rng, face=(0, -1, 0.6), name="brow"))
        frame = k._frame(Vector((s * 0.35, -1, 0)), (s * 0.3, 0, 1))
        at = Vector((s * 0.56, -1.2, 3.78))
        head.append(plate("ear", at, frame, ear, 0.14, body, rng))
        head.append(plate("ear", at + frame[2] * 0.14, frame, [(u * 0.6, 0.03 + v * 0.62) for u, v in ear], 0.03, T("ear_in"), rng))
        # a slit of an eye high on the plane between the muzzle and the cheek
        at, n = k.land(skull, (s * 0.55, -1.85, 3.3), (s * 0.6, -0.8, 0.1))
        fx, fy, fz = k._frame(n)
        slit = [(-0.2, -0.06), (0.02, 0.08), (0.24, 0.07), (0.06, -0.05)]
        if p.get("glow_eyes"):
            groups["head_glow"].append(plate("eye", at, (fx * s, fy, fz), slit, 0.04, None, rng, m=glow))
        else:
            head.append(plate("eye", at, (fx * s, fy, fz), slit, 0.035, tone(p["iris"]), rng))
            head.append(plate("pupil", at, (fx * s, fy, fz), [(0.0, -0.045), (0.05, 0.0), (0.045, 0.07), (-0.005, 0.02)], 0.02, tone(INK), rng, lift=0.036))
        if p.get("fang"):
            head.append(shard((s * 0.22, -2.38, 2.76), (s * 0.22, -2.4, 2.4), 0.13, 0.1, tone(p["fang"], PALE), rng, name="fang"))
    grow = Matrix.Translation((0, -1.0, 3.1 + LIFT)) @ Matrix.Scale(HEAD, 4) @ Matrix.Translation((0, 1.0, -3.1))
    for ob in head + groups["head_glow"]:
        ob.data.transform(grow)

    # the mane: a core, five rings of broad leaves (the first frames the face, the last lies over the
    # shoulders), and a wide bib of three rows down the chest
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
            head.append(shard(base, tip, width, width * 0.45, (tones, tone(rng.choice(tips), mane_kind)), rng, face=face, at=0.45, emit=lit))

    for y, zc, radius, n, length, width, sweep, a0, a1 in ((-1.3, 3.3, 0.88, 10, 0.9, 0.8, -0.1, -50, 230), (-1.05, 3.26, 0.98, 11, 1.35, 1.0, 0.2, -60, 240), (-0.7, 3.2, 1.06, 11, 1.7, 1.15, 0.5, -55, 235), (-0.25, 3.12, 1.0, 9, 1.8, 1.15, 0.85, -40, 220), (0.2, 3.05, 0.85, 6, 1.6, 1.05, 1.3, 20, 160)):
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * (i + 0.5) / n + rng.uniform(-5, 5))
            out = Vector((math.cos(a), 0, math.sin(a)))
            d = (out + Vector((0, sweep, -0.3 if out.z < -0.2 else 0.12))).normalized()
            base = Vector((0, y, zc + LIFT)) + out * radius
            long_ = length * rng.uniform(0.9, 1.1) * (1 + 0.4 * max(0.0, out.z))
            lock(base - d * 0.25, base + d * long_, width * rng.uniform(0.9, 1.1), p["mane"], root, Vector((0, -0.7, 0)) + out)
    for y, z, half, n, long_, width, lean in ((-1.55, 2.6, 0.55, 3, 1.0, 0.9, -0.08), (-1.2, 2.5, 0.9, 5, 1.6, 1.05, -0.02), (-0.85, 2.3, 1.0, 5, 2.0, 1.1, 0.06)):
        for i in range(n):
            x = half * (2 * i / (n - 1) - 1)
            base = Vector((x, y, z + LIFT - abs(x) * 0.25))
            d = Vector((x * 0.38, lean, -1)).normalized()
            lock(base - d * 0.2, base + d * long_ * (1.15 - 0.3 * abs(x) / half), width, p["bib"], deep, (0, -1, 0))

    # the tail: thin, rising from the rump and falling to a flame of seven shards, the middle one longest
    t0, tip = Vector((0, HIND + 0.85, 2.95)), Vector((0, HIND + 3.3, 2.2))
    tail = k.tube([t0, Vector((0, HIND + 1.6, 3.4)), Vector((0, HIND + 2.6, 3.1)), tip], [0.18, 0.16, 0.13, 0.11], m=material(), n=4, name="tail")
    groups["tail"].append(colour(tail, body, rng))
    flow = Vector((0, 0.8, -0.6))
    for i in range(7):
        off = (i - 3) / 3  # -1 to 1 across the flame
        d = (flow + Vector((off * 0.32, -abs(off) * 0.12, (0.5 if i % 2 else -0.1) * abs(off)))).normalized()
        base = tip - flow * (0.25 + 0.2 * abs(off))
        long_, width = 2.8 - 0.9 * abs(off), 1.25 - 0.25 * abs(off)
        if glow and p.get("sparks") and i == 3:
            groups["tail_glow"].append(shard(base, base + d * long_, width * 0.7, 0.35, None, rng, face=(1, 0, 0.3), at=0.36, m=glow))
        else:
            groups["tail"].append(shard(base, base + d * long_, width, 0.6, (root, tone(p["mane"][i % len(p["mane"])], mane_kind)), rng, face=(1 if i % 2 else -1, 0, 0.3), at=0.36, emit=lit))

    extra = p.get("extra")
    if extra:
        extra(groups, torso, thighs, rng, glow)
    joints = {"head": (0, -0.75, 3.15), "leg_fl": (0.68, 0, 2.4), "leg_fr": (-0.68, 0, 2.4), "leg_bl": (0.68, HIND, 2.4), "leg_br": (-0.68, HIND, 2.4), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def lion():
    """Lion: tawny, a dark brown mane, pale paws and muzzle, amber eyes."""
    return lion_model(
        dict(body=(214, 158, 80), fore=(226, 178, 102), paw=(236, 218, 180), muzzle=(238, 222, 188), nose=(62, 40, 34), brow=(220, 168, 92), bridge=(230, 184, 110), ear_in=(150, 96, 50), iris=(244, 180, 40),
             core=(74, 44, 24), mane_root=(88, 52, 26), mane=[(142, 92, 44), (168, 114, 56), (114, 72, 34), (188, 134, 70)], bib_root=(70, 42, 22), bib=[(120, 76, 36), (142, 92, 46)]),
        3,
    )


def sun_extra(groups, torso, thighs, rng, glow):
    """A sun on each haunch, as on the reference: a disc and twelve rays, raised a hair off the thigh."""
    gold = tone((255, 228, 120))
    disc = [(0.2 * math.cos(i * math.tau / 8), 0.2 * math.sin(i * math.tau / 8)) for i in range(8)]
    for s in (1, -1):
        at, n = k.land(thighs[s], (s * 0.5, HIND, 2.68), (s, 0, 0))
        frame, leg = k._frame(n), groups["leg_b" + ("l" if s > 0 else "r")]
        leg.append(plate("sun", at, frame, disc, 0.03, gold, rng))
        for i in range(12):
            c, s_ = math.cos(i * math.tau / 12), math.sin(i * math.tau / 12)
            ray = [(0.26 * c - 0.055 * s_, 0.26 * s_ + 0.055 * c), (0.44 * c, 0.44 * s_), (0.26 * c + 0.055 * s_, 0.26 * s_ - 0.055 * c)]
            leg.append(plate("ray", at, frame, ray, 0.03, gold, rng))


def sun_lion():
    """Sun Lion (mythic): a golden coat, a mane of yellow crystal, a sun on each haunch, glowing eyes, a
    flame of a tail."""
    return lion_model(
        dict(body=(244, 154, 38), fore=(250, 172, 52), paw=(250, 226, 176), muzzle=(250, 228, 180), mane_kind=FIRE, nose=(104, 54, 34), brow=(246, 166, 48), bridge=(255, 192, 72), ear_in=(206, 96, 30),
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
        dict(kind=COOL, paw_kind=COOL, body=(30, 32, 44), fore=(40, 44, 60), paw=(58, 62, 80), muzzle=BONE, nose=(14, 16, 20), brow=BONE, bridge=BONE, ear_in=(66, 76, 98), fang=BONE,
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
    asset("creature_lion", lion, 1.15, {}, "Lion: a chunky low-poly tawny cat with a mane of big brown shards."),
    asset("creature_lion_sun", sun_lion, 1.42, {"head_glow": SUNFIRE}, "Sun Lion (mythic): golden, a mane of big yellow shards, a sun on each haunch, glowing eyes."),
    asset("creature_lion_shadow", shadow_lion, 1.33, {"head_glow": SHADOW, "body_glow": SHADOW, "tail_glow": SHADOW}, "Shadow Lion (legendary): ink black, a bone mask and spine, glowing green ribs and shards."),
]
