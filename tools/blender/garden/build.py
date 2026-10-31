"""Builds the Egg Garden assets headless. See README.md.

blender --background --factory-startup --python tools/blender/garden/build.py -- [asset ...]

With no names, builds every asset in assets/*.py. Writes build/blender/garden/<asset>.fbx/.png,
previews/<asset>.png, contact_sheet.png, and updates tools/blender/garden/manifest.json. A full
build also renders eggs_lineup.png from the exported eggs.
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

import kit  # noqa: E402
import lineup  # noqa: E402

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
            asset["script"] = f"tools/blender/garden/assets/{file}"
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
        print(f"[garden] building {name}", flush=True)
        try:
            kit.reset()
            groups = asset["build"]()
            stats = kit.finalize(name, groups, asset["budget"])
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
            "glow": {f"{name}_{part}": list(rgb) for part, rgb in asset.get("glow", {}).items()},
        }
        print(f"[garden] {name}: {stats['tris']} tris{' OVER BUDGET' if over else ''}, {time.time() - started:.0f}s", flush=True)
    order = [a["name"] for a in all_specs if a["name"] in manifest]
    manifest = {n: manifest[n] for n in order}
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    kit.reset()
    sheet = kit.contact_sheet(order, cols=5)
    print(f"[garden] contact sheet: {sheet}")
    if not wanted and not failed:
        lineup.render(manifest)
    if failed:
        print(f"[garden] FAILED: {', '.join(failed)}")
        sys.exit(1)


main()
