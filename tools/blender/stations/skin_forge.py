"""Skins a whole ForgeGUI creature model (one mesh, never cut) to the Animal Stations rig (decision 0102).

blender --background --factory-startup --python tools/blender/stations/skin_forge.py -- <name> <source.glb> [--test]

The model keeps every face where ForgeGUI made it. What is added is a skeleton with our joints' names
(`body` the root, then `head`, `leg_fl`, `leg_fr`, `leg_bl`, `leg_br`, `tail`), each bone standing at
the point that piece turns on, and the skin: each vertex's weights come from where it is (`REGIONS`, per
asset, in the model's own measurements), blending across a band at each joint so long pieces (the
torso, the tail, the legs) bend there. A loose piece smaller than `small` takes its average weights, so
it moves whole. First `tidy` joins the vertices that sit at one spot (ForgeGUI exports every facet
loose), turns every face outwards and sets the shading. Writes build/blender/stations/<name>.fbx (armature and skinned mesh) and .png
(the model's own texture), the manifest entry (`skinned: true`, `joints` in the manifest's axes) and,
with --test, renders of a few bent poses to check every piece follows the right bone.

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


def flamingo_weights(leg_top, legs, head_z, head_y, tail_y, wing):
    """SHANNON's ForgeGUI flamingos (one body plan): two thin legs (`legs`, {leg: (x, y)} where each
    stands, up to `leg_top`; the feet below z -0.4 go by side), the wing feathers on the body's sides
    (|x| from `wing`[0] to `wing`[1]: the game builds a flamingo's wings as its back legs), the neck and
    head rising from the front of the body (above `head_z`, ahead of `head_y`) and the tail feathers
    behind `tail_y` (a fan or flames)."""
    middle = sum(x for x, _ in legs.values()) / 2

    def weights(p):
        head = ramp(head_z, head_z + 0.05, p.z) * (1 - ramp(head_y, head_y + 0.08, p.y))
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


def flamingo(name, height, body_z, top_z, neck_y, leg_top, legs, head_y, tail_y, wing, small, artifact, what):
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
        "weights": flamingo_weights(leg_top, legs, top_z, head_y, tail_y, wing),
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


def knight_pieces(lo, hi):
    """SHANNON's ForgeGUI Shadow Knight is separate rigid pieces of armour: each follows one bone, by
    where its box is (lo, hi). It faces -Y, its sword in its right hand (-X), its shield on its left."""
    c = (lo + hi) / 2
    if lo.z < -0.23:
        return {"tail": 1.0}  # the cape: the only piece hanging past the feet
    if lo.z > 0.1:
        return {"head": 1.0}  # helmet, visor, horns and plume
    if lo.y < -0.2 or (c.x < -0.31 and c.z > -0.1):
        return {"leg_fr": 1.0}  # the sword (its blade reaches forward) and the arm holding it
    if c.x > -0.17 and c.z > -0.05:
        return {"leg_fl": 1.0}  # the shield and the arm behind it
    if c.z < -0.08:
        return {"leg_bl" if c.x > -0.24 else "leg_br": 1.0}
    return {"body": 1.0}  # torso, belt, tassets and tabard


def hexbound(name, height, cx, neck, shoulder, hip, arm, artifact, what, reach=0.17, back=None, robe=False,
             swap=False, extra=None, ground=None):
    """SHANNON's ForgeGUI Shadow Legion (decision 0104): standing figures of separate pieces, facing -Y. A
    piece follows one bone by where its box is (`extra(lo, hi)` first, for a model's odd pieces): the head
    above the neck (z `neck`), the arms out to the sides past `arm` from the middle (x `cx`) above the hips
    (z `hip`), anything held out past `reach` (a weapon to the ground), the cape behind y `back`, the
    legs below the hips. A big piece (torso, robe, cloak) goes by its vertices instead: the head above the
    neck, the legs below the hips, unless it is a `robe` (it stays with the body, the feet walk under it).
    `swap`: the weapon is in the left (+X) hand, so that arm is `leg_fr`, the one a chop raises."""
    left, right = ("leg_fr", "leg_fl") if swap else ("leg_fl", "leg_fr")

    def pieces(lo, hi):
        if extra:
            w = extra(lo, hi)
            if w:
                return w
        c = (lo + hi) / 2
        dx = c.x - cx
        if lo.z > neck - 0.005 and abs(dx) < arm:
            return {"head": 1.0}
        if back is not None and lo.y > back and c.z < shoulder and hi.z - lo.z > 0.1:
            return {"tail": 1.0}
        if (c.z > hip and abs(dx) > arm) or abs(dx) > reach:
            return {left if dx > 0 else right: 1.0}
        if hi.z < hip + 0.03 and (not robe or hi.z < hip - 0.08):
            return {"leg_bl" if dx > 0 else "leg_br": 1.0}
        return None

    def weights(p):
        dx = p.x - cx
        hand = ramp(arm - 0.01, arm + 0.03, abs(dx)) * ramp(hip - 0.02, hip + 0.04, p.z)  # an arm grown on
        rest = 1 - hand
        head = rest * ramp(neck - 0.01, neck + 0.015, p.z)
        leg = 0.0 if robe else (rest - head) * ramp(hip + 0.02, hip - 0.03, p.z)
        w = {"body": rest - head - leg, "head": head, (left if dx > 0 else right): hand}
        if leg > 0:
            w["leg_bl" if dx > 0 else "leg_br"] = leg
        return {k: v for k, v in w.items() if v > 0.001}

    spec = {
        "height": height,
        "joints": {
            "body": (cx, 0.0, hip + 0.03),
            "head": (cx, 0.0, neck),
            left: (cx + arm, 0.0, shoulder),
            right: (cx - arm, 0.0, shoulder),
            "leg_bl": (cx + arm * 0.6, 0.0, hip),
            "leg_br": (cx - arm * 0.6, 0.0, hip),
            "tail": (cx, back if back is not None else 0.06, shoulder),
        },
        "weights": weights,
        "pieces": pieces,
        "small": 0.05,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), cut from its sheet, skinned to the Stations rig (decision 0104).",
    }
    if ground is not None:
        spec["ground"] = ground
    return spec


def mount(name, height, cx, cy, half, leg_top, head_y, tail_y, artifact, what):
    """A Shadow Legion rider on a horse (decision 0104), facing -Y: four-legged. The horse's legs move (below z
    `leg_top`, front ones ahead of y `cy`), its head (ahead of `head_y`) and tail (behind `tail_y`), both only
    below the rider (Roblox drops a bone nothing follows, and the game needs the head). Horse and rider are
    the body, so a lance, sword or banner never bends. The legs' joints are `half` ahead of and behind `cy`."""

    def weights(p):
        leg = ramp(leg_top, leg_top - 0.05, p.z)
        low = (1 - leg) * ramp(leg_top + 0.32, leg_top + 0.26, p.z)  # the horse, not the rider
        head = low * ramp(head_y, head_y - 0.04, p.y)
        tail = low * ramp(tail_y, tail_y + 0.04, p.y)
        bone = "leg_" + ("f" if p.y < cy else "b") + ("l" if p.x > cx else "r")
        w = {"body": 1 - leg - head - tail, bone: leg, "head": head, "tail": tail}
        return {k: v for k, v in w.items() if v > 0.001}

    return {
        "height": height,
        "joints": {
            "body": (cx, cy, leg_top + 0.08),
            "head": (cx, head_y, leg_top + 0.12),
            "leg_fl": (cx + 0.06, cy - half, leg_top),
            "leg_fr": (cx - 0.06, cy - half, leg_top),
            "leg_bl": (cx + 0.06, cy + half, leg_top),
            "leg_br": (cx - 0.06, cy + half, leg_top),
            "tail": (cx, tail_y, leg_top + 0.15),
        },
        "weights": weights,
        "small": 0.0,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), turned to face forward, skinned to the Stations rig as a four-legged mount (decision 0104).",
    }


def dragon(name, height, cx, cy, head_y, head_z, tail_y, leg_top, wing_x, wing_z, artifact, what):
    """A Shadow Legion dragon (decision 0104), facing -Y, with the old dragon's two wing bones: the wings out
    past `wing_x` from the middle (x `cx`) above z `wing_z` (`wing_l` on +X), the head ahead of y `head_y`
    above `head_z`, the tail behind `tail_y`, the legs below `leg_top` (front ones ahead of `cy`)."""

    def weights(p):
        dx = p.x - cx
        wing = ramp(wing_x, wing_x + 0.04, abs(dx)) * ramp(wing_z - 0.02, wing_z + 0.03, p.z)
        rest = 1 - wing
        head = rest * ramp(head_y, head_y - 0.04, p.y) * ramp(head_z - 0.02, head_z + 0.03, p.z)
        tail = (rest - head) * ramp(tail_y, tail_y + 0.04, p.y)
        leg = (rest - head - tail) * ramp(leg_top, leg_top - 0.04, p.z)
        w = {"body": rest - head - tail - leg, "head": head, "tail": tail, ("wing_l" if dx > 0 else "wing_r"): wing}
        if leg > 0:
            w["leg_" + ("f" if p.y < cy else "b") + ("l" if dx > 0 else "r")] = leg
        return {k: v for k, v in w.items() if v > 0.001}

    return {
        "height": height,
        "joints": {
            "body": (cx, cy, leg_top + 0.06),
            "head": (cx, head_y, head_z),
            "leg_fl": (cx + 0.06, cy - 0.07, leg_top),
            "leg_fr": (cx - 0.06, cy - 0.07, leg_top),
            "leg_bl": (cx + 0.06, cy + 0.07, leg_top),
            "leg_br": (cx - 0.06, cy + 0.07, leg_top),
            "tail": (cx, tail_y, leg_top + 0.06),
            "wing_l": (cx + wing_x, cy - 0.02, wing_z),
            "wing_r": (cx - wing_x, cy - 0.02, wing_z),
        },
        "weights": weights,
        "small": 0.03,
        "notes": f"{name}: SHANNON's {what} from ForgeGUI (artifact {artifact}), cut from its sheet and turned to face forward, skinned to the Stations rig with wings (decision 0104).",
    }


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
    "creature_lion_sun_forge": lion("Sun Lion", 16.05, 0.0, "efa580ee", "Fierce Low-Poly Sunmane Lion"),
    # heights: the Blender models' (StationAssets.creature_flamingo[_peacock, _phoenix].size)
    "creature_flamingo_forge": flamingo("Flamingo", 8.0, 0.0, 0.12, -0.17, -0.12, {"leg_fl": (0.06, 0.035), "leg_fr": (-0.069, 0.09)}, 0.0, 0.13, (0.09, 0.13), 0.06, "c9dca2cc", "pink flamingo"),
    "creature_flamingo_peacock_forge": flamingo("King Flamingo", 9.8, -0.06, 0.06, -0.18, -0.17, {"leg_fl": (0.05, 0.04), "leg_fr": (-0.05, 0.04)}, -0.06, 0.12, (0.1, 0.15), 0.12, "a84542a7", "peacock flamingo with a crown"),
    "creature_flamingo_phoenix_forge": flamingo("Phoenix Flamingo", 11.3, -0.03, 0.12, -0.2, -0.2, {"leg_fl": (0.088, -0.02), "leg_fr": (-0.088, -0.02)}, -0.08, 0.12, (0.11, 0.17), 0.25, "675a6361", "Flamingo of Fire"),
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
    "foe_knight_forge": {
        "height": 7.9,
        "ground": -0.219,  # its feet: the cape's tip hangs a little lower, into the floor
        "joints": {
            "body": (-0.24, 0.03, -0.03),
            "head": (-0.245, 0.05, 0.11),
            "leg_fl": (-0.15, 0.08, 0.1),  # the shield arm's shoulder
            "leg_fr": (-0.33, -0.01, 0.11),  # the sword arm's
            "leg_bl": (-0.165, 0.05, -0.04),
            "leg_br": (-0.3, -0.01, -0.04),
            "tail": (-0.3, 0.1, 0.12),  # the cape hangs from the shoulders
        },
        "weights": lambda p: {"body": 1.0},
        "pieces": knight_pieces,
        "small": 0.0,
        "notes": "Hexbound Knight: SHANNON's Shadow Knight from ForgeGUI (artifact 59c956fa), cut out of a whole-concept-sheet model, one mesh of rigid armour pieces skinned to the Stations rig (decision 0102).",
    },
    # the Shadow Legion (decision 0104): heights in studs from the feet up; `swap` for a weapon in the left hand
    "foe_knight_heavy_forge": hexbound("Heavy Knight", 9.0, 0.02, 0.09, 0.08, -0.09, 0.09, "49ffb084", "heavy knight (01:27)"),
    "foe_archer_forge": hexbound("Shadow Archer", 7.4, 0.0, 0.1, 0.11, -0.1, 0.09, "b23e1fe8", "Shadow Archer (01:29)", reach=0.15, back=0.06),
    "foe_archer_crossbow_forge": hexbound(
        "Crossbow Troop", 7.6, -0.205, 0.06, 0.08, -0.08, 0.08, "eec5a523", "Crossbow Troop (01:31)", back=0.05,
        extra=lambda lo, hi: {"body": 1.0} if lo.y > 0.05 and hi.z > 0.15 else None,  # the quiver on its back
    ),
    "foe_mage_forge": hexbound("Darkcaster", 8.0, -0.16, 0.077, 0.06, -0.12, 0.08, "fd99f263", "Darkcaster (01:32)", back=0.04, robe=True),
    "foe_mage_necromancer_forge": hexbound("Necromancer", 8.4, -0.22, 0.045, 0.035, -0.12, 0.08, "8d373a50", "Necromancer (01:34)", reach=0.16, back=0.1, robe=True),
    "foe_mage_priest_forge": hexbound("Battle Priest", 8.0, -0.21, 0.07, 0.05, -0.1, 0.09, "b78f38cc", "Battle Priest (01:36)", back=0.08, robe=True),
    "foe_knight_berserker_forge": hexbound("Berserker", 8.6, -0.22, 0.06, 0.05, -0.1, 0.1, "e4ece9c5", "Berserk Assault (01:40)", back=0.05, swap=True),
    "foe_ogre_forge": hexbound(
        "Ogre Enforcer", 10.5, -0.2, 0.035, 0.08, -0.12, 0.11, "01343e85", "Ogre Enforcer (01:41)", reach=0.2, swap=True,
        extra=lambda lo, hi: {"leg_fr": 1.0} if lo.z > 0.05 and hi.x - lo.x > 0.2 else None,  # the club over its shoulder
    ),
    "foe_ogre_commander_forge": hexbound(
        "Ogre Commander", 12.5, -0.005, 0.03, 0.06, -0.17, 0.12, "a5fe2fe0", "Ogre Commander (01:42)", reach=0.2, back=0.07, swap=True,
        extra=lambda lo, hi: {"body": 1.0} if lo.y > 0.04 and hi.z > 0.15 else None,  # the banner on its back
    ),
    "foe_golem_forge": hexbound("Siege Golem", 12.0, -0.18, 0.1, 0.06, -0.13, 0.13, "0446aea7", "Siege Golem (01:56)", reach=0.22),
    "foe_knight_shield_forge": hexbound("Shieldbearer", 8.0, -0.37, 0.08, 0.05, -0.125, 0.07, "23742e89", "Shieldbearer (02:00)", reach=0.07),
    "foe_knight_shield_commander_forge": hexbound(
        "Shieldbearer Commander", 9.5, -0.295, 0.18, 0.13, 0.03, 0.07, "0b26e3c4", "Shieldbearer Commander (02:01)", reach=0.1
    ),
    "foe_cavalry_forge": mount("Cavalry", 11.0, -0.125, 0.06, 0.15, -0.17, -0.17, 0.3, "62f553d0", "Cavalry (01:45)"),
    "foe_cavalry_commander_forge": mount(
        "Cavalry Commander", 14.0, 0.0, -0.03, 0.28, -0.33, -0.38, 0.33, "69969c83", "Cavalry Commander (01:48)"
    ),
    "foe_dragon_drake_forge": dragon("Dark Drake", 9.0, -0.14, 0.1, 0.0, 0.02, 0.22, -0.09, 0.1, 0.0, "b91a8625", "Dark Drake (01:49)"),
    "foe_dragon_forge": dragon("Shadow Dragon", 13.0, -0.08, 0.12, -0.03, 0.02, 0.25, -0.08, 0.12, 0.05, "435d1dd3", "Shadow Dragon (01:50)"),
    "foe_dragon_alpha_forge": dragon("Ancient Alpha Dragon", 16.0, 0.0, 0.15, 0.08, 0.08, 0.3, -0.05, 0.1, 0.05, "f52635f1", "Ancient Alpha Dragon (01:54)"),
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


def roblox(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    name, src = args[0], args[1]
    test = "--test" in args
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
        w = spec["pieces"](ilo, ihi) if "pieces" in spec else None  # rigid pieces: each follows one bone
        if w is not None:
            for i in island:
                weights[i] = w
            print("PIECE", max(w, key=w.get), [round(x, 3) for x in (*ilo, *ihi)])
        elif (ihi - ilo).length < spec["small"]:
            whole += 1
            mean = {}
            for i in island:
                for k, w in weights[i].items():
                    mean[k] = mean.get(k, 0) + w / len(island)
            for i in island:
                weights[i] = mean
    bm.free()
    counts = {}
    for w in weights:
        top = max(w, key=w.get)
        counts[top] = counts.get(top, 0) + 1
    print("ISLANDS", islands, "moving whole", whole, "VERTS BY MAIN BONE", counts)

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
        b.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")

    # the skin
    groups = {k: body.vertex_groups.new(name=k) for k in joints}
    for v, w in zip(body.data.vertices, weights):
        for bone, x in w.items():
            groups[bone].add([v.index], x, "REPLACE")
    body.parent = arm
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = arm

    out = kit.OUT
    os.makedirs(out, exist_ok=True)
    # the model's own texture, as the PNG the upload sends
    image = next((img for img in bpy.data.images if img.size[0] > 0), None)
    if image is None:
        raise RuntimeError(f"{name}: the model has no texture")
    png = os.path.join(out, f"{name}.png")
    if image.size[0] > 1024:  # what a Roblox texture shows at most
        image.scale(1024, 1024)
    image.filepath_raw = png
    image.file_format = "PNG"
    image.save()
    print("TEXTURE", image.size[0], image.size[1])

    if test:  # bend it: the head, a front and a hind leg forward, the tail up
        for mat in body.data.materials:  # draw only fronts, as Roblox does
            mat.use_backface_culling = True
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
