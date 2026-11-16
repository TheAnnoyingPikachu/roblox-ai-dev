# 0065: Animal Stations: the training areas built in clearings round each ranch

Status: accepted (SHANNON, 2026-11-16: "go on all four", to the four questions of the report that
showed the concepts: the training looks, and room for the clearings by fanning them out on the side
away from the hub and moving the ranches back out). Builds decision 0061. Task STATION-058.

## The layout

| Number (`World.luau`) | Was | Is |
|---|---|---|
| `RANCH_DIST`, the hub's middle to a ranch's | 780 | 840 |
| `AREA_DIST`, a ranch's middle to each clearing's | none | 420 |
| `AREA_RING`, a clearing's middle to its mountains' feet | none | 132 |
| `AREA_ANGLE`, where the six clearings lie, from straight away from the hub | none | -125, -75, -25, 25, 75, 125 degrees |

- The six clearings fan over the 250 degrees away from the hub, in the order of the stations:
  Speed Track, Strength Gym, Swim Pool, Magic Library, Healing Spring, Guard Yard.
- At 840 one ranch's nearest clearing and the next ranch's are 361 studs apart, middle to middle
  (measured), about as far as a ranch's own clearings are from each other (355); at 780 they would
  be 276 apart, their rings of mountains touching. It undoes half of "bring the ranches in": 900 at
  first, 780 this morning, 840 now. The walk from the plaza's kerb to a ranch's gate is 717 studs.
- A clearing and its pass stand on the ranch's own raised ground (terrain at the same height).
- The plot's fence has six new gaps, one where each path leaves: two in each side, two in the back.
  Each path runs from its gap, under a board with the area's name in its stat's colour, between
  mountains, to the area's gateway.

## Mountains and walls

- Mountains are placed by one rule now: wherever one keeps out of every plot, clearing and pass
  (`zones`, `seated` in `World.luau`), shrinking to fit before giving up. A row stands round each
  plot between the seven ways out, a row round each clearing, taller ones behind where there is
  room. The hub's own mountains and the hub passes' use the same rule, so none stands in a clearing.
- Unseen walls ring each plot and each clearing and run down both sides of each pass, open only
  where a pass goes through (`wallRound`).

## The areas

- An area is the models `area_<station>_<first>_<last>` (45 in all, `assets/areas.py`): each holds
  what stands from Training Grounds level `first` to level `last`. `Areas.luau` stands every model
  whose stretch holds the ranch's level, and `Ranch.render` builds them again when an upgrade is
  bought, as it does the rest of the ranch.
- All six areas follow the one Training Grounds upgrade, as the concepts were drawn.
- The six small courts are gone from the plot. Each area keeps a pad tagged `TrainPad` at its
  middle (nothing reads it yet, as before).
- An area is 160 by 120 studs, as in the concepts.

## What can be walked on, and what cannot

The models take no collisions. `Areas.luau` adds unseen blocks for the floors and the big raised
things only: every yard's floor, the gym's lifting deck, the pool's deck, water and steps, the
library's floor, the spring's terrace and baths, the guard yard's court, wall and towers, the
track's stand. Everything else in an area (fences, kit, bookcases, the gateway's posts) is walked
through. The pool's water is stood on, not swum in.

Changed from the concept: the pool's steps now touch its deck (they stood apart from it).

## Not done

- Animals are not seen in the areas. Training is still the menu's; whether animals show there is
  the open question of decision 0061.
- No signs or paths inside the plot lead to the gaps in its fence.
- One model, `area_spring_2_5`, was uploaded twice: Roblox would not serve its first texture. The
  first pair is unused.
- Not measured: frame rate. Fact: the world is now 14,691 parts and folders before any area model
  loads, with 379 mountains and 535 unseen walls. Assumption: three ranches at the top level show
  about 500,000 triangles of area models between them.
