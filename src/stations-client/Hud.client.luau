--!strict
-- Animal Stations HUD (decision 0025): coins, hatch and refusal toasts, and the Animals panel
-- (team toggle, train at the station that matches the animal's type, stop training). Display
-- only: every button names an action; the server decides everything and sends the new profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationRules = require(Shared:WaitForChild("StationRules"))
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
local ROLE_NAME: { [string]: string } = { attack = "Attack", defense = "Defense", utility = "Utility", titan = "TITAN" }
local REFUSED: { [string]: string } = {
	coins = "Not enough coins",
	full = "Your ranch is full",
	team_full = "Your team is full (3)",
	train_full = "Only 4 animals can train at once",
	training = "Stop its training first",
	loading = "Still loading your ranch...",
	rate = "Slow down a little",
}

local screen = Ui.screen("StationsHud")
local profile: any = nil

-- Coins, top left
local coinBox = Ui.panel(screen, { size = UDim2.fromOffset(200, 48), name = "Coins" })
coinBox.Position = UDim2.fromOffset(12, 12)
local coins = Ui.label(coinBox, "Coins: ...", { size = 24 })

-- Animals button and panel
local toggle = Ui.panel(screen, { size = UDim2.fromOffset(200, 64), name = "AnimalsButton" })
toggle.Position = UDim2.fromOffset(12, 68)
local panel = Ui.panel(screen, { size = UDim2.fromOffset(560, 420), anchor = "center", name = "Animals" })
panel.Visible = false
local title = Ui.label(panel, "Your animals", { size = 26 })
title.LayoutOrder = 1
local list = Instance.new("ScrollingFrame")
list.LayoutOrder = 2
list.Size = UDim2.new(1, 0, 1, -40)
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

local function stationFor(stat: string): StationConfig.Station
	for _, st in StationConfig.STATIONS do
		if st.stat == stat then
			return st
		end
	end
	return StationConfig.STATIONS[1]
end

local function text(parent: Instance, value: string, size: number, y: number, colour: Color3?): TextLabel
	local l = Ui.label(parent, value, { size = size, muted = colour == nil })
	l.Position = UDim2.fromOffset(10, y)
	l.Size = UDim2.new(1, -160, 0, 0)
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
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame
	local rarity = StationRules.rarity(a)
	local t = StationRules.bestStat(a)
	local function stat(s: string): number
		return StationRules.stat(a, s :: any)
	end
	local role = ROLE_NAME[StationRules.role(a)] or "?"
	text(frame, `{nameOf(a)}  -  {rarity}  -  {role}`, 20, 6, RARITY_COLOUR[rarity] or Color3.new(1, 1, 1))
	text(frame, `SPD {stat("speed")}   STR {stat("strength")}   STA {stat("stamina")}   MANA {stat("mana")}`, 16, 36)
	local station = a.at and StationConfig.station(a.at)
	local inTeam = table.find(profile.team, a.id) ~= nil or profile.titan == a.id
	text(frame, if inTeam then "In your team" elseif station then `Training at {station.name}` else "Resting", 16, 62)
	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -8, 0.5, 0)
	buttons.Size = UDim2.fromOffset(140, 92)
	buttons.Parent = frame
	local bl = Instance.new("UIListLayout")
	bl.Padding = UDim.new(0, 4)
	bl.Parent = buttons
	if a.at then
		Ui.button(buttons, "Stop training", function()
			send("stop", a.id)
		end, { danger = true })
	else
		Ui.button(buttons, if inTeam then "Leave team" else "Join team", function()
			send("team", a.id)
		end)
		local st = stationFor(t)
		Ui.button(buttons, `Train {string.upper(st.stat)}`, function()
			send("train", a.id, st.id)
		end)
	end
	frame.Parent = list
end

local function refresh()
	if profile == nil then
		return
	end
	coins.Text = `Coins: {profile.coins}`
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	title.Text = `Your animals ({#profile.animals})  -  team {#profile.team}/3  -  Titan {if profile.titan
		then "ready"
		else "none"}`
	if #profile.animals == 0 then
		local hint = Instance.new("Frame")
		hint.BackgroundTransparency = 1
		hint.Size = UDim2.new(1, -12, 0, 60)
		Ui.label(hint, "No animals yet. Buy an egg at the market stalls in the plaza!", { muted = true })
		hint.Parent = list
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
		Ui.toast(screen, `You hatched a {nameOf(payload)}! ({StationRules.rarity(payload)})`, 4)
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
