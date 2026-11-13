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

-- Every stat set to `x`.
local function full(x: number): StationConfig.Stats
	return { speed = x, strength = x, stamina = x, mana = x, health = x, defence = x }
end

-- Seconds on a station to take a stat from level 0 to level n.
local function secondsTo(n: number): number
	return StationConfig.LEVEL_SECONDS * n * (n + 1) / 2
end

local function animal(p: StationProgress.Profile, id: number): StationProgress.Animal
	local _, a = StationProgress.find(p, id)
	return a :: StationProgress.Animal
end

describe("StationProgress profile", function()
	it("starts at player level 1 with enough coins for three Meadow eggs and nothing else", function()
		local p = fresh()
		expect(p.coins).toBe(300)
		expect(p.xp).toBe(0)
		expect(StationProgress.playerLevel(p)).toBe(1)
		expect(#p.animals).toBe(0)
		expect(#p.team).toBe(0)
		expect(p.titan).toBeNil()
		expect(p.coins >= 3 * (StationConfig.egg("meadow") :: StationConfig.Egg).price).toBeTruthy()
	end)

	it("turns junk into a valid profile without erroring", function()
		for _, junk in { nil, 5, "x", {}, { coins = -5, animals = "no" }, { coins = 0 / 0, team = { 1, 2 }, xp = "9" } } do
			local p = StationProgress.sanitize(junk, 100)
			expect(p.coins >= 0).toBeTruthy()
			expect(p.xp).toBe(0)
			expect(#p.animals).toBe(0)
			expect(#p.team).toBe(0)
		end
	end)

	it("drops unknown animals and duplicate ids, and repairs the rest instead of losing them", function()
		local p = StationProgress.sanitize({
			coins = 1e20,
			xp = -5,
			nextId = 2,
			animals = {
				{ id = 1, s = "jackal", stats = full(30) },
				{ id = 1, s = "tortoise", stats = full(1) }, -- duplicate id: dropped
				{ id = 2, s = "dragon", stats = full(1) }, -- unknown species: dropped
				{
					id = 3,
					s = "rhino",
					v = "sun_lion", -- not a rhino variant
					stats = { speed = 9e9, strength = 1, stamina = 1, mana = 1, health = 1, defence = 1 },
				},
				{ id = 4, s = "meerkat" }, -- no stats at all: rebuilt from the Meerkat's basic stats
				{ id = 5, s = "tortoise", at = "gym", since = 50, stats = full(20) },
				{
					-- a save from before Health and Defence existed, with a broken level table
					id = 6,
					s = "jackal",
					stats = { speed = 44, strength = 20, stamina = 15, mana = 18 },
					trained = { speed = 99, strength = "x" },
				},
			},
			team = { 1, 1, 9, 3, 5, "x" },
		}, 100)
		expect(p.coins).toBe(StationProgress.MAX_COINS)
		expect(p.xp).toBe(0)
		expect(#p.animals).toBe(5)
		expect(animal(p, 3).v).toBeNil()
		expect(animal(p, 3).stats.speed).toBe(StationConfig.STAT_MAX)
		expect(animal(p, 4).stats.mana).toBe(42)
		expect(animal(p, 4).stats.defence).toBe(8)
		local old = animal(p, 6)
		expect(old.stats.speed).toBe(44)
		expect(old.stats.health).toBe(30)
		expect(old.stats.defence).toBe(10)
		local levels = old.trained :: StationConfig.Stats
		expect(levels.speed).toBe(StationConfig.MAX_LEVEL)
		expect(levels.strength).toBe(0)
		expect(levels.defence).toBe(0)
		expect(p.nextId).toBe(7)
		-- 1 and 3 in the team; 5 is training so it cannot be
		expect(#p.team).toBe(2)
		expect(table.find(p.team, 5)).toBeNil()
	end)

	it("is stable: sanitising a sanitised profile changes nothing", function()
		local p = fresh()
		p = StationProgress.buy(p, "meadow", hatched("jackal"))
		p = StationProgress.train(p, 1, "track", 10)
		p = StationProgress.snapshot(p, 500)
		local a = StationProgress.sanitize(p, 600)
		local b = StationProgress.sanitize(a, 600)
		expect(#b.animals).toBe(#a.animals)
		expect(b.animals[1].at).toBe("track")
		expect(b.animals[1].since).toBe(500)
		expect((b.animals[1].trained :: StationConfig.Stats).speed).toBe(
			(p.animals[1].trained :: StationConfig.Stats).speed
		)
		expect(b.coins).toBe(a.coins)
		expect(b.xp).toBe(p.xp)
	end)
end)

describe("StationProgress player level", function()
	it("needs 25 x (level - 1)^2 XP: level 2 at 25, level 15 at 4,900", function()
		expect(StationProgress.xpFor(1)).toBe(0)
		expect(StationProgress.xpFor(2)).toBe(25)
		expect(StationProgress.xpFor(15)).toBe(4900)
		local p = fresh()
		for _, xp in { 0, 24, 25, 99, 100, 4899, 4900, 123456, StationProgress.MAX_XP } do
			p.xp = xp
			local level = StationProgress.playerLevel(p)
			expect(StationProgress.xpFor(level) <= xp).toBeTruthy()
			expect(xp < StationProgress.xpFor(level + 1)).toBeTruthy()
		end
		p.xp = 4899
		expect(StationProgress.playerLevel(p)).toBe(14)
		p.xp = 4900
		expect(StationProgress.playerLevel(p)).toBe(15)
	end)
end)

describe("StationProgress.buy", function()
	it("charges the price, gives XP, adds the animal with a new id and fills the team to three", function()
		local p = fresh()
		local ok, id
		for k, sp in { "jackal", "tortoise", "meerkat", "jackal" } do
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
		expect(p.xp).toBe(3 * (StationConfig.egg("meadow") :: StationConfig.Egg).xp)
		expect(StationProgress.playerLevel(p)).toBe(2)
	end)

	it("refuses an unknown egg, too few coins and a full collection", function()
		local p = fresh()
		local _, ok, code = StationProgress.buy(p, "nope", hatched("jackal"))
		expect(ok).toBe(false)
		expect(code).toBe("egg")
		_, ok, code = StationProgress.buy(p, "safari", hatched("lion"))
		expect(code).toBe("coins")
		p.coins = 1e9
		for _ = 1, StationProgress.MAX_ANIMALS do
			p = StationProgress.buy(p, "meadow", hatched("jackal"))
		end
		_, ok, code = StationProgress.buy(p, "meadow", hatched("jackal"))
		expect(code).toBe("full")
	end)

	it("keeps the Legendary Egg locked until player level 15, whatever the coins", function()
		local p = fresh()
		p.coins = 1e9
		p.xp = StationProgress.xpFor(15) - 1
		local ok, code = StationProgress.canBuy(p, "legendary")
		expect(ok).toBe(false)
		expect(code).toBe("locked")
		local _, bought = StationProgress.buy(p, "legendary", hatched("elephant"))
		expect(bought).toBe(false)
		expect(#p.animals).toBe(0)
		expect(p.coins).toBe(1e9)
		p.xp = StationProgress.xpFor(15)
		expect((StationProgress.canBuy(p, "legendary"))).toBe(true)
		p, bought = StationProgress.buy(p, "legendary", hatched("elephant"))
		expect(bought).toBe(true)
		expect(p.titan).toBe(1)
		expect(p.coins).toBe(1e9 - (StationConfig.egg("legendary") :: StationConfig.Egg).price)
	end)

	it("works with a real seeded hatch", function()
		local a = StationRules.hatch("meadow", Rng.seed(3)) :: StationRules.Owned
		local p, ok = StationProgress.buy(fresh(), "meadow", a)
		expect(ok).toBe(true)
		expect(p.animals[1].s).toBe(a.s)
		-- the base levels rolled at hatch come along, as a copy
		for _, stat in StationConfig.STATS do
			expect(StationRules.level(p.animals[1] :: any, stat)).toBe(StationRules.level(a, stat))
			expect(StationRules.level(a, stat) >= 1).toBeTruthy()
		end
		expect(p.animals[1].trained ~= a.trained).toBeTruthy()
	end)
end)

describe("StationProgress team and training", function()
	local function three(): StationProgress.Profile
		local p = fresh()
		for _, sp in { "jackal", "tortoise", "meerkat" } do
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
		p = StationProgress.buy(p, "meadow", hatched("jackal"))
		_, ok, code = StationProgress.toggleTeam(p, 4)
		expect(code).toBe("team_full")
		_, ok, code = StationProgress.toggleTeam(p, 99)
		expect(code).toBe("animal")
	end)

	it("levels a stat over time, takes the animal out of the team, and keeps the levels when stopped", function()
		local p = three()
		local ok
		p, ok = StationProgress.train(p, 1, "track", 1000)
		expect(ok).toBe(true)
		expect(table.find(p.team, 1)).toBeNil()
		local _, code = select(2, StationProgress.toggleTeam(p, 1))
		expect(code).toBe("training")
		p = StationProgress.stop(p, 1, 1000 + secondsTo(7))
		local a = animal(p, 1)
		expect(StationRules.level(a :: any, "speed")).toBe(7)
		expect(StationRules.stat(a :: any, "speed")).toBe(46) -- 42 x (1 + 7/70) = 46.2
		expect(a.at).toBeNil()
		local _, stopped, why = StationProgress.stop(p, 1, 5000)
		expect(stopped).toBe(false)
		expect(why).toBe("idle")
	end)

	it("settles on every save without double counting", function()
		local p = StationProgress.train(three(), 1, "track", 0)
		p = StationProgress.snapshot(p, 100)
		p = StationProgress.snapshot(p, 100)
		p = StationProgress.snapshot(p, 150)
		local once = StationRules.train(hatched("jackal"), "track", 150)
		local got = (animal(p, 1).trained :: StationConfig.Stats).speed
		expect(math.abs(got - (once.trained :: StationConfig.Stats).speed) < 1e-9).toBeTruthy()
		expect(StationRules.level(animal(p, 1) :: any, "speed")).toBe(2)
	end)

	it("counts at most 8 hours of training per settle while away", function()
		local p = StationProgress.train(three(), 2, "gym", 0)
		p = StationProgress.snapshot(p, 10 * StationProgress.OFFLINE_MAX)
		local capped = StationRules.train(hatched("tortoise"), "gym", StationProgress.OFFLINE_MAX)
		local level = StationRules.level(animal(p, 2) :: any, "strength")
		expect(level).toBe(StationRules.level(capped, "strength"))
		expect(level > 0 and level < StationConfig.MAX_LEVEL).toBeTruthy()
	end)

	it("lets four animals train at once and refuses an unknown station", function()
		local p = three()
		p.coins = 1e6
		for _, sp in { "tortoise", "meerkat", "jackal" } do
			p = StationProgress.buy(p, "meadow", hatched(sp))
		end
		local ok, code
		for id = 1, 5 do
			p, ok, code = StationProgress.train(p, id, "pool", 0)
		end
		expect(ok).toBe(false)
		expect(code).toBe("train_full")
		-- moving one that is already training is not a fifth
		p, ok = StationProgress.train(p, 1, "guard", 60)
		expect(ok).toBe(true)
		expect(animal(p, 1).at).toBe("guard")
		_, ok, code = StationProgress.train(p, 1, "moon", 0)
		expect(code).toBe("station")
	end)

	it("finishes training at level 70: the animal is freed and that stat cannot be trained again", function()
		local p = StationProgress.train(three(), 1, "track", 0)
		for k = 1, 4 do -- 8 hours count per settle; level 70 needs about 21
			p = StationProgress.snapshot(p, k * StationProgress.OFFLINE_MAX)
		end
		local a = animal(p, 1)
		expect(StationRules.level(a :: any, "speed")).toBe(StationConfig.MAX_LEVEL)
		expect(a.at).toBeNil()
		expect(a.since).toBeNil()
		local now = 5 * StationProgress.OFFLINE_MAX
		local _, ok, code = StationProgress.train(p, 1, "track", now)
		expect(ok).toBe(false)
		expect(code).toBe("maxed")
		p, ok = StationProgress.train(p, 1, "gym", now)
		expect(ok).toBe(true)
	end)

	it("keeps the Titan in its own fourth slot, outside the team of three, one at a time", function()
		local p = three()
		p.coins = 1e9
		p.xp = StationProgress.xpFor(15)
		local ok
		p = StationProgress.buy(p, "legendary", hatched("elephant")) -- id 4
		expect(p.titan).toBe(4)
		expect(#p.team).toBe(3)
		local fighters = StationProgress.fighters(p)
		expect(#fighters).toBe(4)
		expect(fighters[4].id).toBe(4) -- the Titan fights last in the line
		p = StationProgress.buy(p, "legendary", hatched("elephant")) -- id 5: the slot is taken
		expect(p.titan).toBe(4)
		p, ok = StationProgress.toggleTeam(p, 5) -- swaps the Titan
		expect(ok).toBe(true)
		expect(p.titan).toBe(5)
		expect(#StationProgress.fighters(p)).toBe(4)
		p = StationProgress.toggleTeam(p, 5)
		expect(p.titan).toBeNil()
		expect(#StationProgress.fighters(p)).toBe(3)
		-- training takes a Titan out of its slot; sanitize never lets one into the team of three
		p = StationProgress.toggleTeam(p, 4)
		p = StationProgress.train(p, 4, "gym", 0)
		expect(p.titan).toBeNil()
		local q = StationProgress.sanitize({ animals = { { id = 1, s = "elephant" } }, team = { 1 }, titan = 1 }, 0)
		expect(#q.team).toBe(0)
		expect(q.titan).toBe(1)
	end)
end)
