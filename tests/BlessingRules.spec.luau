--!strict
local T = require("./framework")
local BlessingRules = require("../src/shared/BlessingRules")
local Rng = require("../src/shared/Rng")

local describe, it, expect = T.describe, T.it, T.expect

describe("BlessingRules offers", function()
	it("offers 3 distinct ids, the same for the same seed", function()
		for seed = 1, 100 do
			local offer = BlessingRules.offer({}, 2, Rng.seed(seed, 1, 3))
			expect(#offer).toBe(3)
			expect(offer[1] ~= offer[2] and offer[2] ~= offer[3] and offer[1] ~= offer[3]).toBe(true)
			local again = BlessingRules.offer({}, 2, Rng.seed(seed, 1, 3))
			expect(table.concat(offer, ",")).toBe(table.concat(again, ","))
		end
	end)

	it("excludes maxed and, solo, party-only blessings", function()
		local stacks = { edge = 3, foxfire = 1, swift = 1 }
		local solo = BlessingRules.eligible(stacks, 1)
		expect(table.find(solo, "edge")).toBeNil()
		expect(table.find(solo, "foxfire")).toBeNil()
		expect(table.find(solo, "link")).toBeNil()
		expect(table.find(solo, "swift") ~= nil).toBe(true)
		expect(table.find(BlessingRules.eligible(stacks, 2), "link") ~= nil).toBe(true)
		for seed = 1, 100 do
			for _, id in BlessingRules.offer(stacks, 1, Rng.seed(seed)) do
				expect(id ~= "edge" and id ~= "foxfire" and id ~= "link").toBe(true)
			end
		end
	end)

	it("offers every eligible one when fewer than 3 remain", function()
		local stacks = {}
		for _, b in BlessingRules.POOL do
			stacks[b.id] = b.max
		end
		stacks.iron = 2
		stacks.storm = 1
		local offer = BlessingRules.offer(stacks, 1, Rng.seed(5))
		expect(#offer).toBe(2)
		stacks.iron = 3
		stacks.storm = 2
		expect(#BlessingRules.offer(stacks, 1, Rng.seed(5))).toBe(0)
	end)

	it("lists the pool in GDD E order", function()
		expect(#BlessingRules.POOL).toBe(12)
		expect(BlessingRules.POOL[1].id).toBe("edge")
		expect(BlessingRules.POOL[12].id).toBe("link")
		expect((BlessingRules.get("link") :: BlessingRules.Blessing).party).toBe(true)
		expect(BlessingRules.get("nope")).toBeNil()
	end)
end)

describe("BlessingRules.apply", function()
	it("stacks up to max and refuses unknown ids", function()
		local s, ok = BlessingRules.apply({}, "swift")
		expect(ok).toBe(true)
		s = BlessingRules.apply(s, "swift")
		local same, full = BlessingRules.apply(s, "swift")
		expect(full).toBe(false)
		expect(same.swift).toBe(2)
		local _, unknown = BlessingRules.apply(s, "nope")
		expect(unknown).toBe(false)
	end)

	it("does not change the input", function()
		local before = { edge = 1 }
		BlessingRules.apply(before, "edge")
		expect(before.edge).toBe(1)
	end)
end)

describe("BlessingRules.modifiers", function()
	it("has the base values with no blessings", function()
		local m = BlessingRules.modifiers({})
		expect(m.damageMult).toBe(1)
		expect(m.maxHp).toBe(100)
		expect(m.charms).toBe(1)
		expect(m.risingCooldown).toBe(5)
		expect(m.triggerDuration).toBe(8)
		expect(m.foxfire or m.shockwave or m.link).toBe(false)
	end)

	it("follows every E formula", function()
		local m = BlessingRules.modifiers({
			edge = 3,
			swift = 2,
			iron = 3,
			foxfire = 1,
			thunder = 2,
			lantern = 2,
			hunger = 2,
			longnight = 2,
			ninetails = 1,
			storm = 1,
			shockwave = 1,
			link = 1,
		})
		expect(math.abs(m.damageMult - 1.36) < 1e-9).toBe(true)
		expect(math.abs(m.speedMult - 1.2) < 1e-9).toBe(true)
		expect(m.maxHp).toBe(160)
		expect(math.abs(m.gaugeRate - 1.6) < 1e-9).toBe(true)
		expect(m.triggerDuration).toBe(14)
		expect(m.charms).toBe(2)
		expect(m.risingCooldown).toBe(3.5)
		expect(m.healOnKill).toBe(6)
		expect(m.thunderDamage).toBe(30)
		expect(m.foxfire and m.shockwave and m.link).toBe(true)
	end)

	it("floors the Rising Slash cooldown at 2 s", function()
		expect(BlessingRules.modifiers({ storm = 2 }).risingCooldown).toBe(2)
		expect(BlessingRules.modifiers({ storm = 5 }).risingCooldown).toBe(2)
	end)
end)
