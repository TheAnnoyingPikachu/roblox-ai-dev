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


# Archer ---------------------------------------------------------------------------------------------

ARCHER_JOINTS = {
    "head": (0, 0, 3.0),
    "leg_fl": (0.62, 0, 2.78),
    "leg_fr": (-0.62, 0, 2.78),
    "leg_bl": (0.22, 0, 1.45),
    "leg_br": (-0.22, 0, 1.45),
    "tail": (0, 0.4, 2.85),
}


def archer():
    """A hooded bowman: a lean tunic with crossed straps, a hood over a dark void with glowing
    eyes, a long bow of dark wood in the left hand with a hexfire string, an arrow with a hexfire
    head in the right, a quiver of glowing arrows on the back and a ragged cloak."""
    cloth = k.flat((44, 32, 62))
    cloth2 = k.flat((30, 22, 44))
    leather = k.flat((70, 50, 42))
    dark = k.flat((24, 22, 32))
    wood = k.flat((70, 44, 34))
    bone = k.flat(BONE)
    glow = k.glow(HEX)
    g = {n: [] for n in ("body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "body_glow", "head_glow", "leg_fl_glow", "leg_fr_glow")}

    b = g["body"]
    b.append(k.box((0.56, 0.36, 0.3), (0, 0, 1.5), m=leather, bevel=0.06, name="pelvis"))
    b.append(k.lathe([(0.34, 0.0), (0.42, 0.25), (0.5, 0.6), (0.52, 0.85), (0.36, 1.05)], loc=(0, 0, 1.68), m=cloth, n=12, scale=(1.0, 0.7, 1.0), name="tunic"))
    for s in (1, -1):  # crossed straps over the chest
        b.append(k.box((0.09, 0.05, 1.0), (0, -0.36, 2.2), rot=(0, s * 33, 0), m=leather, name="strap"))
    b.append(ring((0, 0, 1.72), (0, 0, 1), 0.46, 0.06, leather, "belt"))
    b.append(k.cyl(0.3, 0.14, (0, 0, 2.86), m=dark, n=10, name="collar"))
    b.append(ragged(0.62, 0.5, 5, 0.04, (0, -0.2, 1.56), cloth2, name="skirt"))
    b.append(k.cyl(0.14, 0.9, (0.2, 0.36, 2.3), rot=(-14, 0, 12), m=leather, n=10, bevel=0.02, name="quiver"))
    for i, dx in enumerate((-0.08, -0.03, 0.03, 0.08, 0.0)):  # five arrows, hexfire fletching
        base = Vector((0.2 + dx, 0.34, 2.55))
        tip = base + Vector((dx * 2 + 0.07, 0.1, 0.55 + 0.05 * i))
        b.append(k.tube([base, tip], [0.022, 0.022], m=bone, n=5, name="arrow"))
        g["body_glow"].append(k.box((0.07, 0.12, 0.07), tuple(tip), m=glow, name="fletch"))

    hz = 3.12  # the hood floats over the collar with hexfire between
    h = g["head"]
    h.append(k.lathe([(0.3, 0.0), (0.38, 0.12), (0.4, 0.4), (0.3, 0.66), (0.12, 0.92), (0.0, 0.98)], loc=(0, 0, hz), m=cloth, n=12, scale=(1.0, 1.1, 1.0), name="hood"))
    h.append(shard((0, 0.12, hz + 0.92), (0, 0.5, hz + 1.0), 0.06, cloth))  # the tip of the hood, bent back
    h.append(k.cyl(0.25, 0.06, (0, -0.42, hz + 0.34), rot=(90, 0, 0), m=dark, n=12, name="void"))
    for s in (1, -1):
        g["head_glow"].append(k.box((0.1, 0.03, 0.04), (s * 0.1, -0.455, hz + 0.38), rot=(0, -s * 22, 0), m=glow, name="eye"))
    g["head_glow"].append(k.cyl(0.14, 0.26, (0, 0, 3.0), m=glow, n=8, name="neck_core"))

    for s, part in ((1, "leg_fl"), (-1, "leg_fr")):
        a, X = g[part], s * 0.62
        a.append(k.sphere(0.2, (X, 0, 2.8), m=leather, scale=(1.2, 1.0, 0.8), seg=10, rings=6, name="shoulder"))
        a.append(k.cyl(0.09, 0.5, (X, 0, 2.45), m=cloth, n=8, name="arm"))
        a.append(k.cyl(0.11, 0.46, (X, -0.02, 1.95), m=dark, n=8, bevel=0.01, name="bracer"))
        a.append(k.box((0.15, 0.17, 0.2), (X, -0.04, 1.6), m=dark, bevel=0.03, name="hand"))
        if s == 1:  # the bow: a recurve of dark wood, a straight hexfire string
            a.append(k.horn([(X, 0.14, 3.1), (X, -0.04, 2.5), (X, -0.12, 1.72), (X, -0.04, 0.95), (X, 0.14, 0.35)], [0.035, 0.05, 0.075, 0.05, 0.035], wood, n=6, steps=12, name="bow"))
            g[part + "_glow"].append(k.tube([(X, 0.14, 3.1), (X, 0.14, 0.35)], [0.018, 0.018], m=glow, n=4, name="string"))
        else:  # an arrow in the right hand, a hexfire head
            hand = Vector((X, -0.1, 1.58))
            a.append(k.tube([hand + Vector((0, 0.3, 0.05)), hand + Vector((0, -0.75, -0.15))], [0.022, 0.022], m=bone, n=5, name="arrow"))
            g[part + "_glow"].append(shard(hand + Vector((0, -0.7, -0.14)), hand + Vector((0, -1.05, -0.2)), 0.07, glow))
            g[part + "_glow"].append(k.box((0.08, 0.16, 0.08), tuple(hand + Vector((0, 0.3, 0.05))), m=glow, name="fletch"))

    for s, part in ((1, "leg_bl"), (-1, "leg_br")):
        leg, X = g[part], s * 0.22
        leg.append(k.cyl(0.12, 0.6, (X, 0, 1.15), m=cloth2, n=8, name="thigh"))
        leg.append(k.sphere(0.13, (X, -0.04, 0.78), m=leather, seg=8, rings=6, name="knee"))
        leg.append(k.cyl(0.11, 0.6, (X, 0, 0.42), r2=0.13, m=leather, n=8, name="boot"))
        leg.append(k.box((0.2, 0.46, 0.14), (X, -0.1, 0.07), m=dark, bevel=0.04, name="sole"))

    g["tail"].append(ragged(0.9, 1.7, 7, 0.04, (0, 0.38, 2.85), cloth2, rot=(8, 0, 0), flare=0.45, name="cloak"))
    return g, ARCHER_JOINTS


# Mage -----------------------------------------------------------------------------------------------

MAGE_JOINTS = {
    "head": (0, 0, 3.1),
    "leg_fl": (0.62, 0, 2.9),
    "leg_fr": (-0.62, 0, 2.9),
    "leg_bl": (0.25, 0, 1.5),
    "leg_br": (-0.25, 0, 1.5),
    "tail": (0, 0.42, 2.95),
}


def diamond(h, w, loc, rot=(0, 0, 0), m=None, name="rune"):
    return k.poly([(0, h), (w, 0), (0, -h), (-w, 0)], 0.04, loc=loc, rot=rot, m=m, name=name)


def mage():
    """A hooded, horned caster: a violet robe with a mantle, a split skirt, a hood over a dark
    void with three glowing eyes, a tome at the hip, hexfire runes floating round the body, an
    orb of hexfire above the left palm and a staff in the right hand topped with a crystal."""
    robe = k.flat((58, 30, 92))
    robe2 = k.flat((38, 20, 62))
    dark = k.flat((24, 22, 32))
    iron = k.flat((34, 32, 44))
    wood = k.flat((64, 42, 34))
    bone = k.flat(BONE)
    glow = k.glow(HEX)
    g = {n: [] for n in ("body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "body_glow", "head_glow", "leg_fl_glow", "leg_fr_glow")}

    b = g["body"]
    b.append(k.lathe([(0.46, 0.0), (0.52, 0.3), (0.5, 0.7), (0.4, 1.0), (0.3, 1.12)], loc=(0, 0, 1.55), m=robe, n=14, scale=(1.0, 0.85, 1.0), name="robe"))
    b.append(k.lathe([(0.8, 0.0), (0.68, 0.2), (0.46, 0.36), (0.32, 0.4)], loc=(0, 0, 2.58), m=robe2, n=14, scale=(1.0, 0.85, 1.0), name="mantle"))
    b.append(ring((0, 0, 1.62), (0, 0, 1), 0.5, 0.05, bone, "cord"))
    b.append(k.sphere(0.1, (0, -0.44, 1.62), m=bone, scale=(1.0, 0.8, 1.1), seg=8, rings=6, name="knot"))
    b.append(k.box((0.24, 0.1, 0.3), (0.5, -0.3, 1.4), rot=(0, 0, -15), m=wood, bevel=0.02, name="tome"))
    b.append(k.box((0.06, 0.12, 0.08), (0.5, -0.3, 1.52), rot=(0, 0, -15), m=bone, name="clasp"))
    g["body_glow"].append(diamond(0.18, 0.1, (0, -0.43, 2.2), m=glow, name="chest_rune"))
    g["body_glow"].append(diamond(0.07, 0.045, (0.52, -0.37, 1.4), rot=(0, 0, -15), m=glow, name="tome_rune"))
    for loc, rot in (((1.0, -0.15, 2.45), (0, 0, 20)), ((-0.9, 0.3, 2.0), (0, 0, -25)), ((0.15, 0.95, 2.8), (0, 80, 10))):  # runes floating round the body
        g["body_glow"].append(diamond(0.14, 0.08, loc, rot=rot, m=glow, name="orbit_rune"))

    hz = 3.12
    h = g["head"]
    h.append(k.lathe([(0.3, 0.0), (0.38, 0.12), (0.4, 0.38), (0.28, 0.7), (0.12, 1.05), (0.0, 1.25)], loc=(0, 0, hz), m=robe, n=12, scale=(1.0, 1.1, 1.0), name="hood"))
    h.append(shard((0, 0.1, hz + 1.2), (0, 0.6, hz + 1.1), 0.07, robe))
    h.append(k.cyl(0.25, 0.06, (0, -0.42, hz + 0.36), rot=(90, 0, 0), m=dark, n=12, name="void"))
    for s in (1, -1):
        g["head_glow"].append(k.box((0.1, 0.03, 0.04), (s * 0.1, -0.455, hz + 0.38), rot=(0, -s * 22, 0), m=glow, name="eye"))
        h.append(k.horn([(s * 0.36, -0.05, hz + 0.35), (s * 0.58, -0.1, hz + 0.6), (s * 0.64, -0.2, hz + 0.9)], [0.08, 0.06, 0.0], bone, n=6, steps=8, name="horn"))
    g["head_glow"].append(diamond(0.07, 0.05, (0, -0.335, hz + 0.62), m=glow, name="third_eye"))
    g["head_glow"].append(k.cyl(0.14, 0.2, (0, 0, 3.05), m=glow, n=8, name="neck_core"))

    for s, part in ((1, "leg_fl"), (-1, "leg_fr")):
        a, X = g[part], s * 0.62
        a.append(k.cyl(0.24, 1.0, (X, 0, 2.35), r2=0.14, m=robe, n=10, name="sleeve"))
        if s == 1:  # an open palm with an orb of hexfire above it
            a.append(k.box((0.2, 0.22, 0.05), (X, -0.12, 1.78), m=bone, bevel=0.015, name="palm"))
            g[part + "_glow"].append(k.sphere(0.2, (X, -0.12, 2.1), seg=10, rings=8, m=glow, name="orb"))
            g[part + "_glow"].append(ring((X, -0.12, 2.1), (0, 0, 1), 0.32, 0.025, glow, "orb_ring"))
        else:  # a fist round a tall staff: a skull, three iron prongs and a crystal in a halo
            a.append(k.box((0.15, 0.17, 0.2), (X, -0.08, 1.72), m=bone, bevel=0.03, name="fist"))
            a.append(k.tube([(X, -0.1, 0.05), (X, -0.1, 4.2)], [0.065, 0.055], m=wood, n=8, name="staff"))
            a.append(k.sphere(0.12, (X, -0.1, 4.08), m=bone, seg=8, rings=6, name="skull"))
            for i in range(3):
                ang = i * 2.094
                tip = Vector((X + 0.36 * math.cos(ang), -0.1 + 0.36 * math.sin(ang), 4.78))
                a.append(shard((X, -0.1, 4.15), tuple(tip), 0.06, iron))
            g[part + "_glow"].append(k.sphere(0.2, (X, -0.1, 4.5), scale=(0.8, 0.8, 1.5), seg=6, rings=4, m=glow, name="crystal"))
            g[part + "_glow"].append(ring((X, -0.1, 4.5), (0.4, 0, 1), 0.42, 0.03, glow, "halo"))

    for s, part in ((1, "leg_bl"), (-1, "leg_br")):  # the robe's skirt in two halves, with pointed shoes
        leg, X = g[part], s * 0.26
        leg.append(k.cyl(0.36, 1.5, (X, 0, 0.8), r2=0.26, m=robe, n=12, name="skirt"))
        leg.append(ring((X, 0, 0.12), (0, 0, 1), 0.36, 0.04, bone, "hem"))
        leg.append(k.box((0.22, 0.5, 0.14), (X, -0.2, 0.07), m=dark, bevel=0.04, name="shoe"))
        leg.append(shard((X, -0.4, 0.07), (X, -0.7, 0.16), 0.07, dark))

    g["tail"].append(ragged(0.9, 2.0, 7, 0.05, (0, 0.42, 2.95), robe2, rot=(6, 0, 0), flare=0.5, name="train"))
    return g, MAGE_JOINTS


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


# Imp (decision 0101): the swarm's minion, small and quick to fall --------------------------------------

IMP_JOINTS = {
    "head": (0, 0, 1.62),
    "leg_fl": (0.4, 0, 1.42),
    "leg_fr": (-0.4, 0, 1.42),
    "leg_bl": (0.17, 0, 0.72),
    "leg_br": (-0.17, 0, 0.72),
    "tail": (0, 0.3, 0.86),
}


def imp():
    """A Gloom Imp: a hunched little devil with a pot belly and a hexfire rune on it, a big head with
    long pointed ears, two short horns, a wide fanged grin and glowing eyes, thin clawed arms, bent
    legs on clawed feet, small bat wings and a whip tail with a hexfire barb."""
    skin = k.flat((70, 52, 92))
    skin2 = k.flat((48, 36, 66))
    dark = k.flat((26, 22, 34))
    bone = k.flat(BONE)
    glow = k.glow(HEX)
    g = {n: [] for n in ("body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "body_glow", "head_glow", "tail_glow")}

    b = g["body"]
    b.append(k.sphere(0.36, (0, -0.06, 1.02), m=skin, scale=(1.0, 0.95, 1.05), seg=14, rings=10, name="belly"))
    b.append(k.sphere(0.3, (0, 0.04, 1.36), m=skin, scale=(1.15, 0.85, 0.8), seg=12, rings=8, name="chest"))
    b.append(k.sphere(0.2, (0, 0.06, 0.8), m=skin2, scale=(1.3, 1.0, 0.7), seg=10, rings=6, name="hips"))
    g["body_glow"].append(diamond(0.22, 0.14, (0, -0.42, 1.04), rot=(90, 0, 0), m=glow, name="rune"))
    for s in (1, -1):  # small bat wings on the back
        root = Vector((s * 0.14, 0.26, 1.42))
        tip = Vector((s * 0.78, 0.5, 1.82))
        b.append(k.horn([root, (root + tip) / 2 + Vector((0, 0.06, 0.12)), tip], [0.05, 0.035, 0.015], dark, n=6, steps=8, name="wing_bone"))
        mid, low = Vector((s * 0.66, 0.46, 1.32)), Vector((s * 0.3, 0.32, 1.12))
        b.append(membrane([(root, tip, mid, 0.18), (root, mid, low, 0.12)], skin2, sag=0.06, thick=0.03))

    hz = 1.66
    h = g["head"]
    h.append(k.sphere(0.36, (0, -0.04, hz + 0.24), m=skin, scale=(1.1, 0.95, 0.92), seg=14, rings=10, name="skull"))
    h.append(k.sphere(0.22, (0, -0.28, hz + 0.12), m=skin, scale=(1.3, 0.8, 0.7), seg=12, rings=8, name="jaw"))
    h.append(k.box((0.42, 0.06, 0.05), (0, -0.46, hz + 0.08), m=dark, bevel=0.02, name="grin"))
    for i, x in enumerate((-0.15, -0.06, 0.06, 0.15)):  # fangs
        h.append(shard((x, -0.47, hz + 0.1), (x, -0.5, hz - (0.06 if i in (0, 3) else 0.02)), 0.03, bone))
    for s in (1, -1):
        h.append(shard((s * 0.3, -0.02, hz + 0.32), (s * 0.82, 0.12, hz + 0.6), 0.1, skin2))  # long pointed ears
        h.append(k.horn([(s * 0.14, -0.06, hz + 0.52), (s * 0.2, 0.0, hz + 0.72), (s * 0.16, 0.12, hz + 0.84)], [0.06, 0.04, 0.012], bone, n=6, steps=8, name="horn"))
        g["head_glow"].append(k.sphere(0.065, (s * 0.13, -0.36, hz + 0.3), m=glow, scale=(1.3, 0.6, 0.9), seg=8, rings=6, name="eye"))

    for s, part in ((1, "leg_fl"), (-1, "leg_fr")):  # thin arms, long claws
        a, X = g[part], s * 0.4
        a.append(k.sphere(0.11, (X, 0, 1.42), m=skin, seg=8, rings=6, name="shoulder"))
        a.append(k.cyl(0.06, 0.42, (X + s * 0.04, -0.04, 1.18), rot=(10, 0, 0), m=skin, n=8, name="arm"))
        a.append(k.cyl(0.055, 0.36, (X + s * 0.06, -0.12, 0.86), rot=(24, 0, 0), m=skin2, n=8, name="forearm"))
        a.append(k.sphere(0.08, (X + s * 0.06, -0.2, 0.66), m=skin2, seg=8, rings=6, name="hand"))
        for c in (-1, 0, 1):
            a.append(shard((X + s * 0.06 + c * 0.04, -0.24, 0.64), (X + s * 0.06 + c * 0.06, -0.34, 0.5), 0.022, bone))

    for s, part in ((1, "leg_bl"), (-1, "leg_br")):  # bent legs, clawed feet
        leg, X = g[part], s * 0.17
        leg.append(k.cyl(0.1, 0.34, (X, 0.04, 0.58), rot=(-18, 0, 0), m=skin2, n=8, name="thigh"))
        leg.append(k.cyl(0.075, 0.34, (X, 0.06, 0.26), rot=(14, 0, 0), m=skin, n=8, name="shin"))
        leg.append(k.box((0.16, 0.3, 0.08), (X, -0.06, 0.04), m=dark, bevel=0.03, name="foot"))
        for c in (-1, 1):
            leg.append(shard((X + c * 0.05, -0.2, 0.05), (X + c * 0.06, -0.32, 0.02), 0.025, bone))

    tail = [Vector((0, 0.3, 0.86)), Vector((0, 0.62, 0.7)), Vector((0, 0.9, 0.86)), Vector((0, 1.06, 1.18))]
    g["tail"].append(k.horn(tail, [0.06, 0.045, 0.03, 0.02], skin2, n=6, steps=12, name="whip"))
    g["tail_glow"].append(shard(tail[-1], tail[-1] + Vector((0, 0.06, 0.24)), 0.09, glow))
    return g, IMP_JOINTS


def asset(name, maker, scale, glow, note, budget):
    joints = {}

    def build():
        groups, j = maker()
        joints.update(j)
        return groups

    return dict(name=name, build=build, scale=scale, budget=budget, finalize=k.HD, joints=joints, glow=glow, notes=note)


ASSETS = [
    asset("foe_archer", archer, 1.6, {"body_glow": HEX, "head_glow": HEX, "leg_fl_glow": HEX, "leg_fr_glow": HEX}, "Shade archers: a hooded bowman; eyes, bowstring, arrow head and quiver fletching are Neon.", 7000),
    asset("foe_mage", mage, 1.6, {"body_glow": HEX, "head_glow": HEX, "leg_fl_glow": HEX, "leg_fr_glow": HEX}, "Hex mages: a hooded, horned caster; eyes, runes, the palm orb and the staff crystal are Neon.", 8000),
    asset("foe_knight", knight, 1.6, {"body_glow": HEX, "head_glow": HEX, "leg_fl_glow": HEX, "leg_fr_glow": HEX}, "Gloom knights: haunted armour with floating pieces; runes, eye slits, shield sigil and sword runes are Neon.", 9000),
    asset("foe_ogre", ogre, 2.5, {"body_glow": HEX, "head_glow": HEX, "leg_fr_glow": HEX}, "Ogres: a hunched brute with a spiked club; cracks, eyes, collar runes and club nails are Neon.", 10000),
    asset("foe_imp", imp, 1.3, {"body_glow": HEX, "head_glow": HEX, "tail_glow": HEX}, "Gloom imps (decision 0101): the swarm's minion, a hunched little devil; eyes, belly rune and tail barb are Neon.", 6000),
    asset("foe_dragon", dragon, 1.6, {"body_glow": HEX, "head_glow": HEX, "wing_l_glow": HEX, "wing_r_glow": HEX}, "Hexfire dragons: the predator body with wings (wing_l, wing_r joints); eyes, wing veins and alternate spine spikes are Neon.", 14000),
]
