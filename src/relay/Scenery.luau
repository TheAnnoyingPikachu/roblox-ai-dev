--!strict
-- Relay Rounds world dressing: lighting, terrain and trees around the arena. Built once at server
-- start from Roblox materials and primitive parts (CLAUDE.md rule 9), so nothing lives in the place file.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Props = require(script.Parent:WaitForChild("Props"))

local Scenery = {}

-- Nothing is planted inside these boxes (minX, minZ, maxX, maxZ).
local ARENAS = {
	{ -165, -215, 305, 185 }, -- circuit, infield and grandstand
}

local function inArena(x: number, z: number, margin: number): boolean
	for _, box in ARENAS do
		if x > box[1] - margin and x < box[3] + margin and z > box[2] - margin and z < box[4] + margin then
			return true
		end
	end
	return false
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
	Lighting.ClockTime = 17.3 -- late-afternoon sun: long shadows and warm light
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 155)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.28,
		Offset = 0.15,
		Color = Color3.fromRGB(255, 212, 186),
		Decay = Color3.fromRGB(170, 105, 120),
		Glare = 0.4,
		Haze = 1.4,
	})
	effect("Sky", { SunAngularSize = 14, MoonAngularSize = 9 })
	effect("BloomEffect", { Intensity = 0.35, Size = 28, Threshold = 1.6 })
	effect("SunRaysEffect", { Intensity = 0.08, Spread = 0.8 })
	effect("ColorCorrectionEffect", {
		Saturation = 0.22,
		Contrast = 0.12,
		Brightness = 0.02,
		TintColor = Color3.fromRGB(255, 240, 228),
	})
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
	terrain:FillBlock(CFrame.new(-60, -8, 220), Vector3.new(1200, 12, 1300), Enum.Material.Grass)

	local rng = Random.new(20261025)
	local placed = 0
	while placed < 34 do
		local x, z = rng:NextNumber(-600, 480), rng:NextNumber(-380, 820)
		if not inArena(x, z, 60) then
			terrain:FillBall(Vector3.new(x, -rng:NextNumber(8, 20), z), rng:NextNumber(40, 75), Enum.Material.Grass)
			placed += 1
		end
	end
	terrain:FillBlock(CFrame.new(-280, -4, 0), Vector3.new(140, 8, 220), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-280, -5, 0), Vector3.new(140, 6, 220), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(-205, -3, 0), Vector3.new(14, 6, 230), Enum.Material.Sand)

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	local count = 0
	for attempt = 1, 900 do
		if count >= 170 then
			break
		end
		if attempt % 40 == 0 then
			task.wait()
		end
		local x, z = rng:NextNumber(-520, 420), rng:NextNumber(-300, 780)
		local inLake = x > -355 and x < -195 and z > -115 and z < 115
		if not inArena(x, z, 8) and not inLake then
			local ground = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
			local y = if ground then ground.Position.Y - 0.5 else 0
			tree(trees, Vector3.new(x, y, z), rng)
			count += 1
		end
	end
	-- Cherry blossoms line the edge of the arena.
	local blossoms = 0
	for _ = 1, 400 do
		if blossoms >= 36 then
			break
		end
		local x, z = rng:NextNumber(-230, 370), rng:NextNumber(-280, 250)
		if not inArena(x, z, 6) and inArena(x, z, 40) then
			Props.sakura(trees, Vector3.new(x, 0, z), rng)
			blossoms += 1
		end
	end
	trees.Parent = Workspace
end

return Scenery
