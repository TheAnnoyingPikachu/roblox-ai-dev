# Animal Stations (game 7): read this first

Egg animal collector: animals have four stats and earn the most at the station matching their best
stat. Vision (0021): ranch + silly microgames + turn-based battles. Status: rules (STATION-001/002),
the hub world (STATION-003) and home ranches (STATION-004) only; no saves, remotes or client yet.

- Project `stations.project.json` (CI builds and place-checks it). No publish environment yet.
- Docs: decisions 0019, 0020, 0021; `docs/game-design/game7-gdd.md`; bestiary and art brief `docs/game-design/game7-animals.md`.

## Files

| File | Owns |
|---|---|
| `StationsServer.server.luau` | entry: builds the world, gives each player a ranch (lowest free of 6), spawns owners at their gate |
| `World.luau` | the world: plaza, Hatchery fountain, egg market, roads, the four stations, six ranches, scenery, lighting, spawn |

Pure rules: `StationConfig` (stats, species, variants, eggs, stations) and `StationRules` (hatch, rate). Spec: `StationRules`.

## Must stay true

- World is display only. Work slots are tagged `StationSlot` with `Station` and `Index` attributes for the server to use.
- Terrain fill tops at y = -2 so the surface lands at y = 0 (voxels snap up); flat parts sit on y = 0.
- The SpawnLocation is placed in code (`World.SPAWN`); Rojo ignores `Position` in the project file.
- Max Players must be 6 (= `World.RANCHES`). A place file cannot carry it: set it in Game Settings when publishing.
- Ranch spots are tagged `RanchSpot` (`Ranch`, `Index`) and nests `RanchNest` (`Ranch`); a ranch's `Owner` attribute is the UserId or 0.
- Ranches pair up on the north, east and west roads (`RANCH_ANGLE`); scenery keeps clear of `ROADS` and ranch squares.
- Station layout: track NW, gym NE, pool SW, library SE at `World.STATION_DIST`; local -Z faces the plaza.
