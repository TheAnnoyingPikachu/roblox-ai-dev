--!strict
-- Lantern Express data (architecture lantern 3.1): every number of GDD sections C, F and H and of
-- decision 0018 section 5, the stop tiles, the authored tracks and the train's cars. Types and
-- data only; the rules live in TrackRules, LootRules, CarryRules, WispRules, DepotRules, TrainRules
-- and LanternProgress. No Roblox APIs.

local MetaRules = require("./MetaRules")

local LanternConfig = {}

export type Vec3 = { x: number, y: number, z: number }
export type Line = "forest" | "lake"
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"
export type ItemKind = "coal" | "parts" | "oil" | "supply" | "critter"
export type SeatKind = "stoker" | "turret" | "mender" | "passenger"
export type Critter = {
	id: string,
	name: string,
	rarity: Rarity | "exclusive",
	lines: { Line },
	tiles: { string },
	leg3: boolean?,
	look: string,
}
export type Box = { name: string?, at: Vec3, size: Vec3 } -- stop frame, centre and size
export type Tile = {
	id: string,
	name: string,
	lines: { Line },
	small: { Vec3 },
	big: { Vec3 },
	blocks: { Box },
	lamps: { Vec3 },
}
export type Seat = { id: string, kind: SeatKind, at: Vec3 } -- car-local (car frame as the train frame, at the car's centre)
export type Car = {
	id: string,
	model: string,
	length: number,
	offset: number, -- studs from the engine's front (the train frame origin) to this car's front
	seats: { Seat },
	lanterns: { Vec3 },
	turrets: { Vec3 },
}
export type Track = { points: { Vec3 }, closed: boolean, stops: { number }, nightFrom: number, finish: number }
export type Upgrade = { id: string, name: string, costs: { number } } -- costs of levels II and III
export type LoginSlot = { count: number, tickets: number?, cosmetic: string?, critter: string?, owned: number? }
export type Role = { id: string, stat: string, tiers: { number } }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- Train and run (GDD C1, C5) -------------------------------------------------------------------

LanternConfig.SPEED = { 20, 23, 26 } -- cruise by Boiler level
LanternConfig.ACCEL = 4 -- studs/s^2 speeding up and braking
LanternConfig.COAST = 2 -- studs/s^2 slowing with an empty bunker
LanternConfig.STOKE = { mult = 1.25, seconds = 6, coal = 2, cooldown = 6 }
LanternConfig.COAL_PER_STUD = 1 / 60
LanternConfig.BUNKER = { 80, 100, 120 }
LanternConfig.COAL_LOW = 15
LanternConfig.LANTERN = {
	max = 100,
	store = 6,
	autoBelow = 25,
	autoPour = 8,
	autoEvery = 3,
	mend = 12,
	mendMax = 88,
	mendCooldown = 3,
	depot = 40,
}
LanternConfig.HUB = { grace = 3, firstSit = 20 }
LanternConfig.DEPOT = { max = 90, minStay = 10, grace = 3 }
LanternConfig.END_CARD = 12
LanternConfig.APPROACH = 200 -- studs before a stop where its tile is built (architecture 3.7)

-- Stops (GDD C2, C3) ---------------------------------------------------------------------------

LanternConfig.STOP = {
	calm = 70,
	depth = 160,
	width = 120,
	minStay = 10,
	grace = 3,
	limbo = 10,
	fogV0 = 6,
	fogAcc = 1,
	fogMax = 16,
}
LanternConfig.MOVE = { walk = 16, small = 15, big = 13, critterSolo = 9, critterDuo = 13 }
LanternConfig.REACH = 8
LanternConfig.HELP_BREAK = 14
LanternConfig.LOAD_BOX = 6
LanternConfig.NEAR = 70 -- a big site under 70 studs deep uses the near odds
LanternConfig.ITEMS = {
	coal = { big = false, tickets = 1, coal = 5 },
	parts = { big = false, tickets = 1, parts = 3 },
	oil = { big = false, tickets = 1, oil = 1 },
	supply = { big = true, tickets = 8, parts = 10 },
	critter = { big = true },
} :: { [string]: { big: boolean, tickets: number?, coal: number?, parts: number?, oil: number? } }
LanternConfig.CRITTER_TICKETS = { common = 10, uncommon = 15, rare = 25, epic = 50, legendary = 100 }
LanternConfig.RARITY_COLOURS = { -- GDD C7: crate glow and tag colour
	common = { 120, 170, 110 },
	uncommon = { 90, 160, 230 },
	rare = { 170, 120, 230 },
	epic = { 240, 180, 60 },
	legendary = { 235, 240, 255 },
}

-- Nights (GDD C4) ------------------------------------------------------------------------------

LanternConfig.WAVES = {
	first = 8,
	gap = 25,
	perTurret = { 4, 6, 8 }, -- by leg
	lake = 1,
	spawnMin = 60,
	spawnMax = 75,
	heightMin = 4,
	heightMax = 20,
	spread = 3,
	speed = { 6, 7, 8, 8 }, -- studs/s by min(n, 4): one or two lamps cover the whole circle (LANTERN-015)
	wobble = 2,
	reach = 3,
}
LanternConfig.DIM = { 4.5, 3.5, 3.5, 3 } -- by min(n, 4); a solo lamp puffing 1 wisp in 4 sees the Depot (LANTERN-015)
LanternConfig.BEAM = {
	halfAngle = 7,
	range = { 80, 90, 100 },
	puff = { 0.6, 0.45, 0.35 },
	pitchMin = -15,
	pitchMax = 75,
	stale = 0.5,
}
LanternConfig.LAMPEATER = {
	at = 50,
	warn = 3,
	radius = 45,
	height = 25,
	every = 8,
	dive = 3,
	shoo = 0.8,
	dim = 10,
	needBase = 15,
	needPer = 8,
}

-- Odds (GDD H4), basis points in RARITIES order ------------------------------------------------

LanternConfig.RARITIES = { "common", "uncommon", "rare", "epic", "legendary" } :: { Rarity }
LanternConfig.ODDS = {
	near = { 7000, 2500, 500, 0, 0 },
	far = { forest = { 4600, 3400, 1500, 500, 0 }, lake = { 4000, 3400, 1800, 800, 0 } },
	farLeg3 = { forest = { 4300, 3400, 1500, 500, 300 }, lake = { 3700, 3400, 1800, 800, 300 } },
}

local FOREST_TILES = { "village", "farm", "windmill", "orchard", "inn", "mill" }
local LAKE_TILES = { "village", "farm", "inn", "mill", "lighthouse", "boathouse" }
local ALL_TILES = { "village", "farm", "windmill", "orchard", "inn", "mill", "lighthouse", "boathouse" }
LanternConfig.LINE_TILES = { forest = FOREST_TILES, lake = LAKE_TILES }

local function critter(
	id: string,
	name: string,
	rarity: Rarity | "exclusive",
	lines: { Line },
	tiles: { string },
	look: string,
	leg3: boolean?
): Critter
	return { id = id, name = name, rarity = rarity, lines = lines, tiles = tiles, look = look, leg3 = leg3 }
end

local BOTH: { Line } = { "forest", "lake" }
LanternConfig.CRITTERS = {
	critter(
		"mossmouse",
		"Moss Mouse",
		"common",
		BOTH,
		ALL_TILES,
		"round grey mouse with a moss cap and a dandelion seed"
	),
	critter(
		"puddlefrog",
		"Puddle Frog",
		"common",
		BOTH,
		{ "farm", "mill", "lighthouse", "boathouse" },
		"fat teal frog wearing a walnut-shell boat as a hat"
	),
	critter(
		"wickmole",
		"Wick Mole",
		"common",
		BOTH,
		{ "village", "inn", "mill", "orchard" },
		"velvet mole with a tiny lit candle stub on its head"
	),
	critter(
		"burrbun",
		"Burr Bunny",
		"common",
		BOTH,
		{ "farm", "windmill", "orchard", "village" },
		"cream bunny covered in soft burrs, one ear flopped"
	),
	critter(
		"lanternbeetle",
		"Lantern Beetle",
		"uncommon",
		BOTH,
		{ "farm", "windmill", "orchard", "village" },
		"round beetle whose glass abdomen glows amber"
	),
	critter(
		"fogpup",
		"Fog Pup",
		"uncommon",
		BOTH,
		{ "village", "inn", "lighthouse", "boathouse" },
		"fluffy pale puppy that fades into mist at the tail, knitted scarf"
	),
	critter(
		"acornowlet",
		"Acorn Owlet",
		"uncommon",
		BOTH,
		{ "orchard", "windmill", "mill", "inn" },
		"owl chick sitting in an acorn cup, huge eyes"
	),
	critter(
		"teapotcat",
		"Teapot Cat",
		"rare",
		BOTH,
		{ "inn", "village", "farm" },
		"tabby curled inside a chipped teapot, lid on its head"
	),
	critter(
		"reedfox",
		"Reed Fox",
		"rare",
		BOTH,
		{ "mill", "lighthouse", "boathouse", "orchard" },
		"slim russet fox with cattails in its tail"
	),
	critter(
		"mistfawn",
		"Mist Fawn",
		"epic",
		{ "forest" },
		FOREST_TILES,
		"white fawn with glowing antler buds and star freckles"
	),
	critter(
		"bellturtle",
		"Bell Turtle",
		"epic",
		{ "lake" },
		LAKE_TILES,
		"turtle whose shell is a bronze bell with lily pads"
	),
	critter(
		"moonhare",
		"Moon Hare",
		"legendary",
		BOTH,
		ALL_TILES,
		"silver hare with a crescent-moon mark and long whiskers",
		true
	),
	critter("emberkit", "Ember Kit", "exclusive", {}, {}, "fox kit holding a tiny lantern, ember-tipped tail"),
} :: { Critter }

-- Stop tiles (GDD C3, D): sites are data, the mesh is decor ------------------------------------
-- Copied from LAYOUT in tools/blender/lantern/assets/tiles.py (LANTERN-009), the tiles' contract:
-- the art places its buildings, lamps and a clear lane to exactly these numbers. Stop frame: x
-- across the tile (-60..60), z the depth from the platform deck's track edge (0) to the far edge
-- (160), y up from the plate. The deck (depth 0 to 10, 1.8 high, 108 long) and its ramp (10 to 15)
-- are the same on every tile; sites start at 18. Blocks are { name, x, depth, width, depth size,
-- height } and collide; lamps are where the street lamps stand (code hangs a PointLight 7.5 up).

LanternConfig.BIG_DEPTHS = { 22, 40, 58, 78, 96, 114, 132, 150 }
LanternConfig.TILE_DECK = { depth = 10, height = 1.8, length = 108, ramp = 15 }

type Layout = { blocks: { { any } }, lamps: { { number } }, big: { { number } }, small: { { number } } }

local function tile(id: string, name: string, layout: Layout): Tile
	local function sites(list: { { number } }): { Vec3 }
		local out = {}
		for _, s in list do
			table.insert(out, v(s[1], 0, s[2]))
		end
		return out
	end
	local boxes = {}
	for _, b in layout.blocks do
		table.insert(boxes, { name = b[1], at = v(b[2], b[6] / 2, b[3]), size = v(b[4], b[6], b[5]) })
	end
	local lines: { Line } = {}
	for _, line in BOTH do
		if table.find(LanternConfig.LINE_TILES[line], id) then
			table.insert(lines, line)
		end
	end
	return {
		id = id,
		name = name,
		lines = lines,
		small = sites(layout.small),
		big = sites(layout.big),
		blocks = boxes,
		lamps = sites(layout.lamps),
	}
end

local orchardBlocks = {} -- the orchard's 20 apple trees, 4 across and 5 deep, then the rest
for i, d in { 34, 56, 78, 100, 122 } do
	for j, x in { -44, -26, 26, 44 } do
		table.insert(orchardBlocks, { `apple_{(i - 1) * 4 + j}`, x, d, 2, 2, 15 })
	end
end
table.insert(orchardBlocks, { "store", 32, 146, 16, 14, 13 })
table.insert(orchardBlocks, { "hives", -36, 146, 8, 3, 2.6 })
table.insert(orchardBlocks, { "crates", 14, 96, 3.5, 2.5, 2 })
table.insert(orchardBlocks, { "crates_2", -14, 60, 3.5, 2.5, 2 })

LanternConfig.TILES = {
	tile("village", "Hollow Village", {
		blocks = {
			{ "cottage", 22, 46, 15, 12, 17 },
			{ "house_w", -24, 38, 12, 10, 14 },
			{ "house_nw", -28, 124, 13, 13, 15 },
			{ "house_ne", 28, 132, 12, 10.5, 14 },
			{ "well", 0, 92, 5, 5, 7 },
			{ "fence_1", 17.15, 36, 5.3, 0.5, 1.2 },
			{ "fence_2", 26.9, 36, 5.4, 0.5, 1.2 },
			{ "fence_3", 29.6, 37.8, 0.5, 3.6, 1.2 },
			{ "tree_1", -47, 72, 2, 2, 13 },
			{ "tree_2", 49, 92, 2, 2, 14 },
			{ "tree_3", -50, 152, 2, 2, 12 },
			{ "tree_4", 50, 152, 2, 2, 13 },
			{ "tree_5", -46, 22, 2, 2, 11 },
		},
		lamps = { { 6.5, 30 }, { -6.5, 62 }, { 6.5, 118 }, { -6.5, 146 } },
		big = { { -12, 22 }, { 9, 40 }, { -12, 58 }, { 24, 78 }, { -22, 96 }, { 16, 114 }, { -10, 132 }, { 20, 150 } },
		small = {
			{ -30, 18 },
			{ 32, 20 },
			{ 6, 26 },
			{ -38, 50 },
			{ 38, 56 },
			{ -6, 48 },
			{ 10, 66 },
			{ -30, 70 },
			{ 40, 76 },
			{ -8, 82 },
			{ 12, 100 },
			{ -42, 100 },
			{ 36, 104 },
			{ -14, 112 },
			{ 52, 120 },
			{ 6, 128 },
			{ -44, 136 },
			{ 40, 146 },
			{ -24, 146 },
			{ 4, 150 },
			{ -52, 50 },
			{ 52, 34 },
			{ 24, 92 },
			{ -30, 108 },
		},
	}),
	tile("farm", "Mossy Farm", {
		blocks = {
			{ "barn", 28, 96, 22, 30, 21 },
			{ "silo", 49, 70, 8, 8, 24 },
			{ "farmhouse", -32, 42, 13, 11, 15 },
			{ "hay_1", 17, 58, 6, 6, 5.5 },
			{ "hay_2", -28, 142, 6, 6, 5.5 },
			{ "hay_3", 44, 140, 6, 6, 5.5 },
			{ "cart", 48, 100, 4, 7, 3 },
			{ "coop", 28, 148, 7, 6, 5 },
			{ "fence_w", -57.5, 95, 0.6, 64.6, 1.5 },
			{ "fence_n", -35.75, 127, 44.1, 0.6, 1.5 },
			{ "fence_s", -48.75, 63, 18.1, 0.6, 1.5 },
			{ "fence_se", -19, 63, 10.6, 0.6, 1.5 },
			{ "fence_e", -14, 69, 0.6, 12.6, 1.5 },
			{ "tree_1", -50, 22, 2, 2, 13 },
			{ "tree_2", 52, 152, 2, 2, 14 },
			{ "tree_3", -52, 152, 2, 2, 12 },
			{ "tree_4", 52, 30, 2, 2, 12 },
		},
		lamps = { { -2.5, 30 }, { 10.5, 62 }, { -2.5, 100 }, { 10.5, 132 } },
		big = { { -12, 22 }, { 20, 40 }, { -8, 58 }, { -8, 78 }, { -36, 96 }, { 10, 114 }, { 26, 132 }, { -10, 150 } },
		small = {
			{ 50, 18 },
			{ -40, 18 },
			{ 12, 18 },
			{ 32, 24 },
			{ 0, 38 },
			{ -22, 42 },
			{ -50, 44 },
			{ 50, 50 },
			{ 32, 54 },
			{ 10, 56 },
			{ -34, 68 },
			{ 22, 70 },
			{ -50, 80 },
			{ 50, 82 },
			{ 12, 92 },
			{ -14, 100 },
			{ 50, 112 },
			{ -50, 114 },
			{ -20, 122 },
			{ 0, 132 },
			{ -50, 136 },
			{ 50, 146 },
			{ 12, 148 },
			{ -34, 148 },
		},
	}),
	tile("windmill", "Old Windmill", {
		blocks = {
			{ "windmill", 24, 100, 18, 18, 44 },
			{ "cottage", -28, 50, 13, 11, 15 },
			{ "granary", -30, 128, 14, 18, 13 },
			{ "cart", -40, 100, 4, 7, 3 },
			{ "tree_1", -50, 86, 2, 2, 14 },
			{ "tree_2", 52, 40, 2, 2, 13 },
			{ "tree_3", 52, 112, 2, 2, 12 },
			{ "tree_4", -52, 24, 2, 2, 12 },
		},
		lamps = { { -6.5, 30 }, { 6.5, 64 }, { -6.5, 100 }, { 6.5, 136 } },
		big = { { 12, 22 }, { -12, 40 }, { 10, 58 }, { 36, 78 }, { -12, 96 }, { 40, 114 }, { 12, 132 }, { -16, 150 } },
		small = {
			{ -50, 18 },
			{ -24, 18 },
			{ 34, 18 },
			{ -6, 20 },
			{ 50, 34 },
			{ 18, 40 },
			{ -40, 44 },
			{ 34, 52 },
			{ 50, 64 },
			{ -50, 68 },
			{ -20, 68 },
			{ -2, 72 },
			{ 12, 86 },
			{ -44, 94 },
			{ 50, 94 },
			{ 6, 110 },
			{ -34, 110 },
			{ -50, 120 },
			{ -18, 122 },
			{ 30, 130 },
			{ 50, 148 },
			{ -46, 148 },
			{ 28, 148 },
			{ 2, 148 },
		},
	}),
	tile("orchard", "Apple Orchard", {
		blocks = orchardBlocks,
		lamps = { { 6.5, 30 }, { -6.5, 66 }, { 6.5, 104 }, { -6.5, 140 } },
		big = { { -14, 22 }, { 14, 40 }, { -35, 58 }, { 35, 78 }, { -14, 96 }, { 14, 114 }, { -35, 132 }, { 8, 150 } },
		small = {
			{ 50, 18 },
			{ -50, 18 },
			{ 24, 18 },
			{ -34, 34 },
			{ 34, 36 },
			{ -50, 46 },
			{ -10, 48 },
			{ 50, 50 },
			{ 22, 60 },
			{ 4, 70 },
			{ -50, 72 },
			{ -18, 74 },
			{ -32, 86 },
			{ 16, 90 },
			{ -50, 92 },
			{ 30, 104 },
			{ 50, 106 },
			{ -34, 108 },
			{ -50, 120 },
			{ -8, 128 },
			{ 26, 134 },
			{ 50, 138 },
			{ -18, 148 },
			{ -50, 148 },
		},
	}),
	tile("inn", "Kettle Inn", {
		blocks = {
			{ "inn", -22, 72, 24, 20, 24 },
			{ "sign", 1, 52, 1, 1, 9 },
			{ "table_1", -30, 44, 3, 3, 3 },
			{ "table_2", -14, 42, 3, 3, 3 },
			{ "table_3", -22, 32, 3, 3, 3 },
			{ "stable", 32, 118, 16, 22, 12 },
			{ "tree_1", -50, 120, 2, 2, 13 },
			{ "tree_2", 52, 40, 2, 2, 14 },
			{ "tree_3", -48, 150, 2, 2, 12 },
			{ "tree_4", 50, 152, 2, 2, 13 },
		},
		lamps = { { 1.5, 30 }, { 14.5, 64 }, { 1.5, 100 }, { 14.5, 136 } },
		big = { { -2, 22 }, { -42, 40 }, { 24, 58 }, { -44, 78 }, { -14, 96 }, { 16, 114 }, { -24, 132 }, { 24, 150 } },
		small = {
			{ 50, 18 },
			{ -28, 18 },
			{ -50, 18 },
			{ 24, 30 },
			{ -18, 36 },
			{ 6, 44 },
			{ 50, 46 },
			{ -12, 56 },
			{ -32, 58 },
			{ 44, 68 },
			{ -6, 76 },
			{ 12, 84 },
			{ 50, 90 },
			{ -38, 96 },
			{ 30, 98 },
			{ 46, 108 },
			{ -50, 112 },
			{ -28, 112 },
			{ -6, 118 },
			{ 50, 126 },
			{ 10, 132 },
			{ -50, 144 },
			{ -2, 146 },
			{ 46, 148 },
		},
	}),
	tile("mill", "Water Mill", {
		blocks = {
			{ "stream", -42, 129, 10, 62, 3 },
			{ "pool", -34.5, 91, 25, 14, 3 },
			{ "pond", -42, 38, 18, 18, 3 },
			{ "mill", -28, 110, 18, 18, 22 },
			{ "cottage", 28, 48, 13, 11, 15 },
			{ "store", 32, 128, 16, 16, 12 },
			{ "cart", 16, 96, 4, 7, 3 },
			{ "tree_1", 54, 90, 2, 2, 14 },
			{ "tree_2", -54, 20, 2, 2, 12 },
			{ "tree_3", 52, 152, 2, 2, 13 },
			{ "tree_4", -54, 76, 2, 2, 13 },
		},
		lamps = { { -4.5, 30 }, { 8.5, 64 }, { -4.5, 100 }, { 8.5, 136 } },
		big = { { -16, 22 }, { 14, 40 }, { -14, 58 }, { 22, 78 }, { -10, 96 }, { 22, 114 }, { -20, 132 }, { 8, 150 } },
		small = {
			{ 50, 18 },
			{ 24, 18 },
			{ 4, 20 },
			{ -50, 24 },
			{ 40, 36 },
			{ -26, 40 },
			{ -6, 40 },
			{ -44, 52 },
			{ 50, 54 },
			{ 28, 58 },
			{ 6, 58 },
			{ 44, 74 },
			{ 0, 76 },
			{ -26, 78 },
			{ -50, 80 },
			{ 10, 94 },
			{ 50, 96 },
			{ 30, 96 },
			{ -2, 118 },
			{ 46, 120 },
			{ 12, 130 },
			{ 28, 140 },
			{ 50, 146 },
			{ -32, 148 },
		},
	}),
	tile("lighthouse", "Lake Lighthouse", {
		blocks = {
			{ "lighthouse", 30, 120, 14, 14, 44 },
			{ "cottage", -28, 56, 13, 11, 15 },
			{ "netshed", -32, 122, 12, 16, 11 },
			{ "nets", -14, 130, 9, 1.5, 4.2 },
			{ "rock_1", 48, 150, 8, 5, 4 },
			{ "rock_2", -50, 154, 7, 5, 3.5 },
			{ "rock_3", 14, 156, 6, 4, 3 },
			{ "boat", -6, 148, 3.6, 7, 2 },
			{ "sea", 0, 157, 120, 6, 3 },
			{ "fence_1", -32.4, 47, 5.2, 0.5, 1.2 },
			{ "fence_2", -23.6, 47, 5.2, 0.5, 1.2 },
			{ "tree_1", -50, 24, 2, 2, 12 },
			{ "tree_2", 52, 34, 2, 2, 13 },
		},
		lamps = { { -10.5, 30 }, { 2.5, 64 }, { -10.5, 100 }, { 2.5, 128 } },
		big = { { 12, 22 }, { -18, 40 }, { 14, 58 }, { -22, 78 }, { 12, 96 }, { -14, 114 }, { 14, 132 }, { -24, 150 } },
		small = {
			{ -50, 18 },
			{ 38, 18 },
			{ -26, 18 },
			{ -8, 24 },
			{ -40, 36 },
			{ 28, 38 },
			{ 50, 40 },
			{ 2, 40 },
			{ -50, 56 },
			{ 38, 60 },
			{ -8, 60 },
			{ 24, 78 },
			{ 2, 78 },
			{ 50, 80 },
			{ -48, 80 },
			{ -10, 94 },
			{ 36, 98 },
			{ -30, 98 },
			{ -50, 104 },
			{ 6, 114 },
			{ 50, 118 },
			{ -50, 134 },
			{ -8, 136 },
			{ 40, 148 },
		},
	}),
	tile("boathouse", "Reed Boathouse", {
		blocks = {
			{ "water", -42, 115, 36, 90, 3 },
			{ "boathouse", -26, 96, 24, 16, 15 },
			{ "cottage", 26, 52, 13, 11, 15 },
			{ "nets", 34, 112, 10, 1.5, 4.2 },
			{ "boat", -2, 140, 3.6, 7, 2 },
			{ "tree_1", 52, 24, 2, 2, 13 },
			{ "tree_2", -52, 30, 2, 2, 12 },
			{ "tree_3", 54, 150, 2, 2, 14 },
		},
		lamps = { { 3.5, 30 }, { 16.5, 64 }, { 3.5, 100 }, { 16.5, 136 }, { -54, 80 } },
		big = { { -10, 22 }, { 20, 40 }, { -14, 58 }, { 36, 78 }, { -8, 96 }, { 8, 114 }, { 30, 132 }, { -4, 150 } },
		small = {
			{ 50, 18 },
			{ -34, 18 },
			{ 14, 18 },
			{ 32, 24 },
			{ -50, 36 },
			{ -28, 40 },
			{ 0, 42 },
			{ 50, 50 },
			{ 4, 58 },
			{ 24, 62 },
			{ -44, 66 },
			{ 50, 68 },
			{ 8, 74 },
			{ -20, 78 },
			{ 50, 88 },
			{ 22, 96 },
			{ 50, 106 },
			{ 26, 114 },
			{ -20, 124 },
			{ 50, 126 },
			{ 10, 134 },
			{ -20, 142 },
			{ 50, 146 },
			{ 22, 148 },
		},
	}),
} :: { Tile }

-- Tracks (architecture 3.1, GDD M) -------------------------------------------------------------
-- Authored as straights and arcs from the hub point (10, 0, 0) heading -z, then sampled into
-- control points every 5 studs or less (sparser points let the spline overshoot where a straight
-- meets an arc: at 20 studs the night measured radius 557). The Forest loop turns right (east of
-- the hub), the Lake loop is its mirror (west). Day: out 100, a 90-degree turn of radius 200, the
-- east run (stops at 700 and 1,400), a second turn, 200 to stop 3 at 2,100. Night (radius 650, at
-- least 600 by spec): down, a quarter turn, back across, a quarter turn and up to the hub at 5,700.
-- The Dawn tracks follow the loop to 5,300 and leave on a 400-stud arc (radius 650) into the
-- loop's middle. Both loops measure about 1,570 x 1,620 studs: radius 600 at night does not fit the
-- 1,100 x 650 of architecture 3.1 (a quarter turn alone spans 600 x 600).

local DAY_R, NIGHT_R, OUT, TO_STOP3 = 200, 650, 100, 200
local QUARTER_DAY, QUARTER_NIGHT = math.pi / 2 * DAY_R, math.pi / 2 * NIGHT_R
local EAST = 2100 - OUT - 2 * QUARTER_DAY - TO_STOP3
local WEST = 2 * DAY_R + EAST - 2 * NIGHT_R -- closes the loop east to west
local DOWN = (3600 - 2 * QUARTER_NIGHT - WEST - TO_STOP3 + OUT) / 2 -- and north to south
local UP = DOWN + TO_STOP3 - OUT
local LOOP = { -- { length, radius (0 straight), turn (1 right) }
	{ OUT, 0, 0 },
	{ QUARTER_DAY, DAY_R, 1 },
	{ EAST, 0, 0 },
	{ QUARTER_DAY, DAY_R, 1 },
	{ TO_STOP3, 0, 0 },
	{ DOWN, 0, 0 },
	{ QUARTER_NIGHT, NIGHT_R, 1 },
	{ WEST, 0, 0 },
	{ QUARTER_NIGHT, NIGHT_R, 1 },
	{ UP - 400, 0, 0 },
	{ 400, 0, 0 },
}
local HUB_X = 10

local function trace(parts: { { number } }, mirror: boolean): { Vec3 }
	local x, z, heading = HUB_X, 0, 0 -- heading 0 is -z; positive turns right (towards +x)
	local out = { v(x, 0, z) }
	for _, part in parts do
		local length, radius, turn = part[1], part[2], part[3]
		local pieces = math.ceil(length / 5 - 1e-9)
		for _ = 1, pieces do
			local s = length / pieces
			if radius == 0 then
				x += math.sin(heading) * s
				z -= math.cos(heading) * s
			else
				local dh = turn * s / radius
				local chord = 2 * radius * math.sin(math.abs(dh) / 2)
				x += math.sin(heading + dh / 2) * chord
				z -= math.cos(heading + dh / 2) * chord
				heading += dh
			end
			table.insert(out, v(if mirror then 2 * HUB_X - x else x, 0, z))
		end
	end
	return out
end

local function loop(mirror: boolean): Track
	local points = trace(LOOP, mirror)
	table.remove(points) -- the last point is the hub again; a closed path wraps to points[1]
	return { points = points, closed = true, stops = { 700, 1400, 2100 }, nightFrom = 2100, finish = 5700 }
end

local function dawn(mirror: boolean): Track
	local parts = table.clone(LOOP)
	parts[#parts] = { 400, NIGHT_R, 1 }
	return {
		points = trace(parts, mirror),
		closed = false,
		stops = { 700, 1400, 2100 },
		nightFrom = 2100,
		finish = 5700,
	}
end

LanternConfig.TRACKS = {
	forest = loop(false),
	lake = loop(true),
	forestDawn = dawn(false),
	lakeDawn = dawn(true),
} :: { [string]: Track }
-- The side of the track that platforms and stop tiles are on, as a multiple of TrackRules.right:
-- the outside of each loop (the Forest loop turns right, so its outside is on the left).
LanternConfig.OUTER = { forest = -1, lake = 1 }

-- Cars (GDD C1): 22 + 16 + 16 + 18 studs with 2-stud gaps = 78 --------------------------------

local function seat(id: string, kind: SeatKind, x: number, y: number, z: number): Seat
	return { id = id, kind = kind, at = v(x, y, z) }
end

LanternConfig.CARS = {
	{
		id = "engine",
		model = "train_engine",
		length = 22,
		offset = 0,
		seats = { seat("stoker", "stoker", 0, 3, 7), seat("turret1", "turret", 0, 11, -2) },
		lanterns = { v(0, 6, -11), v(0, 9, 4) },
		turrets = { v(0, 12.5, -3) },
	},
	{
		id = "cargo",
		model = "train_car_cargo",
		length = 16,
		offset = 24,
		seats = {},
		lanterns = { v(-4, 6, 0), v(4, 6, 0) },
		turrets = {},
	},
	{
		id = "lamp",
		model = "train_car_lamp",
		length = 16,
		offset = 42,
		seats = {
			seat("turret2", "turret", 0, 3, -5),
			seat("turret3", "turret", 0, 3, 5),
			seat("mender", "mender", 3, 2.5, 0),
		},
		lanterns = { v(-3, 5, 0), v(3, 5, -1) },
		turrets = { v(0, 4.5, -6), v(0, 4.5, 4) },
	},
	{
		id = "passenger",
		model = "train_car_passenger",
		length = 18,
		offset = 60,
		seats = {
			seat("turret4", "turret", 0, 10, 0),
			seat("passenger1", "passenger", -2, 2.5, -5),
			seat("passenger2", "passenger", 2, 2.5, -5),
			seat("passenger3", "passenger", -2, 2.5, 0),
			seat("passenger4", "passenger", 2, 2.5, 0),
			seat("passenger5", "passenger", -2, 2.5, 5),
			seat("passenger6", "passenger", 2, 2.5, 5),
		},
		lanterns = { v(-4, 7, -8), v(4, 7, 8) },
		turrets = { v(0, 11.5, -1) },
	},
} :: { Car }
LanternConfig.TRAIN_LENGTH = 78
LanternConfig.SEAT_COUNTS = { stoker = 1, turret = 4, mender = 1, passenger = 6 } :: { [string]: number }

-- Depot (GDD F) --------------------------------------------------------------------------------

LanternConfig.UPGRADES = {
	{ id = "boiler", name = "Boiler", costs = { 30, 60 } },
	{ id = "bunker", name = "Bunker", costs = { 25, 50 } },
	{ id = "lamps", name = "Lamps", costs = { 30, 60 } },
} :: { Upgrade }
LanternConfig.COAL_BUY = { coal = 30, parts = 12 }
LanternConfig.OIL_BUY = { cans = 2, parts = 10 }
LanternConfig.TICKETS = { depot = 30, dawn = 150, fed = 50, coop = 0.1 }
LanternConfig.XP =
	{ small = 2, big = 5, rescue = 20, new = 50, puff = 2, stoke = 1, mend = 3, stop = 5, depot = 40, dawn = 150 }

-- Meta (GDD H) ---------------------------------------------------------------------------------

LanternConfig.QUESTS = {
	{ id = "rescue3", label = "Rescue 3 critters", stat = "rescues", goal = 3, reward = 100 },
	{ id = "rescue10", label = "Rescue 10 critters", stat = "rescues", goal = 10, reward = 200 },
	{ id = "load20", label = "Load 20 items yourself", stat = "loads", goal = 20, reward = 100 },
	{ id = "puff30", label = "Puff 30 wisps", stat = "puffs", goal = 30, reward = 100 },
	{ id = "stoke15", label = "Stoke the boiler 15 times", stat = "stokes", goal = 15, reward = 100 },
	{ id = "depot2", label = "Reach 2 Depots", stat = "depots", goal = 2, reward = 150 },
	{ id = "dawn1", label = "Reach Dawn Station", stat = "dawns", goal = 1, reward = 250 },
	{ id = "rare1", label = "Rescue a Rare or better", stat = "rareRescues", goal = 1, reward = 150 },
} :: { MetaRules.Quest }

local function cosmetic(
	slot: string,
	id: string,
	name: string,
	colours: { { number } },
	unlock: any
): MetaRules.Cosmetic
	return {
		id = id,
		name = name,
		slot = slot,
		colours = colours,
		level = unlock.level,
		price = unlock.price,
		grant = unlock.grant,
	}
end

LanternConfig.COSMETICS = {
	cosmetic("livery", "classic", "Lamplight Red", { { 170, 40, 35 }, { 40, 30, 30 } }, { level = 1 }),
	cosmetic("livery", "ember", "Ember Orange", { { 230, 120, 40 }, { 60, 35, 25 } }, { level = 5 }),
	cosmetic("livery", "fern", "Fern Green", { { 70, 130, 70 }, { 35, 50, 35 } }, { level = 10 }),
	cosmetic("livery", "brass", "Polished Brass", { { 200, 160, 80 }, { 70, 50, 30 } }, { price = 2500 }),
	cosmetic("livery", "ivory", "Ivory and Gold", { { 240, 230, 210 }, { 210, 170, 70 } }, { price = 6000 }),
	cosmetic("livery", "mossback", "Mossback", { { 90, 120, 70 }, { 60, 50, 40 } }, { grant = "album" }),
	cosmetic("livery", "midnight", "Midnight Express", { { 30, 35, 70 }, { 200, 190, 255 } }, { grant = "login" }),
	cosmetic("lamp", "warm", "Warm Glow", { { 255, 200, 120 } }, { level = 1 }),
	cosmetic("lamp", "mint", "Mint", { { 160, 255, 200 } }, { level = 3 }),
	cosmetic("lamp", "rose", "Rose", { { 255, 160, 190 } }, { level = 8 }),
	cosmetic("lamp", "sky", "Sky Blue", { { 150, 200, 255 } }, { price = 1200 }),
	cosmetic("lamp", "gold", "Sunbeam Gold", { { 255, 220, 90 } }, { price = 4000 }),
	cosmetic("lamp", "moonlit", "Moonlit", { { 225, 235, 255 } }, { grant = "album" }),
	cosmetic("lamp", "aurora", "Aurora Beam", { { 120, 255, 200 }, { 170, 120, 255 } }, { grant = "login" }),
} :: { MetaRules.Cosmetic }
LanternConfig.SLOTS = { livery = "classic", lamp = "warm" }

LanternConfig.LOGIN = { -- H5: slots by distinct sign-in days this period, claimed in order
	week = {
		{ count = 1, tickets = 40 },
		{ count = 2, tickets = 60 },
		{ count = 3, tickets = 80 },
		{ count = 4, tickets = 100 },
		{ count = 5, cosmetic = "midnight", owned = 150 },
		{ count = 6, tickets = 120 },
		{ count = 7, tickets = 150 },
	},
	month = { -- the last slot drops to the month's length when that is under 30
		{ count = 3, tickets = 100 },
		{ count = 7, tickets = 150 },
		{ count = 12, tickets = 200 },
		{ count = 18, critter = "emberkit", owned = 250 },
		{ count = 22, tickets = 250 },
		{ count = 26, tickets = 300 },
		{ count = 30, cosmetic = "aurora", tickets = 400, owned = 400 },
	},
} :: { [string]: { LoginSlot } }
LanternConfig.MILESTONES = {
	{ count = 4, tickets = 200 },
	{ count = 8, cosmetic = "mossback" },
	{ count = 12, cosmetic = "moonlit", tickets = 1000 },
} :: { { count: number, tickets: number?, cosmetic: string? } }
LanternConfig.ROLES = {
	{ id = "stoker", stat = "stokes", tiers = { 30, 300, 1500 } },
	{ id = "lamplighter", stat = "puffs", tiers = { 100, 1000, 5000 } },
	{ id = "scout", stat = "loads", tiers = { 50, 500, 2500 } },
	{ id = "mender", stat = "mends", tiers = { 15, 150, 750 } },
} :: { Role }
LanternConfig.PINGS = {
	{ id = "coal", text = "Coal here!" },
	{ id = "critter", text = "Critter here!" },
	{ id = "help", text = "Help carry!" },
	{ id = "back", text = "Back to the train!" },
	{ id = "wisps", text = "Wisps there!" },
	{ id = "thanks", text = "Thanks!" },
}
LanternConfig.CREW = { max = 6, active = 180, activeMove = 10 }
LanternConfig.WEEKLY_SALT = 6006

local function find<T>(list: { T }, id: string): T?
	for _, row in list do
		if (row :: any).id == id then
			return row
		end
	end
	return nil
end

function LanternConfig.critter(id: string): Critter?
	return find(LanternConfig.CRITTERS, id)
end

function LanternConfig.tile(id: string): Tile?
	return find(LanternConfig.TILES, id)
end

function LanternConfig.cosmetic(id: string): MetaRules.Cosmetic?
	return find(LanternConfig.COSMETICS, id)
end

return LanternConfig
