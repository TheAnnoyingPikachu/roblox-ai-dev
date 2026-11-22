# Animal moves: concepts and the game's data

How the animals' idles, attacks and spells (power attacks) were made and how they reach the game (STATION-116).
Run from this folder; Blender renders one at a time (several at once hang the GPU).

| Script | Does |
|---|---|
| `concepts.py` | idles, attacks (and the old physical powers) for the nine base animals, in `Creatures.client`'s pose terms |
| `magic.py`, `fxkit.py` | the spells: body keys and a drawing function per spell; fxkit draws them from shapes Roblox has |
| `rig.py` | loads a built model (`build/blender/stations/<asset>.fbx`), poses it as the game does, measures how far its feet sink |
| `render.py`, `render_magic.py` | render the concepts' frames (`run.sh` / `runm.sh keys\|full <animals>`) |
| `gifs.py`, `gifs_magic.py`, `keysheet.py`, `page.py` | animated WebPs, review sheets and the review page |
| `export_moves.py` (+ `idles.luau`) | writes `src/shared/AnimalMoves.luau` from SHANNON's picks (`PICKS`, `VARIANTS`) |
| `rigdata.py` | writes `src/shared/AnimalRig.luau`: every skinned animal's size, joints, foot points and spell anchors |

The game's spells are `src/stations-client/Spells`, translated from `magic.py` call for call (the kit's methods
match fxkit's). Change a spell in both. After a model is rebuilt, run `rigdata.py` again:

    blender --background --factory-startup --python rigdata.py -- <repo> <repo with build/> <asset>...

Check the game's spells after changing one (runs each through its whole clip, no Studio needed):

    lune run tools/blender/stations/moves/check_spells

`magicv.py` (with `render_v.py`): three directions for better-looking spells (hot core, elemental, arcane) on Sun Orb, Horn Lance and Shadow Claws, for SHANNON to pick one before it goes onto every spell.

`render_h.py`: each animal's picked spell in the Hot core look (SHANNON's pick of the three; `fxkit.HOT`), rings closing in on where it casts from.
