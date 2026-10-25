--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")

local describe, it, expect = T.describe, T.it, T.expect

local function sum(odds: { GardenConfig.Odds }): number
	local total = 0
	for _, o in odds do
		total += o.bp
	end
	return total
end

local function ids(list: { any }): string
	local out = {}
	for _, item in list do
		table.insert(out, item.id)
	end
	return table.concat(out, " ")
end

describe("GardenConfig odds tables", function()
	it("sums every species row, mutation row, weather table and the sizes to 10,000", function()
		for _, egg in GardenConfig.EGGS do
			expect(`{egg.id} {sum(egg.odds)}`).toBe(`{egg.id} 10000`)
		end
		for _, w in GardenConfig.WEATHERS do
			expect(`{w.id} {sum(w.mutation)}`).toBe(`{w.id} 10000`)
			expect(ids(w.mutation)).toBe(ids(GardenConfig.MUTATIONS)) -- in MUTATIONS order
		end
		expect(sum(GardenConfig.WEATHER_ODDS.weekday)).toBe(10000)
		expect(sum(GardenConfig.WEATHER_ODDS.weekend)).toBe(10000)
		expect(sum(GardenConfig.SIZES :: any)).toBe(10000)
	end)

	it("uses only known species, and each Lucky Meter's top species is in its egg", function()
		for _, egg in GardenConfig.EGGS do
			for _, o in egg.odds do
				expect(GardenConfig.species(o.id) ~= nil).toBe(true)
			end
			expect(egg.top == nil).toBe(egg.meter == nil)
			if egg.top then
				local found = false
				for _, o in egg.odds do
					found = found or o.id == egg.top
				end
				expect(found).toBe(true)
			end
		end
	end)

	it("matches the E2, E3, E4 and F tables", function()
		local function row(odds: { GardenConfig.Odds }): string
			local out = {}
			for _, o in odds do
				table.insert(out, `{o.id} {o.bp}`)
			end
			return table.concat(out, ", ")
		end
		expect(row((GardenConfig.egg("meadow") :: any).odds)).toBe("bunny 6000, frog 3000, pup 900, cat 100")
		expect(row((GardenConfig.egg("forest") :: any).odds)).toBe("frog 4000, pup 3500, cat 2000, owl 500")
		expect(row((GardenConfig.egg("sunset") :: any).odds)).toBe("cat 4500, owl 3500, fox 1700, turtle 300")
		expect(row((GardenConfig.egg("moon") :: any).odds)).toBe("fox 5000, turtle 4000, lion 950, dragon 50")
		expect(row((GardenConfig.egg("star") :: any).odds)).toBe("turtle 5500, lion 4000, dragon 500")
		expect(row((GardenConfig.egg("starter") :: any).odds)).toBe("pup 10000")
		local mutation = {}
		for _, w in GardenConfig.WEATHERS do
			table.insert(mutation, `{w.id}: {row(w.mutation)}`)
		end
		expect(table.concat(mutation, "; ")).toBe(
			"clear: normal 9790, golden 200, moonlit 0, rainbow 10; "
				.. "sunbeam: normal 7450, golden 2500, moonlit 0, rainbow 50; "
				.. "moonfall: normal 7750, golden 200, moonlit 2000, rainbow 50; "
				.. "shower: normal 8500, golden 500, moonlit 0, rainbow 1000"
		)
		expect(row(GardenConfig.WEATHER_ODDS.weekday)).toBe("clear 5500, sunbeam 2500, moonfall 1500, shower 500")
		expect(row(GardenConfig.WEATHER_ODDS.weekend)).toBe("clear 3500, sunbeam 3500, moonfall 2000, shower 1000")
		local sizes = {}
		for _, z in GardenConfig.SIZES do
			table.insert(sizes, `{z.id} {z.mult} {z.scale} {z.bp}`)
		end
		expect(table.concat(sizes, ", ")).toBe("normal 1 1 8000, big 1.5 1.4 1700, huge 2.5 2 300")
	end)
end)

describe("GardenConfig eggs, species and costs", function()
	it("matches the D1 egg table, meters and hatch XP", function()
		local out = {}
		for _, e in GardenConfig.EGGS do
			local stock = if e.stock then `{e.stock.chance}%{e.stock.min}-{e.stock.max}` else "-"
			table.insert(
				out,
				`{e.id} {e.price or "-"} {e.grow} {e.level} {stock} {e.top or "-"} {e.meter or "-"} {e.xp}`
			)
		end
		expect(table.concat(out, " | ")).toBe(
			"starter - 8 1 - - - 10 | meadow 50 30 1 - cat 50 10 | forest 400 180 2 100%2-4 owl 30 25 | "
				.. "sunset 3000 900 5 60%1-2 turtle 40 60 | moon 25000 3600 10 30%1-1 dragon 100 150 | "
				.. "star 200000 14400 18 10%1-1 dragon 25 400"
		)
	end)

	it("matches the E1 species table and mutation multipliers", function()
		local out = {}
		for _, s in GardenConfig.SPECIES do
			table.insert(out, `{s.id} {s.rarity} {s.rate}`)
		end
		expect(table.concat(out, ", ")).toBe(
			"bunny common 1, frog common 2, pup uncommon 5, cat uncommon 12, owl rare 30, fox rare 70, "
				.. "turtle epic 180, lion legendary 500, dragon mythic 1500"
		)
		local mult = {}
		for _, m in GardenConfig.MUTATIONS do
			table.insert(mult, `{m.id} {m.mult}`)
		end
		expect(table.concat(mult, ", ")).toBe("normal 1, golden 3, moonlit 5, rainbow 10")
	end)

	it("matches the C1 bed costs and C2 pen and storage numbers", function()
		local beds = {}
		for n = 4, 12 do
			table.insert(beds, tostring(GardenConfig.BED_COSTS[n]))
		end
		expect(table.concat(beds, " ")).toBe("500 2000 8000 25000 75000 200000 500000 1200000 3000000")
		expect(GardenConfig.BED_COSTS[3]).toBeNil()
		expect(GardenConfig.BED_COSTS[13]).toBeNil()
		expect(GardenConfig.BEDS.start .. "-" .. GardenConfig.BEDS.max).toBe("3-12")
		expect(GardenConfig.PEN.start .. "-" .. GardenConfig.PEN.max .. " " .. GardenConfig.PEN.first).toBe("6-20 300")
		expect(GardenConfig.STORAGE).toBe(60)
	end)

	it("looks up ids and rarity indices", function()
		expect((GardenConfig.egg("moon") :: any).name).toBe("Moon Egg")
		expect(GardenConfig.egg("nope")).toBeNil()
		expect((GardenConfig.species("cat") :: any).name).toBe("Berry Cat")
		expect(GardenConfig.species("nope")).toBeNil()
		expect((GardenConfig.mutation("moonlit") :: any).mult).toBe(5)
		expect(GardenConfig.mutation("nope")).toBeNil()
		expect((GardenConfig.size("huge") :: any).scale).toBe(2)
		expect(GardenConfig.size("nope")).toBeNil()
		expect(GardenConfig.rarityIndex("bunny")).toBe(1)
		expect(GardenConfig.rarityIndex("owl")).toBe(GardenConfig.RARE)
		expect(GardenConfig.rarityIndex("dragon")).toBe(6)
		expect(GardenConfig.rarityIndex("nope")).toBe(0)
		expect(GardenConfig.RARITIES[GardenConfig.RARE].id).toBe("rare")
	end)
end)

describe("GardenConfig meta data", function()
	it("lists the H4 cosmetics with one level-1 default per slot", function()
		local out = {}
		for _, c in GardenConfig.COSMETICS do
			local unlock = if c.price then `${c.price}` elseif c.index then `i{c.index}` else `L{c.level}`
			table.insert(out, `{c.slot}:{c.id}:{unlock}`)
			expect(#c.colours > 0).toBe(true)
		end
		expect(table.concat(out, " ")).toBe(
			"fence:picket:L1 fence:bamboo:L3 fence:stone:L6 fence:hedge:L10 fence:crystal:L16 fence:golden:i20 "
				.. "fence:candy:$1000000 fence:rainbow:$1000000000 can:tin:L1 can:ducky:L4 can:flower:L8 "
				.. "can:moon:L14 can:star:$10000000 can:galaxy:$10000000000"
		)
	end)

	it("lists the H5 quests, daily and weekly rewards with minutes", function()
		local out = {}
		for _, q in GardenConfig.QUESTS do
			table.insert(out, `{q.id} {q.stat} {q.goal} {q.reward} {q.minutes}`)
		end
		expect(table.concat(out, ", ")).toBe(
			"hatch5 hatches 5 100 3, hatch15 hatches 15 150 6, water10 waters 10 100 3, water25 waters 25 150 6, "
				.. "collect50 collects 50 100 3, rare1 rareHatches 1 150 5, mutant1 mutants 1 200 8, "
				.. "release3 releases 3 100 3"
		)
		expect(table.concat(GardenConfig.DAILY, " ")).toBe("50 75 100 125 150 200 400")
		expect(table.concat(GardenConfig.DAILY_MINUTES, " ")).toBe("2 3 4 5 6 8 15")
		local W = GardenConfig.WEEKLY
		expect(`{W.days} {W.reward} {W.minutes}`).toBe("5 500 30")
	end)
end)
