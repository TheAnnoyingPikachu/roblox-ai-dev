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
			elseif stage % StationGoals.BOSS_EGG_EVERY == 0 then { egg = "best" }
			else { pays = 6, samples = 2 * stage },
	})
end
StationGoals.LIST = list

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
