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

	it(
		"offers a lucky card in about one offer in six and after every boss, never two in one offer (decision 0120)",
		function()
			local rares, ultras = 0, 0
			for w = 1, 1000 do
				local run = WaveRuns.new(w, 3, 77)
				local n = 0
				for _, id in WaveRuns.won(run, { 1, 1, 1 }, 0, 0).offer :: { string } do
					local b = WaveRuns.boon(id) :: WaveRuns.Boon
					n += if b.rare then 1 else 0
					ultras += if b.tier == "ultra" then 1 else 0
				end
				expect(n <= 1).toBeTruthy()
				if w % LevelRules.BOSS_EVERY == 0 then
					expect(n).toBe(1)
				end
				rares += n
			end
			-- 17% of 1000 offers, and the bosses' 100 (some already lucky)
			expect(rares >= 200 and rares <= 320).toBeTruthy()
			expect(ultras >= 5 and ultras <= 45).toBeTruthy()
			-- a run that has taken its ultra lucky boon is never offered another
			for w = 1, 1000 do
				local run = WaveRuns.new(w, 3, 77)
				run.ultra = true
				for _, id in WaveRuns.won(run, { 1, 1, 1 }, 0, 0).offer :: { string } do
					expect((WaveRuns.boon(id) :: WaveRuns.Boon).tier ~= "ultra").toBeTruthy()
				end
			end
		end
	)

	it("has the 27 boons signed off, in three tiers, each with a name and a text", function()
		local tiers: { [string]: number } = {}
		for _, b in WaveRuns.BOONS do
			tiers[b.tier] = (tiers[b.tier] or 0) + 1
			expect(#b.name > 0 and #b.text > 0 and b.weight > 0).toBeTruthy()
			expect(b.rare == (if b.tier ~= "common" then true else nil)).toBeTruthy()
		end
		expect(tiers.common).toBe(12)
		expect(tiers.lucky).toBe(9)
		expect(tiers.ultra).toBe(6)
	end)

	it(
		"counts a boon's stacks up to its cap, Twin Picks two picks an offer for 5 waves, and ends a timed boon",
		function()
			local run = WaveRuns.new(10, 3, 1)
			run.boons = { "steady", "steady", "steady", "steady", "charged", "charged" }
			expect(WaveRuns.count(run, "steady")).toBe(3)
			expect(WaveRuns.count(run, "charged")).toBe(1)
			run.offer = { "twin", "claws", "hide" }
			local twin = WaveRuns.pick(run, "twin")
			expect(twin.ultra).toBe(true)
			twin.offer = { "claws", "hide", "mend" }
			twin.wave = 11 -- the pick after the next fight: one, then a second from the rest
			local first = WaveRuns.pick(twin, "claws")
			expect(WaveRuns.count(first, "claws")).toBe(1)
			expect(first.second).toBe(true)
			expect(table.concat(first.offer :: { string }, ",")).toBe("hide,mend")
			local both, ok = WaveRuns.pick(first, "mend")
			expect(ok).toBe(true)
			expect(both.offer).toBeNil()
			expect(WaveRuns.count(both, "claws") + WaveRuns.count(both, "mend")).toBe(2)
			twin.wave = 15 -- the fifth pick is still twin
			expect(WaveRuns.pick(twin, "claws").second).toBe(true)
			twin.wave = 16
			expect(WaveRuns.pick(twin, "claws").offer).toBeNil()
			twin.offer = { "blessing", "claws", "hide" } -- an ultra card is never left for a second pick
			expect(table.concat(WaveRuns.pick(twin, "hide").offer or {}, ",")).toBe("")
			run.offer = { "unbreakable", "claws", "hide" }
			local hard = WaveRuns.pick(run, "unbreakable")
			expect(WaveRuns.setup(hard).immortal).toBe(true)
			hard.wave = 12
			expect(WaveRuns.setup(hard).immortal).toBe(true)
			hard.wave = 13
			expect(WaveRuns.setup(hard).immortal).toBe(false)
		end
	)

	it("pays the new boons into the pot: Treasure Map's samples, Golden Hour doubling a bank but not a loss", function()
		local run = WaveRuns.new(1, 3, 1)
		run.boons = { "map", "map" }
		local _, samples = WaveRuns.bonus(run, 100, 3)
		expect(samples).toBe(2 * WaveRuns.MAP_SAMPLES)
		run.boons = { "golden" }
		run.pot = { coins = 101, samples = 3 }
		expect(WaveRuns.bank(run, false)).toBe(202)
		expect(WaveRuns.bank(run, true)).toBe(50)
		local after = WaveRuns.won(WaveRuns.new(1, 3, 1), { 0.5, 0.5, 0 }, 0, 0)
		local rested = WaveRuns.new(1, 3, 1)
		rested.boons = { "rested" }
		expect(math.abs(WaveRuns.won(rested, { 0.5, 0.5, 0 }, 0, 0).hp[1] - after.hp[1] - WaveRuns.RESTED) < 1e-9).toBeTruthy()
	end)

	it("puts the fight boons into the setup, and the fight reads them (decision 0120)", function()
		local run = WaveRuns.new(1, 3, 1)
		run.boons = { "iron", "focus", "taps", "watch", "pack", "phoenix", "overcharge", "chain", "thorns", "roar" }
		local setup = WaveRuns.setup(run)
		expect(setup.taken).toBe(WaveRuns.IRON)
		expect(setup.gain).toBe(WaveRuns.FOCUS)
		expect(setup.clickDmg).toBe(WaveRuns.TAPS)
		expect(setup.shieldSooner).toBe(WaveRuns.WATCH)
		expect(setup.phoenix).toBe(1)
		expect(setup.titanReady).toBe(true)
		-- Titan's Roar: the Titan starts full, the others as before
		local team = { owned("lion"), owned("rhino"), owned("flamingo"), owned("elephant") }
		local roar = BattleRules.lineup(team, 1, { titanReady = true })
		expect(roar[4].energy).toBe(BattleRules.POWER_COST)
		expect(roar[1].energy < BattleRules.POWER_COST).toBeTruthy()
		-- Watchful: the shield comes back sooner
		local taps = { { slot = 0, t = 0 }, { slot = 0, t = BattleRules.SHIELD_COOLDOWN - 1 } }
		expect(#BattleRules.shields(taps)).toBe(1)
		expect(#BattleRules.shields(taps, 1)).toBe(2)
		-- Iron Coat: the team ends a hard wave with more health; Phoenix Feather: the first to fall gets up
		local three = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		local function fight(s: BattleRules.Setup): ({ BattleRules.Hit }, { number })
			local log = {}
			local _, _, _, ends = BattleRules.battle(three, LevelRules.enemies(12), log, {}, s)
			return log, ends
		end
		local plainLog, plainEnds = fight({})
		local _, ironEnds = fight({ taken = 0.5 })
		local sum = function(t: { number }): number
			local n = 0
			for _, v in t do
				n += v
			end
			return n
		end
		expect(sum(ironEnds) > sum(plainEnds)).toBeTruthy()
		local first: BattleRules.Hit? = nil
		for _, e in plainLog do
			if e.tside == 1 and e.hp <= 0 then
				first = e
				break
			end
		end
		expect(first ~= nil).toBeTruthy() -- wave 12 knocks a fresh starter team down
		local featherLog = fight({ phoenix = 1 })
		local f = first :: BattleRules.Hit
		for _, e in featherLog do
			if e.t == f.t and e.tside == 1 and e.tslot == f.tslot then
				expect(e.hp > 0).toBeTruthy()
				break
			end
		end
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
