--!strict
-- Neon Spire plaza rules (GDD D, decision 0009): the 12 x 8 grid, footprints and rotation,
-- placing, moving and selling items, Hype and the crowd size. Functions return new tables and
-- never mutate their inputs. No Roblox APIs; every input comes from the server.

local MetaRules = require("./MetaRules")
local SpireConfig = require("./SpireConfig")
local TowerRules = require("./TowerRules") -- copy and types only

local PlazaRules = {}

type Profile = SpireConfig.Profile
type Item = SpireConfig.Item

local PLAZA = SpireConfig.PLAZA
local HYPE = SpireConfig.HYPE

local function isInt(n: any): boolean
	return type(n) == "number" and n == math.floor(n)
end

function PlazaRules.footprint(id: string, r: number): (number, number)
	local item = SpireConfig.item(id)
	if item == nil then
		return 0, 0
	end
	if r % 2 == 1 then
		return item.d, item.w
	end
	return item.w, item.d
end

-- Covered cell keys x + 12 * y; (x, y) is the min-x, min-y corner.
function PlazaRules.cells(id: string, x: number, y: number, r: number): { number }
	local w, d = PlazaRules.footprint(id, r)
	local out = {}
	for cy = y, y + d - 1 do
		for cx = x, x + w - 1 do
			table.insert(out, cx + PLAZA.w * cy)
		end
	end
	return out
end

local function taken(p: Profile, ignoreUid: number?): { [number]: boolean }
	local out = {}
	for _, it in p.plaza.items do
		if it.u ~= ignoreUid then
			for _, key in PlazaRules.cells(it.id, it.x, it.y, it.r) do
				out[key] = true
			end
		end
	end
	return out
end

-- nil when the item fits at (x, y, r).
function PlazaRules.check(p: Profile, id: string, x: number, y: number, r: number, ignoreUid: number?): string?
	if SpireConfig.item(id) == nil then
		return "unknown"
	end
	if not (isInt(x) and isInt(y) and isInt(r)) or r < 0 or r > 3 then
		return "bounds"
	end
	local w, d = PlazaRules.footprint(id, r)
	if x < 0 or y < 0 or x + w > PLAZA.w or y + d > PLAZA.d then
		return "bounds"
	end
	for _, col in PLAZA.walkway do
		if col >= x and col < x + w then
			return "walkway"
		end
	end
	local used = taken(p, ignoreUid)
	for _, key in PlazaRules.cells(id, x, y, r) do
		if used[key] then
			return "occupied"
		end
	end
	return nil
end

function PlazaRules.unlocked(p: Profile, id: string): boolean
	local item = SpireConfig.item(id)
	if item == nil then
		return false
	end
	if item.decor then
		return MetaRules.levelFor(p.xp) >= (item.level or 1)
	end
	return #p.floors >= (item.floors or 0)
end

function PlazaRules.find(p: Profile, uid: number): Item?
	for _, it in p.plaza.items do
		if it.u == uid then
			return it
		end
	end
	return nil
end

-- Per id, total items, decor items.
function PlazaRules.counts(p: Profile): ({ [string]: number }, number, number)
	local per: { [string]: number } = {}
	local decor = 0
	for _, it in p.plaza.items do
		per[it.id] = (per[it.id] or 0) + 1
		local item = SpireConfig.item(it.id)
		if item and item.decor then
			decor += 1
		end
	end
	return per, #p.plaza.items, decor
end

-- Changes (D1, D2) ----------------------------------------------------------------------------

function PlazaRules.placeItem(p: Profile, id: string, x: number, y: number, r: number): (Profile, boolean, string?)
	local item = SpireConfig.item(id)
	if item == nil then
		return p, false, "unknown"
	elseif not PlazaRules.unlocked(p, id) then
		return p, false, "locked"
	end
	local per, total, decor = PlazaRules.counts(p)
	if item.max and (per[id] or 0) >= item.max then
		return p, false, "max"
	elseif total >= PLAZA.maxItems or (item.decor and decor >= PLAZA.maxDecor) then
		return p, false, "full"
	end
	local code = PlazaRules.check(p, id, x, y, r)
	if code then
		return p, false, code
	elseif p.coins < item.cost then
		return p, false, "credits"
	end
	local out = TowerRules.copy(p)
	out.coins -= item.cost
	table.insert(out.plaza.items, { u = out.plaza.nextUid, id = id, x = x, y = y, r = r, paid = item.cost })
	out.plaza.nextUid += 1
	return out, true, nil
end

function PlazaRules.moveItem(p: Profile, uid: number, x: number, y: number, r: number): (Profile, boolean, string?)
	local it = PlazaRules.find(p, uid)
	if it == nil then
		return p, false, "unknown"
	elseif it.x == x and it.y == y and it.r == r then
		return p, false, "same"
	end
	local code = PlazaRules.check(p, it.id, x, y, r, uid)
	if code then
		return p, false, code
	end
	local out = TowerRules.copy(p)
	local moved = PlazaRules.find(out, uid) :: Item
	moved.x, moved.y, moved.r = x, y, r
	return out, true, nil
end

function PlazaRules.sellItem(p: Profile, uid: number): (Profile, boolean, string?)
	local it = PlazaRules.find(p, uid)
	if it == nil then
		return p, false, "unknown"
	end
	local out = TowerRules.copy(p)
	for i, other in out.plaza.items do
		if other.u == uid then
			table.remove(out.plaza.items, i)
			break
		end
	end
	out.coins = math.min(SpireConfig.MAX_COINS, out.coins + math.floor(SpireConfig.REFUND * it.paid + 1e-9))
	return out, true, nil
end

-- Hype (D3) -----------------------------------------------------------------------------------

function PlazaRules.rawHype(p: Profile): number
	local total = 0
	for _, it in p.plaza.items do
		local item = SpireConfig.item(it.id)
		total += if item then item.hype else 0
	end
	return total
end

function PlazaRules.hypeCap(p: Profile): number
	return math.min(HYPE.perFloor * #p.floors, HYPE.cap)
end

function PlazaRules.hype(p: Profile): number
	return math.min(PlazaRules.rawHype(p), PlazaRules.hypeCap(p))
end

function PlazaRules.hypeMult(p: Profile): number
	return 1 + PlazaRules.hype(p) / 100
end

function PlazaRules.crowd(hype: number): number
	return math.min(HYPE.crowdMax, HYPE.crowdBase + math.floor(hype / HYPE.crowdPer))
end

-- Layout (lot space) --------------------------------------------------------------------------

-- y = 0 is the row nearest the tower.
function PlazaRules.cellCentre(x: number, y: number): TowerRules.Vec3
	return { x = -22 + PLAZA.cell * x, y = 0, z = -16 - PLAZA.cell * y }
end

function PlazaRules.itemCentre(id: string, x: number, y: number, r: number): TowerRules.Vec3
	local w, d = PlazaRules.footprint(id, r)
	return PlazaRules.cellCentre(x + (w - 1) / 2, y + (d - 1) / 2)
end

function PlazaRules.cellAt(pos: TowerRules.Vec3): (number?, number?)
	local x = math.floor((pos.x + 24) / PLAZA.cell)
	local y = math.floor((-pos.z - 14) / PLAZA.cell)
	if x < 0 or x >= PLAZA.w or y < 0 or y >= PLAZA.d then
		return nil, nil
	end
	return x, y
end

return PlazaRules
