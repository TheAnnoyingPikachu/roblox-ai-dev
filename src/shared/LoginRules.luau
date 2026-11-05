--!strict
-- Pure login reward tracks (GDD X3, decision 0017): a weekly (Monday-based UTC week) and a monthly
-- (UTC calendar month) track count distinct sign-in days, not streaks. Slots are claimed in order;
-- unclaimed slots expire at the rollover. `today` is MetaRules.dayOf(now). Copies in, copies out;
-- no Roblox API. GardenProgress wraps tick and claim for the server.

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

-- Per track: reset when the period changed, then count today once. Idempotent for the same day.
function LoginRules.tick(p: Profile, today: number): Profile
	local out = GardenRules.copy(p)
	local login: any = out.login
	for _, track in LoginRules.TRACKS do
		local key = LoginRules.periodOf(track, today)
		if login[track] ~= key then
			login[track] = key
			login[track .. "Days"] = 0
			login[track .. "Last"] = -1
			login[track .. "Claimed"] = 0
		end
		if login[track .. "Last"] ~= today then
			login[track .. "Days"] = math.min(LoginRules.MAX_DAYS, login[track .. "Days"] + 1)
			login[track .. "Last"] = today
		end
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

-- Pays the next slot: coins as GardenProgress.scaled (floor = base, capped), the egg into
-- prizeEggs, the cosmetic into owned once (coins only after that). Returns the LastReward text.
function LoginRules.claim(p: Profile, track: string, today: number): (Profile, boolean, string)
	if not LoginRules.canClaim(p, track, today) then
		return p, false, ""
	end
	local _, slot = LoginRules.nextSlot(p, track, today)
	local s = slot :: Slot
	local out = GardenRules.copy(p)
	local text = ""
	if s.coins then
		-- The same formula as GardenProgress.scaled (that module wraps this one).
		local scaled = math.max(s.coins, math.floor(GardenRules.income(out) * 60 * (s.minutes or 0) + 1e-9))
		local paid = math.min(GardenConfig.MAX_COINS - out.coins, scaled)
		out.coins += paid
		text = `{commas(paid)} coins`
	end
	if s.egg then
		out.prizeEggs[s.egg] = math.min(GardenConfig.PRIZE_STORE, (out.prizeEggs[s.egg] or 0) + 1)
		text = `{(GardenConfig.egg(s.egg) :: GardenConfig.Egg).name}!`
	end
	if s.cosmetic and not out.owned[s.cosmetic] then
		out.owned[s.cosmetic] = true
		text = `{(GardenConfig.cosmetic(s.cosmetic) :: MetaRules.Cosmetic).name} + {text}`
	end
	(out.login :: any)[track .. "Claimed"] += 1
	return out, true, text
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
