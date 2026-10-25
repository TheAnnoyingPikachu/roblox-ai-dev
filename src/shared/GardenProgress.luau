--!strict
-- Pure Egg Garden progression and the saved profile (GDD G, H5 and H7, decision 0008): defaults,
-- sanitise, login and offline payout, snapshots, banking, XP and quest stats around the plot and
-- hatch rules, likes, the gate, and the shared rewards (MetaRules with Garden's config, scaled by
-- income). No Roblox APIs; every input comes from the server.

local GardenConfig = require("./GardenConfig")
local GardenRules = require("./GardenRules")
local HatchRules = require("./HatchRules")
local MetaRules = require("./MetaRules")

local GardenProgress = {}

type Profile = GardenConfig.Profile

GardenProgress.SCHEMA_VERSION = 1

local MAX_COINS = GardenConfig.MAX_COINS
local MAX_COUNT = MetaRules.MAX_COUNT
local MAX_TIME = 1e12

local function floor(x: number): number
	return math.floor(x + 1e-9)
end

local function emptyBed(): GardenConfig.Bed
	return { egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 }
end

-- H5: rewards stay worth claiming as the garden grows.
function GardenProgress.scaled(p: Profile, base: number, minutes: number): number
	return math.max(base, floor(GardenRules.income(p) * 60 * minutes))
end

local CONFIG: MetaRules.Config<Profile> = {
	cosmetics = GardenConfig.COSMETICS,
	slots = { fence = "picket", can = "tin" },
	quests = GardenConfig.QUESTS,
	daily = GardenConfig.DAILY,
	dailyMinutes = GardenConfig.DAILY_MINUTES,
	weekly = GardenConfig.WEEKLY,
	maxCoins = MAX_COINS,
	scale = GardenProgress.scaled,
	sanitize = function(record: any): Profile
		return GardenProgress.sanitize(record)
	end,
}
GardenProgress.CONFIG = CONFIG

-- Profile ------------------------------------------------------------------------------------

function GardenProgress.defaults(now: number): Profile
	local pity: { [string]: number } = {}
	for _, egg in GardenConfig.EGGS do
		if egg.meter then
			pity[egg.id] = 0
		end
	end
	local starter = GardenConfig.egg("starter") :: GardenConfig.Egg
	return {
		schemaVersion = GardenProgress.SCHEMA_VERSION,
		xp = 0,
		coins = 100,
		lastSeen = now,
		unbanked = 0,
		nextId = 1,
		bedCount = GardenConfig.BEDS.start,
		penSlots = GardenConfig.PEN.start,
		beds = {
			{ egg = "starter", planted = now, ready = now + starter.grow, waters = 0, helps = 0, lastWater = 0 },
			emptyBed(),
			emptyBed(),
		},
		creatures = {},
		pity = pity,
		index = {},
		stock = { w = -1, bought = {} },
		hatches = 0,
		waters = 0,
		likes = 0,
		gate = "open",
		fence = "picket",
		can = "tin",
		owned = {},
		helped = { day = -1, count = 0 },
		liked = { day = -1, ids = {} },
		daily = { streak = 0, last = -1 },
		week = { key = -1, days = 0, lastDay = -1, claimed = false },
		quests = { day = -1, progress = {}, claimed = {} },
	}
end

local function sanitizeBed(record: any): GardenConfig.Bed
	local e = type(record) == "table" and type(record.egg) == "string" and GardenConfig.egg(record.egg)
	if not e then
		return emptyBed()
	end
	local planted = MetaRules.count(record.planted, MAX_TIME)
	return {
		egg = e.id,
		planted = planted,
		ready = math.clamp(MetaRules.count(record.ready, MAX_TIME), planted, planted + e.grow),
		waters = MetaRules.count(record.waters, GardenConfig.WATER.owner),
		helps = MetaRules.count(record.helps, GardenConfig.WATER.helpers),
		lastWater = MetaRules.count(record.lastWater, MAX_TIME),
	}
end

local function sanitizeCreatures(p: Profile, list: any)
	if type(list) ~= "table" then
		return
	end
	local seen: { [number]: boolean } = {}
	local taken: { [number]: boolean } = {}
	local stored: { number } = {}
	for _, c in ipairs(list) do
		local id = type(c) == "table" and MetaRules.count(c.id, MAX_COUNT) or 0
		local known = id >= 1
			and type(c.s) == "string"
			and GardenConfig.species(c.s)
			and type(c.m) == "string"
			and GardenConfig.mutation(c.m)
			and type(c.z) == "string"
			and GardenConfig.size(c.z)
		if known and not seen[id] then
			seen[id] = true
			local pad = MetaRules.count(c.placed, MAX_COUNT)
			if pad < 1 or pad > p.penSlots or taken[pad] then
				pad = 0
				table.insert(stored, id)
			end
			taken[pad] = true
			table.insert(p.creatures, { id = id, s = c.s, m = c.m, z = c.z, placed = pad, fav = c.fav == true })
		end
	end
	-- Storage past 60 drops the lowest (oldest) ids first.
	table.sort(stored)
	local drop: { [number]: boolean } = {}
	for i = 1, #stored - GardenConfig.STORAGE do
		drop[stored[i]] = true
	end
	for i = #p.creatures, 1, -1 do
		if drop[p.creatures[i].id] then
			table.remove(p.creatures, i)
		end
	end
	for _, c in p.creatures do
		p.nextId = math.max(p.nextId, c.id + 1)
	end
end

-- H7 and decision 0008. Game fields first, so MetaRules' slot checks can read `index`.
function GardenProgress.sanitize(record: any, now: number?): Profile
	local p = GardenProgress.defaults(now or 0)
	if type(record) ~= "table" then
		return p
	end
	p.lastSeen = MetaRules.count(record.lastSeen, MAX_TIME)
	if now and p.lastSeen > now then
		p.lastSeen = now
	end
	p.unbanked = MetaRules.count(record.unbanked, MAX_COINS)
	p.nextId = math.max(1, MetaRules.count(record.nextId, MAX_COUNT))
	p.bedCount = math.clamp(
		MetaRules.count(record.bedCount, GardenConfig.BEDS.max),
		GardenConfig.BEDS.start,
		GardenConfig.BEDS.max
	)
	p.penSlots =
		math.clamp(MetaRules.count(record.penSlots, GardenConfig.PEN.max), GardenConfig.PEN.start, GardenConfig.PEN.max)
	local beds = if type(record.beds) == "table" then record.beds else {}
	p.beds = {}
	for i = 1, p.bedCount do
		p.beds[i] = sanitizeBed(beds[i])
	end
	sanitizeCreatures(p, record.creatures)
	if type(record.pity) == "table" then
		for _, egg in GardenConfig.EGGS do
			if egg.meter then
				p.pity[egg.id] = MetaRules.count(record.pity[egg.id], egg.meter)
			end
		end
	end
	if type(record.index) == "table" then
		for _, key in ipairs(record.index) do
			local s, m = string.match(if type(key) == "string" then key else "", "^(%w+):(%w+)$")
			if s and m and GardenConfig.species(s) and GardenConfig.mutation(m) and not table.find(p.index, key) then
				table.insert(p.index, key)
			end
		end
	end
	if type(record.stock) == "table" then
		p.stock.w = MetaRules.dayNumber(record.stock.w)
		local bought = if type(record.stock.bought) == "table" then record.stock.bought else {}
		for _, egg in GardenConfig.EGGS do
			local n = if egg.stock then MetaRules.count(bought[egg.id], egg.stock.max) else 0
			if n > 0 then
				p.stock.bought[egg.id] = n
			end
		end
	end
	p.hatches = MetaRules.count(record.hatches, MAX_COUNT)
	p.waters = MetaRules.count(record.waters, MAX_COUNT)
	p.likes = MetaRules.count(record.likes, MAX_COUNT)
	if table.find(GardenConfig.GATES, record.gate) then
		p.gate = record.gate
	end
	if type(record.helped) == "table" then
		p.helped =
			{ day = MetaRules.dayNumber(record.helped.day), count = MetaRules.count(record.helped.count, MAX_COUNT) }
	end
	if type(record.liked) == "table" then
		p.liked.day = MetaRules.dayNumber(record.liked.day)
		if type(record.liked.ids) == "table" then
			for _, id in ipairs(record.liked.ids) do
				if #p.liked.ids < GardenConfig.LIKES.perDay and MetaRules.count(id, math.huge) == id then
					table.insert(p.liked.ids, id)
				end
			end
		end
	end
	return MetaRules.sanitizeMeta(CONFIG, record, p)
end

-- Login, snapshots and banking ---------------------------------------------------------------

-- Pays the stored `unbanked` first, then offline income from the saved garden; returns both.
function GardenProgress.login(p: Profile, now: number, today: number): (Profile, number, number)
	local out = GardenProgress.sanitize(p, now)
	local unbanked = out.unbanked
	local offline = GardenRules.offline(out, now)
	out.coins = math.min(MAX_COINS, out.coins + unbanked + offline)
	out.unbanked = 0
	out.lastSeen = now
	return MetaRules.login(CONFIG, out, today), offline, unbanked
end

-- The last op of every flush, so a stored record never pays a banked coin twice.
function GardenProgress.snapshot(p: Profile, unbanked: number, now: number): Profile
	local out = GardenRules.copy(p)
	out.unbanked = math.clamp(floor(unbanked), 0, MAX_COINS)
	out.lastSeen = now
	return out
end

function GardenProgress.leave(p: Profile, now: number): Profile
	return GardenProgress.snapshot(p, 0, now)
end

function GardenProgress.bank(p: Profile, coins: number, pads: number, today: number): Profile
	local out = GardenRules.copy(p)
	out.coins = math.min(MAX_COINS, out.coins + math.max(0, floor(coins)))
	if pads >= 1 then
		out = MetaRules.addProgress(CONFIG, out, today, { collects = math.floor(pads) })
	end
	return out
end

-- XP and quest stats around the plot and hatch rules -----------------------------------------

local function addXp(p: Profile, xp: number)
	p.xp = math.min(MetaRules.MAX_XP, p.xp + xp)
end

function GardenProgress.hatch(
	p: Profile,
	bed: number,
	o: HatchRules.Outcome,
	now: number,
	today: number
): (Profile, boolean, HatchRules.Result?)
	local out, ok, result = HatchRules.apply(p, bed, o, now)
	if not ok then
		return p, false, nil
	end
	out = MetaRules.addProgress(CONFIG, out, today, {
		hatches = 1,
		rareHatches = if GardenConfig.rarityIndex(o.s) >= GardenConfig.RARE then 1 else 0,
		mutants = if o.m ~= "normal" then 1 else 0,
	})
	return out, true, result
end

function GardenProgress.ownWater(p: Profile, bed: number, now: number, today: number): (Profile, boolean)
	local out, ok = GardenRules.water(p, bed, now, false)
	if not ok then
		return p, false
	end
	addXp(out, GardenConfig.XP.ownWater)
	out.waters = math.min(MAX_COUNT, out.waters + 1)
	return MetaRules.addProgress(CONFIG, out, today, { waters = 1 }), true
end

-- The helper's side of a water (the bed change goes to the owner via GardenRules.water).
function GardenProgress.helperWater(p: Profile, today: number): (Profile, number)
	local out = GardenRules.copy(p)
	if out.helped.day ~= today then
		out.helped = { day = today, count = 0 }
	end
	local xp = if out.helped.count < GardenConfig.XP.helperCap then GardenConfig.XP.helperWater else 0
	out.helped.count = math.min(MAX_COUNT, out.helped.count + 1)
	addXp(out, xp)
	out.waters = math.min(MAX_COUNT, out.waters + 1)
	return MetaRules.addProgress(CONFIG, out, today, { waters = 1 }), xp
end

function GardenProgress.release(p: Profile, id: number, today: number): (Profile, boolean, number)
	local out, ok, coins = GardenRules.release(p, id)
	if not ok then
		return p, false, 0
	end
	return MetaRules.addProgress(CONFIG, out, today, { releases = 1 }), true, coins
end

-- Likes and the gate (G1, G2) ----------------------------------------------------------------

-- The liker's side: not self, once per target per UTC day, at most 30 given per day.
function GardenProgress.like(p: Profile, target: number, liker: number, today: number): (Profile, boolean)
	if target == liker then
		return p, false
	end
	local ids = if p.liked.day == today then p.liked.ids else {}
	if table.find(ids, target) or #ids >= GardenConfig.LIKES.perDay then
		return p, false
	end
	local out = GardenRules.copy(p)
	out.liked = { day = today, ids = table.clone(ids) }
	table.insert(out.liked.ids, target)
	return out, true
end

function GardenProgress.receiveLike(p: Profile): Profile
	local out = GardenRules.copy(p)
	out.likes = math.min(MAX_COUNT, out.likes + 1)
	return out
end

function GardenProgress.setGate(p: Profile, gate: string): (Profile, boolean)
	if not table.find(GardenConfig.GATES, gate) then
		return p, false
	end
	local out = GardenRules.copy(p)
	out.gate = gate
	return out, true
end

-- Owners are checked separately.
function GardenProgress.gateAllows(gate: string, isFriend: boolean): boolean
	return gate == "open" or (gate == "friends" and isFriend)
end

-- Shared meta (MetaRules with Garden's config) -----------------------------------------------

function GardenProgress.levelFor(xp: number): number
	return MetaRules.levelFor(xp)
end

function GardenProgress.questsFor(today: number): { MetaRules.Quest }
	return MetaRules.questsFor(GardenConfig.QUESTS, today)
end

function GardenProgress.isUnlocked(p: Profile, id: string): boolean
	return MetaRules.isUnlocked(CONFIG, p, id)
end

function GardenProgress.claimDaily(p: Profile, today: number): (Profile, boolean, number)
	return MetaRules.claimDaily(CONFIG, p, today)
end

function GardenProgress.claimWeekly(p: Profile, today: number): (Profile, boolean, number)
	return MetaRules.claimWeekly(CONFIG, p, today)
end

function GardenProgress.claimQuest(p: Profile, today: number, questId: string): (Profile, boolean, number)
	return MetaRules.claimQuest(CONFIG, p, today, questId)
end

function GardenProgress.buyCosmetic(p: Profile, id: string): (Profile, boolean)
	return MetaRules.buy(CONFIG, p, id)
end

function GardenProgress.equipCosmetic(p: Profile, id: string): (Profile, boolean)
	return MetaRules.equip(CONFIG, p, id)
end

return GardenProgress
