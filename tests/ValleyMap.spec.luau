--!strict
local T = require("./framework")
local ValleyMap = require("../src/shared/ValleyMap")
local StationConfig = require("../src/shared/StationConfig")

local describe, it, expect = T.describe, T.it, T.expect

describe("ValleyMap", function()
	it("has a ground for every station, in the stations' order, on whole voxels", function()
		expect(#ValleyMap.GROUNDS).toBe(#StationConfig.STATIONS)
		for k, st in StationConfig.STATIONS do
			local g = ValleyMap.GROUNDS[k]
			expect(g.id).toBe(st.id)
			expect(g.h % 4).toBe(0) -- terrain stands exactly level only on a voxel's edge
		end
	end)

	it("keeps the homestead and every ground level, and the grounds clear of each other", function()
		for _, p in { { 0, 0 }, { 60, -40 }, { -100, 20 }, { 0, 108 } } do
			expect(math.abs(ValleyMap.height(p[1], p[2])) < 1e-6).toBeTruthy()
		end
		for k, g in ValleyMap.GROUNDS do
			for _, off in { { 0, 0 }, { 100, 0 }, { -70, 70 }, { 0, -104 } } do
				expect(math.abs(ValleyMap.height(g.x + off[1], g.z + off[2]) - g.h) < 1e-6).toBeTruthy()
			end
			-- its levelled round does not reach the homestead's, another ground's or the wall
			local d = math.sqrt(g.x ^ 2 + g.z ^ 2)
			expect(d > ValleyMap.HOME + ValleyMap.PAD).toBeTruthy()
			expect(d + ValleyMap.PAD < ValleyMap.WALL).toBeTruthy()
			for j, other in ValleyMap.GROUNDS do
				if j > k then
					expect(math.sqrt((g.x - other.x) ^ 2 + (g.z - other.z) ^ 2) > 2 * ValleyMap.PAD).toBeTruthy()
				end
			end
		end
	end)

	it("runs a path from the homestead to every ground with no step in it", function()
		for k, w in ValleyMap.WAYS do
			local g = ValleyMap.GROUNDS[k]
			local last = ValleyMap.height(w.ax, w.az)
			expect(math.abs(last) < 1e-6).toBeTruthy()
			for step = 1, 60 do
				local t = step / 60
				local h = ValleyMap.height(w.ax + (w.bx - w.ax) * t, w.az + (w.bz - w.az) * t)
				expect(math.abs(h - last) < 2.5).toBeTruthy() -- a slope a player walks, nowhere a cliff
				last = h
			end
			expect(math.abs(last - g.h) < 1e-6).toBeTruthy()
		end
	end)

	it("brings the road to the hub down to the hub's level before the valley's edge", function()
		expect(math.abs(ValleyMap.height(0, -ValleyMap.ROAD_TOP + 20)) < 1e-6).toBeTruthy()
		local last = 0
		for z = ValleyMap.ROAD_TOP, ValleyMap.HALF - 2, 4 do
			local h = ValleyMap.height(0, -z)
			expect(h <= last + 1e-6).toBeTruthy() -- only ever down
			expect(math.abs(ValleyMap.height(30, -z) - h) < 1e-6).toBeTruthy() -- and level across the road
			last = h
		end
		expect(math.abs(last - ValleyMap.HUB) < 1e-6).toBeTruthy()
		expect(math.abs(ValleyMap.height(0, -ValleyMap.ROAD_FOOT - 10) - ValleyMap.HUB) < 1e-6).toBeTruthy()
	end)

	it("closes the valley: high ground inside the wall all round, the land outside's level at its edge", function()
		for deg = 0, 359, 3 do
			local a = math.rad(deg)
			local x, z = math.cos(a), math.sin(a)
			if not (z < 0 and math.abs(x) * ValleyMap.HALF < 90) then -- but for the road's gap
				local best = -math.huge
				for r = ValleyMap.WALL - 60, ValleyMap.HALF - 2, 4 do
					local scale = r / math.max(math.abs(x), math.abs(z))
					best = math.max(best, ValleyMap.height(x * scale, z * scale))
				end
				expect(best > ValleyMap.LAKE + 20).toBeTruthy() -- a rise the lake cannot spill over
			end
		end
		for _, p in { { ValleyMap.HALF - 1, 0 }, { 0, ValleyMap.HALF - 1 }, { -ValleyMap.HALF + 1, 200 } } do
			expect(math.abs(ValleyMap.height(p[1], p[2]) - ValleyMap.HUB) < 1e-6).toBeTruthy()
		end
	end)

	it("has a lake by the two beach grounds, and water in the stream on its way down", function()
		local lake = 0
		for x = -ValleyMap.HALF, ValleyMap.HALF, 16 do
			for z = -ValleyMap.HALF, ValleyMap.HALF, 16 do
				local h = ValleyMap.height(x, z)
				if ValleyMap.water(x, z, h) == ValleyMap.LAKE then
					lake += 1
					expect(x > 150).toBeTruthy() -- all of it on the lake's side
				end
			end
		end
		expect(lake > 30).toBeTruthy() -- 16-stud squares: over 7,000 square studs of water
		local x, z = 100, 71 -- half way down the stream, between two of its bends
		local d = ValleyMap.stream(x, z)
		expect(d < 2).toBeTruthy()
		local h = ValleyMap.height(x, z)
		expect(ValleyMap.water(x, z, h) == h + 1.3).toBeTruthy()
		expect(ValleyMap.kind(263, 61, -12, 0)).toBe("track")
		expect(ValleyMap.kind(0, -200, -4, 0.05)).toBe("path")
	end)
end)
