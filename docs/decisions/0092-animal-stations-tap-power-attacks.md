# 0092: Animal Stations: the player fires the power attacks

Status: accepted (SHANNON, 2026-11-19: "tap a button to use power attacks"); built by STATION-099.
Date: 2026-11-19. Task STATION-099.

## The rule

In a wave fight the player's team's power meters fill as before (POWER_GAIN + Mana per attack) but now hold
when full. The player taps the animal's plate (or presses 1 to 4) to fire it: a power attack is an extra
strike, at POWER x damage (and heal, for a Utility animal), on top of the animal's own attacks. A full meter
nobody taps fires itself `BattleRules.AUTO_FIRE` (4) seconds after it filled, so a fight nobody watches
still uses its power attacks. The enemies keep the old rule (a power attack replaces the attack that fills
the meter). `LevelRules.fight` without taps, and so every balance test, keeps the old rule for both sides.

## How (facts)

- `BattleRules.battle(one, two, log, taps)`: with `taps` (a list of { slot, t }) side 1 holds and fires as
  above. A tap at a time its meter is not full does nothing. A tap changes nothing before its own time, so
  the server replays the whole fight from the start with each new tap. Tests in
  `tests/BattleRules.spec.luau`.
- Remote contract: a new request `power` with one integer, the team slot (1 to 4). The server
  (`WaveShow.power`) places the tap `TAP_AHEAD` (the longest attack wind-up plus 0.3 s) after the show's
  current time, so every attack already playing is before it. It refuses (`power`) a tap that does not
  fire, comes after the fight's end, or would lose a fight the team was winning, and refuses (`no_fight`)
  when the player has no fight on.
- Pay: the server still decides the pay of a fight nobody taps in at once (`LevelRules.fight(team, level,
  {})`). If the taps turn a lost fight into a win, the clear is paid when the show reports its result. A tap
  never turns a won fight into a loss, so nothing paid is ever taken back.
- Display: `WaveShow` sets `Slot` and `Power` (0 to 1, the meter) on the team's models; `Hud.client` draws a
  plate per animal (health, power, a key number) bottom left during a fight.

## Balance (hypothesis, to check in play)

A power attack is now an extra strike, not a stronger version of a normal one, so a team that uses its
power attacks is a little stronger than before, and a team that never taps is a little weaker (its
strikes come up to 4 seconds late). Waves are tuned with the old rule; if fights now feel too easy, lower
`BattleRules.POWER` for tapped strikes or raise `POWER_COST`.

## Risk

A player who leaves before a tapped-into win reports keeps only what the fight decided at the start: the
late pay is a save write when the show ends, so a leave in between loses that upgrade, never anything
already paid.
