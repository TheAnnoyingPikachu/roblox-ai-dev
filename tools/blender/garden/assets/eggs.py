"""The seven eggs and the hatch shell fragment. Each egg has its own silhouette from all sides,
because players walk round the beds: see docs/assets/garden-blender-plan.md."""

import math
import random

import bmesh
import kit as k
from mathutils import Matrix, Vector


def moved(objs, x=0.0, y=0.0, z=0.0):
    for ob in objs:
        ob.data.transform(Matrix.Translation((x, y, z)))
    return objs


def egg_starter():
    e = dict(H=2.62, R=1.06)
    speck = k.paint(
        "st_shell",
        [(0, (255, 205, 208)), (0.5, (255, 236, 206)), (1, (255, 244, 220))],
        0,
        2.8,
        dots=[((240, 150, 165), 4.2, 0.2), ((130, 205, 170), 3.2, 0.13)],
    )
    yolk = k.flat((255, 196, 96))
    crack = k.flat((205, 150, 135))
    green = k.flat((120, 205, 100))
    green_hi = k.flat((165, 232, 120))

    teeth = 9

    def seam(t):
        return 0.63 + 0.06 * (abs((t * teeth / 360) % 1 * 2 - 1) * 2 - 1)

    parts = [
        k.shell(speck, nu=36, nv=9, v1=seam, **e),
        k.shell(yolk, nu=16, nv=8, warp=lambda t, v: -0.075, name="inner", **e),
    ]
    for path in (
        [(-30, 0.6), (-24, 0.52), (-34, 0.45), (-26, 0.37), (-32, 0.31)],
        [(50, 0.59), (58, 0.5), (48, 0.43), (55, 0.35)],
        [(170, 0.6), (162, 0.51), (172, 0.43), (165, 0.36)],
        [(255, 0.59), (262, 0.5), (252, 0.44)],
    ):
        parts.append(k.ridge(path, 0.03, 0.012, crack, **e))

    lid = [k.shell(speck, nu=36, nv=5, v0=seam, name="lid", **e), k.shell(yolk, nu=18, nv=3, v0=0.6, warp=lambda t, v: -0.04, name="liner", **e)]
    top = k.egg_at(0, 1, **e)[0]
    lid.append(k.tube([top + Vector((0, 0, -0.1)), top + Vector((0.02, 0, 0.12)), top + Vector((0.09, -0.02, 0.27))], [0.075, 0.05, 0.04], m=green, n=6))
    for length, width, x, spin, m in ((0.72, 0.22, 0.08, 18, green_hi), (0.5, 0.17, 0.08, 165, green)):
        sprout = k.leaf(length, width, m, droop=0.3)
        sprout.data.transform(Matrix.Translation(top + Vector((x, -0.02, 0.26))) @ k.rot_z(spin))
        lid.append(sprout)
    # The lid sits ajar, hinged at the back, so the gap shows the warm inside.
    hinge = Vector((0, 0.72, 2.0))
    ajar = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(-7), 4, "X") @ Matrix.Rotation(math.radians(4), 4, "Y") @ Matrix.Translation(-hinge)
    for ob in lid:
        ob.data.transform(Matrix.Translation((0, 0, 0.05)) @ ajar)
    return parts + lid


def _ladybug(red, black, white):
    parts = [
        k.sphere(0.27, (0, 0, 0.02), m=red, scale=(1.18, 1, 0.68), seg=10, rings=6, name="bug_back"),
        k.sphere(0.135, (0.31, 0, 0.05), m=black, scale=(1, 1, 0.85), seg=8, rings=5, name="bug_head"),
        k.box((0.6, 0.022, 0.03), (0, 0, 0.2), m=black, name="bug_split"),
    ]
    for x, y, z in ((-0.16, 0.13, 0.15), (-0.16, -0.13, 0.15), (0.08, 0.15, 0.14), (0.08, -0.15, 0.14), (-0.27, 0, 0.09)):
        parts.append(k.sphere(0.058, (x, y, z), m=black, scale=(1, 1, 0.55), seg=6, rings=3, name="bug_spot"))
    for y in (0.07, -0.07):
        parts.append(k.sphere(0.04, (0.4, y, 0.1), m=white, seg=5, rings=3, name="bug_eye"))
    return parts


def egg_meadow():
    e = dict(H=2.56, R=1.05)
    rng = random.Random(4)
    body = k.paint(
        "me_shell",
        [(0, (135, 215, 125)), (0.5, (190, 240, 170)), (1, (226, 250, 205))],
        0,
        2.7,
        dots=[((255, 255, 250), 3.0, 0.2)],
    )
    turf = k.paint("me_turf", [(0, (85, 175, 85)), (1, (125, 205, 90))], 0, 1.3)
    greens = [k.flat(c) for c in ((110, 205, 90), (140, 222, 100), (88, 188, 96))]
    stem = k.flat((100, 190, 90))
    sun = k.flat(k.SUNNY)
    pink, white, lilac = k.flat(k.ROSE), k.flat(k.SNOW), k.flat(k.VIOLET)

    def edge(t):
        a = math.radians(t)
        return 0.4 + 0.05 * math.sin(a * 5) + 0.03 * math.sin(a * 11)

    parts = [k.shell(body, nu=26, nv=12, **e), k.shell(turf, nu=33, nv=3, v1=edge, warp=lambda t, v: 0.035, name="turf", **e)]
    for i in range(44):
        theta = i * 360 / 44 + rng.uniform(-4, 4)
        v = rng.choice((0.2, 0.28, 0.34, 0.38))
        p, n = k.egg_at(theta, v, 0.02, **e)
        out = Vector((n.x, n.y, 0)).normalized()
        parts.append(k.blade(p, out, rng.uniform(0.45, 0.8), 0.09, rng.choice(greens)))

    # A big daisy crown, flowers on stems out of the grass, little ones on the shell.
    parts += k.stick(k.flower(0.52, pink, sun), 28, 0.9, 0.03, **e)
    for theta, height, m, r, out_by in ((-62, 1.75, white, 0.34, 0.5), (118, 1.5, lilac, 0.31, 0.46), (205, 1.9, sun, 0.32, 0.5)):
        p = k.egg_at(theta, 0.32, 0.02, **e)[0]
        side = Vector((p.x, p.y, 0)).normalized()
        tip = Vector((p.x, p.y, 0)) + side * out_by + Vector((0, 0, height))
        parts.append(k.tube([p, p + side * 0.2 + Vector((0, 0, 0.6)), tip], 0.045, m=stem, n=5))
        head = k.flower(r, m, pink if m is sun else sun)
        tilt = Vector((0, 0, 1)).rotation_difference((side + Vector((0, 0, 1.2))).normalized()).to_matrix().to_4x4()
        for ob in head:
            ob.data.transform(Matrix.Translation(tip) @ tilt)
        parts += head
    parts += k.stick(k.flower(0.2, white, sun, lobes=5), -38, 0.72, 0.02, **e)
    parts += k.stick(k.flower(0.18, lilac, sun, lobes=5), 180, 0.68, 0.02, **e)

    parts += k.stick(_ladybug(k.flat((235, 55, 60)), k.flat((45, 35, 45)), k.flat(k.SNOW)), 8, 0.58, 0.0, spin=70, s=1.15, **e)
    return parts


def egg_forest():
    e = dict(H=2.62, R=1.06)
    bark_m = k.paint(
        "fo_bark",
        [(0, (170, 116, 76)), (0.55, (214, 156, 104)), (1, (198, 138, 90))],
        0,
        2.0,
        dots=[((156, 104, 70), 4, 0.2)],
    )
    cap_m = k.paint("fo_cap", [(0, (240, 186, 110)), (1, (214, 150, 86))], 1.6, 2.9, dots=[((190, 124, 68), 5, 0.3)])
    lip = k.flat((196, 130, 74))
    moss = k.paint("fo_moss", [(0, (118, 205, 100)), (1, (170, 238, 110))], 0, 1.8, dots=[((186, 240, 120), 8, 0.22)])
    red = k.paint("fo_red", [(0, (250, 95, 95)), (1, (232, 62, 72))], 0.4, 1.4, dots=[((255, 248, 236), 2.8, 0.27)])
    tan = k.paint("fo_tan", [(0, (242, 190, 120)), (1, (214, 150, 90))], 0.2, 1.6, dots=[((255, 240, 205), 5, 0.25)])
    stem_m = k.flat((255, 240, 216))
    leaf_m = k.flat((130, 205, 95))
    wood = k.flat((168, 116, 76))

    def bark(t, v):
        a = math.radians(t)
        return 0.05 * math.sin(a * 9 + 1.6 * math.sin(v * 8)) + 0.012

    def cap_edge(t):
        return 0.63 + 0.015 * math.sin(math.radians(t) * 6)

    parts = [
        k.shell(bark_m, nu=32, nv=9, v1=0.68, warp=bark, **e),
        k.shell(cap_m, nu=28, nv=6, v0=cap_edge, warp=lambda t, v: 0.11 + 0.03 * math.sin(math.radians(t) * 10 + v * 30), name="cap", **e),
    ]
    p = k.egg_at(0, 0.63, 0.13, **e)[0]
    parts.append(k.ring(math.hypot(p.x, p.y), p.z, 0.1, lip, n=20, sides=5))
    top = k.egg_at(0, 1, 0.1, **e)[0]
    parts.append(k.tube([top - Vector((0, 0, 0.08)), top + Vector((0.02, 0, 0.17)), top + Vector((0.14, 0, 0.33))], [0.11, 0.075, 0.09], m=wood, n=6))

    # Moss climbs from the ground and drips from under the acorn cap.
    def moss_top(t):
        a = math.radians(t)
        return 0.26 + 0.08 * math.sin(a * 3) + 0.05 * math.sin(a * 7 + 1)

    def drip(t):
        return 0.6 - 0.1 * max(0.0, math.sin(math.radians(t) * 5)) ** 0.55

    parts.append(k.shell(moss, nu=30, nv=3, v1=moss_top, warp=lambda t, v: 0.08, name="moss", **e))
    parts.append(k.shell(moss, nu=50, nv=1, v0=drip, v1=0.64, warp=lambda t, v: 0.085, name="drip", **e))
    for theta, v, r in ((-105, 0.2, 0.36), (130, 0.17, 0.36), (-10, 0.11, 0.34), (235, 0.14, 0.32)):
        p = k.egg_at(theta, v, 0.05, **e)[0]
        parts.append(k.puff(r, p, moss, scale=(1, 1, 0.72), name="lump"))

    # Mushrooms lean out from the base, the biggest feature after the cap.
    for theta, reach, r, h, cap, lean in ((38, 1.0, 0.62, 1.0, red, 16), (-52, 0.98, 0.44, 0.72, tan, -14), (178, 0.98, 0.54, 0.86, red, 14)):
        a = math.radians(theta)
        place = Matrix.Translation((reach * math.sin(a), -reach * math.cos(a), 0)) @ k.rot_z(theta) @ Matrix.Rotation(math.radians(-abs(lean)), 4, "X")
        for ob in k.mushroom(r, h, cap, stem_m):
            ob.data.transform(place)
            parts.append(ob)
    # A small shelf mushroom and an oak-green leaf on the cap.
    for ob in k.mushroom(0.2, 0.3, tan, stem_m):
        parts.append(k.stick(ob, -120, 0.46, 0.02, **e))
    sprig = k.leaf(0.62, 0.2, leaf_m, droop=0.2)
    sprig.data.transform(Matrix.Translation(top + Vector((0.1, -0.02, 0.2))) @ k.rot_z(-30))
    parts.append(sprig)
    return parts


def egg_sunset():
    e = dict(H=2.62, R=1.06)
    body = k.paint(
        "su_shell",
        [(0, (255, 112, 170)), (0.38, (255, 132, 140)), (0.72, (255, 170, 84)), (1, (255, 205, 110))],
        0,
        2.7,
    )
    gold = k.paint("su_gold", [(0, (255, 186, 70)), (1, (255, 232, 130))], 1.6, 3.1)
    cloud = k.paint("su_cloud", [(0, (255, 214, 232)), (1, (255, 250, 245))], 0, 1.5)
    parts = [k.shell(body, nu=28, nv=12, **e), k.shell(gold, nu=28, nv=4, v0=0.8, warp=lambda t, v: 0.07, name="sun", **e)]

    # The sun sits on top of the egg: a collar of flat wedges, broad beams down the shell.
    for i in range(12):
        theta = i * 30
        long_ray = i % 2 == 0
        h = 0.72 if long_ray else 0.46
        ray = k.cyl(0.26 if long_ray else 0.2, h, (0, 0, h / 2), m=gold, n=4, r2=0, name="ray")
        ray.data.transform(k.rot_z(45))
        ray.data.transform(Matrix.Diagonal((1, 0.34, 1, 1)))
        p, n = k.egg_at(theta, 0.8, -0.1, **e)
        out = Vector((n.x, n.y, 0)).normalized()
        aim = (out + Vector((0, 0, 0.34))).normalized()
        side = Vector((0, 0, 1)).cross(out).normalized()
        frame = Matrix((side, aim.cross(side), aim)).transposed().to_4x4()
        ray.data.transform(Matrix.Translation(p) @ frame)
        parts.append(ray)
    for i in range(12):
        theta = i * 30 + 15
        reach = 0.34 if i % 2 == 0 else 0.5
        path = [(theta, 0.8 - (0.8 - reach) * j / 4) for j in range(5)]
        parts.append(k.ridge(path, [0.2, 0.16, 0.11, 0.06, 0.012], 0.05, gold, **e))

    # Wispy clouds: stacks of tapered wind strokes round the lower shell.
    for start, v, sweep in ((-78, 0.33, 76), (22, 0.26, 70), (112, 0.34, 72), (205, 0.27, 70)):
        for offset, dv, length in ((0, 0.07, 0.72), (-14, 0.0, 1.0), (10, -0.065, 0.66)):
            count = 6
            path = [(start + offset + sweep * length * j / count, v + dv + 0.012 * math.sin(j / count * 6.3)) for j in range(count + 1)]
            widths = [0.012 + 0.066 * math.sin(j / count * math.pi) ** 1.3 for j in range(count + 1)]
            parts.append(k.ridge(path, widths, 0.06, cloud, **e))
    for theta, r, z in ((-24, 0.44, 0.08), (32, 0.38, 0.1), (88, 0.44, 0.06), (146, 0.38, 0.1), (204, 0.44, 0.06), (262, 0.38, 0.1), (316, 0.42, 0.08)):
        p = k.egg_at(theta, 0.1, 0.12, **e)[0]
        parts.append(k.puff(r, (p.x, p.y, z + r * 0.5), cloud, name="cloud"))
    return parts


def egg_moon():
    e = dict(H=2.42, R=0.94)
    lift = 0.5
    body = k.paint(
        "mo_shell",
        [(0, (34, 34, 96)), (0.6, (48, 58, 128)), (1, (70, 84, 168))],
        lift,
        lift + 2.42,
        dots=[((170, 185, 245), 5, 0.1)],
    )
    rim = k.flat((104, 120, 200))
    floor = k.flat((38, 40, 104))
    silver = k.paint("mo_crescent", [(0, (255, 232, 170)), (1, (255, 248, 214))], 0, 3.0, dots=[((244, 208, 140), 2.6, 0.2)])
    thread = k.flat((255, 236, 180))
    star_m = k.glow((255, 245, 190))

    parts = [k.shell(body, nu=26, nv=13, **e)]
    for theta, v, r in ((-28, 0.66, 0.3), (24, 0.42, 0.24), (70, 0.68, 0.22), (150, 0.55, 0.3), (215, 0.38, 0.24), (265, 0.7, 0.22)):
        bowl = k.lathe([(r * 1.1, -0.03), (r, 0.03), (r * 0.76, 0.05), (r * 0.62, 0.012)], m=rim, n=12, name="crater_rim")
        base = k.lathe([(r * 0.66, 0.0), (0, 0.012)], m=floor, n=12, name="crater_floor")
        k.stick([bowl, base], theta, v, -0.01, **e)
        parts += [bowl, base]
    glow = []
    for theta, v, r, spin in ((-62, 0.52, 0.17, 10), (6, 0.62, 0.2, -12), (48, 0.82, 0.15, 20), (108, 0.42, 0.16, 0), (182, 0.76, 0.18, 30), (240, 0.56, 0.15, -20), (-12, 0.3, 0.13, 8)):
        glow.append(k.stick(k.star(r, star_m), theta, v, 0.0, spin=spin, **e))
    moved(parts + glow, z=lift)

    # The crescent: inner edge hugs the egg, outer edge bulges, tapering to two tips.
    centre = Vector((0, 0, lift + 1.21))
    points, radii = [], []
    steps = 15
    for i in range(steps + 1):
        s = i / steps * 2 - 1
        a = s * math.radians(116)
        r = 0.05 + 0.46 * math.cos(s * math.pi / 2) ** 0.75
        out = 1.17 + r * 0.92
        points.append(centre + Vector((math.sin(a) * out, 0, -math.cos(a) * out * 1.14)))
        radii.append(r)
    moon = k.tube(points, radii, m=silver, n=14, name="crescent")
    tilt = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(-14), 4, "Y") @ Matrix.Diagonal((1, 0.86, 1, 1)) @ Matrix.Translation(-centre)
    moon.data.transform(tilt)
    tips = [tilt @ points[0], tilt @ points[-1]]
    parts.append(moon)

    # A big star stands on the high horn on a little wire, a smaller one on the low horn.
    for tip, rise, r, lean in ((tips[1], 0.22, 0.34, 0.1), (tips[0], 0.18, 0.27, -0.1)):
        end = tip + Vector((lean, 0, rise))
        parts.append(k.tube([tip - Vector((0, 0, 0.1)), end], 0.03, m=thread, n=5, name="wire"))
        s = k.star(r, star_m)
        s.data.transform(Matrix.Translation(end + Vector((0, 0, r * 0.7))) @ Matrix.Rotation(math.radians(90), 4, "X"))
        glow.append(s)
    for ob in parts + glow:
        ob.data.transform(Matrix.Scale(0.9, 4))
    return {"": parts, "glow": glow}


def _star_outline(r, inner):
    points = []
    for i in range(10):
        a = math.pi * i / 5 + math.pi / 2
        rr = r if i % 2 == 0 else inner
        points.append((rr * math.cos(a), rr * math.sin(a)))
    return points


def egg_star():
    e = dict(H=2.72, R=1.06)
    shades = [k.flat(c) for c in ((255, 230, 120), (255, 200, 66), (242, 160, 40), (208, 120, 30), (160, 84, 24))]
    edge = k.flat((255, 236, 150), name="st_edge")
    deep = k.flat((150, 80, 26), name="st_pocket")
    frame_m = k.flat((255, 232, 130), name="st_frame")
    middle = 1.3

    # Antiprism gem on an egg profile, each ring turned half a step, every edge cut bright.
    n = 12
    levels = [(0.3, 0.0), (0.76, 0.26), (1.02, 0.72), (1.12, 1.26), (1.02, 1.78), (0.76, 2.24), (0.4, 2.6)]
    bm = bmesh.new()
    rings = []
    for j, (r, z) in enumerate(levels):
        turn = (j % 2) * math.pi / n
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / n + turn), r * math.sin(2 * math.pi * i / n + turn), z)) for i in range(n)])
    tip = bm.verts.new((0, 0, 2.82))
    for j in range(len(rings) - 1):
        a, b = rings[j], rings[j + 1]
        for i in range(n):
            if j % 2 == 0:
                bm.faces.new((a[i], a[(i + 1) % n], b[i]))
                bm.faces.new((a[(i + 1) % n], b[(i + 1) % n], b[i]))
            else:
                bm.faces.new((a[i], b[(i + 1) % n], b[i]))
                bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n]))
    for i in range(n):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], tip))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cuts = bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.016, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    bm.faces.index_update()
    bright = {f.index for f in cuts["faces"]}
    bm.normal_update()
    gem = k._obj("gem", bm, shades[0])
    k.facet(gem, shades + [edge], skip=bright)

    # Star pockets, front and back, show the glowing core.
    for y in (-1.1, 1.1):
        k.boolean(gem, k.poly(_star_outline(0.78, 0.36), 1.5, loc=(0, y, middle), m=deep, name="pocket"))
    k.apply_cuts()
    k.sharpen(gem)
    core = k.ico(0.8, (0, 0, middle), m=k.glow((255, 226, 120)), subdiv=2, name="core")

    # Wide cut points, like a Moravian star, kept clear of the two pockets.
    parts = [gem]
    points = [(t, 0.5, 0.86, 0.46) for t in (68, 112, 248, 292)]
    points += [(t, 0.76, 0.66, 0.36) for t in (0, 90, 180, 270)]
    points += [(t, 0.25, 0.4, 0.3) for t in (90, 270)]
    for theta, v, h, r in points:
        spike = k.cyl(r, h, (0, 0, h / 2), m=shades[0], n=5, r2=0, name="spike")
        k.stick(spike, theta, v, -0.2, spin=theta, **e)
        parts.append(k.facet(spike, shades))
    crown = k.cyl(0.34, 0.78, (0, 0, 2.98), m=shades[0], n=5, r2=0, name="crown")
    parts.append(k.facet(crown, shades))
    return {"": parts, "glow": [core]}


def _feather_wing(side, m):
    feathers = []
    shoulder = Vector((0.72, 0.34, 2.05))
    for length, width, angle, drop in (
        (2.05, 0.3, 66, 0.0),
        (2.1, 0.32, 48, -0.06),
        (1.95, 0.32, 30, -0.14),
        (1.7, 0.3, 12, -0.22),
        (1.4, 0.28, -8, -0.3),
        (1.25, 0.24, 55, 0.14),
        (1.2, 0.25, 28, 0.03),
        (1.0, 0.24, 2, -0.12),
    ):
        f = k.leaf(length, width, m, droop=0.1, n=4, steps=5, name="feather")
        place = (
            Matrix.Diagonal((side, 1, 1, 1))
            @ Matrix.Translation(shoulder + Vector((0, 0, drop)))
            @ Matrix.Rotation(math.radians(-angle), 4, "Y")
            @ Matrix.Rotation(math.radians(90), 4, "X")
        )
        f.data.transform(place)
        feathers.append(f)
    return feathers


def egg_celestial():
    e = dict(H=2.72, R=1.0)
    lift = 0.46
    pearl = k.paint(
        "ce_pearl",
        [(0, (255, 226, 214)), (0.37, (255, 246, 232)), (0.372, (78, 88, 205)), (0.545, (104, 96, 226)), (0.547, (255, 252, 244)), (1, (246, 240, 255))],
        lift,
        lift + 2.72,
    )
    gold = k.paint("ce_gold", [(0, (252, 190, 76)), (0.35, (255, 212, 104)), (1, (255, 236, 150))], 0, 3.0)
    plume_r = k.paint("ce_plume_r", [(0, (255, 251, 240)), (0.42, (255, 240, 200)), (1, (255, 190, 64))], 0.7, 2.75, axis="X")
    plume_l = k.paint("ce_plume_l", [(0, (255, 251, 240)), (0.42, (255, 240, 200)), (1, (255, 190, 64))], -0.7, -2.75, axis="X")
    light = k.glow((255, 214, 110))

    parts = [k.shell(pearl, nu=24, nv=12, **e)]
    # Gold belt with a scalloped band, ribs to the crown, a lotus cup at the foot.
    for v in (0.42, 0.53):
        parts.append(k.ridge([(i * 22.5, v) for i in range(17)], 0.055, 0.05, gold, **e))
    parts.append(k.ridge([(i * 11.25, 0.475 + 0.032 * math.cos(math.radians(i * 11.25 * 12))) for i in range(33)], 0.024, 0.04, gold, **e))
    for i in range(8):
        theta = i * 45 + 22.5
        parts.append(k.ridge([(theta, 0.55 + 0.42 * s / 5) for s in range(6)], [0.06, 0.05, 0.045, 0.04, 0.04, 0.05], 0.035, gold, **e))
    for i in range(8):
        theta = i * 45
        parts.append(k.ridge([(theta, 0.02), (theta, 0.1), (theta, 0.18), (theta, 0.27)], [0.05, 0.22, 0.17, 0.012], 0.07, gold, **e))

    # Constellations, front and back, on the upper shell.
    glow = []
    for nodes, lines in (
        ([(-34, 0.74), (-6, 0.84), (24, 0.76), (40, 0.62), (-14, 0.63)], [(0, 1), (1, 2), (2, 3), (0, 4), (4, 2)]),
        ([(150, 0.8), (178, 0.68), (206, 0.78), (232, 0.64), (170, 0.6)], [(0, 1), (1, 2), (2, 3), (1, 4)]),
        ([(-92, 0.3), (-62, 0.24), (-38, 0.32)], [(0, 1), (1, 2)]),
        ([(88, 0.32), (118, 0.24), (146, 0.33)], [(0, 1), (1, 2)]),
    ):
        for a, b in lines:
            (t0, v0), (t1, v1) = nodes[a], nodes[b]
            path = [(t0 + (t1 - t0) * j / 4, v0 + (v1 - v0) * j / 4) for j in range(5)]
            glow.append(k.ridge(path, 0.03, 0.03, light, **e))
        for t, v in nodes:
            glow.append(k.stick(k.star(0.17, light, points=4, inner=0.3), t, v, 0.015, **e))
    for t in (0, 180):
        parts.append(k.stick(k.lathe([(0.3, -0.02), (0.28, 0.05), (0.21, 0.07), (0.19, 0.03)], m=gold, n=12, name="setting"), t, 0.475, 0.0, **e))
        glow.append(k.stick(k.star(0.24, light, points=4, inner=0.34), t, 0.475, 0.03, **e))
    moved(parts + glow, z=lift)

    # Pedestal, crown finial, halo.
    parts.append(
        k.lathe(
            [(0.82, 0.0), (0.84, 0.1), (0.66, 0.16), (0.3, 0.3), (0.26, 0.4), (0.42, 0.52), (0, 0.56)],
            m=gold,
            n=16,
            name="foot",
        )
    )
    top = lift + 2.72
    parts.append(
        k.lathe(
            [(0.3, top - 0.1), (0.24, top + 0.02), (0.1, top + 0.1), (0.13, top + 0.2), (0.05, top + 0.3), (0, top + 0.34)],
            m=gold,
            n=10,
            name="finial",
        )
    )
    s = k.star(0.26, light, points=4, inner=0.3)
    s.data.transform(Matrix.Translation((0, 0, top + 0.56)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    glow.append(s)
    glow.append(k.ring(0.58, top + 0.3, 0.05, light, n=20, sides=5, name="halo"))
    glow[-1].data.transform(Matrix.Translation((0, 0, top + 0.3)) @ Matrix.Rotation(math.radians(-14), 4, "X") @ Matrix.Translation((0, 0, -top - 0.3)))

    # The orbit: a tilted gold ring with three moons riding on it.
    orbit = k.ring(1.72, 0, 0.065, gold, n=28, sides=5, name="orbit")
    tilt = Matrix.Translation((0, 0, lift + 1.2)) @ Matrix.Rotation(math.radians(-13), 4, "Y") @ Matrix.Rotation(math.radians(20), 4, "X")
    orbit.data.transform(tilt)
    parts.append(orbit)
    for a, r in ((20, 0.15), (150, 0.12), (265, 0.17)):
        x, y = 1.72 * math.cos(math.radians(a)), 1.72 * math.sin(math.radians(a))
        glow.append(k.sphere(r, tilt @ Vector((x, y, 0)), m=light, seg=8, rings=5, name="moonlet"))

    parts += _feather_wing(1, plume_r) + _feather_wing(-1, plume_l)
    return {"": parts, "glow": glow}


def egg_shell_fragment():
    """A curved jagged shard; tinted per egg by code, so it is uploaded untextured."""
    e = dict(H=1.9, R=0.72)
    # A smooth shell arc on top, a broken zigzag below: the classic cartoon shard.
    outline = [(-1, 0.45), (-0.56, 0.84), (0, 1), (0.56, 0.84), (1, 0.45), (0.76, -0.1), (0.46, 0.3), (0.16, -0.32), (-0.16, 0.2), (-0.46, -0.28), (-0.76, 0.12)]
    bm = bmesh.new()

    def rim(scale, lift):
        return [bm.verts.new(k.egg_at(60 * x * scale, 0.5 + 0.2 * (y - 0.3) * scale, lift, **e)[0]) for x, y in outline]

    outer, outer_mid, outer_hub = rim(1, 0), rim(0.5, 0), bm.verts.new(k.egg_at(0, 0.5, 0, **e)[0])
    inner, inner_mid, inner_hub = rim(1, -0.07), rim(0.5, -0.07), bm.verts.new(k.egg_at(0, 0.5, -0.07, **e)[0])
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        for edge, mid, hub in ((outer, outer_mid, outer_hub), (inner, inner_mid, inner_hub)):
            bm.faces.new((edge[i], edge[j], mid[j], mid[i]))
            bm.faces.new((mid[i], mid[j], hub))
        bm.faces.new((outer[i], outer[j], inner[j], inner[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return [k._obj("shard", bm, k.paint("sh_shell", [(0, k.CREAM), (1, (255, 250, 236))], 0, 1.2, dots=[((240, 170, 180), 8, 0.15)]))]


NOTES = "Plots.egg replacement; scale to the manifest height, keep the bed and hatch logic."
ASSETS = [
    dict(name="egg_starter", build=egg_starter, budget=2500, size=[2.2, 3, 2.2], priority=1, order=1, replaces="Plots.egg starter (src/garden/Plots.luau 274-295)",
         notes=NOTES),
    dict(name="egg_meadow", build=egg_meadow, budget=2500, size=[2.2, 3, 2.2], priority=1, order=2, replaces="Plots.egg meadow (src/garden/Plots.luau 274-295)",
         notes=NOTES),
    dict(name="egg_forest", build=egg_forest, budget=2500, size=[2.2, 3, 2.2], priority=1, order=3, replaces="Plots.egg forest (src/garden/Plots.luau 274-295)",
         notes=NOTES),
    dict(name="egg_sunset", build=egg_sunset, budget=2500, size=[2.2, 3, 2.2], priority=1, order=4, replaces="Plots.egg sunset (src/garden/Plots.luau 274-295)",
         notes=NOTES),
    dict(name="egg_moon", build=egg_moon, budget=2500, size=[2.2, 3, 2.2], priority=1, order=5, replaces="Plots.egg moon (src/garden/Plots.luau 274-295)",
         notes=NOTES + " egg_moon_glow is Neon.", glow={"glow": (255, 245, 190)}),
    dict(name="egg_star", build=egg_star, budget=2500, size=[2.2, 3, 2.2], priority=1, order=6, replaces="Plots.egg star (src/garden/Plots.luau 274-295)",
         notes=NOTES + " egg_star_glow is the Neon core seen through star pockets, front and back.", glow={"glow": (255, 226, 120)}),
    dict(name="egg_celestial", build=egg_celestial, budget=2500, size=[2.2, 3, 2.2], priority=1, order=7, replaces="New top tier; no egg today",
         notes="New top tier, deliberately larger than the others. egg_celestial_glow (halo, constellations, moonlets, crown star) is Neon.", glow={"glow": (255, 214, 110)}),
    dict(name="egg_shell_fragment", build=egg_shell_fragment, budget=200, size=[1.1, 1.1, 0.4], priority=1, order=8, replaces="Hatch burst shell pieces (src/garden-client/HatchFx.client.luau)",
         notes="Upload skips its texture so code can tint it from EGG_COLOURS; set Color, spin and scale per piece."),
]
