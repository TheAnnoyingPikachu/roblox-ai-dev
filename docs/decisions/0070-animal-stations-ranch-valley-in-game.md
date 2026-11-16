# 0070: Animal Stations: the ranch valley in the game

Status: accepted (SHANNON, 2026-11-16: "go on the ranch vallet and i take your recommendation", to
the four questions of decision 0068). Builds decision 0068; replaces the clearings and passes of
decision 0065 (the areas' looks and upgrade levels stand). Task STATION-063.

## What SHANNON's answer was read as

| Question of 0068 | Read as | Done |
|---|---|---|
| 1. The layout and the look | go | built |
| 2. What the ground is made of | the recommendation: Roblox terrain shaped by one height function | built |
| 3. A round yard for the homestead, or its square plot | not answered | the square plot is kept: see the checkpoint |
| 4. The areas lose their fences and floors | go, as drawn | the twelve models were built again |

## What a ranch is now

One valley, 836 studs across inside its unseen wall. All three ranches have the same valley.

- The homestead's plot, as it was, on a level round in the middle (the ranch's own ground, 22 studs
  above the hub's).
- Six training grounds, each a level round 212 studs across set into the land, 270 to 300 studs
  from the homestead's middle (420 before):

| Ground | Where | Above the homestead |
|---|---|---|
| Magic Library | a high ledge on the mountainside | 44 studs up |
| Healing Spring | a basin under a waterfall | 28 up |
| Guard Yard | the mouth of a pass | 16 up |
| Strength Gym | a cut in the hill | 8 up |
| Speed Track | the flat behind the beach | 12 down |
| Swim Pool | on the beach, by the lake | 16 down |

- A path from the plot to each ground: four leave through gaps in its fence, two beside its gate. A
  stream runs from above the spring to the lake, with a plank bridge where a path crosses it.
- The road to the hub leaves by the plot's gate and comes down to the hub's level inside the valley.
- An area stands on the land itself: no floor, fence or pennants of its own. Each ground's land is
  its floor (grass, sandstone, sand, slate, leafy grass, limestone).
- The heights differ from the concept by a stud or two (library 46, spring 30, pool 15 down, track
  13 down there): terrain is only exactly level on a 4-stud step, and the two highest grounds were
  lowered until their paths could be walked.

## How

- `src/shared/ValleyMap.luau` is the valley, with no Roblox call in it: `height(x, z)`, `water`,
  `kind` (what the land is made of), `GROUNDS`, `WAYS`, the stream. Lune tests it: every ground level
  and clear of the others, every path without a step, the road down to the hub's level, the valley
  closed all round, the lake on one side only.
- `src/stations/Valley.luau` writes it into the terrain a block of 16 by 16 columns at a time, and
  adds the trees, the waterfall and the bridges as parts.
- `World.areaFrame` and `World.AREA_GATE` now come from `ValleyMap.GROUNDS`; `Areas.luau`,
  `Ranch.luau` and the trainers use them as before.
- The ranches are 900 studs from the hub (840 since decision 0065): two valleys side by side must
  not meet.
- Closed: an unseen wall 418 studs from the homestead, open only to the hub's road; the valley's
  own ridge inside the square it is written in; a ring of mountains seated on the rim, which also
  hide that square's straight outer faces from the hub.
- The twelve area models that had a floor, fence or pennants were built again without them
  (`OPEN` in `scenes/training.py`) and uploaded (run 43954205121). Their unseen floor blocks went
  with them.

## Not done

- The homestead is the same square plot with the same buildings: the concept's round yard, paddock,
  well and silo are not built.
- The waterfall is flat strips of glass and the bridges are plain planks: placeholders, not models.
- Terrain is smooth: the land has none of the concept's facets (the known catch of the
  recommendation). Its rock is a little bluer than the mountains' stone.
- Nothing is at the lake but water: nothing to do there, no swimming rules.

## Checkpoint for SHANNON

1. The homestead: keep the square plot (now), or rebuild it as the concept's round yard
   (recommended as its own piece of work with its own concept: every building on it moves).
2. Ranches 900 studs from the hub, not 840: the walk up the pass is 60 studs longer. Rejecting it
   means a smaller valley.
3. All three ranches have the same valley. A different one each needs a seed in `ValleyMap`.
