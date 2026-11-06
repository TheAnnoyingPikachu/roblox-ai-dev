"""Lantern Express world pieces (docs/architecture/lantern.md section 9): Lamplight Depot (the hub
building, its platform, signal and boards), Dawn Station, the rail section and the three scatter
props. Red brick, plum shingles, brass lamps and lit windows for the Depot; cream stone and a golden
dome under a rising-sun window for Dawn. Built at stud scale, ground at z = 0, front -Y (the track
side). Lit glass is a separate `_glow` mesh the game sets to Neon."""

import math

import bpy
import kit as k
from mathutils import Matrix, Vector

STONE = [(0, (196, 186, 176)), (1, (226, 218, 206))]
TEAL = [(0, (40, 98, 110)), (1, (72, 138, 146))]
PLUM = [(0, (96, 50, 90)), (0.6, k.ROOF_PLUM), (1, k.ROOF_PLUM_HI)]


def frame_at(p, n):
    """Matrix placing local +Z along n at p, local +Y as close to up as possible."""
    x, y, z = k._frame(n)
    return Matrix.Translation(p) @ Matrix((x, y, z)).transposed().to_4x4()


def place(F, objs):
    for ob in objs:
        ob.data.transform(F)
    return objs


def arch(w, h, n=8):
    """Round-topped outline in local x/y, base at y = 0, from the bottom right round to the bottom left."""
    r = w / 2
    return [(r, 0), (r, h - r)] + [(r * math.cos(math.pi * i / n), h - r + r * math.sin(math.pi * i / n)) for i in range(1, n)] + [(-r, h - r), (-r, 0)]


def window(F, w, h, frame_m, glow_m, sill_m, out=0.0, cross=True):
    """A round-topped lit window in frame F (x across, y up, z out of the wall), base at y = 0:
    glass (glow), a frame round it, a mullion cross and a sill. `out` lifts it off a curved wall."""
    pts = arch(w, h)
    glass = k.poly(pts, 0.08, loc=(0, 0, out + 0.03), rot=(-90, 0, 0), m=glow_m, name="glass")
    body = [k.tube([(x, y, out + 0.1) for x, y in pts], 0.14, m=frame_m, n=4, cap=False, name="frame"),
            k.box((w + 0.5, 0.3, 0.5), (0, -0.1, out + 0.2), m=sill_m, bevel=0.05, name="sill")]
    if cross:
        body += [k.box((0.14, h - 0.1, 0.1), (0, h / 2, out + 0.1), m=frame_m, name="mullion"),
                 k.box((w - 0.1, 0.14, 0.1), (0, h - w / 2, out + 0.1), m=frame_m, name="transom")]
    return place(F, body), place(F, [glass])


def lantern(x, y, z, brass, iron, glow, s=1.0):
    """A hanging six-sided lantern, its base at z (the train cars' lantern). Returns (body, glow)."""
    body = [k.lathe([(0.2 * s, 0), (0.32 * s, 0.05 * s), (0.32 * s, 0.14 * s)], loc=(x, y, z), m=brass, n=6, name="lantern_foot")]
    lit = [k.lathe([(0.27 * s, 0.12 * s), (0.31 * s, 0.4 * s), (0.27 * s, 0.68 * s)], loc=(x, y, z), m=glow, n=6, name="lantern_glass")]
    for i in range(6):
        a = math.pi / 3 * i
        body.append(k.box((0.06 * s, 0.06 * s, 0.6 * s), (x + 0.31 * s * math.cos(a), y + 0.31 * s * math.sin(a), z + 0.4 * s), rot=(0, 0, math.degrees(a)), m=brass, name="lantern_bar"))
    body.append(k.lathe([(0.4 * s, 0.66 * s), (0.36 * s, 0.76 * s), (0.14 * s, 0.98 * s), (0, 1.02 * s)], loc=(x, y, z), m=iron, n=6, name="lantern_roof"))
    return body, lit


def lamp_post(x, y, z0, h, iron, brass, glow):
    """The village street lamp (house_cottage's): iron post, brass cup, glowing hexagonal lamp,
    iron hat and finial. Top at z0 + h + 2.22."""
    body = [k.lathe([(0.5, 0), (0.5, 0.4), (0.25, 0.7), (0.19, 0.9)], loc=(x, y, z0), m=iron, n=12, name="post_foot"),
            k.cyl(0.17, h, (x, y, z0 + h / 2), m=iron, n=10, name="post"),
            k.lathe([(0.3, 0), (0.55, 0.15), (0.55, 0.24)], loc=(x, y, z0 + h), m=brass, n=6, name="post_cup")]
    lit = [k.lathe([(0.46, 0.2), (0.6, 1.0), (0.6, 1.3)], loc=(x, y, z0 + h), m=glow, n=6, name="post_lamp")]
    for i in range(6):
        a = math.pi / 3 * i
        body.append(k.box((0.09, 0.09, 1.1), (x + 0.61 * math.cos(a), y + 0.61 * math.sin(a), z0 + h + 0.78), rot=(0, 0, math.degrees(a)), m=brass, name="post_bar"))
    body.append(k.lathe([(0.82, 1.28), (0.76, 1.4), (0.32, 1.8), (0.12, 1.9), (0, 1.95)], loc=(x, y, z0 + h), m=iron, n=6, name="post_roof"))
    body.append(k.sphere(0.14, (x, y, z0 + h + 2.08), m=brass, seg=10, rings=6, name="post_finial"))
    return body, lit


def scallop_dome(cx, cy, R, z0, H, m, tiers=((0.0, 0.36, 16), (0.3, 0.64, 12), (0.58, 0.86, 8))):
    """The cottage roof at any size: rings of round shingles whose hems hang in scallops, a cap."""

    def prof(t):
        return max(0.0, 1 - t * t) ** 0.55 + 0.05 * (1 - t) ** 4

    parts = []
    for t0, t1, tongues in tiers:
        def fn(u, v, t0=t0, t1=t1, tongues=tongues):
            a = 2 * math.pi * u
            t = t0 + (t1 - t0) * v
            hem = (1 - v) ** 3
            r = R * (prof(t) + 0.025 * hem)
            return (cx + r * math.cos(a), cy + r * math.sin(a), z0 + t * H - 0.045 * R * hem * abs(math.sin(tongues * a / 2)) ** 0.6)

        parts.append(k.surface(tongues * 4, 2, fn, m=m, thickness=0.3, name="tier"))
    cap = [(R * prof(t), z0 + t * H) for t in (0.8, 0.88, 0.95, 0.99)] + [(0, z0 + H + 0.05)]
    parts.append(k.lathe(cap, loc=(cx, cy, 0), m=m, n=24, name="crown"))
    return parts


def valance(x0, x1, y, z_top, z_bot, m, r=0.6):
    """The cream scalloped valance hung along a canopy edge (station canopies)."""
    n = max(1, round((x1 - x0) / (2 * r)))
    step = (x1 - x0) / n
    pts = [(x0, z_top), (x1, z_top)]
    for j in reversed(range(n)):
        c = x0 + step * (j + 0.5)
        pts += [(c + step / 2 * math.cos(math.pi * i / 4), z_bot - step / 2 * math.sin(math.pi * i / 4)) for i in range(5)]
    return k.poly(pts, 0.1, loc=(0, y, 0), m=m, name="valance")


def text(body, size, loc, m):
    """Flat letters facing -Y, centred on loc (a glow part: lit letters, never baked)."""
    cu = bpy.data.curves.new("text", "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.resolution_u = 3
    ob = bpy.data.objects.new("text", cu)
    bpy.context.scene.collection.objects.link(ob)
    k._select([ob])
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    ob.data.transform(Matrix.Translation(loc) @ Matrix.Rotation(math.radians(90), 4, "X"))
    ob.data.materials.append(m)
    return ob


def clock(F, r, brass, iron, glow):
    """A lit clock face (glow) in frame F: brass bezel, twelve ticks, hands at ten past ten."""
    body = [k.ring(r, 0.1, r * 0.075, brass, n=24, sides=4, name="bezel")]
    for i in range(12):
        a = math.pi / 6 * i
        long = i % 3 == 0
        body.append(k.box((0.16 if long else 0.1, r * (0.24 if long else 0.14), 0.06), (r * 0.8 * math.sin(a), r * 0.8 * math.cos(a), 0.1), rot=(0, 0, -math.degrees(a)), m=iron, name="tick"))
    for deg, length, w in ((-60, 0.5, 0.24), (60, 0.72, 0.15)):
        a = math.radians(deg)
        body.append(k.box((w, r * length, 0.06), (r * length / 2 * math.sin(a), r * length / 2 * math.cos(a), 0.16), rot=(0, 0, -deg), m=iron, name="hand"))
    body.append(k.cyl(0.22, 0.12, (0, 0, 0.2), m=brass, n=12, name="boss"))
    face = k.cyl(r * 0.95, 0.06, (0, 0, 0.04), m=glow, n=24, name="face")
    return place(F, body), place(F, [face])


# Lamplight Depot ---------------------------------------------------------------------------------


def depot_hub():
    brick = k.brick("dh_brick", lo=0, hi=5)
    drum_l = k.brick("dh_drum_l", lo=0, hi=5, around=(-24.2, 2, 5.6))
    drum_r = k.brick("dh_drum_r", lo=0, hi=5, around=(24.2, 2, 5.6))
    stone = k.paint("dh_stone", STONE, 0, 24, grain=(0.06, 2.0))
    roof = k.paint("dh_roof", PLUM, 12, 24, bands=((112, 60, 102), 0.9), grain=(0.06, 1.5))
    door = k.paint("dh_door", TEAL, 1, 8, grain=(0.12, 5, "wave"))
    board = k.paint("dh_board", TEAL, 9, 13)
    cream = k.paint("dh_cream", [(0, (240, 222, 196)), (1, k.CREAM)], 7, 10)
    iron = k.paint("dh_iron", [(0, (64, 56, 90)), (1, (112, 100, 144))], 0, 30)
    brass = k.brass("dh_brass", 0, 30)
    timber = k.mat("dh_timber", k.TIMBER, kind="wood", scale=3, var=0.1)
    glow = k.flat(k.WINDOW_GLOW)
    body, lit = [], []

    def add(parts):
        b, g = parts
        body.extend(b)
        lit.extend(g)

    # Hall: brick box on a stone plinth, stone cornice, a plum barrel roof with brick gables.
    body.append(k.box((40.4, 14.4, 1.0), (0, 2, 0.5), m=stone, bevel=0.05, name="plinth"))
    body.append(k.box((40, 14, 12), (0, 2, 6), m=brick, name="hall"))
    body.append(k.box((40.8, 14.8, 0.6), (0, 2, 12.0), m=stone, bevel=0.08, name="cornice"))
    body.append(k.surface(16, 6, lambda u, v: (-20.5 + 41 * v, 2 - 7.9 * math.cos(math.pi * u), 12.2 + 5.5 * math.sin(math.pi * u)), m=roof, thickness=0.35, name="vault"))
    gable = [(-7.9 * math.cos(math.pi * i / 12), 12.2 + 5.5 * math.sin(math.pi * i / 12)) for i in range(13)]
    for s in (-1, 1):
        body.append(k.poly(gable, 0.4, loc=(s * 20.0, 2, 0), rot=(0, 0, 90), m=brick, name="gable"))
    for x in (-13, 13):
        body.append(k.box((1.6, 1.6, 4.6), (x, 5.5, 17.3), m=brick, name="chimney"))
        body.append(k.box((2.0, 2.0, 0.4), (x, 5.5, 19.7), m=stone, bevel=0.06, name="chimney_cap"))
        body.append(k.lathe([(0.34, 0), (0.38, 0.55), (0.45, 0.68), (0.32, 0.72)], loc=(x, 5.5, 19.9), m=k.paint("dh_pot", [(0, (190, 96, 70)), (1, (214, 124, 90))], 19.9, 20.6), n=10, name="pot"))

    # Pavilions: round brick drums at both ends under scalloped plum domes with brass finials.
    for s, drum in ((-1, drum_l), (1, drum_r)):
        cx = s * 24.2
        body.append(k.lathe([(5.9, 0), (5.9, 1.0), (5.6, 1.1)], loc=(cx, 2, 0), m=stone, n=32, name="drum_plinth"))
        body.append(k.lathe([(5.6, 0.9), (5.6, 14.0)], loc=(cx, 2, 0), m=drum, n=32, name="drum"))
        body.append(k.lathe([(5.55, 13.4), (5.8, 13.6), (5.8, 14.1), (5.5, 14.3)], loc=(cx, 2, 0), m=stone, n=32, name="drum_cornice"))
        body += scallop_dome(cx, 2, 5.6, 14.1, 8.5, roof)
        body.append(k.capsule((cx, 2, 22.4), (cx, 2, 24.4), 0.16, 0.06, brass, n=10, name="spike"))
        body.append(k.sphere(0.42, (cx, 2, 23.0), m=brass, seg=16, rings=8, name="finial"))
        for theta in (-28, 28):
            t = math.radians(theta)
            n = Vector((math.sin(t), -math.cos(t), 0))
            add(window(frame_at(Vector((cx, 2, 2.6)) + n * 5.6, n), 2.4, 6.4, timber, glow, stone, out=0.14))

    # Front: four tall arched windows, the clock tower with the doors, the sign and the clock.
    for x in (-14.5, -8.5, 8.5, 14.5):
        add(window(frame_at(Vector((x, -5.0, 2.4)), Vector((0, -1, 0))), 3.0, 6.6, timber, glow, stone))
        add(window(frame_at(Vector((x, 9.0, 2.4)), Vector((0, 1, 0))), 3.0, 6.6, timber, glow, stone))
    body.append(k.box((8.4, 8.4, 1.0), (0, -2, 0.5), m=stone, bevel=0.05, name="tower_plinth"))
    body.append(k.box((8, 8, 22.5), (0, -2, 11.25), m=brick, name="tower"))
    body.append(k.box((8.8, 8.8, 0.7), (0, -2, 22.5), m=stone, bevel=0.08, name="tower_cornice"))
    for z in (9.0, 15.0):
        body.append(k.box((8.3, 8.3, 0.35), (0, -2, z), m=stone, name="tower_band"))
    # Doors: teal double doors, a lit fanlight, a stone arch, steps, a lantern each side.
    F = frame_at(Vector((0, -6.0, 1.0)), Vector((0, -1, 0)))
    body += place(F, [k.box((4.0, 5.2, 0.16), (0, 2.6, 0.08), m=door, name="door"),
                      k.box((0.1, 5.2, 0.1), (0, 2.6, 0.2), m=iron, name="door_split"),
                      k.tube([(x, y, 0.2) for x, y in arch(4.6, 7.6)], 0.32, m=stone, n=6, cap=False, name="door_arch")])
    for x in (-0.5, 0.5):
        body += place(F, [k.sphere(0.14, (x, 2.6, 0.26), m=brass, seg=10, rings=6, name="knob")])
    fan = [(2.0 * math.cos(math.pi * i / 12), 5.2 + 2.0 * math.sin(math.pi * i / 12)) for i in range(13)]
    lit += place(F, [k.poly(fan, 0.08, loc=(0, 0, 0.04), rot=(-90, 0, 0), m=glow, name="fanlight")])
    body.append(k.box((6.0, 1.6, 0.5), (0, -6.8, 0.25), m=stone, bevel=0.05, name="step"))
    body.append(k.box((5.2, 0.9, 1.0), (0, -6.45, 0.5), m=stone, bevel=0.05, name="step"))
    for x in (-3.15, 3.15):
        body.append(k.box((0.14, 0.7, 0.14), (x, -6.35, 6.7), m=iron, name="bracket"))
        b, g = lantern(x, -6.6, 5.6, brass, iron, glow, s=1.1)
        body += b
        lit += g
    # Sign: LAMPLIGHT over DEPOT in cream on a teal board with a brass rim.
    body.append(k.box((7.0, 0.3, 2.8), (0, -6.15, 11.3), m=board, bevel=0.06, name="sign"))
    body.append(k.tube([(-3.5, -6.32, 9.9), (3.5, -6.32, 9.9), (3.5, -6.32, 12.7), (-3.5, -6.32, 12.7), (-3.5, -6.32, 9.9)], 0.09, m=brass, n=5, name="sign_rim"))
    lit.append(text("LAMPLIGHT", 0.8, (0, -6.33, 11.95), glow))
    lit.append(text("DEPOT", 1.2, (0, -6.33, 10.6), glow))
    add(clock(frame_at(Vector((0, -6.0, 18.6)), Vector((0, -1, 0))), 2.7, brass, iron, glow))
    # Cupola: an octagonal lit lantern room with brass posts, a plum dome and a brass finial.
    body.append(k.lathe([(3.4, 22.85), (3.4, 23.3), (2.7, 23.4)], loc=(0, -2, 0), m=stone, n=8, name="cupola_base"))
    lit.append(k.lathe([(2.45, 23.3), (2.45, 26.4)], loc=(0, -2, 0), m=glow, n=8, name="cupola_glass"))
    for i in range(8):
        a = math.pi / 4 * i + math.pi / 8
        body.append(k.box((0.34, 0.34, 3.1), (2.5 * math.cos(a), -2 + 2.5 * math.sin(a), 24.85), rot=(0, 0, math.degrees(a)), m=brass, name="cupola_post"))
    body.append(k.lathe([(3.1, 26.4), (3.1, 26.8), (2.9, 26.9)], loc=(0, -2, 0), m=stone, n=8, name="cupola_cap"))
    body.append(k.lathe([(3.0, 26.8), (2.7, 27.8), (1.8, 28.8), (0.6, 29.3), (0, 29.4)], loc=(0, -2, 0), m=roof, n=16, name="cupola_dome"))
    body.append(k.capsule((0, -2, 29.2), (0, -2, 29.94), 0.14, 0.06, brass, n=10, name="spike"))
    body.append(k.sphere(0.3, (0, -2, 29.55), m=brass, seg=12, rings=6, name="ball"))

    # Platform canopy either side of the tower: plum roof on iron columns, cream scalloped valance,
    # brass lanterns under it.
    for x0, x1 in ((-19.5, -4.4), (4.4, 19.5)):
        body.append(k.surface(4, 2, lambda u, v, x0=x0, x1=x1: (x0 + (x1 - x0) * u, -5.0 - 8.75 * v, 10.0 - 1.4 * v), m=roof, thickness=0.3, name="canopy"))
        body.append(valance(x0, x1, -13.8, 8.75, 8.15, cream))
    for x in (-18, -12, -6, 6, 12, 18):
        body.append(k.lathe([(0.45, 0), (0.45, 0.4), (0.25, 0.6), (0.2, 0.8), (0.2, 7.8), (0.35, 8.1), (0.4, 8.6)], loc=(x, -13.1, 0), m=iron, n=10, name="column"))
    for x in (-15, -9, 9, 15):
        body.append(k.tube([(x, -9.5, 9.25), (x, -9.5, 8.15)], 0.05, m=iron, n=4, name="chain"))
        b, g = lantern(x, -9.5, 6.75, brass, iron, glow, s=1.4)
        body += b
        lit += g
    for s in (-1, 1):
        b, g = lamp_post(s * 25.0, -10.5, 0, 6.8, iron, brass, glow)
        body += b
        lit += g
    return {"": body, "glow": lit}


def depot_platform():
    brick = k.brick("dp_brick", lo=0, hi=2)
    # The coping carries the cream edge line as a hard band in its ramp (stops 0.005 apart).
    coping = k.paint("dp_coping", [(0, (204, 194, 184)), (0.12, (206, 196, 186)), (0.125, k.CREAM), (0.42, k.CREAM), (0.425, (214, 206, 194)), (1, (226, 218, 206))],
                     -5.0, -4.0, axis="Y", grain=(0.06, 2.0))
    boards = k.paint("dp_boards", [(0, (150, 106, 78)), (1, (150, 106, 78))], -5, 5, axis="Y", bands=((128, 88, 64), 0.85), grain=(0.1, 4, "wave"))
    stone = k.paint("dp_stone", STONE, 0, 2, grain=(0.06, 2.0))
    body = [
        k.box((40, 9.8, 1.7), (0, 0.1, 0.85), m=brick, name="body"),
        k.box((39.8, 9.0, 0.3), (0, 0.5, 1.85), m=boards, bevel=0.04, name="deck"),
        k.box((40, 1.0, 0.36), (0, -4.5, 1.82), m=coping, bevel=0.08, seg=2, name="coping"),
        k.box((40, 0.4, 0.3), (0, 4.8, 1.85), m=stone, bevel=0.05, name="back_coping"),
    ]
    for x in range(-18, 19, 6):
        body.append(k.box((1.0, 0.12, 1.3), (x, -4.96, 0.85), m=brick, name="pilaster"))
        body.append(k.box((1.1, 0.2, 0.2), (x, -4.9, 1.55), m=stone, name="pilaster_cap"))
    for s in (-1, 1):
        body.append(k.box((0.12, 9.8, 1.4), (s * 19.96, 0.1, 0.8), m=stone, name="end_quoin"))
    return body


def depot_signal():
    stone = k.paint("dsg_stone", STONE, 0, 1, grain=(0.06, 2.0))
    iron = k.paint("dsg_iron", [(0, (64, 56, 90)), (0.5, (96, 84, 126)), (1, (132, 118, 164))], 0, 12)
    brass = k.brass("dsg_brass", 0, 12)
    dark = k.paint("dsg_dark", TEAL, 9, 11)
    glow = k.flat(k.LAMP_GLOW)
    body = [
        k.box((2.0, 2.0, 0.8), (0, 0, 0.4), m=stone, bevel=0.12, seg=2, name="plinth"),
        k.lathe([(0.45, 0.8), (0.45, 1.15), (0.3, 1.35), (0.24, 9.2), (0.34, 9.3)], m=iron, n=12, name="post"),
        k.lathe([(0.27, 1.45), (0.32, 1.5), (0.27, 1.55)], m=brass, n=12, name="band"),
        k.box((1.3, 1.0, 2.7), (0, 0, 10.5), m=iron, bevel=0.32, seg=2, name="head"),
        k.sphere(0.3, (0, 0, 11.7), m=brass, seg=10, rings=5, name="ball"),
    ]
    lit = []
    for z, lens_m in ((11.0, glow), (9.95, dark)):
        F = frame_at(Vector((0, -0.5, z)), Vector((0, -1, 0)))
        lens = place(F, [k.cyl(0.38, 0.06, (0, 0, 0.02), m=lens_m, n=12, name="lens")])
        (lit if lens_m is glow else body).extend(lens)
        body += place(F, [k.ring(0.42, 0.04, 0.05, brass, n=12, sides=3, name="bezel"),
                          k.surface(6, 1, lambda u, v: (0.5 * math.cos(math.pi * u), 0.18 + 0.32 * math.sin(math.pi * u), 0.02 + 0.45 * v), m=iron, thickness=0.06, name="visor")])
    # A ladder up the back to the lamp.
    for x in (-0.28, 0.28):
        body.append(k.box((0.07, 0.07, 8.0), (x, 0.42, 5.0), m=iron, name="ladder_rail"))
    for i in range(7):
        body.append(k.box((0.56, 0.06, 0.06), (0, 0.42, 1.8 + 1.05 * i), m=iron, name="rung"))
    return {"": body, "lamp_glow": lit}


def depot_board():
    timber = k.mat("db_timber", k.TIMBER, kind="wood", scale=3, var=0.1)
    stone = k.paint("db_stone", STONE, 0, 1, grain=(0.06, 2.0))
    felt = k.paint("db_felt", [(0, (40, 48, 70)), (1, (54, 62, 88))], 1.8, 8.6, grain=(0.04, 4.0))
    roof = k.paint("db_roof", PLUM, 8.8, 10, bands=((112, 60, 102), 0.35), grain=(0.06, 1.5))
    cream = k.paint("db_cream", [(0, (240, 222, 196)), (1, k.CREAM)], 8, 9)
    brass = k.brass("db_brass", 0, 10)
    glow = k.flat(k.LAMP_GLOW)
    body = [k.box((14.6, 0.3, 6.6), (0, 0.15, 5.2), m=felt, name="panel")]
    for s in (-1, 1):
        body.append(k.box((0.7, 0.7, 9.0), (s * 7.6, 0, 4.5), m=timber, bevel=0.08, name="post"))
        body.append(k.box((0.8, 1.2, 0.5), (s * 7.58, 0, 0.25), m=stone, bevel=0.08, name="foot"))
        body.append(k.box((0.3, 0.36, 7.2), (s * 7.2, -0.1, 5.2), m=timber, bevel=0.04, name="frame_side"))
    for z in (1.75, 8.65):
        body.append(k.box((14.7, 0.36, 0.34), (0, -0.1, z), m=timber, bevel=0.04, name="frame_rail"))
    body.append(k.tube([(-7.0, -0.3, 1.95), (7.0, -0.3, 1.95), (7.0, -0.3, 8.45), (-7.0, -0.3, 8.45), (-7.0, -0.3, 1.95)], 0.05, m=brass, n=4, name="trim"))
    # Plum hood with a cream scalloped valance and two brass gooseneck lamps lighting the board.
    body.append(k.hull([(x, y, 9.0) for x in (-7.98, 7.98) for y in (-0.75, 0.75)] + [(x, 0, 10.0) for x in (-7.6, 7.6)], roof, name="hood"))
    body.append(valance(-7.9, 7.9, -0.7, 9.02, 8.75, cream, r=0.3))
    lit = []
    for x in (-4.5, 4.5):
        body.append(k.tube([(x, -0.05, 8.95), (x, -0.3, 9.05), (x, -0.4, 8.9), (x, -0.4, 8.7)], 0.05, m=brass, n=5, name="gooseneck"))
        body.append(k.lathe([(0.32, 0), (0.28, 0.08), (0.12, 0.26), (0, 0.3)], loc=(x, -0.4, 8.42), m=brass, n=12, name="shade"))
        lit.append(k.sphere(0.26, (x, -0.4, 8.42), m=glow, seg=10, rings=5, scale=(1, 1, 0.7), name="bulb"))
    return {"": body, "lamp_glow": lit}


# Dawn Station ------------------------------------------------------------------------------------


def dawn_station():
    cream = k.paint("ds_cream", [(0, (214, 200, 182)), (0.4, (240, 228, 210)), (1, (255, 246, 230))], 0, 20, grain=(0.04, 3.0))
    stone = k.paint("ds_stone", [(0, (200, 188, 172)), (1, (232, 222, 206))], 0, 20, grain=(0.06, 2.0))
    gold = k.brass("ds_gold", 14, 36)
    roof = k.paint("ds_roof", PLUM, 13, 18, bands=((112, 60, 102), 0.8), grain=(0.06, 1.5))
    door = k.paint("ds_door", TEAL, 1, 9, grain=(0.12, 5, "wave"))
    iron = k.paint("ds_iron", [(0, (64, 56, 90)), (1, (112, 100, 144))], 0, 12)
    peach = k.flat(k.HORIZON)
    glow = k.flat(k.WINDOW_GLOW)
    sun = k.flat(k.LAMP_GLOW)
    body, lit, rays = [], [], []

    def add(parts):
        b, g = parts
        body.extend(b)
        lit.extend(g)

    # Terrace on its hill, three steps up at the front.
    body.append(k.box((60, 28, 1.2), (0, 1, 0.6), m=stone, bevel=0.06, name="terrace"))
    for i in range(3):
        d, h = 2.0 - 0.66 * i, 0.4 * (i + 1)
        body.append(k.box((18 - i, d, h), (0, -13 - d / 2, h / 2), m=stone, bevel=0.04, name="step"))

    # Rotunda: cream drum, a ring of round windows in the tambour, a golden ribbed dome, a lit
    # lantern on top crowned by a brass sun.
    cy = 3.0
    body.append(k.lathe([(9.4, 1.2), (9.4, 2.0), (9.0, 2.2)], loc=(0, cy, 0), m=stone, n=48, name="drum_base"))
    body.append(k.lathe([(9.0, 2.0), (9.0, 15.0)], loc=(0, cy, 0), m=cream, n=48, name="drum"))
    body.append(k.lathe([(9.0, 14.6), (9.7, 15.0), (9.7, 15.6), (7.6, 15.8)], loc=(0, cy, 0), m=stone, n=48, name="drum_cornice"))
    body.append(k.lathe([(7.6, 15.6), (7.6, 19.2)], loc=(0, cy, 0), m=cream, n=40, name="tambour"))
    body.append(k.lathe([(7.6, 19.0), (8.0, 19.2), (8.0, 19.6), (7.6, 19.7)], loc=(0, cy, 0), m=stone, n=40, name="tambour_cornice"))
    dome = [(7.7 * math.cos(math.radians(a)), 19.6 + 10.0 * math.sin(math.radians(a))) for a in range(0, 91, 10)]
    body.append(k.lathe(dome, loc=(0, cy, 0), m=gold, n=40, name="dome"))
    for i in range(8):
        phi = math.pi / 4 * i + math.pi / 8
        pts = [(7.82 * math.cos(math.radians(a)) * math.cos(phi), cy + 7.82 * math.cos(math.radians(a)) * math.sin(phi), 19.6 + 10.1 * math.sin(math.radians(a))) for a in range(0, 81, 10)]
        body.append(k.tube(pts, 0.2, m=cream, n=4, name="rib"))
    for i in range(8):
        t = math.pi / 4 * i + math.pi / 8
        n = Vector((math.sin(t), -math.cos(t), 0))
        F = frame_at(Vector((0, cy, 17.4)) + n * 7.6, n)
        lit += place(F, [k.cyl(0.72, 0.06, (0, 0, 0.06), m=glow, n=12, name="oculus")])
        body += place(F, [k.ring(0.8, 0.08, 0.14, gold, n=12, sides=4, name="oculus_ring")])
    body.append(k.lathe([(2.3, 29.1), (2.3, 29.8)], loc=(0, cy, 0), m=gold, n=16, name="lantern_base"))
    rays.append(k.lathe([(1.75, 29.8), (1.75, 32.2)], loc=(0, cy, 0), m=sun, n=8, name="lantern_glass"))
    for i in range(8):
        a = math.pi / 4 * i + math.pi / 8
        body.append(k.box((0.3, 0.3, 2.4), (1.8 * math.cos(a), cy + 1.8 * math.sin(a), 31.0), rot=(0, 0, math.degrees(a)), m=cream, name="lantern_post"))
    body.append(k.lathe([(2.3, 32.2), (2.3, 32.6), (1.9, 32.8)], loc=(0, cy, 0), m=stone, n=16, name="lantern_cap"))
    body.append(k.lathe([(2.0, 32.7), (1.6, 33.4), (0.8, 33.9), (0, 34.0)], loc=(0, cy, 0), m=gold, n=16, name="lantern_dome"))
    body.append(k.capsule((0, cy, 33.8), (0, cy, 34.6), 0.12, 0.08, gold, n=8, name="stem"))
    disc = [k.cyl(0.55, 0.24, (0, 0, 0), m=gold, n=16, name="sun_disc"), k.star(0.85, gold, points=12, inner=0.62, depth=0.16, name="sun_rays")]
    body += place(Matrix.Translation((0, cy, 35.15)) @ Matrix.Rotation(math.radians(90), 4, "X"), disc)

    # Portico: four columns, an entablature, the rising-sun pediment (lit fan glass, brass rays).
    for x in (-7.4, -2.6, 2.6, 7.4):
        body.append(k.lathe([(0.85, 1.2), (0.85, 1.6), (0.65, 1.9), (0.6, 2.2), (0.52, 10.2)], loc=(x, -9.6, 0), m=cream, n=16, name="column"))
        body.append(k.lathe([(0.52, 10.1), (0.9, 10.6), (0.9, 11.2)], loc=(x, -9.6, 0), m=gold, n=16, name="capital"))
    body.append(k.box((18.4, 5.6, 1.4), (0, -8.4, 11.9), m=stone, bevel=0.08, name="entablature"))
    half = [(7.2 * math.cos(math.pi * i / 16), 12.6 + 7.2 * math.sin(math.pi * i / 16)) for i in range(17)]
    body.append(k.poly(half, 0.6, loc=(0, -10.9, 0), m=cream, name="pediment"))
    body.append(k.tube([(x, -11.22, z) for x, z in half], 0.26, m=gold, n=5, cap=False, name="pediment_rim"))
    fan = [(5.6 * math.cos(math.pi * i / 16), 12.7 + 5.6 * math.sin(math.pi * i / 16)) for i in range(17)]
    rays.append(k.poly(fan, 0.08, loc=(0, -11.24, 0), m=sun, name="sunrise"))
    for i in range(1, 8):
        a = math.pi * i / 8
        body.append(k.box((0.24, 0.1, 4.5), (3.45 * math.cos(a), -11.32, 12.7 + 3.45 * math.sin(a)), rot=(0, 90 - math.degrees(a), 0), m=gold, name="ray"))
    hub = [(1.3 * math.cos(math.pi * i / 10), 12.7 + 1.3 * math.sin(math.pi * i / 10)) for i in range(11)]
    body.append(k.poly(hub, 0.2, loc=(0, -11.36, 0), m=gold, name="sun_hub"))
    body.append(k.box((14.8, 0.3, 0.6), (0, -11.25, 12.85), m=gold, name="sill"))
    # Doors in the drum, under a lit fanlight, with a lantern each side.
    F = frame_at(Vector((0, cy - 9.0, 1.2)), Vector((0, -1, 0)))
    body += place(F, [k.box((4.4, 5.8, 0.2), (0, 2.9, 0.3), m=door, name="door"),
                      k.box((0.1, 5.8, 0.1), (0, 2.9, 0.42), m=gold, name="door_split"),
                      k.tube([(x, y, 0.4) for x, y in arch(5.0, 8.4)], 0.3, m=stone, n=6, cap=False, name="door_arch")])
    fl = [(2.2 * math.cos(math.pi * i / 12), 5.8 + 2.2 * math.sin(math.pi * i / 12)) for i in range(13)]
    lit += place(F, [k.poly(fl, 0.08, loc=(0, 0, 0.3), rot=(-90, 0, 0), m=glow, name="fanlight")])
    for x in (-0.55, 0.55):
        body += place(F, [k.sphere(0.15, (x, 2.9, 0.5), m=gold, seg=10, rings=6, name="knob")])

    # Wings: cream walls with pilasters and tall arched windows under hipped plum roofs.
    for s in (-1, 1):
        x0, x1 = s * 8.0, s * 24.0
        xm = (x0 + x1) / 2
        body.append(k.box((16, 16, 11.8), (xm, 2, 7.1), m=cream, name="wing"))
        body.append(k.box((16.3, 16.6, 0.6), (xm, 2, 13.0), m=stone, bevel=0.08, name="wing_cornice"))
        body.append(k.box((16.2, 16.3, 0.6), (xm, 2, 1.5), m=stone, name="wing_plinth"))
        lo, hi = min(x0, x1) - 0.2, max(x0, x1) + 0.2
        body.append(k.hull([(x, y, 13.25) for x in (lo, hi) for y in (-6.6, 10.6)] + [(x, 2, 17.6) for x in (lo + 4, hi - 4)], roof, name="wing_roof"))
        for i, x in enumerate((10.4, 13.8, 17.2, 20.6)):
            add(window(frame_at(Vector((s * x, -6.0, 3.0)), Vector((0, -1, 0))), 2.4, 6.6, gold, glow, stone))
            body.append(k.box((0.7, 0.3, 11.2), (s * (x - 1.7), -6.1, 7.2), m=stone, name="pilaster"))
        for x in (12.0, 20.0):
            add(window(frame_at(Vector((s * x, 10.0, 3.0)), Vector((0, 1, 0))), 2.4, 6.6, gold, glow, stone))
        # End pavilions with little golden domes and peach pennants.
        px = s * 27.0
        body.append(k.box((6, 18, 14.6), (px, 2, 8.5), m=cream, name="pavilion"))
        body.append(k.box((6.4, 18.4, 0.6), (px, 2, 15.8), m=stone, bevel=0.08, name="pavilion_cornice"))
        body.append(k.lathe([(2.9, 16.0), (2.9, 16.4)], loc=(px, 2, 0), m=stone, n=24, name="dome_drum"))
        body.append(k.lathe([(2.8, 16.3), (2.7, 17.5), (2.2, 18.7), (1.2, 19.6), (0, 19.9)], loc=(px, 2, 0), m=gold, n=24, name="small_dome"))
        body.append(k.capsule((px, 2, 19.7), (px, 2, 23.6), 0.08, 0.08, gold, n=6, name="flagpole"))
        body.append(k.poly([(0, 0), (s * 2.2, -0.45), (0, -0.9)], 0.06, loc=(px + s * 0.06, 2, 23.5), m=peach, name="pennant"))
        add(window(frame_at(Vector((px, -7.0, 3.2)), Vector((0, -1, 0))), 3.2, 8.4, gold, glow, stone))
        b, g = lamp_post(s * 12.0, -11.5, 1.2, 6.6, iron, gold, glow)
        body += b
        lit += g
        F = frame_at(Vector((s * 3.4, cy - math.sqrt(81 - 3.4 * 3.4), 6.2)), Vector((0, -1, 0)))
        body += place(F, [k.box((0.14, 0.14, 0.9), (0, 0.5, 0.45), m=iron, name="bracket")])
        b, g = lantern(s * 3.4, cy - math.sqrt(81 - 3.4 * 3.4) - 0.9, 5.2, gold, iron, glow, s=1.1)
        body += b
        lit += g
    return {"": body, "glow": lit, "sun_glow": rays}


# Track and scatter ---------------------------------------------------------------------------------


def rail_32():
    """32 studs of track along y: a gravel bed, 16 sleepers 2 apart (they tile across seams), two
    rails 6 apart centre to centre (the cars' wheels run at x = +-3) whose tops are the top of the
    asset, 1 stud up."""
    gravel = k.paint("rl_gravel", [(0, (84, 78, 92)), (1, (118, 110, 124))], 0, 0.5, grain=(0.12, 6.0), dots=[((148, 140, 152), 7, 0.12), ((66, 60, 74), 5, 0.1)])
    sleeper = k.paint("rl_sleeper", [(0, (88, 62, 54)), (1, (116, 84, 68))], 0.4, 0.7, grain=(0.12, 4, "wave"))
    steel = k.paint("rl_steel", [(0, (64, 56, 90)), (0.7, (104, 94, 130)), (1, (176, 168, 198))], 0.65, 1.0)
    body = [k.hull([(x, y, 0) for x in (-4, 4) for y in (-16, 16)] + [(x, y, 0.5) for x in (-3.1, 3.1) for y in (-16, 16)], gravel, name="ballast")]
    for i in range(16):
        body.append(k.box((7.2, 0.8, 0.26), (0, -15 + 2 * i, 0.55), m=sleeper, name="sleeper"))
    profile = [(-0.17, 0.66), (0.17, 0.66), (0.17, 0.71), (0.05, 0.75), (0.05, 0.87), (0.12, 0.9), (0.12, 1.0), (-0.12, 1.0), (-0.12, 0.9), (-0.05, 0.87), (-0.05, 0.75), (-0.17, 0.71)]
    for x in (-3.0, 3.0):
        body.append(k.poly(profile, 32.0, loc=(x, 0, 0), m=steel, name="rail"))
    return body


def decor_pine():
    bark = k.paint("pn_bark", [(0, (78, 56, 56)), (1, (112, 80, 72))], 0, 7, grain=(0.12, 4, "wave"))
    needles = k.paint("pn_needles", [(0, (30, 62, 64)), (0.5, (46, 92, 86)), (1, (84, 134, 114))], 3, 28, grain=(0.07, 2.5))
    body = [k.lathe([(0.95, 0), (0.75, 0.5), (0.6, 1.3), (0.5, 7.0)], m=bark, n=12, name="trunk")]
    for z0, z1, r0, r1, tongues in ((3.8, 10.4, 4.82, 1.4, 10), (8.4, 14.6, 4.2, 1.1, 9), (12.6, 18.6, 3.4, 0.8, 8), (16.6, 22.6, 2.6, 0.55, 7), (20.6, 27.4, 1.9, 0.2, 6)):
        def fn(u, v, z0=z0, z1=z1, r0=r0, r1=r1, tongues=tongues):
            a = 2 * math.pi * u
            r = r0 + (r1 - r0) * v ** 0.75
            drop = 0.45 * (1 - v) ** 3 * abs(math.sin(tongues * a / 2)) ** 0.6
            return (r * math.cos(a), r * math.sin(a), z0 + (z1 - z0) * v - drop)

        body.append(k.surface(tongues * 4, 2, fn, m=needles, thickness=0.4, name="tier"))
    body.append(k.sphere(0.42, (0, 0, 27.55), m=needles, seg=10, rings=6, name="tip"))
    return body


def decor_birch():
    spots = [((70, 60, 78), (0.55 * math.cos(a) + 0.03 * z, 0.55 * math.sin(a) + 0.02 * z, z), 0, 0.2)
             for z, a in ((1.6, 0.4), (2.9, 2.6), (4.1, 4.9), (5.2, 1.3), (6.6, 3.6), (7.8, 5.6), (9.0, 0.9), (10.2, 2.9), (11.3, 4.4))]
    bark = k.paint("bh_bark", [(0, (214, 202, 186)), (1, (250, 242, 226))], 0, 14, grain=(0.05, 3.0), marks=spots)
    leaves = k.paint("bh_leaves", [(0, (56, 94, 86)), (0.5, (90, 132, 110)), (1, (146, 178, 136))], 8, 22, grain=(0.07, 2.0))
    trunk = [(0, 0, 0), (0.05, 0.02, 3), (0.2, 0.08, 7), (0.3, 0.12, 11), (0.4, 0.16, 15)]
    body = [k.tube(trunk, [0.78, 0.62, 0.5, 0.4, 0.3], m=bark, n=10, name="trunk")]
    body.append(k.tube([(0.2, 0.08, 7.5), (-1.4, 0.5, 9.6), (-2.0, 0.7, 11.0)], [0.22, 0.14, 0.09], m=bark, n=6, name="branch"))
    body.append(k.tube([(0.25, 0.1, 8.5), (1.6, -0.5, 10.6), (2.1, -0.8, 12.0)], [0.2, 0.13, 0.08], m=bark, n=6, name="branch"))
    for i, (x, y, z, r) in enumerate(((0.25, 0.1, 13.6, 3.35), (-1.9, 0.9, 11.6, 2.15), (1.9, -0.9, 12.2, 2.15), (-0.4, 1.3, 17.2, 2.8), (0.8, -1.22, 17.0, 2.6), (0.2, 0.0, 19.6, 2.3))):
        puff = k.ico(r, (x, y, z), m=leaves, subdiv=3, scale=(1, 1, 0.86), name="puff")
        k.displace(puff, 0.35, size=1.1, seed=i + 1)
        body.append(puff)
    return body


def decor_rock():
    stone = k.paint("rk_stone", [(0, (88, 82, 102)), (1, (148, 140, 160))], 0, 4, grain=(0.08, 2.0), splat=[((80, 116, 92), 0.7, 0.46, 2.9, 9)])
    body = []
    for i, (r, loc, scale, sub) in enumerate(((2.3, (0.6, 0.4, 1.7), (1.3, 1.2, 1.0), 3), (1.6, (-2.4, -0.7, 0.9), (1.05, 1.1, 0.9), 3), (0.85, (3.0, -1.9, 0.3), (1.0, 1.0, 0.8), 2))):
        rock = k.ico(r, loc, m=stone, scale=scale, subdiv=sub, name="rock")
        k.displace(rock, 0.32 * r, size=0.7, seed=i + 2)
        k._select([rock])
        bpy.ops.object.convert(target="MESH")
        for v in rock.data.vertices:  # flat underside: it sits on the terrain, not on a point
            v.co.z = max(v.co.z, 0.0)
        body.append(rock)
    return body


ASSETS = [
    dict(name="depot_hub", build=depot_hub, budget=15000, finalize=k.HD, size=[60, 30, 24], priority=1, order=30,
         replaces="depot fallback (blocks)",
         notes=("Lamplight Depot, 60 x 30 x 24, ground at y = 0, front (the platform canopy) -Z. Red brick hall under a plum barrel roof, round pavilions with "
                "scalloped plum domes at both ends, a clock tower (lit clock 18.6 up, LAMPLIGHT DEPOT sign, teal doors at ground level in its middle, "
                "lit cupola, finial 30 up); the tower front and clock face are 4.1 in front of the origin. The canopy runs from the hall front (3.1 in front of the origin) to 12 in front, eaves 8.6 up, on iron columns on a line 11.2 in front. "
                "Two meshes: depot_hub and depot_hub_glow (Neon: windows front and back, the fanlight, clock face, cupola glass, six lanterns and two lamp posts). "
                "CanCollide false; collide with invisible parts: the hall, tower and pavilion boxes."),
         glow={"glow": k.WINDOW_GLOW}),
    dict(name="depot_platform", build=depot_platform, budget=1500, finalize=k.HD, size=[40, 2, 10], priority=1, order=31,
         replaces="platform fallback (block)",
         notes="Platform, 40 x 2 x 10: brick body, plank deck 2.0 up, stone coping with the cream edge line along the track side (-Z). One mesh. Collide with one box.",
         glow={}),
    dict(name="depot_signal", build=depot_signal, budget=1000, finalize=k.HD, size=[2, 12, 2], priority=1, order=32,
         replaces="signal fallback (cylinder and ball)",
         notes=("Signal post, 2 x 12 x 2: stone plinth, iron post, a lamp head facing -Z (upper lens lit, lower dark teal), brass ball on top, a ladder at the back. "
                "Two meshes: depot_signal and depot_signal_lamp_glow (Neon: the upper lens, 11 up)."),
         glow={"lamp_glow": k.LAMP_GLOW}),
    dict(name="depot_board", build=depot_board, budget=1500, finalize=k.HD, size=[16, 10, 1.5], priority=1, order=33,
         replaces="board fallback (block frame)",
         notes=("Notice board, 16 x 10 x 1.5: timber posts, a dark felt panel 14.6 wide and 6.6 tall centred 5.2 up, its face on the middle plane, framed 0.3 proud "
                "(put the SurfaceGui part just in front, about 14 x 6.4), a plum hood with a cream valance, two gooseneck lamps. Two meshes: depot_board and "
                "depot_board_lamp_glow (Neon: the two bulbs)."),
         glow={"lamp_glow": k.LAMP_GLOW}),
    dict(name="dawn_station", build=dawn_station, budget=15000, finalize=k.HD, size=[60, 36, 30], priority=1, order=34,
         replaces="Dawn Station fallback (blocks)",
         notes=("Dawn Station, 60 x 36 x 30, ground at y = 0, front -Z: a cream stone station on a terrace 1.2 high (steps at the front middle), a rotunda "
                "under a golden ribbed dome and a lit lantern crowned by a brass sun (36 up), a portico whose pediment is a rising-sun window, cream wings "
                "with plum roofs and end pavilions with golden domes and peach pennants. Three meshes: dawn_station, dawn_station_glow (Neon window glow: "
                "windows, oculi, fanlight, lanterns, lamp posts) and dawn_station_sun_glow (Neon lamp glow: the rising-sun fan and the lantern room)."),
         glow={"glow": k.WINDOW_GLOW, "sun_glow": k.LAMP_GLOW}),
    dict(name="rail_32", build=rail_32, budget=600, finalize=k.HD, size=[8, 1, 32], priority=1, order=35,
         replaces="rail fallback (two thin parts)",
         notes=("Track section, 32 x 1 x 8, along z. Rail tops are the top of the asset, 1 up from its base: put the base 1 below the train's rail-top line. "
                "Rails 6 apart centre to centre (the wheels at x +-3); 16 sleepers 2 apart, so sections tile seamlessly every 32. One mesh."),
         glow={}),
    dict(name="decor_pine", build=decor_pine, budget=3000, finalize=k.HD, size=[10, 28, 10], priority=2, order=36,
         replaces="pine fallback (cone and cylinder)",
         notes="Toy pine, 10 x 28 x 10: five scalloped dusk-teal tiers on a plum-brown trunk. One mesh, origin at the trunk foot.", glow={}),
    dict(name="decor_birch", build=decor_birch, budget=3000, finalize=k.HD, size=[8, 22, 8], priority=2, order=37,
         replaces="birch fallback (cone and cylinder)",
         notes="Toy birch, 8 x 22 x 8: cream spotted trunk, six soft sage leaf puffs. One mesh.", glow={}),
    dict(name="decor_rock", build=decor_rock, budget=800, finalize=k.HD, size=[8, 4, 6], priority=2, order=38,
         replaces="rock fallback (ball)",
         notes="Rock cluster, 8 x 4 x 6: three rounded plum-grey boulders with moss on top, flat underneath. One mesh.", glow={}),
]
