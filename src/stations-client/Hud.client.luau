--!strict
-- Animal Stations HUD (decisions 0025, 0029): coins and player level, hatch and refusal toasts,
-- and the Animals panel. Each animal shows its role and group, a team button, and one button per
-- stat with the stat's value and level: tap a stat to train it there, tap it again to stop.
-- Display only: every button names an action; the server decides everything and sends the new
-- profile. Training progress between profiles is a local preview with the same pure rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

Ui.setTheme({ font = Enum.Font.FredokaOne, accent = Color3.fromRGB(255, 200, 70) })

local RARITY_COLOUR: { [string]: Color3 } = {
	common = Color3.fromRGB(200, 200, 200),
	uncommon = Color3.fromRGB(110, 220, 110),
	rare = Color3.fromRGB(90, 160, 255),
	epic = Color3.fromRGB(190, 110, 255),
	legendary = Color3.fromRGB(255, 200, 60),
	mythic = Color3.fromRGB(255, 120, 200),
}
local TRAINING = Color3.fromRGB(90, 210, 130) -- the stat button an animal is training at
local ROLE_NAME: { [string]: string } = { attack = "Attack", defense = "Defence", utility = "Utility", titan = "TITAN" }
local GROUP_NAME: { [string]: string } = { pack = "Pack", solitary = "Solitary" }
local STAT_SHORT: { [string]: string } =
	{ speed = "SPD", strength = "STR", stamina = "STA", mana = "MANA", health = "HP", defence = "DEF" }

local lockedAt = 0
for _, egg in StationConfig.EGGS do
	lockedAt = math.max(lockedAt, egg.unlock or 0)
end
local REFUSED: { [string]: string } = {
	coins = "Not enough coins",
	locked = `Reach level {lockedAt} to unlock that egg`,
	full = "Your ranch is full",
	team_full = "Your team is full (3)",
	train_full = `Only {StationProgress.TRAIN_MAX} animals can train at once`,
	training = "Stop its training first",
	maxed = `That stat is already level {StationConfig.MAX_LEVEL}`,
	loading = "Still loading your ranch...",
	rate = "Slow down a little",
}

local screen = Ui.screen("StationsHud")
local profile: any = nil
local tickers: { () -> () } = {} -- refresh the live text of every stat being trained

-- Coins and player level, top left
local coinBox = Ui.panel(screen, { size = UDim2.fromOffset(220, 76), name = "Coins" })
coinBox.Position = UDim2.fromOffset(12, 12)
local coins = Ui.label(coinBox, "Coins: ...", { size = 24 })
local levelText = Ui.label(coinBox, "Level ...", { size = 16, muted = true })

-- Animals button and panel
local toggle = Ui.panel(screen, { size = UDim2.fromOffset(220, 64), name = "AnimalsButton" })
toggle.Position = UDim2.fromOffset(12, 96)
local panel = Ui.panel(screen, { size = UDim2.fromOffset(640, 440), anchor = "center", name = "Animals" })
panel.Visible = false
local title = Ui.label(panel, "Your animals", { size = 24 })
title.LayoutOrder = 1
local hint = Ui.label(
	panel,
	"Each stat shows its level and battle value. Tap one to train it at your ranch; tap again to stop.",
	{ size = 14, muted = true }
)
hint.LayoutOrder = 2
local list = Instance.new("ScrollingFrame")
list.LayoutOrder = 3
list.Size = UDim2.new(1, 0, 1, -64)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
Ui.button(toggle, "Animals", function()
	panel.Visible = not panel.Visible
end)

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
	return StationRules.train(a, a.at, math.max(0, Workspace:GetServerTimeNow() - a.since))
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
		local left = (1 - progress) * StationRules.levelSeconds(level + 1)
		return `{head}\n{value}   {Format.ago(left)}`
	end
	return `{head}\n{value}`
end

local RIGHT = 344 -- width of a row's button block: the stat grid, a gap and the team button

local function line(parent: Instance, value: string, size: number, y: number, colour: Color3?): TextLabel
	local l = Ui.label(parent, value, { size = size, muted = colour == nil })
	l.Position = UDim2.fromOffset(10, y)
	l.Size = UDim2.new(1, -(RIGHT + 26), 0, 0)
	if colour then
		l.TextColor3 = colour
	end
	return l
end

local function row(a: any, order: number)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -12, 0, 100)
	frame.BackgroundColor3 = Color3.fromRGB(40, 44, 58)
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local sp = StationConfig.species(a.s)
	local rarity = StationRules.rarity(a)
	local isTitan = StationRules.role(a) == StationConfig.TITAN
	local inTeam = table.find(profile.team, a.id) ~= nil or profile.titan == a.id
	local station = a.at and StationConfig.station(a.at)
	line(frame, nameOf(a), 20, 6, RARITY_COLOUR[rarity] or Color3.new(1, 1, 1))
	line(
		frame,
		`{rarity}  -  {ROLE_NAME[StationRules.role(a)] or "?"}  -  {GROUP_NAME[if sp then sp.group else ""] or "?"}`,
		15,
		34
	)
	line(
		frame,
		if station
			then `At the {station.name}`
			elseif inTeam then (if isTitan then "Your Titan" else "In your team")
			else "Resting",
		15,
		58
	)

	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, -8, 0.5, 0)
	right.Size = UDim2.fromOffset(RIGHT, 88)
	right.Parent = frame

	-- one button per stat: value and level; tap to train it, tap the green one to stop
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(246, 88)
	grid.Parent = right
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.fromOffset(78, 42)
	cells.CellPadding = UDim2.fromOffset(6, 4)
	cells.FillDirectionMaxCells = 3
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	for i, st in StationConfig.STATIONS do
		local training = a.at == st.id
		local button = Ui.button(grid, statText(live(a), st.stat, training), function()
			if training then
				send("stop", a.id)
			else
				send("train", a.id, st.id)
			end
		end)
		button.LayoutOrder = i
		button.TextSize = 12
		if training then
			button.BackgroundColor3 = TRAINING
			table.insert(tickers, function()
				button.Text = statText(live(a), st.stat, true)
			end)
		end
	end

	local team = Ui.button(
		right,
		if inTeam then "Leave\nteam" elseif isTitan then "Join as\nTitan" else "Join\nteam",
		function()
			send("team", a.id)
		end
	)
	team.AnchorPoint = Vector2.new(1, 0)
	team.Position = UDim2.fromScale(1, 0)
	team.Size = UDim2.fromOffset(92, 88)
	team.TextSize = 16

	frame.Parent = list
end

local function refresh()
	if profile == nil then
		return
	end
	coins.Text = `Coins: {profile.coins}`
	local level = StationProgress.playerLevel(profile)
	local from, to = StationProgress.xpFor(level), StationProgress.xpFor(level + 1)
	levelText.Text = `Level {level}   ({profile.xp - from}/{to - from} XP)`
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(tickers)
	title.Text =
		`Your animals ({#profile.animals})  -  Team {#profile.team}/{StationProgress.TEAM_SIZE}  -  Titan: {if profile.titan
			then "yes"
			else "none"}`
	if #profile.animals == 0 then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, -12, 0, 60)
		Ui.label(empty, "No animals yet. Buy an egg at the market stalls in the plaza!", { muted = true })
		empty.Parent = list
	end
	for i, a in profile.animals do
		row(a, i)
	end
end

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
		Ui.toast(screen, `You hatched a {nameOf(payload)}! ({StationRules.rarity(payload)}){lucky}`, 4)
	elseif kind == "refused" then
		Ui.toast(screen, REFUSED[payload] or `Can't do that ({payload})`)
	end
end)

-- Training ticks on screen once a second while the panel is open.
task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible then
			for _, tick in tickers do
				tick()
			end
		end
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
