# 0048: Animal Stations: fight presentation, slice 1 (impact, shots, skip)

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0043 (real fights) and 0045 (fight camera). Task STATION-031.

## Decision

SHANNON wants the fights more entertaining to watch. The pass has three slices; this is slice 1.
It is display only: `BattleRules` and `LevelRules` are untouched, a result and a payout are
settled before the replay starts, and nothing below can delay or change them.

- **Impact.** `WaveShow` sets `HitPower`, `HitDmg` and then `HitAt` (server time) on the struck
  model, and `StopAt` / `StopFor` on a melee attacker. `Creatures.client` reacts on each client: a burst
  of sparks (one emitter per model, `Emit`, no lights), a shock disc facing the camera (one short-lived
  neon part), a flinch stretched by `FightFx.flinch` (power and share of max HP), and a hit-stop: that
  model's clip waits 0.06 s (0.1 s for a power hit) while the server clock runs on. `ArenaCamera` pulls
  the FOV in by up to 4 degrees, fading in 0.6 s (`CamPunch` and `CamPunchAt` are set locally on the
  watching player and never replicate). Attributes arrive in any order, so every read is tolerant.
- **Shots.** An archer's arrow and a mage's bolt fly from the shooter's `Hit` box to the target's, made
  by `WaveShow` in the player's show folder (so `clear` removes them) and tweened to land exactly at the
  log's `t`. A shot starts its clip `RELEASE + flight` early (`FightFx.lead`) so the release is in the
  clip. The rules still have no range. A power attack never fires one (it is the ground slam).
- **Skip.** The in-fight button already called `wave_done`; it now reads "Skip the fight" while the
  fight runs and "Leave the arena" once the result shows. Leaving still reports the result at once and
  `readyAt` still holds the next fight, so skipping is no faster to farm.
- The pure numbers (lead, flight time, hit-stop, flinch, punch curve) are in `src/shared/FightFx.luau`
  with `tests/FightFx.spec.luau`.

## Not done yet (slices 2 and 3)

Per-species attacks, a win pose, a slow-motion beat on the killing blow and a power-attack cut-in.
The power attack's charge glow and landing slam already existed and are unchanged.

## Checked

Lune 683/683. In Studio (admin test waves 3 and 6, starters): no script errors; the mage's bolt and the
archer's arrow fly; the FOV punches (55 to 51); sparks and discs appear and are gone after the fight
(0 stray parts); wave 6 still ends "won in 32s (65 attacks)". Not measured: frame time against a
before number, phones, wave 10's big models.
