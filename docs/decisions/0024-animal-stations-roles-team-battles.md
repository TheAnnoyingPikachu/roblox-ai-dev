# 0024: Animal Stations roles and team battles (waves and PvP)

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Builds on 0022 (matchups) and 0023 (training, endless levels); replaces the
front-against-front battle of 0023.

## Vision (from SHANNON)

Three modes on one battle system: **endless wave grinding** (the levels), **rock paper scissors
PvP**, and **training animals**. The four types are four roles: attack, utility, defense, tank.

## Decision

| Type | Role | Animals | In battle (`BattleRules`) |
|---|---|---|---|
| Speed | Attack | Bunny, Fox, Horse, Cheetah | damage × 1.3 |
| Strength | Tank | Pig, Goat, Bear, Gorilla | HP × 1.5; enemies must hit it while it stands |
| Swim | Defense | Duck, Frog, Otter, Dolphin | while it stands its team takes damage × 0.8 (no stacking) |
| Smarts | Utility | Mouse, Raccoon, Parrot, Owl | after attacking, heals the most hurt teammate by half its attack |

- The 0022 loop reads as roles: Attack beats Utility (kills the healer), Utility beats Tank
  (wears it down), Tank beats Defense (outlasts it), Defense beats Attack (blocks it).
- **Team battle:** each round every standing animal acts once, fastest first (speed ties go to
  side 1, then slot order). Deterministic, so the server can replay any result.
- Levels call `BattleRules.battle(team, LevelRules.enemies(level))`. PvP will call the same
  function with two players' teams; the server picks side 1 (it wins speed ties).
- Tests show a Tank + Attack + Defense team beats three of any one role with equal stats, and
  three Attackers beat Tank + Attack + Utility, so no team shape wins everything.

## Level reach with roles (draft)

Starters 4, fully trained starters 16, Safari rares 19, legendary team 39, fully trained mythic team 59.

## Not decided yet

PvP matchmaking, rewards and ranking; whether battles are watched or played move by move;
role abilities beyond these passives.
