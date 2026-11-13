--!strict
-- Game 7 "Animal Stations" data (decisions 0019, 0020, 0022, 0023): stats, species, variants,
-- eggs, training stations, battle matchups.
-- Every species has a basic version (common to rare, easy to get) and three variants (epic,
-- legendary, mythic, super rare). Looks for art: docs/game-design/game7-animals.md.
-- Draft values; balance comes later. Pure data, no Roblox APIs.

local StationConfig = {}

export type Stat = "speed" | "strength" | "swim" | "smarts"
export type Stats = { speed: number, strength: number, swim: number, smarts: number }
export type Variant = { id: string, name: string, tier: string, twist: Stat }
export type Species = { id: string, name: string, rarity: string, stats: Stats, variants: { Variant } }
export type Tier = { tier: string, ppm: number, mult: number, twist: number }
export type Odds = { id: string, bp: number } -- bp: basis points, an egg's odds sum to 10000
export type Egg = { id: string, name: string, price: number, odds: { Odds } }
export type Station = { id: string, name: string, stat: Stat }

StationConfig.STATS = { "speed", "strength", "swim", "smarts" } :: { Stat }
StationConfig.STAT_MIN, StationConfig.STAT_MAX = 1, 400
-- A hatched animal's stats are its version's stats x (100 +/- VARIANCE)%, so two cheetahs differ a little.
StationConfig.VARIANCE = 10

StationConfig.BASIC_RARITIES = { "common", "uncommon", "rare" }
StationConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

-- Variant chance on every hatch, from any egg, in parts per million (shown as "1 in N").
-- A variant's stats are the basic stats x mult, plus `twist` on its twist stat (a second job).
StationConfig.TIERS = {
	{ tier = "mythic", ppm = 50, mult = 3.0, twist = 60 }, -- 1 in 20,000
	{ tier = "legendary", ppm = 500, mult = 2.0, twist = 40 }, -- 1 in 2,000
	{ tier = "epic", ppm = 5000, mult = 1.5, twist = 25 }, -- 1 in 200
} :: { Tier }

local function v(id: string, name: string, tier: string, twist: Stat): Variant
	return { id = id, name = name, tier = tier, twist = twist }
end

local function s(speed: number, strength: number, swim: number, smarts: number): Stats
	return { speed = speed, strength = strength, swim = swim, smarts = smarts }
end

-- Four species per stat: two common, one uncommon, one rare. Variants in order epic, legendary, mythic.
StationConfig.SPECIES = {
	-- speed
	{
		id = "bunny",
		name = "Bunny",
		rarity = "common",
		stats = s(40, 10, 8, 18),
		variants = {
			v("clover_bunny", "Clover Bunny", "epic", "smarts"),
			v("moon_bunny", "Moon Bunny", "legendary", "swim"),
			v("comet_bunny", "Comet Bunny", "mythic", "speed"),
		},
	},
	{
		id = "fox",
		name = "Fox",
		rarity = "common",
		stats = s(45, 15, 12, 30),
		variants = {
			v("arctic_fox", "Arctic Fox", "epic", "swim"),
			v("ember_fox", "Ember Fox", "legendary", "strength"),
			v("kitsune", "Kitsune", "mythic", "smarts"),
		},
	},
	{
		id = "horse",
		name = "Horse",
		rarity = "uncommon",
		stats = s(65, 40, 20, 20),
		variants = {
			v("painted_pony", "Painted Pony", "epic", "smarts"),
			v("pegasus", "Pegasus", "legendary", "strength"),
			v("starlight_unicorn", "Starlight Unicorn", "mythic", "smarts"),
		},
	},
	{
		id = "cheetah",
		name = "Cheetah",
		rarity = "rare",
		stats = s(90, 30, 10, 25),
		variants = {
			v("shadow_cheetah", "Shadow Cheetah", "epic", "smarts"),
			v("golden_cheetah", "Golden Cheetah", "legendary", "strength"),
			v("lightning_cheetah", "Lightning Cheetah", "mythic", "speed"),
		},
	},
	-- strength
	{
		id = "pig",
		name = "Pig",
		rarity = "common",
		stats = s(10, 40, 12, 20),
		variants = {
			v("truffle_pig", "Truffle Pig", "epic", "smarts"),
			v("royal_pig", "Royal Pig", "legendary", "smarts"),
			v("flying_pig", "Flying Pig", "mythic", "speed"),
		},
	},
	{
		id = "goat",
		name = "Goat",
		rarity = "common",
		stats = s(25, 45, 5, 15),
		variants = {
			v("mountain_goat", "Mountain Goat", "epic", "speed"),
			v("crystal_goat", "Crystal Goat", "legendary", "smarts"),
			v("thunder_ram", "Thunder Ram", "mythic", "strength"),
		},
	},
	{
		id = "bear",
		name = "Bear",
		rarity = "uncommon",
		stats = s(25, 65, 35, 20),
		variants = {
			v("panda_bear", "Panda Bear", "epic", "smarts"),
			v("polar_bear", "Polar Bear", "legendary", "swim"),
			v("aurora_bear", "Aurora Bear", "mythic", "smarts"),
		},
	},
	{
		id = "gorilla",
		name = "Gorilla",
		rarity = "rare",
		stats = s(25, 90, 10, 45),
		variants = {
			v("silverback", "Silverback", "epic", "smarts"),
			v("lava_gorilla", "Lava Gorilla", "legendary", "strength"),
			v("galaxy_gorilla", "Galaxy Gorilla", "mythic", "smarts"),
		},
	},
	-- swim
	{
		id = "duck",
		name = "Duck",
		rarity = "common",
		stats = s(12, 8, 42, 15),
		variants = {
			v("rubber_duck", "Rubber Duck", "epic", "swim"),
			v("golden_duck", "Golden Duck", "legendary", "smarts"),
			v("storm_duck", "Storm Duck", "mythic", "speed"),
		},
	},
	{
		id = "frog",
		name = "Frog",
		rarity = "common",
		stats = s(30, 8, 45, 12),
		variants = {
			v("dart_frog", "Dart Frog", "epic", "speed"),
			v("frog_prince", "Frog Prince", "legendary", "smarts"),
			v("jade_frog", "Jade Frog", "mythic", "strength"),
		},
	},
	{
		id = "otter",
		name = "Otter",
		rarity = "uncommon",
		stats = s(25, 20, 65, 35),
		variants = {
			v("sea_otter", "Sea Otter", "epic", "smarts"),
			v("pearl_otter", "Pearl Otter", "legendary", "smarts"),
			v("tidal_otter", "Tidal Otter", "mythic", "strength"),
		},
	},
	{
		id = "dolphin",
		name = "Dolphin",
		rarity = "rare",
		stats = s(35, 30, 90, 60),
		variants = {
			v("pink_dolphin", "Pink River Dolphin", "epic", "smarts"),
			v("midnight_dolphin", "Midnight Dolphin", "legendary", "strength"),
			v("crystal_dolphin", "Crystal Dolphin", "mythic", "speed"),
		},
	},
	-- smarts
	{
		id = "mouse",
		name = "Mouse",
		rarity = "common",
		stats = s(22, 5, 8, 42),
		variants = {
			v("clockwork_mouse", "Clockwork Mouse", "epic", "speed"),
			v("wizard_mouse", "Wizard Mouse", "legendary", "smarts"),
			v("astro_mouse", "Astro Mouse", "mythic", "speed"),
		},
	},
	{
		id = "raccoon",
		name = "Raccoon",
		rarity = "common",
		stats = s(20, 20, 15, 45),
		variants = {
			v("treasure_raccoon", "Treasure Raccoon", "epic", "strength"),
			v("ninja_raccoon", "Ninja Raccoon", "legendary", "speed"),
			v("moonleaf_tanuki", "Moonleaf Tanuki", "mythic", "strength"),
		},
	},
	{
		id = "parrot",
		name = "Parrot",
		rarity = "uncommon",
		stats = s(30, 10, 10, 65),
		variants = {
			v("pirate_parrot", "Pirate Parrot", "epic", "swim"),
			v("rainbow_macaw", "Rainbow Macaw", "legendary", "speed"),
			v("phoenix_parrot", "Phoenix Parrot", "mythic", "strength"),
		},
	},
	{
		id = "owl",
		name = "Owl",
		rarity = "rare",
		stats = s(35, 15, 5, 90),
		variants = {
			v("snowy_owl", "Snowy Owl", "epic", "swim"),
			v("arcane_owl", "Arcane Owl", "legendary", "speed"),
			v("celestial_owl", "Celestial Owl", "mythic", "strength"),
		},
	},
} :: { Species }

-- Eggs roll a species (basic odds); the variant roll (TIERS) happens on top, the same for every egg.
StationConfig.EGGS = {
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 100,
		odds = {
			{ id = "bunny", bp = 1400 },
			{ id = "fox", bp = 1100 },
			{ id = "pig", bp = 1400 },
			{ id = "goat", bp = 1100 },
			{ id = "duck", bp = 1400 },
			{ id = "frog", bp = 1100 },
			{ id = "mouse", bp = 1400 },
			{ id = "raccoon", bp = 1100 },
		},
	},
	{
		id = "wild",
		name = "Wild Egg",
		price = 1500,
		odds = {
			{ id = "bunny", bp = 650 },
			{ id = "fox", bp = 650 },
			{ id = "pig", bp = 650 },
			{ id = "goat", bp = 650 },
			{ id = "duck", bp = 650 },
			{ id = "frog", bp = 650 },
			{ id = "mouse", bp = 650 },
			{ id = "raccoon", bp = 650 },
			{ id = "horse", bp = 1200 },
			{ id = "bear", bp = 1200 },
			{ id = "otter", bp = 1200 },
			{ id = "parrot", bp = 1200 },
		},
	},
	{
		id = "safari",
		name = "Safari Egg",
		price = 15000,
		odds = {
			{ id = "horse", bp = 1500 },
			{ id = "bear", bp = 1500 },
			{ id = "otter", bp = 1500 },
			{ id = "parrot", bp = 1500 },
			{ id = "cheetah", bp = 1000 },
			{ id = "gorilla", bp = 1000 },
			{ id = "dolphin", bp = 1000 },
			{ id = "owl", bp = 1000 },
		},
	},
} :: { Egg }

-- Battle matchups (decision 0022): rock paper scissors in a loop of four. Each stat beats one
-- and loses to one; the stat opposite it is neutral. An animal battles as its best stat.
-- Speed rushes Smarts before it can plan, Smarts outwits Strength, Strength muscles through
-- Swim's current, Swim's water slows Speed.
StationConfig.BEATS = { speed = "smarts", smarts = "strength", strength = "swim", swim = "speed" } :: { [Stat]: Stat }
StationConfig.ADVANTAGE = 1.25 -- damage x this with the advantage, / this against it (slight, not decisive)

-- Training stations (decision 0023): an animal left on a station slowly trains that station's stat.
StationConfig.STATIONS = {
	{ id = "track", name = "Speed Track", stat = "speed" },
	{ id = "gym", name = "Strength Gym", stat = "strength" },
	{ id = "pool", name = "Swim Pool", stat = "swim" },
	{ id = "library", name = "Puzzle Library", stat = "smarts" },
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
	local sp = StationConfig.species(speciesId)
	return if sp then find(sp.variants, variantId) else nil
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
