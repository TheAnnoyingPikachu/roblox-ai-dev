--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local LoginRules = require("../src/shared/LoginRules")
local MetaRules = require("../src/shared/MetaRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = GardenConfig.Profile

local function same(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Hinnant's days_from_civil: the inverse of monthOf, so the date table below reads as dates.
local function dayOf(y: number, m: number, d: number): number
	if m <= 2 then
		y -= 1
	end
	local era = y // 400
	local yoe = y - era * 400
	local doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

local MONDAY = 20759 -- 2026-11-02, a Monday; the 2nd of the month

local function commas(n: number): string
	local s = string.reverse((string.gsub(string.reverse(string.format("%d", n)), "(%d%d%d)", "%1,")))
	return (string.gsub(s, "^,", ""))
end
local function ticked(days: { number }): Profile
	local p = GardenProgress.defaults(0)
	for _, d in days do
		p = LoginRules.tick(p, d)
	end
	return p
end

describe("LoginRules calendar", function()
	it("gives the month key and length for known dates, before and after a year end", function()
		local cases = {
			{ 1970, 1, 1, 31 },
			{ 2024, 2, 29, 29 },
			{ 2026, 11, 5, 30 },
			{ 2100, 3, 1, 31 },
			{ 2025, 12, 31, 31 },
			{ 2026, 1, 1, 31 },
			{ 2026, 2, 1, 28 },
			{ 2000, 2, 15, 29 },
			{ 1900, 2, 15, 28 },
		}
		expect(dayOf(1970, 1, 1)).toBe(0)
		expect(dayOf(2026, 11, 5)).toBe(20762)
		for _, c in cases do
			local y, m, d, len = c[1], c[2], c[3], c[4]
			local key, length = LoginRules.monthOf(dayOf(y, m, d))
			expect(`{y}-{m}-{d} {key} {length}`).toBe(`{y}-{m}-{d} {y * 12 + m - 1} {len}`)
		end
		expect(LoginRules.monthOf(dayOf(2025, 12, 31)) + 1).toBe((LoginRules.monthOf(dayOf(2026, 1, 1))))
		expect(LoginRules.periodOf("week", MONDAY)).toBe(MetaRules.weekOf(MONDAY))
		expect(LoginRules.periodOf("week", MONDAY + 6)).toBe(LoginRules.periodOf("week", MONDAY))
		expect(LoginRules.periodOf("week", MONDAY + 7)).toBe(LoginRules.periodOf("week", MONDAY) + 1)
		expect(LoginRules.periodOf("month", MONDAY)).toBe(2026 * 12 + 10)
	end)

	it("moves the month's last slot to the month's length in February, and never above 30", function()
		local function last(y: number, m: number): number
			return LoginRules.slots("month", dayOf(y, m, 10))[7].count
		end
		expect(`{last(2026, 2)} {last(2024, 2)} {last(2026, 4)} {last(2026, 5)}`).toBe("28 29 30 30")
		expect(same(LoginRules.slots("week", MONDAY), GardenConfig.LOGIN.week)).toBe(true)
		expect(LoginRules.slots("month", dayOf(2026, 2, 1))[6].count).toBe(26)
		expect(GardenConfig.LOGIN.month[7].count).toBe(30) -- the config is not mutated
		expect(table.concat(LoginRules.TRACKS, " ")).toBe("week month")
	end)
end)

describe("LoginRules.tick", function()
	it("counts a day once, two days as 2, and a fresh profile counts today as day 1", function()
		local one = ticked({ MONDAY })
		local L = one.login
		expect(`{L.week} {L.weekDays} {L.weekLast} {L.weekClaimed}`).toBe(`{MetaRules.weekOf(MONDAY)} 1 {MONDAY} 0`)
		expect(`{L.month} {L.monthDays} {L.monthLast} {L.monthClaimed}`).toBe(`{2026 * 12 + 10} 1 {MONDAY} 0`)
		expect(same(LoginRules.tick(one, MONDAY), one)).toBe(true) -- twice the same day equals once
		local two = ticked({ MONDAY, MONDAY + 1, MONDAY + 1 })
		expect(`{two.login.weekDays} {two.login.monthDays}`).toBe("2 2")
	end)

	it("resets the week on the Monday after a Sunday and the month on the 1st, keeping the other track", function()
		local sunday = ticked({ MONDAY, MONDAY + 3, MONDAY + 6 })
		expect(sunday.login.weekDays).toBe(3)
		local next = LoginRules.tick(sunday, MONDAY + 7)
		expect(`{next.login.week} {next.login.weekDays} {next.login.weekClaimed}`).toBe(
			`{MetaRules.weekOf(MONDAY) + 1} 1 0`
		)
		expect(`{next.login.month} {next.login.monthDays}`).toBe(`{2026 * 12 + 10} 4`) -- the month goes on
		local nov30 = dayOf(2026, 11, 30) -- a Monday
		local dec1 = LoginRules.tick(ticked({ nov30 }), nov30 + 1)
		expect(`{dec1.login.month} {dec1.login.monthDays} {dec1.login.monthClaimed}`).toBe(`{2026 * 12 + 11} 1 0`)
		expect(`{dec1.login.week} {dec1.login.weekDays}`).toBe(`{MetaRules.weekOf(nov30)} 2`) -- the week goes on
		local p = GardenProgress.defaults(0)
		LoginRules.tick(p, MONDAY)
		expect(p.login.weekDays).toBe(0) -- input unchanged
	end)

	it("sanitises: integers, keys >= -1, days 0..31, claimed 0..7, anything else the default", function()
		expect(same(LoginRules.sanitize(nil), LoginRules.defaults())).toBe(true)
		expect(same(LoginRules.sanitize("x"), LoginRules.defaults())).toBe(true)
		expect(same(LoginRules.sanitize({}), LoginRules.defaults())).toBe(true)
		local L = LoginRules.sanitize({
			week = 2960.7,
			weekDays = 40,
			weekLast = -9,
			weekClaimed = 8,
			month = -1,
			monthDays = 2.5,
			monthLast = math.huge,
			monthClaimed = "3",
		})
		expect(same(L, {
			week = 2960,
			weekDays = 31,
			weekLast = -1,
			weekClaimed = 7,
			month = -1,
			monthDays = 2,
			monthLast = -1,
			monthClaimed = 0,
		})).toBe(true)
		local full = {
			week = 1,
			weekDays = 2,
			weekLast = 3,
			weekClaimed = 4,
			month = 5,
			monthDays = 6,
			monthLast = 7,
			monthClaimed = 1,
		}
		expect(same(LoginRules.sanitize(full), full)).toBe(true)
	end)
end)

describe("LoginRules claims", function()
	-- 60.5 coins/s garden (GDD C3) with a full week signed in.
	local function week(): Profile
		local p = GardenProgress.defaults(0)
		for i = 1, 6 do
			p.creatures[i] =
				{ id = i, s = "cat", m = "golden", z = "normal", c = "none", placed = i, fav = false, fa = 0, n = "" }
		end
		p.index = { "cat:golden" } -- 12 x 3 x 6 x 1.02 = 220.32 coins/s
		for d = MONDAY, MONDAY + 6 do
			p = LoginRules.tick(p, d)
		end
		return p
	end

	it("can claim at the count, not before, and not past the last slot", function()
		local p = ticked({ MONDAY })
		expect(LoginRules.canClaim(p, "week", MONDAY)).toBe(true)
		expect(LoginRules.canClaim(p, "month", MONDAY)).toBe(false) -- 1 < 3
		expect(LoginRules.canClaim(p, "nope", MONDAY)).toBe(false)
		local n, slot = LoginRules.nextSlot(p, "week", MONDAY)
		expect(`{n} {(slot :: any).count} {(slot :: any).coins}`).toBe("1 1 100")
		local three = ticked({ MONDAY, MONDAY + 1, MONDAY + 2 })
		expect(LoginRules.canClaim(three, "month", MONDAY + 2)).toBe(true)
		expect(LoginRules.claimable(three, MONDAY + 2)).toBe(4) -- week 1, 2, 3 and month 3
		local full = week()
		for _ = 1, 7 do
			full = LoginRules.claim(full, "week", MONDAY + 6)
		end
		expect(full.login.weekClaimed).toBe(7)
		expect(LoginRules.canClaim(full, "week", MONDAY + 6)).toBe(false)
		expect(select(2, LoginRules.nextSlot(full, "week", MONDAY + 6))).toBeNil()
		expect(LoginRules.claimable(full, MONDAY + 6)).toBe(2) -- month slots 1 and 2 (7 sign-ins)
	end)

	it("pays in order, scaled with the floor and the cap, with the LastReward text", function()
		local p = week()
		local income = GardenRules.income(p)
		expect(income > 0).toBe(true)
		-- Slot 2 is not payable while slot 1 is unclaimed: claim always pays the next one.
		local one, ok, text = LoginRules.claim(p, "week", MONDAY + 6)
		expect(ok).toBe(true)
		expect(one.coins - p.coins).toBe(GardenProgress.scaled(p, 100, 3))
		expect(text).toBe(`{commas(GardenProgress.scaled(p, 100, 3))} coins`)
		expect(`{commas(999)} {commas(1200)} {commas(1234567)}`).toBe("999 1,200 1,234,567")
		expect(one.login.weekClaimed).toBe(1)
		expect(p.login.weekClaimed).toBe(0) -- input unchanged
		expect(p.coins).toBe(100)
		-- A poor garden gets the floor: the base amount.
		local poor = ticked({ MONDAY })
		local floor, _, ftext = LoginRules.claim(poor, "week", MONDAY)
		expect(`{floor.coins - poor.coins} {ftext}`).toBe("100 100 coins")
		-- The cap.
		local rich = ticked({ MONDAY })
		rich.coins = GardenConfig.MAX_COINS - 10
		local capped = LoginRules.claim(rich, "week", MONDAY)
		expect(capped.coins).toBe(GardenConfig.MAX_COINS)
	end)

	it(
		"adds the egg to prizeEggs once, grants a cosmetic once then coins only, and is idempotent on a re-apply",
		function()
			local p = week()
			local out = p
			for _ = 1, 4 do
				out = LoginRules.claim(out, "week", MONDAY + 6)
			end
			local egg, ok, text = LoginRules.claim(out, "week", MONDAY + 6)
			expect(`{ok} {text} {egg.prizeEggs.weekly} {egg.coins == out.coins}`).toBe("true Weekly Egg! 1 true")
			-- Re-applying the same claim to a copy of the stored record changes nothing.
			local stored = GardenRules.copy(out)
			local again = LoginRules.claim(stored, "week", MONDAY + 6)
			expect(same(again, egg)).toBe(true)
			expect(same(LoginRules.claim(egg, "week", MONDAY + 6), LoginRules.claim(egg, "week", MONDAY + 6))).toBe(
				true
			)
			local can, cok, ctext = LoginRules.claim(egg, "week", MONDAY + 6)
			expect(`{cok} {ctext} {can.owned.blossom}`).toBe(
				`true Blossom Can + {commas(GardenProgress.scaled(p, 400, 15))} coins true`
			)
			-- The second week it would be granted again: coins only.
			local nextWeek = LoginRules.tick(can, MONDAY + 7)
			for d = MONDAY + 8, MONDAY + 12 do
				nextWeek = LoginRules.tick(nextWeek, d)
			end
			for _ = 1, 5 do
				nextWeek = LoginRules.claim(nextWeek, "week", MONDAY + 12)
			end
			expect(nextWeek.prizeEggs.weekly).toBe(2)
			local second, sok, stext = LoginRules.claim(nextWeek, "week", MONDAY + 12)
			expect(`{sok} {second.owned.blossom} {string.find(stext, "Blossom") == nil}`).toBe("true true true")
			expect(second.coins - nextWeek.coins).toBe(GardenProgress.scaled(nextWeek, 400, 15))
			-- The egg store cap.
			local capped = GardenRules.copy(out)
			capped.prizeEggs.weekly = GardenConfig.PRIZE_STORE
			expect(LoginRules.claim(capped, "week", MONDAY + 6).prizeEggs.weekly).toBe(GardenConfig.PRIZE_STORE)
		end
	)

	it("refuses after a rollover until the new period earns it, and pays the month track", function()
		local p = week() -- 7 sign-ins, nothing claimed
		expect(LoginRules.canClaim(p, "week", MONDAY + 7)).toBe(false) -- the stored key is last week
		expect(select(2, LoginRules.claim(p, "week", MONDAY + 7))).toBe(false)
		expect(LoginRules.claimable(p, MONDAY + 7)).toBe(2) -- the month track only (7 sign-ins: slots 1 and 2)
		local next = LoginRules.tick(p, MONDAY + 7)
		expect(LoginRules.claimable(next, MONDAY + 7)).toBe(3) -- week slot 1 again
		local m1, ok, text = LoginRules.claim(next, "month", MONDAY + 7)
		expect(`{ok} {text}`).toBe(`true {commas(GardenProgress.scaled(next, 200, 10))} coins`)
		local m2 = LoginRules.claim(m1, "month", MONDAY + 7)
		expect(m2.login.monthClaimed).toBe(2)
		expect(select(2, LoginRules.claim(m2, "month", MONDAY + 7))).toBe(false) -- 8 < 12
		-- The monthly egg at 18 sign-ins and the last slot at the month's length.
		local feb = GardenProgress.defaults(0)
		for d = dayOf(2026, 2, 1), dayOf(2026, 2, 28) do
			feb = LoginRules.tick(feb, d)
		end
		expect(feb.login.monthDays).toBe(28)
		local last = dayOf(2026, 2, 28)
		local names = {}
		for _ = 1, 7 do
			local ok2, t
			feb, ok2, t = LoginRules.claim(feb, "month", last)
			expect(ok2).toBe(true)
			table.insert(names, (string.gsub(t, "%d[%d,]* coins", "coins")))
		end
		expect(table.concat(names, "; ")).toBe(
			"coins; coins; coins; Monthly Egg!; Lily Pads + coins; Sakura Fence + coins; Peacock Pitcher + coins"
		)
		expect(`{feb.prizeEggs.monthly} {feb.owned.lily} {feb.owned.sakura} {feb.owned.peacock}`).toBe(
			"1 true true true"
		)
		expect(LoginRules.claimable(feb, last)).toBe(6) -- the week track (Mon 23 to Sat 28), nothing monthly
		expect(select(2, LoginRules.claim(feb, "month", last))).toBe(false)
		-- March 1st: the month resets (all seven were claimed, so nothing is paid) and the count starts over.
		local mar = LoginRules.tick(feb, last + 1)
		expect(`{mar.login.monthDays} {mar.login.monthClaimed} {LoginRules.canClaim(mar, "month", last + 1)}`).toBe(
			"1 0 false"
		)
	end)
end)

describe("LoginRules rollover payout (QA M1, m5, m6)", function()
	-- A 220 coins/s garden signed in on `days`, so scaled coins are above the floors.
	local function garden(days: { number }): Profile
		local p = GardenProgress.defaults(0)
		for i = 1, 6 do
			p.creatures[i] =
				{ id = i, s = "cat", m = "golden", z = "normal", c = "none", placed = i, fav = false, fa = 0, n = "" }
		end
		p.index = { "cat:golden" }
		for _, d in days do
			p = LoginRules.tick(p, d)
		end
		return p
	end
	local function range(from: number, to: number): { number }
		local out = {}
		for d = from, to do
			table.insert(out, d)
		end
		return out
	end

	it("pays the earned, unclaimed week slots at the Monday rollover, in order, and not the unearned", function()
		local p = garden(range(MONDAY, MONDAY + 4)) -- five sign-ins: slots 1 to 5 earned
		for _ = 1, 2 do
			p = LoginRules.claim(p, "week", MONDAY + 4)
		end
		local next, text = LoginRules.tick(p, MONDAY + 7)
		local coins = GardenProgress.scaled(p, 200, 8) + GardenProgress.scaled(p, 300, 12)
		expect(next.coins - p.coins).toBe(coins)
		expect(next.prizeEggs.weekly).toBe(1)
		expect(text).toBe(`Weekly Egg! + {commas(coins)} coins (saved for you)`)
		expect(`{next.owned.blossom} {next.owned.lantern}`).toBe("nil nil") -- slots 6 and 7 were not earned
		local L = next.login
		expect(`{L.week} {L.weekDays} {L.weekLast} {L.weekClaimed}`).toBe(
			`{MetaRules.weekOf(MONDAY) + 1} 1 {MONDAY + 7} 0`
		)
		-- Only the egg left unclaimed: the toast is the claim's text.
		local four = p
		for _ = 1, 2 do
			four = LoginRules.claim(four, "week", MONDAY + 4)
		end
		expect(select(2, LoginRules.tick(four, MONDAY + 7))).toBe("Weekly Egg! (saved for you)")
		-- Nothing earned and unclaimed: nothing paid, no toast.
		local all = LoginRules.claim(four, "week", MONDAY + 4)
		local quiet, none = LoginRules.tick(all, MONDAY + 7)
		expect(`{quiet.coins - all.coins} {quiet.prizeEggs.weekly} '{none}'`).toBe("0 1 ''")
	end)

	it("pays the earned, unclaimed month slots on the 1st, the Monthly Egg included", function()
		local nov19 = dayOf(2026, 11, 19)
		local p = garden(range(MONDAY, nov19)) -- 18 sign-ins: month slots 1 to 4 earned
		for _ = 1, 2 do
			p = LoginRules.claim(p, "month", nov19)
		end
		for _ = 1, 4 do -- the week of the 16th (4 sign-ins) is claimed, so only the month pays
			p = LoginRules.claim(p, "week", nov19)
		end
		local dec1 = dayOf(2026, 12, 1)
		local next, text = LoginRules.tick(p, dec1)
		local coins = GardenProgress.scaled(p, 500, 30)
		expect(`{next.coins - p.coins} {next.prizeEggs.monthly} {next.owned.lily}`).toBe(`{coins} 1 nil`)
		expect(text).toBe(`Monthly Egg! + {commas(coins)} coins (saved for you)`)
		expect(`{next.login.month} {next.login.monthDays} {next.login.monthClaimed}`).toBe(`{2026 * 12 + 11} 1 0`)
	end)

	it("pays once: a re-run sees the new period, and a re-run on the stored copy gives the same record", function()
		local p = garden(range(MONDAY, MONDAY + 6)) -- a full week, nothing claimed
		local paid = LoginRules.tick(p, MONDAY + 7)
		expect(paid.prizeEggs.weekly).toBe(1)
		expect(`{paid.owned.blossom} {paid.owned.lantern}`).toBe("true true")
		expect(same(LoginRules.tick(paid, MONDAY + 7), paid)).toBe(true) -- the flush re-apply
		expect(same(LoginRules.tick(GardenRules.copy(p), MONDAY + 7), paid)).toBe(true) -- UpdateAsync re-runs
		local tuesday = LoginRules.tick(paid, MONDAY + 8)
		expect(`{tuesday.coins - paid.coins} {tuesday.prizeEggs.weekly} {tuesday.login.weekDays}`).toBe("0 1 2")
		expect(p.prizeEggs.weekly).toBeNil() -- input unchanged
	end)

	it("pays an old save only its last earned period: the periods between had no sign-in", function()
		-- Choice: the save keeps one period per track, and a period with no sign-in earned nothing, so a
		-- save that skipped several periods pays exactly what its stored period earned, once.
		local p = garden(range(MONDAY, MONDAY + 4)) -- Mon to Fri: five week slots, month slot 1 (3)
		local later = MONDAY + 7 * 3 + 2 -- three weeks on, the same month
		local next, text = LoginRules.tick(p, later)
		expect(next.prizeEggs.weekly).toBe(1)
		expect(string.find(text, "Weekly Egg!", 1, true) ~= nil).toBe(true)
		expect(`{next.login.week} {next.login.weekDays}`).toBe(`{MetaRules.weekOf(later)} 1`)
		expect(`{next.login.monthDays} {next.login.monthClaimed}`).toBe("6 0") -- the month goes on, claimable
		expect(LoginRules.canClaim(next, "month", later)).toBe(true)
		-- A February save with 20 sign-ins, next seen in November: February's four slots, once.
		local feb = garden(range(dayOf(2026, 2, 1), dayOf(2026, 2, 20)))
		local nov = LoginRules.tick(feb, dayOf(2026, 11, 5))
		local monthCoins = GardenProgress.scaled(feb, 200, 10)
			+ GardenProgress.scaled(feb, 300, 20)
			+ GardenProgress.scaled(feb, 500, 30)
		expect(nov.prizeEggs.monthly).toBe(1)
		expect(nov.coins - feb.coins - monthCoins > 0).toBe(true) -- plus Feb's last week (Mon 16 to Fri 20)
		expect(`{nov.login.month} {nov.login.monthDays}`).toBe(`{2026 * 12 + 10} 1`)
	end)

	it("pays a claim only for the slot its request saw (QA m5)", function()
		local p = garden(range(MONDAY, MONDAY + 2))
		local one, ok = LoginRules.claim(p, "week", MONDAY + 2, 1)
		expect(ok).toBe(true)
		-- The same op re-run on a record that already holds it (a write that landed but reported failure).
		local again, rerun = LoginRules.claim(one, "week", MONDAY + 2, 1)
		expect(`{rerun} {same(again, one)}`).toBe("false true")
		expect(select(2, LoginRules.claim(p, "week", MONDAY + 2, 2))).toBe(false)
		expect(select(2, LoginRules.claim(one, "week", MONDAY + 2, 2))).toBe(true)
	end)

	it("never resets twice in one UTC day when a server clock is behind (QA m6)", function()
		local sunday = garden(range(MONDAY, MONDAY + 6))
		local monday = LoginRules.claim(LoginRules.tick(sunday, MONDAY + 7), "week", MONDAY + 7) -- server A
		expect(monday.login.weekClaimed).toBe(1)
		local behind = LoginRules.tick(monday, MONDAY + 6) -- server B still on Sunday
		expect(same(behind, monday)).toBe(true)
		local midnight = LoginRules.tick(behind, MONDAY + 7) -- B passes midnight
		expect(same(midnight, monday)).toBe(true)
		expect(LoginRules.canClaim(midnight, "week", MONDAY + 7)).toBe(false) -- slot 2 needs two days
	end)
end)
