--!strict
local T = require("./framework")
local BattleRules = require("../src/shared/BattleRules")
local LevelRules = require("../src/shared/LevelRules")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local WaveRuns = require("../src/shared/WaveRuns")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string): StationRules.Owned
	return { s = id, stats = StationRules.versionStats(id, nil) :: StationConfig.Stats }
end

describe("WaveRuns (decision 0098)", function()
	it("carries HP over with a little rest, offers three different boons, and grows the streak", function()
		local run = WaveRuns.new(5, 3, 42)
		local after = WaveRuns.won(run, { 0.5, 0, 0.95 }, 100, 2)
		expect(after.wave).toBe(6)
		expect(after.streak).toBe(1)
		expect(after.hp[1]).toBe(0.7)
		expect(after.hp[2]).toBe(0)
		expect(after.hp[3]).toBe(1)
		local offer = after.offer :: { string }
		expect(#offer).toBe(3)
		expect(offer[1] ~= offer[2] and offer[2] ~= offer[3] and offer[1] ~= offer[3]).toBeTruthy()
		expect(after.pot.coins).toBe(0) -- the first win has no streak yet
		local again = WaveRuns.won(after, after.hp, 100, 2)
		expect(again.pot.coins).toBe(5)
		expect(run.wave).toBe(5) -- the old run is untouched
	end)

	it("only lets an offered boon be picked, and Second Wind and Revive act at once", function()
		local run = WaveRuns.won(WaveRuns.new(1, 3, 7), { 0.4, 0, 1 }, 10, 0)
		local _, ok, code = WaveRuns.pick(run, "nope")
		expect(ok).toBe(false)
		expect(code).toBe("boon")
		run.offer = { "mend", "revive", "claws" }
		local mended = WaveRuns.pick(run, "mend")
		expect(mended.hp[1]).toBe(1)
		expect(mended.hp[2]).toBe(0)
		expect(mended.offer).toBeNil()
		local revived = WaveRuns.pick(run, "revive")
		expect(revived.hp[2]).toBe(0.5)
	end)

	it("offers a rare boon about once or twice a stage, never two in one offer", function()
		local rares = 0
		for w = 1, 1000 do
			local run = WaveRuns.new(w, 3, 77)
			local n = 0
			for _, id in WaveRuns.won(run, { 1, 1, 1 }, 0, 0).offer :: { string } do
				n += if (WaveRuns.boon(id) :: WaveRuns.Boon).rare then 1 else 0
			end
			expect(n <= 1).toBeTruthy()
			rares += n
		end
		expect(rares >= 100 and rares <= 200).toBeTruthy() -- 1000 waves are 100 stages
	end)

	it("makes boons count in the fight and in the pot", function()
		local run = WaveRuns.new(1, 3, 1)
		run.boons = { "claws", "claws", "gold", "lucky" }
		local setup = WaveRuns.setup(run)
		expect(math.abs((setup.dmg :: number) - WaveRuns.CLAWS ^ 2) < 1e-9).toBeTruthy()
		run.streak = 30
		local coins, samples = WaveRuns.bonus(run, 1000, 4)
		expect(coins).toBe(1000 * (WaveRuns.STREAK_MAX + WaveRuns.GOLD_PCT) // 100)
		expect(samples).toBe(4)
		run.pot = { coins = 101, samples = 3 }
		expect(WaveRuns.bank(run, false)).toBe(101)
		expect(WaveRuns.bank(run, true)).toBe(50)
	end)

	it("gives three stars to a team that taps every power attack itself (decision 0097)", function()
		local team = { owned("lion"), owned("rhino"), owned("flamingo") }
		local won, _, par = LevelRules.fight(team, 1, {})
		expect(won).toBe(true)
		-- a perfect player: tap each meter PERFECT_AT after it fills, one at a time
		local taps: { BattleRules.Tap } = {}
		local log: { BattleRules.Hit } = {}
		local tapped: { [string]: boolean } = {}
		for _ = 1, 40 do
			log = {}
			BattleRules.battle(team, LevelRules.enemies(1), log, taps)
			local nextFill: BattleRules.Hit? = nil
			for _, e in log do
				local key = `{e.slot}:{e.t}`
				if e.side == 1 and not e.power and e.energy >= 1 and not tapped[key] then
					nextFill = e
					break
				end
			end
			if nextFill == nil then
				break
			end
			tapped[`{nextFill.slot}:{nextFill.t}`] = true
			table.insert(taps, { slot = nextFill.slot, t = nextFill.t + BattleRules.PERFECT_AT })
		end
		local ok, _, seconds = BattleRules.battle(team, LevelRules.enemies(1), nil, taps)
		local down = false
		for _, e in log do
			down = down or (e.tside == 1 and e.hp <= 0)
		end
		expect(ok).toBe(true)
		expect(seconds <= par).toBeTruthy()
		expect(LevelRules.stars(ok, down, LevelRules.missed(log))).toBe(3)
		local fired: { any } = { -- one fired itself, one was tapped, one is the enemy's
			{ side = 1, power = true },
			{ side = 1, power = true, tap = true },
			{ side = 2, power = true },
		}
		expect(LevelRules.missed(fired)).toBe(1)
		expect(LevelRules.stars(true, false, LevelRules.missed(fired))).toBe(2)
		expect(LevelRules.stars(true, true, 0)).toBe(2)
		expect(LevelRules.stars(false, false, 0)).toBe(0)
	end)
end)

describe("WaveRuns shared fights (decision 0108)", function()
	it("brings every knocked-out animal back at WIPED_BACK for the next wave, alone or together", function()
		local after = WaveRuns.won(WaveRuns.new(1, 4, 7), { 0, 0.5, 0, 1 }, 100, 0)
		local hp = WaveRuns.setup(after).hp :: { number }
		expect(hp[1]).toBe(WaveRuns.WIPED_BACK)
		expect(hp[2]).toBe(0.5 + WaveRuns.REST_HEAL)
		expect(hp[3]).toBe(WaveRuns.WIPED_BACK)
		expect(hp[4]).toBe(1)
		expect(after.hp[1]).toBe(0) -- the run still knows who fell: Revive lifts them to half
		after.offer = { "revive", "mend", "claws" }
		expect((WaveRuns.setup((WaveRuns.pick(after, "revive"))).hp :: { number })[1]).toBe(0.5)
	end)

	it("picks the boon with the most votes, and breaks a tie at random but the same way every time", function()
		local run = WaveRuns.won(WaveRuns.new(1, 3, 11), { 1, 1, 1 }, 100, 0)
		local offer = run.offer :: { string }
		expect(WaveRuns.tally(run, { offer[2], offer[2], offer[1] })).toBe(offer[2])
		expect(WaveRuns.tally(run, { offer[3] })).toBe(offer[3])
		expect(WaveRuns.tally(run, { "nonsense", offer[1] })).toBe(offer[1])
		local tie = WaveRuns.tally(run, { offer[1], offer[3] })
		expect(tie == offer[1] or tie == offer[3]).toBeTruthy()
		expect(WaveRuns.tally(run, { offer[3], offer[1] })).toBe(tie) -- the same votes, the same boon
		local won = {}
		for seed = 1, 40 do -- over many runs each side of a tie wins sometimes
			local r = WaveRuns.won(WaveRuns.new(1, 3, seed), { 1, 1, 1 }, 100, 0)
			local o = r.offer :: { string }
			won[if WaveRuns.tally(r, { o[1], o[2] }) == o[1] then 1 else 2] = true
		end
		expect(won[1] and won[2]).toBeTruthy()
		expect(WaveRuns.tally(WaveRuns.new(1, 3, 1), {})).toBeNil() -- nothing on offer yet
	end)
end)
