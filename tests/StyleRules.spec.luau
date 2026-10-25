--!strict
local T = require("./framework")
local StyleRules = require("../src/shared/StyleRules")

local describe, it, expect = T.describe, T.it, T.expect

describe("StyleRules.add", function()
	it("adds the event's points", function()
		local s = StyleRules.add(StyleRules.new(), "dash")
		expect(s.points).toBe(10)
	end)

	it("pays less for repeating the same move in a row", function()
		local s = StyleRules.new()
		s = StyleRules.add(s, "dash") -- 10
		s = StyleRules.add(s, "dash") -- +5
		s = StyleRules.add(s, "dash") -- +10/3
		expect(math.abs(s.points - (10 + 5 + 10 / 3)) < 1e-9).toBe(true)
	end)

	it("restores full value after a different move", function()
		local s = StyleRules.new()
		s = StyleRules.add(s, "dash")
		s = StyleRules.add(s, "dash")
		s = StyleRules.add(s, "launch")
		expect(s.points).toBe(10 + 5 + 14)
		expect(s.streak).toBe(0)
	end)

	it("ignores unknown events", function()
		local s = StyleRules.add(StyleRules.new(), "teleport")
		expect(s.points).toBe(0)
	end)

	it("caps at MAX", function()
		local s = { points = StyleRules.MAX - 1, last = nil, streak = 0 }
		expect(StyleRules.add(s, "legClear").points).toBe(StyleRules.MAX)
		expect(StyleRules.airtime(s, 10).points).toBe(StyleRules.MAX)
	end)

	it("does not change the input state", function()
		local s = StyleRules.new()
		StyleRules.add(s, "dash")
		expect(s.points).toBe(0)
	end)
end)

describe("StyleRules.decay and reset", function()
	it("decays over time and never below zero", function()
		local s = { points = 10, last = nil, streak = 0 }
		expect(StyleRules.decay(s, 1).points).toBe(10 - StyleRules.DECAY)
		expect(StyleRules.decay(s, 100).points).toBe(0)
	end)

	it("reset empties the meter", function()
		expect(StyleRules.reset().points).toBe(0)
	end)
end)

describe("StyleRules.rank", function()
	it("maps points to the D..SSS ladder at the thresholds", function()
		expect(StyleRules.RANKS[StyleRules.rank(0)].letter).toBe("D")
		expect(StyleRules.RANKS[StyleRules.rank(19.9)].letter).toBe("D")
		expect(StyleRules.RANKS[StyleRules.rank(20)].letter).toBe("C")
		expect(StyleRules.RANKS[StyleRules.rank(110)].letter).toBe("S")
		expect(StyleRules.RANKS[StyleRules.rank(StyleRules.MAX)].letter).toBe("SSS")
	end)
end)
