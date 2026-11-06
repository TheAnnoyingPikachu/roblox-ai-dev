--!strict
-- TrackRules (architecture lantern 3.2, 8): arc-length paths through Catmull-Rom control points.
local T = require("./framework")
local LanternConfig = require("../src/shared/LanternConfig")
local TrackRules = require("../src/shared/TrackRules")

local describe, it, expect = T.describe, T.it, T.expect

type Vec3 = { x: number, y: number, z: number }

local function dist(a: Vec3, b: Vec3): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function circle(r: number, n: number): { Vec3 }
	local pts = {}
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		table.insert(pts, { x = r * math.cos(a), y = 0, z = r * math.sin(a) })
	end
	return pts
end

local FOREST = TrackRules.build(LanternConfig.TRACKS.forest.points, true)

describe("TrackRules", function()
	it("wraps a closed path: at(0) equals at(length), negative distances wrap too", function()
		expect(dist((TrackRules.at(FOREST, 0)), (TrackRules.at(FOREST, FOREST.length))) < 1e-6).toBe(true)
		expect(dist((TrackRules.at(FOREST, -10)), (TrackRules.at(FOREST, FOREST.length - 10))) < 1e-6).toBe(true)
		local c = TrackRules.build(circle(200, 96), true)
		expect(dist((TrackRules.at(c, 1)), (TrackRules.at(c, c.length + 1))) < 1e-6).toBe(true)
	end)

	it("gives a unit forward everywhere", function()
		for d = 0, FOREST.length, 37 do
			local _, f = TrackRules.at(FOREST, d)
			expect(math.abs(math.sqrt(f.x * f.x + f.y * f.y + f.z * f.z) - 1) < 1e-9).toBe(true)
		end
		local _, f = TrackRules.at(FOREST, 0)
		expect(`{math.floor(f.x * 1000 + 0.5) / 1000} {f.z}`).toBe("0 -1") -- the hub heads -z
	end)

	it("spaces consecutive samples step +- 2% apart", function()
		for _, path in { FOREST, TrackRules.build(circle(200, 96), true), TrackRules.build(circle(150, 64), true, 4) } do
			local s = path.samples
			for i = 2, #s do
				local gap = dist(s[i], s[i - 1])
				expect(math.abs(gap - path.step) <= 0.02 * path.step).toBe(true)
			end
		end
	end)

	it("clamps an open path to its ends", function()
		local line =
			TrackRules.build({ { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = -50 }, { x = 0, y = 0, z = -100 } }, false)
		expect(math.abs(line.length - 100) < 1e-6).toBe(true)
		local a, b = TrackRules.at(line, -5), TrackRules.at(line, 0)
		expect(dist(a, b) < 1e-9).toBe(true)
		local e, f = TrackRules.at(line, 105)
		expect(`{e.z} {f.z}`).toBe("-100 -1")
		expect(math.abs((TrackRules.at(line, 37.5)).z + 37.5) < 1e-6).toBe(true)
	end)

	it("round-trips points through toFrame and fromFrame, with -z forward and x right", function()
		local origin = { x = 12, y = 3, z = -40 }
		local forward = { x = 0.6, y = 0, z = -0.8 }
		local p = TrackRules.toFrame(origin, forward, { x = 12 + 6, y = 3, z = -40 - 8 })
		expect(`{math.floor(p.x * 1e6 + 0.5) / 1e6} {p.y} {math.floor(p.z * 1e6 + 0.5) / 1e6}`).toBe("0 0 -10")
		for _, q in { { x = 5, y = 7, z = -3 }, { x = -100, y = 0, z = 40 }, { x = 0.5, y = -2, z = 0 } } do
			local back = TrackRules.fromFrame(origin, forward, TrackRules.toFrame(origin, forward, q))
			expect(dist(back, q) < 1e-9).toBe(true)
		end
		local r = TrackRules.right({ x = 0, y = 0, z = -1 })
		local e = TrackRules.right({ x = 1, y = 0, z = 0 })
		expect(`{r.x + 0} {r.z + 0} {e.x + 0} {e.z + 0}`).toBe("1 0 0 1")
	end)

	it("measures the radius of a circle of radius 200 as 200 +- 2, and a straight as infinite", function()
		local c = TrackRules.build(circle(200, 96), true)
		local r = TrackRules.radius(c, 0, c.length)
		expect(math.abs(r - 200) <= 2).toBe(true)
		expect(math.abs(c.length - 2 * math.pi * 200) < 1).toBe(true)
		local line = TrackRules.build({ { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = -100 } }, false)
		expect(TrackRules.radius(line, 10, 90)).toBe(math.huge)
	end)
end)
