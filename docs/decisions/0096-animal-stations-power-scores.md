# 0096: Animal Stations: power scores

Status: accepted (SHANNON, 2026-11-19: "make a power score calculator and give all creatures and enemies
power scores"); built by STATION-102.
Date: 2026-11-19. Task STATION-102.

## What

- Every animal and every enemy has a **power score**: one number for how strong it is in a wave fight.
- A fighter's score is `sqrt(effective HP x damage a second) x 10`, worked from its battle numbers
  (`BattleRules.fighter`):
  - Effective HP is HP grown by Defence (`(100 + Defence) / 100`). A Defence role divides it by the guard
    cut (0.8). A Utility role adds the heals it gives over 20 seconds.
  - Damage a second counts the power attacks a meter's fill rate allows. The player's side counts them
    as extra strikes (decision 0092); the enemies' replace an attack.
- A side's power is the sum of its fighters' scores, with the group bonuses (`BattleRules.teamPower`). By
  Lanchester's square law, two like sides are even when their sums are equal.
- In tests the side with more power won 1,406 of 1,440 wave fights (98%). The spec holds it at 95% or better.
- It is an estimate for the menus: no fight reads it.

## Where it shows

- On each animal's card in the Animals menu, and on its page.
- On each enemy card in the Waves menu.
- As a match-up chip over the wave: "you're stronger" at 110% of the wave's power or more, "a close one" from
  100%, "they're stronger" below.
- The calculator page (an artifact) uses the same formula, checked against the game's numbers for every
  version of every animal and for waves 1 to 150.

## How (facts)

- `BattleRules.scoreOf`, `powerOf`, `teamPower`, `POWER_SCALE` (10), `HEAL_SECONDS` (20).
- Tests in `tests/BattleRules.spec.luau`.
