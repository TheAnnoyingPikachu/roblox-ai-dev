"""Lantern Express stop tiles and their house set (docs/game-design/game6-art-bible.md sections 4
and 6; docs/architecture/lantern.md section 9). house_cottage is the style-test house of the
stop_village set: LANTERN-009 builds the 120 x 160 stop_village tile from it, it is not in the v0.1
upload list on its own. Built at stud scale, front (the platform edge, which faces the track) -Y,
ground at z = 0, platform top at PLATFORM. Two meshes: the textured body and a Neon `glow` mesh."""

import math

import kit as k
from mathutils import Matrix, Vector

PLATFORM = 2.0  # platform top: depot_platform is 2 high (art bible section 5)
CY = 2.4  # the cottage's round body is centred this far behind the origin
WALL = (7.0, 5.4)  # wall radii x, y
EAVE = (9.4, 7.6)  # roof radii at the eaves
Z_EAVE, ROOF_H = 9.0, 6.6


def frame_at(p, n):
    """Matrix placing local +Z along n at p, local +Y as close to up as possible."""
    x, y, z = k._frame(n)
    return Matrix.Translation(p) @ Matrix((x, y, z)).transposed().to_4x4()


def dome(t):
    """Roof radius (fraction of the eaves) at height fraction t: a full, slightly bell-shaped cap."""
    return max(0.0, 1 - t * t) ** 0.55 + 0.05 * (1 - t) ** 4


def roof_tier(t0, t1, tongues, m, name="tier"):
    """One ring of round shingles from roof height fraction t0 up to t1 (tucked under the next
    ring): its hem flares out and hangs in `tongues` round scallops."""

    def fn(u, v):
        a = 2 * math.pi * u
        t = t0 + (t1 - t0) * v
        hem = (1 - v) ** 3
        r = dome(t) + 0.025 * hem
        drop = 0.32 * hem * abs(math.sin(tongues * a / 2)) ** 0.6
        return (EAVE[0] * r * math.cos(a), CY + EAVE[1] * r * math.sin(a), Z_EAVE + t * ROOF_H - drop)

    return k.surface(tongues * 4, 2, fn, m=m, thickness=0.26, name=name)


def round_window(walls, theta, z, r, timber, glow, flowers=None):
    """A round window on the wall at `theta` degrees round from the front: a glowing pane, a
    timber ring and cross, and a flower box under it."""
    p, n = k.land(walls, (0, CY, z), k.outward(theta, 0))
    f = frame_at(p, n)
    pane = k.cyl(r * 0.95, 0.06, m=glow, n=24, name="pane")
    pane.data.transform(f @ Matrix.Translation((0, 0, 0.02)))
    ring = k.ring(r, 0, r * 0.16, timber, n=20, sides=6, name="frame")
    ring.data.transform(f @ Matrix.Translation((0, 0, 0.06)))
    cross = [k.box((2 * r, 0.12, 0.08), (0, 0, 0.08), m=timber, name="mullion"), k.box((0.12, 2 * r, 0.08), (0, 0, 0.08), m=timber, name="mullion")]
    parts = [ring, *cross]
    if flowers:
        parts.append(k.box((2.0 * r, 0.6, 0.45), (0, -r - 0.4, 0.3), m=timber, bevel=0.05, name="flower_box"))
        for i, (dx, m) in enumerate(zip((-0.55, 0.0, 0.55), flowers)):
            parts.append(k.ico(0.26, (dx * r * 1.3, -r - 0.05, 0.32), m=m, subdiv=1, scale=(1, 1, 0.8), name="flowers"))
    for ob in cross + parts[3:]:
        ob.data.transform(f)
    return parts, [pane]


def house_cottage():
    cream = k.paint("sc_plaster", [(0, (226, 204, 178)), (0.35, k.CREAM), (1, (255, 246, 228))], PLATFORM, Z_EAVE, grain=(0.05, 3.0))
    plinth = k.brick("sc_plinth", lo=0, hi=PLATFORM, around=(0, CY, 6.6))
    face = k.brick("sc_face", lo=0, hi=PLATFORM)
    chimney_brick = k.brick("sc_chimney", lo=11, hi=16)
    stone = k.paint("sc_stone", [(0, (196, 186, 176)), (1, (226, 218, 206))], 2.0, 2.8, grain=(0.08, 2.0))
    boards = k.paint("sc_boards", [(0, (150, 106, 78)), (1, (150, 106, 78))], -1, 1, axis="Y", bands=((128, 88, 64), 0.85), grain=(0.1, 4, "wave"))
    tiles = k.paint("sc_tiles", [(0, (96, 50, 90)), (0.6, k.ROOF_PLUM), (1, k.ROOF_PLUM_HI)], Z_EAVE - 0.4, Z_EAVE + ROOF_H, grain=(0.06, 1.5))
    timber = k.mat("sc_timber", k.TIMBER, kind="wood", scale=3, var=0.1)
    door_m = k.paint("sc_door", [(0, (40, 98, 110)), (1, (72, 138, 146))], PLATFORM, 8.2, axis="Z", grain=(0.12, 5, "wave"))
    iron = k.flat(k.IRON)
    brass = k.brass("sc_brass", 2.0, 16.0)
    glow = k.flat(k.WINDOW_GLOW)
    flowers = [k.flat((255, 150, 190)), k.flat((255, 214, 110)), k.flat((200, 170, 255))]
    body, lit = [], []

    # Platform along the track: brick face, stone coping with a cream edge line, plank deck.
    body.append(k.box((20.0, 6.6, PLATFORM - 0.3), (0, -5.7, (PLATFORM - 0.3) / 2), m=face, name="platform"))
    body.append(k.box((20.4, 6.9, 0.3), (0, -5.75, PLATFORM - 0.15), m=boards, bevel=0.05, name="deck"))
    body.append(k.box((20.6, 0.9, 0.36), (0, -8.85, PLATFORM - 0.1), m=stone, bevel=0.08, seg=2, name="coping"))
    body.append(k.box((20.2, 0.32, 0.04), (0, -8.75, PLATFORM + 0.09), m=k.flat(k.CREAM), name="edge_line"))

    # Round body: brick plinth, cream walls, a timber band under the eaves.
    body.append(k.lathe([(1.03, 0), (1.03, PLATFORM)], loc=(0, CY, 0), m=plinth, n=48, scale=(WALL[0] + 0.4, WALL[1] + 0.4, 1), name="plinth"))
    walls = k.lathe([(1.0, PLATFORM - 0.1), (1.012, 5.6), (1.0, Z_EAVE + 0.4)], loc=(0, CY, 0), m=cream, n=48, scale=(WALL[0], WALL[1], 1), name="walls")
    body.append(walls)
    body.append(k.lathe([(1.02, Z_EAVE - 0.7), (1.025, Z_EAVE + 0.1)], loc=(0, CY, 0), m=timber, n=48, scale=(WALL[0], WALL[1], 1), name="beam"))

    # Roof: four rings of round shingles, a crown cap, a brass finial; a brick chimney.
    for i, (t0, t1, tongues) in enumerate(((0.0, 0.33, 26), (0.26, 0.56, 22), (0.5, 0.76, 17), (0.7, 0.9, 12))):
        body.append(roof_tier(t0, t1, tongues, tiles, name=f"tier{i}"))
    cap = [(dome(t), Z_EAVE + t * ROOF_H) for t in (0.84, 0.9, 0.95, 0.99)] + [(0, Z_EAVE + ROOF_H + 0.05)]
    body.append(k.lathe(cap, loc=(0, CY, 0), m=tiles, n=32, scale=(EAVE[0], EAVE[1], 1), name="crown"))
    top = Z_EAVE + ROOF_H
    body.append(k.capsule((0, CY, top - 0.2), (0, CY, top + 0.9), 0.12, 0.06, brass, n=10, name="spike"))
    body.append(k.sphere(0.32, (0, CY, top + 0.35), m=brass, seg=20, rings=10, name="finial"))
    cx, cy = 4.4, CY + 2.6
    body.append(k.box((1.5, 1.5, 4.6), (cx, cy, 13.3), m=chimney_brick, name="chimney"))
    body.append(k.box((1.9, 1.9, 0.36), (cx, cy, 15.75), m=stone, bevel=0.06, name="chimney_cap"))
    body.append(k.lathe([(0.32, 0), (0.36, 0.5), (0.42, 0.62), (0.3, 0.66)], loc=(cx, cy, 15.9), m=k.paint("sc_pot", [(0, (190, 96, 70)), (1, (214, 124, 90))], 15.9, 16.6), n=12, name="pot"))

    # Dormer: a round lit window under a little hood, standing out of the roof's front.
    dz = Z_EAVE + 0.42 * ROOF_H
    dy = CY - EAVE[1] * dome(0.36)  # front just proud of the roof: a dormer, not a spyglass
    body.append(k.cyl(1.05, CY - 1.0 - dy, (0, (CY - 1.0 + dy) / 2, dz), rot=(90, 0, 0), m=cream, n=24, name="dormer"))
    hood = k.surface(16, 3, lambda u, v: (1.35 * math.cos(math.pi * u), CY - 1.0 + (dy - 0.35 - CY + 1.0) * v, dz + 1.35 * math.sin(math.pi * u)), m=tiles, thickness=0.22, name="hood")
    body.append(hood)
    df = frame_at(Vector((0, dy, dz)), Vector((0, -1, 0)))
    pane = k.cyl(0.7, 0.06, m=glow, n=20, name="pane")
    pane.data.transform(df @ Matrix.Translation((0, 0, 0.02)))
    lit.append(pane)
    ring = k.ring(0.74, 0, 0.12, timber, n=20, sides=6, name="frame")
    ring.data.transform(df @ Matrix.Translation((0, 0, 0.05)))
    body.append(ring)

    # Front door: round-topped planks in a brick arch, a lit porthole, a brass knob, a step.
    dw, dh = 3.4, 5.8
    p, n = k.land(walls, (0, CY, 4), (0, -1, 0))
    yd = p.y - 0.05  # door slab 0.4 deep: its back is in the wall, the brick arch stands 0.2 proud
    arch = [(dw / 2, 0), (dw / 2, dh - dw / 2)] + [(dw / 2 * math.cos(math.pi * i / 12), dh - dw / 2 + dw / 2 * math.sin(math.pi * i / 12)) for i in range(1, 12)] + [(-dw / 2, dh - dw / 2), (-dw / 2, 0)]
    body.append(k.poly(arch, 0.4, loc=(0, yd, PLATFORM), m=door_m, name="door"))
    rim = [(x * 1.12, z * 1.03) for x, z in arch[1:-1]]
    body.append(k.tube([Vector((x, yd - 0.1, PLATFORM + z)) for x, z in [(dw / 2 * 1.12, 0)] + rim + [(-dw / 2 * 1.12, 0)]], 0.3, m=face, n=6, name="door_arch"))
    df = frame_at(Vector((0, yd - 0.2, PLATFORM + dh - 1.3)), Vector((0, -1, 0)))
    pane = k.cyl(0.46, 0.06, m=glow, n=20, name="pane")
    pane.data.transform(df @ Matrix.Translation((0, 0, 0.02)))
    lit.append(pane)
    ring = k.ring(0.5, 0, 0.09, brass, n=20, sides=6, name="porthole")
    ring.data.transform(df @ Matrix.Translation((0, 0, 0.04)))
    body.append(ring)
    body.append(k.sphere(0.16, (1.05, yd - 0.26, PLATFORM + 2.6), m=brass, seg=12, rings=6, name="knob"))
    body.append(k.box((4.6, 1.2, 0.2), (0, yd - 0.6, PLATFORM + 0.1), m=stone, bevel=0.05, name="step"))

    # Windows: two either side of the door with flower boxes, one on each side wall.
    for theta, fl in ((-42, flowers), (42, flowers[::-1]), (-100, None), (100, None)):
        parts, panes = round_window(walls, theta, 5.9, 1.0, timber, glow, fl)
        body += parts
        lit += panes

    # Platform sign: a post with a bracket arm, a hanging roundel (cranberry ring, cream field,
    # amber lantern), a small lamp on top. A bench and a lamp post.
    sx, sy = -7.2, -7.6
    body.append(k.cyl(0.16, 5.6, (sx, sy, PLATFORM + 2.8), m=iron, n=10, name="sign_post"))
    body.append(k.lathe([(0.4, 0), (0.4, 0.3), (0.2, 0.5), (0.16, 0.6)], loc=(sx, sy, PLATFORM), m=iron, n=12, name="sign_foot"))
    body.append(k.box((2.4, 0.14, 0.14), (sx + 1.1, sy, PLATFORM + 5.2), m=iron, name="sign_arm"))
    c = Vector((sx + 1.5, sy, PLATFORM + 3.75))
    roundel = k.paint("sc_roundel", [(0, k.CRANBERRY), (1, k.CRANBERRY)], 0, 1,
                      marks=[(k.CREAM, c, 0, 0.92), (k.AMBER, c + Vector((0, 0, -0.06)), 0, 0.36), (k.IRON, c + Vector((0, 0, 0.42)), 0, 0.14), (k.IRON, c + Vector((0, 0, -0.5)), 0, 0.1)])
    body.append(k.cyl(1.22, 0.16, c, rot=(90, 0, 0), m=roundel, n=32, bevel=0.03, name="roundel"))
    for dx in (-0.6, 0.6):
        body.append(k.tube([(c.x + dx, sy, c.z + 1.0), (c.x + dx, sy, PLATFORM + 5.15)], 0.03, m=iron, n=4, name="chain"))
    lamp_z = PLATFORM + 5.6
    body.append(k.box((0.7, 0.7, 0.12), (sx, sy, lamp_z + 0.05), m=brass, name="sign_lamp_base"))
    lit.append(k.box((0.5, 0.5, 0.6), (sx, sy, lamp_z + 0.4), m=glow, name="sign_lamp"))
    body.append(k.hull([(sx + x * 0.45, sy + y * 0.45, lamp_z + 0.7) for x in (-1, 1) for y in (-1, 1)] + [(sx, sy, lamp_z + 1.15)], iron, name="sign_lamp_roof"))

    px, py = 7.4, -7.6
    body.append(k.lathe([(0.45, 0), (0.45, 0.35), (0.22, 0.6), (0.17, 0.75)], loc=(px, py, PLATFORM), m=iron, n=12, name="post_foot"))
    body.append(k.cyl(0.15, 5.2, (px, py, PLATFORM + 2.9), m=iron, n=10, name="post"))
    lz = PLATFORM + 5.5
    body.append(k.lathe([(0.3, 0), (0.5, 0.15), (0.5, 0.22)], loc=(px, py, lz), m=brass, n=6, name="post_cup"))
    lit.append(k.lathe([(0.42, 0.2), (0.55, 0.9), (0.55, 1.2)], loc=(px, py, lz), m=glow, n=6, name="post_lamp"))
    for i in range(6):
        a = math.pi / 3 * i
        body.append(k.box((0.08, 0.08, 1.0), (px + 0.56 * math.cos(a), py + 0.56 * math.sin(a), lz + 0.72), rot=(0, 0, math.degrees(a)), m=brass, name="post_bar"))
    body.append(k.lathe([(0.75, 1.18), (0.7, 1.3), (0.3, 1.65), (0.12, 1.75), (0, 1.8)], loc=(px, py, lz), m=iron, n=6, name="post_roof"))
    body.append(k.sphere(0.12, (px, py, lz + 1.9), m=brass, seg=10, rings=6, name="post_finial"))

    bx, by = 3.8, -4.7
    body.append(k.box((3.6, 0.9, 0.18), (bx, by, PLATFORM + 1.0), m=timber, bevel=0.05, name="bench_seat"))
    body.append(k.box((3.6, 0.14, 0.7), (bx, by + 0.42, PLATFORM + 1.55), m=timber, bevel=0.04, name="bench_back"))
    for dx in (-1.5, 1.5):
        body.append(k.box((0.16, 0.8, 0.95), (bx + dx, by + 0.05, PLATFORM + 0.48), m=iron, name="bench_leg"))
    return {"": body, "glow": lit}


ASSETS = [
    dict(name="house_cottage", build=house_cottage, budget=10000, finalize=k.HD, size=[20.6, 16.5, 20], priority=1, order=10,
         replaces="none (style-test house of the stop_village set; not uploaded on its own)",
         notes=("Ground at y = 0, platform top at 2, platform edge facing -Z towards the track. Two meshes: house_cottage (textured) and "
                "house_cottage_glow (Neon: windows, door porthole, dormer, the sign lamp and the lamp post). Code adds a PointLight per lit window (range 12, brightness 1.2) "
                "and on the lamp post (range 18). Mesh CanCollide false; collide with invisible parts: the platform box and a cylinder for the house."),
         glow={"glow": k.WINDOW_GLOW}),
]
