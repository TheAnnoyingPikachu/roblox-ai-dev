--!strict
-- Neon Spire income (GDD E and H, decision 0009): module, floor and tower income, the 1 Hz tick
-- with its fraction carry, offline pay, Hot Data, IPO Shares, refund worth and the short number
-- format. No Roblox APIs.

local PlazaRules = require("./PlazaRules")
local SpireConfig = require("./SpireConfig")
local TowerRules = require("./TowerRules")

local SpireEconomy = {}

type Profile = SpireConfig.Profile

local function floor(x: number): number
	return math.floor(x + 1e-9)
end

function SpireEconomy.moduleIncome(dept: string, level: number, event: string): number
	local d = SpireConfig.dept(dept)
	if d == nil or level < 1 or level > 5 then
		return 0
	end
	local boom = event == "boom" and (dept == "data" or dept == "quantum")
	return d.income * SpireConfig.LV[level] * (if boom then 2 else 1)
end

function SpireEconomy.floorIncome(p: Profile, n: number, event: string): number
	local f = p.floors[n]
	if f == nil then
		return 0
	end
	local sum = 0
	for _, level in f.m do
		sum += SpireEconomy.moduleIncome(f.d, level, event)
	end
	return sum * TowerRules.floorMult(p, n, event)
end

function SpireEconomy.shareMult(p: Profile): number
	return 1 + SpireConfig.SHARES.per * p.shares
end

-- E1, in ¢/s (not floored).
function SpireEconomy.income(p: Profile, event: string): number
	local sum = 0
	for n = 2, #p.floors do
		sum += SpireEconomy.floorIncome(p, n, event)
	end
	return sum * PlazaRules.hypeMult(p) * SpireEconomy.shareMult(p)
end

-- Whole credits to pay now and the fraction to carry in server memory.
function SpireEconomy.tick(income: number, carry: number, dt: number): (number, number)
	local total = carry + income * dt
	local whole = floor(total)
	return whole, math.max(0, total - whole)
end

function SpireEconomy.offline(p: Profile, now: number): number
	local away = math.min(math.max(0, now - p.lastSeen), SpireConfig.OFFLINE.cap)
	return floor(SpireEconomy.income(p, "normal") * SpireConfig.OFFLINE.rate * away)
end

function SpireEconomy.hotBonus(p: Profile, event: string): number
	return floor(SpireConfig.HOT.seconds * SpireEconomy.income(p, event))
end

-- Before the 500 cap.
function SpireEconomy.ipoShares(p: Profile): number
	return floor(math.sqrt(math.max(0, p.runEarned) / SpireConfig.SHARES.divisor))
end

-- Credits plus what selling everything would refund.
function SpireEconomy.worth(p: Profile): number
	local total = p.coins
	for n = 2, #p.floors do
		for _, spent in p.floors[n].s do
			total += floor(SpireConfig.REFUND * spent)
		end
	end
	for _, it in p.plaza.items do
		total += floor(SpireConfig.REFUND * it.paid)
	end
	return total
end

function SpireEconomy.timeToAfford(coins: number, income: number, cost: number): number?
	if coins >= cost then
		return 0
	elseif income <= 0 then
		return nil
	end
	return math.ceil((cost - coins) / income)
end

local SUFFIXES = { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- "999", "1.2K", "3.4M", "5.6B", "7.8T", "9.1Qa", "1Qi": one decimal truncated, ".0" dropped.
function SpireEconomy.short(n: number): string
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

return SpireEconomy
