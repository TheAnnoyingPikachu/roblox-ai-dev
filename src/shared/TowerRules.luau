--!strict
-- Neon Spire tower rules (GDD C, decision 0009): floor and module costs, power, Ad Agency
-- stacking, the five tower changes and the lot-space layout. Functions return new tables and
-- never mutate their inputs. No Roblox APIs; every input comes from the server.

local MarketRules = require("./MarketRules")
local SpireConfig = require("./SpireConfig")

local TowerRules = {}

type Profile = SpireConfig.Profile
export type Vec3 = { x: number, y: number, z: number }
-- Result = (Profile, boolean, string?): Luau cannot alias a type pack, so it is spelled out.

local SLOTS = SpireConfig.SLOTS
local MAX_COINS = SpireConfig.MAX_COINS

local function floor(x: number): number
	return math.floor(x + 1e-9)
end

local function isInt(n: any): boolean
	return type(n) == "number" and n == math.floor(n)
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

function TowerRules.copy(p: Profile): Profile
	return deepCopy(p)
end

-- Costs ---------------------------------------------------------------------------------------

function TowerRules.floorCost(n: number): number?
	return SpireConfig.FLOOR_COST[n]
end

-- Price to reach `level`: 1 = buy, 2..5 = upgrade from level - 1.
function TowerRules.moduleCost(dept: string, level: number, event: string): number?
	local d = SpireConfig.dept(dept)
	if d == nil or not isInt(level) or level < 1 or level > 5 then
		return nil
	end
	local base = if level == 1 then d.cost else d.cost * SpireConfig.UP[level - 1]
	return MarketRules.price(base, event)
end

-- The undiscounted total paid for a module at `level` (the cap on `spent`).
function TowerRules.spentMax(dept: string, level: number): number
	local d = SpireConfig.dept(dept)
	if d == nil or level < 1 then
		return 0
	end
	local mult = 1
	for i = 1, math.min(level, 5) - 1 do
		mult += SpireConfig.UP[i]
	end
	return d.cost * mult
end

-- Power and stacking (C5, C6) ----------------------------------------------------------------

function TowerRules.supply(p: Profile): number
	local total = SpireConfig.BASE_SUPPLY
	for _, f in p.floors do
		if f.d == "fusion" then
			for _, level in f.m do
				if level > 0 then
					total += SpireConfig.FUSION_SUPPLY[level]
				end
			end
		end
	end
	return total
end

function TowerRules.draw(p: Profile): number
	local total = 0
	for _, f in p.floors do
		local d = SpireConfig.dept(f.d)
		if d and d.draw > 0 then
			for _, level in f.m do
				if level > 0 then
					total += d.draw
				end
			end
		end
	end
	return total
end

function TowerRules.moduleCount(p: Profile, n: number): number
	local f = if n >= 2 then p.floors[n] else nil
	local count = 0
	if f then
		for _, level in f.m do
			if level > 0 then
				count += 1
			end
		end
	end
	return count
end

function TowerRules.activeAd(p: Profile, n: number): boolean
	local f = p.floors[n]
	return f ~= nil and f.d == "ad" and TowerRules.moduleCount(p, n) >= 1
end

function TowerRules.floorMult(p: Profile, n: number, event: string): number
	local f = p.floors[n]
	if f == nil or n < 2 or f.d == "ad" or f.d == "fusion" or f.d == SpireConfig.LOBBY then
		return 1
	end
	local k = if event == "neon" then SpireConfig.AD.neon else SpireConfig.AD.boost
	local neighbours = (if TowerRules.activeAd(p, n - 1) then 1 else 0)
		+ (if TowerRules.activeAd(p, n + 1) then 1 else 0)
	return 1 + k * neighbours
end

function TowerRules.deptAllowed(dept: string, n: number): boolean
	local d = SpireConfig.dept(dept)
	return d ~= nil and isInt(n) and n >= 2 and n <= SpireConfig.MAX_FLOORS and n >= d.unlock
end

function TowerRules.hotSlots(p: Profile): { { floor: number, slot: number } }
	local out = {}
	for n = 2, #p.floors do
		local f = p.floors[n]
		if f.d ~= "fusion" then
			for slot = 1, SLOTS do
				if f.m[slot] > 0 then
					table.insert(out, { floor = n, slot = slot })
				end
			end
		end
	end
	return out
end

-- Changes (C2, C4, C5) ------------------------------------------------------------------------

local function ownedFloor(p: Profile, n: number): boolean
	return isInt(n) and n >= 2 and n <= #p.floors
end

local function validSlot(p: Profile, n: number, slot: number): boolean
	return ownedFloor(p, n) and isInt(slot) and slot >= 1 and slot <= SLOTS
end

local function emptyFloor(dept: string): SpireConfig.Floor
	return { d = dept, m = { 0, 0, 0, 0 }, s = { 0, 0, 0, 0 } }
end

function TowerRules.buyFloor(p: Profile, dept: string): (Profile, boolean, string?)
	local n = #p.floors + 1
	if #p.floors >= SpireConfig.MAX_FLOORS then
		return p, false, "max"
	elseif SpireConfig.dept(dept) == nil then
		return p, false, "unknown"
	elseif not TowerRules.deptAllowed(dept, n) then
		return p, false, "locked"
	end
	local cost = TowerRules.floorCost(n) or 0
	if p.coins < cost then
		return p, false, "credits"
	end
	local out = TowerRules.copy(p)
	out.coins -= cost
	table.insert(out.floors, emptyFloor(dept))
	return out, true, nil
end

function TowerRules.refitFloor(p: Profile, n: number, dept: string): (Profile, boolean, string?)
	if not ownedFloor(p, n) then
		return p, false, "floor"
	elseif SpireConfig.dept(dept) == nil then
		return p, false, "unknown"
	elseif p.floors[n].d == dept then
		return p, false, "same"
	elseif not TowerRules.deptAllowed(dept, n) then
		return p, false, "locked"
	elseif TowerRules.moduleCount(p, n) > 0 then
		return p, false, "modules"
	end
	local out = TowerRules.copy(p)
	out.floors[n] = emptyFloor(dept)
	return out, true, nil
end

function TowerRules.buyModule(p: Profile, n: number, slot: number, event: string): (Profile, boolean, string?)
	if not validSlot(p, n, slot) then
		return p, false, "floor"
	end
	local f = p.floors[n]
	if f.m[slot] > 0 then
		return p, false, "occupied"
	end
	local d = SpireConfig.dept(f.d) :: SpireConfig.Dept
	local price = TowerRules.moduleCost(f.d, 1, event) :: number
	if p.coins < price then
		return p, false, "credits"
	elseif d.draw > 0 and TowerRules.draw(p) + d.draw > TowerRules.supply(p) then
		return p, false, "power"
	end
	local out = TowerRules.copy(p)
	out.coins -= price
	out.floors[n].m[slot] = 1
	out.floors[n].s[slot] = price
	return out, true, nil
end

function TowerRules.upgradeModule(p: Profile, n: number, slot: number, event: string): (Profile, boolean, string?)
	if not validSlot(p, n, slot) then
		return p, false, "floor"
	end
	local f = p.floors[n]
	local level = f.m[slot]
	if level == 0 then
		return p, false, "empty"
	elseif level >= 5 then
		return p, false, "max"
	end
	local price = TowerRules.moduleCost(f.d, level + 1, event) :: number
	if p.coins < price then
		return p, false, "credits"
	end
	local out = TowerRules.copy(p)
	out.coins -= price
	out.floors[n].m[slot] = level + 1
	out.floors[n].s[slot] += price
	return out, true, nil
end

function TowerRules.sellModule(p: Profile, n: number, slot: number): (Profile, boolean, string?)
	if not validSlot(p, n, slot) then
		return p, false, "floor"
	end
	local f = p.floors[n]
	if f.m[slot] == 0 then
		return p, false, "empty"
	end
	local out = TowerRules.copy(p)
	out.floors[n].m[slot] = 0
	out.floors[n].s[slot] = 0
	if f.d == "fusion" and TowerRules.draw(out) > TowerRules.supply(out) then
		return p, false, "needed"
	end
	out.coins = math.min(MAX_COINS, out.coins + floor(SpireConfig.REFUND * f.s[slot]))
	return out, true, nil
end

-- Layout (lot space) --------------------------------------------------------------------------

TowerRules.LOBBY_HEIGHT = 20
TowerRules.FLOOR_HEIGHT = 14
TowerRules.TOWER = { x = 0, z = 22, size = 36 }
TowerRules.LIFT = { radius = 4, height = 10 }

-- Floor surface; n = #floors + 1 is the roof.
function TowerRules.floorY(n: number): number
	if n <= 1 then
		return 0
	end
	return TowerRules.LOBBY_HEIGHT + TowerRules.FLOOR_HEIGHT * (n - 2)
end

local SLOT_OFFSETS: { Vec3 } = {
	{ x = -10, y = 0, z = 12 },
	{ x = 10, y = 0, z = 12 },
	{ x = -10, y = 0, z = 32 },
	{ x = 10, y = 0, z = 32 },
}

function TowerRules.slotOffset(slot: number): Vec3
	local o = SLOT_OFFSETS[slot]
	return { x = o.x, y = o.y, z = o.z }
end

function TowerRules.slotPos(n: number, slot: number): Vec3
	local o = TowerRules.slotOffset(slot)
	return { x = o.x, y = TowerRules.floorY(n), z = o.z }
end

function TowerRules.liftZone(n: number): (Vec3, number, number)
	return { x = TowerRules.TOWER.x, y = TowerRules.floorY(n), z = TowerRules.TOWER.z },
		TowerRules.LIFT.radius,
		TowerRules.LIFT.height
end

function TowerRules.liftAt(p: Profile, pos: Vec3): number?
	local dx, dz = pos.x - TowerRules.TOWER.x, pos.z - TowerRules.TOWER.z
	if dx * dx + dz * dz > TowerRules.LIFT.radius ^ 2 then
		return nil
	end
	for n = 1, #p.floors + 1 do
		local h = pos.y - TowerRules.floorY(n)
		if h >= 0 and h <= TowerRules.LIFT.height then
			return n
		end
	end
	return nil
end

function TowerRules.liftTarget(p: Profile, arg: string): number?
	if arg == "roof" then
		return #p.floors + 1
	end
	local n = if string.match(arg, "^%d+$") then tonumber(arg) else nil
	return if n and n >= 1 and n <= #p.floors then n else nil
end

function TowerRules.standAt(n: number): Vec3
	return { x = 0, y = TowerRules.floorY(n) + 3, z = 15 }
end

return TowerRules
