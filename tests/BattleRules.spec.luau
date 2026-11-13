--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local BattleRules = require("../src/shared/BattleRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

-- An animal of `role` with every stat 40, so only the role differs between them.
local SPECIES = { attack = "lion", defense = "gorilla", utility = "mandrill" }
local function role(r: string): StationRules.Owned
	return { s = SPECIES[r], stats = { speed = 40, strength = 40, stamina = 40, mana = 40 } }
end

describe("BattleRules roles", function()
	it("takes the role from the species", function()
		expect(BattleRules.fighter(owned("lion"), 1, 1).role).toBe("attack")
		expect(BattleRules.fighter(owned("gorilla"), 1, 1).role).toBe("defense")
		expect(BattleRules.fighter(owned("mandrill"), 1, 1).role).toBe("utility")
		expect(BattleRules.fighter(owned("elephant"), 1, 4).role).toBe("titan")
	end)

	it("makes Attack hit harder than the same stats in another role", function()
		local atk = BattleRules.fighter(role("attack"), 1, 1)
		local util = BattleRules.fighter(role("utility"), 1, 1)
		expect(atk.atk > util.atk).toBeTruthy()
		expect(atk.maxHp).toBe(util.maxHp)
	end)
end)

describe("BattleRules.battle", function()
	it("loses with no team, and side 1 wins a mirror match on speed ties", function()
		expect((BattleRules.battle({}, { owned("jackal") }))).toBe(false)
		local team = { owned("jackal"), owned("warthog"), owned("meerkat") }
		expect((BattleRules.battle(team, { owned("jackal"), owned("warthog"), owned("meerkat") }))).toBe(true)
	end)

	it("is rock paper scissors between equal animals, from either side", function()
		for _, a in StationConfig.ROLES do
			local d = StationConfig.BEATS[a]
			expect((BattleRules.battle({ role(a) }, { role(d) }))).toBe(true)
			expect((BattleRules.battle({ role(d) }, { role(a) }))).toBe(false)
		end
	end)

	it("makes one of each role beat three of any one role with the same stats", function()
		local mixed = { role("attack"), role("defense"), role("utility") }
		for _, same in StationConfig.ROLES do
			-- mixed plays second, so speed ties never help it
			expect((BattleRules.battle({ role(same), role(same), role(same) }, mixed))).toBe(false)
		end
	end)

	it("lets a Titan in the fourth slot turn a lost fight", function()
		local team = { owned("jackal"), owned("warthog"), owned("meerkat") }
		local foes = { owned("cheetah"), owned("rhino"), owned("giraffe") }
		expect((BattleRules.battle(team, foes))).toBe(false)
		table.insert(team, owned("elephant"))
		expect((BattleRules.battle(team, foes))).toBe(true)
	end)

	it("always ends, even when healers face each other", function()
		local _, turns = BattleRules.battle({ role("utility") }, { role("utility") })
		expect(turns <= BattleRules.MAX_TURNS).toBeTruthy()
		local _, t2 = BattleRules.battle(
			{ owned("meerkat") },
			{ owned("mandrill"), owned("mandrill"), owned("mandrill") }
		)
		expect(t2 < BattleRules.MAX_TURNS).toBeTruthy()
	end)
end)
