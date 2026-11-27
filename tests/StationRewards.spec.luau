--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationProgress = require("../src/shared/StationProgress")
local StationRewards = require("../src/shared/StationRewards")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

local DAY = 86400
local MON = 1794787200 -- Monday 16 November 2026, 00:00 UTC

local function fresh(): StationProgress.Profile
	return StationProgress.defaults(0)
end

local function animalsFor(items: StationRewards.Items): { StationRules.Owned }
	local out = {}
	for _ in items.eggs do
		table.insert(out, { s = "jackal", stats = StationRules.versionStats("jackal", nil) :: StationConfig.Stats })
	end
	return out
end

describe("StationRewards calendar", function()
	it("counts UTC days, weeks from Monday and months", function()
		local d = StationRewards.day(MON)
		expect(StationRewards.weekOf(d)).toBe(d)
		expect(StationRewards.weekOf(d + 6)).toBe(d)
		expect(StationRewards.weekOf(d + 7)).toBe(d + 7)
		expect(StationRewards.monthOf(MON)).toBe(2026 * 12 + 10)
		expect(StationRewards.rainbowOf(2026 * 12 + 10)).toBe("cheetah")
		expect(StationRewards.rainbowOf(2026 * 12 + 11)).toBe("jackal")
		expect(StationRewards.rainbowOf(2026 * 12 + 18)).toBe("cheetah")
	end)

	it("logs each day once, starts the week afresh on Monday and the month on the 1st", function()
		local p = fresh()
		StationRewards.visit(p, MON + 10)
		StationRewards.visit(p, MON + 3600) -- the same day again
		expect(p.rewards.weekDays).toBe(1)
		expect(p.rewards.monthDays).toBe(1)
		for k = 1, 6 do
			StationRewards.visit(p, MON + k * DAY)
		end
		expect(p.rewards.weekDays).toBe(7)
		StationRewards.visit(p, MON + 7 * DAY) -- next Monday
		expect(p.rewards.weekDays).toBe(1)
		expect(p.rewards.weekGot).toBe(0)
		expect(p.rewards.monthDays).toBe(8)
		StationRewards.visit(p, MON + 15 * DAY) -- 1 December: a missed week never mattered, the month restarts
		expect(p.rewards.monthDays).toBe(1)
	end)
end)

describe("StationRewards planners", function()
	it("pays coins in wave pays, never under 40", function()
		local p = fresh()
		expect(StationRewards.wavePay(p)).toBe(40)
		p.best = 20
		expect(StationRewards.wavePay(p)).toBe(116)
		expect(StationRewards.resolve(p, { pays = 5 }).coins).toBe(580)
	end)

	it("gives the best egg unlocked and the one below it", function()
		local p = fresh()
		local best, below = StationRewards.bestEgg(p)
		expect(best).toBe("wild") -- the Wild Egg is for sale from the start
		expect(below).toBe("meadow")
		p.best = 10 -- beating wave 10 opens the Safari Egg (decision 0132)
		best, below = StationRewards.bestEgg(p)
		expect(best).toBe("safari")
		expect(below).toBe("wild")
	end)

	it("lets one weekly reward be claimed per day logged, in order", function()
		local p = fresh()
		StationRewards.visit(p, MON)
		local spec = StationRewards.nextWeek(p) :: StationRewards.Spec
		local items = StationRewards.resolve(p, spec)
		local _, ok = StationRewards.claimWeek(p, items, animalsFor(items), MON)
		expect(ok).toBe(true)
		expect(p.coins).toBe(StationProgress.START_COINS + 5 * 40)
		local _, ok2, code = StationRewards.claimWeek(p, items, {}, MON)
		expect(ok2).toBe(false)
		expect(code).toBe("claimed")
		StationRewards.visit(p, MON + DAY)
		spec = StationRewards.nextWeek(p) :: StationRewards.Spec
		items = StationRewards.resolve(p, spec)
		expect(#items.eggs).toBe(2)
		local _, ok3 = StationRewards.claimWeek(p, items, animalsFor(items), MON + DAY)
		expect(ok3).toBe(true)
		expect(#p.eggs).toBe(2)
	end)

	it("pays a monthly milestone once, after enough days logged", function()
		local p = fresh()
		StationRewards.visit(p, MON)
		expect((StationRewards.canMonth(p, 3))).toBe(false)
		local items = StationRewards.resolve(p, StationRewards.MONTH[1])
		expect((StationRewards.claimMonth(p, 1, items, {}, MON))).toBeTruthy()
		local _, again = StationRewards.claimMonth(p, 1, items, {}, MON)
		expect(again).toBe(false)
	end)

	it("gives the month's rainbow animal on day 28, and needs room in the barn", function()
		local p = fresh()
		p.rewards.month, p.rewards.monthDays = 2026 * 12 + 10, 28
		local items = StationRewards.resolve(p, StationRewards.MONTH[28])
		expect(items.rainbow).toBe("cheetah")
		local _, ok = StationRewards.claimMonth(p, 28, items, {}, MON)
		expect(ok).toBe(true)
		expect(p.animals[1].s).toBe("cheetah")
		expect(p.animals[1].rainbow).toBe(true)
	end)

	it("keeps won eggs waiting while the storage is full, and moves them in when there is room", function()
		local p = fresh()
		local cap = StationProgress.value(p, "hatchery") + StationProgress.value(p, "cellar")
		local items = StationRewards.resolve(p, { egg = "meadow", eggs = cap + 2 })
		local _, ok = StationRewards.grant(p, items, animalsFor(items), nil, MON)
		expect(ok).toBe(true)
		expect(#p.eggs).toBe(cap)
		expect(#p.rewards.pending).toBe(2)
		table.remove(p.eggs, 1)
		StationRewards.visit(p, MON)
		expect(#p.eggs).toBe(cap)
		expect(#p.rewards.pending).toBe(1)
		expect(StationProgress.public(p).rewards.pending[1].animal).toBeNil() -- never sent to the client
	end)
end)

describe("StationRewards wheel", function()
	it("has odds that add up to a million, with a 1 in 400 jackpot", function()
		local total = 0
		for _, slice in StationRewards.WHEEL do
			total += slice.ppm
		end
		expect(total).toBe(1000000)
		expect(StationRewards.WHEEL[#StationRewards.WHEEL].ppm).toBe(2500)
		expect(#StationRewards.mythics() > 0).toBeTruthy()
	end)

	it("lands each roll on its slice, and doubles the jackpot after the pity count", function()
		local p = fresh()
		expect(StationRewards.prizeOf(p, 0)).toBe(1)
		expect(StationRewards.prizeOf(p, 299999)).toBe(1)
		expect(StationRewards.prizeOf(p, 300000)).toBe(2)
		expect(StationRewards.prizeOf(p, 999999)).toBe(8)
		expect(StationRewards.prizeOf(p, 996000)).toBe(7)
		p.rewards.pity = StationRewards.PITY
		expect(StationRewards.prizeOf(p, 996000)).toBe(8)
	end)

	it("gives one free spin a day and a jackpot as a rainbow mythic", function()
		local p = fresh()
		local prize = #StationRewards.WHEEL
		local items = StationRewards.resolve(p, StationRewards.WHEEL[prize].prize)
		local mythic = StationRewards.mythics()[1]
		local _, ok = StationRewards.spin(p, prize, items, {}, mythic, MON)
		expect(ok).toBe(true)
		expect(p.animals[1].v).toBe(mythic.v)
		expect(p.animals[1].rainbow).toBe(true)
		expect(p.rewards.pity).toBe(0)
		local _, again, code = StationRewards.spin(p, 1, StationRewards.resolve(p, { pays = 2 }), {}, nil, MON + 60)
		expect(again).toBe(false)
		expect(code).toBe("spun")
		local _, tomorrow = StationRewards.spin(p, 1, StationRewards.resolve(p, { pays = 2 }), {}, nil, MON + DAY)
		expect(tomorrow).toBe(true)
		expect(p.rewards.pity).toBe(1)
	end)
end)

describe("StationProgress boosts", function()
	it("hatches twice as fast during a hatching boost, and two boosts last twice as long", function()
		local p = fresh()
		p.eggs = {
			{
				egg = "wild",
				since = 1000,
				animal = { s = "jackal", stats = StationRules.versionStats("jackal", nil) :: StationConfig.Stats },
			},
		}
		local plain = StationProgress.dueAt(p, p.eggs[1]) :: number
		StationProgress.addBoost(p, "hatch", 120, 1000)
		StationProgress.addBoost(p, "hatch", 120, 1010) -- runs on from the first
		expect(#p.boosts.hatch).toBe(1)
		expect(p.boosts.hatch[1].to).toBe(1240)
		expect(StationProgress.dueAt(p, p.eggs[1])).toBe(plain - 240)
		expect(StationProgress.boostLeft(p, "hatch", 1100)).toBe(140)
	end)

	it("trains twice as fast during a training boost", function()
		local p = fresh()
		local plain = StationProgress.trainedBetween(p, 0, 1000)
		StationProgress.addBoost(p, "train", 100, 500)
		expect(StationProgress.trainedBetween(p, 0, 1000)).toBe(plain + StationProgress.trainingSeconds(p, 100))
	end)

	it("keeps boosts and rewards through a save, and drops bad ones", function()
		local p = fresh()
		StationProgress.addBoost(p, "train", 600, 5000)
		p.rewards.weekDays, p.rewards.weekGot, p.rewards.monthGot = 3, 2, { 1, 3 }
		local back = StationProgress.sanitize(p, 5100)
		expect(back.boosts.train[1].to).toBe(5600)
		expect(back.rewards.weekGot).toBe(2)
		expect(#back.rewards.monthGot).toBe(2)
		local bad =
			StationProgress.sanitize({ boosts = { hatch = { { from = 10, to = 5 } } }, rewards = { weekGot = 9 } }, 0)
		expect(#bad.boosts.hatch).toBe(0)
		expect(bad.rewards.weekGot).toBe(0)
	end)
end)

describe("Stars and star chests (decision 0097)", function()
	it("keeps the best stars per wave, adds them up and makes a chest due every CHEST_STARS", function()
		local p = fresh()
		StationProgress.setStars(p, 3, 2)
		StationProgress.setStars(p, 3, 1) -- worse: kept at 2
		StationProgress.setStars(p, 1, 3)
		expect(p.stars).toBe("302")
		expect(StationProgress.starsOf(p, 3)).toBe(2)
		expect(StationProgress.starsOf(p, 9)).toBe(0)
		expect(StationProgress.starTotal(p)).toBe(5)
		expect(StationProgress.chestsDue(p)).toBe(0)
		for w = 1, 5 do
			StationProgress.setStars(p, w, 3)
		end
		expect(StationProgress.chestsDue(p)).toBe(1)
		local spec = StationRewards.nextChest(p) :: StationRewards.Spec
		local items = StationRewards.resolve(p, spec)
		local coins = p.coins
		local _, ok = StationRewards.claimChest(p, items, animalsFor(items), MON)
		expect(ok).toBe(true)
		expect(p.coins > coins).toBeTruthy()
		expect(StationProgress.chestsDue(p)).toBe(0)
		local _, again, code = StationRewards.claimChest(p, items, animalsFor(items), MON)
		expect(again).toBe(false)
		expect(code).toBe("not_yet")
	end)

	it("cleans stored stars and chests", function()
		local p = StationProgress.sanitize({ stars = "3x2", chests = -4 }, MON)
		expect(p.stars).toBe("302")
		expect(p.chests).toBe(0)
		expect(StationProgress.sanitize({}, MON).stars).toBe("")
	end)

	it("gives a boss chest for every boss wave, in turn", function()
		expect(StationRewards.bossChest(10).egg).toBe("best")
		expect(StationRewards.bossChest(20).boost).toBe("hatch")
		expect(StationRewards.bossChest(40).egg).toBe("best")
	end)
end)
