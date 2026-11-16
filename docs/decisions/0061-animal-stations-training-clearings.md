# 0061: Animal Stations: training areas in clearings round the ranch, with upgrade looks (concepts, second round)

Status: accepted and built (SHANNON, 2026-11-16: "go on all four"; see decision 0065 for what was
built and how it differs). Replaces the training half of 0059.
Date: 2026-11-16. Task STATION-053.

## What SHANNON asked

"concepts make the training areas have upgrading looks and make them all splinter off from the main
ranch, make them large enough for multiple animals to fit in at once. i like the speed track the
strength gym the swimming pool magic libarary, try again with the healing spring and guard yard", and
then: "make the training areas splinter off into different open areas around the ranch through the
mountains".

## What was made

Seven cards in `docs/concepts/`: one for each area, and `ranch-map-card.png` for where they stand.
An area's card is the finished area on top, the same view at upgrade levels 0 to 4 below it (the gold
squares in a frame's corner count the level), and one close look.

### Where they stand (`ranch-map-card.png`)

- The ranch keeps its fenced plot in its ring of mountains. Seven ways lead out of that ring: the
  pass down to the hub, as today, and six new passes, one to each training area.
- Each pass leaves the ranch under a gateway in its stat's colour and runs between mountains to a
  clearing of its own, ringed by mountains, with the area in its middle.
- Fact: a clearing is 264 studs across and its middle is 400 studs from the ranch's; the whole of it
  (ranch, six clearings and their mountains) is about 1,260 studs across.

### How big, and why

- Fact: an elephant is 24.5 studs long and 14 wide and tall; a lion and a rhino are 13 long and 5
  wide. The first concepts' yards (64 by 48 studs) had lanes 2.4 studs wide.
- So every area is now 2.5 times the size: 160 by 120 studs. A lane of the track is 6 studs wide,
  the pool is 100 by 45 with five lanes of 9, the barbell's frame stands 25 studs high so an
  elephant fits under the bar, a bath is 20 studs across.
- Each area has room for six animals at once. Fact: six is the most that can train at once (the
  Ranch House upgrade at its top level). The cards show five to seven animals in each.
- The four areas SHANNON liked are the same designs, grown. Their kit is animal-sized, so a player
  is small beside it.

### The six looks of each area

Level 0 is a new ranch; levels 1 to 5 are the Training Grounds upgrade's. Every area: a worn patch
and a name board (0), its floor and a fence (1), the gateway with its sign (2), a pennant at each
corner (3).

| Level | Speed Track | Strength Gym | Swim Pool |
|---|---|---|---|
| 0 | an oval beaten into the dirt | a boulder, two stones | a pond |
| 1 | the clay track, four lanes | the boulder's run, the log sled | the pool, its ladders and steps |
| 2 | hurdles, hay bales, cones | the lifting deck and barbell, five stones on plinths | lane ropes, starting blocks, palms |
| 3 | the infield: slalom, tyres, pond | chalk, spare weights, tyres, a striking post, a bell at the run's end | the lifeguard's chair, rings, floats |
| 4 | the finish gantry, the stand | the timber frame, kettlebells, an anvil | the diving tower, parasols and loungers |
| 5 | the timing tower, glowing arrows, flags | the climbing rope, braziers, flags | the tube slide |

| Level | Magic Library | Healing Spring (new design) | Guard Yard (new design) |
|---|---|---|---|
| 0 | a rug, a book on a stand, one low case | a warm spring among rocks | two straw men with shields |
| 1 | the slate floor, the open book on its plinth, desks, rugs | the terrace, the source in its basin, two baths | a court of flagstones, the first ram |
| 2 | the half ring of bookcases, scroll cases, crystal lamps | two more baths, a young tree on the source's rock, mats, bamboo | a second ram, sandbags, a rack of shields |
| 3 | the great crystal, the gold star, the orrery, the font | the last two baths, a herb garden, a cross at the way in | the stone wall, two ball throwers, armour stands |
| 4 | the arcade of columns, the window, books adrift, the hourglass | the Spring Tree grown over the source, a pavilion to rest in | a third ram, battlements, a tower at each end, braziers |
| 5 | the rune ring, rings of light, the telescope turret | lanterns in the tree, crystals, a glasshouse, stone lanterns | the great shield over the gate, banners, flags |

### The two new designs

- Healing Spring: a round pale terrace about the source; six round baths set round it like petals,
  each fed by a glowing channel; the Spring Tree growing from the source's rock, hung with lanterns
  of green light; a herb garden and glasshouse on one side, mats and a domed pavilion on the other.
  The first design was a rocky hillside with three pools, a bath house and a red bridge.
- Guard Yard: a court of pale flagstones below a stone wall with battlements and two round towers
  roofed in orange. Animals brace on marked pads against three rams (a log slung from a frame, its
  padded head swinging at them), stand behind tall shields facing two ball throwers, and spar with
  straw men. The first design was a log fort.

### How they are made

`tools/blender/stations/scenes/training.py`: an area is still written as a yard of 64 by 48 units and
grown by `K` (2.5); `lv(n)` marks from which level what follows stands; `cast` stands an animal in it
at its real size. `stage.py` renders a shot at a level and marks it with pips. Nothing is baked,
exported or uploaded.

## For SHANNON to decide

1. The looks, area by area, and the two new designs.
2. The size. 160 by 120 studs is what real animals need to share an area; it makes each area bigger
   than the ranch's own plot (150 studs square). Smaller is possible only by showing fewer animals
   or shrinking the lanes below a lion's width.
3. Where the ranches go. Fact: ranches are now 780 studs from the hub and 1,103 from each other.
   Six clearings round a ranch reach about 630 studs from its middle. Assumption (arithmetic, not
   laid out): a ranch like the map needs to stand about 950 studs from the hub (630, the hub's 250,
   and mountains between) with the ranches further apart, or the clearings must fan out only on
   the side away from the hub. Recommended: fan them over the far 250 degrees
   and move the ranches out; that undoes part of "bring the ranches in" for the walk, though the
   teleport pad is unaffected. Assumption: players mostly teleport.
4. Whether the areas all follow the one Training Grounds upgrade (as drawn), or each gets an
   upgrade of its own.
5. Still open from 0059: whether animals are seen training in their area (new animation clips).

## Not done

- No count of triangles against a budget: an area is 28,000 to 41,000 as rendered, the whole map
  277,000. Not tried in the game engine or on a phone.
- The ranch on the map is sketched (a plot, a house, a barn, a hatchery), not the real one.
