--!strict
-- Hundred Demon Night menus (GDD H2-H6, decision 0007), forked from Relay's Menu: start menu
-- over a camera orbit of the shrine, PLAY panel (moon tier, weapon, invite, START / JOIN NIGHT),
-- Locker (Blade Arts, Masks, Weapons), Rewards (daily streak, weekly bonus, daily quests),
-- Stats, Settings (written to ClientState), toasts, the level / XP / souls bar and music.
-- The client only asks; the server validates every Request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local NightProgress = require(Shared:WaitForChild("NightProgress"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local request = ReplicatedStorage:WaitForChild("NightRemotes"):WaitForChild("Request") :: RemoteFunction

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera
local CONFIG = NightProgress.CONFIG

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

local profile: NightProgress.Profile = NightProgress.defaults()
local onProfile = Instance.new("BindableEvent")

local function readProfile()
	local decoded = ClientState.json(player:GetAttribute("Profile"))
	if decoded ~= nil then
		profile = NightProgress.sanitize(decoded)
		onProfile:Fire()
	end
end
player:GetAttributeChangedSignal("Profile"):Connect(readProfile)

local function today(): number
	return MetaRules.dayOf(Workspace:GetServerTimeNow())
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

local function inRun(): boolean
	return ClientState.isParticipant() and ClientState.status().state ~= "Idle"
end

-- Root GUI --------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "NightMenu",
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
ClientState.autoScale(toasts)

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

-- HUD: level badge, XP bar, souls, quick buttons -------------------------------------------------

local hud = new("Frame", {
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.fromOffset(240, 128),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke(RED, 2) })
ClientState.autoScale(hud)
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
	Text = "0 souls",
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBlack,
	Parent = hud,
})

local panels: { [string]: Frame } = {}
local menuOpen = true
local openPanel: (string) -> ()
local showMenu: () -> ()
local hideMenu: () -> ()

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
	if MetaRules.nextDaily(profile, day) ~= nil or MetaRules.canClaimWeekly(CONFIG, profile, day) then
		return true
	end
	if profile.quests.day ~= day then
		return false
	end
	for _, q in NightProgress.questsFor(day) do
		if not profile.quests.claimed[q.id] and (profile.quests.progress[q.stat] or 0) >= q.goal then
			return true
		end
	end
	return false
end

local lastLevel: number? = nil
local function refreshHud()
	local level = NightProgress.levelFor(profile.xp)
	local from, to = MetaRules.xpForLevel(level), MetaRules.xpForLevel(level + 1)
	levelBadge.Text = tostring(level)
	levelCaption.Text = `LEVEL {level}`
	xpFill.Size = UDim2.fromScale(if level >= MetaRules.MAX_LEVEL then 1 else (profile.xp - from) / (to - from), 1)
	xpText.Text = if level >= MetaRules.MAX_LEVEL
		then "MAX LEVEL"
		else `{commas(profile.xp - from)} / {commas(to - from)} XP`
	coinText.Text = `{commas(profile.coins)} souls`
	rewardsDot.Visible = rewardsReady()
	if lastLevel and level > lastLevel then
		toast(`LEVEL UP!  Level {level}`, GOLD)
		for _, c in NightProgress.COSMETICS do
			if c.level == level and c.price == nil and c.wins == nil and c.tier == nil then
				toast(`Unlocked {if c.slot == "mask" then "mask" else "Blade Art"}: {c.name}`, GREEN)
			end
		end
		for _, w in CombatRules.WEAPONS do
			if w.level == level then
				toast(`Unlocked weapon: {w.name}`, GREEN)
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
	Size = UDim2.fromScale(0.62, 0.74),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, {
	corner(16),
	stroke(RED, 3),
	new("UISizeConstraint", { MaxSize = Vector2.new(860, 620), MinSize = Vector2.new(300, 280) }),
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(48, 30, 58), Color3.fromRGB(26, 18, 32)),
	}),
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

local function heading(parent: Instance, label: string, order: number)
	text({
		Size = UDim2.new(1, -8, 0, 26),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- A gradient swatch of a cosmetic's colour stops.
local function swatch(parent: Instance, colours: { { number } })
	local s = new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = WHITE,
		Parent = parent,
	}, { corner(8) })
	local stops = {}
	for j, c in colours do
		table.insert(
			stops,
			ColorSequenceKeypoint.new(
				if #colours == 1 then 0 else (j - 1) / (#colours - 1),
				Color3.fromRGB(c[1], c[2], c[3])
			)
		)
	end
	if #stops == 0 then
		s.BackgroundColor3 = INK
		text({ Size = UDim2.fromScale(1, 1), Text = "NONE", TextColor3 = MUTED, Parent = s })
		return
	end
	if #stops == 1 then
		table.insert(stops, ColorSequenceKeypoint.new(1, stops[1].Value))
	end
	new("UIGradient", { Color = ColorSequence.new(stops), Parent = s })
end

local function itemButton(parent: Instance, label: string, colour: Color3, active: boolean, onClick: () -> ())
	local b = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 38),
		Text = label,
		BackgroundColor3 = colour,
		TextColor3 = if colour == GOLD then INK else WHITE,
		Parent = parent,
	}, onClick)
	b.AutoButtonColor = active
end

local renderers: { [string]: () -> () } = {}

-- Weapons: shared by the PLAY panel and the Locker.
local function weaponRows(parent: Instance, firstOrder: number)
	for i, w in CombatRules.WEAPONS do
		local r = row(parent, 56, firstOrder + i)
		local total = 0
		for _, d in w.damage do
			total += d
		end
		text({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -180, 0, 24),
			Text = string.upper(w.name),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		text({
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -180, 0, 16),
			Text = `{#w.damage}-hit combo  ·  {total} damage  ·  reach {w.range}  ·  arc {w.arc}`,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local unlocked = NightProgress.weaponUnlocked(profile, w.id)
		if profile.weapon == w.id then
			itemButton(r, "EQUIPPED", GREEN, false, function() end)
		elseif not unlocked then
			itemButton(r, `LEVEL {w.level}`, INK, false, function() end)
		else
			itemButton(r, "EQUIP", RED, true, function()
				if inRun() then
					toast("Leave the night to change weapons", RED)
				elseif ask("equipWeapon", w.id) then
					toast(`Equipped {w.name}`, GREEN)
				end
			end)
		end
	end
end

-- PLAY: moon tier, weapon, invite, START / JOIN NIGHT.
local MOON_COLOURS = {
	Color3.fromRGB(255, 240, 200),
	Color3.fromRGB(255, 240, 200),
	Color3.fromRGB(255, 245, 215),
	Color3.fromRGB(230, 40, 50),
	Color3.fromRGB(20, 12, 24),
}
local function moon(parent: Instance, tier: number, locked: boolean)
	local disc = new("Frame", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = if locked then Color3.fromRGB(70, 65, 80) else MOON_COLOURS[tier],
		ClipsDescendants = false,
		Parent = parent,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	if tier == 5 then
		stroke(GOLD, 2).Parent = disc
	end
	-- Crescent and half moons: a night-coloured disc slid over the lit one.
	local cover = if tier == 1 then 0.35 elseif tier == 2 then 0.55 else nil
	if cover then
		new("Frame", {
			Position = UDim2.fromScale(cover, -0.05),
			Size = UDim2.fromScale(1.05, 1.1),
			BackgroundColor3 = INK,
			Parent = disc,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
end

local play = panel("Play")
renderers.Play = function()
	clear(play)
	local s = ClientState.status()
	local running = s.state ~= "Idle"
	local full = #s.ids >= 6 and not ClientState.isParticipant()
	local start = row(play, 74, 1)
	start.BackgroundTransparency = 1
	button({
		Size = UDim2.fromScale(1, 1),
		Text = if full
			then "NIGHT FULL"
			elseif running then `JOIN NIGHT  ·  WAVE {math.max(s.wave, 1)}`
			else "START NIGHT",
		BackgroundColor3 = if full then INK else RED,
		Parent = start,
	}, function()
		if full then
			return
		end
		if ask("play") then
			ClientState.sound(ClientState.SFX.gong, 0.6)
			hideMenu()
		else
			toast("Could not join the night. Try again.", RED)
		end
	end)
	stroke(GOLD, 3).Parent = start:FindFirstChildOfClass("TextButton") :: TextButton

	heading(play, "MOON", 2)
	local maxTier = NightProgress.maxTier(profile)
	local picked = NightProgress.tierFor(profile)
	for t, name in NightProgress.TIERS do
		local r = row(play, 58, 2 + t)
		local locked = t > maxTier
		moon(r, t, locked)
		text({
			Position = UDim2.fromOffset(64, 6),
			Size = UDim2.new(1, -220, 0, 24),
			Text = `{string.upper(name)} MOON`,
			Font = Enum.Font.GothamBlack,
			TextColor3 = if locked then MUTED else WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		text({
			Position = UDim2.fromOffset(64, 32),
			Size = UDim2.new(1, -220, 0, 16),
			Text = if locked
				then `Win a {NightProgress.TIERS[t - 1]} Moon night to unlock`
				else `Yokai +{35 * (t - 1)}% HP  ·  rewards x{1 + 0.5 * (t - 1)}`,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		if t == picked then
			itemButton(r, "SELECTED", GREEN, false, function() end)
		elseif locked then
			itemButton(r, "LOCKED", INK, false, function() end)
		else
			itemButton(r, "SELECT", RED, true, function()
				if ask("setTier", tostring(t)) then
					toast(if running then `{name} Moon set for your next night` else `{name} Moon selected`, GREEN)
				end
			end)
		end
	end

	heading(play, "WEAPON", 10)
	weaponRows(play, 10)

	local invite = row(play, 50, 20)
	text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -200, 0, 34),
		Text = "Better together: party bonus and revives",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = invite,
	})
	itemButton(invite, "INVITE FRIENDS", GOLD, true, function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			toast("Invites are not available here", RED)
		end
	end)
end

-- Locker: Blade Arts, Masks and Weapons tabs.
local locker = panel("Locker")
local lockerTab = "blade"
local function unlockText(c: MetaRules.Cosmetic): string
	if c.price then
		return `Shop: {commas(c.price)} souls`
	elseif c.tier then
		return `Win a {NightProgress.TIERS[c.tier] or "Eclipse"} Moon night`
	elseif c.wins then
		return `Win {c.wins} nights`
	elseif c.level and c.level > 1 then
		return `Unlocks at level {c.level}`
	end
	return "Default"
end

renderers.Locker = function()
	clear(locker)
	local tabs = new(
		"Frame",
		{ Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, Parent = locker },
		{
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
		}
	)
	for _, tab in { { "blade", "BLADE ARTS" }, { "mask", "MASKS" }, { "weapon", "WEAPONS" } } do
		button({
			Size = UDim2.new(1 / 3, -6, 1, 0),
			Text = tab[2],
			BackgroundColor3 = if lockerTab == tab[1] then RED else INK,
			Parent = tabs,
		}, function()
			lockerTab = tab[1]
			renderers.Locker()
		end)
	end
	if lockerTab == "weapon" then
		weaponRows(locker, 0)
		return
	end
	local i = 0
	for _, c in NightProgress.COSMETICS do
		if c.slot == lockerTab then
			i += 1
			local r = row(locker, 56, i)
			swatch(r, c.colours)
			text({
				Position = UDim2.fromOffset(142, 8),
				Size = UDim2.new(1, -300, 0, 22),
				Text = c.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			text({
				Position = UDim2.fromOffset(142, 30),
				Size = UDim2.new(1, -300, 0, 16),
				Text = unlockText(c),
				TextColor3 = MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			local unlocked = NightProgress.isUnlocked(profile, c.id)
			local equipped = (profile :: any)[c.slot] == c.id
			if equipped then
				itemButton(r, "EQUIPPED", GREEN, false, function() end)
			elseif unlocked then
				itemButton(r, "EQUIP", RED, true, function()
					if ask("equipCosmetic", c.id) then
						toast(`Equipped {c.name}`, GREEN)
					end
				end)
			elseif c.price then
				local price = c.price :: number
				itemButton(r, `BUY {commas(price)}`, if profile.coins >= price then GOLD else INK, true, function()
					if ask("buyCosmetic", c.id) then
						toast(`Bought {c.name}!`, GREEN)
						task.wait(0.4) -- outlast the server's 0.35 s request cooldown (QA m6)
						ask("equipCosmetic", c.id)
					else
						toast("Not enough souls yet", RED)
					end
				end)
			else
				itemButton(r, "LOCKED", INK, false, function() end)
			end
		end
	end
end

-- Rewards: 7-day streak, weekly bonus, today's quests.
local rewards = panel("Rewards")
renderers.Rewards = function()
	clear(rewards)
	local day = today()
	local nextStreak = MetaRules.nextDaily(profile, day)
	local currentStreak = if nextStreak then nextStreak - 1 else profile.daily.streak
	heading(rewards, "DAILY LOGIN STREAK", 1)
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
			Text = `{CONFIG.daily[d]}`,
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
			then `Day {nextStreak} reward is ready: {MetaRules.dailyReward(CONFIG, nextStreak)} souls`
			else "Come back tomorrow to keep your streak!",
		Parent = dailyRow,
	})
	itemButton(
		dailyRow,
		if nextStreak then "CLAIM" else "CLAIMED",
		if nextStreak then GOLD else INK,
		nextStreak ~= nil,
		function()
			if nextStreak and ask("claimDaily") then
				toast(`+{MetaRules.dailyReward(CONFIG, nextStreak)} souls: day {nextStreak} streak!`, GOLD)
			end
		end
	)

	heading(rewards, "WEEKLY BONUS", 4)
	local weekRow = row(rewards, 50, 5)
	local days = if profile.week.key == MetaRules.weekOf(day) then profile.week.days else 0
	local canWeekly = MetaRules.canClaimWeekly(CONFIG, profile, day)
	local goal = CONFIG.weekly.days
	text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -200, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if profile.week.claimed and days > 0
			then "Weekly bonus claimed. New week starts Monday!"
			else `Play on {goal} days this week: {math.min(days, goal)}/{goal} for {CONFIG.weekly.reward} souls`,
		Parent = weekRow,
	})
	itemButton(
		weekRow,
		if canWeekly then "CLAIM" else `{math.min(days, goal)}/{goal}`,
		if canWeekly then GOLD else INK,
		canWeekly,
		function()
			if canWeekly and ask("claimWeekly") then
				toast(`+{CONFIG.weekly.reward} souls: weekly bonus!`, GOLD)
			end
		end
	)

	heading(rewards, "TODAY'S QUESTS", 6)
	for i, q in NightProgress.questsFor(day) do
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
		itemButton(
			r,
			if claimed then "DONE" elseif done then `CLAIM {q.reward}` else `{math.min(progress, q.goal)}/{q.goal}`,
			if done and not claimed then GOLD else INK,
			done and not claimed,
			function()
				if done and not claimed and ask("claimQuest", q.id) then
					toast(`Quest complete: +{q.reward} souls`, GOLD)
				end
			end
		)
	end
end

-- Stats.
local stats = panel("Stats")
renderers.Stats = function()
	clear(stats)
	local function owned(slot: string): string
		local n, total = 0, 0
		for _, c in NightProgress.COSMETICS do
			if c.slot == slot then
				total += 1
				if NightProgress.isUnlocked(profile, c.id) then
					n += 1
				end
			end
		end
		return `{n} / {total}`
	end
	for i, item in
		{
			{ "Level", tostring(NightProgress.levelFor(profile.xp)) },
			{ "Total XP", commas(profile.xp) },
			{ "Souls", commas(profile.coins) },
			{ "Nights won", commas(profile.wins) },
			{ "Best moon", if profile.bestTier > 0 then NightProgress.TIERS[profile.bestTier] else "None yet" },
			{ "Nights played", commas(profile.runs) },
			{ "Waves cleared", commas(profile.waves) },
			{ "Yokai defeated", commas(profile.kills) },
			{ "Login streak", `{profile.daily.streak} days` },
			{ "Blade Arts", owned("blade") },
			{ "Masks", owned("mask") },
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

-- Settings (client-only, not saved; take effect at once through ClientState).
local setting = panel("Settings")
renderers.Settings = function()
	clear(setting)
	for i, item in
		{
			{ "music", "Music" },
			{ "sfx", "Sound effects" },
			{ "shake", "Camera shake" },
			{ "numbers", "Damage numbers" },
		}
	do
		local r = row(setting, 50, i)
		text({
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -200, 0, 30),
			Text = item[2],
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local on = (ClientState.settings :: any)[item[1]] == true
		itemButton(r, if on then "ON" else "OFF", if on then GREEN else INK, true, function()
			ClientState.set(item[1], not on)
			renderers.Settings()
		end)
	end
	local r = row(setting, 190, 10)
	text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 1, -16),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "HOW TO PLAY\n"
			.. "Hold the shrine through 10 waves of yokai. Slay the Oni General on wave 5 and the Gashadokuro on wave 10.\n"
			.. "Click / R2 / ATTACK: slash combo.  E / Y / SKILL: Rising Slash launches yokai.\n"
			.. "Q / Shift / X / DASH: dash through attacks.  R / B / TRIGGER: Demon Trigger when the gauge is full.\n"
			.. "Red marks on the ground are attacks about to land. Pick a blessing between waves. Mix your moves for a higher style rank and more souls.",
		Parent = r,
	})
end

openPanel = function(name: string)
	for key, f in panels do
		f.Visible = key == name
	end
	panelTitle.Text = if name == "Play" then "TONIGHT'S HUNT" else string.upper(name)
	-- Beside the start menu's buttons when it is open, centred otherwise.
	panelHolder.Position = if menuOpen then UDim2.fromScale(0.66, 0.52) else UDim2.fromScale(0.5, 0.52)
	panelHolder.Visible = true
	renderers[name]()
end

local function refreshOpenPanel()
	if panelHolder.Visible then
		for name, f in panels do
			if f.Visible and name ~= "Settings" then
				renderers[name]()
			end
		end
	end
end
onProfile.Event:Connect(function()
	refreshHud()
	refreshOpenPanel()
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
	Position = UDim2.fromScale(0.04, 0.1),
	Size = UDim2.fromScale(0.36, 0.84),
	BackgroundTransparency = 1,
	Parent = menu,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 760) }),
})
ClientState.autoScale(column)
local title = text({
	Size = UDim2.new(1, 0, 0, 104),
	Text = "HUNDRED\nDEMON NIGHT",
	Font = Enum.Font.GothamBlack,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = column,
})
new("UIStroke", { Color = RED, Thickness = 4, Parent = title })
local kanji = text({
	Size = UDim2.new(1, 0, 0, 40),
	Text = "百鬼夜行",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = column,
})
new("UIStroke", { Color = Color3.fromRGB(90, 10, 20), Thickness = 3, Parent = kanji })
text({
	Size = UDim2.new(1, 0, 0, 20),
	Text = "HOLD THE SHRINE UNTIL DAWN",
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 3,
	Parent = column,
})

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
		openPanel(item[2])
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
	menuInfo.Text = `Level {NightProgress.levelFor(profile.xp)}  ·  {commas(profile.coins)} souls  ·  {commas(
		profile.wins
	)} nights won`
end)

-- Slow orbit over the lit courtyard behind the menu (stage, gates, stalls and the moon).
local orbitStart = os.clock()
local orbit = RunService.RenderStepped:Connect(function()
	if not menuOpen then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local t = (os.clock() - orbitStart) * 0.04 + 0.6
	local centre = Vector3.new(0, 6, 0)
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(math.cos(t) * 130, 48, math.sin(t) * 130), centre)
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

-- Opening the menu during a run leaves it (GDD B2), so a second press within 3 s confirms.
local leaveAskedAt = -math.huge
showMenu = function()
	if inRun() then
		if os.clock() - leaveAskedAt > 3 then
			leaveAskedAt = os.clock()
			toast("Press MENU again to leave the night", RED)
			return
		end
		ask("leaveRun")
	end
	menuOpen = true
	orbitStart = os.clock()
	menu.Visible = true
	hud.Visible = false
	panelHolder.Visible = false
end

-- Becoming a participant by any route (START button, a host starting, a retry) drops you into the
-- night; opening the menu later mid-run still works, because only the transition hides it.
local wasParticipant = false
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(function()
	if panels.Play.Visible then
		renderers.Play()
	end
	local participant = ClientState.isParticipant() and ClientState.status().state ~= "Idle"
	if participant and not wasParticipant and menuOpen then
		hideMenu()
	end
	wasParticipant = participant
end)

-- Music -----------------------------------------------------------------------------------------

-- Licensed tracks (docs/assets/register.md): lobby, wave playlist, boss, break, victory.
local TRACKS = {
	menu = { "rbxassetid://87416512611152" },
	wave = { "rbxassetid://9048541013", "rbxassetid://1839321669", "rbxassetid://9040647656" },
	boss = { "rbxassetid://1848096079" },
	rest = { "rbxassetid://1838649615" },
	victory = { "rbxassetid://1839432145" },
}
local VOLUME = { menu = 0.35, wave = 0.35, boss = 0.4, rest = 0.2, victory = 0.45 }
local music = new("Sound", { Name = "NightMusic", Volume = 0, Looped = false, Parent = SoundService })
-- Demon Trigger muffles the highs and swells the music (C5, H6).
local filter =
	new("EqualizerSoundEffect", { LowGain = 4, MidGain = -2, HighGain = -14, Enabled = false, Parent = music })
local mode = ""
local trackIndex = 0

local function wantedMode(): string
	local s = ClientState.status()
	if menuOpen or not ClientState.isParticipant() then
		return "menu"
	elseif s.state == "Victory" then
		return "victory"
	elseif s.state == "Break" or s.state == "Defeat" then
		return "rest"
	elseif s.state == "Wave" and (s.wave == 5 or s.wave == 10) then
		return "boss"
	elseif s.state == "Wave" or s.state == "Countdown" then
		return "wave"
	end
	return "menu"
end

local function volume(): number
	if not ClientState.settings.music then
		return 0
	end
	local base = (VOLUME :: any)[mode] or 0.35
	return if player:GetAttribute("Trigger") == true then math.min(base + 0.15, 0.6) else base
end

local function playNext()
	local list = (TRACKS :: any)[mode] or TRACKS.menu
	trackIndex = trackIndex % #list + 1
	music.SoundId = list[trackIndex]
	music.TimePosition = 0
	music:Play()
	TweenService:Create(music, TweenInfo.new(1.5), { Volume = volume() }):Play()
end
music.Ended:Connect(playNext)

local function applyMusic()
	local wanted = wantedMode()
	if wanted ~= mode then
		mode = wanted
		trackIndex = if mode == "wave" then math.random(0, #TRACKS.wave - 1) else 0
		local fade = TweenService:Create(music, TweenInfo.new(0.8), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			if mode == wanted then
				playNext()
			end
		end)
	else
		TweenService:Create(music, TweenInfo.new(0.5), { Volume = volume() }):Play()
	end
	filter.Enabled = player:GetAttribute("Trigger") == true
end
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(applyMusic)
player:GetAttributeChangedSignal("Trigger"):Connect(applyMusic)
ClientState.SettingsChanged:Connect(applyMusic)
menu:GetPropertyChangedSignal("Visible"):Connect(applyMusic)

-- Boot ------------------------------------------------------------------------------------------

gui.Parent = player:WaitForChild("PlayerGui")
readProfile()
refreshHud()
applyMusic()
local _ = orbit
