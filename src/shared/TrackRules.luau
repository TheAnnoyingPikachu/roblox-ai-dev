--!strict
-- Pure track geometry for Lantern Express (architecture lantern 3.2): a centripetal Catmull-Rom
-- spline through authored control points, resampled by arc length so a distance `d` along the
-- track maps to a position and a forward vector in O(1). Frames: -z forward, y up, x right (the
-- train frame of architecture 2). No Roblox APIs; vectors are plain { x, y, z } tables.

local TrackRules = {}

type Vec3 = { x: number, y: number, z: number }
export type Path = { length: number, step: number, samples: { Vec3 }, closed: boolean }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end
local function sub(a: Vec3, b: Vec3): Vec3
	return v(a.x - b.x, a.y - b.y, a.z - b.z)
end
local function len(a: Vec3): number
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end
local function lerp(a: Vec3, b: Vec3, t: number): Vec3
	return v(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
end
local function unit(a: Vec3): Vec3
	local l = len(a)
	return if l > 0 then v(a.x / l, a.y / l, a.z / l) else v(0, 0, -1)
end

-- Barry-Goldman evaluation of one centripetal (alpha 0.5) segment between p1 and p2.
local function segment(p0: Vec3, p1: Vec3, p2: Vec3, p3: Vec3, t: number): Vec3
	local t1 = math.max(math.sqrt(len(sub(p1, p0))), 1e-6)
	local t2 = t1 + math.max(math.sqrt(len(sub(p2, p1))), 1e-6)
	local t3 = t2 + math.max(math.sqrt(len(sub(p3, p2))), 1e-6)
	local u = t1 + (t2 - t1) * t
	local a1 = lerp(p0, p1, u / t1)
	local a2 = lerp(p1, p2, (u - t1) / (t2 - t1))
	local a3 = lerp(p2, p3, (u - t2) / (t3 - t2))
	local b1 = lerp(a1, a2, u / t2)
	local b2 = lerp(a2, a3, (u - t1) / (t3 - t1))
	return lerp(b1, b2, (u - t1) / (t2 - t1))
end

function TrackRules.build(points: { Vec3 }, closed: boolean, step: number?): Path
	local s = step or 2
	local n = #points
	assert(n >= 2, "a track needs two points")
	local function point(i: number): Vec3
		if closed then
			return points[(i - 1) % n + 1]
		elseif i < 1 then
			return lerp(points[1], points[2], -1) -- 2 p1 - p2
		elseif i > n then
			return lerp(points[n - 1], points[n], 2)
		end
		return points[i]
	end
	-- A dense polyline (about half a stud a piece), then samples every `s` studs of its length.
	local dense: { Vec3 } = { point(1) }
	for i = 1, if closed then n else n - 1 do
		local p0, p1, p2, p3 = point(i - 1), point(i), point(i + 1), point(i + 2)
		local pieces = math.max(4, math.ceil(len(sub(p2, p1)) * 2))
		for k = 1, pieces do
			table.insert(dense, segment(p0, p1, p2, p3, k / pieces))
		end
	end
	local samples: { Vec3 } = { dense[1] }
	local walked, nextAt = 0, s
	for i = 2, #dense do
		local a, b = dense[i - 1], dense[i]
		local piece = len(sub(b, a))
		while piece > 0 and walked + piece >= nextAt do
			table.insert(samples, lerp(a, b, (nextAt - walked) / piece))
			nextAt += s
		end
		walked += piece
	end
	if closed then
		-- The last sample may sit on the wrap point itself; the wrap interval ends at samples[1].
		if walked - (nextAt - s) < 1e-6 then
			table.remove(samples)
		end
	elseif walked - (nextAt - s) > 1e-6 then
		table.insert(samples, dense[#dense])
	end
	return { length = walked, step = s, samples = samples, closed = closed }
end

-- Position and unit forward at distance d. Samples sit at (i - 1) * step; an open path's last
-- sample is its end point (a shorter last interval), a closed path's last interval ends at samples[1].
function TrackRules.at(path: Path, d: number): (Vec3, Vec3)
	local L, step, s = path.length, path.step, path.samples
	d = if path.closed then d % L else math.clamp(d, 0, L)
	local n = #s
	local i = math.min(math.floor(d / step) + 1, n)
	if not path.closed and i == n then
		i = n - 1
	end
	local a = s[i]
	local b = if i < n then s[i + 1] else s[1]
	local da, db = (i - 1) * step, math.min(i * step, L)
	if i == n then
		db = L
	end
	local t = if db > da then math.clamp((d - da) / (db - da), 0, 1) else 0
	return lerp(a, b, t), unit(sub(b, a))
end

function TrackRules.right(forward: Vec3): Vec3
	return unit(v(-forward.z, 0, forward.x))
end

-- Basis of the frame at origin facing forward: x right (horizontal), y up, z backwards.
local function basis(forward: Vec3): (Vec3, Vec3, Vec3)
	local f = unit(forward)
	local r = TrackRules.right(f)
	local back = v(-f.x, -f.y, -f.z)
	local up = v(back.y * r.z - back.z * r.y, back.z * r.x - back.x * r.z, back.x * r.y - back.y * r.x)
	return r, up, back
end

local function dot(a: Vec3, b: Vec3): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

function TrackRules.toFrame(origin: Vec3, forward: Vec3, p: Vec3): Vec3
	local r, up, back = basis(forward)
	local q = sub(p, origin)
	return v(dot(q, r), dot(q, up), dot(q, back))
end

function TrackRules.fromFrame(origin: Vec3, forward: Vec3, p: Vec3): Vec3
	local r, up, back = basis(forward)
	return v(
		origin.x + r.x * p.x + up.x * p.y + back.x * p.z,
		origin.y + r.y * p.x + up.y * p.y + back.y * p.z,
		origin.z + r.z * p.x + up.z * p.y + back.z * p.z
	)
end

-- Smallest circumradius of three points 8 studs apart, sampled every `step` between the
-- distances (math.huge on a straight). For specs and config checks, not for the 10 Hz loop.
function TrackRules.radius(path: Path, from: number, to: number): number
	local h = 8
	local best = math.huge
	local d = from
	while d <= to do
		local a = TrackRules.at(path, d - h)
		local b = TrackRules.at(path, d)
		local c = TrackRules.at(path, d + h)
		local ab, bc, ca = len(sub(b, a)), len(sub(c, b)), len(sub(a, c))
		local u, w = sub(b, a), sub(c, a)
		local cross = v(u.y * w.z - u.z * w.y, u.z * w.x - u.x * w.z, u.x * w.y - u.y * w.x)
		local area2 = len(cross)
		if area2 > 1e-9 then
			best = math.min(best, ab * bc * ca / (2 * area2))
		end
		d += path.step
	end
	return best
end

return TrackRules
