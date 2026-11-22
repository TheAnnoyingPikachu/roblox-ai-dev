--!strict
-- Pure Animal Stations planners and daily wheel (decision 0094, concept B "grows with you"). The weekly
-- planner has a reward for each day logged in that week (it starts again on Monday); the monthly planner
-- counts days logged in the month (never reset by a missed day) and has milestones, day 28 the month's
-- rainbow animal. One free wheel spin a day. Coins are counted in "wave pays": what the player's next new
-- wave pays (never under 40), so a reward is worth the same at any point of the game; eggs are the best
-- one the player has unlocked. Days are UTC. No Roblox APIs: the server passes the clock, the roll and the
-- animals inside won eggs (rolled with StationRules.hatch), so a save change can run twice.

local LevelRules = require("./LevelRules")
local StationConfig = require("./StationConfig")
local StationProgress = require("./StationProgress")
local StationRules = require("./StationRules")

local StationRewards = {}

type Profile = StationProgress.Profile

-- A reward as written in the planners: wave pays, samples, eggs ("best", "below" = the one before the best,
-- or an egg id), a boost ("hatch" or "train", seconds), the month's rainbow animal, or the wheel's jackpot.
export type Spec = {
	pays: number?,
	samples: number?,
	egg: string?,
	eggs: number?,
	boost: string?,
	seconds: number?,
	rainbow: boolean?,
	jackpot: boolean?,
}
-- The same reward for one player now: coins, samples, egg ids, a boost, the rainbow species.
export type Items = {
	coins: number,
	samples: number,
	eggs: { string },
	boost: string?,
	seconds: number,
	rainbow: string?,
	jackpot: boolean,
}

StationRewards.MIN_PAY = 40
StationRewards.WEEK = {
	{ pays = 5 },
	{ egg = "below", eggs = 2 },
	{ pays = 10 },
	{ boost = "train", seconds = 1800 },
	{ egg = "best" },
	{ pays = 20, samples = 5 },
	{ egg = "best", boost = "hatch", seconds = 3600 },
} :: { Spec }
StationRewards.MONTH = {
	[1] = { pays = 10 },
	[3] = { egg = "best" },
	[7] = { boost = "hatch", seconds = 7200 },
	[10] = { pays = 30, samples = 10 },
	[14] = { egg = "best", eggs = 2 },
	[17] = { boost = "train", seconds = 10800 },
	[21] = { egg = "golden" },
	[24] = { pays = 60, samples = 30 },
	[28] = { rainbow = true },
} :: { [number]: Spec }
StationRewards.MILESTONES = { 1, 3, 7, 10, 14, 17, 21, 24, 28 }
-- The month's rainbow animal, a new species each month from November 2026.
StationRewards.ROTATION = { "cheetah", "jackal", "flamingo", "tortoise", "meerkat", "rhino", "lion", "giraffe" }
StationRewards.FIRST_MONTH = 2026 * 12 + 10 -- November 2026
-- The wheel: eight prizes, `ppm` in a million. The jackpot is a rainbow mythic; after PITY spins without
-- one, its chance doubles (taken from the smallest coin prize) until it comes.
StationRewards.WHEEL = {
	{ name = "2 wave pays", ppm = 300000, prize = { pays = 2 } },
	{ name = "5 wave pays", ppm = 200000, prize = { pays = 5 } },
	{ name = "Meadow Egg", ppm = 150000, prize = { egg = "meadow" } },
	{ name = "Hatching x2, 30 min", ppm = 120000, prize = { boost = "hatch", seconds = 1800 } },
	{ name = "Training x2, 30 min", ppm = 100000, prize = { boost = "train", seconds = 1800 } },
	{ name = "5 samples", ppm = 80000, prize = { samples = 5 } },
	{ name = "Your best egg", ppm = 47500, prize = { egg = "best" } },
	{ name = "RAINBOW MYTHIC", ppm = 2500, prize = { jackpot = true } },
} :: { { name: string, ppm: number, prize: Spec } }
StationRewards.PITY = 100

-- Days since 1970 (UTC) of `now`; the Monday that starts its week; year * 12 + month - 1.
function StationRewards.day(now: number): number
	return math.floor(now / 86400)
end
function StationRewards.weekOf(day: number): number
	return day - (day + 3) % 7 -- 1 January 1970 was a Thursday
end
function StationRewards.monthOf(now: number): number
	local t = os.date("!*t", math.floor(now)) :: any
	return t.year * 12 + t.month - 1
end

-- The species whose rainbow the month `month` (year * 12 + month - 1) gives.
function StationRewards.rainbowOf(month: number): string
	local n = #StationRewards.ROTATION
	return StationRewards.ROTATION[(month - StationRewards.FIRST_MONTH) % n + 1]
end

-- Count today for `p` (once a day): a day logged in the week and the month, a new week or month starting
-- afresh. Eggs won while the storage was full move into it as room allows.
function StationRewards.visit(p: Profile, now: number): Profile
	local r = p.rewards
	local d = StationRewards.day(now)
	if d > r.day then
		r.day = d
		local week = StationRewards.weekOf(d)
		if week ~= r.week then
			r.week, r.weekDays, r.weekGot = week, 0, 0
		end
		r.weekDays = math.min(7, r.weekDays + 1)
		local month = StationRewards.monthOf(now)
		if month ~= r.month then
			r.month, r.monthDays, r.monthGot = month, 0, {}
		end
		r.monthDays = math.min(31, r.monthDays + 1)
	end
	local room = StationProgress.value(p, "hatchery") + StationProgress.value(p, "cellar") - #p.eggs
	while room > 0 and #r.pending > 0 do
		local e = table.remove(r.pending, 1) :: StationProgress.HeldEgg
		table.insert(p.eggs, { egg = e.egg, animal = e.animal })
		room -= 1
	end
	return p
end

-- What the player's next new wave pays: one "wave pay".
function StationRewards.wavePay(p: Profile): number
	return math.max(StationRewards.MIN_PAY, LevelRules.reward(p.best + 1, p.best))
end

-- The best egg `p` has unlocked, and the one before it (the Meadow Egg when that is the best).
function StationRewards.bestEgg(p: Profile): (string, string)
	local best, below = StationConfig.EGGS[1].id, StationConfig.EGGS[1].id
	for _, e in StationConfig.EGGS do
		if e.wave == nil or p.best >= e.wave then
			below, best = best, e.id
		end
	end
	return best, below
end

-- `spec` as it is for `p` now.
function StationRewards.resolve(p: Profile, spec: Spec, month: number?): Items
	local best, below = StationRewards.bestEgg(p)
	local eggs = {}
	if spec.egg then
		local id = if spec.egg == "best" then best elseif spec.egg == "below" then below else spec.egg
		for _ = 1, spec.eggs or 1 do
			table.insert(eggs, id)
		end
	end
	return {
		coins = (spec.pays or 0) * StationRewards.wavePay(p),
		samples = spec.samples or 0,
		eggs = eggs,
		boost = spec.boost,
		seconds = spec.seconds or 0,
		rainbow = if spec.rainbow then StationRewards.rainbowOf(month or p.rewards.month) else nil,
		jackpot = spec.jackpot == true,
	}
end

-- Every mythic variant, in the config's order: the jackpot is one of them.
function StationRewards.mythics(): { { s: string, v: string } }
	local out = {}
	for _, sp in StationConfig.SPECIES do
		for _, va in sp.variants do
			if va.tier == "mythic" then
				table.insert(out, { s = sp.id, v = va.id })
			end
		end
	end
	return out
end

-- Whether `items` can be given to `p` now: an animal needs room in the barn, eggs room in the storage or in
-- the waiting list.
function StationRewards.canGrant(p: Profile, items: Items): (boolean, string?)
	if (items.rainbow or items.jackpot) and #p.animals >= StationProgress.value(p, "barn") then
		return false, "full"
	end
	local room = StationProgress.value(p, "hatchery") + StationProgress.value(p, "cellar") - #p.eggs
	if #items.eggs > math.max(0, room) + StationProgress.MAX_PENDING - #p.rewards.pending then
		return false, "eggs_full"
	end
	return true, nil
end

-- Give `items` to `p` at `now`. `animals[k]` is the animal inside items.eggs[k] (rolled by the server);
-- `mythic` the jackpot's animal. Eggs go to the storage, or wait when it is full.
function StationRewards.grant(
	p: Profile,
	items: Items,
	animals: { StationRules.Owned },
	mythic: { s: string, v: string }?,
	now: number
): (Profile, boolean, string?)
	local ok, code = StationRewards.canGrant(p, items)
	if not ok then
		return p, false, code
	elseif #animals < #items.eggs or (items.jackpot and mythic == nil) then
		return p, false, "animal"
	end
	p.coins = math.min(p.coins + items.coins, StationProgress.MAX_COINS)
	p.samples = math.min(p.samples + items.samples, StationProgress.MAX_SAMPLES)
	if items.boost then
		StationProgress.addBoost(p, items.boost, items.seconds, now)
	end
	p.eggs = table.clone(p.eggs)
	local room = StationProgress.value(p, "hatchery") + StationProgress.value(p, "cellar") - #p.eggs
	for k, id in items.eggs do
		local held = { egg = id, animal = animals[k] }
		if room > 0 then
			table.insert(p.eggs, held)
			room -= 1
		else
			table.insert(p.rewards.pending, held)
		end
	end
	if items.rainbow then
		local _, given, why = StationProgress.give(p, items.rainbow, nil, 1, true)
		if not given then
			return p, false, why
		end
	end
	if items.jackpot and mythic then
		local _, given, why = StationProgress.give(p, mythic.s, mythic.v, 1, true)
		if not given then
			return p, false, why
		end
	end
	return p, true, nil
end

-- The weekly reward `p` can claim next, or why none.
function StationRewards.nextWeek(p: Profile): (Spec?, string?)
	local r = p.rewards
	if r.weekGot >= r.weekDays then
		return nil, "claimed"
	end
	return StationRewards.WEEK[r.weekGot + 1], nil
end

-- Whether monthly milestone `d` can be claimed by `p`.
function StationRewards.canMonth(p: Profile, d: number): (boolean, string?)
	local r = p.rewards
	if StationRewards.MONTH[d] == nil then
		return false, "reward"
	elseif table.find(r.monthGot, d) then
		return false, "claimed"
	elseif r.monthDays < d then
		return false, "not_yet"
	end
	return true, nil
end

-- Claim the next weekly reward (`items` resolved from it, `animals` inside its eggs).
function StationRewards.claimWeek(
	p: Profile,
	items: Items,
	animals: { StationRules.Owned },
	now: number
): (Profile, boolean, string?)
	local spec, code = StationRewards.nextWeek(p)
	if spec == nil then
		return p, false, code
	end
	local _, ok, why = StationRewards.grant(p, items, animals, nil, now)
	if not ok then
		return p, false, why
	end
	p.rewards.weekGot += 1
	return p, true, nil
end

-- Claim monthly milestone `d`.
function StationRewards.claimMonth(
	p: Profile,
	d: number,
	items: Items,
	animals: { StationRules.Owned },
	now: number
): (Profile, boolean, string?)
	local can, code = StationRewards.canMonth(p, d)
	if not can then
		return p, false, code
	end
	local _, ok, why = StationRewards.grant(p, items, animals, nil, now)
	if not ok then
		return p, false, why
	end
	table.insert(p.rewards.monthGot, d)
	return p, true, nil
end

-- Whether `p` has a spin: the day's free one, or one won.
function StationRewards.canSpin(p: Profile, now: number): boolean
	return p.rewards.spinDay < StationRewards.day(now) or p.rewards.spins > 0
end

-- The prize a roll lands on: `roll` from 0 to 999,999. With PITY spins behind it, the jackpot's chance
-- doubles, taken from the first prize.
function StationRewards.prizeOf(p: Profile, roll: number): number
	local wheel = StationRewards.WHEEL
	local extra = if p.rewards.pity >= StationRewards.PITY then wheel[#wheel].ppm else 0
	local at = 0
	for k, slice in wheel do
		local ppm = slice.ppm + (if k == 1 then -extra elseif k == #wheel then extra else 0)
		at += ppm
		if roll < at then
			return k
		end
	end
	return #wheel
end

-- Spin the wheel: `prize` is prizeOf(roll) and `items` its reward for `p` (resolved before, with the eggs'
-- animals and the jackpot's mythic rolled). Uses the free spin first.
function StationRewards.spin(
	p: Profile,
	prize: number,
	items: Items,
	animals: { StationRules.Owned },
	mythic: { s: string, v: string }?,
	now: number
): (Profile, boolean, string?)
	if not StationRewards.canSpin(p, now) then
		return p, false, "spun"
	elseif #p.animals >= StationProgress.value(p, "barn") then -- room for the jackpot, whatever the roll
		return p, false, "full"
	end
	local _, ok, why = StationRewards.grant(p, items, animals, mythic, now)
	if not ok then
		return p, false, why
	end
	local r = p.rewards
	if r.spinDay < StationRewards.day(now) then
		r.spinDay = StationRewards.day(now)
	else
		r.spins -= 1
	end
	r.pity = if prize == #StationRewards.WHEEL then 0 else r.pity + 1
	return p, true, nil
end

-- Star chests (decision 0097): one every StationProgress.CHEST_STARS stars, in this order and round again.
-- Boss chests (decision 0098): clearing a boss wave in a run, by the boss wave's number.
StationRewards.CHESTS = {
	{ pays = 10 },
	{ egg = "best" },
	{ pays = 20, samples = 10 },
	{ egg = "best", boost = "train", seconds = 3600 },
	{ egg = "golden" },
} :: { Spec }
StationRewards.BOSS_CHESTS = {
	{ egg = "best" },
	{ boost = "hatch", seconds = 3600 },
	{ boost = "train", seconds = 3600 },
} :: { Spec }

-- The next star chest's reward for `p`, or nil and why when none is due.
function StationRewards.nextChest(p: Profile): (Spec?, string?)
	if StationProgress.chestsDue(p) <= 0 then
		return nil, "not_yet"
	end
	return StationRewards.CHESTS[p.chests % #StationRewards.CHESTS + 1], nil
end

-- Open the next star chest.
function StationRewards.claimChest(
	p: Profile,
	items: Items,
	animals: { StationRules.Owned },
	now: number
): (Profile, boolean, string?)
	local spec, code = StationRewards.nextChest(p)
	if spec == nil then
		return p, false, code
	end
	local _, ok, why = StationRewards.grant(p, items, animals, nil, now)
	if not ok then
		return p, false, why
	end
	p.chests += 1
	return p, true, nil
end

-- The boss chest for clearing boss wave `wave`.
function StationRewards.bossChest(wave: number): Spec
	local n = math.max(1, wave // 10)
	return StationRewards.BOSS_CHESTS[(n - 1) % #StationRewards.BOSS_CHESTS + 1]
end

return StationRewards
