--!strict
-- Animal Stations HUD (decisions 0025, 0029, 0036, 0043, 0044): one scaled root frame holds a player
-- card (level, XP, coins, samples), a bottom bar with three buttons (Animals, Eggs, Waves) and a
-- set of full-screen sheets, each opened from the bar or from a prompt in the world: Animals (a card
-- with a portrait, six stat buttons and a team button for each), Eggs (storage and hatching),
-- Ranch (upgrades, at the Ranch House door), Egg vendor, Wave gate and the admin menu. The layout is
-- written in design units and scaled to the screen (UiLayout.scale), so phones and tablets get the
-- same screens as a desktop.
-- Display only: every button names an action; the server decides everything and sends the new
-- profile. Training progress between profiles is a local preview with the same pure rules.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local FightFx = require(Shared:WaitForChild("FightFx"))
local WaveRuns = require(Shared:WaitForChild("WaveRuns"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationRewards = require(Shared:WaitForChild("StationRewards"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local UiLayout = require(Shared:WaitForChild("UiLayout"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

Ui.setTheme({ -- the Savanna look (decision 0091) for the kit's panels and labels
	font = Enum.Font.FredokaOne,
	accent = Style.C.accent,
	accentText = Style.C.ink,
	text = Style.C.ink,
	muted = Style.C.muted,
	panel = Style.C.sand,
	panelTransparency = 0,
	danger = Style.C.bad,
})

local C = Style.C
local RARITY_COLOUR = Style.RARITY
local RANK: { [string]: number } =
	{ common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6, divine = 7, celestial = 8, secret = 9 }
local ROLE_NAME: { [string]: string } = { attack = "Attack", defense = "Defence", utility = "Utility", titan = "TITAN" }
local GROUP_NAME: { [string]: string } = { pack = "Pack", solitary = "Solitary" }
local STAT_SHORT: { [string]: string } =
	{ speed = "SPD", strength = "STR", stamina = "STA", mana = "MANA", health = "HP", defence = "DEF" }
local RAINBOW = ColorSequence.new({ -- the chip of an animal in a rainbow coat (decision 0058)
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 225, 100)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 235, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 140, 255)),
})

local REFUSED: { [string]: string } = {
	claimed = "You've already claimed that one",
	not_yet = "Log in on more days to claim that",
	spun = "You've had today's spin: come back tomorrow",
	reward = "That reward does not exist",
	coins = "Not enough coins",
	trade_unknown = "That animal is not yours any more",
	trade_training = "That animal is training: stop it first",
	trade_max = "At most 4 animals in one trade",
	trade_full = "No room in a barn for that trade: upgrade the Barn",
	trade_nobody = "That player is not here",
	trade_busy = "One of you is already trading",
	trade_expired = "That trade request ran out",
	trade_none = "No trade is open",
	trade_empty = "Put an animal in the trade first",
	trade_level = `Trading opens at player level {StationTrade.MIN_LEVEL}`,
	trade_their_level = `That player can't trade yet (level {StationTrade.MIN_LEVEL})`,
	trade_limit = `You've done your {StationTrade.PER_DAY} trades today: more tomorrow`,
	trade_locked = "That animal is locked: unlock it in Animals first",
	trade_wait = "Look the trade over first: it opens in a moment",
	trade_confirming = "The trade is locked: confirm it or cancel",
	trade_off = "That player isn't taking trade requests",
	trade_ask_wait = "Give them a few seconds before asking again",
	trade_saving = "Trading needs saving on for both of you",
	trade_store = "Trading couldn't save just now: try again",
	locked = "Clear more waves to unlock that egg",
	full = "Your barn is full: upgrade the Barn at your ranch",
	samples = "Not enough samples",
	admin = "Admins only",
	eggs_full = "Your egg storage is full: upgrade the Egg Storage",
	nests_full = "Every nest is taken: upgrade the Hatchery",
	no_mill = "Build the Windmill first",
	mill_empty = "The windmill has no coins for you yet",
	not_ready = "That egg is not ready yet",
	hatching = "That egg is already hatching",
	top = "That is already at its top level",
	team_full = "Your team is full (3)",
	train_full = "Every training place is taken: upgrade the Ranch House",
	station_busy = "Another animal is training there: stop it first",
	training = "Stop its training first",
	maxed = `That stat is already level {StationConfig.MAX_LEVEL}`,
	loading = "Still loading your ranch...",
	rate = "Slow down a little",
	wave = "That wave is not open yet: clear the one before it",
	no_team = "Put an animal on your team first",
	busy = "The arena is busy: try again in a moment",
	field = "A fight is on: wait in the wave portal to join its next wave",
	arena = "The arena is not ready",
	ranch = "You have no ranch yet",
	shield = "Nothing to shield from right now",
	shield_wait = "Your shield is still recharging",
	boon = "Pick one of the three boons",
	no_fight = "No fight is on",
}

local player = Players.LocalPlayer
local screen = Ui.screen("StationsHud")
local profile: any = nil
local tickers: { () -> () } = {} -- refresh the live text of every stat being trained
local eggTickers: { () -> () } = {} -- and of every egg hatching

-- The root: a frame the size of the screen in design units, scaled up or down to fit it. The
-- "UiSize" attribute of the player (a Vector2) stands in for the screen: a way to look at the
-- layout of a phone or a tablet on a desktop.
local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.AnchorPoint, root.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
root.Parent = screen
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fit()
	local size = screen.AbsoluteSize
	local forced = player:GetAttribute("UiSize")
	if typeof(forced) == "Vector2" then
		size = forced
	end
	local s = UiLayout.scale(size.X, size.Y)
	uiScale.Scale = s
	root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
player:GetAttributeChangedSignal("UiSize"):Connect(fit)
fit()

local function send(action: string, ...: any): boolean
	local ok, code = request:InvokeServer(action, ...)
	if not ok and code then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
	end
	return ok == true
end

local function nameOf(a: any): string
	local sp = StationConfig.species(a.s)
	local va = a.v and StationConfig.variant(a.s, a.v)
	return if va then va.name elseif sp then sp.name else a.s
end

-- `a` as it is right now: a training animal with the time since its last settle added (preview).
local function live(a: any): any
	if a.at == nil or a.since == nil then
		return a
	end
	return StationRules.train(a, a.at, StationProgress.trainedBetween(profile, a.since, Workspace:GetServerTimeNow()))
end

-- Two lines for a stat button: the stat's level out of 70, then its battle value ("SPD 7/70"
-- over "46"), with the time left to the next level while training ("46  12m"), or MAX.
local function statText(a: any, stat: string, training: boolean): string
	local level = StationRules.level(a, stat :: any)
	local head = `{STAT_SHORT[stat]} {level}/{StationConfig.MAX_LEVEL}`
	local value = StationRules.stat(a, stat :: any)
	if level >= StationConfig.MAX_LEVEL then
		return `{head}\n{value}  MAX`
	elseif training then
		local progress = if a.trained then a.trained[stat] - level else 0
		local left = (1 - progress)
			* StationRules.levelSeconds(level + 1)
			* 100
			/ StationProgress.value(profile, "grounds")
		return `{head}\n{value}   {Format.ago(left)}`
	end
	return `{head}\n{value}`
end

-- The sheets and the bottom bar ---------------------------------------------------------------------

local sheets: { [string]: Style.Sheet } = {}
local redraw: { [string]: () -> () } = {}
local openName: string? = nil
local nav = Instance.new("Frame") -- the side dock, hidden while a sheet is open

local function show(name: string?)
	if name and name ~= openName and sheets[name] then
		Style.pop(sheets[name])
	end
	openName = name
	for n, sh in sheets do
		sh.backdrop.Visible = n == name
	end
	nav.Visible = name == nil
	if name and redraw[name] and profile then
		redraw[name]()
	end
end

local function newSheet(name: string, heading: string): Style.Sheet
	local sh = Style.sheet(root, name, heading, function()
		show(nil)
	end)
	Portrait.keepCulled(sh.body)
	sheets[name] = sh
	return sh
end

local animals = newSheet("animals", "Your animals")
local eggs = newSheet("eggs", "Eggs")
local ranch = newSheet("ranch", "Your ranch")
local shop = newSheet("shop", "Egg vendor")
local waves = newSheet("waves", "Endless waves")
local admin = newSheet("admin", "Admin")
local trade = newSheet("trade", "Trade")
local gifts = newSheet("gifts", "Gifts")
local ranchTab = "animals" -- the group of upgrades the Ranch menu shows
for _, sh in sheets do
	Style.list(sh.body, 10, true, true)
end

-- Player card, top left
local top = Style.card(root, UDim2.fromOffset(266, 86))
top.Position = UDim2.fromOffset(12, 12)
local badge = Style.frame(top, UDim2.fromOffset(56, 56), C.accent)
badge.Position = UDim2.fromOffset(10, 15)
Style.round(badge, 28)
Style.stroke(badge, C.panel, 3)
local badgeText = Style.text(badge, "1", 28, C.accentText, UDim2.fromScale(1, 1))
badgeText.TextXAlignment = Enum.TextXAlignment.Center
local levelText = Style.text(top, "Level 1", 20, C.text, UDim2.new(1, -86, 0, 22))
levelText.Position = UDim2.fromOffset(76, 8)
local xpText = Style.text(top, "", 13, C.muted, UDim2.new(1, -86, 0, 22))
xpText.Position = UDim2.fromOffset(76, 10)
xpText.TextXAlignment = Enum.TextXAlignment.Right
local xpBar, setXp = Style.bar(top, UDim2.new(1, -86, 0, 10), C.info)
xpBar.Position = UDim2.fromOffset(76, 34)
local wallet = Instance.new("Frame")
wallet.BackgroundTransparency = 1
wallet.Position, wallet.Size = UDim2.fromOffset(76, 52), UDim2.new(1, -86, 0, 26)
Style.list(wallet, 14, true)
wallet.Parent = top
local _, coinsText = Style.amount(wallet, "coins", "0")
local _, samplesText = Style.amount(wallet, "samples", "0")

-- The side dock (decision 0093): a small Menu button on the left edge slides a column of big buttons out
-- from it: Travel (a pop-out with the hub, your ranch and the wave arena; no teleport pads), Animals,
-- Eggs, Waves and Trade. The whole dock hides while a menu is open.
nav.Name = "Nav"
nav.BackgroundTransparency = 1
nav.Position, nav.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
nav.Parent = root

-- One column of five 56-unit buttons; on a short screen (a phone held sideways) two columns of three.
local DOCK_X, CELL_W, CELL_H, GAP = 14, 112, 56, 10
local dock = Style.panel(nav, UDim2.fromOffset(0, 0))
local column = Instance.new("Frame")
column.BackgroundTransparency = 1
column.Position, column.Size = UDim2.fromOffset(10, 12), UDim2.new(1, -20, 1, -26)
local dockGrid = Instance.new("UIGridLayout")
dockGrid.CellSize, dockGrid.CellPadding = UDim2.fromOffset(CELL_W, CELL_H), UDim2.fromOffset(GAP, GAP)
dockGrid.SortOrder = Enum.SortOrder.LayoutOrder
dockGrid.Parent = column
column.Parent = dock
local DOCK_W = CELL_W + 20
local function shape()
	local cols = if root.Size.Y.Offset < 560 then 2 else 1
	local rows = math.ceil(6 / cols)
	DOCK_W = cols * CELL_W + (cols - 1) * GAP + 20
	dock.Size = UDim2.fromOffset(DOCK_W, rows * CELL_H + (rows - 1) * GAP + 28)
	dockGrid.FillDirectionMaxCells = cols
end
shape()
root:GetPropertyChangedSignal("Size"):Connect(shape)
dock.Position = UDim2.fromOffset(-DOCK_W - 20, 160)

local open = false
local menuButton: TextButton -- below
local function slide(to: boolean)
	open = to
	TweenService:Create(
		dock,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(if open then DOCK_X else -DOCK_W - 20, 160) }
	):Play()
	menuButton.Text = if open then "◀ Menu" else "Menu ▶"
end
menuButton = Style.button(nav, "Menu ▶", function()
	slide(not open)
end, "primary", UDim2.fromOffset(CELL_W + 20, 46))
menuButton.Position, menuButton.TextSize = UDim2.fromOffset(DOCK_X, 104), 20
menuButton:SetAttribute("Sound", "tab")
local menuDot = Style.dot(menuButton, "")
menuDot.Visible = false

local hideResult: () -> () = function() end -- set once the fight panel exists
local dots: { TextLabel } = {}
local function dockButton(label: string, kind: string, order: number, onClick: () -> ()): TextLabel
	local b = Style.button(column, label, onClick, kind)
	b.LayoutOrder, b.TextSize = order, 21
	local dot = Style.dot(b, "")
	dot.Visible = false
	dot:GetPropertyChangedSignal("Visible"):Connect(function() -- the Menu button shows a dot while any does
		local any = false
		for _, d in dots do
			any = any or d.Visible
		end
		menuDot.Visible = any
	end)
	table.insert(dots, dot)
	return dot
end

-- Travel: a pop-out beside the dock
local travel = Style.panel(nav, UDim2.fromOffset(196, 214))
travel.Position, travel.Visible = UDim2.fromOffset(DOCK_X + DOCK_W + 12, 160), false
local places = Instance.new("Frame")
places.BackgroundTransparency = 1
places.Position, places.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -24, 1, -20)
Style.list(places, 10)
places.Parent = travel
Style.text(places, "Go to…", 20, C.text, UDim2.new(1, 0, 0, 26))
local function travelTo(action: string, ...: any)
	travel.Visible = false
	local ok, code = request:InvokeServer(action, ...)
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
	else
		show(nil)
		hideResult()
	end
end
for k, p in
	{
		{ "The hub", "info", "travel", "hub" },
		{ "My ranch", "good", "home" },
		{ "Wave arena", "danger", "travel", "arena" },
	}
do
	local b = Style.button(places, p[1], function()
		travelTo(p[3], p[4])
	end, p[2], UDim2.new(1, 0, 0, 44))
	b.LayoutOrder = k + 1
end

dockButton("Travel", "info", 1, function()
	travel.Position = UDim2.fromOffset(DOCK_X + DOCK_W + 12, 160)
	travel.Visible = not travel.Visible
end)
dockButton("Animals", "good", 2, function()
	show("animals")
end)
local eggsDot = dockButton("Eggs", "ghost", 3, function()
	show("eggs")
end)
local openWaves: () -> () -- below, with the wave sheet
dockButton("Waves", "danger", 4, function()
	openWaves()
end)
local tradeDot = dockButton("Trade", "primary", 5, function()
	show("trade")
end)
local giftsDot = dockButton("Gifts", "good", 6, function()
	request:InvokeServer("rewards") -- count today first
	show("gifts")
end)
nav:GetPropertyChangedSignal("Visible"):Connect(function()
	travel.Visible = false
end)

-- Admin button, top right: only for players the server marks as admin (decision 0038)
local adminToggle = Style.button(root, "Admin", function()
	show(if openName == "admin" then nil else "admin")
end, "ghost", UDim2.fromOffset(84, 40))
adminToggle.AnchorPoint, adminToggle.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 12)
adminToggle.TextSize = 16
-- Animals (decision 0091) ---------------------------------------------------------------------------
-- Tabs filter one grid of small cards: a portrait, the name, the two best stats and a rarity band.
-- Tapping a card opens its detail in the same menu: six stat tiles (tap to train or stop) and the team.

local function darker(colour: Color3): Color3 -- a portrait's background: the rarity, pale
	return colour:Lerp(C.sand, 0.55)
end

local animalsTab = "team"
local chosen: number? = nil -- the id of the animal whose detail is open

local function corner(parent: Instance, text: string, colour: Color3)
	local b = Style.chip(parent, text, colour, Color3.new(1, 1, 1))
	b.Position, b.ZIndex = UDim2.fromOffset(8, 8), 3
	b.TextSize = 13
	b.Size = UDim2.fromOffset(0, 22)
end

local function bestTwo(a: any): string
	local s = live(a)
	local order = table.clone(StationConfig.STATS)
	table.sort(order, function(x, y)
		return StationRules.stat(s, x) > StationRules.stat(s, y)
	end)
	return `{STAT_SHORT[order[1]]} {StationRules.stat(s, order[1])}  {STAT_SHORT[order[2]]} {StationRules.stat(
		s,
		order[2]
	)}`
end

local function animalCard(a: any, order: number)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local inTeam = table.find(profile.team, a.id) ~= nil
	local card = Style.button(animals.body, "", function()
		chosen = a.id
		redraw.animals()
	end, "ghost", UDim2.fromOffset(150, 206))
	card.Name, card.LayoutOrder = nameOf(a), order
	local view = Portrait.new(
		card,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(144, 132), background = darker(colour), rainbow = a.rainbow }
	)
	view.Position = UDim2.fromOffset(3, 3)
	Style.round(view, 10)
	if profile.titan == a.id then
		corner(card, "Titan", C.accent)
	elseif inTeam then
		corner(card, "Team", C.good)
	elseif a.at then
		corner(card, "Training", C.info)
	end
	local worn = StationRules.coatOf(a)
	if worn then
		local coat = Style.chip(card, string.upper(worn.name), Style.COAT[worn.id] or Color3.new(1, 1, 1))
		coat.Position, coat.ZIndex, coat.TextSize = UDim2.fromOffset(8, 106), 3, 12
		if Style.COAT[worn.id] == nil then -- rainbow, prismatic
			local colours = Instance.new("UIGradient")
			colours.Color = RAINBOW
			colours.Parent = coat
		end
	end
	local power = Style.chip(card, `⚡ {Format.commas(BattleRules.powerOf(live(a)))}`, C.ink, Color3.new(1, 1, 1))
	power.AnchorPoint, power.Position, power.ZIndex, power.TextSize = Vector2.new(1, 0), UDim2.new(1, -8, 0, 8), 3, 13
	power.Size = UDim2.fromOffset(0, 22)
	local name = Style.text(card, nameOf(a), 17, C.text, UDim2.new(1, -16, 0, 22))
	name.Position, name.TextTruncate = UDim2.fromOffset(8, 138), Enum.TextTruncate.AtEnd
	local best = Style.text(card, bestTwo(a), 13, C.muted, UDim2.new(1, -16, 0, 18))
	best.Position = UDim2.fromOffset(8, 160)
	local band = Style.frame(card, UDim2.new(1, -6, 0, 12), colour)
	band.Position = UDim2.new(0, 3, 1, -15)
	Style.round(band, 6)
	local tag = Style.text(band, string.upper(rarity), 10, C.ink, UDim2.fromScale(1, 1))
	tag.TextXAlignment = Enum.TextXAlignment.Center
end

local function animalDetail(a: any)
	local sp = StationConfig.species(a.s)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local role = StationRules.role(a)
	local isTitan = role == StationConfig.TITAN
	local inTeam = table.find(profile.team, a.id) ~= nil or profile.titan == a.id

	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size, head.LayoutOrder = UDim2.new(1, -8, 0, 176), 1
	head.Parent = animals.body
	local view = Portrait.new(
		head,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(176, 170), background = darker(colour), rainbow = a.rainbow }
	)
	Style.round(view, 14)
	Style.stroke(view, C.ink, 3)
	local name = Style.text(head, StationTrade.nameOf(a), 30, C.text, UDim2.new(1, -196, 0, 36))
	name.Position, name.TextTruncate = UDim2.fromOffset(194, 2), Enum.TextTruncate.AtEnd
	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position, chips.Size = UDim2.fromOffset(194, 44), UDim2.new(1, -196, 0, 28)
	Style.list(chips, 8, true)
	chips.Parent = head
	Style.chip(chips, string.upper(rarity), colour)
	Style.chip(chips, `⚡ {Format.commas(BattleRules.powerOf(live(a)))} power`, C.ink, Color3.new(1, 1, 1))
	Style.chip(chips, `{ROLE_NAME[role] or "?"} · {GROUP_NAME[if sp then sp.group else ""] or "?"}`)
	if a.at then
		Style.chip(chips, "Training", C.info, Color3.new(1, 1, 1))
	elseif inTeam then
		Style.chip(chips, if isTitan then "Your Titan" else "In your team", C.good, Color3.new(1, 1, 1))
	else
		Style.chip(chips, "Resting")
	end
	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Position, buttons.Size = UDim2.fromOffset(194, 116), UDim2.new(1, -196, 0, 48)
	Style.list(buttons, 10, true)
	buttons.Parent = head
	Style.button(buttons, "‹ Back", function()
		chosen = nil
		redraw.animals()
	end, "ghost", UDim2.fromOffset(100, 46))
	Style.button(buttons, if inTeam then "Leave team" elseif isTitan then "Join as Titan" else "Join team", function()
		send("team", a.id)
	end, if inTeam then "ghost" else "good", UDim2.fromOffset(160, 46))
	-- a locked animal can never go in a trade (decision 0099)
	Style.button(buttons, if a.locked then "🔒 Locked" else "Lock", function()
		send("lock", a.id)
	end, if a.locked then "primary" else "ghost", UDim2.fromOffset(120, 46))

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size, grid.LayoutOrder = UDim2.new(1, -8, 0, 290), 2
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(1 / 3, -12, 0, 132)
	cells.CellPadding = UDim2.fromOffset(14, 14)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	grid.Parent = animals.body
	for i, st in StationConfig.STATIONS do
		local training = a.at == st.id
		local taken = false -- a ground trains one animal (decision 0066): another's is greyed out
		for _, other in profile.animals do
			taken = taken or (other.id ~= a.id and other.at == st.id)
		end
		local tile = Style.card(grid, UDim2.new(), if training then C.info else nil)
		tile.LayoutOrder = i
		local now = live(a)
		local level = StationRules.level(now, st.stat :: any)
		local value = Style.text(
			tile,
			`{STAT_SHORT[st.stat]} {StationRules.stat(now, st.stat :: any)}`,
			22,
			C.text,
			UDim2.new(1, -20, 0, 26)
		)
		value.Position = UDim2.fromOffset(12, 10)
		local lv = Style.text(tile, `Lv {level}/{StationConfig.MAX_LEVEL}`, 14, C.muted, UDim2.new(1, -20, 0, 26))
		lv.Position, lv.TextXAlignment = UDim2.fromOffset(8, 10), Enum.TextXAlignment.Right
		local bar, set = Style.bar(tile, UDim2.new(1, -24, 0, 12), if training then C.info else C.good)
		bar.Position = UDim2.fromOffset(12, 44)
		local into = if a.trained then (a.trained[st.stat] or level) - level else 0
		set(if level >= StationConfig.MAX_LEVEL then 1 else into)
		local label = if training then "Stop" elseif taken then "In use" else "Train"
		local button = Style.button(tile, label, function()
			if training then
				send("stop", a.id)
			else
				send("train", a.id, st.id) -- a taken ground is refused, and the toast says why
			end
		end, if training then "info" elseif taken then "off" else "primary", UDim2.new(1, -24, 0, 44))
		button.Position, button.TextSize = UDim2.fromOffset(12, 70), 17
		if training then
			table.insert(tickers, function()
				local left = string.match(statText(live(a), st.stat, true), "  (.+)$")
				button.Text = if left then `Stop · {left}` else "Stop"
			end)
			tickers[#tickers]()
		end
	end
end

redraw.animals = function()
	Style.clear(animals.body)
	Style.clear(animals.chips)
	Style.clear(animals.tabs)
	table.clear(tickers)
	local all, team, training, rainbows = {}, {}, {}, {}
	for _, a in profile.animals do
		table.insert(all, a)
		if table.find(profile.team, a.id) or profile.titan == a.id then
			table.insert(team, a)
		end
		if a.at then
			table.insert(training, a)
		end
		if StationRules.coatOf(a) then
			table.insert(rainbows, a)
		end
	end
	local LISTS = {
		{ "team", `Your team  {#profile.team}/{StationProgress.TEAM_SIZE}`, team },
		{ "all", `All animals  {#all}`, all },
		{ "training", `Training  {#training}`, training },
		{ "rainbow", `Coats  {#rainbows}`, rainbows },
	}
	local shown = all
	for _, l in LISTS do
		Style.tab(animals, l[2], animalsTab == l[1], function()
			animalsTab, chosen = l[1], nil
			redraw.animals()
		end)
		if animalsTab == l[1] then
			shown = l[3]
		end
	end
	Style.chip(animals.chips, `Barn {#profile.animals}/{StationProgress.value(profile, "barn")}`)
	Style.chip(
		animals.chips,
		if profile.titan then "Titan ready" else "No Titan",
		if profile.titan then C.accent else nil
	)
	if chosen then
		local _, a = StationProgress.find(profile, chosen)
		if a then
			animalDetail(a)
			return
		end
		chosen = nil
	end
	if #shown == 0 then
		local empty = Style.card(animals.body, UDim2.new(1, -12, 0, 150))
		local words = if #profile.animals == 0
			then "No animals yet. Buy an egg from the egg vendor, hatch it, and your first animal joins your team."
			else "Nobody here yet."
		local t = Style.text(empty, words, 19, C.muted, UDim2.new(1, -28, 0, 60))
		t.Position = UDim2.fromOffset(14, 14)
		if #profile.animals == 0 then
			local b = Style.button(empty, "Open the egg vendor", function()
				show("shop")
			end, "primary", UDim2.fromOffset(240, 46))
			b.Position = UDim2.fromOffset(14, 86)
		end
	end
	table.sort(shown, function(x, y)
		local rx, ry = RANK[StationRules.rarity(x)] or 0, RANK[StationRules.rarity(y)] or 0
		if rx ~= ry then
			return rx > ry
		end
		return x.id < y.id
	end)
	for i, a in shown do
		animalCard(a, i)
	end
end

-- Eggs: start an egg and watch its timer from anywhere; open it only at the hatchery (decision 0091) ----

-- A picture of an egg: its own model (decision 0057), `side` units square.
local function eggArt(parent: Instance, eggId: string, side: number): ViewportFrame
	return Portrait.new(parent, `egg_{eggId}`, { size = UDim2.fromOffset(side, side), background = C.cardHi })
end

local eggsTab = "hatching"

-- A line drawn from the player to the nest of hatching egg `k`, for a few seconds.
local function wayTo(k: number)
	local nest: BasePart? = nil
	for _, prompt in CollectionService:GetTagged("Egg") do
		if prompt:GetAttribute("Index") == k and prompt:GetAttribute("Ranch") == player:GetAttribute("Ranch") then
			local p = prompt.Parent
			nest = if p and p:IsA("BasePart")
				then p
				elseif p and p:IsA("Model") then p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
				else nil
		end
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if nest == nil or hrp == nil then
		Style.toast(screen, "Your egg is in the hatchery's nests on your ranch")
		return
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = hrp, nest
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1, beam.FaceCamera = 1.2, 1.2, true
	beam.Color = ColorSequence.new(C.accent)
	beam.Texture, beam.TextureMode, beam.TextureLength, beam.TextureSpeed =
		"rbxasset://textures/particles/sparkles_main.dds", Enum.TextureMode.Wrap, 3, 2
	beam.LightEmission, beam.Transparency = 0.6, NumberSequence.new(0.1)
	beam.Parent = hrp
	for _, x in { a0, a1, beam } do
		Debris:AddItem(x, 10)
	end
end

local function eggCard(k: number, e: any, order: number)
	local def = StationConfig.egg(e.egg) :: StationConfig.Egg
	local now = Workspace:GetServerTimeNow()
	local need = StationProgress.hatchSeconds(profile, def) -- the Brooder shortens it
	local ready = e.since ~= nil and now >= (StationProgress.dueAt(profile, e) :: number)
	local card = Style.card(eggs.body, UDim2.fromOffset(212, 176), if ready then C.good else nil)
	card.LayoutOrder = order
	eggArt(card, e.egg, 68).Position = UDim2.fromOffset(10, 10)
	local name = Style.text(card, def.name, 19, C.text, UDim2.new(1, -92, 0, 24))
	name.Position, name.TextTruncate = UDim2.fromOffset(84, 12), Enum.TextTruncate.AtEnd
	local info = Style.text(card, "", 14, C.muted, UDim2.new(1, -92, 0, 40))
	info.Position = UDim2.fromOffset(84, 38)
	if e.since == nil then
		info.Text = `Takes {Format.ago(need)} to hatch`
		local nests = StationProgress.value(profile, "hatchery")
		local hatching = 0
		for _, x in profile.eggs do
			hatching += if x.since then 1 else 0
		end
		local b = Style.button(card, if hatching >= nests then "Nests full" else "Hatch it", function()
			send("hatch", k)
		end, if hatching >= nests then "off" else "primary")
		b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
	else
		local bar, set = Style.bar(card, UDim2.new(1, -24, 0, 14), C.accent)
		bar.Position = UDim2.fromOffset(12, 88)
		local b = Style.button(card, "Hatching...", function() end, "off")
		b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
		local function tick()
			local remaining = (StationProgress.dueAt(profile, e) :: number) - Workspace:GetServerTimeNow()
			set(1 - remaining / need)
			if remaining <= 0 then
				info.Text, info.TextColor3 = "Ready! Open it at the hatchery", C.good
				b.Text = "Show me the way"
				if b:GetAttribute("Kind") ~= "info" then
					Style.kind(b, "info")
					b.Activated:Connect(function()
						show(nil)
						wayTo(k)
					end)
				end
			else
				info.Text = `Opens in {Format.ago(remaining)}`
			end
		end
		tick()
		table.insert(eggTickers, tick)
	end
end

redraw.eggs = function()
	Style.clear(eggs.body)
	Style.clear(eggs.chips)
	Style.clear(eggs.tabs)
	table.clear(eggTickers)
	local nests, cellar = StationProgress.value(profile, "hatchery"), StationProgress.value(profile, "cellar")
	local hatching, ready, stored = {}, 0, {}
	local now = Workspace:GetServerTimeNow()
	for k, e in profile.eggs do
		if e.since then
			table.insert(hatching, k)
			local def = StationConfig.egg(e.egg)
			if def and now >= (StationProgress.dueAt(profile, e) :: number) then
				ready += 1
			end
		else
			table.insert(stored, k)
		end
	end
	Style.tab(eggs, `Hatching  {#hatching}/{nests}`, eggsTab == "hatching", function()
		eggsTab = "hatching"
		redraw.eggs()
	end, if ready > 0 then tostring(ready) else nil)
	Style.tab(eggs, `In storage  {#stored}/{cellar}`, eggsTab == "storage", function()
		eggsTab = "storage"
		redraw.eggs()
	end)
	Style.tab(eggs, "Egg vendor  ›", false, function()
		show("shop")
	end)
	Style.chip(eggs.chips, `Brooder: hatching {StationProgress.value(profile, "brooder")}% speed`)
	local list = if eggsTab == "hatching" then hatching else stored
	for order, k in list do
		eggCard(k, profile.eggs[k], order)
	end
	if eggsTab == "hatching" then
		for slot = #hatching + 1, nests do -- free nests
			local card = Style.card(eggs.body, UDim2.fromOffset(212, 176))
			card.LayoutOrder = 100 + slot
			local t = Style.text(card, `Nest {slot} is free`, 19, C.muted, UDim2.new(1, -24, 0, 24))
			t.Position = UDim2.fromOffset(12, 14)
			local hint = Style.text(card, "Start an egg from your storage", 14, C.muted, UDim2.new(1, -24, 0, 40))
			hint.Position = UDim2.fromOffset(12, 44)
			local b = Style.button(card, "Choose an egg", function()
				eggsTab = "storage"
				redraw.eggs()
			end, if #stored > 0 then "primary" else "off")
			b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
		end
		local hatchery = StationConfig.upgrade("hatchery") :: StationConfig.Upgrade
		local next = hatchery.levels[(profile.upgrades.hatchery or 0) + 1]
		if next then -- what the next Hatchery level adds
			local card = Style.card(eggs.body, UDim2.fromOffset(212, 176))
			card.LayoutOrder = 200
			Style.paint(card, C.sand)
			local t = Style.text(card, `Nest {nests + 1}`, 19, C.muted, UDim2.new(1, -24, 0, 24))
			t.Position = UDim2.fromOffset(12, 14)
			local hint = Style.text(
				card,
				`The Hatchery's next level hatches {next.value} at once`,
				14,
				C.muted,
				UDim2.new(1, -24, 0, 40)
			)
			hint.Position = UDim2.fromOffset(12, 44)
			local b = Style.button(card, `Upgrade: {Format.short(next.coins)}`, function()
				ranchTab = "eggs"
				show("ranch")
			end, "ghost")
			b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
		end
	elseif #stored == 0 then
		local empty = Style.card(eggs.body, UDim2.new(1, -12, 0, 130))
		local t = Style.text(
			empty,
			"No eggs in storage. Buy some from the egg vendor.",
			19,
			C.muted,
			UDim2.new(1, -28, 0, 30)
		)
		t.Position = UDim2.fromOffset(14, 14)
		local b = Style.button(empty, "Open the egg vendor", function()
			show("shop")
		end, "primary", UDim2.fromOffset(240, 46))
		b.Position = UDim2.fromOffset(14, 66)
	end
end

-- Ranch: upgrades in three groups, each with a picture of its building (decision 0091) -----------------

local GROUPS = {
	{ id = "animals", name = "Animals", upgrades = { "house", "barn", "grounds" } },
	{ id = "eggs", name = "Eggs", upgrades = { "hatchery", "cellar", "brooder" } },
	{ id = "earnings", name = "Earnings", upgrades = { "windmill", "lodge", "den" } },
}

-- Pictures of the buildings as they stand in game (decision 0091): each building's three looks, and
-- the Training Grounds (the Speed Track) at each level. Screenshots from Studio, uploaded as images.
local PICTURES: { [string]: { string } } = {
	house = { "123119223827948", "75503797264752", "107798905588688" },
	barn = { "101892180349204", "121151105188828", "115965219734238" },
	hatchery = { "133902304920898", "124045791914974", "123100005333170" },
	cellar = { "90053421861862", "72531267730211", "133921641057596" },
	brooder = { "88844343986979", "128424168474378", "125930939253883" },
	windmill = { "95016315403212", "71885186151925", "130764990300282" },
	lodge = { "89855001205054", "104259688695882", "92288867347305" },
	den = { "86742890917401", "83910433232346", "101343125013182" },
	grounds = {
		"98297919965705",
		"106959352530071",
		"131970264474678",
		"137939197697617",
		"120047660590642",
		"100438873746948",
	},
}
local PLOT = { brooder = true, windmill = true, lodge = true, den = true } -- as Ranch.luau: not built at level 0

-- Which picture shows upgrade `u` at `level`: the look Ranch.luau builds (1 to 3; the first look for a
-- building not bought yet), or the Training Grounds' level itself (0 to 5).
local function pictureOf(u: StationConfig.Upgrade, level: number): number
	if u.id == "grounds" then
		return math.clamp(level + 1, 1, #PICTURES.grounds)
	end
	local first = if PLOT[u.id] then 1 else 0
	if level < first then
		return 1
	end
	return 1 + math.min(2, (level - first) * 3 // (#u.levels - first + 1))
end

local function picture(parent: Instance, id: string, size: UDim2): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Size = size
	img.BackgroundColor3 = Color3.fromRGB(191, 230, 247)
	img.BorderSizePixel = 0
	img.Image = `rbxassetid://{id}`
	img.ScaleType = Enum.ScaleType.Crop
	Style.round(img, 11)
	img.Parent = parent
	return img
end

local function canBuy(u: StationConfig.Upgrade): boolean
	local cost = u.levels[(profile.upgrades[u.id] or 0) + 1]
	return cost ~= nil and profile.coins >= cost.coins and profile.samples >= cost.samples
end

local function upgradeCard(u: StationConfig.Upgrade, order: number)
	local level = profile.upgrades[u.id] or 0
	local cost = u.levels[level + 1]
	local card = Style.card(ranch.body, UDim2.fromOffset(204, 330))
	card.LayoutOrder = order
	local pics = PICTURES[u.id]
	if pics then
		local now = pictureOf(u, level)
		local view = picture(card, pics[now], UDim2.fromOffset(198, 112))
		view.Position = UDim2.fromOffset(3, 3)
		local built = u.id == "grounds" or level >= (if PLOT[u.id] then 1 else 0)
		if not built then
			view.ImageTransparency = 0.45
			local tag = Style.chip(view, "Not built yet", C.ink, Color3.new(1, 1, 1))
			tag.Position, tag.TextSize = UDim2.fromOffset(8, 8), 13
		end
	end
	local title = Style.text(card, u.name, 21, C.text, UDim2.new(1, -24, 0, 26))
	title.Position = UDim2.fromOffset(12, 122)
	local pips = Instance.new("Frame")
	pips.BackgroundTransparency = 1
	pips.Position, pips.Size = UDim2.fromOffset(12, 152), UDim2.new(1, -24, 0, 14)
	Style.list(pips, 4, true)
	pips.Parent = card
	for i = 1, #u.levels do
		local pip = Style.frame(pips, UDim2.fromOffset(22, 12), if i <= level then C.good else Color3.new(1, 1, 1))
		Style.round(pip, 4)
		Style.stroke(pip, C.ink, 2)
		pip.LayoutOrder = i
	end
	local now = StationProgress.value(profile, u.id)
	local words = if cost then `Now {now} → next {cost.value}\n{u.gives}` else `{now} {u.gives}`
	local gives = Style.text(card, words, 14, C.muted, UDim2.new(1, -24, 0, 54))
	gives.Position = UDim2.fromOffset(12, 174)
	if cost == nil then
		local done = Style.chip(card, "TOP LEVEL", C.accent)
		done.Position = UDim2.fromOffset(12, 238)
		return
	end
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.Position, price.Size = UDim2.fromOffset(12, 232), UDim2.new(1, -24, 0, 26)
	Style.list(price, 10, true)
	price.Parent = card
	Style.amount(price, "coins", Format.commas(cost.coins))
	if cost.samples > 0 then
		Style.amount(price, "samples", tostring(cost.samples))
	end
	local b = Style.button(card, "Upgrade", function()
		send("upgrade", u.id)
	end, if canBuy(u) then "good" else "off")
	b.Position, b.Size = UDim2.fromOffset(12, 270), UDim2.new(1, -24, 0, 44)
end

redraw.ranch = function()
	Style.clear(ranch.body)
	Style.clear(ranch.chips)
	Style.clear(ranch.tabs)
	for _, g in GROUPS do
		local any = false
		for _, id in g.upgrades do
			any = any or canBuy(StationConfig.upgrade(id) :: StationConfig.Upgrade)
		end
		Style.tab(ranch, g.name, ranchTab == g.id, function()
			ranchTab = g.id
			redraw.ranch()
		end, if any then "!" else nil)
		if ranchTab == g.id then
			for i, id in g.upgrades do
				upgradeCard(StationConfig.upgrade(id) :: StationConfig.Upgrade, i)
			end
		end
	end
	Style.amount(ranch.chips, "coins", Format.commas(profile.coins))
	Style.amount(ranch.chips, "samples", `{Format.commas(profile.samples)} samples`)
	if RunService:IsStudio() then -- a way to try the upgrades without fighting for them
		local funds = Style.button(ranch.chips, "Test funds (Studio)", function()
			send("funds")
		end, "ghost", UDim2.fromOffset(196, 44))
		funds.LayoutOrder = -1
	end
end

-- Egg vendor --------------------------------------------------------------------------------------------

-- An egg's card (decision 0078): the egg, its price and time; the animals it hatches, each named under its
-- picture; its rare finds in one row, each edged in its tier's colour. How rare a find is shows when it
-- hatches, not here.
local function animalCell(parent: Instance, order: number, asset: string, label: string?, colour: Color3, side: number)
	local cell = Instance.new("Frame")
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.fromOffset(side, side + (if label then 16 else 0))
	cell.LayoutOrder = order
	cell.Parent = parent
	local view = Portrait.new(cell, asset, { size = UDim2.fromOffset(side, side), background = darker(colour) })
	Style.round(view, 10)
	Style.stroke(view, colour, 3)
	if label then
		local t = Style.text(cell, label, 12, C.muted, UDim2.fromOffset(side + 6, 14))
		t.Position = UDim2.fromOffset(-3, side + 2)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextTruncate = Enum.TextTruncate.AtEnd
	end
end

local shopEgg = 1 -- the egg the vendor shows
redraw.shop = function()
	Style.clear(shop.body)
	Style.clear(shop.chips)
	Style.clear(shop.tabs)
	for k, d in StationConfig.EGGS do
		local closed = d.wave ~= nil and profile.best < d.wave
		local tab = Style.tab(shop, d.name, shopEgg == k, function()
			shopEgg = k
			redraw.shop()
		end)
		tab.Text = `{d.name}\n{if closed then `Wave {d.wave}` else Format.short(d.price)}`
		tab.TextSize, tab.TextYAlignment, tab.Size = 17, Enum.TextYAlignment.Center, UDim2.fromOffset(196, 56)
		if closed then
			Style.kind(tab, "off")
		end
	end
	Style.amount(shop.chips, "coins", Format.commas(profile.coins))
	Style.chip(shop.chips, `Level {StationProgress.playerLevel(profile)} · best wave {profile.best}`)

	local def = StationConfig.EGGS[shopEgg]
	local locked = def.wave ~= nil and profile.best < def.wave
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size, head.LayoutOrder = UDim2.new(1, -8, 0, 110), 1
	head.Parent = shop.body
	eggArt(head, def.id, 104)
	local name = Style.text(head, def.name, 34, C.text, UDim2.new(1, -124, 0, 40))
	name.Position = UDim2.fromOffset(120, 8)
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.Position, price.Size = UDim2.fromOffset(120, 54), UDim2.new(1, -124, 0, 28)
	Style.list(price, 10, true)
	price.Parent = head
	Style.amount(price, "coins", Format.commas(def.price))
	Style.chip(price, `Hatches in {Format.ago(StationProgress.hatchSeconds(profile, def))}`)
	if locked then
		Style.chip(price, `Clear wave {def.wave} to unlock`, C.bad, Color3.new(1, 1, 1))
	end
	local hatches = Style.text(
		shop.body,
		if def.only then "VARIANTS ONLY: EVERY HATCH IS ONE OF THESE" else "HATCHES",
		14,
		C.muted,
		UDim2.new(1, -8, 0, 18)
	)
	hatches.LayoutOrder = 2
	local basics = Instance.new("Frame")
	basics.BackgroundTransparency = 1
	basics.Size, basics.LayoutOrder, basics.Visible = UDim2.new(1, -8, 0, 92), 3, not def.only
	Style.list(basics, 8, true)
	basics.Parent = shop.body
	for i, o in def.odds do
		local sp = StationConfig.species(o.id) :: StationConfig.Species
		animalCell(basics, i, StationRules.assetOf(o.id, nil), sp.name, RARITY_COLOUR[sp.rarity] or C.text, 72)
	end
	local finds = Style.text(shop.body, if def.only then "" else "RARE FINDS", 14, C.muted, UDim2.new(1, -8, 0, 18))
	finds.LayoutOrder = 4
	local rare = Instance.new("Frame")
	rare.BackgroundTransparency = 1
	rare.Size, rare.LayoutOrder = UDim2.new(1, -8, 0, 64), 5
	Style.list(rare, 8, true)
	rare.Parent = shop.body
	local side = math.min(58, (600 - 8 * (#def.rare - 1)) // math.max(1, #def.rare)) -- one row, however many
	for i, drop in def.rare do
		local tier = (StationConfig.variant(drop.s, drop.v) :: StationConfig.Variant).tier
		animalCell(rare, i, StationRules.assetOf(drop.s, drop.v), nil, RARITY_COLOUR[tier] or C.text, side)
	end
	local can = not locked and profile.coins >= def.price
	local b = Style.button(shop.body, `Buy for {Format.commas(def.price)}`, function()
		if locked then
			Style.toast(screen, `Clear wave {def.wave} to unlock the {def.name}`, nil, "bad")
			return
		end
		send("buy", def.id)
	end, if can then "primary" else "off", UDim2.new(1, -12, 0, 56))
	b.LayoutOrder, b.TextSize = 6, 24
end

-- Gifts (decision 0094): the weekly planner, the monthly planner and the daily wheel ----------------------

local giftsTab = "week"
local spinning = false

-- What a reward gives, in words: "930 coins, 2 Meadow Eggs".
local function rewardWords(items: any): string
	local parts = {}
	if items.coins > 0 then
		table.insert(parts, `{Format.commas(items.coins)} coins`)
	end
	if items.samples > 0 then
		table.insert(parts, `{items.samples} samples`)
	end
	local counts, order = {}, {}
	for _, id in items.eggs do
		if counts[id] == nil then
			table.insert(order, id)
		end
		counts[id] = (counts[id] or 0) + 1
	end
	for _, id in order do
		local def = StationConfig.egg(id)
		local name = if def then def.name else id
		table.insert(parts, if counts[id] > 1 then `{counts[id]} {name}s` else `a {name}`)
	end
	if items.boost then
		local what = if items.boost == "hatch" then "Hatching" else "Training"
		table.insert(parts, `{what} x2 for {Format.ago(items.seconds)}`)
	end
	if items.rainbow then
		local sp = StationConfig.species(items.rainbow)
		table.insert(parts, `a Rainbow {if sp then sp.name else items.rainbow}`)
	end
	if items.jackpot then
		table.insert(parts, "a Rainbow mythic!")
	end
	return table.concat(parts, ", ")
end

-- The reward icons (decision 0100): one picture for each kind of reward, in the Savanna look
-- (assets/stations/icons, made by tools/icons/stations_rewards.py). Eggs show their own egg.
local ICON = {
	coins = "rbxassetid://126839540915586",
	samples = "rbxassetid://109970824605063",
	meadow = "rbxassetid://102211226773835",
	wild = "rbxassetid://108812133520186",
	safari = "rbxassetid://129564996329142",
	golden = "rbxassetid://86853923413561",
	star = "rbxassetid://95586444952247",
	hatch = "rbxassetid://111148238651019",
	train = "rbxassetid://92388913223446",
	rainbow = "rbxassetid://90795860429478",
	spin = "rbxassetid://112243151972690",
	gift = "rbxassetid://91667720786022",
}

-- A reward's main picture and the small one for what comes with it.
local function iconsOf(items: any): (string, string?)
	local egg = items.eggs[1]
	local boost = if items.boost then ICON[items.boost] else nil
	if items.jackpot or items.rainbow then
		return ICON.rainbow, nil
	elseif egg then
		return ICON[egg] or ICON.meadow, boost
	elseif items.coins > 0 then
		return ICON.coins, if items.samples > 0 then ICON.samples else boost
	elseif boost then
		return boost, nil
	elseif items.samples > 0 then
		return ICON.samples, nil
	end
	return ICON.gift, nil
end

-- The picture of a reward at `size`: its main icon, a small second one at its foot, a gold star on the
-- player's best egg (`best`).
local function rewardIcon(parent: Instance, items: any, size: number, best: boolean?): Frame
	local main, extra = iconsOf(items)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	local function layer(image: string, scale: number, anchor: Vector2, at: UDim2)
		local p = Instance.new("ImageLabel")
		p.BackgroundTransparency, p.Image = 1, image
		p.AnchorPoint, p.Position, p.Size = anchor, at, UDim2.fromScale(scale, scale)
		p.Parent = holder
	end
	layer(main, 1, Vector2.zero, UDim2.new())
	if extra then
		layer(extra, 0.5, Vector2.new(1, 1), UDim2.fromScale(1.08, 1.04))
	end
	if best then
		layer(ICON.star, 0.42, Vector2.zero, UDim2.fromScale(-0.08, -0.04))
	end
	holder.Parent = parent
	return holder
end

local function giftsReady(): (boolean, boolean, boolean)
	if profile == nil or profile.rewards == nil then
		return false, false, false
	end
	local r = profile.rewards
	local week = r.weekGot < r.weekDays
	local month = false
	for _, d in StationRewards.MILESTONES do
		month = month or (r.monthDays >= d and not table.find(r.monthGot, d))
	end
	return week, month, StationRewards.canSpin(profile, Workspace:GetServerTimeNow())
end

local function boostChips(parent: Instance)
	local now = Workspace:GetServerTimeNow()
	for _, b in { { "hatch", "Hatching" }, { "train", "Training" } } do
		local left = StationProgress.boostLeft(profile, b[1], now)
		if left > 0 then
			Style.chip(parent, `{b[2]} x2: {Format.ago(left)}`, C.info, Color3.new(1, 1, 1))
		end
	end
end

local function weekView()
	local r = profile.rewards
	local head = Style.text(
		gifts.body,
		`Day {math.min(r.weekGot + 1, 7)} of 7 · new rewards every Monday`,
		18,
		C.muted,
		UDim2.new(1, -12, 0, 24)
	)
	head.LayoutOrder = 0
	for k, spec in StationRewards.WEEK do
		local got, ready = k <= r.weekGot, k == r.weekGot + 1 and r.weekGot < r.weekDays
		local card =
			Style.card(gifts.body, UDim2.fromOffset(150, 228), if got then C.good elseif k == 7 then C.accent else nil)
		card.LayoutOrder = k
		local t = Style.text(card, `Day {k}`, 20, C.text, UDim2.new(1, -20, 0, 24))
		t.Position = UDim2.fromOffset(10, 8)
		local items = StationRewards.resolve(profile, spec)
		local icon = rewardIcon(card, items, 68, spec.egg == "best")
		icon.Position = UDim2.fromOffset(41, 34)
		local words = Style.text(card, rewardWords(items), 14, C.muted, UDim2.new(1, -20, 0, 66))
		words.Position, words.TextWrapped, words.TextXAlignment =
			UDim2.fromOffset(10, 106), true, Enum.TextXAlignment.Center
		local b = Style.button(card, if got then "Claimed" elseif ready then "Claim" else "Log in more", function()
			send("claim_week")
		end, if ready then "good" else "off")
		b.Position, b.Size, b.TextSize = UDim2.fromOffset(10, 174), UDim2.new(1, -20, 0, 44), 16
	end
end

local function monthView()
	local r = profile.rewards
	local head = Style.text(
		gifts.body,
		`Days logged this month: {r.monthDays} · a missed day never resets it`,
		18,
		C.muted,
		UDim2.new(1, -12, 0, 24)
	)
	head.LayoutOrder = 0
	for k, d in StationRewards.MILESTONES do
		local spec = StationRewards.MONTH[d]
		local got = table.find(r.monthGot, d) ~= nil
		local ready = not got and r.monthDays >= d
		local items = StationRewards.resolve(profile, spec, StationRewards.monthOf(Workspace:GetServerTimeNow()))
		local card =
			Style.card(gifts.body, UDim2.fromOffset(150, 228), if got then C.good elseif d == 28 then C.accent else nil)
		card.LayoutOrder = k
		local t = Style.text(card, `Day {d}`, 20, C.text, UDim2.new(1, -20, 0, 24))
		t.Position = UDim2.fromOffset(10, 8)
		if items.rainbow then -- the month's own rainbow animal
			local view = Portrait.new(
				card,
				StationRules.assetOf(items.rainbow, nil),
				{ size = UDim2.fromOffset(84, 68), rainbow = true, background = C.cardHi }
			)
			view.Position = UDim2.fromOffset(33, 34)
		else
			local icon = rewardIcon(card, items, 68, spec.egg == "best")
			icon.Position = UDim2.fromOffset(41, 34)
		end
		local words = Style.text(card, rewardWords(items), 14, C.muted, UDim2.new(1, -20, 0, 66))
		words.Position, words.TextWrapped, words.TextXAlignment =
			UDim2.fromOffset(10, 106), true, Enum.TextXAlignment.Center
		local label = if got then "Claimed" elseif ready then "Claim" else `{d - r.monthDays} more days`
		local b = Style.button(card, label, function()
			send("claim_month", d)
		end, if ready then "good" else "off")
		b.Position, b.Size, b.TextSize = UDim2.fromOffset(10, 174), UDim2.new(1, -20, 0, 44), 16
	end
end

-- The wheel: eight prize bubbles round a hub, turned so the prize won stops under the pointer.
local wheelTurn = 0
local function wheelView()
	local SIZE = 380
	local n = #StationRewards.WHEEL
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size, holder.LayoutOrder = UDim2.new(1, -12, 0, SIZE + 300), 1
	holder.Parent = gifts.body

	-- the odds, below the wheel and its button, in two columns
	local odds = Instance.new("Frame")
	odds.BackgroundTransparency = 1
	odds.AnchorPoint, odds.Position, odds.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 130), UDim2.fromOffset(560, 160)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize, grid.CellPadding = UDim2.fromOffset(276, 22), UDim2.fromOffset(8, 2)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = odds
	odds.Parent = holder
	local title = Style.text(holder, "THE ODDS", 14, C.muted, UDim2.fromOffset(560, 20))
	title.AnchorPoint, title.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 106)
	title.TextXAlignment = Enum.TextXAlignment.Center
	for k, slice in StationRewards.WHEEL do
		local line =
			Style.text(odds, `{slice.name}: {slice.ppm / 10000}%`, 15, if k == n then C.bad else C.muted, UDim2.new())
		line.LayoutOrder = k
		line.TextXAlignment = Enum.TextXAlignment.Center
	end
	local pity = Style.text(
		holder,
		`After {StationRewards.PITY} spins without it, the jackpot's chance doubles.`,
		13,
		C.muted,
		UDim2.fromOffset(560, 20)
	)
	pity.AnchorPoint, pity.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 238)
	pity.TextXAlignment = Enum.TextXAlignment.Center

	local stage = holder
	-- the wheel, big, in the middle
	local disc = Instance.new("Frame")
	disc.Name = "Wheel"
	disc.AnchorPoint, disc.Position, disc.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 22), UDim2.fromOffset(SIZE, SIZE)
	disc.BackgroundColor3 = C.sand
	disc.Rotation = wheelTurn % 360
	Style.round(disc, SIZE / 2)
	Style.stroke(disc, C.ink, 6)
	disc.Parent = stage
	local colours = {
		C.cardHi,
		C.accent,
		Color3.fromRGB(201, 238, 176),
		Color3.fromRGB(166, 216, 245),
		C.info,
		Color3.fromRGB(214, 196, 247), -- lilac, so the green samples stand out
		Color3.fromRGB(247, 163, 189),
		C.gold,
	}
	for k, slice in StationRewards.WHEEL do
		local a = math.rad((k - 1) * 360 / n - 90)
		local bubble = Instance.new("TextLabel")
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.new(0.5, math.cos(a) * SIZE * 0.35, 0.5, math.sin(a) * SIZE * 0.35)
		bubble.Size = UDim2.fromOffset(SIZE * 0.25, SIZE * 0.25)
		bubble.BackgroundColor3 = colours[k]
		bubble.Font = Ui.theme.font
		bubble.Text = ""
		bubble.Rotation = (k - 1) * 360 / n
		local prize = slice.prize
		local items = StationRewards.resolve(profile, prize)
		local icon = rewardIcon(bubble, items, math.floor(SIZE * 0.15), prize.egg == "best")
		icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6)
		local caption = Style.text(
			bubble,
			if prize.jackpot
				then "MYTHIC!"
				elseif prize.pays then `{prize.pays} pays`
				elseif prize.boost then `x2 {Format.ago(prize.seconds or 0)}`
				elseif prize.samples then `{prize.samples} samples`
				elseif prize.egg == "best" then "Best egg"
				else "Egg",
			13,
			C.ink,
			UDim2.new(1, 0, 0, 16)
		)
		caption.AnchorPoint, caption.Position, caption.TextXAlignment =
			Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6), Enum.TextXAlignment.Center
		Style.round(bubble, SIZE * 0.125)
		Style.stroke(bubble, C.ink, 3)
		if k == n then
			local g = Instance.new("UIGradient")
			g.Color = RAINBOW
			g.Parent = bubble
		end
		bubble.Parent = disc
	end
	local hub = Style.text(disc, "", 1, C.ink, UDim2.fromOffset(SIZE * 0.22, SIZE * 0.22))
	hub.AnchorPoint, hub.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	hub.BackgroundTransparency, hub.BackgroundColor3 = 0, C.accent
	Style.round(hub, SIZE * 0.11)
	Style.stroke(hub, C.ink, 5)
	local pointer = Style.text(stage, "▼", 48, C.bad, UDim2.fromOffset(48, 48))
	pointer.AnchorPoint, pointer.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -4)
	pointer.TextXAlignment, pointer.ZIndex = Enum.TextXAlignment.Center, 5
	Style.outline(pointer)

	-- under the wheel: the button, which pops while a spin is ready, and when the next one comes
	local now = Workspace:GetServerTimeNow()
	local can = StationRewards.canSpin(profile, now)
	local nextIn = (StationRewards.day(now) + 1) * 86400 - now
	local b = Style.button(stage, if can then "Spin it!" else `Next spin in {Format.ago(nextIn)}`, function()
		if spinning then
			return
		end
		spinning = true
		local ok, code = request:InvokeServer("spin")
		if not ok then
			spinning = false
			Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		end
	end, if can then "primary" else "off", UDim2.fromOffset(240, 60))
	b.AnchorPoint, b.Position, b.TextSize = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 40), 26
	if can then
		local pop = b:FindFirstChildOfClass("UIScale") :: UIScale
		task.spawn(function() -- a gentle pulse until it is pressed or the menu redraws
			while b.Parent and not spinning do
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { Scale = 1.08 }):Play()
				task.wait(0.5)
				if not b.Parent or spinning then
					break
				end
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
				task.wait(0.5)
			end
		end)
	end
	return disc
end

local wheelDisc: Frame? = nil
redraw.gifts = function()
	if spinning then
		return -- the wheel is turning: it redraws when it stops
	end
	Style.clear(gifts.body)
	Style.clear(gifts.chips)
	Style.clear(gifts.tabs)
	local week, month, spin = giftsReady()
	for _, t in { { "week", "This week", week }, { "month", "This month", month }, { "wheel", "Daily wheel", spin } } do
		Style.tab(gifts, t[2], giftsTab == t[1], function()
			giftsTab = t[1]
			redraw.gifts()
		end, if t[3] then "!" else nil)
	end
	boostChips(gifts.chips)
	Style.chip(gifts.chips, "Resets at midnight UTC")
	wheelDisc = nil
	if giftsTab == "week" then
		weekView()
	elseif giftsTab == "month" then
		monthView()
	else
		wheelDisc = wheelView()
	end
end

-- The wheel stops on the prize the server rolled, then says what it was.
local function landWheel(payload: any)
	local n = #StationRewards.WHEEL
	local slice = 360 / n
	local target = -((payload.prize - 1) * slice) + math.random(-12, 12)
	wheelTurn += 360 * 5 + ((target - wheelTurn) % 360)
	local disc = wheelDisc
	local function done()
		spinning = false
		local words = rewardWords(payload.items)
		if payload.items.jackpot and payload.mythic then
			local va = StationConfig.variant(payload.mythic.s, payload.mythic.v)
			words = `JACKPOT! A Rainbow {if va then va.name else "mythic"}!`
		end
		Style.sound("claim")
		Style.toast(screen, `You won: {words}`, 5, "good", (iconsOf(payload.items)))
		if openName == "gifts" then
			redraw.gifts()
		end
	end
	if disc and disc.Parent then
		local t = TweenService:Create(
			disc,
			TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Rotation = wheelTurn }
		)
		t.Completed:Connect(done)
		t:Play()
	else
		done()
	end
end

-- Trading (decision 0084) ---------------------------------------------------------------------------------

local tradeState: any = nil -- the open trade as the server last sent it (pushTrade), and `at`, when it came
local invite: any = nil -- the latest request to trade: from (UserId), name, at (os.clock)
local tradePeek: any = nil -- the animal whose full card is open in the trade window
local tradeDrawn = 0 -- counts redraws of the trade window, so a timer can tell it is stale

local function tradeCell(
	parent: Instance,
	order: number,
	a: any,
	label: string,
	onClick: (() -> ())?,
	picked: boolean?,
	flashFor: number?
)
	local colour = RARITY_COLOUR[StationRules.rarity(a)] or C.text
	local card = Style.card(
		parent,
		UDim2.fromOffset(108, if onClick then 150 else 118),
		if flashFor then C.bad elseif picked then C.good else C.edge
	)
	card.LayoutOrder = order
	if flashFor then -- changed just now (decision 0099): berry until the flash is over
		local mine = tradeDrawn
		task.delay(flashFor, function()
			if tradeDrawn == mine and card.Parent then
				redraw.trade()
			end
		end)
	end
	local peek = Instance.new("TextButton") -- tap the picture for its full card
	peek.BackgroundTransparency, peek.Text = 1, ""
	peek.Position, peek.Size, peek.ZIndex = UDim2.fromOffset(10, 8), UDim2.fromOffset(88, 72), 5
	peek.Activated:Connect(function()
		tradePeek = a
		redraw.trade()
	end)
	peek.Parent = card
	local view = Portrait.new(
		card,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(88, 72), background = darker(colour), rainbow = a.rainbow }
	)
	view.Position = UDim2.fromOffset(10, 8)
	local name = Style.text(card, label, 12, C.text, UDim2.fromOffset(100, 30))
	name.Position = UDim2.fromOffset(4, 82)
	name.TextXAlignment = Enum.TextXAlignment.Center
	if onClick then
		local b =
			Style.button(card, if picked then "Take out" else "Put in", onClick, if picked then "ghost" else "primary")
		b.Position, b.Size = UDim2.fromOffset(8, 112), UDim2.fromOffset(92, 30)
		b.TextSize = 14
	end
end

local function tradeSection(title: string, order: number, height: number): Frame
	local card = Style.card(trade.body, UDim2.new(1, -20, 0, height))
	card.LayoutOrder = order
	local t = Style.text(card, title, 16, C.muted, UDim2.new(1, -24, 0, 20))
	t.Position = UDim2.fromOffset(12, 8)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position, row.Size = UDim2.fromOffset(12, 34), UDim2.new(1, -24, 1, -42)
	Style.list(row, 8, true, true)
	row.Parent = card
	return row
end

-- The full card of the animal tapped in the trade window: version, rarity, coat, power, every stat.
local function peekCard(a: any)
	local card = Style.card(trade.body, UDim2.new(1, -20, 0, 128), RARITY_COLOUR[StationRules.rarity(a)])
	card.LayoutOrder = 1
	local title = Style.text(
		card,
		`{StationTrade.nameOf(a)}  ·  {string.upper(StationRules.rarity(a))}  ·  ⚡ {Format.commas(
			BattleRules.powerOf(a)
		)}`,
		18,
		C.text,
		UDim2.new(1, -120, 0, 24)
	)
	title.Position = UDim2.fromOffset(14, 10)
	local parts = {}
	for _, stat in StationConfig.STATS do
		table.insert(
			parts,
			`{STAT_SHORT[stat]} {StationRules.stat(a, stat)} (Lv {StationRules.level(a, stat)}/{StationConfig.MAX_LEVEL})`
		)
	end
	local lines = Style.text(card, table.concat(parts, "    "), 14, C.muted, UDim2.new(1, -28, 0, 60))
	lines.Position, lines.TextWrapped = UDim2.fromOffset(14, 42), true
	local close = Style.button(card, "Close", function()
		tradePeek = nil
		redraw.trade()
	end, "ghost", UDim2.fromOffset(92, 40))
	close.AnchorPoint, close.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 10)
end

local function ago(at: number): string
	local d = os.time() - at
	return if d < 3600
		then `{math.max(1, d // 60)}m ago`
		elseif d < 86400 then `{d // 3600}h ago`
		else `{d // 86400}d ago`
end

redraw.trade = function()
	tradeDrawn += 1
	local drawn = tradeDrawn
	Style.clear(trade.body)
	Style.clear(trade.chips)
	Style.clear(trade.tabs)
	tradeDot.Visible = false
	local tip = Style.text(
		trade.body,
		"Only what's in this window moves, both sides at once. Nobody can give you anything outside it.",
		14,
		C.muted,
		UDim2.new(1, -20, 0, 20)
	)
	tip.LayoutOrder = 0
	if tradeState then
		local since = os.clock() - (tradeState.at or os.clock())
		local readyIn = math.max(0, (tradeState.readyIn or 0) - since)
		local confirmIn = math.max(0, (tradeState.confirmIn or 0) - since)
		local function again(after: number) -- redraw when a wait runs out
			task.delay(after, function()
				if tradeDrawn == drawn and openName == "trade" then
					redraw.trade()
				end
			end)
		end
		local fresh = (tradeState.traded or 0) == 0 or (tradeState.level or 0) <= StationTrade.MIN_LEVEL
		Style.chip(trade.chips, `Trading with {tradeState.with}`, C.accent, C.accentText)
		Style.chip(
			trade.chips,
			`Level {tradeState.level or "?"} · traded {tradeState.traded or 0} times`,
			if fresh then C.bad else nil,
			if fresh then Color3.new(1, 1, 1) else nil
		)
		Style.chip(trade.chips, `{tradeState.left or 0} trades left today`)
		if tradePeek then
			peekCard(tradePeek)
		end
		local flash = tradeState.flash
		local theirs = tradeSection(`{tradeState.with} gives`, 2, 170)
		if #tradeState.theirs == 0 then
			Style.text(theirs, "Nothing yet", 15, C.muted, UDim2.fromOffset(200, 20))
		end
		local get, give = {}, {}
		for k, a in tradeState.theirs do
			table.insert(get, a)
			local lit = if flash and not flash.mine and flash.id == a.id then flash.left - since else nil
			tradeCell(theirs, k, a, nameOf(a), nil, nil, if lit and lit > 0 then lit else nil)
		end
		local mine = tradeSection("You give", 3, 170)
		if #tradeState.mine == 0 then
			Style.text(mine, "Pick from your animals below", 15, C.muted, UDim2.fromOffset(260, 20))
		end
		for k, id in tradeState.mine do
			local _, a = StationProgress.find(profile, id)
			if a then
				table.insert(give, a)
				local lit = if flash and flash.mine and flash.id == id then flash.left - since else nil
				tradeCell(mine, k, a, nameOf(a), nil, nil, if lit and lit > 0 then lit else nil)
			end
		end
		-- the fairness meter: a guide, never a block
		local balance, uneven = StationTrade.balance(give, get)
		local meter = Style.card(trade.body, UDim2.new(1, -20, 0, if uneven then 74 else 54))
		meter.LayoutOrder = 4
		local left = Style.text(meter, "You give more", 13, C.muted, UDim2.fromOffset(110, 20))
		left.Position = UDim2.fromOffset(12, 17)
		local right = Style.text(meter, "You get more", 13, C.muted, UDim2.fromOffset(110, 20))
		right.AnchorPoint, right.Position, right.TextXAlignment =
			Vector2.new(1, 0), UDim2.new(1, -12, 0, 17), Enum.TextXAlignment.Right
		local bar = Style.frame(meter, UDim2.new(1, -260, 0, 14), C.off)
		bar.Position = UDim2.fromOffset(130, 20)
		Style.round(bar, 7)
		Style.stroke(bar, C.ink, 2)
		local mark = Style.frame(bar, UDim2.fromOffset(8, 24), C.ink)
		mark.AnchorPoint, mark.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(balance, 0.5)
		Style.round(mark, 3)
		if uneven then
			local warnText = Style.text(
				meter,
				"This trade is very uneven: check before you confirm",
				14,
				C.bad,
				UDim2.new(1, -24, 0, 20)
			)
			warnText.Position, warnText.TextXAlignment = UDim2.fromOffset(12, 46), Enum.TextXAlignment.Center
		end
		local buttons = Style.card(trade.body, UDim2.new(1, -20, 0, if tradeState.stage == "confirm" then 112 else 64))
		buttons.LayoutOrder = 5
		local main: TextButton
		if tradeState.stage == "confirm" then
			-- the window is locked: what goes each way, then Confirm after a moment to look
			local function list(xs: { any }): string
				local out = {}
				for _, x in xs do
					table.insert(out, StationTrade.nameOf(x))
				end
				return if #out > 0 then table.concat(out, ", ") else "nothing"
			end
			local summary = Style.text(
				buttons,
				`You give: {list(give)}\nYou get: {list(get)}`,
				15,
				C.text,
				UDim2.new(1, -24, 0, 40)
			)
			summary.Position, summary.TextWrapped = UDim2.fromOffset(12, 6), true
			local precious = false -- giving a coat or a mythic and up needs a hold
			for _, x in give do
				precious = precious
					or StationRules.coatOf(x) ~= nil
					or (RANK[StationRules.rarity(x)] or 0) >= RANK.mythic
			end
			local words = if tradeState.confirmed
				then `Waiting for {tradeState.with}...`
				elseif confirmIn > 0 then `Confirm in {math.ceil(confirmIn)}s`
				elseif precious then "Hold to confirm"
				else "Confirm trade"
			main = Style.button(buttons, words, function()
				if not precious and confirmIn <= 0 and not tradeState.confirmed then
					send("trade_confirm")
				end
			end, if tradeState.confirmed then "good" elseif confirmIn > 0 then "off" else "primary")
			main.Position, main.Size = UDim2.fromOffset(12, 56), UDim2.new(0.5, -18, 0, 44)
			if confirmIn > 0 then
				again(confirmIn - math.floor(confirmIn) + 0.02)
			elseif precious and not tradeState.confirmed then
				local fill = Style.frame(main, UDim2.fromScale(0, 1), C.good)
				fill.ZIndex = 0
				Style.round(fill, 12)
				local holding = 0
				main.InputBegan:Connect(function(input)
					local t = input.UserInputType
					if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
						return
					end
					holding += 1
					local press = holding
					fill.Size = UDim2.fromScale(0, 1)
					TweenService
						:Create(fill, TweenInfo.new(2, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
						:Play()
					task.delay(2, function()
						if holding == press then
							send("trade_confirm")
						end
					end)
				end)
				main.InputEnded:Connect(function(input)
					local t = input.UserInputType
					if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
						holding += 1
						fill.Size = UDim2.fromScale(0, 1)
					end
				end)
			end
		else
			local waiting = readyIn > 0 and not tradeState.ready
			main = Style.button(
				buttons,
				if tradeState.ready
					then "Ready! (tap to wait)"
					elseif waiting then `Ready in {math.ceil(readyIn)}s`
					else "Ready",
				function()
					send("trade_ready")
				end,
				if tradeState.ready then "good" elseif waiting then "off" else "primary"
			)
			main.Position, main.Size = UDim2.fromOffset(12, 10), UDim2.new(0.5, -18, 0, 44)
			if waiting then
				again(readyIn - math.floor(readyIn) + 0.02)
			end
		end
		local cancel = Style.button(buttons, "Cancel trade", function()
			send("trade_cancel")
		end, "ghost")
		cancel.Position, cancel.Size = main.Position + UDim2.fromScale(0.5, 0), UDim2.new(0.5, -18, 0, 44)
		if tradeState.stage ~= "confirm" then
			local rows = math.max(1, math.ceil(#profile.animals / 5))
			local own = tradeSection("Your animals (training and locked ones stay home)", 6, 50 + rows * 158)
			for k, a in profile.animals do
				local picked = table.find(tradeState.mine, a.id) ~= nil
				local label = nameOf(a) .. (if a.at then " (training)" elseif a.locked then " 🔒" else "")
				tradeCell(
					own,
					k,
					a,
					label,
					if a.at or a.locked
						then nil
						else function()
							send("trade_put", a.id)
						end,
					picked
				)
			end
		end
		return
	end
	tradePeek = nil
	local level = StationProgress.playerLevel(profile)
	local off = profile.trades and profile.trades.off
	Style.chip(trade.chips, "Swap animals with a player in this server")
	Style.chip(trade.chips, `{StationTrade.left(profile, os.time())} trades left today`)
	local requests = Style.button(trade.tabs, if off then "Requests: off" else "Requests: on", function()
		send("trade_off", not off)
	end, if off then "off" else "good", UDim2.fromOffset(196, 44))
	requests.LayoutOrder = 50
	if level < StationTrade.MIN_LEVEL then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64), C.gold)
		card.LayoutOrder = 1
		local t = Style.text(
			card,
			`Trading opens at player level {StationTrade.MIN_LEVEL}. You're level {level}: clear waves for XP.`,
			16,
			C.text,
			UDim2.new(1, -28, 0, 40)
		)
		t.Position, t.TextWrapped = UDim2.fromOffset(14, 12), true
	end
	if invite and os.clock() - invite.at < 30 then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 74), C.gold)
		card.LayoutOrder = 2
		local t = Style.text(card, `{invite.name} wants to trade`, 18, C.text, UDim2.new(0.5, 0, 0, 24))
		t.Position = UDim2.fromOffset(14, 25)
		local yes = Style.button(card, "Accept", function()
			local from = invite.from
			invite = nil
			send("trade_answer", from, true)
		end, "good")
		yes.Position, yes.Size = UDim2.new(0.5, 0, 0, 14), UDim2.new(0.25, -12, 0, 44)
		local no = Style.button(card, "Decline", function()
			local from = invite.from
			invite = nil
			send("trade_answer", from, false)
			redraw.trade()
		end, "ghost")
		no.Position, no.Size = UDim2.new(0.75, 0, 0, 14), UDim2.new(0.25, -12, 0, 44)
	end
	local others = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			others += 1
			local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64))
			card.LayoutOrder = 2 + others
			local t = Style.text(card, other.DisplayName, 18, C.text, UDim2.new(0.45, 0, 0, 24))
			t.Position = UDim2.fromOffset(14, 20)
			local ask = Style.button(card, "Ask to trade", function()
				if send("trade_ask", other.UserId) then
					Style.toast(screen, `Asked {other.DisplayName} to trade`, 2)
				end -- a refusal says why
			end, if level >= StationTrade.MIN_LEVEL then "primary" else "off")
			ask.Position, ask.Size = UDim2.new(0.45, 0, 0, 10), UDim2.new(0.33, -12, 0, 44)
			local block = Style.button(card, "Block", function()
				send("trade_block", other.UserId)
				Style.toast(screen, `{other.DisplayName} can't ask you to trade until you rejoin`, 3)
			end, "ghost")
			block.Position, block.Size = UDim2.new(0.78, 0, 0, 10), UDim2.new(0.22, -12, 0, 44)
		end
	end
	if others == 0 then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64))
		card.LayoutOrder = 3
		local t = Style.text(card, "Nobody else is in this server yet.", 16, C.muted, UDim2.new(1, -28, 0, 24))
		t.Position = UDim2.fromOffset(14, 20)
	end
	-- the history: the newest 20 trades
	local log = if profile.trades then profile.trades.log else {}
	if #log > 0 then
		local shown = math.min(#log, 20)
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 40 + shown * 22))
		card.LayoutOrder = 100
		local head = Style.text(card, "Your recent trades", 16, C.muted, UDim2.new(1, -24, 0, 20))
		head.Position = UDim2.fromOffset(12, 8)
		for k = 1, shown do
			local e = log[k]
			local gave = if #e.gave > 0 then table.concat(e.gave, ", ") else "nothing"
			local got = if #e.got > 0 then table.concat(e.got, ", ") else "nothing"
			local line = Style.text(
				card,
				`{ago(e.at)}, with {e.with}: gave {gave}, got {got}`,
				13,
				C.text,
				UDim2.new(1, -24, 0, 20)
			)
			line.Position, line.TextTruncate = UDim2.fromOffset(12, 10 + k * 22), Enum.TextTruncate.AtEnd
		end
	end
end

-- Waves ---------------------------------------------------------------------------------------------------

local wave = 1
-- The fight's panel: a low bar along the bottom, so it never covers the animals, centred on the screen and
-- clear of the power plates (SHANNON, 2026-11-19). What happened on the left, what to do next on the right.
local result = Style.frame(root, UDim2.new(1, -520, 0, 0), C.sand)
Style.round(result, 18)
Style.stroke(result, C.ink, 3)
result.Name = "WaveResult"
result.AutomaticSize = Enum.AutomaticSize.Y
result.AnchorPoint, result.Position, result.Visible = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -24), false
result.ZIndex = 5
Style.pad(result, 12)
local resultTitle: TextLabel, resultSub: TextLabel
local starRow: Frame, drops: Frame, boonRow: Frame, resultButtons: Frame
local starLabels: { TextLabel } = {}
do
	local resultColumns = Style.list(result, 14, true)
	resultColumns.VerticalAlignment = Enum.VerticalAlignment.Center
	local resultLimit = Instance.new("UISizeConstraint")
	resultLimit.MinSize, resultLimit.MaxSize = Vector2.new(480, 0), Vector2.new(840, 1000)
	resultLimit.Parent = result
	local function panelColumn(width: number, order: number, gap: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size, f.AutomaticSize, f.LayoutOrder = UDim2.new(width, -7, 0, 0), Enum.AutomaticSize.Y, order
		Style.list(f, gap)
		f.Parent = result
		return f
	end
	local info, act = panelColumn(0.52, 1, 4), panelColumn(0.48, 2, 8)
	-- the title, with the stars won beside it (decision 0097): three, popping in one by one
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size, titleRow.LayoutOrder = UDim2.new(1, 0, 0, 36), 1
	titleRow.Parent = info
	resultTitle = Style.text(titleRow, "", 24, C.text, UDim2.new(1, -136, 1, 0))
	starRow = Instance.new("Frame")
	starRow.BackgroundTransparency = 1
	starRow.AnchorPoint, starRow.Position, starRow.Size, starRow.Visible =
		Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0, 132, 1, 0), false
	Style.list(starRow, 4, true)
	starRow.Parent = titleRow
	for i = 1, 3 do
		local star = Style.text(starRow, "★", 34, C.off, UDim2.fromOffset(40, 36))
		star.TextXAlignment, star.LayoutOrder = Enum.TextXAlignment.Center, i
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color = 3, C.ink
		edge.Parent = star
		local size = Instance.new("UIScale")
		size.Parent = star
		starLabels[i] = star
	end
	resultSub = Style.text(info, "", 14, C.muted)
	resultSub.LayoutOrder = 2
	resultSub.TextWrapped, resultSub.AutomaticSize = true, Enum.AutomaticSize.Y
	drops = Instance.new("Frame")
	drops.BackgroundTransparency = 1
	drops.Size, drops.LayoutOrder = UDim2.new(1, 0, 0, 26), 3
	Style.list(drops, 14, true)
	drops.Parent = info
	-- after a win in a run, three boons to pick from, in a panel of their own in the middle of the screen
	-- (SHANNON, 2026-11-24): picking one starts the next wave (decision 0098)
	local boons = Style.frame(root, UDim2.fromOffset(680, 0), C.sand)
	boons.Name, boons.AutomaticSize, boons.ZIndex, boons.Visible = "BoonPanel", Enum.AutomaticSize.Y, 8, false
	boons.AnchorPoint, boons.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42)
	Style.round(boons, 20)
	Style.stroke(boons, C.ink, 3)
	Style.pad(boons, 16)
	Style.list(boons, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local boonsTitle = Style.text(boons, "Pick a boon", 26, C.text, UDim2.new(1, 0, 0, 32))
	boonsTitle.Name, boonsTitle.LayoutOrder, boonsTitle.TextXAlignment = "Title", 1, Enum.TextXAlignment.Center
	local votes = Style.text(boons, "", 14, C.muted, UDim2.new(1, 0, 0, 18))
	votes.Name, votes.LayoutOrder, votes.TextXAlignment = "Votes", 3, Enum.TextXAlignment.Center
	boonRow = Instance.new("Frame")
	boonRow.BackgroundTransparency = 1
	boonRow.Size, boonRow.LayoutOrder, boonRow.Visible = UDim2.new(1, 0, 0, 132), 2, false
	Style.list(boonRow, 10, true)
	boonRow.Parent = boons
	-- while a wave is fought: only a Skip button on the right (the wave is at the top: the stage strip)
	local skip = Style.button(root, "Skip ▶", function()
		local b = root:FindFirstChild("SkipWave")
		if b then
			(b :: GuiObject).Visible = false
		end
		send("wave_done") -- the pay is settled already: the result shows at once
	end, "ghost", UDim2.fromOffset(150, 52))
	skip.Name, skip.Visible, skip.ZIndex = "SkipWave", false, 5
	skip.AnchorPoint, skip.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.36, 0)
	resultButtons = Instance.new("Frame")
	resultButtons.BackgroundTransparency = 1
	resultButtons.Size, resultButtons.LayoutOrder = UDim2.new(1, 0, 0, 44), 2
	Style.list(resultButtons, 8, true)
	resultButtons.Parent = act
end
-- A big title that fades as a fight begins: the wave, and who is in it.
local banner = Style.text(root, "", 56, C.text, UDim2.new(1, 0, 0, 70))
-- high and brief (SHANNON, 2026-11-24): it must not hide the enemies walking in
banner.AnchorPoint, banner.Position, banner.TextTransparency = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.17), 1
banner.TextXAlignment, banner.ZIndex = Enum.TextXAlignment.Center, 6
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Thickness, bannerStroke.Transparency = 4, 1
bannerStroke.Parent = banner
local bannerSub = Style.text(root, "", 22, C.muted, UDim2.new(1, 0, 0, 30))
bannerSub.AnchorPoint, bannerSub.Position, bannerSub.TextTransparency =
	Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.17), 1
bannerSub.TextXAlignment, bannerSub.ZIndex = Enum.TextXAlignment.Center, 6
bannerSub.Position += UDim2.fromOffset(0, 66)
local announced = 0
local function announce(n: number)
	announced += 1
	local mine = announced
	local boss = n % LevelRules.BOSS_EVERY == 0
	local names = {}
	local counts, order = {}, {}
	for _, e in LevelRules.enemies(n) do
		local name = (if e.elite then "Elite " else "") .. (StationConfig.foe(e.s) :: StationConfig.Foe).name
		if counts[name] == nil then
			table.insert(order, name)
		end
		counts[name] = (counts[name] or 0) + 1
	end
	for _, name in order do
		table.insert(names, if counts[name] > 1 then `{name} x{counts[name]}` else name)
	end
	banner.Text = if boss then `BOSS WAVE {n}` else `WAVE {n}`
	banner.TextColor3 = if boss then C.bad else C.text
	bannerSub.Text = table.concat(names, "  -  ")
	banner.TextTransparency, bannerStroke.Transparency, bannerSub.TextTransparency = 0, 0, 0
	task.delay(1.1, function()
		if announced ~= mine then
			return
		end
		local fade = TweenInfo.new(0.35)
		TweenService:Create(banner, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(bannerStroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(bannerSub, fade, { TextTransparency = 1 }):Play()
	end)
end

-- What hatched, and how rare it is (decision 0078): its rarity pops up big in its colour, over the
-- animal's name and, for a rare find, how few eggs give one. A rarer hatch pops bigger and shakes.
local reveal = Style.text(root, "", 64, C.text, UDim2.new(1, 0, 0, 80))
reveal.AnchorPoint, reveal.Position, reveal.TextTransparency = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.3), 1
reveal.TextXAlignment, reveal.ZIndex = Enum.TextXAlignment.Center, 7
local revealStroke = Instance.new("UIStroke")
revealStroke.Thickness, revealStroke.Transparency, revealStroke.Color = 5, 1, Color3.fromRGB(20, 16, 30)
revealStroke.Parent = reveal
local revealScale = Instance.new("UIScale")
revealScale.Parent = reveal
local revealSub = Style.text(root, "", 24, C.text, UDim2.new(1, 0, 0, 60))
revealSub.AnchorPoint, revealSub.TextTransparency = Vector2.new(0.5, 0), 1
revealSub.Position = UDim2.new(0.5, 0, 0.3, 46)
revealSub.TextXAlignment, revealSub.ZIndex = Enum.TextXAlignment.Center, 7
local revealSubStroke = Instance.new("UIStroke")
revealSubStroke.Thickness, revealSubStroke.Transparency, revealSubStroke.Color = 3, 1, Color3.fromRGB(20, 16, 30)
revealSubStroke.Parent = revealSub
local revealed = 0
local BIG: { [string]: number } =
	{ common = 0, uncommon = 0, rare = 1, epic = 1, legendary = 2, mythic = 3, divine = 3, celestial = 4, secret = 5 }
local function showRarity(a: any)
	revealed += 1
	local mine = revealed
	local rarity = StationRules.rarity(a)
	local big = BIG[rarity] or 0
	reveal.Text = string.upper(rarity) .. string.rep("!", big)
	reveal.TextColor3 = RARITY_COLOUR[rarity] or C.text
	local lines = { StationTrade.nameOf(a) }
	local def = StationConfig.egg(a.egg or "")
	if a.v and def then
		for _, drop in def.rare do
			if drop.v == a.v then
				table.insert(lines, `Only 1 in {Format.commas(StationRules.PPM // drop.ppm)} {def.name}s hatches one`)
			end
		end
	end
	if StationRules.coatOf(a) then
		table.insert(lines, `A {string.lower((StationRules.coatOf(a) :: any).name)} coat!`)
	end
	revealSub.Text = table.concat(lines, "\n")
	revealSub.TextColor3 = if StationRules.coatOf(a) then Color3.fromRGB(255, 225, 100) else C.text
	reveal.TextTransparency, revealStroke.Transparency = 0, 0
	revealSub.TextTransparency, revealSubStroke.Transparency = 1, 1
	revealScale.Scale, reveal.Rotation = 0.2, 0
	local pop = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(revealScale, pop, { Scale = 1 + big * 0.12 }):Play()
	task.delay(0.35, function()
		if revealed ~= mine then
			return
		end
		TweenService:Create(revealSub, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		TweenService:Create(revealSubStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
		for i = 1, big * 6 do -- a rarer hatch shakes
			if revealed ~= mine then
				return
			end
			reveal.Rotation = (if i % 2 == 0 then 1 else -1) * big * 1.5 * (1 - i / (big * 6 + 1))
			task.wait(0.04)
		end
		reveal.Rotation = 0
	end)
	task.delay(2.6 + big * 0.6, function()
		if revealed ~= mine then
			return
		end
		local fade = TweenInfo.new(0.7)
		for _, x in { reveal, revealSub } do
			TweenService:Create(x, fade, { TextTransparency = 1 }):Play()
		end
		for _, x in { revealStroke, revealSubStroke } do
			TweenService:Create(x, fade, { Transparency = 1 }):Play()
		end
	end)
end

local fight: (n: number) -> boolean
local began: (n: number) -> ()
local moveName: (species: string) -> ()
local fightTick: (folder: Instance?, showing: boolean) -> ()
local music: (kind: string?) -> ()
local again = Style.button(resultButtons, "", function()
	fight(wave)
end, "primary", UDim2.new(0.5, -4, 1, 0))
local leave = Style.button(resultButtons, "Leave the arena", function()
	hideResult()
	music(nil)
	send("wave_done")
end, "ghost", UDim2.new(0.5, -4, 1, 0))
hideResult = function()
	result.Visible = false
	for _, name in { "BoonPanel", "SkipWave" } do
		local x = root:FindFirstChild(name)
		if x then
			(x :: GuiObject).Visible = false
		end
	end
end
local showStars: (n: number) -> ()
local coinBurst: () -> ()
local offerBoons: (ids: { string }, n: number) -> ()
local function buttons(showAgain: boolean)
	again.Visible = showAgain
	leave.Size = if showAgain then UDim2.new(0.5, -4, 1, 0) else UDim2.fromScale(1, 1)
end

-- The stars pop in one by one: gold for each won, pale for the rest (decision 0097).
showStars = function(n: number)
	starRow.Visible = true
	for i, star in starLabels do
		star.TextColor3, star.TextTransparency = C.off, 1
		local size = star:FindFirstChildOfClass("UIScale") :: UIScale
		size.Scale = 0.2
		task.delay(0.35 * i, function()
			star.TextColor3 = if i <= n then C.gold else C.off
			star.TextTransparency = 0
			TweenService:Create(size, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = if i <= n then 1.15 else 0.9,
			}):Play()
			if i <= n then
				Style.sound("tab")
			end
		end)
	end
end

-- Coins burst out of the result and fly to the coin counter (the counter itself follows the save).
coinBurst = function()
	Style.sound("claim")
	local from = result.AbsolutePosition + Vector2.new(result.AbsoluteSize.X / 2, 30)
	local to = coinsText.AbsolutePosition + Vector2.new(0, coinsText.AbsoluteSize.Y / 2)
	for i = 1, 14 do
		local coin = Instance.new("Frame")
		coin.Size, coin.AnchorPoint, coin.BackgroundColor3 = UDim2.fromOffset(18, 18), Vector2.new(0.5, 0.5), C.gold
		coin.ZIndex = 12
		Style.round(coin, 9)
		Style.stroke(coin, C.ink, 2)
		local spread = Vector2.new(math.random(-140, 140), math.random(-110, -20))
		coin.Position = UDim2.fromOffset(from.X, from.Y)
		coin.Parent = screen
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(coin, out, { Position = UDim2.fromOffset(from.X + spread.X, from.Y + spread.Y) }):Play()
		task.delay(0.3 + i * 0.035, function()
			local fly = TweenService:Create(
				coin,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(10, 10) }
			)
			fly.Completed:Once(function()
				coin:Destroy()
			end)
			fly:Play()
		end)
	end
end

-- Three boons as cards (decision 0098); a rare one is edged in gold. Picking one starts wave `n`.
offerBoons = function(ids: { string }, n: number)
	Style.clear(boonRow)
	boonRow.Visible = true
	local panel = boonRow.Parent :: GuiObject
	panel.Visible = true
	local heading = panel:FindFirstChild("Title") :: TextLabel?
	if heading then
		heading.Text = `Pick a boon for wave {n}`
	end
	local votes = panel:FindFirstChild("Votes") :: TextLabel?
	if votes then
		votes.Text = ""
	end
	for k, id in ids do
		local boon = WaveRuns.boon(id)
		if boon then
			local card = Style.button(boonRow, "", function()
				if not boonRow.Visible then -- a second click while the first is on its way
					return
				end
				-- gone the moment it is picked (SHANNON, 2026-11-24); back only if the server refuses it
				boonRow.Visible, panel.Visible, result.Visible = false, false, false -- the next wave takes a moment to walk out
				local ok, code = request:InvokeServer("boon", id)
				if not ok then
					boonRow.Visible, panel.Visible, result.Visible = true, true, true
					Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
				end
			end, if boon.rare then "primary" else "ghost", UDim2.new(1 / 3, -7, 1, 0))
			card.Name, card.LayoutOrder = boon.name, k
			local title = Style.text(card, boon.name, 20, C.text, UDim2.new(1, -12, 0, 26))
			title.Position, title.TextXAlignment = UDim2.fromOffset(6, 12), Enum.TextXAlignment.Center
			local words = Style.text(card, boon.text, 15, C.muted, UDim2.new(1, -16, 0, 52))
			words.Position, words.TextXAlignment, words.TextWrapped =
				UDim2.fromOffset(8, 42), Enum.TextXAlignment.Center, true
			local go = Style.text(card, `Wave {n} ▶`, 12, C.text, UDim2.new(1, -12, 0, 16))
			go.Position, go.TextXAlignment = UDim2.new(0, 6, 1, -20), Enum.TextXAlignment.Center
		end
	end
end

fight = function(n: number): boolean
	local ok, code = request:InvokeServer("wave", n)
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		return false
	end
	began(n)
	return true
end

began = function(n: number)
	wave = n
	show(nil)
	resultTitle.Text, resultSub.Text = `Wave {n}`, "The fight is on..."
	Style.clear(drops)
	Style.clear(boonRow)
	starRow.Visible, boonRow.Visible, drops.Visible = false, false, false
	hideResult()
	local skip = root:FindFirstChild("SkipWave")
	if skip then
		(skip :: GuiObject).Visible = true
	end
	announce(n)
	music(if n % LevelRules.BOSS_EVERY == 0 then "boss" else "fight")
end

-- The power plates' column, bottom right (decision 0092), with the shield at its top (decision 0097).
local plates = Instance.new("Frame")
plates.Name = "PowerPlates"
plates.BackgroundTransparency = 1
plates.AnchorPoint, plates.Position = Vector2.new(1, 1), UDim2.new(1, -14, 1, -20)
plates.Size, plates.AutomaticSize = UDim2.fromOffset(224, 0), Enum.AutomaticSize.Y
plates.Visible = false
plates.ZIndex = 4
local plateList = Style.list(plates, 12)
plateList.VerticalAlignment = Enum.VerticalAlignment.Bottom
plates.Parent = root
plateList.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Fight feel (decision 0097) ---------------------------------------------------------------------------
-- Words that pop over the fight (PERFECT!, a combo, BLOCKED!, a power attack's name), a flash and a
-- shake, the boss's bar across the top, the shield button and the warnings before enemy power attacks,
-- and the fight's music. Display only: the server decides, the shield button only asks.
do
	local POWER_MOVES: { [string]: string } = {
		lion = "KING'S ROAR",
		jackal = "PACK AMBUSH",
		tortoise = "SHELL SLAM",
		meerkat = "BURROW BLITZ",
		cheetah = "LIGHTNING DASH",
		rhino = "HORN CHARGE",
		flamingo = "PINK CYCLONE",
		giraffe = "SKY KICK",
		elephant = "EARTHQUAKE STOMP",
	}
	-- Roblox-licensed audio (docs/assets/register.md): APM music and stings, Pro Sound Effects
	local AUDIO = {
		fight = "rbxassetid://9048541013",
		boss = "rbxassetid://1848096079",
		win = "rbxassetid://1836473422",
		lose = "rbxassetid://9039598193",
		roar = "rbxassetid://9113980319",
		whoosh = "rbxassetid://9114373663",
		shield = "rbxassetid://9125920594",
		gong = "rbxassetid://9125585534",
	}
	local SoundService = game:GetService("SoundService")
	local audio: { [string]: Sound } = {}
	local function sound(name: string, volume: number?): Sound
		local s = audio[name]
		if s == nil then
			s = Instance.new("Sound")
			local made = s :: Sound
			made.SoundId = AUDIO[name]
			made.Parent = SoundService
			audio[name] = made
		end
		local out = s :: Sound
		out.Volume = volume or 0.6
		return out
	end
	local function fxSound(name: string, volume: number?)
		sound(name, volume):Play()
	end

	local track: Sound? = nil
	music = function(kind: string?)
		local old = track
		if old then
			local fade = TweenService:Create(old, TweenInfo.new(0.8), { Volume = 0 })
			fade.Completed:Once(function()
				if track ~= old then
					old:Stop()
				end
			end)
			fade:Play()
		end
		track = nil
		if kind == "fight" or kind == "boss" then
			local s = sound(kind, 0.25)
			s.Looped = true
			s.TimePosition = 0
			s:Play()
			track = s
			fxSound("gong", 0.45)
		elseif kind == "win" or kind == "lose" then
			fxSound(kind, 0.7)
		end
	end

	local function jolt(strength: number)
		player:SetAttribute("CamShake", strength) -- ArenaCamera reads these
		player:SetAttribute("CamShakeAt", os.clock())
	end

	local whiteout = Instance.new("Frame")
	whiteout.Name = "Flash"
	whiteout.Size, whiteout.BackgroundColor3, whiteout.BackgroundTransparency =
		UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1
	whiteout.BorderSizePixel, whiteout.ZIndex, whiteout.Active = 0, 9, false
	whiteout.Parent = root
	local function flashScreen(strength: number)
		whiteout.BackgroundTransparency = 1 - 0.5 * strength
		TweenService:Create(whiteout, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end

	local function bigWords(at: UDim2, size: number, stroke: Color3): (TextLabel, UIStroke, UIScale)
		local t = Style.text(root, "", size, C.gold, UDim2.new(1, 0, 0, size + 20))
		t.AnchorPoint, t.Position, t.TextTransparency = Vector2.new(0.5, 0.5), at, 1
		t.TextXAlignment, t.ZIndex = Enum.TextXAlignment.Center, 8
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color, edge.Transparency = 5, stroke, 1
		edge.Parent = t
		local scale = Instance.new("UIScale")
		scale.Parent = t
		return t, edge, scale
	end
	local popText, popEdge, popScale = bigWords(UDim2.fromScale(0.5, 0.36), 60, C.ink)
	local moveText, moveEdge, moveScale = bigWords(UDim2.fromScale(0.5, 0.25), 42, C.bad)
	moveText.TextColor3 = Color3.new(1, 1, 1)
	local popped, moved = 0, 0
	local function popWords(words: string, colour: Color3, big: number)
		popped += 1
		local mine = popped
		popText.Text, popText.TextColor3 = words, colour
		popText.TextTransparency, popEdge.Transparency, popScale.Scale = 0, 0, 0.3
		TweenService
			:Create(popScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = big })
			:Play()
		task.delay(0.9, function()
			if popped == mine then
				TweenService:Create(popText, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				TweenService:Create(popEdge, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		end)
	end
	moveName = function(species: string)
		local words = POWER_MOVES[species]
		if words == nil then
			return
		end
		moved += 1
		local mine = moved
		moveText.Text = `{words}!`
		moveText.TextTransparency, moveEdge.Transparency, moveScale.Scale = 0, 0, 1.6
		moveText.Position = UDim2.new(0.5, -40, 0.25, 0)
		local snap = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(moveScale, snap, { Scale = 1 }):Play()
		TweenService:Create(moveText, snap, { Position = UDim2.fromScale(0.5, 0.25) }):Play()
		fxSound("whoosh", 0.5)
		task.delay(1.1, function()
			if moved == mine then
				TweenService:Create(moveText, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				TweenService:Create(moveEdge, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end)
	end
	player:GetAttributeChangedSignal("FxPopAt"):Connect(function()
		local words, kind = player:GetAttribute("FxPop"), player:GetAttribute("FxPopKind")
		if type(words) ~= "string" then
			return
		elseif kind == "shield" then
			popWords(words, C.info, 1)
		elseif kind == "big" then
			popWords(words, C.bad, 1.35)
			flashScreen(1)
			jolt(1)
			Style.sound("claim")
		else
			popWords(words, C.gold, 1.15)
			flashScreen(0.6)
			jolt(0.6)
			Style.sound("claim")
		end
	end)

	-- the boss's bar: it slams in as the dragon lands
	local bossBar = Style.frame(root, UDim2.fromOffset(440, 66), C.night)
	Style.round(bossBar, 14)
	Style.stroke(bossBar, C.ink, 3)
	bossBar.AnchorPoint, bossBar.Position, bossBar.Visible, bossBar.ZIndex =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 14), false, 6
	local bossName = Style.text(bossBar, "", 20, C.hex, UDim2.new(1, -24, 0, 26))
	bossName.Position, bossName.TextXAlignment = UDim2.fromOffset(12, 6), Enum.TextXAlignment.Center
	local bossHp, setBossHp = Style.bar(bossBar, UDim2.new(1, -24, 0, 16), C.bad)
	bossHp.Position = UDim2.fromOffset(12, 38)
	local bossScale = Instance.new("UIScale")
	bossScale.Parent = bossBar
	local bossOf: Model? = nil

	-- the shield: a round button left of the plates (or F); it pulses while an enemy power attack is coming
	local tellUntil = 0
	local shieldButton = Style.button(plates, "", function() end, "ghost", UDim2.fromOffset(96, 96))
	shieldButton.Name, shieldButton.LayoutOrder = "Shield", -1
	shieldButton.Visible, shieldButton.TextSize, shieldButton.ZIndex = false, 30, 4
	Style.radius(shieldButton, 48)
	local shieldIcon = Instance.new("ImageLabel")
	shieldIcon.BackgroundTransparency, shieldIcon.Image = 1, "rbxassetid://97488070836179" -- assets/stations/icons/shield.png
	shieldIcon.AnchorPoint, shieldIcon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.46)
	shieldIcon.Size, shieldIcon.ZIndex = UDim2.fromScale(0.72, 0.72), 5
	shieldIcon.Parent = shieldButton
	local shieldKey = Style.chip(shieldButton, "F", C.ink, Color3.new(1, 1, 1))
	shieldKey.AnchorPoint, shieldKey.Position, shieldKey.ZIndex = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, 4), 6
	local shieldLook = ""
	local function raiseShield()
		if not shieldButton.Visible then
			return
		end
		local ready = player:GetAttribute("ShieldReady")
		if type(ready) == "number" and Workspace:GetServerTimeNow() < ready then
			Style.sound("denied")
			return
		end
		local ok, code = request:InvokeServer("shield")
		if ok then
			fxSound("shield", 0.5)
		elseif code == "shield_wait" then
			Style.sound("denied")
		end
	end
	shieldButton.Activated:Connect(raiseShield)
	UserInputService.InputBegan:Connect(function(input, used)
		if not used and input.KeyCode == Enum.KeyCode.F then
			raiseShield()
		end
	end)
	-- the bubble round the team while the shield is up
	player:GetAttributeChangedSignal("ShieldAt"):Connect(function()
		local at = player:GetAttribute("ShieldAt")
		if type(at) ~= "number" then
			return
		end
		task.delay(math.max(0, at - Workspace:GetServerTimeNow()), function()
			local folder = Workspace:FindFirstChild(player:GetAttribute("FightFolder") or `WaveShow{player.UserId}`)
			for _, m in if folder then folder:GetChildren() else {} do
				local hp = m:GetAttribute("Hp")
				if m:IsA("Model") and m:GetAttribute("Side") == 1 and type(hp) == "number" and hp > 0 then
					local cf, size = m:GetBoundingBox()
					local ball = Instance.new("Part")
					ball.Shape, ball.Material, ball.Color = Enum.PartType.Ball, Enum.Material.ForceField, C.info
					ball.Size, ball.CFrame = Vector3.one * math.max(size.X, size.Y, size.Z) * 1.1, cf
					ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow =
						true, false, false, false, false
					ball.Parent = Workspace
					TweenService:Create(ball, TweenInfo.new(BattleRules.SHIELD_SECONDS + 0.3), { Transparency = 1 })
						:Play()
					Debris:AddItem(ball, BattleRules.SHIELD_SECONDS + 0.4)
				end
			end
		end)
	end)

	-- An enemy power attack is coming (the server sets TellAt, when it lands): a disc under the attacker,
	-- orange while it is too soon to shield, red and closing while a shield now would be up when it lands.
	local function warnOf(m: Model)
		local at = m:GetAttribute("TellAt")
		if type(at) ~= "number" then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local deadline = at - FightFx.TAP_AHEAD - now -- the last moment a press still raises it in time
		local opens = deadline - BattleRules.SHIELD_SECONDS + 0.1
		if deadline <= 0 then
			return
		end
		local cf, size = m:GetBoundingBox()
		local r = math.max(size.X, size.Z) * 0.8
		local disc = Instance.new("Part")
		disc.Shape, disc.Material, disc.Color, disc.Transparency =
			Enum.PartType.Cylinder, Enum.Material.Neon, C.accent, 0.35
		disc.Size = Vector3.new(0.2, r * 2.4, r * 2.4)
		disc.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.3, cf.Position.Z)
			* CFrame.Angles(0, 0, math.pi / 2)
		disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
		disc.Parent = Workspace
		TweenService:Create(disc, TweenInfo.new(deadline, Enum.EasingStyle.Linear), { Size = Vector3.new(0.2, r, r) })
			:Play()
		task.delay(math.max(0, opens), function()
			disc.Color = C.bad
			tellUntil = os.clock() + math.min(deadline, BattleRules.SHIELD_SECONDS)
		end)
		task.delay(deadline, function()
			disc.Color = C.night
			TweenService
				:Create(disc, TweenInfo.new(math.max(0.1, at - Workspace:GetServerTimeNow())), { Transparency = 1 })
				:Play()
		end)
		Debris:AddItem(disc, at - now + 0.5)
	end

	-- knockouts (decision 0101): a counter that pops, and coins out of each fallen foe to the counter
	local koText, koEdge, koScale = bigWords(UDim2.new(0.5, 0, 0, 120), 34, C.ink)
	koText.TextColor3 = C.gold
	-- in the top right corner, out of the fight's way
	koText.AnchorPoint, koText.Position, koText.Size =
		Vector2.new(1, 0), UDim2.new(1, -22, 0, 108), UDim2.fromOffset(220, 54)
	koText.TextXAlignment = Enum.TextXAlignment.Right
	local kos = 0
	local fallen: { [Model]: boolean } = {}
	local function knockout(m: Model)
		kos += 1
		koText.Text = `{kos} KO!`
		koText.TextTransparency, koEdge.Transparency, koScale.Scale = 0, 0, 1.4
		TweenService:Create(koScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		local camera = Workspace.CurrentCamera
		local at, seen = camera:WorldToViewportPoint(m:GetPivot().Position)
		if not seen then
			return
		end
		local to = coinsText.AbsolutePosition + Vector2.new(0, coinsText.AbsoluteSize.Y / 2)
		for i = 1, 3 do
			local coin = Instance.new("Frame")
			coin.Size, coin.AnchorPoint, coin.BackgroundColor3 = UDim2.fromOffset(14, 14), Vector2.new(0.5, 0.5), C.gold
			coin.ZIndex, coin.Position = 12, UDim2.fromOffset(at.X + math.random(-16, 16), at.Y + math.random(-16, 4))
			Style.round(coin, 7)
			Style.stroke(coin, C.ink, 2)
			coin.Parent = screen
			local fly = TweenService:Create(
				coin,
				TweenInfo.new(0.6 + i * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(8, 8) }
			)
			fly.Completed:Once(function()
				coin:Destroy()
			end)
			fly:Play()
		end
	end
	-- the power bar: each side's power still standing (its fighters' power x their HP left), in the plates'
	-- column between the shield and the team's plates, as wide as a plate
	local tug = Style.frame(plates, UDim2.fromOffset(224, 13), C.bad)
	tug.Name, tug.LayoutOrder, tug.Visible, tug.ZIndex = "PowerBar", 0, false, 6
	Style.round(tug, 7)
	Style.stroke(tug, C.ink, 3)
	local ourSide = Style.frame(tug, UDim2.fromScale(0.5, 1), C.good)
	Style.round(ourSide, 7)
	local tugLabel = Style.text(tug, "", 11, Color3.new(1, 1, 1), UDim2.fromScale(1, 1))
	tugLabel.TextXAlignment, tugLabel.ZIndex = Enum.TextXAlignment.Center, 8
	local powerCache: { [Model]: number } = {}
	local function powerOf(m: Model, side: number): number
		local got = powerCache[m]
		if got == nil then
			local stats = {}
			for _, stat in StationConfig.STATS do
				local x = m:GetAttribute(stat)
				stats[stat] = if type(x) == "number" then x else 0
			end
			local id = m:GetAttribute(if side == 1 then "Species" else "FoeId")
			got = if type(id) == "string" then BattleRules.powerOf({ s = id, stats = stats :: any }, side) else 0
			powerCache[m] = got
		end
		return got :: number
	end

	local warned: { [Model]: boolean } = {}
	-- Every tick of the fight (from the plates' loop): hook new enemies' warnings, the boss's bar, the
	-- shield button, and the music building as the enemies fall.
	local docked = false
	fightTick = function(folder: Instance?, showing: boolean)
		shieldButton.Visible = showing
		if showing ~= docked then -- the dock (the Menu button and its open column) centred on the left edge in a fight
			docked = showing
			local tall = dock.Size.Y.Offset + 160 - 104 -- from the Menu button's top to the open column's foot
			local down = math.max(0, (root.Size.Y.Offset - tall) / 2 - 104)
			TweenService:Create(nav, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Position = if showing then UDim2.fromOffset(0, down) else UDim2.new(),
			}):Play()
		end
		-- knockouts and the power bar
		local us, them = 0, 0
		for _, m in if folder then folder:GetChildren() else {} do
			local side, hp, max = m:GetAttribute("Side"), m:GetAttribute("Hp"), m:GetAttribute("MaxHp")
			if m:IsA("Model") and type(side) == "number" and type(hp) == "number" and type(max) == "number" then
				local left = math.max(0, hp) / math.max(1, max)
				if side == 1 then
					us += powerOf(m, 1) * left
				else
					them += powerOf(m, 2) * left
					if hp <= 0 and not fallen[m] then
						fallen[m] = true
						knockout(m)
					end
				end
			end
		end
		tug.Visible = showing and us + them > 0
		if us + them > 0 then
			ourSide.Size = UDim2.fromScale(math.clamp(us / (us + them), 0.02, 0.98), 1)
			tugLabel.Text = `⚡ {Format.commas(math.floor(us))}  vs  {Format.commas(math.floor(them))}`
		end
		if not showing and kos > 0 then -- the fight is over: the count starts again next time
			kos = 0
			koText.TextTransparency, koEdge.Transparency = 1, 1
			table.clear(fallen)
			table.clear(powerCache)
		end
		local boss: Model? = nil
		local left, total = 0, 0
		for _, m in if folder then folder:GetChildren() else {} do
			if m:IsA("Model") and m:GetAttribute("Side") == 2 then
				if not warned[m] then
					warned[m] = true
					m:GetAttributeChangedSignal("TellAt"):Connect(function()
						warnOf(m)
					end)
					m.Destroying:Connect(function()
						warned[m] = nil
					end)
				end
				local hp, max = m:GetAttribute("Hp"), m:GetAttribute("MaxHp")
				if type(hp) == "number" and type(max) == "number" then
					left += math.max(0, hp)
					total += max
				end
				if m:GetAttribute("Boss") == true then
					boss = m
				end
			end
		end
		if track and total > 0 then
			track.Volume = 0.25 + 0.25 * (1 - left / total)
		end
		-- the boss
		if boss ~= bossOf then
			bossOf = boss
			bossBar.Visible = false
			if boss then
				local landAt = boss:GetAttribute("LandAt")
				task.delay(
					if type(landAt) == "number" then math.max(0, landAt - Workspace:GetServerTimeNow()) else 0,
					function()
						if bossOf ~= boss then
							return
						end
						bossName.Text = string.upper(tostring(boss:GetAttribute("FoeName") or "Boss"))
						bossBar.Visible, bossScale.Scale = true, 1.8
						TweenService
							:Create(bossScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Scale = 1,
							})
							:Play()
						fxSound("roar", 0.8)
						jolt(1)
					end
				)
			end
		end
		if boss then
			local hp, max = boss:GetAttribute("Hp"), boss:GetAttribute("MaxHp")
			if type(hp) == "number" and type(max) == "number" then
				setBossHp(math.max(0, hp) / math.max(1, max))
			end
		end
		-- the stage (decision 0106): its number and name and ten pips (cleared, this wave, its boss), at the
		-- top, under the boss's bar once there is one. Made on first use and found by name: the HUD's main
		-- chunk is close to Luau's 200 locals.
		local strip = root:FindFirstChild("StageStrip") :: Frame?
		if strip == nil then
			local made = Style.frame(root, UDim2.fromOffset(360, 58), C.night)
			made.Name, made.AnchorPoint, made.ZIndex = "StageStrip", Vector2.new(0.5, 0), 6
			Style.round(made, 12)
			Style.stroke(made, C.ink, 3)
			local title = Style.text(made, "", 15, C.sand, UDim2.new(1, -20, 0, 20))
			title.Name, title.Position, title.TextXAlignment =
				"Title", UDim2.fromOffset(10, 5), Enum.TextXAlignment.Center
			local row = Instance.new("Frame")
			row.Name, row.BackgroundTransparency = "Pips", 1
			row.Size, row.Position = UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 29)
			row.Parent = made
			Style.list(row, 4, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
			for i = 1, LevelRules.STAGE do
				local pip = Style.frame(row, UDim2.fromOffset(if i == LevelRules.STAGE then 46 else 28, 22), C.night)
				pip.Name, pip.LayoutOrder = `Pip{i}`, i
				Style.round(pip, 6)
				Style.stroke(pip, C.ink, 2)
				local label = Style.text(pip, "", 12, C.sand, UDim2.fromScale(1, 1))
				label.Name, label.TextXAlignment = "Label", Enum.TextXAlignment.Center
			end
			strip = made
		end
		local bar = strip :: Frame
		local fought = player:GetAttribute("FightWave")
		bar.Visible = showing and type(fought) == "number"
		bar.Position = UDim2.new(0.5, 0, 0, if bossBar.Visible then 90 else 14)
		if type(fought) == "number" and bar:GetAttribute("Wave") ~= fought then
			bar:SetAttribute("Wave", fought)
			local st = LevelRules.stage(fought)
			local title = bar:FindFirstChild("Title") :: TextLabel
			title.Text = `STAGE {st.n} · {string.upper(st.name)} · WAVE {fought}`
			for i = 1, LevelRules.STAGE do
				local pip = (bar:FindFirstChild("Pips") :: Frame):FindFirstChild(`Pip{i}`) :: Frame
				local label = pip:FindFirstChild("Label") :: TextLabel
				local w, isBoss = st.first + i - 1, i == LevelRules.STAGE
				pip.BackgroundColor3 = if w < fought
					then C.good
					elseif w == fought then C.accent
					elseif isBoss then C.bad
					else C.night
				local edge = pip:FindFirstChildOfClass("UIStroke")
				if edge then
					edge.Color = if w == fought then C.sand else C.ink
				end
				label.Text = if isBoss then "BOSS" elseif w <= fought then tostring(w) else ""
				label.TextColor3 = if w <= fought then C.ink else C.sand
			end
		end
		-- the shield button: cooling down, warning (flashing), or ready
		local ready = player:GetAttribute("ShieldReady")
		local wait = if type(ready) == "number" then ready - Workspace:GetServerTimeNow() else 0
		local look = if wait > 0
			then `wait {math.ceil(wait)}`
			elseif os.clock() < tellUntil then (if math.floor(os.clock() * 6) % 2 == 0 then "warn" else "warn2")
			else "ready"
		if look ~= shieldLook then
			shieldLook = look
			shieldButton.Text = if wait > 0 then `{math.ceil(wait)}` else ""
			shieldIcon.ImageTransparency = if wait > 0 then 0.75 else 0
			Style.kind(
				shieldButton,
				if wait > 0
					then "off"
					elseif look == "warn" then "danger"
					elseif look == "warn2" then "primary"
					else "info"
			)
		end
	end
end

-- Power attacks in a fight (decision 0092): a plate for each of the team's animals, bottom right, with
-- its name, its number key and its mana (the power meter), nothing else. A full meter lights the plate and
-- pops its quick press up on the screen (decision 0106, BattleRules.pressOf): the ring closes on its mark,
-- the needle swings through the gold, the chain's 1-2-3 are tapped in order, the mash counts presses. Tap
-- the pop-up, the plate or the key. The server decides: a refused tap does nothing.

type Plate = {
	button: TextButton,
	power: (number) -> (),
	mana: TextLabel,
	full: boolean,
	press: string,
	label: string, -- the animal's name
	fullAt: number, -- os.clock() when this client saw the meter fill
	close: number, -- seconds after that when the press is due (the ring's close, the needle's first crossing)
	sent: boolean, -- its power tap is on its way
	presses: number, -- a mash's count
	mashUntil: number,
	-- its pop-up while the meter is full, and the parts of it that change
	card: TextButton?,
	hand: Frame?, -- the needle's
	count: TextLabel?, -- the mash's presses
	marks: { TextButton }, -- the chain's 1-2-3
	marked: number,
	parts: any, -- its pop-up's moving parts (PressPops.card)
	holdAt: number?, -- the ring: os.clock() when the hold began
	model: Model?, -- the animal on the field, which its pop-up stands over (PressPops)
	keys: { Enum.KeyCode }?, -- its card's keys (PressPops.claim)
}
local plateOf: { [number]: Plate } = {}
-- Quick presses and clicks (decision 0106) keep their functions here, set in the block below: the HUD's
-- main chunk is close to Luau's 200 locals.
local Press: {
	SWING: number, -- how far the needle swings from the middle of its bar (1 wide)
	tap: (slot: number) -> (), -- the plate, its pop-up or its key is pressed
	hold: (slot: number, down: boolean) -> (), -- the ring's key or pop-up pressed or let go
	on: (p: Plate, slot: number) -> (), -- its meter has just filled
	off: (p: Plate) -> (), -- it is empty again, or gone
	catcher: TextButton, -- the click layer
	pops: any, -- PressPops: stands the pop-ups over their animals (decision 0109)
} =
	{ SWING = 0.46 } :: any

local function firePower(slot: number, presses: number?)
	local p = plateOf[slot]
	if p == nil or not p.full or p.sent then
		return
	end
	p.sent = true
	local failed = presses == BattleRules.FAILED
	if p.card then -- done: it bursts (red when messed up) and is gone at once, never waiting for the attack to play
		Press.pops.fired(p.card, p.card:GetAttribute("Hot") == true, failed)
		p.card = nil
	end
	local ok, code = request:InvokeServer("power", slot, presses)
	for _ = 1, 20 do -- turned down (no foe between rushes, a moment early): sent again, so a press is never lost
		if ok or failed or code == "no_fight" or not p.full then
			break
		end
		task.wait(0.25)
		ok, code = request:InvokeServer("power", slot, presses)
	end
	if ok then
		Style.sound("claim")
	else
		p.sent = false
		if p.full and not failed then -- turned down for good while the meter is still full: a fresh card to press again
			Press.on(p, slot)
		end
	end
end

local function plate(slot: number, label: string, press: string): Plate
	local b = Style.button(plates, "", function()
		Press.tap(slot)
	end, "ghost", UDim2.fromOffset(224, 60))
	b.LayoutOrder = slot
	local name = Style.text(b, label, 17, C.text, UDim2.new(1, -60, 0, 22))
	name.Position, name.TextTruncate = UDim2.fromOffset(12, 6), Enum.TextTruncate.AtEnd
	local key = Style.chip(b, tostring(slot))
	key.AnchorPoint, key.Position = Vector2.new(1, 0), UDim2.new(1, -8, 0, 6)
	local bar, setPower = Style.bar(b, UDim2.new(1, -24, 0, 18), C.accent)
	bar.Position = UDim2.fromOffset(12, 33)
	local mana = Style.text(bar, "", 13, C.ink, UDim2.fromScale(1, 1))
	mana.TextXAlignment, mana.ZIndex = Enum.TextXAlignment.Center, 20
	return {
		button = b,
		power = setPower,
		mana = mana,
		full = false,
		press = press,
		label = label,
		fullAt = 0,
		close = 0,
		sent = false,
		presses = 0,
		mashUntil = 0,
		marks = {},
		marked = 0,
	}
end

do
	-- Clicks (decision 0106): a click anywhere on the fight that is not on a button strikes the front line.
	-- The server lands each strike FightFx.TAP_AHEAD later; here a click is answered at once (a slash on the
	-- nearest foe, a tick, the hit count), and the clicks go up in batches (`strike`) every STRIKE_SEND
	-- seconds. The quick presses' pop-ups live here too, above the clicks. A screen of its own, under the HUD.
	-- Where the needle is `age` seconds after the meter filled: through the middle at `close`, then every
	-- NEEDLE_EVERY after it, swinging out and back between (the server's crossings: BattleRules.perfect).
	local function needleAt(age: number, close: number): number
		local x = (age - close) / BattleRules.NEEDLE_EVERY
		local k = math.floor(x)
		return 0.5 + Press.SWING * (if k % 2 == 0 then 1 else -1) * math.sin(math.pi * (x - k))
	end

	local clickFx = Instance.new("ScreenGui")
	clickFx.Name, clickFx.ResetOnSpawn, clickFx.IgnoreGuiInset = "StationsClicks", false, true
	clickFx.DisplayOrder = screen.DisplayOrder - 1
	clickFx.Parent = player:WaitForChild("PlayerGui")
	local catcher = Instance.new("TextButton")
	catcher.Name, catcher.Text, catcher.AutoButtonColor = "Strike", "", false
	catcher.BackgroundTransparency, catcher.Size, catcher.Visible = 1, UDim2.fromScale(1, 1), false
	catcher.Parent = clickFx
	local hitCount = Style.text(root, "", 44, C.sand, UDim2.fromOffset(280, 56))
	hitCount.AnchorPoint, hitCount.Position, hitCount.ZIndex = Vector2.new(1, 0.5), UDim2.new(1, -24, 0.3, 0), 5
	hitCount.TextXAlignment, hitCount.Visible = Enum.TextXAlignment.Right, false
	Style.outline(hitCount)
	local STRIKE_SEND, CHAIN_HIT = 0.25, 0.8 -- seconds between sends; clicks this close keep the hit count
	local clicks, hits, lastClick = 0, 0, -math.huge

	-- the standing foes nearest the team (the front line first), up to `n`, by their unseen Hit boxes
	local function frontFoes(n: number): { BasePart }
		local folder = Workspace:FindFirstChild(player:GetAttribute("FightFolder") or `WaveShow{player.UserId}`)
		local ours, foes = {}, {}
		for _, m in if folder then folder:GetChildren() else {} do
			local hit, hp = m:FindFirstChild("Hit"), m:GetAttribute("Hp")
			if m:IsA("Model") and hit and hit:IsA("BasePart") and type(hp) == "number" and hp > 0 then
				if m:GetAttribute("Side") == 1 then
					if (m:GetAttribute("Owner") or player.UserId) == player.UserId then -- the player's own team
						table.insert(ours, hit.Position)
					end
				elseif m:GetAttribute("Side") == 2 then
					table.insert(foes, hit)
				end
			end
		end
		if #ours == 0 then
			return {}
		end
		local mid = Vector3.zero
		for _, at in ours do
			mid += at / #ours
		end
		table.sort(foes, function(a, b)
			return (a.Position - mid).Magnitude < (b.Position - mid).Magnitude
		end)
		return table.move(foes, 1, math.min(n, #foes), 1, {})
	end

	local function slash(at: Vector3)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local v, on = camera:WorldToViewportPoint(at)
		if not on then
			return
		end
		local k = uiScale.Scale
		local bar = Style.frame(clickFx, UDim2.fromOffset(44 * k, 6 * k), C.card)
		bar.AnchorPoint, bar.Rotation = Vector2.new(0.5, 0.5), math.random(-40, 40)
		bar.Position = UDim2.fromOffset(v.X + math.random(-14, 14) * k, v.Y + math.random(-14, 14) * k)
		Style.round(bar, 3)
		TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(96 * k, 2 * k),
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(bar, 0.25)
	end

	catcher.Activated:Connect(function()
		-- clicks count only once the wave has started, not while the enemies walk in (SHANNON, 2026-11-24)
		if not plates.Visible or Workspace:GetServerTimeNow() < (player:GetAttribute("FightFrom") or math.huge) then
			return
		end
		clicks = math.min(clicks + 1, 40)
		local now = os.clock()
		hits = if now - lastClick <= CHAIN_HIT then hits + 1 else 1
		lastClick = now
		Style.sound("hover")
		local foe = frontFoes(1)[1]
		if foe then
			slash(foe.Position)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(STRIKE_SEND)
			if clicks > 0 then
				local n = math.min(clicks, 20)
				clicks -= n
				task.spawn(function()
					request:InvokeServer("strike", n)
				end)
			end
		end
	end)

	-- the pop-ups stand over their animals (decision 0109, SHANNON's pick B): PressPops places them
	Press.pops = require(script.Parent:WaitForChild("PressPops"))
	Press.pops.init(clickFx)

	local function pressOff(p: Plate)
		if p.card then
			p.card:Destroy()
		end
		if p.keys then
			Press.pops.free(p.keys)
		end
		p.card, p.hand, p.count, p.marks, p.marked, p.keys = nil, nil, nil, {}, 0, nil
	end

	-- The chain: the next of its 1-2-3 is struck (tapped, or the pop-up, the plate or the key); the last fires.
	local function chainHit(p: Plate, slot: number, k: number)
		if not p.full or p.sent or k ~= p.marked + 1 then
			return
		end
		p.marked = k
		if p.card and p.marks[k] then
			Press.pops.press(p.card, p.marks[k], Press.pops.GREEN)
			if k >= #p.marks then
				p.card:SetAttribute(
					"Hot",
					os.clock() - p.fullAt <= BattleRules.PERFECT_AT + BattleRules.PERFECT_LATE - 0.3
				)
			end
		end
		for i, m in p.marks do
			local e = m:FindFirstChildOfClass("UIStroke")
			if e then
				e.Color = if i <= k then Press.pops.GREEN elseif i == k + 1 then Press.pops.GOLD else Press.pops.EDGE
			end
			if i <= k then
				m.Text = "✓"
			end
		end
		local foe = frontFoes(1)[1]
		if foe then
			slash(foe.Position)
		end
		if k >= #p.marks then
			firePower(slot)
		end
	end

	-- A meter has just filled: its press pops up (decision 0106). Its timing is the ring's (decision 0097): due
	-- when a tap would land BattleRules.PERFECT_AT after the fill, a little earlier for the player's ping.
	local function pressOn(p: Plate, slot: number)
		pressOff(p)
		local ping = math.min(0.25, player:GetNetworkPing() * 2)
		p.fullAt, p.close = os.clock(), math.max(0.2, BattleRules.PERFECT_AT - FightFx.TAP_AHEAD - ping)
		p.sent, p.presses = false, 0
		-- the reference's look (decision 0109, amended): PressPops draws the card
		local k = uiScale.Scale * 0.85 -- over the animals: compact
		local wide = 2 * Press.SWING * math.sin(math.pi * BattleRules.PERFECT_EARLY / BattleRules.NEEDLE_EVERY)
		p.keys = Press.pops.claim(p.press)
		local card, parts = Press.pops.card(clickFx, p.press, Press.pops.names(p.keys :: { Enum.KeyCode }), k, wide, {
			press = function()
				Press.tap(slot)
			end,
			down = function()
				Press.hold(slot, true)
			end,
			up = function()
				Press.hold(slot, false)
			end,
			mark = function(i: number)
				chainHit(p, slot, i)
			end,
		})
		p.parts, p.holdAt, p.hand, p.marks = parts, nil, parts.hand, parts.marks
		if p.press == "mash" then -- the presses go up together at MASH_COUNT, or when time is up
			local window = math.max(0.5, BattleRules.MASH_BY - FightFx.TAP_AHEAD - ping)
			p.mashUntil = p.fullAt + window
			task.delay(window, function()
				if p.full and not p.sent and p.presses > 0 then -- short of MASH_FAIL: messed up
					firePower(slot, if p.presses < BattleRules.MASH_FAIL then BattleRules.FAILED else p.presses)
				end
			end)
		end
		p.card = card
		Press.pops.attach(card, p.model, p.press, k)
	end

	local function pressPlate(slot: number)
		local p = plateOf[slot]
		if p == nil or not p.full or p.sent then
			return
		end
		if p.press == "ring" then
			if p.holdAt == nil then -- the plate tapped, not held: it fires now, never a Perfect
				firePower(slot, 0)
			end
		elseif p.press == "mash" then
			p.presses += 1
			Style.sound("hover")
			if p.parts and p.parts.fill then
				p.parts.fill.Size = UDim2.fromScale(math.min(1, p.presses / BattleRules.MASH_COUNT), 1)
				Press.pops.press(p.card, p.parts.key, nil, true)
				p.card:SetAttribute("Hot", p.presses >= BattleRules.MASH_COUNT)
			end
			if p.presses >= BattleRules.MASH_COUNT or os.clock() > p.mashUntil then
				firePower(slot, p.presses)
			end
		elseif p.press == "chain" then
			chainHit(p, slot, p.marked + 1)
		elseif p.press == "needle" and p.card and p.card:GetAttribute("Hot") ~= true then
			firePower(slot, BattleRules.FAILED) -- stopped outside the green
		else
			firePower(slot)
		end
	end

	-- The ring (decision 0109, amended): held while it fills; let go, it fires with how long it was held (in
	-- tenths, which the server caps by its own clock), and held to full it fires itself, a Perfect.
	local function holdRing(slot: number, down: boolean)
		local p = plateOf[slot]
		if p == nil or not p.full or p.sent or p.press ~= "ring" then
			return
		end
		if down and p.holdAt == nil then
			p.holdAt = os.clock()
			Style.sound("hover")
			if p.card and p.parts and p.parts.key then
				Press.pops.press(p.card, p.parts.key)
			end
		elseif not down and p.holdAt then
			local tenths = math.clamp(math.floor((os.clock() - p.holdAt) * 10), 0, 30)
			p.holdAt = nil
			firePower(slot, if tenths < BattleRules.RING_FAIL then BattleRules.FAILED else tenths) -- let go too soon
		end
	end

	-- the needles swing; the hit count shows while the clicks keep coming
	RunService.RenderStepped:Connect(function()
		if not plates.Visible then
			return
		end
		for slot, p in plateOf do
			if p.hand then
				p.hand.Position = UDim2.fromScale(needleAt(os.clock() - p.fullAt, p.close), 0.5)
			end
			if p.parts and #p.parts.dots > 0 and p.full and not p.sent then -- the ring fills while held
				local held = if p.holdAt then (os.clock() - p.holdAt) * 10 / BattleRules.HOLD_TENTHS else 0
				Press.pops.lit(p.parts, math.floor(math.min(1, held) * #p.parts.dots))
				if p.card then
					p.card:SetAttribute("Hot", held >= 1)
				end
				for i, dot in p.parts.dots do
					local lit = i / #p.parts.dots <= held
					dot.BackgroundColor3 = if not lit
						then Press.pops.DIM
						elseif held >= 0.8 then Press.pops.GOLD
						else Press.pops.LIT
				end
				p.parts.edge.Color = if held >= 0.8 then Press.pops.GOLD else Press.pops.EDGE
				if held >= 1 then
					p.holdAt = nil
					task.spawn(firePower, slot, BattleRules.HOLD_TENTHS)
				end
			elseif p.parts and p.hand and p.full then -- the needle's card goes green while the marker is in it
				local x = needleAt(os.clock() - p.fullAt, p.close)
				local wide = Press.SWING * math.sin(math.pi * BattleRules.PERFECT_EARLY / BattleRules.NEEDLE_EVERY)
				p.parts.edge.Color = if math.abs(x - 0.5) <= wide then Press.pops.GREEN else Press.pops.EDGE
				if p.card then
					p.card:SetAttribute("Hot", math.abs(x - 0.5) <= wide)
				end
			end
		end
		hitCount.Visible = hits >= 3 and os.clock() - lastClick < CHAIN_HIT + 0.4
		hitCount.Text = `{hits} HITS`
	end)
	Press.tap, Press.on, Press.off, Press.catcher, Press.hold = pressPlate, pressOn, pressOff, catcher, holdRing
end

-- the press keys (PressPops.claim): each card's own, taken from the character while the fight is on
plates:GetPropertyChangedSignal("Visible"):Connect(function()
	Press.pops.listen(if plates.Visible
		then function(key: Enum.KeyCode, down: boolean)
			for slot, p in plateOf do
				local keys = p.keys
				if keys == nil or not p.full or p.sent then
					continue
				end
				if p.press == "ring" and keys[1] == key then
					Press.hold(slot, down)
				elseif down and p.press ~= "ring" and keys[if p.press == "chain" then p.marked + 1 else 1] == key then
					Press.tap(slot) -- the chain's next key, or the needle's or the mash's
				elseif down and p.press == "chain" and table.find(keys, key) then
					firePower(slot, BattleRules.FAILED) -- one of its keys out of order
				end
			end
		end
		else nil)
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local folder = Workspace:FindFirstChild(player:GetAttribute("FightFolder") or `WaveShow{player.UserId}`)
		local seen: { [number]: boolean } = {}
		if folder then
			for _, m in folder:GetChildren() do
				local slot = m:GetAttribute("Seat") or m:GetAttribute("Slot")
				local owner = m:GetAttribute("Owner") or player.UserId
				if
					m:GetAttribute("Side") == 1
					and type(slot) == "number"
					and owner ~= player.UserId
					and m:IsA("Model")
				then
					-- another player's animal: only a marker over it while its meter is full (decision 0109)
					local s, power, hp = m:GetAttribute("Species"), m:GetAttribute("Power"), m:GetAttribute("Hp")
					Press.pops.ally(
						m,
						if type(s) == "string" then BattleRules.pressOf({ s = s } :: any) else "ring",
						type(power) == "number" and power >= 1 and type(hp) == "number" and hp > 0
					)
				elseif m:GetAttribute("Side") == 1 and type(slot) == "number" then
					seen[slot] = true
					local p = plateOf[slot]
					if p == nil then
						local s, v = m:GetAttribute("Species"), m:GetAttribute("Variant")
						local va = if type(s) == "string" and type(v) == "string"
							then StationConfig.variant(s, v)
							else nil
						local sp = if type(s) == "string" then StationConfig.species(s) else nil
						local press = if type(s) == "string"
							then BattleRules.pressOf({ s = s, v = if type(v) == "string" then v else nil } :: any)
							else "ring"
						p = plate(slot, if va then va.name elseif sp then sp.name else "?", press)
						plateOf[slot] = p
						m:GetAttributeChangedSignal("AnimAt"):Connect(function()
							if m:GetAttribute("Anim") == "magic" and type(s) == "string" then -- its power attack: say its name
								moveName(s)
							end
						end)
					end
					p.model = if m:IsA("Model") then m else nil
					local hp = m:GetAttribute("Hp")
					local alive = type(hp) == "number" and hp > 0
					local power = m:GetAttribute("Power")
					local share = if type(power) == "number" then math.clamp(power, 0, 1) else 0
					local full = alive and share >= 1
					p.power(share)
					p.mana.Text = if full then "MANA FULL" else `MANA {math.floor(share * 100)}%`
					if full ~= p.full then
						p.full = full
						if full then
							Press.on(p, slot)
						else
							Press.off(p)
						end
						Style.kind(p.button, if full then "primary" else if alive then "ghost" else "off")
					elseif not alive then
						Style.kind(p.button, "off")
					end
				end
			end
		end
		for slot, p in plateOf do
			if not seen[slot] then
				Press.off(p)
				p.button:Destroy()
				plateOf[slot] = nil
			end
		end
		plates.Visible = next(plateOf) ~= nil
		Press.catcher.Visible = plates.Visible
		fightTick(folder, plates.Visible)
	end
end)

local function foeCard(e: any, share: number)
	local foe = StationConfig.foe(e.s) :: StationConfig.Foe
	local boss = foe.kind == "dragon"
	local card = Style.card(waves.body, UDim2.fromOffset(122, 178), if boss then C.bad else C.edge)
	local tint = if foe.tint then Color3.fromRGB(foe.tint[1], foe.tint[2], foe.tint[3]) else nil
	local view = Portrait.new(
		card,
		foe.model,
		{ size = UDim2.fromOffset(102, 96), background = Color3.fromRGB(34, 22, 50), tint = tint, zoom = 0.82 }
	)
	view.Position = UDim2.fromOffset(10, 10)
	local name = Style.text(card, foe.name, 14, C.night, UDim2.new(1, -8, 0, 36))
	name.Position = UDim2.fromOffset(4, 110)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local power = Style.text( -- its share of the wave's power, so the cards add up to the match-up
		card,
		`⚡ {Format.short(math.floor(BattleRules.powerOf(e, 2) * share + 0.5))}`,
		14,
		C.night,
		UDim2.new(1, -8, 0, 18)
	)
	power.Position, power.TextXAlignment = UDim2.fromOffset(4, 148), Enum.TextXAlignment.Center
	if boss then
		local tag = Style.chip(card, "BOSS", C.bad, Color3.new(1, 1, 1))
		tag.AnchorPoint, tag.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 4)
	end
	return card
end

local function section(parent: Instance, words: string, order: number)
	local t = Style.text(parent, words, 17, C.muted, UDim2.new(1, -20, 0, 22))
	t.LayoutOrder = order
	return t
end

redraw.waves = function()
	Style.clear(waves.body)
	Style.clear(waves.chips)
	Style.clear(waves.tabs)
	wave = math.clamp(wave, 1, math.min(profile.best + 1, LevelRules.LAST))
	Style.chip(waves.chips, `Best wave: {profile.best} of {LevelRules.LAST}`)
	local got = StationProgress.starsOf(profile, wave)
	Style.chip(waves.chips, string.rep("★", got) .. string.rep("☆", 3 - got), C.gold, C.ink)
	local boss = wave % LevelRules.BOSS_EVERY == 0
	if boss then
		Style.chip(waves.chips, "BOSS WAVE", C.bad, Color3.new(1, 1, 1))
	end
	Style.chip(
		waves.chips,
		if wave > profile.best then "New" else "Cleared: replays pay a quarter",
		if wave > profile.best then C.accent else C.good,
		if wave > profile.best then C.accentText else Color3.fromRGB(10, 40, 18)
	)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	-- the wave to fight, with arrows to step through the open ones
	local step = Instance.new("Frame")
	step.BackgroundTransparency = 1
	step.Size = UDim2.fromOffset(196, 52)
	step.LayoutOrder = nextOrder()
	step.Parent = waves.tabs
	local prev = Style.button(step, "<", function()
		wave -= 1
		redraw.waves()
	end, if wave > 1 then "ghost" else "off", UDim2.fromOffset(60, 52))
	prev.TextSize = 28
	local nextButton = Style.button(step, ">", function()
		wave += 1
		redraw.waves()
	end, if wave <= profile.best and wave < LevelRules.LAST then "ghost" else "off", UDim2.fromOffset(60, 52))
	nextButton.AnchorPoint, nextButton.Position, nextButton.TextSize = Vector2.new(1, 0), UDim2.fromScale(1, 0), 28
	prev.Size, nextButton.Size = UDim2.fromOffset(46, 52), UDim2.fromOffset(46, 52)
	local head = Style.text(step, `Wave {wave}`, 28, C.text, UDim2.new(1, -100, 1, 0))
	head.Position, head.TextXAlignment = UDim2.fromOffset(50, 0), Enum.TextXAlignment.Center

	local team = StationProgress.fighters(profile)
	local go = Style.button(waves.tabs, `Fight wave {wave}`, function()
		fight(wave)
	end, if #team > 0 then "danger" else "off", UDim2.fromOffset(196, 60))
	go.TextSize, go.LayoutOrder = 24, nextOrder()
	-- stars (decision 0097): the total, and a chest every StationProgress.CHEST_STARS
	local total, due = StationProgress.starTotal(profile), StationProgress.chestsDue(profile)
	local chest = Style.button(
		waves.tabs,
		if due > 0 then `★ {total}: open a chest!` else `★ {total} stars`,
		function()
			if StationProgress.chestsDue(profile) > 0 then
				send("claim_chest")
			end
		end,
		if due > 0 then "primary" else "off",
		UDim2.fromOffset(196, 44)
	)
	chest.LayoutOrder = nextOrder()
	local nextAt = (profile.chests + 1) * StationProgress.CHEST_STARS
	local hint = Style.text(
		waves.tabs,
		if due > 0 then "" else `Next chest at {nextAt} stars`,
		13,
		C.muted,
		UDim2.fromOffset(196, 18)
	)
	hint.LayoutOrder, hint.TextXAlignment = nextOrder(), Enum.TextXAlignment.Center

	-- the power match-up (decision 0096): the side with more power nearly always wins
	local ours, theirs = BattleRules.teamPower(team, 1), LevelRules.power(wave)
	local odds = if #team == 0
		then nil
		elseif ours >= theirs * 1.1 then "good"
		elseif ours >= theirs then "close"
		else "bad"
	local verdict = Style.chip(
		waves.chips,
		`⚡ {Format.commas(ours)} vs {Format.commas(theirs)}: {if odds == "good"
			then "you're stronger"
			elseif odds == "close" then "a close one"
			else "they're stronger"}`,
		if odds == "good" then C.good elseif odds == "close" then C.accent else C.bad,
		if odds == "close" then C.accentText else Color3.new(1, 1, 1)
	)
	verdict.Visible = odds ~= nil
	section(waves.body, "Enemies", nextOrder())
	local line = Instance.new("Frame")
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, -20, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.LayoutOrder = nextOrder()
	Style.list(line, 8, true, true)
	line.Parent = waves.body
	local foes = LevelRules.enemies(wave)
	local raw = BattleRules.teamPower(foes, 2)
	local groups, kinds = {}, {}
	for _, e in foes do
		local key = e.s .. (if e.elite then "*" else "")
		if groups[key] == nil then
			groups[key] = { e = e, n = 0 }
			table.insert(kinds, key)
		end
		groups[key].n += 1
	end
	for _, key in kinds do
		local g = groups[key]
		local card = foeCard(g.e, theirs / math.max(1, raw))
		card.Parent = line
		if g.n > 1 then
			local many = Style.chip(card, `x{g.n}`, C.ink, Color3.new(1, 1, 1))
			many.AnchorPoint, many.Position, many.ZIndex = Vector2.new(1, 0), UDim2.new(1, -4, 0, 4), 4
		end
		if g.e.elite then
			local gold = Style.chip(card, "ELITE", C.gold, C.ink)
			gold.Position, gold.ZIndex = UDim2.fromOffset(4, 4), 4
		end
	end
	local row = LevelRules.crowd(wave)
	section(waves.body, `{#foes} enemies in {row.rushes} {if row.rushes > 1 then "rushes" else "rush"}`, nextOrder())

	section(waves.body, "Clearing it pays", nextOrder())
	local coinsWon, xpWon, samplesWon = StationProgress.payout(profile, wave)
	local pay = Instance.new("Frame")
	pay.BackgroundTransparency = 1
	pay.Size = UDim2.new(1, -20, 0, 26)
	pay.LayoutOrder = nextOrder()
	Style.list(pay, 16, true)
	pay.Parent = waves.body
	Style.amount(pay, "coins", Format.commas(coinsWon))
	Style.amount(pay, "xp", `{xpWon} XP`)
	if samplesWon > 0 then
		Style.amount(pay, "samples", `{samplesWon} samples`)
	end

	section(waves.body, "Your team", nextOrder())
	local mine = Instance.new("Frame")
	mine.BackgroundTransparency = 1
	mine.Size = UDim2.new(1, -20, 0, 0)
	mine.AutomaticSize = Enum.AutomaticSize.Y
	mine.LayoutOrder = nextOrder()
	Style.list(mine, 8, true, true)
	mine.Parent = waves.body
	if #team == 0 then
		local t = Style.text(
			mine,
			"Your team is empty. Open Animals and put an animal on your team.",
			17,
			C.muted,
			UDim2.new(1, 0, 0, 44)
		)
		t.TextWrapped = true
	end
	for _, a in team do
		local colour = RARITY_COLOUR[StationRules.rarity(a)] or C.text
		local card = Style.card(mine, UDim2.fromOffset(104, 132), colour)
		local view = Portrait.new(
			card,
			StationRules.assetOf(a.s, a.v),
			{ size = UDim2.fromOffset(84, 82), background = darker(colour), rainbow = a.rainbow }
		)
		view.Position = UDim2.fromOffset(10, 8)
		local name = Style.text(card, nameOf(a), 14, C.text, UDim2.new(1, -6, 0, 34))
		name.Position = UDim2.fromOffset(3, 94)
		name.TextXAlignment = Enum.TextXAlignment.Center
	end
end

function openWaves()
	wave = if profile then math.min(profile.best + 1, LevelRules.LAST) else 1
	show("waves")
end

-- The card under the cursor ----------------------------------------------------------------------

-- Pointing at an animal shows a small card that follows the cursor: its name, its rarity in the
-- rarity's colour, role and group, the six stats and a health bar. Every model carries what the
-- card needs as attributes (the server's `describe`); the cursor finds a model by its unseen
-- "CreatureHit" box.
local card = Ui.panel(screen, { size = UDim2.fromOffset(236, 152), name = "AnimalCard" })
card.Visible = false
card.ZIndex = 20
local cardEdge = Instance.new("UIStroke")
cardEdge.Thickness = 3
cardEdge.Parent = card
local cardName = Ui.label(card, "", { size = 20 })
local cardPower = Ui.label(card, "", { size = 16 }) -- its power score (decision 0096)
local cardKind = Ui.label(card, "", { size = 14 })
local cardStats = Ui.label(card, "", { size = 14, muted = true })
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 16)
bar.BackgroundColor3 = Color3.new(1, 1, 1)
bar.BorderSizePixel = 0
bar.Parent = card
local fill = Instance.new("Frame")
fill.BackgroundColor3 = C.good
fill.BorderSizePixel = 0
fill.Parent = bar
local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromScale(1, 1)
barText.BackgroundTransparency = 1
barText.Font = Enum.Font.FredokaOne
barText.TextSize = 13
barText.TextColor3 = Color3.new(1, 1, 1)
barText.Parent = bar

local HEXFIRE = Color3.fromRGB(150, 255, 70)

local function showCard(model: Model?)
	local s = model and model:GetAttribute("Species")
	local sp = if type(s) == "string" then StationConfig.species(s) else nil
	local f = model and model:GetAttribute("FoeId")
	local foe = if type(f) == "string" then StationConfig.foe(f) else nil
	if model == nil or (sp == nil and foe == nil) then
		card.Visible = false
		return
	end
	if foe then -- an enemy: the Hexbound have no rarity, only their kind
		cardName.Text = foe.name
		cardName.TextColor3 = HEXFIRE
		cardEdge.Color = HEXFIRE
		cardKind.Text =
			`HEXBOUND {string.upper(foe.kind)}  -  {ROLE_NAME[foe.role] or "?"}  -  {GROUP_NAME[foe.group] or "?"}`
		cardKind.TextColor3 = HEXFIRE
	else
		local animal = sp :: StationConfig.Species
		local v = model:GetAttribute("Variant")
		local va = if type(v) == "string" then StationConfig.variant(animal.id, v) else nil
		local rarity = if va then va.tier else animal.rarity
		local colour = RARITY_COLOUR[rarity] or Color3.new(1, 1, 1)
		cardName.Text = (if model:GetAttribute("Rainbow") then "Rainbow " else "")
			.. (if va then va.name else animal.name)
		cardName.TextColor3 = colour
		cardEdge.Color = colour
		cardKind.Text =
			`{string.upper(rarity)}  -  {ROLE_NAME[animal.role] or "?"}  -  {GROUP_NAME[animal.group] or "?"}`
		cardKind.TextColor3 = colour
	end
	local parts = {}
	for k, stat in StationConfig.STATS do
		table.insert(parts, `{STAT_SHORT[stat]} {model:GetAttribute(stat) or "?"}{if k == 3 then "\n" else "   "}`)
	end
	cardStats.Text = table.concat(parts)
	-- the attributes are its stats as they stand (levels, coat, the Den), so its power works out from them
	local stats = {}
	for _, stat in StationConfig.STATS do
		local x = model:GetAttribute(stat)
		stats[stat] = if type(x) == "number" then x else 0
	end
	local who = { s = if foe then foe.id else (sp :: StationConfig.Species).id, stats = stats :: any }
	cardPower.Text = `⚡ {Format.short(BattleRules.powerOf(who, if foe then 2 else 1))} power`
	cardPower.TextColor3 = if foe then HEXFIRE else C.gold
	local health = model:GetAttribute("health")
	local max = BattleRules.HP_BASE
		+ math.floor((if type(health) == "number" then health else 0) * BattleRules.HP_PER_HEALTH)
	local fightMax = model:GetAttribute("MaxHp") -- in a fight: with the team's bonuses
	if type(fightMax) == "number" then
		max = fightMax
	end
	local hp = model:GetAttribute("Hp") -- set while a fight is on; full otherwise
	local now = if type(hp) == "number" then math.clamp(hp, 0, max) else max
	fill.Size = UDim2.fromScale(now / math.max(1, max), 1)
	barText.Text = `{now} / {max} HP`
	card.Visible = true
end

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if camera == nil or not UserInputService.MouseEnabled then
		return
	end
	local at = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(at.X, at.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("CreatureHit")
	local found = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	showCard(if found then found.Instance.Parent :: Model else nil)
	if card.Visible then
		local inset = if screen.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
		card.Position = UDim2.fromOffset(at.X - inset.X + 18, at.Y - inset.Y + 14)
	end
end)

-- Hatching -------------------------------------------------------------------------------------------

-- The egg `eggId` standing at `at` rocks harder and harder, then bursts: a flash, sparks and bits of
-- shell in its two colours. Takes HATCH seconds; the server brings the animal out of the nest after
-- it. The egg is its own model (the still copy the portraits use), or a plain shell without one.
local HATCH = 1.4
local function hatchEffect(nest: CFrame, eggId: string, body: Color3, spot: Color3)
	local h = 3
	local at = nest.Position
	local portraits = ReplicatedStorage:FindFirstChild("Portraits")
	local source = portraits and portraits:FindFirstChild(`egg_{eggId}`)
	local shell: Instance
	local place: (CFrame) -> ()
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = spot, 10, 0.5, false
	if source and source:IsA("Model") and source.PrimaryPart then
		local model = source:Clone()
		light.Parent = model.PrimaryPart
		shell, place = model, function(foot: CFrame)
			model:PivotTo(foot)
		end
	else
		local plain = Instance.new("Part")
		plain.Anchored, plain.CanCollide, plain.CanQuery = true, false, false
		plain.Size, plain.Color, plain.Material = Vector3.new(h * 0.75, h, h * 0.75), body, Enum.Material.SmoothPlastic
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = plain
		light.Parent = plain
		shell, place = plain, function(foot: CFrame)
			plain.CFrame = foot * CFrame.new(0, h / 2, 0)
		end
	end
	place(nest)
	shell.Parent = Workspace
	local started = os.clock()
	while os.clock() - started < HATCH do -- rock about the foot, faster and wider
		local t = (os.clock() - started) / HATCH
		local lean = math.sin(t * t * 60) * math.rad(4 + 22 * t)
		place(nest * CFrame.Angles(0, 0, lean) * CFrame.new(0, math.abs(lean) * 0.6, 0))
		light.Brightness = 0.5 + 4 * t
		RunService.RenderStepped:Wait()
	end
	shell:Destroy()
	local mid = at + Vector3.new(0, h / 2, 0)
	local flash = Instance.new("Part")
	flash.Shape, flash.Anchored, flash.CanCollide, flash.CanQuery = Enum.PartType.Ball, true, false, false
	flash.Size, flash.Position, flash.Color, flash.Material =
		Vector3.one * h, mid, Color3.new(1, 1, 0.9), Enum.Material.Neon
	flash.Parent = Workspace
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(spot, body)
	sparks.LightEmission = 0.8
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(10, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.Parent = flash
	sparks:Emit(50)
	local out = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, out, { Size = Vector3.one * h * 3.2, Transparency = 1 }):Play()
	for k = 1, 12 do -- bits of shell fly out and fall
		local bit = Instance.new("WedgePart")
		bit.Anchored, bit.CanCollide, bit.CanQuery = true, false, false
		bit.Size = Vector3.new(0.2, 0.7, 0.9)
		bit.Color, bit.Material = if k % 3 == 0 then spot else body, Enum.Material.SmoothPlastic
		bit.CFrame = CFrame.new(mid) * CFrame.Angles(k, k * 2, k * 3)
		bit.Parent = Workspace
		local a = k / 12 * math.pi * 2
		local land = at + Vector3.new(math.cos(a) * 6, 0.2, math.sin(a) * 6)
		TweenService:Create(bit, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(land) * CFrame.Angles(k * 3, k, k * 2),
			Transparency = 1,
		}):Play()
		Debris:AddItem(bit, 0.8)
	end
	Debris:AddItem(flash, 1.3)
end

-- Admin menu (decisions 0038, 0049): only for players the server marks as admin (the game's owner, or
-- anyone in Studio). Its first tab lists every animal and variant: a tap adds it to your own ranch. Its
-- second spawns animals in front of you and plays their animations, its third the same for the
-- Hexbound enemies; nothing there is saved.
local adminTab = "add"
local adminTabs: { [string]: Frame } = {} -- the Spawn ("tests") and Enemies ("foes") tabs, made once
for _, key in { "tests", "foes" } do
	local tab = Instance.new("Frame")
	tab.BackgroundTransparency = 1
	tab.Size, tab.AutomaticSize = UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y
	Style.list(tab, 10)
	tab.Visible = false
	tab.Parent = admin.body
	adminTabs[key] = tab
end
local adminAdd = { body = Instance.new("Frame") } -- the Add animals tab's rows
adminAdd.body.BackgroundTransparency = 1
adminAdd.body.Size, adminAdd.body.AutomaticSize = UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y
Style.list(adminAdd.body, 8)
adminAdd.body.Parent = admin.body
for _, tab in adminTabs do
	-- the animations play on whatever is spawned
	local anims = Instance.new("Frame")
	anims.BackgroundTransparency = 1
	anims.Size, anims.AutomaticSize, anims.LayoutOrder = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y, 0
	Style.list(anims, 6, true, true)
	anims.Parent = tab
	local CLIPS = {
		{ "idle", "Idle" },
		{ "walk", "Walk" },
		{ "attack", "Attack" },
		{ "magic", "Power" },
		{ "hit", "Hit" },
		{ "die", "Fall" },
	}
	for i, clip in CLIPS do
		Style.button(anims, clip[2], function()
			send("look_anim", clip[1])
		end, "ghost", UDim2.fromOffset(86, 44)).LayoutOrder =
			i
	end
	Style.button(anims, "Clear", function()
		send("look_clear")
	end, "ghost", UDim2.fromOffset(86, 44)).LayoutOrder = #CLIPS
		+ 1
end
do
	-- the server lists them in this order too (LOOKS: a species, then its variants; the foes after them all)
	local k = 0
	local function spawnButton(tab: Frame, name: string)
		k += 1
		local index = k
		Style.button(tab, `Spawn {name}`, function()
			send("look", index)
		end, "ghost", UDim2.new(1, 0, 0, 44)).LayoutOrder =
			index
	end
	for _, sp in StationConfig.SPECIES do
		spawnButton(adminTabs.tests, sp.name)
		for _, va in sp.variants do
			spawnButton(adminTabs.tests, `{va.name} ({va.tier})`)
		end
	end
	for _, f in StationConfig.FOES do
		spawnButton(adminTabs.foes, f.name)
	end
end

-- The Add animals tab (decisions 0049, 0058): one row per species and variant; a tap adds it to your own
-- ranch, every stat at level 1. The server checks the admin.
do
	local list: { { s: string, v: string? } } = {} -- in the server's order (LOOKS: a species, then its variants)
	for _, sp in StationConfig.SPECIES do
		table.insert(list, { s = sp.id })
		for _, va in sp.variants do
			table.insert(list, { s = sp.id, v = va.id })
		end
	end
	local function draw()
		Style.clear(adminAdd.body)
		for k, a in list do
			local colour = RARITY_COLOUR[StationRules.rarity(a :: any)] or C.text
			local name = nameOf(a)
			local va = if a.v then StationConfig.variant(a.s, a.v) else nil
			local row = Style.button(adminAdd.body, "", function()
				local ok, code = request:InvokeServer("admin_add", k, 1, false)
				Style.toast(
					screen,
					if ok then `Added a {name} to your ranch` else REFUSED[code] or `Can't do that ({code})`,
					2
				)
			end, "ghost", UDim2.new(1, 0, 0, 64))
			row.Name, row.LayoutOrder = name, k
			Style.stroke(row, colour, 2)
			local view = Portrait.new(
				row,
				StationRules.assetOf(a.s, a.v),
				{ size = UDim2.fromOffset(52, 52), background = darker(colour) }
			)
			view.Position = UDim2.fromOffset(6, 6)
			local label =
				Style.text(row, if va then `{name} ({va.tier})` else name, 18, colour, UDim2.new(1, -220, 1, 0))
			label.Position = UDim2.fromOffset(70, 0)
			local hint = Style.text(row, "Add to my ranch", 14, C.muted, UDim2.fromOffset(140, 64))
			hint.AnchorPoint, hint.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 0)
			hint.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	local drawn = false
	redraw.admin = function() -- the rows are drawn once, when first opened: a new profile must not scroll it back up
		Style.clear(admin.tabs)
		for _, t in { { "add", "Add animals" }, { "tests", "Spawn" }, { "foes", "Enemies" } } do
			Style.tab(admin, t[2], adminTab == t[1], function()
				adminTab = t[1]
				redraw.admin()
			end)
		end
		adminTabs.tests.Visible, adminTabs.foes.Visible = adminTab == "tests", adminTab == "foes"
		adminAdd.body.Visible = adminTab == "add"
		if adminTab == "add" and not drawn then
			drawn = true
			draw()
		end
	end
end
local function showAdmin()
	adminToggle.Visible = player:GetAttribute("Admin") == true
	if not adminToggle.Visible and openName == "admin" then
		show(nil)
	end
end
player:GetAttributeChangedSignal("Admin"):Connect(showAdmin)
showAdmin()

-- A way to open a sheet by name, for looking at the layout without walking to its prompt: set the
-- player's "UiOpen" attribute to a sheet's name ("" closes).
player:GetAttributeChangedSignal("UiOpen"):Connect(function()
	local name = player:GetAttribute("UiOpen")
	show(if type(name) == "string" and sheets[name] then name else nil)
end)

-- Refreshing ------------------------------------------------------------------------------------------

local function refresh()
	if profile == nil then
		return
	end
	local level = StationProgress.playerLevel(profile)
	local from, to = StationProgress.xpFor(level), StationProgress.xpFor(level + 1)
	badgeText.Text = tostring(level)
	levelText.Text = `Level {level}`
	xpText.Text = `{Format.short(profile.xp - from)} / {Format.short(to - from)} XP`
	setXp((profile.xp - from) / math.max(1, to - from))
	coinsText.Text = Format.short(profile.coins)
	samplesText.Text = Format.short(profile.samples)
	if openName and redraw[openName] then
		redraw[openName]()
	end
end

-- The prompts in the world: the Ranch House door, the egg storage and a finished egg (the owner
-- only), the wave gate and the vendors' stalls.
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local mine = prompt:GetAttribute("Ranch") == who:GetAttribute("Ranch")
	local owners = CollectionService:HasTag(prompt, "RanchMenu")
		or CollectionService:HasTag(prompt, "EggStorage")
		or CollectionService:HasTag(prompt, "Egg")
		or CollectionService:HasTag(prompt, "Mill")
	if owners and not mine then
		Style.toast(screen, "This is not your ranch")
	elseif CollectionService:HasTag(prompt, "RanchMenu") then
		show("ranch")
	elseif CollectionService:HasTag(prompt, "EggStorage") then
		show("eggs")
	elseif CollectionService:HasTag(prompt, "HubTrade") then -- the hub's Trading Post
		show("trade")
	elseif CollectionService:HasTag(prompt, "HubGifts") then -- the hub's Gift Stand
		request:InvokeServer("rewards")
		show("gifts")
	elseif CollectionService:HasTag(prompt, "WaveGate") then
		openWaves()
	elseif CollectionService:HasTag(prompt, "Egg") then
		send("open", prompt:GetAttribute("Index"))
	elseif CollectionService:HasTag(prompt, "Mill") then
		send("collect")
	elseif CollectionService:HasTag(prompt, "Vendor") then
		if prompt:GetAttribute("Kind") == "eggs" then
			show("shop")
		else
			Style.toast(screen, "The gear vendor is still unpacking. Gear is coming soon!")
		end
	end
end)

task.spawn(function() -- once a second: countdowns, and a finished egg can be opened
	while true do
		task.wait(1)
		if profile then -- the Eggs button's dot: eggs ready to open at the hatchery
			local ready, now = 0, Workspace:GetServerTimeNow()
			for _, e in profile.eggs do
				local def = e.since and StationConfig.egg(e.egg)
				if def and now >= (StationProgress.dueAt(profile, e) :: number) then
					ready += 1
				end
			end
			eggsDot.Text, eggsDot.Visible = tostring(ready), ready > 0
			local week, month, spin = giftsReady()
			giftsDot.Text, giftsDot.Visible = "!", week or month or spin
		end
		if openName == "animals" then
			for _, tick in tickers do
				tick()
			end
		elseif openName == "eggs" then
			for _, tick in eggTickers do
				tick()
			end
		end
		for _, prompt in CollectionService:GetTagged("Egg") do
			local due = prompt:GetAttribute("Due")
			local ready = type(due) == "number" and Workspace:GetServerTimeNow() >= due;
			(prompt :: ProximityPrompt).ActionText = if ready then "Open" else "Hatching"
			local sparkle = prompt.Parent and prompt.Parent:FindFirstChildOfClass("ParticleEmitter")
			if sparkle then
				sparkle.Enabled = ready
			end
		end
		for _, prompt in CollectionService:GetTagged("Mill") do -- what the owner's windmill holds, on its till
			if profile and prompt:GetAttribute("Ranch") == player:GetAttribute("Ranch") then
				local held = StationProgress.held(profile, Workspace:GetServerTimeNow())
				local full = held >= StationProgress.value(profile, "windmill") * StationProgress.MILL_HOURS
				local text =
					`{Format.commas(held)} {if held == 1 then "coin" else "coins"}{if full then " (full)" else ""}`
				(prompt :: ProximityPrompt).ObjectText = text
				for _, d in (prompt.Parent :: Instance):GetDescendants() do
					if d:IsA("TextLabel") then
						d.Text = text
					end
				end
			end
		end
	end
end)

fx.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "profile" then
		local first = profile == nil
		profile = payload
		if first then
			task.spawn(request.InvokeServer, request, "rewards") -- today counts for the planners
		end
		refresh()
	elseif kind == "hatched" then
		local lucky = ""
		for _, stat in StationConfig.STATS do
			if StationRules.level(payload, stat) >= StationConfig.MAX_LEVEL then
				lucky = `  JACKPOT: {STAT_SHORT[stat]} is already level {StationConfig.MAX_LEVEL}!`
			end
		end
		if payload.at then
			hatchEffect(payload.at, payload.egg, payload.body, payload.spot) -- then the animal steps out
		end
		showRarity(payload)
		if lucky ~= "" then
			Style.toast(screen, lucky, 4)
		end
	elseif kind == "wavedone" then
		local took = string.format("%.1f", payload.seconds)
		local skip = root:FindFirstChild("SkipWave")
		if skip then
			(skip :: GuiObject).Visible = false
		end
		Style.clear(drops)
		Style.clear(boonRow)
		drops.Visible = payload.won
		music(if payload.won then "win" else "lose")
		showStars(payload.stars or 0)
		local goals = "★ win   ★ nobody knocked out   ★ you fire every power attack"
		if payload.won then
			resultTitle.Text, resultTitle.TextColor3 =
				if payload.last
					then `Wave {payload.wave} cleared: the Legion is beaten!`
					else `Wave {payload.wave} cleared!`,
				C.good
			local mvp = if payload.mvp then `  MVP: {payload.mvp} ({Format.short(payload.mvpDmg or 0)} damage)` else ""
			local lines = { `Won in {took}s.{if payload.first then " First clear!" else ""}{mvp}`, goals }
			if payload.streak then
				local pot = if payload.pot then payload.pot.coins else 0
				table.insert(
					lines,
					if pot > 0
						then `Run: {payload.streak} in a row. Pot: +{Format.commas(pot)} coins, paid when you leave.`
						else `Run: {payload.streak} in a row. Keep winning to fill the pot.`
				)
			end
			resultSub.Text = table.concat(lines, "\n")
			Style.amount(drops, "coins", `+{Format.commas(payload.coins)}`)
			Style.amount(drops, "xp", `+{payload.xp} XP`)
			if payload.samples > 0 then
				Style.amount(drops, "samples", `+{payload.samples} samples`)
			end
			coinBurst()
			if payload.chest then
				Style.toast(screen, `Boss chest! {rewardWords(payload.chest)}`, 5, "good", (iconsOf(payload.chest)))
			end
			wave = math.min(payload.wave + 1, LevelRules.LAST)
			again.Text = if payload.last then `Fight wave {wave} again` else `Fight wave {wave}`
			if payload.offer then -- pick a boon: it starts the next wave
				offerBoons(payload.offer, wave)
				if (payload.party or 1) > 1 then -- a party votes, 7 seconds (the server's VOTE_SECONDS): a countdown
					local panel = boonRow.Parent :: GuiObject
					local heading = panel:FindFirstChild("Title") :: TextLabel?
					task.spawn(function()
						for left = 7, 1, -1 do
							if not panel.Visible or heading == nil then
								return
							end
							heading.Text = `Vote for a boon: {left}`
							task.wait(1)
						end
						panel.Visible, result.Visible = false, false -- time is up: the server picks and the next wave starts
					end)
				end
			end
			buttons(payload.offer == nil)
			local pot = if payload.pot then payload.pot.coins else 0
			leave.Text = if pot > 0 then `Leave and bank +{Format.commas(pot)}` else "Leave the arena"
		else
			resultTitle.Text, resultTitle.TextColor3 = `Wave {payload.wave}: beaten`, C.bad
			resultSub.Text = `Your team lost in {took}s to {payload.foes}. Train your animals up and try again.`
			wave = payload.wave
			again.Text = `Try wave {wave} again`
			buttons(true)
			leave.Text = "Leave the arena"
		end
		result.Visible = true
	elseif kind == "began" then -- a shared fight's wave, started by another player or by the vote (decision 0108)
		began(payload.wave)
	elseif kind == "votes" then
		local votes = (boonRow.Parent :: Instance):FindFirstChild("Votes") :: TextLabel?
		if votes then
			votes.Text = `{payload.voted} of {payload.of} have voted`
		end
	elseif kind == "boon" then
		local voted = boonRow.Parent :: GuiObject
		voted.Visible, result.Visible = false, false
		local picked = WaveRuns.boon(payload.id)
		if picked then
			Style.toast(screen, `The party's boon: {picked.name}`, 3, "good")
		end
	elseif kind == "over" then
		hideResult()
		music(nil)
		Style.toast(screen, "Another party took the field: your run is banked", 5)
	elseif kind == "banked" then
		if payload.lost and payload.coins > 0 then
			Style.toast(
				screen,
				`Run over after {payload.waves} waves: you keep half the pot, +{Format.commas(payload.coins)} coins`,
				5
			)
		elseif payload.coins > 0 or payload.samples > 0 then
			Style.toast(
				screen,
				`Run banked: +{Format.commas(payload.coins)} coins{if payload.samples > 0
					then ` and {payload.samples} samples`
					else ""}`,
				5,
				"good"
			)
		end
	elseif kind == "waveshow" then
		local took = string.format("%.0f", payload.seconds)
		Style.toast(screen, `Wave {payload.wave}: {if payload.won then "won" else "lost"} in {took}s`, 7)
	elseif kind == "trade_invite" then
		invite = { from = payload.from, name = payload.name, at = os.clock() }
		Style.toast(screen, `{payload.name} wants to trade: open Trade`, 5)
		tradeDot.Text, tradeDot.Visible = "!", true
		if openName == "trade" then
			redraw.trade()
		end
	elseif kind == "trade" then
		if payload.closed then
			tradeState = nil
			tradePeek = nil
			local said = ({
				declined = "They said no to the trade",
				cancelled = "The trade was cancelled",
				left = "The other player left: the trade is off",
				failed = "The trade could not finish",
			})[payload.closed]
			if said then
				Style.toast(screen, said, 4)
			end
		else
			local opening = tradeState == nil
			payload.at = os.clock()
			tradeState = payload
			if opening and openName ~= "trade" then
				show("trade")
				return
			end
		end
		if openName == "trade" then
			redraw.trade()
		end
	elseif kind == "trade_done" then
		Style.sound("claim")
		Style.toast(
			screen,
			`Trade done with {payload.with}: you got {if #payload.got > 0
				then table.concat(payload.got, ", ")
				else "nothing"}`,
			5,
			"good"
		)
	elseif kind == "reward" then
		Style.sound("claim")
		Style.toast(screen, `You got: {rewardWords(payload.items)}`, 4, "good", (iconsOf(payload.items)))
	elseif kind == "spun" then
		landWheel(payload)
	elseif kind == "collected" then
		Style.toast(
			screen,
			`Collected {Format.commas(payload)} {if payload == 1 then "coin" else "coins"} from your windmill`,
			4
		)
	elseif kind == "bought" then
		Style.sound("buy")
		local egg = StationConfig.egg(payload)
		if egg then
			Style.toast(screen, `{egg.name} bought. It is in your egg storage.`, 3)
		end
	elseif kind == "upgraded" then
		Style.sound("buy")
		local u = StationConfig.upgrade(payload)
		if u and profile then
			Style.toast(screen, `{u.name} upgraded: {StationProgress.value(profile, u.id)} {u.gives}`, 4)
		end
	elseif kind == "refused" then
		Style.toast(screen, REFUSED[payload] or `Can't do that ({payload})`, nil, "bad")
	end
end)

-- Ask for the profile until the server has loaded it.
task.spawn(function()
	for _ = 1, 30 do
		if request:InvokeServer("profile") then
			return
		end
		task.wait(1)
	end
end)
