"""Skins a whole ForgeGUI creature model (one mesh, never cut) to the Animal Stations rig (decision 0102).

blender --background --factory-startup --python tools/blender/stations/skin_forge.py -- <name> <source.glb> [--test] [--stretch]

The model keeps every face where ForgeGUI made it. What is added is a skeleton with our joints' names
(`body` the root, then `head`, `leg_fl`, `leg_fr`, `leg_bl`, `leg_br`, `tail`), each bone standing at
the point that piece turns on, and the skin: each vertex's weights come from where it is (`REGIONS`, per
asset, in the model's own measurements), blending across a band at each joint so long pieces (the
torso, the tail, the legs) bend there. A loose piece smaller than `small` takes its average weights, so
it moves whole. First `tidy` joins the vertices that sit at one spot (ForgeGUI exports every facet
loose), turns every face outwards and sets the shading. Writes build/blender/stations/<name>.fbx (armature and skinned mesh) and .png
(the model's own texture), the manifest entry (`skinned: true`, `joints` in the manifest's axes) and,
with --test, renders of a few bent poses to check every piece follows the right bone; with --stretch, the
game's strongest poses with every face stretched by a quarter drawn red, and how much of it there is.

Facing: the source looks along Blender -Y with +X its left, as every Stations creature does.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

MANIFEST = os.path.join(HERE, "manifest.json")

# Per asset, in the source model's own units (Blender axes after the glTF import, before scaling):
# `length` the studs it is long (nose to tail), `joints` where each piece turns, `weights(p)` the bones a
# vertex at `p` follows ({ bone: weight }, summing to 1) and `small` the size under which an island moves
# whole.
def ramp(a, b, x):
    """0 at a, 1 at b, smooth between (a may be above b)."""
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def jackal_weights(p):
    """SHANNON's "Low-Poly Jackal in Profile" (ForgeGUI artifact 0a34fc4d), the Jackal: tan with a black
    saddle, the head at y < -0.32, front legs at x +-0.08, y -0.24 (apart below z -0.12), hind legs at
    x +-0.135, y 0.13 (apart below z -0.11), and a bushy tail hanging behind them from y 0.21."""
    tail = ramp(0.2, 0.25, p.y)
    head = ramp(-0.3, -0.36, p.y) * ramp(0.0, 0.08, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if -0.31 < p.y < -0.13 and 0.03 < abs(p.x) < 0.14:
        leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.12, -0.18, p.z)
    elif 0.02 < p.y < 0.21 and 0.06 < abs(p.x) < 0.2:
        leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.1, -0.16, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def sphinx_weights(p):
    """SHANNON's "Low-Poly Anubis Statue" (ForgeGUI artifact 54ef40ce), the Sphinx Jackal: sandstone, the
    head and striped headdress at y < -0.32, front legs at x +-0.12, y -0.28 (apart below z -0.12), hind
    legs mid-stride at x +-0.11, y 0.07..0.13 (apart below z -0.11), and a pointed tail from y 0.2."""
    tail = ramp(0.19, 0.23, p.y)
    head = ramp(-0.31, -0.37, p.y) * ramp(-0.05, 0.03, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if -0.36 < p.y < -0.12 and 0.05 < abs(p.x) < 0.18:
        leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.11, -0.17, p.z)
    elif -0.01 < p.y < 0.21 and 0.045 < abs(p.x) < 0.18:
        leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.1, -0.16, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def tortoise_weights(back, tail_from):
    """SHANNON's ForgeGUI tortoises (one body plan): a wide shell, the head out in front from y -0.34,
    stout legs under the shell's sides (|x| 0.07..0.36; front at y -0.36..-0.1, hind at `back`) leaving
    it below z -0.17, and a small tail under the back from `tail_from`."""

    def weights(p):
        tail = ramp(tail_from, tail_from + 0.05, p.y) * (1 - ramp(0.04, 0.07, abs(p.x)))
        head = ramp(-0.34, -0.39, p.y)
        w = {"body": (1 - head) * (1 - tail), "head": head, "tail": tail}
        leg, down = None, ramp(-0.17, -0.23, p.z)
        if 0.07 < abs(p.x) < 0.36 and down > 0:
            if -0.36 < p.y < -0.1:
                leg = "leg_fl" if p.x > 0 else "leg_fr"
            elif back[0] < p.y < back[1]:
                leg = "leg_bl" if p.x > 0 else "leg_br"
        if leg:
            w = {k: v * (1 - down) for k, v in w.items()}
            w[leg] = down
        return {k: v for k, v in w.items() if v > 0.001}

    return weights


def tortoise(name, length, back, hind, tail_from, artifact, what):
    return {
        "length": length,
        "joints": {
            "body": (0.0, 0.0, 0.0),
            "head": (0.0, -0.34, -0.03),
            "leg_fl": (0.23, -0.24, -0.17),
            "leg_fr": (-0.23, -0.24, -0.17),
            "leg_bl": (0.2, hind, -0.17),
            "leg_br": (-0.2, hind, -0.17),
            "tail": (0.0, tail_from, -0.2),
        },
        "weights": tortoise_weights(back, tail_from),
        "small": 0.06,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), one mesh, skinned to the Stations rig (decision 0102).",
    }


def pharaoh_weights(p):
    """SHANNON's "Anubis Guardian in Gold and Blue" (ForgeGUI artifact 518bf4a5), the Pharaoh Jackal:
    symmetric, the head and its headdress at y < -0.3, front legs at x +-0.11, y -0.29 (apart below
    z -0.12), hind legs at x +-0.12, y 0.08 (apart below z -0.1), small wings on the back (they ride on the
    body) and a long tail hanging behind from y 0.16."""
    tail = ramp(0.15, 0.2, p.y)
    head = ramp(-0.27, -0.34, p.y) * ramp(-0.06, 0.02, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, 0.0
    if 0.06 < abs(p.x) < 0.17:
        if -0.37 < p.y < -0.18:
            leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(-0.08, -0.15, p.z)
        elif -0.01 < p.y < 0.16:
            leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(-0.07, -0.14, p.z)
    if leg and down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def rhino_weights(tail_from, leg_top):
    """SHANNON's ForgeGUI rhinos (one reference image, one body plan): the head forward of the shoulders
    from y -0.21, front legs at x +-0.13, y -0.23..0, hind legs at x +-0.125, y 0..0.32, apart below
    `leg_top`, and a thin tail from `tail_from`."""

    def weights(p):
        tail = ramp(tail_from, tail_from + 0.04, p.y)
        head = ramp(-0.21, -0.26, p.y)
        w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
        leg, down = None, ramp(leg_top, leg_top - 0.06, p.z)
        if 0.05 < abs(p.x) < 0.23 and down > 0:
            if -0.23 < p.y < 0.0:
                leg = "leg_fl" if p.x > 0 else "leg_fr"
            elif 0.0 <= p.y < 0.32:
                leg = "leg_bl" if p.x > 0 else "leg_br"
        if leg:
            w = {k: v * (1 - down) for k, v in w.items()}
            w[leg] = down
        return {k: v for k, v in w.items() if v > 0.001}

    return weights


def rhino(name, length, tail_from, tail_z, leg_top, artifact, what):
    return {
        "length": length,
        "joints": {
            "body": (0.0, 0.0, 0.0),
            "head": (0.0, -0.22, 0.04),
            "leg_fl": (0.13, -0.13, -0.09),
            "leg_fr": (-0.13, -0.13, -0.09),
            "leg_bl": (0.125, 0.21, -0.09),
            "leg_br": (-0.125, 0.21, -0.09),
            "tail": (0.0, tail_from, tail_z),
        },
        "weights": rhino_weights(tail_from, leg_top),
        "small": 0.06,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), one mesh, skinned to the Stations rig (decision 0102).",
    }


def meerkat_weights(hip, belly, shoulder, neck):
    """SHANNON's ForgeGUI meerkats, standing upright (one body plan): the legs below the hips (z `hip`),
    short arms hanging in front of the belly (ahead of y `belly`, up to the shoulders at z `shoulder`), the
    head above the neck (z `neck`) and the tail out behind the rump (y > 0)."""

    def weights(p):
        head = ramp(neck, neck + 0.05, p.z)
        # the tail stops at the shoulders: above them, whatever hangs down the back is the head's (a crest)
        tail = ramp(0.0, 0.06, p.y) * (1 - ramp(shoulder + 0.05, neck, p.z)) * (1 - head)
        w = {"body": (1 - head) * (1 - tail), "head": head, "tail": tail}
        leg, share = None, 0.0
        if p.z < hip + 0.03 and p.y < 0.02:
            leg, share = ("leg_bl" if p.x > 0 else "leg_br"), ramp(hip + 0.03, hip - 0.03, p.z)
        elif hip + 0.08 < p.z < shoulder and p.y < belly + 0.01:
            leg = "leg_fl" if p.x > 0 else "leg_fr"
            share = ramp(belly + 0.01, belly - 0.03, p.y) * (1 - ramp(shoulder - 0.05, shoulder, p.z))
        if leg and share > 0:
            w = {k: v * (1 - share) for k, v in w.items()}
            w[leg] = share
        return {k: v for k, v in w.items() if v > 0.001}

    return weights


def meerkat(name, height, hip, belly, shoulder, neck, artifact, what):
    return {
        "height": height,  # an upright animal is scaled by its height
        "joints": {
            "body": (0.0, -0.12, hip + 0.05),
            "head": (0.0, -0.15, neck),
            "leg_fl": (0.08, -0.2, shoulder),
            "leg_fr": (-0.08, -0.2, shoulder),
            "leg_bl": (0.09, -0.14, hip),
            "leg_br": (-0.09, -0.14, hip),
            "tail": (0.0, 0.0, hip),
        },
        "weights": meerkat_weights(hip, belly, shoulder, neck),
        "small": 0.06,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), one mesh, skinned to the Stations rig (decision 0102).",
    }


def quad_weights(head_y, head_z, tail_y, front, back, front_top, back_top, inner, outer):
    """A four-legged ForgeGUI model, from its measurements: the head ahead of `head_y` and above
    `head_z`, the tail behind `tail_y`, legs between |x| `inner` and `outer` (front ones at y `front`,
    hind ones at y `back`) that leave the body below `front_top` and `back_top`."""

    def weights(p):
        tail = ramp(tail_y, tail_y + 0.05, p.y)
        head = ramp(head_y, head_y - 0.06, p.y) * ramp(head_z, head_z + 0.06, p.z)
        w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
        leg, down = None, 0.0
        if inner < abs(p.x) < outer:
            if front[0] < p.y < front[1]:
                leg, down = ("leg_fl" if p.x > 0 else "leg_fr"), ramp(front_top, front_top - 0.06, p.z)
            elif back[0] < p.y < back[1]:
                leg, down = ("leg_bl" if p.x > 0 else "leg_br"), ramp(back_top, back_top - 0.06, p.z)
        if leg and down > 0:
            w = {k: v * (1 - down) for k, v in w.items()}
            w[leg] = down
        return {k: v for k, v in w.items() if v > 0.001}

    return weights


def feet_weights(feet, top, head_y, head_z, tail_y):
    """A four-legged model whose legs stand close under it: each vertex below `top` near a foot (`feet`,
    {leg: (x, y)}) follows that leg; the head is ahead of `head_y` above `head_z`, the tail behind
    `tail_y`."""

    def weights(p):
        tail = ramp(tail_y, tail_y + 0.05, p.y)
        head = ramp(head_y, head_y - 0.05, p.y) * ramp(head_z, head_z + 0.06, p.z)
        w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
        leg, near = min(((k, (p.x - x) ** 2 + (p.y - y) ** 2) for k, (x, y) in feet.items()), key=lambda t: t[1])
        down = ramp(top, top - 0.05, p.z) if near < 0.055**2 else 0.0
        if down > 0:
            w = {k: v * (1 - down) for k, v in w.items()}
            w[leg] = down
        return {k: v for k, v in w.items() if v > 0.001}

    return weights


def flamingo_weights(leg_top, legs, head_z, head_y, tail_y, wing, beak=None):
    """SHANNON's ForgeGUI flamingos (one body plan): two thin legs (`legs`, {leg: (x, y)} where each
    stands, up to `leg_top`; the feet below z -0.4 go by side), the wing feathers on the body's sides
    (|x| from `wing`[0] to `wing`[1]: the game builds a flamingo's wings as its back legs), the neck and
    head rising from the front of the body (above `head_z`, ahead of `head_y`) and the tail feathers
    behind `tail_y` (a fan or flames). With `beak`, everything ahead of y `beak` is the head's too, however
    low: a beak that hangs below `head_z` (the Phoenix's) would stay with the body and tear off its face."""
    middle = sum(x for x, _ in legs.values()) / 2

    def weights(p):
        head = ramp(head_z, head_z + 0.05, p.z) * (1 - ramp(head_y, head_y + 0.08, p.y))
        if beak is not None:
            head = max(head, 1 - ramp(beak, beak + 0.04, p.y))
        tail = ramp(tail_y, tail_y + 0.06, p.y) * (1 - head)
        w = {"body": (1 - head) * (1 - tail), "head": head, "tail": tail}
        part, share = None, 0.0
        if p.z < leg_top + 0.03:
            leg, near = min(((k, (p.x - x) ** 2 + (p.y - y) ** 2) for k, (x, y) in legs.items()), key=lambda t: t[1])
            if p.z < -0.4:  # a foot
                part = "leg_fl" if p.x > middle else "leg_fr"
            elif near < 0.045**2:
                part = leg
            share = ramp(leg_top + 0.03, leg_top - 0.03, p.z) if part else 0.0
        if part is None and leg_top < p.z < head_z and p.y < tail_y + 0.06:
            part, share = ("leg_bl" if p.x > 0 else "leg_br"), ramp(wing[0], wing[1], abs(p.x))
        if part and share > 0:
            w = {k: v * (1 - share) for k, v in w.items()}
            w[part] = share
        return {k: v for k, v in w.items() if v > 0.001}

    return weights


def flamingo(name, height, body_z, top_z, neck_y, leg_top, legs, head_y, tail_y, wing, small, artifact, what, beak=None):
    return {
        "height": height,  # it stands tall: scaled by its height
        "joints": {
            "body": (0.0, 0.0, body_z),
            "head": (0.0, neck_y, top_z),  # the neck's foot: the head joint swings the neck
            "leg_fl": (*legs["leg_fl"], leg_top),
            "leg_fr": (*legs["leg_fr"], leg_top),
            "leg_bl": (wing[0], -0.07, top_z - 0.04),  # the wings
            "leg_br": (-wing[0], -0.07, top_z - 0.04),
            "tail": (0.0, tail_y, body_z),
        },
        "weights": flamingo_weights(leg_top, legs, top_z, head_y, tail_y, wing, beak),
        "small": small,  # loose feathers and flames this size move whole, so none stretches
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), one mesh, skinned to the Stations rig (decision 0102).",
    }


def lion(name, length, tail_x, artifact, what):
    """SHANNON's ForgeGUI lions (one body plan, one reference): a big mane round the head, front paws at
    x +-0.08..0.13, y -0.3, hind paws at y 0.14, legs apart below z -0.03, a tail rising from the rump."""
    return {
        "length": length,
        "joints": {
            "body": (0.0, -0.08, 0.05),
            "head": (0.0, -0.3, 0.1),
            "leg_fl": (0.1, -0.27, -0.04),
            "leg_fr": (-0.1, -0.27, -0.04),
            "leg_bl": (0.1, 0.13, -0.03),
            "leg_br": (-0.1, 0.13, -0.03),
            "tail": (tail_x, 0.25, 0.02),
        },
        "weights": quad_weights(-0.28, -0.1, 0.24, (-0.37, -0.14), (0.02, 0.26), -0.03, -0.02, 0.04, 0.2),
        "small": 0.06,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), one mesh, skinned to the Stations rig (decision 0102).",
    }


def guardian_weights(p):
    """SHANNON's "Sahara Guardian Rare Variant" (ForgeGUI artifact 30d3ddb4): a stone lion in gold and purple
    armour, mid-stride and a little left of centre (its middle is x -0.02). The head and mane are ahead of
    y -0.31 above z -0.07 with the front legs right under them (y -0.47..-0.28); the hind legs are apart in
    the stride (left y -0.12..0.03, right y -0.07..0.14); the tail is over a third of its length, from y 0.11."""
    tail = ramp(0.1, 0.15, p.y)
    head = ramp(-0.28, -0.34, p.y) * ramp(-0.1, -0.04, p.z)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg = None
    if abs(p.x + 0.02) > 0.03 or p.z < -0.2:  # not the pendants hanging between the legs
        if -0.47 < p.y < -0.28:
            leg = "leg_fl" if p.x > -0.02 else "leg_fr"
        elif p.x > 0 and -0.12 < p.y < 0.03:
            leg = "leg_bl"
        elif p.x <= 0 and -0.07 < p.y < 0.14:
            leg = "leg_br"
    # the legs blend over the band where they leave the body; AnimalMoves.STIFF keeps every clip's leg turns small
    down = ramp(-0.12, -0.18, p.z) if leg else 0.0
    if down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def mammoth_weights(p):
    """SHANNON's Golden Rune Mammoth (ForgeGUI artifact fb438279), straightened: a huge head whose ears and crest
    reach back over the shoulders to y -0.16, the trunk and tusks ahead of y -0.3 down to z -0.23, the front legs
    right under the head (y -0.27..-0.06), the hind legs at y 0.17..0.37, legs apart below z -0.1, a tail from y 0.37."""
    tail = ramp(0.37, 0.42, p.y)
    head = max(ramp(-0.28, -0.34, p.y), ramp(-0.16, -0.24, p.y) * ramp(-0.13, -0.06, p.z))
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg = None
    if 0.04 < abs(p.x) < 0.27:
        if -0.27 < p.y < -0.06:
            leg = "leg_fl" if p.x > 0 else "leg_fr"
        elif 0.17 < p.y < 0.37:
            leg = "leg_bl" if p.x > 0 else "leg_br"
    down = ramp(-0.1, -0.16, p.z) if leg else 0.0
    if down > 0:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def war_tortoise_weights(p):
    """SHANNON's Sunfire War-Tortoise (ForgeGUI artifact 276820c6), turned 88.7 degrees to stand along Y: a shell
    with a sun cannon on top whose barrel reaches out over the head (y < -0.36, above z 0.09: it stays on the body),
    the head below it ahead of y -0.36, stout legs under the shell's sides (front y -0.36..-0.12, hind 0.12..0.42,
    |x| 0.06..0.32) apart below z -0.21, and a small tail from y 0.4."""
    tail = ramp(0.4, 0.44, p.y) * (1 - ramp(0.06, 0.09, abs(p.x)))
    head = ramp(-0.34, -0.39, p.y) * (1 - ramp(0.06, 0.1, p.z))
    w = {"body": (1 - head) * (1 - tail), "head": head, "tail": tail}
    leg, down = None, ramp(-0.17, -0.23, p.z)
    if 0.06 < abs(p.x) < 0.32 and down > 0:
        if -0.36 < p.y < -0.12:
            leg = "leg_fl" if p.x > 0 else "leg_fr"
        elif 0.12 < p.y < 0.42:
            leg = "leg_bl" if p.x > 0 else "leg_br"
    if leg:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def sun_rhino_weights(p):
    """SHANNON's Molten Sun Rhino (ForgeGUI artifact 8fd726bf), mid-stride: the head and horn ahead of y -0.27, the
    left legs ahead of the right ones (front left y -0.27..-0.06, front right -0.14..0.08, hind left 0.15..0.36,
    hind right 0.26..0.46), apart below z -0.06, and a tail curling up behind from y 0.42 above z -0.05."""
    tail = ramp(0.42, 0.46, p.y) * ramp(-0.08, -0.03, p.z)
    head = ramp(-0.25, -0.3, p.y)
    w = {"body": (1 - tail) * (1 - head), "tail": tail, "head": head}
    leg, down = None, ramp(-0.06, -0.11, p.z)
    if 0.0 < abs(p.x) < 0.24 and down > 0:
        left = p.x > 0
        if (left and -0.27 < p.y < -0.06) or (not left and -0.14 < p.y < 0.08):
            leg = "leg_fl" if left else "leg_fr"
        elif (left and 0.15 < p.y < 0.36) or (not left and 0.26 < p.y < 0.46):
            leg = "leg_bl" if left else "leg_br"
    if leg:
        w = {k: v * (1 - down) for k, v in w.items()}
        w[leg] = down
    return {k: v for k, v in w.items() if v > 0.001}


def guardian_pieces(lo, hi):
    """The sun halo (a ring and its spikes, loose pieces standing over the shoulders) goes whole with the head."""
    if hi.y - lo.y < 0.5 and lo.y > -0.34 and hi.y < -0.1 and lo.z > 0.0 and hi.z > 0.085:
        return {"head": 1.0}
    return None


# The Shadow Legion never stretches (`cut` in main): ForgeGUI grows its arms, capes and weapons onto the body,
# and skin blended across a joint smeared them. A loose piece moves whole on the bone holding `WHOLE` of its
# weight; the rest is cut apart where one bone's faces meet another's, each part whole on its bone.
WHOLE = 0.8


def dragon_parts(jaw, head, neck, wings, legs, tail, tail_line=None):
    """A dragon regenerated standing square (wings spread flat, jaws apart, tail straight), each vertex on one
    bone, as its source measures: the lower jaw `jaw` (y0, y1, half width, lowest z, and the mouth's line: z at
    y_ref and its slope), the head `head` (ahead of y above z within half width x, and its horns: behind that,
    ahead of horn_y above horn_z), the neck `neck` (ahead of y above z within half width x), the wings `wings`
    (their band of y, the root: beyond x above z near the back and beyond x2 above z2 further out, the hand
    beyond the wrist's x), the legs `legs` (front ahead of y, hind between two y; a leg is outside |x| above z,
    or below its keel or belly) and the tail `tail` (behind y, then its middle and end). A tail that curves aside
    gives `tail_line`, (radius, [(x, y), ...] down its middle): it is what lies within the radius of that line behind
    y, and its middle and end are the shares of the way along it (`tail`'s second and third numbers)."""
    jy0, jy1, jx, jz, jz0, jslope, jyref = jaw
    hy, hz, hx, horn_y, horn_z = head
    ny, nz, nx = neck
    (wy0, wy1), (rx, rz, rx2, rz2), wrist = wings
    fy, (hy0, hy1), (lz, lx), keel, belly = legs
    t0, t1, t2 = tail
    if tail_line:
        radius, line = tail_line
        steps = list(zip(line, line[1:]))
        total = sum(math.dist(a, b) for a, b in steps)

    def along(p):  # how far along the tail's line, as a share of it, and how far from it
        best, done = (9.0, 0.0), 0.0
        for a, b in steps:
            seg = math.dist(a, b)
            u = max(0.0, min(1.0, ((p.x - a[0]) * (b[0] - a[0]) + (p.y - a[1]) * (b[1] - a[1])) / (seg * seg)))
            d = math.dist((p.x, p.y), (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
            if d < best[0]:
                best = (d, (done + seg * u) / total)
            done += seg
        return best[1], best[0]

    def parts(p):
        ax, side = abs(p.x), "l" if p.x > 0 else "r"
        if jy0 < p.y < jy1 and ax < jx and jz < p.z < jz0 + jslope * (p.y - jyref):
            return {"jaw": 1.0}
        if (p.y < hy and p.z > hz and ax < hx) or (p.y < horn_y and p.z > horn_z and ax < hx):
            return {"head": 1.0}
        if p.y < ny and p.z > nz and ax < nx:
            return {"neck_base": 1.0}
        if wy0 < p.y < wy1 and ((ax > rx and p.z > rz) or (ax > rx2 and p.z > rz2)):
            return {("hand_" if ax > wrist else "wing_") + side: 1.0}
        # (a keel hangs between the front legs, a belly between the hind ones: a leg is what is outside them, or below)
        if p.y < fy and ((p.z < lz and ax > lx) or p.z < keel):
            return {"leg_f" + side: 1.0}
        if hy0 < p.y < hy1 and ((p.z < lz and ax > lx) or p.z < belly):
            return {"leg_b" + side: 1.0}
        if p.y > t0:
            if not tail_line:
                return {"tail_end" if p.y > t2 else "tail_mid" if p.y > t1 else "tail": 1.0}
            share, off = along(p)
            if off < radius:
                return {"tail_end" if share > t2 else "tail_mid" if share > t1 else "tail": 1.0}
        return {"body": 1.0}

    return parts


# SHANNON's Dark Drake regenerated standing square (ForgeGUI job b49fe23f): x -0.471..0.475, y -0.452..0.454,
# z -0.217..0.215, facing -Y
drake_parts = dragon_parts(
    jaw=(-0.433, -0.368, 0.04, 0.04, 0.08, 0.21, -0.432),
    head=(-0.355, 0.04, 0.07, -0.27, 0.155),
    neck=(-0.285, 0.0, 0.065),
    wings=((-0.3, -0.18), (0.075, 0.03, 0.12, -0.1), 0.2),
    legs=(-0.24, (-0.17, 0.0), (-0.05, 0.04), -0.145, -0.13),
    tail=(0.0, 0.15, 0.3),
)


# SHANNON's Shadow Dragon regenerated standing square (ForgeGUI job c37c9006): x -0.479..0.479, y -0.406..0.414,
# z -0.274..0.274, facing -Y
shadow_dragon_parts = dragon_parts(
    jaw=(-0.402, -0.348, 0.04, 0.07, 0.112, 0.24, -0.4),
    head=(-0.335, 0.07, 0.09, -0.26, 0.19),
    neck=(-0.24, 0.0, 0.08),
    wings=((-0.245, -0.12), (0.1, 0.0, 0.15, -0.12), 0.19),
    legs=(-0.19, (-0.08, 0.07), (-0.05, 0.04), -0.16, -0.165),
    tail=(0.07, 0.2, 0.32),
)

# SHANNON's Ancient Alpha Dragon regenerated standing square (ForgeGUI job 865f4999): x -0.479..0.479, y -0.333..0.329,
# z -0.203..0.198, facing -Y; its tail curls away to its left (+X) behind it
alpha_dragon_parts = dragon_parts(
    jaw=(-0.327, -0.258, 0.04, 0.045, 0.087, 0.05, -0.33),
    head=(-0.255, 0.045, 0.08, -0.19, 0.15),
    neck=(-0.18, 0.0, 0.08),
    wings=((-0.165, 0.05), (0.1, 0.0, 0.15, -0.12), 0.24),
    legs=(-0.15, (-0.12, 0.03), (-0.05, 0.035), -0.13, -0.12),
    tail=(0.03, 0.33, 0.66),
    tail_line=(0.075, [(0.0, 0.03), (0.04, 0.09), (0.1, 0.15), (0.18, 0.21), (0.27, 0.27), (0.36, 0.32)]),
)

def legion(name, height, artifact, what, joints, boxes, ground=None, how="cut from its sheet", **extra):
    """A Shadow Legion figure rigged by hand (decision 0104), facing -Y: `joints` where each bone turns
    (`leg_fr` is the arm a chop raises, the weapon arm), and `boxes`, (bone, (x0, x1, y0, y1, z0, z1)) in
    the source's units: a vertex follows the bone of the first box it is in, else the body. Read the boxes
    off the --stretch bones view. A cape or cloak stays on the body: grown onto the back, it tore when it
    swung."""

    def weights(p):
        for bone, (x0, x1, y0, y1, z0, z1) in boxes:
            if x0 <= p.x <= x1 and y0 <= p.y <= y1 and z0 <= p.z <= z1:
                return {bone: 1.0}
        return {"body": 1.0}

    spec = {
        "height": height,
        "joints": joints,
        "weights": weights,
        "small": 0.03,
        "cut": True,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), {how}, skinned to the Stations rig in whole parts (decision 0104).",
    }
    if ground is not None:
        spec["ground"] = ground
    spec.update(extra)  # e.g. blend (rings of faces) for a closed skin, tris to thin it to, shade, turn
    return spec


REGIONS = {
    # the elephants (lengths: StationAssets.creature_elephant[_frost, _war].size); the head takes all ahead
    # of the shoulders: the ears, the trunk and the tusks (and the War Elephant's trunk axe)
    "creature_elephant_forge": {
        "length": 24.51,
        "joints": {
            "body": (0.0, 0.03, 0.05),
            "head": (0.0, -0.22, 0.1),
            "leg_fl": (0.1, -0.12, -0.07),
            "leg_fr": (-0.1, -0.12, -0.07),
            "leg_bl": (0.104, 0.21, -0.07),
            "leg_br": (-0.104, 0.21, -0.07),
            "tail": (0.0, 0.33, 0.05),
        },
        "weights": quad_weights(-0.18, -0.5, 0.32, (-0.2, -0.02), (0.15, 0.31), -0.07, -0.07, 0.03, 0.17),
        "small": 0.06,
        "notes": "Elephant (the Titan): SHANNON's second regular elephant from ForgeGUI (artifact fc30d94a), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_elephant_frost_forge": {
        "length": 29.97,
        "joints": {
            "body": (0.0, 0.08, 0.05),
            "head": (0.0, -0.2, 0.1),
            "leg_fl": (0.09, -0.05, -0.12),
            "leg_fr": (-0.09, -0.05, -0.12),
            "leg_bl": (0.09, 0.255, -0.12),
            "leg_br": (-0.09, 0.255, -0.12),
            "tail": (0.0, 0.34, 0.03),
        },
        # shaggy: the fur hanging round the legs moves with them
        "weights": quad_weights(-0.18, -0.5, 0.33, (-0.15, 0.06), (0.15, 0.34), -0.12, -0.12, 0.03, 0.17),
        "small": 0.06,
        "cut": True,  # big shards of fur: blended, they stretched at the shoulders and neck (7.4 % at worst)
        "notes": "Frost Mammoth: SHANNON's Frostfur Mammoth with Crystal Tusks from ForgeGUI (artifact 29d6a1a2), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_elephant_war_forge": {
        "length": 27.0,
        "joints": {
            "body": (0.0, 0.12, 0.05),
            "head": (0.0, -0.12, 0.08),
            "leg_fl": (0.078, 0.0, -0.09),
            "leg_fr": (-0.078, 0.0, -0.09),
            "leg_bl": (0.082, 0.286, -0.09),
            "leg_br": (-0.082, 0.286, -0.09),
            "tail": (0.0, 0.35, 0.05),
        },
        "weights": quad_weights(-0.1, -0.5, 0.34, (-0.07, 0.07), (0.2, 0.35), -0.09, -0.09, 0.03, 0.15),
        "small": 0.06,
        "notes": "War Elephant: SHANNON's armoured war mammoth with a trunk axe from ForgeGUI (artifact 90a97f25), one mesh, skinned to the Stations rig (decision 0102).",
    },
    # giraffes stand tall: scaled by height (StationAssets.creature_giraffe[_diamond].size); the head joint
    # is the neck's foot, so the head swings the whole neck, as the Blender giraffe's did
    "creature_giraffe_forge": {
        "height": 23.46,
        "joints": {
            "body": (0.0, 0.0, -0.05),
            "head": (0.0, -0.15, 0.06),
            "leg_fl": (0.07, -0.13, -0.1),
            "leg_fr": (-0.07, -0.13, -0.1),
            "leg_bl": (0.075, 0.16, -0.1),
            "leg_br": (-0.075, 0.16, -0.1),
            "tail": (0.0, 0.21, 0.0),
        },
        "weights": quad_weights(0.0, 0.04, 0.2, (-0.2, -0.05), (0.1, 0.23), -0.1, -0.1, 0.02, 0.16),
        "small": 0.06,
        "notes": "Giraffe: SHANNON's giraffe from ForgeGUI (artifact c2e4bf29), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_giraffe_acacia_forge": {
        "height": 24.0,  # a new variety (decision 0103): between the giraffe and the Diamond Giraffe
        "joints": {
            "body": (0.0, 0.0, -0.03),
            "head": (0.0, -0.18, 0.06),
            "leg_fl": (0.095, -0.18, -0.1),
            "leg_fr": (-0.095, -0.18, -0.1),
            "leg_bl": (0.095, 0.115, -0.1),
            "leg_br": (-0.095, 0.115, -0.1),
            "tail": (0.0, 0.23, 0.0),
        },
        # acacias grow on its back (they ride the body) and up its neck (they ride the head)
        "weights": quad_weights(-0.06, 0.04, 0.23, (-0.26, -0.08), (0.04, 0.2), -0.1, -0.1, 0.03, 0.18),
        "small": 0.1,  # its leaves are loose pieces: each moves whole
        "notes": "Acacia Giraffe: SHANNON's giraffe with acacias growing on it, from ForgeGUI (artifact 6e93bd49), one mesh, skinned to the Stations rig (decisions 0102, 0103).",
    },
    "creature_giraffe_diamond_forge": {
        "height": 24.39,
        "joints": {
            "body": (0.0, -0.05, -0.03),
            "head": (0.0, -0.22, 0.06),
            "leg_fl": (0.1, -0.24, -0.09),
            "leg_fr": (-0.1, -0.24, -0.09),
            "leg_bl": (0.1, 0.14, -0.09),
            "leg_br": (-0.1, 0.14, -0.09),
            "tail": (0.0, 0.19, 0.0),
        },
        "weights": quad_weights(-0.06, 0.04, 0.19, (-0.32, -0.15), (0.06, 0.21), -0.09, -0.09, 0.03, 0.17),
        "small": 0.06,
        "notes": "Diamond Giraffe: SHANNON's diamond giraffe from ForgeGUI (artifact f1abf347), one mesh, skinned to the Stations rig (decision 0102).",
    },
    # lengths: the Blender models' (StationAssets.creature_lion[_shadow, _sun].size)
    "creature_lion_forge": lion("Lion", 13.0, 0.0, "c46416c2", "lion (now do it again following this reference)"),
    "creature_lion_shadow_forge": lion("Shadow Lion", 15.03, -0.05, "68e2e5b5", "Shadowfang Purple Lion"),
    # low-poly and faceted: blended, its legs and neck stretched in the walk (12.6 % of it at worst); cut, it moves in whole parts
    "creature_lion_sun_forge": dict(lion("Sun Lion", 16.05, 0.0, "efa580ee", "Fierce Low-Poly Sunmane Lion"), cut=True),
    # heights: the Blender models' (StationAssets.creature_flamingo[_peacock, _phoenix].size)
    "creature_lion_sahara_forge": {
        "length": 22.0,  # 1.37 x the Sun Lion
        "joints": {
            "body": (-0.02, -0.15, -0.03),
            "head": (-0.03, -0.33, 0.0),
            "leg_fl": (0.06, -0.37, -0.1),
            "leg_fr": (-0.1, -0.37, -0.1),
            "leg_bl": (0.04, -0.05, -0.1),
            "leg_br": (-0.08, 0.04, -0.1),
            "tail": (-0.045, 0.12, -0.06),
        },
        "weights": guardian_weights,
        "pieces": guardian_pieces,
        "small": 0.06,
        "notes": "Sahara Guardian: SHANNON's Sahara Guardian Rare Variant from ForgeGUI (artifact 30d3ddb4), one mesh with its sun halo, skinned to the Stations rig (decision 0102).",
    },
    # the source was turned 22.9 degrees about the vertical and centred on its feet first (ForgeGUI stood it
    # askew): its length along Y, head at -Y. A dense smooth model, thinned: shaded smooth, its skin blended.
    "creature_elephant_sahara_forge": {
        "length": 39.0,  # 1.3 x the Frost Mammoth: an Eternal is clearly bigger than its species' others
        "joints": {
            "body": (0.0, 0.05, 0.0),
            "head": (0.0, -0.2, 0.02),
            "leg_fl": (0.14, -0.17, -0.1),
            "leg_fr": (-0.14, -0.17, -0.1),
            "leg_bl": (0.11, 0.27, -0.1),
            "leg_br": (-0.12, 0.27, -0.1),
            "tail": (-0.06, 0.38, -0.06),
        },
        "weights": mammoth_weights,
        "small": 0.06,
        "shade": "smooth",
        "tris": 12000,
        "notes": "Sahara Mammoth: SHANNON's Golden Rune Mammoth from ForgeGUI (artifact fb438279), one mesh with its sun spike, skinned to the Stations rig (decision 0102).",
    },
    "creature_tortoise_sahara_forge": {  # (the source turned 88.7 degrees first: straighten.py)
        "length": 19.5,  # 1.3 x the Island Tortoise
        "joints": {
            "body": (0.0, 0.0, 0.0),
            "head": (0.0, -0.36, -0.03),
            "leg_fl": (0.2, -0.25, -0.17),
            "leg_fr": (-0.2, -0.25, -0.17),
            "leg_bl": (0.2, 0.27, -0.17),
            "leg_br": (-0.2, 0.27, -0.17),
            "tail": (0.0, 0.4, -0.1),
        },
        "weights": war_tortoise_weights,
        "small": 0.06,
        "shade": "smooth",
        "tris": 12000,
        "notes": "Sunfire War-Tortoise: SHANNON's Sunfire War-Tortoise of the Desert from ForgeGUI (artifact 276820c6), one mesh with its sun cannon, skinned to the Stations rig (decision 0102).",
    },
    "creature_rhino_sahara_forge": {
        "length": 24.0,  # 1.3 x the Lava Rhino
        "joints": {
            "body": (0.0, 0.0, 0.0),
            "head": (0.0, -0.26, 0.03),
            "leg_fl": (0.15, -0.17, -0.06),
            "leg_fr": (-0.16, -0.03, -0.06),
            "leg_bl": (0.07, 0.26, -0.06),
            "leg_br": (-0.1, 0.37, -0.06),
            "tail": (0.0, 0.43, 0.02),
        },
        "weights": sun_rhino_weights,
        "small": 0.06,
        "shade": "smooth",
        "tris": 12000,
        "notes": "Molten Sun Rhino: SHANNON's Molten Sun Rhino of the Savannah from ForgeGUI (artifact 8fd726bf), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_flamingo_forge": flamingo("Flamingo", 8.0, 0.0, 0.12, -0.17, -0.12, {"leg_fl": (0.06, 0.035), "leg_fr": (-0.069, 0.09)}, 0.0, 0.13, (0.09, 0.13), 0.06, "c9dca2cc", "pink flamingo"),
    "creature_flamingo_peacock_forge": flamingo("King Flamingo", 9.8, -0.06, 0.06, -0.18, -0.17, {"leg_fl": (0.05, 0.04), "leg_fr": (-0.05, 0.04)}, -0.06, 0.12, (0.1, 0.15), 0.12, "a84542a7", "peacock flamingo with a crown"),
    "creature_flamingo_phoenix_forge": flamingo("Phoenix Flamingo", 11.3, -0.03, 0.12, -0.2, -0.2, {"leg_fl": (0.088, -0.02), "leg_fr": (-0.088, -0.02)}, -0.08, 0.12, (0.11, 0.17), 0.25, "675a6361", "Flamingo of Fire", beak=-0.3),
    "creature_cheetah_forge": {
        "length": 10.85,  # the Blender cheetah's length (StationAssets.creature_cheetah.size)
        "joints": {
            "body": (0.0, -0.05, 0.03),
            "head": (-0.02, -0.32, 0.1),
            "leg_fl": (0.115, -0.29, -0.06),
            "leg_fr": (-0.115, -0.29, -0.06),
            "leg_bl": (0.1, 0.08, -0.06),
            "leg_br": (-0.115, 0.11, -0.06),
            "tail": (-0.02, 0.19, 0.0),
        },
        # slim: head at y < -0.3, legs at |x| 0.06..0.17 leaving the body below z -0.05, a long ringed tail
        "weights": quad_weights(-0.3, -0.02, 0.17, (-0.37, -0.2), (0.0, 0.2), -0.04, -0.04, 0.055, 0.18),
        "small": 0.06,
        "notes": "Cheetah: SHANNON's Angular Roblox-Style Cheetah from ForgeGUI (artifact 1a08317f), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_cheetah_thunder_forge": {
        "length": 13.5,  # the Blender Fire Cheetah's length (StationAssets.creature_cheetah_fire.size), whose place it takes
        "joints": {
            "body": (0.0, -0.05, 0.05),
            "head": (-0.03, -0.33, 0.12),
            "leg_fl": (0.13, -0.29, -0.1),
            "leg_fr": (-0.13, -0.29, -0.1),
            "leg_bl": (0.13, 0.15, -0.1),
            "leg_br": (-0.13, 0.15, -0.1),
            "tail": (-0.03, 0.26, 0.08),
        },
        # storm clouds: head at y < -0.31 under a spiky cloud mane, legs at |x| 0.06..0.2 leaving the body
        # below z -0.08, and a tail ending in a cloud
        "weights": quad_weights(-0.31, -0.05, 0.25, (-0.39, -0.15), (0.03, 0.3), -0.08, -0.08, 0.055, 0.21),
        "small": 0.06,
        "notes": "Thunder Cheetah (the Fire Cheetah's place): SHANNON's storm-cloud cheetah from ForgeGUI (artifact 91e6733c), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_cheetah_lightning_forge": {
        "length": 13.86,  # the Blender Lightning Cheetah's length (StationAssets.creature_cheetah_lightning.size)
        "joints": {
            "body": (-0.065, 0.1, 0.03),
            "head": (-0.07, -0.06, 0.08),
            "leg_fl": (-0.027, -0.05, -0.04),
            "leg_fr": (-0.122, -0.02, -0.04),
            "leg_bl": (-0.006, 0.16, -0.04),
            "leg_br": (-0.11, 0.25, -0.04),
            "tail": (-0.06, 0.3, 0.0),
        },
        # cut from the concept sheet and turned straight (the big cheetah of artifact d4747ca8): legs close
        # under the body, left of the middle line at x -0.065 being +x, apart below z -0.06
        "weights": feet_weights(
            {"leg_fl": (-0.027, -0.06), "leg_fr": (-0.122, -0.029), "leg_bl": (-0.006, 0.16), "leg_br": (-0.11, 0.257)},
            -0.03, -0.04, -0.02, 0.29,
        ),
        "small": 0.06,
        "notes": "Lightning Cheetah: the big cheetah of SHANNON's ForgeGUI concept sheet (artifact d4747ca8), cut out and turned straight, skinned to the Stations rig (decision 0102).",
    },
    # heights: the Blender models' (StationAssets.creature_meerkat[_star, _storm].size)
    "creature_meerkat_forge": meerkat("Meerkat", 4.8, -0.25, -0.235, 0.13, 0.24, "836fe118", "meerkat (now do it again following this reference)"),
    "creature_meerkat_star_forge": meerkat("Star Meerkat", 7.5, -0.27, -0.225, 0.1, 0.22, "5d3b0709", "star meerkat"),
    "creature_meerkat_storm_forge": meerkat("Storm Meerkat", 6.7, -0.25, -0.262, 0.1, 0.21, "1f8645af", "Alien Meerkat with UFO Tail"),
    # lengths: the Blender models' (StationAssets.creature_rhino[_lava, _crystal].size)
    "creature_rhino_forge": rhino("Rhino", 13.9, 0.32, 0.06, -0.09, "9f6a531e", "Low-Poly Rhino"),
    "creature_rhino_crystal_forge": rhino("Crystal Rhino", 16.0, 0.33, 0.08, -0.1, "f70447fd", "Rainbow Crystal Rhino"),
    "creature_rhino_lava_forge": rhino("Lava Rhino", 18.5, 0.3, 0.07, -0.09, "f93e493b", "Molten Lava Rhino Warrior"),
    "creature_jackal_pharaoh_forge": {
        "length": 9.1,  # the Blender Pharaoh Jackal's length (StationAssets.creature_jackal_pharaoh.size)
        "joints": {
            "body": (0.0, -0.08, 0.0),
            "head": (0.0, -0.3, 0.1),
            "leg_fl": (0.11, -0.26, -0.1),
            "leg_fr": (-0.11, -0.26, -0.1),
            "leg_bl": (0.1, 0.08, -0.07),
            "leg_br": (-0.1, 0.08, -0.07),
            "tail": (0.0, 0.16, -0.04),
        },
        "weights": pharaoh_weights,
        "small": 0.06,
        "notes": "Pharaoh Jackal: SHANNON's Anubis Guardian from ForgeGUI (artifact 518bf4a5), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_jackal_forge": {
        "length": 7.4,  # the Blender jackal's length (StationAssets.creature_jackal.size)
        "joints": {
            "body": (0.0, -0.04, 0.0),
            "head": (0.0, -0.31, 0.12),
            "leg_fl": (0.08, -0.22, -0.12),
            "leg_fr": (-0.08, -0.22, -0.12),
            "leg_bl": (0.12, 0.13, -0.1),
            "leg_br": (-0.12, 0.13, -0.1),
            "tail": (0.0, 0.21, 0.0),
        },
        "weights": jackal_weights,
        "small": 0.06,
        "notes": "Jackal: SHANNON's Jackal in Profile from ForgeGUI (artifact 0a34fc4d), one mesh, skinned to the Stations rig (decision 0102).",
    },
    "creature_jackal_sphinx_forge": {
        "length": 9.6,  # the Blender Sphinx Jackal's length (StationAssets.creature_jackal_sphinx.size)
        "joints": {
            "body": (0.0, -0.06, 0.0),
            "head": (0.0, -0.32, 0.1),
            "leg_fl": (0.12, -0.26, -0.12),
            "leg_fr": (-0.12, -0.26, -0.12),
            "leg_bl": (0.11, 0.07, -0.1),
            "leg_br": (-0.11, 0.13, -0.1),
            "tail": (0.0, 0.2, -0.02),
        },
        "weights": sphinx_weights,
        "small": 0.06,
        "notes": "Sphinx Jackal: SHANNON's Anubis Statue from ForgeGUI (artifact 54ef40ce), one mesh, skinned to the Stations rig (decision 0102).",
    },
    # the Hexbound knight (a foe): cut out of the 01:18 model, which made SHANNON's whole concept sheet in
    # 3D (the rock base, the title and the small detail pieces dropped); 7.52 studs from its feet up, as
    # the Blender knight
    "foe_knight_forge": legion(
        "Shadow Knight", 7.9, "f9bf1baf", "Shadow Knight (01:18)",
        how="regenerated by ForgeGUI in an A-pose, its sword and shield made apart (job 519ef8b1) and put in its hands",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.22), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.18, 0.0, 0.15), "leg_fr": (-0.18, 0.0, 0.15), "leg_bl": (0.08, 0.0, -0.15), "leg_br": (-0.08, 0.0, -0.15),
        },
        boxes=[
            ("leg_fl", (0.19, 1, -1, -0.04, -0.35, 0.3)),  # the shield, on the left forearm
            ("leg_fl", (0.19, 1, -1, 0.05, -0.3, 0.25)),  # the left arm, in front of the cape
            ("leg_fr", (-1, -0.25, -1, 1, -0.2, 0.0)),  # the sword, held ahead in the right hand
            ("leg_fr", (-1, -0.19, -1, 0.05, -0.3, 0.25)),
            ("head", (-0.13, 0.13, -1, 1, 0.22, 1)),
            ("body", (-0.06, 0.06, -1, -0.07, -0.4, -0.1)),  # the tabard
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.31)),  # below the cape's hem: the whole boot, heel and all
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.31)),
            ("leg_bl", (0.0, 0.19, -1, 0.05, -1, -0.15)),
            ("leg_br", (-0.19, 0.0, -1, 0.05, -1, -0.15)),
        ],
        blend=2,
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25)},
        elbows={"leg_fl": (0.35, -0.025, -0.101), "leg_fr": (-0.35, -0.025, -0.101)},
        turn=False,
    ),
        "weights": lambda p: {"body": 1.0},
    # the Shadow Legion (decision 0104), rigged by hand: heights in studs from the feet up, each hip where it
    # was (a figure's walk is timed by it); a robe's feet stay under it
    "foe_knight_heavy_forge": legion(
        "Heavy Knight", 9.0, "2f5329e8", "heavy knight (01:27)",
        how="regenerated by ForgeGUI in an A-pose, its hammer and shield made apart (job 2f5329e8) and put in its hands, the hammer gripped a third of the way up its shaft",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.22), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.2, 0.0, 0.15), "leg_fr": (-0.2, 0.0, 0.15), "leg_bl": (0.09, 0.0, -0.15), "leg_br": (-0.09, 0.0, -0.15),
        },
        boxes=[
            ("leg_fl", (0.21, 1, -1, -0.06, -0.4, 0.3)),  # the shield, on the left forearm
            ("leg_fl", (0.21, 1, -1, 1, -0.22, 0.3)),
            ("leg_fr", (-1, -0.25, -1, 0.1, -0.42, 0.0)),  # the hammer, held ahead in the right hand, head down (its handle's end pokes back past the fist)
            ("leg_fr", (-1, -0.21, -1, 1, -0.22, 0.3)),
            ("head", (-0.12, 0.12, -1, 1, 0.22, 1)),
            ("body", (-0.06, 0.06, -1, -0.08, -0.4, -0.08)),  # the tabard
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.15)),
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.15)),
        ],
        blend=2,
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25)},
        tips="leg_fr",  # the hammer's head: a trail and a glow follow it (Creatures.client WEAPON_FX)
        elbows={"leg_fl": (0.378, -0.038, -0.118), "leg_fr": (-0.378, -0.038, -0.118)},
        turn=False,
    ),
    # the bow in its left (+X) hand; its right draws across its chest; quiver and cloak on its back and side
    "foe_archer_forge": legion(
        "Shadow Archer", 7.4, "6a06f2d8", "Shadow Archer (01:29)",
        how="regenerated by ForgeGUI in an A-pose, its bow made apart (job 7633fd67) and put in its left hand",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.2), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.17, 0.0, 0.15), "leg_fr": (-0.17, 0.0, 0.15), "leg_bl": (0.08, 0.0, -0.13), "leg_br": (-0.08, 0.0, -0.13),
        },
        boxes=[
            ("leg_fl", (0.27, 1, -1, 1, -0.25, 0.25)),  # the left hand and its bow, held low pointing ahead
            ("leg_fl", (0.19, 1, -1, 0.05, -0.25, 0.25)),  # the arm, in front of the cloak
            ("leg_fr", (-1, -0.27, -1, 1, -0.25, 0.25)),
            ("leg_fr", (-1, -0.19, -1, 0.05, -0.25, 0.25)),
            ("head", (-0.15, 0.15, -1, 0.06, 0.2, 1)),  # the hood (the quiver behind stays on the body)
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.31)),  # below the cloak's hem: the whole boot, heel and all
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.31)),
            ("leg_bl", (0.0, 0.19, -1, 0.05, -1, -0.13)),
            ("leg_br", (-0.19, 0.0, -1, 0.05, -1, -0.13)),
        ],
        blend=2,  # arms clear of the body: their shoulders bend
        # from the A-pose to arms by its sides, the arrow arm bent so the arrow in its fist points ahead and down
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25), "elbow_r": (50, 0, 0)},
        # the bow in its hand, and an arrow (job 6c0eeb1e) in its quiver on a bone of its own, at its nock: the
        # shot brings it to the string (Creatures.client)
        held={"split": 0.8, "+x": "leg_fl", "-x": "leg_fr", "stowed": {"bone": "arrow", "behind": 0.05, "left_of": 0.15, "at": (-0.245, 0.115, 0.373)}},
        elbows={"leg_fl": (0.357, -0.035, -0.066), "leg_fr": (-0.357, -0.035, -0.066)},
        turn=False,
    ),
    # the crossbow in its right (-X) fist, pointing ahead; its quiver and cape stay with the body
    "foe_archer_crossbow_forge": legion(
        "Crossbow Troop", 7.6, "c9727742", "Crossbow Troop (01:31)",
        how="regenerated by ForgeGUI in an A-pose with empty fists, its crossbow made apart (job 9b1947e6) and put in its right fist",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.2), "tail": (0.0, 0.1, 0.1),
            "leg_fl": (0.19, 0.0, 0.13), "leg_fr": (-0.19, 0.0, 0.13), "leg_bl": (0.09, 0.0, -0.16), "leg_br": (-0.09, 0.0, -0.16),
        },
        boxes=[
            ("body", (-1, 1, 0.05, 1, -0.6, 0.32)),  # the quiver and the cape
            ("leg_fl", (0.2, 1, -1, 0.05, -0.25, 0.2)),
            ("leg_fr", (-1, -0.2, -1, 0.05, -0.25, 0.2)),
            ("head", (-0.13, 0.13, -1, 1, 0.2, 1)),
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.17)),
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.17)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25)},
        elbows={"leg_fl": (0.285, -0.007, -0.135), "leg_fr": (-0.284, -0.006, -0.136)},
        turn=False,
    ),
    # the staff upright in its right (-X) fist; an orb floats above its upturned left palm; its coat's front panel and
    # its cape stay with the body
    "foe_mage_forge": legion(
        "Darkcaster", 8.0, "021c5f3e", "Darkcaster (01:32)",
        how="regenerated by ForgeGUI in an A-pose with a fist and an open palm, its staff and orb made apart (job e034e544) and put in its hands",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.22), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.2, 0.0, 0.17), "leg_fr": (-0.2, 0.0, 0.17), "leg_bl": (0.08, 0.0, -0.17), "leg_br": (-0.08, 0.0, -0.17),
        },
        boxes=[
            ("body", (-0.09, 0.09, -1, -0.04, -0.42, 0.0)),  # the coat's front panel
            ("leg_fl", (0.19, 1, -1, 0.04, -0.14, 0.3)),
            ("leg_fr", (-1, -0.19, -1, 0.04, -0.14, 0.3)),
            ("head", (-0.12, 0.12, -1, 1, 0.22, 1)),
            ("body", (-1, 1, 0.05, 1, -0.5, 0.17)),  # the cape
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.25)),  # below the coat
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.25)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        # its arms rest bent: the staff upright in its right fist, held under its head; its left palm up before its chest, the orb above it
        rest={"leg_fl": (-23, -26, -27), "elbow_l": (87, 15, 38), "leg_fr": (-25, 0, -10), "elbow_r": (100, 0, 0)},
        elbows={"leg_fl": (0.332, -0.092, -0.091), "leg_fr": (-0.327, -0.107, -0.068)},
        turn=False,
    ),
    # the skull staff upright in its right (-X) fist; a glowing skull floats above its upturned clawed left hand; its
    # robe glides, its front panel and cape stay with the body
    "foe_mage_necromancer_forge": legion(
        "Necromancer", 8.4, "01b71c4c", "Necromancer (01:34)",
        how="regenerated by ForgeGUI in an A-pose with a fist and an open clawed hand, its staff and skull made apart (job a7455633) and put in its hands",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.22), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.19, 0.0, 0.17), "leg_fr": (-0.19, 0.0, 0.17), "leg_bl": (0.07, 0.0, -0.2), "leg_br": (-0.07, 0.0, -0.2),
        },
        boxes=[
            ("body", (-0.09, 0.09, -1, -0.05, -0.45, 0.05)),  # the robe's front panel
            ("leg_fl", (0.19, 1, -1, 0.03, -0.16, 0.2)),
            ("leg_fr", (-1, -0.19, -1, 0.03, -0.16, 0.2)),
            ("head", (-0.14, 0.14, -1, 1, 0.22, 1)),
            ("body", (-1, 1, 0.03, 1, -0.6, 0.22)),  # the cape
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.36)),  # its boots, under the robe
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.36)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        # its arms rest bent: the staff upright in its right fist; its left palm up before it, the skull above it
        rest={"leg_fl": (-3, 6, -2), "elbow_l": (80, -11, 54), "leg_fr": (-25, 0, -10), "elbow_r": (100, 0, 0)},
        elbows={"leg_fl": (0.299, -0.091, -0.107), "leg_fr": (-0.278, -0.094, -0.064)},
        turn=False,
    ),
    "foe_mage_priest_forge": legion(
        "Battle Priest", 8.0, "ad1de0c6", "Battle Priest (01:36)",
        how="regenerated by ForgeGUI in an A-pose with a fist and an open palm, its staff (job 0ad35017) in its fist and its half-open book (job 6c0eeb1e) open on its palm, set for its idle pose",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.2), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.17, 0.0, 0.15), "leg_fr": (-0.17, 0.0, 0.15), "leg_bl": (0.06, 0.0, -0.2), "leg_br": (-0.06, 0.0, -0.2),
        },
        boxes=[
            ("leg_fr", (-1, -0.17, -1, 1, -0.2, 0.3)),  # the arms (the staff and the book go with their hands: `held`)
            ("leg_fl", (0.17, 1, -1, 1, -0.2, 0.3)),
            ("head", (-0.15, 0.15, -1, 1, 0.2, 1)),
        ],
        blend=2,
        # its arms rest bent: the staff upright in its right fist, out to its side; the open book on its left palm, held low before it
        rest={"leg_fl": (-7, -36, 12), "elbow_l": (76, -11, 6), "leg_fr": (20, 0, -10), "elbow_r": (60, 0, 0)},
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        elbows={"leg_fl": (0.289, -0.09, -0.076), "leg_fr": (-0.274, -0.077, -0.056)},
        tips="leg_fl",  # the book's far end: its magic bolt is cast from there (Creatures.client boltFx)
        turn=False,
    ),
    # the great axe in its right (-X) fist; its fur mantle, front panel and cape stay with the body
    "foe_knight_berserker_forge": legion(
        "Berserker", 8.6, "ad969636", "Berserk Assault (01:40)",
        how="regenerated by ForgeGUI in an A-pose with empty fists, its great axe made apart (job 9b1947e6) and put in its right fist",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.3), "tail": (0.0, 0.1, 0.15),
            "leg_fl": (0.21, 0.0, 0.18), "leg_fr": (-0.21, 0.0, 0.18), "leg_bl": (0.1, 0.0, -0.18), "leg_br": (-0.1, 0.0, -0.18),
        },
        boxes=[
            ("body", (-0.08, 0.08, -1, -0.04, -0.4, 0.0)),  # the front panel
            ("leg_fl", (0.22, 1, -1, 0.06, -0.2, 0.19)),  # below the fur mantle
            ("leg_fr", (-1, -0.22, -1, 0.06, -0.2, 0.19)),
            ("head", (-0.1, 0.1, -1, 0.06, 0.3, 1)),
            ("body", (-1, 1, 0.06, 1, -0.6, 0.4)),  # the cape
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.2)),
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.2)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25)},
        elbows={"leg_fl": (0.349, -0.083, -0.025), "leg_fr": (-0.35, -0.083, -0.025)},
        turn=False,
    ),
    # the club in its right (-X) fist, held at its handle's end, its head ahead and down; its loincloth stays with the body
    "foe_ogre_forge": legion(
        "Ogre Enforcer", 10.5, "559185f5", "Ogre Enforcer (01:41)",
        how="regenerated by ForgeGUI in an A-pose with empty fists, its club made apart (job e034e544) and put in its right fist",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.28), "tail": (0.0, 0.1, 0.15),
            "leg_fl": (0.26, 0.0, 0.18), "leg_fr": (-0.26, 0.0, 0.18), "leg_bl": (0.12, 0.0, -0.16), "leg_br": (-0.12, 0.0, -0.16),
        },
        boxes=[
            ("leg_fl", (0.235, 1, -1, 1, -0.32, 0.14)),
            ("leg_fl", (0.26, 1, -1, 1, 0.14, 0.3)),
            ("leg_fr", (-1, -0.235, -1, 1, -0.32, 0.14)),
            ("leg_fr", (-1, -0.26, -1, 1, 0.14, 0.3)),
            ("head", (-0.13, 0.13, -1, 1, 0.28, 1)),
            ("body", (-0.12, 0.12, -1, -0.13, -0.36, -0.03)),  # the loincloth's front flap
            ("body", (-0.18, 0.18, 0.12, 1, -0.36, -0.03)),  # and its back
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.19)),
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.19)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        rest={"leg_fl": (0, 0, 15), "leg_fr": (0, 0, -15)},
        elbows={"leg_fl": (0.43, 0.025, -0.17), "leg_fr": (-0.413, 0.011, -0.189)},
        turn=False,
    ),
    # the axe in its left (+X) fist, a banner on its back
    # the great axe held up before it in both hands (in its right (-X) fist, turning about the grip); its banner,
    # chain and loincloth stay with the body
    "foe_ogre_commander_forge": legion(
        "Ogre Commander", 12.5, "33ba2278", "Ogre Commander (01:42)",
        how="regenerated by ForgeGUI in an A-pose with empty fists, its great axe made apart (job ad7e7c71) and put in its right fist",
        joints={
            "body": (0.0, 0.0, -0.1), "head": (0.0, -0.02, 0.17), "tail": (0.0, 0.12, -0.15),
            "leg_fl": (0.22, 0.0, 0.1), "leg_fr": (-0.22, 0.0, 0.1), "leg_bl": (0.1, 0.0, -0.2), "leg_br": (-0.1, 0.0, -0.2),
        },
        boxes=[
            ("body", (-0.09, 0.09, -1, -0.04, -0.42, -0.05)),  # the loincloth's front panel
            ("leg_fl", (0.23, 1, -1, 0.1, -0.3, 0.12)),  # below the shoulder plates
            ("leg_fr", (-1, -0.23, -1, 0.1, -0.3, 0.12)),
            ("head", (-0.12, 0.12, -1, 0.05, 0.17, 1)),  # (the banner's pole behind it stays)
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.24)),
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.24)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        # it rests holding its great axe up before it in both hands, the right above the left on the haft (the turns
        # solved so the haft runs through both fists); a swing turns both arms alike about its shoulders' line, so
        # the hands stay on the haft (its axe turned about the haft so its blades face front and back, edge-on to the chop)
        rest={
            "leg_fr": (81.6, 25.4, -67.5), "elbow_r": (44.8, -26.4, 0), "weapon": (-10.4, -7.6, 79.8),
            "leg_fl": (90.4, -28.7, 75.7), "elbow_l": (-0.4, 30.4, 0),
        },
        elbows={"leg_fl": (0.333, -0.019, -0.185), "leg_fr": (-0.334, -0.022, -0.187)},
        # (its axe turns in its right fist, about the grip, so both hands can hold the haft through a swing)
        wield={"side": "-x", "bone": "weapon", "at": (-0.33, -0.0175, -0.17)},
        turn=False,
    ),
    # its arms and great fists swing from its shoulders and bend at the elbows; its siege castle, the castle's banners
    # and the banner at its belt stay with its body
    "foe_golem_forge": legion(
        "Siege Golem", 12.0, "b06296c3", "Siege Golem (01:56)",
        how="regenerated by ForgeGUI with empty fists, its siege castle on its back",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.08, 0.08), "tail": (0.0, 0.1, 0.1),
            "leg_fl": (0.25, -0.02, 0.12), "leg_fr": (-0.25, -0.02, 0.12), "leg_bl": (0.1, -0.02, -0.15), "leg_br": (-0.1, -0.02, -0.15),
        },
        boxes=[
            ("leg_fl", (0.18, 1, -1, 0.07, -0.08, 0.21)),  # the shoulder, upper arm and elbow, in front of the castle, below its banners
            ("leg_fl", (0.27, 1, -1, 0.07, -0.36, -0.08)),  # the forearm and the fist, beside the leg
            ("leg_fr", (-1, -0.18, -1, 0.07, -0.08, 0.21)),
            ("leg_fr", (-1, -0.27, -1, 0.07, -0.36, -0.08)),
            ("head", (-0.09, 0.09, -1, -0.02, 0.04, 0.26)),
            ("leg_bl", (0.05, 1, -1, 1, -1, -0.17)),  # below its hips, either side of the belt's banner
            ("leg_br", (-1, -0.05, -1, 1, -1, -0.17)),
        ],
        blend=2,
        elbows={"leg_fl": (0.4, -0.08, -0.2), "leg_fr": (-0.4, -0.08, -0.2)},
        turn=False,
    ),
    # behind a tower shield (its left arm, hidden), the sword in its right hand pointing down ahead
    "foe_knight_shield_forge": legion(
        "Shieldbearer", 8.0, "ce83b327", "Shieldbearer (02:00)",
        how="regenerated by ForgeGUI in an A-pose, its huge tower shield and sword made apart (job 0ad35017) and put in its hands",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.02, 0.22), "tail": (0.0, 0.08, 0.15),
            "leg_fl": (0.17, 0.0, 0.15), "leg_fr": (-0.17, 0.0, 0.15), "leg_bl": (0.08, 0.0, -0.15), "leg_br": (-0.08, 0.0, -0.15),
        },
        boxes=[
            ("leg_fl", (0.17, 1, -1, 1, -0.25, 0.3)),  # the arms (the shield and the sword go with their hands: `held`)
            ("leg_fr", (-1, -0.17, -1, 1, -0.25, 0.3)),
            ("head", (-0.12, 0.12, -1, 1, 0.22, 1)),
            ("leg_bl", (0.0, 1, -1, 1, -1, -0.19)),  # below the plated skirt's hem: the skirt stays with the body
            ("leg_br", (-1, 0.0, -1, 1, -1, -0.19)),
        ],
        blend=2,
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25)},
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        elbows={"leg_fl": (0.297, -0.027, -0.109), "leg_fr": (-0.297, -0.027, -0.109)},
        turn=False,
    ),
    # its tower shield on its left (+X) fist and its longsword in its right; its cape stays with the body
    "foe_knight_shield_commander_forge": legion(
        "Shieldbearer Commander", 9.5, "8a326fc8", "Shieldbearer Commander (02:01)",
        how="regenerated by ForgeGUI in an A-pose with empty fists, its tower shield and longsword made apart (job ad7e7c71) and put in its hands",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.01, 0.21), "tail": (0.0, 0.06, 0.18),
            "leg_fl": (0.16, 0.0, 0.15), "leg_fr": (-0.16, 0.0, 0.15), "leg_bl": (0.07, 0.0, -0.12), "leg_br": (-0.07, 0.0, -0.12),
        },
        boxes=[
            ("leg_fl", (0.17, 1, -1, 0.02, -0.2, 0.3)),  # the arms, in front of the cape (the shield and the sword go with their hands: `held`)
            ("leg_fr", (-1, -0.17, -1, 0.02, -0.2, 0.3)),
            ("head", (-0.12, 0.12, -1, 1, 0.21, 1)),  # the helmet and its plume
            ("leg_bl", (0.0, 0.175, -1, 0.02, -1, -0.19)),  # below the plated skirt's hem, inside the cape that wraps round them (its boots reach 0.171, the cape 0.177)
            ("leg_br", (-0.175, 0.0, -1, 0.02, -1, -0.19)),
        ],
        blend=2,
        rest={"leg_fl": (0, 0, 25), "leg_fr": (0, 0, -25)},
        held={"split": 0.72, "+x": "leg_fl", "-x": "leg_fr"},
        elbows={"leg_fl": (0.27, -0.055, -0.1), "leg_fr": (-0.27, -0.055, -0.1)},
        wield={"side": "-x", "bone": "weapon", "at": (-0.27, -0.055, -0.1)},  # its sword turns in its fist (a wrist)
        turn=False,
    ),
    # a rider on its warhorse: the horse's legs, neck and tail move; the rider's right arm, which holds its lance
    # couched ahead, is the bone "elbow_r" at its shoulder (no arm bones of its own); the barding stays with the body
    "foe_cavalry_forge": legion(
        "Cavalry", 11.0, "8c814c64", "Cavalry (01:45)",
        how="regenerated by ForgeGUI as a rider on its horse, the rider's right arm out, its lance made apart (job a7455633) and put in its fist",
        joints={
            "body": (0.0, 0.0, -0.05), "head": (0.0, -0.27, 0.0), "tail": (0.0, 0.4, 0.0),
            "leg_fl": (0.06, -0.22, -0.15), "leg_fr": (-0.06, -0.22, -0.15), "leg_bl": (0.06, 0.26, -0.15), "leg_br": (-0.06, 0.26, -0.15),
            "elbow_r": (-0.13, 0.03, 0.2),
        },
        boxes=[
            ("elbow_r", (-1, -0.13, -0.15, 0.22, 0.0, 0.32)),  # the rider's right arm
            ("head", (-0.12, 0.12, -1, -0.27, -0.12, 0.5)),  # the horse's neck and head, and its plume
            ("tail", (-0.12, 0.12, 0.38, 1, -0.4, 0.15)),
            ("leg_fl", (0.0, 1, -1, -0.05, -1, -0.27)),  # below the barding
            ("leg_fr", (-1, 0.0, -1, -0.05, -1, -0.27)),
            ("leg_bl", (0.046, 1, 0.05, 1, -1, -0.27)),  # its hind legs are staggered: the right one stands under its middle
            ("leg_br", (-1, 0.046, 0.05, 1, -1, -0.27)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "body", "-x": "elbow_r"},
        turn=False,
    ),
    # a commander on its warhorse: the horse's legs, neck and tail move; the rider's sword arm, its cavalry sword
    # raised in its fist, is the bone "elbow_r" at its shoulder; the barding and the banner stay with the body
    "foe_cavalry_commander_forge": legion(
        "Cavalry Commander", 14.0, "a7939882", "Cavalry Commander (01:48)",
        how="regenerated by ForgeGUI as a rider on its horse standing square, the rider's sword arm out, its cavalry sword made apart (job ad7e7c71) and put in its fist",
        joints={
            "body": (0.02, 0.0, -0.05), "head": (0.02, -0.27, 0.0), "tail": (0.02, 0.33, 0.0),
            "leg_fl": (0.08, -0.18, -0.17), "leg_fr": (-0.045, -0.18, -0.17), "leg_bl": (0.11, 0.25, -0.17), "leg_br": (-0.05, 0.25, -0.17),
            "elbow_r": (-0.1, 0.02, 0.16),
        },
        boxes=[
            ("elbow_r", (-1, -0.125, -0.15, 0.1, 0.03, 0.3)),  # the rider's sword arm
            ("head", (-0.15, 0.2, -1, -0.27, -0.02, 1)),  # the horse's neck and head (its front barding stays)
            ("tail", (-0.15, 0.2, 0.33, 1, -0.35, 0.2)),
            ("leg_fl", (0.02, 1, -0.32, 0.0, -1, -0.24)),  # below the barding's hem
            ("leg_fr", (-1, 0.02, -0.32, 0.0, -1, -0.24)),
            ("leg_bl", (0.02, 1, 0.0, 0.345, -1, -0.24)),
            ("leg_br", (-1, 0.02, 0.0, 0.345, -1, -0.24)),
        ],
        blend=2,
        held={"split": 0.72, "+x": "body", "-x": "elbow_r"},
        turn=False,
    ),
    # dragons: wings (`wing_l` on +X), head, tail and legs from the elbow and knee down
    # regenerated standing square for rigging: a neck, a jaw that opens, wings that bend at the wrist, a tail in three
    "foe_dragon_drake_forge": {
        "height": 9.0,
        "joints": {
            "body": (0.0, -0.15, -0.03), "neck_base": (0.0, -0.31, 0.02), "head": (0.0, -0.355, 0.105), "jaw": (0.0, -0.375, 0.088),
            "wing_l": (0.08, -0.25, 0.085), "hand_l": (0.2, -0.25, 0.098), "wing_r": (-0.08, -0.25, 0.085), "hand_r": (-0.2, -0.25, 0.098),
            "leg_fl": (0.06, -0.29, -0.03), "leg_fr": (-0.06, -0.29, -0.03), "leg_bl": (0.06, -0.07, -0.04), "leg_br": (-0.06, -0.07, -0.04),
            "tail": (0.0, 0.0, -0.06), "tail_mid": (0.0, 0.15, -0.08), "tail_end": (0.0, 0.3, -0.095),
        },
        "parents": {
            "head": "neck_base", "jaw": "head", "hand_l": "wing_l", "hand_r": "wing_r", "tail_mid": "tail", "tail_end": "tail_mid",
        },
        "weights": drake_parts,
        "small": 0.03,
        "cut": True,
        "blend": 2,
        "notes": "Dark Drake: SHANNON's Dark Drake (01:49) from ForgeGUI (artifact b49fe23f), regenerated standing square with its wings spread flat, skinned to the Stations rig in whole parts with a neck, a jaw, wing hands and a three-part tail (decision 0104).",
    },
    # regenerated standing square for rigging: a neck, a jaw that opens, wings that bend at the wrist, a tail in three
    "foe_dragon_forge": {
        "height": 12.0,  # its wings spread flat make it 22.7 wide at 13: at its size (2.0) it must pass the arena gate's 42 studs
        "joints": {
            "body": (0.0, -0.1, -0.05), "neck_base": (0.0, -0.27, 0.05), "head": (0.0, -0.33, 0.15), "jaw": (0.0, -0.35, 0.12),
            "wing_l": (0.1, -0.19, 0.05), "hand_l": (0.19, -0.19, 0.14), "wing_r": (-0.1, -0.19, 0.05), "hand_r": (-0.19, -0.19, 0.14),
            "leg_fl": (0.075, -0.27, -0.06), "leg_fr": (-0.075, -0.27, -0.06), "leg_bl": (0.07, 0.0, -0.06), "leg_br": (-0.07, 0.0, -0.06),
            "tail": (0.0, 0.07, -0.08), "tail_mid": (0.0, 0.2, -0.1), "tail_end": (0.0, 0.32, -0.11),
        },
        "parents": {
            "head": "neck_base", "jaw": "head", "hand_l": "wing_l", "hand_r": "wing_r", "tail_mid": "tail", "tail_end": "tail_mid",
        },
        "weights": shadow_dragon_parts,
        "small": 0.03,
        "cut": True,
        "blend": 2,
        "notes": "Shadow Dragon: SHANNON's Shadow Dragon (01:50) from ForgeGUI (artifact c37c9006), regenerated standing square with its wings spread flat, skinned to the Stations rig in whole parts with a neck, a jaw, wing hands and a three-part tail (decision 0104).",
    },
    # regenerated standing square for rigging: a neck, a jaw that opens, wings that bend at the wrist, a tail in three
    # along its curl; its wings rest raised and swept back (spread flat it would not pass the arena gate)
    "foe_dragon_alpha_forge": {
        "height": 13.8,  # its raised wings make it 23.1 wide: at its size (1.8) it must pass the arena gate's 42 studs
        "joints": {
            "body": (0.0, -0.1, -0.03), "neck_base": (0.0, -0.2, 0.04), "head": (0.0, -0.255, 0.11), "jaw": (0.0, -0.262, 0.088),
            "wing_l": (0.1, -0.08, 0.04), "hand_l": (0.24, -0.11, 0.13), "wing_r": (-0.1, -0.08, 0.04), "hand_r": (-0.24, -0.11, 0.13),
            "leg_fl": (0.07, -0.23, -0.07), "leg_fr": (-0.07, -0.23, -0.07), "leg_bl": (0.055, -0.04, -0.07), "leg_br": (-0.055, -0.04, -0.07),
            "tail": (0.0, 0.03, -0.04), "tail_mid": (0.1, 0.15, -0.07), "tail_end": (0.22, 0.24, -0.1),
        },
        "parents": {
            "head": "neck_base", "jaw": "head", "hand_l": "wing_l", "hand_r": "wing_r", "tail_mid": "tail", "tail_end": "tail_mid",
        },
        "weights": alpha_dragon_parts,
        "small": 0.03,
        "cut": True,
        "blend": 2,
        "rest": {"wing_l": (0, 25, -40), "hand_l": (0, 20, -15), "wing_r": (0, -25, 40), "hand_r": (0, -20, 15)},
        "notes": "Ancient Alpha Dragon: SHANNON's Ancient Alpha Dragon (01:54) from ForgeGUI (artifact 865f4999), regenerated standing square, skinned to the Stations rig in whole parts with a neck, a jaw, wing hands and a three-part tail along its curl, its wings resting raised (decision 0104).",
    },
    # lengths: the Blender models' (StationAssets.creature_tortoise[_island, _gemshell].size)
    "creature_tortoise_forge": tortoise("Tortoise", 10.1, (0.18, 0.46), 0.32, 0.4, "ea214a64", "Low-Poly Stone Tortoise"),
    "creature_tortoise_island_forge": tortoise("Island Tortoise", 14.8, (0.14, 0.45), 0.28, 0.35, "e1ded7d6", "Low-Poly Stone Tortoise (with an island)"),
    "creature_tortoise_gemshell_forge": tortoise("Gemshell Tortoise", 13.4, (0.15, 0.42), 0.28, 0.33, "now-make-this-in-the-roblox-style.glb", "gem tortoise (downloaded from the ForgeGUI site)"),
}


def tidy(me, weld, shade, turn=True):
    """ForgeGUI's faceted models come as thousands of loose pieces that mostly touch, a third of their faces
    turned inwards. Roblox draws only a face's front, so those show as holes. Join the vertices that sit at
    the same spot (`weld`, in the source's units; each face keeps its own UVs), then turn every face out:
    rays from its centre on each side, and the side more of them escape from is outside."""
    bm = bmesh.new()
    bm.from_mesh(me)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    flipped = 0
    for f in bm.faces:
        n = f.normal
        if n.length < 0.5:
            continue
        c = f.calc_center_median()
        a = n.orthogonal().normalized()
        b = n.cross(a)
        rays = [Vector((0, 0, 0))] + [(a * x + b * y) * 0.6 for x, y in ((1, 0), (-1, 0), (0, 1), (0, -1))]

        def escapes(side):
            out = 0
            for r in rays:
                d = (n * side + r).normalized()
                hit = tree.ray_cast(c + d * 1e-4, d)
                out += 1 if hit[0] is None else 0
            return out

        if turn and escapes(-1) > escapes(1):
            f.normal_flip()
            flipped += 1
    bm.normal_update()
    # shading: "flat" keeps every facet of a low-poly model crisp, "smooth" runs the light evenly over the
    # joined surface; the game draws the mesh two-sided (MeshPart.DoubleSided), so a thin piece shows from
    # behind too
    for f in bm.faces:
        f.smooth = shade == "smooth"
    for e in bm.edges:
        e.smooth = shade == "smooth"
    bm.to_mesh(me)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("TIDY verts", before, "->", len(me.vertices), "faces turned out", flipped, "tris", tris)
    if tris > 20000:
        raise RuntimeError(f"{tris} triangles is over Roblox's 20,000 for one mesh")


def base_colour():
    """The texture a material's base colour reads (a ForgeGUI model can carry normal and roughness maps too)."""
    for mat in bpy.data.materials:
        b = mat.node_tree.nodes.get("Principled BSDF") if mat.use_nodes else None
        if b and b.inputs["Base Color"].is_linked:
            n = b.inputs["Base Color"].links[0].from_node
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0:
                return n.image
    return next((img for img in bpy.data.images if img.size[0] > 0), None)


def roblox(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


# --stretch: the game's strongest poses (the clips' peaks in Creatures.client; keep them in step), as its
# degrees (pitch, yaw, roll) about the model's Roblox axes: its x is our -x, its y our z, its z our y. The
# body's own turn moves everything alike, so it is left out.
QUAD_POSES = {
    "walk": {"leg_fl": (27, 0, 0), "leg_br": (27, 0, 0), "leg_fr": (-27, 0, 0), "leg_bl": (-27, 0, 0), "tail": (0, 16, 0)},
    "attack": {"head": (30, 0, 0), "leg_fl": (-26, 0, 0), "leg_fr": (-26, 0, 0), "leg_bl": (-22, 0, 0), "leg_br": (-22, 0, 0), "tail": (22, 0, 0)},
    "power": {"head": (16, 0, 0), "leg_fl": (40, 0, 0), "leg_fr": (58, 0, 0), "leg_bl": (-30, 0, 0), "leg_br": (-30, 0, 0), "tail": (-28, 0, 0)},
    "fall": {"head": (26, 0, 0), "leg_fl": (30, 0, 0), "leg_fr": (24, 0, 0), "leg_bl": (-20, 0, 0), "leg_br": (-24, 0, 0), "tail": (14, 0, 0)},
}
BIPED_POSES = {
    "walk": {"leg_bl": (26, 0, 0), "leg_br": (-26, 0, 0), "leg_fl": (-18, 0, 0), "leg_fr": (18, 0, 0), "tail": (10, 0, 0)},
    "chop": {"leg_fr": (165, 0, 0), "leg_fl": (25, 0, 0), "head": (-8, 0, 0), "leg_bl": (-8, 0, 0), "leg_br": (8, 0, 0), "tail": (-10, 0, 0)},
    "swing": {"leg_fr": (15, 0, 0), "leg_fl": (50, 0, 0), "head": (10, 0, 0), "leg_bl": (16, 0, 0), "leg_br": (-12, 0, 0), "tail": (14, 0, 0)},
    "power": {"leg_fl": (172, 0, 0), "leg_fr": (166, 0, 0), "head": (-22, 0, 0), "leg_bl": (-8, 0, 0), "leg_br": (8, 0, 0), "tail": (-20, 0, 0)},
    "fall": {"head": (-30, 0, 0), "leg_fl": (70, 0, 0), "leg_fr": (20, 0, 0), "leg_bl": (12, 0, 0), "leg_br": (-10, 0, 0), "tail": (30, 0, 0)},
}
ATTACK_OF = {  # an archer draws, a mage casts (in place of the chop and its swing down)
    "foe_archer": {"leg_fl": (92, 0, 0), "leg_fr": (72, 0, 0), "head": (-4, 0, 0), "tail": (-6, 0, 0)},
    "foe_mage": {"leg_fl": (112, 0, 0), "leg_fr": (50, 0, 0), "head": (-12, 0, 0), "tail": (-8, 0, 0)},
}
OWN_POSES = {  # a model's own attack and power clips (ATTACKS, MAGICS in Creatures.client), at their peaks
    "foe_dragon_drake_forge": {  # each of its own joints at the most its moves will ask of it
        "rear": {"neck_base": (30, 0, 0), "head": (-25, 0, 0), "jaw": (-22, 0, 0), "wing_l": (0, 0, -40), "wing_r": (0, 0, 40)},
        "strike": {"neck_base": (-25, 0, 0), "head": (12, 0, 0), "jaw": (14, 0, 0)},
        "look": {"neck_base": (0, 30, 0), "head": (0, 25, 0)},
        "tail wave": {"tail": (0, 25, 0), "tail_mid": (0, 28, 0), "tail_end": (0, 32, 0)},
        "wings up": {"wing_l": (0, 0, -40), "wing_r": (0, 0, 40), "hand_l": (0, 0, -25), "hand_r": (0, 0, 25)},
        "wings down": {"wing_l": (0, 0, 35), "wing_r": (0, 0, -35), "hand_l": (0, 0, 30), "hand_r": (0, 0, -30)},
        "wings folded": {"wing_l": (0, -20, 20), "hand_l": (0, -60, 30), "wing_r": (0, 20, -20), "hand_r": (0, 60, -30)},
    },
    "foe_knight_heavy_forge": {
        "chop": {"leg_fr": (218, 0, 8), "leg_fl": (45, 0, -12), "head": (10, 0, 0), "leg_bl": (10, 0, 0), "leg_br": (-6, 0, 0)},
        "swing": {"leg_fr": (0, 20, 0), "leg_fl": (10, 0, -20), "head": (-14, 0, 0), "leg_bl": (36, 0, 0), "leg_br": (-12, 0, 0)},
        "power": {"leg_fr": (215, 0, 8), "leg_fl": (165, 0, -8), "head": (8, 0, 0), "leg_bl": (45, 0, 0), "leg_br": (40, 0, 0)},
    },
    "foe_archer_forge": {  # its draw, side-on (the volley is the same draw, its body tipped back)
        "chop": {"leg_fl": (-65, 1, -98), "leg_fr": (49, 14, 58), "elbow_r": (58, 89, 46), "head": (0, 78, 0)},
        "power": {"leg_fl": (-65, 1, -98), "leg_fr": (49, 14, 58), "elbow_r": (58, 89, 46), "head": (0, 78, 0)},
    },
}
OWN_POSES["foe_dragon_forge"] = OWN_POSES["foe_dragon_alpha_forge"] = OWN_POSES["foe_dragon_drake_forge"]  # (the same joints, the same moves asked of them)
STRETCHED = math.log(1.25)
BONE_COLOURS = {  # the bones view: which bone a face follows
    "body": (0.55, 0.55, 0.55), "head": (1.0, 0.85, 0.1), "leg_fl": (0.9, 0.15, 0.15), "leg_fr": (0.15, 0.35, 1.0),
    "leg_bl": (1.0, 0.5, 0.0), "leg_br": (0.0, 0.85, 0.9), "tail": (0.1, 0.75, 0.2), "wing_l": (0.9, 0.2, 0.9),
    "wing_r": (0.5, 0.2, 1.0), "neck_base": (0.75, 0.6, 0.3), "jaw": (1.0, 1.0, 1.0), "hand_l": (1.0, 0.6, 0.85),
    "hand_r": (0.25, 0.1, 0.55), "tail_mid": (0.45, 0.95, 0.45), "tail_end": (0.05, 0.4, 0.1), "weapon": (0.95, 0.75, 0.2),
}  # a face whose edge grows or shrinks by a quarter is drawn red


def game_poses(name):
    if name.startswith("foe_dragon"):  # a dragon walks and strikes on four legs, and beats its wings hardest then
        poses = dict(QUAD_POSES)
        poses["wings up"] = {"wing_l": (0, 0, -38), "wing_r": (0, 0, 38)}
        poses["wings down"] = {"wing_l": (0, 0, 38), "wing_r": (0, 0, -38)}
        poses.update(OWN_POSES.get(name, {}))
        return poses
    if not name.startswith("foe_") or name.startswith("foe_cavalry"):
        return QUAD_POSES
    poses = dict(BIPED_POSES)
    for kind, attack in ATTACK_OF.items():
        if name.startswith(kind):
            del poses["swing"]
            poses["chop"] = attack
    poses.update(OWN_POSES.get(name, {}))
    return poses


def set_pose(arm, pose):
    for pb in arm.pose.bones:
        a, b, c = pose.get(pb.name, (0, 0, 0))
        turn = Matrix.Rotation(math.radians(-a), 4, "X") @ Matrix.Rotation(math.radians(b), 4, "Z") @ Matrix.Rotation(math.radians(c), 4, "Y")
        rest = pb.bone.matrix_local.to_3x3().to_4x4()
        pb.matrix_basis = rest.inverted() @ turn @ rest  # the turn about its joint, in the model's axes
    bpy.context.view_layer.update()


def stretch(name, arm, body, scene, out, place):
    """Pose the model as the game does at each clip's peak and measure every face against its rest: the
    share of the surface stretched or squashed by a quarter, which two bones pull those faces apart, and a
    render from either front corner with them red."""
    import numpy as np

    me = body.data
    n = len(me.vertices)
    rest = np.empty(n * 3)
    me.vertices.foreach_get("co", rest)
    rest = rest.reshape(n, 3)
    edges = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    rest_len = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    edge_of = {tuple(sorted(e)): i for i, e in enumerate(edges.tolist())}
    face_edges = [[edge_of[tuple(sorted(k))] for k in p.edge_keys] for p in me.polygons]
    area = np.array([p.area for p in me.polygons])
    names = [g.name for g in body.vertex_groups]
    main = []  # each vertex's strongest bone
    for v in me.vertices:
        ws = sorted(((g.weight, names[g.group]) for g in v.groups), reverse=True)
        main.append(ws[0][1] if ws else "?")
    def paint(colour):
        mat = bpy.data.materials.new("paint")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
        me.materials.append(mat)
        return len(me.materials) - 1

    def shoot(label, views):
        for side, view in views:
            scene.camera.location = mid + view.normalized() * size.length * 1.2
            scene.camera.rotation_euler = (mid - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out, "previews", f"{name}_stretch_{label}_{side}.png")
            bpy.ops.render.render(write_still=True)

    size = Vector(body.dimensions)
    mid = Vector((0, 0, size.z / 2))
    # flat views from the front and each side, square: their grid in the source's units is printed. First
    # as it is, then which bone each face follows (the most of its corners'), with a white ball on each joint
    views = (("l", Vector((0.0, -1.0, 0.0))), ("r", Vector((1.0, 0.0, 0.0))), ("s", Vector((-1.0, 0.0, 0.0))))
    cam, res = scene.camera.data, (scene.render.resolution_x, scene.render.resolution_y)
    cam.type, cam.ortho_scale = "ORTHO", max(size) * 1.1
    scene.render.resolution_x = scene.render.resolution_y = 640
    shoot("tex", views)
    slots = {k: paint(c) for k, c in BONE_COLOURS.items()}
    for f in me.polygons:
        tops = [main[v] for v in f.vertices]
        f.material_index = slots.get(max(set(tops), key=tops.count), 0)
    balls = []
    for b in arm.data.bones:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=size.z * 0.015, location=b.head_local)
        balls.append(bpy.context.object)
    shoot("bones", views)
    print("BONES VIEW scale", place[0][0], "offset", *(place.col[3][k] / place[0][0] for k in range(3)), "mid", mid.z, "span", cam.ortho_scale)
    cam.type, (scene.render.resolution_x, scene.render.resolution_y) = "PERSP", res
    for ball in balls:
        bpy.data.objects.remove(ball, do_unlink=True)
    for _ in slots:
        me.materials.pop(index=len(me.materials) - 1)
    red_slot = paint((1, 0, 0))
    deps = bpy.context.evaluated_depsgraph_get()
    worst = 0.0
    for pose_name, pose in game_poses(name).items():
        set_pose(arm, pose)
        ev = body.evaluated_get(deps)
        posed_me = ev.to_mesh()
        posed = np.empty(n * 3)
        posed_me.vertices.foreach_get("co", posed)
        ev.to_mesh_clear()
        posed = posed.reshape(n, 3)
        posed_len = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
        ok = rest_len > 1e-4
        change = np.zeros(len(edges))
        change[ok] = np.abs(np.log(np.maximum(posed_len[ok], 1e-6) / rest_len[ok]))
        bad = np.array([max(change[i] for i in fe) for fe in face_edges]) > STRETCHED
        share = area[bad].sum() / area.sum() * 100
        worst = max(worst, share)
        pairs = {}
        for f in np.nonzero(bad)[0]:
            bones = sorted({main[v] for v in me.polygons[f].vertices})
            key = "/".join(bones)
            pairs[key] = pairs.get(key, 0) + area[f]
        top = sorted(pairs.items(), key=lambda kv: -kv[1])[:4]
        print(f"STRETCH {pose_name:10s} {share:5.2f}% " + "  ".join(f"{k} {v / area.sum() * 100:.2f}%" for k, v in top))
        for f, b in zip(me.polygons, bad):
            f.material_index = red_slot if b else 0
        shoot(pose_name.replace(" ", "_"), (("l", Vector((0.9, -1.0, 0.3))), ("r", Vector((-0.9, -1.0, 0.3)))))
    for f in me.polygons:
        f.material_index = 0
    me.materials.pop(index=red_slot)
    set_pose(arm, {})
    print(f"STRETCH WORST {name} {worst:.2f}%")


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    name, src = args[0], args[1]
    test = "--test" in args
    check = "--stretch" in args
    spec = REGIONS[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"{name}: expected one mesh, found {[o.name for o in meshes]}")
    for o in list(bpy.context.scene.objects):  # nothing but the one mesh: no plates, lights or helpers
        if o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    body = meshes[0]
    body.name = f"{name}_body"
    body.data.name = f"{name}_body"
    body.parent = None
    body.data.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    # the file's own normals (one per facet, a third of them inward) would override any shading: drop them
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    tidy(body.data, spec.get("weld", 0.0005), spec.get("shade", "flat"), spec.get("turn", True))
    have = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if have > spec.get("tris", have):  # a dense model is thinned, so a crowd of them stays smooth
        thin = body.modifiers.new("thin", "DECIMATE")
        thin.ratio = spec["tris"] / have
        bpy.ops.object.modifier_apply(modifier=thin.name)
        print("THINNED", have, "->", sum(len(p.vertices) - 2 for p in body.data.polygons))

    # each vertex's weights from where it is; a small island takes its average, so it moves whole
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    weights = [spec["weights"](v.co) for v in bm.verts]
    held_verts = set()  # the vertices of props joined in a hand
    parents = dict(spec.get("parents", {}))  # bones that hang from another than the body
    seen = set()
    whole, islands = 0, 0
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, island = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            island.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        islands += 1
        ilo = Vector((min(bm.verts[i].co[k] for i in island) for k in range(3)))
        ihi = Vector((max(bm.verts[i].co[k] for i in island) for k in range(3)))
        if "held" in spec:  # a prop joined in a hand (its texture right of the body's in the atlas) moves whole with that arm
            uv = bm.loops.layers.uv.active
            us = [lp[uv].uv.x for i in island for f in bm.verts[i].link_faces for lp in f.loops if lp.vert.index == i]
            if us and sum(1 for u in us if u > spec["held"]["split"]) >= 0.9 * len(us):
                side = sum(bm.verts[i].co.x for i in island) / len(island) - spec["held"].get("cx", 0.0)
                bone = spec["held"]["+x" if side > 0 else "-x"]
                stowed = spec["held"].get("stowed")  # a prop kept on its back (an arrow in its quiver) has a bone of its own
                mid = sum((bm.verts[i].co for i in island), Vector()) / len(island)
                if stowed and mid.y > stowed["behind"] and mid.x < stowed["left_of"]:
                    bone = stowed["bone"]
                    spec["joints"][bone] = stowed["at"]
                for i in island:
                    weights[i] = {bone: 1.0}
                held_verts.update(island)
                whole += 1
                continue
        w = spec["pieces"](ilo, ihi) if "pieces" in spec else None  # rigid pieces: each follows one bone
        if w is not None:
            for i in island:
                weights[i] = w
            print("PIECE", max(w, key=w.get), [round(x, 3) for x in (*ilo, *ihi)])
        elif spec.get("cut"):  # no piece stretches: it moves whole, or in whole parts cut apart at the joints
            total = {}
            for i in island:
                for k, w in weights[i].items():
                    total[k] = total.get(k, 0) + w
            top = max(total, key=total.get)
            # (never the body's own piece whole: its arms, legs and head grow from it)
            if (top != "body" and total[top] >= WHOLE * len(island)) or (ihi - ilo).length < spec["small"]:
                whole += 1
                for i in island:
                    weights[i] = {top: 1.0}
                continue
            for i in island:
                weights[i] = {max(weights[i], key=weights[i].get): 1.0}
            for _ in range(spec.get("blend", 0)):  # a closed skin is blended, a ring of faces a pass, where cutting would open it
                soft = {}
                for i in island:
                    acc = dict(weights[i])
                    for e in bm.verts[i].link_edges:
                        for k, w in weights[e.other_vert(bm.verts[i]).index].items():
                            acc[k] = acc.get(k, 0) + w
                    best = sorted(acc.items(), key=lambda kv: -kv[1])[:4]  # Roblox keeps four bones a vertex
                    total_w = sum(w for _, w in best)
                    soft[i] = {k: w / total_w for k, w in best}
                for i, w in soft.items():
                    weights[i] = w
            print("CUT", {k: round(x / len(island), 2) for k, x in total.items()}, len(island), [round(x, 3) for x in (*ilo, *ihi)])
        elif (ihi - ilo).length < spec["small"]:
            whole += 1
            mean = {}
            for i in island:
                for k, w in weights[i].items():
                    mean[k] = mean.get(k, 0) + w / len(island)
            for i in island:
                weights[i] = mean
    if spec.get("cut") and not spec.get("blend"):  # each face goes with most of its corners' bone; the skin is cut where two bones' faces meet
        bones = sorted({k for w in weights for k in w})
        layer = bm.faces.layers.int.new("bone")
        for f in bm.faces:
            tops = [max(weights[v.index], key=weights[v.index].get) for v in f.verts]
            f[layer] = bones.index(max(set(tops), key=tops.count))
        for _ in range(3):  # straighten the cut: a face goes with its neighbours when most of them agree
            turn = {}
            for f in bm.faces:
                near = [g[layer] for e in f.edges for g in e.link_faces if g is not f]
                best = max(set(near), key=near.count) if near else f[layer]
                if best != f[layer] and near.count(best) * 2 > len(near):
                    turn[f] = best
            for f, b in turn.items():
                f[layer] = b
        seams = [e for e in bm.edges if len({f[layer] for f in e.link_faces}) > 1]
        bmesh.ops.split_edges(bm, edges=seams)
        for v in [v for v in bm.verts if len({f[layer] for f in v.link_faces}) > 1]:
            bmesh.utils.vert_separate(v, list(v.link_edges))  # two bones' faces meeting at a point, not an edge
        bm.verts.ensure_lookup_table()
        weights = [{bones[v.link_faces[0][layer]] if v.link_faces else "body": 1.0} for v in bm.verts]
        bm.to_mesh(body.data)
        print("CUT APART", len(seams), "edges")
    bm.free()
    counts = {}
    for w in weights:
        top = max(w, key=w.get)
        counts[top] = counts.get(top, 0) + 1
    print("ISLANDS", islands, "moving whole", whole, "VERTS BY MAIN BONE", counts)
    if spec.get("tips"):  # two bones in the held weapon's far end, children of its arm: the game hangs a trail between them
        arm_bone = spec["tips"]
        joint = Vector(spec["joints"][arm_bone])
        own = [i for i, w in enumerate(weights) if w.get(arm_bone, 0) > 0.99]
        reach = {i: (body.data.vertices[i].co - joint).length for i in own}
        far = max(reach.values())
        for part, lo_, hi_ in (("tip", 0.93, 1.01), ("neck", 0.84, 0.88)):
            idx = [i for i in own if lo_ * far < reach[i] <= hi_ * far]
            spec["joints"][part] = tuple(sum((body.data.vertices[i].co for i in idx), Vector()) / len(idx))
            for i in idx:
                weights[i] = {part: 1.0}  # a bone Roblox keeps must have a vertex
            parents[part] = arm_bone
            print("TIP", part, len(idx))
    if spec.get("elbows"):  # an elbow halfway down each arm (to its hand, given): the forearm, and what it holds, bend there
        for arm_bone, hand in spec["elbows"].items():
            elbow = "elbow_l" if arm_bone == "leg_fl" else "elbow_r"
            joint = Vector(spec["joints"][arm_bone])
            at = joint + (Vector(hand) - joint) * 0.5
            along = (Vector(hand) - joint).normalized()
            moved = 0
            for i, w in enumerate(weights):
                a = w.get(arm_bone, 0)
                if a <= 0:
                    continue
                f = 1.0 if i in held_verts else ramp(-0.03, 0.03, (body.data.vertices[i].co - at).dot(along))
                w = dict(w)
                w[arm_bone], w[elbow] = a * (1 - f), a * f
                weights[i] = {k: x for k, x in w.items() if x > 0.001}
                moved += f > 0.5
            spec["joints"][elbow] = tuple(at)
            parents[elbow] = arm_bone
            for part in ("tip", "neck"):
                if parents.get(part) == arm_bone:
                    parents[part] = elbow
            print("ELBOW", elbow, moved)
    if spec.get("wield"):  # a held weapon with a bone of its own at the grip, riding on the forearm: it turns in the fist
        wield = spec["wield"]
        forearm = "elbow_r" if wield["side"] == "-x" else "elbow_l"
        n = 0
        for i in held_verts:
            if weights[i].get(forearm, 0) > 0.99:
                weights[i] = {wield["bone"]: 1.0}
                n += 1
        spec["joints"][wield["bone"]] = tuple(wield["at"])
        parents[wield["bone"]] = forearm
        print("WIELD", wield["bone"], n)

    # to studs, standing on the ground under its middle
    lo = Vector((min(v.co[k] for v in body.data.vertices) for k in range(3)))
    hi = Vector((max(v.co[k] for v in body.data.vertices) for k in range(3)))
    scale = spec["height"] / (hi.z - lo.z) if "height" in spec else spec["length"] / (hi.y - lo.y)
    ground = spec.get("ground", lo.z)  # where it stands: its lowest point, or its feet if something hangs lower
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -ground))
    place = Matrix.Scale(scale, 4) @ Matrix.Translation(offset)
    body.data.transform(place)
    joints = {k: place @ Vector(j) for k, j in spec["joints"].items()}

    # the skeleton: every bone stands straight up from its joint, the root's children all of it
    arm_data = bpy.data.armatures.new(f"{name}_rig")
    arm = bpy.data.objects.new(f"{name}_rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_data.edit_bones.new("body")
    root.head, root.tail, root.roll = joints["body"], joints["body"] + Vector((0, 0, 1)), 0
    for k, j in joints.items():
        if k == "body":
            continue
        b = arm_data.edit_bones.new(k)
        b.head, b.tail, b.roll = j, j + Vector((0, 0, 1)), 0
    for k in joints:
        if k != "body":
            arm_data.edit_bones[k].parent = arm_data.edit_bones[parents[k]] if k in parents else root
    bpy.ops.object.mode_set(mode="OBJECT")

    # the skin
    groups = {k: body.vertex_groups.new(name=k) for k in joints}
    for v, w in zip(body.data.vertices, weights):
        for bone, x in w.items():
            groups[bone].add([v.index], x, "REPLACE")
    body.parent = arm
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    if spec.get("rest"):  # an A-pose model rests with its arms lowered: pose them so and keep that shape
        set_pose(arm, spec["rest"])
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_apply(modifier=mod.name)
        set_pose(arm, {})
        mod = body.modifiers.new("rig", "ARMATURE")
        mod.object = arm
        # the bones hanging from a lowered arm (elbow, weapon tips) go where the arm took their part of the mesh
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        before = dict(joints)
        for k in list(joints):
            at, up = before[k], parents.get(k)
            while up:  # each bone above it turned its part about its own joint, the nearest first
                if up in spec["rest"]:
                    a, b, c = spec["rest"][up]
                    turn = Matrix.Rotation(math.radians(-a), 3, "X") @ Matrix.Rotation(math.radians(b), 3, "Z") @ Matrix.Rotation(math.radians(c), 3, "Y")
                    at = before[up] + turn @ (at - before[up])
                up = parents.get(up)
            joints[k] = at
            eb = arm_data.edit_bones[k]
            eb.head, eb.tail = at, at + Vector((0, 0, 1))
        bpy.ops.object.mode_set(mode="OBJECT")

    out = kit.OUT
    os.makedirs(out, exist_ok=True)
    # the model's own texture, as the PNG the upload sends
    image = base_colour()
    if image is None:
        raise RuntimeError(f"{name}: the model has no texture")
    png = os.path.join(out, f"{name}.png")
    if image.size[0] > 1024:  # what a Roblox texture shows at most
        image.scale(1024, 1024)
    image.filepath_raw = png
    image.file_format = "PNG"
    image.save()
    print("TEXTURE", image.size[0], image.size[1])

    if test or check:  # a stage to render it on
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
        scene.render.resolution_x, scene.render.resolution_y = 520, 420
        world = bpy.data.worlds.new("w")
        world.color = (0.8, 0.85, 0.9)
        scene.world = world
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        size = Vector((hi - lo)) * scale
        mid = Vector((0, 0, size.z / 2))
        cam.location = mid + Vector((1.0, -0.35, 0.25)).normalized() * size.length * 1.25
        cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    if check:
        stretch(name, arm, body, scene, out, place)
    if test:  # bend it: the head, a front and a hind leg forward, the tail up
        for mat in body.data.materials:  # draw only fronts, as Roblox does
            mat.use_backface_culling = True
        poses = {
            "rest": {},
            "bent": {"head": (0, 0, 35), "leg_fl": (40, 0, 0), "leg_br": (-40, 0, 0), "tail": (50, 0, 0)},
            "crouch": {"head": (-25, 0, 0), "leg_fr": (-35, 0, 0), "leg_bl": (35, 0, 0), "tail": (0, 0, -60)},
            # the Titan's den (Creatures.client `sleep`): a loaf, the body down 0.75 of the front legs' height;
            # here a head's x turn is the game's pitch the other way round (the game's 30 is -30)
            "den": {"head": (-30, 0, 0), "leg_fl": (80, 0, 0), "leg_fr": (80, 0, 0), "leg_bl": (72, 0, 0), "leg_br": (72, 0, 0)},
        }
        front = joints["leg_fl"].z  # the front legs' joint above the ground (the model stands at z 0)
        for pose_name, pose in poses.items() if name.startswith("creature_elephant") else list(poses.items())[:3]:
            for pb in arm.pose.bones:
                r = pose.get(pb.name, (0, 0, 0))
                pb.rotation_mode = "XYZ"
                # bones point up: pose rotations are in the bone's own axes (x across, y up, z back)
                pb.rotation_euler = Euler([math.radians(a) for a in r], "XYZ")
                pb.location = (0, -0.75 * front, 0) if pose_name == "den" and pb.name == "body" else (0, 0, 0)
            bpy.context.view_layer.update()
            scene.render.filepath = os.path.join(out, "previews", f"{name}_{pose_name}.png")
            bpy.ops.render.render(write_still=True)
        for pb in arm.pose.bones:
            pb.rotation_euler = Euler((0, 0, 0))
            pb.location = (0, 0, 0)
        bpy.context.view_layer.update()

    fbx = os.path.join(out, f"{name}.fbx")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=False,
        use_armature_deform_only=True,
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        path_mode="STRIP",
        embed_textures=False,
        bake_anim=False,
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    size = (hi - lo) * scale
    centre = Vector((0, 0, ((lo.z + hi.z) / 2 - ground) * scale))
    if spec.get("rest"):  # a rest baked in moved the mesh (raised wings, an axe in two hands): measure it as built
        pts = [v.co for v in body.data.vertices]
        built_lo = Vector((min(p[k] for p in pts) for k in range(3)))
        built_hi = Vector((max(p[k] for p in pts) for k in range(3)))
        size, centre = built_hi - built_lo, (built_lo + built_hi) / 2
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    manifest[name] = {
        "fbx": os.path.relpath(fbx, kit.ROOT).replace("\\", "/"),
        "png": os.path.relpath(png, kit.ROOT).replace("\\", "/"),
        "preview": f"build/blender/stations/previews/{name}_rest.png",
        "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)],
        "tris": tris,
        "parts": {f"{name}_body": tris},
        "tris_budget": 20000,
        "script": "tools/blender/stations/skin_forge.py",
        "notes": spec["notes"],
        "glow": {},
        "centres": {f"{name}_body": roblox(centre)},
        "joints": {f"{name}_{k}": roblox(j) for k, j in joints.items() if k != "body"},
        "skinned": True,
        "root": roblox(joints["body"]),
    }
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    print(f"[stations] {name}: skinned, {tris} tris, size {manifest[name]['size_studs']}")


main()
