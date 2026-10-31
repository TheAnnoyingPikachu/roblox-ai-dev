"""Copies the built Night assets into assets/night/ (committed, read by the upload workflow).

python tools/blender/night/export_assets.py [asset ...]

Run after build.py; with names, exports only those. FBX files are copied as is; textures are re-saved as 256-colour dithered PNGs
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
OUT = os.path.join(ROOT, "assets", "night")

with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
    manifest = json.load(f)
os.makedirs(OUT, exist_ok=True)
for name, entry in manifest.items():
    if sys.argv[1:] and name not in sys.argv[1:]:
        continue
    shutil.copyfile(os.path.join(ROOT, entry["fbx"]), os.path.join(OUT, f"{name}.fbx"))
    image = Image.open(os.path.join(ROOT, entry["png"])).convert("RGB")
    image.quantize(256, dither=Image.Dither.FLOYDSTEINBERG).save(os.path.join(OUT, f"{name}.png"), optimize=True)
    print(f"exported {name}")
