--!strict
-- DepotRules (architecture lantern 3.6, 8; GDD F): prices and caps, purchases, tallies, leftover.
local T = require("./framework")
local DepotRules = require("../src/shared/DepotRules")

local describe, it, expect = T.describe, T.it, T.expect

local function pools(parts: number, coal: number, oil: number, b: number?, k: number?, l: number?): DepotRules.Pools
	return { parts = parts, coal = coal, oil = oil, levels = { boiler = b or 1, bunker = k or 1, lamps = l or 1 } }
end

describe("DepotRules", function()
	it("prices the upgrades at II and III, then nil when maxed (GDD F)", function()
		local rows = {}
		for _, id in { "boiler", "bunker", "lamps" } do
			local prices = {}
			for level = 1, 3 do
				local p = pools(0, 0, 0);
				(p.levels :: any)[id] = level
				table.insert(prices, tostring(DepotRules.price(p, id)))
			end
			table.insert(rows, `{id} {table.concat(prices, "/")}`)
		end
		expect(table.concat(rows, ", ")).toBe("boiler 30/60/nil, bunker 25/50/nil, lamps 30/60/nil")
		expect(DepotRules.price(pools(0, 50, 0), "coal")).toBe(12) -- 30 fits under 80
		expect(DepotRules.price(pools(0, 51, 0), "coal")).toBeNil()
		expect(DepotRules.price(pools(0, 51, 0, 1, 2), "coal")).toBe(12) -- the Bunker II cap is 100
		expect(DepotRules.price(pools(0, 0, 4), "oil")).toBe(10)
		expect(DepotRules.price(pools(0, 0, 5), "oil")).toBeNil()
		expect(DepotRules.price(pools(0, 0, 0), "nope")).toBeNil()
	end)

	it("buys from the Parts pool, keeps the coal on a bunker upgrade and refuses with the right code", function()
		local out, ok = DepotRules.buy(pools(100, 70, 1), "bunker")
		expect(`{ok} {out.parts} {out.coal} {out.levels.bunker} {DepotRules.bunker(out.levels)}`).toBe(
			"true 75 70 2 100"
		)
		out = DepotRules.buy(out, "coal")
		expect(`{out.parts} {out.coal}`).toBe("63 100")
		out = DepotRules.buy(out, "oil")
		expect(`{out.parts} {out.oil}`).toBe("53 3")
		local _, refused, code = DepotRules.buy(out, "coal")
		expect(`{refused} {code}`).toBe("false full")
		expect(select(3, DepotRules.buy(pools(100, 0, 5), "oil"))).toBe("full")
		expect(select(3, DepotRules.buy(pools(29, 0, 0), "boiler"))).toBe("parts")
		expect(select(3, DepotRules.buy(pools(999, 0, 0, 3), "boiler"))).toBe("max")
		expect(select(3, DepotRules.buy(pools(999, 0, 0), "turbo"))).toBe("unknown")
		local p = pools(60, 0, 0)
		DepotRules.buy(p, "lamps")
		expect(`{p.parts} {p.levels.lamps}`).toBe("60 1") -- the input is not changed
	end)

	it("maps levels to cruise, bunker, puff and range", function()
		local rows = {}
		for level = 1, 3 do
			local l = { boiler = level, bunker = level, lamps = level }
			table.insert(
				rows,
				`{DepotRules.cruise(l)}/{DepotRules.bunker(l)}/{DepotRules.puff(l)}/{DepotRules.range(l)}`
			)
		end
		expect(table.concat(rows, " ")).toBe("20/80/0.6/80 23/100/0.45/90 26/120/0.35/100")
	end)

	it("tallies a majority; a tie or no votes gives the default", function()
		local opts = { "forest", "lake" }
		expect(DepotRules.tally({ [1] = "lake", [2] = "lake", [3] = "forest" }, opts, "forest")).toBe("lake")
		expect(DepotRules.tally({ [1] = "lake", [2] = "forest" }, opts, "forest")).toBe("forest")
		expect(DepotRules.tally({}, opts, "forest")).toBe("forest")
		expect(DepotRules.tally({ [1] = "weekly", [2] = "lake" }, opts, "forest")).toBe("lake") -- other votes ignored
		expect(DepotRules.tally({ [1] = "weekly" }, { "free", "weekly" }, "free")).toBe("weekly")
		expect(DepotRules.tally({ [1] = "weekly", [2] = "free" }, { "free", "weekly" }, "free")).toBe("free")
	end)

	it("shares leftover Parts as ceil(Parts / n)", function()
		local got = {}
		for _, case in { { 0, 3 }, { 10, 3 }, { 12, 4 }, { 7, 0 }, { 42, 1 } } do
			table.insert(got, DepotRules.leftover(case[1], case[2]))
		end
		expect(table.concat(got, " ")).toBe("0 4 3 7 42")
	end)
end)
