# Egg Garden: read this first

Cozy hatch-and-collect garden for up to 6 players (each owns a plot). Status: v0.1 built, QA fixes
verified (GARDEN-006); v0.2 (Celestial Egg, Splash Dash) built in GARDEN-009, Studio tests open; v0.5
server (spawn, valley, login tracks; decision 0017) built in GARDEN-052.

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
| `World.luau` | Hatchling Valley, cart, boards, lighting; v0.5 spawn, large sakura, hill bands, pond, lanterns (GDD X2) |
| `Dash.luau` | Splash Dash: the one live `Round`, entrants, carrying out `DashRules` events, prizes, collision group |
| `DashWorld.luau` | Splash Island decks, start barrier, arches, ready pad and its prompt and label |
| `Wheel.luau` | Petal Catch: one round per player, catches from the 5 Hz root samples, the roll and the prize (`docs/architecture/garden-wheel.md`) |
| `WheelWorld.luau` | the Petal Patch, blossom tree, wheel stand with the Play prompt and the empty `SpinsLabel` |
| `Trades.luau` | v0.4 safe trading: live pairs, `GardenTrades<suffix>` ledger, commit, undo and heal; `Trades.deps` is the test seam GardenServer fills |
| `../garden-client/*` | Menu (panels), Hud, HatchFx (reveal), CreatureFx; display only |

Pure rules: `GardenConfig` (data and types), `WorldRules` (weather, stock), `GardenRules` (beds, pads,
pen, income), `HatchRules` (rolls, odds), `GardenProgress` (MetaRules config, sanitise, lock, login,
offline), `DashRules` (round, sample checks, obstacle poses), `WheelRules` (petal schedule, catches, tiers, roll,
award), `TradeRules` (trade state machine, `give`, `undo`, `heal`). Specs: `GardenConfig GardenRules HatchRules
WorldRules GardenProgress MetaRules DashRules WheelRules TradeRules`.

## Must stay true

- Hatch outcomes are rolled once on the server and applied as fixed outcomes (re-applied on flush).
- Every write goes through `Profiles.apply` with a pure change; a failed load never writes.
- A Dash outcome comes only from `DashRules` on server samples; no remote carries a position, time or hit.
- A prize is applied in the step that accepts the finish, without yielding; `Dash.leave` grants nothing.
- Dash calls from gardening paths go through `guarded`: a Dash fault must not stop pads, teleports or saves.
- A wheel outcome comes only from `WheelRules` on server samples; `Wheel.leave` grants nothing; a spin is one
  `Profiles.apply` with `WheelRules.award`. Wheel calls go through `guarded` like Dash.
- Router checks: loaded session and plot, string action, arg nil or string <= 32, shared 0.35 s limit.
- v0.5 spawn (garden.md 4.7): every character spawns on `Workspace.Garden.Spawn` on the plaza; nobody is moved
  at join. Only `play` (refused while racing) and `home` move a character to `Plots.gate`; `CharacterAdded`
  only re-places a racer (`Dash.place`).
- Login tracks: `GardenProgress.login` ticks them at load; `slowTick` calls `Profiles.loginTick` for a profile whose
  `weekLast` or `monthLast` is before today (UTC rollover while online). At a rollover the tick pays the earned,
  unclaimed slots first (0017 amendment: nothing earned is lost) and its text goes to `LastReward`.
  `claimLogin week|month` is the only login claim (the slot is pinned in `Profiles.request`); `claimDaily` and
  `claimWeekly` are unknown actions (decision 0017).
- Stores `GardenProfile<suffix>`, `GardenIncome<suffix>`; `PRODUCTION_UNIVERSE_ID` stays nil without SHANNON.
- `Models.luau`/`Props.luau` are mapped in from `src/relay`; never add files with those names here.
- New economy values, remotes or schema fields need a decision record (0008, 0012, 0013).
- `adminGrant` is refused in the router unless `GardenConfig.ADMINS[player.UserId]`; hidden buttons are not the check.
- A trade commits in this order only: both `GardenTrades` ledger keys, `TradeRules.canCommit` again, then the two
  `Profiles.apply(…, "trade", give)` with no yield between them; undo marks both ledgers before its two applies;
  `Trades.heal` runs in `Profiles.load` after login and resolves every counterpart lookup before its one apply.
- `name` is the only request that yields (TextService filter) and it never yields inside `Profiles.apply`; a
  filter error writes nothing. Pet names never go into `announce`, the board or a notice to another player.
- `release`, `store`, `place`, `favourite` and `name` are refused on a creature picked in a live trade (`Trades.locked`).
- Trades calls from gardening paths go through `guarded`, like Dash.

Fast check: `lune run tests/run Garden Hatch WorldRules MetaRules` then
`rojo build garden.project.json -o build/garden.rbxl && node tools/check-place.mjs garden.project.json build/garden.rbxl`.
