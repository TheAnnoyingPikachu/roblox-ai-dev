# Egg Garden: architecture (v0.2)

Owner: A09. Inputs: `docs/game-design/game4-gdd.md` (the GDD; section letters below refer to it) and `docs/decisions/0008-egg-garden.md` (save schema, economy, odds, remotes, child safety), amended by `docs/decisions/0012-egg-garden-v02.md` (Celestial Egg, Splash Dash, schema v2). If this file and the GDD disagree on a rule, the GDD wins and this file is fixed; the resolutions in section 8 are the exception (they settle what the GDD leaves open).

## 1. Place, files and who owns them

Rojo project `garden.project.json`:

| Instance | Source |
|---|---|
| `ReplicatedStorage.Shared` | `src/shared` (pure modules, shared with the other games) |
| `ServerScriptService.Garden` | `src/garden` |
| `ServerScriptService.Garden.Models` | `src/relay/Models.luau`, **required in place** |
| `ServerScriptService.Garden.Props` | `src/relay/Props.luau`, **required in place** |
| `StarterPlayer.StarterPlayerScripts.GardenClient` | `src/garden-client` |
| `Workspace.SpawnLocation` | at (0, 0.6, 42), in the plaza south of the cart (fallback; the server moves each character to its plot gate) |

`src/garden` and `src/garden-client` hold a `.gitkeep` so the project builds in CI before the scripts exist; delete it when the first script lands. Never add a `Models.luau` or `Props.luau` to `src/garden` (it would collide with the in-place mapping).

### Reused files

| File | Garden | Notes |
|---|---|---|
| `src/shared/Rng.luau` | required in place, unchanged | hatch, stock and weather rolls |
| `src/shared/MetaRules.luau` | required in place | GARDEN-003 adds the optional fields in section 3.1 (decision 0008); Relay and Night behaviour unchanged |
| `src/shared/ProgressRules.luau`, `NightProgress.luau` | not used | must stay green after the MetaRules change |
| `src/relay/Models.luau` | required in place | GARDEN-004 adds 10 entries (`eggTree`, `bunny`, `frog`, `pup`, `cat`, `owl`, `fox`, `turtle`, `lion`, `dragon`) after their register rows exist; reuses `sakura` for blossom trees. Adding entries does not change Relay or Night. |
| `src/relay/Props.luau` | required in place, unchanged | `part` and `label`; Garden-only builders go in `World.luau` and `Plots.luau` |
| `src/night/Profiles.luau` | **copied** to `src/garden/Profiles.luau` | Same load and re-apply core; new stores, `GardenProgress`, write queue and coalescing (4.2) |
| `src/night/Remotes.luau` | **copied** to `src/garden/Remotes.luau` | `GardenRemotes` (`Request`, `Fx`) and `GardenStatus`; no `Combat` |
| `src/relay-client/Menu.client.luau` | **copied** (forked) to `src/garden-client/Menu.client.luau` | Same look, toasts, gold dot, music player; new panels (section 6) |
| everything else under `src/relay`, `src/relay-client`, `src/night`, `src/night-client` | not used | |

Every file under `src/relay`, `src/relay-client`, `src/night` and `src/night-client` stays byte-identical except the new `Models.luau` entries and the v0.2 changes in section 9.

### File ownership by task

| Task | Writes |
|---|---|
| GARDEN-003 | `src/shared/{GardenConfig,WorldRules,GardenRules,HatchRules,GardenProgress}.luau`, `src/shared/MetaRules.luau` (section 3.1 additions only), `tests/<Module>.spec.luau` for the 5 new modules, `tests/MetaRules.spec.luau` (new cases only), `tests/run.luau` (`SPECS`) |
| GARDEN-004 | `src/garden/*`, `src/relay/Models.luau` (new entries only), `docs/assets/register.md` (mesh, music and SFX rows) |
| GARDEN-005 | `src/garden-client/*` |
| GARDEN-008 | `src/shared/{GardenConfig,GardenRules,HatchRules,GardenProgress,DashRules}.luau`, their specs, `tests/run.luau`, `docs/architecture/README.md` |
| GARDEN-009 | `src/garden/**` (new `Dash.luau`, `DashWorld.luau`), `src/relay/Models.luau` (section 9 only) |
| GARDEN-010 | `src/garden-client/**` (new `DashFx.client.luau`) |
| Artist | `src/shared/GardenAssets.luau` (generated), `tools/blender/garden/**`, `assets/garden/**`, `docs/assets/register.md` rows |

GARDEN-009 and GARDEN-010 code against section 3 and may start with stubs once GARDEN-008's signatures are merged; they share no files.

GARDEN-004 and GARDEN-005 code against the signatures in section 3 and may start with stubs; GARDEN-003 must not change a signature without updating this file in the same PR.

## 2. Conventions for the pure modules

- Same as `docs/architecture/night.md` section 2: `--!strict`, no Roblox globals, requires by string (`require("./GardenRules")`), functions return new tables and never mutate inputs, `floor(x + 1e-9)` for every floor of a product.
- Times are integer server `os.time()` seconds passed in as `now`; days are `MetaRules.dayOf(now)` passed in as `today`. Pad accrual takes `dt` in seconds.
- Positions are `Vec3 = { x: number, y: number, z: number }` (structurally the same as `CombatRules.Vec3`); "horizontal" means the x, z plane.
- Ids are strings as in decisions 0008 and 0012: eggs `starter meadow forest sunset moon star celestial`; species `bunny frog pup cat owl fox turtle lion dragon`; mutations `normal golden moonlit rainbow celestial`; sizes `normal big huge`; weathers `clear sunbeam moonfall shower`; rarities `common uncommon rare epic legendary mythic`; gates `open friends closed`.
- Dependency graph (no cycles): `GardenConfig` (types and data, no requires except `MetaRules` for the `Cosmetic`/`Quest` types); `WorldRules → Rng, GardenConfig`; `GardenRules → GardenConfig, WorldRules, MetaRules`; `HatchRules → Rng, GardenConfig, GardenRules, MetaRules`; `GardenProgress → MetaRules, GardenConfig, GardenRules, HatchRules`; `DashRules → GardenConfig`.
- XP and quest progress: `HatchRules` adds hatch and Index XP itself (GDD N); every other XP and all quest progress is added by the `GardenProgress` wrappers, the only module holding the MetaRules config. The server calls the `GardenProgress` wrapper where one exists, else the `GardenRules` function.

## 3. Pure modules: exact signatures

### 3.1 `MetaRules` additions (decision 0008)

```luau
export type Cosmetic = { ...existing fields..., index: number? } -- unlocked when #profile.index >= index
export type Quest = { ...existing fields..., minutes: number? }
export type Meta = { ...existing fields with wins: number?..., index: { string }? }
export type Config<P> = {
	...existing fields...,
	weekly: { days: number, reward: number, minutes: number? },
	maxCoins: number?, -- default MetaRules.MAX_COINS
	dailyMinutes: { number }?, -- same length as daily
	scale: ((profile: P, base: number, minutes: number) -> number)?,
}

MetaRules.reward<P>(config: Config<P>, profile: P, base: number, minutes: number?): number -- scale or base
```

`sanitizeMeta` clamps coins to `config.maxCoins or MAX_COINS` and writes `wins` only when `into.wins ~= nil`; `claimDaily` pays `reward(config, profile, dailyReward(config, streak), dailyMinutes[streak clamped])`, `claimWeekly` `reward(config, profile, weekly.reward, weekly.minutes)`, `claimQuest` `reward(config, profile, quest.reward, quest.minutes)`, each capped at `maxCoins`. `dailyReward` keeps returning the base. No existing signature changes.

### 3.2 `GardenConfig` (types and data only)

```luau
export type Odds = { id: string, bp: number }
export type Stock = { chance: number, min: number, max: number } -- chance in percent
export type Egg = {
	id: string,
	name: string,
	price: number?, -- nil: not sold (starter)
	grow: number, -- seconds
	level: number, -- unlock level (starter 1)
	stock: Stock?, -- nil: always in stock, unlimited (meadow); unused for starter
	odds: { Odds }, -- species, sums to 10000
	top: string?, -- Lucky Meter species. A sold egg must have top and meter: rollSpecies gives odds[1] without one
	meter: number?,
	xp: number,
	mutation: string?, -- fixed: always this mutation, no draw, weather ignored (celestial)
}
export type Species = { id: string, name: string, rarity: string, rate: number }
export type Mutation = { id: string, name: string, mult: number }
export type Size = { id: string, name: string, mult: number, scale: number, bp: number }
export type Weather = { id: string, name: string, mutation: { Odds } } -- MUTATIONS order without egg-only mutations, sums to 10000

export type Bed = { egg: string, planted: number, ready: number, waters: number, helps: number, lastWater: number }
export type Creature = { id: number, s: string, m: string, z: string, placed: number, fav: boolean } -- placed 0 = storage
export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	lastSeen: number,
	unbanked: number,
	nextId: number,
	bedCount: number,
	penSlots: number,
	beds: { Bed },
	creatures: { Creature },
	pity: { [string]: number },
	index: { string },
	stock: { w: number, bought: { [string]: number } },
	hatches: number,
	waters: number,
	likes: number,
	gate: string,
	fence: string,
	can: string,
	owned: { [string]: boolean },
	helped: { day: number, count: number },
	liked: { day: number, ids: { number } },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
	prizeEggs: { [string]: number }, -- egg id -> count, v2; only counts >= 1
	dash: { day: number, prizes: number, coins: number }, -- v2; day -1 until the first reward
}

GardenConfig.EGGS: { Egg } -- starter, meadow, forest, sunset, moon, star, celestial (always last); the stock index i is position - 1
GardenConfig.SPECIES: { Species } -- E1 order
GardenConfig.RARITIES: { { id: string, name: string, colour: { number } } } -- common..mythic, RGB 0-255
GardenConfig.RARE = 3 -- RARITIES index of "rare": rareHatches counts rarity index >= 3
GardenConfig.MUTATIONS: { Mutation } -- normal 1, golden 3, moonlit 5, rainbow 10, celestial 20
GardenConfig.SIZES: { Size } -- normal 1.0/1.0/8000, big 1.5/1.4/1700, huge 2.5/2.0/300
GardenConfig.WEATHERS: { Weather } -- clear, sunbeam, moonfall, shower
GardenConfig.WEATHER_ODDS = { weekday: { Odds }, weekend: { Odds } } -- F table
GardenConfig.BED_COSTS: { [number]: number } -- [4] = 500 ... [12] = 3_000_000
GardenConfig.BEDS = { start = 3, max = 12 }
GardenConfig.PEN = { start = 6, max = 20, first = 300 } -- slot cost first * 2^(penSlots - 6)
GardenConfig.STORAGE = 60
GardenConfig.WATER = { cooldown = 60, cut = 0.05, owner = 5, helpers = 3, maxCut = 0.4 }
GardenConfig.XP = { index = 50, ownWater = 3, helperWater = 15, helperCap = 20 }
GardenConfig.INDEX_BONUS = 0.02
GardenConfig.INDEX_SIZE = 38 -- count of indexable pairs: 9 * 4 + 2
GardenConfig.OFFLINE = { rate = 0.5, cap = 28_800 }
GardenConfig.RELEASE_SECONDS = 6 -- 0008 amendment 2026-10-26 (was 30)
GardenConfig.PAD = { radius = 4.5, height = 6 }
GardenConfig.RANGE = { cart = 25, bed = 12 }
GardenConfig.RESTOCK = 300
GardenConfig.WEATHER_WINDOW = 600
GardenConfig.WEATHER_ACTIVE = 300
GardenConfig.SEEDS = { stock = 9001, weather = 4242 }
GardenConfig.LIKES = { perDay = 30 }
GardenConfig.MAX_COINS = 1e15
GardenConfig.GATES = { "open", "friends", "closed" }
GardenConfig.COSMETICS: { MetaRules.Cosmetic } -- H4; slot "fence" | "can"; colours chosen by GARDEN-003
GardenConfig.QUESTS: { MetaRules.Quest } -- H5 with reward = base and minutes
GardenConfig.DAILY = { 50, 75, 100, 125, 150, 200, 400 }
GardenConfig.DAILY_MINUTES = { 2, 3, 4, 5, 6, 8, 15 }
GardenConfig.WEEKLY = { days = 5, reward = 500, minutes = 30 }
GardenConfig.PRIZE_STORE = 1_000_000 -- sanitise limit per egg in prizeEggs
GardenConfig.DASH: DashConfig -- below

GardenConfig.egg(id: string): Egg?
GardenConfig.species(id: string): Species?
GardenConfig.mutation(id: string): Mutation?
GardenConfig.size(id: string): Size?
GardenConfig.rarityIndex(speciesId: string): number -- 1..6, 0 if unknown
GardenConfig.fixedBy(mutationId: string): Egg? -- the egg whose `mutation` is this id; nil for weather mutations
GardenConfig.indexable(speciesId: string, mutationId: string): boolean -- both known; for an egg-only mutation, the species is in that egg's odds
```

The lookup helpers are the only functions; the module is otherwise data.

New data (decision 0012, GDD S1 and T):

```luau
-- appended to EGGS:
{ id = "celestial", name = "Celestial Egg", price = 1_000_000_000, grow = 28800, level = 25,
  stock = { chance = 5, min = 1, max = 1 }, odds = odds({ "lion", 8500, "dragon", 1500 }),
  top = "dragon", meter = 10, xp = 1000, mutation = "celestial" }
-- appended to MUTATIONS:
{ id = "celestial", name = "Celestial", mult = 20 }

export type Spot = { x: number, y: number, z: number }
export type Obstacle = {
	kind: string, -- "sweeper" | "ball" | "pendulum" | "platform"
	model: string, -- section 9
	at: Spot, -- sweeper hub; ball and platform path centre; pendulum hinge
	period: number, -- seconds per cycle
	phase: number, -- 0..1, fraction of a cycle
	size: number, -- sweeper arm length; ball or bob radius; platform half width
	reach: number, -- ball and platform travel either side of `at`; pendulum rod length; 0 for a sweeper
	axis: string?, -- "x" | "z": direction of ball, platform and pendulum travel
	lift: number?, -- ball bounce height
	knock: number, -- velocity on a hit; 0 for a platform
}
export type DashConfig = {
	name: string, -- "Splash Dash"
	minPlayers: number, -- 3
	maxPlayers: number, -- 6
	countdown: number, -- 15
	starting: number, -- 5
	limit: number, -- 120
	grace: number, -- 20
	prizeEgg: string, -- "moon"
	prizesPerDay: number, -- 3
	coinsBase: number, -- 100
	coinsMinutes: number, -- 1
	coinsPerDay: number, -- 6
	fellY: number, -- 125
	zone: { radius: number, height: number }, -- 16, 14
	minFinish: number, -- 28, shared over the legs by length
	maxSpeed: number, -- 95
	slack: number, -- 12
	maxStrikes: number, -- 3
	settle: number, -- 1, seconds after a server teleport with no checks: the client's old position can still arrive
	knockMax: number, -- 70
	swing: number, -- 50, pendulum amplitude in degrees
	start: Spot, -- (-120, 140, 300)
	checkpoints: { Spot }, -- (-20,140,300), (100,140,300), (100,140,400), (-20,140,400), (-120,140,400); the last is the finish
	decks: { Deck }, -- { x1, x2, z1, z2 } in course order, built by DashWorld, read by the reach spec
	obstacles: { Obstacle },
}
```

First-pass obstacles (tuned at the greybox gate; not economy values, decision 0012):

| Kind | `at` | `period` | `phase` | `size` | `reach` | `axis` | `lift` | `knock` |
|---|---|---|---|---|---|---|---|---|
| sweeper | (−85, 140, 300) | 6 | 0 | 20 | 0 | | | 45 |
| sweeper | (−45, 140, 300) | 5 | 0.5 | 20 | 0 | | | 45 |
| ball | (10, 140, 300) | 4 | 0 | 5 | 7 | z | 4 | 55 |
| ball | (35, 140, 300) | 4 | 0.25 | 5 | 7 | z | 4 | 55 |
| ball | (60, 140, 300) | 4 | 0.5 | 5 | 7 | z | 4 | 55 |
| ball | (85, 140, 300) | 4 | 0.75 | 5 | 7 | z | 4 | 55 |
| pendulum | (100, 170, 325) | 5 | 0 | 4 | 26 | x | | 65 |
| pendulum | (100, 170, 350) | 5 | 0.33 | 4 | 26 | x | | 65 |
| pendulum | (100, 170, 375) | 5 | 0.66 | 4 | 26 | x | | 65 |
| platform | (76, 140, 400) | 7 | 0 | 6 | 8 | z | | 0 |
| platform | (58, 140, 400) | 7 | 0.5 | 6 | 8 | z | | 0 |
| platform | (40, 140, 400) | 7 | 0 | 6 | 8 | z | | 0 |
| platform | (22, 140, 400) | 7 | 0.5 | 6 | 8 | z | | 0 |
| platform | (4, 140, 400) | 7 | 0 | 6 | 8 | z | | 0 |
| sweeper | (−70, 140, 400) | 5 | 0.25 | 12 | 0 | | | 45 |

### 3.3 `WorldRules`

```luau
export type Window = { window: number, kind: string, startsAt: number } -- startsAt = window * 600

WorldRules.weekday(unix: number): number -- Monday 0 .. Sunday 6
WorldRules.isWeekend(unix: number): boolean -- weekday 5 or 6
WorldRules.weatherWindow(unix: number): number -- floor(unix / 600)
WorldRules.eventFor(window: number): string -- the window's event kind (may be "clear"); weekday from the window start
WorldRules.weatherAt(unix: number): string -- eventFor(window) in the first 300 s, else "clear"
WorldRules.weatherLeft(unix: number): number -- seconds until weatherAt changes (to the next window boundary or the 300 s mark)
WorldRules.forecast(unix: number, n: number): { Window } -- the current window and the next n - 1
WorldRules.stockWindow(unix: number): number -- floor(unix / 300)
WorldRules.restockLeft(unix: number): number -- seconds until the next stock window
WorldRules.stockFor(window: number): { [string]: number } -- forest, sunset, moon, star; 0 when out of stock; meadow absent (unlimited)
```

### 3.4 `GardenRules`

```luau
type Profile = GardenConfig.Profile
type Creature = GardenConfig.Creature
export type Vec3 = { x: number, y: number, z: number }
export type Pads = { [number]: number } -- pad index -> pending coins (float), server memory only

GardenRules.copy(p: Profile): Profile -- deep copy, used by every change here and in HatchRules
GardenRules.level(p: Profile): number -- MetaRules.levelFor(p.xp)
GardenRules.rate(c: Creature): number -- base * mutation * size
GardenRules.indexMult(p: Profile): number -- 1 + 0.02 * #index
GardenRules.income(p: Profile): number -- sum of placed rates * indexMult
GardenRules.offline(p: Profile, now: number): number -- floor(income * 0.5 * min(away, 28800) + 1e-9); 0 if lastSeen >= now
GardenRules.short(n: number): string -- "999", "1.2K", "3.4M", "5.6B", "1.5T"; one decimal truncated, ".0" dropped
GardenRules.releaseValue(c: Creature): number -- floor(rate * RELEASE_SECONDS + 1e-9)

GardenRules.bedState(p: Profile, bed: number, now: number): string -- "locked" (bed > bedCount) | "empty" | "growing" | "ripe"
GardenRules.growFraction(p: Profile, bed: number, now: number): number -- 0..1 from planted to ready; 0 if now < planted
GardenRules.firstEmptyBed(p: Profile): number?
GardenRules.find(p: Profile, id: number): Creature?
GardenRules.freePad(p: Profile): number? -- lowest pad 1..penSlots with no creature
GardenRules.storageCount(p: Profile): number
GardenRules.isFull(p: Profile): boolean -- no free pad and storage at 60

GardenRules.eggUnlocked(p: Profile, egg: string): boolean -- sold and level >= unlock
GardenRules.stockLeft(p: Profile, egg: string, now: number): number -- math.huge for meadow, 0 for unsold or unknown
GardenRules.buyEgg(p: Profile, egg: string, now: number): (Profile, boolean) -- D1 rules except distance
GardenRules.canPlantPrize(p: Profile, egg: string): boolean -- prizeEggs[egg] >= 1, level >= egg.level, an empty bed
GardenRules.plantPrize(p: Profile, egg: string, now: number): (Profile, boolean) -- lowest empty bed; count - 1 (nil at 0); coins and stock unchanged
GardenRules.waterCut(egg: string): number -- floor(0.05 * grow)
GardenRules.canWater(p: Profile, bed: number, now: number, helper: boolean): boolean
GardenRules.water(p: Profile, bed: number, now: number, helper: boolean): (Profile, boolean) -- bed change only, no XP
GardenRules.nextBedCost(p: Profile): number? -- nil at 12
GardenRules.buyBed(p: Profile): (Profile, boolean) -- adds an empty bed
GardenRules.nextPenCost(p: Profile): number? -- nil at 20
GardenRules.buyPenSlot(p: Profile): (Profile, boolean)
GardenRules.place(p: Profile, id: number): (Profile, boolean)
GardenRules.store(p: Profile, id: number): (Profile, boolean)
GardenRules.release(p: Profile, id: number): (Profile, boolean, number) -- coins paid
GardenRules.favourite(p: Profile, id: number): (Profile, boolean)

GardenRules.accrue(p: Profile, pads: Pads, dt: number): Pads -- each placed creature's pad += rate * indexMult * dt
GardenRules.bankPad(pads: Pads, pad: number): (Pads, number) -- floor(pending + 1e-9) out, fraction stays
GardenRules.unbanked(pads: Pads): number -- floor(sum of pending + 1e-9)
GardenRules.onPad(root: Vec3, pad: Vec3): boolean -- horizontal <= 4.5 and |dy| <= 6
GardenRules.within(a: Vec3, b: Vec3, range: number): boolean -- horizontal distance <= range
```

### 3.5 `HatchRules`

```luau
export type Outcome = { egg: string, s: string, m: string, z: string, forced: boolean } -- forced: by the Lucky Meter
export type Result = { creature: GardenConfig.Creature, xp: number, newEntry: boolean }

HatchRules.pick(odds: { GardenConfig.Odds }, r: number): string -- first id whose cumulative bp >= r (r in 1..10000)
HatchRules.rollSpecies(egg: string, pity: number, rng: Rng.State): (string, boolean, Rng.State) -- species, forced; no draw when forced or starter
HatchRules.rollMutation(weather: string, rng: Rng.State): (string, Rng.State)
HatchRules.rollSize(rng: Rng.State): (string, Rng.State)
HatchRules.roll(p: Profile, bed: number, now: number, weather: string, rng: Rng.State): Outcome? -- nil unless the bed is ripe and the garden not full; starter: pup normal normal, no draws; an egg with `mutation` takes it with no mutation draw (draw order species, size)
HatchRules.apply(p: Profile, bed: number, o: Outcome, now: number): (Profile, boolean, Result?) -- re-checks ripe (same egg) and not full; empties the bed; creature id = nextId; lowest free pad else storage; pity; index; hatches + 1; XP egg.xp (+50 if new entry)
HatchRules.hatch(p: Profile, bed: number, now: number, weather: string, rng: Rng.State): (Profile, boolean, Outcome?, Result?) -- roll then apply
HatchRules.nextPity(egg: string, pity: number, species: string): number -- 0 on the top species, else pity + 1
HatchRules.announce(o: Outcome): boolean -- legendary or mythic species, any rainbow, any huge
HatchRules.percent(bp: number): string -- "60.00" (two decimals, for the ODDS panel)
```

### 3.6 `GardenProgress`

```luau
GardenProgress.SCHEMA_VERSION = 2 -- decision 0012
GardenProgress.CONFIG: MetaRules.Config<Profile> -- COSMETICS, slots { fence = "picket", can = "tin" }, QUESTS, DAILY, DAILY_MINUTES, WEEKLY, maxCoins 1e15, scale = scaled

GardenProgress.defaults(now: number): Profile -- decision 0008 defaults, plus prizeEggs {} and dash { day = -1, prizes = 0, coins = 0 } (0012); starter egg ready now + 8
GardenProgress.sanitize(record: any, now: number?): Profile -- H7 and decision 0008; game fields before MetaRules.sanitizeMeta
GardenProgress.scaled(p: Profile, base: number, minutes: number): number -- max(base, floor(income * 60 * minutes + 1e-9))
GardenProgress.login(p: Profile, now: number, today: number): (Profile, number, number) -- pays unbanked then offline; returns offline, unbanked
GardenProgress.snapshot(p: Profile, unbanked: number, now: number): Profile -- last op of every flush
GardenProgress.leave(p: Profile, now: number): Profile -- unbanked = 0, lastSeen = now
GardenProgress.bank(p: Profile, coins: number, pads: number, today: number): Profile -- coins (capped 1e15); collects += pads (the server counts a pad once per visit)
GardenProgress.LOCK_STALE = 120 -- session lock (0008 amendment 2026-10-26)
GardenProgress.canClaim(record: any, session: string, now: number): boolean -- load: no lock, own lock, or |now - at| >= LOCK_STALE
GardenProgress.holds(record: any, session: string): boolean -- write: the stored lock is this session's
GardenProgress.locked(p: Profile, session: string?, now: number): any -- record to store: p with lock { session, at = now }, or no lock (final write); sanitize drops it
GardenProgress.hatch(p: Profile, bed: number, o: HatchRules.Outcome, now: number, today: number): (Profile, boolean, HatchRules.Result?) -- apply + quest stats hatches, rareHatches, mutants
GardenProgress.ownWater(p: Profile, bed: number, now: number, today: number): (Profile, boolean) -- water(helper false) + 3 XP + waters stat and total
GardenProgress.helperWater(p: Profile, today: number): (Profile, number) -- the helper's side: 15 XP under the daily cap of 20, waters stat and total; returns XP paid
GardenProgress.release(p: Profile, id: number, today: number): (Profile, boolean, number) -- GardenRules.release + releases stat
GardenProgress.like(p: Profile, target: number, liker: number, today: number): (Profile, boolean) -- the liker's side: not self, once per target per day, 30 per day
GardenProgress.receiveLike(p: Profile): Profile -- likes + 1
GardenProgress.setGate(p: Profile, gate: string): (Profile, boolean)
GardenProgress.gateAllows(gate: string, isFriend: boolean): boolean -- open: true; friends: isFriend; closed: false (owners are checked separately)
GardenProgress.dashPrizesToday(p: Profile, today: number): number -- 0 when dash.day ~= today
GardenProgress.dashEligible(p: Profile, today: number): boolean -- prizes today < DASH.prizesPerDay
GardenProgress.dashPrize(p: Profile, today: number): (Profile, boolean) -- prizeEggs[DASH.prizeEgg] + 1, prizes + 1; refused at the cap; resets the counters on a new day
GardenProgress.dashCoins(p: Profile, today: number): (Profile, number) -- scaled(p, coinsBase, coinsMinutes), capped at MAX_COINS, coins counter + 1; 0 paid at the cap
GardenProgress.levelFor(xp: number): number
GardenProgress.questsFor(today: number): { MetaRules.Quest }
GardenProgress.isUnlocked(p: Profile, id: string): boolean
GardenProgress.claimDaily(p: Profile, today: number): (Profile, boolean, number)
GardenProgress.claimWeekly(p: Profile, today: number): (Profile, boolean, number)
GardenProgress.claimQuest(p: Profile, today: number, questId: string): (Profile, boolean, number)
GardenProgress.buyCosmetic(p: Profile, id: string): (Profile, boolean)
GardenProgress.equipCosmetic(p: Profile, id: string): (Profile, boolean)
```

Quest stat keys: `hatches`, `waters`, `collects`, `rareHatches`, `mutants`, `releases`.

### 3.7 Tests (GDD N), beyond the GDD's list

- `MetaRules.spec`: `index` unlock; `reward` without `scale` returns the base; `maxCoins` respected; a profile without `wins` sanitises without gaining one.
- `GardenProgress.spec`: `sanitize(defaults(now))` equals `defaults(now)`; `login` pays unbanked before offline and never twice; `snapshot` then `login` after 0 s pays exactly `unbanked`.
- `HatchRules.spec`: `apply` re-applied to a copy of the original profile gives the same creature (no re-roll); `apply` refuses when the bed's egg differs from the outcome's.
- v0.2, `GardenConfig.spec`: weather ids equal `MUTATIONS` without egg-only mutations; `INDEX_SIZE` equals the count of `indexable` pairs; every sold egg has `top` and `meter`; `celestial` is last in `EGGS`; existing stock unchanged for a fixed window.
- v0.2, `HatchRules.spec`: a Celestial hatch is always `celestial` in all 4 weathers and only lion or dragon; `pity = 9` forces a dragon; no weather roll ever gives `celestial` (walk `r` 1..10000 in every table).
- v0.2, `GardenRules.spec`: the 60% test uses `egg.mutation` when set and checks 24 pairs; `plantPrize` refusals (no egg, level, no bed), lowest bed, count down, coins and stock unchanged.
- v0.2, `GardenProgress.spec`: a literal v1 record loads with every field kept and `prizeEggs = {}`; `prizeEggs` and `dash` survive `sanitize` (the flush path); `bunny:celestial` is dropped from `index` and `creatures`; caps and day rollover; re-applying `dashPrize` to a copy of the stored record gives the same result.

### 3.8 `DashRules` (new)

Pure Splash Dash rules (GDD T). Same conventions as section 2, except that `t` is a float `workspace:GetServerTimeNow()` time passed in by the server, because finish times need better than 1 s. Used by the server for the round and by the client for obstacle poses and hit tests.

```luau
export type Vec3 = { x: number, y: number, z: number }
export type Phase = "idle" | "countdown" | "starting" | "racing"
export type Entrant = { id: number, eligible: boolean } -- id: UserId
export type Racer = {
	next: number, -- index in DASH.checkpoints of the checkpoint to reach next
	eligible: boolean, -- may take the egg
	strikes: number,
	lastPos: Vec3?, -- last sample that differed, or where the server last moved the racer
	lastAt: number, -- server time of lastPos
	legAt: number, -- when this leg began: GO, the last checkpoint or the last server teleport
	settleUntil: number, -- samples before this time are ignored
	arriving: boolean, -- teleported, and no sample has shown the racer at lastPos yet
	finished: number?, -- seconds from GO
	out: boolean, -- left or struck out
}
export type Round = {
	phase: Phase,
	ready: { number }, -- UserIds in ready order; survives a running round (the next round's queue)
	at: number, -- countdown end (countdown), GO (starting), time limit (racing); 0 in idle
	goAt: number,
	racers: { [number]: Racer },
	places: number, -- finishers so far
	winner: number?, -- first finisher
	prizeTo: number?, -- first eligible finisher
}
export type Event = {
	kind: string, -- "start" | "go" | "checkpoint" | "splash" | "flag" | "out" | "finish" | "over"
	id: number?, -- the racer
	ids: { number }?, -- start: racers in spot order; over: racers still in the round
	cp: number?, -- checkpoint: reached; splash, flag: the checkpoint to return to (0 = start)
	place: number?, -- finish
	time: number?, -- finish: seconds from GO
	egg: boolean?, -- finish: this finisher takes the egg
	winner: number?, -- over
	prizeTo: number?, -- over
	reason: string?, -- over: "finished" | "time" | "empty"
}
export type Pose = { x: number, y: number, z: number, angle: number } -- angle in radians

DashRules.new(): Round
DashRules.isReady(r: Round, id: number): boolean
DashRules.isRacer(r: Round, id: number): boolean -- in the round and not out
DashRules.setReady(r: Round, id: number, ready: boolean, t: number): (Round, boolean) -- changed; refused for a racer; third ready in idle starts the countdown, below minPlayers cancels it
DashRules.start(r: Round, t: number, entrants: { Entrant }): (Round, { Event }) -- call when a countdown is due; entrants = ready players with a character; below minPlayers: idle, ready = entrants; else starting, ready cleared, "start"
DashRules.step(r: Round, t: number): (Round, { Event }) -- timed changes: starting to racing ("go"); racing to idle at the limit, 20 s after the first finish or when nobody is running ("over"); idle with minPlayers ready starts a countdown
DashRules.sample(r: Round, id: number, pos: Vec3, t: number): (Round, { Event }) -- one 5 Hz sample while racing, in this order: settle, arrival, speed, fall, zone; a finisher gets the fall check only; no-op otherwise
DashRules.teleported(r: Round, id: number, t: number, at: Vec3): Round -- after any server teleport: lastPos = at, lastAt = t, legAt = max(t, goAt), settleUntil = t + DASH.settle, arriving
DashRules.legMin(cp: number): number -- seconds the leg to checkpoint cp takes at least: its share of minFinish by length
DashRules.leave(r: Round, id: number, t: number): (Round, { Event }) -- removes from ready; a racer goes out; may give "over" with reason "empty"
DashRules.facing(cp: number): Vec3 -- flat direction towards the next checkpoint, cp 0 to one before the finish
DashRules.respawnCp(r: Round, id: number): number -- 0 = start, else the last checkpoint reached
DashRules.respawnPoint(cp: number): Vec3 -- deck position, 4 studs up
DashRules.startSpot(i: number): Vec3 -- spots 1..6 on the start deck, 6 studs apart along z
DashRules.inZone(pos: Vec3, spot: Vec3): boolean -- horizontal <= zone.radius and |dy| <= zone.height
DashRules.status(r: Round): { [string]: any } -- GardenStatus.dash: { phase, ready, need, at, goAt, racers = { ids not out } }

DashRules.pose(o: GardenConfig.Obstacle, t: number): Pose -- pure in server time, the same for every client and round
DashRules.knock(o: GardenConfig.Obstacle, pose: Pose, root: Vec3): Vec3? -- velocity for a hit, magnitude <= DASH.knockMax, else nil; nil for platforms
```

`sample` rules, all from GDD T7:

0. **Settle:** before `settleUntil` the sample is ignored. A server `PivotTo` does not reach the client at once, so the next samples can still show the old position; without this a fall would count as a second fall and then a speed breach.
   **Arrival:** while `arriving`, for 2 s past `settleUntil`, a sample more than 30 studs from `lastPos` is stale and is ignored too, which covers a ping over 1 s. 30 is under the 31 studs a sample may move, so a stale sample that does pass cannot cause a strike. Any other sample ends `arriving`.
1. **Speed:** if `lastPos` is set and `pos` differs from it, a horizontal distance above `maxSpeed × (t − lastAt) + slack` is a breach: `strikes + 1`. At `maxStrikes`: `out` true, event `out`. Else event `flag` with `cp = respawnCp`.
2. **Fall:** `pos.y < fellY`: event `splash` with `cp = respawnCp`.
3. **Zone:** if `inZone(pos, checkpoints[next])` and `t - legAt >= legMin(next)`: `legAt = t`; a middle checkpoint gives `next + 1` and event `checkpoint`; the last one sets `finished`, `places + 1`, `winner` if unset, `egg = prizeTo == nil and eligible` (setting `prizeTo`), event `finish`. Sooner than the floor nothing happens, with no strike. The floors add up to `minFinish`, so no finish comes earlier.
4. `lastPos`, `lastAt` update only when `pos` changed.

`step` ends a round at the earliest of `goAt + limit`, `first finish + grace`, or nobody running; it then clears `racers`, keeps `ready`, and starts a new countdown if `ready` is at least `minPlayers`.

`pose`: with `c = 2π × (t / period + phase)`. Sweeper: `at`, `angle = c` (one turn each period). Ball: `at + reach × sin c` along `axis`, `y = at.y + size + lift × |cos c|`. Pendulum: `a = swing × sin c`, bob at `at + reach × (sin a along axis, −cos a in y)`, `angle = a`. Platform: `at + reach × sin c` along `axis`.

`knock`: sweeper: root within 2.5 of the arm segments (both sides of the hub) in the plane and 0 to 6 above the deck: tangent × `knock`, up 20. Ball and pendulum: distance to the pose at most `size + 2`: away × `knock`, up 20. Clamp to `knockMax`.

`tests/DashRules.spec.luau` covers every GDD T10 check value, and: phases and cancels; ready kept through a running round; order enforced (zones out of order do nothing); fall to the right checkpoint; leave at every phase; down to 1 racer; everyone leaves; capped first finisher passes the egg to the next eligible; nobody eligible; nobody finishes; a stale sample inside the settle time is neither a fall nor a strike; idle-then-hop takes the whole `minFinish`; the fastest honest walk and a walk after a fall on any leg are neither held nor flagged; every required gap is under the default jump at every moment of the platform cycle, with a safe moment in each; every Ball Alley lane is threatened; `pose` deterministic for a fixed `t`; `knock` never above `knockMax` over a sweep of times and positions; inputs never mutated.

## 4. Server (`src/garden`)

### 4.1 Files

| File | Kind | Owns |
|---|---|---|
| `GardenServer.server.luau` | Script | Entry point. Requires everything; plot assignment on join (lowest free 1 to 6) and release on leave; character spawn at the gate; `Request` router (common checks from decision 0008, world checks, then `Profiles.request`); `like` and `home`; bed prompt handlers (`Hatch`, `Water`); the Heartbeat loop (4.3); `GardenStatus`; hatch announcements; `BindToClose`. |
| `State.luau` | Module | The single mutable live state: `State.live: { [Player]: Live }` with `Live = { plot: number, pads: GardenRules.Pads, lastRequest: number, inside: { [number]: number }, visits: { [number]: boolean }, friends: { [number]: boolean }, boardIncome: number, boardAt: number }` (`inside`: plot -> seconds a disallowed player has been inside; `visits`: own pads already counted as a collect during the current visit; `friends`: IsFriendsWith cache by owner UserId). |
| `Remotes.luau` | Module | Copied from Night: creates `ReplicatedStorage.GardenRemotes` (`Request`, `Fx`) and `ReplicatedStorage.GardenStatus`; returns them plus `fx(kind, data)` = `Fx:FireAllClients` and `notice(player, text)` = `Fx:FireClient(player, "notice", { text = text })`. |
| `Profiles.luau` | Module | Copied from Night (4.2). |
| `Plots.luau` | Module | Builds the 6 plot shells once (fence, gate, sign, 12 bed sites, 20 pad sites, decor, under 300 parts each); `refresh(plot, profile)` rebuilds the changing parts (bed eggs and locks, pad locks, creature models, sign text, fence style, prompt `Enabled`); `clear(plot)`; geometry. |
| `Dash.luau` | Module | v0.2. The one live `Round` (a `DashRules.Round`); turns player state into entrants, runs `start`, `step` and `sample`, and carries out their events: teleports, start arch, `Profiles.apply` for prizes, Fx, notices. Collision group for characters. |
| `DashWorld.luau` | Module | v0.2. Builds the static Splash Island once: decks, rails, water plane, arches, ready pad and its prompt and label, under `Workspace.Garden.Dash`. Under 150 parts. Moving obstacles are not here: they exist only on clients. |
| `World.luau` | Module | Builds Hatchling Valley (GDD I1, I4 lighting baseline): plaza, Great Egg Tree (`Models.spawn("eggTree")`), cart with six display eggs (spacing 2.8) and its "Shop" prompt (opens the client's EGGS panel; the prompt itself changes nothing), forecast board, Top Gardens board, Wild Meadow gate, paths, meadows (at most 600 flowers), river, 16 blossom trees (`Models.spawn("sakura")`), windmill, barn, far scenery. Under 6,000 parts with the plots. |

Server module APIs (signatures for cross-file calls):

```luau
-- Profiles.luau
Profiles.Changed: RBXScriptSignal -- (player, profile)
Profiles.load(player: Player) -- blocks; claims the session lock (UpdateAsync, 3 tries), else offline with a notice; runs login; sets OfflineCoins
Profiles.get(player: Player): GardenConfig.Profile?
Profiles.isOnline(player: Player): boolean
Profiles.apply(player: Player, label: string, change: (GardenConfig.Profile) -> GardenConfig.Profile) -- in memory now, queued for the store, published
Profiles.bank(player: Player, coins: number, pads: number, today: number) -- pad banking: in memory now; merged into the last queued op if it is this day's bank; publishes only Coins
Profiles.request(player: Player, action: string, arg: string?): boolean -- buyEgg, plantPrize, buyBed, buyPenSlot, place, store, release, favourite, setGate, claimDaily, claimWeekly, claimQuest, buyCosmetic, equipCosmetic, adminGrant (owner only, router-checked, decision 0013); decides on the in-memory profile, applies only if accepted
Profiles.step(now: number) -- 1 Hz: publish dirty sessions, flush due queues (7 s / 60 s), income board writes (120 s)
Profiles.finish(player: Player, now: number) -- bank already done by the caller; leave op, waits at most 10 s for a running write, final flush (releases the lock; no retry wait past 25 s), then drops the session
Profiles.finishAll(now: number) -- BindToClose: finish every session in parallel
Profiles.topIncome(): { { name: string, income: number } }

-- Plots.luau
Plots.COUNT = 6 -- plots; Max Players must match
Plots.assign(player: Player): number? -- lowest free plot, sets Owner
Plots.free(plot: number) -- Owner = 0, clear
Plots.refresh(plot: number, profile: GardenConfig.Profile)
Plots.pads(plot: number): { [number]: GardenRules.Vec3 } -- pad centres 1..20
Plots.bed(plot: number, bed: number): GardenRules.Vec3 -- soil centre
Plots.gate(plot: number): CFrame -- just outside the gate, facing in
Plots.contains(plot: number, pos: GardenRules.Vec3): boolean -- inside the 60 x 60 fence
Plots.setPending(plot: number, pad: number, coins: number) -- the Pending attribute and coin pile, only when the floored value changed
Plots.prompts: RBXScriptSignal -- (player, plot, bed, kind: "Hatch" | "Water") from ProximityPrompt.Triggered

-- World.luau
World.build(): { cart: GardenRules.Vec3, board: (rows: { { name: string, income: number } }) -> (), forecast: (status: { [string]: any }) -> () }

-- Remotes.luau
Remotes.fxTo(player: Player, kind: string, data: { [string]: any }) -- one player only, as notice

-- Dash.luau
Dash.prompt: ProximityPrompt -- the ready pad; GardenServer connects Triggered through `admit`
Dash.toggle(player: Player): boolean -- the dashReady action and the pad prompt
Dash.leave(player: Player) -- PlayerRemoving, and the home action for a racer: leaves ready and any round; home teleports after it. A player who is only ready stays ready on home (GDD T3)
Dash.isRacing(player: Player): boolean
Dash.place(player: Player): boolean -- CharacterAdded: moves a racer's new character to the start or last checkpoint; false when not racing
Dash.step(roots: { [Player]: GardenRules.Vec3 }, today: number) -- 5 Hz, from fastTick
Dash.status(): { [string]: any } -- GardenStatus.dash, 1 Hz
Dash.close() -- BindToClose: ends the round with no prize and no teleports

-- DashWorld.luau
DashWorld.build(): { arch: BasePart, prompt: ProximityPrompt, label: (status: { [string]: any }) -> () }
```

### 4.2 Profiles (copied from Night)

Same load (3 tries, offline mode), `publish`, `topWins` pattern as `src/night/Profiles.luau`, with:

- Stores `GardenProfile<suffix>` and ordered `GardenIncome<suffix>`; `GardenProgress` in place of `NightProgress`; the transform is `GardenProgress.sanitize(old, now)` with `now` captured when the flush starts, then each queued change in order, then `snapshot`, stored as `GardenProgress.locked(..., session.id, now)` (no lock on the final write).
- Session lock (0008 amendment 2026-10-26): `session.id` is a GUID per load. The transform cancels (returns nil) unless `GardenProgress.holds(old, session.id)`; then the session goes offline (`ProfileOnline` false, `notice`) and never writes again.
- Session `{ id, profile, online, queue: { (Profile) -> Profile }, bank, writing: boolean, lastWrite: number, dirty: boolean, closing }`. `apply` runs `change` on `profile` and appends it to `queue` (if online). A flush moves `queue` out, runs one `UpdateAsync` (3 tries) and, on success, sets `profile` = the stored result with every change queued since the flush started re-run on it. One flush at a time per player (`writing`). A failed flush puts its changes back at the front of the queue.
- Load: one `UpdateAsync` that claims the lock when `GardenProgress.canClaim(old, session.id, now)` and stores the sanitised record with it (cancels and retries, 2 s and 4 s, otherwise); then `apply(login)`; the login's returned `offline` sets `OfflineCoins`. Without the lock or the store the session runs offline and gets a `notice`. A player who left during the load is finished at once (login written, lock released).
- `publish` sets `Profile` (JSON), `Coins`, `Income` (number), `Level`, `XP`, `Plot`, leaderstats `Income` (`GardenRules.short(floor(income))`) and `Index` (`#index`), and fires `Changed` (which `GardenServer` uses for `Plots.refresh`).
- Income board: in `step`, per session, if `floor(income) ~= boardIncome` and 120 s since `boardAt`, `SetAsync` in a spawned thread.

### 4.3 Server loop

`RunService.Heartbeat` accumulates `dt`. `now = os.time()`, `today = MetaRules.dayOf(now)`.

Every 0.2 s (5 Hz), for each `State.live` entry with a loaded profile:

1. Read the owner's `HumanoidRootPart` position (server-replicated).
2. `pads = GardenRules.accrue(profile, pads, 0.2)`.
3. For each pad `i` with `GardenRules.onPad(root, Plots.pads(plot)[i])`: `pads, coins = GardenRules.bankPad(pads, i)`; sum coins and count pads with coins ≥ 1; `Fx("collect", { owner, pad = i, amount = coins })` per pad. A pad counts towards `count` only once per visit (`live.visits`, reset when the root is off the pad). If the sum > 0: `Profiles.bank(player, sum, count, today)`.
4. Gate guard: for every player standing in `Plots.contains(plot, root)` of another owner whose gate disallows them, add 0.2 to `inside[plot]`; past 1.0 s move them to `Plots.gate(plot)`; reset when outside.

Every 1 s:

5. `Plots.setPending` for every pad of every owned plot.
6. `GardenStatus.Value = JSONEncode(status)` when changed (`WorldRules.weatherAt`, `weatherLeft`, `forecast(now, 3)` kinds 2 and 3, `restockLeft`, `stockWindow`, `stockFor`); `World.forecast(status)`.
7. `Profiles.step(now)`.
8. Every 60 s: `World.board(Profiles.topIncome())` in a spawned thread.

`fastTick` calls `Dash.step(roots, today)` last, under its own `guarded`, so a Dash fault never stops the pads. `slowTick` adds `status.dash = Dash.status()`.

`Request` calls and prompt triggers are handled when they arrive, between ticks.

- **Hatch prompt:** checks (decision 0008) → `weather = WorldRules.weatherAt(now)` → `o = HatchRules.roll(profile, bed, now, weather, Rng.seed(Random.new():NextInteger(1, 2^31 - 1)))`; nil → `notice` if `GardenRules.isFull`; else `Profiles.apply(player, "hatch", fn(p) (GardenProgress.hatch(p, bed, o, now, today)))`, `Fx("hatch", { owner, bed, id, s, m, z })` with the in-memory creature id, and `Fx("announce", { name = DisplayName, s, m, z })` when `HatchRules.announce(o)`.
- **Water prompt:** checks → owner: `apply(owner, "water", GardenProgress.ownWater ...)`; helper: `apply(owner, "help", GardenRules.water(p, bed, now, true))` and `apply(helper, "helper", GardenProgress.helperWater(p, today))`; `Fx("water", { owner, bed, by })`.
- **like:** after the gate check (which may yield on `IsFriendsWith`), `GardenProgress.like` is re-checked on the liker's current profile; then `apply(liker, "like", GardenProgress.like(p, target, liker.UserId, today))` and `apply(target, "liked", GardenProgress.receiveLike)`; `Fx("like", { owner = target, by = liker })`. The two sides (and the two sides of a helper water) are re-applied to their own stored records independently, so the counterpart op is best effort.
- **release** (via `Profiles.request`) also fires `Fx("release", { owner, id })` for the meadow run-off.
- **PlayerAdded:** `Plots.assign` (if no plot is free: `notice` every 10 s and retry every second until one frees up), set up `State.live`, `Profiles.load`, spawn the character at `Plots.gate`. **PlayerRemoving:** drop `State.live`, bank every pad, free the plot (`Plots.free`, so a waiting player can take it), then `Profiles.finish`. **BindToClose:** the same for every player, in parallel, via `Profiles.finishAll`.

### 4.3a Splash Dash round on the server

`Dash.step` each 0.2 s, with `t = workspace:GetServerTimeNow()`:

1. If a countdown is due: entrants are ready players with a root and a session, `eligible = Profiles.isOnline(player) and GardenProgress.dashEligible(profile, today)`; `DashRules.start`.
2. `DashRules.step`, then `DashRules.sample` for each racer with a root.
3. Carry out each event, in order, without yielding:

| Event | Server does |
|---|---|
| `start` | `PivotTo(DashRules.startSpot(i))`, `DashRules.teleported`; the arch stays closed (`CanCollide` true) |
| `go` | arch `CanCollide` false |
| `checkpoint` | `Remotes.fxTo(player, "dashCheckpoint", { cp, total = 5 })` |
| `splash` | `PivotTo(respawnPoint(cp))`, `teleported`, `fxTo(player, "dashSplash", { cp, reason = "fall" })` |
| `flag` | the same with `reason = "check"`, and `warn` with the UserId |
| `out` | move to the plot gate, `notice` "You are out of this round." |
| `finish` | prize below, then `Remotes.fx("dashFinish", { by = id, name = DisplayName, place, time, egg, coins })` |
| `over` | arch `CanCollide` true; each racer in `ids` moved to `Plots.gate`; `Remotes.fx("dashOver", { winner, prize, reason })` with display names |

**Prize:** the same step that accepts the finish, before anything can yield:

```luau
local today = MetaRules.dayOf(os.time())
if e.egg then
	Profiles.apply(player, "dashPrize", function(p) return (GardenProgress.dashPrize(p, today)) end)
else
	local _, coins = GardenProgress.dashCoins(profile, today) -- for the Fx
	Profiles.apply(player, "dashCoins", function(p) return (select(1, GardenProgress.dashCoins(p, today))) end)
end
```

The op is pure and captures `today`, so re-applying it to the stored record is safe, and the leave flush writes it. `onLeave` calls `Dash.leave(player)` first; it never grants anything.

**GardenServer changes:** `REQUEST_ARGS` adds `dashReady = false`, `plantPrize = true`; `dashReady` returns `Dash.toggle(player)`; `home` calls `Dash.leave(player)` before `toGate` when `Dash.isRacing(player)`, which includes the start hold; `plantPrize` falls through to `Profiles.request`; CharacterAdded runs `if not Dash.place(player) then toGate(...) end`; `onLeave` and `BindToClose` call `Dash.leave` and `Dash.close`; the pad prompt goes through `admit`.

**Collisions:** `PhysicsService:RegisterCollisionGroup("Racers")` with `CollisionGroupSetCollidable("Racers", "Racers", false)`. Every character part joins it in CharacterAdded and DescendantAdded, for the whole session. shortcut: this also stops players bumping in the garden, which is harmless; scope it to rounds only if a playtest asks.

**Moving characters:** always `character:PivotTo` on the server, facing along the course (`DashRules.facing`), then `DashRules.teleported` with the target. The client zeroes its own velocity on `dashSplash`.

### 4.4 How plots, eggs, pads and creatures are represented

- **Pure state:** the saved `Profile` (beds, creatures) plus `State.live[player].pads` (pending coins). Models are views rebuilt by `Plots.refresh` on `Profiles.Changed`; nothing is read back from models.
- **Plot frame:** plot `n` centre `(100 sin θ, 0, −100 cos θ)` with `θ = (n − 1) × 60°` clockwise from north; `frame = CFrame.lookAt(centre, Vector3.new(0, 0, 0))`, so local −Z faces the plaza and the gate sits at local z = −30. Bed `i` (1 to 12): rows local z = −22, −14, −6 (front row first), columns local x = −18, −6, 6, 18. Pad `i` (1 to 20): rows local z = 7, 14, 21, 28, columns x = −20, −10, 0, 10, 20.
- **Instances:** `Workspace.Garden.Plots.Plot<n>` (Model; attributes `Owner` UserId or 0, `Gate`) with `Beds.Bed<i>` (Model; attributes `Locked`, `Egg`, `Planted`, `Ready`; child `Soil` part holding the `Hatch` and `Water` ProximityPrompts, `MaxActivationDistance` 10; child `Egg` part when planted), `Pads.Pad<i>` (Part; attributes `Locked`, `Pending`), `Creatures.<id>` (MeshPart from `Models.spawn(species)` or a part-built fallback Model; anchored on its pad; attributes `Id`, `S`, `M`, `Z`, `Pad`, `Hatched` (`workspace:GetServerTimeNow()` at creation)), `Sign` (SurfaceGui), `Fence`.
- **Mutation looks** are applied client-side (`CreatureFx`) from the `M` attribute; the server sets only the base mesh, texture and scale (`SIZES[z].scale`).

## 5. `Fx` payloads

`Fx:FireAllClients(kind: string, data: table)`, except `notice` (`FireClient`). `owner`, `by` = UserId; `bed`, `pad` = index; `id` = creature id.

| `kind` | `data` | Sent when |
|---|---|---|
| `hatch` | `{ owner, bed, id, s, m, z }` | a hatch is accepted |
| `collect` | `{ owner, pad, amount }` | a pad is banked with ≥ 1 coin |
| `water` | `{ owner, bed, by }` | a water is accepted |
| `announce` | `{ name, s, m, z }` | `HatchRules.announce` |
| `like` | `{ owner, by }` | a like is accepted |
| `release` | `{ owner, id }` | a release is accepted (before the model is removed) |
| `notice` | `{ text }` | to one player, for a refusal that needs words |
| `dashCheckpoint` | `{ cp, total }` | to one racer: checkpoint `cp` of `total` reached |
| `dashSplash` | `{ cp, reason }` | to one racer: moved back to `cp` (0 = start); `reason` `"fall"` or `"check"` |
| `dashFinish` | `{ by, name, place, time, egg, coins }` | to all: a racer finished; `by` UserId, `name` display name, `time` seconds, `egg` boolean, `coins` paid |
| `dashOver` | `{ winner, prize, reason }` | to all: display names or nil; `reason` `"finished"`, `"time"` or `"empty"` |

`GardenStatus` adds `dash = { phase, ready, need, at, goAt, racers }` (`DashRules.status`), and `stock.celestial` through `WorldRules.stockFor`. `at` and `goAt` are server times, so 1 Hz is enough: clients count down locally with `workspace:GetServerTimeNow()`. No new player attributes: `prizeEggs` and `dash` are in `Profile`.

## 6. Client (`src/garden-client`)

| File | Kind | Owns |
|---|---|---|
| `ClientState.luau` | ModuleScript | Client-only settings `{ music, sfx, fastHatch, announcements: boolean }` with `SettingsChanged`; `reveal(owner, id, hidden)` with `hidden` keyed `"<owner>:<id>"` (creature ids are per profile), so CreatureFx hides only that garden's creature until its reveal ends. |
| `Menu.client.luau` | LocalScript | Forked Relay menu: title "EGG GARDEN", camera orbit, PLAY (camera flies to own gate), INDEX (38 entries, silhouettes, which eggs and weathers can produce them, every weather's mutation table), CREATURES (pen and storage lists with Place, Store, Release with confirmation "Release Berry Cat to the wild meadow? +324 coins", Favourite), EGGS (cart panel: price, grow time, stock left, unlock, Lucky Meter, ODDS card, BUY), LOCKER (fence, can), REWARDS, STATS, SETTINGS (writes `ClientState`), ADMIN (owner's creature catalogue, decision 0013), How to Play and Odds cards, toasts (`LastReward` without its `#n` suffix, `notice`), music by weather. Sends `Request` only. |
| `Hud.client.luau` | LocalScript | Coins and income (short format), level and XP bar, weather chip and the next two, restock timer, HOME button (`home`), Index count, gold dot, "While you were away" card (`OfflineCoins` > 0), hatch announcement banners (setting), first-session prompts and arrows (GDD H2, `hatches = 0` at join), per-viewer prompt visibility: each bed's `Hatch`/`Water` prompt `Enabled` locally only when the action can succeed for this player (owner, ripe/growing, cooldown, caps, gate, garden not full), using `GardenRules` on the owner's `Profile` attribute and `workspace:GetServerTimeNow()`. |
| `HatchFx.client.luau` | LocalScript | Reveal (wobble 1.5 s or 0.4 s Fast Hatch, crack, pop, rarity burst, name, rarity, mutation, size; never shows another creature), coin pops, water splash in the can's colour, like hearts, egg growth scale (40% to 100% by `GardenRules.growFraction`) and ripe glow/wobble, BillboardGui time left; weather looks from `GardenStatus` (I4 lighting tweens, rain, rainbow beam, fireflies, lamp lights), stingers; SFX. |
| `CreatureFx.client.luau` | LocalScript | Creature bob, hop and turn tweens; mutation looks (Golden texture swap, Moonlit, Rainbow and Celestial `Highlight`, falling back to particles and a tinted `SelectionBox` past about 31 highlights); ambient life (windmill sails, butterflies, petals). |
| `DashFx.client.luau` | LocalScript | v0.2. Splash Dash on the client: clones and drives the obstacles from `DashRules.pose(o, workspace:GetServerTimeNow())`, hit tests its own root with `DashRules.knock`, sets `AssemblyLinearVelocity`, carries the root on platforms, zeroes velocity on `dashSplash`; round HUD (countdown, GO, timer, checkpoint pips, splash text), results card, pad prompt text. Sends nothing. |

v0.2 changes in the existing files (GDD S4, T8): `Menu` Index grid uses `GardenConfig.indexable` with cell width `1 / cells`; `weathersFor` uses `GardenConfig.fixedBy`; the ODDS card branches on `egg.mutation`; `MUTATION_COLOURS.celestial`; a new `Dash` panel (READY, prizes today, prize eggs with PLANT using `GardenRules.canPlantPrize`). `Hud`: DASH quick button, column height 384, gold dot. `ClientState`: `EGG_COLOURS.celestial`, `Status.dash`. `HatchFx`: shell fragments (section 9).

`DashFx` detail: runs obstacles only while the local player is in `status.dash.racers`, and parks them otherwise. Obstacle parts have `CanCollide` false, because `knock` decides hits. A platform is walked on one invisible `Collider` block of 12 x 2 x 12 in its model, also the carry ray's target; its mesh is only the look. Each Heartbeat for each obstacle: `pose`, `PivotTo`, then `knock` against the local root with a 0.5 s cooldown per obstacle. A hit sets `root.AssemblyLinearVelocity` and `Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)`, so the walk controller does not cancel it. Platform carry: a raycast down 5 studs finds a platform part, and the root gets that platform's movement since the last frame.

Clients never write server state. The ODDS card, Index and forecast tables read `GardenConfig` (the same data the server rolls from) and format with `HatchRules.percent`.

## 7. Scaffolding

- `garden.project.json` (section 1), `src/garden/.gitkeep`, `src/garden-client/.gitkeep`.
- CI builds `build/garden.rbxl`; `publish.yml` offers `garden-staging` and maps `garden-*` to `garden.project.json`. The `garden-staging` environment (variables `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`, secret `ROBLOX_API_KEY`) is created by a human.
- **Publish checklist (Garden places):** set **Max Players = 6** (Creator Hub > the place > Settings, or Studio Game Settings > Places) to match `Plots.COUNT`. A place file cannot carry this setting, so `publish.yml` cannot set it; `GardenServer` warns in the server log when `Players.MaxPlayers` is higher, and extra players wait for a plot with a notice.

## 8. Resolutions of points the GDD leaves open

1. The leaderboard store is `GardenIncome<suffix>` (the GDD ranks by income), value `floor(income)`.
2. `placed` is stored as a pad number (0 = storage) rather than a boolean, so pads are stable across saves and the "lowest free pad" rule is well defined.
3. Pending coins belong to the pad, not the creature; storing or releasing a creature leaves its pad's coins to collect.
4. Every flush (not only the 60 s autosave) ends with `snapshot(unbanked, now)`, so a banked coin can never be paid again as `unbanked` after a crash. Login pays `unbanked` before computing offline.
5. The 6 s per-key DataStore cooldown no longer exists (decision 0008); 7 s coalescing is kept as a budget choice.
6. MetaRules needs three optional extensions the GDD did not name: a per-config coin cap (Garden coins reach 1e15, MetaRules caps at 1e7), an optional `wins` (Garden has none), and the minutes fields for `scale`.
7. Cosmetics listed with a coin amount are prices bought with `buyCosmetic`, not thresholds.
8. Weather id for Rainbow Shower is `shower`, so it never collides with the `rainbow` mutation id.
9. `GardenStatus` adds `stock` (this window's quantities) so each client can compute stock left; `stockLeft` is seconds to the next restock.
10. Distances (cart 25, beds 12) are horizontal, as Night's resolution 3.
11. A Lucky-Meter-forced species takes no species draw; the starter takes no draws at all. Draw order is species, mutation, size from one state.
12. Bed prompts share the 0.35 s request rate limit.
13. `sanitize` takes an optional `now` (the MetaRules config calls it without one), so "a future `lastSeen` becomes now" and new-profile defaults use the server's time inside `UpdateAsync`.
14. XP numbers live in `GardenConfig` (data); hatch XP is added by `HatchRules`, other XP and all quest stats by `GardenProgress` wrappers, which keeps the module graph acyclic.
15. Place, store, release and favourite need a UI the GDD does not list: a CREATURES panel in the menu.
16. Refusals that need words (full garden) use a `notice` Fx sent to one player; `release` gets an Fx for the meadow run-off; `hatch` carries the creature `id` so clients can hide the model during the reveal.
17. `OfflineCoins` shows the offline payout only; the saved `unbanked` is added silently.
18. Leaderstats `Income` is a StringValue (short format); `Index` an IntValue.
19. `short` truncates to one decimal and drops ".0" (`1250` → "1.2K", `2000` → "2K").
20. Weather tables keep 4 rows; egg-only mutations are not in them (decision 0012). Display code that loops weather tables needs no change, and `HatchRules.pick`'s last-row fallback can never return `celestial`.
21. Prize eggs are a count per egg, not a list: two Moon Eggs are the same thing, and the store cannot grow large.
22. `prizeEggs` keeps sold eggs only, so the starter can never be a prize.
23. `dashReady` toggles, so the menu button and the pad need one action. `home` doubles as leaving a round for a racer, so no third action; it leaves a ready player ready.
24. A round has no results phase: racers go home at once, and the card shows over the garden.
25. `Dash` owns its round state outside `State.live`, because a round outlives any one player.
26. Times in `DashRules` use `GetServerTimeNow` floats, not `os.time()`: finish times and the leg floors need sub-second values.

## 9. Models and naming

The artist's Blender models are registered by these exact names, as keys of `src/shared/GardenAssets.luau`, generated like `NightAssets.luau` (same `Asset` type, `tools/blender/garden`). A nil `model` id means not uploaded yet, and the game keeps the part-built fallback, so code never waits for art.

**Loading:** `src/relay/Models.luau` changes in exactly four places, and Relay and Night keep their behaviour:

1. `local GardenAssets = require(Shared.GardenAssets)`.
2. `loadNight` reads `NightAssets[name] or GardenAssets[name]`.
3. `CLIENT_MODELS` adds `egg_shell_fragment`, `dash_sweeper`, `dash_ball`, `dash_pendulum`, `dash_platform`; clients clone these from `ReplicatedStorage.NightModels` (the folder name is historical).
4. `Models.preloadGarden()`, the `preloadNight` loop over `GardenAssets`; `GardenServer` calls it at start.

If `GardenAssets.luau` has not landed when GARDEN-009 starts, GARDEN-009 adds `return {}` with the type export; the generated file replaces it.

| Name | Where | Target size (studs) | How code uses it | Fallback |
|---|---|---|---|---|
| `egg_starter`, `egg_meadow`, `egg_forest`, `egg_sunset`, `egg_moon`, `egg_star`, `egg_celestial` | server, `Plots.egg` (beds and cart) | 2.2 × 3 × 2.2, one mesh | `` Models.nightPart(`egg_{id}`, ...) `` only when `Models.nightReady(name)`, because `Plots.refresh` must not yield; renamed `Egg`, since `HatchFx` finds it by that name and scales its `Size` | stretched Ball from `EGG_LOOKS` |
| `egg_shell_fragment` | client, `HatchFx` reveal | about 1, one mesh | up to 6 clones burst from the crack, tinted from `EGG_COLOURS`, `TextureID` cleared | the existing burst |
| `dash_sweeper` | client, `DashFx` | 40 long: two arms, symmetric about the hub | `PivotTo` at the pose | a bar and hub of parts |
| `dash_ball` | client, `DashFx` | 10 diameter | `PivotTo` at the pose | Ball part |
| `dash_pendulum` | client, `DashFx` | 30 tall, bob 8 wide, hinge at the top centre | `PivotTo`, with the offset below | rod and Ball |
| `dash_platform` | client, `DashFx` | 12 × 2 × 12 | `PivotTo` at the pose; decor, the walked surface is the invisible `Collider` block | Block part |
| `dash_arch` | server, `DashWorld` | 28 wide, 18 high, walk-through | decor; the barrier is a separate invisible part | parts |
| `dash_ready_pad` | server, `DashWorld` | 12 wide, low | decor; a flat part carries the prompt | Cylinder part |
| `dash_island` | server, `DashWorld` | about 300 × 160 from above | decor under the decks, never walked on | none, the decks stand alone |

Three contract points for the artist and engineers:

- **Pivots are not kept.** `loadNight` rebuilds each asset into a new Model, whose pivot is its bounding box centre. A sweeper therefore has to be symmetric about its hub. For the pendulum, `DashFx` pivots at the hinge and places the model half its height below it along the rod.
- **Size:** `DashFx` scales each dash model to the config (`size`, `reach`) with `Model:ScaleTo` using `GardenAssets[name].size`. Hit tests use the config, never the mesh, so a model that differs from the table still plays the same.
- **Collision:** the decks are `DashWorld` parts. No mesh collision is used on the course.
