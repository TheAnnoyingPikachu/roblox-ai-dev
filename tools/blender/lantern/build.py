"""Builds the Lantern Express assets headless. See README.md.

blender --background --factory-startup --python tools/blender/lantern/build.py -- [asset ...]

With no names, builds every asset in assets/*.py. Writes build/blender/lantern/<asset>.fbx/.png,
previews/<asset>.png, contact_sheet.png, and updates tools/blender/lantern/manifest.json. A full
build also renders style_test.png from the exported files.
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
import style_test  # noqa: E402

MANIFEST = os.path.join(HERE, "manifest.json")


def raw_tris(groups):
    """Triangles before finalize, modifiers included: over budget, finalize silently decimates
    everything (eyes and markings too), so the build says so."""
    objs = [o for g in (groups.values() if isinstance(groups, dict) else [groups]) for o in g if o.type == "MESH"]
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        total += len(me.loop_triangles)
        ev.to_mesh_clear()
    return total


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
            asset["script"] = f"tools/blender/lantern/assets/{file}"
            found.append(asset)
    return sorted(found, key=lambda a: (a["priority"], a["order"]))


def main():
    wanted = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    manifest = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)
    all_specs = specs()
    failed = []
    for asset in all_specs:
        name = asset["name"]
        if wanted and name not in wanted:
            continue
        started = time.time()
        print(f"[lantern] building {name}", flush=True)
        glow = {f"{name}_{part}": list(rgb) for part, rgb in asset.get("glow", {}).items()}
        try:
            kit.reset()
            kit.GLOW.clear()
            kit.GLOW.update(glow)
            groups = asset["build"]()
            raw = raw_tris(groups)
            if raw > asset["budget"]:
                print(f"[lantern] {name}: {raw} raw tris over the {asset['budget']} budget: finalize DECIMATES it, trim the model", flush=True)
            stats = kit.finalize(name, groups, asset["budget"], **asset.get("finalize", {}))
        except Exception:
            traceback.print_exc()
            failed.append(name)
            continue
        over = stats["tris"] > asset["budget"]
        manifest[name] = {
            **stats,
            "target_size_studs": asset["size"],
            "tris_budget": asset["budget"],
            "priority": f"P{asset['priority']}",
            "replaces": asset["replaces"],
            "script": asset["script"],
            "notes": asset.get("notes", ""),
            # Neon colour (sRGB) per glow mesh; the game sets those meshes to Neon in it.
            "glow": glow,
        }
        print(f"[lantern] {name}: {stats['tris']} tris{' OVER BUDGET' if over else ''}, size {stats['size_studs']}, {time.time() - started:.0f}s", flush=True)
    order = [a["name"] for a in all_specs if a["name"] in manifest]
    manifest = {n: manifest[n] for n in order}
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    kit.reset()
    sheet = kit.contact_sheet(order, cols=3)
    print(f"[lantern] contact sheet: {sheet}")
    if not wanted and not failed:
        style_test.render(manifest)
    if failed:
        print(f"[lantern] FAILED: {', '.join(failed)}")
        sys.exit(1)


main()
