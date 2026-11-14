# 0048: Animal Stations: fight presentation (slice 1: impact, shots, skip; slice 2: species, win pose)

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

## Slice 2: per-species attacks, a win pose, a harder defeat

- **Attacks.** `Creatures.client` picks the attack clip from the model's species (read from its `Asset`,
  so a variant uses its species' clip): jackal lunge and snap with a head shake, cheetah double paw swipe,
  tortoise shell slam, meerkat stand-and-jab, flamingo neck whip, lion pounce, elephant stomp and slam,
  rhino keeps the horn charge (also the fallback). Every clip is 0.95 s with contact near 0.44 s, so the
  server's `LENGTH` and lead are unchanged. The power attack keeps the shared rear-and-slam, except the
  tortoise, cheetah and flamingo, which have their own wind-ups (the slam stays at `MAGIC_IMPACT`).
- **Win pose.** A beat after the last hit (`seconds + 0.6` after the replay starts) `WaveShow` sets
  `Anim = "win"` on the winning side's survivors; it holds until the show is cleared. Animals rear and
  pump their front paws; the Hexbound throw both arms up; a dragon beats its wings harder.
- **Defeat.** A four-legged fall is now thrown back first (a knock-up key at 0.2 s) before the roll.
- Nothing about a result changed: the pose is set after the log has played out.

## Not done yet (slice 3)

A slow-motion beat on the killing blow and a power-attack cut-in.
The power attack's charge glow and landing slam already existed and are unchanged.

## Checked

Lune 683/683. In Studio (admin test waves 3 and 6, starters): no script errors; the mage's bolt and the
archer's arrow fly; the FOV punches (55 to 51); sparks and discs appear and are gone after the fight
(0 stray parts); wave 6 still ends "won in 32s (65 attacks)". Not measured: frame time against a
before number, phones, wave 10's big models.

Slice 2 checked in Studio: all eight species' contact poses and win pose posed side by side in the air;
the three custom power wind-ups ran without errors; a wave 2 fight with the starters showed the win pose
on all three survivors. Not tuned in motion by eye beyond stills.
