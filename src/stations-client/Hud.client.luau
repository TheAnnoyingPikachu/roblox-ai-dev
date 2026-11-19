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
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local UiLayout = require(Shared:WaitForChild("UiLayout"))
local StationAssets = require(Shared:WaitForChild("StationAssets"))
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
local RANK: { [string]: number } = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 }
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
	locked = "Clear more waves to unlock that egg",
	full = "Your barn is full: upgrade the Barn at your ranch",
	samples = "Not enough samples",
	admin = "Admins only",
	eggs_full = "Your egg storage is full: upgrade the Egg Cellar",
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
	arena = "The arena is not ready",
	ranch = "You have no ranch yet",
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

local function send(action: string, ...: any)
	local ok, code = request:InvokeServer(action, ...)
	if not ok and code then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
	end
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
	return StationRules.train(a, a.at, StationProgress.trainingSeconds(profile, Workspace:GetServerTimeNow() - a.since))
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
local nav = Instance.new("Frame") -- the bottom bar, hidden while a sheet is open

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

-- Bottom bar: Animals, Waves and Home (the eggs stay at the ranch)
nav.Name = "Nav"
nav.BackgroundTransparency = 1
nav.AnchorPoint, nav.Position, nav.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10), UDim2.new(1, -24, 0, 64)
local navLimit = Instance.new("UISizeConstraint")
navLimit.MaxSize = Vector2.new(540, 64)
navLimit.Parent = nav
Style.list(nav, 8, true)
nav.Parent = root

local hideResult: () -> () = function() end -- set once the fight panel exists
local function navButton(label: string, kind: string, order: number, onClick: () -> ()): TextLabel
	local b = Style.button(nav, label, onClick, kind, UDim2.new(1 / 4, -8, 1, -6))
	b.LayoutOrder, b.TextSize = order, 24
	local dot = Style.dot(b, "")
	dot.Visible = false
	return dot
end
navButton("Animals", "good", 1, function()
	show("animals")
end)
local openWaves: () -> () -- below, with the wave sheet
navButton("Waves", "danger", 2, function()
	openWaves()
end)
local tradeDot = navButton("Trade", "primary", 4, function()
	show("trade")
end)
navButton("Home", "info", 3, function()
	local ok, code = request:InvokeServer("home")
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
	else
		show(nil)
		hideResult()
	end
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
	if a.rainbow then
		local coat = Style.chip(card, "RAINBOW", Color3.new(1, 1, 1))
		coat.Position, coat.ZIndex, coat.TextSize = UDim2.fromOffset(8, 106), 3, 12
		local colours = Instance.new("UIGradient")
		colours.Color = RAINBOW
		colours.Parent = coat
	end
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
	local name =
		Style.text(head, (if a.rainbow then "Rainbow " else "") .. nameOf(a), 30, C.text, UDim2.new(1, -196, 0, 36))
	name.Position, name.TextTruncate = UDim2.fromOffset(194, 2), Enum.TextTruncate.AtEnd
	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position, chips.Size = UDim2.fromOffset(194, 44), UDim2.new(1, -196, 0, 28)
	Style.list(chips, 8, true)
	chips.Parent = head
	Style.chip(chips, string.upper(rarity), colour)
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
		if a.rainbow then
			table.insert(rainbows, a)
		end
	end
	local LISTS = {
		{ "team", `Your team  {#profile.team}/{StationProgress.TEAM_SIZE}`, team },
		{ "all", `All animals  {#all}`, all },
		{ "training", `Training  {#training}`, training },
		{ "rainbow", `Rainbows  {#rainbows}`, rainbows },
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
	local ready = e.since ~= nil and now >= e.since + need
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
			local remaining = e.since + need - Workspace:GetServerTimeNow()
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
			if def and now >= e.since + StationProgress.hatchSeconds(profile, def) then
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

-- The model that pictures upgrade `u` at `level`: its building's look (as Ranch.luau picks it), or for
-- the Training Grounds the Speed Track's training area at that level.
local function buildingAsset(u: StationConfig.Upgrade, level: number): string?
	if u.id == "grounds" then
		for name in StationAssets do
			local first, last = string.match(name, "^area_track_(%d)_(%d)$")
			if first and level >= tonumber(first) :: number and level <= tonumber(last) :: number then
				return name
			end
		end
		return nil
	end
	local look = math.clamp(1 + math.min(2, level * 3 // (#u.levels + 1)), 1, 3)
	local name = `home_{u.id}_{look}`
	return if StationAssets[name] then name else nil
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
	local asset = buildingAsset(u, level)
	if asset then
		local view =
			Portrait.new(card, asset, { size = UDim2.fromOffset(198, 112), background = Color3.fromRGB(191, 230, 247) })
		view.Position = UDim2.fromOffset(3, 3)
		Style.round(view, 11)
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
	local hatches = Style.text(shop.body, "HATCHES", 14, C.muted, UDim2.new(1, -8, 0, 18))
	hatches.LayoutOrder = 2
	local basics = Instance.new("Frame")
	basics.BackgroundTransparency = 1
	basics.Size, basics.LayoutOrder = UDim2.new(1, -8, 0, 92), 3
	Style.list(basics, 8, true)
	basics.Parent = shop.body
	for i, o in def.odds do
		local sp = StationConfig.species(o.id) :: StationConfig.Species
		animalCell(basics, i, StationRules.assetOf(o.id, nil), sp.name, RARITY_COLOUR[sp.rarity] or C.text, 72)
	end
	local finds = Style.text(shop.body, "RARE FINDS", 14, C.muted, UDim2.new(1, -8, 0, 18))
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

-- Trading (decision 0084) ---------------------------------------------------------------------------------

local tradeState: any = nil -- the open trade as the server last sent it: with, mine, theirs, ready, theyReady
local invite: any = nil -- the latest request to trade: from (UserId), name, at (os.clock)

local function tradeCell(parent: Instance, order: number, a: any, label: string, onClick: (() -> ())?, picked: boolean?)
	local colour = RARITY_COLOUR[StationRules.rarity(a)] or C.text
	local card =
		Style.card(parent, UDim2.fromOffset(108, if onClick then 150 else 118), if picked then C.good else C.edge)
	card.LayoutOrder = order
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

redraw.trade = function()
	Style.clear(trade.body)
	Style.clear(trade.chips)
	tradeDot.Visible = false
	if tradeState then
		Style.chip(trade.chips, `Trading with {tradeState.with}`, C.accent, C.accentText)
		Style.chip(
			trade.chips,
			if tradeState.theyReady then "They are ready" else "They are choosing",
			if tradeState.theyReady then C.good else nil
		)
		local theirs = tradeSection(`{tradeState.with} gives`, 1, 170)
		if #tradeState.theirs == 0 then
			Style.text(theirs, "Nothing yet", 15, C.muted, UDim2.fromOffset(200, 20))
		end
		for k, a in tradeState.theirs do
			tradeCell(theirs, k, a, nameOf(a))
		end
		local mine = tradeSection("You give", 2, 170)
		if #tradeState.mine == 0 then
			Style.text(mine, "Pick from your animals below", 15, C.muted, UDim2.fromOffset(260, 20))
		end
		for k, id in tradeState.mine do
			local _, a = StationProgress.find(profile, id)
			if a then
				tradeCell(mine, k, a, nameOf(a))
			end
		end
		local buttons = Style.card(trade.body, UDim2.new(1, -20, 0, 64))
		buttons.LayoutOrder = 3
		local ready = Style.button(buttons, if tradeState.ready then "Ready! (tap to wait)" else "Ready", function()
			send("trade_ready")
		end, if tradeState.ready then "good" else "primary")
		ready.Position, ready.Size = UDim2.fromOffset(12, 10), UDim2.new(0.5, -18, 0, 44)
		local cancel = Style.button(buttons, "Cancel trade", function()
			send("trade_cancel")
		end, "ghost")
		cancel.Position, cancel.Size = UDim2.new(0.5, 6, 0, 10), UDim2.new(0.5, -18, 0, 44)
		local rows = math.max(1, math.ceil(#profile.animals / 5))
		local own = tradeSection("Your animals (training ones cannot be traded)", 4, 50 + rows * 158)
		for k, a in profile.animals do
			local picked = table.find(tradeState.mine, a.id) ~= nil
			local label = nameOf(a) .. (if a.at then " (training)" else "")
			tradeCell(
				own,
				k,
				a,
				label,
				if a.at
					then nil
					else function()
						send("trade_put", a.id)
					end,
				picked
			)
		end
		return
	end
	Style.chip(trade.chips, "Swap animals with a player in this server")
	if invite and os.clock() - invite.at < 30 then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 74), C.gold)
		card.LayoutOrder = 0
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
			card.LayoutOrder = others
			local t = Style.text(card, other.DisplayName, 18, C.text, UDim2.new(0.6, 0, 0, 24))
			t.Position = UDim2.fromOffset(14, 20)
			local ask = Style.button(card, "Ask to trade", function()
				send("trade_ask", other.UserId)
				Style.toast(screen, `Asked {other.DisplayName} to trade`, 2)
			end, "primary")
			ask.Position, ask.Size = UDim2.new(0.6, 0, 0, 10), UDim2.new(0.4, -12, 0, 44)
		end
	end
	if others == 0 then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64))
		card.LayoutOrder = 1
		local t = Style.text(card, "Nobody else is in this server yet.", 16, C.muted, UDim2.new(1, -28, 0, 24))
		t.Position = UDim2.fromOffset(14, 20)
	end
end

-- Waves ---------------------------------------------------------------------------------------------------

local wave = 1
local result = Style.frame(root, UDim2.new(1, -24, 0, 0), C.sand) -- shown over the fight
Style.round(result, 18)
Style.stroke(result, C.ink, 3)
result.Name = "WaveResult"
result.AutomaticSize = Enum.AutomaticSize.Y
result.AnchorPoint, result.Position, result.Visible = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -84), false
result.ZIndex = 5
Style.pad(result, 14)
Style.list(result, 8)
local resultLimit = Instance.new("UISizeConstraint")
resultLimit.MaxSize = Vector2.new(400, 1000)
resultLimit.Parent = result
local resultTitle = Style.text(result, "", 24, C.text)
local resultSub = Style.text(result, "", 15, C.muted)
local drops = Instance.new("Frame")
drops.BackgroundTransparency = 1
drops.Size = UDim2.new(1, 0, 0, 26)
Style.list(drops, 14, true)
drops.Parent = result
local resultButtons = Instance.new("Frame")
resultButtons.BackgroundTransparency = 1
resultButtons.Size = UDim2.new(1, 0, 0, 44)
Style.list(resultButtons, 8, true)
resultButtons.Parent = result
-- A big title that fades as a fight begins: the wave, and who is in it.
local banner = Style.text(root, "", 56, C.text, UDim2.new(1, 0, 0, 70))
banner.AnchorPoint, banner.Position, banner.TextTransparency = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.14), 1
banner.TextXAlignment, banner.ZIndex = Enum.TextXAlignment.Center, 6
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Thickness, bannerStroke.Transparency = 4, 1
bannerStroke.Parent = banner
local bannerSub = Style.text(root, "", 22, C.muted, UDim2.new(1, 0, 0, 30))
bannerSub.AnchorPoint, bannerSub.Position, bannerSub.TextTransparency =
	Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.14), 1
bannerSub.TextXAlignment, bannerSub.ZIndex = Enum.TextXAlignment.Center, 6
bannerSub.Position += UDim2.fromOffset(0, 66)
local announced = 0
local function announce(n: number)
	announced += 1
	local mine = announced
	local boss = n % LevelRules.BOSS_EVERY == 0
	local names = {}
	for _, e in LevelRules.enemies(n) do
		table.insert(names, (StationConfig.foe(e.s) :: StationConfig.Foe).name)
	end
	banner.Text = if boss then `BOSS WAVE {n}` else `WAVE {n}`
	banner.TextColor3 = if boss then C.bad else C.text
	bannerSub.Text = table.concat(names, "  -  ")
	banner.TextTransparency, bannerStroke.Transparency, bannerSub.TextTransparency = 0, 0, 0
	task.delay(2.4, function()
		if announced ~= mine then
			return
		end
		local fade = TweenInfo.new(0.8)
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
local BIG: { [string]: number } = { common = 0, uncommon = 0, rare = 1, epic = 1, legendary = 2, mythic = 3 }
local function showRarity(a: any)
	revealed += 1
	local mine = revealed
	local rarity = StationRules.rarity(a)
	local big = BIG[rarity] or 0
	reveal.Text = string.upper(rarity) .. string.rep("!", big)
	reveal.TextColor3 = RARITY_COLOUR[rarity] or C.text
	local lines = { (if a.rainbow then "Rainbow " else "") .. nameOf(a) }
	local def = StationConfig.egg(a.egg or "")
	if a.v and def then
		for _, drop in def.rare do
			if drop.v == a.v then
				table.insert(lines, `Only 1 in {Format.commas(StationRules.PPM // drop.ppm)} {def.name}s hatches one`)
			end
		end
	end
	if a.rainbow then
		table.insert(lines, "A rainbow coat!")
	end
	revealSub.Text = table.concat(lines, "\n")
	revealSub.TextColor3 = if a.rainbow then Color3.fromRGB(255, 225, 100) else C.text
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
local again = Style.button(resultButtons, "", function()
	fight(wave)
end, "primary", UDim2.new(0.5, -4, 1, 0))
local leave = Style.button(resultButtons, "Leave the arena", function()
	result.Visible = false
	send("wave_done")
end, "ghost", UDim2.new(0.5, -4, 1, 0))
hideResult = function()
	result.Visible = false
end
local function buttons(showAgain: boolean)
	again.Visible = showAgain
	leave.Size = if showAgain then UDim2.new(0.5, -4, 1, 0) else UDim2.fromScale(1, 1)
end

fight = function(n: number): boolean
	local ok, code = request:InvokeServer("wave", n)
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		return false
	end
	wave = n
	show(nil)
	resultTitle.Text, resultSub.Text = `Wave {n}`, "The fight is on..."
	Style.clear(drops)
	buttons(false)
	leave.Text = "Skip the fight" -- the pay is already settled: leaving shows the result at once
	result.Visible = true
	announce(n)
	return true
end

-- Power attacks in a fight (decision 0092): a plate for each of the team's animals, bottom right, with
-- its health and its power meter. A full meter glows; tap the plate (or press its number key) to fire.
-- The server decides: a refused tap does nothing.
local plates = Instance.new("Frame")
plates.Name = "PowerPlates"
plates.BackgroundTransparency = 1
plates.AnchorPoint, plates.Position = Vector2.new(0, 1), UDim2.new(0, 14, 1, -90)
plates.Size, plates.AutomaticSize = UDim2.fromOffset(224, 0), Enum.AutomaticSize.Y
plates.Visible = false
plates.ZIndex = 4
local plateList = Style.list(plates, 12)
plateList.VerticalAlignment = Enum.VerticalAlignment.Bottom
plates.Parent = root

type Plate = { button: TextButton, hp: (number) -> (), power: (number) -> (), name: TextLabel, full: boolean }
local plateOf: { [number]: Plate } = {}

local function firePower(slot: number)
	local p = plateOf[slot]
	if p == nil or not p.full then
		return
	end
	local ok = request:InvokeServer("power", slot)
	if ok then
		Style.sound("claim")
	end
end

local function plate(slot: number, label: string): Plate
	local b = Style.button(plates, "", function()
		firePower(slot)
	end, "ghost", UDim2.fromOffset(224, 72))
	b.LayoutOrder = slot
	local name = Style.text(b, label, 17, C.text, UDim2.new(1, -60, 0, 22))
	name.Position, name.TextTruncate = UDim2.fromOffset(12, 6), Enum.TextTruncate.AtEnd
	local key = Style.chip(b, tostring(slot))
	key.AnchorPoint, key.Position = Vector2.new(1, 0), UDim2.new(1, -8, 0, 6)
	local hpBar, setHp = Style.bar(b, UDim2.new(1, -24, 0, 12), C.good)
	hpBar.Position = UDim2.fromOffset(12, 32)
	local pBar, setPower = Style.bar(b, UDim2.new(1, -24, 0, 10), C.accent)
	pBar.Position = UDim2.fromOffset(12, 52)
	return { button = b, hp = setHp, power = setPower, name = name, full = false }
end

UserInputService.InputBegan:Connect(function(input, used)
	if used or not plates.Visible then
		return
	end
	local slot = ({
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
	})[input.KeyCode]
	if slot then
		firePower(slot)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local folder = Workspace:FindFirstChild(`WaveShow{player.UserId}`)
		local seen: { [number]: boolean } = {}
		if folder then
			for _, m in folder:GetChildren() do
				local slot = m:GetAttribute("Slot")
				if m:GetAttribute("Side") == 1 and type(slot) == "number" then
					seen[slot] = true
					local p = plateOf[slot]
					if p == nil then
						local s, v = m:GetAttribute("Species"), m:GetAttribute("Variant")
						local va = if type(s) == "string" and type(v) == "string"
							then StationConfig.variant(s, v)
							else nil
						local sp = if type(s) == "string" then StationConfig.species(s) else nil
						p = plate(slot, if va then va.name elseif sp then sp.name else "?")
						plateOf[slot] = p
					end
					local hp, max = m:GetAttribute("Hp"), m:GetAttribute("MaxHp")
					local alive = type(hp) == "number" and hp > 0
					if type(hp) == "number" and type(max) == "number" then
						p.hp(hp / math.max(1, max))
					end
					local power = m:GetAttribute("Power")
					local full = alive and type(power) == "number" and power >= 1
					p.power(if type(power) == "number" then power else 0)
					if full ~= p.full then
						p.full = full
						Style.kind(p.button, if full then "primary" else if alive then "ghost" else "off")
						p.name.Text = if full
							then `POWER! {(string.gsub(p.name.Text, "^POWER! ", ""))}`
							else (string.gsub(p.name.Text, "^POWER! ", ""))
					elseif not alive then
						Style.kind(p.button, "off")
					end
				end
			end
		end
		for slot, p in plateOf do
			if not seen[slot] then
				p.button:Destroy()
				plateOf[slot] = nil
			end
		end
		plates.Visible = next(plateOf) ~= nil
	end
end)

local function foeCard(foeId: string)
	local foe = StationConfig.foe(foeId) :: StationConfig.Foe
	local boss = foe.kind == "dragon"
	local card = Style.card(waves.body, UDim2.fromOffset(122, 158), if boss then C.bad else C.edge)
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
	wave = math.clamp(wave, 1, profile.best + 1)
	Style.chip(waves.chips, `Best wave: {profile.best}`)
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
	end, if wave <= profile.best then "ghost" else "off", UDim2.fromOffset(60, 52))
	nextButton.AnchorPoint, nextButton.Position, nextButton.TextSize = Vector2.new(1, 0), UDim2.fromScale(1, 0), 28
	prev.Size, nextButton.Size = UDim2.fromOffset(46, 52), UDim2.fromOffset(46, 52)
	local head = Style.text(step, `Wave {wave}`, 28, C.text, UDim2.new(1, -100, 1, 0))
	head.Position, head.TextXAlignment = UDim2.fromOffset(50, 0), Enum.TextXAlignment.Center

	local team = StationProgress.fighters(profile)
	local go = Style.button(waves.tabs, `Fight wave {wave}`, function()
		fight(wave)
	end, if #team > 0 then "danger" else "off", UDim2.fromOffset(196, 60))
	go.TextSize, go.LayoutOrder = 24, nextOrder()

	section(waves.body, "Enemies", nextOrder())
	local line = Instance.new("Frame")
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, -20, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.LayoutOrder = nextOrder()
	Style.list(line, 8, true, true)
	line.Parent = waves.body
	for _, e in LevelRules.enemies(wave) do
		foeCard(e.s).Parent = line
	end

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
	wave = if profile then profile.best + 1 else 1
	show("waves")
end

-- The card under the cursor ----------------------------------------------------------------------

-- Pointing at an animal shows a small card that follows the cursor: its name, its rarity in the
-- rarity's colour, role and group, the six stats and a health bar. Every model carries what the
-- card needs as attributes (the server's `describe`); the cursor finds a model by its unseen
-- "CreatureHit" box.
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local card = Ui.panel(screen, { size = UDim2.fromOffset(236, 132), name = "AnimalCard" })
card.Visible = false
card.ZIndex = 20
local cardEdge = Instance.new("UIStroke")
cardEdge.Thickness = 3
cardEdge.Parent = card
local cardName = Ui.label(card, "", { size = 20 })
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

-- Admin menu (decision 0038): only for players the server marks as admin (the game's owner, or
-- anyone in Studio). Stands animal and enemy models in front of you to look at, and plays test
-- waves in the arena; nothing is saved.
local adminTab = "tests"
local adminTests = Instance.new("Frame") -- the Tests tab's buttons, made once
adminTests.BackgroundTransparency = 1
adminTests.Size, adminTests.AutomaticSize = UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y
Style.list(adminTests, 10)
adminTests.Parent = admin.body
local adminAdd = { body = Instance.new("Frame") } -- the Add animals tab's tiles
adminAdd.body.BackgroundTransparency = 1
adminAdd.body.Size, adminAdd.body.AutomaticSize = UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y
Style.list(adminAdd.body, 10, true, true)
adminAdd.body.Visible = false
adminAdd.body.Parent = admin.body
do
	local n = 0
	local function add(text: string, action: string, value: any?)
		n += 1
		Style.button(adminTests, text, function()
			send(action, value)
		end, "ghost", UDim2.new(1, 0, 0, 44)).LayoutOrder =
			n
	end
	add("Spawn every animal and enemy in a row", "look", 0)
	add("Clear them", "look_clear")
	for _, anim in { "idle", "walk", "attack", "magic", "hit", "die" } do
		add(`All play: {anim}`, "look_anim", anim)
	end
	for _, test in
		{
			{ 1, "starters", "Test wave 1 (starter team)" },
			{ 6, "starters", "Test wave 6 (starter team, mages)" },
			{ 10, "starters", "Test wave 10 (starter team, first dragon)" },
			{ 10, "mythics", "Test wave 10 (best team)" },
			{ 30, "mythics", "Test wave 30 (best team, a Drake)" },
			{ 60, "mythics", "Test wave 60 (best team, the Dragon)" },
			{ 12, "mine", "Test wave 12 (my own team)" },
		}
	do
		n += 1
		Style.button(adminTests, test[3] :: string, function()
			local ok, code = request:InvokeServer("testwave", test[1], test[2])
			if not ok then
				Style.toast(
					screen,
					if code == "models" then "An enemy model is not uploaded yet" else REFUSED[code] or `Can't ({code})`
				)
			else
				show(nil)
			end
		end, "ghost", UDim2.new(1, 0, 0, 44)).LayoutOrder =
			n
	end
	local k = 0 -- the server lists them in this order too
	for _, sp in StationConfig.SPECIES do
		k += 1
		add(`Spawn {sp.name}`, "look", k)
		for _, va in sp.variants do
			k += 1
			add(`Spawn {va.name} ({va.tier})`, "look", k)
		end
	end
	for _, foe in StationConfig.FOES do
		k += 1
		add(`Spawn {foe.name} (Hexbound {foe.kind})`, "look", k)
	end
end

-- Admin menu 2 (decisions 0049, 0058): add an animal of any species or variant to your own ranch by
-- tapping its picture. The row on top sets the level of every stat of the new animal and whether it
-- wears the rainbow coat. The server checks the admin and the numbers.
do
	local LEVELS = { 1, 10, 35, StationConfig.MAX_LEVEL }
	local level, rainbow = 1, false
	local list: { { s: string, v: string? } } = {} -- in the server's order (LOOKS: a species, then its variants)
	for _, sp in StationConfig.SPECIES do
		table.insert(list, { s = sp.id })
		for _, va in sp.variants do
			table.insert(list, { s = sp.id, v = va.id })
		end
	end
	local function draw()
		Style.clear(adminAdd.body)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size, row.AutomaticSize = UDim2.new(1, -20, 0, 0), Enum.AutomaticSize.Y
		row.LayoutOrder = 0
		Style.list(row, 6, true, true)
		row.Parent = adminAdd.body
		local words = Style.text(row, "Stat level", 16, C.muted, UDim2.fromOffset(80, 40))
		words.LayoutOrder = 0
		local picks: { [number]: TextButton } = {}
		for i, n in LEVELS do
			picks[n] = Style.button(row, tostring(n), function()
				level = n
				for m, b in picks do
					Style.kind(b, if m == level then "primary" else "ghost")
				end
			end, if n == level then "primary" else "ghost", UDim2.fromOffset(52, 40))
			picks[n].LayoutOrder = i
		end
		local coat = Style.button(row, if rainbow then "Rainbow coat: on" else "Rainbow coat: off", function()
			rainbow = not rainbow
			draw() -- every picture changes its coat
		end, if rainbow then "good" else "ghost", UDim2.fromOffset(170, 40))
		coat.LayoutOrder = #LEVELS + 1
		for k, a in list do
			local colour = RARITY_COLOUR[StationRules.rarity(a :: any)] or C.text
			local name = nameOf(a)
			local tile = Style.button(adminAdd.body, "", function()
				local ok, code = request:InvokeServer("admin_add", k, level, rainbow)
				local said = if ok
					then `Added a {if rainbow then "Rainbow " else ""}{name}, level {level}`
					else REFUSED[code] or `Can't do that ({code})`
				Style.toast(screen, said, 2)
			end, "ghost", UDim2.fromOffset(116, 146))
			tile.Name, tile.LayoutOrder = name, k
			Style.stroke(tile, colour, 2)
			local view = Portrait.new(
				tile,
				StationRules.assetOf(a.s, a.v),
				{ size = UDim2.fromOffset(96, 96), background = darker(colour), rainbow = rainbow }
			)
			view.Position = UDim2.fromOffset(10, 8)
			local label = Style.text(tile, name, 14, colour, UDim2.new(1, -8, 0, 34))
			label.Position = UDim2.fromOffset(4, 108)
			label.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	local drawn = false
	redraw.admin = function() -- the tiles are drawn once, when first opened: a new profile must not scroll it back up
		Style.clear(admin.tabs)
		for _, t in { { "tests", "Tests" }, { "add", "Add animals" } } do
			Style.tab(admin, t[2], adminTab == t[1], function()
				adminTab = t[1]
				redraw.admin()
			end)
		end
		adminTests.Visible, adminAdd.body.Visible = adminTab == "tests", adminTab == "add"
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
		profile = payload
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
		local took = string.format("%.0f", payload.seconds)
		Style.clear(drops)
		if payload.won then
			resultTitle.Text, resultTitle.TextColor3 = `Wave {payload.wave} cleared!`, C.good
			Style.sound("claim")
			resultSub.Text = `Your team won in {took}s.{if payload.first then " First clear!" else ""}`
			Style.amount(drops, "coins", `+{Format.commas(payload.coins)}`)
			Style.amount(drops, "xp", `+{payload.xp} XP`)
			if payload.samples > 0 then
				Style.amount(drops, "samples", `+{payload.samples} samples`)
			end
			wave = payload.wave + 1
			again.Text = `Fight wave {wave}`
		else
			resultTitle.Text, resultTitle.TextColor3 = `Wave {payload.wave}: beaten`, C.bad
			resultSub.Text = `Your team lost in {took}s to {payload.foes}. Train your animals up and try again.`
			wave = payload.wave
			again.Text = `Try wave {wave} again`
		end
		buttons(true)
		leave.Text = "Leave the arena"
		result.Visible = true
	elseif kind == "waveshow" then
		local took = string.format("%.0f", payload.seconds)
		Style.toast(
			screen,
			`Wave {payload.wave}: {if payload.won then "your team won" else "your team lost"} in {took}s ({payload.attacks} attacks) against {payload.foes}`,
			7
		)
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
			local said = ({
				done = "Trade done! Your new animals are in your barn.",
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
			tradeState = payload
			if opening and openName ~= "trade" then
				show("trade")
				return
			end
		end
		if openName == "trade" then
			redraw.trade()
		end
	elseif kind == "collected" then
		Style.toast(
			screen,
			`Collected {Format.commas(payload)} {if payload == 1 then "coin" else "coins"} from your windmill`,
			4
		)
	elseif kind == "bought" then
		local egg = StationConfig.egg(payload)
		if egg then
			Style.toast(screen, `{egg.name} bought. It is in your egg storage.`, 3)
		end
	elseif kind == "upgraded" then
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
