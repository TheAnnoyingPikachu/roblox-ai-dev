--!strict
-- Neon Spire progression and the saved profile (GDD J and N, decision 0009): defaults, sanitise,
-- login and offline pay, earn and Hot Data ops, the session lock, the Request contract (check,
-- parse, apply) with XP and quest stats around the tower and plaza rules, the token bucket, the
-- IPO and the shared rewards (MetaRules with Spire's config, scaled by income). No Roblox APIs;
-- every input comes from the server.

local MetaRules = require("./MetaRules")
local PlazaRules = require("./PlazaRules")
local Rng = require("./Rng")
local SpireConfig = require("./SpireConfig")
local SpireEconomy = require("./SpireEconomy")
local TowerRules = require("./TowerRules")

local SpireProgress = {}

type Profile = SpireConfig.Profile
export type Bucket = { tokens: number, at: number }

SpireProgress.SCHEMA_VERSION = 1
SpireProgress.LOCK_STALE = 120 -- seconds: 2 x the 60 s autosave; every write refreshes `at`

local MAX_COINS = SpireConfig.MAX_COINS
local MAX_EARNED = SpireConfig.MAX_EARNED
local MAX_COUNT = MetaRules.MAX_COUNT
local MAX_TIME = 1e12
local SLOTS = SpireConfig.SLOTS

local function floor(x: number): number
	return math.floor(x + 1e-9)
end

local function isInt(n: any): boolean
	return type(n) == "number" and n == math.floor(n)
end

local function emptyFloor(dept: string): SpireConfig.Floor
	return { d = dept, m = { 0, 0, 0, 0 }, s = { 0, 0, 0, 0 } }
end

local function startFloors(): { SpireConfig.Floor }
	return { emptyFloor(SpireConfig.LOBBY), emptyFloor("data") }
end

-- Rewards stay worth claiming as the tower grows.
function SpireProgress.scaled(p: Profile, base: number, minutes: number): number
	return math.max(base, floor(SpireEconomy.income(p, "normal") * 60 * minutes))
end

local CONFIG: MetaRules.Config<Profile> = {
	cosmetics = SpireConfig.COSMETICS,
	slots = SpireConfig.SLOT_DEFAULTS,
	quests = SpireConfig.QUESTS,
	daily = SpireConfig.DAILY,
	dailyMinutes = SpireConfig.DAILY_MINUTES,
	weekly = SpireConfig.WEEKLY,
	maxCoins = MAX_COINS,
	scale = SpireProgress.scaled,
	sanitize = function(record: any): Profile
		return SpireProgress.sanitize(record)
	end,
}
SpireProgress.CONFIG = CONFIG

-- Profile ------------------------------------------------------------------------------------

local COMPANY_RANGES = {
	p = #SpireConfig.NAMES.prefixes,
	s = #SpireConfig.NAMES.suffixes,
	glyph = SpireConfig.GLYPHS,
	colour = #SpireConfig.COLOURS,
	trim = #SpireConfig.COLOURS,
}
local COMPANY_KEYS = { "p", "s", "glyph", "colour", "trim" }

function SpireProgress.company(seed: number): SpireConfig.Company
	local state = Rng.seed(seed, 4077)
	local out: any = {}
	for _, key in COMPANY_KEYS do
		out[key], state = Rng.int(state, 1, (COMPANY_RANGES :: any)[key])
	end
	return out
end

local function validCompany(c: any): boolean
	if type(c) ~= "table" then
		return false
	end
	for _, key in COMPANY_KEYS do
		local v = c[key]
		if not isInt(v) or v < 1 or v > (COMPANY_RANGES :: any)[key] then
			return false
		end
	end
	return true
end

function SpireProgress.defaults(now: number, seed: number?): Profile
	return {
		schemaVersion = SpireProgress.SCHEMA_VERSION,
		xp = 0,
		coins = SpireConfig.START.coins,
		lifetimeEarned = 0,
		runEarned = 0,
		lastSeen = now,
		floors = startFloors(),
		plaza = { nextUid = 1, items = {} },
		shares = 0,
		ipos = 0,
		hotCaught = 0,
		endorsements = 0,
		bestFloors = SpireConfig.START.floors,
		gate = "open",
		company = SpireProgress.company(seed or 0),
		skin = SpireConfig.SLOT_DEFAULTS.skin,
		crown = SpireConfig.SLOT_DEFAULTS.crown,
		lobby = SpireConfig.SLOT_DEFAULTS.lobby,
		tiles = SpireConfig.SLOT_DEFAULTS.tiles,
		trail = SpireConfig.SLOT_DEFAULTS.trail,
		owned = {},
		endorsed = { day = -1, ids = {} },
		daily = { streak = 0, last = -1 },
		week = { key = -1, days = 0, lastDay = -1, claimed = false },
		quests = { day = -1, progress = {}, claimed = {} },
	}
end

local function sanitizeFloor(record: any, n: number): SpireConfig.Floor
	local d = if type(record) == "table" and type(record.d) == "string" then record.d else ""
	if not TowerRules.deptAllowed(d, n) then
		return emptyFloor("data")
	end
	local f = emptyFloor(d)
	local m = if type(record.m) == "table" then record.m else {}
	local s = if type(record.s) == "table" then record.s else {}
	for slot = 1, SLOTS do
		local level = MetaRules.count(m[slot], 5)
		f.m[slot] = level
		f.s[slot] = if level > 0 then MetaRules.count(s[slot], TowerRules.spentMax(d, level)) else 0
	end
	return f
end

-- Removes the highest-draw modules (highest floor, then highest slot first) until draw fits;
-- returns the credits to refund (their full `spent`).
local function fitPower(p: Profile): number
	local refund = 0
	while TowerRules.draw(p) > TowerRules.supply(p) do
		local best, bestDraw, bestSlot = nil :: SpireConfig.Floor?, -1, 0
		for n = #p.floors, 2, -1 do
			local f = p.floors[n]
			local draw = (SpireConfig.dept(f.d) :: SpireConfig.Dept).draw
			for slot = SLOTS, 1, -1 do
				if f.m[slot] > 0 and draw > bestDraw then
					best, bestDraw, bestSlot = f, draw, slot
				end
			end
		end
		if best == nil or bestDraw <= 0 then
			break
		end
		refund += best.s[bestSlot]
		best.m[bestSlot] = 0
		best.s[bestSlot] = 0
	end
	return refund
end

local function sanitizePlaza(p: Profile, record: any)
	if type(record) ~= "table" then
		return
	end
	local list = if type(record.items) == "table" then record.items else {}
	local nextUid = math.max(1, MetaRules.count(record.nextUid, MAX_COUNT))
	local seen: { [number]: boolean } = {}
	for _, it in ipairs(list) do
		if #p.plaza.items >= SpireConfig.PLAZA.maxItems then
			break
		end
		local item = type(it) == "table" and type(it.id) == "string" and SpireConfig.item(it.id)
		local u = if item then MetaRules.count(it.u, MAX_COUNT) else 0
		if item and u >= 1 and not seen[u] then
			local per, _, decor = PlazaRules.counts(p)
			local fits = PlazaRules.check(p, item.id, it.x, it.y, it.r) == nil
			local underMax = if item.max then (per[item.id] or 0) < item.max else decor < SpireConfig.PLAZA.maxDecor
			if fits and underMax then
				seen[u] = true
				table.insert(
					p.plaza.items,
					{ u = u, id = item.id, x = it.x, y = it.y, r = it.r, paid = MetaRules.count(it.paid, item.cost) }
				)
				nextUid = math.max(nextUid, u + 1)
			end
		end
	end
	p.plaza.nextUid = nextUid
end

-- Decision 0009. Game fields first, then MetaRules.sanitizeMeta, then Shares-locked slots.
function SpireProgress.sanitize(record: any, now: number?, seed: number?): Profile
	local p = SpireProgress.defaults(now or 0, seed)
	if type(record) ~= "table" then
		return p
	end
	p.lifetimeEarned = MetaRules.count(record.lifetimeEarned, MAX_EARNED)
	p.runEarned = MetaRules.count(record.runEarned, MAX_EARNED)
	p.lastSeen = MetaRules.count(record.lastSeen, MAX_TIME)
	if now and p.lastSeen > now then
		p.lastSeen = now
	end

	local floors = if type(record.floors) == "table" then record.floors else {}
	local count = 1
	while count < SpireConfig.MAX_FLOORS and floors[count + 1] ~= nil do
		count += 1
	end
	for n = 2, math.max(count, SpireConfig.START.floors) do
		p.floors[n] = sanitizeFloor(floors[n], n)
	end
	local refund = fitPower(p)

	sanitizePlaza(p, record.plaza)
	p.shares = MetaRules.count(record.shares, SpireConfig.SHARES.max)
	p.ipos = MetaRules.count(record.ipos, MAX_COUNT)
	p.hotCaught = MetaRules.count(record.hotCaught, MAX_COUNT)
	p.endorsements = MetaRules.count(record.endorsements, MAX_COUNT)
	p.bestFloors = math.max(#p.floors, MetaRules.count(record.bestFloors, SpireConfig.MAX_FLOORS))
	if table.find(SpireConfig.GATES, record.gate) then
		p.gate = record.gate
	end
	if validCompany(record.company) then
		local c = record.company
		p.company = { p = c.p, s = c.s, glyph = c.glyph, colour = c.colour, trim = c.trim }
	end
	if type(record.endorsed) == "table" then
		p.endorsed.day = MetaRules.dayNumber(record.endorsed.day)
		if type(record.endorsed.ids) == "table" then
			for _, id in ipairs(record.endorsed.ids) do
				if
					#p.endorsed.ids < SpireConfig.ENDORSE.perDay
					and isInt(id)
					and math.abs(id) < 2 ^ 53
					and not table.find(p.endorsed.ids, id)
				then
					table.insert(p.endorsed.ids, id)
				end
			end
		end
	end

	MetaRules.sanitizeMeta(CONFIG, record, p)
	p.coins = math.min(MAX_COINS, p.coins + refund)
	for slot, default in SpireConfig.SLOT_DEFAULTS do
		local id = (p :: any)[slot]
		if p.shares < (SpireConfig.SHARE_UNLOCKS[id] or 0) then
			(p :: any)[slot] = default
		end
	end
	return p
end

function SpireProgress.publicState(p: Profile): SpireConfig.TowerState
	local floors: { SpireConfig.PublicFloor } = {}
	for _, f in p.floors do
		table.insert(floors, { d = f.d, m = table.clone(f.m) })
	end
	local items: { SpireConfig.PublicItem } = {}
	for _, it in p.plaza.items do
		table.insert(items, { u = it.u, id = it.id, x = it.x, y = it.y, r = it.r })
	end
	local c = p.company
	return {
		floors = floors,
		items = items,
		company = { p = c.p, s = c.s, glyph = c.glyph, colour = c.colour, trim = c.trim },
		skin = p.skin,
		crown = p.crown,
		lobby = p.lobby,
		tiles = p.tiles,
		trail = p.trail,
		gate = p.gate,
		hype = PlazaRules.hype(p),
		endorsements = p.endorsements,
		shares = p.shares,
		level = MetaRules.levelFor(p.xp),
	}
end

function SpireProgress.levelFor(xp: number): number
	return MetaRules.levelFor(xp)
end

function SpireProgress.questsFor(today: number): { MetaRules.Quest }
	return MetaRules.questsFor(SpireConfig.QUESTS, today)
end

function SpireProgress.isUnlocked(p: Profile, id: string): boolean
	return MetaRules.isUnlocked(CONFIG, p, id) and p.shares >= (SpireConfig.SHARE_UNLOCKS[id] or 0)
end

-- Session lock (as GardenProgress) -----------------------------------------------------------

local function lockOf(record: any): { session: string, at: number }?
	local lock = if type(record) == "table" then record.lock else nil
	if
		type(lock) == "table"
		and type(lock.session) == "string"
		and type(lock.at) == "number"
		and lock.at == lock.at
	then
		return lock
	end
	return nil
end

function SpireProgress.canClaim(record: any, session: string, now: number): boolean
	local lock = lockOf(record)
	return lock == nil or lock.session == session or math.abs(now - lock.at) >= SpireProgress.LOCK_STALE
end

function SpireProgress.holds(record: any, session: string): boolean
	local lock = lockOf(record)
	return lock ~= nil and lock.session == session
end

function SpireProgress.locked(p: Profile, session: string?, now: number): any
	local out: any = table.clone(p)
	out.lock = if session then { session = session, at = now } else nil
	return out
end

-- Server-only ops ------------------------------------------------------------------------------

local function addXp(p: Profile, xp: number)
	p.xp = math.min(MetaRules.MAX_XP, p.xp + xp)
end

function SpireProgress.earn(p: Profile, credits: number, seconds: number, today: number): Profile
	local out = TowerRules.copy(p)
	local c = math.max(0, floor(credits))
	out.coins = math.min(MAX_COINS, out.coins + c)
	out.lifetimeEarned = math.min(MAX_EARNED, out.lifetimeEarned + c)
	out.runEarned = math.min(MAX_EARNED, out.runEarned + c)
	if seconds >= 1 then
		out = MetaRules.addProgress(CONFIG, out, today, { earnSeconds = math.floor(seconds) })
	end
	return out
end

-- Pays offline income from the saved tower; returns it.
function SpireProgress.login(p: Profile, now: number): (Profile, number)
	local out = SpireProgress.sanitize(p, now)
	local today = MetaRules.dayOf(now)
	local offline = SpireEconomy.offline(out, now)
	out = SpireProgress.earn(out, offline, 0, today)
	out.lastSeen = now
	return MetaRules.login(CONFIG, out, today), offline
end

function SpireProgress.snapshot(p: Profile, now: number): Profile
	local out = TowerRules.copy(p)
	out.lastSeen = now
	return out
end

function SpireProgress.grabHot(p: Profile, amount: number, today: number): Profile
	local out = SpireProgress.earn(p, amount, 0, today)
	out.hotCaught = math.min(MAX_COUNT, out.hotCaught + 1)
	addXp(out, SpireConfig.HOT.xp)
	return MetaRules.addProgress(CONFIG, out, today, { earnSeconds = SpireConfig.HOT.seconds, hot = 1 })
end

function SpireProgress.receiveEndorse(p: Profile): Profile
	local out = TowerRules.copy(p)
	out.endorsements = math.min(MAX_COUNT, out.endorsements + 1)
	return out
end

-- Owners are checked separately.
function SpireProgress.gateAllows(gate: string, isFriend: boolean): boolean
	return gate == "open" or (gate == "friends" and isFriend)
end

-- The Request contract ---------------------------------------------------------------------------

function SpireProgress.check(action: string, arg: string?): string?
	local spec = if type(action) == "string" then SpireConfig.ACTIONS[action] else nil
	if spec == nil then
		return "action"
	end
	if spec.pattern == nil then
		return if arg == nil then nil else "arg"
	end
	if type(arg) ~= "string" or #arg > SpireConfig.MAX_ARG or string.match(arg, spec.pattern) == nil then
		return "arg"
	end
	return nil
end

function SpireProgress.parse(action: string, arg: string?): { any }?
	if SpireProgress.check(action, arg) then
		return nil
	end
	local pattern = SpireConfig.ACTIONS[action].pattern
	if pattern == nil then
		return {}
	end
	local out: { any } = { string.match(arg :: string, pattern) }
	for i, v in out do
		if string.match(v, "^%d+$") then
			out[i] = tonumber(v)
		end
	end
	return out
end

function SpireProgress.take(b: Bucket, clock: number): (Bucket, boolean)
	local size, rate = SpireConfig.BUCKET.size, SpireConfig.BUCKET.rate
	local tokens = math.min(size, b.tokens + rate * math.max(0, clock - b.at))
	if tokens >= 1 then
		return { tokens = tokens - 1, at = clock }, true
	end
	return { tokens = tokens, at = clock }, false
end

function SpireProgress.ipo(p: Profile, _now: number): (Profile, boolean, string?)
	if not SpireConfig.FEATURES.ipo then
		return p, false, "locked"
	end
	local gained = SpireEconomy.ipoShares(p)
	if #p.floors < SpireConfig.SHARES.minFloors or gained < 1 then
		return p, false, "ipo"
	end
	local out = TowerRules.copy(p)
	out.shares = math.min(SpireConfig.SHARES.max, out.shares + gained)
	out.ipos = math.min(MAX_COUNT, out.ipos + 1)
	out.coins = SpireConfig.START.coins
	out.floors = startFloors()
	out.runEarned = 0
	return out, true, nil
end

local function stats(p: Profile, today: number, deltas: { [string]: number }): Profile
	return MetaRules.addProgress(CONFIG, p, today, deltas)
end

local function endorse(p: Profile, target: number, today: number): (Profile, boolean, string?)
	local ids = if p.endorsed.day == today then p.endorsed.ids else {}
	if table.find(ids, target) then
		return p, false, "done"
	elseif #ids >= SpireConfig.ENDORSE.perDay then
		return p, false, "max"
	end
	local out = TowerRules.copy(p)
	out.endorsed = { day = today, ids = table.clone(ids) }
	table.insert(out.endorsed.ids, target)
	if #ids < SpireConfig.XP.endorseCap then
		addXp(out, SpireConfig.XP.endorse)
	end
	return stats(out, today, { endorse = 1 }), true, nil
end

local function setCompany(p: Profile, a: { any }): (Profile, boolean, string?)
	local c: any = {}
	for i, key in COMPANY_KEYS do
		c[key] = a[i]
	end
	if not validCompany(c) then
		return p, false, "unknown"
	end
	local cur = p.company
	if cur.p == c.p and cur.s == c.s and cur.glyph == c.glyph and cur.colour == c.colour and cur.trim == c.trim then
		return p, false, "same"
	end
	local out = TowerRules.copy(p)
	out.company = c
	return out, true, nil
end

local function buyCosmetic(p: Profile, id: string): (Profile, boolean, string?)
	local c = MetaRules.cosmetic(CONFIG, id)
	if c == nil then
		return p, false, "unknown"
	elseif p.owned[id] then
		return p, false, "owned"
	elseif c.price == nil or p.shares < (SpireConfig.SHARE_UNLOCKS[id] or 0) then
		return p, false, "locked"
	elseif p.coins < c.price then
		return p, false, "credits"
	end
	local out = MetaRules.buy(CONFIG, p, id)
	return out, true, nil
end

local function equipCosmetic(p: Profile, id: string): (Profile, boolean, string?)
	local c = MetaRules.cosmetic(CONFIG, id)
	if c == nil then
		return p, false, "unknown"
	elseif not SpireProgress.isUnlocked(p, id) then
		return p, false, "locked"
	elseif (p :: any)[c.slot] == id then
		return p, false, "same"
	end
	local out = MetaRules.equip(CONFIG, p, id)
	return out, true, nil
end

local function claim(out: Profile, ok: boolean, p: Profile): (Profile, boolean, string?)
	if not ok then
		return p, false, "claimed"
	end
	return out, true, nil
end

-- Every ACTIONS entry with profile = true; the server router and client previews call this.
function SpireProgress.apply(
	p: Profile,
	action: string,
	arg: string?,
	now: number,
	event: string
): (Profile, boolean, string?)
	local spec = if type(action) == "string" then SpireConfig.ACTIONS[action] else nil
	if spec == nil or not spec.profile then
		return p, false, "action"
	end
	local a = SpireProgress.parse(action, arg)
	if a == nil then
		return p, false, "arg"
	end
	local today = MetaRules.dayOf(now)
	local out, ok, code

	if action == "buyFloor" then
		out, ok, code = TowerRules.buyFloor(p, a[1])
		if ok then
			addXp(out, SpireConfig.XP.floor * (SpireConfig.dept(a[1]) :: SpireConfig.Dept).tier)
			out.bestFloors = math.max(out.bestFloors, #out.floors)
			out = stats(out, today, { floors = 1 })
		end
	elseif action == "refitFloor" then
		out, ok, code = TowerRules.refitFloor(p, a[1], a[2])
	elseif action == "buyModule" then
		out, ok, code = TowerRules.buyModule(p, a[1], a[2], event)
		if ok then
			addXp(out, SpireConfig.XP.module)
			out = stats(out, today, { modules = 1 })
		end
	elseif action == "upgradeModule" then
		out, ok, code = TowerRules.upgradeModule(p, a[1], a[2], event)
		if ok then
			local level = out.floors[a[1]].m[a[2]]
			addXp(out, SpireConfig.XP.upgrade * level)
			out = stats(out, today, { upgrades = 1, maxed = if level == 5 then 1 else 0 })
		end
	elseif action == "sellModule" then
		out, ok, code = TowerRules.sellModule(p, a[1], a[2])
	elseif action == "placeItem" then
		out, ok, code = PlazaRules.placeItem(p, a[1], a[2], a[3], a[4])
		if ok then
			if (SpireConfig.item(a[1]) :: SpireConfig.PlazaItem).hype > 0 then
				addXp(out, SpireConfig.XP.plaza)
			end
			out = stats(out, today, { placed = 1 })
		end
	elseif action == "moveItem" then
		out, ok, code = PlazaRules.moveItem(p, a[1], a[2], a[3], a[4])
	elseif action == "sellItem" then
		out, ok, code = PlazaRules.sellItem(p, a[1])
	elseif action == "endorse" then
		out, ok, code = endorse(p, a[1], today)
	elseif action == "setGate" then
		if not table.find(SpireConfig.GATES, a[1]) then
			out, ok, code = p, false, "unknown"
		elseif p.gate == a[1] then
			out, ok, code = p, false, "same"
		else
			out, ok, code = TowerRules.copy(p), true, nil
			out.gate = a[1]
		end
	elseif action == "setCompany" then
		out, ok, code = setCompany(p, a)
	elseif action == "ipo" then
		out, ok, code = SpireProgress.ipo(p, now)
	elseif action == "claimDaily" then
		local claimed, accepted = MetaRules.claimDaily(CONFIG, p, today)
		out, ok, code = claim(claimed, accepted, p)
	elseif action == "claimWeekly" then
		local claimed, accepted = MetaRules.claimWeekly(CONFIG, p, today)
		out, ok, code = claim(claimed, accepted, p)
	elseif action == "claimQuest" then
		local claimed, accepted = MetaRules.claimQuest(CONFIG, p, today, a[1])
		out, ok, code = claim(claimed, accepted, p)
	elseif action == "buyCosmetic" then
		out, ok, code = buyCosmetic(p, a[1])
	elseif action == "equipCosmetic" then
		out, ok, code = equipCosmetic(p, a[1])
	else
		return p, false, "action"
	end
	return out, ok, code
end

return SpireProgress
