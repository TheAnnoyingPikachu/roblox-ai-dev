# 0022: Animal Stations battle matchups

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Builds on 0021 (turn-based creature battles).

## Decision

- The four stats form one rock paper scissors loop. Each stat beats one, loses to one, and is
  neutral to the one opposite it:

| Stat | Beats | Loses to | Neutral |
|---|---|---|---|
| Speed | Smarts (rushes it before it can plan) | Swim | Strength |
| Smarts | Strength (outwits brute force) | Speed | Swim |
| Strength | Swim (muscles through the current) | Smarts | Speed |
| Swim | Speed (water slows runners) | Strength | Smarts |

- The advantage is slight: damage × 1.25 with the advantage, ÷ 1.25 against it
  (`StationConfig.ADVANTAGE`). A much stronger animal still wins a bad matchup.
- An animal battles as its highest stat (`StationRules.battleType`), so a cheetah is Speed and an
  owl is Smarts. `StationRules.matchup(attacker, defender)` gives the multiplier.

## Not decided yet

Turns, moves, HP and damage formula, and whether a variant's twist stat can give it a second type.
