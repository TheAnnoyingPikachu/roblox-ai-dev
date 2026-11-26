# 0113: Animal Stations: analytics for the beta

Status: accepted (SHANNON, 2026-11-24: beta blocker 13, pick A). Task STATION-133.
Date: 2026-11-24.

## What

- `src/stations/Analytics.luau`, server only, every call guarded.
- Onboarding funnel, ten steps, each once a session: joined, bought an egg, started a hatch, first animal, has a
  team, started a wave, won a wave, cleared wave 3, beat the wave 10 boss, player level 5.
- Economy: every change to coins or samples (kit Saves' onChanged) is one `LogEconomyEvent`, Source or Sink, with
  the request or payout that made it as its item (`buy`, `upgrade`, `release`, `collect`, `wave_pay`, `run_pot`...).
- Custom events (three names): `WaveLost` (waves 1 to 3, the wave as a field), `Refused` (action and code),
  `SaveTrouble` (the save's status when not online).
- Amended 2026-11-26 (decision 0121, answer 36): `ModelFailed` (what failed to load and its asset id), after its
  three tries. Custom events need a player, so it is logged on the server's first player.
- Never logged: clicks (`strike`) and power presses, which would spend the place's rate limit (120 + 20 per
  player a minute).
- Model-load failures stay warnings: the Error Report shows them. Read it daily once the beta is published.
