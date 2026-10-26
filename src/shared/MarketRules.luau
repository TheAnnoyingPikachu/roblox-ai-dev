--!strict
-- Neon Spire Market Pulse (GDD F, decision 0009): the server-wide event schedule and Flash Sale
-- prices. Pure functions of the unix time, so every server shows the same event at the same
-- time. Same pattern as WorldRules. No Roblox APIs.

local Rng = require("./Rng")
local SpireConfig = require("./SpireConfig")

local MarketRules = {}

export type Window = { window: number, kind: string, startsAt: number } -- startsAt = window * 600

local MARKET = SpireConfig.MARKET

local function pick(odds: { SpireConfig.Odds }, r: number): string
	local total = 0
	for _, o in odds do
		total += o.bp
		if r <= total then
			return o.id
		end
	end
	return odds[#odds].id
end

-- Monday 0 .. Sunday 6 (1 January 1970 was a Thursday).
function MarketRules.weekday(unix: number): number
	return (math.floor(unix / 86400) + 3) % 7
end

function MarketRules.isWeekend(unix: number): boolean
	return MarketRules.weekday(unix) >= 5
end

function MarketRules.window(unix: number): number
	return math.floor(unix / MARKET.window)
end

-- The window's event (may be "normal"); the weekday is taken from the window start.
function MarketRules.eventFor(window: number): string
	local odds = if MarketRules.isWeekend(window * MARKET.window)
		then SpireConfig.EVENT_ODDS.weekend
		else SpireConfig.EVENT_ODDS.weekday
	return pick(odds, (Rng.int(Rng.seed(window, MARKET.seed), 1, 10000)))
end

function MarketRules.eventAt(unix: number): string
	local w = MarketRules.window(unix)
	return if unix - w * MARKET.window < MARKET.active then MarketRules.eventFor(w) else "normal"
end

-- Seconds until the shown state changes: the event's end while one is active, else the next window.
function MarketRules.eventLeft(unix: number): number
	local w = MarketRules.window(unix)
	local t = unix - w * MARKET.window
	if t < MARKET.active and MarketRules.eventFor(w) ~= "normal" then
		return MARKET.active - t
	end
	return MARKET.window - t
end

function MarketRules.forecast(unix: number, n: number): { Window }
	local w = MarketRules.window(unix)
	local out: { Window } = {}
	for i = 0, n - 1 do
		table.insert(out, { window = w + i, kind = MarketRules.eventFor(w + i), startsAt = (w + i) * MARKET.window })
	end
	return out
end

function MarketRules.price(base: number, event: string): number
	return if event == "sale" then math.floor(base * MARKET.sale + 1e-9) else base
end

return MarketRules
