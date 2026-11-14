# 0043: Animal Stations: real wave fights, and a dark glow for the Hexbound

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0032, 0040 and 0042.

## Decision

From SHANNON: "lets make real wave fights and finish the gameplay loop like you said", and, while it
was being built, "get rid of the green circle aura and just give them a dark glow".

- **The loop is closed.** Hatch, train, put animals on the team, walk up the north road to the
  **wave gate** (a red crystal on a pillar at the arena's entrance), choose a wave, fight it, and
  the clear pays coins, XP and samples that buy the next ranch upgrades.
- **The gate list.** Any wave up to one past the best cleared (a cleared one can be replayed). It
  shows the wave's enemies, what clearing it pays, and who is on the team. The team is the player's
  own team (three animals and a Titan); there is nothing to choose in the arena.
- **The server decides, pays at once and then shows it.** `StationProgress.canFight` checks the wave
  and the team, `LevelRules.fight` decides it (`BattleRules`, deterministic), and a win is paid
  straight away with `StationProgress.clear`. The arena then replays the same fight from its log
  (`WaveShow`, decision 0042), with health bars and damage numbers, and a result panel gives the
  coins, XP and samples, "Fight the next wave" or "Try again", and "Leave the arena". A player who
  leaves or disconnects mid-replay keeps what the fight paid; a loss pays nothing and costs nothing.
- **Pay.** Coins as before (40 for wave 1, 8% more a wave, a quarter for a replay). XP is
  10 + 4 per wave. Samples start at wave 5: one per 5 waves, double on a boss wave (every 10th),
  a quarter for a replay. Wave 10 drops 4, wave 40 drops 16; the samples the ranch upgrades need
  (about 475 in all) arrive over the first 60 or so waves.
- **One fight at a time in the arena.** A second player is told it is busy. A player may not start
  another fight until the last one's own fight time (and the walk-in) has passed, even if they
  leave early, so skipping the replay does not make farming faster.
- **A dark glow instead of the green pool.** The green ground disc, the green sparks and the green
  light are gone. Each Hexbound has thick black-violet smoke rising off it and one faint deep-violet
  light, built into the model as before (one light, about 25 live particles; the cost in 0042 holds).

## Why

- The game could not be played for a reason: nothing earned coins, XP or samples.
- Paying at the start keeps a disconnect from costing a player a won fight and lets the server stay
  simple; the wait before the next fight keeps the pay tied to real time.

## Costs and limits

- The coin counter jumps when the fight begins, before the replay shows the win.
- The same fight is decided twice (once to pay, once for the replay's log) from the same team; they
  agree because the rules are deterministic.
- One fight at a time in the arena, no waiting line; no prediction of the result; no co-op.
- Drop numbers and the 4-second walk-in wait are first guesses.
- Archers and mages still stand and "shoot" with no visible projectile.
- The test funds button is still in the ranch menu in Studio, and the admin test waves are still there.
