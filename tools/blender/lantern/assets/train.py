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


ASSETS = [
    dict(name="train_engine", build=train_engine, budget=12000, finalize=k.HD, size=[8, 11, 22], priority=1, order=1,
         replaces="engine fallback (red block body, black cylinder boiler, chimney)",
         notes=("Engine and tender, 22 x 11 x 8 (architecture section 9). Wheels on y = 0 (rail top), front -Z, cab floor 2.3 up. Three meshes: train_engine (textured), "
                "train_engine_lamp_glow (Neon: headlamp lens and side panes, tender tail lamp) and train_engine_fire_glow (Neon: firebox door and grate, cab spectacles). "
                "Chimney top centre (smoke): 5.5 forward of the middle, 11 up. Cab roof (the engine's turret): a gentle arch 8.2 to 8.65 up, 7.9 wide, from 2.1 behind the middle to 6.5 behind. "
                "Code adds a SpotLight on the lamp (range 60, angle 50, brightness 3) and an orange PointLight in the cab (range 12). Static: the wheels do not turn."),
         glow={"lamp_glow": k.LAMP_GLOW, "fire_glow": k.FIRE_GLOW}),
]
