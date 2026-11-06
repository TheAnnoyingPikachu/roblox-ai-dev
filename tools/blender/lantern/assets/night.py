"""Lantern Express night assets (docs/architecture/lantern.md section 9; art bible section 9, "Mild"):
the shadow wisp and the Lampeater (body and two wings, each its own asset so code can flap the
wings). Same HD helpers as the critters (fuse, lens, the family's catchlights), one mesh and one
baked texture each, front -Y, origin at the base centre. Cute-spooky, never scary: no mouths with
teeth, no claws, no red eyes, never black."""

import math
import os
import sys

import bmesh
import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "garden", "assets"))
from creatures_a import xf  # noqa: E402


def swap(ob, m):
    ob.data.materials[0] = m
    return ob


def fit(parts, size):
    """Scales the parts to `size` [x, height, depth] studs (Roblox order) and stands them on the
    origin; returns the matrix, so paints placed after it can use build points."""
    lo, hi = k._ground_dims(parts)
    d = hi - lo
    s = (size[0] / d.x, size[2] / d.y, size[1] / d.z)
    print(f"[night] fit scale x {s[0]:.2f} y {s[1]:.2f} z {s[2]:.2f}", flush=True)
    m = Matrix.Translation((-(lo.x + hi.x) / 2 * s[0], -(lo.y + hi.y) / 2 * s[1], -lo.z * s[2])) @ Matrix.Diagonal((*s, 1))
    for ob in parts:
        ob.data.transform(m)
    return m


def zspan(ob):
    lo, hi = k._ground_dims([ob])
    return lo.z, hi.z


def glass_eye(target, centre, d, r, glass, pupil=k.EYE_INK):
    """A round lantern-glass eye: the family's dark glossy eye (a big pupil and its two
    catchlights, big upper left, small lower right) inside a glowing amber glass rim."""
    dome = k.lens(target, centre, d, r, glass, thick=0.5, sink=0.5, seg=16, name="eye")
    p, n = k.land(target, centre, d)
    x, y, _ = k._frame(n)
    pupil_ob = k.lens(dome, centre, d, r * 0.76, k.flat(pupil), scale=(0.9, 1), thick=0.3, sink=0.5, seg=16, name="pupil")
    parts = [dome, pupil_ob]
    for u, v, s in ((-0.24, 0.28, 0.28), (0.24, -0.3, 0.12)):
        parts.append(k.lens(pupil_ob, p + (x * u + y * v) * r, n, r * s, k.flat(k.SNOW), thick=0.3, sink=0.4, seg=8, name="catchlight"))
    return parts


# Shadow wisp -----------------------------------------------------------------------------------


def shadow_wisp():
    """A soft round puff of deep indigo (never black), lumpy like a small cloud, with a wispy tail
    curling down behind, and two big round glowing amber eyes with catchlights. No mouth, no teeth.
    Paler lilac on top so it reads against the dusk sky; up to 40 on screen, so it is cheap."""
    c = Vector((0, 0, 1.25))
    puff = k.fuse(
        [
            (c, 0.95, (1.05, 0.95, 0.95)),
            ((0.42, 0.08, 1.88), 0.46), ((-0.4, 0.12, 1.92), 0.5), ((0.02, 0.32, 2.08), 0.42),  # crown lumps
            ((0.86, 0.1, 1.22), 0.42), ((-0.86, 0.06, 1.3), 0.4),  # cheeks
            ("capsule", (0.0, 0.4, 0.75), (0.22, 0.75, 0.42), 0.34),  # the wispy tail, curling down and back
            ("capsule", (0.22, 0.75, 0.42), (0.52, 0.86, 0.2), 0.2),
            ("capsule", (0.52, 0.86, 0.2), (0.78, 0.8, 0.12), 0.1),
        ],
        k.flat((70, 58, 140)),
        tris=1000,
        soft=0.35,
        name="puff",
    )
    k.texel(puff, k.FACE_TEXEL, c + Vector((0, -0.95, 0)), 0.8)
    glow = k.flat((255, 186, 84), emit=1.0)
    eyes = []
    for side in (-1, 1):
        d = k.outward(side * 26, 16)
        r = 0.32
        dome = k.lens(puff, c, d, r, glow, scale=(0.84, 1.08), thick=0.5, sink=0.45, seg=16, name="eye")
        p, n = k.land(puff, c, d)
        x, y, _ = k._frame(n)
        eyes += [dome, k.lens(dome, p + (x * -0.32 + y * 0.4) * r, n, r * 0.3, k.flat(k.SNOW), thick=0.3, sink=0.4, seg=8, name="catchlight"),
                 k.lens(dome, p + (x * 0.28 - y * 0.38) * r, n, r * 0.13, k.flat(k.SNOW), thick=0.3, sink=0.4, seg=8, name="catchlight")]
    parts = [puff, *k.texel(eyes, k.FACE_TEXEL)]
    m = fit(parts, [2.5, 2.5, 2.5])
    lo, hi = zspan(puff)
    rim = [((150, 132, 214), m @ Vector(p), 0, r * m.to_scale().x) for p, r in (((0.42, 0.08, 2.2), 0.36), ((-0.4, 0.12, 2.28), 0.38), ((0.02, 0.32, 2.4), 0.3))]
    swap(puff, k.paint("sw_puff", [(0, (40, 34, 92)), (0.35, (62, 50, 128)), (0.75, (88, 72, 160)), (1, (132, 114, 200))], lo, hi, marks=rim))
    for ob in eyes:
        if ob.name.startswith("eye"):
            elo, ehi = zspan(ob)
            swap(ob, k.paint("sw_eye", [(0, (255, 140, 50)), (0.6, (255, 176, 76)), (1, (255, 204, 120))], elo, ehi, emit=1.0))
    return parts


# The Lampeater ---------------------------------------------------------------------------------
# Built at a quarter of its size (the fuse resolution stays light) and fitted to section 9. Its
# thorax sits at the body's bounding-box centre and the wing roots at their boxes' centre on y,
# so wings placed beside the body by bounding box meet it at the shoulders.

CREAM = (250, 236, 210)
FLUFF = (226, 206, 236)


def lampeater_body():
    """A big soft majestic moth (the Garden Lantern Moth's family): a fluffy lilac-cream body with
    a cream ruff, a round head with huge round lantern-glass eyes (amber, catchlights), blush and a
    small content mouth, two feathery antennae swept up and back, six tucked fluffy legs, a plump
    abdomen with a cream tuft at its tip. No mandibles, fangs, stingers or claws."""
    head, R = Vector((0, -1.32, 0.05)), 0.62
    body = k.fuse(
        [
            (head, R, (1.1, 0.95, 1.0)),
            ((0, -0.1, 0.05), 0.64, (1.05, 1.0, 1.0)),  # big fluffy thorax, at the box centre
            ((0, 0.9, -0.02), 0.62, (1.0, 1.6, 0.95)),  # one plump furry abdomen...
            ((0, 1.72, -0.08), 0.3, (1.0, 1.0, 0.9)),  # ...rounding off to a soft tip
            *[((s * 0.34, y, -0.5), 0.12, (1.0, 1.0, 1.4)) for y in (-0.42, -0.1, 0.22) for s in (-1, 1)],  # tucked fluffy legs
        ],
        k.flat(FLUFF),
        tris=3700,
        name="body",
    )
    # The cream ruff: a solid collar between head and thorax, scalloped with soft lumps.
    ruff = k.fuse(
        [((0, -0.74, 0.05), 0.66, (1.1, 0.42, 1.05))]
        + [((0.66 * math.cos(a), -0.74 + 0.06 * math.sin(3 * a), 0.05 + 0.66 * math.sin(a)), 0.2) for a in (math.radians(360 * i / 14) for i in range(14))],
        k.flat(CREAM),
        tris=1100,
        soft=0.4,
        name="ruff",
    )
    parts = [body, ruff]
    # Feathery antennae: a quill and a striped plume each, swept up, out and back.
    plumes = []
    for s in (-1, 1):
        root = head + Vector((s * 0.22, 0.0, 0.5))
        plume = k.leaf(0.72, 0.2, k.flat((236, 210, 160)), droop=-0.05, n=8, steps=12, name="plume")
        plume.data.transform(Matrix.Translation((0.16, 0, 0)))
        quill = k.tube([(-0.05, -0.02, 0), (0.45, -0.02, 0), (0.9, -0.02, 0)], [0.03, 0.022, 0.008], m=k.flat((150, 112, 96)), n=6, name="quill")
        xf([plume, quill], root, yaw=30, pitch=38, roll=90, mirror=s < 0)
        parts += [plume, quill]
        plumes.append(plume)
    # The face: huge round lantern-glass eyes, blush, a small "w".
    k.texel(body, k.FACE_TEXEL, head + Vector((0, -R, 0)), R)
    glass = k.flat((255, 176, 64), emit=0.9)
    face = []
    for side in (-1, 1):
        face += glass_eye(body, head, k.outward(side * 34, 6), R * 0.34, glass)
        face.append(k.lens(body, head, k.outward(side * 56, -24), R * 0.17, k.flat(k.mix(FLUFF, k.BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
    face.append(k.mouth(body, head, k.outward(0, -24), R * 0.13, k.flat(k.INKY), "w"))
    parts += k.texel(face, k.FACE_TEXEL)

    m = fit(parts, [6, 6, 16])
    s = sum(m.to_scale()) / 3
    lo, hi = zspan(body)
    swap(body, k.paint("le_body", [(0, (170, 146, 206)), (0.4, (206, 186, 234)), (1, (240, 228, 252))], lo, hi, marks=[((252, 240, 228), m @ Vector((0, 1.85, -0.08)), 0, 0.36 * s)]))
    lo, hi = zspan(ruff)
    swap(ruff, k.paint("le_ruff", [(0, (226, 206, 186)), (1, (255, 246, 228))], lo, hi))
    for plume in plumes:
        lo, hi = zspan(plume)
        swap(plume, k.paint("le_plume", [(0, (214, 176, 126)), (1, (246, 222, 172))], lo, hi, bands=((222, 186, 136), 0.24)))
    for ob in face:
        if ob.name.startswith("eye"):
            elo, ehi = zspan(ob)
            swap(ob, k.paint("le_eye", [(0, (255, 140, 48)), (0.55, (255, 180, 72)), (1, (255, 206, 120))], elo, ehi, emit=0.9))
    return parts


# Wing outline in studs (x out from the hinge, y forward negative), hinge front to hinge back: a long
# forewing to a round apex, a soft notch, a round hindwing fan behind.
WING = [(0, -3.2), (2.5, -4.6), (6.5, -5.6), (11, -6.0), (15, -5.85), (17.4, -4.8), (18, -3.0), (17.2, -1.0), (15.2, 0.6), (13.2, 1.5),
        (12.6, 2.7), (11.8, 4.4), (10.0, 5.7), (7.5, 6.0), (4.8, 5.4), (2.3, 4.2), (0, 2.8)]


def pillow(outline, root, thick, steps=4, rings=7):
    """A soft plush slab: the outline (open, both ends on the hinge line) fanned from `root`, a top
    and a bottom surface `thick` thick at the root with an elliptical edge (round, never sharp),
    closed along the hinge by two side strips."""
    pts = [Vector((x, y, 0)) for x, y in outline]
    pts = [2 * pts[0] - pts[1]] + pts + [2 * pts[-1] - pts[-2]]
    rim = []
    for i in range(1, len(pts) - 2):  # Catmull-Rom through the outline
        a, b, c, d = pts[i - 1 : i + 3]
        for j in range(steps):
            u = j / steps
            rim.append(0.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (3 * b - a - 3 * c + d) * u ** 3))
    rim.append(pts[-2])
    root = Vector((root[0], root[1], 0))
    vs = [math.sin(math.pi / 2 * j / rings) for j in range(rings + 1)]  # rings bunch towards the edge
    bm = bmesh.new()
    top_pole, bot_pole = bm.verts.new(root + Vector((0, 0, thick))), bm.verts.new(root - Vector((0, 0, thick)))
    top, bot = [], []
    for p in rim:
        t_row, b_row = [top_pole], [bot_pole]
        for v in vs[1:-1]:
            q = root + (p - root) * v
            h = thick * math.sqrt(1 - v * v)
            t_row.append(bm.verts.new(q + Vector((0, 0, h))))
            b_row.append(bm.verts.new(q - Vector((0, 0, h))))
        edge = bm.verts.new(p)
        top.append(t_row + [edge])
        bot.append(b_row + [edge])
    for i in range(len(rim) - 1):
        for rows in (top, bot):
            a, b = rows[i], rows[i + 1]
            bm.faces.new((a[0], a[1], b[1]))
            for j in range(1, rings):
                bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
    for i in (0, len(rim) - 1):  # close the hinge side
        for j in range(rings):
            quad = [top[i][j], top[i][j + 1], bot[i][j + 1], bot[i][j]]
            if len(set(quad)) == 4:
                bm.faces.new(quad)
            elif len(set(quad)) == 3:
                bm.faces.new(list(dict.fromkeys(quad)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return k._obj("wing", bm, k.flat((180, 150, 230)))


def lampeater_wing(side):
    """One soft wing (+1 the moth's left, Blender +X; -1 its right): a plush slab in a moth's
    outline (a long forewing to a round apex, a round hindwing behind), thickest at the root with
    round edges and a gentle upward curve to the tip; a dusk gradient from violet at the root to
    pale lilac at the tips, and big lantern-amber eye-spots on both faces. The hinge is the inner
    edge (the box's inner face); the root sits at the box's centre on y."""
    wing = pillow(WING, (0, -0.2), 0.36)

    def lift(x):  # a gentle upward curve to the tip
        return 1.1 * (max(x, 0) / 18) ** 1.8

    for v in wing.data.vertices:
        v.co.z += lift(v.co.x)
    k.texel(wing, 0.8)
    spots = [(Vector((11.6, -2.7, lift(11.6))), 2.5), (Vector((8.2, 3.1, lift(8.2))), 1.6)]
    if side < 0:
        wing.data.transform(Matrix.Diagonal((-1, 1, 1, 1)))
        wing.data.flip_normals()
        spots = [(Vector((-p.x, p.y, p.z)), r) for p, r in spots]
    m = fit([wing], [18, 1.5, 12])
    marks = []
    for p, r in spots:
        q = m @ p
        marks += [((255, 190, 92), q, 0, r), ((92, 52, 146), q, 0, r * 0.84), ((255, 168, 56), q, 0, r * 0.72), ((255, 214, 130), q, 0, r * 0.5),
                  ((74, 42, 108), q, 0, r * 0.3), ((255, 248, 236), q + Vector((-0.12 * r * side, -0.12 * r, 0.3)), 0, r * 0.16)]
    root_x, tip_x = (m @ Vector((0, 0, 0))).x, (m @ Vector((18 * side, 0, 0))).x
    lo, hi = min(root_x, tip_x), max(root_x, tip_x)
    ramp = [(0, (104, 74, 180)), (0.45, (164, 128, 226)), (1, (232, 212, 252))]
    if side < 0:
        ramp = [(1 - t, c) for t, c in reversed(ramp)]
    swap(wing, k.paint(f"le_wing_{'l' if side > 0 else 'r'}", ramp, lo, hi, axis="X", marks=marks))
    return [wing]


NOTE_WING = ("The moth's {which} wing (Blender {bx}; it mirrors lampeater_wing_{other}). Flapped by code about its inner edge: the hinge is the bounding-box face nearest "
             "the body. Placed by bounding box at the body's centre height and depth, offset (body width + wing width) / 2 to the moth's {which}, where its root "
             "meets the thorax. Eye-spots on both faces (players look up at it).")
ASSETS = [
    dict(name="shadow_wisp", build=shadow_wisp, budget=1500, finalize=k.HD, size=[2.5, 2.5, 2.5], priority=1, order=40,
         replaces="wisp fallback (dark ball with two white dots)", glow={},
         notes="One mesh, 2.5 studs, front -Y; eyes baked bright (no Neon). Drifts, wobbles, swells and pops by code. Up to 40 on screen."),
    dict(name="lampeater_body", build=lampeater_body, budget=7000, finalize=k.HD, size=[6, 6, 16], priority=1, order=41,
         replaces="Lampeater fallback (block body)", glow={},
         notes="One mesh, front -Y (head forward), thorax at the bounding-box centre where the wings meet it. Lantern-glass eyes baked bright; "
               "code may hang a warm PointLight in front of the face. Swoops by code."),
    dict(name="lampeater_wing_l", build=lambda: lampeater_wing(1), budget=2500, finalize=k.HD, size=[18, 1.5, 12], priority=1, order=42,
         replaces="Lampeater fallback (wedge part)", glow={},
         notes=NOTE_WING.format(which="left", bx="+X", other="r")),
    dict(name="lampeater_wing_r", build=lambda: lampeater_wing(-1), budget=2500, finalize=k.HD, size=[18, 1.5, 12], priority=1, order=43,
         replaces="Lampeater fallback (wedge part)", glow={},
         notes=NOTE_WING.format(which="right", bx="-X", other="l")),
]
