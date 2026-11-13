--!strict
-- Pure Animal Stations saved profile (decision 0025): defaults, sanitize, buying and hatching eggs,
-- the team, and training at stations (settled from timestamps, offline time capped). Every change
-- takes its inputs (the hatched animal, `now`) as arguments, so SaveStore can run it twice.
-- No Roblox APIs; the server owns the Rng and the clock.

local LevelRules = require("./LevelRules")
local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local StationProgress = {}

type Stats = StationConfig.Stats
-- One owned animal: the hatched Owned fields plus an id, and where it trains (at = station id)
-- since when (os.time).
export type Animal = { id: number, s: string, v: string?, stats: Stats, trained: Stats?, at: string?, since: number? }
export type Profile = {
	version: number,
	coins: number,
	nextId: number,
	animals: { Animal },
	team: { number }, -- animal ids, at most TEAM_SIZE, never one that is training
	best: number, -- highest level cleared
}

StationProgress.VERSION = 1
StationProgress.START_COINS = 300 -- three Meadow eggs: a first team
StationProgress.MAX_COINS = 1e15
StationProgress.MAX_ANIMALS = 100
StationProgress.TEAM_SIZE = LevelRules.TEAM_SIZE
StationProgress.TRAIN_MAX = 4 -- animals training at once
StationProgress.OFFLINE_MAX = 8 * 3600 -- training seconds counted per settle while away

local MAX_TIME = 1e12

function StationProgress.defaults(_now: number): Profile
	return {
		version = StationProgress.VERSION,
		coins = StationProgress.START_COINS,
		nextId = 1,
		animals = {},
		team = {},
		best = 0,
	}
end

local function int(x: any, lo: number, hi: number, fallback: number): number
	if type(x) ~= "number" or x ~= x then
		return fallback
	end
	return math.clamp(math.floor(x), lo, hi)
end

local function cleanStats(x: any, hi: number): Stats?
	if type(x) ~= "table" then
		return nil
	end
	local out = {} :: any
	for _, stat in StationConfig.STATS do
		local n = x[stat]
		if type(n) ~= "number" or n ~= n then
			return nil
		end
		out[stat] = math.clamp(n, 0, hi)
	end
	return out :: Stats
end

-- A stored record in any shape becomes a valid profile: bad animals dropped, numbers clamped,
-- the team and training rebuilt to the rules.
function StationProgress.sanitize(record: any, now: number?): Profile
	local p = StationProgress.defaults(now or 0)
	if type(record) ~= "table" then
		return p
	end
	p.coins = int(record.coins, 0, StationProgress.MAX_COINS, p.coins)
	p.best = int(record.best, 0, 1e9, 0)
	local ids: { [number]: Animal } = {}
	local maxId = 0
	local training = 0
	if type(record.animals) == "table" then
		for _, a in record.animals do
			if #p.animals >= StationProgress.MAX_ANIMALS then
				break
			end
			if type(a) ~= "table" or type(a.s) ~= "string" or StationConfig.species(a.s) == nil then
				continue
			end
			local v = if type(a.v) == "string" and StationConfig.variant(a.s, a.v) then a.v else nil
			local id = int(a.id, 1, 1e12, 0)
			local stats = cleanStats(a.stats, StationConfig.STAT_MAX)
			if id == 0 or ids[id] or stats == nil then
				continue
			end
			for _, stat in StationConfig.STATS do
				(stats :: any)[stat] = math.max(StationConfig.STAT_MIN, math.floor((stats :: any)[stat]))
			end
			local trained = cleanStats(a.trained, StationConfig.STAT_MAX)
			local animal: Animal = { id = id, s = a.s, v = v, stats = stats :: Stats, trained = trained }
			if type(a.at) == "string" and StationConfig.station(a.at) and training < StationProgress.TRAIN_MAX then
				animal.at = a.at
				animal.since = int(a.since, 0, MAX_TIME, now or 0)
				training += 1
			end
			ids[id] = animal
			maxId = math.max(maxId, id)
			table.insert(p.animals, animal)
		end
	end
	p.nextId = math.max(int(record.nextId, 1, 1e12, 1), maxId + 1)
	if type(record.team) == "table" then
		for _, id in record.team do
			local a = if type(id) == "number" then ids[id] else nil
			if a and a.at == nil and not table.find(p.team, id) and #p.team < StationProgress.TEAM_SIZE then
				table.insert(p.team, id)
			end
		end
	end
	return p
end

function StationProgress.find(p: Profile, id: number): (number?, Animal?)
	for i, a in p.animals do
		if a.id == id then
			return i, a
		end
	end
	return nil, nil
end

-- Whether `p` can buy `eggId` now; the code says why not.
function StationProgress.canBuy(p: Profile, eggId: string): (boolean, string?)
	local egg = StationConfig.egg(eggId)
	if egg == nil then
		return false, "egg"
	elseif #p.animals >= StationProgress.MAX_ANIMALS then
		return false, "full"
	elseif p.coins < egg.price then
		return false, "coins"
	end
	return true, nil
end

-- Pay for `eggId` and add `hatched` (rolled by the server with StationRules.hatch). Joins the team
-- while it has room. Returns the new animal's id.
function StationProgress.buy(
	p: Profile,
	eggId: string,
	hatched: StationRules.Owned
): (Profile, boolean, string?, number?)
	local ok, code = StationProgress.canBuy(p, eggId)
	if not ok then
		return p, false, code, nil
	end
	local egg = StationConfig.egg(eggId) :: StationConfig.Egg
	p.coins -= egg.price
	local id = p.nextId
	p.nextId += 1
	table.insert(p.animals, { id = id, s = hatched.s, v = hatched.v, stats = table.clone(hatched.stats) })
	if #p.team < StationProgress.TEAM_SIZE then
		table.insert(p.team, id)
	end
	return p, true, nil, id
end

-- Add training time to every training animal up to `now` (at most OFFLINE_MAX per settle).
function StationProgress.settle(p: Profile, now: number): Profile
	for i, a in p.animals do
		if a.at and a.since then
			local seconds = math.clamp(now - a.since, 0, StationProgress.OFFLINE_MAX)
			local t = StationRules.train(a :: any, a.at, seconds)
			local copy = table.clone(a)
			copy.trained = t.trained
			copy.since = math.max(a.since, now)
			p.animals[i] = copy
		end
	end
	return p
end

-- Put animal `id` in or out of the team. A training animal cannot join.
function StationProgress.toggleTeam(p: Profile, id: number): (Profile, boolean, string?)
	local _, a = StationProgress.find(p, id)
	if a == nil then
		return p, false, "animal"
	end
	local at = table.find(p.team, id)
	if at then
		table.remove(p.team, at)
		return p, true, nil
	elseif a.at then
		return p, false, "training"
	elseif #p.team >= StationProgress.TEAM_SIZE then
		return p, false, "team_full"
	end
	table.insert(p.team, id)
	return p, true, nil
end

-- Start animal `id` training at `stationId` (it leaves the team), or move it to another station.
function StationProgress.train(p: Profile, id: number, stationId: string, now: number): (Profile, boolean, string?)
	local i, a = StationProgress.find(p, id)
	if i == nil or a == nil then
		return p, false, "animal"
	elseif StationConfig.station(stationId) == nil then
		return p, false, "station"
	end
	if a.at == nil then
		local n = 0
		for _, x in p.animals do
			n += if x.at then 1 else 0
		end
		if n >= StationProgress.TRAIN_MAX then
			return p, false, "train_full"
		end
	end
	p = StationProgress.settle(p, now)
	local copy = table.clone(p.animals[i])
	copy.at, copy.since = stationId, now
	p.animals[i] = copy
	local t = table.find(p.team, id)
	if t then
		table.remove(p.team, t)
	end
	return p, true, nil
end

-- Stop animal `id` training, keeping the points it earned.
function StationProgress.stop(p: Profile, id: number, now: number): (Profile, boolean, string?)
	local i, a = StationProgress.find(p, id)
	if i == nil or a == nil then
		return p, false, "animal"
	elseif a.at == nil then
		return p, false, "idle"
	end
	p = StationProgress.settle(p, now)
	local copy = table.clone(p.animals[i])
	copy.at, copy.since = nil, nil
	p.animals[i] = copy
	return p, true, nil
end

-- Written on every save: training is settled so the stored stats are current.
function StationProgress.snapshot(p: Profile, now: number): Profile
	return StationProgress.settle(p, now)
end

return StationProgress
