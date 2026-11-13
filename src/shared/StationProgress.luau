--!strict
-- Pure Animal Stations saved profile (decisions 0025, 0027, 0029): defaults, sanitize, the player
-- level, buying and hatching eggs, the team and its Titan slot, and training (settled from
-- timestamps in real time, also while the player is away). Every change takes its inputs (the hatched animal, `now`)
-- as arguments, so SaveStore can run it twice. No Roblox APIs; the server owns the Rng and the clock.

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
	team: { number }, -- animal ids, at most TEAM_SIZE, never a Titan or one that is training
	titan: number?, -- the fourth slot: one Titan's id (decision 0027)
	best: number, -- highest wave (endless level) cleared
	xp: number, -- player XP; the player level comes from it (playerLevel)
}

StationProgress.VERSION = 1
StationProgress.START_COINS = 300 -- three Meadow eggs: a first team
StationProgress.MAX_COINS = 1e15
StationProgress.MAX_ANIMALS = 100
StationProgress.TEAM_SIZE = LevelRules.TEAM_SIZE
StationProgress.TRAIN_MAX = 4 -- animals training at once
StationProgress.MAX_XP = 1e12
StationProgress.XP_STEP = 25 -- total XP for player level n is XP_STEP x (n - 1)^2

local MAX_TIME = 1e12

function StationProgress.defaults(_now: number): Profile
	return {
		version = StationProgress.VERSION,
		coins = StationProgress.START_COINS,
		nextId = 1,
		animals = {},
		team = {},
		best = 0,
		xp = 0,
	}
end

-- Total XP needed to be player level `level` (level 1 needs none, level 15 needs 4,900).
function StationProgress.xpFor(level: number): number
	return StationProgress.XP_STEP * (level - 1) ^ 2
end

-- The player's level. XP comes from everything the player does: so far hatching eggs and every
-- stat level a creature gains. Not the same as a stat level or a wave.
function StationProgress.playerLevel(p: Profile): number
	return math.floor(math.sqrt(p.xp / StationProgress.XP_STEP)) + 1
end

local function int(x: any, lo: number, hi: number, fallback: number): number
	if type(x) ~= "number" or x ~= x then
		return fallback
	end
	return math.clamp(math.floor(x), lo, hi)
end

-- A stored number for every stat, clamped. A missing or bad one takes the fallback, so a save
-- written before a stat existed keeps its animals instead of losing them.
local function cleanStats(x: any, lo: number, hi: number, fallback: Stats): Stats
	local out = {} :: any
	for _, stat in StationConfig.STATS do
		local n = if type(x) == "table" then x[stat] else nil
		out[stat] = if type(n) == "number" and n == n then math.clamp(n, lo, hi) else (fallback :: any)[stat]
	end
	return out :: Stats
end

function StationProgress.isTitan(a: Animal): boolean
	return StationRules.role(a :: any) == StationConfig.TITAN
end

-- A stored record in any shape becomes a valid profile: unknown animals dropped, missing stats
-- filled from the animal's version, numbers clamped, the team and training rebuilt to the rules.
function StationProgress.sanitize(record: any, now: number?): Profile
	local p = StationProgress.defaults(now or 0)
	if type(record) ~= "table" then
		return p
	end
	p.coins = int(record.coins, 0, StationProgress.MAX_COINS, p.coins)
	p.best = int(record.best, 0, 1e9, 0)
	p.xp = int(record.xp, 0, StationProgress.MAX_XP, 0)
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
			if id == 0 or ids[id] then
				continue
			end
			local version = StationRules.versionStats(a.s, v) :: Stats
			local stats = cleanStats(a.stats, StationConfig.STAT_MIN, StationConfig.STAT_MAX, version)
			for _, stat in StationConfig.STATS do
				(stats :: any)[stat] = math.floor((stats :: any)[stat])
			end
			local trained = if type(a.trained) == "table"
				then cleanStats(a.trained, 0, StationConfig.MAX_LEVEL, StationRules.ZERO)
				else nil
			local animal: Animal = { id = id, s = a.s, v = v, stats = stats, trained = trained }
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
			if
				a
				and a.at == nil
				and not StationProgress.isTitan(a)
				and not table.find(p.team, id)
				and #p.team < StationProgress.TEAM_SIZE
			then
				table.insert(p.team, id)
			end
		end
	end
	local t = if type(record.titan) == "number" then ids[record.titan] else nil
	if t and t.at == nil and StationProgress.isTitan(t) then
		p.titan = t.id
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
	elseif egg.unlock and StationProgress.playerLevel(p) < egg.unlock then
		return false, "locked"
	elseif #p.animals >= StationProgress.MAX_ANIMALS then
		return false, "full"
	elseif p.coins < egg.price then
		return false, "coins"
	end
	return true, nil
end

-- Pay for `eggId`, add `hatched` (rolled by the server with StationRules.hatch) and earn the egg's
-- XP. The animal joins the team while it has room (a Titan takes the Titan slot if it is empty).
-- Returns the new animal's id.
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
	p.xp = math.min(p.xp + egg.xp, StationProgress.MAX_XP)
	local id = p.nextId
	p.nextId += 1
	local animal: Animal = {
		id = id,
		s = hatched.s,
		v = hatched.v,
		stats = table.clone(hatched.stats),
		trained = if hatched.trained then table.clone(hatched.trained) else nil, -- the base levels
	}
	table.insert(p.animals, animal)
	if StationProgress.isTitan(animal) then
		p.titan = p.titan or id
	elseif #p.team < StationProgress.TEAM_SIZE then
		table.insert(p.team, id)
	end
	return p, true, nil, id
end

-- Add training time to every training animal up to `now`. Every stat level gained gives the
-- player XP. An animal whose stat reaches MAX_LEVEL is done: it stops training and frees its place.
function StationProgress.settle(p: Profile, now: number): Profile
	for i, a in p.animals do
		if a.at and a.since then
			local st = StationConfig.station(a.at) :: StationConfig.Station
			local t = StationRules.train(a :: any, a.at, math.max(0, now - a.since))
			local copy = table.clone(a)
			copy.trained = t.trained
			copy.since = math.max(a.since, now)
			local gained = StationRules.level(copy :: any, st.stat) - StationRules.level(a :: any, st.stat)
			p.xp = math.min(p.xp + gained * StationConfig.XP_STAT_LEVEL, StationProgress.MAX_XP)
			if StationRules.level(copy :: any, st.stat) >= StationConfig.MAX_LEVEL then
				copy.at, copy.since = nil, nil
			end
			p.animals[i] = copy
		end
	end
	return p
end

-- Put animal `id` in or out of the team. A Titan goes in the Titan slot (replacing the one
-- there). A training animal cannot join.
function StationProgress.toggleTeam(p: Profile, id: number): (Profile, boolean, string?)
	local _, a = StationProgress.find(p, id)
	if a == nil then
		return p, false, "animal"
	end
	if StationProgress.isTitan(a) then
		if p.titan == id then
			p.titan = nil
		elseif a.at then
			return p, false, "training"
		else
			p.titan = id
		end
		return p, true, nil
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
	local st = StationConfig.station(stationId)
	if i == nil or a == nil then
		return p, false, "animal"
	elseif st == nil then
		return p, false, "station"
	elseif StationRules.level(a :: any, st.stat) >= StationConfig.MAX_LEVEL then
		return p, false, "maxed"
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
	if p.titan == id then
		p.titan = nil
	end
	return p, true, nil
end

-- Stop animal `id` training, keeping the levels and progress it earned.
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

-- The animals that fight: the team in order, then the Titan.
function StationProgress.fighters(p: Profile): { Animal }
	local out = {}
	for _, id in p.team do
		local _, a = StationProgress.find(p, id)
		if a then
			table.insert(out, a)
		end
	end
	if p.titan then
		local _, a = StationProgress.find(p, p.titan)
		if a then
			table.insert(out, a)
		end
	end
	return out
end

-- Written on every save: training is settled so the stored levels are current.
function StationProgress.snapshot(p: Profile, now: number): Profile
	return StationProgress.settle(p, now)
end

return StationProgress
