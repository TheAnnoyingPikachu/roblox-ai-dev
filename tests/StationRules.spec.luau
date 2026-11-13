--!strict
local T = require("./framework")
local Rng = require("../src/shared/Rng")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string): StationRules.Owned
	return { s = id, stats = (StationConfig.animal(id) :: StationConfig.Animal).stats }
end

describe("StationConfig", function()
	it("has egg odds that sum to 10000 and name real animals", function()
		for _, egg in StationConfig.EGGS do
			local sum = 0
			for _, o in egg.odds do
				sum += o.bp
				expect(StationConfig.animal(o.id) ~= nil).toBeTruthy()
			end
			expect(sum).toBe(10000)
		end
	end)

	it("keeps every base stat in range with a known rarity", function()
		for _, a in StationConfig.ANIMALS do
			expect(table.find(StationConfig.RARITIES, a.rarity) ~= nil).toBeTruthy()
			for _, stat in StationConfig.STATS do
				local v = (a.stats :: any)[stat]
				expect(v >= StationConfig.STAT_MIN and v <= StationConfig.STAT_MAX).toBeTruthy()
			end
		end
	end)

	it("gives every stat a station and every animal an egg", function()
		for _, stat in StationConfig.STATS do
			local found = false
			for _, st in StationConfig.STATIONS do
				found = found or st.stat == stat
			end
			expect(found).toBeTruthy()
		end
		for _, a in StationConfig.ANIMALS do
			local found = false
			for _, egg in StationConfig.EGGS do
				for _, o in egg.odds do
					found = found or o.id == a.id
				end
			end
			expect(found).toBeTruthy()
		end
	end)
end)

describe("StationRules.rate", function()
	it("pays a stat-100 animal the station's full rate and scales on the curve", function()
		local full = { s = "x", stats = { speed = 100, strength = 25, swim = 1, smarts = 1 } }
		expect(StationRules.rate(full, "track")).toBe(50)
		expect(StationRules.rate(full, "gym")).toBe(50 * 0.25 ^ 1.5)
	end)

	it("returns 0 for an unknown station", function()
		expect(StationRules.rate(owned("bunny"), "moon")).toBe(0)
	end)

	it(
		"puts the cheetah on the track, the gorilla in the gym, the dolphin in the pool, the owl in the library",
		function()
			expect((StationRules.bestStation(owned("cheetah")))).toBe("track")
			expect((StationRules.bestStation(owned("gorilla")))).toBe("gym")
			expect((StationRules.bestStation(owned("dolphin")))).toBe("pool")
			expect((StationRules.bestStation(owned("owl")))).toBe("library")
		end
	)

	it("makes a cheetah on the track earn over 5x a cheetah in the gym", function()
		local c = owned("cheetah")
		expect(StationRules.rate(c, "track") > 5 * StationRules.rate(c, "gym")).toBeTruthy()
	end)

	it("sums assignments into income", function()
		local c, b = owned("cheetah"), owned("bunny")
		local total = StationRules.income({ { animal = c, station = "track" }, { animal = b, station = "track" } })
		expect(total).toBe(StationRules.rate(c, "track") + StationRules.rate(b, "track"))
	end)
end)

describe("StationRules.hatch", function()
	it("picks by cumulative basis points at the boundaries", function()
		local odds = (StationConfig.egg("meadow") :: StationConfig.Egg).odds
		expect(StationRules.pick(odds, 1)).toBe("bunny")
		expect(StationRules.pick(odds, 3000)).toBe("bunny")
		expect(StationRules.pick(odds, 3001)).toBe("duck")
		expect(StationRules.pick(odds, 10000)).toBe("otter")
	end)

	it("refuses an unknown egg without using the rng", function()
		local a, rng = StationRules.hatch("nope", 123)
		expect(a).toBeNil()
		expect(rng).toBe(123)
	end)

	it("is reproducible from the same seed", function()
		local a1 = StationRules.hatch("safari", Rng.seed(7)) :: StationRules.Owned
		local a2 = StationRules.hatch("safari", Rng.seed(7)) :: StationRules.Owned
		expect(a1.s).toBe(a2.s)
		expect(a1.stats.speed).toBe(a2.stats.speed)
	end)

	it("rolls stats within the variance of the species base over many hatches", function()
		local rng = Rng.seed(42)
		local seen = {}
		for _ = 1, 2000 do
			local a
			a, rng = StationRules.hatch("meadow", rng)
			local animal = a :: StationRules.Owned
			seen[animal.s] = true
			local base = (StationConfig.animal(animal.s) :: StationConfig.Animal).stats
			for _, stat in StationConfig.STATS do
				local v, b = (animal.stats :: any)[stat], (base :: any)[stat]
				local lo = math.max(StationConfig.STAT_MIN, math.floor(b * (100 - StationConfig.VARIANCE) / 100))
				local hi = math.floor(b * (100 + StationConfig.VARIANCE) / 100)
				expect(v >= lo and v <= hi).toBeTruthy()
			end
		end
		for _, o in (StationConfig.egg("meadow") :: StationConfig.Egg).odds do
			expect(seen[o.id]).toBe(true)
		end
	end)
end)
