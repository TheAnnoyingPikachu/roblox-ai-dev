--!strict
-- "Shrine of a Hundred Lanterns" (GDD I1, I2): the ground-level courtyard, night lighting, the
-- leaderboard board and the ambient life (fireflies, petals, fog, lantern flicker, idle yokai).
-- Built once at server start from parts, Roblox materials, terrain and the generated meshes in
-- Models (docs/assets/register.md). No game rules live here.
-- Decoration never touches combat: props placed through `prop` are ghosted (no collision or
-- queries, so movement and telegraph raycasts ignore them) and `spot` refuses the open floor.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local Arena = {}

-- Players stand at the shrine entrance facing the stage when a night starts (GDD B1, I1).
Arena.SPAWN = CFrame.lookAt(Vector3.new(0, 0, 80), Vector3.new(0, 0, 0))

local RADIUS = 100
local PIT = Vector3.new(0, 0, -65)
-- The surface everyone actually walks on (measured in Studio): the lawn's top voxel layer, -4..0 at
-- occupancy 0.75, reads as y = -2 + 4 * 0.75 = 1. That covers the Courtyard part (top y = 0), so
-- anything meant to be seen on the ground stands on FLOOR. Never change the lawn's height: player
-- height against enemy hover and the Y hit bands depends on it.
local FLOOR = 1
local PAGODA = Vector3.new(74, FLOOR, -175)
local WATERFALL = Vector3.new(-330, FLOOR, -40)
local POND = Vector3.new(-60, 0, -10)
local POND_RADIUS = 18
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(22, 18, 26)
local VERMILION = Color3.fromRGB(196, 40, 28)
local WOOD = Color3.fromRGB(110, 70, 45)
local SLATE = Color3.fromRGB(88, 86, 96)
local STONE = Color3.fromRGB(150, 148, 140)
local PURPLE = Color3.fromRGB(170, 60, 255)
local WARM = Color3.fromRGB(255, 170, 90)

local folder = Instance.new("Folder")
folder.Name = "NightArena"

local flickers: { PointLight } = {}
local idleYokai: { BasePart } = {}
local confetti: ParticleEmitter? = nil
local boardText: TextLabel? = nil

local function glow(p: BasePart, colour: Color3, range: number, brightness: number, flicker: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	if flicker then
		table.insert(flickers, l)
	end
	return l
end

local function wedge(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material
): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = colour
	w.Material = material
	w.Parent = parent
	return w
end

local function decor(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- A decorative Night model, ghosted and shadowless. New map props have no part version: nil until
-- their ids are uploaded, so they simply do not appear.
local function prop(name: string, parent: Instance, base: Vector3, yaw: number?, scale: number?): Model?
	local model = Models.night(name, parent, base, yaw, scale)
	if model then
		Models.ghost(model)
		for _, p in model:GetChildren() do
			(p :: BasePart).CastShadow = false
		end
	end
	return model
end

-- Sets a model's <name>_glow mesh to real Neon (baked textures do not emit in Roblox).
local function neon(model: Model?, colour: Color3, transparency: number?)
	local strip = model and model:FindFirstChild(model.Name .. "_glow") :: BasePart?
	if strip then
		strip.Material = Enum.Material.Neon
		strip.Color = colour
		strip.Transparency = transparency or 0
	end
end

-- Height of the terrain at (x, z), so trees stand on the sando hill.
local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else -1
end

-- Yaw in degrees that turns a model's front the way `frame` looks (Models.night yaw). Uploaded
-- models come in facing +Z at yaw 0 (checked in Studio), hence the half turn.
local function yawOf(frame: CFrame): number
	return math.deg(math.atan2(-frame.LookVector.X, -frame.LookVector.Z)) + 180
end

-- First part of a Night model, to carry lights and emitters.
local function body(model: Model): BasePart
	return model:FindFirstChildWhichIsA("BasePart") :: BasePart
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- An invisible box that emits from its whole volume (fireflies, fog).
local function cloud(parent: Instance, centre: Vector3, size: Vector3, props: { [string]: any })
	local box = decor(part(parent, size, centre, WHITE))
	box.Transparency = 1
	props.Shape = Enum.ParticleEmitterShape.Box
	props.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter(box, props)
end

local function fireflies(parent: Instance, centre: Vector3, size: Vector3)
	cloud(parent, centre, size, {
		Color = ColorSequence.new(Color3.fromRGB(220, 255, 140)),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 5,
	})
end

-- Low soft mist over a box.
local function fog(parent: Instance, centre: Vector3, size: Vector3, from: number, to: number, rate: number)
	cloud(parent, centre, size, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 130, 190)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(from, to),
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 0),
		Rate = rate,
	})
end

local function petals(parent: BasePart, rate: number)
	emitter(parent, {
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 215)),
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(1.5, -1.2, 0.5),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		SpreadAngle = Vector2.new(180, 180),
		Rate = rate,
	})
end

-- Hanging paper lantern: glowing body with black caps.
local function paperLantern(parent: Instance, at: Vector3, colour: Color3, light: boolean)
	local name = if colour.G > 0.6 then "paper_lantern_cream" else "paper_lantern_red"
	local model = Models.night(name, parent, at - Vector3.new(0, 1.4, 0))
	local lamp: BasePart
	if model then
		Models.ghost(model)
		lamp = body(model)
	else
		lamp = decor(pillar(parent, at - Vector3.new(0, 1.1, 0), 2.2, 0.85, colour, Enum.Material.Neon))
		decor(pillar(parent, at + Vector3.new(0, 1.1, 0), 0.3, 0.6, INK, Enum.Material.Wood))
		decor(pillar(parent, at - Vector3.new(0, 1.4, 0), 0.3, 0.6, INK, Enum.Material.Wood))
	end
	if light then
		glow(lamp, colour:Lerp(WARM, 0.5), 16, 1.6, true)
	end
end

-- Stone lantern (toro): the Night model with a warm light in its firebox, or Props.lantern.
local function stoneLantern(parent: Instance, base: Vector3)
	if Models.night("stone_lantern", parent, base) == nil then
		Props.lantern(parent, base)
		return
	end
	local fire = decor(part(parent, Vector3.one, base + Vector3.new(0, 4, 0), WARM))
	fire.Transparency = 1
	glow(fire, Color3.fromRGB(255, 170, 90), 14, 1.5)
end

-- White zigzag shide paper streamer hanging from `top`.
local function shide(parent: Instance, top: Vector3, yaw: number)
	for i = 0, 2 do
		local side = if i % 2 == 0 then 0.2 else -0.2
		decor(
			part(
				parent,
				Vector3.new(0.5, 0.75, 0.05),
				CFrame.new(top + Vector3.new(0, -0.4 - i * 0.7, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(side, 0, 0),
				WHITE,
				Enum.Material.Fabric
			)
		)
	end
end

-- Lighting (I2) ------------------------------------------------------------------------------

local function effect(className: string, props: { [string]: any })
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		existing:Destroy()
	end
	local e = Instance.new(className)
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = Lighting
end

local function lighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(38, 36, 64)
	Lighting.OutdoorAmbient = Color3.fromRGB(72, 72, 120)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.27,
		Offset = 0.1,
		Color = Color3.fromRGB(78, 80, 150),
		Decay = Color3.fromRGB(46, 42, 92),
		Glare = 0.2,
		Haze = 0.9,
	})
	effect("Sky", { MoonAngularSize = 20, StarCount = 3000 })
	effect("BloomEffect", { Intensity = 0.7, Size = 28, Threshold = 1.15 })
	effect("ColorCorrectionEffect", {
		TintColor = Color3.fromRGB(232, 226, 255),
		Contrast = 0.14,
		Saturation = 0.2,
		Brightness = 0,
	})
end

-- Ground, wall and paths --------------------------------------------------------------------

-- Cobbled paths as { minX, maxX, minZ, maxZ }.
local PATHS = {
	{ -6, 6, 30, 104 }, -- entrance to stage
	{ -6, 6, -48, -20 }, -- stage to the boss pit
	{ 22, 58, -6, 6 }, -- stage to the stalls
	{ -41, -21, -6, 6 }, -- stage to the pond
}

-- Material of the ground at (x, z), or nil to leave the lawn.
local function groundMaterial(x: number, z: number): Enum.Material?
	local M = Enum.Material
	local fromCentre = math.sqrt(x * x + z * z)
	local mossy = math.noise(x / 16, z / 16, 7) > 0.08
	if math.abs(x) <= 18 and z >= 102 and z <= 154 then
		return if math.abs(x) <= 7 then M.Cobblestone else M.Pavement -- yatai street
	elseif fromCentre > RADIUS + 5 then
		return if mossy then M.LeafyGrass else nil
	end
	for _, path in PATHS do
		if x >= path[1] and x <= path[2] and z >= path[3] and z <= path[4] then
			return M.Cobblestone
		end
	end
	local nearTree = (Vector3.new(x, 0, z) - Vector3.new(-55, 0, 45)).Magnitude < 15
	local nearPond = (Vector3.new(x, 0, z) - POND).Magnitude < POND_RADIUS + 5
	if fromCentre <= 32 then
		return M.Pavement
	elseif nearTree or nearPond or (fromCentre > 84 and mossy and math.abs(x) > 16) then
		return M.LeafyGrass
	end
	return M.Sand
end

local function ground()
	local terrain = Workspace.Terrain
	terrain:Clear()
	local M = Enum.Material
	for material, colour in
		{
			[M.Grass] = Color3.fromRGB(44, 66, 48),
			[M.LeafyGrass] = Color3.fromRGB(58, 88, 50),
			[M.Sand] = Color3.fromRGB(128, 122, 114),
			[M.Pavement] = Color3.fromRGB(112, 108, 112),
			[M.Cobblestone] = Color3.fromRGB(96, 92, 90),
			[M.Mud] = Color3.fromRGB(46, 40, 38),
		}
	do
		terrain:SetMaterialColor(material, colour)
	end
	terrain.WaterColor = Color3.fromRGB(14, 46, 56)
	terrain.WaterTransparency = 0.7
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.05
	terrain.WaterWaveSpeed = 4
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1400, 10, 1400), M.Grass)

	-- Paint in the voxels, materials only: fills would change the surface height. A pond column
	-- becomes a mud bed under water (water cells are always whole, so its surface is y = 0).
	local region = Region3.new(Vector3.new(-160, -8, -160), Vector3.new(160, 4, 164))
	local materials, occupancy = terrain:ReadVoxels(region, 4)
	local corner = region.CFrame.Position - region.Size / 2
	local BED, SURFACE, ABOVE = 1, 2, 3 -- layers -8..-4, -4..0, 0..4
	for ix = 1, materials.Size.X do
		for iz = 1, materials.Size.Z do
			local x, z = corner.X + (ix - 0.5) * 4, corner.Z + (iz - 0.5) * 4
			if (Vector3.new(x, 0, z) - POND).Magnitude < POND_RADIUS then
				materials[ix][BED][iz] = M.Mud
				materials[ix][SURFACE][iz] = M.Water
				occupancy[ix][SURFACE][iz] = 1
				materials[ix][ABOVE][iz] = M.Air
				occupancy[ix][ABOVE][iz] = 0
			else
				materials[ix][SURFACE][iz] = groundMaterial(x, z) or materials[ix][SURFACE][iz]
			end
		end
	end
	terrain:WriteVoxels(region, 4, materials, occupancy)

	local court = pillar(folder, Vector3.new(0, -1, 0), 1, RADIUS, SLATE, Enum.Material.Slate)
	court.Name = "Courtyard"

	-- Stone wall with a wooden fence on top; open at the entrance and behind the shrine hall.
	local segments = 48
	local width = 2 * math.pi * (RADIUS + 4) / segments + 0.4
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local at = Vector3.new(math.cos(angle) * (RADIUS + 4), 0, math.sin(angle) * (RADIUS + 4))
		local entrance = at.Z > 0 and math.abs(at.X) < 10
		local hall = at.Z < 0 and math.abs(at.X) < 26
		local face = CFrame.lookAt(at, Vector3.zero)
		if not entrance and not hall and Models.night("wall_segment", folder, at, yawOf(face)) == nil then
			part(folder, Vector3.new(width, 6, 2), face + Vector3.new(0, 2, 0), STONE, Enum.Material.Slate)
			part(
				folder,
				Vector3.new(width, 0.5, 2.4),
				face + Vector3.new(0, 5.25, 0),
				Color3.fromRGB(60, 56, 64),
				Enum.Material.Slate
			)
			part(folder, Vector3.new(0.5, 3, 0.5), face * CFrame.new(width / 2 - 0.3, 7, 0), WOOD, Enum.Material.Wood)
			part(folder, Vector3.new(width, 0.35, 0.35), face * CFrame.new(0, 8.2, 0), WOOD, Enum.Material.Wood)
			part(folder, Vector3.new(width, 0.35, 0.35), face * CFrame.new(0, 6.8, 0), WOOD, Enum.Material.Wood)
		end
	end
end

-- Kagura stage (centre) ----------------------------------------------------------------------

-- The taiko drum model on the deck, or nil (the caller builds its part drum).
local function taiko(base: Vector3): Model?
	return Models.night("taiko_drum", folder, base, 45)
end

local function stage()
	-- With the Night model the deck, skirt, ramps and pillars stay as invisible collision.
	local mesh = Models.night("kagura_stage", folder, Vector3.zero)
	if mesh then
		Models.ghost(mesh)
	end
	local solid: { BasePart } = {}
	local deck = part(
		folder,
		Vector3.new(32, 4, 32),
		Vector3.new(0, 2, 0),
		Color3.fromRGB(150, 105, 70),
		Enum.Material.WoodPlanks
	)
	deck.Name = "Stage"
	table.insert(solid, deck)
	table.insert(solid, part(folder, Vector3.new(33, 0.6, 33), Vector3.new(0, 0.3, 0), INK, Enum.Material.Wood))
	-- Ramps on all four sides; a wedge's tall face is its +Z side, so each faces back to the deck.
	for _, d in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local centre = d * 21 + Vector3.new(0, 2, 0)
		table.insert(
			solid,
			wedge(
				folder,
				Vector3.new(8, 4, 10),
				CFrame.lookAt(centre, centre + d),
				Color3.fromRGB(140, 98, 66),
				Enum.Material.WoodPlanks
			)
		)
	end
	for _, x in { -15, 15 } do
		for _, z in { -15, 15 } do
			table.insert(solid, pillar(folder, Vector3.new(x, 4, z), 12, 0.8, VERMILION, Enum.Material.Wood))
			paperLantern(folder, Vector3.new(x * 1.12, 13, z * 1.12), Color3.fromRGB(255, 90, 60), true)
		end
	end
	if mesh then
		for _, p in solid do
			p.Transparency = 1
		end
		taiko(Vector3.new(-8, 4, -8))
		return
	end
	-- Eaves and a gabled roof (two wedges meeting at a west-east ridge).
	part(folder, Vector3.new(36, 0.8, 36), Vector3.new(0, 16.4, 0), INK, Enum.Material.Wood)
	local roof = Color3.fromRGB(46, 50, 70)
	wedge(folder, Vector3.new(38, 5, 19), CFrame.new(0, 19.3, -9.5), roof, Enum.Material.Slate)
	wedge(
		folder,
		Vector3.new(38, 5, 19),
		CFrame.new(0, 19.3, 9.5) * CFrame.Angles(0, math.pi, 0),
		roof,
		Enum.Material.Slate
	)
	part(folder, Vector3.new(40, 0.8, 1.2), Vector3.new(0, 22, 0), INK, Enum.Material.Slate)
	-- Shimenawa rope with shide streamers across the front (south) and back.
	for _, z in { 15.8, -15.8 } do
		local rope = decor(
			part(
				folder,
				Vector3.new(30, 1.2, 1.2),
				Vector3.new(0, 14.5, z),
				Color3.fromRGB(214, 190, 120),
				Enum.Material.Fabric
			)
		)
		rope.Shape = Enum.PartType.Cylinder
		for i = -2, 2 do
			shide(folder, Vector3.new(i * 5.5, 13.9, z), 0)
		end
	end
	-- A taiko drum on the deck.
	if taiko(Vector3.new(-8, 4, -8)) then
		return
	end
	local drum = part(
		folder,
		Vector3.new(2.4, 3.4, 3.4),
		CFrame.new(-8, 6.2, -8) * CFrame.Angles(0, math.rad(45), 0),
		Color3.fromRGB(120, 30, 24),
		Enum.Material.Wood
	)
	drum.Shape = Enum.PartType.Cylinder
end

-- Boss pit, shrine hall, sacred tree ---------------------------------------------------------

local function pit()
	local floorPit = PIT + Vector3.new(0, FLOOR, 0)
	decor(pillar(folder, floorPit - Vector3.new(0, 0.05, 0), 0.2, 20, Color3.fromRGB(46, 42, 54), Enum.Material.Slate))
	decor(pillar(folder, floorPit - Vector3.new(0, 0.02, 0), 0.2, 13, Color3.fromRGB(28, 24, 34), Enum.Material.Basalt))
	local rng = Random.new(65)
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local length = rng:NextNumber(5, 12)
		local from = rng:NextNumber(3, 10)
		local mid = floorPit + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (from + length / 2)
		decor(
			part(
				folder,
				Vector3.new(0.35, 0.1, length),
				CFrame.new(mid + Vector3.new(0, 0.1, 0))
					* CFrame.Angles(0, -angle + math.pi / 2 + rng:NextNumber(-0.3, 0.3), 0),
				PURPLE,
				Enum.Material.Neon
			)
		)
	end
	local core =
		decor(part(folder, Vector3.new(1, 0.1, 1), floorPit + Vector3.new(0, 0.1, 0), PURPLE, Enum.Material.Neon))
	glow(core, PURPLE, 30, 2)
	for _, x in { -30, 30 } do
		part(folder, Vector3.new(8, 1.5, 8), Vector3.new(x, 0.75, -80), STONE, Enum.Material.Slate)
		if Models.night("oni_statue", folder, Vector3.new(x, 1.5, -80)) == nil then
			Models.spawn("oni", folder, Vector3.new(x, 1.5, -80), 0.8, 180)
		end
	end
end

local function shrineHall()
	local at = Vector3.new(0, 0, -115)
	part(folder, Vector3.new(50, 1.5, 44), at + Vector3.new(0, 0.75, 0), STONE, Enum.Material.Slate)
	if
		Models.night("shrine_hall", folder, at + Vector3.new(0, 1.5, 0)) == nil
		and Models.spawn("shrineHall", folder, at + Vector3.new(0, 1.5, 0), 1.3, 180) == nil
	then
		part(
			folder,
			Vector3.new(36, 12, 26),
			at + Vector3.new(0, 7.5, 0),
			Color3.fromRGB(120, 80, 50),
			Enum.Material.WoodPlanks
		)
		for _, x in { -17, -6, 6, 17 } do
			pillar(folder, at + Vector3.new(x, 1.5, 13.5), 12, 0.8, VERMILION, Enum.Material.Wood)
		end
		local roof = Color3.fromRGB(40, 44, 60)
		wedge(folder, Vector3.new(44, 8, 18), CFrame.new(at + Vector3.new(0, 17.5, -8)), roof, Enum.Material.Slate)
		wedge(
			folder,
			Vector3.new(44, 8, 18),
			CFrame.new(at + Vector3.new(0, 17.5, 8)) * CFrame.Angles(0, math.pi, 0),
			roof,
			Enum.Material.Slate
		)
	end
	for _, x in { -22, 22 } do
		paperLantern(folder, at + Vector3.new(x, 12, 21), Color3.fromRGB(255, 120, 60), true)
		prop("sake_barrels", folder, Vector3.new(x * 0.886, 1.5, -98))
	end
end

local function sacredTree()
	local at = Vector3.new(-55, 0, 45)
	-- The Night model carries its own shimenawa rope and shide.
	local blender = Models.night("sacred_tree", folder, at, 30)
	local tree = if blender then nil else Models.spawn("sacredTree", folder, at, 1, 30)
	if blender then
		Models.ghost(blender)
	elseif tree then
		tree.CanCollide = false
	else
		pillar(folder, at, 22, 3.5, Color3.fromRGB(70, 50, 38), Enum.Material.Wood)
		local rng = Random.new(45)
		for _ = 1, 6 do
			local leaves = decor(
				part(
					folder,
					Vector3.one * rng:NextNumber(14, 20),
					at + Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(22, 30), rng:NextNumber(-9, 9)),
					Color3.fromRGB(40, 90, 50),
					Enum.Material.LeafyGrass
				)
			)
			leaves.Shape = Enum.PartType.Ball
		end
	end
	-- Shimenawa ring with paper streamers, and a low stone fence (tamagaki).
	for i = 0, if blender then -1 else 9 do
		local angle = i / 10 * math.pi * 2
		local p = at + Vector3.new(math.cos(angle) * 5.5, 9, math.sin(angle) * 5.5)
		local rope = decor(
			part(
				folder,
				Vector3.new(3.6, 0.9, 0.9),
				CFrame.lookAt(p, at + Vector3.new(0, 9, 0)),
				Color3.fromRGB(214, 190, 120),
				Enum.Material.Fabric
			)
		)
		rope.Shape = Enum.PartType.Cylinder
		if i % 2 == 0 then
			shide(folder, p - Vector3.new(0, 0.4, 0), angle)
		end
	end
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		part(
			folder,
			Vector3.new(0.8, 2.4, 0.8),
			at + Vector3.new(math.cos(angle) * 11, 1.2, math.sin(angle) * 11),
			STONE,
			Enum.Material.Slate
		)
	end
	fireflies(folder, at + Vector3.new(0, 6, 0), Vector3.new(36, 10, 36))
end

-- Koi pond (west) ----------------------------------------------------------------------------

local function bridge(z: number, halfLength: number)
	local centre = Vector3.new(-60, 0, z)
	-- With the Night model the deck and rail parts stay as invisible collision.
	local mesh = Models.night("arched_bridge", folder, centre)
	if mesh then
		Models.ghost(mesh)
	end
	local solid: { BasePart } = {}
	local steps = 8
	local rise = 3
	local function height(s: number): number
		return 0.4 + rise * math.sin(math.pi * s)
	end
	for i = 0, steps - 1 do
		local s0, s1 = i / steps, (i + 1) / steps
		local a = centre + Vector3.new(-halfLength + s0 * 2 * halfLength, height(s0), 0)
		local b = centre + Vector3.new(-halfLength + s1 * 2 * halfLength, height(s1), 0)
		local length = (b - a).Magnitude + 0.3
		table.insert(
			solid,
			part(
				folder,
				Vector3.new(length, 0.6, 6),
				CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(150, 40, 30),
				Enum.Material.Wood
			)
		)
		for _, side in { -3, 3 } do
			local rail = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 1.6, side), b + Vector3.new(0, 1.6, side))
			table.insert(solid, part(folder, Vector3.new(0.3, 0.3, length), rail, VERMILION, Enum.Material.Wood))
			if i % 2 == 0 then
				table.insert(
					solid,
					part(
						folder,
						Vector3.new(0.4, 1.8, 0.4),
						a + Vector3.new(0, 0.9, side),
						VERMILION,
						Enum.Material.Wood
					)
				)
			end
		end
	end
	if mesh then
		for _, p in solid do
			p.Transparency = 1
		end
	end
end

local function pond()
	local centre = POND
	-- Water cannot sit at FLOOR, so this sheet over it is the walkable surface, exactly where the
	-- lawn was, and the koi show through it.
	local sheet = pillar(folder, POND, FLOOR, POND_RADIUS, Color3.fromRGB(26, 74, 86), Enum.Material.Glass)
	sheet.Name = "PondSurface"
	sheet.Transparency = 0.55
	sheet.Reflectance = 0.15
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local at = centre + Vector3.new(math.cos(angle) * 18.8, FLOOR + 0.35, math.sin(angle) * 18.8)
		decor(
			part(
				folder,
				Vector3.new(5.2, 0.9, 1.8),
				CFrame.lookAt(at, centre + Vector3.new(0, FLOOR + 0.35, 0)),
				Color3.fromRGB(120, 118, 112),
				Enum.Material.Slate
			)
		)
	end
	bridge(-21, 15)
	bridge(1, 15)
	for i, z in { -15, -10, -5 } do
		decor(pillar(folder, centre + Vector3.new(i * 1.5 - 3, FLOOR, z + 10), 0.2, 1.6, STONE, Enum.Material.Slate))
	end
	local rng = Random.new(7)
	local koi = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(250, 245, 240), Color3.fromRGB(230, 60, 40) }
	for i = 1, 8 do
		local at = centre + Vector3.new(rng:NextNumber(-12, 12), -0.35, rng:NextNumber(-12, 12))
		if i <= 5 then
			local yaw = rng:NextNumber(0, 6.28)
			local fish = Models.night("koi", folder, at - Vector3.new(0, 0.15, 0), math.deg(yaw))
			if fish then
				Models.ghost(fish)
			else
				decor(
					part(folder, Vector3.new(0.6, 0.3, 1.6), CFrame.new(at) * CFrame.Angles(0, yaw, 0), koi[i % 3 + 1])
				)
			end
		else
			decor(
				pillar(
					folder,
					at + Vector3.new(0, FLOOR + 0.37, 0),
					0.08,
					rng:NextNumber(0.8, 1.4),
					Color3.fromRGB(60, 120, 60),
					Enum.Material.LeafyGrass
				)
			)
		end
	end
	fireflies(folder, centre + Vector3.new(0, 4, 0), Vector3.new(40, 6, 40))
	for _, at in { Vector3.new(-68, FLOOR, -10), Vector3.new(-50, FLOOR, -12), Vector3.new(-56, FLOOR, 6) } do
		prop("lily_pads", folder, at, rng:NextNumber(0, 360))
	end
	for _, at in { Vector3.new(-82, FLOOR, -10), Vector3.new(-65.7, FLOOR, 11.3), Vector3.new(-65.7, FLOOR, -31.3) } do
		prop("garden_rocks", folder, at, rng:NextNumber(0, 360))
	end
end

-- Festival stalls (east) ---------------------------------------------------------------------

local STALLS = {
	{ "たこ焼き\nTAKOYAKI", Color3.fromRGB(200, 40, 40) },
	{ "金魚すくい\nGOLDFISH", Color3.fromRGB(240, 240, 235) },
	{ "お面\nMASKS", Color3.fromRGB(40, 50, 120) },
	{ "りんご飴\nCANDY APPLES", Color3.fromRGB(200, 40, 40) },
	{ "焼きそば\nYAKISOBA", Color3.fromRGB(40, 50, 120) },
}

-- Night stall model per awning colour (lower-case Color3:ToHex()).
local STALL_MODELS =
	{ c82828 = "festival_stall_red", f0f0eb = "festival_stall_white", ["283278"] = "festival_stall_indigo" }

-- One stall at `frame` (local -Z is its front): model or parts, sign and lanterns.
local function stall(i: number, info: { any }, frame: CFrame)
	-- The Night stall model replaces the counter, posts, awning, goods and crates; the sign
	-- (SurfaceGui text) and lanterns stay.
	local accent = { Color3.fromRGB(240, 240, 235), Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 240, 235) }
	local asset = STALL_MODELS[string.lower((info[2] :: Color3):ToHex())]
	local built = Models.night(asset, folder, frame.Position, yawOf(frame)) ~= nil
	if not built then
		part(folder, Vector3.new(9, 3, 2.5), frame * CFrame.new(0, 1.5, -2.5), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -4.3, 4.3 } do
			for _, depth in { -3.6, 3 } do
				part(
					folder,
					Vector3.new(0.5, 8, 0.5),
					frame * CFrame.new(x, 4, depth),
					Color3.fromRGB(70, 46, 32),
					Enum.Material.Wood
				)
			end
		end
		-- Striped fabric awning sloping down to the front.
		for s = 1, 3 do
			local colour = if s == 2 then info[2] else accent[(i % 2) + 1]
			part(
				folder,
				Vector3.new(3.4, 0.25, 9),
				frame * CFrame.new(-6.8 + s * 3.4, 8.4, -0.6) * CFrame.Angles(math.rad(-14), 0, 0),
				colour,
				Enum.Material.Fabric
			)
		end
	end
	local sign = part(folder, Vector3.new(8, 2.4, 0.3), frame * CFrame.new(0, 10.6, -4.4), INK, Enum.Material.Wood)
	label(sign, info[1], Color3.fromRGB(255, 220, 150))
	for _, x in { -4.3, 4.3 } do
		paperLantern(
			folder,
			(frame * CFrame.new(x, 6.4, -5)).Position,
			if x < 0 then Color3.fromRGB(255, 80, 60) else Color3.fromRGB(255, 200, 120),
			x < 0
		)
	end
	if not built then
		for g = -1, 1 do
			local good = decor(
				part(
					folder,
					Vector3.new(1, 0.8, 1),
					frame * CFrame.new(g * 2.6, 3.4, -2.5),
					Color3.fromHSV((i * 0.17 + g * 0.08) % 1, 0.7, 0.9)
				)
			)
			good.Shape = Enum.PartType.Ball
		end
		part(
			folder,
			Vector3.new(2, 2, 2),
			frame * CFrame.new(5.8, 1, -1),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.Wood
		)
		part(
			folder,
			Vector3.new(1.6, 1.6, 1.6),
			frame * CFrame.new(5.6, 2.8, -0.8) * CFrame.Angles(0, 0.4, 0),
			Color3.fromRGB(140, 100, 64),
			Enum.Material.Wood
		)
	end
end

local function stalls()
	for i, info in STALLS do
		local z = (i - 3) * 18
		-- Local frame: -Z faces the courtyard centre (west).
		stall(i, info, CFrame.lookAt(Vector3.new(62, 0, z), Vector3.new(0, 0, z)))
	end
end

-- Demon gates, entrance, lanterns ------------------------------------------------------------

local GATES = { Vector3.new(60, 0, 60), Vector3.new(-60, 0, -60), Vector3.new(60, 0, -60), Vector3.new(-60, 0, 60) }

local function demonGate(at: Vector3)
	local frame = CFrame.lookAt(at, Vector3.zero)
	local gate = Models.night("demon_gate", folder, at, yawOf(frame))
	neon(gate, PURPLE)
	if gate == nil then
		for _, x in { -6, 6 } do
			local foot = (frame * CFrame.new(x, 0, 0)).Position
			pillar(folder, foot, 14, 0.9, INK, Enum.Material.Wood)
			decor(part(folder, Vector3.new(0.3, 12, 0.3), frame * CFrame.new(x, 7, -0.95), PURPLE, Enum.Material.Neon))
		end
		part(folder, Vector3.new(18, 1.2, 1.8), frame * CFrame.new(0, 14.4, 0), INK, Enum.Material.Wood)
		part(folder, Vector3.new(15, 0.8, 0.8), frame * CFrame.new(0, 11.5, 0), INK, Enum.Material.Wood)
		decor(part(folder, Vector3.new(18, 0.2, 0.2), frame * CFrame.new(0, 13.7, -0.95), PURPLE, Enum.Material.Neon))
	end
	local portal =
		decor(part(folder, Vector3.new(11, 11, 0.2), frame * CFrame.new(0, 5.6, 0), PURPLE, Enum.Material.Neon))
	portal.Transparency = 0.75
	emitter(portal, {
		Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(60, 0, 120)),
		LightEmission = 0.8,
		Size = NumberSequence.new(1.2, 0),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.5, 1.5),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(120, 240),
		SpreadAngle = Vector2.new(30, 30),
		Rate = 25,
	})
	local floor = decor(pillar(folder, at + Vector3.new(0, FLOOR + 0.02, 0), 0.1, 7, PURPLE, Enum.Material.Neon))
	floor.Transparency = 0.55
	glow(floor, PURPLE, 24, 2.5)

	-- An idle yokai drifting at the gate, shown only while no night is running (GDD I2 menu orbit).
	local spot = frame * CFrame.new(0, 4, -4)
	local wisp: BasePart? = Models.nightPart("wisp", folder, spot.Position - Vector3.new(0, 1.8, 0), yawOf(frame))
	if wisp then
		decor(wisp)
	else
		local ball = decor(part(folder, Vector3.one * 2.2, spot, Color3.fromRGB(200, 235, 255), Enum.Material.Neon))
		ball.Shape = Enum.PartType.Ball
		wisp = ball
	end
	assert(wisp, "wisp")
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(110, 180, 255)
	fire.SecondaryColor = WHITE
	fire.Size = 3
	fire.Parent = wisp
	glow(wisp, Color3.fromRGB(130, 190, 255), 10, 1.5)
	TweenService:Create(
		wisp,
		TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = wisp.Position + Vector3.new(0, 1.5, 0) }
	):Play()
	table.insert(idleYokai, wisp)
end

local function entrance()
	if Models.night("entrance_torii", folder, Vector3.new(0, 0, 98), 180) then
		-- Same plaque Props.torii hangs under the kasagi.
		local text = "百鬼夜行"
		local plaque = part(folder, Vector3.new(math.max(4, #text * 0.9), 1.6, 0.4), Vector3.new(0, 14.8, 98), INK)
		plaque.Material = Enum.Material.Slate
		plaque.CanCollide = false
		label(plaque, text, Color3.fromRGB(255, 210, 120))
	else
		Props.torii(folder, Vector3.new(0, 0, 98), 18, 16, Color3.fromRGB(255, 210, 120), "百鬼夜行")
	end
	for _, x in { -9, 9 } do
		part(folder, Vector3.new(4, 2, 5), Vector3.new(x, 1, 88), STONE, Enum.Material.Slate)
		if Models.night("komainu", folder, Vector3.new(x, 2, 88)) == nil then
			Models.spawn("komainu", folder, Vector3.new(x, 2, 88), 0.9, 180)
		end
		stoneLantern(folder, Vector3.new(x * 1.6, 0, 93))
	end
	-- Nights-won leaderboard: a lantern board beside the entrance path, facing west.
	local board = part(folder, Vector3.new(1, 12, 16), Vector3.new(24, 7, 82), INK, Enum.Material.Wood)
	board.Name = "Leaderboard"
	-- Set back 1.2 studs, or the frame's backing covers the text face of the board.
	local frameModel = Models.night("leaderboard_frame", folder, Vector3.new(25.2, 0, 82), 270)
	for _, z in { -8.6, 8.6 } do
		if frameModel == nil then
			pillar(folder, Vector3.new(24, 0, 82 + z), 14, 0.5, VERMILION, Enum.Material.Wood)
		end
		paperLantern(folder, Vector3.new(23, 15, 82 + z), Color3.fromRGB(255, 120, 60), true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local list = Instance.new("TextLabel")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.TextColor3 = Color3.fromRGB(255, 225, 170)
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "NIGHTS WON\n\nloading…"
	list.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.Parent = list
	boardText = list
end

local function rimLanterns()
	for i = 0, 15 do
		local angle = (i + 0.5) / 16 * math.pi * 2
		local at = Vector3.new(math.cos(angle) * 92, 0, math.sin(angle) * 92)
		if (at - PIT).Magnitude >= 30 then
			local model = Instance.new("Model")
			model.Name = "StoneLantern"
			stoneLantern(model, at)
			for _, d in model:GetDescendants() do
				if d:IsA("PointLight") then
					d.Range = 18
					table.insert(flickers, d)
				end
			end
			model.Parent = folder
		end
	end
end

-- One sagging string of small lanterns from a to b.
local function garland(a: Vector3, b: Vector3, sag: number)
	local colours = { Color3.fromRGB(255, 80, 60), Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 240, 220) }
	local count = math.floor((b - a).Magnitude / 6)
	local previous: Attachment? = nil
	for k = 0, count do
		local s = k / count
		local at = a:Lerp(b, s) - Vector3.new(0, sag * 4 * s * (1 - s), 0)
		local bulb = decor(part(folder, Vector3.new(0.9, 1.1, 0.9), at, colours[k % 3 + 1], Enum.Material.Neon))
		bulb.Shape = Enum.PartType.Ball
		if k % 4 == 2 then
			glow(bulb, WARM, 10, 1)
		end
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, 0.5, 0)
		attachment.Parent = bulb
		if previous then
			local beam = Instance.new("Beam")
			beam.Attachment0 = previous
			beam.Attachment1 = attachment
			beam.Width0, beam.Width1 = 0.12, 0.12
			beam.Color = ColorSequence.new(INK)
			beam.LightInfluence = 1
			beam.Parent = bulb
		end
		previous = attachment
	end
end

-- Strings from the stage roof corners to poles on the rim, then pole to pole round the wall. The
-- rim string skips the north chord, which would cross the boss pit.
local function lanternStrings()
	local poles: { Vector3 } = {}
	for _, corner in
		{ Vector3.new(16, 0, -16), Vector3.new(-16, 0, -16), Vector3.new(16, 0, 16), Vector3.new(-16, 0, 16) }
	do
		local diagonal = math.atan2(corner.Z, corner.X)
		for _, spread in { -0.32, 0.32 } do
			local angle = diagonal + spread
			local pole = Vector3.new(math.cos(angle) * 88, 0, math.sin(angle) * 88)
			pillar(folder, pole, 12, 0.35, WOOD, Enum.Material.Wood)
			garland(corner + Vector3.new(0, 16, 0), pole + Vector3.new(0, 12, 0), 4)
			table.insert(poles, pole)
		end
	end
	table.sort(poles, function(a, b)
		return math.atan2(a.Z, a.X) < math.atan2(b.Z, b.X)
	end)
	for i, pole in poles do
		local other = poles[i % #poles + 1]
		if pole.Z > -50 or other.Z > -50 or math.sign(pole.X) == math.sign(other.X) then
			garland(pole + Vector3.new(0, 12, 0), other + Vector3.new(0, 12, 0), 2.5)
		end
	end
end

-- South sando: yatai street, stone stairs and senbon-torii tunnel up a hill to an inner shrine ----

local SANDO_FOOT = 152 -- z where the stairs start: four flights of 6 over 12, landings of 6
local SANDO_TOP = 24

-- Height of the stair line at z.
local function sandoY(z: number): number
	local along = math.clamp(z - SANDO_FOOT, 0, 66)
	local flights = math.floor(along / 18)
	return FLOOR + flights * 6 + math.min(along - flights * 18, 12) / 2
end

local function sando()
	local terrain = Workspace.Terrain
	local M = Enum.Material
	-- A smooth hill whose north face follows the stairs, a paved summit and a cutting for the flights.
	-- A block fill reads about 2 studs above its top, so landings fill to their height minus 2.
	terrain:FillBall(Vector3.new(0, -150.5, 242), 174.5, M.Grass)
	terrain:FillBlock(CFrame.new(0, FLOOR + SANDO_TOP - 22, 242), Vector3.new(52, 40, 52), M.Pavement)
	for i = 0, 3 do
		local y = FLOOR + i * 6
		local z = SANDO_FOOT + i * 18
		terrain:FillBlock(CFrame.new(0, y + 20, z + 9), Vector3.new(13, 40, 18), M.Air)
		terrain:FillBlock(CFrame.new(0, y - 8, z + 9), Vector3.new(13, 12, 18), M.Slate)
		terrain:FillWedge(CFrame.new(0, y + 3, z + 6), Vector3.new(13, 6, 12), M.Slate)
		terrain:FillBlock(CFrame.new(0, y + 1, z + 15), Vector3.new(13, 6, 6), M.Slate)
	end

	for i = 0, 5 do
		local z = 112 + (i // 2) * 14
		local x = if i % 2 == 0 then -15 else 15
		stall(i + 1, STALLS[i % #STALLS + 1], CFrame.lookAt(Vector3.new(x, FLOOR, z), Vector3.new(0, FLOOR, z)))
	end
	for z = 106, 142, 18 do
		for _, x in { -9, 9 } do
			pillar(folder, Vector3.new(x, FLOOR, z), 12, 0.3, WOOD, Enum.Material.Wood)
		end
		if z < 142 then
			garland(Vector3.new(-9, FLOOR + 12, z), Vector3.new(9, FLOOR + 12, z + 18), 2)
			garland(Vector3.new(9, FLOOR + 12, z), Vector3.new(-9, FLOOR + 12, z + 18), 2)
		end
	end
	for _, x in { -6.5, 6.5 } do
		stoneLantern(folder, Vector3.new(x, FLOOR, SANDO_FOOT - 2))
		for landing = 1, 3 do
			local z = SANDO_FOOT + landing * 18 - 3
			stoneLantern(folder, Vector3.new(x * 0.86, groundY(x * 0.86, z), z))
		end
		for _, z in { 228, 240 } do
			stoneLantern(folder, Vector3.new(x * 1.3, groundY(x * 1.3, z), z))
		end
	end

	for i = 0, 3 do
		local y = FLOOR + i * 6
		local z = SANDO_FOOT + i * 18 + 6
		if prop("sando_stairs", folder, Vector3.new(0, y, z), 180) then
			-- Exact walkable slope over the coarser terrain wedge.
			local ramp = wedge(folder, Vector3.new(9, 6, 12), CFrame.new(0, y + 3.4, z), STONE, Enum.Material.Slate)
			ramp.Transparency = 1
		end
	end
	for z = SANDO_FOOT + 1, SANDO_FOOT + 64, 3 do
		-- On a flight the feet sit on the sloped side blocks; on a landing, on the ground.
		local onFlight = (z - SANDO_FOOT) % 18 < 12
		prop("senbon_torii", folder, Vector3.new(0, sandoY(z) + (if onFlight then 0.6 else 0), z))
	end

	-- Inner shrine on the summit, behind a smaller vermilion torii.
	Models.night("entrance_torii", folder, Vector3.new(0, groundY(0, 224), 224), 0, 0.6)
	Models.night("shrine_hall", folder, Vector3.new(0, groundY(0, 250), 250), 180, 0.5)
	fireflies(folder, Vector3.new(0, SANDO_TOP, 190), Vector3.new(70, 16, 70))
end

-- Garden and banners ------------------------------------------------------------------------------

-- A point `radius` from the centre at `degrees` (0 = east, 90 = south). Decoration inside the wall
-- only lives in the band along it, clear of the boss pit (GDD I1) and the demon gates.
local function spot(degrees: number, radius: number): Vector3
	local angle = math.rad(degrees)
	local at = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	assert(radius >= 88, "decoration on the fighting floor")
	assert((at - PIT).Magnitude >= 30, "decoration in the boss pit")
	for _, gate in GATES do
		assert((at - gate).Magnitude >= 14, "decoration at a demon gate")
	end
	return at + Vector3.new(0, FLOOR, 0)
end

local function garden()
	local rng = Random.new(77)
	for _, degrees in { -18, 0, 18, 180, 200, 212 } do
		prop("bamboo_cluster", folder, spot(degrees, 97), rng:NextNumber(0, 360))
	end
	for _, degrees in { 108, 160 } do
		prop("pine_tree", folder, spot(degrees, 97), rng:NextNumber(0, 360))
	end
	for _, degrees in { 38, 52, 68, 128, 172, 232, 300, 330 } do
		prop("hydrangea_bush", folder, spot(degrees, 98), rng:NextNumber(0, 360))
	end
	for _, degrees in { 245, 295 } do
		prop("garden_rocks", folder, spot(degrees, 97), rng:NextNumber(0, 360))
	end
	prop("zen_garden", folder, Vector3.new(-30, FLOOR, 80))

	-- A close band of bamboo, pine and cedar outside the wall frames the courtyard, under the menu
	-- orbit's sightline (camera radius 130, height 54).
	for step = 0, 23 do
		local degrees = step * 15 + 7
		if math.abs(degrees - 90) > 14 and math.abs(degrees - 270) > 22 then
			local angle = math.rad(degrees)
			local distance = rng:NextNumber(110, 122)
			local at = Vector3.new(math.cos(angle) * distance, FLOOR - 0.3, math.sin(angle) * distance)
			local yaw = rng:NextNumber(0, 360)
			if step % 4 == 0 then
				prop("bamboo_cluster", folder, at, yaw, rng:NextNumber(0.9, 1.15))
			elseif step % 4 == 2 then
				prop("pine_tree", folder, at, yaw, rng:NextNumber(1, 1.3))
			else
				prop("cedar_tree", folder, at, yaw, rng:NextNumber(0.65, 0.95))
			end
		end
	end
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(128, 150)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		if math.abs(x) > 30 then
			prop("cedar_tree", folder, Vector3.new(x, groundY(x, z) - 0.5, z), math.deg(angle), rng:NextNumber(0.7, 1))
		end
	end
	-- Cedars crowd the sando hill, standing on its slope.
	for i = 1, 22 do
		local angle = i * 2.4
		local distance = 34 + i * 2.2
		local x, z = math.cos(angle) * distance, 242 + math.sin(angle) * distance
		if math.abs(x) > 11 then
			prop("cedar_tree", folder, Vector3.new(x, groundY(x, z) - 0.5, z), math.deg(angle), 0.7 + (i % 4) * 0.1)
		end
	end
	fireflies(folder, Vector3.new(90, 6, 0), Vector3.new(24, 10, 70))
	fireflies(folder, Vector3.new(-96, 6, -30), Vector3.new(16, 10, 60))
end

local function banners()
	local names = { "nobori_red", "nobori_indigo" }
	-- Between the stalls, cloth toward the courtyard.
	for i, z in { -27, -9, 9, 27 } do
		local frame = CFrame.lookAt(Vector3.new(60, 0, z), Vector3.new(0, 0, z))
		prop(names[i % 2 + 1], folder, frame.Position + Vector3.new(0, FLOOR, 0), yawOf(frame))
	end
	-- Along the wall, cloth toward the centre.
	for i, degrees in { 30, 80, 100, 118, 150, 190, 240, 308, 335 } do
		local at = spot(degrees, 99)
		prop(names[i % 2 + 1], folder, at, yawOf(CFrame.lookAt(at, Vector3.new(0, FLOOR, 0))))
	end
	-- Down both sides of the yatai street, cloth across it.
	for i, z in { 119, 133, 147 } do
		for side, x in { -10, 10 } do
			prop(names[(i + side) % 2 + 1], folder, Vector3.new(x, FLOOR, z))
		end
	end
end

-- Outside the wall -------------------------------------------------------------------------

local function sakuraRing()
	local rng = Random.new(110)
	for i = 0, 11 do
		local angle = (i + 0.5) / 12 * math.pi * 2
		local distance = rng:NextNumber(110, 130)
		local at = Vector3.new(math.cos(angle) * distance, -1, math.sin(angle) * distance)
		local scale, yaw = rng:NextNumber(1, 1.3), rng:NextNumber(0, 360)
		local blender = Models.night("sakura_tree", folder, at, yaw, scale)
		local tree = if blender then body(blender) else Models.spawn("sakura", folder, at, scale, yaw)
		if tree then
			petals(tree, 2)
		else
			Props.sakura(folder, at, rng)
		end
	end
end

local function forest()
	local trees = Instance.new("Folder")
	trees.Name = "Forest"
	local rng = Random.new(2026)
	local greens = { Color3.fromRGB(30, 70, 45), Color3.fromRGB(24, 58, 40), Color3.fromRGB(40, 80, 55) }
	for i = 1, 140 do
		if i % 35 == 0 then
			task.wait()
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(150, 320)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		local base = Vector3.new(x, groundY(x, z), z)
		local height = rng:NextNumber(14, 26)
		local cleared = (math.abs(x) < 14 and z > 100)
			or (base - PAGODA).Magnitude < 26
			or (base - WATERFALL).Magnitude < 62
		local cedar = if cleared then nil else Models.night("cedar_tree", trees, base, math.deg(angle), height / 26)
		if cleared or cedar then
			for _, p in if cedar then cedar:GetChildren() else {} do
				(p :: BasePart).CastShadow = false
			end
			-- Keep the random sequence of the part forest so the layout does not change.
			for _ = 0, 2 do
				rng:NextInteger(1, #greens)
			end
			continue
		end
		pillar(trees, base, height, 1.2, Color3.fromRGB(60, 42, 32), Enum.Material.Wood)
		-- Cedar-like stacked cones of leaves.
		for layer = 0, 2 do
			local size = (3 - layer) * 3.6
			local leaves = part(
				trees,
				Vector3.new(size, size * 0.8, size),
				base + Vector3.new(0, height - 4 + layer * 4, 0),
				greens[rng:NextInteger(1, #greens)],
				Enum.Material.LeafyGrass
			)
			leaves.Shape = Enum.PartType.Ball
			leaves.CastShadow = false
		end
	end
	trees.Parent = folder
	-- A big low moon behind the shrine hall for the first screenshot (I2).
	local moon = decor(
		part(folder, Vector3.one * 70, Vector3.new(90, 120, -420), Color3.fromRGB(235, 235, 255), Enum.Material.Neon)
	)
	moon.Name = "Moon"
	moon.Shape = Enum.PartType.Ball
	-- Drifting low fog over the courtyard.
	for _, at in { Vector3.new(50, 2, 50), Vector3.new(-50, 2, -50), Vector3.new(50, 2, -50), Vector3.new(-50, 2, 50) } do
		fog(folder, at, Vector3.new(60, 2, 60), 14, 20, 1.5)
	end
end

-- Far mountains, or the older terrain ones while the model has no id. The arcs leave a gap at the
-- moon's bearing (-78 degrees), so no ridge crosses its disc.
local function mountains()
	local placed = false
	for _, degrees in { -156, -120, -36, 24, 84, 144 } do
		local angle = math.rad(degrees)
		local at = Vector3.new(math.cos(angle) * 510, -10, math.sin(angle) * 510)
		placed = prop("mountain_range", folder, at, yawOf(CFrame.lookAt(at, Vector3.new(0, -10, 0)))) ~= nil
		if not placed then
			break
		end
	end
	if placed then
		return
	end
	local terrain = Workspace.Terrain
	local rng = Random.new(1001)
	-- Far mountains ring the shrine beyond 300 studs.
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distance = rng:NextNumber(340, 520)
		local at = Vector3.new(math.cos(angle) * distance, -rng:NextNumber(20, 50), math.sin(angle) * distance)
		terrain:FillBall(at, rng:NextNumber(90, 150), if i % 3 == 0 then Enum.Material.Rock else Enum.Material.Grass)
	end
end

-- Landmarks beyond the wall: the pagoda by the shrine hall, the castle on its north-west hill and
-- the waterfall in the west.
local function backdrop()
	local warm = Color3.fromRGB(255, 190, 110)
	local pagoda = prop("pagoda", folder, PAGODA)
	neon(pagoda, warm)
	if pagoda then
		for _, x in { -17, 17 } do
			for _, z in { -17, 17 } do
				stoneLantern(folder, PAGODA + Vector3.new(x, 0, z))
			end
		end
	end
	local keep = Vector3.new(-250, 38, -340)
	local castle = prop("castle", folder, keep, yawOf(CFrame.lookAt(keep, Vector3.new(0, keep.Y, 0))))
	neon(castle, warm)
	if castle then
		Workspace.Terrain:FillBall(keep - Vector3.new(0, 84, 0), 90, Enum.Material.Rock)
	end
	local fall = prop("waterfall", folder, WATERFALL, yawOf(CFrame.lookAt(WATERFALL, Vector3.new(0, FLOOR, 0))))
	neon(fall, Color3.fromRGB(176, 214, 255), 0.2)
	if fall then
		local toward = -WATERFALL.Unit
		fog(folder, WATERFALL + toward * 8 + Vector3.new(0, 6, 0), Vector3.new(34, 8, 34), 22, 34, 3)
		cloud(folder, WATERFALL - toward * 8 + Vector3.new(0, 44, 0), Vector3.new(14, 76, 6), {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(226, 240, 255)),
			LightEmission = 0.6,
			Transparency = NumberSequence.new(0.7, 1),
			Size = NumberSequence.new(3, 7),
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(14, 20),
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 18,
		})
	end
end

-- Sky-wide life: petals over the courtyard and mist banks round the forest and the pond.
local function ambient()
	local sky = decor(part(folder, Vector3.new(190, 1, 190), Vector3.new(0, 22, 0), WHITE))
	sky.Transparency = 1
	petals(sky, 14)
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2 + 0.4
		fog(folder, Vector3.new(math.cos(angle) * 230, 8, math.sin(angle) * 230), Vector3.new(180, 8, 180), 50, 70, 0.6)
	end
	fog(folder, POND + Vector3.new(0, FLOOR + 1, 0), Vector3.new(30, 1, 30), 10, 16, 1)
end

-- An occasional firework over the backdrop. A short Enabled pulse, because property changes
-- replicate to clients. Emitters sit far outside the wall, so they never hide a fight.
local function fireworks()
	local shells: { ParticleEmitter } = {}
	for _, at in
		{
			Vector3.new(-170, 150, -330),
			Vector3.new(190, 170, -300),
			Vector3.new(260, 140, 120),
			Vector3.new(-260, 160, 180),
		}
	do
		local holder = decor(part(folder, Vector3.one, at, WHITE))
		holder.Transparency = 1
		table.insert(
			shells,
			emitter(holder, {
				LightEmission = 1,
				LightInfluence = 0,
				Brightness = 4,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 13),
					NumberSequenceKeypoint.new(0.7, 9),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Lifetime = NumberRange.new(1.8, 2.8),
				Speed = NumberRange.new(120, 170),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 2.2,
				Acceleration = Vector3.new(0, -16, 0),
				Rate = 900,
				Enabled = false,
			})
		)
	end
	local colours = {
		Color3.fromRGB(255, 90, 80),
		Color3.fromRGB(255, 210, 110),
		Color3.fromRGB(150, 200, 255),
		Color3.fromRGB(255, 150, 210),
	}
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(7, 14))
			local shell = shells[rng:NextInteger(1, #shells)]
			shell.Color = ColorSequence.new(colours[rng:NextInteger(1, #colours)])
			shell.Enabled = true
			task.wait(0.3)
			shell.Enabled = false
		end
	end)
end

local function celebration()
	local holder = decor(part(folder, Vector3.new(30, 1, 30), Vector3.new(0, 26, 0), WHITE))
	holder.Transparency = 1
	confetti = emitter(holder, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 180, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 160, 255)),
		}),
		Size = NumberSequence.new(0.4),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -6, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		Rate = 0,
	})
end

-- Public API ---------------------------------------------------------------------------------

function Arena.update(rows: { { name: string, wins: number } })
	if boardText == nil then
		return
	end
	local lines = { "NIGHTS WON", "" }
	for i, row in rows do
		table.insert(lines, `{i}. {row.name}  {row.wins}`)
	end
	if #rows == 0 then
		table.insert(lines, "Survive a night to join the board!")
	end
	boardText.Text = table.concat(lines, "\n")
end

-- Five seconds of confetti over the stage on Victory.
function Arena.celebrate()
	local e = confetti
	if e then
		e.Rate = 150
		task.delay(5, function()
			e.Rate = 0
		end)
	end
end

-- Idle yokai drift at the gates only while no night is running.
function Arena.idle(on: boolean)
	for _, wisp in idleYokai do
		wisp.Transparency = if on then 0 else 1
		for _, child in wisp:GetChildren() do
			if child:IsA("Fire") or child:IsA("PointLight") then
				child.Enabled = on
			end
		end
	end
end

-- Builds everything once. Returns the run spawn and the leaderboard updater (night.md 4.1).
function Arena.build(): (CFrame, (rows: { { name: string, wins: number } }) -> ())
	lighting()
	ground()
	folder.Parent = Workspace
	mountains()
	stage()
	pit()
	for _, at in GATES do
		demonGate(at)
	end
	entrance()
	rimLanterns()
	lanternStrings()
	stalls()
	task.wait()
	pond()
	sacredTree()
	shrineHall()
	sando()
	task.wait()
	garden()
	banners()
	sakuraRing()
	forest()
	backdrop()
	ambient()
	celebration()
	fireworks()
	local parts = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	if parts >= 5000 then
		warn(`[Arena] {parts} parts, over the 5,000 budget (GDD I2)`)
	end
	folder:SetAttribute("Parts", parts)
	-- Lantern flicker: a few lights at a time, so replication stays light.
	task.spawn(function()
		local rng = Random.new()
		while #flickers > 0 do
			for _ = 1, 4 do
				local l = flickers[rng:NextInteger(1, #flickers)]
				l.Brightness = rng:NextNumber(1.2, 1.9)
			end
			task.wait(0.15)
		end
	end)
	return Arena.SPAWN, Arena.update
end

return Arena
