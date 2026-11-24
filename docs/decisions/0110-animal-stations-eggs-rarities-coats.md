# 0110: Animal Stations: twelve eggs, rarity by power, stronger variants, ten coats

Status: accepted (SHANNON, 2026-11-24, below). The numbers are Claude's draft, to confirm at the checkpoint.
Date: 2026-11-24. Task STATION-129. Replaces decision 0031's "no legendary-only egg" and decision 0037's two
variant tiers; extends decision 0058 (the rainbow coat) to a family of coats.

## Context

- Fact: four eggs, the last open at wave 20, with 300 waves (decision 0107). Every egg dropped every animal
  of its tier. Rarity did not follow power: the "mythic" Comet Meerkat (444) was weaker than the
  "legendary" Shadow Lion (660).
- Concept: the canvas "Eggs, Rarities and Coats" (boards: the plan, the egg ladder, rarities, coats shot on
  the game's Lion in Studio, the drop matrix, and the new eggs' looks).
- SHANNON, 2026-11-24: "make a plan to spread the animals sparsly through more eggs ... make higher tier eggs
  drop nothing but good varients, ... concepts for more texture variants like rainbow and what each variant
  will give as a buff, make more creature rarities and adjust the current rarities so the most powerful
  creatures all come in a higher rarity and from harder to obtain eggs"; then, on the concept: "make the
  current special variants slightly stronger so they are epic or legendary at least ... we wont be making
  any more [animals] yet so just do what you can with the current animals, if need be you could make some
  animals even more powerful to fit them into higher rarities ... yes the super high level eggs will only
  drop high rarity variants. i like the guilded coat but make it increase XP gain instead. also make the
  rainbow coat rarer and make the primsatic coat extremely good like 30% to each stat ... dont make the
  crown egg drop guarenteed prismatic ... but make it a higher chance".

## What

### Rarity by power (`StationRules.powerRarity`)

- Nine rarities: common, uncommon, rare, epic, legendary, mythic, divine, celestial, secret (kept for later;
  none yet). A version's rarity is the band its stat total falls in: under 180 common, 180 uncommon, 260
  rare, 400 epic, 550 legendary, 800 mythic, 1,100 divine, 1,600 celestial. A Titan's bands are 1.6 times as
  wide. A spec checks every version.
- The Tortoise moves to uncommon, the Rhino to rare, the Elephant to epic.
- Each variant has its own `mult` (its stats are the species' x mult, its twist stat gains 20 x mult more),
  set so it lands in its band. Every variant is at least epic. Epic: Pharaoh Jackal, Alien Meerkat,
  Gemshell Tortoise, King Flamingo, Thunder Cheetah. Legendary: Sphinx Jackal, Comet Meerkat, Island
  Tortoise, Phoenix Flamingo, Lava Rhino. Mythic: Lightning Cheetah, Shadow Lion, Acacia Giraffe, War
  Elephant. Divine: Crystal Rhino, Diamond Giraffe (SHANNON swapped the two rhinos' places, 2026-11-24). Celestial: Sun Lion, Frost Mammoth.
- `STAT_MAX` (a version's stat) goes from 400 to 1,000, so the strongest are not cut short.

### Twelve eggs (`StationConfig.EGGS`)

| # | Egg | Opens | Price | Animals | Variants | Signature coat |
|---|---|---|---|---|---|---|
| 1 | Meadow | start | 100 | Jackal, Meerkat | Pharaoh Jackal, Alien Meerkat 1 in 5,000 | none |
| 2 | Wild | start | 1,500 | Jackal, Tortoise, Cheetah | Gemshell Tortoise, Thunder Cheetah 1 in 4,000 | Storm |
| 3 | Safari | wave 10 | 15K | Meerkat, Flamingo, Rhino | King Flamingo 1 in 2,000; Comet Meerkat 1 in 10,000 | Ember |
| 4 | Golden | wave 20 | 50K | Cheetah, Lion, Giraffe, Elephant 5% | Thunder Cheetah 1 in 2,000; Lightning Cheetah 1 in 25,000 | Gilded |
| 5 | Dusk | wave 35 | 140K | Tortoise, Rhino, Jackal | Island Tortoise, Sphinx Jackal 1 in 5,000; Lava Rhino 1 in 8,000 | Obsidian |
| 6 | Oasis | wave 50 | 430K | Flamingo, Giraffe, Meerkat | Phoenix Flamingo 1 in 5,000; Acacia Giraffe 1 in 20,000 | Verdant |
| 7 | Ivory | wave 75 | 3M | Elephant 40%, Rhino, Lion | War Elephant 1 in 5,000; Shadow Lion 1 in 20,000 | Frost |
| 8 | Legend | wave 100 | 20M | variants only | epic 80%, legendary 20% | Spectral |
| 9 | Mythic | wave 140 | 440M | variants only | legendary 85%, mythic 15% | Galaxy |
| 10 | Divine | wave 180 | 9.6B | variants only | mythic 90%, divine 10% | Prismatic (1 in 2,000) |
| 11 | Celestial | wave 230 | 450B | variants only | divine 95%, celestial 5%; always a coat | none |
| 12 | Crown | wave 300 cleared | 98T | variants only | Sun Lion, Frost Mammoth; always a coat, Prismatic about 1 in 9 | Prismatic x20 |

- Each animal hatches from one to three eggs, each variant from one to three. A variant-only egg's drops
  add up to a million (`only`). A price is about 250 first clears of the wave that opens the egg. The new eggs' models are in `tools/blender/stations/assets/eggs.py` (concept board "How each egg looks") and
  uploaded (upload-assets run 45377796460).

### Ten coats (`StationConfig.COATS`)

One coat at most per animal, rolled after the animal; an egg's signature coat is 5 times as likely.

| Coat | Odds | Buff |
|---|---|---|
| Prismatic | 1 in 10,000 | +30% every stat |
| Spectral | 1 in 2,500 | once a fight, a blow that would knock it out leaves it at 1 HP |
| Galaxy | 1 in 1,000 | +12% Mana; its power meter starts each fight a quarter full |
| Gilded | 1 in 1,000 | +25% player XP from a wave it fights in (up to three count) |
| Rainbow | 1 in 500 (was 1 in 200) | +5% every stat (decision 0058) |
| Ember, Frost, Storm, Obsidian, Verdant | 1 in 400 each | +12% Strength, Health, Speed, Defence, Stamina |

- Looks (`Creatures.spawn`): Rainbow and Prismatic wear the rainbow texture; the rest are a tint, an outline
  and an effect over the model, as shot on the concept board. Galaxy and Prismatic should get their own
  textures later.
- Saves: an animal gains `coat` (an id); `rainbow = true` is kept beside `coat = "rainbow"`, and a save from
  before coats with only `rainbow = true` reads as the rainbow coat. Nothing is rewritten.
- Trades weigh a coat by its rarity (`StationTrade.COAT`); giving any coat or a mythic or higher needs a hold.

## Amended (SHANNON, 2026-11-24): small boons, rare boons rarer, a quicker walk-in

- SHANNON: "speed up the time it takes for the next wave to hit ... nerf all the boons to much smaller
  numbers so that wave 300 requires both a good team and good boon stacks, also decrease the frequency of
  special boons to about one or two every stage".
- Boons (`WaveRuns.CLAWS`, `HIDE`, `QUICK`): Sharp Claws +5% damage (was 20), Thick Hide +5% max HP (was 20),
  Quick Paws 3% faster (was 12), each stack multiplying. Charged Up and Second Wind are unchanged.
- Rare boons (Revive, Lucky Find, Gold Rush) stand in `RARE_PCT` 15 offers of 100, at most one an offer:
  about 1.5 a stage of 10 waves (before: in most offers).
- The steep waves after 100 are retuned for the small boons: `STEEP_GROWTH` 1.013 (was 1.08; 1.016 until clicking became a bonus, decision 0106); `STEEP_BEND`
  200 as before. The enemies walk out of the gate at 18 studs a second (was 13).
- Simulation at 1.016 (4 clicks a second, a Good press 1.5 s after each meter fills: `EXPIRE_FAILS` off,
  `AUTO_FIRE` 1.5 in the sim, as a run out press now fails): the best team with good picks clears 300 or 299;
  random picks 169; at 1.017 good picks stop at 269 to 279. Before the fail (no presses, AUTO_FIRE 6, 1.014): the best
  team with good picks reaches 289, 299 or 299 (three seeds). At 1.015 and AUTO_FIRE 4 it cleared 279, 289 or 300 (three
  seeds); with random picks 169 or 189. Mythics at level 40 now stop at 79 to 89 (before 129 to 149): the
  middle waves are harder too, as boons no longer carry a team. Three players not re-simulated.

## Amended (SHANNON, 2026-11-24): eggs by player level

- SHANNON: "we're going to lock eggs behind player level instead of wave". An egg's `level`
  (`StationProgress.playerLevel`) replaces its `wave`: Safari 5, Golden 8, Dusk 12, Oasis 16, Ivory 24, Legend
  32, Mythic 42, Divine 54, Celestial 68, Crown 85 (draft: the level a player has from the waves' XP alone at
  each egg's old wave, rounded up; buying and training add XP). The bands and `mult`s stay as drafted
  (SHANNON: "do as you see fit").

## Amended (SHANNON, 2026-11-24): payouts and prices shrunk together

- SHANNON: "shrink both accordingly but still keep the numbers quite high to make them seem cool and expensive".
- Waves pay 5.5% more each (`LevelRules.REWARD_GROWTH` 1.055, was 1.08). Each egg's price is cut by the same
  share as the coins all first clears pay up to its old unlock wave, so an egg takes about as many runs as before,
  rounded: Safari 15,000, Golden 40,000, Dusk 85,000, Oasis 185,000, Ivory 750,000, Legend 2.75 million, Mythic
  25 million, Divine 200 million, Celestial 3 billion, Crown 125 billion (was 98 trillion). Meadow and Wild
  unchanged. Ranch upgrades (up to 800,000) are unchanged. Draft: the QA pass checks them.

## Evidence

- Specs: `StationRules` (twelve eggs, rarity by power for every version, coats' odds and buffs),
  `BattleRules` (Spectral, Galaxy), `StationProgress` (Gilded XP, coats in saves). 789 pass.
- Played in Studio (build dev, local): the HUD loads (it is at Luau's local limit), the egg vendor lists all
  twelve (the tab column now scrolls clear of the chips), the Animals panel shows the new rarities and coat
  chips and a Coats tab.

- The waves (decision 0107's simulation, 4 clicks a second, re-run with the new variants): the best team
  there is (Sun Lion, Crystal Rhino, Diamond Giraffe, Frost Mammoth, all level 70) with the best boon picks
  clears 289 to 300, wave 300 in 2 runs of 12, as decision 0107 aimed for; with random picks 159 to 169. A
  team of mythics at level 40 reaches 129 to 149 with random picks. Steepening the curve (`STEEP_BEND` 190)
  shut wave 300 to everyone, so the curve stays as it is: boons, not the team, decide the last waves.
- Three players (three strong teams of four, 4 clicks a second each, the best boon picks) stop at wave 280,
  289 or clear 300 (three seeds): where one player with the best team does. A crowd 4 to 16 times stronger
  for three costs them only 10 to 20 waves, so `PARTY_POWER` stays. Every late wave is all or nothing: won
  waves end in about 4 seconds (wave 250, staged in Studio: 32 down, the Ancient Alpha Dragon too, in 4.0 s).
- Saves: nobody has a save yet (SHANNON), so stored animals need no restat.

## To confirm at the checkpoint

1. Prices, hatch times and odds: in the QA pass.
2. The bands and the variants' `mult`s (draft).
