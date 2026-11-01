# Egg Garden: read this first

Cozy hatch-and-collect garden for up to 6 players (each owns a plot). Status: v0.1 built, QA fixes
verified (GARDEN-006); v0.2 (Celestial Egg, Splash Dash) built in GARDEN-009, Studio tests open.

- Project `garden.project.json`; publish target `garden-staging` (Max Players 6, set in place settings).
- Long docs, open only the section you need: `docs/architecture/garden.md` (§3 signatures, §4 server,
  §5 Fx, §6 client), `docs/game-design/game4-gdd.md`, decisions `docs/decisions/0008-egg-garden.md` and
  `docs/decisions/0012-egg-garden-v02.md`, `docs/decisions/0013-garden-admin-catalogue.md`.

## Files

| File | Owns |
|---|---|
| `GardenServer.server.luau` | entry: plot assignment, `Request` router, bed prompts, 5 Hz pad loop and 1 Hz status loop, `GardenStatus`, BindToClose |
| `Profiles.luau` | saves: session lock, coalesced UpdateAsync (7 s / 60 s / leave), offline mode, income board |
| `Remotes.luau` | `GardenRemotes` (`Request`, `Fx`), `GardenStatus`, `notice` |
| `State.luau` | `State.live[player]`: plot, pads, rate limit, gate timers |
| `Plots.luau` | 6 plot shells, `refresh(plot, profile)` rebuilds beds, pads, creatures |
| `World.luau` | Hatchling Valley, cart, boards, lighting |
| `Dash.luau` | Splash Dash: the one live `Round`, entrants, carrying out `DashRules` events, prizes, collision group |
| `DashWorld.luau` | Splash Island decks, start barrier, arches, ready pad and its prompt and label |
| `../garden-client/*` | Menu (panels), Hud, HatchFx (reveal), CreatureFx; display only |

Pure rules: `GardenConfig` (data and types), `WorldRules` (weather, stock), `GardenRules` (beds, pads,
pen, income), `HatchRules` (rolls, odds), `GardenProgress` (MetaRules config, sanitise, lock, login,
offline), `DashRules` (round, sample checks, obstacle poses). Specs: `GardenConfig GardenRules HatchRules
WorldRules GardenProgress MetaRules DashRules`.

## Must stay true

- Hatch outcomes are rolled once on the server and applied as fixed outcomes (re-applied on flush).
- Every write goes through `Profiles.apply` with a pure change; a failed load never writes.
- A Dash outcome comes only from `DashRules` on server samples; no remote carries a position, time or hit.
- A prize is applied in the step that accepts the finish, without yielding; `Dash.leave` grants nothing.
- Dash calls from gardening paths go through `guarded`: a Dash fault must not stop pads, teleports or saves.
- Router checks: loaded session and plot, string action, arg nil or string <= 32, shared 0.35 s limit.
- Stores `GardenProfile<suffix>`, `GardenIncome<suffix>`; `PRODUCTION_UNIVERSE_ID` stays nil without SHANNON.
- `Models.luau`/`Props.luau` are mapped in from `src/relay`; never add files with those names here.
- New economy values, remotes or schema fields need a decision record (0008, 0012, 0013).
- `adminGrant` is refused in the router unless `GardenConfig.ADMINS[player.UserId]`; hidden buttons are not the check.

Fast check: `lune run tests/run Garden Hatch WorldRules MetaRules` then
`rojo build garden.project.json -o build/garden.rbxl && node tools/check-place.mjs garden.project.json build/garden.rbxl`.
