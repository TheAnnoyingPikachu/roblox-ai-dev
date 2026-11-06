--!strict
-- Lantern Express carrying (architecture lantern 3.4, GDD C2, D, J): picking items up (three small
-- or one big), help-carrying a critter crate, dropping, loading at the train, being caught by the
-- fog and the stop closing at departure. Nothing here is earned: an item is only paid for when
-- `load` returns it. Functions return new tables and never mutate their inputs. No Roblox APIs.

local LanternConfig = require("./LanternConfig")
local LootRules = require("./LootRules")

local CarryRules = {}

type Stop = LootRules.Stop
type Item = LootRules.Item
type Vec3 = LanternConfig.Vec3
export type Carry = { small: { number }, big: number? } -- item ids; the first carrier's hands
export type Carries = { [number]: Carry } -- by UserId
-- One carrier's G4 samples (stop or world frame, only x and z count): the last sample and its time,
-- the studs the carrier may still cover (`budget`) and the last position that passed.
export type Pace = { last: Vec3, at: number, budget: number, valid: Vec3 }

local MAX_SMALL = 3
local SPREAD = { 0, 1, -1 }

local function copyStop(stop: Stop): Stop
	local out = table.clone(stop)
	out.items = {}
	for id, item in stop.items do
		out.items[id] = table.clone(item)
	end
	return out
end

local function copyCarries(carries: Carries): Carries
	local out: Carries = {}
	for userId, c in carries do
		out[userId] = { small = table.clone(c.small), big = c.big }
	end
	return out
end

-- The crate userId holds the second handle of, if any.
local function helping(stop: Stop, userId: number): Item?
	for _, item in stop.items do
		if item.state == "carried" and item.helper == userId then
			return item
		end
	end
	return nil
end

local function busy(stop: Stop, carries: Carries, userId: number): boolean
	local c = carries[userId]
	return helping(stop, userId) ~= nil or (c ~= nil and (c.big ~= nil or #c.small > 0))
end

function CarryRules.canPick(stop: Stop, carries: Carries, userId: number, itemId: number): (boolean, string?)
	local item = stop.items[itemId]
	if item == nil or item.state == "loaded" or item.state == "lost" then
		return false, "gone"
	elseif item.state == "carried" then
		return false, "taken"
	end
	local c = carries[userId]
	if helping(stop, userId) or (c and c.big) then
		return false, "hands"
	end
	local held = if c then #c.small else 0
	if item.big and held > 0 then
		return false, "big"
	elseif not item.big and held >= MAX_SMALL then
		return false, "full"
	end
	return true, nil
end

function CarryRules.pick(stop: Stop, carries: Carries, userId: number, itemId: number): (Stop, Carries)
	if not CarryRules.canPick(stop, carries, userId, itemId) then
		return stop, carries
	end
	local out, hands = copyStop(stop), copyCarries(carries)
	local item = out.items[itemId]
	item.state, item.by, item.helper = "carried", userId, nil
	local c = hands[userId] or { small = {} }
	if item.big then
		c.big = itemId
	else
		table.insert(c.small, itemId)
	end
	hands[userId] = c
	return out, hands
end

function CarryRules.canHelp(stop: Stop, carries: Carries, userId: number, itemId: number): (boolean, string?)
	local item = stop.items[itemId]
	if item == nil or item.kind ~= "critter" or item.state ~= "carried" then
		return false, "gone"
	elseif item.by == userId or item.helper ~= nil then
		return false, "taken"
	elseif busy(stop, carries, userId) then
		return false, "hands"
	end
	return true, nil
end

function CarryRules.help(stop: Stop, carries: Carries, userId: number, itemId: number): (Stop, Carries)
	if not CarryRules.canHelp(stop, carries, userId, itemId) then
		return stop, carries
	end
	local out = copyStop(stop)
	out.items[itemId].helper = userId
	return out, carries
end

-- The helper lets go (break distance, sits, leaves or is caught); the first carrier keeps the crate.
function CarryRules.letGo(stop: Stop, helperId: number): Stop
	if helping(stop, helperId) == nil then
		return stop
	end
	local out = copyStop(stop)
	for _, item in out.items do
		if item.state == "carried" and item.helper == helperId then
			item.helper = nil
		end
	end
	return out
end

-- Everything userId carries lies free at `at` (stop frame), small items 1 stud apart; a helper
-- only lets go. Anyone may pick the items up again until the train leaves.
function CarryRules.drop(stop: Stop, carries: Carries, userId: number, at: Vec3): (Stop, Carries)
	local out = CarryRules.letGo(stop, userId)
	local c = carries[userId]
	if c == nil then
		return out, carries
	end
	out = if out == stop then copyStop(stop) else out
	local hands = copyCarries(carries)
	hands[userId] = nil
	local ids = table.clone(c.small)
	if c.big then
		table.insert(ids, c.big)
	end
	for i, id in ids do
		local item = out.items[id]
		item.state, item.by, item.helper = "free", nil, nil
		item.pos = { x = at.x + SPREAD[(i - 1) % 3 + 1], y = at.y, z = at.z }
	end
	return out, hands
end

-- Loads everything userId carries as first carrier. A coal sack needs bunker room (coalRoom > 0,
-- each sack using ITEMS.coal.coal of it); one that does not fit stays carried. Returns the loaded
-- items (copies), which the caller pays for.
function CarryRules.load(stop: Stop, carries: Carries, userId: number, coalRoom: number): (Stop, Carries, { Item })
	local c = carries[userId]
	if c == nil then
		return stop, carries, {}
	end
	local out, hands = copyStop(stop), copyCarries(carries)
	local loaded, kept = {}, {}
	local ids = table.clone(c.small)
	if c.big then
		table.insert(ids, c.big)
	end
	for _, id in ids do
		local item = out.items[id]
		if item.kind == "coal" and coalRoom <= 0 then
			table.insert(kept, id)
		else
			if item.kind == "coal" then
				coalRoom -= LanternConfig.ITEMS.coal.coal :: number
			end
			item.state, item.helper = "loaded", nil
			table.insert(loaded, table.clone(item))
		end
	end
	hands[userId] = if #kept > 0 then { small = kept } else nil
	return out, hands, loaded
end

-- Caught by the fog: as drop, at the catch point behind the fog front.
function CarryRules.catch(stop: Stop, carries: Carries, userId: number, at: Vec3): (Stop, Carries)
	return CarryRules.drop(stop, carries, userId, at)
end

-- Departure: every free or carried item is gone for this run (a critter goes back to its stop);
-- loaded items stay loaded.
function CarryRules.close(stop: Stop, _carries: Carries): (Stop, Carries)
	local out = copyStop(stop)
	for _, item in out.items do
		if item.state == "free" or item.state == "carried" then
			item.state, item.by, item.helper = "lost", nil, nil
		end
	end
	return out, {}
end

local function flat(a: Vec3, b: Vec3): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- The G4 speed check for one carrier, run every server tick before that tick's loads (QA M2). `p` is
-- nil for the first sample, taken where the item was picked up. Distance over time (QA r3): the
-- carrier earns mult x `speed` studs a second, banked up to `lag` seconds of carrying plus `slack`
-- (starting at `slack`), and every move spends it. So an honest carrier whose position the server
-- saw frozen for up to `lag` + slack / speed seconds catches up, while anything faster than mult x
-- speed runs the bank dry within seconds. Returns the new pace, whether the move passed (false: drop
-- the load at `pace.valid`, the last position that passed) and whether the carrier may load this
-- tick: never on the pick-up sample, so a carrier must be checked once before a load.
function CarryRules.pace(p: Pace?, pos: Vec3, speed: number, now: number): (Pace, boolean, boolean)
	local check = LanternConfig.CARRY_CHECK
	if p == nil then
		return { last = pos, at = now, budget = check.slack, valid = pos }, true, false
	end
	local bank = math.min(speed * check.lag + check.slack, p.budget + check.mult * speed * math.max(0, now - p.at))
	local left = bank - flat(pos, p.last)
	local ok = left >= 0
	return { last = pos, at = now, budget = math.max(0, left), valid = if ok then pos else p.valid }, ok, ok
end

function CarryRules.speed(stop: Stop, carries: Carries, userId: number): number
	local move = LanternConfig.MOVE
	if helping(stop, userId) then
		return move.critterDuo
	end
	local c = carries[userId]
	if c and c.big then
		local item = stop.items[c.big]
		if item.kind == "critter" then
			return if item.helper then move.critterDuo else move.critterSolo
		end
		return move.big
	end
	return if c and #c.small > 0 then move.small else move.walk
end

return CarryRules
