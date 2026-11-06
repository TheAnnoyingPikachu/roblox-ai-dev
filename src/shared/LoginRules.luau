--!strict
-- Pure login reward tracks (GDD X3, decision 0017): a weekly (Monday-based UTC week) and a monthly
-- (UTC calendar month) track count distinct sign-in days, not streaks. Slots are claimed in order;
-- earned slots still unclaimed at the rollover are paid then (0017 amendment, QA M1), so nothing
-- earned is lost. `today` is MetaRules.dayOf(now). Copies in, copies out; no Roblox API.
-- GardenProgress wraps tick and claim for the server.

local GardenConfig = require("./GardenConfig")
local GardenRules = require("./GardenRules")
local MetaRules = require("./MetaRules")

local LoginRules = {}

type Profile = GardenConfig.Profile
export type Login = GardenConfig.Login
type Slot = GardenConfig.LoginSlot

LoginRules.TRACKS = { "week", "month" }
LoginRules.MAX_DAYS = 31
LoginRules.MAX_CLAIMED = 7

function LoginRules.defaults(): Login
	return {
		week = -1,
		weekDays = 0,
		weekLast = -1,
		weekClaimed = 0,
		month = -1,
		monthDays = 0,
		monthLast = -1,
		monthClaimed = 0,
	}
end

local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- (year * 12 + month - 1, days in that month) for a UTC day number: Hinnant's civil_from_days.
function LoginRules.monthOf(day: number): (number, number)
	local z = day + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local m = if mp < 10 then mp + 3 else mp - 9
	local y = yoe + era * 400 + (if m <= 2 then 1 else 0)
	local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
	return y * 12 + m - 1, if m == 2 and leap then 29 else MONTH_DAYS[m]
end

function LoginRules.periodOf(track: string, day: number): number
	return if track == "week" then MetaRules.weekOf(day) else (LoginRules.monthOf(day))
end

-- A copy of LOGIN[track]; the month's last slot sits at the month's length when that is under 30.
function LoginRules.slots(track: string, day: number): { Slot }
	local out = table.clone(GardenConfig.LOGIN[track])
	if track == "month" then
		local _, length = LoginRules.monthOf(day)
		local last = table.clone(out[#out])
		last.count = math.min(last.count, length)
		out[#out] = last
	end
	return out
end

function LoginRules.nextSlot(p: Profile, track: string, today: number): (number, Slot?)
	local n = (p.login :: any)[track .. "Claimed"] + 1
	return n, LoginRules.slots(track, today)[n]
end

function LoginRules.canClaim(p: Profile, track: string, today: number): boolean
	if table.find(LoginRules.TRACKS, track) == nil then
		return false
	end
	local login: any = p.login
	local _, slot = LoginRules.nextSlot(p, track, today)
	return login[track] == LoginRules.periodOf(track, today) and slot ~= nil and login[track .. "Days"] >= slot.count
end

local function commas(n: number): string
	local s = string.reverse((string.gsub(string.reverse(string.format("%d", n)), "(%d%d%d)", "%1,")))
	return (string.gsub(s, "^,", ""))
end

-- Pays slot `s` into `out` (a copy): coins as GardenProgress.scaled (floor = base, capped), the egg
-- into prizeEggs, the cosmetic into owned once (coins only after that). Returns the coins paid and
-- the names of the egg and of a newly owned cosmetic.
local function pay(out: Profile, s: Slot): (number, string?, string?)
	local paid, egg, cosmetic = 0, nil, nil
	if s.coins then
		-- The same formula as GardenProgress.scaled (that module wraps this one).
		local scaled = math.max(s.coins, math.floor(GardenRules.income(out) * 60 * (s.minutes or 0) + 1e-9))
		paid = math.min(GardenConfig.MAX_COINS - out.coins, scaled)
		out.coins += paid
	end
	if s.egg then
		out.prizeEggs[s.egg] = math.min(GardenConfig.PRIZE_STORE, (out.prizeEggs[s.egg] or 0) + 1)
		egg = `{(GardenConfig.egg(s.egg) :: GardenConfig.Egg).name}!`
	end
	if s.cosmetic and not out.owned[s.cosmetic] then
		out.owned[s.cosmetic] = true
		cosmetic = (GardenConfig.cosmetic(s.cosmetic) :: MetaRules.Cosmetic).name
	end
	return paid, egg, cosmetic
end

-- Pays the next slot and returns the LastReward text. `slot`, when given, is the slot number the
-- request saw: a re-run on a record that already paid it changes nothing (QA m5).
function LoginRules.claim(p: Profile, track: string, today: number, slot: number?): (Profile, boolean, string)
	local n, s = LoginRules.nextSlot(p, track, today)
	if not LoginRules.canClaim(p, track, today) or (slot ~= nil and slot ~= n) then
		return p, false, ""
	end
	local out = GardenRules.copy(p)
	local paid, egg, cosmetic = pay(out, s :: Slot)
	local text = egg or `{commas(paid)} coins`
	if cosmetic then
		text = `{cosmetic} + {text}`
	end
	(out.login :: any)[track .. "Claimed"] = n
	return out, true, text
end

-- Per track: when the period moved forward, pay every earned slot still unclaimed in the ending
-- period, in order (QA M1: nothing earned is lost), then reset; then count today once. A clock
-- behind the stored period changes nothing, so two servers never reset a track twice (QA m6).
-- Idempotent: a re-run sees the new key. Returns the "(saved for you)" toast text, "" if none.
function LoginRules.tick(p: Profile, today: number): (Profile, string)
	local out = GardenRules.copy(p)
	local login: any = out.login
	local coins, names = 0, {}
	for _, track in LoginRules.TRACKS do
		local key = LoginRules.periodOf(track, today)
		if key > login[track] then
			-- The save keeps one period per track: any period between had no sign-in, so earned nothing.
			local slots = LoginRules.slots(track, login[track .. "Last"])
			for n = login[track .. "Claimed"] + 1, #slots do
				if login[track .. "Days"] < slots[n].count then
					break
				end
				local paid, egg, cosmetic = pay(out, slots[n])
				coins += paid
				if egg then
					table.insert(names, egg)
				end
				if cosmetic then
					table.insert(names, cosmetic)
				end
			end
			login[track] = key
			login[track .. "Days"] = 0
			login[track .. "Last"] = -1
			login[track .. "Claimed"] = 0
		end
		if login[track] == key and today > login[track .. "Last"] then
			login[track .. "Days"] = math.min(LoginRules.MAX_DAYS, login[track .. "Days"] + 1)
			login[track .. "Last"] = today
		end
	end
	if coins > 0 then
		table.insert(names, `{commas(coins)} coins`)
	end
	return out, if #names > 0 then `{table.concat(names, " + ")} (saved for you)` else ""
end

-- Slots claimable now over both tracks (the Rewards badge).
function LoginRules.claimable(p: Profile, today: number): number
	local n = 0
	local login: any = p.login
	for _, track in LoginRules.TRACKS do
		if login[track] == LoginRules.periodOf(track, today) then
			local slots = LoginRules.slots(track, today)
			for i = login[track .. "Claimed"] + 1, #slots do
				if login[track .. "Days"] < slots[i].count then
					break
				end
				n += 1
			end
		end
	end
	return n
end

function LoginRules.sanitize(record: any): Login
	local out: any = LoginRules.defaults()
	if type(record) ~= "table" then
		return out
	end
	for _, track in LoginRules.TRACKS do
		out[track] = MetaRules.dayNumber(record[track])
		out[track .. "Days"] = MetaRules.count(record[track .. "Days"], LoginRules.MAX_DAYS)
		out[track .. "Last"] = MetaRules.dayNumber(record[track .. "Last"])
		out[track .. "Claimed"] = MetaRules.count(record[track .. "Claimed"], LoginRules.MAX_CLAIMED)
	end
	return out
end

return LoginRules
