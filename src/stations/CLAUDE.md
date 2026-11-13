# Animal Stations (game 7): read this first

Egg animal collector: hatch animals with four stats, train them at stations, and send a team of three
through endless levels (0023). Vision (0021): ranch + silly microgames + turn-based battles. Status: rules (STATION-001/002),
the hub world (STATION-003), home ranches (STATION-004), matchups (STATION-005), training and levels (STATION-006), roles and team battles (STATION-007), saves, egg buying, team and training requests with a first HUD (STATION-008); no battle screen, animal models or ranch upgrades yet.

- Project `stations.project.json` (CI builds and place-checks it). No publish environment yet.
- Docs: decisions 0019 to 0026 (0026: stats are speed, strength, stamina, mana) (0025 also records the next direction: Titan fourth slot, tycoon ranch with samples); `docs/game-design/game7-gdd.md`; bestiary and art brief `docs/game-design/game7-animals.md`.

## Files

| File | Owns |
|---|---|
| `StationsServer.server.luau` | entry: builds the world, ranch assignment and spawn, kit Saves (`StationsProfile`), kit Router + `StationsRemotes` (profile, buy, team, train, stop), stall prompts |
| `../stations-client/Hud.client.luau` | coins, toasts, Animals panel; display only |
| `World.luau` | the world: plaza, Hatchery fountain, egg market, roads, the four stations, three ranches, scenery, lighting, spawn |

Pure rules: `StationConfig` (stats, species, variants, eggs, stations, matchups), `StationRules` (hatch, train, matchups) `LevelRules` (enemy teams, rewards) and `BattleRules` (roles, team battle for levels and PvP). `StationProgress` (saved profile and every change to it). Specs: `StationRules`, `LevelRules`, `BattleRules`, `StationProgress`.

## Must stay true

- The server decides prices, hatches and times; profile changes are pure `StationProgress` functions that capture their inputs (SaveStore runs them twice).
- World is display only. Work slots are tagged `StationSlot` with `Station` and `Index` attributes for the server to use.
- Terrain fill tops at y = -2 so the surface lands at y = 0 (voxels snap up); flat parts sit on y = 0.
- The SpawnLocation is placed in code (`World.SPAWN`); Rojo ignores `Position` in the project file.
- Max Players must be 3 (= `World.RANCHES`). A place file cannot carry it: set it in Game Settings when publishing.
- Ranch spots are tagged `RanchSpot` (`Ranch`, `Index`) and nests `RanchNest` (`Ranch`); a ranch's `Owner` attribute is the UserId or 0.
- One ranch ends each of the north, east and west roads (`RANCH_ANGLE`); scenery keeps clear of `ROADS` and ranch squares.
- Station layout: track NW, gym NE, pool SW, library SE at `World.STATION_DIST`; local -Z faces the plaza.
