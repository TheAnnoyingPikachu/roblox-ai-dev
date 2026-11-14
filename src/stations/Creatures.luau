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
local StationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationConfig"))
local StationRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationRules"))

local Creatures = {}

-- How long each one-shot animation lasts (seconds); the client holds the matching poses.
Creatures.LENGTH = { attack = 0.95, magic = 1.6, hit = 0.4, die = 1.2 }

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

local DARK = Color3.fromRGB(70, 30, 110) -- the glow of their aura

-- An evil aura for a Hexbound model (decisions 0042, 0043): a dark glow, thick black-violet smoke
-- rising off the footprint and one faint deep-violet light. Built into the model, so it costs the
-- server nothing while it runs, and kept small: about 25 live particles and one light with no
-- shadows for each enemy.
local function aura(model: Model, root: BasePart, rootFrame: CFrame, size: { number }, unit: number)
	local w, l = size[1] * 0.8, size[3] * 0.8
	local base = Instance.new("Part")
	base.Name = "Aura"
	base.Size = Vector3.new(w, 0.2, l)
	base.CFrame = rootFrame * CFrame.new(0, 0.15, 0)
	base.Transparency = 1
	base.CanCollide, base.CanQuery, base.CanTouch, base.CastShadow, base.Massless = false, false, false, false, true
	local hold = Instance.new("WeldConstraint")
	hold.Part0, hold.Part1 = root, base
	hold.Parent = base
	base.Parent = model

	local haze = Instance.new("ParticleEmitter")
	haze.Name = "Haze"
	haze.Texture = "rbxasset://textures/particles/smoke_main.dds"
	haze.Color = ColorSequence.new(Color3.fromRGB(58, 24, 90), Color3.fromRGB(6, 4, 12))
	haze.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	haze.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4 * unit), NumberSequenceKeypoint.new(1, 3.6 * unit) })
	haze.Lifetime = NumberRange.new(1.8, 3)
	haze.Rate = 12
	haze.Speed = NumberRange.new(0.8, 2.2)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.LightEmission = 0.05
	haze.Acceleration = Vector3.new(0, 1.4, 0)
	haze.Shape = Enum.ParticleEmitterShape.Box
	haze.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	haze.EmissionDirection = Enum.NormalId.Top
	haze.Parent = base

	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = DARK, 9 * unit, 0.6, false
	light.Parent = base
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
	-- the leg length the poses scale by: the front legs' joint on an animal, the hips' on a Hexbound
	-- (their front "legs" are arms, hung from the shoulders)
	local hexbound = string.sub(name, 1, 4) == "foe_"
	local unit = entry.joints[if hexbound then `{name}_leg_bl` else `{name}_leg_fl`][2] / POSE_LEGS
	model:SetAttribute("Scale", unit)
	model:SetAttribute("Stride", STRIDE / math.sqrt(unit))
	if hexbound then
		model:SetAttribute("Hexbound", true)
		model:SetAttribute(if name == "foe_dragon" then "Winged" else "Biped", true)
		aura(model, root, rootFrame, entry.size, unit)
	end

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
	return StationRules.assetOf(s, v)
end

-- How a Hexbound foe looks (decision 0042) is in its StationConfig entry: the model of its kind, a
-- size and a tint. A tier of a kind is the same model bigger, smaller or tinted, not a new one.
export type Look = { model: string, size: number?, tint: Color3? }
local function lookOf(foeId: string): Look?
	local f = StationConfig.foe(foeId)
	if f == nil then
		return nil
	end
	local t = f.tint
	return { model = f.model, size = f.size, tint = if t then Color3.fromRGB(t[1], t[2], t[3]) else nil }
end

-- What the card under the cursor reads: an animal's species, variant and six stats (its own, with
-- its training, or its version's), set as attributes so every player's client sees them.
function Creatures.describe(model: Model, s: string, v: string?, animal: StationRules.Owned?)
	model:SetAttribute("Species", s)
	model:SetAttribute("Variant", v)
	local plain = StationRules.versionStats(s, v) :: StationConfig.Stats
	for _, stat in StationConfig.STATS do
		model:SetAttribute(stat, if animal then StationRules.stat(animal, stat) else (plain :: any)[stat])
	end
end

-- The same for a Hexbound foe: its id and the stats it has at this wave.
function Creatures.describeFoe(model: Model, foeId: string, stats: StationConfig.Stats)
	model:SetAttribute("FoeId", foeId)
	for _, stat in StationConfig.STATS do
		model:SetAttribute(stat, (stats :: any)[stat])
	end
end

function Creatures.spawn(name: string, at: CFrame, parent: Instance, look: Look?): Model?
	local source = template(name)
	if source == nil then
		return nil
	end
	local model = source:Clone()
	model:PivotTo(at)
	if look then
		local size = look.size or 1
		if size ~= 1 then
			model:ScaleTo(model:GetScale() * size)
			local scale = (model:GetAttribute("Scale") :: number) * size
			model:SetAttribute("Scale", scale)
			model:SetAttribute("Stride", STRIDE / math.sqrt(scale))
		end
		if look.tint then
			for _, d in model:GetDescendants() do
				if d:IsA("MeshPart") and d.Material ~= Enum.Material.Neon then
					d.Color = look.tint
				end
			end
		end
	end
	model:SetAttribute("Asset", name)
	Creatures.play(model, "idle")
	CollectionService:AddTag(model, "Creature")
	model.Parent = parent
	return model
end

-- Still copies of every uploaded model for the client's picture frames (decision 0044): the meshes
-- in their rest pose, with no joints, lights, particles or hit box, in ReplicatedStorage.Portraits.
-- They load in the background and appear as they are ready; the client waits for each.
function Creatures.publishPortraits()
	local folder = ReplicatedStorage:FindFirstChild("Portraits") or Instance.new("Folder")
	folder.Name = "Portraits"
	folder.Parent = ReplicatedStorage
	for name, entry in StationAssets do
		if entry.model == nil then
			continue
		end
		task.spawn(function()
			local source = template(name)
			if source == nil then
				return
			end
			local copy = source:Clone()
			for _, d in copy:GetDescendants() do
				if
					d:IsA("Motor6D")
					or d:IsA("WeldConstraint")
					or d:IsA("ParticleEmitter")
					or d:IsA("PointLight")
					or d.Name == "Hit"
					or d.Name == "Aura"
				then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			copy.Parent = folder
		end)
	end
end

-- A foe standing at `at`, in its own size and tint. Nil when its model is not uploaded.
function Creatures.spawnFoe(foeId: string, at: CFrame, parent: Instance): Model?
	local look = lookOf(foeId)
	return if look then Creatures.spawn(look.model, at, parent, look) else nil
end

-- The size in studs a foe is once spawned (width, height, depth), for placing a line of them.
function Creatures.foeSize(foeId: string): Vector3
	local f = StationConfig.foe(foeId) :: StationConfig.Foe
	local size = StationAssets[f.model].size
	return Vector3.new(size[1], size[2], size[3]) * (f.size or 1)
end

return Creatures
