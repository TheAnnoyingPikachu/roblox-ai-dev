--!strict
-- Pure Animal Stations rules (decisions 0019, 0020, 0022, 0023): hatch an animal (species, then a
-- rare variant roll, then stats), train it at a station, and its battle type and matchups. The
-- server owns the Rng state and the clock; the client never sends stats or times.

local Rng = require("./Rng")
local StationConfig = require("./StationConfig")

local StationRules = {}

type Stats = StationConfig.Stats
-- One hatched animal: v nil = basic; stats rolled at hatch; trained = points added at stations.
export type Owned = { s: string, v: string?, stats: Stats, trained: Stats? }

StationRules.PPM = 1_000_000
StationRules.ZERO = { speed = 0, strength = 0, stamina = 0, mana = 0 } :: Stats

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

-- The stat an animal battles as: its highest current stat (ties go to the first in STATS).
function StationRules.battleType(animal: Owned): StationConfig.Stat
	local best, top = StationConfig.STATS[1], -1
	for _, stat in StationConfig.STATS do
		local x = StationRules.stat(animal, stat)
		if x > top then
			best, top = stat, x
		end
	end
	return best
end

-- Damage multiplier for an attacker of type `a` hitting a defender of type `d`.
function StationRules.matchup(a: StationConfig.Stat, d: StationConfig.Stat): number
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

-- An animal's stat right now: hatched plus trained, floored. Not capped here: training stops at
-- STAT_MAX, and level enemies must keep growing past it.
function StationRules.stat(animal: Owned, stat: StationConfig.Stat): number
	return math.floor((animal.stats :: any)[stat] + (if animal.trained then (animal.trained :: any)[stat] else 0))
end

-- `animal` after `seconds` on `stationId`: a copy with that station's stat trained, never past
-- POTENTIAL x the hatched stat or a total of STAT_MAX. Unknown station or no time: unchanged.
-- shortcut: no cap on offline seconds; the server clamps the time it passes in.
function StationRules.train(animal: Owned, stationId: string, seconds: number): Owned
	local st = StationConfig.station(stationId)
	if st == nil or seconds <= 0 then
		return animal
	end
	local trained = if animal.trained then table.clone(animal.trained) else table.clone(StationRules.ZERO)
	local hatched = (animal.stats :: any)[st.stat]
	local cap = math.min(hatched * StationConfig.POTENTIAL, StationConfig.STAT_MAX - hatched)
	local now = (trained :: any)[st.stat] + seconds / StationConfig.TRAIN_SECONDS;
	(trained :: any)[st.stat] = math.min(now, cap)
	local out = table.clone(animal)
	out.trained = trained
	return out
end

return StationRules
