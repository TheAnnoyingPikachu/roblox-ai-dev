"""Looping labelled GIFs of one animal's concepts. gifs.py <animal out dir> <gif dir>
(reads fit_full.json and frames/, writes <asset>_<key>.gif and prints them)"""
import glob
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
fit = json.load(open(os.path.join(src, "fit_full.json"), encoding="utf-8"))
font = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 18)
small = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 14)
bg = Image.open(os.path.join(src, "bg.png")).convert("RGB")
W, H, TOP, BOT = 380, 330, 28, 24
PAD = 200


def padded(im):
    """the frame grown by PAD on every side by repeating its edge rows and columns (floor and backdrop)"""
    import numpy as np
    return Image.fromarray(np.pad(np.asarray(im), ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge"))
items = [(k, v["label"], "idle", None) for k, v in fit["idles"].items()]
items += [(k, v["label"], v["kind"], 0.5 + (0.44 if v["kind"] == "attack" else 0.92)) for k, v in fit["clips"].items()]
for key, label, kind, hit in items:
    ims = [Image.open(f).convert("RGB") for f in sorted(glob.glob(os.path.join(src, "frames", f"{key}_*.png")))]
    box = None
    for im in ims:
        b = ImageChops.difference(im, bg).convert("L").point(lambda v: 255 if v > 14 else 0).getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    x0, y0, x1, y1 = box
    m = 14
    x0, y0, x1, y1 = x0 - m, y0 - m, x1 + m, y1 + m
    want = W / (H - TOP - BOT)  # grow the box to the GIF's shape round its middle
    if (x1 - x0) / (y1 - y0) < want:
        grow = (y1 - y0) * want - (x1 - x0)
        x0, x1 = x0 - grow / 2, x1 + grow / 2
    else:
        grow = (x1 - x0) / want - (y1 - y0)
        y0, y1 = y0 - grow / 2, y1 + grow / 2
    if box[0] < 2 or box[1] < 2 or box[2] > bg.width - 2 or box[3] > bg.height - 2:  # the animal itself reaches the edge
        print('OUT OF FRAME', key, round(x0), round(y0), round(x1), round(y1), bg.size)
    fps = 12 if kind == "idle" else 24
    tag = {"idle": "IDLE", "attack": "ATTACK", "power": "POWER"}[kind]
    out = []
    for i, im in enumerate(ims):
        f = padded(im).crop((round(x0) + PAD, round(y0) + PAD, round(x1) + PAD, round(y1) + PAD)).resize((W, H - TOP - BOT), Image.LANCZOS)
        c = Image.new("RGB", (W, H), (36, 33, 44))
        c.paste(f, (0, TOP))
        d = ImageDraw.Draw(c)
        d.text((8, 3), label, fill=(255, 214, 120), font=font)
        d.text((W - 8, 6), tag, fill=(170, 160, 190), font=small, anchor="ra")
        if hit is not None:
            t = i / fps
            phase = kind if 0.5 <= t <= 0.5 + (0.95 if kind == "attack" else 1.6) else "idle"
            d.text((8, H - 21), phase, fill=(170, 160, 190), font=small)
            if abs(t - hit) <= 0.05:
                d.text((W - 8, H - 24), "HIT!", fill=(255, 96, 72), font=font, anchor="ra")
        out.append(c)
    name = f"{fit['asset']}_{key}.webp"
    out[0].save(os.path.join(dst, name), save_all=True, append_images=out[1:], duration=round(1000 / fps), loop=0, quality=80, method=4)
    print(name, len(out), os.path.getsize(os.path.join(dst, name)) // 1024, "KB")
