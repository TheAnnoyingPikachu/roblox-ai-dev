--!strict
-- Animal Stations world (framework, decision 0029): the hub, a central plaza with the hatchery
-- fountain, and three home ranches (one per player). Each ranch is a
-- large separate area behind the hub's mountains, reached by teleport pad or up its own pass. A ranch is the
-- player's base, where animals live and train: its plot is built here, and what stands on it
-- by Ranch.luau from its owner's upgrades. Mountains ring every area to hide the void; a canyon through
-- the hub's mountains is the wave arena. Built once from parts, Roblox materials and terrain.
-- Display only: no game rules live here. Teleport prompts and the arena's stand and spawn are
-- tagged for the server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local World = {}

World.PLAZA = 48 -- plaza radius
World.HUB_RADIUS = 300 -- the walkable hub: an invisible wall stands here, the mountains behind it
-- The wave arena: a canyon through the mountains north of the plaza (half width, near and far end).
local ARENA_HALF, ARENA_NEAR, ARENA_FAR = 60, 330, 640
World.SPAWN = Vector3.new(0, 0.6, 76)
World.RANCHES = 3 -- one home ranch per player; lobbies (servers) hold 3 players to match
World.RANCH_DIST = 900 -- hub centre to each ranch centre: behind the hub's mountains, up a pass
World.RANCH_Y = 22 -- the island surface (a terrain cylinder topped at 18 lands there; measured)
local ISLAND = 175 -- island radius
World.RANCH_HALF = 75 -- half the fenced ranch square
local RING = 134 -- where the feet of a ranch's mountains start, from its centre
local PASS_HALF = 34 -- half the width of the pass from the hub up to each ranch
local PASS_RAMP, PASS_TOP = 560, 725 -- along a pass from the hub: where it starts to climb, where it is up
-- The ranches lie south, east and west of the hub; the wave arena is to the north.
local RANCH_ANGLE = { 90, 0, 180 }

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
local GRASS = Color3.fromRGB(112, 170, 80) -- terrain grass, and the parts that continue it
local PINE = { Color3.fromRGB(50, 124, 82), Color3.fromRGB(62, 140, 92) }

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
	label(board, text, WHITE, 1.4) -- clear of the posts
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

-- A sharp four-sided point standing on `base`: four corner wedges, tall corners together.
local function pyramid(parent: Instance, base: CFrame, width: number, height: number, colour: Color3)
	for k = 0, 3 do
		local w = Instance.new("CornerWedgePart")
		w.Anchored, w.Size = true, Vector3.new(width / 2, height, width / 2)
		-- a corner wedge's tall corner is at +x, -z
		w.CFrame = base * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(-width / 4, height / 2, width / 4)
		w.Color, w.Material = colour, M.SmoothPlastic
		w.Parent = parent
	end
end

-- A pine: a trunk and three tiers, `s` times the usual size (about 12 studs tall at 1).
local function pine(parent: Instance, base: Vector3, s: number, rng: Random)
	pillar(parent, base, 3 * s, 0.55 * s, BARK, M.Wood)
	local green = PINE[rng:NextInteger(1, #PINE)]
	local spin = CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
	for k = 0, 2 do
		local tier = CFrame.new(base + Vector3.new(0, (2 + 2.5 * k) * s, 0)) * spin
		pyramid(parent, tier, (7 - 1.7 * k) * s, 4.6 * s, green:Lerp(WHITE, 0.05 * k))
	end
end

local function bush(parent: Instance, at: Vector3, s: number, rng: Random)
	local green = LEAVES[rng:NextInteger(1, #LEAVES)]
	for _ = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-1, 1), 0.8 + rng:NextNumber(0, 0.5), rng:NextNumber(-1, 1)) * s
		ball(parent, at + off, rng:NextNumber(2, 2.8) * s, green:Lerp(WHITE, rng:NextNumber(0, 0.08)), M.SmoothPlastic)
	end
end

-- A boulder: two tilted blocks, about `s` studs across.
local function rock(parent: Instance, at: Vector3, s: number, rng: Random)
	for k = 1, 2 do
		local size = Vector3.new(rng:NextNumber(0.9, 1.4), rng:NextNumber(0.6, 0.9), rng:NextNumber(0.8, 1.2)) * s / k
		local turn = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3))
		local where = at + Vector3.new((k - 1) * s * 0.8, size.Y * 0.35, (k - 1) * s * 0.3)
		part(parent, size, CFrame.new(where) * turn, STONE_DARK:Lerp(INK, rng:NextNumber(0.25, 0.5)), M.Slate)
	end
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
	t:SetMaterialColor(M.Grass, GRASS)
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

-- Every road in the hub as a segment {a, b}; scenery keeps clear of these. The south walk comes
-- in past the hub's teleport pad, the north road leads to the wave arena, and three roads run
-- out to the passes that climb to the ranches (south, east, west).
local ROADS: { { Vector3 } } = {
	{ Vector3.new(0, 0, World.PLAZA - 2), Vector3.new(0, 0, 90) },
	{ Vector3.new(0, 0, -(World.PLAZA - 2)), Vector3.new(0, 0, -ARENA_NEAR) },
	{ Vector3.new(0, 0, 90), Vector3.new(0, 0, World.HUB_RADIUS) },
	{ Vector3.new(World.PLAZA - 2, 0, 0), Vector3.new(World.HUB_RADIUS, 0, 0) },
	{ Vector3.new(-(World.PLAZA - 2), 0, 0), Vector3.new(-World.HUB_RADIUS, 0, 0) },
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
		local gap = if (b - a).Magnitude > 150 then 44 else 22 -- fewer lamps on the long roads
		for i = 1, math.floor(((b - a).Magnitude - 6) / gap) do -- stop short of the road's end
			local p = a + dir * (i * gap - 8)
			lamp(f, p + side * 11)
			lamp(f, p - side * 11)
		end
		disc(f, b + Vector3.new(0, 0.32, 0), 18, 0.6, PATH, M.Cobblestone) -- round off the end
	end
	-- the hub's teleport pad, beside the south road
	teleporter(f, Vector3.new(19, 0, 84), "ranch", "Go to your ranch")
	signboard(f, CFrame.new(19, 0, 92), 13, "To your ranch", Color3.fromRGB(60, 130, 170), 5)
end

-- Mountains and the wave arena ---------------------------------------------------------------------

local ROCK = Color3.fromRGB(128, 124, 138)
local SNOW = Color3.fromRGB(240, 244, 250)
local FOOTHILL = Color3.fromRGB(100, 156, 82)

-- A mountain: a huge rock dome with two higher peaks capped with snow. `pos` is
-- the centre of its foot circle on the ground and `foot` that circle's radius. With `toward`
-- (the place it is seen from) it also gets what shows up close on that side: grassy foothills
-- with pines, and lumps and ledges of rock on the slope.
local function mountain(parent: Instance, pos: Vector3, foot: number, rng: Random, toward: Vector3?)
	local r = foot / math.sqrt(1 - 0.25 ^ 2)
	local stone = ROCK:Lerp(INK, rng:NextNumber(0, 0.18))
	local core = pos - Vector3.new(0, r * 0.25, 0)
	local m = ball(parent, core, r * 2, stone, M.Slate)
	m.Name = "Mountain"
	local spin = rng:NextNumber(0, math.pi * 2)
	for k = 1, 2 do
		local a = spin + k * 2.4
		local pr = r * (if k == 1 then 0.62 else 0.48)
		local lift = r * (if k == 1 then 0.5 else 0.42)
		local centre = pos + Vector3.new(math.cos(a) * r * 0.28, lift, math.sin(a) * r * 0.28)
		ball(parent, centre, pr * 2, stone:Lerp(WHITE, 0.06 * k), M.Slate)
		ball(parent, centre + Vector3.new(0, pr * 0.3, 0), pr * (if k == 1 then 1.7 else 1.6), SNOW, M.Snow)
	end
	if toward == nil then
		return
	end
	local inward = (toward - pos) * Vector3.new(1, 0, 1)
	local base = math.atan2(inward.Z, inward.X)
	for k = -2, 2 do -- foothills, each with a pine near its top
		local a = base + k * 0.42 + rng:NextNumber(-0.12, 0.12)
		local mr = foot * rng:NextNumber(0.2, 0.3)
		local at = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (foot - mr * 0.45) - Vector3.new(0, mr * 0.5, 0)
		ball(parent, at, mr * 2, FOOTHILL:Lerp(INK, rng:NextNumber(0, 0.12)), M.Grass)
		local dx, dz = rng:NextNumber(-0.3, 0.3) * mr, rng:NextNumber(-0.3, 0.3) * mr
		local top = math.sqrt(mr * mr - dx * dx - dz * dz)
		pine(parent, at + Vector3.new(dx, top - 0.5, dz), mr / 20, rng)
	end
	local function onSlope(a: number, e: number): Vector3 -- a direction out of the dome, e radians up from level
		return Vector3.new(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e))
	end
	for _ = 1, 3 do -- shoulders: lumps of rock that break up the round slope
		local out = onSlope(base + rng:NextNumber(-1.2, 1.2), rng:NextNumber(0.45, 0.85))
		local sr = r * rng:NextNumber(0.3, 0.42)
		ball(parent, core + out * r * 0.78, sr * 2, stone:Lerp(INK, rng:NextNumber(0, 0.12)), M.Slate)
	end
	for _ = 1, 7 do -- ledges: flat shelves of darker rock lying along the slope
		local out = onSlope(base + rng:NextNumber(-1.1, 1.1), math.asin(0.25) + rng:NextNumber(0.08, 0.55))
		local size = r * rng:NextNumber(0.07, 0.13)
		local lie = CFrame.lookAt(core + out * (r - size * 0.2), core + out * (r + 1))
			* CFrame.Angles(math.pi / 2 + rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), 0)
		part(parent, Vector3.new(size * 2.4, size * 0.5, size * 1.5), lie, stone:Lerp(INK, 0.3), M.Slate)
	end
end

-- An invisible wall from a to b (ground points), so nobody climbs the mountains to the void.
local function barrier(parent: Instance, a: Vector3, b: Vector3)
	local along = b - a
	local mid = (a + b) / 2 + Vector3.new(0, 200, 0)
	local facing = CFrame.lookAt(mid, mid + Vector3.new(-along.Z, 0, along.X))
	local w = part(parent, Vector3.new(along.Magnitude + 2, 400, 2), facing, WHITE)
	w.Transparency, w.CastShadow, w.Name = 1, false, "Barrier"
end

-- True when a mountain `dist` out at angle `a` (foot radius `foot`) would stand in a pass that
-- leaves along angle `way`.
local function inPass(a: number, dist: number, foot: number, way: number): boolean
	return math.cos(a - way) > 0 and math.abs(math.sin(a - way)) * dist < PASS_HALF + foot
end

-- A ring of mountains round `centre` whose feet start `inner` studs out, a taller row behind
-- them, and an invisible wall in front. Both rows and the wall leave the pass open: it leaves
-- along `way` (a unit vector). Used for the ranches.
local function mountainRing(parent: Instance, centre: Vector3, inner: number, rng: Random, way: Vector3)
	local facing = math.atan2(way.Z, way.X)
	for k = 0, 11 do
		local a = facing + k / 12 * math.pi * 2
		local foot = rng:NextNumber(105, 140)
		if not inPass(a, inner + foot, foot, facing) then
			mountain(parent, centre + Vector3.new(math.cos(a), 0, math.sin(a)) * (inner + foot), foot, rng, centre)
		end
		local behind, tall = a + math.pi / 12, rng:NextNumber(150, 190)
		if not inPass(behind, inner + 90 + tall, tall, facing) then
			local at = centre + Vector3.new(math.cos(behind), 0, math.sin(behind)) * (inner + 90 + tall)
			mountain(parent, at, tall, rng, nil)
		end
	end
	local wall = inner - 16
	local gap = math.asin((PASS_HALF - 2) / wall)
	local function rim(k: number): Vector3
		local a = facing + gap + k * (math.pi * 2 - 2 * gap) / 24
		return centre + Vector3.new(math.cos(a), 0, math.sin(a)) * wall
	end
	for k = 0, 23 do
		barrier(parent, rim(k), rim(k + 1))
	end
end

-- The pass from the hub up to ranch `i`: a road through its own canyon, level from the hub's
-- wall, then climbing to the ranch. Mountains and invisible walls line both sides, so a ranch
-- can be walked (and one day ridden) to as well as teleported to.
local function pass(root: Instance, i: number, rng: Random)
	local f = folder(root, `Pass{i}`)
	local a = rad(RANCH_ANGLE[i])
	local dir, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
	local gate = World.RANCH_DIST - World.RANCH_HALF
	local function height(s: number): number
		return World.RANCH_Y * math.clamp((s - PASS_RAMP) / (PASS_TOP - PASS_RAMP), 0, 1)
	end
	-- a point `s` studs along the pass from the hub's middle, `across` to one side, `up` above the ground
	local function at(s: number, across: number, up: number?): Vector3
		return dir * s + side * across + Vector3.new(0, height(s) + (up or 0), 0)
	end
	-- the ground of the climb and of the top, wide enough to run under the mountains' feet
	strip(f, at(PASS_RAMP, 0, 0.1), at(PASS_TOP, 0, 0.1), 150, 4, GRASS, M.Grass)
	strip(f, at(PASS_TOP - 1, 0, 0.1), at(PASS_TOP + 70, 0, 0.1), 150, 4, GRASS, M.Grass)
	-- the road, as far as the ranch's own path
	for _, seg in { { World.HUB_RADIUS, PASS_RAMP }, { PASS_RAMP, PASS_TOP }, { PASS_TOP, gate - 22 } } do
		strip(f, at(seg[1], 0, 0.4), at(seg[2], 0, 0.4), 18, 0.6, STONE_DARK, M.Cobblestone)
		strip(f, at(seg[1], 0, 0.45), at(seg[2], 0, 0.45), 15, 0.6, PATH, M.Cobblestone)
	end
	signboard(
		f,
		CFrame.lookAt(at(World.HUB_RADIUS + 8, 0), at(0, 0)),
		22,
		"Ranch Pass",
		Color3.fromRGB(110, 150, 90),
		10
	)
	-- lamps down one side then the other, and pines, bushes and boulders along the edges
	for k = 0, math.floor((gate - 40 - World.HUB_RADIUS) / 50) do
		lamp(f, at(World.HUB_RADIUS + 30 + k * 50, if k % 2 == 0 then 12 else -12, 0.1))
	end
	for s = World.HUB_RADIUS + 10, gate - 30, 13 do
		local where =
			at(s + rng:NextNumber(-4, 4), rng:NextNumber(15, 30) * (if rng:NextNumber() < 0.5 then -1 else 1), 0.1)
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			pine(f, where, rng:NextNumber(0.9, 1.5), rng)
		elseif kind == 2 then
			bush(f, where, rng:NextNumber(0.9, 1.4), rng)
		else
			rock(f, where, rng:NextNumber(2, 4.5), rng)
		end
	end
	-- mountains down both sides: big ones along the canyon, a smaller pair where it meets the ranch
	for k, s in { 430, 540, 650, 735 } do
		for _, sx in { -1, 1 } do
			local foot = if k == 4 then rng:NextNumber(86, 92) else rng:NextNumber(140, 165)
			mountain(f, at(s, sx * (PASS_HALF + foot * 0.94)), foot, rng, at(s, 0))
		end
	end
	local w = PASS_HALF - 2
	local from = math.sqrt(World.HUB_RADIUS ^ 2 - w ^ 2)
	local to = World.RANCH_DIST - math.sqrt((RING - 16) ^ 2 - w ^ 2)
	for _, sx in { -1, 1 } do
		barrier(f, dir * from + side * sx * w, dir * to + side * sx * w)
	end
end

-- The hub's mountains: a ring that is open to the north, where two rows of mountains make a
-- canyon closed at its far end, and to the three passes. The canyon is the wave arena: the
-- player's team stands at the near end ("WaveStand") and the endless waves will come from the far
-- end ("WaveSpawn").
local function mountains(root: Instance, rng: Random)
	local f = folder(root, "Mountains")
	local GAP, N = 32, 26 -- degrees left open either side of north; mountains in the ring
	for i = 0, N - 1 do
		local a = rad(-90 + GAP + i * (360 - 2 * GAP) / (N - 1))
		local foot = rng:NextNumber(165, 220)
		local dist = World.HUB_RADIUS + 60 + foot
		local blocked = false
		for _, way in RANCH_ANGLE do
			blocked = blocked or inPass(a, dist, foot, rad(way))
		end
		if not blocked then
			mountain(f, Vector3.new(math.cos(a), 0, math.sin(a)) * dist, foot, rng, Vector3.zero)
		end
	end
	for k = 0, 2 do
		for _, side in { -1, 1 } do
			local z = -(ARENA_NEAR + 60 + k * 150)
			mountain(f, Vector3.new(side * (ARENA_HALF + 158), 0, z), 150, rng, Vector3.new(0, 0, z))
		end
	end
	mountain(f, Vector3.new(0, 0, -(ARENA_FAR + 260)), 230, rng, Vector3.new(0, 0, -ARENA_FAR))
	-- invisible wall round the hub, open at the canyon's mouth and at each pass; then up both
	-- sides of the canyon and across its end
	local half = ARENA_HALF + 10
	local mouth = math.deg(math.asin(half / World.HUB_RADIUS)) -- half-angle of the canyon mouth
	local openings = { { -90, mouth } }
	for _, way in RANCH_ANGLE do
		table.insert(openings, { way, math.deg(math.asin((PASS_HALF - 2) / World.HUB_RADIUS)) })
	end
	table.sort(openings, function(x, y)
		return x[1] < y[1]
	end)
	local function rim(degrees: number): Vector3
		return Vector3.new(math.cos(rad(degrees)), 0, math.sin(rad(degrees))) * World.HUB_RADIUS
	end
	for k, o in openings do
		local nxt = openings[k % #openings + 1]
		local from, to = o[1] + o[2], nxt[1] - nxt[2]
		if to < from then
			to += 360
		end
		local steps = math.ceil((to - from) / 9)
		for step = 0, steps - 1 do
			barrier(f, rim(from + (to - from) * step / steps), rim(from + (to - from) * (step + 1) / steps))
		end
	end
	local far = -(ARENA_FAR + 12)
	barrier(f, rim(-90 + mouth), Vector3.new(half, 0, far))
	barrier(f, rim(-90 - mouth), Vector3.new(-half, 0, far))
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
	-- the wave gate: a red crystal on a stone pillar beside the road; its prompt (tagged "WaveGate")
	-- opens the wave list on the client
	local at = Vector3.new(18, 0, -(ARENA_NEAR - 26))
	pillar(arena, at, 5, 1.6, STONE_DARK, M.Cobblestone)
	local crystal = ball(arena, at + Vector3.new(0, 7, 0), 3.4, Color3.fromRGB(220, 60, 60), M.Neon)
	glow(crystal, Color3.fromRGB(255, 90, 90), 22, 1.2)
	local gate = Instance.new("ProximityPrompt")
	gate.ActionText, gate.ObjectText = "Choose a wave", "Wave gate"
	gate.HoldDuration, gate.MaxActivationDistance, gate.RequiresLineOfSight = 0.3, 14, false
	gate.Parent = crystal
	CollectionService:AddTag(gate, "WaveGate")
end

-- Where a player stands after a wave: back at the arena's near end, on the road, facing the stand.
function World.arenaGate(): CFrame
	return CFrame.lookAt(Vector3.new(0, 3, -(ARENA_NEAR - 34)), Vector3.new(0, 3, -(ARENA_NEAR + 40)))
end

-- Ranches -------------------------------------------------------------------------------------------

local RED = Color3.fromRGB(196, 64, 54)
local HAY = Color3.fromRGB(232, 196, 110)
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

-- Wooden post-and-rail fence between two local points (y = 0) of `cf`.
local function fence(f: Instance, cf: CFrame, a: Vector3, b: Vector3)
	local n = math.max(1, math.round((b - a).Magnitude / 6))
	for k = 0, n do
		local p = (cf * CFrame.new(a:Lerp(b, k / n))).Position
		part(f, Vector3.new(0.9, 4.6, 0.9), CFrame.new(p + Vector3.new(0, 2.3, 0)) * cf.Rotation, WOOD_DARK, M.Wood)
		part(f, Vector3.new(1.25, 0.35, 1.25), CFrame.new(p + Vector3.new(0, 4.75, 0)) * cf.Rotation, WOOD, M.Wood)
	end
	local wa, wb = (cf * CFrame.new(a)).Position, (cf * CFrame.new(b)).Position
	for _, y in { 1.8, 3.7 } do
		bar(f, wa + Vector3.new(0, y, 0), wb + Vector3.new(0, y, 0), 0.22, WOOD, M.Wood)
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

-- One home ranch plot, the part that never changes: lawn, fence, the stone gate with the owner
-- sign, the teleport pad, a mailbox, flowers, trees and the mountains. What stands on the plot
-- depends on its owner's upgrades and is built by Ranch.luau.
local function ranch(root: Instance, i: number, rng: Random)
	local f = folder(root, `Ranch{i}`)
	f:SetAttribute("Index", i)
	f:SetAttribute("Owner", 0)
	local cf = World.ranchFrame(i)
	local H = World.RANCH_HALF
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	part(f, Vector3.new(H * 2, 0.4, H * 2), at(0, 0.2, 0), Color3.fromRGB(120, 176, 84), M.Grass)
	-- fence with a gate gap facing the plaza
	fence(f, cf, Vector3.new(-H, 0, -H), Vector3.new(-8, 0, -H))
	fence(f, cf, Vector3.new(8, 0, -H), Vector3.new(H, 0, -H))
	fence(f, cf, Vector3.new(H, 0, -H), Vector3.new(H, 0, H))
	fence(f, cf, Vector3.new(H, 0, H), Vector3.new(-H, 0, H))
	fence(f, cf, Vector3.new(-H, 0, H), Vector3.new(-H, 0, -H))
	-- gate: stone pillars with lanterns, a wooden arch with the owner sign (World.setRanchOwner
	-- changes the text)
	for _, dx in { -8, 8 } do
		part(f, Vector3.new(3.4, 6, 3.4), at(dx, 3, -H), STONE_DARK, M.Cobblestone)
		part(f, Vector3.new(4, 0.7, 4), at(dx, 6.3, -H), STONE, M.Slate)
		part(f, Vector3.new(1.6, 7, 1.6), at(dx, 10, -H), WOOD_DARK, M.Wood)
		local lantern = part(f, Vector3.new(1.3, 1.7, 1.3), at(dx, 5, -H - 2.3), WARM, M.Neon)
		part(f, Vector3.new(1.7, 0.35, 1.7), at(dx, 6, -H - 2.3), INK, M.Metal)
		part(f, Vector3.new(0.3, 0.3, 1.2), at(dx, 6.1, -H - 1.6), INK, M.Metal)
		glow(lantern, WARM, 16, 1.2)
	end
	part(f, Vector3.new(18, 1, 1.4), at(0, 12.6, -H), WOOD_DARK, M.Wood)
	local sign = part(f, Vector3.new(14, 3.2, 0.6), at(0, 10.2, -H), WOOD, M.WoodPlanks)
	sign.Name = "OwnerSign"
	label(sign, "Free Ranch", WHITE, 0.6)
	-- teleport pad to the hub, just inside the gate
	teleporter(f, at(16, 0, -H + 6).Position, "hub", "Go to the hub")
	signboard(f, at(27, 0, -H + 3), 11, "To the hub", Color3.fromRGB(60, 130, 170), 3.2)
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
	mountainRing(f, cf.Position, RING, rng, cf.LookVector)
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
	signboard(f, CFrame.new(0, 0, 70), 26, "Welcome to Animal Stations!", Color3.fromRGB(90, 160, 80), 7)
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
	for i = 1, World.RANCHES do
		pass(root, i, rng)
	end
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

-- Builders shared with Ranch.luau, which builds what stands on each ranch plot.
World.kit = {
	disc = disc,
	ball = ball,
	bar = bar,
	glow = glow,
	signboard = signboard,
	lamp = lamp,
	tree = tree,
	flowers = flowers,
	egg = egg,
	fence = fence,
	barn = barn,
	silo = silo,
	pine = pine,
	bush = bush,
	rock = rock,
	eggLook = EGG_LOOK,
}

return World
