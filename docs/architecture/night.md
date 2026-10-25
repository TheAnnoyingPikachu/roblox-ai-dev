# Hundred Demon Night: architecture (v0.1)

Owner: A09. Inputs: `docs/game-design/game3-gdd.md` (the GDD; section letters below refer to it) and `docs/decisions/0007-hundred-demon-night.md` (save schema, economy, remotes). If this file and the GDD disagree on a rule, the GDD wins and this file is fixed; the resolutions in section 7 are the exception (they settle what the GDD leaves open).

## 1. Place, files and who owns them

Rojo project `night.project.json`:

| Instance | Source |
|---|---|
| `ReplicatedStorage.Shared` | `src/shared` (pure modules, shared with the other games) |
| `ServerScriptService.Night` | `src/night` |
| `ServerScriptService.Night.Models` | `src/relay/Models.luau`, **required in place** |
| `ServerScriptService.Night.Props` | `src/relay/Props.luau`, **required in place** |
| `StarterPlayer.StarterPlayerScripts.NightClient` | `src/night-client` |
| `Workspace.SpawnLocation` | at (0, 0.6, 80), the entrance (GDD I1) |

`src/night` and `src/night-client` hold a `.gitkeep` so the project builds in CI before the scripts exist; delete it when the first script lands. Never add a `Models.luau` or `Props.luau` to `src/night` (it would collide with the in-place mapping).

### Reused Relay files

| Relay file | Night | Notes |
|---|---|---|
| `src/shared/StyleRules.luau` | required in place | NIGHT-003 adds the combat events to `POINTS` (section 3.9). Relay's entries and behaviour unchanged. |
| `src/shared/ProgressRules.luau` | required by Relay only | NIGHT-003 rewrites its body to delegate to `MetaRules`; public API unchanged (decision 0007). |
| `src/relay/Models.luau` | required in place | NIGHT-004 adds the 5 new mesh entries (skull, hand, camphor, shrineHall, lanternYokai) after their register rows exist. Adding entries does not change Relay. |
| `src/relay/Props.luau` | required in place, unchanged | `part`, `pillar`, `label`, `torii`, `lantern`, `sakura`, `demonGate`. Night-only builders go in `Arena.luau`. |
| `src/relay/Profiles.luau` | **copied** to `src/night/Profiles.luau` | New stores, `NightProgress` instead of `ProgressRules`, no remote of its own (section 4.2). |
| `src/relay-client/Menu.client.luau` | **copied** (forked) to `src/night-client/Menu.client.luau` | Same look and panels; Night panel, Locker tabs, NightStatus. |
| `src/relay-client/Movement.client.luau` | **copied** to `src/night-client/Movement.client.luau` | Launch and boost pads removed; local style meter removed (the meter is server-side now); dash also fires `Combat("dash")` and `ClientState.Dashed`. |
| `src/relay-client/CameraFx.client.luau` | **copied** to `src/night-client/CameraFx.client.luau` | Baton spectator and flyover removed; applies `ClientState` shake and FOV kick; Victory podium camera. |
| `src/relay/Course.luau`, `Scenery.luau`, `RelayServer.server.luau`, `RelayRules.luau`, `src/relay-client/StatusBar.client.luau` | not used | `Scenery.lighting` is a pattern to copy into `Arena.luau`, not a dependency. |

Every file under `src/relay` and `src/relay-client` stays byte-identical except the new `Models.luau` entries.

### File ownership by task

| Task | Writes |
|---|---|
| NIGHT-003 | `src/shared/{Rng,CombatRules,WaveRules,BossRules,BlessingRules,RunRules,MetaRules,NightProgress}.luau`, `src/shared/ProgressRules.luau` (body only), `src/shared/StyleRules.luau` (new `POINTS` only), `tests/<Module>.spec.luau` for the 8 new modules, `tests/run.luau` (`SPECS`) |
| NIGHT-004 | `src/night/*`, `src/relay/Models.luau` (new entries only), `docs/assets/register.md` (mesh and SFX rows) |
| NIGHT-005 | `src/night-client/*` |

NIGHT-004 and NIGHT-005 code against the signatures in section 3 and may start with stubs; NIGHT-003 must not change a signature without updating this file in the same PR.

## 2. Conventions for the pure modules

- `--!strict`, no Roblox globals (`Vector3`, `CFrame`, `Instance`, `game`, `task`, `os.clock`, `math.random`, `Random`). Times are plain seconds passed in by the caller (`t`, the server's `os.clock()`); days are `MetaRules.dayOf(os.time())` passed in.
- Shared modules require each other by string: `require("./CombatRules")` (works in Lune and in Roblox, as `SaveRules` does).
- Functions do not mutate their inputs; they return new tables (as `ProgressRules`). The server keeps the returned value.
- Positions are `Vec3 = { x: number, y: number, z: number }` (defined in `CombatRules`); the server converts with `{ x = v.X, y = v.Y, z = v.Z }`. "Horizontal" means the x, z plane. North is −z.
- Rounding: `round(x) = floor(x + 0.5 + 1e-9)`; every other `floor` of a product is `floor(x + 1e-9)`.
- Dependency graph (no cycles): `Rng`; `CombatRules`; `StyleRules`; `MetaRules`; `WaveRules → Rng, CombatRules`; `BossRules → CombatRules`; `BlessingRules → Rng`; `RunRules → Rng, BlessingRules, CombatRules`; `NightProgress → MetaRules, CombatRules`; `ProgressRules → MetaRules`.

## 3. Pure modules: exact signatures

Constants are listed with their values; every constant in the GDD tables exists as data (not inlined) so tests and scripts read the same numbers.

### 3.1 `Rng`

```luau
export type State = number -- integer in [1, 2^32 - 1]

Rng.seed(a: number, b: number?, c: number?): State -- mixes up to 3 integers; same inputs, same state
Rng.next(state: State): (number, State) -- value in [0, 1)
Rng.int(state: State, lo: number, hi: number): (number, State) -- integer in [lo, hi], lo <= hi
```

xorshift32 (shifts 13, 17, 5) on `bit32`; a zero state becomes `0x9E3779B9`. `next` returns `state' / 2^32`. `int` = `lo + floor(value × (hi − lo + 1))`.

### 3.2 `CombatRules`

```luau
export type Vec3 = { x: number, y: number, z: number }

export type Weapon = {
	id: string, -- "katana" | "kodachi" | "nodachi"
	name: string,
	level: number, -- unlock level
	damage: { number }, -- per step; #damage = steps
	interval: number,
	window: number,
	recovery: number,
	range: number,
	arc: number, -- degrees
	knockback: number, -- finisher, studs
}

export type Swing = { range: number, arc: number, band: number } -- band = max |dy|
export type Target = { id: number, pos: Vec3, radius: number, mult: number } -- mult: boss part multiplier, 1 otherwise

export type Fighter = {
	weapon: string,
	step: number, -- last accepted combo step, 0 = none this run
	attackAt: number, -- time of last accepted attack, -math.huge if none
	skillAt: number,
	dashAt: number,
	gauge: number, -- 0..100, fractions kept
	triggerUntil: number,
	guardUntil: number, -- attacks refused while t < guardUntil
	requests: { number }, -- Combat event times in the last 1.0 s
}

CombatRules.WEAPONS: { Weapon } -- C1 table, katana first
CombatRules.SKILL = { cooldown = 5, damage = 20, range = 8, arc = 120, band = 8, airborne = 1.2, shockwaveRange = 10 }
CombatRules.ATTACK_BAND = 6
CombatRules.POINT_BLANK = 1
CombatRules.DASH = { tolerance = 0.95, invulnerable = 0.35 }
CombatRules.TRIGGER = { cost = 100, duration = 8, damage = 1.4, speed = 1.2, healPerHit = 2 }
CombatRules.AIRBORNE_DAMAGE = 1.25
CombatRules.STAGGER = 0.4
CombatRules.KNOCKBACK_TIME = 0.25
CombatRules.ARMOURED_KNOCKBACK = 0.3
CombatRules.CONTACT = { reach = 2.5, band = 5, interval = 1.0 }
CombatRules.GUARD = { distance = 12, lockout = 1.0 }
CombatRules.RATE = { count = 20, window = 1.0 }

CombatRules.weapon(id: string): Weapon?
CombatRules.newFighter(weapon: string): Fighter
CombatRules.allowRequest(f: Fighter, t: number): (boolean, Fighter) -- C10 rate limit; records t either way
CombatRules.attack(f: Fighter, t: number): (boolean, Fighter, number) -- accepted, new fighter, step (C1); step 0 when refused
CombatRules.isFinisher(f: Fighter): boolean -- the last accepted step is the weapon's last
CombatRules.skill(f: Fighter, t: number, cooldown: number): (boolean, Fighter)
CombatRules.dash(f: Fighter, t: number): (boolean, Fighter) -- t - dashAt >= 0.95
CombatRules.trigger(f: Fighter, t: number, duration: number): (boolean, Fighter) -- gauge >= 100 and not active; gauge -> 0
CombatRules.triggerActive(f: Fighter, t: number): boolean
CombatRules.gain(f: Fighter, damageDealt: number, gaugeRate: number, t: number): Fighter -- + damage / 4 * rate, cap 100, none while active
CombatRules.guard(f: Fighter, previous: Vec3, current: Vec3, t: number): Fighter -- horizontal move > 12 sets guardUntil = t + 1
CombatRules.guarded(f: Fighter, t: number): boolean

CombatRules.attackSwing(weapon: Weapon): Swing
CombatRules.skillSwing(shockwave: boolean): Swing -- shockwave: range 10, arc 360
CombatRules.inSwing(origin: Vec3, facing: Vec3, target: Target, swing: Swing): boolean -- C2
CombatRules.hits(origin: Vec3, facing: Vec3, targets: { Target }, swing: Swing): { Target } -- input order; one per id, the highest mult
CombatRules.damage(base: number, damageMult: number, airborne: boolean, trigger: boolean, partMult: number): number -- C6, partMult last inside the round
CombatRules.reaction(class: string, finisher: boolean, trigger: boolean): (boolean, number) -- class "normal"|"armoured"|"boss" -> (staggers, knockback multiplier)
CombatRules.canLaunch(class: string): boolean -- "normal" only
CombatRules.contact(enemyPos: Vec3, enemyRadius: number, playerPos: Vec3): boolean -- C8 reach and band
CombatRules.flatDistance(a: Vec3, b: Vec3): number
CombatRules.nearSegment(a: Vec3, b: Vec3, pos: Vec3, width: number): boolean -- horizontal distance from pos to segment ab <= width
```

`facing` is the root LookVector; `inSwing` flattens it. Projectiles and dash paths test a target with `nearSegment(a, b, target.pos, width + target.radius)`; players count as radius 0.

### 3.3 `WaveRules`

```luau
export type Stats = {
	kind: string, -- "wisp" | "lantern" | "kasa" | "oni" | "general" | "boss"
	name: string,
	cost: number, -- 0 for general and boss
	hp: number,
	speed: number,
	contact: number, -- contact damage, 0 if none
	attack: number, -- fireball, dash, slam damage; 0 if none (boss attacks live in BossRules)
	radius: number,
	class: string, -- "normal" | "armoured" | "boss"
}

export type Spawn = { kind: string, speedMult: number }

export type Enemy = {
	id: number,
	kind: string,
	class: string,
	hp: number,
	maxHp: number,
	contact: number, -- scaled
	attack: number, -- scaled
	speed: number, -- after speedMult
	radius: number,
	pos: Vec3, -- written by the server from the model each tick
	target: number?, -- participant UserId
	retargetAt: number,
	nearAt: number, -- last time within 30 studs of any participant
	staggerUntil: number,
	airborneUntil: number,
	nextAttackAt: number,
	telegraphUntil: number, -- 0 when not telegraphing
	owner: number?, -- id of the general or boss that summoned it
}

export type Candidate = { userId: number, pos: Vec3 } -- not downed, in join order

WaveRules.WAVES = 10
WaveRules.ENEMIES: { [string]: Stats } -- D1 (radii from C2)
WaveRules.BEHAVIOUR = {
	wisp = { hover = 3 },
	lantern = { keepMin = 18, keepMax = 28, period = 3.5, range = 40, telegraph = 0.8, projectileSpeed = 35, projectileRadius = 2 },
	kasa = { period = 4, range = 30, telegraph = 1.0, length = 30, speed = 60, width = 3 },
	oni = { range = 8, radius = 9, telegraph = 1.2, period = 3 },
	general = { range = 10, radius = 12, telegraph = 1.0, period = 3, summonEvery = 10, summonCount = 4, summonCap = 8 },
}
WaveRules.BASE_BUDGET: { [number]: number } -- [2]=8, [3]=11, [4]=14, [6]=18, [7]=21, [8]=24, [9]=28
WaveRules.INTRO: { [number]: string } -- [2]="lantern", [3]="kasa", [4]="oni"
WaveRules.TUTORIAL_SPEED = 0.7
WaveRules.GATES: { Vec3 } -- 1 SE (60,0,60), 2 NW (-60,0,-60), 3 NE (60,0,-60), 4 SW (-60,0,60)
WaveRules.SPAWN_INTERVAL = 0.5
WaveRules.RETARGET = 1.0
WaveRules.STUCK = { radius = 30, time = 20 }

WaveRules.budget(w: number, n: number): number -- 0 for waves 1, 5, 10
WaveRules.allowed(w: number): { string } -- in the order wisp, lantern, kasa, oni
WaveRules.gatesOpen(w: number): number -- 1 for wave 1, 2 for waves 2-3, 4 from wave 4
WaveRules.oniCap(w: number, n: number): number
WaveRules.composition(w: number, n: number, seed: Rng.State): { Spawn } -- wave 1: wisps; 5: { general }; 10: { boss }
WaveRules.gateFor(i: number, open: number): number -- ((i - 1) mod open) + 1
WaveRules.aliveCap(n: number): number -- 12 + 4(n - 1); summons do not count
WaveRules.hp(kind: string, n: number, tier: number): number -- D5
WaveRules.damage(base: number, tier: number): number -- D5, also used for boss attacks
WaveRules.newEnemy(id: number, kind: string, n: number, tier: number, pos: Vec3, t: number, speedMult: number?, owner: number?): Enemy
WaveRules.pickTarget(pos: Vec3, candidates: { Candidate }): number? -- nearest; ties to the earlier candidate
WaveRules.canAct(e: Enemy, t: number): boolean -- not staggered and not airborne
WaveRules.isStuck(e: Enemy, t: number): boolean -- t - nearAt >= 20
WaveRules.nearestGate(pos: Vec3): number
```

Composition seed for wave `w` is `Rng.seed(run.seed, 0, w)` (join index 0 is reserved for waves).

### 3.4 `BossRules`

```luau
export type State = {
	phase: number, -- 1..3
	index: number, -- next position in the phase's sequence
	nextAt: number, -- earliest time for the next attack
	staggerUntil: number,
	turn: number, -- round-robin target counter
}

BossRules.RISE = 3 -- seconds from spawn to the first attack
BossRules.GAP = 2.5
BossRules.STAGGER = 4
BossRules.SEQUENCES = { { "slam", "slam", "sweep" }, { "slam", "sweep", "slam" }, { "double", "sweep", "sweep" } }
BossRules.SLAM = { radius = 10, follow = 1.5, lock = 0.6, damage = 30 }
BossRules.SWEEP = { telegraph = 1.5, width = 4, feet = 4, damage = 25, halfLength = 100 }
BossRules.SUMMON = { wisp = 6, lantern = 2 }
BossRules.PART = { hand = 1.0, skull = 1.5, staggeredSkull = 2.0 }

BossRules.new(t: number): State
BossRules.phaseFor(hp: number, maxHp: number): number -- > 0.66 -> 1, >= 0.33 -> 2, else 3
BossRules.next(s: State, hp: number, maxHp: number, t: number): (string?, State) -- nil before nextAt; "summon" once on entering a higher phase, then that phase's sequence from the start, looping
BossRules.resolved(s: State, attack: string, t: number): State -- slam/double: staggerUntil = t + 4; nextAt = max(t + 2.5, staggerUntil)
BossRules.staggered(s: State, t: number): boolean
BossRules.partMult(part: string, staggered: boolean): number -- "hand" | "skull"
BossRules.targets(s: State, ids: { number }, count: number): ({ number }, State) -- round robin over not-downed ids in join order; distinct when #ids >= count
BossRules.sweepLine(target: Vec3): (Vec3, Vec3) -- west-east line at the target's z
BossRules.sweepHit(a: Vec3, b: Vec3, pos: Vec3, feetHeight: number): boolean -- within 4 of the line and feet < 4 above ground
```

### 3.5 `BlessingRules`

```luau
export type Blessing = { id: string, name: string, max: number, party: boolean, text: string }
export type Stacks = { [string]: number }
export type Modifiers = {
	damageMult: number,
	speedMult: number,
	maxHp: number,
	gaugeRate: number,
	triggerDuration: number,
	charms: number,
	risingCooldown: number,
	healOnKill: number,
	thunderDamage: number,
	foxfire: boolean,
	shockwave: boolean,
	link: boolean,
}

BlessingRules.POOL: { Blessing } -- E table order
BlessingRules.FOXFIRE = { damage = 20, range = 30, speed = 60, width = 2 }
BlessingRules.THUNDER = { width = 3, window = 0.35 }

BlessingRules.get(id: string): Blessing?
BlessingRules.eligible(stacks: Stacks, partySize: number): { string } -- POOL order
BlessingRules.offer(stacks: Stacks, partySize: number, seed: Rng.State): { string } -- up to 3 distinct ids
BlessingRules.apply(stacks: Stacks, id: string): (Stacks, boolean) -- false if unknown or at max
BlessingRules.modifiers(stacks: Stacks): Modifiers -- E formulas
```

Offer seed for participant `j` at break `w`: `Rng.seed(run.seed, j, w)`. Draw: `Rng.int(1, #remaining)` and remove, three times.

### 3.6 `RunRules`

```luau
export type Participant = {
	userId: number,
	joinIndex: number, -- 1.., renumbered in join order when a new run starts
	hp: number,
	maxHp: number,
	charms: number,
	downed: boolean,
	reviveAt: number?, -- pending charm revive
	helpTime: number, -- seconds an ally has stood within 6 studs, 0 when none
	invulnUntil: number, -- revive invulnerability
	dashUntil: number, -- dash invulnerability
	stacks: BlessingRules.Stacks,
	offer: { string }, -- this break's offer, {} otherwise
	picked: boolean,
	clears: number, -- waves cleared in this run (1 after the first: count it as a run)
}

export type Run = {
	state: string, -- "Idle" | "Countdown" | "Wave" | "Break" | "Victory" | "Defeat"
	wave: number, -- 0 before wave 1
	tier: number,
	seed: number,
	host: number?,
	endsAt: number, -- end of Countdown, Break, Victory, Defeat; 0 otherwise
	n: number, -- participants at the start of the current wave
	participants: { Participant }, -- join order
}

export type TickInput = {
	t: number,
	dt: number,
	cleared: boolean, -- the current wave is cleared (server: Enemies.cleared())
	hostTier: number, -- the current host's clamped tier, used when a new Countdown starts
	seed: number, -- fresh seed, used when a new Countdown starts
	positions: { [number]: CombatRules.Vec3 }, -- participant roots by UserId
}

export type Event = { kind: string, wave: number?, n: number?, userId: number?, by: number? }
-- kinds: "countdown", "wave" (wave, n), "cleared" (wave, n), "break" (wave), "victory", "defeat",
-- "idle", "down" (userId), "revive" (userId, by: helper UserId or nil for a charm), "host" (userId)

export type HitResult = string -- "hit" | "down" | "dodge" | "immune" | "ignored"

RunRules.MAX_PARTY = 6
RunRules.COUNTDOWN = 3
RunRules.BREAK = 12
RunRules.END = 8 -- Victory and Defeat
RunRules.BASE_HP = 100
RunRules.CHARM = { delay = 3, hp = 0.5 }
RunRules.ALLY = { radius = 6, time = 2, hp = 0.4 }
RunRules.REVIVE_INVULN = 2
RunRules.BREAK_HEAL = { heal = 25, stand = 0.5 }

RunRules.new(): Run
RunRules.find(run: Run, userId: number): Participant?
RunRules.play(run: Run, userId: number, tier: number, seed: number, t: number): (Run, boolean) -- B2; tier and seed used only from Idle; catch-up blessings applied here
RunRules.catchUpCount(run: Run): number -- w - 1 in Wave(w) or Break(w), else 0
RunRules.leave(run: Run, userId: number): (Run, { Event })
RunRules.tick(run: Run, input: TickInput): (Run, { Event })
RunRules.damage(run: Run, userId: number, amount: number, t: number): (Run, HitResult) -- "dodge" when blocked only by dashUntil
RunRules.heal(run: Run, userId: number, amount: number): Run -- capped at maxHp, no effect when downed
RunRules.dash(run: Run, userId: number, t: number): Run -- dashUntil = t + 0.35
RunRules.pick(run: Run, userId: number, choice: number): (Run, boolean)
RunRules.isAlive(run: Run, userId: number): boolean -- participant and not downed
RunRules.defeated(run: Run): boolean -- every participant downed and none with reviveAt
```

`tick` does, in this order: timers (Countdown → Wave(1); Break end → auto-pick offer 1, Wave(w+1); Victory/Defeat end → Countdown with remaining participants reset, or Idle); charm revives due; ally revives from `positions` and `dt`; in Wave, `cleared` → "cleared" then Break(w) or Victory; in Wave, `defeated` → Defeat. At Break start it sets offers and applies the break heal. Applying a blessing (pick, auto-pick, catch-up) recomputes `maxHp`, heals 20 for Iron Skin and adds a charm for Nine Tails. Spirit Link heals both to max when the reviver or the revived has it.

### 3.7 `MetaRules`

```luau
export type Cosmetic = {
	id: string,
	name: string,
	slot: string, -- the profile field it equips into: "trail" (Relay), "blade" | "mask" (Night)
	colours: { { number } }, -- RGB 0-255 stops
	level: number?,
	wins: number?,
	tier: number?, -- bestTier needed
	price: number?,
}

export type Quest = { id: string, label: string, stat: string, goal: number, reward: number }

export type Meta = { -- fields every game's profile has (bestTier optional)
	xp: number,
	coins: number,
	wins: number,
	bestTier: number?,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}

export type Config<P> = {
	cosmetics: { Cosmetic },
	slots: { [string]: string }, -- slot field -> default cosmetic id
	quests: { Quest },
	daily: { number },
	weekly: { days: number, reward: number },
	sanitize: (record: any) -> P, -- the game's full sanitiser; also used to clone
}

MetaRules.MAX_LEVEL = 50
MetaRules.MAX_XP = 1_000_000
MetaRules.MAX_COINS = 10_000_000
MetaRules.MAX_COUNT = 1_000_000

MetaRules.dayOf(unixSeconds: number): number
MetaRules.weekOf(day: number): number
MetaRules.levelFor(xp: number): number
MetaRules.xpForLevel(level: number): number
MetaRules.count(value: any, cap: number): number -- sanitise helper (0 for non-numbers, NaN, inf)
MetaRules.dayNumber(value: any): number -- sanitise helper (-1 for invalid)
MetaRules.sanitizeMeta<P>(config: Config<P>, record: any, into: P): P -- fills the Meta fields and slot fallbacks into `into`; call after game fields such as bestTier are set
MetaRules.cosmetic<P>(config: Config<P>, id: string): Cosmetic?
MetaRules.isUnlocked<P>(config: Config<P>, profile: P, id: string): boolean
MetaRules.questsFor(pool: { Quest }, today: number): { Quest } -- 3 distinct, any pool size >= 3
MetaRules.addProgress<P>(config: Config<P>, profile: P, today: number, deltas: { [string]: number }): P -- resets quests on a new day, then adds
MetaRules.login<P>(config: Config<P>, profile: P, today: number): P
MetaRules.nextDaily<P>(profile: P, today: number): number?
MetaRules.dailyReward<P>(config: Config<P>, streak: number): number
MetaRules.claimDaily<P>(config: Config<P>, profile: P, today: number): (P, boolean, number)
MetaRules.canClaimWeekly<P>(config: Config<P>, profile: P, today: number): boolean
MetaRules.claimWeekly<P>(config: Config<P>, profile: P, today: number): (P, boolean, number)
MetaRules.claimQuest<P>(config: Config<P>, profile: P, today: number, questId: string): (P, boolean, number)
MetaRules.buy<P>(config: Config<P>, profile: P, id: string): (P, boolean)
MetaRules.equip<P>(config: Config<P>, profile: P, id: string): (P, boolean) -- sets profile[cosmetic.slot]
```

Inside, `P` is cast to `Meta` (`(profile :: any) :: Meta`); a game's profile type must contain every `Meta` field. `ProgressRules` keeps all current exports (`Profile`, `MatchResult`, `Trail`, `Quest`, the constants, `TRAILS`, `QUEST_POOL`, `DAILY`, `WEEKLY` and every function) as thin wrappers over `MetaRules` with a Relay `Config<Profile>`; `matchRewards` and `applyMatch` stay Relay-specific (the latter uses `addProgress`).

### 3.8 `NightProgress`

```luau
export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number, -- souls
	wins: number,
	runs: number,
	waves: number,
	kills: number,
	bestTier: number,
	tierPick: number,
	weapon: string,
	blade: string,
	mask: string,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}

export type Tally = { kills: number, launches: number, triggers: number, bestRank: number } -- bestRank: StyleRules rank index, 1 = D

export type WaveResult = { wave: number, tier: number, n: number, first: boolean, tally: Tally }

NightProgress.SCHEMA_VERSION = 1
NightProgress.MAX_TIER = 5
NightProgress.TIERS = { "Crescent", "Half", "Full", "Blood", "Eclipse" }
NightProgress.STYLE_MULT = { 1.0, 1.1, 1.2, 1.3, 1.5, 1.75, 2.0 } -- by rank index, same length as StyleRules.RANKS
NightProgress.COSMETICS: { MetaRules.Cosmetic } -- H4; blade colours reuse Relay's trail colours where the id matches
NightProgress.QUEST_POOL: { MetaRules.Quest } -- H5
NightProgress.CONFIG: MetaRules.Config<Profile> -- daily and weekly amounts as decision 0006

NightProgress.defaults(): Profile
NightProgress.sanitize(record: any): Profile -- H7
NightProgress.newTally(): Tally
NightProgress.waveRewards(wave: number, tier: number, n: number, bestRank: number): (number, number) -- XP, souls (F2)
NightProgress.victoryRewards(tier: number): (number, number)
NightProgress.applyWave(p: Profile, result: WaveResult, today: number): (Profile, number, number) -- rewards + F3 stats + quest progress
NightProgress.applyVictory(p: Profile, tier: number, today: number): (Profile, number, number)
NightProgress.maxTier(p: Profile): number -- min(5, bestTier + 1)
NightProgress.tierFor(p: Profile): number -- tierPick clamped to maxTier
NightProgress.setTier(p: Profile, tier: number): (Profile, boolean) -- refused if locked or not 1..5
NightProgress.weaponUnlocked(p: Profile, id: string): boolean
NightProgress.equipWeapon(p: Profile, id: string): (Profile, boolean)
NightProgress.levelFor(xp: number): number
NightProgress.questsFor(today: number): { MetaRules.Quest }
NightProgress.isUnlocked(p: Profile, id: string): boolean
NightProgress.login(p: Profile, today: number): Profile
NightProgress.claimDaily(p: Profile, today: number): (Profile, boolean, number)
NightProgress.claimWeekly(p: Profile, today: number): (Profile, boolean, number)
NightProgress.claimQuest(p: Profile, today: number, questId: string): (Profile, boolean, number)
NightProgress.buyCosmetic(p: Profile, id: string): (Profile, boolean)
NightProgress.equipCosmetic(p: Profile, id: string): (Profile, boolean)
```

Quest stat keys: `runs`, `waves`, `kills`, `launches`, `triggers`, `rankS`, `generals`, `bosses`.

### 3.9 `StyleRules` additions

New `POINTS` keys (Relay's stay untouched): `hit = 3`, `finisher = 8`, `launchEnemy = 10`, `airHit = 6`, `dodge = 15`, `kill = 5`, `trigger = 20`. (Relay's `launch = 14` is the launch pad, hence the new name.) One swing scores one event: `launchEnemy` for a skill that launched at least one enemy, else `finisher`, else `airHit` if any hit target was airborne, else `hit`; nothing if it hit nothing. Each kill scores `kill`. A dodge scores once per enemy attack instance. Trigger activation scores `trigger`.

## 4. Server (`src/night`)

### 4.1 Files

| File | Kind | Owns |
|---|---|---|
| `NightServer.server.luau` | Script | Entry point. Requires everything, owns the 10 Hz tick (4.3), routes `Request` (common checks from decision 0007, run actions `play`, `leaveRun`, `pickBlessing`; meta actions to `Profiles.request`), handles RunRules events, publishes `NightStatus` and run attributes, refreshes the leaderboard board every 60 s, PlayerAdded/Removing. |
| `State.luau` | Module | The single mutable server state: `{ run: RunRules.Run, positions: { [number]: CombatRules.Vec3 } }`. Every module reads `State.run` and assigns the value RunRules returns. |
| `Remotes.luau` | Module | Creates `ReplicatedStorage.NightRemotes` (`Request`, `Combat`, `Fx`) and `ReplicatedStorage.NightStatus`; returns them plus `fx(kind: string, data: { [string]: any })` = `Fx:FireAllClients`. |
| `Profiles.luau` | Module | Copied from Relay (4.2). |
| `Combat.luau` | Module | Per-participant `Entry = { fighter: CombatRules.Fighter, style: StyleRules.State, tally: NightProgress.Tally, sample: CombatRules.Vec3? }`; `Combat` remote handler; hit tests against `Enemies.targets()`; damage, gauge, heal-on-hit, kill credit, style; foxfire bolts and Thunder Dash paths; Trigger expiry; walk speed (`24 × speedMult × 1.2 in Trigger`, 0 while downed). |
| `Enemies.luau` | Module | Enemy records (`WaveRules.Enemy`) and their models; wave start, spawn queue, AI, telegraphs, enemy attacks and fireballs, the Oni General, the Gashadokuro (`BossRules`), stuck relocation, `cleared()`. |
| `Gear.luau` | Module | Builds the weapon `Tool` (per weapon, coloured by the blade) and the mask (parts welded to the head); `give(player)`, `strip(player)`. |
| `Arena.luau` | Module | Builds the shrine courtyard (GDD I1), lighting (I2), the leaderboard board; returns the shrine-steps spawn CFrame and the board's `update(rows)`. |

Server module APIs (signatures for cross-file calls):

```luau
-- Profiles.luau
Profiles.Changed: RBXScriptSignal -- (player, profile)
Profiles.load(player: Player)
Profiles.release(player: Player)
Profiles.get(player: Player): NightProgress.Profile?
Profiles.isOnline(player: Player): boolean
Profiles.request(player: Player, action: string, arg: string?): boolean -- claimDaily, claimWeekly, claimQuest, buyCosmetic, equipCosmetic, setTier, equipWeapon
Profiles.recordWave(player: Player, result: NightProgress.WaveResult)
Profiles.recordVictory(player: Player, tier: number)
Profiles.topWins(): { { name: string, wins: number } }

-- Combat.luau
Combat.join(player: Player) -- new Entry with the profile's weapon
Combat.remove(player: Player)
Combat.sample(t: number) -- tick step 1
Combat.step(t: number, dt: number) -- tick step 4
Combat.takeTally(userId: number): NightProgress.Tally -- returns and resets the wave tally
Combat.dodged(userId: number) -- style event from a dodge

-- Enemies.luau
Enemies.startWave(w: number, n: number, tier: number, seed: number, t: number)
Enemies.step(t: number, dt: number): { Hurt } -- Hurt = { userId: number, amount: number, key: string }
Enemies.targets(): { CombatRules.Target } -- boss parts as separate targets with the boss's id and their mult
Enemies.get(id: number): WaveRules.Enemy?
Enemies.damage(id: number, amount: number, by: number, finisher: boolean, trigger: boolean, launch: boolean, from: CombatRules.Vec3, t: number): boolean -- applies reactions; true if killed
Enemies.cleared(): boolean
Enemies.bossFraction(): number?
Enemies.clear()
```

`Hurt.key` identifies the attack instance (`"<enemyId>:<attackNumber>"`, or `"contact:<enemyId>"`), so a player is hit and a dodge is counted at most once per instance.

### 4.2 Profiles (copied from Relay)

Same load (3 tries, offline mode), `apply` re-apply pattern, `publish` and `topWins` as `src/relay/Profiles.luau`, with: stores `NightProfile<suffix>` and `NightWins<suffix>`; `NightProgress` in place of `ProgressRules`; attributes `Profile`, `ProfileOnline`, `LastReward`, `XP`, `Level`, `Coins`, `Weapon`, `Blade`, `Mask`; leaderstats `Level` and `Nights`; no remote folder of its own (rate limit and type checks move to `NightServer`'s router, which calls `Profiles.request` only after they pass). `recordWave` and `recordVictory` set `LastReward` like `recordMatch`. The ordered store is written on Victory.

### 4.3 Server tick (10 Hz)

`RunService.Heartbeat` accumulates `dt`; every 0.1 s, with `t = os.clock()`:

1. `Combat.sample(t)`: read each participant's `HumanoidRootPart` into `State.positions`; run the teleport guard.
2. `hurts = Enemies.step(t, 0.1)`: spawn queue (one per 0.5 s while under `aliveCap`, gate rotation), read model positions into records, retarget every 1.0 s, stuck relocation, movement targets, telegraphs and attacks, boss pattern, fireballs, contact checks.
3. For each hurt: `State.run, result = RunRules.damage(...)`; `"dodge"` → `Combat.dodged`; `"hit"`/`"down"` → reset style, `Fx("hurt")` / `Fx("down")`.
4. `Combat.step(t, 0.1)`: foxfire bolts, Thunder Dash paths that complete, Trigger expiry, style decay and per-wave best rank, walk speed.
5. `State.run, events = RunRules.tick(State.run, { t, dt = 0.1, cleared = Enemies.cleared(), hostTier, seed, positions = State.positions })`, then handle events:
   - `countdown`: `Gear.give` and `Combat.join` each participant, move them to the shrine steps.
   - `wave`: `Enemies.startWave(wave, n, tier, Rng.seed(run.seed, 0, wave), t)`.
   - `cleared`: for each participant, `Profiles.recordWave(player, { wave, tier, n, first = p.clears == 1, tally = Combat.takeTally(id) })`.
   - `break`: publish `Offers`. `victory`: `Profiles.recordVictory` for each participant. `defeat`, `idle`: `Enemies.clear()`. `revive`, `down`: `Fx`.
6. Publish: per participant, set `HP`, `MaxHP`, `Gauge`, `StyleRank`, `StylePoints`, `Charms`, `Trigger`, `Blessings`, `Offers` only when the value changed; humanoid health mirrors `HP / MaxHP`. `NightStatus.Value` only when its JSON changed.

`Combat` events and `Request` calls are handled when they arrive, between ticks, against `State.run`. A `play` from Idle passes `NightProgress.tierFor(profile)` and a fresh seed (`Random.new():NextInteger(1, 2^31 - 1)`). A `play` accepted in Countdown, Wave or Break also calls `Gear.give` and `Combat.join` at once (the `countdown` event covers the rest). `leaveRun`, opening the menu and PlayerRemoving call `RunRules.leave`, `Combat.remove` and `Gear.strip`, then handle the returned events.

### 4.4 Enemies on the server

- Pure state: a `WaveRules.Enemy` record per enemy in `Enemies.luau`, keyed by `id` (increasing integer, never reused in a server).
- Model: `Workspace.NightEnemies.<id>`, a `Model` of at most 15 parts, no Humanoid. `PrimaryPart` named `Root` (unanchored, `CanCollide` false, network owner set to the server with `SetNetworkOwner(nil)`); other parts welded and massless. Attributes `Id` (number) and `Kind` (string) on the model. An `AlignPosition` (OneAttachment, `MaxVelocity` = speed, raised for knockback) and an `AlignOrientation` on `Root`; the server writes their targets each tick.
- Airborne: target height +10 for 1.2 s. Stagger: target = current position. Knockback: target pushed `knockback × multiplier` studs away from the attacker over 0.25 s.
- Gashadokuro: `Workspace.NightEnemies.<id>` with `Skull`, `HandL`, `HandR` mesh parts (anchored, tweened), each with attribute `Part` = `"skull"` or `"hand"`; one `Enemy` record.
- Fireballs and foxfire bolts are server tables (position, velocity, radius, life), not parts; the client draws them from `Fx("projectile")`.
- Removal: dead enemies are destroyed after `Fx("kill")`; summons are destroyed when their owner dies; `Enemies.clear()` destroys everything.

## 5. `Fx` payloads

`Fx:FireAllClients(kind: string, data: table)`. `u` = player UserId, `e` = enemy id, `p` = `Vector3`. Clients skip `swing` and `dash` events whose `u` is their own (already predicted).

| `kind` | `data` | Sent when |
|---|---|---|
| `swing` | `{ u, act: "attack" \| "skill" \| "trigger", step: number, fin: boolean }` | a Combat request is accepted |
| `dash` | `{ u, thunder: boolean }` | a dash is accepted |
| `hit` | `{ u, fin: boolean, list: { { e, a: number, p } } }` | one per swing, bolt or thunder path that hits; `a` = damage |
| `kill` | `{ e, u, p }` | an enemy dies (`u` = killing blow) |
| `telegraph` | `{ e, shape: "circle" \| "line" \| "glow", p, q: Vector3?, r: number, dur: number, follow: number? }` | an attack starts its warning; `q` = line end; `follow` = UserId the circle tracks (boss slam) |
| `impact` | `{ e, p, r: number, what: "slam" \| "sweep" \| "dash" }` | the warned attack lands |
| `projectile` | `{ id: number, what: "fireball" \| "foxfire", p, v: Vector3, r: number, life: number }` | spawned |
| `projectileEnd` | `{ id: number, p }` | hit or expired |
| `hurt` | `{ u, a: number, p }` | a player loses HP |
| `dodge` | `{ u, p }` | dash invulnerability blocked an attack |
| `down` | `{ u, p }` | a player is downed |
| `revive` | `{ u, by: number?, p }` | a player stands up (`by` nil = charm or break) |
| `summon` | `{ e, p }` | the general roars or the boss summons |

## 6. Client (`src/night-client`)

| File | Kind | Owns |
|---|---|---|
| `ClientState.luau` | ModuleScript | Client-only settings `{ music, sfx, shake, numbers: boolean }` with a `SettingsChanged` signal; `Dashed` signal (Movement fires, CombatFx and Hud listen); camera requests `shake(seconds: number)` and `fovKick(degrees: number)` consumed by CameraFx. |
| `Menu.client.luau` | LocalScript | Forked Relay menu: title and camera orbit, PLAY panel (tier picker, weapon picker, Invite friends via `SocialService:PromptGameInvite`, START / JOIN NIGHT), Locker (Blade Arts, Masks, Weapons), Rewards, Stats, Settings (writes `ClientState`), toasts, level/XP/souls bar, music and SFX. Sends `Request` only. Opening the menu during a run sends `leaveRun`. |
| `Movement.client.luau` | LocalScript | Copied Relay movement (double jump, dash with afterimages, Ninja animations, speed lines); dash also fires `Combat("dash")`. |
| `CameraFx.client.luau` | LocalScript | Applies `ClientState` shake and FOV kick (if the setting is on); Victory podium camera. |
| `CombatFx.client.luau` | LocalScript | Input for Attack (click/tap, R2), Skill (E, Y), Trigger (R, B) and the touch buttons; soft lock; client prediction (slash arc, blade sweep, `toolanim` StringValue on the equipped Tool, Rising Slash hop); renders every `Fx` kind (hit flash, sparks, damage numbers, telegraphs, projectiles, impacts, spirit-flame markers, Trigger aura on players whose `Trigger` attribute is true). |
| `Hud.client.luau` | LocalScript | HP bar, Trigger gauge, skill and dash cooldown rings (from the client's own sends and `BlessingRules.modifiers` of its `Blessings`), style meter (`StyleRank`, `StylePoints`), wave banner and boss bar (`NightStatus`), charm icons, teammate HP pips, blessing cards (`pickBlessing`, keys 1-3), first-run prompts (`runs = 0`). |

Clients never write server state. The weapon Tool has `ManualActivationOnly = true`; CombatFx reads input itself.

## 7. Resolutions of points the GDD leaves open

1. Boss part multipliers apply inside the C6 rounding as its last factor; one swing hits a boss once, on the reachable part with the highest multiplier.
2. Every `floor`/`round` of a product adds 1e-9 first (F2, C6, D5).
3. Teleport guard and contact distances are horizontal; the guard blocks `attack` and `skill` only.
4. Gate numbering: 1 SE, 2 NW, 3 NE, 4 SW, so two open gates are opposite each other.
5. Oni and Oni General attack at most every 3 s (telegraph start to telegraph start); the general starts a slam within 10 studs. Lantern and kasa periods also run telegraph start to telegraph start.
6. Summons ignore the alive cap and do not count toward clearing; they vanish with their owner.
7. Boss: first attack 3 s after rising; Hand Slam and Double Slam both stagger the skull for 4 s; the next attack waits for `max(GAP, stagger)`; skipping a phase gives one summon; targets rotate round-robin in join order; the sweep line runs west to east at the target's z. Boss attack damage uses the D5 damage scaling.
8. `StyleRules` combat launch event is named `launchEnemy` (Relay's `launch` keeps 14); one style event per swing (section 3.9).
9. `setTier` refuses a locked tier rather than storing it; `equipCosmetic` and `setTier` are allowed during a run (cosmetic / next run).
10. Nine Tails picked mid-run grants its charm at once; Iron Skin heals 20 at once.
11. Composition seeds use join index 0; participants are 1-based and renumbered when a new run starts.
12. A non-nil `arg` to an action without one, and any extra `Combat` argument, are refused.
13. No extra save on leave: every change is written when it happens.
14. Split of the GDD's `CombatFx` into `CombatFx` (input, VFX) and `Hud` (widgets), plus `ClientState` for shared client settings, so no client file passes ~1,000 lines. New attributes `StylePoints`, `Trigger`, `Weapon`, `Blade`, `Mask` added to decision 0007's contract for the meter fill, other players' aura and gear.
15. `Models.luau` and `Props.luau` are mapped in place from `src/relay` instead of copied; Relay's profile and client scripts are copied because their stores, remotes and status differ.
