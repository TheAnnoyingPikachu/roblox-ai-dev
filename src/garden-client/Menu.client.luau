--!strict
-- Egg Garden menus (GDD H2-H6, E5-E6, decision 0008), forked from the Relay / Night menu: start
-- menu over a camera orbit of Hatchling Valley, EGGS (cart panel with ODDS cards and the Lucky
-- Meter), INDEX, CREATURES (place, store, release, favourite, pen slots, gate), LOCKER, REWARDS,
-- DASH (Splash Dash ready state and prize eggs), STATS, SETTINGS, ADMIN (owner's creature catalogue),
-- How to Play and Odds cards, toasts
-- and music by weather. The client only asks;
-- the server decides every outcome through Request(action, arg).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local HatchRules = require(Shared:WaitForChild("HatchRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera
local UI = ClientState.UI
local new, corner, stroke, text, button =
	ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text, ClientState.button
local commas, short = ClientState.commas, ClientState.short

local profile: any = ClientState.profile()

-- Requests go out at least 0.4 s apart: a second one inside the server's 0.35 s limit is refused.
local nextAsk = 0
local function ask(action: string, arg: string?): boolean
	local slot = math.max(os.clock(), nextAsk)
	nextAsk = slot + 0.4
	if slot > os.clock() then
		task.wait(slot - os.clock())
	end
	local ok, result = pcall(request.InvokeServer, request, action, arg)
	return ok and result == true
end

local function gamepad(): boolean
	return UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
end

local function selectFirst(root: Instance)
	if not gamepad() then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d.Visible then
			GuiService.SelectedObject = d
			return
		end
	end
end

-- Root GUI ----------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "GardenMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Toasts stack at the top centre, under the HUD's coin bar.
local toasts = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(380, 300),
	BackgroundTransparency = 1,
	ZIndex = 20, -- over the panels
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
ClientState.autoScale(toasts)

local function toast(message: string, colour: Color3?)
	local accent = colour or UI.PINK
	local t = text({
		Size = UDim2.fromOffset(380, 40),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = UI.CREAM,
		Text = message,
		Parent = toasts,
	})
	corner(14).Parent = t
	local outline = stroke(accent, 3)
	outline.Parent = t
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = t })
	ClientState.pop(t)
	task.delay(4, function()
		TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		TweenService:Create(outline, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.45, t.Destroy, t)
	end)
end
ClientState.Toasted:Connect(toast)

player:GetAttributeChangedSignal("LastReward"):Connect(function()
	local reward = player:GetAttribute("LastReward")
	if type(reward) == "string" and reward ~= "" then
		toast(string.match(reward, "^(.*)#%d+$") or reward, UI.GOLD) -- "#n" only makes repeats change
	end
end)

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "notice" and type(data) == "table" and type(data.text) == "string" then
		toast(data.text, UI.CORAL)
	end
end)

-- Panels ------------------------------------------------------------------------------------------

local panels: { [string]: ScrollingFrame } = {}
local renderers: { [string]: () -> () } = {}
local openPanel: (string) -> ()
local hideMenu: () -> ()

local panelHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.64, 0.76),
	BackgroundColor3 = UI.PANEL,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, {
	corner(22),
	stroke(UI.PINK, 4),
	new("UISizeConstraint", { MaxSize = Vector2.new(880, 640), MinSize = Vector2.new(320, 280) }),
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 240), Color3.fromRGB(255, 232, 238)),
	}),
})
local panelTitle = text({
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -90, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.PINK,
	Text = "",
	Parent = panelHolder,
})
new("UIStroke", { Color = UI.WHITE, Thickness = 3, Parent = panelTitle })
button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(48, 42),
	Text = "X",
	BackgroundColor3 = UI.CORAL,
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
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.PINK,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = panelHolder,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panels[name] = f
	return f
end

local function row(parent: Instance, height: number, order: number): Frame
	return new("Frame", {
		Size = UDim2.new(1, -10, 0, height),
		BackgroundColor3 = UI.CARD,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(14), stroke(Color3.fromRGB(245, 215, 225), 2) })
end

local function heading(parent: Instance, label: string, order: number)
	local h = text({
		Size = UDim2.new(1, -10, 0, 28),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.LEAF,
		LayoutOrder = order,
		Parent = parent,
	})
	return h
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
		TextColor3 = colour or UI.INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

-- A card of wrapped body text, as tall as it needs; 18 px at any screen size.
local function para(parent: Instance, s: string, order: number, colour: Color3?): TextLabel
	local r = row(parent, 0, order)
	r.AutomaticSize = Enum.AutomaticSize.Y
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = r,
	})
	return text({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = s,
		Font = Enum.Font.GothamMedium,
		TextColor3 = colour or UI.INK,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
end

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Right-aligned action button; slot 1 is rightmost, and each later slot sits left of the real
-- widths before it, so buttons of different widths never overlap.
local function action(
	parent: Instance,
	s: string,
	colour: Color3,
	active: boolean,
	onClick: () -> (),
	slot: number?,
	width: number?
)
	local w = width or 120
	local right = if (slot or 1) == 1 then 10 else parent:GetAttribute("ActionRight") or 10
	parent:SetAttribute("ActionRight", right + w + 8)
	local b = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -right, 0.5, 0),
		Size = UDim2.fromOffset(w, 40),
		Text = s,
		BackgroundColor3 = if active then colour else UI.GREY,
		TextColor3 = if colour == UI.GOLD and active then UI.INK else UI.WHITE,
		Parent = parent,
	}, function()
		if active then
			onClick()
		end
	end)
	b.AutoButtonColor = active
	return b
end

-- A pill-shaped egg swatch in the egg's two shell colours.
local function eggIcon(parent: Instance, egg: string, x: number, y: number, size: number)
	local colours = ClientState.EGG_COLOURS[egg] or ClientState.EGG_COLOURS.starter
	new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size * 0.78, size),
		BackgroundColor3 = UI.WHITE,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(colours[1], colours[2]) }),
		stroke(UI.WHITE, 2),
	})
end

local function bar(parent: Instance, x: number, y: number, w: number, fraction: number, colour: Color3)
	local back = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.new(1, w, 0, 12),
		BackgroundColor3 = Color3.fromRGB(245, 230, 235),
		Parent = parent,
	}, { corner(6) })
	new("Frame", {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = colour,
		Parent = back,
	}, { corner(6) })
end

local function eggsUsing(species: string): string
	local names = {}
	for _, e in GardenConfig.EGGS do
		if e.price then
			for _, o in e.odds do
				if o.id == species and o.bp > 0 then
					table.insert(names, (e.name:gsub(" Egg$", "")))
				end
			end
		end
	end
	return if #names > 0 then table.concat(names, ", ") .. " Egg" else "Starter Egg"
end

local function weathersFor(mutation: string): string
	local fixed = GardenConfig.fixedBy(mutation)
	if fixed then
		return fixed.name
	end
	local names = {}
	for _, w in GardenConfig.WEATHERS do
		for _, o in w.mutation do
			if o.id == mutation and o.bp > 0 then
				table.insert(names, w.name)
			end
		end
	end
	return if #names == #GardenConfig.WEATHERS then "Any weather" else table.concat(names, ", ")
end

-- Two-decimal percent rows for an odds table, with a checked total.
local function oddsRows(
	parent: Instance,
	order: number,
	odds: { any },
	nameOf: (string) -> string,
	colourOf: ((string) -> Color3)?
): number
	local total = 0
	local r = row(parent, 30 * (#odds + 1) + 12, order)
	for i, o in odds do
		total += o.bp
		label(r, 14, 6 + (i - 1) * 30, -120, 26, nameOf(o.id), if colourOf then colourOf(o.id) else nil)
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 6 + (i - 1) * 30),
			Size = UDim2.fromOffset(110, 26),
			Text = `{HatchRules.percent(o.bp)}%`,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
	end
	label(r, 14, 6 + #odds * 30, -120, 26, "Total", UI.MUTED)
	text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6 + #odds * 30),
		Size = UDim2.fromOffset(110, 26),
		Text = `{HatchRules.percent(total)}%`,
		TextColor3 = UI.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = r,
	})
	return order + 1
end

local function speciesName(id: string): string
	local s = GardenConfig.species(id)
	return if s then `{s.name}  ({ClientState.rarityName(id)})` else id
end

local function mutationName(id: string): string
	local m = GardenConfig.mutation(id)
	return if m then `{m.name}  x{m.mult}` else id
end

-- "Every Celestial Egg hatches Legendary or Mythic with the Celestial mutation." (GDD S5)
local function guarantee(egg: any): string
	local rarities = {}
	for _, o in egg.odds do
		local name = ClientState.rarityName(o.id)
		if not table.find(rarities, name) then
			table.insert(rarities, name)
		end
	end
	local m = GardenConfig.mutation(egg.mutation)
	return `Every {egg.name} hatches {table.concat(rarities, " or ")} with the {if m then m.name else egg.mutation} mutation.`
end

-- EGGS: the cart panel --------------------------------------------------------------------------

local eggsPanel = panel("Eggs")
local restockLabel: TextLabel? = nil
renderers.Eggs = function()
	clear(eggsPanel)
	local now = ClientState.now()
	local empty = GardenRules.firstEmptyBed(profile)
	local top = row(eggsPanel, 54, 0)
	restockLabel = label(top, 14, 6, -200, 20, "", UI.LEAF)
	local used = 0
	for i = 1, profile.bedCount do
		if GardenRules.bedState(profile, i, now) ~= "empty" then
			used += 1
		end
	end
	label(top, 14, 28, -200, 20, `Beds in use: {used} / {profile.bedCount}`, UI.MUTED)
	local bedCost = GardenRules.nextBedCost(profile)
	action(
		top,
		if bedCost then `NEW BED {short(bedCost)}` else "ALL BEDS",
		UI.LEAF,
		bedCost ~= nil and profile.coins >= bedCost,
		function()
			if ask("buyBed") then
				ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.5)
				toast("New garden bed unlocked!", UI.LEAF)
			end
		end,
		1,
		170
	)
	local order = 1
	for _, egg in GardenConfig.EGGS do
		if egg.price == nil then
			continue
		end
		local price = egg.price :: number
		order += 1
		local r = row(eggsPanel, if egg.mutation then 210 else 166, order)
		eggIcon(r, egg.id, 12, 12, 64)
		label(r, 72, 8, -86, 28, egg.name)
		label(
			r,
			72,
			38,
			-86,
			22,
			`{short(price)} coins  -  grows in {ClientState.clock(egg.grow)}  -  level {egg.level}`,
			UI.MUTED
		)
		local left = GardenRules.stockLeft(profile, egg.id, now)
		label(
			r,
			72,
			62,
			-86,
			22,
			if left == math.huge
				then "Always in stock"
				elseif left > 0 then `{left} left this restock`
				else "Sold out until the next restock",
			if left > 0 then UI.LEAF else UI.CORAL
		)
		if egg.meter and egg.top then
			local pity = profile.pity[egg.id] or 0
			local best = GardenConfig.species(egg.top)
			label(
				r,
				72,
				86,
				-86,
				22,
				`Lucky Meter {pity} / {egg.meter}: {if best then best.name else egg.top} by hatch {egg.meter}`,
				UI.LILAC
			)
		end
		if egg.mutation then
			(r:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = UI.GOLD
			label(r, 72, 110, -86, 44, guarantee(egg), UI.LEAF).TextWrapped = true
		end
		local strip = new("Frame", {
			Position = UDim2.new(0, 0, 1, -52),
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			Parent = r,
		})
		local unlocked = GardenRules.eggUnlocked(profile, egg.id)
		local buyText = if not unlocked
			then `LEVEL {egg.level}`
			elseif left <= 0 then "SOLD OUT"
			elseif empty == nil then "BEDS FULL"
			else `BUY {short(price)}`
		local canBuy = unlocked and left > 0 and empty ~= nil and profile.coins >= price
		action(strip, buyText, UI.PINK, canBuy, function()
			if ask("buyEgg", egg.id) then
				ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.8)
				toast(`{egg.name} planted in bed {empty}!`, UI.LEAF)
			else
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local far = root
					and (Vector3.new(root.Position.X, 0, root.Position.Z) - ClientState.CART).Magnitude > 25
				toast(if far then "Walk to the Egg Cart to buy eggs" else "Could not buy that egg right now", UI.CORAL)
			end
		end, 1, 130)
		action(strip, "ODDS", UI.LILAC, true, function()
			ClientState.oddsEgg = egg.id
			openPanel("Odds")
		end, 2, 90)
	end
end

-- ODDS card: one egg (from the cart) or every egg and weather (from Settings or the Index).
local oddsPanel = panel("Odds")
renderers.Odds = function()
	clear(oddsPanel)
	local only = ClientState.oddsEgg :: string?
	local onlyEgg = only and GardenConfig.egg(only)
	local weather = ClientState.status().weather
	local order = 0
	for _, egg in GardenConfig.EGGS do
		if egg.price == nil or (only and egg.id ~= only) then
			continue
		end
		order += 1
		heading(oddsPanel, `{string.upper(egg.name)}: CREATURES`, order)
		order = oddsRows(oddsPanel, order + 1, egg.odds, speciesName, ClientState.rarityColour)
		if egg.mutation then
			heading(oddsPanel, "MUTATION", order)
			order = oddsRows(oddsPanel, order + 1, { { id = egg.mutation, bp = 10000 } }, function(id)
				return `{mutationName(id)}, any weather`
			end)
			para(oddsPanel, guarantee(egg), order, UI.LEAF)
			order += 1
		end
		if egg.meter and egg.top then
			local r = row(oddsPanel, 60, order)
			local pity = profile.pity[egg.id] or 0
			local best = GardenConfig.species(egg.top)
			label(r, 14, 6, -28, 22, `Lucky Meter {pity} / {egg.meter}`, UI.LILAC)
			label(
				r,
				14,
				32,
				-28,
				22,
				`{if best then best.name else egg.top} is guaranteed by hatch {egg.meter} of this egg.`,
				UI.MUTED
			)
			order += 1
		end
	end
	order += 1
	heading(oddsPanel, "SIZES (EVERY EGG)", order)
	local sizes = {}
	for _, s in GardenConfig.SIZES do
		table.insert(sizes, { id = s.id, bp = s.bp })
	end
	order = oddsRows(oddsPanel, order + 1, sizes, function(id)
		local s = GardenConfig.size(id)
		return if s then `{s.name}  x{s.mult} coins` else id
	end)
	for _, w in GardenConfig.WEATHERS do
		if onlyEgg and (onlyEgg.mutation or w.id ~= weather) then
			continue
		end
		order += 1
		local now = if w.id == weather then "  (NOW)" else ""
		heading(oddsPanel, `MUTATIONS IN {string.upper(w.name)}{now}`, order)
		order = oddsRows(oddsPanel, order + 1, w.mutation, mutationName)
	end
	if not only then
		order += 1
		heading(oddsPanel, "WEATHER SCHEDULE (EVERY 10 MINUTES)", order)
		local names = function(id: string): string
			return ClientState.weatherName(id)
		end
		order += 1
		heading(oddsPanel, "Monday to Friday", order).TextColor3 = UI.MUTED
		order = oddsRows(oddsPanel, order + 1, GardenConfig.WEATHER_ODDS.weekday, names)
		heading(oddsPanel, "Saturday and Sunday (Weekend Bloom)", order).TextColor3 = UI.MUTED
		order = oddsRows(oddsPanel, order + 1, GardenConfig.WEATHER_ODDS.weekend, names)
	end
	local note = row(oddsPanel, 46, order + 1)
	label(
		note,
		14,
		6,
		-28,
		34,
		"These are the exact numbers the server uses. Odds never change except by weather.",
		UI.MUTED
	).TextWrapped =
		true
end

-- INDEX: 9 species x 4 mutations, plus Celestial for the two species of the Celestial Egg -----------

local MUTATION_COLOURS = {
	normal = Color3.fromRGB(180, 225, 190),
	golden = Color3.fromRGB(255, 205, 70),
	moonlit = Color3.fromRGB(140, 150, 255),
	rainbow = Color3.fromRGB(255, 140, 200),
	celestial = ClientState.CELESTIAL,
}

local indexPanel = panel("Index")
renderers.Index = function()
	clear(indexPanel)
	local found: { [string]: boolean } = {}
	for _, key in profile.index do
		found[key] = true
	end
	local top = row(indexPanel, 56, 0)
	label(top, 14, 6, -28, 22, `{#profile.index} / {GardenConfig.INDEX_SIZE} found`, UI.LEAF)
	label(top, 14, 30, -28, 20, `Each new entry: +50 XP and +2% income forever (now +{#profile.index * 2}%)`, UI.MUTED)
	for i, sp in GardenConfig.SPECIES do
		local any = false
		for _, m in GardenConfig.MUTATIONS do
			any = any or found[`{sp.id}:{m.id}`] == true
		end
		local r = row(indexPanel, 144, i)
		label(
			r,
			14,
			6,
			-28,
			24,
			if any then sp.name else "???",
			if any then ClientState.rarityColour(sp.id) else UI.MUTED
		)
		label(
			r,
			14,
			30,
			-28,
			20,
			`{ClientState.rarityName(sp.id)}  -  {sp.rate} coins/s  -  from {eggsUsing(sp.id)}`,
			UI.MUTED
		)
		local cells = new("Frame", {
			Position = UDim2.fromOffset(10, 54),
			Size = UDim2.new(1, -20, 0, 82),
			BackgroundTransparency = 1,
			Parent = r,
		}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
		local kinds = {}
		for _, m in GardenConfig.MUTATIONS do
			if GardenConfig.indexable(sp.id, m.id) then
				table.insert(kinds, m)
			end
		end
		for _, m in kinds do
			local has = found[`{sp.id}:{m.id}`] == true
			local cell = new("Frame", {
				Size = UDim2.new(1 / #kinds, -5, 1, 0),
				BackgroundColor3 = if has then MUTATION_COLOURS[m.id] or UI.MINT else Color3.fromRGB(90, 80, 95),
				Parent = cells,
			}, { corner(10) })
			if m.id == "celestial" then
				stroke(UI.GOLD, 2).Parent = cell
			end
			text({
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 0, 28),
				Text = if has then m.name else "?",
				TextColor3 = if has then UI.INK else UI.WHITE,
				Parent = cell,
			})
			text({
				Position = UDim2.fromOffset(4, 34),
				Size = UDim2.new(1, -8, 0, 44),
				Text = if has then "Found" else weathersFor(m.id),
				TextColor3 = if has then UI.INK else Color3.fromRGB(220, 210, 225),
				Font = Enum.Font.GothamMedium,
				TextWrapped = true,
				Parent = cell,
			})
		end
	end
	local order = #GardenConfig.SPECIES + 1
	for _, w in GardenConfig.WEATHERS do
		order += 1
		heading(indexPanel, `MUTATIONS IN {string.upper(w.name)}`, order)
		order = oddsRows(indexPanel, order + 1, w.mutation, mutationName)
	end
	for _, m in GardenConfig.MUTATIONS do
		local fixed = GardenConfig.fixedBy(m.id)
		if fixed then
			order += 1
			para(indexPanel, `{mutationName(m.id)}: only from the {fixed.name}, in any weather.`, order, UI.MUTED)
		end
	end
end

-- ADMIN: every creature in every size, for the owner (decision 0013). Only the owner sees the HUD
-- button that opens this; the server decides on GardenConfig.ADMINS --------------------------------

local adminPanel = panel("Admin")
local adminSize = "normal"

-- Shows the species' real mesh; nothing if the server has not loaded it.
local function preview(parent: Instance, species: string)
	local folder = ReplicatedStorage:FindFirstChild("GardenSpecies")
	local mesh = folder and folder:FindFirstChild(species) :: BasePart?
	if mesh == nil then
		return
	end
	local view = new("ViewportFrame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(116, 126),
		BackgroundColor3 = UI.WHITE,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		Parent = parent,
	}, { corner(10) })
	local copy = mesh:Clone()
	copy.CFrame = CFrame.identity
	copy.Parent = view
	local eye = new("Camera", { FieldOfView = 30, Parent = view })
	eye.CFrame = CFrame.lookAt(Vector3.new(0.45, 0.25, -1).Unit * mesh.Size.Magnitude * 2, Vector3.zero)
	view.CurrentCamera = eye
end

renderers.Admin = function()
	clear(adminPanel)
	local top = row(adminPanel, 56, 0)
	label(top, 14, 6, -310, 22, "Tap a creature to add it", UI.LEAF)
	label(top, 14, 30, -310, 20, `Storage {GardenRules.storageCount(profile)} / {GardenConfig.STORAGE}`, UI.MUTED)
	for i = #GardenConfig.SIZES, 1, -1 do
		local size = GardenConfig.SIZES[i]
		action(top, size.name, if size.id == adminSize then UI.PINK else UI.SKY, true, function()
			adminSize = size.id
			renderers.Admin()
		end, #GardenConfig.SIZES - i + 1, 88)
	end
	for i, sp in GardenConfig.SPECIES do
		local r = row(adminPanel, 146, i)
		preview(r, sp.id)
		label(r, 138, 8, -148, 24, sp.name, ClientState.rarityColour(sp.id))
		label(r, 138, 34, -148, 18, ClientState.rarityName(sp.id), UI.MUTED)
		local cells = new("Frame", {
			Position = UDim2.fromOffset(138, 58),
			Size = UDim2.new(1, -148, 0, 78),
			BackgroundTransparency = 1,
			Parent = r,
		}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
		local kinds = {}
		for _, m in GardenConfig.MUTATIONS do
			if GardenConfig.indexable(sp.id, m.id) then
				table.insert(kinds, m)
			end
		end
		for _, m in kinds do
			local rate = GardenRules.rate({ id = 0, s = sp.id, m = m.id, z = adminSize, placed = 0, fav = false })
			button({
				Size = UDim2.new(1 / #kinds, -5, 1, 0),
				Text = `{m.name}\n{short(rate)}/s`,
				BackgroundColor3 = MUTATION_COLOURS[m.id] or UI.MINT,
				TextColor3 = UI.INK,
				Parent = cells,
			}, function()
				local name = ClientState.creatureName(sp.id, m.id, adminSize)
				if ask("adminGrant", `{sp.id}:{m.id}:{adminSize}`) then
					toast(`{name} added to your garden`, UI.LEAF)
				else
					toast("Not added: your storage may be full", UI.CORAL)
				end
			end)
		end
	end
end

-- CREATURES: pen, storage, release, favourite, pen slots, gate ------------------------------------

local confirm = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(60, 40, 60),
	BackgroundTransparency = 0.45,
	Visible = false,
	ZIndex = 50,
	Parent = gui,
})
local confirmCard = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 200),
	BackgroundColor3 = UI.CREAM,
	Parent = confirm,
}, { corner(20), stroke(UI.PINK, 4) })
ClientState.autoScale(confirmCard)
local confirmText = text({
	Position = UDim2.fromOffset(20, 18),
	Size = UDim2.new(1, -40, 0, 90),
	TextWrapped = true,
	Text = "",
	Parent = confirmCard,
})
local confirmYes: () -> () = function() end
button({
	Position = UDim2.new(0.5, 8, 1, -70),
	Size = UDim2.new(0.5, -28, 0, 52),
	Text = "RELEASE",
	BackgroundColor3 = UI.PINK,
	Parent = confirmCard,
}, function()
	confirm.Visible = false
	confirmYes()
end)
local noButton = button({
	Position = UDim2.new(0, 20, 1, -70),
	Size = UDim2.new(0.5, -28, 0, 52),
	Text = "KEEP",
	BackgroundColor3 = UI.LEAF,
	Parent = confirmCard,
}, function()
	confirm.Visible = false
end)

local function ask2(message: string, onYes: () -> ())
	confirmText.Text = message
	confirmYes = onYes
	confirm.Visible = true
	if gamepad() then
		GuiService.SelectedObject = noButton
	end
end

local creaturesPanel = panel("Creatures")
local function creatureRow(c: any, order: number)
	local name = ClientState.creatureName(c.s, c.m, c.z)
	local r = row(creaturesPanel, 62, order)
	new("Frame", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(0, 6, 1, -16),
		BackgroundColor3 = ClientState.rarityColour(c.s),
		Parent = r,
	}, { corner(3) })
	label(r, 16, 6, -390, 26, name, ClientState.rarityColour(c.s))
	local where = if c.placed > 0 then `pad {c.placed}` else "in storage, not earning"
	label(
		r,
		16,
		34,
		-390,
		18,
		`{ClientState.rarityName(c.s)}  -  {short(GardenRules.rate(c))} coins/s  -  {where}`,
		UI.MUTED
	)
	local id = tostring(c.id)
	if c.placed > 0 then
		action(r, "STORE", UI.SKY, GardenRules.storageCount(profile) < GardenConfig.STORAGE, function()
			ask("store", id)
		end, 1, 100)
	else
		action(r, "PLACE", UI.LEAF, GardenRules.freePad(profile) ~= nil, function()
			if not ask("place", id) then
				toast("Your pen is full: store a creature or buy a pen slot", UI.CORAL)
			end
		end, 1, 100)
	end
	action(r, if c.fav then "LOVED" else "LOVE", UI.GOLD, true, function()
		ask("favourite", id)
	end, 2, 90)
	local value = GardenRules.releaseValue(c)
	action(r, if c.fav then "LOCKED" else "RELEASE", UI.CORAL, not c.fav, function()
		ask2(`Release {name} to the wild meadow?\n+{commas(value)} coins`, function()
			if ask("release", id) then
				ClientState.sound(ClientState.SFX.whoosh, 0.3, nil, 1.2)
			end
		end)
	end, 3, 110)
end

renderers.Creatures = function()
	clear(creaturesPanel)
	local placed, stored = {}, {}
	for _, c in profile.creatures do
		table.insert(if c.placed > 0 then placed else stored, c)
	end
	local function byRate(a: any, b: any): boolean
		local ra, rb = GardenRules.rate(a), GardenRules.rate(b)
		return if ra == rb then a.id < b.id else ra > rb
	end
	table.sort(placed, byRate)
	table.sort(stored, byRate)

	local top = row(creaturesPanel, 54, 0)
	label(top, 14, 6, -220, 22, `Income {short(GardenRules.income(profile))} coins/s`, UI.LEAF)
	label(
		top,
		14,
		30,
		-220,
		18,
		`Pen {#placed} / {profile.penSlots}  -  Storage {#stored} / {GardenConfig.STORAGE}`,
		UI.MUTED
	)
	local slotCost = GardenRules.nextPenCost(profile)
	action(
		top,
		if slotCost then `NEW PAD {short(slotCost)}` else "ALL PADS",
		UI.LEAF,
		slotCost ~= nil and profile.coins >= slotCost,
		function()
			if ask("buyPenSlot") then
				ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.5)
				toast("New pen pad unlocked!", UI.LEAF)
			end
		end,
		1,
		170
	)

	local gate = row(creaturesPanel, 54, 1)
	label(gate, 14, 6, -380, 22, "Garden gate")
	label(gate, 14, 30, -380, 18, "Who can water and like your garden", UI.MUTED)
	for i, g in { "closed", "friends", "open" } do
		action(gate, string.upper(g), if profile.gate == g then UI.PINK else UI.SKY, profile.gate ~= g, function()
			if ask("setGate", g) then
				toast(`Gate set to {g}`, UI.LEAF)
			end
		end, i, 100)
	end

	heading(creaturesPanel, "IN YOUR PEN (EARNING)", 2)
	for i, c in placed do
		creatureRow(c, 2 + i)
	end
	if #placed == 0 then
		label(row(creaturesPanel, 40, 3), 14, 8, -28, 24, "Hatch an egg to fill your pen!", UI.MUTED)
	end
	heading(creaturesPanel, "STORAGE", 200)
	for i, c in stored do
		creatureRow(c, 200 + i)
	end
	if #stored == 0 then
		label(row(creaturesPanel, 40, 201), 14, 8, -28, 24, "Storage is empty", UI.MUTED)
	end
end

-- LOCKER: fences and watering cans ----------------------------------------------------------------

local locker = panel("Locker")
local lockerTab = "fence"
local function unlockText(c: any): string
	if c.price then
		return `Shop: {short(c.price)} coins`
	elseif c.index then
		return `Find {c.index} Index entries`
	elseif c.level and c.level > 1 then
		return `Unlocks at level {c.level}`
	end
	return "Default"
end

renderers.Locker = function()
	clear(locker)
	local tabs = new("Frame", {
		Size = UDim2.new(1, -10, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = locker,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	for _, tab in { { "fence", "FENCES" }, { "can", "WATERING CANS" } } do
		button({
			Size = UDim2.new(0.5, -4, 1, 0),
			Text = tab[2],
			BackgroundColor3 = if lockerTab == tab[1] then UI.PINK else UI.SKY,
			Parent = tabs,
		}, function()
			lockerTab = tab[1]
			renderers.Locker()
		end)
	end
	local i = 0
	for _, c in GardenConfig.COSMETICS do
		if c.slot ~= lockerTab then
			continue
		end
		i += 1
		local r = row(locker, 60, i)
		local stops = {}
		for j, col in c.colours do
			table.insert(
				stops,
				ColorSequenceKeypoint.new(
					if #c.colours == 1 then 0 else (j - 1) / (#c.colours - 1),
					ClientState.colour(col)
				)
			)
		end
		if #stops == 1 then
			table.insert(stops, ColorSequenceKeypoint.new(1, stops[1].Value))
		end
		local sw = new("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(90, 36),
			BackgroundColor3 = if #stops == 0 then UI.GREY else UI.WHITE,
			Parent = r,
		}, { corner(10), stroke(UI.WHITE, 2) })
		if #stops >= 2 then
			new("UIGradient", { Color = ColorSequence.new(stops), Parent = sw })
		end
		label(r, 114, 8, -270, 24, c.name)
		label(r, 114, 34, -270, 18, unlockText(c), UI.MUTED)
		local unlocked = GardenProgress.isUnlocked(profile, c.id)
		if (profile :: any)[c.slot] == c.id then
			action(r, "EQUIPPED", UI.LEAF, false, function() end, 1, 140)
		elseif unlocked then
			action(r, "EQUIP", UI.PINK, true, function()
				if ask("equipCosmetic", c.id) then
					toast(`Equipped {c.name}`, UI.LEAF)
				end
			end, 1, 140)
		elseif c.price then
			local price = c.price :: number
			action(r, `BUY {short(price)}`, UI.GOLD, profile.coins >= price, function()
				if ask("buyCosmetic", c.id) then
					toast(`Bought {c.name}!`, UI.LEAF)
					ask("equipCosmetic", c.id)
				end
			end, 1, 140)
		else
			action(r, "LOCKED", UI.GREY, false, function() end, 1, 140)
		end
	end
end

-- REWARDS: daily streak, weekly bonus, quests (amounts scale with the garden, H5) ------------------

local rewards = panel("Rewards")
renderers.Rewards = function()
	clear(rewards)
	local day = MetaRules.dayOf(ClientState.now())
	local nextStreak = MetaRules.nextDaily(profile, day)
	local currentStreak = if nextStreak then nextStreak - 1 else profile.daily.streak
	local function dailyAmount(d: number): number
		local k = math.clamp(d, 1, #GardenConfig.DAILY)
		return GardenProgress.scaled(profile, GardenConfig.DAILY[k], GardenConfig.DAILY_MINUTES[k])
	end
	heading(rewards, "DAILY STREAK", 1)
	local strip = new("Frame", {
		Size = UDim2.new(1, -10, 0, 84),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = rewards,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	for d = 1, 7 do
		local claimed = d <= math.min(currentStreak, 7)
		local isNext = nextStreak ~= nil and d == math.min(nextStreak, 7)
		local cell = new("Frame", {
			Size = UDim2.new(1 / 7, -6, 1, 0),
			BackgroundColor3 = if claimed then UI.MINT elseif isNext then UI.GOLD else UI.CARD,
			Parent = strip,
		}, { corner(12), stroke(UI.WHITE, 2) })
		text({ Size = UDim2.fromScale(1, 0.4), Text = `DAY {d}`, Parent = cell })
		text({
			Position = UDim2.fromScale(0.05, 0.45),
			Size = UDim2.fromScale(0.9, 0.42),
			Text = short(dailyAmount(d)),
			TextColor3 = if claimed or isNext then UI.INK else UI.LEAF,
			Parent = cell,
		})
	end
	local dailyRow = row(rewards, 52, 3)
	label(
		dailyRow,
		14,
		10,
		-170,
		32,
		if nextStreak
			then `Day {nextStreak} reward: {commas(dailyAmount(nextStreak))} coins`
			else "Come back tomorrow to keep your streak!"
	)
	action(dailyRow, if nextStreak then "CLAIM" else "CLAIMED", UI.GOLD, nextStreak ~= nil, function()
		if ask("claimDaily") then
			ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
		end
	end, 1, 140)

	heading(rewards, "WEEKLY BONUS", 4)
	local weekRow = row(rewards, 52, 5)
	local days = if profile.week.key == MetaRules.weekOf(day) then profile.week.days else 0
	local canWeekly = MetaRules.canClaimWeekly(GardenProgress.CONFIG, profile, day)
	local goal = GardenConfig.WEEKLY.days
	local weekly = GardenProgress.scaled(profile, GardenConfig.WEEKLY.reward, GardenConfig.WEEKLY.minutes)
	label(
		weekRow,
		14,
		10,
		-170,
		32,
		if profile.week.claimed and days > 0
			then "Weekly bonus claimed. A new week starts Monday!"
			else `Play on {goal} days this week ({math.min(days, goal)}/{goal}): {commas(weekly)} coins`
	)
	action(weekRow, if canWeekly then "CLAIM" else `{math.min(days, goal)}/{goal}`, UI.GOLD, canWeekly, function()
		if ask("claimWeekly") then
			ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
		end
	end, 1, 140)

	heading(rewards, "TODAY'S QUESTS", 6)
	for i, q in GardenProgress.questsFor(day) do
		local progress = if profile.quests.day == day then profile.quests.progress[q.stat] or 0 else 0
		local claimed = profile.quests.day == day and profile.quests.claimed[q.id] == true
		local done = progress >= q.goal
		local amount = GardenProgress.scaled(profile, q.reward, (q :: any).minutes or 0)
		local r = row(rewards, 62, 6 + i)
		label(r, 14, 6, -170, 24, `{q.label}  -  {short(amount)} coins`)
		bar(r, 14, 38, -180, progress / q.goal, if done then UI.MINT else UI.PINK)
		action(
			r,
			if claimed then "DONE" elseif done then "CLAIM" else `{math.min(progress, q.goal)}/{q.goal}`,
			UI.GOLD,
			done and not claimed,
			function()
				if ask("claimQuest", q.id) then
					ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
				end
			end,
			1,
			140
		)
	end
end

-- STATS ---------------------------------------------------------------------------------------------

local stats = panel("Stats")
renderers.Stats = function()
	clear(stats)
	local best, bestRate = "None yet", -1
	for _, c in profile.creatures do
		local r = GardenRules.rate(c)
		if r > bestRate then
			best, bestRate = ClientState.creatureName(c.s, c.m, c.z), r
		end
	end
	local level = GardenRules.level(profile)
	for i, item in
		{
			{ "Level", tostring(level) },
			{ "Total XP", commas(profile.xp) },
			{ "Coins", commas(profile.coins) },
			{ "Income", `{short(GardenRules.income(profile))} coins/s` },
			{ "Eggs hatched", commas(profile.hatches) },
			{ "Garden Index", `{#profile.index} / {GardenConfig.INDEX_SIZE}` },
			{ "Best creature", best },
			{ "Eggs watered", commas(profile.waters) },
			{ "Likes", commas(profile.likes) },
			{ "Beds", `{profile.bedCount} / {GardenConfig.BEDS.max}` },
			{ "Pen pads", `{profile.penSlots} / {GardenConfig.PEN.max}` },
			{ "Login streak", `{profile.daily.streak} days` },
		}
	do
		local r = row(stats, 42, i)
		label(r, 14, 8, -14, 26, item[1], UI.MUTED).Size = UDim2.new(0.45, -14, 0, 26)
		text({
			Position = UDim2.new(0.45, 0, 0, 8),
			Size = UDim2.new(0.55, -14, 0, 26),
			Text = item[2],
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
	end
	if not player:GetAttribute("ProfileOnline") then
		label(
			row(stats, 44, 99),
			14,
			8,
			-28,
			28,
			"Saving is offline on this server: progress lasts this session only.",
			UI.CORAL
		)
	end
end

-- DASH: Splash Dash ready state, prizes today and prize eggs (GDD T8, T9) -------------------------

local DASH = GardenConfig.DASH
local PRIZE = GardenConfig.egg(DASH.prizeEgg) :: GardenConfig.Egg
local dashPanel = panel("Dash")
local dashLine: TextLabel? = nil
local dashWaiting = false -- a READY press is on its way; the next GardenStatus shows the result

local function dashText(dash: ClientState.DashStatus): (string, string)
	if dash.phase == "countdown" then
		return `Starting in {math.max(0, math.ceil(dash.at - ClientState.now()))}`, `{#dash.ready} players ready`
	elseif dash.phase == "starting" then
		return "Race starting", "Ready up now for the next race."
	elseif dash.phase == "racing" then
		return "Race running", "Ready up now for the next race."
	end
	return `{#dash.ready} / {dash.need} ready`,
		if #Players:GetPlayers() < dash.need
			then `Needs {dash.need} players`
			else `Starts when {dash.need} players are ready`
end

renderers.Dash = function()
	clear(dashPanel)
	local dash = ClientState.status().dash
	local racer = table.find(dash.racers, player.UserId) ~= nil
	local ready = table.find(dash.ready, player.UserId) ~= nil
	local tooFew = #Players:GetPlayers() < dash.need
	local head, detail = dashText(dash)
	local top = row(dashPanel, 96, 1)
	dashLine = label(top, 14, 8, -232, 32, head, UI.LEAF)
	label(top, 14, 44, -232, 44, detail, UI.MUTED).TextWrapped = true
	local readyButton: TextButton
	readyButton = action(
		top,
		if dashWaiting
			then "..."
			elseif racer then "IN RACE"
			elseif ready then "NOT READY"
			elseif tooFew then `NEEDS {dash.need} PLAYERS`
			else "READY",
		if ready then UI.CORAL else UI.LEAF,
		not dashWaiting and not racer and (ready or not tooFew),
		function()
			if dashWaiting then
				return
			end
			dashWaiting = true
			readyButton.Text = "..." -- changed in place, so a gamepad keeps its selection
			if not ask("dashReady") then
				toast("Could not change that right now", UI.CORAL)
			end
		end,
		1,
		200
	)

	local got = GardenProgress.dashPrizesToday(profile, MetaRules.dayOf(ClientState.now()))
	local cap = DASH.prizesPerDay
	para(
		dashPanel,
		if not player:GetAttribute("ProfileOnline")
			then "Saving is off on this server, so prizes are off this visit."
			elseif got >= cap then `{got} / {cap} prizes today. You can still race for fun and coins.`
			else `Prizes today: {got} / {cap}`,
		2,
		if got >= cap then UI.MUTED else UI.LEAF
	)

	heading(dashPanel, "YOUR PRIZE EGGS", 3)
	local held = false
	for i, egg in GardenConfig.EGGS do
		local count = profile.prizeEggs[egg.id] or 0
		if count < 1 then
			continue
		end
		held = true
		local can = GardenRules.canPlantPrize(profile, egg.id)
		local low = GardenRules.level(profile) < egg.level
		local r = row(dashPanel, 96, 3 + i)
		eggIcon(r, egg.id, 12, 14, 64)
		label(r, 72, 8, -232, 30, `{egg.name} x{count}`)
		label(
			r,
			72,
			42,
			-232,
			44,
			if low
				then `Saved for you. Plant it at Level {egg.level}.`
				elseif can then `Free to plant. Grows in {ClientState.clock(egg.grow)}.`
				else "Saved for you until a bed is free.",
			UI.MUTED
		).TextWrapped =
			true
		action(r, if can then "PLANT" elseif low then `LEVEL {egg.level}` else "BEDS FULL", UI.LEAF, can, function()
			local bed = GardenRules.firstEmptyBed(profile)
			if ask("plantPrize", egg.id) then
				ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.8)
				toast(`{egg.name} planted in bed {bed}!`, UI.LEAF)
			else
				toast("Could not plant that egg right now", UI.CORAL)
			end
		end, 1, 140)
	end
	if not held then
		para(dashPanel, `No prize eggs yet. Finish a race first to win a {PRIZE.name}.`, 3, UI.MUTED)
	end

	heading(dashPanel, "HOW TO PLAY", 50)
	para(
		dashPanel,
		`Press READY or use the pad in the plaza. When {DASH.minPlayers} players are ready, a short countdown starts and everyone ready goes to Splash Island.`,
		51
	)
	para(
		dashPanel,
		"Walk and jump to the finish, through every checkpoint. Fall in the water and you go back to your last checkpoint. Players pass through each other.",
		52
	)
	para(
		dashPanel,
		`The first finisher wins a {PRIZE.name}, up to {cap} a day. Every other finisher earns coins. Prize eggs are kept safe until you plant them.`,
		53
	)
end

-- SETTINGS, How to Play -------------------------------------------------------------------------

local setting = panel("Settings")
renderers.Settings = function()
	clear(setting)
	for i, item in
		{
			{ "music", "Music" },
			{ "sfx", "Sound effects" },
			{ "fastHatch", "Fast Hatch (short reveal)" },
			{ "announcements", "Hatch announcements" },
		}
	do
		local r = row(setting, 52, i)
		label(r, 14, 10, -170, 32, item[2])
		local on = (ClientState.settings :: any)[item[1]] == true
		action(r, if on then "ON" else "OFF", if on then UI.LEAF else UI.CORAL, true, function()
			ClientState.set(item[1], not on)
			renderers.Settings()
		end, 1, 120)
	end
	local cards = row(setting, 60, 10)
	cards.BackgroundTransparency = 1
	button(
		{ Size = UDim2.new(0.5, -4, 1, 0), Text = "HOW TO PLAY", BackgroundColor3 = UI.SKY, Parent = cards },
		function()
			openPanel("Help")
		end
	)
	button({
		Position = UDim2.new(0.5, 4, 0, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		Text = "ODDS CARD",
		BackgroundColor3 = UI.LILAC,
		Parent = cards,
	}, function()
		ClientState.oddsEgg = nil
		openPanel("Odds")
	end)
end

local help = panel("Help")
renderers.Help = function()
	clear(help)
	for i, body in
		{
			"Buy eggs at the Egg Cart in the plaza. Each egg is planted in your first empty bed.",
			"Eggs grow in real time, even when you are offline. Water them to grow faster (once a minute).",
			"When an egg is ripe, use Hatch (E, gamepad X or tap). Every creature and its odds are listed on the ODDS card.",
			"Your creatures fill coin pads in your pen. Walk over a pad to collect its coins.",
			"Weather changes every 10 minutes. Sunbeam, Moonfall and Rainbow Shower make Golden, Moonlit and Rainbow creatures more likely.",
			"The Lucky Meter on each egg guarantees its best creature within a set number of hatches.",
			"Visit other gardens to water their eggs and leave a like. Nobody can ever take what you own.",
			"Splash Dash is an optional race for 3 or more players. Open DASH to get ready and to plant prize eggs.",
		}
	do
		local r = row(help, 64, i)
		local t = label(r, 14, 6, -28, 52, body)
		t.TextWrapped = true
		t.Font = Enum.Font.GothamMedium
	end
end

local TITLES = {
	Eggs = "EGG CART",
	Odds = "ODDS",
	Index = "GARDEN INDEX",
	Creatures = "MY CREATURES",
	Locker = "LOCKER",
	Rewards = "REWARDS",
	Dash = "SPLASH DASH",
	Stats = "STATS",
	Settings = "SETTINGS",
	Admin = "ADMIN CATALOGUE",
	Help = "HOW TO PLAY",
}

openPanel = function(name: string)
	for key, f in panels do
		f.Visible = key == name
	end
	panelTitle.Text = TITLES[name] or string.upper(name)
	-- Beside the start menu's buttons when it is open, centred otherwise; nearly full screen on a
	-- phone, where the 18 px text needs the width.
	local narrow = camera.ViewportSize.X < 900
	panelHolder.Size = if narrow then UDim2.fromScale(0.94, 0.92) else UDim2.fromScale(0.64, 0.76)
	panelHolder.Position = if narrow
		then UDim2.fromScale(0.5, 0.5)
		elseif ClientState.menuOpen then UDim2.fromScale(0.64, 0.53)
		else UDim2.fromScale(0.5, 0.53)
	panelHolder.Visible = true
	panels[name].CanvasPosition = Vector2.zero
	renderers[name]()
	selectFirst(panelHolder)
end
ClientState.OpenRequested:Connect(function(name: string)
	if name == "Odds" then
		ClientState.oddsEgg = nil
	end
	openPanel(name)
end)

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

-- Start menu --------------------------------------------------------------------------------------

local menu = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
new("Frame", {
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = Color3.fromRGB(255, 236, 244),
	BorderSizePixel = 0,
	Parent = menu,
}, { new("UIGradient", { Transparency = NumberSequence.new(0.15, 1) }) })
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
	Text = "EGG GARDEN",
	TextColor3 = UI.WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Parent = column,
})
new("UIStroke", { Color = UI.PINK, Thickness = 5, Parent = title })
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 225, 160)),
	Parent = title,
})
local tagline = text({
	Size = UDim2.new(1, 0, 0, 26),
	Text = "Hatch it. Grow it. Collect them all.",
	TextColor3 = UI.LEAF,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = column,
})
new("UIStroke", { Color = UI.WHITE, Thickness = 2, Parent = tagline })

local menuDot: Frame
local MENU_ITEMS = {
	{ "PLAY", "Play", UI.PINK },
	{ "EGGS & ODDS", "Eggs", UI.GOLD },
	{ "INDEX", "Index", UI.LEAF },
	{ "CREATURES", "Creatures", UI.SKY },
	{ "LOCKER", "Locker", UI.LILAC },
	{ "REWARDS", "Rewards", UI.CORAL },
	{ "STATS", "Stats", UI.SKY },
	{ "SETTINGS", "Settings", UI.LILAC },
}
local playButton: TextButton
for i, item in MENU_ITEMS do
	local b = button({
		Size = UDim2.new(1, 0, 0, if i == 1 then 66 else 46),
		Text = item[1],
		BackgroundColor3 = item[3],
		TextColor3 = if item[3] == UI.GOLD then UI.INK else UI.WHITE,
		LayoutOrder = 3 + i,
		Parent = column,
	}, function()
		if item[2] == "Play" then
			hideMenu()
		else
			if item[2] == "Eggs" then
				ClientState.oddsEgg = nil
			end
			openPanel(item[2])
		end
	end)
	if i == 1 then
		playButton = b
		local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Thickness = 4
	end
	if item[2] == "Rewards" then
		menuDot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = UI.GOLD,
			Visible = false,
			Parent = b,
		}, { corner(9), stroke(UI.WHITE, 2) })
	end
end
local menuInfo = text({
	Size = UDim2.new(1, 0, 0, 22),
	Text = "",
	TextColor3 = UI.INK,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 30,
	Parent = column,
})
new("UIStroke", { Color = UI.WHITE, Thickness = 2, Parent = menuInfo })

local function refreshMenu()
	menuDot.Visible = ClientState.rewardsReady(profile)
	menuInfo.Text =
		`Level {GardenRules.level(profile)}  -  {short(profile.coins)} coins  -  Index {#profile.index}/{GardenConfig.INDEX_SIZE}`
end

-- Slow orbit over the plaza: the Great Egg Tree, the cart and the gardens behind them (I4 shot).
local orbitStart = os.clock()
local flying = false
RunService.RenderStepped:Connect(function()
	if not ClientState.menuOpen or flying then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local t = (os.clock() - orbitStart) * 0.035 + 1.9
	local centre = Vector3.new(0, 14, 0)
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(math.cos(t) * 120, 52, math.sin(t) * 120), centre)
end)

-- PLAY: close the menu and fly the camera to the player's own gate, then hand it back.
hideMenu = function()
	ClientState.setMenu(false)
	menu.Visible = false
	panelHolder.Visible = false
	GuiService.SelectedObject = nil
	local plot = player:GetAttribute("Plot")
	local function finish()
		flying = false
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	if type(plot) == "number" and not ClientState.racing then
		flying = true
		local frame = ClientState.plotFrame(plot)
		local goal = CFrame.lookAt(
			frame:PointToWorldSpace(Vector3.new(0, 24, -66)),
			frame:PointToWorldSpace(Vector3.new(0, 2, -4))
		)
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = goal }
		)
		tween:Play()
		tween.Completed:Once(function()
			task.wait(0.4)
			finish()
		end)
	else
		finish()
	end
	ClientState.sound(ClientState.SFX.whoosh, 0.3, nil, 1.1)
	if ClientState.rewardsReady(profile) then
		toast("Rewards are ready! Open REWARDS to claim.", UI.GOLD)
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

-- A round starting takes the player out of any menu: the race needs the camera and the controls.
ClientState.RacingChanged:Connect(function(racing: boolean)
	if racing then
		panelHolder.Visible = false
		confirm.Visible = false
		GuiService.SelectedObject = nil
		if ClientState.menuOpen then
			hideMenu()
		end
	end
end)

-- The cart's Shop prompt (server-side, changes nothing) opens the EGGS panel here.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who == player and (prompt.Name == "Shop" or prompt.ActionText == "Shop") then
		ClientState.oddsEgg = nil
		openPanel("Eggs")
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

local function onProfile()
	profile = ClientState.profile()
	refreshMenu()
	local name = visiblePanel()
	if name and name ~= "Settings" and name ~= "Help" then
		rerender(name)
	end
end
player:GetAttributeChangedSignal("Profile"):Connect(onProfile)
-- Banking changes Coins at 5 Hz; buy buttons follow at most once a second (QA N1).
local coinsPending = false
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if not coinsPending then
		coinsPending = true
		task.delay(1, function()
			coinsPending = false
			onProfile()
		end)
	end
end)

-- Restock countdown and window changes for the open cart panel (1 Hz).
local lastWindow = -1
task.spawn(function()
	while true do
		local status = ClientState.status()
		local name = visiblePanel()
		if name == "Eggs" then
			if status.stockWindow ~= lastWindow and lastWindow ~= -1 then
				renderers.Eggs()
			end
			if restockLabel then
				restockLabel.Text = `Restock in {ClientState.clock(ClientState.left(status.stockLeft))}`
			end
		elseif name == "Dash" and dashLine then
			dashLine.Text = (dashText(status.dash))
		end
		lastWindow = status.stockWindow
		task.wait(1)
	end
end)
-- The Odds panel shows the current weather's table, so it changes only with the weather.
local oddsWeather = ClientState.status().weather
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(function()
	local weather = ClientState.status().weather
	if weather ~= oddsWeather then
		oddsWeather = weather
		if visiblePanel() == "Odds" then
			rerender("Odds")
		end
	end
end)

-- The Dash panel changes with the ready list, the phase and who is in the server.
local dashSeen = ""
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(function()
	local dash = ClientState.status().dash
	local key = `{dash.phase}|{table.concat(dash.ready, ",")}|{table.concat(dash.racers, ",")}|{#Players:GetPlayers()}`
	if key ~= dashSeen or dashWaiting then
		dashSeen = key
		dashWaiting = false
		if visiblePanel() == "Dash" then
			rerender("Dash")
		end
	end
end)

-- Music ---------------------------------------------------------------------------------------------

-- Licensed APM tracks (docs/assets/register.md, GDD H6): two bright acoustic folk tracks in turn,
-- a dreamy harp track while Moonfall is on.
local TRACKS = {
	day = { "rbxassetid://1840007459", "rbxassetid://1839993539" },
	moon = { "rbxassetid://9039607235" },
}
local VOLUME = { day = 0.32, moon = 0.28 }
local music = new("Sound", { Name = "GardenMusic", Volume = 0, Looped = false, Parent = SoundService })
local mode = ""
local trackIndex = 0
local function volume(): number
	return if ClientState.settings.music then (VOLUME :: any)[mode] or 0.32 else 0
end
local function playNext()
	local list = (TRACKS :: any)[mode] or TRACKS.day
	trackIndex = trackIndex % #list + 1
	music.SoundId = list[trackIndex]
	music.TimePosition = 0
	music:Play()
	TweenService:Create(music, TweenInfo.new(1.5), { Volume = volume() }):Play()
end
music.Ended:Connect(playNext)
local function applyMusic()
	local wanted = if ClientState.status().weather == "moonfall" and not ClientState.menuOpen then "moon" else "day"
	if wanted ~= mode then
		mode = wanted
		trackIndex = if mode == "day" then math.random(0, #TRACKS.day - 1) else 0
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
end
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(applyMusic)
ClientState.SettingsChanged:Connect(applyMusic)
ClientState.MenuChanged:Connect(applyMusic)

-- Boot ----------------------------------------------------------------------------------------------

gui.Parent = player:WaitForChild("PlayerGui")
onProfile()
applyMusic()
if gamepad() then
	GuiService.SelectedObject = playButton
end
