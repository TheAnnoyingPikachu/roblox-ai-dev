--!strict
-- Animal Stations world (framework, decision 0029): the hub, a central plaza with the hatchery
-- fountain and the vendors' egg stalls, and three home ranches (one per player). Each ranch is a
-- large separate island far from the hub, reached only by the teleport pads. A ranch is the
-- player's base, where animals live and train: a barn, a paddock, an egg nest and one training
-- pad per stat, with room to grow. Mountains ring every area to hide the void; a canyon through
-- the hub's mountains is the wave arena. Built once from parts, Roblox materials and terrain.
-- Display only: no game rules live here. Spots, nests, training pads, teleport prompts and the
-- arena's stand and spawn are tagged for the server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationConfig"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local World = {}

World.PLAZA = 48 -- plaza radius
World.HUB_RADIUS = 300 -- the walkable hub: an invisible wall stands here, the mountains behind it
-- The wave arena: a canyon through the mountains north of the plaza (half width, near and far end).
local ARENA_HALF, ARENA_NEAR, ARENA_FAR = 60, 330, 640
World.SPAWN = Vector3.new(0, 0.6, 76)
World.RANCHES = 3 -- one home ranch per player; lobbies (servers) hold 3 players to match
World.RANCH_DIST = 1200 -- hub centre to each ranch centre: detached, reached only by teleport
World.RANCH_Y = 22 -- the island surface (a terrain cylinder topped at 18 lands there; measured)
local ISLAND = 115 -- island radius
World.RANCH_HALF = 60 -- half the fenced ranch square: room for the ranch to grow
World.RANCH_SPOTS = 8 -- places in the paddock where owned animals will idle
-- The ranch islands lie north, east and west of the hub.
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

-- Each stat's colour (its training pad at the ranch).
local STAT_COLOUR: { [string]: Color3 } = {
	speed = Color3.fromRGB(255, 160, 40),
	health = Color3.fromRGB(70, 200, 120),
	defence = Color3.fromRGB(105, 125, 165),
	strength = Color3.fromRGB(235, 70, 70),
	stamina = Color3.fromRGB(50, 150, 255),
	mana = Color3.fromRGB(160, 90, 240),
}
local EGG_LOOK: { [string]: { body: Color3, spot: Color3 } } = {
	meadow = { body = Color3.fromRGB(250, 240, 200), spot = Color3.fromRGB(130, 210, 110) },
	wild = { body = Color3.fromRGB(150, 210, 120), spot = Color3.fromRGB(110, 80, 50) },
	safari = { body = Color3.fromRGB(245, 200, 110), spot = Color3.fromRGB(70, 50, 35) },
	golden = { body = Color3.fromRGB(255, 205, 70), spot = Color3.fromRGB(150, 80, 220) },
}

local function rad(d: number): number
	return math.rad(d)
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
	-- one flat island per ranch, far from the hub
	for _, angle in RANCH_ANGLE do
		local c = Vector3.new(math.cos(rad(angle)), 0, math.sin(rad(angle))) * World.RANCH_DIST
		local top = World.RANCH_Y - 4 -- measured in Studio: a cylinder top at 18 gives a surface at 22
		t:FillCylinder(CFrame.new(c + Vector3.new(0, (top - 10) / 2, 0)), top + 10, ISLAND, M.Grass)
	end
end

-- Plaza ----------------------------------------------------------------------------------------------

local function plaza(root: Instance, rng: Random)
	local f = folder(root, "Plaza")
	local R = World.PLAZA
	disc(f, Vector3.new(0, 0.4, 0), R * 2 + 4, 0.6, STONE_DARK, M.Pavement)
	disc(f, Vector3.new(0, 0.5, 0), R * 2, 0.6, STONE, M.Pavement)
	disc(f, Vector3.new(0, 0.55, 0), 62, 0.6, Color3.fromRGB(236, 226, 205), M.Pavement)
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

	-- Egg market (the hub's vendors) on the north arc, facing the south walk players arrive on:
	-- one stall per egg, cheapest on the left as you look north.
	local mk = folder(f, "EggMarket")
	for i, e in StationConfig.EGGS do
		local a = rad(-90 + (i - (#StationConfig.EGGS + 1) / 2) * 36)
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
		label(
			board,
			if e.unlock then `{e.name}  Lv {e.unlock}+  {e.price} coins` else `{e.name}  {e.price} coins`,
			WHITE
		)
		local spot = part(stand, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 10.6, 1), WARM, M.Neon)
		glow(spot, WARM, 12, 1)
	end

	-- benches and planters around the rim, clear of the market arc (north) and the south walk
	for i = 0, 15 do
		local deg = i * 22.5 + 11.25
		local fromNorth = math.abs(((deg + 90 + 180) % 360) - 180)
		if fromNorth > 75 and fromNorth < 166 then
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

-- Every road as a segment {a, b}; scenery keeps clear of these. The south walk comes in from the
-- hub's teleport pad and the north road leads to the wave arena. The ranches are reached by
-- teleport, not by road.
local ROADS: { { Vector3 } } = {
	{ Vector3.new(0, 0, World.PLAZA - 2), Vector3.new(0, 0, 90) },
	{ Vector3.new(0, 0, -(World.PLAZA - 2)), Vector3.new(0, 0, -ARENA_NEAR) },
}

-- Where a player arrives in the hub: on the south walk, facing the plaza.
function World.hubSpawn(): CFrame
	return CFrame.lookAt(Vector3.new(0, 3, 80), Vector3.new(0, 3, 0))
end

-- A glowing teleport pad with a prompt. `to` is "hub" or "ranch"; the server connects every
-- prompt tagged "Teleport" and decides where the player goes.
local function teleporter(parent: Instance, pos: Vector3, to: string, action: string)
	local pad = disc(parent, pos + Vector3.new(0, 0.7, 0), 8, 0.5, Color3.fromRGB(120, 220, 255), M.Neon)
	pad.Name = "Teleport"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "Teleport"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("To", to)
	prompt.Parent = pad
	CollectionService:AddTag(prompt, "Teleport")
end

local function paths(root: Instance)
	local f = folder(root, "Paths")
	for _, seg in ROADS do
		local a, b = seg[1], seg[2]
		strip(f, a + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0), 18, 0.6, STONE_DARK, M.Cobblestone)
		strip(f, a + Vector3.new(0, 0.35, 0), b + Vector3.new(0, 0.35, 0), 15, 0.6, PATH, M.Cobblestone)
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X).Unit
		for i = 1, math.floor(((b - a).Magnitude - 6) / 22) do -- stop short of the road's end
			local p = a + dir * (i * 22 - 8)
			lamp(f, p + side * 11)
			lamp(f, p - side * 11)
		end
		disc(f, b + Vector3.new(0, 0.32, 0), 18, 0.6, PATH, M.Cobblestone) -- round off the end
	end
	-- the hub's teleport pad at the end of the south walk
	teleporter(f, Vector3.new(0, 0, 90), "ranch", "Go to your ranch")
	signboard(f, CFrame.new(0, 0, 100), 14, "To your ranch", Color3.fromRGB(60, 130, 170), 5)
end

-- Mountains and the wave arena ---------------------------------------------------------------------

local ROCK = Color3.fromRGB(128, 124, 138)

-- A mountain: a huge rock dome. `pos` is the centre of its foot circle on the ground and `foot`
-- that circle's radius; the ball's centre is sunk a quarter of its radius.
local function mountain(parent: Instance, pos: Vector3, foot: number, rng: Random)
	local r = foot / math.sqrt(1 - 0.25 ^ 2)
	local m = ball(parent, pos - Vector3.new(0, r * 0.25, 0), r * 2, ROCK:Lerp(INK, rng:NextNumber(0, 0.18)), M.Slate)
	m.Name = "Mountain"
end

-- An invisible wall from a to b (ground points), so nobody climbs the mountains to the void.
local function barrier(parent: Instance, a: Vector3, b: Vector3)
	local along = b - a
	local mid = (a + b) / 2 + Vector3.new(0, 200, 0)
	local facing = CFrame.lookAt(mid, mid + Vector3.new(-along.Z, 0, along.X))
	local w = part(parent, Vector3.new(along.Magnitude + 2, 400, 2), facing, WHITE)
	w.Transparency, w.CastShadow, w.Name = 1, false, "Barrier"
end

-- A closed ring of mountains round `centre` whose feet start `inner` studs out, with an
-- invisible wall just inside them. Used for the ranch islands.
local function mountainRing(parent: Instance, centre: Vector3, inner: number, rng: Random)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local foot = rng:NextNumber(105, 140)
		mountain(parent, centre + Vector3.new(math.cos(a), 0, math.sin(a)) * (inner + foot), foot, rng)
	end
	for k = 0, 23 do
		local a0, a1 = k / 24 * math.pi * 2, (k + 1) / 24 * math.pi * 2
		barrier(
			parent,
			centre + Vector3.new(math.cos(a0), 0, math.sin(a0)) * (inner - 2),
			centre + Vector3.new(math.cos(a1), 0, math.sin(a1)) * (inner - 2)
		)
	end
end

-- The hub's mountains: a ring that is open to the north, where two rows of mountains make a
-- canyon closed at its far end. The canyon is the wave arena: the player's team stands at the
-- near end ("WaveStand") and the endless waves will come from the far end ("WaveSpawn").
local function mountains(root: Instance, rng: Random)
	local f = folder(root, "Mountains")
	local GAP, N = 32, 22 -- degrees left open either side of north; mountains in the ring
	for i = 0, N - 1 do
		local a = rad(-90 + GAP + i * (360 - 2 * GAP) / (N - 1))
		local foot = rng:NextNumber(165, 220)
		mountain(f, Vector3.new(math.cos(a), 0, math.sin(a)) * (World.HUB_RADIUS + 60 + foot), foot, rng)
	end
	for k = 0, 2 do
		for _, side in { -1, 1 } do
			mountain(f, Vector3.new(side * (ARENA_HALF + 158), 0, -(ARENA_NEAR + 60 + k * 150)), 150, rng)
		end
	end
	mountain(f, Vector3.new(0, 0, -(ARENA_FAR + 260)), 230, rng)
	-- invisible wall: round the hub, then up both sides of the canyon and across its end
	local half = ARENA_HALF + 10
	local mouth = math.deg(math.asin(half / World.HUB_RADIUS)) -- half-angle of the canyon mouth
	local STEPS = 36
	local function rim(k: number): Vector3
		local a = rad(-90 + mouth + k * (360 - 2 * mouth) / STEPS)
		return Vector3.new(math.cos(a), 0, math.sin(a)) * World.HUB_RADIUS
	end
	for k = 0, STEPS - 1 do
		barrier(f, rim(k), rim(k + 1))
	end
	local far = -(ARENA_FAR + 12)
	barrier(f, rim(0), Vector3.new(half, 0, far))
	barrier(f, rim(STEPS), Vector3.new(-half, 0, far))
	barrier(f, Vector3.new(-half, 0, far), Vector3.new(half, 0, far))

	local arena = folder(root, "WaveArena")
	local length = ARENA_FAR - ARENA_NEAR
	part(
		arena,
		Vector3.new(ARENA_HALF * 2, 0.4, length),
		CFrame.new(0, 0.2, -(ARENA_NEAR + length / 2)),
		Color3.fromRGB(190, 160, 120),
		M.Ground
	)
	local stand =
		disc(arena, Vector3.new(0, 0.7, -(ARENA_NEAR + 40)), 30, 0.4, Color3.fromRGB(120, 220, 255), M.SmoothPlastic)
	stand.Name = "Stand"
	CollectionService:AddTag(stand, "WaveStand")
	local spawn = part(
		arena,
		Vector3.new(ARENA_HALF * 2 - 10, 0.4, 8),
		CFrame.new(0, 0.5, -(ARENA_FAR - 20)),
		Color3.fromRGB(220, 70, 70),
		M.Neon
	)
	spawn.Name = "Spawn"
	CollectionService:AddTag(spawn, "WaveSpawn")
	signboard(arena, CFrame.new(0, 0, -(ARENA_NEAR - 12)), 24, "Endless Waves", Color3.fromRGB(190, 70, 70), 8)
end

-- Ranches -------------------------------------------------------------------------------------------

local RED = Color3.fromRGB(196, 64, 54)
local HAY = Color3.fromRGB(232, 196, 110)
local DIRT = Color3.fromRGB(168, 128, 86)
local ROOF = Color3.fromRGB(84, 72, 76)

-- Local frame of ranch `i`: origin at its centre on the island, -Z (look) points back at the hub.
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
	-- teleport pad to the hub, just inside the gate
	teleporter(f, at(-14, 0, -H + 10).Position, "hub", "Go to the hub")
	signboard(f, at(-14, 0, -H + 3), 10, "To the hub", Color3.fromRGB(60, 130, 170), 3.2)
	-- training pads, one per stat, in the stat's colour: animals train at the ranch (decision
	-- 0029). Tagged "TrainPad" with the station id; simple placeholders for the tycoon buildings.
	local pads = folder(f, "TrainPads")
	for k, st in StationConfig.STATIONS do
		local column, row = (k - 1) % 3, (k - 1) // 3
		local centre = at(13 + column * 9, 0, -2 + row * 9).Position
		local pad = disc(pads, centre + Vector3.new(0, 0.6, 0), 6, 0.4, STAT_COLOUR[st.stat], M.SmoothPlastic)
		pad.Name = st.id
		pad:SetAttribute("Ranch", i)
		pad:SetAttribute("Station", st.id)
		CollectionService:AddTag(pad, "TrainPad")
	end
	signboard(f, at(22, 0, 12.5), 14, "Training", Color3.fromRGB(90, 110, 150), 3.2)
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
	for _, p in
		{
			Vector3.new(-H - 12, 0, 30),
			Vector3.new(H + 12, 0, 30),
			Vector3.new(-H - 14, 0, -4),
			Vector3.new(H + 14, 0, -6),
		}
	do
		tree(f, at(p.X, 0, p.Z).Position, rng, rng:NextNumber(1.1, 1.5))
	end
	-- mountains all round the island hide the void
	mountainRing(f, cf.Position, 100, rng)
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

-- True when `p` is clear of the plaza and every road.
local function open(p: Vector3, margin: number): boolean
	local flat = Vector3.new(p.X, 0, p.Z)
	if flat.Magnitude < World.PLAZA + margin + 6 then
		return false
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
	-- groves of 4 to 8 trees between the zones, then a forest ring in front of the mountains
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
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(255, 295)
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
	-- south walk: welcome sign over the way into the plaza (clear of the walk's lamps)
	signboard(f, CFrame.new(0, 0, 70), 22, "Welcome to Animal Stations!", Color3.fromRGB(90, 160, 80), 7)
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
	mountains(root, rng)
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
