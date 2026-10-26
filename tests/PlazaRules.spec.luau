--!strict
local T = require("./framework")
local MetaRules = require("../src/shared/MetaRules")
local PlazaRules = require("../src/shared/PlazaRules")
local SpireConfig = require("../src/shared/SpireConfig")
local SpireProgress = require("../src/shared/SpireProgress")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = SpireConfig.Profile

local NOW = 1_800_000_000

local function plaza(floors: number, coins: number): Profile
	local p = SpireProgress.defaults(NOW, 1)
	p.coins = coins
	for n = 3, floors do
		p.floors[n] = { d = "data", m = { 0, 0, 0, 0 }, s = { 0, 0, 0, 0 } }
	end
	return p
end

-- Items for Hype sums only (positions do not matter to rawHype).
local function withItems(p: Profile, ids: { [string]: number }): Profile
	for id, n in ids do
		for _ = 1, n do
			table.insert(p.plaza.items, { u = p.plaza.nextUid, id = id, x = 0, y = 0, r = 0, paid = 0 })
			p.plaza.nextUid += 1
		end
	end
	return p
end

describe("PlazaRules", function()
	it("footprint swaps on odd rotations", function()
		local w, d = PlazaRules.footprint("maglev", 0)
		expect(w).toBe(3)
		expect(d).toBe(2)
		w, d = PlazaRules.footprint("maglev", 3)
		expect(w).toBe(2)
		expect(d).toBe(3)
		w, d = PlazaRules.footprint("nope", 0)
		expect(w).toBe(0)
		expect(d).toBe(0)
	end)

	it("cells are keys x + 12y from the min corner", function()
		local cells = PlazaRules.cells("noodle", 2, 3, 1) -- 1 x 2 at r = 1
		expect(#cells).toBe(2)
		expect(cells[1]).toBe(2 + 36)
		expect(cells[2]).toBe(2 + 48)
	end)

	it("walkway, bounds and overlap at each edge for every rotation and size", function()
		local p = plaza(2, 0)
		for _, item in SpireConfig.ITEMS do
			for r = 0, 3 do
				local w, d = PlazaRules.footprint(item.id, r)
				-- left block x 0..4, right block x 7..11
				expect(PlazaRules.check(p, item.id, 0, 0, r)).toBeNil()
				expect(PlazaRules.check(p, item.id, 12 - w, 8 - d, r)).toBeNil()
				expect(PlazaRules.check(p, item.id, 5 - w, 0, r)).toBeNil() -- right edge touches the walkway
				expect(PlazaRules.check(p, item.id, 6 - w, 0, r)).toBe("walkway")
				expect(PlazaRules.check(p, item.id, 7, 0, r)).toBeNil()
				expect(PlazaRules.check(p, item.id, 6, 0, r)).toBe("walkway")
				expect(PlazaRules.check(p, item.id, -1, 0, r)).toBe("bounds")
				expect(PlazaRules.check(p, item.id, 0, -1, r)).toBe("bounds")
				expect(PlazaRules.check(p, item.id, 13 - w, 0, r)).toBe("bounds")
				expect(PlazaRules.check(p, item.id, 7, 9 - d, r)).toBe("bounds")
			end
		end
		expect(PlazaRules.check(p, "bench", 0, 0, 4)).toBe("bounds")
		expect(PlazaRules.check(p, "bench", 0.5, 0, 0)).toBe("bounds")
		expect(PlazaRules.check(p, "bench", 0, 0, -1)).toBe("bounds")
		expect(PlazaRules.check(p, "nope", 0, 0, 0)).toBe("unknown")
	end)

	it("a 3 x 3 Idol along each edge at every rotation", function()
		local p = plaza(25, 0)
		for r = 0, 3 do
			expect(PlazaRules.check(p, "idol", 0, 0, r)).toBeNil()
			expect(PlazaRules.check(p, "idol", 2, 5, r)).toBeNil()
			expect(PlazaRules.check(p, "idol", 9, 5, r)).toBeNil()
			expect(PlazaRules.check(p, "idol", 7, 0, r)).toBeNil()
			expect(PlazaRules.check(p, "idol", 3, 0, r)).toBe("walkway")
			expect(PlazaRules.check(p, "idol", 4, 0, r)).toBe("walkway")
			expect(PlazaRules.check(p, "idol", 10, 0, r)).toBe("bounds")
			expect(PlazaRules.check(p, "idol", 0, 6, r)).toBe("bounds")
		end
	end)

	it("overlap on each side of a placed item; moveItem ignores its own cells", function()
		local p = plaza(10, 1e6)
		local out, ok = PlazaRules.placeItem(p, "arcade", 1, 2, 0) -- cells x 1..2, y 2..3
		expect(ok).toBe(true)
		for _, cell in { { 0, 2 }, { 3, 2 }, { 1, 1 }, { 1, 4 } } do
			expect(PlazaRules.check(out, "bench", cell[1], cell[2], 0)).toBeNil()
		end
		for _, cell in { { 1, 2 }, { 2, 2 }, { 1, 3 }, { 2, 3 } } do
			expect(PlazaRules.check(out, "bench", cell[1], cell[2], 0)).toBe("occupied")
		end
		expect(PlazaRules.check(out, "arcade", 0, 1, 0)).toBe("occupied")
		local uid = out.plaza.items[1].u
		local moved, ok2 = PlazaRules.moveItem(out, uid, 2, 3, 0)
		expect(ok2).toBe(true)
		expect(moved.plaza.items[1].x).toBe(2)
		expect(out.plaza.items[1].x).toBe(1) -- input untouched
		expect(select(3, PlazaRules.moveItem(out, uid, 1, 2, 0))).toBe("same")
		expect(select(3, PlazaRules.moveItem(out, 99, 0, 0, 0))).toBe("unknown")
		expect(select(3, PlazaRules.moveItem(out, uid, 4, 0, 0))).toBe("walkway")
		local two = PlazaRules.placeItem(out, "bench", 0, 0, 0)
		expect(select(3, PlazaRules.moveItem(two, uid, 0, 0, 0))).toBe("occupied")
	end)

	it("placeItem: uid, paid, credits and refusals in order", function()
		local p = plaza(3, 900)
		local a, ok = PlazaRules.placeItem(p, "palm", 0, 0, 0)
		expect(ok).toBe(true)
		expect(a.coins).toBe(100)
		expect(a.plaza.items[1].u).toBe(1)
		expect(a.plaza.items[1].paid).toBe(800)
		expect(a.plaza.nextUid).toBe(2)
		expect(select(3, PlazaRules.placeItem(a, "palm", 1, 0, 0))).toBe("credits")
		expect(select(3, PlazaRules.placeItem(a, "nope", 1, 0, 0))).toBe("unknown")
		expect(select(3, PlazaRules.placeItem(a, "vending", 1, 0, 0))).toBe("locked") -- floors 3 < 5
		expect(select(3, PlazaRules.placeItem(a, "planter", 1, 0, 0))).toBe("locked") -- level 1 < 2
		expect(select(3, PlazaRules.placeItem(a, "bench", 0, 0, 0))).toBe("occupied")
		expect(select(3, PlazaRules.placeItem(a, "bench", 5, 0, 0))).toBe("walkway")
		local _, okLamp = PlazaRules.placeItem(a, "bollard", 1, 0, 0)
		expect(okLamp).toBe(true)
	end)

	it("unlocks: hype items by floors, decor by level", function()
		local p = plaza(5, 0)
		expect(PlazaRules.unlocked(p, "vending")).toBe(true)
		expect(PlazaRules.unlocked(p, "noodle")).toBe(false)
		expect(PlazaRules.unlocked(p, "koi")).toBe(false)
		p.xp = MetaRules.xpForLevel(10)
		expect(PlazaRules.unlocked(p, "koi")).toBe(true)
		expect(PlazaRules.unlocked(p, "nope")).toBe(false)
	end)

	it("per-item max, 20 decor and the 60-item cap", function()
		local p = plaza(30, 1e12)
		p.xp = MetaRules.xpForLevel(10)
		for i = 0, 11 do
			p = (PlazaRules.placeItem(p, "bench", i % 5, i // 5, 0))
		end
		expect(#p.plaza.items).toBe(12)
		expect(select(3, PlazaRules.placeItem(p, "bench", 4, 3, 0))).toBe("max")
		-- 20 decor
		local q = plaza(30, 1e12)
		q.xp = MetaRules.xpForLevel(10)
		for i = 0, 19 do
			q = (PlazaRules.placeItem(q, "lamp", i % 5, i // 5, 0))
		end
		local _, total, nDecor = PlazaRules.counts(q)
		expect(total).toBe(20)
		expect(nDecor).toBe(20)
		expect(select(3, PlazaRules.placeItem(q, "lamp", 7, 0, 0))).toBe("full")
		-- 60 items (raw inserts; only the count matters here)
		local full = plaza(30, 1e12)
		full.xp = MetaRules.xpForLevel(10)
		local spots = {}
		for y = 0, 7 do
			for _, x in { 0, 1, 2, 3, 4, 7, 8, 9, 10, 11 } do
				table.insert(spots, { x, y })
			end
		end
		for i = 1, 60 do
			table.insert(full.plaza.items, { u = i, id = "lamp", x = spots[i][1], y = spots[i][2], r = 0, paid = 150 })
		end
		full.plaza.nextUid = 61
		expect(select(3, PlazaRules.placeItem(full, "bench", spots[61][1], spots[61][2], 0))).toBe("full")
	end)

	it("sellItem refunds floor(0.5 x paid)", function()
		local p = plaza(3, 1000)
		p = (PlazaRules.placeItem(p, "bollard", 0, 0, 0))
		p = (PlazaRules.placeItem(p, "palm", 1, 0, 0))
		expect(p.coins).toBe(150)
		local out, ok = PlazaRules.sellItem(p, 1)
		expect(ok).toBe(true)
		expect(out.coins).toBe(175)
		expect(#out.plaza.items).toBe(1)
		expect(out.plaza.items[1].id).toBe("palm")
		expect(select(3, PlazaRules.sellItem(out, 1))).toBe("unknown")
		local odd = plaza(3, 0)
		table.insert(odd.plaza.items, { u = 1, id = "bench", x = 0, y = 0, r = 0, paid = 75 })
		expect((PlazaRules.sellItem(odd, 1)).coins).toBe(37)
	end)

	it("D3 check: 12 benches and 10 palms at floor 3 give raw 32, cap 30, x1.30", function()
		local p = withItems(plaza(3, 0), { bench = 12, palm = 10 })
		expect(PlazaRules.rawHype(p)).toBe(32)
		expect(PlazaRules.hypeCap(p)).toBe(30)
		expect(PlazaRules.hype(p)).toBe(30)
		expect(PlazaRules.hypeMult(p)).toBe(1.3)
	end)

	it("D3 check: every item but the Idol at floor 20 gives 212 raw, cap 200, x3", function()
		local p = withItems(
			plaza(20, 0),
			{ bench = 12, palm = 10, vending = 8, noodle = 6, arcade = 4, fountain = 2, maglev = 1, billboard = 2 }
		)
		expect(PlazaRules.rawHype(p)).toBe(212)
		expect(PlazaRules.hypeCap(p)).toBe(200)
		expect(PlazaRules.hype(p)).toBe(200)
		expect(PlazaRules.hypeMult(p)).toBe(3)
		local tall = withItems(plaza(30, 0), { idol = 1 })
		expect(PlazaRules.hypeCap(tall)).toBe(200)
	end)

	it("crowd = min(40, 2 + floor(hype / 5))", function()
		expect(PlazaRules.crowd(0)).toBe(2)
		expect(PlazaRules.crowd(9)).toBe(3)
		expect(PlazaRules.crowd(30)).toBe(8)
		expect(PlazaRules.crowd(190)).toBe(40)
		expect(PlazaRules.crowd(200)).toBe(40)
	end)

	it("cellAt(cellCentre(x, y)) returns (x, y) for all 96 cells", function()
		for x = 0, 11 do
			for y = 0, 7 do
				local cx, cy = PlazaRules.cellAt(PlazaRules.cellCentre(x, y))
				expect(cx).toBe(x)
				expect(cy).toBe(y)
			end
		end
		local c = PlazaRules.cellCentre(0, 0)
		expect(c.x).toBe(-22)
		expect(c.z).toBe(-16)
		expect((PlazaRules.cellAt({ x = 24, y = 0, z = -20 }))).toBeNil()
		expect((PlazaRules.cellAt({ x = 0, y = 0, z = -13 }))).toBeNil()
		expect((PlazaRules.cellAt({ x = 0, y = 0, z = -46.5 }))).toBeNil()
	end)

	it("itemCentre is the footprint centre", function()
		local c = PlazaRules.itemCentre("idol", 0, 0, 0)
		expect(c.x).toBe(-18)
		expect(c.z).toBe(-20)
		local m = PlazaRules.itemCentre("maglev", 7, 0, 1) -- 2 wide, 3 deep
		expect(m.x).toBe(-22 + 4 * 7.5)
		expect(m.z).toBe(-16 - 4 * 1)
	end)
end)
