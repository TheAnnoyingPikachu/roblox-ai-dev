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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WaveRuns = require(Shared:WaitForChild("WaveRuns"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationGoals = require(Shared:WaitForChild("StationGoals"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local UiLayout = require(Shared:WaitForChild("UiLayout"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

-- The HUD is this script and the Hud* modules beside it (STATION-135). What they share is on App; what
-- they share and also change is on App.S, read and written as S.name everywhere, so no part holds a
-- stale copy.
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S

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
	trade_closed = "Trading opens later in the beta",
	trade_ask_wait = "Give them a few seconds before asking again",
	trade_saving = "Trading needs saving on for both of you",
	trade_store = "Trading couldn't save just now: try again",
	locked = "Reach a higher level to unlock that egg",
	in_team = "Take it off your team first",
	animal_locked = "Unlock it first",
	last_animal = "You can't release your last animal",
	fuse_mismatch = "Fusing takes four of the same animal and coat",
	fuse_top = "Prismatic is the top coat",
	fuse_count = "Fusing takes four of the same animal",
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

local player = game:GetService("Players").LocalPlayer
local screen = Ui.screen("StationsHud")
S.profile = nil
local tickers: { () -> () } = {} -- refresh the live text of every stat being trained
local eggTickers: { () -> () } = {} -- and of every egg hatching
-- Helpers called from one place each are fields of this table, not locals of their own (STATION-134): the
-- main chunk may hold 200 locals at once (Luau's limit), and every local a later function uses takes one
-- of them to the end. A new helper that one screen calls belongs here, or inside a `do` block.
local Hud = {}

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
	return StationRules.train(a, a.at, StationProgress.trainedBetween(S.profile, a.since, Workspace:GetServerTimeNow()))
end

-- Two lines for a stat button: the stat's level out of 70, then its battle value ("SPD 7/70"
-- over "46"), with the time left to the next level while training ("46  12m"), or MAX.
function Hud.statText(a: any, stat: string, training: boolean): string
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
			/ StationProgress.value(S.profile, "grounds")
		return `{head}\n{value}   {Format.ago(left)}`
	end
	return `{head}\n{value}`
end

-- The sheets and the bottom bar ---------------------------------------------------------------------

local sheets: { [string]: Style.Sheet } = {}
local redraw: { [string]: () -> () } = {}
S.openName = nil
local nav = Instance.new("Frame") -- the side dock, hidden while a sheet is open

local function show(name: string?)
	if name and name ~= S.openName and sheets[name] then
		Style.pop(sheets[name])
	end
	S.openName = name
	for n, sh in sheets do
		sh.backdrop.Visible = n == name
	end
	nav.Visible = name == nil and not S.fighting
	if name and redraw[name] and S.profile then
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
S.ranchTab = "animals" -- the group of upgrades the Ranch menu shows
for _, sh in sheets do
	Style.list(sh.body, 10, true, true)
end

-- The player, top left (decision 0114): the level in its XP ring, then the coins and the samples, each in a
-- paper pill of its own.
local top = Instance.new("Frame")
top.Name = "Player"
top.BackgroundTransparency = 1
top.Position, top.Size = UDim2.fromOffset(14, 12), UDim2.fromOffset(440, 60)
Style.list(top, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
top.Parent = root
local levelPill = Style.pill(top, UDim2.fromOffset(204, 60), 30)
local xpRing, setXp = Style.pie(levelPill, 50, C.info, C.cardHi)
xpRing.Position = UDim2.fromOffset(5, 5)
local badge = Style.frame(xpRing, UDim2.fromOffset(38, 38), C.accent)
badge.AnchorPoint, badge.Position, badge.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 2
Style.round(badge, 19)
Style.stroke(badge, C.ink, 3)
local badgeText = Style.text(badge, "1", 19, C.accentText, UDim2.fromScale(1, 1))
badgeText.TextXAlignment, badgeText.ZIndex = Enum.TextXAlignment.Center, 3
local levelText = Style.text(levelPill, "Level 1", 18, C.text, UDim2.new(1, -78, 0, 20))
levelText.Position = UDim2.fromOffset(64, 10)
local xpText = Style.small(levelPill, "", 13, C.muted, UDim2.new(1, -78, 0, 16))
xpText.Position = UDim2.fromOffset(64, 32)
local function purse(kind: string, width: number): TextLabel
	local pill = Style.pill(top, UDim2.fromOffset(width, 40), 20)
	local row, text = Style.amount(pill, kind, "0")
	row.Position = UDim2.fromOffset(10, 7)
	return text
end
local coinsText = purse("coins", 112)
local samplesText = purse("samples", 92)

-- Everything that makes way for an open menu and for a fight: the dock, the goal, To battle, what is waiting.
nav.Name = "Nav"
nav.BackgroundTransparency = 1
nav.Size = UDim2.fromScale(1, 1)
nav.Parent = root

-- The dock (decision 0114): what is done most is always up on the left edge, each button a picture, a word
-- and its key. No menu to open first.
local dock = Instance.new("Frame")
dock.Name = "Dock"
dock.BackgroundTransparency = 1
dock.Position, dock.Size = UDim2.fromOffset(16, 96), UDim2.fromOffset(84, 480)
Style.list(dock, 12)
dock.Parent = nav
local hotkeys: { [Enum.KeyCode]: { sheet: string?, run: () -> () } } = {}
local function dockButton(
	label: string,
	icon: string,
	key: Enum.KeyCode,
	onClick: () -> (),
	sheet: string?
): (TextLabel, TextButton)
	local b = Style.button(dock, label, onClick, "ghost", UDim2.fromOffset(84, 68))
	b.LayoutOrder, b.TextSize, b.TextYAlignment = #dock:GetChildren() - 1, 15, Enum.TextYAlignment.Bottom
	local inset = (b:FindFirstChild("Label") :: TextLabel):FindFirstChild("Inset") :: UIPadding
	inset.PaddingBottom = UDim.new(0, 5)
	local art = Style.icon(b, icon, 38)
	art.AnchorPoint, art.Position, art.ZIndex = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 4), 2
	local cap = Style.key(b, tostring(b.LayoutOrder))
	cap.AnchorPoint, cap.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(4, 4)
	hotkeys[key] = { sheet = sheet, run = onClick }
	local dot = Style.dot(b, "")
	dot.Visible = false
	return dot, b
end

S.hideResult = function() end -- set once the fight panel exists

-- Travel: a pop-out beside its button with the hub, your ranch and the wave arena (no teleport pads)
local travel = Style.panel(nav, UDim2.fromOffset(196, 214))
travel.AnchorPoint, travel.Position, travel.Visible = Vector2.new(0, 1), UDim2.fromOffset(114, 488), false
local places = Instance.new("Frame")
places.BackgroundTransparency = 1
places.Position, places.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -24, 1, -20)
Style.list(places, 10)
places.Parent = travel
Style.text(places, "Go to…", 20, C.text, UDim2.new(1, 0, 0, 26))
function Hud.travelTo(action: string, ...: any)
	travel.Visible = false
	local ok, code = request:InvokeServer(action, ...)
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
	else
		show(nil)
		S.hideResult()
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
		Hud.travelTo(p[3], p[4])
	end, p[2], UDim2.new(1, 0, 0, 44))
	b.LayoutOrder = k + 1
end

dockButton("Animals", "paw", Enum.KeyCode.One, function()
	show("animals")
end, "animals")
local eggsDot = dockButton("Eggs", "egg", Enum.KeyCode.Two, function()
	show("eggs")
end, "eggs")
dockButton("Ranch", "home", Enum.KeyCode.Three, function()
	show("ranch")
end, "ranch")
local giftsDot, giftsButton = dockButton("Gifts", "gift", Enum.KeyCode.Four, function()
	request:InvokeServer("rewards") -- count today first
	show("gifts")
end, "gifts")
giftsButton.BackgroundColor3 = Color3.fromRGB(255, 233, 168)
local _, travelButton = dockButton("Travel", "flag", Enum.KeyCode.Five, function()
	travel.Visible = not travel.Visible
end)
travelButton.BackgroundColor3 = Color3.fromRGB(207, 232, 251)
local tradeDot, tradeButton = dockButton("Trade", "swap", Enum.KeyCode.Six, function()
	show("trade")
end, "trade")
if not StationTrade.ON then -- off until trading is hardened (SHANNON, 2026-11-24)
	tradeButton.Visible, hotkeys[Enum.KeyCode.Six] = false, nil
end
nav:GetPropertyChangedSignal("Visible"):Connect(function()
	travel.Visible = false
end)

-- To battle (key B): the biggest button on the screen says which wave is next.
do
	local battle = Style.button(nav, "", function()
		S.openWaves()
	end, "good", UDim2.fromOffset(296, 72))
	battle.Name = "ToBattle"
	battle.AnchorPoint, battle.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -20)
	Style.radius(battle, 20)
	local crest = Instance.new("ImageLabel") -- the shield with a paw (assets/stations/icons/shield.png)
	crest.BackgroundTransparency, crest.Image = 1, "rbxassetid://97488070836179"
	crest.Position, crest.Size, crest.ZIndex = UDim2.fromOffset(14, 12), UDim2.fromOffset(48, 48), 2
	crest.Parent = battle
	local battleTitle = Style.text(battle, "To battle", 28, Color3.fromRGB(35, 52, 15), UDim2.fromOffset(170, 30))
	battleTitle.Position, battleTitle.ZIndex = UDim2.fromOffset(72, 9), 2
	local battleSub = Style.small(battle, "", 13, Color3.fromRGB(35, 52, 15), UDim2.fromOffset(180, 16))
	battleSub.Position, battleSub.ZIndex = UDim2.fromOffset(72, 43), 2
	local battleKey = Style.key(battle, "B")
	battleKey.AnchorPoint, battleKey.Position = Vector2.new(1, 0.5), UDim2.new(1, -16, 0.5, 0)
	hotkeys[Enum.KeyCode.B] = {
		sheet = "waves",
		run = function()
			S.openWaves()
		end,
	}
	function Hud.nextWave(text: string)
		battleSub.Text = text
	end
end

-- A key from the dock opens its menu, closes it again, or goes straight from one menu to another.
UserInputService.InputBegan:Connect(function(input, typing)
	local hot = hotkeys[input.KeyCode]
	if typing or hot == nil or S.fighting then
		return
	elseif hot.sheet and S.openName == hot.sheet then
		Style.sound("close")
		show(nil)
	elseif S.openName == nil or hot.sheet then
		Style.sound("tab")
		hot.run()
	end
end)

-- The goal (decision 0115): the next thing to do and what it pays, always at the top.
do
	local goal = Style.pill(nav, UDim2.fromOffset(456, 58), 16)
	goal.Name = "Goal"
	goal.AnchorPoint, goal.Position, goal.Visible = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), false
	Style.icon(goal, "flag", 34).Position = UDim2.fromOffset(12, 12)
	local goalText = Style.text(goal, "", 17, C.text, UDim2.new(1, -212, 0, 20))
	goalText.Position, goalText.TextWrapped, goalText.TextTruncate =
		UDim2.fromOffset(54, 8), false, Enum.TextTruncate.AtEnd
	local goalBar, setGoal = Style.bar(goal, UDim2.fromOffset(140, 10), C.good)
	goalBar.Position = UDim2.fromOffset(54, 35)
	local goalCount = Style.small(goal, "", 12, C.muted, UDim2.fromOffset(104, 14))
	goalCount.Position = UDim2.fromOffset(202, 33)
	local goalPays = Style.frame(goal, UDim2.fromOffset(144, 42), C.cardHi)
	goalPays.AnchorPoint, goalPays.Position = Vector2.new(1, 0.5), UDim2.new(1, -8, 0.5, 0)
	Style.round(goalPays, 12)
	local goalPaysIcon = Instance.new("ImageLabel")
	goalPaysIcon.BackgroundTransparency = 1
	goalPaysIcon.Position, goalPaysIcon.Size = UDim2.fromOffset(5, 5), UDim2.fromOffset(32, 32)
	goalPaysIcon.Parent = goalPays
	local goalPaysText = Style.text(goalPays, "", 14, C.text, UDim2.new(1, -46, 1, 0))
	goalPaysText.Position = UDim2.fromOffset(42, 0)
	-- `text` nil hides the strip (every goal is done).
	function Hud.showGoal(text: string?, f: number?, count: string?, pays: string?, icon: string?)
		goal.Visible = text ~= nil
		goalText.Text, goalCount.Text = text or "", count or ""
		goalPaysText.Text, goalPaysIcon.Image = pays or "", icon or ""
		setGoal(f or 0)
	end
end

-- What is hatching and training, beside the dock, with the time left: the soonest three.
do
	local waiting = Style.pill(nav, UDim2.fromOffset(256, 46), 16)
	waiting.Name = "Waiting"
	waiting.AnchorPoint, waiting.Position, waiting.Visible = Vector2.new(0, 1), UDim2.new(0, 114, 1, -22), false
	local waitRows: { { row: Frame, art: ImageLabel, name: TextLabel, left: TextLabel, fill: Frame } } = {}
	for k = 1, 3 do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position, row.Size = UDim2.fromOffset(10, 8 + (k - 1) * 38), UDim2.new(1, -20, 0, 30)
		row.Parent = waiting
		local art = Style.icon(row, "egg", 30)
		local name = Style.text(row, "", 14, C.text, UDim2.new(1, -100, 0, 16))
		name.Position, name.TextWrapped, name.TextTruncate = UDim2.fromOffset(38, 0), false, Enum.TextTruncate.AtEnd
		local left = Style.small(row, "", 13, C.text, UDim2.fromOffset(62, 16))
		left.AnchorPoint, left.Position, left.TextXAlignment =
			Vector2.new(1, 0), UDim2.fromScale(1, 0), Enum.TextXAlignment.Right
		local bar = Style.frame(row, UDim2.new(1, -38, 0, 8), C.cardHi)
		bar.Position = UDim2.fromOffset(38, 21)
		Style.round(bar, 4)
		local fill = Style.frame(bar, UDim2.fromScale(0, 1), C.accent)
		Style.round(fill, 4)
		waitRows[k] = { row = row, art = art, name = name, left = left, fill = fill }
	end
	-- Called once a second and whenever the save changes.
	function Hud.waiting()
		local p, now = S.profile, Workspace:GetServerTimeNow()
		local rows: { { icon: string, name: string, left: number, f: number, colour: Color3 } } = {}
		for _, e in p.eggs do
			local def = e.since and StationConfig.egg(e.egg)
			if def then
				local due = StationProgress.dueAt(p, e) :: number
				table.insert(rows, {
					icon = "egg",
					name = def.name,
					left = math.max(0, due - now),
					f = (now - e.since) / math.max(1, due - e.since),
					colour = C.accent,
				})
			end
		end
		for _, a in p.animals do
			local station = a.at and a.since and StationConfig.station(a.at)
			local cur = if station then live(a) else a
			local level = if station then StationRules.level(cur, station.stat) else StationConfig.MAX_LEVEL
			if station and level < StationConfig.MAX_LEVEL then
				local f = if cur.trained then cur.trained[station.stat] - level else 0
				table.insert(rows, {
					icon = "paw",
					name = `{nameOf(a)} · {STAT_SHORT[station.stat]} {level + 1}`,
					left = (1 - f) * StationRules.levelSeconds(level + 1) * 100 / StationProgress.value(p, "grounds"),
					f = f,
					colour = C.info,
				})
			end
		end
		table.sort(rows, function(x, y)
			return x.left < y.left
		end)
		for k, w in waitRows do
			local r = rows[k]
			w.row.Visible = r ~= nil
			if r then
				w.art.Image = Style.image(r.icon)
				w.name.Text, w.left.Text = r.name, if r.left <= 0 then "Ready!" else Format.ago(r.left)
				w.fill.Size, w.fill.BackgroundColor3 = UDim2.fromScale(math.clamp(r.f, 0, 1), 1), r.colour
			end
		end
		waiting.Visible = #rows > 0
		waiting.Size = UDim2.fromOffset(256, 12 + math.min(#rows, 3) * 38)
	end
end

-- Top right: who else is here, with a way to bring a friend; under it a note when an egg is ready to open.
do
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.AnchorPoint, side.Position, side.Size = Vector2.new(1, 0), UDim2.new(1, -14, 0, 12), UDim2.fromOffset(300, 140)
	local sideList = Style.list(side, 12)
	sideList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	side.Parent = nav
	local mates = Style.pill(side, UDim2.fromOffset(120, 44), 22)
	mates.Name = "Mates"
	local faces = Instance.new("Frame")
	faces.BackgroundTransparency = 1
	faces.Position, faces.Size = UDim2.fromOffset(8, 6), UDim2.new(1, -16, 0, 32)
	local faceList = Style.list(faces, 6, true)
	faceList.VerticalAlignment, faceList.HorizontalAlignment =
		Enum.VerticalAlignment.Center, Enum.HorizontalAlignment.Right
	faces.Parent = mates
	local matesText = Style.small(faces, "Play together", 13, C.text, UDim2.fromOffset(92, 16))
	matesText.LayoutOrder = 0
	local invite = Style.button(faces, "+ Invite", function()
		local SocialService = game:GetService("SocialService")
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			Style.toast(screen, "Invites are not open here: share the game's link instead")
		end
	end, "good", UDim2.fromOffset(88, 30))
	invite.TextSize, invite.LayoutOrder = 15, 99
	local function showMates()
		for _, f in faces:GetChildren() do
			if f:IsA("ImageLabel") then
				f:Destroy()
			end
		end
		local others = 0
		for _, other in game:GetService("Players"):GetPlayers() do
			if other ~= player then
				others += 1
				local face = Instance.new("ImageLabel")
				face.Size, face.BackgroundColor3, face.LayoutOrder = UDim2.fromOffset(32, 32), C.info, others
				face.Image = `rbxthumb://type=AvatarHeadShot&id={other.UserId}&w=48&h=48`
				Style.round(face, 16)
				Style.stroke(face, C.ink, 2)
				face.Parent = faces
			end
		end
		matesText.Text = if others > 0 then "Ranch mates" else "Play together"
		mates.Size = UDim2.fromOffset(202 + others * 38, 44)
	end
	game:GetService("Players").PlayerAdded:Connect(showMates)
	game:GetService("Players").PlayerRemoving:Connect(function()
		task.defer(showMates)
	end)
	showMates()
	local eggNote = Style.pill(side, UDim2.fromOffset(300, 62), 16)
	eggNote.Name, eggNote.Visible, eggNote.LayoutOrder = "EggReady", false, 2
	Style.icon(eggNote, "egg", 44).Position = UDim2.fromOffset(9, 9)
	local eggNoteText = Style.text(eggNote, "", 16, C.text, UDim2.new(1, -140, 0, 20))
	eggNoteText.Position, eggNoteText.TextWrapped, eggNoteText.TextTruncate =
		UDim2.fromOffset(60, 11), false, Enum.TextTruncate.AtEnd
	Style.small(eggNote, "At your hatchery", 13, C.muted, UDim2.new(1, -140, 0, 16)).Position = UDim2.fromOffset(60, 33)
	local eggNoteAt = 0
	local eggGo = Style.button(eggNote, "Go", function()
		Hud.wayTo(eggNoteAt)
	end, "primary", UDim2.fromOffset(64, 40))
	eggGo.AnchorPoint, eggGo.Position = Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, -2)
	-- The note for hatching egg `k` (nil: none is ready).
	function Hud.eggReady(k: number?, name: string?)
		eggNote.Visible, eggNoteAt = k ~= nil, k or 0
		eggNoteText.Text = `Your {name or "egg"} is ready`
	end
end

-- Admin button, bottom left: only for players the server marks as admin (decision 0038)
local adminToggle = Style.button(root, "Admin", function()
	show(if S.openName == "admin" then nil else "admin")
end, "ghost", UDim2.fromOffset(84, 40))
adminToggle.AnchorPoint, adminToggle.Position = Vector2.new(0, 1), UDim2.new(0, 16, 1, -22)
adminToggle.TextSize = 16

-- What the parts below need from this script. They are loaded in the order they were written: each
-- takes what it needs from App as locals of its own and adds what it makes.
App.C = C
App.RARITY_COLOUR = RARITY_COLOUR
App.RANK = RANK
App.ROLE_NAME = ROLE_NAME
App.GROUP_NAME = GROUP_NAME
App.STAT_SHORT = STAT_SHORT
App.RAINBOW = RAINBOW
App.REFUSED = REFUSED
App.screen = screen
App.tickers = tickers
App.eggTickers = eggTickers
App.Hud = Hud
App.root = root
App.uiScale = uiScale
App.send = send
App.nameOf = nameOf
App.live = live
App.sheets = sheets
App.redraw = redraw
App.nav = nav
App.show = show
App.animals = animals
App.eggs = eggs
App.ranch = ranch
App.shop = shop
App.waves = waves
App.admin = admin
App.trade = trade
App.gifts = gifts
App.coinsText = coinsText
App.tradeDot = tradeDot
App.adminToggle = adminToggle

for _, part in
	{ "HudAnimals", "HudRanch", "HudShop", "HudGifts", "HudTrade", "HudWaves", "HudFight", "HudHover", "HudHatch" }
do
	require(script.Parent:WaitForChild(part))
end

local rewardWords = App.rewardWords
local iconsOf = App.iconsOf
local giftsReady = App.giftsReady
local result = App.result
local resultTitle = App.resultTitle
local resultSub = App.resultSub
local drops = App.drops
local boonRow = App.boonRow
local showRarity = App.showRarity
local began = App.began
local again = App.again
local leave = App.leave
local showStars = App.showStars
local coinBurst = App.coinBurst
local offerBoons = App.offerBoons
local buttons = App.buttons
local hatchEffect = App.hatchEffect

-- Refreshing ------------------------------------------------------------------------------------------

local function refresh()
	if S.profile == nil then
		return
	end
	local level = StationProgress.playerLevel(S.profile)
	local from, to = StationProgress.xpFor(level), StationProgress.xpFor(level + 1)
	badgeText.Text = tostring(level)
	levelText.Text = `Level {level}`
	xpText.Text = `{Format.short(S.profile.xp - from)} / {Format.short(to - from)} XP`
	setXp((S.profile.xp - from) / math.max(1, to - from))
	coinsText.Text = Format.short(S.profile.coins)
	samplesText.Text = Format.short(S.profile.samples)
	local best = S.profile.best
	Hud.nextWave(
		if best == 0
			then "Wave 1 · your first fight"
			else `Wave {math.min(best + 1, LevelRules.LAST)} · your best is {best}`
	)
	local goal = StationGoals.next(S.profile)
	if goal then
		local done, of = StationGoals.progress(S.profile, goal)
		local items = StationGoals.items(S.profile, goal)
		Hud.showGoal(goal.text, done / of, StationGoals.label(S.profile, goal), rewardWords(items), (iconsOf(items)))
	else
		Hud.showGoal(nil)
	end
	Hud.waiting()
	if S.openName and redraw[S.openName] then
		redraw[S.openName]()
	end
end

-- The prompts in the world: the Ranch House door, the egg storage and a finished egg (the owner
-- only), the wave gate and the vendors' stalls.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, who)
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
		S.openWaves()
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
		if S.profile then -- the Eggs button's dot: eggs ready to open at the hatchery
			local ready, now = 0, Workspace:GetServerTimeNow()
			local first: number?, firstName: string? = nil, nil
			for k, e in S.profile.eggs do
				local def = e.since and StationConfig.egg(e.egg)
				if def and now >= (StationProgress.dueAt(S.profile, e) :: number) then
					ready += 1
					first, firstName = first or k, firstName or def.name
				end
			end
			eggsDot.Text, eggsDot.Visible = tostring(ready), ready > 0
			Hud.eggReady(first, firstName)
			Hud.waiting()
			local week, month, spin = giftsReady()
			giftsDot.Text, giftsDot.Visible = "!", week or month or spin
		end
		if S.openName == "animals" then
			for _, tick in tickers do
				tick()
			end
		elseif S.openName == "eggs" then
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
			if S.profile and prompt:GetAttribute("Ranch") == player:GetAttribute("Ranch") then
				local held = StationProgress.held(S.profile, Workspace:GetServerTimeNow())
				local full = held >= StationProgress.value(S.profile, "windmill") * StationProgress.MILL_HOURS
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
		local first = S.profile == nil
		S.profile = payload
		if first then
			task.spawn(request.InvokeServer, request, "rewards") -- today counts for the planners
		end
		refresh()
	elseif kind == "announce" then -- another player's rare hatch (SHANNON, 2026-11-24)
		Style.toast(screen, `{payload.who} hatched {payload.what}!`, 5, "good")
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
		if S.profile and #S.profile.animals <= 1 then -- the first hatch: day 1's gifts open after it (SHANNON, 2026-11-24)
			task.delay(4, function()
				request:InvokeServer("rewards")
				show("gifts")
			end)
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
		S.music(if payload.won then "win" else "lose")
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
			S.wave = math.min(payload.wave + 1, LevelRules.LAST)
			again.Text = if payload.last then `Fight wave {S.wave} again` else `Fight wave {S.wave}`
			if payload.offer then -- pick a boon: it starts the next wave
				offerBoons(payload.offer, S.wave)
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
			S.wave = payload.wave
			again.Text = `Try wave {S.wave} again`
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
		S.hideResult()
		S.music(nil)
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
		S.invite = { from = payload.from, name = payload.name, at = os.clock() }
		Style.toast(screen, `{payload.name} wants to trade: open Trade`, 5)
		tradeDot.Text, tradeDot.Visible = "!", true
		if S.openName == "trade" then
			redraw.trade()
		end
	elseif kind == "trade" then
		if payload.closed then
			S.tradeState = nil
			S.tradePeek = nil
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
			local opening = S.tradeState == nil
			payload.at = os.clock()
			S.tradeState = payload
			if opening and S.openName ~= "trade" then
				show("trade")
				return
			end
		end
		if S.openName == "trade" then
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
	elseif kind == "goal" then -- a goal reached and paid (decision 0115)
		Style.sound("claim")
		Style.toast(
			screen,
			`Goal done: {payload.text}. You got {rewardWords(payload.items)}`,
			5,
			"good",
			(iconsOf(payload.items))
		)
	elseif kind == "reward" then
		Style.sound("claim")
		Style.toast(screen, `You got: {rewardWords(payload.items)}`, 4, "good", (iconsOf(payload.items)))
	elseif kind == "spun" then
		Hud.landWheel(payload)
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
		if u and S.profile then
			Style.toast(screen, `{u.name} upgraded: {StationProgress.value(S.profile, u.id)} {u.gives}`, 4)
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
