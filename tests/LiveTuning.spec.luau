--!strict
local T = require("./framework")
local LevelRules = require("../src/shared/LevelRules")
local LiveTuning = require("../src/shared/LiveTuning")
local StationConfig = require("../src/shared/StationConfig")
local StationProgress = require("../src/shared/StationProgress")

local describe, it, expect = T.describe, T.it, T.expect

describe("LiveTuning (decision 0131)", function()
	it("keeps every value inside its approved range, and anything else at the default", function()
		expect(LiveTuning.clamp("replayPct", 90)).toBe(60)
		expect(LiveTuning.clamp("replayPct", 10)).toBe(25)
		expect(LiveTuning.clamp("coinBoost", 2)).toBe(2)
		expect(LiveTuning.clamp("coinBoost", "lots")).toBe(1)
		expect(LiveTuning.clamp("eggPrice", 0 / 0)).toBe(1)
		for _, k in LiveTuning.KEYS do
			expect(k.default >= k.min and k.default <= k.max).toBeTruthy()
		end
	end)

	it("applies values to the shared rules, and a missing key goes back to its default", function()
		local meadow = StationConfig.egg("meadow") :: StationConfig.Egg
		local price, pay = meadow.price, LevelRules.reward(20, 0)
		local p = StationProgress.defaults(0)
		local hatch = StationProgress.hatchSeconds(p, meadow)
		LiveTuning.apply({ replayPct = 50, coinBoost = 2, eggPrice = 1.5, hatchTime = 0.5 })
		expect(LevelRules.REPLAY_PCT).toBe(50)
		expect(LevelRules.reward(20, 0)).toBe(math.floor(LevelRules.REWARD_START * LevelRules.REWARD_GROWTH ^ 19 * 2))
		expect(meadow.price).toBe(math.floor(price * 1.5 + 0.5))
		expect(StationProgress.hatchSeconds(p, meadow)).toBe(math.ceil(hatch / 2))
		LiveTuning.apply({})
		expect(meadow.price).toBe(price)
		expect(LevelRules.reward(20, 0)).toBe(pay)
		expect(StationProgress.hatchSeconds(p, meadow)).toBe(hatch)
	end)
end)
