# Hundred Demon Night: read this first

Co-op wave-survival action game in a shrine courtyard: waves of yokai, an Oni General and the
Gashadokuro boss, picking blessings between waves. Status: v0.1 built, QA fixes verified (NIGHT-006),
custom Blender models swapped in (NIGHT-007, NIGHT-008); tasks in review.

- Project `night.project.json`; publish target `night-staging`.
- Long docs, open only the section you need: `docs/architecture/night.md` (§3 signatures, §4 server,
  §5 Fx, §6 client), `docs/game-design/game3-gdd.md`, decision `docs/decisions/0007-hundred-demon-night.md`,
  models: `docs/assets/night-blender-plan.md`, `tools/blender/night/README.md`.

## Files

| File | Owns |
|---|---|
| `NightServer.server.luau` | entry: 10 Hz tick, `Request` router (play, leaveRun, pickBlessing, meta actions), RunRules events, `NightStatus` |
| `State.luau` | `State.run` (RunRules.Run) and `State.positions` |
| `Combat.luau` | per-player fighter, `Combat` remote, hit tests, style, foxfire, Thunder Dash |
| `Enemies.luau` | enemy records and models, AI, telegraphs, bosses, `cleared()` |
| `Arena.luau` / `Gear.luau` | shrine courtyard, lighting, board / weapon Tool and mask |
| `Profiles.luau` / `Remotes.luau` | saves (copied from Relay) / `NightRemotes` (`Request`, `Combat`, `Fx`) |
| `../night-client/*` | Menu, Hud, CombatFx (input, prediction, every Fx), Movement, CameraFx |

Pure rules: `Rng`, `CombatRules`, `WaveRules`, `BossRules`, `BlessingRules`, `RunRules` (the run state
machine), `MetaRules`, `NightProgress`, `NightAssets` (generated from `tools/blender/night/uploaded.json`).
Specs: `Rng CombatRules WaveRules BossRules BlessingRules RunRules MetaRules NightProgress NightAssets`.

## Must stay true

- `RunRules.tick` and `RunRules.damage` decide the run; modules assign the value they return.
- `Combat` requests are validated and rate-limited on the server; clients skip their own predicted `swing`/`dash` Fx.
- `Hurt.key` makes each attack hit and each dodge count at most once per player.
- Stores `NightProfile<suffix>`, `NightWins<suffix>`; `PRODUCTION_UNIVERSE_ID` stays nil without SHANNON.
- `NightAssets.luau` is generated: change `uploaded.json` and run `tools/blender/night/write-assets-module.mjs`.

Fast check: `lune run tests/run Rng Combat Wave Boss Blessing RunRules MetaRules NightProgress NightAssets`.
