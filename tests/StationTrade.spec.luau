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

describe("StationTrade ledger (decision 0099)", function()
	it("writes a side newest first with its time, and keeps LEDGER_KEEP", function()
		local list = {}
		for n = 1, StationTrade.LEDGER_KEEP + 5 do
			list = StationTrade.ledgerAdd(list, { id = `t{n}` }, n)
		end
		expect(#list).toBe(StationTrade.LEDGER_KEEP)
		expect(list[1].id).toBe(`t{StationTrade.LEDGER_KEEP + 5}`)
		expect(list[1].at).toBe(StationTrade.LEDGER_KEEP + 5)
		expect(list[#list].id).toBe("t6") -- the five oldest went
	end)

	it("never changes the side it was given", function()
		local side = { id = "t1", give = { 1 } }
		local list = StationTrade.ledgerAdd({}, side, 5)
		expect(side.at).toBeNil()
		expect(list[1] == side).toBe(false)
	end)

	it("cancels every side of one trade, and nothing else", function()
		local list = StationTrade.ledgerAdd(StationTrade.ledgerAdd({}, { id = "a" }, 1), { id = "b" }, 2)
		table.insert(list, "junk") -- a damaged entry is skipped, not an error
		list = StationTrade.ledgerCancel(list, "a")
		expect(list[2].cancelled).toBe(true)
		expect(list[1].cancelled).toBeNil()
	end)
end)

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

describe("StationTrade safety (decision 0099)", function()
	local DAY = 86400
	it("opens at player level MIN_LEVEL and stops after PER_DAY trades in a UTC day", function()
		local p = save({ "jackal" })
		local ok, code = StationTrade.canTrade(p, DAY * 10)
		expect(ok).toBe(false)
		expect(code).toBe("trade_level")
		p.xp = StationProgress.xpFor(StationTrade.MIN_LEVEL)
		expect((StationTrade.canTrade(p, DAY * 10))).toBe(true)
		p.trades.day, p.trades.count = 10, StationTrade.PER_DAY
		local _, limit = StationTrade.canTrade(p, DAY * 10 + 5)
		expect(limit).toBe("trade_limit")
		expect((StationTrade.canTrade(p, DAY * 11))).toBe(true) -- a new day
		expect(StationTrade.left(p, DAY * 11)).toBe(StationTrade.PER_DAY)
	end)

	it("keeps a locked animal out of trades, and a traded copy arrives unlocked", function()
		local p = save({ "jackal", "lion" })
		StationTrade.lock(p, 1)
		local ok, code = StationTrade.canOffer(p, 1)
		expect(ok).toBe(false)
		expect(code).toBe("trade_locked")
		StationTrade.lock(p, 1)
		expect((StationTrade.canOffer(p, 1))).toBe(true)
		p.animals[2].locked = true
		local copy = StationTrade.copies(p, { 2 })[1]
		expect(copy.locked).toBeNil()
		local back = StationProgress.sanitize(p, 0)
		expect(back.animals[2].locked).toBe(true)
	end)

	it("commits a side once: the swap, the count and the history, and a second run changes nothing", function()
		local a, b = save({ "jackal", "lion" }), save({ "rhino" })
		local side = {
			id = "t1",
			with = "B",
			give = { 1 },
			get = StationTrade.copies(b, { 1 }),
			gave = { "Jackal" },
			got = { "Rhino" },
		}
		local _, ok = StationTrade.commit(a, side, DAY * 3)
		expect(ok).toBe(true)
		expect(#a.animals).toBe(2)
		expect(a.trades.count).toBe(1)
		expect(a.trades.total).toBe(1)
		expect(a.trades.log[1].id).toBe("t1")
		local _, again = StationTrade.commit(a, side, DAY * 3)
		expect(again).toBe(true)
		expect(a.trades.count).toBe(1)
		expect(#a.animals).toBe(2)
		local stored = StationProgress.sanitize(a, 0)
		expect(StationTrade.has(stored, "t1")).toBe(true)
	end)

	it("weighs both sides on the fairness meter and warns when one is far behind", function()
		local p = save({ "jackal", "jackal", "lion" })
		local mythic = { s = "lion", v = "sun_lion", stats = p.animals[3].stats, rainbow = true }
		local even, warnEven = StationTrade.balance({ p.animals[1] }, { p.animals[2] })
		expect(math.abs(even - 0.5) < 0.01).toBeTruthy()
		expect(warnEven).toBe(false)
		local tilt, warn = StationTrade.balance({ p.animals[1] }, { mythic :: any })
		expect(tilt > 0.9).toBeTruthy()
		expect(warn).toBe(true)
	end)
end)
