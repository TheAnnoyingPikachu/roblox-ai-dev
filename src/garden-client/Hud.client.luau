--!strict
-- Egg Garden HUD (GDD H2, F, G1; docs/architecture/garden.md section 6): coins and income (short
-- format), level and XP bar, Index count, weather chip with the next two windows, restock and
-- next-ripe timers, quick buttons with the gold dots, HOME and LIKE, the "While you were away" card,
-- hatch announcement banners, first-session prompts with a guide beam, and per-viewer bed prompt
-- visibility. Sends only Request("home") and Request("like", userId); the server checks both.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local UI = ClientState.UI
local new, corner, stroke, text, button =
	ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text, ClientState.button
local short, commas = ClientState.short, ClientState.commas
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function ask(action: string, arg: string?): boolean
	local ok, result = pcall(request.InvokeServer, request, action, arg)
	return ok and result == true
end

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local gui = new("ScreenGui", {
	Name = "GardenHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 4,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })

local function chip(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UI.CREAM
	props.BackgroundTransparency = props.BackgroundTransparency or 0.05
	return new("Frame", props, { corner(16), stroke(UI.WHITE, 3) })
end

-- Coins (top centre) ------------------------------------------------------------------------------

local coinBox = chip({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(280, 74),
	Parent = hud,
})
ClientState.autoScale(coinBox)
local coinIcon = new("Frame", {
	Position = UDim2.fromOffset(12, 13),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = UI.GOLD,
	Parent = coinBox,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Color3.fromRGB(230, 150, 30), 3) })
text({
	Size = UDim2.fromScale(1, 1),
	Text = "C",
	TextColor3 = Color3.fromRGB(200, 120, 20),
	Parent = coinIcon,
})
local coinText = text({
	Position = UDim2.fromOffset(70, 4),
	Size = UDim2.new(1, -80, 0, 42),
	Text = "0",
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = coinBox,
})
local incomeText = text({
	Position = UDim2.fromOffset(70, 46),
	Size = UDim2.new(1, -80, 0, 22),
	Text = "+0 / s",
	TextColor3 = UI.LEAF,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = coinBox,
})

-- Level, XP, Index (top left) ---------------------------------------------------------------------

local levelBox = chip({ Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(230, 74), Parent = hud })
ClientState.autoScale(levelBox)
local levelBadge = text({
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(54, 54),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.PINK,
	TextColor3 = UI.WHITE,
	Text = "1",
	Parent = levelBox,
})
corner(27).Parent = levelBadge
local xpBack = new("Frame", {
	Position = UDim2.fromOffset(74, 14),
	Size = UDim2.fromOffset(144, 14),
	BackgroundColor3 = Color3.fromRGB(245, 225, 232),
	Parent = levelBox,
}, { corner(7) })
local xpFill = new(
	"Frame",
	{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.PINK, Parent = xpBack },
	{ corner(7) }
)
local xpText = text({
	Position = UDim2.fromOffset(74, 30),
	Size = UDim2.fromOffset(144, 16),
	Text = "",
	TextColor3 = UI.MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = levelBox,
})
local indexText = text({
	Position = UDim2.fromOffset(74, 48),
	Size = UDim2.fromOffset(144, 18),
	Text = "",
	TextColor3 = UI.LEAF,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = levelBox,
})

-- Weather, restock and ripe timers (top right) ----------------------------------------------------

local timers = chip({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(250, 128),
	Parent = hud,
})
ClientState.autoScale(timers)
local weatherBar = new("Frame", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 0, 40),
	BackgroundColor3 = UI.SKY,
	Parent = timers,
}, { corner(12) })
local weatherText = text({
	Position = UDim2.fromOffset(10, 2),
	Size = UDim2.new(1, -20, 0, 22),
	Text = "Clear",
	TextColor3 = UI.WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = weatherBar,
})
new("UIStroke", { Color = UI.INK, Thickness = 1, Transparency = 0.6, Parent = weatherText })
local weatherLeftText = text({
	Position = UDim2.fromOffset(10, 23),
	Size = UDim2.new(1, -20, 0, 15),
	Text = "",
	TextColor3 = UI.WHITE,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = weatherBar,
})
local function timerLine(y: number, colour: Color3): TextLabel
	return text({
		Position = UDim2.fromOffset(14, y),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		TextColor3 = colour,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = timers,
	})
end
local forecastText = timerLine(52, UI.MUTED)
local restockText = timerLine(76, UI.CORAL)
local ripeText = timerLine(100, UI.LEAF)

-- Quick buttons (left middle, clear of the thumbstick and jump button) ---------------------------

local quick = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(if touchOnly then 120 else 136, 384),
	BackgroundTransparency = 1,
	Parent = hud,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
ClientState.autoScale(quick)
local rewardsDot: Frame
local dashDot: Frame
local quickButtons: { [string]: TextButton } = {}
local function goldDot(parent: Instance): Frame
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = UI.GOLD,
		Visible = false,
		Parent = parent,
	}, { corner(8), stroke(UI.WHITE, 2) })
end
local QUICK = {
	{ "MENU", "Menu", UI.LILAC },
	{ "EGGS", "Eggs", UI.GOLD },
	{ "CREATURES", "Creatures", UI.SKY },
	{ "INDEX", "Index", UI.LEAF },
	{ "REWARDS", "Rewards", UI.CORAL },
	{ "DASH", "Dash", UI.AQUA },
	{ "HOME", "Home", UI.PINK },
}
if GardenConfig.ADMINS[player.UserId] then
	table.insert(QUICK, { "ADMIN", "Admin", UI.CORAL })
end
for i, item in QUICK do
	local b = button({
		Size = UDim2.new(1, 0, 0, 46),
		Text = item[1],
		BackgroundColor3 = item[3],
		TextColor3 = if item[3] == UI.GOLD then UI.INK else UI.WHITE,
		LayoutOrder = i,
		Parent = quick,
	}, function()
		if item[2] == "Menu" then
			ClientState.setMenu(true)
		elseif item[2] == "Home" then
			if not ask("home") then
				ClientState.toast("Could not go home right now", UI.CORAL)
			end
		else
			ClientState.open(item[2])
		end
	end)
	quickButtons[item[2]] = b
	if item[2] == "Rewards" then
		rewardsDot = goldDot(b)
	elseif item[2] == "Dash" then
		dashDot = goldDot(b)
	end
end

-- In a race only HOME stays (it leaves the round), and the race timer takes the coin bar's place.
ClientState.RacingChanged:Connect(function(racing: boolean)
	coinBox.Visible = not racing
	for name, b in quickButtons do
		b.Visible = name == "Home" or not racing
	end
end)

-- LIKE: shown inside another player's garden while their gate allows it.
local likeButton = button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, if touchOnly then -150 else -90),
	Size = UDim2.fromOffset(220, 54),
	Text = "LIKE GARDEN",
	BackgroundColor3 = UI.PINK,
	Visible = false,
	Parent = hud,
}, function() end)
ClientState.autoScale(likeButton)
local likeTarget: Player? = nil
likeButton.Activated:Connect(function()
	local target = likeTarget
	if target and ask("like", tostring(target.UserId)) then
		ClientState.toast(`You liked {target.DisplayName}'s garden!`, UI.PINK)
	end
end)

-- Profile-driven text -------------------------------------------------------------------------------

local profile: any = ClientState.profile()
local lastLevel: number? = nil
local lastCoins: number? = nil

local function refresh()
	profile = ClientState.profile()
	local coins = tonumber(player:GetAttribute("Coins")) or profile.coins
	coinText.Text = short(coins)
	if lastCoins and coins > lastCoins then
		ClientState.pop(coinText)
	end
	lastCoins = coins
	local income = tonumber(player:GetAttribute("Income")) or GardenRules.income(profile)
	incomeText.Text = `+{short(income)} / s`
	local level = GardenRules.level(profile)
	local from, to = MetaRules.xpForLevel(level), MetaRules.xpForLevel(level + 1)
	levelBadge.Text = tostring(level)
	local maxed = level >= MetaRules.MAX_LEVEL
	xpFill.Size = UDim2.fromScale(if maxed then 1 else (profile.xp - from) / math.max(1, to - from), 1)
	xpText.Text = if maxed then "MAX LEVEL" else `{commas(profile.xp - from)} / {commas(to - from)} XP`
	indexText.Text = `Index {#profile.index} / {GardenConfig.INDEX_SIZE}`
	rewardsDot.Visible = ClientState.rewardsReady(profile)
	dashDot.Visible = ClientState.prizeReady(profile)
	if lastLevel and level > lastLevel then
		ClientState.toast(`LEVEL UP! Level {level}`, UI.GOLD)
		ClientState.sound(ClientState.SFX.fanfare, 0.45)
		for _, egg in GardenConfig.EGGS do
			if egg.price and egg.level == level then
				ClientState.toast(`New egg at the cart: {egg.name}`, UI.LEAF)
			end
		end
	end
	lastLevel = level
end
player:GetAttributeChangedSignal("Profile"):Connect(refresh)
player:GetAttributeChangedSignal("Coins"):Connect(refresh)
player:GetAttributeChangedSignal("Income"):Connect(refresh)

-- Timers (1 Hz countdowns from GardenStatus and the profile) ---------------------------------------

local function refreshTimers()
	local status = ClientState.status()
	local now = ClientState.now()
	local w = status.weather
	weatherBar.BackgroundColor3 = ClientState.WEATHER_COLOURS[w] or UI.SKY
	weatherText.Text = ClientState.weatherName(w)
	local window = GardenConfig.WEATHER_WINDOW
	local nextStart = (math.floor(now / window) + 1) * window
	weatherLeftText.Text = if w ~= "clear"
		then `Ends in {ClientState.clock(ClientState.left(status.weatherLeft))}`
		else "Sunny skies"
	local f1, f2 = status.forecast[1] or "clear", status.forecast[2] or "clear"
	forecastText.Text =
		`Next: {ClientState.weatherName(f1)} in {ClientState.clock(nextStart - now)}, then {ClientState.weatherName(f2)}`
	restockText.Text = `Egg restock in {ClientState.clock(ClientState.left(status.stockLeft))}`
	local soonest: number? = nil
	local ripe = 0
	local t = math.floor(now)
	for i = 1, profile.bedCount do
		local state = GardenRules.bedState(profile, i, t)
		if state == "ripe" then
			ripe += 1
		elseif state == "growing" then
			local left = profile.beds[i].ready - now
			soonest = if soonest then math.min(soonest, left) else left
		end
	end
	ripeText.Text = if ripe > 0
		then `{ripe} egg{if ripe == 1 then "" else "s"} ready to hatch!`
		elseif soonest then `Next egg ripe in {ClientState.clock(soonest)}`
		else "Buy an egg at the cart"
end

-- Welcome back card ---------------------------------------------------------------------------------

local welcomeShown = false
local function welcome()
	local offline = tonumber(player:GetAttribute("OfflineCoins")) or 0
	if welcomeShown or offline <= 0 or ClientState.menuOpen then
		return
	end
	welcomeShown = true
	local shade = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(60, 40, 60),
		BackgroundTransparency = 0.5,
		ZIndex = 40,
		Parent = gui,
	})
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 250),
		BackgroundColor3 = UI.CREAM,
		Parent = shade,
	}, { corner(24), stroke(UI.GOLD, 4) })
	ClientState.autoScale(card)
	text({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 40),
		Text = "WELCOME BACK!",
		TextColor3 = UI.PINK,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 26),
		Text = "While you were away your creatures earned",
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.MUTED,
		Parent = card,
	})
	local amount = text({
		Position = UDim2.fromOffset(20, 92),
		Size = UDim2.new(1, -40, 0, 56),
		Text = `{commas(offline)} coins`,
		TextColor3 = Color3.fromRGB(230, 150, 30),
		Parent = card,
	})
	new("UIStroke", { Color = UI.WHITE, Thickness = 3, Parent = amount })
	local ok = button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(200, 54),
		Text = "COLLECT",
		BackgroundColor3 = UI.LEAF,
		Parent = card,
	}, function()
		ClientState.sound(ClientState.SFX.tick, 0.4, nil, 1.8)
		shade:Destroy()
	end)
	if UserInputService:GetLastInputType().Name:find("Gamepad") then
		GuiService.SelectedObject = ok
	end
	ClientState.pop(amount)
	ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
end
player:GetAttributeChangedSignal("OfflineCoins"):Connect(welcome)

-- Announcements and visitor toasts (Fx) -------------------------------------------------------------

local banner = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.fromOffset(560, 48),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.LILAC,
	TextColor3 = UI.WHITE,
	Text = "",
	Visible = false,
	Parent = hud,
})
corner(16).Parent = banner
stroke(UI.WHITE, 3).Parent = banner
new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = banner })
ClientState.autoScale(banner)
local bannerToken = 0

local function eggName(id: string): string
	local e = GardenConfig.egg(id)
	return if e then e.name else "egg"
end

local function displayName(userId: any): string
	local p = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	return if p then p.DisplayName else "A visitor"
end

-- Tutorial hooks set below.
local onCollect: () -> () = function() end

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "announce" and ClientState.settings.announcements then
		local m = GardenConfig.mutation(data.m)
		local z = GardenConfig.size(data.z)
		local sp = GardenConfig.species(data.s)
		local words = {}
		if z and data.z ~= "normal" then
			table.insert(words, string.upper(z.name))
		end
		if m and data.m ~= "normal" then
			table.insert(words, string.upper(m.name))
		end
		table.insert(words, if sp then sp.name else tostring(data.s))
		banner.Text = `{tostring(data.name)} hatched a {table.concat(words, " ")}!`
		local celestial = data.m == "celestial"
		banner.BackgroundColor3 = if celestial
			then ClientState.CELESTIAL
			else ClientState.rarityColour(tostring(data.s))
		banner.TextColor3 = if celestial then UI.INK else UI.WHITE
		banner.Visible = true
		bannerToken += 1
		local token = bannerToken
		task.delay(5, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	elseif kind == "water" and data.owner == player.UserId and data.by ~= player.UserId then
		local bed = profile.beds[tonumber(data.bed) or 0]
		ClientState.toast(`{displayName(data.by)} watered your {eggName(if bed then bed.egg else "")}!`, UI.SKY)
	elseif kind == "like" and data.owner == player.UserId then
		ClientState.toast(`{displayName(data.by)} liked your garden!`, UI.PINK)
	elseif kind == "collect" and data.owner == player.UserId then
		onCollect()
	end
end)

-- Friend cache for gate checks (IsFriendsWith yields, so it is filled in the background).
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

-- Per-viewer bed prompt visibility (4 Hz; the server still checks every trigger) --------------------

local function bedIndex(bed: Instance): number?
	return tonumber(bed.Name:match("^Bed(%d+)$"))
end

local function updatePrompts()
	local now = math.floor(ClientState.now())
	for n = 1, 6 do
		local model = ClientState.plotModel(n)
		local beds = model and model:FindFirstChild("Beds")
		if not beds then
			continue
		end
		local owner = ClientState.ownerOf(n)
		local p = ClientState.profileOf(owner)
		local mine = owner == player
		local allowed = mine
			or (owner ~= nil and GardenProgress.gateAllows(p and p.gate or "closed", isFriend(owner.UserId)))
		for _, bed in beds:GetChildren() do
			local i = bedIndex(bed)
			local soil = bed:FindFirstChild("Soil")
			if not (i and soil) then
				continue
			end
			for _, prompt in soil:GetChildren() do
				if prompt:IsA("ProximityPrompt") then
					local enabled = false
					if p and i <= p.bedCount then
						if prompt.Name == "Hatch" then
							enabled = mine and GardenRules.bedState(p, i, now) == "ripe" and not GardenRules.isFull(p)
						elseif prompt.Name == "Water" then
							enabled = allowed and GardenRules.canWater(p, i, now, not mine)
						end
					end
					if prompt.Enabled ~= enabled then
						prompt.Enabled = enabled
					end
				end
			end
		end
	end
end

local function updateLike()
	local r = root()
	local n = r and ClientState.plotAt(r.Position)
	local owner = n and ClientState.ownerOf(n)
	local p = ClientState.profileOf(owner)
	likeTarget = nil
	if owner and owner ~= player and p and GardenProgress.gateAllows(p.gate, isFriend(owner.UserId)) then
		local today = MetaRules.dayOf(ClientState.now())
		local liked = profile.liked.day == today and table.find(profile.liked.ids, owner.UserId) ~= nil
		likeTarget = if liked then nil else owner
		likeButton.Text = if liked then "LIKED TODAY" else `LIKE {string.upper(owner.DisplayName)}'S GARDEN`
		likeButton.BackgroundColor3 = if liked then UI.GREY else UI.PINK
		likeButton.Visible = true
	else
		likeButton.Visible = false
	end
end

-- First session (H2): one prompt at a time with a beam to its target --------------------------------

local tutorial = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, if touchOnly then -220 else -160),
	Size = UDim2.fromOffset(460, 56),
	BackgroundColor3 = UI.GOLD,
	Visible = false,
	Parent = hud,
}, { corner(20), stroke(UI.WHITE, 4) })
ClientState.autoScale(tutorial)
local tutorialText = text({
	Position = UDim2.fromOffset(16, 6),
	Size = UDim2.new(1, -32, 1, -12),
	Text = "",
	Parent = tutorial,
})

local cartMarker = new("Part", {
	Name = "CartGuide",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.one,
	Position = ClientState.CART + Vector3.new(0, 5, 0),
	Parent = Workspace,
})
local beam = new("Beam", {
	Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 150, 200)),
	Width0 = 1.2,
	Width1 = 1.2,
	FaceCamera = true,
	LightEmission = 0.6,
	Transparency = NumberSequence.new(0.2),
	TextureSpeed = 1,
	Enabled = false,
	Parent = Workspace.Terrain,
})
local beamEnd = new("Attachment", { Parent = Workspace.Terrain })
local beamStart = new("Attachment", { Parent = Workspace.Terrain })
beam.Attachment0 = beamStart
beam.Attachment1 = beamEnd
local marker = new("BillboardGui", {
	Size = UDim2.fromOffset(110, 44),
	StudsOffset = Vector3.new(0, 5, 0),
	AlwaysOnTop = true,
	Enabled = false,
	Parent = Workspace.Terrain,
})
local markerText = text({
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.PINK,
	TextColor3 = UI.WHITE,
	Text = "HERE",
	Parent = marker,
})
corner(14).Parent = markerText
stroke(UI.WHITE, 3).Parent = markerText

local function plotPart(path: { string }): BasePart?
	local plot = player:GetAttribute("Plot")
	local node: Instance? = if type(plot) == "number" then ClientState.plotModel(plot) else nil
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local collected = false
onCollect = function()
	collected = true
end

-- Bed holding the first bought Meadow Egg (followed by the water and hatch steps).
local function meadowBed(): number?
	for i, b in profile.beds do
		if b.egg == "meadow" then
			return i
		end
	end
	return nil
end

local watchedBed: number? = nil
type Step = { text: string, done: () -> boolean, target: () -> BasePart? }
local STEPS: { Step } = {
	{
		text = "Your egg is ready! Hatch it",
		done = function()
			return profile.hatches >= 1
		end,
		target = function()
			return plotPart({ "Beds", "Bed1", "Soil" })
		end,
	},
	{
		text = "Walk over the pad to collect coins",
		done = function()
			return collected
		end,
		target = function()
			local c = profile.creatures[1]
			return plotPart({ "Pads", `Pad{if c and c.placed > 0 then c.placed else 1}` })
		end,
	},
	{
		text = "Visit the Egg Cart",
		done = function()
			local r = root()
			return r ~= nil and (Vector3.new(r.Position.X, 0, r.Position.Z) - ClientState.CART).Magnitude <= 25
		end,
		target = function()
			return cartMarker
		end,
	},
	{
		text = "Buy a Meadow Egg",
		done = function()
			watchedBed = meadowBed() or watchedBed
			return watchedBed ~= nil or profile.hatches >= 2
		end,
		target = function()
			return cartMarker
		end,
	},
	{
		text = "Water your egg",
		done = function()
			return profile.waters >= 1 or profile.hatches >= 2
		end,
		target = function()
			return plotPart({ "Beds", `Bed{watchedBed or 1}`, "Soil" })
		end,
	},
	{
		text = "Hatch it when it's ripe!",
		done = function()
			return profile.hatches >= 2
		end,
		target = function()
			return plotPart({ "Beds", `Bed{watchedBed or 1}`, "Soil" })
		end,
	},
}
local step = 0 -- 0 until the profile arrives; past #STEPS when finished or not a first session

local function updateTutorial()
	if step == 0 then
		if type(player:GetAttribute("Profile")) ~= "string" then
			return
		end
		step = if profile.hatches == 0 then 1 else #STEPS + 1
	end
	while STEPS[step] and STEPS[step].done() do
		step += 1
		ClientState.sound(ClientState.SFX.tick, 0.3, nil, 1.6)
	end
	local s = STEPS[step]
	local r = root()
	local target = s and s.target()
	tutorial.Visible = s ~= nil
	beam.Enabled = s ~= nil and target ~= nil and r ~= nil
	marker.Enabled = beam.Enabled
	if s then
		tutorialText.Text = s.text
	end
	if beam.Enabled and target and r then
		beamStart.WorldPosition = r.Position - Vector3.new(0, 2, 0)
		beamEnd.WorldPosition = target.Position + Vector3.new(0, 1, 0)
		marker.Adornee = target
	end
end

-- Loops ---------------------------------------------------------------------------------------------

ClientState.MenuChanged:Connect(function(open: boolean)
	hud.Visible = not open
	if not open then
		welcome()
	end
end)

task.spawn(function()
	local tick = 0
	while true do
		tick += 1
		updatePrompts()
		if hud.Visible and not ClientState.racing then
			updateTutorial()
			updateLike()
			markerText.Position = UDim2.fromOffset(0, math.sin(os.clock() * 4) * 4)
		else
			tutorial.Visible = false
			beam.Enabled = false
			marker.Enabled = false
		end
		if tick % 4 == 0 then
			refreshTimers()
		end
		task.wait(0.25)
	end
end)

TweenService:Create(coinIcon, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Rotation = 8,
}):Play()

gui.Parent = player:WaitForChild("PlayerGui")
refresh()
refreshTimers()
