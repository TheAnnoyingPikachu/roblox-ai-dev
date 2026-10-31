# Relay Rounds: read this first

Team relay race on one shared circuit: each team member runs one leg, hands off the baton at their
team's box, and dodges hazards. Status: v0.1 built; RELAY-001 to RELAY-005 in review.

- Project `relay.project.json`; publish target `relay-staging`.
- Long docs: `docs/game-design/relay-rounds-gdd.md`, decision `docs/decisions/0006-relay-rounds-profiles-economy.md`.

## Files

| File | Owns |
|---|---|
| `RelayServer.server.luau` | rounds, legs, handoffs, hazards, wins; reads positions only, nothing a client sends affects a race |
| `Profiles.luau` | saves and the profile `Request` remote (the only client request) |
| `Course.luau` / `Scenery.luau` | the circuit and handoff boxes / lighting, terrain, trees |
| `Models.luau` | mesh IDs, **shared**: Night, Garden and Spire require it in place; add entries only |
| `Props.luau` | part-built props, **shared** the same way; keep existing builders unchanged |
| `../relay-client/*` | Menu, Movement (client-simulated, cosmetic style meter), CameraFx, StatusBar |

Pure rules: `RelayRules` (rounds and legs), `StyleRules` (cosmetic meter), `ProgressRules` (Relay's
config for `MetaRules`). Specs: `RelayRules StyleRules ProgressRules MetaRules`.

## Must stay true

- Every file here except new `Models.luau` entries stays byte-identical for the other games' sake.
- A new mesh needs a `docs/assets/register.md` row first; `Models.spawn` returns nil on failure and callers keep a part fallback.

Fast check: `lune run tests/run RelayRules StyleRules ProgressRules MetaRules`.
