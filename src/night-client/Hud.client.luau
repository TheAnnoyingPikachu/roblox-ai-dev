--!strict
-- Hundred Demon Night combat HUD (GDD H2, E, F1, G, B6-B7): HP bar, Demon Trigger gauge, skill
-- and dash cooldown rings, style rank meter, wave banner and boss bar, charms, teammate HP pips,
-- blessing cards, first-run prompts, countdown and wave callouts, Victory and Defeat screens.
-- Reads server attributes and NightStatus; the only thing it sends is Request("pickBlessing").

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlessingRules = require(Shared:WaitForChild("BlessingRules"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local NightProgress = require(Shared:WaitForChild("NightProgress"))
local StyleRules = require(Shared:WaitForChild("StyleRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local remotes = ReplicatedStorage:WaitForChild("NightRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local SFX = ClientState.SFX

-- Style -----------------------------------------------------------------------------------------

local INK = Color3.fromRGB(18, 14, 24)
local PANEL = Color3.fromRGB(32, 24, 40)
local RED = Color3.fromRGB(220, 40, 50)
local GOLD = Color3.fromRGB(255, 200, 70)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 160, 185)
local GREEN = Color3.fromRGB(80, 220, 120)
local SPIRIT = Color3.fromRGB(140, 200, 255)
local PURPLE = Color3.fromRGB(150, 70, 255)

local RANK_COLOURS = {
	Color3.fromRGB(170, 170, 180),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(110, 255, 140),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 60, 90),
	Color3.fromRGB(255, 60, 220),
}

-- One kanji per blessing as its card icon (CJK renders through Roblox's font fallback; no emoji).
local BLESSING_ICONS = {
	edge = "刃",
	swift = "速",
	iron = "鉄",
	foxfire = "狐",
	thunder = "雷",
	lantern = "灯",
	hunger = "餓",
	longnight = "夜",
	ninetails = "尾",
	storm = "嵐",
	shockwave = "衝",
	link = "絆",
}

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(colour: Color3, thickness: number): UIStroke
	return new("UIStroke", { Color = colour, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

local function bar(parent: Instance, position: UDim2, size: UDim2, colours: { Color3 }): (Frame, Frame)
	local back = new("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.15,
		Parent = parent,
	}, { corner(6), stroke(Color3.fromRGB(70, 55, 85), 1.5) })
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = back }, {
		corner(6),
		new("UIGradient", { Color = ColorSequence.new(colours[1], colours[2]) }),
	})
	return back, fill
end

local function number(value: any, fallback: number): number
	return if type(value) == "number" then value else fallback
end

local function gamepad(): boolean
	return UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
end

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- The default health bar and hotbar give way to this HUD (number keys pick blessings).
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

-- Root ------------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "NightHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 4,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })

-- Vitals: HP, Demon Trigger gauge, charms, ability rings (bottom centre) -------------------------

local vitals = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = if touchOnly then UDim2.new(0.42, 0, 1, -10) else UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(if touchOnly then 340 else 560, 96),
	BackgroundTransparency = 1,
	Parent = hud,
})
ClientState.autoScale(vitals)

local hpBack, hpFill = bar(vitals, UDim2.fromOffset(0, 26), UDim2.fromOffset(330, 26), {
	Color3.fromRGB(255, 70, 110),
	Color3.fromRGB(200, 20, 60),
})
local hpGhost = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 230, 230),
	BackgroundTransparency = 0.3,
	ZIndex = 0,
	Parent = hpBack,
}, { corner(6) })
hpFill.ZIndex = 1
local hpText = text({
	Size = UDim2.fromScale(1, 1),
	Text = "100 / 100",
	Font = Enum.Font.GothamBlack,
	ZIndex = 2,
	Parent = hpBack,
})
new("UIStroke", { Thickness = 1.5, Color = INK, Parent = hpText })
text({
	Size = UDim2.fromOffset(60, 22),
	Text = "HP",
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = vitals,
})
local charmRow = new("Frame", {
	Position = UDim2.fromOffset(60, 0),
	Size = UDim2.fromOffset(270, 22),
	BackgroundTransparency = 1,
	Parent = vitals,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}),
})

local gaugeBack, gaugeFill = bar(vitals, UDim2.fromOffset(0, 60), UDim2.fromOffset(330, 18), {
	PURPLE,
	Color3.fromRGB(255, 40, 70),
})
local gaugeStroke = gaugeBack:FindFirstChildOfClass("UIStroke") :: UIStroke
local gaugeText = text({
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.fromOffset(330, 16),
	Text = "DEMON TRIGGER",
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = vitals,
})

-- Ability rings (keyboard and gamepad; touch buttons show their own cooldowns).
type Ring = { frame: Frame, gradient: UIGradient, key: TextLabel, label: TextLabel, outline: UIStroke }
local rings: { [string]: Ring } = {}
local function ring(action: string, label: string, x: number, colour: Color3)
	local f = new("Frame", {
		Position = UDim2.fromOffset(x, 8),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = colour,
		Visible = not touchOnly,
		Parent = vitals,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local outline = stroke(WHITE, 2.5)
	outline.Parent = f
	local cover = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, Parent = f }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local gradient = new("UIGradient", { Rotation = -90, Parent = cover })
	local name = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.32),
		Text = label,
		Font = Enum.Font.GothamBlack,
		ZIndex = 2,
		Parent = f,
	})
	new("UIStroke", { Thickness = 1.5, Color = INK, Parent = name })
	local key = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(64, 16),
		Text = "",
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		Parent = f,
	})
	rings[action] = { frame = f, gradient = gradient, key = key, label = name, outline = outline }
end
ring("skill", "SKILL", 350, Color3.fromRGB(70, 90, 200))
ring("dash", "DASH", 422, Color3.fromRGB(40, 150, 170))
ring("trigger", "TRIGGER", 494, Color3.fromRGB(120, 20, 40))

local function wipe(g: UIGradient, fraction: number)
	local f = math.clamp(fraction, 0.002, 0.998)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if fraction <= 0 then 1 else 0.3),
		NumberSequenceKeypoint.new(f, if fraction <= 0 then 1 else 0.3),
		NumberSequenceKeypoint.new(math.min(f + 0.001, 1), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Style meter (right) ---------------------------------------------------------------------------

local meter = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.4, 0),
	Size = UDim2.fromOffset(220, 150),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = hud,
})
ClientState.autoScale(meter)
local meterPop = new("UIScale", { Parent = meter })
local letter = text({
	Size = UDim2.new(1, 0, 0, 96),
	Text = "D",
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Right,
	Rotation = -6,
	Parent = meter,
})
local letterStroke = new("UIStroke", { Thickness = 4, Color = INK, Parent = letter })
local rankName = text({
	Position = UDim2.fromOffset(0, 92),
	Size = UDim2.new(1, 0, 0, 26),
	Text = "Dull",
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = meter,
})
new("UIStroke", { Thickness = 2, Color = INK, Parent = rankName })
local _, styleFill = bar(meter, UDim2.fromOffset(40, 124), UDim2.new(1, -40, 0, 9), { WHITE, WHITE })
local shownRank = 1

local function refreshStyle()
	local index = math.clamp(math.floor(number(player:GetAttribute("StyleRank"), 1)), 1, #StyleRules.RANKS)
	local points = number(player:GetAttribute("StylePoints"), 0)
	local r = StyleRules.RANKS[index]
	letter.Text = r.letter
	rankName.Text = r.name
	letter.TextColor3 = RANK_COLOURS[index]
	letterStroke.Color = if index >= 5 then Color3.fromRGB(60, 0, 30) else INK
	styleFill.BackgroundColor3 = RANK_COLOURS[index]
	local nextMin = if StyleRules.RANKS[index + 1] then StyleRules.RANKS[index + 1].min else StyleRules.MAX
	styleFill.Size = UDim2.fromScale(math.clamp((points - r.min) / math.max(nextMin - r.min, 1), 0, 1), 1)
	meter.Visible = points > 0.5
	if index > shownRank then
		meterPop.Scale = 1.6
		TweenService
			:Create(meterPop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	shownRank = index
end
player:GetAttributeChangedSignal("StyleRank"):Connect(refreshStyle)
player:GetAttributeChangedSignal("StylePoints"):Connect(refreshStyle)

-- Wave banner and boss bar (top centre) ---------------------------------------------------------

local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(440, 96),
	BackgroundTransparency = 1,
	Parent = hud,
})
ClientState.autoScale(banner)
local waveText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(300, 40),
	BackgroundTransparency = 0.2,
	BackgroundColor3 = PANEL,
	Text = "WAVE 1 / 10",
	Font = Enum.Font.GothamBlack,
	Parent = banner,
})
corner(10).Parent = waveText
stroke(RED, 2).Parent = waveText
new("UIPadding", {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	Parent = waveText,
})
local subText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 42),
	Size = UDim2.fromOffset(300, 18),
	Text = "",
	TextColor3 = GOLD,
	Parent = banner,
})
new("UIStroke", { Thickness = 1.5, Color = INK, Parent = subText })
local bossFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.fromOffset(440, 32),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = banner,
})
local bossName = text({
	Size = UDim2.new(1, 0, 0, 14),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Parent = bossFrame,
})
new("UIStroke", { Thickness = 1.5, Color = INK, Parent = bossName })
local bossBack, bossFill = bar(bossFrame, UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 14), {
	Color3.fromRGB(255, 60, 60),
	Color3.fromRGB(140, 0, 60),
})
for _, mark in { 0.33, 0.66 } do -- Gashadokuro phase marks (D3)
	new("Frame", {
		Position = UDim2.fromScale(mark, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 2,
		Name = "PhaseMark",
		Parent = bossBack,
	})
end

-- Teammates (left middle) -------------------------------------------------------------------------

local team = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(200, 220),
	BackgroundTransparency = 1,
	Parent = hud,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
ClientState.autoScale(team)
local pips: { [number]: { frame: Frame, fill: Frame, name: TextLabel } } = {}

local function refreshTeam()
	local ids = ClientState.status().ids
	local keep: { [number]: boolean } = {}
	for i, id in ids do
		local other = Players:GetPlayerByUserId(id)
		if id ~= player.UserId and other then
			keep[id] = true
			local pip = pips[id]
			if pip == nil then
				local f = new("Frame", {
					Size = UDim2.fromOffset(200, 32),
					BackgroundColor3 = PANEL,
					BackgroundTransparency = 0.25,
					Parent = team,
				}, {
					corner(8),
				})
				local name = text({
					Position = UDim2.fromOffset(8, 2),
					Size = UDim2.new(1, -16, 0, 14),
					Text = other.DisplayName,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = f,
				})
				local _, fill =
					bar(f, UDim2.fromOffset(8, 19), UDim2.new(1, -16, 0, 8), { GREEN, Color3.fromRGB(40, 170, 90) })
				pip = { frame = f, fill = fill, name = name }
				pips[id] = pip
			end
			pip.frame.LayoutOrder = i
			local hp, maxHp =
				number(other:GetAttribute("HP"), 100), math.max(number(other:GetAttribute("MaxHP"), 100), 1)
			pip.fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			pip.name.Text = if hp <= 0 then `{other.DisplayName}  DOWN` else other.DisplayName
			pip.name.TextColor3 = if hp <= 0 then SPIRIT else WHITE
		end
	end
	for id, pip in pips do
		if not keep[id] then
			pip.frame:Destroy()
			pips[id] = nil
		end
	end
end

-- Callouts --------------------------------------------------------------------------------------

local callout = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.34),
	Size = UDim2.fromScale(0.8, 0.16),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextTransparency = 1,
	Rotation = -4,
	Parent = gui,
})
local calloutStroke =
	new("UIStroke", { Thickness = 6, Color = Color3.fromRGB(20, 10, 20), Transparency = 1, Parent = callout })
local calloutScale = new("UIScale", { Parent = callout })
local calloutSub = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.43),
	Size = UDim2.fromScale(0.6, 0.05),
	Text = "",
	TextColor3 = WHITE,
	TextTransparency = 1,
	Parent = gui,
})
local calloutSubStroke = new("UIStroke", { Thickness = 3, Color = INK, Transparency = 1, Parent = calloutSub })

-- Slams a word onto the screen, holds it, then fades it out (Relay's StatusBar callout).
local function slam(word: string, colour: Color3, hold: number, sub: string?)
	callout.Text = word
	callout.TextColor3 = colour
	callout.TextTransparency = 0
	calloutStroke.Transparency = 0
	calloutSub.Text = sub or ""
	calloutSub.TextTransparency = if sub then 0 else 1
	calloutSubStroke.Transparency = if sub then 0 else 1
	calloutScale.Scale = 2.2
	TweenService
		:Create(calloutScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local shown = word
	task.delay(hold, function()
		if callout.Text == shown then
			local out = TweenInfo.new(0.4)
			TweenService:Create(callout, out, { TextTransparency = 1 }):Play()
			TweenService:Create(calloutStroke, out, { Transparency = 1 }):Play()
			TweenService:Create(calloutSub, out, { TextTransparency = 1 }):Play()
			TweenService:Create(calloutSubStroke, out, { Transparency = 1 }):Play()
		end
	end)
end

-- First-run prompts (H2) ------------------------------------------------------------------------

local promptLabel = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -140),
	Size = UDim2.fromOffset(460, 40),
	BackgroundTransparency = 0.2,
	BackgroundColor3 = PANEL,
	Text = "",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBlack,
	Visible = false,
	Parent = hud,
})
corner(10).Parent = promptLabel
stroke(GOLD, 2).Parent = promptLabel
new("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	Parent = promptLabel,
})
ClientState.autoScale(promptLabel)

local firstRun = false
local promptStep = 0 -- 0 waiting, 1 slash, 2 skill, 3 dash, 4 trigger, 5 done
local cardsShown = false
local pickedOnce = false
local ownHits = 0
local launched = false
local gaugeFilled = false

local function promptText(step: number): string
	local pad, tap = gamepad(), touchOnly
	if step == 1 then
		return if tap then "Tap ATTACK to slash" elseif pad then "R2: slash" else "Click to slash"
	elseif step == 2 then
		return if tap then "SKILL: Rising Slash" elseif pad then "Y: Rising Slash" else "E: Rising Slash"
	elseif step == 3 then
		return if tap
			then "DASH through attacks"
			elseif pad then "X: Dash through attacks"
			else "Q: Dash through attacks"
	elseif step == 4 then
		return if tap then "TRIGGER: DEMON TRIGGER" elseif pad then "B: DEMON TRIGGER" else "R: DEMON TRIGGER"
	elseif step == 5 then
		return if tap then "Pick a blessing" else "Pick a blessing: 1, 2 or 3"
	end
	return ""
end

local function refreshPrompt()
	if not firstRun then
		promptLabel.Visible = false
		return
	end
	if promptStep == 0 and ClientState.status().state == "Wave" then
		promptStep = 1
	end
	-- Each prompt appears once its cue has happened and stays until it is done (H2 order); the
	-- blessing prompt belongs to the first break whatever step the others are on.
	local show = 0
	if cardsShown and not pickedOnce then
		show = 5
	elseif
		promptStep == 1
		or (promptStep == 2 and ownHits >= 3)
		or (promptStep == 3 and launched)
		or (promptStep == 4 and gaugeFilled)
	then
		show = promptStep
	end
	promptLabel.Text = promptText(show)
	promptLabel.Visible = show > 0
end

ClientState.Acted:Connect(function(action: string)
	if (promptStep == 1 and action == "attack") or (promptStep == 2 and action == "skill") then
		promptStep += 1
	elseif promptStep == 4 and action == "trigger" then
		promptStep = 5
	end
	refreshPrompt()
end)
ClientState.Dashed:Connect(function()
	if promptStep == 3 and launched then
		promptStep = 4
		refreshPrompt()
	end
end)
fx.OnClientEvent:Connect(function(kind: any, data: any)
	if kind == "hit" and type(data) == "table" and data.u == player.UserId then
		ownHits += 1
		if os.clock() - ClientState.sent.skill < 0.6 then
			launched = true -- a Rising Slash that landed
		end
		refreshPrompt()
	end
end)

local function readProfile()
	local p = ClientState.json(player:GetAttribute("Profile"))
	if type(p) == "table" then
		local runs = tonumber(p.runs) or 0
		if runs == 0 and not firstRun and promptStep == 0 then
			firstRun = true
		elseif runs > 0 then
			firstRun = false
		end
	end
	refreshPrompt()
end
player:GetAttributeChangedSignal("Profile"):Connect(readProfile)

-- Blessing cards (E) ----------------------------------------------------------------------------

local cards = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 400),
	Size = UDim2.fromOffset(720, 280),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
ClientState.autoScale(cards)
local cardsTitle = text({
	Size = UDim2.new(1, 0, 0, 36),
	Text = "CHOOSE A BLESSING",
	Font = Enum.Font.GothamBlack,
	TextColor3 = GOLD,
	Parent = cards,
})
new("UIStroke", { Thickness = 3, Color = INK, Parent = cardsTitle })
local cardRow = new("Frame", {
	Position = UDim2.fromOffset(0, 44),
	Size = UDim2.new(1, 0, 0, 226),
	BackgroundTransparency = 1,
	Parent = cards,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 16),
	}),
})
local shownOffer = ""
local picking = false

local function pick(index: number)
	if picking or not cards.Visible then
		return
	end
	picking = true
	local ok, result = pcall(request.InvokeServer, request, "pickBlessing", tostring(index))
	picking = false
	if ok and result == true then
		ClientState.sound(SFX.gong, 0.5, nil, 1.6)
		pickedOnce = true
		refreshPrompt()
	end
end

for i = 1, 3 do
	ContextActionService:BindAction(`NightPick{i}`, function(_, state)
		if state ~= Enum.UserInputState.Begin or not cards.Visible then
			return Enum.ContextActionResult.Pass
		end
		task.spawn(pick, i)
		return Enum.ContextActionResult.Sink
	end, false, (Enum.KeyCode :: any)[({ "One", "Two", "Three" })[i]])
end

local function renderCards(offer: { string })
	for _, c in cardRow:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local stacks = ClientState.json(player:GetAttribute("Blessings"))
	stacks = if type(stacks) == "table" then stacks else {}
	for i, id in offer do
		local b = BlessingRules.get(id)
		if b then
			local have = tonumber(stacks[id]) or 0
			local card = new("TextButton", {
				Size = UDim2.fromOffset(220, 226),
				BackgroundColor3 = PANEL,
				AutoButtonColor = true,
				Text = "",
				LayoutOrder = i,
				Parent = cardRow,
			}, {
				corner(14),
				stroke(if b.party then SPIRIT else GOLD, 3),
				new("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.fromRGB(70, 40, 90), Color3.fromRGB(25, 18, 32)),
				}),
			})
			local badge = text({
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 0,
				BackgroundColor3 = RED,
				Text = if touchOnly then "" else tostring(i),
				Font = Enum.Font.GothamBlack,
				Visible = not touchOnly,
				Parent = card,
			})
			corner(17).Parent = badge
			local icon = text({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 14),
				Size = UDim2.fromOffset(80, 70),
				Text = BLESSING_ICONS[id] or "福",
				TextColor3 = GOLD,
				Font = Enum.Font.GothamBlack,
				Parent = card,
			})
			new("UIStroke", { Thickness = 3, Color = RED, Parent = icon })
			text({
				Position = UDim2.fromOffset(10, 92),
				Size = UDim2.new(1, -20, 0, 28),
				Text = string.upper(b.name),
				Font = Enum.Font.GothamBlack,
				Parent = card,
			})
			text({
				Position = UDim2.fromOffset(12, 124),
				Size = UDim2.new(1, -24, 0, 70),
				Text = b.text,
				TextColor3 = Color3.fromRGB(225, 215, 240),
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
			text({
				Position = UDim2.new(0, 10, 1, -28),
				Size = UDim2.new(1, -20, 0, 18),
				Text = if b.max > 1 then `STACK {have + 1} / {b.max}` else "UNIQUE",
				TextColor3 = MUTED,
				Parent = card,
			})
			card.Activated:Connect(function()
				pick(i)
			end)
		end
	end
end

local function refreshCards()
	local offer = ClientState.json(player:GetAttribute("Offers"))
	local list: { string } = if type(offer) == "table" then offer else {}
	local show = #list > 0 and ClientState.status().state == "Break" and ClientState.isParticipant()
	local key = table.concat(list, ",")
	if show and (not cards.Visible or key ~= shownOffer) then
		shownOffer = key
		renderCards(list)
		cards.Visible = true
		cardsShown = true
		cards.Position = UDim2.new(0.5, 0, 1, 400)
		TweenService:Create(cards, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -130),
		}):Play()
	elseif not show and cards.Visible then
		cardsShown = false
		local out = TweenService:Create(cards, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 400),
		})
		out:Play()
		out.Completed:Once(function()
			if cards.Position.Y.Offset >= 399 then
				cards.Visible = false
			end
		end)
	end
end
player:GetAttributeChangedSignal("Offers"):Connect(function()
	refreshCards()
	refreshPrompt()
end)

-- Downed, Victory and Defeat overlays -----------------------------------------------------------

local downed = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(20, 30, 60),
	BackgroundTransparency = 0.6,
	Visible = false,
	Parent = gui,
})
local downedTitle = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(0.5, 0.1),
	Text = "DOWNED",
	TextColor3 = SPIRIT,
	Font = Enum.Font.GothamBlack,
	Parent = downed,
})
new("UIStroke", { Thickness = 4, Color = INK, Parent = downedTitle })
local downedSub = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.49),
	Size = UDim2.fromScale(0.6, 0.04),
	Text = "",
	Parent = downed,
})
new("UIStroke", { Thickness = 2, Color = INK, Parent = downedSub })

local finale = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = INK,
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
local finaleTitle = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromScale(0.8, 0.16),
	Text = "",
	Font = Enum.Font.GothamBlack,
	Rotation = -3,
	Parent = finale,
})
local finaleStroke = new("UIStroke", { Thickness = 6, Color = INK, Parent = finaleTitle })
local finaleKanji = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.39),
	Size = UDim2.fromScale(0.4, 0.07),
	Text = "百鬼夜行",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBlack,
	Parent = finale,
})
new("UIStroke", { Thickness = 3, Color = RED, Parent = finaleKanji })
local finaleSub = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromScale(0.6, 0.045),
	Text = "",
	Parent = finale,
})
new("UIStroke", { Thickness = 2, Color = INK, Parent = finaleSub })
local finaleTimer = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(0.5, 0.035),
	Text = "",
	TextColor3 = MUTED,
	Parent = finale,
})

local function confetti()
	local colours = { GOLD, RED, WHITE, Color3.fromRGB(255, 150, 200), SPIRIT }
	for _ = 1, 60 do
		local piece = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, 0, -20),
			Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18)),
			BackgroundColor3 = colours[math.random(1, #colours)],
			Rotation = math.random(0, 360),
			BorderSizePixel = 0,
			Parent = finale,
		})
		local fall = 2 + math.random() * 2.5
		TweenService:Create(
			piece,
			TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, math.random() * 1.5),
			{
				Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 30),
				Rotation = piece.Rotation + math.random(-540, 540),
			}
		):Play()
		task.delay(fall + 1.6, piece.Destroy, piece)
	end
end

local function showFinale(victory: boolean, s: ClientState.Status)
	local tierName = string.upper(NightProgress.TIERS[s.tier] or "Crescent")
	finale.Visible = true
	finale.BackgroundTransparency = 1
	TweenService:Create(finale, TweenInfo.new(0.6), { BackgroundTransparency = 0.45 }):Play()
	finaleTitle.Text = if victory then "NIGHT CLEARED" else "THE NIGHT FALLS"
	finaleTitle.TextColor3 = if victory then GOLD else RED
	finaleStroke.Color = if victory then Color3.fromRGB(90, 30, 0) else INK
	finaleSub.Text = if victory
		then `The Gashadokuro is slain under the {tierName} MOON`
		else `Fell on wave {s.wave} of 10 under the {tierName} MOON. Rewards already earned are kept.`
	local scale = finaleTitle:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = finaleTitle })
	scale.Scale = 2.4
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	if victory then
		confetti()
		ClientState.sound(SFX.bigGong, 0.9)
	else
		ClientState.sound(SFX.boom, 0.6, nil, 0.5)
	end
end

-- Status and attributes -------------------------------------------------------------------------

local lastState, lastWave, lastLeft = "", -1, -1
local function onStatus()
	local s = ClientState.status()
	local mine = ClientState.isParticipant()
	hud.Visible = mine and s.state ~= "Idle"
	local tierName = NightProgress.TIERS[s.tier] or "Crescent"

	if s.state == "Countdown" then
		waveText.Text = "NIGHT FALLS"
		subText.Text = `{string.upper(tierName)} MOON  ·  {s.left}s`
	elseif s.state == "Break" then
		waveText.Text = `WAVE {s.wave} CLEARED`
		subText.Text = `BREAK  ·  WAVE {s.wave + 1} IN {s.left}s`
	else
		waveText.Text = `WAVE {math.max(s.wave, 1)} / 10`
		subText.Text = `{string.upper(tierName)} MOON`
	end

	local boss = s.boss
	bossFrame.Visible = boss ~= nil and s.state == "Wave"
	if boss then
		bossName.Text = if s.wave == 10 then "GASHADOKURO" else "ONI GENERAL"
		bossFill.Size = UDim2.fromScale(math.clamp(boss, 0, 1), 1)
		for _, mark in bossBack:GetChildren() do
			if mark.Name == "PhaseMark" then
				(mark :: Frame).Visible = s.wave == 10
			end
		end
	end

	if mine then
		if s.state == "Countdown" and s.left ~= lastLeft and s.left > 0 then
			slam(tostring(s.left), Color3.fromRGB(255, 230, 120), 0.7)
			ClientState.sound(SFX.beep, 0.5)
		end
		if s.state == "Wave" and (lastState ~= "Wave" or s.wave ~= lastWave) then
			local bossWave = s.wave == 5 or s.wave == 10
			slam(
				if s.wave == 10 then "GASHADOKURO" elseif s.wave == 5 then "ONI GENERAL" else `WAVE {s.wave}`,
				if bossWave then RED else WHITE,
				1.4,
				if bossWave then "BOSS WAVE" elseif s.wave == 1 then "Hold the shrine!" else nil
			)
			ClientState.sound(SFX.gong, 0.7)
		elseif s.state == "Break" and lastState ~= "Break" then
			slam("WAVE CLEARED", GREEN, 1.2, "Choose a blessing")
			ClientState.sound(SFX.gong, 0.5, nil, 1.5) -- temple-bell stand-in: the gong, pitched up
		end
		if (s.state == "Victory" or s.state == "Defeat") and lastState ~= s.state then
			showFinale(s.state == "Victory", s)
		end
	end
	if finale.Visible then
		finaleTimer.Text = if s.state == "Victory" or s.state == "Defeat" then `Next night in {s.left}s` else ""
		if s.state ~= "Victory" and s.state ~= "Defeat" then
			TweenService:Create(finale, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			finale.Visible = false
		end
	end
	if s.state == "Countdown" and lastState ~= "Countdown" then
		gaugeFilled, ownHits, launched = false, 0, false
	end

	lastState, lastWave, lastLeft = s.state, s.wave, s.left
	refreshTeam()
	refreshCards()
	refreshPrompt()
end
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(onStatus)

local shownHp = 100
local function refreshVitals()
	local hp = number(player:GetAttribute("HP"), 100)
	local maxHp = math.max(number(player:GetAttribute("MaxHP"), 100), 1)
	local fraction = math.clamp(hp / maxHp, 0, 1)
	hpFill.Size = UDim2.fromScale(fraction, 1)
	-- The pale ghost bar trails damage so the size of each hit reads at a glance.
	TweenService:Create(hpGhost, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25), {
		Size = UDim2.fromScale(fraction, 1),
	}):Play()
	hpText.Text = `{math.floor(hp)} / {math.floor(maxHp)}`
	if hp < shownHp then
		hpBack.Rotation = 2
		TweenService:Create(hpBack, TweenInfo.new(0.2, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play()
	end
	shownHp = hp

	local charms = math.max(0, math.floor(number(player:GetAttribute("Charms"), 0)))
	local icons = {}
	for _, c in charmRow:GetChildren() do
		if c:IsA("Frame") then
			table.insert(icons, c)
		end
	end
	for i = #icons + 1, charms do
		new("Frame", {
			Size = UDim2.fromOffset(13, 13),
			Rotation = 45,
			BackgroundColor3 = GOLD,
			LayoutOrder = i,
			Parent = charmRow,
		}, { stroke(Color3.fromRGB(120, 60, 0), 1.5) })
	end
	for i = charms + 1, #icons do
		icons[i]:Destroy()
	end

	local inRun = ClientState.isParticipant() and ClientState.status().state ~= "Idle"
	downed.Visible = inRun and hp <= 0
	downedSub.Text = "Your spirit lingers: a charm or an ally standing beside you will revive you"
end
for _, name in { "HP", "MaxHP", "Charms" } do
	player:GetAttributeChangedSignal(name):Connect(refreshVitals)
end

-- Every frame: gauge glow and ability cooldown wipes.
RunService.RenderStepped:Connect(function()
	if not hud.Visible then
		return
	end
	local now = os.clock()
	local gauge = math.clamp(number(player:GetAttribute("Gauge"), 0), 0, CombatRules.TRIGGER.cost)
	local active = player:GetAttribute("Trigger") == true
	local full = gauge >= CombatRules.TRIGGER.cost and not active
	gaugeFill.Size = UDim2.fromScale(if active then 1 else gauge / CombatRules.TRIGGER.cost, 1)
	gaugeStroke.Color = if full or active then GOLD else Color3.fromRGB(70, 55, 85)
	gaugeStroke.Thickness = if full then 2.5 + math.sin(now * 10) * 1.5 else 1.5
	local key = if touchOnly then "TRIGGER" elseif gamepad() then "B" else "R"
	gaugeText.Text = if active
		then "DEMON TRIGGER ACTIVE"
		elseif full then `DEMON TRIGGER READY  [{key}]`
		else "DEMON TRIGGER"
	gaugeText.TextColor3 = if full or active then GOLD else MUTED
	if full and not gaugeFilled then
		gaugeFilled = true
		refreshPrompt()
	end

	if not touchOnly then
		local pad = gamepad()
		local stacks = ClientState.json(player:GetAttribute("Blessings"))
		local cooldown = BlessingRules.modifiers(if type(stacks) == "table" then stacks else {}).risingCooldown
		local skillLeft = cooldown - (now - ClientState.sent.skill)
		wipe(rings.skill.gradient, skillLeft / cooldown)
		wipe(rings.dash.gradient, 1 - (now - ClientState.sent.dash))
		wipe(rings.trigger.gradient, if active then 0 else 1 - gauge / CombatRules.TRIGGER.cost)
		rings.skill.key.Text = if skillLeft > 0 then string.format("%.1f", skillLeft) elseif pad then "Y" else "E"
		rings.dash.key.Text = if pad then "X" else "Q"
		rings.trigger.key.Text = if pad then "B" else "R"
		rings.trigger.outline.Color = if full then GOLD else WHITE
		rings.trigger.outline.Thickness = if full then 3.5 + math.sin(now * 10) * 1.5 else 2.5
	end
end)

-- Boot ------------------------------------------------------------------------------------------

gui.Parent = player:WaitForChild("PlayerGui")
readProfile()
refreshVitals()
refreshStyle()
onStatus()
for _, other in Players:GetPlayers() do
	other:GetAttributeChangedSignal("HP"):Connect(refreshTeam)
end
Players.PlayerAdded:Connect(function(other)
	other:GetAttributeChangedSignal("HP"):Connect(refreshTeam)
end)
