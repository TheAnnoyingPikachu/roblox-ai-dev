--!strict
-- Pure Relay Rounds progression rules (decision 0006): XP and levels, coins, trails (level, win
-- and shop unlocks), daily login streak, weekly login bonus and daily quests, plus the saved
-- profile record. No Roblox APIs, so Lune can unit-test them. The server decides every input:
-- match results come from the server and `day` is the server's UTC day number.

local ProgressRules = {}

export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	wins: number,
	races: number,
	legs: number,
	trail: string,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}

export type MatchResult = { legs: number, roundsSurvived: number, won: boolean }

export type Trail = {
	id: string,
	name: string,
	colours: { { number } }, -- RGB 0-255, one or more stops
	level: number?,
	wins: number?,
	price: number?,
}

export type Quest = { id: string, label: string, stat: string, goal: number, reward: number }

ProgressRules.SCHEMA_VERSION = 1
ProgressRules.MAX_LEVEL = 50
ProgressRules.MAX_XP = 1_000_000
ProgressRules.MAX_COINS = 10_000_000
ProgressRules.MAX_COUNT = 1_000_000

ProgressRules.XP = { race = 20, leg = 10, round = 5, win = 60 }
ProgressRules.COINS = { race = 10, leg = 5, round = 0, win = 25 }
ProgressRules.DAILY = { 50, 75, 100, 125, 150, 200, 400 } -- streak day 1..7, then stays at 7
ProgressRules.WEEKLY = { days = 5, reward = 500 }

local TRAILS: { Trail } = {
	{ id = "team", name = "Team Colour", colours = {}, level = 1 },
	{ id = "sakura", name = "Sakura", colours = { { 255, 183, 210 }, { 255, 255, 255 } }, level = 3 },
	{ id = "ember", name = "Ember", colours = { { 255, 200, 60 }, { 255, 40, 0 } }, level = 5 },
	{ id = "cyan", name = "Neon Cyan", colours = { { 0, 255, 255 }, { 0, 120, 255 } }, level = 8 },
	{ id = "shadow", name = "Demon Shadow", colours = { { 120, 0, 40 }, { 20, 0, 30 } }, level = 12 },
	{
		id = "rainbow",
		name = "Rainbow Dash",
		colours = { { 255, 60, 60 }, { 255, 220, 60 }, { 60, 255, 120 }, { 60, 160, 255 }, { 200, 80, 255 } },
		level = 18,
	},
	{ id = "gold", name = "Champion Gold", colours = { { 255, 230, 120 }, { 200, 140, 20 } }, wins = 10 },
	{ id = "lightning", name = "Lightning", colours = { { 255, 255, 140 }, { 120, 160, 255 } }, price = 750 },
	{ id = "galaxy", name = "Galaxy", colours = { { 40, 0, 90 }, { 160, 60, 255 }, { 255, 255, 255 } }, price = 1500 },
	{ id = "inferno", name = "Inferno", colours = { { 255, 255, 200 }, { 255, 120, 0 }, { 120, 0, 0 } }, price = 2500 },
	{ id = "void", name = "Void", colours = { { 0, 0, 0 }, { 90, 0, 140 } }, price = 5000 },
}
ProgressRules.TRAILS = TRAILS

local QUEST_POOL: { Quest } = {
	{ id = "play3", label = "Play 3 matches", stat = "races", goal = 3, reward = 100 },
	{ id = "legs5", label = "Run 5 legs", stat = "legs", goal = 5, reward = 100 },
	{ id = "legs12", label = "Run 12 legs", stat = "legs", goal = 12, reward = 200 },
	{ id = "win1", label = "Win a match", stat = "wins", goal = 1, reward = 150 },
	{ id = "win3", label = "Win 3 matches", stat = "wins", goal = 3, reward = 300 },
	{ id = "rounds6", label = "Survive 6 rounds", stat = "rounds", goal = 6, reward = 120 },
}
ProgressRules.QUEST_POOL = QUEST_POOL

-- Days and weeks -----------------------------------------------------------------------------

function ProgressRules.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

-- Weeks start on Monday (UTC day 0, 1 Jan 1970, was a Thursday).
function ProgressRules.weekOf(day: number): number
	return math.floor((day + 3) / 7)
end

-- Profile ------------------------------------------------------------------------------------

function ProgressRules.defaults(): Profile
	return {
		schemaVersion = ProgressRules.SCHEMA_VERSION,
		xp = 0,
		coins = 0,
		wins = 0,
		races = 0,
		legs = 0,
		trail = "team",
		owned = {},
		daily = { streak = 0, last = -1 },
		week = { key = -1, days = 0, lastDay = -1, claimed = false },
		quests = { day = -1, progress = {}, claimed = {} },
	}
end

local function count(value: any, cap: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, cap)
end

local function day(value: any): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return -1
	end
	return math.max(-1, math.floor(value))
end

function ProgressRules.trail(id: string): Trail?
	for _, t in TRAILS do
		if t.id == id then
			return t
		end
	end
	return nil
end

function ProgressRules.levelFor(xp: number): number
	return math.min(ProgressRules.MAX_LEVEL, math.floor(math.sqrt(math.max(xp, 0) / 40)) + 1)
end

-- Total XP needed to reach `level`.
function ProgressRules.xpForLevel(level: number): number
	return 40 * (level - 1) ^ 2
end

function ProgressRules.isUnlocked(profile: Profile, id: string): boolean
	local t = ProgressRules.trail(id)
	if t == nil then
		return false
	end
	if t.price then
		return profile.owned[id] == true
	end
	if t.level and ProgressRules.levelFor(profile.xp) < t.level then
		return false
	end
	if t.wins and profile.wins < t.wins then
		return false
	end
	return true
end

-- Turns whatever is stored into a valid profile.
function ProgressRules.sanitize(record: any): Profile
	local p = ProgressRules.defaults()
	if type(record) ~= "table" then
		return p
	end
	p.xp = count(record.xp, ProgressRules.MAX_XP)
	p.coins = count(record.coins, ProgressRules.MAX_COINS)
	p.wins = count(record.wins, ProgressRules.MAX_COUNT)
	p.races = count(record.races, ProgressRules.MAX_COUNT)
	p.legs = count(record.legs, ProgressRules.MAX_COUNT)
	if type(record.owned) == "table" then
		for id, value in record.owned do
			local t = type(id) == "string" and ProgressRules.trail(id)
			if t and t.price and value == true then
				p.owned[id] = true
			end
		end
	end
	if type(record.daily) == "table" then
		p.daily = { streak = math.min(count(record.daily.streak, 10_000), 10_000), last = day(record.daily.last) }
	end
	if type(record.week) == "table" then
		p.week = {
			key = day(record.week.key),
			days = math.min(count(record.week.days, 7), 7),
			lastDay = day(record.week.lastDay),
			claimed = record.week.claimed == true,
		}
	end
	if type(record.quests) == "table" then
		p.quests.day = day(record.quests.day)
		if type(record.quests.progress) == "table" then
			for stat, value in record.quests.progress do
				if type(stat) == "string" then
					p.quests.progress[stat] = count(value, ProgressRules.MAX_COUNT)
				end
			end
		end
		if type(record.quests.claimed) == "table" then
			for id, value in record.quests.claimed do
				if type(id) == "string" and value == true then
					p.quests.claimed[id] = true
				end
			end
		end
	end
	p.trail = if type(record.trail) == "string" then record.trail else "team"
	if not ProgressRules.isUnlocked(p, p.trail) then
		p.trail = "team"
	end
	return p
end

local function clone(profile: Profile): Profile
	return ProgressRules.sanitize(profile)
end

-- Matches ------------------------------------------------------------------------------------

function ProgressRules.matchRewards(result: MatchResult): (number, number)
	local legs = math.max(0, math.floor(result.legs))
	local rounds = math.max(0, math.floor(result.roundsSurvived))
	local xp = ProgressRules.XP.race + ProgressRules.XP.leg * legs + ProgressRules.XP.round * rounds
	local coins = ProgressRules.COINS.race + ProgressRules.COINS.leg * legs + ProgressRules.COINS.round * rounds
	if result.won then
		xp += ProgressRules.XP.win
		coins += ProgressRules.COINS.win
	end
	return xp, coins
end

-- Today's quests: three distinct picks from the pool, the same for everyone on a given day.
function ProgressRules.questsFor(today: number): { Quest }
	local picks: { Quest } = {}
	local n = #QUEST_POOL
	local start = (today * 7) % n
	local step = 1 + today % (n - 1)
	local used: { [number]: boolean } = {}
	local i = start
	while #picks < 3 do
		while used[i] do
			i = (i + 1) % n
		end
		used[i] = true
		table.insert(picks, QUEST_POOL[i + 1])
		i = (i + step) % n
	end
	return picks
end

-- Quest progress resets when the day changes.
local function questsToday(p: Profile, today: number)
	if p.quests.day ~= today then
		p.quests = { day = today, progress = {}, claimed = {} }
	end
end

-- Adds one finished match to a profile. Returns a new profile and the XP and coins earned.
function ProgressRules.applyMatch(profile: Profile, result: MatchResult, today: number): (Profile, number, number)
	local p = clone(profile)
	local xp, coins = ProgressRules.matchRewards(result)
	local legs = math.max(0, math.floor(result.legs))
	local rounds = math.max(0, math.floor(result.roundsSurvived))
	p.xp = math.min(ProgressRules.MAX_XP, p.xp + xp)
	p.coins = math.min(ProgressRules.MAX_COINS, p.coins + coins)
	p.races = math.min(ProgressRules.MAX_COUNT, p.races + 1)
	p.legs = math.min(ProgressRules.MAX_COUNT, p.legs + legs)
	if result.won then
		p.wins = math.min(ProgressRules.MAX_COUNT, p.wins + 1)
	end
	questsToday(p, today)
	local progress = p.quests.progress
	progress.races = (progress.races or 0) + 1
	progress.legs = (progress.legs or 0) + legs
	progress.rounds = (progress.rounds or 0) + rounds
	progress.wins = (progress.wins or 0) + (if result.won then 1 else 0)
	return p, xp, coins
end

-- Logins, daily and weekly rewards -----------------------------------------------------------

-- Records that the player was online on `today`, for the weekly bonus.
function ProgressRules.login(profile: Profile, today: number): Profile
	local p = clone(profile)
	local week = ProgressRules.weekOf(today)
	if p.week.key ~= week then
		p.week = { key = week, days = 0, lastDay = -1, claimed = false }
	end
	if p.week.lastDay ~= today then
		p.week.days = math.min(7, p.week.days + 1)
		p.week.lastDay = today
	end
	questsToday(p, today)
	return p
end

-- The streak day the next claim would be, or nil if today's reward is already claimed.
function ProgressRules.nextDaily(profile: Profile, today: number): number?
	if profile.daily.last == today then
		return nil
	end
	if profile.daily.last == today - 1 then
		return profile.daily.streak + 1
	end
	return 1
end

function ProgressRules.dailyReward(streak: number): number
	return ProgressRules.DAILY[math.clamp(streak, 1, #ProgressRules.DAILY)]
end

function ProgressRules.claimDaily(profile: Profile, today: number): (Profile, boolean, number)
	local streak = ProgressRules.nextDaily(profile, today)
	if streak == nil then
		return profile, false, 0
	end
	local p = clone(profile)
	local reward = ProgressRules.dailyReward(streak)
	p.daily = { streak = streak, last = today }
	p.coins = math.min(ProgressRules.MAX_COINS, p.coins + reward)
	return p, true, reward
end

function ProgressRules.canClaimWeekly(profile: Profile, today: number): boolean
	return profile.week.key == ProgressRules.weekOf(today)
		and profile.week.days >= ProgressRules.WEEKLY.days
		and not profile.week.claimed
end

function ProgressRules.claimWeekly(profile: Profile, today: number): (Profile, boolean, number)
	if not ProgressRules.canClaimWeekly(profile, today) then
		return profile, false, 0
	end
	local p = clone(profile)
	p.week.claimed = true
	p.coins = math.min(ProgressRules.MAX_COINS, p.coins + ProgressRules.WEEKLY.reward)
	return p, true, ProgressRules.WEEKLY.reward
end

function ProgressRules.claimQuest(profile: Profile, today: number, questId: string): (Profile, boolean, number)
	local quest: Quest? = nil
	for _, q in ProgressRules.questsFor(today) do
		if q.id == questId then
			quest = q
		end
	end
	if quest == nil or profile.quests.day ~= today or profile.quests.claimed[questId] then
		return profile, false, 0
	end
	if (profile.quests.progress[quest.stat] or 0) < quest.goal then
		return profile, false, 0
	end
	local p = clone(profile)
	p.quests.claimed[questId] = true
	p.coins = math.min(ProgressRules.MAX_COINS, p.coins + quest.reward)
	return p, true, quest.reward
end

-- Trails -------------------------------------------------------------------------------------

function ProgressRules.buyTrail(profile: Profile, id: string): (Profile, boolean)
	local t = type(id) == "string" and ProgressRules.trail(id)
	if not t or not t.price or profile.owned[id] or profile.coins < t.price then
		return profile, false
	end
	local p = clone(profile)
	p.coins -= t.price
	p.owned[id] = true
	return p, true
end

-- Equips a trail if it is unlocked; otherwise returns the profile unchanged.
function ProgressRules.equip(profile: Profile, id: string): (Profile, boolean)
	if type(id) ~= "string" or not ProgressRules.isUnlocked(profile, id) then
		return profile, false
	end
	local p = clone(profile)
	p.trail = id
	return p, true
end

return ProgressRules
