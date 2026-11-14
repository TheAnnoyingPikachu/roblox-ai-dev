--!strict
-- Animates every creature model (tag "Creature", built by stations/Creatures.luau). The server
-- sets each model's Anim ("idle", "walk", "attack", "magic", "hit", "die") and AnimAt (server time) attributes
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

local JOINTS = { "body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "wing_l", "wing_r" }
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

-- Two-legged Hexbound (the knight, archer, mage and ogre have a "Biped" attribute): their front
-- "legs" are arms hung from the shoulders and their back "legs" are legs, so an arm swings forward
-- and up with a positive pitch, and 180 points it straight up. The cape or cloak is the "tail".

-- A sword or club chop (knight, ogre): the weapon arm goes up overhead, then comes down hard.
local BIPED_ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{
			0.30,
			{
				body = { 6, 0, 0, 0, 0.05, 0.2 },
				leg_fr = { 165 },
				leg_fl = { 25 },
				head = { -8 },
				leg_bl = { -8 },
				leg_br = { 8 },
				tail = { -10 },
			},
		},
		{
			0.46,
			{
				body = { -14, 0, 0, 0, -0.12, -0.9 },
				leg_fr = { 15 },
				leg_fl = { 50 },
				head = { 10 },
				leg_bl = { 16 },
				leg_br = { -12 },
				tail = { 14 },
			},
		},
		{ 0.70, { body = { -5, 0, 0, 0, 0, -0.4 }, leg_fr = { 20 }, leg_fl = { 30 } } },
		{ 0.95, {} },
	},
}

-- A bow shot (archer): both arms out to aim, then the drawing hand snaps back and the body recoils.
local ARCHER_ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{ 0.30, { leg_fl = { 90 }, leg_fr = { 72 }, body = { 0, 0, 0, 0, 0, -0.1 }, head = { -4 }, tail = { -6 } } },
		{ 0.46, { leg_fl = { 92 }, leg_fr = { 22 }, body = { 7, 0, 0, 0, 0.03, 0.4 }, head = { 4 }, tail = { 12 } } },
		{ 0.70, { leg_fl = { 60 }, leg_fr = { 18 }, body = { 2 } } },
		{ 0.95, {} },
	},
}

-- A spell cast (mage): the orb hand rises, the staff thrusts out and the body leans into it.
local MAGE_ATTACK: Clip = {
	length = 0.95,
	keys = {
		{ 0.00, {} },
		{
			0.30,
			{ leg_fl = { 112 }, leg_fr = { 50 }, body = { 8, 0, 0, 0, 0.06, 0.2 }, head = { -12 }, tail = { -8 } },
		},
		{
			0.46,
			{ leg_fl = { 82 }, leg_fr = { 20 }, body = { -8, 0, 0, 0, -0.05, -0.5 }, head = { 8 }, tail = { 14 } },
		},
		{ 0.70, { leg_fl = { 50 }, leg_fr = { 20 }, body = { -3 } } },
		{ 0.95, {} },
	},
}

-- The power attack for all of them: both arms thrown overhead while the power gathers, then a
-- stomp and slam as the ground erupts.
local BIPED_MAGIC: Clip = {
	length = 1.6,
	keys = {
		{ 0.00, {} },
		{
			0.40,
			{
				leg_fl = { 150 },
				leg_fr = { 150 },
				body = { 10, 0, 0, 0, 0.1, 0.15 },
				head = { -18 },
				leg_bl = { -6 },
				leg_br = { 6 },
				tail = { -14 },
			},
		},
		{
			0.78,
			{
				leg_fl = { 172 },
				leg_fr = { 166 },
				body = { 14, 0, 0, 0, 0.14, 0.2 },
				head = { -22 },
				leg_bl = { -8 },
				leg_br = { 8 },
				tail = { -20 },
			},
		},
		{
			MAGIC_IMPACT,
			{
				leg_fl = { 35 },
				leg_fr = { 30 },
				body = { -16, 0, 0, 0, -0.18, -0.7 },
				head = { 14 },
				leg_bl = { 14 },
				leg_br = { -8 },
				tail = { 22 },
			},
		},
		{ 1.12, { body = { -4, 0, 0, 0, 0.02, -0.2 }, head = { 6 } } },
		{ 1.60, {} },
	},
}

-- Struck: the body jerks back and the head snaps up.
local HIT: Clip = {
	length = 0.4,
	keys = {
		{ 0.00, {} },
		{ 0.10, { body = { 9, 0, 0, 0, 0, 0.5 }, head = { -16 }, leg_fl = { 12 }, leg_fr = { 12 }, tail = { 12 } } },
		{ 0.40, {} },
	},
}

-- Defeat: an animal rolls onto its side, a Hexbound biped falls on its back, a dragon slumps.
-- The y of the body is a fraction of its height off the ground (see `rest` on a rig), not studs.
local DIE_QUAD: Clip = {
	length = 1.2,
	keys = {
		{ 0.00, {} },
		{ 0.50, { body = { 8, 0, 40, 0, -0.25, 0 }, head = { 20 } } },
		{
			1.20,
			{
				body = { 0, 0, 86, 0, -0.58, 0 },
				head = { 26 },
				leg_fl = { 30 },
				leg_fr = { 24 },
				leg_bl = { -20 },
				leg_br = { -24 },
				tail = { 14 },
			},
		},
	},
}
local DIE_BIPED: Clip = {
	length = 1.2,
	keys = {
		{ 0.00, {} },
		{ 0.45, { body = { 20, 0, 0, 0, -0.2, 0.3 }, head = { -20 }, leg_fl = { 40 }, leg_fr = { 30 } } },
		{
			1.20,
			{
				body = { 86, 0, 0, 0, -0.7, 0 },
				head = { -30 },
				leg_fl = { 70 },
				leg_fr = { 20 },
				leg_bl = { 12 },
				leg_br = { -10 },
				tail = { 30 },
			},
		},
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

-- A Hexbound biped stands heavier and walks with its arms swinging against its legs.
local function idleBiped(t: number): Pose
	return {
		body = { 0, 0, 0, 0, 0.02 * math.sin(t * TAU / 3.4), 0 },
		head = { 2 * math.sin(t * TAU / 3.4 + 0.8), 4 * math.sin(t * TAU / 6), 0 },
		leg_fl = { 3 * math.sin(t * TAU / 3.4) },
		leg_fr = { -3 * math.sin(t * TAU / 3.4) },
		tail = { 5 * math.sin(t * TAU / 2.6), 0, 0 },
	}
end

local function walkBiped(t: number, rate: number): Pose
	local phase = t * rate * TAU
	local a = 26 * math.sin(phase)
	return {
		leg_bl = { a },
		leg_br = { -a },
		leg_fl = { -a * 0.7 },
		leg_fr = { a * 0.7 },
		body = { -3, 3 * math.sin(phase), 2 * math.sin(phase), 0, 0.09 * math.abs(math.sin(phase)), 0 },
		head = { 2 * math.sin(2 * phase + 0.6), -3 * math.sin(phase), 0 },
		tail = { 10 * math.sin(phase + 1), 0, 0 },
	}
end

-- A dragon's wings (the "wing_l" joint is on its left, so it lifts with a negative roll): a slow
-- beat at rest, a wider one when it moves, a hard one when it attacks, still when it is down.
local function wings(time: number, anim: string?): Pose
	local amp, rate = 10, 0.5
	if anim == "walk" then
		amp, rate = 16, 0.9
	elseif anim == "attack" or anim == "magic" then
		amp, rate = 38, 1.8
	elseif anim == "die" then
		amp = 0
	end
	local f = amp * math.sin(time * rate * TAU) + (if anim == "die" then 28 else 0)
	return { wing_l = { 0, 0, -f }, wing_r = { 0, 0, f } }
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
	rest: number, -- the body's height above the ground, studs; 0 until a fall needs it
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
	rigs[model] = { model = model, joints = joints, now = now, magicAt = 0, impactAt = 0, rest = 0 }
	model.DescendantAdded:Connect(function(d) -- pieces can arrive after the model
		if d:IsA("Motor6D") and rigs[model] then
			rigs[model].joints[d.Name] = d
		end
	end)
end

-- Fights (decision 0042): a creature with a "MaxHp" attribute shows a health bar over it, and every
-- change in its "Hp" floats a number: red for damage, green for healing. The server sets both.
local function floatNumber(model: Model, change: number)
	local hit = model:FindFirstChild("Hit") :: BasePart?
	if hit == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.Adornee = hit
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local x = (math.random() - 0.5) * hit.Size.X * 0.5
	gui.StudsOffset = Vector3.new(x, hit.Size.Y / 2 + 1, 0)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = if change < 0 then tostring(change) else `+{change}`
	text.TextColor3 = if change < 0 then Color3.fromRGB(255, 90, 80) else Color3.fromRGB(110, 255, 140)
	text.TextStrokeTransparency = 0
	text.Parent = gui
	gui.Parent = hit
	TweenService:Create(gui, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(text, TweenInfo.new(1.0), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1.1)
end

local function watchHealth(model: Model)
	local hit = model:FindFirstChild("Hit") :: BasePart?
	local maxHp = model:GetAttribute("MaxHp")
	if hit == nil or type(maxHp) ~= "number" or hit:FindFirstChild("HealthBar") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(110, 12)
	gui.Adornee = hit
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.StudsOffset = Vector3.new(0, hit.Size.Y / 2 + 1.2, 0)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	back.BorderSizePixel = 0
	back.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = if model:GetAttribute("Side") == 2 then Color3.fromRGB(150, 255, 70) else Color3.fromRGB(255, 200, 70)
	edge.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if model:GetAttribute("Side") == 2
		then Color3.fromRGB(220, 70, 70)
		else Color3.fromRGB(90, 210, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = hit
	local last = model:GetAttribute("Hp")
	local function update()
		local hp, full = model:GetAttribute("Hp"), model:GetAttribute("MaxHp")
		if type(hp) ~= "number" or type(full) ~= "number" then
			return
		end
		if type(last) == "number" and hp ~= last then
			floatNumber(model, hp - last)
		end
		last = hp
		TweenService
			:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(hp / math.max(1, full), 0, 1), 1) })
			:Play()
		gui.Enabled = hp > 0
	end
	model:GetAttributeChangedSignal("Hp"):Connect(update)
	update()
end

CollectionService:GetInstanceAddedSignal("Creature"):Connect(add)
CollectionService:GetInstanceAddedSignal("Creature"):Connect(function(model)
	task.defer(function() -- its attributes and parts arrive just after the tag
		for _ = 1, 20 do
			if model:FindFirstChild("Hit") and model:GetAttribute("MaxHp") ~= nil then
				watchHealth(model :: Model)
				return
			end
			task.wait(0.1)
		end
	end)
end)
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
		local biped = model:GetAttribute("Biped") == true
		local target: Pose
		if anim == "die" then -- holds its last pose
			target = sample(if biped then DIE_BIPED else DIE_QUAD, t)
			local body = target.body
			if body then
				if rig.rest == 0 then
					local asset = model:GetAttribute("Asset")
					local mesh = model:FindFirstChild(`{asset}_body`) :: BasePart?
					local root = model.PrimaryPart
					rig.rest = if mesh and root then math.max(1, mesh.Position.Y - root.Position.Y) else 1
				end
				local fall = table.clone(body) -- the clip's y is a share of the body's height
				fall[5] = body[5] * rig.rest / ((model:GetAttribute("Scale") :: number?) or 1)
				target = table.clone(target)
				target.body = fall
			end
		elseif anim == "hit" and t < HIT.length then
			target = sample(HIT, t)
		elseif anim == "walk" then
			local rate = (model:GetAttribute("Stride") :: number?) or 1.5
			target = if biped then walkBiped(time, rate) else walk(time, rate)
		elseif anim == "attack" and t < ATTACK.length then
			local kind = model:GetAttribute("Asset")
			local clip = if not biped
				then ATTACK
				elseif kind == "foe_archer" then ARCHER_ATTACK
				elseif kind == "foe_mage" then MAGE_ATTACK
				else BIPED_ATTACK
			target = sample(clip, t)
		elseif anim == "magic" and t < MAGIC.length then
			target = sample(if biped then BIPED_MAGIC else MAGIC, t)
			if rig.magicAt ~= at then
				rig.magicAt = at
				charge(model, (magicColour(model)), math.max(0.1, MAGIC_IMPACT - t))
			end
			if t >= MAGIC_IMPACT and rig.impactAt ~= at then
				rig.impactAt = at
				impact(model, magicColour(model))
			end
		else
			target = if biped then idleBiped(time) else idle(time)
		end
		if model:GetAttribute("Winged") == true then
			target = table.clone(target)
			for joint, v in wings(time, anim) do
				target[joint] = v
			end
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
