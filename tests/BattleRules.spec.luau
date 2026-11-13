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

-- An animal of `role` with every stat 40 and a light Defence of 10, so only the role differs.
local SPECIES = { attack = "lion", defense = "rhino", utility = "meerkat" }
local function role(r: string): StationRules.Owned
	return custom(SPECIES[r], { defence = 10 })
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

	it("takes HP from Health alone", function()
		local a = custom("lion")
		local base = BattleRules.fighter(a, 1, 1).maxHp
		expect(base).toBe(BattleRules.HP_BASE + 40 * BattleRules.HP_PER_HEALTH)
		local healthy = StationRules.train(a, "spring", 1e9) -- Health doubled
		expect(BattleRules.fighter(healthy, 1, 1).maxHp).toBe(BattleRules.HP_BASE + 80 * BattleRules.HP_PER_HEALTH)
		expect(BattleRules.fighter(StationRules.train(a, "gym", 1e9), 1, 1).maxHp).toBe(base)
	end)

	it("makes Attack hit harder than the same stats in another role", function()
		local atk = BattleRules.fighter(role("attack"), 1, 1)
		local util = BattleRules.fighter(role("utility"), 1, 1)
		expect(atk.atk > util.atk).toBeTruthy()
		expect(atk.maxHp).toBe(util.maxHp)
	end)
end)

describe("BattleRules stats in a fight", function()
	-- one attacker against a huge punch bag that cannot hurt it: count the actions to finish it
	local function actions(hitter: StationRules.Owned, bag: StationRules.Owned): number
		local won, turns = BattleRules.battle({ hitter }, { bag })
		expect(won).toBe(true)
		return turns
	end
	local function bag(defence: number): StationRules.Owned
		return custom("lion", { speed = 1, strength = 1, stamina = 1, mana = 1, health = 2000, defence = defence })
	end
	local function hitter(mana: number): StationRules.Owned
		return custom("lion", { speed = 99, mana = mana, health = 4000, defence = 0 })
	end

	it("makes more Mana mean more frequent power attacks", function()
		local low, mid, high = actions(hitter(0), bag(0)), actions(hitter(40), bag(0)), actions(hitter(90), bag(0))
		expect(mid < low).toBeTruthy()
		expect(high < mid).toBeTruthy()
	end)

	it("makes Defence cut incoming damage: 100 Defence about doubles the hits needed", function()
		local none, some, lots = actions(hitter(0), bag(0)), actions(hitter(0), bag(50)), actions(hitter(0), bag(100))
		expect(some > none).toBeTruthy()
		expect(lots > some).toBeTruthy()
		expect(lots >= none * 1.9 and lots <= none * 2.1).toBeTruthy()
	end)
end)

describe("BattleRules.lineup groups", function()
	local function find(team: { BattleRules.Fighter }, slot: number): BattleRules.Fighter
		return team[slot]
	end

	it("gives a pack animal 10% attack and HP for each other pack animal on the team", function()
		expect(StationConfig.PACK_PCT).toBe(10)
		expect(StationConfig.SOLITARY_PCT).toBe(25)
		local alone = find(BattleRules.lineup({ owned("lion") }, 1), 1)
		local raw = BattleRules.fighter(owned("lion"), 1, 1)
		expect(alone.atk).toBe(raw.atk)
		expect(alone.maxHp).toBe(raw.maxHp)
		local pair = find(BattleRules.lineup({ owned("lion"), owned("jackal") }, 1), 1)
		expect(pair.atk).toBe(math.floor(raw.atk * 110 / 100))
		expect(pair.maxHp).toBe(math.floor(raw.maxHp * 110 / 100))
		-- the full pack with the Titan: three others
		local pack = BattleRules.lineup({ owned("lion"), owned("jackal"), owned("meerkat"), owned("elephant") }, 1)
		expect(find(pack, 1).atk).toBe(math.floor(raw.atk * 130 / 100))
		local titan = BattleRules.fighter(owned("elephant"), 1, 4)
		expect(find(pack, 4).maxHp).toBe(math.floor(titan.maxHp * 130 / 100))
		expect(find(pack, 4).hp).toBe(find(pack, 4).maxHp)
		-- solitary teammates do not count as pack
		local mixed = find(BattleRules.lineup({ owned("lion"), owned("rhino"), owned("cheetah") }, 1), 1)
		expect(mixed.atk).toBe(raw.atk)
	end)

	it("gives a solitary animal 25% when no teammate shares its role", function()
		local raw = BattleRules.fighter(owned("cheetah"), 1, 1)
		local alone = find(BattleRules.lineup({ owned("cheetah") }, 1), 1)
		expect(alone.atk).toBe(math.floor(raw.atk * 125 / 100))
		expect(alone.maxHp).toBe(math.floor(raw.maxHp * 125 / 100))
		-- a different role beside it keeps the bonus, for both
		local two = BattleRules.lineup({ owned("cheetah"), owned("rhino") }, 1)
		expect(find(two, 1).atk).toBe(alone.atk)
		expect(find(two, 2).maxHp).toBe(math.floor(BattleRules.fighter(owned("rhino"), 1, 2).maxHp * 125 / 100))
		-- another Attack animal beside it removes the bonus
		local shared = find(BattleRules.lineup({ owned("cheetah"), owned("jackal") }, 1), 1)
		expect(shared.atk).toBe(raw.atk)
		local twins = BattleRules.lineup({ owned("rhino"), owned("tortoise") }, 1)
		expect(find(twins, 1).maxHp).toBe(BattleRules.fighter(owned("rhino"), 1, 1).maxHp)
	end)
end)

describe("BattleRules.battle", function()
	it("loses with no team, and side 1 wins a mirror match on speed ties", function()
		expect((BattleRules.battle({}, { owned("jackal") }))).toBe(false)
		local team = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		expect((BattleRules.battle(team, { owned("jackal"), owned("tortoise"), owned("meerkat") }))).toBe(true)
	end)

	it("is rock paper scissors between equal animals, from either side", function()
		-- with a light Defence; a very high Defence favours healers, since heals are not cut
		for _, a in StationConfig.ROLES do
			local d = StationConfig.BEATS[a]
			expect((BattleRules.battle({ role(a) }, { role(d) }))).toBe(true)
			expect((BattleRules.battle({ role(d) }, { role(a) }))).toBe(false)
		end
	end)

	it("lets one of each role beat three of any one animal of the same rarity, from either side", function()
		local tiers = {
			{ mixed = { "jackal", "tortoise", "meerkat" } },
			{ mixed = { "cheetah", "rhino", "flamingo" } },
		}
		for _, tier in tiers do
			local mixed = {}
			for _, id in tier.mixed do
				table.insert(mixed, owned(id))
			end
			for _, id in tier.mixed do
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

	it("always ends, even when healers face each other", function()
		local _, turns = BattleRules.battle({ role("utility") }, { role("utility") })
		expect(turns <= BattleRules.MAX_TURNS).toBeTruthy()
		local _, t2 = BattleRules.battle({ owned("meerkat") }, three("flamingo"))
		expect(t2 < BattleRules.MAX_TURNS).toBeTruthy()
	end)
end)
