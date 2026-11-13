--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local BattleRules = require("../src/shared/BattleRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

-- A made-up animal of species `id` with the given numbers (40 where not given).
local function custom(id: string, over: { [string]: number }?): StationRules.Owned
	local st = { speed = 40, strength = 40, stamina = 40, mana = 40, health = 40, defence = 40 } :: any
	for k, x in over or {} do
		st[k] = x
	end
	return { s = id, stats = st :: StationConfig.Stats }
end

local function three(id: string): { StationRules.Owned }
	return { owned(id), owned(id), owned(id) }
end

describe("BattleRules.fighter", function()
	it("takes the role and group from the species", function()
		expect(BattleRules.fighter(owned("lion"), 1, 1).role).toBe("attack")
		expect(BattleRules.fighter(owned("rhino"), 1, 1).role).toBe("defense")
		expect(BattleRules.fighter(owned("meerkat"), 1, 1).role).toBe("utility")
		expect(BattleRules.fighter(owned("elephant"), 1, 4).role).toBe("titan")
		expect(BattleRules.fighter(owned("lion"), 1, 1).group).toBe("pack")
		expect(BattleRules.fighter(owned("rhino"), 1, 1).group).toBe("solitary")
	end)

	it("gives each stat exactly one job", function()
		-- Speed: attack speed. Stamina: the rest between attacks. Strength: damage. Mana: energy
		-- per attack. Health: HP. Defence: damage reduction.
		local JOB =
			{ speed = "swing", stamina = "rest", strength = "dmg", mana = "gain", health = "maxHp", defence = "def" }
		local BETTER = { swing = -1, rest = -1, dmg = 1, gain = 1, maxHp = 1, def = 1 }
		local base = custom("lion")
		local before = BattleRules.fighter(base, 1, 1) :: any
		for _, st in StationConfig.STATIONS do
			local after = BattleRules.fighter(StationRules.train(base, st.id, 1e12), 1, 1) :: any
			for field, direction in BETTER do
				if field == JOB[st.stat] then
					expect((after[field] - before[field]) * direction > 0).toBeTruthy()
				else
					expect(after[field]).toBe(before[field])
				end
			end
		end
	end)

	it(
		"halves the swing at 100 Speed and the rest at 100 Stamina, and lands the first attack after one swing",
		function()
			local slow = BattleRules.fighter(custom("lion", { speed = 0, stamina = 0 }), 1, 1)
			expect(slow.swing).toBe(BattleRules.SWING)
			expect(slow.rest).toBe(BattleRules.REST)
			expect(slow.next).toBe(slow.swing)
			local quick = BattleRules.fighter(custom("lion", { speed = 100, stamina = 100 }), 1, 1)
			expect(quick.swing).toBe(BattleRules.SWING / 2)
			expect(quick.rest).toBe(BattleRules.REST / 2)
		end
	)

	it("takes HP from Health and damage from Strength, with Attack hitting harder", function()
		local a = BattleRules.fighter(custom("lion"), 1, 1)
		expect(a.maxHp).toBe(BattleRules.HP_BASE + 40 * BattleRules.HP_PER_HEALTH)
		local u = BattleRules.fighter(custom("meerkat"), 1, 1)
		expect(u.dmg).toBe(BattleRules.DMG_BASE + 40 * BattleRules.DMG_PER_STRENGTH)
		expect(a.dmg).toBe(math.floor(u.dmg * BattleRules.ATTACK_BONUS))
		expect(a.maxHp).toBe(u.maxHp)
	end)
end)

describe("BattleRules stats in a wave fight", function()
	-- one attacker against a punch bag that barely fights back: how long it takes to finish it
	local function bag(over: { [string]: number }?): StationRules.Owned
		local st = { speed = 0, strength = 0, stamina = 0, mana = 0, health = 600, defence = 0 }
		for k, x in over or {} do
			st[k] = x
		end
		return custom("lion", st)
	end
	local function hitter(over: { [string]: number }?): StationRules.Owned
		local st = { mana = 0, health = 4000, defence = 0 }
		for k, x in over or {} do
			st[k] = x
		end
		return custom("lion", st)
	end
	local function seconds(h: StationRules.Owned, b: StationRules.Owned): number
		local won, _, took = BattleRules.battle({ h }, { b })
		expect(won).toBe(true)
		return took
	end

	it("ends sooner with more Strength, more Speed, more Stamina or more Mana", function()
		local plain = seconds(hitter(), bag())
		expect(seconds(hitter({ strength = 80 }), bag()) < plain).toBeTruthy()
		expect(seconds(hitter({ speed = 100 }), bag()) < plain).toBeTruthy()
		expect(seconds(hitter({ stamina = 100 }), bag()) < plain).toBeTruthy()
		local some, lots = seconds(hitter({ mana = 40 }), bag()), seconds(hitter({ mana = 90 }), bag())
		expect(some < plain).toBeTruthy()
		expect(lots < some).toBeTruthy()
	end)

	it("lasts longer against more Health or more Defence: 100 Defence about doubles it", function()
		local plain = seconds(hitter(), bag())
		expect(seconds(hitter(), bag({ health = 1200 })) > plain).toBeTruthy()
		local some, lots = seconds(hitter(), bag({ defence = 50 })), seconds(hitter(), bag({ defence = 100 }))
		expect(some > plain).toBeTruthy()
		expect(lots > some).toBeTruthy()
		expect(lots >= plain * 1.8 and lots <= plain * 2.2).toBeTruthy()
	end)

	it("lets the faster of two otherwise equal animals win, from either side", function()
		local fast, slow = custom("lion", { speed = 60 }), custom("lion")
		expect((BattleRules.battle({ fast }, { slow }))).toBe(true)
		expect((BattleRules.battle({ slow }, { fast }))).toBe(false)
	end)
end)

describe("BattleRules.lineup groups", function()
	it("gives a pack animal 10% damage and HP for each other pack animal on the team", function()
		expect(StationConfig.PACK_PCT).toBe(10)
		expect(StationConfig.SOLITARY_PCT).toBe(25)
		local raw = BattleRules.fighter(owned("lion"), 1, 1)
		local alone = BattleRules.lineup({ owned("lion") }, 1)[1]
		expect(alone.dmg).toBe(raw.dmg)
		expect(alone.maxHp).toBe(raw.maxHp)
		local pair = BattleRules.lineup({ owned("lion"), owned("jackal") }, 1)[1]
		expect(pair.dmg).toBe(math.floor(raw.dmg * 110 / 100))
		expect(pair.maxHp).toBe(math.floor(raw.maxHp * 110 / 100))
		-- the full pack with the Titan: three others
		local pack = BattleRules.lineup({ owned("lion"), owned("jackal"), owned("meerkat"), owned("elephant") }, 1)
		expect(pack[1].dmg).toBe(math.floor(raw.dmg * 130 / 100))
		local titan = BattleRules.fighter(owned("elephant"), 1, 4)
		expect(pack[4].maxHp).toBe(math.floor(titan.maxHp * 130 / 100))
		expect(pack[4].hp).toBe(pack[4].maxHp)
		-- solitary teammates do not count as pack
		expect(BattleRules.lineup({ owned("lion"), owned("rhino"), owned("cheetah") }, 1)[1].dmg).toBe(raw.dmg)
	end)

	it("gives a solitary animal 25% when no teammate shares its role", function()
		local raw = BattleRules.fighter(owned("cheetah"), 1, 1)
		local alone = BattleRules.lineup({ owned("cheetah") }, 1)[1]
		expect(alone.dmg).toBe(math.floor(raw.dmg * 125 / 100))
		expect(alone.maxHp).toBe(math.floor(raw.maxHp * 125 / 100))
		-- a different role beside it keeps the bonus, for both
		local two = BattleRules.lineup({ owned("cheetah"), owned("rhino") }, 1)
		expect(two[1].dmg).toBe(alone.dmg)
		expect(two[2].maxHp).toBe(math.floor(BattleRules.fighter(owned("rhino"), 1, 2).maxHp * 125 / 100))
		-- another Attack animal beside it removes the bonus
		expect(BattleRules.lineup({ owned("cheetah"), owned("jackal") }, 1)[1].dmg).toBe(raw.dmg)
		local twins = BattleRules.lineup({ owned("rhino"), owned("tortoise") }, 1)
		expect(twins[1].maxHp).toBe(BattleRules.fighter(owned("rhino"), 1, 1).maxHp)
	end)
end)

describe("BattleRules.battle", function()
	it("loses with no team, and the player's team wins a mirror match on ties", function()
		expect((BattleRules.battle({}, { owned("jackal") }))).toBe(false)
		local team = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		expect((BattleRules.battle(team, { owned("jackal"), owned("tortoise"), owned("meerkat") }))).toBe(true)
	end)

	it("makes enemies hit the Defence animal first, so it shields a fragile teammate", function()
		local glass = custom("jackal", { health = 1, strength = 400, mana = 0, defence = 0 })
		local wall = { health = 100, defence = 200, strength = 0 }
		local enemy = custom("lion", { strength = 100, health = 150 })
		expect((BattleRules.battle({ glass, custom("tortoise", wall) }, { enemy }))).toBe(true)
		-- the same numbers without the Defence role: the fragile one is hit first and the fight is lost
		expect((BattleRules.battle({ glass, custom("lion", wall) }, { enemy }))).toBe(false)
	end)

	it("lets a Utility animal heal, and calls a fight that runs out of time a loss", function()
		local over = { health = 100, strength = 0, speed = 100, stamina = 100, mana = 0, defence = 0 }
		local attacker = custom("lion", { speed = 0, stamina = 0, mana = 0, health = 4000, defence = 0 })
		-- without healing the target falls in half a minute
		local won, _, took = BattleRules.battle({ attacker }, { custom("lion", over) })
		expect(won).toBe(true)
		expect(took < 40).toBeTruthy()
		-- the same numbers on a healer: it heals more than it takes, so time runs out
		won, _, took = BattleRules.battle({ attacker }, { custom("meerkat", over) })
		expect(won).toBe(false)
		expect(took > BattleRules.MAX_SECONDS - 5 and took <= BattleRules.MAX_SECONDS).toBeTruthy()
	end)

	it("lets one of each role beat three of any one animal of the same rarity, from either side", function()
		for _, ids in { { "jackal", "tortoise", "meerkat" }, { "cheetah", "rhino", "flamingo" } } do
			local mixed = {}
			for _, id in ids do
				table.insert(mixed, owned(id))
			end
			for _, id in ids do
				expect((BattleRules.battle(three(id), mixed))).toBe(false)
				expect((BattleRules.battle(mixed, three(id)))).toBe(true)
			end
		end
	end)

	it("lets the Titan in the fourth slot turn a lost fight", function()
		local team = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		local foes = { owned("cheetah"), owned("rhino"), owned("flamingo") }
		expect((BattleRules.battle(team, foes))).toBe(false)
		table.insert(team, owned("elephant"))
		expect((BattleRules.battle(team, foes))).toBe(true)
	end)

	it("always ends: healers against healers, and absurd stats stop at the attack limit", function()
		local won, _, took = BattleRules.battle({ custom("meerkat") }, { custom("meerkat") })
		expect(won).toBe(true)
		expect(took < BattleRules.MAX_SECONDS).toBeTruthy()
		local endless = { speed = 1e300, stamina = 1e300, health = 1e12 }
		local lost, actions = BattleRules.battle({ custom("tortoise", endless) }, { custom("tortoise", endless) })
		expect(lost).toBe(false)
		expect(actions).toBe(BattleRules.MAX_ACTIONS)
	end)
end)
