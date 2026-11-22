"""The review page: every animal's idle, attack and power concepts as GIFs. page.py <out dir> <page.html>"""
import html
import json
import os
import sys

OUT, PAGE, OUTM = sys.argv[1], sys.argv[2], sys.argv[3]  # OUTM: the magic power attacks (render_magic.py)
ORDER = ["jackal", "tortoise", "meerkat", "cheetah", "rhino", "flamingo", "lion", "giraffe", "elephant"]
VARIANTS = {"jackal": ["jackal_pharaoh", "jackal_sphinx"], "tortoise": ["tortoise_gemshell", "tortoise_island"],
            "meerkat": ["meerkat_star", "meerkat_storm"], "cheetah": ["cheetah_lightning", "cheetah_thunder"],
            "rhino": ["rhino_lava", "rhino_crystal"], "flamingo": ["flamingo_peacock", "flamingo_phoenix"],
            "lion": ["lion_sun", "lion_shadow"], "giraffe": ["giraffe_acacia", "giraffe_diamond"],
            "elephant": ["elephant_frost", "elephant_war"]}
NOTES = {  # what a concept would need beyond its clip, said on its card
    "2_drink": "Lowers its whole neck to the ground, so it reads best in the pen rather than between attacks.",
    "creature_meerkat_storm_forge_m_ufo": "The saucer would be a small model of its own, made like the training kit.",
}
PICKS = {  # SHANNON's picks, 2026-11-21: the base rows by letter, every variant spell but the War Elephant's volley
    "jackal": ("1_prowl", "b_leap", "m_pack"), "tortoise": ("1_ancient", "a_snap", "m_nova"), "meerkat": ("2_boxer", "a_combo", "m_sunorb"),
    "cheetah": ("1_stalk", "a_trip", "m_blades"), "rhino": ("2_whet", "a_gore", "m_lance"), "flamingo": ("2_preen", "b_lash", "m_darts"),
    "lion": ("1_king", "a_maul", "m_roar"), "giraffe": ("1_browse", "a_neck", "m_lance"), "elephant": ("1_sway", "a_tusk", "m_orb")}
NEW = {"creature_elephant_war_forge_m_axe"}
DROPPED = {"creature_elephant_war_forge_m_volley"}
KIND = {"idle": ("Idle", "loops"), "attack": ("Attack", "hit at 0.44 s"), "power": ("Magic power attack", "impact at 0.92 s"),
        "variant": ("Variant power attacks", "one spell each")}
sections, nav = [], []
for a in ORDER:
    fit = json.load(open(os.path.join(OUT, a, "fit_full.json"), encoding="utf-8"))
    magic = json.load(open(os.path.join(OUTM, a, "fit_magic_full.json"), encoding="utf-8"))
    rows = []
    groups = {"idle": [(k, v, fit["asset"], 380, 330, None) for k, v in fit["idles"].items()],
              "attack": [(k, v, fit["asset"], 380, 330, None) for k, v in fit["clips"].items() if v["kind"] == "attack"],
              "power": [(k, v, magic["asset"], 480, 352, None) for k, v in magic["clips"].items()], "variant": []}
    for w in VARIANTS[a]:
        vm = json.load(open(os.path.join(OUTM, w, "fit_magic_full.json"), encoding="utf-8"))
        groups["variant"] += [(k, v, vm["asset"], 480, 352, vm["name"]) for k, v in vm["clips"].items()]
    for kind in ("idle", "attack", "power", "variant"):
        figs = []
        for i, (k, v, asset, w, h, who) in enumerate(groups[kind]):
            note = NOTES.get(k) or NOTES.get(f"{asset}_{k}")
            full = f"{asset}_{k}"
            state = ("new" if full in NEW else "" if full in DROPPED else "picked") if kind == "variant" else ("picked" if k in PICKS[a] else "")
            badge = f'<span class="badge {state}">{"New: to pick" if state == "new" else "Picked"}</span>' if state else ""
            tag = f'<span class="who">{html.escape(who)}</span>' if who else f'<span class="opt">{"AB"[i]}</span>'
            figs.append(f'''<figure class="{state}">{badge}
          <img src="gifs/{asset}_{k}.webp" alt="{html.escape(who or fit["name"])}: {html.escape(v["label"])}" loading="lazy" width="{w}" height="{h}">
          <figcaption>{tag}<b>{html.escape(v["label"])}</b> {html.escape(v["text"])}{f'<span class="note">{html.escape(note)}</span>' if note else ""}</figcaption>
        </figure>''')
        title, sub = KIND[kind]
        rows.append(f'''<div class="row {kind}">
        <h3>{title}<span>{sub}</span></h3>
        <div class="pair">{"".join(figs)}</div>
      </div>''')
    nav.append(f'<a href="#{a}">{html.escape(fit["name"])}</a>')
    sections.append(f'''<section id="{a}">
      <h2>{html.escape(fit["name"])}</h2>
      {"".join(rows)}
    </section>''')

page = f'''<title>Animal Move Concepts</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap">
<style>
/* Layout: a short brief, a jump bar, then one band per animal with four rows (idle, attack, power, variants), two options side by side */
:root {{
  --bg: #eeedf2; --surface: #ffffff; --fg: #1f1d26; --muted: #5f5b6b; --line: #d9d6e0;
  --accent: #a8620c; --idle: #2e7d74; --attack: #2f5f9e; --power: #b4441f; --magic: #7b3fb8; --stage: #24212c;
  --display: "Space Grotesk", "Segoe UI", system-ui, sans-serif; --body: "Inter", "Segoe UI", system-ui, sans-serif;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #17161c; --surface: #211f28; --fg: #ece9f2; --muted: #a29db0; --line: #34313d;
  --accent: #e9a64a; --idle: #6cc7bb; --attack: #86b3ef; --power: #f08a62; --magic: #c49af0; color-scheme: dark }} }}
:root[data-theme="dark"] {{ --bg: #17161c; --surface: #211f28; --fg: #ece9f2; --muted: #a29db0; --line: #34313d;
  --accent: #e9a64a; --idle: #6cc7bb; --attack: #86b3ef; --power: #f08a62; --magic: #c49af0; color-scheme: dark }}
body {{ background: var(--bg); color: var(--fg); font-family: var(--body); line-height: 1.5; }}
.wrap {{ max-width: 1000px; margin: 0 auto; padding-block: 32px 72px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); display: grid; gap: 28px; }}
h1, h2, h3 {{ font-family: var(--display); margin: 0; text-wrap: balance; }}
h1 {{ font-size: 2rem; }}
.eyebrow {{ font-size: .74rem; letter-spacing: .09em; text-transform: uppercase; color: var(--accent); font-weight: 600; }}
header {{ display: grid; gap: 10px; }}
header p {{ margin: 0; max-width: 68ch; color: var(--muted); }}
.facts {{ display: flex; flex-wrap: wrap; gap: 8px 22px; font-size: .9rem; }}
.facts b {{ font-variant-numeric: tabular-nums; }}
nav {{ position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--bg); display: flex; flex-wrap: wrap; gap: 6px; padding-block: 10px; border-bottom: 1px solid var(--line); }}
body::before {{ content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--bg); }}
nav a {{ color: var(--fg); text-decoration: none; font-size: .88rem; font-weight: 500; padding: 4px 10px; border: 1px solid var(--line); border-radius: 99px; background: var(--surface); }}
nav a:hover, nav a:focus-visible {{ border-color: var(--accent); outline: none; }}
section {{ display: grid; gap: 18px; padding-top: 8px; scroll-margin-top: 64px; }}
section + section {{ border-top: 1px solid var(--line); padding-top: 28px; }}
h2 {{ font-size: 1.5rem; }}
.row {{ display: grid; gap: 10px; }}
h3 {{ font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; display: flex; gap: 10px; align-items: baseline; }}
h3 span {{ font-family: var(--body); text-transform: none; letter-spacing: 0; font-weight: 400; color: var(--muted); font-size: .85rem; }}
.idle h3 {{ color: var(--idle); }} .attack h3 {{ color: var(--attack); }} .power h3 {{ color: var(--power); }} .variant h3 {{ color: var(--magic); }}
.pair {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap: 14px; }}
figure {{ margin: 0; display: grid; gap: 8px; align-content: start; min-width: 0; background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 10px; }}
figure img {{ width: 100%; height: auto; border-radius: 6px; background: var(--stage); display: block; }}
figcaption {{ font-size: .92rem; display: block; }}
figcaption b {{ font-weight: 600; margin-right: 4px; }}
.opt {{ display: inline-grid; place-items: center; width: 1.4em; height: 1.4em; margin-right: 6px; border-radius: 4px; font-family: var(--display); font-size: .8rem; font-weight: 700; color: var(--surface); background: var(--muted); vertical-align: 1px; }}
.idle .opt {{ background: var(--idle); }} .attack .opt {{ background: var(--attack); }} .power .opt {{ background: var(--power); }}
.who {{ display: block; font-family: var(--display); font-size: .78rem; letter-spacing: .06em; text-transform: uppercase; color: var(--magic); margin-bottom: 2px; }}
figure {{ position: relative; }}
figure:not(.picked):not(.new) {{ opacity: .6; }}
figure.picked {{ border-color: var(--idle); box-shadow: 0 0 0 1px var(--idle); }}
figure.new {{ border-color: var(--accent); box-shadow: 0 0 0 2px var(--accent); }}
.badge {{ position: absolute; top: 16px; right: 16px; z-index: 1; font-size: .74rem; font-weight: 600; padding: 2px 8px; border-radius: 99px; color: #fff; background: var(--idle); }}
.badge.new {{ background: var(--accent); }}
.note {{ display: block; margin-top: 6px; font-size: .84rem; color: var(--muted); }}
footer {{ color: var(--muted); font-size: .88rem; max-width: 70ch; }}
@media (prefers-reduced-motion: reduce) {{ html {{ scroll-behavior: auto; }} }}
</style>
<div class="wrap">
  <header>
    <span class="eyebrow">Animal Stations · base animals and variants · concepts</span>
    <h1>Animal Move Concepts</h1>
    <p>A new idle, attack and power attack for each of the nine base animals, two options of each to pick from, and a power attack of its own for each of the 18 variants. Power attacks are spells now: the animal casts and the magic plays out on a target dummy ahead of it. Everything is posed in Blender on each animal's own model and rig, on the game's timing.</p>
    <p>Every effect is made of things Roblox has: glowing Neon parts, beams, rings, particles, and a Highlight round the body for the glow while it charges. A variant keeps its species' idle and attack.</p>
    <div class="facts"><span>Attack: <b>0.95 s</b>, the hit lands at <b>0.44 s</b></span><span>Power attack: <b>1.6 s</b>, the impact at <b>0.92 s</b></span><span>Idles loop every <b>4.8 s</b></span><span>Variants: <b>18</b>, one spell each</span></div>
    <p>Each clip starts and ends with half a second of today's idle; in the game it will start from whichever idle you pick. The game's own hit sparks and flinch come on top.</p>
    <p><b>Picked</b> marks your choices, which are going into the game. New: the War Elephant's <b>War Axe</b>, the axe in its trunk grown huge (under Elephant, Variant power attacks), for you to keep or change.</p>
  </header>
  <nav aria-label="Animals">{"".join(nav)}</nav>
  {"".join(sections)}
  <footer>Say whether the War Axe is a keeper, or ask for changes to it or to any picked move.</footer>
</div>
'''
open(PAGE, "w", encoding="utf-8").write(page)
print("page", len(page))
