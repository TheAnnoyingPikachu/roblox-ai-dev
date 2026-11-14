"""The Hexbound (decision 0040): evil magic knights, ogres and dragons, the enemies of the waves.

Corners are cut on purpose. There are three models, one per kind (a tier within a kind is a tint
and a size in game). The knight is haunted armour whose pieces float apart, so there is no skin to
join and no joint to hide. The ogre is the animals' fused-blob style. The dragon is the animals'
predator body with wings and horns. All three use the animals' rig names so the same pieces
animate: a biped's arms are the "front legs" (leg_fl left, leg_fr right), its legs the "back
legs" (leg_bl, leg_br) and its cape or loincloth the "tail"; the dragon adds wing_l and wing_r.
Facing Blender -Y; left is +X. Every enemy glows hexfire green, so friend and foe read at a glance.
"""

import importlib.util
import math
import os
import random

import bmesh
import bpy
import kit as k
from mathutils import Vector

# the animals' helpers (shard, leg, eyes, ring, predator): animals.py is a sibling file
_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("stations_animals", os.path.join(_here, "animals.py"))
animals = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(animals)
shard, ring = animals.shard, animals.ring

HEX = (150, 255, 70)
BONE = (214, 200, 172)


def ragged(width, drop, teeth, depth, loc, m, rot=(0, 0, 0), flare=0.0, name="cloth"):
    """A hanging strip of cloth with a ragged hem, in the x/z plane, `depth` thick."""
    top, hem = width / 2, width / 2 * (1 + flare)
    pts = [(-top, 0), (top, 0)]
    for i in range(teeth + 1):  # the hem, from right to left, every other point higher
        pts.append((hem - 2 * hem * i / teeth, -drop * (0.62 if i % 2 else 1.0)))
    return k.poly(pts, depth, loc=loc, rot=rot, m=m, name=name)


def membrane(panels, m, sag=0.3, thick=0.05):
    """Panels of wing skin, each (apex, a, b, scallop): two triangles from the apex to the edge a-b,
    whose middle is pulled in towards the apex by `scallop` (0 = straight) and droops a little.
    Thin but solid, so they show from both sides."""
    bm = bmesh.new()
    for apex, a, b, scallop in panels:
        edge = (a + b) / 2
        mid = edge + (apex - edge) * scallop - Vector((0, 0, sag))
        va, vb, vp, vm = (bm.verts.new(p) for p in (a, b, apex, mid))
        for tri in ((vp, va, vm), (vp, vm, vb)):
            bm.faces.new(tri)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
    return k._obj("membrane", bm, m)


# Knight ---------------------------------------------------------------------------------------------

KNIGHT_JOINTS = {
    "head": (0, 0, 3.2),
    "leg_fl": (0.92, 0, 3.0),
    "leg_fr": (-0.92, 0, 3.0),
    "leg_bl": (0.3, 0, 1.55),
    "leg_br": (-0.3, 0, 1.55),
    "tail": (0, 0.5, 3.05),
}


def knight():
    """Haunted plate armour: a barrel chest, a great helm with horns and angry slits, spiked
    pauldrons, a sword in the right hand and a kite shield on the left arm, a ragged cape. The
    helm and the gauntlets float clear of the rest; hexfire shows in the gaps."""
    steel = k.flat((40, 36, 56))
    dark = k.flat((22, 20, 32))
    trim = k.flat((108, 98, 136))
    bone = k.flat(BONE)
    cloth = k.flat((74, 26, 82))
    glow = k.glow(HEX)
    g = {n: [] for n in ("body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "body_glow", "head_glow", "leg_fl_glow", "leg_fr_glow")}

    # the body: pelvis, three lames, a bell of a chest with a keel, a gorget, spikes down the back
    b = g["body"]
    b.append(k.box((0.8, 0.5, 0.36), (0, 0, 1.62), m=steel, bevel=0.07, name="pelvis"))
    for i, (w, z) in enumerate(((0.86, 1.9), (0.94, 2.06), (1.02, 2.22))):
        b.append(k.box((w, 0.54 + 0.02 * i, 0.17), (0, 0, z), m=trim if i == 1 else steel, bevel=0.05, name="lame"))
    b.append(k.lathe([(0.46, 0.0), (0.6, 0.2), (0.8, 0.52), (0.76, 0.76), (0.5, 0.9), (0.4, 0.96)], loc=(0, 0, 2.28), m=steel, n=14, scale=(1.0, 0.74, 1.0), name="cuirass"))
    b.append(k.box((0.14, 0.2, 0.9), (0, -0.52, 2.7), m=trim, bevel=0.05, name="keel"))
    b.append(k.cyl(0.36, 0.22, (0, 0, 3.14), m=dark, n=12, bevel=0.03, name="gorget"))
    for i in range(4):
        z = 2.35 + 0.28 * i
        b.append(shard((0, 0.42, z), (0, 0.8 - 0.05 * i, z + 0.34), 0.11, steel))
    b.append(k.sphere(0.13, (0, -0.31, 1.82), m=bone, scale=(1.0, 0.8, 1.1), seg=10, rings=6, name="belt_skull"))
    b.append(ragged(0.7, 0.62, 6, 0.05, (0, -0.3, 1.5), cloth, name="tabard"))
    b.append(ragged(0.7, 0.7, 6, 0.05, (0, 0.3, 1.5), cloth, name="tabard_back"))
    g["body_glow"].append(k.poly([(0, 0.3), (0.2, 0), (0, -0.3), (-0.2, 0)], 0.05, loc=(0, -0.57, 2.72), m=glow, name="rune"))
    g["body_glow"].append(k.box((0.9, 0.04, 0.05), (0, -0.28, 2.0), m=glow, name="belt_line"))

    # the head floats above the gorget with hexfire between: a great helm, a brow, a mouth
    # grille, swept horns and a crest
    hz = 3.38
    h = g["head"]
    h.append(k.lathe([(0.32, 0.0), (0.4, 0.1), (0.43, 0.42), (0.37, 0.66), (0.19, 0.78), (0.0, 0.8)], loc=(0, 0, hz), m=steel, n=14, scale=(1.0, 1.12, 1.0), name="helm"))
    h.append(k.box((0.74, 0.12, 0.1), (0, -0.46, hz + 0.34), rot=(-8, 0, 0), m=trim, bevel=0.03, name="brow"))
    for x in (-0.12, 0, 0.12):
        h.append(k.box((0.05, 0.06, 0.2), (x, -0.47, hz + 0.15), m=dark, name="bar"))
    for s in (1, -1):
        h.append(k.horn([(s * 0.38, 0.0, hz + 0.4), (s * 0.66, -0.05, hz + 0.6), (s * 0.8, -0.22, hz + 1.0), (s * 0.66, -0.4, hz + 1.32)], [0.11, 0.09, 0.055, 0.0], bone, n=8, steps=10, name="horn"))
        g["head_glow"].append(k.box((0.2, 0.05, 0.06), (s * 0.15, -0.46, hz + 0.25), rot=(0, -s * 22, 0), m=glow, name="eye"))
    for y, tall in ((-0.2, 0.34), (0.0, 0.42), (0.2, 0.3)):
        h.append(shard((0, y, hz + 0.64), (0, y + 0.1, hz + 0.64 + tall), 0.09, steel))
    g["head_glow"].append(k.cyl(0.18, 0.3, (0, 0, 3.2), m=glow, n=8, name="neck_core"))

    # the arms: pauldron, upper arm, elbow with a back spike, vambrace, a floating gauntlet and a
    # glowing core in the gap between them
    for s, part in ((1, "leg_fl"), (-1, "leg_fr")):
        a, X = g[part], s * 0.92
        a.append(k.sphere(0.42, (X, 0, 3.0), m=steel, scale=(1.25, 1.0, 0.72), seg=12, rings=8, name="pauldron"))
        a.append(shard((X * 1.05, 0, 3.15), (X * 1.2, 0, 3.8), 0.12, steel))
        a.append(k.cyl(0.14, 0.5, (X, 0, 2.5), m=dark, n=10, name="arm"))
        a.append(k.sphere(0.19, (X * 1.02, 0.02, 2.2), m=steel, seg=10, rings=6, name="elbow"))
        a.append(shard((X * 1.02, 0.1, 2.2), (X * 1.02, 0.55, 2.28), 0.09, steel))
        a.append(k.cyl(0.16, 0.5, (X, -0.03, 1.9), m=steel, n=10, bevel=0.02, name="vambrace"))
        a.append(k.box((0.3, 0.34, 0.32), (X, -0.06, 1.42), m=steel, bevel=0.06, name="gauntlet"))
        g[part + "_glow"].append(k.cyl(0.09, 0.14, (X, -0.04, 1.61), m=glow, n=8, name="wrist_core"))
        if s == -1:  # the sword: grip, crossguard, pommel, a blade with hexfire runes
            hy = -0.06
            a.append(k.box((0.08, 0.5, 0.08), (X, hy, 1.42), m=dark, name="grip"))
            a.append(k.box((0.1, 0.12, 0.64), (X, hy - 0.28, 1.42), m=trim, bevel=0.03, name="crossguard"))
            a.append(k.sphere(0.1, (X, hy + 0.27, 1.42), m=trim, seg=8, rings=6, name="pommel"))
            a.append(k.poly([(-0.13, 0), (0.13, 0), (0.13, 1.7), (0, 2.1), (-0.13, 1.7)], 0.07, loc=(X, hy - 0.34, 1.42), rot=(90, 90, 0), m=steel, name="blade"))
            for i in range(3):
                g[part + "_glow"].append(k.box((0.1, 0.16, 0.1), (X, hy - 0.8 - 0.4 * i, 1.42), m=glow, name="rune"))
        else:  # the shield: a kite of plate with a trim behind it, a boss and a hexfire sigil
            kite = [(-0.46, 0.75), (0.46, 0.75), (0.5, 0.15), (0, -0.95), (-0.5, 0.15)]
            wide = [(x * 1.14, z * 1.1 - 0.02) for x, z in kite]
            a.append(k.poly(kite, 0.1, loc=(X + 0.18, -0.26, 1.95), m=steel, bevel=0.02, name="shield"))
            a.append(k.poly(wide, 0.06, loc=(X + 0.18, -0.2, 1.95), m=trim, name="shield_rim"))
            a.append(k.sphere(0.14, (X + 0.18, -0.34, 2.25), m=trim, seg=8, rings=6, name="boss"))
            g[part + "_glow"].append(k.poly([(0, 0.42), (0.2, 0.05), (0, -0.55), (-0.2, 0.05)], 0.04, loc=(X + 0.18, -0.33, 1.9), m=glow, name="sigil"))

    # the legs: tasset, thigh, knee with a spike, greave, sabaton
    for s, part in ((1, "leg_bl"), (-1, "leg_br")):
        leg, X = g[part], s * 0.3
        leg.append(k.box((0.38, 0.36, 0.4), (X, -0.02, 1.5), m=steel, bevel=0.06, name="tasset"))
        leg.append(k.cyl(0.16, 0.66, (X, 0, 1.0), m=dark, n=10, name="thigh"))
        leg.append(k.sphere(0.2, (X, -0.1, 0.62), m=steel, seg=10, rings=6, name="knee"))
        leg.append(shard((X, -0.24, 0.62), (X, -0.62, 0.7), 0.1, steel))
        leg.append(k.cyl(0.15, 0.5, (X, 0, 0.34), m=steel, n=10, bevel=0.02, name="greave"))
        leg.append(k.box((0.28, 0.58, 0.18), (X, -0.14, 0.09), m=steel, bevel=0.05, name="sabaton"))

    g["tail"].append(ragged(1.2, 1.9, 8, 0.05, (0, 0.5, 3.05), cloth, rot=(8, 0, 0), flare=0.3, name="cape"))
    return g, KNIGHT_JOINTS


# Ogre -----------------------------------------------------------------------------------------------

OGRE_JOINTS = {
    "head": (0, -0.5, 3.8),
    "leg_fl": (1.2, -0.4, 3.6),
    "leg_fr": (-1.2, -0.4, 3.6),
    "leg_bl": (0.58, 0.1, 1.55),
    "leg_br": (-0.58, 0.1, 1.55),
    "tail": (0, 0.9, 2.0),
}


def ogre():
    """A hunched green brute: a big belly, long arms, short legs, tusks and brow horns, an iron
    collar and a belt, a spiked club in the right hand. Hexfire shows as cracks across the skin,
    in the eyes, on the collar and as nails in the club."""
    skin = k.paint("og_skin", [(0, (58, 74, 56)), (0.5, (94, 114, 84)), (1, (122, 140, 100))], 0, 5.0, rest=True, grain=(0.18, 6))
    iron = k.flat((30, 28, 36))
    bone = k.flat(BONE)
    wood = k.flat((70, 48, 34))
    hide = k.flat((88, 54, 42))
    glow = k.glow(HEX)
    rng = random.Random(3)
    g = {n: [] for n in ("body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "body_glow", "head_glow", "leg_fr_glow")}

    torso = k.fuse(
        [
            ((0, 0.3, 1.8), 0.85, (1.05, 1.0, 0.9)),
            ((0, -0.1, 2.5), 1.22, (1.1, 1.0, 1.0)),
            ((0, -0.4, 3.25), 1.1, (1.28, 0.95, 0.88)),
            ((0, -0.5, 3.8), 0.62, (1.5, 1.0, 0.7)),
            ((0, 0.55, 3.55), 0.72, (1.0, 0.8, 0.8)),
            *k.pair((1.0, -0.45, 3.65), 0.55, (0.9, 1.0, 0.9)),
        ],
        skin,
        tris=2400,
        soft=0.25,
        name="torso",
    )
    k.zone(skin, (128, 152, 108), (0, -1.1, 2.4), (0.9, 0.5, 0.9), soft=0.5)  # a paler belly
    b = g["body"]
    b.append(torso)
    b.append(ring((0, 0.0, 2.0), (0, 0, 1), 1.12, 0.1, iron, "belt"))
    b.append(k.sphere(0.18, (0, -1.14, 2.0), m=bone, scale=(1.0, 0.7, 1.1), seg=10, rings=6, name="buckle"))
    b.append(ring((0, -0.6, 3.85), (0, 0, 1), 0.74, 0.1, iron, "collar"))
    b.append(ragged(1.2, 1.0, 6, 0.06, (0, -1.08, 1.95), hide, name="loincloth"))
    for a in (-70, -35, 0, 35, 70):  # runes round the collar
        g["body_glow"].append(k.box((0.12, 0.12, 0.12), (0.74 * math.sin(math.radians(a)), -0.6 - 0.74 * math.cos(math.radians(a)), 3.85), m=glow, name="collar_rune"))
    for side in (-1, 1):  # cracks of hexfire across the skin
        for z0 in (1.9, 2.5, 3.1, 3.7):
            pts, z = [], z0
            for step in range(6):
                z += rng.uniform(-0.2, 0.2)
                a = side * (8 + 13 * step + rng.uniform(-5, 5))
                pts.append(((0, -0.2, z), k.outward(a, 0)))
            try:
                g["body_glow"].append(k.vein(torso, pts, 0.05, glow))
            except ValueError:
                pass

    hc = Vector((0, -0.95, 4.3))
    skull = k.fuse(
        [
            (tuple(hc), 0.52, (1.0, 1.1, 0.92)),
            ("capsule", (0, -0.5, 3.8), tuple(hc), 0.46),
            ((0, -1.25, 4.02), 0.44, (1.12, 1.05, 0.75)),
            *k.pair((0.28, -1.3, 4.5), 0.22, (1.0, 1.5, 0.5), (20, 0, 0)),
            ((0, -1.55, 4.2), 0.2),
            *k.pair((0.56, -0.85, 4.45), 0.2, (0.5, 0.4, 1.4), (-20, 20, 0)),
        ],
        skin,
        tris=1500,
        soft=0.25,
        name="skull",
    )
    face, glows = animals.eyes(skull, skin, hc, 42, 10, 0.1, HEX, (24, 30, 22), True)
    h = g["head"]
    h += [skull, *face]
    for s in (1, -1):
        h.append(k.horn([(s * 0.3, -1.45, 3.95), (s * 0.36, -1.72, 4.25), (s * 0.3, -1.78, 4.7)], [0.11, 0.085, 0.0], bone, n=8, steps=8, name="tusk"))
        h.append(k.horn([(s * 0.36, -1.0, 4.72), (s * 0.62, -0.95, 5.0), (s * 0.72, -0.85, 5.35)], [0.11, 0.08, 0.0], iron, n=8, steps=8, name="horn"))
    g["head_glow"] += glows

    for s, part in ((1, "leg_fl"), (-1, "leg_fr")):
        arm = k.fuse(
            [
                ("capsule", (s * 1.2, -0.4, 3.6), (s * 1.55, -0.3, 2.45), 0.38),
                ("capsule", (s * 1.55, -0.3, 2.45), (s * 1.5, -0.8, 1.4), 0.33),
                ((s * 1.55, -0.55, 1.95), 0.4),
                ((s * 1.5, -0.85, 1.05), 0.46, (1.0, 1.0, 0.95)),
            ],
            skin,
            tris=800,
            soft=0.25,
            name=part,
        )
        parts = g[part]
        parts += [arm, ring((s * 1.5, -0.7, 1.55), (0, -0.4, 1), 0.42, 0.07, iron, "bracer")]
        for dx in (-0.2, 0, 0.2):
            parts.append(shard((s * 1.5 + dx, -1.2, 1.1), (s * 1.5 + dx, -1.5, 1.14), 0.07, bone))
        if s == -1:  # the club: a haft, a fat head with iron spikes and hexfire nails
            club = Vector((-1.85, -1.75, 3.3))
            parts.append(k.horn([(-1.5, -0.75, 0.7), (-1.6, -1.15, 1.6), (-1.75, -1.4, 2.4), tuple(club)], [0.13, 0.15, 0.2, 0.5], wood, n=10, steps=12, name="club"))
            for i in range(12):
                zz = 1 - 2 * (i + 0.5) / 12
                rr, phi = math.sqrt(1 - zz * zz), i * 2.399
                d = Vector((rr * math.cos(phi), rr * math.sin(phi), zz))
                if i % 2:
                    g["leg_fr_glow"].append(shard(club + d * 0.4, club + d * 0.85, 0.1, glow))
                else:
                    parts.append(shard(club + d * 0.4, club + d * 1.0, 0.13, iron))

    for s, part in ((1, "leg_bl"), (-1, "leg_br")):
        g[part] += animals.leg(skin, s * 0.58, 0.05, 1.6, 0.4, 0.34, 0.42, k.flat(BONE), part, (50, 62, 46))

    g["tail"].append(ragged(1.3, 1.1, 7, 0.06, (0, 0.95, 1.95), hide, rot=(6, 0, 0), name="pelt"))
    return g, OGRE_JOINTS


# Dragon ---------------------------------------------------------------------------------------------

DRAGON = dict(chest_z=2.5, chest_r=1.4, waist_r=1.1, hip_r=1.25, len=3.0, leg_r=0.45, foot_r=0.55, head_r=0.8, neck=1.9, head_up=1.2, neck_r=0.6, snout=1.0, ears="point", ear=0.35, muzzle=1.15, tail_len=1.0, tail_r=0.5)


def wing(s, skin_m, bone_m, glow_m):
    """One wing, off the shoulder at (0.8, 0.3, 3.8): an arm to the wrist, four fingers fanned
    out, scalloped skin between them, hexfire along the fingers. Returns (pieces, glowing pieces)."""
    S, E, W = Vector((s * 0.8, 0.3, 3.8)), Vector((s * 2.6, -0.1, 5.1)), Vector((s * 4.5, 0.6, 5.9))
    tips = [Vector((s * 7.6, -1.4, 5.3)), Vector((s * 7.3, 1.5, 3.9)), Vector((s * 5.6, 3.1, 3.0)), Vector((s * 2.0, 3.4, 3.3))]
    pieces = [k.horn([S, E, W], [0.3, 0.24, 0.16], bone_m, n=8, steps=8, name="wing_arm")]
    glows = []
    for tp in tips:
        mid = W.lerp(tp, 0.5)
        pieces.append(k.horn([W, mid + Vector((0, 0, 0.12)), tp], [0.13, 0.09, 0.0], bone_m, n=6, steps=6, name="finger"))
        glows.append(k.horn([W + Vector((0, 0, 0.1)), mid + Vector((0, 0, 0.22)), tp + Vector((0, 0, 0.05))], [0.05, 0.04, 0.0], glow_m, n=5, steps=6, name="vein"))
    pieces.append(membrane([(W, tips[0], tips[1], 0.28), (W, tips[1], tips[2], 0.28), (W, tips[2], tips[3], 0.28), (S, W, tips[3], 0.0)], skin_m))
    pieces.append(shard(W, W + Vector((s * 0.6, -0.9, 0.5)), 0.16, bone_m))
    return pieces, glows


def dragon():
    """A winged dragon on the animals' predator body: a thick neck, a horned head with glowing
    eyes, a spine of spikes, a long tail with a spade, and two bat wings veined with hexfire."""
    skin = k.paint("dr_scale", [(0, (26, 22, 40)), (0.5, (44, 36, 66)), (1, (66, 54, 92))], 0, 5.0, rest=True, grain=(0.16, 7), dots=[((18, 14, 28), 8.0, 0.2)])
    bone, glow = k.flat(BONE), k.glow(HEX)
    c = dict(DRAGON)
    c.update(skin=skin, iris=HEX, socket=(10, 8, 16), glow_eyes=True, claw=BONE, head_extra=[((0, -1.57, 3.45), 0.66), ((0, -2.24, 3.87), 0.64)])
    g, torso, skull, hc = animals.predator(c)
    g["body_glow"] = []
    for o in g["tail"]:  # the predator's short tail is replaced by a long one
        bpy.data.objects.remove(o, do_unlink=True)
    t0 = Vector(c["joints"]["tail"])
    pts = [t0, t0 + Vector((0, 1.7, -0.15)), t0 + Vector((0, 3.6, -0.5)), t0 + Vector((0, 5.6, -0.6)), t0 + Vector((0, 7.2, -0.2))]
    g["tail"] = [k.rest(k.horn(pts, [0.5, 0.4, 0.3, 0.2, 0.05], skin, n=10, steps=14, name="tail"))]
    end = pts[-1]
    for dx, dy in ((-0.5, 0.2), (0, 0.5), (0.5, 0.2)):  # a spade of spikes at the tip
        g["tail"].append(shard(end - Vector((0, 0.6, 0)), end + Vector((dx, dy + 0.6, 0.1)), 0.14, bone))
    for i in range(7):  # a spine of spikes along the back, every other one hexfire
        y = -0.3 + 0.55 * i
        p, _ = k.land(torso, (0, y, 2.5), (0, 0, 1))
        lean = Vector((0, 0.45, 1)).normalized()
        tall = 0.5 + 0.35 * math.sin(math.pi * (i + 1) / 8)
        piece = shard(p - lean * 0.2, p + lean * tall, 0.13 + tall * 0.1, glow if i % 2 else bone)
        (g["body_glow"] if i % 2 else g["body"]).append(piece)
    R, snout = c["head_r"], c["snout"]
    tip = hc + Vector((0, -R * 0.75 - snout, -R * 0.2))
    g["head"].append(shard(tip + Vector((0, 0.25, 0.25)), tip + Vector((0, -0.15, 0.7)), 0.13, bone))
    for s in (1, -1):
        g["head"].append(k.horn([(s * 0.32, hc.y + 0.25, hc.z + 0.5), (s * 0.5, hc.y + 1.0, hc.z + 1.0), (s * 0.5, hc.y + 1.9, hc.z + 1.05)], [0.16, 0.12, 0.0], bone, n=8, steps=10, name="horn"))
        g["head"].append(k.horn([(s * 0.5, hc.y + 0.1, hc.z - 0.2), (s * 0.85, hc.y + 0.5, hc.z - 0.1), (s * 1.0, hc.y + 0.9, hc.z + 0.2)], [0.12, 0.08, 0.0], bone, n=6, steps=6, name="jaw_horn"))
        pieces, veins = wing(s, k.flat((74, 36, 100)), bone, glow)
        name = "wing_l" if s == 1 else "wing_r"
        g[name], g[name + "_glow"] = pieces, veins
    joints = dict(c["joints"])
    joints["wing_l"], joints["wing_r"] = (0.8, 0.3, 3.8), (-0.8, 0.3, 3.8)
    return g, joints


# Assets ---------------------------------------------------------------------------------------------


def asset(name, maker, scale, glow, note, budget):
    joints = {}

    def build():
        groups, j = maker()
        joints.update(j)
        return groups

    return dict(name=name, build=build, scale=scale, budget=budget, finalize=k.HD, joints=joints, glow=glow, notes=note)


ASSETS = [
    asset("foe_knight", knight, 1.6, {"body_glow": HEX, "head_glow": HEX, "leg_fl_glow": HEX, "leg_fr_glow": HEX}, "Gloom knights: haunted armour with floating pieces; runes, eye slits, shield sigil and sword runes are Neon.", 9000),
    asset("foe_ogre", ogre, 2.5, {"body_glow": HEX, "head_glow": HEX, "leg_fr_glow": HEX}, "Ogres: a hunched brute with a spiked club; cracks, eyes, collar runes and club nails are Neon.", 10000),
    asset("foe_dragon", dragon, 1.6, {"body_glow": HEX, "head_glow": HEX, "wing_l_glow": HEX, "wing_r_glow": HEX}, "Hexfire dragons: the predator body with wings (wing_l, wing_r joints); eyes, wing veins and alternate spine spikes are Neon.", 14000),
]
