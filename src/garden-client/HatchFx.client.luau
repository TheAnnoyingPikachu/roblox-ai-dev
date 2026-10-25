--!strict
-- Egg Garden world effects (GDD D3, I2, I4; docs/architecture/garden.md sections 5 and 6): the hatch
-- reveal (wobble 1.5 s or 0.4 s with Fast Hatch, crack, pop, rarity burst and a card with name,
-- rarity, mutation and size; it only ever shows the creature the server hatched), coin pops, water
-- splashes in the can's colour, like hearts, release run-off, egg growth and ripe glow with a
-- time-left label, and weather looks from GardenStatus with stingers. Display only: sends nothing.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local HatchRules = require(Shared:WaitForChild("HatchRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local fx = ReplicatedStorage:WaitForChild("GardenRemotes"):WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local UI = ClientState.UI
local SFX = ClientState.SFX
local new, corner, stroke, text = ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text

local fxFolder = new("Folder", { Name = "GardenClientFx", Parent = Workspace })

local function plotOf(userId: any): number?
	for n = 1, 6 do
		local owner = ClientState.ownerOf(n)
		if owner and owner.UserId == userId then
			return n
		end
	end
	return nil
end

local function find(userId: any, path: { string }): Instance?
	local n = plotOf(userId)
	local node: Instance? = if n then ClientState.plotModel(n) else nil
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function positionOf(inst: Instance?): Vector3?
	if inst == nil then
		return nil
	elseif inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

-- One-shot particle burst at a point (default sparkle texture).
local function burst(at: Vector3, colour: Color3, count: number, speed: number, size: number?)
	local a = new("Attachment", { WorldPosition = at, Parent = Workspace.Terrain })
	local e = new("ParticleEmitter", {
		Color = ColorSequence.new(colour, UI.WHITE),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size or 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0, 0.4),
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0),
		LightEmission = 0.7,
		Rate = 0,
		Parent = a,
	})
	e:Emit(count)
	task.delay(1.5, a.Destroy, a)
end

-- Floating BillboardGui that rises and fades.
local function float(at: Vector3, build: (BillboardGui) -> (), rise: number?)
	local holder = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		Position = at,
		Parent = fxFolder,
	})
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(160, 50),
		AlwaysOnTop = true,
		MaxDistance = 120,
		Adornee = holder,
		Parent = holder,
	})
	build(bb)
	TweenService
		:Create(holder, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = at + Vector3.new(0, rise or 5, 0) })
		:Play()
	task.delay(0.6, function()
		for _, d in bb:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(1.2, holder.Destroy, holder)
end

-- Reveal card -------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "GardenReveal",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 6,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local card = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.fromOffset(420, 170),
	BackgroundColor3 = UI.CREAM,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	Parent = gui,
}, { corner(24) })
local cardStroke = stroke(UI.PINK, 5)
cardStroke.Parent = card
ClientState.autoScale(card)
local cardRarity =
	text({ Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 26), Text = "", Parent = card })
local cardName =
	text({ Position = UDim2.fromOffset(20, 40), Size = UDim2.new(1, -40, 0, 48), Text = "", Parent = card })
new("UIStroke", { Color = UI.WHITE, Thickness = 3, Parent = cardName })
local cardDetail = text({
	Position = UDim2.fromOffset(20, 94),
	Size = UDim2.new(1, -40, 0, 24),
	Text = "",
	TextColor3 = UI.MUTED,
	Font = Enum.Font.GothamBold,
	Parent = card,
})
local cardRate = text({
	Position = UDim2.fromOffset(20, 124),
	Size = UDim2.new(1, -40, 0, 30),
	Text = "",
	TextColor3 = UI.LEAF,
	Parent = card,
})
local cardToken = 0
card.Activated:Connect(function()
	card.Visible = false
end)

local function showCard(s: string, m: string, z: string)
	local colour = ClientState.rarityColour(s)
	local mu, sz = GardenConfig.mutation(m), GardenConfig.size(z)
	cardStroke.Color = colour
	cardRarity.Text = string.upper(ClientState.rarityName(s))
	cardRarity.TextColor3 = colour
	cardName.Text = ClientState.creatureName(s, m, z)
	cardName.TextColor3 = colour
	cardDetail.Text = `Mutation: {if mu then mu.name else m}  -  Size: {if sz then sz.name else z}`
	cardRate.Text =
		`+{ClientState.short(GardenRules.rate({ id = 0, s = s, m = m, z = z, placed = 0, fav = false }))} coins/s`
	card.Visible = true
	ClientState.pop(cardName)
	cardToken += 1
	local token = cardToken
	task.delay(if ClientState.settings.fastHatch then 2.5 else 4, function()
		if token == cardToken then
			card.Visible = false
		end
	end)
end

-- Eggs: growth, ripe glow and wobble, time left -----------------------------------------------------

type EggView = { base: CFrame, size: Vector3, label: TextLabel, light: PointLight, sparkle: ParticleEmitter }
local eggs: { [BasePart]: EggView } = {}
local lastEgg: { [Instance]: string } = {} -- bed model -> egg id, kept for the reveal after the egg part is gone

local function eggView(part: BasePart): EggView
	local view = eggs[part]
	if view then
		return view
	end
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(110, 34),
		StudsOffset = Vector3.new(0, 3.2, 0),
		MaxDistance = 70,
		Adornee = part,
		Parent = part,
	})
	local label = text({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = UI.CREAM,
		Text = "",
		Parent = bb,
	})
	corner(12).Parent = label
	stroke(UI.WHITE, 2).Parent = label
	local light =
		new("PointLight", { Color = Color3.fromRGB(255, 230, 160), Range = 10, Brightness = 0, Parent = part })
	local sparkle = new("ParticleEmitter", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 140, 255)),
		}),
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		LightEmission = 0.8,
		Parent = part,
	})
	view = { base = part.CFrame, size = part.Size, label = label, light = light, sparkle = sparkle }
	eggs[part] = view
	part.Destroying:Once(function()
		eggs[part] = nil
	end)
	return view
end

local function eachEgg(callback: (bed: Instance, part: BasePart, egg: string) -> ())
	local root = Workspace:FindFirstChild("Garden")
	local plots = root and root:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local beds = plot:FindFirstChild("Beds")
		for _, bed in if beds then beds:GetChildren() else {} do
			local egg = bed:GetAttribute("Egg")
			local part = bed:FindFirstChild("Egg")
			if type(egg) == "string" and egg ~= "" then
				lastEgg[bed] = egg
				if part and part:IsA("BasePart") then
					callback(bed, part, egg)
				end
			end
		end
	end
end

local shower = false
RunService.RenderStepped:Connect(function()
	local now = ClientState.now()
	local t = os.clock()
	eachEgg(function(bed, part, _egg)
		local view = eggView(part)
		local planted = tonumber(bed:GetAttribute("Planted")) or now
		local ready = tonumber(bed:GetAttribute("Ready")) or now
		local f = if now < planted
			then 0
			elseif ready <= planted then 1
			else math.clamp((now - planted) / (ready - planted), 0, 1)
		local ripe = now >= ready
		local scale = 0.4 + 0.6 * f
		local size = view.size * scale
		local wobble = if ripe then CFrame.Angles(0, 0, math.sin(t * 6 + view.base.X) * 0.12) else CFrame.identity
		part.Size = size
		part.CFrame = view.base * CFrame.new(0, -(view.size.Y - size.Y) / 2, 0) * wobble
		view.light.Brightness = if ripe then 1.2 + math.sin(t * 3) * 0.4 else 0
		view.sparkle.Rate = if ripe and shower then 6 else 0
	end)
end)

-- Time-left labels at 2 Hz.
task.spawn(function()
	while true do
		local now = ClientState.now()
		eachEgg(function(bed, part, _egg)
			local view = eggView(part)
			local ready = tonumber(bed:GetAttribute("Ready")) or now
			if now >= ready then
				view.label.Text = "READY!"
				view.label.TextColor3 = UI.LEAF
			else
				view.label.Text = ClientState.clock(ready - now)
				view.label.TextColor3 = UI.INK
			end
		end)
		task.wait(0.5)
	end
end)

-- Hatch reveal ---------------------------------------------------------------------------------------

local function shellPart(colour: Color3, size: Vector3, cf: CFrame): Part
	return new("Part", {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.SmoothPlastic,
		Color = colour,
		Size = size,
		CFrame = cf,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = fxFolder,
	})
end

local function reveal(data: any)
	local id = tonumber(data.id)
	local s, m, z = tostring(data.s), tostring(data.m), tostring(data.z)
	if id == nil or GardenConfig.species(s) == nil then
		return
	end
	local mine = data.owner == player.UserId
	ClientState.reveal(id, true)
	local bed = find(data.owner, { "Beds", `Bed{tonumber(data.bed) or 0}` })
	local soil = bed and bed:FindFirstChild("Soil")
	local at = positionOf(soil)
	if at == nil then
		ClientState.reveal(id, false)
		if mine then
			showCard(s, m, z)
		end
		return
	end
	local egg = if bed then lastEgg[bed] or "meadow" else "meadow"
	local colours = ClientState.EGG_COLOURS[egg] or ClientState.EGG_COLOURS.meadow
	local centre = at + Vector3.new(0, 2.2, 0)
	local shell = shellPart(colours[1], Vector3.new(2.2, 3, 2.2), CFrame.new(centre))
	new("Highlight", {
		FillTransparency = 1,
		OutlineColor = colours[2],
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = shell,
	})
	new("PointLight", { Color = colours[2], Range = 12, Brightness = 1, Parent = shell })

	-- Wobble, growing stronger; one soft whoosh per swing. Same wobble for every outcome.
	local duration = if ClientState.settings.fastHatch then 0.4 else 1.5
	local start = os.clock()
	local swings = 0
	while os.clock() - start < duration do
		local k = (os.clock() - start) / duration
		shell.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.sin(k * math.pi * 8) * (0.08 + 0.25 * k))
		local swing = math.floor(k * 4)
		if mine and swing > swings then
			swings = swing
			ClientState.sound(SFX.whoosh, 0.12, centre, 1.6 + 0.1 * swing)
		end
		RunService.RenderStepped:Wait()
	end

	-- Crack: the shell splits in two and the halves fly apart.
	shell:Destroy()
	local rarity = GardenConfig.rarityIndex(s)
	local colour = ClientState.rarityColour(s)
	for side = -1, 1, 2 do
		local half =
			shellPart(if side < 0 then colours[1] else colours[2], Vector3.new(2.2, 1.6, 2.2), CFrame.new(centre))
		TweenService:Create(half, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(centre + Vector3.new(side * 2.5, if side < 0 then 1.5 else 0.6, 0))
				* CFrame.Angles(0, 0, side * 1.2),
			Transparency = 1,
		}):Play()
		task.delay(0.55, half.Destroy, half)
	end
	ClientState.sound(SFX.puff, if mine then 0.5 else 0.2, centre, 1.3)
	burst(centre, colour, 20 + rarity * 12, 8 + rarity * 2, 0.6 + rarity * 0.1)
	if rarity >= 5 then
		burst(centre + Vector3.new(0, 2, 0), UI.GOLD, 60, 16, 1.2)
	end
	if mine then
		-- Soft chimes rising with rarity; a resonant one for Legendary and Mythic.
		ClientState.sound(if rarity >= 5 then SFX.fanfare else SFX.chime, 0.35, nil, 1 + 0.12 * rarity)
		showCard(s, m, z)
	end
	ClientState.reveal(id, false)
end

-- Coins, water, likes, release --------------------------------------------------------------------

local function coinPop(data: any)
	local pad = find(data.owner, { "Pads", `Pad{tonumber(data.pad) or 0}` })
	local at = positionOf(pad)
	local amount = tonumber(data.amount) or 0
	if at == nil or amount <= 0 then
		return
	end
	local mine = data.owner == player.UserId
	float(at + Vector3.new(0, 2.5, 0), function(bb)
		local t = text({
			Size = UDim2.fromScale(1, 1),
			Text = `+{ClientState.short(amount)}`,
			TextColor3 = UI.GOLD,
			Parent = bb,
		})
		new("UIStroke", { Color = Color3.fromRGB(150, 90, 10), Thickness = 2.5, Parent = t })
	end)
	burst(at + Vector3.new(0, 1, 0), UI.GOLD, if mine then 14 else 6, 6, 0.5)
	if mine then
		ClientState.sound(SFX.tick, 0.25, nil, 1.7 + math.random() * 0.25)
	end
end

local function canColour(userId: any): Color3
	local by = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local p = ClientState.profileOf(by)
	for _, c in GardenConfig.COSMETICS do
		if p and c.slot == "can" and c.id == p.can and c.colours[1] then
			return ClientState.colour(c.colours[1])
		end
	end
	return Color3.fromRGB(120, 200, 255)
end

local function splash(data: any)
	local soil = find(data.owner, { "Beds", `Bed{tonumber(data.bed) or 0}`, "Soil" })
	local at = positionOf(soil)
	if at == nil then
		return
	end
	local colour = canColour(data.by)
	burst(at + Vector3.new(0, 4, 0), colour, 40, 6, 0.4)
	float(at + Vector3.new(0, 3, 0), function(bb)
		local t = text({ Size = UDim2.fromScale(1, 1), Text = "Watered!", TextColor3 = colour, Parent = bb })
		new("UIStroke", { Color = UI.WHITE, Thickness = 2.5, Parent = t })
	end, 3)
	ClientState.sound(SFX.puff, 0.3, at, 0.7)
end

-- A heart drawn from two circles and a turned square (no emoji or image assets).
local function heart(bb: BillboardGui)
	bb.Size = UDim2.fromOffset(60, 60)
	local pink = UI.PINK
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = pink,
		BorderSizePixel = 0,
		Parent = holder,
	})
	for _, x in { 0.33, 0.67 } do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.38),
			Size = UDim2.fromScale(0.42, 0.42),
			BackgroundColor3 = pink,
			BorderSizePixel = 0,
			Parent = holder,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
end

local function hearts(data: any)
	local n = plotOf(data.owner)
	if not n then
		return
	end
	local sign = find(data.owner, { "Sign" })
	local at = positionOf(sign) or ClientState.plotFrame(n):PointToWorldSpace(Vector3.new(0, 4, -30))
	for i = 1, 5 do
		task.delay(i * 0.12, function()
			float(at + Vector3.new(math.random(-30, 30) / 10, 3, math.random(-10, 10) / 10), heart, 6)
		end)
	end
	if data.owner == player.UserId or data.by == player.UserId then
		ClientState.sound(SFX.chime, 0.25, nil, 2)
	end
end

-- Released creatures hop off through the Wild Meadow gate (a local copy; the server removes the real one).
local function runOff(data: any)
	local model = find(data.owner, { "Creatures", tostring(data.id) })
	if not (model and (model:IsA("BasePart") or model:IsA("Model"))) then
		return
	end
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	if not ok or copy == nil then
		return
	end
	local start = (model :: any):GetPivot() :: CFrame
	local goal = ClientState.MEADOW_GATE + Vector3.new(0, start.Position.Y, 0)
	copy.Parent = fxFolder
	local distance = (goal - start.Position).Magnitude
	local duration = math.clamp(distance / 22, 2, 7)
	local begin = os.clock()
	ClientState.sound(SFX.whoosh, 0.25, start.Position, 0.9)
	while os.clock() - begin < duration and copy.Parent do
		local k = (os.clock() - begin) / duration
		local pos = start.Position:Lerp(goal, k) + Vector3.new(0, math.abs(math.sin(k * duration * 6)) * 1.5, 0)
		copy:PivotTo(CFrame.lookAt(pos, Vector3.new(goal.X, pos.Y, goal.Z)))
		RunService.Heartbeat:Wait()
	end
	burst(goal + Vector3.new(0, 2, 0), UI.MINT, 24, 6)
	copy:Destroy()
end

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "hatch" then
		task.spawn(reveal, data)
	elseif kind == "collect" then
		coinPop(data)
	elseif kind == "water" then
		splash(data)
	elseif kind == "like" then
		hearts(data)
	elseif kind == "release" then
		task.spawn(runOff, data)
	end
end)

-- Weather looks (GDD I4) -----------------------------------------------------------------------------

local function effect(className: string): any
	local e = Lighting:FindFirstChildOfClass(className)
	if not e then
		e = new(className, { Parent = Lighting })
	end
	return e
end
local tint = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
local rays = effect("SunRaysEffect") :: SunRaysEffect
local clock = new("NumberValue", { Value = Lighting.ClockTime })
clock.Changed:Connect(function(v: number)
	Lighting.ClockTime = v % 24
end)

local LOOKS = {
	clear = {
		clock = 14.5,
		ambient = Color3.fromRGB(140, 140, 150),
		tint = Color3.new(1, 1, 1),
		rays = 0.06,
		clouds = 0.55,
	},
	sunbeam = {
		clock = 14.5,
		ambient = Color3.fromRGB(150, 145, 140),
		tint = Color3.fromRGB(255, 236, 200),
		rays = 0.25,
		clouds = 0.4,
	},
	moonfall = {
		clock = 0.5,
		ambient = Color3.fromRGB(80, 90, 150),
		tint = Color3.fromRGB(220, 225, 255),
		rays = 0.02,
		clouds = 0.5,
	},
	shower = {
		clock = 14.5,
		ambient = Color3.fromRGB(135, 140, 155),
		tint = Color3.fromRGB(245, 245, 255),
		rays = 0.05,
		clouds = 0.8,
	},
}

-- A sky emitter above the plaza for weather particles (sparkles, rain, fireflies).
local sky = new("Part", {
	Name = "WeatherSky",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(260, 1, 260),
	Position = Vector3.new(0, 70, 0),
	Parent = fxFolder,
})
local function skyEmitter(props: { [string]: any }): ParticleEmitter
	props.Rate = 0
	props.Enabled = true
	props.Parent = sky
	return new("ParticleEmitter", props)
end
local goldDust = skyEmitter({
	Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)),
	Size = NumberSequence.new(0.5, 0),
	Lifetime = NumberRange.new(6, 9),
	Speed = NumberRange.new(4, 7),
	EmissionDirection = Enum.NormalId.Bottom,
	LightEmission = 1,
})
local rain = skyEmitter({
	Color = ColorSequence.new(Color3.fromRGB(200, 220, 255)),
	Size = NumberSequence.new(0.15),
	Squash = NumberSequence.new(4),
	Transparency = NumberSequence.new(0.35),
	Lifetime = NumberRange.new(1.4, 1.8),
	Speed = NumberRange.new(45, 55),
	EmissionDirection = Enum.NormalId.Bottom,
	Orientation = Enum.ParticleOrientation.VelocityParallel,
})
local ground = new("Part", {
	Name = "WeatherGround",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(240, 1, 240),
	Position = Vector3.new(0, 3, 0),
	Parent = fxFolder,
})
local fireflies = new("ParticleEmitter", {
	Color = ColorSequence.new(Color3.fromRGB(230, 255, 140)),
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	}),
	Lifetime = NumberRange.new(3, 5),
	Speed = NumberRange.new(0.5, 1.5),
	SpreadAngle = Vector2.new(180, 180),
	LightEmission = 1,
	Rate = 0,
	Parent = ground,
})

-- Rainbow arc about 300 studs across the northern sky (7-colour Beam, width 40).
local arcA = new("Attachment", { WorldPosition = Vector3.new(-150, 0, -260), Parent = Workspace.Terrain })
local arcB = new("Attachment", { WorldPosition = Vector3.new(150, 0, -260), Parent = Workspace.Terrain })
arcA.WorldCFrame = CFrame.new(arcA.WorldPosition) * CFrame.Angles(0, 0, math.rad(90))
arcB.WorldCFrame = CFrame.new(arcB.WorldPosition) * CFrame.Angles(0, 0, math.rad(90))
local rainbowColours = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(255, 235, 80),
	Color3.fromRGB(90, 220, 110),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(110, 90, 230),
	Color3.fromRGB(190, 110, 230),
}
local stops = {}
for i, c in rainbowColours do
	table.insert(stops, ColorSequenceKeypoint.new((i - 1) / 6, c))
end
local rainbow = new("Beam", {
	Attachment0 = arcA,
	Attachment1 = arcB,
	Color = ColorSequence.new(stops),
	Width0 = 40,
	Width1 = 40,
	CurveSize0 = 220,
	CurveSize1 = -220,
	Segments = 60,
	LightEmission = 0.5,
	Transparency = NumberSequence.new(1),
	FaceCamera = true,
	Parent = Workspace.Terrain,
})

-- Lamp-post and hanging-egg lights (World.luau lights them as PointLights under parts named *Lamp*
-- or *HangingEgg*; shortcut: matched by name, switch to a tag if World names them differently).
local function nightLights(): { PointLight }
	local found = {}
	local root = Workspace:FindFirstChild("Garden")
	for _, d in if root then root:GetDescendants() else {} do
		if d:IsA("PointLight") and d.Parent and (d.Parent.Name:find("Lamp") or d.Parent.Name:find("HangingEgg")) then
			table.insert(found, d)
		end
	end
	return found
end
local lampBase: { [PointLight]: number } = {}

local currentWeather: string? = nil
local function applyWeather()
	local w = ClientState.status().weather
	if w == currentWeather then
		return
	end
	local first = currentWeather == nil
	currentWeather = w
	shower = w == "shower"
	local look = (LOOKS :: any)[w] or LOOKS.clear
	local info = TweenInfo.new(if first then 0 else 4, Enum.EasingStyle.Sine)
	-- Always run the clock forwards (through sunset into Moonfall, through dawn out of it).
	local from = clock.Value % 24
	clock.Value = from
	TweenService:Create(clock, info, { Value = from + (look.clock - from) % 24 }):Play()
	TweenService:Create(Lighting, info, { OutdoorAmbient = look.ambient }):Play()
	TweenService:Create(tint, info, { TintColor = look.tint }):Play()
	TweenService:Create(rays, info, { Intensity = look.rays }):Play()
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		TweenService:Create(clouds, info, { Cover = look.clouds }):Play()
	end
	goldDust.Rate = if w == "sunbeam" then 30 else 0
	rain.Rate = if w == "shower" then 400 else 0
	fireflies.Rate = if w == "moonfall" then 25 else 0
	rainbow.Transparency = NumberSequence.new(if w == "shower" then 0.35 else 1)
	for _, l in nightLights() do
		lampBase[l] = lampBase[l] or l.Brightness
		l.Enabled = true
		TweenService:Create(l, info, { Brightness = if w == "moonfall" then math.max(lampBase[l], 2) else 0 }):Play()
	end
	if not first and w ~= "clear" then
		local weather = nil
		for _, entry in GardenConfig.WEATHERS do
			if entry.id == w then
				weather = entry
			end
		end
		-- Stinger and an honest note of what changed (the published table, nothing more).
		ClientState.sound(SFX.fanfare, 0.3, nil, if w == "moonfall" then 0.8 elseif w == "shower" then 1.4 else 1.15)
		if weather then
			local best, bestBp = "", 0
			for _, o in weather.mutation do
				if o.id ~= "normal" and o.bp > bestBp then
					best, bestBp = o.id, o.bp
				end
			end
			local mu = GardenConfig.mutation(best)
			ClientState.toast(
				`{weather.name}! {if mu then mu.name else best} chance is {HatchRules.percent(bestBp)}% for 5 minutes`,
				ClientState.WEATHER_COLOURS[w]
			)
		end
	end
end
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(applyWeather)
applyWeather()
