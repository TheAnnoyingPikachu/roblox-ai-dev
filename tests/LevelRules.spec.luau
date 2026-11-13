--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local LevelRules = require("../src/shared/LevelRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

local function teamTotal(team: { StationRules.Owned }): number
	local n = 0
	for _, a in team do
		for _, stat in StationConfig.STATS do
			n += StationRules.stat(a, stat)
		end
	end
	return n
end

-- The highest level `team` clears in a row from level 1 (stops at `limit`).
local function reach(team: { StationRules.Owned }, limit: number): number
	for level = 1, limit do
		if not LevelRules.fight(team, level) then
			return level - 1
		end
	end
	return limit
end

describe("LevelRules.enemies", function()
	it("is the same team every time for the same level, of TEAM_SIZE real species", function()
		local a, b = LevelRules.enemies(17), LevelRules.enemies(17)
		expect(#a).toBe(LevelRules.TEAM_SIZE)
		for k = 1, #a do
			expect(a[k].s).toBe(b[k].s)
			expect(a[k].stats.speed).toBe(b[k].stats.speed)
			expect(StationConfig.species(a[k].s) ~= nil).toBeTruthy()
		end
	end)

	it("only sends commons early and gets stronger every few levels without end", function()
		for _, e in LevelRules.enemies(1) do
			expect((StationConfig.species(e.s) :: StationConfig.Species).rarity).toBe("common")
		end
		expect(LevelRules.scale(2) > LevelRules.scale(1)).toBeTruthy()
		expect(teamTotal(LevelRules.enemies(200)) > teamTotal(LevelRules.enemies(100))).toBeTruthy()
		expect(LevelRules.enemies(300)[1].stats.speed > StationConfig.STAT_MAX).toBeTruthy()
	end)

	it("puts a variant boss last on every 10th level, rarer as levels rise", function()
		expect(LevelRules.enemies(9)[3].v).toBeNil()
		expect(StationRules.rarity(LevelRules.enemies(10)[3])).toBe("epic")
		expect(StationRules.rarity(LevelRules.enemies(30)[3])).toBe("legendary")
		expect(StationRules.rarity(LevelRules.enemies(60)[3])).toBe("mythic")
	end)
end)

describe("LevelRules.fight", function()
	it("lets three commons clear the first levels but walls them later", function()
		local starters = { owned("jackal"), owned("warthog"), owned("meerkat") }
		local r = reach(starters, 200)
		expect(r >= 3).toBeTruthy()
		expect(r < 60).toBeTruthy()
	end)

	it("makes training and variants push further", function()
		local starters = { owned("jackal"), owned("warthog"), owned("meerkat") }
		local trained = {}
		for _, a in starters do
			local t = StationRules.bestStat(a)
			for _, st in StationConfig.STATIONS do
				if st.stat == t then
					table.insert(trained, StationRules.train(a, st.id, 1e9))
				end
			end
		end
		local rares = { owned("lion", "sun_lion"), owned("gorilla", "lava_gorilla"), owned("mandrill") }
		local base, better, best = reach(starters, 400), reach(trained, 400), reach(rares, 400)
		expect(better > base).toBeTruthy()
		expect(best > better).toBeTruthy()
		expect(best < 400).toBeTruthy()
	end)

	it("never sends a Titan as a level enemy, and a Titan carries a team further", function()
		for _, level in { 1, 20, 100 } do
			for _, e in LevelRules.enemies(level) do
				expect(StationRules.role(e) ~= "titan").toBeTruthy()
			end
		end
		local team = { owned("jackal"), owned("warthog"), owned("meerkat") }
		local without = reach(team, 400)
		table.insert(team, owned("elephant"))
		expect(reach(team, 400) > without).toBeTruthy()
	end)
end)

describe("LevelRules.reward", function()
	it("pays more for higher levels and a part for replays", function()
		expect(LevelRules.reward(1, 0)).toBe(LevelRules.REWARD_START)
		expect(LevelRules.reward(20, 19) > LevelRules.reward(10, 9)).toBeTruthy()
		expect(LevelRules.reward(5, 9)).toBe(math.floor(LevelRules.reward(5, 4) * LevelRules.REPLAY_PCT / 100))
	end)
end)
