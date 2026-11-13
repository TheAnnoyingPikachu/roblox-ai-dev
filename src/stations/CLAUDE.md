# Animal Stations (game 7): read this first

Egg animal collector: animals have four stats and earn the most at the station matching their best
stat. Status: rules (STATION-001/002) and the hub world (STATION-003) only; no saves, remotes or client yet.

- Project `stations.project.json` (CI builds and place-checks it). No publish environment yet.
- Docs: decisions 0019, 0020; `docs/game-design/game7-gdd.md`; bestiary and art brief `docs/game-design/game7-animals.md`.

## Files

| File | Owns |
|---|---|
| `StationsServer.server.luau` | entry: builds the hub |
| `World.luau` | the hub: plaza, Hatchery fountain, egg market, paths, the four stations, scenery, lighting, spawn |

Pure rules: `StationConfig` (stats, species, variants, eggs, stations) and `StationRules` (hatch, rate). Spec: `StationRules`.

## Must stay true

- World is display only. Work slots are tagged `StationSlot` with `Station` and `Index` attributes for the server to use.
- Terrain fill tops at y = -2 so the surface lands at y = 0 (voxels snap up); flat parts sit on y = 0.
- The SpawnLocation is placed in code (`World.SPAWN`); Rojo ignores `Position` in the project file.
- Station layout: track NW, gym NE, pool SW, library SE at `World.STATION_DIST`; local -Z faces the plaza.
