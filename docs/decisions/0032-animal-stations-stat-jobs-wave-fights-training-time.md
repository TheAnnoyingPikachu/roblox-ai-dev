# 0032: Animal Stations stat jobs, wave fights on a clock, training time, XP sources

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Replaces the battle rules of 0024 and 0027, the role loop of 0022 and 0027 for
waves, the training numbers of 0029 and the hatch odds of 0030. Framework: draft numbers.

## Decision

**Each stat has one job** (from SHANNON), and they apply to wave fights only:

| Stat | Job | Draft formula |
|---|---|---|
| Speed | attack speed: how fast an attack happens | swing = 1.5 s × 100 ÷ (100 + Speed) |
| Stamina | the delay between attacks | rest = 1.5 s × 100 ÷ (100 + Stamina) |
| Strength | damage | 4 + Strength ÷ 4 |
| Mana | energy each attack gives towards the power attack | 10 + Mana, power attack (× 2) at 200 |
| Health | HP | 20 + 1.5 × Health |
| Defence | cuts incoming damage | × 100 ÷ (100 + Defence) |

- **Species still matter:** a stat's value is the species' number grown by its level (doubled
  at level 70), so the same level is worth more on a stronger species.
- **Wave fights run on a clock.** An animal's first attack lands after one swing, then it rests
  and swings again. The fight is deterministic and decided by the server. One that lasts 300
  seconds counts as lost.
- **Roles are jobs, not a rock paper scissors loop.** Attack: damage × 1.3. Defence: enemies must
  hit it first and it takes × 0.8. Utility: each attack also heals the most hurt teammate by 8%
  of the healer's own max HP. The loop of 0022 and 0027 is removed from wave fights.
- **Fights between players will work differently, and stats will not affect them.** Nothing is
  built with them in mind.
- Waves grow 3% a wave (was 4%), because every stat now does more. The Rhino's stats were
  trimmed to 25 / 50 / 60 / 10 / 70 / 55 so three of them no longer match a balanced team.

**Hatch rolls**

- A base 15 is **1 in 90**. The weights step down evenly: a 15 has weight 7 and every level
  below it 5 more, out of 630 (a 1 is 77 in 630, about 1 in 8).
- The jackpot (one stat at level 70) is **1 in 10,000** hatches.

**Training time**

- Every level takes a little longer than the one before: 2 minutes for level 1, growing about
  12% a level to **24 hours at level 61**, then about 8% a level to **48 hours at level 70**.
  One stat from 0 to 70 takes about 23 days; the first 20 levels about 2.3 hours.
- Training runs in real time, also while the player is away. The 8 hour offline cap is removed,
  since a level can take two days.
- **Training enhancements** will shorten these times later (not built).

**XP comes from everything**

- Built: hatching (10 to 500 by egg) and 5 XP for every stat level a creature gains.
- To add when they exist: clearing waves, the daily, weekly and monthly login tracks, levelling
  gear, and more.

**Deferred by SHANNON:** saving ("we'll do saving later"); the world ("all correct", not the
focus now).

## Checks

644 headless tests, including: each stat changes exactly one battle number; level times rise
every level and are 24 to 48 hours from 61 to 70; a 15 is exactly 1 in 90. Wave reach (draft):
a fresh starter team 13, the same team maxed 29, uncommons 17, with the Titan 36, maxed 63, a
maxed mythic team with the Titan 79. The weakest possible starting trio clears wave 4. A wave 1
fight lasts about 20 seconds.

## Why the heal changed

Healing a share of the target's HP made a tank with two healers behind it unbeatable (wave 5
stopped every starter team while waves 6 to 8 were easy). Healing from the healer's own size
removes that wall.

## Not decided yet

Training enhancements; gear; the login tracks; how much XP waves give; how wave fights are
shown in the arena.
