# 0071: Animal Stations: an open, bigger homestead with more to upgrade (concept)

Status: accepted (SHANNON, 2026-11-17: "do all those buildings, do all your suggested drafts, the area doesnt
need to be bigger just needs to fit everything"); in the game by decision 0072, at 224 studs across.
Date: 2026-11-17. Task STATION-064.

## What SHANNON asked

"make a new more open style middle ranch area, and make it bigger with more upgrades", then: "like
just the middle not the training grounds".

## What was made (`docs/concepts/ranch-homestead-card.png`)

The middle of the ranch as an open green. The training grounds are not touched.

- **Open.** No fence round it. The herd's meadow is at its heart, inside a low kerb with a gap at
  every way. A ring path runs round the meadow and the buildings stand round the path with open
  ground between them. Each way out to a training ground leaves between two buildings, under a
  board in its stat's colour. The gate is two stone posts under the owner's name; a low wall each
  side stops after a few steps.
- **Bigger.** 300 studs across. The fenced plot is 150 a side, so this is about three times the
  ground.
- **More to upgrade.** Eight buildings in the middle, where the plot has two. A building that is
  not bought yet is a staked plot with its name on a board.

The card shows the finished homestead, its plan, a new ranch, a ranch half built, and three closer
views. The pips on a view say how far the ranch is built (none: new; five: everything bought).

## The buildings

| Building | What its upgrade gives | In the game today | Draft levels |
|---|---|---|---|
| Ranch House | animals training at once | an upgrade, 2 to 6 | unchanged |
| Barn | animals you can keep | an upgrade, 10 to 80 | unchanged; the meadow shows more of the herd as it grows |
| Hatchery | eggs hatching at once | fixed at 6 | 3, 4, 5, 6, 8, 10 |
| Egg Cellar | eggs you can store | fixed at 24 | 8, 12, 18, 24, 36, 48 |
| Brooder | hatching speed | fixed | 100% to 200% |
| Windmill | coins every hour, also while you are away | nothing like it | to be set |
| Trophy Lodge | more coins from waves | nothing like it | up to +50% |
| Titan's Den | the Titan's stats in a wave | nothing like it | up to +20% |

The Training Grounds upgrade stays as it is. The two vendors' stalls stand by the gate and are not
an upgrade.

- Facts: the "today" column is `StationConfig.UPGRADES`, `StationProgress.MAX_EGGS` and
  `MAX_STORED`.
- Hypotheses: every draft number. None is playtested and no price is proposed.
- Assumption: nobody has a save that matters yet (nothing is published), so a new ranch may start
  with fewer nests and less storage than today's fixed numbers.

Each building has three looks on the card (for example the Hatchery: three nests under a canvas, a
round pavilion of six, a great one of ten under a two-tiered roof). In the game each level would
change something, as the training areas do.

## What a bigger middle does to the valley

- Fact: today the homestead's level round is 112 studs in radius and the grounds' middles are 270
  to 300 studs out (decision 0070).
- Assumption: the paths keep today's slope. A round 150 in radius then needs every ground about 40
  studs further out, a valley about 80 studs wider, and the ranches about 985 studs from the hub
  (900 today). On foot, the homestead's middle to a ground's middle becomes about 20 seconds.
- The smaller option: the same layout 224 studs across fits the valley as it stands (still about
  1.75 times the plot's ground), with less open ground between the buildings.

## For SHANNON to decide

1. The layout and the look: go, or changes.
2. The size: 300 across as drawn (recommended, since bigger was asked for; the valley's grounds and
   the ranches move out), or 224 across (nothing else moves).
3. Which new upgrades. Recommended: the Hatchery, the Egg Cellar and the Brooder, which only raise
   numbers the rules already have. The Windmill (a new income), the Trophy Lodge and the Titan's
   Den each add something new to the economy or the fights: say yes or no to each. Any of them
   needs its own decision record with prices before it is built.
4. The go-ahead to build the buildings as models and upload them, as the training areas were.

## Not done

- Nothing is built for the game, exported or uploaded. No rule or number is changed.
- The card stands the homestead on flat ground: the valley round it is not drawn.
- Three looks a building, not one for every level. Not tried in the game engine or on a phone.
