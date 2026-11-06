"""Lantern Express critters to the Egg Garden HD creature standard (tools/blender/garden/README.md
"Creature standard"), dusk-toned and lantern-themed (docs/game-design/game6-art-bible.md section 4).
One mesh each, standing on the origin, facing Blender -Y, 2.0 to 3.5 tall within a 3 x 3 footprint
(docs/architecture/lantern.md section 9). The reference build is critter_emberkit."""

import math
import os
import sys

import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "garden", "assets"))
from creatures_a import capsules, snout_face, spline  # noqa: E402


def swap(ob, m):
    ob.data.materials[0] = m
    return ob


def stand(parts, height):
    """Uniform scale to `height` studs, centred and standing on the origin, so round shapes stay
    round. Paints that depend on position are swapped in after this."""
    lo, hi = k._ground_dims(parts)
    s = height / (hi.z - lo.z)
    m = Matrix.Translation((-(lo.x + hi.x) / 2 * s, -(lo.y + hi.y) / 2 * s, -lo.z * s)) @ Matrix.Scale(s, 4)
    for ob in parts:
        ob.data.transform(m)
    print(f"[critters] uniform scale {s:.2f}", flush=True)
    return m


def zspan(ob):
    lo, hi = k._ground_dims([ob])
    return lo.z, hi.z


def paper_lantern(centre, r, m, rim, bail, name="lantern"):
    """Round paper lantern (chochin) hanging from its bail at the top: body, two caps, the bail."""
    x, y, z = centre
    h = r * 1.75
    z0 = z - h / 2
    body = k.lathe([(r * 0.42, 0.04 * h), (r * 0.75, 0.12 * h), (r * 0.96, 0.3 * h), (r, 0.5 * h), (r * 0.96, 0.7 * h), (r * 0.75, 0.88 * h), (r * 0.42, 0.96 * h)],
                   loc=(x, y, z0), m=m, n=20, name=name)
    caps = [k.lathe([(0, -0.02 * h), (r * 0.5, -0.02 * h), (r * 0.55, 0.05 * h), (r * 0.5, 0.11 * h), (0, 0.11 * h)], loc=(x, y, z0), m=rim, n=16, name="cap"),
            k.lathe([(0, 0.89 * h), (r * 0.5, 0.89 * h), (r * 0.55, 0.95 * h), (r * 0.5, 1.02 * h), (0, 1.02 * h)], loc=(x, y, z0), m=rim, n=16, name="cap")]
    top = z0 + 1.02 * h
    hook = k.tube([(x - r * 0.35, y, top - 0.02), (x - r * 0.3, y, top + r * 0.35), (x, y, top + r * 0.52), (x + r * 0.3, y, top + r * 0.35), (x + r * 0.35, y, top - 0.02)],
                  r * 0.06, m=bail, n=6, name="bail")
    return [body, *caps, hook], Vector((x, y, top + r * 0.52))


def critter_emberkit():
    """Ember Kit (GDD H4 `emberkit`, the monthly login exclusive and the game's mascot): a
    periwinkle fox kit in a conductor's cap with an ember-tipped tail, holding a tiny glowing paper
    lantern out on a stick. HD standard: one fused body (the Cactus Fox's
    proportions), the kit face on a snout, smooth separate props."""
    fur = k.flat(k.PERIWINKLE)
    cream_rgb = (255, 244, 228)
    cream, peach = k.flat(cream_rgb), k.flat((255, 180, 176))
    head, R = Vector((0, -0.3, 2.5)), 1.05
    snout = Vector((0, -1.3, 2.18))
    tilt = 20
    ear = Vector((0.76, -0.1, 3.4))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    tail = spline([(-0.25, 0.9, 0.5), (-0.85, 1.3, 0.7), (-1.3, 1.45, 1.3), (-1.42, 1.3, 2.0), (-1.25, 1.0, 2.6)], [0.26, 0.46, 0.54, 0.44, 0.08], 16)
    hand = Vector((1.18, -0.72, 1.55))  # the raised paw that holds the stick, clear of the muzzle
    body = k.fuse(
        [
            (head, R, (1.15, 0.98, 0.92)),
            (snout, 0.42, (1.0, 1.2, 0.7)),
            *k.pair((0.98, -0.5, 2.15), 0.3, (0.8, 0.6, 0.6), (0, 0, 20)),  # cheek fluff
            ((0, 0.1, 1.25), 0.85, (1.0, 1.1, 0.95)),  # chest
            ((0, 0.25, 0.68), 0.85, (1.12, 1.2, 0.78)),  # round seat
            *k.pair(ear, 0.56, (0.85, 0.32, 0.8), (0, tilt, 0)),  # big ears: a wide base...
            *k.pair(ear + axis * 0.5, 0.34, (0.55, 0.3, 1.0), (0, tilt, 0)),  # ...tapering to the tip
            *k.pair((0.5, -0.55, 0.2), 0.3, (0.9, 1.45, 0.62)),  # feet
            ((-0.72, -0.45, 1.25), 0.19, (0.85, 0.9, 1.3)),  # resting arm
            ("capsule", (0.66, -0.3, 1.42), hand, 0.19),  # raised arm
            (hand, 0.22),
            *capsules(tail),
        ],
        fur,
        tris=2750,
    )
    parts = [body]
    for side in (-1, 1):
        up = (side * axis.x, 0, axis.z)
        mid = ear + axis * 0.18
        parts.append(k.lens(body, (side * mid.x, mid.y, mid.z), (0, -1, 0), 0.38, peach, scale=(0.56, 1), thick=0.2, sink=0.6, up=up, seg=12, name="ear_in"))

    # Conductor's cap, tipped forward and a little to the side, between the ears.
    cap_parts = [
        k.lathe([(0.4, -0.05), (0.42, 0.05), (0.45, 0.28), (0.5, 0.36), (0.44, 0.42), (0.2, 0.45), (0, 0.46)], m=k.flat(k.CRANBERRY), n=20, name="cap"),
        k.lathe([(0.425, 0.04), (0.445, 0.07), (0.455, 0.17), (0.44, 0.2)], m=k.flat((240, 190, 92)), n=20, name="cap_band"),
        k.sphere(0.4, (0, -0.3, 0.03), m=k.flat(k.IRON), scale=(1.0, 0.75, 0.1), seg=16, rings=4, name="visor"),
        k.sphere(0.09, (0, -0.445, 0.25), m=k.flat((255, 214, 128)), scale=(1, 0.5, 1), seg=10, rings=4, name="badge"),
    ]
    top, n = k.land(body, head + Vector((0, -0.25, 0)), (0, -0.25, 1))
    place = Matrix.Translation(top - n * 0.1) @ Matrix.Rotation(math.radians(12), 4, "X") @ Matrix.Rotation(math.radians(8), 4, "Y")
    for ob in cap_parts:
        ob.data.transform(place)
    parts += cap_parts

    # The lantern on a stick: the stick rises from the paw, a small hook at its tip holds the bail.
    d = Vector((0.3, -0.25, 1.0)).normalized()
    tip_pt = hand + d * 1.55
    hook_end = tip_pt + Vector((0.3, -0.06, -0.02))
    wood = k.flat((150, 104, 74))
    parts.append(k.capsule(hand - d * 0.32, tip_pt, 0.07, 0.06, wood, n=8, name="stick"))
    parts.append(k.tube([tip_pt, tip_pt + Vector((0.16, -0.03, 0.08)), hook_end], [0.055, 0.05, 0.045], m=wood, n=8, name="hook"))
    r = 0.34
    # Centre so the bail's top (1.43 r above it) passes through the hook.
    lamp, _ = paper_lantern((hook_end.x, hook_end.y, hook_end.z - 1.43 * r), r, k.flat(k.AMBER), k.flat(k.CRANBERRY), k.flat((110, 70, 60)))
    parts += lamp

    parts += snout_face(body, snout, cream_rgb, k.NOSE, mouth_w=0.2, muzzle_r=0.38, muzzle_scale=(1.05, 0.85))
    parts += k.face(body, head, R, skin=k.PERIWINKLE, nose=None, mouth_kind=None, eye_phi=8, spread=36)

    m = stand(parts, 2.9)  # 2.9 tall keeps the lantern inside the 3 x 3 footprint
    s = m.to_scale().x
    # Position-dependent paints, after the scale: dusk fur (darker socks), and the ember tail tip
    # and cream chest as paint marks (spheres round a point), whose edges stay clean where a separate
    # piece would cut a ragged line through the decimated body.
    tip_c = tail[-1][0]  # the tail tip curls forward, so a bigger sphere would reach the head
    marks = [((255, 140, 66), m @ tip_c, 0, 0.6 * s), ((255, 206, 112), m @ tip_c, 0, 0.32 * s), (cream_rgb, m @ Vector((0, -0.42, 1.12)), 0, 0.56 * s)]
    for side in (-1, 1):  # dark ear tips, the clearest fox cue
        e = ear + axis * 0.95
        marks.append(((62, 64, 150), m @ Vector((side * e.x, e.y, e.z)), 0, 0.42 * s))
    lo, hi = zspan(body)
    swap(body, k.paint("ek_fur", [(0, (78, 86, 194)), (0.1, k.PERIWINKLE_DEEP), (0.55, (140, 158, 248)), (1, (174, 190, 255))], lo, hi, marks=marks))
    lo, hi = zspan(lamp[0])
    swap(lamp[0], k.paint("ek_lamp", [(0, (255, 150, 55)), (0.5, (255, 196, 100)), (1, (255, 168, 68))], lo, hi, bands=((255, 180, 86), 0.08), emit=0.45))
    lo, hi = zspan(cap_parts[0])
    swap(cap_parts[0], k.paint("ek_cap", [(0, k.CRANBERRY_DEEP), (1, (220, 74, 80))], lo, hi))
    return parts


NOTES = ("One mesh, stands on the origin facing -Y; scale to the manifest height. The mascot and the reference critter for the HD standard. "
         "The lantern is baked bright, no Neon: code adds a small amber PointLight (range 8, brightness 1.5) at the lantern, on the viewer's right about 0.55 of the height up.")
ASSETS = [
    dict(name="critter_emberkit", build=critter_emberkit, budget=k.CREATURE_BUDGET, finalize=k.HD, size=[2.9, 2.9, 2.8], priority=1, order=1,
         replaces="critter fallback (two balls, ears and the rarity colour)", notes=NOTES, glow={}),
]
