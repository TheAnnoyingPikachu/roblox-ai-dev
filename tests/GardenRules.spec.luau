--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local MetaRules = require("../src/shared/MetaRules")
local WorldRules = require("../src/shared/WorldRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = GardenConfig.Profile

local NOW = 1_800_000_000

local function creature(id: number, s: string, m: string, z: string, placed: number): GardenConfig.Creature
	return { id = id, s = s, m = m, z = z, placed = placed, fav = false }
end

-- The C3 check garden: a Big Golden Berry Cat and a Normal Sprout Bunny with 5 Index entries.
local function checkGarden(): Profile
	local p = GardenProgress.defaults(NOW)
	p.creatures = { creature(1, "cat", "golden", "big", 1), creature(2, "bunny", "normal", "normal", 2) }
	p.index = { "bunny:normal", "cat:golden", "frog:normal", "pup:normal", "cat:normal" }
	p.nextId = 3
	return p
end

local function rich(level: number): Profile
	local p = GardenProgress.defaults(NOW)
	p.coins = 1e12
	p.xp = MetaRules.xpForLevel(level)
	p.beds[1] = { egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 }
	return p
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

describe("GardenRules income (C3)", function()
	it("matches the check values: 60.5 coins/s, 108,900 after 1 h, 871,200 after 10 h", function()
		local p = checkGarden()
		expect(GardenRules.rate(p.creatures[1])).toBe(54)
		expect(GardenRules.rate(p.creatures[2])).toBe(1)
		expect(near(GardenRules.indexMult(p), 1.1)).toBe(true)
		expect(near(GardenRules.income(p), 60.5)).toBe(true)
		p.lastSeen = NOW - 3600
		expect(GardenRules.offline(p, NOW)).toBe(108900)
		p.lastSeen = NOW - 36000
		expect(GardenRules.offline(p, NOW)).toBe(871200) -- capped at 8 h, half rate
	end)

	it("pays no offline coins when lastSeen is now or in the future, and stored creatures earn nothing", function()
		local p = checkGarden()
		p.lastSeen = NOW
		expect(GardenRules.offline(p, NOW)).toBe(0)
		p.lastSeen = NOW + 500
		expect(GardenRules.offline(p, NOW)).toBe(0)
		p.creatures[1].placed = 0
		expect(near(GardenRules.income(p), 1.1)).toBe(true)
		expect(GardenRules.income(GardenProgress.defaults(NOW))).toBe(0)
	end)

	it("applies mutation and size multipliers and the index bonus up to x2.6 (U4)", function()
		expect(GardenRules.rate(creature(1, "dragon", "rainbow", "huge", 1))).toBe(1500 * 10 * 2.5)
		expect(GardenRules.rate(creature(1, "owl", "moonlit", "normal", 1))).toBe(150)
		expect(GardenRules.rate(creature(1, "nope", "normal", "normal", 1))).toBe(0)
		local p = GardenProgress.defaults(NOW)
		for i = 1, GardenConfig.INDEX_SIZE do
			p.index[i] = `x{i}`
		end
		expect(near(GardenRules.indexMult(p), 2.6)).toBe(true)
	end)

	it("matches the S2 and U3 check values for Celestial and Aurora creatures", function()
		local lion = creature(1, "lion", "celestial", "normal", 1)
		local dragon = creature(2, "dragon", "celestial", "normal", 2)
		local huge = creature(3, "dragon", "celestial", "huge", 3)
		expect(GardenRules.rate(lion)).toBe(10000)
		expect(GardenRules.releaseValue(lion)).toBe(60000)
		expect(GardenRules.rate(dragon)).toBe(30000)
		expect(GardenRules.releaseValue(dragon)).toBe(180000)
		expect(GardenRules.rate(huge)).toBe(75000)
		expect(GardenRules.releaseValue(huge)).toBe(450000)
		local phoenix = creature(4, "phoenix", "celestial", "huge", 4)
		expect(GardenRules.rate(phoenix)).toBe(125000) -- the new top Celestial
		expect(GardenRules.releaseValue(phoenix)).toBe(750000)
		for id, want in { whale = 5000, kirin = 7500, axolotl = 25000 } do
			expect(GardenRules.rate(creature(5, id, "normal", "normal", 5))).toBe(want)
			expect(GardenRules.releaseValue(creature(5, id, "normal", "normal", 5))).toBe(want * 6)
		end
		local best = creature(6, "axolotl", "rainbow", "huge", 6)
		expect(GardenRules.rate(best)).toBe(625000) -- the new top single creature
		expect(GardenRules.releaseValue(best)).toBe(3_750_000)
		-- The exact long-run phoenix share with a meter of 10, size average 1.13.
		local share = 0.03 / (1 - 0.97 ^ 10)
		local rest = (500 * 6000 + 800 * 2500 + 1500 * 1200) / 9700
		local average = (rest * (1 - share) + 2500 * share) * 20 * 1.13
		expect(math.floor(average)).toBe(20488)
		expect(math.floor(average * 6 / 1000)).toBe(122) -- about 122,000 coins
		expect(string.format("%.2f", 100 * average * 6 / 1_000_000_000)).toBe("0.01")
	end)

	it("pays floor(rate x 6) on release (324 for a Big Golden Berry Cat) and refuses favourites", function()
		local p = checkGarden()
		expect(GardenRules.releaseValue(p.creatures[1])).toBe(324)
		local out, ok, coins = GardenRules.release(p, 1)
		expect(ok).toBe(true)
		expect(coins).toBe(324)
		expect(out.coins).toBe(100 + 324)
		expect(GardenRules.find(out, 1)).toBeNil()
		expect(#out.index).toBe(5) -- the Index entry stays
		expect(#p.creatures).toBe(2) -- input unchanged
		local fav = GardenRules.favourite(p, 1)
		expect((GardenRules.find(fav, 1) :: any).fav).toBe(true)
		local _, refused, none = GardenRules.release(fav, 1)
		expect(refused).toBe(false)
		expect(none).toBe(0)
		expect((GardenRules.find(GardenRules.favourite(fav, 1), 1) :: any).fav).toBe(false)
		expect(select(2, GardenRules.favourite(p, 99))).toBe(false)
		expect(select(2, GardenRules.release(p, 99))).toBe(false)
	end)

	-- Director ruling (0008 amendment 2026-10-26): the expected coins from buying, hatching and
	-- releasing an egg are at most 60% of its price, for every sold egg in every weather. The Lucky
	-- Meter is bounded from above by adding top rate / meter to the species average. An egg with a
	-- fixed mutation uses it, not the weather table: the table would understate it 20 times over.
	it("never returns more than 60% of an egg's price on buy, hatch and release, in any weather", function()
		local size = 0
		for _, z in GardenConfig.SIZES do
			size += z.mult * z.bp / 10000
		end
		local checked = 0
		for _, egg in GardenConfig.EGGS do
			local price = egg.price
			if price == nil then
				continue
			end
			local species = 0
			for _, o in egg.odds do
				species += (GardenConfig.species(o.id) :: GardenConfig.Species).rate * o.bp / 10000
			end
			if egg.top and egg.meter then
				species += (GardenConfig.species(egg.top) :: GardenConfig.Species).rate / egg.meter
			end
			for _, w in GardenConfig.WEATHERS do
				local mutation = 0
				for _, o in if egg.mutation then { { id = egg.mutation, bp = 10000 } } else w.mutation do
					mutation += (GardenConfig.mutation(o.id) :: GardenConfig.Mutation).mult * o.bp / 10000
				end
				expect(mutation >= 1).toBe(true)
				if egg.mutation then
					expect(mutation).toBe(20)
				end
				local expected = species * mutation * size * GardenConfig.RELEASE_SECONDS
				if expected > 0.6 * price then
					error(`{egg.id} in {w.id}: expected release {expected} > 60% of {price}`)
				end
				checked += 1
			end
		end
		expect(checked).toBe(28) -- 7 sold eggs x 4 weathers
	end)

	-- The exact long-run figures of decision 0014 (GDD U6) and docs/game-design/game4-v03-pacing-check.py.
	it("reproduces the decision's return, average income and payback for every egg", function()
		local PINNED = {
			meadow = "28.4 54.2 3 19",
			forest = "15.9 30.3 12 33",
			sunset = "13.1 24.9 75 40",
			moon = "6.3 12.0 299 84",
			star = "1.9 3.7 735 272",
			celestial = "0.01 0.01 20488 48808",
			aurora = "0.0 0.0 6362 785864",
		}
		local size = 0
		for _, z in GardenConfig.SIZES do
			size += z.mult * z.bp / 10000
		end
		local function mult(weather: string): number
			local out = 0
			for _, w in GardenConfig.WEATHERS do
				if w.id == weather then
					for _, o in w.mutation do
						out += (GardenConfig.mutation(o.id) :: GardenConfig.Mutation).mult * o.bp / 10000
					end
				end
			end
			return out
		end
		local event = mult("clear") / 2
		for _, o in GardenConfig.WEATHER_ODDS.weekday do
			event += mult(o.id) * o.bp / 20000
		end
		local worst, worstAt = 0, ""
		for _, egg in GardenConfig.EGGS do
			local price = egg.price
			if price == nil then
				continue
			end
			local q, rest = 0, 0
			for _, o in egg.odds do
				if o.id == egg.top then
					q = o.bp / 10000
				else
					rest += (GardenConfig.species(o.id) :: GardenConfig.Species).rate * o.bp / 10000
				end
			end
			local share = q / (1 - (1 - q) ^ (egg.meter :: number))
			local top = (GardenConfig.species(egg.top :: string) :: GardenConfig.Species).rate
			local base = (share * top + (1 - share) * rest / (1 - q)) * size
			local fixed = if egg.mutation
				then (GardenConfig.mutation(egg.mutation) :: GardenConfig.Mutation).mult
				else nil
			local function back(weather: string): number
				return 100 * base * (fixed or mult(weather)) * GardenConfig.RELEASE_SECONDS / price
			end
			for _, w in GardenConfig.WEATHERS do
				if back(w.id) > worst then
					worst, worstAt = back(w.id), `{egg.id} {w.id}`
				end
			end
			local rate = base * (fixed or event)
			local digits = if fixed then "%.2f" else "%.1f"
			local row = `{string.format(digits, back("clear"))} {string.format(digits, back("shower"))}`
			expect(`{egg.id} {row} {string.format("%.0f %.0f", rate, price / rate)}`).toBe(`{egg.id} {PINNED[egg.id]}`)
		end
		expect(`{worstAt} {string.format("%.1f", worst)}`).toBe("meadow shower 54.2")
	end)

	it("formats short numbers, truncating to one decimal", function()
		expect(GardenRules.short(999)).toBe("999")
		expect(GardenRules.short(0)).toBe("0")
		expect(GardenRules.short(60.5)).toBe("60")
		expect(GardenRules.short(1234)).toBe("1.2K")
		expect(GardenRules.short(1250)).toBe("1.2K")
		expect(GardenRules.short(2000)).toBe("2K")
		expect(GardenRules.short(999_999)).toBe("999.9K")
		expect(GardenRules.short(3.4e6)).toBe("3.4M")
		expect(GardenRules.short(5.6e9)).toBe("5.6B")
		expect(GardenRules.short(1.5e12)).toBe("1.5T")
		expect(GardenRules.short(1e15)).toBe("1000T")
	end)
end)

describe("GardenRules pads", function()
	it("accrues rate x indexMult x dt per placed creature's pad", function()
		local p = checkGarden()
		local pads = GardenRules.accrue(p, {}, 0.2)
		expect(near(pads[1], 54 * 1.1 * 0.2)).toBe(true)
		expect(near(pads[2], 1.1 * 0.2)).toBe(true)
		for _ = 1, 4 do
			pads = GardenRules.accrue(p, pads, 0.2)
		end
		expect(near(pads[2], 1.1)).toBe(true)
		expect(GardenRules.unbanked(pads)).toBe(60) -- floor(59.4 + 1.1)
	end)

	it("banks floor(pending) and keeps the fraction, without touching the input", function()
		local pads = { [1] = 3.75, [2] = 0.5 }
		local out, coins = GardenRules.bankPad(pads, 1)
		expect(coins).toBe(3)
		expect(near(out[1], 0.75)).toBe(true)
		expect(pads[1]).toBe(3.75)
		local _, zero = GardenRules.bankPad(pads, 2)
		expect(zero).toBe(0)
		local _, empty = GardenRules.bankPad(pads, 9)
		expect(empty).toBe(0)
		local _, exact = GardenRules.bankPad({ [1] = 0.1 + 0.2 + 0.7 }, 1)
		expect(exact).toBe(1)
	end)

	it("keeps a pad's coins when its creature is stored (pending belongs to the pad)", function()
		local p = checkGarden()
		local pads = GardenRules.accrue(p, {}, 1)
		local stored = GardenRules.store(p, 1)
		pads = GardenRules.accrue(stored, pads, 1)
		expect(near(pads[1], 59.4)).toBe(true)
	end)

	it("checks pad and range distances horizontally", function()
		local pad = { x = 10, y = 0, z = 10 }
		expect(GardenRules.onPad({ x = 14.5, y = 3, z = 10 }, pad)).toBe(true)
		expect(GardenRules.onPad({ x = 14.6, y = 3, z = 10 }, pad)).toBe(false)
		expect(GardenRules.onPad({ x = 10, y = 6, z = 10 }, pad)).toBe(true)
		expect(GardenRules.onPad({ x = 10, y = -6.1, z = 10 }, pad)).toBe(false)
		expect(GardenRules.within({ x = 0, y = 100, z = 0 }, { x = 15, y = 0, z = 20 }, 25)).toBe(true)
		expect(GardenRules.within({ x = 0, y = 0, z = 0 }, { x = 15, y = 0, z = 20.1 }, 25)).toBe(false)
	end)
end)

describe("GardenRules beds and eggs (D1)", function()
	it("reports bed states and growth, treating a clock before planted as just planted", function()
		local p = GardenProgress.defaults(NOW)
		expect(GardenRules.bedState(p, 1, NOW)).toBe("growing")
		expect(GardenRules.bedState(p, 1, NOW + 8)).toBe("ripe")
		expect(GardenRules.bedState(p, 1, NOW + 10 ^ 6)).toBe("ripe") -- ripe eggs never spoil
		expect(GardenRules.bedState(p, 2, NOW)).toBe("empty")
		expect(GardenRules.bedState(p, 4, NOW)).toBe("locked")
		expect(GardenRules.bedState(p, 0, NOW)).toBe("locked")
		expect(GardenRules.growFraction(p, 1, NOW + 4)).toBe(0.5)
		expect(GardenRules.growFraction(p, 1, NOW - 50)).toBe(0)
		expect(GardenRules.bedState(p, 1, NOW - 50)).toBe("growing")
		expect(GardenRules.growFraction(p, 1, NOW + 9)).toBe(1)
		expect(GardenRules.growFraction(p, 2, NOW)).toBe(0)
		expect(GardenRules.firstEmptyBed(p)).toBe(2)
	end)

	it("plants a bought egg in the lowest empty bed with ready = now + grow", function()
		local p = GardenProgress.defaults(NOW)
		local a, ok = GardenRules.buyEgg(p, "meadow", NOW)
		expect(ok).toBe(true)
		expect(a.coins).toBe(50)
		expect(a.beds[2].egg).toBe("meadow")
		expect(a.beds[2].planted).toBe(NOW)
		expect(a.beds[2].ready).toBe(NOW + 30)
		local b = GardenRules.buyEgg(a, "meadow", NOW)
		expect(b.beds[3].egg).toBe("meadow")
		expect(b.coins).toBe(0) -- starting coins buy two Meadow Eggs
		expect(p.beds[2].egg).toBe("") -- input unchanged
		expect(GardenRules.stockLeft(p, "meadow", NOW)).toBe(math.huge)
	end)

	it("refuses each D1 failure: level, stock, coins, no empty bed, unsold or unknown egg", function()
		local p = GardenProgress.defaults(NOW)
		p.coins = 1000
		expect(GardenRules.eggUnlocked(p, "forest")).toBe(false)
		expect(select(2, GardenRules.buyEgg(p, "forest", NOW))).toBe(false) -- level 1 < 2
		expect(select(2, GardenRules.buyEgg(p, "starter", NOW))).toBe(false)
		expect(select(2, GardenRules.buyEgg(p, "nope", NOW))).toBe(false)
		expect(GardenRules.stockLeft(p, "starter", NOW)).toBe(0)
		expect(GardenRules.stockLeft(p, "nope", NOW)).toBe(0)
		p.coins = 49
		expect(select(2, GardenRules.buyEgg(p, "meadow", NOW))).toBe(false)
		p.coins = 1000
		for i = 1, 3 do
			p.beds[i] = { egg = "meadow", planted = NOW, ready = NOW + 30, waters = 0, helps = 0, lastWater = 0 }
		end
		expect(select(2, GardenRules.buyEgg(p, "meadow", NOW))).toBe(false)
		-- Out of stock: find a window where the Star Egg is not stocked.
		local q = rich(18)
		local t = NOW
		while WorldRules.stockFor(WorldRules.stockWindow(t)).star > 0 do
			t += 300
		end
		expect(GardenRules.eggUnlocked(q, "star")).toBe(true)
		expect(GardenRules.stockLeft(q, "star", t)).toBe(0)
		expect(select(2, GardenRules.buyEgg(q, "star", t))).toBe(false)
	end)

	it("counts buys per player per window and resets on the next window", function()
		local p = rich(2)
		p.bedCount = 12
		for i = 1, 12 do
			p.beds[i] = { egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 }
		end
		local window = WorldRules.stockWindow(NOW)
		local qty = WorldRules.stockFor(window).forest
		expect(qty >= 2 and qty <= 4).toBe(true)
		for i = 1, qty do
			expect(GardenRules.stockLeft(p, "forest", NOW)).toBe(qty - i + 1)
			local ok
			p, ok = GardenRules.buyEgg(p, "forest", NOW)
			expect(ok).toBe(true)
		end
		expect(p.stock.w).toBe(window)
		expect(p.stock.bought.forest).toBe(qty)
		expect(select(2, GardenRules.buyEgg(p, "forest", NOW))).toBe(false)
		local nextStart = (window + 1) * 300
		expect(GardenRules.stockLeft(p, "forest", nextStart)).toBe(WorldRules.stockFor(window + 1).forest)
		local after, ok = GardenRules.buyEgg(p, "forest", nextStart)
		expect(ok).toBe(true)
		expect(after.stock.w).toBe(window + 1)
		expect(after.stock.bought.forest).toBe(1)
	end)
end)

describe("GardenRules Celestial Egg (S1)", function()
	local function stockedAt(egg: string, stocked: boolean): number
		local t = NOW
		while (WorldRules.stockFor(WorldRules.stockWindow(t))[egg] > 0) ~= stocked do
			t += 300
		end
		return t
	end

	it("sells it at the cart like any egg: level 25, 1,000,000,000 coins, one per stocked window", function()
		local t = stockedAt("celestial", true)
		local p = rich(25)
		expect(GardenRules.stockLeft(p, "celestial", t)).toBe(1)
		local out, ok = GardenRules.buyEgg(p, "celestial", t)
		expect(ok).toBe(true)
		expect(out.coins).toBe(1e12 - 1e9)
		expect(out.beds[1].egg).toBe("celestial")
		expect(out.beds[1].ready).toBe(t + 28800)
		expect(GardenRules.stockLeft(out, "celestial", t)).toBe(0)
		expect(select(2, GardenRules.buyEgg(out, "celestial", t))).toBe(false)
		expect(select(2, GardenRules.buyEgg(rich(24), "celestial", t))).toBe(false)
		local poor = rich(25)
		poor.coins = 999_999_999
		expect(select(2, GardenRules.buyEgg(poor, "celestial", t))).toBe(false)
		expect(select(2, GardenRules.buyEgg(p, "celestial", stockedAt("celestial", false)))).toBe(false)
	end)

	it("sells the Aurora Egg at level 32 for 5,000,000,000 coins, one per stocked window (U3)", function()
		local t = stockedAt("aurora", true)
		local p = rich(32)
		expect(GardenRules.stockLeft(p, "aurora", t)).toBe(1)
		local out, ok = GardenRules.buyEgg(p, "aurora", t)
		expect(ok).toBe(true)
		expect(out.coins).toBe(1e12 - 5e9)
		expect(out.beds[1].egg).toBe("aurora")
		expect(out.beds[1].ready).toBe(t + 43200)
		expect(GardenRules.stockLeft(out, "aurora", t)).toBe(0)
		expect(select(2, GardenRules.buyEgg(rich(31), "aurora", t))).toBe(false)
		expect(select(2, GardenRules.buyEgg(p, "aurora", stockedAt("aurora", false)))).toBe(false)
		expect(GardenRules.waterCut("aurora")).toBe(2160)
	end)

	it("cuts 1,440 s per water and ripens in 17,280 s with 8 waters", function()
		expect(GardenRules.waterCut("celestial")).toBe(1440)
		local p = GardenProgress.defaults(NOW)
		p.beds[1] = { egg = "celestial", planted = NOW, ready = NOW + 28800, waters = 0, helps = 0, lastWater = 0 }
		for i = 0, 7 do
			p = GardenRules.water(p, 1, NOW + 60 * i, i >= 5)
		end
		expect(p.beds[1].ready - p.beds[1].planted).toBe(17280)
	end)
end)

describe("GardenRules prize eggs (decision 0012)", function()
	local function winner(level: number, count: number): Profile
		local p = rich(level)
		p.prizeEggs = { moon = count }
		return p
	end

	it("plants at Level 10, not 9, at ready = now + 3,600 with coins and stock unchanged", function()
		local poor = winner(10, 1)
		poor.coins = 0
		poor.stock = { w = 12, bought = { moon = 1 } }
		expect(GardenRules.canPlantPrize(winner(9, 1), "moon")).toBe(false)
		expect(select(2, GardenRules.plantPrize(winner(9, 1), "moon", NOW))).toBe(false)
		expect(GardenRules.canPlantPrize(poor, "moon")).toBe(true)
		local out, ok = GardenRules.plantPrize(poor, "moon", NOW)
		expect(ok).toBe(true)
		expect(out.beds[1].egg).toBe("moon")
		expect(out.beds[1].planted).toBe(NOW)
		expect(out.beds[1].ready).toBe(NOW + 3600)
		expect(out.coins).toBe(0)
		expect(out.stock.w).toBe(12)
		expect(out.stock.bought.moon).toBe(1)
		expect(out.prizeEggs.moon).toBeNil() -- no zero counts
		expect(poor.prizeEggs.moon).toBe(1) -- input unchanged
		expect(poor.beds[1].egg).toBe("")
	end)

	it("ignores stock: plants in a window with no Moon Eggs", function()
		local t = NOW
		while WorldRules.stockFor(WorldRules.stockWindow(t)).moon > 0 do
			t += 300
		end
		expect(select(2, GardenRules.plantPrize(winner(10, 1), "moon", t))).toBe(true)
	end)

	it("uses the lowest empty bed and counts down", function()
		local p = winner(10, 2)
		p.beds[1] = { egg = "meadow", planted = NOW, ready = NOW + 30, waters = 0, helps = 0, lastWater = 0 }
		local out = GardenRules.plantPrize(p, "moon", NOW)
		expect(out.beds[2].egg).toBe("moon")
		expect(out.prizeEggs.moon).toBe(1)
		local last = GardenRules.plantPrize(out, "moon", NOW)
		expect(last.beds[3].egg).toBe("moon")
		expect(last.prizeEggs.moon).toBeNil()
		expect(select(2, GardenRules.plantPrize(last, "moon", NOW))).toBe(false) -- spent once only
	end)

	it("refuses with no egg, with full beds keeps the egg, and refuses unsold or unknown eggs", function()
		expect(select(2, GardenRules.plantPrize(rich(25), "moon", NOW))).toBe(false)
		local full = winner(10, 1)
		for i = 1, full.bedCount do
			full.beds[i] = { egg = "meadow", planted = NOW, ready = NOW + 30, waters = 0, helps = 0, lastWater = 0 }
		end
		local same, ok = GardenRules.plantPrize(full, "moon", NOW)
		expect(ok).toBe(false)
		expect(same.prizeEggs.moon).toBe(1)
		local odd = rich(25)
		odd.prizeEggs = { starter = 1, nope = 1 }
		expect(GardenRules.canPlantPrize(odd, "starter")).toBe(false)
		expect(GardenRules.canPlantPrize(odd, "nope")).toBe(false)
		expect(GardenRules.canPlantPrize(odd, nil :: any)).toBe(false)
	end)
end)

describe("GardenRules watering (D2)", function()
	local function planted(egg: string): Profile
		local p = GardenProgress.defaults(0)
		local e = GardenConfig.egg(egg) :: GardenConfig.Egg
		p.beds[1] = { egg = egg, planted = NOW, ready = NOW + e.grow, waters = 0, helps = 0, lastWater = 0 }
		return p
	end

	it("cuts floor(5% of grow time) per water", function()
		local cuts = {}
		for _, id in { "meadow", "forest", "sunset", "moon", "star", "celestial", "aurora" } do
			table.insert(cuts, tostring(GardenRules.waterCut(id)))
			local out = GardenRules.water(planted(id), 1, NOW, false)
			expect(out.beds[1].ready).toBe(NOW + (GardenConfig.egg(id) :: any).grow - GardenRules.waterCut(id))
		end
		expect(table.concat(cuts, " ")).toBe("1 9 45 180 720 1440 2160")
		expect(GardenRules.waterCut("nope")).toBe(0)
	end)

	it("ripens a Moon Egg watered 8 times in 2,160 s", function()
		local p = planted("moon")
		for i = 0, 7 do
			local ok
			p, ok = GardenRules.water(p, 1, NOW + 60 * i, i >= 5)
			expect(ok).toBe(true)
		end
		expect(p.beds[1].ready - p.beds[1].planted).toBe(2160)
		expect(p.beds[1].waters).toBe(5)
		expect(p.beds[1].helps).toBe(3)
		expect(GardenRules.canWater(p, 1, NOW + 600, false)).toBe(false)
		expect(GardenRules.canWater(p, 1, NOW + 600, true)).toBe(false)
	end)

	it("enforces the 60 s cooldown by anyone and the 5 + 3 caps", function()
		local p = GardenRules.water(planted("star"), 1, NOW, false)
		expect(GardenRules.canWater(p, 1, NOW + 59, false)).toBe(false)
		expect(GardenRules.canWater(p, 1, NOW + 59, true)).toBe(false) -- the cooldown is shared
		expect(GardenRules.canWater(p, 1, NOW + 60, true)).toBe(true)
		local t = NOW
		for _ = 2, 5 do
			t += 60
			p = GardenRules.water(p, 1, t, false)
		end
		expect(p.beds[1].waters).toBe(5)
		expect(GardenRules.canWater(p, 1, t + 60, false)).toBe(false)
		expect(GardenRules.canWater(p, 1, t + 60, true)).toBe(true)
		for _ = 1, 3 do
			t += 60
			p = GardenRules.water(p, 1, t, true)
		end
		expect(select(2, GardenRules.water(p, 1, t + 60, true))).toBe(false)
	end)

	it("never sets ready before now and refuses empty, ripe or locked beds", function()
		local p = GardenRules.water(planted("meadow"), 1, NOW + 29, false)
		expect(p.beds[1].ready).toBe(NOW + 29)
		expect(GardenRules.bedState(p, 1, NOW + 29)).toBe("ripe")
		expect(select(2, GardenRules.water(planted("meadow"), 1, NOW + 30, false))).toBe(false) -- ripe
		expect(select(2, GardenRules.water(planted("meadow"), 2, NOW, false))).toBe(false) -- empty
		expect(select(2, GardenRules.water(planted("meadow"), 5, NOW, false))).toBe(false) -- locked
		local late = planted("moon")
		local out = GardenRules.water(late, 1, NOW + 3500, false)
		expect(out.beds[1].ready).toBe(NOW + 3500) -- max(now, ready - cut)
	end)
end)

describe("GardenRules admin catalogue (decision 0013)", function()
	it("gives every species, mutation and size a save can hold, and nothing else", function()
		local given = 0
		for _, s in GardenConfig.SPECIES do
			for _, m in GardenConfig.MUTATIONS do
				for _, z in GardenConfig.SIZES do
					local p, ok = GardenRules.grant(GardenProgress.defaults(NOW), s.id, m.id, z.id)
					expect(ok).toBe(GardenConfig.indexable(s.id, m.id))
					if ok then
						given += 1
						local kept = GardenProgress.sanitize(p, NOW).creatures[1]
						expect(kept.s == s.id and kept.m == m.id and kept.z == z.id).toBe(true)
					end
				end
			end
		end
		expect(given).toBe(GardenConfig.INDEX_SIZE * #GardenConfig.SIZES)
		local base = GardenProgress.defaults(NOW)
		expect(select(2, GardenRules.grant(base, "bunny", "celestial", "normal"))).toBe(false)
		expect(select(2, GardenRules.grant(base, "nope", "normal", "normal"))).toBe(false)
		expect(select(2, GardenRules.grant(base, "bunny", "nope", "normal"))).toBe(false)
		expect(select(2, GardenRules.grant(base, "bunny", "normal", "nope"))).toBe(false)
	end)

	it("adds the Index entry once and pays no XP, hatch or coins", function()
		local base = GardenProgress.defaults(NOW)
		local p = GardenRules.grant(base, "dragon", "celestial", "huge")
		p = GardenRules.grant(p, "dragon", "celestial", "big")
		expect(#p.creatures).toBe(2)
		expect(p.creatures[1].id ~= p.creatures[2].id).toBe(true)
		expect(p.nextId).toBe(base.nextId + 2)
		expect(#p.index).toBe(1)
		expect(p.xp).toBe(base.xp)
		expect(p.hatches).toBe(base.hatches)
		expect(p.coins).toBe(base.coins)
		expect(#base.creatures).toBe(0)
	end)

	it("fills the pen, then storage, then refuses", function()
		local p = GardenProgress.defaults(NOW)
		for i = 1, p.penSlots + GardenConfig.STORAGE do
			p = GardenRules.grant(p, "bunny", "normal", "normal")
			expect(p.creatures[i].placed).toBe(if i <= p.penSlots then i else 0)
		end
		expect(select(2, GardenRules.grant(p, "bunny", "normal", "normal"))).toBe(false)
	end)

	it("lets only the owner in", function()
		local count = 0
		for _ in GardenConfig.ADMINS do
			count += 1
		end
		expect(count).toBe(1)
		expect(GardenConfig.ADMINS[96807256]).toBe(true)
	end)
end)

describe("GardenRules beds, pen and storage (C1, C2)", function()
	it("sells beds 4 to 12 at the C1 costs, then stops", function()
		local p = rich(1)
		local costs = {}
		while GardenRules.nextBedCost(p) do
			local cost = GardenRules.nextBedCost(p) :: number
			table.insert(costs, tostring(cost))
			local before = p.coins
			local ok
			p, ok = GardenRules.buyBed(p)
			expect(ok).toBe(true)
			expect(before - p.coins).toBe(cost)
			expect(#p.beds).toBe(p.bedCount)
			expect(p.beds[p.bedCount].egg).toBe("")
		end
		expect(table.concat(costs, " ")).toBe("500 2000 8000 25000 75000 200000 500000 1200000 3000000")
		expect(p.bedCount).toBe(12)
		expect(select(2, GardenRules.buyBed(p))).toBe(false)
		local poor = GardenProgress.defaults(NOW)
		expect(select(2, GardenRules.buyBed(poor))).toBe(false) -- 100 < 500
	end)

	it("sells pen slots 7 to 20 at 300 x 2^k, then stops", function()
		local p = rich(1)
		local costs = {}
		while GardenRules.nextPenCost(p) do
			table.insert(costs, tostring(GardenRules.nextPenCost(p)))
			p = GardenRules.buyPenSlot(p)
		end
		expect(table.concat(costs, " ")).toBe(
			"300 600 1200 2400 4800 9600 19200 38400 76800 153600 307200 614400 1228800 2457600"
		)
		expect(p.penSlots).toBe(20)
		expect(select(2, GardenRules.buyPenSlot(p))).toBe(false)
		local poor = GardenProgress.defaults(NOW)
		poor.coins = 299
		expect(select(2, GardenRules.buyPenSlot(poor))).toBe(false)
	end)

	it("places on the lowest free pad, stores while storage has room, and reports a full garden", function()
		local p = GardenProgress.defaults(NOW)
		for i = 1, 5 do
			table.insert(p.creatures, creature(i, "bunny", "normal", "normal", if i == 2 then 0 else i))
		end
		expect(GardenRules.freePad(p)).toBe(2)
		local placed, ok = GardenRules.place(p, 2)
		expect(ok).toBe(true)
		expect((GardenRules.find(placed, 2) :: any).placed).toBe(2)
		expect(GardenRules.freePad(placed)).toBe(6)
		expect(select(2, GardenRules.place(placed, 2))).toBe(false) -- already placed
		local stored = GardenRules.store(placed, 3)
		expect((GardenRules.find(stored, 3) :: any).placed).toBe(0)
		expect(GardenRules.storageCount(stored)).toBe(1)
		expect(select(2, GardenRules.store(stored, 3))).toBe(false) -- already stored
		expect(select(2, GardenRules.place(p, 99))).toBe(false)
		local full = GardenRules.copy(placed)
		table.insert(full.creatures, creature(7, "frog", "normal", "normal", 6))
		expect(GardenRules.freePad(full)).toBeNil()
		expect(GardenRules.isFull(full)).toBe(false)
		for i = 8, 67 do
			table.insert(full.creatures, creature(i, "frog", "normal", "normal", 0))
		end
		expect(GardenRules.storageCount(full)).toBe(60)
		expect(GardenRules.isFull(full)).toBe(true)
		expect(select(2, GardenRules.store(full, 1))).toBe(false) -- storage full
		expect(select(2, GardenRules.place(full, 8))).toBe(false) -- no free pad
	end)

	it("copies deeply", function()
		local p = checkGarden()
		local c = GardenRules.copy(p)
		c.creatures[1].placed = 9
		c.beds[1].egg = "moon"
		expect(p.creatures[1].placed).toBe(1)
		expect(p.beds[1].egg).toBe("starter")
		expect(GardenRules.level(rich(7))).toBe(7)
	end)
end)
