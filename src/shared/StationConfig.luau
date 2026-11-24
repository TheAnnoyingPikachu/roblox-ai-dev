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
-- tier: its rarity (decision 0110: set by its power, `RARITY_FLOOR`); mult: its stats are the species' x mult,
-- and its twist stat gains TWIST_PER x mult more
export type Variant = { id: string, name: string, tier: string, twist: Stat, mult: number }
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
	kind: string, -- "knight" | "archer" | "mage" | "ogre" | "golem" | "cavalry" | "dragon"
	model: string, -- the asset that shows it ("foe_<kind>[_<word>]_forge", decision 0104)
	size: number?, -- scaled by this (default 1; the stronger ones stand bigger, and a dragon's wings must still
	-- pass the arena gate, 42 studs wide: Arena.luau) ...
	tint: { number }?, -- ... and tinted this colour, r g b 0 to 255 (default: as built)
	role: string, -- "attack" | "defense" | "utility"
	group: string, -- "pack" | "solitary"
	stats: Stats, -- before the wave's scaling
	from: number?, -- the first wave it can appear in the normal line (nil: never)
	boss: number?, -- the first wave it can be the dragon that ends a boss wave (nil: never)
	minion: boolean?, -- a swarm's minion (decision 0101): never drawn as a regular
	ability: string?, -- "revive": its power attack raises fallen allies (decision 0104); "sweep": it strikes the
	-- whole team (decision 0105)
}
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
	only: boolean?, -- variants only (decision 0110): its `rare` drops add up to a million, `odds` is empty
	coat: string?, -- its signature coat: COAT_TIMES (or `times`) as likely
	times: number?,
	always: boolean?, -- every hatch has a coat (the coats' odds scaled to a million)
}
export type Coat = {
	id: string,
	name: string,
	ppm: number,
	all: number?,
	stat: Stat?,
	pct: number?,
	xp: number?,
	charged: boolean?,
	spectral: boolean?,
}
export type Station = { id: string, name: string, stat: Stat }

-- Each stat has one job in a wave fight (decision 0032, BattleRules): Speed is attack speed,
-- Strength damage, Stamina the rest between attacks, Mana the charge towards the power attack,
-- Health HP and Defence cuts incoming damage.
StationConfig.STATS = { "speed", "strength", "stamina", "mana", "health", "defence" } :: { Stat }
StationConfig.STAT_MIN, StationConfig.STAT_MAX = 1, 1000 -- limits of a version's (level 0) stat

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
-- Coats (decisions 0058, 0110): any hatch, of any animal or variant, can come out in one coat, rolled after
-- the animal: `ppm` hatches in a million, `times` as often from an egg whose signature coat it is (`Egg.coat`).
-- `all` adds that percent to every stat, `stat` and `pct` to one, rounded up, so even a stat of 8 gains 1.
-- `xp`: the player gains that percent more XP from a wave it fights in (up to COAT_XP_MAX of them count).
-- `charged`: its power meter starts each fight CHARGED_START full. `spectral`: once a fight, a blow that
-- would knock it out leaves it at 1 HP. Rarest first; the rainbow coat of decision 0058 is one of them.
StationConfig.COATS = {
	{ id = "prismatic", name = "Prismatic", ppm = 100, all = 30 },
	{ id = "spectral", name = "Spectral", ppm = 400, spectral = true },
	{ id = "galaxy", name = "Galaxy", ppm = 1000, stat = "mana", pct = 12, charged = true },
	{ id = "gilded", name = "Gilded", ppm = 1000, xp = 25 },
	{ id = "rainbow", name = "Rainbow", ppm = 2000, all = 5 },
	{ id = "ember", name = "Ember", ppm = 2500, stat = "strength", pct = 12 },
	{ id = "frost", name = "Frost", ppm = 2500, stat = "health", pct = 12 },
	{ id = "storm", name = "Storm", ppm = 2500, stat = "speed", pct = 12 },
	{ id = "obsidian", name = "Obsidian", ppm = 2500, stat = "defence", pct = 12 },
	{ id = "verdant", name = "Verdant", ppm = 2500, stat = "stamina", pct = 12 },
} :: { Coat }
StationConfig.COAT_TIMES = 5 -- an egg's signature coat is this many times as likely
StationConfig.COAT_XP_MAX = 3
StationConfig.CHARGED_START = 0.25
-- Player XP comes from everything the player does (decision 0032). Built so far: hatching (each
-- egg's `xp`) and every stat level a creature gains in training. Waves, the login tracks and
-- gear will add theirs when they exist.
StationConfig.XP_STAT_LEVEL = 5

StationConfig.BASIC_RARITIES = { "common", "uncommon", "rare" }
StationConfig.RARITIES =
	{ "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "celestial", "secret" }
-- Rarity by power (decision 0110): a version's rarity is the band its stat total falls in (a Titan's band
-- is TITAN_BAND times wider). "secret" is kept for animals that are not ranked by power; none yet.
StationConfig.RARITY_FLOOR = {
	common = 0,
	uncommon = 180,
	rare = 260,
	epic = 400,
	legendary = 550,
	mythic = 800,
	divine = 1100,
	celestial = 1600,
} :: { [string]: number }
StationConfig.TITAN_BAND = 1.6
StationConfig.TWIST_PER = 20

-- Roles (decision 0027): three team roles, each with its own job in a wave fight (BattleRules),
-- and the Titan, which fills the team's fourth slot.
StationConfig.ROLES = { "attack", "defense", "utility" }
StationConfig.TITAN = "titan"

-- Groups (decision 0029): a pack animal gains PACK_PCT % attack and HP for each other pack
-- animal on its team; a solitary animal gains SOLITARY_PCT % when no teammate shares its role.
StationConfig.GROUPS = { "pack", "solitary" }
StationConfig.PACK_PCT = 10
StationConfig.SOLITARY_PCT = 25

-- Variants (decision 0110, replacing the two tiers of decision 0037): each has its own `mult`, set so its
-- power lands in its rarity's band (StationRules.powerRarity; a spec checks). How often one hatches is set
-- egg by egg (EGGS, `rare`).
local function v(id: string, name: string, tier: string, twist: Stat, mult: number): Variant
	return { id = id, name = name, tier = tier, twist = twist, mult = mult }
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

-- Small African beta pool: one common and one uncommon per role, a rare lion, and the Titan. Rarity by power
-- (decision 0110): the Tortoise is uncommon, the Rhino rare, the Titan Elephant epic.
-- Pack: jackal (dog), lion (cat), meerkat, flamingo (bird), giraffe, elephant. Solitary: tortoise, cheetah, rhino.
-- Two variants each (decisions 0037, 0110): each at least epic, its rarity by its power. Its model is the asset "creature_<species>_<first word of its id>".
StationConfig.SPECIES = {
	{
		id = "jackal",
		name = "Jackal",
		role = "attack",
		group = "pack",
		rarity = "common",
		stats = s(42, 22, 15, 18, 30, 10),
		variants = {
			v("pharaoh_jackal", "Pharaoh Jackal", "epic", "mana", 2.8),
			v("sphinx_jackal", "Sphinx Jackal", "legendary", "speed", 4),
		},
	},
	{
		id = "tortoise",
		name = "Tortoise",
		role = "defense",
		group = "solitary",
		rarity = "uncommon",
		stats = s(5, 25, 48, 20, 55, 50),
		variants = {
			v("gemshell_tortoise", "Gemshell Tortoise", "epic", "defence", 2),
			v("island_tortoise", "Island Tortoise", "legendary", "health", 3),
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
			-- the ids stay so saves and eggs keep them; SHANNON renamed them to fit their models (decision 0102)
			v("storm_meerkat", "Alien Meerkat", "epic", "mana", 2.9),
			v("star_meerkat", "Comet Meerkat", "legendary", "speed", 4),
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
			v("lightning_cheetah", "Lightning Cheetah", "mythic", "speed", 3.8),
			-- the id stays "fire_cheetah" so saves and eggs keep it; SHANNON made it the Thunder Cheetah (decision 0102)
			v("fire_cheetah", "Thunder Cheetah", "epic", "strength", 2),
		},
	},
	{
		id = "rhino",
		name = "Rhino",
		role = "defense",
		group = "solitary",
		rarity = "rare",
		stats = s(25, 50, 60, 10, 70, 55),
		variants = {
			v("lava_rhino", "Lava Rhino", "legendary", "strength", 2),
			v("crystal_rhino", "Crystal Rhino", "divine", "defence", 4),
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
			v("phoenix_flamingo", "Phoenix Flamingo", "legendary", "mana", 3),
			v("peacock_flamingo", "King Flamingo", "epic", "stamina", 2), -- renamed by SHANNON (decision 0102); the id stays
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
			v("sun_lion", "Sun Lion", "celestial", "strength", 5),
			v("shadow_lion", "Shadow Lion", "mythic", "speed", 2.6),
		},
	},
	{ -- decision 0079: draft numbers, a little over the Lion's total
		id = "giraffe",
		name = "Giraffe",
		role = "utility",
		group = "pack",
		rarity = "rare",
		stats = s(50, 60, 45, 55, 80, 25),
		variants = {
			v("diamond_giraffe", "Diamond Giraffe", "divine", "defence", 3.6),
			v("acacia_giraffe", "Acacia Giraffe", "mythic", "health", 2.6), -- decision 0103
		},
	},
	{
		id = "elephant",
		name = "Elephant",
		role = "titan",
		group = "pack",
		rarity = "epic",
		stats = s(30, 160, 180, 60, 200, 120),
		variants = {
			v("frost_elephant", "Frost Mammoth", "celestial", "health", 3.4),
			v("war_elephant", "War Elephant", "mythic", "strength", 2),
		},
	},
} :: { Species }

-- The Shadow Legion (decision 0104, replacing the Hexbound of decisions 0040 and 0041): SHANNON's ForgeGUI
-- enemies of the endless waves, each its own model. Knights, heavy knights and battle priests (they heal
-- the enemies) fight from the first wave, one of each role; something new turns up every wave or few after
-- that: archers at 3, shieldbearers at 4, the ogre enforcer at 5, the darkcaster (a damage mage) at 6, the
-- berserker at 7, crossbows at 9, cavalry at 11, the necromancer (raises a fallen enemy, once each) at 12, the ogre
-- commander at 15, the shieldbearer commander at 18, the siege golem at 22 and the cavalry commander at
-- 26. A dragon ends every 10th wave: the strongest one the wave allows (the dark drake from 10, the
-- shadow dragon from 30, the ancient alpha dragon from 60). Draft numbers: the ones that replace an old
-- enemy keep its stats, so the waves stay as hard. Their model is "foe_<kind>[_<word>]_forge".
StationConfig.FOE_KINDS = { "knight", "archer", "mage", "ogre", "golem", "cavalry", "dragon" }
StationConfig.FOES = {
	{
		id = "shadow_knight",
		name = "Shadow Knight",
		kind = "knight",
		model = "foe_knight_forge",
		role = "attack",
		group = "pack",
		stats = s(38, 24, 16, 14, 32, 14),
		from = 1,
	},
	{
		id = "heavy_knight",
		name = "Heavy Knight",
		kind = "knight",
		model = "foe_knight_heavy_forge",
		role = "defense",
		group = "solitary",
		stats = s(8, 26, 48, 12, 58, 58),
		from = 1,
	},
	{
		id = "shadow_archer",
		name = "Shadow Archer",
		kind = "archer",
		model = "foe_archer_forge",
		role = "attack",
		group = "pack",
		stats = s(46, 24, 14, 14, 26, 8),
		from = 3,
	},
	{
		id = "shieldbearer",
		name = "Shieldbearer",
		kind = "knight",
		model = "foe_knight_shield_forge",
		role = "defense",
		group = "pack",
		stats = s(12, 16, 44, 10, 54, 66),
		from = 4,
	},
	{
		id = "ogre_enforcer",
		name = "Ogre Enforcer",
		kind = "ogre",
		model = "foe_ogre_forge",
		size = 1.15,
		role = "attack",
		group = "solitary",
		stats = s(24, 80, 28, 8, 76, 22),
		from = 5,
	},
	{
		id = "darkcaster",
		name = "Darkcaster",
		kind = "mage",
		model = "foe_mage_forge",
		role = "attack",
		group = "solitary",
		stats = s(26, 56, 14, 72, 38, 8),
		from = 6,
	},
	{
		id = "berserker",
		name = "Berserker",
		kind = "knight",
		model = "foe_knight_berserker_forge",
		size = 1.1,
		role = "attack",
		group = "solitary",
		stats = s(52, 60, 22, 20, 44, 10),
		from = 7,
	},
	{
		id = "battle_priest",
		name = "Battle Priest",
		kind = "mage",
		model = "foe_mage_priest_forge",
		role = "utility",
		group = "pack",
		stats = s(28, 8, 16, 44, 28, 10),
		from = 1,
	},
	{
		id = "crossbow_troop",
		name = "Crossbow Troop",
		kind = "archer",
		model = "foe_archer_crossbow_forge",
		role = "attack",
		group = "solitary",
		stats = s(16, 70, 26, 14, 50, 16),
		from = 9,
	},
	{
		id = "cavalry",
		name = "Cavalry",
		kind = "cavalry",
		model = "foe_cavalry_forge",
		size = 1.1,
		role = "attack",
		group = "pack",
		stats = s(72, 40, 30, 14, 48, 24),
		from = 11,
	},
	{
		id = "necromancer",
		name = "Necromancer",
		kind = "mage",
		model = "foe_mage_necromancer_forge",
		size = 1.15,
		role = "attack",
		group = "solitary",
		stats = s(20, 30, 30, 70, 46, 20),
		ability = "revive",
		from = 12,
	},
	{
		id = "ogre_commander",
		name = "Ogre Commander",
		kind = "ogre",
		model = "foe_ogre_commander_forge",
		size = 1.3,
		role = "attack",
		group = "pack",
		stats = s(46, 92, 40, 20, 84, 28),
		from = 15,
	},
	{
		id = "shieldbearer_commander",
		name = "Shieldbearer Commander",
		kind = "knight",
		model = "foe_knight_shield_commander_forge",
		size = 1.3,
		role = "defense",
		group = "solitary",
		stats = s(14, 30, 56, 24, 80, 90),
		from = 18,
	},
	{
		id = "siege_golem",
		name = "Siege Golem",
		kind = "golem",
		model = "foe_golem_forge",
		size = 1.45,
		role = "defense",
		group = "solitary",
		stats = s(6, 60, 64, 10, 110, 96),
		ability = "sweep",
		from = 22,
	},
	{
		id = "cavalry_commander",
		name = "Cavalry Commander",
		kind = "cavalry",
		model = "foe_cavalry_commander_forge",
		size = 1.3,
		role = "attack",
		group = "solitary",
		stats = s(82, 84, 44, 24, 90, 40),
		from = 26,
	},
	{
		id = "dark_drake",
		name = "Dark Drake",
		kind = "dragon",
		model = "foe_dragon_drake_forge",
		size = 1.9,
		role = "attack",
		group = "solitary",
		stats = s(46, 70, 36, 46, 108, 38),
		ability = "sweep",
		boss = 10,
	},
	{
		id = "shadow_dragon",
		name = "Shadow Dragon",
		kind = "dragon",
		model = "foe_dragon_forge",
		size = 2.0,
		role = "attack",
		group = "solitary",
		stats = s(70, 130, 70, 80, 200, 90),
		ability = "sweep",
		boss = 30,
	},
	{
		id = "ancient_alpha_dragon",
		name = "Ancient Alpha Dragon",
		kind = "dragon",
		model = "foe_dragon_alpha_forge",
		size = 1.8,
		role = "attack",
		group = "solitary",
		stats = s(100, 200, 100, 120, 320, 160),
		ability = "sweep",
		boss = 60,
	},
} :: { Foe }

-- Eggs (decisions 0056, 0110). A hatch first rolls the egg's rare drops: each variant it lists is a drop of
-- its own, `ppm` hatches in a million (shown as "1 in N", so every ppm divides a million). If none
-- hits, it rolls a basic animal by `odds`. Twelve eggs, one opening every 10 to 50 waves, each holding two
-- or three animals and its own variants and signature coat, so collecting means working up through them.
-- The first seven drop animals and, rarely, variants; the last five (`only`) drop nothing but variants,
-- rarer and stronger egg by egg up to the Crown Egg for clearing the last wave. Every hatch from the
-- Celestial and Crown Eggs has a coat, and the Crown Egg's Prismatic is far likelier (decision 0110, which
-- replaces decision 0031's "no legendary-only egg"). Draft numbers: a price is about 250 first clears of
-- the wave that opens the egg.
local function r(species: string, variant: string, oneIn: number): Rare
	return { s = species, v = variant, ppm = 1_000_000 / oneIn }
end
local function w(species: string, variant: string, ppm: number): Rare -- a variant-only egg's share
	return { s = species, v = variant, ppm = ppm }
end
local function egg(e: any): Egg
	return e :: Egg
end

StationConfig.EGGS = {
	egg({
		id = "meadow",
		name = "Meadow Egg",
		price = 100,
		xp = 10,
		hatch = 60,
		odds = { { id = "jackal", bp = 5000 }, { id = "meerkat", bp = 5000 } },
		rare = { r("jackal", "pharaoh_jackal", 5000), r("meerkat", "storm_meerkat", 5000) },
	}),
	egg({
		id = "wild",
		name = "Wild Egg",
		price = 1500,
		xp = 40,
		hatch = 600,
		odds = { { id = "jackal", bp = 3000 }, { id = "tortoise", bp = 3500 }, { id = "cheetah", bp = 3500 } },
		rare = { r("tortoise", "gemshell_tortoise", 4000), r("cheetah", "fire_cheetah", 4000) },
		coat = "storm",
	}),
	egg({
		id = "safari",
		name = "Safari Egg",
		price = 15000,
		xp = 150,
		hatch = 3600,
		wave = 10,
		odds = { { id = "meerkat", bp = 3000 }, { id = "flamingo", bp = 3500 }, { id = "rhino", bp = 3500 } },
		rare = { r("flamingo", "peacock_flamingo", 2000), r("meerkat", "star_meerkat", 10000) },
		coat = "ember",
	}),
	egg({
		id = "golden",
		name = "Golden Egg",
		price = 50000,
		xp = 500,
		hatch = 14400,
		wave = 20,
		odds = {
			{ id = "cheetah", bp = 3000 },
			{ id = "lion", bp = 3500 },
			{ id = "giraffe", bp = 3000 },
			{ id = "elephant", bp = 500 },
		},
		rare = { r("cheetah", "fire_cheetah", 2000), r("cheetah", "lightning_cheetah", 25000) },
		coat = "gilded",
	}),
	egg({
		id = "dusk",
		name = "Dusk Egg",
		price = 140_000,
		xp = 800,
		hatch = 6 * 3600,
		wave = 35,
		odds = { { id = "tortoise", bp = 3500 }, { id = "rhino", bp = 3500 }, { id = "jackal", bp = 3000 } },
		rare = {
			r("tortoise", "island_tortoise", 5000),
			r("jackal", "sphinx_jackal", 5000),
			r("rhino", "lava_rhino", 8000),
		},
		coat = "obsidian",
	}),
	egg({
		id = "oasis",
		name = "Oasis Egg",
		price = 430_000,
		xp = 1200,
		hatch = 8 * 3600,
		wave = 50,
		odds = { { id = "flamingo", bp = 3500 }, { id = "giraffe", bp = 3000 }, { id = "meerkat", bp = 3500 } },
		rare = { r("flamingo", "phoenix_flamingo", 5000), r("giraffe", "acacia_giraffe", 20000) },
		coat = "verdant",
	}),
	egg({
		id = "ivory",
		name = "Ivory Egg",
		price = 3_000_000,
		xp = 2000,
		hatch = 12 * 3600,
		wave = 75,
		odds = { { id = "elephant", bp = 4000 }, { id = "rhino", bp = 3000 }, { id = "lion", bp = 3000 } },
		rare = { r("elephant", "war_elephant", 5000), r("lion", "shadow_lion", 20000) },
		coat = "frost",
	}),
	egg({
		id = "legend",
		name = "Legend Egg",
		price = 20_000_000,
		xp = 3000,
		hatch = 16 * 3600,
		wave = 100,
		only = true,
		odds = {},
		rare = { -- epic 80%, legendary 20%
			w("jackal", "pharaoh_jackal", 160000),
			w("meerkat", "storm_meerkat", 160000),
			w("tortoise", "gemshell_tortoise", 160000),
			w("flamingo", "peacock_flamingo", 160000),
			w("cheetah", "fire_cheetah", 160000),
			w("jackal", "sphinx_jackal", 40000),
			w("meerkat", "star_meerkat", 40000),
			w("tortoise", "island_tortoise", 40000),
			w("flamingo", "phoenix_flamingo", 40000),
			w("rhino", "lava_rhino", 40000),
		},
		coat = "spectral",
	}),
	egg({
		id = "mythic",
		name = "Mythic Egg",
		price = 440_000_000,
		xp = 5000,
		hatch = 24 * 3600,
		wave = 140,
		only = true,
		odds = {},
		rare = { -- legendary 85%, mythic 15%
			w("jackal", "sphinx_jackal", 170000),
			w("meerkat", "star_meerkat", 170000),
			w("tortoise", "island_tortoise", 170000),
			w("flamingo", "phoenix_flamingo", 170000),
			w("rhino", "lava_rhino", 170000),
			w("cheetah", "lightning_cheetah", 37500),
			w("lion", "shadow_lion", 37500),
			w("giraffe", "acacia_giraffe", 37500),
			w("elephant", "war_elephant", 37500),
		},
		coat = "galaxy",
	}),
	egg({
		id = "divine",
		name = "Divine Egg",
		price = 9.6e9,
		xp = 8000,
		hatch = 36 * 3600,
		wave = 180,
		only = true,
		odds = {},
		rare = { -- mythic 90%, divine 10%
			w("cheetah", "lightning_cheetah", 225000),
			w("lion", "shadow_lion", 225000),
			w("giraffe", "acacia_giraffe", 225000),
			w("elephant", "war_elephant", 225000),
			w("rhino", "crystal_rhino", 50000),
			w("giraffe", "diamond_giraffe", 50000),
		},
		coat = "prismatic",
	}),
	egg({
		id = "celestial",
		name = "Celestial Egg",
		price = 4.5e11,
		xp = 12000,
		hatch = 48 * 3600,
		wave = 230,
		only = true,
		odds = {},
		rare = { -- divine 95%, celestial 5%
			w("rhino", "crystal_rhino", 475000),
			w("giraffe", "diamond_giraffe", 475000),
			w("lion", "sun_lion", 30000),
			w("elephant", "frost_elephant", 20000),
		},
		always = true,
	}),
	egg({
		id = "crown",
		name = "Crown Egg",
		price = 9.8e13,
		xp = 20000,
		hatch = 72 * 3600,
		wave = 300,
		only = true,
		odds = {},
		rare = { w("lion", "sun_lion", 600000), w("elephant", "frost_elephant", 400000) },
		coat = "prismatic",
		times = 20,
		always = true,
	}),
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
	-- the homestead's other buildings (decision 0072): draft numbers, none playtested
	{
		id = "hatchery",
		name = "Hatchery",
		gives = "eggs hatching at once",
		base = 3,
		levels = {
			{ coins = 400, samples = 0, value = 4 },
			{ coins = 2500, samples = 0, value = 5 },
			{ coins = 12000, samples = 10, value = 6 },
			{ coins = 60000, samples = 40, value = 8 },
			{ coins = 300000, samples = 120, value = 10 },
		},
	},
	{
		id = "cellar",
		name = "Egg Storage", -- the cellar and its greenhouse (decision 0091)
		gives = "eggs you can store",
		base = 8,
		levels = {
			{ coins = 300, samples = 0, value = 12 },
			{ coins = 1500, samples = 0, value = 18 },
			{ coins = 8000, samples = 5, value = 24 },
			{ coins = 40000, samples = 30, value = 36 },
			{ coins = 200000, samples = 100, value = 48 },
		},
	},
	{
		id = "brooder",
		name = "Brooder",
		gives = "% hatching speed",
		base = 100,
		levels = {
			{ coins = 1000, samples = 0, value = 115 },
			{ coins = 5000, samples = 0, value = 130 },
			{ coins = 25000, samples = 10, value = 150 },
			{ coins = 120000, samples = 50, value = 175 },
			{ coins = 500000, samples = 150, value = 200 },
		},
	},
	{
		id = "windmill",
		name = "Windmill",
		gives = "coins an hour, also while you are away",
		base = 0,
		levels = {
			{ coins = 2000, samples = 0, value = 60 },
			{ coins = 10000, samples = 0, value = 150 },
			{ coins = 40000, samples = 15, value = 400 },
			{ coins = 150000, samples = 50, value = 1000 },
			{ coins = 500000, samples = 150, value = 2500 },
		},
	},
	{
		id = "lodge",
		name = "Trophy Lodge",
		gives = "% coins from waves",
		base = 100,
		levels = {
			{ coins = 1500, samples = 0, value = 110 },
			{ coins = 8000, samples = 0, value = 120 },
			{ coins = 40000, samples = 15, value = 130 },
			{ coins = 180000, samples = 60, value = 140 },
			{ coins = 600000, samples = 200, value = 150 },
		},
	},
	{
		id = "den",
		name = "Titan's Den",
		gives = "% of the Titan's stats in waves",
		base = 100,
		levels = {
			{ coins = 3000, samples = 0, value = 104 },
			{ coins = 15000, samples = 5, value = 108 },
			{ coins = 60000, samples = 25, value = 112 },
			{ coins = 250000, samples = 80, value = 116 },
			{ coins = 800000, samples = 250, value = 120 },
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

function StationConfig.coat(id: string): Coat?
	return find(StationConfig.COATS, id)
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
