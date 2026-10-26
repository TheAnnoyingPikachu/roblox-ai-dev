--!strict
-- Neon Spire data (GDD sections C to J, decision 0009): departments, floor costs, levels, plaza
-- items, Market events, company names, cosmetics, quests, the Request contract and the saved
-- profile type. Data only, plus three lookups. No Roblox APIs.

local MetaRules = require("./MetaRules")

local SpireConfig = {}

export type Dept = {
	id: string, -- data fusion ad synth drone quantum orbital
	name: string, -- "Data Farm"
	module: string, -- "Server Rack"
	income: number, -- ¢/s per module at L1 (0 for fusion)
	draw: number, -- power per module (0 for fusion)
	cost: number, -- L1 module cost
	unlock: number, -- lowest floor number it can go on
	tier: number, -- XP tier: data 1, fusion 1, ad 2, synth 3, drone 4, quantum 5, orbital 6
}
export type PlazaItem = {
	id: string, -- lowercase letters only (Request pattern %l+)
	name: string,
	cost: number,
	hype: number, -- 0 for decor
	w: number, -- cells along x at r = 0
	d: number, -- cells along y at r = 0
	max: number?, -- per-plaza count limit (hype items); nil for decor
	floors: number?, -- hype items: unlocked when #p.floors >= floors
	level: number?, -- decor: unlocked when level >= level
	decor: boolean,
}
export type Event = { id: string, name: string }
export type Odds = { id: string, bp: number } -- basis points, a row sums to 10000
export type ActionSpec = { pattern: string?, profile: boolean } -- pattern nil: takes no arg; profile false: router-only (lift, home)
export type Company = { p: number, s: number, glyph: number, colour: number, trim: number }

export type Floor = { d: string, m: { number }, s: { number } } -- dept id; 4 slot levels 0..5 (0 empty); 4 credits spent per slot
export type Item = { u: number, id: string, x: number, y: number, r: number, paid: number }
export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number, -- credits (¢); named coins because MetaRules pays rewards into `coins`
	lifetimeEarned: number,
	runEarned: number,
	lastSeen: number,
	floors: { Floor }, -- floors[1] is always { d = "lobby", m = {0,0,0,0}, s = {0,0,0,0} }
	plaza: { nextUid: number, items: { Item } },
	shares: number,
	ipos: number,
	hotCaught: number,
	endorsements: number, -- received
	bestFloors: number, -- highest #floors ever
	gate: string,
	company: Company,
	skin: string, -- cosmetic slots (MetaRules reads them at the top level)
	crown: string,
	lobby: string,
	tiles: string,
	trail: string,
	owned: { [string]: boolean },
	endorsed: { day: number, ids: { number } }, -- given today
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}
export type PublicFloor = { d: string, m: { number } }
export type PublicItem = { u: number, id: string, x: number, y: number, r: number }
export type TowerState = {
	floors: { PublicFloor },
	items: { PublicItem },
	company: Company,
	skin: string,
	crown: string,
	lobby: string,
	tiles: string,
	trail: string,
	gate: string,
	hype: number,
	endorsements: number,
	shares: number,
	level: number,
}

SpireConfig.SCHEMA_VERSION = 1
SpireConfig.LOBBY = "lobby"
SpireConfig.MAX_FLOORS = 30
SpireConfig.SLOTS = 4
SpireConfig.START = { coins = 100, floors = 2 }
SpireConfig.MAX_COINS = 1e15
SpireConfig.MAX_EARNED = 1e18

local DEPTS: { Dept } = {
	{ id = "data", name = "Data Farm", module = "Server Rack", income = 1, draw = 1, cost = 15, unlock = 1, tier = 1 },
	{
		id = "fusion",
		name = "Fusion Core",
		module = "Fusion Cell",
		income = 0,
		draw = 0,
		cost = 150,
		unlock = 3,
		tier = 1,
	},
	{
		id = "ad",
		name = "Holo Ad Agency",
		module = "Holo Projector",
		income = 6,
		draw = 2,
		cost = 600,
		unlock = 5,
		tier = 2,
	},
	{
		id = "synth",
		name = "Synth Lab",
		module = "Bio-Printer",
		income = 40,
		draw = 4,
		cost = 8_000,
		unlock = 8,
		tier = 3,
	},
	{
		id = "drone",
		name = "Drone Port",
		module = "Courier Drone",
		income = 250,
		draw = 6,
		cost = 150_000,
		unlock = 12,
		tier = 4,
	},
	{
		id = "quantum",
		name = "Quantum Core",
		module = "Q-Mind",
		income = 1_600,
		draw = 10,
		cost = 3_000_000,
		unlock = 17,
		tier = 5,
	},
	{
		id = "orbital",
		name = "Orbital Uplink",
		module = "Uplink Dish",
		income = 10_000,
		draw = 16,
		cost = 60_000_000,
		unlock = 23,
		tier = 6,
	},
}
SpireConfig.DEPTS = DEPTS

-- GDD C2 (the table is the rule).
SpireConfig.FLOOR_COST = {
	[3] = 129,
	[4] = 277,
	[5] = 596,
	[6] = 1_280,
	[7] = 2_760,
	[8] = 5_930,
	[9] = 12_700,
	[10] = 27_400,
	[11] = 58_900,
	[12] = 127_000,
	[13] = 272_000,
	[14] = 585_000,
	[15] = 1_260_000,
	[16] = 2_710_000,
	[17] = 5_820_000,
	[18] = 12_500_000,
	[19] = 26_900_000,
	[20] = 57_800_000,
	[21] = 124_000_000,
	[22] = 267_000_000,
	[23] = 575_000_000,
	[24] = 1_240_000_000,
	[25] = 2_660_000_000,
	[26] = 5_710_000_000,
	[27] = 12_300_000_000,
	[28] = 26_400_000_000,
	[29] = 56_800_000_000,
	[30] = 122_000_000_000,
} :: { [number]: number }

SpireConfig.LV = { 1, 2, 4, 8, 16 }
SpireConfig.UP = { 2, 5, 12, 30 }
SpireConfig.FUSION_SUPPLY = { 8, 18, 32, 50, 75 }
SpireConfig.BASE_SUPPLY = 6
SpireConfig.AD = { boost = 0.25, neon = 0.5 }
SpireConfig.REFUND = 0.5
SpireConfig.PLAZA = { w = 12, d = 8, cell = 4, walkway = { 5, 6 }, maxItems = 60, maxDecor = 20 }
SpireConfig.HYPE = { perFloor = 10, cap = 200, crowdBase = 2, crowdPer = 5, crowdMax = 40 }

local function hypeItem(
	id: string,
	name: string,
	cost: number,
	hype: number,
	w: number,
	d: number,
	max: number,
	floors: number
): PlazaItem
	return { id = id, name = name, cost = cost, hype = hype, w = w, d = d, max = max, floors = floors, decor = false }
end

local function decorItem(id: string, name: string, cost: number, w: number, d: number, level: number): PlazaItem
	return { id = id, name = name, cost = cost, hype = 0, w = w, d = d, level = level, decor = true }
end

local ITEMS: { PlazaItem } = {
	hypeItem("bench", "Neon Bench", 100, 1, 1, 1, 12, 2),
	hypeItem("palm", "Holo Palm", 800, 2, 1, 1, 10, 3),
	hypeItem("vending", "Vending Bot", 6_000, 3, 1, 1, 8, 5),
	hypeItem("noodle", "Noodle Stall", 40_000, 5, 2, 1, 6, 7),
	hypeItem("arcade", "Arcade Kiosk", 300_000, 8, 2, 2, 4, 10),
	hypeItem("fountain", "Holo Fountain", 2_500_000, 12, 2, 2, 2, 13),
	hypeItem("maglev", "Maglev Stop", 20_000_000, 20, 3, 2, 1, 17),
	hypeItem("billboard", "Mega Billboard", 150_000_000, 25, 2, 1, 2, 21),
	hypeItem("idol", "Hologram Idol", 1_500_000_000, 40, 3, 3, 1, 25),
	decorItem("lamp", "Street Lamp", 150, 1, 1, 1),
	decorItem("bollard", "Bollard", 50, 1, 1, 1),
	decorItem("planter", "Planter", 300, 1, 1, 2),
	decorItem("arrow", "Neon Arrow", 500, 1, 1, 3),
	decorItem("puddle", "Puddle Tile", 100, 1, 1, 4),
	decorItem("trashbot", "Trash-Bot", 1_000, 1, 1, 6),
	decorItem("arch", "Cable Arch", 2_000, 2, 1, 8),
	decorItem("koi", "Holo Koi", 2_000, 2, 2, 10),
}
SpireConfig.ITEMS = ITEMS

SpireConfig.SHARES = { per = 0.10, max = 500, minFloors = 20, divisor = 10_000_000 }
SpireConfig.HOT = { minGap = 60, maxGap = 120, life = 45, seconds = 30, xp = 5, range = 12 }
SpireConfig.OFFLINE = { rate = 0.5, cap = 28_800 }
SpireConfig.MARKET = { window = 600, active = 300, seed = 7077, sale = 0.75 }

local EVENTS: { Event } = {
	{ id = "normal", name = "Normal" },
	{ id = "boom", name = "Data Boom" },
	{ id = "neon", name = "Neon Night" },
	{ id = "sale", name = "Flash Sale" },
}
SpireConfig.EVENTS = EVENTS

local EVENT_ODDS: { weekday: { Odds }, weekend: { Odds } } = {
	weekday = {
		{ id = "normal", bp = 5500 },
		{ id = "boom", bp = 2000 },
		{ id = "neon", bp = 1500 },
		{ id = "sale", bp = 1000 },
	},
	weekend = {
		{ id = "normal", bp = 3500 },
		{ id = "boom", bp = 2500 },
		{ id = "neon", bp = 2000 },
		{ id = "sale", bp = 2000 },
	},
}
SpireConfig.EVENT_ODDS = EVENT_ODDS

SpireConfig.NAMES = {
	prefixes = {
		"Neon",
		"Kuro",
		"Vanta",
		"Ion",
		"Hexa",
		"Nova",
		"Chroma",
		"Pulse",
		"Synth",
		"Arc",
		"Zen",
		"Echo",
		"Volt",
		"Lumen",
		"Onyx",
		"Cipher",
		"Flux",
		"Orbit",
		"Prism",
		"Quanta",
		"Riven",
		"Static",
		"Vector",
		"Zero",
	},
	suffixes = {
		"Dynamics",
		"Systems",
		"Industries",
		"Labs",
		"Works",
		"Corp",
		"Networks",
		"Holdings",
		"Robotics",
		"Media",
		"Logic",
		"Foundry",
		"Group",
		"Collective",
		"Sciences",
		"Interactive",
	},
}
SpireConfig.GLYPHS = 12

-- Art bible palette: Grid Cyan, Hot Magenta, Volt Violet, Sodium Amber, Acid Lime, Signal White,
-- then Coral and Ice.
local CYAN, MAGENTA, VIOLET, AMBER = { 0, 240, 255 }, { 255, 42, 109 }, { 123, 47, 255 }, { 255, 184, 0 }
local LIME, WHITE, CORAL, ICE = { 182, 255, 59 }, { 232, 246, 255 }, { 255, 107, 74 }, { 159, 216, 255 }
local STEEL, ASPHALT = { 28, 35, 51 }, { 11, 15, 26 }
SpireConfig.COLOURS = { CYAN, MAGENTA, VIOLET, AMBER, LIME, WHITE, CORAL, ICE }

SpireConfig.GATES = { "open", "friends", "closed" }
SpireConfig.ENDORSE = { perDay = 30 }
SpireConfig.XP = { module = 2, upgrade = 2, floor = 10, plaza = 5, hot = 5, endorse = 3, endorseCap = 10 }

local function cosmetic(
	slot: string,
	id: string,
	name: string,
	colours: { { number } },
	unlock: { [string]: number }
): MetaRules.Cosmetic
	return { id = id, name = name, slot = slot, colours = colours, level = unlock.level, price = unlock.price }
end

-- Decision 0009 table. Shares-unlocked ids have no MetaRules unlock; SHARE_UNLOCKS gates them.
local COSMETICS: { MetaRules.Cosmetic } = {
	cosmetic("skin", "glass", "Glass", { ICE, STEEL }, { level = 1 }),
	cosmetic("skin", "chrome", "Chrome", { WHITE, STEEL }, {}),
	cosmetic("skin", "carbon", "Carbon", { ASPHALT, CYAN }, {}),
	cosmetic("skin", "jade", "Jade Glass", { LIME, STEEL }, {}),
	cosmetic("skin", "prism", "Prism", { CYAN, MAGENTA, VIOLET, AMBER }, {}),
	cosmetic("crown", "antenna", "Antenna", { WHITE }, { level = 1 }),
	cosmetic("crown", "halo", "Halo Ring", { CYAN }, { level = 5 }),
	cosmetic("crown", "needle", "Spire Needle", { VIOLET, WHITE }, { level = 12 }),
	cosmetic("crown", "satellite", "Satellite Crown", { AMBER, WHITE }, {}),
	cosmetic("crown", "holoLogo", "Holo Logo", { MAGENTA, CYAN }, { price = 2_000_000 }),
	cosmetic("lobby", "marble", "Marble", { WHITE, STEEL }, { level = 1 }),
	cosmetic("lobby", "neonTile", "Neon Tile", { CYAN, ASPHALT }, { level = 3 }),
	cosmetic("lobby", "carbonFloor", "Carbon Floor", { ASPHALT, VIOLET }, { level = 10 }),
	cosmetic("lobby", "goldLobby", "Gold Lobby", { AMBER, WHITE }, { price = 50_000_000 }),
	cosmetic("tiles", "grid", "Grid", { CYAN, ASPHALT }, { level = 1 }),
	cosmetic("tiles", "hex", "Hex", { MAGENTA, ASPHALT }, { level = 4 }),
	cosmetic("tiles", "circuit", "Circuit", { LIME, ASPHALT }, { level = 15 }),
	cosmetic("tiles", "chromeTiles", "Chrome Tiles", { WHITE, STEEL }, { price = 500_000 }),
	cosmetic("trail", "none", "None", {}, { level = 1 }),
	cosmetic("trail", "cyanTrail", "Cyan Trail", { CYAN }, { level = 2 }),
	cosmetic("trail", "magentaTrail", "Magenta Trail", { MAGENTA }, { level = 8 }),
	cosmetic("trail", "goldTrail", "Gold Trail", { AMBER }, {}),
}
SpireConfig.COSMETICS = COSMETICS
SpireConfig.SLOT_DEFAULTS = { skin = "glass", crown = "antenna", lobby = "marble", tiles = "grid", trail = "none" }
SpireConfig.SHARE_UNLOCKS =
	{ chrome = 1, carbon = 10, jade = 30, prism = 75, satellite = 10, goldTrail = 1 } :: { [string]: number }

-- Reward is the base; the paid amount is SpireProgress.scaled(base, minutes).
local QUESTS: { MetaRules.Quest } = {
	{ id = "modules10", label = "Buy 10 modules", stat = "modules", goal = 10, reward = 300, minutes = 5 },
	{ id = "upgrades15", label = "Upgrade 15 modules", stat = "upgrades", goal = 15, reward = 400, minutes = 5 },
	{ id = "maxed1", label = "Reach level 5 on a module", stat = "maxed", goal = 1, reward = 500, minutes = 10 },
	{ id = "hot5", label = "Catch 5 Hot Data", stat = "hot", goal = 5, reward = 500, minutes = 10 },
	{ id = "plaza3", label = "Place 3 plaza items", stat = "placed", goal = 3, reward = 300, minutes = 5 },
	{ id = "floor1", label = "Buy a floor", stat = "floors", goal = 1, reward = 300, minutes = 5 },
	{
		id = "earn1h",
		label = "Earn 1 hour of income",
		stat = "earnSeconds",
		goal = 3_600,
		reward = 1_000,
		minutes = 15,
	},
	{ id = "endorse2", label = "Endorse 2 companies", stat = "endorse", goal = 2, reward = 200, minutes = 5 },
}
SpireConfig.QUESTS = QUESTS
SpireConfig.DAILY = { 100, 150, 200, 250, 300, 400, 800 }
SpireConfig.DAILY_MINUTES = { 2, 3, 4, 5, 6, 8, 15 }
SpireConfig.WEEKLY = { days = 5, reward = 1_000, minutes = 30 }
SpireConfig.MILESTONES = { 10, 20, 30 }
SpireConfig.BUCKET = { size = 6, rate = 4 }
SpireConfig.MAX_ARG = 40
SpireConfig.FEATURES = { ipo = false }

local CELL = "^(%d+):([1-4])$"
local ID = "^([%w_]+)$"
SpireConfig.ACTIONS = {
	buyFloor = { pattern = "^(%l+)$", profile = true },
	refitFloor = { pattern = "^(%d+):(%l+)$", profile = true },
	buyModule = { pattern = CELL, profile = true },
	upgradeModule = { pattern = CELL, profile = true },
	sellModule = { pattern = CELL, profile = true },
	placeItem = { pattern = "^(%l+):(%d+):(%d+):([0-3])$", profile = true },
	moveItem = { pattern = "^(%d+):(%d+):(%d+):([0-3])$", profile = true },
	sellItem = { pattern = "^(%d+)$", profile = true },
	lift = { pattern = "^(%w+)$", profile = false },
	home = { profile = false },
	endorse = { pattern = "^(%d+)$", profile = true },
	setGate = { pattern = "^(%l+)$", profile = true },
	setCompany = { pattern = "^(%d+):(%d+):(%d+):(%d+):(%d+)$", profile = true },
	ipo = { profile = true },
	claimDaily = { profile = true },
	claimWeekly = { profile = true },
	claimQuest = { pattern = ID, profile = true },
	buyCosmetic = { pattern = ID, profile = true },
	equipCosmetic = { pattern = ID, profile = true },
} :: { [string]: ActionSpec }

SpireConfig.CODES = {
	"busy",
	"type",
	"action",
	"arg",
	"rate",
	"zone",
	"target",
	"gate",
	"credits",
	"power",
	"locked",
	"floor",
	"occupied",
	"empty",
	"max",
	"full",
	"bounds",
	"walkway",
	"modules",
	"needed",
	"same",
	"unknown",
	"claimed",
	"owned",
	"done",
	"ipo",
}

local function find<T>(list: { T }, id: string): T?
	for _, entry in list do
		if (entry :: any).id == id then
			return entry
		end
	end
	return nil
end

-- nil for unknown ids and for "lobby".
function SpireConfig.dept(id: string): Dept?
	return find(DEPTS, id)
end

function SpireConfig.item(id: string): PlazaItem?
	return find(ITEMS, id)
end

function SpireConfig.companyName(c: Company): string
	return `{SpireConfig.NAMES.prefixes[c.p] or "?"} {SpireConfig.NAMES.suffixes[c.s] or "?"}`
end

return SpireConfig
