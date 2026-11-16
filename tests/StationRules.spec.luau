--!strict
local T = require("./framework")
local Rng = require("../src/shared/Rng")
local LevelRules = require("../src/shared/LevelRules")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

local function total(stats: StationConfig.Stats): number
	local n = 0
	for _, stat in StationConfig.STATS do
		n += (stats :: any)[stat]
	end
	return n
end

-- Seconds of training to take a stat from level 0 to level n.
local function secondsTo(n: number): number
	local total = 0
	for level = 1, n do
		total += StationRules.levelSeconds(level)
	end
	return total
end

describe("StationConfig", function()
	it("has egg odds that sum to 10000 and name real species, and rare drops that name real variants once", function()
		for _, egg in StationConfig.EGGS do
			local sum = 0
			for _, o in egg.odds do
				sum += o.bp
				expect(StationConfig.species(o.id) ~= nil).toBeTruthy()
			end
			expect(sum).toBe(10000)
			local listed = {}
			for _, row in egg.rare do
				expect(StationConfig.variant(row.s, row.v) ~= nil).toBeTruthy()
				expect(listed[row.v]).toBeNil()
				listed[row.v] = true
				expect(row.ppm > 0 and StationRules.PPM % row.ppm == 0).toBeTruthy() -- shown as "1 in N"
			end
		end
	end)

	it("covers every team role, with basic versions common to rare and stats in 1..100", function()
		local count = {}
		for _, sp in StationConfig.SPECIES do
			expect(table.find(StationConfig.GROUPS, sp.group) ~= nil).toBeTruthy()
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
			expect(count[role] >= 2).toBeTruthy()
		end
	end)

	it("has the small beta roster: a pack of cat, dog, meerkat, bird and the Titan; three solitary", function()
		local group = {}
		for _, sp in StationConfig.SPECIES do
			group[sp.id] = sp.group
		end
		expect(#StationConfig.SPECIES).toBe(8)
		for _, id in { "lion", "jackal", "meerkat", "flamingo", "elephant" } do
			expect(group[id]).toBe("pack")
		end
		for _, id in { "cheetah", "rhino", "tortoise" } do
			expect(group[id]).toBe("solitary")
		end
	end)

	it("has one Titan: legendary, with a mythic variant, bigger than any basic animal", function()
		local biggest, titans = 0, 0
		for _, sp in StationConfig.SPECIES do
			if sp.role ~= StationConfig.TITAN then
				biggest = math.max(biggest, total(sp.stats))
			end
		end
		for _, sp in StationConfig.SPECIES do
			if sp.role == StationConfig.TITAN then
				titans += 1
				expect(sp.id).toBe("elephant")
				expect(sp.rarity).toBe("legendary")
				expect(sp.variants[1].tier).toBe("mythic")
				expect(total(sp.stats) > biggest).toBeTruthy()
			end
		end
		expect(titans).toBe(1)
	end)

	it(
		"has no legendary-only egg: the Titan is a rare hatch from the Golden Egg; the Meadow and Wild Eggs are open from the start, the others unlock with the waves (10, 20)",
		function()
			local locked = 0
			for _, egg in StationConfig.EGGS do
				local titan, other = false, false
				for _, o in egg.odds do
					local sp = StationConfig.species(o.id) :: StationConfig.Species
					if sp.role == StationConfig.TITAN then
						titan = true
					else
						other = true
					end
				end
				expect(other).toBe(true) -- every egg drops ordinary animals
				if egg.id == "meadow" or egg.id == "wild" then
					expect(egg.wave).toBeNil()
					expect(titan).toBe(false)
				elseif egg.id ~= "golden" then
					locked += 1
					expect(egg.wave).toBe(10)
					expect(titan).toBe(false)
				elseif egg.wave then
					locked += 1
					expect(egg.wave).toBe(20)
					expect(titan).toBe(true)
					local share = 0
					for _, o in egg.odds do
						local sp = StationConfig.species(o.id) :: StationConfig.Species
						share += if sp.role == StationConfig.TITAN then o.bp else 0
					end
					expect(share <= 1000).toBeTruthy() -- the legendary stays a rare drop
				else
					expect(titan).toBe(false)
				end
				expect(egg.xp > 0).toBeTruthy()
			end
			expect(locked).toBe(2)
		end
	)

	it("gives every animal a variant, legendary or mythic, named <word>_<species>", function()
		local ids = {}
		for _, sp in StationConfig.SPECIES do
			expect(ids[sp.id]).toBeNil()
			ids[sp.id] = true
			expect(#sp.variants >= 1).toBeTruthy()
			-- a basic animal is never above epic, unless it is the Titan (legendary)
			if sp.role ~= StationConfig.TITAN then
				expect(table.find(StationConfig.BASIC_RARITIES, sp.rarity) ~= nil).toBeTruthy()
			end
			for _, va in sp.variants do
				expect(ids[va.id]).toBeNil()
				ids[va.id] = true
				expect(va.tier == "legendary" or va.tier == "mythic").toBeTruthy()
				expect(StationConfig.tier(va.tier) ~= nil).toBeTruthy()
				expect(table.find(StationConfig.STATS, va.twist) ~= nil).toBeTruthy()
				expect(string.match(va.id, "^%l+_" .. sp.id .. "$") ~= nil).toBeTruthy() -- the model's name comes from it
			end
		end
	end)

	it(
		"makes variants rare drops (1 in 400 or rarer; no mythic likelier than a legendary of its egg) and every tier legendary or higher",
		function()
			for _, egg in StationConfig.EGGS do
				local sum, legendary, mythic = 0, math.huge, 0 -- the egg's rarest legendary and likeliest mythic
				for _, row in egg.rare do
					sum += row.ppm
					expect(row.ppm <= 2500).toBeTruthy()
					if (StationConfig.variant(row.s, row.v) :: StationConfig.Variant).tier == "mythic" then
						mythic = math.max(mythic, row.ppm)
					else
						legendary = math.min(legendary, row.ppm)
					end
				end
				expect(sum <= 10000).toBeTruthy() -- at most 1 hatch in 100 is a variant
				expect(mythic <= legendary).toBeTruthy()
			end
			for _, t in StationConfig.TIERS do
				expect(t.tier == "legendary" or t.tier == "mythic").toBeTruthy()
				expect(table.find(StationConfig.BASIC_RARITIES, t.tier)).toBeNil()
				expect(table.find(StationConfig.RARITIES, t.tier) ~= nil).toBeTruthy()
			end
		end
	)

	it("gives every stat exactly one station and lets an egg hatch every species and every variant", function()
		for _, stat in StationConfig.STATS do
			local n = 0
			for _, st in StationConfig.STATIONS do
				n += if st.stat == stat then 1 else 0
			end
			expect(n).toBe(1)
		end
		for _, sp in StationConfig.SPECIES do
			local found = false
			for _, egg in StationConfig.EGGS do
				for _, o in egg.odds do
					found = found or o.id == sp.id
				end
			end
			expect(found).toBeTruthy()
			for _, va in sp.variants do
				local dropped = false
				for _, egg in StationConfig.EGGS do
					for _, row in egg.rare do
						dropped = dropped or (row.s == sp.id and row.v == va.id)
					end
				end
				expect(dropped).toBeTruthy()
			end
		end
	end)

	it("only finds a variant under its own species", function()
		expect(StationConfig.variant("cheetah", "lightning_cheetah") ~= nil).toBeTruthy()
		expect(StationConfig.variant("jackal", "lightning_cheetah")).toBeNil()
	end)
end)

describe("StationRules.versionStats", function()
	it("multiplies a variant's stats by its tier and adds the twist", function()
		local st = StationRules.versionStats("jackal", "pharaoh_jackal") :: StationConfig.Stats -- legendary x2, +40 mana
		expect(st.speed).toBe(84)
		expect(st.mana).toBe(76)
		expect(st.defence).toBe(20)
	end)

	it("refuses unknown species and mismatched variants", function()
		expect(StationRules.versionStats("dragon", nil)).toBeNil()
		expect(StationRules.versionStats("jackal", "sun_lion")).toBeNil()
	end)

	it("makes every variant stronger than its basic version in every stat", function()
		for _, sp in StationConfig.SPECIES do
			local basic = owned(sp.id)
			for _, va in sp.variants do
				for _, stat in StationConfig.STATS do
					expect(StationRules.stat(owned(sp.id, va.id), stat) > StationRules.stat(basic, stat)).toBeTruthy()
				end
			end
		end
	end)
end)

describe("StationRules stat levels", function()
	it("levels a stat with time on its station, each level taking longer, and leaves the original alone", function()
		local c = owned("cheetah")
		expect(StationRules.level(c, "strength")).toBe(0)
		expect(StationRules.level(StationRules.train(c, "gym", secondsTo(1)), "strength")).toBe(1)
		expect(StationRules.level(StationRules.train(c, "gym", secondsTo(2) - 1), "strength")).toBe(1)
		local t = StationRules.train(c, "gym", secondsTo(7))
		expect(StationRules.level(t, "strength")).toBe(7)
		expect(StationRules.stat(t, "strength")).toBe(38) -- 35 x (1 + 7/70) = 38.5
		expect(StationRules.stat(t, "speed")).toBe(70)
		expect(StationRules.level(c, "strength")).toBe(0)
	end)

	it("makes every level take a little longer, with each level above 60 taking 24 to 48 hours", function()
		local hour = 3600
		expect(StationRules.levelSeconds(1)).toBe(120)
		for n = 2, StationConfig.MAX_LEVEL do
			local now, before = StationRules.levelSeconds(n), StationRules.levelSeconds(n - 1)
			expect(now > before).toBeTruthy()
			expect(now < before * 1.15).toBeTruthy() -- a little longer, never a jump
			expect(now == math.floor(now)).toBeTruthy() -- whole seconds
		end
		expect(StationRules.levelSeconds(60) < 24 * hour).toBeTruthy()
		expect(StationRules.levelSeconds(61)).toBe(24 * hour)
		expect(StationRules.levelSeconds(70)).toBe(48 * hour)
		for n = 61, 70 do
			local t = StationRules.levelSeconds(n)
			expect(t >= 24 * hour and t <= 48 * hour).toBeTruthy()
		end
		-- slower than the old 30 x n seconds at every level
		for n = 1, 70 do
			expect(StationRules.levelSeconds(n) > 30 * n).toBeTruthy()
		end
		-- one stat from 0 to 70 is about three weeks; the first 20 levels a couple of hours
		expect(secondsTo(70) > 20 * 24 * hour and secondsTo(70) < 26 * 24 * hour).toBeTruthy()
		expect(secondsTo(20) > 2 * hour and secondsTo(20) < 3 * hour).toBeTruthy()
	end)

	it("keeps part of a level between sessions", function()
		local c = owned("cheetah")
		local half = secondsTo(1) / 2
		local once = StationRules.train(c, "track", half)
		expect(StationRules.level(once, "speed")).toBe(0)
		expect(StationRules.level(StationRules.train(once, "track", half), "speed")).toBe(1)
	end)

	it("stops every stat at level 70, where the stat is doubled", function()
		for _, st in StationConfig.STATIONS do
			local c = owned("cheetah")
			local almost = StationRules.train(c, st.id, secondsTo(StationConfig.MAX_LEVEL) - 1)
			expect(StationRules.level(almost, st.stat)).toBe(69)
			local done = StationRules.train(c, st.id, secondsTo(StationConfig.MAX_LEVEL))
			expect(StationRules.level(done, st.stat)).toBe(70)
			local more = StationRules.train(done, st.id, 1e9)
			expect(StationRules.level(more, st.stat)).toBe(70)
			expect(StationRules.stat(more, st.stat)).toBe(2 * (c.stats :: any)[st.stat])
		end
		expect(StationConfig.MAX_LEVEL).toBe(70)
	end)

	it("gives exact whole numbers where the maths is exact", function()
		-- 35 x 84 / 70 is exactly 42; floating point multiplication by 1.2 could give 41
		local c = StationRules.train(owned("cheetah"), "gym", secondsTo(14))
		expect(StationRules.stat(c, "strength")).toBe(42)
	end)

	it("ignores an unknown station or no time", function()
		local c = owned("cheetah")
		expect(StationRules.train(c, "moon", 600)).toBe(c)
		expect(StationRules.train(c, "track", 0)).toBe(c)
		expect(StationRules.train(c, "track", -60)).toBe(c)
	end)
end)

describe("StationRules roles", function()
	it("takes the role from the species, whatever is trained", function()
		expect(StationRules.role(owned("lion"))).toBe("attack")
		expect(StationRules.role(owned("rhino"))).toBe("defense")
		expect(StationRules.role(owned("meerkat"))).toBe("utility")
		expect(StationRules.role(owned("elephant"))).toBe("titan")
		local trained = StationRules.train(owned("lion"), "library", 1e9)
		expect(StationRules.role(trained)).toBe("attack")
	end)
end)

describe("StationRules.hatch", function()
	it("picks species by cumulative basis points at the boundaries", function()
		local odds = (StationConfig.egg("meadow") :: StationConfig.Egg).odds
		expect(StationRules.pick(odds, 1)).toBe("jackal")
		expect(StationRules.pick(odds, 3400)).toBe("jackal")
		expect(StationRules.pick(odds, 3401)).toBe("tortoise")
		expect(StationRules.pick(odds, 10000)).toBe("meerkat")
	end)

	it("picks an egg's rare drops in the order it lists them, a basic animal past their total", function()
		local rare = (StationConfig.egg("meadow") :: StationConfig.Egg).rare
		local function drop(r: number): string?
			local row = StationRules.pickRare(rare, r)
			return row and row.v
		end
		expect(drop(1)).toBe("pharaoh_jackal")
		expect(drop(200)).toBe("pharaoh_jackal")
		expect(drop(201)).toBe("gemshell_tortoise")
		expect(drop(600)).toBe("storm_meerkat")
		expect(drop(601)).toBeNil()
		expect(drop(1_000_000)).toBeNil()
	end)

	it("hatches a variant only from an egg that lists it, as its own animal", function()
		local rng = Rng.seed(7)
		local sphinx = 0
		for _ = 1, 60000 do -- the Safari Egg has no Jackal, but lists the Sphinx Jackal (1 in 5,000: about 12 here)
			local a
			a, rng = StationRules.hatch("safari", rng)
			local animal = a :: StationRules.Owned
			if animal.s == "jackal" then
				sphinx += 1
				expect(animal.v).toBe("sphinx_jackal")
			end
			expect(animal.v ~= "pharaoh_jackal" and animal.v ~= "sun_lion").toBeTruthy() -- not in this egg
		end
		expect(sphinx >= 2 and sphinx <= 30).toBeTruthy()
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
		for _, stat in StationConfig.STATS do
			expect(StationRules.level(a1, stat)).toBe(StationRules.level(a2, stat))
		end
	end)

	it("rolls a base level from 1 to 15, each higher number less likely than the one before", function()
		expect(StationConfig.BASE_MAX).toBe(15)
		expect(StationRules.BASE_ROLL).toBe(630)
		expect(StationRules.baseLevel(1)).toBe(1)
		expect(StationRules.baseLevel(77)).toBe(1)
		expect(StationRules.baseLevel(78)).toBe(2)
		expect(StationRules.baseLevel(623)).toBe(14)
		expect(StationRules.baseLevel(624)).toBe(15)
		expect(StationRules.baseLevel(630)).toBe(15)
		local share = table.create(15, 0)
		for r = 1, StationRules.BASE_ROLL do
			share[StationRules.baseLevel(r)] += 1
		end
		for level = 2, 15 do
			expect(share[level - 1] - share[level]).toBe(StationConfig.BASE_STEP) -- the same step down each time
		end
		expect(share[15] * 90).toBe(StationRules.BASE_ROLL) -- a 15 is exactly 1 in 90
	end)

	it("hatches mostly basics and rare variants, with the version's stats and base levels of 1 to 15", function()
		local rng = Rng.seed(42)
		local seen, variants = {}, 0
		local tally = table.create(StationConfig.BASE_MAX, 0)
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
			local maxed = 0
			for _, stat in StationConfig.STATS do
				expect((animal.stats :: any)[stat]).toBe((base :: any)[stat])
				local level = StationRules.level(animal, stat)
				if level == StationConfig.MAX_LEVEL then
					maxed += 1 -- the jackpot (about 1 in 100,000 hatches)
				else
					expect(level >= 1 and level <= StationConfig.BASE_MAX).toBeTruthy()
					tally[level] += 1
				end
			end
			expect(maxed <= 1).toBeTruthy()
		end
		for _, o in (StationConfig.egg("meadow") :: StationConfig.Egg).odds do
			expect(seen[o.id]).toBe(true)
		end
		-- the Meadow Egg lists three legendary variants at 200 ppm each: 12 in 20000; allow wide seeded noise
		expect(variants >= 2 and variants <= 25).toBeTruthy()
		-- 120,000 base levels: low numbers are common, a 15 is rare but happens
		expect(tally[1] > tally[5] and tally[5] > tally[10] and tally[10] > tally[15]).toBeTruthy()
		expect(tally[15] > 0).toBeTruthy()
	end)

	it(
		"hatches about 1 animal in 200 in a rainbow coat, with the hatched stats of the same animal without it",
		function()
			expect(StationConfig.RAINBOW_PPM * 200).toBe(StationRules.PPM)
			local rng = Rng.seed(11)
			local coats, same = 0, true
			for _ = 1, 20000 do
				local a
				a, rng = StationRules.hatch("meadow", rng)
				local animal = a :: StationRules.Owned
				if animal.rainbow then
					coats += 1
					local plain = StationRules.versionStats(animal.s, animal.v) :: StationConfig.Stats
					for _, stat in StationConfig.STATS do
						same = same and (animal.stats :: any)[stat] == (plain :: any)[stat]
					end
				else
					same = same and animal.rainbow == nil -- absent, never false: nothing extra in a save
				end
			end
			expect(coats >= 60 and coats <= 140).toBeTruthy() -- 100 expected
			expect(same).toBe(true)
			-- forced on and off: any egg, any animal
			local real = StationConfig.RAINBOW_PPM
			for _, forced in { StationRules.PPM, 0 } do
				StationConfig.RAINBOW_PPM = forced
				for _, egg in StationConfig.EGGS do
					local a
					a, rng = StationRules.hatch(egg.id, rng)
					same = same and (a :: StationRules.Owned).rainbow == (if forced == 0 then nil else true)
				end
			end
			StationConfig.RAINBOW_PPM = real
			expect(same).toBe(true)
		end
	)

	it("gives a rainbow animal 5% more of every stat, rounded up, at any level", function()
		expect(StationConfig.RAINBOW_BONUS).toBe(5)
		local function lion(level: number, rainbow: boolean?): StationRules.Owned
			local trained = {} :: any
			for _, stat in StationConfig.STATS do
				trained[stat] = level
			end
			return {
				s = "lion",
				stats = StationRules.versionStats("lion", nil) :: StationConfig.Stats,
				trained = trained,
				rainbow = rainbow,
			}
		end
		for _, level in { 0, 1, 35, StationConfig.MAX_LEVEL } do
			for _, stat in StationConfig.STATS do
				local plain = StationRules.stat(lion(level), stat)
				local coated = StationRules.stat(lion(level, true), stat)
				expect(coated).toBe(plain + math.ceil(plain * 5 / 100))
				expect(coated > plain).toBeTruthy() -- every stat gains at least 1
			end
		end
		-- exact where 5% is a whole number, one up where it is not
		local stats = { speed = 100, strength = 8, stamina = 20, mana = 21, health = 1, defence = 399 }
		local want = { speed = 105, strength = 9, stamina = 21, mana = 23, health = 2, defence = 419 }
		for _, stat in StationConfig.STATS do
			expect(StationRules.stat({ s = "lion", stats = stats, rainbow = true }, stat)).toBe((want :: any)[stat])
			expect(StationRules.stat({ s = "lion", stats = stats }, stat)).toBe((stats :: any)[stat])
		end
	end)

	it("has a tiny jackpot that hatches exactly one stat at level 70", function()
		expect(StationConfig.JACKPOT_PPM * 10000).toBe(StationRules.PPM) -- 1 in 10,000
		-- force the jackpot on, then off, to check both paths; put the real chance back after
		local real = StationConfig.JACKPOT_PPM
		local good = true
		local rng = Rng.seed(5)
		for _, forced in { StationRules.PPM, 0 } do
			StationConfig.JACKPOT_PPM = forced
			for _ = 1, 500 do
				local a
				a, rng = StationRules.hatch("wild", rng)
				local maxed = 0
				for _, stat in StationConfig.STATS do
					local level = StationRules.level(a :: StationRules.Owned, stat)
					if level == StationConfig.MAX_LEVEL then
						maxed += 1
					elseif level < 1 or level > StationConfig.BASE_MAX then
						good = false
					end
				end
				good = good and maxed == (if forced == 0 then 0 else 1)
			end
		end
		StationConfig.JACKPOT_PPM = real
		expect(good).toBe(true)
	end)

	it("drops the Titan from the Golden Egg about 1 time in 20, now and then as one of its variants", function()
		local rng = Rng.seed(9)
		local titans, special, variants = 0, 0, 0
		for _ = 1, 40000 do -- the Golden Egg lists both Titan variants (1 in 2,000 and 1 in 20,000): about 22 here
			local a
			a, rng = StationRules.hatch("golden", rng)
			local animal = a :: StationRules.Owned
			if StationRules.role(animal) == StationConfig.TITAN then
				titans += 1
				expect(animal.s).toBe("elephant")
				if animal.v then
					special += 1
					expect(StationConfig.variant("elephant", animal.v) ~= nil).toBeTruthy()
				end
			elseif animal.v then
				variants += 1
			end
		end
		expect(titans >= 1700 and titans <= 2300).toBeTruthy() -- 5% of 40,000 = 2,000
		expect(special >= 1 and special <= 40).toBeTruthy() -- rare, but they do hatch
		expect(variants > 0).toBeTruthy()
	end)

	it("reports the variant tier as the rarity, else the species rarity", function()
		expect(StationRules.rarity(owned("lion"))).toBe("rare")
		expect(StationRules.rarity(owned("cheetah", "lightning_cheetah"))).toBe("mythic")
		expect(StationRules.rarity(owned("elephant"))).toBe("legendary")
	end)
end)

describe("StationConfig foes (the Hexbound)", function()
	it(
		"are knights, archers, mages, ogres and dragons with real roles, groups and stats, and are not animals",
		function()
			local ids = {}
			for _, sp in StationConfig.SPECIES do
				ids[sp.id] = true
				for _, va in sp.variants do
					ids[va.id] = true
				end
			end
			for _, f in StationConfig.FOES do
				expect(ids[f.id]).toBeNil()
				ids[f.id] = true
				expect(table.find(StationConfig.FOE_KINDS, f.kind) ~= nil).toBeTruthy()
				expect(table.find(StationConfig.ROLES, f.role) ~= nil).toBeTruthy()
				expect(table.find(StationConfig.GROUPS, f.group) ~= nil).toBeTruthy()
				for _, stat in StationConfig.STATS do
					local x = (f.stats :: any)[stat]
					expect(x >= StationConfig.STAT_MIN and x <= StationConfig.STAT_MAX).toBeTruthy()
				end
				expect(StationConfig.species(f.id)).toBeNil()
				expect(StationConfig.foe(f.id)).toBe(f)
				expect(StationRules.role({ s = f.id, stats = f.stats })).toBe(f.role)
				if f.kind == "dragon" then
					expect(f.from).toBeNil()
					expect(f.boss ~= nil and f.boss % LevelRules.BOSS_EVERY == 0).toBeTruthy()
				else
					expect(f.boss).toBeNil()
					expect(f.from ~= nil).toBeTruthy()
				end
			end
		end
	)

	it("open with all three roles from wave 1 and a dragon for the first boss wave", function()
		local roles, first = {}, math.huge
		for _, f in StationConfig.FOES do
			if f.from == 1 then
				roles[f.role] = true
			end
			if f.boss then
				first = math.min(first, f.boss)
			end
		end
		for _, role in StationConfig.ROLES do
			expect(roles[role]).toBe(true)
		end
		expect(first).toBe(LevelRules.BOSS_EVERY)
		expect(StationConfig.foe("dragon")).toBeNil()
		expect(StationConfig.foe("elephant")).toBeNil() -- an animal is not a foe either
	end)
end)
