--!strict
-- TrainRules (architecture lantern 3.7, 8; GDD C, D, E, I, J, K, P; decision 0018 section 2).
-- A small fake server drives the run at 10 Hz: it seats and stands players as the events say,
-- reports depths and the load box, and (when asked) aims four perfect beams at the night.
local T = require("./framework")
local LanternConfig = require("../src/shared/LanternConfig")
local MetaRules = require("../src/shared/MetaRules")
local Rng = require("../src/shared/Rng")
local TrainRules = require("../src/shared/TrainRules")
local WispRules = require("../src/shared/WispRules")

local describe, it, expect = T.describe, T.it, T.expect

type Run = TrainRules.Run
type Event = TrainRules.Event

local A, B, C = 11, 22, 33
local LANTERNS = { { x = 0, y = 6, z = -11 }, { x = 0, y = 7, z = 68 } }
local TURRET = { x = 0, y = 10, z = 39 }

type World = {
	run: Run,
	k: number,
	start: number,
	dt: number,
	now: number,
	seats: { [number]: LanternConfig.SeatKind? },
	depth: { [number]: number? },
	loadBox: { [number]: boolean },
	aim: boolean, -- four perfect beams at night
	share: number?, -- or one beam on every share-th wisp only (a lone lamp that misses the rest)
	sitBack: boolean, -- players sit straight back down when stood up
	fuel: boolean, -- the bunker is full at every stop (the crew loads coal sacks)
	log: { { t: number, e: Event } },
	last: { Event },
}

local function world(members: { number }, seed: number?): World
	local run = TrainRules.new(seed or 42, 0)
	local seats = {}
	for _, userId in members do
		run = TrainRules.join(run, userId, 0)
		seats[userId] = run.crew[userId].seat
	end
	return {
		run = run,
		k = 0,
		start = 0,
		dt = 0.1,
		now = 0,
		seats = seats,
		depth = {},
		loadBox = {},
		aim = false,
		sitBack = false,
		fuel = false,
		log = {},
		last = {},
	}
end

local function unit(x: number, y: number, z: number): LanternConfig.Vec3
	local l = math.sqrt(x * x + y * y + z * z)
	return { x = x / l, y = y / l, z = z / l }
end

local function beams(w: World): { WispRules.Beam }
	local out = {}
	local night = w.run.night
	if night and w.share then
		local best = nil
		for id, wisp in night.wisps do
			if wisp.born <= w.now and id % w.share == 0 and (best == nil or id < best) then
				best = id
			end
		end
		if best then
			local p = WispRules.pos(night.wisps[best], w.now)
			table.insert(out, { origin = TURRET, dir = unit(p.x - TURRET.x, p.y - TURRET.y, p.z - TURRET.z) })
		end
		return out
	end
	if not (w.aim and night) then
		return out
	end
	local targets = {}
	local l = night.lampeater
	if l and l.gone == nil and w.now >= l.born then
		local p = WispRules.lampeaterPos(l, w.now)
		table.insert(targets, p)
		table.insert(targets, p)
	end
	local ids = {}
	for id, wisp in night.wisps do
		if wisp.born <= w.now then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		table.insert(targets, WispRules.pos(night.wisps[id], w.now))
	end
	for i = 1, math.min(4, #targets) do
		local p = targets[i]
		table.insert(out, { origin = TURRET, dir = unit(p.x - TURRET.x, p.y - TURRET.y, p.z - TURRET.z) })
	end
	return out
end

local function step(w: World)
	if w.fuel and w.run.phase == "stop" then
		w.run.coal = LanternConfig.BUNKER[w.run.levels.bunker]
	end
	local events
	w.run, events = TrainRules.tick(w.run, {
		now = w.now,
		dt = w.dt,
		seats = table.clone(w.seats),
		depth = table.clone(w.depth),
		loadBox = table.clone(w.loadBox),
		beams = beams(w),
		lanterns = LANTERNS,
	})
	w.last = events
	for _, e in events do
		table.insert(w.log, { t = w.now, e = e })
		local userId = e.userId :: number
		if e.kind == "seat" or e.kind == "back" then
			w.seats[userId] = e.payload
		elseif e.kind == "unseat" then
			w.seats[userId] = nil
		end
	end
	if w.sitBack and w.run.phase ~= "ended" then
		for userId, m in w.run.crew do
			if w.seats[userId] == nil and (m.limboUntil or 0) <= 0 then
				w.seats[userId] = m.lastSeat or "passenger"
			end
		end
	end
	w.k += 1
	w.now = w.start + w.k * w.dt
end

-- Steps until an event of `kind` (and `pred`) happens; returns its tick time.
local function untilEvent(w: World, kind: string, limit: number?, pred: ((Event) -> boolean)?): number
	local stop = w.now + (limit or 4000)
	while w.now < stop do
		local t = w.now
		step(w)
		for _, e in w.last do
			if e.kind == kind and (pred == nil or pred(e)) then
				return t
			end
		end
	end
	error(`no {kind} event within {limit or 4000} s`)
end

local function untilTime(w: World, t: number)
	while w.now < t - 1e-9 do
		step(w)
	end
end

local function count(w: World, kind: string, from: number?, to: number?): number
	local n = 0
	for _, x in w.log do
		if x.e.kind == kind and x.t >= (from or -math.huge) and x.t <= (to or math.huge) then
			n += 1
		end
	end
	return n
end

local function near(a: number, b: number, eps: number): boolean
	return math.abs(a - b) <= eps
end

local function critterOn22(run: Run): number
	for id, item in (run.loot :: any).items do
		if item.kind == "critter" and item.pos.z == 22 then
			return id
		end
	end
	error("no crate on the 22-stud site")
end

describe("TrainRules: the hub", function()
	it("leaves 3 s after everyone is seated (PLAY seats a lone player in the cab)", function()
		local w = world({ A })
		expect(w.run.crew[A].seat).toBe("stoker")
		expect(untilEvent(w, "depart")).toBe(3)
		expect(`{w.run.phase} {w.run.target} {w.run.coal} {w.run.lantern}`).toBe("ride 700 80 100")
	end)

	it("leaves 20 s after the first sits, seating the rest with seat events", function()
		local w = world({ A, B })
		expect(w.run.crew[B].seat).toBe("turret")
		w.seats[B] = nil -- B never sits
		local t = untilEvent(w, "depart")
		expect(t).toBe(20)
		local seated = false
		for _, e in w.last do
			if e.kind == "seat" and e.userId == B then
				seated = true
			end
		end
		expect(seated).toBe(true)
		expect(w.seats[B] ~= nil).toBe(true)
	end)

	it("takes the weekly vote at departure and uses the week's seed", function()
		local w = world({ A, B })
		w.start, w.now = 1_762_400_000, 1_762_400_000 -- a Thursday in November 2025
		local ok
		w.run, ok = TrainRules.vote(w.run, A, "weekly")
		expect(ok).toBe(true)
		w.run = TrainRules.vote(w.run, B, "weekly")
		expect(select(3, TrainRules.vote(w.run, A, "lake"))).toBe("payload")
		untilEvent(w, "depart")
		local week = MetaRules.weekOf(MetaRules.dayOf(1_762_400_000))
		expect(`{w.run.weekly} {w.run.seed == Rng.seed(week, 6006)} {next(w.run.votes)}`).toBe("true true nil")
	end)
end)

describe("TrainRules: rides and stops", function()
	it("brakes to exactly 700 studs: 40 s at Boiler I, 36 at II, 33 at III, building the stop 200 studs out", function()
		for boiler, want in { 40.0, 36.18, 33.42 } do
			local w = world({ A })
			local left = untilEvent(w, "depart")
			w.run.levels.boiler = boiler
			local approach = untilEvent(w, "approach")
			expect(w.run.loot ~= nil and w.run.d >= 500 and w.run.d < 503).toBe(true)
			expect(approach < left + want).toBe(true)
			local t = untilEvent(w, "arrive")
			expect(`{boiler} {near(t - left, want, 0.1)} {w.run.d}`).toBe(`{boiler} true 700`)
		end
	end)

	it("stands everyone up on arrival, rings the bell at 70 s and runs the fog 160 to 0 in 13.1 s", function()
		local w = world({ A, B })
		local arrived = untilEvent(w, "arrive")
		local stood = 0
		for _, e in w.last do
			stood += if e.kind == "unseat" then 1 else 0
		end
		expect(`{stood} {w.seats[A]} {w.seats[B]} {TrainRules.fogFront(w.run, arrived + 69)}`).toBe("2 nil nil nil")
		local bell = untilEvent(w, "bell")
		expect(near(bell - arrived, 70, 1e-6)).toBe(true)
		expect(TrainRules.fogFront(w.run, bell)).toBe(160)
		expect(near(TrainRules.FOG_TIME, 13.125, 1e-9)).toBe(true)
		expect(TrainRules.fogFront(w.run, bell + 13.12) > 0).toBe(true)
		expect(TrainRules.fogFront(w.run, bell + 13.125)).toBe(0)
		expect(TrainRules.fogFront(w.run, bell + 10)).toBe(50) -- 6 to 16 studs/s over 10 s covers 110
	end)

	it("needs 10 s after arrival and 3 s with everyone seated to leave early", function()
		local w = world({ A })
		local arrived = untilEvent(w, "arrive")
		w.seats[A] = "stoker" -- sits straight back down
		expect(near(untilEvent(w, "depart") - arrived, 10, 1e-6)).toBe(true)
		local w2 = world({ A })
		local arrived2 = untilEvent(w2, "arrive")
		untilTime(w2, arrived2 + 20)
		w2.seats[A] = "passenger"
		expect(near(untilEvent(w2, "depart") - arrived2, 23, 1e-6)).toBe(true)
	end)

	it("leaves when the fog reaches the platform, seating whoever still stands", function()
		local w = world({ A, B })
		local arrived = untilEvent(w, "arrive")
		w.seats[A] = "stoker"
		local left = untilEvent(w, "depart")
		expect(near(left - arrived, 70 + 13.125, 0.1)).toBe(true)
		local seatB, stopLeft = false, 0
		for _, e in w.last do
			seatB = seatB or (e.kind == "seat" and e.userId == B)
			stopLeft += if e.kind == "stopLeft" then 1 else 0
		end
		expect(`{seatB} {stopLeft} {w.run.phase} {w.run.stop} {w.run.loot}`).toBe("true 2 ride 2 nil")
	end)

	it("catches a member deeper than the fog: the load drops, 10 s in the fog, back seated, no stop XP", function()
		local w = world({ A, B }) -- B stays on the platform, so the train waits for the fog
		untilEvent(w, "arrive")
		local crate = critterOn22(w.run)
		local ok
		w.run, ok = TrainRules.pick(w.run, A, crate)
		expect(ok).toBe(true)
		w.depth[A] = 150 -- greedy: still at the far end with the crate when the bell rings
		local caught = untilEvent(w, "caught")
		local front = TrainRules.fogFront(w.run, caught) :: number
		expect(front < 150 and front > 140).toBe(true)
		local loot = w.run.loot :: any
		expect(`{loot.items[crate].state} {loot.items[crate].pos.z} {w.run.carries[A]}`).toBe("free 150 nil")
		w.depth[A] = nil -- hidden under the platform
		expect(select(3, TrainRules.pick(w.run, A, 1))).toBe("refused") -- nothing to do from the fog
		local back = untilEvent(w, "back")
		expect(near(back - caught, 10, 1e-6)).toBe(true)
		expect(w.seats[A] ~= nil).toBe(true)
		local stopLeft = {}
		untilEvent(w, "depart")
		for _, e in w.last do
			if e.kind == "stopLeft" then
				table.insert(stopLeft, e.userId)
			end
		end
		expect(table.concat(stopLeft, " ")).toBe(tostring(B))
		-- the crate went back to its stop: never loaded, never counted, and the run lost nothing earned
		expect(`{count(w, "load")} {w.run.critters} {w.run.crew[A].limboUntil}`).toBe("0 0 nil")
	end)

	it("does not hold the train for a member in the fog, who comes back during the ride", function()
		local w = world({ A, B })
		untilEvent(w, "arrive")
		w.seats[B] = "turret"
		local bell = untilEvent(w, "bell")
		untilTime(w, bell + 8)
		w.depth[A] = 159
		local caught = untilEvent(w, "caught")
		w.depth[A] = nil
		local left = untilEvent(w, "depart")
		expect(left - caught < 10).toBe(true) -- the early departure did not wait for A
		expect(w.run.phase).toBe("ride")
		local back = untilEvent(w, "back")
		expect(`{near(back - caught, 10, 1e-6)} {w.run.phase} {w.seats[A] ~= nil}`).toBe("true ride true")
	end)

	it("pays nothing for a crate dropped, picked by another and loaded: only the loader's load event", function()
		local w = world({ A, B })
		untilEvent(w, "arrive")
		local crate = critterOn22(w.run)
		w.run = TrainRules.pick(w.run, A, crate)
		local ok
		w.run, ok = TrainRules.drop(w.run, A, { x = 1, y = 0, z = 15 })
		expect(ok).toBe(true)
		expect(select(3, TrainRules.drop(w.run, A, { x = 0, y = 0, z = 0 }))).toBe("refused") -- nothing carried
		w.run = TrainRules.pick(w.run, B, crate)
		w.run = TrainRules.help(w.run, A, crate)
		expect((w.run.loot :: any).items[crate].helper).toBe(A)
		w.loadBox[A] = true -- the helper in the box loads nothing
		step(w)
		expect(count(w, "load")).toBe(0)
		w.loadBox[B] = true
		local t = untilEvent(w, "load")
		local load = w.last[#w.last]
		for _, e in w.last do
			if e.kind == "load" then
				load = e
			end
		end
		expect(`{load.userId} {#(load.items :: any)} {(load.items :: any)[1].kind} {load.n} {w.run.critters}`).toBe(
			`{B} 1 critter 2 1`
		)
		expect(t >= 0).toBe(true)
	end)

	it(
		"loads coal into the bunker to its cap, Parts to the pool and oil to the store (a full store pours +8)",
		function()
			local w = world({ A })
			untilEvent(w, "arrive")
			local loot = w.run.loot :: any
			local kinds = {}
			for id, item in loot.items do
				kinds[item.kind] = kinds[item.kind] or {}
				table.insert(kinds[item.kind], id)
			end
			table.sort(kinds.coal)
			w.run.coal = 77
			w.run.oil = 6
			w.run.lantern = 50
			for _, id in { kinds.coal[1], kinds.coal[2], kinds.oil[1] } do
				w.run = TrainRules.pick(w.run, A, id)
			end
			w.loadBox[A] = true
			step(w)
			-- the first sack fills the bunker to 80, the second stays carried (full bunker), the oil pours
			expect(`{w.run.coal} {w.run.oil} {w.run.lantern} {#w.run.carries[A].small}`).toBe("80 6 58 1")
			expect(count(w, "load")).toBe(1)
		end
	)
end)

describe("TrainRules: the seated rule and joining", function()
	it("keeps every member seated or in the fog after each moving tick, seating a stood member at once", function()
		local w = world({ A, B, C })
		w.sitBack, w.aim, w.fuel = true, true, true
		local ticks, jumps = 0, 0
		while w.run.phase ~= "depot" and w.now < 1500 do
			local moving = w.run.phase == "ride" or w.run.phase == "night"
			if moving and w.k % 7 == 0 then
				w.seats[C] = nil -- C jumps off (or presses Sit off) on a moving train
				jumps += 1
			end
			local before = w.seats[C]
			step(w)
			if w.run.phase == "ride" or w.run.phase == "night" then
				ticks += 1
				for userId, m in w.run.crew do
					expect(m.seat ~= nil or (m.limboUntil or 0) > w.now - w.dt).toBe(true)
					if userId == C and before == nil then
						local seated = false
						for _, e in w.last do
							seated = seated or (e.kind == "seat" and e.userId == C)
						end
						expect(seated).toBe(true)
					end
				end
			end
		end
		expect(w.run.phase).toBe("depot")
		expect(ticks > 1000 and jumps > 100).toBe(true)
	end)

	it("places a joining player by phase (GDD I4) and refuses a seventh", function()
		local run = TrainRules.new(1, 0)
		local where
		run, where = TrainRules.join(run, A, 0)
		expect(`{where} {run.crew[A].seat}`).toBe("seat stoker")
		run, where = TrainRules.join(run, B, 0)
		expect(`{where} {run.crew[B].seat}`).toBe("seat turret")
		local same
		same, where = TrainRules.join(run, A, 5)
		expect(`{same == run} {where}`).toBe("true seat")
		local cases = {
			ride = "seat passenger",
			night = "seat turret",
			stop = "platform nil",
			depot = "depot nil",
			ended = "hub nil",
		}
		for phase, want in cases do
			local r = table.clone(run)
			r.phase = phase :: any
			local out, placed = TrainRules.join(r, C, 10)
			expect(`{phase} {placed} {out.crew[C].seat}`).toBe(`{phase} {want}`)
		end
		for userId = 1, 4 do
			run = TrainRules.join(run, userId, 0)
		end
		expect(#run.order).toBe(6)
		local full, placed = TrainRules.join(run, 99, 0)
		expect(`{full == run} {placed} {full.crew[99]}`).toBe("true hub nil")
		expect(TrainRules.conductor(run)).toBe(A)
	end)

	it("drops a leaver's load and vote, and ends the run 'empty' when the last one leaves", function()
		local w = world({ A, B })
		untilEvent(w, "arrive")
		local crate = critterOn22(w.run)
		w.run = TrainRules.pick(w.run, A, crate)
		local run, events = TrainRules.leave(w.run, A, { x = 3, y = 0, z = 20 })
		local item = (run.loot :: any).items[crate]
		expect(`{item.state} {item.pos.x} {item.pos.z} {run.crew[A]} {#events} {TrainRules.conductor(run)}`).toBe(
			`free 3 20 nil 0 {B}`
		)
		local last
		last, events = TrainRules.leave(run, B, nil)
		expect(`{last.phase} {last.ended} {events[#events].kind} {events[#events].reason}`).toBe(
			"ended empty end empty"
		)
		local fresh, next = TrainRules.tick(
			last,
			{ now = 200, dt = 0.1, seats = {}, depth = {}, loadBox = {}, beams = {}, lanterns = {} }
		)
		expect(`{fresh.phase} {#fresh.order} {next[1].kind}`).toBe("hub 0 hub")
		local hub = TrainRules.new(1, 0)
		hub = TrainRules.join(hub, A, 0)
		local empty = TrainRules.leave(hub, A)
		expect(`{empty.phase} {#empty.order}`).toBe("hub 0") -- an empty hub just waits
	end)

	it("counts members active in the last 180 s (at least 1 while anyone is aboard)", function()
		local run = TrainRules.new(1, 0)
		run = TrainRules.join(run, A, 0)
		run = TrainRules.join(run, B, 0)
		expect(TrainRules.activeCount(run, 180)).toBe(2)
		expect(TrainRules.activeCount(run, 181)).toBe(1)
		run = TrainRules.touch(run, B, 100)
		expect(TrainRules.activeCount(run, 250)).toBe(1)
		expect(TrainRules.activeCount(run, 300)).toBe(1)
		expect(TrainRules.activeCount(TrainRules.new(1, 0), 0)).toBe(0)
	end)
end)

describe("TrainRules: nights, Depot and run ends", function()
	it("runs the night in 3,600 / v + v / 4 s with 7 waves at Boiler I and 6 at II and III", function()
		for boiler, waves in { 7, 6, 6 } do
			local w = world({ A })
			w.sitBack, w.aim = true, true
			untilEvent(w, "depart")
			w.run.levels.boiler, w.run.levels.bunker, w.run.coal = boiler, 3, 120
			local night = untilEvent(w, "night")
			local depot = untilEvent(w, "depot")
			local spawns = 0
			for _, x in w.log do
				if x.e.kind == "wisp" and x.e.payload.kind == "spawn" then
					spawns += 1
				end
			end
			local v = LanternConfig.SPEED[boiler]
			expect(`{boiler} {near(depot - night, 3600 / v + v / 4, 0.1)} {spawns}`).toBe(`{boiler} true {waves}`)
		end
	end)

	it("burns 95 coal a leg: 35 on the rides and 60 at night", function()
		local w = world({ A })
		w.sitBack, w.aim = true, true
		untilEvent(w, "depart")
		w.run.levels.bunker, w.run.coal = 3, 120
		untilEvent(w, "night")
		expect(near(w.run.coal, 120 - 35, 1e-6)).toBe(true)
		untilEvent(w, "depot")
		expect(near(w.run.coal, 25, 1e-6)).toBe(true)
		expect(near(TrainRules.coalNeed(TrainRules.new(1, 0)), 95, 1e-9)).toBe(true)
	end)

	it("runs dry 2,700 studs into the first night, coasts to a halt and ends 'coal' with every load kept", function()
		local w = world({ A })
		w.sitBack, w.aim = true, true
		untilEvent(w, "arrive")
		w.run = TrainRules.pick(w.run, A, critterOn22(w.run))
		w.loadBox[A] = true
		untilEvent(w, "load")
		w.loadBox[A] = false
		local dry = -1
		while w.run.phase ~= "ended" and w.now < 1000 do
			step(w)
			if dry < 0 and w.run.coal <= 0 then
				dry = w.run.d
			end
		end
		local finish = w.log[#w.log].e
		for _, x in w.log do
			if x.e.kind == "end" then
				finish = x.e
			end
		end
		expect(`{near(dry, 4800, 2.5)} {near(w.run.d, 4900, 3)} {finish.reason}`).toBe("true true coal")
		expect(`{finish.payload.critters} {finish.payload.parts} {count(w, "load")}`).toBe("1 0 1")
		local hub = untilEvent(w, "hub")
		expect(`{w.run.phase} {#w.run.order} {w.run.coal} {w.run.critters}`).toBe("hub 1 80 0")
		expect(hub >= 0).toBe(true)
	end)

	it("auto-pours +8 every 3 s under 25, and ends 'lantern' at 0", function()
		local w = world({ A })
		w.sitBack = true -- nobody aims: the wisps get through
		untilEvent(w, "night")
		w.run.oil, w.run.coal = 2, 200 -- coal to spare: the lantern ends this night, not the bunker
		local pours = {}
		local oil = 2
		while w.run.phase == "night" do
			step(w)
			if w.run.oil < oil then
				oil = w.run.oil
				table.insert(pours, w.now - w.dt)
			end
		end
		expect(`{#pours} {w.run.ended} {w.run.lantern}`).toBe("2 lantern 0")
		expect(pours[2] - pours[1] >= 3 - 1e-6).toBe(true)
	end)

	it(
		"solo night 1 (LANTERN-015): a lamp puffing one wisp in four reaches the Depot; an idle lamp does not",
		function()
			local function night(share: number?): string
				local w = world({ A })
				w.sitBack, w.fuel, w.share = true, true, share
				untilEvent(w, "night")
				w.run.oil = 0 -- no oil: the lantern alone
				local low = 100
				while w.run.phase == "night" do
					step(w)
					low = math.min(low, w.run.lantern)
				end
				return `{w.run.phase} {math.floor(low)}`
			end
			-- 7 waves of 4 wisps at 4.5: 28 wisps, 7 puffed, 21 through (94.5) leaves 5.5
			expect(night(4)).toBe("depot 5")
			expect(night(nil)).toBe("ended 0")
		end
	)

	it(
		"pays the Depot (+40 lantern), stands everyone up, leaves at 90 s with everyone seated, takes the branch vote",
		function()
			local w = world({ A, B, C })
			w.sitBack, w.aim, w.fuel = true, true, true
			untilEvent(w, "night")
			w.run.lantern = 30
			local arrived = untilEvent(w, "depot")
			local stood = 0
			for _, e in w.last do
				stood += if e.kind == "unseat" then 1 else 0
			end
			expect(`{stood} {w.run.lantern >= 70} {w.run.phase}`).toBe("3 true depot")
			w.sitBack = false
			for userId in w.run.crew do
				w.seats[userId] = nil
			end
			w.run = TrainRules.vote(w.run, A, "lake")
			w.run = TrainRules.vote(w.run, B, "lake")
			w.run = TrainRules.vote(w.run, C, "forest")
			expect(select(3, TrainRules.vote(w.run, A, "weekly"))).toBe("payload")
			w.run.parts = 40
			local ok
			w.run, ok = TrainRules.buy(w.run, B, "boiler")
			expect(`{ok} {w.run.parts} {w.run.levels.boiler}`).toBe("true 10 2")
			local left = untilEvent(w, "depart")
			expect(near(left - arrived, 90, 1e-6)).toBe(true)
			expect(`{w.run.leg} {w.run.line} {w.run.track} {w.run.d} {w.run.stop}`).toBe("2 lake lake 0 1")
			for _, userId in { A, B, C } do
				expect(w.seats[userId] ~= nil).toBe(true)
			end
			expect(select(3, TrainRules.buy(w.run, A, "lamps"))).toBe("phase")
		end
	)

	it(
		"runs leg 3 on the Dawn track to 5,700 and ends 'dawn' with the Lampeater fed and the distance capped",
		function()
			local w = world({ A })
			w.sitBack, w.aim, w.fuel = true, true, true
			local dawnAt = untilEvent(w, "dawn", 3000)
			local dawn, finish
			for _, x in w.log do
				if x.e.kind == "dawn" then
					dawn = x.e
				elseif x.e.kind == "end" then
					finish = x.e
				end
			end
			expect(`{w.run.track} {w.run.leg} {w.run.ended} {dawn.payload.fed} {finish.payload.dist}`).toBe(
				"forestDawn 3 dawn true 17100"
			)
			expect(`{count(w, "depot")} {count(w, "fed")} {count(w, "approach")}`).toBe("2 1 9")
			-- The fastest run: the hub's 3 s, then three legs of three 40 s rides, three 10 s stops and a
			-- 185 s night, and two 10 s Depots (17.1 minutes). GDD P's 25 to 30 minutes add scavenging.
			expect(near(dawnAt, 3 + 3 * (3 * 40 + 3 * 10 + 185) + 2 * 10, 0.5)).toBe(true)
		end
	)
end)

describe("TrainRules: requests", function()
	it("stokes for +25% over 6 s at 2 coal, from the Stoker seat, while moving, every 6 s", function()
		local w = world({ A, B })
		expect(select(3, TrainRules.stoke(w.run, A, 0))).toBe("phase")
		untilEvent(w, "depart")
		untilTime(w, 10)
		local coal = w.run.coal
		expect(select(3, TrainRules.stoke(w.run, B, w.now))).toBe("seat")
		local ok
		w.run, ok = TrainRules.stoke(w.run, A, w.now)
		expect(`{ok} {w.run.coal == coal - 2} {w.run.stokeUntil}`).toBe(`true true {w.now + 6}`)
		expect(select(3, TrainRules.stoke(w.run, A, w.now + 5.9))).toBe("cooldown")
		untilTime(w, 13)
		expect(near(w.run.speed, 25, 1e-6)).toBe(true)
		untilTime(w, 20)
		expect(near(w.run.speed, 20, 1e-6)).toBe(true)
		local dry = table.clone(w.run)
		dry.coal = 1.5
		expect(select(3, TrainRules.stoke(dry, A, w.now))).toBe("coal")
		expect(select(3, TrainRules.stoke(w.run, 99, w.now))).toBe("refused")
	end)

	it("mends +12 from one can, Mender seat only, lantern 88 or less, every 3 s", function()
		local run = TrainRules.new(1, 0)
		run = TrainRules.join(run, A, 0)
		run.crew[A].seat = "mender"
		expect(select(3, TrainRules.mend(run, A, 0))).toBe("oil")
		run.oil = 2
		expect(select(3, TrainRules.mend(run, A, 0))).toBe("full")
		run.lantern = 80
		local ok
		run, ok = TrainRules.mend(run, A, 0)
		expect(`{ok} {run.lantern} {run.oil}`).toBe("true 92 1")
		run.lantern = 50
		expect(select(3, TrainRules.mend(run, A, 2.9))).toBe("cooldown")
		run = TrainRules.mend(run, A, 3)
		expect(`{run.lantern} {run.oil}`).toBe("62 0")
		run.crew[A].seat = "stoker"
		expect(select(3, TrainRules.mend(run, A, 10))).toBe("seat")
	end)

	it("refuses SIT to a carrier, who walks the load to the train; a helper may sit (QA M1)", function()
		local w = world({ A, B })
		untilEvent(w, "arrive")
		local crate = critterOn22(w.run)
		w.run = TrainRules.pick(w.run, A, crate)
		w.depth[A] = 30 -- 30 studs out with the crate: SIT used to seat A in the cab, loading it next tick
		local ok, code = TrainRules.canSit(w.run, A)
		expect(`{ok} {code}`).toBe("false carrying")
		w.run = TrainRules.help(w.run, B, crate)
		expect(TrainRules.canSit(w.run, B)).toBe(true) -- the helper lets go; A keeps the crate
		expect(select(2, TrainRules.canSit(w.run, 99))).toBe("refused")
		step(w) -- the server refused the sit: A stands at depth 30, outside the load box
		expect(`{count(w, "load")} {w.run.carries[A] ~= nil}`).toBe("0 true")
		w.depth[A], w.loadBox[A] = nil, true -- walked it home
		untilEvent(w, "load")
		expect(TrainRules.canSit(w.run, A)).toBe(true)
	end)

	it("refuses carrying outside a stop and Depot buying outside the Depot", function()
		local run = TrainRules.join(TrainRules.new(1, 0), A, 0)
		expect(select(3, TrainRules.pick(run, A, 1))).toBe("phase")
		expect(select(3, TrainRules.help(run, A, 1))).toBe("phase")
		expect(select(3, TrainRules.drop(run, A, { x = 0, y = 0, z = 0 }))).toBe("phase")
		expect(select(3, TrainRules.pick(run, 99, 1))).toBe("refused")
		expect(select(3, TrainRules.buy(run, A, "boiler"))).toBe("phase")
		expect(TrainRules.letGo(run, A) == run).toBe(true)
	end)

	it("reports the LanternRun status attributes", function()
		local w = world({ A })
		untilEvent(w, "arrive")
		local s = TrainRules.status(w.run, w.now)
		local keys = {}
		for k in s do
			table.insert(keys, k)
		end
		table.sort(keys)
		expect(table.concat(keys, " ")).toBe(
			"BellAt Boiler Bunker Coal CoalCap CoalNeed Conductor Crew D Lamps Lantern LeaveAt Leg Line Oil Parts Phase PhaseAt Speed Stop Tile Votes Wave Weekly"
		)
		expect(`{s.Phase} {s.Stop} {s.D} {s.CoalCap} {s.Conductor} {s.Crew[1].userId} {s.Tile ~= ""}`).toBe(
			`stop 1 700 80 {A} {A} true`
		)
		expect(near(s.LeaveAt, s.PhaseAt + 70 + 13.125, 1e-6)).toBe(true)
		expect(near(s.CoalNeed, 5000 / 60, 1e-9)).toBe(true)
	end)
end)

describe("TrainRules: the pacing check values (GDD P, K)", function()
	it("solo from PLAY: stop 1 at 43 s, the first rescue at 49 s, the bell at 113 s, stop 2 by 169 s", function()
		local w = world({ A })
		expect(untilEvent(w, "depart")).toBe(3)
		local stop1 = untilEvent(w, "arrive")
		expect(near(stop1, 43, 0.05)).toBe(true)
		-- the pacing script's player: 1 s to stand, walks 22 studs at 16, 0.5 s to pick, back at 9
		local crate = critterOn22(w.run)
		local out, pick = stop1 + 1 + 22 / 16, stop1 + 1 + 22 / 16 + 0.5
		local home = pick + 22 / 9
		while w.now < home do
			w.depth[A] = if w.now < out
				then (w.now - stop1 - 1) * 16
				elseif w.now < pick then 22
				else 22 - (w.now - pick) * 9
			if w.now >= pick and w.run.carries[A] == nil then
				w.run = TrainRules.pick(w.run, A, crate)
			end
			step(w)
		end
		w.depth[A] = nil
		w.loadBox[A] = true
		local rescued = untilEvent(w, "load")
		expect(rescued <= 49).toBe(true)
		expect(w.run.critters).toBe(1)
		w.loadBox[A] = false
		expect(near(untilEvent(w, "bell"), 113, 0.05)).toBe(true)
		local stop2 = untilEvent(w, "arrive")
		expect(stop2 <= 169).toBe(true)
		expect(near(stop2, 43 + 70 + 13.125 + 40, 0.1)).toBe(true)
	end)

	it(
		"fog check: leaving at the bell, a lone critter carrier gets home from 118 studs, everyone else from 159",
		function()
			local run = TrainRules.new(1, 0)
			run.phase, run.bellAt = "stop", 0
			local function home(depth: number, speed: number): boolean
				local t, x = 0, depth
				while x > 0 do
					if x >= (TrainRules.fogFront(run, t) :: number) then
						return false
					end
					t, x = t + 0.05, x - speed * 0.05
				end
				return true
			end
			expect(`{home(118, 9)} {home(119, 9)}`).toBe("true false")
			for _, speed in { 13, 15, 16 } do
				expect(home(159, speed)).toBe(true)
			end
		end
	)
end)
