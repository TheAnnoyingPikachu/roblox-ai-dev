"""Builds the concept board for one base animal: uv run --with pillow python build_board.py <board dir>
Reads <board>/clips/<clip>/f_##.png + clips.json, <board>/rom/rom_##.png + rom.json, <board>/bones/*.png and the
pictures copied into <board>/img; writes GIFs and <board>/index.html."""
import json, os, sys
from PIL import Image

board = sys.argv[1]
TITLE = os.environ.get("BOARD_TITLE", "the Eternal Sun Cheetah")
HAS = lambda f: os.path.exists(os.path.join(board, "img", f))
clips = json.load(open(os.path.join(board, "clips", "clips.json")))
rom = json.load(open(os.path.join(board, "rom", "rom.json")))

for key, c in clips.items():
    d = os.path.join(board, "clips", key)
    frames = [Image.open(os.path.join(d, f"f_{i:02d}.png")).convert("RGB") for i in range(c["frames"])]
    frames = [f.crop((40, 20, 440, 300)) for f in frames]
    step = c["seconds"] / (c["frames"] if c["loop"] else c["frames"] - 1)
    dur = [int(step * 1000)] * len(frames)
    if not c["loop"]:
        dur[-1] = 700  # rest a moment before it plays again
    frames[0].save(os.path.join(board, "clips", f"{key}.gif"), save_all=True, append_images=frames[1:], duration=dur, loop=0)


def badge(v):
    cls = "ok" if v < 7 else ("warn" if v < 10 else "bad")
    return f'<span class="b {cls}">{v:.1f} % stretch</span>'


KINDS = [("idle", "Idle"), ("run", "Run"), ("attack", "Attack"), ("power", "Power move"), ("hit", "Hit"), ("fall", "Fall"), ("win", "Win")]
clip_html = ""
for kind, title in KINDS:
    cards = "".join(
        f'<div class="card"><img src="clips/{k}.gif" alt="{c["name"]}"><h4>{c["name"]} {badge(c["worst_stretch"])}</h4><p>{c["desc"]}</p></div>'
        for k, c in clips.items() if c["kind"] == kind)
    clip_html += f'<h3>{title} <span class="pick">pick one</span></h3><div class="grid">{cards}</div>'

rom_html = "".join(
    f'<div class="rom"><img src="rom/rom_{i:02d}.png" alt="{t}"><div>{t}<br>{badge(rom["stretch"][t])}</div></div>'
    for i, t in enumerate(rom["tests"]))
clip_rows = "".join(f'<tr><td>{c["name"]}</td><td>{c["kind"]}</td><td>{badge(c["worst_stretch"])}</td><td>{c["worst_squash"]:.1f} %</td></tr>'
                    for k, c in clips.items())

ROSTER = [
    ("Jackal", "Four-legged", "+ two ear bones (the tall ears flick and flatten)", "Sphinx: + two wings (shoulder, tip); Anubis: as the base"),
    ("Meerkat", "Upright", "hips low and a vertical spine; arms with elbows and paws in place of front legs; a balancing tail", "variants share it"),
    ("Cheetah", "Four-legged (the base)", "none: this is the template", "the Eternal Sun Cheetah, built"),
    ("Lion", "Four-legged", "+ a jaw for the roar; the mane a rigid kit piece on the neck and chest", "Sahara Guardian: + the crown and halo on the head"),
    ("Flamingo", "Bird", "two legs with a backward-bending ankle, a 5-bone neck, two 2-bone wings", "Phoenix: wing flames as kit on the wing bones"),
    ("Tortoise", "Four-legged, shell", "the shell a rigid kit on the spine (no spine bend), a 2-bone neck, short legs", "War-Tortoise: the cannon on the shell"),
    ("Rhino", "Four-legged", "the horns rigid on the head", "Sun Rhino: built in the old pipeline, can be moved over"),
    ("Elephant", "Four-legged", "+ a 3-bone trunk, + two ear bones that flap", "Sahara Mammoth: built in the old pipeline"),
    ("Giraffe", "Four-legged, long neck", "a 4-bone neck instead of 1, ossicones rigid on the head", "variants share it"),
]
roster_rows = "".join(f"<tr><td><b>{a}</b></td><td>{b}</td><td>{c}</td><td>{d}</td></tr>" for a, b, c, d in ROSTER)

extra_imgs = "".join(f'<h3>{t}</h3><img src="img/{f}" alt="{t}">' for f, t in (("concepts.png", "From your original to the concept to the model"), ("cheetah_concepts.png", "The concepts it was picked from"), ("jackal_concepts.png", "Next family: the jackals")) if HAS(f))
roster_img = '<img src="img/roster.png" alt="The base animal models">' if HAS("roster.png") else ""
html = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Animal pipeline board: {TITLE}</title><style>
body{{font-family:system-ui,sans-serif;background:#1b1a21;color:#ecebf2;margin:0;padding:26px 36px 64px;line-height:1.5}}
h1{{margin:0 0 4px;font-size:28px}} h2{{margin:44px 0 10px;font-size:21px;border-bottom:1px solid #3a3846;padding-bottom:6px}}
h3{{margin:26px 0 8px;font-size:17px;color:#f2c66d}} h4{{margin:8px 0 2px;font-size:15px}}
p,li,td{{color:#cfcdd9;max-width:1000px}} img{{max-width:100%;border-radius:8px;background:#26252d;display:block}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:14px}}
.card{{background:#25242d;border-radius:10px;padding:10px}} .card p{{margin:2px 0;font-size:14px}}
.b{{font-size:12px;border-radius:4px;padding:1px 7px;margin-left:6px;font-weight:600}} .ok{{background:#2f6b3f;color:#d9ffe2}}
.warn{{background:#7a6a2a;color:#fff3c8}} .bad{{background:#7a2f2a;color:#ffd9d6}}
.pick{{font-size:12px;background:#4b3a7a;color:#e6dcff;border-radius:4px;padding:1px 7px;margin-left:6px}}
.roms{{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px}} .rom{{font-size:13px;color:#cfcdd9}}
table{{border-collapse:collapse;margin:10px 0}} td,th{{border:1px solid #3a3846;padding:5px 9px;text-align:left;vertical-align:top}}
th{{background:#25242d}} .flow{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}}
.step{{background:#25242d;border-radius:10px;padding:10px;font-size:14px}} .step b{{color:#f2c66d}} .step img{{margin-top:6px}}
</style></head><body>
<h1>Animal pipeline board</h1>
<p>One board an animal: the creature and its variants, its rig with every extra bone, several options of each clip to
pick from, a stretch check at every joint's limit and on every clip, and the way into the game. This one is the base
animal every other is built to: <b>{TITLE}</b>. Stretch is the share of his skin pulled longer by a
quarter (green under 7 %, amber under 10 %); his armour pieces are rigid and never stretch.</p>

<h2>1. The pipeline</h2>
<div class="flow">
<div class="step"><b>1 Concept</b><br>References of the species and its set, the stretch-room rules in the prompt, picks.<img src="img/concept.png"></div>
<div class="step"><b>2 Model</b><br>One ForgeGUI 3D model from the picked concept, neutral stance checked (feet level within 0.2 %).<img src="img/model.png"></div>
<div class="step"><b>3 Body and kit</b><br>Split by shade: the body becomes one clean quad skin (11k triangles), the armour stays crisp and rigid (5k).<img src="img/split.png"></div>
<div class="step"><b>4 Rig</b><br>The template placed from a landmark file, weights by bone heat, the rules, then smoothed; armour pinned to bones.<img src="bones/bones_side.png"></div>
<div class="step"><b>5 Clips</b><br>Several options of each clip keyed on the rig, feet on targets so they plant.<img src="clips/run_bound.gif"></div>
<div class="step"><b>6 Checks</b><br>Every joint at its limit and every frame of every clip measured; stretched faces drawn red.<img src="rom/rom_00.png"></div>
<div class="step"><b>7 Picks</b><br>You pick one option of each clip on this board.</div>
<div class="step"><b>8 Into the game</b><br>The picked clips baked to keys the game plays on the new bones (section 7).</div>
</div>

<h2>2. The roster: one base model an animal</h2>
{roster_img}
<table><tr><th>Animal</th><th>Rig template</th><th>Extra bones and rigid pieces</th><th>Variants</th></tr>{roster_rows}</table>
<p>Four templates cover them all: four-legged (seven animals), upright (the meerkat), bird (the flamingo), and the
four-legged one with extra modules (trunk, jaw, ears, wings, a long neck) switched on per animal from its landmark file.</p>

<h2>3. The creature and its variants</h2>
<h3>{TITLE}</h3>
<img src="img/model_views.png" alt="The concept and the model from three sides">
<img src="img/split_look.png" alt="The model, its body skin, and its armour kit">
{extra_imgs}

<h2>4. The rig, with every bone</h2>
<div class="grid" style="grid-template-columns:1fr 1fr"><img src="bones/bones_side.png"><img src="bones/bones_q.png"></div>
<table><tr><th>Colour</th><th>Bones</th><th>What they do</th></tr>
<tr><td style="color:#ffbf1a">gold</td><td>hips, spine, chest</td><td>the back arches, coils and rolls (the sprint's spine flex)</td></tr>
<tr><td style="color:#a659ff">purple</td><td>neck, head</td><td>looks, nods and snaps on its own; the head is one rigid block</td></tr>
<tr><td style="color:#ff731a">orange</td><td>tail 1–4</td><td>a tail that swings in a wave and curls at the tip</td></tr>
<tr><td style="color:#268cff">blue</td><td>upper, lower, foot ×4</td><td>real knees; the front ones bend back, the hind ones forward</td></tr>
<tr><td style="color:#1ad94d">green</td><td>foot targets ×4</td><td>a planted foot stays put while the body moves over it</td></tr>
<tr><td style="color:#f2f2f2">white</td><td>knee aims ×4</td><td>set which way each knee bends (picked automatically)</td></tr>
<tr><td style="color:#f2339a">pink</td><td>trunk, jaw, ears, wings</td><td>the extra modules other animals switch on (none on the cheetah)</td></tr></table>
<p>21 bones move his skin, 9 more steer it. The armour has no bones of its own: each piece rides one bone rigidly.</p>

<h2>5. Clip options</h2>
{clip_html}

<h2>6. The stretch check</h2>
<h3>Every joint alone at the edge of its budget</h3>
<div class="roms">{rom_html}</div>
<h3>Every clip, its worst frame</h3>
<table><tr><th>Clip</th><th>Kind</th><th>Stretched</th><th>Squashed (folds)</th></tr>{clip_rows}</table>
<p>What made the difference: smoothing the weights (100 passes) took the worst clips from 14 % to 9 % and every
joint under 1.6 %. Squashed skin is where it folds, behind a bent knee: it is not a tear.</p>

<h2>7. Into the game</h2>
<table><tr><th>Step</th><th>What</th><th>Status</th></tr>
<tr><td>Export</td><td>The skin and the armour as one skinned mesh (four bones a vertex, under 20,000 triangles) with the 21 moving bones, from rig.blend</td><td>ready to write</td></tr>
<tr><td>Bake</td><td>Each picked clip sampled at 15 keys a second into each bone's turn and move, written as a data module the game reads (like AnimalRig)</td><td>after picks</td></tr>
<tr><td>Play</td><td>Creatures.client plays the baked keys on the new bones for an animal that has them, blending between clips as now; every other animal keeps today's code poses</td><td>after picks</td></tr>
<tr><td>Wire</td><td>The animal's entry (StationRules, StationConfig), its spell anchors measured on the new bones, its rainbow coat</td><td>after picks</td></tr>
<tr><td>Check</td><td>Tests on the clip data, the stretch report kept with the build, then Studio with the admin buttons and the build stamp</td><td>after picks</td></tr>
<tr><td>Ship</td><td>Upload, a task and a decision record, one PR for you to squash</td><td>your go</td></tr></table>
<p>Not Roblox's Animator clips: uploading animation assets cannot be automated from here, and baked keys keep every
animal in one system with the moves it has today.</p>
</body></html>"""
open(os.path.join(board, "index.html"), "w", encoding="utf-8").write(html)
print("BOARD", len(clips), "clips", len(rom["tests"]), "joint tests")
