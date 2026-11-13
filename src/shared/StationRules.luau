--!strict
-- Pure Animal Stations rules (decisions 0019, 0020): hatch an animal (species, then a rare variant
-- roll, then stats), and what it earns at each station. The server owns the Rng state; the client
-- never sends stats or amounts.

local Rng = require("./Rng")
local StationConfig = require("./StationConfig")

local StationRules = {}

type Stats = StationConfig.Stats
export type Owned = { s: string, v: string?, stats: Stats } -- one hatched animal; v nil = basic

-- Stat curve: earnings grow faster than the stat, so a specialist clearly beats an all-rounder.
StationRules.CURVE = 1.5
StationRules.PPM = 1_000_000

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

-- Coins per second for `animal` working at `stationId`; 0 for an unknown station.
function StationRules.rate(animal: Owned, stationId: string): number
	local st = StationConfig.station(stationId)
	if st == nil then
		return 0
	end
	local stat = (animal.stats :: any)[st.stat] :: number
	return st.coinsPerSec * (stat / 100) ^ StationRules.CURVE
end

-- The station where `animal` earns most (ties go to the first station in the list).
function StationRules.bestStation(animal: Owned): (string, number)
	local bestId, bestRate = StationConfig.STATIONS[1].id, -1
	for _, st in StationConfig.STATIONS do
		local r = StationRules.rate(animal, st.id)
		if r > bestRate then
			bestId, bestRate = st.id, r
		end
	end
	return bestId, bestRate
end

-- Total coins per second for a list of { animal, station } assignments.
function StationRules.income(assignments: { { animal: Owned, station: string } }): number
	local total = 0
	for _, a in assignments do
		total += StationRules.rate(a.animal, a.station)
	end
	return total
end

return StationRules
