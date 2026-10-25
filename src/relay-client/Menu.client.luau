--!strict
-- Relay Rounds menus (decision 0006): start menu with a camera orbit, HUD (level, XP, coins),
-- Locker (trails), Rewards (daily streak, weekly bonus, daily quests), Stats, Settings, toasts
-- and music. The client only asks; the server validates every request in Profiles.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ProgressRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressRules"))
local request = ReplicatedStorage:WaitForChild("RelayRemotes"):WaitForChild("Request") :: RemoteFunction
local status = ReplicatedStorage:WaitForChild("RelayStatus") :: StringValue

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera

-- Style -----------------------------------------------------------------------------------------

local INK = Color3.fromRGB(18, 14, 24)
local PANEL = Color3.fromRGB(32, 24, 40)
local RED = Color3.fromRGB(220, 40, 50)
local GOLD = Color3.fromRGB(255, 200, 70)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 160, 185)
local GREEN = Color3.fromRGB(80, 220, 120)

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(colour: Color3, thickness: number): UIStroke
	return new("UIStroke", { Color = colour, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.AutoButtonColor = true
	props.BackgroundColor3 = props.BackgroundColor3 or RED
	local b = new(
		"TextButton",
		props,
		{ corner(10), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) }
	)
	b.Activated:Connect(onClick)
	return b
end

-- Profile ---------------------------------------------------------------------------------------

local profile: ProgressRules.Profile = ProgressRules.defaults()
local onProfile = Instance.new("BindableEvent")

local function readProfile()
	local raw = player:GetAttribute("Profile")
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			profile = ProgressRules.sanitize(decoded)
			onProfile:Fire()
		end
	end
end
player:GetAttributeChangedSignal("Profile"):Connect(readProfile)

local function today(): number
	return ProgressRules.dayOf(Workspace:GetServerTimeNow())
end

local function ask(action: string, arg: string?): boolean
	local ok, result = pcall(request.InvokeServer, request, action, arg)
	return ok and result == true
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Root GUI --------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "RelayMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Toasts stack at the top right.
local toasts = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 70),
	Size = UDim2.fromOffset(300, 300),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

local function toast(message: string, colour: Color3?)
	local t = text({
		Size = UDim2.fromOffset(300, 40),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = PANEL,
		Text = message,
		TextColor3 = colour or WHITE,
		Parent = toasts,
	})
	corner(8).Parent = t
	local outline = stroke(colour or GOLD, 2)
	outline.Parent = t
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = t })
	task.delay(4, function()
		TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		TweenService:Create(outline, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.45, t.Destroy, t)
	end)
end

-- HUD: level badge, XP bar, coins, quick buttons -------------------------------------------------

local hud = new("Frame", {
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.fromOffset(240, 128),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke(RED, 2) })
local levelBadge = text({
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.fromOffset(60, 44),
	BackgroundTransparency = 0,
	BackgroundColor3 = RED,
	Font = Enum.Font.GothamBlack,
	Text = "1",
	Parent = hud,
})
corner(10).Parent = levelBadge
local levelCaption = text({
	Position = UDim2.fromOffset(80, 8),
	Size = UDim2.fromOffset(150, 18),
	Text = "LEVEL 1",
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = hud,
})
local xpBack = new(
	"Frame",
	{ Position = UDim2.fromOffset(80, 30), Size = UDim2.fromOffset(150, 10), BackgroundColor3 = INK, Parent = hud },
	{ corner(5) }
)
local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, Parent = xpBack }, { corner(5) })
local xpText = text({
	Position = UDim2.fromOffset(80, 42),
	Size = UDim2.fromOffset(150, 14),
	Text = "0 / 40 XP",
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = hud,
})
local coinText = text({
	Position = UDim2.fromOffset(10, 58),
	Size = UDim2.fromOffset(220, 24),
	Text = "0 coins",
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBlack,
	Parent = hud,
})

local panels: { [string]: Frame } = {}
local menuOpen = true
local openPanel: (string) -> ()
local showMenu: () -> ()

local quick = new(
	"Frame",
	{ Position = UDim2.fromOffset(10, 88), Size = UDim2.fromOffset(220, 32), BackgroundTransparency = 1, Parent = hud },
	{
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	}
)
local rewardsDot: Frame
for _, item in { { "Menu", "MENU" }, { "Locker", "LOCKER" }, { "Rewards", "REWARDS" } } do
	local b = button({
		Size = UDim2.fromOffset(69, 32),
		Text = item[2],
		BackgroundColor3 = if item[1] == "Menu" then INK else RED,
		Parent = quick,
	}, function()
		if item[1] == "Menu" then
			showMenu()
		else
			openPanel(item[1])
		end
	end)
	if item[1] == "Rewards" then
		rewardsDot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = GOLD,
			Visible = false,
			Parent = b,
		}, { corner(6) })
	end
end

local function rewardsReady(): boolean
	local day = today()
	if ProgressRules.nextDaily(profile, day) ~= nil or ProgressRules.canClaimWeekly(profile, day) then
		return true
	end
	if profile.quests.day ~= day then
		return false
	end
	for _, q in ProgressRules.questsFor(day) do
		if not profile.quests.claimed[q.id] and (profile.quests.progress[q.stat] or 0) >= q.goal then
			return true
		end
	end
	return false
end

local lastLevel: number? = nil
local function refreshHud()
	local level = ProgressRules.levelFor(profile.xp)
	local from, to = ProgressRules.xpForLevel(level), ProgressRules.xpForLevel(level + 1)
	levelBadge.Text = tostring(level)
	levelCaption.Text = `LEVEL {level}`
	xpFill.Size = UDim2.fromScale(if level >= ProgressRules.MAX_LEVEL then 1 else (profile.xp - from) / (to - from), 1)
	xpText.Text = if level >= ProgressRules.MAX_LEVEL
		then "MAX LEVEL"
		else `{commas(profile.xp - from)} / {commas(to - from)} XP`
	coinText.Text = `{commas(profile.coins)} coins`
	rewardsDot.Visible = rewardsReady()
	if lastLevel and level > lastLevel then
		toast(`LEVEL UP!  Level {level}`, GOLD)
		for _, t in ProgressRules.TRAILS do
			if t.level == level then
				toast(`Unlocked trail: {t.name}`, GREEN)
			end
		end
	end
	lastLevel = level
end

player:GetAttributeChangedSignal("LastReward"):Connect(function()
	local reward = player:GetAttribute("LastReward")
	if type(reward) == "string" then
		toast(reward, GOLD)
	end
end)

-- Panels ----------------------------------------------------------------------------------------

local panelHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.62, 0.7),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, {
	corner(16),
	stroke(RED, 3),
	new("UISizeConstraint", { MaxSize = Vector2.new(860, 620), MinSize = Vector2.new(320, 360) }),
})
local panelTitle = text({
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -90, 0, 40),
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = panelHolder,
})
button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(44, 40),
	Text = "X",
	BackgroundColor3 = INK,
	Parent = panelHolder,
}, function()
	panelHolder.Visible = false
end)

local function panel(name: string): Frame
	local f = new("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = panelHolder,
	}, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panels[name] = f
	return f
end

local function row(parent: Instance, height: number, order: number): Frame
	return new("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(10) })
end

local renderers: { [string]: () -> () } = {}

-- Locker: every trail with a colour preview and its state.
local locker = panel("Locker")
renderers.Locker = function()
	for _, c in locker:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, t in ProgressRules.TRAILS do
		local r = row(locker, 56, i)
		local swatch = new("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(120, 36),
			BackgroundColor3 = WHITE,
			Parent = r,
		}, { corner(8) })
		local stops = {}
		if #t.colours == 0 then
			table.insert(
				stops,
				ColorSequenceKeypoint.new(0, if player.Team then player.Team.TeamColor.Color else WHITE)
			)
			table.insert(
				stops,
				ColorSequenceKeypoint.new(1, if player.Team then player.Team.TeamColor.Color else WHITE)
			)
		else
			for j, rgb in t.colours do
				table.insert(
					stops,
					ColorSequenceKeypoint.new(
						if #t.colours == 1 then 0 else (j - 1) / (#t.colours - 1),
						Color3.fromRGB(rgb[1], rgb[2], rgb[3])
					)
				)
			end
			if #stops == 1 then
				table.insert(stops, ColorSequenceKeypoint.new(1, stops[1].Value))
			end
		end
		new("UIGradient", { Color = ColorSequence.new(stops), Parent = swatch })
		text({
			Position = UDim2.fromOffset(142, 8),
			Size = UDim2.new(1, -300, 0, 22),
			Text = t.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local how = if t.price
			then `Shop: {commas(t.price)} coins`
			elseif t.wins then `Unlocks at {t.wins} wins`
			else `Unlocks at level {t.level}`
		text({
			Position = UDim2.fromOffset(142, 30),
			Size = UDim2.new(1, -300, 0, 16),
			Text = how,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local unlocked = ProgressRules.isUnlocked(profile, t.id)
		local label, colour, action = "LOCKED", INK, nil :: string?
		if profile.trail == t.id then
			label, colour = "EQUIPPED", GREEN
		elseif unlocked then
			label, colour, action = "EQUIP", RED, "equipTrail"
		elseif t.price then
			label, colour, action = `BUY {commas(t.price)}`, if profile.coins >= t.price then GOLD else INK, "buyTrail"
		end
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 38),
			Text = label,
			BackgroundColor3 = colour,
			TextColor3 = if colour == GOLD then INK else WHITE,
			Parent = r,
		}, function()
			if action == nil then
				return
			end
			if ask(action, t.id) then
				toast(if action == "buyTrail" then `Bought {t.name}!` else `Equipped {t.name}`, GREEN)
				if action == "buyTrail" then
					ask("equipTrail", t.id)
				end
			elseif action == "buyTrail" then
				toast("Not enough coins yet", RED)
			end
		end)
		b.AutoButtonColor = action ~= nil
	end
end

-- Rewards: 7-day streak, weekly bonus, today's quests.
local rewards = panel("Rewards")
renderers.Rewards = function()
	for _, c in rewards:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local day = today()
	local nextStreak = ProgressRules.nextDaily(profile, day)
	local currentStreak = if nextStreak then nextStreak - 1 else profile.daily.streak
	text({
		Size = UDim2.new(1, -8, 0, 26),
		Text = "DAILY LOGIN STREAK",
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = 1,
		Parent = rewards,
	})
	local strip = new(
		"Frame",
		{ Size = UDim2.new(1, -8, 0, 86), BackgroundTransparency = 1, LayoutOrder = 2, Parent = rewards },
		{
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
		}
	)
	for d = 1, 7 do
		local shownStreak = math.min(currentStreak, 7)
		local claimed = d <= shownStreak
		local isNext = nextStreak ~= nil and d == math.min(nextStreak, 7)
		local cell = new("Frame", {
			Size = UDim2.new(1 / 7, -6, 1, 0),
			BackgroundColor3 = if claimed then GREEN elseif isNext then GOLD else INK,
			Parent = strip,
		}, { corner(10) })
		text({
			Size = UDim2.fromScale(1, 0.4),
			Text = `DAY {d}`,
			TextColor3 = if isNext then INK else WHITE,
			Parent = cell,
		})
		text({
			Position = UDim2.fromScale(0, 0.45),
			Size = UDim2.fromScale(1, 0.45),
			Text = `{ProgressRules.DAILY[d]}`,
			TextColor3 = if isNext then INK else GOLD,
			Font = Enum.Font.GothamBlack,
			Parent = cell,
		})
	end
	local dailyRow = row(rewards, 50, 3)
	text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -200, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if nextStreak
			then `Day {nextStreak} reward is ready: {ProgressRules.dailyReward(nextStreak)} coins`
			else "Come back tomorrow to keep your streak!",
		Parent = dailyRow,
	})
	button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(160, 36),
		Text = if nextStreak then "CLAIM" else "CLAIMED",
		BackgroundColor3 = if nextStreak then GOLD else INK,
		TextColor3 = if nextStreak then INK else MUTED,
		Parent = dailyRow,
	}, function()
		if nextStreak and ask("claimDaily") then
			toast(`+{ProgressRules.dailyReward(nextStreak)} coins: day {nextStreak} streak!`, GOLD)
		end
	end)

	text({
		Size = UDim2.new(1, -8, 0, 26),
		Text = "WEEKLY BONUS",
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = 4,
		Parent = rewards,
	})
	local weekRow = row(rewards, 50, 5)
	local days = if profile.week.key == ProgressRules.weekOf(day) then profile.week.days else 0
	local canWeekly = ProgressRules.canClaimWeekly(profile, day)
	text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -200, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if profile.week.claimed and days > 0
			then "Weekly bonus claimed. New week starts Monday!"
			else `Play on {ProgressRules.WEEKLY.days} days this week: {math.min(days, ProgressRules.WEEKLY.days)}/{ProgressRules.WEEKLY.days} for {ProgressRules.WEEKLY.reward} coins`,
		Parent = weekRow,
	})
	button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(160, 36),
		Text = if canWeekly then "CLAIM" else `{math.min(days, ProgressRules.WEEKLY.days)}/{ProgressRules.WEEKLY.days}`,
		BackgroundColor3 = if canWeekly then GOLD else INK,
		TextColor3 = if canWeekly then INK else MUTED,
		Parent = weekRow,
	}, function()
		if canWeekly and ask("claimWeekly") then
			toast(`+{ProgressRules.WEEKLY.reward} coins: weekly bonus!`, GOLD)
		end
	end)

	text({
		Size = UDim2.new(1, -8, 0, 26),
		Text = "TODAY'S QUESTS",
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = 6,
		Parent = rewards,
	})
	for i, q in ProgressRules.questsFor(day) do
		local progress = if profile.quests.day == day then profile.quests.progress[q.stat] or 0 else 0
		local claimed = profile.quests.day == day and profile.quests.claimed[q.id] == true
		local done = progress >= q.goal
		local r = row(rewards, 58, 6 + i)
		text({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -200, 0, 22),
			Text = q.label,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local back = new("Frame", {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -200, 0, 12),
			BackgroundColor3 = PANEL,
			Parent = r,
		}, { corner(6) })
		new("Frame", {
			Size = UDim2.fromScale(math.clamp(progress / q.goal, 0, 1), 1),
			BackgroundColor3 = if done then GREEN else GOLD,
			Parent = back,
		}, { corner(6) })
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(160, 36),
			Text = if claimed
				then "DONE"
				elseif done then `CLAIM {q.reward}`
				else `{math.min(progress, q.goal)}/{q.goal}`,
			BackgroundColor3 = if claimed then INK elseif done then GOLD else INK,
			TextColor3 = if done and not claimed then INK else MUTED,
			Parent = r,
		}, function()
			if done and not claimed and ask("claimQuest", q.id) then
				toast(`Quest complete: +{q.reward} coins`, GOLD)
			end
		end)
	end
end

-- Stats.
local stats = panel("Stats")
renderers.Stats = function()
	for _, c in stats:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local level = ProgressRules.levelFor(profile.xp)
	local winRate = if profile.races > 0 then math.floor(profile.wins / profile.races * 100) else 0
	for i, item in
		{
			{ "Level", tostring(level) },
			{ "Total XP", commas(profile.xp) },
			{ "Coins", commas(profile.coins) },
			{ "Matches played", commas(profile.races) },
			{ "Wins", commas(profile.wins) },
			{ "Win rate", `{winRate}%` },
			{ "Legs run", commas(profile.legs) },
			{ "Login streak", `{profile.daily.streak} days` },
			{
				"Trails owned",
				tostring((function()
					local n = 0
					for _, t in ProgressRules.TRAILS do
						if ProgressRules.isUnlocked(profile, t.id) then
							n += 1
						end
					end
					return n
				end)()) .. ` / {#ProgressRules.TRAILS}`,
			},
		}
	do
		local r = row(stats, 40, i)
		text({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.6, -12, 0, 28),
			Text = item[1],
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		text({
			Position = UDim2.new(0.6, 0, 0, 6),
			Size = UDim2.new(0.4, -12, 0, 28),
			Text = item[2],
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
	end
	if not player:GetAttribute("ProfileOnline") then
		local r = row(stats, 40, 99)
		text({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 28),
			Text = "Saving is offline on this server: progress lasts this session only.",
			TextColor3 = GOLD,
			Parent = r,
		})
	end
end

-- Settings.
local settings = { music = true, sfx = true }
local applyMusic: () -> ()
local setting = panel("Settings")
renderers.Settings = function()
	for _, c in setting:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, item in { { "music", "Music" }, { "sfx", "Sound effects" } } do
		local r = row(setting, 50, i)
		text({
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -200, 0, 30),
			Text = item[2],
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local on = (settings :: any)[item[1]]
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(120, 36),
			Text = if on then "ON" else "OFF",
			BackgroundColor3 = if on then GREEN else INK,
			Parent = r,
		}, function()
			(settings :: any)[item[1]] = not on
			applyMusic()
			renderers.Settings()
		end)
	end
	local r = row(setting, 120, 3)
	text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 1, -16),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "HOW TO PLAY\nRace your team's legs around the circuit. Run into your team's box to pass the baton. Last team each round is out.\nJump twice to double jump. Q / Shift to air dash. Ride the cyan boost pads. Avoid lava and lasers.",
		Parent = r,
	})
end

openPanel = function(name: string)
	for key, f in panels do
		f.Visible = key == name
	end
	panelTitle.Text = string.upper(name)
	-- Beside the start menu's buttons when it is open, centred otherwise.
	panelHolder.Position = if menuOpen then UDim2.fromScale(0.64, 0.52) else UDim2.fromScale(0.5, 0.52)
	panelHolder.Visible = true
	renderers[name]()
end

onProfile.Event:Connect(function()
	refreshHud()
	if panelHolder.Visible then
		for name, f in panels do
			if f.Visible and name ~= "Settings" then
				renderers[name]()
			end
		end
	end
end)

-- Start menu ------------------------------------------------------------------------------------

local menu = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
new("Frame", {
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
	Parent = menu,
}, { new("UIGradient", { Transparency = NumberSequence.new(0.05, 1) }) })
local column = new("Frame", {
	Position = UDim2.fromScale(0.06, 0.12),
	Size = UDim2.fromScale(0.34, 0.8),
	BackgroundTransparency = 1,
	Parent = menu,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 700) }),
})
local title = text({
	Size = UDim2.new(1, 0, 0, 96),
	Text = "RELAY ROUNDS",
	Font = Enum.Font.GothamBlack,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = column,
})
new("UIStroke", { Color = RED, Thickness = 4, Parent = title })
text({
	Size = UDim2.new(1, 0, 0, 28),
	Text = "ANIME RELAY GRAND PRIX",
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = column,
})
new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 3, Parent = column })

local hideMenu: () -> ()
local menuDot: Frame
for i, item in
	{
		{ "PLAY", "Play" },
		{ "LOCKER", "Locker" },
		{ "REWARDS", "Rewards" },
		{ "STATS", "Stats" },
		{ "SETTINGS", "Settings" },
	}
do
	local b = button({
		Size = UDim2.new(1, 0, 0, if i == 1 then 70 else 52),
		Text = item[1],
		BackgroundColor3 = if i == 1 then RED else PANEL,
		LayoutOrder = 3 + i,
		Parent = column,
	}, function()
		if item[2] == "Play" then
			hideMenu()
		else
			openPanel(item[2])
		end
	end)
	stroke(if i == 1 then GOLD else RED, 2).Parent = b
	if item[2] == "Rewards" then
		menuDot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -16, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = GOLD,
			Visible = false,
			Parent = b,
		}, { corner(8) })
	end
end
local menuInfo = text({
	Size = UDim2.new(1, 0, 0, 22),
	Text = "",
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 20,
	Parent = column,
})
onProfile.Event:Connect(function()
	menuDot.Visible = rewardsReady()
	menuInfo.Text =
		`Level {ProgressRules.levelFor(profile.xp)}  ·  {commas(profile.coins)} coins  ·  {commas(profile.wins)} wins`
end)

-- Slow orbit over the circuit behind the menu.
local orbitStart = os.clock()
local orbit = RunService.RenderStepped:Connect(function()
	if not menuOpen then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local t = (os.clock() - orbitStart) * 0.05
	local centre = Vector3.new(70, 0, 0)
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(math.cos(t) * 260, 110, math.sin(t) * 260), centre)
end)

hideMenu = function()
	menuOpen = false
	menu.Visible = false
	panelHolder.Visible = false
	hud.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if rewardsReady() then
		toast("Rewards are ready! Open REWARDS to claim.", GOLD)
	end
end

showMenu = function()
	menuOpen = true
	orbitStart = os.clock()
	menu.Visible = true
	hud.Visible = false
	panelHolder.Visible = false
end

-- A match starting pulls you out of the menu so you never miss your leg.
status:GetPropertyChangedSignal("Value"):Connect(function()
	if menuOpen and player.Team ~= nil and string.find(status.Value, "Get ready") then
		hideMenu()
	end
end)

-- Music -----------------------------------------------------------------------------------------

-- Licensed tracks (docs/assets/register.md): one lobby track, a three-track race playlist.
local LOBBY_TRACKS = { "rbxassetid://87416512611152" }
local RACE_TRACKS = { "rbxassetid://9040647656", "rbxassetid://1845705763", "rbxassetid://1848171351" }
local music = new("Sound", { Name = "RelayMusic", Volume = 0, Looped = false, Parent = SoundService })
local mode = ""
local trackIndex = 0

local function racing(): boolean
	local s = status.Value
	return string.find(s, "s left") ~= nil or string.find(s, "Get ready") ~= nil
end

local function playNext()
	local list = if mode == "race" then RACE_TRACKS else LOBBY_TRACKS
	trackIndex = trackIndex % #list + 1
	music.SoundId = list[trackIndex]
	music.TimePosition = 0
	music:Play()
	TweenService:Create(music, TweenInfo.new(1.5), { Volume = if settings.music then 0.35 else 0 }):Play()
end
music.Ended:Connect(playNext)

applyMusic = function()
	local wanted = if racing() then "race" else "lobby"
	if wanted ~= mode then
		mode = wanted
		trackIndex = if mode == "race" then math.random(0, #RACE_TRACKS - 1) else 0
		local fade = TweenService:Create(music, TweenInfo.new(0.8), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(playNext)
	else
		music.Volume = if settings.music then 0.35 else 0
	end
	for _, s in SoundService:GetChildren() do
		if s:IsA("Sound") and s ~= music then
			if s:GetAttribute("BaseVolume") == nil then
				s:SetAttribute("BaseVolume", s.Volume)
			end
			s.Volume = if settings.sfx then s:GetAttribute("BaseVolume") :: number else 0
		end
	end
end
status:GetPropertyChangedSignal("Value"):Connect(applyMusic)

-- Boot ------------------------------------------------------------------------------------------

gui.Parent = player:WaitForChild("PlayerGui")
readProfile()
refreshHud()
applyMusic()
local _ = orbit
