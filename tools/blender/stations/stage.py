"""Concept scenes for Animal Stations: whole places (the hub's centre, a ranch's training areas) built
in the faceted style of the animals and rendered as presentation cards. Concepts only: nothing here is
baked, exported or uploaded.

blender --background --factory-startup --python tools/blender/stations/stage.py -- [scene ...]

With no names, renders every scene in scenes/*.py. Writes build/blender/stations/scenes/<scene>.png
(a wide hero shot over three closer ones) and each shot beside it.

A scene file lists SCENES = [dict(name=..., build=fn, shots=[...])]. `build(rng)` makes the place round
the origin, 1 unit = 1 stud, the ground at z = 0, north towards +Y. A shot is (eye, target, lens): the
first is the hero. A place that grows with an upgrade tags its pieces with the levels they stand at
(`first`, `last`); a shot (eye, target, lens, level) then shows it at that level, marked with pips.
The helpers below make faceted pieces from a colour: one flat tone a face, like facet.py's, optionally
under one of its surface textures.
"""

import ast
import importlib.util
import math
import os
import random
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import facet as F  # noqa: E402
import kit as k  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

OUT = os.path.join(k.OUT, "scenes")
WARM, COOL, PALE = F.WARM, F.COOL, F.PALE

# Colours shared by the scenes.
GRASS = (104, 168, 76)
STONE = (200, 190, 170)
STONE_DARK = (150, 144, 136)
MARBLE = (236, 230, 216)
SAND = (226, 204, 156)
DIRT = (166, 124, 84)
WOOD = (150, 102, 62)
WOOD_DARK = (98, 66, 44)
GOLD = (250, 196, 60)
WATER = (70, 176, 236)
LEAF = (76, 150, 72)
INK = (40, 36, 48)
WHITE = (244, 242, 234)
RED = (214, 66, 60)
LANTERN = (255, 214, 130)


# Pieces ------------------------------------------------------------------------------------------------


def paint(ob, rgb, rng, surface=None, kind=WARM, emit=0.0, chance=0.2):
    """Gives a mesh the faceted look: one tone of `rgb` a face, by which way the face points."""
    ob.data.materials.clear()
    ob.data.materials.append(F.material(emit, surface))
    return F.colour(ob, F.tone(rgb, kind), rng, chance)


def neon(ob, rgb, strength=3.0):
    """A glowing piece (Neon in the game)."""
    ob.data.materials.clear()
    ob.data.materials.append(k.mat(f"neon_{rgb}_{strength}", rgb, kind="flat", emit=strength, rough=0.4))
    return ob


def words(text, at, size, rgb, yaw=0.0, depth=0.14, glow=0.3):
    """Raised lettering centred on `at`, standing upright and read from its local -Y side."""
    curve = bpy.data.curves.new("words", "FONT")
    curve.body, curve.size, curve.extrude = text, size, depth / 2
    curve.align_x, curve.align_y = "CENTER", "CENTER"
    flat = bpy.data.objects.new("words", curve)
    bpy.context.scene.collection.objects.link(flat)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(flat.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(flat)
    me.transform(Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X"))
    me.materials.clear()
    me.materials.append(k.mat(f"words_{rgb}_{glow}", rgb, kind="flat", emit=glow, rough=0.5))
    ob = bpy.data.objects.new("words", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def gem(base, tip, width, rgb, strength=3.0, rng=None):
    """A glowing crystal from base to tip."""
    return neon(F.shard(base, tip, width, width, None, rng, m=k.mat("gem", rgb, kind="flat")), rgb, strength)


def moved(ob, matrix):
    ob.data.transform(matrix)
    return ob


def polar(r, deg, z=0.0):
    a = math.radians(deg)
    return Vector((r * math.cos(a), r * math.sin(a), z))


def box(size, at, rgb, rng, yaw=0.0, tilt=(0.0, 0.0), bevel=0.0, **look):
    """A block standing on the point `at`, turned `yaw` degrees."""
    ob = k.box(size, (at[0], at[1], at[2] + size[2] / 2), (tilt[0], tilt[1], yaw), bevel=bevel)
    return paint(ob, rgb, rng, **look)


def post(r, h, at, rgb, rng, n=8, r2=None, rot=(0.0, 0.0, 0.0), **look):
    """An upright prism (a post, a drum, a cone with r2 = 0) standing on `at`."""
    ob = k.cyl(r, h, (0, 0, h / 2), n=n, r2=r2)
    ob.data.transform(k._xf(at, rot))
    return paint(ob, rgb, rng, **look)


def turn(profile, at, rgb, rng, n=12, **look):
    """A turned piece (a vase, a basin, a column): profile [(radius, height), ...] from its foot up."""
    return paint(k.lathe(profile, at, n=n), rgb, rng, **look)


def pipe(points, radii, rgb, rng, n=6, **look):
    return paint(k.tube(points, radii, n=n), rgb, rng, **look)


def lump(at, size, rgb, rng, surface=None, kind=WARM):
    """A rock, a bush, a puff of leaves."""
    if isinstance(size, (int, float)):
        size = (size, size, size)
    return F.lump(at, size, F.tone(rgb, kind), rng, surface=surface)


def shard(base, tip, width, thick, rgb, rng, kind=WARM, **kw):
    return F.shard(base, tip, width, thick, F.tone(rgb, kind), rng, **kw)


def slab(r0, r1, a0, a1, z, h, rgb, rng, centre=(0.0, 0.0), step=6.0, **look):
    """A piece of a ring lying flat: from radius r0 to r1, from angle a0 to a1 (degrees), its foot at z."""
    n = max(1, round(abs(a1 - a0) / step))
    verts, faces = [], []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        for r in (r0, r1):
            for zz in (z, z + h):
                verts.append((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), zz))
    for i in range(n):
        b, c = i * 4, i * 4 + 4
        faces += [(b + 1, b + 3, c + 3, c + 1), (b, c, c + 2, b + 2), (b, b + 1, c + 1, c), (b + 2, c + 2, c + 3, b + 3)]
    faces += [(0, 2, 3, 1), (n * 4, n * 4 + 1, n * 4 + 3, n * 4 + 2)]
    look.setdefault("chance", 0.2)
    kind = look.pop("kind", WARM)
    return F.mesh("slab", verts, faces, F.tone(rgb, kind), rng, **look)


def disc(r, at, h, rgb, rng, n=32, **look):
    return post(r, h, at, rgb, rng, n=n, **look)


def prism(outline, at, h, rgb, rng, yaw=0.0, **look):
    """A flat shape [(x, y), ...] standing `h` tall on `at`."""
    n = len(outline)
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    foot = [(at[0] + x * c - y * s, at[1] + x * s + y * c) for x, y in outline]
    verts = [(x, y, at[2]) for x, y in foot] + [(x, y, at[2] + h) for x, y in foot]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    kind = look.pop("kind", WARM)
    return F.mesh("prism", verts, faces, F.tone(rgb, kind), rng, **look)


def roof(w, d, h, at, rgb, rng, yaw=0.0, ridge=0.0, **look):
    """A hipped roof `w` by `d` standing on `at`, its ridge `ridge` long (0: a pyramid)."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def p(x, y, z):
        return (at[0] + x * c - y * s, at[1] + x * s + y * c, at[2] + z)

    verts = [p(-w / 2, -d / 2, 0), p(w / 2, -d / 2, 0), p(w / 2, d / 2, 0), p(-w / 2, d / 2, 0), p(-ridge / 2, 0, h), p(ridge / 2, 0, h)]
    faces = [(0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4)]
    kind = look.pop("kind", WARM)
    return F.mesh("roof", verts, faces, F.tone(rgb, kind), rng, **look)


def flag(at, w, h, rgb, rng, yaw=0.0, point=True):
    """A pennant hanging from `at` (its top middle), facing along `yaw`."""
    outline = [(-w / 2, 0), (w / 2, 0), (w / 2, -h * 0.55), (0, -h), (-w / 2, -h * 0.55)] if point else [(-w / 2, 0), (w / 2, 0), (w / 2, -h), (-w / 2, -h)]
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    n = len(outline)
    verts = []
    for t in (-0.04, 0.04):
        verts += [(at[0] + x * c - t * s, at[1] + x * s + t * c, at[2] + z) for x, z in outline]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))[::-1]] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    return F.mesh("flag", verts, faces, F.tone(rgb), rng)


def bunting(a, b, sag, rng, colours, n=9, size=0.9):
    """A line of little flags hung between two points."""
    a, b = Vector(a), Vector(b)
    pts = [a.lerp(b, i / 16) - Vector((0, 0, sag * math.sin(math.pi * i / 16))) for i in range(17)]
    out = [pipe(pts, 0.05, INK, rng, n=4)]
    yaw = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
    for i in range(n):
        t = (i + 0.5) / n
        p = a.lerp(b, t) - Vector((0, 0, sag * math.sin(math.pi * t)))
        out.append(flag(p, size * 0.8, size, colours[i % len(colours)], rng, yaw))
    return out


def tree(at, rng, s=1.0, leaf=LEAF, trunk=WOOD_DARK):
    """A round faceted tree, about 9 studs tall at s = 1."""
    x, y, z = at
    out = [post(0.55 * s, 4.2 * s, at, trunk, rng, n=6, r2=0.38 * s)]
    for dx, dy, dz, r in ((0, 0, 6.0, 2.9), (1.5, 0.6, 4.9, 2.0), (-1.3, -0.8, 5.2, 2.1), (0.3, 1.2, 7.4, 1.8)):
        tint = tuple(min(255, c * rng.uniform(0.9, 1.12)) for c in leaf)
        out.append(lump((x + dx * s, y + dy * s, z + dz * s), (r * s, r * s, r * s * 0.86), tint, rng))
    return out


def pine(at, rng, s=1.0):
    x, y, z = at
    out = [post(0.4 * s, 2.0 * s, at, WOOD_DARK, rng, n=6)]
    for i, (r, h) in enumerate(((2.4, 3.2), (1.9, 2.8), (1.3, 2.6))):
        out.append(post(r * s, h * s, (x, y, z + (1.6 + i * 1.9) * s), (52, 122, 84), rng, n=7, r2=0.0))
    return out


def bush(at, rng, s=1.0, rgb=(92, 160, 78)):
    x, y, z = at
    return [lump((x + dx * s, y + dy * s, z + 0.7 * s * sz), (1.1 * s * sz, 1.1 * s * sz, 0.8 * s * sz), rgb, rng) for dx, dy, sz in ((0, 0, 1.0), (0.9, 0.3, 0.75), (-0.7, 0.5, 0.7))]


def flowers(at, rng, n=7, spread=1.2, colours=((255, 120, 170), (255, 224, 90), (190, 150, 255), (255, 255, 255), (255, 150, 90))):
    """A patch of little flowers: a stalk and a bright head each."""
    out = []
    for _ in range(n):
        a, r = rng.uniform(0, math.tau), spread * math.sqrt(rng.random())
        x, y, h = at[0] + r * math.cos(a), at[1] + r * math.sin(a), rng.uniform(0.5, 0.9)
        out.append(post(0.05, h, (x, y, at[2]), (70, 140, 70), rng, n=4))
        out.append(lump((x, y, at[2] + h + 0.1), 0.2, colours[rng.randrange(len(colours))], rng))
    return out


def rock(at, rng, s=1.0, rgb=STONE_DARK):
    return lump((at[0], at[1], at[2] + 0.45 * s), (s, s * 0.85, s * 0.6), rgb, rng, surface="rock", kind=COOL)


def lantern(at, rng, h=6.0, rgb=LANTERN, metal=INK):
    """A lamp post with a hanging lantern that glows."""
    x, y, z = at
    out = [post(0.5, 0.5, at, metal, rng, n=8), post(0.18, h, (x, y, z + 0.5), metal, rng, n=6)]
    out.append(box((1.5, 0.16, 0.16), (x + 0.6, y, z + h + 0.3), metal, rng))
    out.append(neon(k.cyl(0.42, 0.9, (x + 1.2, y, z + h - 0.35), n=6), rgb))
    out.append(post(0.56, 0.3, (x + 1.2, y, z + h + 0.1), metal, rng, n=6, r2=0.1))
    out.append(post(0.5, 0.12, (x + 1.2, y, z + h - 0.9), metal, rng, n=6))
    return out


def bench(at, rng, yaw=0.0):
    """A slatted bench; it faces along its local -Y."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def p(x, y, z):
        return (at[0] + x * c - y * s, at[1] + x * s + y * c, at[2] + z)

    out = []
    for i in range(3):
        out.append(box((4.4, 0.42, 0.14), p(0, -0.5 + i * 0.5, 1.1), WOOD, rng, yaw))
    for i in range(2):
        out.append(box((4.4, 0.14, 0.42), p(0, 0.85, 1.6 + i * 0.6), WOOD, rng, yaw))
    for sx in (-1.8, 1.8):
        out.append(box((0.3, 1.5, 1.1), p(sx, 0, 0), INK, rng, yaw))
        out.append(box((0.3, 0.2, 1.4), p(sx, 0.85, 1.1), INK, rng, yaw))
    return out


def fence(a, b, rng, h=1.6, gap=3.0, rgb=WOOD):
    """Posts and two rails from a to b."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    n = max(1, round(length / gap))
    yaw = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
    out = []
    for i in range(n + 1):
        p = a.lerp(b, i / n)
        out.append(box((0.38, 0.38, h), p, WOOD_DARK, rng, yaw))
    mid = (a + b) / 2
    for z in (h * 0.45, h * 0.82):
        out.append(box((length, 0.16, 0.26), (mid.x, mid.y, mid.z + z), rgb, rng, yaw))
    return out


# The cast: the game's own animals and eggs, built by their asset files ------------------------------------

_cast = {}


def _assets():
    if not _cast:
        folder = os.path.join(HERE, "assets")
        for file in sorted(os.listdir(folder)):
            if file.endswith(".py") and not file.startswith("_"):
                spec = importlib.util.spec_from_file_location(file[:-3], os.path.join(folder, file))
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                for asset in module.ASSETS:
                    _cast[asset["name"]] = asset
    return _cast


def spin(objs, at, yaw):
    """Turns pieces `yaw` degrees about the upright line through `at`. Returns them."""
    m = Matrix.Translation(Vector((at[0], at[1], 0))) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Translation(Vector((-at[0], -at[1], 0)))
    for ob in objs:
        ob.data.transform(m)
    return objs


def face_in(deg):
    """The yaw at which something standing at angle `deg` round the middle faces the middle."""
    return deg - 90


def actor(name, at, yaw=0.0, scale=1.0, statue=None, rng=None, surface="rock", kind=PALE, fit=None):
    """The asset `name` (an animal, an egg) standing on `at`, turned `yaw` degrees from facing -Y, at
    `scale` times its real size, or `fit` studs along its longest side. With `statue` (a colour) it is
    carved from stone of that colour."""
    asset = _assets()[name]
    groups = asset["build"]()
    objs = [ob for part in groups.values() for ob in part]
    s = asset.get("scale", 1) * scale
    for ob in objs:
        ob.data.transform(Matrix.Scale(s, 4))
    lo, hi = k._ground_dims(objs)
    if fit:
        again = fit / max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
        for ob in objs:
            ob.data.transform(Matrix.Scale(again, 4))
        lo, hi = lo * again, hi * again
    move = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
    for part, part_objs in groups.items():
        for ob in part_objs:
            ob.data.transform(move)
            if statue:
                paint(ob, statue, rng, surface=surface, kind=kind)
            elif part.endswith("_glow"):
                neon(ob, asset["glow"].get(part, k.GLOW_RGB))
    return objs


def sort_pieces(rng, asset):
    """Sorts every mesh in the scene into the pieces of a game model: the painted `body`, and one Neon
    piece for each colour that glows (`body_glow`, `body2_glow`, ...), whose colours it writes into
    `asset["glow"]`. Lettering and steam are painted on, plain white. Returns the groups."""
    groups, colours = {"body": []}, {}
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        kind = ob.data.materials[0].name if ob.data.materials else ""
        if kind.startswith("neon_"):
            rgb = tuple(round(c) for c in ast.literal_eval(kind[5 : kind.rindex("_")]))
            part = colours.setdefault(rgb, "body_glow" if not colours else f"body{len(colours) + 1}_glow")
            groups.setdefault(part, []).append(ob)
        else:
            if kind.startswith("words_") or kind == "steam":
                paint(ob, WHITE, rng, chance=0.0)
            groups["body"].append(ob)
    asset["glow"] = {part: rgb for rgb, part in colours.items()}
    return groups


# The card ------------------------------------------------------------------------------------------------


TOP = 5  # the highest upgrade level of a place that grows


def show(level):
    """Shows a place as it stands at upgrade `level`: only the pieces whose `first` to `last` hold it."""
    for ob in bpy.data.objects:
        if "first" in ob:
            ob.hide_render = not ob["first"] <= level <= ob["last"]


def pips(frame, level):
    """Marks a frame with its upgrade level: five squares in the top left corner, `level` of them gold."""
    h = frame.shape[0]
    frame[h - 44 : h - 8, 8 : 8 + 5 * 30 + 6] = (0.08, 0.08, 0.1)
    for i in range(TOP):
        frame[h - 38 : h - 14, 14 + i * 30 : 38 + i * 30] = (1.0, 0.78, 0.2) if i < level else (0.3, 0.3, 0.34)
    return frame


def render(name, shots, ground=GRASS):
    """Renders the shots [(eye, target, lens[, level]), ...] and lays them out: the first wide on top, the
    rest in rows of three below."""
    scene = bpy.context.scene
    k.daylight(scene)
    grass = k.mat("stage_grass", ground, kind="noise", var=0.06, scale=0.6, rough=1.0)
    k.cyl(4000, 0.02, (0, 0, -0.012), m=grass, n=64)
    os.makedirs(OUT, exist_ok=True)
    frames = []
    for i, shot in enumerate(shots):
        eye, target, lens = shot[:3]
        show(shot[3] if len(shot) > 3 else TOP)
        w, h = (1920, 1080) if i == 0 else (640, 480)
        cam_data = bpy.data.cameras.new("cam")
        cam_data.lens = lens
        cam_data.clip_end = 4000
        cam = bpy.data.objects.new("cam", cam_data)
        scene.collection.objects.link(cam)
        cam.location = eye
        cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = w, h
        scene.render.filepath = os.path.join(OUT, f"{name}_{i}.png")
        bpy.ops.render.render(write_still=True)
        frames.append(k._bloom(k._pixels(scene.render.filepath)))
        if i > 0 and len(shot) > 3:
            pips(frames[-1], shot[3])
    rows = [frames[0]]
    for j in range(1, len(frames) - 2, 3):
        rows.insert(0, np.concatenate(frames[j : j + 3], axis=1))  # image rows run bottom to top
    width = min(r.shape[1] for r in rows)
    sheet = np.concatenate([r[:, :width] for r in rows], axis=0)
    rgba = np.concatenate([sheet, np.ones((*sheet.shape[:2], 1), dtype=np.float32)], axis=-1)
    out = bpy.data.images.new("card", sheet.shape[1], sheet.shape[0], alpha=False)
    out.pixels.foreach_set(rgba.astype(np.float32).ravel())
    out.filepath_raw = os.path.join(OUT, f"{name}.png")
    out.file_format = "PNG"
    out.save()


def scenes():
    found = []
    folder = os.path.join(HERE, "scenes")
    for file in sorted(os.listdir(folder)):
        if file.endswith(".py") and not file.startswith("_"):
            spec = importlib.util.spec_from_file_location(f"scene_{file[:-3]}", os.path.join(folder, file))
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            found += module.SCENES
    return found


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    wanted = [a for a in args if not a.startswith("--")]
    failed = []
    for scene in scenes():
        if wanted and scene["name"] not in wanted:
            continue
        started = time.time()
        print(f"[stage] building {scene['name']}", flush=True)
        try:
            k.reset()
            scene["build"](random.Random(scene.get("seed", 7)))
            tris = sum(k._tris(o) for o in bpy.data.objects if o.type == "MESH")
            render(scene["name"], scene["shots"], scene.get("ground", GRASS))
        except Exception:
            traceback.print_exc()
            failed.append(scene["name"])
            continue
        print(f"[stage] {scene['name']}: {tris} tris, {time.time() - started:.0f}s", flush=True)
    if failed:
        print(f"[stage] FAILED: {', '.join(failed)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
