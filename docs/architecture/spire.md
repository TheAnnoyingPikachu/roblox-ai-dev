# Neon Spire: architecture (v0.1)

Owner: A09. Status: final for the build (SPIRE-003), verified by A01. Inputs: `docs/game-design/game5-gdd.md` (the GDD; section letters refer to it), `docs/game-design/game5-art-bible.md` (the art bible), decisions 0009 (economy, saves, remotes) and 0010 (assets), and the Egg Garden code after its GARDEN-006 fixes. If this file and the GDD disagree on a rule, the GDD wins and this file is fixed; the resolutions in section 10 are the exception (they settle what the GDD leaves open or could not work as written).

## 1. Place, files and who owns them

Rojo project `spire.project.json`:

| Instance | Source |
|---|---|
| `ReplicatedStorage.Shared` | `src/shared` (pure modules, shared with the other games) |
| `ReplicatedStorage.BuildInfo` | `build-info/BuildInfo.txt` (StringValue; section 9) |
| `ServerScriptService.Spire` | `src/spire` |
| `ServerScriptService.Spire.Models` | `src/relay/Models.luau`, **required in place** (hero props, decision 0010) |
| `StarterPlayer.StarterPlayerScripts.SpireClient` | `src/spire-client` |
| `Workspace.SpawnLocation` | at (0, 0.6, 0), centre of the Grid Plaza, invisible (fallback; the server moves each character into its lobby) |

`src/spire` and `src/spire-client` hold a `.gitkeep` so the project builds before the scripts exist; delete it when the first script lands. Never add a `Models.luau` to `src/spire` (it would collide with the in-place mapping).

### Reused files

| File | Spire | Notes |
|---|---|---|
| `src/shared/Rng.luau` | required in place, unchanged | Market schedule, company name of a new profile |
| `src/shared/MetaRules.luau` | required in place, **unchanged** | Spire uses the existing `maxCoins`, `dailyMinutes` and `scale` options. Credits are stored as `coins` and cosmetic slots at the top level of the profile because MetaRules reads and writes those names (section 10, resolution 1). |
| `src/garden/Profiles.luau` | **copied** to `src/spire/Profiles.luau` | Session lock, coalesced re-apply, offline mode, `BindToClose`; `bank` becomes `earn` (4.2) |
| `src/garden/Remotes.luau` | **copied** to `src/spire/Remotes.luau` | `SpireRemotes` (`Request`, `Fx`), `SpireStatus`; `Request` returns `(ok, code)` |
| `src/garden-client/Menu.client.luau` | **forked** to `src/spire-client/Menu.client.luau` | restyled to the art bible UI kit |
| `src/relay/Models.luau` | required in place | new entries only, after their register rows (SPIRE-007) |

Every file under `src/relay*`, `src/night*` and `src/garden*` stays byte-identical except new `Models.luau` entries in SPIRE-007.

### File ownership by task

SPIRE-004, SPIRE-005 and SPIRE-006 run in parallel and write disjoint files. A task changes only its own files; anything else it needs goes back to A09.

| Task | Writes (only these) |
|---|---|
| SPIRE-003 (this) | `docs/architecture/spire.md`, `docs/decisions/0009-…`, `spire.project.json`, `build-info/BuildInfo.txt`, `src/spire/.gitkeep`, `src/spire-client/.gitkeep`, `.github/workflows/ci.yml`, `.github/workflows/publish.yml` |
| SPIRE-004 | `src/shared/SpireConfig.luau`, `TowerRules.luau`, `PlazaRules.luau`, `MarketRules.luau`, `SpireEconomy.luau`, `SpireProgress.luau`; `tests/SpireConfig.spec.luau`, `TowerRules.spec.luau`, `PlazaRules.spec.luau`, `MarketRules.spec.luau`, `SpireEconomy.spec.luau`, `SpireProgress.spec.luau`, `SpireBalance.spec.luau`; `tests/run.luau` (`SPECS` entries only) |
| SPIRE-005 | `src/spire/SpireServer.server.luau`, `State.luau`, `Remotes.luau`, `Profiles.luau`, `Lots.luau`, `City.luau`; deletes `src/spire/.gitkeep` |
| SPIRE-006 | `src/spire-client/ClientState.luau`, `Menu.client.luau`, `Hud.client.luau`, `Build.client.luau`, `Lift.client.luau`, and the **greybox** `TowerView.client.luau` and `PlazaView.client.luau`; deletes `src/spire-client/.gitkeep` |
| SPIRE-007 (after 006) | rewrites `TowerView` and `PlazaView` to final quality; creates `City.client.luau`, `Atmos.client.luau`, `Crowd.client.luau`, `Traffic.client.luau`, `Fx.client.luau`; `src/relay/Models.luau` (new entries), `docs/assets/register.md` |
| SPIRE-009 (M4) | flips `SpireConfig.FEATURES.ipo`; IPO screen in `Menu`; skins and crowns in `TowerView` |

SPIRE-005 and SPIRE-006 code against the signatures in section 3 and may stub them locally until SPIRE-004 lands; stubs are never committed under `src/shared`.

## 2. Shape of the system

```
          Request(action, arg) -> (ok, code)                SpireStatus (event, forecast)
 client ─────────────────────────────▶ server router ──▶ pure rules (src/shared) ──▶ in-memory profile
   ▲                                       │                                            │
   │   Lot.State JSON, player attributes   │  Profiles: coalesced UpdateAsync re-apply, │
   └───────────────────────────────────────┴── session lock, 7 s / 60 s / leave / close ┘
   │
   └─ client builds every visual (towers, plazas, crowds, traffic, rain) from replicated state
```

- **Server owns:** profiles, credits, every rule decision, lot assignment, the 1 Hz income tick, the Hot Data schedule, the Market schedule, character teleports (lift, home, Sky Deck), collision slabs, prompts, boards.
- **Client owns (display only):** all decorative geometry and effects, build-mode previews (computed with the same pure modules), camera, UI, audio.
- **Why client-built visuals:** a 30-floor tower with interiors is thousands of parts. Replicating one JSON attribute per lot and building locally lets each client choose its own level of detail, keeps server memory flat, and the server never creates or destroys decorative parts.

## 3. Pure modules (`src/shared`): exact signatures

### 3.0 Conventions

- As `docs/architecture/garden.md` section 2: `--!strict`, no Roblox globals, string requires (`require("./TowerRules")`), functions return new tables and never mutate inputs, `floor(x + 1e-9)` for every floor of a product.
- Times are integer server `os.time()` seconds passed in as `now`; days are `MetaRules.dayOf(now)`; the Market event is passed in as `event` (an id from `SpireConfig.EVENTS`).
- Every change returns `Result = (Profile, boolean, string?)`: the new profile (the input unchanged when refused), accepted, and a refusal code from `SpireConfig.CODES` when refused. A refused change never returns a modified profile.
- Inputs from the network arrive as numbers parsed from digit captures, so every rule re-checks that numbers are integers in range (`n == math.floor(n)`), never trusting the pattern alone.
- Lot space: studs, origin at the lot centre on the ground surface, local −Z points at the Grid Plaza. The server's lot model pivot is the lot frame; clients use `lot:GetPivot()` and never recompute it.
- Dependency graph (no cycles): `SpireConfig → MetaRules` (types only); `MarketRules → Rng, SpireConfig`; `TowerRules → SpireConfig, MarketRules`; `PlazaRules → SpireConfig, MetaRules`; `SpireEconomy → SpireConfig, TowerRules, PlazaRules`; `SpireProgress → MetaRules, Rng, SpireConfig, TowerRules, PlazaRules, MarketRules, SpireEconomy`.
- XP and quest progress are added only by `SpireProgress` (the only module with the MetaRules config). The server and client call `SpireProgress.apply` for every Request action, never the `TowerRules`/`PlazaRules` changes directly.

### 3.1 `SpireConfig` (types and data only)

```luau
export type Dept = {
	id: string, -- data fusion ad synth drone quantum orbital
	name: string, -- "Data Farm"
	module: string, -- "Server Rack"
	income: number, -- ¢/s per module at L1 (0 for fusion)
	draw: number, -- power per module (0 for fusion)
	cost: number, -- L1 module cost
	unlock: number, -- lowest floor number it can go on
	tier: number, -- XP tier: data 1, fusion 1, ad 2, synth 3, drone 4, quantum 5, orbital 6
}
export type PlazaItem = {
	id: string, -- lowercase letters only (Request pattern %l+)
	name: string,
	cost: number,
	hype: number, -- 0 for decor
	w: number, -- cells along x at r = 0
	d: number, -- cells along y at r = 0
	max: number?, -- per-plaza count limit (hype items); nil for decor
	floors: number?, -- hype items: unlocked when #p.floors >= floors
	level: number?, -- decor: unlocked when level >= level
	decor: boolean,
}
export type Event = { id: string, name: string }
export type Odds = { id: string, bp: number } -- basis points, a row sums to 10000
export type ActionSpec = { pattern: string?, profile: boolean } -- pattern nil: takes no arg; profile false: router-only (lift, home)
export type Company = { p: number, s: number, glyph: number, colour: number, trim: number } -- 1-based: NAMES.prefixes, NAMES.suffixes, glyph 1..GLYPHS, COLOURS (logo), COLOURS (trim)

export type Floor = { d: string, m: { number }, s: { number } } -- dept id; 4 slot levels 0..5 (0 empty); 4 credits spent per slot
export type Item = { u: number, id: string, x: number, y: number, r: number, paid: number }
export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number, -- credits (¢); named coins because MetaRules pays rewards into `coins`
	lifetimeEarned: number,
	runEarned: number,
	lastSeen: number,
	floors: { Floor }, -- floors[1] is always { d = "lobby", m = {0,0,0,0}, s = {0,0,0,0} }
	plaza: { nextUid: number, items: { Item } },
	shares: number,
	ipos: number,
	hotCaught: number,
	endorsements: number, -- received
	bestFloors: number, -- highest #floors ever (stats panel "best tower height")
	gate: string,
	company: Company,
	skin: string, -- cosmetic slots (MetaRules reads them at the top level)
	crown: string,
	lobby: string,
	tiles: string,
	trail: string,
	owned: { [string]: boolean },
	endorsed: { day: number, ids: { number } }, -- given today
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}
export type PublicFloor = { d: string, m: { number } }
export type PublicItem = { u: number, id: string, x: number, y: number, r: number }
export type TowerState = { -- the lot's State attribute (JSON); everything every client may see
	floors: { PublicFloor },
	items: { PublicItem },
	company: Company,
	skin: string,
	crown: string,
	lobby: string,
	tiles: string,
	trail: string,
	gate: string,
	hype: number,
	endorsements: number,
	shares: number,
	level: number,
}

SpireConfig.SCHEMA_VERSION = 1
SpireConfig.LOBBY = "lobby"
SpireConfig.MAX_FLOORS = 30
SpireConfig.SLOTS = 4
SpireConfig.START = { coins = 100, floors = 2 } -- lobby + an empty Data Farm floor
SpireConfig.MAX_COINS = 1e15
SpireConfig.MAX_EARNED = 1e18 -- lifetimeEarned and runEarned
SpireConfig.DEPTS: { Dept } -- GDD C3, in this order: data, fusion, ad, synth, drone, quantum, orbital
SpireConfig.FLOOR_COST: { [number]: number } -- GDD C2, keys 3..30: [3] = 129 ... [30] = 122_000_000_000
SpireConfig.LV = { 1, 2, 4, 8, 16 }
SpireConfig.UP = { 2, 5, 12, 30 }
SpireConfig.FUSION_SUPPLY = { 8, 18, 32, 50, 75 }
SpireConfig.BASE_SUPPLY = 6
SpireConfig.AD = { boost = 0.25, neon = 0.5 } -- per active neighbour; neon during Neon Night
SpireConfig.REFUND = 0.5
SpireConfig.PLAZA = { w = 12, d = 8, cell = 4, walkway = { 5, 6 }, maxItems = 60, maxDecor = 20 }
SpireConfig.HYPE = { perFloor = 10, cap = 200, crowdBase = 2, crowdPer = 5, crowdMax = 40 }
SpireConfig.ITEMS: { PlazaItem } -- GDD D2 hype items in table order, then the 8 decor items (decision 0009)
SpireConfig.SHARES = { per = 0.10, max = 500, minFloors = 20, divisor = 10_000_000 }
SpireConfig.HOT = { minGap = 60, maxGap = 120, life = 45, seconds = 30, xp = 5, range = 12 }
SpireConfig.OFFLINE = { rate = 0.5, cap = 28_800 }
SpireConfig.MARKET = { window = 600, active = 300, seed = 7077, sale = 0.75 }
SpireConfig.EVENTS: { Event } -- normal "Normal", boom "Data Boom", neon "Neon Night", sale "Flash Sale"
SpireConfig.EVENT_ODDS: { weekday: { Odds }, weekend: { Odds } } -- GDD F, rows in EVENTS order
SpireConfig.NAMES: { prefixes: { string }, suffixes: { string } } -- GDD G, 24 and 16, in GDD order
SpireConfig.GLYPHS = 12 -- glyph count; shapes are drawn by the client
SpireConfig.COLOURS: { { number } } -- 8 RGB 0-255: the six art bible accents in table order, then Coral, Ice
SpireConfig.GATES = { "open", "friends", "closed" }
SpireConfig.ENDORSE = { perDay = 30 }
SpireConfig.XP = { module = 2, upgrade = 2, floor = 10, plaza = 5, hot = 5, endorse = 3, endorseCap = 10 } -- upgrade x new level; floor x dept tier; endorse XP for the first 10 a day
SpireConfig.COSMETICS: { MetaRules.Cosmetic } -- decision 0009 table; slots skin crown lobby tiles trail
SpireConfig.SLOT_DEFAULTS = { skin = "glass", crown = "antenna", lobby = "marble", tiles = "grid", trail = "none" }
SpireConfig.SHARE_UNLOCKS: { [string]: number } -- cosmetic id -> Shares needed (MetaRules has no Shares field)
SpireConfig.QUESTS: { MetaRules.Quest } -- decision 0009 table, with reward (base) and minutes
SpireConfig.DAILY = { 100, 150, 200, 250, 300, 400, 800 }
SpireConfig.DAILY_MINUTES = { 2, 3, 4, 5, 6, 8, 15 }
SpireConfig.WEEKLY = { days = 5, reward = 1000, minutes = 30 }
SpireConfig.MILESTONES = { 10, 20, 30 } -- floors announced on the ticker
SpireConfig.BUCKET = { size = 6, rate = 4 } -- Request token bucket: capacity, tokens per second
SpireConfig.MAX_ARG = 40
SpireConfig.FEATURES = { ipo = false } -- SPIRE-009 sets true (M4)
SpireConfig.ACTIONS: { [string]: ActionSpec } -- section 6.1
SpireConfig.CODES: { string } -- every refusal code, section 6.2

SpireConfig.dept(id: string): Dept? -- nil for unknown ids and for "lobby"
SpireConfig.item(id: string): PlazaItem?
SpireConfig.companyName(c: Company): string -- "Volt Robotics"
```

The three lookup helpers are the only functions.

### 3.2 `MarketRules`

```luau
export type Window = { window: number, kind: string, startsAt: number } -- startsAt = window * 600

MarketRules.weekday(unix: number): number -- (floor(unix / 86400) + 3) % 7, Monday 0
MarketRules.isWeekend(unix: number): boolean -- weekday 5 or 6
MarketRules.window(unix: number): number -- floor(unix / 600)
MarketRules.eventFor(window: number): string -- Rng.int(Rng.seed(window, 7077), 1, 10000) against the weekday or weekend row (weekday of window * 600); may be "normal"
MarketRules.eventAt(unix: number): string -- eventFor(window) while unix - startsAt < 300, else "normal"
MarketRules.eventLeft(unix: number): number -- t = unix - startsAt; 300 - t while a non-normal event is active, else 600 - t
MarketRules.forecast(unix: number, n: number): { Window } -- the current window and the next n - 1
MarketRules.price(base: number, event: string): number -- floor(base * 0.75 + 1e-9) when event == "sale", else base
```

### 3.3 `TowerRules`

```luau
type Profile = SpireConfig.Profile
export type Vec3 = { x: number, y: number, z: number }
export type Result = (Profile, boolean, string?)

TowerRules.copy(p: Profile): Profile -- deep copy, used by every change in the Spire modules

-- costs
TowerRules.floorCost(n: number): number? -- FLOOR_COST[n]; nil unless 3 <= n <= 30
TowerRules.moduleCost(dept: string, level: number, event: string): number? -- price to reach `level`: 1 = buy (cost), 2..5 = upgrade (cost * UP[level - 1]); MarketRules.price applied; nil for unknown dept or level outside 1..5
TowerRules.spentMax(dept: string, level: number): number -- cost * (1 + UP[1] + ... + UP[level - 1]), no discount; 0 at level 0

-- power and stacking
TowerRules.supply(p: Profile): number -- 6 + sum FUSION_SUPPLY[level] over fusion modules
TowerRules.draw(p: Profile): number -- sum dept.draw over non-fusion modules (any level)
TowerRules.moduleCount(p: Profile, n: number): number -- filled slots on floor n (0 for the lobby or out of range)
TowerRules.activeAd(p: Profile, n: number): boolean -- floor n is "ad" with >= 1 module
TowerRules.floorMult(p: Profile, n: number, event: string): number -- 1 for lobby, ad, fusion; else 1 + k * (active ad floors among n - 1, n + 1), k = 0.5 when event == "neon" else 0.25
TowerRules.deptAllowed(dept: string, n: number): boolean -- dept known (not lobby), 2 <= n <= 30, n >= dept.unlock
TowerRules.hotSlots(p: Profile): { { floor: number, slot: number } } -- every filled non-fusion slot, floor then slot order

-- changes (GDD C2, C4, C5); refusal codes in brackets, checked in this order
TowerRules.buyFloor(p: Profile, dept: string): Result -- [max] #floors = 30, [unknown] dept, [locked] not deptAllowed(dept, #floors + 1), [credits]; appends { d = dept, m = {0,0,0,0}, s = {0,0,0,0} }
TowerRules.refitFloor(p: Profile, n: number, dept: string): Result -- [floor] n not an owned floor 2..#floors, [unknown], [same] dept == current, [locked], [modules] floor has modules; free
TowerRules.buyModule(p: Profile, n: number, slot: number, event: string): Result -- [floor] n not an owned floor 2..#floors or slot not 1..4, [occupied], [credits], [power] dept.draw > 0 and draw + dept.draw > supply; level 1, s = price paid
TowerRules.upgradeModule(p: Profile, n: number, slot: number, event: string): Result -- [floor], [empty], [max] level 5, [credits]; s += price paid; no power check
TowerRules.sellModule(p: Profile, n: number, slot: number): Result -- [floor], [empty], [needed] fusion and draw > supply after; coins += floor(0.5 * s + 1e-9); level and s to 0

-- layout (lot space)
TowerRules.LOBBY_HEIGHT = 20
TowerRules.FLOOR_HEIGHT = 14
TowerRules.TOWER = { x = 0, z = 22, size = 36 } -- footprint centre and side: x -18..18, z 4..40
TowerRules.LIFT = { radius = 4, height = 10 }
TowerRules.floorY(n: number): number -- floor surface: 0 for n = 1, 20 + 14 * (n - 2) for n >= 2; n = #floors + 1 is the roof (floorY(31) = 426)
TowerRules.slotOffset(slot: number): Vec3 -- y = 0; 1 (-10, 0, 12), 2 (10, 0, 12), 3 (-10, 0, 32), 4 (10, 0, 32)
TowerRules.slotPos(n: number, slot: number): Vec3 -- slotOffset + (0, floorY(n), 0)
TowerRules.liftZone(n: number): (Vec3, number, number) -- centre (0, floorY(n), 22), radius 4, height 10
TowerRules.liftAt(p: Profile, pos: Vec3): number? -- the n in 1..#floors + 1 with horizontal distance to (0, 22) <= 4 and 0 <= pos.y - floorY(n) <= 10
TowerRules.liftTarget(p: Profile, arg: string): number? -- tonumber(arg) in 1..#floors, or #floors + 1 for "roof"; else nil
TowerRules.standAt(n: number): Vec3 -- where a teleport puts the root: (0, floorY(n) + 3, 15), in front of the lift
```

### 3.4 `PlazaRules`

```luau
type Profile = SpireConfig.Profile
type Item = SpireConfig.Item
type Result = TowerRules.Result

PlazaRules.footprint(id: string, r: number): (number, number) -- (w, d), swapped when r is odd; (0, 0) for an unknown id
PlazaRules.cells(id: string, x: number, y: number, r: number): { number } -- covered cell keys x + 12 * y; (x, y) is the min-x, min-y corner
PlazaRules.check(p: Profile, id: string, x: number, y: number, r: number, ignoreUid: number?): string? -- nil when it fits; [unknown] id; [bounds] non-integer, r outside 0..3 or any cell outside x 0..11, y 0..7; [walkway] any cell in columns 5 or 6; [occupied] any cell covered by another item (except ignoreUid)
PlazaRules.unlocked(p: Profile, id: string): boolean -- hype item: #floors >= floors; decor: MetaRules.levelFor(xp) >= level
PlazaRules.find(p: Profile, uid: number): Item?
PlazaRules.counts(p: Profile): ({ [string]: number }, number, number) -- per id, total items, decor items

PlazaRules.placeItem(p: Profile, id: string, x: number, y: number, r: number): Result -- [unknown], [locked], [max] count(id) >= max, [full] 60 items or decor at 20, check codes, [credits]; u = nextUid, nextUid += 1, paid = cost (no Flash Sale on plaza items)
PlazaRules.moveItem(p: Profile, uid: number, x: number, y: number, r: number): Result -- [unknown] uid, [same] same x, y, r, check(..., uid) codes; free
PlazaRules.sellItem(p: Profile, uid: number): Result -- [unknown]; coins += floor(0.5 * paid + 1e-9)

PlazaRules.rawHype(p: Profile): number -- sum of item hype
PlazaRules.hypeCap(p: Profile): number -- min(10 * #floors, 200)
PlazaRules.hype(p: Profile): number -- min(rawHype, hypeCap)
PlazaRules.hypeMult(p: Profile): number -- 1 + hype / 100
PlazaRules.crowd(hype: number): number -- min(40, 2 + floor(hype / 5))

PlazaRules.cellCentre(x: number, y: number): TowerRules.Vec3 -- lot space (-22 + 4x, 0, -16 - 4y); y = 0 is the row nearest the tower
PlazaRules.itemCentre(id: string, x: number, y: number, r: number): TowerRules.Vec3 -- centre of the footprint
PlazaRules.cellAt(pos: TowerRules.Vec3): (number?, number?) -- the cell under a lot-space point; nil outside the grid
```

### 3.5 `SpireEconomy`

```luau
type Profile = SpireConfig.Profile

SpireEconomy.moduleIncome(dept: string, level: number, event: string): number -- income * LV[level] * (2 for data and quantum when event == "boom", else 1); 0 for level 0 or fusion
SpireEconomy.floorIncome(p: Profile, n: number, event: string): number -- sum moduleIncome on floor n * TowerRules.floorMult
SpireEconomy.shareMult(p: Profile): number -- 1 + 0.10 * shares
SpireEconomy.income(p: Profile, event: string): number -- E1: sum floorIncome * hypeMult * shareMult (not floored)
SpireEconomy.tick(income: number, carry: number, dt: number): (number, number) -- total = carry + income * dt; whole = floor(total + 1e-9); returns whole, max(0, total - whole)
SpireEconomy.offline(p: Profile, now: number): number -- floor(income(p, "normal") * 0.5 * min(max(0, now - lastSeen), 28800) + 1e-9)
SpireEconomy.hotBonus(p: Profile, event: string): number -- floor(30 * income(p, event) + 1e-9)
SpireEconomy.ipoShares(p: Profile): number -- floor(sqrt(runEarned / 1e7) + 1e-9), before the 500 cap
SpireEconomy.worth(p: Profile): number -- coins + sum floor(0.5 * s) over modules + sum floor(0.5 * paid) over items
SpireEconomy.timeToAfford(coins: number, income: number, cost: number): number? -- 0 if coins >= cost; nil if income <= 0; else ceil((cost - coins) / income)
SpireEconomy.short(n: number): string -- "999", "1.2K", "3.4M", "5.6B", "7.8T", "9.1Qa", "1Qi"; one decimal truncated, ".0" dropped (as GardenRules.short)
```

### 3.6 `SpireProgress`

```luau
type Profile = SpireConfig.Profile
type Result = TowerRules.Result
export type Bucket = { tokens: number, at: number } -- at = os.clock() of the last take

SpireProgress.SCHEMA_VERSION = 1
SpireProgress.CONFIG: MetaRules.Config<Profile> -- COSMETICS, slots = SLOT_DEFAULTS, QUESTS, DAILY, DAILY_MINUTES, WEEKLY, maxCoins 1e15, scale = scaled
SpireProgress.LOCK_STALE = 120

-- profile
SpireProgress.company(seed: number): SpireConfig.Company -- 5 Rng.int draws from Rng.seed(seed, 4077): p 1..24, s 1..16, glyph 1..12, colour 1..8, trim 1..8
SpireProgress.defaults(now: number, seed: number?): Profile -- 100 credits, floors { lobby, empty data }, company(seed or 0), gate "open", slot defaults, lastSeen now
SpireProgress.sanitize(record: any, now: number?, seed: number?): Profile -- decision 0009 rules; game fields before MetaRules.sanitizeMeta, then Shares-locked slots reset to defaults; drops `lock`; seed only names a record with no valid company
SpireProgress.scaled(p: Profile, base: number, minutes: number): number -- max(base, floor(income(p, "normal") * 60 * minutes + 1e-9))
SpireProgress.publicState(p: Profile): SpireConfig.TowerState
SpireProgress.levelFor(xp: number): number
SpireProgress.questsFor(today: number): { MetaRules.Quest }
SpireProgress.isUnlocked(p: Profile, id: string): boolean -- MetaRules.isUnlocked and shares >= (SHARE_UNLOCKS[id] or 0)

-- session lock (as GardenProgress; the stored record carries lock = { session, at })
SpireProgress.canClaim(record: any, session: string, now: number): boolean
SpireProgress.holds(record: any, session: string): boolean
SpireProgress.locked(p: Profile, session: string?, now: number): any

-- server-only ops (fixed inputs, re-applied on the stored record)
SpireProgress.login(p: Profile, now: number): (Profile, number) -- sanitize; offline paid through earn(seconds 0); lastSeen = now; MetaRules.login(today); returns offline
SpireProgress.snapshot(p: Profile, now: number): Profile -- lastSeen = now; the last op of every flush
SpireProgress.earn(p: Profile, credits: number, seconds: number, today: number): Profile -- coins += credits (cap 1e15); lifetimeEarned and runEarned += credits (cap 1e18); quest stat earnSeconds += seconds
SpireProgress.grabHot(p: Profile, amount: number, today: number): Profile -- earn(amount, 30); hotCaught += 1; XP 5; quest stat hot += 1
SpireProgress.receiveEndorse(p: Profile): Profile -- endorsements += 1
SpireProgress.gateAllows(gate: string, isFriend: boolean): boolean -- open true, friends isFriend, closed false (owners are checked separately)

-- the Request contract (server router and client previews call the same functions)
SpireProgress.check(action: string, arg: string?): string? -- nil when ok; [action] not in ACTIONS; [arg] arg given to a no-arg action, missing for an arg action, or no pattern match
SpireProgress.parse(action: string, arg: string?): { any }? -- the pattern captures, digit-only captures as numbers; {} for no-arg actions; nil when check fails
SpireProgress.apply(p: Profile, action: string, arg: string?, now: number, event: string): Result -- every ACTIONS entry with profile = true (6.1): parse, run the rule, add XP and quest stats; [action] for lift and home
SpireProgress.take(b: Bucket, clock: number): (Bucket, boolean) -- tokens = min(6, tokens + 4 * max(0, clock - at)), at = clock; if tokens >= 1 then tokens -= 1 and true, else false
SpireProgress.ipo(p: Profile, now: number): Result -- [locked] FEATURES.ipo false, [ipo] #floors < 20 or ipoShares < 1; shares = min(500, shares + gained), ipos += 1, coins 100, floors reset to defaults, runEarned 0; everything else kept
```

What `apply` adds around each rule (stats count accepted actions only):

| Action | Rule | XP | Quest stats |
|---|---|---|---|
| `buyFloor` | `TowerRules.buyFloor` | 10 × tier | `floors` +1; `bestFloors = max(bestFloors, #floors)` |
| `refitFloor` | `refitFloor` | – | – |
| `buyModule` | `buyModule(…, event)` | 2 | `modules` +1 |
| `upgradeModule` | `upgradeModule(…, event)` | 2 × new level | `upgrades` +1; `maxed` +1 on reaching level 5 |
| `sellModule` | `sellModule` | – | – |
| `placeItem` | `PlazaRules.placeItem` | 5 if the item has hype | `placed` +1 |
| `moveItem`, `sellItem` | `PlazaRules` | – | – |
| `endorse` | giver side: [done] target already in today's ids, [max] 30 today | 3 while today's count before it is < 10 | `endorse` +1 |
| `setGate` | [unknown] not in GATES, [same] | – | – |
| `setCompany` | [unknown] an index out of range (p 1..24, s 1..16, glyph 1..12, colour and trim 1..8), [same] all equal | – | – |
| `ipo` | `SpireProgress.ipo` | – | – |
| `claimDaily`, `claimWeekly`, `claimQuest` | MetaRules; refused → [claimed] | – | – |
| `buyCosmetic` | [unknown], [owned], [locked] not priced or Shares-locked, [credits] | – | – |
| `equipCosmetic` | [unknown], [locked] (`isUnlocked`), [same] already equipped | – | – |

`endorse` checks "not self" only in the router (the profile does not know its UserId).

### 3.7 Tests beyond GDD R

- `SpireConfig.spec`: `FLOOR_COST` equals C2; the 7 departments and 17 items match C3, D2 and the decor table of decision 0009; every `ACTIONS` pattern compiles; `CODES` entries unique; every slot default is a cosmetic in that slot.
- `TowerRules.spec`: `floorY(1) = 0`, `floorY(30) = 412`, `floorY(31) = 426`; `liftAt` on each boundary; `liftTarget("roof")`.
- `PlazaRules.spec`: a 3 × 3 Idol at every rotation along each edge; `cellAt(cellCentre(x, y))` returns `(x, y)` for all 96 cells.
- `SpireProgress.spec`: `sanitize(defaults(now, s), now) == defaults(now, s)`; `apply` run twice on copies of one profile gives equal results (re-apply safety); `take` never accepts more than `6 + 4t` over `t` seconds; `parse` rejects `"3:5"`, `"x:1"`, `"1:1:1"` for `buyModule` and any 41-character arg; `login`, `snapshot`, `login` after 0 s pays 0 offline.
- `SpireEconomy.spec`: `worth` never rises over 10,000 seeded buy/upgrade/sell/place/move/sell sequences, including Flash Sale prices.

## 4. Server (`src/spire`)

### 4.1 Files

| File | Kind | Owns |
|---|---|---|
| `SpireServer.server.luau` | Script | Entry: prints `[Spire] build <stamp>` first (section 9); warns if `Players.MaxPlayers > 6`; lot assignment on join (`Lots.assign`; if none is free, `notice` every 10 s and retry every second); character spawn and respawn at `standAt(1)` of its lot; `Request` router (4.3); prompt handlers (4.4); the Heartbeat loop (4.5); ticker; leave and `BindToClose`. |
| `State.luau` | Module | `State.live: { [Player]: Live }`, the only mutable live state. |
| `Remotes.luau` | Module | Copied from Garden: creates `ReplicatedStorage.SpireRemotes` (`Request`, `Fx`) and `ReplicatedStorage.SpireStatus`; `fx(kind, data)` = `Fx:FireAllClients`; `notice(player, text)` = `Fx:FireClient(player, "notice", { text = text })`. |
| `Profiles.luau` | Module | Copied from Garden (4.2). |
| `Lots.luau` | Module | The 6 lot shells (4.6) and their prompts, collision slabs and `State` attribute writes. ≤ 60 parts per lot plus 1 per floor. |
| `City.luau` | Module | Grid Plaza and street collision (≤ 1,500 parts), Top Spires and Market boards (SurfaceGui). No decoration. |

```luau
-- State.luau
export type Hot = { floor: number, slot: number, ends: number } -- ends = os.time() when it expires
export type Live = {
	lot: number,
	carry: number, -- income fraction (SpireEconomy.tick)
	bucket: SpireProgress.Bucket,
	hot: Hot?,
	nextHot: number, -- os.time() of the next spark
	friends: { [number]: boolean }, -- IsFriendsWith cache by UserId
	boardEarned: number, -- last value written to SpireBoard
	boardAt: number,
}
State.live: { [Player]: Live }

-- Profiles.luau
Profiles.Changed: RBXScriptSignal -- (player, profile)
Profiles.load(player: Player) -- blocks; claims the lock (3 tries), else offline + notice; a new record is named from a server Random seed; runs login; sets OfflineCredits
Profiles.get(player: Player): SpireConfig.Profile?
Profiles.isOnline(player: Player): boolean -- has the store and holds the lock
Profiles.apply(player: Player, label: string, change: (SpireConfig.Profile) -> SpireConfig.Profile) -- in memory now, queued (makes a 7 s flush due), published
Profiles.earn(player: Player, credits: number, seconds: number, today: number) -- in memory now; merged into the last queued op if it is this day's earn op; does not make a 7 s flush due; sets only Credits
Profiles.request(player: Player, action: string, arg: string?, event: string): (boolean, string?) -- [busy] no session or closing; SpireProgress.apply on the in-memory profile; if accepted, applies the same call with the same now and event
Profiles.step(now: number) -- 1 Hz: publish dirty sessions, flush due queues, board writes
Profiles.finish(player: Player, now: number) -- leave op (snapshot), waits <= 10 s for a running write, final flush releasing the lock (<= 25 s), drops the session
Profiles.finishAll(now: number) -- BindToClose, all sessions in parallel
Profiles.topEarned(): { { name: string, earned: number } } -- top 10 of SpireBoard

-- Lots.luau
Lots.COUNT = 6
Lots.assign(player: Player): number? -- lowest free lot; sets Owner
Lots.free(lot: number) -- moves visitors off the tower (Grid Plaza + notice), Owner = 0, State = "", slabs and Hot removed
Lots.model(lot: number): Model
Lots.toLot(lot: number, pos: Vector3): TowerRules.Vec3 -- pivot:PointToObjectSpace
Lots.toWorld(lot: number, v: TowerRules.Vec3): Vector3
Lots.setState(lot: number, state: SpireConfig.TowerState) -- marks the lot dirty
Lots.flush() -- 4 Hz from the loop: writes each dirty lot's State JSON once (latest wins) and syncs its slabs
Lots.setHot(lot: number, hot: State.Hot?) -- Hot part to slotPos + (0, 3, 0) with Grab enabled, or disabled
Lots.prompts: RBXScriptSignal -- (player: Player, lot: number, kind: "grab" | "skydeck")

-- City.luau
City.build(): { board: (rows: { { name: string, earned: number } }) -> (), market: (status: { [string]: any }) -> () }
```

### 4.2 Profiles (copied from Garden)

Same as `src/garden/Profiles.luau` with these differences:

- Stores `SpireProfile<suffix>` and ordered `SpireBoard<suffix>` (suffix `_studio`, `_staging`, or none in `PRODUCTION_UNIVERSE_ID`, which stays nil until SHANNON approves a production release). Key `player_<UserId>`.
- `GardenProgress` → `SpireProgress`. Load transform: `SpireProgress.locked(SpireProgress.sanitize(old, now, seed), session.id, now)` when `canClaim`, with `seed` drawn once from server `Random` before the call.
- Flush transform: cancel unless `holds`; `sanitize(old, now)`, each queued op in order, `snapshot(p, now)`, stored with `locked(…, session.id, now)` (no lock on the final write). On success the stored result becomes the in-memory profile with every op queued since the flush started re-run on it (income credited during the yield sits in a new earn op, so it is kept).
- `Profiles.bank` → `Profiles.earn` (merged op, like `bank`). **A flush is due** when a non-earn op is queued and 7 s have passed since the last write, or when 60 s have passed (autosave). Earn ops ride along with whichever comes first, so an idle tower writes once a minute and a crash loses at most 60 s of income (GDD P).
- `publish` sets `Profile` (JSON), `Credits`, `Floors` (#floors), `Level`, `XP`, `Lot` and leaderstats `Floors` (IntValue), and fires `Changed`; `SpireServer` passes it on as `Lots.setState(lot, SpireProgress.publicState(p))`. `Income` and leaderstats `Income` are set by the loop (they depend on the event).
- Board: in `step`, if `min(floor(lifetimeEarned), 2^53) ~= boardEarned` and 120 s since `boardAt`, `SetAsync` in a spawned thread.
- Keep the `[Profiles] <id> loaded (<n> bytes encoded)` print; SPIRE-005 records a maxed test profile (must be < 12 KB).
- Sessions without the store or the lock run offline (playable, unsaved, `ProfileOnline` false, notice), as Garden.

### 4.3 Request router

`Request.OnServerInvoke = function(player, action, arg)` returns `(ok: boolean, code: string?)`. Checks in this order; each refusal returns at once and changes nothing:

1. `busy`: no loaded session (`Profiles.get` nil) or no `State.live` entry.
2. `type`: `action` not a string, `arg` neither nil nor a string, or `#arg > 40`.
3. `rate`: `SpireProgress.take(live.bucket, os.clock())` is false.
4. `action` / `arg`: `SpireProgress.check(action, arg)`.
5. World checks on server-side positions (`HumanoidRootPart` of the current character):
   - `lift`: `zone` unless the root exists and `TowerRules.liftAt(p, Lots.toLot(lot, root.Position))` is not nil; `arg` unless `liftTarget(p, arg)` is a floor other than that one; then teleport to `Lots.toWorld(lot, standAt(target))` and return `true`.
   - `home`: `zone` without a root; else teleport to `standAt(1)` of the own lot and return `true`.
   - `endorse`: `target` unless the UserId is another player in this server; `gate` unless the target's gate allows the caller (`gateAllows`, `IsFriendsWith` cached in `live.friends`; may yield once). Then step 6, and if accepted `Profiles.apply(target, "endorsed", SpireProgress.receiveEndorse)` and `Fx("endorse", { lot = targetLot })`.
6. `Profiles.request(player, action, arg, MarketRules.eventAt(os.time()))` (decided on the profile current after any yield).
7. On acceptance: `Fx("built", …)` for build actions (6.3); ticker when `buyFloor` reaches a `MILESTONES` floor; clear the Hot Data spark if its slot is no longer filled.

### 4.4 Prompts

Server `ProximityPrompt.Triggered` via `Lots.prompts`, with the same `busy` and `rate` checks (the bucket is shared with `Request`):

- **Grab** (`Hot` part, `MaxActivationDistance` 12): the lot's owner only; `live.hot` set and `os.time() < hot.ends`; the slot still filled; root within 12 studs of `toWorld(slotPos(floor, slot))`. Then `amount = SpireEconomy.hotBonus(p, event)` (fixed once), `Profiles.apply(player, "hot", fn(p) SpireProgress.grabHot(p, amount, today))`, clear the spark, `Fx("grabbed", { lot, amount })`.
- **SkyDeck** (lobby lift pad, `MaxActivationDistance` 12): root within 12 studs; the owner always, others when the gate allows; teleport to `standAt(#floors + 1)` of that lot.
- **Build** (`Terminal`): opens build mode on the client only; the server ignores it.

When an owner sets a gate that disallows a visitor, or leaves, visitors standing on that tower (above `floorY(2)` inside the footprint) are moved to the Grid Plaza with a notice.

### 4.5 Loop

`Heartbeat` accumulates `dt`. At 4 Hz: `Lots.flush()`. Every whole second (`now = os.time()`, `today = MetaRules.dayOf(now)`, `event = MarketRules.eventAt(now)`), iterating a snapshot of `State.live`:

1. Income: `inc = SpireEconomy.income(p, event)`; `whole, live.carry = SpireEconomy.tick(inc, live.carry, 1)`; if `inc > 0`, `Profiles.earn(player, whole, 1, today)`; set `Income` and leaderstats `Income` (`short(floor(inc))`) when changed.
2. Hot Data: expire `live.hot` at `ends` (`Lots.setHot(lot, nil)`). If none is active, `now >= nextHot` and `TowerRules.hotSlots(p)` is not empty: pick one with server `Random`, `hot = { floor, slot, ends = now + 45 }`, `Lots.setHot`, `Fx("hot", { lot, floor, slot, ends })`. When a spark ends or is grabbed, `nextHot = now + Random:NextInteger(60, 120)`.
3. `SpireStatus.Value = JSONEncode({ event, eventLeft, forecast = { kind2, kind3 }, window })` when changed (from `MarketRules.forecast(now, 3)`); `City.market(status)`.
4. `Profiles.step(now)`.
5. Every 60 s: `City.board(Profiles.topEarned())` in a spawned thread.

**PlayerAdded:** `Lots.assign` (or wait), `State.live[player] = { lot, carry = 0, bucket = { tokens = 6, at = os.clock() }, nextHot = now + Random:NextInteger(60, 120), friends = {}, boardEarned = -1, boardAt = 0 }`, `Profiles.load`, spawn at `standAt(1)`. **PlayerRemoving:** drop `State.live`, `Lots.free(lot)` (before the final write, so a waiting player can take it), `Profiles.finish`. **BindToClose:** `Profiles.finishAll`.

### 4.6 Lots and instances

- Lot `n` centre `(150 sin θ, 0, −150 cos θ)`, `θ = (n − 1) × 60°`; frame `CFrame.lookAt(centre, Vector3.zero)` (local −Z faces the Grid Plaza). Lot 64 × 92: x −32..32, z −46..46. Plaza grid x −24..24, z −46..−14; approach z −14..4; tower x −18..18, z 4..40.
- `Workspace.Spire.Lots.Lot<n>` (Model, PrimaryPart `Ground`, pivot = frame; attributes `Owner` (UserId, 0 when free) and `State` (TowerState JSON, `""` when free)). Children: `Ground`, `Approach`, `Lobby` (collision walls with a door gap at z = 4, x −4..4), `Slabs` (`Floor<n>`: invisible 36 × 1 × 36 at `floorY(n) − 0.5`, n = 2..#floors + 1, the last being the roof), `LiftPad` (prompt `SkyDeck`), `Terminal` (prompt `Build`), `Hot` (prompt `Grab`, disabled when no spark), `Sign` (SurfaceGui: company name, owner display name, endorsements).
- `Workspace.Spire.City`: Grid Plaza, streets, boards. Clients put their visuals under a client-only `Workspace.SpireClient` folder.

## 5. Client (`src/spire-client`)

| File | Task | Owns |
|---|---|---|
| `ClientState.luau` | 006 | settings, quality tier, own profile cache, status cache, build-mode state, `request` wrapper, refusal texts (API below) |
| `Menu.client.luau` | 006 | forked start menu (GDD K1) with the build stamp in the bottom-right corner, LOCKER, REWARDS, STATS, SETTINGS, How to Play, company rename (`setCompany`), toasts (`ClientState.Toast`); the IPO screen is added by SPIRE-009 |
| `Hud.client.luau` | 006 | GDD K2: credits count-up, income, power and Hype bars, Market chip, Hot Data toast with GO (`lift` to the spark's floor), BUILD/LIFT/HOME, first-session script (K5; when `xp == 0` at join), "While you were away" (`OfflineCredits` > 0), ticker banner, `notice`; hides the `Grab` prompt locally on lots it does not own |
| `Build.client.luau` | 006 | build mode (K3): tower camera, floor cards, department picker, plaza grid with ghost and rotation, touch/mouse/gamepad; every preview and disabled reason from `SpireProgress.apply` on a copy of the own profile, with `now = floor(workspace:GetServerTimeNow())` and the `SpireStatus` event |
| `Lift.client.luau` | 006 | lift UI and transition (K4); sends `lift` |
| `TowerView.client.luau` | 006 greybox, 007 final | each lot's tower from `State` (diff per floor), construction effects; reads `ClientState.focusFloor` |
| `PlazaView.client.luau` | 006 greybox, 007 final | plaza items from `State` |
| `City.client.luau`, `Atmos.client.luau`, `Crowd.client.luau`, `Traffic.client.luau` | 007 | backdrop, lighting and rain, crowds (`PlazaRules.crowd`), traffic |
| `Fx.client.luau` | 007 | juice and SFX for `built`, `hot`, `grabbed`, `endorse`, `ipo`, `ticker` |

```luau
-- ClientState.luau (SPIRE-006; read by the SPIRE-007 files)
export type Settings = { music: boolean, sfx: boolean, reduceFlashing: boolean, rain: string, shake: boolean, announcements: boolean } -- rain "low" | "med" | "high"
ClientState.settings: Settings
ClientState.SettingsChanged: RBXScriptSignal -- ()
ClientState.quality: string -- "low" | "med" | "high"; low on touch devices by default; drops a step when the 5 s average frame time > 33 ms
ClientState.QualityChanged: RBXScriptSignal -- ()
ClientState.profile(): SpireConfig.Profile? -- decoded own Profile attribute, cached per change
ClientState.status(): { event: string, eventLeft: number, forecast: { string }, window: number }
ClientState.stamp(): string -- section 9
ClientState.mode: string -- "play" | "tower" | "plaza"
ClientState.focusFloor: number? -- floor highlighted in tower view
ClientState.ModeChanged: RBXScriptSignal -- ()
ClientState.request(action: string, arg: string?): (boolean, string?) -- InvokeServer; on refusal fires Toast with REFUSALS[code]
ClientState.Toast: RBXScriptSignal -- (text: string)
ClientState.REFUSALS: { [string]: string } -- code -> text (6.2)
```

### 5.1 Level of detail

| Distance from camera | Tower | Plaza |
|---|---|---|
| < 120 studs (own tower: current floor ±2) | exterior + interiors | items + crowd animated |
| 120 to 400 | exterior | items, crowd static |
| > 400 | exterior without balconies and signature parts | items hidden, lights only |

Quality tiers: Low halves rain, crowd and traffic counts and turns off interiors except the current floor.

### 5.2 Streaming

`Workspace.StreamingEnabled` stays off in v0.1: the server owns few parts, and client-built content is not streamed anyway. Revisit if phone memory exceeds 800 MB in the M2 look pass (art bible 12).

## 6. Remote contract

### 6.1 `Request` actions

`ReplicatedStorage.SpireRemotes.Request` (RemoteFunction): `Request(action: string, arg: string?) -> (boolean, string?)`. `SpireConfig.ACTIONS`:

| Action | `pattern` (nil = no arg) | `profile` | Captures |
|---|---|---|---|
| `buyFloor` | `^(%l+)$` | true | dept |
| `refitFloor` | `^(%d+):(%l+)$` | true | floor, dept |
| `buyModule`, `upgradeModule`, `sellModule` | `^(%d+):([1-4])$` | true | floor, slot |
| `placeItem` | `^(%l+):(%d+):(%d+):([0-3])$` | true | id, x, y, r |
| `moveItem` | `^(%d+):(%d+):(%d+):([0-3])$` | true | uid, x, y, r |
| `sellItem` | `^(%d+)$` | true | uid |
| `lift` | `^(%w+)$` | false | floor digits or `roof` (`TowerRules.liftTarget`) |
| `home` | nil | false | – |
| `endorse` | `^(%d+)$` | true | UserId |
| `setGate` | `^(%l+)$` | true | gate |
| `setCompany` | `^(%d+):(%d+):(%d+):(%d+):(%d+)$` | true | prefix, suffix, glyph, colour, trim |
| `ipo` | nil | true | – |
| `claimDaily`, `claimWeekly` | nil | true | – |
| `claimQuest`, `buyCosmetic`, `equipCosmetic` | `^([%w_]+)$` | true | id |

### 6.2 Refusal codes (`SpireConfig.CODES`) and toast text

| Code | Where | Text (`ClientState.REFUSALS`) |
|---|---|---|
| `busy` | router, Profiles | Still loading. Try again in a moment. |
| `type`, `action`, `arg` | router, `check` | That did not work. |
| `rate` | router | Slow down a little. |
| `zone` | lift, home | Step onto a lift pad first. |
| `target` | endorse | That company is not here. |
| `gate` | endorse, Sky Deck | This tower is closed to visitors. |
| `credits` | buys | Not enough credits. |
| `power` | buyModule | Not enough power: build or upgrade a Fusion Core. |
| `locked` | dept, item, cosmetic, IPO feature | Not unlocked yet. |
| `floor` | floor or slot not yours | Pick one of your floors. |
| `occupied` | slot, cells | That spot is taken. |
| `empty` | upgrade, sell | That slot is empty. |
| `max` | 30 floors, level 5, item limit, 30 endorsements | Already at the limit. |
| `full` | 60 items, 20 decor | Your plaza is full. |
| `bounds` | cells | That does not fit on the plaza. |
| `walkway` | cells | Keep the walkway clear. |
| `modules` | refit | Sell this floor's modules first. |
| `needed` | sell fusion | Your tower needs that power. |
| `same` | no-op changes | Nothing to change. |
| `unknown` | ids | That does not exist. |
| `claimed` | rewards | Nothing to claim yet. |
| `owned` | buyCosmetic | You already own that. |
| `done` | endorse | Already endorsed today. |
| `ipo` | ipo | Reach floor 20 and earn more first. |

The client may show richer text (Build shows "Need 2 more power" from `TowerRules.draw`/`supply`); the code is the contract.

### 6.3 `Fx` payloads

`SpireRemotes.Fx` (RemoteEvent): `FireAllClients(kind, data)` except `notice` (`FireClient`). The server ignores `Fx.OnServerEvent`. `lot` is 1..6; times are `os.time()` seconds (clients compare with `workspace:GetServerTimeNow()`).

| `kind` | `data` | Sent when | Listened by |
|---|---|---|---|
| `built` | `{ lot, kind: string (the action name), floor: number?, slot: number?, uid: number?, level: number? }` | an accepted build action (buyFloor: the new floor number; upgrade: the new level; placeItem: the new uid) | TowerView, PlazaView, Fx |
| `hot` | `{ lot, floor, slot, ends }` | a spark starts | Hud (owner), TowerView/Fx |
| `grabbed` | `{ lot, amount }` | a spark is grabbed | Hud (owner "+30s"), Fx |
| `ticker` | `{ company: string, text: string }` | floor 10, 20 or 30, or an IPO; e.g. `text = "reached floor 20!"` | Hud (setting), Fx |
| `endorse` | `{ lot }` | an endorsement lands | Fx, TowerView sign |
| `ipo` | `{ lot }` | an IPO (M4) | Fx, TowerView |
| `notice` | `{ text }` | to one player: offline saving, waiting for a lot, moved off a tower | Hud |

### 6.4 Replicated state

- `ReplicatedStorage.SpireStatus` (StringValue, JSON, written when changed): `{ event: string, eventLeft: number, forecast: { string, string }, window: number }`.
- `ReplicatedStorage.BuildInfo` (StringValue): the build stamp.
- Lot model attributes: `Owner` (number), `State` (TowerState JSON or `""`; at most 4 writes a second per lot, about 4 KB at most).
- Player attributes (server-set only): `Profile` (JSON), `ProfileOnline` (boolean), `Credits`, `Income`, `Floors`, `Level`, `XP`, `Lot`, `OfflineCredits` (numbers). Leaderstats: `Floors` (IntValue), `Income` (StringValue, short format).

The client never sends amounts, prices, levels to buy, positions, outcomes or targets beyond the ids and cells above. Flash Sale prices are decided by the server's `event` at acceptance.

## 7. Saves

The contract is decision 0009. Summary: stores `SpireProfile<suffix>` and ordered `SpireBoard<suffix>`; session lock `lock = { session, at }`, stale after 120 s; coalesced writes (a non-earn op + 7 s, or the 60 s autosave), final write on leave and in `BindToClose` releasing the lock; every op re-applied with fixed inputs; failed loads and offline sessions never write.

## 8. Security checklist (for SPIRE-008 QA)

- Every `Request` action and prompt refuses: wrong types, long args, malformed patterns, unknown ids, non-integer or out-of-range floors, slots, cells and indices, other players' lots, spam beyond the bucket, sessions not loaded or closing.
- A refused request returns the input profile unchanged and queues nothing; a bucket refusal takes no token and gives none back.
- No buy/sell sequence raises `SpireEconomy.worth` (property test).
- No client value is trusted for money, prices, levels, positions or outcomes. Teleports only via `lift`, `home` and `SkyDeck`, checked on server positions.
- No `MarketplaceService`, `TextBox`, trading or gifting in Spire code (grep check).
- Loops over `State.live` iterate a snapshot.

## 9. Build, release and the build stamp

- CI builds `build/spire.rbxl` alongside the other places. `publish.yml` offers `spire-staging` and maps `spire-*` to `spire.project.json`. The `spire-staging` environment and its experience are created by a human (rule 7).
- **Build stamp (generic):** `build-info/BuildInfo.txt` is committed with the text `dev`. CI and `publish.yml` overwrite it with `$GITHUB_SHA` (40 hex characters, no newline) before any `rojo build`. A project that wants the stamp maps the file to `ReplicatedStorage.BuildInfo` (Rojo makes a `.txt` a StringValue); only `spire.project.json` does so now, and another game adopts it by adding the same mapping. Readers use `string.match(BuildInfo.Value, "%S+") or "dev"`.
- **Where it shows:** `SpireServer` prints `[Spire] build <stamp>` (full SHA) first thing at start; the start menu shows the first 7 characters in its bottom-right corner (`ClientState.stamp()`). A local `rojo build` or `rojo serve` shows `dev`. A playtest note only counts when it records the stamp it saw.
- **Publish checklist** (comments in `publish.yml`): set Max Players to 6 for Spire (and Garden) places; after every publish, restart or shut down running servers before joining, then check the stamp.
- **Post-publish check (SPIRE-002, only if SHANNON approves the key scope):** an Open Cloud Luau Execution task against the new version that returns `BuildInfo.Value` and fails the run if it differs from the commit. Not built in SPIRE-003.

## 10. Resolutions (where this file settles or changes the GDD)

1. **Credits are stored as `coins`** and the five cosmetic slots (`skin crown lobby tiles trail`) at the top level of the profile, not in a `cosmetics` table: `MetaRules` (unchanged, shared by three games) pays rewards into `coins` and sanitises slots by top-level name. The UI and attributes still say Credits.
2. **The session lock is `lock = { session, at }`** (Garden's helpers), not GDD N's `session = { id, at }`, so the copied `Profiles` works unchanged.
3. **No absolute credit snapshot.** Income is credited through merged `earn` ops re-applied like every other op; `snapshot` only sets `lastSeen`. An absolute snapshot would lose the income credited while `UpdateAsync` yields, because the stored result replaces the in-memory profile. Earn ops do not make a 7 s flush due, which keeps an idle tower at one write a minute.
4. **`setCompany` takes five indices** (adds `trim`, the brand colour); GDD O listed four, which left the brand colour unsettable.
5. **The Fx field `until` is named `ends`**: `until` is a Luau keyword.
6. **"Earn 1 hour of income" contract** counts `earnSeconds` (1 per online second with income, 30 per Hot Data) with goal 3,600, because MetaRules quests need a fixed goal.
7. **`bestFloors`** is added to the profile for the stats panel's "best tower height" (kept through an IPO).
8. **Shares-unlocked cosmetics** use `SpireConfig.SHARE_UNLOCKS`, checked by `SpireProgress.isUnlocked`, `equipCosmetic`, `buyCosmetic` and `sanitize`; MetaRules has no Shares field.
9. **The floor list is 2 to 30 long** after sanitising (a 1-floor record gets an empty Data Farm), matching defaults and the IPO reset. A department not allowed at its floor number sanitises like an unknown one.
10. **Plaza items keep their place after an IPO** even when their unlock floor is above the new tower; sanitising never drops items for unlocks.
11. **Fusion slots are never Hot Data slots,** and the lobby has no slots.
12. **Visitors are moved to the Grid Plaza** when the owner leaves, or sets a gate that excludes them, while they stand on the tower.
13. **The ordered board stores `floor(lifetimeEarned)` capped at 2^53** (exact integers in Luau numbers) and shows Roblox user names, as Garden.
14. **Offline-mode sessions play unsaved** (as Garden) rather than being refused; they are told and never write.
15. **Decor items, cosmetics, quests, XP and daily rewards** are not fully valued in the GDD; their values are in decision 0009.

## 11. Lessons applied from games 1 to 4

| Lesson (source) | Applied here |
|---|---|
| Money outside the saved balance can be paid twice across a server hop (GARDEN-006 M1) | Income credited directly through earn ops; no unbanked pool; session lock from day one |
| No free plot gave a silent dead session (GARDEN-006 M2) | Lot freed before the final write; waiting notice and retry; Max Players 6 warning |
| Repeated equips wrote to the DataStore every time (NIGHT-006 M2) | No-op requests refused with `same` before queueing; earn ops do not trigger 7 s writes |
| Table modified while iterating crashed the tick (NIGHT-006 M4) | Loops over `State.live` iterate a snapshot |
| No `BindToClose` (NIGHT-006 m7) | `Profiles.finishAll` in `BindToClose` from the first server commit |
| Mesh loads during the tick (NIGHT-006 m8) | Hero props preloaded at start; decorative meshes are client-side |
| `Highlight` cap around 31 (Egg Garden U) | No Highlights for repeated items; Neon and ForceField instead |
| Code-only reviews; Studio playtests never ran (all four games) | A greybox playtest gate (M1) before art, and the build stamp so notes match a commit |
| Staging baseplate (Bake Rush) | Build stamp and the restart-servers checklist line before any Spire publish |
| Duplicate spec keys in `tests/run.luau` (Bake Rush) | One entry per spec; the runner already fails on unregistered specs |
