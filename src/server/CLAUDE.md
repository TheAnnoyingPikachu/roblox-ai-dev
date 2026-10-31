# Bake Rush (pilot): read this first

Small bakery tycoon used to prove the pipeline: bake at the oven, sell at the counter, upgrade.
Status: PILOT-004 (saves) in review, waiting on the staging playtest. Its staging place showed only a
baseplate once (2026-10-24); the build stamp and post-publish check (SPIRE-002) exist to settle that.

- Project `default.project.json`; publish targets `staging` and `production` (production: v* tags, SHANNON approves).
- Long docs: `docs/game-design/bake-rush-gdd.md`, decisions 0004 (remotes, economy) and 0005 (saves).

## Files

| File | Owns |
|---|---|
| `Main.server.luau` | starts BakeService then SaveService |
| `services/BakeService.luau` | stations (ProximityPrompts), applies `BakeRules` to every request |
| `services/SaveService.luau` | DataStore saves with session lock and save count (decision 0005) |

Pure rules: `BakeRules`, `BakeConfig` (tuning, decision record to change), `SaveRules`, `RewardRules`.
Specs: `BakeRules SaveRules RewardRules`.

## Must stay true

- `PRODUCTION_UNIVERSE_ID` in SaveService stays nil until SHANNON approves a production release.
- A failed load kicks the player and never saves over existing data.

Fast check: `lune run tests/run BakeRules SaveRules RewardRules`.
