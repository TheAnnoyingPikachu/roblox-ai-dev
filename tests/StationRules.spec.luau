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

	it("has four species per team role, basic versions common to rare with stats in 1..100", function()
		local count = {}
		for _, sp in StationConfig.SPECIES do
			if sp.role ~= StationConfig.TITAN then
				expect(table.find(StationConfig.ROLES, sp.role) ~= nil).toBeTruthy()
				count[sp.role] = (count[sp.role] or 0) + 1
				expect(table.find(StationConfig.BASIC_RARITIES, sp.rarity) ~= nil).toBeTruthy()
				for _, stat in StationConfig.STATS do
					local x = (sp.stats :: any)[stat]
					expect(x >= 1 and x <= 100).toBeTruthy()
				end
			end
		end
		for _, role in StationConfig.ROLES do
			expect(count[role]).toBe(4)
		end
	end)

	it("makes Titans legendary, without variants, and bigger than any basic animal", function()
		local biggest, titans = 0, 0
		for _, sp in StationConfig.SPECIES do
			local total = sp.stats.speed + sp.stats.strength + sp.stats.stamina + sp.stats.mana + sp.stats.health
			if sp.role ~= StationConfig.TITAN then
				biggest = math.max(biggest, total)
			end
		end
		for _, sp in StationConfig.SPECIES do
			if sp.role == StationConfig.TITAN then
				titans += 1
				expect(sp.rarity).toBe("legendary")
				expect(#sp.variants).toBe(0)
				local total = sp.stats.speed + sp.stats.strength + sp.stats.stamina + sp.stats.mana + sp.stats.health
				expect(total > biggest).toBeTruthy()
				for _, stat in StationConfig.STATS do
					expect((sp.stats :: any)[stat] <= StationConfig.STAT_MAX).toBeTruthy()
				end
			end
		end
		expect(titans >= 1).toBeTruthy()
	end)

	it("gives every non-Titan exactly one variant per tier, with unique ids and a real twist stat", function()
		local ids = {}
		for _, sp in StationConfig.SPECIES do
			expect(ids[sp.id]).toBeNil()
			ids[sp.id] = true
			if sp.role ~= StationConfig.TITAN then
				expect(#sp.variants).toBe(#StationConfig.TIERS)
				for _, t in StationConfig.TIERS do
					local n = 0
					for _, va in sp.variants do
						n += if va.tier == t.tier then 1 else 0
					end
					expect(n).toBe(1)
				end
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

	it("keeps Titans rare: only in the dearest egg, under 5% together", function()
		for _, egg in StationConfig.EGGS do
			local bp = 0
			for _, o in egg.odds do
				local sp = StationConfig.species(o.id) :: StationConfig.Species
				bp += if sp.role == StationConfig.TITAN then o.bp else 0
			end
			if egg.id == "safari" then
				expect(bp > 0 and bp <= 500).toBeTruthy()
			else
				expect(bp).toBe(0)
			end
		end
	end)

	it("only finds a variant under its own species", function()
		expect(StationConfig.variant("cheetah", "golden_cheetah") ~= nil).toBeTruthy()
		expect(StationConfig.variant("hyena", "golden_cheetah")).toBeNil()
	end)
end)

describe("StationRules.versionStats", function()
	it("multiplies a variant's stats by its tier and adds the twist", function()
		local st = StationRules.versionStats("cheetah", "golden_cheetah") :: StationConfig.Stats -- legendary x2, +40 strength
		expect(st.speed).toBe(140)
		expect(st.strength).toBe(110)
		expect(st.stamina).toBe(40)
	end)

	it("refuses unknown species and mismatched variants", function()
		expect(StationRules.versionStats("dragon", nil)).toBeNil()
		expect(StationRules.versionStats("hyena", "sun_lion")).toBeNil()
	end)

	it("makes every variant stronger than its basic version in the basic's best stat", function()
		for _, sp in StationConfig.SPECIES do
			local basic = owned(sp.id)
			local t = StationRules.bestStat(basic)
			for _, va in sp.variants do
				expect(StationRules.stat(owned(sp.id, va.id), t) > StationRules.stat(basic, t)).toBeTruthy()
			end
		end
	end)
end)

describe("StationRules.train", function()
	it("adds one point of the station's stat per TRAIN_SECONDS and leaves the original alone", function()
		local c = owned("cheetah")
		local t = StationRules.train(c, "gym", StationConfig.TRAIN_SECONDS * 5)
		expect(StationRules.stat(t, "strength")).toBe(40)
		expect(StationRules.stat(t, "speed")).toBe(70)
		expect(StationRules.stat(c, "strength")).toBe(35)
	end)

	it("keeps part points between sessions", function()
		local c = owned("cheetah")
		local half = StationConfig.TRAIN_SECONDS / 2
		local t = StationRules.train(StationRules.train(c, "track", half), "track", half)
		expect(StationRules.stat(t, "speed")).toBe(71)
	end)

	it("stops at POTENTIAL x the hatched stat and never passes STAT_MAX", function()
		local c = StationRules.train(owned("cheetah"), "track", 1e9)
		expect(StationRules.stat(c, "speed")).toBe(70 * (1 + StationConfig.POTENTIAL))
		local m = StationRules.train(owned("cheetah", "lightning_cheetah"), "track", 1e9)
		expect(StationRules.stat(m, "speed")).toBe(StationConfig.STAT_MAX)
	end)

	it("trains Health at the Healing Spring, and Health is never the attack stat", function()
		local g = owned("gorilla") -- health 95 is its highest number
		expect(StationRules.bestStat(g)).toBe("stamina")
		local t = StationRules.train(g, "spring", StationConfig.TRAIN_SECONDS * 5)
		expect(StationRules.stat(t, "health")).toBe(100)
	end)

	it("ignores an unknown station or no time", function()
		local c = owned("cheetah")
		expect(StationRules.train(c, "moon", 600)).toBe(c)
		expect(StationRules.train(c, "track", 0)).toBe(c)
		expect(StationRules.train(c, "track", -60)).toBe(c)
	end)
end)

describe("StationRules roles and matchups", function()
	it("takes the role from the species, whatever is trained", function()
		expect(StationRules.role(owned("lion"))).toBe("attack")
		expect(StationRules.role(owned("gorilla"))).toBe("defense")
		expect(StationRules.role(owned("mandrill"))).toBe("utility")
		expect(StationRules.role(owned("elephant"))).toBe("titan")
		local trained = StationRules.train(owned("lion"), "library", 1e9)
		expect(StationRules.role(trained)).toBe("attack")
	end)

	it("makes the three roles one loop: each beats one and loses to one", function()
		for _, a in StationConfig.ROLES do
			local wins, losses = 0, 0
			for _, d in StationConfig.ROLES do
				local m = StationRules.matchup(a, d)
				wins += if m > 1 then 1 else 0
				losses += if m < 1 then 1 else 0
			end
			expect(wins).toBe(1)
			expect(losses).toBe(1)
			expect(StationRules.matchup(a, a)).toBe(1)
		end
		local seen, at = {}, "attack"
		for _ = 1, 3 do
			expect(seen[at]).toBeNil()
			seen[at] = true
			at = StationConfig.BEATS[at]
		end
		expect(at).toBe("attack")
	end)

	it("keeps the advantage slight and symmetric, and Titans outside the loop", function()
		expect(StationConfig.ADVANTAGE > 1 and StationConfig.ADVANTAGE <= 1.5).toBeTruthy()
		expect(StationRules.matchup("attack", "utility") * StationRules.matchup("utility", "attack")).toBe(1)
		for _, r in StationConfig.ROLES do
			expect(StationRules.matchup("titan", r)).toBe(1)
			expect(StationRules.matchup(r, "titan")).toBe(1)
		end
	end)
end)

describe("StationRules.hatch", function()
	it("picks species by cumulative basis points at the boundaries", function()
		local odds = (StationConfig.egg("meadow") :: StationConfig.Egg).odds
		expect(StationRules.pick(odds, 1)).toBe("hyena")
		expect(StationRules.pick(odds, 1700)).toBe("hyena")
		expect(StationRules.pick(odds, 1701)).toBe("jackal")
		expect(StationRules.pick(odds, 10000)).toBe("flamingo")
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

	it("hatches Titans from the Safari Egg, always as the basic version", function()
		local rng = Rng.seed(9)
		local titans = 0
		for _ = 1, 5000 do
			local a
			a, rng = StationRules.hatch("safari", rng)
			local animal = a :: StationRules.Owned
			if StationRules.role(animal) == "titan" then
				titans += 1
				expect(animal.v).toBeNil()
			end
		end
		-- expected 4% = 200 in 5000
		expect(titans >= 130 and titans <= 280).toBeTruthy()
	end)

	it("reports the variant tier as the rarity, else the species rarity", function()
		expect(StationRules.rarity(owned("lion"))).toBe("rare")
		expect(StationRules.rarity(owned("cheetah", "lightning_cheetah"))).toBe("mythic")
		expect(StationRules.rarity(owned("elephant"))).toBe("legendary")
	end)
end)
