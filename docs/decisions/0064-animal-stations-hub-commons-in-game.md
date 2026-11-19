# 0064: Animal Stations: the gathering place built on the hub's plaza

Status: accepted (SHANNON, 2026-11-16: "go on all four", to the four questions of the report that
showed the concept; the first was which hub centre). Replaces the centre of decision 0060.
Task STATION-057.

## What is on the plaza now

The concept of decision 0063 (`docs/concepts/hub-commons-card.png`), in place of the fountain,
statues, shrines and gateways.

- Eight models, built by `tools/blender/stations/assets/hub.py` from the functions that drew the
  concept (`scenes/hub_commons.py`): the floor, the fire pit with its benches, the market with the
  egg seller's cart, the cafe, the stage, the green (meeting tree, pond, trough), the lights
  (poles, lamps, strings of flags, planters) and the signs (finger posts, notice board, arch).
- The Golden Egg sits on the egg seller's cart with a Meadow, a Wild and a Safari Egg beside it.
  They are the eggs' own models (`World.kit.eggModel`).
- Nine animals stand about, idling: a lion by the fire, a cheetah, a jackal at the market, a
  tortoise, a flamingo at the pond, a rhino at the trough, an elephant by the arena road, two
  meerkats on the stage. They are the game's own animal models (`Creatures.spawn`), with the card
  under the cursor like any other. They belong to no one and do nothing else.
- Unseen parts make solid what should be: the floor, the fire's stones and benches, the stalls and
  the cart, the cafe's floor, counter, wall and tables, the stage and its benches, the tree, its
  bench and mound, the pier, the trough, the picnic tables, posts and the arch.

## What changed in the build tools

- A model built where it stands now records its `lift` in the manifest (how far above the place's
  ground its lowest point was), and `Creatures.build` puts its Root that far below it. The table of
  lifts that `World.luau` kept for the first centre is gone.
- `stage.sort_pieces` sorts a scene's meshes into one painted `body` and a Neon piece for each
  colour that glows. The fire has four.

## What went

- The first centre's twelve models are out of the manifest and the game, with the statues
  (`Creatures.statue`). Their uploads stay on the account, unused: twelve models and twelve images,
  and the first fountain's pair. The images can be archived by the upload workflow when SHANNON
  says; models cannot be through the API.
- The gathering place's eight models were uploaded twice by mistake: the first upload run stuck in
  GitHub's queue, the upload was started again and succeeded, and an hour later the stuck run ran
  as well. The game uses the second start's models; the late run's eight models and eight images
  are unused duplicates (register: "second upload").

## Not done

- Nothing on the plaza does anything yet: the stalls sell nothing, the notice board shows nothing,
  the stage hosts nothing. Vendors are still on the ranches.
- The fire and the lanterns glow but cast no light; the hub is always in daylight.
- If a model fails to load, its piece is missing and its unseen walls stay.
