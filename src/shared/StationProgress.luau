--!strict
-- Pure Animal Stations saved profile (decisions 0025, 0027, 0029, 0034, 0036): defaults, sanitize,
-- the player level, buying eggs into the egg storage, hatching and opening them, the team
-- and its Titan slot, training (settled from timestamps in real time, also while the player is
-- away) and the ranch upgrades. Every change takes its inputs (the hatched animal, `now`)
-- as arguments, so SaveStore can run it twice. No Roblox APIs; the server owns the Rng and the clock.

local LevelRules = require("./LevelRules")
local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local StationProgress = {}

type Stats = StationConfig.Stats
-- One owned animal: the hatched Owned fields plus an id, and where it trains (at = station id)
-- since when (os.time).
export type Animal = { id: number, s: string, v: string?, stats: Stats, trained: Stats?, at: string?, since: number? }
-- A bought egg: which egg, since when it has been hatching (os.time; nil while it waits in the
-- egg storage), and the animal the server rolled for it when it was bought. The animal is never
-- sent to the client (`public`).
export type HeldEgg = { egg: string, since: number?, animal: StationRules.Owned }
export type Profile = {
	version: number,
	coins: number,
	nextId: number,
	animals: { Animal },
	team: { number }, -- animal ids, at most TEAM_SIZE, never a Titan or one that is training
	titan: number?, -- the fourth slot: one Titan's id (decision 0027)
	best: number, -- highest wave (endless level) cleared
	xp: number, -- player XP; the player level comes from it (playerLevel)
	samples: number, -- dropped by harder waves; with coins they pay for ranch upgrades
	upgrades: { [string]: number }, -- level of each ranch upgrade (StationConfig.UPGRADES), 0 = not bought
	eggs: { HeldEgg }, -- bought eggs, oldest first: at most MAX_EGGS hatching, the rest in the egg storage
}

StationProgress.VERSION = 1
StationProgress.START_COINS = 300 -- three Meadow eggs: a first team
StationProgress.MAX_COINS = 1e15
StationProgress.MAX_ANIMALS = 100 -- the most a save can hold; the Barn sets how many a player may keep
StationProgress.MAX_SAMPLES = 1e9
StationProgress.MAX_EGGS = 6 -- eggs hatching at once
StationProgress.MAX_STORED = 24 -- eggs the egg storage holds besides
StationProgress.TEAM_SIZE = LevelRules.TEAM_SIZE
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
		samples = 0,
		upgrades = {},
		eggs = {},
	}
end

-- What ranch upgrade `id` gives `p` now: animals training at once ("house"), animals kept
-- ("barn"), training speed in percent ("grounds").
function StationProgress.value(p: Profile, id: string): number
	local u = StationConfig.upgrade(id) :: StationConfig.Upgrade
	local level = p.upgrades[id] or 0
	return if level > 0 then u.levels[level].value else u.base
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

-- The fields of a stored animal that are its own (species, variant, stats, stat levels), cleaned;
-- nil when the species is unknown.
local function owned(a: any): StationRules.Owned?
	if type(a) ~= "table" or type(a.s) ~= "string" or StationConfig.species(a.s) == nil then
		return nil
	end
	local v = if type(a.v) == "string" and StationConfig.variant(a.s, a.v) then a.v else nil
	local version = StationRules.versionStats(a.s, v) :: Stats
	local stats = cleanStats(a.stats, StationConfig.STAT_MIN, StationConfig.STAT_MAX, version)
	for _, stat in StationConfig.STATS do
		(stats :: any)[stat] = math.floor((stats :: any)[stat])
	end
	local trained = if type(a.trained) == "table"
		then cleanStats(a.trained, 0, StationConfig.MAX_LEVEL, StationRules.ZERO)
		else nil
	return { s = a.s, v = v, stats = stats, trained = trained }
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
	p.samples = int(record.samples, 0, StationProgress.MAX_SAMPLES, 0)
	for _, u in StationConfig.UPGRADES do
		local stored = if type(record.upgrades) == "table" then record.upgrades[u.id] else nil
		p.upgrades[u.id] = int(stored, 0, #u.levels, 0)
	end
	local slots = StationProgress.value(p, "house")
	local ids: { [number]: Animal } = {}
	local maxId = 0
	local training = 0
	if type(record.animals) == "table" then
		for _, a in record.animals do
			if #p.animals >= StationProgress.MAX_ANIMALS then
				break
			end
			local own = owned(a)
			local id = if own then int(a.id, 1, 1e12, 0) else 0
			if own == nil or id == 0 or ids[id] then
				continue
			end
			local animal: Animal = { id = id, s = own.s, v = own.v, stats = own.stats, trained = own.trained }
			if type(a.at) == "string" and StationConfig.station(a.at) and training < slots then
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
	if type(record.eggs) == "table" then
		for _, e in record.eggs do
			local animal = if type(e) == "table" then owned(e.animal) else nil
			local room = #p.eggs < StationProgress.MAX_EGGS + StationProgress.MAX_STORED
			if animal and type(e.egg) == "string" and StationConfig.egg(e.egg) and room then
				local started = type(e.since) == "number" and StationProgress.hatching(p) < StationProgress.MAX_EGGS
				local since = if started then int(e.since, 0, MAX_TIME, now or 0) else nil
				table.insert(p.eggs, { egg = e.egg, since = since, animal = animal })
			end
		end
	end
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

-- How many of `p`'s eggs are hatching (the others wait in the egg storage).
function StationProgress.hatching(p: Profile): number
	local n = 0
	for _, e in p.eggs do
		n += if e.since then 1 else 0
	end
	return n
end

-- Whether `p` can buy `eggId` now; the code says why not.
function StationProgress.canBuy(p: Profile, eggId: string): (boolean, string?)
	local egg = StationConfig.egg(eggId)
	if egg == nil then
		return false, "egg"
	elseif egg.unlock and StationProgress.playerLevel(p) < egg.unlock then
		return false, "locked"
	elseif #p.eggs >= StationProgress.MAX_EGGS + StationProgress.MAX_STORED then
		return false, "eggs_full"
	elseif p.coins < egg.price then
		return false, "coins"
	end
	return true, nil
end

-- Pay for `eggId`, earn its XP and put it in the egg storage with the animal the server rolled
-- for it (StationRules.hatch). The player chooses when it hatches (`start`) and opens it when it
-- is done (`crack`).
function StationProgress.buy(p: Profile, eggId: string, hatched: StationRules.Owned): (Profile, boolean, string?)
	local ok, code = StationProgress.canBuy(p, eggId)
	if not ok then
		return p, false, code
	end
	local egg = StationConfig.egg(eggId) :: StationConfig.Egg
	p.coins -= egg.price
	p.xp = math.min(p.xp + egg.xp, StationProgress.MAX_XP)
	local animal: StationRules.Owned = {
		s = hatched.s,
		v = hatched.v,
		stats = table.clone(hatched.stats),
		trained = if hatched.trained then table.clone(hatched.trained) else nil, -- the base levels
	}
	p.eggs = table.clone(p.eggs)
	table.insert(p.eggs, { egg = eggId, animal = animal })
	return p, true, nil
end

-- Start hatching the `k`th egg at `now`: it must be in the storage, and one of the six hatching
-- places must be free.
function StationProgress.start(p: Profile, k: number, now: number): (Profile, boolean, string?)
	local e = p.eggs[k]
	if e == nil then
		return p, false, "egg"
	elseif e.since then
		return p, false, "hatching"
	elseif StationProgress.hatching(p) >= StationProgress.MAX_EGGS then
		return p, false, "nests_full"
	end
	p.eggs = table.clone(p.eggs)
	p.eggs[k] = { egg = e.egg, since = now, animal = e.animal }
	return p, true, nil
end

-- True when egg `e` is hatching and has waited its hatch time: it can be opened.
function StationProgress.due(e: { egg: string, since: number? }, now: number): boolean
	local egg = StationConfig.egg(e.egg)
	return egg ~= nil and e.since ~= nil and now >= e.since + egg.hatch
end

-- Open the `k`th egg: it must have finished hatching and the Barn must have room. Its animal
-- joins the collection with a new id, and the team while that has room (a Titan takes the Titan
-- slot if it is empty). Returns the animal.
function StationProgress.crack(p: Profile, k: number, now: number): (Profile, boolean, string?, Animal?)
	local e = p.eggs[k]
	if e == nil then
		return p, false, "egg", nil
	elseif not StationProgress.due(e, now) then
		return p, false, "not_ready", nil
	elseif #p.animals >= math.min(StationProgress.value(p, "barn"), StationProgress.MAX_ANIMALS) then
		return p, false, "full", nil
	end
	local animal: Animal =
		{ id = p.nextId, s = e.animal.s, v = e.animal.v, stats = e.animal.stats, trained = e.animal.trained }
	p.nextId += 1
	table.insert(p.animals, animal)
	if StationProgress.isTitan(animal) then
		p.titan = p.titan or animal.id
	elseif #p.team < StationProgress.TEAM_SIZE then
		table.insert(p.team, animal.id)
	end
	p.eggs = table.clone(p.eggs)
	table.remove(p.eggs, k)
	return p, true, nil, animal
end

-- The profile as the client may see it: the held eggs without the animals inside them.
function StationProgress.public(p: Profile): any
	local copy = table.clone(p) :: any
	copy.eggs = {}
	for k, e in p.eggs do
		copy.eggs[k] = { egg = e.egg, since = e.since }
	end
	return copy
end

-- Training seconds earned in `seconds` of real time: the Training Grounds make it go faster.
function StationProgress.trainingSeconds(p: Profile, seconds: number): number
	return math.max(0, seconds) * StationProgress.value(p, "grounds") / 100
end

-- Add training time to every training animal up to `now`. Every stat level gained gives the
-- player XP. An animal whose stat reaches MAX_LEVEL is done: it stops training and frees its place.
function StationProgress.settle(p: Profile, now: number): Profile
	for i, a in p.animals do
		if a.at and a.since then
			local st = StationConfig.station(a.at) :: StationConfig.Station
			local t = StationRules.train(a :: any, a.at, StationProgress.trainingSeconds(p, now - a.since))
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
		if n >= StationProgress.value(p, "house") then
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

-- Whether `p` can buy the next level of ranch upgrade `id` now; the code says why not.
function StationProgress.canUpgrade(p: Profile, id: string): (boolean, string?)
	local u = StationConfig.upgrade(id)
	if u == nil then
		return false, "upgrade"
	end
	local cost = u.levels[(p.upgrades[id] or 0) + 1]
	if cost == nil then
		return false, "top"
	elseif p.coins < cost.coins then
		return false, "coins"
	elseif p.samples < cost.samples then
		return false, "samples"
	end
	return true, nil
end

-- Buy the next level of ranch upgrade `id`. Training is settled first, so time already spent
-- counts at the old speed.
function StationProgress.upgrade(p: Profile, id: string, now: number): (Profile, boolean, string?)
	local ok, code = StationProgress.canUpgrade(p, id)
	if not ok then
		return p, false, code
	end
	p = StationProgress.settle(p, now)
	local level = (p.upgrades[id] or 0) + 1
	local cost = (StationConfig.upgrade(id) :: StationConfig.Upgrade).levels[level]
	p.coins -= cost.coins
	p.samples -= cost.samples
	p.upgrades = table.clone(p.upgrades)
	p.upgrades[id] = level
	return p, true, nil
end

-- Whether `p` can send its team at wave `level` now: any wave up to one past the best cleared,
-- with at least one animal on the team. The code says why not.
function StationProgress.canFight(p: Profile, level: number): (boolean, string?)
	if level < 1 or level > p.best + 1 or level ~= math.floor(level) then
		return false, "wave"
	elseif #StationProgress.fighters(p) == 0 then
		return false, "no_team"
	end
	return true, nil
end

-- What clearing wave `level` pays `p` now: coins, player XP and samples.
function StationProgress.payout(p: Profile, level: number): (number, number, number)
	return LevelRules.reward(level, p.best), LevelRules.xp(level, p.best), LevelRules.samples(level, p.best)
end

-- Pay for clearing wave `level` (the server has decided the fight was won) and record it as the
-- best if it is.
function StationProgress.clear(p: Profile, level: number): (Profile, boolean, string?)
	local ok, code = StationProgress.canFight(p, level)
	if not ok then
		return p, false, code
	end
	local coins, xp, samples = StationProgress.payout(p, level)
	p.coins = math.min(p.coins + coins, StationProgress.MAX_COINS)
	p.xp = math.min(p.xp + xp, StationProgress.MAX_XP)
	p.samples = math.min(p.samples + samples, StationProgress.MAX_SAMPLES)
	p.best = math.max(p.best, level)
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
