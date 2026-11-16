--!strict
-- The shape of a ranch's valley (decision 0070): the homestead on a plateau in the middle, the six
-- training grounds set into the land round it (basins and ledges up the mountainside, two down by a
-- lake), a path from the homestead to each, a stream from the spring to the lake, and the road down to
-- the hub. Pure: no Roblox API (its noise is Luau's own), so the layout is tested by Lune. The world
-- writes its terrain from `height` and `water` (src/stations/Valley.luau).
--
-- Everything is in a ranch's own plan: `x` to its right and `z` away from the hub (the hub is towards
-- -z), in studs from the homestead's middle; heights are above the homestead's ground.

local ValleyMap = {}

ValleyMap.HALF = 448 -- the valley is written this far each way from its middle
ValleyMap.WALL = 418 -- no one walks further out than this
ValleyMap.HOME = 112 -- the radius levelled for the homestead
ValleyMap.PAD = 106 -- and for each training ground
ValleyMap.LAKE = -20 -- the top of the lake's water
ValleyMap.HUB = -22 -- the hub's ground, which the road comes down to
ValleyMap.ROAD_TOP, ValleyMap.ROAD_FOOT = 175, 340 -- how far along the hub road its slope begins and ends

-- `sx`, `sz`: where its path leaves the homestead's plot (a square 75 studs each way from the middle):
-- a gap in the fence where the plot is clear of buildings, or beside the plot's own gate at the front.
export type Ground = { id: string, x: number, z: number, h: number, sx: number, sz: number }
-- The training grounds, in StationConfig.STATIONS' order. Heights are whole voxels (4 studs), so the
-- terrain stands exactly level there.
ValleyMap.GROUNDS = {
	{ id = "track", x = 263, z = 61, h = -12, sx = 75, sz = 22 }, -- on the flat behind the beach
	{ id = "gym", x = -243, z = -118, h = 8, sx = -22, sz = -88 }, -- in a cut in the hill
	{ id = "pool", x = 221, z = -155, h = -16, sx = 22, sz = -88 }, -- on the beach, by the water
	{ id = "library", x = -278, z = 112, h = 44, sx = -75, sz = 30 }, -- on a high ledge
	{ id = "spring", x = -99, z = 273, h = 28, sx = -52, sz = 75 }, -- in a basin under the waterfall
	{ id = "guard", x = 127, z = 238, h = 16, sx = 45, sz = 75 }, -- in the mouth of a pass
} :: { Ground }

-- The stream, from above the spring to the lake.
ValleyMap.STREAM = { { -99, 372 }, { -99, 273 }, { -30, 170 }, { 60, 112 }, { 140, 30 }, { 215, -40 }, { 330, -55 } }

local LAKEWARD = { x = 0.98, z = -0.19 } -- the way down to the lake

local function smooth(a: number, b: number, v: number): number
	local t = math.clamp((v - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function ridge(x: number, z: number, f: number): number
	return 1 - math.min(1, math.abs(math.noise(x * f, z * f, 3.7)) * 1.6)
end

-- (distance from (x, z) to the segment a to b, how far along it the nearest point is: 0 to 1)
local function near(x: number, z: number, ax: number, az: number, bx: number, bz: number): (number, number)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2), t
end

-- (distance from (x, z) to the stream, how far along the whole of it the nearest point is: 0 to 1)
function ValleyMap.stream(x: number, z: number): (number, number)
	local best, at = math.huge, 0
	local line = ValleyMap.STREAM
	for i = 1, #line - 1 do
		local d, t = near(x, z, line[i][1], line[i][2], line[i + 1][1], line[i + 1][2])
		if d < best then
			best, at = d, (i - 1 + t) / (#line - 1)
		end
	end
	return best, at
end

export type Way = { sx: number, sz: number, ax: number, az: number, bx: number, bz: number, h0: number, h1: number }
-- The paths: straight from where each leaves the plot (s) to its ground's edge (b). It is level as far
-- as the homestead's edge (a), then slopes to the ground's height.
local ways: { Way } = {}
for _, g in ValleyMap.GROUNDS do
	local dx, dz = g.x - g.sx, g.z - g.sz
	local d = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / d, dz / d
	-- how far along the line it leaves the homestead's levelled round, a little inside its edge
	local along = -(g.sx * ux + g.sz * uz)
	local out = along + math.sqrt(math.max(0, along * along - (g.sx * g.sx + g.sz * g.sz) + (ValleyMap.HOME - 6) ^ 2))
	local b = d - (ValleyMap.PAD - 6)
	table.insert(ways, {
		sx = g.sx,
		sz = g.sz,
		ax = g.sx + ux * out,
		az = g.sz + uz * out,
		bx = g.sx + ux * b,
		bz = g.sz + uz * b,
		h0 = 0,
		h1 = g.h,
	})
end
ValleyMap.WAYS = ways

-- The road to the hub at `d` studs along it from the homestead's middle: level, down the slope, level.
local function road(d: number): number
	return ValleyMap.HUB * math.clamp((d - ValleyMap.ROAD_TOP) / (ValleyMap.ROAD_FOOT - ValleyMap.ROAD_TOP), 0, 1)
end

-- The land's height at (x, z).
function ValleyMap.height(x: number, z: number): number
	local r = math.sqrt(x * x + z * z)
	local s = x * LAKEWARD.x + z * LAKEWARD.z
	local n = 0.6 * ridge(x, z, 0.0036) + 0.4 * ridge(x + 900, z, 0.0085)
	local inland = 1 - smooth(-40, 220, s) -- 1 among the mountains, 0 on the lake's side
	-- low knolls between the grounds, and mountains that rise behind them
	local h = 10
		+ 30 * n * (0.4 + 0.6 * inland)
		+ math.max(0, r - 280) * 0.5 * (0.2 + 0.8 * inland) * (0.5 + 0.95 * n)
		- 0.1 * math.max(0, s)
	local beach = -8 - 22 * smooth(215, 360, s + 26 * math.noise(x * 0.006, z * 0.006, 1))
	h += (beach - h) * smooth(150, 262, s)
	-- the valley is closed all round: a ridge near its edge (the lake's far shore too), then down to
	-- the level of the land outside
	local edge = math.max(math.abs(x), math.abs(z))
	h += (40 + 62 * n - h) * smooth(372, 424, edge) * (0.45 + 0.55 * (1 - inland))
	h += (ValleyMap.HUB - h) * smooth(430, 446, edge)
	local d, t = ValleyMap.stream(x, z) -- the stream's gully, from the spring's height to the lake
	if d < 40 then
		local bed = 28 - 50 * smooth(0.14, 1, t)
		h += (math.min(h, bed) - h) * smooth(40, 10, d)
	end
	if z < 0 then -- the road down to the hub, straight along -z, cut through the ridge
		local across = math.abs(x)
		if across < 80 then
			h += (road(-z) - h) * smooth(80, 42, across)
		end
	end
	for _, w in ways do
		local wd, wt = near(x, z, w.ax, w.az, w.bx, w.bz)
		if wd < 44 then
			h += (w.h0 + (w.h1 - w.h0) * wt - h) * smooth(44, 11, wd)
		end
	end
	-- what is levelled: the homestead and each ground. Near one the land comes to its height; between
	-- two that stand close it steps from one's height to the other's, so each stays level to its edge
	local nearest, sum, weight = math.huge, 0, 0
	for k = 0, #ValleyMap.GROUNDS do
		local g = ValleyMap.GROUNDS[k]
		local out = if g then math.sqrt((x - g.x) ^ 2 + (z - g.z) ^ 2) - ValleyMap.PAD else r - ValleyMap.HOME -- how far outside its levelled round
		if out <= 0 then
			nearest, sum, weight = 0, if g then g.h else 0, 1 -- on it: exactly its height
			break
		elseif out < 46 then
			local w = 1 / out - 1 / 46 -- fades to nothing as it comes into reach, so nothing jumps
			nearest, sum, weight = math.min(nearest, out), sum + w * (if g then g.h else 0), weight + w
		end
	end
	if weight > 0 then
		h += (sum / weight - h) * smooth(46, 0, nearest)
	end
	if t > 0.14 and d < 9 and r > ValleyMap.HOME then -- the stream's bed
		local clear = true
		for _, g in ValleyMap.GROUNDS do
			clear = clear and math.sqrt((x - g.x) ^ 2 + (z - g.z) ^ 2) > ValleyMap.PAD
		end
		if clear then
			h -= 2.4 * smooth(9, 3, d)
		end
	end
	return h
end

-- The top of the water over (x, z): the lake's, the stream's, or nil where there is none.
function ValleyMap.water(x: number, z: number, h: number): number?
	if h < ValleyMap.LAKE and x * LAKEWARD.x + z * LAKEWARD.z > 150 and math.max(math.abs(x), math.abs(z)) < 430 then
		return ValleyMap.LAKE -- the hub's road is as low, but it is not on the lake's side
	end
	local d, t = ValleyMap.stream(x, z)
	if t > 0.14 and d < 5 and h > ValleyMap.LAKE then
		return h + 1.3
	end
	return nil
end

-- What the land is at (x, z), given its height and how steep it is there (0 level to 1 sheer): the id
-- of a training ground (its floor), or "path", "sand", "rock", "snow" or "grass".
function ValleyMap.kind(x: number, z: number, h: number, steep: number): string
	for _, g in ValleyMap.GROUNDS do
		if (x - g.x) ^ 2 + (z - g.z) ^ 2 < 90 * 90 then
			return g.id
		end
	end
	for _, w in ways do
		if near(x, z, w.sx, w.sz, w.bx, w.bz) < 7 then
			return "path"
		end
	end
	if z < -75 and math.abs(x) < 9 then
		return "path"
	end
	local s = x * LAKEWARD.x + z * LAKEWARD.z
	if h < -3.5 and s > 150 and steep < 0.3 then
		return "sand"
	elseif steep > 0.34 then
		return "rock"
	elseif h > 118 then
		return "snow"
	end
	return "grass"
end

return ValleyMap
