# Lantern Express: architecture (v0.1)

Owner: A06 (Designer and Architect thread, LANTERN-001). Inputs: `docs/game-design/game6-gdd.md` (the GDD; section letters below refer to it) and `docs/decisions/0018-lantern-express.md` (place structure, seated rule, remotes, save schema v1, economy). If this file and the GDD disagree on a rule, the GDD wins and this file is fixed; the resolutions in section 11 settle what the GDD leaves open. Task ids are in `docs/production/game6-plan.md`.

## 1. Place, files and who owns them

Rojo project `lantern.project.json` (section 10):

| Instance | Source |
|---|---|
| `ReplicatedStorage.Shared` | `src/shared` (pure modules, shared with the other games) |
| `ReplicatedStorage.Kit`, `.KitRoblox`, `.BuildInfo` | `src/kit`, `src/kit-roblox/modules`, `build-info/BuildInfo.txt` |
| `ServerScriptService.Lantern` | `src/lantern` |
| `ServerScriptService.Lantern.Models`, `.Props` | `src/relay/Models.luau`, `src/relay/Props.luau`, **required in place** (as Garden) |
| `StarterPlayer.StarterPlayerScripts.LanternClient` | `src/lantern-client` |
| `Workspace.SpawnLocation` | at the hub platform (0, 0.6, 30); the server places characters on PLAY |

`src/lantern` and `src/lantern-client` hold a `.gitkeep` until their first script lands (LANTERN-002). Never add a `Models.luau` or `Props.luau` to `src/lantern`.

### Reused files

| File | Lantern | Notes |
|---|---|---|
| `src/kit/*` | required | `SaveStore` (through `Saves.start`), `Router`, `Payload`, `RateLimit`, `Format`; LANTERN-005 adds the `newer` option to `SaveStore` |
| `src/kit-roblox/modules/Saves.luau`, `Remotes.luau` | required | unchanged |
| `src/kit-roblox/modules/UiKit.luau` | **new** (LANTERN-005), generalised from `src/garden-client/UiKit.luau` | section 7; Garden keeps its own file until a Garden release moves it |
| `src/shared/MetaRules.luau` | required, unchanged | levels, quests, cosmetics with a Lantern config |
| `src/shared/LoginRules.luau` | required for `monthOf` and `periodOf` only, unchanged | the track logic is Lantern's own (3.8) |
| `src/shared/Rng.luau` | required, unchanged | every roll |
| `src/relay/Models.luau` | required in place | LANTERN-006 adds `LanternAssets` in three places (section 9) |
| `src/relay/Props.luau` | required in place, unchanged | `part`, `label` |
| everything under `src/garden*`, `src/night*`, `src/relay*` other than the two above | not used, byte-identical | |

### File ownership by task

| Task | Writes |
|---|---|
| LANTERN-002 | `lantern.project.json`, `src/lantern/.gitkeep`, `src/lantern-client/.gitkeep`, `.github/workflows/ci.yml`, `.github/workflows/publish.yml`, `docs/architecture/README.md` |
| LANTERN-003 | `src/shared/{LanternConfig,LootRules,CarryRules,WispRules}.luau`, their specs, `tests/run.luau` |
| LANTERN-004 | `src/shared/{TrackRules,DepotRules,TrainRules,LanternProgress}.luau`, their specs, `tests/run.luau` |
| LANTERN-005 | `src/kit-roblox/modules/UiKit.luau`, `src/kit/SaveStore.luau` (the `newer` option), `tests/SaveStore.spec.luau`, `src/kit/CLAUDE.md`, `docs/decisions/0011-shared-kit-and-pipeline-trust.md` (a note) |
| LANTERN-006 | `src/lantern/**`, `src/relay/Models.luau` (three places), `src/shared/LanternConfig.luau` (TILES from the art's LAYOUT), `tests/LanternConfig.spec.luau`, this file |
| LANTERN-007 | `src/lantern-client/**` |
| LANTERN-008, 009, 010 | `tools/blender/lantern/assets/{train,items,depot}.py`, `tiles.py`, `{critters,night}.py` respectively |
| LANTERN-011 | `tools/blender/lantern/{manifest,uploaded}.json`, `src/shared/LanternAssets.luau`, `tests/LanternAssets.spec.luau`, `src/shared/LanternIcons.luau`, `tools/icons/lantern/**`, `docs/assets/register.md`, `docs/assets/lantern-blender-plan.md` |
| Art director (style test, own task) | `tools/blender/lantern/{kit,build,lineup}.py`, `tools/blender/lantern/README.md`, `docs/game-design/game6-art-bible.md` |

LANTERN-003 lands first (leaf modules); LANTERN-004 codes against 3.3 to 3.5 and lands second. LANTERN-006 and LANTERN-007 code against section 3 and the 0018 contract, may start on stubs once LANTERN-003's signatures are merged, and share no file. Art tasks share no code file: the game shows part fallbacks until LANTERN-011 fills `LanternAssets`. No task changes a signature in section 3 without updating this file in the same PR.

## 2. Conventions for the pure modules

- As `docs/architecture/garden.md` section 2: `--!strict`, no Roblox globals, requires by string (`require("./TrainRules")`), functions return new tables and never mutate inputs, `floor(x + 1e-9)` for every floor of a product.
- **Times:** run times are `GetServerTimeNow()` floats passed in as `now` (sub-second timers: fog, puffs, dives). Save times are integer `os.time()`; days are `MetaRules.dayOf(os.time())` passed in as `today`.
- **Vectors:** `Vec3 = { x: number, y: number, z: number }`. Three frames: **world**; the **stop frame** (the art's `LAYOUT` frame, `tools/blender/lantern/assets/tiles.py`: x across the tile, −60 to 60; y up from the tile's plate; z depth from the platform deck's track edge into the stop, 0 to 160, with the deck at 0 to 10 and its ramp at 10 to 15; the server maps it to world as `Site * Vector3.new(x, y, z)`, section 4.4); the **train frame** (origin at the engine's track point at y 0, −z forward along the track, y up, x right; built from `TrackRules.at(track, d)`, which the client rebuilds from the replicated `D`). Every night value (wisps, beams, lantern points, turret origins, the Lampeater) is in the train frame.
- **Ids:** species `mossmouse puddlefrog wickmole burrbun lanternbeetle fogpup acornowlet teapotcat reedfox mistfawn bellturtle moonhare emberkit`; rarities `common uncommon rare epic legendary`; lines `forest lake`; tracks `forest lake forestDawn lakeDawn`; tiles `village farm windmill orchard inn mill lighthouse boathouse`; items `coal parts oil supply critter`; seats `stoker turret mender passenger`; upgrades `boiler bunker lamps coal oil`; roles `stoker lamplighter scout mender`; pings `coal critter help back wisps thanks`; phases `hub ride stop night depot ended`; run ends `dawn coal lantern empty`.
- **Dependency graph** (no cycles): `LanternConfig` (types and data; requires only `MetaRules` for the `Cosmetic`/`Quest` types); `TrackRules` (none); `LootRules → Rng, LanternConfig`; `CarryRules → LanternConfig, LootRules` (types); `WispRules → Rng, LanternConfig`; `DepotRules → LanternConfig`; `TrainRules → LanternConfig, Rng, MetaRules, LootRules, CarryRules, WispRules, DepotRules`; `LanternProgress → MetaRules, LoginRules, LanternConfig, LootRules` (types).

## 3. Pure modules: exact signatures

### 3.1 `LanternConfig` (types and data only; every GDD C, F and H value lives here)

```luau
export type Vec3 = { x: number, y: number, z: number }
export type Line = "forest" | "lake"
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"
export type ItemKind = "coal" | "parts" | "oil" | "supply" | "critter"
export type SeatKind = "stoker" | "turret" | "mender" | "passenger"
export type Critter = { id: string, name: string, rarity: Rarity | "exclusive", lines: { Line }, tiles: { string }, leg3: boolean?, look: string }
export type Box = { at: Vec3, size: Vec3 } -- stop frame, centre and size
export type Tile = { id: string, name: string, lines: { Line }, small: { Vec3 }, big: { Vec3 }, blocks: { Box } }
export type Seat = { id: string, kind: SeatKind, at: Vec3 } -- car-local (car frame as the train frame, at the car's centre)
export type Car = { id: string, model: string, length: number, offset: number, seats: { Seat }, lanterns: { Vec3 }, turrets: { Vec3 } }
export type Track = { points: { Vec3 }, closed: boolean, stops: { number }, nightFrom: number, finish: number }
export type Upgrade = { id: string, name: string, costs: { number } } -- costs of levels II and III
export type LoginSlot = { count: number, tickets: number?, cosmetic: string?, critter: string?, owned: number? }
export type Role = { id: string, stat: string, tiers: { number } }

-- Train and run (GDD C1, C5)
LanternConfig.SPEED = { 20, 23, 26 }; LanternConfig.ACCEL = 4; LanternConfig.COAST = 2
LanternConfig.STOKE = { mult = 1.25, seconds = 6, coal = 2, cooldown = 6 }
LanternConfig.COAL_PER_STUD = 1 / 60; LanternConfig.BUNKER = { 80, 100, 120 }; LanternConfig.COAL_LOW = 15
LanternConfig.LANTERN = { max = 100, store = 6, autoBelow = 25, autoPour = 8, autoEvery = 3, mend = 12, mendMax = 88, mendCooldown = 3, depot = 40 }
LanternConfig.HUB = { grace = 3, firstSit = 20 }; LanternConfig.DEPOT = { max = 90, minStay = 10, grace = 3 }; LanternConfig.END_CARD = 12
-- Stops (GDD C2, C3)
LanternConfig.STOP = { calm = 70, depth = 160, width = 120, minStay = 10, grace = 3, limbo = 10, fogV0 = 6, fogAcc = 1, fogMax = 16 }
LanternConfig.MOVE = { walk = 16, small = 15, big = 13, critterSolo = 9, critterDuo = 13 }
LanternConfig.REACH = 8; LanternConfig.HELP_BREAK = 14; LanternConfig.LOAD_BOX = 6; LanternConfig.NEAR = 70
LanternConfig.ITEMS = { coal = { big = false, tickets = 1, coal = 5 }, parts = { big = false, tickets = 1, parts = 3 },
  oil = { big = false, tickets = 1, oil = 1 }, supply = { big = true, tickets = 8, parts = 10 }, critter = { big = true } }
LanternConfig.CRITTER_TICKETS = { common = 10, uncommon = 15, rare = 25, epic = 50, legendary = 100 }
LanternConfig.RARITY_COLOURS = { common = { 120, 170, 110 }, ... } -- GDD C7, RGB lists
LanternConfig.APPROACH = 200 -- studs before a stop where its tile is built
-- Nights (GDD C4)
LanternConfig.WAVES = { first = 8, gap = 25, perTurret = { 4, 6, 8 }, lake = 1, spawnMin = 60, spawnMax = 75,
  heightMin = 4, heightMax = 20, spread = 3, speed = 8, wobble = 2, reach = 3 }
LanternConfig.DIM = { 6, 4.5, 3.5, 3 } -- by min(n, 4)
LanternConfig.BEAM = { halfAngle = 7, range = { 80, 90, 100 }, puff = { 0.6, 0.45, 0.35 }, pitchMin = -15, pitchMax = 75, stale = 0.5 }
LanternConfig.LAMPEATER = { at = 50, warn = 3, radius = 45, height = 25, every = 8, dive = 3, shoo = 0.8, dim = 10, needBase = 15, needPer = 8 }
-- Odds (GDD H4), basis points in RARITIES order
LanternConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }
LanternConfig.ODDS = { near = { 7000, 2500, 500, 0, 0 },
  far = { forest = { 4600, 3400, 1500, 500, 0 }, lake = { 4000, 3400, 1800, 800, 0 } },
  farLeg3 = { forest = { 4300, 3400, 1500, 500, 300 }, lake = { 3700, 3400, 1800, 800, 300 } } }
LanternConfig.CRITTERS: { Critter }   -- the 13 rows of GDD H4, in that order
LanternConfig.TILES: { Tile }         -- 8 tiles copied from the art's LAYOUT (tiles.py, LANTERN-009): named blocks, 24 small sites (depth 18..150), 8 big sites at depths 22..150, street lamps
LanternConfig.BIG_DEPTHS = { 22, 40, 58, 78, 96, 114, 132, 150 }; LanternConfig.LINE_TILES = { forest = { ... }, lake = { ... } }
LanternConfig.TILE_DECK = { depth = 10, height = 1.8, length = 108, ramp = 15 } -- every tile's platform deck and ramp
export type Box = { name: string?, at: Vec3, size: Vec3 }; Tile gains `lamps: { Vec3 }` (code hangs a PointLight 7.5 up)
LanternConfig.TRACKS: { [string]: Track } -- forest, lake (closed loops, 5,700 ± 20 studs; stops 700, 1,400, 2,100; nightFrom 2,100); forestDawn, lakeDawn (open: the loop to 5,300 then the 400-stud spur; finish 5,700)
LanternConfig.OUTER = { forest = -1, lake = 1 } -- the platform side, as a multiple of TrackRules.right (the loop's outside)
LanternConfig.CARS: { Car }           -- engine (22 long, offset 0), cargo (16, 24), lamp (16, 42), passenger (18, 60): 78 studs; 12 seats, 4 turrets
LanternConfig.TRAIN_LENGTH = 78; LanternConfig.SEAT_COUNTS = { stoker = 1, turret = 4, mender = 1, passenger = 6 }
LanternConfig.UPGRADES: { Upgrade }   -- boiler {30, 60}, bunker {25, 50}, lamps {30, 60}
LanternConfig.COAL_BUY = { coal = 30, parts = 12 }; LanternConfig.OIL_BUY = { cans = 2, parts = 10 }
LanternConfig.TICKETS = { depot = 30, dawn = 150, fed = 50, coop = 0.1 }
LanternConfig.XP = { small = 2, big = 5, rescue = 20, new = 50, puff = 2, stoke = 1, mend = 3, stop = 5, depot = 40, dawn = 150 }
-- Meta (GDD H)
LanternConfig.QUESTS: { MetaRules.Quest }      -- the 8 of H5
LanternConfig.COSMETICS: { MetaRules.Cosmetic } -- the 14 of H6 (grant "album" or "login" where marked)
LanternConfig.SLOTS = { livery = "classic", lamp = "warm" }
LanternConfig.LOGIN = { week = { LoginSlot }, month = { LoginSlot } } -- H5 (7 each)
LanternConfig.MILESTONES = { { count = 4, tickets = 200 }, { count = 8, cosmetic = "mossback" }, { count = 12, cosmetic = "moonlit", tickets = 1000 } }
LanternConfig.ROLES: { Role }        -- stoker/stokes {30,300,1500}, lamplighter/puffs {100,1000,5000}, scout/loads {50,500,2500}, mender/mends {15,150,750}
LanternConfig.PINGS = { { id = "coal", text = "Coal here!" }, { id = "critter", text = "Critter here!" }, { id = "help", text = "Help carry!" },
  { id = "back", text = "Back to the train!" }, { id = "wisps", text = "Wisps there!" }, { id = "thanks", text = "Thanks!" } }
LanternConfig.CREW = { max = 6, active = 180, activeMove = 10 }; LanternConfig.WEEKLY_SALT = 6006
LanternConfig.critter(id: string): Critter?; LanternConfig.tile(id: string): Tile?; LanternConfig.cosmetic(id: string): MetaRules.Cosmetic?
```

The tracks are authored as control points: each loop measures about 1,570 × 1,620 studs around a 5,700-stud track (radius 600 at night does not fit 1,100 × 650: a quarter turn alone spans 600 × 600), the Forest loop east of the hub (x > 0), the Lake loop west, both passing the hub platform at d = 0 heading −z. Curve radius at least 150 studs on day rides (measured 197) and **at least 600 studs from `nightFrom` to the end** (measured 632) (so every car stays within 5 studs of the engine's train frame at night, and wisp and beam maths in the train frame holds for the rear turret). The 6 stop sites are at the loops' stop distances; the platform is on the loop's outer side (`OUTER`); the stop frame's +z points away from the track (section 4.4).

### 3.2 `TrackRules` (track geometry)

```luau
export type Path = { length: number, step: number, samples: { Vec3 }, closed: boolean } -- points every `step` studs of arc length
TrackRules.build(points: { Vec3 }, closed: boolean, step: number?): Path -- centripetal Catmull-Rom through the points, resampled by arc length (default step 2)
TrackRules.at(path: Path, d: number): (Vec3, Vec3) -- position and unit forward at distance d; a closed path wraps, an open one clamps to [0, length]
TrackRules.right(forward: Vec3): Vec3 -- horizontal unit right of a forward vector (y up)
TrackRules.toFrame(origin: Vec3, forward: Vec3, p: Vec3): Vec3 -- world point into the frame at origin facing forward (-z forward)
TrackRules.fromFrame(origin: Vec3, forward: Vec3, p: Vec3): Vec3 -- the inverse
TrackRules.radius(path: Path, from: number, to: number): number -- smallest turning radius sampled between two distances (spec and config checks)
```

### 3.3 `LootRules` (stops and critter rolls)

```luau
export type Item = { id: number, kind: LanternConfig.ItemKind, site: number, big: boolean, pos: LanternConfig.Vec3,
  species: string?, rarity: LanternConfig.Rarity?, state: "free" | "carried" | "loaded" | "lost", by: number?, helper: number? }
export type Stop = { tile: string, line: LanternConfig.Line, leg: number, index: number, n: number, items: { [number]: Item } }
LootRules.counts(n: number): { coal: number, parts: number, oil: number, supply: number, critter: number } -- GDD C3
LootRules.tileFor(seed: number, leg: number, index: number, line: LanternConfig.Line): string -- seeded pick from the line's six tiles, never the same tile twice in a leg
LootRules.build(seed: number, leg: number, index: number, line: LanternConfig.Line, n: number, first: boolean): Stop
  -- rng = Rng.seed(seed, leg * 10 + index, n); critter crates on the first big sites of a seeded shuffle (first: the 22-stud site leads),
  -- supply crates on the next; small items on seeded small sites, at most 3 a site, spread 1 stud; species rolled here, once
LootRules.rarity(rng: Rng.State, far: boolean, line: LanternConfig.Line, leg: number): (LanternConfig.Rarity, Rng.State)
LootRules.species(rng: Rng.State, rarity: LanternConfig.Rarity, line: LanternConfig.Line, tile: string, leg: number): (string, Rng.State)
  -- even shares among that rarity's species on the line and tile, else on the line (GDD H4); moonhare needs leg 3 and far (its row is 0 elsewhere)
LootRules.odds(line: LanternConfig.Line, leg: number, tile: string, far: boolean): { [string]: number } -- species basis points, sums to 10,000 (remainders to the first species in CRITTERS order)
```

### 3.4 `CarryRules` (carrying, loading, the fog)

```luau
export type Carry = { small: { number }, big: number? } -- item ids
export type Carries = { [number]: Carry } -- by UserId
type Stop = LootRules.Stop
CarryRules.canPick(stop: Stop, carries: Carries, userId: number, itemId: number): (boolean, string?) -- "gone" | "taken" | "hands" (holds a big item) | "full" (3 small) | "big" (small items held)
CarryRules.pick(stop: Stop, carries: Carries, userId: number, itemId: number): (Stop, Carries)
CarryRules.canHelp(stop: Stop, carries: Carries, userId: number, itemId: number): (boolean, string?) -- a critter crate carried by another player with no helper; the helper's hands empty
CarryRules.help(stop: Stop, carries: Carries, userId: number, itemId: number): (Stop, Carries)
CarryRules.letGo(stop: Stop, helperId: number): Stop -- the helper leaves the crate (break distance, the helper sits, leaves or is caught)
CarryRules.drop(stop: Stop, carries: Carries, userId: number, at: LanternConfig.Vec3): (Stop, Carries) -- all free at `at` (stop frame); a helper only lets go
CarryRules.load(stop: Stop, carries: Carries, userId: number, coalRoom: number): (Stop, Carries, { Item }) -- everything carried by userId as first carrier; coal sacks stay carried when coalRoom <= 0
CarryRules.catch(stop: Stop, carries: Carries, userId: number, at: LanternConfig.Vec3): (Stop, Carries) -- as drop; the items are behind the fog front
CarryRules.close(stop: Stop, carries: Carries): (Stop, Carries) -- departure: every free or carried item becomes "lost", carries emptied
CarryRules.speed(stop: Stop, carries: Carries, userId: number): number -- GDD C2 (a helper gets the duo speed)
```

### 3.5 `WispRules` (nights and the Lampeater, train frame)

```luau
export type Wisp = { id: number, born: number, from: LanternConfig.Vec3, target: LanternConfig.Vec3, speed: number, phase: number, lit: number, state: "drift" | "puffed" | "dimmed" }
export type Dive = { at: number, target: LanternConfig.Vec3, lit: number }
export type Lampeater = { born: number, fed: number, need: number, nextDive: number, dive: Dive?, gone: ("fed" | "dawn")? }
export type Night = { started: number, wave: number, nextWave: number, nextId: number, rng: Rng.State, wisps: { [number]: Wisp }, lampeater: Lampeater? }
export type Beam = { origin: LanternConfig.Vec3, dir: LanternConfig.Vec3 } -- dir is a unit vector
export type Event = { kind: "spawn" | "puff" | "dim" | "lampeater" | "dive" | "shoo" | "fed", wisps: { Wisp }?, ids: { number }?, amount: number?, target: LanternConfig.Vec3? }
export type StepInput = { now: number, dt: number, n: number, leg: number, line: LanternConfig.Line, lamps: number, beams: { Beam }, lanterns: { LanternConfig.Vec3 } }
WispRules.new(now: number, seed: number, leg: number): Night
WispRules.waveSize(n: number, leg: number, line: LanternConfig.Line): number -- GDD C4 / C6
WispRules.dimPer(n: number): number -- LanternConfig.DIM[min(n, 4)]
WispRules.pos(w: Wisp, now: number): LanternConfig.Vec3 -- straight drift from `from` to `target` at `speed` plus the wobble (2 studs, phase); clients draw the same
WispRules.lampeaterPos(l: Lampeater, now: number): LanternConfig.Vec3 -- circle (radius 45, height 25), or the dive line during a dive
WispRules.lit(beam: Beam, point: LanternConfig.Vec3, range: number): boolean -- angle <= BEAM.halfAngle and distance <= range
WispRules.clampAim(dir: any): LanternConfig.Vec3? -- nil unless a table of three finite numbers with 0.5 <= length <= 1.5; normalised; pitch clamped to [-15, 75] degrees
WispRules.step(night: Night, input: StepInput): (Night, { Event })
  -- spawns a wave at nextWave (waveSize, spread over WAVES.spread s, from the seeded rng, targets from input.lanterns);
  -- adds dt to `lit` of every drifting wisp inside any beam; puffs at BEAM.puff[lamps]; a wisp within WAVES.reach of its target dims (amount dimPer(n));
  -- leg 3: no waves at or after LAMPEATER.at, the Lampeater spawns at `at`, dives every `every` s, a dive with lit >= shoo is shooed else dims LAMPEATER.dim,
  -- fed += dt for each beam on it; fed >= need (needBase + needPer * (n - 1)) gives "fed"
```

### 3.6 `DepotRules` (run upgrades and votes)

```luau
export type Levels = { boiler: number, bunker: number, lamps: number } -- 1 to 3
export type Pools = { parts: number, coal: number, oil: number, levels: Levels }
DepotRules.price(pools: Pools, id: string): number? -- nil when maxed, unknown, or (coal, oil) no room for a full purchase
DepotRules.buy(pools: Pools, id: string): (Pools, boolean, string?) -- "parts" | "max" | "full" | "unknown"; a bunker upgrade keeps the coal
DepotRules.cruise(l: Levels): number; DepotRules.bunker(l: Levels): number; DepotRules.puff(l: Levels): number; DepotRules.range(l: Levels): number
DepotRules.tally(votes: { [number]: string }, options: { string }, default: string): string -- majority among options; a tie or no votes gives default
DepotRules.leftover(parts: number, n: number): number -- ceil(parts / max(n, 1))
```

### 3.7 `TrainRules` (the run state machine)

```luau
export type Phase = "hub" | "ride" | "stop" | "night" | "depot" | "ended"
export type Member = { userId: number, joined: number, active: number, seat: LanternConfig.SeatKind?, lastSeat: LanternConfig.SeatKind?, limboUntil: number?, stokeAt: number, mendAt: number }
export type Run = {
  phase: Phase, phaseAt: number, seed: number, weekly: boolean, leg: number, stop: number, line: LanternConfig.Line, track: string,
  d: number, speed: number, target: number, stokeUntil: number,
  coal: number, lantern: number, oil: number, parts: number, levels: DepotRules.Levels, pourAt: number,
  bellAt: number?, allSeatedAt: number?, firstSitAt: number?,
  crew: { [number]: Member }, order: { number }, votes: { [number]: string },
  loot: LootRules.Stop?, carries: CarryRules.Carries, night: WispRules.Night?,
  critters: number, dist: number, fed: boolean, ended: ("dawn" | "coal" | "lantern" | "empty")?,
}
export type Input = {
  now: number, dt: number,
  seats: { [number]: LanternConfig.SeatKind? }, -- the seat kind each crew member sits in now (server's Seat.Occupant)
  depth: { [number]: number? },                 -- stop frame depth of each standing crew member during a stop (nil when seated or off the stop)
  loadBox: { [number]: boolean },               -- crew member's root inside the train's load box
  beams: { WispRules.Beam },                    -- turret beams in the train frame (fresh aims only)
  lanterns: { LanternConfig.Vec3 },             -- lantern points in the train frame (from the car poses)
}
export type Event = { kind: string, userId: number?, items: { LootRules.Item }?, n: number?, reason: string?, payload: any? }
-- kinds and fields: "approach" (n: activeCount; run.loot is the stop to build, 200 studs out) "arrive" (n: stop) "bell"
--   "caught" (userId) "back" (userId, payload: seat kind) "load" (userId: carrier, items, n: activeCount) "seat" (userId,
--   payload: seat kind; the server seats them) "unseat" (userId; stand up) "depart" (payload: track) "night"
--   "wisp" (payload: a WispRules event) "depot" (n: leg) "dawn" (payload: { fed }) "fed" "coalLow" (reason: "low" | "night")
--   "end" (reason; payload: { parts = each member's leftover Parts share, critters, dist }) "hub" "stopLeft" (userId: stop XP)
TrainRules.new(seed: number, now: number): Run -- phase hub, full bunker, lantern 100, levels 1/1/1
TrainRules.join(run: Run, userId: number, now: number): (Run, "seat" | "platform" | "depot" | "hub")
TrainRules.leave(run: Run, userId: number, at: LanternConfig.Vec3?): (Run, { Event }) -- drops carries, removes votes; the last member out ends the run ("empty")
TrainRules.touch(run: Run, userId: number, now: number): Run -- marks active (a request, 10 studs moved, an aim)
TrainRules.activeCount(run: Run, now: number): number -- members active in the last CREW.active s (at least 1 while anyone is aboard)
TrainRules.tick(run: Run, input: Input): (Run, { Event })
  -- hub: departs 3 s after all seated or 20 s after the first sits ("seat" events for the rest); takes the weekly vote
  -- ride/night: speed to cruise (x STOKE.mult while stoking), brakes to stop exactly at `target`, burns coal per stud, coasts and ends "coal" at 0,
  --   re-seats anyone standing ("seat"), runs WispRules.step at night, applies dims, auto-pours, ends "lantern" at 0;
  --   200 studs before a stop builds `loot` (LootRules.build with activeCount) and emits "approach", so the tile exists before the train halts
  -- stop: "arrive" + "unseat" all, bell at calm, catches from `depth` vs fogFront ("caught", limbo 10 s, "back"),
  --   loads from `loadBox` ("load" with items and n), departs when all seated 3 s after minStay or when the fog reaches 0 (CarryRules.close, "seat" for the rest)
  -- depot: "depot" (+40 lantern), departs as DEPOT, takes the branch vote; leg 3 runs on <line>Dawn and ends "dawn" at finish
  -- ended: "end" once, then "hub" after END_CARD s: the returned run is a fresh one (new seed) that keeps the crew,
  --   standing, in its order; the server keeps it and never calls new() for it
TrainRules.stoke(run: Run, userId: number, now: number): (Run, boolean, string?)
TrainRules.mend(run: Run, userId: number, now: number): (Run, boolean, string?)
TrainRules.buy(run: Run, userId: number, id: string): (Run, boolean, string?)
TrainRules.vote(run: Run, userId: number, choice: string): (Run, boolean, string?)
TrainRules.pick(run: Run, userId: number, itemId: number): (Run, boolean, string?)
TrainRules.help(run: Run, userId: number, itemId: number): (Run, boolean, string?)
TrainRules.drop(run: Run, userId: number, at: LanternConfig.Vec3): (Run, boolean, string?)
TrainRules.letGo(run: Run, userId: number): Run
TrainRules.fogFront(run: Run, now: number): number? -- stop frame depth of the fog front; nil outside a stop or before the bell
TrainRules.coalNeed(run: Run): number -- coal to reach the end of tonight from here
TrainRules.conductor(run: Run): number? -- the longest-aboard member (order[1])
TrainRules.status(run: Run, now: number): { [string]: any } -- the LanternRun attributes of decision 0018
```

### 3.8 `LanternProgress` (the save, meta and rewards)

```luau
export type Profile = { schemaVersion: number, xp: number, coins: number, lastSeen: number, index: { string }, rescues: { [string]: number },
  stats: { [string]: number }, best: { critters: number, dist: number }, weekBest: { week: number, critters: number, dist: number },
  milestones: { [string]: boolean }, follower: string, livery: string, lamp: string, badge: string, owned: { [string]: boolean },
  daily: { streak: number, last: number }, week: { key: number, days: number, lastDay: number, claimed: boolean },
  quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } }, login: LoginRules.Login }
export type Loaded = { kind: LanternConfig.ItemKind, species: string?, rarity: LanternConfig.Rarity? }
export type Paid = { tickets: number, xp: number, new: { string }, text: string } -- `text` for LastReward / the payout toast
LanternProgress.SCHEMA_VERSION = 1
LanternProgress.config: MetaRules.Config<Profile>
LanternProgress.defaults(now: number): Profile
LanternProgress.sanitize(record: any, now: number?): Profile -- decision 0018 section 4
LanternProgress.snapshot(p: Profile, now: number): Profile -- lastSeen
LanternProgress.isNewer(record: any): boolean -- schemaVersion above 1 (for the kit's `newer` option)
LanternProgress.share(v: number, n: number): number -- ceil(v * (1 + TICKETS.coop * (n - 1)) / n - 1e-9)
LanternProgress.load(p: Profile, items: { Loaded }, mine: boolean, n: number, today: number): (Profile, Paid)
  -- shares of every item's Tickets; XP small/big only when `mine`, rescue XP always; rescues and index; new species XP; milestones reached (once);
  -- stats loads (mine), rescues, rareRescues; quest progress
LanternProgress.award(p: Profile, kind: "depot" | "dawn" | "fed" | "parts" | "stop", amount: number, today: number): (Profile, Paid) -- amount: leftover Parts share for "parts", else ignored
LanternProgress.count(p: Profile, stat: "puffs" | "stokes" | "mends" | "caught" | "legs" | "runs", by: number, today: number): Profile -- stats, XP (puff, stoke, mend), quest progress
LanternProgress.runEnd(p: Profile, critters: number, dist: number, week: number?, dawn: boolean): (Profile, { critters: boolean, dist: boolean }) -- best and weekBest; which weekly values improved
LanternProgress.dayTick(p: Profile, today: number): (Profile, string) -- pays the stored day's completed, unclaimed quests when today moved on, "(saved for you)" text
LanternProgress.loginTick(p: Profile, today: number): (Profile, string) -- the LoginRules.tick rules on LanternConfig.LOGIN
LanternProgress.join(p: Profile, today: number): (Profile, string) -- dayTick, loginTick, MetaRules.login; the combined toast
LanternProgress.canClaimLogin(p: Profile, track: string, today: number): boolean
LanternProgress.claimLogin(p: Profile, track: string, today: number, slot: number?): (Profile, boolean, string) -- slot = the slot the request saw (re-apply safe)
LanternProgress.claimable(p: Profile, today: number): number -- login slots claimable (REWARDS badge)
LanternProgress.claimQuest(p: Profile, today: number, id: string): (Profile, boolean, number)
LanternProgress.buy(p: Profile, id: string): (Profile, boolean); LanternProgress.equip(p: Profile, id: string): (Profile, boolean)
LanternProgress.tier(p: Profile, role: string): number -- 0 to 3
LanternProgress.setBadge(p: Profile, role: string): (Profile, boolean) -- "none" clears
LanternProgress.setFollower(p: Profile, species: string): (Profile, boolean) -- "none" clears
```

Every function that takes `today` runs `dayTick` first, so a completed quest is never wiped by `MetaRules`' day reset (GDD G3.5); `join` returns its text for the toast, the others pay silently. Login-granted critters (the Ember Kit) are added to `rescues` and `index` like a rescue and count for milestones. Cosmetics with `grant = "album"` are granted by the milestone, `grant = "login"` by the slot; both are owned-only (`MetaRules.isUnlocked` already treats `grant` like `price`).

## 4. Server (`src/lantern`)

### 4.1 Files

| File | Holds |
|---|---|
| `LanternServer.server.luau` | Boot: `Saves.start{ name = "LanternProfile", defaults, sanitize, snapshot, onChanged }` (the newer-save guard, 4.6); `ReplicatedStorage.LanternModels` filled for the client; the `Router` (0018 table) and `Remotes.create("LanternRemotes", router)`; `ReplicatedStorage.LanternRun`; `Players` join and leave; the 10 Hz loop and its event dispatch; carry checks (help break, G4 speed); the Heartbeat drive; the day-rollover and board refresh (every 60 s); the Max Players warning |
| `Train.luau` | Builds the four cars, named by their assets (`train_engine`, `train_car_cargo`, `train_car_lamp`, `train_car_passenger`): part fallbacks, the mesh welded on when it loads; seats (`Seat` parts with `Kind` and `Car` attributes); turret heads (`lamp_turret_head` parts with a `Seat` attribute); one load box per car; `drive(track, d)`; `frame()` (the train frame); `seat(player, kind, strict?)`; `stand(player, side, at?)`; `clearSeat(seat, side)`; `seats()` (UserId → kind); `seatOf(player)`; `turrets()`, `lanternPoints()` (train frame, from the car poses); `aimHead(seatId, dir)`; `door(side, along?)`; `inLoadBox(pos)`; `distance(pos)`; `paint(colours)`; `onOccupant(fn)` |
| `World.luau` | The four track paths and `World.at(track, d)` (a Dawn track before 0 reads its loop); `World.site(line, stop)`; rails (`rail_32` or parts every 32 studs); the platforms (hub, Dawn, the stop pieces under the train's rear); Lamplight Depot; Dawn Station; seeded decor; the weekly boards (SurfaceGuis); the base `Lighting`, `Atmosphere`, `Sky` and post effects of the art bible (dusk; the client tweens the phases) |
| `Stops.luau` | `build(stop, site, parent, onPrompt)`: the tile (`stop_<tile>` mesh, else part fallbacks from `Tile.blocks` dressed by block name, the deck, the ramp and the street lamps with their PointLights), the ground collider, invisible edges, every item model (`ItemId`, `Kind`, `Big`, `Rarity` attributes; `Pick` and `Help` prompts); `sync(loot, carries, rootOf)`; `depth(pos)`; `toStop(pos)`; `itemPos(id)`; `platform(n)`; `clear()` |
| `Carry.luau` | The look of carrying: small items welded to the back (three slots), the supply crate welded in front, the critter crate on a server-owned `AlignPosition` and `AlignOrientation` in front of its carrier or at the carriers' midpoint; the G4 speed check (`tooFast`); `inLoadBox(pos)` |
| `Night.luau` | The `Aim` intake (0018 checks, `RateLimit` burst 4 at 12 a second, `WispRules.clampAim`), the fresh beams for the tick and their owners, turret heads at 10 Hz, the `Fx` of every wisp event and the puff credit |
| `Rewards.luau` | Pays loads, Depot, Dawn, fed, leftover Parts and stop XP to each crew member's own save (`saves.apply` with a change that captures its inputs); counts puffs, stokes, mends and catches; run-end bests and the weekly boards; the end card tallies; announcements; `LastReward`; `ReplicatedStorage.LanternBoards` |
| `CLAUDE.md` | The short context for threads (as `src/garden/CLAUDE.md`) |

### 4.2 Run lifecycle on the server

- `run = TrainRules.new(seed, now)` once at start. Seed: `Rng.seed(os.time(), hash(JobId))`; when the weekly vote wins at the hub departure, TrainRules switches to `Rng.seed(MetaRules.weekOf(today), LanternConfig.WEEKLY_SALT)`. After a `hub` event the server **keeps the returned run** (a fresh run that carries the crew); it never calls `new()` again.
- **10 Hz loop:** activity first (10 studs moved while standing, an aim in the last second: `TrainRules.touch`); build `Input` from the world (`Train.seats()` for crew members, `Stops.depth` for standing crew during a stop, `Carry.inLoadBox` for carriers, `Night.beams()`, `Train.lanternPoints()`), call `TrainRules.tick`, keep the returned run, and dispatch each event: `seat`/`unseat` to `Train`, `approach` to `Stops.build`, `arrive` (and `depot`) to `Fx arrive`, `caught` to a hide-and-anchor of the character (and `back` to `Train.seat`), `load` to `Rewards.load`, `stopLeft` to stop XP, `depart` to `Stops.clear`, `wisp` events to `Night.fx` (puff credit to `Rewards.count`), `depot`/`dawn`/`end` to `Rewards`, `hub` to the hub return; then the help break and the G4 speed check, `Stops.sync`, the turret heads, `TrainRules.status` to `LanternRun` (changed attributes only, `D` at 2 Hz), the player attributes and the conductor's livery.
- **Heartbeat drive:** `Train.drive(run.track, min(run.target, run.d + run.speed * (now - lastTick)))` while the train moves, so the cars move smoothly between ticks.
- **Requests** call the matching `TrainRules` or `LanternProgress` function; a request that changes the run replaces `run` in the same frame (no yield between reading and writing the run) and touches the member's activity. Profile requests try the pure function on the live profile first and then `saves.apply` the same change.
- **Prompts:** `Pick up` and `Help carry` are server ProximityPrompts on item bodies (`MaxActivationDistance` = `REACH`, `HoldDuration` 0.3); `Triggered` checks crew membership and the server distance (`REACH` + 2), then `TrainRules.pick` / `help`; a refusal goes back as `Fx notice` with words (prompts have no reply channel).
- **Join and leave:** `PlayerAdded` loads the save (`saves.load`), runs `LanternProgress.join` and shows its toast; `play` calls `TrainRules.join` and places the character by its answer (`seat`, `platform` on the stop's deck, `depot`/`hub` on the hub platform); a crew member's respawn is placed the same way. `PlayerRemoving` calls `TrainRules.leave` (items dropped where the player stood) before the kit's `saves.finish`.

### 4.3 Train, seats and the seated rule

The rule is decision 0018 section 2; the train is built as 0018's **fallback**: anchored server cars moved by CFrame (LANTERN-006 brief). Each car is one assembly: an anchored base part (the floor collider, 2.3 above the rail top) with every other part, seat and turret head welded to it (`Massless`, no collision); `Train.drive` sets each base's CFrame every Heartbeat at `TrackRules.at(track, d − offset − length / 2)`, so seated characters (welded to their seat) ride along and no character physics runs on a moving car. Turret heads hang on a `Weld` whose `C0` turns them. Seats are server-assigned (`Seat:Sit(humanoid)` after pivoting the character beside the seat); touch-sitting works for crew members, and a non-crew sitter is stood up at once and stepped off the car. Standing up removes the `SeatWeld` and moves the character beside its car on the platform side; the server owns the character's physics for that move (0.4 s), because the client's seated pose overwrote a plain move in Studio. `Humanoid.SeatPart` can stay set after the weld is gone, so `Train.seatOf` also checks `Seat.Occupant`. The load boxes (one per car, 6 studs out each side) are invisible and used only for the server's position test. The train frame is `TrackRules.at(track, D)` at y 0 (the client rebuilds the same frame from `D`); lantern points and turret origins are converted into it from the car poses.

### 4.4 Stops and the fog

The stop frame is the art's `LAYOUT` frame (`tools/blender/lantern/assets/tiles.py`, copied into `LanternConfig.TILES`). `World.site(line, stop)` is level with the engine's front at the stop distance, on the platform deck's track edge **4 studs out** from the track centre on the loop's outer side, at the tile's plate top (rail top + 0.2), looking at the track: a stop frame point `(x, y, depth)` is `Site * Vector3.new(x, y, depth)`, +Z running into the stop. The tile's deck (depth 0 to 10, 1.8 high, 108 long; 4 to 14 studs from the track) is the platform; its ramp runs down to the plate at 15; the sites start at 18. The `Stop` model carries `Site`, `Tile`, `Line`, `Leg` and `Index` attributes.

A stop is built on `approach` (200 studs out, about 10 s before the train halts). The tile mesh is decor placed by bounding box with the site's heading (the FBX arrives turned half round, so its x is the stop frame's x and its depth runs along +Z; a mirrored tile is fixed in this yaw, never in the art); collision comes from `Tile.blocks` parts, the deck, the ramp and one ground collider, so code never reads the mesh. Until the mesh exists, the blocks are dressed by name (houses with roof, plinth and lit windows; trees; water; low props). A platform piece under the train's rear (54 to 100 studs behind the stop distance) carries the deck on under the passenger car. The fog has no server part: clients draw it from `BellAt` and the stop site (GDD L); the server compares each standing crew member's `Stops.depth` with `TrainRules.fogFront` in the tick, and a member on the deck (depth 10 or less) is never caught (GDD C2: the crew on the platform is seated when the fog reaches it). A caught character is anchored and moved under the tile for the limbo, then seated.

### 4.5 Night on the server

`Night.beams()` returns, for each turret seat whose occupant sent the stored aim and whose aim is younger than 0.5 s, `{ origin = turret origin in the train frame, dir = stored aim }`, and the UserId behind each beam. The hit test runs inside `WispRules.step` (pure) on the server's own wisp positions. Spawns go to clients as `Fx wisps` batches of at most 40 spawn records; clients compute positions with `WispRules.pos`. The server never trusts a client's wisp position or time.

### 4.6 Rewards and saves

- `Rewards.load(run, event, now)`: for every **active** crew member `m` (`now − m.active ≤ CREW.active`), `saves.apply(m, function(p) return (LanternProgress.load(p, items, mine, n, today)) end)` with `items` (kind, species, rarity), `mine`, `n` and `today` copied before the closure; then `Fx payout` and `new` to that player, `load` and `rescue` to everyone and `announce` for Rare and above.
- Depot, Dawn, fed (paid at Dawn), stop XP and leftover Parts: `LanternProgress.award` for every crew member aboard; run end: `LanternProgress.runEnd` and, for a weekly run that improved a value, an `UpdateAsync` on the weekly ordered store keeping the larger value; then each member's own `Fx runEnd`.
- Puffs: the server credits a puff to every player whose beam lit the wisp in the tick that puffed it (`count(p, "puffs", k)`); stokes and mends to the actor; catches to the caught player.
- Every change is a pure function of its captured inputs (kit rule); random outcomes were fixed when the stop was built.
- **Newer saves:** until the kit's `newer` option (LANTERN-005) is passed through `Saves.start`, the server's `sanitize` throws on a record with `schemaVersion` above 1, so the load's `UpdateAsync` writes nothing and the session goes offline; the server then reads the record (`GetAsync`) and shows it sanitised in memory for that session. Nothing is ever written over it.

### 4.7 Weekly boards

Two ordered stores per week (0018 section 4). `Rewards` reads the top 10 of each every 60 s (`GetSortedAsync`; display names through `UserService:GetUserInfosByUserIdsAsync`, cached per session: GDD G5 shows display names only) and writes them to the Depot boards and to `ReplicatedStorage.LanternBoards` (a StringValue, JSON `{ critters = { { name, value } }, dist = { ... } }`, both lists present from the start) for the BOARD panel. Read failures keep the last list.

## 5. `Fx` payloads and status

Decision 0018 section 3, as built. Times in payloads are `GetServerTimeNow` seconds; vectors in wisp and dive payloads are train-frame `{ x, y, z }` tables, `ping.pos` is a world `Vector3`.

| Kind | To | Payload |
|---|---|---|
| `arrive` | all | `{ phase = "stop" or "depot", leg, stop (0 at the Depot), tile ("" at the Depot), line }` |
| `bell` | all | `{ at }` |
| `depart` | all | `{}` |
| `load` | all | `{ by, kind, count }`, one per item kind in the load |
| `rescue` | all | `{ by, species, rarity }` |
| `new` | the player | `{ species }` |
| `caught`, `back` | all | `{ userId }` |
| `wisps` | all | `{ list = { { id, born, from, target, speed, phase } } }`, at most 40 records |
| `puff` | all | `{ ids }` puffed in one tick |
| `dim` | all | `{ id (nil for a Lampeater dive), lantern }` (the lantern after the tick) |
| `lampeater` | all | `{ born, seed }` |
| `dive` | all | `{ at, target }` |
| `shoo` | all | `{ target }` (not in 0018's list; the LANTERN-007 client plays it) |
| `fed` | all | `{}` |
| `ping` | all | `{ userId, id, pos }` |
| `buy` | all | `{ userId, id, level }` (level nil for coal and oil) |
| `payout` | the player | `{ tickets, xp, text }` |
| `runEnd` | each player | `{ reason, summary = { critters, dist, tickets, xp } }` (their own Tickets and XP this run) |
| `announce` | all | `{ name (display name), species, rarity }` |
| `notice` | the player | `{ text }` (prompt refusals, the join toast, rollover payouts, a slipped load) |

`Request` refusal codes are 0018's list plus the carry codes of `TrainRules.pick`/`help`/`drop` (`gone`, `taken`, `hands`, `big`), which reach players as `notice` words. `LanternRun` attributes are `TrainRules.status` with `Crew` (JSON list of `{ userId, seat, active, badge }`) and `Votes` (JSON tallies). Player attributes: `Profile` (JSON of the whole save), `ProfileOnline`, `Tickets`, `Level`, `XP`, `LastReward`, `Carry` (JSON `{ small = { kinds }, big = kind?, help = itemId? }`), `Seat` (kind or ""), `Badge`, `Follower`, `Lamp`. `ReplicatedStorage.LanternModels` holds the client-drawn templates (`shadow_wisp`, `lampeater_*`, `critter_<id>`) once their ids exist.

## 6. Client (`src/lantern-client`)

| File | Holds |
|---|---|
| `ClientState.luau` | The Lantern theme tokens (passed to `UiKit.configure`), the run status reader (`LanternRun` attributes as a table plus a changed signal), the profile reader, `request(action, arg)` with the refusal-code texts, sounds (`SFX` ids nil until registered), rarity colours (GDD C7) |
| `Menu.client.luau` | `UiKit.startMenu` and the panels: ALBUM (GRID, WHERE with `LootRules.odds`, FOLLOWER), LOCKER (LIVERY, LAMP, BADGE), REWARDS (WEEKLY, MONTHLY, QUESTS, with `claimLogin` and `claimQuest`), BOARD (two weekly lists), SETTINGS (music, sound effects, Calm night, How to play) |
| `Hud.client.luau` | The HUD of GDD H2: lantern meter, phase chip and bell chip, coal bar with tonight's need, Parts and oil, coin pill and level ring, carry slots and DROP, seat buttons (SIT, STOKE, MEND), crew list with badges, seats and pings; the Depot panel (upgrade cards, branch or weekly vote); the run end card; toasts and announcements |
| `PingWheel.client.luau` | Hold `Q`, the left bumper or the ping button; six slices; sends `ping <id>` or `ping <id>:<itemId>` for the item under the cursor or the centre of the screen; draws markers from `Fx ping` (8 s, 3 per player) |
| `LampFx.client.luau` | Turret control: while `Seat` is a turret, the camera sits behind the lamp head; the mouse ray, a touch drag or the right stick gives the world direction, converted into the train frame with the replicated engine CFrame and sent on `Aim` at 10 Hz when it changed by more than 0.5°; the local beam draws at once; other turrets' beams follow their replicated heads. Draws wisps from `Fx wisps` with `WispRules.pos` and `GetServerTimeNow`, the Lampeater with `WispRules.lampeaterPos`; puff, dim, dive and fed effects |
| `TrainFx.client.luau` | The seated camera (a gentle sway), chuff rate from `Speed`, smoke, whistle and bell; the fog wall at stops from `BellAt` (a moving wall of particle emitters and a translucent gradient, the same front formula as `TrainRules.fogFront`); the caught overlay; lighting by phase (dusk on the last ride, night, dawn); item glow and bob; rescued critters in the passenger windows; followers (hop behind their owner at the Depot, ride on the seat arm during runs); the client half of the seated rule (jumping disabled while seated on a moving train) |
| `CLAUDE.md` | The short context for threads |

Rules that must stay true: the client never decides an outcome; every widget comes from `UiKit`; every animation is skipped under `GuiService.ReducedMotionEnabled`; no image other than `LanternIcons` ids and `ViewportFrame`s; text at least 12 px on an 844 × 390 screen; the fog drawn by the client never decides a catch.

## 7. Kit changes (LANTERN-005)

- **`src/kit-roblox/modules/UiKit.luau`:** the Garden UI kit (`src/garden-client/UiKit.luau` at GARDEN-058, architecture garden 6.4) with every Garden dependency injected. `UiKit.configure{ tokens = { [name]: Color3 }, fonts = { body: Font, title: Font }, icons = { [string]: number? }, sound = (name: string, volume: number?) -> (), short = (n: number) -> string, rarity = { colour: (id: string) -> Color3, name: (id: string) -> string }, previews = Folder? }` must be called once before the first widget. Same widgets, same numbers (GDD X1.3 of game 4), same rules (one panel at a time, Reduced Motion, 12 px minimum). `eggDisc` stays in Garden. The kit's existing `Ui.luau` stays for games that use it.
- **`SaveStore` option `newer: ((record: any) -> boolean)?`:** when it returns true for the stored record at load, the session runs offline with that record sanitised, writes nothing (no lock claim, no autosave, no final write) and logs "newer save". Tests in `tests/SaveStore.spec.luau`; noted in decision 0011 as a backwards-compatible addition.

## 8. Tests per module

| Spec | Cases (beyond one per signature) |
|---|---|
| `LanternConfig.spec.luau` | every odds row sums to 10,000; every critter's lines and tiles exist; every tile has 24 small and 8 big sites at the C3 depths, inside 120 × 160, none inside a block, all past the deck and ramp and off the lamps, with pinned rows of the art's LAYOUT; the loops measure 5,700 ± 20 with stops at 700, 1,400, 2,100; radius ≥ 150 on rides and ≥ 600 from `nightFrom` (`TrackRules.radius`); the Dawn tracks end at 5,700; the cars total 78 studs with 12 seats (1 stoker, 4 turrets, 1 mender, 6 passengers); ids unique; 8 quests with known stats; 14 cosmetics; 7 slots per login track; every grant cosmetic has its grant |
| `TrackRules.spec.luau` | a closed path wraps (`at(0) == at(length)`); forward is a unit vector; consecutive samples are `step` ± 2% apart; an open path clamps; `toFrame` and `fromFrame` round-trip; `radius` of a circle of radius 200 is 200 ± 2 |
| `LootRules.spec.luau` | `counts` for n = 1 to 6 equals GDD C6; `build` is deterministic for the same arguments; stop 1 puts a critter crate on the 22-stud site; big sites hold one item, small sites at most 3; no tile repeats in a leg; `odds` sums to 10,000 for every line, leg, tile and band; over 100,000 seeded rolls each rarity is within 0.5 points of its row; `moonhare` only from leg 3 far crates; `mistfawn` never on the Lake Line, `bellturtle` never on the Forest Line; `emberkit` never rolled |
| `CarryRules.spec.luau` | one case per cell of the GDD J table; 3 small or 1 big; no pick of a carried item; help only on a critter crate carried alone; `letGo` keeps the first carrier; speeds 16 / 15 / 13 / 9 / 13; a full bunker leaves coal carried; `catch` drops; `close` loses every free and carried item and empties carries |
| `WispRules.spec.luau` | `waveSize` equals GDD C6 (+1 on the Lake); `dimPer`; `pos` is deterministic and reaches the target at distance / speed; `lit` at 6.9° in, 7.1° out, and at the range edge; `clampAim` refuses NaN, infinity, zero, length 2, non-tables, and clamps pitch; exposure adds across beams and puffs at 0.6 / 0.45 / 0.35 s; aims sent more often do not puff faster (exposure grows by the tick's `dt`); waves at 8 s then every 25; leg 3 stops waves at 50 s, the Lampeater dives every 8 s, a 0.8 s beam shoos, `need` by n, fed once |
| `DepotRules.spec.luau` | prices and caps of GDD F; a bunker upgrade keeps coal; coal and oil refused without room; `tally` majority, tie and no votes give the default; `leftover` |
| `TrainRules.spec.luau` | hub departure (3 s after all seated; 20 s after the first sit with `seat` events); a ride brakes to the exact stop distance and takes 40 s at Boiler I; arrival stands everyone up; bell at 70 s; `fogFront` 160 at the bell and 0 at 13.1 s; caught → 10 s limbo → `back`; early departure needs 10 s and 3 s seated; departure at the fog seats the rest; coal 95 a leg; out of coal coasts and ends "coal"; lantern 0 ends "lantern"; night 180 s with 7 waves at Boiler I; Depot +40 lantern and payout events, 90 s cap; branch vote; leg 3 on the Dawn track ends "dawn"; **the seated rule:** while moving, every member is seated or in limbo after each tick, a stood member gets a `seat` event the same tick; join placement per phase; leave drops carries; the last leave ends "empty"; `activeCount` drops a member after 180 s idle; **pacing check values** (GDD P): stop 1 at 43 s from PLAY, first rescue reachable at 49 s, stop 2 by 169 s |
| `LanternProgress.spec.luau` | defaults; every sanitise rule of 0018 section 4; `isNewer`; `share` for v = 1, 8, 10, 100 and n = 1 to 6; `load` pays shares, XP only for `mine` small and big, rescue XP always, a new species once, milestones 4 / 8 / 12 once each (with the cosmetic grants); `dayTick` pays a completed unclaimed quest of the stored day once and nothing twice; login: the LoginRules spec cases on Lantern's slots (rollover pays earned unclaimed slots once, re-apply is idempotent, a clock behind changes nothing), the Ember Kit enters the album, an owned exclusive pays its Tickets; `runEnd` bests and weekly reset; badge tiers; follower only from the album; MetaRules' own spec unchanged |
| `SaveStore.spec.luau` (LANTERN-005) | a newer record loads offline, is sanitised in memory and is never written (no lock claim, no flush, no final write); without the option nothing changes |
| `LanternAssets.spec.luau` (LANTERN-011) | every name in section 9 exists; no name collides with `NightAssets` or `GardenAssets`; sizes within section 9's bounds; critters 2.0 to 3.5 tall within 3 × 3; tiles 120 × 160 within 2% |

Every spec is registered in `tests/run.luau`; `Purity.spec` covers the new `src/shared` modules.

## 9. Assets for v0.1 (the Blender pipeline contract)

Generated by `tools/blender/lantern` (the art director's kit, the Garden pipeline's conventions) into `src/shared/LanternAssets.luau` (same `Asset` type as `NightAssets`); a nil model id means not uploaded, and the game keeps the part fallback, so code never waits for art.

**Conventions:** 1 unit = 1 stud; **origin at the base centre, front on Blender −Y** (arrives facing Roblox −Z at yaw 0, the Garden convention); one mesh and one baked 1024 full-RGB texture per asset with 192-sample AO; **pivots are not kept** (`Models.luau` rebuilds each asset into a Model whose pivot is its bounding-box centre), so a part that turns about a hinge must be symmetric about that hinge, and code places everything by bounding box; sizes are the manifest's measured values and code scales with `Model:ScaleTo` to the sizes below; hit tests, seats, sites and collision always come from `LanternConfig`, never from a mesh.

**Loading:** `src/relay/Models.luau` changes in three places (LANTERN-006): `local LanternAssets` (optional require, as `GardenAssets`), `loadNight` reads `NightAssets[name] or GardenAssets[name] or LanternAssets[name]`, and `Models.preloadLantern()`.

| Name | Size (studs, L × H × W or W × H × D) | Tris | How code uses it | Fallback |
|---|---|---|---|---|
| `train_engine` | 22 × 11 × 8, with tender and open cab | 12,000 | decor welded to the engine base part; chimney top is where smoke spawns (config) | red block body, black cylinder boiler, chimney |
| `train_car_cargo` | 16 × 7 × 8, coal bunker and crate deck | 6,000 | decor on the cargo base part | block wagon |
| `train_car_lamp` | 16 × 9 × 8, flatcar with two turret rings and a lantern rack | 6,000 | decor | block flatcar |
| `train_car_passenger` | 18 × 10 × 8, six seats visible, 8 windows | 8,000 | decor; window slots for riding critters are config | block coach |
| `lamp_turret_base` | 3 × 2 × 3 | 1,200 | at each turret position | cylinder |
| `lamp_turret_head` | 2.4 × 2.4 × 3.6, glass front on −Y, symmetric about its hinge | 1,500 | turned about its bounding-box centre by the server (yaw, pitch) | block with a pale glass face |
| `item_coal_sack` | 1.6 × 1.4 × 1.2 | 800 | item, welded to backs when carried | dark block |
| `item_parts_bag` | 1.6 × 1.2 × 1.2 | 800 | item | brown block |
| `item_oil_can` | 1.0 × 1.6 × 1.0 | 600 | item | yellow cylinder |
| `item_supply_crate` | 3 × 3 × 3 | 900 | item | wooden block |
| `item_critter_crate` | 3.6 × 3 × 2.6, handles at both ends, air holes, a window | 1,200 | item; the glow is a code light in the rarity colour | block with handles |
| `stop_village`, `stop_farm`, `stop_windmill`, `stop_orchard`, `stop_inn`, `stop_mill`, `stop_lighthouse`, `stop_boathouse` | footprint exactly 120 × 160 (a ground plate is part of the mesh, so the bounding box is the footprint); height up to 40 (lighthouse and windmill up to 48); buildings sit on `Tile.blocks` | 15,000 each | decor placed by bounding box in the stop frame; collision from `Tile.blocks` | coloured blocks from `Tile.blocks` |
| `critter_<id>` × 13 (GDD H4 ids) | height 2.0 (commons) to 3.5 (Moon Hare), footprint within 3 × 3 | 6,000 each (HD creature standard, the shared face) | rescue reveal, passenger windows, followers, album viewports; bob and hop by code | two balls, ears and the rarity colour |
| `shadow_wisp` | 2.5 × 2.5 × 2.5, soft dark puff with two bright eyes baked | 1,500 | night, up to 40 on screen; swell and pop by code | dark ball with two white dots |
| `lampeater_body` | 6 × 6 × 16, front −Y, lantern-glass eyes | 7,000 | the finale; swoop by code | block body |
| `lampeater_wing_l`, `lampeater_wing_r` | 18 × 1.5 × 12 each, hinge on the inner edge | 2,500 each | flapped by code, offset by half their width from the body | wedge parts |
| `depot_hub` | 60 × 30 × 24, red brick, clock, brass lamps | 15,000 | Lamplight Depot | blocks |
| `depot_platform` | 40 × 2 × 10 | 1,500 | the hub (2) and each stop site (1) | block |
| `depot_signal` | 2 × 12 × 2 | 1,000 | hub and Dawn decor | cylinder and ball |
| `depot_board` | 16 × 10 × 1.5 frame | 1,500 | Depot upgrade and weekly boards (a SurfaceGui part in front) | block frame |
| `dawn_station` | 60 × 36 × 30, white, facing the sunrise | 15,000 | the finish | blocks |
| `rail_32` | 32 × 1 × 8, two rails, sleepers, ballast | 600 | laid every 32 studs along the tracks, chord to the curve | two thin parts |
| `decor_pine`, `decor_birch`, `decor_rock` | 10 × 28 × 10, 8 × 22 × 8, 8 × 4 × 6 | 3,000, 3,000, 800 | seeded scatter, 30 to 150 studs from the track | cone and cylinder, ball |

45 assets: two upload runs (26 fit in one run with a short poll; studio lessons). Each gets a `docs/assets/register.md` row before upload. The **style test** (art director) is `train_engine`, one critter and the `stop_village` house set, at this standard, reviewed on a contact sheet before LANTERN-008 to 010 start. Budget on screen (assumption, checked at the phone gate): the train about 45,000 tris, a stop 15,000 plus items, up to 14 critters 84,000, 40 wisps 60,000, rails and decor inside the 250-stud fog about 150,000.

**Sounds and icons** (LANTERN-011, licensed partners only, a register row each): music (day, night, Lampeater, Dawn sting) and the SFX of GDD M; 20 icon decals drawn with Pillow (`tools/icons/lantern`): album, locker, rewards, board, settings, coal, parts, oil, lantern, ticket, four roles, six pings (glyph fallback until uploaded), ids in `src/shared/LanternIcons.luau`.

## 10. Rojo project and CI

`lantern.project.json` (LANTERN-002):

```json
{
  "name": "lantern-express",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Kit": { "$path": "src/kit" },
      "KitRoblox": { "$path": "src/kit-roblox/modules" },
      "BuildInfo": { "$path": "build-info/BuildInfo.txt" }
    },
    "ServerScriptService": {
      "Lantern": {
        "$path": "src/lantern",
        "Models": { "$path": "src/relay/Models.luau" },
        "Props": { "$path": "src/relay/Props.luau" }
      },
      "BuildStamp": { "$path": "src/kit-roblox/BuildStamp.server.luau" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "LanternClient": { "$path": "src/lantern-client" },
        "BuildStamp": { "$path": "src/kit-roblox/BuildStamp.client.luau" }
      },
      "$properties": { "CharacterWalkSpeed": 16, "CharacterJumpPower": 50, "CharacterUseJumpPower": true }
    },
    "Workspace": {
      "$properties": { "StreamingEnabled": false },
      "SpawnLocation": {
        "$className": "SpawnLocation",
        "$properties": { "Anchored": true, "Neutral": true, "Size": [12, 1, 12], "Position": [0, 0.6, 30], "Transparency": 1 }
      }
    }
  }
}
```

`StreamingEnabled` is off on purpose: the world is two loops of rails, decor and one stop at a time inside a 250-stud fog, and client code reads stop and train instances without streaming waits (GDD S assumption; the phone gate checks it). If Rojo refuses the Workspace property, LANTERN-002 notes it and the place setting is set in Studio at the checkpoint instead.

**CI** (`ci.yml`, LANTERN-002): add `rojo build lantern.project.json --output build/lantern.rbxl` to the build step and `build/lantern.rbxl` to the sha256 line; add `node tools/check-place.mjs lantern.project.json build/lantern.rbxl --sha "$GITHUB_SHA"` to the place check. **Publish** (`publish.yml`): add `lantern-staging` to the environment options and `lantern-*) project=lantern.project.json ;;` to the project case, plus the header comment. The `lantern-staging` GitHub environment (variables `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`, secret `ROBLOX_API_KEY`) and the experience are created by SHANNON (checkpoint); no production environment for Lantern until SHANNON approves a production release.

## 11. Resolutions of points the GDD leaves open

1. Loot counts use the active crew as the train approaches (200 studs out); a player who joins later adds no items to that stop.
2. The first carrier owns a critter crate's load (and its `mine` XP); the helper gets the crew share like everyone else.
3. A full bunker refuses coal sacks at the load (they stay carried); an oil can with a full store pours +8 at once.
4. Puff credit goes to every player whose beam lit the wisp in the puffing tick; a shared puff counts once for each of them (roles and quests), XP 2 each.
5. A player in fog limbo counts as seated for the seated rule and as not seated for the early departure (a caught crew member does not delay the train).
6. The conductor is `order[1]`, the earliest member still aboard; it changes only when that member leaves.
7. The hub and the Depot are the same model; the Depot panel opens only in phase `depot`, the vote card in phase `hub` shows FREE RUN and LINE OF THE WEEK.
8. Run end returns everyone to the hub platform standing; the next run starts when someone sits (hub rules).
9. `dist` for the Farthest board is the distance travelled this run across legs (rides and nights), capped at three legs' total; a Dawn finish is the cap.
10. A `ping` with an item id outside 60 studs is placed at the player instead (not refused), so a ping always shows.
11. The weekly vote is taken at the hub departure; a weekly run started with n players keeps its seed if the crew changes.
12. Day rollover while online: the server's 60 s check calls `dayTick` and `loginTick` for every online player when `MetaRules.dayOf(os.time())` changes, and shows the "(saved for you)" toast.
