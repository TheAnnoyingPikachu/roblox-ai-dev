--!strict
local T = require("./framework")
local LevelRules = require("../src/shared/LevelRules")
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

describe("StationProgress income while away (decision 0124)", function()
	it("pays the Windmill its level's coins, or its share of the next wave's pay when that is more", function()
		local p = fresh()
		p.upgrades.windmill = 1
		expect(StationProgress.millRate(p)).toBe(60) -- wave 1 pays 40: 2% of it is less than 60
		p.best = 149
		local pay = LevelRules.reward(150, 0)
		expect(StationProgress.millRate(p)).toBe(pay * 2 // 100)
		p.upgrades.windmill = 5
		expect(StationProgress.millRate(p)).toBe(pay * 10 // 100)
		p.mill = 0
		expect(StationProgress.held(p, 100 * 3600)).toBe(StationProgress.millRate(p) * StationProgress.MILL_HOURS)
	end)

	it("pays every ranch animal off the team and not training, by rarity, held up to HERD_HOURS", function()
		local p = fresh()
		for _ = 1, 5 do
			p = StationProgress.give(p, "jackal", nil, 1)
		end
		-- the first three joined the team: only two earn, each its floor at wave 1
		expect(#p.team).toBe(3)
		local floor = StationConfig.HERD_FLOOR[StationRules.rarity(p.animals[4] :: any)]
		expect(StationProgress.herdRate(p)).toBe(2 * floor)
		p = StationProgress.train(p, p.animals[4].id, "gym", 0)
		expect(StationProgress.herdRate(p)).toBe(floor) -- a training animal earns nothing
		p.herd = 0
		expect(StationProgress.herdHeld(p, 3600)).toBe(floor)
		expect(StationProgress.herdHeld(p, 100 * 3600)).toBe(floor * StationProgress.HERD_HOURS)
		local coins = p.coins
		local _, ok, _, got = StationProgress.collectHerd(p, 100 * 3600)
		expect(ok).toBe(true)
		expect(p.coins).toBe(coins + got)
		expect(p.herd).toBe(100 * 3600)
		local _, again, code = StationProgress.collectHerd(p, 100 * 3600)
		expect(again).toBe(false)
		expect(code).toBe("herd_empty")
	end)

	it("keeps the herd's clock in the save and never ahead of now", function()
		local p = fresh()
		p.herd = 500
		expect(StationProgress.sanitize(p, 1000).herd).toBe(500)
		p.herd = 5000
		expect(StationProgress.sanitize(p, 1000).herd).toBe(1000)
		expect(StationProgress.sanitize({}, 1000).herd).toBe(1000) -- an old save starts earning now
	end)
end)

describe("StationProgress away (decision 0121)", function()
	it("says what trained, hatched and filled while away, and changes nothing", function()
		local p = fresh()
		p = StationProgress.give(p, "lion", nil, 1)
		local lion = p.animals[1]
		p = StationProgress.train(p, lion.id, "gym", 0)
		local hour = 3600
		local away = StationProgress.away(p, 24 * hour)
		expect(#away.trained).toBe(1)
		expect(away.trained[1].stat).toBe("strength")
		expect(away.trained[1].to > away.trained[1].from).toBeTruthy()
		expect(p.animals[1].since).toBe(0) -- the save itself is not settled
		expect(away.eggs).toBe(0)
		expect(away.mill).toBe(0)
		local none = StationProgress.away(fresh(), 10)
		expect(#none.trained + none.eggs + none.mill).toBe(0)
	end)
end)

describe("StationProgress sound (decision 0122)", function()
	it("starts at full volume, keeps whole steps from 0 to SOUND_STEPS, and survives a save", function()
		local steps = StationProgress.SOUND_STEPS
		local p = fresh()
		expect(p.sound.music).toBe(steps)
		expect(p.sound.mute).toBe(false)
		StationProgress.setSound(p, 3.7, 99, true)
		expect(p.sound.music).toBe(3)
		expect(p.sound.effects).toBe(steps)
		expect(p.sound.mute).toBe(true)
		local back = StationProgress.sanitize(p, 0)
		expect(back.sound.music).toBe(3)
		expect(back.sound.mute).toBe(true)
		local junk = StationProgress.sanitize({ sound = { music = "loud", effects = -4, mute = "yes" } }, 0)
		expect(junk.sound.music).toBe(steps)
		expect(junk.sound.effects).toBe(0)
		expect(junk.sound.mute).toBe(false)
	end)
end)

-- Everything a save names that an older server's sanitize would drop. When this list changes,
-- StationProgress.VERSION must go up, so an older server never loads and strips a newer save (decision 0111).
-- Raise VERSION, then set CONTENT to the printed list's length and checksum.
local CONTENT = { version = 5, count = 68, sum = 3348052 } -- 5: star levels (decision 0123)
local function contentIds(): { string }
	local ids = {}
	for _, sp in StationConfig.SPECIES do
		table.insert(ids, "s:" .. sp.id)
		for _, v in sp.variants do
			table.insert(ids, "v:" .. v.id)
		end
	end
	for _, e in StationConfig.EGGS do
		table.insert(ids, "e:" .. e.id)
	end
	for _, c in StationConfig.COATS do
		table.insert(ids, "c:" .. c.id)
	end
	for _, u in StationConfig.UPGRADES do
		table.insert(ids, "u:" .. u.id)
	end
	for _, st in StationConfig.STATIONS do
		table.insert(ids, "t:" .. st.id)
	end
	table.sort(ids)
	return ids
end

describe("StationProgress content version (decision 0121)", function()
	it("raises VERSION whenever a species, variant, egg, coat, upgrade or station is added or renamed", function()
		local ids = contentIds()
		local sum = 0
		for k, id in ids do
			for i = 1, #id do
				sum = (sum + string.byte(id, i) * (k + i)) % 1e9
			end
		end
		if #ids ~= CONTENT.count or sum ~= CONTENT.sum then
			print(`content changed: count = {#ids}, sum = {sum}; raise StationProgress.VERSION and update CONTENT`)
		end
		expect(StationProgress.VERSION).toBe(CONTENT.version)
		expect(#ids).toBe(CONTENT.count)
		expect(sum).toBe(CONTENT.sum)
	end)
end)

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
					trained = { speed = 999, strength = "x" },
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
		_, ok, code = StationProgress.buy(p, "wild", hatched("rhino"))
		expect(code).toBe("coins")
		p.coins = 1e9
		for _ = 1, 3 + 8 do -- a new ranch: three nests and room for eight in the storage
			p = StationProgress.buy(p, "meadow", hatched("jackal"))
		end
		expect(#p.eggs).toBe(11)
		_, ok, code = StationProgress.buy(p, "meadow", hatched("jackal"))
		expect(code).toBe("eggs_full")
	end)

	it(
		"opens the Meadow and Wild Eggs from the start and unlocks the others with the waves: Safari at 10, Golden at 20",
		function()
			local p = fresh()
			p.coins = 1e9
			p.best = 300 -- the waves no longer open an egg: player level does (SHANNON, 2026-11-24)
			expect((StationProgress.canBuy(p, "meadow"))).toBe(true)
			expect((StationProgress.canBuy(p, "wild"))).toBe(true)
			p.xp = StationProgress.xpFor(4)
			local _, ok, code = StationProgress.buy(p, "safari", hatched("lion"))
			expect(ok).toBe(false)
			expect(code).toBe("locked")
			p.xp = StationProgress.xpFor(5)
			_, ok = StationProgress.buy(p, "safari", hatched("lion"))
			expect(ok).toBe(true)
			_, ok, code = StationProgress.buy(p, "golden", hatched("lion"))
			expect(code).toBe("locked")
			p.xp = StationProgress.xpFor(8)
			_, ok = StationProgress.buy(p, "golden", hatched("lion"))
			expect(ok).toBe(true)
		end
	)

	it("starts the egg the player chooses, six at once with six nests, and nothing starts by itself", function()
		local p = fresh()
		p.coins = 1e9
		p.upgrades.hatchery = 3 -- six nests
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
		p.upgrades.hatchery = 1 -- four nests
		for k, sp in { "jackal", "tortoise", "meerkat", "jackal" } do
			p = StationProgress.buy(p, "meadow", hatched(sp))
			p = StationProgress.start(p, k, k * 10)
		end
		local ok, code, born
		_, ok, code = StationProgress.crack(p, 2, 20 + wait - 1)
		expect(ok).toBe(false)
		expect(code).toBe("not_ready")
		expect(StationProgress.due(p, p.eggs[2], 20 + wait - 1)).toBe(false)
		expect(StationProgress.due(p, p.eggs[2], 20 + wait)).toBe(true)
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
		expect(#p.team).toBe(3)
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

	it("keeps a rainbow coat from the egg to the animal and through a save, and only a true one", function()
		local p = fresh()
		p.coins = 1e9
		local coated = hatched("jackal")
		coated.rainbow = true
		p = StationProgress.buy(p, "meadow", coated)
		expect(StationProgress.sanitize(p, 0).eggs[1].animal.rainbow).toBe(true) -- inside a stored egg
		expect(StationProgress.public(p).eggs[1].animal).toBeNil() -- and never shown before it hatches
		p = StationProgress.start(p, 1, 0)
		local born
		p, _, _, born = StationProgress.crack(p, 1, 1e9)
		expect((born :: StationProgress.Animal).rainbow).toBe(true)
		p = get(p, "meadow", hatched("tortoise"))
		local again = StationProgress.sanitize(p, 0)
		expect(again.animals[1].rainbow).toBe(true)
		expect(again.animals[2].rainbow).toBeNil()
		-- training and the team leave it on
		again = StationProgress.train(again, again.animals[1].id, StationConfig.STATIONS[1].id, 0)
		again = StationProgress.settle(again, 5000)
		expect(again.animals[1].rainbow).toBe(true)
		local junk = StationProgress.sanitize({
			animals = { { id = 1, s = "jackal", rainbow = "yes" }, { id = 2, s = "jackal", rainbow = false } },
		}, 0)
		expect(junk.animals[1].rainbow).toBeNil()
		expect(junk.animals[2].rainbow).toBeNil()
		-- the admin's menu can add one
		p, _, _, born = StationProgress.give(p, "lion", "sun_lion", 3, true)
		expect((born :: StationProgress.Animal).rainbow).toBe(true)
		p, _, _, born = StationProgress.give(p, "lion", nil, 3, false)
		expect((born :: StationProgress.Animal).rainbow).toBeNil()
	end)

	it("gives an admin's animal at a chosen level, past the Barn, and refuses junk", function()
		local p = fresh()
		p.coins = 1e9
		for _ = 1, 10 do
			p = get(p, "meadow", hatched("jackal"))
		end
		local ok, code, born
		p, ok, code, born = StationProgress.give(p, "lion", nil, 5)
		expect(ok).toBe(true) -- the Barn holds 10 and is full
		expect(#p.animals).toBe(11)
		local a = born :: StationProgress.Animal
		expect(a.s).toBe("lion")
		expect(StationRules.level(a, "speed")).toBe(5)
		expect(a.id).toBe(p.nextId - 1)
		expect(StationProgress.sanitize(p, 0).animals[11].s).toBe("lion")
		for _, bad in
			{
				{ "dodo", nil, 1 },
				{ "lion", "x_y", 1 },
				{ "lion", nil, 0 },
				{ "lion", nil, StationConfig.MAX_LEVEL + 1 },
			}
		do
			_, ok, code = StationProgress.give(p, bad[1] :: string, bad[2] :: string?, bad[3] :: number)
			expect(ok).toBe(false)
			expect(code).toBe("animal")
		end
		p.animals = table.create(StationProgress.MAX_ANIMALS, p.animals[1])
		_, ok, code = StationProgress.give(p, "lion", nil, 1)
		expect(code).toBe("full")
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
		for _ = 1, 13 do
			table.insert(eggs, { egg = "meadow", since = 5, animal = { s = "jackal" } })
		end
		table.insert(eggs, 1, { egg = "moon", since = 5, animal = { s = "jackal" } })
		table.insert(eggs, 2, { egg = "meadow", since = 5, animal = { s = "dragon" } })
		table.insert(eggs, 3, "junk")
		local q = StationProgress.sanitize({ eggs = eggs }, 0)
		expect(#q.eggs).toBe(13) -- the good ones: no more hatching than a save can hold, the rest back in storage
		expect(StationProgress.hatching(q)).toBe(StationProgress.MAX_EGGS)
		expect(q.eggs[11].since).toBeNil()
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

	it("keeps the Golden Egg locked until player level 8, whatever the coins", function()
		local p = fresh()
		p.coins = 1e9
		p.xp = StationProgress.xpFor(8) - 1
		local ok, code = StationProgress.canBuy(p, "golden")
		expect(ok).toBe(false)
		expect(code).toBe("locked")
		local _, bought = StationProgress.buy(p, "golden", hatched("elephant"))
		expect(bought).toBe(false)
		expect(#p.animals).toBe(0)
		expect(p.coins).toBe(1e9)
		p.xp = StationProgress.xpFor(8)
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
		expect(StationRules.stat(a :: any, "speed")).toBe(57) -- 42 x 6762 / 4900 = 57.96 (decision 0123)
		expect(a.at).toBeNil()
		local _, stopped, why = StationProgress.stop(p, 1, 5000)
		expect(stopped).toBe(false)
		expect(why).toBe("idle")
	end)

	it("puts an animal back in the team slot it left when its training stops, if that place is free", function()
		local p = three()
		local first = p.team[1]
		p = StationProgress.train(p, first, "track", 0)
		expect(table.find(p.team, first)).toBeNil()
		p = StationProgress.sanitize(StationProgress.snapshot(p, 10), 10) -- the slot survives a save
		p = StationProgress.stop(p, first, 20)
		expect(p.team[1]).toBe(first)
		-- a full team keeps the stopped animal out
		p = StationProgress.train(p, first, "track", 30)
		p.coins = 1000
		p = get(p, "meadow", hatched("jackal")) -- a hatch joins a team with room
		expect(#p.team).toBe(StationProgress.TEAM_SIZE)
		p = StationProgress.stop(p, first, 40)
		expect(table.find(p.team, first)).toBeNil()
		expect(#p.team).toBe(StationProgress.TEAM_SIZE)
	end)

	it("releases an idle animal for coins by rarity, never one in the team, training, locked or the last", function()
		local p = three()
		p.coins = 1000
		p = get(p, "meadow", hatched("jackal")) -- the fourth waits outside a full team
		local spare = p.animals[#p.animals].id
		local _, ok, code = StationProgress.release(p, p.team[1])
		expect(code).toBe("in_team")
		local coins = p.coins
		p, ok = StationProgress.release(p, spare)
		expect(ok).toBe(true)
		expect(#p.animals).toBe(3)
		expect(p.coins).toBe(coins + StationProgress.RELEASE_PAY.common)
	end)

	it("fuses four of one animal and coat tier into one of the next tier, levels averaged", function()
		local p = fresh()
		p.coins = 1e6
		for _ = 1, 3 do -- three for the team, then four more outside it
			p = get(p, "meadow", hatched("meerkat"))
		end
		local ids = {}
		for k = 1, 4 do
			p = get(p, "meadow", hatched("jackal"))
			local a = p.animals[#p.animals]
			ids[k] = a.id
			local copy = table.clone(a)
			copy.trained = { speed = k * 4, stamina = 0, strength = 0, mana = 0, health = 0, defence = 0 } :: any
			p.animals[#p.animals] = copy
		end
		local _, a = StationProgress.find(p, ids[1])
		expect(#StationProgress.fusable(p, a :: StationProgress.Animal)).toBe(4)
		local _, ok, code = StationProgress.fuse(p, ids, "rainbow")
		expect(code).toBe("coat") -- a plain animal fuses into the commonest coats, not Rainbow
		local coat = StationProgress.COAT_TIERS[1][1]
		local before = #p.animals
		p, ok = StationProgress.fuse(p, ids, coat)
		expect(ok).toBe(true)
		expect(#p.animals).toBe(before - 3)
		local _, fused = StationProgress.find(p, ids[1])
		expect((fused :: StationProgress.Animal).coat).toBe(coat)
		expect(StationRules.level(fused :: any, "speed")).toBe(10) -- (4 + 8 + 12 + 16) / 4
		expect(StationProgress.coatTier(fused :: StationProgress.Animal)).toBe(1)
		local _, _, why = StationProgress.fuse(p, { ids[1], ids[1], ids[1], ids[1] }, coat)
		expect(why).toBe("animal")
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
		for id, station in { "pool", "track", "gym" } do
			p, ok, code = StationProgress.train(p, id, station, 0)
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

	it("keeps only the first of two animals a stored save has training at one station", function()
		local p = StationProgress.train(three(), 1, "track", 0)
		p = StationProgress.train(p, 2, "gym", 0)
		p.animals[2].at = "track" -- as a save from before the rule could hold
		local clean = StationProgress.sanitize(p, 100)
		expect(animal(clean, 1).at).toBe("track")
		expect(animal(clean, 2).at).toBeNil()
		expect(animal(clean, 2).since).toBeNil()
	end)

	it("trains one animal at a time at a station, and frees it when that one stops or moves", function()
		local p, ok, code = StationProgress.train(three(), 1, "track", 0)
		expect(ok).toBe(true)
		p, ok, code = StationProgress.train(p, 2, "track", 10)
		expect(ok).toBe(false)
		expect(code).toBe("station_busy")
		expect(animal(p, 2).at).toBeNil()
		p, ok = StationProgress.train(p, 1, "track", 20) -- the one that is there may start again
		expect(ok).toBe(true)
		p, ok = StationProgress.train(p, 2, "gym", 20)
		expect(ok).toBe(true)
		p, ok, code = StationProgress.train(p, 2, "track", 30) -- nor may another move in
		expect(ok).toBe(false)
		expect(code).toBe("station_busy")
		expect(animal(p, 2).at).toBe("gym")
		p = StationProgress.stop(p, 1, 40)
		p, ok = StationProgress.train(p, 2, "track", 50)
		expect(ok).toBe(true)
		p, ok = StationProgress.train(p, 3, "gym", 60) -- and the one it left is free
		expect(ok).toBe(true)
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
		p.xp = StationProgress.xpFor(8) -- the Golden Egg is unlocked
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

	it("starts a ranch with three nests, room for eight stored eggs, and no brooder, windmill, lodge or den", function()
		local p = fresh()
		expect(StationProgress.value(p, "hatchery")).toBe(3)
		expect(StationProgress.value(p, "cellar")).toBe(8)
		expect(StationProgress.value(p, "brooder")).toBe(100)
		expect(StationProgress.value(p, "windmill")).toBe(0)
		expect(StationProgress.value(p, "lodge")).toBe(100)
		expect(StationProgress.value(p, "den")).toBe(100)
		-- the most a save can hold is what the top levels give
		local function top(id: string): number
			local u = StationConfig.upgrade(id) :: StationConfig.Upgrade
			return u.levels[#u.levels].value
		end
		expect(top("hatchery")).toBe(StationProgress.MAX_EGGS)
		expect(top("cellar")).toBe(StationProgress.MAX_STORED)
	end)

	it("lets the Hatchery and the Egg Cellar say how many eggs hatch and wait, and never cuts a save down", function()
		local p = rich()
		for k = 1, 11 do
			p = StationProgress.buy(p, "meadow", hatched("jackal"))
			if k <= 3 then
				p = StationProgress.start(p, k, 0)
			end
		end
		local _, ok, code = StationProgress.start(p, 4, 0)
		expect(code).toBe("nests_full")
		_, ok, code = StationProgress.buy(p, "meadow", hatched("jackal"))
		expect(code).toBe("eggs_full")
		p = StationProgress.upgrade(p, "hatchery", 0) -- a fourth nest
		p, ok = StationProgress.start(p, 4, 0)
		expect(ok).toBe(true)
		p, ok = StationProgress.buy(p, "meadow", hatched("jackal")) -- and so room for one more egg
		expect(ok).toBe(true)
		p = StationProgress.upgrade(p, "cellar", 0) -- twelve stored
		for _ = 1, 4 do
			p, ok = StationProgress.buy(p, "meadow", hatched("jackal"))
			expect(ok).toBe(true)
		end
		expect(#p.eggs).toBe(16)
		-- a save from before the upgrades, with six hatching and twenty stored, keeps them all
		local old = { eggs = {} }
		for k = 1, 26 do
			table.insert(old.eggs, { egg = "meadow", since = if k <= 6 then 5 else nil, animal = { s = "jackal" } })
		end
		local q = StationProgress.sanitize(old, 0)
		expect(#q.eggs).toBe(26)
		expect(StationProgress.hatching(q)).toBe(6)
	end)

	it("hatches faster with the Brooder, rounded up to whole seconds", function()
		local egg = StationConfig.egg("wild") :: StationConfig.Egg
		local p = rich()
		expect(StationProgress.hatchSeconds(p, egg)).toBe(egg.hatch)
		p = StationProgress.buy(p, "wild", hatched("rhino"))
		p = StationProgress.start(p, 1, 100)
		p = StationProgress.upgrade(p, "brooder", 100) -- 115%
		local quick = math.ceil(egg.hatch * 100 / 115)
		expect(StationProgress.hatchSeconds(p, egg)).toBe(quick)
		expect(StationProgress.due(p, p.eggs[1], 100 + quick - 1)).toBe(false)
		expect(StationProgress.due(p, p.eggs[1], 100 + quick)).toBe(true) -- an egg already hatching is faster too
		for _ = 2, 5 do
			p = StationProgress.upgrade(p, "brooder", 100)
		end
		expect(StationProgress.hatchSeconds(p, egg)).toBe(egg.hatch / 2) -- 200%
	end)

	it(
		"fills the Windmill by the hour, also while away, to eight hours' worth, and pays only when collected",
		function()
			local p = rich()
			local ok, code, got
			p, ok, code = StationProgress.collect(p, 5000)
			expect(ok).toBe(false)
			expect(code).toBe("no_mill")
			expect(p.mill).toBeNil()
			p = StationProgress.upgrade(p, "windmill", 1000) -- 60 coins an hour, from now
			expect(p.mill).toBe(1000)
			local coins = p.coins
			expect(StationProgress.held(p, 1000 + 59)).toBe(0) -- a coin takes a minute
			_, ok, code = StationProgress.collect(p, 1000 + 59)
			expect(code).toBe("mill_empty")
			expect(StationProgress.held(p, 1000 + 150)).toBe(2)
			p = StationProgress.settle(p, 1000 + 150)
			expect(p.coins).toBe(coins) -- nothing is paid until it is collected
			p, ok, code, got = StationProgress.collect(p, 1000 + 150)
			expect(ok).toBe(true)
			expect(got).toBe(2)
			expect(p.coins).toBe(coins + 2)
			expect(p.mill).toBe(1120) -- the half minute left over keeps counting
			local month = 1120 + 30 * 24 * 3600
			expect(StationProgress.held(p, month)).toBe(60 * StationProgress.MILL_HOURS) -- a month away: it is full
			p, ok, code, got = StationProgress.collect(p, month)
			expect(got).toBe(480)
			expect(p.mill).toBe(month)
			-- buying a level empties it first, at the rate it was earned at
			local before = p.coins
			p = StationProgress.upgrade(p, "windmill", month + 3600) -- it holds 60; the second level costs 10,000
			expect(p.coins).toBe(before + 60 - 10000)
			expect(p.mill).toBe(month + 3600)
			expect(StationProgress.held(p, month + 3600)).toBe(0)
			expect(StationProgress.held(p, month + 7200)).toBe(150) -- an hour at the new rate
			-- the clock is kept through sanitize, but never ahead of now
			expect(StationProgress.sanitize(p, month + 7200).mill).toBe(month + 3600)
			expect(StationProgress.sanitize(p, month).mill).toBe(month)
		end
	)

	it("pays more coins for a wave with the Trophy Lodge, and nothing else more", function()
		local p = rich()
		p.best = 30
		local coins, xp, samples = StationProgress.payout(p, 31)
		p = StationProgress.upgrade(p, "lodge", 0) -- 110%
		local more, sameXp, sameSamples = StationProgress.payout(p, 31)
		expect(more).toBe(coins * 110 // 100)
		expect(sameXp).toBe(xp)
		expect(sameSamples).toBe(samples)
	end)

	it("gives the Titan its Den's share of every stat in a wave, and no other animal", function()
		local p = rich()
		local ok
		p, ok = StationProgress.give(p, "lion", nil, 10)
		p, ok = StationProgress.give(p, "elephant", nil, 10)
		expect(ok).toBe(true)
		local plain = StationProgress.fighters(p)
		expect(#plain).toBe(2)
		expect((plain[2] :: any).boost).toBeNil()
		p = StationProgress.upgrade(p, "den", 0) -- 104%
		local team = StationProgress.fighters(p)
		expect((team[1] :: any).boost).toBeNil()
		expect((team[2] :: any).boost).toBe(104)
		for _, stat in StationConfig.STATS do
			local base = StationRules.stat(plain[2] :: any, stat)
			expect(StationRules.stat(team[2] :: any, stat)).toBe(base * 104 // 100)
			expect(StationRules.stat(team[1] :: any, stat)).toBe(StationRules.stat(plain[1] :: any, stat))
		end
		local _, stored = StationProgress.find(p, p.titan :: number)
		expect((stored :: any).boost).toBeNil() -- the saved animal is untouched
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
		for id, station in { "gym", "track", "pool" } do
			p, ok, code = StationProgress.train(p, id, station, 0)
		end
		expect(code).toBe("train_full")
		p = StationProgress.upgrade(p, "house", 0)
		p, ok = StationProgress.train(p, 3, "pool", 0)
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
		for id = 1, 5 do -- each at a station of its own: a station trains one
			table.insert(animals, { id = id, s = "jackal", at = StationConfig.STATIONS[id].id, since = 0 })
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

	it(
		"pays 25% more XP for each Gilded animal on the team, up to three, and keeps coats in the save (decision 0110)",
		function()
			local p = withTeam()
			local _, plain = StationProgress.payout(p, 5)
			p.animals[1].coat = "gilded"
			local _, more = StationProgress.payout(p, 5)
			expect(more).toBe(plain * 125 // 100)
			local q = StationProgress.sanitize(p, 0)
			expect(q.animals[1].coat).toBe("gilded")
			q.animals[1].coat = "nonsense"
			expect(StationProgress.sanitize(q, 0).animals[1].coat).toBeNil()
			q.animals[1].coat, q.animals[1].rainbow = nil, true -- a save from before coats
			local old = StationProgress.sanitize(q, 0).animals[1]
			expect(old.coat).toBe("rainbow")
			expect(old.rainbow).toBe(true)
		end
	)

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
		p.best = LevelRules.LAST - 1
		expect(StationProgress.canFight(p, LevelRules.LAST)).toBe(true)
		p.best = LevelRules.LAST
		expect(StationProgress.canFight(p, LevelRules.LAST)).toBe(true) -- a replay of the last wave
		local _, over = StationProgress.canFight(p, LevelRules.LAST + 1)
		expect(over).toBe("wave") -- there is no wave after the last (decision 0107)
	end)

	it("pays a player carried to a wave past their own best, and makes it their best (decision 0108)", function()
		local p = withTeam()
		p.best = 4
		local _, alone, why = StationProgress.clear(p, 30)
		expect(alone).toBe(false)
		expect(why).toBe("wave")
		local coins = StationProgress.payout(p, 30)
		local before = p.coins
		local q, ok = StationProgress.clear(p, 30, true)
		expect(ok).toBe(true)
		expect(q.best).toBe(30)
		expect(q.coins).toBe(before + coins)
		local _, past = StationProgress.clear(q, LevelRules.LAST + 1, true)
		expect(past).toBe(false) -- never past the last wave
		local _, none, code = StationProgress.clear(fresh(), 3, true)
		expect(none).toBe(false) -- never without a team
		expect(code).toBe("no_team")
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

describe("StationProgress Robux and the beta (decision 0117)", function()
	it("grants a purchase once per receipt, at BASE_MAX in its coat, the Titan to its slot", function()
		local p = fresh()
		local q, ok, code, a = StationProgress.grant(p, "lion", "sahara_lion", "r1", "rainbow")
		expect(ok).toBe(true)
		expect(code).toBeNil()
		local got = a :: StationProgress.Animal
		expect(got.v).toBe("sahara_lion")
		expect(got.coat).toBe("rainbow")
		expect(got.rainbow).toBe(true)
		expect(got.trained.strength).toBe(StationConfig.BASE_MAX)
		expect(#q.animals).toBe(1)
		expect(q.team[1]).toBe(got.id)
		local again, ok2, code2, a2 = StationProgress.grant(q, "lion", "sahara_lion", "r1", "rainbow")
		expect(ok2).toBe(true) -- Roblox sent the receipt again: nothing more is given
		expect(code2).toBe("granted")
		expect(a2).toBeNil()
		expect(#again.animals).toBe(1)
		local t = StationProgress.grant(again, "elephant", "sahara_elephant", "r2", nil)
		expect(#t.animals).toBe(2)
		expect(t.titan).toBe(t.animals[2].id)
		expect(#t.team).toBe(1) -- a Titan never joins the team
	end)

	it(
		"refuses a purchase when the save is full or the animal unknown, and remembers receipts through a save",
		function()
			local p = fresh()
			for k = 1, StationProgress.MAX_ANIMALS do
				p.animals[k] = {
					id = k,
					s = "lion",
					stats = StationRules.versionStats("lion", nil) :: StationConfig.Stats,
					trained = full(1),
				}
			end
			p.nextId = StationProgress.MAX_ANIMALS + 1
			local _, ok, code = StationProgress.grant(p, "lion", "sahara_lion", "r1", nil)
			expect(ok).toBe(false)
			expect(code).toBe("full")
			local _, ok2, code2 = StationProgress.grant(fresh(), "lion", "nope_lion", "r1", nil)
			expect(ok2).toBe(false)
			expect(code2).toBe("animal")
			local q = StationProgress.grant(fresh(), "lion", "sahara_lion", "r9", "galaxy")
			local back = StationProgress.sanitize(q, 0)
			expect(back.receipts[1]).toBe("r9")
			expect(back.animals[1].v).toBe("sahara_lion") -- an exclusive variant survives a save
			expect(back.animals[1].coat).toBe("galaxy")
			local many = fresh()
			for k = 1, StationProgress.MAX_RECEIPTS + 5 do
				many = StationProgress.grant(many, "lion", "sahara_lion", `x{k}`, nil)
				table.clear(many.animals) -- only the receipts matter here
			end
			expect(#many.receipts).toBe(StationProgress.MAX_RECEIPTS)
			expect(many.receipts[1]).toBe("x6") -- the oldest go
		end
	)

	it("gives the beta reward once per save while it is on", function()
		local q, ok, _, a = StationProgress.betaGift(fresh(), nil)
		local gift = StationConfig.BETA_GIFT :: { s: string, v: string }
		expect(ok).toBe(true)
		expect((a :: StationProgress.Animal).v).toBe(gift.v)
		expect(q.beta).toBe(true)
		local again, ok2, code2 = StationProgress.betaGift(StationProgress.sanitize(q, 0), nil)
		expect(ok2).toBe(false)
		expect(code2).toBe("done")
		expect(#again.animals).toBe(1)
	end)
end)

describe("StationProgress animals met (decision 0118)", function()
	it("meets a version once, only one that exists, and every animal owned", function()
		local p = fresh()
		expect(#p.met).toBe(0)
		p = StationProgress.meet(p, "lion", nil)
		p = StationProgress.meet(p, "lion", nil)
		p = StationProgress.meet(p, "lion", "sun_lion")
		p = StationProgress.meet(p, "dragon", nil) -- a foe, not an animal
		p = StationProgress.meet(p, "lion", "nope")
		expect(#p.met).toBe(2)
		expect(table.find(p.met, "lion/") ~= nil and table.find(p.met, "lion/sun_lion") ~= nil).toBeTruthy()
		local given = StationProgress.give(fresh(), "elephant", nil, 3, false)
		expect(table.find(given.met, "elephant/") ~= nil).toBeTruthy()
	end)

	it("keeps a stored list clean and short, and meets what an older save owns", function()
		local record = fresh() :: any
		record.met = { "lion/", "lion/", "lion/sun_lion", "ghost/", "junk", 42, string.rep("x", 80) }
		record.animals = { { id = 1, s = "rhino", stats = StationRules.versionStats("rhino", nil) } }
		record.nextId = 2
		local p = StationProgress.sanitize(record, 0)
		table.sort(p.met)
		expect(table.concat(p.met, ",")).toBe("lion/,lion/sun_lion,rhino/")
		local all = fresh()
		for _, sp in StationConfig.SPECIES do
			all = StationProgress.meet(all, sp.id, nil)
			for _, va in sp.variants do
				all = StationProgress.meet(all, sp.id, va.id)
			end
		end
		expect(#all.met).toBe(StationProgress.MAX_MET)
		expect(#StationProgress.sanitize(all, 0).met).toBe(StationProgress.MAX_MET)
	end)
end)
