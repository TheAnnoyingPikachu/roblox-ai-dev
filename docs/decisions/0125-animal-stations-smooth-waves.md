# 0125: Animal Stations: waves on a smooth curve, bosses one step up

Status: accepted (SHANNON, 2026-11-27, Round 2 of the decision pass, build 2 A: "Every wave is scaled to a smooth
power curve; boss waves stay a step up (about 1.5x)", then "yes builds"). The numbers are Claude's. Task
STATION-184. Date: 2026-11-27.

## Context

- Fact: a wave's swarm was scaled to the power of a "classic" wave of three foes drawn at random
  (`LevelRules.classic`, decision 0101), so from one wave to the next the power changed by 0.2x to 3.9x, and a
  boss wave's dragon made it 1.5x to 5.8x the wave before. Starter and mid teams stopped at the wave 40 and 60
  bosses whatever their training.

## What

- `LevelRules.target(level)`: the geometric mean of the classic waves' power from `SMOOTH_SPAN` (6) waves before
  to 6 after, without their dragons; a boss wave is `BOSS_STEP` (1.5) times that. Cached.
- The swarm is matched to `target` x its crowd row's power x the party's (was the classic wave's), and
  `LevelRules.power` (the menus' wave power) is `target`.
- From one non-boss wave to the next the power now changes by 0.93x to 1.16x (was 0.2x to 3.9x).
- The last wall (decision 0121) is 16% a wave from 250 (was 8%): with smoother bosses the best teams cleared
  wave 300 again.
- The intro's wave 40 is now won by the borrowed legends without the net (the net still holds at wave 60, which
  the test now checks).

## Simulation (2026-11-27, today's levels: decision 0123's star levels are not in this branch)

Last wave cleared, best picks, 4 clicks a second.

| Team | Level 1 | Level 30 | Level 70 | Before (level 70) |
|---|---|---|---|---|
| Starters | fresh 19, run 19 to 31 | 29, run 36 to 59 | 49, run 59 | 29, run 39 |
| Mid team | 49, run 69 to 79 | 59, run 79 to 109 | 69, run 99 to 258 | 59, run 59 |
| Top variants | 88, run 259 to 277 | | 109, run 259 to 282 | 79, run 249 to 269 |
| Best team | 89, run 259 to 277 | | 119, run 259 to 285 | |

- No run of 48 cleared wave 300. With the wall at 12% one best-team run did.
- To check when decision 0123 (star levels) and this meet: the wall again with stars.

## Not changed

The crowds (`CROWDS`), elites, party scaling, which foes come when, the dragons' looks.
