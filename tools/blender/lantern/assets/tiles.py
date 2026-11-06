"""Lantern Express stop tiles and their house set (docs/game-design/game6-art-bible.md sections 4
and 6; docs/architecture/lantern.md section 9). house_cottage is the style-test house; the
stop_village tile stands it on its ground plate as the hero house. Built at stud scale, front (the
platform edge, which faces the track) -Y, ground at z = 0, platform top at PLATFORM. Two meshes per
asset: the textured body and a Neon `glow` mesh (the lighthouse adds a `beacon_glow`).

Stop tiles are 120 x 160 ground plates (the bounding box). LAYOUT is the tiles' contract for
LanternConfig.TILES (LANTERN-003): building blocks, the 8 big and 24 small loot sites and the street
lamps, in the stop frame: x across the tile, d the depth from the platform's track edge (0) to the
far edge (160). The FBX arrives turned half round (Blender +Y lands on Roblox +Z, Garden README), so
at yaw 0 the stop frame's x is Blender -x and d is Blender y + 80 (P below)."""

import math

import bpy
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


def roof_tier(t0, t1, tongues, m, name="tier", c=(0, CY), eave=EAVE, z=Z_EAVE, h=ROOF_H, per=4):
    """One ring of round shingles from roof height fraction t0 up to t1 (tucked under the next
    ring): its hem flares out and hangs in `tongues` round scallops. A dome centred on c."""

    def fn(u, v):
        a = 2 * math.pi * u
        t = t0 + (t1 - t0) * v
        hem = (1 - v) ** 3
        r = dome(t) + 0.025 * hem
        drop = 0.32 * hem * abs(math.sin(tongues * a / 2)) ** 0.6
        return (c[0] + eave[0] * r * math.cos(a), c[1] + eave[1] * r * math.sin(a), z + t * h - drop)

    return k.surface(tongues * per, 2, fn, m=m, thickness=0.26, name=name)


def round_window(walls, theta, z, r, timber, glow, flowers=None, c=(0, CY), seg=20, sides=6, pane_n=24):
    """A round window on the wall at `theta` degrees round from the front: a glowing pane, a
    timber ring and cross, and a flower box under it."""
    p, n = k.land(walls, (c[0], c[1], z), k.outward(theta, 0))
    f = frame_at(p, n)
    pane = k.cyl(r * 0.95, 0.06, m=glow, n=pane_n, name="pane")
    pane.data.transform(f @ Matrix.Translation((0, 0, 0.02)))
    ring = k.ring(r, 0, r * 0.16, timber, n=seg, sides=sides, name="frame")
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


def sign(sx, sy, iron, brass, glow):
    """Platform sign: a post with a bracket arm, a hanging roundel (cranberry ring, cream field,
    amber lantern), a small lamp on top."""
    body, lit = [], []
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
    return body, lit


def post_lamp(px, py, iron, brass, glow, z0=PLATFORM):
    """The platform lamp post: an iron post with a six-sided brass lantern."""
    body, lit = [], []
    body.append(k.lathe([(0.45, 0), (0.45, 0.35), (0.22, 0.6), (0.17, 0.75)], loc=(px, py, z0), m=iron, n=12, name="post_foot"))
    body.append(k.cyl(0.15, 5.2, (px, py, z0 + 2.9), m=iron, n=10, name="post"))
    lz = z0 + 5.5
    body.append(k.lathe([(0.3, 0), (0.5, 0.15), (0.5, 0.22)], loc=(px, py, lz), m=brass, n=6, name="post_cup"))
    lit.append(k.lathe([(0.42, 0.2), (0.55, 0.9), (0.55, 1.2)], loc=(px, py, lz), m=glow, n=6, name="post_lamp"))
    for i in range(6):
        a = math.pi / 3 * i
        body.append(k.box((0.08, 0.08, 1.0), (px + 0.56 * math.cos(a), py + 0.56 * math.sin(a), lz + 0.72), rot=(0, 0, math.degrees(a)), m=brass, name="post_bar"))
    body.append(k.lathe([(0.75, 1.18), (0.7, 1.3), (0.3, 1.65), (0.12, 1.75), (0, 1.8)], loc=(px, py, lz), m=iron, n=6, name="post_roof"))
    body.append(k.sphere(0.12, (px, py, lz + 1.9), m=brass, seg=10, rings=6, name="post_finial"))
    return body, lit


def bench(bx, by, timber, iron, z0=PLATFORM):
    return [
        k.box((3.6, 0.9, 0.18), (bx, by, z0 + 1.0), m=timber, bevel=0.05, name="bench_seat"),
        k.box((3.6, 0.14, 0.7), (bx, by + 0.42, z0 + 1.55), m=timber, bevel=0.04, name="bench_back"),
        *[k.box((0.16, 0.8, 0.95), (bx + dx, by + 0.05, z0 + 0.48), m=iron, name="bench_leg") for dx in (-1.5, 1.5)],
    ]


def house_cottage(station=True, at=(0.0, 0.0)):
    """The style-test house. station=False drops its platform, sign, lamp and bench and stands it
    on the ground on stone steps; `at` moves it (Blender x, y of its origin)."""
    cream = k.paint("sc_plaster", [(0, (226, 204, 178)), (0.35, k.CREAM), (1, (255, 246, 228))], PLATFORM, Z_EAVE, grain=(0.05, 3.0))
    plinth = k.brick("sc_plinth", lo=0, hi=PLATFORM, around=(at[0], at[1] + CY, 6.6))
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
    if station:
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
    if not station:  # stone stairs down to the ground
        for i, (dy_, h) in enumerate(((0.6, 2.0), (1.7, 1.34), (2.8, 0.67))):
            body.append(k.box((4.6 - 0.2 * i, 1.1 if i else 1.2, h), (0, yd - dy_, h / 2), m=stone, bevel=0.05, name="stair"))

    # Windows: two either side of the door with flower boxes, one on each side wall.
    for theta, fl in ((-42, flowers), (42, flowers[::-1]), (-100, None), (100, None)):
        parts, panes = round_window(walls, theta, 5.9, 1.0, timber, glow, fl)
        body += parts
        lit += panes

    # Platform sign, a lamp post and a bench.
    if station:
        b, g = sign(-7.2, -7.6, iron, brass, glow)
        body += b
        lit += g
        b, g = post_lamp(7.4, -7.6, iron, brass, glow)
        body += b
        lit += g
        body += bench(3.8, -4.7, timber, iron)
    if at != (0.0, 0.0):
        for ob in body + lit:
            ob.data.transform(Matrix.Translation((at[0], at[1], 0)))
    return {"": body, "glow": lit}


# Stop tiles -------------------------------------------------------------------------------------

W, D = 120.0, 160.0  # the plate: x across, depth
GROUND = 0.2  # plate top: proud of the terrain so the two never z-fight
DECK, RAMP = 10.0, 15.0  # platform deck from the track edge to depth 10, ramp down to the ground at 15
PLAT_X = 54.0  # platform half length
BIG_DEPTHS = (22, 40, 58, 78, 96, 114, 132, 150)
BIG_R, SMALL_R = 4.0, 2.5  # clear radius round a big (critter, supply crate) and a small site

# Per tile, in the stop frame (module docstring): blocks {name: (x, d, w, dd, h)} (centre, width
# across, depth, height) that collide; lamps (x, d) where the street lamps stand (code hangs a
# PointLight, range 18, at 7.5 up); big and small sites (x, d). The platform deck (108 x 1.8 x 10
# on the plate, depth 0 to 10) and its ramp (depth 10 to 15, the whole length) are the same on
# every tile. Everything else on the ground is low and walkable.
LAYOUT = {
    "village": dict(
        blocks={
            "cottage": (22, 46, 15, 12, 17),
            "house_w": (-24, 38, 12, 10, 14),
            "house_nw": (-28, 124, 13, 13, 15),
            "house_ne": (28, 132, 12, 10.5, 14),
            "well": (0, 92, 5, 5, 7),
            "fence_1": (17.15, 36, 5.3, 0.5, 1.2),
            "fence_2": (26.9, 36, 5.4, 0.5, 1.2),
            "fence_3": (29.6, 37.8, 0.5, 3.6, 1.2),
            "tree_1": (-47, 72, 2, 2, 13),
            "tree_2": (49, 92, 2, 2, 14),
            "tree_3": (-50, 152, 2, 2, 12),
            "tree_4": (50, 152, 2, 2, 13),
            "tree_5": (-46, 22, 2, 2, 11),
        },
        lamps=[(6.5, 30), (-6.5, 62), (6.5, 118), (-6.5, 146)],
        big=[(-12, 22), (9, 40), (-12, 58), (24, 78), (-22, 96), (16, 114), (-10, 132), (20, 150)],
        small=[(-30, 18), (32, 20), (6, 26), (-38, 50), (38, 56), (-6, 48), (10, 66), (-30, 70), (40, 76), (-8, 82), (12, 100), (-42, 100),
               (36, 104), (-14, 112), (52, 120), (6, 128), (-44, 136), (40, 146), (-24, 146), (4, 150), (-52, 50), (52, 34), (24, 92), (-30, 108)],
    ),
    "farm": dict(
        blocks={
            "barn": (28, 96, 22, 30, 21),
            "silo": (49, 70, 8, 8, 24),
            "farmhouse": (-32, 42, 13, 11, 15),
            "hay_1": (17, 58, 6, 6, 5.5),
            "hay_2": (-28, 142, 6, 6, 5.5),
            "hay_3": (44, 140, 6, 6, 5.5),
            "cart": (48, 100, 4, 7, 3),
            "coop": (28, 148, 7, 6, 5),
            "fence_w": (-57.5, 95, 0.6, 64.6, 1.5),
            "fence_n": (-35.75, 127, 44.1, 0.6, 1.5),
            "fence_s": (-48.75, 63, 18.1, 0.6, 1.5),
            "fence_se": (-19, 63, 10.6, 0.6, 1.5),
            "fence_e": (-14, 69, 0.6, 12.6, 1.5),
            "tree_1": (-50, 22, 2, 2, 13),
            "tree_2": (52, 152, 2, 2, 14),
            "tree_3": (-52, 152, 2, 2, 12),
            "tree_4": (52, 30, 2, 2, 12),
        },
        lamps=[(-2.5, 30), (10.5, 62), (-2.5, 100), (10.5, 132)],
        big=[(-12, 22), (20, 40), (-8, 58), (-8, 78), (-36, 96), (10, 114), (26, 132), (-10, 150)],
        small=[(50, 18), (-40, 18), (12, 18), (32, 24), (0, 38), (-22, 42), (-50, 44), (50, 50), (32, 54), (10, 56), (-34, 68), (22, 70),
               (-50, 80), (50, 82), (12, 92), (-14, 100), (50, 112), (-50, 114), (-20, 122), (0, 132), (-50, 136), (50, 146), (12, 148), (-34, 148)],
    ),
    "windmill": dict(
        blocks={
            "windmill": (24, 100, 18, 18, 44),
            "cottage": (-28, 50, 13, 11, 15),
            "granary": (-30, 128, 14, 18, 13),
            "cart": (-40, 100, 4, 7, 3),
            "tree_1": (-50, 86, 2, 2, 14),
            "tree_2": (52, 40, 2, 2, 13),
            "tree_3": (52, 112, 2, 2, 12),
            "tree_4": (-52, 24, 2, 2, 12),
        },
        lamps=[(-6.5, 30), (6.5, 64), (-6.5, 100), (6.5, 136)],
        big=[(12, 22), (-12, 40), (10, 58), (36, 78), (-12, 96), (40, 114), (12, 132), (-16, 150)],
        small=[(-50, 18), (-24, 18), (34, 18), (-6, 20), (50, 34), (18, 40), (-40, 44), (34, 52), (50, 64), (-50, 68), (-20, 68), (-2, 72),
               (12, 86), (-44, 94), (50, 94), (6, 110), (-34, 110), (-50, 120), (-18, 122), (30, 130), (50, 148), (-46, 148), (28, 148), (2, 148)],
    ),
    "orchard": dict(
        blocks={
            **{f"apple_{i * 4 + j + 1}": (x, d, 2, 2, 15) for i, d in enumerate((34, 56, 78, 100, 122)) for j, x in enumerate((-44, -26, 26, 44))},
            "store": (32, 146, 16, 14, 13),
            "hives": (-36, 146, 8, 3, 2.6),
            "crates": (14, 96, 3.5, 2.5, 2),
            "crates_2": (-14, 60, 3.5, 2.5, 2),
        },
        lamps=[(6.5, 30), (-6.5, 66), (6.5, 104), (-6.5, 140)],
        big=[(-14, 22), (14, 40), (-35, 58), (35, 78), (-14, 96), (14, 114), (-35, 132), (8, 150)],
        small=[(50, 18), (-50, 18), (24, 18), (-34, 34), (34, 36), (-50, 46), (-10, 48), (50, 50), (22, 60), (4, 70), (-50, 72), (-18, 74),
               (-32, 86), (16, 90), (-50, 92), (30, 104), (50, 106), (-34, 108), (-50, 120), (-8, 128), (26, 134), (50, 138), (-18, 148), (-50, 148)],
    ),
    "inn": dict(
        blocks={
            "inn": (-22, 72, 24, 20, 24),
            "sign": (1, 52, 1, 1, 9),
            "table_1": (-30, 44, 3, 3, 3),
            "table_2": (-14, 42, 3, 3, 3),
            "table_3": (-22, 32, 3, 3, 3),
            "stable": (32, 118, 16, 22, 12),
            "tree_1": (-50, 120, 2, 2, 13),
            "tree_2": (52, 40, 2, 2, 14),
            "tree_3": (-48, 150, 2, 2, 12),
            "tree_4": (50, 152, 2, 2, 13),
        },
        lamps=[(1.5, 30), (14.5, 64), (1.5, 100), (14.5, 136)],
        big=[(-2, 22), (-42, 40), (24, 58), (-44, 78), (-14, 96), (16, 114), (-24, 132), (24, 150)],
        small=[(50, 18), (-28, 18), (-50, 18), (24, 30), (-18, 36), (6, 44), (50, 46), (-12, 56), (-32, 58), (44, 68), (-6, 76), (12, 84),
               (50, 90), (-38, 96), (30, 98), (46, 108), (-50, 112), (-28, 112), (-6, 118), (50, 126), (10, 132), (-50, 144), (-2, 146), (46, 148)],
    ),
    "mill": dict(
        blocks={
            "stream": (-42, 129, 10, 62, 3),
            "pool": (-34.5, 91, 25, 14, 3),
            "pond": (-42, 38, 18, 18, 3),
            "mill": (-28, 110, 18, 18, 22),
            "cottage": (28, 48, 13, 11, 15),
            "store": (32, 128, 16, 16, 12),
            "cart": (16, 96, 4, 7, 3),
            "tree_1": (54, 90, 2, 2, 14),
            "tree_2": (-54, 20, 2, 2, 12),
            "tree_3": (52, 152, 2, 2, 13),
            "tree_4": (-54, 76, 2, 2, 13),
        },
        lamps=[(-4.5, 30), (8.5, 64), (-4.5, 100), (8.5, 136)],
        big=[(-16, 22), (14, 40), (-14, 58), (22, 78), (-10, 96), (22, 114), (-20, 132), (8, 150)],
        small=[(50, 18), (24, 18), (4, 20), (-50, 24), (40, 36), (-26, 40), (-6, 40), (-44, 52), (50, 54), (28, 58), (6, 58), (44, 74),
               (0, 76), (-26, 78), (-50, 80), (10, 94), (50, 96), (30, 96), (-2, 118), (46, 120), (12, 130), (28, 140), (50, 146), (-32, 148)],
    ),
    "lighthouse": dict(
        blocks={
            "lighthouse": (30, 120, 14, 14, 44),
            "cottage": (-28, 56, 13, 11, 15),
            "netshed": (-32, 122, 12, 16, 11),
            "nets": (-14, 130, 9, 1.5, 4.2),
            "rock_1": (48, 150, 8, 5, 4),
            "rock_2": (-50, 154, 7, 5, 3.5),
            "rock_3": (14, 156, 6, 4, 3),
            "boat": (-6, 148, 3.6, 7, 2),
            "sea": (0, 157, 120, 6, 3),
            "fence_1": (-32.4, 47, 5.2, 0.5, 1.2),
            "fence_2": (-23.6, 47, 5.2, 0.5, 1.2),
            "tree_1": (-50, 24, 2, 2, 12),
            "tree_2": (52, 34, 2, 2, 13),
        },
        lamps=[(-10.5, 30), (2.5, 64), (-10.5, 100), (2.5, 128)],
        big=[(12, 22), (-18, 40), (14, 58), (-22, 78), (12, 96), (-14, 114), (14, 132), (-24, 150)],
        small=[(-50, 18), (38, 18), (-26, 18), (-8, 24), (-40, 36), (28, 38), (50, 40), (2, 40), (-50, 56), (38, 60), (-8, 60), (24, 78),
               (2, 78), (50, 80), (-48, 80), (-10, 94), (36, 98), (-30, 98), (-50, 104), (6, 114), (50, 118), (-50, 134), (-8, 136), (40, 148)],
    ),
    "boathouse": dict(
        blocks={
            "water": (-42, 115, 36, 90, 3),
            "boathouse": (-26, 96, 24, 16, 15),
            "cottage": (26, 52, 13, 11, 15),
            "nets": (34, 112, 10, 1.5, 4.2),
            "boat": (-2, 140, 3.6, 7, 2),
            "tree_1": (52, 24, 2, 2, 13),
            "tree_2": (-52, 30, 2, 2, 12),
            "tree_3": (54, 150, 2, 2, 14),
        },
        lamps=[(3.5, 30), (16.5, 64), (3.5, 100), (16.5, 136), (-54, 80)],
        big=[(-10, 22), (20, 40), (-14, 58), (36, 78), (-8, 96), (8, 114), (30, 132), (-4, 150)],
        small=[(50, 18), (-34, 18), (14, 18), (32, 24), (-50, 36), (-28, 40), (0, 42), (50, 50), (4, 58), (24, 62), (-44, 66), (50, 68),
               (8, 74), (-20, 78), (50, 88), (22, 96), (50, 106), (26, 114), (-20, 124), (50, 126), (10, 134), (-20, 142), (50, 146), (22, 148)],
    ),
}


def P(x, d, z=0.0):
    """Stop frame point (x across, depth d) in Blender coordinates."""
    return Vector((-x, d - D / 2, z))


def hide(ob, *dirs, w=0.02):
    """Faces turned along any of `dirs` are hidden (under the ground, inside a wall): almost no
    texture for them (the HD unwrap's texel weight)."""
    attr = ob.data.attributes.get("texel") or ob.data.attributes.new("texel", "FLOAT", "FACE")
    for poly in ob.data.polygons:
        if any(poly.normal.dot(Vector(v)) > 0.9 for v in dirs):
            attr.data[poly.index].value = w
    return ob


def _gap(x, d, block):
    bx, bd, w, dd, _ = block
    return math.hypot(max(abs(x - bx) - w / 2, 0), max(abs(d - bd) - dd / 2, 0))


def check(name, keep=()):
    """The layout contract: 8 big sites at the GDD depths, 24 small ones between 15 and 150, all
    on the plate and off the platform, apart from each other, clear of every block and of the
    decor footprints in `keep` [(x, d, r)]."""
    lay = LAYOUT[name]
    big, small = lay["big"], lay["small"]
    assert tuple(d for _, d in big) == BIG_DEPTHS, f"{name}: big site depths"
    assert len(small) == 24 and all(15 <= d <= 150 for _, d in small), f"{name}: small sites"
    sites = [(x, d, BIG_R) for x, d in big] + [(x, d, SMALL_R) for x, d in small]
    for i, (x, d, r) in enumerate(sites):
        assert abs(x) <= W / 2 - r and RAMP <= d <= D - r, f"{name}: site ({x}, {d}) off the plate"
        for key, block in lay["blocks"].items():
            assert _gap(x, d, block) >= r, f"{name}: site ({x}, {d}) blocked by {key}"
        for lx, ld in lay["lamps"]:
            assert math.hypot(x - lx, d - ld) >= r + 0.5, f"{name}: site ({x}, {d}) on a lamp"
        for kx, kd, kr in keep:
            assert math.hypot(x - kx, d - kd) >= r + kr, f"{name}: site ({x}, {d}) under decor at ({kx}, {kd})"
        for x2, d2, r2 in sites[i + 1 :]:
            assert math.hypot(x - x2, d - d2) >= r + r2 - 1, f"{name}: sites ({x}, {d}) and ({x2}, {d2}) overlap"
    for key, (bx, bd, w, dd, _) in lay["blocks"].items():
        assert abs(bx) + w / 2 <= W / 2 and bd - dd / 2 >= RAMP and bd + dd / 2 <= D, f"{name}: block {key} off the plate"


def mats():
    """The tile palette (art bible sections 2 and 5); materials are cached by name per build."""
    return {
        "grass": k.paint("t_grass", [(0, (64, 98, 92)), (1, (70, 104, 96))], 0, 1, grain=(0.08, 0.1),
                         splat=[((80, 114, 100), 0.05, 0.6, -1, 1), ((58, 90, 90), 0.09, 0.64, -1, 1)]),
        "path": k.paint("t_path", [(0, (100, 82, 90)), (1, (108, 88, 96))], 0, 1, grain=(0.1, 1.2)),
        "cobble": k.mat("t_cobble", (108, 90, 98), kind="cells", scale=0.9, var=0.14),
        "brick": k.brick("t_brick", lo=GROUND, hi=PLATFORM),
        "chimney": k.brick("t_chimney", lo=8, hi=18),
        "stone": k.paint("sc_stone", [(0, (196, 186, 176)), (1, (226, 218, 206))], 2.0, 2.8, grain=(0.08, 2.0)),
        "rock": k.paint("t_rock", [(0, (104, 100, 120)), (1, (150, 144, 160))], 0, 3, grain=(0.12, 1.5)),
        "boards": k.paint("sc_boards", [(0, (150, 106, 78)), (1, (150, 106, 78))], -1, 1, axis="Y", bands=((128, 88, 64), 0.85), grain=(0.1, 4, "wave")),
        "planks": k.paint("t_planks", [(0, (132, 92, 70)), (1, (150, 106, 80))], 0, 12, axis="Z", bands=((118, 80, 60), 0.9), grain=(0.1, 4, "wave")),
        "timber": k.mat("sc_timber", k.TIMBER, kind="wood", scale=3, var=0.1),
        "iron": k.flat(k.IRON),
        "brass": k.brass("t_brass", 0, 12),
        "glow": k.flat(k.WINDOW_GLOW),
        "cream": k.flat(k.CREAM),
        "bark": k.mat("t_bark", (96, 68, 64), kind="wood", scale=2, var=0.12),
        "leaf": k.paint("t_leaf", [(0, (44, 82, 82)), (0.55, (58, 106, 94)), (1, (92, 138, 108))], 4, 15, grain=(0.12, 0.9)),
        "bush": k.paint("t_bush", [(0, (44, 80, 80)), (1, (78, 122, 100))], 0, 3, grain=(0.12, 1.2)),
        "bloom": k.paint("t_bloom", [(0, (48, 86, 82)), (1, (80, 124, 102))], 0, 2.5, grain=(0.1, 1.5),
                         dots=[((255, 150, 190), 2.2, 0.12), ((255, 214, 110), 2.7, 0.1), ((200, 170, 255), 3.1, 0.1)]),
        "flowers": [k.flat((255, 150, 190)), k.flat((255, 214, 110)), k.flat((200, 170, 255))],
        "water": k.paint("t_water", [(0, (52, 92, 120)), (1, (62, 110, 132))], 0, 1, grain=(0.12, 0.4, "wave")),
        "picket": k.paint("t_picket", [(0, (214, 200, 186)), (1, (250, 236, 214))], 0, 1.4, grain=(0.04, 3.0)),
        "toadstool": k.paint("t_toadstool", [(0, (110, 58, 100)), (1, k.ROOF_PLUM_HI)], 0.5, 2.0, dots=[(k.CREAM, 3.2, 0.14)]),
        "door": k.paint("t_door", [(0, (40, 98, 110)), (1, (72, 138, 146))], 1, 7, grain=(0.12, 5, "wave")),
        "soil": k.paint("t_soil", [(0, (78, 60, 70)), (1, (96, 74, 82))], 0, 0.6, grain=(0.14, 2.0)),
        "pumpkin": k.paint("t_pumpkin", [(0, (170, 92, 58)), (1, (214, 132, 72))], 0, 1.4, grain=(0.08, 6, "wave")),
        "cabbage": k.paint("t_cabbage", [(0, (70, 116, 104)), (1, (120, 168, 136))], 0, 1.2, grain=(0.1, 4.0)),
        "hay": k.paint("t_hay", [(0, (150, 124, 96)), (1, (206, 180, 132))], 0, 4, grain=(0.12, 5, "wave")),
        "sack": k.paint("t_sack", [(0, (170, 152, 136)), (1, (214, 198, 176))], 0, 2, grain=(0.08, 6.0)),
        "reed": k.paint("t_reed", [(0, (70, 96, 84)), (1, (128, 150, 112))], 0, 3, grain=(0.1, 3.0)),
        "boat": k.paint("t_boat", [(0, (40, 84, 98)), (0.7, (62, 124, 136)), (1, k.CREAM)], 0.2, 1.7),
        "china": k.paint("t_china", [(0, (52, 112, 124)), (1, (88, 160, 168))], 0, 9, grain=(0.03, 4.0)),
        "sand": k.paint("t_sand", [(0, (140, 126, 134)), (1, (162, 146, 148))], 0, 0.4, grain=(0.08, 1.4)),
        "skep": k.paint("t_skep", [(0, (176, 146, 104)), (1, (214, 186, 132))], 0, 3, bands=((150, 120, 86), 0.24)),
        "net": k.paint("t_net", [(0, (60, 96, 104)), (1, (84, 124, 128))], 0, 5, dots=[((40, 64, 76), 6.0, 0.18)]),
        "fruit": [k.flat((236, 168, 96)), k.flat((222, 128, 136))],
        "apple": k.paint("t_apple", [(0, (44, 82, 82)), (0.55, (58, 106, 94)), (1, (92, 138, 108))], 4, 15, grain=(0.12, 0.9),
                         dots=[((246, 178, 96), 0.42, 0.17), ((232, 132, 140), 0.5, 0.15)]),
    }


class Tile:
    """A stop tile under construction: body and glow objects, built in place on the plate."""

    def __init__(self, name):
        check(name)
        self.name, self.lay, self.m = name, LAYOUT[name], mats()
        self.body, self.lit, self.keep, self.parts = [], [], [], {}
        ground(self)
        platform(self)
        for x, d in self.lay["lamps"]:
            lamp(self, x, d)

    def block(self, key):
        return self.lay["blocks"][key]

    def put(self, body, lit=(), x=0.0, d=0.0, yaw=0.0, keep=0.0, part="glow"):
        """Moves pieces built round the local origin (front -Y, the track) to (x, d), turned yaw
        degrees; lit pieces join the glow mesh `part`; keep: radius that sites must stay clear of
        (low decor)."""
        m = Matrix.Translation(P(x, d)) @ k.rot_z(yaw)
        for ob in [*body, *lit]:
            ob.data.transform(m)
        self.body += list(body)
        (self.lit if part == "glow" else self.parts.setdefault(part, [])).extend(lit)
        if keep:
            self.keep.append((x, d, keep))

    def done(self):
        """Checks the layout against the decor, flattens whatever sinks below the plate's bottom
        (sunken bushes and rocks: hidden in the plate) so the ground stays at GROUND, and keeps
        everything on the 120 x 160 footprint."""
        check(self.name, self.keep)
        coarse_bricks()
        groups = {"": self.body, "glow": self.lit, **self.parts}
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        for ob in (o for g in groups.values() for o in g):
            if ob.modifiers:  # apply them first: a displaced rock can still dip below the plate
                old, ob.data = ob.data, bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
                ob.modifiers.clear()
                bpy.data.meshes.remove(old)
            for v in ob.data.vertices:
                v.co.z = max(v.co.z, 0.0)
                assert abs(v.co.x) <= W / 2 + 1e-3 and abs(v.co.y) <= D / 2 + 1e-3, f"{self.name}: {ob.name} off the plate at {tuple(v.co)}"
        return groups


def coarse_bricks():
    """Bricks 1.4 x 0.7 with wider mortar on a tile: at its texel density the kit's 1 x 0.5 bond
    aliases into dots."""
    for m in bpy.data.materials:
        for node in m.node_tree.nodes if m.node_tree else ():
            if node.type == "TEX_BRICK" and node.inputs["Mortar Size"].default_value < 0.1:
                node.inputs["Brick Width"].default_value *= 1.4
                node.inputs["Row Height"].default_value *= 1.4
                node.inputs["Mortar Size"].default_value = 0.1
                brick, mortar = node.inputs["Color1"].default_value, node.inputs["Mortar"].default_value
                node.inputs["Mortar"].default_value = [b + (c - b) * 0.55 for b, c in zip(brick, mortar)]  # softer: less shimmer when baked


def ground(t):
    plate = k.box((W, D, GROUND), (0, 0, GROUND / 2), m=t.m["grass"], name="ground")
    hide(k.texel(plate, 0.35), (0, 0, -1))
    t.body.append(plate)


def platform(t):
    """The platform along the whole track edge: brick face, stone coping with a cream edge line,
    a plank deck, a gravel ramp down the back; a sign, two lamp posts, two benches."""
    m, y0 = t.m, -D / 2
    face = k.box((2 * PLAT_X, DECK, PLATFORM - GROUND), (0, y0 + DECK / 2, (PLATFORM + GROUND) / 2), m=m["brick"], name="platform")
    deck = k.box((2 * PLAT_X + 0.3, DECK - 0.85, 0.3), (0, y0 + 0.85 + (DECK - 0.85) / 2, PLATFORM - 0.15), m=m["boards"], bevel=0.05, name="deck")
    ramp = k.hull([(sx * PLAT_X, y, z) for sx in (-1, 1) for y, z in ((y0 + DECK - 0.2, PLATFORM - 0.02), (y0 + RAMP, GROUND - 0.02), (y0 + DECK - 0.2, GROUND - 0.02))], m["path"], name="ramp")
    k.texel(face, 2.2)  # the brick face is what a seated player sees closest
    t.body += [hide(face, (0, 0, 1), (0, 0, -1), (0, 1, 0)), hide(deck, (0, 0, -1)), hide(k.texel(ramp, 0.5), (0, 0, -1), (0, -1, 0))]
    t.body.append(k.box((2 * PLAT_X + 0.6, 0.9, 0.36), (0, y0 + 0.45, PLATFORM - 0.1), m=m["stone"], bevel=0.08, seg=2, name="coping"))
    t.body.append(k.box((2 * PLAT_X + 0.2, 0.32, 0.04), (0, y0 + 0.55, PLATFORM + 0.09), m=m["cream"], name="edge_line"))
    b, g = sign(*P(42, 8.4)[:2], m["iron"], m["brass"], m["glow"])
    k.texel([ob for ob in b if ob.name.startswith("roundel")], 4)
    t.body += b
    t.lit += g
    for x in (-30, 22):
        b, g = post_lamp(*P(x, 8.6)[:2], m["iron"], m["brass"], m["glow"])
        t.body += b
        t.lit += g
    for x in (-12, 12):
        t.body += bench(*P(x, 8.2)[:2], m["timber"], m["iron"])


def lamp(t, x, d, h=6.0):
    """A street lamp along the paths: the lights that lead back to the train in the fog."""
    m = t.m
    body = [
        k.lathe([(0.42, 0), (0.42, 0.3), (0.2, 0.55), (0.15, 0.7)], loc=(0, 0, GROUND), m=m["iron"], n=8, name="lamp_foot"),
        k.cyl(0.13, h, (0, 0, GROUND + h / 2 + 0.3), m=m["iron"], n=8, name="lamp_post"),
        k.lathe([(0.24, h + 0.4), (0.44, h + 0.55), (0.44, h + 0.62)], m=m["brass"], n=6, name="lamp_cup"),
        k.lathe([(0.66, h + 1.5), (0.6, h + 1.6), (0.24, h + 1.95), (0, h + 2.05)], m=m["iron"], n=6, name="lamp_roof"),
        k.ico(0.1, (0, 0, h + 2.12), m=m["brass"], subdiv=1, name="lamp_finial"),
    ]
    lit = [k.lathe([(0.36, h + 0.6), (0.48, h + 1.2), (0.48, h + 1.52)], m=m["glow"], n=6, name="lamp_glass")]
    t.put(body, lit, x, d)


def path(t, points, width, m=None, z=0.05):
    """A flat path strip along stop-frame points [(x, d), ...]."""
    pts = [P(x, d) for x, d in points]
    left, right = [], []
    for i, p in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        tangent = (b - a).normalized()
        n = Vector((-tangent.y, tangent.x, 0)) * (width / 2)
        left.append(p + n)
        right.append(p - n)
    outline = [(v.x, v.y) for v in left + right[::-1]]
    ob = k.plate([outline], z, loc=(0, 0, GROUND + z / 2), m=m or t.m["path"], name="path")
    t.body.append(hide(k.texel(ob, 0.5), (0, 0, -1)))
    return ob


def ring_path(t, x, d, r_in, r_out, m=None, n=32):
    c = P(x, d)
    loops = [[(c.x + r * math.cos(2 * math.pi * i / n), c.y + r * math.sin(2 * math.pi * i / n)) for i in range(n)] for r in (r_out, r_in)]
    ob = k.plate(loops, 0.05, loc=(0, 0, GROUND + 0.025), m=m or t.m["path"], name="ring_path")
    t.body.append(hide(k.texel(ob, 0.5), (0, 0, -1)))


def tree(t, key, s=1.0, leaf=None, seed=0, spread=0.27):
    """A round dusk tree: a stout trunk under a cloud of four puffs, the canopy above head height
    (spread: the main puff's radius as a share of the height)."""
    x, d, _, _, h = t.block(key)
    rng = [math.sin(seed * 12.9898 + i * 78.233) for i in range(8)]
    r = spread * h
    body = [k.lathe([(0.8 * s, 0), (0.55 * s, 0.7), (0.45 * s, h * 0.45), (0.3 * s, h * 0.7)], m=t.m["bark"], n=8, name="trunk")]
    for (dx, dy, dz, rr) in ((0, 0, h - r * 0.95, r), (0.55 * r, 0.25 * r, h - 1.45 * r, 0.72 * r), (-0.5 * r, -0.3 * r, h - 1.4 * r, 0.74 * r), (0.1 * r, -0.55 * r, h - 1.2 * r, 0.62 * r)):
        body.append(k.puff(rr, (dx + rng[0] * 0.3, dy + rng[1] * 0.3, dz), leaf or t.m["leaf"], scale=(1, 1, 0.86), name="canopy"))
    hide(body[0], (0, 0, -1))
    t.put(body, (), x, d, yaw=rng[2] * 180)


def bush(t, x, d, r=1.6, m=None):
    t.put([k.puff(r, (0, 0, GROUND + r * 0.45), m or t.m["bush"], scale=(1.15, 1, 0.75), name="bush")], (), x, d, keep=r * 1.15)


def barrel(t, x, d, s=1.0, yaw=0.0):
    m = t.m
    body = [k.lathe([(0.5 * s, 0), (0.6 * s, 0.65 * s), (0.5 * s, 1.3 * s)], loc=(0, 0, GROUND), m=m["planks"], n=10, name="barrel")]
    for z in (0.22, 1.08):
        body.append(k.lathe([(0.56 * s, z * s), (0.58 * s, (z + 0.08) * s)], loc=(0, 0, GROUND), m=m["iron"], n=10, name="hoop"))
    hide(body[0], (0, 0, -1))
    t.put(body, (), x, d, yaw, keep=0.7 * s)


def festoon(t, a, b, n=5, sag=0.9):
    """A string of round paper lanterns between two stop-frame points (x, d, z)."""
    pa, pb = P(a[0], a[1], a[2]), P(b[0], b[1], b[2])
    t.body.append(k.rope(pa, pb, sag, 0.04, t.m["iron"], n=3, steps=10, name="festoon"))
    for i in range(1, n + 1):
        s = i / (n + 1)
        p = pa.lerp(pb, s) - Vector((0, 0, 4 * sag * s * (1 - s) + 0.35))
        t.lit.append(k.ico(0.3, p, m=t.m["glow"], subdiv=1, scale=(1, 1, 1.25), name="paper_lantern"))


def fence(t, points, h=1.2):
    """Cream picket fence along stop-frame points: one flat comb of round-topped pickets a run."""
    for (x0, d0), (x1, d1) in zip(points, points[1:]):
        a, b = P(x0, d0), P(x1, d1)
        length = (b - a).length
        n = max(2, int(length / 0.75))
        step = length / n
        outline = [(0, 0)]
        for i in range(n):
            x = i * step + 0.1
            outline += [(x, 0.3), (x, h - 0.15), (x + 0.12, h), (x + step - 0.32, h), (x + step - 0.2, h - 0.15), (x + step - 0.2, 0.3)]
        outline += [(length, 0.3), (length, 0)]
        to = Matrix.Translation(a + Vector((0, 0, GROUND))) @ Matrix.Rotation(math.atan2(b.y - a.y, b.x - a.x), 4, "Z")
        for ob in (k.poly(outline, 0.12, m=t.m["picket"], name="fence"), k.box((length, 0.1, 0.16), (length / 2, 0.1, 0.55), m=t.m["timber"], name="fence_rail")):
            ob.data.transform(to)
            t.body.append(ob)
        t.keep += [(x0 + (x1 - x0) * s / 4, d0 + (d1 - d0) * s / 4, 0.5) for s in range(5)]


def toadstools(t, x, d, spots=((0, 0, 1.0), (1.1, 0.5, 0.7), (-0.6, 0.9, 0.55))):
    """A clump of toy toadstools: plum caps with cream spots."""
    body = []
    for dx, dy, s in spots:
        for ob in k.mushroom(0.9 * s, 1.3 * s, t.m["toadstool"], t.m["cream"]):
            ob.data.transform(Matrix.Translation((dx, dy, GROUND - 0.05)))
            body.append(ob)
    t.put(body, (), x, d, keep=1.6)


def signpost(t, x, d, yaw=0.0):
    m = t.m
    body = [k.box((0.3, 0.3, 3.6), (0, 0, GROUND + 1.8), m=m["timber"], name="signpost"),
            k.ico(0.22, (0, 0, GROUND + 3.7), m=m["brass"], subdiv=1, name="signpost_cap")]
    for z, a, dx in ((3.0, 15, 0.9), (2.4, -20, -0.8)):
        body.append(k.poly([(-1.0, -0.22), (0.9, -0.22), (1.2, 0), (0.9, 0.22), (-1.0, 0.22)], 0.1, loc=(dx, 0, GROUND + z), rot=(0, 0, a), m=m["cream"], name="signboard"))
    t.put(body, (), x, d, yaw, keep=0.8)


def cottage(t, key, yaw=0.0, tongues=(16, 12), side=130, chimney=True, storeys=1, n=24):
    """A plain neighbour of the hero house (about 2,300 tris): plinth, cream drum, a two-ring
    scalloped plum roof, two lit front windows with flower boxes and one more at `side` degrees
    round from the front (towards the lane and the far end), a door. storeys=2 (the inn, the mill
    house): two rows of windows either side of a floor band, a third roof ring, a door hood."""
    x, d, w, dd, h = t.block(key)
    if yaw:
        s = min(w, dd) / 2 - 0.35
        r = (s, 0.87 * s)
    else:
        r = (w / 2 - 0.35, dd / 2 - 0.35)
    m = t.m
    zp, ze, rh = 1.1, round(0.5 * h, 2), 0.42 * h
    eave = (r[0] + 2.0, r[1] + 1.9) if storeys == 1 else (r[0] + 2.6, r[1] + 2.4)
    c = P(x, d)
    plaster = k.paint(f"t_plaster_{ze}", [(0, (226, 204, 178)), (0.35, k.CREAM), (1, (255, 246, 228))], zp, ze, grain=(0.05, 3.0))
    plinth = k.brick(f"t_plinth_{key}", lo=0, hi=zp + 0.8, around=(c.x, c.y, r[0]))
    roof = k.paint(f"t_roof_{ze}", [(0, (96, 50, 90)), (0.6, k.ROOF_PLUM), (1, k.ROOF_PLUM_HI)], ze - 0.4, ze + rh, grain=(0.06, 1.5))
    door_m = m["door"]
    body, lit = [], []
    walls = k.lathe([(1.0, zp - 0.1), (1.012, (zp + ze) / 2), (1.0, ze + 0.4)], m=plaster, n=n, scale=(r[0], r[1], 1), name="walls")
    zf = zp + (ze - zp) * 0.52  # floor band of a two-storey house
    bands = [(ze - 0.55, ze + 0.1)] + ([(zf - 0.3, zf + 0.3)] if storeys == 2 else [])
    for ob in [k.lathe([(1.0, 0), (1.0, zp)], m=plinth, n=n, scale=(r[0] + 0.35, r[1] + 0.35, 1), name="plinth"), walls] + [
            k.lathe([(1.02, z0), (1.025, z1)], m=m["timber"], n=n, scale=(r[0], r[1], 1), name="beam") for z0, z1 in bands]:
        body.append(hide(ob, (0, 0, 1), (0, 0, -1)))
    rings = ((0.0, 0.46, tongues[0]), (0.38, 0.8, tongues[1])) if storeys == 1 else ((0.0, 0.36, tongues[0]), (0.3, 0.62, tongues[1]), (0.56, 0.84, tongues[2]))
    for i, (t0, t1, tg) in enumerate(rings):
        body.append(roof_tier(t0, t1, tg, roof, f"tier{i}", c=(0, 0), eave=eave, z=ze, h=rh, per=3))
    crown = k.lathe([(dome(tt), ze + tt * rh) for tt in (0.74, 0.86, 0.95)] + [(0, ze + rh + 0.05)], m=roof, n=18, scale=(eave[0], eave[1], 1), name="crown")
    body.append(hide(crown, (0, 0, -1)))
    body.append(k.ico(0.28, (0, 0, ze + rh + 0.3), m=m["brass"], subdiv=2, name="finial"))
    if chimney:
        hx, hy = r[0] * 0.5, r[1] * 0.4
        body.append(k.box((1.2, 1.2, rh * 0.5 + 0.4), (hx, hy, ze + rh * 0.75 + 0.2), m=m["chimney"], name="chimney"))
        body.append(k.box((1.55, 1.55, 0.3), (hx, hy, ze + rh + 0.55), m=m["stone"], bevel=0.05, name="chimney_cap"))
    wr = 0.8 if r[0] < 6 else 0.9
    if storeys == 1:
        zw = (zp + ze) / 2 + 0.3
        spots = [(-44, zw, m["flowers"]), (44, zw, m["flowers"][::-1])] + ([(side, zw, None)] if side else [])
    else:
        lo, hi = (zp + zf) / 2 + 0.2, (zf + ze) / 2
        spots = [(-50, lo, m["flowers"]), (-26, lo, m["flowers"]), (26, lo, m["flowers"][::-1]), (50, lo, m["flowers"][::-1]),
                 (-36, hi, None), (0, hi, None), (36, hi, None)] + ([(side, lo, None), (side, hi, None)] if side else [])
    for theta, z, fl in spots:
        parts, panes = round_window(walls, theta, z, wr, m["timber"], m["glow"], fl, c=(0, 0), seg=12, sides=4, pane_n=12)
        body += parts
        lit += panes
    dw, dh = (2.6, 4.4) if storeys == 1 else (3.2, 5.0)
    p, _ = k.land(walls, (0, 0, zp + 2), (0, -1, 0))
    yd = p.y - 0.05
    arch = arch_outline(dw, dh)
    if storeys == 2:  # a little scalloped hood over the door
        hood = k.surface(12, 2, lambda u, v: (2.4 * math.cos(math.pi * u), yd + 0.5 - 2.2 * v, zp + dh + 0.4 + 1.2 * math.sin(math.pi * u) - 0.5 * v), m=roof, thickness=0.2, name="hood")
        body.append(hood)
        body += [k.box((0.2, 0.2, 1.6), (sx * 2.2, yd - 1.1, zp + dh - 0.3), rot=(-35, 0, 0), m=m["timber"], name="hood_strut") for sx in (-1, 1)]
    body.append(k.poly(arch, 0.4, loc=(0, yd, zp), m=door_m, name="door"))
    body.append(k.tube([Vector((x_ * 1.12, yd - 0.1, zp + z_ * 1.03)) for x_, z_ in arch], 0.2, m=m["timber"], n=4, name="door_frame"))
    body.append(k.ico(0.13, (0.75, yd - 0.25, zp + 2.0), m=m["brass"], subdiv=1, name="knob"))
    body.append(k.box((3.4, 1.1, zp), (0, yd - 0.45, zp / 2), m=m["stone"], bevel=0.05, name="step"))
    t.put(body, lit, x, d, yaw)


def well(t, key):
    """The village well: a stone drum, two timber posts under a little scalloped roof, a windlass
    with a bucket, and a lantern hanging under the roof."""
    x, d, w, _, _ = t.block(key)
    m = t.m
    r = w / 2 - 0.6
    stone = k.paint("t_wellstone", [(0, (150, 140, 150)), (1, (200, 192, 196))], 0, 1.4, grain=(0.12, 2.0))
    body = [k.lathe([(r, 0), (r, 1.3), (r + 0.12, 1.45), (r - 0.55, 1.45), (r - 0.55, 1.0)], m=stone, n=16, name="well_ring"),
            k.cyl(r - 0.55, 0.04, (0, 0, 1.02), m=m["water"], n=16, name="well_water")]
    for sx in (-1, 1):
        body.append(k.box((0.32, 0.32, 3.6), (sx * (r - 0.3), 0, 1.45 + 1.8), m=m["timber"], name="well_post"))
    body.append(k.cyl(0.18, 2 * r - 0.2, (0, 0, 3.6), rot=(0, 90, 0), m=m["timber"], n=8, name="windlass"))
    body.append(k.tube([(0.3, 0, 3.5), (0.3, 0, 2.4)], 0.03, m=m["iron"], n=4, name="rope"))
    body.append(k.lathe([(0.26, 1.9), (0.32, 2.4)], m=m["planks"], n=8, name="bucket"))
    roof = k.paint("t_wellroof", [(0, (96, 50, 90)), (0.6, k.ROOF_PLUM), (1, k.ROOF_PLUM_HI)], 4.6, 6.8, grain=(0.06, 1.5))
    body.append(roof_tier(0.0, 0.7, 10, roof, "well_roof", c=(0, 0), eave=(r + 0.9, r + 0.9), z=4.9, h=1.9, per=3))
    body.append(k.lathe([(dome(tt) * (r + 0.9), 4.9 + tt * 1.9) for tt in (0.6, 0.85)] + [(0, 6.85)], m=roof, n=12, name="well_cap"))
    body.append(k.ico(0.2, (0, 0, 7.0), m=m["brass"], subdiv=1, name="well_finial"))
    lit = [k.box((0.4, 0.4, 0.5), (0, 0, 4.45), m=m["glow"], name="well_lamp")]
    body.append(k.lathe([(0.32, 4.72), (0.12, 4.9)], m=m["iron"], n=6, name="well_lamp_hood"))
    t.put(body, lit, x, d)


def stop_village():
    """The hero house_cottage with three plainer neighbours round a straight cobbled lane that
    opens into a ring round the well; lamps lead back to the platform."""
    t = Tile("village")
    m = t.m
    path(t, [(0, RAMP - 0.5), (0, 80.0)], 9, m["cobble"])
    ring_path(t, 0, 92, 4.2, 12.2, m["cobble"])
    path(t, [(0, 103.5), (0, D)], 9, m["cobble"])
    c = P(*t.block("cottage")[:2])
    house = house_cottage(station=False, at=(c.x, c.y - CY))
    t.body += house[""]
    t.lit += house["glow"]
    path(t, [(22, 37.5), (22, 33), (4.5, 33)], 3.4, m["path"])  # the hero's front walk
    fence(t, [(14.5, 36), (19.8, 36)])
    fence(t, [(24.2, 36), (29.6, 36), (29.6, 39.6)])
    cottage(t, "house_w", side=-130)  # stop x < 0 is Blender +x: the lane is round to -130
    cottage(t, "house_nw", yaw=-24, side=-130)
    cottage(t, "house_ne", tongues=(15, 11), side=130)
    # Paper lanterns strung lamp to lamp over the lane, by way of the well: the way home lit up.
    festoon(t, (6.5, 30, 7.4), (-6.5, 62, 7.4), n=6, sag=1.0)
    festoon(t, (-6.5, 62, 7.4), (0, 92, 6.6), n=5, sag=0.8)
    festoon(t, (0, 92, 6.6), (6.5, 118, 7.4), n=5, sag=0.8)
    toadstools(t, -43, 80)
    toadstools(t, 44, 128, ((0, 0, 0.9), (-1.0, 0.6, 0.6)))
    signpost(t, -10, 100, yaw=30)
    path(t, [(-24, 32), (-14, 30), (-4.5, 30)], 3.0, m["path"])
    path(t, [(28, 124.5), (14, 120), (4.5, 120)], 3.0, m["path"])
    well(t, "well")
    for key, s in (("tree_1", 1.0), ("tree_2", 1.1), ("tree_3", 0.95), ("tree_4", 1.0), ("tree_5", 0.9)):
        tree(t, key, s, seed=len(key) + int(s * 10) + t.block(key)[0])
    for x, d, r in ((12.5, 50, 1.4), (31.5, 50, 1.4), (-31, 40, 1.3), (-17, 41, 1.2), (21, 128, 1.3), (35, 136, 1.2), (-20, 118, 1.3)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((-55, 64), (-54, 92), (55, 66), (55, 104), (-56, 128), (-30, 156), (34, 158)):
        bush(t, x, d, 1.9)
    for x, d, s in ((32, 42, 1.0), (33.2, 44, 0.9), (-16, 34, 0.9)):
        barrel(t, x, d, s)
    return t.done()


# The kit of the other tiles ----------------------------------------------------------------------


def roofing(name, lo, hi, bands=None):
    """Plum shingles, dark at the eaves to light at the crown (between object heights lo and hi)."""
    return k.paint(name, [(0, (96, 50, 90)), (0.6, k.ROOF_PLUM), (1, k.ROOF_PLUM_HI)], lo, hi, grain=(0.06, 1.5), bands=bands)


def arch_outline(w, h, n=8):
    """Round-topped door outline (x, z) from the sill."""
    return [(w / 2, 0), (w / 2, h - w / 2)] + [(w / 2 * math.cos(math.pi * i / n), h - w / 2 + w / 2 * math.sin(math.pi * i / n)) for i in range(1, n)] + [(-w / 2, h - w / 2), (-w / 2, 0)]


def window(m, p, n, w, h=None, sill=True):
    """A lit window on a flat face at p facing n: round (radius w) or w x h, a timber frame and
    cross. Returns (body, lit)."""
    if h is None:
        lit = [k.cyl(w * 0.95, 0.06, (0, 0, 0.03), m=m["glow"], n=14, name="pane")]
        body = [k.ring(w, 0.06, w * 0.16, m["timber"], n=12, sides=4, name="frame")]
        span = (2 * w, 2 * w)
    else:
        lit = [k.box((w, h, 0.06), (0, 0, 0.03), m=m["glow"], name="pane")]
        body = [k.box((w + 0.36, 0.2, 0.16), (0, sy * (h / 2 + 0.08), 0.08), m=m["timber"], name="frame") for sy in (-1, 1)]
        body += [k.box((0.2, h, 0.16), (sx * (w / 2 + 0.08), 0, 0.08), m=m["timber"], name="frame") for sx in (-1, 1)]
        if sill:
            body.append(k.box((w + 0.6, 0.18, 0.36), (0, -h / 2 - 0.2, 0.18), m=m["timber"], name="sill"))
        span = (w, h)
    body += [k.box((span[0], 0.1, 0.08), (0, 0, 0.08), m=m["timber"], name="mullion"), k.box((0.1, span[1], 0.08), (0, 0, 0.08), m=m["timber"], name="mullion")]
    f = frame_at(Vector(p), Vector(n))
    for ob in body + lit:
        ob.data.transform(f)
    return body, lit


def shed(t, key, yaw=0.0, walls=None, cupola=False, side=2, loft=True, rear=False, door=(0.42, 7.5), lift=0.0):
    """A barrel-roofed building (barn, stable, granary, apple store, boathouse): plank walls on a
    stone footing (or lifted on staddle stones), a plum shingle vault with scalloped eaves,
    round-topped double doors in the gable at the local front, a lit round loft window over them,
    lit windows down the sides, optionally a lit window in the rear gable and a lantern cupola."""
    x, d, w, dd, h = t.block(key)
    if abs(yaw) % 180 == 90:
        w, dd = dd, w
    m = t.m
    wm = walls or m["planks"]
    footing = 0.15 if lift else 0.8
    top = h - lift - (2.4 if cupola else 0.3)
    rise = 0.5 * top
    zb, R, L = top - rise, w / 2 + 0.8, dd + 1.6
    zt = zb + rise * math.sqrt(1 - (w / 2 / R) ** 2) + 0.1
    roof = roofing(f"t_vault_{zb:.1f}", zb, top, bands=((108, 58, 100), 0.9))
    body, lit = [], []
    if not lift:
        body.append(hide(k.box((w + 0.4, dd + 0.4, footing), (0, 0, footing / 2), m=m["stone"], bevel=0.06, name="footing"), (0, 0, -1)))
    body.append(hide(k.box((w, dd, zt - footing), (0, 0, (footing + zt) / 2), m=wm, name="shed_walls"), (0, 0, 1), (0, 0, -1)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(k.box((0.45, 0.45, zt - footing), (sx * w / 2, sy * dd / 2, (footing + zt) / 2), m=m["timber"], name="corner_post"))
    th0 = math.acos(w / 2 / R)
    for sy in (-1, 1):
        gable = [(w / 2, zt - 0.2)] + [(R * 0.99 * math.cos(a), zb + rise * 0.99 * math.sin(a)) for a in (th0 + (math.pi - 2 * th0) * i / 10 for i in range(11))] + [(-w / 2, zt - 0.2)]
        body.append(k.poly(gable, 0.3, loc=(0, sy * (dd / 2 - 0.1), 0), m=wm, name="gable"))
    body.append(k.surface(16, 1, lambda u, v: (R * math.cos(math.pi * u), -L / 2 + L * v, zb + rise * math.sin(math.pi * u)), m=roof, thickness=0.3, name="vault"))
    nt = max(6, round(L / 2.2))
    for s in (1, -1):
        def hem(u, v, s=s):
            a = 0.24 * v if s > 0 else math.pi - 0.24 * v
            drop = 0.3 * (1 - v) ** 3 * abs(math.sin(nt * math.pi * u)) ** 0.6
            return (R * 1.03 * math.cos(a), -L / 2 + L * u, zb + rise * 1.03 * math.sin(a) - drop)
        body.append(k.surface(nt * 3, 1, hem, m=roof, thickness=0.22, name="hem"))
    dw, dh = min(door[0] * w, 7.0), min(door[1], zt - footing - 0.6)
    yd = -dd / 2 - 0.12
    arch = arch_outline(dw, dh)
    body.append(k.poly(arch, 0.24, loc=(0, yd, footing), m=m["door"], name="big_door"))
    body.append(k.tube([Vector((px * 1.06, yd - 0.1, footing + pz * 1.02)) for px, pz in arch], 0.2, m=m["timber"], n=4, name="door_frame"))
    body.append(k.box((0.16, 0.1, dh - 0.3), (0, yd - 0.14, footing + (dh - 0.3) / 2), m=m["timber"], name="door_split"))
    brace = math.degrees(math.atan2(dh * 0.5, dw / 2 - 0.5))
    for sx in (-1, 1):
        body.append(k.box((math.hypot(dw / 2 - 0.5, dh * 0.5), 0.1, 0.22), (sx * dw / 4, yd - 0.14, footing + dh * 0.32), rot=(0, sx * brace, 0), m=m["timber"], name="brace"))
    zl = min(footing + dh + 1.6, top - 1.5)
    for sy, z in ((-1, zl if loft and zl - footing - dh > 0.9 else None), (1, (zt + top) / 2 if rear else None)):
        if z is not None:
            b, g = window(m, (0, sy * (dd / 2 + 0.16), z), (0, sy, 0), 0.95)
            body += b
            lit += g
    if rear:  # a plain door in the rear gable too
        back = [(-px, pz) for px, pz in arch_outline(2.4, 4.2)]
        body.append(k.poly(back, 0.3, loc=(0, dd / 2 + 0.1, footing), m=m["door"], name="rear_door"))
        body.append(k.tube([Vector((px * 1.1, dd / 2 + 0.2, footing + pz * 1.03)) for px, pz in back], 0.18, m=m["timber"], n=4, name="door_frame"))
    for sx in (-1, 1):
        for i in range(side):
            b, g = window(m, (sx * (w / 2 + 0.02), -dd / 2 + dd * (i + 0.5) / side, footing + (zt - footing) * 0.55), (sx, 0, 0), 1.2, 1.3)
            body += b
            lit += g
    if cupola:
        body.append(hide(k.lathe([(1.25, top - 0.6), (1.25, top + 1.3)], m=m["cream"], n=10, name="cupola"), (0, 0, -1)))
        for a in range(4):
            g = k.box((1.0, 0.06, 0.8), (0, -1.24, top + 0.55), m=m["glow"], name="cupola_pane")
            g.data.transform(k.rot_z(90 * a))
            lit.append(g)
        body.append(k.lathe([(1.7, top + 1.25), (1.25, top + 1.7), (0.5, top + 2.05), (0, top + 2.15)], m=roof, n=10, name="cupola_roof"))
        body.append(k.cyl(0.05, 0.9, (0, 0, top + 2.55), m=m["brass"], n=4, name="vane_rod"))
        body.append(k.hull([(-0.7, 0, top + 2.75), (0.5, -0.04, top + 2.6), (0.5, 0.04, top + 2.6), (0.5, 0, top + 2.95), (0.7, 0, top + 2.75)], m["brass"], name="vane"))
    if lift:
        for ob in body + lit:
            ob.data.transform(Matrix.Translation((0, 0, lift)))
        for sx in (-0.38, 0, 0.38):
            for sy in (-0.4, 0.4):
                body += k.mushroom(0.75, (lift + 0.15) / 1.38, m["stone"], m["stone"], name="staddle")  # cap top under the floor
                for ob in body[-2:]:
                    ob.data.transform(Matrix.Translation((sx * w, sy * dd, 0)))
        for i in range(3):
            body.append(k.box((dw, 1.0, (lift + footing) * (3 - i) / 3), (0, yd - 0.5 - i, (lift + footing) * (3 - i) / 6), m=m["planks"], name="steps"))
    t.put(body, lit, x, d, yaw)


def silo(t, key):
    """A grey-lilac stave silo with iron hoops, a ladder and a lit hatch under a scalloped dome."""
    x, d, w, _, h = t.block(key)
    m = t.m
    r, ze = w / 2 - 0.7, h - 3.8
    staves = k.paint("t_staves", [(0, (118, 112, 132)), (1, (164, 156, 176))], 0, ze, grain=(0.1, 3, "wave"))
    body = [hide(k.lathe([(r + 0.35, 0), (r + 0.35, 2.0)], m=k.brick("t_silo_base", lo=0, hi=2, around=(*P(x, d)[:2], r)), n=20, name="silo_base"), (0, 0, 1), (0, 0, -1)),
            hide(k.lathe([(r, 1.9), (r, ze + 0.3)], m=staves, n=20, name="silo"), (0, 0, 1), (0, 0, -1))]
    for z in range(4, int(ze), 4):
        body.append(hide(k.lathe([(r + 0.07, z), (r + 0.07, z + 0.3)], m=m["iron"], n=20, name="hoop"), (0, 0, 1), (0, 0, -1)))
    roof = roofing("t_silo_roof", ze, h)
    body.append(roof_tier(0.0, 0.6, 12, roof, "silo_roof", c=(0, 0), eave=(r + 0.8, r + 0.8), z=ze, h=3.3, per=3))
    body.append(hide(k.lathe([(dome(tt) * (r + 0.8), ze + tt * 3.3) for tt in (0.5, 0.8, 0.95)] + [(0, ze + 3.35)], m=roof, n=14, name="silo_cap"), (0, 0, -1)))
    body.append(k.ico(0.25, (0, 0, ze + 3.6), m=m["brass"], subdiv=1, name="silo_finial"))
    for sx in (-0.45, 0.45):
        body.append(k.box((0.12, 0.12, ze - 1.5), (sx, -r - 0.35, 1.0 + (ze - 1.5) / 2), m=m["timber"], name="ladder"))
    for z in range(2, int(ze), 2):
        body.append(k.box((0.9, 0.1, 0.1), (0, -r - 0.35, z), m=m["timber"], name="rung"))
    b, g = window(m, (0.0, -r - 0.05, ze - 1.4), (0, -1, 0), 0.55)
    t.put(body + b, g, x, d)


def haystack(t, key, s=1.0):
    x, d, w, _, h = t.block(key)
    m = t.m
    r = w / 2 - 0.4
    body = [k.lathe([(r * 0.95, 0), (r, h * 0.25), (r * 0.92, h * 0.5), (r * 0.7, h * 0.74), (r * 0.36, h * 0.92), (0, h * 0.97)], m=m["hay"], n=14, name="haystack"),
            k.ring(r * 0.93, h * 0.45, 0.08, m["timber"], n=14, sides=3, name="hay_rope"),
            k.cyl(0.08, 1.4, (0, 0, h * 0.97), m=m["timber"], n=4, name="hay_pole")]
    t.put(body, (), x, d)


def crops(t, x0, x1, d0, d1, rows, kinds, step=3.2):
    """Soil ridges running away from the track, a crop on each; the plants make way for every site
    (the ridges are low, so loot sits on them)."""
    m = t.m
    sites = [(x, d, BIG_R) for x, d in t.lay["big"]] + [(x, d, SMALL_R) for x, d in t.lay["small"]]
    across = (x1 - x0) / rows
    for i in range(rows):
        x = x0 + across * (i + 0.5)
        kind = kinds[i % len(kinds)]
        t.put([hide(k.box((1.7, d1 - d0, 0.36), (0, 0, GROUND + 0.04), m=m["soil"], bevel=0.12, name="ridge"), (0, 0, -1))], (), x, (d0 + d1) / 2)
        n = int((d1 - d0) / step)
        for j in range(n):
            d = d0 + (j + 0.5) * (d1 - d0) / n
            if any(math.hypot(x - sx, d - sd) < r + 0.9 for sx, sd, r in sites):
                continue
            z = GROUND + 0.2
            if kind == "pumpkin":
                s = 0.8 + 0.25 * abs(math.sin(i * 7.1 + j * 3.3))
                plant = [k.lathe([(0, 0), (0.45 * s, 0.05 * s), (0.62 * s, 0.3 * s), (0.45 * s, 0.56 * s), (0, 0.6 * s)], loc=(0, 0, z), m=m["pumpkin"], n=7, name="pumpkin"),
                         k.cyl(0.06, 0.3, (0, 0, z + 0.65 * s), m=m["timber"], n=4, name="pumpkin_stem")]
            elif kind == "cabbage":
                plant = [k.ico(0.55, (0, 0, z + 0.3), m=m["cabbage"], subdiv=1, scale=(1, 1, 0.75), name="cabbage")]
            else:  # wheat: a round stook of sheaves tied at the waist
                plant = [k.lathe([(0.55, 0), (0.32, 0.75), (0.5, 1.25), (0.4, 1.6), (0, 1.75)], loc=(0, 0, z - 0.2), m=m["hay"], n=7, name="stook"),
                         k.lathe([(0.35, 0.68), (0.35, 0.86)], loc=(0, 0, z - 0.2), m=m["timber"], n=7, name="stook_band")]
            t.put(plant, (), x, d, yaw=i * 37 + j * 53)


def rail_fence(t, points, h=1.3, step=3.0):
    """A timber post-and-rail fence along stop-frame points."""
    m = t.m
    for (x0, d0), (x1, d1) in zip(points, points[1:]):
        a, b = P(x0, d0), P(x1, d1)
        length = (b - a).length
        n = max(1, round(length / step))
        to = Matrix.Translation(a) @ Matrix.Rotation(math.atan2(b.y - a.y, b.x - a.x), 4, "Z")
        parts = [k.box((0.3, 0.3, h + 0.2), (length * i / n, 0, GROUND + (h + 0.2) / 2), m=m["timber"], name="fence_post") for i in range(n + 1)]
        parts += [k.box((length, 0.12, 0.22), (length / 2, 0.12, GROUND + z), m=m["timber"], name="fence_rail") for z in (0.55, h - 0.1)]
        for ob in parts:
            ob.data.transform(to)
        t.body += parts
        t.keep += [(x0 + (x1 - x0) * i / n, d0 + (d1 - d0) * i / n, 0.4) for i in range(n + 1)]


def cart(t, key, yaw=0.0, load="hay"):
    """A two-wheeled farm cart, shafts down, with a load of hay, sacks or pumpkins."""
    x, d, *_ = t.block(key)
    m = t.m
    body = [k.box((2.4, 4.0, 0.25), (0, 0.8, 1.35), m=m["planks"], name="cart_bed")]
    body += [k.box((0.14, 4.0, 0.6), (sx * 1.2, 0.8, 1.75), m=m["planks"], name="cart_side") for sx in (-1, 1)]
    body += [k.box((2.4, 0.14, 0.6), (0, 0.8 + sy * 2.0, 1.75), m=m["planks"], name="cart_end") for sy in (-1, 1)]
    for sx in (-1, 1):
        body.append(k.cyl(1.05, 0.22, (sx * 1.45, 0.8, 1.05), rot=(0, 90, 0), m=m["timber"], n=12, name="wheel"))
        body.append(k.cyl(0.25, 0.4, (sx * 1.5, 0.8, 1.05), rot=(0, 90, 0), m=m["iron"], n=6, name="hub"))
        body.append(k.box((0.14, 3.0, 0.14), (sx * 0.8, -2.5, 0.85), rot=(-15, 0, 0), m=m["timber"], name="shaft"))
    if load == "hay":
        body.append(k.puff(1.4, (0, 0.8, 2.1), m["hay"], scale=(0.85, 1.4, 0.55), name="cart_hay"))
    elif load == "sacks":
        body += [k.ico(0.55, (dx, 0.8 + dy, 1.95), m=m["sack"], subdiv=2, scale=(1.1, 0.8, 0.75), name="sack") for dx, dy in ((-0.5, -1.0), (0.5, -0.9), (0, 0.2), (-0.5, 1.3), (0.5, 1.4))]
    else:
        body += [k.ico(0.5, (dx, 0.8 + dy, 1.95), m=m["pumpkin"], subdiv=1, scale=(1, 1, 0.8), name="pumpkin") for dx, dy in ((-0.55, -1.0), (0.5, -0.6), (0, 0.5), (-0.5, 1.4), (0.55, 1.2))]
    t.put(body, (), x, d, yaw)


def sacks(t, x, d, n=4, yaw=0.0):
    m = t.m
    spots = ((0, 0, 0), (1.0, 0.2, 0), (0.5, 0.9, 0), (0.5, 0.35, 0.75), (-0.9, 0.5, 0))[:n]
    body = [k.ico(0.6, (dx, dy, GROUND + 0.45 + dz), m=m["sack"], subdiv=2, scale=(1.0, 0.8, 0.8), name="sack") for dx, dy, dz in spots]
    t.put(body, (), x, d, yaw, keep=1.6)


def rock(t, x, d, r=1.6, s=(1.0, 0.8, 0.6), keep=True):
    ob = k.displace(k.ico(r, (0, 0, GROUND + r * s[2] * 0.4), m=t.m["rock"], subdiv=2, scale=s, name="rock"), r * 0.18, size=r * 0.7, seed=int(abs(x * 7 + d * 3)) % 97 + 1)
    t.put([ob], (), x, d, yaw=(x * 37 + d * 11) % 360, keep=r * max(s[0], s[1]) if keep else 0)


def reeds(t, x, d, n=6):
    m = t.m
    body = []
    for i in range(n):
        a, rr = i * 2.4, 0.3 + 0.25 * (i % 3)
        hgt = 2.0 + 0.6 * math.sin(i * 1.7)
        body.append(k.cyl(0.07, hgt, (rr * math.cos(a), rr * math.sin(a), GROUND + hgt / 2), r2=0.04, m=m["reed"], n=4, name="reed"))
        if i % 2 == 0:
            body.append(k.capsule((rr * math.cos(a), rr * math.sin(a), GROUND + hgt * 0.7), (rr * math.cos(a), rr * math.sin(a), GROUND + hgt * 0.7 + 0.5), 0.1, 0.1, m["timber"], n=6, name="cattail"))
    t.put(body, (), x, d, keep=0.9)


def water(t, outline, kerb=True, skip=()):
    """A water surface on the plate (stop-frame outline), with a stone kerb along every edge but
    those numbered in `skip` (edge i runs from point i to point i + 1)."""
    pts = [P(x, d) for x, d in outline]
    ob = k.plate([[(p.x, p.y) for p in pts]], 0.06, loc=(0, 0, GROUND + 0.03), m=t.m["water"], name="water")
    t.body.append(hide(k.texel(ob, 0.5), (0, 0, -1)))
    for i, (a, b) in enumerate(zip(pts, pts[1:] + pts[:1])):
        if not kerb or i in skip:
            continue
        v = b - a
        ob = k.box((v.length + 0.7, 0.7, 0.45), ((a.x + b.x) / 2, (a.y + b.y) / 2, GROUND + 0.18), rot=(0, 0, math.degrees(math.atan2(v.y, v.x))), m=t.m["stone"], bevel=0.12, name="kerb")
        for vert in ob.data.vertices:  # ends that reach the plate's edge stop there
            vert.co.x = max(-W / 2, min(W / 2, vert.co.x))
            vert.co.y = max(-D / 2, min(D / 2, vert.co.y))
        t.body.append(ob)


def boat(t, x, d, yaw=0.0, upturned=False, z=None, s=1.0):
    """A little rowboat: a pointed open hull, two thwarts and a pair of oars."""
    m = t.m
    L, Wd, Hd = 6.0 * s, 2.4 * s, 0.9 * s

    def hull(u, v):
        e = 2 * u - 1
        half = Wd / 2 * max(0.0, 1 - e * e) ** 0.6
        a = math.pi * v
        return (-half * math.cos(a), e * L / 2, -Hd * math.sin(a) * (1 - 0.35 * e * e) + 0.35 * s * e * e)

    body = [k.surface(14, 6, hull, m=m["boat"], thickness=0.12, name="hull")]
    if not upturned:
        body += [k.box((Wd * 0.85, 0.35, 0.1), (0, dy * L, -0.25 * s), m=m["planks"], name="thwart") for dy in (-0.12, 0.18)]
        body += [k.box((0.12, L * 0.7, 0.08), (sx * Wd * 0.25, 0, -0.1 * s), rot=(0, 0, sx * 6), m=m["timber"], name="oar") for sx in (-1, 1)]
    lift = Hd + 0.05 + GROUND if z is None else z
    for ob in body:
        if upturned:
            ob.data.transform(Matrix.Rotation(math.pi, 4, "Y"))
        ob.data.transform(Matrix.Translation((0, 0, (GROUND + 0.35 * s) if upturned else lift)))
    t.put(body, (), x, d, yaw)


def teapot(s, china, lid):
    """The inn's emblem (tea, not drink): a round china teapot, spout on -x, handle on +x."""
    return [k.lathe([(0, 0), (0.55 * s, 0.02 * s), (0.9 * s, 0.3 * s), (1.0 * s, 0.62 * s), (0.85 * s, 0.95 * s), (0.5 * s, 1.1 * s), (0, 1.12 * s)], m=china, n=16, name="teapot"),
            k.lathe([(0.52 * s, 1.08 * s), (0.45 * s, 1.25 * s), (0.12 * s, 1.33 * s), (0, 1.34 * s)], m=lid, n=12, name="teapot_lid"),
            k.ico(0.14 * s, (0, 0, 1.42 * s), m=lid, subdiv=1, name="teapot_knob"),
            k.tube([(-0.8 * s, 0, 0.45 * s), (-1.2 * s, 0, 0.72 * s), (-1.45 * s, 0, 1.12 * s)], [0.2 * s, 0.13 * s, 0.09 * s], m=china, n=6, name="spout"),
            k.tube([(0.85 * s, 0, 0.95 * s), (1.35 * s, 0, 0.95 * s), (1.45 * s, 0, 0.62 * s), (0.95 * s, 0, 0.35 * s)], 0.08 * s, m=china, n=5, name="handle")]


def tea_table(t, key):
    """A round garden table set for tea: a teapot, two cups and saucers, three stools."""
    x, d, *_ = t.block(key)
    m = t.m
    body = [k.lathe([(0.35, 0), (0.18, 0.3), (0.14, 2.0), (1.25, 2.05), (1.3, 2.25), (0, 2.27)], loc=(0, 0, GROUND), m=m["timber"], n=14, name="table")]
    for ob in teapot(0.32, m["china"], m["cream"]):
        ob.data.transform(Matrix.Translation((0.1, 0.2, GROUND + 2.27)))
        body.append(ob)
    for dx, dy in ((-0.7, -0.4), (0.6, -0.6)):
        body.append(k.lathe([(0.22, 0), (0.24, 0.02), (0.06, 0.04), (0.13, 0.06), (0.15, 0.24), (0, 0.24)], loc=(dx, dy, GROUND + 2.27), m=m["china"], n=8, name="cup"))
    for a in (0, 120, 240):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        body.append(k.lathe([(0.3, 0), (0.22, 0.4), (0.2, 1.2), (0.55, 1.25), (0.55, 1.4), (0, 1.42)], loc=(2.0 * c, 2.0 * s, GROUND), m=m["timber"], n=8, name="stool"))
    t.put(body, (), x, d)


def waterwheel(t, x, d, r=6.5, width=2.4, z=5.5):
    """An undershot mill wheel, its face to the track and its axle running back into the mill
    (decor, static): an open rim band, sixteen paddles, two sets of spokes."""
    m = t.m
    body = [k.surface(24, 1, lambda u, v: (r * math.cos(2 * math.pi * u), r * math.sin(2 * math.pi * u), -width / 2 + width * v), m=m["timber"], thickness=0.5, name="wheel_rim")]
    for i in range(16):
        a = 2 * math.pi * i / 16
        body.append(k.box((1.3, 0.16, width - 0.1), (math.cos(a) * (r - 0.1), math.sin(a) * (r - 0.1), 0), rot=(0, 0, math.degrees(a)), m=m["planks"], name="paddle"))
    for i in range(4):
        for sz in (-0.3, 0.3):
            body.append(k.box((2 * r - 1.0, 0.3, 0.3), (0, 0, sz * width), rot=(0, 0, 45 * i), m=m["timber"], name="spoke"))
    body.append(k.cyl(0.7, width + 0.6, (0, 0, 0), m=m["iron"], n=10, name="wheel_hub"))
    body.append(k.cyl(0.3, width + 3.6, (0, 0, 1.5), m=m["iron"], n=8, name="axle"))
    for ob in body:  # local z (the axle) to Blender +y: back into the mill
        ob.data.transform(Matrix.Translation((0, 0, z)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    t.put(body, (), x, d)


def lantern_post(t, x, d, h=5.0):
    """A plain timber pole (a festoon anchor)."""
    t.put([k.box((0.3, 0.3, h), (0, 0, GROUND + h / 2), m=t.m["timber"], name="pole"), k.ico(0.2, (0, 0, GROUND + h + 0.1), m=t.m["brass"], subdiv=1, name="pole_cap")], (), x, d, keep=0.5)


def patch(t, x, d, r, m=None, n=24):
    """A round gravel patch on the plate."""
    c = P(x, d)
    ob = k.plate([[(c.x + r * math.cos(2 * math.pi * i / n), c.y + r * math.sin(2 * math.pi * i / n)) for i in range(n)]], 0.05, loc=(0, 0, GROUND + 0.025), m=m or t.m["path"], name="patch")
    t.body.append(hide(k.texel(ob, 0.5), (0, 0, -1)))
    return ob


def windmill(t, key):
    """A cream tower mill: brick plinth, a reefing stage with a rail, lit windows up the front, a
    scalloped plum cap and four lattice sails in an X facing the track (static; the lowest sail
    tip is 15 up, over everyone's head)."""
    x, d, w, _, h = t.block(key)
    m = t.m
    rb, rt, zc = w / 2 - 0.5, w / 2 - 2.6, 25.0
    profile = [(rb, 1.5), (rb - (rb - rt) * 0.55, zc * 0.5), (rt, zc + 0.4)]

    def radius(z):
        (r0, z0), (r1, z1) = (profile[0], profile[1]) if z < profile[1][1] else (profile[1], profile[2])
        return r0 + (r1 - r0) * (z - z0) / (z1 - z0)

    wall = k.paint("t_mill_wall", [(0, (214, 196, 178)), (0.4, k.CREAM), (1, (250, 240, 224))], 1.5, zc, grain=(0.05, 3.0))
    tower = k.lathe(profile, m=wall, n=28, name="tower")
    body, lit = [hide(tower, (0, 0, 1), (0, 0, -1)), hide(k.lathe([(rb + 0.4, 0), (rb + 0.4, 1.6)], m=k.brick("t_mill_plinth", lo=0, hi=1.6, around=(*P(x, d)[:2], rb)), n=28, name="plinth"), (0, 0, 1), (0, 0, -1))], []
    for z in (zc * 0.36, zc - 0.5):
        body.append(hide(k.lathe([(radius(z) + 0.05, z - 0.3), (radius(z) + 0.08, z + 0.3)], m=m["timber"], n=28, name="band"), (0, 0, 1), (0, 0, -1)))
    zs = 8.0  # the reefing stage
    rs = radius(zs) + 2.2
    body.append(k.lathe([(rs, zs - 0.2), (rs, zs + 0.15)], m=m["planks"], n=24, name="stage"))
    body.append(k.ring(rs - 0.1, zs + 1.2, 0.08, m["timber"], n=24, sides=4, name="stage_rail"))
    for i in range(12):
        a = 2 * math.pi * i / 12
        c, s = math.cos(a), math.sin(a)
        body.append(k.box((0.16, 0.16, 1.2), ((rs - 0.1) * c, (rs - 0.1) * s, zs + 0.6), m=m["timber"], name="stage_post"))
        r0 = radius(zs - 2.4) - 0.1
        body.append(k.tube([(r0 * c, r0 * s, zs - 2.4), ((rs - 0.5) * c, (rs - 0.5) * s, zs - 0.15)], 0.1, m=m["timber"], n=4, name="stage_strut"))
    for theta, z, r in ((0, 13.0, 0.85), (0, 19.0, 0.75), (-62, 4.6, 0.8), (62, 4.6, 0.8), (150, 13, 0.75), (-150, 13, 0.75)):
        parts, panes = round_window(tower, theta, z, r, m["timber"], m["glow"], None, c=(0, 0), seg=12, sides=4, pane_n=12)
        body += parts
        lit += panes
    p, _ = k.land(tower, (0, 0, 3), (0, -1, 0))
    arch = arch_outline(2.8, 4.6)
    body.append(k.poly(arch, 0.5, loc=(0, p.y - 0.05, 1.5), m=m["door"], name="door"))
    body.append(k.tube([Vector((ax * 1.1, p.y - 0.15, 1.5 + az * 1.03)) for ax, az in arch], 0.2, m=m["timber"], n=4, name="door_frame"))
    body.append(k.box((3.6, 1.2, 1.5), (0, p.y - 0.6, 0.75), m=m["stone"], bevel=0.05, name="step"))
    roof = roofing("t_cap", zc, zc + 7.4)
    eave = (rt + 1.7, rt + 1.7)
    for i, (t0, t1, tg) in enumerate(((0.0, 0.5, 18), (0.42, 0.84, 12))):
        body.append(roof_tier(t0, t1, tg, roof, f"cap{i}", c=(0, 0), eave=eave, z=zc, h=7.2, per=3))
    body.append(hide(k.lathe([(dome(tt) * eave[0], zc + tt * 7.2) for tt in (0.78, 0.9, 0.97)] + [(0, zc + 7.25)], m=roof, n=16, name="cap_crown"), (0, 0, -1)))
    body.append(k.capsule((0, 0, zc + 7.0), (0, 0, zc + 8.4), 0.14, 0.07, m["brass"], n=8, name="spike"))
    body.append(k.ico(0.35, (0, 0, zc + 7.6), m=m["brass"], subdiv=2, name="finial"))
    hub = Vector((0, -(rt + 2.4), zc + 2.6))
    body.append(k.cyl(0.5, rt + 1.0, (0, hub.y / 2 - 0.6, hub.z), rot=(90, 0, 0), m=m["iron"], n=10, name="windshaft"))
    body.append(k.cyl(0.95, 0.9, hub, rot=(90, 0, 0), m=m["iron"], n=12, name="hub"))
    body.append(k.ico(0.5, hub + Vector((0, -0.5, 0)), m=m["brass"], subdiv=2, name="hub_cap"))
    sail = k.paint("t_sail", [(0, (226, 214, 200)), (1, (246, 236, 220))], 0, 40, grain=(0.04, 2.0))
    span = 15.0
    for i in range(4):
        arm = [k.box((0.42, 0.42, span), (0, 0, span / 2 + 0.4), m=m["timber"], name="stock")]
        arm += [k.box((0.18, 0.2, span - 3.2), (sx, 0, 3.2 + (span - 3.2) / 2), m=m["timber"], name="sail_rail") for sx in (0.42, 2.7)]
        arm += [k.box((2.5, 0.16, 0.16), (1.55, 0, z), m=m["timber"], name="sail_bar") for z in [3.2 + j * (span - 3.4) / 8 for j in range(9)]]
        arm.append(k.box((2.1, 0.06, (span - 3.4) * 0.6), (1.55, 0.12, 3.4 + (span - 3.4) * 0.3), m=sail, name="sail_cloth"))
        turn = Matrix.Translation(hub) @ Matrix.Rotation(math.radians(45 + 90 * i), 4, "Y")
        for ob in arm:
            ob.data.transform(turn)
        body += arm
    t.put(body, lit, x, d)


def lighthouse(t, key):
    """A cream lighthouse with plum bands: brick plinth, lit windows climbing it, a gallery with a
    rail, the lantern room (its glass is the `beacon_glow` mesh, Lamp Glow), a plum dome and vane."""
    x, d, w, _, h = t.block(key)
    m = t.m
    rb, rt, zt = w / 2 - 0.7, 4.4, 33.0
    stripes = k.paint("t_lighthouse", [(0, (226, 210, 196)), (1, (252, 244, 230))], 0, zt, grain=(0.04, 3.0), bands=(k.ROOF_PLUM, 9.0))
    tower = k.lathe([(rb, 1.4), (rb * 0.85 + rt * 0.15, zt * 0.4), (rt, zt)], m=stripes, n=24, name="tower")
    body, lit = [hide(tower, (0, 0, 1), (0, 0, -1)), hide(k.lathe([(rb + 0.5, 0), (rb + 0.5, 1.5)], m=k.brick("t_lh_plinth", lo=0, hi=1.5, around=(*P(x, d)[:2], rb)), n=24, name="plinth"), (0, 0, 1), (0, 0, -1))], []
    for theta, z in ((-25, 9.0), (20, 16.0), (-15, 23.0), (160, 12.0), (-170, 20.0)):
        parts, panes = round_window(tower, theta, z, 0.6, m["timber"], m["glow"], None, c=(0, 0), seg=10, sides=4, pane_n=10)
        body += parts
        lit += panes
    p, _ = k.land(tower, (0, 0, 3), (0, -1, 0))
    arch = arch_outline(2.6, 4.4)
    body.append(k.poly(arch, 0.5, loc=(0, p.y - 0.05, 1.4), m=m["door"], name="door"))
    body.append(k.tube([Vector((ax * 1.1, p.y - 0.15, 1.4 + az * 1.03)) for ax, az in arch], 0.2, m=m["timber"], n=4, name="door_frame"))
    body.append(k.box((3.4, 1.2, 1.4), (0, p.y - 0.6, 0.7), m=m["stone"], bevel=0.05, name="step"))
    rg = rt + 1.7
    body.append(k.lathe([(rt - 0.2, zt - 1.2), (rg, zt - 0.15), (rg, zt + 0.25), (0, zt + 0.25)], m=m["iron"], n=24, name="gallery"))
    body.append(k.ring(rg - 0.1, zt + 1.4, 0.07, m["brass"], n=24, sides=4, name="gallery_rail"))
    for i in range(12):
        a = 2 * math.pi * i / 12
        body.append(k.box((0.12, 0.12, 1.2), ((rg - 0.1) * math.cos(a), (rg - 0.1) * math.sin(a), zt + 0.85), m=m["iron"], name="rail_post"))
    rl = rt * 0.72
    body.append(hide(k.lathe([(rl + 0.1, zt + 0.2), (rl + 0.1, zt + 1.3)], m=m["iron"], n=12, name="lantern_base"), (0, 0, -1)))
    beacon = [hide(k.lathe([(rl, zt + 1.2), (rl, zt + 4.6)], m=m["glow"], n=12, name="lantern_glass"), (0, 0, -1), (0, 0, 1))]
    for i in range(6):
        a = 2 * math.pi * i / 6
        body.append(k.box((0.16, 0.16, 3.4), ((rl + 0.04) * math.cos(a), (rl + 0.04) * math.sin(a), zt + 2.9), m=m["iron"], name="mullion"))
    roof = roofing("t_lh_roof", zt + 4.5, zt + 7.4)
    body.append(k.lathe([(rl + 0.7, zt + 4.5), (rl + 0.55, zt + 5.3), (rl * 0.55, zt + 6.5), (0.3, zt + 7.1), (0, zt + 7.2)], m=roof, n=16, name="lantern_dome"))
    body.append(k.ico(0.4, (0, 0, zt + 7.5), m=m["brass"], subdiv=2, name="finial"))
    body.append(k.cyl(0.06, 1.6, (0, 0, zt + 8.4), m=m["brass"], n=4, name="vane_rod"))
    body.append(k.hull([(-1.0, 0, zt + 8.9), (0.7, -0.05, zt + 8.75), (0.7, 0.05, zt + 8.75), (0.7, 0, zt + 9.15), (1.0, 0, zt + 8.95)], m["brass"], name="vane"))
    t.put(body, lit, x, d)
    t.put([], beacon, x, d, part="beacon_glow")


def skeps(t, key):
    """Three straw beehive skeps on a plank bench."""
    x, d, *_ = t.block(key)
    m = t.m
    body = [k.box((7.0, 1.6, 0.25), (0, 0, GROUND + 1.0), m=m["planks"], name="hive_bench")]
    body += [k.box((0.25, 1.4, 1.0), (sx, 0, GROUND + 0.5), m=m["timber"], name="hive_leg") for sx in (-3.0, 0, 3.0)]
    for sx in (-2.3, 0, 2.3):
        body.append(k.lathe([(0.75, 0), (0.8, 0.35), (0.72, 0.8), (0.5, 1.2), (0.22, 1.42), (0, 1.48)], loc=(sx, 0, GROUND + 1.12), m=m["skep"], n=12, name="skep"))
        body.append(k.box((0.36, 0.1, 0.22), (sx, -0.76, GROUND + 1.3), m=m["iron"], name="hive_door"))
    t.put(body, (), x, d)


def crates(t, key, apples=True):
    """A stack of three plank crates, the top ones heaped with apples."""
    x, d, *_ = t.block(key)
    m = t.m
    body = []
    for dx, dy, dz in ((-0.85, 0, 0), (0.85, 0, 0), (0, 0.1, 0.95)):
        body.append(k.box((1.6, 1.2, 0.9), (dx, dy, GROUND + 0.45 + dz), m=m["planks"], bevel=0.05, name="crate"))
        if apples:
            body += [k.ico(0.24, (dx + ax, dy + ay, GROUND + 0.95 + dz), m=m["fruit"][(i + int(dz)) % 2], subdiv=1, name="apple")
                     for i, (ax, ay) in enumerate(((-0.4, -0.25), (0.35, -0.2), (0, 0.25), (-0.35, 0.28)))]
    t.put(body, (), x, d)


def ladder(t, x, d, yaw=0.0, h=6.0):
    m = t.m
    body = [k.box((0.14, 0.14, h), (sx, 0, h / 2), m=m["timber"], name="ladder_rail") for sx in (-0.45, 0.45)]
    body += [k.box((0.9, 0.1, 0.1), (0, 0, z), m=m["timber"], name="ladder_rung") for z in [0.6 + i * 0.9 for i in range(int(h / 0.9) - 1)]]
    for ob in body:
        ob.data.transform(Matrix.Translation((0, 0, GROUND)) @ Matrix.Rotation(math.radians(-14), 4, "X"))
    t.put(body, (), x, d, yaw, keep=1.2)


def basket(t, x, d):
    m = t.m
    body = [k.lathe([(0.45, 0), (0.62, 0.55), (0.66, 0.6), (0, 0.6)], loc=(0, 0, GROUND), m=m["skep"], n=10, name="basket")]
    body += [k.ico(0.22, (ax, ay, GROUND + 0.66), m=m["fruit"][i % 2], subdiv=1, name="apple") for i, (ax, ay) in enumerate(((-0.25, -0.1), (0.2, -0.15), (0, 0.22)))]
    t.put(body, (), x, d, keep=0.8)


def millstones(t, x, d, yaw=0.0):
    m = t.m
    body = [k.cyl(1.7, 0.55, (0, 0, GROUND + 0.28), m=m["rock"], n=18, name="millstone"),
            k.cyl(1.6, 0.55, (0.3, 0.9, GROUND + 1.55), rot=(72, 0, 0), m=m["rock"], n=18, name="millstone")]
    t.put(body, (), x, d, yaw, keep=1.9)


def pump(t, x, d):
    """A cast-iron hand pump on a stone block, a bucket under the spout."""
    m = t.m
    body = [k.box((1.2, 1.2, 0.6), (0, 0, GROUND + 0.3), m=m["stone"], bevel=0.08, name="pump_base"),
            k.cyl(0.22, 2.4, (0, 0, GROUND + 1.8), m=m["iron"], n=8, name="pump"),
            k.ico(0.3, (0, 0, GROUND + 3.05), m=m["iron"], subdiv=1, name="pump_cap"),
            k.cyl(0.1, 0.8, (0, -0.4, GROUND + 2.3), rot=(70, 0, 0), m=m["iron"], n=6, name="spout"),
            k.box((0.12, 1.6, 0.12), (0, 0.7, GROUND + 3.0), rot=(-20, 0, 0), m=m["iron"], name="pump_handle"),
            k.lathe([(0.3, 0), (0.38, 0.6)], loc=(0, -0.9, GROUND), m=m["planks"], n=8, name="bucket")]
    t.put(body, (), x, d, keep=1.2)


def trough(t, x, d, yaw=0.0):
    m = t.m
    body = [k.box((3.6, 1.2, 0.9), (0, 0, GROUND + 0.45), m=m["planks"], bevel=0.06, name="trough"),
            k.box((3.3, 0.9, 0.05), (0, 0, GROUND + 0.8), m=m["water"], name="trough_water")]
    t.put(body, (), x, d, yaw, keep=1.9)


def crab_pots(t, x, d):
    m = t.m
    body = [k.lathe([(0.7, 0), (0.75, 0.3), (0.55, 0.8), (0, 0.95)], loc=(dx, dy, GROUND + dz), m=m["net"], n=10, name="crab_pot")
            for dx, dy, dz in ((0, 0, 0), (1.3, 0.3, 0), (0.6, 0.2, 0.9))]
    body.append(k.ring(0.5, GROUND + 0.1, 0.09, m["sack"], n=10, sides=4, name="rope"))
    body[-1].data.transform(Matrix.Translation((-1.2, -0.4, 0)))
    body.append(k.ring(0.45, GROUND + 0.25, 0.09, m["sack"], n=10, sides=4, name="rope"))
    body[-1].data.transform(Matrix.Translation((-1.2, -0.4, 0)))
    t.put(body, (), x, d, keep=1.8)


def buoy(t, x, d):
    m = t.m
    striped = k.paint("t_buoy", [(0, k.CREAM), (1, k.CREAM)], 0, 2, bands=(k.ROOF_PLUM, 0.9))
    t.put([k.lathe([(0, 0), (0.6, 0.15), (0.75, 0.6), (0.55, 1.2), (0.15, 1.45), (0, 1.5)], loc=(0, 0, GROUND), m=striped, n=12, name="buoy")], (), x, d, keep=0.9)


def net_rack(t, key):
    """Fishing nets hung to dry between three poles."""
    x, d, w, *_ = t.block(key)
    m = t.m
    half = w / 2 - 0.3
    body = [k.box((0.3, 0.3, 4.2), (sx, 0, GROUND + 2.1), m=m["timber"], name="net_pole") for sx in (-half, 0, half)]
    for x0, x1 in ((-half, 0), (0, half)):
        body.append(k.surface(6, 3, lambda u, v, x0=x0, x1=x1: (x0 + (x1 - x0) * u, 0.15 * math.sin(math.pi * u), GROUND + 3.8 - 2.6 * v - 0.5 * math.sin(math.pi * u) * (1 - v)), m=m["net"], thickness=0.05, name="net"))
    body.append(k.box((2 * half, 0.12, 0.12), (0, 0, GROUND + 3.9), m=m["timber"], name="net_bar"))
    t.put(body, (), x, d)


def tea_sign(t, key):
    """The inn sign (tea, not drink): a post with a hanging cream roundel and a lit lamp under the
    arm, crowned with a big teal teapot."""
    x, d, *_ = t.block(key)
    m = t.m
    c = P(x, d) + Vector((1.9, 0, GROUND + 4.6))
    roundel = k.paint("t_tea_roundel", [(0, k.CREAM), (1, k.CREAM)], 0, 1, marks=[((56, 118, 128), c, 1.0, 1.4), ((56, 118, 128), c, 0, 0.42)])
    body = [k.box((0.4, 0.4, 7.0), (0, 0, GROUND + 3.5), m=m["timber"], name="sign_post"),
            k.lathe([(0.65, 0), (0.65, 0.4), (0.32, 0.7)], loc=(0, 0, GROUND), m=m["stone"], n=8, name="sign_foot"),
            k.box((2.8, 0.18, 0.2), (1.3, 0, GROUND + 6.3), m=m["iron"], name="sign_arm"),
            k.texel(k.cyl(1.3, 0.16, (1.9, 0, GROUND + 4.6), rot=(90, 0, 0), m=roundel, n=24, name="tea_roundel"), 4)]
    body += [k.tube([(1.9 + dx, 0, GROUND + 5.85), (1.9 + dx, 0, GROUND + 6.25)], 0.03, m=m["iron"], n=4, name="chain") for dx in (-0.6, 0.6)]
    for ob in teapot(1.0, m["china"], m["cream"]):
        ob.data.transform(Matrix.Translation((0, 0, GROUND + 7.0)))
        body.append(ob)
    lit = [k.box((0.45, 0.45, 0.55), (2.6, 0, GROUND + 5.7), m=m["glow"], name="sign_lamp")]
    body.append(k.hull([(2.6 + sx * 0.4, sy * 0.4, GROUND + 6.05) for sx in (-1, 1) for sy in (-1, 1)] + [(2.6, 0, GROUND + 6.3)], m["iron"], name="sign_lamp_roof"))
    t.put(body, lit, x, d)


def stop_farm():
    """A plank barn with a lantern cupola, a stave silo and haystacks beside a farm track, a
    pumpkin and cabbage field in rail fences, the farmhouse by the platform."""
    t = Tile("farm")
    m = t.m
    path(t, [(4, RAMP - 0.5), (4, D)], 9)
    path(t, [(8.5, 77), (28, 77), (28, 80.5)], 4)
    path(t, [(-32, 36), (-32, 32), (-0.5, 32)], 3)
    shed(t, "barn", cupola=True, side=3)
    silo(t, "silo")
    cottage(t, "farmhouse", side=-130)
    for key in ("hay_1", "hay_2", "hay_3"):
        haystack(t, key)
    cart(t, "cart", load="pumpkins")
    crops(t, -56, -16, 66, 124, 10, ("pumpkin", "cabbage", "cabbage", "pumpkin", "cabbage"))
    rail_fence(t, [(-40, 63), (-57.5, 63), (-57.5, 127), (-14, 127)])  # the fence_ blocks
    rail_fence(t, [(-14, 75), (-14, 63), (-24, 63)])
    shed(t, "coop", lift=0.8, side=1, loft=False, door=(0.34, 2.4))
    pump(t, -18, 48)
    for i, (dx, dy, s) in enumerate(((0, 0, 1.0), (1.3, 0.4, 0.8), (-1.1, 0.6, 0.85), (0.4, 1.4, 0.75), (0.2, 0.6, 0.7))):
        t.put([k.lathe([(0, 0), (0.6 * s, 0.06 * s), (0.82 * s, 0.38 * s), (0.6 * s, 0.74 * s), (0, 0.8 * s)], loc=(dx, dy, GROUND + (0.6 if i == 4 else 0)), m=m["pumpkin"], n=8, name="pumpkin")], (), 22, 20)
    t.keep.append((22.3, 20.6, 2.2))
    for key, s in (("tree_1", 1.0), ("tree_2", 1.1), ("tree_3", 0.95), ("tree_4", 1.0)):
        tree(t, key, s, seed=t.block(key)[1])
    sacks(t, 14, 86, 4)
    for x, d in ((40.5, 79), (42, 80.6), (41, 77.4)):
        t.put([k.lathe([(0, 0), (0.6, 0.06), (0.82, 0.38), (0.6, 0.74), (0, 0.8)], loc=(0, 0, GROUND), m=m["pumpkin"], n=8, name="pumpkin")], (), x, d, keep=0.9)
    trough(t, 14, 100, yaw=90)
    for x, d, r in ((-40, 34, 1.2), (-24, 34, 1.2)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((-56, 40), (56, 50), (-56, 140), (56, 116), (30, 156)):
        bush(t, x, d, 1.9)
    barrel(t, 40, 112)
    barrel(t, 41.4, 113.4, 0.9)
    return t.done()


def stop_windmill():
    """The tower windmill, its sails in an X over the yard, the miller's cottage, a granary on
    staddle stones and a wheat patch; a lane of lamps runs straight to the platform."""
    t = Tile("windmill")
    m = t.m
    path(t, [(0, RAMP - 0.5), (0, D)], 9)
    path(t, [(4.5, 86), (24, 86), (24, 90.5)], 4)
    path(t, [(-28, 44), (-28, 38), (-4.5, 38)], 3)
    path(t, [(-30, 117), (-30, 113), (-4.5, 113)], 3.4)
    windmill(t, "windmill")
    cottage(t, "cottage", side=-130)
    shed(t, "granary", lift=1.4, side=2, door=(0.4, 5.5))
    cart(t, "cart", yaw=8, load="sacks")
    crops(t, 30, 56, 122, 152, 6, ("wheat",), step=2.6)
    sacks(t, 11, 93, 5)
    sacks(t, 33, 87, 3, yaw=40)
    millstones(t, 13, 104, yaw=-70)
    for key, s in (("tree_1", 1.05), ("tree_2", 1.0), ("tree_3", 0.95), ("tree_4", 0.9)):
        tree(t, key, s, seed=t.block(key)[1])
    for x, d, r in ((-36, 42, 1.2), (-20, 42, 1.2), (-18, 58, 1.3)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((-56, 120), (56, 96), (-40, 156), (24, 156)):
        bush(t, x, d, 1.9)
    toadstools(t, 44, 62)
    return t.done()


def stop_orchard():
    """Rows of round apple trees hung with paper lanterns either side of a grass lane, beehive
    skeps, apple crates and baskets, and the cream apple store at the far end."""
    t = Tile("orchard")
    m = t.m
    path(t, [(0, RAMP - 0.5), (0, D)], 9, m["path"])
    path(t, [(4.5, 135), (32, 135), (32, 138.5)], 4)
    for key in t.lay["blocks"]:
        if key.startswith("apple"):
            tree(t, key, 1.25, leaf=m["apple"], seed=t.block(key)[0] + t.block(key)[1], spread=0.31)
    for col in (-26, 26):
        for d0, d1 in ((34, 56), (56, 78), (78, 100), (100, 122)):
            festoon(t, (col, d0, 6.9), (col, d1, 6.9), n=4, sag=0.9)
    festoon(t, (6.5, 30, 7.4), (-6.5, 66, 7.4), n=7, sag=1.2)
    festoon(t, (-6.5, 66, 7.4), (6.5, 104, 7.4), n=7, sag=1.2)
    shed(t, "store", walls=k.paint("t_store_wall", [(0, (226, 204, 178)), (0.35, k.CREAM), (1, (255, 246, 228))], 0.8, 7, grain=(0.05, 3.0)), side=2)
    skeps(t, "hives")
    crates(t, "crates")
    crates(t, "crates_2")
    ladder(t, 23.6, 56, yaw=90)
    for x, d in ((-23, 34), (29, 78), (-41, 100), (41, 122), (-29, 122)):
        basket(t, x, d)
    for i, (x, d) in enumerate(((-44, 38), (-26, 60), (44, 82), (26, 102), (-44, 104), (44, 126))):
        t.put([k.ico(0.24, (0, 0, GROUND + 0.18), m=m["fruit"][i % 2], subdiv=1, name="windfall")], (), x, d, keep=0.4)
    for x, d in ((-56, 20), (56, 30), (-56, 150), (16, 156)):
        bush(t, x, d, 1.8)
    toadstools(t, -12, 140)
    return t.done()


def stop_inn():
    """The Kettle tea room inn: a broad two-storey drum with a teapot sign by the lane, a tea
    garden of round tables under strung lanterns, and the stable across the lane."""
    t = Tile("inn")
    m = t.m
    path(t, [(8, RAMP - 0.5), (8, D)], 9)
    path(t, [(-22, 61.5), (-22, 57), (3.5, 57)], 4.4)
    patch(t, -22, 40, 13.5)
    cottage(t, "inn", tongues=(24, 18, 13), side=-100, storeys=2, n=32)
    x, d, *_, h = t.block("inn")
    top = round(0.5 * h, 2) + 0.42 * h  # the crown of the inn's roof (cottage proportions)
    crown = teapot(2.6, m["china"], m["cream"])  # the tea room's crown, read from the train
    for ob in crown:
        ob.data.transform(Matrix.Translation((0, 0, top - 0.25)))
    t.put(k.texel(crown, 1.5), (), x, d)
    tea_sign(t, "sign")
    for key in ("table_1", "table_2", "table_3"):
        tea_table(t, key)
    shed(t, "stable", yaw=90, side=2, door=(0.36, 6.0))
    path(t, [(12.5, 118), (23, 118)], 4)
    for x, d in ((-37, 27), (-7, 27)):
        lantern_post(t, x, d, 6.0)
    festoon(t, (-37, 27, 6.2), (-28, 62.5, 10.5), n=6, sag=1.0)
    festoon(t, (-7, 27, 6.2), (-16, 62.5, 10.5), n=6, sag=1.0)
    festoon(t, (-37, 27, 6.2), (-7, 27, 6.2), n=6, sag=1.0)
    trough(t, 20, 108, yaw=90)
    t.put([k.lathe([(1.4, 0), (1.45, 0.7), (1.4, 1.4)], loc=(0, 0, GROUND), m=m["hay"], n=14, name="hay_bale")], (), 21, 130, keep=1.6)
    barrel(t, -8, 70)
    barrel(t, -7, 72, 0.9)
    for key, s in (("tree_1", 1.0), ("tree_2", 1.1), ("tree_3", 0.95), ("tree_4", 1.0)):
        tree(t, key, s, seed=t.block(key)[1])
    for x, d, r in ((-36, 60, 1.3), (-9, 60, 1.3)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((-56, 46), (56, 80), (-56, 100), (-20, 156)):
        bush(t, x, d, 1.9)
    return t.done()


def stop_mill():
    """A round mill house with its water wheel in the mill stream, the mill pond by the platform,
    the miller's cottage, a sack store and millstones; the lane stays clear of the water."""
    t = Tile("mill")
    m = t.m
    path(t, [(4, RAMP - 0.5), (4, D)], 9)
    path(t, [(-0.5, 110), (-18.5, 110)], 4)
    path(t, [(28, 42), (28, 37), (8.5, 37)], 3)
    path(t, [(8.5, 116), (32, 116), (32, 119.5)], 3.4)
    # The mill stream comes down from the far edge into the mill pool, which runs across the
    # tile in front of the mill so the wheel shows its face to the train; a duck pond by the platform.
    water(t, [(-37, 98), (-37, D), (-47, D), (-47, 98)], skip=(1, 3))
    water(t, [(-22, 84), (-22, 98), (-37, 98), (-47, 98), (-47, 84)], skip=(2,))
    water(t, [(-42 + 9 * math.cos(2 * math.pi * i / 20), 38 + 9 * math.sin(2 * math.pi * i / 20)) for i in range(20)])
    cottage(t, "mill", yaw=-90, tongues=(20, 15, 11), side=130, storeys=2, n=28)
    waterwheel(t, -30, 96.5)
    cottage(t, "cottage", side=-130)
    shed(t, "store", side=2, door=(0.4, 6))
    cart(t, "cart", yaw=-6, load="sacks")
    millstones(t, -14, 102, yaw=20)
    sacks(t, -14, 116, 5)
    sacks(t, 22, 120, 3)
    for x, d in ((-50, 104), (-50, 134), (-34, 50), (-33.5, 30), (-49, 86), (-20, 82)):
        reeds(t, x, d)
    for i, (x, d) in enumerate(((-44, 36), (-39, 41), (-46, 41.5))):
        t.put([k.cyl(0.9 - 0.15 * i, 0.04, (0, 0, GROUND + 0.1), m=m["cabbage"], n=10, name="lily_pad")], (), x, d)
    for key, s in (("tree_1", 1.0), ("tree_2", 1.05), ("tree_3", 0.95), ("tree_4", 1.0)):
        tree(t, key, s, seed=t.block(key)[1])
    for x, d, r in ((22, 36, 1.2), (34, 36, 1.2)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((56, 64), (56, 136), (40, 156)):
        bush(t, x, d, 1.9)
    return t.done()


def stop_lighthouse():
    """The banded lighthouse over a sandy cove at the far edge, the keeper's cottage and the net
    shed, rocks, an upturned rowboat, crab pots and a buoy; the lane runs down to the sand."""
    t = Tile("lighthouse")
    m = t.m
    sand = [(-W / 2, 154)] + [(x, 134 + 3 * math.sin(x * 0.11) + 1.5 * math.sin(x * 0.31)) for x in range(-60, 61, 6)] + [(W / 2, 154)]
    pts = [P(x, d) for x, d in sand]
    t.body.append(hide(k.texel(k.plate([[(p.x, p.y) for p in pts]], 0.05, loc=(0, 0, GROUND + 0.025), m=m["sand"], name="sand"), 0.45), (0, 0, -1)))
    path(t, [(-4, RAMP - 0.5), (-4, 129)], 9)  # stops where the sand begins
    path(t, [(0.5, 106), (30, 106), (30, 112.5)], 4)
    path(t, [(-28, 50), (-28, 44), (-8.5, 44)], 3)
    lighthouse(t, "lighthouse")
    cottage(t, "cottage", side=-130)
    shed(t, "netshed", side=1, door=(0.42, 5.5))
    for key in ("rock_1", "rock_2", "rock_3"):
        x, d, w, dd, h = t.block(key)
        rock(t, x, d, w / 2, (1.0, dd / w, h / (w / 2) / 1.2), keep=False)
    boat(t, *t.block("boat")[:2], yaw=12, upturned=True)
    for x, d, r in ((-44, 142, 0.9), (22, 146, 0.8), (-14, 156, 0.7), (40, 132, 0.8)):
        rock(t, x, d, r)
    for x, d, r in ((-34, 148, 1.6), (6, 150, 1.3)):
        water(t, [(x + r * math.cos(2 * math.pi * i / 10), d + r * 0.7 * math.sin(2 * math.pi * i / 10)) for i in range(10)], kerb=False)
        t.body[-1].data.transform(Matrix.Translation((0, 0, 0.04)))  # clear of the sand: no z-fighting
        t.keep.append((x, d, r))
    crab_pots(t, 22, 92)
    buoy(t, 40, 104)
    net_rack(t, "nets")
    t.put([k.capsule((-2.2, 0, GROUND + 0.4), (2.2, 0, GROUND + 0.4), 0.4, 0.32, m["bark"], n=8, name="driftwood")], (), 30, 150, yaw=20, keep=2.4)
    for x, d in ((-20, 137), (6, 139), (-54, 134), (52, 128)):
        reeds(t, x, d, 5)
    water(t, [(-W / 2, 154), (W / 2, 154), (W / 2, D), (-W / 2, D)], kerb=False)  # the sea's edge: a block, nobody wades in
    t.put([k.box((W, 0.6, 0.06), (0, 0, GROUND + 0.08), m=m["cream"], name="foam")], (), 0, 154.4)
    fence(t, [(-35, 47), (-29.8, 47)])
    fence(t, [(-26.2, 47), (-21, 47)])
    t.body += bench(*P(18, 102)[:2], m["timber"], m["iron"], z0=GROUND)
    t.keep.append((18, 102, 2.0))
    for key, s in (("tree_1", 0.95), ("tree_2", 1.0)):
        tree(t, key, s, seed=t.block(key)[1])
    for x, d, r in ((-36, 46, 1.2), (-20, 46, 1.2)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((56, 60), (-56, 90), (56, 96)):
        bush(t, x, d, 1.9)
    return t.done()


def stop_boathouse():
    """A boathouse straddling the edge of a lake inlet, its big doors on the water, a jetty with
    moored rowboats and a lamp at its end, the fisher's cottage, net racks and crab pots."""
    t = Tile("boathouse")
    m = t.m
    path(t, [(10, RAMP - 0.5), (10, D)], 9)
    path(t, [(5.5, 96), (-13, 96)], 4)
    path(t, [(26, 42), (26, 37), (14.5, 37)], 3)
    path(t, [(5.5, 80), (-22, 80)], 4)
    # The lake inlet down the left side, 70 studs from the platform: the jetty runs out across its
    # near end, seen in profile from the train with its boats and lanterns; the boathouse stands
    # side-on to the track behind it, big doors on the water.
    water(t, [(-24, 70), (-24, D), (-W / 2, D), (-W / 2, 70)], skip=(1, 2))
    shed(t, "boathouse", yaw=90, rear=True, side=2, door=(0.5, 7.5))
    t.put([k.box((7.0, 7.2, 0.3), (0, 0, GROUND + 0.1), rot=(0, -6, 0), m=m["boards"], name="slipway")], (), -41.5, 96)
    jetty = [k.box((34, 4.4, 0.35), (0, 0, GROUND + 0.6), m=m["boards"], bevel=0.05, name="jetty")]
    jetty += [k.cyl(0.25, 1.6, (x, sy * 2.0, GROUND + 0.3), m=m["timber"], n=6, name="jetty_post") for sy in (-1, 1) for x in range(-15, 17, 6)]
    jetty += [k.cyl(0.18, 3.4, (x, -2.0, GROUND + 1.7), m=m["timber"], n=6, name="lantern_pole") for x in (-15, -3, 9)]
    t.put(jetty, (), -40, 80)
    for a, b in ((-25, -37), (-37, -49)):
        festoon(t, (a, 82, 3.4), (b, 82, 3.4), n=4, sag=0.6)
    boat(t, -44, 74.5, yaw=90, z=GROUND + 0.65)
    boat(t, -50, 85.5, yaw=86, z=GROUND + 0.65, s=0.95)
    t.put([k.cyl(0.14, 8.0, (0, 0, GROUND + 4.6), m=m["timber"], n=6, name="mast"),
           k.capsule((0, 0.2, GROUND + 1.8), (0, 3.4, GROUND + 1.6), 0.32, 0.22, m["sack"], n=8, name="furled_sail"),
           k.ico(0.16, (0, 0, GROUND + 8.7), m=m["brass"], subdiv=1, name="mast_cap")], (), -50, 85.5, yaw=86)
    boat(t, -45, 96, yaw=90, z=GROUND + 0.75, s=0.85)
    boat(t, -36, 128, yaw=70, z=GROUND + 0.65, s=0.9)
    boat(t, *t.block("boat")[:2], yaw=-20, upturned=True)
    cottage(t, "cottage", side=130)
    net_rack(t, "nets")
    crab_pots(t, 40, 124)
    buoy(t, 20, 104)
    barrel(t, -11, 106)
    barrel(t, -10.5, 108, 0.9)
    for x, d in ((-58, 73), (-27, 74), (-58, 150), (-27, 155), (-27, 138)):
        reeds(t, x, d, 6)
    for key, s in (("tree_1", 1.0), ("tree_2", 0.95), ("tree_3", 1.05)):
        tree(t, key, s, seed=t.block(key)[1])
    for x, d, r in ((18, 46, 1.2), (34, 46, 1.2)):
        bush(t, x, d, r, m["bloom"])
    for x, d in ((-56, 62), (56, 90), (56, 140)):
        bush(t, x, d, 1.9)
    return t.done()


TILE_NOTES = ("Stop tile, 120 x 160 ground plate (the bounding box), front (-Z) on the track: the platform's track edge is the front face. Ground top 0.2 above "
              "the bounding box bottom (the plate stands proud of the terrain), platform top 2.0, deck depth 0 to 10, gravel ramp 10 to 15 down the whole length. "
              "Blocks (collide), sites and street lamps: LAYOUT in tools/blender/lantern/assets/tiles.py, the proposal for LanternConfig.TILES, in the stop frame "
              "(x across = Blender -x, depth from the platform edge). Mesh CanCollide false. Glow mesh: lit windows, street lamps and the platform lamps (Neon); "
              "code adds a PointLight (range 18) at each street lamp and one per building's window cluster (range 12, brightness 1.2) within the 24-light budget.")

ASSETS = [
    dict(name="house_cottage", build=house_cottage, budget=10000, finalize=k.HD, size=[20.6, 16.5, 20], priority=1, order=10,
         replaces="none (style-test house of the stop_village set; not uploaded on its own)",
         notes=("Ground at y = 0, platform top at 2, platform edge facing -Z towards the track. Two meshes: house_cottage (textured) and "
                "house_cottage_glow (Neon: windows, door porthole, dormer, the sign lamp and the lamp post). Code adds a PointLight per lit window (range 12, brightness 1.2) "
                "and on the lamp post (range 18). Mesh CanCollide false; collide with invisible parts: the platform box and a cylinder for the house."),
         glow={"glow": k.WINDOW_GLOW}),
    *[dict(name=f"stop_{tile}", build=build, budget=25000, finalize=k.HD, size=[120, height, 160], priority=1, order=20 + i,
           replaces="stop fallback (coloured blocks from Tile.blocks)", notes=f"{about} " + TILE_NOTES,
           glow={"glow": k.WINDOW_GLOW, **({"beacon_glow": k.LAMP_GLOW} if tile == "lighthouse" else {})})
      for i, (tile, build, height, about) in enumerate((
          ("village", stop_village, 16.6, "Village: the hero house_cottage with three neighbours, the well, lanterns strung over the lane."),
          ("farm", stop_farm, 24.1, "Farm: the barn with a lantern cupola, the silo, haystacks, the pumpkin field, the farmhouse."),
          ("windmill", stop_windmill, 40.2, "Windmill: the tower mill and its static sails (lowest tip 15 up), the miller's cottage, the granary on staddle stones, wheat."),
          ("orchard", stop_orchard, 14.6, "Orchard: twenty apple trees hung with paper lanterns, skeps, apple crates, the apple store."),
          ("inn", stop_inn, 25.9, "Inn: the two-storey tea room (a teapot sign: tea, not drink), the tea garden, the stable."),
          ("mill", stop_mill, 20.9, "Mill: the mill house and its water wheel (static) in the stream, the mill pond, the miller's cottage, the store."),
          ("lighthouse", stop_lighthouse, 42.2, "Lighthouse: the banded lighthouse (beacon_glow: its lantern glass, Neon Lamp Glow; code may add a PointLight, range 30), "
                                              "the keeper's cottage, the net shed, the sandy cove."),
          ("boathouse", stop_boathouse, 14.9, "Boathouse: the boathouse over the inlet, the jetty and its boats, the fisher's cottage. The water is a block (keep out)."),
      ))],
]
