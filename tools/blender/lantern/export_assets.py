"""Copies the built Lantern Express assets into assets/lantern/ (committed, read by the upload workflow).

python tools/blender/lantern/export_assets.py [asset ...]

Run after build.py. Names limit the export to those assets (the rest need not be built). FBX files
are copied as is. Textures stay full RGB (architecture section 9: every asset is full RGB with
baked AO; a 256-colour palette dithers the soft AO and gradients into grain). Needs Pillow.
"""

import json
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "lantern")

with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
    manifest = json.load(f)
os.makedirs(OUT, exist_ok=True)
wanted = sys.argv[1:]
for name, entry in manifest.items():
    if wanted and name not in wanted:
        continue
    shutil.copyfile(os.path.join(ROOT, entry["fbx"]), os.path.join(OUT, f"{name}.fbx"))
    png = os.path.join(OUT, f"{name}.png")
    Image.open(os.path.join(ROOT, entry["png"])).convert("RGB").save(png, optimize=True)
    print(f"exported {name} ({os.path.getsize(png) // 1024} KB texture)")
