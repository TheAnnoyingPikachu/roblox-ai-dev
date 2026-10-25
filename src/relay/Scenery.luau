--!strict
-- Relay Rounds world dressing: lighting, terrain and trees around the arena. Built once at server
-- start from Roblox materials and primitive parts (CLAUDE.md rule 9), so nothing lives in the place file.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Scenery = {}

-- Nothing is planted inside this box: it holds the lobby, course lanes and stands.
local ARENA_MIN = Vector2.new(-70, -90)
local ARENA_MAX = Vector2.new(140, 330)

local function inArena(x: number, z: number, margin: number): boolean
	return x > ARENA_MIN.X - margin
		and x < ARENA_MAX.X + margin
		and z > ARENA_MIN.Y - margin
		and z < ARENA_MAX.Y + margin
end

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

function Scenery.lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 155)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.28,
		Offset = 0.15,
		Color = Color3.fromRGB(199, 214, 235),
		Decay = Color3.fromRGB(106, 134, 170),
		Glare = 0.4,
		Haze = 1.4,
	})
	effect("Sky", { SunAngularSize = 14, MoonAngularSize = 9 })
	effect("BloomEffect", { Intensity = 0.35, Size = 28, Threshold = 1.6 })
	effect("SunRaysEffect", { Intensity = 0.08, Spread = 0.8 })
	effect("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.08, Brightness = 0.02 })
end

local function tree(parent: Instance, base: Vector3, rng: Random)
	local height = rng:NextNumber(10, 18)
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(106, 76, 52)
	trunk.Size = Vector3.new(height, 2, 2)
	trunk.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = parent
	local greens = { Color3.fromRGB(75, 151, 75), Color3.fromRGB(58, 125, 21), Color3.fromRGB(91, 154, 76) }
	for i = 1, rng:NextInteger(2, 4) do
		local leaves = Instance.new("Part")
		leaves.Shape = Enum.PartType.Ball
		leaves.Anchored = true
		leaves.Material = Enum.Material.LeafyGrass
		leaves.Color = greens[rng:NextInteger(1, #greens)]
		local size = rng:NextNumber(8, 12) - i
		leaves.Size = Vector3.new(size, size, size)
		leaves.Position = base + Vector3.new(rng:NextNumber(-2.5, 2.5), height - 1 + i * 2.2, rng:NextNumber(-2.5, 2.5))
		leaves.Parent = parent
	end
end

-- Grass ground, rolling hills, a lake, dirt paths and a forest ring around the arena.
function Scenery.world()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:FillBlock(CFrame.new(0, -8, 120), Vector3.new(900, 12, 1000), Enum.Material.Grass)

	local rng = Random.new(20261025)
	local placed = 0
	while placed < 26 do
		local x, z = rng:NextNumber(-380, 400), rng:NextNumber(-360, 580)
		if not inArena(x, z, 60) then
			terrain:FillBall(Vector3.new(x, -rng:NextNumber(8, 20), z), rng:NextNumber(40, 75), Enum.Material.Grass)
			placed += 1
		end
	end
	terrain:FillBlock(CFrame.new(-200, -4, 140), Vector3.new(140, 8, 220), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-200, -5, 140), Vector3.new(140, 6, 220), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(-145, -3, 140), Vector3.new(14, 6, 230), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(-35, -2.4, 20), Vector3.new(12, 1, 200), Enum.Material.Ground)

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	local count = 0
	for attempt = 1, 600 do
		if count >= 140 then
			break
		end
		if attempt % 40 == 0 then
			task.wait()
		end
		local x, z = rng:NextNumber(-300, 360), rng:NextNumber(-260, 520)
		local inLake = x > -275 and x < -125 and z > 25 and z < 255
		if not inArena(x, z, 8) and not inLake then
			local ground = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
			local y = if ground then ground.Position.Y - 0.5 else 0
			tree(trees, Vector3.new(x, y, z), rng)
			count += 1
		end
	end
	trees.Parent = Workspace
end

return Scenery
