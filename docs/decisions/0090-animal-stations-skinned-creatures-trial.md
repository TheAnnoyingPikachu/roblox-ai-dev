# 0090: Animal Stations: skinned creatures (trial on the Lion)

Status: trial (SHANNON, 2026-11-19: "could you take the lion model and redo all the animations entirely
outside of forgegui? make new bones and everything if need be"). Task STATION-097.

## What and why

The ForgeGUI models (0088) are cut into seven rigid pieces so the existing clips can move them. Here one
model stays one unbroken mesh on a skeleton of its own and bends, made entirely in Blender:

- `tools/blender/stations/skin.py`: 19 bones found from forge.py's cuts (hips, chest, neck, head, a
  three-bone tail, upper, lower and paw for each leg); weights painted from each face's piece and the
  distance to its bones, blended at the joints (Blender's automatic weights fail on these meshes of
  loose pieces). Exports `assets/stations/skin_lion.fbx` and `.png` (no animation in the file).
- `tools/blender/stations/clips/lion.json`: idle, walk, attack (Claw Maul, hit at 0.44 s), magic
  (King's Roar, hit at 0.92 s), hit, die and win, as turns in the creature's own frame per bone, so
  Blender's preview and the game play them alike.
- `skin_lion` is in the manifest as a trial: not yet used by the game (portraits and the seven-piece
  test skip `skin_`).

## Open (facts unless marked)

- Whether the Open Cloud upload keeps the skeleton: tested by uploading it (see STATION-097).
- Playing the clips on its bones in the game: a code change in Creatures, after the upload test.
- Seen only in Blender stills: the tail's root stretches a little in the walk; the death pose sits low.
