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

-- Seconds of training to take a stat from level 0 to level n.
local function secondsTo(n: number): number
	local total = 0
	for level = 1, n do
		total += StationRules.levelSeconds(level)
	end
	return total
end

-- Buy an egg, hatch it and open it: for tests about other things.
local function get(p: StationProgress.Profile, eggId: string, h: StationRules.Owned): StationProgress.Profile
	p = StationProgress.buy(p, eggId, h)
	p = StationProgress.start(p, #p.eggs, 0)
	return (StationProgress.crack(p, #p.eggs, 1e9))
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
		p = get(p, "meadow", hatched("jackal"))
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
	it("charges the price, gives XP and puts the egg in the egg storage, not hatching", function()
		local p = fresh()
		local ok
		for k, sp in { "jackal", "tortoise", "meerkat", "jackal" } do
			p, ok = StationProgress.buy(p, "meadow", hatched(sp))
			if k <= 3 then
				expect(ok).toBe(true)
			end
		end
		expect(ok).toBe(false) -- 300 coins buy three
		expect(p.coins).toBe(0)
		expect(#p.eggs).toBe(3)
		expect(#p.animals).toBe(0)
		expect(StationProgress.hatching(p)).toBe(0)
		expect(p.eggs[2].egg).toBe("meadow")
		expect(p.eggs[2].since).toBeNil()
		expect(p.eggs[2].animal.s).toBe("tortoise")
		expect(p.xp).toBe(3 * (StationConfig.egg("meadow") :: StationConfig.Egg).xp)
		expect(StationProgress.playerLevel(p)).toBe(2)
	end)

	it("refuses an unknown egg, too few coins and an egg when the storage is full", function()
		local p = fresh()
		local _, ok, code = StationProgress.buy(p, "nope", hatched("jackal"))
		expect(ok).toBe(false)
		expect(code).toBe("egg")
		_, ok, code = StationProgress.buy(p, "safari", hatched("lion"))
		expect(code).toBe("coins")
		p.coins = 1e9
		for _ = 1, StationProgress.MAX_EGGS + StationProgress.MAX_STORED do
			p = StationProgress.buy(p, "meadow", hatched("jackal"))
		end
		expect(#p.eggs).toBe(30)
		_, ok, code = StationProgress.buy(p, "meadow", hatched("jackal"))
		expect(code).toBe("eggs_full")
	end)

	it("starts the egg the player chooses, six at once, and nothing starts by itself", function()
		local p = fresh()
		p.coins = 1e9
		for k = 1, 8 do
			p = StationProgress.buy(p, "meadow", hatched(if k == 7 then "meerkat" else "jackal"))
		end
		local ok, code
		p, ok = StationProgress.start(p, 7, 40) -- the seventh first: the player's choice
		expect(ok).toBe(true)
		expect(p.eggs[7].since).toBe(40)
		expect(p.eggs[1].since).toBeNil()
		_, ok, code = StationProgress.start(p, 7, 50)
		expect(code).toBe("hatching")
		_, ok, code = StationProgress.start(p, 9, 50)
		expect(code).toBe("egg")
		for k = 1, 5 do
			p, ok = StationProgress.start(p, k, 50)
			expect(ok).toBe(true)
		end
		expect(StationProgress.hatching(p)).toBe(6)
		_, ok, code = StationProgress.start(p, 6, 60)
		expect(ok).toBe(false)
		expect(code).toBe("nests_full")
	end)

	it("opens a finished egg only when asked: a new id, into the team while it has room", function()
		local wait = (StationConfig.egg("meadow") :: StationConfig.Egg).hatch
		local p = fresh()
		p.coins = 1e9
		for k, sp in { "jackal", "tortoise", "meerkat", "jackal" } do
			p = StationProgress.buy(p, "meadow", hatched(sp))
			p = StationProgress.start(p, k, k * 10)
		end
		local ok, code, born
		_, ok, code = StationProgress.crack(p, 2, 20 + wait - 1)
		expect(ok).toBe(false)
		expect(code).toBe("not_ready")
		expect(StationProgress.due(p.eggs[2], 20 + wait - 1)).toBe(false)
		expect(StationProgress.due(p.eggs[2], 20 + wait)).toBe(true)
		expect(#p.animals).toBe(0) -- time alone opens nothing
		p, ok, code, born = StationProgress.crack(p, 2, 20 + wait) -- the second egg, the player's choice
		expect(ok).toBe(true)
		expect((born :: StationProgress.Animal).id).toBe(1)
		expect((born :: StationProgress.Animal).s).toBe("tortoise")
		expect(#p.eggs).toBe(3)
		expect(p.eggs[2].animal.s).toBe("meerkat")
		_, ok, code = StationProgress.crack(p, 9, 1e9)
		expect(code).toBe("egg")
		for _ = 1, 3 do
			p = StationProgress.crack(p, 1, 1e9)
		end
		expect(#p.animals).toBe(4)
		expect(#p.eggs).toBe(0)
		expect(#p.team).toBe(3) -- the fourth rests
		-- an egg still in the storage cannot be opened, however long it waits
		p = StationProgress.buy(p, "meadow", hatched("jackal"))
		_, ok, code = StationProgress.crack(p, 1, 1e12)
		expect(code).toBe("not_ready")
	end)

	it("keeps a finished egg in its nest while the Barn is full, and opens it when there is room", function()
		local p = fresh()
		p.coins = 1e9
		for _ = 1, 10 do
			p = get(p, "meadow", hatched("jackal"))
		end
		p = StationProgress.buy(p, "meadow", hatched("meerkat"))
		p = StationProgress.start(p, 1, 0)
		local _, ok, code = StationProgress.crack(p, 1, 1e9)
		expect(ok).toBe(false)
		expect(code).toBe("full")
		expect(#p.eggs).toBe(1)
		p = StationProgress.upgrade(p, "barn", 0)
		local born
		p, ok, code, born = StationProgress.crack(p, 1, 1e9)
		expect(ok).toBe(true)
		expect((born :: StationProgress.Animal).s).toBe("meerkat")
		expect(#p.animals).toBe(11)
	end)

	it("keeps eggs through sanitize, drops broken ones, and hides their animals from the client", function()
		local p = fresh()
		p.coins = 1e9
		p = StationProgress.buy(p, "wild", hatched("cheetah"))
		p = StationProgress.buy(p, "wild", hatched("rhino"))
		p = StationProgress.start(p, 1, 50)
		local again = StationProgress.sanitize(p, 0)
		expect(#again.eggs).toBe(2)
		expect(again.eggs[1].egg).toBe("wild")
		expect(again.eggs[1].since).toBe(50)
		expect(again.eggs[1].animal.s).toBe("cheetah")
		expect(again.eggs[2].since).toBeNil()
		local eggs = {}
		for _ = 1, 9 do
			table.insert(eggs, { egg = "meadow", since = 5, animal = { s = "jackal" } })
		end
		table.insert(eggs, 1, { egg = "moon", since = 5, animal = { s = "jackal" } })
		table.insert(eggs, 2, { egg = "meadow", since = 5, animal = { s = "dragon" } })
		table.insert(eggs, 3, "junk")
		local q = StationProgress.sanitize({ eggs = eggs }, 0)
		expect(#q.eggs).toBe(9) -- the nine good ones: no more than six hatching, the rest back in storage
		expect(StationProgress.hatching(q)).toBe(StationProgress.MAX_EGGS)
		expect(q.eggs[7].since).toBeNil()
		expect(q.eggs[1].animal.stats.speed).toBe(
			(StationRules.versionStats("jackal", nil) :: StationConfig.Stats).speed
		)
		local seen = StationProgress.public(p)
		expect(seen.eggs[1].egg).toBe("wild")
		expect(seen.eggs[1].since).toBe(50)
		expect(seen.eggs[1].animal).toBeNil()
		expect(seen.eggs[2].animal).toBeNil()
		expect(p.eggs[1].animal.s).toBe("cheetah") -- the profile itself is untouched
		expect(seen.coins).toBe(p.coins)
	end)

	it("keeps the Golden Egg locked until player level 15, whatever the coins", function()
		local p = fresh()
		p.coins = 1e9
		p.xp = StationProgress.xpFor(15) - 1
		local ok, code = StationProgress.canBuy(p, "golden")
		expect(ok).toBe(false)
		expect(code).toBe("locked")
		local _, bought = StationProgress.buy(p, "golden", hatched("elephant"))
		expect(bought).toBe(false)
		expect(#p.animals).toBe(0)
		expect(p.coins).toBe(1e9)
		p.xp = StationProgress.xpFor(15)
		expect((StationProgress.canBuy(p, "golden"))).toBe(true)
		p, bought = StationProgress.buy(p, "golden", hatched("elephant"))
		expect(bought).toBe(true)
		expect(p.coins).toBe(1e9 - (StationConfig.egg("golden") :: StationConfig.Egg).price)
		p = StationProgress.start(p, 1, 0)
		p = StationProgress.crack(p, 1, 1e9)
		expect(p.titan).toBe(1) -- the Titan takes its slot when the egg opens
	end)

	it("works with a real seeded hatch", function()
		local a = StationRules.hatch("meadow", Rng.seed(3)) :: StationRules.Owned
		local p, ok = StationProgress.buy(fresh(), "meadow", a)
		expect(ok).toBe(true)
		p = StationProgress.start(p, 1, 0)
		p = StationProgress.crack(p, 1, 1e9)
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
			p = get(p, "meadow", hatched(sp))
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
		p = get(p, "meadow", hatched("jackal"))
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
		expect(StationRules.level(animal(p, 1) :: any, "speed")).toBe(1) -- level 1 takes 120 s
	end)

	it("keeps training in real time while the player is away, and pays XP for every stat level gained", function()
		local p = StationProgress.train(three(), 2, "gym", 0)
		local before = p.xp
		local away = 3 * 24 * 3600 -- three days
		p = StationProgress.snapshot(p, away)
		local level = StationRules.level(animal(p, 2) :: any, "strength")
		expect(level).toBe(StationRules.level(StationRules.train(hatched("tortoise"), "gym", away), "strength"))
		expect(level > 40 and level < StationConfig.MAX_LEVEL).toBeTruthy()
		expect(p.xp).toBe(before + level * StationConfig.XP_STAT_LEVEL)
		-- no level gained, no XP
		p = StationProgress.snapshot(p, away + 60)
		expect(p.xp).toBe(before + level * StationConfig.XP_STAT_LEVEL)
	end)

	it("lets two animals train at once on a new ranch and refuses an unknown station", function()
		local p = three()
		local ok, code
		for id = 1, 3 do
			p, ok, code = StationProgress.train(p, id, "pool", 0)
		end
		expect(ok).toBe(false)
		expect(code).toBe("train_full")
		-- moving one that is already training is not a third
		p, ok = StationProgress.train(p, 1, "guard", 60)
		expect(ok).toBe(true)
		expect(animal(p, 1).at).toBe("guard")
		_, ok, code = StationProgress.train(p, 1, "moon", 0)
		expect(code).toBe("station")
	end)

	it("finishes training at level 70: the animal is freed and that stat cannot be trained again", function()
		local p = StationProgress.train(three(), 1, "track", 0)
		p = StationProgress.snapshot(p, secondsTo(StationConfig.MAX_LEVEL) - 1)
		expect(animal(p, 1).at).toBe("track") -- one second short of level 70
		p = StationProgress.snapshot(p, secondsTo(StationConfig.MAX_LEVEL))
		local a = animal(p, 1)
		expect(StationRules.level(a :: any, "speed")).toBe(StationConfig.MAX_LEVEL)
		expect(a.at).toBeNil()
		expect(a.since).toBeNil()
		local now = secondsTo(StationConfig.MAX_LEVEL) + 60
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
		p = get(p, "golden", hatched("elephant")) -- id 4
		expect(p.titan).toBe(4)
		expect(#p.team).toBe(3)
		local fighters = StationProgress.fighters(p)
		expect(#fighters).toBe(4)
		expect(fighters[4].id).toBe(4) -- the Titan fights last in the line
		p = get(p, "golden", hatched("elephant")) -- id 5: the slot is taken
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

describe("StationProgress ranch upgrades", function()
	local function rich(): StationProgress.Profile
		local p = fresh()
		p.coins, p.samples = 1e9, 1e6
		return p
	end

	it("starts a ranch with 2 training places, room for 10 animals and normal training speed", function()
		local p = fresh()
		expect(StationProgress.value(p, "house")).toBe(2)
		expect(StationProgress.value(p, "barn")).toBe(10)
		expect(StationProgress.value(p, "grounds")).toBe(100)
		expect(p.samples).toBe(0)
	end)

	it("makes every level of every upgrade cost more and give more than the one before", function()
		for _, u in StationConfig.UPGRADES do
			local coins, samples, value = 0, 0, u.base
			for _, level in u.levels do
				expect(level.coins > coins).toBeTruthy()
				expect(level.samples >= samples).toBeTruthy()
				expect(level.value > value).toBeTruthy()
				coins, samples, value = level.coins, level.samples, level.value
			end
			expect(u.levels[#u.levels].samples > 0).toBeTruthy() -- the top needs samples
		end
	end)

	it("charges coins and samples for the next level and gives its value", function()
		local p = rich()
		local ok
		for level, cost in (StationConfig.upgrade("barn") :: StationConfig.Upgrade).levels do
			local coins, samples = p.coins, p.samples
			p, ok = StationProgress.upgrade(p, "barn", 0)
			expect(ok).toBe(true)
			expect(p.upgrades.barn).toBe(level)
			expect(p.coins).toBe(coins - cost.coins)
			expect(p.samples).toBe(samples - cost.samples)
			expect(StationProgress.value(p, "barn")).toBe(cost.value)
		end
	end)

	it("refuses an unknown upgrade, too few coins, too few samples and a finished upgrade", function()
		local p = fresh()
		local _, ok, code = StationProgress.upgrade(p, "moon", 0)
		expect(ok).toBe(false)
		expect(code).toBe("upgrade")
		_, ok, code = StationProgress.upgrade(p, "barn", 0) -- 300 coins, needs 500
		expect(code).toBe("coins")
		expect(p.upgrades.barn).toBeNil()
		p.coins = 1e9
		p = StationProgress.upgrade(p, "barn", 0)
		p = StationProgress.upgrade(p, "barn", 0)
		local coins = p.coins
		_, ok, code = StationProgress.upgrade(p, "barn", 0) -- level 3 needs samples
		expect(code).toBe("samples")
		expect(p.coins).toBe(coins)
		p.samples = 1e6
		for _ = 3, 5 do
			p = StationProgress.upgrade(p, "barn", 0)
		end
		_, ok, code = StationProgress.upgrade(p, "barn", 0)
		expect(code).toBe("top")
	end)

	it("lets a bigger Barn hold more animals and a bigger Ranch House train more at once", function()
		local p = rich()
		for _ = 1, 10 do
			p = get(p, "meadow", hatched("jackal"))
		end
		expect(#p.animals).toBe(10)
		p = get(p, "meadow", hatched("jackal")) -- bought, but the Barn is full: it waits in the hatchery
		expect(#p.animals).toBe(10)
		p = StationProgress.upgrade(p, "barn", 0)
		p = StationProgress.start(p, 1, 0)
		p = StationProgress.crack(p, 1, 1e9)
		expect(#p.animals).toBe(11)
		local ok, code
		for id = 1, 3 do
			p, ok, code = StationProgress.train(p, id, "gym", 0)
		end
		expect(code).toBe("train_full")
		p = StationProgress.upgrade(p, "house", 0)
		p, ok = StationProgress.train(p, 3, "gym", 0)
		expect(ok).toBe(true)
	end)

	it("trains faster with better Training Grounds, and counts time before the upgrade at the old speed", function()
		local p = rich()
		p = get(p, "meadow", hatched("jackal"))
		p = StationProgress.train(p, 1, "track", 0)
		p = StationProgress.upgrade(p, "grounds", 1000) -- 1,000 seconds at 100%
		expect(StationProgress.value(p, "grounds")).toBe(115)
		p = StationProgress.settle(p, 2000) -- then 1,000 seconds at 115%
		local same = StationRules.train(hatched("jackal"), "track", 1000 + 1150)
		local trained = animal(p, 1).trained :: StationConfig.Stats
		expect(math.abs(trained.speed - (same.trained :: StationConfig.Stats).speed) < 1e-9).toBeTruthy()
		expect(StationProgress.trainingSeconds(p, 200)).toBe(230)
		expect(StationProgress.trainingSeconds(p, -5)).toBe(0)
	end)

	it(
		"keeps upgrades and samples through sanitize, clamps junk, and never drops animals over the Barn's room",
		function()
			local animals = {}
			for id = 1, 14 do
				table.insert(animals, { id = id, s = "jackal" })
			end
			local p = StationProgress.sanitize(
				{ samples = 12.7, upgrades = { barn = 99, house = "x", grounds = 2 }, animals = animals },
				0
			)
			expect(p.samples).toBe(12)
			expect(p.upgrades.barn).toBe(5)
			expect(p.upgrades.house).toBe(0)
			expect(p.upgrades.grounds).toBe(2)
			local q = StationProgress.sanitize({ animals = animals, upgrades = 7, samples = -3 }, 0)
			expect(#q.animals).toBe(14) -- over a new barn's 10: kept, only buying more is refused
			expect(q.samples).toBe(0)
			expect(q.upgrades.barn).toBe(0)
		end
	)

	it("keeps only as many animals training as the Ranch House has places when a save is read", function()
		local animals = {}
		for id = 1, 5 do
			table.insert(animals, { id = id, s = "jackal", at = "gym", since = 0 })
		end
		local function training(p: StationProgress.Profile): number
			local n = 0
			for _, a in p.animals do
				n += if a.at then 1 else 0
			end
			return n
		end
		expect(training(StationProgress.sanitize({ animals = animals }, 0))).toBe(2)
		expect(training(StationProgress.sanitize({ animals = animals, upgrades = { house = 2 } }, 0))).toBe(4)
	end)
end)

describe("StationProgress wave fights", function()
	local function withTeam(): StationProgress.Profile
		local p = fresh()
		return get(p, "meadow", hatched("jackal"))
	end

	it("opens waves one at a time up to one past the best, and needs an animal on the team", function()
		local p = fresh()
		local ok, code = StationProgress.canFight(p, 1)
		expect(ok).toBe(false)
		expect(code).toBe("no_team")
		p = withTeam()
		expect(StationProgress.canFight(p, 1)).toBe(true)
		local _, why = StationProgress.canFight(p, 2)
		expect(why).toBe("wave")
		p.best = 4
		expect(StationProgress.canFight(p, 5)).toBe(true)
		expect(StationProgress.canFight(p, 3)).toBe(true) -- a replay
		local _, bad = StationProgress.canFight(p, 6)
		expect(bad).toBe("wave")
		local _, zero = StationProgress.canFight(p, 0)
		expect(zero).toBe("wave")
		local _, half = StationProgress.canFight(p, 2.5)
		expect(half).toBe("wave")
	end)

	it("pays coins, XP and samples for a first clear, records the best and pays a quarter for a replay", function()
		local p = withTeam()
		p.best = 9
		local coins, xp, samples = p.coins, p.xp, p.samples
		local q, ok = StationProgress.clear(p, 10)
		expect(ok).toBe(true)
		expect(q.best).toBe(10)
		expect(q.coins > coins).toBeTruthy()
		expect(q.xp > xp).toBeTruthy()
		expect(q.samples).toBe(samples + 4) -- a boss wave drops double
		local before = q.coins
		q = StationProgress.clear(q, 10)
		expect(q.best).toBe(10)
		expect(q.coins - before < before - coins).toBeTruthy() -- the replay pays less
	end)

	it("refuses to pay for a wave that is not open", function()
		local p = withTeam()
		local q, ok, code = StationProgress.clear(p, 5)
		expect(ok).toBe(false)
		expect(code).toBe("wave")
		expect(q.best).toBe(0)
	end)
end)
