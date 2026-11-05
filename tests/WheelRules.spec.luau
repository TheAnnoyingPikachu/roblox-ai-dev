--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local Rng = require("../src/shared/Rng")
local WheelRules = require("../src/shared/WheelRules")

local describe, it, expect = T.describe, T.it, T.expect

type Round = WheelRules.Round
type Drop = WheelRules.Drop
type Profile = GardenConfig.Profile

local WHEEL = GardenConfig.WHEEL
local C = WHEEL.centre
local START = 100
local DAY = 20_000
local NOW = DAY * 86400 + 10

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

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

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function kinds(drops: { Drop }): string
	local out = {}
	for _, d in drops do
		table.insert(out, string.sub(d.kind, 1, 1))
	end
	return table.concat(out)
end

local function count(drops: { Drop }): string
	local n = { pink = 0, gold = 0, cone = 0 }
	for _, d in drops do
		n[d.kind] += 1
	end
	return `{n.pink} {n.gold} {n.cone}`
end

local function dist(d: Drop): number
	return math.sqrt((d.x - C.x) ^ 2 + (d.z - C.z) ^ 2)
end

-- A spot `away` studs from drop `d`, at ground level.
local function at(d: Drop, away: number, y: number?): WheelRules.Vec3
	return { x = d.x + away, y = y or C.y, z = d.z }
end

local function round(eligible: boolean?, n: number?): Round
	return WheelRules.new(7, 12345, START, eligible ~= false, n or 1)
end

local DROPS = WheelRules.schedule(12345, START)
local ONE: { Drop } = { DROPS[1] } -- geometry checks on drop 1 alone: other spots can overlap its radius

-- Runs `body` with GardenRules.income stubbed, as GardenProgress.spec does.
local function withIncome(income: number, body: () -> ())
	local real = GardenRules.income
	GardenRules.income = function(_: Profile): number
		return income
	end
	local ok, err = pcall(body)
	GardenRules.income = real
	if not ok then
		error(err, 0)
	end
end

describe("WheelRules schedule (W3.1, W10)", function()
	it("gives 40 drops, 26 / 4 / 10, at startAt + 2 + (i - 1), each 4 to 12 from the centre, for 200 seeds", function()
		for seed = 1, 200 do
			local drops = WheelRules.schedule(seed, START)
			expect(#drops).toBe(40)
			expect(count(drops)).toBe("26 4 10")
			for i, d in drops do
				expect(near(d.at, START + 2 + (i - 1))).toBe(true)
				local r = dist(d)
				expect(`{seed} {i} {r >= 4 - 1e-9 and r <= 12 + 1e-9}`).toBe(`{seed} {i} true`)
			end
		end
		expect(DROPS[1].at).toBe(102)
		expect(DROPS[40].at).toBe(141)
	end)

	it("is deterministic in (seed, startAt) and differs between seeds 1 and 2", function()
		expect(same(WheelRules.schedule(12345, START), DROPS)).toBe(true)
		local a, b = WheelRules.schedule(1, START), WheelRules.schedule(2, START)
		expect(kinds(a) ~= kinds(b) or a[1].x ~= b[1].x or a[1].z ~= b[1].z).toBe(true)
		local later = WheelRules.schedule(1, START + 50)
		expect(kinds(later)).toBe(kinds(a))
		expect(later[1].at).toBe(a[1].at + 50)
	end)

	it("follows the 2.2 algorithm exactly (Fisher-Yates with Rng.int, then two Rng.next per drop)", function()
		local list = {}
		for _, pair in { { "pink", 26 }, { "gold", 4 }, { "cone", 10 } } do
			for _ = 1, pair[2] :: number do
				table.insert(list, pair[1])
			end
		end
		local state = 12345
		for i = 40, 2, -1 do
			local j
			j, state = Rng.int(state, 1, i)
			list[i], list[j] = list[j], list[i]
		end
		for i = 1, 40 do
			local u, v
			u, state = Rng.next(state)
			v, state = Rng.next(state)
			local r = 4 + 8 * math.sqrt(u)
			local a = 2 * math.pi * v
			expect(DROPS[i].kind).toBe(list[i])
			expect(near(DROPS[i].x, C.x + r * math.cos(a))).toBe(true)
			expect(near(DROPS[i].z, C.z + r * math.sin(a))).toBe(true)
		end
		-- Pinned for seed 12345 so a drift in either Rng or the shuffle shows up as a literal change.
		expect(kinds(DROPS)).toBe("pppppcgpcppgppppccppcppcpcppppcpgcgppppc")
		expect(string.format("%.3f %.3f %.3f %.3f", DROPS[1].x, DROPS[1].z, DROPS[40].x, DROPS[40].z)).toBe(
			"-42.317 -46.225 -32.144 -55.494"
		)
	end)
end)

describe("WheelRules catch geometry (W3.2, W10)", function()
	local d1 = DROPS[1]

	it("has the drop at 102 catchable from 104.25 to 105.75", function()
		local from, to = WheelRules.bandAt(d1)
		expect(`{from} {to}`).toBe("104.25 105.75")
	end)

	it("catches at 105.0 within 3.4 studs, not at 3.6", function()
		local r, events = WheelRules.sample(round(), ONE, at(d1, 3.4), 105)
		expect(#events).toBe(1)
		expect(`{events[1].kind} {events[1].i} {events[1].drop} {events[1].score}`).toBe(
			`catch 1 {d1.kind} {math.max(0, WHEEL.points[d1.kind])}`
		)
		expect(r.done[1]).toBe(true)
		local r2, none = WheelRules.sample(round(), ONE, at(d1, 3.6), 105)
		expect(#none).toBe(0)
		expect(r2.done[1]).toBeNil()
	end)

	it("does not catch above the band at 104.0, and the drop is still catchable at 104.4", function()
		local r, events = WheelRules.sample(round(), ONE, at(d1, 0), 104)
		expect(#events).toBe(0)
		expect(r.done[1]).toBeNil()
		local _, later = WheelRules.sample(r, ONE, at(d1, 0), 104.4)
		expect(#later).toBe(1)
	end)

	it("does not catch a landed drop at 106.0 and marks it done without an event", function()
		local r, events = WheelRules.sample(round(), ONE, at(d1, 0), 106)
		expect(#events).toBe(0)
		expect(r.done[1]).toBe(true)
	end)

	it("needs the root near the ground and never resolves a drop twice", function()
		local _, high = WheelRules.sample(round(), ONE, at(d1, 0, C.y + 10.5), 105)
		expect(#high).toBe(0)
		local _, low = WheelRules.sample(round(), ONE, at(d1, 0, C.y - 2.5), 105)
		expect(#low).toBe(0)
		local r, first = WheelRules.sample(round(), ONE, at(d1, 0, C.y + 10), 105)
		expect(#first).toBe(1)
		local r2, again = WheelRules.sample(r, ONE, at(d1, 0), 105.2)
		expect(#again).toBe(0)
		expect(r2.score).toBe(r.score)
	end)

	it("keeps the band open for 1.5 s, so 5 Hz sees at least 7 samples", function()
		local from, to = WheelRules.bandAt(d1)
		expect(near(to - from, 1.5)).toBe(true)
		for offset = 0, 0.19, 0.01 do
			local seen = 0
			for k = 0, 10 do
				local t = from + offset + 0.2 * k
				if t <= to then
					local _, events = WheelRules.sample(round(), ONE, at(d1, 0), t)
					seen += #events
				end
			end
			expect(seen >= 7).toBe(true)
		end
	end)

	it("is a no-op after endAt and can catch more than one drop in a sample", function()
		local r = round()
		expect(r.endAt).toBe(START + 45)
		local same_, events = WheelRules.sample(r, ONE, at(d1, 0), r.endAt)
		expect(same_ == r and #events == 0).toBe(true)
		-- Two drops placed on the same spot, one second apart: both in the band at 105.75.
		local pair: { Drop } = { { at = 102, kind = "pink", x = 0, z = 0 }, { at = 103, kind = "gold", x = 0, z = 0 } }
		local _, both = WheelRules.sample(r, pair, { x = 0, y = C.y, z = 0 }, 105.5)
		expect(`{#both} {both[1].i} {both[2].i} {both[2].score}`).toBe("2 1 2 4")
	end)
end)

describe("WheelRules score and tiers (W3.3)", function()
	local function scored(score: number, eligible: boolean?): Round
		local r = round(eligible)
		r.score = score
		return r
	end
	local spot = { x = 0, y = C.y, z = 0 }
	local function one(kind: WheelRules.Kind, score: number): number
		local r = round()
		r.score = score
		local out = WheelRules.sample(r, { { at = 102, kind = kind, x = 0, z = 0 } }, spot, 105)
		return out.score
	end

	it("scores +1, +3 and -2 floored at 0", function()
		expect(one("pink", 0)).toBe(1)
		expect(one("gold", 0)).toBe(3)
		expect(one("cone", 5)).toBe(3)
		expect(one("cone", 1)).toBe(0)
		expect(one("cone", 0)).toBe(0)
	end)

	it("gives none / spin / spin / lucky at 11 / 12 / 23 / 24, and none when not eligible", function()
		expect(WheelRules.tier(scored(11))).toBe("none")
		expect(WheelRules.tier(scored(12))).toBe("spin")
		expect(WheelRules.tier(scored(23))).toBe("spin")
		expect(WheelRules.tier(scored(24))).toBe("lucky")
		expect(WheelRules.tier(scored(38, false))).toBe("none")
	end)

	it("finishes only at endAt with the score and tier", function()
		local r = scored(17)
		local _, early = WheelRules.finish(r, r.endAt - 0.1)
		expect(#early).toBe(0)
		local _, events = WheelRules.finish(r, r.endAt)
		expect(`{events[1].kind} {events[1].score} {events[1].tier}`).toBe("over 17 spin")
	end)
end)

describe("WheelRules wheel (W4, decision 0016)", function()
	it("has both columns summing to 10,000 with every wedge above zero", function()
		local standard, lucky = 0, 0
		for _, w in WHEEL.wedges do
			expect(`{w.id} {w.standard > 0 and w.lucky > 0}`).toBe(`{w.id} true`)
			standard += w.standard
			lucky += w.lucky
		end
		expect(`{standard} {lucky}`).toBe("10000 10000")
	end)

	it("lands 100,000 rolls on every wedge within 15% of its bp, on both wheels", function()
		for _, lucky in { false, true } do
			local hits: { [string]: number } = {}
			local state = Rng.seed(2, if lucky then 1 else 0)
			for _ = 1, 100_000 do
				local id
				id, state = WheelRules.roll(state, lucky)
				hits[id] = (hits[id] or 0) + 1
			end
			for _, w in WHEEL.wedges do
				local want = (if lucky then w.lucky else w.standard) * 10
				local got = hits[w.id] or 0
				expect(`{w.id} {lucky} {math.abs(got - want) <= want * 0.15}`).toBe(`{w.id} {lucky} true`)
			end
		end
	end)

	it("pays the W5 expected value: 127.0 standard, 189.1 lucky coins/s per spin", function()
		local value = { meadow = 3, forest = 12, sunset = 75, moon = 299, star = 735, celestial = 20488, aurora = 6362 }
		local standard, lucky = 0, 0
		for _, w in WHEEL.wedges do
			local v = (value :: any)[w.id] or 0
			standard += w.standard / 10000 * v
			lucky += w.lucky / 10000 * v
		end
		expect(string.format("%.1f %.1f", standard, lucky)).toBe("127.0 189.1")
	end)
end)

describe("WheelRules spins and award (W4.2, W6, W10)", function()
	local function profile(spins: number?, day: number?): Profile
		local p = GardenProgress.defaults(NOW)
		p.wheelToday = { day = day or DAY, spins = spins or 0 }
		return p
	end

	it("counts spins for today only, with the cap and the day rollover", function()
		local p = profile(2)
		expect(`{WheelRules.spinsToday(p, DAY)} {WheelRules.spinsLeft(p, DAY)} {WheelRules.canSpin(p, DAY)}`).toBe(
			"2 1 true"
		)
		local capped = profile(3)
		expect(`{WheelRules.spinsLeft(capped, DAY)} {WheelRules.canSpin(capped, DAY)}`).toBe("0 false")
		expect(`{WheelRules.spinsLeft(capped, DAY + 1)} {WheelRules.canSpin(capped, DAY + 1)}`).toBe("3 true")
		expect(WheelRules.spinsLeft(GardenProgress.defaults(NOW), DAY)).toBe(3)
	end)

	it("applies spin 3 after two, and nothing at the cap", function()
		local out, ok = WheelRules.award(profile(2), DAY, 3, "moon")
		expect(ok).toBe(true)
		expect(`{out.wheelToday.day} {out.wheelToday.spins} {WheelRules.spinsLeft(out, DAY)}`).toBe(`{DAY} 3 0`)
		expect(out.prizeEggs.moon).toBe(1)
		local p = profile(3)
		local same_, applied, paid = WheelRules.award(p, DAY, 4, "moon")
		expect(`{same_ == p} {applied} {paid}`).toBe("true false 0")
	end)

	it("is idempotent on (today, n) and refuses out-of-order ops", function()
		local once, ok = WheelRules.award(profile(1), DAY, 2, "moon")
		expect(ok).toBe(true)
		local twice, again = WheelRules.award(once, DAY, 2, "moon")
		expect(`{again} {twice == once}`).toBe("false true")
		local skipped, bad = WheelRules.award(profile(1), DAY, 3, "moon")
		expect(`{bad} {skipped.prizeEggs.moon}`).toBe("false nil")
		local _, early = WheelRules.award(profile(1), DAY, 1, "moon")
		expect(early).toBe(false)
	end)

	it("resets the counter on a new day: award(p, today + 1, 1) is spin 1 of that day", function()
		local out, ok = WheelRules.award(profile(3), DAY + 1, 1, "forest")
		expect(ok).toBe(true)
		expect(same(out.wheelToday, { day = DAY + 1, spins = 1 })).toBe(true)
		expect(select(2, WheelRules.award(profile(3), DAY + 1, 2, "forest"))).toBe(false)
	end)

	it("pays scaled(100, 10) on Coins: 36,300 at 60.5 coins/s, 100 at 0, clamped to MAX_COINS", function()
		withIncome(60.5, function()
			local out, ok, paid = WheelRules.award(profile(0), DAY, 1, "coins")
			expect(`{ok} {paid} {out.coins}`).toBe(`true 36300 {100 + 36300}`)
			expect(next(out.prizeEggs)).toBeNil()
		end)
		withIncome(0, function()
			local _, _, paid = WheelRules.award(profile(0), DAY, 1, "coins")
			expect(paid).toBe(100)
			local rich = profile(0)
			rich.coins = GardenConfig.MAX_COINS
			local out, ok, none = WheelRules.award(rich, DAY, 1, "coins")
			expect(`{ok} {none} {out.coins == GardenConfig.MAX_COINS} {out.wheelToday.spins}`).toBe("true 0 true 1")
		end)
	end)

	it("caps prizeEggs at PRIZE_STORE", function()
		local p = profile(0)
		p.prizeEggs.celestial = 999_999
		local out = WheelRules.award(p, DAY, 1, "celestial")
		expect(out.prizeEggs.celestial).toBe(1_000_000)
		expect(WheelRules.award(out, DAY, 2, "celestial").prizeEggs.celestial).toBe(1_000_000)
	end)

	it("gives distinct spin ids across n and days", function()
		local seen: { [number]: boolean } = {}
		for day = DAY, DAY + 2 do
			for n = 1, 3 do
				local id = WheelRules.spinId(day, n)
				expect(seen[id]).toBeNil()
				seen[id] = true
			end
		end
		expect(WheelRules.spinId(DAY, 2)).toBe(DAY * 10 + 2)
	end)

	it("never mutates its inputs", function()
		local r = round()
		local drops = deepCopy(DROPS)
		local before = deepCopy(r)
		WheelRules.sample(r, DROPS, at(DROPS[1], 0), 105)
		WheelRules.finish(r, r.endAt)
		WheelRules.tier(r)
		expect(same(r, before)).toBe(true)
		expect(same(DROPS, drops)).toBe(true)
		local p = profile(1)
		p.prizeEggs.moon = 1
		local copy = deepCopy(p)
		WheelRules.award(p, DAY, 2, "moon")
		WheelRules.award(p, DAY, 2, "coins")
		expect(same(p, copy)).toBe(true)
	end)
end)
