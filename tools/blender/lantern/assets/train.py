"""The Lantern Express engine: a chunky toy steam engine and its tender, a tall flared chimney, a
big brass headlamp and an open cab lit by the firebox (docs/game-design/game6-art-bible.md sections
4 and 6; docs/architecture/lantern.md section 9: 22 x 11 x 8 with tender and open cab, 12,000
tris). Built at stud scale, front -Y, wheels on z = 0 (the rail top). Three meshes: the textured
body and two Neon glow meshes (`Models.luau` leaves `_glow` meshes untextured)."""

import math

import kit as k
from mathutils import Matrix, Vector

FOOT = 2.3  # footplate top = the cab floor
HALF = 4.0  # half the width: the cars are 8 wide
BOILER_R, BOILER_Z = 1.85, 4.0
WHEEL_X = 3.0  # wheel centre plane


def wheel(x, y, r, side, name):
    """Toy wheel standing on z = 0: red disc, brass ring and hub, iron tyre: one lathe painted in
    rings round the centre of its outer disc face (side +1 faces +X)."""
    t = r / 1.5
    c = (x + side * 0.22 * t, y, r)  # the outer disc face's centre
    m = k.paint(f"wheel_{name}", [(0, k.CRANBERRY_DEEP), (1, k.CRANBERRY)], 0, 2 * r,
                marks=[(k.IRON, c, r * 0.84, r * 3), ((236, 184, 84), c, r * 0.72, r * 0.84), ((240, 190, 92), c, 0, r * 0.27), (k.IRON, c, 0, r * 0.1)])
    profile = [(0, -0.36 * t), (r, -0.36 * t), (r, 0.24 * t), (r * 0.95, 0.32 * t), (r * 0.84, 0.32 * t),
               (r * 0.8, 0.22 * t), (r * 0.3, 0.22 * t), (r * 0.25, 0.38 * t), (0, 0.44 * t)]
    return k.lathe(profile, loc=(x, y, r), rot=(0, 90 * side, 0), m=m, n=24 if r > 1.2 else 16, name="wheel")


def splasher(y, zc, r, side, m):
    """The rounded wheel arch on the footplate: the part of a disc of radius r round the wheel's
    centre (y, zc) that stands above the footplate, 0.9 thick."""
    top = FOOT - 0.05
    a0 = math.asin(max(-1.0, min(1.0, (top - zc) / r)))
    pts = [(r * math.cos(a), zc + r * math.sin(a)) for a in (a0 + (math.pi - 2 * a0) * i / 14 for i in range(15))]
    return k.poly(pts, 0.9, loc=(side * WHEEL_X, y, 0), rot=(0, 0, 90), m=m, name="splasher")


def ring_at(r, thick, m, loc, n=24, sides=6, name="ring"):
    """A ring facing -Y (a bezel or window frame on a front face)."""
    ob = k.ring(r, 0, thick, m, n=n, sides=sides, name=name)
    ob.data.transform(Matrix.Translation(loc) @ Matrix.Rotation(math.radians(90), 4, "X"))
    return ob


def train_engine():
    red = k.paint("te_red", [(0, k.CRANBERRY_DEEP), (0.5, k.CRANBERRY), (1, (222, 76, 80))], 1.0, 8.5)
    deep = k.paint("te_deep", [(0, (120, 30, 46)), (1, k.CRANBERRY_DEEP)], 0.0, FOOT)
    iron = k.paint("te_iron", [(0, (64, 56, 90)), (0.5, (96, 84, 126)), (1, (132, 118, 164))], 0.0, 11.0)
    roof = k.paint("te_roof", [(0, (62, 50, 88)), (1, (98, 80, 128))], 8.0, 8.9)
    coal = k.paint("te_coal", [(0, (40, 34, 52)), (1, (62, 54, 78))], 5.0, 6.6, dots=[((112, 100, 132), 3.5, 0.12)])
    brass = k.brass("te_brass", 0.0, 11.0)
    lamp_brass = k.brass("te_lamp", 5.5, 8.6)
    body, lamp, fire = [], [], []

    # Running gear: three big driving wheels, cylinders, side rods; three small tender wheels.
    drive_y = (-5.5, -2.6, 0.3)
    for side in (-1, 1):
        for i, y in enumerate(drive_y):
            body.append(wheel(side * WHEEL_X, y, 1.3, side, f"d{i}{side}"))
            body.append(splasher(y, 1.3, 1.42, side, red))
            body.append(k.cyl(0.12, 0.3, (side * (WHEEL_X + 0.4), y, 1.3 - 0.54), rot=(0, 90, 0), m=brass, n=8, name="crank"))
        body.append(k.box((0.14, 6.4, 0.3), (side * (WHEEL_X + 0.55), -2.6, 1.3 - 0.54), m=brass, bevel=0.05, name="rod"))
        for i, y in enumerate((6.1, 7.8, 9.5)):
            body.append(wheel(side * WHEEL_X, y, 0.8, side, f"t{i}{side}"))
        body.append(k.lathe([(0.7, 0), (0.74, 0.1), (0.74, 2.0), (0.7, 2.1)], loc=(side * 3.25, -9.0, 1.05), rot=(-90, 0, 0), m=red, n=16, name="cylinder"))
        for yy in (-8.95, -6.95):
            body.append(k.cyl(0.78, 0.16, (side * 3.25, yy, 1.05), rot=(90, 0, 0), m=brass, n=16, name="cyl_band"))
    body.append(k.box((2.8, 14.0, 1.1), (0, -2.6, 1.3), m=iron, name="frame"))
    body.append(k.box((2.8, 5.2, 0.9), (0, 7.8, 1.2), m=iron, name="tender_frame"))

    # Footplates, buffer beams, buffers, cowcatcher, drawbar and fall plate.
    body.append(k.box((2 * HALF, 14.6, 0.45), (0, -2.5, FOOT - 0.225), m=deep, bevel=0.12, seg=2, name="footplate"))
    body.append(k.box((2 * HALF - 0.2, 5.6, 0.45), (0, 7.8, FOOT - 0.225), m=deep, bevel=0.12, seg=2, name="tender_plate"))
    body.append(k.box((2.6, 0.9, 0.12), (0, 4.95, FOOT - 0.06), m=iron, name="fall_plate"))
    for side in (-1, 1):
        body.append(k.box((0.1, 14.4, 0.14), (side * (HALF + 0.02), -2.5, FOOT - 0.28), m=brass, name="trim"))
    for y, s in ((-10.05, -1), (10.25, 1)):
        body.append(k.box((2 * HALF, 0.6, 1.1), (0, y, 1.75), m=red, bevel=0.1, seg=2, name="beam"))
        for side in (-1, 1):
            body.append(k.cyl(0.2, 0.5, (side * 2.6, y + s * 0.45, 1.75), rot=(90, 0, 0), m=iron, n=10, name="buffer"))
            body.append(k.lathe([(0, 0), (0.44, 0), (0.48, 0.08), (0.44, 0.18), (0.25, 0.22), (0, 0.23)], loc=(side * 2.6, y + s * 0.6, 1.75), rot=(-90 * s, 0, 0), m=brass, n=14, name="buffer_head"))
    pilot = k.paint("te_pilot", [(0, k.CRANBERRY), (1, k.CRANBERRY)], -4, 4, axis="X", bands=((240, 190, 92), 0.6))
    body.append(k.hull([(x, -10.3, z) for x in (-3.5, 3.5) for z in (0.2, 1.25)] + [(0, -11.2, 0.2), (0, -10.6, 1.25), (-0.8, -11.0, 0.2), (0.8, -11.0, 0.2)], pilot, name="cowcatcher"))

    # Boiler: red barrel with brass bands, iron smokebox, domed door with a brass ring (no plate: with
    # the handle it read as a face, and the train has none).
    body.append(k.cyl(BOILER_R, 8.6, (0, -2.9, BOILER_Z), rot=(90, 0, 0), m=red, n=32, name="boiler"))
    body.append(k.cyl(BOILER_R + 0.07, 2.0, (0, -8.0, BOILER_Z), rot=(90, 0, 0), m=iron, n=32, name="smokebox"))
    for y in (-6.7, -3.7, -0.7):
        body.append(k.cyl(BOILER_R + 0.05, 0.26, (0, y, BOILER_Z), rot=(90, 0, 0), m=brass, n=32, name="band"))
    body.append(k.lathe([(1.5, 0), (1.5, 0.1), (1.26, 0.3), (0.8, 0.44), (0, 0.5)], loc=(0, -8.96, BOILER_Z), rot=(90, 0, 0), m=iron, n=28, name="door"))
    body.append(ring_at(1.55, 0.11, brass, (0, -9.0, BOILER_Z), n=28, name="door_ring"))
    body.append(k.sphere(0.17, (0, -9.48, BOILER_Z), m=brass, seg=12, rings=6, name="handle"))
    body.append(k.box((3.0, 1.8, 1.4), (0, -8.0, 2.6), m=iron, name="saddle"))

    # Tall flared chimney with a brass crown (its top, 11 up, is where smoke spawns), steam dome,
    # whistle, handrails.
    top = BOILER_Z + BOILER_R - 0.25
    body.append(k.lathe([(0.62, 0), (0.47, 0.6), (0.45, 2.6), (0.6, 3.6), (0.96, 4.5), (1.08, 5.0)], loc=(0, -5.5, top), m=iron, n=24, name="chimney"))
    body.append(k.lathe([(1.06, 4.92), (1.2, 5.02), (1.2, 5.25), (1.06, 5.38), (0.8, 5.38), (0.74, 5.1), (0, 5.05)], loc=(0, -5.5, top), m=brass, n=24, name="crown"))
    body.append(k.lathe([(0.85, 0), (0.8, 0.4), (0.68, 0.72), (0.44, 0.92), (0, 1.0)], loc=(0, -2.1, top), m=brass, n=24, name="dome"))
    body.append(k.lathe([(0.18, 0), (0.15, 0.45), (0.22, 0.55), (0.22, 0.8), (0.08, 0.9), (0, 0.92)], loc=(0, 0.4, top + 0.05), m=brass, n=12, name="whistle"))
    for side in (-1, 1):
        x = side * (BOILER_R + 0.24)
        body.append(k.tube([(x, -6.6, 4.9), (x, 0.8, 4.9)], 0.06, m=brass, n=6, name="handrail"))
        for y in (-5.9, -2.6, 0.4):
            body.append(k.cyl(0.045, 0.34, (side * (BOILER_R + 0.1), y, 4.9), rot=(0, 90, 0), m=brass, n=6, name="stanchion"))

    # The big brass headlamp, set into the smokebox top: lens and side panes are the lamp glow.
    lz, ly = 6.45, -8.25  # lamp body centre height and depth
    body.append(k.box((2.2, 1.5, 1.8), (0, ly, lz), m=lamp_brass, bevel=0.22, seg=2, name="lamp_body"))
    body.append(k.hull([(x * 1.28, ly + y * 0.92, lz + 0.86) for x in (-1, 1) for y in (-1, 1)] + [(x * 0.45, ly + y * 0.38, lz + 1.38) for x in (-1, 1) for y in (-1, 1)], iron, name="lamp_roof"))
    body.append(k.cyl(0.24, 0.26, (0, ly, lz + 1.48), m=iron, n=10, name="lamp_vent"))
    body.append(k.sphere(0.19, (0, ly, lz + 1.72), m=lamp_brass, seg=12, rings=6, name="finial"))
    body.append(ring_at(0.84, 0.13, lamp_brass, (0, ly - 0.8, lz), n=28, name="bezel"))
    lamp.append(k.cyl(0.78, 0.14, (0, ly - 0.78, lz), rot=(90, 0, 0), m=k.flat(k.LAMP_GLOW), n=28, name="lens"))
    for side in (-1, 1):
        lamp.append(k.box((0.06, 0.75, 0.9), (side * 1.12, ly, lz), m=k.flat(k.LAMP_GLOW), name="pane"))

    # Open cab: an arched front with round spectacles, waist-high sides with big open windows, open
    # at the back to the tender. Inside, the firebox door glows on the backhead.
    y0, y1, z1 = 1.0, 4.6, 8.2
    end = [(-3.6, FOOT), (3.6, FOOT)] + [(3.6 - 7.2 * i / 14, z1 + 0.45 * math.sin(math.pi * (0.04 + 0.92 * i / 14))) for i in range(15)]
    body.append(k.poly(end, 0.4, loc=(0, y0 + 0.2, 0), m=red, name="cab_front"))
    for side in (-1, 1):
        x = side * 3.4
        body.append(k.box((0.4, y1 - y0, 4.6 - FOOT), (x, (y0 + y1) / 2, (FOOT + 4.6) / 2), m=red, bevel=0.08, name="cab_side"))
        body.append(k.box((0.4, 0.6, z1 - 4.6), (x, y0 + 0.3, (4.6 + z1) / 2), m=red, bevel=0.06, name="cab_post"))
        body.append(k.box((0.4, 0.5, z1 - 4.6), (x, y1 - 0.25, (4.6 + z1) / 2), m=red, bevel=0.06, name="cab_post"))
        body.append(k.box((0.5, y1 - y0 + 0.1, 0.18), (x, (y0 + y1) / 2, 4.6), m=brass, name="sill"))
        body.append(k.tube([(x + side * 0.05, y0 + 0.75, 4.75), (x + side * 0.05, y0 + 0.75, 7.9)], 0.05, m=brass, n=6, name="grab"))
        sx = side * 2.35
        body.append(ring_at(0.5, 0.09, brass, (sx, y0 - 0.04, 6.9), n=20, sides=5, name="spectacle"))
        fire.append(k.cyl(0.45, 0.08, (sx, y0 - 0.02, 6.9), rot=(90, 0, 0), m=k.flat(k.FIRE_GLOW), n=20, name="spectacle_glow"))
        c = Vector((side * 3.62, 2.8, 3.45))
        nameplate = k.paint(f"te_plate{side}", [(0, (236, 184, 84)), (1, (236, 184, 84))], 0, 1, marks=[(k.CREAM, c, 0, 0.5), (k.AMBER, c, 0, 0.2)])
        body.append(k.sphere(0.72, c, m=nameplate, scale=(0.09, 1.25, 0.72), seg=16, rings=6, name="plate"))
    body.append(k.lathe([(1.15, 0), (1.15, 0.12), (0, 0.12)], loc=(0, y0 + 0.4, 3.75), rot=(-90, 0, 0), m=iron, n=20, name="fire_frame"))
    fire.append(k.cyl(0.8, 0.06, (0, y0 + 0.55, 3.75), rot=(90, 0, 0), m=k.flat(k.FIRE_GLOW), n=20, name="fire_door"))
    body.append(k.surface(14, 1, lambda u, v: (-3.95 + 7.9 * u, y0 - 0.35 + (y1 - y0 + 0.8) * v, z1 - 0.05 + 0.45 * math.sin(math.pi * u)), m=roof, thickness=0.25, name="cab_roof"))

    # Firebox under the cab: glowing grate slots between the driving and tender wheels.
    body.append(k.box((3.6, 2.2, 1.1), (0, 2.7, 1.3), m=iron, bevel=0.08, name="firebox"))
    for side in (-1, 1):
        for y in (2.05, 2.7, 3.35):
            fire.append(k.box((0.06, 0.36, 0.66), (side * 1.82, y, 1.3), m=k.flat(k.FIRE_GLOW), name="grate"))

    # Tender: a red tank with brass trim, a heaped coal load, a tail lamp at the back.
    body.append(k.box((7.2, 5.0, 3.0), (0, 7.8, FOOT + 1.5), m=red, bevel=0.25, seg=2, name="tank"))
    for z in (FOOT + 0.35, FOOT + 2.75):
        body.append(k.box((7.32, 5.12, 0.16), (0, 7.8, z), m=brass, name="tank_band"))
    heap = k.ico(2.4, (0, 7.7, FOOT + 3.0), m=coal, scale=(1.35, 0.95, 0.42), subdiv=3, name="coal")
    k.displace(heap, 0.35, size=0.5, seed=3)
    body.append(heap)
    body.append(k.box((0.7, 0.5, 0.12), (2.6, 10.25, FOOT + 3.06), m=brass, name="tail_lamp_base"))
    body.append(k.hull([(2.6 + x * 0.32, 10.25 + y * 0.28, FOOT + 3.62) for x in (-1, 1) for y in (-1, 1)] + [(2.6, 10.25, FOOT + 3.9)], iron, name="tail_lamp_roof"))
    lamp.append(k.box((0.5, 0.42, 0.5), (2.6, 10.25, FOOT + 3.37), m=k.flat(k.LAMP_GLOW), name="tail_lamp"))
    body.append(k.box((0.5, 0.5, 0.35), (0, 10.6, 1.75), m=iron, bevel=0.06, name="coupling"))
    return {"": body, "lamp_glow": lamp, "fire_glow": fire}


# Cars: the engine's livery (red gradient, deep red deck, plum iron, brass), the same deck height,
# buffer beams, buffers and coupling height, so the train reads as one toy set. ------------------


def livery(p):
    """The engine's materials under a per-car prefix (a livery swap re-bakes the same names)."""
    return dict(
        red=k.paint(f"{p}_red", [(0, k.CRANBERRY_DEEP), (0.5, k.CRANBERRY), (1, (222, 76, 80))], 1.0, 8.5),
        planks=k.paint(f"{p}_planks", [(0, k.CRANBERRY_DEEP), (0.5, k.CRANBERRY), (1, (222, 76, 80))], 1.0, 8.5, bands=((176, 46, 58), 0.7)),
        deep=k.paint(f"{p}_deep", [(0, (120, 30, 46)), (1, k.CRANBERRY_DEEP)], 0.0, FOOT),
        iron=k.paint(f"{p}_iron", [(0, (64, 56, 90)), (0.5, (96, 84, 126)), (1, (132, 118, 164))], 0.0, 11.0),
        roof=k.paint(f"{p}_roof", [(0, (62, 50, 88)), (1, (98, 80, 128))], 8.0, 9.6),
        brass=k.brass(f"{p}_brass", 0.0, 10.0),
        boards=k.paint(f"{p}_boards", [(0, (150, 106, 78)), (1, (150, 106, 78))], -4, 4, axis="X", bands=((128, 88, 64), 0.8), grain=(0.1, 4, "wave")),
        timber=k.mat(f"{p}_timber", k.TIMBER, kind="wood", scale=3, var=0.1),
        coal=k.paint(f"{p}_coal", [(0, (40, 34, 52)), (1, (62, 54, 78))], 4.5, 6.4, dots=[((112, 100, 132), 3.5, 0.12)]),
    )


def nameplate(side, y, z, p, x):
    """The engine's oval brass plate with the cream and amber lantern roundel, on a car side at x."""
    c = Vector((side * x, y, z))
    plate = k.paint(f"{p}_plate{side}", [(0, (236, 184, 84)), (1, (236, 184, 84))], 0, 1, marks=[(k.CREAM, c, 0, 0.5), (k.AMBER, c, 0, 0.2)])
    return k.sphere(0.72, c, m=plate, scale=(0.09, 1.25, 0.72), seg=16, rings=6, name="plate")


def lantern(x, y, z, m, lamp, s=1.0):
    """A hanging six-sided lantern, its base at z: brass foot, glowing glass (lamp glow), brass
    corner bars, plum-iron roof and a ring. Returns (body, glow)."""
    body = [k.lathe([(0.2 * s, 0), (0.32 * s, 0.05 * s), (0.32 * s, 0.14 * s)], loc=(x, y, z), m=m["brass"], n=6, name="lantern_foot")]
    glow = [k.lathe([(0.27 * s, 0.12 * s), (0.31 * s, 0.4 * s), (0.27 * s, 0.68 * s)], loc=(x, y, z), m=lamp, n=6, name="lantern_glass")]
    for i in range(6):
        a = math.pi / 3 * i
        body.append(k.box((0.06 * s, 0.06 * s, 0.6 * s), (x + 0.31 * s * math.cos(a), y + 0.31 * s * math.sin(a), z + 0.4 * s), rot=(0, 0, math.degrees(a)), m=m["brass"], name="lantern_bar"))
    body.append(k.lathe([(0.4 * s, 0.66 * s), (0.36 * s, 0.76 * s), (0.14 * s, 0.98 * s), (0, 1.02 * s)], loc=(x, y, z), m=m["iron"], n=6, name="lantern_roof"))
    body.append(k.ring(0.1 * s, 0, 0.03 * s, m["brass"], n=8, sides=4, name="lantern_ring"))
    body[-1].data.transform(Matrix.Translation((x, y, z + 1.1 * s)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    return body, glow


def car_base(L, m, axles, r=0.9):
    """Deck (top at FOOT), buffer beams, buffers and couplings at both ends (the engine's height and
    spacing: buffers 2.6 off centre, 1.75 up; buffer heads end exactly at +-L/2, so the cars meet
    the train's 2-stud gaps like the tender does), wheels with brass axleboxes and leaf springs."""
    beam = L / 2 - 0.83
    body = [k.box((2 * HALF, 2 * beam - 0.5, 0.45), (0, 0, FOOT - 0.225), m=m["deep"], bevel=0.12, seg=2, name="deck")]
    for side in (-1, 1):
        body.append(k.box((0.08, 2 * beam - 0.9, 0.14), (side * (HALF - 0.0), 0, FOOT - 0.28), m=m["brass"], name="trim"))
    for s in (-1, 1):
        y = s * beam
        body.append(k.box((2 * HALF, 0.6, 1.1), (0, y, 1.75), m=m["red"], bevel=0.1, seg=2, name="beam"))
        for side in (-1, 1):
            body.append(k.cyl(0.2, 0.5, (side * 2.6, y + s * 0.45, 1.75), rot=(90, 0, 0), m=m["iron"], n=10, name="buffer"))
            body.append(k.lathe([(0, 0), (0.44, 0), (0.48, 0.08), (0.44, 0.18), (0.25, 0.22), (0, 0.23)], loc=(side * 2.6, y + s * 0.6, 1.75), rot=(-90 * s, 0, 0), m=m["brass"], n=14, name="buffer_head"))
        body.append(k.box((0.5, 0.5, 0.35), (0, y + s * 0.35, 1.75), m=m["iron"], bevel=0.06, name="coupling"))
        body.append(k.ring(0.2, 1.75, 0.05, m["iron"], n=8, sides=4, centre=(0, y + s * 0.55), name="link"))
    for ay in axles:
        for side in (-1, 1):
            body.append(wheel(side * WHEEL_X, ay, r, side, f"{ay}{side}"))
            x = side * 3.45
            body.append(k.box((0.24, 0.6, 0.62), (x, ay, r), m=m["brass"], bevel=0.06, name="axlebox"))
            body.append(k.box((0.16, 0.24, FOOT - 0.45 - r), (x, ay, (FOOT - 0.45 + r) / 2), m=m["iron"], name="hanger"))
            body.append(k.tube([(x, ay - 1.1, FOOT - 0.5), (x, ay - 0.5, FOOT - 0.72), (x, ay, FOOT - 0.78), (x, ay + 0.5, FOOT - 0.72), (x, ay + 1.1, FOOT - 0.5)], 0.08, m=m["iron"], n=6, name="spring"))
        body.append(k.box((2 * WHEEL_X - 0.6, 0.6, 0.5), (0, ay, FOOT - 0.6), m=m["iron"], name="frame"))
    return body


def train_car_cargo():
    m = livery("tc")
    lamp_m = k.flat(k.LAMP_GLOW)
    body, lamp = car_base(16, m, (-4.6, 4.6)), []

    # Coal bunker (front half): a red planked bin with brass bands and iron corners, heaped with coal.
    bc, bl, bh = -3.95, 6.6, 2.9
    body.append(k.box((7.5, bl, bh), (0, bc, FOOT + bh / 2), m=m["planks"], bevel=0.22, seg=2, name="bunker"))
    for z in (FOOT + 0.3, FOOT + bh - 0.25):
        body.append(k.box((7.62, bl + 0.12, 0.16), (0, bc, z), m=m["brass"], name="bunker_band"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(k.box((0.34, 0.34, bh + 0.1), (sx * 3.66, bc + sy * (bl / 2 - 0.08), FOOT + bh / 2), m=m["iron"], bevel=0.06, name="corner"))
        body.append(nameplate(sx, bc, FOOT + 1.45, "tc", 3.77))
    heap = k.ico(2.4, (0, bc, FOOT + bh - 0.35), m=m["coal"], scale=(1.42, 1.25, 0.55), subdiv=3, name="coal")
    k.displace(heap, 0.45, size=0.45, seed=5)
    body.append(heap)

    # The bunker's lamp: a lantern on an iron post at its back corner (the car's warm point).
    lx, ly = 3.0, bc + bl / 2 - 0.5
    body.append(k.cyl(0.09, 0.7, (lx, ly, FOOT + bh + 0.3), m=m["iron"], n=8, name="lamp_post"))
    b, g = lantern(lx, ly, FOOT + bh + 0.62, m, lamp_m, s=0.95)
    body += b
    lamp += g

    # Crate deck (back half): plank floor, timber stakes with a brass top rail, lashed cargo.
    body.append(k.box((7.7, 6.9, 0.08), (0, 3.85, FOOT + 0.02), m=m["boards"], name="crate_deck"))
    for sx in (-1, 1):
        for y in (0.9, 3.95, 7.0):
            body.append(k.box((0.3, 0.3, 1.45), (sx * 3.75, y, FOOT + 0.7), m=m["timber"], bevel=0.05, name="stake"))
        body.append(k.tube([(sx * 3.75, 0.9, FOOT + 1.4), (sx * 3.75, 7.0, FOOT + 1.4)], 0.08, m=m["brass"], n=6, name="top_rail"))
    body.append(k.tube([(-3.75, 7.0, FOOT + 1.4), (3.75, 7.0, FOOT + 1.4)], 0.08, m=m["brass"], n=6, name="end_rail"))
    crate = k.paint("tc_crate", [(0, (150, 106, 78)), (1, (172, 124, 90))], FOOT, FOOT + 4, bands=((132, 92, 66), 0.55), grain=(0.08, 4, "wave"))
    for (cx, cy, cz, s, yaw) in ((-1.5, 3.6, FOOT + 1.1, 2.2, 0), (-1.4, 3.7, FOOT + 2.2 + 0.75, 1.5, 14), (1.6, 5.6, FOOT + 0.8, 1.6, -8)):
        body.append(k.box((s, s, s), (cx, cy, cz), rot=(0, 0, yaw), m=crate, bevel=0.12, seg=2, name="crate"))
        for dz in (-0.5, 0.5):
            body.append(k.box((s + 0.06, s + 0.06, 0.12), (cx, cy, cz + dz * (s - 0.3)), rot=(0, 0, yaw), m=m["iron"], name="crate_band"))
    teal = k.paint("tc_barrel", [(0, (40, 92, 104)), (1, (72, 138, 146))], FOOT, FOOT + 1.8)
    body.append(k.lathe([(0.62, 0), (0.72, 0.4), (0.74, 0.85), (0.72, 1.3), (0.62, 1.7), (0.5, 1.72), (0, 1.72)], loc=(1.6, 2.6, FOOT), m=teal, n=20, name="barrel"))
    for z in (0.3, 1.4):
        body.append(k.ring(0.72, FOOT + z, 0.06, m["brass"], n=20, sides=5, centre=(1.6, 2.6), name="hoop"))
    rope = k.flat((214, 186, 130))
    body.append(k.tube([(-2.68, 2.7, FOOT + 0.1), (-2.68, 2.7, FOOT + 2.27), (-0.32, 2.7, FOOT + 2.27), (-0.32, 2.7, FOOT + 0.1)], 0.07, m=rope, n=6, name="lashing"))
    return {"": body, "lamp_glow": lamp}


def train_car_lamp():
    m = livery("tl")
    lamp_m = k.flat(k.LAMP_GLOW)
    body, lamp = car_base(16, m, (-4.6, 4.6)), []
    body.append(k.box((7.7, 14.0, 0.08), (0, 0, FOOT + 0.02), m=m["boards"], name="planks"))

    # Two turret rings: an iron plate and a brass ring the 3 x 3 turret base stands on.
    for ty in (-TURRET_Y, TURRET_Y):
        body.append(k.cyl(1.62, 0.16, (0, ty, FOOT + 0.08), m=m["iron"], n=28, name="turret_plate"))
        body.append(k.ring(1.55, FOOT + 0.17, 0.09, m["brass"], n=28, sides=5, centre=(0, ty), name="turret_ring"))
        for i in range(6):
            a = math.pi / 3 * i + math.pi / 6
            body.append(k.cyl(0.08, 0.08, (1.3 * math.cos(a), ty + 1.3 * math.sin(a), FOOT + 0.19), m=m["brass"], n=5, name="bolt"))

    # Low red planked bulwarks with brass caps round the turrets, open in the middle by the rack.
    for side in (-1, 1):
        for y0, y1 in ((-7.3, -2.0), (2.0, 7.3)):
            body.append(k.box((0.3, y1 - y0, 1.0), (side * 3.82, (y0 + y1) / 2, FOOT + 0.5), m=m["planks"], bevel=0.05, name="bulwark"))
            body.append(k.box((0.42, y1 - y0 + 0.06, 0.12), (side * 3.82, (y0 + y1) / 2, FOOT + 1.02), m=m["brass"], bevel=0.03, name="cap"))
            body.append(k.box((0.08, y1 - y0 - 0.4, 0.1), (side * 3.99, (y0 + y1) / 2, FOOT + 0.5), m=m["brass"], name="stripe"))
    for s in (-1, 1):
        body.append(k.box((7.34, 0.3, 1.0), (0, s * 7.15, FOOT + 0.5), m=m["planks"], bevel=0.05, name="end_bulwark"))
        body.append(k.box((7.4, 0.42, 0.12), (0, s * 7.15, FOOT + 1.02), m=m["brass"], bevel=0.03, name="cap"))

    # The lantern rack across the middle: timber uprights, an iron arch with a brass finial (9 up),
    # three lanterns hanging from it, a shelf of oil cans, the Mender's stool behind it.
    for side in (-1, 1):
        x = side * 2.5
        body.append(k.box((0.42, 0.42, 5.75), (x, 0, FOOT + 2.875), m=m["timber"], bevel=0.06, name="upright"))
        body.append(k.lathe([(0.42, 0), (0.42, 0.25), (0.3, 0.4)], loc=(x, 0, FOOT), m=m["brass"], n=8, name="upright_foot"))
        body.append(k.sphere(0.2, (x, 0, FOOT + 5.85), m=m["brass"], seg=8, rings=4, name="upright_knob"))
    arch = [(2.5 * math.cos(math.pi * i / 10), 0, 7.95 + 0.6 * math.sin(math.pi * i / 10)) for i in range(11)]
    body.append(k.tube(arch, 0.13, m=m["iron"], n=8, name="arch"))
    body.append(k.sphere(0.22, (0, 0, 8.78), m=m["brass"], seg=10, rings=6, name="finial"))
    for x, z in ((-1.5, 5.75), (0, 6.0), (1.5, 5.75)):
        top = 7.95 + 0.6 * math.sin(math.acos(x / 2.5))
        body.append(k.tube([(x, 0, z + 1.4), (x, 0, top)], 0.04, m=m["iron"], n=4, name="chain"))
        b, g = lantern(x, 0, z, m, lamp_m, s=1.3)
        body += b
        lamp += g
    body.append(k.box((4.6, 0.9, 0.16), (0, 0, FOOT + 1.6), m=m["timber"], bevel=0.04, name="shelf"))
    can = k.paint("tl_can", [(0, (205, 138, 50)), (1, (250, 196, 98))], FOOT + 1.7, FOOT + 2.5)
    for x in (-1.3, -0.45, 0.45, 1.3):
        body.append(k.lathe([(0.26, 0), (0.26, 0.5), (0.12, 0.66), (0.06, 0.8), (0, 0.8)], loc=(x, 0, FOOT + 1.68), m=can, n=8, name="oil_can"))
    teal = k.paint("tl_cushion", [(0, (40, 92, 104)), (1, (72, 138, 146))], FOOT + 1.0, FOOT + 1.5)
    body.append(k.lathe([(0.45, 0), (0.3, 0.3), (0.26, 1.0), (0.5, 1.05)], loc=(0, MENDER_Y, FOOT), m=m["timber"], n=12, name="stool"))
    body.append(k.lathe([(0.56, 1.0), (0.6, 1.2), (0.5, 1.4), (0, 1.45)], loc=(0, MENDER_Y, FOOT), m=teal, n=16, name="stool_cushion"))
    return {"": body, "lamp_glow": lamp}


def train_car_passenger():
    m = livery("tp")
    lamp_m = k.flat(k.LAMP_GLOW)
    body, lamp = car_base(18, m, (-5.4, 5.4), r=0.95), []
    body.append(k.box((7.3, 15.0, 0.08), (0, 0, FOOT + 0.02), m=m["boards"], name="planks"))
    W, Z0, Z1, BY = 3.78, FOOT, 8.55, 7.6  # wall centre x, wall bottom, eaves, body half length

    # Side walls: one plank wall each with four round-topped open windows (eight, critters ride in
    # them), a brass waist sill and brass window frames.
    holes = []
    for c in WINDOWS:
        arc = [(c + 1.3 * math.cos(math.pi * i / 10), 6.6 + 1.3 * math.sin(math.pi * i / 10)) for i in range(11)]
        holes.append([(c + 1.3, 4.6)] + arc + [(c - 1.3, 4.6)])
    for side in (-1, 1):
        wall = k.plate([[(-BY, Z0), (BY, Z0), (BY, Z1), (-BY, Z1)]] + holes, 0.36, loc=(side * W, 0, 0), rot=(90, 0, 90), m=m["planks"], name="wall")
        body.append(wall)
        body.append(k.box((0.52, 2 * BY + 0.1, 0.16), (side * W, 0, 4.6), m=m["brass"], name="sill"))
        body.append(k.box((0.12, 2 * BY + 0.1, 0.16), (side * (W + 0.17), 0, Z1 - 0.3), m=m["brass"], name="cornice"))
        for hole in holes:
            body.append(k.tube([(side * (W + 0.19), y, z) for y, z in hole], 0.07, m=m["brass"], n=4, cap=False, name="frame"))
        body.append(nameplate(side, 0, 3.45, "tp", 3.98))

    # End walls under the roof arch: a teal door with a lit porthole.
    door = k.paint("tp_door", [(0, (40, 98, 110)), (1, (72, 138, 146))], FOOT, 6.6, grain=(0.12, 5, "wave"))
    end = [(-W - 0.18, Z0), (W + 0.18, Z0)] + [(3.96 - 7.92 * i / 14, Z1 + 0.6 * math.sin(math.pi * (0.04 + 0.92 * i / 14))) for i in range(15)]
    for s in (-1, 1):
        y = s * BY
        body.append(k.poly(end, 0.34, loc=(0, y, 0), m=m["planks"], name="end_wall"))
        dw, dh = 2.0, 4.1
        arch = [(dw / 2, 0), (dw / 2, dh - dw / 2)] + [(dw / 2 * math.cos(math.pi * i / 10), dh - dw / 2 + dw / 2 * math.sin(math.pi * i / 10)) for i in range(1, 10)] + [(-dw / 2, dh - dw / 2), (-dw / 2, 0)]
        body.append(k.poly(arch, 0.12, loc=(0, y + s * 0.2, FOOT + 0.05), m=door, name="door"))
        body.append(k.sphere(0.12, (0.62, y + s * 0.3, FOOT + 2.0), m=m["brass"], seg=10, rings=6, name="knob"))
        pz = FOOT + dh - 1.0
        lamp.append(k.cyl(0.42, 0.06, (0, y + s * 0.27, pz), rot=(90, 0, 0), m=lamp_m, n=16, name="porthole"))
        body.append(ring_at(0.46, 0.08, m["brass"], (0, y + s * 0.3, pz), n=16, sides=5, name="porthole_ring"))

    # Roof: the cab's plum arch, a turret plinth on top (the passenger roof turret), two brass
    # roof lamps; inside, two lanterns hang over the aisle.
    body.append(k.surface(14, 2, lambda u, v: (-4.0 + 8.0 * u, -BY - 0.4 + (2 * BY + 0.8) * v, Z1 - 0.05 + 0.6 * math.sin(math.pi * u)), m=m["roof"], thickness=0.25, name="roof"))
    top = Z1 + 0.6
    body.append(k.cyl(1.62, 0.32, (0, 0, top + 0.1), m=m["iron"], n=32, name="turret_plate"))
    body.append(k.ring(1.55, top + 0.27, 0.09, m["brass"], n=28, sides=5, name="turret_ring"))
    for y in (-5.3, 5.3):
        body.append(k.lathe([(0.36, 0), (0.4, 0.34), (0.3, 0.56), (0.13, 0.72), (0, 0.8)], loc=(0, y, ROOF_LAMP_Z), m=m["brass"], n=12, name="roof_lamp"))
    for y in (-3.6, 3.6):
        body.append(k.tube([(0, y, Z1 + 0.4), (0, y, 7.95)], 0.035, m=m["iron"], n=4, name="chain"))
        b, g = lantern(0, y, 6.85, m, lamp_m, s=0.9)
        body += b
        lamp += g

    # Six seats facing forward in three rows: timber frames, teal cushions, seen through the windows.
    cushion = k.paint("tp_cushion", [(0, (40, 92, 104)), (1, (76, 142, 150))], FOOT + 0.8, 6.0)
    for sy in SEAT_ROWS:
        for sx in (-SEAT_X, SEAT_X):
            body.append(k.box((2.3, 1.5, 0.9), (sx, sy, FOOT + 0.45), m=m["timber"], name="seat_base"))
            body.append(k.box((2.2, 1.45, 0.42), (sx, sy - 0.05, FOOT + 1.1), m=cushion, bevel=0.14, name="seat"))
            body.append(k.box((2.3, 0.3, 2.3), (sx, sy + 0.75, FOOT + 2.05), m=m["timber"], bevel=0.08, name="seat_back"))
            body.append(k.box((2.1, 0.32, 1.7), (sx, sy + 0.5, FOOT + 2.2), m=cushion, bevel=0.14, seg=2, name="back_cushion"))

    # Tail lamp on the back wall.
    b, g = lantern(2.6, BY + 0.45, 5.6, m, lamp_m, s=0.8)
    body += b
    lamp += g
    body.append(k.box((0.12, 0.6, 0.12), (2.6, BY + 0.25, 6.55), m=m["iron"], name="tail_bracket"))
    return {"": body, "lamp_glow": lamp}


TURRET_Y = 4.7  # lamp car turret rings, each side of the middle
MENDER_Y = 1.25  # the Mender's stool, just behind the lantern rack
WINDOWS = (-5.34, -1.78, 1.78, 5.34)  # passenger window centres along the car
SEAT_ROWS = (-4.08, -0.08, 3.92)  # passenger seat centres along the car (backs on the +Y side)
SEAT_X = 1.95
ROOF_LAMP_Z = 9.2


# Lamp turret: a drum base and a searchlight head, both round so they read from every side. ------


def lamp_turret_base():
    m = livery("lb")
    body = [
        k.lathe([(1.5, 0), (1.5, 0.16), (1.3, 0.32), (0, 0.32)], m=m["iron"], n=24, name="foot"),
        k.lathe([(1.12, 0.3), (1.08, 0.9), (1.12, 1.5)], m=m["red"], n=24, name="drum"),
        # Hollow bearing: the head's grips dip into the well when it aims high.
        k.lathe([(1.18, 1.46), (1.45, 1.6), (1.45, 1.9), (1.3, 2.0), (1.06, 2.0), (1.0, 1.55), (0, 1.55)], m=m["brass"], n=24, name="bearing"),
        k.lathe([(0.3, 1.54), (0.2, 1.75), (0.22, 1.85), (0.22, 1.92), (0, 1.97)], m=m["brass"], n=10, name="spindle"),
        k.lathe([(1.08, 0.82), (1.13, 0.9), (1.08, 0.98)], m=m["brass"], n=24, name="band"),
    ]
    for i in range(6):
        a = math.pi / 3 * i + math.pi / 6
        body.append(k.cyl(0.09, 0.1, (1.38 * math.cos(a), 1.38 * math.sin(a), 0.3), m=m["brass"], n=5, name="bolt"))
    return body


def lamp_turret_head():
    """A searchlight along Y, symmetric about its trunnions: the hood is 1.8 in front of them, the
    grips 1.8 behind, the hood ring 1.2 round, so the bounding-box centre is the hinge."""
    m = livery("lh")
    lens_m = k.flat(k.LAMP_GLOW)
    flip = Matrix.Rotation(math.radians(90), 4, "X")  # local +z (the lathe axis) -> world -Y (front)
    parts = [
        k.lathe([(0, -1.5), (0.55, -1.46), (0.84, -1.34), (0.96, -1.16), (0.96, 1.2)], m=m["red"], n=24, name="barrel"),
        k.lathe([(0.9, 1.1), (1.17, 1.2), (1.2, 1.32), (1.2, 1.74), (1.12, 1.8), (1.0, 1.8), (0.98, 1.36)], m=m["brass"], n=24, name="hood"),
        k.lathe([(0.95, -0.78), (1.03, -0.6), (0.95, -0.42)], m=m["brass"], n=24, name="band"),
        k.lathe([(0.95, 0.42), (1.03, 0.6), (0.95, 0.78)], m=m["brass"], n=24, name="band"),
    ]
    for p in parts:
        p.data.transform(flip)
    lens = k.cyl(0.97, 0.06, (0, -1.4, 0), rot=(90, 0, 0), m=lens_m, n=24, name="lens")
    for side in (-1, 1):
        parts.append(k.cyl(0.3, 0.26, (side * 1.07, 0, 0), rot=(0, 90, 0), m=m["brass"], n=12, name="trunnion"))
        parts.append(k.capsule((side * 0.62, 1.1, 0), (side * 0.62, 1.68, 0), 0.12, 0.12, m["iron"], n=8, name="grip"))
    parts.append(k.lathe([(0.24, 0.8), (0.24, 1.08), (0.32, 1.12), (0.3, 1.2), (0, 1.2)], m=m["iron"], n=12, name="vent"))
    return {"": parts, "lamp_glow": [lens]}


ASSETS = [
    dict(name="train_engine", build=train_engine, budget=12000, finalize=k.HD, size=[8, 11, 22], priority=1, order=1,
         replaces="engine fallback (red block body, black cylinder boiler, chimney)",
         notes=("Engine and tender, 22 x 11 x 8 (architecture section 9). Wheels on y = 0 (rail top), front -Z, cab floor 2.3 up. Three meshes: train_engine (textured), "
                "train_engine_lamp_glow (Neon: headlamp lens and side panes, tender tail lamp) and train_engine_fire_glow (Neon: firebox door and grate, cab spectacles). "
                "Chimney top centre (smoke): 5.5 forward of the middle, 11 up. Cab roof (the engine's turret): a gentle arch 8.2 to 8.65 up, 7.9 wide, from 2.1 behind the middle to 6.5 behind. "
                "Code adds a SpotLight on the lamp (range 60, angle 50, brightness 3) and an orange PointLight in the cab (range 12). Static: the wheels do not turn."),
         glow={"lamp_glow": k.LAMP_GLOW, "fire_glow": k.FIRE_GLOW}),
    dict(name="train_car_cargo", build=train_car_cargo, budget=6000, finalize=k.HD, size=[8, 7, 16], priority=1, order=2,
         replaces="cargo car fallback (block wagon)",
         notes=("Cargo car, 16 x 7 x 8: coal bunker in front, crate deck behind. Wheels on y = 0 (rail top), front -Z, floor 2.3 up. Buffer heads end at the "
                "bounding box (+-8), buffers and coupling 1.75 up, 2.6 off centre, as the engine. Two meshes: train_car_cargo (textured) and train_car_cargo_lamp_glow "
                "(Neon: the bunker lantern, glass centre 6.2 up at the bunker's back corner on the car's left, 1.15 forward of the middle). Static wheels."),
         glow={"lamp_glow": k.LAMP_GLOW}),
    dict(name="train_car_lamp", build=train_car_lamp, budget=6000, finalize=k.HD, size=[8, 9, 16], priority=1, order=3,
         replaces="lamp car fallback (block flatcar)",
         notes=("Lamp car, 16 x 9 x 8: flatcar with two turret rings and the lantern rack. Wheels on y = 0, front -Z, floor 2.3 up. Turret rings (3.2 across, "
                "lamp_turret_base stands on them): top 2.46 up, centred 4.7 forward and 4.7 back of the middle. Lantern rack across the middle (finial 9 up); "
                "its three lanterns (glass centres 6.3 up at x +-1.5 and 6.5 up at x 0) are the train_car_lamp_lamp_glow mesh (Neon). The Mender's stool: "
                "cushion top 3.75 up, 1.25 behind the middle on the centre line, facing forward at the rack. Red bulwarks (top 3.4 up) round both ends, open beside the rack."),
         glow={"lamp_glow": k.LAMP_GLOW}),
    dict(name="train_car_passenger", build=train_car_passenger, budget=8000, finalize=k.HD, size=[8, 10, 18], priority=1, order=4,
         replaces="passenger car fallback (block coach)",
         notes=("Passenger coach, 18 x 10 x 8. Wheels on y = 0, front -Z, floor 2.3 up. Six forward-facing seats (cushion tops 3.6 up) at x +-1.95 and "
                "z -4.1, -0.1, 3.9 from the middle. Eight open round-topped windows, four a side, centred z +-1.78 and +-5.34, sill top 4.68 up at x +-3.8 "
                "(the critter window slots), opening 2.6 wide and 3.3 tall. Roof turret plinth: top 9.41 up on the middle. "
                "train_car_passenger_lamp_glow (Neon): two cabin lanterns over the aisle (z +-3.6, 7.2 up), the two end-door portholes and the tail lamp "
                "(back wall, 6 up). Static wheels."),
         glow={"lamp_glow": k.LAMP_GLOW}),
    dict(name="lamp_turret_base", build=lamp_turret_base, budget=1200, finalize=k.HD, size=[3, 2, 3], priority=1, order=5,
         replaces="turret base fallback (cylinder)",
         notes=("Turret drum, 3 x 2 x 3, origin at its base centre: red drum, brass bearing with a hollow well (the head's grips dip into it at high pitch). "
                "Stands on the lamp car's turret rings, the passenger roof plinth and the engine's cab roof. One mesh."),
         glow={}),
    dict(name="lamp_turret_head", build=lamp_turret_head, budget=1500, finalize=k.HD, size=[2.4, 2.4, 3.6], priority=1, order=6,
         replaces="turret head fallback (block with a pale glass face)",
         notes=("Searchlight head, 2.4 x 2.4 x 3.6, glass front on -Z, symmetric about its hinge: the trunnion axis runs through the bounding-box centre. "
                "Place the hinge 1.65 above the base top (0.45 clear at rest; at -15 pitch the hood clears the bearing, at 75 the grips sink into the well). "
                "Two meshes: lamp_turret_head (textured) and lamp_turret_head_lamp_glow (Neon lens; code may tint it to the player's lamp colour)."),
         glow={"lamp_glow": k.LAMP_GLOW}),
]
