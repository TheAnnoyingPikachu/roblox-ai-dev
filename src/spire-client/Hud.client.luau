--!strict
-- Neon Spire HUD (GDD K2, E3, E4, I1, K5; docs/architecture/spire.md section 5): credits count-up
-- and income, "+30s" pops, Market Pulse chip, level and XP, power and Hype bars, BUILD / LIFT /
-- HOME, the Hot Data card with GO, ENDORSE on other towers, the timed first-session script, the
-- "While you were away" card, ticker banners and notices. Hides the Grab and Build prompts on lots
-- this player does not own (the server checks every trigger anyway).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local PlazaRules = require(Shared:WaitForChild("PlazaRules"))
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireEconomy = require(Shared:WaitForChild("SpireEconomy"))
local SpireProgress = require(Shared:WaitForChild("SpireProgress"))
local TowerRules = require(Shared:WaitForChild("TowerRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer :: Player
local UI, FONT = ClientState.UI, ClientState.FONT
local new, corner, stroke, text, button =
	ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text, ClientState.button
local short, commas = ClientState.short, ClientState.commas
local touch = ClientState.touch

local gui = ClientState.gui("SpireHud", 4)
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })

local profile: any = ClientState.me()

-- Credits and income (top left) -------------------------------------------------------------------

local creditBox =
	ClientState.panel({ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(270, 78), Parent = hud }, UI.LIME)
ClientState.autoScale(creditBox)
local creditText = text({
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.new(1, -28, 0, 42),
	Text = "0 ¢",
	FontFace = FONT.mono,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = creditBox,
})
local incomeText = text({
	Position = UDim2.fromOffset(14, 50),
	Size = UDim2.new(1, -28, 0, 22),
	Text = "+0 ¢/s",
	TextColor3 = UI.LIME,
	FontFace = FONT.mono,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = creditBox,
})
local creditValue = new("NumberValue", { Value = 0 })
creditValue.Changed:Connect(function(v: number)
	creditText.Text = `{short(v)} ¢`
end)
local lastCredits: number? = nil

-- A short "+x" that rises from the counter (credits gained, "+30s" for Hot Data).
local function plus(s: string, colour: Color3)
	local t = text({
		Position = UDim2.fromOffset(150, 46),
		Size = UDim2.fromOffset(120, 26),
		Text = s,
		TextColor3 = colour,
		FontFace = FONT.mono,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = creditBox,
	})
	TweenService:Create(t, TweenInfo.new(0.9), { Position = UDim2.fromOffset(150, 20), TextTransparency = 1 }):Play()
	task.delay(1, t.Destroy, t)
end

-- Market Pulse chip (top centre) -------------------------------------------------------------------

local chip = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(330, 66),
	Parent = hud,
})
ClientState.autoScale(chip)
local eventText = text({
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 28),
	Text = "",
	FontFace = FONT.display,
	Parent = chip,
})
local eventSub = text({
	Position = UDim2.fromOffset(12, 38),
	Size = UDim2.new(1, -24, 0, 20),
	Text = "",
	TextColor3 = UI.MUTED,
	Parent = chip,
})
local EVENT_ICONS = { normal = "◇", boom = "▲", neon = "✦", sale = "%" }

-- Level, XP, menu (top right) ------------------------------------------------------------------------

local levelBox = ClientState.panel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 8),
	Size = UDim2.fromOffset(250, 66),
	Parent = hud,
}, UI.VIOLET)
ClientState.autoScale(levelBox)
local levelText = text({
	Position = UDim2.fromOffset(10, 6),
	Size = UDim2.fromOffset(110, 26),
	Text = "LV 1",
	FontFace = FONT.display,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = levelBox,
})
local xpBack = new("Frame", {
	Position = UDim2.fromOffset(10, 38),
	Size = UDim2.fromOffset(110, 8),
	BackgroundColor3 = UI.STEEL,
	Parent = levelBox,
}, { corner(3) })
local xpFill = new(
	"Frame",
	{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.VIOLET, Parent = xpBack },
	{ corner(3) }
)
local xpText = text({
	Position = UDim2.fromOffset(10, 48),
	Size = UDim2.fromOffset(110, 14),
	Text = "",
	TextColor3 = UI.MUTED,
	FontFace = FONT.mono,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = levelBox,
})
local menuButton = button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(110, 52),
	Text = "MENU",
	Outline = true,
	Parent = levelBox,
}, function()
	ClientState.setMode("play")
	ClientState.setMenu(true)
end)
local menuDot = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(14, 14),
	BackgroundColor3 = UI.AMBER,
	Visible = false,
	Parent = menuButton,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

-- Power and Hype bars (left edge, above the thumbstick zone) ------------------------------------------

local bars = ClientState.panel({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.4, 0),
	Size = UDim2.fromOffset(240, 128),
	Parent = hud,
})
ClientState.autoScale(bars)
local function meter(y: number, name: string): (TextLabel, Frame, Frame, TextLabel)
	local head = text({
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, 22),
		Text = name,
		FontFace = FONT.mono,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bars,
	})
	local back = new("Frame", {
		Position = UDim2.fromOffset(12, y + 24),
		Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = UI.STEEL,
		Parent = bars,
	}, { corner(3) })
	local fill = new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.CYAN, Parent = back },
		{ corner(3) }
	)
	local sub = text({
		Position = UDim2.fromOffset(12, y + 36),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "",
		TextColor3 = UI.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bars,
	})
	return head, back, fill, sub
end
local powerHead, _, powerFill, powerSub = meter(6, "⚡ POWER")
local hypeHead, _, hypeFill, hypeSub = meter(66, "♦ HYPE")

-- BUILD, LIFT, HOME (bottom right; raised above the jump button on touch) ----------------------------

local actions = new("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, if touch then -170 else -16),
	Size = UDim2.fromOffset(170, 196),
	BackgroundTransparency = 1,
	Parent = hud,
}, {
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}),
})
ClientState.autoScale(actions)
button(
	{ Size = UDim2.fromOffset(150, 56), Text = "HOME", Outline = true, LayoutOrder = 1, Parent = actions },
	function()
		if ClientState.request("home") then
			ClientState.sound(ClientState.SFX.whoosh, 0.3, nil, 1.2)
		end
	end
)
button(
	{ Size = UDim2.fromOffset(150, 56), Text = "LIFT", Outline = true, LayoutOrder = 2, Parent = actions },
	function()
		ClientState.lift(nil)
	end
)
local buildButton = button(
	{ Size = UDim2.fromOffset(170, 72), Text = "BUILD", LayoutOrder = 3, Parent = actions },
	function()
		ClientState.setMode("tower")
	end
)
local buildRing = buildButton:FindFirstChildOfClass("UIStroke") :: UIStroke

-- ENDORSE: inside another company's lot while its gate allows the visitor ---------------------------

local endorseButton = button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, if touch then -150 else -24),
	Size = UDim2.fromOffset(300, 56),
	Text = "ENDORSE",
	BackgroundColor3 = UI.MAGENTA,
	Visible = false,
	Parent = hud,
}, function() end)
ClientState.autoScale(endorseButton)
local endorseTarget: Player? = nil
endorseButton.Activated:Connect(function()
	local target = endorseTarget
	if target and ClientState.request("endorse", tostring(target.UserId)) then
		ClientState.toast("Endorsed! They will see it on their sign.", UI.LIME)
	end
end)

-- Hot Data card (E3) ---------------------------------------------------------------------------------

local hotCard = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(380, 60),
	Visible = false,
	Parent = hud,
}, UI.AMBER)
ClientState.autoScale(hotCard)
local hotText = text({
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.new(1, -140, 0, 40),
	Text = "",
	TextColor3 = UI.AMBER,
	FontFace = FONT.display,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = hotCard,
})
local hot: { floor: number, slot: number, ends: number }? = nil
button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(110, 48),
	Text = "GO",
	BackgroundColor3 = UI.AMBER,
	Parent = hotCard,
}, function()
	local h = hot
	if h then
		ClientState.setMode("play")
		ClientState.lift(tostring(h.floor))
	end
end)

-- Ticker banner (I1) ---------------------------------------------------------------------------------

local banner = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 152),
	Size = UDim2.fromOffset(560, 44),
	BackgroundTransparency = 0.12,
	BackgroundColor3 = UI.ASPHALT,
	TextColor3 = UI.CYAN,
	FontFace = FONT.display,
	Text = "",
	Visible = false,
	Parent = hud,
})
corner(6).Parent = banner
stroke(UI.MAGENTA, 1.5).Parent = banner
new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = banner })
ClientState.autoScale(banner)
local bannerToken = 0

-- Unlock cards: a department becomes available (K5 floor 3 and floor 5 cards) ------------------------

local unlockCard = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(440, 120),
	Visible = false,
	Parent = hud,
}, UI.AMBER)
ClientState.autoScale(unlockCard)
local unlockTitle = text({
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 30),
	Text = "",
	FontFace = FONT.display,
	TextColor3 = UI.AMBER,
	Parent = unlockCard,
})
local unlockBody = text({
	Position = UDim2.fromOffset(14, 42),
	Size = UDim2.new(1, -28, 0, 22),
	Text = "",
	Parent = unlockCard,
})
local unlockPanel = "Help"
button({
	Position = UDim2.new(0, 14, 1, -48),
	Size = UDim2.new(0.5, -18, 0, 40),
	Text = "LEARN MORE",
	Outline = true,
	Parent = unlockCard,
}, function()
	unlockCard.Visible = false
	ClientState.open(unlockPanel)
end)
button({
	Position = UDim2.new(0.5, 4, 1, -48),
	Size = UDim2.new(0.5, -18, 0, 40),
	Text = "GOT IT",
	Parent = unlockCard,
}, function()
	unlockCard.Visible = false
end)

local EXPLAINER = { fusion = "Power", ad = "Stacking" }
local BLURB = {
	fusion = "Fusion Cells supply power for more modules.",
	ad = "Ad Agencies boost the floors above and below.",
	synth = "Bio-Printers earn 40 ¢/s each.",
	drone = "Courier Drones earn 250 ¢/s each.",
	quantum = "Q-Minds earn 1,600 ¢/s each.",
	orbital = "Uplink Dishes earn 10,000 ¢/s each.",
}
local function showUnlock(d: any)
	unlockTitle.Text = `UNLOCKED: {string.upper(d.name)}`
	unlockBody.Text = BLURB[d.id] or ""
	unlockPanel = EXPLAINER[d.id] or "Help"
	unlockCard.Visible = true
	ClientState.pop(unlockCard)
	ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.4)
	task.delay(10, function()
		if unlockTitle.Text == `UNLOCKED: {string.upper(d.name)}` then
			unlockCard.Visible = false
		end
	end)
end

-- Refresh from the profile ---------------------------------------------------------------------------

local lastLevel: number? = nil
local lastFloors: number? = nil

local function refresh()
	profile = ClientState.me()
	local credits = profile.coins
	if lastCredits and credits > lastCredits then
		plus(`+{short(credits - lastCredits)}`, UI.LIME)
	end
	if lastCredits ~= credits then
		TweenService:Create(creditValue, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Value = credits }):Play()
	end
	lastCredits = credits
	local income = tonumber(player:GetAttribute("Income")) or SpireEconomy.income(profile, ClientState.event())
	incomeText.Text = `+{short(income)} ¢/s`

	local level = ClientState.level(profile)
	local from, to = MetaRules.xpForLevel(level), MetaRules.xpForLevel(level + 1)
	levelText.Text = `LV {level}`
	local maxed = level >= MetaRules.MAX_LEVEL
	xpFill.Size = UDim2.fromScale(if maxed then 1 else (profile.xp - from) / math.max(1, to - from), 1)
	xpText.Text = if maxed then "MAX" else `{commas(profile.xp - from)}/{commas(to - from)} XP`
	menuDot.Visible = ClientState.rewardsReady(profile)
	if lastLevel and level > lastLevel then
		ClientState.toast(`LEVEL UP! Level {level}`, UI.VIOLET)
		ClientState.sound(ClientState.SFX.chime, 0.4, nil, 1.9)
	end
	lastLevel = level

	local draw, supply = TowerRules.draw(profile), TowerRules.supply(profile)
	local ratio = draw / math.max(1, supply)
	local powerColour = if ratio >= 1 then UI.MAGENTA elseif ratio > 0.8 then UI.AMBER else UI.CYAN
	powerHead.Text = `⚡ POWER {draw}/{supply}{if ratio >= 1 then "  FULL" else ""}`
	powerHead.TextColor3 = powerColour
	powerFill.BackgroundColor3 = powerColour
	powerFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	powerSub.Text = if ratio >= 1 then "Build a Fusion Core for more" else `{supply - draw} free`

	local hype, cap, raw = PlazaRules.hype(profile), PlazaRules.hypeCap(profile), PlazaRules.rawHype(profile)
	hypeHead.Text = `♦ HYPE {hype}/{cap}  x{string.format("%.2f", PlazaRules.hypeMult(profile))}`
	hypeFill.Size = UDim2.fromScale(math.clamp(hype / math.max(1, cap), 0, 1), 1)
	hypeFill.BackgroundColor3 = UI.MAGENTA
	hypeSub.Text = if raw >= cap and cap < SpireConfig.HYPE.cap
		then `cap {cap} · build higher to raise it`
		else `cap {cap} · place plaza items`

	local floors = #profile.floors
	if lastFloors and floors > lastFloors then
		for _, d in SpireConfig.DEPTS do
			if d.unlock > lastFloors and d.unlock <= floors then
				showUnlock(d) -- K5: the floor 3 card is Fusion Core, the floor 5 card Ad Agency
			end
		end
	end
	lastFloors = floors
end
ClientState.ProfileChanged:Connect(refresh)
player:GetAttributeChangedSignal("Income"):Connect(refresh)

local function refreshChip()
	local status = ClientState.status()
	local e = status.event
	local colour = ClientState.EVENT_COLOURS[e] or UI.CYAN
	eventText.Text = `{EVENT_ICONS[e] or "◇"} {string.upper(ClientState.eventName(e))}`
	eventText.TextColor3 = colour
	local left = ClientState.clock(ClientState.left(status.eventLeft))
	local f1, f2 = status.forecast[1] or "normal", status.forecast[2] or "normal"
	eventSub.Text = if e ~= "normal"
		then `ends in {left} · next {ClientState.eventName(f1)}, {ClientState.eventName(f2)}`
		else `next {ClientState.eventName(f1)} in {left}, then {ClientState.eventName(f2)}`
end

-- Welcome back (E4) ------------------------------------------------------------------------------------

local welcomeShown = false
local function welcome()
	local offline = tonumber(player:GetAttribute("OfflineCredits")) or 0
	if welcomeShown or offline <= 0 or ClientState.menuOpen then
		return
	end
	welcomeShown = true
	local shade = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.ASPHALT,
		BackgroundTransparency = 0.4,
		ZIndex = 40,
		Parent = gui,
	})
	local card = ClientState.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 240),
		Parent = shade,
	}, UI.LIME)
	ClientState.autoScale(card)
	text({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 38),
		Text = "WHILE YOU WERE AWAY",
		TextColor3 = UI.CYAN,
		FontFace = FONT.display,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(20, 58),
		Size = UDim2.new(1, -40, 0, 24),
		Text = "your tower earned (half rate, up to 8 hours)",
		TextColor3 = UI.MUTED,
		Parent = card,
	})
	local amount = text({
		Position = UDim2.fromOffset(20, 90),
		Size = UDim2.new(1, -40, 0, 56),
		Text = `{commas(offline)} ¢`,
		TextColor3 = UI.LIME,
		FontFace = FONT.mono,
		Parent = card,
	})
	local ok = button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(200, 56),
		Text = "NICE",
		BackgroundColor3 = UI.LIME,
		Parent = card,
	}, function()
		shade:Destroy()
	end)
	if ClientState.gamepad() then
		GuiService.SelectedObject = ok
	end
	ClientState.pop(amount)
	ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
end
player:GetAttributeChangedSignal("OfflineCredits"):Connect(welcome)

-- Fx (section 6.3) --------------------------------------------------------------------------------------

ClientState.fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	local mine = data.lot ~= nil and data.lot == ClientState.myLot()
	if kind == "notice" and type(data.text) == "string" then
		ClientState.toast(data.text, UI.AMBER)
	elseif kind == "ticker" and ClientState.settings.announcements then
		banner.Text = `{string.upper(tostring(data.company))} {tostring(data.text)}`
		banner.Visible = true
		bannerToken += 1
		local token = bannerToken
		task.delay(6, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	elseif kind == "hot" and mine and type(data.floor) == "number" and type(data.ends) == "number" then
		hot = { floor = data.floor, slot = tonumber(data.slot) or 1, ends = data.ends }
		ClientState.sound(ClientState.SFX.chime, 0.4, nil, 2)
	elseif kind == "grabbed" and mine then
		hot = nil
		plus("+30s", UI.AMBER)
		ClientState.toast(`HOT DATA! +{commas(tonumber(data.amount) or 0)} ¢`, UI.AMBER)
	end
end)

local function refreshHot()
	local h = hot
	local left = if h then h.ends - ClientState.now() else 0
	if h and left <= 0 then
		hot = nil
	end
	hotCard.Visible = hot ~= nil
	if h and left > 0 then
		hotText.Text = `HOT DATA · Floor {h.floor} · {math.ceil(left)} s`
	end
end

-- Friend cache for gate checks (IsFriendsWith yields, so it fills in the background).
local friends: { [number]: boolean } = {}
local function isFriend(userId: number): boolean
	if friends[userId] == nil then
		friends[userId] = false
		task.spawn(function()
			local ok, yes = pcall(player.IsFriendsWith, player, userId)
			friends[userId] = ok and yes == true
		end)
	end
	return friends[userId]
end

local function updateEndorse()
	local r = ClientState.root()
	local n = r and ClientState.lotAt(r.Position)
	local owner = n and ClientState.ownerOf(n)
	local state = n and ClientState.lotState(n)
	endorseTarget = nil
	if not (owner and owner ~= player and state and ClientState.mode == "play") then
		endorseButton.Visible = false
		return
	end
	local allowed = SpireProgress.gateAllows(tostring(state.gate), isFriend(owner.UserId))
	local today = MetaRules.dayOf(ClientState.now())
	local done = profile.endorsed.day == today and table.find(profile.endorsed.ids, owner.UserId) ~= nil
	local name = if type(state.company) == "table" then SpireConfig.companyName(state.company) else owner.DisplayName
	endorseTarget = if allowed and not done then owner else nil
	endorseButton.Text = if done
		then "ENDORSED TODAY ✓"
		elseif not allowed then "GATE CLOSED"
		else `ENDORSE {string.upper(name)}`
	ClientState.enable(endorseButton, endorseTarget ~= nil)
	endorseButton.Visible = true
end

-- Grab and Build prompts belong to the lot's owner only.
local function updatePrompts()
	local me = ClientState.myLot()
	for n = 1, 6 do
		local model = ClientState.lotModel(n)
		if not model or n == me then
			continue
		end
		for _, name in { "Hot", "Terminal" } do
			local holder = model:FindFirstChild(name)
			local prompt = holder and holder:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt and prompt.Enabled then
				prompt.Enabled = false
			end
		end
	end
end

-- First session script (K5): one prompt at a time; nothing blocks ignoring it -----------------------

local tutorial = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, if touch then -220 else -90),
	Size = UDim2.fromOffset(500, 54),
	Visible = false,
	Parent = gui,
}, UI.AMBER)
ClientState.autoScale(tutorial)
local tutorialText = text({
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 1, -14),
	Text = "",
	TextColor3 = UI.AMBER,
	Parent = tutorial,
})

local beam = new("Beam", {
	Color = ColorSequence.new(UI.CYAN, UI.MAGENTA),
	Width0 = 1,
	Width1 = 1,
	FaceCamera = true,
	LightEmission = 0.8,
	Transparency = NumberSequence.new(0.2),
	Enabled = false,
	Parent = Workspace.Terrain,
})
local beamStart = new("Attachment", { Parent = Workspace.Terrain })
local beamEnd = new("Attachment", { Parent = Workspace.Terrain })
beam.Attachment0 = beamStart
beam.Attachment1 = beamEnd

local function lotPart(name: string): BasePart?
	local lot = ClientState.myLot()
	local model = lot and ClientState.lotModel(lot)
	local node = model and model:FindFirstChild(name)
	if node and node:IsA("Model") then
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local function modules(): number
	local n = 0
	for _, f in profile.floors do
		for _, level in f.m do
			n += if level > 0 then 1 else 0
		end
	end
	return n
end

local function upgraded(): boolean
	for _, f in profile.floors do
		for _, level in f.m do
			if level >= 2 then
				return true
			end
		end
	end
	return false
end

local stepStarted = os.clock()
type Step = { text: () -> string, done: () -> boolean, target: string? }
local STEPS: { Step } = {
	{
		text = function()
			return "Your first server rack is waiting: press BUILD"
		end,
		done = function()
			return ClientState.mode ~= "play" or modules() >= 1
		end,
		target = "Terminal",
	},
	{
		text = function()
			return "Tap BUY on a slot: a Server Rack costs 15 ¢"
		end,
		done = function()
			return modules() >= 1
		end,
	},
	{
		text = function()
			return `Fill the floor: buy 3 more racks ({math.min(modules(), 4)}/4)`
		end,
		done = function()
			return modules() >= 4 or #profile.floors >= 3
		end,
	},
	{
		text = function()
			return "Upgrade one: each level doubles its income"
		end,
		done = function()
			return upgraded() or #profile.floors >= 3
		end,
	},
	{
		text = function()
			return `Go to the top of the tower and BUY FLOOR 3 ({short(TowerRules.floorCost(3) or 0)} ¢)`
		end,
		done = function()
			return #profile.floors >= 3
		end,
	},
	{
		text = function()
			return if hot
				then "HOT DATA! Tap GO to ride the lift and grab it"
				else "Keep building: Hot Data sparks appear on your floors"
		end,
		done = function()
			return profile.hotCaught >= 1 or (hot == nil and os.clock() - stepStarted > 150)
		end,
	},
	{
		text = function()
			return "In BUILD, open PLAZA and place a Neon Bench for Hype"
		end,
		done = function()
			return #profile.plaza.items >= 1
		end,
	},
	{
		text = function()
			return "Reach floor 5 to unlock the Holo Ad Agency"
		end,
		done = function()
			return #profile.floors >= 5
		end,
	},
}
local step = 0 -- 0 until the profile arrives; past #STEPS when finished or not a first session

local function updateTutorial()
	if step == 0 then
		if ClientState.profile() == nil then
			return
		end
		step = if profile.xp == 0 then 1 else #STEPS + 1
		stepStarted = os.clock()
	end
	while STEPS[step] and STEPS[step].done() do
		step += 1
		stepStarted = os.clock()
		ClientState.sound(ClientState.SFX.click, 0.3, nil, 1.6)
	end
	local s = STEPS[step]
	tutorial.Visible = s ~= nil and not ClientState.menuOpen
	buildRing.Color = if step == 1 then UI.AMBER else UI.CYAN
	buildRing.Thickness = if step == 1 then 3 + math.sin(os.clock() * 6) else 1.5
	local r = ClientState.root()
	local target = s and s.target and lotPart(s.target)
	beam.Enabled = tutorial.Visible and ClientState.mode == "play" and target ~= nil and r ~= nil
	if s then
		tutorialText.Text = s.text()
	end
	if beam.Enabled and target and r then
		beamStart.WorldPosition = r.Position - Vector3.new(0, 2, 0)
		beamEnd.WorldPosition = target.Position + Vector3.new(0, 2, 0)
	end
end

-- Loops ---------------------------------------------------------------------------------------------

local function layout()
	hud.Visible = not ClientState.menuOpen
	actions.Visible = ClientState.mode == "play"
	bars.Visible = ClientState.mode == "play" -- build cards show power and Hype instead
	if not ClientState.menuOpen then
		welcome()
	end
end
ClientState.MenuChanged:Connect(layout)
ClientState.ModeChanged:Connect(layout)

task.spawn(function()
	local tick = 0
	while true do
		tick += 1
		updatePrompts()
		if hud.Visible then
			updateTutorial()
			refreshHot()
			if tick % 2 == 0 then
				updateEndorse()
			end
		else
			beam.Enabled = false
			tutorial.Visible = false
		end
		if tick % 4 == 0 then
			refreshChip()
		end
		task.wait(0.25)
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
refresh()
refreshChip()
layout()
