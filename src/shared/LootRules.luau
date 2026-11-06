--!strict
-- Lantern Express stops and critter rolls (architecture lantern 3.3, GDD C3, H4): how many items a
-- stop holds, which tile it is, where each item lies, and which critter each crate holds. Every
-- roll is seeded (Rng) and made once, when the stop is built, so a save change never re-rolls.
-- Functions return new tables. No Roblox APIs.

local LanternConfig = require("./LanternConfig")
local Rng = require("./Rng")

local LootRules = {}

type Vec3 = LanternConfig.Vec3
type Line = LanternConfig.Line
type Rarity = LanternConfig.Rarity

export type Item = {
	id: number,
	kind: LanternConfig.ItemKind,
	site: number, -- index into the tile's `big` or `small` sites
	big: boolean,
	pos: Vec3, -- stop frame
	species: string?,
	rarity: Rarity?,
	state: "free" | "carried" | "loaded" | "lost",
	by: number?, -- first carrier (UserId)
	helper: number?, -- second carrier of a critter crate
}
export type Stop = { tile: string, line: Line, leg: number, index: number, n: number, items: { [number]: Item } }

local LINE_CODE = { forest = 1, lake = 2 }

function LootRules.counts(n: number): { coal: number, parts: number, oil: number, supply: number, critter: number }
	n = math.clamp(math.floor(n), 1, LanternConfig.CREW.max)
	return {
		coal = 6 + 3 * n,
		parts = 2 + n,
		oil = 2 + n // 2,
		supply = 1 + n // 2,
		critter = 1 + math.ceil(n / 2),
	}
end

local function shuffle<T>(rng: Rng.State, list: { T }): ({ T }, Rng.State)
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j
		j, rng = Rng.int(rng, 1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out, rng
end

-- One seeded order of the line's six tiles per leg, so the leg's three stops never repeat a tile.
function LootRules.tileFor(seed: number, leg: number, index: number, line: Line): string
	local order = shuffle(Rng.seed(seed, leg, LINE_CODE[line]), LanternConfig.LINE_TILES[line])
	return order[(index - 1) % #order + 1]
end

local function row(far: boolean, line: Line, leg: number): { number }
	if not far then
		return LanternConfig.ODDS.near
	end
	return if leg >= 3 then LanternConfig.ODDS.farLeg3[line] else LanternConfig.ODDS.far[line]
end

function LootRules.rarity(rng: Rng.State, far: boolean, line: Line, leg: number): (Rarity, Rng.State)
	local r
	r, rng = Rng.int(rng, 0, 9999)
	local odds = row(far, line, leg)
	for i, bp in odds do
		if r < bp then
			return LanternConfig.RARITIES[i], rng
		end
		r -= bp
	end
	return LanternConfig.RARITIES[1], rng -- unreachable: every row sums to 10,000
end

-- The species a crate of `rarity` can hold here: that rarity's species on the line and the tile,
-- else on the line (GDD H4). CRITTERS order; the Ember Kit ("exclusive") never appears.
local function pool(rarity: Rarity, line: Line, tile: string): { string }
	local onLine, onTile = {}, {}
	for _, c in LanternConfig.CRITTERS do
		if c.rarity == rarity and table.find(c.lines, line) then
			table.insert(onLine, c.id)
			if table.find(c.tiles, tile) then
				table.insert(onTile, c.id)
			end
		end
	end
	return if #onTile > 0 then onTile else onLine
end

function LootRules.species(rng: Rng.State, rarity: Rarity, line: Line, tile: string, _leg: number): (string, Rng.State)
	local ids = pool(rarity, line, tile)
	local i
	i, rng = Rng.int(rng, 1, #ids)
	return ids[i], rng
end

-- Species basis points for one crate band; each rarity's share is split evenly, its remainder
-- going to the first species of that rarity in CRITTERS order, so the total is exactly 10,000.
function LootRules.odds(line: Line, leg: number, tile: string, far: boolean): { [string]: number }
	local out: { [string]: number } = {}
	for i, bp in row(far, line, leg) do
		if bp > 0 then
			local ids = pool(LanternConfig.RARITIES[i], line, tile)
			local each = bp // #ids
			for _, id in ids do
				out[id] = (out[id] or 0) + each
			end
			out[ids[1]] += bp - each * #ids
		end
	end
	return out
end

function LootRules.build(seed: number, leg: number, index: number, line: Line, n: number, first: boolean): Stop
	local rng = Rng.seed(seed, leg * 10 + index, n)
	local tileId = LootRules.tileFor(seed, leg, index, line)
	local tile = LanternConfig.tile(tileId) :: LanternConfig.Tile
	local counts = LootRules.counts(n)
	local items: { [number]: Item } = {}
	local function add(kind: LanternConfig.ItemKind, site: number, big: boolean, pos: Vec3): Item
		local item: Item = { id = #items + 1, kind = kind, site = site, big = big, pos = pos, state = "free" }
		items[item.id] = item
		return item
	end
	local bigOrder = {}
	for i in tile.big do
		table.insert(bigOrder, i)
	end
	bigOrder, rng = shuffle(rng, bigOrder)
	if first then -- stop 1 of a run: the first critter crate on the 22-stud site (GDD C3)
		table.remove(bigOrder, table.find(bigOrder, 1) :: number)
		table.insert(bigOrder, 1, 1)
	end
	for k = 1, counts.critter + counts.supply do
		local site = bigOrder[k]
		local pos = tile.big[site]
		local item = add(if k <= counts.critter then "critter" else "supply", site, true, table.clone(pos))
		if item.kind == "critter" then
			local rarity
			rarity, rng = LootRules.rarity(rng, pos.z >= LanternConfig.NEAR, line, leg)
			item.rarity = rarity
			item.species, rng = LootRules.species(rng, rarity, line, tileId, leg)
		end
	end
	local smallOrder = {}
	for i in tile.small do
		table.insert(smallOrder, i)
	end
	smallOrder, rng = shuffle(rng, smallOrder)
	local k = 0
	for _, kind in { "coal", "parts", "oil" } :: { LanternConfig.ItemKind } do
		for _ = 1, (counts :: any)[kind] do
			local site = smallOrder[k % #smallOrder + 1]
			local slot = k // #smallOrder -- 0, 1, 2: at most 3 a site, 1 stud apart
			local at = tile.small[site]
			add(kind, site, false, { x = at.x + ({ 0, 1, -1 })[slot + 1], y = at.y, z = at.z })
			k += 1
		end
	end
	return { tile = tileId, line = line, leg = leg, index = index, n = n, items = items }
end

return LootRules
