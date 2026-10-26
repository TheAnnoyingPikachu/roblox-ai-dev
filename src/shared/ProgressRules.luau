--!strict
-- Pure Relay Rounds progression rules (decision 0006): XP and levels, coins, trails (level, win
-- and shop unlocks), daily login streak, weekly login bonus and daily quests, plus the saved
-- profile record. The shared reward rules live in MetaRules (decision 0007); this module is
-- Relay's config for them plus its match rules. No Roblox APIs, so Lune can unit-test them. The
-- server decides every input: match results come from the server and `day` is the server's UTC
-- day number.

local MetaRules = require("./MetaRules")

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

export type Trail = MetaRules.Cosmetic

export type Quest = MetaRules.Quest

ProgressRules.SCHEMA_VERSION = 1
ProgressRules.MAX_LEVEL = MetaRules.MAX_LEVEL
ProgressRules.MAX_XP = MetaRules.MAX_XP
ProgressRules.MAX_COINS = MetaRules.MAX_COINS
ProgressRules.MAX_COUNT = MetaRules.MAX_COUNT

ProgressRules.XP = { race = 20, leg = 10, round = 5, win = 60 }
ProgressRules.COINS = { race = 10, leg = 5, round = 0, win = 25 }
ProgressRules.DAILY = { 50, 75, 100, 125, 150, 200, 400 } -- streak day 1..7, then stays at 7
ProgressRules.WEEKLY = { days = 5, reward = 500 }

local function trail(id: string, name: string, colours: { { number } }, unlock: { [string]: number }): Trail
	return {
		id = id,
		name = name,
		slot = "trail",
		colours = colours,
		level = unlock.level,
		wins = unlock.wins,
		price = unlock.price,
	}
end

local TRAILS: { Trail } = {
	trail("team", "Team Colour", {}, { level = 1 }),
	trail("sakura", "Sakura", { { 255, 183, 210 }, { 255, 255, 255 } }, { level = 3 }),
	trail("ember", "Ember", { { 255, 200, 60 }, { 255, 40, 0 } }, { level = 5 }),
	trail("cyan", "Neon Cyan", { { 0, 255, 255 }, { 0, 120, 255 } }, { level = 8 }),
	trail("shadow", "Demon Shadow", { { 120, 0, 40 }, { 20, 0, 30 } }, { level = 12 }),
	trail(
		"rainbow",
		"Rainbow Dash",
		{ { 255, 60, 60 }, { 255, 220, 60 }, { 60, 255, 120 }, { 60, 160, 255 }, { 200, 80, 255 } },
		{ level = 18 }
	),
	trail("gold", "Champion Gold", { { 255, 230, 120 }, { 200, 140, 20 } }, { wins = 10 }),
	trail("lightning", "Lightning", { { 255, 255, 140 }, { 120, 160, 255 } }, { price = 750 }),
	trail("galaxy", "Galaxy", { { 40, 0, 90 }, { 160, 60, 255 }, { 255, 255, 255 } }, { price = 1500 }),
	trail("inferno", "Inferno", { { 255, 255, 200 }, { 255, 120, 0 }, { 120, 0, 0 } }, { price = 2500 }),
	trail("void", "Void", { { 0, 0, 0 }, { 90, 0, 140 } }, { price = 5000 }),
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

local CONFIG: MetaRules.Config<Profile> = {
	cosmetics = TRAILS,
	slots = { trail = "team" },
	quests = QUEST_POOL,
	daily = ProgressRules.DAILY,
	weekly = ProgressRules.WEEKLY,
	sanitize = function(record: any): Profile
		return ProgressRules.sanitize(record)
	end,
}

ProgressRules.dayOf = MetaRules.dayOf
ProgressRules.weekOf = MetaRules.weekOf
ProgressRules.levelFor = MetaRules.levelFor
ProgressRules.xpForLevel = MetaRules.xpForLevel

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

function ProgressRules.trail(id: string): Trail?
	return MetaRules.cosmetic(CONFIG, id)
end

function ProgressRules.isUnlocked(profile: Profile, id: string): boolean
	return MetaRules.isUnlocked(CONFIG, profile, id)
end

-- Turns whatever is stored into a valid profile.
function ProgressRules.sanitize(record: any): Profile
	local p = ProgressRules.defaults()
	if type(record) == "table" then
		p.races = MetaRules.count(record.races, ProgressRules.MAX_COUNT)
		p.legs = MetaRules.count(record.legs, ProgressRules.MAX_COUNT)
	end
	return MetaRules.sanitizeMeta(CONFIG, record, p)
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
	return MetaRules.questsFor(QUEST_POOL, today)
end

-- Adds one finished match to a profile. Returns a new profile and the XP and coins earned.
function ProgressRules.applyMatch(profile: Profile, result: MatchResult, today: number): (Profile, number, number)
	local p = ProgressRules.sanitize(profile)
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
	local deltas = { races = 1, legs = legs, rounds = rounds, wins = if result.won then 1 else 0 }
	return MetaRules.addProgress(CONFIG, p, today, deltas), xp, coins
end

-- Logins, daily and weekly rewards -----------------------------------------------------------

-- Records that the player was online on `today`, for the weekly bonus.
function ProgressRules.login(profile: Profile, today: number): Profile
	return MetaRules.login(CONFIG, profile, today)
end

-- The streak day the next claim would be, or nil if today's reward is already claimed.
function ProgressRules.nextDaily(profile: Profile, today: number): number?
	return MetaRules.nextDaily(profile, today)
end

function ProgressRules.dailyReward(streak: number): number
	return MetaRules.dailyReward(CONFIG, streak)
end

function ProgressRules.claimDaily(profile: Profile, today: number): (Profile, boolean, number)
	return MetaRules.claimDaily(CONFIG, profile, today)
end

function ProgressRules.canClaimWeekly(profile: Profile, today: number): boolean
	return MetaRules.canClaimWeekly(CONFIG, profile, today)
end

function ProgressRules.claimWeekly(profile: Profile, today: number): (Profile, boolean, number)
	return MetaRules.claimWeekly(CONFIG, profile, today)
end

function ProgressRules.claimQuest(profile: Profile, today: number, questId: string): (Profile, boolean, number)
	return MetaRules.claimQuest(CONFIG, profile, today, questId)
end

-- Trails -------------------------------------------------------------------------------------

function ProgressRules.buyTrail(profile: Profile, id: string): (Profile, boolean)
	return MetaRules.buy(CONFIG, profile, id)
end

-- Equips a trail if it is unlocked; otherwise returns the profile unchanged.
function ProgressRules.equip(profile: Profile, id: string): (Profile, boolean)
	return MetaRules.equip(CONFIG, profile, id)
end

return ProgressRules
