# 0030: Animal Stations base stats on hatch, mountains, and the wave arena

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Builds on 0029. Framework: simple placeholders, draft numbers.

## Decision

**Base stats on hatch**

- Every stat hatches at a level from **1 to 15**, and each higher number is a little less likely
  than the one before: the weights are 15, 14, ... 1 out of 120, so a 1 comes up 12.5% of the
  time and a 15 0.83% (1 in 120).
- **Jackpot:** 1 hatch in 100,000 has one stat (picked at random) at level **70** straight away.
- This roll replaces the old ±10% variance. Two animals of the same version now differ only in
  their stat levels, which then train up to 70 (0029).

**Mountains**

- Large rock mountains ring the hub and every ranch island, so the void is never in view. An
  invisible wall stands in front of them (the hub's walkable radius is 300 studs).

**Wave arena**

- A canyon through the hub's mountains, north of the plaza and reached by the north road, is
  where the endless waves will be fought. The player's team stands at the near end (tagged
  `WaveStand`) and the enemies will come from the far end (tagged `WaveSpawn`), which is closed
  by a mountain. Nothing is fought there yet: this is the place only.

## Checks

643 headless tests. Studio play on 2026-11-13: no script errors; rays from the hub centre and
from a ranch hit a wall in every direction, with the canyon the only way through; hatched
animals show base levels between 1 and 15 in the Animals panel.

## Not decided yet

The jackpot odds; how a wave battle is staged in the arena.
