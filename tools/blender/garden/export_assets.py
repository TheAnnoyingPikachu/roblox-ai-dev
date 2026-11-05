"""Copies the built Garden assets into assets/garden/ (committed, read by the upload workflow).

python tools/blender/garden/export_assets.py [asset ...]

Run after build.py. Names limit the export to those assets (the rest need not be built). FBX files are copied as is; textures are re-saved as 256-colour dithered PNGs
(visually identical for these baked textures, about half the size) to keep the repo small.
Needs Pillow (pip install pillow).
"""

import json
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "garden")

with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
    manifest = json.load(f)
os.makedirs(OUT, exist_ok=True)
wanted = sys.argv[1:]
for name, entry in manifest.items():
    if wanted and name not in wanted:
        continue
    shutil.copyfile(os.path.join(ROOT, entry["fbx"]), os.path.join(OUT, f"{name}.fbx"))
    image = Image.open(os.path.join(ROOT, entry["png"])).convert("RGB")
    image.quantize(256, dither=Image.Dither.FLOYDSTEINBERG).save(os.path.join(OUT, f"{name}.png"), optimize=True)
    print(f"exported {name}")
