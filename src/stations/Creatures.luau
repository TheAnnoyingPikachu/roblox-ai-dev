--!strict
-- Animal Stations creature models (decision 0033): the jointed Blender creatures in StationAssets.
-- Each is loaded once, scaled to its measured size and rigged from the manifest: a hidden Root on
-- the ground, a Motor6D from it to the body, and one from the body to the head, each leg and the
-- tail at the joint the Blender build recorded. Neon `_glow` meshes ride on their piece. Models are
-- tagged "Creature"; the client animates the Motor6Ds from the Anim and AnimAt attributes set here
-- (stations-client/Creatures.client.luau). Display only: no game rules.

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StationAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationAssets"))

local Creatures = {}

-- How long each one-shot animation lasts (seconds); the client holds the matching poses.
Creatures.LENGTH = { attack = 0.95, magic = 1.6 }

-- The client's poses are written for legs this long (studs). A creature's Scale attribute is its
-- own leg length over this: poses, effects and the walk all grow with it.
local POSE_LEGS = 1.45
local STRIDE = 1.5 -- walk strides a second at Scale 1; bigger animals step slower
local STEP = 2.63 -- studs one stride covers at Scale 1 (the legs swing 27 degrees each way)

local FLAT = Vector3.new(1, 0, 1)
local templates: { [string]: Model | boolean } = {} -- true while loading, false when it failed

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function textureOf(entry: StationAssets.Asset): string?
	if entry.texture then
		return `rbxassetid://{entry.texture}`
	elseif entry.decal then
		-- The upload could not resolve the decal's image id: read it from the decal itself.
		local ok, loaded = pcall(InsertService.LoadAsset, InsertService, entry.decal)
		local decal = ok and loaded:FindFirstChildWhichIsA("Decal", true)
		return if decal then decal.Texture else nil
	end
	return nil
end

-- The rigged template for `name`, or nil when the asset is not uploaded or did not load.
local function build(name: string): Model?
	local entry = StationAssets[name]
	if entry == nil or entry.model == nil then
		return nil
	end
	local ok, loaded = pcall(InsertService.LoadAsset, InsertService, entry.model)
	if not ok then
		warn(`[Creatures] {name} failed to load: {tostring(loaded)}`)
		return nil
	end
	local texture = textureOf(entry)
	local model = Instance.new("Model")
	model.Name = name
	local parts: { [string]: MeshPart } = {}
	for _, d in loaded:GetDescendants() do
		if d:IsA("MeshPart") then
			parts[d.Name] = d
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
			local glow = entry.glow[d.Name]
			if glow then
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromRGB(glow[1], glow[2], glow[3])
				d.CastShadow = false
			elseif texture then
				d.TextureID = texture
			end
			d.Parent = model
		end
	end
	loaded:Destroy()
	for _, partName in entry.parts do
		if parts[partName] == nil then
			warn(`[Creatures] {name}: mesh {partName} is missing from model {entry.model}`)
			return nil
		end
	end
	-- Fit the measured height, whatever unit scale the importer used.
	local _, extents = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * entry.size[2] / extents.Y)

	-- Manifest space (x right, y up, z towards the head, origin on the ground under the middle)
	-- to world: the body's centre gives the place, the head's direction from it the yaw.
	local body, head = parts[`{name}_body`], parts[`{name}_head`]
	local cb, ch = vec(entry.centres[body.Name]), vec(entry.centres[head.Name])
	local want, have = (ch - cb) * FLAT, (head.Position - body.Position) * FLAT
	local yaw = math.atan2(have.X, have.Z) - math.atan2(want.X, want.Z)
	local frame = CFrame.new(body.Position) * CFrame.Angles(0, yaw, 0) * CFrame.new(-cb)
	for partName, c in entry.centres do
		local off = (frame * vec(c) - parts[partName].Position).Magnitude
		if off > 0.15 then
			warn(`[Creatures] {name}: {partName} is {off} studs from where the manifest puts it`)
		end
	end

	-- The Root faces the way the creature does (a CFrame looks along -Z; manifest +Z is the head).
	local rootFrame = frame * CFrame.Angles(0, math.pi, 0)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 0.2, 4)
	root.CFrame = rootFrame
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.Parent = model
	model.PrimaryPart = root

	-- A joint at world point `at` with the Root's axes: x right, y up, -z forward.
	local function joint(jointName: string, part0: BasePart, part1: BasePart, at: Vector3)
		local j = CFrame.new(at) * rootFrame.Rotation
		local m = Instance.new("Motor6D")
		m.Name = jointName
		m.Part0, m.Part1 = part0, part1
		m.C0 = part0.CFrame:Inverse() * j
		m.C1 = part1.CFrame:Inverse() * j
		m.Parent = part0
	end
	joint("body", root, body, frame * cb)
	for partName, j in entry.joints do
		joint(string.sub(partName, #name + 2), body, parts[partName], frame * vec(j)) -- "head", "leg_fl", ...
	end
	for partName in entry.glow do -- "<asset>_<piece>_glow" rides on "<asset>_<piece>"
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = parts[string.sub(partName, 1, -6)], parts[partName]
		weld.Parent = parts[partName]
	end
	for _, p in parts do
		p.Anchored = false
	end
	-- an unseen box round the whole animal, so the cursor can find it (its meshes take no rays)
	local hit = Instance.new("Part")
	hit.Name = "Hit"
	hit.Size = vec(entry.size)
	hit.CFrame = rootFrame * CFrame.new(0, entry.size[2] / 2, 0)
	hit.Transparency = 1
	hit.CanCollide, hit.CanTouch, hit.Massless = false, false, true
	local hold = Instance.new("WeldConstraint")
	hold.Part0, hold.Part1 = root, hit
	hold.Parent = hit
	hit.Parent = model
	CollectionService:AddTag(hit, "CreatureHit")
	local unit = entry.joints[`{name}_leg_fl`][2] / POSE_LEGS
	model:SetAttribute("Scale", unit)
	model:SetAttribute("Stride", STRIDE / math.sqrt(unit))

	if next(entry.glow) then -- a glowing variant lights its surroundings and sheds embers
		local _, rgb = next(entry.glow)
		local colour = Color3.fromRGB((rgb :: any)[1], (rgb :: any)[2], (rgb :: any)[3])
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = colour, 7 * unit, 1.4, false
		light.Parent = body
		local embers = Instance.new("ParticleEmitter")
		embers.Name = "Embers"
		embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		embers.Color = ColorSequence.new(colour, colour:Lerp(Color3.new(1, 1, 1), 0.5))
		embers.LightEmission = 1
		embers.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * unit), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(1.2, 2.4)
		embers.Rate = 14
		embers.Speed = NumberRange.new(1.5 * unit, 3 * unit)
		embers.SpreadAngle = Vector2.new(35, 35)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Acceleration = Vector3.new(0, 2, 0)
		embers.Parent = body
	end
	return model
end

local function template(name: string): Model?
	while templates[name] == true do -- another thread is loading it
		task.wait()
	end
	if templates[name] == nil then
		templates[name] = true
		templates[name] = build(name) or false
	end
	return (templates[name] or nil) :: Model?
end

-- Set which animation the creature plays, from now. The client reads these attributes.
function Creatures.play(model: Model, anim: string)
	model:SetAttribute("Anim", anim)
	model:SetAttribute("AnimAt", Workspace:GetServerTimeNow())
end

-- Studs a second that match the creature's walk animation, so its feet do not slide.
function Creatures.speed(model: Model): number
	return STEP * (model:GetAttribute("Scale") :: number) * (model:GetAttribute("Stride") :: number)
end

-- A creature standing at `at` (its feet there, facing along the CFrame's look vector), at the
-- size it was built. Nil when the asset is not uploaded yet or did not load.
-- The asset that shows species `s`, or its variant `v`: a variant "<word>_<species>" is the asset
-- "creature_<species>_<word>" (StationRules.spec keeps the ids in that form).
function Creatures.asset(s: string, v: string?): string
	local word = if v then string.match(v, "^(%l+)_") else nil
	return if word then `creature_{s}_{word}` else `creature_{s}`
end

function Creatures.spawn(name: string, at: CFrame, parent: Instance): Model?
	local source = template(name)
	if source == nil then
		return nil
	end
	local model = source:Clone()
	model:PivotTo(at)
	model:SetAttribute("Asset", name)
	Creatures.play(model, "idle")
	CollectionService:AddTag(model, "Creature")
	model.Parent = parent
	return model
end

return Creatures
