--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local HatchRules = require("../src/shared/HatchRules")
local Rng = require("../src/shared/Rng")
local WorldRules = require("../src/shared/WorldRules")

local describe, it, expect = T.describe, T.it, T.expect

local FRIDAY = 20000 -- UTC day 20000 is Friday 4 October 2024
local FRI_2359 = FRIDAY * 86400 + 86340
local SAT_0000 = (FRIDAY + 1) * 86400

local function roll(window: number): number
	return (Rng.int(Rng.seed(window, 4242), 1, 10000))
end

describe("WorldRules days", function()
	it("numbers weekdays from Monday 0 and spots weekends", function()
		expect(WorldRules.weekday(0)).toBe(3) -- 1 January 1970 was a Thursday
		expect(WorldRules.weekday(4 * 86400)).toBe(0) -- 5 January 1970, Monday
		expect(WorldRules.weekday(FRI_2359)).toBe(4)
		expect(WorldRules.weekday(SAT_0000)).toBe(5)
		expect(WorldRules.weekday(SAT_0000 + 86400)).toBe(6)
		expect(WorldRules.isWeekend(FRI_2359)).toBe(false)
		expect(WorldRules.isWeekend(SAT_0000)).toBe(true)
		expect(WorldRules.isWeekend(SAT_0000 + 2 * 86400)).toBe(false) -- Monday
	end)
end)

describe("WorldRules weather (F)", function()
	it("gives the same weather for the same time and is active only for the first 300 s", function()
		local w0 = WorldRules.weatherWindow(SAT_0000)
		for w = w0, w0 + 200 do
			local start = w * 600
			expect(WorldRules.weatherWindow(start + 599)).toBe(w)
			local kind = WorldRules.eventFor(w)
			expect(WorldRules.eventFor(w)).toBe(kind)
			expect(WorldRules.weatherAt(start)).toBe(kind)
			expect(WorldRules.weatherAt(start + 299)).toBe(kind)
			expect(WorldRules.weatherAt(start + 300)).toBe("clear")
			expect(WorldRules.weatherAt(start + 599)).toBe("clear")
		end
	end)

	it("uses the weekday table up to Friday 23:59 and the weekend table from Saturday 00:00", function()
		local differs = { weekday = 0, weekend = 0 }
		for w = WorldRules.weatherWindow(SAT_0000) - 144, WorldRules.weatherWindow(SAT_0000) + 143 do
			local weekend = w * 600 >= SAT_0000
			local odds = if weekend then GardenConfig.WEATHER_ODDS.weekend else GardenConfig.WEATHER_ODDS.weekday
			local other = if weekend then GardenConfig.WEATHER_ODDS.weekday else GardenConfig.WEATHER_ODDS.weekend
			expect(WorldRules.eventFor(w)).toBe(HatchRules.pick(odds, roll(w)))
			if HatchRules.pick(odds, roll(w)) ~= HatchRules.pick(other, roll(w)) then
				differs[if weekend then "weekend" else "weekday"] += 1
			end
		end
		-- The check is only meaningful if some windows on each side would differ under the other table.
		expect(differs.weekday > 0 and differs.weekend > 0).toBe(true)
		expect(WorldRules.weatherWindow(FRI_2359) + 1).toBe(WorldRules.weatherWindow(SAT_0000))
	end)

	it("keeps each weather within 1 point of its odds over 20,000 windows of each table", function()
		local counts = { weekday = {} :: { [string]: number }, weekend = {} :: { [string]: number } }
		local n = { weekday = 0, weekend = 0 }
		local w = 2_900_000
		while n.weekday < 20000 or n.weekend < 20000 do
			local key = if WorldRules.isWeekend(w * 600) then "weekend" else "weekday"
			if n[key] < 20000 then
				n[key] += 1
				local kind = WorldRules.eventFor(w)
				counts[key][kind] = (counts[key][kind] or 0) + 1
			end
			w += 1
		end
		for key, odds in GardenConfig.WEATHER_ODDS do
			for _, o in odds do
				local pct = 100 * (counts[key][o.id] or 0) / 20000
				expect(`{key} {o.id} {math.abs(pct - o.bp / 100) <= 1}`).toBe(`{key} {o.id} true`)
			end
		end
	end)

	it("counts down to the next 300 s mark and forecasts the next windows", function()
		local start = 2_900_000 * 600
		expect(WorldRules.weatherLeft(start)).toBe(300)
		expect(WorldRules.weatherLeft(start + 299)).toBe(1)
		expect(WorldRules.weatherLeft(start + 300)).toBe(300)
		expect(WorldRules.weatherLeft(start + 599)).toBe(1)
		local f = WorldRules.forecast(start + 450, 3)
		expect(#f).toBe(3)
		for i, entry in f do
			expect(entry.window).toBe(2_900_000 + i - 1)
			expect(entry.startsAt).toBe(entry.window * 600)
			expect(entry.kind).toBe(WorldRules.eventFor(entry.window))
		end
	end)
end)

describe("WorldRules restock (D1)", function()
	it("restocks every 300 s", function()
		expect(WorldRules.stockWindow(600)).toBe(2)
		expect(WorldRules.stockWindow(899)).toBe(2)
		expect(WorldRules.restockLeft(600)).toBe(300)
		expect(WorldRules.restockLeft(899)).toBe(1)
	end)

	it("keeps Meadow unlimited and every quantity in range, at about the published chance", function()
		local inStock: { [string]: number } = {}
		for s = 5_000_000, 5_019_999 do
			local stock = WorldRules.stockFor(s)
			expect(stock.meadow).toBeNil()
			expect(stock.starter).toBeNil()
			for _, egg in GardenConfig.EGGS do
				local range = egg.stock
				if range then
					local q = stock[egg.id]
					expect(q == 0 or (q >= range.min and q <= range.max and q == math.floor(q))).toBe(true)
					inStock[egg.id] = (inStock[egg.id] or 0) + if q > 0 then 1 else 0
				end
			end
			expect(WorldRules.stockFor(s).forest).toBe(stock.forest)
		end
		expect(inStock.forest).toBe(20000)
		for _, egg in GardenConfig.EGGS do
			if egg.stock then
				local pct = 100 * inStock[egg.id] / 20000
				expect(`{egg.id} {math.abs(pct - egg.stock.chance) <= 1}`).toBe(`{egg.id} true`)
			end
		end
	end)

	it("derives each egg's stock from its seed (window, 9001, position - 1)", function()
		local s = 5_000_123
		local r, state = Rng.int(Rng.seed(s, 9001, 2), 1, 10000)
		expect(r <= 10000).toBe(true)
		expect(WorldRules.stockFor(s).forest).toBe((Rng.int(state, 2, 4)))
	end)
end)
