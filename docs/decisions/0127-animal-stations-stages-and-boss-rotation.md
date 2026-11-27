# 0127: Animal Stations: a name for every stage, and the boss rotation

Status: accepted (SHANNON, 2026-11-27, Round 2 build 1: "do boss tints and larger dragons as well with like cool
UI made in forge", then "do everything you can without credits for now"). The names, the order and the sizes are
Claude's. The boss intro and health bar made in ForgeGUI wait for credits. Task STATION-187. Date: 2026-11-27.

## Context

- Fact: stages 6 to 30 (waves 51 to 300) were all "The Ancient", and every boss wave from 60 to 300 was the Ancient
  Alpha Dragon, 25 times.

## What

- `LevelRules.STAGE_NAMES` names all 30 stages (The Vanguard to The Ancient); one past the list is still The Ancient.
- From wave 70 (`ROTATE_FROM`) each boss wave takes the next of `ROTATION`: Ancient Alpha Dragon, Siege Golem,
  Shadow Dragon, Cavalry Commander, Dark Drake, Ogre Commander, Shieldbearer Commander, Necromancer, and round
  again. Waves 10 to 60 keep their dragons.
- A foe of the line made a boss fights at `BOSS_MULT` (3) times its stats, in the classic wave and the swarm; the
  swarm is still matched to the wave's power as a whole.
- A wave's boss carries `boss = true` (`LevelRules.enemies`): it lands on the summoning circle, gets the HUD's boss
  bar and a red outline, and stands bigger (`Creatures.spawnFoe`): a dragon 1.3 times, a foe of the line 1.8 times
  and tinted crimson (`BOSS_TINT`).
- Fact (simulation, 2026-11-27, today's main): no run of the best team at level 70 cleared wave 300 (best 299;
  mid team 59, top variants 229 to 289).

## Not changed

The boss chests, the dragons' stats and thresholds, the swarm's crowds.
