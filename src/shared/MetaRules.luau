--!strict
-- Pure meta-game rules shared by every game (decisions 0006 and 0007): levels, days and weeks,
-- daily streak, weekly bonus, daily quests, cosmetics by slot and sanitising. Each game passes a
-- Config; `ProgressRules` (Relay) and `NightProgress` (Night) are thin layers over this. No
-- Roblox APIs, so Lune can unit-test it. `today` is always the server's UTC day number.

local MetaRules = {}

export type Cosmetic = {
	id: string,
	name: string,
	slot: string,
	colours: { { number } },
	level: number?,
	wins: number?,
	tier: number?,
	price: number?,
}

export type Quest = { id: string, label: string, stat: string, goal: number, reward: number }

export type Meta = {
	xp: number,
	coins: number,
	wins: number,
	bestTier: number?,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}

export type Config<P> = {
	cosmetics: { Cosmetic },
	slots: { [string]: string },
	quests: { Quest },
	daily: { number },
	weekly: { days: number, reward: number },
	sanitize: (record: any) -> P,
}

MetaRules.MAX_LEVEL = 50
MetaRules.MAX_XP = 1_000_000
MetaRules.MAX_COINS = 10_000_000
MetaRules.MAX_COUNT = 1_000_000

local function meta(profile: any): Meta
	return profile :: Meta
end

-- Days and weeks -----------------------------------------------------------------------------

function MetaRules.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

-- Weeks start on Monday (UTC day 0, 1 Jan 1970, was a Thursday).
function MetaRules.weekOf(day: number): number
	return math.floor((day + 3) / 7)
end

-- Levels and sanitising ----------------------------------------------------------------------

function MetaRules.levelFor(xp: number): number
	return math.min(MetaRules.MAX_LEVEL, math.floor(math.sqrt(math.max(xp, 0) / 40)) + 1)
end

-- Total XP needed to reach `level`.
function MetaRules.xpForLevel(level: number): number
	return 40 * (level - 1) ^ 2
end

function MetaRules.count(value: any, cap: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, cap)
end

function MetaRules.dayNumber(value: any): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return -1
	end
	return math.max(-1, math.floor(value))
end

function MetaRules.cosmetic<P>(config: Config<P>, id: string): Cosmetic?
	for _, c in config.cosmetics do
		if c.id == id then
			return c
		end
	end
	return nil
end

function MetaRules.isUnlocked<P>(config: Config<P>, profile: P, id: string): boolean
	local c = MetaRules.cosmetic(config, id)
	if c == nil then
		return false
	end
	local m = meta(profile)
	if c.price then
		return m.owned[id] == true
	end
	if c.level and MetaRules.levelFor(m.xp) < c.level then
		return false
	end
	if c.wins and m.wins < c.wins then
		return false
	end
	if c.tier and (m.bestTier or 0) < c.tier then
		return false
	end
	return true
end

function MetaRules.sanitizeMeta<P>(config: Config<P>, record: any, into: P): P
	local p = meta(into)
	if type(record) ~= "table" then
		return into
	end
	p.xp = MetaRules.count(record.xp, MetaRules.MAX_XP)
	p.coins = MetaRules.count(record.coins, MetaRules.MAX_COINS)
	p.wins = MetaRules.count(record.wins, MetaRules.MAX_COUNT)
	if type(record.owned) == "table" then
		for id, value in record.owned do
			local c = type(id) == "string" and MetaRules.cosmetic(config, id)
			if c and c.price and value == true then
				p.owned[id] = true
			end
		end
	end
	if type(record.daily) == "table" then
		p.daily =
			{ streak = MetaRules.count(record.daily.streak, 10_000), last = MetaRules.dayNumber(record.daily.last) }
	end
	if type(record.week) == "table" then
		p.week = {
			key = MetaRules.dayNumber(record.week.key),
			days = MetaRules.count(record.week.days, 7),
			lastDay = MetaRules.dayNumber(record.week.lastDay),
			claimed = record.week.claimed == true,
		}
	end
	if type(record.quests) == "table" then
		p.quests.day = MetaRules.dayNumber(record.quests.day)
		if type(record.quests.progress) == "table" then
			for stat, value in record.quests.progress do
				if type(stat) == "string" then
					p.quests.progress[stat] = MetaRules.count(value, MetaRules.MAX_COUNT)
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
	local slots = into :: any
	for slot, default in config.slots do
		local id = record[slot]
		local c = type(id) == "string" and MetaRules.cosmetic(config, id)
		slots[slot] = if c and c.slot == slot and MetaRules.isUnlocked(config, into, id) then id else default
	end
	return into
end

-- Quests -------------------------------------------------------------------------------------

-- Today's quests: three distinct picks from the pool, the same for everyone on a given day.
function MetaRules.questsFor(pool: { Quest }, today: number): { Quest }
	local picks: { Quest } = {}
	local n = #pool
	local start = (today * 7) % n
	local step = 1 + today % (n - 1)
	local used: { [number]: boolean } = {}
	local i = start
	while #picks < 3 do
		while used[i] do
			i = (i + 1) % n
		end
		used[i] = true
		table.insert(picks, pool[i + 1])
		i = (i + step) % n
	end
	return picks
end

-- Quest progress resets when the day changes.
local function questsToday(p: Meta, today: number)
	if p.quests.day ~= today then
		p.quests = { day = today, progress = {}, claimed = {} }
	end
end

function MetaRules.addProgress<P>(config: Config<P>, profile: P, today: number, deltas: { [string]: number }): P
	local out = config.sanitize(profile)
	local p = meta(out)
	questsToday(p, today)
	for stat, delta in deltas do
		p.quests.progress[stat] = (p.quests.progress[stat] or 0) + delta
	end
	return out
end

-- Logins, daily and weekly rewards -----------------------------------------------------------

-- Records that the player was online on `today`, for the weekly bonus.
function MetaRules.login<P>(config: Config<P>, profile: P, today: number): P
	local out = config.sanitize(profile)
	local p = meta(out)
	local week = MetaRules.weekOf(today)
	if p.week.key ~= week then
		p.week = { key = week, days = 0, lastDay = -1, claimed = false }
	end
	if p.week.lastDay ~= today then
		p.week.days = math.min(7, p.week.days + 1)
		p.week.lastDay = today
	end
	questsToday(p, today)
	return out
end

-- The streak day the next claim would be, or nil if today's reward is already claimed.
function MetaRules.nextDaily<P>(profile: P, today: number): number?
	local p = meta(profile)
	if p.daily.last == today then
		return nil
	end
	if p.daily.last == today - 1 then
		return p.daily.streak + 1
	end
	return 1
end

function MetaRules.dailyReward<P>(config: Config<P>, streak: number): number
	return config.daily[math.clamp(streak, 1, #config.daily)]
end

function MetaRules.claimDaily<P>(config: Config<P>, profile: P, today: number): (P, boolean, number)
	local streak = MetaRules.nextDaily(profile, today)
	if streak == nil then
		return profile, false, 0
	end
	local out = config.sanitize(profile)
	local p = meta(out)
	local reward = MetaRules.dailyReward(config, streak)
	p.daily = { streak = streak, last = today }
	p.coins = math.min(MetaRules.MAX_COINS, p.coins + reward)
	return out, true, reward
end

function MetaRules.canClaimWeekly<P>(config: Config<P>, profile: P, today: number): boolean
	local p = meta(profile)
	return p.week.key == MetaRules.weekOf(today) and p.week.days >= config.weekly.days and not p.week.claimed
end

function MetaRules.claimWeekly<P>(config: Config<P>, profile: P, today: number): (P, boolean, number)
	if not MetaRules.canClaimWeekly(config, profile, today) then
		return profile, false, 0
	end
	local out = config.sanitize(profile)
	local p = meta(out)
	p.week.claimed = true
	p.coins = math.min(MetaRules.MAX_COINS, p.coins + config.weekly.reward)
	return out, true, config.weekly.reward
end

function MetaRules.claimQuest<P>(config: Config<P>, profile: P, today: number, questId: string): (P, boolean, number)
	local quest: Quest? = nil
	for _, q in MetaRules.questsFor(config.quests, today) do
		if q.id == questId then
			quest = q
		end
	end
	local m = meta(profile)
	if quest == nil or m.quests.day ~= today or m.quests.claimed[questId] then
		return profile, false, 0
	end
	if (m.quests.progress[quest.stat] or 0) < quest.goal then
		return profile, false, 0
	end
	local out = config.sanitize(profile)
	local p = meta(out)
	p.quests.claimed[questId] = true
	p.coins = math.min(MetaRules.MAX_COINS, p.coins + quest.reward)
	return out, true, quest.reward
end

-- Cosmetics ----------------------------------------------------------------------------------

function MetaRules.buy<P>(config: Config<P>, profile: P, id: string): (P, boolean)
	local c = type(id) == "string" and MetaRules.cosmetic(config, id)
	local m = meta(profile)
	if not c or not c.price or m.owned[id] or m.coins < c.price then
		return profile, false
	end
	local out = config.sanitize(profile)
	local p = meta(out)
	p.coins -= c.price
	p.owned[id] = true
	return out, true
end

-- Equips into the cosmetic's own slot if it is unlocked; otherwise returns the profile unchanged.
function MetaRules.equip<P>(config: Config<P>, profile: P, id: string): (P, boolean)
	if type(id) ~= "string" or not MetaRules.isUnlocked(config, profile, id) then
		return profile, false
	end
	local c = MetaRules.cosmetic(config, id) :: Cosmetic
	local out = config.sanitize(profile);
	(out :: any)[c.slot] = id
	return out, true
end

return MetaRules
