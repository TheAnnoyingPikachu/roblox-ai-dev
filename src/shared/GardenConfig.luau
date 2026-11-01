--!strict
-- Egg Garden data (GDD sections C to H, S and T, decisions 0008 and 0012): eggs, species, odds,
-- mutations, sizes, weather tables, costs, cosmetics, quests, Splash Dash and the saved profile
-- type. Data only, plus seven lookups. The server rolls from and the client's ODDS panel reads
-- these same tables.

local MetaRules = require("./MetaRules")

local GardenConfig = {}

export type Odds = { id: string, bp: number }
export type Stock = { chance: number, min: number, max: number } -- chance in percent
export type Egg = {
	id: string,
	name: string,
	price: number?, -- nil: not sold (starter)
	grow: number, -- seconds
	level: number, -- unlock level (starter 1)
	stock: Stock?, -- nil: always in stock, unlimited (meadow); unused for starter
	odds: { Odds }, -- species, sums to 10000
	top: string?, -- Lucky Meter species. A sold egg must have top and meter: rollSpecies gives odds[1] without one
	meter: number?,
	xp: number,
	mutation: string?, -- fixed: always this mutation, no draw, weather ignored (celestial)
}
export type Cry = { id: number, pitch: number } -- Creator Store audio asset id (registered first) and PlaybackSpeed
export type Species = { id: string, name: string, rarity: string, rate: number, cry: Cry? } -- cry nil: the client is silent
export type Mutation = { id: string, name: string, mult: number }
export type Size = { id: string, name: string, mult: number, scale: number, bp: number }
export type Weather = { id: string, name: string, mutation: { Odds } } -- MUTATIONS order without egg-only ones, sums to 10000

export type Bed = { egg: string, planted: number, ready: number, waters: number, helps: number, lastWater: number }
export type Creature = { id: number, s: string, m: string, z: string, placed: number, fav: boolean } -- placed 0 = storage
export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	lastSeen: number,
	unbanked: number,
	nextId: number,
	bedCount: number,
	penSlots: number,
	beds: { Bed },
	creatures: { Creature },
	pity: { [string]: number },
	index: { string },
	stock: { w: number, bought: { [string]: number } },
	hatches: number,
	waters: number,
	likes: number,
	gate: string,
	fence: string,
	can: string,
	owned: { [string]: boolean },
	helped: { day: number, count: number },
	liked: { day: number, ids: { number } },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
	prizeEggs: { [string]: number }, -- egg id -> count, v2; only counts >= 1
	dash: { day: number, prizes: number, coins: number }, -- v2; day -1 until the first reward
}

export type Spot = { x: number, y: number, z: number }
export type Obstacle = {
	kind: string, -- "sweeper" | "ball" | "pendulum" | "platform"
	model: string, -- architecture section 9
	at: Spot, -- sweeper hub; ball and platform path centre; pendulum hinge
	period: number, -- seconds per cycle
	phase: number, -- 0..1, fraction of a cycle
	size: number, -- sweeper arm length; ball or bob radius; platform half width
	reach: number, -- ball and platform travel either side of `at`; pendulum rod length; 0 for a sweeper
	axis: string?, -- "x" | "z": direction of ball, platform and pendulum travel
	lift: number?, -- ball bounce height
	knock: number, -- velocity on a hit; 0 for a platform
}
export type Deck = { x1: number, x2: number, z1: number, z2: number } -- walked top at start.y
export type DashConfig = {
	name: string,
	minPlayers: number,
	maxPlayers: number,
	countdown: number,
	starting: number,
	limit: number,
	grace: number,
	prizeEgg: string,
	prizesPerDay: number,
	coinsBase: number,
	coinsMinutes: number,
	coinsPerDay: number,
	fellY: number,
	zone: { radius: number, height: number },
	minFinish: number,
	maxSpeed: number,
	slack: number,
	maxStrikes: number,
	settle: number, -- seconds after a server teleport with no checks: the client's old position can still arrive
	knockMax: number,
	swing: number, -- pendulum amplitude in degrees
	start: Spot,
	checkpoints: { Spot }, -- the last is the finish
	decks: { Deck }, -- in course order; Lily Hop has no deck, its platforms go between the last two
	obstacles: { Obstacle },
}

local function odds(list: { any }): { Odds }
	local out: { Odds } = {}
	for i = 1, #list, 2 do
		table.insert(out, { id = list[i], bp = list[i + 1] })
	end
	return out
end

-- The stock index i of an egg is its position - 1 (forest 2, sunset 3, moon 4, star 5, celestial 6,
-- aurora 7), so a new egg goes last or every later egg's stock changes. Odds: GDD U2, decision 0014.
local EGGS: { Egg } = {
	{ id = "starter", name = "Starter Egg", grow = 8, level = 1, odds = odds({ "pup", 10000 }), xp = 10 },
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 50,
		grow = 30,
		level = 1,
		odds = odds({ "bunny", 5800, "frog", 2400, "duck", 1100, "pup", 500, "lamb", 100, "cat", 100 }),
		top = "cat",
		meter = 50,
		xp = 10,
	},
	{
		id = "forest",
		name = "Forest Egg",
		price = 400,
		grow = 180,
		level = 2,
		stock = { chance = 100, min = 2, max = 4 },
		odds = odds({ "frog", 3000, "pup", 3000, "lamb", 1500, "cat", 1700, "owl", 500, "hedgehog", 300 }),
		top = "hedgehog",
		meter = 30,
		xp = 25,
	},
	{
		id = "sunset",
		name = "Sunset Egg",
		price = 3000,
		grow = 900,
		level = 5,
		stock = { chance = 60, min = 1, max = 2 },
		odds = odds({
			"cat",
			3500,
			"owl",
			2500,
			"hedgehog",
			1500,
			"fox",
			1700,
			"turtle",
			300,
			"deer",
			300,
			"panda",
			200,
		}),
		top = "panda",
		meter = 40,
		xp = 60,
	},
	{
		id = "moon",
		name = "Moon Egg",
		price = 25000,
		grow = 3600,
		level = 10,
		stock = { chance = 30, min = 1, max = 1 },
		odds = odds({
			"fox",
			4000,
			"turtle",
			2500,
			"deer",
			1500,
			"panda",
			1000,
			"lion",
			600,
			"unicorn",
			350,
			"dragon",
			50,
		}),
		top = "dragon",
		meter = 100,
		xp = 150,
	},
	{
		id = "star",
		name = "Star Egg",
		price = 200000,
		grow = 14400,
		level = 18,
		stock = { chance = 10, min = 1, max = 1 },
		odds = odds({ "turtle", 3000, "panda", 2500, "lion", 2500, "unicorn", 1500, "dragon", 400, "phoenix", 100 }),
		top = "phoenix",
		meter = 25,
		xp = 400,
	},
	{
		-- Every Legendary and Mythic species (decision 0014 amends 0012's lion/dragon list).
		id = "celestial",
		name = "Celestial Egg",
		price = 1_000_000_000,
		grow = 28800,
		level = 25,
		stock = { chance = 5, min = 1, max = 1 },
		odds = odds({ "lion", 6000, "unicorn", 2500, "dragon", 1200, "phoenix", 300 }),
		top = "phoenix",
		meter = 10,
		xp = 1000,
		mutation = "celestial",
	},
	{
		-- GDD U3: the only source of whale, kirin and axolotl; weather mutation roll, nothing fixed.
		id = "aurora",
		name = "Aurora Egg",
		price = 5_000_000_000,
		grow = 43200,
		level = 32,
		stock = { chance = 3, min = 1, max = 1 },
		odds = odds({ "dragon", 3500, "phoenix", 3000, "whale", 2000, "kirin", 1200, "axolotl", 300 }),
		top = "axolotl",
		meter = 20,
		xp = 3000,
	},
}
GardenConfig.EGGS = EGGS

-- GDD U1 order: rarity, then rate. `cry` stays nil until the clip's row is in docs/assets/register.md
-- (rule 9); GARDEN-025 registers the clips and fills `cry = { id = <asset id>, pitch = <PlaybackSpeed> }`.
local SPECIES: { Species } = {
	{ id = "bunny", name = "Sprout Bunny", rarity = "common", rate = 1 },
	{ id = "frog", name = "Toadstool Frog", rarity = "common", rate = 2 },
	{ id = "duck", name = "Puddle Duckling", rarity = "common", rate = 3 },
	{ id = "pup", name = "Bumble Pup", rarity = "uncommon", rate = 5 },
	{ id = "lamb", name = "Clover Lamb", rarity = "uncommon", rate = 8 },
	{ id = "cat", name = "Berry Cat", rarity = "uncommon", rate = 12 },
	{ id = "owl", name = "Pumpkin Owl", rarity = "rare", rate = 30 },
	{ id = "hedgehog", name = "Acorn Hedgehog", rarity = "rare", rate = 45 },
	{ id = "fox", name = "Cactus Fox", rarity = "rare", rate = 70 },
	{ id = "turtle", name = "Lotus Turtle", rarity = "epic", rate = 180 },
	{ id = "deer", name = "Blossom Fawn", rarity = "epic", rate = 250 },
	{ id = "panda", name = "Bamboo Panda", rarity = "epic", rate = 350 },
	{ id = "lion", name = "Sunflower Lion", rarity = "legendary", rate = 500 },
	{ id = "unicorn", name = "Daisy Unicorn", rarity = "legendary", rate = 800 },
	{ id = "dragon", name = "Moonblossom Dragon", rarity = "mythic", rate = 1500 },
	{ id = "phoenix", name = "Ember Phoenix", rarity = "mythic", rate = 2500 },
	{ id = "whale", name = "Aurora Whale", rarity = "divine", rate = 5000 },
	{ id = "kirin", name = "Nimbus Kirin", rarity = "divine", rate = 7500 },
	{ id = "axolotl", name = "Stardust Axolotl", rarity = "secret", rate = 25000 },
}
GardenConfig.SPECIES = SPECIES

-- Appended only, so no rarityIndex moves (HatchRules LEGENDARY = 5 and RARE = 3 stay valid).
GardenConfig.RARITIES = {
	{ id = "common", name = "Common", colour = { 180, 180, 180 } },
	{ id = "uncommon", name = "Uncommon", colour = { 90, 200, 90 } },
	{ id = "rare", name = "Rare", colour = { 70, 140, 255 } },
	{ id = "epic", name = "Epic", colour = { 170, 80, 255 } },
	{ id = "legendary", name = "Legendary", colour = { 255, 200, 40 } },
	{ id = "mythic", name = "Mythic", colour = { 255, 110, 200 } },
	{ id = "divine", name = "Divine", colour = { 90, 230, 230 } },
	{ id = "secret", name = "Secret", colour = { 60, 55, 85 } }, -- dark on purpose: the client strokes its text (U1)
}
GardenConfig.RARE = 3 -- RARITIES index of "rare": rareHatches counts rarity index >= 3

local MUTATIONS: { Mutation } = {
	{ id = "normal", name = "Normal", mult = 1 },
	{ id = "golden", name = "Golden", mult = 3 },
	{ id = "moonlit", name = "Moonlit", mult = 5 },
	{ id = "rainbow", name = "Rainbow", mult = 10 },
	{ id = "celestial", name = "Celestial", mult = 20 }, -- egg-only: in no weather table
}
GardenConfig.MUTATIONS = MUTATIONS

local SIZES: { Size } = {
	{ id = "normal", name = "Normal", mult = 1.0, scale = 1.0, bp = 8000 },
	{ id = "big", name = "Big", mult = 1.5, scale = 1.4, bp = 1700 },
	{ id = "huge", name = "Huge", mult = 2.5, scale = 2.0, bp = 300 },
}
GardenConfig.SIZES = SIZES

local WEATHERS: { Weather } = {
	{ id = "clear", name = "Clear", mutation = odds({ "normal", 9790, "golden", 200, "moonlit", 0, "rainbow", 10 }) },
	{
		id = "sunbeam",
		name = "Sunbeam",
		mutation = odds({ "normal", 7450, "golden", 2500, "moonlit", 0, "rainbow", 50 }),
	},
	{
		id = "moonfall",
		name = "Moonfall",
		mutation = odds({ "normal", 7750, "golden", 200, "moonlit", 2000, "rainbow", 50 }),
	},
	{
		id = "shower",
		name = "Rainbow Shower",
		mutation = odds({ "normal", 8500, "golden", 500, "moonlit", 0, "rainbow", 1000 }),
	},
}
GardenConfig.WEATHERS = WEATHERS

GardenConfig.WEATHER_ODDS = {
	weekday = odds({ "clear", 5500, "sunbeam", 2500, "moonfall", 1500, "shower", 500 }),
	weekend = odds({ "clear", 3500, "sunbeam", 3500, "moonfall", 2000, "shower", 1000 }),
}

GardenConfig.BED_COSTS = {
	[4] = 500,
	[5] = 2_000,
	[6] = 8_000,
	[7] = 25_000,
	[8] = 75_000,
	[9] = 200_000,
	[10] = 500_000,
	[11] = 1_200_000,
	[12] = 3_000_000,
} :: { [number]: number }
GardenConfig.BEDS = { start = 3, max = 12 }
GardenConfig.PEN = { start = 6, max = 20, first = 300 } -- slot cost first * 2^(penSlots - 6)
GardenConfig.STORAGE = 60
GardenConfig.WATER = { cooldown = 60, cut = 0.05, owner = 5, helpers = 3, maxCut = 0.4 }
GardenConfig.XP = { index = 50, ownWater = 3, helperWater = 15, helperCap = 20 }
GardenConfig.INDEX_BONUS = 0.02
GardenConfig.INDEX_SIZE = 80 -- count of indexable pairs: 19 * 4 + 4 celestial pairs (lion, unicorn, dragon, phoenix)
GardenConfig.OFFLINE = { rate = 0.5, cap = 28_800 }
-- 0008 amendment 2026-10-26: release never returns its egg price (buy, hatch, release <= 60% of it).
GardenConfig.RELEASE_SECONDS = 6
GardenConfig.PAD = { radius = 4.5, height = 6 }
GardenConfig.RANGE = { cart = 25, bed = 12 }
GardenConfig.RESTOCK = 300
GardenConfig.WEATHER_WINDOW = 600
GardenConfig.WEATHER_ACTIVE = 300
GardenConfig.SEEDS = { stock = 9001, weather = 4242 }
GardenConfig.LIKES = { perDay = 30 }
GardenConfig.MAX_COINS = 1e15
GardenConfig.ADMINS = { [96807256] = true } :: { [number]: boolean } -- SHANNON (genetheman); decision 0013
GardenConfig.GATES = { "open", "friends", "closed" }

local function cosmetic(
	slot: string,
	id: string,
	name: string,
	colours: { { number } },
	unlock: { [string]: number }
): MetaRules.Cosmetic
	return {
		id = id,
		name = name,
		slot = slot,
		colours = colours,
		level = unlock.level,
		index = unlock.index,
		price = unlock.price,
	}
end

-- H4. Coin amounts are prices (bought with buyCosmetic); a can's first colour is its splash.
local COSMETICS: { MetaRules.Cosmetic } = {
	cosmetic("fence", "picket", "White Picket", { { 255, 255, 255 } }, { level = 1 }),
	cosmetic("fence", "bamboo", "Bamboo", { { 200, 180, 100 }, { 120, 150, 60 } }, { level = 3 }),
	cosmetic("fence", "stone", "Cobble Wall", { { 150, 150, 150 }, { 110, 105, 100 } }, { level = 6 }),
	cosmetic("fence", "hedge", "Hedge", { { 70, 140, 60 }, { 50, 110, 45 } }, { level = 10 }),
	cosmetic("fence", "crystal", "Crystal", { { 170, 220, 255 }, { 120, 180, 255 } }, { level = 16 }),
	cosmetic("fence", "golden", "Golden", { { 255, 200, 60 }, { 200, 140, 20 } }, { index = 20 }),
	cosmetic("fence", "candy", "Candy Cane", { { 255, 255, 255 }, { 230, 40, 50 } }, { price = 1_000_000 }),
	cosmetic(
		"fence",
		"rainbow",
		"Rainbow",
		{ { 255, 60, 60 }, { 255, 220, 60 }, { 60, 255, 120 }, { 60, 160, 255 }, { 200, 80, 255 } },
		{ price = 1_000_000_000 }
	),
	cosmetic("can", "tin", "Tin Can", { { 120, 200, 255 }, { 180, 185, 190 } }, { level = 1 }),
	cosmetic("can", "ducky", "Rubber Ducky", { { 255, 220, 60 }, { 255, 140, 0 } }, { level = 4 }),
	cosmetic("can", "flower", "Flower Pot", { { 255, 140, 180 }, { 200, 110, 70 } }, { level = 8 }),
	cosmetic("can", "moon", "Moon Jar", { { 200, 220, 255 }, { 40, 50, 110 } }, { level = 14 }),
	cosmetic("can", "star", "Star Pitcher", { { 255, 240, 170 }, { 255, 200, 60 } }, { price = 10_000_000 }),
	cosmetic(
		"can",
		"galaxy",
		"Galaxy",
		{ { 160, 60, 255 }, { 40, 0, 90 }, { 255, 255, 255 } },
		{ price = 10_000_000_000 }
	),
}
GardenConfig.COSMETICS = COSMETICS

-- H5: reward is the base; the paid amount is GardenProgress.scaled(base, minutes).
local QUESTS: { MetaRules.Quest } = {
	{ id = "hatch5", label = "Hatch 5 eggs", stat = "hatches", goal = 5, reward = 100, minutes = 3 },
	{ id = "hatch15", label = "Hatch 15 eggs", stat = "hatches", goal = 15, reward = 150, minutes = 6 },
	{ id = "water10", label = "Water 10 eggs", stat = "waters", goal = 10, reward = 100, minutes = 3 },
	{ id = "water25", label = "Water 25 eggs", stat = "waters", goal = 25, reward = 150, minutes = 6 },
	{ id = "collect50", label = "Collect 50 coin pads", stat = "collects", goal = 50, reward = 100, minutes = 3 },
	{ id = "rare1", label = "Hatch a Rare or better", stat = "rareHatches", goal = 1, reward = 150, minutes = 5 },
	{ id = "mutant1", label = "Hatch a mutated creature", stat = "mutants", goal = 1, reward = 200, minutes = 8 },
	{ id = "release3", label = "Release 3 creatures", stat = "releases", goal = 3, reward = 100, minutes = 3 },
}
GardenConfig.QUESTS = QUESTS

GardenConfig.DAILY = { 50, 75, 100, 125, 150, 200, 400 }
GardenConfig.DAILY_MINUTES = { 2, 3, 4, 5, 6, 8, 15 }
GardenConfig.WEEKLY = { days = 5, reward = 500, minutes = 30 }
GardenConfig.PRIZE_STORE = 1_000_000 -- sanitise limit per egg in prizeEggs

local function obstacle(
	kind: string,
	at: { number },
	period: number,
	phase: number,
	size: number,
	reach: number,
	axis: string?,
	lift: number?,
	knock: number
): Obstacle
	return {
		kind = kind,
		model = `dash_{kind}`,
		at = { x = at[1], y = at[2], z = at[3] },
		period = period,
		phase = phase,
		size = size,
		reach = reach,
		axis = axis,
		lift = lift,
		knock = knock,
	}
end

-- GDD T and decision 0012. The obstacles are first-pass values, tuned at the greybox gate.
local DASH: DashConfig = {
	name = "Splash Dash",
	minPlayers = 3,
	maxPlayers = 6,
	countdown = 15,
	starting = 5,
	limit = 120,
	grace = 20,
	prizeEgg = "moon",
	prizesPerDay = 3,
	coinsBase = 100,
	coinsMinutes = 1,
	coinsPerDay = 6,
	fellY = 125,
	zone = { radius = 16, height = 14 },
	minFinish = 28,
	maxSpeed = 95,
	slack = 12,
	maxStrikes = 3,
	settle = 1,
	knockMax = 70,
	swing = 50,
	start = { x = -120, y = 140, z = 300 },
	checkpoints = {
		{ x = -20, y = 140, z = 300 },
		{ x = 100, y = 140, z = 300 },
		{ x = 100, y = 140, z = 400 },
		{ x = -20, y = 140, z = 400 },
		{ x = -120, y = 140, z = 400 },
	},
	decks = {
		{ x1 = -140, x2 = -100, z1 = 280, z2 = 320 }, -- start
		{ x1 = -100, x2 = -20, z1 = 278, z2 = 322 }, -- Sweeper Green
		{ x1 = -20, x2 = 112, z1 = 288, z2 = 312 }, -- Ball Alley, to CP2
		{ x1 = 95, x2 = 105, z1 = 312, z2 = 388 }, -- Pendulum Bridge
		{ x1 = 88, x2 = 112, z1 = 388, z2 = 412 }, -- CP3
		{ x1 = -132, x2 = -8, z1 = 388, z2 = 412 }, -- CP4, Last Sprint and the finish
	},
	obstacles = {
		obstacle("sweeper", { -85, 140, 300 }, 6, 0, 20, 0, nil, nil, 45),
		obstacle("sweeper", { -45, 140, 300 }, 5, 0.5, 20, 0, nil, nil, 45),
		obstacle("ball", { 10, 140, 300 }, 4, 0, 5, 7, "z", 4, 55),
		obstacle("ball", { 35, 140, 300 }, 4, 0.25, 5, 7, "z", 4, 55),
		obstacle("ball", { 60, 140, 300 }, 4, 0.5, 5, 7, "z", 4, 55),
		obstacle("ball", { 85, 140, 300 }, 4, 0.75, 5, 7, "z", 4, 55),
		obstacle("pendulum", { 100, 170, 325 }, 5, 0, 4, 26, "x", nil, 65),
		obstacle("pendulum", { 100, 170, 350 }, 5, 0.33, 4, 26, "x", nil, 65),
		obstacle("pendulum", { 100, 170, 375 }, 5, 0.66, 4, 26, "x", nil, 65),
		obstacle("platform", { 76, 140, 400 }, 7, 0, 6, 8, "z", nil, 0),
		obstacle("platform", { 58, 140, 400 }, 7, 0.5, 6, 8, "z", nil, 0),
		obstacle("platform", { 40, 140, 400 }, 7, 0, 6, 8, "z", nil, 0),
		obstacle("platform", { 22, 140, 400 }, 7, 0.5, 6, 8, "z", nil, 0),
		obstacle("platform", { 4, 140, 400 }, 7, 0, 6, 8, "z", nil, 0),
		obstacle("sweeper", { -70, 140, 400 }, 5, 0.25, 12, 0, nil, nil, 45),
	},
}
GardenConfig.DASH = DASH

local function find<T>(list: { T }, id: string): T?
	for _, item in list do
		if (item :: any).id == id then
			return item
		end
	end
	return nil
end

function GardenConfig.egg(id: string): Egg?
	return find(EGGS, id)
end

function GardenConfig.species(id: string): Species?
	return find(SPECIES, id)
end

function GardenConfig.mutation(id: string): Mutation?
	return find(MUTATIONS, id)
end

function GardenConfig.size(id: string): Size?
	return find(SIZES, id)
end

function GardenConfig.rarityIndex(speciesId: string): number
	local s = find(SPECIES, speciesId)
	if s == nil then
		return 0
	end
	for i, r in GardenConfig.RARITIES do
		if r.id == s.rarity then
			return i
		end
	end
	return 0
end

-- The egg whose `mutation` is this id; nil for weather mutations.
function GardenConfig.fixedBy(mutationId: string): Egg?
	for _, egg in EGGS do
		if egg.mutation == mutationId then
			return egg
		end
	end
	return nil
end

-- Both known; an egg-only mutation needs a species from that egg's odds. The one definition of
-- what the Index and saved creatures may hold, and of INDEX_SIZE.
function GardenConfig.indexable(speciesId: string, mutationId: string): boolean
	if find(SPECIES, speciesId) == nil or find(MUTATIONS, mutationId) == nil then
		return false
	end
	local egg = GardenConfig.fixedBy(mutationId)
	return egg == nil or find(egg.odds, speciesId) ~= nil
end

return GardenConfig
