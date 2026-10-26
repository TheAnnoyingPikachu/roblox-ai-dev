--!strict
-- Neon Spire menus (GDD K1, J, G, I2, K7), forked from the Egg Garden menu and restyled to the art
-- bible UI kit: start menu over a slow camera crane with the build stamp in the bottom-right
-- corner, LOCKER, REWARDS, STATS, SETTINGS, COMPANY (rename from the name lists, logo, brand
-- colour, gate), How to Play and the power, Hype and stacking explainer cards, and the toasts
-- (ClientState.Toast). The client only asks; the server decides through Request(action, arg).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireEconomy = require(Shared:WaitForChild("SpireEconomy"))
local SpireProgress = require(Shared:WaitForChild("SpireProgress"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera
local UI, FONT = ClientState.UI, ClientState.FONT
local new, corner, stroke, text, button =
	ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text, ClientState.button
local commas, short = ClientState.commas, ClientState.short
local ask = ClientState.request

local profile: any = ClientState.me()

local function selectFirst(root: Instance)
	if not ClientState.gamepad() then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d.Visible and d.Active then
			GuiService.SelectedObject = d
			return
		end
	end
end

-- Root GUI ----------------------------------------------------------------------------------------

local gui = ClientState.gui("SpireMenu", 5, true)

-- Toasts stack at the top centre, under the HUD's Market chip; they slide in over 220 ms.
local toasts = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.fromOffset(420, 320),
	BackgroundTransparency = 1,
	ZIndex = 60,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
ClientState.autoScale(toasts)

local function toast(message: string, colour: Color3?)
	local accent = colour or UI.CYAN
	local holder = new("Frame", { Size = UDim2.fromOffset(420, 44), BackgroundTransparency = 1, Parent = toasts })
	local t = text({
		Position = UDim2.fromOffset(0, -20),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BackgroundColor3 = UI.ASPHALT,
		TextTransparency = 1,
		Text = message,
		Parent = holder,
	})
	corner(6).Parent = t
	local outline = stroke(accent, 1.5, 1)
	outline.Parent = t
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = t })
	new("Frame", {
		Size = UDim2.new(0, 3, 1, -10),
		Position = UDim2.fromOffset(-8, 5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = t,
	})
	local slide = TweenInfo.new(0.22, Enum.EasingStyle.Quint)
	TweenService:Create(t, slide, { Position = UDim2.new(), BackgroundTransparency = 0.12, TextTransparency = 0 })
		:Play()
	TweenService:Create(outline, slide, { Transparency = 0.2 }):Play()
	task.delay(4, function()
		TweenService:Create(t, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		TweenService:Create(outline, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		task.delay(0.35, holder.Destroy, holder)
	end)
end
ClientState.Toast:Connect(toast)

-- Panels ------------------------------------------------------------------------------------------

local panels: { [string]: ScrollingFrame } = {}
local renderers: { [string]: () -> () } = {}
local openPanel: (string) -> ()
local hideMenu: () -> ()

local panelHolder = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.64, 0.76),
	Visible = false,
	ZIndex = 10,
	Parent = gui,
})
new("UISizeConstraint", { MaxSize = Vector2.new(880, 640), MinSize = Vector2.new(320, 280), Parent = panelHolder })
local panelTitle = text({
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -90, 0, 38),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.CYAN,
	FontFace = FONT.display,
	Text = "",
	Parent = panelHolder,
})
local closeButton = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(56, 44),
	Text = "X",
	BackgroundColor3 = UI.MAGENTA,
	Outline = true,
	Parent = panelHolder,
}, function()
	panelHolder.Visible = false
end)

local function panel(name: string): ScrollingFrame
	local f = new("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.CYAN,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = panelHolder,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panels[name] = f
	return f
end

local function row(parent: Instance, height: number, order: number, accent: Color3?): Frame
	return new("Frame", {
		Size = UDim2.new(1, -10, 0, height),
		BackgroundColor3 = UI.STEEL,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(6), stroke(accent or UI.CYAN, 1, 0.7) })
end

local function heading(parent: Instance, s: string, order: number): TextLabel
	return text({
		Size = UDim2.new(1, -10, 0, 26),
		Text = s,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.MAGENTA,
		FontFace = FONT.display,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function label(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	s: string,
	colour: Color3?
): TextLabel
	return text({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.new(1, w, 0, h),
		Text = s,
		TextColor3 = colour or UI.WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
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

-- Right-aligned action buttons, packed right to left in call order: each row keeps its own
-- running offset, so mixed widths never overlap (Egg Garden QA).
local function action(
	parent: Instance,
	s: string,
	colour: Color3,
	active: boolean,
	onClick: () -> (),
	width: number?
): TextButton
	local w = width or 120
	local right = (parent:GetAttribute("Right") :: number?) or 10
	parent:SetAttribute("Right", right + w + 8)
	local b = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -right, 0.5, 0),
		Size = UDim2.fromOffset(w, 44),
		Text = s,
		BackgroundColor3 = colour,
		Parent = parent,
	}, function()
		if active then
			onClick()
		end
	end)
	ClientState.enable(b, active)
	return b
end

local function bar(parent: Instance, x: number, y: number, w: number, fraction: number, colour: Color3)
	local back = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.new(1, w, 0, 10),
		BackgroundColor3 = UI.ASPHALT,
		Parent = parent,
	}, { corner(3) })
	new("Frame", {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = colour,
		Parent = back,
	}, { corner(3) })
end

local function paragraphs(f: ScrollingFrame, list: { string })
	for i, para in list do
		local r = row(f, 70, i)
		local t = label(r, 14, 6, -28, 58, para)
		t.TextWrapped = true
		t.TextScaled = false
		t.TextSize = 18
	end
end

-- LOCKER: five cosmetic slots ---------------------------------------------------------------------

local locker = panel("Locker")
local lockerTab = "skin"
local SLOTS =
	{ { "skin", "FACADE" }, { "crown", "CROWN" }, { "lobby", "LOBBY" }, { "tiles", "TILES" }, { "trail", "TRAIL" } }

local function unlockText(c: any): string
	local shares = SpireConfig.SHARE_UNLOCKS[c.id]
	if c.price then
		return `Shop: {short(c.price)} credits`
	elseif shares then
		return `Needs {shares} Share{if shares == 1 then "" else "s"} (IPO)`
	elseif c.level and c.level > 1 then
		return `Unlocks at level {c.level}`
	end
	return "Default"
end

renderers.Locker = function()
	clear(locker)
	local tabs = new("Frame", {
		Size = UDim2.new(1, -10, 0, 46),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = locker,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	for _, tab in SLOTS do
		button({
			Size = UDim2.new(0.2, -5, 1, 0),
			Text = tab[2],
			BackgroundColor3 = UI.CYAN,
			Outline = lockerTab ~= tab[1],
			Parent = tabs,
		}, function()
			lockerTab = tab[1]
			renderers.Locker()
		end)
	end
	local i = 0
	for _, c in SpireConfig.COSMETICS do
		if c.slot ~= lockerTab then
			continue
		end
		i += 1
		local r = row(locker, 62, i)
		local stops = {}
		for j, col in c.colours do
			table.insert(
				stops,
				ColorSequenceKeypoint.new(
					if #c.colours == 1 then 0 else (j - 1) / (#c.colours - 1),
					ClientState.rgb(col)
				)
			)
		end
		if #stops == 1 then
			table.insert(stops, ColorSequenceKeypoint.new(1, stops[1].Value))
		end
		local sw = new("Frame", {
			Position = UDim2.fromOffset(12, 13),
			Size = UDim2.fromOffset(80, 36),
			BackgroundColor3 = if #stops == 0 then UI.GREY else Color3.new(1, 1, 1),
			Parent = r,
		}, { corner(4), stroke(UI.WHITE, 1, 0.5) })
		if #stops >= 2 then
			new("UIGradient", { Color = ColorSequence.new(stops), Parent = sw })
		end
		label(r, 104, 8, -280, 24, c.name)
		label(r, 104, 34, -280, 18, unlockText(c), UI.MUTED)
		local unlocked = SpireProgress.isUnlocked(profile, c.id)
		if (profile :: any)[c.slot] == c.id then
			action(r, "EQUIPPED", UI.LIME, false, function() end, 150)
		elseif unlocked then
			action(r, "EQUIP", UI.CYAN, true, function()
				if ask("equipCosmetic", c.id) then
					toast(`Equipped {c.name}`, UI.LIME)
				end
			end, 150)
		elseif c.price then
			local price = c.price :: number
			local affordable = profile.coins >= price
			local b = action(r, `BUY {short(price)}`, UI.AMBER, affordable, function()
				-- The token bucket (6, refilled 4/s) takes both requests back to back.
				if ask("buyCosmetic", c.id) and ask("equipCosmetic", c.id) then
					toast(`Bought and equipped {c.name}!`, UI.LIME)
				end
			end, 150)
			if not affordable then
				b.TextColor3 = UI.MAGENTA
			end
		else
			action(r, "LOCKED", UI.GREY, false, function() end, 150)
		end
	end
end

-- REWARDS: daily streak, weekly bonus, contracts (amounts scale with income, GDD J) ----------------

local rewards = panel("Rewards")
renderers.Rewards = function()
	clear(rewards)
	local day = MetaRules.dayOf(ClientState.now())
	local nextStreak = MetaRules.nextDaily(profile, day)
	local currentStreak = if nextStreak then nextStreak - 1 else profile.daily.streak
	local function dailyAmount(d: number): number
		local k = math.clamp(d, 1, #SpireConfig.DAILY)
		return SpireProgress.scaled(profile, SpireConfig.DAILY[k], SpireConfig.DAILY_MINUTES[k])
	end
	heading(rewards, "DAILY STREAK", 1)
	local strip = new("Frame", {
		Size = UDim2.new(1, -10, 0, 80),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = rewards,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	for d = 1, 7 do
		local claimed = d <= math.min(currentStreak, 7)
		local isNext = nextStreak ~= nil and d == math.min(nextStreak, 7)
		local cell = new("Frame", {
			Size = UDim2.new(1 / 7, -6, 1, 0),
			BackgroundColor3 = if claimed then UI.STEEL elseif isNext then UI.AMBER else UI.ASPHALT,
			Parent = strip,
		}, { corner(6), stroke(if claimed then UI.LIME else UI.CYAN, 1, 0.4) })
		text({
			Size = UDim2.fromScale(1, 0.4),
			Text = if claimed then `DAY {d} ✓` else `DAY {d}`,
			TextColor3 = if isNext then UI.ASPHALT else UI.WHITE,
			Parent = cell,
		})
		text({
			Position = UDim2.fromScale(0.05, 0.45),
			Size = UDim2.fromScale(0.9, 0.42),
			Text = short(dailyAmount(d)),
			FontFace = FONT.mono,
			TextColor3 = if isNext then UI.ASPHALT else UI.LIME,
			Parent = cell,
		})
	end
	local dailyRow = row(rewards, 56, 3)
	label(
		dailyRow,
		14,
		12,
		-180,
		32,
		if nextStreak
			then `Day {nextStreak} reward: {commas(dailyAmount(nextStreak))} credits`
			else "Come back tomorrow to keep your streak!"
	)
	action(dailyRow, if nextStreak then "CLAIM" else "CLAIMED", UI.AMBER, nextStreak ~= nil, function()
		if ask("claimDaily") then
			ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
		end
	end, 150)

	heading(rewards, "WEEKLY BONUS", 4)
	local weekRow = row(rewards, 56, 5)
	local days = if profile.week.key == MetaRules.weekOf(day) then profile.week.days else 0
	local canWeekly = MetaRules.canClaimWeekly(SpireProgress.CONFIG, profile, day)
	local goal = SpireConfig.WEEKLY.days
	local weekly = SpireProgress.scaled(profile, SpireConfig.WEEKLY.reward, SpireConfig.WEEKLY.minutes)
	label(
		weekRow,
		14,
		12,
		-180,
		32,
		if profile.week.claimed and days > 0
			then "Weekly bonus claimed. A new week starts Monday!"
			else `Play on {goal} days this week ({math.min(days, goal)}/{goal}): {commas(weekly)} credits`
	)
	action(weekRow, if canWeekly then "CLAIM" else `{math.min(days, goal)}/{goal}`, UI.AMBER, canWeekly, function()
		if ask("claimWeekly") then
			ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
		end
	end, 150)

	heading(rewards, "TODAY'S CONTRACTS", 6)
	for i, q in SpireProgress.questsFor(day) do
		local progress = if profile.quests.day == day then profile.quests.progress[q.stat] or 0 else 0
		local claimed = profile.quests.day == day and profile.quests.claimed[q.id] == true
		local done = progress >= q.goal
		local amount = SpireProgress.scaled(profile, q.reward, q.minutes or 0)
		local r = row(rewards, 64, 6 + i)
		label(r, 14, 6, -180, 24, `{q.label}  ·  {short(amount)} credits`)
		bar(r, 14, 40, -190, progress / q.goal, if done then UI.LIME else UI.CYAN)
		action(
			r,
			if claimed
				then "DONE ✓"
				elseif done then "CLAIM"
				else `{short(math.min(progress, q.goal))}/{short(q.goal)}`,
			UI.AMBER,
			done and not claimed,
			function()
				if ask("claimQuest", q.id) then
					ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
				end
			end,
			150
		)
	end
end

-- STATS (GDD J) -------------------------------------------------------------------------------------

local stats = panel("Stats")
renderers.Stats = function()
	clear(stats)
	local income = tonumber(player:GetAttribute("Income")) or SpireEconomy.income(profile, ClientState.event())
	for i, item in
		{
			{ "Company", SpireConfig.companyName(profile.company) },
			{ "Level", tostring(ClientState.level(profile)) },
			{ "Floors", `{#profile.floors} / {SpireConfig.MAX_FLOORS}` },
			{ "Income", `{short(income)} ¢/s` },
			{ "Credits", commas(profile.coins) },
			{ "Lifetime earned", commas(profile.lifetimeEarned) },
			{ "Shares", `{profile.shares} (+{profile.shares * 10}% income)` },
			{ "IPOs", tostring(profile.ipos) },
			{ "Hot Data caught", commas(profile.hotCaught) },
			{ "Endorsements", commas(profile.endorsements) },
			{ "Best tower height", `{profile.bestFloors} floors` },
			{ "Login streak", `{profile.daily.streak} days` },
		}
	do
		local r = row(stats, 42, i)
		label(r, 14, 8, -14, 26, item[1], UI.MUTED).Size = UDim2.new(0.45, -14, 0, 26)
		text({
			Position = UDim2.new(0.45, 0, 0, 8),
			Size = UDim2.new(0.55, -14, 0, 26),
			Text = item[2],
			FontFace = FONT.mono,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
	end
	if player:GetAttribute("ProfileOnline") == false then
		label(
			row(stats, 44, 99, UI.MAGENTA),
			14,
			8,
			-28,
			28,
			"Saving is offline on this server: progress lasts this session only.",
			UI.MAGENTA
		)
	end
end

-- COMPANY: name from the two lists, logo glyph and colour, brand colour, gate (GDD G, I2) ---------

local company = panel("Company")
local draft: { number }? = nil -- p, s, glyph, colour, trim being edited
local FIELDS = {
	{ "Name", #SpireConfig.NAMES.prefixes },
	{ "Second word", #SpireConfig.NAMES.suffixes },
	{ "Logo shape", SpireConfig.GLYPHS },
	{ "Logo colour", #SpireConfig.COLOURS },
	{ "Brand colour", #SpireConfig.COLOURS },
}

renderers.Company = function()
	clear(company)
	local c = profile.company
	local saved = { c.p, c.s, c.glyph, c.colour, c.trim }
	local d = draft or table.clone(saved)
	draft = d
	local preview = { p = d[1], s = d[2], glyph = d[3], colour = d[4], trim = d[5] }
	local top = row(company, 84, 0, ClientState.brand(d[5]))
	local logo = new("Frame", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = UI.ASPHALT,
		Parent = top,
	}, { corner(6), stroke(ClientState.brand(d[5]), 2) })
	ClientState.glyph(logo, d[3], ClientState.brand(d[4]), 64)
	local name = label(top, 90, 12, -110, 36, string.upper(SpireConfig.companyName(preview)))
	name.FontFace = FONT.display
	name.TextColor3 = ClientState.brand(d[5])
	label(top, 90, 52, -110, 20, "Free to rename. Everyone sees the name on your tower.", UI.MUTED)
	for i, field in FIELDS do
		local r = row(company, 54, i)
		label(r, 14, 6, -300, 22, field[1], UI.MUTED)
		local value = if i == 1
			then SpireConfig.NAMES.prefixes[d[1]]
			elseif i == 2 then SpireConfig.NAMES.suffixes[d[2]]
			else `{d[i]} / {field[2]}`
		local v = label(r, 14, 28, -300, 22, value)
		if i >= 4 then
			v.TextColor3 = ClientState.brand(d[i])
		end
		action(r, ">", UI.CYAN, true, function()
			d[i] = d[i] % field[2] + 1
			renderers.Company()
		end, 56)
		action(r, "<", UI.CYAN, true, function()
			d[i] = (d[i] - 2) % field[2] + 1
			renderers.Company()
		end, 56)
	end
	local same = table.concat(d, ":") == table.concat(saved, ":")
	local saveRow = row(company, 56, 10)
	label(saveRow, 14, 12, -200, 30, if same then "No changes" else "Save to rename your company", UI.MUTED)
	action(saveRow, "SAVE", UI.LIME, not same, function()
		if ask("setCompany", table.concat(d, ":")) then
			draft = nil
			toast(`You are now {SpireConfig.companyName(preview)}!`, UI.LIME)
		end
	end, 150)

	heading(company, "TOWER GATE", 11)
	local gate = row(company, 56, 12)
	label(gate, 14, 6, -380, 22, "Who can ride your lift to the Sky Deck")
	label(gate, 14, 30, -380, 18, "and endorse you. Your plaza is always open.", UI.MUTED)
	for i = #SpireConfig.GATES, 1, -1 do
		local g = SpireConfig.GATES[i]
		action(gate, string.upper(g), if profile.gate == g then UI.LIME else UI.CYAN, profile.gate ~= g, function()
			if ask("setGate", g) then
				toast(`Gate set to {g}`, UI.LIME)
			end
		end, 110)
	end
end

-- SETTINGS, How to Play, explainer cards (K7: every tutorial can be reopened) ----------------------

local setting = panel("Settings")
renderers.Settings = function()
	clear(setting)
	local s = ClientState.settings :: any
	for i, item in
		{
			{ "music", "Music" },
			{ "sfx", "Sound effects" },
			{ "reduceFlashing", "Reduce flashing" },
			{ "shake", "Camera shake" },
			{ "announcements", "City announcements" },
		}
	do
		local r = row(setting, 54, i)
		label(r, 14, 12, -170, 30, item[2])
		local on = s[item[1]] == true
		action(r, if on then "ON ✓" else "OFF ✕", if on then UI.LIME else UI.MAGENTA, true, function()
			ClientState.set(item[1], not on)
			renderers.Settings()
		end, 130)
	end
	local rain = row(setting, 54, 6)
	label(rain, 14, 12, -420, 30, "Rain")
	for _, level in { "high", "med", "low" } do
		action(rain, string.upper(level), UI.CYAN, s.rain ~= level, function()
			ClientState.set("rain", level)
			renderers.Settings()
		end, 90)
	end
	local cards = new("Frame", {
		Size = UDim2.new(1, -10, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 10,
		Parent = setting,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	for _, item in { { "HOW TO PLAY", "Help" }, { "POWER", "Power" }, { "HYPE", "Hype" }, { "STACKING", "Stacking" } } do
		button({ Size = UDim2.new(0.25, -5, 1, 0), Text = item[1], Outline = true, Parent = cards }, function()
			openPanel(item[2])
		end)
	end
end

local help = panel("Help")
renderers.Help = function()
	clear(help)
	paragraphs(help, {
		"Your tower earns credits every second, even while you are away (at half rate, up to 8 hours).",
		"Press BUILD. Tap a floor to open its card: buy modules for its 4 slots and upgrade them to level 5.",
		"At the top of the tower, BUY FLOOR picks the department of your next floor. Better departments unlock higher up.",
		"Modules draw power. When the power bar is full, build a Fusion Core floor (from floor 3) and fill it with cells.",
		"Holo Ad Agency floors boost the floors directly above and below them. Where you put them matters.",
		"In PLAZA, place items on the grid for Hype. Hype multiplies all income, up to 10 per floor you own.",
		"Hot Data sparks appear on your floors. Tap GO, ride the lift and grab them for 30 seconds of income.",
		"Market Pulse events change every 10 minutes for the whole city: Data Boom, Neon Night and Flash Sale.",
		"Visit other towers, ride to their Sky Deck and endorse them. Nobody can ever take what you own.",
	})
end

local power = panel("Power")
renderers.Power = function()
	clear(power)
	paragraphs(power, {
		"POWER: every module except a Fusion Cell draws power. The power bar shows draw / supply.",
		"Your lobby supplies 6. Each Fusion Cell adds 8, rising to 75 at level 5. Fusion Core floors unlock at floor 3.",
		"A module that would take draw over supply cannot be bought: BUILD shows how much more power you need.",
		"Power never runs out on its own: income is never reduced, the rule only blocks new modules.",
	})
end

local hype = panel("Hype")
renderers.Hype = function()
	clear(hype)
	paragraphs(hype, {
		"HYPE: plaza items add Hype. Income is multiplied by 1 + Hype / 100, so 50 Hype is +50%.",
		"Hype is capped at 10 per floor you own (and 200 in all): build higher to raise the cap.",
		"The walkway to your lobby door stays clear. Decor items add no Hype but make the plaza yours.",
		"Moving an item is free; selling one refunds half its price.",
	})
end

local stacking = panel("Stacking")
renderers.Stacking = function()
	clear(stacking)
	paragraphs(stacking, {
		"STACKING: a Holo Ad Agency floor with at least one projector boosts the floors directly above and below it by 25%.",
		"A floor between two Ad Agencies gets +50%. Ad and Fusion floors are never boosted.",
		"During Neon Night the boost is +50% per neighbour.",
		"The floor card shows each floor's boost before you buy.",
	})
end

local TITLES = {
	Locker = "LOCKER",
	Rewards = "REWARDS",
	Stats = "STATS",
	Company = "COMPANY",
	Settings = "SETTINGS",
	Help = "HOW TO PLAY",
	Power = "POWER",
	Hype = "HYPE",
	Stacking = "STACKING",
}

-- Panels whose content never depends on the profile.
local STATIC = { Settings = true, Help = true, Power = true, Hype = true, Stacking = true }

local panelScale = new("UIScale", { Parent = panelHolder })
openPanel = function(name: string)
	if name == "Company" then
		draft = nil
	end
	for key, f in panels do
		f.Visible = key == name
	end
	panelTitle.Text = TITLES[name] or string.upper(name)
	-- Beside the start menu's buttons when it is open, centred otherwise.
	panelHolder.Position = if ClientState.menuOpen then UDim2.fromScale(0.64, 0.53) else UDim2.fromScale(0.5, 0.53)
	local was = panelHolder.Visible
	panelHolder.Visible = true
	if not was then
		panelScale.Scale = 0.96
		TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
	end
	panels[name].CanvasPosition = Vector2.zero
	renderers[name]()
	selectFirst(panelHolder)
	if ClientState.gamepad() and GuiService.SelectedObject == nil then
		GuiService.SelectedObject = closeButton
	end
end
ClientState.OpenRequested:Connect(openPanel)

local function visiblePanel(): string?
	if not panelHolder.Visible then
		return nil
	end
	for name, f in panels do
		if f.Visible then
			return name
		end
	end
	return nil
end

-- Start menu (K1) ---------------------------------------------------------------------------------

local menu = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
new("Frame", {
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = UI.ASPHALT,
	BorderSizePixel = 0,
	Parent = menu,
}, { new("UIGradient", { Transparency = NumberSequence.new(0.1, 1) }) })
local column = new("Frame", {
	Position = UDim2.fromScale(0.04, 0.06),
	Size = UDim2.fromScale(0.34, 0.9),
	BackgroundTransparency = 1,
	Parent = menu,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UISizeConstraint", { MaxSize = Vector2.new(420, 760) }),
})
ClientState.autoScale(column)
local title = text({
	Size = UDim2.new(1, 0, 0, 96),
	Text = "NEON SPIRE",
	TextColor3 = UI.CYAN,
	FontFace = FONT.display,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = column,
})
new("UIStroke", { Color = UI.MAGENTA, Thickness = 2, Parent = title })
text({
	Size = UDim2.new(1, 0, 0, 26),
	Text = "Build to the sky.",
	TextColor3 = UI.WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = column,
})

local menuDot: Frame
local MENU_ITEMS = {
	{ "PLAY", "Play" },
	{ "LOCKER", "Locker" },
	{ "REWARDS", "Rewards" },
	{ "STATS", "Stats" },
	{ "COMPANY", "Company" },
	{ "SETTINGS", "Settings" },
}
local playButton: TextButton
for i, item in MENU_ITEMS do
	local b = button({
		Size = UDim2.new(1, 0, 0, if i == 1 then 66 else 50),
		Text = item[1],
		Outline = i ~= 1,
		LayoutOrder = 3 + i,
		Parent = column,
	}, function()
		if item[2] == "Play" then
			hideMenu()
		else
			openPanel(item[2])
		end
	end)
	if i == 1 then
		playButton = b
	end
	if item[2] == "Rewards" then
		menuDot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = UI.AMBER,
			Visible = false,
			Parent = b,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
end
local menuInfo = text({
	Size = UDim2.new(1, 0, 0, 22),
	Text = "",
	TextColor3 = UI.MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 30,
	Parent = column,
})

-- Build stamp (section 9): first 7 characters, bottom-right corner. Playtest notes record it.
local stampLabel = text({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -8),
	Size = UDim2.fromOffset(160, 20),
	Text = `build {string.sub(ClientState.stamp(), 1, 7)}`,
	TextColor3 = UI.MUTED,
	FontFace = FONT.mono,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = menu,
})
task.spawn(function()
	-- BuildInfo can replicate after this script starts.
	ReplicatedStorage:WaitForChild("BuildInfo", 10)
	stampLabel.Text = `build {string.sub(ClientState.stamp(), 1, 7)}`
end)

local function refreshMenu()
	menuDot.Visible = ClientState.rewardsReady(profile)
	local name = SpireConfig.companyName(profile.company)
	menuInfo.Text =
		`{name}  ·  Level {ClientState.level(profile)}  ·  {#profile.floors} floors  ·  {short(profile.coins)} ¢`
end

-- Title glitch: a short offset and colour swap at most twice a second, never with Reduce flashing.
task.spawn(function()
	while true do
		task.wait(0.6 + math.random() * 1.6)
		if menu.Visible and not ClientState.settings.reduceFlashing then
			title.Position = UDim2.fromOffset(math.random(-4, 4), 0)
			title.TextColor3 = UI.MAGENTA
			task.wait(0.08)
			title.Position = UDim2.new()
			title.TextColor3 = UI.CYAN
		end
	end
end)

-- Slow crane up and around the city (greybox stand-in for the showcase tower shot).
local orbitStart = os.clock()
local flying = false
RunService.RenderStepped:Connect(function()
	if not ClientState.menuOpen or flying then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local t = os.clock() - orbitStart
	local a = t * 0.03 + 0.6
	local height = 40 + 140 * (1 - math.exp(-t / 40))
	local centre = Vector3.new(0, 60 + height * 0.4, 0)
	camera.CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * 240, height, math.sin(a) * 240), centre)
end)

-- PLAY: fly from the skyline into the own lobby (K5 0 s), then hand the camera back.
hideMenu = function()
	ClientState.setMenu(false)
	menu.Visible = false
	panelHolder.Visible = false
	GuiService.SelectedObject = nil
	local lot = ClientState.myLot()
	local frame = lot and ClientState.lotFrame(lot)
	local function finish()
		flying = false
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	if frame then
		flying = true
		local goal = CFrame.lookAt(
			frame:PointToWorldSpace(Vector3.new(0, 14, -24)),
			frame:PointToWorldSpace(Vector3.new(0, 8, 10))
		)
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = goal }
		)
		tween:Play()
		tween.Completed:Once(function()
			task.wait(0.3)
			finish()
		end)
	else
		finish()
	end
	ClientState.sound(ClientState.SFX.whoosh, 0.3, nil, 1.1)
	if ClientState.rewardsReady(profile) then
		toast("Rewards are ready! Open REWARDS to claim.", UI.AMBER)
	end
end

ClientState.MenuChanged:Connect(function(open: boolean)
	if open and not menu.Visible then
		orbitStart = os.clock()
		menu.Visible = true
		panelHolder.Visible = false
		selectFirst(column)
	end
end)

-- Live refresh --------------------------------------------------------------------------------------

-- Rebuilds an open panel and puts a gamepad selection back on the button at the same place.
local function rerender(name: string)
	local frame = panels[name]
	local selected = GuiService.SelectedObject
	local path = {}
	if selected and selected:IsDescendantOf(frame) then
		local node: Instance = selected
		while node ~= frame do
			local parent = node.Parent :: Instance
			table.insert(path, 1, table.find(parent:GetChildren(), node))
			node = parent
		end
	end
	renderers[name]()
	if #path > 0 then
		local node: Instance? = frame
		for _, i in path do
			node = node and node:GetChildren()[i]
		end
		if node and node:IsA("GuiObject") and node.Selectable then
			GuiService.SelectedObject = node
		end
	end
end

-- Credits change every second; open panels follow at most once a second so buttons stay current
-- without rebuilding under the cursor every frame (Egg Garden QA N1).
local pending = false
ClientState.ProfileChanged:Connect(function()
	if pending then
		return
	end
	pending = true
	task.delay(0.25, function()
		pending = false
		profile = ClientState.me()
		refreshMenu()
		local name = visiblePanel()
		if name and not STATIC[name] then
			rerender(name)
		end
	end)
end)

-- Boot ----------------------------------------------------------------------------------------------

gui.Parent = player:WaitForChild("PlayerGui")
refreshMenu()
if ClientState.gamepad() then
	GuiService.SelectedObject = playButton
end
