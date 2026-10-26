--!strict
local T = require("./framework")
local SpireConfig = require("../src/shared/SpireConfig")
local SpireProgress = require("../src/shared/SpireProgress")
local TowerRules = require("../src/shared/TowerRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = SpireConfig.Profile

local NOW = 1_800_000_000

local function fl(d: string, m: { number }): SpireConfig.Floor
	local s = {}
	for i = 1, 4 do
		s[i] = TowerRules.spentMax(d, m[i])
	end
	return { d = d, m = table.clone(m), s = s }
end

local function tower(coins: number, floors: { SpireConfig.Floor }): Profile
	local p = SpireProgress.defaults(NOW, 1)
	p.coins = coins
	for i, f in floors do
		p.floors[i + 1] = f
	end
	return p
end

describe("TowerRules", function()
	describe("costs", function()
		it("floorCost is the C2 table, nil outside 3..30", function()
			expect(TowerRules.floorCost(3)).toBe(129)
			expect(TowerRules.floorCost(30)).toBe(122_000_000_000)
			expect(TowerRules.floorCost(2)).toBeNil()
			expect(TowerRules.floorCost(31)).toBeNil()
		end)

		it("C4 check: a Server Rack to L5 costs 15 + 30 + 75 + 180 + 450 = 750", function()
			local parts = { 15, 30, 75, 180, 450 }
			local sum = 0
			for level = 1, 5 do
				expect(TowerRules.moduleCost("data", level, "normal")).toBe(parts[level])
				sum += TowerRules.moduleCost("data", level, "normal") :: number
			end
			expect(sum).toBe(750)
			expect(TowerRules.spentMax("data", 5)).toBe(750)
			expect(TowerRules.spentMax("data", 0)).toBe(0)
			expect(TowerRules.moduleCost("data", 6, "normal")).toBeNil()
			expect(TowerRules.moduleCost("data", 0, "normal")).toBeNil()
			expect(TowerRules.moduleCost("lobby", 1, "normal")).toBeNil()
		end)

		it("Flash Sale discounts module prices", function()
			expect(TowerRules.moduleCost("data", 1, "sale")).toBe(11)
			expect(TowerRules.moduleCost("data", 5, "sale")).toBe(337)
		end)
	end)

	describe("power (C5)", function()
		it("new profile: supply 6, draw 0 (empty Data Farm); one rack draws 1", function()
			local p = SpireProgress.defaults(NOW)
			expect(TowerRules.supply(p)).toBe(6)
			expect(TowerRules.draw(p)).toBe(0)
			local out, ok = TowerRules.buyModule(p, 2, 1, "normal")
			expect(ok).toBe(true)
			expect(TowerRules.draw(out)).toBe(1)
		end)

		it("six Server Racks: draw 6, a seventh is refused at the exact boundary", function()
			local p = tower(1000, { fl("data", { 1, 1, 1, 1 }), fl("data", { 1, 1, 0, 0 }) })
			expect(TowerRules.draw(p)).toBe(6)
			expect(TowerRules.supply(p)).toBe(6)
			local out, ok, code = TowerRules.buyModule(p, 3, 3, "normal")
			expect(ok).toBe(false)
			expect(code).toBe("power")
			expect(out).toBe(p)
			-- one fewer rack: the sixth fits exactly
			local q = tower(1000, { fl("data", { 1, 1, 1, 1 }), fl("data", { 1, 0, 0, 0 }) })
			local _, ok2 = TowerRules.buyModule(q, 3, 2, "normal")
			expect(ok2).toBe(true)
		end)

		it("one Fusion Cell L1 adds 8; fusion modules draw nothing", function()
			local p = tower(1000, { fl("data", { 1, 1, 1, 1 }), fl("fusion", { 1, 0, 0, 0 }) })
			expect(TowerRules.supply(p)).toBe(14)
			expect(TowerRules.draw(p)).toBe(4)
			local out, ok = TowerRules.buyModule(p, 3, 2, "normal")
			expect(ok).toBe(true)
			expect(TowerRules.supply(out)).toBe(22)
			local up = tower(0, { fl("fusion", { 5, 3, 0, 0 }) })
			expect(TowerRules.supply(up)).toBe(6 + 75 + 32)
		end)

		it("ad module needs 2 power: refused at draw 5 of 6", function()
			local p = tower(10_000, {
				fl("data", { 1, 1, 1, 1 }),
				fl("data", { 1, 0, 0, 0 }),
				fl("data", { 0, 0, 0, 0 }),
				fl("ad", { 0, 0, 0, 0 }),
			})
			local _, ok, code = TowerRules.buyModule(p, 5, 1, "normal")
			expect(ok).toBe(false)
			expect(code).toBe("power")
		end)

		it("selling a needed Fusion Cell is refused; an unneeded one refunds half", function()
			local p = tower(0, { fl("data", { 1, 1, 1, 1 }), fl("fusion", { 1, 0, 0, 0 }), fl("data", { 1, 1, 1, 0 }) })
			expect(TowerRules.draw(p)).toBe(7)
			local out, ok, code = TowerRules.sellModule(p, 3, 1)
			expect(ok).toBe(false)
			expect(code).toBe("needed")
			expect(out).toBe(p)
			local q = tower(0, { fl("data", { 1, 1, 1, 1 }), fl("fusion", { 1, 0, 0, 0 }) })
			local sold, ok2 = TowerRules.sellModule(q, 3, 1)
			expect(ok2).toBe(true)
			expect(sold.coins).toBe(75)
		end)
	end)

	describe("stacking (C6)", function()
		it("C6 check: 4 racks L3 between two active ad floors earn x1.5", function()
			local p = tower(0, { fl("ad", { 1, 0, 0, 0 }), fl("data", { 3, 3, 3, 3 }), fl("ad", { 1, 0, 0, 0 }) })
			expect(TowerRules.floorMult(p, 3, "normal")).toBe(1.5)
			expect(TowerRules.floorMult(p, 3, "neon")).toBe(2)
		end)

		it("+25% per active neighbour, +50% during Neon Night, not on ad or fusion floors", function()
			local p = tower(0, {
				fl("data", { 1, 0, 0, 0 }),
				fl("ad", { 1, 0, 0, 0 }),
				fl("fusion", { 1, 0, 0, 0 }),
				fl("ad", { 1, 0, 0, 0 }),
				fl("ad", { 0, 0, 0, 0 }),
				fl("data", { 1, 0, 0, 0 }),
			})
			expect(TowerRules.floorMult(p, 1, "normal")).toBe(1)
			expect(TowerRules.floorMult(p, 2, "normal")).toBe(1.25)
			expect(TowerRules.floorMult(p, 2, "neon")).toBe(1.5)
			expect(TowerRules.floorMult(p, 3, "normal")).toBe(1) -- ad
			expect(TowerRules.floorMult(p, 4, "normal")).toBe(1) -- fusion
			expect(TowerRules.floorMult(p, 5, "neon")).toBe(1) -- ad
			expect(TowerRules.floorMult(p, 7, "normal")).toBe(1) -- floor 6 is an empty ad floor
			expect(TowerRules.activeAd(p, 3)).toBe(true)
			expect(TowerRules.activeAd(p, 6)).toBe(false)
		end)
	end)

	describe("changes", function()
		it("buyFloor: appends an empty floor, charges C2, refuses in order", function()
			local p = tower(129, {})
			local out, ok = TowerRules.buyFloor(p, "fusion")
			expect(ok).toBe(true)
			expect(#out.floors).toBe(3)
			expect(out.floors[3].d).toBe("fusion")
			expect(out.coins).toBe(0)
			expect(#p.floors).toBe(2) -- input untouched
			expect(select(3, TowerRules.buyFloor(p, "nope"))).toBe("unknown")
			expect(select(3, TowerRules.buyFloor(p, "lobby"))).toBe("unknown")
			expect(select(3, TowerRules.buyFloor(p, "ad"))).toBe("locked") -- floor 3 < 5
			local poor = tower(128, {})
			expect(select(3, TowerRules.buyFloor(poor, "data"))).toBe("credits")
			local full = tower(1e15, {})
			for n = 3, 30 do
				full.floors[n] = fl("data", { 0, 0, 0, 0 })
			end
			expect(select(3, TowerRules.buyFloor(full, "data"))).toBe("max")
		end)

		it("department unlocks use the new floor number", function()
			expect(TowerRules.deptAllowed("ad", 5)).toBe(true)
			expect(TowerRules.deptAllowed("ad", 4)).toBe(false)
			expect(TowerRules.deptAllowed("synth", 8)).toBe(true)
			expect(TowerRules.deptAllowed("orbital", 22)).toBe(false)
			expect(TowerRules.deptAllowed("data", 1)).toBe(false)
			expect(TowerRules.deptAllowed("data", 31)).toBe(false)
			expect(TowerRules.deptAllowed("data", 2.5)).toBe(false)
		end)

		it("refitFloor: free, refuses in order", function()
			local p = tower(0, { fl("data", { 0, 0, 0, 0 }), fl("data", { 1, 0, 0, 0 }) })
			local out, ok = TowerRules.refitFloor(p, 3, "fusion")
			expect(ok).toBe(false) -- floor 3 has a module
			expect(out).toBe(p)
			expect(select(3, TowerRules.refitFloor(p, 3, "fusion"))).toBe("modules")
			expect(select(3, TowerRules.refitFloor(p, 1, "data"))).toBe("floor")
			expect(select(3, TowerRules.refitFloor(p, 5, "data"))).toBe("floor")
			expect(select(3, TowerRules.refitFloor(p, 2.5, "data"))).toBe("floor")
			expect(select(3, TowerRules.refitFloor(p, 2, "zzz"))).toBe("unknown")
			expect(select(3, TowerRules.refitFloor(p, 2, "data"))).toBe("same")
			expect(select(3, TowerRules.refitFloor(p, 2, "fusion"))).toBe("locked")
			local q = tower(0, { fl("data", { 0, 0, 0, 0 }), fl("data", { 0, 0, 0, 0 }) })
			local r, ok2 = TowerRules.refitFloor(q, 3, "fusion")
			expect(ok2).toBe(true)
			expect(r.floors[3].d).toBe("fusion")
		end)

		it("buyModule and upgradeModule record the price paid; refusals in order", function()
			local p = tower(1000, {})
			expect(select(3, TowerRules.buyModule(p, 1, 1, "normal"))).toBe("floor")
			expect(select(3, TowerRules.buyModule(p, 2, 5, "normal"))).toBe("floor")
			expect(select(3, TowerRules.buyModule(p, 2, 0, "normal"))).toBe("floor")
			expect(select(3, TowerRules.buyModule(p, 3, 1, "normal"))).toBe("floor")
			local a = TowerRules.buyModule(p, 2, 1, "sale")
			expect(a.coins).toBe(989)
			expect(a.floors[2].s[1]).toBe(11)
			expect(select(3, TowerRules.buyModule(a, 2, 1, "normal"))).toBe("occupied")
			local b = TowerRules.upgradeModule(a, 2, 1, "normal")
			expect(b.floors[2].m[1]).toBe(2)
			expect(b.floors[2].s[1]).toBe(41)
			expect(select(3, TowerRules.upgradeModule(b, 2, 2, "normal"))).toBe("empty")
			local poor = tower(14, {})
			expect(select(3, TowerRules.buyModule(poor, 2, 1, "normal"))).toBe("credits")
			local maxed = tower(1e6, { fl("data", { 5, 0, 0, 0 }) })
			expect(select(3, TowerRules.upgradeModule(maxed, 2, 1, "normal"))).toBe("max")
			local broke = tower(29, { fl("data", { 1, 0, 0, 0 }) })
			expect(select(3, TowerRules.upgradeModule(broke, 2, 1, "normal"))).toBe("credits")
		end)

		it("upgrades never check power", function()
			local p = tower(1e6, { fl("data", { 1, 1, 1, 1 }), fl("data", { 1, 1, 0, 0 }) })
			local _, ok = TowerRules.upgradeModule(p, 2, 1, "normal")
			expect(ok).toBe(true)
		end)

		it("C4 check: selling a L5 Server Rack refunds 375; refunds floor odd amounts", function()
			local p = tower(0, { fl("data", { 5, 0, 0, 0 }) })
			local out, ok = TowerRules.sellModule(p, 2, 1)
			expect(ok).toBe(true)
			expect(out.coins).toBe(375)
			expect(out.floors[2].m[1]).toBe(0)
			expect(out.floors[2].s[1]).toBe(0)
			local odd = tower(0, { { d = "data", m = { 1, 0, 0, 0 }, s = { 11, 0, 0, 0 } } })
			expect((TowerRules.sellModule(odd, 2, 1)).coins).toBe(5)
			expect(select(3, TowerRules.sellModule(p, 2, 2))).toBe("empty")
			expect(select(3, TowerRules.sellModule(p, 1, 1))).toBe("floor")
		end)

		it("hotSlots: filled non-fusion slots in floor then slot order", function()
			local p = tower(0, { fl("data", { 0, 1, 0, 1 }), fl("fusion", { 1, 1, 0, 0 }), fl("ad", { 1, 0, 0, 0 }) })
			local slots = TowerRules.hotSlots(p)
			expect(#slots).toBe(3)
			expect(slots[1].floor).toBe(2)
			expect(slots[1].slot).toBe(2)
			expect(slots[2].slot).toBe(4)
			expect(slots[3].floor).toBe(4)
		end)
	end)

	describe("layout", function()
		it("floorY: lobby 0, floor 2 at 20, floor 30 at 412, roof of 30 floors at 426", function()
			expect(TowerRules.floorY(1)).toBe(0)
			expect(TowerRules.floorY(2)).toBe(20)
			expect(TowerRules.floorY(30)).toBe(412)
			expect(TowerRules.floorY(31)).toBe(426)
		end)

		it("slot offsets and positions", function()
			local o = TowerRules.slotOffset(4)
			expect(o.x).toBe(10)
			expect(o.z).toBe(32)
			local s = TowerRules.slotPos(3, 1)
			expect(s.x).toBe(-10)
			expect(s.y).toBe(34)
			expect(s.z).toBe(12)
			local stand = TowerRules.standAt(2)
			expect(stand.y).toBe(23)
			expect(stand.z).toBe(15)
		end)

		it("liftAt on each boundary", function()
			local p = tower(0, { fl("data", { 0, 0, 0, 0 }), fl("data", { 0, 0, 0, 0 }) }) -- 3 floors, roof n = 4
			local c, radius, height = TowerRules.liftZone(3)
			expect(c.y).toBe(34)
			expect(radius).toBe(4)
			expect(height).toBe(10)
			expect(TowerRules.liftAt(p, { x = 0, y = 0, z = 22 })).toBe(1)
			expect(TowerRules.liftAt(p, { x = 0, y = 10, z = 22 })).toBe(1)
			expect(TowerRules.liftAt(p, { x = 0, y = 10.01, z = 22 })).toBeNil()
			expect(TowerRules.liftAt(p, { x = 4, y = 20, z = 22 })).toBe(2)
			expect(TowerRules.liftAt(p, { x = 4.01, y = 20, z = 22 })).toBeNil()
			expect(TowerRules.liftAt(p, { x = 0, y = 25, z = 18 })).toBe(2)
			expect(TowerRules.liftAt(p, { x = 0, y = 19.99, z = 22 })).toBeNil()
			expect(TowerRules.liftAt(p, { x = 0, y = 48, z = 22 })).toBe(4) -- the roof
			expect(TowerRules.liftAt(p, { x = 0, y = 62, z = 22 })).toBeNil() -- above the roof
			expect(TowerRules.liftAt(p, { x = 0, y = -0.1, z = 22 })).toBeNil()
		end)

		it("liftTarget: owned floors and the roof", function()
			local p = tower(0, { fl("data", { 0, 0, 0, 0 }), fl("data", { 0, 0, 0, 0 }) })
			expect(TowerRules.liftTarget(p, "roof")).toBe(4)
			expect(TowerRules.liftTarget(p, "1")).toBe(1)
			expect(TowerRules.liftTarget(p, "3")).toBe(3)
			expect(TowerRules.liftTarget(p, "4")).toBeNil()
			expect(TowerRules.liftTarget(p, "0")).toBeNil()
			expect(TowerRules.liftTarget(p, "1e0")).toBeNil()
			expect(TowerRules.liftTarget(p, "lobby")).toBeNil()
		end)
	end)
end)
