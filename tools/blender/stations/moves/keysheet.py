"""One review sheet per animal: a row per concept, its key poses left to right.
keysheet.py <animal out dir> <sheet.jpg> [only prefix,...]"""
import glob
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
only = sys.argv[3].split(",") if len(sys.argv) > 3 else None
font = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 15)
rows = {}
for f in sorted(glob.glob(os.path.join(src, "keys", "*.png"))):
    b = os.path.basename(f)[:-4]
    key = "_".join(b.split("_")[:-2])
    if only and not any(key.startswith(o) for o in only):
        continue
    rows.setdefault(key, []).append((b.split("_")[-1], Image.open(f).convert("RGB")))
W, H = 240, 200
cols = max(len(v) for v in rows.values())
sheet = Image.new("RGB", (W * cols, H * len(rows)), (0, 0, 0))
for y, (key, ims) in enumerate(rows.items()):
    base = ims[0][1]
    box = (int(base.width * 0.1), int(base.height * 0.05), int(base.width * 0.9), int(base.height * 0.95))
    for x, (t, im) in enumerate(ims):
        c = im.crop(box)
        c.thumbnail((W, H))
        cell = Image.new("RGB", (W, H), (36, 33, 44))
        cell.paste(c, ((W - c.width) // 2, (H - c.height) // 2))
        ImageDraw.Draw(cell).text((4, 2), f"{key} {t}", fill=(255, 214, 120), font=font)
        sheet.paste(cell, (x * W, y * H))
sheet.save(out, quality=88)
