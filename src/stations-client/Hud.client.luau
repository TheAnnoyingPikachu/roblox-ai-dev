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
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

Ui.setTheme({ font = Enum.Font.FredokaOne, accent = Color3.fromRGB(255, 200, 70) })

local C = Style.C
local RARITY_COLOUR = Style.RARITY
local TRAINING = Color3.fromRGB(70, 170, 104) -- the stat button an animal is training at
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
	locked = "Clear more waves to unlock that egg",
	full = "Your barn is full: upgrade the Barn at your ranch",
	samples = "Not enough samples",
	admin = "Admins only",
	eggs_full = "Your egg storage is full",
	nests_full = "All six hatching places are taken",
	not_ready = "That egg is not ready yet",
	hatching = "That egg is already hatching",
	top = "That is already at its top level",
	team_full = "Your team is full (3)",
	train_full = "Every training place is taken: upgrade the Ranch House",
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
		Ui.toast(screen, REFUSED[code] or `Can't do that ({code})`)
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
local adminAdd = newSheet("adminadd", "Add animals")
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
navLimit.MaxSize = Vector2.new(420, 64)
navLimit.Parent = nav
Style.list(nav, 8, true)
nav.Parent = root

local hideResult: () -> () = function() end -- set once the fight panel exists
local function navButton(label: string, stripe: Color3, order: number, onClick: () -> ()): TextLabel
	local b = Style.button(nav, label, onClick, "ghost", UDim2.new(1 / 3, -6, 1, 0))
	b.LayoutOrder, b.TextSize = order, 22
	Style.stroke(b, C.edge, 2)
	local line = Style.frame(b, UDim2.new(0.5, 0, 0, 5), stripe)
	line.AnchorPoint, line.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -7)
	Style.round(line, 3)
	local dot = Style.frame(b, UDim2.fromOffset(26, 26), C.bad)
	dot.AnchorPoint, dot.Position, dot.Visible = Vector2.new(1, 0), UDim2.new(1, 6, 0, -8), false
	Style.round(dot, 13)
	Style.stroke(dot, C.panel, 2)
	local count = Style.text(dot, "", 15, Color3.new(1, 1, 1), UDim2.fromScale(1, 1))
	count.TextXAlignment = Enum.TextXAlignment.Center
	return count
end
navButton("Animals", C.good, 1, function()
	show("animals")
end)
local openWaves: () -> () -- below, with the wave sheet
navButton("Waves", C.bad, 2, function()
	openWaves()
end)
navButton("Home", C.info, 3, function()
	local ok, code = request:InvokeServer("home")
	if not ok then
		Ui.toast(screen, REFUSED[code] or `Can't do that ({code})`)
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
local addToggle = Style.button(root, "Add animals", function()
	show(if openName == "adminadd" then nil else "adminadd")
end, "ghost", UDim2.fromOffset(120, 40))
addToggle.AnchorPoint, addToggle.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 58)
addToggle.TextSize = 16

-- Animals ------------------------------------------------------------------------------------------

local function darker(colour: Color3): Color3
	return colour:Lerp(Color3.fromRGB(26, 24, 42), 0.78)
end

local function animalCard(a: any, order: number)
	local sp = StationConfig.species(a.s)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local role = StationRules.role(a)
	local isTitan = role == StationConfig.TITAN
	local inTeam = table.find(profile.team, a.id) ~= nil or profile.titan == a.id
	local station = a.at and StationConfig.station(a.at)

	local card = Style.card(animals.body, UDim2.fromOffset(236, 272), colour)
	card.LayoutOrder = order
	local view =
		Portrait.new(card, StationRules.assetOf(a.s, a.v), { background = darker(colour), rainbow = a.rainbow })
	view.Position = UDim2.fromOffset(10, 10)
	if a.rainbow then
		local coat = Style.chip(card, "RAINBOW", Color3.new(1, 1, 1), C.panel)
		coat.Position = UDim2.fromOffset(14, 70)
		local colours = Instance.new("UIGradient")
		colours.Color = RAINBOW
		colours.Parent = coat
	end
	local name = Style.text(card, nameOf(a), 20, colour, UDim2.new(1, -116, 0, 24))
	name.Position = UDim2.fromOffset(106, 10)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local tag = Style.chip(card, string.upper(rarity), colour, C.panel)
	tag.Position = UDim2.fromOffset(106, 36)
	local kind = Style.text(
		card,
		`{ROLE_NAME[role] or "?"}, {GROUP_NAME[if sp then sp.group else ""] or "?"}`,
		14,
		C.muted,
		UDim2.new(1, -116, 0, 18)
	)
	kind.Position = UDim2.fromOffset(106, 64)
	local status = if station
		then Style.chip(card, `Training {STAT_SHORT[station.stat]}`, TRAINING, Color3.new(1, 1, 1))
		elseif inTeam then Style.chip(
			card,
			if isTitan then "Your Titan" else "In your team",
			C.good,
			Color3.fromRGB(10, 40, 18)
		)
		else Style.chip(card, "Resting")
	status.Position = UDim2.fromOffset(106, 86)

	-- one button per stat: value and level; tap to train it, tap the green one to stop
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position, grid.Size = UDim2.fromOffset(10, 120), UDim2.new(1, -20, 0, 92)
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(1 / 3, -4, 0, 44)
	cells.CellPadding = UDim2.fromOffset(6, 4)
	cells.FillDirectionMaxCells = 3
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	grid.Parent = card
	for i, st in StationConfig.STATIONS do
		local training = a.at == st.id
		local button = Style.button(grid, statText(live(a), st.stat, training), function()
			if training then
				send("stop", a.id)
			else
				send("train", a.id, st.id)
			end
		end, "stat")
		button.LayoutOrder, button.TextSize = i, 13
		if training then
			button.BackgroundColor3 = TRAINING
			table.insert(tickers, function()
				button.Text = statText(live(a), st.stat, true)
			end)
		end
	end

	local team = Style.button(
		card,
		if inTeam then "Leave team" elseif isTitan then "Join as Titan" else "Join team",
		function()
			send("team", a.id)
		end,
		if inTeam then "ghost" else "good"
	)
	team.Position = UDim2.fromOffset(10, 218)
	team.Size = UDim2.new(1, -20, 0, 44)
end

redraw.animals = function()
	Style.clear(animals.body)
	Style.clear(animals.chips)
	table.clear(tickers)
	Style.chip(animals.chips, `{#profile.animals} animals`)
	Style.chip(animals.chips, `Team {#profile.team}/{StationProgress.TEAM_SIZE}`, C.good, Color3.fromRGB(10, 40, 18))
	Style.chip(
		animals.chips,
		if profile.titan then "Titan ready" else "No Titan",
		if profile.titan then C.gold else C.cardHi,
		if profile.titan then C.accentText else C.text
	)
	if #profile.animals == 0 then
		local empty = Style.card(animals.body, UDim2.new(1, -20, 0, 96))
		local words =
			"No animals yet. Buy an egg from the egg vendor on your ranch, hatch it, and your first animal joins your team."
		local t = Style.text(empty, words, 18, C.muted, UDim2.new(1, -28, 1, -20))
		t.Position = UDim2.fromOffset(14, 10)
	end
	for i, a in profile.animals do
		animalCard(a, i)
	end
end

-- Eggs: the storage and what is hatching ----------------------------------------------------------------

-- A picture of an egg: its own model (decision 0057), `side` units square.
local function eggArt(parent: Instance, eggId: string, side: number): ViewportFrame
	return Portrait.new(parent, `egg_{eggId}`, { size = UDim2.fromOffset(side, side) })
end

local function eggCard(k: number, e: any)
	local def = StationConfig.egg(e.egg) :: StationConfig.Egg
	local now = Workspace:GetServerTimeNow()
	local ready = e.since ~= nil and now >= e.since + def.hatch
	local card = Style.card(eggs.body, UDim2.fromOffset(236, 140), if ready then C.good else C.edge)
	card.LayoutOrder = k
	eggArt(card, e.egg, 68).Position = UDim2.fromOffset(10, 10)
	local name = Style.text(card, def.name, 19, C.text, UDim2.new(1, -90, 0, 24))
	name.Position = UDim2.fromOffset(84, 10)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local info = Style.text(card, "", 14, C.muted, UDim2.new(1, -90, 0, 36))
	info.Position = UDim2.fromOffset(84, 34)
	if e.since == nil then
		info.Text = `Takes {Format.ago(def.hatch)} to hatch`
		local b = Style.button(card, "Hatch it", function()
			send("hatch", k)
		end, "primary")
		b.Position, b.Size = UDim2.fromOffset(10, 90), UDim2.new(1, -20, 0, 40)
	else
		local bar, set = Style.bar(card, UDim2.new(1, -20, 0, 14), C.accent)
		bar.Position = UDim2.fromOffset(10, 90)
		local left = Style.text(card, "", 15, C.text, UDim2.new(1, -20, 0, 20))
		left.Position = UDim2.fromOffset(10, 110)
		local function tick()
			local t = Workspace:GetServerTimeNow()
			local remaining = e.since + def.hatch - t
			set(1 - remaining / def.hatch)
			if remaining <= 0 then
				info.Text = "Ready! Open it at your hatchery."
				info.TextColor3 = C.good
				left.Text = ""
			else
				info.Text = "Hatching..."
				left.Text = `Opens in {Format.ago(remaining)}`
			end
		end
		tick()
		table.insert(eggTickers, tick)
	end
end

redraw.eggs = function()
	Style.clear(eggs.body)
	Style.clear(eggs.chips)
	table.clear(eggTickers)
	local hatching = 0
	for _, e in profile.eggs do
		hatching += if e.since then 1 else 0
	end
	Style.chip(eggs.chips, `Hatching {hatching}/{StationProgress.MAX_EGGS}`, C.accent, C.accentText)
	Style.chip(eggs.chips, `In storage {#profile.eggs - hatching}/{StationProgress.MAX_STORED}`)
	if #profile.eggs == 0 then
		local empty = Style.card(eggs.body, UDim2.new(1, -20, 0, 80))
		local t = Style.text(
			empty,
			"No eggs. Buy some from the egg vendor on your ranch.",
			18,
			C.muted,
			UDim2.new(1, -28, 1, -20)
		)
		t.Position = UDim2.fromOffset(14, 10)
	end
	for k, e in profile.eggs do
		eggCard(k, e)
	end
end

-- Ranch: upgrades ------------------------------------------------------------------------------------

local function upgradeCard(u: StationConfig.Upgrade, order: number)
	local level = profile.upgrades[u.id] or 0
	local card = Style.card(ranch.body, UDim2.fromOffset(366, 168))
	card.LayoutOrder = order
	local title = Style.text(card, u.name, 22, C.text, UDim2.new(1, -24, 0, 26))
	title.Position = UDim2.fromOffset(14, 10)
	local pips = Instance.new("Frame")
	pips.BackgroundTransparency = 1
	pips.Position, pips.Size = UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 14)
	Style.list(pips, 4, true)
	pips.Parent = card
	for i = 1, #u.levels do
		local pip = Style.frame(pips, UDim2.fromOffset(22, 12), if i <= level then C.good else C.off)
		Style.round(pip, 4)
		pip.LayoutOrder = i
	end
	local now =
		Style.text(card, `{StationProgress.value(profile, u.id)} {u.gives}`, 18, C.text, UDim2.new(1, -28, 0, 22))
	now.Position = UDim2.fromOffset(14, 60)
	local cost = u.levels[level + 1]
	if cost == nil then
		local done = Style.chip(card, "TOP LEVEL", C.gold, C.accentText)
		done.Position = UDim2.fromOffset(14, 100)
		return
	end
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.Position, price.Size = UDim2.fromOffset(14, 86), UDim2.new(1, -28, 0, 24)
	Style.list(price, 14, true)
	price.Parent = card
	Style.amount(price, "coins", Format.commas(cost.coins))
	if cost.samples > 0 then
		Style.amount(price, "samples", `{cost.samples} samples`)
	end
	local can = profile.coins >= cost.coins and profile.samples >= cost.samples
	local b = Style.button(card, `Upgrade to {cost.value}`, function()
		send("upgrade", u.id)
	end, if can then "good" else "off")
	b.Position, b.Size = UDim2.fromOffset(14, 114), UDim2.new(1, -28, 0, 44)
end

redraw.ranch = function()
	Style.clear(ranch.body)
	Style.clear(ranch.chips)
	Style.amount(ranch.chips, "coins", Format.commas(profile.coins))
	Style.amount(ranch.chips, "samples", `{Format.commas(profile.samples)} samples`)
	for i, u in StationConfig.UPGRADES do
		upgradeCard(u, i)
	end
	local more = Style.card(ranch.body, UDim2.new(1, -20, 0, 70))
	more.LayoutOrder = 100
	local b = Style.button(more, "Open your eggs", function()
		show("eggs")
	end, "ghost")
	b.Position, b.Size = UDim2.fromOffset(12, 13), UDim2.new(1, -24, 0, 44)
	if RunService:IsStudio() then -- a way to try the upgrades without fighting for them
		local funds = Style.button(ranch.body, "Test funds (Studio only)", function()
			send("funds")
		end, "ghost", UDim2.new(1, -20, 0, 44))
		funds.LayoutOrder = 101
	end
end

-- Egg vendor --------------------------------------------------------------------------------------------

redraw.shop = function()
	Style.clear(shop.body)
	Style.clear(shop.chips)
	Style.amount(shop.chips, "coins", Format.commas(profile.coins))
	Style.chip(shop.chips, `Level {StationProgress.playerLevel(profile)}`)
	Style.chip(shop.chips, `Best wave: {profile.best}`)
	local rows = 1 -- seven rare drops fit across a card: every card is as tall as the longest list needs
	for _, def in StationConfig.EGGS do
		rows = math.max(rows, math.ceil(#def.rare / 7))
	end
	local more = (rows - 1) * 76
	for k, def in StationConfig.EGGS do
		local locked = def.wave ~= nil and profile.best < def.wave
		local card = Style.card(shop.body, UDim2.fromOffset(366, 312 + more))
		card.LayoutOrder = k
		eggArt(card, def.id, 80).Position = UDim2.fromOffset(14, 12)
		local name = Style.text(card, def.name, 22, C.text, UDim2.new(1, -110, 0, 26))
		name.Position = UDim2.fromOffset(106, 12)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position, row.Size = UDim2.fromOffset(106, 44), UDim2.new(1, -120, 0, 26)
		Style.list(row, 8, true)
		row.Parent = card
		Style.amount(row, "coins", Format.commas(def.price))
		Style.chip(row, Format.ago(def.hatch))
		if locked then
			local lock = Style.chip(card, `Clear wave {def.wave} to unlock`, C.bad, Color3.new(1, 1, 1))
			lock.Position = UDim2.fromOffset(106, 74)
		end
		local inside = Instance.new("Frame") -- what it can hatch
		inside.BackgroundTransparency = 1
		inside.Position, inside.Size = UDim2.fromOffset(14, 100), UDim2.new(1, -28, 0, 52)
		Style.list(inside, 5, true)
		inside.Parent = card
		local names = {}
		for i, o in def.odds do
			local sp = StationConfig.species(o.id) :: StationConfig.Species
			table.insert(names, sp.name)
			local view = Portrait.new(
				inside,
				StationRules.assetOf(o.id, nil),
				{ size = UDim2.fromOffset(48, 48), background = darker(RARITY_COLOUR[sp.rarity] or C.text) }
			)
			view.LayoutOrder = i
		end
		local list = Style.text(card, table.concat(names, ", "), 13, C.muted, UDim2.new(1, -28, 0, 32))
		list.Position = UDim2.fromOffset(14, 156)
		local rare = Instance.new("Frame") -- its variants: drops of their own, each with its odds
		rare.BackgroundTransparency = 1
		rare.Position, rare.Size = UDim2.fromOffset(14, 188), UDim2.new(1, -28, 0, 72 + more)
		Style.list(rare, 4, true, true)
		rare.Parent = card
		for i, drop in def.rare do
			local colour = RARITY_COLOUR[(StationConfig.variant(drop.s, drop.v) :: StationConfig.Variant).tier]
				or C.text
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromOffset(44, 72)
			cell.LayoutOrder = i
			cell.Parent = rare
			Portrait.new(
				cell,
				StationRules.assetOf(drop.s, drop.v),
				{ size = UDim2.fromOffset(44, 44), background = darker(colour) }
			)
			local odds = Style.text(
				cell,
				`1 in {Format.short(StationRules.PPM / drop.ppm)}`,
				11,
				colour,
				UDim2.fromOffset(44, 26)
			)
			odds.Position = UDim2.fromOffset(0, 46)
			odds.TextXAlignment = Enum.TextXAlignment.Center
		end
		local can = not locked and profile.coins >= def.price
		local b = Style.button(card, `Buy for {Format.commas(def.price)}`, function()
			if locked then
				Ui.toast(screen, `Clear wave {def.wave} to unlock the {def.name}`)
				return
			end
			send("buy", def.id)
		end, if can then "primary" else "off")
		b.Position, b.Size = UDim2.fromOffset(14, 266 + more), UDim2.new(1, -28, 0, 36)
	end
end

-- Waves ---------------------------------------------------------------------------------------------------

local wave = 1
local result = Style.card(root, UDim2.new(1, -24, 0, 0), C.accent) -- shown over the fight
result.Name = "WaveResult"
result.AutomaticSize = Enum.AutomaticSize.Y
result.AnchorPoint, result.Position, result.Visible = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -84), false
result.ZIndex = 5
Style.pad(result, 14)
Style.list(result, 8)
local resultLimit = Instance.new("UISizeConstraint")
resultLimit.MaxSize = Vector2.new(440, 1000)
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
		Ui.toast(screen, REFUSED[code] or `Can't do that ({code})`)
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
	local name = Style.text(card, foe.name, 14, C.hex, UDim2.new(1, -8, 0, 36))
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
	step.Size = UDim2.new(1, -20, 0, 52)
	step.LayoutOrder = nextOrder()
	step.Parent = waves.body
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
	local head = Style.text(step, `Wave {wave}`, 34, C.text, UDim2.new(1, -140, 1, 0))
	head.Position, head.TextXAlignment = UDim2.fromOffset(70, 0), Enum.TextXAlignment.Center

	local team = StationProgress.fighters(profile)
	local go = Style.button(waves.body, `Fight wave {wave}`, function()
		fight(wave)
	end, if #team > 0 then "primary" else "off", UDim2.new(1, -20, 0, 56))
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
		local name = Style.text(card, nameOf(a), 14, colour, UDim2.new(1, -6, 0, 34))
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
bar.BackgroundColor3 = Color3.fromRGB(40, 36, 46)
bar.BorderSizePixel = 0
bar.Parent = card
local fill = Instance.new("Frame")
fill.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
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
do
	local n = 0
	local function add(text: string, action: string, value: any?)
		n += 1
		Style.button(admin.body, text, function()
			send(action, value)
		end, "ghost", UDim2.new(1, -20, 0, 44)).LayoutOrder =
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
		Style.button(admin.body, test[3] :: string, function()
			local ok, code = request:InvokeServer("testwave", test[1], test[2])
			if not ok then
				Ui.toast(
					screen,
					if code == "models" then "An enemy model is not uploaded yet" else REFUSED[code] or `Can't ({code})`
				)
			else
				show(nil)
			end
		end, "ghost", UDim2.new(1, -20, 0, 44)).LayoutOrder =
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
				Ui.toast(screen, said, 2)
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
	redraw.adminadd = function() -- drawn once, when first opened: a new profile must not scroll it back up
		if not drawn then
			drawn = true
			draw()
		end
	end
end
local function showAdmin()
	adminToggle.Visible = player:GetAttribute("Admin") == true
	addToggle.Visible = adminToggle.Visible
	if not adminToggle.Visible and (openName == "admin" or openName == "adminadd") then
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
	if owners and not mine then
		Ui.toast(screen, "This is not your ranch")
	elseif CollectionService:HasTag(prompt, "RanchMenu") then
		show("ranch")
	elseif CollectionService:HasTag(prompt, "EggStorage") then
		show("eggs")
	elseif CollectionService:HasTag(prompt, "WaveGate") then
		openWaves()
	elseif CollectionService:HasTag(prompt, "Egg") then
		send("open", prompt:GetAttribute("Index"))
	elseif CollectionService:HasTag(prompt, "Vendor") then
		if prompt:GetAttribute("Kind") == "eggs" then
			show("shop")
		else
			Ui.toast(screen, "The gear vendor is still unpacking. Gear is coming soon!")
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
		local coat = if payload.rainbow then "Rainbow " else ""
		Ui.toast(screen, `You hatched a {coat}{nameOf(payload)}! ({StationRules.rarity(payload)}){lucky}`, 4)
	elseif kind == "wavedone" then
		local took = string.format("%.0f", payload.seconds)
		Style.clear(drops)
		if payload.won then
			resultTitle.Text, resultTitle.TextColor3 = `Wave {payload.wave} cleared!`, C.good
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
		Ui.toast(
			screen,
			`Wave {payload.wave}: {if payload.won then "your team won" else "your team lost"} in {took}s ({payload.attacks} attacks) against {payload.foes}`,
			7
		)
	elseif kind == "bought" then
		local egg = StationConfig.egg(payload)
		if egg then
			Ui.toast(screen, `{egg.name} bought. It is in your egg storage.`, 3)
		end
	elseif kind == "upgraded" then
		local u = StationConfig.upgrade(payload)
		if u and profile then
			Ui.toast(screen, `{u.name} upgraded: {StationProgress.value(profile, u.id)} {u.gives}`, 4)
		end
	elseif kind == "refused" then
		Ui.toast(screen, REFUSED[payload] or `Can't do that ({payload})`)
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
