# 0095: Animal Stations: the watering hole hub

Status: accepted (SHANNON, 2026-11-19: "go for the watering hole but add the monthly rainbow statue i like
that addition", from the hub designs page); built by STATION-101.
Date: 2026-11-19. Task STATION-101. Replaces the gathering place of decision 0064.

## What SHANNON chose

- A savanna oasis in the middle of the plaza: a pond in a sandy rim with lily pads and reeds, a leaning
  acacia over it, and a ring path round it with five stops: the Trading Post (north-east), the Gift Stand
  (north-west), the campfire (south-west), the Hall of Fame (south-east) and the notice board by the south
  road. The plaza keeps its size and its four roads.
- On a rock on the pond's south bank, the month's rainbow animal (StationRewards.rainbowOf) stands as a
  statue twice its size, facing the road players come in on. It changes with the month.

## How (facts)

- Blender: tools/blender/stations/scenes/watering_hole.py (the pieces and their numbers) and
  assets/hub.py (eight models, built where they stand). The old hub models (floor, fire, market, cafe,
  stage, green, lights, signs) are gone.
- World.luau stands the models, puts unseen solid blocks where they are, stands the statue and the
  visitors, writes the notice board (the month's rainbow, the wheel's jackpot, boss waves) and puts
  prompts at the two stalls (tags HubTrade and HubGifts): the HUD opens Trade or Gifts.
- The Hall of Fame: StationsServer picks this server's best animals (rarest first, rainbow coats first,
  at most two of a player's) a moment after any save changes, and World.setFame stands them on the four
  pedestals with their owners' names over them.
