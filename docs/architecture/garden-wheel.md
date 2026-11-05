# Egg Garden architecture: Petal Catch and the prize wheel

Companion to `docs/architecture/garden.md` (its conventions, sections 2, 4.3a, 5 and 6 apply). Design: `docs/game-design/game4-wheel.md` (W). Economy values and contract: decision 0016. Written as a separate file so the v0.4 designer's edits to `garden.md` do not conflict; fold a one-line pointer into `garden.md` 1, 5 and 6 when v0.4 merges.

## 1. Files and who owns them

| File | Kind | Owns | Task |
|---|---|---|---|
| `src/shared/GardenConfig.luau` | pure data | `GardenConfig.WHEEL` (section 2.1), `Profile.wheelToday` | GARDEN-041 |
| `src/shared/WheelRules.luau` | pure, new | schedule, catch samples, tiers, roll, award (section 2.2) | GARDEN-041 |
| `src/shared/GardenProgress.luau` | pure | `defaults` and `sanitize` for `wheelToday`; `SCHEMA_VERSION` 3 (with v0.4) | GARDEN-041 |
| `tests/WheelRules.spec.luau` | spec, new | W12 | GARDEN-041 |
| `src/garden/Wheel.luau` | server, new | one round per player, samples, the spin, the prize (section 3) | GARDEN-042 |
| `src/garden/WheelWorld.luau` | server, new | the Petal Patch, stand, prompt, fallbacks (section 3.3) | GARDEN-042 |
| `src/garden/GardenServer.server.luau` | server | `wheelStart` action, `home` and leave hooks, `fastTick` call, `BindToClose` | GARDEN-042 |
| `src/garden-client/WheelFx.client.luau` | client, new | petals from the seed, basket, round HUD, end card, wheel panel, stand label (section 5) | GARDEN-043 |
| `src/garden-client/Menu.client.luau` | client | the DASH panel's prize list title reads "Prize eggs" (Splash Dash and Petal Catch share it) | GARDEN-043 |
| `src/relay/Models.luau` | shared loader | `CLIENT_MODELS` adds `wheel_disc`, `wheel_basket`, `petal_pink`, `petal_gold`, `pinecone` | GARDEN-043 |
| `tools/blender/garden/**`, `assets/garden/**`, `src/shared/GardenAssets.luau` | art | the six props (section 6) | GARDEN-044 |

## 2. Pure modules

### 2.1 `GardenConfig.WHEEL` (data only)

```luau
export type Wedge = { id: string, standard: number, lucky: number } -- id: an egg id or "coins"; bp
export type WheelConfig = {
	name: string, -- "Petal Catch"
	centre: Spot, -- patch centre, ground level: { x = -40, y = 0, z = -52 }
	size: number, -- 30 (fence square)
	stand: Spot, -- { x = -40, y = 0, z = -38 }, faces +z (the plaza)
	promptRange: number, -- 12
	round: number, -- 45
	lead: number, -- 2: first drop after startAt
	gap: number, -- 1.0 between drops
	drops: { pink: number, gold: number, cone: number }, -- 26, 4, 10
	points: { pink: number, gold: number, cone: number }, -- 1, 3, -2
	canopy: number, -- 16: drop height above centre.y
	fall: number, -- 4 studs/s
	band: { top: number, bottom: number }, -- 7, 1: catchable while bottom <= y <= top
	catchRadius: number, -- 3.5
	ring: { min: number, max: number }, -- 4, 12 from the trunk
	spinAt: number, -- 12
	luckyAt: number, -- 24
	spinsPerDay: number, -- 3
	coinsBase: number, -- 100
	coinsMinutes: number, -- 10
	wedges: { Wedge }, -- disc order clockwise from the pointer: meadow, forest, sunset, coins, moon, star, celestial, aurora
}
GardenConfig.WHEEL: WheelConfig
```

`Profile` adds `wheelToday: { day: number, spins: number }` (v3, default `{ day = -1, spins = 0 }`).

`GardenConfig.spec` adds: 8 wedges, both columns sum to 10,000, every non-`coins` wedge is a sold egg (`GardenConfig.egg(id).price`), `drops` sum to 40, `spinAt < luckyAt <= drops.pink + 3 × drops.gold`.

### 2.2 `WheelRules` (new; no Roblox APIs; `t` is a float server time as in `DashRules`)

```luau
export type Vec3 = { x: number, y: number, z: number }
export type Kind = "pink" | "gold" | "cone"
export type Tier = "none" | "spin" | "lucky"
export type Drop = { at: number, kind: Kind, x: number, z: number } -- at: server time it leaves the canopy; x, z: world
export type Round = {
	id: number, -- UserId
	seed: number,
	startAt: number,
	endAt: number, -- startAt + WHEEL.round
	eligible: boolean, -- saving session and under the cap at the start
	n: number, -- the spin this round can earn: spinsToday + 1 (meaningless when not eligible)
	score: number,
	done: { [number]: boolean }, -- drop index -> resolved (caught or landed)
}
export type Event = {
	kind: string, -- "catch" | "over"
	i: number?, -- catch: drop index
	drop: Kind?, -- catch
	score: number?, -- catch: after; over: final
	tier: Tier?, -- over
}

WheelRules.schedule(seed: number, startAt: number): { Drop } -- 40 drops, fixed composition shuffled, ring spots; pure in (seed, startAt)
WheelRules.new(id: number, seed: number, t: number, eligible: boolean, n: number): Round
WheelRules.bandAt(drop: Drop): (number, number) -- (from, to): server times the drop is catchable; from = at + (canopy - band.top) / fall, to = at + (canopy - band.bottom) / fall
WheelRules.sample(r: Round, drops: { Drop }, pos: Vec3, t: number): (Round, { Event }) -- one 5 Hz sample: in index order, a drop past `to` is done (no event); a drop inside [from, to] with horizontal distance <= catchRadius and centre.y - 2 <= pos.y <= centre.y + 10 is caught: done, score = max(0, score + points[kind]), event "catch". No-op after endAt.
WheelRules.tier(r: Round): Tier -- "none" unless eligible and score >= spinAt; "lucky" at >= luckyAt
WheelRules.finish(r: Round, t: number): (Round, { Event }) -- at t >= endAt: event "over" { score, tier }; else no-op
WheelRules.roll(state: Rng.State, lucky: boolean): (string, Rng.State) -- wedge id by Rng.int(state, 1, 10000) over the column
WheelRules.spinsToday(p: Profile, today: number): number -- wheelToday.spins if wheelToday.day == today else 0
WheelRules.spinsLeft(p: Profile, today: number): number -- spinsPerDay - spinsToday
WheelRules.canSpin(p: Profile, today: number): boolean
WheelRules.spinId(today: number, n: number): number -- today * 10 + n
WheelRules.award(p: Profile, today: number, n: number, wedge: string): (Profile, boolean, number) -- idempotent prize op; (profile, applied, coins paid)
```

`award`, exactly:

1. If `spinsToday(p, today) ~= n - 1` or `n > spinsPerDay`: return `(p, false, 0)`. This covers a re-apply (the stored record already has spin `n`), an out-of-order op and the cap.
2. Copy; `wheelToday = { day = today, spins = n }`.
3. `wedge == "coins"`: `paid = min(MAX_COINS - coins, GardenProgress.scaled(p, coinsBase, coinsMinutes))`, `coins += paid`. Else `prizeEggs[wedge] = min(PRIZE_STORE, (prizeEggs[wedge] or 0) + 1)`.
4. Return `(out, true, paid)`.

`schedule`, exactly, so server and client agree: `list` = 26 `"pink"`, 4 `"gold"`, 10 `"cone"` in that order; `state = seed`; Fisher–Yates from `i = 40` down to 2 with `j, state = Rng.int(state, 1, i)`; then for `i = 1..40`: `u, state = Rng.next(state)`, `v, state = Rng.next(state)`, `r = ring.min + (ring.max - ring.min) × sqrt(u)`, `a = 2π × v`, `x = centre.x + r cos a`, `z = centre.z + r sin a`, `at = startAt + lead + (i - 1) × gap`.

`tests/WheelRules.spec.luau`: the W12 list and every W10 check value.

### 2.3 `GardenProgress`

- `defaults`: `wheelToday = { day = -1, spins = 0 }`.
- `sanitize`, after `dash`: `day = MetaRules.dayNumber(record.wheelToday.day)`, `spins = MetaRules.count(record.wheelToday.spins, WHEEL.spinsPerDay)`; a missing or non-table field gives the default.
- `SCHEMA_VERSION = 3` lands with v0.4; if GARDEN-041 merges first it makes the bump itself and the v0.4 task keeps it. `GardenProgress.spec` loads a literal v2 record and compares every field plus the default `wheelToday`.

## 3. Server

### 3.1 `Wheel.luau`

Modelled on `Dash.luau`: rounds live in a module table keyed by `Player`, outside `State.live`, and every outcome comes from `WheelRules` on the server's own samples. Event handling never yields, so a prize is in the profile and the write queue in the same step that ends the round.

```luau
Wheel.prompt: ProximityPrompt -- the stand's "Play"; GardenServer routes it through admit to Wheel.start
Wheel.start(player: Player): boolean -- the wheelStart action and the prompt
Wheel.isPlaying(player: Player): boolean
Wheel.leave(player: Player) -- home, PlayerRemoving: drops the round, grants nothing
Wheel.step(roots: { [Player]: Vec3 }, today: number) -- 5 Hz, after Dash.step in fastTick, guarded
Wheel.close() -- BindToClose: drops every round
```

`Wheel.start`: refuse when `closed`, no `State.live[player]` or profile, a round exists, `Dash.isRacing(player)`, or the server root is over `promptRange` from `WHEEL.stand` horizontally. Else, with `t = Workspace:GetServerTimeNow()` and `today = MetaRules.dayOf(os.time())`:

```luau
local seed = Rng.seed(math.floor(t * 1000) % 2 ^ 32, player.UserId, counter) -- counter: rounds started this server
if RunService:IsStudio() then seed = folder:GetAttribute("Seed") or seed end -- W11 only
local eligible = Profiles.isOnline(player) and WheelRules.canSpin(profile, today)
rounds[player] = { round = WheelRules.new(id, seed, t, eligible, WheelRules.spinsToday(profile, today) + 1), drops = WheelRules.schedule(seed, t) }
Remotes.fxTo(player, "wheelStart", { seed = seed, startAt = t, endAt = t + WHEEL.round, practice = not eligible, spinsLeft = WheelRules.spinsLeft(profile, today) })
if not Profiles.isOnline(player) then Remotes.notice(player, SPINS_OFF_TEXT) end
```

`Wheel.step`, for each `(player, entry)`, `t` as above:

1. `WheelRules.finish(entry.round, t)`: on `over`, remove the round, then if `tier ~= "none"`:
   ```luau
   local n, lucky = entry.round.n, tier == "lucky"
   local wedge = WheelRules.roll(Rng.seed(os.time(), player.UserId, WheelRules.spinId(today, n) + math.floor((os.clock() % 1) * 2 ^ 20)), lucky)
   local coins = 0
   Profiles.apply(player, "wheelSpin", function(p)
   	local out, _, paid = WheelRules.award(p, today, n, wedge)
   	coins = paid -- the first (in-memory) application sets it; the re-apply does not run here
   	return out
   end)
   ```
   `today` is the day of the finish (a capped player's new day does not reopen an ineligible round, because `eligible` was fixed at the start). Then `fxTo(player, "wheelOver", { score, tier, spinsLeft })` and `fxTo(player, "wheelSpin", { wedge, lucky, spinId, coins, spinsLeft })` with `spinsLeft` from the profile after the apply. If the session went offline in between, the notice is `UNSAVED_TEXT` as in Dash. On `tier == "none"` only `wheelOver`.
2. Else, with the player's root: `WheelRules.sample`; each `catch` event: `fxTo(player, "wheelCatch", { i, kind = drop, score })`.

Order matters for the day: `today` comes from the tick's `os.time()` (the same value `fastTick` passes), not from the round.

### 3.2 `GardenServer` changes

`REQUEST_ARGS.wheelStart = false`; the router returns `Wheel.start(player)`. `home` calls `Wheel.leave(player)` (after `Dash.leave`). `onLeave` calls `Wheel.leave`. `fastTick` ends with `guarded("wheel tick", function() Wheel.step(roots, today) end)` after the Dash tick. `BindToClose` calls `Wheel.close()` beside `Dash.close()`. The stand prompt's `Triggered` goes through `admit` like the ready pad. `src/garden/CLAUDE.md` gets the two files in its table and one "must stay true" line: "A wheel outcome comes only from `WheelRules` on server samples; `Wheel.leave` grants nothing; a spin is one `Profiles.apply` with `WheelRules.award`."

### 3.3 `WheelWorld.luau`

`WheelWorld.build(): { prompt: ProximityPrompt, folder: Folder }`, called by `Wheel` at require time after `World.build` (as `DashWorld`). Under `Workspace.Garden.Wheel`: a 30 × 30 grass part at `centre`, a picket fence of parts (0.4 wide, 2.5 tall posts every 3 studs, two 6-stud gaps on the +z side), the trunk (a collidable Cylinder radius 2, 6 tall) with `Props.sakura` as the canopy fallback swapped for `wheel_tree` by `Models.night`, the stand: a Wood post and a Cylinder disc fallback at `stand` + (0, 5, 0) swapped for `wheel_stand`, and a transparent 6 × 0.2 × 6 pad at `stand` carrying the prompt and a `BillboardGui` (`StudsOffset` (0, 9, 0), `MaxDistance` 100) whose `TextLabel` is named `SpinsLabel` and left empty: the client writes it. Decor pieces use `DashWorld`'s `decor` pattern (`CanCollide`, `CanQuery`, `CanTouch` false). The `Parts` attribute budget check from `DashWorld.build` is repeated. The disc that spins is **client-side** (`WheelFx` clones `wheel_disc` or builds the wedge fallback); the server's disc fallback is a plain decor cylinder so a client without the model still sees a wheel.

## 4. `Fx` payloads (all `fxTo` the one player; display only)

| `kind` | `data` | Sent when |
|---|---|---|
| `wheelStart` | `{ seed, startAt, endAt, practice, spinsLeft }` | a round starts; `startAt`, `endAt` server times; `practice` true when the round cannot earn a spin |
| `wheelCatch` | `{ i, kind, score }` | the server caught drop `i` (`"pink"`, `"gold"`, `"cone"`); `score` after |
| `wheelOver` | `{ score, tier, spinsLeft }` | the round ended; `tier` `"none"`, `"spin"` or `"lucky"` |
| `wheelSpin` | `{ wedge, lucky, spinId, coins, spinsLeft }` | right after `wheelOver` when `tier ~= "none"`; the prize is already applied; `coins` 0 unless the Coins wedge |

No new `GardenStatus` field and no new attribute: `wheelToday` is in `Profile`.

## 5. Client: `WheelFx.client.luau`

Sends nothing. Modelled on `DashFx`.

- **Petals:** on `wheelStart`, `drops = WheelRules.schedule(seed, startAt)` (the same pure function the server used). Each Heartbeat with `now = GetServerTimeNow()`: a drop with `at <= now` and not resolved gets a clone (`petal_pink`, `petal_gold`, `pinecone` from `NightModels`, else the part fallback) at `(x, centre.y + canopy - fall × (now - at) + sway, z)`, `sway` a cosmetic sine under 0.5 studs in x; below `centre.y + 0.3` it settles (petal: lies flat and fades over 2 s; pinecone: a small roll and fade). On `wheelCatch { i }` the clone tweens to the basket in 0.15 s and a "+1" / "+3" / "−2" floats up (`UI.PINK`, `UI.GOLD`, brown; never red). A catch with no clone yet (late join of the Fx) is just the float.
- **Basket:** a `wheel_basket` clone (or Cylinder) welded to the local character's right hand (`RightHand` or `Right Arm`) for the round; removed on `wheelOver`.
- **Round HUD:** score, timer from `endAt`, the progress bar with the 12 and 24 marks, "N spins left today" or "Practice". Hidden outside a round. `autoScale` as the Dash HUD.
- **End card:** 3 s or tap: "Nice catch! 17 petals"; then the wheel panel (tier `spin` or `lucky`), or "Nice try, play again", or "Practice round". Never near-miss text.
- **Wheel panel:** a `ViewportFrame` or a flat `ImageLabel` disc with 8 wedges in `EGG_COLOURS` pairs and `UI.GOLD` for Coins, pointer at the top, odds columns under it (`HatchRules.percent`), SPIN button (gamepad A). SPIN starts the pre-decided animation: `wheelSpin` has already arrived (it follows `wheelOver` in the same step; the client waits for it before enabling SPIN, with a 2 s fallback that enables it anyway and shows the result on arrival). Angle: 4 full turns + the wedge's centre + a random offset within 80% of the wedge, `Quint` ease out over 3.5 s; `whoosh` at the start, `chime` at the stop, `fanfare` and a burst for `celestial` and `aurora`. Result line: "<Egg name>! Saved with your prize eggs. Open DASH to plant it." or "+<coins> coins". No ticking while it slows; the disc never backs up.
- **Stand label:** `SpinsLabel.Text` from the local `Profile` attribute (`wheelToday`) and `ProfileOnline`: "3 spins left today" … "All 3 spins used today · practice rounds open" / "Saving is off on this server · practice only". Updated on the attribute's change and once a minute (day rollover).
- **Sounds:** W7.2, all through `ClientState.sound`, silent with `sfx` off.
- **Idle look:** outside a round the disc turns slowly (0.1 turns/s) so the stand reads as a wheel.

## 6. Models (`GardenAssets`, GARDEN-044; architecture 9 contract points apply)

| Name | Where | Target size (studs) | How code uses it | Fallback |
|---|---|---|---|---|
| `wheel_stand` | server, `WheelWorld` | 7 × 8 × 2, pointer at the top centre | decor; `Models.night` at `stand`, yaw 0 facing +z | Wood post and board |
| `wheel_disc` | client, `WheelFx` | 6 across, 0.6 thick, bounding box centre on the axle | cloned from `NightModels`, pivoted at the stand's axle (`stand` + (0, 5, −0.5)), rotated about its own z by the client | Cylinder with 8 wedge parts |
| `wheel_basket` | client | 1.6 across | welded to the right hand | Cylinder |
| `petal_pink`, `petal_gold` | client | 1.2 across, under 100 tris | one clone per falling drop | flattened Ball |
| `pinecone` | client | 1.0 tall, under 200 tris | one clone per falling drop | brown Ball |
| `wheel_tree` | server | 24 canopy, 20 tall, trunk at the x, z centre | decor; replaces the `Props.sakura` fallback | `Props.sakura` |

Register rows in `docs/assets/register.md` before any id is used (rule 9); nil ids keep the fallbacks.
