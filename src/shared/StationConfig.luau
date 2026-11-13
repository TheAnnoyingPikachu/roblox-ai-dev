--!strict
-- Game 7 "Animal Stations" data (decisions 0019 to 0029): stats and stat levels, roles, groups,
-- the small African beta pool with its variants, the Titan, eggs, training stations and matchups.
-- Every non-Titan species has a basic version (common to rare) and three super-rare variants
-- (epic, legendary, mythic). Looks for art: docs/game-design/game7-animals.md.
-- Draft values; balance comes later. Pure data, no Roblox APIs.

local StationConfig = {}

export type Stat = "speed" | "strength" | "stamina" | "mana" | "health" | "defence"
export type Stats = {
	speed: number,
	strength: number,
	stamina: number,
	mana: number,
	health: number,
	defence: number,
}
export type Variant = { id: string, name: string, tier: string, twist: Stat }
export type Species = {
	id: string,
	name: string,
	role: string, -- "attack" | "defense" | "utility" | "titan"
	group: string, -- "pack" | "solitary"
	rarity: string,
	stats: Stats,
	variants: { Variant },
}
export type Tier = { tier: string, ppm: number, mult: number, twist: number }
export type Odds = { id: string, bp: number } -- bp: basis points, an egg's odds sum to 10000
-- unlock: the player level needed to buy it (nil = from the start); xp: player XP per hatch
export type Egg = { id: string, name: string, price: number, xp: number, unlock: number?, odds: { Odds } }
export type Station = { id: string, name: string, stat: Stat }

-- Health is HP in battle, Defence cuts incoming damage, Mana fills the power-attack meter
-- (decisions 0028, 0029).
StationConfig.STATS = { "speed", "strength", "stamina", "mana", "health", "defence" } :: { Stat }
StationConfig.STAT_MIN, StationConfig.STAT_MAX = 1, 400 -- limits of a hatched (untrained) stat
-- A hatched animal's stats are its version's stats x (100 +/- VARIANCE)%, so two cheetahs differ a little.
StationConfig.VARIANCE = 10

-- Stat levels (decision 0029): training raises a stat's level, 0 to MAX_LEVEL. A stat's value is
-- its hatched value x (1 + LEVEL_GROWTH x level / MAX_LEVEL), so a maxed stat is doubled.
-- Level n takes LEVEL_SECONDS x n seconds on the station (level 1 half a minute, level 70 35 minutes).
StationConfig.MAX_LEVEL = 70
StationConfig.LEVEL_GROWTH = 1
StationConfig.LEVEL_SECONDS = 30

StationConfig.BASIC_RARITIES = { "common", "uncommon", "rare" }
StationConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

-- Roles (decision 0027). The three team roles form a rock paper scissors loop; the Titan stands
-- outside it (neutral to everyone) and fills the team's fourth slot. BattleRules gives each its job.
StationConfig.ROLES = { "attack", "defense", "utility" }
StationConfig.TITAN = "titan"
-- Attack breaks through Utility, Utility's magic gets past Defense, Defense blocks Attack.
StationConfig.BEATS = { attack = "utility", utility = "defense", defense = "attack" } :: { [string]: string }
StationConfig.ADVANTAGE = 1.25 -- damage x this with the advantage, / this against it (slight, not decisive)

-- Groups (decision 0029): a pack animal gains PACK_PCT % attack and HP for each other pack
-- animal on its team; a solitary animal gains SOLITARY_PCT % when no teammate shares its role.
StationConfig.GROUPS = { "pack", "solitary" }
StationConfig.PACK_PCT = 10
StationConfig.SOLITARY_PCT = 25

-- Variant chance on every hatch, from any egg, in parts per million (shown as "1 in N").
-- A variant's stats are the basic stats x mult, plus `twist` on its twist stat.
StationConfig.TIERS = {
	{ tier = "mythic", ppm = 50, mult = 3.0, twist = 60 }, -- 1 in 20,000
	{ tier = "legendary", ppm = 500, mult = 2.0, twist = 40 }, -- 1 in 2,000
	{ tier = "epic", ppm = 5000, mult = 1.5, twist = 25 }, -- 1 in 200
} :: { Tier }

local function v(id: string, name: string, tier: string, twist: Stat): Variant
	return { id = id, name = name, tier = tier, twist = twist }
end

-- speed, strength, stamina, mana, health, defence
local function s(speed: number, strength: number, stamina: number, mana: number, health: number, defence: number): Stats
	return {
		speed = speed,
		strength = strength,
		stamina = stamina,
		mana = mana,
		health = health,
		defence = defence,
	}
end

-- Small African beta pool: one common and one uncommon per role, a rare lion, and the Titan.
-- Pack: jackal (dog), lion (cat), meerkat, flamingo (bird), elephant. Solitary: tortoise, cheetah, rhino.
-- Variants in order epic, legendary, mythic. The Titan is legendary only and has no variants.
StationConfig.SPECIES = {
	{
		id = "jackal",
		name = "Jackal",
		role = "attack",
		group = "pack",
		rarity = "common",
		stats = s(42, 22, 15, 18, 30, 10),
		variants = {
			v("dune_jackal", "Dune Jackal", "epic", "stamina"),
			v("golden_jackal", "Golden Jackal", "legendary", "strength"),
			v("pharaoh_jackal", "Pharaoh Jackal", "mythic", "mana"),
		},
	},
	{
		id = "tortoise",
		name = "Tortoise",
		role = "defense",
		group = "solitary",
		rarity = "common",
		stats = s(5, 25, 48, 20, 55, 50),
		variants = {
			v("moss_tortoise", "Mossback Tortoise", "epic", "mana"),
			v("gem_tortoise", "Gemshell Tortoise", "legendary", "defence"),
			v("island_tortoise", "Island Tortoise", "mythic", "health"),
		},
	},
	{
		id = "meerkat",
		name = "Meerkat",
		role = "utility",
		group = "pack",
		rarity = "common",
		stats = s(30, 8, 15, 42, 25, 8),
		variants = {
			v("scout_meerkat", "Scout Meerkat", "epic", "speed"),
			v("sandmage_meerkat", "Sandmage Meerkat", "legendary", "mana"),
			v("mirage_meerkat", "Mirage Meerkat", "mythic", "speed"),
		},
	},
	{
		id = "cheetah",
		name = "Cheetah",
		role = "attack",
		group = "solitary",
		rarity = "uncommon",
		stats = s(70, 35, 20, 20, 45, 15),
		variants = {
			v("shadow_cheetah", "Shadow Cheetah", "epic", "mana"),
			v("golden_cheetah", "Golden Cheetah", "legendary", "strength"),
			v("lightning_cheetah", "Lightning Cheetah", "mythic", "speed"),
		},
	},
	{
		id = "rhino",
		name = "Rhino",
		role = "defense",
		group = "solitary",
		rarity = "uncommon",
		stats = s(25, 60, 65, 10, 75, 60),
		variants = {
			v("stone_rhino", "Stone Rhino", "epic", "defence"),
			v("crystal_rhino", "Crystal Rhino", "legendary", "mana"),
			v("thunder_rhino", "Thunder Rhino", "mythic", "speed"),
		},
	},
	{
		id = "flamingo",
		name = "Flamingo",
		role = "utility",
		group = "pack",
		rarity = "uncommon",
		stats = s(30, 10, 30, 65, 50, 15),
		variants = {
			v("sunset_flamingo", "Sunset Flamingo", "epic", "stamina"),
			v("pearl_flamingo", "Pearl Flamingo", "legendary", "mana"),
			v("phoenix_flamingo", "Phoenix Flamingo", "mythic", "strength"),
		},
	},
	{
		id = "lion",
		name = "Lion",
		role = "attack",
		group = "pack",
		rarity = "rare",
		stats = s(55, 90, 40, 25, 70, 30),
		variants = {
			v("white_lion", "White Lion", "epic", "health"),
			v("sun_lion", "Sun Lion", "legendary", "mana"),
			v("star_lion", "Constellation Lion", "mythic", "strength"),
		},
	},
	{
		id = "elephant",
		name = "Elephant",
		role = "titan",
		group = "pack",
		rarity = "legendary",
		stats = s(30, 160, 180, 60, 200, 120),
		variants = {},
	},
} :: { Species }

-- Eggs roll a species (basic odds); the variant roll (TIERS) happens on top, the same for every egg.
-- The Titan only comes from the Legendary Egg, which unlocks at player level 15.
StationConfig.EGGS = {
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 100,
		xp = 10,
		odds = {
			{ id = "jackal", bp = 3400 },
			{ id = "tortoise", bp = 3300 },
			{ id = "meerkat", bp = 3300 },
		},
	},
	{
		id = "wild",
		name = "Wild Egg",
		price = 1500,
		xp = 40,
		odds = {
			{ id = "jackal", bp = 1800 },
			{ id = "tortoise", bp = 1800 },
			{ id = "meerkat", bp = 1800 },
			{ id = "cheetah", bp = 1600 },
			{ id = "rhino", bp = 1500 },
			{ id = "flamingo", bp = 1500 },
		},
	},
	{
		id = "safari",
		name = "Safari Egg",
		price = 15000,
		xp = 150,
		odds = {
			{ id = "cheetah", bp = 2700 },
			{ id = "rhino", bp = 2700 },
			{ id = "flamingo", bp = 2600 },
			{ id = "lion", bp = 2000 },
		},
	},
	{
		id = "legendary",
		name = "Legendary Egg",
		price = 50000,
		xp = 500,
		unlock = 15,
		odds = {
			{ id = "elephant", bp = 10000 },
		},
	},
} :: { Egg }

-- Training stations (decision 0023): an animal left on a station slowly levels that station's stat.
StationConfig.STATIONS = {
	{ id = "track", name = "Speed Track", stat = "speed" },
	{ id = "gym", name = "Strength Gym", stat = "strength" },
	{ id = "pool", name = "Swim Pool", stat = "stamina" },
	{ id = "library", name = "Magic Library", stat = "mana" },
	{ id = "spring", name = "Healing Spring", stat = "health" },
	{ id = "guard", name = "Guard Yard", stat = "defence" },
} :: { Station }

local function find<T>(list: { T }, id: string): T?
	for _, x in list do
		if (x :: any).id == id then
			return x
		end
	end
	return nil
end

function StationConfig.species(id: string): Species?
	return find(StationConfig.SPECIES, id)
end

-- The variant `variantId` of `speciesId`, or nil when either is unknown or they don't match.
function StationConfig.variant(speciesId: string, variantId: string): Variant?
	local species = StationConfig.species(speciesId)
	return if species then find(species.variants, variantId) else nil
end

function StationConfig.tier(tier: string): Tier?
	for _, t in StationConfig.TIERS do
		if t.tier == tier then
			return t
		end
	end
	return nil
end

function StationConfig.egg(id: string): Egg?
	return find(StationConfig.EGGS, id)
end

function StationConfig.station(id: string): Station?
	return find(StationConfig.STATIONS, id)
end

return StationConfig
