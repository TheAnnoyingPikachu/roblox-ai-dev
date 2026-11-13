--!strict
-- Pure Animal Stations rules (decision 0019): hatch an animal with rolled stats, and what it earns
-- at each station. The server owns the Rng state; the client never sends stats or amounts.

local Rng = require("./Rng")
local StationConfig = require("./StationConfig")

local StationRules = {}

export type Owned = { s: string, stats: StationConfig.Stats } -- one hatched animal

-- Stat curve: earnings grow faster than the stat, so a specialist clearly beats an all-rounder.
StationRules.CURVE = 1.5

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

-- Hatch one animal from `eggId`. Nil for an unknown egg (the server refuses the request).
function StationRules.hatch(eggId: string, rng: Rng.State): (Owned?, Rng.State)
	local egg = StationConfig.egg(eggId)
	if egg == nil then
		return nil, rng
	end
	local r
	r, rng = Rng.int(rng, 1, 10000)
	local species = StationRules.pick(egg.odds, r)
	local base = (StationConfig.animal(species) :: StationConfig.Animal).stats
	local stats = {} :: any
	for _, stat in StationConfig.STATS do
		local pct
		pct, rng = Rng.int(rng, 100 - StationConfig.VARIANCE, 100 + StationConfig.VARIANCE)
		local v = math.floor((base :: any)[stat] * pct / 100)
		stats[stat] = math.clamp(v, StationConfig.STAT_MIN, StationConfig.STAT_MAX)
	end
	return { s = species, stats = stats :: StationConfig.Stats }, rng
end

-- Coins per second for `animal` working at `stationId`; 0 for an unknown station.
function StationRules.rate(animal: Owned, stationId: string): number
	local st = StationConfig.station(stationId)
	if st == nil then
		return 0
	end
	local stat = (animal.stats :: any)[st.stat] :: number
	return st.coinsPerSec * (stat / StationConfig.STAT_MAX) ^ StationRules.CURVE
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
