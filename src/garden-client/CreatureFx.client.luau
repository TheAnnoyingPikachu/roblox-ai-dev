--!strict
-- Egg Garden creature looks (GDD I3, I4 "Life"; docs/architecture/garden.md section 6): idle bob,
-- hop and turn on every creature (local CFrame offsets, no rigs), mutation looks from the `M`
-- attribute (Golden texture swap, Moonlit and Rainbow Highlights with a SelectionBox fallback past
-- the Highlight budget), hiding a creature while HatchFx reveals it, and ambient life (windmill
-- sails, butterflies, drifting petals). Display only: sends nothing and changes nothing the server owns.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local camera = Workspace.CurrentCamera
local fxFolder = Workspace:WaitForChild("GardenClientFx", 30) or Workspace

-- Roblox renders about 31 Highlights at once; the reveal needs a few, the rest fall back.
local HIGHLIGHT_BUDGET = 26
local highlights = 0

type View = {
	inst: Instance,
	id: number,
	parts: { BasePart },
	base: CFrame,
	written: CFrame,
	phase: number,
	hopAt: number,
	look: Instance?,
	mutation: string,
	hidden: boolean,
}
local views: { [Instance]: View } = {}

local function pivot(inst: Instance): CFrame
	return if inst:IsA("BasePart") then inst.CFrame else (inst :: Model):GetPivot()
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	else
		(inst :: Model):PivotTo(cf)
	end
end

local function partsOf(inst: Instance): { BasePart }
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function emitter(parent: Instance, colour: ColorSequence, rate: number): ParticleEmitter
	return ClientState.new("ParticleEmitter", {
		Color = colour,
		Size = NumberSequence.new(0.35, 0),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(0.6, 1.4),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.8,
		Rate = rate,
		Parent = parent,
	})
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
})

-- Mutation looks (I3). Returns the Highlight or SelectionBox that the frame loop tints, if any.
local function applyLook(view: View): Instance?
	local m = view.mutation
	local main = view.parts[1]
	if main == nil or m == "normal" then
		return nil
	end
	if m == "golden" then
		for _, p in view.parts do
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			p.Color = Color3.fromRGB(255, 200, 60)
			p.Material = Enum.Material.Foil
		end
		ClientState.new("Sparkles", { SparkleColor = Color3.fromRGB(255, 220, 120), Parent = main })
		return nil
	end
	local fill = if m == "moonlit" then Color3.fromRGB(120, 140, 255) else Color3.fromRGB(255, 120, 200)
	emitter(main, if m == "moonlit" then ColorSequence.new(Color3.fromRGB(200, 210, 255)) else RAINBOW, 4)
	if highlights < HIGHLIGHT_BUDGET then
		highlights += 1
		local h = ClientState.new("Highlight", {
			FillColor = fill,
			FillTransparency = 0.6,
			OutlineColor = fill,
			OutlineTransparency = 0.3,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Adornee = view.inst,
			Parent = view.inst,
		})
		h.Destroying:Once(function()
			highlights -= 1
		end)
		return h
	end
	-- shortcut: fallbacks stay SelectionBoxes after a Highlight frees up; re-check on respawn is enough.
	return ClientState.new("SelectionBox", {
		Color3 = fill,
		SurfaceColor3 = fill,
		SurfaceTransparency = 0.85,
		LineThickness = 0.05,
		Transparency = 0.4,
		Adornee = view.inst,
		Parent = view.inst,
	})
end

local function track(inst: Instance)
	if views[inst] or not (inst:IsA("BasePart") or inst:IsA("Model")) then
		return
	end
	local id = tonumber(inst:GetAttribute("Id")) or tonumber(inst.Name)
	if id == nil then
		return
	end
	local base = pivot(inst)
	local view: View = {
		inst = inst,
		id = id,
		parts = partsOf(inst),
		base = base,
		written = base,
		phase = math.random() * math.pi * 2,
		hopAt = os.clock() + 2 + math.random() * 6,
		look = nil,
		mutation = tostring(inst:GetAttribute("M") or "normal"),
		hidden = false,
	}
	view.look = applyLook(view)
	views[inst] = view
	inst.Destroying:Once(function()
		views[inst] = nil
	end)
end

-- New creatures are tracked the moment they replicate so a fresh hatch is hidden before it is seen.
task.spawn(function()
	local root = Workspace:WaitForChild("Garden")
	root.DescendantAdded:Connect(function(inst)
		if inst.Parent and inst.Parent.Name == "Creatures" then
			track(inst)
		end
	end)
end)

-- Backup sweep of Workspace.Garden.Plots.Plot<n>.Creatures (twice a second; cheap at 120 max).
task.spawn(function()
	while true do
		local root = Workspace:FindFirstChild("Garden")
		local plots = root and root:FindFirstChild("Plots")
		for _, plot in if plots then plots:GetChildren() else {} do
			local folder = plot:FindFirstChild("Creatures")
			for _, c in if folder then folder:GetChildren() else {} do
				track(c)
			end
		end
		for inst in views do
			if not inst:IsDescendantOf(Workspace) then
				views[inst] = nil
			end
		end
		task.wait(0.5)
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local eye = camera.CFrame.Position
	for inst, view in views do
		local current = pivot(inst)
		-- The server moved or rebuilt it: take its new spot as the base.
		if
			(current.Position - view.written.Position).Magnitude > 0.01
			or current.LookVector:Dot(view.written.LookVector) < 0.999
		then
			view.base = current
		end
		local hidden = ClientState.hidden[view.id] == true
		if hidden ~= view.hidden then
			view.hidden = hidden
			for _, p in view.parts do
				p.LocalTransparencyModifier = if hidden then 1 else 0
			end
			if view.look then
				(view.look :: any).Enabled = not hidden
			end
		end
		if view.look and view.mutation == "rainbow" and not hidden then
			local hue = Color3.fromHSV((t * 0.25 + view.phase) % 1, 0.55, 1)
			if view.look:IsA("Highlight") then
				view.look.FillColor = hue
				view.look.OutlineColor = hue
			elseif view.look:IsA("SelectionBox") then
				view.look.Color3 = hue
				view.look.SurfaceColor3 = hue
			end
		end
		if (view.base.Position - eye).Magnitude > 160 then
			continue
		end
		local bob = math.sin(t * 2 + view.phase) * 0.18
		if t > view.hopAt + 0.45 then
			view.hopAt = t + 3 + math.random() * 6
		end
		local h = if t >= view.hopAt then (t - view.hopAt) / 0.45 else -1
		local hop = if h >= 0 and h <= 1 then math.sin(h * math.pi) * 1.1 else 0
		local turn = math.sin(t * 0.5 + view.phase * 2) * 0.45
		local cf = view.base * CFrame.new(0, bob + hop, 0) * CFrame.Angles(0, turn, 0)
		setPivot(inst, cf)
		view.written = cf
	end
end)

-- Ambient life ----------------------------------------------------------------------------------------

-- Windmill sails (World.luau; shortcut: found by the name "Sails", switch to a tag if renamed).
local sails: Instance? = nil
local sailsBase: CFrame? = nil
task.spawn(function()
	while sails == nil do
		local root = Workspace:FindFirstChild("Garden")
		local found = root and root:FindFirstChild("Sails", true)
		if found and (found:IsA("BasePart") or found:IsA("Model")) then
			sails = found
			sailsBase = pivot(found)
		end
		task.wait(3)
	end
end)

-- Butterflies wander over the plaza and meadows.
local BUTTERFLY_COLOURS = {
	Color3.fromRGB(255, 170, 200),
	Color3.fromRGB(255, 225, 120),
	Color3.fromRGB(170, 210, 255),
	Color3.fromRGB(200, 170, 255),
	Color3.fromRGB(170, 240, 190),
}
type Butterfly = { wings: { BasePart }, centre: Vector3, seed: number }
local butterflies: { Butterfly } = {}
for i = 1, 16 do
	local angle = i / 16 * math.pi * 2
	local radius = 25 + (i % 4) * 14
	local colour = BUTTERFLY_COLOURS[i % #BUTTERFLY_COLOURS + 1]
	local wings = {}
	for _ = 1, 2 do
		table.insert(
			wings,
			ClientState.new("Part", {
				Size = Vector3.new(0.5, 0.05, 0.6),
				Color = colour,
				Material = Enum.Material.Neon,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Parent = fxFolder,
			})
		)
	end
	table.insert(butterflies, {
		wings = wings,
		centre = Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius),
		seed = i * 7.3,
	})
end

-- Petals drifting down over the valley.
local petalSky = ClientState.new("Part", {
	Name = "PetalSky",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(300, 1, 300),
	Position = Vector3.new(0, 45, 0),
	Parent = fxFolder,
})
ClientState.new("ParticleEmitter", {
	Color = ColorSequence.new(Color3.fromRGB(255, 190, 215), Color3.fromRGB(255, 230, 240)),
	Size = NumberSequence.new(0.35),
	Squash = NumberSequence.new(-0.6),
	Lifetime = NumberRange.new(10, 14),
	Speed = NumberRange.new(2, 4),
	EmissionDirection = Enum.NormalId.Bottom,
	RotSpeed = NumberRange.new(-90, 90),
	Rotation = NumberRange.new(0, 360),
	Acceleration = Vector3.new(1.5, 0, 0.5),
	Rate = 10,
	Parent = petalSky,
})

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local s, base = sails, sailsBase
	if s and base and s.Parent then
		setPivot(s, base * CFrame.Angles(0, 0, t * 0.6))
	end
	for _, b in butterflies do
		local x = math.noise(b.seed, t * 0.15) * 18
		local z = math.noise(b.seed + 50, t * 0.15) * 18
		local y = 2.5 + math.noise(b.seed + 100, t * 0.3) * 2
		local pos = b.centre + Vector3.new(x, y, z)
		local ahead = b.centre
			+ Vector3.new(math.noise(b.seed, t * 0.15 + 0.05) * 18, y, math.noise(b.seed + 50, t * 0.15 + 0.05) * 18)
		local frame = CFrame.lookAt(pos, if (ahead - pos).Magnitude > 0.01 then ahead else pos + Vector3.zAxis)
		local flap = math.sin(t * 18 + b.seed) * 0.9
		b.wings[1].CFrame = frame * CFrame.Angles(0, 0, flap) * CFrame.new(-0.25, 0, 0)
		b.wings[2].CFrame = frame * CFrame.Angles(0, 0, -flap) * CFrame.new(0.25, 0, 0)
	end
end)
