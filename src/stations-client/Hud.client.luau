--!strict
-- Animal Stations HUD (decisions 0025, 0029, 0036): coins and player level, hatch and refusal
-- toasts, the Animals panel, and two plain lists opened in the world: the ranch menu (at the Ranch
-- House door: upgrades and eggs) and the egg vendor's (at a ranch's egg stall). Each animal shows its role and group, a team button, and one button per
-- stat with the stat's value and level: tap a stat to train it there, tap it again to stop.
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
}

local screen = Ui.screen("StationsHud")
local profile: any = nil
local tickers: { () -> () } = {} -- refresh the live text of every stat being trained

-- Coins and player level, top left
local coinBox = Ui.panel(screen, { size = UDim2.fromOffset(220, 100), name = "Coins" })
coinBox.Position = UDim2.fromOffset(12, 12)
local coins = Ui.label(coinBox, "Coins: ...", { size = 24 })
local samples = Ui.label(coinBox, "Samples: ...", { size = 16 })
local levelText = Ui.label(coinBox, "Level ...", { size = 16, muted = true })

-- Animals button and panel
local toggle = Ui.panel(screen, { size = UDim2.fromOffset(220, 64), name = "AnimalsButton" })
toggle.Position = UDim2.fromOffset(12, 120)
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
	coins.Text = `Coins: {Format.commas(profile.coins)}`
	samples.Text = `Samples: {Format.commas(profile.samples)}`
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
		Ui.label(empty, "No animals yet. Buy an egg from the egg vendor on your ranch!", { muted = true })
		empty.Parent = list
	end
	for i, a in profile.animals do
		row(a, i)
	end
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

local function showCard(model: Model?)
	local s = model and model:GetAttribute("Species")
	local sp = if type(s) == "string" then StationConfig.species(s) else nil
	if model == nil or sp == nil then
		card.Visible = false
		return
	end
	local v = model:GetAttribute("Variant")
	local va = if type(v) == "string" then StationConfig.variant(sp.id, v) else nil
	local rarity = if va then va.tier else sp.rarity
	local colour = RARITY_COLOUR[rarity] or Color3.new(1, 1, 1)
	cardName.Text = if va then va.name else sp.name
	cardName.TextColor3 = colour
	cardEdge.Color = colour
	cardKind.Text = `{string.upper(rarity)}  -  {ROLE_NAME[sp.role] or "?"}  -  {GROUP_NAME[sp.group] or "?"}`
	cardKind.TextColor3 = colour
	local parts = {}
	for k, stat in StationConfig.STATS do
		table.insert(parts, `{STAT_SHORT[stat]} {model:GetAttribute(stat) or "?"}{if k == 3 then "\n" else "   "}`)
	end
	cardStats.Text = table.concat(parts)
	local health = model:GetAttribute("health")
	local max = BattleRules.HP_BASE
		+ math.floor((if type(health) == "number" then health else 0) * BattleRules.HP_PER_HEALTH)
	local hp = model:GetAttribute("Hp") -- set once fights exist; full until then
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

-- An egg of these colours standing on `at` rocks harder and harder, then bursts: a flash, sparks
-- and bits of shell. Takes HATCH seconds; the server brings the animal out of the nest after it.
local HATCH = 1.4
local function hatchEffect(at: Vector3, body: Color3, spot: Color3)
	local h = 3
	local shell = Instance.new("Part")
	shell.Anchored, shell.CanCollide, shell.CanQuery = true, false, false
	shell.Size, shell.Color, shell.Material = Vector3.new(h * 0.75, h, h * 0.75), body, Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = spot, 10, 0.5, false
	light.Parent = shell
	shell.Parent = Workspace
	local foot = CFrame.new(at)
	local started = os.clock()
	while os.clock() - started < HATCH do -- rock about the foot, faster and wider
		local t = (os.clock() - started) / HATCH
		local lean = math.sin(t * t * 60) * math.rad(4 + 22 * t)
		shell.CFrame = foot * CFrame.Angles(0, 0, lean) * CFrame.new(0, h / 2 + math.abs(lean) * 0.6, 0)
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

-- Ranch menu and egg vendor ------------------------------------------------------------------------

-- A plain list in the middle of the screen with a heading and a Close button.
local function sheet(name: string, heading: string): (Frame, ScrollingFrame)
	local frame = Ui.panel(screen, { size = UDim2.fromOffset(470, 500), anchor = "center", name = name })
	frame.Visible = false
	Ui.label(frame, heading, { size = 24 }).LayoutOrder = 1
	local rows = Instance.new("ScrollingFrame")
	rows.LayoutOrder = 2
	rows.Size = UDim2.new(1, 0, 1, -96)
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = 8
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.CanvasSize = UDim2.new()
	rows.Parent = frame
	local order = Instance.new("UIListLayout")
	order.Padding = UDim.new(0, 6)
	order.SortOrder = Enum.SortOrder.LayoutOrder
	order.Parent = rows
	Ui.button(frame, "Close", function()
		frame.Visible = false
	end, { danger = true }).LayoutOrder = 3
	return frame, rows
end

local menu, menuRows = sheet("RanchMenu", "Your ranch")
local shop, shopRows = sheet("EggShop", "Egg vendor")
local store, storeRows = sheet("EggStorage", "Egg storage")

local function only(frame: Frame) -- one list at a time
	menu.Visible, shop.Visible, store.Visible = frame == menu, frame == shop, frame == store
end

-- Admin menu (decision 0038): only for players the server marks as admin (the game's owner, or
-- anyone in Studio). Stands animal models in front of you to look at; nothing is saved.
local admin, adminRows = sheet("Admin", "Admin: look at the animals")
local adminToggle = Ui.panel(screen, { size = UDim2.fromOffset(220, 64), name = "AdminButton" })
adminToggle.Position = UDim2.fromOffset(12, 192)
Ui.button(adminToggle, "Admin", function()
	admin.Visible = not admin.Visible
end)
do
	local n = 0
	local function add(text: string, action: string, value: any?)
		n += 1
		Ui.button(adminRows, text, function()
			send(action, value)
		end).LayoutOrder = n
	end
	add("Spawn every animal in a row", "look", 0)
	add("Clear them", "look_clear")
	for _, anim in { "idle", "walk", "attack", "magic" } do
		add(`All play: {anim}`, "look_anim", anim)
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
end
local function showAdmin()
	adminToggle.Visible = Players.LocalPlayer:GetAttribute("Admin") == true
	admin.Visible = admin.Visible and adminToggle.Visible
end
Players.LocalPlayer:GetAttributeChangedSignal("Admin"):Connect(showAdmin)
showAdmin()
local eggLines: { { label: TextLabel, egg: any } } = {} -- the menu's egg lines, for their countdowns

local function clear(rows: Instance)
	for _, child in rows:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function eggText(e: any): string
	local egg = StationConfig.egg(e.egg) :: StationConfig.Egg
	if e.since == nil then
		return `{egg.name}: in the egg storage`
	end
	local left = e.since + egg.hatch - Workspace:GetServerTimeNow()
	return if left > 0 then `{egg.name}: opens in {Format.ago(left)}` else `{egg.name}: ready! Open it at the hatchery`
end

-- The ranch menu: each upgrade with what it gives and a button for its next level, then the eggs.
local function drawMenu()
	if profile == nil then
		return
	end
	clear(menuRows)
	eggLines = {}
	local n = 0
	local function place(thing: GuiObject)
		n += 1
		thing.LayoutOrder = n
	end
	for _, u in StationConfig.UPGRADES do
		local level = profile.upgrades[u.id] or 0
		place(
			Ui.label(
				menuRows,
				`{u.name}, level {level} of {#u.levels}: {StationProgress.value(profile, u.id)} {u.gives}`
			)
		)
		local cost = u.levels[level + 1]
		if cost then
			local price = `{Format.commas(cost.coins)} coins`
			if cost.samples > 0 then
				price ..= ` + {cost.samples} samples`
			end
			place(Ui.button(menuRows, `Upgrade to {cost.value} for {price}`, function()
				send("upgrade", u.id)
			end))
		end
	end
	local hatching = 0
	for _, e in profile.eggs do
		hatching += if e.since then 1 else 0
	end
	place(
		Ui.label(
			menuRows,
			`Eggs: {hatching} of {StationProgress.MAX_EGGS} hatching, {#profile.eggs - hatching} in the egg storage`,
			{ size = 20 }
		)
	)
	for k, e in profile.eggs do
		if k <= 12 then
			local entry = Ui.label(menuRows, eggText(e), { size = 16, muted = e.since == nil })
			place(entry)
			table.insert(eggLines, { label = entry, egg = e })
		end
	end
	if RunService:IsStudio() then -- coins and samples cannot be earned in play yet
		place(Ui.button(menuRows, "Test funds (Studio only)", function()
			send("funds")
		end))
	end
end

-- The egg vendor's list: every egg with its price and hatch time.
local function drawShop()
	if profile == nil then
		return
	end
	clear(shopRows)
	local level = StationProgress.playerLevel(profile)
	local note = Ui.label(
		shopRows,
		"Eggs go to your egg storage. Choose one there to hatch (six at a time), then open it when it is done.",
		{ size = 14, muted = true }
	)
	note.LayoutOrder = 0
	for k, egg in StationConfig.EGGS do
		local needs = if egg.unlock and level < egg.unlock then `  (from level {egg.unlock})` else ""
		local inside = {}
		for _, o in egg.odds do
			table.insert(inside, (StationConfig.species(o.id) :: StationConfig.Species).name)
		end
		local entry =
			`{egg.name}: {Format.commas(egg.price)} coins, opens in {Format.ago(egg.hatch)}{needs}\nHatches: {table.concat(
				inside,
				", "
			)}`
		Ui.label(shopRows, entry).LayoutOrder = k * 2
		Ui.button(shopRows, `Buy {egg.name}`, function()
			send("buy", egg.id)
		end).LayoutOrder = k * 2 + 1
	end
end

-- The egg storage's list: every stored egg with a button to start hatching it.
local function drawStore()
	if profile == nil then
		return
	end
	clear(storeRows)
	local hatching, stored = 0, 0
	for k, e in profile.eggs do
		if e.since then
			hatching += 1
		else
			stored += 1
			local egg = StationConfig.egg(e.egg) :: StationConfig.Egg
			Ui.button(storeRows, `Hatch {egg.name} (takes {Format.ago(egg.hatch)})`, function()
				send("hatch", k)
			end).LayoutOrder =
				k
		end
	end
	local head = if stored == 0
		then "No eggs in storage. Buy some from the egg vendor."
		else `{hatching} of {StationProgress.MAX_EGGS} hatching places are in use. Choose an egg to hatch:`
	Ui.label(storeRows, head, { size = 16, muted = true }).LayoutOrder = 0
end

-- The prompts in the world: the Ranch House door, the egg storage and a finished egg (the owner
-- only), and the vendors' stalls.
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= Players.LocalPlayer then
		return
	end
	local mine = prompt:GetAttribute("Ranch") == who:GetAttribute("Ranch")
	local owners = CollectionService:HasTag(prompt, "RanchMenu")
		or CollectionService:HasTag(prompt, "EggStorage")
		or CollectionService:HasTag(prompt, "Egg")
	if owners and not mine then
		Ui.toast(screen, "This is not your ranch")
	elseif CollectionService:HasTag(prompt, "RanchMenu") then
		drawMenu()
		only(menu)
	elseif CollectionService:HasTag(prompt, "EggStorage") then
		drawStore()
		only(store)
	elseif CollectionService:HasTag(prompt, "Egg") then
		send("open", prompt:GetAttribute("Index"))
	elseif CollectionService:HasTag(prompt, "Vendor") then
		if prompt:GetAttribute("Kind") == "eggs" then
			drawShop()
			only(shop)
		else
			Ui.toast(screen, "The gear vendor is still unpacking. Gear is coming soon!")
		end
	end
end)

task.spawn(function() -- once a second: the menu's countdowns, and a finished egg can be opened
	while true do
		task.wait(1)
		if menu.Visible then
			for _, entry in eggLines do
				entry.label.Text = eggText(entry.egg)
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
		if menu.Visible then
			drawMenu()
		end
		if shop.Visible then
			drawShop()
		end
		if store.Visible then
			drawStore()
		end
	elseif kind == "hatched" then
		local lucky = ""
		for _, stat in StationConfig.STATS do
			if StationRules.level(payload, stat) >= StationConfig.MAX_LEVEL then
				lucky = `  JACKPOT: {STAT_SHORT[stat]} is already level {StationConfig.MAX_LEVEL}!`
			end
		end
		if payload.at then
			hatchEffect(payload.at, payload.body, payload.spot) -- then the animal steps out
		end
		Ui.toast(screen, `You hatched a {nameOf(payload)}! ({StationRules.rarity(payload)}){lucky}`, 4)
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
