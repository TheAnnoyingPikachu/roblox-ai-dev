--!strict
-- Animates every creature model (tag "Creature", built by stations/Creatures.luau). The server
-- sets each model's Anim ("idle", "walk", "attack", "magic") and AnimAt (server time) attributes
-- and moves its Root; this script poses the Motor6Ds every frame and plays the magic attack's
-- effects. Display only: nothing here decides anything.
--
-- A pose is { joint = { pitch, yaw, roll (degrees), x, y, z (studs at scale 1) } }. Joints share
-- the Root's axes: x right, y up, -z forward. Positive pitch lifts the nose (or swings a foot
-- forward); positive yaw turns left.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

type Pose = { [string]: { number } }
type Clip = { length: number, keys: { { any } } }

local JOINTS = { "body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail" }
local TAU = math.pi * 2
local MAGIC_IMPACT = 0.92 -- seconds into "magic" when the front feet land

-- Horn attack: crouch back with the head down, lunge and throw the horn up, settle.
local ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{
			0.28,
			{
				body = { -5, 0, 0, 0, -0.06, 0.45 },
				head = { -24 },
				leg_fl = { 14 },
				leg_fr = { 14 },
				leg_bl = { 9 },
				leg_br = { 9 },
				tail = { -18 },
			},
		},
		{
			0.42,
			{
				body = { 7, 0, 0, 0, 0.1, -1.0 },
				head = { 30 },
				leg_fl = { -26 },
				leg_fr = { -26 },
				leg_bl = { -22 },
				leg_br = { -22 },
				tail = { 22 },
			},
		},
		{
			0.62,
			{
				body = { 3, 0, 0, 0, 0.03, -0.6 },
				head = { 14 },
				leg_fl = { -12 },
				leg_fr = { -12 },
				leg_bl = { -9 },
				leg_br = { -9 },
			},
		},
		{ 0.95, {} },
	},
}

-- Magic attack: rear up on the hind legs, paw the air while the horn charges, slam down.
local MAGIC: Clip = {
	length = 1.6,
	keys = {
		{ 0.00, {} },
		{
			0.40,
			{
				body = { 26, 0, 0, 0, 0.42, 0.26 },
				head = { 12 },
				leg_fl = { 52 },
				leg_fr = { 42 },
				leg_bl = { -26 },
				leg_br = { -26 },
				tail = { -22 },
			},
		},
		{
			0.78,
			{
				body = { 30, 0, 0, 0, 0.5, 0.3 },
				head = { 16 },
				leg_fl = { 40 },
				leg_fr = { 58 },
				leg_bl = { -30 },
				leg_br = { -30 },
				tail = { -28 },
			},
		},
		{
			MAGIC_IMPACT,
			{
				body = { -6, 0, 0, 0, -0.14, -0.2 },
				head = { -16 },
				leg_fl = { -4 },
				leg_fr = { -4 },
				leg_bl = { 6 },
				leg_br = { 6 },
				tail = { 20 },
			},
		},
		{ 1.12, { body = { 2, 0, 0, 0, 0.05, 0 }, head = { 7 } } },
		{ 1.60, {} },
	},
}

local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

-- The clip's pose at time t: the two keys around t blended with a smooth ease.
local function sample(clip: Clip, t: number): Pose
	local keys = clip.keys
	if t >= clip.length then
		return keys[#keys][2]
	end
	for i = 1, #keys - 1 do
		local t0, t1 = keys[i][1], keys[i + 1][1]
		if t >= t0 and t <= t1 then
			local u = ease((t - t0) / (t1 - t0))
			local a, b = keys[i][2] :: Pose, keys[i + 1][2] :: Pose
			local out: Pose = {}
			for _, joint in JOINTS do
				local ja, jb = a[joint], b[joint]
				if ja or jb then
					local v = table.create(6, 0)
					for k = 1, 6 do
						local x, y = if ja then ja[k] or 0 else 0, if jb then jb[k] or 0 else 0
						v[k] = x + (y - x) * u
					end
					out[joint] = v
				end
			end
			return out
		end
	end
	return {}
end

local function idle(t: number): Pose
	return {
		body = { 0, 0, 0, 0, 0.03 * math.sin(t * TAU / 3.2), 0 },
		head = { 2 * math.sin(t * TAU / 3.2 + 0.8), 5 * math.sin(t * TAU / 5.6), 0 },
		tail = { 0, 12 * math.sin(t * TAU / 1.9), 0 },
	}
end

-- A trot: diagonal legs swing together, the body bobs twice a stride, head and tail follow.
local function walk(t: number, rate: number): Pose
	local phase = t * rate * TAU
	local a, b = 27 * math.sin(phase), 27 * math.sin(phase + math.pi)
	return {
		leg_fl = { a },
		leg_br = { a },
		leg_fr = { b },
		leg_bl = { b },
		body = { 1.5 * math.sin(2 * phase), 0, 2 * math.sin(phase), 0, 0.07 * math.abs(math.sin(phase)), 0 },
		head = { 3 * math.sin(2 * phase + 0.6), 3 * math.sin(phase), 0 },
		tail = { 0, 16 * math.sin(phase), 0 },
	}
end

-- Magic attack effects ---------------------------------------------------------------------------

local function fxPart(size: Vector3, cframe: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cframe, colour, material
	p.Parent = Workspace
	return p
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

-- The horn gathers light while the creature rears up.
local function charge(model: Model, colour: Color3, seconds: number)
	local asset = model:GetAttribute("Asset")
	local head = (model:FindFirstChild(`{asset}_head_glow`) or model:FindFirstChild(`{asset}_head`)) :: BasePart?
	if head == nil then
		return
	end
	local tip = CFrame.new(0, 0.46 * head.Size.Y, -0.22 * head.Size.Z) -- the top front of the head: the horn's tip
	local s = ((model:GetAttribute("Scale") :: number?) or 1)
	local orb = fxPart(Vector3.one * 0.2 * s, head.CFrame, colour, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = colour, 4, 0.5, false
	light.Parent = orb
	tween(orb, seconds, { Size = Vector3.one * 1.1 * s, Transparency = 0.25 }, Enum.EasingStyle.Sine)
	tween(light, seconds, { Range = 10 * s, Brightness = 3 }, Enum.EasingStyle.Sine)
	local started = os.clock()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or head.Parent == nil then
			follow:Disconnect()
			orb:Destroy()
			return
		end
		orb.CFrame = head.CFrame * tip
	end)
end

-- A sharp four-sided spike standing on `stem` (the middle of its base): four corner wedges with
-- their tall corners together, welded to the stem so moving the stem moves the spike.
local function pyramid(stem: Part, width: number, height: number, colour: Color3, material: Enum.Material)
	for k = 0, 3 do
		local w = Instance.new("CornerWedgePart")
		w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow, w.Massless = false, false, false, false, true
		w.Size, w.Color, w.Material = Vector3.new(width / 2, height, width / 2), colour, material
		-- a corner wedge's tall corner is at +x, -z
		w.CFrame = stem.CFrame * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(-width / 4, height / 2, width / 4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = stem, w
		weld.Parent = w
		w.Parent = stem
	end
end

-- The slam: a ring of light on the ground, then spikes burst up in a line ahead of the creature.
local function impact(model: Model, colour: Color3, molten: boolean)
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local s = ((model:GetAttribute("Scale") :: number?) or 1)
	local ground = root.CFrame * CFrame.new(0, 0.1, -1.4 * s) -- where the front feet land
	local ring = fxPart(Vector3.new(0.3, 2, 2), ground * CFrame.Angles(0, 0, math.pi / 2), colour, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	tween(ring, 0.5, { Size = Vector3.new(0.3, 9 * s, 9 * s), Transparency = 1 })
	Debris:AddItem(ring, 0.6)
	local rock = if molten then Color3.fromRGB(40, 34, 38) else Color3.fromRGB(150, 140, 128)
	for i = 1, 6 do
		task.delay(0.055 * i, function()
			local height = (1.3 + 0.3 * i) * s
			local width = (0.5 + 0.07 * i) * s
			local lean = CFrame.Angles(
				math.rad(math.random(-14, 14)),
				math.rad(math.random(0, 360)),
				math.rad(math.random(-14, 14))
			)
			local base = ground * CFrame.new(math.random(-10, 10) / 10 * s, 0, -(1.6 + 1.3 * i) * s) -- from past the nose on
			local low, high =
				base * CFrame.new(0, -height * 1.15, 0) * lean, base * CFrame.new(0, -height * 0.12, 0) * lean
			-- a rock spike with a thinner, taller glowing core: only its tip shows
			local spike = fxPart(Vector3.one * 0.2, low, rock, Enum.Material.Slate)
			spike.Transparency = 1
			pyramid(spike, width, height, rock, Enum.Material.Slate)
			pyramid(spike, width * 0.5, height * 1.12, colour, Enum.Material.Neon)
			tween(spike, 0.16, { CFrame = high }, Enum.EasingStyle.Back)
			task.delay(0.75, function()
				tween(spike, 0.35, { CFrame = low })
			end)
			Debris:AddItem(spike, 1.15)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Shadows = colour, 5 * s, 2, false
			light.Parent = spike
			local burst = Instance.new("ParticleEmitter")
			burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			burst.Color = ColorSequence.new(colour)
			burst.LightEmission = if molten then 1 else 0.4
			burst.Size =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * s), NumberSequenceKeypoint.new(1, 0) })
			burst.Lifetime = NumberRange.new(0.4, 0.9)
			burst.Speed = NumberRange.new(4 * s, 8 * s)
			burst.SpreadAngle = Vector2.new(50, 50)
			burst.Acceleration = Vector3.new(0, -24, 0)
			burst.Rate = 0
			burst.Parent = spike
			task.delay(0.14, burst.Emit, burst, 14) -- once the spike is out of the ground
		end)
	end
end

local function magicColour(model: Model): (Color3, boolean)
	for _, d in model:GetChildren() do -- a glowing variant casts in its own colour
		if d:IsA("MeshPart") and d.Material == Enum.Material.Neon then
			return d.Color, true
		end
	end
	return Color3.fromRGB(255, 226, 150), false
end

-- Rigs ---------------------------------------------------------------------------------------------

type Rig = {
	model: Model,
	joints: { [string]: Motor6D },
	now: { [string]: { number } }, -- the pose on screen, eased towards the target each frame
	magicAt: number, -- the AnimAt of the magic attack whose effects have started
	impactAt: number, -- and of the one whose slam has played
}

local rigs: { [Model]: Rig } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	local now = {}
	for _, joint in JOINTS do
		now[joint] = table.create(6, 0)
	end
	rigs[model] = { model = model, joints = joints, now = now, magicAt = 0, impactAt = 0 }
	model.DescendantAdded:Connect(function(d) -- pieces can arrive after the model
		if d:IsA("Motor6D") and rigs[model] then
			rigs[model].joints[d.Name] = d
		end
	end)
end

CollectionService:GetInstanceAddedSignal("Creature"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Creature"):Connect(function(model)
	rigs[model :: Model] = nil
end)
for _, model in CollectionService:GetTagged("Creature") do
	add(model)
end

-- Motor6D.Transform is applied in the simulation step, so set it just before.
RunService.PreSimulation:Connect(function(dt: number)
	local time = Workspace:GetServerTimeNow()
	for model, rig in rigs do
		local anim = model:GetAttribute("Anim") :: string?
		local at = (model:GetAttribute("AnimAt") :: number?) or time
		local t = math.max(0, time - at)
		local target: Pose
		if anim == "walk" then
			target = walk(time, (model:GetAttribute("Stride") :: number?) or 1.5)
		elseif anim == "attack" and t < ATTACK.length then
			target = sample(ATTACK, t)
		elseif anim == "magic" and t < MAGIC.length then
			target = sample(MAGIC, t)
			if rig.magicAt ~= at then
				rig.magicAt = at
				charge(model, (magicColour(model)), math.max(0.1, MAGIC_IMPACT - t))
			end
			if t >= MAGIC_IMPACT and rig.impactAt ~= at then
				rig.impactAt = at
				impact(model, magicColour(model))
			end
		else
			target = idle(time)
		end
		local scale = ((model:GetAttribute("Scale") :: number?) or 1)
		local blend = math.min(1, dt * 22)
		for _, joint in JOINTS do
			local goal, v = target[joint], rig.now[joint]
			for k = 1, 6 do
				v[k] += ((if goal then goal[k] or 0 else 0) - v[k]) * blend
			end
			local motor = rig.joints[joint]
			if motor then
				motor.Transform = CFrame.new(v[4] * scale, v[5] * scale, v[6] * scale)
					* CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
			end
		end
	end
end)
