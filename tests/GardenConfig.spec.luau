--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local Rng = require("../src/shared/Rng")
local WorldRules = require("../src/shared/WorldRules")

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

local function weatherMutations(): string
	local out = {}
	for _, m in GardenConfig.MUTATIONS do
		if GardenConfig.fixedBy(m.id) == nil then
			table.insert(out, m.id)
		end
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
			expect(ids(w.mutation)).toBe(weatherMutations()) -- MUTATIONS order without egg-only mutations
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
		expect(row((GardenConfig.egg("celestial") :: any).odds)).toBe("lion 8500, dragon 1500")
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
				.. "star 200000 14400 18 10%1-1 dragon 25 400 | celestial 1000000000 28800 25 5%1-1 dragon 10 1000"
		)
	end)

	it("keeps every sold egg on a Lucky Meter and the Celestial Egg last, fixed to its mutation", function()
		for _, e in GardenConfig.EGGS do
			if e.price then
				expect(`{e.id} {e.top ~= nil and e.meter ~= nil}`).toBe(`{e.id} true`)
			end
			expect(e.mutation).toBe(if e.id == "celestial" then "celestial" else nil)
		end
		expect(GardenConfig.EGGS[#GardenConfig.EGGS].id).toBe("celestial")
		expect(#GardenConfig.EGGS).toBe(7) -- stock index 6
		expect((GardenConfig.egg("celestial") :: any).name).toBe("Celestial Egg")
	end)

	it("keeps the stock of every existing egg for fixed windows, and seeds Celestial with index 6", function()
		-- Copied from WorldRules.stockFor before the Celestial Egg was added.
		local pinned = { "2 1 0 0", "4 2 0 0", "4 0 0 0", "4 0 0 1", "3 0 0 0", "3 2 1 0" }
		for i, row in pinned do
			local window = 6_000_000 + i - 1
			local s = WorldRules.stockFor(window)
			expect(`{s.forest} {s.sunset} {s.moon} {s.star}`).toBe(row)
			local r, state = Rng.int(Rng.seed(window, 9001, 6), 1, 10000)
			expect(s.celestial).toBe(if r <= 500 then (Rng.int(state, 1, 1)) else 0)
		end
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
		expect(table.concat(mult, ", ")).toBe("normal 1, golden 3, moonlit 5, rainbow 10, celestial 20")
	end)

	it("fixes celestial to its egg, in no weather table", function()
		expect((GardenConfig.fixedBy("celestial") :: any).id).toBe("celestial")
		for _, id in { "normal", "golden", "moonlit", "rainbow", "nope" } do
			expect(GardenConfig.fixedBy(id)).toBeNil()
		end
		expect(weatherMutations()).toBe("normal golden moonlit rainbow")
		for _, w in GardenConfig.WEATHERS do
			expect(#w.mutation).toBe(4)
			for _, o in w.mutation do
				expect(o.id == "celestial").toBe(false)
			end
		end
	end)

	it("counts 38 indexable pairs, the only new ones being lion:celestial and dragon:celestial", function()
		local count = 0
		local special = {}
		for _, s in GardenConfig.SPECIES do
			for _, m in GardenConfig.MUTATIONS do
				if GardenConfig.indexable(s.id, m.id) then
					count += 1
					if m.id == "celestial" then
						table.insert(special, `{s.id}:{m.id}`)
					end
				end
			end
		end
		expect(count).toBe(GardenConfig.INDEX_SIZE)
		expect(count).toBe(38)
		expect(table.concat(special, " ")).toBe("lion:celestial dragon:celestial")
		expect(GardenConfig.indexable("nope", "normal")).toBe(false)
		expect(GardenConfig.indexable("bunny", "nope")).toBe(false)
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

describe("GardenConfig Splash Dash (GDD T, decision 0012)", function()
	local D = GardenConfig.DASH

	it("matches the decision's rule values", function()
		expect(`{D.name} {D.minPlayers} {D.maxPlayers} {D.countdown} {D.starting} {D.limit} {D.grace}`).toBe(
			"Splash Dash 3 6 15 5 120 20"
		)
		expect(`{D.prizeEgg} {D.prizesPerDay} {D.coinsBase} {D.coinsMinutes} {D.coinsPerDay}`).toBe("moon 3 100 1 6")
		expect(`{D.fellY} {D.zone.radius} {D.zone.height} {D.minFinish}`).toBe("125 16 14 28")
		expect(`{D.maxSpeed} {D.slack} {D.maxStrikes} {D.settle} {D.knockMax} {D.swing}`).toBe("95 12 3 1 70 50")
		expect(GardenConfig.PRIZE_STORE).toBe(1_000_000)
		expect(GardenConfig.egg(D.prizeEgg) ~= nil).toBe(true)
	end)

	it("lays the course out over 540 studs and keeps every knock under the limit", function()
		local path = 0
		local from = D.start
		local spots = {}
		for _, c in D.checkpoints do
			path += math.abs(c.x - from.x) + math.abs(c.z - from.z)
			table.insert(spots, `{c.x},{c.y},{c.z}`)
			from = c
		end
		expect(path).toBe(540)
		expect(`{D.start.x},{D.start.y},{D.start.z}`).toBe("-120,140,300")
		expect(table.concat(spots, " ")).toBe("-20,140,300 100,140,300 100,140,400 -20,140,400 -120,140,400")
		local kinds = {}
		for _, o in D.obstacles do
			kinds[o.kind] = (kinds[o.kind] or 0) + 1
			expect(o.model).toBe(`dash_{o.kind}`)
			expect(math.sqrt(o.knock ^ 2 + 20 ^ 2) <= D.knockMax).toBe(true)
			expect(o.knock == 0).toBe(o.kind == "platform")
		end
		expect(`{kinds.sweeper} {kinds.ball} {kinds.pendulum} {kinds.platform}`).toBe("3 4 3 4")
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
