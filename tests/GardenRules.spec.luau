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

	it("applies mutation and size multipliers and the index bonus up to x1.72", function()
		expect(GardenRules.rate(creature(1, "dragon", "rainbow", "huge", 1))).toBe(1500 * 10 * 2.5)
		expect(GardenRules.rate(creature(1, "owl", "moonlit", "normal", 1))).toBe(150)
		expect(GardenRules.rate(creature(1, "nope", "normal", "normal", 1))).toBe(0)
		local p = GardenProgress.defaults(NOW)
		for i = 1, 36 do
			p.index[i] = `x{i}`
		end
		expect(near(GardenRules.indexMult(p), 1.72)).toBe(true)
	end)

	it("pays floor(rate x 30) on release (1,620 for a Big Golden Berry Cat) and refuses favourites", function()
		local p = checkGarden()
		expect(GardenRules.releaseValue(p.creatures[1])).toBe(1620)
		local out, ok, coins = GardenRules.release(p, 1)
		expect(ok).toBe(true)
		expect(coins).toBe(1620)
		expect(out.coins).toBe(100 + 1620)
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

describe("GardenRules watering (D2)", function()
	local function planted(egg: string): Profile
		local p = GardenProgress.defaults(0)
		local e = GardenConfig.egg(egg) :: GardenConfig.Egg
		p.beds[1] = { egg = egg, planted = NOW, ready = NOW + e.grow, waters = 0, helps = 0, lastWater = 0 }
		return p
	end

	it("cuts floor(5% of grow time) per water", function()
		local cuts = {}
		for _, id in { "meadow", "forest", "sunset", "moon", "star" } do
			table.insert(cuts, tostring(GardenRules.waterCut(id)))
			local out = GardenRules.water(planted(id), 1, NOW, false)
			expect(out.beds[1].ready).toBe(NOW + (GardenConfig.egg(id) :: any).grow - GardenRules.waterCut(id))
		end
		expect(table.concat(cuts, " ")).toBe("1 9 45 180 720")
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
