--!strict
-- Game 7 "Animal Stations" data (decisions 0019 to 0041): stats and stat levels, roles, groups,
-- the small African beta pool with its variants, the Titan, eggs and training stations, and the
-- Hexbound, the enemies of the waves. Every species has a basic version (never above epic; the
-- Titan is legendary) and rare variants (legendary or mythic). A variant is a drop of its own in
-- the eggs that list it (`Egg.rare`, decision 0056), rarer than any basic animal. Looks for art:
-- docs/game-design/game7-animals.md and game7-enemies.md.
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
-- An enemy of the waves (decision 0040): the same six stats, role and group as an animal, so
-- BattleRules fights it the same way, but never hatched, owned, saved or found in an egg.
export type Foe = {
	id: string,
	name: string,
	kind: string, -- "knight" | "archer" | "mage" | "ogre" | "dragon"
	model: string, -- the asset that shows it ("foe_<kind>"): a tier of a kind is the same model
	size: number?, -- scaled by this (default 1) ...
	tint: { number }?, -- ... and tinted this colour, r g b 0 to 255 (default: as built)
	role: string, -- "attack" | "defense" | "utility"
	group: string, -- "pack" | "solitary"
	stats: Stats, -- before the wave's scaling
	from: number?, -- the first wave it can appear in the normal line (nil: never)
	boss: number?, -- the first wave it can be the dragon that ends a boss wave (nil: never)
}
export type Tier = { tier: string, mult: number, twist: number }
export type Odds = { id: string, bp: number } -- bp: basis points, an egg's odds sum to 10000
export type Rare = { s: string, v: string, ppm: number } -- a variant as a drop of its own: ppm of the egg's hatches
-- wave: the wave that must be cleared before it can be bought (nil = from the start); xp: player XP
-- for buying it; hatch: seconds it sits in the ranch's hatchery before it opens (decision 0036,
-- draft numbers); odds: its basic animals; rare: its variants, rolled first (decision 0056)
export type Egg = {
	id: string,
	name: string,
	price: number,
	xp: number,
	hatch: number,
	wave: number?,
	odds: { Odds },
	rare: { Rare },
}
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

-- Variant tiers. A variant's stats are the basic stats x mult, plus `twist` on its twist stat. How
-- often one hatches is set egg by egg (EGGS, `rare`).
StationConfig.TIERS = {
	{ tier = "mythic", mult = 3.0, twist = 60 },
	{ tier = "legendary", mult = 2.0, twist = 40 },
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
-- One variant each (decision 0037): legendary for the commons, mythic for the rest. A variant is
-- always legendary or higher. Its model is the asset "creature_<species>_<first word of its id>".
StationConfig.SPECIES = {
	{
		id = "jackal",
		name = "Jackal",
		role = "attack",
		group = "pack",
		rarity = "common",
		stats = s(42, 22, 15, 18, 30, 10),
		variants = {
			v("pharaoh_jackal", "Pharaoh Jackal", "legendary", "mana"),
			v("sphinx_jackal", "Sphinx Jackal", "mythic", "speed"),
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
			v("gemshell_tortoise", "Gemshell Tortoise", "legendary", "defence"),
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
			v("storm_meerkat", "Storm Meerkat", "legendary", "mana"),
			v("star_meerkat", "Star Meerkat", "mythic", "speed"),
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
			v("lightning_cheetah", "Lightning Cheetah", "mythic", "speed"),
			v("fire_cheetah", "Fire Cheetah", "legendary", "strength"),
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
			v("lava_rhino", "Lava Rhino", "mythic", "strength"),
			v("crystal_rhino", "Crystal Rhino", "legendary", "defence"),
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
			v("phoenix_flamingo", "Phoenix Flamingo", "mythic", "mana"),
			v("peacock_flamingo", "Peacock Flamingo", "legendary", "stamina"),
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
			v("sun_lion", "Sun Lion", "mythic", "strength"),
			v("shadow_lion", "Shadow Lion", "legendary", "speed"),
		},
	},
	{
		id = "elephant",
		name = "Elephant",
		role = "titan",
		group = "pack",
		rarity = "legendary",
		stats = s(30, 160, 180, 60, 200, 120),
		variants = {
			v("frost_elephant", "Frost Mammoth", "mythic", "health"),
			v("war_elephant", "War Elephant", "legendary", "strength"),
		},
	},
} :: { Species }

-- The Hexbound (decisions 0040, 0041): evil magic knights, archers, mages, ogres and dragons, the
-- enemies of the endless waves. Knights are haunted armour and fight from the first wave; after that
-- something new turns up every few waves: archers at 3, ogres at 5, mages from 6 (a healer at 8, a
-- warden at 12), a crossbowman at 9 and the ogre warlord at 15. A dragon ends every 10th wave: the
-- strongest one the wave allows. Archers are fast and fragile, mages hit hard through their Mana,
-- heal or ward. Draft numbers, set to the strength of the animals the waves used before, so the
-- waves are as hard. Their model is the asset "foe_<kind>"; tiers within a kind differ by tint
-- and size.
StationConfig.FOE_KINDS = { "knight", "archer", "mage", "ogre", "dragon" }
StationConfig.FOES = {
	{
		id = "gloom_squire",
		name = "Gloom Squire",
		kind = "knight",
		model = "foe_knight",
		role = "attack",
		group = "pack",
		stats = s(38, 24, 16, 14, 32, 14),
		from = 1,
	},
	{
		id = "gloom_bulwark",
		name = "Gloom Bulwark",
		kind = "knight",
		model = "foe_knight",
		size = 1.2,
		tint = { 150, 175, 215 },
		role = "defense",
		group = "solitary",
		stats = s(8, 26, 48, 12, 58, 58),
		from = 1,
	},
	{
		id = "gloom_banner",
		name = "Gloom Banner",
		kind = "knight",
		model = "foe_knight",
		tint = { 255, 160, 160 },
		role = "utility",
		group = "pack",
		stats = s(28, 8, 16, 44, 28, 10),
		from = 1,
	},
	{
		id = "shade_archer",
		name = "Shade Archer",
		kind = "archer",
		model = "foe_archer",
		role = "attack",
		group = "pack",
		stats = s(46, 24, 14, 14, 26, 8),
		from = 3,
	},
	{
		id = "shade_crossbowman",
		name = "Shade Crossbowman",
		kind = "archer",
		model = "foe_archer",
		size = 1.15,
		tint = { 200, 175, 140 },
		role = "attack",
		group = "solitary",
		stats = s(16, 70, 26, 14, 50, 16),
		from = 9,
	},
	{
		id = "ogre_brute",
		name = "Ogre Brute",
		kind = "ogre",
		model = "foe_ogre",
		role = "attack",
		group = "solitary",
		stats = s(24, 80, 28, 8, 76, 22),
		from = 5,
	},
	{
		id = "ogre_shaman",
		name = "Ogre Shaman",
		kind = "ogre",
		model = "foe_ogre",
		size = 0.9,
		tint = { 185, 160, 240 },
		role = "utility",
		group = "pack",
		stats = s(28, 12, 28, 60, 50, 12),
		from = 5,
	},
	{
		id = "ogre_warlord",
		name = "Ogre Warlord",
		kind = "ogre",
		model = "foe_ogre",
		size = 1.25,
		tint = { 165, 125, 125 },
		role = "attack",
		group = "pack",
		stats = s(46, 92, 40, 20, 84, 28),
		from = 15,
	},
	{
		id = "hexcaster",
		name = "Hexcaster",
		kind = "mage",
		model = "foe_mage",
		role = "attack",
		group = "solitary",
		stats = s(26, 56, 14, 72, 38, 8),
		from = 6,
	},
	{
		id = "hexweaver",
		name = "Hexweaver",
		kind = "mage",
		model = "foe_mage",
		size = 0.95,
		tint = { 190, 255, 215 },
		role = "utility",
		group = "pack",
		stats = s(28, 10, 20, 58, 36, 10),
		from = 8,
	},
	{
		id = "hexwarden",
		name = "Hexwarden",
		kind = "mage",
		model = "foe_mage",
		size = 1.2,
		tint = { 130, 130, 190 },
		role = "defense",
		group = "solitary",
		stats = s(10, 24, 46, 42, 62, 56),
		from = 12,
	},
	{
		id = "hexfire_whelp",
		name = "Hexfire Whelp",
		kind = "dragon",
		model = "foe_dragon",
		size = 0.85,
		tint = { 200, 200, 240 },
		role = "attack",
		group = "solitary",
		stats = s(46, 70, 36, 46, 108, 38),
		boss = 10,
	},
	{
		id = "hexfire_drake",
		name = "Hexfire Drake",
		kind = "dragon",
		model = "foe_dragon",
		role = "attack",
		group = "solitary",
		stats = s(70, 130, 70, 80, 200, 90),
		boss = 30,
	},
	{
		id = "hexfire_dragon",
		name = "Hexfire Dragon",
		kind = "dragon",
		model = "foe_dragon",
		size = 1.45,
		tint = { 160, 135, 180 },
		role = "attack",
		group = "solitary",
		stats = s(100, 200, 100, 120, 320, 160),
		boss = 60,
	},
} :: { Foe }

-- Eggs (decision 0056). A hatch first rolls the egg's rare drops: each variant it lists is a drop of
-- its own, `ppm` hatches in a million (shown as "1 in N", so every ppm divides a million). If none
-- hits, it rolls a basic animal by `odds`. A variant gets likelier egg by egg, and an animal's mythic
-- starts one egg after its legendary. The Meadow and Wild Eggs are open from the start; the others
-- unlock with the waves: the Safari Egg with the first dragon beaten (wave 10), the Golden Egg with
-- the second (wave 20). There is no legendary-only egg: the Titan is a rare hatch from the Golden Egg,
-- which drops other animals too (decision 0031). Draft numbers.
local function r(species: string, variant: string, oneIn: number): Rare
	return { s = species, v = variant, ppm = 1_000_000 / oneIn }
end

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
		rare = {
			r("jackal", "pharaoh_jackal", 5000),
			r("tortoise", "gemshell_tortoise", 5000),
			r("meerkat", "storm_meerkat", 5000),
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
		rare = {
			r("jackal", "sphinx_jackal", 20000),
			r("tortoise", "island_tortoise", 20000),
			r("meerkat", "star_meerkat", 20000),
			r("jackal", "pharaoh_jackal", 2000),
			r("tortoise", "gemshell_tortoise", 2000),
			r("meerkat", "storm_meerkat", 2000),
			r("cheetah", "fire_cheetah", 4000),
			r("rhino", "crystal_rhino", 4000),
			r("flamingo", "peacock_flamingo", 4000),
		},
	},
	{
		id = "safari",
		name = "Safari Egg",
		price = 15000,
		xp = 150,
		hatch = 3600,
		wave = 10,
		odds = {
			{ id = "cheetah", bp = 2700 },
			{ id = "rhino", bp = 2700 },
			{ id = "flamingo", bp = 2600 },
			{ id = "lion", bp = 2000 },
		},
		rare = {
			r("cheetah", "lightning_cheetah", 10000),
			r("rhino", "lava_rhino", 10000),
			r("flamingo", "phoenix_flamingo", 10000),
			r("jackal", "sphinx_jackal", 5000),
			r("tortoise", "island_tortoise", 5000),
			r("meerkat", "star_meerkat", 5000),
			r("cheetah", "fire_cheetah", 500),
			r("rhino", "crystal_rhino", 500),
			r("flamingo", "peacock_flamingo", 500),
			r("lion", "shadow_lion", 2000),
		},
	},
	{
		id = "golden",
		name = "Golden Egg",
		price = 50000,
		xp = 500,
		hatch = 14400,
		wave = 20,
		odds = {
			{ id = "lion", bp = 5000 },
			{ id = "cheetah", bp = 1500 },
			{ id = "rhino", bp = 1500 },
			{ id = "flamingo", bp = 1500 },
			{ id = "elephant", bp = 500 },
		},
		rare = {
			r("elephant", "frost_elephant", 20000),
			r("lion", "sun_lion", 4000),
			r("cheetah", "lightning_cheetah", 2000),
			r("rhino", "lava_rhino", 2000),
			r("flamingo", "phoenix_flamingo", 2000),
			r("lion", "shadow_lion", 400),
			r("elephant", "war_elephant", 2000),
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

-- The foe `id`, or nil. A foe is never a species: nothing that hatches or saves looks here.
function StationConfig.foe(id: string): Foe?
	return find(StationConfig.FOES, id)
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
