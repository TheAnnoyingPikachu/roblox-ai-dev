--!strict
-- Pure Egg Garden plot rules (GDD C and D, decision 0008): income, offline coins, pads, beds,
-- buying and watering eggs, the pen, storage and release. Functions return new tables and never
-- mutate their inputs. No Roblox APIs; every input comes from the server.

local GardenConfig = require("./GardenConfig")
local MetaRules = require("./MetaRules")
local WorldRules = require("./WorldRules")

local GardenRules = {}

type Profile = GardenConfig.Profile
type Creature = GardenConfig.Creature
export type Vec3 = { x: number, y: number, z: number }
export type Pads = { [number]: number } -- pad index -> pending coins (float), server memory only

local MAX_COINS = GardenConfig.MAX_COINS

local function floor(x: number): number
	return math.floor(x + 1e-9)
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

local function emptyBed(): GardenConfig.Bed
	return { egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 }
end

function GardenRules.copy(p: Profile): Profile
	return deepCopy(p)
end

function GardenRules.level(p: Profile): number
	return MetaRules.levelFor(p.xp)
end

-- Income (C3) ---------------------------------------------------------------------------------

function GardenRules.rate(c: Creature): number
	local s, m, z = GardenConfig.species(c.s), GardenConfig.mutation(c.m), GardenConfig.size(c.z)
	if s == nil or m == nil or z == nil then
		return 0
	end
	return s.rate * m.mult * z.mult
end

function GardenRules.indexMult(p: Profile): number
	return 1 + GardenConfig.INDEX_BONUS * #p.index
end

function GardenRules.income(p: Profile): number
	local sum = 0
	for _, c in p.creatures do
		if c.placed > 0 then
			sum += GardenRules.rate(c)
		end
	end
	return sum * GardenRules.indexMult(p)
end

function GardenRules.offline(p: Profile, now: number): number
	if p.lastSeen >= now then
		return 0
	end
	local away = math.min(now - p.lastSeen, GardenConfig.OFFLINE.cap)
	return floor(GardenRules.income(p) * GardenConfig.OFFLINE.rate * away)
end

local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- "999", "1.2K", "3.4M", "5.6B", "1.5T": one decimal truncated, ".0" dropped.
function GardenRules.short(n: number): string
	for _, s in SUFFIXES do
		local unit = s[1] :: number
		if n >= unit then
			local tenths = floor(n / unit * 10)
			local text = if tenths % 10 == 0
				then string.format("%d", tenths // 10)
				else string.format("%.1f", tenths / 10)
			return text .. (s[2] :: string)
		end
	end
	return string.format("%d", floor(n))
end

function GardenRules.releaseValue(c: Creature): number
	return floor(GardenRules.rate(c) * GardenConfig.RELEASE_SECONDS)
end

-- Beds, pads and storage ----------------------------------------------------------------------

function GardenRules.bedState(p: Profile, bed: number, now: number): string
	if bed < 1 or bed > p.bedCount or p.beds[bed] == nil then
		return "locked"
	end
	local b = p.beds[bed]
	if b.egg == "" then
		return "empty"
	end
	-- A clock behind `planted` counts as just planted, so it is still growing (K).
	return if now >= b.ready and now >= b.planted then "ripe" else "growing"
end

function GardenRules.growFraction(p: Profile, bed: number, now: number): number
	local state = GardenRules.bedState(p, bed, now)
	if state == "ripe" then
		return 1
	elseif state ~= "growing" then
		return 0
	end
	local b = p.beds[bed]
	if now < b.planted or b.ready <= b.planted then
		return 0
	end
	return math.clamp((now - b.planted) / (b.ready - b.planted), 0, 1)
end

function GardenRules.firstEmptyBed(p: Profile): number?
	for i = 1, p.bedCount do
		if p.beds[i] and p.beds[i].egg == "" then
			return i
		end
	end
	return nil
end

function GardenRules.find(p: Profile, id: number): Creature?
	for _, c in p.creatures do
		if c.id == id then
			return c
		end
	end
	return nil
end

function GardenRules.freePad(p: Profile): number?
	local taken: { [number]: boolean } = {}
	for _, c in p.creatures do
		taken[c.placed] = true
	end
	for pad = 1, p.penSlots do
		if not taken[pad] then
			return pad
		end
	end
	return nil
end

function GardenRules.storageCount(p: Profile): number
	local n = 0
	for _, c in p.creatures do
		if c.placed == 0 then
			n += 1
		end
	end
	return n
end

function GardenRules.isFull(p: Profile): boolean
	return GardenRules.freePad(p) == nil and GardenRules.storageCount(p) >= GardenConfig.STORAGE
end

-- Eggs and watering (D1, D2) ------------------------------------------------------------------

function GardenRules.eggUnlocked(p: Profile, egg: string): boolean
	local e = type(egg) == "string" and GardenConfig.egg(egg)
	return if e and e.price ~= nil then GardenRules.level(p) >= e.level else false
end

function GardenRules.stockLeft(p: Profile, egg: string, now: number): number
	local e = type(egg) == "string" and GardenConfig.egg(egg)
	if not e or e.price == nil then
		return 0
	end
	if e.stock == nil then
		return math.huge
	end
	local window = WorldRules.stockWindow(now)
	local bought = if p.stock.w == window then p.stock.bought[egg] or 0 else 0
	return math.max(0, (WorldRules.stockFor(window)[egg] or 0) - bought)
end

-- D1 except the cart distance, which the server checks.
function GardenRules.buyEgg(p: Profile, egg: string, now: number): (Profile, boolean)
	local e = type(egg) == "string" and GardenConfig.egg(egg)
	local bed = GardenRules.firstEmptyBed(p)
	if not e or e.price == nil or bed == nil or not GardenRules.eggUnlocked(p, egg) then
		return p, false
	end
	if p.coins < e.price or GardenRules.stockLeft(p, egg, now) < 1 then
		return p, false
	end
	local out = GardenRules.copy(p)
	out.coins -= e.price
	if e.stock then
		local window = WorldRules.stockWindow(now)
		if out.stock.w ~= window then
			out.stock = { w = window, bought = {} }
		end
		out.stock.bought[egg] = (out.stock.bought[egg] or 0) + 1
	end
	out.beds[bed] = { egg = egg, planted = now, ready = now + e.grow, waters = 0, helps = 0, lastWater = 0 }
	return out, true
end

function GardenRules.canPlantPrize(p: Profile, egg: string): boolean
	return GardenRules.eggUnlocked(p, egg) and (p.prizeEggs[egg] or 0) >= 1 and GardenRules.firstEmptyBed(p) ~= nil
end

-- A won egg (decision 0012): the egg's own level gate, no price and no stock check.
function GardenRules.plantPrize(p: Profile, egg: string, now: number): (Profile, boolean)
	if not GardenRules.canPlantPrize(p, egg) then
		return p, false
	end
	local out = GardenRules.copy(p)
	local left = out.prizeEggs[egg] - 1
	out.prizeEggs[egg] = (if left > 0 then left else nil) :: any
	local ready = now + (GardenConfig.egg(egg) :: GardenConfig.Egg).grow
	out.beds[GardenRules.firstEmptyBed(p) :: number] =
		{ egg = egg, planted = now, ready = ready, waters = 0, helps = 0, lastWater = 0 }
	return out, true
end

function GardenRules.waterCut(egg: string): number
	local e = GardenConfig.egg(egg)
	return if e then floor(GardenConfig.WATER.cut * e.grow) else 0
end

function GardenRules.canWater(p: Profile, bed: number, now: number, helper: boolean): boolean
	if GardenRules.bedState(p, bed, now) ~= "growing" then
		return false
	end
	local b = p.beds[bed]
	local W = GardenConfig.WATER
	if b.waters + b.helps > 0 and now - b.lastWater < W.cooldown then
		return false
	end
	return if helper then b.helps < W.helpers else b.waters < W.owner
end

-- The bed change only; XP and quest progress are added by GardenProgress.
function GardenRules.water(p: Profile, bed: number, now: number, helper: boolean): (Profile, boolean)
	if not GardenRules.canWater(p, bed, now, helper) then
		return p, false
	end
	local out = GardenRules.copy(p)
	local b = out.beds[bed]
	b.ready = math.max(now, b.ready - GardenRules.waterCut(b.egg))
	if helper then
		b.helps += 1
	else
		b.waters += 1
	end
	b.lastWater = now
	return out, true
end

-- Beds and pen slots (C1, C2) ------------------------------------------------------------------

function GardenRules.nextBedCost(p: Profile): number?
	return if p.bedCount < GardenConfig.BEDS.max then GardenConfig.BED_COSTS[p.bedCount + 1] else nil
end

function GardenRules.buyBed(p: Profile): (Profile, boolean)
	local cost = GardenRules.nextBedCost(p)
	if cost == nil or p.coins < cost then
		return p, false
	end
	local out = GardenRules.copy(p)
	out.coins -= cost
	out.bedCount += 1
	out.beds[out.bedCount] = emptyBed()
	return out, true
end

function GardenRules.nextPenCost(p: Profile): number?
	local PEN = GardenConfig.PEN
	return if p.penSlots < PEN.max then PEN.first * 2 ^ (p.penSlots - PEN.start) else nil
end

function GardenRules.buyPenSlot(p: Profile): (Profile, boolean)
	local cost = GardenRules.nextPenCost(p)
	if cost == nil or p.coins < cost then
		return p, false
	end
	local out = GardenRules.copy(p)
	out.coins -= cost
	out.penSlots += 1
	return out, true
end

-- Creatures (C2, C4) --------------------------------------------------------------------------

function GardenRules.place(p: Profile, id: number): (Profile, boolean)
	local c = GardenRules.find(p, id)
	local pad = GardenRules.freePad(p)
	if c == nil or c.placed ~= 0 or pad == nil then
		return p, false
	end
	local out = GardenRules.copy(p);
	(GardenRules.find(out, id) :: Creature).placed = pad
	return out, true
end

function GardenRules.store(p: Profile, id: number): (Profile, boolean)
	local c = GardenRules.find(p, id)
	if c == nil or c.placed == 0 or GardenRules.storageCount(p) >= GardenConfig.STORAGE then
		return p, false
	end
	local out = GardenRules.copy(p);
	(GardenRules.find(out, id) :: Creature).placed = 0
	return out, true
end

function GardenRules.release(p: Profile, id: number): (Profile, boolean, number)
	local c = GardenRules.find(p, id)
	if c == nil or c.fav then
		return p, false, 0
	end
	local value = GardenRules.releaseValue(c)
	local out = GardenRules.copy(p)
	for i, other in out.creatures do
		if other.id == id then
			table.remove(out.creatures, i)
			break
		end
	end
	out.coins = math.min(MAX_COINS, out.coins + value)
	return out, true, value
end

function GardenRules.favourite(p: Profile, id: number): (Profile, boolean)
	if GardenRules.find(p, id) == nil then
		return p, false
	end
	local out = GardenRules.copy(p)
	local c = GardenRules.find(out, id) :: Creature
	c.fav = not c.fav
	return out, true
end

-- Pads (C3) -----------------------------------------------------------------------------------

function GardenRules.accrue(p: Profile, pads: Pads, dt: number): Pads
	local out: Pads = table.clone(pads)
	local mult = GardenRules.indexMult(p)
	for _, c in p.creatures do
		if c.placed > 0 then
			out[c.placed] = (out[c.placed] or 0) + GardenRules.rate(c) * mult * dt
		end
	end
	return out
end

function GardenRules.bankPad(pads: Pads, pad: number): (Pads, number)
	local pending = pads[pad] or 0
	local coins = math.max(0, floor(pending))
	local out: Pads = table.clone(pads)
	out[pad] = math.max(0, pending - coins)
	return out, coins
end

function GardenRules.unbanked(pads: Pads): number
	local sum = 0
	for _, v in pads do
		sum += v
	end
	return floor(sum)
end

function GardenRules.onPad(root: Vec3, pad: Vec3): boolean
	local P = GardenConfig.PAD
	return GardenRules.within(root, pad, P.radius) and math.abs(root.y - pad.y) <= P.height
end

function GardenRules.within(a: Vec3, b: Vec3, range: number): boolean
	local dx, dz = a.x - b.x, a.z - b.z
	return dx * dx + dz * dz <= range * range
end

return GardenRules
