--!strict
-- Egg Garden server-wide schedules (GDD D1 and F, decision 0008): weather windows and the egg
-- restock. Pure functions of the unix time, so every server shows the same weather and stock.
-- No Roblox APIs.

local GardenConfig = require("./GardenConfig")
local Rng = require("./Rng")

local WorldRules = {}

export type Window = { window: number, kind: string, startsAt: number } -- startsAt = window * 600

local WINDOW = GardenConfig.WEATHER_WINDOW
local ACTIVE = GardenConfig.WEATHER_ACTIVE
local RESTOCK = GardenConfig.RESTOCK

-- Same walk as HatchRules.pick (kept local: HatchRules depends on this module through GardenRules).
local function pick(odds: { GardenConfig.Odds }, r: number): string
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
function WorldRules.weekday(unix: number): number
	return (math.floor(unix / 86400) + 3) % 7
end

function WorldRules.isWeekend(unix: number): boolean
	return WorldRules.weekday(unix) >= 5
end

function WorldRules.weatherWindow(unix: number): number
	return math.floor(unix / WINDOW)
end

-- Monday-based week number, the same maths as weekday().
function WorldRules.week(unix: number): number
	return math.floor((math.floor(unix / 86400) + 3) / 7)
end

-- The week's event weather (GDD V2.3): one of the rare weathers, fixed for the whole week.
function WorldRules.weekendEvent(unix: number): string
	local RARE = GardenConfig.RARE_WEATHERS
	return RARE[Rng.int(Rng.seed(WorldRules.week(unix), GardenConfig.SEEDS.event), 1, #RARE)]
end

-- The weather table in force at `unix`: weekday as stored; weekend with WEATHER_EVENT_BONUS moved
-- from clear to the event weather. Always sums to 10,000.
function WorldRules.oddsFor(unix: number): { GardenConfig.Odds }
	if not WorldRules.isWeekend(unix) then
		return GardenConfig.WEATHER_ODDS.weekday
	end
	local event = WorldRules.weekendEvent(unix)
	local out: { GardenConfig.Odds } = {}
	for _, o in GardenConfig.WEATHER_ODDS.weekend do
		local bonus = if o.id == "clear"
			then -GardenConfig.WEATHER_EVENT_BONUS
			elseif o.id == event then GardenConfig.WEATHER_EVENT_BONUS
			else 0
		table.insert(out, { id = o.id, bp = o.bp + bonus })
	end
	return out
end

-- The window's event kind (may be "clear"); the table is taken from the window start.
function WorldRules.eventFor(window: number): string
	local r = Rng.int(Rng.seed(window, GardenConfig.SEEDS.weather), 1, 10000)
	return pick(WorldRules.oddsFor(window * WINDOW), r)
end

-- This week's event for GardenStatus.event: Saturday 00:00 to Monday 00:00 UTC.
function WorldRules.eventStatus(unix: number): { weather: string, startsAt: number, endsAt: number, active: boolean }
	local saturday = (7 * WorldRules.week(unix) + 2) * 86400
	return {
		weather = WorldRules.weekendEvent(unix),
		startsAt = saturday,
		endsAt = saturday + 2 * 86400,
		active = unix >= saturday and unix < saturday + 2 * 86400,
	}
end

function WorldRules.weatherAt(unix: number): string
	local w = WorldRules.weatherWindow(unix)
	return if unix - w * WINDOW < ACTIVE then WorldRules.eventFor(w) else "clear"
end

-- Seconds to the next 300 s mark (the event's end or the next window's start). The kind there
-- may be the same, e.g. a clear window followed by a clear one.
function WorldRules.weatherLeft(unix: number): number
	local offset = unix - WorldRules.weatherWindow(unix) * WINDOW
	return if offset < ACTIVE then ACTIVE - offset else WINDOW - offset
end

function WorldRules.forecast(unix: number, n: number): { Window }
	local w = WorldRules.weatherWindow(unix)
	local out: { Window } = {}
	for i = 0, n - 1 do
		table.insert(out, { window = w + i, kind = WorldRules.eventFor(w + i), startsAt = (w + i) * WINDOW })
	end
	return out
end

function WorldRules.stockWindow(unix: number): number
	return math.floor(unix / RESTOCK)
end

function WorldRules.restockLeft(unix: number): number
	return (WorldRules.stockWindow(unix) + 1) * RESTOCK - unix
end

-- Per-player quantities for the stocked eggs this window; 0 when out of stock. Meadow is absent
-- (always in stock, unlimited).
function WorldRules.stockFor(window: number): { [string]: number }
	local out: { [string]: number } = {}
	for position, egg in GardenConfig.EGGS do
		local stock = egg.stock
		if stock then
			local r, state = Rng.int(Rng.seed(window, GardenConfig.SEEDS.stock, position - 1), 1, 10000)
			out[egg.id] = if r <= stock.chance * 100 then (Rng.int(state, stock.min, stock.max)) else 0
		end
	end
	return out
end

return WorldRules
