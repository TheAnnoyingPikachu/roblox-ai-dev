# Studio architecture on one page

Read this before any long design doc. Each game has its own short `CLAUDE.md` next to its server
code; open the long docs only at the sections a task's `inputs` name.

## Games and where they live

| Game | Project file | Server | Client | Pure rules (`src/shared`) | Short context |
|---|---|---|---|---|---|
| Bake Rush (pilot) | `default.project.json` | `src/server` | `src/client` | `BakeRules`, `BakeConfig`, `SaveRules`, `RewardRules` | `src/server/CLAUDE.md` |
| Relay Rounds | `relay.project.json` | `src/relay` | `src/relay-client` | `RelayRules`, `StyleRules`, `ProgressRules` | `src/relay/CLAUDE.md` |
| Hundred Demon Night | `night.project.json` | `src/night` | `src/night-client` | `Rng`, `CombatRules`, `WaveRules`, `BossRules`, `BlessingRules`, `RunRules`, `NightProgress`, `NightAssets` | `src/night/CLAUDE.md` |
| Egg Garden | `garden.project.json` | `src/garden` | `src/garden-client` | `GardenConfig`, `WorldRules`, `GardenRules`, `HatchRules`, `GardenProgress` | `src/garden/CLAUDE.md` |
| Neon Spire (planned) | `spire.project.json` (SPIRE-003) | `src/spire` | `src/spire-client` | planned in `docs/architecture/spire.md` §3 | add `src/spire/CLAUDE.md` with the first code |

Shared by every game: `MetaRules` (XP, levels, coins, daily/weekly rewards, quests, cosmetics),
`src/relay/Models.luau` (mesh IDs, required in place) and `src/relay/Props.luau` (part builders).

## Every place has the same skeleton

```
ReplicatedStorage.Shared      src/shared       pure game rules (Lune-tested, no Roblox API)
ReplicatedStorage.Kit         src/kit          pure building blocks (Lune-tested): saves, router, limits, format, stamp
ReplicatedStorage.KitRoblox   src/kit-roblox/modules   Roblox adapters for the kit: Saves, Remotes, Ui
ReplicatedStorage.BuildInfo   build-info/BuildInfo.txt  build stamp, "dev" locally, commit sha from CI
ServerScriptService.<Game>    src/<game>       server: the only place outcomes are decided
ServerScriptService.BuildStamp            prints "[Build] <sha>" at server start
StarterPlayerScripts.<Game>Client  src/<game>-client   UI, input, effects; asks, never decides
StarterPlayerScripts.BuildStamp           corner label "build <sha>"
```

## How a request flows

```
client  Request:InvokeServer(action, ...args)
server  Router: loading? -> rate limit -> known action? -> Payload validators -> handler
handler pure rule decides on the in-memory profile -> SaveStore.apply(change) -> attributes for the UI
saves   SaveStore: session lock, coalesced UpdateAsync (<= 1 write / 7 s, 60 s autosave, final write on leave)
```

Games 1 to 4 implement this flow by hand (`Profiles.luau`, `Remotes.luau` per game). New games use
the kit instead of copying those files (decision 0011). Existing games are not migrated: their
code passed QA and playtests, and a migration would need new ones.

## What is tested where

| Layer | Tested by | Command |
|---|---|---|
| Game rules, economy, sanitise/lock rules | Lune specs per module | `lune run tests/run <Module>` |
| Saves, remote validation, rate limits (kit) | `SaveStore.spec`, `Kit.spec` with `tests/fakes/DataStore.luau` | `lune run tests/run SaveStore Kit` |
| Rule 5 (pure modules really are pure) | `Purity.spec` | `lune run tests/run Purity` |
| Built place contains every mapped node, its scripts and the stamp | `tools/check-place.mjs` (CI and before upload) | `node tools/check-place.mjs garden.project.json build/garden.rbxl` |
| Published version is the build that was uploaded | `tools/verify-publish.mjs` (publish.yml, Open Cloud Luau execution) | publish run |
| A PR stays inside its tasks' files | `tools/check-scope.mjs` (CI) | `node tools/check-scope.mjs origin/main` |
| Game-side Roblox code (worlds, effects, feel) | Studio playtests with notes that record the build stamp | gate 4 |

## Release path

PR → CI (gate 1) → `v*` tag → publish.yml to `<game>-staging`: stamp, build, check the file,
upload, verify the published version, restart servers or tick the checklist → SHANNON playtests on
staging (gate 4) → production publish with SHANNON's approval (gate 5). Details: `studio/gates.md`.
