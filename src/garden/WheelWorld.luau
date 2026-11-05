--!strict
-- The Petal Patch and the wheel stand (garden-wheel.md W2, architecture garden-wheel.md 3.3) under
-- Workspace.Garden.Wheel. Parts are built first; a Blender model (wheel_tree, wheel_stand) replaces
-- its fallback once it has loaded, so the patch plays with no art. The disc that spins is client-side
-- (WheelFx); the server's disc is a plain decor cylinder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar = Props.part, Props.pillar

local WheelWorld = {}

local WHEEL = GardenConfig.WHEEL
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(60, 45, 40)
local GRASS = Color3.fromRGB(150, 215, 130)
local PICKET = Color3.fromRGB(255, 250, 240)
local BARK = Color3.fromRGB(78, 52, 46)
local POST = 2.5
local POST_GAP = 3
local OPENING = 6

local function vec(s: GardenConfig.Spot): Vector3
	return Vector3.new(s.x, s.y, s.z)
end

-- Scenery that players and raycasts pass through (DashWorld's pattern).
local function decor<T>(p: T): T
	local b: BasePart = p :: any
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	return p
end

-- Replaces `fallback` with the model `name` once it has loaded; no uploaded id keeps the fallback.
local function swap(name: string, parent: Instance, base: Vector3, yaw: number, fallback: Instance?)
	task.spawn(function()
		local model = Models.night(name, parent, base, yaw)
		if model then
			Models.ghost(model)
			if fallback then
				fallback:Destroy()
			end
		end
	end)
end

-- Picket posts every 3 studs round the square, with two 6-stud openings on the plaza (+z) side.
local function fence(parent: Instance, centre: Vector3)
	local half = WHEEL.size / 2
	local openings = { centre.X - half / 2, centre.X + half / 2 }
	local function post(at: Vector3)
		decor(part(parent, Vector3.new(0.4, POST, 0.4), at + Vector3.new(0, POST / 2, 0), PICKET))
	end
	for d = -half, half, POST_GAP do
		for _, side in { -1, 1 } do
			post(centre + Vector3.new(side * half, 0, d)) -- east and west runs, corners included
			local x = centre.X + d
			local open = math.abs(x - openings[1]) < OPENING / 2 or math.abs(x - openings[2]) < OPENING / 2
			if math.abs(d) < half and not (side > 0 and open) then
				post(Vector3.new(x, centre.Y, centre.Z + side * half))
			end
		end
	end
end

local function tree(parent: Instance, centre: Vector3)
	pillar(parent, centre, 6, 2, BARK, Enum.Material.Wood).Name = "Trunk"
	local fallback = Instance.new("Model")
	fallback.Name = "wheel_tree" -- the art task's asset name; Models.night replaces it
	Props.sakura(fallback, centre, Random.new(16))
	Models.ghost(fallback)
	fallback.Parent = parent
	swap("wheel_tree", parent, centre, 0, fallback)
end

local function stand(parent: Instance, at: Vector3): ProximityPrompt
	local fallback = Instance.new("Model")
	fallback.Name = "wheel_stand"
	part(fallback, Vector3.new(1, 8, 1), at + Vector3.new(0, 4, 0), BARK, Enum.Material.Wood)
	local disc = part(
		fallback,
		Vector3.new(0.6, 6, 6),
		CFrame.new(at + Vector3.new(0, 5, 0.5)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 196, 64)
	)
	disc.Shape = Enum.PartType.Cylinder
	Models.ghost(fallback)
	fallback.Parent = parent
	-- The model's front is -z at yaw 0 (artist's note), so 180 turns it to the plaza; its axle is then
	-- at stand + (0, 5, 0.5), where WheelFx pivots the client disc.
	swap("wheel_stand", parent, at, 180, fallback)
	local pad = decor(part(parent, Vector3.new(6, 0.2, 6), at + Vector3.new(0, 0.1, 0), WHITE))
	pad.Name = "StandPad"
	pad.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Play"
	prompt.ActionText = "Play"
	prompt.ObjectText = WHEEL.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = WHEEL.promptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.MaxDistance = 100
	gui.LightInfluence = 0
	gui.Parent = pad
	local label = Instance.new("TextLabel")
	label.Name = "SpinsLabel" -- the client writes it from its own Profile
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.Parent = label
	label.Parent = gui
	return prompt
end

-- Builds the patch once. Call after World.build, which creates Workspace.Garden.
function WheelWorld.build(): { prompt: ProximityPrompt, folder: Folder }
	local root = Workspace:WaitForChild("Garden")
	local folder = Instance.new("Folder")
	folder.Name = "Wheel"
	local centre = vec(WHEEL.centre)
	local grass = part(
		folder,
		Vector3.new(WHEEL.size, 0.4, WHEEL.size),
		centre + Vector3.new(0, 0.2, 0),
		GRASS,
		Enum.Material.Grass
	)
	grass.Name = "Grass"
	fence(folder, centre)
	tree(folder, centre)
	local prompt = stand(folder, vec(WHEEL.stand))
	folder.Parent = root
	-- World.build counted the valley before this existed; keep the GDD I4 budget check whole.
	local parts = (root:GetAttribute("Parts") or 0) + #folder:GetDescendants()
	root:SetAttribute("Parts", parts)
	if parts > 6000 then
		warn(`[WheelWorld] {parts} parts, over the 6,000 budget`)
	end
	return { prompt = prompt, folder = folder }
end

return WheelWorld
