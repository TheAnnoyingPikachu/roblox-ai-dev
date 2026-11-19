# 0068: Animal Stations: the whole ranch reworked as one valley (concept)

Status: accepted (SHANNON, 2026-11-16: "go on the ranch vallet and i take your recommendation"); in the
game by decision 0070, which says how each question below was read.
Date: 2026-11-16. Task STATION-061.

## What SHANNON asked

"can you also integrate the training grounds into the landscape by having them on like adjacsent
mountain basins by the ranch or by having them a little lower by a beach or something, concept for
this one first please", then: "like make a concept for an entire ranch rework to fit everything in an
optimised and cool way please".

## What was made (`docs/concepts/ranch-valley-card.png`)

One ranch as one valley that runs from mountains down to a bay. Both ideas are in it: four grounds
in basins and cuts in the mountainside, two down on the beach.

- The homestead on a round plateau in the middle: house, barn and silo, hatchery, the two vendors,
  a paddock for the roaming animals, a well, a windmill.
- Up the mountainside behind it: the Magic Library on a high ledge (46 studs up), the Healing
  Spring in a basin under a waterfall (30 up), the Guard Yard in the mouth of a pass (16 up).
- Beside it: the Strength Gym in a quarry cut into the hill (8 up).
- Below it, on the beach: the Swim Pool as a lido by the water (15 down) and the Speed Track on the
  flat behind the sand (13 down).
- A stream runs from the waterfall past the homestead to the sea. A path leaves the homestead for
  each ground under a signpost in its stat's colour. The road to the hub leaves to the south-west.
- The grounds stand on the land itself: no square floor, no fence. One animal is at work in each.

### Why it is tighter

| | The six clearings (in the game now) | The valley |
|---|---|---|
| Homestead's middle to a ground's middle | 420 studs | 255 to 315 |
| The whole ranch across | about 1,260 | about 820 |
| What you see from the homestead | mountains; no ground | every ground |

Facts: the first column is decision 0065's layout; the second is the concept's own numbers
(`tools/blender/stations/scenes/ranch_valley.py`).

## For SHANNON to decide

1. The layout and the look: go, or changes.
2. What the ground is made of in the game. (a) Roblox terrain shaped by the same height function
   (recommended): walkable as it is, and the bay and pool can be real water. The catch: it is
   smooth, so the land loses the concept's facets. (b) Uploaded faceted meshes: the exact look, but
   a mesh that size walks badly and needs several uploads for each ranch.
3. Whether the homestead becomes a round yard as sketched, or keeps its square plot.
4. Whether the areas lose their fences and floors as drawn (twelve area models built again).

## Not done

- Nothing is built, exported or uploaded. The grounds are shown at the top upgrade level only.
- The homestead's buildings are sketches. Not tried in the game engine or on a phone.
