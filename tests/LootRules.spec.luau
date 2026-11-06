--!strict
-- LootRules (architecture lantern 3.3, 8; GDD C3, C6, H4): counts, seeded stops, the first-stop
-- crate, odds that sum to 10,000 and 100,000-roll frequencies.
local T = require("./framework")
local LanternConfig = require("../src/shared/LanternConfig")
local LootRules = require("../src/shared/LootRules")
local Rng = require("../src/shared/Rng")

local describe, it, expect = T.describe, T.it, T.expect

type Line = LanternConfig.Line
local LINES: { Line } = { "forest", "lake" }

local function same(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, x in a do
		if not same(x, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

describe("LootRules.counts", function()
	it("equals the GDD C6 table for crews of 1 to 6", function()
		local rows = {}
		for n = 1, 6 do
			local c = LootRules.counts(n)
			table.insert(rows, `{c.coal}/{c.parts}/{c.oil}/{c.supply}/{c.critter}`)
		end
		expect(table.concat(rows, " ")).toBe("9/3/2/1/2 12/4/3/2/2 15/5/3/2/3 18/6/4/3/3 21/7/4/3/4 24/8/5/4/4")
		expect(same(LootRules.counts(0), LootRules.counts(1))).toBe(true) -- n is at least 1
		expect(same(LootRules.counts(9), LootRules.counts(6))).toBe(true)
	end)
end)

describe("LootRules.build", function()
	it("is deterministic for the same arguments and differs by seed", function()
		local a = LootRules.build(1234, 2, 3, "lake", 4, false)
		expect(same(a, LootRules.build(1234, 2, 3, "lake", 4, false))).toBe(true)
		expect(same(a, LootRules.build(1235, 2, 3, "lake", 4, false))).toBe(false)
		expect(`{a.tile} {a.line} {a.leg} {a.index} {a.n}`).toBe(`{LootRules.tileFor(1234, 2, 3, "lake")} lake 2 3 4`)
	end)

	it("holds the C3 counts, one item a big site and at most 3 a small site, every item free", function()
		for seed = 1, 60 do
			for n = 1, 6 do
				local stop = LootRules.build(seed, 1 + seed % 3, 1 + n % 3, LINES[1 + seed % 2], n, false)
				local c = LootRules.counts(n)
				local kinds, bigUse, smallUse, total = {}, {}, {}, 0
				for id, item in stop.items do
					expect(item.id).toBe(id)
					expect(item.state).toBe("free")
					expect(item.big).toBe(item.kind == "supply" or item.kind == "critter")
					kinds[item.kind] = (kinds[item.kind] or 0) + 1
					local use = if item.big then bigUse else smallUse
					use[item.site] = (use[item.site] or 0) + 1
					expect(item.species ~= nil).toBe(item.kind == "critter")
					total += 1
				end
				expect(total).toBe(c.coal + c.parts + c.oil + c.supply + c.critter)
				for _, kind in { "coal", "parts", "oil", "supply", "critter" } do
					expect(kinds[kind]).toBe((c :: any)[kind])
				end
				for _, k in bigUse do
					expect(k).toBe(1)
				end
				for _, k in smallUse do
					expect(k <= 3).toBe(true)
				end
			end
		end
	end)

	it("puts a critter crate on the 22-stud site on stop 1 of every run", function()
		for seed = 1, 200 do
			for _, n in { 1, 3, 6 } do
				local stop = LootRules.build(seed, 1, 1, "forest", n, true)
				local found = false
				for _, item in stop.items do
					if item.kind == "critter" and item.pos.z == 22 then
						found = true
						expect(item.rarity == "common" or item.rarity == "uncommon" or item.rarity == "rare").toBe(true)
					end
				end
				expect(found).toBe(true)
			end
		end
	end)

	it("places items on their tile's sites and rolls near crates (under 70 studs) on the near odds", function()
		for seed = 1, 300 do
			local stop = LootRules.build(seed, 3, 2, LINES[1 + seed % 2], 6, false)
			local tile = LanternConfig.tile(stop.tile) :: LanternConfig.Tile
			for _, item in stop.items do
				local site = if item.big then tile.big[item.site] else tile.small[item.site]
				expect(math.abs(item.pos.x - site.x) <= 1 and item.pos.z == site.z).toBe(true)
				if item.kind == "critter" and item.pos.z < LanternConfig.NEAR then
					expect(item.rarity ~= "epic" and item.rarity ~= "legendary").toBe(true)
				end
			end
		end
	end)

	it("never repeats a tile in a leg and only uses the line's tiles", function()
		for seed = 1, 300 do
			for _, line in LINES do
				for leg = 1, 3 do
					local seen = {}
					for index = 1, 3 do
						local tile = LootRules.tileFor(seed, leg, index, line)
						expect(seen[tile]).toBeNil()
						seen[tile] = true
						expect(table.find(LanternConfig.LINE_TILES[line], tile) ~= nil).toBe(true)
					end
				end
			end
		end
	end)
end)

describe("LootRules odds and rolls", function()
	it("sums to 10,000 for every line, leg, tile and band, without the Ember Kit", function()
		for _, line in LINES do
			for leg = 1, 3 do
				for _, tile in LanternConfig.LINE_TILES[line] do
					for _, far in { false, true } do
						local total = 0
						for id, bp in LootRules.odds(line, leg, tile, far) do
							expect(bp >= 0).toBe(true)
							expect(id ~= "emberkit").toBe(true)
							total += bp
						end
						expect(`{line} {leg} {tile} {far} {total}`).toBe(`{line} {leg} {tile} {far} 10000`)
					end
				end
			end
		end
	end)

	it("splits a rarity evenly on the tile, else on the line (H4 examples)", function()
		local windmill = LootRules.odds("forest", 1, "windmill", true)
		-- commons on the windmill: Moss Mouse and Burr Bunny; rares: none there, so both of the line
		expect(`{windmill.mossmouse} {windmill.burrbun} {windmill.puddlefrog}`).toBe("2300 2300 nil")
		expect(`{windmill.lanternbeetle} {windmill.acornowlet} {windmill.teapotcat} {windmill.reedfox}`).toBe(
			"1700 1700 750 750"
		)
		expect(`{windmill.mistfawn} {windmill.moonhare}`).toBe("500 nil")
		local farm = LootRules.odds("lake", 3, "farm", true)
		-- three lake-farm commons (mouse, frog, bunny) share 3,700: 1,234 to the first, 1,233 each after
		expect(`{farm.mossmouse} {farm.puddlefrog} {farm.burrbun} {farm.teapotcat}`).toBe("1234 1233 1233 1800")
		expect(`{farm.bellturtle} {farm.moonhare} {farm.mistfawn}`).toBe("800 300 nil")
	end)

	it(
		"rolls the Moon Hare only from leg 3 far crates, the Mist Fawn only on Forest, the Bell Turtle only on Lake",
		function()
			for _, line in LINES do
				for leg = 1, 3 do
					for _, tile in LanternConfig.LINE_TILES[line] do
						for _, far in { false, true } do
							local odds = LootRules.odds(line, leg, tile, far)
							expect(odds.moonhare ~= nil).toBe(leg == 3 and far)
							expect(odds.mistfawn ~= nil).toBe(line == "forest" and far)
							expect(odds.bellturtle ~= nil).toBe(line == "lake" and far)
						end
					end
				end
			end
			for seed = 1, 400 do
				for leg = 1, 3 do
					local stop = LootRules.build(seed, leg, 3, "lake", 6, false)
					for _, item in stop.items do
						if item.species == "moonhare" then
							expect(leg == 3 and item.pos.z >= LanternConfig.NEAR).toBe(true)
						end
						expect(item.species ~= "mistfawn" and item.species ~= "emberkit").toBe(true)
					end
				end
			end
		end
	)

	it("lands every rarity within 0.5 points of its row over 100,000 seeded rolls", function()
		local rows = {
			{ far = false, line = "forest", leg = 1, row = LanternConfig.ODDS.near },
			{ far = true, line = "forest", leg = 2, row = LanternConfig.ODDS.far.forest },
			{ far = true, line = "lake", leg = 2, row = LanternConfig.ODDS.far.lake },
			{ far = true, line = "forest", leg = 3, row = LanternConfig.ODDS.farLeg3.forest },
			{ far = true, line = "lake", leg = 3, row = LanternConfig.ODDS.farLeg3.lake },
		}
		for _, r in rows do
			local rng = Rng.seed(6006, r.leg, if r.far then 1 else 0)
			local hits: { [string]: number } = {}
			local rolls = 100000
			for _ = 1, rolls do
				local rarity
				rarity, rng = LootRules.rarity(rng, r.far, r.line :: Line, r.leg)
				hits[rarity] = (hits[rarity] or 0) + 1
			end
			for i, rarity in LanternConfig.RARITIES do
				local got = (hits[rarity] or 0) / rolls * 100
				local want = r.row[i] / 100
				expect(`{r.line} {r.leg} {rarity} {math.abs(got - want) <= 0.5}`).toBe(`{r.line} {r.leg} {rarity} true`)
			end
		end
	end)

	it("lands every species within 0.5 points of LootRules.odds over 100,000 crates on one tile", function()
		local rng = Rng.seed(77)
		local hits: { [string]: number } = {}
		local rolls = 100000
		for _ = 1, rolls do
			local rarity, species
			rarity, rng = LootRules.rarity(rng, true, "lake", 3)
			species, rng = LootRules.species(rng, rarity, "lake", "farm", 3)
			hits[species] = (hits[species] or 0) + 1
		end
		for id, bp in LootRules.odds("lake", 3, "farm", true) do
			expect(`{id} {math.abs((hits[id] or 0) / rolls * 100 - bp / 100) <= 0.5}`).toBe(`{id} true`)
		end
	end)
end)
