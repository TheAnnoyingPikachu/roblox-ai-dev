# 0124: Animal Stations: ranch animals earn while away, and the Windmill pays a share of the next wave

Status: accepted (SHANNON, 2026-11-27, decision 0123: Round 2 answers 6 A and 19 A, "yes its A. Yes a share").
The numbers are Claude's draft. Task STATION-182. Date: 2026-11-27.

## What

- **The Windmill** (`StationProgress.millRate`): each hour it makes its level's coins (60 to 2,500, as before) or
  `share` percent of the next wave's first-clear pay (2, 4, 6, 8, 10 by level), whichever is more. It still holds
  `MILL_HOURS` (8) and is emptied at the mill.
- **Ranch animals** (`herdRate`, `herdHeld`, `collectHerd`): every animal not on the team, not the Titan in its
  slot and not training earns each hour its rarity's `HERD_PERMILLE` of the next wave's pay, or its `HERD_FLOOR`
  in coins when that is more. Held up to `HERD_HOURS` (8). The Ranch menu's header has a **Collect** button.

| Rarity | Per mille of next wave an hour | Floor, coins an hour |
|---|---|---|
| common | 0.5 | 1 |
| uncommon | 1 | 2 |
| rare | 2 | 4 |
| epic | 4 | 8 |
| legendary | 8 | 15 |
| mythic | 15 | 30 |
| divine | 25 | 50 |
| celestial | 40 | 80 |
| secret | 50 | 100 |
| eternal | 60 | 120 |

- Data schema: the save gains `herd` (when the animals' coins were last collected, os.time; an old save starts
  from its first load). An older server drops it: up to 8 hours of animal coins restart, nothing else.
- Remote contract: a new request `collect_herd()`, which pays `herdHeld` and resets the clock (`herd_empty` when
  there is nothing).

## What it comes to (2026-11-27)

Six basic animals off the team (rare and epic), Windmill level 2 and 5:

| Best wave + 1 | Its first clear | Windmill L2 an hour | Windmill L5 an hour | Full Windmill L5 (8 h) | Animals an hour |
|---|---|---|---|---|---|
| 50 | 551 | 150 | 2,500 | 36 waves' pay | 20 |
| 100 | 8,017 | 320 | 2,500 | 2.5 waves | 80 |
| 150 | 116,594 | 4,663 | 11,659 | 0.8 waves | 1,164 |
| 250 | 24,655,989 | 986,239 | 2,465,598 | 0.8 waves | 246,554 |

- Fact: before, a full Windmill was at most 20,000 coins, less than a wave 100 first clear.
- Shortcut: the animals' whole time is paid at the rate when collected, so moving animals off the team just before
  collecting pays a little more.

## Not changed

The Windmill's prices and flat coins, `MILL_HOURS`, where it is emptied.
