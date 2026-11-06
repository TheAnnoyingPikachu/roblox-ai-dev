"""Lantern Express critters to the Egg Garden HD creature standard (tools/blender/garden/README.md
"Creature standard"), dusk-toned and lantern-themed (docs/game-design/game6-art-bible.md section 4).
One mesh each, standing on the origin, facing Blender -Y, 2.0 to 3.5 tall within a 3 x 3 footprint
(docs/architecture/lantern.md section 9). The reference build is critter_emberkit."""

import math
import os
import sys

import bpy
import kit as k
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "garden", "assets"))
from creatures_a import band, capsules, petal, snout_face, spline, xf  # noqa: E402
from creatures_b import aim, disc, onto, petals, split, star  # noqa: E402


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


# Helpers for the twelve rolled critters --------------------------------------------------------


def fur(ob, name, rgb, marks=(), deep=None):
    """The family's dusk skin from one colour: deep at the feet, `rgb` round the middle, paler at
    the crown (the Ember Kit's ramp). Call after `stand`."""
    lo, hi = zspan(ob)
    deep = deep or k.shade(rgb, 0.56)
    return swap(ob, k.paint(name, [(0, deep), (0.1, k.mix(deep, rgb, 0.4)), (0.55, k.shade(rgb, 0.96)), (1, k.mix(rgb, (255, 255, 255), 0.16))], lo, hi, marks=marks))


def lamp(ob, name, rgb=(255, 196, 100)):
    """Baked-bright lantern glass (the Ember Kit's): warm ends, a bright middle, faint paper ribs."""
    lo, hi = zspan(ob)
    return swap(ob, k.paint(name, [(0, k.mix(rgb, (255, 140, 50), 0.6)), (0.5, rgb), (1, k.mix(rgb, (255, 160, 60), 0.4))], lo, hi, bands=(k.mix(rgb, (255, 170, 80), 0.5), 0.08), emit=0.45))


def ear_in(body, ear, tilt, r, m, scale=(0.56, 1), lift=0.18):
    """Inner ears (README): a lens on each ear's front along the ear's tilted axis."""
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    out = []
    for side in (-1, 1):
        mid = Vector(ear) + axis * lift
        out.append(k.lens(body, (side * mid.x, mid.y, mid.z), (0, -1, 0), r, m, scale=scale, thick=0.2, sink=0.6, up=(side * axis.x, 0, axis.z), seg=12, name="ear_in"))
    return out


def tail_tube(points, radii, m, steps=14, name="tail"):
    """A thin smooth tail (mouse, mole) as one tube: too thin for fuse without beads."""
    s = spline(points, radii, steps)
    return k.tube([p for p, _ in s], [r for _, r in s], m=m, n=10, name=name)


# Moss Mouse (common) ---------------------------------------------------------------------------


def critter_mossmouse():
    """Moss Mouse (common, all tiles): a round grey mouse with big round ears and a pink tail, a
    moss cushion for a cap, holding up a dandelion seed like a parasol whose fluff glows like a
    tiny lantern."""
    grey = (170, 164, 198)
    head, R = Vector((0, -0.15, 2.3)), 1.05
    ear, tilt = Vector((0.98, 0.05, 3.15)), 20
    hand = Vector((1.02, -0.62, 1.5))
    body = k.fuse(
        [
            (head, R, (1.2, 0.98, 0.9)),
            ((0, -0.98, 2.02), 0.36, (1.15, 1.0, 0.8)),  # small muzzle
            ((0, 0.1, 1.2), 0.8, (1.0, 1.05, 0.95)),  # chest
            ((0, 0.22, 0.65), 0.85, (1.15, 1.15, 0.78)),  # round seat
            *k.pair(ear, 0.6, (1.0, 0.4, 0.95), (0, tilt, 0)),  # big round ears
            *k.pair((0.48, -0.5, 0.2), 0.28, (0.9, 1.45, 0.62)),  # feet
            ((-0.72, -0.4, 1.2), 0.18, (0.85, 0.9, 1.3)),  # resting arm
            ("capsule", (0.62, -0.25, 1.35), hand, 0.18),  # raised arm on the stalk
            (hand, 0.2),
        ],
        k.flat(grey),
        tris=2700,
    )
    pink = k.flat((250, 170, 196))
    parts = [body, *ear_in(body, ear, tilt, 0.44, pink, scale=(0.72, 0.8), lift=0.02)]
    parts.append(tail_tube([(0.15, 0.95, 0.3), (0.7, 1.4, 0.28), (1.2, 1.32, 0.7), (1.08, 0.98, 1.12), (0.8, 1.02, 1.3)], [0.12, 0.1, 0.08, 0.065, 0.05], k.flat((214, 164, 192))))

    # Moss cushion: soft clumps fused into one cap, set on the crown between the ears.
    clumps = [((0, 0, 0.12), 0.45, (1.2, 1.15, 0.72)), ((0.12, 0.08, 0.36), 0.2)] + [((0.42 * math.cos(a), 0.4 * math.sin(a), 0.06), 0.24, (1, 1, 0.85)) for a in (math.radians(30 + 60 * i) for i in range(6))]
    cap = k.fuse(clumps, k.flat((110, 150, 104)), tris=420, soft=0.35, name="moss")
    sprout = [k.capsule((0.1, 0.0, 0.3), (0.16, -0.02, 0.55), 0.035, 0.03, k.flat((120, 170, 100)), n=8, name="sprout")]
    sprout += xf(k.leaf(0.26, 0.1, k.flat((150, 196, 116)), droop=0.3, n=8, steps=8), (0.16, -0.02, 0.54), yaw=-20, pitch=25)
    sprout += xf(k.leaf(0.22, 0.09, k.flat((128, 182, 106)), droop=0.3, n=8, steps=8), (0.16, -0.02, 0.54), yaw=190, pitch=30)
    parts += onto([cap, *sprout], body, head, (0, -0.2, 1), up=(0, 1, 0), sink=0.1)

    # The dandelion seed: seed at the paw, a long beak up, the fluff open above like a parasol.
    d = Vector((0.12, -0.06, 1)).normalized()
    top = hand + d * 1.55
    cream = k.flat((240, 230, 210))
    seed = [k.capsule(hand - d * 0.62, hand - d * 0.3, 0.05, 0.075, k.flat((176, 136, 100)), n=10, name="achene"),
            k.capsule(hand - d * 0.32, top, 0.035, 0.03, cream, n=8, name="beak")]
    r, cup, thick = 0.66, 0.5, 0.08
    fluff = disc(r, petals(12, 0.4, 0.7), k.flat((255, 236, 186)), n=60, cup=cup, thick=thick, name="pappus")
    knot = k.sphere(0.08, (0, 0, r * thick), m=k.flat((255, 196, 100), emit=0.6), seg=12, rings=6, name="knot")
    rays = []  # a fine ray along each lobe: the seed's silk
    for i in range(12):
        a = 2 * math.pi * i / 12
        pts = [(r * t * math.cos(a), r * t * math.sin(a), r * (cup * t * t + thick * (1 - t * t)) + 0.012) for t in (0.1, 0.55, 0.95)]
        rays.append(k.tube(pts, [0.016, 0.014, 0.008], m=k.flat((255, 250, 236)), n=4, name="silk"))
    seed += aim([fluff, knot, *rays], top, d)
    parts += seed
    parts += k.face(body, head, R, skin=grey, nose=(236, 128, 160))

    m = stand(parts, 2.0)
    s = m.to_scale().x
    fur(body, "mm_fur", grey, marks=[((236, 228, 236), m @ Vector((0, -0.62, 1.05)), 0, 0.5 * s), ((226, 218, 232), m @ Vector((0, -1.25, 1.98)), 0, 0.3 * s)])
    lo, hi = zspan(cap)
    swap(cap, k.paint("mm_moss", [(0, (78, 120, 88)), (1, (128, 176, 112))], lo, hi, splat=[((142, 186, 114), 22, 0.64, lo, hi + 1)]))
    lo, hi = zspan(fluff)
    swap(fluff, k.paint("mm_fluff", [(0, (255, 184, 92)), (0.45, (255, 212, 136)), (1, (255, 236, 188))], lo, hi, emit=0.7))
    return parts


# Puddle Frog (common) --------------------------------------------------------------------------


def critter_puddlefrog():
    """Puddle Frog (common, farm, mill, lighthouse, boathouse): a fat teal frog, eyes on two bumps
    (the Garden frog), wearing a walnut-shell boat as a hat: a matchstick mast, a leaf sail and a
    tiny paper lantern at the masthead."""
    teal = (108, 190, 174)
    head, R = Vector((0, -0.2, 1.75)), 1.05
    bumps = [Vector((side * 0.62, -0.68, 2.42)) for side in (-1, 1)]
    body = k.fuse(
        [
            (head, R, (1.32, 1.0, 0.82)),
            ((0, 0.25, 0.82), 1.08, (1.24, 1.15, 0.78)),  # fat round seat
            *[(b, 0.47) for b in bumps],
            *k.pair((1.04, 0.3, 0.52), 0.5, (0.75, 1.25, 0.72)),  # folded back legs
            *k.pair((1.2, -0.45, 0.14), 0.3, (0.9, 1.5, 0.55), (0, 0, -18)),  # back feet
            ("capsule", (0.58, -0.55, 0.68), (0.62, -0.86, 0.24), 0.21),  # front legs
            ("capsule", (-0.58, -0.55, 0.68), (-0.62, -0.86, 0.24), 0.21),
            *k.pair((0.64, -0.98, 0.15), 0.27, (0.9, 1.4, 0.6)),  # front paws
        ],
        k.flat(teal),
        tris=2900,
    )
    parts = [body]
    belly = k.lens(body, (0, 0.25, 0.62), (0, -1, 0), 0.64, k.flat((214, 236, 204)), scale=(1.15, 0.8), thick=0.2, sink=0.6, name="belly")
    parts.append(belly)

    # The walnut-shell boat, along x, sitting on the crown behind the eye bumps.
    shell = k.lathe([(0, 0), (0.3, 0.02), (0.5, 0.1), (0.6, 0.22), (0.62, 0.34), (0.57, 0.37), (0.5, 0.27), (0.3, 0.17), (0, 0.15)], m=k.flat((150, 100, 70)), n=28, scale=(1.3, 0.78, 1), name="walnut")
    mast_top = Vector((0.06, 0.02, 1.02))
    wood = k.flat((222, 196, 150))
    boat = [shell, k.capsule((0.06, 0.02, 0.12), mast_top, 0.035, 0.03, wood, n=8, name="mast"),
            k.capsule((0.06, 0.02, 0.88), (0.32, 0.02, 0.92), 0.025, 0.022, wood, n=8, name="yard")]
    sail = petal(0.62, 0.22, k.flat((150, 196, 132)), droop=0.06, tip=1.0, base=0.5, n=8, steps=10, name="sail")
    sail.data.transform(Matrix.Translation((0.0, 0.03, 0.3)) @ Matrix.Rotation(math.radians(-90), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "X"))
    boat.append(sail)
    hook = Vector((0.32, 0.02, 0.9))
    lantern, _ = paper_lantern((hook.x, hook.y, hook.z - 1.43 * 0.19), 0.19, k.flat(k.AMBER), k.flat(k.CRANBERRY), k.flat((110, 70, 60)))
    boat += lantern
    for ob in boat:
        ob.data.transform(Matrix.Scale(1.3, 4))
    parts += onto(boat, body, head + Vector((0, 0.15, 0)), (0, 0.12, 1), up=(0, 1, 0), spin=0, sink=0.14)

    # Face by hand (the Garden frog): eyes look out from the bumps.
    k.texel(body, k.FACE_TEXEL, head + Vector((0, -R, 0.2)), R * 1.1)
    face = []
    for side, b in zip((-1, 1), bumps):
        face += k.eye(body, b, k.outward(side * 14, 6), R * 0.24)
        face.append(k.lens(body, head, k.outward(side * 50, -14), R * 0.17, k.flat(k.mix(teal, k.BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
        face.append(k.lens(body, head, k.outward(side * 7, 2), 0.035, k.flat(k.NOSE), thick=0.5, sink=0.5, seg=12, name="nostril"))
    face.append(k.mouth(body, head, k.outward(0, -18), 0.5, k.flat(k.INKY), "smile", r=0.045))
    parts += k.texel(face, k.FACE_TEXEL)

    m = stand(parts, 2.0)
    s = m.to_scale().x
    spots = [((70, 140, 140), m @ Vector(p), 0, r * s) for p, r in (((0.5, 0.95, 1.2), 0.2), ((-0.35, 1.05, 0.9), 0.16), ((0.0, 0.9, 1.55), 0.13), ((-0.85, 0.6, 1.35), 0.14), ((1.0, 0.2, 1.5), 0.12))]
    fur(body, "pf_skin", teal, marks=spots)
    lo, hi = zspan(shell)
    swap(shell, k.paint("pf_walnut", [(0, (116, 76, 58)), (1, (184, 134, 92))], lo, hi, grain=(0.3, 7, "noise")))
    lamp(lantern[0], "pf_lamp")
    return parts


# Wick Mole (common) ----------------------------------------------------------------------------


def candle(r, h, wax_rgb=(255, 236, 206)):
    """A candle stub at the origin, +Z up: a brass dish, a wax stub with three soft drips, the wick
    and a teardrop flame. Returns (parts, wax, flame) for the paints after `stand`."""
    brass = k.flat((222, 168, 80))
    wax = k.lathe([(0, 0), (r, 0), (r, h * 0.92), (r * 0.9, h), (0.3 * r, h * 0.96), (0, h * 0.98)], m=k.flat(wax_rgb), n=24, name="wax")
    dish = k.lathe([(0, -0.05 * h), (r * 1.7, -0.05 * h), (r * 1.85, 0.12 * h), (r * 1.7, 0.16 * h), (r * 1.2, 0.04 * h), (0, 0.04 * h)], m=brass, n=28, name="dish")
    drips = [k.capsule((r * 0.98 * math.cos(a), r * 0.98 * math.sin(a), h * 0.95), (r * 1.02 * math.cos(a), r * 1.02 * math.sin(a), h * t), 0.22 * r, 0.26 * r, k.flat(wax_rgb), n=10, name="drip")
             for a, t in ((math.radians(-100), 0.45), (math.radians(-35), 0.62), (math.radians(150), 0.55))]
    wick = k.capsule((0, 0, h * 0.9), (0.02 * r, 0, h + 0.28 * r), 0.07 * r, 0.06 * r, k.flat((80, 60, 70)), n=8, name="wick")
    f = 1.6 * r
    flame = k.lathe([(0, 0), (0.42 * f, 0.12 * f), (0.55 * f, 0.38 * f), (0.48 * f, 0.68 * f), (0.28 * f, 1.0 * f), (0, 1.32 * f)], loc=(0.02 * r, 0, h + 0.12 * r), m=k.flat((255, 200, 90), emit=0.8), n=20, name="flame")
    return [dish, wax, *drips, wick, flame], wax, flame


def critter_wickmole():
    """Wick Mole (common, village, inn, mill, orchard): a velvet plum mole, pear-shaped with a pink
    snout and two big round pink digging paws held up, a lit candle stub stuck on its head."""
    velvet = (134, 118, 176)
    head, R = Vector((0, -0.2, 2.15)), 1.05
    snout = Vector((0, -1.25, 1.9))
    body = k.fuse(
        [
            (head, R, (1.15, 1.0, 0.92)),
            (snout, 0.36, (1.0, 1.25, 0.8)),  # pointed snout
            ((0, 0.1, 1.15), 0.95, (1.08, 1.05, 0.95)),  # pear body
            ((0, 0.25, 0.6), 0.95, (1.18, 1.15, 0.7)),  # round seat
            *k.pair((0.48, -0.55, 0.18), 0.28, (0.9, 1.4, 0.6)),  # feet
            ("capsule", (0.66, -0.35, 1.15), (0.6, -0.92, 1.12), 0.2),  # arms forward to the paws
            ("capsule", (-0.66, -0.35, 1.15), (-0.6, -0.92, 1.12), 0.2),
            ("capsule", (0, 1.0, 0.45), (0, 1.32, 0.38), 0.12),  # stub tail
        ],
        k.flat(velvet),
        tris=2600,
    )
    pink = (246, 160, 184)
    parts = [body]
    for side in (-1, 1):  # big round spade paws, palms out and forward
        paw = k.sphere(0.34, (side * 0.66, -1.1, 1.14), m=k.flat(pink), scale=(1.0, 0.45, 1.0), rot=(0, 0, side * 22), seg=20, rings=10, name="paw")
        parts.append(paw)
    stub, wax, flame = candle(0.3, 0.42)
    parts += onto(stub, body, head + Vector((0, 0.1, 0)), (0.18, 0.05, 1), up=(0, 1, 0), sink=0.06)
    parts += snout_face(body, snout, k.mix(velvet, (255, 236, 236), 0.45), (236, 120, 150), nose_r=0.15, mouth_w=0.2, muzzle_r=0.36, muzzle_scale=(1.0, 0.9))
    parts += k.face(body, head, R, skin=velvet, nose=None, mouth_kind=None, eye_phi=8, spread=36)

    m = stand(parts, 2.1)
    s = m.to_scale().x
    fur(body, "wm_fur", velvet, marks=[(k.mix(velvet, (240, 226, 240), 0.4), m @ Vector((0, -0.75, 1.0)), 0, 0.62 * s)])
    lo, hi = zspan(flame)
    swap(flame, k.paint("wm_flame", [(0, (255, 120, 40)), (0.4, (255, 172, 64)), (1, (255, 222, 120))], lo, hi, emit=0.9))
    return parts


# Burr Bunny (common) ---------------------------------------------------------------------------


def physalis(R, h, m, ribs=5):
    """A Chinese-lantern seed pod at the origin hanging from +Z: a papery husk with `ribs` soft ribs,
    widest near the top, closing to a soft point at the bottom."""

    def fn(u, v):
        a = 2 * math.pi * u
        r = R * math.sin(math.pi * v) ** 0.75 * (0.7 + 0.3 * v) * (1 + 0.1 * math.cos(ribs * a))
        return (r * math.cos(a), r * math.sin(a), h * v)

    return k.surface(30, 10, fn, m=m, name="physalis")


def critter_burrbun():
    """Burr Bunny (common, farm, windmill, orchard, village): a cream bunny with one ear up and one
    flopped, soft olive burrs caught in its fur, holding up a glowing Chinese-lantern seed pod."""
    cream = (248, 232, 210)
    head, R = Vector((0, -0.05, 2.2)), 1.0
    ear, tilt = Vector((0.42, 0.02, 3.2)), 14
    hand = Vector((0.82, -0.72, 1.5))
    body = k.fuse(
        [
            (head, R, (1.2, 0.95, 0.9)),
            ((0, 0.1, 1.05), 0.86, (1.12, 1.0, 0.95)),  # chest
            ((0, 0.05, 0.62), 0.8, (1.22, 1.05, 0.7)),  # round seat
            (ear, 0.62, (0.4, 0.2, 1.0), (0, tilt, 0)),  # the upright ear
            ((-0.4, 0.02, 2.95), 0.36, (0.5, 0.26, 0.8), (0, -14, 0)),  # the flopped ear's root...
            ((-0.98, -0.04, 3.0), 0.6, (1.0, 0.22, 0.36), (0, -38, 0)),  # ...and its fall to the side
            *k.pair((0.48, -0.42, 0.2), 0.3, (0.9, 1.45, 0.62)),  # feet
            ((-0.66, -0.4, 1.0), 0.17, (0.85, 0.9, 1.3)),  # resting arm
            ("capsule", (0.58, -0.25, 1.2), hand, 0.17),  # raised arm on the stem
            (hand, 0.19),
        ],
        k.flat(cream),
        tris=2700,
    )
    pink = k.flat((255, 176, 200))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    parts = [body, k.lens(body, ear + axis * 0.05, (0, -1, 0), 0.42, pink, scale=(0.34, 1), thick=0.2, sink=0.6, up=axis, seg=12, name="ear_in"),
             k.blob(0.3, (0, 0.92, 0.72), k.flat((255, 246, 232)), name="tail")]

    # Soft burrs caught in the fur: round domes, kept off the face.
    burr = k.flat((150, 156, 98))
    for c, d in (((0, 0.1, 1.05), k.outward(-70, 10)), ((0, 0.1, 1.05), k.outward(110, -10)), ((0, 0.1, 1.05), k.outward(160, 20)), ((0, 0.1, 1.05), k.outward(-140, -15)),
                 ((0, 0.05, 0.62), k.outward(80, -5)), (head, k.outward(-150, 40)), (head, k.outward(130, 25)), (head, k.outward(75, 52))):
        parts.append(k.lens(body, c, d, 0.15, burr, thick=1.0, sink=0.12, seg=12, name="burr"))

    # The seed pod hangs from a bent stem held in the raised paw.
    stem_top = hand + Vector((0.12, -0.05, 0.95))
    green = k.flat((120, 150, 96))
    parts.append(k.capsule(hand - Vector((0, 0, 0.25)), stem_top, 0.045, 0.04, green, n=8, name="stem"))
    tip = stem_top + Vector((0.3, -0.04, -0.04))
    parts.append(k.tube([stem_top, stem_top + Vector((0.16, -0.02, 0.07)), tip], [0.04, 0.038, 0.036], m=green, n=8, name="stem"))
    pod = physalis(0.36, 0.82, k.flat((255, 150, 60)))
    pod.data.transform(Matrix.Translation(tip - Vector((0, 0, 0.84))))
    parts += [pod, k.capsule(tip + Vector((0, 0, 0.04)), tip - Vector((0, 0, 0.1)), 0.06, 0.05, green, n=8, name="calyx")]
    parts += k.face(body, head, R, skin=cream, nose=(240, 130, 160))

    m = stand(parts, 2.3)
    s = m.to_scale().x
    fur(body, "bb_fur", cream, deep=(196, 172, 170), marks=[((255, 246, 234), m @ Vector((0, -0.55, 1.0)), 0, 0.48 * s)])
    for ob in parts:
        if ob.name.startswith("burr"):
            lo, hi = zspan(ob)
            swap(ob, k.paint("bb_burr", [(0, (112, 132, 76)), (1, (170, 184, 104))], lo, hi, dots=[((214, 214, 150), 90, 0.25)]))
            break
    lo, hi = zspan(pod)
    swap(pod, k.paint("bb_pod", [(0, (255, 120, 44)), (0.55, (255, 172, 76)), (1, (255, 140, 56))], lo, hi, emit=0.75))
    return parts


# Lantern Beetle (uncommon) ---------------------------------------------------------------------


def critter_lanternbeetle():
    """Lantern Beetle (uncommon, farm, windmill, orchard, village): a round blue-violet beetle
    sitting up, its shell closed over its back like a cape, its round glass abdomen glowing amber
    in front inside brass lantern ribs; ball-tipped antennae, six stubby legs."""
    shell = (104, 122, 214)
    head, R = Vector((0, -0.15, 2.45)), 1.0
    glass_c, gr = Vector((0, -0.3, 0.98)), 0.8
    body = k.fuse(
        [
            (head, R, (1.18, 0.98, 0.9)),
            ((0, 0.05, 1.55), 0.62, (1.1, 1.0, 0.7)),  # thorax collar
            ((0, 0.3, 1.0), 0.95, (1.05, 0.95, 1.05)),  # the shell over the back
            *k.pair((0.5, -0.62, 0.18), 0.27, (0.9, 1.4, 0.6)),  # feet
            *k.pair((0.72, -0.2, 1.62), 0.17, (0.85, 0.9, 1.3)),  # arms
            ("capsule", (0.86, 0.0, 1.0), (1.16, -0.2, 0.78), 0.14),  # middle legs
            ("capsule", (-0.86, 0.0, 1.0), (-1.16, -0.2, 0.78), 0.14),
        ],
        k.flat(shell),
        tris=2550,
    )
    glass = k.sphere(gr, glass_c, m=k.flat((255, 190, 90)), scale=(1.0, 0.9, 1.0), seg=28, rings=14, name="glass")
    parts = [body, glass]
    brass = k.flat((232, 178, 84))
    # Brass lantern ribs over the glass and a ring where it meets the collar.
    for a in (-50, -18, 18, 50):
        pts = []
        for i in range(9):
            phi = math.radians(-62 + 124 * i / 8)
            d = Vector((math.sin(math.radians(a)) * math.cos(phi), -math.cos(math.radians(a)) * math.cos(phi), math.sin(phi)))
            p, n = k.land(glass, glass_c, d)
            pts.append(p + n * 0.02)
        parts.append(k.tube(pts, 0.04, m=brass, n=6, name="rib"))
    ring = k.ring(gr * 0.72, 0, 0.06, brass, n=28, sides=6, name="band")
    ring.data.transform(Matrix.Translation(glass_c + Vector((0, 0.05, gr * 0.68))))
    parts.append(ring)
    # Ball-tipped antennae, a soft curve up and out.
    for side in (-1, 1):
        root = head + Vector((side * 0.36, -0.45, 0.72))
        pts = [root, root + Vector((side * 0.12, -0.12, 0.38)), root + Vector((side * 0.34, -0.1, 0.66))]
        parts.append(k.tube(pts, [0.05, 0.045, 0.04], m=k.flat(k.shade(shell, 0.7)), n=8, name="antenna"))
        parts.append(k.sphere(0.13, pts[-1] + Vector((side * 0.06, 0, 0.06)), m=k.flat((255, 164, 64), emit=0.6), seg=20, rings=10, name="bulb"))
    parts += k.face(body, head, R, skin=shell, nose=None)

    m = stand(parts, 2.4)
    s = m.to_scale().x
    # The shell: a seam down the back, pale spots, darker head and legs at the bottom.
    marks = [((136, 156, 246), m @ Vector((0, 0.95, 1.0)), 0, 1.02 * s)]  # the wing cases, paler than head and legs
    marks += [((70, 82, 160), m @ Vector((0, 1.25, z)), 0, 0.06 * s) for z in (0.5, 0.7, 0.9, 1.1, 1.3, 1.5)]
    marks += [((168, 184, 255), m @ Vector(p), 0, 0.15 * s) for p in ((0.55, 1.0, 1.3), (-0.55, 1.0, 1.3), (0.8, 0.6, 0.85), (-0.8, 0.6, 0.85), (0.35, 1.18, 0.75), (-0.35, 1.18, 0.75))]
    fur(body, "lb_shell", shell, marks=marks)
    lo, hi = zspan(glass)
    swap(glass, k.paint("lb_glass", [(0, (255, 104, 34)), (0.45, (255, 150, 50)), (1, (255, 120, 40))], lo, hi, emit=0.8))
    return parts


# Fog Pup (uncommon) ----------------------------------------------------------------------------


def critter_fogpup():
    """Fog Pup (uncommon, village, inn, lighthouse, boathouse): a fluffy pale puppy with floppy ears,
    a knitted amber scarf with a tiny lantern tag, and a plume tail that frays into puffs of mist."""
    pale = (248, 240, 230)
    head, R = Vector((0, -0.3, 2.45)), 1.0
    snout = Vector((0, -1.25, 2.12))
    tail = spline([(0, 0.95, 0.62), (0.05, 1.42, 0.86), (0.2, 1.66, 1.32), (0.36, 1.66, 1.8)], [0.24, 0.3, 0.27, 0.2], 12)
    body = k.fuse(
        [
            (head, R, (1.24, 0.98, 0.95)),
            (snout, 0.42, (1.2, 0.95, 0.78)),
            *k.pair((0.95, -0.55, 2.12), 0.3, (0.8, 0.6, 0.6), (0, 0, 20)),  # cheek fluff
            ((0, 0.1, 1.2), 0.88, (1.05, 1.1, 0.95)),  # chest
            ((0, 0.25, 0.66), 0.85, (1.15, 1.2, 0.74)),  # round seat
            *k.pair((1.3, -0.12, 2.12), 0.6, (0.34, 0.62, 1.0), (0, -20, 0)),  # floppy ears hanging at the sides
            *k.pair((0.5, -0.5, 0.2), 0.3, (0.9, 1.45, 0.62)),  # feet
            *k.pair((0.74, -0.42, 1.1), 0.2, (0.85, 0.9, 1.3)),  # arms
            *capsules(tail),
        ],
        k.flat(pale),
        tris=2650,
    )
    parts = [body]
    # The tail frays into mist: soft puffs drifting up and away, each smaller.
    mist = k.fuse([((0.62, 1.68, 1.96), 0.23), ((0.98, 1.62, 2.1), 0.17), ((1.28, 1.48, 2.18), 0.12), ((1.5, 1.36, 2.3), 0.08)], k.flat((200, 192, 232)), tris=420, soft=0.2, name="mist")  # drifting out beside the head
    parts.append(mist)
    # Knitted scarf: a ribbed band round the neck, a striped end over the shoulder, a fringe.
    knit = k.flat((255, 168, 64))
    neck = k.fuse([(head, R, (1.24, 0.98, 0.95)), ((0, 0.1, 1.2), 0.88, (1.05, 1.1, 0.95))], knit, tris=1200, name="neck")  # the band's target without the ears
    scarf = band(neck, 0, 0.05, 1.4, 1.74, knit, nu=48, nv=3, lift=0.13, name="scarf")
    bpy.data.objects.remove(neck)
    end = petal(0.82, 0.2, knit, droop=0.0, tip=0.5, base=0.9, n=8, steps=8, name="scarf_end")
    # Built along +X, flat face up: face the front, hang down, swing a little out to the side.
    hang = Matrix.Translation((-0.42, -0.98, 1.58)) @ Matrix.Rotation(math.radians(-14), 4, "Y") @ Matrix.Rotation(math.radians(96), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "X")
    end.data.transform(hang)
    parts += [scarf, end]
    tip = hang @ Vector((0.82, 0, 0))
    for dx in (-0.1, 0.0, 0.1):
        a = tip + Vector((dx, 0, 0.02))
        parts.append(k.capsule(a, a + Vector((dx * 0.3, -0.03, -0.16)), 0.035, 0.03, k.flat((255, 236, 200)), n=8, name="fringe"))
    hook = Vector((0.12, -1.08, 1.5))
    tag, _ = paper_lantern((hook.x, hook.y, hook.z - 1.43 * 0.17), 0.17, k.flat(k.AMBER), k.flat(k.CRANBERRY), k.flat((110, 70, 60)))
    parts += tag
    parts += snout_face(body, snout, (255, 248, 252), k.NOSE)
    parts += k.face(body, head, R, skin=pale, nose=None, mouth_kind=None, eye_phi=8, spread=36)

    m = stand(parts, 2.5)
    s = m.to_scale().x
    # The fur fades to fog lilac along the tail.
    fade = [(k.mix(pale, (196, 188, 230), 0.55), m @ tail[6][0], 0, 0.75 * s), ((196, 188, 232), m @ tail[-1][0], 0, 0.42 * s),
            *[((214, 196, 214), m @ Vector((x, -0.12, 1.85)), 0, 0.62 * s) for x in (1.3, -1.3)],  # dusky ear tips
            ((255, 250, 244), m @ Vector((0, -0.7, 1.05)), 0, 0.5 * s)]
    fur(body, "fp_fur", pale, deep=(196, 176, 190), marks=fade)
    lo, hi = zspan(mist)
    swap(mist, k.paint("fp_mist", [(0, (196, 188, 230)), (1, (222, 216, 246))], lo, hi))
    lo, hi = zspan(scarf)
    swap(scarf, k.paint("fp_knit", [(0, (236, 136, 52)), (1, (255, 176, 72))], lo, hi, rays=((255, 214, 140), 40, lo - 1, 0.25)))
    lo, hi = zspan(end)
    swap(end, k.paint("fp_end", [(0, (236, 136, 52)), (1, (255, 176, 72))], lo, hi, bands=((255, 232, 196), 0.14 * s * 2)))
    lamp(tag[0], "fp_lamp")
    return parts


# Acorn Owlet (uncommon) ------------------------------------------------------------------------


def critter_acornowlet():
    """Acorn Owlet (uncommon, orchard, windmill, mill, inn): a round dove-grey owl chick with ear tufts,
    a cream face mask and huge eyes, sitting in a scaly acorn cup, its wing tips cradling a little
    acorn-shaped lantern on the cup's rim."""
    lilac = (216, 194, 202)  # dove-rose grey
    c, R = Vector((0, 0, 1.7)), 1.12
    centre = Vector((0, 0, 2.02))  # the face's middle
    body = k.fuse(
        [
            (c, R, (1.1, 1.0, 1.06)),
            *k.pair((0.72, -0.12, 2.8), 0.36, (0.48, 0.3, 1.0), (0, 40, 0)),  # ear tufts, splayed
            *k.pair((1.14, 0.0, 1.6), 0.52, (0.34, 0.72, 0.95), (0, -12, 0)),  # wings...
            ("capsule", (1.1, -0.3, 1.5), (0.78, -1.15, 1.3), 0.17),  # ...reaching forward
            ("capsule", (-1.1, -0.3, 1.5), (-0.78, -1.15, 1.3), 0.17),
            *k.pair((0.76, -1.2, 1.3), 0.2, (1.0, 0.9, 0.85)),  # wing tips, one on the lantern
        ],
        k.flat(lilac),
        tris=2350,
    )
    lobes = []
    for side in (-1, 1):
        p, n = k.land(body, centre, k.outward(side * 18, -2))
        lobes.append((p - n * 0.2, 0.62, (1.0, 0.42, 1.0), (0, 0, side * 18)))
    mask = k.fuse(lobes, k.flat((250, 240, 228)), tris=560, soft=0.25, name="mask")
    cup = k.lathe([(0, 0), (0.4, 0.0), (0.8, 0.12), (1.12, 0.42), (1.3, 0.82), (1.34, 1.08), (1.26, 1.17), (1.14, 1.08), (1.02, 0.78), (0.6, 0.5), (0, 0.45)], m=k.flat((150, 110, 76)), n=40, name="cup")
    parts = [body, mask, cup]
    # The acorn lantern: a glowing nut under a scaly cap, resting on the rim.
    base = Vector((0.3, -1.46, 0.84))
    nut = k.lathe([(0, 0), (0.1, 0.03), (0.22, 0.14), (0.28, 0.3), (0.27, 0.42), (0.22, 0.5)], loc=base, m=k.flat(k.AMBER), n=24, name="nut")
    brown = k.flat((132, 92, 66))
    parts += [nut, k.lathe([(0.2, 0.44), (0.3, 0.5), (0.31, 0.6), (0.2, 0.69), (0, 0.71)], loc=base, m=brown, n=24, name="acorn_cap"),
              k.capsule(base + Vector((0, 0, 0.68)), base + Vector((0.04, 0, 0.84)), 0.04, 0.035, brown, n=8, name="acorn_stalk")]
    # Face by hand (the Garden owl): the eyes on the mask, a small beak between them.
    k.texel([body, mask], k.FACE_TEXEL, centre + Vector((0, -R, -0.1)), R * 0.95)
    face = []
    for side in (-1, 1):
        face += k.eye(mask, centre, k.outward(side * 27, -1), R * 0.3)
        face.append(k.lens(body, centre, k.outward(side * 52, -26), R * 0.15, k.flat(k.mix(lilac, k.BLUSH_PINK, 0.55)), scale=(1.5, 0.9), thick=0.18, sink=0.5, name="blush"))
    p, n = k.land(mask, centre, k.outward(0, -14))
    face.append(k.capsule(p - n * 0.1, p + n * 0.16 - Vector((0, 0, 0.16)), 0.12, 0.04, k.flat((236, 170, 110)), n=12, name="beak"))
    parts += k.texel(face, k.FACE_TEXEL)

    m = stand(parts, 2.5)
    s = m.to_scale().x
    fur(body, "ao_fluff", lilac, deep=(150, 124, 150))
    lo, hi = zspan(cup)
    swap(cup, k.mat("ao_cup", (164, 122, 84), kind="cells", scale=8, var=0.2, rough=0.6))
    lamp(nut, "ao_lamp", rgb=(255, 170, 70))
    return parts


# Teapot Cat (rare) -----------------------------------------------------------------------------


def critter_teapotcat():
    """Teapot Cat (rare, inn, village, farm): an apricot tabby curled inside a chipped porcelain
    teapot, paws on the rim and the lid on its head, tail draped down the back. The pot is a lantern:
    star holes pierced round its belly glow amber."""
    apricot = (244, 172, 116)
    head, R = Vector((0, -0.08, 2.18)), 0.98
    ear, tilt = Vector((0.6, -0.05, 3.05)), 16
    body = k.fuse(
        [
            (head, R, (1.24, 0.98, 0.92)),
            ((0, 0.1, 1.3), 0.78, (1.0, 1.0, 0.9)),  # curled body, inside the pot
            *k.pair(ear, 0.58, (0.5, 0.25, 1.0), (0, tilt, 0)),  # pointed ears
            *k.pair((0.46, -0.8, 1.62), 0.22, (1.0, 1.35, 0.62)),  # paws over the rim
            *[("capsule", (s * 0.5, -0.35, 1.45), (s * 0.46, -0.72, 1.6), 0.18) for s in (-1, 1)],
        ],
        k.flat(apricot),
        tris=2050,
    )
    tail = spline([(-0.4, 0.55, 1.42), (-0.6, 0.86, 1.68), (-0.78, 1.14, 1.5), (-0.7, 1.4, 1.1), (-0.42, 1.5, 0.76), (-0.06, 1.48, 0.6)], [0.16, 0.16, 0.15, 0.14, 0.13, 0.12], 16)
    tail_ob = k.fuse(capsules(tail), k.flat(apricot), tris=340, name="tail")
    pot = k.lathe([(0, 0), (0.7, 0), (0.78, 0.06), (1.1, 0.3), (1.26, 0.7), (1.22, 1.1), (1.0, 1.42), (0.86, 1.55), (0.9, 1.62), (0.84, 1.66), (0.76, 1.58), (0.7, 1.2), (0, 1.15)], m=k.flat((244, 236, 226)), n=32, name="pot")
    chip = k.sphere(0.24, (-0.9, 0.0, 1.68), seg=12, rings=6, name="chip")  # on the left rim, clear of the head
    k.boolean(pot, chip)
    k.apply_cuts()
    porcelain = k.flat((244, 236, 226))
    spout = tail_tube([(-0.85, -0.5, 0.55), (-1.3, -0.78, 0.82), (-1.55, -0.95, 1.22), (-1.66, -1.02, 1.5)], [0.3, 0.2, 0.15, 0.14], porcelain, steps=8, name="spout")
    handle = tail_tube([(1.05, 0.0, 1.2), (1.5, 0.0, 1.3), (1.72, 0.0, 0.95), (1.55, 0.0, 0.5), (1.12, 0.0, 0.4)], [0.11] * 5, porcelain, steps=8, name="handle")
    parts = [body, tail_ob, pot, spout, handle]
    # Star holes pierced round the belly, glowing from the lantern inside.
    glow = k.flat((255, 140, 44), emit=0.9)
    for theta, z in ((-30, 0.72), (10, 0.95), (45, 0.68), (150, 0.72), (190, 0.95), (225, 0.7), (-75, 1.0), (110, 1.0)):
        parts += onto([disc(0.15, star, glow, n=20, cup=0.0, thick=0.25, closed=False, name="star_hole")], pot, (0, 0, z), k.outward(theta, 0), spin=theta, sink=0.015)
    lid = k.lathe([(0, 0), (0.62, 0), (0.66, 0.05), (0.6, 0.12), (0.4, 0.22), (0.16, 0.26), (0.12, 0.3), (0.16, 0.4), (0.1, 0.48), (0, 0.5)], m=porcelain, n=24, name="lid")
    parts += onto([lid], body, head, (0.22, -0.08, 1), up=(0, 1, 0), sink=0.1)
    parts += ear_in(body, ear, tilt, 0.4, k.flat((255, 170, 190)), scale=(0.42, 1), lift=0.02)
    # Tabby: three stripes up the forehead.
    stripe = k.flat((206, 122, 82))
    for a in (-16, 0, 16):
        parts.append(k.lens(body, head, k.outward(a, 52), 0.17, stripe, scale=(0.32, 1), thick=0.15, sink=0.6, up=(math.sin(math.radians(a)) * 0.6, 0.3, 1), seg=12, name="stripe"))
    face = k.face(body, head, R, skin=apricot, nose=None, mouth_kind=None)
    muzzle = k.lens(body, head, k.outward(0, -22), 0.34, k.flat((255, 236, 216)), scale=(1.35, 0.8), thick=0.45, sink=0.55, seg=20, name="muzzle")
    face += k.texel([muzzle, k.lens(muzzle, head, k.outward(0, -14), R * 0.08, k.flat((236, 120, 140)), scale=(1.35, 0.9), thick=0.55, sink=0.4, seg=12, name="nose"),
                     k.mouth(muzzle, head, k.outward(0, -24), R * 0.15, k.flat(k.INKY), "w")], k.FACE_TEXEL)
    parts += face

    m = stand(parts, 2.8)
    s = m.to_scale().x
    fur(body, "tc_fur", apricot)
    rings = [((206, 122, 82), m @ tail[i][0], 0, 0.21 * s) for i in (3, 7, 11, 15)]
    fur(tail_ob, "tc_tail", apricot, marks=rings)
    lo, hi = zspan(pot)
    teal, cream = (92, 150, 170), (246, 238, 228)
    swap(pot, k.paint("tc_pot", [(0, teal), (0.07, teal), (0.08, cream), (0.62, cream), (0.63, teal), (0.68, teal), (0.69, cream), (1, cream)], lo, hi))
    return parts


# Reed Fox (rare) -------------------------------------------------------------------------------


def critter_reedfox():
    """Reed Fox (rare, mill, lighthouse, boathouse, orchard): a slim russet fox (the Ember Kit's
    build, leaner) with dark socks and ear tips, three cattails and two reed blades tucked into its
    big cream-tipped tail; the tallest cattail smoulders like an ember torch."""
    russet = (206, 108, 80)
    cream_rgb = (255, 238, 222)
    head, R = Vector((0, -0.3, 2.5)), 1.0
    snout = Vector((0, -1.32, 2.16))
    tilt = 16
    ear = Vector((0.7, -0.1, 3.4))
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    tail = spline([(-0.25, 0.9, 0.5), (-0.85, 1.3, 0.7), (-1.3, 1.45, 1.3), (-1.42, 1.3, 2.0), (-1.25, 1.0, 2.6)], [0.26, 0.46, 0.54, 0.44, 0.08], 16)
    body = k.fuse(
        [
            (head, R, (1.12, 0.98, 0.92)),
            (snout, 0.42, (0.95, 1.3, 0.68)),
            *k.pair((0.92, -0.5, 2.15), 0.28, (0.8, 0.6, 0.6), (0, 0, 20)),  # cheek fluff
            ((0, 0.1, 1.25), 0.78, (0.92, 1.05, 1.0)),  # slim chest
            ((0, 0.25, 0.68), 0.8, (1.02, 1.12, 0.8)),  # seat
            *k.pair(ear, 0.56, (0.85, 0.32, 0.8), (0, tilt, 0)),
            *k.pair(ear + axis * 0.5, 0.34, (0.55, 0.3, 1.0), (0, tilt, 0)),
            *k.pair((0.46, -0.55, 0.2), 0.28, (0.85, 1.45, 0.62)),  # feet
            *k.pair((0.64, -0.45, 1.25), 0.18, (0.85, 0.9, 1.3)),  # arms
            *capsules(tail),
        ],
        k.flat(russet),
        tris=2600,
    )
    parts = [body, *ear_in(body, ear, tilt, 0.38, k.flat((255, 186, 176)))]
    # Cattails and reeds tucked into the tail, rising behind the shoulder.
    stalk, brown = k.flat((104, 146, 112)), k.flat((122, 80, 62))
    tails = []
    for base, top, glow in (((-1.32, 1.42, 1.5), (-1.62, 1.55, 4.05), True), ((-1.22, 1.52, 1.2), (-0.92, 1.85, 3.5), False), ((-1.4, 1.25, 1.8), (-2.15, 1.25, 3.55), False)):
        base, top = Vector(base), Vector(top)
        d = (top - base).normalized()
        parts.append(k.capsule(base, top, 0.045, 0.04, stalk, n=8, name="stalk"))
        r = 0.15 if glow else 0.12
        head_ob = k.capsule(top - d * 0.7, top - d * 0.12, r, r, k.flat((255, 140, 50), emit=0.8) if glow else brown, n=12, name="cattail")
        parts += [head_ob, k.capsule(top - d * 0.14, top + d * 0.14, 0.025, 0.012, stalk, n=8, name="spike")]
        tails.append((head_ob, glow))
    for yaw, pitch, length in ((160, 58, 2.0), (205, 46, 1.7)):
        parts += xf(petal(length, 0.1, k.flat((120, 166, 122)), droop=-0.1, tip=1.0, base=0.6, n=8, steps=10, name="reed"), (-1.3, 1.4, 1.5), yaw=yaw, pitch=pitch, roll=90)
    parts += snout_face(body, snout, cream_rgb, k.NOSE, mouth_w=0.2, muzzle_r=0.38, muzzle_scale=(1.0, 0.85))
    parts += k.face(body, head, R, skin=russet, nose=None, mouth_kind=None, eye_phi=8, spread=36)

    m = stand(parts, 2.9)
    s = m.to_scale().x
    tip_c = tail[-1][0]
    marks = [(cream_rgb, m @ tip_c, 0, 0.62 * s), (cream_rgb, m @ Vector((0, -0.42, 1.12)), 0, 0.52 * s)]
    for side in (-1, 1):
        e = ear + axis * 0.95
        marks.append(((96, 52, 58), m @ Vector((side * e.x, e.y, e.z)), 0, 0.42 * s))  # dark ear tips
        marks.append(((110, 56, 58), m @ Vector((side * 0.46, -0.55, 0.0)), 0, 0.38 * s))  # dark socks
    fur(body, "rf_fur", russet, marks=marks)
    for ob, glow in tails:
        lo, hi = zspan(ob)
        if glow:
            swap(ob, k.paint("rf_ember", [(0, (240, 84, 36)), (0.5, (255, 132, 48)), (1, (255, 180, 84))], lo, hi, emit=0.9))
        else:
            swap(ob, k.paint("rf_cattail", [(0, (104, 66, 52)), (1, (150, 104, 76))], lo, hi))
    return parts


# Mist Fawn (epic) ------------------------------------------------------------------------------


def critter_mistfawn():
    """Mist Fawn (epic, Forest Line): a moon-white fawn on four slim legs (the Garden deer's frame),
    big pink-lined ears, two antler buds glowing amber like candle tips, a star blaze, and fawn spots
    that are little glowing gold stars down its back."""
    moon = (250, 246, 252)
    head, R = Vector((0, -0.38, 3.3)), 1.0
    snout = Vector((0, -1.22, 2.98))
    ear, tilt = (1.15, -0.2, 3.62), 66
    legs = []
    for x, y, r in ((0.4, -0.38, 0.19), (0.42, 0.82, 0.2)):
        for sd in (-1, 1):
            legs += [("capsule", (sd * x, y, 0.22), (sd * x, y, 1.45), r), ((sd * x, y, 0.19), r + 0.02, (1, 1.05, 0.85))]
    body_c = Vector((0, 0.25, 1.78))
    body = k.fuse(
        [
            (head, R, (1.1, 0.96, 0.94)),
            (snout, 0.42, (1.1, 0.92, 0.76)),
            ((0, -0.15, 2.5), 0.5, (1.0, 1.0, 1.15)),  # neck
            (body_c, 0.8, (1.0, 1.2, 0.86)),
            *k.pair(ear, 0.52, (0.5, 0.25, 1.0), (0, tilt, 0)),
            *legs,
        ],
        k.flat(moon),
        tris=2250,
    )
    split(body, k.flat((150, 132, 190)), (0, 0, 0.3), (0, 0, -1))  # lilac hooves
    parts = [body, k.sphere(0.24, (0, 1.22, 2.1), m=k.flat((255, 252, 255)), seg=20, rings=10, name="tail")]
    for sd in (-1, 1):  # inner ears along the ears' near-level axis
        t = math.radians(tilt)
        parts.append(k.lens(body, (sd * ear[0], ear[1], ear[2]), (0, -1, 0), 0.42, k.flat((255, 182, 204)), scale=(0.34, 1), thick=0.2, sink=0.6, up=(sd * math.sin(t), 0, math.cos(t)), name="ear_in"))
    parts.append(k.lens(body, body_c, (0, -1, 0.1), 0.34, k.flat((255, 250, 255)), scale=(0.8, 1.25), thick=0.22, sink=0.6, name="chest"))
    muzzle = k.lens(body, snout, k.outward(0, -22), 0.34, k.flat((255, 248, 250)), scale=(1.15, 0.8), thick=0.25, sink=0.6, name="muzzle")
    face = [muzzle, k.lens(body, snout, k.outward(0, 22), 0.12, k.flat((150, 110, 150)), scale=(1.3, 0.85), thick=0.55, sink=0.4, seg=12, name="nose")]
    face.append(k.mouth(muzzle, snout, k.outward(0, -30), 0.2, k.flat(k.INKY), "smile"))
    parts += k.texel(face, k.FACE_TEXEL)
    # Star freckles down the back and over the rump, glowing gold.
    gold = k.flat((255, 214, 120), emit=0.7)
    for theta, phi in ((70, 30), (110, 40), (140, 20), (165, 45), (95, 8), (125, 2)):
        for sd in (1, -1):
            parts += onto([disc(0.16, star, gold, n=20, cup=0.0, thick=0.25, closed=False, name="freckle")], body, body_c, k.outward(sd * theta, phi), spin=sd * theta, sink=0.012)
    parts += onto([disc(0.15, star, gold, n=20, cup=0.0, thick=0.25, closed=False, name="freckle")], body, body_c, k.outward(180, 50), sink=0.012)
    # Antler buds: short stalks, each tipped with a glowing bud.
    bark = k.flat((196, 170, 214))
    buds = []
    for sd in (-1, 1):
        base, tip = Vector((sd * 0.36, -0.3, 4.05)), Vector((sd * 0.5, -0.22, 4.42))
        parts.append(k.capsule(base, tip, 0.11, 0.09, bark, n=12, name="antler"))
        bud = k.lathe([(0, 0), (0.16, 0.05), (0.22, 0.18), (0.18, 0.33), (0.09, 0.46), (0, 0.52)], m=k.flat((255, 176, 64), emit=0.9), n=20, name="bud")
        aim([bud], tip - (tip - base).normalized() * 0.04, tip - base + Vector((sd * 0.12, 0, 0.3)))
        buds.append(bud)
    parts += buds
    parts += onto([disc(0.17, star, gold, n=20, cup=0.0, thick=0.25, closed=False, name="blaze")], body, head, k.outward(0, 42), sink=0.012)  # star blaze
    parts += k.face(body, head, R, skin=moon, nose=None, mouth_kind=None, eye_phi=8, spread=36)

    m = stand(parts, 3.2)
    fur(body, "mf_coat", moon, deep=(214, 204, 232))
    for bud in buds:
        lo, hi = zspan(bud)
        swap(bud, k.paint("mf_bud", [(0, (255, 120, 40)), (0.5, (255, 150, 52)), (1, (255, 190, 100))], lo, hi, emit=0.9))
    return parts


# Bell Turtle (epic) ----------------------------------------------------------------------------


def lily_pad(a):
    """Round pad with a V notch at angle 0."""
    w = math.atan2(math.sin(a), math.cos(a))
    return 1 - 0.85 * max(0.0, 1 - abs(w) / 0.32)


def critter_bellturtle():
    """Bell Turtle (epic, Lake Line): a compact sage turtle whose shell is a tall bronze bell with
    a flared lip and a crown loop, lily pads draped on its shoulders and a water lily whose heart
    glows amber."""
    sage = (130, 190, 168)
    head, R = Vector((0, -1.25, 1.3)), 0.92
    centre = Vector((0, 0.25, 0))
    body = k.fuse(
        [
            (head, R, (1.15, 0.95, 0.95)),
            ((0, -0.7, 0.95), 0.55),  # neck under the bell's lip
            (centre + Vector((0, 0, 0.72)), 1.0, (1.25, 1.12, 0.7)),
            *k.pair((1.02, -0.55, 0.2), 0.34, (0.95, 1.3, 0.6)),  # front legs
            *k.pair((1.02, 0.85, 0.2), 0.34, (0.95, 1.3, 0.6)),  # back legs
            ("capsule", (0, 1.2, 0.4), (0, 1.42, 0.3), 0.12),  # tail
        ],
        k.flat(sage),
        tris=2300,
    )
    bell = k.lathe([(1.2, 0.6), (1.38, 0.64), (1.4, 0.76), (1.22, 0.9), (1.06, 1.25), (0.98, 1.8), (0.94, 2.4), (0.84, 2.85), (0.6, 3.12), (0.3, 3.26), (0, 3.3)],
                   loc=centre, m=k.flat((200, 140, 70)), n=40, name="bell")
    loop = k.ring(0.2, 0, 0.07, k.flat((226, 172, 92)), n=20, sides=8, name="loop")
    loop.data.transform(Matrix.Translation(centre + Vector((0, 0, 3.42))) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    parts = [body, bell, loop]
    green, green_hi = k.flat((96, 152, 112)), k.flat((126, 180, 128))
    parts += onto([disc(0.56, lily_pad, green, n=36, cup=0.15, thick=0.1, name="pad")], bell, centre + Vector((0, 0, 2.5)), k.outward(-75, 30), up=(0, 0, 1), spin=200, sink=0.01)
    parts += onto([disc(0.48, lily_pad, green_hi, n=32, cup=0.15, thick=0.1, name="pad")], bell, centre + Vector((0, 0, 2.3)), k.outward(160, 28), up=(0, 0, 1), spin=40, sink=0.01)
    # The water lily on the front shoulder: two rings of round petals round a glowing heart.
    petal_m, heart = k.flat((255, 228, 238)), k.flat((255, 160, 52), emit=1.0)
    lily = [disc(0.52, petals(8, 0.4, 0.8), petal_m, n=40, cup=0.5, thick=0.12, name="lily"),
            disc(0.36, petals(8, 0.4, 0.8), petal_m, heart=heart, n=32, cup=0.85, thick=0.14, hr=0.52, dome=0.45, name="lily")]
    lily[1].data.transform(Matrix.Translation((0, 0, 0.05)) @ k.rot_z(22.5))
    parts += onto(lily, bell, centre + Vector((0, 0, 2.6)), k.outward(22, 26), up=(0, 0, 1), sink=0.03)
    parts += k.face(body, head, R, skin=sage, mouth_kind="smile")

    m = stand(parts, 2.9)
    fur(body, "bt_skin", sage)
    lo, hi = zspan(bell)
    dark, mid, high = (122, 86, 52), (198, 152, 78), (248, 214, 140)
    swap(bell, k.paint("bt_bell", [(0, dark), (0.05, dark), (0.06, k.mix(mid, high, 0.4)), (0.1, mid), (0.22, mid), (0.23, dark), (0.25, dark), (0.26, k.mix(mid, high, 0.2)),
                                   (0.72, k.mix(mid, high, 0.7)), (0.73, dark), (0.75, dark), (0.76, k.mix(mid, high, 0.75)), (1, high)], lo, hi, rough=0.3))
    return parts


# Moon Hare (legendary) -------------------------------------------------------------------------


def critter_moonhare():
    """Moon Hare (legendary, any tile, far crates on leg 3): the biggest critter. A silver hare
    with long violet-tipped ears, a glowing gold crescent moon on its forehead and long whiskers,
    hugging a round full-moon lantern to its chest."""
    silver = (214, 218, 234)
    head, R = Vector((0, -0.12, 2.4)), 1.05
    ear, tilt = Vector((0.42, 0.04, 3.62)), 12
    paw = Vector((0.52, -1.18, 1.32))
    body = k.fuse(
        [
            (head, R, (1.18, 0.96, 0.92)),
            ((0, 0.1, 1.22), 0.86, (1.05, 1.02, 0.98)),  # chest
            ((0, 0.12, 0.66), 0.84, (1.15, 1.1, 0.72)),  # round seat
            *k.pair(ear + Vector((0, 0, 0.15)), 0.98, (0.32, 0.19, 1.0), (0, tilt, 0)),  # long hare ears
            *k.pair((0.5, -0.5, 0.18), 0.3, (0.85, 1.75, 0.6)),  # long hare feet
            *[("capsule", (sd * 0.66, -0.3, 1.52), (sd * paw.x, paw.y, paw.z), 0.18) for sd in (-1, 1)],  # arms round the lantern
            *k.pair(paw, 0.2),
        ],
        k.flat(silver),
        tris=2650,
    )
    axis = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    parts = [body, k.sphere(0.32, (0, 1.0, 0.75), m=k.flat((246, 248, 255)), seg=20, rings=10, name="tail")]
    for sd in (-1, 1):
        parts.append(k.lens(body, (sd * ear.x, ear.y, ear.z + 0.22), (0, -1, 0), 0.74, k.flat((246, 196, 222)), scale=(0.28, 1), thick=0.2, sink=0.6, up=(sd * axis.x, 0, axis.z), seg=12, name="ear_in"))
    # The full-moon lantern: a glowing pale-gold globe with brass caps and a bail.
    mc, mr = Vector((0, -1.42, 1.22)), 0.52
    moon = k.sphere(mr, mc, m=k.flat((255, 232, 160), emit=0.7), seg=28, rings=14, name="moon")
    brass = k.flat((226, 176, 92))
    parts += [moon,
              k.lathe([(0, 0), (0.2, 0), (0.22, 0.05), (0.16, 0.1), (0, 0.11)], loc=mc + Vector((0, 0, mr - 0.04)), m=brass, n=20, name="cap"),
              k.lathe([(0, 0), (0.16, 0.01), (0.2, 0.06), (0.2, 0.1), (0, 0.11)], loc=mc - Vector((0, 0, mr + 0.06)), m=brass, n=20, name="cap"),
              k.tube([mc + Vector((x, 0, z)) for x, z in ((-0.18, mr + 0.05), (-0.14, mr + 0.3), (0, mr + 0.42), (0.14, mr + 0.3), (0.18, mr + 0.05))], 0.03, m=brass, n=8, name="bail")]
    # Crescent moon on the forehead: a tapered arc on the surface, horns up (the Garden dragon's).
    f = Vector((0, -1, 0.62)).normalized()
    pts, radii = [], []
    for i in range(11):
        t = i / 10 * 2 - 1
        a = math.radians(125 * t)
        p, n = k.land(body, head, f + Vector((0.28 * math.sin(a), 0, -0.28 * math.cos(a))))
        r = 0.02 + 0.07 * (1 - t * t) ** 0.6
        pts.append(p + n * r * 0.3)
        radii.append(r)
    parts.append(k.texel(k.tube(pts, radii, m=k.flat((255, 214, 110), emit=0.8), n=8, name="crescent"), k.FACE_TEXEL))
    face = k.face(body, head, R, skin=silver, nose=None, mouth_kind=None)
    muzzle = k.lens(body, head, k.outward(0, -22), 0.34, k.flat((250, 250, 255)), scale=(1.4, 0.8), thick=0.45, sink=0.55, seg=20, name="muzzle")
    face += [muzzle, k.lens(muzzle, head, k.outward(0, -14), R * 0.085, k.flat((236, 140, 176)), scale=(1.35, 0.9), thick=0.55, sink=0.4, seg=12, name="nose"),
             k.mouth(muzzle, head, k.outward(0, -24), R * 0.15, k.flat(k.INKY), "w")]
    # Long whiskers, three a side, sweeping out past the cheeks.
    for sd in (-1, 1):
        for lift, droop in ((0.05, 0.12), (-0.02, -0.02), (-0.09, -0.16)):
            root, n = k.land(muzzle, head, k.outward(sd * 18, -20 + lift * 60))
            out = Vector((sd * 1.0, -0.25, 0)).normalized()
            pts = [root + n * 0.01, root + out * 0.45 + Vector((0, 0, droop * 0.4 + 0.03)), root + out * 0.95 + Vector((0, 0.1, droop))]
            face.append(k.tube(pts, [0.018, 0.014, 0.006], m=k.flat((255, 250, 240)), n=4, name="whisker"))
    parts += k.texel(face, k.FACE_TEXEL)

    m = stand(parts, 3.5)
    s = m.to_scale().x
    marks = [((248, 250, 255), m @ Vector((0, -0.62, 1.0)), 0, 0.5 * s)]
    for sd in (-1, 1):
        marks.append(((120, 112, 196), m @ (Vector((sd * ear.x, ear.y, ear.z + 0.15)) + Vector((sd * axis.x, 0, axis.z)) * 0.92), 0, 0.32 * s))  # violet ear tips
    lo, hi = zspan(body)
    deep = (150, 154, 190)
    swap(body, k.paint("mh_fur", [(0, deep), (0.1, k.mix(deep, silver, 0.4)), (0.55, silver), (1, (236, 240, 255))], lo, hi, marks=marks, dots=[((246, 248, 255), 26, 0.05)]))
    lo, hi = zspan(moon)
    craters = [((255, 156, 64), m @ (mc + Vector(d) * mr), 0, r * s) for d, r in (((-0.45, -0.8, 0.35), 0.13), ((0.4, -0.85, -0.2), 0.1), ((0.1, -0.95, -0.55), 0.08), ((-0.2, -0.75, -0.62), 0.06))]
    swap(moon, k.paint("mh_moon", [(0, (255, 150, 58)), (0.5, (255, 178, 84)), (1, (255, 204, 120))], lo, hi, emit=0.85, marks=craters))
    return parts


NOTES = ("One mesh, stands on the origin facing -Y; scale to the manifest height. The mascot and the reference critter for the HD standard. "
         "The lantern is baked bright, no Neon: code adds a small amber PointLight (range 8, brightness 1.5) at the lantern, on the viewer's right about 0.55 of the height up.")
ASSETS = [
    dict(name="critter_emberkit", build=critter_emberkit, budget=k.CREATURE_BUDGET, finalize=k.HD, size=[2.9, 2.9, 2.8], priority=1, order=1,
         replaces="critter fallback (two balls, ears and the rarity colour)", notes=NOTES, glow={}),
]

# (id, rarity, [x, height, depth] studs as built (rarer is taller), where code hangs the warm PointLight)
ROLLED = [
    ("mossmouse", "common", [1.85, 2.0, 1.55], "the dandelion fluff, on the viewer's right above the head"),
    ("puddlefrog", "common", [1.55, 2.0, 1.5], "the masthead lantern on top of the walnut hat"),
    ("wickmole", "common", [1.25, 2.1, 1.65], "the candle flame on top of the head"),
    ("burrbun", "common", [1.85, 2.3, 1.45], "the seed-pod lantern, on the viewer's left at about half height"),
    ("lanternbeetle", "uncommon", [1.55, 2.4, 1.4], "the glass abdomen, low at the front (it also glows from the antenna tips)"),
    ("fogpup", "uncommon", [2.35, 2.5, 2.75], "the lantern tag under the chin"),
    ("acornowlet", "uncommon", [2.2, 2.5, 2.5], "the acorn lantern on the cup's front rim"),
    ("teapotcat", "rare", [2.8, 2.8, 2.25], "the middle of the teapot (its star holes glow)"),
    ("reedfox", "rare", [2.45, 2.9, 2.8], "the glowing cattail, top left behind the head"),
    ("mistfawn", "epic", [2.15, 3.2, 2.1], "between the two glowing antler buds, at the top of the head"),
    ("bellturtle", "epic", [2.2, 2.9, 2.95], "the water lily's glowing heart on the bell's front shoulder"),
    ("moonhare", "legendary", [1.85, 3.5, 2.4], "the moon lantern hugged to the chest"),
]
for _order, (_id, _rarity, _size, _light) in enumerate(ROLLED, 2):
    ASSETS.append(dict(name=f"critter_{_id}", build=globals()[f"critter_{_id}"], budget=k.CREATURE_BUDGET, finalize=k.HD, size=_size, priority=1, order=_order,
                       replaces="critter fallback (two balls, ears and the rarity colour)", glow={},
                       notes=f"{_rarity.capitalize()}. One mesh, stands on the origin facing -Y; scale to the manifest height. Its light is baked bright, no Neon: code adds a small amber PointLight (range 8, brightness 1.5) at {_light}."))
