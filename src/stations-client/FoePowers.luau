--!strict
-- The Shadow Legion's power moves (decision 0105, SHANNON's concepts): each enemy's effects, drawn afresh every frame
-- of its "magic" clip from the clip's time, translated call for call from the concept renderer's fx_ functions (the
-- concepts started their charge in the warning; here it starts with the clip). Display only.
-- WaveShow names who a power attack reaches before it plays: `PowerAim`, the other side's slots it strikes, and
-- `PowerAllies`, its own side's slots it raises or heals. Without them (a model shown on its own) it aims ahead.
-- Sizes are studs, times seconds into the clip; the hit lands at HIT, as FightFx.POWER_LEAD.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FoeAnchors = require(script.Parent:WaitForChild("FoeAnchors"))
local StationAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationAssets"))

local FoePowers = {}

local HIT = 0.92
local LAST = 2.3 -- seconds into the clip when the last of its effects (a scorch) has faded
local TAU = 2 * math.pi
local UP = Vector3.yAxis

local WHITE = Color3.new(1, 1, 1)
local VIOLET = Color3.fromRGB(170, 70, 255)
local HEX = Color3.fromRGB(120, 40, 220)
local MAGENTA = Color3.fromRGB(230, 70, 220)
local CRIMSON = Color3.fromRGB(235, 40, 110)
local GOLD = Color3.fromRGB(255, 200, 90)
local GREEN = Color3.fromRGB(110, 255, 120)
local RED = Color3.fromRGB(255, 40, 40)
local ROCK = Color3.fromRGB(70, 60, 80)
local BOLT = Color3.fromRGB(190, 110, 255) -- the Battle Priest's bolt (FightFx.BOLTS)

type Bones = { [string]: { bone: Bone, turn: CFrame } }
type Spot = { home: Vector3, chest: Vector3, r: number, h: number, w: number } -- the ground under one, its chest
type Kit = {
	folder: Folder,
	floor: number,
	pools: { [string]: { BasePart } },
	used: { [string]: number },
	shown: { [string]: number },
	lamp: Part,
	light: PointLight,
	want: number, -- how bright the charge's light is this frame (0: off)
}
type Frame = {
	model: Model,
	S: { [string]: any }, -- what a move keeps from frame to frame (where a blade was when it let go)
	base: Vector3, -- the ground under its middle
	fwd: Vector3, -- its front and its left, flat
	left: Vector3,
	size: Vector3,
	me: Spot,
	targets: { Spot },
	allies: { Spot },
}
type Anchors = { [string]: Vector3 }
type Fx = (k: Kit, c: number, A: Anchors, F: Frame) -> ()

local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function grow(c: number, a: number, b: number): number
	return ease((c - a) / math.max(1e-6, b - a))
end

-- x along d (a cylinder's axis)
local function along(mid: Vector3, d: Vector3): CFrame
	local x = d.Unit
	local ref = if math.abs(x.Y) < 0.95 then UP else Vector3.xAxis
	local z = x:Cross(ref).Unit
	return CFrame.fromMatrix(mid, x, z:Cross(x), z)
end

-- The kit: pooled parts placed afresh each frame --------------------------------------------------------------------

local function newKit(floor: number): Kit
	local folder = Instance.new("Folder")
	folder.Name = "FoePower"
	folder.Parent = Workspace
	local lamp = Instance.new("Part")
	lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = true, false, false, false
	lamp.Transparency, lamp.Size = 1, Vector3.one * 0.2
	lamp.Parent = folder
	local light = Instance.new("PointLight")
	light.Shadows, light.Enabled = false, false
	light.Parent = lamp
	return {
		folder = folder,
		floor = floor,
		pools = {},
		used = {},
		shown = {},
		lamp = lamp,
		light = light,
		want = 0,
	}
end

-- `power` is the concepts' glow: 1.5 and over is Neon (a softer light is plain, so it does not glare)
local function part(k: Kit, kind: string, colour: Color3, power: number, alpha: number): BasePart
	local pool = k.pools[kind]
	if pool == nil then
		pool = {}
		k.pools[kind] = pool
	end
	local n = (k.used[kind] or 0) + 1
	k.used[kind] = n
	local p = pool[n]
	if p == nil then
		local made = Instance.new("Part")
		made.Shape = if kind == "ball"
			then Enum.PartType.Ball
			elseif kind == "cyl" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		made.Anchored, made.CanCollide, made.CanQuery, made.CanTouch, made.CastShadow = true, false, false, false, false
		made.TopSurface, made.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		made.Parent = k.folder
		pool[n] = made
		p = made
	end
	p.Color = colour
	p.Material = if kind == "rock"
		then Enum.Material.Slate
		elseif power >= 1.5 then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	p.Transparency = 1 - math.clamp(alpha, 0, 1)
	return p
end

local function begin(k: Kit)
	table.clear(k.used)
	k.want = 0
end

-- hides what this frame did not draw
local function finish(k: Kit)
	for kind, pool in k.pools do
		local used = k.used[kind] or 0
		for i = used + 1, k.shown[kind] or #pool do
			pool[i].Transparency = 1
		end
		k.shown[kind] = used
	end
	k.light.Enabled = k.want > 0
end

local function ground(k: Kit, p: Vector3): Vector3
	return Vector3.new(p.X, k.floor, p.Z)
end

-- the shapes (the concept renderer's, in its order and with its arguments) -----------------------------------------

local function sphere(k: Kit, p: Vector3, r: number, colour: Color3, power: number?, alpha: number?)
	local a = alpha or 1
	if r <= 0 or a <= 0.01 then
		return
	end
	local b = part(k, "ball", colour, power or 5, a)
	b.Size, b.CFrame = Vector3.one * 2 * r, CFrame.new(p)
end

-- a hot core in a soft halo
local function glow(k: Kit, p: Vector3, r: number, colour: Color3, alpha: number?, power: number?)
	local a, g = alpha or 1, power or 6
	sphere(k, p, r * 0.45, WHITE, g * 1.6, a)
	sphere(k, p, r, colour, g, 0.55 * a)
	sphere(k, p, r * 1.7, colour, g * 0.6, 0.18 * a)
end

local function cyl(k: Kit, a: Vector3, b: Vector3, r: number, colour: Color3, power: number, alpha: number)
	local d = b - a
	local n = d.Magnitude
	if n < 1e-4 or r <= 0 then
		return
	end
	local c = part(k, "cyl", colour, power, alpha)
	c.Size, c.CFrame = Vector3.new(n, 2 * r, 2 * r), along((a + b) / 2, d)
end

-- a cone from radius r0 at p0 to r1 at p1 (in three steps when it tapers)
local function streak(
	k: Kit,
	p0: Vector3,
	p1: Vector3,
	r0: number,
	r1: number,
	colour: Color3,
	power: number?,
	alpha: number?
)
	local g, a = power or 5, alpha or 1
	if a <= 0.01 or (p1 - p0).Magnitude < 1e-4 then
		return
	end
	if math.abs(r0 - r1) < 0.25 * math.max(r0, r1) then
		cyl(k, p0, p1, (r0 + r1) / 2, colour, g, a)
		return
	end
	for i = 0, 2 do
		cyl(k, p0:Lerp(p1, i / 3), p0:Lerp(p1, (i + 1) / 3), r0 + (r1 - r0) * (i + 0.5) / 3, colour, g, a)
	end
end

-- a torus, or a tapered arc of one, round `centre` in the plane of x and y
local function arc(
	k: Kit,
	centre: Vector3,
	x: Vector3,
	y: Vector3,
	R: number,
	r: number,
	colour: Color3,
	power: number,
	alpha: number,
	a0: number?,
	a1: number?,
	taper: boolean?
)
	if alpha <= 0.01 or R <= 0 then
		return
	end
	local from, to = a0 or 0, a1 or TAU
	local n = math.clamp(math.round(R * 2 * math.abs(to - from) / TAU), 10, 36)
	local prev = centre + (x * math.cos(from) + y * math.sin(from)) * R
	for i = 1, n do
		local a = from + (to - from) * i / n
		local q = centre + (x * math.cos(a) + y * math.sin(a)) * R
		local rr = if taper then r * math.sin(math.pi * (i - 0.5) / n) ^ 0.7 else r
		local d = (q - prev).Unit * rr * 0.5 -- (a little long, so the joins close)
		cyl(k, prev - d, q + d, rr, colour, power, alpha)
		prev = q
	end
end

-- a ring lying on the ground round p
local function ring(k: Kit, p: Vector3, R: number, r: number, colour: Color3, power: number?, alpha: number?)
	arc(k, ground(k, p) + UP * 0.03, Vector3.xAxis, Vector3.zAxis, R, r, colour, power or 5, alpha or 1)
end

local function disc(k: Kit, p: Vector3, R: number, colour: Color3, power: number?, alpha: number?)
	local a = alpha or 0.5
	if a <= 0.01 or R <= 0 then
		return
	end
	local d = part(k, "cyl", colour, power or 3, a)
	d.Size = Vector3.new(0.05, 2 * R, 2 * R)
	d.CFrame = CFrame.new(ground(k, p) + UP * 0.02) * CFrame.Angles(0, 0, math.pi / 2)
end

local ROCK_AXIS = Vector3.new(1, 0.6, 0.3).Unit

local function rock(k: Kit, p: Vector3, r: number, rot: number, glowColour: Color3?)
	local b = part(k, "rock", ROCK, 0, 1)
	b.Size, b.CFrame = Vector3.new(1.5, 1.3, 1.4) * r, CFrame.new(p) * CFrame.fromAxisAngle(ROCK_AXIS, rot)
	if glowColour then
		sphere(k, p, r * 1.25, glowColour, 4, 0.3)
	end
end

local function sparks(
	k: Kit,
	p: Vector3,
	c: number,
	at: number,
	colour: Color3,
	n: number?,
	L: number?,
	dur: number?,
	seed: number?
)
	local length = dur or 0.35
	if c < at or c > at + length then
		return
	end
	local u = (c - at) / length
	local rnd = Random.new(seed or 1)
	local reach = L or 2
	for _ = 1, n or 10 do
		local d = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.2, 1), rnd:NextNumber(-1, 1)).Unit
		streak(k, p + d * reach * u, p + d * reach * math.min(1, u + 0.35), 0.06 * (1 - u), 0.01, colour, 8, 1 - u)
	end
end

local function burst(k: Kit, p: Vector3, c: number, at: number, colour: Color3, r: number?, dur: number?, seed: number?)
	local size, length = r or 2, dur or 0.4
	if c < at or c > at + length then
		return
	end
	local u = (c - at) / length
	sphere(k, p, size * (0.3 + 1.1 * u), colour, 6, 0.6 * (1 - u))
	sphere(k, p, size * 0.6 * (1 - u), WHITE, 12, 1 - u)
	ring(k, p, size * (0.4 + 2.2 * u), 0.12 * (1 - u) + 0.02, colour, 6, 1 - u)
	sparks(k, p, c, at, colour, 12, size * 1.4, length, seed or 3)
end

-- where something flying from p0 (at t0) to p1 (at t1) is at c, and where it was a moment ago
local function fly(p0: Vector3, p1: Vector3, c: number, t0: number, t1: number, lift: number?): (Vector3, Vector3)
	local h = lift or 0
	local function at(u: number): Vector3
		return p0:Lerp(p1, u) + UP * h * 4 * u * (1 - u)
	end
	local u = math.clamp((c - t0) / (t1 - t0), 0, 1)
	return at(u), at(math.max(0, u - 0.18))
end

local function bolt(
	k: Kit,
	p0: Vector3,
	p1: Vector3,
	c: number,
	t0: number,
	t1: number,
	colour: Color3,
	r: number?,
	lift: number?
)
	if c < t0 or c > t1 then
		return
	end
	local size = r or 0.8
	local p, q = fly(p0, p1, c, t0, t1, lift)
	glow(k, p, size, colour)
	streak(k, q, p, 0.05, size * 0.7, colour, 5, 0.6)
end

-- light gathering at p from a to b, motes drawn in, and the move's light growing with it
local function charge(k: Kit, p: Vector3, c: number, a: number, b: number, colour: Color3, rmax: number?)
	if c < a or c > b + 0.04 then
		return
	end
	local u = grow(c, a, b)
	local r = (rmax or 0.9) * (0.2 + 0.8 * u) * (1 + 0.1 * math.sin(c * 47))
	glow(k, p, r, colour, 0.6 + 0.4 * u)
	for i = 0, 4 do
		local ang = c * 7 + i * TAU / 5
		local rad = r * (3.2 - 2.0 * ((c * 2.5 + i * 0.2) % 1))
		local q = p + Vector3.new(math.cos(ang) * rad, math.sin(ang * 2) * rad * 0.4, math.sin(ang) * rad)
		sphere(k, q, r * 0.12, colour, 8, 0.9)
	end
	if u >= k.want then
		k.want = math.max(u, 0.01)
		k.lamp.CFrame = CFrame.new(p)
		k.light.Color, k.light.Brightness, k.light.Range = colour, 1 + 3 * u, 6 + 10 * u
	end
end

-- a curved blade of light flying along fwd, its tips swept back, spread along `span`
local function crescent(
	k: Kit,
	p: Vector3,
	fwd: Vector3,
	span: Vector3,
	R: number,
	thick: number,
	colour: Color3,
	alpha: number?,
	deg: number?
)
	local a, x = alpha or 1, fwd.Unit
	local y = (span - x * span:Dot(x)).Unit
	local half = math.rad(deg or 75)
	arc(k, p - x * R, x, y, R, thick, colour, 6, 0.75 * a, -half, half, true)
	arc(k, p - x * R * 1.02, x, y, R * 0.97, thick * 0.4, WHITE, 10, a, -half * 0.9, half * 0.9, true)
end

-- a glowing crack zigzagging along the ground from p0 to p1 as c goes t0 -> t1, shards jumping out of its end
local function fissure(
	k: Kit,
	S: { [string]: any },
	p0: Vector3,
	p1: Vector3,
	c: number,
	t0: number,
	t1: number,
	colour: Color3,
	width: number,
	seed: number
)
	local key = `zig{seed}`
	local pts: { Vector3 } = S[key]
	if pts == nil then
		local rnd = Random.new(seed)
		local n = 14
		local d = p1 - p0
		local side = Vector3.new(-d.Z, 0, d.X).Unit
		pts = {}
		for i = 0, n do
			table.insert(
				pts,
				ground(k, p0:Lerp(p1, i / n)) + side * (if i > 0 and i < n then rnd:NextNumber(-0.9, 0.9) else 0)
			)
		end
		S[key] = pts
	end
	if c < t0 then
		return
	end
	local u = math.min(1, (c - t0) / (t1 - t0))
	local fade = 1 - grow(c, t1 + 0.25, t1 + 0.6)
	local shown = u * (#pts - 1)
	local lift = UP * 0.05
	for i = 1, #pts - 1 do
		if i - 1 > shown then
			break
		end
		local a, b = pts[i], pts[i + 1]
		if i > shown then
			b = a:Lerp(b, shown - (i - 1))
		end
		streak(k, a + lift, b + lift, width, width, colour, 7, 0.9 * fade)
		streak(k, a + lift, b + lift, width * 0.35, width * 0.35, WHITE, 10, fade)
		local age = (shown - (i - 1)) / (#pts - 1) * (t1 - t0)
		if age < 0.25 then
			local rnd = Random.new((i - 1) * 13 + seed)
			for j = 0, 1 do
				local q = a
					+ Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)) * 0.6
					+ UP * (0.4 + 2.5 * age)
				rock(k, q, 0.28, age * 9 + j, colour)
			end
		end
	end
end

-- a shaft of light coming down onto p: its foot falls from h to the ground by t1, then it fades
local function pillar(
	k: Kit,
	p: Vector3,
	c: number,
	t0: number,
	t1: number,
	colour: Color3,
	r: number,
	h: number,
	a: number
)
	if c < t0 then
		return
	end
	local fall = grow(c, t0, t1)
	local fade = 1 - grow(c, t1 + 0.2, t1 + 0.6)
	local top = ground(k, p) + UP * h
	local foot = ground(k, p) + UP * h * (1 - fall)
	streak(k, foot, top, r, r * 1.3, colour, 1.1, a * fade)
	streak(k, foot, top, r * 0.2, r * 0.3, colour, 2, a * fade)
end

-- a summoning circle on the ground: two rings and a five-pointed star turning in them
local function rune(k: Kit, p: Vector3, R: number, c: number, colour: Color3, alpha: number)
	if alpha <= 0.01 then
		return
	end
	local q = ground(k, p)
	ring(k, q, R, 0.06, colour, 3, alpha)
	ring(k, q, R * 0.72, 0.04, colour, 3, alpha)
	for i = 0, 4 do
		local a = c * 1.5 + i * TAU * 2 / 5
		local b = a + TAU * 2 / 5
		streak(
			k,
			q + Vector3.new(math.cos(a) * R * 0.72, 0.04, math.sin(a) * R * 0.72),
			q + Vector3.new(math.cos(b) * R * 0.72, 0.04, math.sin(b) * R * 0.72),
			0.03,
			0.03,
			colour,
			3,
			alpha
		)
	end
	disc(k, q, R, colour, 1.2, 0.1 * alpha)
end

-- n see-through copies of the model as it stands now, in the kit's folder (the Cavalry Commander's charge)
local function ghosts(k: Kit, model: Model, bones: Bones, n: number): { Model }
	local made = {}
	local archivable = model.Archivable
	model.Archivable = true
	for i = 1, n do
		local copy = model:Clone()
		for _, tag in CollectionService:GetTags(copy) do -- or the client would rig and fight it
			CollectionService:RemoveTag(copy, tag)
		end
		for _, d in copy:GetDescendants() do
			if d.Name == "Hit" or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("SurfaceAppearance") then
				d:Destroy()
			elseif d:IsA("Bone") and bones[d.Name] then
				d.Transform = bones[d.Name].bone.Transform
			elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
				d.Enabled = false
			elseif d:IsA("MeshPart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
				d.TextureID, d.Material, d.Color = "", Enum.Material.ForceField, HEX -- (see-through, its edges lit)
				d.Transparency = 0.1 + 0.15 * (i - 1)
			elseif d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			end
		end
		copy.Parent = k.folder
		table.insert(made, copy)
	end
	model.Archivable = archivable
	return made
end

-- Each enemy's move: c the clip's time, A its anchors as posed now, F who it reaches ----------------------------------

-- what a move keeps once `now` is true (where its blade was when it let go)
local function keep(F: Frame, name: string, now: boolean, p: Vector3): Vector3?
	if now and F.S[name] == nil then
		F.S[name] = p
	end
	return F.S[name]
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.zAxis
end

local FX: { [string]: Fx } = {}

FX.foe_knight_forge = function(k, c, A, F) -- Dark Cleave
	local T = F.targets[1]
	charge(k, A.blade, c, 0, 0.6, VIOLET, 0.7)
	local b0 = keep(F, "blade0", c >= 0.66, A.blade)
	if b0 and c <= HIT then
		local p = fly(b0, T.chest, c, 0.66, HIT)
		crescent(k, p, T.chest - b0, UP, 2.6, 0.55, VIOLET)
	end
	burst(k, T.chest, c, HIT, VIOLET, 2.2)
end

FX.foe_archer_forge = function(k, c, A, F) -- Shadow Volley
	local T = F.targets[1]
	charge(k, A.bow, c, 0, 0.25, HEX, 0.5)
	charge(k, A.arrow, c, 0.25, 0.55, VIOLET, 0.5)
	local a0 = keep(F, "arrow0", c >= 0.55, A.arrow)
	if a0 then
		local apex = a0:Lerp(T.chest, 0.45) + UP * 9
		local function land(rnd: Random): Vector3
			return ground(k, T.home) + Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)) * 2.2
		end
		if c <= 0.72 then -- one arrow up
			local p, q = fly(a0, apex, c, 0.55, 0.72)
			streak(k, q, p, 0.04, 0.25, VIOLET, 7, 0.9)
			glow(k, p, 0.35, VIOLET)
		elseif c <= HIT then -- splits into five that rain down
			if c <= 0.76 then
				burst(k, apex, c, 0.72, VIOLET, 0.8, 0.2)
			end
			local rnd = Random.new(2)
			for i = 0, 4 do
				local to = land(rnd)
				if c >= 0.72 + i * 0.02 then
					local p, q = fly(apex, to, c, 0.72 + i * 0.02, 0.9 + i * 0.01)
					streak(k, q, p, 0.03, 0.2, VIOLET, 7, 0.9)
				end
			end
		end
		if c >= 0.9 then
			local rnd = Random.new(2)
			for i = 0, 4 do
				burst(k, land(rnd) + UP * 0.3, c, 0.9 + i * 0.01, VIOLET, 0.7, 0.3, i)
			end
		end
	end
	burst(k, T.chest, c, HIT, VIOLET, 1.6)
end

FX.foe_knight_shield_forge = function(k, c, A, F) -- Shield Slam
	local T = F.targets[1]
	charge(k, A.shield, c, 0, 0.6, VIOLET, 1.1)
	local s0 = keep(F, "shield0", c >= 0.70, A.shield)
	if s0 and c <= HIT then
		local p = fly(s0, T.chest, c, 0.70, HIT)
		local fwd = (T.chest - s0).Unit
		local u = (c - 0.70) / 0.22
		local x = fwd:Cross(UP).Unit -- a ring stood up, facing its way
		for i, s in { 1.0, 0.75 } do
			arc(k, p - fwd * (i - 1) * 0.6, x, UP, (1.6 + 0.8 * u) * s, 0.16, VIOLET, 6, 0.9 - 0.3 * (i - 1))
		end
		sphere(k, p, 1.5 + 0.7 * u, VIOLET, 3, 0.18)
	end
	burst(k, T.chest, c, HIT, VIOLET, 2.4)
end

FX.foe_ogre_forge = function(k, c, A, F) -- Ground Pound
	local T = F.targets[1]
	charge(k, A.club, c, 0, 0.6, VIOLET, 1.0)
	local c0 = keep(F, "club0", c >= 0.70, A.club)
	if c0 then
		burst(k, ground(k, c0) + UP * 0.3, c, 0.70, VIOLET, 1.8, 0.35)
		fissure(k, F.S, c0, T.home, c, 0.70, HIT, VIOLET, 0.3, 5)
	end
	if c >= HIT and c <= HIT + 0.5 then -- rock bursts up under it
		local u = (c - HIT) / 0.5
		local rnd = Random.new(9)
		for i = 0, 6 do
			local d = Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)).Unit * rnd:NextNumber(0.5, 2.2)
			local z = (5 * u - 6 * u * u) * rnd:NextNumber(0.6, 1.2)
			local r = rnd:NextNumber(0.35, 0.6)
			if z > -0.2 then
				rock(k, ground(k, T.home) + d * (1 + u) + UP * z, r, u * 6 + i, VIOLET)
			end
		end
	end
	burst(k, T.chest, c, HIT, VIOLET, 2.0)
end

FX.foe_mage_forge = function(k, c, A, F) -- Hex Bolt
	local T = F.targets[1]
	charge(k, A.hand, c, 0, 0.72, HEX, 1.0)
	local h0 = keep(F, "hand0", c >= 0.72, A.hand)
	bolt(k, h0 or A.hand, T.chest, c, 0.72, HIT, HEX, 1.1)
	if c >= HIT and c <= HIT + 0.35 then -- an implosion: dark, pulled in, then a flash
		local u = (c - HIT) / 0.35
		sphere(k, T.chest, 2.4 - 2.0 * u, Color3.fromRGB(40, 10, 70), 1.0, 0.6 * (1 - u))
		ring(k, T.chest, 3.0 - 2.4 * u, 0.12, HEX, 7, 1 - u)
	end
	burst(k, T.chest, c, HIT + 0.12, HEX, 1.8)
end

local SLASHES = { { 0.40, "bl", 0.6 }, { 0.54, "br", -0.6 }, { 0.68, "bl", 0.0 } }

FX.foe_knight_berserker_forge = function(k, c, A, F) -- Frenzy
	local T = F.targets[1]
	charge(k, A.bl, c, 0, 0.25, CRIMSON, 0.5)
	charge(k, A.br, c, 0, 0.25, CRIMSON, 0.5)
	for i, s in SLASHES do
		local t0, tilt = s[1] :: number, s[3] :: number
		local p0 = keep(F, `s{i}`, c >= t0, A[s[2] :: string])
		local t1 = if i < 3 then t0 + 0.22 else HIT
		if p0 and c <= t1 then
			local p = fly(p0, T.chest, c, t0, t1)
			crescent(k, p, T.chest - p0, F.left * tilt + UP, (if i < 3 then 1.8 else 2.6), 0.4, CRIMSON)
			if i == 3 then -- the last, both blades crossed
				crescent(k, p, T.chest - p0, F.left * -0.7 + UP, 2.6, 0.4, CRIMSON)
			end
		end
		burst(k, T.chest, c, t1, CRIMSON, if i < 3 then 1.2 else 2.4, 0.3, i)
	end
end

FX.foe_mage_priest_forge = function(k, c, A, F) -- Benediction
	local T = F.targets[1]
	charge(k, A.staff, c, 0, 0.62, GOLD, 1.0)
	if c >= 0.62 and c <= 0.8 then -- a column of light up from the staff
		streak(k, A.staff, A.staff + UP * 30, 0.25, 0.6, GOLD, 7, 0.7 * (1 - grow(c, 0.7, 0.8)))
	end
	local healed = if #F.allies > 0 then F.allies else { F.me }
	for i, e in healed do
		pillar(k, e.home, c, 0.74, HIT, GOLD, 0.8, 22, 0.22)
		if c >= HIT then
			local u = grow(c, HIT, HIT + 0.6)
			ring(k, e.home, 0.8 + 2.4 * u, 0.1, GOLD, 7, 1 - u)
			local rnd = Random.new(i)
			for _ = 1, 10 do -- motes rising round it
				local a = rnd:NextNumber(0, TAU)
				local rr = rnd:NextNumber(0.6, 1.2) * e.w * 0.6
				local z = (rnd:NextNumber(0, 0.4) + (c - HIT) * 1.6) * e.h
				if z < e.h * 1.3 then
					local q = ground(k, e.home) + Vector3.new(math.cos(a + c) * rr, z, math.sin(a + c) * rr)
					sphere(k, q, 0.18, GOLD, 9, 1 - u)
				end
			end
			if c <= HIT + 0.6 then
				sphere(k, ground(k, e.home) + UP * e.h * 0.5, math.max(e.w, e.h) * 0.62, GOLD, 2.0, 0.035 * (1 - u))
			end
		end
	end
	local s0 = keep(F, "staff0", c >= 0.8, A.staff)
	bolt(k, s0 or A.staff, T.chest, c, 0.80, HIT, BOLT, 0.7)
	burst(k, T.chest, c, HIT, BOLT, 1.4)
end

FX.foe_archer_crossbow_forge = function(k, c, A, F) -- Marked Shot
	local T = F.targets[1]
	if c <= 0.9 then -- its aim, on its target, the whole wind-up
		local a = 0.35 + 0.5 * grow(c, 0, 0.35)
		local pulse = 0.75 + 0.25 * math.sin(c * 30)
		streak(k, A.bow, T.chest, 0.035, 0.035, RED, 8, a * pulse)
		ring(k, T.home, 2.2 - 0.6 * grow(c, 0, 0.86), 0.08, RED, 8, a)
		ring(k, T.home, 1.2 - 0.3 * grow(c, 0, 0.86), 0.05, RED, 8, a)
	end
	charge(k, A.bow, c, 0.35, 0.86, VIOLET, 0.45)
	local b0 = keep(F, "bow0", c >= 0.86, A.bow)
	if b0 and c <= HIT then
		local p = fly(b0, T.chest, c, 0.86, HIT)
		streak(k, b0:Lerp(p, 0.4), p, 0.02, 0.3, VIOLET, 9, 1)
		glow(k, p, 0.4, VIOLET)
	end
	burst(k, T.chest, c, HIT, VIOLET, 1.8)
end

FX.foe_cavalry_forge = function(k, c, A, F) -- Lance Charge
	local T = F.targets[1]
	charge(k, A.lance, c, 0, 0.6, VIOLET, 0.8)
	local l0 = keep(F, "lance0", c >= 0.70, A.lance)
	if l0 and c <= HIT then
		local p = fly(l0, T.chest, c, 0.70, HIT)
		local d = (T.chest - l0).Unit
		streak(k, p - d * 6, p, 0.05, 0.4, VIOLET, 6, 0.8)
		glow(k, p, 0.6, VIOLET)
		local rnd = Random.new(math.floor(c * 100))
		for _ = 1, 5 do -- speed lines
			local o = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1)) * 1.2
			streak(k, p - d * rnd:NextNumber(4, 8) + o, p - d * 1.5 + o, 0.02, 0.03, WHITE, 6, 0.6)
		end
	end
	burst(k, T.chest, c, HIT, VIOLET, 2.2)
end

FX.foe_mage_necromancer_forge = function(k, c, A, F) -- Raise Dead
	local T = F.targets[1]
	charge(k, A.skull, c, 0, 0.62, GREEN, 0.9)
	for i, e in F.allies do -- the fallen it raises
		local rr = math.max(e.w, e.h) * 0.55
		if c >= 0.70 then
			local open = grow(c, 0.70, 0.82) * (1 - grow(c, 1.4, 1.7))
			rune(k, e.home, rr * (0.6 + 0.4 * grow(c, 0.7, 0.82)), c + i, GREEN, open)
			if c >= 0.75 and c <= 1.5 then -- green smoke and light coming up
				local rnd = Random.new(i * 31)
				for _ = 1, 9 do
					local z = ((c - 0.75) * 1.4 + rnd:NextNumber(0, 0.4)) * e.h
					local a = rnd:NextNumber(0, TAU)
					local q = ground(k, e.home) + Vector3.new(math.cos(a) * rr * 0.5, z, math.sin(a) * rr * 0.5)
					sphere(k, q, rnd:NextNumber(0.4, 0.8), GREEN, 3, 0.22 * (1 - grow(c, 1.1, 1.5)))
				end
			end
		end
	end
	local s0 = keep(F, "skull0", c >= 0.74, A.skull)
	bolt(k, s0 or A.skull, T.chest, c, 0.74, HIT, VIOLET, 0.7)
	burst(k, T.chest, c, HIT, VIOLET, 1.4)
end

FX.foe_ogre_commander_forge = function(k, c, A, F) -- Earthsplitter
	local T = F.targets[1]
	charge(k, A.axe, c, 0, 0.6, MAGENTA, 1.1)
	local a0 = keep(F, "axe0", c >= 0.70, A.axe)
	if a0 then
		burst(k, ground(k, a0) + UP * 0.4, c, 0.70, MAGENTA, 2.2, 0.35)
		fissure(k, F.S, a0, T.home - flat(T.home - F.base) * 2, c, 0.70, HIT, MAGENTA, 0.45, 8)
	end
	if c >= HIT and c <= HIT + 0.45 then -- it erupts under its target
		local u = (c - HIT) / 0.45
		local g = ground(k, T.home)
		streak(k, g, g + UP * (2 + 9 * u), 1.6 * (1 - u), 0.3, MAGENTA, 6, 0.8 * (1 - u))
	end
	burst(k, T.chest, c, HIT, MAGENTA, 2.6)
end

FX.foe_knight_shield_commander_forge = function(k, c, A, F) -- Lance of Light
	local T = F.targets[1]
	charge(k, A.shield, c, 0, 0.6, VIOLET, 1.2)
	charge(k, A.sword, c, 0, 0.7, WHITE, 0.6)
	local s0 = keep(F, "sword0", c >= 0.70, A.sword)
	if s0 and c <= HIT + 0.08 then
		local u = grow(c, 0.70, HIT)
		local tip = s0:Lerp(T.chest, u)
		local tail = s0:Lerp(T.chest, math.max(0, u - 0.45))
		streak(k, tail, tip, 0.05, 0.55, VIOLET, 7, 0.85)
		streak(k, tail, tip, 0.02, 0.2, WHITE, 12, 1)
	end
	burst(k, T.chest, c, HIT, VIOLET, 2.4)
end

FX.foe_golem_forge = function(k, c, A, F) -- Siege Barrage
	charge(k, A.castle, c, 0, 0.2, VIOLET, 1.4)
	if c <= 0.6 then -- smoke off its towers
		local rnd = Random.new(4)
		for _ = 1, 6 do
			local o = Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1))
			local z = ((c + 0.8) * 0.9 + rnd:NextNumber(0, 1)) % 1.4
			sphere(k, A.castle + o + UP * z * 3, 0.5 + z, Color3.fromRGB(60, 55, 70), 0.2, 0.3 * (1 - z / 1.4))
		end
	end
	for i, T in F.targets do -- a boulder for each
		local t0, t1 = 0.20 + 0.1 * (i - 1), 0.86 + 0.03 * (i - 1)
		local c0 = keep(F, `c{i}`, c >= t0, A.castle)
		if c0 then
			burst(k, c0, c, t0, VIOLET, 1.2, 0.2, i)
			if c <= t1 then
				local p, q = fly(c0, ground(k, T.home) + UP * 0.6, c, t0, t1, 14)
				rock(k, p, 0.9, c * 8 + i, VIOLET)
				glow(k, p, 1.2, VIOLET, 0.6)
				streak(k, q, p, 0.1, 0.8, VIOLET, 5, 0.5)
			end
		end
		burst(k, T.chest, c, t1, VIOLET, 2.2, 0.4, i)
	end
	if c >= HIT then -- its fists hit the ground as the barrage lands
		burst(k, ground(k, A.fl) + UP * 0.3, c, HIT, VIOLET, 1.6, 0.35)
		burst(k, ground(k, A.fr) + UP * 0.3, c, HIT, VIOLET, 1.6, 0.35)
	end
end

FX.foe_cavalry_commander_forge = function(k, c, A, F) -- Royal Charge
	local T = F.targets[1]
	charge(k, A.sword, c, 0, 0.6, VIOLET, 0.9)
	local made: { Model }? = F.S.ghosts
	if made == nil and c >= 0.62 then
		made = ghosts(k, F.model, F.S.bones, 3)
		F.S.ghosts, F.S.from = made, F.model:GetPivot()
	end
	if made then -- three ghost riders charge in, one after another
		local dir = flat(T.home - F.base)
		local dist = math.max(0, (ground(k, T.home) - F.base).Magnitude - T.r - F.size.Z * 0.45)
		for i, g in made do
			local t0, t1 = 0.62 + 0.06 * (i - 1), 0.86 + 0.03 * (i - 1)
			local on = c >= t0 and c <= t1 + 0.1
			if on then
				g:PivotTo(CFrame.new(dir * dist * grow(c, t0, t1)) * F.S.from)
			end
			g.Parent = if on then k.folder else nil
		end
	end
	if c >= 0.86 and c <= HIT + 0.1 then
		local dir = flat(T.home - F.base)
		crescent(k, T.chest - dir * 1.2, dir, F.left + UP * 0.6, 3.4, 0.6, VIOLET, 1 - grow(c, HIT, HIT + 0.1))
	end
	burst(k, T.chest, c, HIT, VIOLET, 2.6)
end

FX.foe_dragon_drake_forge = function(k, c, A, F) -- Shadow Volley (a fireball at each; all land by the hit)
	charge(k, A.mouth, c, 0, 0.5, HEX, 0.9)
	for i, T in F.targets do
		local t0, t1 = 0.50 + 0.06 * (i - 1), 0.86 + 0.02 * (i - 1)
		local m0 = keep(F, `m{i}`, c >= t0, A.mouth)
		bolt(k, m0 or A.mouth, T.chest, c, t0, t1, HEX, 1.1, 2.5)
		burst(k, T.chest, c, t1, HEX, 2.0, 0.4, i)
	end
end

FX.foe_dragon_forge = function(k, c, A, F) -- Eclipse Pounce
	if c <= 0.6 then -- a dark mantle swirling round it
		local rr = F.size.X * 0.32
		for i = 0, 7 do
			local a = c * 3 + i * TAU / 8
			local q = F.base
				+ F.left * math.cos(a) * rr
				- F.fwd * (math.sin(a) * rr * 0.7 - F.size.Z * 0.1)
				+ UP * (0.3 + 0.15 * math.sin(a * 2)) * F.size.Y
			sphere(k, q, 1.4, Color3.fromRGB(50, 15, 90), 1.5, 0.3)
		end
	end
	charge(k, A.mouth, c, 0, 0.6, HEX, 0.9)
	local p = keep(F, "land", c >= 0.80, ground(k, A.mouth))
	if p then -- a shockwave from where it lands, out to every animal
		local u = grow(c, 0.80, 1.30)
		sphere(k, p, 2 + 7 * u, Color3.fromRGB(40, 10, 80), 1.2, 0.45 * (1 - u))
		local far = 0
		for _, T in F.targets do
			far = math.max(far, (ground(k, T.home) - p).Magnitude)
		end
		local reach = if c <= HIT then far * grow(c, 0.80, HIT) else far * (1 + 0.5 * grow(c, HIT, HIT + 0.3))
		local fade = 1 - grow(c, HIT, HIT + 0.3)
		ring(k, p, reach, 0.35, HEX, 7, fade)
		ring(k, p, reach * 0.93, 0.15, WHITE, 10, fade)
		disc(k, p, reach, HEX, 1.5, 0.12 * fade)
	end
	for i, T in F.targets do
		burst(k, T.chest, c, HIT, HEX, 1.8, 0.4, i)
	end
end

FX.foe_dragon_alpha_forge = function(k, c, A, F) -- Ancient Flame
	charge(k, A.mouth, c, 0, 0.78, MAGENTA, 1.6)
	local struck: { [number]: number } = F.S.struck or {}
	F.S.struck = struck
	if c >= 0.78 and c <= 1.12 then
		local m = A.mouth
		local d = flat(m - A.head_bone)
		local T1 = F.targets[1]
		local along_ = d:Dot(F.fwd) -- the torrent reaches the row the team stands in
		local s = if math.abs(along_) > 1e-4 then (T1.home - m):Dot(F.fwd) / along_ else 0
		local e = m + d * s
		local fin = Vector3.new(e.X, k.floor + (T1.chest.Y - k.floor) * 0.8, e.Z)
		local u = grow(c, 0.78, 0.84) * (1 - grow(c, 1.06, 1.12))
		local tip = m:Lerp(fin, u)
		local rnd = Random.new(math.floor(c * 200))
		for i = 0, 30 do -- billows widening out from the maw, white-hot at its heart
			local f = i / 30
			local q = m:Lerp(tip, f)
				+ Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.6, 1), rnd:NextNumber(-1, 1)) * f * 1.6
			local r = (0.9 + 4.2 * f * u) * rnd:NextNumber(0.8, 1.2)
			sphere(k, q, r, MAGENTA, 4, 0.22)
			sphere(k, q, r * 0.55, Color3.fromRGB(255, 120, 240), 6, 0.35)
			if f * u < 0.6 then
				sphere(k, q, r * 0.3, Color3.fromRGB(255, 225, 250), 10, 0.8)
			end
		end
		for _ = 1, 10 do -- embers thrown off it
			local f = rnd:NextNumber(0.2, 1.0)
			local o = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(0, 1.5), rnd:NextNumber(-1, 1))
			sphere(k, m:Lerp(tip, f) + o * (1 + 3 * f), 0.15, Color3.fromRGB(255, 160, 240), 12, 1)
		end
		if u > 0.9 then
			sparks(k, ground(k, fin) + UP * 0.5, c, c - 0.1, MAGENTA, 8, 2.5, 0.3, math.floor(c * 50))
			for i, T in F.targets do -- struck as the torrent passes
				if struck[i] == nil and math.abs((T.home - fin):Dot(F.left)) < T.r + 1.5 then
					struck[i] = c
				end
			end
		end
	end
	for i, at in struck do -- and scorched there
		local T = F.targets[i]
		if T then
			disc(k, T.home, T.r * 1.3, Color3.fromRGB(60, 10, 50), 0.5, 0.5 * (1 - grow(c, at + 0.6, at + 1.2)))
		end
	end
end

-- The moves that reach the whole team aim at four when nothing names who (a model shown on its own).
local ALL = {
	foe_golem_forge = true,
	foe_dragon_drake_forge = true,
	foe_dragon_forge = true,
	foe_dragon_alpha_forge = true,
}

-- Casting -----------------------------------------------------------------------------------------------------------

type Cast = { at: number, kit: Kit, S: { [string]: any }, aim: { Model }?, allies: { Model }? }
local casts: { [Model]: Cast } = {}
local warned: { [string]: boolean } = {}

local function spot(home: Vector3, w: number, h: number): Spot
	return { home = home, chest = home + UP * h * 0.55, r = math.max(w, h) * 0.5, h = h, w = w }
end

local function spotOf(model: Model): Spot?
	local hit = model:FindFirstChild("Hit") :: BasePart?
	if hit == nil then
		return nil
	end
	return spot(hit.CFrame.Position - UP * hit.Size.Y / 2, hit.Size.X, hit.Size.Y) -- (CFrame: Lune's parts lack Position)
end

-- the models in `model`'s show named by its attribute `name` (slots), on its own side or the other
local function named(model: Model, name: string, own: boolean): { Model }?
	local list, parent = model:GetAttribute(name), model.Parent
	if type(list) ~= "string" or parent == nil then
		return nil
	end
	local side, out = model:GetAttribute("Side"), {}
	for n in string.gmatch(list, "%d+") do
		for _, m in parent:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Slot") == tonumber(n) and (m:GetAttribute("Side") == side) == own then
				table.insert(out, m)
				break
			end
		end
	end
	return out
end

-- An enemy whose power move is drawn here (its shared charge and slam are not).
function FoePowers.has(model: Model): boolean
	return FX[(model:GetAttribute("Asset") :: string?) or ""] ~= nil
end

function FoePowers.stop(model: Model)
	local cast = casts[model]
	if cast then
		casts[model] = nil
		cast.kit.folder:Destroy()
	end
end

-- Draws `model`'s power move `t` seconds into the "magic" clip that started at `at` (and clears it once that is over).
function FoePowers.step(model: Model, bones: Bones, anim: string?, at: number, t: number)
	local asset = (model:GetAttribute("Asset") :: string?) or ""
	local fx = FX[asset]
	local root, me = model.PrimaryPart, spotOf(model)
	if anim ~= "magic" or fx == nil or t >= LAST or root == nil or me == nil then
		FoePowers.stop(model)
		return
	end
	local cast = casts[model]
	if cast == nil or cast.at ~= at then
		FoePowers.stop(model)
		cast = { at = at, kit = newKit(me.home.Y), S = { bones = bones } }
		casts[model] = cast
	end
	local c = cast :: Cast
	local k = c.kit
	-- who it reaches (named once both are here), else four, or one, ahead of it
	c.aim = c.aim or named(model, "PowerAim", false)
	c.allies = c.allies or named(model, "PowerAllies", true)
	local cf = root.CFrame
	local fwd = flat(cf.LookVector)
	local left = UP:Cross(fwd)
	local F: Frame = {
		model = model,
		S = c.S,
		base = me.home,
		fwd = fwd,
		left = left,
		size = model:GetExtentsSize(),
		me = me,
		targets = {},
		allies = {},
	}
	for _, m in c.aim or {} do
		table.insert(F.targets, spotOf(m))
	end
	if #F.targets == 0 then
		local ahead = me.home + fwd * (F.size.Z / 2 + 18)
		local n = if ALL[asset] then 4 else 1
		for i = 1, n do
			table.insert(F.targets, spot(ahead + left * (i - (n + 1) / 2) * 9, 5, 5))
		end
	end
	for _, m in c.allies or {} do
		table.insert(F.allies, spotOf(m))
	end
	-- where each anchor is now: its rest offset (Root axes) carried by its bone as posed. A bone's `turn` is its rest
	-- frame in the Root's (Creatures.client takes it before any pose); its WorldCFrame will not do, as that already
	-- holds its parents' poses. Sizes are over the built size (GetScale also holds the importer's unit).
	local A: Anchors = {}
	local built = StationAssets[asset]
	local size, rot = if built then me.h / built.size[2] else 1, cf.Rotation
	for name, a in FoeAnchors[asset] or {} do
		local v = a[2] :: { number }
		local off = Vector3.new(v[1], v[2], v[3]) * size
		local b = bones[a[1]]
		local key = `bone {a[1]}`
		if b == nil and c.S[key] == nil then -- a bone no pose moves (a weapon's "tip"): found once
			c.S[key] = model:FindFirstChild(a[1], true) or false
		end
		if b then
			local now = b.bone.TransformedWorldCFrame
			A[name] = now.Position + now.Rotation * (b.turn:Inverse() * off)
		elseif c.S[key] then -- (as it stands: its offset is none)
			A[name] = (c.S[key] :: Bone).TransformedWorldCFrame.Position + rot * off
		else
			A[name] = me.chest
		end
	end
	local head = bones.head
	A.head_bone = if head then head.bone.TransformedWorldCFrame.Position else me.chest
	begin(k)
	local ok, err = pcall(fx, k, t, A, F)
	if not ok and not warned[asset] then
		warned[asset] = true
		warn(`[FoePowers] {asset}: {err}`)
	end
	finish(k)
end

return FoePowers
