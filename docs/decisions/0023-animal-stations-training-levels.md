# 0023: Animal Stations pivot: training stations and endless levels

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Replaces the idle coin earning of 0019; changes 0021 to lobbies of 3.

## Decision

- **The goal:** train a team of three animals to clear an endless line of levels.
- **Stations train, they do not pay.** An animal left on a station gains +1 to that station's
  stat every 60 seconds (`TRAIN_SECONDS`). Training adds at most the hatched stat again
  (`POTENTIAL` = 1, so up to double) and never past `STAT_MAX` 400. Training a second stat past
  the best one changes the animal's battle type (0022).
- **Levels** (`src/shared/LevelRules.luau`): each level is an enemy team of three, the same every
  time for that level. Enemy stats are basic stats × 0.6 × 1.04^(level − 1), with no cap, so the
  levels never end. Enemies are commons from level 1, uncommons from 5 and rares from 15. Every
  10th level has a variant boss last: epic, legendary from 30, mythic from 60.
- **Battles** are automatic and deterministic. HP = 20 + half the stat total, attack =
  4 + best stat ÷ 4, × the 0022 matchup (1.25 or ÷ 1.25). Replaced by the team battle with roles
  in 0024.
- **Coins** come from clearing levels: 40 × 1.08^(level − 1) the first time, 25% of that for a
  replay. Coins buy eggs (prices unchanged for now).
- **Lobbies of 3:** a server holds 3 players, each with a home ranch at the end of the north,
  east or west road. Teams of 3 players fighting levels together come after most of the game exists.

## First balance check (tests and a Studio run)

Three Meadow commons clear level 4; fully trained, level 16; three Safari rares, 18; a
legendary team, 35. Draft numbers, to tune once battles are playable.

## Not decided yet

Battle presentation (watch it, or tap moves), whether microgames give training boosts, offline
training limits, and egg prices against level rewards.
