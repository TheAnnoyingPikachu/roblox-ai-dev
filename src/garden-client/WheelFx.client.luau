--!strict
-- Petal Catch on the client (garden-wheel.md W7, architecture garden-wheel.md 5): the player's own
-- petals rendered from the server seed with the same WheelRules.schedule, the basket, the round HUD,
-- the end card, the pre-decided wheel animation with both odds columns, the stand's spins label and
-- the sounds. Sends nothing: every catch and the wedge are the server's (G4: no near-miss, no ticking,
-- no failure sound, no spin-again, no countdown to the next spin).

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local HatchRules = require(Shared:WaitForChild("HatchRules"))
local WheelRules = require(Shared:WaitForChild("WheelRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local fx = ReplicatedStorage:WaitForChild("GardenRemotes"):WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local UI = ClientState.UI
local SFX = ClientState.SFX
local new, corner, stroke, text = ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text

local WHEEL = GardenConfig.WHEEL
local CENTRE = Vector3.new(WHEEL.centre.x, WHEEL.centre.y, WHEEL.centre.z)
local AXLE = Vector3.new(WHEEL.stand.x, WHEEL.stand.y + 5, WHEEL.stand.z + 0.5) -- the stand faces +z
local WEDGE = 360 / #WHEEL.wedges
local SPIN_TIME = 3.5
local SPIN_TURNS = 4
local IDLE_TURNS = 0.1
local BROWN = Color3.fromRGB(150, 110, 80)
local KIND_COLOUR = { pink = UI.PINK, gold = UI.GOLD, cone = BROWN }
local KIND_MODEL = { pink = "petal_pink", gold = "petal_gold", cone = "pinecone" }
local KIND_SIGN = { pink = "+1", gold = "+3", cone = "-2" }

local function wedgeColours(id: string): (Color3, Color3)
	local pair = ClientState.EGG_COLOURS[id]
	if pair then
		return pair[1], pair[2]
	end
	return UI.GOLD, Color3.fromRGB(255, 225, 140)
end

local function wedgeName(id: string): string
	local egg = GardenConfig.egg(id)
	return if egg then egg.name else "Coins"
end

-- Props: NightModels clones or part fallbacks -------------------------------------------------------

local function ghost(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
end

local function template(name: string): Model?
	local shared = ReplicatedStorage:FindFirstChild("NightModels")
	local t = shared and shared:FindFirstChild(name)
	return if t and t:IsA("Model") then t else nil
end

local function ball(size: Vector3, colour: Color3): Part
	return new(
		"Part",
		{ Shape = Enum.PartType.Ball, Size = size, Color = colour, Material = Enum.Material.SmoothPlastic }
	)
end

-- One falling drop: the model, or a flattened pink or gold Ball, or a brown Ball.
local function dropModel(kind: string): Model
	local t = template((KIND_MODEL :: any)[kind])
	local m = if t
		then t:Clone()
		else new("Model", {}, { ball(Vector3.new(1.2, 0.3, 0.8), (KIND_COLOUR :: any)[kind]) })
	if kind == "cone" and t == nil then
		(m:FindFirstChildOfClass("Part") :: Part).Size = Vector3.new(0.7, 1, 0.7)
	end
	ghost(m)
	if t == nil then
		m.WorldPivot = (m:FindFirstChildOfClass("Part") :: Part).CFrame
	end
	return m
end

local function basketModel(): Model
	local t = template("wheel_basket")
	local m = if t then t:Clone() else new("Model", {}, { ball(Vector3.new(1.6, 1.2, 1.6), BROWN) })
	if t == nil then
		(m:FindFirstChildOfClass("Part") :: Part).Shape = Enum.PartType.Cylinder
		m.WorldPivot = (m:FindFirstChildOfClass("Part") :: Part).CFrame
	end
	ghost(m)
	return m
end

-- The 3D disc at the stand, turned about its own z: the model, or a cylinder with 8 wedge blocks in
-- disc order clockwise from the pointer (top).
local discYaw = 0 -- the artist's disc faces -z at yaw 0, like the stand; the fallback is built facing +z
local function discModel(): Model
	local t = template("wheel_disc")
	if t then
		local m = t:Clone()
		ghost(m)
		m.WorldPivot = m:GetBoundingBox() -- bounding box centre on the axle (architecture 9)
		discYaw = math.pi
		return m
	end
	local m = Instance.new("Model")
	new("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 6, 6),
		Color = UI.CREAM,
		CFrame = CFrame.Angles(0, math.rad(90), 0),
		Parent = m,
	})
	for i, w in WHEEL.wedges do
		local a = math.rad((i - 0.5) * WEDGE)
		local top, bottom = wedgeColours(w.id)
		-- Rotation about +z takes the top towards -x: clockwise for a viewer on the plaza side (+z).
		local block = new("Part", {
			Size = Vector3.new(1.4, 1.4, 0.3),
			Color = top,
			CFrame = CFrame.Angles(0, 0, a) * CFrame.new(0, 2.1, 0.4),
			Parent = m,
		})
		new("Part", {
			Size = Vector3.new(1.4, 0.5, 0.32),
			Color = bottom,
			CFrame = block.CFrame * CFrame.new(0, -0.45, 0),
			Parent = m,
		})
	end
	m.WorldPivot = CFrame.identity
	ghost(m)
	return m
end

local disc = discModel()
disc.Name = "WheelDisc"
disc.Parent = Workspace
local discAngle = 0 -- degrees clockwise from the pointer, shared by the 3D disc and the panel

local function setDisc(angle: number)
	discAngle = angle
	disc:PivotTo(CFrame.new(AXLE) * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.Angles(0, discYaw, 0))
end

-- Round state ----------------------------------------------------------------------------------------

type Round = { seed: number, startAt: number, endAt: number, practice: boolean, spinsLeft: number }
type Petal = { model: Model, done: boolean }

local round: Round? = nil
local drops: { WheelRules.Drop } = {}
local petals: { [number]: Petal } = {}
local score = 0
local basket: Model? = nil
local petalFolder: Folder? = nil
local pendingSpin: any = nil

local function hand(): BasePart?
	local c = player.Character
	local h = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
	return if h and h:IsA("BasePart") then h else nil
end

local function basketAt(): Vector3
	local h = hand()
	if basket and h then
		local root = basket.PrimaryPart or basket:FindFirstChildWhichIsA("BasePart")
		return if root then root.Position else h.Position
	end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r.Position else CENTRE
end

local function holdBasket()
	local h = hand()
	if h == nil or basket then
		return
	end
	local m = basketModel()
	m:PivotTo(h.CFrame * CFrame.new(0, -1.2, 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = h
			weld.Part1 = d
			weld.Parent = d
		end
	end
	m.Parent = Workspace
	basket = m
end

local function dropBasket()
	if basket then
		basket:Destroy()
		basket = nil
	end
end

local function settle(i: number, p: Petal)
	p.done = true
	local d = drops[i]
	local m = p.model
	local flat = CFrame.new(d.x, CENTRE.Y + 0.2, d.z) * CFrame.Angles(0, i, 0)
	local pose = if d.kind == "cone" then flat * CFrame.new(0.6, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2) else flat
	m:PivotTo(pose)
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(2), { Transparency = 1 }):Play()
		end
	end
	task.delay(2.1, m.Destroy, m)
end

RunService.Heartbeat:Connect(function(dt: number)
	local r = round
	if r == nil then
		setDisc((discAngle + IDLE_TURNS * 360 * dt) % 360)
		return
	end
	local now = ClientState.now()
	for i, d in drops do
		local p = petals[i]
		if d.at > now or (p and p.done) then
			continue
		end
		if p == nil then
			p = { model = dropModel(d.kind), done = false }
			p.model.Parent = petalFolder
			petals[i] = p
		end
		local y = CENTRE.Y + WHEEL.canopy - WHEEL.fall * (now - d.at)
		if y < CENTRE.Y + 0.3 then
			settle(i, p)
		else
			local sway = 0.4 * math.sin(now * 2 + i) -- cosmetic, under 0.5 studs; the server scores the straight line
			p.model:PivotTo(CFrame.new(d.x + sway, y, d.z) * CFrame.Angles(0, now + i, math.sin(now * 3 + i) * 0.4))
		end
	end
end)

-- HUD -----------------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "GardenWheel",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Under the coin chip, top centre, clear of the quick-button column (left) and the jump button.
local chip = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.fromOffset(440, 104),
	BackgroundColor3 = UI.CREAM,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = gui,
}, { corner(16), stroke(UI.WHITE, 3) })
ClientState.autoScale(chip)
local chipScale = chip:FindFirstChildOfClass("UIScale") :: UIScale
local scoreText = text({
	Position = UDim2.fromOffset(16, 4),
	Size = UDim2.fromOffset(120, 56),
	Text = "0",
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = chip,
})
local timeText = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 10),
	Size = UDim2.fromOffset(120, 44),
	Text = "45",
	TextColor3 = UI.LEAF,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = chip,
})
local spinsText = text({
	Position = UDim2.fromOffset(140, 14),
	Size = UDim2.fromOffset(170, 36),
	Text = "",
	TextColor3 = UI.MUTED,
	Parent = chip,
})
local bar = new("Frame", {
	Position = UDim2.fromOffset(16, 68),
	Size = UDim2.new(1, -32, 0, 18),
	BackgroundColor3 = UI.GREY,
	Parent = chip,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = UI.PINK,
	Parent = bar,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local BAR_MAX = WHEEL.drops.pink + WHEEL.points.gold * WHEEL.drops.gold -- a perfect round
for _, mark in { { WHEEL.spinAt, "Spin" }, { WHEEL.luckyAt, "Lucky" } } do
	local at = (mark[1] :: number) / BAR_MAX
	new(
		"Frame",
		{ Position = UDim2.fromScale(at, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = UI.INK, Parent = bar }
	)
	text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(at, 1),
		Size = UDim2.fromOffset(90, 16),
		Text = `{mark[2]} {mark[1]}`,
		TextColor3 = UI.MUTED,
		Parent = bar,
	})
end

local function setScore(n: number)
	score = n
	scoreText.Text = tostring(n)
	fill.Size = UDim2.fromScale(math.clamp(n / BAR_MAX, 0, 1), 1)
	ClientState.pop(scoreText)
end

-- Floating "+1" over the basket.
local function float(sign: string, colour: Color3)
	local at = basketAt() + Vector3.new(0, 2.5, 0)
	local bill =
		new("BillboardGui", { Size = UDim2.fromOffset(80, 40), AlwaysOnTop = true, Parent = Workspace.Terrain })
	bill.StudsOffsetWorldSpace = at
	local label = text({ Size = UDim2.fromScale(1, 1), Text = sign, TextColor3 = colour, Parent = bill })
	new("UIStroke", { Color = UI.WHITE, Thickness = 2, Parent = label })
	TweenService:Create(bill, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = at + Vector3.new(0, 2.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	task.delay(1, bill.Destroy, bill)
end

-- End card and wheel panel ----------------------------------------------------------------------------

local card = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 200),
	BackgroundColor3 = UI.CREAM,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	Parent = gui,
}, { corner(24), stroke(UI.PINK, 5) })
ClientState.autoScale(card)
local cardTitle = text({
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -40, 0, 56),
	Text = "",
	TextColor3 = UI.PINK,
	Parent = card,
})
new("UIStroke", { Color = UI.WHITE, Thickness = 3, Parent = cardTitle })
local cardLine = text({
	Position = UDim2.fromOffset(20, 80),
	Size = UDim2.new(1, -40, 0, 60),
	Text = "",
	TextColor3 = UI.LEAF,
	TextScaled = false,
	TextSize = 32,
	TextWrapped = true,
	Parent = card,
})
local panel = new("Frame", {
	Position = UDim2.fromOffset(20, 76),
	Size = UDim2.new(1, -40, 0, 500),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = card,
})
-- The disc: a round frame with 8 pockets at 45 degree steps, rotated as a whole; pointer at the top.
local discFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(170, 170),
	Size = UDim2.fromOffset(300, 300),
	BackgroundColor3 = UI.CARD,
	Parent = panel,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(UI.GOLD, 6) })
for i, w in WHEEL.wedges do
	local a = math.rad((i - 0.5) * WEDGE)
	local top, bottom = wedgeColours(w.id)
	local pocket = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.sin(a) * 110, 0.5, -math.cos(a) * 110),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = top,
		Rotation = (i - 0.5) * WEDGE,
		Parent = discFrame,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }),
		stroke(UI.WHITE, 2),
	})
	local label = text({
		Size = UDim2.fromScale(1, 1),
		Text = if w.id == "coins" then "Coins" else (string.gsub(wedgeName(w.id), " Egg", "")),
		TextColor3 = UI.WHITE,
		Parent = pocket,
	})
	new("UIStroke", { Color = UI.INK, Thickness = 1.5, Parent = label })
end
new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(170, 4),
	Size = UDim2.fromOffset(40, 36),
	BackgroundTransparency = 1,
	Text = "▼",
	TextScaled = true,
	Font = Enum.Font.FredokaOne,
	TextColor3 = UI.CORAL,
	ZIndex = 3,
	Parent = panel,
})
local spinButton = ClientState.button({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(170, 336),
	Size = UDim2.fromOffset(220, 64),
	Text = "SPIN",
	Parent = panel,
}, function() end)
local resultLine = text({
	Position = UDim2.fromOffset(0, 410),
	Size = UDim2.new(1, 0, 0, 80),
	Text = "",
	TextColor3 = UI.LEAF,
	TextScaled = false,
	TextSize = 30,
	TextWrapped = true,
	Parent = panel,
})
-- Both odds columns (G4.2), as percentages.
local odds = new("Frame", {
	Position = UDim2.fromOffset(350, 0),
	Size = UDim2.new(1, -350, 0, 400),
	BackgroundTransparency = 1,
	Parent = panel,
})
do
	local rows = { "Wedge\tStandard\tLucky" }
	for _, w in WHEEL.wedges do
		table.insert(rows, `{wedgeName(w.id)}\t{HatchRules.percent(w.standard)}%\t{HatchRules.percent(w.lucky)}%`)
	end
	for i, row in rows do
		local cells = string.split(row, "\t")
		for c, cell in cells do
			text({
				Position = UDim2.fromOffset(if c == 1 then 0 else 130 + (c - 2) * 95, (i - 1) * 32),
				Size = UDim2.fromOffset(if c == 1 then 130 else 90, 30),
				Text = cell,
				TextSize = 24,
				TextScaled = false,
				TextColor3 = if i == 1 then UI.MUTED else UI.INK,
				TextXAlignment = if c == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
				Parent = odds,
			})
		end
	end
	text({
		Position = UDim2.fromOffset(0, #rows * 32 + 8),
		Size = UDim2.new(1, 0, 0, 60),
		Text = `The lucky wheel is for a score of {WHEEL.luckyAt} or more`,
		TextSize = 22,
		TextScaled = false,
		TextWrapped = true,
		TextColor3 = UI.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = odds,
	})
end

local cardToken = 0
local wheelDue = false -- the title phase of a spin or lucky end card: a tap goes straight to the wheel
local showWheel
local function closeCard()
	card.Visible = false
	panel.Visible = false
	wheelDue = false
	if GuiService.SelectedObject == spinButton then
		GuiService.SelectedObject = nil
	end
end
card.Activated:Connect(function()
	if wheelDue then
		showWheel()
	elseif not panel.Visible then
		closeCard()
	end
end)

local function showCard(title: string, line: string, seconds: number?)
	cardTitle.Text = title
	cardLine.Text = line
	cardLine.Visible = line ~= ""
	card.Size = UDim2.fromOffset(720, 200)
	panel.Visible = false
	card.Visible = true
	cardToken += 1
	local token = cardToken
	if seconds then
		task.delay(seconds, function()
			if token == cardToken then
				closeCard()
			end
		end)
	end
end

local spinning = false
local spinArmed = false
local function arm(on: boolean)
	spinArmed = on
	spinButton.BackgroundColor3 = if on then UI.PINK else UI.GREY
end

local function resultText(data: any): string
	if data.wedge == "coins" then
		return `+{ClientState.commas(tonumber(data.coins) or 0)} coins`
	end
	return `{wedgeName(data.wedge)}! Saved with your prize eggs. Open DASH to plant it.`
end

-- The pre-decided spin: 4 turns plus the wedge's centre and a random offset within 80% of the wedge,
-- Quint ease out, never backing up; one chime at the stop (no ticking: G4.3).
local function spinTo(data: any)
	if spinning then
		return
	end
	spinning = true
	spinButton.Visible = false
	local index = 1
	for i, w in WHEEL.wedges do
		if w.id == data.wedge then
			index = i
		end
	end
	local target = (index - 0.5) * WEDGE + (math.random() - 0.5) * WEDGE * 0.8
	local from = discAngle % 360
	local travel = SPIN_TURNS * 360 + (-target - from) % 360 -- disc angle that puts the wedge under the pointer
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(v)
		setDisc(from + v)
		discFrame.Rotation = discAngle
	end)
	ClientState.sound(SFX.whoosh, 0.3)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Value = travel }
	)
	tween.Completed:Once(function()
		value:Destroy()
		spinning = false
		ClientState.sound(SFX.chime, 1.0)
		resultLine.Text = resultText(data)
		ClientState.pop(resultLine)
		if data.wedge == "celestial" or data.wedge == "aurora" then
			local top, bottom = wedgeColours(data.wedge)
			ClientState.sound(SFX.fanfare, 0.5)
			ClientState.burst(AXLE, top, 60, 16, 0.8)
			ClientState.burst(basketAt() + Vector3.new(0, 3, 0), bottom, 40, 12, 0.6)
		end
		cardToken += 1
		local token = cardToken
		task.delay(6, function()
			if token == cardToken then
				closeCard()
			end
		end)
	end)
	tween:Play()
end

spinButton.Activated:Connect(function()
	if not spinArmed then
		return
	end
	arm(false)
	if pendingSpin then
		spinTo(pendingSpin)
	else
		spinButton.Text = "..." -- the result shows on arrival (2 s fallback armed the button)
	end
end)

function showWheel()
	wheelDue = false
	cardLine.Visible = false
	card.Size = UDim2.fromOffset(720, 600)
	panel.Visible = true
	discFrame.Rotation = discAngle
	resultLine.Text = ""
	spinButton.Text = "SPIN"
	spinButton.Visible = true
	arm(pendingSpin ~= nil)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = spinButton
	end
	if not spinArmed then
		task.delay(2, function()
			if panel.Visible and not spinning and not spinArmed then
				arm(true)
			end
		end)
	end
end

-- Stand label ------------------------------------------------------------------------------------------

local function spinsLine(): string
	local p = ClientState.profile()
	if player:GetAttribute("ProfileOnline") == false then
		return "Saving is off on this server · practice only"
	end
	local left = WheelRules.spinsLeft(p, math.floor(ClientState.now() / 86400))
	return if left <= 0
		then `All {WHEEL.spinsPerDay} spins used today · practice rounds open`
		else `{left} spin{if left == 1 then "" else "s"} left today`
end

local standLabel: TextLabel? = nil
local function updateLabel()
	if not (standLabel and standLabel.Parent) then
		local garden = Workspace:FindFirstChild("Garden")
		local wheel = garden and garden:FindFirstChild("Wheel")
		local found = wheel and wheel:FindFirstChild("SpinsLabel", true)
		standLabel = if found and found:IsA("TextLabel") then found else nil
	end
	if standLabel then
		standLabel.Text = spinsLine()
	end
	local prompt = standLabel and standLabel:FindFirstAncestorWhichIsA("BasePart")
	local play = prompt and prompt:FindFirstChildOfClass("ProximityPrompt")
	if play then
		play.Enabled = round == nil
	end
end
player:GetAttributeChangedSignal("Profile"):Connect(updateLabel)
player:GetAttributeChangedSignal("ProfileOnline"):Connect(updateLabel)
task.spawn(function()
	while true do
		updateLabel()
		task.wait(60) -- day rollover
	end
end)

-- Fx -------------------------------------------------------------------------------------------------------

local function onStart(data: any)
	round = {
		seed = data.seed,
		startAt = data.startAt,
		endAt = data.endAt,
		practice = data.practice == true,
		spinsLeft = tonumber(data.spinsLeft) or 0,
	}
	drops = WheelRules.schedule(data.seed, data.startAt)
	table.clear(petals)
	pendingSpin = nil
	if petalFolder then
		petalFolder:Destroy()
	end
	petalFolder = new("Folder", { Name = "WheelPetals", Parent = Workspace })
	setScore(0)
	local r = round :: Round
	spinsText.Text = if r.practice
		then "Practice"
		else `{r.spinsLeft} spin{if r.spinsLeft == 1 then "" else "s"} left today`
	chip.Visible = true
	closeCard()
	holdBasket()
	updateLabel()
	ClientState.sound(SFX.whoosh, 0.3)
end

local function onCatch(data: any)
	local i = tonumber(data.i) or 0
	local kind = tostring(data.kind)
	setScore(tonumber(data.score) or score)
	local p = petals[i]
	if p and not p.done then
		p.done = true
		local m = p.model
		local target = basketAt()
		local root = m:FindFirstChildWhichIsA("BasePart")
		if root then
			local t = 0
			local from = m:GetPivot()
			local conn
			conn = RunService.Heartbeat:Connect(function(dt)
				t += dt / 0.15
				if t >= 1 then
					conn:Disconnect()
					m:Destroy()
				else
					m:PivotTo(from:Lerp(CFrame.new(basketAt()), t))
				end
			end)
		else
			m:Destroy()
		end
		if kind == "cone" then
			-- Bounces off the basket: it is a petal that is not caught, not a loss.
			local cone = dropModel("cone")
			cone:PivotTo(CFrame.new(target))
			cone.Parent = petalFolder
			settle(i, { model = cone, done = true })
		end
	end
	float((KIND_SIGN :: any)[kind] or "", (KIND_COLOUR :: any)[kind] or UI.INK)
	if kind == "pink" then
		ClientState.sound(SFX.tick, 0.3, nil, 1.6)
	elseif kind == "gold" then
		ClientState.sound(SFX.chime, 0.4, nil, 1.3)
	end
end

local function onOver(data: any)
	local r = round
	round = nil
	chip.Visible = false
	dropBasket()
	if petalFolder then
		local folder = petalFolder
		task.delay(3, folder.Destroy, folder) -- petals still in the air settle on their own
		petalFolder = nil
	end
	table.clear(petals)
	updateLabel()
	ClientState.sound(SFX.whoosh, 0.3)
	local n = tonumber(data.score) or 0
	local petalsText = `{n} petal{if n == 1 then "" else "s"}`
	if data.tier == "spin" or data.tier == "lucky" then
		showCard(`Nice catch! {petalsText}`, if data.tier == "lucky" then "Lucky wheel!" else "", nil)
		wheelDue = true
		task.delay(if r then 3 else 0, function()
			if wheelDue then
				showWheel()
			end
		end)
	elseif r and r.practice then
		showCard(`Practice round · {petalsText}`, "", 3)
	elseif n >= WHEEL.spinAt then
		showCard(`Nice catch! {petalsText}`, "", 3)
	else
		showCard("Nice try, play again", petalsText, 3)
	end
end

local function onSpin(data: any)
	pendingSpin = data
	if panel.Visible and spinButton.Text == "..." then
		spinTo(data)
	elseif panel.Visible and not spinning then
		arm(true)
	end
end

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "wheelStart" then
		onStart(data)
	elseif kind == "wheelCatch" then
		onCatch(data)
	elseif kind == "wheelOver" then
		onOver(data)
	elseif kind == "wheelSpin" then
		onSpin(data)
	end
end)

RunService.RenderStepped:Connect(function()
	local r = round
	if r then
		timeText.Text = tostring(math.max(0, math.ceil(r.endAt - ClientState.now())))
		chip.Position = UDim2.new(0.5, 0, 0, 12 + 88 * chipScale.Scale) -- under Hud's coin chip
	end
end)

player.CharacterAdded:Connect(function()
	dropBasket()
	if round then
		task.delay(0.5, holdBasket)
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
