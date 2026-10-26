--!strict
-- "Shrine of a Hundred Lanterns" (GDD I1, I2): the ground-level courtyard, night lighting, the
-- leaderboard board and the ambient life (fireflies, petals, fog, lantern flicker, idle yokai).
-- Built once at server start from parts, Roblox materials, terrain and the generated meshes in
-- Models (docs/assets/register.md). No game rules live here.

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
	local body = decor(pillar(parent, at - Vector3.new(0, 1.1, 0), 2.2, 0.85, colour, Enum.Material.Neon))
	decor(pillar(parent, at + Vector3.new(0, 1.1, 0), 0.3, 0.6, INK, Enum.Material.Wood))
	decor(pillar(parent, at - Vector3.new(0, 1.4, 0), 0.3, 0.6, INK, Enum.Material.Wood))
	if light then
		glow(body, colour:Lerp(WARM, 0.5), 16, 1.6, true)
	end
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
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(40, 35, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 60, 100)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.35,
		Offset = 0.1,
		Color = Color3.fromRGB(90, 60, 140),
		Decay = Color3.fromRGB(40, 20, 60),
		Glare = 0.2,
		Haze = 1.2,
	})
	effect("Sky", { MoonAngularSize = 20, StarCount = 3000 })
	effect("BloomEffect", { Intensity = 0.6, Size = 30, Threshold = 1.2 })
	effect("ColorCorrectionEffect", {
		TintColor = Color3.fromRGB(225, 215, 255),
		Contrast = 0.1,
		Saturation = 0.15,
		Brightness = 0,
	})
end

-- Ground, wall and paths --------------------------------------------------------------------

local function ground()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1400, 10, 1400), Enum.Material.Grass)
	local rng = Random.new(1001)
	-- Far mountains ring the shrine beyond 300 studs.
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distance = rng:NextNumber(340, 520)
		local at = Vector3.new(math.cos(angle) * distance, -rng:NextNumber(20, 50), math.sin(angle) * distance)
		terrain:FillBall(at, rng:NextNumber(90, 150), if i % 3 == 0 then Enum.Material.Rock else Enum.Material.Grass)
	end
	-- Koi pond: shallow water over the courtyard, west (I1).
	terrain:FillCylinder(CFrame.new(-60, 0, -10), 1.2, 18, Enum.Material.Water)

	local court = pillar(folder, Vector3.new(0, -1, 0), 1, RADIUS, SLATE, Enum.Material.Slate)
	court.Name = "Courtyard"
	local cobble = Color3.fromRGB(120, 116, 110)
	for _, path in
		{
			{ Vector3.new(10, 0.1, 84), Vector3.new(0, 0.05, 58) }, -- entrance to stage
			{ Vector3.new(10, 0.1, 20), Vector3.new(0, 0.05, -26) }, -- stage to the boss pit
			{ Vector3.new(36, 0.1, 8), Vector3.new(34, 0.05, 0) }, -- stage to the stalls
			{ Vector3.new(22, 0.1, 8), Vector3.new(-27, 0.05, 0) }, -- stage to the pond
		}
	do
		part(folder, path[1], path[2], cobble, Enum.Material.Cobblestone)
	end
	-- Approach path outside the entrance.
	part(folder, Vector3.new(12, 1, 40), Vector3.new(0, -0.5, 120), cobble, Enum.Material.Cobblestone)

	-- Stone wall with a wooden fence on top; open at the entrance and behind the shrine hall.
	local segments = 48
	local width = 2 * math.pi * (RADIUS + 4) / segments + 0.4
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local at = Vector3.new(math.cos(angle) * (RADIUS + 4), 0, math.sin(angle) * (RADIUS + 4))
		local entrance = at.Z > 0 and math.abs(at.X) < 10
		local hall = at.Z < 0 and math.abs(at.X) < 26
		if not entrance and not hall then
			local face = CFrame.lookAt(at, Vector3.zero)
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

local function stage()
	local deck = part(
		folder,
		Vector3.new(32, 4, 32),
		Vector3.new(0, 2, 0),
		Color3.fromRGB(150, 105, 70),
		Enum.Material.WoodPlanks
	)
	deck.Name = "Stage"
	part(folder, Vector3.new(33, 0.6, 33), Vector3.new(0, 0.3, 0), INK, Enum.Material.Wood)
	-- Ramps on all four sides; a wedge's tall face is its +Z side, so each faces back to the deck.
	for _, d in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local centre = d * 21 + Vector3.new(0, 2, 0)
		wedge(
			folder,
			Vector3.new(8, 4, 10),
			CFrame.lookAt(centre, centre + d),
			Color3.fromRGB(140, 98, 66),
			Enum.Material.WoodPlanks
		)
	end
	for _, x in { -15, 15 } do
		for _, z in { -15, 15 } do
			pillar(folder, Vector3.new(x, 4, z), 12, 0.8, VERMILION, Enum.Material.Wood)
			paperLantern(folder, Vector3.new(x * 1.12, 13, z * 1.12), Color3.fromRGB(255, 90, 60), true)
		end
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
	decor(pillar(folder, PIT + Vector3.new(0, -0.05, 0), 0.2, 20, Color3.fromRGB(46, 42, 54), Enum.Material.Slate))
	decor(pillar(folder, PIT + Vector3.new(0, -0.02, 0), 0.2, 13, Color3.fromRGB(28, 24, 34), Enum.Material.Basalt))
	local rng = Random.new(65)
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local length = rng:NextNumber(5, 12)
		local from = rng:NextNumber(3, 10)
		local mid = PIT + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (from + length / 2)
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
	local core = decor(part(folder, Vector3.new(1, 0.1, 1), PIT + Vector3.new(0, 0.1, 0), PURPLE, Enum.Material.Neon))
	glow(core, PURPLE, 30, 2)
	for _, x in { -30, 30 } do
		part(folder, Vector3.new(8, 1.5, 8), Vector3.new(x, 0.75, -80), STONE, Enum.Material.Slate)
		Models.spawn("oni", folder, Vector3.new(x, 1.5, -80), 0.8, 180)
	end
end

local function shrineHall()
	local at = Vector3.new(0, 0, -115)
	part(folder, Vector3.new(50, 1.5, 44), at + Vector3.new(0, 0.75, 0), STONE, Enum.Material.Slate)
	if Models.spawn("shrineHall", folder, at + Vector3.new(0, 1.5, 0), 1.3, 180) == nil then
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
	end
end

local function sacredTree()
	local at = Vector3.new(-55, 0, 45)
	local tree = Models.spawn("sacredTree", folder, at, 1, 30)
	if tree then
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
	for i = 0, 9 do
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
		part(
			folder,
			Vector3.new(length, 0.6, 6),
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(150, 40, 30),
			Enum.Material.Wood
		)
		for _, side in { -3, 3 } do
			local rail = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 1.6, side), b + Vector3.new(0, 1.6, side))
			part(folder, Vector3.new(0.3, 0.3, length), rail, VERMILION, Enum.Material.Wood)
			if i % 2 == 0 then
				part(folder, Vector3.new(0.4, 1.8, 0.4), a + Vector3.new(0, 0.9, side), VERMILION, Enum.Material.Wood)
			end
		end
	end
end

local function pond()
	local centre = Vector3.new(-60, 0, -10)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local at = centre + Vector3.new(math.cos(angle) * 18.8, 0.35, math.sin(angle) * 18.8)
		part(
			folder,
			Vector3.new(5.2, 0.9, 1.8),
			CFrame.lookAt(at, centre + Vector3.new(0, 0.35, 0)),
			Color3.fromRGB(120, 118, 112),
			Enum.Material.Slate
		)
	end
	bridge(-21, 15)
	bridge(1, 15)
	for i, z in { -15, -10, -5 } do
		pillar(folder, centre + Vector3.new(i * 1.5 - 3, 0.2, z + 10), 0.5, 1.6, STONE, Enum.Material.Slate)
	end
	local rng = Random.new(7)
	local koi = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(250, 245, 240), Color3.fromRGB(230, 60, 40) }
	for i = 1, 8 do
		local at = centre + Vector3.new(rng:NextNumber(-12, 12), 0.15, rng:NextNumber(-12, 12))
		if i <= 5 then
			decor(
				part(
					folder,
					Vector3.new(0.6, 0.3, 1.6),
					CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					koi[i % 3 + 1]
				)
			)
		else
			decor(
				pillar(
					folder,
					at + Vector3.new(0, 0.3, 0),
					0.08,
					rng:NextNumber(0.8, 1.4),
					Color3.fromRGB(60, 120, 60),
					Enum.Material.LeafyGrass
				)
			)
		end
	end
	fireflies(folder, centre + Vector3.new(0, 4, 0), Vector3.new(40, 6, 40))
end

-- Festival stalls (east) ---------------------------------------------------------------------

local STALLS = {
	{ "たこ焼き\nTAKOYAKI", Color3.fromRGB(200, 40, 40) },
	{ "金魚すくい\nGOLDFISH", Color3.fromRGB(240, 240, 235) },
	{ "お面\nMASKS", Color3.fromRGB(40, 50, 120) },
	{ "りんご飴\nCANDY APPLES", Color3.fromRGB(200, 40, 40) },
	{ "焼きそば\nYAKISOBA", Color3.fromRGB(40, 50, 120) },
}

local function stalls()
	local accent = { Color3.fromRGB(240, 240, 235), Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 240, 235) }
	for i, info in STALLS do
		local z = (i - 3) * 18
		-- Local frame: -Z faces the courtyard centre (west).
		local frame = CFrame.lookAt(Vector3.new(62, 0, z), Vector3.new(0, 0, z))
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

-- Demon gates, entrance, lanterns ------------------------------------------------------------

local GATES = { Vector3.new(60, 0, 60), Vector3.new(-60, 0, -60), Vector3.new(60, 0, -60), Vector3.new(-60, 0, 60) }

local function demonGate(at: Vector3)
	local frame = CFrame.lookAt(at, Vector3.zero)
	for _, x in { -6, 6 } do
		local foot = (frame * CFrame.new(x, 0, 0)).Position
		pillar(folder, foot, 14, 0.9, INK, Enum.Material.Wood)
		decor(part(folder, Vector3.new(0.3, 12, 0.3), frame * CFrame.new(x, 7, -0.95), PURPLE, Enum.Material.Neon))
	end
	part(folder, Vector3.new(18, 1.2, 1.8), frame * CFrame.new(0, 14.4, 0), INK, Enum.Material.Wood)
	part(folder, Vector3.new(15, 0.8, 0.8), frame * CFrame.new(0, 11.5, 0), INK, Enum.Material.Wood)
	decor(part(folder, Vector3.new(18, 0.2, 0.2), frame * CFrame.new(0, 13.7, -0.95), PURPLE, Enum.Material.Neon))
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
	local floor = decor(pillar(folder, at + Vector3.new(0, 0.02, 0), 0.1, 7, PURPLE, Enum.Material.Neon))
	floor.Transparency = 0.55
	glow(floor, PURPLE, 24, 2.5)

	-- An idle yokai drifting at the gate, shown only while no night is running (GDD I2 menu orbit).
	local wisp = decor(
		part(folder, Vector3.one * 2.2, frame * CFrame.new(0, 4, -4), Color3.fromRGB(200, 235, 255), Enum.Material.Neon)
	)
	wisp.Shape = Enum.PartType.Ball
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
	Props.torii(folder, Vector3.new(0, 0, 98), 18, 16, Color3.fromRGB(255, 210, 120), "百鬼夜行")
	for _, x in { -9, 9 } do
		part(folder, Vector3.new(4, 2, 5), Vector3.new(x, 1, 88), STONE, Enum.Material.Slate)
		Models.spawn("komainu", folder, Vector3.new(x, 2, 88), 0.9, 180)
		Props.lantern(folder, Vector3.new(x * 1.6, 0, 93))
	end
	-- Nights-won leaderboard: a lantern board beside the entrance path, facing west.
	local board = part(folder, Vector3.new(1, 12, 16), Vector3.new(24, 7, 82), INK, Enum.Material.Wood)
	board.Name = "Leaderboard"
	for _, z in { -8.6, 8.6 } do
		pillar(folder, Vector3.new(24, 0, 82 + z), 14, 0.5, VERMILION, Enum.Material.Wood)
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
			Props.lantern(model, at)
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

-- Strings of small lanterns from the stage roof corners to poles on the rim.
local function lanternStrings()
	local colours = { Color3.fromRGB(255, 80, 60), Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 240, 220) }
	for _, corner in
		{ Vector3.new(16, 0, -16), Vector3.new(-16, 0, -16), Vector3.new(16, 0, 16), Vector3.new(-16, 0, 16) }
	do
		local diagonal = math.atan2(corner.Z, corner.X)
		for _, spread in { -0.32, 0.32 } do
			local angle = diagonal + spread
			local pole = Vector3.new(math.cos(angle) * 88, 0, math.sin(angle) * 88)
			pillar(folder, pole, 12, 0.35, WOOD, Enum.Material.Wood)
			local a = corner + Vector3.new(0, 16, 0)
			local b = pole + Vector3.new(0, 12, 0)
			local count = math.floor((b - a).Magnitude / 6)
			local previous: Attachment? = nil
			for k = 0, count do
				local s = k / count
				local at = a:Lerp(b, s) - Vector3.new(0, 4 * 4 * s * (1 - s), 0)
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
	end
end

-- Outside the wall -------------------------------------------------------------------------

local function sakuraRing()
	local rng = Random.new(110)
	for i = 0, 11 do
		local angle = (i + 0.5) / 12 * math.pi * 2
		local distance = rng:NextNumber(110, 130)
		local at = Vector3.new(math.cos(angle) * distance, -1, math.sin(angle) * distance)
		local tree = Models.spawn("sakura", folder, at, rng:NextNumber(1, 1.3), rng:NextNumber(0, 360))
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
		local base = Vector3.new(math.cos(angle) * distance, -1, math.sin(angle) * distance)
		local height = rng:NextNumber(14, 26)
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
		cloud(folder, at, Vector3.new(60, 2, 60), {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(150, 130, 190)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(14, 20),
			Lifetime = NumberRange.new(10, 14),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 0),
			Rate = 1.5,
		})
	end
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
	sakuraRing()
	forest()
	celebration()
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
