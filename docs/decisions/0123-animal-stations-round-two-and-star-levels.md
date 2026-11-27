# 0123: Animal Stations: round two of the decision pass, and star levels

Status: accepted (SHANNON, 2026-11-27, Round 2 of the doc "Animal Stations: your decision pass", then in chat:
"do it but make it 70 star levels for a total of 140 and make them take slightly longer and make the creatures
almost twice as powerful. yes its A. Yes a share. yes bosses. yes builds. yes seeing each other"). Task
STATION-181 makes the training change; the rest are done in their own tasks. Date: 2026-11-27.

## The answers

- 5 (training), A with stars: a stat reaches level 70 in about 4.6 days; then 70 star levels to 140, each a
  little more than twice as long as level 70, and a stat at 140 almost twice as strong as at 70.
- 5b (stronger levels), E: a level 70 stat is 3x its species value, most of it by level 50.
- 6 (ranch animals while away), A: every animal not on the team or training earns coins an hour by rarity,
  held up to 8 hours, collected at the Ranch House.
- 19 (the Windmill), A: it pays a share of the player's next wave's pay.
- Build 1, A plus: a name for each 10-wave stage, the boss rotating through the dragons and the strongest foes
  made huge with a boss tint, larger dragons, and a boss intro and health bar made in ForgeGUI.
- Builds 2, 3, 4, 6, 7, 8, 9, 10: 2 A (a smooth power curve, bosses a step up), 3 B (show how close the loss
  was and the weakest stat), 4 A (teaching goals and a reward every 5 player levels), 6 A (text of 12 px or
  more), 7 A (music and sounds made in ForgeGUI), 8 A (a short list tunable live), 9 A (Roblox's automatic
  translation, with built sentences moved into a translation table), 10 A (one PR accepting the merged tasks).
- Build 5, A, B and D: best wave in the player list, "Visit a ranch", a top-100 board at the hub, and one
  animal that follows its owner.
- Build 11 (launch plumbing and the private-place test): "talk first"; SHANNON earlier put it last.

## What STATION-181 changes

- `MAX_LEVEL` 70 to 140; `STAR_FROM` 70. Levels above 70 are star levels, written "70 ★5" (`levelText`).
- A stat's value is its species value x `StationRules.grown(level)` / 4900: 4900 + 2 x (4900 - (70 - L)^2) up
  to 70 (x1 at 0, x2.84 at 50, x3 at 70), then `STAR_PCT` (260) percent of the species value spread evenly
  over the 70 stars (x5.6 at 140, 1.87 times level 70). Whole-number maths.
- Training time (`levelSeconds`): 120 s for level 1, growing evenly to 3 hours at level 60 and 12 hours at 70
  (about 4.6 days for 0 to 70); a star level takes 27 hours, growing to 36 hours at 140 (about 91 days for all
  70 stars).
- The jackpot hatches one stat at level 70, not 140; the Ranger lends legends at level 70 (the intro and the
  loan were tuned for it).
- `StationProgress.VERSION` 4 to 5: an older server would cut a star level back to 70 when it cleans the save,
  so it must never load one (decision 0111).
- `LevelRules.END_GROWTH` 1.08 to 1.12: with stars the best teams cleared wave 300 again.

## Simulation (2026-11-27)

Last wave cleared, best picks, 4 clicks a second, the rules of decision 0121. Fresh = one fight with no boons.

| Team | Level 1 | Level 30 | Level 50 | Level 70 | Level 105 | Level 140 |
|---|---|---|---|---|---|---|
| Starters | fresh 19, run 19 to 29 | 39, run 39 to 59 | 39, run 59 | 39, run 59 | 59, run 59 | 59, run 59 |
| Mid team | 39, run 59 | 59, run 59 to 69 | 59, run 69 to 79 | 59, run 69 to 89 | 59, run 89 to 209 | 69, run 169 to 259 |
| Top variants | 59, run 79 to 99 | 89, run 249 to 269 | 89, run 259 to 279 | 89, run 259 to 279 | 99, run 269 to 279 | 119, run 269 to 289 |
| Best team | 59, run 89 to 249 | 89, run 259 to 279 | 99, run 259 to 279 | 99, run 269 to 289 | 139, run 269 to 299 | 159, run 269 to 289 |

- With the wall at 8% a wave, 2 of 32 runs of fully starred top teams cleared wave 300. At 12%, none of 64
  did (best 289), nor of 12 with damage-first picks (269 to 289). Waves up to 250 are unchanged.
- Fact: starters stop at 59 at any level: the wave 60 boss is a wall (build 2 changes the boss steps).
- Assumption: parties of two or three are not simulated.

## Not changed

Rarities (`powerRarity` reads a version's level 0 stats), XP per level, coats, the Titan's Den.
