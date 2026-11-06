--!strict
-- WispRules (architecture lantern 3.5, 8; GDD C4, C6, E): wave sizes, the beam cone, aim checks,
-- exposure and puffs, dims, wave timing and the Lampeater.
local T = require("./framework")
local WispRules = require("../src/shared/WispRules")

local describe, it, expect = T.describe, T.it, T.expect

type Vec3 = { x: number, y: number, z: number }
type Night = WispRules.Night

local ORIGIN = { x = 0, y = 5, z = 39 }
local LANTERNS = { { x = 0, y = 6, z = -11 }, { x = 0, y = 7, z = 68 } }

local function unit(a: Vec3): Vec3
	local l = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
	return { x = a.x / l, y = a.y / l, z = a.z / l }
end

local function toward(p: Vec3, from: Vec3?): WispRules.Beam
	local o = from or ORIGIN
	return { origin = o, dir = unit({ x = p.x - o.x, y = p.y - o.y, z = p.z - o.z }) }
end

local function input(now: number, dt: number, extra: { [string]: any }?): WispRules.StepInput
	local out: any = { now = now, dt = dt, n = 1, leg = 1, line = "forest", lamps = 1, beams = {}, lanterns = LANTERNS }
	for k, x in extra or {} do
		out[k] = x
	end
	return out
end

-- A night with one drifting wisp born at `born`, heading from far away towards a lantern.
local function oneWisp(born: number): Night
	local night = WispRules.new(0, 1, 1)
	night.nextWave = math.huge
	night.wisps[1] = {
		id = 1,
		born = born,
		from = { x = 70, y = 10, z = 39 },
		target = { x = 0, y = 6, z = 39 },
		speed = 8,
		phase = 0,
		lit = 0,
		state = "drift",
	}
	return night
end

-- Steps from `from` to `to` every dt, aiming `beams` beams at wisp 1 (or at the Lampeater).
local function run(
	night: Night,
	from: number,
	to: number,
	dt: number,
	beams: number,
	extra: { [string]: any }?
): (Night, { any })
	local all = {}
	local k = 0
	while from + k * dt < to - 1e-9 do
		k += 1
		local t = from + k * dt
		local list = {}
		local w = night.wisps[1]
		local l = night.lampeater
		local target = if w then WispRules.pos(w, t) elseif l then WispRules.lampeaterPos(l, t) else nil
		if target then
			for b = 1, beams do
				table.insert(list, toward(target, { x = b, y = 5, z = 39 }))
			end
		end
		local args = { beams = list }
		for key, x in extra or {} do
			args[key] = x
		end
		local events
		night, events = WispRules.step(night, input(t, dt, args))
		for _, e in events do
			table.insert(all, { t = t, e = e })
		end
	end
	return night, all
end

local function kinds(events: { any }, kind: string): { number }
	local out = {}
	for _, x in events do
		if x.e.kind == kind then
			table.insert(out, math.floor(x.t * 100 + 0.5) / 100)
		end
	end
	return out
end

describe("WispRules sizes and paths", function()
	it("sizes waves as GDD C6, +1 on the Lake Line, and dims by crew size", function()
		local rows = {}
		for n = 1, 6 do
			local legs = {}
			for leg = 1, 3 do
				table.insert(legs, WispRules.waveSize(n, leg, "forest"))
			end
			table.insert(rows, `{table.concat(legs, "/")}:{WispRules.dimPer(n)}`)
		end
		expect(table.concat(rows, " ")).toBe("4/6/8:6 8/12/16:4.5 12/18/24:3.5 16/24/32:3 17/25/33:3 18/26/34:3")
		expect(WispRules.waveSize(4, 2, "lake")).toBe(25)
		expect(WispRules.waveSize(1, 1, "lake")).toBe(5)
	end)

	it("drifts deterministically and reaches its target at distance / speed", function()
		local w = oneWisp(10).wisps[1]
		local a, b = WispRules.pos(w, 12.3), WispRules.pos(w, 12.3)
		expect(`{a.x} {a.y} {a.z}`).toBe(`{b.x} {b.y} {b.z}`)
		local arrive = 10 + 70 / 8
		local p = WispRules.pos(w, arrive)
		local d = math.sqrt((p.x - 0) ^ 2 + (p.y - 6) ^ 2 + (p.z - 39) ^ 2)
		expect(d <= 2 + 1e-9).toBe(true) -- the wobble only, inside the 3-stud reach
		local early = WispRules.pos(w, arrive - 1)
		expect(early.x > 5).toBe(true)
		expect(WispRules.pos(w, 0).x).toBe(WispRules.pos(w, 10).x) -- before birth it waits at `from`
	end)
end)

describe("WispRules beams and aims", function()
	it("lights 6.9 degrees in, 7.1 out, and up to the range", function()
		local beam = { origin = { x = 0, y = 0, z = 0 }, dir = { x = 0, y = 0, z = -1 } }
		local function at(deg: number, dist: number): Vec3
			return { x = dist * math.sin(math.rad(deg)), y = 0, z = -dist * math.cos(math.rad(deg)) }
		end
		expect(WispRules.lit(beam, at(6.9, 50), 80)).toBe(true)
		expect(WispRules.lit(beam, at(7.1, 50), 80)).toBe(false)
		expect(WispRules.lit(beam, at(0, 80), 80)).toBe(true)
		expect(WispRules.lit(beam, at(0, 80.01), 80)).toBe(false)
		expect(WispRules.lit(beam, at(0, 95), 100)).toBe(true)
		expect(WispRules.lit(beam, at(180, 10), 80)).toBe(false)
	end)

	it("refuses bad aims and clamps the pitch to -15 to 75 degrees", function()
		local nan = 0 / 0
		for _, bad in
			{
				nil,
				"x",
				5,
				{},
				{ x = nan, y = 0, z = -1 },
				{ x = math.huge, y = 0, z = 0 },
				{ x = 0, y = 0, z = 0 },
				{ x = 0, y = 0, z = -2 },
				{ x = 0, y = 0, z = -0.4 },
				{ x = "1", y = 0, z = 0 },
			} :: { any }
		do
			expect(WispRules.clampAim(bad)).toBeNil()
		end
		local fwd = WispRules.clampAim({ x = 0, y = 0, z = -1.2 }) :: Vec3
		expect(`{fwd.x} {fwd.y} {fwd.z}`).toBe("0 0 -1")
		local up = WispRules.clampAim({ x = 0, y = 1, z = 0 }) :: Vec3
		expect(math.abs(math.deg(math.asin(up.y)) - 75) < 1e-6).toBe(true)
		local down = WispRules.clampAim({ x = 1, y = -1, z = 0 }) :: Vec3
		expect(math.abs(math.deg(math.asin(down.y)) + 15) < 1e-6).toBe(true)
		expect(math.abs(down.x * down.x + down.y * down.y + down.z * down.z - 1) < 1e-9).toBe(true)
		expect(down.x > 0 and down.z == 0).toBe(true) -- the yaw is kept
	end)

	it("puffs after 0.6 / 0.45 / 0.35 s of beam by Lamps level, not a tick sooner", function()
		for lamps, want in { 0.6, 0.45, 0.35 } do
			local _, events = run(oneWisp(0), 0, 1, 0.05, 1, { lamps = lamps })
			expect(`{lamps} {kinds(events, "puff")[1]}`).toBe(`{lamps} {want}`)
		end
	end)

	it("adds exposure across beams: two beams puff in half the time", function()
		local _, events = run(oneWisp(0), 0, 1, 0.05, 2)
		expect(kinds(events, "puff")[1]).toBe(0.3)
	end)

	it("never puffs faster for aims sent more often: exposure grows by the tick's dt", function()
		local _, slow = run(oneWisp(0), 0, 1, 0.1, 1)
		local _, fast = run(oneWisp(0), 0, 1, 0.025, 1)
		expect(`{kinds(slow, "puff")[1]} {kinds(fast, "puff")[1]}`).toBe("0.6 0.6")
	end)

	it("dims the lantern by dimPer(n) when an unlit wisp reaches its target", function()
		local _, events = run(oneWisp(0), 0, 10, 0.1, 0, { n = 3 })
		local dims = {}
		for _, x in events do
			if x.e.kind == "dim" then
				table.insert(dims, `{x.e.ids[1]}:{x.e.amount}`)
			end
		end
		expect(table.concat(dims, " ")).toBe("1:3.5")
		expect(#kinds(events, "puff")).toBe(0)
	end)
end)

describe("WispRules waves and the Lampeater", function()
	it("spawns waves at 8 s and every 25 s, spread over 3 s, aimed at the lanterns", function()
		local night, events = run(WispRules.new(0, 9, 1), 0, 180, 0.5, 0, { n = 2 })
		expect(table.concat(kinds(events, "spawn"), " ")).toBe("8 33 58 83 108 133 158")
		expect(night.wave).toBe(7)
		local first = events[1].e.wisps
		expect(#first).toBe(8)
		for i, w in first do
			expect(math.abs(w.born - (8 + (i - 1) * 3 / 8)) < 1e-9).toBe(true)
			local dx, dz = w.from.x - 0, w.from.z - 39
			local r = math.sqrt(dx * dx + dz * dz)
			expect(r >= 60 - 1e-9 and r <= 75 + 1e-9 and w.from.y >= 4 and w.from.y <= 20).toBe(true)
			expect(w.target.z == -11 or w.target.z == 68).toBe(true)
		end
		local _, again = run(WispRules.new(0, 9, 1), 0, 9, 0.5, 0, { n = 2 })
		expect(again[1].e.wisps[5].from.x).toBe(first[5].from.x) -- seeded
	end)

	it("on leg 3 stops waves at 50 s, warns at 47 s and dives every 8 s from 58 s; an unlit dive dims 10", function()
		local night, events = run(WispRules.new(0, 3, 3), 0, 90, 0.1, 0, { leg = 3 })
		expect(table.concat(kinds(events, "spawn"), " ")).toBe("8 33")
		expect(table.concat(kinds(events, "lampeater"), " ")).toBe("47")
		expect(table.concat(kinds(events, "dive"), " ")).toBe("58 66 74 82 90")
		local lampeater = night.lampeater :: WispRules.Lampeater
		expect(`{lampeater.born} {lampeater.need}`).toBe("50 15")
		local dives = {}
		for _, x in events do
			if x.e.kind == "dim" and x.e.ids == nil then
				table.insert(dives, `{math.floor(x.t * 10 + 0.5) / 10}:{x.e.amount}`)
			end
		end
		expect(table.concat(dives, " ")).toBe("61:10 69:10 77:10 85:10")
	end)

	it("shoos a dive with 0.8 s of beam and is fed once at 15 + 8 (n - 1) beam-seconds", function()
		local night = WispRules.new(0, 3, 3)
		night = run(night, 0, 57.9, 0.1, 0, { leg = 3, n = 2 })
		night.wisps = {} -- leave the moth alone in the sky for the beam helper
		local events
		-- a 0.8 s burst during the first dive (58 to 61) shoos it
		night, events = run(night, 57.9, 58.8, 0.1, 1, { leg = 3, n = 2 })
		local rest
		night, rest = run(night, 58.8, 61.2, 0.1, 0, { leg = 3, n = 2 })
		expect(#kinds(rest, "shoo")).toBe(1)
		expect(#kinds(events, "fed") + #kinds(rest, "fed")).toBe(0)
		local lampeater = night.lampeater :: WispRules.Lampeater
		expect(lampeater.need).toBe(23)
		-- two beams feed it the rest of its 23 beam-seconds; then no more dives
		local fed
		night, fed = run(night, 61.2, 80, 0.1, 2, { leg = 3, n = 2 })
		expect(#kinds(fed, "fed")).toBe(1)
		expect((night.lampeater :: WispRules.Lampeater).gone).toBe("fed")
		local after
		night, after = run(night, 80, 120, 0.1, 2, { leg = 3, n = 2 })
		expect(#kinds(after, "fed") + #kinds(after, "dive")).toBe(0)
	end)

	it("never mutates the night it is given", function()
		local night = oneWisp(0)
		WispRules.step(night, input(0.1, 0.1, { beams = { toward(WispRules.pos(night.wisps[1], 0.1)) } }))
		expect(night.wisps[1].lit).toBe(0)
	end)
end)
