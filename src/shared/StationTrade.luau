--!strict
-- Animal Stations trading (decision 0084): two players in one server swap animals. Each puts up to
-- MAX of their own animals in the trade; when both say ready the server swaps them. Pure: the server
-- keeps the trade and calls `swap` on both saves. (Egg Garden's trading is TradeRules: another game.)
--
-- What moves is a copy of each animal as it is (its stats, levels, variant, rainbow coat), under a
-- new id in the save it lands in. An animal that is training cannot be offered; one that leaves also
-- leaves the team, and the Titan's slot, which falls to another Titan if there is one.

--
-- Safe trading (decision 0099): trading opens at player level MIN_LEVEL, a player finishes at most PER_DAY
-- trades a UTC day, a locked animal never goes in a trade, and each finished trade is remembered by its id
-- (`commit`), so the server's ledger can apply a trade a crash cut short, once and only once.

local BattleRules = require("./BattleRules")
local StationConfig = require("./StationConfig")
local StationProgress = require("./StationProgress")
local StationRules = require("./StationRules")

local StationTrade = {}

-- trading is switched off until its hardening is done (SHANNON, 2026-11-24): the Trade button is hidden and every
-- trade request refused; true turns it back on
StationTrade.ON = false
StationTrade.MAX = 4 -- animals each side may put in one trade
StationTrade.MIN_LEVEL = 5
StationTrade.PER_DAY = 20
StationTrade.READY_DELAY = 3 -- seconds Ready waits after any change to the trade
StationTrade.CONFIRM_SECONDS = 5 -- once both are ready, Confirm waits this long
StationTrade.ASK_GAP = 10 -- seconds between two requests to the same player
StationTrade.HEAL_SECONDS = 12 * 3600 -- the ledger's trades younger than this are checked at login
StationTrade.LEDGER_KEEP = 60 -- a player's ledger key keeps this many sides, newest first

-- The ledger key's new list after writing `side` at `now` (TradeLedger): newest first, LEDGER_KEEP at most.
function StationTrade.ledgerAdd(list: { any }, side: any, now: number): { any }
	local entry = table.clone(side)
	entry.at = now
	table.insert(list, 1, entry)
	while #list > StationTrade.LEDGER_KEEP do
		table.remove(list)
	end
	return list
end

-- The ledger key's list with every side of trade `id` marked cancelled, so the heal never applies it.
function StationTrade.ledgerCancel(list: { any }, id: string): { any }
	for _, e in list do
		if type(e) == "table" and e.id == id then
			e.cancelled = true
		end
	end
	return list
end
StationTrade.UNEVEN = 0.4 -- the fairness meter warns when one side is worth under this share of the other

type Profile = StationProgress.Profile
type Animal = StationProgress.Animal

local DAY = 86400

-- Whether `p` may trade at `now`: level MIN_LEVEL, and fewer than PER_DAY trades today.
function StationTrade.canTrade(p: Profile, now: number): (boolean, string?)
	if StationProgress.playerLevel(p) < StationTrade.MIN_LEVEL then
		return false, "trade_level"
	elseif p.trades.day == now // DAY and p.trades.count >= StationTrade.PER_DAY then
		return false, "trade_limit"
	end
	return true, nil
end

-- Trades `p` has left today.
function StationTrade.left(p: Profile, now: number): number
	return StationTrade.PER_DAY - (if p.trades.day == now // DAY then p.trades.count else 0)
end

-- Whether `p` may put animal `id` in a trade.
function StationTrade.canOffer(p: Profile, id: number): (boolean, string?)
	local _, a = StationProgress.find(p, id)
	if a == nil then
		return false, "trade_unknown"
	elseif a.at ~= nil then
		return false, "trade_training"
	elseif a.locked then
		return false, "trade_locked"
	end
	return true, nil
end

-- Lock or unlock animal `id` of `p`.
function StationTrade.lock(p: Profile, id: number): (Profile, boolean, string?)
	local _, a = StationProgress.find(p, id)
	if a == nil then
		return p, false, "trade_unknown"
	end
	a.locked = if a.locked then nil else true
	return p, true, nil
end

-- Turn trade requests to `p` off or on.
function StationTrade.setOff(p: Profile, off: boolean): (Profile, boolean, string?)
	p.trades.off = off
	return p, true, nil
end

-- What an animal is worth on the fairness meter (a guide, never a block): its power, times its
-- rarity's weight, times its coat's weight (COAT, by the coat's rarity: decision 0110).
StationTrade.RARITY = {
	common = 1,
	uncommon = 1.5,
	rare = 2.5,
	epic = 4,
	legendary = 8,
	mythic = 20,
	divine = 50,
	celestial = 120,
	secret = 300,
	eternal = 800, -- decision 0117
}
StationTrade.RAINBOW = 3
StationTrade.COAT = { prismatic = 20, spectral = 6, galaxy = 4, gilded = 4, rainbow = StationTrade.RAINBOW }
function StationTrade.worth(a: StationRules.Owned): number
	local weight = StationTrade.RARITY[StationRules.rarity(a)] or 1
	local coat = StationRules.coatOf(a)
	return BattleRules.powerOf(a) * weight * (if coat then StationTrade.COAT[coat.id] or 2 else 1)
end

-- Where a trade sits on the fairness meter, from 0 (you give everything) to 1 (you get everything); 0.5
-- is even. `uneven` when one side is worth under UNEVEN of the other.
function StationTrade.balance(give: { StationRules.Owned }, get: { StationRules.Owned }): (number, boolean)
	local a, b = 0, 0
	for _, x in give do
		a += StationTrade.worth(x)
	end
	for _, x in get do
		b += StationTrade.worth(x)
	end
	if a + b <= 0 then
		return 0.5, false
	end
	return b / (a + b), math.min(a, b) < math.max(a, b) * StationTrade.UNEVEN
end

-- A name for an animal in the history: its version and coat.
function StationTrade.nameOf(a: StationRules.Owned): string
	local va = if a.v then StationConfig.variant(a.s, a.v) else nil
	local sp = StationConfig.species(a.s)
	local coat = StationRules.coatOf(a)
	return (if coat then coat.name .. " " else "") .. (if va then va.name elseif sp then sp.name else a.s)
end

-- `offer` with `id` put in or taken out (at most MAX), and whether that was allowed.
function StationTrade.toggle(p: Profile, offer: { number }, id: number): ({ number }, boolean, string?)
	local out = table.clone(offer)
	local at = table.find(out, id)
	if at then
		table.remove(out, at)
		return out, true, nil
	end
	local ok, code = StationTrade.canOffer(p, id)
	if not ok then
		return offer, false, code
	elseif #out >= StationTrade.MAX then
		return offer, false, "trade_max"
	end
	table.insert(out, id)
	return out, true, nil
end

-- Copies of the animals `ids` of `p`, as they would move: no training state.
function StationTrade.copies(p: Profile, ids: { number }): { Animal }
	local out = {}
	for _, id in ids do
		local _, a = StationProgress.find(p, id)
		if a then
			local c = table.clone(a)
			c.stats = table.clone(a.stats)
			c.trained = if a.trained then table.clone(a.trained) else nil
			c.at, c.since, c.locked = nil, nil, nil
			table.insert(out, c)
		end
	end
	return out
end

-- `p` gives the animals `give` (its ids) and gets `get` (copies from the other save). Refuses if one
-- of `give` is gone or training, or if the save would hold more than its Barn keeps (a save already
-- over it, from the admin menu, may still swap even). Safe to run again on a stored record.
function StationTrade.swap(p: Profile, give: { number }, get: { Animal }): (Profile, boolean, string?)
	for _, id in give do
		local ok, code = StationTrade.canOffer(p, id)
		if not ok then
			return p, false, code
		end
	end
	local after = #p.animals - #give + #get
	if after > StationProgress.MAX_ANIMALS or (#get > #give and after > StationProgress.value(p, "barn")) then
		return p, false, "trade_full"
	end
	local gone: { [number]: boolean } = {}
	for _, id in give do
		gone[id] = true
	end
	local kept = {}
	for _, a in p.animals do
		if not gone[a.id] then
			table.insert(kept, a)
		end
	end
	p.animals = kept
	local team = {}
	for _, id in p.team do
		if not gone[id] then
			table.insert(team, id)
		end
	end
	p.team = team
	for _, a in get do
		local c = table.clone(a)
		c.id = p.nextId
		c.at, c.since, c.locked = nil, nil, nil
		p.nextId += 1
		table.insert(p.animals, c)
		StationProgress.meet(p, c.s, c.v) -- decision 0118
	end
	if p.titan and gone[p.titan] then
		p.titan = nil
	end
	if p.titan == nil then -- the slot goes to a Titan still in the save, if any
		for _, a in p.animals do
			if StationProgress.isTitan(a) then
				p.titan = a.id
				break
			end
		end
	end
	return p, true, nil
end

-- One side of a finished trade, as the ledger keeps it: the trade's id, who with, and what moves.
export type Side = { id: string, with: string, give: { number }, get: { Animal }, gave: { string }, got: { string } }

-- Whether `p` already has trade `id` (it is in the history).
function StationTrade.has(p: Profile, id: string): boolean
	for _, e in p.trades.log do
		if e.id == id then
			return true
		end
	end
	return false
end

-- Apply one side of a trade to `p` at `now`: the swap, the day's count and the history. A trade already
-- in the history changes nothing and succeeds, so the ledger's heal and a re-run are both safe.
function StationTrade.commit(p: Profile, side: Side, now: number): (Profile, boolean, string?)
	if StationTrade.has(p, side.id) then
		return p, true, nil
	end
	local _, ok, code = StationTrade.swap(p, side.give, side.get)
	if not ok then
		return p, false, code
	end
	local t = p.trades
	if t.day ~= now // DAY then
		t.day, t.count = now // DAY, 0
	end
	t.count += 1
	t.total += 1
	table.insert(t.log, 1, { id = side.id, with = side.with, gave = side.gave, got = side.got, at = now })
	while #t.log > StationProgress.TRADE_LOG do
		table.remove(t.log)
	end
	return p, true, nil
end

return StationTrade
