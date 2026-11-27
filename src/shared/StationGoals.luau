--!strict
-- Animal Stations goals (decision 0115): one goal is always on screen with what it pays (the strip at the
-- top of the HUD). The goals come in a fixed order and the first one a save has not finished is "the goal":
-- the early ones teach the game, then every stage's boss is one. Pure rules, no Roblox APIs: the server
-- pays a goal the moment the save shows it reached, through StationRewards (coins in wave pays, so a goal
-- is worth the same at any point of the game), and the HUD draws the strip from the same functions.

local LevelRules = require("./LevelRules")
local StationConfig = require("./StationConfig")
local StationProgress = require("./StationProgress")
local StationRewards = require("./StationRewards")
local StationRules = require("./StationRules")

local StationGoals = {}

type Profile = StationProgress.Profile
export type Goal = {
	id: string, -- kept in the save: 16 characters at most, never reused
	text: string,
	of: number, -- how many it takes
	from: number?, -- a boss goal counts waves from here ("wave 27 of 30")
	count: (p: Profile) -> number,
	reward: StationRewards.Spec,
}

local function trainedLevels(p: Profile): number
	local n = 0
	for _, a in p.animals do
		for _, stat in StationConfig.STATS do
			n += math.max(0, StationRules.level(a :: any, stat) - 1)
		end
	end
	return n
end

StationGoals.BOSS_EGG_EVERY = 5 -- every fifth stage's boss pays the best egg the player has unlocked

-- Teaching goals (decision 0123, build 4 A): woven in after a stage's boss, each shows one thing the game has
-- that the waves never ask for. By the stage they follow.
local function one(x: boolean): number
	return if x then 1 else 0
end
local TEACH: { [number]: { Goal } } = {
	[1] = {
		{
			id = "barn",
			text = "Upgrade your Barn",
			of = 1,
			count = function(p)
				return one((p.upgrades.barn or 0) >= 1)
			end,
			reward = { pays = 3 },
		},
		{
			id = "mill",
			text = "Build the Windmill",
			of = 1,
			count = function(p)
				return one((p.upgrades.windmill or 0) >= 1)
			end,
			reward = { samples = 5 },
		},
	},
	[2] = {
		{
			id = "titan",
			text = "Put a Titan in its slot",
			of = 1,
			count = function(p)
				return one(p.titan ~= nil)
			end,
			reward = { pays = 4, samples = 4 },
		},
	},
	[3] = {
		{
			id = "coat",
			text = "Own an animal with a coat",
			of = 1,
			count = function(p)
				for _, a in p.animals do
					if StationProgress.coatTier(a) >= 1 then
						return 1
					end
				end
				return 0
			end,
			reward = { pays = 5 },
		},
	},
	[5] = {
		{
			id = "fuse",
			text = "Fuse four of a coat into a better one",
			of = 1,
			count = function(p)
				for _, a in p.animals do
					if StationProgress.coatTier(a) >= 2 then
						return 1
					end
				end
				return 0
			end,
			reward = { egg = "best" },
		},
	},
}
local list: { Goal } = {
	{
		id = "team",
		text = "Hatch a team of three",
		of = 3,
		count = function(p)
			return #p.animals
		end,
		reward = { pays = 2 },
	},
	{
		id = "wave3",
		text = "Clear wave 3",
		of = 3,
		count = function(p)
			return p.best
		end,
		reward = { pays = 4 },
	},
	{ id = "train", text = "Train a stat up a level", of = 1, count = trainedLevels, reward = { egg = "wild" } },
	{
		id = "gift",
		text = "Open one of today's gifts",
		of = 1,
		count = function(p)
			return p.rewards.weekGot + #p.rewards.monthGot + (if p.rewards.spinDay > 0 then 1 else 0)
		end,
		reward = { samples = 3 },
	},
}
for stage = 1, LevelRules.LAST // LevelRules.BOSS_EVERY do
	local wave = stage * LevelRules.BOSS_EVERY
	local from = wave - LevelRules.BOSS_EVERY
	table.insert(list, {
		id = `boss{wave}`,
		text = `Beat the wave {wave} boss`,
		of = LevelRules.BOSS_EVERY,
		from = from,
		count = function(p)
			return p.best - from
		end,
		reward = if stage == 1
			then { egg = "safari" } -- the first boss: a taste of the egg after the next
			elseif stage == 2 then { animal = "elephant" } -- the first Titan, guaranteed (decision 0121)
			elseif stage % StationGoals.BOSS_EGG_EVERY == 0 then { egg = "best" }
			else { pays = 6, samples = 2 * stage },
	})
	for _, goal in TEACH[stage] or {} do
		table.insert(list, goal)
	end
end
StationGoals.LIST = list

-- A reward every LEVEL_EVERY player levels up to LEVEL_TOP (decision 0123, build 4 A): wave pays and samples,
-- the best egg on every tenth. Kept in the save's goals list as "lvl5", "lvl10"..., paid as soon as reached.
StationGoals.LEVEL_EVERY, StationGoals.LEVEL_TOP = 5, 100
local levels: { Goal } = {}
for level = StationGoals.LEVEL_EVERY, StationGoals.LEVEL_TOP, StationGoals.LEVEL_EVERY do
	table.insert(levels, {
		id = `lvl{level}`,
		text = `Reach player level {level}`,
		of = level,
		count = function(p)
			return StationProgress.playerLevel(p)
		end,
		reward = if level % 10 == 0 then { egg = "best" } else { pays = 4, samples = level // 5 * 2 },
	})
end
StationGoals.LEVELS = levels

-- The level reward `p` has reached and not been paid, the lowest first; nil when none.
function StationGoals.levelDue(p: Profile): Goal?
	for _, goal in levels do
		if table.find(p.goals, goal.id) == nil and goal.count(p) >= goal.of then
			return goal
		end
	end
	return nil
end

-- The goal `p` is on: the first it has not finished (nil once every goal is done).
function StationGoals.next(p: Profile): Goal?
	for _, goal in list do
		if table.find(p.goals, goal.id) == nil then
			return goal
		end
	end
	return nil
end

-- How far `p` is on `goal`: done so far (never more than it takes) and how many it takes.
function StationGoals.progress(p: Profile, goal: Goal): (number, number)
	return math.clamp(goal.count(p), 0, goal.of), goal.of
end

-- The strip's small print: "2 of 3", or "wave 27 of 30" for a boss.
function StationGoals.label(p: Profile, goal: Goal): string
	local done, of = StationGoals.progress(p, goal)
	return if goal.from then `wave {goal.from + done} of {goal.from + of}` else `{done} of {of}`
end

-- The goal `p` is on, if it has reached it: the server pays it now.
function StationGoals.due(p: Profile): Goal?
	local goal = StationGoals.next(p)
	return if goal and goal.count(p) >= goal.of then goal else nil
end

-- What `goal` pays `p` right now.
function StationGoals.items(p: Profile, goal: Goal): StationRewards.Items
	return StationRewards.resolve(p, goal.reward)
end

-- Finish the goal `id`: it must be the one `p` is on and reached. `items` is what it pays (`items`, worked
-- out before the change) and `animals` the animals inside its eggs, so the change can run twice.
function StationGoals.finish(
	p: Profile,
	id: string,
	items: StationRewards.Items,
	animals: { StationRules.Owned },
	now: number
): (Profile, boolean, string?)
	local goal = StationGoals.due(p)
	if goal == nil or goal.id ~= id then
		goal = StationGoals.levelDue(p) -- or a level reward
	end
	if goal == nil or goal.id ~= id then
		return p, false, "goal"
	end
	local _, ok, code = StationRewards.grant(p, items, animals, nil, now)
	if not ok then
		return p, false, code
	end
	table.insert(p.goals, id)
	return p, true, nil
end

return StationGoals
