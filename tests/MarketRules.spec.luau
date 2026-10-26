--!strict
local T = require("./framework")
local MarketRules = require("../src/shared/MarketRules")
local Rng = require("../src/shared/Rng")
local SpireConfig = require("../src/shared/SpireConfig")

local describe, it, expect = T.describe, T.it, T.expect

-- 2027-01-15 00:00 UTC is a Friday (day 20833: (20833 + 3) % 7 = 4).
local FRIDAY = 20833 * 86400
local SATURDAY = FRIDAY + 86400

local function pick(row: { SpireConfig.Odds }, r: number): string
	local total = 0
	for _, o in row do
		total += o.bp
		if r <= total then
			return o.id
		end
	end
	return row[#row].id
end

describe("MarketRules", function()
	it("weekday: Monday 0, Friday 4, Saturday 5", function()
		expect(MarketRules.weekday(0)).toBe(3) -- 1 Jan 1970, Thursday
		expect(MarketRules.weekday(FRIDAY)).toBe(4)
		expect(MarketRules.weekday(SATURDAY)).toBe(5)
		expect(MarketRules.isWeekend(SATURDAY - 1)).toBe(false)
		expect(MarketRules.isWeekend(SATURDAY)).toBe(true)
		expect(MarketRules.isWeekend(SATURDAY + 2 * 86400)).toBe(false) -- Monday
	end)

	it("same unix gives the same event", function()
		for i = 0, 200 do
			local unix = FRIDAY + i * 997
			expect(MarketRules.eventAt(unix)).toBe(MarketRules.eventAt(unix))
			expect(MarketRules.eventFor(MarketRules.window(unix))).toBe(MarketRules.eventFor(MarketRules.window(unix)))
		end
	end)

	it("an event is active only in the first 300 s of its window", function()
		local checked = 0
		for w = MarketRules.window(FRIDAY), MarketRules.window(FRIDAY) + 200 do
			local kind = MarketRules.eventFor(w)
			expect(MarketRules.eventAt(w * 600)).toBe(kind)
			expect(MarketRules.eventAt(w * 600 + 299)).toBe(kind)
			expect(MarketRules.eventAt(w * 600 + 300)).toBe("normal")
			expect(MarketRules.eventAt(w * 600 + 599)).toBe("normal")
			if kind ~= "normal" then
				checked += 1
				expect(MarketRules.eventLeft(w * 600)).toBe(300)
				expect(MarketRules.eventLeft(w * 600 + 299)).toBe(1)
			else
				expect(MarketRules.eventLeft(w * 600 + 10)).toBe(590)
			end
			expect(MarketRules.eventLeft(w * 600 + 300)).toBe(300)
			expect(MarketRules.eventLeft(w * 600 + 599)).toBe(1)
		end
		expect(checked > 0).toBeTruthy()
	end)

	it("Friday 23:59 uses the weekday row, Saturday 00:00 the weekend row", function()
		local friLate = MarketRules.window(SATURDAY - 60)
		local satEarly = MarketRules.window(SATURDAY)
		expect(friLate + 1).toBe(satEarly)
		local function roll(w: number): number
			return (Rng.int(Rng.seed(w, 7077), 1, 10000))
		end
		expect(MarketRules.eventFor(friLate)).toBe(pick(SpireConfig.EVENT_ODDS.weekday, roll(friLate)))
		expect(MarketRules.eventFor(satEarly)).toBe(pick(SpireConfig.EVENT_ODDS.weekend, roll(satEarly)))
		-- Over many windows each day uses its own row (the rows differ for r in 3501..10000).
		local differs = 0
		for w = satEarly - 144, satEarly + 143 do
			local row = if MarketRules.isWeekend(w * 600)
				then SpireConfig.EVENT_ODDS.weekend
				else SpireConfig.EVENT_ODDS.weekday
			expect(MarketRules.eventFor(w)).toBe(pick(row, roll(w)))
			if pick(SpireConfig.EVENT_ODDS.weekday, roll(w)) ~= pick(SpireConfig.EVENT_ODDS.weekend, roll(w)) then
				differs += 1
			end
		end
		expect(differs > 0).toBeTruthy()
	end)

	it("frequencies within 1 point of the table over 20,000 windows", function()
		for _, case in
			{
				{ start = FRIDAY - 4 * 86400, row = SpireConfig.EVENT_ODDS.weekday },
				{ start = SATURDAY, row = SpireConfig.EVENT_ODDS.weekend },
			}
		do
			local counts: { [string]: number } = {}
			local n = 0
			local w = MarketRules.window(case.start)
			while n < 20_000 do
				if (case.row == SpireConfig.EVENT_ODDS.weekend) == MarketRules.isWeekend(w * 600) then
					local kind = MarketRules.eventFor(w)
					counts[kind] = (counts[kind] or 0) + 1
					n += 1
				end
				w += 1
			end
			for _, o in case.row do
				local share = (counts[o.id] or 0) / n * 10000
				expect(math.abs(share - o.bp) <= 100).toBeTruthy()
			end
		end
	end)

	it("forecast: the current window and the next n - 1", function()
		local f = MarketRules.forecast(FRIDAY + 1234, 3)
		expect(#f).toBe(3)
		local w = MarketRules.window(FRIDAY + 1234)
		for i, entry in f do
			expect(entry.window).toBe(w + i - 1)
			expect(entry.startsAt).toBe((w + i - 1) * 600)
			expect(entry.kind).toBe(MarketRules.eventFor(w + i - 1))
		end
	end)

	it("Flash Sale price is floor(price x 0.75); other events unchanged", function()
		expect(MarketRules.price(15, "sale")).toBe(11)
		expect(MarketRules.price(30, "sale")).toBe(22)
		expect(MarketRules.price(8_000, "sale")).toBe(6_000)
		expect(MarketRules.price(15, "normal")).toBe(15)
		expect(MarketRules.price(15, "boom")).toBe(15)
		expect(MarketRules.price(15, "neon")).toBe(15)
	end)
end)
