"""Builds the Animal Stations creatures headless.

blender --background --factory-startup --python tools/blender/stations/build.py -- [--draft | --beauty] [asset ...]

With no names, builds every asset in assets/*.py. Writes build/blender/stations/<asset>.fbx/.png,
previews/<asset>[_side|_front|_back].png and tools/blender/stations/manifest.json. --draft skips
the bake and export and only renders the previews (seconds instead of minutes), for shaping.
--beauty renders a presentation card of each asset instead (build/blender/stations/beauty).

Besides the Garden fields the manifest records the rig, in Roblox axes (x right, y up, z back)
from the point on the ground under the model's middle: `centres` (each mesh's bounding-box
centre, which is where its MeshPart sits) and `joints` (where each piece turns on the body). A model that is built where it stands and
exported uncentred (`finalize: center False`: a piece of the hub, of a training area) also records
`lift`: how far above the place's ground its lowest point was, since the export stands it on zero.
"""

import importlib.util
import json
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

MANIFEST = os.path.join(HERE, "manifest.json")


def specs():
    found = []
    folder = os.path.join(HERE, "assets")
    for file in sorted(os.listdir(folder)):
        if not file.endswith(".py") or file.startswith("_"):
            continue
        spec = importlib.util.spec_from_file_location(file[:-3], os.path.join(folder, file))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for asset in module.ASSETS:
            asset["script"] = f"tools/blender/stations/assets/{file}"
            found.append(asset)
    return found


def roblox(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


def eyes_of(every, offset):
    """Where a creature's eyes are (pieces named "eye..."), as [x, y, z, size] in the manifest's axes, and the
    sRGB colour of its brow (pieces named "brow..."): the game lays a lid of that colour over each eye to
    close it (the Titan asleep in its den)."""
    eyes = []
    for ob in every:
        if ob.name.startswith("eye"):
            elo, ehi = kit._ground_dims([ob])
            eyes.append(roblox((elo + ehi) / 2 + offset) + [round(max(ehi - elo), 3)])
    shades = []
    for ob in every:
        attr = ob.data.color_attributes.get("lp") if ob.name.startswith("brow") else None
        if attr:
            shades += [tuple(d.color)[:3] for d in attr.data]
    if not shades:
        return eyes, None
    mean = [sum(c[i] for c in shades) / len(shades) for i in range(3)]
    return eyes, [round(255 * (c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055)) for c in mean]


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    draft = "--draft" in args
    beauty = "--beauty" in args
    wanted = [a for a in args if not a.startswith("--")]
    manifest = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)
    failed = []
    for asset in specs():
        name = asset["name"]
        if wanted and name not in wanted:
            continue
        started = time.time()
        print(f"[stations] building {name}", flush=True)
        try:
            kit.reset()
            groups = asset["build"]()
            glow = asset.get("glow", {})
            if glow:
                kit.GLOW_RGB = next(iter(glow.values()))
            every = [ob for objs in groups.values() for ob in objs]
            scale = asset.get("scale", 1)  # shapes are written at a handy size: this is the real one
            for ob in every:
                ob.data.transform(Matrix.Scale(scale, 4))
            lo, hi = kit._ground_dims(every)
            if beauty:
                kit.beauty(name, groups, lo, hi, glow)
                continue
            if draft:
                kit.preview(name, every, lo, hi)
                print(f"[stations] {name}: draft previews, {sum(kit._tris(o) for o in every)} tris, {time.time() - started:.0f}s", flush=True)
                continue
            # finalize moves the model so the ground under its middle is the origin
            offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
            eyes, lid = eyes_of(every, offset)
            stats = kit.finalize(name, groups, asset["budget"], **asset.get("finalize", {}))
            if stats["tris"] > asset["budget"]:
                raise ValueError(f"{name}: {stats['tris']} tris is over the budget {asset['budget']} (decimation would move the joints)")
            centres = {}
            for part in groups:
                plo, phi = kit._ground_dims([bpy.data.objects[f"{name}_{part}"]])
                centres[f"{name}_{part}"] = roblox((plo + phi) / 2)
        except Exception:
            traceback.print_exc()
            failed.append(name)
            continue
        manifest[name] = {
            **stats,
            "tris_budget": asset["budget"],
            "script": asset["script"],
            "notes": asset.get("notes", ""),
            # Neon colour (sRGB) per glow mesh; the game sets those meshes to Neon in it.
            "glow": {f"{name}_{part}": list(rgb) for part, rgb in glow.items()},
            "centres": centres,
            "joints": {f"{name}_{part}": roblox(Vector(j) * scale + offset) for part, j in asset["joints"].items()},
        }
        if asset.get("finalize", {}).get("center") is False:
            manifest[name]["lift"] = round(lo.z, 3)
        if eyes:
            manifest[name]["eyes"], manifest[name]["lid"] = eyes, lid
        print(f"[stations] {name}: {stats['tris']} tris, {time.time() - started:.0f}s", flush=True)
    if not draft and not beauty:
        with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, indent=2)
            f.write("\n")
    if failed:
        print(f"[stations] FAILED: {', '.join(failed)}")
        sys.exit(1)


main()
