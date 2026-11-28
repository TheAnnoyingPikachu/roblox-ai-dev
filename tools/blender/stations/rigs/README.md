# The rig pipeline: a generated model to a rigged, animated animal

For an animal whose model is one generated mesh (ForgeGUI). It gets knees, a spine, a neck and a tail of several
bones, clips keyed with its feet held on the ground, and a board to pick from. Decision 0133.

```
run_creature.sh <dir> "<title>" [clip set]     # <dir>/raw.glb -> <dir>/rig/rig_full.blend and <dir>/board/index.html
blender -b <dir>/rig/rig_full.blend -P export_game.py -- <repo> <asset> <length in studs> <clip set> \
    idle=<clip> walk=<clip> attack=<clip> magic=<clip> hit=<clip> die=<clip> win=<clip>
```

`batch.sh <root>` runs every folder under `<root>` that has a model and no board yet, one after another (renders
one at a time: several at once hang the GPU). `look.py` renders a rigged model at rest from behind and in front,
drawn fronts only as Roblox draws it: look at a new model's legs there before anything else.

## Families

| Family | Measured by | What it has more |
|---|---|---|
| rhino, lion, cheetah, jackal | `autoland.py` | nothing: the four-legged rig as it is |
| elephant | `autoland.py` (clip set `elephant`) | four trunk bones (`"trunk": [curl up, sway]`) and an `ear_l` and `ear_r` (posed by name), all on springs |
| tortoise | `autoland.py` (clip set `tortoise`) | leg joints at the shell's underside so the shell never bends; a head that slides (`"pull": [d]`) |
| meerkat | `autoland_up.py` | stood up: its "hind legs" are its legs, planted; its "front legs" are its arms, which ride with the body and are posed by where the hands go |

`"drop": [1]` sets any of them down on the ground (a meerkat on its haunches). A topple's `root` pivot is measured
from the root bone: `[roll, pivot x, pivot height above the floor, up, yaw]`.

The model must face -Y (its head at -Y), stand in a neutral stance with its legs straight, and be one textured mesh.

| Step | Script | What it does |
|---|---|---|
| 1 | `autoland.py` | Measures the landmarks (`species.json`): the feet, the belly and rump, each leg's joints, the spine, neck and tail. Each knee gets a slight bend the way it folds: a dead-straight leg gives the rig no direction to bend it in. Skipped when a `species.json` is already there. |
| 2 | `split_remesh.py` | A voxel remesh of the body: clean, even quads. Only a proxy to work the weights out on. |
| 3 | `quadrig.py` | The skeleton from the landmarks, bone-heat weights on the proxy, rule fixes (no leg weight above the legs, a rigid head), smoothed weights, IK legs with each pole angle tried and picked. |
| 4 | `transfer_rig.py` | Keeps the model as generated (welded, faces turned out) and copies the proxy's weights to it. A remeshed and re-baked body comes out patchy where pieces overlap, so it is never shown. |
| 5 | `clips.py` | Bakes every clip of the set (`clipsets/<set>.py`) at 60 frames a second, with follow-through on the tail, measures its stretch and renders it. |
| 6 | `rom.py`, `bones.py` | Each joint at its limit, and the skeleton drawn over the model. |
| 7 | `build_board.py` | `board/index.html`: every clip as a loop with its stretch, the joint tests, the bones. |
| 8 | `export_game.py` | The model with every bone as `build/blender/stations/<asset>.fbx`, its manifest entry, and the picked clips baked into `src/stations-client/Clips/<asset>.luau`. Then `export_assets.py`, `rainbow.py`, `moves/rigdata.py` and the upload as for any model. |

## Clips

`rigpose.py` is the posing language: a pose is `{body, spine, neck, head, tail, fl, fr, hl, hr, carry, root}` in
world axes and model units, a clip a function of time. `keyed([(time, pose, ease), ...])` makes a one-shot from keys:
`out` settles into a wind-up, `in` lands a blow at full speed, `over` goes past and comes back. A planted foot that
moves between two keys is lifted in an arc; hips that would pull a planted foot off the ground sink instead.

A clip set is `CLIPS = {key: (name, kind, description, seconds, function, loops)}`. Lengths are the game's: an idle
loops in 4.8 s, an attack is 0.95 s with its blow at 0.44, a power attack 1.6 s with its blow at 0.92, a hit 0.4 s,
a fall 1.2 s. `clipsets/quad.py` is the fallback for any four-legged animal; a species has its own
(`clipsets/rhino.py`, `lion.py`, `cheetah.py`, `jackal.py`, `elephant.py`, `meerkat.py`, `tortoise.py`), and a variant's own power attack sits beside its species'
(`power_prism`). Distances are in model units, so a set fits its family's build; `"drop": [1]` lays the belly on the
ground whatever the build. Every set has a walk at the game's pace: `Creatures.speed` is about 0.4 of a body length
a second, which is a walk, not a trot.

Stretch is the share of the surface whose faces have an edge a quarter longer than at rest. Look at the renders as
well as the number: a tear can move without the number changing.
