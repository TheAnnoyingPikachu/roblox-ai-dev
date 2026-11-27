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
-- since when (os.time). coat: the coat it wears (decision 0110); rainbow = true beside coat = "rainbow"
-- (decision 0058: saves from before coats have only that).
export type Animal = {
	id: number,
	s: string,
	v: string?,
	stats: Stats,
	trained: Stats?,
	rainbow: boolean?,
	coat: string?,
	at: string?,
	since: number?,
	slot: number?, -- training: the team slot it left (0 = the Titan's), where Stop puts it back
	locked: boolean?, -- its owner locked it: it cannot go in a trade (decision 0099)
}
-- A finished trade as the save remembers it (decision 0099): its id (the ledger's), who with, the names
-- of what went each way and when. `trades.log` keeps the newest TRADE_LOG; a trade whose id is in it
-- has been applied to this save, which is what makes the ledger's heal safe to run again.
export type TradeEntry = { id: string, with: string, gave: { string }, got: { string }, at: number }
export type Trades = { day: number, count: number, total: number, off: boolean, log: { TradeEntry } }
-- A bought egg: which egg, since when it has been hatching (os.time; nil while it waits in the
-- egg storage), and the animal the server rolled for it when it was bought. The animal is never
-- sent to the client (`public`).
-- `quick`: one of the intro's starter eggs, which hatches in QUICK_SECONDS (decision 0116).
export type HeldEgg = { egg: string, since: number?, animal: StationRules.Owned, quick: boolean? }
-- A boost (decision 0094): from `from` to `to` (os.time), eggs hatch (or animals train) twice as fast.
export type Window = { from: number, to: number }
export type Boosts = { hatch: { Window }, train: { Window } }
-- The planners and the daily wheel (decision 0094, StationRewards): `day` the last UTC day counted (days
-- since 1970), the week and month being counted (the Monday's day; year * 12 + month - 1), days logged and
-- rewards claimed in each, the last free spin's day, extra spins, spins since a jackpot, and eggs won
-- while the egg storage was full, waiting for room.
export type Rewards = {
	day: number,
	week: number,
	weekDays: number,
	weekGot: number,
	month: number,
	monthDays: number,
	monthGot: { number },
	spinDay: number,
	spins: number,
	pity: number,
	pending: { HeldEgg },
}
export type Profile = {
	version: number,
	coins: number,
	nextId: number,
	animals: { Animal },
	team: { number }, -- animal ids, at most TEAM_SIZE, never a Titan or one that is training
	titan: number?, -- the fourth slot: one Titan's id (decision 0027)
	best: number, -- highest wave cleared (LevelRules.LAST at most)
	xp: number, -- player XP; the player level comes from it (playerLevel)
	samples: number, -- dropped by harder waves; with coins they pay for ranch upgrades
	upgrades: { [string]: number }, -- level of each ranch upgrade (StationConfig.UPGRADES), 0 = not bought
	eggs: { HeldEgg }, -- bought eggs, oldest first: some hatching (the Hatchery says how many), the rest in the egg storage
	mill: number?, -- when the Windmill was last emptied (os.time); nil without one
	boosts: Boosts,
	rewards: Rewards,
	stars: string, -- the best stars won on each wave (decision 0097): character n is wave n's, "0" to "3"
	chests: number, -- star chests opened (one is due every CHEST_STARS stars)
	trades: Trades, -- trades today (UTC `day`), all time, requests off, and the history (decision 0099)
	goals: { string }, -- ids of the goals finished and paid (decision 0115, StationGoals)
	intro: boolean, -- the intro is done or skipped (decision 0116, StationIntro): it never shows twice
	receipts: { string }, -- the Robux purchases granted, newest last (decision 0117): a receipt is granted once
	beta: boolean, -- the beta reward is given (decision 0117)
	met: { string }, -- the animals met (decision 0118): "species/variant" keys, "lion/" for the plain species
	loan: { boss: boolean, day: number }, -- the Ranger's loan (decision 0119, StationIntro): the wave 10 boss's is
	-- used, and the UTC day of the last one
	herd: number, -- when the ranch animals' coins were last collected (os.time, decision 0124)
}

-- Animals met (decision 0118): what the Animals window's Seen tab draws from. `meet` adds a version once (a
-- species, or a species and one of its variants); anything not in StationConfig is left out, so the list is
-- never longer than the versions there are. Owning an animal meets it (hatched, given, granted, traded).
local VERSIONS = 0
for _, sp in StationConfig.SPECIES do
	VERSIONS += 1 + #sp.variants
end
StationProgress.MAX_MET = VERSIONS
function StationProgress.metKey(s: string, v: string?): string
	return `{s}/{v or ""}`
end
function StationProgress.meet(p: Profile, s: string, v: string?): Profile
	local key = StationProgress.metKey(s, v)
	if table.find(p.met, key) == nil and StationRules.versionStats(s, v) ~= nil and #p.met < VERSIONS then
		p.met = table.clone(p.met)
		table.insert(p.met, key)
	end
	return p
end

-- The content version (beta blocker 6, SHANNON's pick A): bump it with every release that adds species, variants,
-- eggs or coats. A server never loads a save whose `version` is above its own (`tooNew`, kit SaveStore): it would
-- strip what it does not know. A save is stamped with the version of the server that last wrote it.
StationProgress.VERSION = 4 -- 2: goals and the intro (decisions 0115, 0116); 3: the eternal pair (decision 0117); 4: met
-- and the Ranger's loan (0118, 0119)
StationProgress.START_COINS = 300 -- three Meadow eggs: a first team
StationProgress.MAX_COINS = 1e15
StationProgress.MAX_ANIMALS = 100 -- the most a save can hold; the Barn sets how many a player may keep
StationProgress.MAX_SAMPLES = 1e9
-- The most eggs a save can hold hatching and stored: the top of the Hatchery and of the Egg Cellar,
-- which set how many a player may have (decision 0072). A save is never cut down to fit a level.
StationProgress.MAX_EGGS = 10
StationProgress.MAX_STORED = 48
StationProgress.MILL_HOURS = 8 -- the Windmill holds this many hours of coins: then it is full and stops
StationProgress.TEAM_SIZE = LevelRules.TEAM_SIZE
StationProgress.MAX_XP = 1e12
StationProgress.XP_STEP = 25 -- total XP for player level n is XP_STEP x (n - 1)^2

local MAX_TIME = 1e12
StationProgress.MAX_WINDOWS = 16 -- boost windows a save keeps (the oldest go)
StationProgress.MAX_PENDING = 20 -- eggs won that wait for room
StationProgress.MAX_STAR_WAVES = 5000 -- waves a save keeps stars for
StationProgress.TRADE_LOG = 40 -- finished trades a save remembers (the menu shows the newest 20)
StationProgress.CHEST_STARS = 15
StationProgress.QUICK_SECONDS = 5 -- how long a starter egg takes to hatch
StationProgress.MAX_GOALS = 64 -- goal ids a save keeps (StationGoals has fewer)
StationProgress.MAX_RECEIPTS = 200 -- Robux purchases a save remembers (Roblox re-sends a receipt within days)
local KEEP = 30 * 86400 -- a boost window ended longer ago than this no longer matters

function StationProgress.defaults(now: number): Profile
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
		boosts = { hatch = {}, train = {} },
		rewards = {
			day = 0,
			week = 0,
			weekDays = 0,
			weekGot = 0,
			month = 0,
			monthDays = 0,
			monthGot = {},
			spinDay = 0,
			spins = 0,
			pity = 0,
			pending = {},
		},
		stars = "",
		chests = 0,
		trades = { day = 0, count = 0, total = 0, off = false, log = {} },
		goals = {},
		intro = false,
		receipts = {},
		beta = false,
		met = {},
		loan = { boss = false, day = 0 },
		herd = now or 0,
	}
end

-- What ranch upgrade `id` gives `p` now: animals training at once ("house"), animals kept
-- ("barn"), training speed in percent ("grounds"), eggs hatching at once ("hatchery"), eggs stored
-- ("cellar"), hatching speed in percent ("brooder"), coins an hour ("windmill"), wave coins in
-- percent ("lodge"), the Titan's stats in a wave in percent ("den").
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
	local coat = if type(a.coat) == "string" and StationConfig.coat(a.coat)
		then a.coat
		elseif a.rainbow == true then "rainbow"
		else nil
	return {
		s = a.s,
		v = v,
		stats = stats,
		trained = trained,
		coat = coat,
		rainbow = if coat == "rainbow" then true else nil,
	}
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
	if StationProgress.value(p, "windmill") > 0 then -- never ahead of the clock: it would not pay until then
		p.mill = math.min(int(record.mill, 0, MAX_TIME, now or 0), now or MAX_TIME)
	end
	local slots = StationProgress.value(p, "house")
	local ids: { [number]: Animal } = {}
	local maxId = 0
	local training = 0
	local taken: { [string]: boolean } = {} -- a station trains one animal: a save from before that rule keeps the first
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
			local animal: Animal = {
				id = id,
				s = own.s,
				v = own.v,
				stats = own.stats,
				trained = own.trained,
				rainbow = own.rainbow,
				coat = own.coat,
				locked = if a.locked == true then true else nil,
			}
			if type(a.at) == "string" and StationConfig.station(a.at) and training < slots and not taken[a.at] then
				taken[a.at] = true
				animal.at = a.at
				animal.since = int(a.since, 0, MAX_TIME, now or 0)
				animal.slot = if type(a.slot) == "number" then int(a.slot, 0, StationProgress.TEAM_SIZE, 0) else nil
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
				table.insert(
					p.eggs,
					{ egg = e.egg, since = since, animal = animal, quick = if e.quick == true then true else nil }
				)
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
	local boosts = if type(record.boosts) == "table" then record.boosts else {}
	for _, kind in { "hatch", "train" } do
		local list = boosts[kind]
		local kept = (p.boosts :: any)[kind]
		if type(list) == "table" then
			for _, w in list do
				local from = if type(w) == "table" then int(w.from, 0, MAX_TIME, -1) else -1
				local to = if type(w) == "table" then int(w.to, 0, MAX_TIME, -1) else -1
				if from >= 0 and to > from and to - from <= KEEP and to >= (now or 0) - KEEP then
					table.insert(kept, { from = from, to = to })
				end
			end
		end
		while #kept > StationProgress.MAX_WINDOWS do
			table.remove(kept, 1)
		end
	end
	local r = if type(record.rewards) == "table" then record.rewards else {}
	local w = p.rewards
	w.day = int(r.day, 0, 1e7, 0)
	w.week = int(r.week, 0, 1e7, 0)
	w.weekDays = int(r.weekDays, 0, 7, 0)
	w.weekGot = int(r.weekGot, 0, w.weekDays, 0)
	w.month = int(r.month, 0, 1e6, 0)
	w.monthDays = int(r.monthDays, 0, 31, 0)
	if type(r.monthGot) == "table" then
		for _, d in r.monthGot do
			if type(d) == "number" and d == math.floor(d) and d >= 1 and d <= 31 and not table.find(w.monthGot, d) then
				table.insert(w.monthGot, d)
			end
		end
	end
	w.spinDay = int(r.spinDay, 0, 1e7, 0)
	w.spins = int(r.spins, 0, 1000, 0)
	w.pity = int(r.pity, 0, 1e6, 0)
	if type(r.pending) == "table" then
		for _, e in r.pending do
			local animal = if type(e) == "table" then owned(e.animal) else nil
			local room = #w.pending < StationProgress.MAX_PENDING
			if animal and type(e.egg) == "string" and StationConfig.egg(e.egg) and room then
				table.insert(w.pending, { egg = e.egg, animal = animal })
			end
		end
	end
	if type(record.stars) == "string" then
		p.stars = string.sub(string.gsub(record.stars, "[^0-3]", "0"), 1, StationProgress.MAX_STAR_WAVES)
	end
	p.chests = int(record.chests, 0, 1e6, 0)
	-- the intro: done when the save says so, and for a save from before it that has already played
	p.intro = record.intro == true or (record.intro == nil and (#p.animals > 0 or #p.eggs > 0 or p.best > 0))
	local seen: { [string]: boolean } = {}
	for _, id in if type(record.goals) == "table" then record.goals else {} do -- which ids exist is StationGoals' business
		if type(id) == "string" and #id <= 16 and not seen[id] and #p.goals < StationProgress.MAX_GOALS then
			seen[id] = true
			table.insert(p.goals, id)
		end
	end
	for _, key in if type(record.receipts) == "table" then record.receipts else {} do
		if type(key) == "string" and #key <= 64 and table.find(p.receipts, key) == nil then
			table.insert(p.receipts, key)
		end
	end
	while #p.receipts > StationProgress.MAX_RECEIPTS do
		table.remove(p.receipts, 1)
	end
	p.beta = record.beta == true
	-- the animals met (decision 0118): known versions only, each once; every animal owned is met
	for _, key in if type(record.met) == "table" then record.met else {} do
		if type(key) == "string" and #key <= 64 then
			local s, v = string.match(key, "^([^/]+)/(.*)$")
			if s then
				StationProgress.meet(p, s, if v == "" then nil else v)
			end
		end
	end
	for _, a in p.animals do
		StationProgress.meet(p, a.s, a.v)
	end
	p.herd = math.min(int(record.herd, 0, MAX_TIME, now or 0), now or MAX_TIME) -- never ahead of the clock
	local loan = if type(record.loan) == "table" then record.loan else {}
	p.loan = { boss = loan.boss == true, day = int(loan.day, 0, 1e7, 0) }
	local stored = if type(record.trades) == "table" then record.trades else {}
	p.trades.day = int(stored.day, 0, 1e7, 0)
	p.trades.count = int(stored.count, 0, 1000, 0)
	p.trades.total = int(stored.total, 0, 1e9, 0)
	p.trades.off = stored.off == true
	if type(stored.log) == "table" then
		for _, e in stored.log do
			if
				type(e) == "table"
				and type(e.id) == "string"
				and #e.id <= 64
				and #p.trades.log < StationProgress.TRADE_LOG
			then
				local function names(list: any): { string }
					local out = {}
					for _, n in if type(list) == "table" then list else {} do
						if type(n) == "string" and #out < 8 then
							table.insert(out, string.sub(n, 1, 40))
						end
					end
					return out
				end
				table.insert(p.trades.log, {
					id = e.id,
					with = if type(e.with) == "string" then string.sub(e.with, 1, 40) else "?",
					gave = names(e.gave),
					got = names(e.got),
					at = int(e.at, 0, MAX_TIME, 0),
				})
			end
		end
	end
	return p
end

-- Stars (decision 0097): the best won on wave `wave`, all of them, and the star chests due.
function StationProgress.starsOf(p: Profile, wave: number): number
	return tonumber(string.sub(p.stars, wave, wave)) or 0
end
function StationProgress.starTotal(p: Profile): number
	local sum = 0
	for c in string.gmatch(p.stars, "%d") do
		sum += tonumber(c) :: number
	end
	return sum
end
function StationProgress.chestsDue(p: Profile): number
	return math.max(0, StationProgress.starTotal(p) // StationProgress.CHEST_STARS - p.chests)
end

-- Record `n` stars won on wave `wave`, keeping the best.
function StationProgress.setStars(p: Profile, wave: number, n: number): Profile
	if wave < 1 or wave > StationProgress.MAX_STAR_WAVES or wave ~= math.floor(wave) then
		return p
	end
	n = math.clamp(math.floor(n), 0, 3)
	if n > StationProgress.starsOf(p, wave) then
		local padded = p.stars .. string.rep("0", math.max(0, wave - #p.stars))
		p.stars = string.sub(padded, 1, wave - 1) .. tostring(n) .. string.sub(padded, wave + 1)
	end
	return p
end

-- Seconds of `windows` that fall between `from` and `to`.
local function overlap(windows: { Window }, from: number, to: number): number
	local sum = 0
	for _, w in windows do
		sum += math.max(0, math.min(to, w.to) - math.max(from, w.from))
	end
	return sum
end

-- Add `seconds` of the boost `kind` ("hatch" or "train") from `now`: it runs on from the end of one still
-- running, so two make twice as long, never twice as strong.
function StationProgress.addBoost(p: Profile, kind: string, seconds: number, now: number): Profile
	local list = (p.boosts :: any)[kind] :: { Window }
	local last = list[#list]
	if last and last.to >= now then
		list[#list] = { from = last.from, to = last.to + seconds }
	else
		table.insert(list, { from = now, to = now + seconds })
	end
	while #list > StationProgress.MAX_WINDOWS do
		table.remove(list, 1)
	end
	return p
end

-- Seconds of boost `kind` left at `now` (0 when none runs).
function StationProgress.boostLeft(p: Profile, kind: string, now: number): number
	local left = 0
	for _, w in (p.boosts :: any)[kind] :: { Window } do
		left = math.max(left, w.to - math.max(now, w.from))
	end
	return math.max(0, left)
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
	elseif egg.level and StationProgress.playerLevel(p) < egg.level then -- by player level (SHANNON, 2026-11-24)
		return false, "locked"
	elseif #p.eggs >= StationProgress.value(p, "hatchery") + StationProgress.value(p, "cellar") then
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
		rainbow = hatched.rainbow,
		coat = hatched.coat,
	}
	p.eggs = table.clone(p.eggs)
	table.insert(p.eggs, { egg = eggId, animal = animal })
	return p, true, nil
end

-- Start hatching the `k`th egg at `now`: it must be in the storage, and one of the Hatchery's nests
-- must be free.
function StationProgress.start(p: Profile, k: number, now: number): (Profile, boolean, string?)
	local e = p.eggs[k]
	if e == nil then
		return p, false, "egg"
	elseif e.since then
		return p, false, "hatching"
	elseif StationProgress.hatching(p) >= StationProgress.value(p, "hatchery") then
		return p, false, "nests_full"
	end
	p.eggs = table.clone(p.eggs)
	p.eggs[k] = { egg = e.egg, since = now, animal = e.animal, quick = e.quick }
	return p, true, nil
end

-- How many seconds `egg` takes to hatch for `p`: its own time, shortened by the Brooder. Whole seconds,
-- rounded up. The Brooder's level now counts for the whole wait, also for an egg already hatching.
function StationProgress.hatchSeconds(p: Profile, egg: StationConfig.Egg): number
	return math.ceil(egg.hatch * 100 / StationProgress.value(p, "brooder"))
end

-- When `p`'s egg `e` can be opened (os.time; nil while it waits in storage): its hatch time from when it
-- started, but twice as fast during a hatching boost (decision 0094).
function StationProgress.dueAt(p: Profile, e: { egg: string, since: number? }): number?
	local egg = StationConfig.egg(e.egg)
	if egg == nil or e.since == nil then
		return nil
	end
	if (e :: any).quick then
		return (e.since :: number) + StationProgress.QUICK_SECONDS
	end
	local t, left = e.since :: number, StationProgress.hatchSeconds(p, egg)
	local windows = table.clone(p.boosts.hatch)
	table.sort(windows, function(a, b)
		return a.from < b.from
	end)
	for _, w in windows do
		if w.to > t then
			if w.from > t then -- plain time before the boost
				if left <= w.from - t then
					return t + left
				end
				left -= w.from - t
				t = w.from
			end
			local fast = w.to - t -- twice as fast in here
			if left <= 2 * fast then
				return t + math.ceil(left / 2)
			end
			left -= 2 * fast
			t = w.to
		end
	end
	return t + left
end

-- True when `p`'s egg `e` is hatching and has waited its hatch time: it can be opened.
function StationProgress.due(p: Profile, e: { egg: string, since: number? }, now: number): boolean
	local at = StationProgress.dueAt(p, e)
	return at ~= nil and now >= at
end

-- Open the `k`th egg: it must have finished hatching and the Barn must have room. Its animal
-- joins the collection with a new id, and the team while that has room (a Titan takes the Titan
-- slot if it is empty). Returns the animal.
function StationProgress.crack(p: Profile, k: number, now: number): (Profile, boolean, string?, Animal?)
	local e = p.eggs[k]
	if e == nil then
		return p, false, "egg", nil
	elseif not StationProgress.due(p, e, now) then
		return p, false, "not_ready", nil
	elseif #p.animals >= math.min(StationProgress.value(p, "barn"), StationProgress.MAX_ANIMALS) then
		return p, false, "full", nil
	end
	local animal: Animal = {
		id = p.nextId,
		s = e.animal.s,
		v = e.animal.v,
		stats = e.animal.stats,
		trained = e.animal.trained,
		rainbow = e.animal.rainbow,
		coat = e.animal.coat,
	}
	p.nextId += 1
	table.insert(p.animals, animal)
	StationProgress.meet(p, animal.s, animal.v)
	if StationProgress.isTitan(animal) then
		p.titan = p.titan or animal.id
	elseif #p.team < StationProgress.TEAM_SIZE then
		table.insert(p.team, animal.id)
	end
	p.eggs = table.clone(p.eggs)
	table.remove(p.eggs, k)
	return p, true, nil, animal
end

-- Admin menu (decision 0049): add one animal of species `s` (and variant `v`) with every stat at
-- `level`, in a rainbow coat when `rainbow` is true, joining the team like a hatched one. It skips the
-- Barn's limit, not the save's.
function StationProgress.give(
	p: Profile,
	s: string,
	v: string?,
	level: number,
	rainbow: boolean?
): (Profile, boolean, string?, Animal?)
	local stats = StationRules.versionStats(s, v)
	if stats == nil or level ~= math.floor(level) or level < 1 or level > StationConfig.MAX_LEVEL then
		return p, false, "animal", nil
	elseif #p.animals >= StationProgress.MAX_ANIMALS then
		return p, false, "full", nil
	end
	local trained = {} :: any
	for _, stat in StationConfig.STATS do
		trained[stat] = level
	end
	local animal: Animal = {
		id = p.nextId,
		s = s,
		v = v,
		stats = stats,
		trained = trained :: Stats,
		rainbow = if rainbow then true else nil,
		coat = if rainbow then "rainbow" else nil,
	}
	p.nextId += 1
	table.insert(p.animals, animal)
	StationProgress.meet(p, animal.s, animal.v)
	if StationProgress.isTitan(animal) then
		p.titan = p.titan or animal.id
	elseif #p.team < StationProgress.TEAM_SIZE then
		table.insert(p.team, animal.id)
	end
	return p, true, nil, animal
end

-- Robux and the beta (decision 0117): grant one animal of species `s` and variant `v` for receipt `key`, once
-- (a receipt already granted changes nothing and says "granted"), in coat `coat`, every stat at BASE_MAX, joining
-- the team like a hatched one. Refused when the save is full ("full"): Roblox sends the receipt again later.
function StationProgress.grant(
	p: Profile,
	s: string,
	v: string?,
	key: string,
	coat: string?
): (Profile, boolean, string?, Animal?)
	if table.find(p.receipts, key) then
		return p, true, "granted", nil
	end
	local stats = StationRules.versionStats(s, v)
	if stats == nil or (coat ~= nil and StationConfig.coat(coat) == nil) then
		return p, false, "animal", nil
	elseif #p.animals >= StationProgress.MAX_ANIMALS then
		return p, false, "full", nil
	end
	local trained = {} :: any
	for _, stat in StationConfig.STATS do
		trained[stat] = StationConfig.BASE_MAX
	end
	local animal: Animal = {
		id = p.nextId,
		s = s,
		v = v,
		stats = stats,
		trained = trained :: Stats,
		rainbow = if coat == "rainbow" then true else nil,
		coat = coat,
	}
	p.nextId += 1
	table.insert(p.animals, animal)
	StationProgress.meet(p, animal.s, animal.v)
	if StationProgress.isTitan(animal) then
		p.titan = p.titan or animal.id
	elseif #p.team < StationProgress.TEAM_SIZE then
		table.insert(p.team, animal.id)
	end
	p.receipts = table.clone(p.receipts)
	table.insert(p.receipts, key)
	while #p.receipts > StationProgress.MAX_RECEIPTS do
		table.remove(p.receipts, 1)
	end
	return p, true, nil, animal
end

-- The beta reward (decision 0117): StationConfig.BETA_GIFT, once per save, in coat `coat`.
function StationProgress.betaGift(p: Profile, coat: string?): (Profile, boolean, string?, Animal?)
	local gift = StationConfig.BETA_GIFT
	if gift == nil or p.beta then
		return p, false, "done", nil
	end
	local q, ok, why, animal = StationProgress.grant(p, gift.s, gift.v, "beta", coat)
	if ok then
		q.beta = true
	end
	return q, ok, why, animal
end

-- The profile as the client may see it: the held eggs without the animals inside them.
function StationProgress.public(p: Profile): any
	local copy = table.clone(p) :: any
	copy.eggs = {}
	for k, e in p.eggs do
		copy.eggs[k] = { egg = e.egg, since = e.since, quick = e.quick }
	end
	copy.rewards = table.clone(p.rewards)
	copy.rewards.pending = {}
	for k, e in p.rewards.pending do
		copy.rewards.pending[k] = { egg = e.egg }
	end
	return copy
end

-- Training seconds earned in `seconds` of real time: the Training Grounds make it go faster.
function StationProgress.trainingSeconds(p: Profile, seconds: number): number
	return math.max(0, seconds) * StationProgress.value(p, "grounds") / 100
end

-- Training seconds earned from `from` to `to`: as trainingSeconds, and twice as fast during a training
-- boost (decision 0094).
function StationProgress.trainedBetween(p: Profile, from: number, to: number): number
	if to <= from then
		return 0
	end
	return StationProgress.trainingSeconds(p, (to - from) + overlap(p.boosts.train, from, to))
end

-- The next wave's first-clear pay: what the Windmill's share and the ranch animals' earnings are of (decision 0124).
local function nextPay(p: Profile): number
	return LevelRules.reward(math.min(p.best + 1, LevelRules.LAST), 0)
end

-- The Windmill's coins an hour (decisions 0073, 0124): its level's coins, or its share of the next wave's pay
-- when that is more, so it stays worth collecting late in the game. 0 without a Windmill.
function StationProgress.millRate(p: Profile): number
	local level = p.upgrades.windmill or 0
	local flat = StationProgress.value(p, "windmill")
	local u = StationConfig.upgrade("windmill")
	local share = if level > 0 and u and u.share then u.share[level] or 0 else 0
	return math.max(flat, nextPay(p) * share // 100)
end

-- How many coins the Windmill holds for `p` at `now`: its coins an hour for the time since it was last
-- emptied, also while the player was away, up to MILL_HOURS of them. Whole coins.
function StationProgress.held(p: Profile, now: number): number
	local rate = StationProgress.millRate(p)
	if rate <= 0 or p.mill == nil then
		return 0
	end
	return math.floor(rate * math.clamp(now - p.mill, 0, StationProgress.MILL_HOURS * 3600) / 3600)
end

-- Collect what the Windmill holds: the player does this at the mill (decision 0073). The time a part
-- of a coin took stays on its clock, unless it was full. Returns the coins collected.
function StationProgress.collect(p: Profile, now: number): (Profile, boolean, string?, number)
	local rate = StationProgress.millRate(p)
	if rate <= 0 then
		return p, false, "no_mill", 0
	end
	local coins = StationProgress.held(p, now)
	if coins <= 0 then
		return p, false, "mill_empty", 0
	end
	local since = p.mill :: number
	local full = now - since >= StationProgress.MILL_HOURS * 3600
	p.mill = if full then now else math.min(now, since + math.ceil(coins * 3600 / rate))
	p.coins = math.min(p.coins + coins, StationProgress.MAX_COINS)
	return p, true, nil, coins
end

-- The ranch animals' coins an hour (decision 0124): each animal not on the team, not the Titan in its slot and
-- not training earns its rarity's HERD_PERMILLE of the next wave's pay, or its HERD_FLOOR when that is more.
StationProgress.HERD_HOURS = 8
function StationProgress.herdRate(p: Profile): number
	local pay, total = nextPay(p), 0
	for _, a in p.animals do
		if not (table.find(p.team, a.id) or p.titan == a.id or a.at) then
			local r = StationRules.rarity(a :: any)
			local floor = StationConfig.HERD_FLOOR[r] or 1
			total += math.max(floor, math.floor(pay * (StationConfig.HERD_PERMILLE[r] or 0.5) / 1000))
		end
	end
	return total
end

-- What the ranch animals hold for `p` at `now`, up to HERD_HOURS of earning. Whole coins.
-- shortcut: the whole time is paid at the rate when collected, so moving animals off the team just before
-- collecting pays a little more; keep a per-change clock if that is ever farmed.
function StationProgress.herdHeld(p: Profile, now: number): number
	local seconds = math.clamp(now - p.herd, 0, StationProgress.HERD_HOURS * 3600)
	return math.floor(StationProgress.herdRate(p) * seconds / 3600)
end

-- Collect the ranch animals' coins at the Ranch House (decision 0124). Returns the coins collected.
function StationProgress.collectHerd(p: Profile, now: number): (Profile, boolean, string?, number)
	local coins = StationProgress.herdHeld(p, now)
	if coins <= 0 then
		return p, false, "herd_empty", 0
	end
	p.herd = now
	p.coins = math.min(p.coins + coins, StationProgress.MAX_COINS)
	return p, true, nil, coins
end

-- Add training time to every training animal up to `now`. Every stat level gained gives the
-- player XP. An animal whose stat reaches MAX_LEVEL is done: it stops training and frees its place.
function StationProgress.settle(p: Profile, now: number): Profile
	for i, a in p.animals do
		if a.at and a.since then
			local st = StationConfig.station(a.at) :: StationConfig.Station
			local t = StationRules.train(a :: any, a.at, StationProgress.trainedBetween(p, a.since, now))
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
-- Release and fusion (SHANNON, 2026-11-24, decision 0112) ---------------------------------------------------

-- Coins for releasing an animal, by rarity; twice that with a coat.
StationProgress.RELEASE_PAY = {
	common = 10,
	uncommon = 25,
	rare = 60,
	epic = 150,
	legendary = 400,
	mythic = 1000,
	divine = 2500,
	celestial = 6000,
	secret = 15000,
	eternal = 40000, -- decision 0117
} :: { [string]: number }
StationProgress.FUSE = 4 -- this many of one animal, of one coat tier, fuse into one of the next tier

-- The coat tiers, commonest first: the coats grouped by how rare they are (StationConfig.COATS' ppm).
local function coatTiers(): { { string } }
	local byPpm: { [number]: { string } } = {}
	local order: { number } = {}
	for _, c in StationConfig.COATS do
		if byPpm[c.ppm] == nil then
			byPpm[c.ppm] = {}
			table.insert(order, c.ppm)
		end
		table.insert(byPpm[c.ppm], c.id)
	end
	table.sort(order, function(x, y)
		return x > y
	end)
	local out = {}
	for _, ppm in order do
		table.insert(out, byPpm[ppm])
	end
	return out
end
StationProgress.COAT_TIERS = coatTiers()

-- An animal's coat tier: 0 with no coat, 1 for the commonest coats, up to #COAT_TIERS (Prismatic).
function StationProgress.coatTier(a: Animal): number
	local coat = StationRules.coatOf(a :: any)
	if coat == nil then
		return 0
	end
	for k, ids in StationProgress.COAT_TIERS do
		if table.find(ids, coat.id) then
			return k
		end
	end
	return 0
end

-- Why animal `a` of `p` cannot be released or fused, or nil.
local function busy(p: Profile, a: Animal): string?
	if table.find(p.team, a.id) or p.titan == a.id then
		return "in_team"
	elseif a.at then
		return "training"
	elseif a.locked then
		return "animal_locked"
	end
	return nil
end

-- Release animal `id` for RELEASE_PAY coins. Never one in the team, training or locked, nor the last one.
function StationProgress.release(p: Profile, id: number): (Profile, boolean, string?)
	local i, a = StationProgress.find(p, id)
	if i == nil or a == nil then
		return p, false, "animal"
	end
	local why = busy(p, a)
	if why then
		return p, false, why
	elseif #p.animals <= 1 then
		return p, false, "last_animal"
	end
	local pay = (StationProgress.RELEASE_PAY[StationRules.rarity(a :: any)] or 0) * (if a.coat then 2 else 1)
	table.remove(p.animals, i)
	p.coins = math.min(p.coins + pay, StationProgress.MAX_COINS)
	return p, true, nil
end

-- The ones among `p`'s idle animals that could fuse with `a` (the same animal, the same coat tier), `a` first.
function StationProgress.fusable(p: Profile, a: Animal): { number }
	local out = { a.id }
	local tier = StationProgress.coatTier(a)
	if tier >= #StationProgress.COAT_TIERS then
		return out
	end
	for _, x in p.animals do
		if x.id ~= a.id and x.s == a.s and x.v == a.v and StationProgress.coatTier(x) == tier and busy(p, x) == nil then
			table.insert(out, x.id)
		end
	end
	return out
end

-- Fuse FUSE animals `ids` (the same animal, the same coat tier, all idle) into the first of them, wearing `coat`
-- (one of the next tier's: the server picks it) with each stat level the average of the four, rounded down.
function StationProgress.fuse(p: Profile, ids: { number }, coat: string): (Profile, boolean, string?)
	if #ids ~= StationProgress.FUSE then
		return p, false, "fuse_count"
	end
	local them: { Animal } = {}
	for k, id in ids do
		local _, a = StationProgress.find(p, id)
		if a == nil or table.find(ids, id) ~= k then
			return p, false, "animal"
		end
		local why = busy(p, a)
		if why then
			return p, false, why
		end
		table.insert(them, a)
	end
	local first = them[1]
	local tier = StationProgress.coatTier(first)
	for _, a in them do
		if a.s ~= first.s or a.v ~= first.v or StationProgress.coatTier(a) ~= tier then
			return p, false, "fuse_mismatch"
		end
	end
	local next = StationProgress.COAT_TIERS[tier + 1]
	if next == nil then
		return p, false, "fuse_top"
	elseif not table.find(next, coat) then
		return p, false, "coat"
	end
	local trained = {}
	for _, stat in StationConfig.STATS do
		local sum = 0
		for _, a in them do
			sum += StationRules.level(a :: any, stat)
		end
		trained[stat] = sum // #them
	end
	local copy = table.clone(first)
	copy.coat, copy.rainbow, copy.trained = coat, if coat == "rainbow" then true else nil, trained :: any
	local kept = {}
	for _, a in p.animals do
		if a.id == first.id then
			table.insert(kept, copy)
		elseif not table.find(ids, a.id) then
			table.insert(kept, a)
		end
	end
	p.animals = kept
	return p, true, nil
end

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
-- A station trains one animal at a time (decision 0066).
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
	for _, x in p.animals do
		if x.id ~= id and x.at == stationId then
			return p, false, "station_busy"
		end
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
	local t = table.find(p.team, id)
	if t then
		table.remove(p.team, t)
		copy.slot = t
	end
	if p.titan == id then
		p.titan = nil
		copy.slot = 0
	end
	p.animals[i] = copy
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
	local slot = copy.slot
	copy.at, copy.since, copy.slot = nil, nil, nil
	p.animals[i] = copy
	-- back where it left from (SHANNON, 2026-11-24), if that place is free
	if slot == 0 and p.titan == nil then
		p.titan = id
	elseif slot and slot > 0 and #p.team < StationProgress.TEAM_SIZE and not table.find(p.team, id) then
		table.insert(p.team, math.min(slot, #p.team + 1), id)
	end
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
	if id == "windmill" then
		p = (StationProgress.collect(p, now)) -- what it holds is paid first, at the rate it was earned at
	end
	local level = (p.upgrades[id] or 0) + 1
	local cost = (StationConfig.upgrade(id) :: StationConfig.Upgrade).levels[level]
	p.coins -= cost.coins
	p.samples -= cost.samples
	p.upgrades = table.clone(p.upgrades)
	p.upgrades[id] = level
	if id == "windmill" then
		p.mill = now -- it starts to fill from now, at its new rate
	end
	return p, true, nil
end

-- Whether `p` can send its team at wave `level` now: any wave up to one past the best cleared and
-- no further than the last (LevelRules.LAST, decision 0107), with at least one animal on the team.
-- The code says why not.
function StationProgress.canFight(p: Profile, level: number): (boolean, string?)
	if level < 1 or level > math.min(p.best + 1, LevelRules.LAST) or level ~= math.floor(level) then
		return false, "wave"
	elseif #StationProgress.fighters(p) == 0 then
		return false, "no_team"
	end
	return true, nil
end

-- What clearing wave `level` pays `p` now: coins (the Trophy Lodge adds to them), player XP and samples.
function StationProgress.payout(p: Profile, level: number): (number, number, number)
	local coins = LevelRules.reward(level, p.best) * StationProgress.value(p, "lodge") // 100
	local pct, n = 100, 0 -- the Gilded coat (decision 0110): more XP for each on the team, up to COAT_XP_MAX
	for _, a in StationProgress.fighters(p) do
		local coat = StationRules.coatOf(a :: any)
		if coat and coat.xp and n < StationConfig.COAT_XP_MAX then
			pct, n = pct + coat.xp, n + 1
		end
	end
	return coins, LevelRules.xp(level, p.best) * pct // 100, LevelRules.samples(level, p.best)
end

-- Pay for clearing wave `level` (the server has decided the fight was won) and record it as the
-- best if it is. `carried` (a shared fight, decision 0108): another player opened the wave, so it may be
-- further on than this save could open alone; it is still a wave that exists, won with a team.
function StationProgress.clear(p: Profile, level: number, carried: boolean?): (Profile, boolean, string?)
	local ok, code = StationProgress.canFight(p, if carried then math.min(level, p.best + 1) else level)
	if carried and (level > LevelRules.LAST or level ~= math.floor(level)) then
		ok, code = false, "wave"
	end
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

-- Add `coins` and `samples` the server has decided to pay (a wave run's pot, decision 0098).
function StationProgress.earn(p: Profile, coins: number, samples: number): Profile
	p.coins = math.min(p.coins + math.max(0, math.floor(coins)), StationProgress.MAX_COINS)
	p.samples = math.min(p.samples + math.max(0, math.floor(samples)), StationProgress.MAX_SAMPLES)
	return p
end

-- The animals that fight: the team in order, then the Titan, with the stats its Den gives it.
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
			local den = StationProgress.value(p, "den")
			if den > 100 then
				a = table.clone(a);
				(a :: any).boost = den
			end
			table.insert(out, a :: Animal)
		end
	end
	return out
end

-- Written on every save: training is settled so the stored levels are current.
function StationProgress.snapshot(p: Profile, now: number): Profile
	return StationProgress.settle(p, now)
end

return StationProgress
