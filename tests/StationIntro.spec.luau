--!strict
local T = require("./framework")
local BattleRules = require("../src/shared/BattleRules")
local LevelRules = require("../src/shared/LevelRules")
local StationConfig = require("../src/shared/StationConfig")
local StationIntro = require("../src/shared/StationIntro")
local StationProgress = require("../src/shared/StationProgress")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

describe("StationIntro", function()
	it("lends one legend of each class and the Titan", function()
		local roles = {}
		for _, a in StationIntro.team() do
			roles[StationRules.role(a)] = true
			expect(StationConfig.variant(a.s, a.v :: string) ~= nil).toBe(true)
		end
		expect(roles.attack and roles.defense and roles.utility and roles.titan).toBe(true)
	end)

	it("cannot be lost, whatever the player does not press, and no legend falls", function()
		local won, _, seconds, ends = LevelRules.fight(StationIntro.team(), StationIntro.WAVE, {}, StationIntro.SETUP)
		expect(won).toBe(true)
		expect(seconds < BattleRules.MAX_SECONDS / 2).toBe(true)
		expect(seconds > 30).toBe(true) -- long enough for every press to come up
		for _, share in ends do
			expect(share > 0.5).toBe(true)
		end
	end)

	it("keeps the team standing even where it would lose (the net under the blessing)", function()
		local hard = { clicks = true, immortal = true }
		local plain = { clicks = true }
		local won = LevelRules.fight(StationIntro.team(), StationIntro.WAVE, {}, plain)
		expect(won).toBe(false) -- without help the legends at level 1 lose this wave
		local saved, _, _, ends = LevelRules.fight(StationIntro.team(), StationIntro.WAVE, {}, hard)
		expect(saved).toBe(true)
		for _, share in ends do
			expect(share > 0).toBe(true)
		end
	end)

	it("gives a new save one starter of each class, hatching in seconds, once", function()
		local p = StationProgress.defaults(0)
		expect(p.intro).toBe(false)
		local _, ok = StationIntro.finish(p, 1000)
		expect(ok).toBe(true)
		expect(p.intro).toBe(true)
		expect(#p.eggs).toBe(3)
		local roles = {}
		for _, e in p.eggs do
			expect(e.since).toBe(1000)
			expect(StationProgress.dueAt(p, e)).toBe(1000 + StationProgress.QUICK_SECONDS)
			roles[StationRules.role(e.animal)] = true
		end
		expect(roles.attack and roles.defense and roles.utility).toBe(true)
		local _, again, code = StationIntro.finish(p, 2000)
		expect(again).toBe(false)
		expect(code).toBe("intro_done")
		expect(#p.eggs).toBe(3)
	end)

	it("opens a starter egg after its five seconds, and it survives a save", function()
		local p = StationProgress.defaults(0)
		StationIntro.finish(p, 1000)
		local q = StationProgress.sanitize(p, 1001)
		expect(q.intro).toBe(true)
		expect(q.eggs[1].quick).toBe(true)
		expect(StationProgress.due(q, q.eggs[1], 1004)).toBe(false)
		expect(StationProgress.due(q, q.eggs[1], 1005)).toBe(true)
		expect(StationProgress.public(q).eggs[1].quick).toBe(true)
	end)

	it("never shows to a save from before it that has already played", function()
		local old = StationProgress.defaults(0) :: any
		StationProgress.give(old, "jackal", nil, 1)
		old.intro = nil
		expect(StationProgress.sanitize(old, 0).intro).toBe(true)
		local best = StationProgress.defaults(0) :: any
		best.intro, best.best = nil, 4
		expect(StationProgress.sanitize(best, 0).intro).toBe(true)
		local empty = StationProgress.defaults(0) :: any
		empty.intro = nil
		expect(StationProgress.sanitize(empty, 0).intro).toBe(false)
	end)
end)
