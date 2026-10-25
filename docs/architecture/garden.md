# Egg Garden: architecture (v0.1)

Owner: A09. Inputs: `docs/game-design/game4-gdd.md` (the GDD; section letters below refer to it) and `docs/decisions/0008-egg-garden.md` (save schema, economy, odds, remotes, child safety). If this file and the GDD disagree on a rule, the GDD wins and this file is fixed; the resolutions in section 8 are the exception (they settle what the GDD leaves open).

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

Every file under `src/relay`, `src/relay-client`, `src/night` and `src/night-client` stays byte-identical except the new `Models.luau` entries.

### File ownership by task

| Task | Writes |
|---|---|
| GARDEN-003 | `src/shared/{GardenConfig,WorldRules,GardenRules,HatchRules,GardenProgress}.luau`, `src/shared/MetaRules.luau` (section 3.1 additions only), `tests/<Module>.spec.luau` for the 5 new modules, `tests/MetaRules.spec.luau` (new cases only), `tests/run.luau` (`SPECS`) |
| GARDEN-004 | `src/garden/*`, `src/relay/Models.luau` (new entries only), `docs/assets/register.md` (mesh, music and SFX rows) |
| GARDEN-005 | `src/garden-client/*` |

GARDEN-004 and GARDEN-005 code against the signatures in section 3 and may start with stubs; GARDEN-003 must not change a signature without updating this file in the same PR.

## 2. Conventions for the pure modules

- Same as `docs/architecture/night.md` section 2: `--!strict`, no Roblox globals, requires by string (`require("./GardenRules")`), functions return new tables and never mutate inputs, `floor(x + 1e-9)` for every floor of a product.
- Times are integer server `os.time()` seconds passed in as `now`; days are `MetaRules.dayOf(now)` passed in as `today`. Pad accrual takes `dt` in seconds.
- Positions are `Vec3 = { x: number, y: number, z: number }` (structurally the same as `CombatRules.Vec3`); "horizontal" means the x, z plane.
- Ids are strings as in decision 0008: eggs `starter meadow forest sunset moon star`; species `bunny frog pup cat owl fox turtle lion dragon`; mutations `normal golden moonlit rainbow`; sizes `normal big huge`; weathers `clear sunbeam moonfall shower`; rarities `common uncommon rare epic legendary mythic`; gates `open friends closed`.
- Dependency graph (no cycles): `GardenConfig` (types and data, no requires except `MetaRules` for the `Cosmetic`/`Quest` types); `WorldRules → Rng, GardenConfig`; `GardenRules → GardenConfig, WorldRules, MetaRules`; `HatchRules → Rng, GardenConfig, GardenRules, MetaRules`; `GardenProgress → MetaRules, GardenConfig, GardenRules, HatchRules`.
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
	top: string?, -- Lucky Meter species
	meter: number?,
	xp: number,
}
export type Species = { id: string, name: string, rarity: string, rate: number }
export type Mutation = { id: string, name: string, mult: number }
export type Size = { id: string, name: string, mult: number, scale: number, bp: number }
export type Weather = { id: string, name: string, mutation: { Odds } } -- in MUTATIONS order, sums to 10000

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
}

GardenConfig.EGGS: { Egg } -- starter, meadow, forest, sunset, moon, star; the stock index i is position - 1
GardenConfig.SPECIES: { Species } -- E1 order
GardenConfig.RARITIES: { { id: string, name: string, colour: { number } } } -- common..mythic, RGB 0-255
GardenConfig.RARE = 3 -- RARITIES index of "rare": rareHatches counts rarity index >= 3
GardenConfig.MUTATIONS: { Mutation } -- normal 1, golden 3, moonlit 5, rainbow 10
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
GardenConfig.INDEX_SIZE = 36
GardenConfig.OFFLINE = { rate = 0.5, cap = 28_800 }
GardenConfig.RELEASE_SECONDS = 30
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

GardenConfig.egg(id: string): Egg?
GardenConfig.species(id: string): Species?
GardenConfig.mutation(id: string): Mutation?
GardenConfig.size(id: string): Size?
GardenConfig.rarityIndex(speciesId: string): number -- 1..6, 0 if unknown
```

The five lookup helpers are the only functions; the module is otherwise data.

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
GardenRules.releaseValue(c: Creature): number -- floor(rate * 30 + 1e-9)

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
HatchRules.roll(p: Profile, bed: number, now: number, weather: string, rng: Rng.State): Outcome? -- nil unless the bed is ripe and the garden not full; starter: pup normal normal, no draws
HatchRules.apply(p: Profile, bed: number, o: Outcome, now: number): (Profile, boolean, Result?) -- re-checks ripe (same egg) and not full; empties the bed; creature id = nextId; lowest free pad else storage; pity; index; hatches + 1; XP egg.xp (+50 if new entry)
HatchRules.hatch(p: Profile, bed: number, now: number, weather: string, rng: Rng.State): (Profile, boolean, Outcome?, Result?) -- roll then apply
HatchRules.nextPity(egg: string, pity: number, species: string): number -- 0 on the top species, else pity + 1
HatchRules.announce(o: Outcome): boolean -- legendary or mythic species, any rainbow, any huge
HatchRules.percent(bp: number): string -- "60.00" (two decimals, for the ODDS panel)
```

### 3.6 `GardenProgress`

```luau
GardenProgress.SCHEMA_VERSION = 1
GardenProgress.CONFIG: MetaRules.Config<Profile> -- COSMETICS, slots { fence = "picket", can = "tin" }, QUESTS, DAILY, DAILY_MINUTES, WEEKLY, maxCoins 1e15, scale = scaled

GardenProgress.defaults(now: number): Profile -- decision 0008 defaults; starter egg ready now + 8
GardenProgress.sanitize(record: any, now: number?): Profile -- H7 and decision 0008; game fields before MetaRules.sanitizeMeta
GardenProgress.scaled(p: Profile, base: number, minutes: number): number -- max(base, floor(income * 60 * minutes + 1e-9))
GardenProgress.login(p: Profile, now: number, today: number): (Profile, number, number) -- pays unbanked then offline; returns offline, unbanked
GardenProgress.snapshot(p: Profile, unbanked: number, now: number): Profile -- last op of every flush
GardenProgress.leave(p: Profile, now: number): Profile -- unbanked = 0, lastSeen = now
GardenProgress.bank(p: Profile, coins: number, pads: number, today: number): Profile -- coins (capped 1e15); collects += pads with >= 1 coin
GardenProgress.hatch(p: Profile, bed: number, o: HatchRules.Outcome, now: number, today: number): (Profile, boolean, HatchRules.Result?) -- apply + quest stats hatches, rareHatches, mutants
GardenProgress.ownWater(p: Profile, bed: number, now: number, today: number): (Profile, boolean) -- water(helper false) + 3 XP + waters stat and total
GardenProgress.helperWater(p: Profile, today: number): (Profile, number) -- the helper's side: 15 XP under the daily cap of 20, waters stat and total; returns XP paid
GardenProgress.release(p: Profile, id: number, today: number): (Profile, boolean, number) -- GardenRules.release + releases stat
GardenProgress.like(p: Profile, target: number, liker: number, today: number): (Profile, boolean) -- the liker's side: not self, once per target per day, 30 per day
GardenProgress.receiveLike(p: Profile): Profile -- likes + 1
GardenProgress.setGate(p: Profile, gate: string): (Profile, boolean)
GardenProgress.gateAllows(gate: string, isFriend: boolean): boolean -- open: true; friends: isFriend; closed: false (owners are checked separately)
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

## 4. Server (`src/garden`)

### 4.1 Files

| File | Kind | Owns |
|---|---|---|
| `GardenServer.server.luau` | Script | Entry point. Requires everything; plot assignment on join (lowest free 1 to 6) and release on leave; character spawn at the gate; `Request` router (common checks from decision 0008, world checks, then `Profiles.request`); `like` and `home`; bed prompt handlers (`Hatch`, `Water`); the Heartbeat loop (4.3); `GardenStatus`; hatch announcements; `BindToClose`. |
| `State.luau` | Module | The single mutable live state: `State.live: { [Player]: Live }` with `Live = { plot: number, pads: GardenRules.Pads, lastRequest: number, inside: { [number]: number }, friends: { [number]: boolean }, boardIncome: number, boardAt: number }` (`inside`: plot -> seconds a disallowed player has been inside; `friends`: IsFriendsWith cache by owner UserId). |
| `Remotes.luau` | Module | Copied from Night: creates `ReplicatedStorage.GardenRemotes` (`Request`, `Fx`) and `ReplicatedStorage.GardenStatus`; returns them plus `fx(kind, data)` = `Fx:FireAllClients` and `notice(player, text)` = `Fx:FireClient(player, "notice", { text = text })`. |
| `Profiles.luau` | Module | Copied from Night (4.2). |
| `Plots.luau` | Module | Builds the 6 plot shells once (fence, gate, sign, 12 bed sites, 20 pad sites, decor, under 300 parts each); `refresh(plot, profile)` rebuilds the changing parts (bed eggs and locks, pad locks, creature models, sign text, fence style, prompt `Enabled`); `clear(plot)`; geometry. |
| `World.luau` | Module | Builds Hatchling Valley (GDD I1, I4 lighting baseline): plaza, Great Egg Tree (`Models.spawn("eggTree")`), cart with five display eggs and its "Shop" prompt (opens the client's EGGS panel; the prompt itself changes nothing), forecast board, Top Gardens board, Wild Meadow gate, paths, meadows (at most 600 flowers), river, 16 blossom trees (`Models.spawn("sakura")`), windmill, barn, far scenery. Under 6,000 parts with the plots. |

Server module APIs (signatures for cross-file calls):

```luau
-- Profiles.luau
Profiles.Changed: RBXScriptSignal -- (player, profile)
Profiles.load(player: Player) -- blocks; runs login; sets OfflineCoins
Profiles.get(player: Player): GardenConfig.Profile?
Profiles.isOnline(player: Player): boolean
Profiles.apply(player: Player, label: string, change: (GardenConfig.Profile) -> GardenConfig.Profile, quiet: boolean?) -- in memory now, queued for the store; quiet: publish on the next 1 Hz step instead of now
Profiles.request(player: Player, action: string, arg: string?): boolean -- buyEgg, buyBed, buyPenSlot, place, store, release, favourite, setGate, claimDaily, claimWeekly, claimQuest, buyCosmetic, equipCosmetic; decides on the in-memory profile, applies only if accepted
Profiles.step(now: number) -- 1 Hz: publish dirty sessions, flush due queues (7 s / 60 s), income board writes (120 s)
Profiles.finish(player: Player, now: number) -- bank already done by the caller; leave op, final flush (waits), then drops the session
Profiles.finishAll(now: number) -- BindToClose: finish every session in parallel
Profiles.topIncome(): { { name: string, income: number } }

-- Plots.luau
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
```

### 4.2 Profiles (copied from Night)

Same load (3 tries, offline mode), `publish`, `topWins` pattern as `src/night/Profiles.luau`, with:

- Stores `GardenProfile<suffix>` and ordered `GardenIncome<suffix>`; `GardenProgress` in place of `NightProgress`; the transform is `GardenProgress.sanitize(old, now)` with `now` captured when the flush starts, then each queued change in order, then `snapshot`.
- Session `{ profile, online, queue: { (Profile) -> Profile }, writing: boolean, lastWrite: number, dirty: boolean }`. `apply` runs `change` on `profile` and appends it to `queue` (if online). A flush moves `queue` out, runs one `UpdateAsync` (3 tries) and, on success, sets `profile` = the stored result with every change queued since the flush started re-run on it. One flush at a time per player (`writing`). A failed flush puts its changes back at the front of the queue.
- Load: after `GetAsync`, `apply(login)`; the login's returned `offline` sets `OfflineCoins`.
- `publish` sets `Profile` (JSON), `Coins`, `Income` (number), `Level`, `XP`, `Plot`, leaderstats `Income` (`GardenRules.short(floor(income))`) and `Index` (`#index`), and fires `Changed` (which `GardenServer` uses for `Plots.refresh`).
- Income board: in `step`, per session, if `floor(income) ~= boardIncome` and 120 s since `boardAt`, `SetAsync` in a spawned thread.

### 4.3 Server loop

`RunService.Heartbeat` accumulates `dt`. `now = os.time()`, `today = MetaRules.dayOf(now)`.

Every 0.2 s (5 Hz), for each `State.live` entry with a loaded profile:

1. Read the owner's `HumanoidRootPart` position (server-replicated).
2. `pads = GardenRules.accrue(profile, pads, 0.2)`.
3. For each pad `i` with `GardenRules.onPad(root, Plots.pads(plot)[i])`: `pads, coins = GardenRules.bankPad(pads, i)`; sum coins and count pads with coins ≥ 1; `Fx("collect", { owner, pad = i, amount = coins })` per pad. If the sum > 0: `Profiles.apply(player, "bank", fn(p) GardenProgress.bank(p, sum, count, today), true)`.
4. Gate guard: for every player standing in `Plots.contains(plot, root)` of another owner whose gate disallows them, add 0.2 to `inside[plot]`; past 1.0 s move them to `Plots.gate(plot)`; reset when outside.

Every 1 s:

5. `Plots.setPending` for every pad of every owned plot.
6. `GardenStatus.Value = JSONEncode(status)` when changed (`WorldRules.weatherAt`, `weatherLeft`, `forecast(now, 3)` kinds 2 and 3, `restockLeft`, `stockWindow`, `stockFor`); `World.forecast(status)`.
7. `Profiles.step(now)`.
8. Every 60 s: `World.board(Profiles.topIncome())` in a spawned thread.

`Request` calls and prompt triggers are handled when they arrive, between ticks.

- **Hatch prompt:** checks (decision 0008) → `weather = WorldRules.weatherAt(now)` → `o = HatchRules.roll(profile, bed, now, weather, Rng.seed(Random.new():NextInteger(1, 2^31 - 1)))`; nil → `notice` if `GardenRules.isFull`; else `Profiles.apply(player, "hatch", fn(p) (GardenProgress.hatch(p, bed, o, now, today)))`, `Fx("hatch", { owner, bed, id, s, m, z })` with the in-memory creature id, and `Fx("announce", { name = DisplayName, s, m, z })` when `HatchRules.announce(o)`.
- **Water prompt:** checks → owner: `apply(owner, "water", GardenProgress.ownWater ...)`; helper: `apply(owner, "help", GardenRules.water(p, bed, now, true))` and `apply(helper, "helper", GardenProgress.helperWater(p, today))`; `Fx("water", { owner, bed, by })`.
- **like:** `apply(liker, "like", GardenProgress.like(p, target, liker.UserId, today))` and `apply(target, "liked", GardenProgress.receiveLike)`; `Fx("like", { owner = target, by = liker })`.
- **release** (via `Profiles.request`) also fires `Fx("release", { owner, id })` for the meadow run-off.
- **PlayerAdded:** `Plots.assign`, `Profiles.load`, then set up `State.live`, spawn the character at `Plots.gate`. **PlayerRemoving:** bank every pad (`GardenProgress.bank`), `Profiles.finish`, then remove the plot's prompts and models (`Plots.free`), drop `State.live`. **BindToClose:** the same for every player, in parallel, via `Profiles.finishAll`.

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

## 6. Client (`src/garden-client`)

| File | Kind | Owns |
|---|---|---|
| `ClientState.luau` | ModuleScript | Client-only settings `{ music, sfx, fastHatch, announcements: boolean }` with `SettingsChanged`; `Revealing(id)` signal from HatchFx so CreatureFx hides a creature until its reveal ends. |
| `Menu.client.luau` | LocalScript | Forked Relay menu: title "EGG GARDEN", camera orbit, PLAY (camera flies to own gate), INDEX (36 entries, silhouettes, which eggs and weathers can produce them, every weather's mutation table), CREATURES (pen and storage lists with Place, Store, Release with confirmation "Release Berry Cat to the wild meadow? +1,620 coins", Favourite), EGGS (cart panel: price, grow time, stock left, unlock, Lucky Meter, ODDS card, BUY), LOCKER (fence, can), REWARDS, STATS, SETTINGS (writes `ClientState`), How to Play and Odds cards, toasts (`LastReward`, `notice`), music by weather. Sends `Request` only. |
| `Hud.client.luau` | LocalScript | Coins and income (short format), level and XP bar, weather chip and the next two, restock timer, HOME button (`home`), Index count, gold dot, "While you were away" card (`OfflineCoins` > 0), hatch announcement banners (setting), first-session prompts and arrows (GDD H2, `hatches = 0` at join), per-viewer prompt visibility: each bed's `Hatch`/`Water` prompt `Enabled` locally only when the action can succeed for this player (owner, ripe/growing, cooldown, caps, gate, garden not full), using `GardenRules` on the owner's `Profile` attribute and `workspace:GetServerTimeNow()`. |
| `HatchFx.client.luau` | LocalScript | Reveal (wobble 1.5 s or 0.4 s Fast Hatch, crack, pop, rarity burst, name, rarity, mutation, size; never shows another creature), coin pops, water splash in the can's colour, like hearts, egg growth scale (40% to 100% by `GardenRules.growFraction`) and ripe glow/wobble, BillboardGui time left; weather looks from `GardenStatus` (I4 lighting tweens, rain, rainbow beam, fireflies, lamp lights), stingers; SFX. |
| `CreatureFx.client.luau` | LocalScript | Creature bob, hop and turn tweens; mutation looks (Golden texture swap, Moonlit and Rainbow `Highlight`, falling back to particles and a tinted `SelectionBox` past about 31 highlights); ambient life (windmill sails, butterflies, petals). |

Clients never write server state. The ODDS card, Index and forecast tables read `GardenConfig` (the same data the server rolls from) and format with `HatchRules.percent`.

## 7. Scaffolding

- `garden.project.json` (section 1), `src/garden/.gitkeep`, `src/garden-client/.gitkeep`.
- CI builds `build/garden.rbxl`; `publish.yml` offers `garden-staging` and maps `garden-*` to `garden.project.json`. The `garden-staging` environment (variables `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`, secret `ROBLOX_API_KEY`) is created by a human.

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
