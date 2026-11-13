--!strict
local T = require("./framework")
local Rng = require("../src/shared/Rng")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

describe("StationConfig", function()
	it("has egg odds that sum to 10000 and name real species", function()
		for _, egg in StationConfig.EGGS do
			local sum = 0
			for _, o in egg.odds do
				sum += o.bp
				expect(StationConfig.species(o.id) ~= nil).toBeTruthy()
			end
			expect(sum).toBe(10000)
		end
	end)

	it("keeps basic versions common to rare with stats in 1..100", function()
		for _, sp in StationConfig.SPECIES do
			expect(table.find(StationConfig.BASIC_RARITIES, sp.rarity) ~= nil).toBeTruthy()
			for _, stat in StationConfig.STATS do
				local x = (sp.stats :: any)[stat]
				expect(x >= 1 and x <= 100).toBeTruthy()
			end
		end
	end)

	it("gives every species exactly one variant per tier, with unique ids and a real twist stat", function()
		local ids = {}
		for _, sp in StationConfig.SPECIES do
			expect(ids[sp.id]).toBeNil()
			ids[sp.id] = true
			expect(#sp.variants).toBe(#StationConfig.TIERS)
			for _, t in StationConfig.TIERS do
				local n = 0
				for _, va in sp.variants do
					n += if va.tier == t.tier then 1 else 0
				end
				expect(n).toBe(1)
			end
			for _, va in sp.variants do
				expect(ids[va.id]).toBeNil()
				ids[va.id] = true
				expect(table.find(StationConfig.STATS, va.twist) ~= nil).toBeTruthy()
			end
		end
	end)

	it("makes variants super rare (1 in 200 or rarer) and every variant tier rarer than basic", function()
		for _, t in StationConfig.TIERS do
			expect(t.ppm <= 5000).toBeTruthy()
			expect(table.find(StationConfig.BASIC_RARITIES, t.tier)).toBeNil()
			expect(table.find(StationConfig.RARITIES, t.tier) ~= nil).toBeTruthy()
		end
	end)

	it("gives every stat a station and lets an egg hatch every species", function()
		for _, stat in StationConfig.STATS do
			local found = false
			for _, st in StationConfig.STATIONS do
				found = found or st.stat == stat
			end
			expect(found).toBeTruthy()
		end
		for _, sp in StationConfig.SPECIES do
			local found = false
			for _, egg in StationConfig.EGGS do
				for _, o in egg.odds do
					found = found or o.id == sp.id
				end
			end
			expect(found).toBeTruthy()
		end
	end)

	it("only finds a variant under its own species", function()
		expect(StationConfig.variant("cheetah", "golden_cheetah") ~= nil).toBeTruthy()
		expect(StationConfig.variant("bunny", "golden_cheetah")).toBeNil()
	end)
end)

describe("StationRules.versionStats", function()
	it("multiplies a variant's stats by its tier and adds the twist", function()
		local st = StationRules.versionStats("cheetah", "golden_cheetah") :: StationConfig.Stats -- legendary x2, +40 strength
		expect(st.speed).toBe(180)
		expect(st.strength).toBe(100)
		expect(st.swim).toBe(20)
	end)

	it("refuses unknown species and mismatched variants", function()
		expect(StationRules.versionStats("dragon", nil)).toBeNil()
		expect(StationRules.versionStats("bunny", "kitsune")).toBeNil()
	end)

	it("makes every variant out-earn its basic version at the basic's best station", function()
		for _, sp in StationConfig.SPECIES do
			local basic = owned(sp.id)
			local best, rate = StationRules.bestStation(basic)
			for _, va in sp.variants do
				expect(StationRules.rate(owned(sp.id, va.id), best) > rate).toBeTruthy()
			end
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

	it("sends each basic specialist to its matching station", function()
		local want = { speed = "track", strength = "gym", swim = "pool", smarts = "library" }
		for _, sp in StationConfig.SPECIES do
			local top, topStat = -1, ""
			for _, stat in StationConfig.STATS do
				if (sp.stats :: any)[stat] > top then
					top, topStat = (sp.stats :: any)[stat], stat
				end
			end
			expect((StationRules.bestStation(owned(sp.id)))).toBe((want :: any)[topStat])
		end
	end)

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

describe("StationRules battle matchups", function()
	it("makes the four stats one loop: each beats one, loses to one, is neutral to one", function()
		for _, a in StationConfig.STATS do
			local wins, losses, even = 0, 0, 0
			for _, d in StationConfig.STATS do
				if a ~= d then
					local m = StationRules.matchup(a :: any, d :: any)
					wins += if m > 1 then 1 else 0
					losses += if m < 1 then 1 else 0
					even += if m == 1 then 1 else 0
				end
			end
			expect(wins).toBe(1)
			expect(losses).toBe(1)
			expect(even).toBe(1)
			expect(StationRules.matchup(a :: any, a :: any)).toBe(1)
		end
		-- the loop visits all four stats before coming back
		local seen, at = {}, "speed"
		for _ = 1, 4 do
			expect(seen[at]).toBeNil()
			seen[at] = true
			at = (StationConfig.BEATS :: any)[at]
		end
		expect(at).toBe("speed")
	end)

	it("keeps the advantage slight and symmetric", function()
		expect(StationConfig.ADVANTAGE > 1 and StationConfig.ADVANTAGE <= 1.5).toBeTruthy()
		expect(StationRules.matchup("speed", "smarts") * StationRules.matchup("smarts", "speed")).toBe(1)
	end)

	it("battles as the best stat: a cheetah is speed, an owl is smarts, and the cheetah has the edge", function()
		expect(StationRules.battleType(owned("cheetah"))).toBe("speed")
		expect(StationRules.battleType(owned("owl"))).toBe("smarts")
		expect(StationRules.matchup("speed", "smarts")).toBe(StationConfig.ADVANTAGE)
		expect(StationRules.battleType(owned("dolphin"))).toBe("swim")
		expect(StationRules.matchup("speed", "swim") < 1).toBeTruthy()
	end)
end)

describe("StationRules.hatch", function()
	it("picks species by cumulative basis points at the boundaries", function()
		local odds = (StationConfig.egg("meadow") :: StationConfig.Egg).odds
		expect(StationRules.pick(odds, 1)).toBe("bunny")
		expect(StationRules.pick(odds, 1400)).toBe("bunny")
		expect(StationRules.pick(odds, 1401)).toBe("fox")
		expect(StationRules.pick(odds, 10000)).toBe("raccoon")
	end)

	it("picks the variant tier rarest first, basic past 5550 ppm", function()
		expect(StationRules.pickTier(1)).toBe("mythic")
		expect(StationRules.pickTier(50)).toBe("mythic")
		expect(StationRules.pickTier(51)).toBe("legendary")
		expect(StationRules.pickTier(550)).toBe("legendary")
		expect(StationRules.pickTier(551)).toBe("epic")
		expect(StationRules.pickTier(5550)).toBe("epic")
		expect(StationRules.pickTier(5551)).toBeNil()
		expect(StationRules.pickTier(1_000_000)).toBeNil()
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
		expect(a1.v).toBe(a2.v)
		expect(a1.stats.speed).toBe(a2.stats.speed)
	end)

	it("hatches mostly basics, rare variants, within the stat variance", function()
		local rng = Rng.seed(42)
		local seen, variants = {}, 0
		local N = 20000
		for _ = 1, N do
			local a
			a, rng = StationRules.hatch("meadow", rng)
			local animal = a :: StationRules.Owned
			seen[animal.s] = true
			if animal.v then
				variants += 1
				expect(StationConfig.variant(animal.s, animal.v) ~= nil).toBeTruthy()
			end
			local base = StationRules.versionStats(animal.s, animal.v) :: StationConfig.Stats
			for _, stat in StationConfig.STATS do
				local x, b = (animal.stats :: any)[stat], (base :: any)[stat]
				local lo = math.max(StationConfig.STAT_MIN, math.floor(b * (100 - StationConfig.VARIANCE) / 100))
				local hi = math.floor(b * (100 + StationConfig.VARIANCE) / 100)
				expect(x >= lo and x <= hi).toBeTruthy()
			end
		end
		for _, o in (StationConfig.egg("meadow") :: StationConfig.Egg).odds do
			expect(seen[o.id]).toBe(true)
		end
		-- expected 5550 ppm = 111 in 20000; allow wide seeded noise
		expect(variants >= 60 and variants <= 170).toBeTruthy()
	end)

	it("reports the variant tier as the rarity, else the species rarity", function()
		expect(StationRules.rarity(owned("cheetah"))).toBe("rare")
		expect(StationRules.rarity(owned("bunny", "comet_bunny"))).toBe("mythic")
	end)
end)
