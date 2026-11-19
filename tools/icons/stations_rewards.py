"""Render the reward icons (decision 0100) to 256 x 256 PNGs with a clear background, with Edge headless."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

DEFS = """
<radialGradient id="gold" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="#ffe9a0"/><stop offset=".55" stop-color="#ffb52e"/><stop offset="1" stop-color="#d98a0b"/></radialGradient>
<radialGradient id="gem" cx="35%" cy="30%" r="80%"><stop offset="0" stop-color="#d4f7cf"/><stop offset=".5" stop-color="#5cbf4a"/><stop offset="1" stop-color="#2f8a2a"/></radialGradient>
<linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5a5a"/><stop offset=".25" stop-color="#ffb23a"/><stop offset=".45" stop-color="#ffe14a"/><stop offset=".62" stop-color="#5fd35f"/><stop offset=".8" stop-color="#4ab6ff"/><stop offset="1" stop-color="#b06df2"/></linearGradient>
<radialGradient id="shine" cx="35%" cy="28%" r="80%"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></radialGradient>
"""
INK = "#3a2412"
EGG = "M50 12 C 72 12 80 48 80 62 C 80 80 66 88 50 88 C 34 88 20 80 20 62 C 20 48 28 12 50 12 Z"
SHADOW = '<ellipse cx="50" cy="90" rx="28" ry="5" fill="#3a2412" opacity=".22"/>'


def egg(base, spots, extra=""):
    dots = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>' for x, y, r, c in spots)
    return f"""{SHADOW}<path d="{EGG}" fill="{base}" stroke="{INK}" stroke-width="5"/>{dots}{extra}
<path d="{EGG}" fill="url(#shine)"/><path d="M36 30 q4 -8 10 -10" stroke="#fff" stroke-width="5" fill="none" stroke-linecap="round"/>"""


ICONS = {
    "coins": f"""<ellipse cx="50" cy="86" rx="40" ry="7" fill="{INK}" opacity=".22"/>
<g stroke="{INK}" stroke-width="5">
<ellipse cx="32" cy="70" rx="20" ry="9" fill="#d98a0b"/><rect x="12" y="58" width="40" height="12" fill="#d98a0b"/><ellipse cx="32" cy="58" rx="20" ry="9" fill="url(#gold)"/>
<ellipse cx="68" cy="72" rx="20" ry="9" fill="#d98a0b"/><rect x="48" y="52" width="40" height="20" fill="#d98a0b"/><ellipse cx="68" cy="52" rx="20" ry="9" fill="url(#gold)"/>
<ellipse cx="50" cy="40" rx="20" ry="9" fill="#d98a0b"/><rect x="30" y="26" width="40" height="14" fill="#d98a0b"/><ellipse cx="50" cy="26" rx="20" ry="9" fill="url(#gold)"/></g>
<path d="M80 12 l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z" fill="#fff" stroke="{INK}" stroke-width="1.5"/>""",
    "samples": f"""{SHADOW}<g stroke="{INK}" stroke-width="5" stroke-linejoin="round">
<polygon points="26,38 42,22 58,38 42,84" fill="url(#gem)"/><polygon points="26,38 58,38 42,84" fill="#3e9b34"/>
<polygon points="50,50 64,36 78,50 64,86" fill="url(#gem)"/><polygon points="50,50 78,50 64,86" fill="#3e9b34"/></g>
<path d="M34 31 l6 -6" stroke="#fff" stroke-width="4" stroke-linecap="round"/>
<path d="M80 14 l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z" fill="#fff" stroke="{INK}" stroke-width="1.5"/>""",
    "egg_meadow": egg("#fff6dc", [(62, 34, 6, "#9fd879"), (38, 58, 7, "#9fd879"), (60, 70, 5, "#9fd879"), (44, 40, 4, "#bfe69a")]),
    "egg_wild": egg("#6fbf4a", [(62, 36, 6, "#6b4a2b"), (38, 56, 7, "#6b4a2b"), (60, 72, 5, "#6b4a2b"), (46, 76, 4, "#4f9b35")],
                    f'<path d="M24 66 q14 -10 26 0 t26 -2" stroke="{INK}" stroke-width="4" fill="none"/>'),
    "egg_safari": egg("#f2c66b", [(40, 44, 6, "#8b5a2b"), (62, 62, 7, "#8b5a2b"), (44, 72, 4, "#8b5a2b")],
                      f'<path d="M22 56 h56" stroke="#c0392b" stroke-width="6"/><path d="M22 56 h56" stroke="{INK}" stroke-width="1.5" fill="none"/>'),
    "egg_golden": egg("url(#gold)", [(50, 52, 6, "#b06df2"), (34, 64, 4, "#b06df2"), (66, 64, 4, "#b06df2")],
                      f'<path d="M26 44 h48" stroke="#d98a0b" stroke-width="4"/><path d="M80 18 l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z M18 70 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" fill="#fff" stroke="{INK}" stroke-width="1.5"/>'),
    "star": f"""<path d="M50 6 l12 26 28 3 -21 19 6 28 -25 -14 -25 14 6 -28 -21 -19 28 -3z" fill="#ffe14a" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
<path d="M42 28 l6 -10" stroke="#fff" stroke-width="5" stroke-linecap="round"/>""",
    "hatch2": f"""<ellipse cx="42" cy="90" rx="26" ry="5" fill="{INK}" opacity=".22"/>
<path d="M42 22 C 61 22 68 54 68 66 C 68 82 56 90 42 90 C 28 90 16 82 16 66 C 16 54 23 22 42 22 Z" fill="#fff6dc" stroke="{INK}" stroke-width="5"/>
<path d="M20 58 l8 -6 7 7 8 -8 8 8 7 -7 8 6" stroke="{INK}" stroke-width="5" fill="none" stroke-linejoin="round"/>
<circle cx="70" cy="30" r="24" fill="#4aa6e8" stroke="{INK}" stroke-width="5"/>
<text x="70" y="39" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="24" fill="#fff" stroke="{INK}" stroke-width="1.5">x2</text>""",
    "train2": f"""<ellipse cx="44" cy="88" rx="32" ry="5" fill="{INK}" opacity=".22"/>
<g stroke="{INK}" stroke-width="5" stroke-linejoin="round">
<rect x="10" y="52" width="12" height="30" rx="3" fill="#56586a"/><rect x="22" y="56" width="9" height="22" rx="2" fill="#7a7c8e"/>
<rect x="31" y="62" width="26" height="9" fill="#c9c6bd"/>
<rect x="57" y="56" width="9" height="22" rx="2" fill="#7a7c8e"/><rect x="66" y="52" width="12" height="30" rx="3" fill="#56586a"/></g>
<circle cx="70" cy="28" r="24" fill="#e2507a" stroke="{INK}" stroke-width="5"/>
<text x="70" y="37" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="24" fill="#fff" stroke="{INK}" stroke-width="1.5">x2</text>""",
    "rainbow": f"""{SHADOW}<g stroke="{INK}" stroke-width="5">
<ellipse cx="50" cy="64" rx="24" ry="20" fill="url(#rainbow)"/>
<ellipse cx="22" cy="38" rx="10" ry="12" fill="url(#rainbow)"/><ellipse cx="41" cy="24" rx="10" ry="12" fill="url(#rainbow)"/>
<ellipse cx="60" cy="24" rx="10" ry="12" fill="url(#rainbow)"/><ellipse cx="79" cy="38" rx="10" ry="12" fill="url(#rainbow)"/></g>
<path d="M86 74 l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z M12 72 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" fill="#fff" stroke="{INK}" stroke-width="1.5"/>""",
    "spin": f"""<ellipse cx="50" cy="92" rx="30" ry="5" fill="{INK}" opacity=".22"/>
<path d="M50 54 L50 18 A36 36 0 0 1 81 36 Z" fill="#ffb52e"/><path d="M50 54 L81 36 A36 36 0 0 1 81 72 Z" fill="#5cbf4a"/>
<path d="M50 54 L81 72 A36 36 0 0 1 50 90 Z" fill="#4aa6e8"/><path d="M50 54 L50 90 A36 36 0 0 1 19 72 Z" fill="#e2507a"/>
<path d="M50 54 L19 72 A36 36 0 0 1 19 36 Z" fill="#b06df2"/><path d="M50 54 L19 36 A36 36 0 0 1 50 18 Z" fill="url(#rainbow)"/>
<circle cx="50" cy="54" r="36" fill="none" stroke="{INK}" stroke-width="5"/><circle cx="50" cy="54" r="9" fill="#ffb52e" stroke="{INK}" stroke-width="4"/>
<path d="M42 4 h16 l-8 14z" fill="#e2507a" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>""",
    "gift": f"""<ellipse cx="50" cy="90" rx="34" ry="5" fill="{INK}" opacity=".22"/>
<g stroke="{INK}" stroke-width="5" stroke-linejoin="round">
<rect x="18" y="44" width="64" height="42" rx="4" fill="#5cbf4a"/><rect x="14" y="32" width="72" height="15" rx="4" fill="#78d468"/>
<rect x="43" y="32" width="14" height="54" fill="#ffe14a"/>
<path d="M50 32 C 34 12 18 22 30 32 Z M50 32 C 66 12 82 22 70 32 Z" fill="#ffe14a"/></g>""",
}


def main(out):
    os.makedirs(out, exist_ok=True)
    for name, body in ICONS.items():
        page = os.path.join(out, f"{name}.html")
        with open(page, "w", encoding="utf-8") as f:
            f.write(f"""<!doctype html><html><head><style>html,body{{margin:0;background:transparent;overflow:hidden}}svg{{display:block}}</style></head>
<body><svg width="256" height="256" viewBox="-4 -4 108 108"><defs>{DEFS}</defs>{body}</svg></body></html>""")
        png = os.path.join(out, f"{name}.png")
        subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                        "--window-size=256,256", f"--screenshot={png}", "file:///" + page.replace("\\", "/")],
                       check=True, capture_output=True, timeout=60)
        print(name, os.path.getsize(png))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out"))
