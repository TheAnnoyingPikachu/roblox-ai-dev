--!strict
local T = require("./framework")
local StationProgress = require("../src/shared/StationProgress")
local StationTrade = require("../src/shared/StationTrade")

local describe, it, expect = T.describe, T.it, T.expect

-- A save holding the given animals (species ids), the first three on the team.
local function save(species: { string }): StationProgress.Profile
	local p = StationProgress.defaults(0)
	p.upgrades.barn = 5 -- room to receive
	for _, s in species do
		p = (StationProgress.give(p, s, nil, 3, false))
	end
	return p
end

describe("StationTrade", function()
	it("lets an owned animal be offered, not a missing or a training one, and at most MAX", function()
		local p = save({ "jackal", "lion", "rhino", "meerkat", "cheetah" })
		expect((StationTrade.canOffer(p, 1))).toBe(true)
		local ok, code = StationTrade.canOffer(p, 99)
		expect(ok).toBe(false)
		expect(code).toBe("trade_unknown")
		p.animals[2].at, p.animals[2].since = "gym", 0
		ok, code = StationTrade.canOffer(p, 2)
		expect(ok).toBe(false)
		expect(code).toBe("trade_training")
		local offer = {}
		for _, id in { 1, 3, 4, 5 } do
			offer = (StationTrade.toggle(p, offer, id))
		end
		expect(#offer).toBe(StationTrade.MAX)
		p = (StationProgress.give(p, "tortoise", nil, 3, false))
		local same, okMore, why = StationTrade.toggle(p, offer, 6)
		expect(okMore).toBe(false)
		expect(why).toBe("trade_max")
		expect(#same).toBe(StationTrade.MAX)
		local fewer = StationTrade.toggle(p, offer, 3) -- toggling again takes it out
		expect(#fewer).toBe(StationTrade.MAX - 1)
		expect(table.find(fewer, 3)).toBeNil()
	end)

	it("swaps copies under new ids, off the team, the stats and coat kept, and nothing duplicated", function()
		local a = save({ "jackal", "lion" })
		local b = save({ "rhino" })
		a.animals[2].rainbow = true
		local fromA, fromB = StationTrade.copies(a, { 2 }), StationTrade.copies(b, { 1 })
		local a2, okA = StationTrade.swap(a, { 2 }, fromB)
		local b2, okB = StationTrade.swap(b, { 1 }, fromA)
		expect(okA and okB).toBe(true)
		expect(#a2.animals).toBe(2)
		expect(#b2.animals).toBe(1)
		local _, lion = StationProgress.find(b2, b2.animals[1].id)
		expect((lion :: any).s).toBe("lion")
		expect((lion :: any).rainbow).toBe(true)
		expect((lion :: any).trained.speed).toBe(3)
		expect(table.find(a2.team, 2)).toBeNil() -- the lion left A's team
		expect(a2.animals[2].id).toBe(3) -- A's next id, not B's
		local ids = {}
		for _, x in a2.animals do
			expect(ids[x.id]).toBeNil()
			ids[x.id] = true
		end
	end)

	it("refuses when an offered animal is gone or training by the time of the swap, changing nothing", function()
		local a = save({ "jackal", "lion" })
		local before = #a.animals
		a.animals[1].at, a.animals[1].since = "track", 0
		local same, ok, code = StationTrade.swap(a, { 1 }, {})
		expect(ok).toBe(false)
		expect(code).toBe("trade_training")
		expect(#same.animals).toBe(before)
		local _, ok2, code2 = StationTrade.swap(a, { 42 }, {})
		expect(ok2).toBe(false)
		expect(code2).toBe("trade_unknown")
	end)

	it("refuses to take in more than the Barn keeps, but lets a full save swap even", function()
		local a = save({ "jackal", "lion", "rhino" })
		a.upgrades.barn = nil -- the Barn's base
		local keep = StationProgress.value(a, "barn")
		while #a.animals < keep do
			a = (StationProgress.give(a, "meerkat", nil, 1, false))
		end
		local gift = StationTrade.copies(save({ "cheetah" }), { 1 })
		local _, ok, code = StationTrade.swap(a, {}, gift)
		expect(ok).toBe(false)
		expect(code).toBe("trade_full")
		local _, okEven = StationTrade.swap(a, { 1 }, gift)
		expect(okEven).toBe(true)
	end)

	it("hands the Titan's slot to another Titan when the Titan leaves, or empties it", function()
		local a = save({ "elephant", "jackal" })
		expect(a.titan).toBe(1)
		local a2 = StationTrade.swap(a, { 1 }, {})
		expect(a2.titan).toBeNil()
		local b = save({ "elephant", "elephant" })
		local b2 = StationTrade.swap(b, { 1 }, {})
		expect(b2.titan).toBe(2)
	end)
end)
