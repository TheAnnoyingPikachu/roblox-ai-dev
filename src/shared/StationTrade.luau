--!strict
-- Animal Stations trading (decision 0084): two players in one server swap animals. Each puts up to
-- MAX of their own animals in the trade; when both say ready the server swaps them. Pure: the server
-- keeps the trade and calls `swap` on both saves. (Egg Garden's trading is TradeRules: another game.)
--
-- What moves is a copy of each animal as it is (its stats, levels, variant, rainbow coat), under a
-- new id in the save it lands in. An animal that is training cannot be offered; one that leaves also
-- leaves the team, and the Titan's slot, which falls to another Titan if there is one.

local StationProgress = require("./StationProgress")

local StationTrade = {}

StationTrade.MAX = 4 -- animals each side may put in one trade

type Profile = StationProgress.Profile
type Animal = StationProgress.Animal

-- Whether `p` may put animal `id` in a trade.
function StationTrade.canOffer(p: Profile, id: number): (boolean, string?)
	local _, a = StationProgress.find(p, id)
	if a == nil then
		return false, "trade_unknown"
	elseif a.at ~= nil then
		return false, "trade_training"
	end
	return true, nil
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
			c.at, c.since = nil, nil
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
		c.at, c.since = nil, nil
		p.nextId += 1
		table.insert(p.animals, c)
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

return StationTrade
