# 0107: Animal Stations: 300 waves, steep to the last

Status: accepted (SHANNON, 2026-11-24, below). The numbers are Claude's draft, to confirm at the checkpoint.
Date: 2026-11-24. Task STATION-122.

## Context

- Fact: a run's boons multiply with no limit (`WaveRuns.setup`: +20% damage, +20% HP or 12% faster for each
  one picked), while the waves grew 3% a wave with no last wave. The release review of 2026-11-23 found that a
  run that gets going never ends: a starter team at stat level 8 cleared wave 150 in 41 minutes in the
  simulation.
- SHANNON, 2026-11-23: "do not fix the stacking modifiers but we will make a cap on the levels and make it
  quite hard to reach". 2026-11-24: "make like 300 levels and make the later levels very hard".
- Fact, met on the way: every stat of a foe grew by the one number, so its swing and its rest shrank with it
  (`BattleRules.fighter`: 1.5 s x 100 / (100 + speed)). At 3% a wave a foe of wave 300 would swing hundreds
  of times a second, and the fight would end on `MAX_ACTIONS`, not on the rules.

## What

- `LevelRules.LAST` = 300 is the last wave. `StationProgress.canFight` refuses a wave past it. A run that
  clears it ends there: its pot is paid in full, no boons are offered, and the result carries `last`. The
  wave menu stops at it.
- Waves 1 to `STEEP_FROM` (100) are as they were: every stat grows 3% a wave.
- After wave 100 the Legion gets no faster: speed, stamina, mana and defence hold at wave 100's. Health and
  strength (`STEEP_STATS`) grow instead, by `LevelRules.might(wave)` =
  `STEEP_GROWTH ^ (n x (1 + n / STEEP_BEND))` for the n-th steep wave, with `STEEP_GROWTH` 1.08 and
  `STEEP_BEND` 200. That is 8% on wave 101, 12% a wave at 150, 17% at 200, 21% at 250 and 26% at 300.
- The strongest boon adds 20%, so from about wave 250 a run loses ground on every wave whatever it picks.
- Display: the numbers that outgrow `Format.commas` in the late waves (a wave's power, a foe's power, the
  MVP's damage) use `Format.short`.

## Why a curve that keeps steepening

- Rejected: one steeper rate after wave 100. In the simulation 12% a wave let strong teams clear all 300,
  and 16% stopped the best team near wave 220 with one way of picking boons and let it reach 300 with
  another. Where a run stops then depends on a second decimal.
- A rate that keeps rising passes every way of stacking sooner or later, so the wall is there for all of
  them, and the team and the picks decide only how far up it a run climbs.

## What the numbers do (simulation, 2026-11-24)

`BattleRules.battle` over whole runs from wave 1, 4 clicks a second, no power presses, boons picked by a
fixed order. Starter 8 = jackal, tortoise and meerkat at stat level 8. Mid 35 = lion, rhino, flamingo and
an elephant at 35. Max 70 = the four mythics at 70. The last wave cleared:

| Team | Picks at random | Damage, HP, speed first | Damage, speed first |
|---|---|---|---|
| Starter 8 | 29 to 30 | 159 to 229 | 269 |
| Mid 35 | 89 to 129 | 239 | 269 to 289 |
| Max 70 | 149 to 159 | 269 | 279 to 300 (300 in 1 run of 6) |

- A run to the top is about 83 minutes of fighting from wave 1.
- A fresh run (no boons) wins from wave 17 at most (Starter 8), 39 (Mid 35) or 69 (Max 70). Every wave
  past that is only reached inside one unbroken run.
- With no clicks at all and the best picks, Max 70 reaches 269 to 289; Starter 8 loses its second wave.

## To confirm at the checkpoint

1. The numbers: `LAST` 300, `STEEP_FROM` 100, `STEEP_GROWTH` 1.08 (1.016 since decision 0110's amendment: small
   boons and press fails), `STEEP_BEND` 200.
2. Fact: with boons stacking, the picks decide far more than the team. A starter team that always takes
   damage and speed reaches wave 269. Quick Paws is the lever: a click is worth `STRIKE_SECONDS` of its
   animal's own attacking, so each 12% faster also makes every click 13.6% stronger. Not changed
   (the stacking stays, as SHANNON said).
3. Fact: rewards still grow 8% a wave to the end. Wave 300's first clear pays 394 billion coins and all 300
   pay 5.3 trillion; the dearest egg costs 50,000. Not changed here: it is an economy decision of its own.
4. Fact: the last waves take one sitting of over an hour, since a run cannot be resumed.

## Not changed

Boons, rewards, crowds (`CROWDS`' last row starts at wave 40), stage names (stage 6 and on is The
Ancient) and the shared fight for three players (decisions to come).
