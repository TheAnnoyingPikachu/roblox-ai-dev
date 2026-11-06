--!strict
-- Lantern Express train and world feel (GDD L, art bible 3 and 9; architecture lantern 6): lighting
-- by phase (dusk, the ride into night, night, dawn), the seated camera sway, chimney smoke that
-- follows the speed, the whistle and bell, the fog wall at stops from BellAt (the same front formula
-- as TrainRules.fogFront), the fog sprint vignette, the caught overlay, and the client half of the
-- seated rule (no jumping while seated on a moving train). The fog drawn here never decides a catch.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local TrainRules = require(Shared:WaitForChild("TrainRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))

local UI = ClientState.UI
local new = UiKit.new
local player = Players.LocalPlayer
local STOP = LanternConfig.STOP

-- Lighting (art bible 3) ------------------------------------------------------------------------------------

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
type Look = { [string]: any }
local DUSK: Look = {
	ClockTime = 18.4,
	Brightness = 1.6,
	Ambient = rgb(44, 38, 74),
	OutdoorAmbient = rgb(110, 100, 150),
	ColorShift_Top = rgb(255, 190, 150),
	density = 0.42,
	fog = UI.FOG,
	decay = rgb(96, 84, 150),
	stars = 0,
}
local NIGHT: Look = {
	ClockTime = 24.5, -- 0.5, kept above 18.4 so the blend runs forward through the evening
	Brightness = 0.6,
	Ambient = rgb(34, 30, 64),
	OutdoorAmbient = rgb(64, 60, 110),
	ColorShift_Top = rgb(150, 150, 255),
	density = 0.5,
	fog = rgb(120, 112, 170),
	decay = rgb(40, 36, 80),
	stars = 1500,
}
local DAWN: Look = {
	ClockTime = 30.2, -- 6.2 the next morning
	Brightness = 2,
	Ambient = rgb(60, 52, 80),
	OutdoorAmbient = rgb(150, 130, 150),
	ColorShift_Top = rgb(255, 210, 170),
	density = 0.38,
	fog = rgb(230, 200, 200),
	decay = rgb(150, 120, 140),
	stars = 0,
}

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or new("Atmosphere", { Parent = Lighting })
atmosphere.Offset, atmosphere.Glare, atmosphere.Haze = 0.25, 0.3, 1.8
local sky = Lighting:FindFirstChildOfClass("Sky") or new("Sky", { Parent = Lighting })
sky.MoonAngularSize = 14
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or new("BloomEffect", { Parent = Lighting })
bloom.Size, bloom.Threshold = 24, 0.92
local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	or new("ColorCorrectionEffect", { Parent = Lighting })
grade.Saturation, grade.Contrast, grade.TintColor = 0.08, 0.05, rgb(255, 246, 240)
Lighting.GlobalShadows, Lighting.ShadowSoftness = true, 0.4
Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.5, 0.4

local function blend(a: Look, b: Look, t: number): Look
	local out: Look = {}
	for k, v in a do
		out[k] = if typeof(v) == "Color3" then v:Lerp(b[k], t) else v + (b[k] - v) * t
	end
	return out
end

local function lookFor(r: ClientState.Run): Look
	local t = LanternConfig.TRACKS[ClientState.trackName(r)]
	local d = r.D or 0
	if r.Phase == "night" then
		local night = blend(DUSK, NIGHT, math.clamp((d - t.nightFrom) / 700, 0, 1)) -- the ride into night
		if (r.Leg or 1) >= 3 then
			return blend(night, DAWN, math.clamp((d - (t.finish - 400)) / 400, 0, 1)) -- the spur to Dawn
		end
		return night
	elseif r.Phase == "ended" and (r.Leg or 1) >= 3 and d >= t.finish - 1 then
		return DAWN
	end
	return DUSK
end

local current: Look = lookFor(ClientState.run())
local function applyLight(dt: number)
	local goal = lookFor(ClientState.run())
	current = blend(current, goal, if ClientState.still() then 1 else math.min(1, dt * 0.8))
	Lighting.ClockTime = current.ClockTime % 24
	Lighting.Brightness = current.Brightness
	Lighting.Ambient = current.Ambient
	Lighting.OutdoorAmbient = current.OutdoorAmbient
	Lighting.ColorShift_Top = current.ColorShift_Top
	atmosphere.Density = current.density
	atmosphere.Color = current.fog
	atmosphere.Decay = current.decay
	sky.StarCount = math.floor(current.stars)
	bloom.Intensity = if ClientState.settings.calm then 0.3 else 0.6 -- Calm night halves Bloom
end

-- The fog wall at a stop (art bible 3): a soft lilac bank 20 tall, glowing, with a bright edge ----------

local wall: Model? = nil
local wallFrame: CFrame? = nil
local wisps: { PVInstance } = {}

local function slab(model: Model, name: string, size: Vector3, transparency: number): Part
	local p = new("Part", {
		Name = name,
		Size = size,
		Color = UI.FOG,
		Material = Enum.Material.SmoothPlastic,
		Transparency = transparency,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})
	return p
end

local function emitter(parent: Instance, texture: string, colour: Color3, size: number, rate: number, emission: number)
	return new("ParticleEmitter", {
		Texture = texture,
		Color = ColorSequence.new(colour),
		LightEmission = emission,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(30, 30),
		Rate = rate,
		Shape = Enum.ParticleEmitterShape.Box,
		Parent = parent,
	})
end

local function buildWall(frame: CFrame)
	local model = new("Model", { Name = "LanternFogWall" })
	local width = STOP.width + 8
	-- three soft layers, each thinner towards the top so the bank has no hard edge; faint, so the
	-- smoke reads as mist and not as a lit screen (Studio integration)
	for i, t in { 0.78, 0.86, 0.94 } do
		local p = slab(model, `Bank{i}`, Vector3.new(width, 22 - (i - 1) * 6, 6), t)
		p:SetAttribute("Back", (i - 1) * 5)
	end
	local fill = slab(model, "Behind", Vector3.new(width, 24, 1), 0.8)
	fill:SetAttribute("Fill", true)
	local edge = slab(model, "Edge", Vector3.new(width, 22, 1), 1) -- carries the sparkles only
	edge:SetAttribute("Back", -2)
	emitter(model:FindFirstChild("Bank1") :: Part, "rbxasset://textures/particles/smoke_main.dds", UI.FOG, 22, 70, 0.3)
	emitter(
		model:FindFirstChild("Bank2") :: Part,
		"rbxasset://textures/particles/smoke_main.dds",
		UI.CREAM,
		16,
		30,
		0.3
	)
	emitter(edge, "rbxasset://textures/particles/sparkles_main.dds", UI.RING, 0.8, 12, 1)
	-- wisp silhouettes inside the bank (soft dark puffs with two glowing eyes; art bible 9)
	wisps = {}
	for i = 1, 4 do
		local w: PVInstance? = ClientState.model("shadow_wisp") -- the uploaded wisp, eyes and all
		if w then
			for _, p in w:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
				end
			end
			w.Parent = model
		else
			local ball =
				ClientState.ball(model, "shadow_wisp", Vector3.new(2.5, 2.5, 2.5), rgb(40, 34, 90), Vector3.zero)
			ball.Transparency = 0.25
			w = ball
		end
		(w :: PVInstance):SetAttribute("Slot", i)
		table.insert(wisps, w :: PVInstance)
	end
	model.Parent = Workspace
	wall, wallFrame = model, frame
end

local function placeWall(front: number, t: number)
	local model, frame = wall :: Model, wallFrame :: CFrame
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Back") ~= nil then
			p.CFrame = frame * CFrame.new(0, p.Size.Y / 2, front + (p:GetAttribute("Back") :: number))
		elseif p:IsA("BasePart") and p:GetAttribute("Fill") then
			local depth = math.max(1, STOP.depth - front + 10)
			p.Size = Vector3.new(p.Size.X, 24, depth)
			p.CFrame = frame * CFrame.new(0, 12, front + depth / 2)
		end
	end
	local bob = if ClientState.still() then 0 else math.sin(t * 1.3)
	for _, w in wisps do
		local i = w:GetAttribute("Slot") :: number
		w:PivotTo(frame * CFrame.new(-45 + i * 22, 6 + i % 2 * 4 + bob * 0.6, front + 6 + i * 3))
	end
end

local function dropWall()
	if wall then
		wall:Destroy()
	end
	wall, wallFrame, wisps = nil, nil, {}
end

-- Fog sprint vignette and the caught overlay ------------------------------------------------------------------

local screen = new("ScreenGui", {
	Name = "LanternFeel",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local edges: { Frame } = {}
for _, e in
	{
		{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), -90 },
		{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0.75, 0), 180 },
	}
do
	local f = new("Frame", {
		Size = e[1],
		Position = e[2],
		BackgroundColor3 = UI.DUSK, -- violet, never black (art bible 9)
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screen,
	}, { new("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(0, 1) }) })
	table.insert(edges, f)
end
local function vignette(k: number)
	local strength = if ClientState.settings.calm then 0.3 else 0.6 -- Calm night halves the vignette
	for _, f in edges do
		f.BackgroundTransparency = 1 - strength * math.clamp(k, 0, 1)
	end
end

local caught = new("Frame", {
	Name = "Caught",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = UI.FOG, -- lilac, not black
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 5,
	Parent = screen,
})
local caughtText = UiKit.text(caught, "The fog carried you back. Back on the train soon...", 30, UI.INK, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(700, 44),
	Outline = UI.CREAM,
	OutlineThickness = 2,
	ZIndex = 6,
})
UiKit.scaleRoot(screen)
local function setCaught(on: boolean)
	caught.Visible = true
	local goal = if on then 0.25 else 1
	if ClientState.still() then
		caught.BackgroundTransparency = goal
	else
		TweenService:Create(caught, TweenInfo.new(0.8), { BackgroundTransparency = goal }):Play()
	end
	caughtText.Visible = on
	if not on then
		task.delay(0.85, function()
			if caught.BackgroundTransparency >= 1 then
				caught.Visible = false
			end
		end)
	end
end

-- Chimney smoke that follows the speed (the engine model or its part fallback, named train_engine) ------

local smoke: ParticleEmitter? = nil
local nextLook = 0
local function chimney(speed: number)
	if smoke == nil or smoke.Parent == nil then
		if os.clock() < nextLook then
			return
		end
		nextLook = os.clock() + 2
		local engine = Workspace:FindFirstChild("train_engine", true)
		if engine == nil then
			return
		end
		local top = if engine:IsA("Model") then engine else nil
		local base: BasePart? = if top
			then top.PrimaryPart or top:FindFirstChildWhichIsA("BasePart", true)
			else engine :: BasePart
		if base == nil then
			return
		end
		local cf, size = (base :: BasePart).CFrame, (base :: BasePart).Size
		if top then
			cf, size = top:GetBoundingBox()
		end
		local a = new("Attachment", { Name = "Chimney", Parent = base })
		a.WorldPosition = (cf * CFrame.new(0, size.Y / 2, -size.Z * 0.3)).Position
		smoke = emitter(a, "rbxasset://textures/particles/smoke_main.dds", rgb(225, 215, 235), 3, 0, 0.1)
		local e = smoke :: ParticleEmitter
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.Speed = NumberRange.new(6, 9)
		e.EmissionDirection = Enum.NormalId.Top
		e.Lifetime = NumberRange.new(1.5, 2.5)
	end
	local e = smoke :: ParticleEmitter
	-- chuff rate follows speed: about one puff per wheel turn
	e.Rate = if speed > 0.5 then 2 + speed * 0.5 else 0.6
end

-- Rescued critters ride in the passenger car's windows until the run ends (GDD K 0:49; the window
-- slots of train_car_passenger: x +-3.8, z +-1.78 and +-5.34, sill 4.68 above the rail).
local WINDOWS =
	{ { 1, -5.34 }, { -1, -5.34 }, { 1, -1.78 }, { -1, -1.78 }, { 1, 1.78 }, { -1, 1.78 }, { 1, 5.34 }, { -1, 5.34 } }
local riders: { Model } = {}
local function ride(species: string)
	local train = Workspace:FindFirstChild("Lantern") and (Workspace :: any).Lantern:FindFirstChild("Train")
	local coach = train and train:FindFirstChild("train_car_passenger")
	local base = coach and coach:FindFirstChild("Base") :: BasePart?
	local slot = WINDOWS[#riders + 1]
	if base == nil or slot == nil then
		return
	end
	local m = ClientState.critterModel(species)
	local _, size = m:GetBoundingBox()
	if size.Y > 2.4 then
		m:ScaleTo(m:GetScale() * 2.4 / size.Y)
	end
	local box, fit = m:GetBoundingBox()
	-- the base's centre is 1.8 above the rail; the critter sits on the sill looking out
	local at = base.CFrame
		* CFrame.new(slot[1] * 3.3, 4.68 - 1.8 + fit.Y / 2, slot[2])
		* CFrame.Angles(0, -slot[1] * math.pi / 2, 0)
	m:PivotTo(at * box:ToObjectSpace(m:GetPivot()))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = base, p
			weld.Parent = p
		end
	end
	m.Parent = Workspace
	table.insert(riders, m)
end
ClientState.RunChanged:Connect(function(name: string)
	if name == "Phase" and ClientState.run().Phase == "hub" then
		for _, m in riders do
			m:Destroy()
		end
		riders = {}
	end
end)

-- Music by phase: the menu track in the start menu, hub, Depot and run end; day on rides and stops;
-- night for nights and the Lampeater. A crossfade at the music setting (Calm night plays it softer).
local tracks: { [string]: Sound } = {}
for name, id in ClientState.MUSIC do
	local s = Instance.new("Sound")
	s.Name = `Music_{name}`
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	tracks[name] = s
end
local function music(dt: number, r: ClientState.Run)
	local calm = ClientState.menuOpen or r.Phase == "hub" or r.Phase == "depot" or r.Phase == "ended"
	local want = if calm then "menu" elseif r.Phase == "night" then "night" else "day"
	local level = 0.5 * ClientState.settings.music * (if ClientState.settings.calm then 0.6 else 1)
	for name, s in tracks do
		local goal = if name == want then level else 0
		if goal > 0 and not s.IsPlaying then
			s:Play()
		end
		s.Volume += (goal - s.Volume) * math.min(1, dt * 1.5)
		if goal == 0 and s.IsPlaying and s.Volume < 0.01 then
			s:Stop()
		end
	end
end

-- Every frame ---------------------------------------------------------------------------------------------------

local bellRung = false
local whooshAt = 0
RunService.RenderStepped:Connect(function(dt: number)
	local r = ClientState.run()
	local now = ClientState.now()
	local t = os.clock()
	applyLight(dt)
	chimney(r.Speed or 0)
	music(dt, r)

	-- the fog wall
	local front: number? = nil
	if r.Phase == "stop" then
		front =
			TrainRules.fogFront({ phase = "stop", bellAt = if (r.BellAt or 0) > 0 then r.BellAt else nil } :: any, now)
		if wall == nil then
			local frame = ClientState.stopFrame()
			if frame then
				buildWall(frame)
			end
		end
		if wall then
			placeWall(front or STOP.depth, t)
		end
	elseif wall then
		dropWall()
	end

	-- the fog sprint: the bell, a rising whoosh and the vignette closing on a player near the front
	if front and not bellRung then
		bellRung = true
		ClientState.sound("bell", 0.7)
		ClientState.sound("whistle", 0.6)
	elseif front == nil then
		bellRung = false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local k = 0
	if front and root and wallFrame and humanoid and humanoid.SeatPart == nil then
		local depth = (wallFrame :: CFrame):PointToObjectSpace(root.Position).Z
		k = if depth > 0 then 1 - (front - depth) / 40 else 0
		if k > 0.2 and t > whooshAt then
			whooshAt = t + 3
			ClientState.sound("whoosh", 0.25 + 0.3 * k, nil, 0.8 + 0.4 * k) -- rising as the front nears
		end
	end
	vignette(k)

	-- the seated rule (client half) and the seated camera sway
	if humanoid then
		local moving = (r.Speed or 0) > 0.1
		local seated = humanoid.SeatPart ~= nil
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not (seated and moving))
		local turret = seated and (humanoid.SeatPart :: Seat):GetAttribute("Kind") == "turret"
		if seated and moving and not turret and not ClientState.still() then
			local s = math.min((r.Speed or 0) / 20, 1)
			humanoid.CameraOffset = Vector3.new(math.sin(t * 1.1) * 0.12, math.sin(t * 1.9) * 0.08, 0) * s
		else
			humanoid.CameraOffset = Vector3.zero
		end
	end
end)

ClientState.Fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		data = {}
	end
	if kind == "depart" then
		ClientState.sound("whistle", 0.6)
	elseif kind == "rescue" and type(data.species) == "string" then
		ride(data.species)
	elseif kind == "caught" and tonumber(data.userId) == player.UserId then
		setCaught(true)
		task.delay(STOP.limbo + 2, setCaught, false) -- in case `back` is missed
	elseif kind == "back" and tonumber(data.userId) == player.UserId then
		setCaught(false)
	end
end)
