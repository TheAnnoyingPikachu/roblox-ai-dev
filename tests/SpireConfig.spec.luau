--!strict
local T = require("./framework")
local SpireConfig = require("../src/shared/SpireConfig")

local describe, it, expect = T.describe, T.it, T.expect

-- GDD C2 and C3, D2 and the decor table of decision 0009.
local C2 = {
	129,
	277,
	596,
	1_280,
	2_760,
	5_930,
	12_700,
	27_400,
	58_900,
	127_000,
	272_000,
	585_000,
	1_260_000,
	2_710_000,
	5_820_000,
	12_500_000,
	26_900_000,
	57_800_000,
	124_000_000,
	267_000_000,
	575_000_000,
	1_240_000_000,
	2_660_000_000,
	5_710_000_000,
	12_300_000_000,
	26_400_000_000,
	56_800_000_000,
	122_000_000_000,
}
local C3 = { -- id, income, draw, cost, unlock, tier
	{ "data", 1, 1, 15, 1, 1 },
	{ "fusion", 0, 0, 150, 3, 1 },
	{ "ad", 6, 2, 600, 5, 2 },
	{ "synth", 40, 4, 8_000, 8, 3 },
	{ "drone", 250, 6, 150_000, 12, 4 },
	{ "quantum", 1_600, 10, 3_000_000, 17, 5 },
	{ "orbital", 10_000, 16, 60_000_000, 23, 6 },
}
local D2 = { -- id, cost, hype, w, d, max, floors (hype) or level (decor)
	{ "bench", 100, 1, 1, 1, 12, 2 },
	{ "palm", 800, 2, 1, 1, 10, 3 },
	{ "vending", 6_000, 3, 1, 1, 8, 5 },
	{ "noodle", 40_000, 5, 2, 1, 6, 7 },
	{ "arcade", 300_000, 8, 2, 2, 4, 10 },
	{ "fountain", 2_500_000, 12, 2, 2, 2, 13 },
	{ "maglev", 20_000_000, 20, 3, 2, 1, 17 },
	{ "billboard", 150_000_000, 25, 2, 1, 2, 21 },
	{ "idol", 1_500_000_000, 40, 3, 3, 1, 25 },
	{ "lamp", 150, 0, 1, 1, 0, 1 },
	{ "bollard", 50, 0, 1, 1, 0, 1 },
	{ "planter", 300, 0, 1, 1, 0, 2 },
	{ "arrow", 500, 0, 1, 1, 0, 3 },
	{ "puddle", 100, 0, 1, 1, 0, 4 },
	{ "trashbot", 1_000, 0, 1, 1, 0, 6 },
	{ "arch", 2_000, 0, 2, 1, 0, 8 },
	{ "koi", 2_000, 0, 2, 2, 0, 10 },
}

describe("SpireConfig", function()
	it("floor cost table matches C2 for floors 3 to 30 and nothing else", function()
		for n = 3, 30 do
			expect(SpireConfig.FLOOR_COST[n]).toBe(C2[n - 2])
		end
		local keys = 0
		for _ in SpireConfig.FLOOR_COST do
			keys += 1
		end
		expect(keys).toBe(28)
		expect(SpireConfig.FLOOR_COST[2]).toBeNil()
	end)

	it("floor costs are within 1% of 60 x 2.15^(n - 2)", function()
		for n = 3, 30 do
			local formula = 60 * 2.15 ^ (n - 2)
			expect(math.abs(SpireConfig.FLOOR_COST[n] / formula - 1) < 0.01).toBeTruthy()
		end
	end)

	it("departments match C3 in order", function()
		expect(#SpireConfig.DEPTS).toBe(7)
		for i, row in C3 do
			local d = SpireConfig.DEPTS[i]
			expect(d.id).toBe(row[1])
			expect(d.income).toBe(row[2])
			expect(d.draw).toBe(row[3])
			expect(d.cost).toBe(row[4])
			expect(d.unlock).toBe(row[5])
			expect(d.tier).toBe(row[6])
			expect(SpireConfig.dept(row[1] :: string)).toBe(d)
		end
		expect(SpireConfig.dept("lobby")).toBeNil()
		expect(SpireConfig.dept("nope")).toBeNil()
	end)

	it("plaza items match D2 and the decor table", function()
		expect(#SpireConfig.ITEMS).toBe(17)
		for i, row in D2 do
			local item = SpireConfig.ITEMS[i]
			expect(item.id).toBe(row[1])
			expect(item.cost).toBe(row[2])
			expect(item.hype).toBe(row[3])
			expect(item.w).toBe(row[4])
			expect(item.d).toBe(row[5])
			expect(item.decor).toBe(i > 9)
			if item.decor then
				expect(item.max).toBeNil()
				expect(item.level).toBe(row[7])
				expect(item.cost <= 2_000).toBeTruthy()
			else
				expect(item.max).toBe(row[6])
				expect(item.floors).toBe(row[7])
			end
			expect(string.match(item.id, "^%l+$")).toBe(item.id)
			expect(SpireConfig.item(item.id)).toBe(item)
		end
	end)

	it("all hype items give 252 Hype and need 85 cells", function()
		local hype, cells = 0, 0
		for _, item in SpireConfig.ITEMS do
			if not item.decor then
				hype += item.hype * (item.max :: number)
				cells += item.w * item.d * (item.max :: number)
			end
		end
		expect(hype).toBe(252)
		expect(cells).toBe(85)
	end)

	it("unlock floors strictly increase", function()
		for i = 2, #SpireConfig.DEPTS do
			expect(SpireConfig.DEPTS[i].unlock > SpireConfig.DEPTS[i - 1].unlock).toBeTruthy()
		end
		for i = 2, 9 do
			expect((SpireConfig.ITEMS[i].floors :: number) > (SpireConfig.ITEMS[i - 1].floors :: number)).toBeTruthy()
		end
	end)

	it("every event row sums to 10000 and lists EVENTS in order", function()
		for _, row in { SpireConfig.EVENT_ODDS.weekday, SpireConfig.EVENT_ODDS.weekend } do
			local sum = 0
			for i, o in row do
				expect(o.id).toBe(SpireConfig.EVENTS[i].id)
				sum += o.bp
			end
			expect(sum).toBe(10000)
		end
		expect(SpireConfig.EVENT_ODDS.weekday[2].bp).toBe(2000)
		expect(SpireConfig.EVENT_ODDS.weekend[4].bp).toBe(2000)
	end)

	it("ids are unique across departments, items, events, cosmetics and quests", function()
		for _, list in
			{ SpireConfig.DEPTS, SpireConfig.ITEMS, SpireConfig.EVENTS, SpireConfig.COSMETICS, SpireConfig.QUESTS }
		do
			local seen = {}
			for _, entry in list :: { any } do
				expect(seen[entry.id]).toBeNil()
				seen[entry.id] = true
			end
		end
	end)

	it("names: 24 prefixes and 16 suffixes in GDD order", function()
		expect(#SpireConfig.NAMES.prefixes).toBe(24)
		expect(#SpireConfig.NAMES.suffixes).toBe(16)
		expect(SpireConfig.NAMES.prefixes[1]).toBe("Neon")
		expect(SpireConfig.NAMES.prefixes[24]).toBe("Zero")
		expect(SpireConfig.NAMES.suffixes[16]).toBe("Interactive")
		expect(SpireConfig.companyName({ p = 13, s = 9, glyph = 1, colour = 1, trim = 1 })).toBe("Volt Robotics")
		expect(#SpireConfig.COLOURS).toBe(8)
		expect(SpireConfig.GLYPHS).toBe(12)
	end)

	it("every ACTIONS pattern compiles", function()
		for _, spec in SpireConfig.ACTIONS do
			if spec.pattern then
				local ok = pcall(string.match, "x", spec.pattern)
				expect(ok).toBeTruthy()
			end
		end
		expect(SpireConfig.ACTIONS.lift.profile).toBe(false)
		expect(SpireConfig.ACTIONS.home.profile).toBe(false)
		expect(SpireConfig.ACTIONS.home.pattern).toBeNil()
	end)

	it("CODES entries are unique", function()
		local seen = {}
		for _, code in SpireConfig.CODES do
			expect(seen[code]).toBeNil()
			seen[code] = true
		end
		expect(#SpireConfig.CODES).toBe(26)
	end)

	it("every slot default is a cosmetic in that slot, unlocked at level 1", function()
		for slot, id in SpireConfig.SLOT_DEFAULTS do
			local found = nil
			for _, c in SpireConfig.COSMETICS do
				if c.id == id then
					found = c
				end
			end
			expect(found ~= nil and found.slot == slot and found.level == 1).toBeTruthy()
		end
	end)

	it("cosmetics match the decision 0009 table", function()
		local byId = {}
		for _, c in SpireConfig.COSMETICS do
			byId[c.id] = c
		end
		expect(byId.halo.level).toBe(5)
		expect(byId.needle.level).toBe(12)
		expect(byId.holoLogo.price).toBe(2_000_000)
		expect(byId.goldLobby.price).toBe(50_000_000)
		expect(byId.chromeTiles.price).toBe(500_000)
		expect(byId.circuit.level).toBe(15)
		expect(byId.magentaTrail.level).toBe(8)
		for id, shares in { chrome = 1, carbon = 10, jade = 30, prism = 75, satellite = 10, goldTrail = 1 } do
			expect(SpireConfig.SHARE_UNLOCKS[id]).toBe(shares)
			expect(byId[id].level == nil and byId[id].price == nil).toBeTruthy()
		end
		expect(#SpireConfig.COSMETICS).toBe(22)
	end)

	it("quests match the decision 0009 contract table", function()
		local q = SpireConfig.QUESTS
		expect(#q).toBe(8)
		expect(q[7].id).toBe("earn1h")
		expect(q[7].stat).toBe("earnSeconds")
		expect(q[7].goal).toBe(3_600)
		expect(q[7].reward).toBe(1_000)
		expect(q[7].minutes).toBe(15)
		expect(SpireConfig.WEEKLY.reward).toBe(1_000)
		expect(SpireConfig.DAILY[7]).toBe(800)
	end)
end)
