--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local MetaRules = require("../src/shared/MetaRules")
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

	it("matches the U2, E3, E4 and F tables", function()
		local function row(odds: { GardenConfig.Odds }): string
			local out = {}
			for _, o in odds do
				table.insert(out, `{o.id} {o.bp}`)
			end
			return table.concat(out, ", ")
		end
		expect(row((GardenConfig.egg("meadow") :: any).odds)).toBe(
			"bunny 5800, frog 2400, duck 1100, pup 500, lamb 100, cat 100"
		)
		expect(row((GardenConfig.egg("forest") :: any).odds)).toBe(
			"frog 3000, pup 3000, lamb 1500, cat 1700, owl 500, hedgehog 300"
		)
		expect(row((GardenConfig.egg("sunset") :: any).odds)).toBe(
			"cat 3500, owl 2500, hedgehog 1500, fox 1700, turtle 300, deer 300, panda 200"
		)
		expect(row((GardenConfig.egg("moon") :: any).odds)).toBe(
			"fox 4000, turtle 2500, deer 1500, panda 1000, lion 600, unicorn 350, dragon 50"
		)
		expect(row((GardenConfig.egg("star") :: any).odds)).toBe(
			"turtle 3000, panda 2500, lion 2500, unicorn 1500, dragon 400, phoenix 100"
		)
		expect(row((GardenConfig.egg("celestial") :: any).odds)).toBe(
			"lion 6000, unicorn 2500, dragon 1200, phoenix 300"
		)
		expect(row((GardenConfig.egg("aurora") :: any).odds)).toBe(
			"dragon 3500, phoenix 3000, whale 2000, kirin 1200, axolotl 300"
		)
		expect(row((GardenConfig.egg("starter") :: any).odds)).toBe("pup 10000")
		local mutation = {}
		for _, w in GardenConfig.WEATHERS do
			table.insert(mutation, `{w.id}: {row(w.mutation)}`)
		end
		expect(table.concat(mutation, "; ")).toBe(
			"clear: normal 9790, golden 200, moonlit 0, rainbow 10; "
				.. "sunbeam: normal 7450, golden 2500, moonlit 0, rainbow 50; "
				.. "moonfall: normal 7750, golden 200, moonlit 2000, rainbow 50; "
				.. "shower: normal 8500, golden 500, moonlit 0, rainbow 1000; "
				.. "snowfall: normal 8800, golden 1000, moonlit 150, rainbow 50; "
				.. "petals: normal 8500, golden 1000, moonlit 0, rainbow 500; "
				.. "thunder: normal 8800, golden 800, moonlit 300, rainbow 100"
		)
		expect(row(GardenConfig.WEATHER_ODDS.weekday)).toBe(
			"clear 5200, sunbeam 2500, moonfall 1500, shower 500, snowfall 100, petals 100, thunder 100"
		)
		expect(row(GardenConfig.WEATHER_ODDS.weekend)).toBe(
			"clear 2900, sunbeam 3500, moonfall 2000, shower 1000, snowfall 200, petals 200, thunder 200"
		)
		expect(GardenConfig.WEATHER_EVENT_BONUS).toBe(800)
		expect(table.concat(GardenConfig.RARE_WEATHERS, " ")).toBe("snowfall petals thunder")
		expect(#GardenConfig.WEATHERS).toBe(7)
		local sizes = {}
		for _, z in GardenConfig.SIZES do
			table.insert(sizes, `{z.id} {z.mult} {z.scale} {z.bp}`)
		end
		expect(table.concat(sizes, ", ")).toBe("normal 1 1 8000, big 1.5 1.4 1700, huge 2.5 2 300")
	end)

	it("matches decision 0015: charms, the Moth substitution, trade, milestone and name values", function()
		local charms = {}
		for _, c in GardenConfig.CHARMS do
			table.insert(charms, `{c.id} {c.name} {c.mult} {c.weather} {c.bp}`)
			expect(GardenConfig.charm(c.id)).toBe(c)
			expect(GardenConfig.charmFor(c.weather)).toBe(c)
			expect(GardenConfig.isRare(c.weather)).toBe(true)
		end
		expect(table.concat(charms, ", ")).toBe(
			"frosted Frosted 1.5 snowfall 2500, blooming Blooming 2 petals 1500, stormy Stormy 3 thunder 1000"
		)
		expect(GardenConfig.charm("none")).toBeNil()
		expect(GardenConfig.charm("nope")).toBeNil()
		for _, w in { "clear", "sunbeam", "moonfall", "shower", "nope" } do
			expect(GardenConfig.charmFor(w)).toBeNil()
			expect(GardenConfig.isRare(w)).toBe(false)
		end
		local events = {}
		for _, e in GardenConfig.EGGS do
			if e.event then
				table.insert(events, `{e.id} {e.event.s} {e.event.bp} {e.event.from}`)
			end
		end
		expect(table.concat(events, ", ")).toBe("forest moth 300 frog, sunset moth 300 cat")
		local TR = GardenConfig.TRADE
		expect(
			`{TR.perDay} {TR.range} {TR.fair} {TR.hold} {TR.confirm} {TR.invite} {TR.pick} {TR.undo} {TR.kept} {TR.emoteGap} {TR.declineGap} {TR.emotes}`
		).toBe("3 15 0.5 10 20 30 120 600 30 1 60 4")
		local milestones = {}
		for _, m in GardenConfig.MILESTONES do
			table.insert(milestones, `{m.at} {m.coins} {m.title or "-"} {m.egg or "-"}`)
		end
		expect(table.concat(milestones, ", ")).toBe(
			"20 5000 Hatchling Keeper -, 40 50000 - -, 60 1000000 - -, 80 0 Garden Legend aurora"
		)
		expect(`{GardenConfig.NAME.max} {GardenConfig.NAME.cooldown} {GardenConfig.NAME.perDay}`).toBe("20 10 3")
		expect(GardenConfig.SEEDS.event).toBe(7777)
	end)
end)

describe("GardenConfig eggs, species and costs", function()
	it("matches the D1 and U3 egg table, meters and hatch XP", function()
		local out = {}
		for _, e in GardenConfig.EGGS do
			local stock = if e.stock then `{e.stock.chance}%{e.stock.min}-{e.stock.max}` else "-"
			table.insert(
				out,
				`{e.id} {e.price or "-"} {e.grow} {e.level} {stock} {e.top or "-"} {e.meter or "-"} {e.xp}`
			)
		end
		expect(table.concat(out, " | ")).toBe(
			"starter - 8 1 - - - 10 | meadow 50 30 1 - cat 50 10 | forest 400 180 2 100%2-4 hedgehog 30 25 | "
				.. "sunset 3000 900 5 60%1-2 panda 40 60 | moon 25000 3600 10 30%1-1 dragon 100 150 | "
				.. "star 200000 14400 18 10%1-1 phoenix 25 400 | celestial 1000000000 28800 25 5%1-1 phoenix 10 1000 | "
				.. "aurora 5000000000 43200 32 3%1-1 axolotl 20 3000 | "
				.. "weekly - 3600 1 - capybara 12 150 | monthly - 14400 1 - snowleopard 8 400"
		)
	end)

	it(
		"keeps every sold egg on a Lucky Meter, Celestial fixed to its mutation and the Aurora Egg the last sold",
		function()
			local lastSold = ""
			for _, e in GardenConfig.EGGS do
				if e.price then
					expect(`{e.id} {e.top ~= nil and e.meter ~= nil}`).toBe(`{e.id} true`)
					lastSold = e.id
				end
				expect(e.mutation).toBe(if e.id == "celestial" then "celestial" else nil)
			end
			expect(lastSold).toBe("aurora") -- stock index 7
			expect(#GardenConfig.EGGS).toBe(10)
			expect((GardenConfig.egg("celestial") :: any).name).toBe("Celestial Egg")
			expect((GardenConfig.egg("aurora") :: any).name).toBe("Aurora Egg")
		end
	)

	-- GDD X3.3 and X3.4, decision 0017.
	it("lists the Weekly and Monthly Eggs after aurora: exclusive, unpriced, unstocked, level 1, metered", function()
		local n = #GardenConfig.EGGS
		expect(`{GardenConfig.EGGS[n - 1].id} {GardenConfig.EGGS[n].id}`).toBe("weekly monthly")
		local exclusiveSpecies: { [string]: boolean } = {}
		for _, e in GardenConfig.EGGS do
			expect(`{e.id} {GardenConfig.isPrizeable(e)}`).toBe(`{e.id} {e.id ~= "starter"}`)
			if e.exclusive then
				expect(`{e.id} {e.exclusive} {e.price} {e.stock} {e.level} {e.top} {e.meter}`).toBe(
					`{e.id} {e.id} nil nil 1 {e.top} {e.meter}`
				)
				for _, o in e.odds do
					exclusiveSpecies[o.id] = true
				end
			else
				expect(`{e.id} {e.exclusive}`).toBe(`{e.id} nil`)
			end
		end
		expect((GardenConfig.egg("weekly") :: any).name).toBe("Weekly Egg")
		expect((GardenConfig.egg("monthly") :: any).name).toBe("Monthly Egg")
		local listed = {}
		for _, s in GardenConfig.SPECIES do
			if exclusiveSpecies[s.id] then
				table.insert(listed, s.id)
			end
		end
		expect(table.concat(listed, " ")).toBe("puffin otter capybara redpanda peacock snowleopard")
		-- Exclusive means only from its egg: no sold egg's odds name one of the six.
		for _, e in GardenConfig.EGGS do
			if e.price then
				for _, o in e.odds do
					expect(`{e.id} {o.id} {exclusiveSpecies[o.id]}`).toBe(`{e.id} {o.id} nil`)
				end
			end
		end
	end)

	it("gives every sold egg its rarest species as top (rarity index, then rate)", function()
		for _, e in GardenConfig.EGGS do
			if e.top then
				local best = e.odds[1].id
				for _, o in e.odds do
					local a, b =
						GardenConfig.species(o.id) :: GardenConfig.Species,
						GardenConfig.species(best) :: GardenConfig.Species
					local ra, rb = GardenConfig.rarityIndex(o.id), GardenConfig.rarityIndex(best)
					if ra > rb or (ra == rb and a.rate > b.rate) then
						best = o.id
					end
				end
				expect(`{e.id} {e.top}`).toBe(`{e.id} {best}`)
			end
		end
	end)

	it("keeps the stock of every existing egg for fixed windows, and seeds Celestial 6 and Aurora 7", function()
		-- Copied from WorldRules.stockFor before the Celestial Egg was added.
		local pinned = { "2 1 0 0", "4 2 0 0", "4 0 0 0", "4 0 0 1", "3 0 0 0", "3 2 1 0" }
		for i, row in pinned do
			local window = 6_000_000 + i - 1
			local s = WorldRules.stockFor(window)
			expect(`{s.forest} {s.sunset} {s.moon} {s.star}`).toBe(row)
			local r, state = Rng.int(Rng.seed(window, 9001, 6), 1, 10000)
			expect(s.celestial).toBe(if r <= 500 then (Rng.int(state, 1, 1)) else 0)
			r, state = Rng.int(Rng.seed(window, 9001, 7), 1, 10000)
			expect(s.aurora).toBe(if r <= 300 then (Rng.int(state, 1, 1)) else 0)
		end
	end)

	it("matches the U1 species table in rarity-then-rate order, and the mutation multipliers", function()
		local out = {}
		for i, s in GardenConfig.SPECIES do
			table.insert(out, `{s.id} {s.rarity} {s.rate}`)
			local prev = GardenConfig.SPECIES[i - 1]
			if prev then
				local ri, rp = GardenConfig.rarityIndex(s.id), GardenConfig.rarityIndex(prev.id)
				expect(`{s.id} {ri > rp or (ri == rp and s.rate > prev.rate)}`).toBe(`{s.id} true`)
			end
		end
		expect(table.concat(out, ", ")).toBe(
			"bunny common 1, frog common 2, duck common 3, pup uncommon 5, lamb uncommon 8, puffin uncommon 10, "
				.. "cat uncommon 12, owl rare 30, hedgehog rare 45, otter rare 50, moth rare 55, fox rare 70, "
				.. "turtle epic 180, capybara epic 220, deer epic 250, panda epic 350, "
				.. "lion legendary 500, redpanda legendary 650, unicorn legendary 800, "
				.. "dragon mythic 1500, peacock mythic 2000, phoenix mythic 2500, "
				.. "whale divine 5000, snowleopard divine 6000, kirin divine 7500, axolotl secret 25000"
		)
		local mult = {}
		for _, m in GardenConfig.MUTATIONS do
			table.insert(mult, `{m.id} {m.mult}`)
		end
		expect(table.concat(mult, ", ")).toBe("normal 1, golden 3, moonlit 5, rainbow 10, celestial 20")
		expect(#GardenConfig.SPECIES).toBe(26) -- X3.4: 20 + the six login exclusives
		expect((GardenConfig.species("moth") :: any).name).toBe("Lantern Moth")
		expect((GardenConfig.species("moth") :: any).cry).toBeNil() -- until a clip is registered
		local names = {}
		for _, id in { "puffin", "otter", "capybara", "redpanda", "peacock", "snowleopard" } do
			local s = GardenConfig.species(id) :: GardenConfig.Species
			table.insert(names, s.name)
			expect(`{id} {s.cry}`).toBe(`{id} nil`) -- until registered (X3.4)
		end
		expect(table.concat(names, ", ")).toBe(
			"Pebble Puffin, River Otter, Spa Capybara, Maple Red Panda, Jewel Peacock, Frost Leopard"
		)
	end)

	it("lists the 8 U1 rarities in order with their colours", function()
		local out = {}
		for _, r in GardenConfig.RARITIES do
			table.insert(out, `{r.id} {r.name} {table.concat(r.colour, ",")}`)
		end
		expect(table.concat(out, "; ")).toBe(
			"common Common 180,180,180; uncommon Uncommon 90,200,90; rare Rare 70,140,255; epic Epic 170,80,255; "
				.. "legendary Legendary 255,200,40; mythic Mythic 255,110,200; divine Divine 90,230,230; "
				.. "secret Secret 60,55,85"
		)
	end)

	it("gives every cry present a positive integer id and a pitch in 0.5 to 2", function()
		for _, s in GardenConfig.SPECIES do
			local cry = s.cry
			if cry then
				expect(`{s.id} {cry.id > 0 and cry.id == math.floor(cry.id)}`).toBe(`{s.id} true`)
				expect(`{s.id} {cry.pitch >= 0.5 and cry.pitch <= 2}`).toBe(`{s.id} true`)
			end
		end
	end)

	it("puts exactly the Legendary and Mythic species in the Celestial Egg, the login exclusives apart", function()
		local want = {}
		for _, s in GardenConfig.SPECIES do
			if (s.rarity == "legendary" or s.rarity == "mythic") and s.id ~= "redpanda" and s.id ~= "peacock" then
				table.insert(want, s.id)
			end
		end
		expect(ids((GardenConfig.egg("celestial") :: any).odds)).toBe(table.concat(want, " "))
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

	it("counts 108 indexable pairs, the celestial ones being lion, unicorn, dragon and phoenix", function()
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
		expect(count).toBe(108) -- 26 x 4 + 4 (X3.4); milestones stay at 20 / 40 / 60 / 80
		expect(GardenConfig.indexable("moth", "rainbow")).toBe(true)
		expect(GardenConfig.indexable("snowleopard", "rainbow")).toBe(true)
		expect(GardenConfig.indexable("redpanda", "celestial")).toBe(false)
		expect(GardenConfig.indexable("moth", "celestial")).toBe(false)
		expect(table.concat(special, " ")).toBe("lion:celestial unicorn:celestial dragon:celestial phoenix:celestial")
		expect(GardenConfig.indexable("whale", "celestial")).toBe(false) -- the Aurora fixes nothing
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
		expect(GardenConfig.rarityIndex("lion")).toBe(5)
		expect(GardenConfig.rarityIndex("dragon")).toBe(6)
		expect(GardenConfig.rarityIndex("whale")).toBe(7)
		expect(GardenConfig.rarityIndex("axolotl")).toBe(8)
		expect(GardenConfig.rarityIndex("nope")).toBe(0)
		expect(GardenConfig.RARITIES[GardenConfig.RARE].id).toBe("rare")
		expect(GardenConfig.RARE).toBe(3)
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
		expect(`{kinds.sweeper} {kinds.ball} {kinds.pendulum} {kinds.platform}`).toBe("3 4 3 5")
	end)
end)

describe("GardenConfig meta data", function()
	it("lists the H4 cosmetics with one level-1 default per slot", function()
		local out = {}
		for _, c in GardenConfig.COSMETICS do
			local unlock = if c.price
				then `${c.price}`
				elseif c.index then `i{c.index}`
				elseif c.grant then c.grant
				else `L{c.level}`
			table.insert(out, `{c.slot}:{c.id}:{unlock}`)
			expect(#c.colours > 0).toBe(true)
			expect(GardenConfig.cosmetic(c.id)).toBe(c)
			if c.grant then
				expect(`{c.id} {c.price} {c.level} {c.index}`).toBe(`{c.id} nil nil nil`)
			end
		end
		expect(table.concat(out, " ")).toBe(
			"fence:picket:L1 fence:bamboo:L3 fence:stone:L6 fence:hedge:L10 fence:crystal:L16 fence:golden:i20 "
				.. "fence:starlit:i60 fence:candy:$1000000 fence:rainbow:$1000000000 can:tin:L1 can:ducky:L4 can:flower:L8 "
				.. "can:moon:L14 can:star:$10000000 can:galaxy:$10000000000 pad:plain:L1 pad:clover:i40 "
				.. "can:blossom:login fence:lantern:login pad:lily:login fence:sakura:login can:peacock:login"
		)
		expect(GardenConfig.cosmetic("nope")).toBeNil()
	end)

	-- GDD X3.1 and X3.2, decision 0017.
	it("lists the two login tracks: 7 ascending slots each, the eggs at week 5 and month 4, cosmetics once", function()
		local function row(track: string): string
			local out = {}
			local last = 0
			for _, s in GardenConfig.LOGIN[track] do
				expect(s.count > last).toBe(true)
				last = s.count
				-- coins + minutes, or egg, or coins + minutes + cosmetic
				expect((s.coins ~= nil) == (s.minutes ~= nil) and (s.egg == nil) == (s.coins ~= nil)).toBe(true)
				if s.egg then
					expect((GardenConfig.egg(s.egg) :: GardenConfig.Egg).exclusive).toBe(
						track == "week" and "weekly" or "monthly"
					)
				end
				if s.cosmetic then
					expect((GardenConfig.cosmetic(s.cosmetic) :: MetaRules.Cosmetic).grant).toBe("login")
				end
				table.insert(
					out,
					`{s.count}:{s.egg or `{s.coins}/{s.minutes}`}{if s.cosmetic then "+" .. s.cosmetic else ""}`
				)
			end
			expect(#GardenConfig.LOGIN[track]).toBe(7)
			return table.concat(out, " ")
		end
		expect(row("week")).toBe("1:100/3 2:150/5 3:200/8 4:300/12 5:weekly 6:400/15+blossom 7:500/20+lantern")
		expect(row("month")).toBe(
			"3:200/10 7:300/20 12:500/30 18:monthly 22:600/40+lily 26:800/50+sakura 30:1000/60+peacock"
		)
		expect(GardenConfig.LOGIN.week[5].egg .. " " .. GardenConfig.LOGIN.month[4].egg).toBe("weekly monthly")
		expect(#GardenConfig.ICON_SET).toBe(16)
		expect(table.concat(GardenConfig.ICON_SET, " ")).toBe(
			"coin egg paw book hanger gift flag petal home chart cog heart swap calendar lock check"
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
		-- Deprecated by decision 0017 (nothing pays them); still in CONFIG so MetaRules ticks the fields.
		expect(table.concat(GardenConfig.DAILY, " ")).toBe("50 75 100 125 150 200 400")
		expect(table.concat(GardenConfig.DAILY_MINUTES, " ")).toBe("2 3 4 5 6 8 15")
		local W = GardenConfig.WEEKLY
		expect(`{W.days} {W.reward} {W.minutes}`).toBe("5 500 30")
	end)
end)
