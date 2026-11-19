# 0019: Animal Stations (game 7) foundation: stats, animals, stations

Status: proposed (draft values, for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13

## Context

SHANNON asked for a new egg animal-collecting game in which each animal has stats, and placing an
animal on the mini-game station that matches its best stat earns the most money (a fast cheetah
on the speed station). Lantern Express is paused. A concept video was accepted on 2026-11-13.

## Decision

- **Four stats:** speed, strength, swim, smarts, each 1 to 100.
- **Animals** have base stats with one clear specialty. A hatched animal gets each base stat
  × 90 to 110% (rounded down, clamped to 1 to 100), so two of the same animal can differ a little.
- **Rarities:** common, uncommon, rare, epic, legendary. Rarer animals have higher stats.
- **Eggs** list their odds on screen in basis points (sum 10000). Draft: Meadow Egg 100 coins,
  Safari Egg 2,500 coins. Eggs cost in-game coins only (decision 0002: no paid randomness).
- **Stations:** Speed Track, Strength Gym, Swim Pool, Puzzle Library, one stat each.
  `rate = coinsPerSec × (stat / 100) ^ 1.5` with `coinsPerSec = 50` for now. The curve makes a
  specialist on its matching station earn far more than anywhere else (cheetah: track ~46/s, gym ~8/s).
- All rolls happen on the server with the seeded `Rng`. The client never sends stats or amounts.

Rules live in `src/shared/StationConfig.luau` (data) and `src/shared/StationRules.luau` (pure rules).

## Open (later decisions)

Save schema and remotes, station slots and upgrades, offline earnings, the play-it-yourself
mini-game bonus, stat training or levelling, more animals and eggs, and the final balance.
