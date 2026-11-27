# 0131: Animal Stations: live tuning

Status: accepted (SHANNON, 2026-11-27, Round 2 build 8 A: "A short list you can change live (reward growth, replay
pay, an egg price multiplier, events on and off), within ranges you approve once"). The keys and ranges are Claude's
draft, for SHANNON's approval. Task STATION-192. Date: 2026-11-27.

## What

Four ConfigService keys, set on the Creator Hub (the experience's Configs page) and live on running servers within
about 5 minutes of publishing. Anything outside a range is held at its edge; a missing key, a wrong type or an
unreachable ConfigService means the default.

| Key | What it does | Default | Range |
|---|---|---|---|
| `replayPct` | a replayed wave's pay, percent of its first clear | 40 | 25 to 60 |
| `coinBoost` | an event: wave coins times this | 1 | 1 to 3 |
| `eggPrice` | every egg's price times this | 1 | 0.5 to 2 |
| `hatchTime` | every hatch time times this (0.5 = twice as fast) | 1 | 0.25 to 1 |

- `Shared.LiveTuning` holds the list, the ranges and `apply`, which sets the shared rules (`LevelRules.REPLAY_PCT`,
  `LevelRules.COIN_BOOST`, each egg's `price`, `StationProgress.HATCH_MULT`). The server's `LiveConfig` reads
  ConfigService and sets ReplicatedStorage attributes `Live_<key>`; the HUD applies the same values, so the client's
  prices and timers agree with the server's.
- The server applies the defaults at once and the live values when ConfigService answers, so start never waits on it.
- `coinBoost` also lifts what the Windmill's share and the ranch animals' earnings are counted from (decision 0124).
- Reward growth is left out: changing it live would change every wave's pay and the egg prices built on it at once.

## To do on the Creator Hub (SHANNON)

Create the four keys with their defaults (numbers), then change one and publish when needed. Nothing has to exist
for the game to run.
