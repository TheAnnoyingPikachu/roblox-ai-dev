--!strict
-- Pure Animal Stations rules (decisions 0019 to 0029): hatch an animal (species, then a
-- rare variant roll, then stats), level its stats at the stations, and its role and matchups.
-- The server owns the Rng state and the clock; the client never sends stats or times.

local Rng = require("./Rng")
local StationConfig = require("./StationConfig")

local StationRules = {}

type Stats = StationConfig.Stats
-- One hatched animal: v nil = basic; stats rolled at hatch; trained = each stat's level, 0 to
-- MAX_LEVEL, with the progress to the next level as the fraction.
export type Owned = { s: string, v: string?, stats: Stats, trained: Stats? }

StationRules.PPM = 1_000_000
StationRules.ZERO = { speed = 0, strength = 0, stamina = 0, mana = 0, health = 0, defence = 0 } :: Stats
-- The stats an attack can come from. Health is only HP and Defence only cuts damage.
StationRules.ATTACK_STATS = { "speed", "strength", "stamina", "mana" } :: { StationConfig.Stat }

-- First id whose cumulative basis points reach r (r in 1..10000).
function StationRules.pick(odds: { StationConfig.Odds }, r: number): string
	local total = 0
	for _, o in odds do
		total += o.bp
		if r <= total then
			return o.id
		end
	end
	return odds[#odds].id
end

-- The variant tier for r in 1..PPM (rarest first), or nil for the basic version.
function StationRules.pickTier(r: number): string?
	local total = 0
	for _, t in StationConfig.TIERS do
		total += t.ppm
		if r <= total then
			return t.tier
		end
	end
	return nil
end

-- The version's stats before the per-hatch variance: basic stats, or basic x mult + twist for a
-- variant. Nil for an unknown species or a variant of another species. Used for stat cards too.
function StationRules.versionStats(speciesId: string, variantId: string?): Stats?
	local sp = StationConfig.species(speciesId)
	if sp == nil then
		return nil
	end
	if variantId == nil then
		return table.clone(sp.stats)
	end
	local va = StationConfig.variant(speciesId, variantId)
	local tier = va and StationConfig.tier(va.tier)
	if va == nil or tier == nil then
		return nil
	end
	local out = {} :: any
	for _, stat in StationConfig.STATS do
		local x = (sp.stats :: any)[stat] * tier.mult + (if stat == va.twist then tier.twist else 0)
		out[stat] = math.min(math.floor(x), StationConfig.STAT_MAX)
	end
	return out :: Stats
end

-- Hatch one animal from `eggId`. Nil for an unknown egg (the server refuses the request).
-- Draws: species, variant tier, then one per stat.
function StationRules.hatch(eggId: string, rng: Rng.State): (Owned?, Rng.State)
	local egg = StationConfig.egg(eggId)
	if egg == nil then
		return nil, rng
	end
	local r, t
	r, rng = Rng.int(rng, 1, 10000)
	local species = StationRules.pick(egg.odds, r)
	t, rng = Rng.int(rng, 1, StationRules.PPM)
	local tier = StationRules.pickTier(t)
	local variantId: string? = nil
	if tier then
		for _, va in (StationConfig.species(species) :: StationConfig.Species).variants do
			if va.tier == tier then
				variantId = va.id
			end
		end
	end
	local base = StationRules.versionStats(species, variantId) :: Stats
	local stats = {} :: any
	for _, stat in StationConfig.STATS do
		local pct
		pct, rng = Rng.int(rng, 100 - StationConfig.VARIANCE, 100 + StationConfig.VARIANCE)
		local x = math.floor((base :: any)[stat] * pct / 100)
		stats[stat] = math.clamp(x, StationConfig.STAT_MIN, StationConfig.STAT_MAX)
	end
	return { s = species, v = variantId, stats = stats :: Stats }, rng
end

-- An animal's attack stat: its highest current stat among ATTACK_STATS (ties go to the first).
function StationRules.bestStat(animal: Owned): StationConfig.Stat
	local best, top = StationRules.ATTACK_STATS[1], -1
	for _, stat in StationRules.ATTACK_STATS do
		local x = StationRules.stat(animal, stat)
		if x > top then
			best, top = stat, x
		end
	end
	return best
end

-- An animal's role, from its species: "attack", "defense", "utility" or "titan".
function StationRules.role(animal: Owned): string
	local sp = StationConfig.species(animal.s)
	return if sp then sp.role else "attack"
end

-- Damage multiplier for an attacker of role `a` hitting a defender of role `d`. Titans are
-- outside the loop: always 1.
function StationRules.matchup(a: string, d: string): number
	if StationConfig.BEATS[a] == d then
		return StationConfig.ADVANTAGE
	elseif StationConfig.BEATS[d] == a then
		return 1 / StationConfig.ADVANTAGE
	end
	return 1
end

-- Display rarity: the variant's tier, or the species' basic rarity.
function StationRules.rarity(animal: Owned): string
	if animal.v then
		local va = StationConfig.variant(animal.s, animal.v)
		if va then
			return va.tier
		end
	end
	local sp = StationConfig.species(animal.s)
	return if sp then sp.rarity else "common"
end

-- A stat's level, 0 (untrained) to MAX_LEVEL.
function StationRules.level(animal: Owned, stat: StationConfig.Stat): number
	return if animal.trained then math.floor((animal.trained :: any)[stat]) else 0
end

-- An animal's stat right now: the hatched value grown by its level (doubled at MAX_LEVEL).
-- Whole-number maths, so a result that should be exact is never one short. Not capped: level
-- enemies have no levels but hatched stats that keep growing.
function StationRules.stat(animal: Owned, stat: StationConfig.Stat): number
	local max = StationConfig.MAX_LEVEL
	local grown = max + StationConfig.LEVEL_GROWTH * StationRules.level(animal, stat)
	return math.floor((animal.stats :: any)[stat] * grown / max)
end

-- Seconds on a station to go from level n - 1 to level n.
function StationRules.levelSeconds(n: number): number
	return StationConfig.LEVEL_SECONDS * n
end

-- `animal` after `seconds` on `stationId`: a copy with that station's stat levelled, never past
-- MAX_LEVEL. Unknown station or no time: unchanged.
-- shortcut: no cap on offline seconds; the caller clamps the time it passes in.
function StationRules.train(animal: Owned, stationId: string, seconds: number): Owned
	local st = StationConfig.station(stationId)
	if st == nil or seconds <= 0 then
		return animal
	end
	local trained = if animal.trained then table.clone(animal.trained) else table.clone(StationRules.ZERO)
	local lv = (trained :: any)[st.stat] :: number
	while seconds > 0 and lv < StationConfig.MAX_LEVEL do
		local whole = math.floor(lv)
		local cost = StationRules.levelSeconds(whole + 1)
		local need = (whole + 1 - lv) * cost -- seconds left in this level
		if seconds >= need then
			lv, seconds = whole + 1, seconds - need
		else
			lv, seconds = lv + seconds / cost, 0
		end
	end
	(trained :: any)[st.stat] = math.min(lv, StationConfig.MAX_LEVEL)
	local out = table.clone(animal)
	out.trained = trained
	return out
end

return StationRules
