--!strict
-- Splash Island (GDD T2, docs/architecture/garden.md 4.1, 9): the static course under
-- Workspace.Garden.Dash, and the ready pad in the plaza. Moving obstacles are not here: they exist
-- only on clients. Parts are built first; a Blender model replaces its fallback once it has loaded,
-- so the course plays with no art. Decks are always parts: no mesh collision on the course.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar = Props.part, Props.pillar

local DashWorld = {}

local DECK_TOP = 140
local DECK_THICK = 2
local WALL = 30 -- high enough that nobody jumps out of the start deck during the hold
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(60, 45, 40)
local TRIM = Color3.fromRGB(255, 225, 110)
local READY_PAD = Vector3.new(-26, 0, -22)
local ARCHES = { Vector3.new(-100, DECK_TOP, 300), Vector3.new(-120, DECK_TOP, 400) }

-- x1, x2, z1, z2, colour. Lily Hop has no deck: its platforms are client obstacles.
local DECKS = {
	{ -140, -100, 280, 320, Color3.fromRGB(255, 190, 215) }, -- start
	{ -100, -20, 278, 322, Color3.fromRGB(190, 240, 170) }, -- Sweeper Green
	{ -20, 112, 288, 312, Color3.fromRGB(255, 240, 170) }, -- Ball Alley, to CP2
	{ 95, 105, 312, 388, Color3.fromRGB(190, 225, 255) }, -- Pendulum Bridge
	{ 88, 112, 388, 412, Color3.fromRGB(255, 240, 170) }, -- CP3
	{ -132, -8, 388, 412, Color3.fromRGB(225, 205, 255) }, -- CP4, Last Sprint and the finish
}

-- Scenery that players and raycasts pass through.
local function decor<T>(p: T): T
	local b: BasePart = p :: any
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	return p
end

-- An invisible wall that keeps racers on the start deck until GO.
local function wall(parent: Instance, size: Vector3, at: Vector3): Part
	local w = part(parent, size, at, WHITE)
	w.Transparency = 1
	return w
end

local function decks(parent: Instance)
	for _, d in DECKS do
		local x1, x2, z1, z2 = d[1] :: number, d[2] :: number, d[3] :: number, d[4] :: number
		local mid = Vector3.new((x1 + x2) / 2, DECK_TOP - DECK_THICK / 2, (z1 + z2) / 2)
		part(parent, Vector3.new(x2 - x1, DECK_THICK, z2 - z1), mid, d[5] :: Color3)
		-- Painted edge strips only: a knock off the side is the point of the course.
		local alongX = x2 - x1 > z2 - z1
		for _, side in { -1, 1 } do
			local size = if alongX then Vector3.new(x2 - x1, 0.3, 0.6) else Vector3.new(0.6, 0.3, z2 - z1)
			local offset = if alongX then Vector3.zAxis * (z2 - z1) / 2 else Vector3.xAxis * (x2 - x1) / 2
			local at = Vector3.new(mid.X, DECK_TOP + 0.15, mid.Z) + offset * side
			decor(part(parent, size, at, TRIM, Enum.Material.Neon))
		end
	end
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

local function arches(parent: Instance)
	for _, at in ARCHES do
		local fallback = Instance.new("Model")
		fallback.Name = "ArchFallback"
		for _, z in { -14, 14 } do
			part(fallback, Vector3.new(1.5, 18, 1.5), at + Vector3.new(0, 9, z), WHITE, Enum.Material.Wood)
		end
		part(fallback, Vector3.new(1.5, 2, 29.5), at + Vector3.new(0, 18, 0), TRIM, Enum.Material.Neon)
		Models.ghost(fallback)
		fallback.Parent = parent
		swap("dash_arch", parent, at, 90, fallback)
		-- On its own part, so it outlives the swap: Moonfall must not hide the arches (GDD T2).
		local anchor = decor(part(parent, Vector3.one, at + Vector3.new(0, 16, 0), WHITE))
		anchor.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = TRIM
		light.Range = 30
		light.Parent = anchor
	end
end

local function readyPad(parent: Instance): (ProximityPrompt, TextLabel)
	local fallback =
		decor(pillar(parent, READY_PAD, 0.5, 6, Color3.fromRGB(110, 185, 255), Enum.Material.SmoothPlastic))
	swap("dash_ready_pad", parent, READY_PAD, 0, fallback)
	local pad = decor(part(parent, Vector3.new(12, 0.2, 12), READY_PAD + Vector3.new(0, 0.7, 0), WHITE))
	pad.Name = "ReadyPad"
	pad.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Ready"
	prompt.ActionText = "Ready"
	prompt.ObjectText = GardenConfig.DASH.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = pad
	local label = Instance.new("TextLabel")
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
	return prompt, label
end

local function padText(status: { [string]: any }): string
	if status.phase == "idle" then
		return `{#status.ready} / {status.need} ready`
	elseif status.phase == "countdown" then
		return `Starting in {math.max(0, math.ceil(status.at - Workspace:GetServerTimeNow()))}`
	end
	return "Race running"
end

-- Builds the island once. Call after World.build, which creates Workspace.Garden.
function DashWorld.build(): { arch: BasePart, prompt: ProximityPrompt, label: (status: { [string]: any }) -> () }
	local root = Workspace:WaitForChild("Garden")
	local folder = Instance.new("Folder")
	folder.Name = "Dash"
	decks(folder)
	local water = part(
		folder,
		Vector3.new(320, 1, 180),
		Vector3.new(-10, 117.5, 350),
		Color3.fromRGB(70, 160, 255),
		Enum.Material.SmoothPlastic
	)
	water.Name = "Water"
	water.Transparency = 1 -- only catches falls: the island pond is the water players see
	-- Base 75 puts the pond under the fall line (fellY 125) and the rim trees just below the decks.
	swap("dash_island", folder, Vector3.new(-10, 75, 350), 0)
	arches(folder)
	wall(folder, Vector3.new(1, WALL, 40), Vector3.new(-140, DECK_TOP + WALL / 2, 300))
	wall(folder, Vector3.new(40, WALL, 1), Vector3.new(-120, DECK_TOP + WALL / 2, 280))
	wall(folder, Vector3.new(40, WALL, 1), Vector3.new(-120, DECK_TOP + WALL / 2, 320))
	local arch = wall(folder, Vector3.new(1, WALL, 44), Vector3.new(-100, DECK_TOP + WALL / 2, 300))
	arch.Name = "StartBarrier"
	local prompt, label = readyPad(folder)
	folder.Parent = root
	-- World.build counted the valley before this existed; keep the GDD I4 budget check whole.
	local parts = (root:GetAttribute("Parts") or 0) + #folder:GetDescendants()
	root:SetAttribute("Parts", parts)
	if parts > 6000 then
		warn(`[DashWorld] {parts} parts, over the 6,000 budget`)
	end
	return {
		arch = arch,
		prompt = prompt,
		label = function(status: { [string]: any })
			label.Text = padText(status)
		end,
	}
end

return DashWorld
