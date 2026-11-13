--!strict
-- Game 7 "Animal Stations" data (decision 0019): stats, rarities, animals, eggs and stations.
-- Draft values for the foundation; balance comes later. Pure data, no Roblox APIs.

local StationConfig = {}

export type Stat = "speed" | "strength" | "swim" | "smarts"
export type Stats = { speed: number, strength: number, swim: number, smarts: number }
export type Animal = { id: string, name: string, rarity: string, stats: Stats }
export type Odds = { id: string, bp: number } -- bp: basis points, an egg's odds sum to 10000
export type Egg = { id: string, name: string, price: number, odds: { Odds } }
export type Station = { id: string, name: string, stat: Stat, coinsPerSec: number }

StationConfig.STATS = { "speed", "strength", "swim", "smarts" } :: { Stat }
StationConfig.STAT_MIN, StationConfig.STAT_MAX = 1, 100
-- A hatched animal's stats are its species base x (100 +/- VARIANCE)%, so two cheetahs differ a little.
StationConfig.VARIANCE = 10

StationConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

-- Base stats: one strong stat per animal, so each has a clear best station.
StationConfig.ANIMALS = {
	{ id = "bunny", name = "Bunny", rarity = "common", stats = { speed = 40, strength = 10, swim = 5, smarts = 15 } },
	{ id = "duck", name = "Duck", rarity = "common", stats = { speed = 10, strength = 8, swim = 40, smarts = 12 } },
	{ id = "pig", name = "Pig", rarity = "common", stats = { speed = 8, strength = 38, swim = 10, smarts = 20 } },
	{ id = "mouse", name = "Mouse", rarity = "common", stats = { speed = 20, strength = 3, swim = 5, smarts = 38 } },
	{ id = "fox", name = "Fox", rarity = "uncommon", stats = { speed = 60, strength = 20, swim = 10, smarts = 35 } },
	{
		id = "otter",
		name = "Otter",
		rarity = "uncommon",
		stats = { speed = 25, strength = 15, swim = 62, smarts = 30 },
	},
	{ id = "bear", name = "Bear", rarity = "rare", stats = { speed = 30, strength = 75, swim = 35, smarts = 20 } },
	{ id = "owl", name = "Owl", rarity = "rare", stats = { speed = 35, strength = 10, swim = 5, smarts = 78 } },
	{
		id = "dolphin",
		name = "Dolphin",
		rarity = "epic",
		stats = { speed = 30, strength = 30, swim = 90, smarts = 60 },
	},
	{
		id = "gorilla",
		name = "Gorilla",
		rarity = "epic",
		stats = { speed = 25, strength = 90, swim = 10, smarts = 45 },
	},
	{
		id = "cheetah",
		name = "Cheetah",
		rarity = "legendary",
		stats = { speed = 95, strength = 30, swim = 10, smarts = 25 },
	},
} :: { Animal }

StationConfig.EGGS = {
	{
		id = "meadow",
		name = "Meadow Egg",
		price = 100,
		odds = {
			{ id = "bunny", bp = 3000 },
			{ id = "duck", bp = 2500 },
			{ id = "pig", bp = 2000 },
			{ id = "mouse", bp = 1500 },
			{ id = "fox", bp = 600 },
			{ id = "otter", bp = 400 },
		},
	},
	{
		id = "safari",
		name = "Safari Egg",
		price = 2500,
		odds = {
			{ id = "fox", bp = 3200 },
			{ id = "otter", bp = 3000 },
			{ id = "bear", bp = 1800 },
			{ id = "owl", bp = 1500 },
			{ id = "dolphin", bp = 250 },
			{ id = "gorilla", bp = 200 },
			{ id = "cheetah", bp = 50 },
		},
	},
} :: { Egg }

-- coinsPerSec: what an animal with stat 100 earns there. Lower stats earn on a curve (StationRules.rate).
StationConfig.STATIONS = {
	{ id = "track", name = "Speed Track", stat = "speed", coinsPerSec = 50 },
	{ id = "gym", name = "Strength Gym", stat = "strength", coinsPerSec = 50 },
	{ id = "pool", name = "Swim Pool", stat = "swim", coinsPerSec = 50 },
	{ id = "library", name = "Puzzle Library", stat = "smarts", coinsPerSec = 50 },
} :: { Station }

local function find<T>(list: { T }, id: string): T?
	for _, v in list do
		if (v :: any).id == id then
			return v
		end
	end
	return nil
end

function StationConfig.animal(id: string): Animal?
	return find(StationConfig.ANIMALS, id)
end

function StationConfig.egg(id: string): Egg?
	return find(StationConfig.EGGS, id)
end

function StationConfig.station(id: string): Station?
	return find(StationConfig.STATIONS, id)
end

return StationConfig
