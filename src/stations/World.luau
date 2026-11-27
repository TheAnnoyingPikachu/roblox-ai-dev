--!strict
-- Animal Stations world (framework, decision 0029): the hub, a central plaza with the hatchery
-- gathering place (made of Blender models, decision 0064), and three home ranches (one per player). Each ranch is a
-- large separate area behind the hub's mountains, reached by teleport pad or up its own pass: a valley
-- (decision 0070, laid out in src/shared/ValleyMap.luau and written into the terrain by Valley.luau) with
-- the homestead in its middle and its six training grounds set into the land round it. A ranch is the
-- player's base, where animals live and train: its plot is built here, and what stands on it
-- by Ranch.luau from its owner's upgrades. Mountains ring every area to hide the void; a canyon through
-- the hub's mountains is the wave arena. Built once from parts, Roblox materials and terrain.
-- Display only: no game rules live here. Teleport prompts and the arena's stand and spawn are
-- tagged for the server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Props = require(script.Parent:WaitForChild("Props"))
local Battlefield = require(script.Parent:WaitForChild("Battlefield"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))
local Valley = require(script.Parent:WaitForChild("Valley"))
local ValleyMap = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ValleyMap"))
local StationRewards =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StationRewards"))
local StationConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StationConfig"))
local StationAssets = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StationAssets"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local World = {}

World.PLAZA = 48 -- plaza radius
World.HUB_RADIUS = 250 -- the walkable hub: an invisible wall stands here, the mountains behind it
-- The road north out of the hub (half width, and where the battlefield's ground begins).
local ARENA_HALF, ARENA_NEAR = 60, 330
-- The Legion's battlefield (decision 0108), where the wave fights happen: far to the north, past the canyon's
-- mountains, reached only through the wave portal. Its teams look north, to the castle.
World.FIELD = CFrame.new(0, 0, -(ARENA_NEAR + Battlefield.REACH))
World.PORTAL = Vector3.new(0, 0, -(ARENA_NEAR - 26)) -- the wave portal's ring, on the road at the canyon's mouth
World.PORTAL_RADIUS = 14 -- a player this near its middle is in it
World.SPAWN = Vector3.new(0, 0.6, 76)
World.RANCHES = 3 -- one home ranch per player; lobbies (servers) hold 3 players to match
World.RANCH_DIST = 900 -- hub centre to each ranch centre: two valleys side by side must not meet
World.RANCH_Y = 22 -- the homestead's ground: the hub's is at 0, and ValleyMap.HUB below the homestead
World.LAWN = 0 -- the homestead's lawn above that ground: none, it is the valley's own grass (a part's grass is far darker)
World.RANCH_GATE = ValleyMap.HOME - 8 -- a homestead's middle to its gate: just inside the round the valley levels
local PASS_HALF = 34 -- half the width of the pass from the hub up to each ranch
-- along a pass from the hub: where it starts to climb, and where it is up (ValleyMap's road, seen from the hub)
local PASS_TOP = World.RANCH_DIST - ValleyMap.ROAD_TOP
local PASS_RAMP = World.RANCH_DIST - ValleyMap.ROAD_FOOT
-- The ranches lie south, east and west of the hub; the wave arena is to the north.
local RANCH_ANGLE = { 90, 0, 180 }
local FLAT = Vector3.new(1, 0, 1)

local M = Enum.Material
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(45, 40, 55)
local STONE = Color3.fromRGB(226, 214, 190)
local STONE_DARK = Color3.fromRGB(190, 176, 150)
local PATH = Color3.fromRGB(214, 196, 160)
local WOOD = Color3.fromRGB(170, 118, 72)
local WOOD_DARK = Color3.fromRGB(112, 76, 48)
local BARK = Color3.fromRGB(96, 66, 44)
local LEAVES = { Color3.fromRGB(84, 150, 64), Color3.fromRGB(106, 166, 70), Color3.fromRGB(126, 176, 70) } -- decision 0085
local FLOWERS = {
	Color3.fromRGB(255, 140, 185),
	Color3.fromRGB(255, 225, 100),
	Color3.fromRGB(185, 150, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 160, 110),
	Color3.fromRGB(140, 200, 255),
}
local WARM = Color3.fromRGB(255, 210, 150)
local GRASS = Color3.fromRGB(108, 168, 72) -- terrain grass, and the parts that continue it (decision 0085)
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

-- Scenery models (decision 0085): a faceted tree, pine or bush stood at `base`, turned at random, at
-- `scale`. It loads in the background (the first of a kind has to), so nothing waits; until it has (or
-- if it never does), `fallback` builds the old one of parts. A tree keeps an unseen trunk to bump into.
local function standModel(
	parent: Instance,
	kinds: { string },
	base: Vector3,
	scale: number,
	rng: Random,
	fallback: () -> ()
)
	local name = kinds[rng:NextInteger(1, #kinds)]
	local at = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	task.spawn(function()
		if Creatures.still(name, at, scale, parent) == nil then
			fallback()
		end
	end)
end

-- Round cartoon tree: trunk plus two or three leaf balls (the fallback of the faceted ones).
local function ballTree(parent: Instance, base: Vector3, rng: Random, scale: number)
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

local function tree(parent: Instance, base: Vector3, rng: Random, scale: number)
	local trunk = pillar(parent, base, 8 * scale, 1.4 * scale, BARK, M.Wood)
	trunk.Transparency, trunk.Name = 1, "Trunk"
	local seed = rng:NextInteger(1, 1e6) -- what the fallback would have rolled, without changing `rng`'s sequence
	standModel(parent, { "scenery_tree_1", "scenery_tree_2", "scenery_tree_3" }, base, scale, rng, function()
		ballTree(parent, base, Random.new(seed), scale)
	end)
end

local function flowers(parent: Instance, centre: Vector3, rng: Random, n: number, spread: number)
	for _ = 1, n do
		local p = centre + Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread))
		pillar(parent, p, 0.8, 0.08, Color3.fromRGB(70, 140, 60))
		ball(parent, p + Vector3.new(0, 0.9, 0), 0.7, FLOWERS[rng:NextInteger(1, #FLOWERS)])
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

-- An egg of type `kind` standing at `at` (its front along the CFrame's look), its shell `h` studs tall:
-- the Blender model (decision 0057), or the plain spotted shell when that is not uploaded or did not
-- load. Returns an unseen part the size of the shell, there at once: for a prompt, a light, sparkles.
local EGG_BUILT = 3 -- the height of a model's shell as it was built
local function eggModel(parent: Instance, at: CFrame, h: number, kind: string, rng: Random): Part
	local look = EGG_LOOK[kind] or EGG_LOOK.meadow
	local holder = part(parent, Vector3.new(h * 0.75, h, h * 0.75), at * CFrame.new(0, h / 2, 0), look.body)
	holder.Name, holder.Transparency = "Egg", 1
	task.spawn(function() -- the first of a kind has to load
		if Creatures.still(`egg_{kind}`, at, h / EGG_BUILT, parent) == nil then
			egg(parent, at.Position, h, look.body, look.spot, rng)
		end
	end)
	return holder
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
local function wedgePine(parent: Instance, base: Vector3, s: number, rng: Random)
	pillar(parent, base, 3 * s, 0.55 * s, BARK, M.Wood)
	local green = PINE[rng:NextInteger(1, #PINE)]
	local spin = CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
	for k = 0, 2 do
		local tier = CFrame.new(base + Vector3.new(0, (2 + 2.5 * k) * s, 0)) * spin
		pyramid(parent, tier, (7 - 1.7 * k) * s, 4.6 * s, green:Lerp(WHITE, 0.05 * k))
	end
end

local function pine(parent: Instance, base: Vector3, s: number, rng: Random)
	local trunk = pillar(parent, base, 6 * s, 1.2 * s, BARK, M.Wood)
	trunk.Transparency, trunk.Name = 1, "Trunk"
	local seed = rng:NextInteger(1, 1e6)
	standModel(parent, { "scenery_pine_1", "scenery_pine_2" }, base, s, rng, function()
		wedgePine(parent, base, s, Random.new(seed))
	end)
end

local function ballBush(parent: Instance, at: Vector3, s: number, rng: Random)
	local green = LEAVES[rng:NextInteger(1, #LEAVES)]
	for _ = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-1, 1), 0.8 + rng:NextNumber(0, 0.5), rng:NextNumber(-1, 1)) * s
		ball(parent, at + off, rng:NextNumber(2, 2.8) * s, green:Lerp(WHITE, rng:NextNumber(0, 0.08)), M.SmoothPlastic)
	end
end

local function bush(parent: Instance, at: Vector3, s: number, rng: Random)
	local seed = rng:NextInteger(1, 1e6)
	standModel(parent, { "scenery_bush_1" }, at, s, rng, function()
		ballBush(parent, at, s, Random.new(seed))
	end)
end

-- A boulder: a cluster of tilted blocks, about `s` studs across (decision 0085: three, and a pebble).
local function rock(parent: Instance, at: Vector3, s: number, rng: Random)
	for k = 1, 3 do
		local size = Vector3.new(rng:NextNumber(0.9, 1.4), rng:NextNumber(0.6, 0.9), rng:NextNumber(0.8, 1.2)) * s / k
		local turn = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3))
		local where = at + Vector3.new((k - 1) * s * 0.8, size.Y * 0.35, (k - 1) * s * 0.3)
		part(parent, size, CFrame.new(where) * turn, STONE_DARK:Lerp(INK, rng:NextNumber(0.25, 0.5)), M.Slate)
	end
	local pebble = at + Vector3.new(-0.7 * s, 0.1 * s, 0.6 * s)
	part(parent, Vector3.new(0.35, 0.25, 0.3) * s, CFrame.new(pebble), STONE_DARK:Lerp(INK, 0.4), M.Slate)
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
	-- decision 0085: a later, warmer afternoon, soft haze, gentle grading
	Lighting.ClockTime = 15.6
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(96, 92, 104)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 136, 150)
	Lighting.ShadowSoftness = 0.35
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.33,
		Offset = 0.15,
		Color = Color3.fromRGB(214, 222, 236),
		Decay = Color3.fromRGB(150, 140, 170),
		Glare = 0.35,
		Haze = 1.6,
	})
	effect("BloomEffect", { Intensity = 0.35, Size = 24, Threshold = 1.6 })
	effect("SunRaysEffect", { Intensity = 0.1, Spread = 0.6 })
	effect("ColorCorrectionEffect", {
		Saturation = 0.08,
		Contrast = 0.1,
		Brightness = 0.01,
		TintColor = Color3.fromRGB(255, 246, 232),
	})
	effect("DepthOfFieldEffect", { FarIntensity = 0.25, FocusDistance = 120, InFocusRadius = 140, NearIntensity = 0 })
end

-- Blades of grass grow on Grass and up through whatever lies flat on it (a floor, a pond, a path):
-- under such places the ground is LeafyGrass, which has none (decision 0085). A round `r` about `centre`,
-- a few studs deep, one 4-stud row at a time (voxels lie on a 4-stud grid).
local function calm(t: Terrain, centre: Vector3, r: number)
	for z = -r, r, 4 do
		local x = math.max(2, math.sqrt(math.max(0, r * r - z * z))) -- a row of no width is an error
		local lo, hi = centre + Vector3.new(-x, -8, z), centre + Vector3.new(x, 4, z + 4)
		t:ReplaceMaterial(Region3.new(lo, hi):ExpandToGrid(4), 4, M.Grass, M.LeafyGrass)
	end
end

local function terrain()
	local t = Workspace.Terrain
	t:Clear() -- a rebuild must not keep the old hills
	t:SetMaterialColor(M.Grass, GRASS)
	Valley.colours(t)
	-- voxels snap up: a block whose top is at y = -2 gives a surface at y = 0 (checked in Studio)
	t:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1500, 12, 1500), M.Grass)
	-- the short blades of grass are the place's (stations.project.json): a script may not set them
	local clouds = t:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Color = 0.45, 0.6, WHITE
	clouds.Parent = t
	-- each ranch's valley: level land round it at the hub's height, then the valley itself
	for i = 1, World.RANCHES do
		local frame = World.ranchFrame(i)
		local span = ValleyMap.HALF * 2 + 400
		t:FillBlock(CFrame.new(frame.Position.X, -8, frame.Position.Z), Vector3.new(span, 12, span), M.Grass)
		Valley.write(t, frame)
		Valley.den(t, frame)
		Valley.tops(t, frame)
		calm(t, frame.Position, ValleyMap.HOME) -- the whole homestead: no blades up through a floor or path
		-- and the road up to it from the hub (its pass is straight along an axis, so one box covers it)
		local a = rad(RANCH_ANGLE[i])
		local dir, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
		local from = dir * (World.HUB_RADIUS - 8) - side * 13 - Vector3.new(0, 10, 0)
		local to = dir * (World.RANCH_DIST - World.RANCH_GATE + 4) + side * 13 + Vector3.new(0, World.RANCH_Y + 8, 0)
		local region = Region3.new(from:Min(to), from:Max(to)):ExpandToGrid(4)
		t:ReplaceMaterial(region, 4, M.Grass, M.LeafyGrass)
	end
	calm(t, Vector3.zero, World.PLAZA + 6) -- the hub's plaza floor
	-- the battlefield's ground (decision 0108) begins at the hub's north edge: no terrain under it, between
	-- the ranches' land (their level fill reaches 248 studs from the middle in x and 648 north), then full width
	local half = World.RANCH_DIST - (ValleyMap.HALF * 2 + 400) / 2 - 4
	t:FillBlock(CFrame.new(0, -8, -(ARENA_NEAR + 760) / 2), Vector3.new(half * 2, 16, 760 - ARENA_NEAR), M.Air)
	t:FillBlock(CFrame.new(0, -8, -705), Vector3.new(1500, 16, 90), M.Air)
	-- and no blades up through the portal's stone floor
	local near, far = Vector3.new(-(ARENA_HALF + 20), -10, -(ARENA_NEAR + 20)), Vector3.new(ARENA_HALF + 20, 4, -270)
	t:ReplaceMaterial(Region3.new(near, far):ExpandToGrid(4), 4, M.Grass, M.LeafyGrass)
end

-- Plaza ----------------------------------------------------------------------------------------------

-- The plaza is a place to gather (decision 0064), made of the models of
-- tools/blender/stations/assets/hub.py. Each was built where it stands, so every one goes on the
-- plaza's middle. Where an egg, an animal or an unseen wall goes below is read off
-- tools/blender/stations/scenes/hub_commons.py, in its own numbers (x east, y north, in studs from the
-- plaza's middle): change the two together.
local Y0 = 0.25 -- the plaza's ground
local GROUND = 0.05 -- and how far above it the lawn's top is (watering_hole.py GROUND)
local CENTRE =
	{ "hub_ground", "hub_pond", "hub_trading", "hub_gifts", "hub_fame", "hub_board", "hub_camp", "hub_lights" }
-- watering_hole.py's numbers: each stop's (radius, angle), the statue's rock, the acacia, the ring path
local STOPS = {
	trading = { 38, 45 },
	gifts = { 38, 135 },
	camp = { 38, 225 },
	fame = { 38, 315 },
	board = { 37, 258 },
	best = { 37, 287 }, -- the top-100 board (decision 0129), between the notice board and the Hall of Fame
}
local ROCK = { 0, -12.5, 3.6, 3.52 } -- middle x, y; radius; the top the statue stands on
local ACACIA = { -10.5, 10.5 }
local RING_OUT = 30
local FAME = 4
-- who stands about: species, variant, where, and its yaw there
local VISITORS: { { any } } = {
	{ "flamingo", nil, 3, 5, 0.1, 200 }, -- in the shallows
	{ "elephant", nil, 16.5, 3, 0, 270 }, -- drinking on the east bank
	{ "giraffe", nil, -15, 14, 0, 120 }, -- under the acacia
	{ "rhino", nil, -16.5, -1, 0, 80 }, -- on the west bank
	{ "tortoise", nil, 8, -10, 0, 160 },
	{ "meerkat", nil, -23.5, -31, 0, 40 }, -- at the campfire
	{ "meerkat", "star_meerkat", -31, -23.5, 0, 60 },
	{ "jackal", nil, 21, 33.5, 0, 220 }, -- by the trading post
	{ "cheetah", nil, 26, -6, 0.1, 10 }, -- on the ring path
}

-- A point on the plaza: `x` studs east and `y` north of its middle, `up` above its ground.
local function onPlaza(x: number, y: number, up: number): Vector3
	return Vector3.new(x, Y0 + up, -y)
end

-- The same from a distance `r` and a direction `deg` (0 east, 90 north).
local function around(r: number, deg: number, up: number): Vector3
	return onPlaza(r * math.cos(rad(deg)), r * math.sin(rad(deg)), up)
end

-- The CFrame of something standing on (x, y, up) and facing `yaw` degrees, as the Blender scenes turn things.
local function standing(x: number, y: number, up: number, yaw: number): CFrame
	local p = onPlaza(x, y, up)
	return CFrame.lookAt(p, p + Vector3.new(math.sin(rad(yaw)), 0, math.cos(rad(yaw))))
end

-- The models take no collisions: each solid piece gets an unseen part to stand on or walk into.
local function solid(p: Part): Part
	p.Transparency, p.CastShadow, p.Name = 1, false, "Solid"
	return p
end

-- A stop's middle (x, y) and the yaw that turns its front (local -y) to the plaza's middle.
local function stopAt(name: string): (number, number, number)
	local s = STOPS[name]
	return s[1] * math.cos(rad(s[2])), s[1] * math.sin(rad(s[2])), s[2] - 90
end

local statueFolder: Instance? = nil
local statueMonth = -1
local fameFolder: Instance? = nil
local boardText: TextLabel? = nil
local bestColumns: { TextLabel } = {}

-- The statue on the rock by the pond: the month's rainbow animal (StationRewards.rainbowOf), twice size,
-- facing the south road where players come in. Stood again when the month changes.
local function standStatue()
	local month = StationRewards.monthOf(os.time())
	if month == statueMonth or statueFolder == nil then
		return
	end
	statueMonth = month
	local f = statueFolder :: Instance
	f:ClearAllChildren()
	local s = StationRewards.rainbowOf(month)
	local p = onPlaza(ROCK[1], ROCK[2], ROCK[4])
	local model = Creatures.spawn(
		Creatures.asset(s, nil),
		CFrame.lookAt(p, p + Vector3.new(0, 0, 1)),
		f,
		{ model = Creatures.asset(s, nil), size = 2 },
		true
	)
	if model then
		Creatures.describe(model, s, nil)
		model:SetAttribute("Statue", true)
	end
	local sp = StationConfig.species(s)
	if boardText then
		(boardText :: TextLabel).Text = table.concat({
			"RAINBOW OF THE MONTH",
			`The Rainbow {if sp then sp.name else s}!`,
			"Log in on 28 days this month to win it (Gifts, This month).",
			"",
			"DAILY WHEEL: one free spin a day.",
			"1 in 400 wins a Rainbow mythic.",
			"",
			"WAVES: every 10th wave is a boss.",
		}, "\n")
	end
end

-- The Hall of Fame (decision 0095): the best animals in this server on its pedestals, each with its
-- owner's name. `best` is a list of { s, v, rainbow, owner }, best first (StationsServer chooses).
function World.setFame(best: { { s: string, v: string?, rainbow: boolean?, coat: string?, owner: string } })
	local f = fameFolder
	if f == nil then
		return
	end
	f:ClearAllChildren()
	local x0, y0, yaw = stopAt("fame")
	local c, s = math.cos(rad(yaw)), math.sin(rad(yaw))
	for i = 1, math.min(FAME, #best) do
		local a = best[i]
		local lx = (i - (FAME + 1) / 2) * 4.4
		local ly = 0.8 + math.abs(i - (FAME + 1) / 2) * 0.8
		local x, y = x0 + lx * c - ly * s, y0 + lx * s + ly * c
		local p = onPlaza(x, y, GROUND + 2)
		task.spawn(function()
			local asset = Creatures.asset(a.s, a.v)
			local size = StationAssets[asset] and StationAssets[asset].size or { 4, 4, 4 }
			local fit = math.min(1, 3.4 / math.max(size[1], size[3], 0.1)) -- small enough for its pedestal
			local model = Creatures.spawn(
				asset,
				CFrame.lookAt(p, p + Vector3.new(-x, 0, y).Unit),
				f,
				{ model = asset, size = fit },
				a.coat or a.rainbow
			)
			if model then
				Creatures.describe(model, a.s, a.v)
			end
		end)
		local plate = part(
			f,
			Vector3.new(1.6, 0.5, 0.25),
			CFrame.lookAt(onPlaza(x, y, GROUND + 0.9), onPlaza(0, 0, GROUND + 0.9)) * CFrame.new(0, 0, -1.7),
			WHITE
		)
		plate.Transparency, plate.CanCollide = 1, false
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromOffset(160, 30), Vector3.new(0, 0.6, 0), 60
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency, t.Font, t.TextScaled = UDim2.fromScale(1, 1), 1, Enum.Font.FredokaOne, true
		t.TextColor3, t.TextStrokeTransparency, t.Text = Color3.fromRGB(255, 225, 120), 0.3, a.owner
		t.Parent = gui
		gui.Parent = plate
	end
end

-- A prompt at a stop's counter, tagged so the HUD opens its menu.
local function counterPrompt(f: Instance, name: string, tag: string, action: string, object: string)
	local x, y, yaw = stopAt(name)
	local c, s = math.cos(rad(yaw)), math.sin(rad(yaw))
	local lx, ly = 0, -3.6
	local at = onPlaza(x + lx * c - ly * s, y + lx * s + ly * c, GROUND + 1.5)
	local spot = part(f, Vector3.new(4, 3, 1), CFrame.new(at), WHITE)
	spot.Transparency, spot.CanCollide, spot.CastShadow, spot.Name = 1, false, false, tag
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = action, object
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.2, 12, false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- the client draws a paper pill (STATION-162)
	prompt.Parent = spot
	CollectionService:AddTag(prompt, tag)
end

local function plaza(root: Instance, _rng: Random)
	local f = folder(root, "Plaza")
	-- an unseen floor under the lawn: what feet stand on
	local floor =
		disc(f, Vector3.new(0, Y0 + GROUND - 0.4, 0), World.PLAZA * 2 + 1, 0.8, Color3.fromRGB(128, 184, 86), M.Grass)
	floor.Transparency = 1
	for _, name in CENTRE do
		task.spawn(Creatures.still, name, CFrame.new(0, Y0, 0) * CFrame.Angles(0, math.pi, 0), 1, f) -- each has to load
	end
	-- An unseen block of a piece that stands on (px, py) turned `yaw`: `w` by `d` and `h` tall, its
	-- middle at (x, y) of the piece, its foot `from` above the lawn.
	local function block(
		px: number,
		py: number,
		yaw: number,
		x: number,
		y: number,
		w: number,
		d: number,
		h: number,
		from: number?
	)
		local c, s = math.cos(rad(yaw)), math.sin(rad(yaw))
		local where = onPlaza(px + x * c - y * s, py + x * s + y * c, GROUND + (from or 0) + h / 2)
		solid(part(f, Vector3.new(w, h, d), CFrame.new(where) * CFrame.Angles(0, rad(yaw), 0), WHITE))
	end
	local function column(x: number, y: number, radius: number, h: number, from: number?)
		solid(pillar(f, onPlaza(x, y, GROUND + (from or 0)), h, radius, WHITE))
	end

	-- the statue's rock and the acacia's trunk
	column(ROCK[1], ROCK[2], ROCK[3] + 0.9, ROCK[4])
	column(ACACIA[1], ACACIA[2], 1.1, 9)
	-- the two stalls: floor, counter, back wall, posts
	for _, name in { "trading", "gifts" } do
		local x, y, yaw = stopAt(name)
		block(x, y, yaw, 0, 0, 9, 6, 0.35)
		block(x, y, yaw, 0, -2, 8.6, 1.4, 3.05)
		block(x, y, yaw, 0, 2.8, 8.6, 0.4, 5.95)
	end
	-- the Hall of Fame's pedestals and its arch's two columns
	do
		local x0, y0, yaw = stopAt("fame")
		local c, s = math.cos(rad(yaw)), math.sin(rad(yaw))
		for i = 1, FAME do
			local lx = (i - (FAME + 1) / 2) * 4.4
			local ly = 0.8 + math.abs(i - (FAME + 1) / 2) * 0.8
			column(x0 + lx * c - ly * s, y0 + lx * s + ly * c, 1.5, 2)
		end
		for _, lx in { -9.2, 9.2 } do
			column(x0 + lx * c - 1.4 * s, y0 + lx * s + 1.4 * c, 0.5, 7)
		end
	end
	-- the notice board, and the writing on it
	do
		local x, y, yaw = stopAt("board")
		block(x, y, yaw, 0, 0, 7.4, 0.4, 4.4, 1.6)
		for _, lx in { -3.4, 3.4 } do
			block(x, y, yaw, lx, 0, 0.6, 0.6, 7.2)
		end
		local c, s = math.cos(rad(yaw)), math.sin(rad(yaw))
		local at = onPlaza(x - -0.32 * s, y + -0.32 * c, GROUND + 3.8)
		local paper = part(f, Vector3.new(6.8, 3.8, 0.1), CFrame.lookAt(at, onPlaza(0, 0, GROUND + 3.8)), WHITE)
		paper.Transparency, paper.CanCollide, paper.CastShadow, paper.Name = 1, false, false, "NoticePaper"
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, 40, 0.3
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		t.Font, t.TextScaled, t.TextColor3 = Enum.Font.FredokaOne, true, Color3.fromRGB(58, 36, 18)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight =
			UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 16), UDim.new(0, 16)
		pad.Parent = t
		t.Parent = gui
		gui.Parent = paper
		boardText = t
	end
	-- the top-100 board (decision 0129): wooden posts and a cream sheet in four columns of 25, written by setBest
	do
		local x, y, yaw = stopAt("best")
		local c, s = math.cos(rad(yaw)), math.sin(rad(yaw))
		local wood = Color3.fromRGB(122, 82, 46)
		for _, lx in { -6.4, 6.4 } do
			local post =
				part(f, Vector3.new(0.7, 9, 0.7), CFrame.new(onPlaza(x + lx * c, y + lx * s, GROUND + 4.5)), wood)
			post.Material = Enum.Material.Wood
		end
		local at = onPlaza(x, y, GROUND + 5)
		local sheet = part(
			f,
			Vector3.new(12.4, 7, 0.3),
			CFrame.lookAt(at, onPlaza(0, 0, GROUND + 5)),
			Color3.fromRGB(250, 238, 210)
		)
		sheet.Name, sheet.CastShadow = "BestBoard", false
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, 40, 0.3
		local title = Instance.new("TextLabel")
		title.Size, title.BackgroundTransparency = UDim2.fromScale(1, 0.12), 1
		title.Font, title.TextScaled, title.TextColor3 = Enum.Font.FredokaOne, true, Color3.fromRGB(58, 36, 18)
		title.Text = "BEST WAVES · ALL SERVERS"
		title.Parent = gui
		for k = 1, 4 do
			local t = Instance.new("TextLabel")
			t.Position, t.Size = UDim2.new((k - 1) / 4, 8, 0.13, 0), UDim2.new(0.25, -16, 0.85, 0)
			t.BackgroundTransparency, t.TextXAlignment, t.TextYAlignment =
				1, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
			t.Font, t.TextScaled, t.TextColor3 = Enum.Font.FredokaOne, true, Color3.fromRGB(58, 36, 18)
			t.Text = ""
			t.Parent = gui
			bestColumns[k] = t
		end
		gui.Parent = sheet
	end
	-- the campfire's stone ring and its four logs
	do
		local x, y = stopAt("camp")
		column(x, y, 3, 0.9)
		for i = 0, 3 do
			local a = rad(i * 90 + 45)
			local cx, cy = x + math.cos(a) * 6.2, y + math.sin(a) * 6.2
			block(cx, cy, i * 90 + 45, 0, 0, 1.2, 4.8, 1.2)
		end
	end
	-- the lamps round the ring path (as watering_hole.py `lights`)
	local taken = { 0, 90, 180, 270 }
	for _, st in STOPS do
		table.insert(taken, st[2])
	end
	for i = 0, 15 do
		local a = i * 22.5 + 11.25
		local near = 360
		for _, t in taken do
			near = math.min(near, math.abs((a - t + 180) % 360 - 180))
		end
		if near >= 9 then
			solid(pillar(f, around(RING_OUT + 1.6, a, GROUND), 6.5, 0.3, WHITE))
		end
	end

	-- the prompts at the two stalls
	counterPrompt(f, "trading", "HubTrade", "Trade", "Trading Post")
	counterPrompt(f, "gifts", "HubGifts", "Open", "Daily Gifts")

	-- the statue, the Hall of Fame's animals (StationsServer fills it), and the animals that stand about
	statueFolder = folder(f, "Statue")
	fameFolder = folder(f, "HallOfFame")
	task.spawn(function()
		while true do
			standStatue()
			task.wait(600)
		end
	end)
	for _, v in VISITORS do
		task.spawn(function()
			local model = Creatures.spawn(Creatures.asset(v[1], v[2]), standing(v[3], v[4], GROUND + v[5], v[6]), f)
			if model then
				Creatures.describe(model, v[1], v[2])
			end
		end)
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
-- Write the top-100 board (decision 0129): `rows` are "1. Name  wave", 25 to a column.
function World.setBest(rows: { string })
	for k, t in bestColumns do
		local chunk = {}
		for i = (k - 1) * 25 + 1, math.min(k * 25, #rows) do
			table.insert(chunk, rows[i])
		end
		t.Text = if k == 1 and #rows == 0 then "No best waves yet" else table.concat(chunk, "\n")
	end
end

function World.hubSpawn(): CFrame
	return CFrame.lookAt(Vector3.new(0, 3, 80), Vector3.new(0, 3, 0))
end

local function paths(root: Instance)
	local f = folder(root, "Paths")
	for _, seg in ROADS do
		local a, b = seg[1], seg[2]
		-- no blades of grass up through the road (decision 0085): the roads lie along x or z
		local lo, hi = a:Min(b) - Vector3.new(10, 8, 10), a:Max(b) + Vector3.new(10, 4, 10)
		Workspace.Terrain:ReplaceMaterial(Region3.new(lo, hi):ExpandToGrid(4), 4, M.Grass, M.LeafyGrass)
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
	-- no teleport pad here any more: the HUD's Travel buttons go anywhere (decision 0093)
end

-- Mountains and the wave arena ---------------------------------------------------------------------

local ROCKS = { Color3.fromRGB(150, 142, 132), Color3.fromRGB(136, 128, 120), Color3.fromRGB(164, 154, 140) } -- decision 0085
local SNOW = Color3.fromRGB(240, 244, 250)
local FOOTHILL = Color3.fromRGB(100, 156, 82)

-- A mountain: a huge rock dome with two higher peaks capped with snow. `pos` is
-- the centre of its foot circle on the ground and `foot` that circle's radius. With `toward`
-- (the place it is seen from) it also gets what shows up close on that side: grassy foothills
-- with pines, and lumps and ledges of rock on the slope.
local function mountain(parent: Instance, pos: Vector3, foot: number, rng: Random, toward: Vector3?)
	local r = foot / math.sqrt(1 - 0.25 ^ 2)
	local stone = ROCKS[rng:NextInteger(1, #ROCKS)]:Lerp(INK, rng:NextNumber(0, 0.12))
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
	for _ = 1, 4 do -- pines up the slope it shows (decision 0085)
		local out = onSlope(base + rng:NextNumber(-0.9, 0.9), rng:NextNumber(0.3, 0.6))
		pine(parent, core + out * (r - 1), rng:NextNumber(1.6, 2.6), rng)
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

-- Where no mountain may stand: the hub, the arena's canyon, every ranch plot and clearing (circles), and
-- every pass (a strip from `a` to `b`). `r` is how near a mountain's foot may come to the middle or the
-- line. Filled by `layout` before anything is built.
type Zone = { a: Vector3, b: Vector3?, r: number }
local zones: { Zone } = {}

local function layout()
	table.clear(zones)
	table.insert(zones, { a = Vector3.zero, r = World.HUB_RADIUS + 40 })
	table.insert(zones, { a = Vector3.new(0, 0, -World.HUB_RADIUS), b = World.FIELD.Position, r = ARENA_HALF + 6 })
	table.insert(zones, { a = World.FIELD.Position + Vector3.new(0, 0, 280), b = World.FIELD.Position, r = 320 })
	-- a ranch's valley is its own land as far as its unseen wall: mountains stand on its rim beyond that,
	-- where they hide the straight outer faces of the square it is written in
	for i = 1, World.RANCHES do
		local home = World.ranchFrame(i).Position * FLAT
		table.insert(zones, { a = Vector3.zero, b = home, r = PASS_HALF - 12 })
		table.insert(zones, { a = home, r = ValleyMap.WALL + 12 })
	end
end

-- True when a mountain at `c` with a foot of radius `foot` keeps out of every zone.
local function clearOf(c: Vector3, foot: number): boolean
	local p = c * FLAT
	for _, z in zones do
		local nearest = z.a
		if z.b then
			local along = z.b - z.a
			nearest = z.a + along * math.clamp((p - z.a):Dot(along) / along:Dot(along), 0, 1)
		end
		if (p - nearest).Magnitude - foot < z.r then
			return false
		end
	end
	return true
end

-- A mountain seated against the point `base`, reaching away from it along `u` (its middle is `lean`
-- feet out): as big as `foot` if that keeps out of every zone, else smaller, down to `least`; none if
-- even that does not fit.
local function seated(
	parent: Instance,
	base: Vector3,
	u: Vector3,
	foot: number,
	lean: number,
	least: number,
	rng: Random,
	toward: Vector3?
)
	local f = foot
	while f >= least do
		local c = base + u * f * lean
		if clearOf(c, f) then
			mountain(parent, c, f, rng, toward)
			return
		end
		f *= 0.86
	end
end

-- An invisible wall round `centre` at `radius`, open at each way out: {a unit vector, half the gap's width}.
local function wallRound(parent: Instance, centre: Vector3, radius: number, ways: { { any } })
	local gaps = {}
	for _, w in ways do
		table.insert(gaps, { math.atan2(w[1].Z, w[1].X), math.asin(w[2] / radius) })
	end
	table.sort(gaps, function(x, y)
		return x[1] < y[1]
	end)
	local function rim(a: number): Vector3
		return centre + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
	end
	for k, gap in gaps do
		local nxt = gaps[k % #gaps + 1]
		local from, to = gap[1] + gap[2], nxt[1] - nxt[2]
		if to < from then
			to += math.pi * 2
		end
		local steps = math.ceil((to - from) / rad(15))
		for s = 0, steps - 1 do
			barrier(parent, rim(from + (to - from) * s / steps), rim(from + (to - from) * (s + 1) / steps))
		end
	end
end

-- True when a mountain `dist` out at angle `a` (foot radius `foot`) would stand in a pass that
-- leaves along angle `way`.
local function inPass(a: number, dist: number, foot: number, way: number): boolean
	return math.cos(a - way) > 0 and math.abs(math.sin(a - way)) * dist < PASS_HALF + foot
end

-- What closes ranch `i`'s valley: an unseen wall inside its rim, open only to the pass from the hub,
-- and a ring of mountains seated on the rim, behind the valley's own ridge.
local function valleyRim(parent: Instance, i: number, rng: Random)
	local cf = World.ranchFrame(i)
	local home = cf.Position
	wallRound(parent, home, ValleyMap.WALL, { { cf.LookVector, PASS_HALF - 2 } })
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2
		local u = Vector3.new(math.cos(a), 0, math.sin(a))
		seated(parent, home * FLAT + u * (ValleyMap.WALL + 12), u, rng:NextNumber(130, 175), 1, 70, rng, nil)
	end
end

-- The pass from the hub up to ranch `i`: a road through its own canyon, level from the hub's
-- wall, then climbing to the ranch. Mountains and invisible walls line both sides, so a ranch
-- can be walked (and one day ridden) to as well as teleported to.
local function pass(root: Instance, i: number, rng: Random)
	local f = folder(root, `Pass{i}`)
	local a = rad(RANCH_ANGLE[i])
	local dir, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
	local gate = World.RANCH_DIST - World.RANCH_GATE
	local function height(s: number): number
		return World.RANCH_Y * math.clamp((s - PASS_RAMP) / (PASS_TOP - PASS_RAMP), 0, 1)
	end
	-- a point `s` studs along the pass from the hub's middle, `across` to one side, `up` above the ground
	local function at(s: number, across: number, up: number?): Vector3
		return dir * s + side * across + Vector3.new(0, height(s) + (up or 0), 0)
	end
	-- the road, on the valley's own ground (ValleyMap's road), as far as the ranch's own path
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
	for k, s in { World.HUB_RADIUS + 130, World.HUB_RADIUS + 220, World.HUB_RADIUS + 310, World.RANCH_DIST - 165 } do
		for _, sx in { -1, 1 } do
			local foot = if k == 4 then rng:NextNumber(86, 92) else rng:NextNumber(140, 165)
			seated(f, at(s, sx * PASS_HALF), side * sx, foot, 0.94, 60, rng, at(s, 0))
		end
	end
	local w = PASS_HALF - 2
	local from = math.sqrt(World.HUB_RADIUS ^ 2 - w ^ 2)
	local to = World.RANCH_DIST - math.sqrt(ValleyMap.WALL ^ 2 - w ^ 2)
	for _, sx in { -1, 1 } do
		barrier(f, dir * from + side * sx * w, dir * to + side * sx * w)
	end
end

-- The hub's mountains: a ring that is open to the north, where the road leaves for the battlefield
-- (Battlefield.luau: its approach and peaks), and to the three passes.
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
			local u = Vector3.new(math.cos(a), 0, math.sin(a))
			seated(f, u * (World.HUB_RADIUS + 60), u, foot, 1, 110, rng, Vector3.zero)
		end
	end
	-- invisible wall round the hub, open at the road north and at each pass; then up both sides of the
	-- approach and round the battlefield (as far as the castle's rock)
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
	local field = World.FIELD.Position
	local opens, wide, ends = field.Z + 360, 300, field.Z - 190
	for _, sx in { -1, 1 } do
		barrier(f, rim(-90 + sx * mouth), Vector3.new(sx * half, 0, opens))
		barrier(f, Vector3.new(sx * half, 0, opens), Vector3.new(sx * wide, 0, opens))
		barrier(f, Vector3.new(sx * wide, 0, opens), Vector3.new(sx * wide, 0, ends))
	end
	barrier(f, Vector3.new(-wide, 0, ends), Vector3.new(wide, 0, ends))

	local arena = folder(root, "WaveArena")
	-- the portal's stone floor across the road's mouth, over the seam where the battlefield's ground begins
	part(
		arena,
		Vector3.new(ARENA_HALF * 2 + 24, 0.4, 56),
		CFrame.new(0, 0.2, -(ARENA_NEAR - 12)),
		STONE_DARK,
		M.Cobblestone
	)
	-- the wave portal (decision 0108): a ring on the road and a standing portal behind it. Everyone in the
	-- ring when a fight starts goes through to the battlefield together (StationsServer). Its prompt (tagged
	-- "WaveGate") opens the wave list on the client.
	local VIOLET = Color3.fromRGB(112, 64, 255)
	local ring =
		disc(arena, World.PORTAL + Vector3.new(0, 0.5, 0), World.PORTAL_RADIUS * 2, 0.5, STONE_DARK, M.Cobblestone)
	ring.Name = "Portal"
	disc(arena, World.PORTAL + Vector3.new(0, 0.56, 0), World.PORTAL_RADIUS * 2 - 3, 0.5, VIOLET, M.Neon).CanCollide =
		false
	disc(arena, World.PORTAL + Vector3.new(0, 0.62, 0), World.PORTAL_RADIUS * 2 - 5, 0.5, STONE, M.Cobblestone)
	local back = World.PORTAL + Vector3.new(0, 0, -(World.PORTAL_RADIUS + 3))
	for i = 0, 15 do -- the standing portal: a ring of stone blocks round a violet glow
		local a = i * math.pi / 8
		part(
			arena,
			Vector3.new(4.6, 3.4, 3.4),
			CFrame.new(back + Vector3.new(math.cos(a) * 10, 11.5 + math.sin(a) * 10, 0))
				* CFrame.Angles(0, 0, a + math.pi / 2),
			if i % 2 == 0 then STONE_DARK else STONE,
			M.Cobblestone
		)
	end
	local glass = disc(arena, back + Vector3.new(0, 11.5, 0), 18, 0.6, VIOLET, M.Neon)
	glass.CFrame = CFrame.new(back + Vector3.new(0, 11.5, 0)) * CFrame.Angles(0, math.pi / 2, 0)
	glass.CanCollide, glass.Transparency = false, 0.2
	glow(glass, VIOLET, 30, 1.6)
	signboard(arena, CFrame.new(-24, 0, -(ARENA_NEAR - 26)), 24, "Wave Portal", Color3.fromRGB(96, 50, 176), 8)
	local gate = Instance.new("ProximityPrompt")
	gate.ActionText, gate.ObjectText = "Choose a wave", "Wave portal"
	gate.HoldDuration, gate.MaxActivationDistance, gate.RequiresLineOfSight = 0.3, World.PORTAL_RADIUS + 6, false
	gate.Style = Enum.ProximityPromptStyle.Custom -- the client draws a paper pill (STATION-162)
	gate.Parent = ring
	CollectionService:AddTag(gate, "WaveGate")
	Battlefield.build(folder(root, "Battlefield"), World.FIELD)
end

-- Where a player stands after a wave: on the road before the wave portal, outside its ring, facing it.
function World.arenaGate(): CFrame
	return CFrame.lookAt(Vector3.new(0, 3, -(ARENA_NEAR - 52)), Vector3.new(0, 3, -(ARENA_NEAR + 40)))
end

-- Whether `position` is in the wave portal's ring (decision 0108).
function World.inPortal(position: Vector3): boolean
	return ((position - World.PORTAL) * FLAT).Magnitude <= World.PORTAL_RADIUS
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

-- The frame of ranch `i`'s training ground `k` (StationConfig.STATIONS' order, as ValleyMap.GROUNDS):
-- half a stud under its levelled land, so that what an area's model has just above its own ground
-- lies on it; looking away from the homestead. An area's model has its gateway on its back, which so
-- faces the path in.
function World.areaFrame(i: number, k: number): CFrame
	local cf = World.ranchFrame(i)
	local g = ValleyMap.GROUNDS[k]
	local centre = cf * Vector3.new(g.x, g.h - 0.5, g.z)
	return CFrame.lookAt(centre, centre + cf:VectorToWorldSpace(Vector3.new(g.x, 0, g.z)).Unit)
end

-- In the homestead's own frame, for each ground: where its path leaves the homestead's lawn (its name
-- board stands there), and the ground's middle.
World.AREA_GATE, World.AREA_AT = {} :: { Vector3 }, {} :: { Vector3 }
for k, g in ValleyMap.GROUNDS do
	local out = Vector3.new(g.x, 0, g.z)
	World.AREA_GATE[k], World.AREA_AT[k] = out.Unit * (ValleyMap.HOME - 6), out
end

-- Where the owner spawns: just inside the gate, facing the barn.
function World.ranchSpawn(i: number): CFrame
	return World.ranchFrame(i) * CFrame.new(0, 3, -World.RANCH_GATE + 10) * CFrame.Angles(0, math.pi, 0)
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
	local G = World.RANCH_GATE
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- the homestead is open all round (decision 0072): its lawn is the round the valley levels for it
	-- gate: stone pillars with lanterns, a wooden arch with the owner sign (World.setRanchOwner
	-- changes the text). No fence leads off it: a low wall each side stops after a few steps.
	for _, dx in { -8, 8 } do
		part(f, Vector3.new(3.4, 6, 3.4), at(dx, 3, -G), STONE_DARK, M.Cobblestone)
		part(f, Vector3.new(4, 0.7, 4), at(dx, 6.3, -G), STONE, M.Slate)
		part(f, Vector3.new(1.6, 7, 1.6), at(dx, 10, -G), WOOD_DARK, M.Wood)
		local lantern = part(f, Vector3.new(1.3, 1.7, 1.3), at(dx, 5, -G - 2.3), WARM, M.Neon)
		part(f, Vector3.new(1.7, 0.35, 1.7), at(dx, 6, -G - 2.3), INK, M.Metal)
		part(f, Vector3.new(0.3, 0.3, 1.2), at(dx, 6.1, -G - 1.6), INK, M.Metal)
		glow(lantern, WARM, 16, 1.2)
		local side = dx / 8
		part(f, Vector3.new(13, 3, 2.2), at(side * 16.2, 1.5, -G), STONE_DARK, M.Cobblestone)
		part(f, Vector3.new(3, 4.2, 3), at(side * 24, 2.1, -G), STONE_DARK, M.Cobblestone)
		flowers(f, at(side * 16.5, World.LAWN, -G - 2.6).Position, rng, 8, 3)
	end
	part(f, Vector3.new(18, 1, 1.4), at(0, 12.6, -G), WOOD_DARK, M.Wood)
	local sign = part(f, Vector3.new(14, 3.2, 0.6), at(0, 10.2, -G), WOOD, M.WoodPlanks)
	sign.Name = "OwnerSign"
	label(sign, "Free Ranch", WHITE, 0.6)
	-- mailbox by the gate
	local box = at(12.5, 0, -G - 3.5)
	pillar(f, box.Position, 3.4, 0.25, WOOD_DARK, M.Wood)
	part(f, Vector3.new(1.4, 1.3, 2.2), box * CFrame.new(0, 4, 0), RED, M.SmoothPlastic)
	part(f, Vector3.new(0.15, 1, 0.5), box * CFrame.new(0.8, 4.5, 0.6), Color3.fromRGB(255, 220, 80), M.SmoothPlastic)
	-- the valley round it: its trees, waterfall and bridges, and what closes it
	Valley.dress(f, cf, rng, { tree = tree, pine = pine, rock = rock, bush = bush })
	valleyRim(f, i, rng)
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
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(80, World.HUB_RADIUS - 80)
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
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(World.HUB_RADIUS - 45, World.HUB_RADIUS - 5)
		if open(p, 4) then
			tree(f, p, rng, rng:NextNumber(1.3, 1.9))
		end
	end
	local beds = 0
	tries = 0
	while beds < 40 and tries < 2000 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(66, World.HUB_RADIUS - 70) -- clear of the market stalls
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
	layout()
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
	eggModel = eggModel,
	fence = fence,
	barn = barn,
	silo = silo,
	pine = pine,
	bush = bush,
	rock = rock,
	eggLook = EGG_LOOK,
}

return World
