"""Draws the 20 Lantern Express UI icons (HUD and panels; LANTERN-015).

    python tools/icons/lantern/make_icons.py [out_dir]

Writes lantern_icon_<name>.png, 128 x 128 RGBA, into out_dir (default assets/lantern/icons), plus
contact_sheet.png on the dusk teal. The style rules of tools/icons/make_icons.py (Egg Garden): flat
shapes, WHITE fill, 6 px INK outline, one accent, 8 px safe margin, drawn at 4x and box-filtered
down, no randomness (a re-run gives identical bytes). INK and the accents are the art bible's
(docs/game-design/game6-art-bible.md sections 2 and 7): night-plum ink, Lantern Amber the hero.
Pillow 13.0.0 (pinned: a different resampler build may change the anti-aliased bytes).
"""

import math
import os
import sys

from PIL import Image, ImageDraw

SIZE, SS = 128, 4  # output size and supersampling
S = SIZE * SS
INK = (52, 40, 78, 255)  # art bible 7 INK
WHITE = (255, 255, 255, 255)
AMBER = (255, 176, 64, 255)  # Lantern Amber, the hero
RED = (196, 52, 62, 255)  # Lamplight Red
TEAL = (62, 128, 140, 255)  # Dusk Teal
LILAC = (170, 120, 230, 255)  # lantern violet
MOSS = (120, 170, 110, 255)
PEACH = (246, 168, 140, 255)  # Horizon Peach
OUT = 6 * SS  # outline width
ICON_SET = [
    "coal", "lantern", "ticket", "xp", "parts", "oil", "crate", "critter", "lamp", "stoke",
    "mend", "ping", "album", "locker", "rewards", "board", "settings", "depot", "train", "close",
]


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
    """Thick line with an outline (handles, spouts, the close X)."""
    flat = [(x * SS, y * SS) for x, y in pts]
    for col, width in ((outline, w * SS + 2 * OUT), (colour, w * SS)):
        if col:
            d.line(flat, fill=col, width=width, joint="curve")
            for p in (flat[0], flat[-1]):
                d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=col)


def dot(d, cx, cy, r, fill=INK):
    ell(d, (cx - r, cy - r, cx + r, cy + r), fill, outline=None)


def star_pts(cx, cy, r_out, r_in, n=5):
    return [
        (cx + (r_out if i % 2 == 0 else r_in) * math.cos(-math.pi / 2 + math.pi * i / n),
         cy + (r_out if i % 2 == 0 else r_in) * math.sin(-math.pi / 2 + math.pi * i / n))
        for i in range(2 * n)
    ]


def gear_pts(cx, cy, r, teeth=8):
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        rr = r if (i % 4) in (0, 1) else r * 0.74
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def drop_pts(cx, cy, r, tip):
    """A drop: a circle of radius r centred at (cx, cy) drawn up to a point `tip` above."""
    pts = [(cx, cy - tip)]
    for i in range(1, 32):
        a = -math.pi / 2 + math.radians(30) + (2 * math.pi - math.radians(60)) * i / 32
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def coal(d):  # a coal sack: lumps heaped in the mouth, an amber tie, a round white sack
    for cx, cy, r in ((46, 30, 12), (68, 22, 14), (88, 32, 11)):
        dot(d, cx, cy, r)
    poly(d, [(30, 34), (98, 34), (86, 58), (42, 58)], WHITE)
    poly(d, [(44, 58), (84, 58), (108, 84), (104, 106), (90, 116), (38, 116), (24, 106), (20, 84)], WHITE)
    rect(d, (36, 50, 92, 72), AMBER, r=8)


def lantern(d):  # a brass lantern: handle, cap, amber glass, base
    stroke(d, [(48, 26), (52, 12), (76, 12), (80, 26)], WHITE, 5)
    rect(d, (36, 24, 92, 38), WHITE, r=6)
    rect(d, (40, 38, 88, 98), AMBER, r=14)
    d.line(px(64, 42, 64, 94), fill=INK, width=OUT // 2)
    rect(d, (32, 98, 96, 114), WHITE, r=6)


def ticket(d):  # a train ticket with notched sides and an amber star
    pts = [(14, 32), (114, 32), (114, 52)]
    pts += [(114 - 10 * math.sin(math.pi * i / 8), 64 - 12 * math.cos(math.pi * i / 8)) for i in range(1, 8)]
    pts += [(114, 76), (114, 96), (14, 96), (14, 76)]
    pts += [(14 + 10 * math.sin(math.pi * i / 8), 64 + 12 * math.cos(math.pi * i / 8)) for i in range(1, 8)]
    pts += [(14, 52)]
    poly(d, pts, WHITE)
    for y in range(38, 92, 10):
        d.line(px(86, y, 86, y + 5), fill=INK, width=OUT // 2)
    poly(d, star_pts(52, 64, 20, 9), AMBER)


def xp(d):  # a big star with an amber heart and two sparkles
    poly(d, star_pts(60, 68, 50, 22), WHITE)
    poly(d, star_pts(60, 70, 20, 9), AMBER, outline=None)
    for cx, cy, r in ((104, 22, 9), (112, 46, 5)):
        poly(d, [(cx, cy - r * 1.6), (cx + r * 0.5, cy), (cx, cy + r * 1.6), (cx - r * 0.5, cy)], AMBER, outline=None)


def parts(d):  # an open wrench over a teal hex nut
    nut = [(38 + 22 * math.cos(math.pi / 3 * i), 90 + 22 * math.sin(math.pi / 3 * i)) for i in range(6)]
    poly(d, nut, TEAL)
    ell(d, (29, 81, 47, 99), WHITE)
    stroke(d, [(52, 76), (80, 48)], WHITE, 13)
    cx, cy = 88, 40  # the head: a C open towards the top right, jaw notch inside
    arc = [math.radians(-15 + 300 * i / 30) for i in range(31)]
    head = [(cx + 24 * math.cos(a), cy + 24 * math.sin(a)) for a in arc]
    head += [(cx + 9 * math.cos(arc[-1]), cy + 9 * math.sin(arc[-1])), (cx + 9 * math.cos(arc[0]), cy + 9 * math.sin(arc[0]))]
    poly(d, head, WHITE)


def oil(d):  # an oil can with a spout and an amber drop
    rect(d, (16, 58, 84, 112), WHITE, r=10)
    rect(d, (34, 42, 66, 60), WHITE, r=5)
    stroke(d, [(80, 70), (108, 42)], WHITE, 7)
    poly(d, drop_pts(108, 92, 11, 26), AMBER)


def crate(d):  # a plank crate with an amber brace
    rect(d, (16, 22, 112, 108), WHITE, r=8)
    stroke(d, [(30, 92), (98, 38)], AMBER, 9)
    for y in (50, 80):
        d.line(px(16, y, 112, y), fill=INK, width=OUT // 2)
    rect(d, (16, 22, 112, 108), None, r=8)


def critter(d):  # a round critter face with peach blush
    for sx in (-1, 1):
        poly(d, [(64 + sx * 26, 46), (64 + sx * 44, 14), (64 + sx * 48, 52)], WHITE)
    ell(d, (16, 30, 112, 114), WHITE)
    for sx in (-1, 1):
        dot(d, 64 + sx * 18, 68, 8)
        dot(d, 64 + sx * 15, 64, 3, WHITE)
        ell(d, (64 + sx * 30 - 9, 82, 64 + sx * 30 + 9, 92), PEACH, outline=None)
    dot(d, 64, 84, 4)


def lamp(d):  # a turret lamp throwing an amber beam
    poly(d, [(56, 52), (118, 18), (118, 92)], AMBER)
    rect(d, (14, 38, 62, 80), WHITE, r=10)
    rect(d, (28, 80, 48, 112), WHITE, r=4)
    ell(d, (42, 46, 62, 72), WHITE)


def stoke(d):  # a flame: amber outer, white heart, on a white coal bed
    poly(d,[(64, 10), (88, 44), (98, 72), (90, 98), (64, 108), (38, 98), (30, 72), (40, 44)], AMBER)
    poly(d, [(64, 50), (76, 72), (78, 90), (64, 100), (50, 90), (52, 72)], WHITE, outline=None)
    rect(d, (22, 104, 106, 118), WHITE, r=6)


def mend(d):  # an oil drop with a moss plus
    poly(d, drop_pts(64, 76, 38, 66), WHITE)
    stroke(d, [(64, 58), (64, 94)], MOSS, 10, outline=None)
    stroke(d, [(46, 76), (82, 76)], MOSS, 10, outline=None)


def ping(d):  # a map pin with an amber dot
    pts = [(64, 116)]
    for i in range(1, 40):
        a = math.radians(130) + math.radians(280) * i / 40
        pts.append((64 + 40 * math.cos(a), 50 + 40 * math.sin(a)))
    poly(d, pts, WHITE)
    ell(d, (46, 32, 82, 68), AMBER)


def album(d):  # a lilac album with a paw on the cover
    rect(d, (20, 14, 108, 114), LILAC, r=8)
    rect(d, (30, 14, 108, 114), WHITE, r=8)
    d.line(px(30, 14, 30, 114), fill=INK, width=OUT)
    for cx, cy in ((54, 50), (68, 42), (84, 50)):
        dot(d, cx, cy, 7)
    ell(d, (52, 58, 86, 86), INK, outline=None)


def locker(d):  # a two-door locker with teal handles and vents
    rect(d, (22, 10, 106, 116), WHITE, r=8)
    d.line(px(64, 10, 64, 116), fill=INK, width=OUT)
    for x in (34, 74):
        for y in (24, 32):
            d.line(px(x, y, x + 20, y), fill=INK, width=OUT // 2)
    for x in (54, 74):
        rect(d, (x - 4, 58, x + 4, 80), TEAL, r=3)


def rewards(d):  # a gift box with a Lamplight Red ribbon
    rect(d, (18, 50, 110, 112), WHITE, r=10)
    rect(d, (12, 36, 116, 60), WHITE, r=8)
    d.rectangle(px(54, 36, 74, 112), fill=RED, outline=INK, width=OUT)
    for sx in (-1, 1):
        ell(d, (64 + sx * 26 - 16, 12, 64 + sx * 26 + 16, 40), RED)


def board(d):  # a notice board on legs, lines of names and an amber pin
    for x in (34, 94):
        rect(d, (x - 5, 70, x + 5, 118), WHITE, r=3)
    rect(d, (12, 14, 116, 86), WHITE, r=8)
    for i, y in enumerate((36, 52, 68)):
        d.line(px(28, y, 100 - 16 * i, y), fill=INK, width=OUT)
    ell(d, (88, 22, 108, 42), AMBER)


def settings(d):  # a cog with a lilac hub
    poly(d, gear_pts(64, 64, 52), WHITE)
    ell(d, (46, 46, 82, 82), LILAC)


def depot(d):  # the Depot: a station house with an amber clock
    rect(d, (16, 56, 112, 114), WHITE, r=6)
    poly(d, [(64, 12), (118, 58), (10, 58)], WHITE)
    ell(d, (50, 26, 78, 54), AMBER)
    d.line(px(64, 40, 64, 31), fill=INK, width=OUT // 2)
    d.line(px(64, 40, 71, 40), fill=INK, width=OUT // 2)
    rect(d, (54, 80, 74, 114), WHITE, r=4)


def train(d):  # a toy engine: boiler, cab, chimney, wheels, amber headlamp
    rect(d, (70, 30, 112, 92), WHITE, r=6)
    rect(d, (22, 52, 80, 92), WHITE, r=14)
    poly(d, [(32, 18), (50, 18), (46, 30), (46, 52), (36, 52), (36, 30)], WHITE)
    for cx in (40, 92):
        ell(d, (cx - 15, 82, cx + 15, 112), WHITE)
        dot(d, cx, 97, 5)
    ell(d, (6, 56, 30, 80), AMBER)


def close(d):  # a Lamplight Red disc with a white X
    ell(d, (12, 12, 116, 116), RED)
    stroke(d, [(42, 42), (86, 86)], WHITE, 12)
    stroke(d, [(86, 42), (42, 86)], WHITE, 12)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "assets", "lantern", "icons")
    os.makedirs(out, exist_ok=True)
    tiles = []
    for name in ICON_SET:
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        globals()[name](ImageDraw.Draw(img))
        img = img.resize((SIZE, SIZE), Image.Resampling.BOX)
        img.save(os.path.join(out, f"lantern_icon_{name}.png"), optimize=True)
        tiles.append(img)
    sheet = Image.new("RGBA", (10 * 144, 2 * 144), (62, 128, 140, 255))  # Dusk Teal
    for i, t in enumerate(tiles):
        sheet.paste(t, (8 + 144 * (i % 10), 8 + 144 * (i // 10)), t)
    sheet.save(os.path.join(out, "contact_sheet.png"))
    print(f"wrote {len(tiles)} icons to {out}")


if __name__ == "__main__":
    main()
