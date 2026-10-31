--!strict
local T = require("./framework")
local DashRules = require("../src/shared/DashRules")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local MetaRules = require("../src/shared/MetaRules")
local Rng = require("../src/shared/Rng")

local describe, it, expect = T.describe, T.it, T.expect

type Round = DashRules.Round
type Event = DashRules.Event

local DASH = GardenConfig.DASH
local CP = DASH.checkpoints
local GO = 120 -- from ready at 100: countdown to 115, then 5 s

-- Round in `racing` at GO. `capped` entrants are not eligible for the egg.
local function race(ids: { number }, capped: { [number]: boolean }?): Round
	local r = DashRules.new()
	local entrants: { DashRules.Entrant } = {}
	for _, id in ids do
		r = DashRules.setReady(r, id, true, 100)
		table.insert(entrants, { id = id, eligible = not (capped and capped[id]) })
	end
	r = DashRules.start(r, 115, entrants)
	r = DashRules.step(r, GO)
	assert(r.phase == "racing", "race helper did not reach racing")
	return r
end

-- Samples `id` through checkpoints `from` to `to`, 3 s apart, starting at `t`. Returns the time after.
local function through(r: Round, id: number, from: number, to: number, t: number): (Round, number)
	for cp = from, to do
		r = DashRules.sample(r, id, CP[cp], t)
		t += 3
	end
	return r, t
end

-- Runs `id` to the last checkpoint before the finish, then finishes it at exactly `at`.
local function finishAt(r: Round, id: number, at: number): (Round, { Event })
	r = through(r, id, r.racers[id].next, #CP - 1, GO + 1)
	return DashRules.sample(r, id, CP[#CP], at)
end

local function kinds(events: { Event }): string
	local out = {}
	for _, e in events do
		table.insert(out, e.kind)
	end
	return table.concat(out, " ")
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

describe("DashRules GDD T10 check values", function()
	it("counts down from the third ready: 100 + 15 = 115, and a fourth does not move it", function()
		local r = DashRules.new()
		r = DashRules.setReady(r, 1, true, 100)
		r = DashRules.setReady(r, 2, true, 100)
		expect(r.phase).toBe("idle")
		expect(r.at).toBe(0)
		r = DashRules.setReady(r, 3, true, 100)
		expect(r.phase).toBe("countdown")
		expect(r.at).toBe(115)
		r = DashRules.setReady(r, 4, true, 110)
		expect(r.at).toBe(115)
		expect(#r.ready).toBe(4)
	end)

	it("cancels at 112 when it drops to 2, and a third again at 113 ends at 128", function()
		local r = DashRules.new()
		for id = 1, 3 do
			r = DashRules.setReady(r, id, true, 100)
		end
		r = DashRules.setReady(r, 2, false, 112)
		expect(r.phase).toBe("idle")
		expect(r.at).toBe(0)
		expect(table.concat(r.ready, " ")).toBe("1 3")
		r = DashRules.setReady(r, 4, true, 113)
		expect(r.phase).toBe("countdown")
		expect(r.at).toBe(128)
	end)

	it("from a countdown ending at 115: GO at 120 and the time limit at 240", function()
		local r = DashRules.new()
		local entrants = {}
		for id = 1, 3 do
			r = DashRules.setReady(r, id, true, 100)
			table.insert(entrants, { id = id, eligible = true })
		end
		local events
		r, events = DashRules.start(r, 115, entrants)
		expect(kinds(events)).toBe("start")
		expect(table.concat(events[1].ids :: { number }, " ")).toBe("1 2 3")
		expect(r.phase).toBe("starting")
		expect(r.at).toBe(120)
		expect(r.goAt).toBe(120)
		expect(#r.ready).toBe(0) -- racers are not re-readied
		r, events = DashRules.step(r, 119.9)
		expect(r.phase).toBe("starting")
		expect(#events).toBe(0)
		r, events = DashRules.step(r, 120)
		expect(kinds(events)).toBe("go")
		expect(r.phase).toBe("racing")
		expect(r.at).toBe(240)
		expect(r.goAt).toBe(120)
	end)

	it("after a first finish at GO + 45, ends at GO + 65 at the latest", function()
		local r = race({ 1, 2, 3 })
		r = finishAt(r, 1, GO + 45)
		expect(r.winner).toBe(1)
		expect(r.at).toBe(GO + 65)
		local before, none = DashRules.step(r, GO + 64.9)
		expect(before.phase).toBe("racing")
		expect(#none).toBe(0)
		local over, events = DashRules.step(r, GO + 65)
		expect(over.phase).toBe("idle")
		expect(kinds(events)).toBe("over")
		expect(events[1].reason).toBe("finished")
		expect(table.concat(events[1].ids :: { number }, " ")).toBe("1 2 3")
	end)

	it("keeps the earlier time limit when the first finish is near it", function()
		local r = finishAt(race({ 1, 2, 3 }), 1, GO + 110)
		expect(r.at).toBe(GO + 120)
	end)

	it("refuses a finish at GO + 24.9 with a strike and accepts GO + 25.0", function()
		local r = through(race({ 1, 2, 3 }), 1, 1, 4, GO + 1)
		local early, flagged = DashRules.sample(r, 1, CP[5], GO + 24.9)
		expect(kinds(flagged)).toBe("flag")
		expect(flagged[1].cp).toBe(4)
		expect(early.racers[1].strikes).toBe(1)
		expect(early.racers[1].finished).toBeNil()
		expect(early.winner).toBeNil()
		local ok, events = DashRules.sample(r, 1, CP[5], GO + 25)
		expect(kinds(events)).toBe("finish")
		expect(events[1].time).toBe(25)
		expect(events[1].place).toBe(1)
		expect(ok.racers[1].strikes).toBe(0)
		expect(ok.racers[1].finished).toBe(25)
	end)

	it("allows 31 studs between samples 0.2 s apart and strikes 32", function()
		local start = { x = -100, y = 144, z = 300 }
		local r = DashRules.sample(race({ 1, 2, 3 }), 1, start, 130)
		local _, fine = DashRules.sample(r, 1, { x = -69, y = 144, z = 300 }, 130.2)
		expect(#fine).toBe(0)
		local out, flagged = DashRules.sample(r, 1, { x = -68, y = 144, z = 300 }, 130.2)
		expect(kinds(flagged)).toBe("flag")
		expect(flagged[1].cp).toBe(0)
		expect(out.racers[1].strikes).toBe(1)
	end)

	it("measures from the last changed sample: frozen 2 s then 100 studs is allowed, 222 is not", function()
		local start = { x = -100, y = 144, z = 300 }
		local r = DashRules.sample(race({ 1, 2, 3 }), 1, start, 130)
		for i = 1, 10 do
			r = DashRules.sample(r, 1, start, 130 + i * 0.2)
		end
		expect(r.racers[1].lastAt).toBe(130)
		local out, none = DashRules.sample(r, 1, { x = -100, y = 144, z = 400 }, 132.2)
		expect(#none).toBe(0)
		expect(out.racers[1].lastAt).toBe(132.2)
		local _, far = DashRules.sample(r, 1, { x = 122, y = 144, z = 300 }, 132.2)
		expect(kinds(far)).toBe("flag")
	end)

	it("pays coins of 3,630 at 60.5 coins/s and 100 at 0 income", function()
		local p = GardenProgress.defaults(0)
		p.creatures = {
			{ id = 1, s = "cat", m = "golden", z = "big", placed = 1, fav = false },
			{ id = 2, s = "bunny", m = "normal", z = "normal", placed = 2, fav = false },
		}
		p.index = { "bunny:normal", "cat:golden", "frog:normal", "pup:normal", "cat:normal" }
		expect(select(2, GardenProgress.dashCoins(p, 20000))).toBe(3630)
		expect(select(2, GardenProgress.dashCoins(GardenProgress.defaults(0), 20000))).toBe(100)
	end)

	it("takes prizes today from 2 to 3 on a win, not eligible again until the next UTC day", function()
		local p = GardenProgress.defaults(0)
		p.dash = { day = 20000, prizes = 2, coins = 0 }
		expect(GardenProgress.dashEligible(p, 20000)).toBe(true)
		local out = GardenProgress.dashPrize(p, 20000)
		expect(out.dash.prizes).toBe(3)
		expect(GardenProgress.dashEligible(out, 20000)).toBe(false)
		expect(GardenProgress.dashEligible(out, 20001)).toBe(true)
	end)

	it("refuses plantPrize at Level 9 and plants at Level 10, ready = now + 3,600", function()
		local p = GardenProgress.defaults(0)
		p.prizeEggs = { moon = 1 }
		p.xp = MetaRules.xpForLevel(9)
		expect(select(2, GardenRules.plantPrize(p, "moon", 5000))).toBe(false)
		p.xp = MetaRules.xpForLevel(10)
		local out, ok = GardenRules.plantPrize(p, "moon", 5000)
		expect(ok).toBe(true)
		expect(out.beds[2].ready).toBe(5000 + 3600)
		expect(out.coins).toBe(p.coins)
		expect(out.stock.w).toBe(p.stock.w)
	end)
end)

describe("DashRules ready and countdown", function()
	it("toggles only on a change, and starts empty", function()
		local r = DashRules.new()
		expect(`{r.phase} {#r.ready} {r.at} {r.goAt} {r.places}`).toBe("idle 0 0 0 0")
		expect(select(2, DashRules.setReady(r, 1, false, 0))).toBe(false)
		local a, ok = DashRules.setReady(r, 1, true, 0)
		expect(ok).toBe(true)
		expect(DashRules.isReady(a, 1)).toBe(true)
		expect(DashRules.isReady(r, 1)).toBe(false)
		expect(select(2, DashRules.setReady(a, 1, true, 0))).toBe(false)
	end)

	it("takes joins during the countdown up to 6, and refuses a seventh", function()
		local r = DashRules.new()
		for id = 1, 6 do
			local ok
			r, ok = DashRules.setReady(r, id, true, 100 + id)
			expect(ok).toBe(true)
		end
		expect(r.at).toBe(118) -- third ready at 103
		expect(select(2, DashRules.setReady(r, 7, true, 110))).toBe(false)
	end)

	it("keeps the countdown when ready stays at 3 or more, and cancels below 3", function()
		local r = DashRules.new()
		for id = 1, 4 do
			r = DashRules.setReady(r, id, true, 100)
		end
		r = DashRules.setReady(r, 1, false, 105)
		expect(r.phase).toBe("countdown")
		expect(r.at).toBe(115)
		r = DashRules.setReady(r, 2, false, 106)
		expect(r.phase).toBe("idle")
		expect(table.concat(r.ready, " ")).toBe("3 4")
		expect(DashRules.status(r).at).toBe(0)
	end)

	it("does nothing when start is called early or with no countdown", function()
		local idle = DashRules.new()
		expect((DashRules.start(idle, 5, {}))).toBe(idle)
		local r = DashRules.new()
		for id = 1, 3 do
			r = DashRules.setReady(r, id, true, 100)
		end
		local early, events = DashRules.start(r, 114.9, { { id = 1, eligible = true } })
		expect(early).toBe(r)
		expect(#events).toBe(0)
	end)

	it("goes back to idle when a ready player has no character and fewer than 3 are left", function()
		local r = DashRules.new()
		for id = 1, 3 do
			r = DashRules.setReady(r, id, true, 100)
		end
		local out, events = DashRules.start(r, 115, { { id = 1, eligible = true }, { id = 3, eligible = true } })
		expect(#events).toBe(0)
		expect(out.phase).toBe("idle")
		expect(out.at).toBe(0)
		expect(table.concat(out.ready, " ")).toBe("1 3") -- the others stay ready
		expect(next(out.racers)).toBeNil()
	end)

	it("starts without a ready player who has no character when 3 are left", function()
		local r = DashRules.new()
		for id = 1, 4 do
			r = DashRules.setReady(r, id, true, 100)
		end
		local entrants = { { id = 1, eligible = true }, { id = 2, eligible = false }, { id = 4, eligible = true } }
		local out, events = DashRules.start(r, 115, entrants)
		expect(table.concat(events[1].ids :: { number }, " ")).toBe("1 2 4")
		expect(DashRules.isRacer(out, 3)).toBe(false)
		expect(out.racers[2].eligible).toBe(false)
		expect(out.racers[1].next).toBe(1)
	end)

	it("starts a countdown from idle in step when enough are ready, and not otherwise", function()
		local r = DashRules.new()
		r.ready = { 1, 2, 3 }
		local out = DashRules.step(r, 50)
		expect(out.phase).toBe("countdown")
		expect(out.at).toBe(65)
		local quiet = DashRules.new()
		quiet.ready = { 1, 2 }
		expect((DashRules.step(quiet, 50))).toBe(quiet)
	end)

	it("reports status with need 3 and only racers not out", function()
		local r = race({ 5, 3, 9 })
		r = DashRules.leave(r, 9, 130)
		r = DashRules.setReady(r, 7, true, 130)
		local s = DashRules.status(r)
		expect(`{s.phase} {s.need} {s.at} {s.goAt}`).toBe("racing 3 240 120")
		expect(table.concat(s.racers, " ")).toBe("3 5")
		expect(table.concat(s.ready, " ")).toBe("7")
	end)
end)

describe("DashRules running rounds", function()
	it("keeps ready through a running round and counts down for it when the round ends", function()
		local r = race({ 1, 2, 3 })
		for id = 4, 6 do
			local ok
			r, ok = DashRules.setReady(r, id, true, 130)
			expect(ok).toBe(true)
		end
		expect(r.phase).toBe("racing") -- a third ready starts nothing until the round ends
		local out, events = DashRules.step(r, 240)
		expect(events[1].reason).toBe("time")
		expect(out.phase).toBe("countdown")
		expect(out.at).toBe(255)
		expect(table.concat(out.ready, " ")).toBe("4 5 6")
		expect(next(out.racers)).toBeNil()
		expect(out.goAt).toBe(0)
	end)

	it("refuses ready for a racer, finished or not, until the round is over", function()
		local r = race({ 1, 2, 3 })
		expect(select(2, DashRules.setReady(r, 1, true, 130))).toBe(false)
		local done = finishAt(r, 1, GO + 30)
		expect(DashRules.isRacer(done, 1)).toBe(true)
		expect(select(2, DashRules.setReady(done, 1, true, 151))).toBe(false)
		local left = DashRules.leave(r, 2, 130)
		expect(select(2, DashRules.setReady(left, 2, true, 130))).toBe(true) -- out, so free to queue
	end)

	it("enforces order: zones out of order do nothing, even the finish", function()
		local r = race({ 1, 2, 3 })
		for cp = 2, 5 do
			local out, events = DashRules.sample(r, 1, CP[cp], GO + 30 * cp)
			expect(#events).toBe(0)
			expect(out.racers[1].next).toBe(1)
			expect(out.racers[1].strikes).toBe(0)
		end
		local one, events = DashRules.sample(r, 1, CP[1], GO + 5)
		expect(kinds(events)).toBe("checkpoint")
		expect(events[1].cp).toBe(1)
		expect(one.racers[1].next).toBe(2)
		local _, none = DashRules.sample(one, 1, CP[3], GO + 15)
		expect(#none).toBe(0)
		local _, again = DashRules.sample(one, 1, CP[1], GO + 6)
		expect(#again).toBe(0) -- a checkpoint counts once
	end)

	it("reaches a checkpoint inside its zone, not outside", function()
		local c = CP[1]
		expect(DashRules.inZone({ x = c.x + 16, y = c.y, z = c.z }, c)).toBe(true)
		expect(DashRules.inZone({ x = c.x + 16.1, y = c.y, z = c.z }, c)).toBe(false)
		expect(DashRules.inZone({ x = c.x, y = c.y + 14, z = c.z }, c)).toBe(true)
		expect(DashRules.inZone({ x = c.x, y = c.y - 14.1, z = c.z }, c)).toBe(false)
	end)

	it("sends a fall back to the right checkpoint with no strike", function()
		local r = race({ 1, 2, 3 })
		local _, atStart = DashRules.sample(r, 1, { x = -100, y = 124.9, z = 300 }, 125)
		expect(kinds(atStart)).toBe("splash")
		expect(atStart[1].cp).toBe(0)
		r = through(r, 1, 1, 2, GO + 1)
		expect(DashRules.respawnCp(r, 1)).toBe(2)
		local fell, events = DashRules.sample(r, 1, { x = 100, y = 120, z = 330 }, 130)
		expect(kinds(events)).toBe("splash")
		expect(events[1].cp).toBe(2)
		expect(fell.racers[1].strikes).toBe(0)
		expect(fell.racers[1].next).toBe(3)
		local _, ledge = DashRules.sample(r, 1, { x = 100, y = 125, z = 330 }, 130)
		expect(#ledge).toBe(0)
	end)

	it("ignores a stale sample inside the settle time: neither a fall nor a strike", function()
		local r = DashRules.sample(race({ 1, 2, 3 }), 1, { x = -100, y = 144, z = 300 }, 130)
		r = DashRules.teleported(r, 1, 131)
		expect(r.racers[1].lastPos).toBeNil()
		expect(r.racers[1].settleUntil).toBe(132)
		local out, events = DashRules.sample(r, 1, { x = 500, y = 100, z = 900 }, 131.8)
		expect(#events).toBe(0)
		expect(out.racers[1].strikes).toBe(0)
		expect(out.racers[1].lastPos).toBeNil()
		local after, none = DashRules.sample(r, 1, { x = 500, y = 144, z = 900 }, 132)
		expect(#none).toBe(0) -- the first sample after a teleport has nothing to compare with
		expect((after.racers[1].lastPos :: any).x).toBe(500)
		local _, fell = DashRules.sample(r, 1, { x = 500, y = 100, z = 900 }, 132)
		expect(kinds(fell)).toBe("splash")
	end)

	it("strikes twice, then puts the racer out on the third; a breach never counts its zone", function()
		local r = DashRules.sample(race({ 1, 2, 3 }), 1, { x = -100, y = 144, z = 300 }, 130)
		for strike = 1, 2 do
			local events
			r, events = DashRules.sample(r, 1, CP[1], 130 + strike * 0.2 - 0.15)
			expect(kinds(events)).toBe("flag")
			expect(r.racers[1].strikes).toBe(strike)
			expect(r.racers[1].next).toBe(1)
		end
		local out, events = DashRules.sample(r, 1, CP[1], 130.45)
		expect(kinds(events)).toBe("out")
		expect(out.racers[1].out).toBe(true)
		expect(DashRules.isRacer(out, 1)).toBe(false)
		local later, none = DashRules.sample(out, 1, CP[1], 200)
		expect(#none).toBe(0)
		expect(later).toBe(out)
	end)

	it("strikes a NaN or infinite position rather than trusting it", function()
		local r = DashRules.sample(race({ 1, 2, 3 }), 1, { x = -100, y = 144, z = 300 }, 130)
		local nan = 0 / 0
		expect(kinds(select(2, DashRules.sample(r, 1, { x = nan, y = 144, z = 300 }, 131)))).toBe("flag")
		expect(kinds(select(2, DashRules.sample(r, 1, { x = math.huge, y = 144, z = 300 }, 131)))).toBe("flag")
	end)

	it("ignores samples outside racing, from strangers and from finishers", function()
		local r = DashRules.new()
		expect((DashRules.sample(r, 1, CP[1], 5))).toBe(r)
		local running = race({ 1, 2, 3 })
		expect((DashRules.sample(running, 99, CP[1], 130))).toBe(running)
		expect((DashRules.teleported(running, 99, 130))).toBe(running)
		local done = finishAt(running, 1, GO + 30)
		local again, none = DashRules.sample(done, 1, CP[5], GO + 31)
		expect(again).toBe(done)
		expect(#none).toBe(0)
		local entrants = { { id = 1, eligible = true }, { id = 2, eligible = true }, { id = 3, eligible = true } }
		local waiting = DashRules.new()
		for id = 1, 3 do
			waiting = DashRules.setReady(waiting, id, true, 100)
		end
		waiting = DashRules.start(waiting, 115, entrants)
		expect(waiting.phase).toBe("starting")
		expect((DashRules.sample(waiting, 1, { x = 0, y = 0, z = 0 }, 118))).toBe(waiting)
	end)
end)

describe("DashRules prizes in a round", function()
	it("gives one egg per round to the first eligible finisher, and places everyone", function()
		local r = race({ 1, 2, 3 })
		local a, b, c
		r, a = finishAt(r, 1, GO + 40)
		r, b = finishAt(r, 2, GO + 42)
		r, c = finishAt(r, 3, GO + 44)
		expect(`{a[1].place} {a[1].egg}`).toBe("1 true")
		expect(`{b[1].place} {b[1].egg}`).toBe("2 false")
		expect(`{c[1].place} {c[1].egg}`).toBe("3 false")
		expect(near(b[1].time :: number, 42)).toBe(true)
		expect(r.winner).toBe(1)
		expect(r.prizeTo).toBe(1)
		expect(r.places).toBe(3)
		local over, events = DashRules.step(r, GO + 44.2)
		expect(over.phase).toBe("idle") -- nobody running
		expect(`{events[1].winner} {events[1].prizeTo} {events[1].reason}`).toBe("1 1 finished")
	end)

	it("never gives a second egg for repeat samples on the finish", function()
		local r, first = finishAt(race({ 1, 2, 3 }), 1, GO + 40)
		expect(first[1].egg).toBe(true)
		for i = 1, 20 do
			local events
			r, events = DashRules.sample(r, 1, CP[5], GO + 40 + i * 0.2)
			expect(#events).toBe(0)
		end
		expect(r.places).toBe(1)
	end)

	it("lets a capped first finisher win and passes the egg to the next eligible", function()
		local r = race({ 1, 2, 3 }, { [1] = true })
		local a, b, c
		r, a = finishAt(r, 1, GO + 40)
		expect(`{a[1].place} {a[1].egg}`).toBe("1 false")
		expect(r.winner).toBe(1)
		expect(r.prizeTo).toBeNil()
		r, b = finishAt(r, 2, GO + 45)
		expect(`{b[1].place} {b[1].egg}`).toBe("2 true")
		r, c = finishAt(r, 3, GO + 46)
		expect(c[1].egg).toBe(false)
		expect(r.at).toBe(GO + 60) -- the grace runs from the first finish, eligible or not
		local _, events = DashRules.step(r, GO + 60)
		expect(`{events[1].winner} {events[1].prizeTo}`).toBe("1 2")
	end)

	it("gives no egg when nobody is eligible", function()
		local r = race({ 1, 2, 3 }, { [1] = true, [2] = true, [3] = true })
		local a, b
		r, a = finishAt(r, 1, GO + 40)
		r, b = finishAt(r, 2, GO + 41)
		expect(a[1].egg).toBe(false)
		expect(b[1].egg).toBe(false)
		local _, events = DashRules.step(r, GO + 60)
		expect(`{events[1].winner} {events[1].prizeTo} {events[1].reason}`).toBe("1 nil finished")
	end)

	it("gives nothing when nobody finishes: over at the limit with reason time", function()
		local r = through(race({ 1, 2, 3 }), 1, 1, 3, GO + 1)
		local before, none = DashRules.step(r, 239.9)
		expect(before.phase).toBe("racing")
		expect(#none).toBe(0)
		local out, events = DashRules.step(r, 240)
		expect(kinds(events)).toBe("over")
		expect(`{events[1].winner} {events[1].prizeTo} {events[1].reason}`).toBe("nil nil time")
		expect(table.concat(events[1].ids :: { number }, " ")).toBe("1 2 3")
		expect(out.phase).toBe("idle")
		expect(next(out.racers)).toBeNil()
	end)

	it("runs 6 players on 6 spots, each placed, with one egg", function()
		local ids = { 11, 12, 13, 14, 15, 16 }
		local r = race(ids)
		local eggs = 0
		for i, id in ids do
			local events
			r, events = finishAt(r, id, GO + 40 + i)
			expect(events[1].place).toBe(i)
			eggs += if events[1].egg then 1 else 0
		end
		expect(eggs).toBe(1)
		local seen: { [number]: boolean } = {}
		for i = 1, 6 do
			local s = DashRules.startSpot(i)
			expect(s.x).toBe(DASH.start.x)
			expect(s.y).toBe(DASH.start.y + 4)
			expect(math.abs(s.z - DASH.start.z) <= 15).toBe(true) -- on the 40-wide deck
			seen[s.z] = true
			if i > 1 then
				expect(s.z - DashRules.startSpot(i - 1).z).toBe(6)
			end
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		expect(count).toBe(6)
	end)
end)

describe("DashRules leaving", function()
	it("removes a ready player in idle and ignores a stranger", function()
		local r = DashRules.setReady(DashRules.new(), 1, true, 0)
		local out, events = DashRules.leave(r, 1, 1)
		expect(#out.ready).toBe(0)
		expect(#events).toBe(0)
		expect((DashRules.leave(r, 99, 1))).toBe(r)
	end)

	it("cancels the countdown below 3 and keeps the others ready", function()
		local r = DashRules.new()
		for id = 1, 3 do
			r = DashRules.setReady(r, id, true, 100)
		end
		local out = DashRules.leave(r, 2, 105)
		expect(out.phase).toBe("idle")
		expect(out.at).toBe(0)
		expect(table.concat(out.ready, " ")).toBe("1 3")
	end)

	it("keeps the countdown when 3 stay", function()
		local r = DashRules.new()
		for id = 1, 4 do
			r = DashRules.setReady(r, id, true, 100)
		end
		local out = DashRules.leave(r, 2, 105)
		expect(out.phase).toBe("countdown")
		expect(out.at).toBe(115)
	end)

	it("takes a racer out in the start hold, and the round goes on", function()
		local r = DashRules.new()
		local entrants = {}
		for id = 1, 3 do
			r = DashRules.setReady(r, id, true, 100)
			table.insert(entrants, { id = id, eligible = true })
		end
		r = DashRules.start(r, 115, entrants)
		local out, events = DashRules.leave(r, 1, 117)
		expect(#events).toBe(0)
		expect(out.phase).toBe("starting")
		expect(DashRules.isRacer(out, 1)).toBe(false)
		out = DashRules.leave(out, 2, 117)
		local empty
		empty, events = DashRules.leave(out, 3, 118)
		expect(kinds(events)).toBe("over")
		expect(events[1].reason).toBe("empty")
		expect(empty.phase).toBe("idle")
	end)

	it("runs on down to 1 racer, who can still win", function()
		local r = race({ 1, 2, 3 })
		r = DashRules.leave(r, 2, 130)
		r = DashRules.leave(r, 3, 131)
		expect(r.phase).toBe("racing")
		local _, still = DashRules.step(r, 132)
		expect(#still).toBe(0)
		local events
		r, events = finishAt(r, 1, GO + 40)
		expect(events[1].egg).toBe(true)
		local _, ended = DashRules.step(r, GO + 40.2)
		expect(`{ended[1].winner} {ended[1].reason}`).toBe("1 finished")
		expect(table.concat(ended[1].ids :: { number }, " ")).toBe("1")
	end)

	it("ends at once with no prize when everyone leaves, keeping the queue", function()
		local r = race({ 1, 2, 3 })
		for id = 4, 6 do
			r = DashRules.setReady(r, id, true, 125)
		end
		r = DashRules.leave(r, 1, 130)
		r = DashRules.leave(r, 2, 130)
		local out, events = DashRules.leave(r, 3, 131)
		expect(kinds(events)).toBe("over")
		expect(`{events[1].winner} {events[1].prizeTo} {events[1].reason}`).toBe("nil nil empty")
		expect(#(events[1].ids :: { number })).toBe(0)
		expect(out.phase).toBe("countdown")
		expect(out.at).toBe(146)
	end)

	it("keeps what a finisher won when they leave, and lets the rest finish", function()
		local r = finishAt(race({ 1, 2, 3 }), 1, GO + 40)
		r = DashRules.leave(r, 1, GO + 41)
		expect(DashRules.isRacer(r, 1)).toBe(false)
		expect(r.winner).toBe(1)
		expect(r.prizeTo).toBe(1)
		expect(r.at).toBe(GO + 60)
		local _, events = finishAt(r, 2, GO + 45)
		expect(events[1].egg).toBe(false)
	end)

	it("ends on the next step when the last runner strikes out, by reason", function()
		local r = race({ 1, 2, 3 })
		r = DashRules.leave(r, 2, 130)
		r = DashRules.leave(r, 3, 130)
		r = DashRules.sample(r, 1, { x = -100, y = 144, z = 300 }, 131)
		for i = 1, 3 do
			r = DashRules.sample(r, 1, { x = 500, y = 144, z = 300 }, 131 + i * 0.1)
		end
		expect(DashRules.isRacer(r, 1)).toBe(false)
		local _, events = DashRules.step(r, 132)
		expect(`{events[1].reason} {#(events[1].ids :: { number })}`).toBe("empty 0")
	end)

	it("ends with the finishers when the last runner leaves", function()
		local r = finishAt(race({ 1, 2, 3 }), 1, GO + 40)
		r = DashRules.leave(r, 2, GO + 41)
		local mid, none = DashRules.leave(r, 3, GO + 41)
		expect(#none).toBe(0)
		local _, events = DashRules.step(mid, GO + 41.2)
		expect(`{events[1].reason} {events[1].winner}`).toBe("finished 1")
	end)
end)

describe("DashRules positions", function()
	it("respawns at the start or the last checkpoint, 4 studs up", function()
		local s = DashRules.respawnPoint(0)
		expect(`{s.x} {s.y} {s.z}`).toBe("-120 144 300")
		local c = DashRules.respawnPoint(3)
		expect(`{c.x} {c.y} {c.z}`).toBe("100 144 400")
		expect(DashRules.respawnCp(DashRules.new(), 1)).toBe(0)
	end)
end)

describe("DashRules obstacles", function()
	local function first(kind: string): GardenConfig.Obstacle
		for _, o in DASH.obstacles do
			if o.kind == kind then
				return o
			end
		end
		error(kind)
	end

	it("turns a sweeper once a period around its hub", function()
		local o = first("sweeper")
		local p = DashRules.pose(o, o.period / 4)
		expect(`{p.x} {p.y} {p.z}`).toBe(`{o.at.x} {o.at.y} {o.at.z}`)
		expect(near(p.angle, math.pi / 2)).toBe(true)
		expect(near(DashRules.pose(o, 0).angle, 0)).toBe(true)
	end)

	it("sends a ball across the alley, bouncing", function()
		local o = first("ball")
		local a = DashRules.pose(o, 0)
		expect(near(a.z, o.at.z)).toBe(true)
		expect(near(a.y, o.at.y + 5 + 8)).toBe(true)
		local b = DashRules.pose(o, o.period / 4)
		expect(near(b.z, o.at.z + 7)).toBe(true)
		expect(near(b.y, o.at.y + 5)).toBe(true)
		expect(b.x).toBe(o.at.x)
	end)

	it("swings a pendulum 50 degrees either side", function()
		local o = first("pendulum")
		local a = DashRules.pose(o, 0)
		expect(near(a.x, o.at.x)).toBe(true)
		expect(near(a.y, o.at.y - o.reach)).toBe(true)
		local b = DashRules.pose(o, o.period / 4)
		local swing = math.rad(50)
		expect(near(b.angle, swing)).toBe(true)
		expect(near(b.x, o.at.x + o.reach * math.sin(swing))).toBe(true)
		expect(near(b.y, o.at.y - o.reach * math.cos(swing))).toBe(true)
		expect(b.z).toBe(o.at.z)
	end)

	it("slides a platform along its axis", function()
		local o = first("platform")
		local b = DashRules.pose(o, o.period / 4)
		expect(near(b.z, o.at.z + o.reach)).toBe(true)
		expect(`{b.x} {b.y}`).toBe(`{o.at.x} {o.at.y}`)
	end)

	it("is the same for a fixed t, and phase is a fraction of a cycle", function()
		local t = 1_800_000_123.4
		for _, o in DASH.obstacles do
			local a, b = DashRules.pose(o, t), DashRules.pose(o, t)
			expect(`{a.x} {a.y} {a.z} {a.angle}`).toBe(`{b.x} {b.y} {b.z} {b.angle}`)
			local shifted = table.clone(o)
			shifted.phase = 0
			local c = DashRules.pose(shifted, 40 + o.phase * o.period)
			local d = DashRules.pose(o, 40)
			expect(near(c.x, d.x) and near(c.y, d.y) and near(c.z, d.z)).toBe(true)
		end
	end)

	it("knocks a root on a sweeper arm along the way the arm turns, both sides of the hub", function()
		local o = first("sweeper")
		local pose = DashRules.pose(o, 0) -- arms along x
		local v = DashRules.knock(o, pose, { x = o.at.x + 10, y = o.at.y + 3, z = o.at.z }) :: DashRules.Vec3
		expect(`{math.abs(v.x) < 1e-9} {v.y} {v.z}`).toBe("true 20 -45")
		-- A point on the arm moves that way as the angle grows, as CFrame.Angles(0, angle, 0) turns it.
		local a = 0.01
		expect(math.cos(a) * 10 < 10 and -math.sin(a) * 10 < 0).toBe(true)
		local w = DashRules.knock(o, pose, { x = o.at.x - 10, y = o.at.y + 3, z = o.at.z }) :: DashRules.Vec3
		expect(w.z).toBe(45)
		expect(DashRules.knock(o, pose, { x = o.at.x + 10, y = o.at.y + 3, z = o.at.z + 2.5 }) ~= nil).toBe(true)
		expect(DashRules.knock(o, pose, { x = o.at.x + 10, y = o.at.y + 3, z = o.at.z + 2.6 })).toBeNil()
		expect(DashRules.knock(o, pose, { x = o.at.x + 21, y = o.at.y + 3, z = o.at.z + 2.6 })).toBeNil()
		expect(DashRules.knock(o, pose, { x = o.at.x + 10, y = o.at.y + 6.1, z = o.at.z })).toBeNil() -- jumped it
		expect(DashRules.knock(o, pose, { x = o.at.x + 10, y = o.at.y - 0.1, z = o.at.z })).toBeNil()
	end)

	it("knocks a root away from a ball or bob, within size + 2", function()
		for _, kind in { "ball", "pendulum" } do
			local o = first(kind)
			local pose = DashRules.pose(o, 0)
			local reach = o.size + 2
			local v = DashRules.knock(o, pose, { x = pose.x + reach, y = pose.y, z = pose.z }) :: DashRules.Vec3
			expect(`{v.x} {v.y} {v.z}`).toBe(`{o.knock} 20 0`)
			expect(DashRules.knock(o, pose, { x = pose.x + reach + 0.1, y = pose.y, z = pose.z })).toBeNil()
			expect(DashRules.knock(o, pose, { x = pose.x, y = pose.y + reach + 0.1, z = pose.z })).toBeNil()
			local below = DashRules.knock(o, pose, { x = pose.x, y = pose.y - 1, z = pose.z }) :: DashRules.Vec3
			expect(`{below.x} {below.y} {below.z}`).toBe(`{o.knock} 20 0`) -- no direction: no NaN
		end
	end)

	it("never knocks from a platform, and never above knockMax over a sweep of times and positions", function()
		local hits = 0
		for _, o in DASH.obstacles do
			for step = 0, 23 do
				local t = 1000 + step * o.period / 24
				local pose = DashRules.pose(o, t)
				for dx = -24, 24, 2 do
					for dz = -24, 24, 2 do
						for dy = -8, 8, 2 do
							local v = DashRules.knock(o, pose, { x = pose.x + dx, y = pose.y + dy, z = pose.z + dz })
							if o.kind == "platform" then
								expect(v).toBeNil()
							elseif v then
								hits += 1
								local size = math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2)
								expect(size == size and size <= DASH.knockMax + 1e-9).toBe(true)
							end
						end
					end
				end
			end
		end
		expect(hits > 1000).toBe(true)
	end)

	it("clamps a stronger knock to knockMax", function()
		local o = table.clone(first("ball"))
		o.knock = 500
		local pose = DashRules.pose(o, 0)
		local v = DashRules.knock(o, pose, { x = pose.x + 1, y = pose.y, z = pose.z }) :: DashRules.Vec3
		expect(near(math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2), DASH.knockMax)).toBe(true)
	end)
end)

describe("DashRules purity", function()
	local function frozen(value: any): any
		if type(value) == "table" and not table.isfrozen(value) then
			table.freeze(value)
			for _, child in value do
				frozen(child)
			end
		end
		return value
	end

	it("never mutates a round, its entrants or a position (they are frozen here), over a whole round", function()
		local r: Round = frozen(DashRules.new())
		local function ready(id: number, t: number)
			r = frozen((DashRules.setReady(r, id, true, t)))
		end
		ready(1, 100)
		ready(2, 100)
		ready(3, 100)
		ready(4, 101)
		r = frozen((DashRules.setReady(r, 4, false, 102)))
		r = frozen((DashRules.step(r, 110)))
		r = frozen((DashRules.leave(r, 99, 110)))
		local entrants =
			frozen({ { id = 1, eligible = true }, { id = 2, eligible = true }, { id = 3, eligible = false } })
		r = frozen((DashRules.start(r, 115, entrants)))
		r = frozen((DashRules.teleported(r, 1, 115)))
		r = frozen((DashRules.step(r, 120)))
		ready(9, 121)
		r = frozen((DashRules.sample(r, 1, frozen({ x = -100, y = 144, z = 300 }), 122)))
		r = frozen((DashRules.sample(r, 1, frozen({ x = -100, y = 120, z = 300 }), 123)))
		r = frozen((DashRules.sample(r, 2, frozen({ x = -100, y = 144, z = 300 }), 124)))
		r = frozen((DashRules.sample(r, 2, frozen({ x = 500, y = 144, z = 300 }), 124.2)))
		r = frozen((DashRules.leave(r, 3, 125)))
		r = frozen(through(r, 1, 1, 4, 130))
		r = frozen((DashRules.sample(r, 1, frozen(table.clone(CP[5])), 160)))
		r = frozen((DashRules.leave(r, 1, 161)))
		r = frozen((DashRules.leave(r, 2, 162)))
		expect(r.phase).toBe("idle")
		DashRules.status(r)
		expect(DashRules.respawnCp(r, 1)).toBe(0)
	end)

	it("holds its invariants through hundreds of rounds of random requests", function()
		local rng = Rng.seed(31337)
		local function int(lo: number, hi: number): number
			local v
			v, rng = Rng.int(rng, lo, hi)
			return v
		end
		local r: Round = DashRules.new()
		local t = 1000
		local eggs = 0
		local overs = 0
		local won = 0
		for _ = 1, 200_000 do
			t += 0.2
			local id = int(1, 8)
			local action = int(1, 10)
			local events: { Event } = {}
			if action <= 2 then
				r = DashRules.setReady(r, id, int(1, 2) == 1, t)
			elseif action == 3 then
				r, events = DashRules.leave(r, id, t)
			elseif action == 4 then
				r = DashRules.teleported(r, id, t)
			elseif action <= 7 then
				local racer = r.racers[id]
				local spot = if racer and int(1, 4) > 1 then CP[racer.next] else CP[int(1, 5)]
				local y = if int(1, 10) == 1 then 100 else 144
				r, events = DashRules.sample(r, id, { x = spot.x + int(-3, 3), y = y, z = spot.z }, t)
			else
				if r.phase == "countdown" and t >= r.at then
					local entrants = {}
					for _, ready in r.ready do
						if int(1, 8) > 1 then
							table.insert(entrants, { id = ready, eligible = int(1, 3) > 1 })
						end
					end
					r, events = DashRules.start(r, t, entrants)
				else
					r, events = DashRules.step(r, t)
				end
			end
			for _, e in events do
				eggs += if e.egg then 1 else 0
				won += if e.egg then 1 else 0
				if e.kind == "over" then
					overs += 1
					expect(eggs <= 1).toBe(true)
					eggs = 0
				end
			end
			expect(eggs <= 1).toBe(true)
			expect(#r.ready <= DASH.maxPlayers).toBe(true)
			local seen: { [number]: boolean } = {}
			for _, ready in r.ready do
				expect(seen[ready]).toBeNil()
				seen[ready] = true
			end
			expect((r.phase == "idle") == (r.at == 0)).toBe(true)
			if r.phase == "countdown" then
				expect(#r.ready >= DASH.minPlayers).toBe(true)
			end
			if r.phase == "idle" or r.phase == "countdown" then
				expect(next(r.racers)).toBeNil()
				expect(r.winner).toBeNil()
			end
			if r.phase == "racing" then
				expect(r.at <= r.goAt + DASH.limit).toBe(true)
			end
			if r.prizeTo then
				expect(r.racers[r.prizeTo].eligible and r.racers[r.prizeTo].finished ~= nil).toBe(true)
			end
		end
		expect(overs >= 100).toBe(true)
		expect(won >= 10).toBe(true)
	end)
end)
