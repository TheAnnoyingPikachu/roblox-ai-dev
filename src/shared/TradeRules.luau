--!strict
-- Pure Egg Garden trading (GDD V1, decision 0015): the state machine of one trade between two
-- friends, the fairness check, and the two idempotent profile changes (`give`, `undo`) plus the
-- heal that finishes a half-written trade at the next load. The server owns the timers, the
-- distance checks and the ledger store; nothing here decides who may talk to whom. Functions
-- return new tables and never mutate their inputs. No Roblox APIs.

local GardenConfig = require("./GardenConfig")
local GardenRules = require("./GardenRules")
local MetaRules = require("./MetaRules")

local TradeRules = {}

type Profile = GardenConfig.Profile
type Creature = GardenConfig.Creature
type TradeRecord = GardenConfig.TradeRecord

export type Side = { user: number, pick: number?, ready: boolean, confirmed: boolean }
export type State = "proposed" | "picking" | "hold" | "confirm" | "committing" | "done" | "cancelled"
-- at: when the current state expires (0 in committing, done, cancelled)
export type Trade = {
	state: State,
	a: Side,
	b: Side,
	at: number,
	id: string?,
	reason: string?,
	emoteAt: { [number]: number },
}
export type Ledger = {
	id: string,
	at: number,
	a: number,
	b: number,
	ca: Creature,
	cb: Creature,
	undoAt: number?,
	void: boolean?,
}
export type Action = "accept" | "cancel" | "confirm" | "pick" | "emote"

local TRADE = GardenConfig.TRADE
local LIVE = { proposed = true, picking = true, hold = true, confirm = true } -- states a cancel or a timer can end

local function side(user: number): Side
	return { user = user, pick = nil, ready = false, confirmed = false }
end

local function copyTrade(t: Trade): Trade
	return {
		state = t.state,
		a = table.clone(t.a),
		b = table.clone(t.b),
		at = t.at,
		id = t.id,
		reason = t.reason,
		emoteAt = table.clone(t.emoteAt),
	}
end

local function cancelled(t: Trade, reason: string): Trade
	local out = copyTrade(t)
	out.state = "cancelled"
	out.reason = reason
	out.at = 0
	return out
end

local function record(p: Profile, id: string): TradeRecord?
	for _, r in p.trades do
		if r.id == id then
			return r
		end
	end
	return nil
end

-- The state machine -------------------------------------------------------------------------

function TradeRules.new(a: number, b: number, now: number): Trade
	return {
		state = "proposed",
		a = side(a),
		b = side(b),
		at = now + TRADE.invite,
		id = nil,
		reason = nil,
		emoteAt = {},
	}
end

-- mine, theirs; nil when `user` is not in the trade.
function TradeRules.side(t: Trade, user: number): (Side?, Side?)
	if t.a.user == user then
		return t.a, t.b
	elseif t.b.user == user then
		return t.b, t.a
	end
	return nil, nil
end

function TradeRules.value(c: Creature): number
	return GardenRules.rate(c)
end

function TradeRules.fair(x: Creature, y: Creature): boolean
	local vx, vy = TradeRules.value(x), TradeRules.value(y)
	return math.min(vx, vy) >= TRADE.fair * math.max(vx, vy)
end

-- 0 fair; 1 when x's owner would give the more valuable creature; 2 when y's owner would.
function TradeRules.unfairTo(x: Creature, y: Creature): number
	if TradeRules.fair(x, y) then
		return 0
	end
	return if TradeRules.value(x) > TradeRules.value(y) then 1 else 2
end

-- Owned and not a favourite; the reason otherwise.
function TradeRules.tradable(p: Profile, id: number): (Creature?, string?)
	local c = GardenRules.find(p, id)
	if c == nil then
		return nil, "missing"
	elseif c.fav then
		return nil, "fav"
	end
	return c, nil
end

function TradeRules.tradesToday(p: Profile, today: number): number
	return if p.tradesToday.day == today then p.tradesToday.count else 0
end

function TradeRules.canTrade(p: Profile, today: number): boolean
	return TradeRules.tradesToday(p, today) < TRADE.perDay
end

-- The pure transitions of GDD V1.3. A refusal returns the trade unchanged with a reason; `emote`
-- never changes the state (ok true means the server forwards it).
function TradeRules.step(t: Trade, user: number, action: Action, arg: number?, now: number): (Trade, boolean, string?)
	local mine = TradeRules.side(t, user)
	if mine == nil then
		return t, false, "user"
	end
	if not LIVE[t.state] then
		return t, false, "state"
	end
	if action == "cancel" then
		return cancelled(t, if t.state == "proposed" and user == t.b.user then "declined" else "cancelled"), true, nil
	elseif action == "emote" then
		if type(arg) ~= "number" or arg ~= math.floor(arg) or arg < 1 or arg > TRADE.emotes then
			return t, false, "range"
		end
		local last = t.emoteAt[user]
		if last ~= nil and now - last < TRADE.emoteGap then
			return t, false, "gap"
		end
		local out = copyTrade(t)
		out.emoteAt[user] = now
		return out, true, nil
	end
	local out = copyTrade(t)
	local me: Side = if out.a.user == user then out.a else out.b
	local other: Side = if out.a.user == user then out.b else out.a
	if action == "accept" and out.state == "proposed" then
		if user ~= out.b.user then
			return t, false, "user"
		end
		out.state = "picking"
		out.at = now + TRADE.pick
	elseif action == "accept" and out.state == "picking" then
		if me.pick == nil or other.pick == nil then
			return t, false, "pick"
		end
		me.ready = true
		if other.ready then
			out.state = "hold"
			out.at = now + TRADE.hold
		end
	elseif action == "pick" and out.state == "picking" then
		if type(arg) ~= "number" then
			return t, false, "range"
		end
		me.pick = arg
		me.ready = false
		other.ready = false
	elseif action == "confirm" and out.state == "confirm" then
		me.confirmed = true
		if other.confirmed then
			out.state = "committing"
			out.at = 0
		end
	else
		return t, false, "state"
	end
	return out, true, nil
end

-- Timers: the hold bar ends into confirm; any other live state past `at` is cancelled "expired".
function TradeRules.tick(t: Trade, now: number): Trade
	if not LIVE[t.state] or now < t.at then
		return t
	end
	if t.state == "hold" then
		local out = copyTrade(t)
		out.state = "confirm"
		out.at = now + TRADE.confirm
		return out
	end
	return cancelled(t, "expired")
end

-- Both picks tradable, fair, both under the daily limit; else the reason and the side (1 = a,
-- 2 = b) the notice names.
function TradeRules.canCommit(pa: Profile, pb: Profile, t: Trade, today: number): (boolean, string?, number?)
	local ca, ra = TradeRules.tradable(pa, t.a.pick or 0)
	if ca == nil then
		return false, ra, 1
	end
	local cb, rb = TradeRules.tradable(pb, t.b.pick or 0)
	if cb == nil then
		return false, rb, 2
	end
	local unfair = TradeRules.unfairTo(ca, cb)
	if unfair ~= 0 then
		return false, "unfair", unfair
	end
	if not TradeRules.canTrade(pa, today) then
		return false, "limit", 1
	elseif not TradeRules.canTrade(pb, today) then
		return false, "limit", 2
	end
	return true, nil, nil
end

-- The record written to both ledger keys before any profile changes (V1.4 step 2).
function TradeRules.ledger(t: Trade, pa: Profile, pb: Profile, id: string, now: number): Ledger
	return {
		id = id,
		at = now,
		a = t.a.user,
		b = t.b.user,
		ca = table.clone(GardenRules.find(pa, t.a.pick or 0) :: Creature),
		cb = table.clone(GardenRules.find(pb, t.b.pick or 0) :: Creature),
	}
end

-- The profile changes ------------------------------------------------------------------------

local function sameCreature(a: Creature, b: Creature): boolean
	return a.id == b.id and a.s == b.s and a.m == b.m and a.z == b.z and a.c == b.c
end

-- Removes the creature with `id` and puts `incoming` (a fresh id, the same slot, its name kept)
-- in its place. Returns the new creature's id.
local function swap(out: Profile, id: number, incoming: Creature): number
	local newId = out.nextId
	for i, c in out.creatures do
		if c.id == id then
			local fresh = GardenRules.newCreature(newId, incoming.s, incoming.m, incoming.z, incoming.c, c.placed)
			fresh.n = incoming.n
			out.creatures[i] = fresh
			break
		end
	end
	out.nextId += 1
	return newId
end

-- V1.4 step 3 for one profile. Idempotent on the trade id; unchanged when the creature this
-- player gives is not there as the ledger recorded it (the server warns). Touches no index, xp,
-- coins or quest stat.
function TradeRules.give(p: Profile, user: number, L: Ledger, today: number): Profile
	if record(p, L.id) then
		return p
	end
	local mine, theirs, with
	if user == L.a then
		mine, theirs, with = L.ca, L.cb, L.b
	elseif user == L.b then
		mine, theirs, with = L.cb, L.ca, L.a
	else
		return p
	end
	local have = GardenRules.find(p, mine.id)
	if have == nil or have.fav or not sameCreature(have, mine) then
		return p
	end
	local out = GardenRules.copy(p)
	local gotId = swap(out, mine.id, theirs)
	table.insert(out.trades, {
		id = L.id,
		at = L.at,
		with = with,
		gave = table.clone(mine),
		got = table.clone(theirs),
		gotId = gotId,
		undone = false,
	})
	while #out.trades > TRADE.kept do
		table.remove(out.trades, 1)
	end
	-- A heal may apply an older day's trade after today's count began: it never resets today.
	if today > out.tradesToday.day then
		out.tradesToday = { day = today, count = 0 }
	end
	if today == out.tradesToday.day then
		out.tradesToday.count += 1
	end
	return out
end

-- V1.5 on one profile: the record is there, not undone, within the window, and the creature it
-- got (by gotId) is still here. A favourite lock on it does not block the return.
function TradeRules.canUndo(p: Profile, id: string, now: number): (boolean, string?)
	local r = record(p, id)
	if r == nil then
		return false, "missing"
	elseif r.undone then
		return false, "undone"
	elseif now - r.at > TRADE.undo then
		return false, "late"
	elseif GardenRules.find(p, r.gotId) == nil then
		return false, "released"
	end
	return true, nil
end

-- Idempotent on `undone`; unchanged when the got creature is gone. The returning creature takes
-- the slot the leaving one had. The trade still counts towards the day.
function TradeRules.undo(p: Profile, user: number, L: Ledger): Profile
	local r = record(p, L.id)
	if (user ~= L.a and user ~= L.b) or r == nil or r.undone or GardenRules.find(p, r.gotId) == nil then
		return p
	end
	local out = GardenRules.copy(p)
	swap(out, r.gotId, r.gave);
	(record(out, L.id) :: TradeRecord).undone = true
	return out
end

-- V1.4 step 4: finishes what a crash left half-written. `mine` is this player's ledger key;
-- `confirmed(L)` is the counterpart-ledger lookup the server resolved before this apply (called
-- only for records missing from `trades`). Records older than the oldest kept are ignored when
-- the list is at its cap.
function TradeRules.heal(
	p: Profile,
	user: number,
	mine: { Ledger },
	confirmed: (Ledger) -> boolean,
	_now: number -- kept for the 3.10 signature; the heal has no timer
): Profile
	local list = table.clone(mine)
	table.sort(list, function(x, y)
		return x.at < y.at
	end)
	local oldest = if #p.trades >= TRADE.kept then p.trades[1].at else -1
	local out = p
	for _, L in list do
		if L.void or L.at < oldest then
			continue
		end
		if record(out, L.id) == nil then
			if not confirmed(L) then
				continue
			end
			out = TradeRules.give(out, user, L, MetaRules.dayOf(L.at))
		end
		local r = record(out, L.id)
		if L.undoAt and r and not r.undone then
			out = TradeRules.undo(out, user, L)
		end
	end
	return out
end

-- The `trade` Fx payload (architecture 5.1). `names` and `creatures` are keyed by UserId; the
-- server passes each side's current pick (or nil) and adds `record` itself.
function TradeRules.status(t: Trade, names: { [number]: string }, creatures: { [number]: Creature? }): { [string]: any }
	local function view(s: Side): { [string]: any }
		local c = creatures[s.user]
		return {
			user = s.user,
			name = names[s.user],
			ready = s.ready,
			confirmed = s.confirmed,
			pick = if c
				then { id = c.id, s = c.s, m = c.m, z = c.z, c = c.c, n = c.n, rate = GardenRules.rate(c) }
				else nil,
		}
	end
	return { state = t.state, id = t.id, reason = t.reason, at = t.at, a = view(t.a), b = view(t.b) }
end

return TradeRules
