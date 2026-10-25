--!strict
local T = require("./framework")
local CombatRules = require("../src/shared/CombatRules")

local describe, it, expect = T.describe, T.it, T.expect

local ORIGIN = { x = 0, y = 0, z = 0 }
local NORTH = { x = 0, y = 0, z = -1 }

local function target(x: number, z: number, radius: number?, y: number?): CombatRules.Target
	return { id = 1, pos = { x = x, y = y or 0, z = z }, radius = radius or 0, mult = 1 }
end

-- A target `dist` studs away at `deg` degrees off north.
local function at(deg: number, dist: number, radius: number?): CombatRules.Target
	local r = math.rad(deg)
	return target(math.sin(r) * dist, -math.cos(r) * dist, radius)
end

describe("CombatRules weapons", function()
	it("has the C1 table, katana first", function()
		expect(CombatRules.WEAPONS[1].id).toBe("katana")
		local k = CombatRules.weapon("kodachi") :: CombatRules.Weapon
		expect(#k.damage).toBe(5)
		expect(k.level).toBe(6)
		expect((CombatRules.weapon("nodachi") :: CombatRules.Weapon).range).toBe(11)
		expect(CombatRules.weapon("spear")).toBeNil()
	end)
end)

describe("CombatRules combo (C1)", function()
	it("starts at step 1 and chains inside the window", function()
		local f = CombatRules.newFighter("katana")
		local ok, f1, step = CombatRules.attack(f, 10)
		expect(ok).toBe(true)
		expect(step).toBe(1)
		expect(f.step).toBe(0)
		local _, f2, step2 = CombatRules.attack(f1, 10.32)
		expect(step2).toBe(2)
		local _, f3, step3 = CombatRules.attack(f2, 10.32 + 0.69)
		expect(step3).toBe(3)
		expect(CombatRules.isFinisher(f3)).toBe(true)
		expect(CombatRules.isFinisher(f2)).toBe(false)
	end)

	it("refuses an attack before the interval", function()
		local _, f1 = CombatRules.attack(CombatRules.newFighter("katana"), 10)
		local ok, same, step = CombatRules.attack(f1, 10.31)
		expect(ok).toBe(false)
		expect(step).toBe(0)
		expect(same.step).toBe(1)
	end)

	it("restarts at step 1 after the window", function()
		local _, f1 = CombatRules.attack(CombatRules.newFighter("katana"), 10)
		local ok, _, step = CombatRules.attack(f1, 10.71)
		expect(ok).toBe(true)
		expect(step).toBe(1)
	end)

	it("waits for recovery after the finisher, then resets", function()
		local f = CombatRules.newFighter("nodachi")
		_, f = CombatRules.attack(f, 0)
		_, f = CombatRules.attack(f, 0.6)
		expect(CombatRules.isFinisher(f)).toBe(true)
		local early = CombatRules.attack(f, 0.6 + 0.59)
		expect(early).toBe(false)
		local ok, _, step = CombatRules.attack(f, 0.6 + 0.61)
		expect(ok).toBe(true)
		expect(step).toBe(1)
	end)
end)

describe("CombatRules hit test (C2)", function()
	local swing = CombatRules.attackSwing(CombatRules.WEAPONS[1]) -- range 8, arc 110

	it("hits inside the arc and misses just outside it", function()
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(54, 5), swing)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(-54, 5), swing)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(56, 5), swing)).toBe(false)
	end)

	it("measures range to the target's edge", function()
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(0, 8), swing)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(0, 8.1), swing)).toBe(false)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(0, 11, 3.5), swing)).toBe(true)
	end)

	it("hits point blank at any angle", function()
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(180, 1), swing)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(180, 3, 2), swing)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(180, 1.1), swing)).toBe(false)
	end)

	it("applies the vertical band (6, 8 for the skill)", function()
		expect(CombatRules.inSwing(ORIGIN, NORTH, target(0, -4, 0, 6), swing)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, target(0, -4, 0, 6.1), swing)).toBe(false)
		local skill = CombatRules.skillSwing(false)
		expect(CombatRules.inSwing(ORIGIN, NORTH, target(0, -4, 0, 8), skill)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, target(0, -4, 0, 8.1), skill)).toBe(false)
	end)

	it("ignores the facing's vertical part and the shockwave hits all around", function()
		local up = { x = 0, y = 5, z = -1 }
		expect(CombatRules.inSwing(ORIGIN, up, at(0, 5), swing)).toBe(true)
		local wave = CombatRules.skillSwing(true)
		expect(wave.range).toBe(10)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(180, 10), wave)).toBe(true)
		expect(CombatRules.inSwing(ORIGIN, NORTH, at(180, 10.1), wave)).toBe(false)
	end)

	it("cleaves, in input order, one hit per id with the highest mult", function()
		local a = { id = 1, pos = { x = 0, y = 0, z = -3 }, radius = 1, mult = 1 }
		local b = { id = 2, pos = { x = 0, y = 0, z = -5 }, radius = 1, mult = 1 }
		local hand = { id = 3, pos = { x = 1, y = 0, z = -4 }, radius = 6, mult = 1.0 }
		local skull = { id = 3, pos = { x = 0, y = 0, z = -6 }, radius = 9, mult = 1.5 }
		local miss = { id = 4, pos = { x = 0, y = 0, z = 30 }, radius = 1, mult = 1 }
		local list = CombatRules.hits(ORIGIN, NORTH, { a, hand, b, skull, miss }, swing)
		expect(#list).toBe(3)
		expect(list[1].id).toBe(1)
		expect(list[2].id).toBe(3)
		expect(list[2].mult).toBe(1.5)
		expect(list[3].id).toBe(2)
	end)
end)

describe("CombatRules damage (C6)", function()
	it("rounds each multiplier combination", function()
		expect(CombatRules.damage(12, 1, false, false, 1)).toBe(12)
		expect(CombatRules.damage(12, 1.12, false, false, 1)).toBe(13) -- 13.44
		expect(CombatRules.damage(12, 1, true, false, 1)).toBe(15)
		expect(CombatRules.damage(12, 1, false, true, 1)).toBe(17) -- 16.8
		expect(CombatRules.damage(12, 1, true, true, 1)).toBe(21) -- 21.0
		expect(CombatRules.damage(10, 1, false, false, 1.25)).toBe(13) -- 12.5 rounds up
		expect(CombatRules.damage(24, 1.36, true, true, 2.0)).toBe(114) -- 114.24
	end)

	it("applies the boss part multiplier last inside the round", function()
		expect(CombatRules.damage(8, 1, false, false, 1.5)).toBe(12)
		expect(CombatRules.damage(13, 1, false, false, 1.5)).toBe(20) -- 19.5
	end)
end)

describe("CombatRules gauge and Trigger (C5)", function()
	it("gains damage / 4 times rate, keeps fractions, caps at 100", function()
		local f = CombatRules.gain(CombatRules.newFighter("katana"), 13, 1.3, 0)
		expect(math.abs(f.gauge - 4.225) < 1e-9).toBe(true)
		f = CombatRules.gain(f, 1000, 1, 0)
		expect(f.gauge).toBe(100)
	end)

	it("needs a full gauge, empties it, and gains nothing while active", function()
		local f = CombatRules.newFighter("katana")
		local early = CombatRules.trigger(f, 0, 8)
		expect(early).toBe(false)
		f = CombatRules.gain(f, 400, 1, 0)
		local ok, on = CombatRules.trigger(f, 10, 8)
		expect(ok).toBe(true)
		expect(on.gauge).toBe(0)
		expect(CombatRules.triggerActive(on, 17.9)).toBe(true)
		expect(CombatRules.triggerActive(on, 18)).toBe(false)
		expect(CombatRules.gain(on, 100, 1, 12).gauge).toBe(0)
		expect(CombatRules.gain(on, 100, 1, 18).gauge).toBe(25)
		local again = CombatRules.trigger(CombatRules.gain(on, 400, 1, 18), 12, 8)
		expect(again).toBe(false)
	end)
end)

describe("CombatRules dash, skill, guard and rate limit", function()
	it("accepts a dash after 0.95 s", function()
		local _, f = CombatRules.dash(CombatRules.newFighter("katana"), 5)
		expect((CombatRules.dash(f, 5.94))).toBe(false)
		expect((CombatRules.dash(f, 5.95))).toBe(true)
	end)

	it("uses the cooldown it is given for the skill", function()
		local _, f = CombatRules.skill(CombatRules.newFighter("katana"), 0, 5)
		expect((CombatRules.skill(f, 4.9, 5))).toBe(false)
		expect((CombatRules.skill(f, 2, 2))).toBe(true)
	end)

	it("locks attacks for 1 s after a root moves more than 12 studs", function()
		local f = CombatRules.newFighter("katana")
		local a, b = { x = 0, y = 0, z = 0 }, { x = 12, y = 50, z = 0 }
		expect(CombatRules.guarded(CombatRules.guard(f, a, b, 3), 3)).toBe(false)
		local g = CombatRules.guard(f, a, { x = 12.1, y = 0, z = 0 }, 3)
		expect(CombatRules.guarded(g, 3.99)).toBe(true)
		expect(CombatRules.guarded(g, 4)).toBe(false)
	end)

	it("refuses the 21st request inside one second, counting refused ones", function()
		local f = CombatRules.newFighter("katana")
		for i = 1, 20 do
			local ok
			ok, f = CombatRules.allowRequest(f, i * 0.01)
			expect(ok).toBe(true)
		end
		local ok21
		ok21, f = CombatRules.allowRequest(f, 0.5)
		expect(ok21).toBe(false)
		expect((CombatRules.allowRequest(f, 1.005))).toBe(false)
		expect((CombatRules.allowRequest(f, 1.6))).toBe(true)
	end)
end)

describe("CombatRules reactions and contact", function()
	it("follows C7 per class", function()
		local s, k = CombatRules.reaction("normal", false, false)
		expect(s).toBe(true)
		expect(k).toBe(0)
		s, k = CombatRules.reaction("normal", true, false)
		expect(k).toBe(1)
		s, k = CombatRules.reaction("armoured", false, false)
		expect(s).toBe(false)
		s, k = CombatRules.reaction("armoured", false, true)
		expect(s).toBe(true)
		expect(k).toBe(0)
		s, k = CombatRules.reaction("armoured", true, false)
		expect(k).toBe(0.3)
		s, k = CombatRules.reaction("boss", true, true)
		expect(s).toBe(false)
		expect(k).toBe(0)
		expect(CombatRules.canLaunch("normal")).toBe(true)
		expect(CombatRules.canLaunch("armoured")).toBe(false)
	end)

	it("checks contact reach and band (C8)", function()
		local e = { x = 0, y = 0, z = 0 }
		expect(CombatRules.contact(e, 1.5, { x = 4, y = 5, z = 0 })).toBe(true)
		expect(CombatRules.contact(e, 1.5, { x = 4.1, y = 0, z = 0 })).toBe(false)
		expect(CombatRules.contact(e, 1.5, { x = 0, y = 5.1, z = 0 })).toBe(false)
	end)

	it("measures horizontal distance to a segment", function()
		local a, b = { x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }
		expect(CombatRules.nearSegment(a, b, { x = 5, y = 9, z = 3 }, 3)).toBe(true)
		expect(CombatRules.nearSegment(a, b, { x = 5, y = 0, z = 3.1 }, 3)).toBe(false)
		expect(CombatRules.nearSegment(a, b, { x = 12, y = 0, z = 0 }, 3)).toBe(true)
		expect(CombatRules.nearSegment(a, b, { x = 13.1, y = 0, z = 0 }, 3)).toBe(false)
		expect(CombatRules.nearSegment(a, a, { x = 0, y = 0, z = 2 }, 2)).toBe(true)
		expect(CombatRules.flatDistance(a, { x = 3, y = 100, z = 4 })).toBe(5)
	end)
end)
