# 0048: Animal Stations: fight presentation (impact and shots, species attacks and win pose, rhythm)

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
  server's `LENGTH` and lead are unchanged. Every base animal has its own power attack (jackal howl and
  drive, tortoise shell crash, meerkat overhead smash, cheetah coil and bound, flamingo neck spear, lion
  crouch and long pounce, rhino back-up and charge, elephant trumpet and stomp); the slam stays at
  `MAGIC_IMPACT` and the ground eruption is still the shared effect. A clip is looked up by the model's
  asset first, then its species, then the shared one, so a variant can later add `creature_lion_sun` to
  `MAGICS` (or `ATTACKS`) and win over its species'.
- **The flamingo keeps both feet on the ground** (SHANNON's note): its attacks, power attack and win pose
  have no leg motion, its flinch is stripped of leg joints (`PLANTED`), and its win is a neck sway.
- **Win pose.** A beat after the last hit (`seconds + 1.0` after the replay starts, once the killing blow's slow motion has played) `WaveShow` sets
  `Anim = "win"` on the winning side's survivors; it holds until the show is cleared. Animals rear and
  pump their front paws; the Hexbound throw both arms up; a dragon beats its wings harder.
- **Defeat.** A four-legged fall is now thrown back first (a knock-up key at 0.2 s) before the roll.
- Nothing about a result changed: the pose is set after the log has played out.

## Slice 3: fight rhythm

- **Killing blow.** `WaveShow` marks the last hit of the log (when it kills) with `HitFinal = 1`.
  On each client it holds 0.2 s (`FightFx.hitStop`), bursts bigger, and slows every clip to 0.3 speed for
  0.8 s, easing back to full speed by 1.5 s (`FightFx.slow`). This is display only: a clip reads a later
  time than the server's clock (`rig.held`), the server's timing and the report never slow. The target's
  fall plays slowly; the winners cheer 1.0 s after the fight's end.
- **Camera cut-in.** A power hit or the killing blow cuts the camera 62% of the way towards its
  target and back out over 1.3 s (`FightFx.cut`, `ArenaCamera`); other cuts wait 4 s between each
  (`FightFx.canCut`), the killing blow always cuts. A boss is covered by this: its power attacks and the
  killing blow cut in; there is no separate boss rule.
- **Skip button:** slice 1.

## Checked

Lune 683/683. In Studio (admin test waves 3 and 6, starters): no script errors; the mage's bolt and the
archer's arrow fly; the FOV punches (55 to 51); sparks and discs appear and are gone after the fight
(0 stray parts); wave 6 still ends "won in 32s (65 attacks)". Not measured: frame time against a
before number, phones, wave 10's big models.

Slice 2 checked in Studio: all eight species' contact poses and win pose posed side by side in the air;
the three custom power wind-ups ran without errors; a wave 2 fight with the starters showed the win pose
on all three survivors. Not tuned in motion by eye beyond stills.

Slice 3 and the power attacks checked in Studio (starters, wave 6): the camera cut in four times 4 s or more apart and on the killing blow (closest 10 studs from the fight's middle, a still showed a close shot of two fighters); the killing blow landed at 32.2 s, the win pose 1.05 s later; the flamingo's leg joints measured 0.0 degrees in attack, power, hit and win. Not seen by eye: the eight power attacks in motion at the slam (my showcase retriggers the ground effect), the slow motion at full speed, a dragon's killing blow.
