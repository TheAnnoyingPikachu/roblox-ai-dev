--!strict
-- Lantern Express Depot (architecture lantern 3.6, GDD F): this run's upgrades bought from the
-- crew's Parts pool, coal and oil purchases, and vote tallies. Functions return new tables.
-- No Roblox APIs.

local LanternConfig = require("./LanternConfig")

local DepotRules = {}

export type Levels = { boiler: number, bunker: number, lamps: number } -- 1 to 3
export type Pools = { parts: number, coal: number, oil: number, levels: Levels }

local function upgrade(id: string): LanternConfig.Upgrade?
	for _, u in LanternConfig.UPGRADES do
		if u.id == id then
			return u
		end
	end
	return nil
end

function DepotRules.cruise(l: Levels): number
	return LanternConfig.SPEED[l.boiler]
end

function DepotRules.bunker(l: Levels): number
	return LanternConfig.BUNKER[l.bunker]
end

function DepotRules.puff(l: Levels): number
	return LanternConfig.BEAM.puff[l.lamps]
end

function DepotRules.range(l: Levels): number
	return LanternConfig.BEAM.range[l.lamps]
end

-- (price, refusal): the refusal when the item cannot be bought at any price right now.
local function quote(pools: Pools, id: string): (number?, string?)
	local u = upgrade(id)
	if u then
		local level = (pools.levels :: any)[id]
		return u.costs[level], if level >= 3 then "max" else nil
	elseif id == "coal" then
		local fits = DepotRules.bunker(pools.levels) - pools.coal >= LanternConfig.COAL_BUY.coal
		return if fits then LanternConfig.COAL_BUY.parts else nil, if fits then nil else "full"
	elseif id == "oil" then
		local fits = LanternConfig.LANTERN.store - pools.oil >= LanternConfig.OIL_BUY.cans
		return if fits then LanternConfig.OIL_BUY.parts else nil, if fits then nil else "full"
	end
	return nil, "unknown"
end

function DepotRules.price(pools: Pools, id: string): number?
	return (quote(pools, id))
end

-- A bunker upgrade keeps the coal; coal and oil are bought only when the whole purchase fits.
function DepotRules.buy(pools: Pools, id: string): (Pools, boolean, string?)
	local price, refusal = quote(pools, id)
	if price == nil then
		return pools, false, refusal
	elseif pools.parts < price then
		return pools, false, "parts"
	end
	local out = table.clone(pools)
	out.levels = table.clone(pools.levels)
	out.parts -= price
	if id == "coal" then
		out.coal += LanternConfig.COAL_BUY.coal
	elseif id == "oil" then
		out.oil += LanternConfig.OIL_BUY.cans
	else
		(out.levels :: any)[id] += 1
	end
	return out, true, nil
end

-- The majority among `options`; a tie at the top or no votes gives `default`.
function DepotRules.tally(votes: { [number]: string }, options: { string }, default: string): string
	local counts: { [string]: number } = {}
	for _, choice in votes do
		if table.find(options, choice) then
			counts[choice] = (counts[choice] or 0) + 1
		end
	end
	local best, top, tied = default, 0, false
	for _, option in options do
		local k = counts[option] or 0
		if k > top then
			best, top, tied = option, k, false
		elseif k == top and k > 0 then
			tied = true
		end
	end
	return if tied or top == 0 then default else best
end

function DepotRules.leftover(parts: number, n: number): number
	return math.max(0, math.ceil(parts / math.max(n, 1) - 1e-9))
end

return DepotRules
