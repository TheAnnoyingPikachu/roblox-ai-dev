# 0072: Animal Stations: the open homestead in the game, with six new ranch upgrades

Status: accepted (SHANNON, 2026-11-17: "do all those buildings, do all your suggested drafts, the
area doesnt need to be bigger just needs to fit everything"). Builds decision 0071. Changes the
economy and the save (rule 8). Tasks STATION-065 (the rules), 066 (the models), 067 (the game).

## How SHANNON's answer was read

| Question of 0071 | Read as | Done |
|---|---|---|
| 1. The layout and the look | go | built |
| 2. 300 studs across, or 224 | 224: the homestead fills the round the valley already levels, nothing else moves | built |
| 3. Which new upgrades | all six, with the drafts | in the rules |
| 4. Build the buildings as models | go | 24 models uploaded |

## The homestead

Open, with no fence. The square plot, its lawn and its fence are gone; the gate stays, with a low
wall each side that stops after a few steps. The lawn is the valley's own grass.

- The herd's meadow in the middle (34 studs in radius) inside a low kerb with a gap at every way.
  The first eight animals roam it.
- A ring path round the meadow. A path runs from it to each training ground, the road runs from
  it to the gate, and a short path leads to every building's door. Dirt at first, then paved.
- Round the path, the eight buildings. A building has three looks, and its levels are spread over
  them; one that a new ranch does not have is a staked plot with its name on a board.
- The two vendors' stalls by the way in. More comes with the sum of all levels: benches, lamps, an
  orchard, flowers, a field, a well, a shelter, a garden, a fire, hives, flags.

The card `docs/concepts/ranch-homestead-card.png` is drawn again at this size. It is the other way
round from the first card: seen from above, the valley's plan runs the other way than the first
card drew it. The buildings stand between the same paths.

## The upgrades (draft numbers: none playtested)

Coins, with samples in brackets. The first three raise numbers the rules had as fixed; the last
three are new.

| Building | Gives | New ranch | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 |
|---|---|---|---|---|---|---|---|
| Hatchery | eggs hatching at once | 3 | 4 for 400 | 5 for 2,500 | 6 for 12,000 (10) | 8 for 60,000 (40) | 10 for 300,000 (120) |
| Egg Cellar | eggs you can store | 8 | 12 for 300 | 18 for 1,500 | 24 for 8,000 (5) | 36 for 40,000 (30) | 48 for 200,000 (100) |
| Brooder | hatching speed | 100% | 115% for 1,000 | 130% for 5,000 | 150% for 25,000 (10) | 175% for 120,000 (50) | 200% for 500,000 (150) |
| Windmill | coins an hour | none | 60 for 2,000 | 150 for 10,000 | 400 for 40,000 (15) | 1,000 for 150,000 (50) | 2,500 for 500,000 (150) |
| Trophy Lodge | coins from waves | 100% | 110% for 1,500 | 120% for 8,000 | 130% for 40,000 (15) | 140% for 180,000 (60) | 150% for 600,000 (200) |
| Titan's Den | the Titan's stats in a wave | 100% | 104% for 3,000 | 108% for 15,000 (5) | 112% for 60,000 (25) | 116% for 250,000 (80) | 120% for 800,000 (250) |

The Ranch House, the Barn and the Training Grounds keep their numbers.

### How each works

- **Hatchery and Egg Cellar.** A new ranch has three nests and room for eight stored eggs (six and
  24 before, fixed). A save is never cut down: eggs already hatching or stored stay, up to the top
  levels' numbers (10 and 48), which are now the most a save can hold.
- **Brooder.** An egg's time is divided by the Brooder's speed, rounded up to whole seconds. The
  level a player has now counts for the whole wait, also for an egg already hatching.
- **Windmill.** It fills with whole coins for the time since it was last emptied, also while its
  owner is away, up to eight hours' worth, and pays when the owner collects at the mill (decision
  0073; at first it paid by itself once a minute). The save gains `mill`, its clock.
- **Trophy Lodge.** Multiplies the coins a cleared wave pays, rounded down. Not its XP or samples.
- **Titan's Den.** Multiplies every stat of the Titan in a wave fight, rounded down. Nothing is
  stored on the animal: the boost is put on the copy that fights. Once the den is built the Titan
  stands in it and no longer roams.

Facts: the table is `StationConfig.UPGRADES`; the rules are `StationProgress` and `StationRules.stat`,
with a test for each. Hypotheses: every number.

### Looks by level

| Building | Plot | Look 1 | Look 2 | Look 3 |
|---|---|---|---|---|
| Ranch House | | levels 0, 1 | 2, 3 | 4 |
| Barn, Hatchery, Egg Cellar | | 0, 1 | 2, 3 | 4, 5 |
| Brooder, Windmill, Trophy Lodge, Titan's Den | level 0 | 1, 2 | 3, 4 | 5 |

The Hatchery always has as many nests as its level gives. The egg rack shows 12 stored eggs in the
first look and 24 in the others; the rest are down in the cellar.

## How it is built

- 24 models `home_<upgrade>_<look>` (`tools/blender/stations/assets/homestead.py`, from the makers
  of `scenes/homestead.py`), uploaded by run 44137951448. A model leaves out what the game stands
  itself: the eggs, their nests and rack, the Titan, the windmill's sails (which turn on a motor).
- `src/stations/Ranch.luau` stands them, adds unseen blocks where a model is solid, and builds the
  rest from parts. `World.luau` no longer builds a lawn or a fence.
- `ValleyMap`: every way now starts on the ring path, straight towards its ground. The grounds have
  not moved.

## Not done

- Nothing happens at the Trophy Lodge or the Brooder but their numbers: no trophies for waves
  cleared, no eggs on the warm beds.
- Three looks a building, not one for every level.
- No sound. Nothing new on a phone was looked at.

## Checkpoint for SHANNON

Answered on 2026-11-17: items 1 to 3 are good as they are; item 4, collect by hand, is decision 0073.

1. The prices and numbers above are drafts: say which to change.
2. A new ranch now starts with three nests and room for eight stored eggs, not six and 24.
3. The Brooder speeds up eggs already hatching (kinder and simpler than counting time at the old
   speed).
4. The Windmill pays by itself. A hand collect at the mill would make it something to visit.
