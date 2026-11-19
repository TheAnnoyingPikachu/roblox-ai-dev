# 0020: Animal Stations basic and variant versions

Status: proposed (draft values, for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Amends 0019 (replaces its 11 animals).

## Decision

- 16 species, four per stat. Each has a **basic** version (common, uncommon or rare) and three
  **variants**: epic (1 in 200 per hatch), legendary (1 in 2,000), mythic (1 in 20,000).
- Eggs roll the species. The variant roll happens on top and is the same in every egg.
- A variant's stats are the basic stats × 1.5, 2 or 3, plus 25, 40 or 60 on its twist stat, so
  some variants become good at a second station. Stats now cap at 400, and the rate formula
  divides by 100, so a variant can earn more than a station's base `coinsPerSec`.
- Eggs: Meadow 100, Wild 1,500, Safari 15,000 coins (in-game coins only, decision 0002).
- The saved animal is `{ s = species, v = variant or nil, stats }`. The stats are rolled once and stored.

Looks and the full list: `docs/game-design/game7-animals.md`.
