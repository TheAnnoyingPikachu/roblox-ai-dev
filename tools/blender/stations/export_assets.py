"""Copies the built Animal Stations assets into assets/stations/ (committed, read by the upload
workflow).

python tools/blender/stations/export_assets.py [--rainbow] [asset ...]

Run after build.py. FBX files are copied as is; textures stay full RGB (a palette would dither the
soft shading into grain). Needs Pillow (pip install pillow).
--rainbow copies the rainbow coats instead (decision 0058): what rainbow.py painted in
build/blender/stations/rainbow/<asset>.png becomes assets/stations/<asset>_rainbow.png.
"""

import json
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "stations")

with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
    manifest = json.load(f)
os.makedirs(OUT, exist_ok=True)
rainbow = "--rainbow" in sys.argv
wanted = [a for a in sys.argv[1:] if not a.startswith("--")]
for name, entry in manifest.items():
    if wanted and name not in wanted:
        continue
    if rainbow:
        coat = os.path.join(ROOT, "build", "blender", "stations", "rainbow", f"{name}.png")
        if os.path.exists(coat):
            png = os.path.join(OUT, f"{name}_rainbow.png")
            Image.open(coat).convert("RGB").save(png, optimize=True)
            print(f"exported {name}_rainbow ({os.path.getsize(png) // 1024} KB texture)")
        continue
    shutil.copyfile(os.path.join(ROOT, entry["fbx"]), os.path.join(OUT, f"{name}.fbx"))
    png = os.path.join(OUT, f"{name}.png")
    Image.open(os.path.join(ROOT, entry["png"])).convert("RGB").save(png, optimize=True)
    print(f"exported {name} ({os.path.getsize(png) // 1024} KB texture)")
