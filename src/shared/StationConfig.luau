--!strict
-- Game 7 "Animal Stations" data (decisions 0019 to 0036): stats and stat levels, roles, groups,
-- the small African beta pool with its variants, the Titan, eggs and training stations.
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
-- unlock: the player level needed to buy it (nil = from the start); xp: player XP for buying it;
-- hatch: seconds it sits in the ranch's hatchery before it opens (decision 0036, draft numbers)
export type Egg =
	{ id: string, name: string, price: number, xp: number, hatch: number, unlock: number?, odds: { Odds } }
export type Station = { id: string, name: string, stat: Stat }

-- Each stat has one job in a wave fight (decision 0032, BattleRules): Speed is attack speed,
-- Strength damage, Stamina the rest between attacks, Mana the charge towards the power attack,
-- Health HP and Defence cuts incoming damage.
StationConfig.STATS = { "speed", "strength", "stamina", "mana", "health", "defence" } :: { Stat }
StationConfig.STAT_MIN, StationConfig.STAT_MAX = 1, 400 -- limits of a version's (level 0) stat

-- Stat levels (decision 0029): training raises a stat's level, 0 to MAX_LEVEL. A stat's value is
-- its species value x (1 + LEVEL_GROWTH x level / MAX_LEVEL), so a maxed stat is doubled.
StationConfig.MAX_LEVEL = 70
StationConfig.LEVEL_GROWTH = 1
-- Training time (decision 0032): every level takes a little longer than the one before. Level 1
-- takes LEVEL_FIRST seconds; the time grows steadily to one day at LEVEL_DAY and on to LEVEL_LAST
-- at MAX_LEVEL, so each level above 60 takes about 24 to 48 hours of real time (about 23 days
-- for one stat from 0 to 70). Training enhancements will shorten this later.
StationConfig.LEVEL_FIRST = 120
StationConfig.LEVEL_DAY = 61
StationConfig.LEVEL_LAST = 48 * 3600
-- Base stats (decisions 0030, 0032): on hatch every stat starts at a level from 1 to BASE_MAX,
-- each higher number a little less likely. A BASE_MAX has weight BASE_TOP and every level below
-- it BASE_STEP more, out of 630: a 15 is 7 in 630 = 1 in 90, a 1 is 77 in 630 (about 1 in 8).
-- JACKPOT_PPM is the chance that one stat hatches at MAX_LEVEL instead.
StationConfig.BASE_MAX = 15
StationConfig.BASE_TOP, StationConfig.BASE_STEP = 7, 5
StationConfig.JACKPOT_PPM = 100 -- 1 in 10,000 hatches
-- Player XP comes from everything the player does (decision 0032). Built so far: hatching (each
-- egg's `xp`) and every stat level a creature gains in training. Waves, the login tracks and
-- gear will add theirs when they exist.
StationConfig.XP_STAT_LEVEL = 5

StationConfig.BASIC_RARITIES = { "common", "uncommon", "rare" }
StationConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

-- Roles (decision 0027): three team roles, each with its own job in a wave fight (BattleRules),
-- and the Titan, which fills the team's fourth slot.
StationConfig.ROLES = { "attack", "defense", "utility" }
StationConfig.TITAN = "titan"

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
		stats = s(25, 50, 60, 10, 70, 55),
		variants = {
			v("stone_rhino", "Stone Rhino", "epic", "defence"),
			v("crystal_rhino", "Crystal Rhino", "legendary", "mana"),
			v("lava_rhino", "Lava Rhino", "mythic", "strength"),
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
-- There is no legendary-only egg: the Titan (the one legendary species) is a rare hatch from the
-- Golden Egg, which unlocks at player level 15 and drops other animals too (decision 0031).
-- Placeholder eggs: an egg overhaul is planned.
StationConfig.EGGS = {
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 100,
		xp = 10,
		hatch = 60,
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
		hatch = 600,
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
		hatch = 3600,
		odds = {
			{ id = "cheetah", bp = 2700 },
			{ id = "rhino", bp = 2700 },
			{ id = "flamingo", bp = 2600 },
			{ id = "lion", bp = 2000 },
		},
	},
	{
		id = "golden",
		name = "Golden Egg",
		price = 50000,
		xp = 500,
		hatch = 14400,
		unlock = 15,
		odds = {
			{ id = "lion", bp = 5000 },
			{ id = "cheetah", bp = 1500 },
			{ id = "rhino", bp = 1500 },
			{ id = "flamingo", bp = 1500 },
			{ id = "elephant", bp = 500 },
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

-- Ranch upgrades (decision 0034): the ranch is a tycoon. Each upgrade is bought one level at a
-- time with coins and, higher up, samples (dropped by harder waves; not earnable until waves are
-- built). `base` is what a new ranch has, `value` what that level gives. Every level also changes
-- how the ranch looks (src/stations/Ranch.luau). Draft numbers: meant to be slow to afford.
export type UpgradeLevel = { coins: number, samples: number, value: number }
export type Upgrade = { id: string, name: string, gives: string, base: number, levels: { UpgradeLevel } }
StationConfig.UPGRADES = {
	{
		id = "house",
		name = "Ranch House",
		gives = "animals training at once",
		base = 2,
		levels = {
			{ coins = 1000, samples = 0, value = 3 },
			{ coins = 8000, samples = 0, value = 4 },
			{ coins = 60000, samples = 15, value = 5 },
			{ coins = 400000, samples = 60, value = 6 },
		},
	},
	{
		id = "barn",
		name = "Barn",
		gives = "animals you can keep",
		base = 10,
		levels = {
			{ coins = 500, samples = 0, value = 20 },
			{ coins = 3000, samples = 0, value = 30 },
			{ coins = 15000, samples = 10, value = 45 },
			{ coins = 75000, samples = 40, value = 60 },
			{ coins = 400000, samples = 150, value = 80 },
		},
	},
	{
		id = "grounds",
		name = "Training Grounds",
		gives = "% training speed",
		base = 100,
		levels = {
			{ coins = 750, samples = 0, value = 115 },
			{ coins = 4000, samples = 0, value = 130 },
			{ coins = 20000, samples = 10, value = 150 },
			{ coins = 100000, samples = 40, value = 175 },
			{ coins = 500000, samples = 150, value = 200 },
		},
	},
} :: { Upgrade }

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

function StationConfig.upgrade(id: string): Upgrade?
	return find(StationConfig.UPGRADES, id)
end

return StationConfig
