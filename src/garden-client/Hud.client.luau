--!strict
-- Egg Garden HUD (GDD H2, F, G1, X1.4; docs/architecture/garden.md 6, 6.4) on the UI kit: the coin
-- pill with the +N float, the level ring and XP bar with the Index count, the weather chip with its
-- next two windows, the weekend event, restock and next-ripe chips, the left icon strip with badges
-- (REWARDS: login slots + quests + a milestone; DASH: prize eggs; CREATURES: a trade invite; INDEX:
-- a milestone), LIKE and TRADE, the "While you were away" card, hatch announcement banners,
-- first-session prompts with a guide beam, and per-viewer bed prompt visibility. Sends only
-- Request("home"), Request("like", userId) and Request("tradePropose", userId); the server checks all
-- three.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local UI = ClientState.UI
local ACCENT = ClientState.ACCENT
local new, text = ClientState.new, UiKit.text
local commas = ClientState.commas

local function ask(action: string, arg: string?): boolean
	local ok, result = pcall(request.InvokeServer, request, action, arg)
	return ok and result == true
end

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Below the Roblox top bar, so the coin pill never sits under its buttons.
local gui = new("ScreenGui", {
	Name = "GardenHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 4,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
UiKit.scaleRoot(gui)
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })

-- Top bar: coins, level ring, XP and the Index count (top left) -------------------------------------

local coinPill = UiKit.coinPill(hud)
local ring = UiKit.levelRing(hud)
local indexText = text(hud, "", 18, UI.INK, { -- INK: LEAF over the world was 2.9:1 (QA M2)
	Position = UDim2.fromOffset(396, 70),
	Size = UDim2.fromOffset(200, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	Outline = UI.WHITE,
	OutlineThickness = 1.5,
})

-- Weather, event, restock and ripe chips (top right) ----------------------------------------------

local chips = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 20),
	Size = UDim2.fromOffset(330, 320),
	BackgroundTransparency = 1,
	Parent = hud,
}, {
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local weatherChip = UiKit.chip(chips, 330, 64)
weatherChip.LayoutOrder = 1
local weatherDisc = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = UI.SKY,
	Parent = weatherChip,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local weatherText = UiKit.chipText(weatherChip, "Clear", {
	Position = UDim2.fromOffset(64, 4),
	Size = UDim2.new(1, -74, 0, 32),
	TextSize = 26,
})
local weatherLeftText = UiKit.chipText(weatherChip, "", {
	Position = UDim2.fromOffset(64, 36),
	Size = UDim2.new(1, -74, 0, 22),
	TextSize = 16,
})
-- Every chip line is INK on the glass (QA m1: coloured text was 1.5 to 2.5:1); its colour is a dot.
-- 48 high, so the forecast still fits on two lines at 12 px on a phone (QA M2).
local function line(order: number, colour: Color3): TextLabel
	local chip = UiKit.chip(chips, 330, 48)
	chip.LayoutOrder = order
	new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = colour,
		Parent = chip,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = UI.WHITE, Thickness = 1.5 }) })
	return UiKit.chipText(chip, "", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -44, 1, 0) })
end
local forecastText = line(2, UI.SKY)
local eventText = line(3, UI.LILAC) -- "This weekend: Thunder" (V2.3)
local restockText = line(4, UI.CORAL)
local ripeText = line(5, UI.LEAF)

-- The left strip --------------------------------------------------------------------------------------

local touch = UiKit.touch()
local items: { UiKit.StripItem } = {
	{
		icon = "egg",
		label = "EGGS",
		colour = ACCENT.Eggs,
		main = true,
		onClick = function()
			ClientState.open("Eggs")
		end,
	},
	{
		icon = "paw",
		label = "PETS",
		colour = ACCENT.Creatures,
		main = true,
		onClick = function()
			ClientState.open("Creatures")
		end,
	},
	{
		icon = "book",
		label = "INDEX",
		colour = ACCENT.Index,
		onClick = function()
			ClientState.open("Index")
		end,
	},
	{
		icon = "gift",
		label = "REWARDS",
		colour = ACCENT.Rewards,
		main = true,
		onClick = function()
			ClientState.open("Rewards")
		end,
	},
	{
		icon = "flag",
		label = "DASH",
		colour = ACCENT.Dash,
		onClick = function()
			ClientState.open("Dash")
		end,
	},
}
if GardenConfig.WHEEL then
	table.insert(items, {
		icon = "petal",
		label = "PATCH",
		colour = ACCENT.Patch,
		onClick = function()
			ClientState.open("Patch")
		end,
	})
end
table.insert(items, {
	icon = "hanger",
	label = "LOCKER",
	colour = ACCENT.Locker,
	onClick = function()
		ClientState.open("Locker")
	end,
})
table.insert(items, {
	icon = "home",
	label = "HOME",
	colour = UI.MINT,
	main = true,
	onClick = function()
		if not ask("home") then
			ClientState.toast("Could not go home right now", UI.CORAL, "home")
		end
	end,
})
if GardenConfig.ADMINS[player.UserId] then
	table.insert(items, {
		icon = "lock",
		label = "ADMIN",
		colour = ACCENT.Admin,
		onClick = function()
			ClientState.open("Admin")
		end,
	})
end
table.insert(items, {
	icon = "cog",
	label = "MENU",
	colour = UI.LILAC,
	onClick = function()
		ClientState.setMenu(true)
	end,
})
local strip = UiKit.strip(hud, items, touch)

local function badge(name: string, count: number?)
	local b = strip[name]
	if b and b:GetAttribute("Badge") ~= count then
		UiKit.setBadge(b, count)
	end
end

-- A milestone can be claimed (V4).
local function milestoneReady(p: any): boolean
	for _, m in GardenConfig.MILESTONES do
		if #p.index >= m.at and p.milestones[tostring(m.at)] ~= true then
			return true
		end
	end
	return false
end

-- An incoming trade invite (V1): the CREATURES dot.
local function inviteDot()
	local t = ClientState.tradeState
	local invited = t ~= nil and t.state == "proposed" and type(t.b) == "table" and t.b.user == player.UserId
	badge("PETS", if invited then 0 else nil)
end
ClientState.TradeChanged:Connect(inviteDot)

-- In a race only HOME stays (it leaves the round), and the race timer takes the coin pill's place.
ClientState.RacingChanged:Connect(function(racing: boolean)
	for _, name in { "CoinPill", "LevelRing" } do
		local f = hud:FindFirstChild(name)
		if f then
			(f :: GuiObject).Visible = not racing
		end
	end
	for name, b in strip do
		b.Visible = name == "HOME" or not racing
	end
	local sheet = hud:FindFirstChild("MoreSheet")
	if sheet and racing then
		(sheet :: GuiObject).Visible = false
	end
end)

-- LIKE and TRADE, side by side at the bottom centre --------------------------------------------------

-- LIKE: shown inside another player's garden while their gate allows it.
local likeTarget: Player? = nil
local likeButton = UiKit.button(hud, "LIKE GARDEN", UI.PINK, "large", 340, function()
	local target = likeTarget
	if target and ask("like", tostring(target.UserId)) then
		ClientState.toast(`You liked {target.DisplayName}'s garden!`, UI.PINK, "heart")
	end
end)
likeButton.AnchorPoint = Vector2.new(1, 1)
likeButton.Position = UDim2.new(0.5, -8, 1, -30)
likeButton.Visible = false

-- TRADE: the nearest Roblox friend within TRADE.range, while no trade is live and the setting is on (V1).
local tradeTarget: Player? = nil
local tradeButton = UiKit.button(hud, "TRADE", UI.AQUA, "large", 340, function()
	local target = tradeTarget
	if target and not ask("tradePropose", tostring(target.UserId)) then
		ClientState.toast("Could not ask for a trade right now", UI.CORAL, "swap")
	end
end)
tradeButton.AnchorPoint = Vector2.new(0, 1)
tradeButton.Position = UDim2.new(0.5, 8, 1, -30)
tradeButton.Visible = false

-- Profile-driven text -------------------------------------------------------------------------------

local profile: any = ClientState.profile()
local lastLevel: number? = nil
local lastCoins: number? = nil

local function refresh()
	profile = ClientState.profile()
	local coins = tonumber(player:GetAttribute("Coins")) or profile.coins
	local income = tonumber(player:GetAttribute("Income")) or GardenRules.income(profile)
	coinPill.set(coins, income)
	if lastCoins and coins > lastCoins then
		coinPill.gain(coins - lastCoins)
	end
	lastCoins = coins
	local level = GardenRules.level(profile)
	local from, to = MetaRules.xpForLevel(level), MetaRules.xpForLevel(level + 1)
	local maxed = level >= MetaRules.MAX_LEVEL
	ring.set(
		level,
		if maxed then 1 else (profile.xp - from) / math.max(1, to - from),
		if maxed then "MAX LEVEL" else `{commas(profile.xp - from)} / {commas(to - from)} XP`
	)
	indexText.Text = `Index {#profile.index} / {GardenConfig.INDEX_SIZE}`
	local loaded = type(player:GetAttribute("Profile")) == "string"
	local milestone = loaded and milestoneReady(profile)
	local rewards = if loaded then ClientState.rewardsCount(profile) + (if milestone then 1 else 0) else 0
	local prizes = if loaded then ClientState.prizeCount(profile) else 0
	badge("REWARDS", if rewards > 0 then rewards else nil)
	badge("DASH", if prizes > 0 then prizes else nil)
	badge("INDEX", if milestone then 0 else nil)
	if lastLevel and level > lastLevel then
		ClientState.toast(`LEVEL UP! Level {level}`, UI.GOLD, "chart")
		ClientState.sound(ClientState.SFX.fanfare, 0.45)
		for _, egg in GardenConfig.EGGS do
			if egg.price and egg.level == level then
				ClientState.toast(`New egg at the cart: {egg.name}`, UI.LEAF, "egg")
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
	weatherDisc.BackgroundColor3 = ClientState.WEATHER_COLOURS[w] or UI.SKY
	weatherText.Text = ClientState.weatherName(w)
	local window = GardenConfig.WEATHER_WINDOW
	local nextStart = (math.floor(now / window) + 1) * window
	weatherLeftText.Text = if w ~= "clear"
		then `Ends in {ClientState.clock(ClientState.left(status.weatherLeft))}`
		else "Sunny skies"
	local f1, f2 = status.forecast[1] or "clear", status.forecast[2] or "clear"
	forecastText.Text =
		`Next: {ClientState.weatherName(f1)} in {ClientState.clock(nextStart - now)}, then {ClientState.weatherName(f2)}`
	local event = ClientState.weatherName(status.event.weather)
	eventText.Text = if status.event.active then `{event} weekend!` else `This weekend: {event}`
	local dot = eventText.Parent and eventText.Parent:FindFirstChild("Dot") :: Frame?
	if dot then
		dot.BackgroundColor3 = ClientState.WEATHER_COLOURS[status.event.weather] or UI.LILAC
	end
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
	local card = UiKit.modal(gui, "WELCOME BACK!", UI.GOLD, 600, 360)
	text(card.body, "While you were away your creatures earned", 22, UI.INK_SOFT, {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
	})
	local amount = text(card.body, `{commas(offline)} coins`, 56, UI.GOLD, {
		Size = UDim2.new(1, 0, 0, 66),
		LayoutOrder = 2,
		Outline = UI.INK,
		OutlineThickness = 2.5,
	})
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = card.body,
	})
	local ok = UiKit.button(holder, "COLLECT", UI.LEAF, "large", 260, function()
		ClientState.sound(ClientState.SFX.tick, 0.4, nil, 1.8)
		card.close()
	end)
	ok.AnchorPoint = Vector2.new(0.5, 0)
	ok.Position = UDim2.new(0.5, 0, 0, 4)
	UiKit.selectFirst(card.frame)
	ClientState.pop(amount)
	ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
end
player:GetAttributeChangedSignal("OfflineCoins"):Connect(welcome)

-- Announcements and visitor toasts (Fx) -------------------------------------------------------------

local banner = UiKit.row(hud, 56, 0)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 180)
banner.Size = UDim2.fromOffset(640, 56)
banner.Visible = false
local bannerText = text(banner, "", 26, UI.WHITE, {
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -32, 1, 0),
	Outline = UI.INK,
	OutlineThickness = 2,
})
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
		local charm = GardenConfig.charm(tostring(data.c))
		local words = {}
		if charm then
			table.insert(words, string.upper(charm.name))
		end
		if z and data.z ~= "normal" then
			table.insert(words, string.upper(z.name))
		end
		if m and data.m ~= "normal" then
			table.insert(words, string.upper(m.name))
		end
		table.insert(words, if sp then sp.name else tostring(data.s))
		bannerText.Text = `{tostring(data.name)} hatched a {table.concat(words, " ")}!`
		local celestial = data.m == "celestial"
		banner.BackgroundColor3 = if celestial
			then ClientState.CELESTIAL
			else ClientState.rarityColour(tostring(data.s))
		bannerText.TextColor3 = if celestial then UI.INK else UI.WHITE
		banner.Visible = true
		ClientState.pop(banner)
		bannerToken += 1
		local token = bannerToken
		task.delay(5, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	elseif kind == "water" and data.owner == player.UserId and data.by ~= player.UserId then
		local bed = profile.beds[tonumber(data.bed) or 0]
		ClientState.toast(`{displayName(data.by)} watered your {eggName(if bed then bed.egg else "")}!`, UI.SKY, "egg")
	elseif kind == "like" and data.owner == player.UserId then
		ClientState.toast(`{displayName(data.by)} liked your garden!`, UI.PINK, "heart")
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

local function updateTrade()
	local r = root()
	tradeTarget = nil
	if r and ClientState.settings.trades and ClientState.tradeState == nil then
		local best: Player? = nil
		local bestD = GardenConfig.TRADE.range
		for _, other in Players:GetPlayers() do
			local orr = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if orr and orr:IsA("BasePart") and isFriend(other.UserId) then
				local d = (Vector3.new(orr.Position.X, 0, orr.Position.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude
				if d <= bestD then
					best, bestD = other, d
				end
			end
		end
		tradeTarget = best
	end
	tradeButton.Visible = tradeTarget ~= nil
	if tradeTarget then
		tradeButton.Text = `TRADE WITH {string.upper(tradeTarget.DisplayName)}`
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
		UiKit.setEnabled(likeButton, not liked)
		likeButton.Visible = true
	else
		likeButton.Visible = false
	end
end

-- First session (H2): one prompt at a time with a beam to its target --------------------------------

local tutorial = UiKit.row(hud, 64, 0)
tutorial.AnchorPoint = Vector2.new(0.5, 0)
tutorial.Position = UDim2.new(0.5, 0, 0, 104)
tutorial.Size = UDim2.fromOffset(560, 64)
tutorial.BackgroundColor3 = UI.GOLD
tutorial.Visible = false
local tutorialText = text(tutorial, "", 28, UI.WHITE, {
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -32, 1, 0),
	Outline = UI.INK,
	OutlineThickness = 2,
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
local markerText = ClientState.text({
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.PINK,
	TextColor3 = UI.WHITE,
	Text = "HERE",
	Parent = marker,
})
ClientState.corner(14).Parent = markerText
ClientState.stroke(UI.WHITE, 3).Parent = markerText

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
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(hud) then
		GuiService.SelectedObject = nil
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
			updateTrade()
			markerText.Position = UDim2.fromOffset(0, math.sin(os.clock() * 4) * 4)
		else
			tutorial.Visible = false
			beam.Enabled = false
			marker.Enabled = false
			tradeButton.Visible = false
		end
		if tick % 4 == 0 then
			refreshTimers()
		end
		task.wait(0.25)
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
refresh()
refreshTimers()
