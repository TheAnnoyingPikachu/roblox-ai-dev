--!strict
-- Egg Garden data (GDD sections C to H, decision 0008): eggs, species, odds, mutations, sizes,
-- weather tables, costs, cosmetics, quests and the saved profile type. Data only, plus five
-- lookups. The server rolls from and the client's ODDS panel reads these same tables.

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
	top: string?, -- Lucky Meter species
	meter: number?,
	xp: number,
}
export type Species = { id: string, name: string, rarity: string, rate: number }
export type Mutation = { id: string, name: string, mult: number }
export type Size = { id: string, name: string, mult: number, scale: number, bp: number }
export type Weather = { id: string, name: string, mutation: { Odds } } -- in MUTATIONS order, sums to 10000

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
}

local function odds(list: { any }): { Odds }
	local out: { Odds } = {}
	for i = 1, #list, 2 do
		table.insert(out, { id = list[i], bp = list[i + 1] })
	end
	return out
end

-- The stock index i of an egg is its position - 1 (forest 2, sunset 3, moon 4, star 5).
local EGGS: { Egg } = {
	{ id = "starter", name = "Starter Egg", grow = 8, level = 1, odds = odds({ "pup", 10000 }), xp = 10 },
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 50,
		grow = 30,
		level = 1,
		odds = odds({ "bunny", 6000, "frog", 3000, "pup", 900, "cat", 100 }),
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
		odds = odds({ "frog", 4000, "pup", 3500, "cat", 2000, "owl", 500 }),
		top = "owl",
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
		odds = odds({ "cat", 4500, "owl", 3500, "fox", 1700, "turtle", 300 }),
		top = "turtle",
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
		odds = odds({ "fox", 5000, "turtle", 4000, "lion", 950, "dragon", 50 }),
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
		odds = odds({ "turtle", 5500, "lion", 4000, "dragon", 500 }),
		top = "dragon",
		meter = 25,
		xp = 400,
	},
}
GardenConfig.EGGS = EGGS

local SPECIES: { Species } = {
	{ id = "bunny", name = "Sprout Bunny", rarity = "common", rate = 1 },
	{ id = "frog", name = "Toadstool Frog", rarity = "common", rate = 2 },
	{ id = "pup", name = "Bumble Pup", rarity = "uncommon", rate = 5 },
	{ id = "cat", name = "Berry Cat", rarity = "uncommon", rate = 12 },
	{ id = "owl", name = "Pumpkin Owl", rarity = "rare", rate = 30 },
	{ id = "fox", name = "Cactus Fox", rarity = "rare", rate = 70 },
	{ id = "turtle", name = "Lotus Turtle", rarity = "epic", rate = 180 },
	{ id = "lion", name = "Sunflower Lion", rarity = "legendary", rate = 500 },
	{ id = "dragon", name = "Moonblossom Dragon", rarity = "mythic", rate = 1500 },
}
GardenConfig.SPECIES = SPECIES

GardenConfig.RARITIES = {
	{ id = "common", name = "Common", colour = { 180, 180, 180 } },
	{ id = "uncommon", name = "Uncommon", colour = { 90, 200, 90 } },
	{ id = "rare", name = "Rare", colour = { 70, 140, 255 } },
	{ id = "epic", name = "Epic", colour = { 170, 80, 255 } },
	{ id = "legendary", name = "Legendary", colour = { 255, 200, 40 } },
	{ id = "mythic", name = "Mythic", colour = { 255, 110, 200 } },
}
GardenConfig.RARE = 3 -- RARITIES index of "rare": rareHatches counts rarity index >= 3

local MUTATIONS: { Mutation } = {
	{ id = "normal", name = "Normal", mult = 1 },
	{ id = "golden", name = "Golden", mult = 3 },
	{ id = "moonlit", name = "Moonlit", mult = 5 },
	{ id = "rainbow", name = "Rainbow", mult = 10 },
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
GardenConfig.INDEX_SIZE = 36
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

return GardenConfig
