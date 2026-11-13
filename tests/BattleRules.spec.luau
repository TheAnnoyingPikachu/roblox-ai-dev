--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local BattleRules = require("../src/shared/BattleRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

-- A made-up animal whose best stat is `best` (60) with 20 in the rest, so every role has the same
-- stat total and only the role differs.
local function role(best: StationConfig.Stat, speed: number?): StationRules.Owned
	local st = { speed = 20, strength = 20, swim = 20, smarts = 20 } :: any
	st[best] = 60
	if speed and best ~= "speed" then
		st.speed = speed
	end
	return { s = "x", stats = st :: StationConfig.Stats }
end

describe("BattleRules roles", function()
	it("gives each type its role: speed attack, strength tank, swim defense, smarts utility", function()
		expect(BattleRules.fighter(owned("cheetah"), 1, 1).role).toBe("attack")
		expect(BattleRules.fighter(owned("gorilla"), 1, 1).role).toBe("tank")
		expect(BattleRules.fighter(owned("dolphin"), 1, 1).role).toBe("defense")
		expect(BattleRules.fighter(owned("owl"), 1, 1).role).toBe("utility")
		local seen = {}
		for _, r in StationConfig.ROLES do
			expect(seen[r]).toBeNil()
			seen[r] = true
		end
	end)

	it("makes Attack hit harder and Tank tougher than the same stats in another role", function()
		local atk = BattleRules.fighter(role("speed"), 1, 1)
		local tank = BattleRules.fighter(role("strength"), 1, 1)
		local util = BattleRules.fighter(role("smarts"), 1, 1)
		expect(atk.atk > util.atk).toBeTruthy()
		expect(tank.maxHp > util.maxHp).toBeTruthy()
	end)
end)

describe("BattleRules.battle", function()
	it("loses with no team, and side 1 wins a mirror match on speed ties", function()
		expect((BattleRules.battle({}, { owned("bunny") }))).toBe(false)
		local team = { owned("bunny"), owned("pig"), owned("duck") }
		expect((BattleRules.battle(team, { owned("bunny"), owned("pig"), owned("duck") }))).toBe(true)
	end)

	it("lets the type advantage decide a fight between equal animals", function()
		-- equal totals and speed; Defense (swim) beats Attack (speed)
		local d, a = role("swim", 60), role("speed")
		expect((BattleRules.battle({ d }, { a }))).toBe(true)
		expect((BattleRules.battle({ a }, { d }))).toBe(false)
	end)

	it("makes a Tank, Attack, Defense team beat three of any one role with the same stats", function()
		local mixed = { role("strength", 40), role("speed"), role("swim", 40) }
		for _, same in { "speed", "strength", "swim", "smarts" } do
			local mono = {}
			for _ = 1, 3 do
				table.insert(mono, role(same :: any, 40))
			end
			-- mixed plays second so speed ties never help it
			expect((BattleRules.battle(mono, mixed))).toBe(false)
		end
	end)

	it("always ends, even when healers face each other", function()
		local _, turns = BattleRules.battle({ role("smarts") }, { role("smarts") })
		expect(turns <= BattleRules.MAX_TURNS).toBeTruthy()
		local _, t2 = BattleRules.battle({ owned("mouse") }, { owned("owl"), owned("owl"), owned("owl") })
		expect(t2 < BattleRules.MAX_TURNS).toBeTruthy()
	end)

	it("has no unbeatable team shape: three Attackers beat Tank, Attack, Utility", function()
		local attackers = { role("speed"), role("speed"), role("speed") }
		expect((BattleRules.battle(attackers, { role("strength", 40), role("speed"), role("smarts", 40) }))).toBe(true)
	end)
end)
