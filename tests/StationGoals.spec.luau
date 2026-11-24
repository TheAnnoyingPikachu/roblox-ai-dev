--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationGoals = require("../src/shared/StationGoals")
local StationProgress = require("../src/shared/StationProgress")
local StationRewards = require("../src/shared/StationRewards")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

local function fresh(): StationProgress.Profile
	return StationProgress.defaults(0)
end

local function animalsFor(items: StationRewards.Items): { StationRules.Owned }
	local out = {}
	for _ in items.eggs do
		table.insert(out, { s = "jackal", stats = StationRules.versionStats("jackal", nil) :: StationConfig.Stats })
	end
	return out
end

-- Pay every goal `p` has reached, as the server does, and return how many that was.
local function settle(p: StationProgress.Profile): number
	local n = 0
	while true do
		local goal = StationGoals.due(p)
		if goal == nil then
			return n
		end
		local items = StationGoals.items(p, goal)
		local _, ok = StationGoals.finish(p, goal.id, items, animalsFor(items), 0)
		assert(ok, goal.id)
		n += 1
	end
end

describe("StationGoals", function()
	it("starts a new save on hatching a team, and counts its animals", function()
		local p = fresh()
		local goal = StationGoals.next(p) :: StationGoals.Goal
		expect(goal.id).toBe("team")
		expect(StationGoals.label(p, goal)).toBe("0 of 3")
		expect(StationGoals.due(p)).toBe(nil)
		for _ = 1, 2 do
			StationProgress.give(p, "jackal", nil, 1)
		end
		expect(StationGoals.label(p, goal)).toBe("2 of 3")
		expect(StationGoals.due(p)).toBe(nil)
	end)

	it("pays a reached goal once, in order, and moves on", function()
		local p = fresh()
		for _ = 1, 3 do
			StationProgress.give(p, "jackal", nil, 1)
		end
		local goal = StationGoals.due(p) :: StationGoals.Goal
		expect(goal.id).toBe("team")
		local items = StationGoals.items(p, goal)
		expect(items.coins).toBe(2 * StationRewards.wavePay(p))
		local coins = p.coins
		local _, late = StationGoals.finish(p, "wave3", items, {}, 0) -- not the goal it is on
		expect(late).toBe(false)
		local _, ok = StationGoals.finish(p, "team", items, {}, 0)
		expect(ok).toBe(true)
		expect(p.coins).toBe(coins + items.coins)
		local _, again = StationGoals.finish(p, "team", items, {}, 0)
		expect(again).toBe(false)
		expect(p.coins).toBe(coins + items.coins)
		expect((StationGoals.next(p) :: StationGoals.Goal).id).toBe("wave3")
	end)

	it("does not finish a goal that is not reached", function()
		local p = fresh()
		local goal = StationGoals.next(p) :: StationGoals.Goal
		local _, ok = StationGoals.finish(p, goal.id, StationGoals.items(p, goal), {}, 0)
		expect(ok).toBe(false)
		expect(#p.goals).toBe(0)
	end)

	it("pays training with a Wild Egg, into the egg storage", function()
		local p = fresh()
		p.goals = { "team", "wave3" }
		expect((StationGoals.next(p) :: StationGoals.Goal).id).toBe("train")
		expect(StationGoals.due(p)).toBe(nil)
		StationProgress.give(p, "jackal", nil, 2) -- one level up on every stat
		local goal = StationGoals.due(p) :: StationGoals.Goal
		local items = StationGoals.items(p, goal)
		expect(items.eggs[1]).toBe("wild")
		local _, ok = StationGoals.finish(p, goal.id, items, animalsFor(items), 0)
		expect(ok).toBe(true)
		expect(p.eggs[1].egg).toBe("wild")
	end)

	it("makes every stage's boss a goal, counted in that stage's waves", function()
		local p = fresh()
		p.goals = { "team", "wave3", "train", "gift", "boss10", "boss20" }
		p.best = 27
		local goal = StationGoals.next(p) :: StationGoals.Goal
		expect(goal.id).toBe("boss30")
		local done, of = StationGoals.progress(p, goal)
		expect(done).toBe(7)
		expect(of).toBe(10)
		expect(StationGoals.label(p, goal)).toBe("wave 27 of 30")
		p.best = 30
		expect((StationGoals.due(p) :: StationGoals.Goal).id).toBe("boss30")
		p.best = 12 -- behind the stage: never under nothing
		expect(StationGoals.label(p, goal)).toBe("wave 20 of 30")
	end)

	it("pays the first boss a Safari Egg, every fifth the best egg, the others coins and samples", function()
		local p = fresh()
		local by = {}
		for _, goal in StationGoals.LIST do
			by[goal.id] = goal
		end
		expect(StationGoals.items(p, by.boss10).eggs[1]).toBe("safari")
		expect(StationGoals.items(p, by.boss50).eggs[1]).toBe((StationRewards.bestEgg(p)))
		local items = StationGoals.items(p, by.boss20)
		expect(items.coins).toBe(6 * StationRewards.wavePay(p))
		expect(items.samples).toBe(4)
		expect(#items.eggs).toBe(0)
	end)

	it("catches a returning save up, one goal after another", function()
		local p = fresh()
		for _ = 1, 3 do
			StationProgress.give(p, "jackal", nil, 3)
		end
		p.best = 27
		p.rewards.spinDay = 20000
		expect(settle(p)).toBe(6) -- team, wave3, train, gift, boss10, boss20
		expect((StationGoals.next(p) :: StationGoals.Goal).id).toBe("boss30")
		expect(settle(p)).toBe(0)
	end)

	it("has ids a save can keep, and ends when every goal is done", function()
		local seen = {}
		local p = fresh()
		for _, goal in StationGoals.LIST do
			expect(#goal.id <= 16).toBe(true)
			expect(seen[goal.id]).toBe(nil)
			seen[goal.id] = true
			table.insert(p.goals, goal.id)
		end
		expect(#StationGoals.LIST <= StationProgress.MAX_GOALS).toBe(true)
		expect(StationGoals.next(p)).toBe(nil)
		expect(StationGoals.due(p)).toBe(nil)
		expect(#StationProgress.sanitize(p, 0).goals).toBe(#StationGoals.LIST)
	end)

	it("keeps only short, different ids when a save is read", function()
		local p = StationProgress.sanitize({ goals = { "team", "team", 7, string.rep("x", 17), "wave3" } }, 0)
		expect(#p.goals).toBe(2)
		expect(p.goals[2]).toBe("wave3")
		expect(#StationProgress.sanitize({ goals = "team" }, 0).goals).toBe(0)
	end)
end)
