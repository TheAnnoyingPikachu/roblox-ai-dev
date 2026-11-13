--!strict
local T = require("./framework")
local Rng = require("../src/shared/Rng")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local StationProgress = require("../src/shared/StationProgress")

local describe, it, expect = T.describe, T.it, T.expect

local function hatched(id: string): StationRules.Owned
	return { s = id, stats = StationRules.versionStats(id, nil) :: StationConfig.Stats }
end

local function fresh(): StationProgress.Profile
	return StationProgress.defaults(0)
end

describe("StationProgress profile", function()
	it("starts with enough coins for three Meadow eggs and nothing else", function()
		local p = fresh()
		expect(p.coins).toBe(300)
		expect(#p.animals).toBe(0)
		expect(#p.team).toBe(0)
		expect(p.coins >= 3 * (StationConfig.egg("meadow") :: StationConfig.Egg).price).toBeTruthy()
	end)

	it("turns junk into a valid profile without erroring", function()
		for _, junk in { nil, 5, "x", {}, { coins = -5, animals = "no" }, { coins = 0 / 0, team = { 1, 2 } } } do
			local p = StationProgress.sanitize(junk, 100)
			expect(p.coins >= 0).toBeTruthy()
			expect(#p.animals).toBe(0)
			expect(#p.team).toBe(0)
		end
	end)

	it("drops bad animals, duplicate ids and bad team entries, and keeps good ones", function()
		local p = StationProgress.sanitize({
			coins = 1e20,
			nextId = 2,
			animals = {
				{ id = 1, s = "fox", stats = { speed = 45, strength = 15, stamina = 12, mana = 30 } },
				{ id = 1, s = "pig", stats = { speed = 1, strength = 1, stamina = 1, mana = 1 } }, -- duplicate id
				{ id = 2, s = "dragon", stats = { speed = 1, strength = 1, stamina = 1, mana = 1 } }, -- no species
				{ id = 3, s = "owl", v = "kitsune", stats = { speed = 9e9, strength = 1, stamina = 1, mana = 1 } },
				{ id = 4, s = "duck" }, -- no stats
				{
					id = 5,
					s = "goat",
					at = "gym",
					since = 50,
					stats = { speed = 25, strength = 45, stamina = 5, mana = 15 },
				},
			},
			team = { 1, 1, 9, 3, 5, "x" },
		}, 100)
		expect(p.coins).toBe(StationProgress.MAX_COINS)
		expect(#p.animals).toBe(3)
		local _, owl = StationProgress.find(p, 3)
		expect((owl :: StationProgress.Animal).v).toBeNil() -- kitsune is not an owl variant
		expect((owl :: StationProgress.Animal).stats.speed).toBe(StationConfig.STAT_MAX)
		expect(p.nextId).toBe(6)
		-- 1 and 3 in the team; 5 is training so it cannot be
		expect(#p.team).toBe(2)
		expect(table.find(p.team, 5)).toBeNil()
	end)

	it("is stable: sanitising a sanitised profile changes nothing", function()
		local p = fresh()
		p = StationProgress.buy(p, "meadow", hatched("fox"))
		p = StationProgress.train(p, 1, "track", 10)
		local a = StationProgress.sanitize(p, 20)
		local b = StationProgress.sanitize(a, 20)
		expect(#b.animals).toBe(#a.animals)
		expect(b.animals[1].at).toBe("track")
		expect(b.coins).toBe(a.coins)
	end)
end)

describe("StationProgress.buy", function()
	it("charges the price, adds the animal with a new id and fills the team to three", function()
		local p = fresh()
		local ok, id
		for k, sp in { "bunny", "pig", "duck", "mouse" } do
			p, ok, _, id = StationProgress.buy(p, "meadow", hatched(sp))
			if k <= 3 then
				expect(ok).toBe(true)
				expect(id).toBe(k)
			end
		end
		expect(ok).toBe(false) -- 300 coins buy three
		expect(p.coins).toBe(0)
		expect(#p.animals).toBe(3)
		expect(#p.team).toBe(3)
	end)

	it("refuses an unknown egg, too few coins and a full collection", function()
		local p = fresh()
		local _, ok, code = StationProgress.buy(p, "nope", hatched("fox"))
		expect(ok).toBe(false)
		expect(code).toBe("egg")
		_, ok, code = StationProgress.buy(p, "safari", hatched("owl"))
		expect(code).toBe("coins")
		p.coins = 1e9
		for _ = 1, StationProgress.MAX_ANIMALS do
			p = StationProgress.buy(p, "meadow", hatched("fox"))
		end
		_, ok, code = StationProgress.buy(p, "meadow", hatched("fox"))
		expect(code).toBe("full")
	end)

	it("works with a real seeded hatch", function()
		local a = StationRules.hatch("meadow", Rng.seed(3)) :: StationRules.Owned
		local p, ok = StationProgress.buy(fresh(), "meadow", a)
		expect(ok).toBe(true)
		expect(p.animals[1].s).toBe(a.s)
	end)
end)

describe("StationProgress team and training", function()
	local function three(): StationProgress.Profile
		local p = fresh()
		for _, sp in { "bunny", "pig", "duck" } do
			p = StationProgress.buy(p, "meadow", hatched(sp))
		end
		return p
	end

	it("toggles team membership and refuses a fourth", function()
		local p = three()
		local ok, code
		p, ok = StationProgress.toggleTeam(p, 2)
		expect(ok).toBe(true)
		expect(#p.team).toBe(2)
		p, ok = StationProgress.toggleTeam(p, 2)
		expect(#p.team).toBe(3)
		p.coins = 100
		p = StationProgress.buy(p, "meadow", hatched("frog"))
		_, ok, code = StationProgress.toggleTeam(p, 4)
		expect(code).toBe("team_full")
		_, ok, code = StationProgress.toggleTeam(p, 99)
		expect(code).toBe("animal")
	end)

	it("trains over time, takes the animal out of the team, and keeps points when stopped", function()
		local p = three()
		local ok
		p, ok = StationProgress.train(p, 1, "track", 1000)
		expect(ok).toBe(true)
		expect(table.find(p.team, 1)).toBeNil()
		local _, code = select(2, StationProgress.toggleTeam(p, 1))
		expect(code).toBe("training")
		p = StationProgress.stop(p, 1, 1000 + 10 * StationConfig.TRAIN_SECONDS)
		local _, a = StationProgress.find(p, 1)
		expect(StationRules.stat(a :: any, "speed")).toBe(50)
		expect((a :: StationProgress.Animal).at).toBeNil()
	end)

	it("settles on every save without double counting", function()
		local p = StationProgress.train(three(), 1, "track", 0)
		p = StationProgress.snapshot(p, 5 * StationConfig.TRAIN_SECONDS)
		p = StationProgress.snapshot(p, 5 * StationConfig.TRAIN_SECONDS)
		p = StationProgress.snapshot(p, 6 * StationConfig.TRAIN_SECONDS)
		local _, a = StationProgress.find(p, 1)
		expect(StationRules.stat(a :: any, "speed")).toBe(46)
	end)

	it("caps offline training per settle and the number training at once", function()
		local p = StationProgress.train(three(), 2, "gym", 0)
		p = StationProgress.snapshot(p, 10 * StationProgress.OFFLINE_MAX)
		local _, a = StationProgress.find(p, 2)
		local expected = 40 + math.min(40, StationProgress.OFFLINE_MAX / StationConfig.TRAIN_SECONDS)
		expect(StationRules.stat(a :: any, "strength")).toBe(expected)
		p.coins = 1e6
		for _, sp in { "goat", "frog", "fox" } do
			p = StationProgress.buy(p, "meadow", hatched(sp))
		end
		local ok, code
		for id = 1, 5 do
			p, ok, code = StationProgress.train(p, id, "pool", 0)
		end
		expect(ok).toBe(false)
		expect(code).toBe("train_full")
		_, ok, code = StationProgress.train(p, 1, "moon", 0)
		expect(code).toBe("station")
	end)
end)
