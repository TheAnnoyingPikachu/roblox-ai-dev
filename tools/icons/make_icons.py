"""Draws the 16 Egg Garden UI icons (GardenConfig.ICON_SET; architecture 9.3, GDD X1.5).

    python -I tools/icons/make_icons.py [out_dir]

Writes garden_icon_<name>.png, 128 x 128 RGBA, into out_dir (default assets/garden/icons).
Flat shapes: WHITE fill, 6 px INK outline, one pastel accent, 8 px safe margin. Deterministic:
no randomness, drawn at 4x and box-filtered down, so a re-run gives identical bytes.
Pillow 13.0.0 (pinned: a different resampler build may change the anti-aliased bytes).
"""

import os
import sys

from PIL import Image, ImageDraw

SIZE, SS = 128, 4  # output size and supersampling
S = SIZE * SS
INK = (74, 58, 72, 255)
WHITE = (255, 255, 255, 255)
PINK = (255, 150, 185, 255)
GOLD = (255, 196, 64, 255)
LEAF = (70, 170, 110, 255)
SKY = (130, 200, 255, 255)
LILAC = (190, 160, 240, 255)
CORAL = (255, 120, 110, 255)
AQUA = (70, 190, 205, 255)
OUT = 6 * SS  # outline width
ICON_SET = ["coin", "egg", "paw", "book", "hanger", "gift", "flag", "petal", "home", "chart", "cog", "heart", "swap", "calendar", "lock", "check"]


def px(*v):
    """Design units (0-128) to supersampled pixels."""
    return [c * SS for c in v]


def ell(d, box, fill, outline=INK):
    d.ellipse(px(*box), fill=fill, outline=outline, width=OUT if outline else 0)


def rect(d, box, fill, r=8, outline=INK):
    d.rounded_rectangle(px(*box), radius=r * SS, fill=fill, outline=outline, width=OUT if outline else 0)


def poly(d, pts, fill, outline=INK):
    flat = [(x * SS, y * SS) for x, y in pts]
    if outline:
        d.line(flat + flat[:1], fill=outline, width=OUT, joint="curve")
        for p in flat:  # round the corners the joint misses
            d.ellipse([p[0] - OUT / 2, p[1] - OUT / 2, p[0] + OUT / 2, p[1] + OUT / 2], fill=outline)
    d.polygon(flat, fill=fill)
    if outline:
        d.line(flat + flat[:1], fill=outline, width=OUT // 2, joint="curve")


def stroke(d, pts, colour, w, outline=INK):
    """Thick line with an outline (hanger, swap arrows, check)."""
    flat = [(x * SS, y * SS) for x, y in pts]
    for col, width in ((outline, w * SS + 2 * OUT), (colour, w * SS)):
        if col:
            d.line(flat, fill=col, width=width, joint="curve")
            for p in (flat[0], flat[-1]):
                d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=col)


def heart_pts(cx, cy, s):
    import math

    pts = []
    for i in range(64):
        t = 2 * math.pi * i / 64
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * s, cy + y * s))
    return pts


def egg_pts(cx, cy, w, h):
    import math

    return [(cx + w * math.cos(t) * (1 - 0.18 * math.sin(t)), cy - h * math.sin(t)) for t in (2 * math.pi * i / 64 for i in range(64))]


def gear_pts(cx, cy, r, teeth=8):
    import math

    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        rr = r if (i % 4) in (0, 1) else r * 0.74
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def coin(d):
    ell(d, (16, 16, 112, 112), GOLD)
    ell(d, (34, 34, 94, 94), WHITE)
    poly(d, [(64, 44), (76, 58), (70, 86), (58, 86), (52, 58)], GOLD, outline=None)


def egg(d):
    poly(d, egg_pts(64, 66, 36, 46), WHITE)
    for cx, cy, r in ((52, 56, 7), (76, 70, 8), (58, 86, 6)):
        ell(d, (cx - r, cy - r, cx + r, cy + r), PINK, outline=None)


def paw(d):
    for cx, cy in ((34, 44), (56, 28), (82, 30), (102, 48)):
        ell(d, (cx - 12, cy - 15, cx + 12, cy + 15), WHITE)
    poly(d, [(64, 50), (90, 62), (100, 86), (84, 108), (64, 100), (44, 108), (28, 86), (38, 62)], WHITE)
    poly(d, [(64, 62), (82, 70), (88, 86), (76, 98), (64, 92), (52, 98), (40, 86), (46, 70)], PINK, outline=None)


def book(d):
    rect(d, (16, 24, 64, 104), LEAF, r=6)
    rect(d, (64, 24, 112, 104), WHITE, r=6)
    for y in (46, 60, 74):
        d.line(px(74, y, 102, y), fill=LEAF, width=OUT)
    d.line(px(64, 24, 64, 104), fill=INK, width=OUT)


def hanger(d):
    stroke(d, [(64, 44), (64, 34), (72, 26), (66, 16), (58, 20)], WHITE, 6)
    poly(d, [(64, 44), (116, 88), (112, 100), (16, 100), (12, 88)], LILAC)


def gift(d):
    rect(d, (18, 50, 110, 112), WHITE, r=10)
    rect(d, (12, 36, 116, 60), WHITE, r=8)
    d.rectangle(px(54, 36, 74, 112), fill=CORAL, outline=INK, width=OUT)
    for sx in (-1, 1):
        ell(d, (64 + sx * 26 - 16, 12, 64 + sx * 26 + 16, 40), CORAL)


def flag(d):
    rect(d, (26, 12, 38, 116), WHITE, r=5)
    poly(d, [(38, 20), (108, 34), (90, 50), (108, 70), (38, 82)], AQUA)


def petal(d):
    import math

    for i in range(5):
        a = -math.pi / 2 + 2 * math.pi * i / 5
        cx, cy = 64 + 30 * math.cos(a), 64 + 30 * math.sin(a)
        ell(d, (cx - 20, cy - 20, cx + 20, cy + 20), WHITE)
    ell(d, (46, 46, 82, 82), PINK)


def home(d):
    rect(d, (28, 58, 100, 112), WHITE, r=6)
    poly(d, [(64, 14), (116, 62), (12, 62)], CORAL)
    rect(d, (54, 78, 74, 112), SKY, r=4)


def chart(d):
    for i, (x, h, col) in enumerate(((20, 36, WHITE), (52, 60, WHITE), (84, 90, SKY))):
        rect(d, (x, 112 - h, x + 26, 112), col, r=5)
    d.line(px(14, 114, 114, 114), fill=INK, width=OUT)


def cog(d):
    poly(d, gear_pts(64, 64, 52), WHITE)
    ell(d, (46, 46, 82, 82), LILAC)


def heart(d):
    poly(d, heart_pts(64, 58, 3.0), WHITE)
    poly(d, heart_pts(64, 60, 1.8), PINK, outline=None)


def swap(d):
    stroke(d, [(20, 44), (96, 44)], WHITE, 10)
    poly(d, [(88, 24), (116, 44), (88, 64)], PINK)
    stroke(d, [(108, 84), (32, 84)], WHITE, 10)
    poly(d, [(40, 64), (12, 84), (40, 104)], PINK)


def calendar(d):
    rect(d, (14, 26, 114, 112), WHITE, r=10)
    rect(d, (14, 26, 114, 52), CORAL, r=10)
    d.rectangle(px(14, 44, 114, 52), fill=CORAL)
    d.line(px(14, 52, 114, 52), fill=INK, width=OUT)
    for x in (38, 90):
        rect(d, (x - 5, 12, x + 5, 36), WHITE, r=4)
    for i in range(6):
        x, y = 34 + 26 * (i % 3), 68 + 22 * (i // 3)
        ell(d, (x - 5, y - 5, x + 5, y + 5), INK, outline=None)


def lock(d):
    stroke(d, [(40, 60), (40, 36), (52, 22), (76, 22), (88, 36), (88, 60)], GOLD, 10)
    rect(d, (20, 56, 108, 114), WHITE, r=10)
    ell(d, (56, 70, 72, 86), INK, outline=None)
    d.rectangle(px(60, 78, 68, 100), fill=INK)


def check(d):
    ell(d, (14, 14, 114, 114), WHITE)
    stroke(d, [(36, 66), (56, 86), (94, 44)], LEAF, 14)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "garden", "icons")
    os.makedirs(out, exist_ok=True)
    tiles = []
    for name in ICON_SET:
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        globals()[name](ImageDraw.Draw(img))
        img = img.resize((SIZE, SIZE), Image.Resampling.BOX)
        img.save(os.path.join(out, f"garden_icon_{name}.png"), optimize=True)
        tiles.append(img)
    sheet = Image.new("RGBA", (8 * 144, 2 * 144), (120, 170, 150, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, (8 + 144 * (i % 8), 8 + 144 * (i // 8)), t)
    sheet.save(os.path.join(out, "contact_sheet.png"))
    print(f"wrote {len(tiles)} icons to {out}")


if __name__ == "__main__":
    main()
