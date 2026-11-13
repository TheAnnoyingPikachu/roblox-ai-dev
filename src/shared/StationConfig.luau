--!strict
-- Game 7 "Animal Stations" data (decisions 0019 to 0028): stats, roles, the African beta pool of
-- species with their variants, Titans, eggs, training stations and battle matchups.
-- Every non-Titan species has a basic version (common to rare) and three super-rare variants
-- (epic, legendary, mythic). Looks for art: docs/game-design/game7-animals.md.
-- Draft values; balance comes later. Pure data, no Roblox APIs.

local StationConfig = {}

export type Stat = "speed" | "strength" | "stamina" | "mana" | "health"
export type Stats = { speed: number, strength: number, stamina: number, mana: number, health: number }
export type Variant = { id: string, name: string, tier: string, twist: Stat }
export type Species = {
	id: string,
	name: string,
	role: string, -- "attack" | "defense" | "utility" | "titan"
	rarity: string,
	stats: Stats,
	variants: { Variant },
}
export type Tier = { tier: string, ppm: number, mult: number, twist: number }
export type Odds = { id: string, bp: number } -- bp: basis points, an egg's odds sum to 10000
export type Egg = { id: string, name: string, price: number, odds: { Odds } }
export type Station = { id: string, name: string, stat: Stat }

-- Health is HP in battle; Mana fills the power-attack meter (decision 0028).
StationConfig.STATS = { "speed", "strength", "stamina", "mana", "health" } :: { Stat }
StationConfig.STAT_MIN, StationConfig.STAT_MAX = 1, 400
-- A hatched animal's stats are its version's stats x (100 +/- VARIANCE)%, so two cheetahs differ a little.
StationConfig.VARIANCE = 10

StationConfig.BASIC_RARITIES = { "common", "uncommon", "rare" }
StationConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

-- Roles (decision 0027). The three team roles form a rock paper scissors loop; Titans stand
-- outside it (neutral to everyone) and fill the team's fourth slot. BattleRules gives each its job.
StationConfig.ROLES = { "attack", "defense", "utility" }
StationConfig.TITAN = "titan"
-- Attack breaks through Utility, Utility's magic gets past Defense, Defense blocks Attack.
StationConfig.BEATS = { attack = "utility", utility = "defense", defense = "attack" } :: { [string]: string }
StationConfig.ADVANTAGE = 1.25 -- damage x this with the advantage, / this against it (slight, not decisive)

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

local function s(speed: number, strength: number, stamina: number, mana: number, health: number): Stats
	return { speed = speed, strength = strength, stamina = stamina, mana = mana, health = health }
end

local function sp(id: string, name: string, role: string, rarity: string, stats: Stats, variants: { Variant }): Species
	return { id = id, name = name, role = role, rarity = rarity, stats = stats, variants = variants }
end

-- African beta pool. Four species per role (two common, one uncommon, one rare), variants in order
-- epic, legendary, mythic. Then the Titans: legendary, no variants, far bigger stats.
StationConfig.SPECIES = {
	-- attack: fast and strong
	sp("hyena", "Hyena", "attack", "common", s(30, 40, 20, 12, 38), {
		v("ember_hyena", "Ember Hyena", "epic", "strength"),
		v("bone_hyena", "Bonechief Hyena", "legendary", "stamina"),
		v("eclipse_hyena", "Eclipse Hyena", "mythic", "mana"),
	}),
	sp("jackal", "Jackal", "attack", "common", s(42, 22, 15, 18, 30), {
		v("dune_jackal", "Dune Jackal", "epic", "stamina"),
		v("golden_jackal", "Golden Jackal", "legendary", "strength"),
		v("pharaoh_jackal", "Pharaoh Jackal", "mythic", "mana"),
	}),
	sp("cheetah", "Cheetah", "attack", "uncommon", s(70, 35, 20, 20, 45), {
		v("shadow_cheetah", "Shadow Cheetah", "epic", "mana"),
		v("golden_cheetah", "Golden Cheetah", "legendary", "strength"),
		v("lightning_cheetah", "Lightning Cheetah", "mythic", "speed"),
	}),
	sp("lion", "Lion", "attack", "rare", s(55, 90, 40, 25, 70), {
		v("white_lion", "White Lion", "epic", "stamina"),
		v("sun_lion", "Sun Lion", "legendary", "mana"),
		v("star_lion", "Constellation Lion", "mythic", "strength"),
	}),
	-- defense: high stamina
	sp("warthog", "Warthog", "defense", "common", s(22, 35, 40, 8, 45), {
		v("mud_warthog", "Mudslinger Warthog", "epic", "strength"),
		v("iron_warthog", "Ironhide Warthog", "legendary", "stamina"),
		v("magma_warthog", "Magma Warthog", "mythic", "strength"),
	}),
	sp("tortoise", "Tortoise", "defense", "common", s(5, 25, 48, 20, 55), {
		v("moss_tortoise", "Mossback Tortoise", "epic", "mana"),
		v("gem_tortoise", "Gemshell Tortoise", "legendary", "stamina"),
		v("island_tortoise", "Island Tortoise", "mythic", "mana"),
	}),
	sp("rhino", "Rhino", "defense", "uncommon", s(25, 60, 65, 10, 75), {
		v("stone_rhino", "Stone Rhino", "epic", "stamina"),
		v("crystal_rhino", "Crystal Rhino", "legendary", "mana"),
		v("thunder_rhino", "Thunder Rhino", "mythic", "speed"),
	}),
	sp("gorilla", "Gorilla", "defense", "rare", s(25, 80, 90, 40, 95), {
		v("silverback", "Silverback", "epic", "mana"),
		v("lava_gorilla", "Lava Gorilla", "legendary", "strength"),
		v("galaxy_gorilla", "Galaxy Gorilla", "mythic", "mana"),
	}),
	-- utility: high mana
	sp("meerkat", "Meerkat", "utility", "common", s(30, 8, 15, 42, 25), {
		v("scout_meerkat", "Scout Meerkat", "epic", "speed"),
		v("sandmage_meerkat", "Sandmage Meerkat", "legendary", "mana"),
		v("mirage_meerkat", "Mirage Meerkat", "mythic", "speed"),
	}),
	sp("flamingo", "Flamingo", "utility", "common", s(20, 8, 22, 45, 28), {
		v("sunset_flamingo", "Sunset Flamingo", "epic", "stamina"),
		v("pearl_flamingo", "Pearl Flamingo", "legendary", "mana"),
		v("phoenix_flamingo", "Phoenix Flamingo", "mythic", "strength"),
	}),
	sp("giraffe", "Giraffe", "utility", "uncommon", s(30, 25, 35, 65, 50), {
		v("painted_giraffe", "Painted Giraffe", "epic", "speed"),
		v("cloud_giraffe", "Cloudtop Giraffe", "legendary", "stamina"),
		v("star_giraffe", "Stargazer Giraffe", "mythic", "mana"),
	}),
	sp("mandrill", "Mandrill", "utility", "rare", s(35, 30, 40, 90, 60), {
		v("masked_mandrill", "Masked Mandrill", "epic", "strength"),
		v("storm_mandrill", "Stormcaller Mandrill", "legendary", "speed"),
		v("spirit_mandrill", "Spirit Mandrill", "mythic", "mana"),
	}),
	-- titans
	sp("elephant", "Elephant", "titan", "legendary", s(30, 160, 180, 60, 200), {}),
	sp("hippo", "Hippo", "titan", "legendary", s(35, 180, 150, 40, 190), {}),
	sp("crocodile", "Crocodile", "titan", "legendary", s(50, 170, 130, 50, 160), {}),
} :: { Species }

-- Eggs roll a species (basic odds); the variant roll (TIERS) happens on top, the same for every egg.
-- Titans: a 4% chance from the Safari Egg (draft; how Titans are earned is not settled).
StationConfig.EGGS = {
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 100,
		odds = {
			{ id = "hyena", bp = 1700 },
			{ id = "jackal", bp = 1700 },
			{ id = "warthog", bp = 1700 },
			{ id = "tortoise", bp = 1600 },
			{ id = "meerkat", bp = 1700 },
			{ id = "flamingo", bp = 1600 },
		},
	},
	{
		id = "wild",
		name = "Wild Egg",
		price = 1500,
		odds = {
			{ id = "hyena", bp = 900 },
			{ id = "jackal", bp = 900 },
			{ id = "warthog", bp = 900 },
			{ id = "tortoise", bp = 900 },
			{ id = "meerkat", bp = 900 },
			{ id = "flamingo", bp = 900 },
			{ id = "cheetah", bp = 1600 },
			{ id = "rhino", bp = 1500 },
			{ id = "giraffe", bp = 1500 },
		},
	},
	{
		id = "safari",
		name = "Safari Egg",
		price = 15000,
		odds = {
			{ id = "cheetah", bp = 1900 },
			{ id = "rhino", bp = 1900 },
			{ id = "giraffe", bp = 1900 },
			{ id = "lion", bp = 1300 },
			{ id = "gorilla", bp = 1300 },
			{ id = "mandrill", bp = 1300 },
			{ id = "elephant", bp = 134 },
			{ id = "hippo", bp = 133 },
			{ id = "crocodile", bp = 133 },
		},
	},
} :: { Egg }

-- Training stations (decision 0023): an animal left on a station slowly trains that station's stat.
StationConfig.STATIONS = {
	{ id = "track", name = "Speed Track", stat = "speed" },
	{ id = "gym", name = "Strength Gym", stat = "strength" },
	{ id = "pool", name = "Swim Pool", stat = "stamina" },
	{ id = "library", name = "Magic Library", stat = "mana" },
	{ id = "spring", name = "Healing Spring", stat = "health" },
} :: { Station }
StationConfig.TRAIN_SECONDS = 60 -- seconds on a station for +1 to its stat
-- Training can add at most POTENTIAL x the hatched stat, so a trained animal tops out at double
-- and a variant's higher stats stay a higher ceiling.
StationConfig.POTENTIAL = 1

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
