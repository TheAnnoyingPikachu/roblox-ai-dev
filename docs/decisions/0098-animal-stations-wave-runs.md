# 0098: Animal Stations: wave runs and boons

Status: accepted (SHANNON, 2026-11-19: concept C on the fight concepts page, "A and B and C are all good");
built by STATION-104.
Date: 2026-11-19. Task STATION-104.

## What

- Fighting a wave starts a **run**. "Next wave" after a win carries on the run; leaving the arena or losing
  ends it.
- **HP carries over** from wave to wave. Between waves each standing animal heals 20% of its max HP, and a
  knocked-out animal stays down.
- After each win the player **picks one of three boons**. A boon lasts the rest of the run (weights in
  brackets):
  - Sharp Claws (10): +20% damage.
  - Thick Hide (10): +20% max HP.
  - Quick Paws (8): attacks 12% faster.
  - Charged Up (8): meters start half full.
  - Second Wind (8): heals the team to full.
  - Revive (4, rare): brings the knocked out back at half HP.
  - Lucky Find (4, rare): double samples for the rest of the run.
  - Gold Rush (4, rare): +25% coins for the rest of the run.
  - Boons that stack multiply.
- **Pay:**
  - Each wave pays as it always has, at once.
  - On top of that a **pot** grows with each win. It holds a streak bonus (5% of the wave's coins for each
    win in a row before it, up to 100%), Gold Rush's coins and Lucky Find's samples.
  - Leaving the arena banks the whole pot; a loss banks half. A player who leaves the game banks it all.
- A **boss chest** comes with every boss wave cleared in a run. In turn: the best egg, hatching x2 for
  1 hour, training x2 for 1 hour.
- The run lives on the server (not in the save): a server that stops loses the pot, never the waves' own pay.

## How (facts)

- Rules: `src/shared/WaveRuns.luau` (pure); `BattleRules.battle`'s `setup` (start HP, meters, damage,
  max HP, tempo) and its fourth result (the team's HP at the end).
- Tests: `tests/WaveRuns.spec.luau`.
- Remotes: `boon` (pick from the offer: it also starts the next wave), `wave_done` (leave: banks the pot).
- `StationRewards.bossChest`.
