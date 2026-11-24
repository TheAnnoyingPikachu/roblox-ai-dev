"""Looping labelled WebPs of one model's magic concepts (the whole frame: the camera already frames the caster,
the target and the sky). gifs_magic.py <model out dir> <gif dir>"""
import glob
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
fit = json.load(open(os.path.join(src, "fit_magic_full.json"), encoding="utf-8"))
font = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 18)
small = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 14)
W, H, TOP, BOT = 480, 352, 28, 24
for key, v in fit["clips"].items():
    ims = [Image.open(f).convert("RGB") for f in sorted(glob.glob(os.path.join(src, "frames", f"{key}_*.png")))]
    out = []
    for i, im in enumerate(ims):
        c = Image.new("RGB", (W, H), (36, 33, 44))
        c.paste(im.resize((W, H - TOP - BOT), Image.LANCZOS), (0, TOP))
        d = ImageDraw.Draw(c)
        d.text((8, 3), v["label"], fill=(255, 214, 120), font=font)
        d.text((W - 8, 6), "POWER", fill=(170, 160, 190), font=small, anchor="ra")
        t = i / 24
        d.text((8, H - 21), "power" if 0.5 <= t <= 2.1 else "idle", fill=(170, 160, 190), font=small)
        if abs(t - 1.42) <= 0.05:
            d.text((W - 8, H - 24), "HIT!", fill=(255, 96, 72), font=font, anchor="ra")
        out.append(c)
    name = f"{fit['asset']}_{key}.webp"
    out[0].save(os.path.join(dst, name), save_all=True, append_images=out[1:], duration=42, loop=0, quality=78, method=4)
    print(name, len(out), os.path.getsize(os.path.join(dst, name)) // 1024, "KB")
