--!strict
local T = require("./framework")
local BossRules = require("../src/shared/BossRules")

local describe, it, expect = T.describe, T.it, T.expect

local MAX = 3000

-- Runs the boss from `s` at `hp`, resolving each attack at once, and lists what it does.
local function play(s: BossRules.State, hp: number, count: number, t: number): ({ string }, BossRules.State, number)
	local seen = {}
	for _ = 1, count do
		t = math.max(t, s.nextAt)
		local attack
		attack, s = BossRules.next(s, hp, MAX, t)
		table.insert(seen, attack :: string)
		s = BossRules.resolved(s, attack :: string, t)
	end
	return seen, s, t
end

describe("BossRules phases", function()
	it("splits at 66% and 33%", function()
		expect(BossRules.phaseFor(3000, MAX)).toBe(1)
		expect(BossRules.phaseFor(1981, MAX)).toBe(1)
		expect(BossRules.phaseFor(1980, MAX)).toBe(2)
		expect(BossRules.phaseFor(990, MAX)).toBe(2)
		expect(BossRules.phaseFor(989, MAX)).toBe(3)
		expect(BossRules.phaseFor(0, MAX)).toBe(3)
	end)
end)

describe("BossRules attacks", function()
	it("waits 3 s after rising, then loops phase 1 in order", function()
		local s = BossRules.new(100)
		expect((BossRules.next(s, MAX, MAX, 102.9))).toBeNil()
		local seen = play(s, MAX, 6, 103)
		expect(table.concat(seen, ",")).toBe("slam,slam,sweep,slam,slam,sweep")
	end)

	it("summons once on entering phase 2, then runs its sequence from the start", function()
		local _, s, t = play(BossRules.new(0), MAX, 1, 3) -- one slam into phase 1
		local seen = play(s, 1500, 5, t)
		expect(table.concat(seen, ",")).toBe("summon,slam,sweep,slam,slam")
	end)

	it("summons again on entering phase 3, and once when a phase is skipped", function()
		local _, s, t = play(BossRules.new(0), 1500, 2, 3)
		local seen = play(s, 500, 4, t)
		expect(table.concat(seen, ",")).toBe("summon,double,sweep,sweep")
		local skipped = play(BossRules.new(0), 100, 4, 3)
		expect(table.concat(skipped, ",")).toBe("summon,double,sweep,sweep")
	end)

	it("holds the next attack until the current one resolves", function()
		local attack, s = BossRules.next(BossRules.new(0), MAX, MAX, 3)
		expect(attack).toBe("slam")
		expect((BossRules.next(s, MAX, MAX, 50))).toBeNil()
	end)

	it("staggers the skull 4 s after a slam and waits max(gap, stagger)", function()
		local _, s = BossRules.next(BossRules.new(0), MAX, MAX, 3)
		s = BossRules.resolved(s, "slam", 10)
		expect(BossRules.staggered(s, 13.9)).toBe(true)
		expect(BossRules.staggered(s, 14)).toBe(false)
		expect(s.nextAt).toBe(14)
		s = BossRules.resolved(s, "sweep", 20)
		expect(s.nextAt).toBe(22.5)
		expect(BossRules.staggered(s, 20)).toBe(false)
		s = BossRules.resolved(s, "double", 30)
		expect(s.staggerUntil).toBe(34)
	end)
end)

describe("BossRules parts and targets", function()
	it("multiplies hands x1.0, skull x1.5, staggered skull x2.0", function()
		expect(BossRules.partMult("hand", false)).toBe(1.0)
		expect(BossRules.partMult("hand", true)).toBe(1.0)
		expect(BossRules.partMult("skull", false)).toBe(1.5)
		expect(BossRules.partMult("skull", true)).toBe(2.0)
	end)

	it("rotates targets round robin, distinct when there are enough", function()
		local s = BossRules.new(0)
		local a, b, c
		a, s = BossRules.targets(s, { 1, 2, 3 }, 1)
		b, s = BossRules.targets(s, { 1, 2, 3 }, 2)
		c, s = BossRules.targets(s, { 1, 2, 3 }, 1)
		expect(a[1]).toBe(1)
		expect(b[1]).toBe(2)
		expect(b[2]).toBe(3)
		expect(c[1]).toBe(1)
		local solo = BossRules.targets(s, { 9 }, 2)
		expect(solo[1]).toBe(9)
		expect(solo[2]).toBe(9)
		expect(#BossRules.targets(s, {}, 2)).toBe(0)
	end)

	it("sweeps west to east at the target's z and misses jumpers", function()
		local a, b = BossRules.sweepLine({ x = 20, y = 3, z = -15 })
		expect(a.x < b.x).toBe(true)
		expect(a.z).toBe(-15)
		expect(b.z).toBe(-15)
		expect(BossRules.sweepHit(a, b, { x = 20, y = 0, z = -11 }, 3.9)).toBe(true)
		expect(BossRules.sweepHit(a, b, { x = 20, y = 0, z = -11 }, 4)).toBe(false)
		expect(BossRules.sweepHit(a, b, { x = 20, y = 0, z = -10.9 }, 0)).toBe(false)
	end)
end)
