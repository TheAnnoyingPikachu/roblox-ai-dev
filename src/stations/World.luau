--!strict
-- Animal Stations world (STATION-003, STATION-004): the central plaza with the hatchery fountain
-- and the egg market, the station zones (Healing Spring S, and on the diagonals Speed Track NW, Strength Gym NE, Swim
-- Pool SW, Magic Library SE), three home ranches (one per player), each on its own hill far out along the north, east and west roads,
-- paths with lamps, trees, flowers and the hill ring. Built once from parts, Roblox materials and
-- terrain. Display only: no game rules live here. Slots, spots and nests are tagged for the server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationConfig"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local World = {}

World.PLAZA = 48 -- plaza radius
World.STATION_DIST = 130 -- plaza centre to each station centre
World.SPAWN = Vector3.new(0, 0.6, 76)
World.SLOTS = 8 -- work slots per station (placeholder count; the rules decide later)
World.RANCHES = 3 -- one home ranch per player; lobbies (servers) hold 3 players to match
World.RANCH_DIST = 400 -- plaza centre to each ranch centre: far out, so the hub has room to grow
World.RANCH_Y = 22 -- each ranch sits on its own hilltop this high
local HILL = 75 -- hilltop radius
local RAMP = 90 -- length of the road ramp up each hill
World.RANCH_HALF = 38 -- half the fenced ranch square
World.RANCH_SPOTS = 8 -- places in the paddock where owned animals will idle
-- One ranch at the end of each of the north, east and west roads (south is the welcome walk).
local RANCH_ANGLE = { -90, 0, 180 }

local M = Enum.Material
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(45, 40, 55)
local STONE = Color3.fromRGB(226, 214, 190)
local STONE_DARK = Color3.fromRGB(190, 176, 150)
local PATH = Color3.fromRGB(214, 196, 160)
local WOOD = Color3.fromRGB(170, 118, 72)
local WOOD_DARK = Color3.fromRGB(112, 76, 48)
local BARK = Color3.fromRGB(96, 66, 44)
local LEAVES = { Color3.fromRGB(96, 180, 80), Color3.fromRGB(120, 196, 90), Color3.fromRGB(80, 160, 90) }
local FLOWERS = {
	Color3.fromRGB(255, 140, 185),
	Color3.fromRGB(255, 225, 100),
	Color3.fromRGB(185, 150, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 160, 110),
	Color3.fromRGB(140, 200, 255),
}
local WARM = Color3.fromRGB(255, 210, 150)

-- Station look: stat colour, position on the diagonal, display title.
local STAT_COLOUR: { [string]: Color3 } = {
	speed = Color3.fromRGB(255, 160, 40),
	health = Color3.fromRGB(70, 200, 120),
	strength = Color3.fromRGB(235, 70, 70),
	stamina = Color3.fromRGB(50, 150, 255),
	mana = Color3.fromRGB(160, 90, 240),
}
local STATION_ANGLE: { [string]: number } = { track = -135, gym = -45, pool = 135, library = 45, spring = 90 }
local EGG_LOOK: { [string]: { body: Color3, spot: Color3 } } = {
	meadow = { body = Color3.fromRGB(250, 240, 200), spot = Color3.fromRGB(130, 210, 110) },
	wild = { body = Color3.fromRGB(150, 210, 120), spot = Color3.fromRGB(110, 80, 50) },
	safari = { body = Color3.fromRGB(245, 200, 110), spot = Color3.fromRGB(70, 50, 35) },
}

local function rad(d: number): number
	return math.rad(d)
end

local function stationPos(id: string): Vector3
	local a = rad(STATION_ANGLE[id])
	return Vector3.new(math.cos(a), 0, math.sin(a)) * World.STATION_DIST
end

-- A flat disc lying on the ground, centre at `pos` (y = top surface).
local function disc(
	parent: Instance,
	pos: Vector3,
	diameter: number,
	height: number,
	colour: Color3,
	mat: Enum.Material?
): Part
	local p = part(
		parent,
		Vector3.new(height, diameter, diameter),
		CFrame.new(pos - Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, rad(90)),
		colour,
		mat
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, pos: Vector3, d: number, colour: Color3, mat: Enum.Material?): Part
	local p = part(parent, Vector3.new(d, d, d), pos, colour, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A horizontal bar between two points (cylinder).
local function bar(parent: Instance, a: Vector3, b: Vector3, r: number, colour: Color3, mat: Enum.Material?): Part
	local len = (b - a).Magnitude
	local p = part(
		parent,
		Vector3.new(len, r * 2, r * 2),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0),
		colour,
		mat
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A flat strip from a to b on the ground (y of a/b = top surface).
local function strip(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	colour: Color3,
	mat: Enum.Material?
): Part
	local len = (b - a).Magnitude
	return part(
		parent,
		Vector3.new(width, height, len),
		CFrame.lookAt((a + b) / 2 - Vector3.new(0, height / 2, 0), b - Vector3.new(0, height / 2, 0)),
		colour,
		mat
	)
end

local function glow(p: BasePart, colour: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = colour, range, brightness, false
	l.Parent = p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A sign board on two posts facing along `cf`'s look vector, text on both faces.
local function signboard(parent: Instance, cf: CFrame, width: number, text: string, colour: Color3, postHeight: number?)
	local h = postHeight or 9
	for _, dx in { -width / 2 + 0.6, width / 2 - 0.6 } do
		local base = (cf * CFrame.new(dx, 0, 0)).Position
		pillar(parent, base, h + 1.5, 0.45, WOOD_DARK, M.Wood)
	end
	local board = part(parent, Vector3.new(width, 3.4, 0.6), cf * CFrame.new(0, h, 0), colour, M.SmoothPlastic)
	part(parent, Vector3.new(width + 0.6, 0.4, 0.8), cf * CFrame.new(0, h + 1.9, 0), WOOD_DARK, M.Wood)
	part(parent, Vector3.new(width + 0.6, 0.4, 0.8), cf * CFrame.new(0, h - 1.9, 0), WOOD_DARK, M.Wood)
	label(board, text, WHITE)
end

-- Lamp post with a warm glowing head.
local function lamp(parent: Instance, base: Vector3)
	part(parent, Vector3.new(1.6, 0.6, 1.6), base + Vector3.new(0, 0.3, 0), INK, M.Metal)
	pillar(parent, base, 10, 0.25, INK, M.Metal)
	local head = part(parent, Vector3.new(1.4, 1.6, 1.4), base + Vector3.new(0, 10.6, 0), WARM, M.Neon)
	part(parent, Vector3.new(2, 0.4, 2), base + Vector3.new(0, 11.6, 0), INK, M.Metal)
	glow(head, WARM, 18, 1.2)
end

-- Round cartoon tree: trunk plus two or three leaf balls.
local function tree(parent: Instance, base: Vector3, rng: Random, scale: number)
	local h = rng:NextNumber(7, 10) * scale
	pillar(parent, base, h, 0.9 * scale, BARK, M.Wood)
	local leaf = LEAVES[rng:NextInteger(1, #LEAVES)]
	ball(parent, base + Vector3.new(0, h + 2.5 * scale, 0), 9 * scale, leaf, M.SmoothPlastic)
	for _ = 1, rng:NextInteger(1, 2) do
		local off = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 2), rng:NextNumber(-3, 3)) * scale
		ball(
			parent,
			base + Vector3.new(0, h + 2 * scale, 0) + off,
			rng:NextNumber(5, 7) * scale,
			leaf:Lerp(WHITE, 0.08),
			M.SmoothPlastic
		)
	end
end

local function flowers(parent: Instance, centre: Vector3, rng: Random, n: number, spread: number)
	for _ = 1, n do
		local p = centre + Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread))
		pillar(parent, p, 0.8, 0.08, Color3.fromRGB(70, 140, 60))
		ball(parent, p + Vector3.new(0, 0.9, 0), 0.7, FLOWERS[rng:NextInteger(1, #FLOWERS)])
	end
end

local function bench(parent: Instance, cf: CFrame)
	part(parent, Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.6, 0), WOOD, M.Wood)
	part(parent, Vector3.new(6, 1.4, 0.3), cf * CFrame.new(0, 2.6, 0.85), WOOD, M.Wood)
	for _, dx in { -2.5, 2.5 } do
		part(parent, Vector3.new(0.4, 1.6, 1.6), cf * CFrame.new(dx, 0.8, 0), INK, M.Metal)
	end
end

-- An egg: a stretched sphere with a few spots, standing with its bottom at `base`.
local function egg(parent: Instance, base: Vector3, h: number, body: Color3, spot: Color3, rng: Random): Part
	local e = part(parent, Vector3.new(h * 0.75, h, h * 0.75), base + Vector3.new(0, h / 2, 0), body, M.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = e
	for _ = 1, 7 do
		local a, y = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.3)
		local rr = h * 0.375 * math.sqrt(1 - (y * 2) ^ 2) * 0.97
		local p = base + Vector3.new(math.cos(a) * rr, h / 2 + y * h, math.sin(a) * rr)
		ball(parent, p, h * 0.16, spot)
	end
	return e
end

-- A work slot: a coloured pad an animal will stand on, tagged "StationSlot".
local function slot(parent: Instance, pos: Vector3, colour: Color3, station: string, index: number)
	disc(parent, pos + Vector3.new(0, 0.15, 0), 4.8, 0.5, WHITE, M.SmoothPlastic)
	local pad = disc(parent, pos + Vector3.new(0, 0.3, 0), 4.2, 0.5, colour, M.SmoothPlastic)
	pad.Name = `Slot{index}`
	pad:SetAttribute("Station", station)
	pad:SetAttribute("Index", index)
	CollectionService:AddTag(pad, "StationSlot")
end

-- Lighting and sky ---------------------------------------------------------------------------------

local function effect(className: string, props: { [string]: any })
	local e = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = Lighting
end

local function lighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 110, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.28,
		Offset = 0.1,
		Color = Color3.fromRGB(200, 225, 255),
		Decay = Color3.fromRGB(120, 160, 210),
		Glare = 0.2,
		Haze = 1.2,
	})
	effect("BloomEffect", { Intensity = 0.25, Size = 20, Threshold = 2.2 })
	effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.7 })
	effect("ColorCorrectionEffect", { Saturation = 0.12, Contrast = 0.05, Brightness = 0.02 })
end

local function terrain()
	local t = Workspace.Terrain
	t:Clear() -- a rebuild must not keep the old hills
	-- voxels snap up: a block whose top is at y = -2 gives a surface at y = 0 (checked in Studio)
	t:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1500, 12, 1500), M.Grass)
	local clouds = t:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Color = 0.45, 0.6, WHITE
	clouds.Parent = t
	-- one flat-topped hill per ranch, with a lower terrace round it
	for _, angle in RANCH_ANGLE do
		local c = Vector3.new(math.cos(rad(angle)), 0, math.sin(rad(angle))) * World.RANCH_DIST
		local top = World.RANCH_Y - 4 -- measured in Studio: a cylinder top at 18 gives a surface at 22
		t:FillCylinder(CFrame.new(c + Vector3.new(0, (top - 10) / 2, 0)), top + 10, HILL, M.Grass)
		t:FillCylinder(CFrame.new(c + Vector3.new(0, (top / 2 - 10) / 2, 0)), top / 2 + 10, HILL + 14, M.Grass)
	end
	-- rolling hill ring that closes the hub in
	local rng = Random.new(11)
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = rng:NextNumber(540, 600)
		local size = rng:NextNumber(70, 120)
		t:FillBall(Vector3.new(math.cos(a) * r, -size * 0.45, math.sin(a) * r), size, M.Grass)
	end
end

-- Plaza ----------------------------------------------------------------------------------------------

local function plaza(root: Instance, rng: Random)
	local f = folder(root, "Plaza")
	local R = World.PLAZA
	disc(f, Vector3.new(0, 0.4, 0), R * 2 + 4, 0.6, STONE_DARK, M.Pavement)
	disc(f, Vector3.new(0, 0.5, 0), R * 2, 0.6, STONE, M.Pavement)
	disc(f, Vector3.new(0, 0.55, 0), 62, 0.6, Color3.fromRGB(236, 226, 205), M.Pavement)
	-- coloured inlay ring: one quarter per stat, pointing at its station
	for id, angle in STATION_ANGLE do
		local st = StationConfig.station(id) :: StationConfig.Station
		for k = -3, 3 do
			local a = rad(angle + k * 7)
			local p = Vector3.new(math.cos(a), 0, math.sin(a)) * 36
			part(
				f,
				Vector3.new(3.6, 0.2, 4.4),
				CFrame.lookAt(p + Vector3.new(0, 0.6, 0), Vector3.new(0, 0.6, 0)),
				STAT_COLOUR[st.stat],
				M.SmoothPlastic
			)
		end
	end

	-- Hatchery fountain: basin, water, pedestal and the great egg
	local h = folder(f, "Hatchery")
	disc(h, Vector3.new(0, 1.2, 0), 30, 1, STONE_DARK, M.Marble)
	for i = 0, 27 do -- basin rim ring, so the water shows inside it
		local a = i / 28 * math.pi * 2
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * 14.2
		part(
			h,
			Vector3.new(3.4, 2, 1.8),
			CFrame.lookAt(p + Vector3.new(0, 2, 0), Vector3.new(0, 2, 0)),
			STONE_DARK,
			M.Marble
		)
	end
	local water = disc(h, Vector3.new(0, 2.3, 0), 27, 1.1, Color3.fromRGB(90, 190, 255), M.Glass)
	water.Transparency = 0.2
	water.Reflectance = 0.15
	disc(h, Vector3.new(0, 4.4, 0), 12, 4, STONE, M.Marble)
	disc(h, Vector3.new(0, 5.2, 0), 9, 0.8, Color3.fromRGB(255, 215, 90), M.Metal)
	local great = egg(h, Vector3.new(0, 5.2, 0), 13, Color3.fromRGB(255, 236, 170), Color3.fromRGB(255, 150, 190), rng)
	great.Name = "GreatEgg"
	glow(great, Color3.fromRGB(255, 225, 160), 22, 0.7)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate, sparkle.Lifetime = 6, NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.6)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
	sparkle.LightEmission = 1
	sparkle.Parent = great
	-- four little spouts around the pedestal
	for i = 0, 3 do
		local a = rad(i * 90 + 45)
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * 9.5
		ball(h, p + Vector3.new(0, 2.6, 0), 1.6, STONE, M.Marble)
	end

	-- Egg market on the north arc: one stand per egg, cheapest on the left as you look north.
	local mk = folder(f, "EggMarket")
	for i, e in StationConfig.EGGS do
		local a = rad(-90 + (i - 2) * 32)
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * 34
		local cf = CFrame.lookAt(p + Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 0))
		local stand = folder(mk, e.id)
		-- base and posts
		part(stand, Vector3.new(12, 1, 10), cf * CFrame.new(0, 0.5, 0), WOOD, M.WoodPlanks)
		for _, c in
			{
				Vector3.new(-5.4, 0, -4.4),
				Vector3.new(5.4, 0, -4.4),
				Vector3.new(-5.4, 0, 4.4),
				Vector3.new(5.4, 0, 4.4),
			}
		do
			pillar(stand, (cf * CFrame.new(c + Vector3.new(0, 1, 0))).Position, 10, 0.35, WOOD_DARK, M.Wood)
		end
		-- striped awning in the egg's colours
		local look = EGG_LOOK[e.id]
		for s = 0, 5 do
			local col = if s % 2 == 0 then look.body else look.spot
			part(
				stand,
				Vector3.new(2.2, 0.4, 11.6),
				cf * CFrame.new(-5.5 + s * 2.2, 11.4, 0) * CFrame.Angles(rad(-10), 0, 0),
				col,
				M.Fabric
			)
		end
		-- counter, cushion and the egg
		part(stand, Vector3.new(10, 3, 2), cf * CFrame.new(0, 2.5, -3.6), WOOD_DARK, M.Wood)
		part(stand, Vector3.new(10.4, 0.4, 2.4), cf * CFrame.new(0, 4.1, -3.6), WOOD, M.Wood)
		disc(stand, (cf * CFrame.new(0, 2.2, 1)).Position, 5, 1.2, Color3.fromRGB(200, 60, 90), M.Fabric)
		egg(stand, (cf * CFrame.new(0, 2.2, 1)).Position, 6, look.body, look.spot, rng)
		-- name and price board above the counter, facing the plaza
		local board = part(
			stand,
			Vector3.new(10, 2.6, 0.4),
			cf * CFrame.new(0, 9, -4.8),
			look.body:Lerp(INK, 0.55),
			M.SmoothPlastic
		)
		label(board, `{e.name}  {e.price} coins`, WHITE)
		local spot = part(stand, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 10.6, 1), WARM, M.Neon)
		glow(spot, WARM, 12, 1)
	end

	-- benches and planters around the rim, skipping the market and the four path mouths
	for i = 0, 15 do
		local deg = i * 22.5 + 11.25
		local onPath = false
		for _, pa in STATION_ANGLE do
			local d = math.abs(((deg - pa + 180) % 360) - 180)
			onPath = onPath or d < 14
		end
		local nearMarket = math.abs(((deg + 90 + 180) % 360) - 180) < 50
		local south = math.abs(((deg - 90 + 180) % 360) - 180) < 14
		if not onPath and not nearMarket and not south then
			local a = rad(deg)
			local p = Vector3.new(math.cos(a), 0, math.sin(a)) * (R - 4)
			bench(f, CFrame.lookAt(p + Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 0)))
			local q = Vector3.new(math.cos(a + 0.12), 0, math.sin(a + 0.12)) * (R - 4)
			disc(f, q + Vector3.new(0, 1.8, 0), 3.4, 1.4, STONE_DARK, M.Brick)
			flowers(f, q + Vector3.new(0, 1.6, 0), rng, 6, 1)
		end
	end
	-- lamps on the plaza rim
	for i = 0, 7 do
		local a = rad(i * 45 + 22.5)
		lamp(f, Vector3.new(math.cos(a), 0, math.sin(a)) * (R - 1) + Vector3.new(0, 0.5, 0))
	end
end

-- Paths ----------------------------------------------------------------------------------------------

-- Every road as a segment {a, b}; scenery keeps clear of these. A ranch road runs flat, climbs
-- a ramp to the hilltop, then runs flat to the gate.
local function roadSegments(): { { Vector3 } }
	local segs = {}
	for _, angle in STATION_ANGLE do
		local d = Vector3.new(math.cos(rad(angle)), 0, math.sin(rad(angle)))
		table.insert(segs, { d * (World.PLAZA - 2), d * (World.STATION_DIST - 40) })
	end
	for _, angle in RANCH_ANGLE do
		local d = Vector3.new(math.cos(rad(angle)), 0, math.sin(rad(angle)))
		local up = Vector3.new(0, World.RANCH_Y, 0)
		local top = World.RANCH_DIST - HILL + 3
		table.insert(segs, { d * (World.PLAZA - 2), d * (top - RAMP) })
		table.insert(segs, { d * (top - RAMP), d * top + up })
		table.insert(segs, { d * top + up, d * (World.RANCH_DIST - World.RANCH_HALF - 2) + up })
	end
	return segs
end
local ROADS = roadSegments()

local function paths(root: Instance)
	local f = folder(root, "Paths")
	for _, seg in ROADS do
		local a, b = seg[1], seg[2]
		strip(f, a + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0), 18, 0.6, STONE_DARK, M.Cobblestone)
		strip(f, a + Vector3.new(0, 0.35, 0), b + Vector3.new(0, 0.35, 0), 15, 0.6, PATH, M.Cobblestone)
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X).Unit
		if a.Y ~= b.Y then
			-- a ramp: an earth wedge under the road (thick end uphill), and no lamps on the slope
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local mid = Vector3.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, (a.Z + b.Z) / 2)
			local w = Instance.new("WedgePart")
			w.Anchored, w.Size = true, Vector3.new(30, math.abs(b.Y - a.Y), flat.Magnitude)
			w.CFrame = CFrame.lookAt(mid, mid - flat)
			w.Color, w.Material = Color3.fromRGB(150, 120, 84), M.Ground
			w.Parent = f
			continue
		end
		for i = 1, math.floor(((b - a).Magnitude - 6) / 22) do -- stop short so no lamp lands inside a gate
			local p = a + dir * (i * 22 - 8)
			lamp(f, p + side * 11)
			lamp(f, p - side * 11)
		end
		disc(f, b + Vector3.new(0, 0.32, 0), 18, 0.6, PATH, M.Cobblestone) -- round off joins and forks
	end
end

-- Stations -------------------------------------------------------------------------------------------

-- Local frame of a station: origin at its centre, -Z (look) points back at the plaza.
local function frame(id: string): CFrame
	local p = stationPos(id)
	return CFrame.lookAt(p, Vector3.zero)
end

-- Shared shell of every station: ground pad, entrance arch with the name, info board, work slots.
local function shell(root: Instance, st: StationConfig.Station): (Folder, CFrame, Color3)
	local f = folder(root, st.id)
	local cf = frame(st.id)
	local col = STAT_COLOUR[st.stat]
	-- entrance arch at the near edge
	local gate = cf * CFrame.new(0, 0, -40)
	for _, dx in { -10, 10 } do
		local base = (gate * CFrame.new(dx, 0, 0)).Position
		part(
			f,
			Vector3.new(3, 14, 3),
			CFrame.new(base + Vector3.new(0, 7, 0)) * gate.Rotation,
			col:Lerp(WHITE, 0.15),
			M.SmoothPlastic
		)
		part(
			f,
			Vector3.new(3.8, 1, 3.8),
			CFrame.new(base + Vector3.new(0, 14.5, 0)) * gate.Rotation,
			WHITE,
			M.SmoothPlastic
		)
		ball(f, base + Vector3.new(0, 15.8, 0), 2.2, col, M.Neon)
	end
	local sign = part(f, Vector3.new(23, 4.2, 1), gate * CFrame.new(0, 12.4, 0), col, M.SmoothPlastic)
	part(f, Vector3.new(24, 0.6, 1.4), gate * CFrame.new(0, 14.8, 0), WHITE, M.SmoothPlastic)
	part(f, Vector3.new(24, 0.6, 1.4), gate * CFrame.new(0, 10, 0), WHITE, M.SmoothPlastic)
	label(sign, string.upper(st.name), WHITE)
	-- info board beside the arch
	signboard(
		f,
		cf * CFrame.new(23, 0, -36) * CFrame.Angles(0, rad(180), 0),
		21,
		`Trains {string.upper(st.stat)}`,
		col:Lerp(INK, 0.35),
		6
	)
	return f, cf, col
end

local function slotsAlong(
	f: Instance,
	cf: CFrame,
	col: Color3,
	st: StationConfig.Station,
	first: Vector3,
	step: Vector3
)
	local sf = folder(f, "Slots")
	for i = 1, World.SLOTS do
		slot(sf, (cf * CFrame.new(first + step * (i - 1))).Position, col, st.id, i)
	end
end

local function track(root: Instance, st: StationConfig.Station, rng: Random)
	local f, cf, col = shell(root, st)
	-- oval running track from short segments
	local A, B, N = 30, 19, 56
	local function at(t: number, grow: number): Vector3
		return (cf * CFrame.new(math.cos(t) * (A + grow), 0, math.sin(t) * (B + grow) + 4)).Position
	end
	for i = 0, N - 1 do
		local t0, t1 = i / N * math.pi * 2, (i + 1) / N * math.pi * 2
		strip(
			f,
			at(t0, 0) + Vector3.new(0, 0.4, 0),
			at(t1, 0) + Vector3.new(0, 0.4, 0) + (at(t1, 0) - at(t0, 0)) * 0.08,
			9,
			0.6,
			Color3.fromRGB(205, 92, 62),
			M.Ground
		)
		for _, g in { -4.6, 0, 4.6 } do
			strip(
				f,
				at(t0, g) + Vector3.new(0, 0.48, 0),
				at(t1, g) + Vector3.new(0, 0.48, 0),
				0.35,
				0.6,
				WHITE,
				M.SmoothPlastic
			)
		end
	end
	-- inner field and the start line
	local field = part(f, Vector3.new(1, 1, 1), cf * CFrame.new(0, 0.15, 4), Color3.fromRGB(120, 200, 95), M.Grass)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Scale = Vector3.new(0.3, (B - 4.6) * 2, (A - 4.6) * 2)
	mesh.Parent = field
	field.CFrame = cf * CFrame.new(0, 0.2, 4) * CFrame.Angles(0, rad(90), rad(90))
	for k = 0, 7 do
		for r = 0, 1 do
			local c = if (k + r) % 2 == 0 then WHITE else INK
			part(
				f,
				Vector3.new(1.1, 0.62, 1.1),
				cf * CFrame.new(A - 4 + k * 1.12, 0.45, 4 + r * 1.12 - 0.56),
				c,
				M.SmoothPlastic
			)
		end
	end
	-- finish arch over the start line
	for _, dz in { -6, 6 } do
		pillar(f, (cf * CFrame.new(A, 0, 4 + dz)).Position, 11, 0.5, WHITE, M.Metal)
	end
	local banner =
		part(f, Vector3.new(13, 2.6, 1), cf * CFrame.new(A, 10, 4) * CFrame.Angles(0, rad(90), 0), col, M.SmoothPlastic)
	label(banner, "FINISH", WHITE)
	-- bleachers along the far straight
	for row = 0, 3 do
		part(f, Vector3.new(36, 1, 3), cf * CFrame.new(0, 0.5 + row * 1.2, 4 + B + 9 + row * 3), STONE, M.Concrete)
		for s = 0, 11 do
			local c = if s % 2 == 0 then col else WHITE
			part(
				f,
				Vector3.new(2.4, 0.4, 1.6),
				cf * CFrame.new(-16.5 + s * 3, 1.2 + row * 1.2, 4 + B + 9 + row * 3),
				c,
				M.SmoothPlastic
			)
		end
	end
	-- pennant flags around the track
	for i = 0, 9 do
		local t = i / 10 * math.pi * 2
		local p = at(t, 9)
		pillar(f, p, 8, 0.15, WHITE, M.Metal)
		local mid = (cf * CFrame.new(0, 0, 4)).Position
		local face = CFrame.lookAt(p + Vector3.new(0, 7, 0), Vector3.new(mid.X, 7, mid.Z))
		part(
			f,
			Vector3.new(2.4, 1.6, 0.15),
			face * CFrame.new(1.2, 0, 0),
			if i % 2 == 0 then col else Color3.fromRGB(255, 230, 90),
			M.SmoothPlastic
		)
	end
	-- starting blocks: the work slots, in the inner field facing the near straight
	slotsAlong(f, cf, col, st, Vector3.new(-17.5, 0.5, -2), Vector3.new(5, 0, 0))
	tree(f, (cf * CFrame.new(-30, 0, -26)).Position, rng, 0.9)
	tree(f, (cf * CFrame.new(30, 0, -26)).Position, rng, 0.9)
end

local function gym(root: Instance, st: StationConfig.Station, rng: Random)
	local f, cf, col = shell(root, st)
	local RUBBER = Color3.fromRGB(60, 60, 68)
	-- raised floor with mat tiles
	part(f, Vector3.new(56, 1.6, 44), cf * CFrame.new(0, 0.8, 6), Color3.fromRGB(200, 200, 205), M.Concrete)
	for x = 0, 5 do
		for z = 0, 3 do
			local c = if (x + z) % 2 == 0 then RUBBER else RUBBER:Lerp(col, 0.25)
			part(f, Vector3.new(8.6, 0.2, 9.6), cf * CFrame.new(-21.5 + x * 8.6, 1.7, -8.5 + z * 9.6 + 6), c, M.Rubber)
		end
	end
	-- pavilion: pillars and a roof over the back half
	for _, x in { -26, -9, 9, 26 } do
		part(f, Vector3.new(2, 16, 2), cf * CFrame.new(x, 9.6, 26), WHITE, M.SmoothPlastic)
		part(f, Vector3.new(2, 16, 2), cf * CFrame.new(x, 9.6, 8), WHITE, M.SmoothPlastic)
	end
	part(f, Vector3.new(58, 1.2, 22), cf * CFrame.new(0, 18, 17), WHITE, M.SmoothPlastic)
	part(f, Vector3.new(58.4, 1.6, 0.8), cf * CFrame.new(0, 17.4, 6), col, M.SmoothPlastic)
	part(f, Vector3.new(58.4, 1.6, 0.8), cf * CFrame.new(0, 17.4, 28), col, M.SmoothPlastic)
	local roofSign = part(f, Vector3.new(20, 3.4, 0.8), cf * CFrame.new(0, 20.4, 6.2), col, M.SmoothPlastic)
	label(roofSign, "LIFT!", WHITE)
	-- barbell racks under the roof
	for _, x in { -18, 0, 18 } do
		local base = cf * CFrame.new(x, 1.8, 22)
		for _, dx in { -3.5, 3.5 } do
			part(f, Vector3.new(0.6, 6, 0.6), base * CFrame.new(dx, 3, 0), INK, M.Metal)
		end
		local a, b = (base * CFrame.new(-5.5, 5.2, 0)).Position, (base * CFrame.new(5.5, 5.2, 0)).Position
		bar(f, a, b, 0.2, Color3.fromRGB(190, 190, 200), M.Metal)
		for _, d in { -4.6, 4.6 } do
			local p = (base * CFrame.new(d, 5.2, 0)).Position
			bar(f, p - cf.RightVector * 0.4, p + cf.RightVector * 0.4, 1.6, col, M.SmoothPlastic)
		end
	end
	-- dumbbell rack and tyre stack at the sides
	part(f, Vector3.new(1.4, 2.4, 10), cf * CFrame.new(-25, 3, -6), INK, M.Metal)
	for i = 0, 4 do
		local p = (cf * CFrame.new(-25, 4.6, -10 + i * 2)).Position
		bar(f, p - cf.RightVector * 1, p + cf.RightVector * 1, 0.15, Color3.fromRGB(190, 190, 200), M.Metal)
		bar(f, p - cf.RightVector * 1.1, p - cf.RightVector * 0.7, 0.55, RUBBER, M.Rubber)
		bar(f, p + cf.RightVector * 0.7, p + cf.RightVector * 1.1, 0.55, RUBBER, M.Rubber)
	end
	for i = 0, 2 do
		disc(f, (cf * CFrame.new(25, 2.6 + i * 1.6, -6)).Position, 5, 1.5, Color3.fromRGB(35, 35, 38), M.Rubber)
	end
	-- giant kettlebell statue by the entrance
	local kb = (cf * CFrame.new(-18, 0, -34)).Position
	part(f, Vector3.new(6, 1.2, 6), kb + Vector3.new(0, 0.6, 0), STONE, M.Marble)
	ball(f, kb + Vector3.new(0, 4.4, 0), 6.6, INK, M.Metal)
	local handle = part(f, Vector3.new(4.6, 0.9, 0.9), kb + Vector3.new(0, 8.6, 0), INK, M.Metal)
	handle.CFrame = CFrame.new(kb + Vector3.new(0, 8.6, 0)) * cf.Rotation
	for _, dx in { -2, 2 } do
		part(
			f,
			Vector3.new(0.9, 2.4, 0.9),
			CFrame.new(kb + Vector3.new(0, 7.6, 0)) * cf.Rotation * CFrame.new(dx, 0, 0),
			INK,
			M.Metal
		)
	end
	-- lifting pads: the work slots in two rows on the open half of the floor
	local sf = folder(f, "Slots")
	for i = 1, World.SLOTS do
		local row, k = (i - 1) // 4, (i - 1) % 4
		slot(sf, (cf * CFrame.new(-15 + k * 10, 1.8, -10 + row * 9)).Position, col, st.id, i)
	end
	tree(f, (cf * CFrame.new(34, 0, -30)).Position, rng, 1)
	tree(f, (cf * CFrame.new(-34, 0, 20)).Position, rng, 1)
end

local function pool(root: Instance, st: StationConfig.Station, rng: Random)
	local f, cf, col = shell(root, st)
	local TILE = Color3.fromRGB(240, 248, 255)
	local W, L = 30, 46 -- pool water size (x, z)
	-- deck, rim and basin
	part(f, Vector3.new(W + 20, 1, L + 16), cf * CFrame.new(0, 0.5, 6), Color3.fromRGB(235, 225, 205), M.Pavement)
	for _, side in { -1, 1 } do
		part(f, Vector3.new(2, 1.4, L + 4), cf * CFrame.new(side * (W / 2 + 1), 1.2, 6), TILE, M.Marble)
		part(f, Vector3.new(W + 4, 1.4, 2), cf * CFrame.new(0, 1.2, 6 + side * (L / 2 + 1)), TILE, M.Marble)
	end
	part(f, Vector3.new(W, 0.4, L), cf * CFrame.new(0, 1, 6), Color3.fromRGB(120, 210, 240), M.SmoothPlastic)
	local water = part(f, Vector3.new(W, 0.6, L), cf * CFrame.new(0, 1.3, 6), Color3.fromRGB(40, 160, 245), M.Glass)
	water.Transparency, water.Reflectance = 0.3, 0.2
	water.Name = "Water"
	-- lane ropes with red and white floats
	for lane = 1, 3 do
		local x = -W / 2 + lane * W / 4
		for k = 0, 22 do
			local c = if k % 2 == 0 then Color3.fromRGB(235, 60, 60) else WHITE
			ball(f, (cf * CFrame.new(x, 1.6, 6 - L / 2 + 1 + k * 2)).Position, 0.9, c, M.SmoothPlastic)
		end
	end
	-- diving board and ladder at the far end
	part(f, Vector3.new(3, 3, 3), cf * CFrame.new(-8, 2, 6 + L / 2 + 4), TILE, M.Marble)
	part(
		f,
		Vector3.new(2.4, 0.4, 9),
		cf * CFrame.new(-8, 3.7, 6 + L / 2 - 0.5),
		Color3.fromRGB(80, 170, 255),
		M.SmoothPlastic
	)
	for _, dx in { -1, 1 } do
		bar(
			f,
			(cf * CFrame.new(8 + dx, 1, 6 + L / 2)).Position,
			(cf * CFrame.new(8 + dx, 4.5, 6 + L / 2 + 0.8)).Position,
			0.15,
			WHITE,
			M.Metal
		)
	end
	-- loungers and umbrellas on the side deck
	for i = 0, 3 do
		local side = if i < 2 then -1 else 1
		local z = -6 + (i % 2) * 18
		local base = cf * CFrame.new(side * (W / 2 + 6), 1, z)
		part(f, Vector3.new(2.6, 0.5, 6), base * CFrame.new(0, 0.9, 0), WHITE, M.SmoothPlastic)
		part(
			f,
			Vector3.new(2.6, 0.5, 2.6),
			base * CFrame.new(0, 1.6, 2.6) * CFrame.Angles(rad(-35), 0, 0),
			WHITE,
			M.SmoothPlastic
		)
		local pole = (base * CFrame.new(side * 2.6, 0, -2)).Position
		pillar(f, pole, 8, 0.15, WHITE, M.Metal)
		disc(
			f,
			pole + Vector3.new(0, 8.4, 0),
			7,
			0.5,
			if i % 2 == 0 then col else Color3.fromRGB(255, 225, 100),
			M.Fabric
		)
		ball(f, pole + Vector3.new(0, 8.6, 0), 0.8, WHITE)
	end
	-- life ring on a post
	local ringPost = cf * CFrame.new(W / 2 + 6, 1, 26)
	pillar(f, ringPost.Position, 5, 0.2, WHITE, M.Metal)
	local ring = part(
		f,
		Vector3.new(0.8, 3, 3),
		ringPost * CFrame.new(0, 4, -0.5) * CFrame.Angles(0, rad(90), 0),
		Color3.fromRGB(235, 70, 60),
		M.SmoothPlastic
	)
	ring.Shape = Enum.PartType.Cylinder
	-- starting blocks: the work slots along the near edge
	slotsAlong(f, cf, col, st, Vector3.new(-17.5, 1, 6 - L / 2 - 5.5), Vector3.new(5, 0, 0))
	tree(f, (cf * CFrame.new(-W / 2 - 14, 0, 36)).Position, rng, 1)
	tree(f, (cf * CFrame.new(W / 2 + 14, 0, 38)).Position, rng, 1)
end

local function library(root: Instance, st: StationConfig.Station, rng: Random)
	local f, cf, col = shell(root, st)
	local WALL = Color3.fromRGB(236, 228, 214)
	local ROOF = col:Lerp(INK, 0.3)
	local W, D, H = 40, 26, 15
	local c = cf * CFrame.new(0, 0, 16) -- building centre (front faces the plaza)
	-- floor, back and side walls, front columns
	part(f, Vector3.new(W + 4, 1.2, D + 4), c * CFrame.new(0, 0.6, 0), Color3.fromRGB(150, 105, 70), M.WoodPlanks)
	part(f, Vector3.new(W, H, 1.6), c * CFrame.new(0, H / 2 + 1.2, D / 2), WALL, M.Plaster)
	for _, side in { -1, 1 } do
		part(f, Vector3.new(1.6, H, D), c * CFrame.new(side * W / 2, H / 2 + 1.2, 0), WALL, M.Plaster)
		-- round window on each side wall
		local win = part(
			f,
			Vector3.new(1.8, 5, 5),
			c * CFrame.new(side * W / 2, H / 2 + 3, 0),
			Color3.fromRGB(190, 225, 255),
			M.Glass
		)
		win.Shape = Enum.PartType.Cylinder
	end
	for k = 0, 4 do
		local x = -W / 2 + 2 + k * (W - 4) / 4
		pillar(f, (c * CFrame.new(x, 1.2, -D / 2 + 1)).Position, H, 1, WHITE, M.Marble)
	end
	part(f, Vector3.new(W + 2, 1.6, 2), c * CFrame.new(0, H + 2, -D / 2 + 1), WHITE, M.Marble)
	-- gabled roof from two wedges, purple tiles
	local half = D / 2 + 2
	for _, side in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(W + 4, 7, half)
		w.CFrame = c
			* CFrame.new(0, H + 2.8 + 3.5, side * half / 2)
			* CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		w.Color, w.Material = ROOF, M.Slate
		w.Parent = f
	end
	local pediment = part(f, Vector3.new(16, 3, 0.6), c * CFrame.new(0, H + 4.4, -D / 2 - 1.4), col, M.SmoothPlastic)
	label(pediment, "LIBRARY", WHITE)
	-- bookshelves along the back wall
	for k = 0, 3 do
		local sx = -15 + k * 10
		part(f, Vector3.new(8, 11, 2.4), c * CFrame.new(sx, 6.7, D / 2 - 2), WOOD_DARK, M.Wood)
		for shelf = 0, 3 do
			local y = 2.6 + shelf * 2.6
			local x = sx - 3.4
			while x < sx + 3.2 do
				local bw = rng:NextNumber(0.5, 0.9)
				local bh = rng:NextNumber(1.6, 2.2)
				part(
					f,
					Vector3.new(bw, bh, 1.6),
					c * CFrame.new(x + bw / 2, y + bh / 2, D / 2 - 2.6),
					FLOWERS[rng:NextInteger(1, #FLOWERS)]:Lerp(INK, 0.25),
					M.SmoothPlastic
				)
				x += bw + 0.08
			end
		end
	end
	-- chalkboard on the left wall
	local board =
		part(f, Vector3.new(0.4, 6, 12), c * CFrame.new(-W / 2 + 1.2, 7.5, 0), Color3.fromRGB(40, 70, 55), M.Slate)
	label(board, "2 + 2 = ?", WHITE)
	-- puzzle cubes and a book stack outside the front
	local cubeCols = {
		Color3.fromRGB(235, 70, 70),
		Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(60, 160, 255),
		Color3.fromRGB(80, 200, 100),
		WHITE,
		Color3.fromRGB(255, 140, 40),
	}
	for n, pos in { Vector3.new(-26, 0, -22), Vector3.new(24, 0, -24) } do
		local base = cf * CFrame.new(pos) * CFrame.Angles(0, rad(20 * n), 0)
		for x = -1, 1 do
			for y = 0, 2 do
				for z = -1, 1 do
					part(
						f,
						Vector3.new(1.9, 1.9, 1.9),
						base * CFrame.new(x * 2, 1 + y * 2, z * 2),
						cubeCols[(x + y * 2 + z * 3 + 9) % 6 + 1],
						M.SmoothPlastic
					)
				end
			end
		end
	end
	for i = 0, 4 do
		part(
			f,
			Vector3.new(5 - i * 0.4, 1.2, 3.6 - i * 0.2),
			cf * CFrame.new(26, 0.6 + i * 1.2, 4) * CFrame.Angles(0, rad(i * 13), 0),
			FLOWERS[i + 1]:Lerp(INK, 0.2),
			M.SmoothPlastic
		)
	end
	-- study desks: the work slots in two rows inside, each with a desk and a lamp
	local sf = folder(f, "Slots")
	for i = 1, World.SLOTS do
		local row, colIdx = (i - 1) // 4, (i - 1) % 4
		local p = c * CFrame.new(-13.5 + colIdx * 9, 1.2, -6 + row * 8)
		slot(sf, p.Position, col, st.id, i)
		part(f, Vector3.new(5, 0.4, 2.4), p * CFrame.new(0, 3, 3.6), WOOD, M.Wood)
		for _, dx in { -2.2, 2.2 } do
			part(f, Vector3.new(0.4, 3, 2), p * CFrame.new(dx, 1.5, 3.6), WOOD_DARK, M.Wood)
		end
		local lampHead = part(f, Vector3.new(0.8, 0.8, 0.8), p * CFrame.new(1.6, 4.2, 4), WARM, M.Neon)
		glow(lampHead, WARM, 8, 0.6)
	end
end

-- Healing Spring (trains Health): a round stone pool of glowing green water with a spout rock,
-- boulders and reeds; the work slots ring the pool.
local function spring(root: Instance, st: StationConfig.Station, rng: Random)
	local f, cf, col = shell(root, st)
	local c = (cf * CFrame.new(0, 0, 6)).Position
	disc(f, c + Vector3.new(0, 0.5, 0), 58, 1, Color3.fromRGB(196, 206, 188), M.Pavement)
	disc(f, c + Vector3.new(0, 1.6, 0), 30, 1.2, STONE_DARK, M.Cobblestone)
	disc(f, c + Vector3.new(0, 1.7, 0), 26, 0.6, Color3.fromRGB(150, 230, 190), M.SmoothPlastic)
	local water = disc(f, c + Vector3.new(0, 1.9, 0), 26, 0.4, col, M.Glass)
	water.Transparency, water.Reflectance = 0.35, 0.2
	water.Name = "Water"
	glow(water, col, 30, 0.8)
	-- spout rock in the middle with a glowing orb
	ball(f, c + Vector3.new(0, 2.5, 0), 7, STONE, M.Slate)
	ball(f, c + Vector3.new(1.5, 5, -1), 4.5, STONE, M.Slate)
	local orb = ball(f, c + Vector3.new(0.6, 8.2, -0.4), 2.6, col:Lerp(WHITE, 0.4), M.Neon)
	glow(orb, col, 24, 1.2)
	-- boulders and reeds around the rim
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.4
		local p = c + Vector3.new(math.cos(a) * 16.5, 0, math.sin(a) * 16.5)
		ball(f, p + Vector3.new(0, 1.4, 0), rng:NextNumber(2.5, 4.5), STONE_DARK, M.Slate)
		for _ = 1, 3 do
			local r = p + Vector3.new(rng:NextNumber(-2, 2), 1, rng:NextNumber(-2, 2))
			pillar(f, r, rng:NextNumber(3, 5), 0.15, Color3.fromRGB(90, 160, 80))
		end
	end
	local sf = folder(f, "Slots")
	for i = 1, World.SLOTS do
		local a = (i - 0.5) / World.SLOTS * math.pi * 2
		slot(sf, c + Vector3.new(math.cos(a) * 23, 1, math.sin(a) * 23), col, st.id, i)
	end
end

local BUILDERS: { [string]: (Instance, StationConfig.Station, Random) -> () } = {
	spring = spring,
	track = track,
	gym = gym,
	pool = pool,
	library = library,
}

-- Ranches -------------------------------------------------------------------------------------------

local RED = Color3.fromRGB(196, 64, 54)
local HAY = Color3.fromRGB(232, 196, 110)
local DIRT = Color3.fromRGB(168, 128, 86)
local ROOF = Color3.fromRGB(84, 72, 76)

-- Local frame of ranch `i`: origin at its centre, -Z (look) points back at the plaza.
function World.ranchFrame(i: number): CFrame
	local a = rad(RANCH_ANGLE[i])
	local up = Vector3.new(0, World.RANCH_Y, 0)
	return CFrame.lookAt(Vector3.new(math.cos(a), 0, math.sin(a)) * World.RANCH_DIST + up, up)
end

-- Where the owner spawns: just inside the gate, facing the barn.
function World.ranchSpawn(i: number): CFrame
	return World.ranchFrame(i) * CFrame.new(0, 3, -World.RANCH_HALF + 8) * CFrame.Angles(0, math.pi, 0)
end

-- White post-and-rail fence between two local points (y = 0) of `cf`.
local function fence(f: Instance, cf: CFrame, a: Vector3, b: Vector3)
	local n = math.max(1, math.round((b - a).Magnitude / 6))
	for k = 0, n do
		local p = (cf * CFrame.new(a:Lerp(b, k / n))).Position
		part(f, Vector3.new(0.9, 4.6, 0.9), CFrame.new(p + Vector3.new(0, 2.3, 0)) * cf.Rotation, WHITE, M.Wood)
	end
	local wa, wb = (cf * CFrame.new(a)).Position, (cf * CFrame.new(b)).Position
	for _, y in { 1.8, 3.7 } do
		bar(f, wa + Vector3.new(0, y, 0), wb + Vector3.new(0, y, 0), 0.22, WHITE, M.Wood)
	end
end

-- Red barn with white trim, X-braced doors, a hayloft and a gabled roof whose gable faces the gate.
local function barn(f: Instance, b: CFrame)
	local W, D, H = 24, 16, 11
	local top = H + 1
	part(f, Vector3.new(W + 2, 1, D + 2), b * CFrame.new(0, 0.5, 0), STONE_DARK, M.Concrete)
	part(f, Vector3.new(W, H, 1), b * CFrame.new(0, H / 2 + 1, D / 2 - 0.5), RED, M.WoodPlanks)
	for _, side in { -1, 1 } do
		part(f, Vector3.new(1, H, D), b * CFrame.new(side * (W / 2 - 0.5), H / 2 + 1, 0), RED, M.WoodPlanks)
		part(f, Vector3.new(7, H, 1), b * CFrame.new(side * 8.5, H / 2 + 1, -D / 2 + 0.5), RED, M.WoodPlanks)
		for _, z in { -D / 2, D / 2 } do -- corner boards
			part(f, Vector3.new(1.4, H, 1.4), b * CFrame.new(side * W / 2, H / 2 + 1, z), WHITE, M.Wood)
		end
	end
	part(f, Vector3.new(10, H - 9, 1), b * CFrame.new(0, 10 + (H - 9) / 2, -D / 2 + 0.5), RED, M.WoodPlanks)
	-- closed double doors: white frame, centre post and an X brace on each leaf
	local door = b * CFrame.new(0, 5.5, -D / 2 - 0.1)
	part(f, Vector3.new(10, 9, 0.6), door, RED:Lerp(INK, 0.15), M.WoodPlanks)
	for _, dx in { -5, 0, 5 } do
		part(f, Vector3.new(0.6, 9, 0.5), door * CFrame.new(dx, 0, -0.4), WHITE, M.Wood)
	end
	for _, dy in { -4.5, 4.5 } do
		part(f, Vector3.new(10.6, 0.6, 0.5), door * CFrame.new(0, dy, -0.4), WHITE, M.Wood)
	end
	for _, dx in { -2.5, 2.5 } do
		for _, sign in { -1, 1 } do
			local a = (door * CFrame.new(dx - 2.2, -4.2 * sign, -0.45)).Position
			local c = (door * CFrame.new(dx + 2.2, 4.2 * sign, -0.45)).Position
			bar(f, a, c, 0.26, WHITE, M.Wood)
		end
	end
	-- roof: ridge runs front to back, so build it in a frame turned 90 degrees
	local rb = b * CFrame.Angles(0, math.pi / 2, 0)
	local rh, half = 8, W / 2 + 1.5
	for _, side in { -1, 1 } do
		local turn = CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		local w = Instance.new("WedgePart")
		w.Anchored, w.Size = true, Vector3.new(D + 3, rh, half)
		w.CFrame = rb * CFrame.new(0, top + rh / 2, side * half / 2) * turn
		w.Color, w.Material = ROOF, M.Slate
		w.Parent = f
		for _, x in { D / 2 - 0.5, -(D / 2 - 0.5) } do -- red gable ends under the roof
			local g = Instance.new("WedgePart")
			g.Anchored, g.Size = true, Vector3.new(1, rh - 0.6, W / 2)
			g.CFrame = rb * CFrame.new(x, top + (rh - 0.6) / 2, side * W / 4) * turn
			g.Color, g.Material = RED, M.WoodPlanks
			g.Parent = f
		end
	end
	-- hayloft window on the front gable, hay peeking out
	local loft = b * CFrame.new(0, top + 2.4, -D / 2 - 0.2)
	part(f, Vector3.new(4.2, 3.6, 0.4), loft, INK, M.SmoothPlastic)
	for _, dy in { -2, 2 } do
		part(f, Vector3.new(5, 0.5, 0.5), loft * CFrame.new(0, dy, -0.1), WHITE, M.Wood)
	end
	for _, dx in { -2.3, 2.3 } do
		part(f, Vector3.new(0.5, 4.4, 0.5), loft * CFrame.new(dx, 0, -0.1), WHITE, M.Wood)
	end
	ball(f, (loft * CFrame.new(0, -1, 0)).Position, 2.6, HAY, M.Fabric)
end

local function silo(f: Instance, base: Vector3)
	pillar(f, base, 20, 4.5, Color3.fromRGB(205, 210, 215), M.Metal)
	ball(f, base + Vector3.new(0, 20, 0), 9, RED, M.SmoothPlastic)
	for _, y in { 6, 13 } do
		disc(f, base + Vector3.new(0, y + 0.3, 0), 9.3, 0.6, RED, M.SmoothPlastic)
	end
end

-- One home ranch: fenced yard, gate with the owner sign, barn and silo, a paddock of animal spots,
-- an egg nest, a trough, hay bales, a mailbox, flowers and trees. Spots and nest are tagged.
local function ranch(root: Instance, i: number, rng: Random)
	local f = folder(root, `Ranch{i}`)
	f:SetAttribute("Index", i)
	f:SetAttribute("Owner", 0)
	local cf = World.ranchFrame(i)
	local H = World.RANCH_HALF
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- ground: lawn, a greener paddock on the left, dirt tracks to the barn and the nest
	part(f, Vector3.new(H * 2, 0.4, H * 2), at(0, 0.2, 0), Color3.fromRGB(120, 176, 84), M.Grass)
	part(f, Vector3.new(30, 0.5, 46), at(-20, 0.25, -12), Color3.fromRGB(104, 168, 72), M.LeafyGrass)
	part(f, Vector3.new(9, 0.5, H + 14), at(0, 0.3, -H / 2 + 7), DIRT, M.Ground)
	part(f, Vector3.new(14, 0.5, 14), at(20, 0.3, -14), DIRT, M.Ground)
	-- fence with a gate gap facing the plaza
	fence(f, cf, Vector3.new(-H, 0, -H), Vector3.new(-8, 0, -H))
	fence(f, cf, Vector3.new(8, 0, -H), Vector3.new(H, 0, -H))
	fence(f, cf, Vector3.new(H, 0, -H), Vector3.new(H, 0, H))
	fence(f, cf, Vector3.new(H, 0, H), Vector3.new(-H, 0, H))
	fence(f, cf, Vector3.new(-H, 0, H), Vector3.new(-H, 0, -H))
	-- gate arch with the owner sign (World.setRanchOwner changes the text); the road brings the lamps
	for _, dx in { -8, 8 } do
		part(f, Vector3.new(1.6, 13, 1.6), at(dx, 6.5, -H), WOOD_DARK, M.Wood)
		ball(f, at(dx, 13.4, -H).Position, 1.8, HAY, M.SmoothPlastic)
	end
	part(f, Vector3.new(18, 1, 1.4), at(0, 12.6, -H), WOOD_DARK, M.Wood)
	local sign = part(f, Vector3.new(14, 3.2, 0.6), at(0, 10.2, -H), WOOD, M.WoodPlanks)
	sign.Name = "OwnerSign"
	label(sign, "Free Ranch", WHITE)
	barn(f, at(0, 0, 22))
	silo(f, at(19, 0, 26).Position)
	-- paddock: straw spots where owned animals will idle, tagged "RanchSpot"
	local spots = folder(f, "Spots")
	local n = 0
	for _, z in { -28, -18, -8, 2 } do
		for _, x in { -27, -14 } do
			n += 1
			local pad = disc(spots, at(x, 0, z).Position + Vector3.new(0, 0.55, 0), 4.6, 0.3, HAY, M.Fabric)
			pad.Name = `Spot{n}`
			pad:SetAttribute("Ranch", i)
			pad:SetAttribute("Index", n)
			CollectionService:AddTag(pad, "RanchSpot")
		end
	end
	-- water trough and hay bales by the paddock
	part(f, Vector3.new(3.4, 2.2, 9), at(-33, 1.1, 12), WOOD, M.Wood)
	part(f, Vector3.new(2.6, 0.3, 8.2), at(-33, 2.1, 12), Color3.fromRGB(90, 170, 230), M.Glass).Transparency = 0.25
	for k, o in { Vector3.new(-17, 1.5, 12), Vector3.new(-12.6, 1.5, 12.4), Vector3.new(-14.8, 4.5, 12.2) } do
		part(f, Vector3.new(4.2, 3, 3), at(o.X, o.Y, o.Z) * CFrame.Angles(0, rad(k * 7), 0), HAY, M.Fabric)
	end
	-- egg nest: the ranch's own hatching spot, tagged "RanchNest"
	local nestAt = at(20, 0, -14).Position
	local nest = disc(f, nestAt + Vector3.new(0, 0.9, 0), 7, 0.8, HAY, M.Fabric)
	nest.Name = "Nest"
	nest:SetAttribute("Ranch", i)
	CollectionService:AddTag(nest, "RanchNest")
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		ball(f, nestAt + Vector3.new(math.cos(a) * 3.4, 1.2, math.sin(a) * 3.4), 2, HAY:Lerp(WOOD, 0.2), M.Fabric)
	end
	local e = egg(f, nestAt + Vector3.new(0, 0.9, 0), 3.4, EGG_LOOK.meadow.body, EGG_LOOK.meadow.spot, rng)
	glow(e, WARM, 10, 0.6)
	signboard(f, at(20, 0, -22.5), 9, "Egg Nest", Color3.fromRGB(110, 170, 90), 3.2)
	-- mailbox by the gate, flowers along the front fence, trees outside the corners
	local box = at(12.5, 0, -H - 3.5)
	pillar(f, box.Position, 3.4, 0.25, WOOD_DARK, M.Wood)
	part(f, Vector3.new(1.4, 1.3, 2.2), box * CFrame.new(0, 4, 0), RED, M.SmoothPlastic)
	part(f, Vector3.new(0.15, 1, 0.5), box * CFrame.new(0.8, 4.5, 0.6), Color3.fromRGB(255, 220, 80), M.SmoothPlastic)
	for _, x in { -28, -18, 18, 28 } do
		flowers(f, at(x, 0, -H - 2.5).Position, rng, 6, 2.5)
	end
	for _, p in { Vector3.new(-48, 0, 30), Vector3.new(48, 0, 30), Vector3.new(-50, 0, -4), Vector3.new(50, 0, -6) } do
		tree(f, at(p.X, 0, p.Z).Position, rng, rng:NextNumber(1.1, 1.5))
	end
end

local function ranches(root: Instance, rng: Random)
	local f = folder(root, "Ranches")
	for i = 1, World.RANCHES do
		ranch(f, i, rng)
	end
end

-- Show who owns ranch `i` (nil frees it). Display only; the server keeps the real assignment.
function World.setRanchOwner(i: number, player: Player?)
	local hub = Workspace:FindFirstChild("Hub")
	local all = hub and hub:FindFirstChild("Ranches")
	local model = all and all:FindFirstChild(`Ranch{i}`)
	if model == nil then
		return
	end
	model:SetAttribute("Owner", if player then player.UserId else 0)
	local text = if player then `{player.DisplayName}'s Ranch` else "Free Ranch"
	for _, d in (model:FindFirstChild("OwnerSign") :: Instance):GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = text
		end
	end
end

-- Scenery --------------------------------------------------------------------------------------------

-- True when `p` is clear of the plaza, every road, station zone and ranch.
local function open(p: Vector3, margin: number): boolean
	local flat = Vector3.new(p.X, 0, p.Z)
	if flat.Magnitude < World.PLAZA + margin + 6 then
		return false
	end
	for id in STATION_ANGLE do
		if (flat - stationPos(id)).Magnitude < 58 + margin then
			return false
		end
	end
	for i = 1, World.RANCHES do
		local c = World.ranchFrame(i).Position
		if (flat - Vector3.new(c.X, 0, c.Z)).Magnitude < HILL + 20 + margin then
			return false -- the whole hill and its terrace
		end
	end
	for _, seg in ROADS do
		local a, b = seg[1] * Vector3.new(1, 0, 1), seg[2] * Vector3.new(1, 0, 1)
		local t = math.clamp((flat - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
		if (flat - a:Lerp(b, t)).Magnitude < 14 + margin then
			return false
		end
	end
	return true
end

local function scenery(root: Instance, rng: Random)
	local f = folder(root, "Scenery")
	-- groves of 4 to 8 trees between the zones, then a denser forest ring in front of the hills
	local groves, tries = 0, 0
	while groves < 16 and tries < 2000 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(80, 220)
		local c = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if open(c, 14) then
			groves += 1
			for _ = 1, rng:NextInteger(4, 8) do
				local p = c + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
				if open(p, 4) then
					tree(f, p, rng, rng:NextNumber(0.9, 1.4))
				end
			end
		end
	end
	for i = 0, 89 do
		local a = i / 90 * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(355, 410)
		if open(p, 4) then
			tree(f, p, rng, rng:NextNumber(1.3, 1.9))
		end
	end
	local beds = 0
	tries = 0
	while beds < 40 and tries < 2000 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(55, 230)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if open(p, 2) then
			flowers(f, p, rng, 10, 3)
			ball(
				f,
				p + Vector3.new(rng:NextNumber(-4, 4), 0.6, rng:NextNumber(-4, 4)),
				rng:NextNumber(2.5, 4),
				LEAVES[rng:NextInteger(1, #LEAVES)]
			)
			beds += 1
		end
	end
	-- south lawn: welcome sign at the spawn walk
	signboard(
		f,
		CFrame.new(0, 0, 62) * CFrame.Angles(0, 0, 0),
		22,
		"Welcome to Animal Stations!",
		Color3.fromRGB(90, 160, 80),
		7
	)
end

-- Build --------------------------------------------------------------------------------------------

-- The built world (World.build first).
function World.root(): Folder
	return Workspace:WaitForChild("Hub") :: Folder
end

function World.build(): Folder
	local old = Workspace:FindFirstChild("Hub")
	if old then
		old:Destroy()
	end
	lighting()
	terrain()
	local rng = Random.new(2026)
	local root = Instance.new("Folder")
	root.Name = "Hub"
	plaza(root, rng)
	paths(root)
	local stations = folder(root, "Stations")
	for _, st in StationConfig.STATIONS do
		BUILDERS[st.id](stations, st, rng)
	end
	ranches(root, rng)
	scenery(root, rng)
	root.Parent = Workspace
	-- Rojo does not apply Position on the project's SpawnLocation, so place it here: south lawn,
	-- facing north up the walk to the plaza.
	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.CFrame = CFrame.new(World.SPAWN)
	end
	return root
end

return World
