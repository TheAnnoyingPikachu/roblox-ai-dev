# Animal Stations (game 7): read this first

Egg animal collector, at framework stage: hatch animals, level their six stats at your ranch, and
send a team of three plus a Titan through endless waves. The ranch is the player's base (a tycoon
later); the hub is for vendors. Keep things simple: placeholders, draft numbers.

- Project `stations.project.json` (CI builds and place-checks it). No publish environment yet.
- Docs: `docs/game-design/game7-gdd.md` (the current summary), `docs/game-design/game7-animals.md`
  (roster and looks), decisions 0019 to 0032 (0029 to 0032 are the latest and replace parts of the rest).
- Not built: wave battles in the arena (so coins cannot be earned in play), animal models, the ranch tycoon.

## Files

| File | Owns |
|---|---|
| `StationsServer.server.luau` | entry: builds the world, ranch assignment and spawn, teleport prompts, kit Saves (`StationsProfile`), kit Router + `StationsRemotes` (profile, buy, team, train, stop), stall prompts |
| `../stations-client/Hud.client.luau` | coins and player level, toasts, Animals panel (team button, one train button per stat); display only |
| `World.luau` | the hub (plaza, Hatchery fountain, egg stalls, south walk, teleport pad, north road, scenery), the wave arena canyon, three ranch islands (barn, paddock, nest, training pads, teleport pad), the mountains and invisible walls round every area, lighting, spawn |

Pure rules in `src/shared`: `StationConfig` (stats, stat levels, roles, groups, species, variants,
eggs, stations), `StationRules` (hatch, stat levels, roles), `BattleRules` (wave fights on a clock),
`LevelRules` (waves, rewards), `StationProgress` (saved profile and every change to it). Each has a spec.

## Must stay true

- The server decides prices, hatches and times; profile changes are pure `StationProgress` functions that capture their inputs (SaveStore runs them twice).
- "Level" has three meanings: wave (`LevelRules`, `Profile.best`), stat level (0 to `MAX_LEVEL`, `Owned.trained`) and player level (`StationProgress.playerLevel`, from `Profile.xp`).
- `BattleRules` is for wave fights only. Fights between players will work differently and stats will not affect them: build nothing with PvP in mind.
- Each stat has exactly one job in a wave fight (Speed swing, Stamina rest, Strength damage, Mana energy per attack, Health HP, Defence damage cut); the spec checks it. A stat's value is the species number grown by its level, so species still matter.
- Training runs in real time, also while the player is away, with no cap; level times come from `StationRules.levelSeconds` (whole seconds).
- A role and a group come from the species, never from stats. The Titan is never in `Profile.team`; it uses `Profile.titan`.
- `sanitize` repairs an animal's missing stats from its species; it only drops unknown species and duplicate ids. Keep it that way when stats change.
- World is display only. Tags for the server: `TrainPad` (`Ranch`, `Station`), `RanchSpot` (`Ranch`, `Index`), `RanchNest` (`Ranch`), `Teleport` prompts (`To` = "hub" or "ranch"), `WaveStand` and `WaveSpawn` in the arena. A ranch's `Owner` attribute is the UserId or 0.
- Ranches are detached islands (`World.RANCH_DIST`), reached only by teleport. Terrain lands on 4-stud steps: the island cylinder tops at 18 so the surface is `World.RANCH_Y` = 22 (measured); the hub block tops at -2 for a surface at 0.
- Every area is closed: mountains (rock domes) with an invisible `Barrier` wall in front. The hub's wall is at `World.HUB_RADIUS` and opens only into the arena canyon; keep new hub content inside it.
- A hatched animal's `stats` are exactly its version's numbers; what varies is `trained`, the stat levels (base 1 to `BASE_MAX` on hatch, jackpot `MAX_LEVEL`).
- The SpawnLocation is placed in code (`World.SPAWN`, the hub fallback); Rojo ignores `Position` in the project file. Owners are moved to their ranch after spawning.
- Max Players must be 3 (= `World.RANCHES`). A place file cannot carry it: set it in Game Settings when publishing.
