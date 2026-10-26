--!strict
local T = require("./framework")
local Rng = require("../src/shared/Rng")
local WaveRules = require("../src/shared/WaveRules")

local describe, it, expect = T.describe, T.it, T.expect

local ORIGIN = { x = 0, y = 0, z = 0 }

describe("WaveRules composition (D4)", function()
	it("sums to the budget B for waves 2-9, n 1-6, 50 seeds", function()
		for w = 2, 9 do
			if w ~= 5 then
				for n = 1, 6 do
					local b = WaveRules.budget(w, n)
					expect(b).toBe(math.floor(WaveRules.BASE_BUDGET[w] * (1 + 0.6 * (n - 1)) + 0.5 + 1e-9))
					for seed = 1, 50 do
						local total = 0
						for _, s in WaveRules.composition(w, n, Rng.seed(seed, 0, w)) do
							total += WaveRules.ENEMIES[s.kind].cost
						end
						expect(total).toBe(b)
					end
				end
			end
		end
	end)

	it("has the D4 budgets and none for waves 1, 5 and 10", function()
		expect(WaveRules.budget(2, 1)).toBe(8)
		expect(WaveRules.budget(2, 6)).toBe(32)
		expect(WaveRules.budget(9, 2)).toBe(45) -- 44.8
		expect(WaveRules.budget(1, 3)).toBe(0)
		expect(WaveRules.budget(5, 3)).toBe(0)
		expect(WaveRules.budget(10, 3)).toBe(0)
	end)

	it("starts intro waves with the new type", function()
		for seed = 1, 50 do
			for w, kind in WaveRules.INTRO do
				expect(WaveRules.composition(w, 1, Rng.seed(seed, 0, w))[1].kind).toBe(kind)
			end
		end
	end)

	it("uses only allowed types and keeps the oni cap", function()
		for w = 2, 9 do
			for n = 1, 6 do
				local allowed = {}
				for _, kind in WaveRules.allowed(w) do
					allowed[kind] = true
				end
				for seed = 1, 50 do
					local onis = 0
					for _, s in WaveRules.composition(w, n, Rng.seed(seed, 0, w)) do
						expect(allowed[s.kind]).toBe(true)
						expect(s.speedMult).toBe(1)
						if s.kind == "oni" then
							onis += 1
						end
					end
					expect(onis <= WaveRules.oniCap(w, n)).toBe(true)
				end
			end
		end
		expect(WaveRules.oniCap(4, 1)).toBe(1)
		expect(WaveRules.oniCap(9, 6)).toBe(5)
	end)

	it("is deterministic per seed", function()
		local a = WaveRules.composition(7, 3, Rng.seed(42, 0, 7))
		local b = WaveRules.composition(7, 3, Rng.seed(42, 0, 7))
		expect(#a).toBe(#b)
		for i, s in a do
			expect(s.kind).toBe(b[i].kind)
		end
	end)

	it("sends 6 + 3(n - 1) slow wisps in wave 1 and the bosses alone", function()
		local one = WaveRules.composition(1, 1, Rng.seed(1))
		expect(#one).toBe(6)
		expect(one[1].kind).toBe("wisp")
		expect(one[1].speedMult).toBe(WaveRules.TUTORIAL_SPEED)
		expect(#WaveRules.composition(1, 6, Rng.seed(1))).toBe(21)
		local five = WaveRules.composition(5, 4, Rng.seed(1))
		expect(#five).toBe(1)
		expect(five[1].kind).toBe("general")
		expect(WaveRules.composition(10, 4, Rng.seed(1))[1].kind).toBe("boss")
	end)

	it("lists allowed types per wave", function()
		expect(#WaveRules.allowed(1)).toBe(1)
		expect(#WaveRules.allowed(2)).toBe(2)
		expect(WaveRules.allowed(3)[3]).toBe("kasa")
		expect(WaveRules.allowed(4)[4]).toBe("oni")
		expect(#WaveRules.allowed(9)).toBe(4)
	end)
end)

describe("WaveRules gates and caps", function()
	it("opens 1, 2, then 4 gates and rotates spawns through them", function()
		expect(WaveRules.gatesOpen(1)).toBe(1)
		expect(WaveRules.gatesOpen(2)).toBe(2)
		expect(WaveRules.gatesOpen(3)).toBe(2)
		expect(WaveRules.gatesOpen(4)).toBe(4)
		expect(WaveRules.gatesOpen(10)).toBe(4)
		local order = {}
		for i = 1, 6 do
			table.insert(order, WaveRules.gateFor(i, 4))
		end
		expect(table.concat(order, ",")).toBe("1,2,3,4,1,2")
		expect(WaveRules.gateFor(3, 2)).toBe(1)
		expect(WaveRules.gateFor(7, 1)).toBe(1)
	end)

	it("puts gate 1 south-east and gate 2 opposite it", function()
		expect(WaveRules.GATES[1].x).toBe(60)
		expect(WaveRules.GATES[1].z).toBe(60)
		expect(WaveRules.GATES[2].x).toBe(-60)
		expect(WaveRules.nearestGate({ x = -50, y = 0, z = 40 })).toBe(4)
		expect(WaveRules.nearestGate(ORIGIN)).toBe(1)
	end)

	it("caps alive enemies at 12 + 4(n - 1)", function()
		expect(WaveRules.aliveCap(1)).toBe(12)
		expect(WaveRules.aliveCap(6)).toBe(32)
	end)
end)

describe("WaveRules scaling (D5)", function()
	it("scales regular HP at n = 1, 6 and t = 1, 5", function()
		expect(WaveRules.hp("wisp", 1, 1)).toBe(24)
		expect(WaveRules.hp("wisp", 6, 1)).toBe(42)
		expect(WaveRules.hp("wisp", 1, 5)).toBe(58) -- 57.6
		expect(WaveRules.hp("wisp", 6, 5)).toBe(101) -- 100.8
		expect(WaveRules.hp("oni", 6, 5)).toBe(672)
	end)

	it("scales the general and the boss harder with party size", function()
		expect(WaveRules.hp("general", 1, 1)).toBe(900)
		expect(WaveRules.hp("general", 6, 1)).toBe(4275)
		expect(WaveRules.hp("boss", 6, 5)).toBe(34200)
		expect(WaveRules.hp("boss", 1, 5)).toBe(7200)
	end)

	it("scales damage by tier only", function()
		expect(WaveRules.damage(6, 1)).toBe(6)
		expect(WaveRules.damage(6, 5)).toBe(11) -- 10.8
		expect(WaveRules.damage(12, 5)).toBe(22) -- 21.6
		expect(WaveRules.damage(30, 3)).toBe(42)
		expect(WaveRules.damage(0, 5)).toBe(0)
	end)

	it("builds an enemy record with scaled stats", function()
		local e = WaveRules.newEnemy(7, "oni", 1, 5, ORIGIN, 100, nil, 3)
		expect(e.hp).toBe(384)
		expect(e.maxHp).toBe(384)
		expect(e.contact).toBe(11)
		expect(e.attack).toBe(45)
		expect(e.class).toBe("armoured")
		expect(e.owner).toBe(3)
		expect(WaveRules.newEnemy(8, "wisp", 1, 1, ORIGIN, 0, 0.7).speed).toBe(14 * 0.7)
	end)
end)

describe("WaveRules targeting (D2)", function()
	it("picks the nearest candidate horizontally, ties to the earlier one", function()
		local list = {
			{ userId = 10, pos = { x = 5, y = 0, z = 0 } },
			{ userId = 11, pos = { x = 0, y = 0, z = -5 } },
			{ userId = 12, pos = { x = 0, y = 40, z = 4 } },
		}
		expect(WaveRules.pickTarget(ORIGIN, list)).toBe(12)
		table.remove(list, 3)
		expect(WaveRules.pickTarget(ORIGIN, list)).toBe(10)
		expect(WaveRules.pickTarget(ORIGIN, {})).toBeNil()
	end)

	it("can't act while staggered or airborne, and is stuck after 20 s away", function()
		local e = WaveRules.newEnemy(1, "wisp", 1, 1, ORIGIN, 0)
		expect(WaveRules.canAct(e, 1)).toBe(true)
		e.staggerUntil = 1.4
		expect(WaveRules.canAct(e, 1)).toBe(false)
		e.staggerUntil, e.airborneUntil = 0, 2.2
		expect(WaveRules.canAct(e, 2)).toBe(false)
		expect(WaveRules.canAct(e, 2.2)).toBe(true)
		expect(WaveRules.isStuck(e, 19.9)).toBe(false)
		expect(WaveRules.isStuck(e, 20)).toBe(true)
	end)
end)
