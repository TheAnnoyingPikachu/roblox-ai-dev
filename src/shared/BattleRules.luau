--!strict
-- Pure Animal Stations wave fights (decisions 0027 to 0032): the player's team against a wave
-- of enemies, on a clock. This is for the waves only: fights between players will work
-- differently and are not designed. Each stat has one job:
--   Health    HP
--   Defence   cuts incoming damage
--   Strength  damage per attack
--   Speed     attack speed: a shorter swing
--   Stamina   a shorter rest between attacks
--   Mana      energy per attack towards the power attack
-- Roles come from the species (or the foe): Attack hits harder, Defence draws every hit and takes less,
-- Utility also heals the most hurt teammate with every attack. The Titan (the team's fourth
-- slot) has no special job. Pack and solitary animals get group bonuses. A foe with the "revive"
-- ability (the Necromancer, decision 0104) raises up to REVIVE_MAX fallen allies with each power attack, and
-- one with "sweep" (the dragons and the Siege Golem, decision 0105) strikes the whole team with it.
-- In the pit fight (decision 0106) clicks add strikes and each animal's power attack has a quick press
-- (`pressOf`, `perfect`); see `battle`.
-- Deterministic: same teams, same result, so the server can decide and replay any fight.

local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local BattleRules = {}

type Owned = StationRules.Owned
export type Fighter = {
	role: string,
	group: string?,
	hp: number,
	maxHp: number,
	dmg: number,
	def: number,
	swing: number, -- seconds an attack takes
	rest: number, -- seconds of rest before the next attack
	gain: number, -- energy per attack
	energy: number, -- the power meter
	next: number, -- when its next attack lands
	side: number,
	slot: number,
	rush: number, -- which rush of its wave it comes in (decision 0101); 1 for the team
	arrive: number, -- when it is in the fight (math.huge while its rush has not been called)
	engaged: boolean, -- side 2: in the front line (only the front line attacks)
	revive: boolean?, -- its power attack raises fallen allies (decision 0104)
	revived: boolean?, -- raised once already: it stays down next time
	sweep: boolean?, -- its power attack strikes every animal of the team that stands (decision 0105)
	press: string, -- its power attack's quick press (decision 0106): "ring", "chain", "needle" or "mash"
	click: number, -- a click strike's share of a normal hit (decision 0106); 0 when clicks do not strike
	owner: number, -- side 1: which player's team it is in (decision 0108: an Owned's `owner`, 1 when unset)
	spot: number?, -- side 2: its place along the front line while it stands in it (decision 0108)
	spectral: boolean?, -- the Spectral coat (decision 0110): the first blow that would knock it out leaves it at 1 HP
	spared: boolean?, -- ... and that has happened
}

BattleRules.HP_BASE, BattleRules.HP_PER_HEALTH = 20, 1.5
BattleRules.DMG_BASE, BattleRules.DMG_PER_STRENGTH = 4, 0.25
BattleRules.DEF_HALF = 100 -- incoming damage x DEF_HALF / (DEF_HALF + Defence): 100 Defence halves it
-- An attack takes SWING seconds, then the animal rests REST seconds. Speed shortens the swing and
-- Stamina the rest, each by TEMPO_HALF / (TEMPO_HALF + stat): 100 of the stat halves its time.
BattleRules.SWING, BattleRules.REST, BattleRules.TEMPO_HALF = 1.5, 1.5, 100
-- Power attacks: every attack adds POWER_GAIN + Mana energy; at POWER_COST that attack's damage
-- and heal are x POWER and the cost is spent.
BattleRules.POWER_GAIN, BattleRules.POWER_COST, BattleRules.POWER = 10, 200, 2
BattleRules.ATTACK_BONUS = 1.3 -- Attack: damage x this
BattleRules.GUARD = 0.8 -- Defence: enemies must target it while it stands, and it takes damage x this
BattleRules.HEAL_PCT = 8 -- Utility: each attack also heals the most hurt teammate by this % of the healer's own max HP
BattleRules.MAX_SECONDS = 300 -- a fight this long is a loss for side 1 (heals could stall it)
BattleRules.REVIVE_PCT = 50 -- a raised ally stands up with this % of its max HP, once per fight
BattleRules.REVIVE_MAX = 3 -- the most one power attack raises (decision 0105)
BattleRules.MAX_ACTIONS = 5000 -- backstop for absurd stats; also a loss for side 1

-- A run's carried HP and boons for side 1 (decision 0098; see `battle`).
-- `clicks` (decision 0106): the team's own attacks are CLICK_SLOW times slower and clicks add strikes.
export type Setup = {
	hp: { number }?,
	energy: number?,
	dmg: number?,
	maxHp: number?,
	tempo: number?,
	clicks: boolean?,
	immortal: boolean?, -- the intro's borrowed fight (decision 0116): nobody on the team can be knocked out
}

-- Quick presses (decisions 0106, 0109): each of the four classes has its own press, so a team of one of
-- each and its Titan has all four. SHANNON, 2026-11-24: "make each QTE assigned to one of the four classes".
BattleRules.PRESS_OF_ROLE = {
	attack = "ring",
	defense = "needle",
	utility = "chain",
	titan = "mash",
} :: { [string]: string }
function BattleRules.pressOf(animal: Owned): string
	return BattleRules.PRESS_OF_ROLE[StationRules.role(animal)] or "ring"
end

-- One animal's battle numbers before group bonuses. Each stat feeds exactly one of them.
function BattleRules.fighter(animal: Owned, side: number, slot: number): Fighter
	local foe = StationConfig.foe(animal.s)
	local sp = StationConfig.species(animal.s) or foe
	local role = StationRules.role(animal)
	local coat = StationRules.coatOf(animal)
	local function stat(name: StationConfig.Stat): number
		return StationRules.stat(animal, name)
	end
	local hp = BattleRules.HP_BASE + math.floor(stat("health") * BattleRules.HP_PER_HEALTH)
	local dmg = BattleRules.DMG_BASE + math.floor(stat("strength") * BattleRules.DMG_PER_STRENGTH)
	if role == "attack" then
		dmg = math.floor(dmg * BattleRules.ATTACK_BONUS)
	end
	local half = BattleRules.TEMPO_HALF
	local swing = BattleRules.SWING * half / (half + stat("speed"))
	return {
		role = role,
		group = if sp then sp.group else nil,
		hp = hp,
		maxHp = hp,
		dmg = dmg,
		def = stat("defence"),
		swing = swing,
		rest = BattleRules.REST * half / (half + stat("stamina")),
		gain = BattleRules.POWER_GAIN + stat("mana"),
		energy = if coat and coat.charged then math.floor(BattleRules.POWER_COST * StationConfig.CHARGED_START) else 0,
		next = swing, -- the first attack lands after one swing, so the faster animal strikes first
		side = side,
		slot = slot,
		rush = math.max(1, (animal :: any).rush or 1),
		arrive = 0,
		engaged = side == 1,
		revive = if foe and foe.ability == "revive" then true else nil,
		sweep = if foe and foe.ability == "sweep" then true else nil,
		press = BattleRules.pressOf(animal),
		click = 0,
		owner = math.max(1, (animal :: any).owner or 1),
		spectral = if coat and coat.spectral then true else nil,
	}
end

-- Shared fights (decision 0108): a team may hold several players' teams, each animal marked with its
-- player's number (`owner`, 1 to `players`). The front line is FRONT_MORE longer for each player after
-- the first.
BattleRules.FRONT_MORE = 3
function BattleRules.players(team: { Owned }): number
	local n = 1
	for _, a in team do
		n = math.max(n, (a :: any).owner or 1)
	end
	return n
end
function BattleRules.front(players: number): number
	return BattleRules.FRONT + BattleRules.FRONT_MORE * (math.max(1, players) - 1)
end

-- A whole team ready to fight, with the group bonuses on damage and HP: a pack animal gains
-- PACK_PCT % for each other pack animal, a solitary animal SOLITARY_PCT % when no teammate
-- shares its role. A teammate is an animal of the same player (decision 0108).
function BattleRules.lineup(team: { Owned }, side: number, setup: Setup?): { Fighter }
	local out = {}
	for i, a in team do
		table.insert(out, BattleRules.fighter(a, side, i))
	end
	for _, f in out do
		local pct = 0
		if f.group == "pack" then
			for _, m in out do
				if m ~= f and m.group == "pack" and m.owner == f.owner then
					pct += StationConfig.PACK_PCT
				end
			end
		elseif f.group == "solitary" then
			pct = StationConfig.SOLITARY_PCT
			for _, m in out do
				if m ~= f and m.role == f.role and m.owner == f.owner then
					pct = 0
				end
			end
		end
		f.dmg = math.floor(f.dmg * (100 + pct) / 100)
		f.maxHp = math.floor(f.maxHp * (100 + pct) / 100)
		f.hp = f.maxHp
	end
	if setup then -- a run's carried HP and boons (decision 0098)
		for i, f in out do
			f.dmg = math.max(1, math.floor(f.dmg * (setup.dmg or 1)))
			f.maxHp = math.max(1, math.floor(f.maxHp * (setup.maxHp or 1)))
			local share = if setup.hp and setup.hp[i] then setup.hp[i] else 1
			f.hp = if share <= 0 then 0 else math.max(1, math.floor(f.maxHp * math.min(1, share)))
			f.swing *= setup.tempo or 1
			f.rest *= setup.tempo or 1
			if setup.clicks then -- a strike is STRIKE_SECONDS of its attacking; its own attacks slow down
				f.click = BattleRules.STRIKE_SECONDS / (f.swing + f.rest)
				f.swing *= BattleRules.CLICK_SLOW
				f.rest *= BattleRules.CLICK_SLOW
			end
			f.next = f.swing
			f.energy = math.floor( -- a boon's charge on top of a coat's
				BattleRules.POWER_COST * math.clamp((setup.energy or 0) + f.energy / BattleRules.POWER_COST, 0, 0.99)
			)
		end
	end
	return out
end

-- Power scores (decision 0096): one number for how strong a fighter is in a wave fight, so a team and a
-- wave can be weighed before they meet. A fighter's is sqrt(effective HP x damage a second) x
-- POWER_SCALE, and a side's is the sum of its fighters' (with the group bonuses): by Lanchester's square
-- law two like sides are even when their sums are. A healer counts its heals as HP over HEAL_SECONDS.
-- Side 1's power attacks are extra strikes (the player's, decision 0092); side 2's replace an attack.
-- An estimate for the menus: no fight reads it.
BattleRules.POWER_SCALE, BattleRules.HEAL_SECONDS = 10, 20
function BattleRules.scoreOf(f: Fighter): number
	local cycle = f.swing + f.rest
	local share = math.min(1, f.gain / BattleRules.POWER_COST) -- power attacks per attack
	local extra = if f.side == 1 then BattleRules.POWER else BattleRules.POWER - 1
	local per = (1 + extra * share) / cycle -- attacks' worth of damage a second
	local hp = f.maxHp * (BattleRules.DEF_HALF + f.def) / BattleRules.DEF_HALF
	if f.revive then -- an ally raised at REVIVE_PCT now and then: about a quarter more HP on the side
		hp *= 1 + BattleRules.REVIVE_PCT / 200
	end
	if f.role == "defense" then
		hp /= BattleRules.GUARD
	elseif f.role == "utility" then
		hp += f.maxHp * BattleRules.HEAL_PCT / 100 * per * BattleRules.HEAL_SECONDS
	end
	return math.floor(math.sqrt(hp * f.dmg * per) * BattleRules.POWER_SCALE + 0.5)
end

-- One animal's (or foe's) own power: no teammates, so no group bonus.
function BattleRules.powerOf(animal: Owned, side: number?): number
	return BattleRules.scoreOf(BattleRules.fighter(animal, side or 1, 1))
end

-- A whole side's power, group bonuses and all.
function BattleRules.teamPower(team: { Owned }, side: number?): number
	local sum = 0
	for _, f in BattleRules.lineup(team, side or 1) do
		sum += BattleRules.scoreOf(f)
	end
	return sum
end

local function alive(team: { Fighter }): boolean
	for _, f in team do
		if f.hp > 0 then
			return true
		end
	end
	return false
end

-- The enemy to hit at `now`: the first standing Defence animal, else the first standing animal, of
-- those in the fight (a rush still on its way cannot be hit).
local function target(foes: { Fighter }, now: number): Fighter?
	local first: Fighter? = nil
	for _, f in foes do
		if f.hp > 0 and f.arrive <= now then
			if f.role == "defense" then
				return f
			end
			first = first or f
		end
	end
	return first
end

-- Fight the player's team (side 1) against a wave (side 2) on a clock: whoever's attack is due
-- next acts (ties go to side 1, then the lower slot). Returns whether the team won, how many
-- attacks happened and how many seconds the fight took. `log`, when given, is filled with one
-- entry per attack, in order, so the fight can be shown: when it landed (`t`), who hit (`side`,
-- `slot`), whom (`tside`, `tslot`), the damage dealt (`dmg`) and the target's HP after it (`hp`),
-- whether it was a power attack (`power`, and `tap` when the player fired it), the attacker's power
-- meter after it (`energy`, 0 to 1) and, for a healer, who it healed and to what HP
-- (`heal` = { slot, hp }, on the healer's own side). It never changes the result.
--
-- With `taps` (decision 0092) the player fires their team's power attacks: side 1's meters fill and
-- hold, and a power attack is an extra strike on top of the animal's own attacks, landing at a tap's
-- time `t` for the animal in `slot`, if its meter is full then (a tap at any other time does
-- nothing). A full meter nobody taps fires itself AUTO_FIRE seconds after it filled. A tap changes
-- nothing before its own time, so the server can replay a fight from the start with each new tap.
-- Without `taps` every power attack fires itself on the attack that fills the meter.
--
-- Fight feel (decision 0097), with taps only:
-- * Perfect: a tap PERFECT_AT seconds after its meter filled (PERFECT_EARLY before to PERFECT_LATE after)
--   is a Perfect power attack, x PERFECT on top of POWER.
-- * Combo: a power attack by a different animal of the team within COMBO_SECONDS of the last one adds
--   to the combo (up to COMBO_MAX): COMBO_PCT % more damage for each step past the first.
-- * Shield: a tap on slot 0 raises the team's shield for SHIELD_SECONDS, halving (x SHIELD) every
--   enemy power attack that lands meanwhile; after a shield goes up the next can come SHIELD_COOLDOWN
--   seconds later (`BattleRules.shields`), and an earlier tap does nothing.
-- `setup` (decision 0098: a wave run) starts side 1 hurt or stronger: `hp` its HP by slot as a share of
-- max HP (0 = knocked out), `energy` its meters' share full, `dmg`, `maxHp` and `tempo` (attack time)
-- multiplied in after the group bonuses. The fourth result is side 1's HP at the end, as shares by slot.
-- more forgiving, with a fail (SHANNON, 2026-11-24): was 4 s, 0.25 s and 0.55 s
BattleRules.AUTO_FIRE = 6
-- A full meter left AUTO_FIRE seconds fails like a messed-up press (SHANNON, 2026-11-24): a plain hit marked
-- `fail`. False makes it fire a plain power attack instead (the run simulations' presser, decision 0110).
BattleRules.EXPIRE_FAILS = true
BattleRules.PERFECT_AT, BattleRules.PERFECT_EARLY, BattleRules.PERFECT_LATE = 2.5, 0.35, 0.8
BattleRules.PERFECT = 1.5
BattleRules.COMBO_SECONDS, BattleRules.COMBO_PCT, BattleRules.COMBO_MAX = 3, 25, 4
BattleRules.SHIELD_SECONDS, BattleRules.SHIELD_COOLDOWN, BattleRules.SHIELD = 1.2, 6, 0.5
--
-- Crowds (decision 0101): a wave's foes may come in rushes (an Owned's `rush`, 1 to 3). Rush 1 is there at
-- the start; the next is called when half of the one before is down, or RUSH_SECONDS after it arrived, and
-- arrives RUSH_WALK later (`arrivals`, when given, gets each foe's arrival by slot). Only the front line
-- attacks: the first FRONT standing foes that have arrived, in slot order; the next steps up when one
-- falls (`engaged`, when given, gets when each foe joined it). The team fights crowds:
-- * an Attack animal's normal hit also strikes the next foe for SPLASH of its damage;
-- * a power attack also strikes up to CROWD - 1 more foes for CROWD_SHARE of its damage;
-- * a Defence animal's power attack knocks every foe it strikes back KNOCKBACK seconds;
-- * a Utility animal's power attack heals the whole team, not only the most hurt (a Battle Priest's heals its
--   whole side too, decision 0105).
-- Extra strikes are in their hit's `also` ({ slot, dmg, hp }), a team heal in `heals` ({ slot, hp }).
BattleRules.FRONT, BattleRules.RUSH_SECONDS, BattleRules.RUSH_WALK = 6, 8, 2
--
-- The pit fight (decision 0106), with taps and a setup with `clicks`:
-- * The team's own attacks are CLICK_SLOW times slower.
-- * A tap on slot STRIKE is a click: the next standing animal of the team in turn strikes the usual target
--   with STRIKE_SECONDS of its attacking (its `click` share of a normal hit, splash and heal included), and
--   its meter gains the same share of its energy. Its log entry is a normal hit marked `click`. A strike
--   less than STRIKE_GAP after the last one does nothing.
-- * A power tap is a Perfect by its animal's press (`perfect`): a ring held while it fills (decision 0109,
--   amended: the tap's `presses` is how long it was held, in tenths of a second, at least HOLD_TENTHS); the needle's, at
--   PERFECT_AT and every NEEDLE_EVERY after; a chain finished by PERFECT_AT + PERFECT_LATE; a mash that
--   brings MASH_COUNT presses (the tap's `presses`) by MASH_BY + PERFECT_LATE.
--
-- Shared fights (decision 0108), when side 1 holds more than one player's team (`BattleRules.players`):
-- * The front line is `BattleRules.front(players)` long. Each foe in it has a place along it (`spot`, 1 to
--   that; `places`, when given, gets each foe's by slot): the first take them in order, and a foe that steps
--   up takes the place the longest empty. Player k's team stands before the k-th part of the line.
-- * A foe attacks the team it stands before (its first standing Defence animal, else its first standing
--   animal), and the usual target once that team is down.
-- * A click is its player's (the tap's `owner`): that player's next standing animal strikes the standing foe
--   of the front line nearest that player's team. Each player's clicks keep their own STRIKE_GAP.
-- * Everything else is one team's: the usual target for the animals' own attacks and power attacks, one
--   combo, one shield, one setup.
-- clicking is a bonus, slightly easier (SHANNON, 2026-11-24): was 2.4 times slower unclicked and 0.6 s a click
BattleRules.STRIKE, BattleRules.CLICK_SLOW, BattleRules.STRIKE_SECONDS, BattleRules.STRIKE_GAP = -1, 1, 0.25, 1 / 12
BattleRules.NEEDLE_EVERY = 1.5
BattleRules.MASH_COUNT, BattleRules.MASH_BY, BattleRules.MASH_RATE = 8, 4.5, 12
-- A press messed up (SHANNON, 2026-11-24: "a fail condition as punishment"): a chain's wrong key, a needle
-- stopped outside the green, a ring let go before RING_FAIL tenths, a mash short of MASH_FAIL when time is up.
-- The client judges it on what the player saw and sends FAILED as the tap's `presses` (it can only cost the
-- player): the meter is spent on a plain hit, marked `fail`.
BattleRules.FAILED, BattleRules.RING_FAIL, BattleRules.MASH_FAIL = -1, 6, 4
BattleRules.HOLD_TENTHS = 12 -- the ring fills in 1.2 s of holding
BattleRules.SPLASH, BattleRules.CROWD, BattleRules.CROWD_SHARE, BattleRules.KNOCKBACK = 0.5, 5, 0.6, 1
export type Hit = {
	t: number,
	side: number,
	slot: number,
	tside: number,
	tslot: number,
	dmg: number,
	hp: number,
	power: boolean,
	tap: boolean?,
	perfect: boolean?,
	combo: number?, -- 2 and up
	shielded: boolean?,
	energy: number,
	heal: { slot: number, hp: number }?,
	heals: { { slot: number, hp: number } }?,
	also: { { slot: number, dmg: number, hp: number } }?,
	revives: { { slot: number, hp: number } }?, -- the allies its power attack raised (decisions 0104, 0105)
	click: boolean?, -- a click's strike (decision 0106)
	fail: boolean?, -- a power tap whose press was messed up: a plain hit, the meter spent
}
export type Tap = { slot: number, t: number, presses: number?, owner: number? }

-- Whether a power tap `since` seconds after its meter filled is a Perfect for an animal whose press is
-- `press` (decisions 0097, 0106, 0109); `presses` is a mash's count or a ring's hold in tenths of a second.
function BattleRules.perfect(press: string, since: number, presses: number?): boolean
	local late = since - BattleRules.PERFECT_AT
	if press == "chain" then
		return late <= BattleRules.PERFECT_LATE
	elseif press == "mash" then
		return (presses or 0) >= BattleRules.MASH_COUNT and since <= BattleRules.MASH_BY + BattleRules.PERFECT_LATE
	elseif press == "ring" then
		return (presses or 0) >= BattleRules.HOLD_TENTHS
	elseif press == "needle" then
		return late >= -BattleRules.PERFECT_EARLY
			and (late + BattleRules.PERFECT_EARLY) % BattleRules.NEEDLE_EVERY
				<= BattleRules.PERFECT_EARLY + BattleRules.PERFECT_LATE
	end
	return late >= -BattleRules.PERFECT_EARLY and late <= BattleRules.PERFECT_LATE
end

-- The times of the shield taps (slot 0) in `taps` that raise the shield, in order.
function BattleRules.shields(taps: { Tap }): { number }
	local times = {}
	for _, tap in taps do
		if tap.slot == 0 then
			table.insert(times, tap.t)
		end
	end
	table.sort(times)
	local out, ready = {}, -math.huge
	for _, t in times do
		if t >= ready then
			table.insert(out, t)
			ready = t + BattleRules.SHIELD_COOLDOWN
		end
	end
	return out
end

function BattleRules.battle(
	one: { Owned },
	two: { Owned },
	log: { Hit }?,
	taps: { Tap }?,
	setup: Setup?,
	arrivals: { [number]: number }?,
	engaged: { [number]: number }?,
	places: { [number]: number }?
): (boolean, number, number, { number })
	local sides = { BattleRules.lineup(one, 1, setup), BattleRules.lineup(two, 2) }
	local foes = sides[2]
	local players = BattleRules.players(one)
	local front = BattleRules.front(players)
	local teams: { { Fighter } } = table.create(players) -- each player's animals, in slot order
	for k = 1, players do
		teams[k] = {}
	end
	for _, f in sides[1] do
		table.insert(teams[math.min(f.owner, players)], f)
	end
	-- rushes: rushAt[r] is when rush r arrives (math.huge until it is called)
	local rushes = 1
	for _, f in foes do
		rushes = math.max(rushes, f.rush)
	end
	local rushAt, landed = { 0 }, { true }
	for r = 2, rushes do
		rushAt[r], landed[r] = math.huge, false
	end
	for _, f in foes do
		f.arrive = rushAt[f.rush]
	end
	local all = table.clone(sides[1])
	for _, f in sides[2] do
		table.insert(all, f)
	end
	local held = taps ~= nil
	local queue: { Tap } = if taps then table.clone(taps) else {}
	table.sort(queue, function(a, b)
		return a.t < b.t
	end)
	local full: { [Fighter]: number } = {} -- when each held meter filled
	local actions, now = 0, 0
	local up: { [number]: boolean } = {} -- the shield taps that raise it
	for _, t in BattleRules.shields(queue) do
		up[t] = true
	end
	local shieldTo = -math.huge
	local combo, comboAt, comboSlot = 0, -math.huge, 0
	-- each player's clicks so far, and when their next may strike (decision 0106)
	local strikes, strikeReady = table.create(players, 0), table.create(players, -math.huge)

	-- the front line: the first `front` standing foes that have arrived; one that joins after the start
	-- swings from then. Each stands in a place along it: a fallen foe's place is free again.
	local free: { number }, spots = {}, 0
	local function engage()
		for _, f in foes do
			if f.spot and f.hp <= 0 then
				table.insert(free, f.spot)
				f.spot = nil
			end
		end
		local n = 0
		for _, f in foes do
			if f.hp > 0 and f.arrive <= now then
				n += 1
				if n <= front then
					if not f.engaged then
						f.engaged = true
						if now > 0 then
							f.next = now + f.swing
						end
						if engaged then
							engaged[f.slot] = now
						end
					end
					if f.spot == nil then
						spots = if #free > 0 then spots else spots + 1
						f.spot = table.remove(free, 1) or (spots - 1) % front + 1
						if places then
							places[f.slot] = f.spot :: number
						end
					end
				end
			end
		end
	end
	-- shared fights: the standing animal a foe in place `spot` attacks, of the team it stands before
	local function facing(spot: number?): Fighter?
		if players == 1 or spot == nil then
			return nil
		end
		local first: Fighter? = nil
		for _, f in teams[math.clamp(math.ceil(spot * players / front), 1, players)] do
			if f.hp > 0 then
				if f.role == "defense" then
					return f
				end
				first = first or f
			end
		end
		return first
	end
	-- shared fights: the standing foe of the front line nearest player `who`'s team
	local function nearest(who: number): Fighter?
		local mid = (who - 0.5) * front / players + 0.5
		local best: Fighter? = nil
		for _, f in foes do
			if f.hp > 0 and f.arrive <= now and f.spot then
				if best == nil or math.abs(f.spot - mid) < math.abs((best.spot :: number) - mid) then
					best = f
				end
			end
		end
		return best
	end
	local function call(r: number) -- rush r is on its way
		rushAt[r] = now + BattleRules.RUSH_WALK
		for _, f in foes do
			if f.rush == r then
				f.arrive = rushAt[r]
				if arrivals then
					arrivals[f.slot] = rushAt[r]
				end
			end
		end
	end
	if arrivals then
		for _, f in foes do
			if f.rush == 1 then
				arrivals[f.slot] = 0
			end
		end
	end
	engage()
	-- after a foe falls: the front line steps up, and half of a rush down calls the next one
	local function fell()
		engage()
		for r = 2, rushes do
			if rushAt[r] == math.huge and landed[r - 1] then
				local size, down = 0, 0
				for _, f in foes do
					if f.rush == r - 1 then
						size += 1
						down += if f.hp <= 0 then 1 else 0
					end
				end
				if down * 2 >= size then
					call(r)
				end
			end
		end
	end

	-- `d` takes `hit` at `now` (Defence last, as one division, so exact results stay exact)
	local function hurt(d: Fighter, hit: number): number
		if d.role == "defense" then
			hit *= BattleRules.GUARD
		end
		local dealt = math.max(1, math.floor(hit * BattleRules.DEF_HALF / (BattleRules.DEF_HALF + d.def)))
		if d.spectral and not d.spared and dealt >= d.hp and d.hp > 1 then -- the Spectral coat: once, it stays up
			d.spared, dealt = true, d.hp - 1
		end
		if d.side == 1 and setup and setup.immortal then -- a fight that cannot be lost: the last point of HP stays
			dealt = math.min(dealt, math.max(0, d.hp - 1))
		end
		d.hp -= dealt
		return dealt
	end

	-- `me` attacks at `now`; `power` x damage and heal
	local function strike(
		me: Fighter,
		power: number,
		tapped: boolean?,
		perfect: boolean?,
		click: boolean?,
		failed: boolean?
	)
		local enemies = sides[3 - me.side]
		local d = (if me.side == 2 then facing(me.spot) elseif click and players > 1 then nearest(me.owner) else nil)
			or target(enemies, now) :: Fighter
		local hit = me.dmg * power
		local chain = nil
		if held and me.side == 1 and power > 1 then
			combo = if me.slot ~= comboSlot and now - comboAt <= BattleRules.COMBO_SECONDS
				then math.min(BattleRules.COMBO_MAX, combo + 1)
				else 1
			comboAt, comboSlot = now, me.slot
			if perfect then
				hit *= BattleRules.PERFECT
			end
			hit *= 1 + BattleRules.COMBO_PCT * (combo - 1) / 100
			chain = if combo > 1 then combo else nil
		end
		local shielded = me.side == 2 and power > 1 and now <= shieldTo
		if shielded then
			hit *= BattleRules.SHIELD
		end
		local dealt = hurt(d, hit)
		local struck = { d }
		-- the team fights crowds: splash, and power attacks that hit several
		local also: { { slot: number, dmg: number, hp: number } }? = nil
		if me.side == 1 then
			local extra = if power > 1 then BattleRules.CROWD - 1 elseif me.role == "attack" then 1 else 0
			local share = if power > 1 then BattleRules.CROWD_SHARE else BattleRules.SPLASH
			for _, o in enemies do
				if extra <= 0 then
					break
				elseif o ~= d and o.hp > 0 and o.arrive <= now then
					extra -= 1
					local got = hurt(o, hit * share)
					also = also or {}
					table.insert(also :: any, { slot = o.slot, dmg = got, hp = o.hp })
					table.insert(struck, o)
				end
			end
			if power > 1 and me.role == "defense" then -- knocked back a step
				for _, o in struck do
					if o.hp > 0 and o.engaged then
						o.next += BattleRules.KNOCKBACK
					end
				end
			end
		elseif me.sweep and power > 1 then -- every animal that stands takes the whole blow (decision 0105)
			for _, o in enemies do
				if o ~= d and o.hp > 0 and o.arrive <= now then
					local got = hurt(o, hit)
					also = also or {}
					table.insert(also :: any, { slot = o.slot, dmg = got, hp = o.hp })
				end
			end
		end
		local entry: Hit? = nil
		if log then
			entry = {
				t = now,
				side = me.side,
				slot = me.slot,
				tside = d.side,
				tslot = d.slot,
				dmg = dealt,
				hp = d.hp,
				power = power > 1,
				tap = tapped,
				perfect = if perfect then true else nil,
				combo = chain,
				shielded = if shielded then true else nil,
				energy = math.min(1, me.energy / BattleRules.POWER_COST),
				also = also,
				click = click,
				fail = failed,
			}
			table.insert(log, entry :: Hit)
		end
		if me.revive and power > 1 then -- the first fallen allies not raised before stand up again
			local raised = 0
			for _, m in sides[me.side] do
				if raised >= BattleRules.REVIVE_MAX then
					break
				elseif m.hp <= 0 and not m.revived and m.arrive <= now then
					raised += 1
					m.revived = true
					m.hp = math.max(1, math.floor(m.maxHp * BattleRules.REVIVE_PCT / 100))
					m.next = now + m.swing
					if entry then
						entry.revives = entry.revives or {}
						table.insert(entry.revives :: any, { slot = m.slot, hp = m.hp })
					end
				end
			end
		end
		if me.role == "utility" then
			local heal = math.floor(me.maxHp * BattleRules.HEAL_PCT * power / 100)
			if power > 1 then -- its whole side
				local heals = {}
				for _, m in sides[me.side] do
					if m.hp > 0 and m.arrive <= now then
						m.hp = math.min(m.maxHp, m.hp + heal)
						table.insert(heals, { slot = m.slot, hp = m.hp })
					end
				end
				if entry then
					entry.heals = heals
				end
			else
				local low: Fighter? = nil
				for _, m in sides[me.side] do
					if m.hp > 0 and (low == nil or m.hp / m.maxHp < low.hp / low.maxHp) then
						low = m
					end
				end
				if low then
					low.hp = math.min(low.maxHp, low.hp + heal)
					if entry then
						entry.heal = { slot = low.slot, hp = low.hp }
					end
				end
			end
		end
		if not click then -- clicks are bounded by STRIKE_GAP, not counted as attacks
			actions += 1
		end
		for _, o in struck do
			if o.hp <= 0 and o.side == 2 then
				fell()
				break
			end
		end
	end

	while alive(sides[1]) and alive(sides[2]) and actions < BattleRules.MAX_ACTIONS do
		local f: Fighter? = nil
		for _, c in all do -- `all` is in side then slot order, so a strict < breaks ties that way
			if c.hp > 0 and c.engaged and (f == nil or c.next < f.next) then
				f = c
			end
		end
		local nextAt = if f then f.next else math.huge
		-- a rush is called by the clock, or lands
		local rushEvent, rushIs, rushOf = math.huge, "", 0
		for r = 2, rushes do
			local t, is = math.huge, ""
			if rushAt[r] == math.huge and rushAt[r - 1] < math.huge then
				t, is = rushAt[r - 1] + BattleRules.RUSH_SECONDS, "call"
			elseif not landed[r] and rushAt[r] < math.huge then
				t, is = rushAt[r], "land"
			end
			if t < rushEvent then
				rushEvent, rushIs, rushOf = t, is, r
			end
		end
		-- a held power attack due first: a tap, else a meter firing itself (ties before attacks)
		local auto: Fighter?, autoAt = nil, math.huge
		for _, c in sides[1] do
			local at = full[c]
			if at and c.hp > 0 and at + BattleRules.AUTO_FIRE < autoAt then
				auto, autoAt = c, at + BattleRules.AUTO_FIRE
			end
		end
		local tap = queue[1]
		if rushEvent <= nextAt and rushEvent <= autoAt and (tap == nil or rushEvent < tap.t) then
			if rushEvent > BattleRules.MAX_SECONDS then
				break
			end
			now = math.max(now, rushEvent)
			if rushIs == "call" then -- called now: it lands RUSH_WALK later
				call(rushOf)
			else
				landed[rushOf] = true
				engage()
			end
			continue
		end
		if tap and tap.t <= autoAt and tap.t <= nextAt then
			table.remove(queue, 1)
			local c = sides[1][tap.slot]
			if tap.slot == 0 and up[tap.t] then
				shieldTo = tap.t + BattleRules.SHIELD_SECONDS
			elseif tap.slot == BattleRules.STRIKE then -- a click (decision 0106), its player's (decision 0108)
				local who = math.clamp(tap.owner or 1, 1, players)
				if tap.t >= strikeReady[who] and tap.t <= BattleRules.MAX_SECONDS and target(foes, tap.t) then
					local me: Fighter? = nil
					local mine = teams[who]
					for _ = 1, #mine do -- that player's next standing animal in turn
						strikes[who] += 1
						local m = mine[(strikes[who] - 1) % #mine + 1]
						if m.hp > 0 and m.click > 0 then
							me = m
							break
						end
					end
					if me then
						now = math.max(now, tap.t)
						strikeReady[who] = tap.t + BattleRules.STRIKE_GAP
						me.energy = math.min(BattleRules.POWER_COST, me.energy + me.gain * me.click)
						if me.energy >= BattleRules.POWER_COST and full[me] == nil then
							full[me] = now
						end
						strike(me, me.click, nil, nil, true)
					end
				end
			elseif c and c.hp > 0 and full[c] and tap.t >= full[c] and target(foes, tap.t) then
				if tap.t > BattleRules.MAX_SECONDS then
					break
				end
				local since = tap.t - full[c]
				now = math.max(now, tap.t)
				full[c] = nil
				c.energy -= BattleRules.POWER_COST
				if tap.presses == BattleRules.FAILED then
					strike(c, 1, true, false, nil, true)
				else
					strike(c, BattleRules.POWER, true, BattleRules.perfect(c.press, since, tap.presses))
				end
			end
			continue
		end
		if auto and autoAt <= nextAt then
			if autoAt > BattleRules.MAX_SECONDS then
				break
			end
			now = autoAt
			if target(foes, now) == nil then -- nobody to hit yet (the next rush is on its way): wait
				full[auto] = (full[auto] :: number) + 0.5
				continue
			end
			full[auto] = nil
			auto.energy -= BattleRules.POWER_COST
			if BattleRules.EXPIRE_FAILS then
				strike(auto, 1, nil, false, nil, true)
			else
				strike(auto, BattleRules.POWER)
			end
			continue
		end
		local me = f :: Fighter
		if f == nil or me.next > BattleRules.MAX_SECONDS then
			break
		end
		now = me.next
		if target(sides[3 - me.side], now) == nil then -- nobody to hit yet: it waits a turn
			me.next = now + me.rest + me.swing
			continue
		end
		local power = 1
		if held and me.side == 1 then -- fills and holds; the strike comes from a tap or AUTO_FIRE
			me.energy = math.min(BattleRules.POWER_COST, me.energy + me.gain)
			if me.energy >= BattleRules.POWER_COST and full[me] == nil then
				full[me] = now
			end
		else
			me.energy += me.gain
			if me.energy >= BattleRules.POWER_COST then
				me.energy -= BattleRules.POWER_COST
				power = BattleRules.POWER
			end
		end
		strike(me, power)
		me.next = now + me.rest + me.swing
	end
	local ends = {}
	for i, f in sides[1] do
		ends[i] = math.max(0, f.hp) / f.maxHp
	end
	return alive(sides[1]) and not alive(sides[2]), actions, now, ends
end

return BattleRules
