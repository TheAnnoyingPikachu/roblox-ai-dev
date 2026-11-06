--!strict
-- Lantern Express save, meta and rewards (architecture lantern 3.8, decision 0018 section 4, GDD
-- H, J): schema v1 defaults and sanitise, load shares, Depot and Dawn payouts, the album and its
-- milestones, role badges, daily quests (MetaRules with Lantern's config) and the weekly and
-- monthly login tracks (LoginRules' calendar maths, Lantern's own slots). Every function changes
-- one player's profile only and takes every random outcome as an input; nothing here ever lowers
-- Tickets, XP, the album, quest progress, milestones or bests. No Roblox APIs.

local LanternConfig = require("./LanternConfig")
local LoginRules = require("./LoginRules")
local MetaRules = require("./MetaRules")

local LanternProgress = {}

export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number, -- Tickets
	lastSeen: number,
	index: { string }, -- album: species rescued at least once, in first-rescue order
	rescues: { [string]: number },
	stats: { [string]: number },
	best: { critters: number, dist: number },
	weekBest: { week: number, critters: number, dist: number },
	milestones: { [string]: boolean },
	follower: string,
	livery: string,
	lamp: string,
	badge: string,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
	login: LoginRules.Login,
}
export type Loaded = { kind: LanternConfig.ItemKind, species: string?, rarity: LanternConfig.Rarity? }
export type Paid = { tickets: number, xp: number, new: { string }, text: string }

LanternProgress.SCHEMA_VERSION = 1
LanternProgress.STATS = {
	"runs",
	"dawns",
	"legs",
	"depots",
	"loads",
	"rescues",
	"rareRescues",
	"puffs",
	"stokes",
	"mends",
	"caught",
	"fed",
}
LanternProgress.MAX_DIST = 20000 -- sanitise cap of best.dist (decision 0018)

local MAX_XP, MAX_COINS, MAX_COUNT, MAX_TIME = MetaRules.MAX_XP, MetaRules.MAX_COINS, MetaRules.MAX_COUNT, 1e12
local RUN_DIST = 3 * LanternConfig.TRACKS.forest.finish -- a Dawn finish: the Farthest board's cap
local RARE = { rare = true, epic = true, legendary = true }
local TRACKS = { "week", "month" }

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function copy(p: Profile): Profile
	return deepCopy(p)
end

local function commas(n: number): string
	local s = string.reverse((string.gsub(string.reverse(string.format("%d", n)), "(%d%d%d)", "%1,")))
	return (string.gsub(s, "^,", ""))
end

local function addCoins(p: Profile, tickets: number): number
	local paid = math.clamp(tickets, 0, MAX_COINS - p.coins)
	p.coins += paid
	return paid
end

local function addXp(p: Profile, xp: number)
	p.xp = math.min(MAX_XP, p.xp + xp)
end

local function stat(p: Profile, key: string, by: number)
	p.stats[key] = math.min(MAX_COUNT, (p.stats[key] or 0) + by)
end

-- Profile ------------------------------------------------------------------------------------

function LanternProgress.defaults(now: number): Profile
	local stats = {}
	for _, key in LanternProgress.STATS do
		stats[key] = 0
	end
	return {
		schemaVersion = LanternProgress.SCHEMA_VERSION,
		xp = 0,
		coins = 0,
		lastSeen = now,
		index = {},
		rescues = {},
		stats = stats,
		best = { critters = 0, dist = 0 },
		weekBest = { week = -1, critters = 0, dist = 0 },
		milestones = {},
		follower = "",
		livery = LanternConfig.SLOTS.livery,
		lamp = LanternConfig.SLOTS.lamp,
		badge = "",
		owned = {},
		daily = { streak = 0, last = -1 },
		week = { key = -1, days = 0, lastDay = -1, claimed = false },
		quests = { day = -1, progress = {}, claimed = {} },
		login = LoginRules.defaults(),
	}
end

local CONFIG: MetaRules.Config<Profile> = {
	cosmetics = LanternConfig.COSMETICS,
	slots = LanternConfig.SLOTS,
	quests = LanternConfig.QUESTS,
	daily = { 0 }, -- MetaRules ticks daily and week; Lantern pays nothing for them (decision 0018)
	weekly = { days = 7, reward = 0 },
	sanitize = function(record: any): Profile
		return LanternProgress.sanitize(record)
	end,
}
LanternProgress.config = CONFIG

function LanternProgress.tier(p: Profile, role: string): number
	for _, r in LanternConfig.ROLES do
		if r.id == role then
			local n, tier = p.stats[r.stat] or 0, 0
			for i, need in r.tiers do
				if n >= need then
					tier = i
				end
			end
			return tier
		end
	end
	return 0
end

-- A record written by a later build (schemaVersion above 1) loads read-only (kit `newer` option).
function LanternProgress.isNewer(record: any): boolean
	return type(record) == "table"
		and type(record.schemaVersion) == "number"
		and record.schemaVersion > LanternProgress.SCHEMA_VERSION
end

-- Decision 0018 section 4. A record without schemaVersion loads as v1. Game fields first, so
-- MetaRules' slot checks see the sanitised XP and owned list.
function LanternProgress.sanitize(record: any, now: number?): Profile
	local p = LanternProgress.defaults(now or 0)
	if type(record) ~= "table" then
		return p
	end
	p.lastSeen = MetaRules.count(record.lastSeen, MAX_TIME)
	if now and p.lastSeen > now then
		p.lastSeen = now
	end
	local rescues = if type(record.rescues) == "table" then record.rescues else {}
	for _, c in LanternConfig.CRITTERS do
		local n = MetaRules.count(rescues[c.id], MAX_COUNT)
		if n >= 1 then
			p.rescues[c.id] = n
		end
	end
	if type(record.index) == "table" then
		for _, id in ipairs(record.index) do
			if type(id) == "string" and p.rescues[id] and not table.find(p.index, id) then
				table.insert(p.index, id)
			end
		end
	end
	local missing = {}
	for id in p.rescues do
		if not table.find(p.index, id) then
			table.insert(missing, id)
		end
	end
	table.sort(missing) -- appended in id order
	for _, id in missing do
		table.insert(p.index, id)
	end
	local stats = if type(record.stats) == "table" then record.stats else {}
	for _, key in LanternProgress.STATS do
		p.stats[key] = MetaRules.count(stats[key], MAX_COUNT)
	end
	if type(record.best) == "table" then
		p.best = {
			critters = MetaRules.count(record.best.critters, MAX_COUNT),
			dist = MetaRules.count(record.best.dist, LanternProgress.MAX_DIST),
		}
	end
	if type(record.weekBest) == "table" then
		p.weekBest = {
			week = MetaRules.dayNumber(record.weekBest.week),
			critters = MetaRules.count(record.weekBest.critters, MAX_COUNT),
			dist = MetaRules.count(record.weekBest.dist, LanternProgress.MAX_DIST),
		}
	end
	local thisWeek = if now then MetaRules.weekOf(MetaRules.dayOf(now)) else nil
	if thisWeek and p.weekBest.week < thisWeek then
		p.weekBest = { week = thisWeek, critters = 0, dist = 0 }
	end
	if type(record.milestones) == "table" then
		for _, m in LanternConfig.MILESTONES do
			if record.milestones[tostring(m.count)] == true then
				p.milestones[tostring(m.count)] = true
			end
		end
	end
	if type(record.follower) == "string" and p.rescues[record.follower] then
		p.follower = record.follower
	end
	if type(record.badge) == "string" and LanternProgress.tier(p, record.badge) >= 1 then
		p.badge = record.badge
	end
	p.login = LoginRules.sanitize(record.login)
	return MetaRules.sanitizeMeta(CONFIG, record, p)
end

function LanternProgress.snapshot(p: Profile, now: number): Profile
	local out = copy(p)
	out.lastSeen = now
	return out
end

-- H3: each active crew member's Tickets for a load worth v.
function LanternProgress.share(v: number, n: number): number
	n = math.max(1, math.floor(n))
	return math.max(0, math.ceil(v * (1 + LanternConfig.TICKETS.coop * (n - 1)) / n - 1e-9))
end

-- The album -------------------------------------------------------------------------------------

-- Adds one rescue; true when the species is new to the album.
local function rescue(p: Profile, species: string): boolean
	local new = p.rescues[species] == nil
	p.rescues[species] = math.min(MAX_COUNT, (p.rescues[species] or 0) + 1)
	if new then
		table.insert(p.index, species)
	end
	return new
end

-- Pays every milestone the album has reached and not yet paid (once each): (Tickets, names).
local function milestones(p: Profile): (number, { string })
	local tickets, names = 0, {}
	for _, m in LanternConfig.MILESTONES do
		local key = tostring(m.count)
		if #p.index >= m.count and not p.milestones[key] then
			p.milestones[key] = true
			tickets += addCoins(p, m.tickets or 0)
			if m.cosmetic and not p.owned[m.cosmetic] then
				p.owned[m.cosmetic] = true
				table.insert(names, (LanternConfig.cosmetic(m.cosmetic) :: MetaRules.Cosmetic).name)
			end
		end
	end
	return tickets, names
end

local function paid(tickets: number, xp: number, new: { string }, extra: { string }): Paid
	local parts = {}
	if #new > 0 then
		local names = {}
		for _, id in new do
			table.insert(names, (LanternConfig.critter(id) :: LanternConfig.Critter).name)
		end
		table.insert(parts, `NEW! {table.concat(names, ", ")}`)
	end
	for _, name in extra do
		table.insert(parts, name)
	end
	if tickets > 0 then
		table.insert(parts, `+{commas(tickets)} Tickets`)
	end
	if xp > 0 then
		table.insert(parts, `+{commas(xp)} XP`)
	end
	return { tickets = tickets, xp = xp, new = new, text = table.concat(parts, " · ") }
end

-- Daily quests (GDD G3.5, J) ----------------------------------------------------------------------

-- When `today` moved past the stored quest day, pays that day's completed, unclaimed quests once
-- and starts today's. Returns the "(saved for you)" text, "" if nothing was paid.
function LanternProgress.dayTick(p: Profile, today: number): (Profile, string)
	local q = p.quests
	if q.day < 0 or today <= q.day then
		return p, ""
	end
	local out = copy(p)
	local tickets = 0
	for _, quest in MetaRules.questsFor(LanternConfig.QUESTS, q.day) do
		if (q.progress[quest.stat] or 0) >= quest.goal and not q.claimed[quest.id] then
			tickets += addCoins(out, quest.reward)
		end
	end
	out.quests = { day = today, progress = {}, claimed = {} }
	return out, if tickets > 0 then `{commas(tickets)} Tickets (saved for you)` else ""
end

function LanternProgress.claimQuest(p: Profile, today: number, id: string): (Profile, boolean, number)
	local out = LanternProgress.dayTick(p, today)
	return MetaRules.claimQuest(CONFIG, out, today, id)
end

-- Rewards ----------------------------------------------------------------------------------------

-- One load reaching the train (items carried by one player): every active member's share of each
-- item's Tickets; small and big XP only for the carrier (`mine`), rescue XP for everyone; album,
-- milestones and quest progress. Species and rarities were rolled when the stop was built.
function LanternProgress.load(p: Profile, items: { Loaded }, mine: boolean, n: number, today: number): (Profile, Paid)
	local out = copy((LanternProgress.dayTick(p, today)))
	local tickets, xp, new = 0, 0, {}
	local deltas = { rescues = 0, loads = 0, rareRescues = 0 }
	for _, item in items do
		local spec = LanternConfig.ITEMS[item.kind]
		if spec == nil then
			continue
		end
		local value = if item.kind == "critter"
			then (LanternConfig.CRITTER_TICKETS :: any)[item.rarity or ""] or 0
			else spec.tickets or 0
		tickets += LanternProgress.share(value, n)
		if mine then
			xp += if spec.big then LanternConfig.XP.big else LanternConfig.XP.small
			stat(out, "loads", 1)
			deltas.loads += 1
		end
		local c = if item.kind == "critter" and item.species then LanternConfig.critter(item.species) else nil
		if c and c.rarity ~= "exclusive" then
			xp += LanternConfig.XP.rescue
			if rescue(out, c.id) then
				xp += LanternConfig.XP.new
				table.insert(new, c.id)
			end
			stat(out, "rescues", 1)
			deltas.rescues += 1
			if RARE[c.rarity] then
				stat(out, "rareRescues", 1)
				deltas.rareRescues += 1
			end
		end
	end
	tickets = addCoins(out, tickets)
	local bonus, names = milestones(out)
	addXp(out, xp)
	out = MetaRules.addProgress(CONFIG, out, today, deltas)
	return out, paid(tickets + bonus, xp, new, names)
end

local AWARDS = {
	depot = { tickets = LanternConfig.TICKETS.depot, xp = LanternConfig.XP.depot, stats = { "depots", "legs" } },
	dawn = { tickets = LanternConfig.TICKETS.dawn, xp = LanternConfig.XP.dawn, stats = { "dawns", "legs" } },
	fed = { tickets = LanternConfig.TICKETS.fed, xp = 0, stats = { "fed" } },
	stop = { tickets = 0, xp = LanternConfig.XP.stop, stats = {} },
	parts = { tickets = 0, xp = 0, stats = {} },
} :: { [string]: { tickets: number, xp: number, stats: { string } } }

-- Payouts to every member aboard: "depot", "dawn", "fed" (paid at Dawn), "stop" (left aboard) and
-- "parts" (`amount` = this member's leftover Parts share, DepotRules.leftover). Legs are counted here.
function LanternProgress.award(
	p: Profile,
	kind: "depot" | "dawn" | "fed" | "parts" | "stop",
	amount: number,
	today: number
): (Profile, Paid)
	local row = AWARDS[kind]
	if row == nil then
		return p, paid(0, 0, {}, {})
	end
	local out = copy((LanternProgress.dayTick(p, today)))
	local tickets = addCoins(out, if kind == "parts" then math.max(0, math.floor(amount)) else row.tickets)
	addXp(out, row.xp)
	local deltas = {}
	for _, key in row.stats do
		stat(out, key, 1)
		deltas[key] = 1
	end
	out = MetaRules.addProgress(CONFIG, out, today, deltas)
	return out, paid(tickets, row.xp, {}, {})
end

local COUNTED = {
	puffs = LanternConfig.XP.puff,
	stokes = LanternConfig.XP.stoke,
	mends = LanternConfig.XP.mend,
	caught = 0,
	legs = 0,
	runs = 0,
}

-- Puffs, stokes, mends and catches (legs and runs are already counted by award and runEnd).
function LanternProgress.count(
	p: Profile,
	key: "puffs" | "stokes" | "mends" | "caught" | "legs" | "runs",
	by: number,
	today: number
): Profile
	local xp = COUNTED[key]
	by = math.max(0, math.floor(by))
	if xp == nil or by == 0 then
		return p
	end
	local out = copy((LanternProgress.dayTick(p, today)))
	stat(out, key, by)
	addXp(out, xp * by)
	return MetaRules.addProgress(CONFIG, out, today, { [key] = by })
end

-- Run end: all-time bests, and this week's bests for a weekly run (`week` = MetaRules.weekOf);
-- returns which weekly values improved (the server writes those boards). A Dawn finish is the
-- Farthest cap.
function LanternProgress.runEnd(
	p: Profile,
	critters: number,
	dist: number,
	week: number?,
	dawn: boolean
): (Profile, { critters: boolean, dist: boolean })
	local out = copy(p)
	critters = MetaRules.count(critters, MAX_COUNT)
	dist = if dawn then RUN_DIST else MetaRules.count(dist, RUN_DIST)
	out.best.critters = math.max(out.best.critters, critters)
	out.best.dist = math.max(out.best.dist, dist)
	stat(out, "runs", 1)
	local improved = { critters = false, dist = false }
	if week then
		if out.weekBest.week ~= week then
			out.weekBest = { week = week, critters = 0, dist = 0 }
		end
		improved.critters = critters > out.weekBest.critters
		improved.dist = dist > out.weekBest.dist
		out.weekBest.critters = math.max(out.weekBest.critters, critters)
		out.weekBest.dist = math.max(out.weekBest.dist, dist)
	end
	return out, improved
end

-- Login tracks (GDD H5; the Garden X3 rules on Lantern's slots) -----------------------------------

local function slots(track: string, day: number): { LanternConfig.LoginSlot }
	local out = table.clone(LanternConfig.LOGIN[track])
	if track == "month" then
		local _, length = LoginRules.monthOf(day)
		local last = table.clone(out[#out])
		last.count = math.min(last.count, length)
		out[#out] = last
	end
	return out
end

-- Pays one slot into `out`: Tickets, then the cosmetic or the critter (their Tickets once owned).
local function pay(out: Profile, s: LanternConfig.LoginSlot): (number, { string })
	local tickets, names = s.tickets or 0, {}
	if s.cosmetic then
		if out.owned[s.cosmetic] then
			tickets += s.owned or 0
		else
			out.owned[s.cosmetic] = true
			table.insert(names, (LanternConfig.cosmetic(s.cosmetic) :: MetaRules.Cosmetic).name)
		end
	end
	local bonus = 0
	if s.critter then
		if out.rescues[s.critter] then
			tickets += s.owned or 0
		else
			rescue(out, s.critter) -- into the album like a rescue; counts for milestones
			table.insert(names, (LanternConfig.critter(s.critter) :: LanternConfig.Critter).name)
			local more
			bonus, more = milestones(out)
			for _, name in more do
				table.insert(names, name)
			end
		end
	end
	return addCoins(out, tickets) + bonus, names
end

local function login(p: Profile): any
	return p.login
end

function LanternProgress.canClaimLogin(p: Profile, track: string, today: number): boolean
	if not table.find(TRACKS, track) then
		return false
	end
	local l = login(p)
	local slot = slots(track, today)[l[track .. "Claimed"] + 1]
	return l[track] == LoginRules.periodOf(track, today) and slot ~= nil and l[track .. "Days"] >= slot.count
end

-- Pays the next slot. `slot`, when given, is the slot number the request saw: a re-run on a record
-- that already paid it changes nothing.
function LanternProgress.claimLogin(p: Profile, track: string, today: number, slot: number?): (Profile, boolean, string)
	local base = LanternProgress.dayTick(p, today)
	if not LanternProgress.canClaimLogin(base, track, today) then
		return base, false, ""
	end
	local n = login(base)[track .. "Claimed"] + 1
	if slot ~= nil and slot ~= n then
		return base, false, ""
	end
	local out = copy(base)
	local tickets, names = pay(out, slots(track, today)[n])
	login(out)[track .. "Claimed"] = n
	if tickets > 0 then
		table.insert(names, `{commas(tickets)} Tickets`)
	end
	return out, true, table.concat(names, " + ")
end

-- Per track: when the period moved on, pays every earned slot still unclaimed in the ending period,
-- in order (nothing earned is lost), then resets; then counts today once. A clock behind the
-- stored period changes nothing. Idempotent. Returns the "(saved for you)" text, "" if none.
function LanternProgress.loginTick(p: Profile, today: number): (Profile, string)
	local out = copy((LanternProgress.dayTick(p, today)))
	local l = login(out)
	local tickets, names = 0, {}
	for _, track in TRACKS do
		local key = LoginRules.periodOf(track, today)
		if key > l[track] then
			local list = slots(track, l[track .. "Last"])
			for n = l[track .. "Claimed"] + 1, #list do
				if l[track .. "Days"] < list[n].count then
					break
				end
				local t, more = pay(out, list[n])
				tickets += t
				for _, name in more do
					table.insert(names, name)
				end
			end
			l[track], l[track .. "Days"], l[track .. "Last"], l[track .. "Claimed"] = key, 0, -1, 0
		end
		if l[track] == key and today > l[track .. "Last"] then
			l[track .. "Days"] = math.min(LoginRules.MAX_DAYS, l[track .. "Days"] + 1)
			l[track .. "Last"] = today
		end
	end
	if tickets > 0 then
		table.insert(names, `{commas(tickets)} Tickets`)
	end
	return out, if #names > 0 then `{table.concat(names, " + ")} (saved for you)` else ""
end

function LanternProgress.claimable(p: Profile, today: number): number
	local n, l = 0, login(p)
	for _, track in TRACKS do
		if l[track] == LoginRules.periodOf(track, today) then
			local list = slots(track, today)
			for i = l[track .. "Claimed"] + 1, #list do
				if l[track .. "Days"] < list[i].count then
					break
				end
				n += 1
			end
		end
	end
	return n
end

-- At join: the stored day's quests, the login tracks, MetaRules' day and week; one toast text.
function LanternProgress.join(p: Profile, today: number): (Profile, string)
	local out, quests = LanternProgress.dayTick(p, today)
	local saved
	out, saved = LanternProgress.loginTick(out, today)
	out = MetaRules.login(CONFIG, out, today)
	local texts = {}
	for _, text in { quests, saved } do
		if text ~= "" then
			table.insert(texts, text)
		end
	end
	return out, table.concat(texts, " · ")
end

-- Locker, badge and follower -------------------------------------------------------------------

function LanternProgress.buy(p: Profile, id: string): (Profile, boolean)
	return MetaRules.buy(CONFIG, p, id)
end

function LanternProgress.equip(p: Profile, id: string): (Profile, boolean)
	return MetaRules.equip(CONFIG, p, id)
end

function LanternProgress.setBadge(p: Profile, role: string): (Profile, boolean)
	if role ~= "none" and LanternProgress.tier(p, role) < 1 then
		return p, false
	end
	local out = copy(p)
	out.badge = if role == "none" then "" else role
	return out, true
end

function LanternProgress.setFollower(p: Profile, species: string): (Profile, boolean)
	if species ~= "none" and not p.rescues[species] then
		return p, false
	end
	local out = copy(p)
	out.follower = if species == "none" then "" else species
	return out, true
end

return LanternProgress
