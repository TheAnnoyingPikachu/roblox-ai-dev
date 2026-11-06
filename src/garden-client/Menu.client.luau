--!strict
-- Egg Garden menus (GDD H2-H6, E5-E6, X1, X3.5; decisions 0008, 0017) on the UI kit (architecture
-- 6.4): the start menu over a camera orbit (logo, PLAY, the newest-species showcase, side column),
-- and one panel at a time: EGGS + ODDS (cart cards, Lucky Meter, published odds), INDEX GRID /
-- MILESTONES, CREATURES PEN / STORAGE / TRADES (place, store, release, love, name, pen pads, gate),
-- LOCKER FENCE / CAN / PADS, REWARDS WEEKLY / MONTHLY / QUESTS (login tracks), STATS, DASH (ready
-- state and prize eggs), PATCH (Petal Catch), SETTINGS + HOW TO PLAY, ADMIN (owner's catalogue,
-- decision 0013), toasts and music by weather. The client only asks; the server decides every
-- outcome through Request(action, arg).

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local HatchRules = require(Shared:WaitForChild("HatchRules"))
local LoginRules = require(Shared:WaitForChild("LoginRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local TradeRules = require(Shared:WaitForChild("TradeRules"))
local WheelRules = require(Shared:WaitForChild("WheelRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera
local UI = ClientState.UI
local ACCENT = ClientState.ACCENT
local new, text = ClientState.new, UiKit.text
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

local function today(): number
	return MetaRules.dayOf(ClientState.now())
end

-- Root GUI and toasts ------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "GardenMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
UiKit.scaleRoot(gui)

local toastKit = UiKit.toast(gui)
local function toast(message: string, colour: Color3?, icon: string?)
	toastKit(message, icon, colour)
end
ClientState.Toasted:Connect(toast)

player:GetAttributeChangedSignal("LastReward"):Connect(function()
	local reward = player:GetAttribute("LastReward")
	if type(reward) == "string" and reward ~= "" then
		toast(string.match(reward, "^(.*)#%d+$") or reward, UI.GOLD, "gift") -- "#n" only makes repeats change
	end
end)

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "notice" and type(data) == "table" and type(data.text) == "string" then
		toast(data.text, UI.CORAL, "heart")
	end
end)

-- Content helpers -----------------------------------------------------------------------------------

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local row = UiKit.row

local function label(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	s: string,
	colour: Color3?
): TextLabel
	return text(parent, s, h - 2, colour or UI.INK, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.new(1, w, 0, h),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function heading(parent: Instance, s: string, order: number, colour: Color3?): TextLabel
	return text(parent, s, 24, colour or UI.LEAF, {
		Size = UDim2.new(1, -10, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Outline = UI.WHITE,
		OutlineThickness = 2,
	})
end

-- A card of wrapped body text, as tall as it needs; 20 px.
local function para(parent: Instance, s: string, order: number, colour: Color3?): TextLabel
	local r = row(parent, 0, order)
	r.AutomaticSize = Enum.AutomaticSize.Y
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		Parent = r,
	})
	return text(r, s, 20, colour or UI.INK, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- Right-aligned button in a row; slot 1 is rightmost, each later slot sits left of the real widths
-- before it, so buttons of different widths never overlap.
local function action(
	parent: Instance,
	s: string,
	colour: Color3,
	active: boolean,
	onClick: () -> (),
	slot: number?,
	width: number?
): TextButton
	local w = width or 120
	local right = if (slot or 1) == 1 then 14 else parent:GetAttribute("ActionRight") or 14
	parent:SetAttribute("ActionRight", right + w + 10)
	local b = UiKit.button(parent, s, colour, "small", w, onClick)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -right, 0.5, -3)
	UiKit.setEnabled(b, active)
	return b
end

-- A holder that grows with its UIGridLayout.
local function gridBox(parent: Instance, order: number, w: number, h: number): Frame
	local holder = new("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	UiKit.grid(holder, w, h)
	return holder
end

-- A sideways-scrolling row of cards (the ODDS egg chooser).
local function cardRow(parent: Instance, order: number, h: number): ScrollingFrame
	return new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, h + 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		LayoutOrder = order,
		Parent = parent,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }),
	})
end

local function eggsUsing(species: string): string
	local names = {}
	local rare, login = false, false
	for _, e in GardenConfig.EGGS do
		if e.price or e.exclusive then
			for _, o in e.odds do
				if o.id == species and o.bp > 0 then
					table.insert(names, (e.name:gsub(" Egg$", "")))
					login = login or e.exclusive ~= nil
				end
			end
			local event = (e :: any).event
			if event and event.s == species then
				rare = true
				table.insert(names, (e.name:gsub(" Egg$", "")))
			end
		end
	end
	if #names == 0 then
		return "Starter Egg"
	end
	return table.concat(names, ", ")
		.. " Egg"
		.. (if rare then ", only in Snowfall, Petal Storm or Thunder" elseif login then " (login reward)" else "")
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
	local r = row(parent, 30 * (#odds + 1) + 14, order)
	local function line(i: number, left: string, right: string, colour: Color3?)
		label(r, 16, 7 + (i - 1) * 30, -150, 26, left, colour)
		text(r, right, 22, colour or UI.INK, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 7 + (i - 1) * 30),
			Size = UDim2.fromOffset(120, 26),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	for i, o in odds do
		total += o.bp
		line(i, nameOf(o.id), `{HatchRules.percent(o.bp)}%`, if colourOf then colourOf(o.id) else nil)
	end
	line(#odds + 1, "Total", `{HatchRules.percent(total)}%`, UI.INK_SOFT)
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

local function eggStroke(id: string): Color3
	local colours = ClientState.EGG_COLOURS[id]
	return if colours then colours[2] else UI.GOLD
end

-- A centred egg disc in a card's icon area.
local function eggIcon(card: UiKit.Card, egg: string, size: number)
	UiKit.eggDisc(card.icon, egg, size, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
end

-- A small corner tag on a card (stock left, LOVED).
local function cornerTag(card: UiKit.Card, s: string, colour: Color3)
	local tag = text(card.icon.Parent, s, 15, UI.WHITE, {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = colour,
		TextScaled = false,
		ZIndex = 3,
		Outline = UI.INK,
		OutlineThickness = 1,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = tag })
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = tag })
end

-- Panels -------------------------------------------------------------------------------------------

type Def = { title: string, accent: Color3, tabs: { string }?, render: (p: UiKit.Panel, tab: string?) -> () }
local DEFS: { [string]: Def } = {}
local open: { name: string, panel: UiKit.Panel }? = nil

local function render()
	local o = open
	if not o then
		return
	end
	o.panel.setFooter(0)
	clear(o.panel.body)
	DEFS[o.name].render(o.panel, o.panel.tab)
end

local function openPanel(name: string, tab: string?)
	local def = DEFS[name]
	if not def then
		return
	end
	local p = UiKit.panel(gui, def.title, def.accent)
	local mine = { name = name, panel = p }
	open = mine
	p.onClose = function()
		if open == mine then
			open = nil
		end
	end
	if def.tabs then
		p.setTabs(def.tabs, render)
		p.setTab(if tab and table.find(def.tabs, tab) then tab else def.tabs[1])
	else
		render()
	end
	UiKit.selectFirst(p.frame)
end

local function visiblePanel(): (string?, string?)
	local o = open
	if o then
		return o.name, o.panel.tab
	end
	return nil, nil
end

-- Rebuilds the open panel and puts a gamepad selection back on the button at the same place.
local function rerender()
	local o = open
	if not o then
		return
	end
	local frame = o.panel.frame
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
	render()
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

-- EGGS: the cart cards and the ODDS tab ----------------------------------------------------------------

local selectedEgg: string? = nil
local restockLabel: TextLabel? = nil

local function eggsTab(p: UiKit.Panel)
	local now = ClientState.now()
	local empty = GardenRules.firstEmptyBed(profile)
	local grid = gridBox(p.body, 1, 160, 200)
	if not (selectedEgg and (GardenConfig.egg(selectedEgg :: string) :: any).price) then
		for _, egg in GardenConfig.EGGS do
			if egg.price then
				selectedEgg = egg.id
				break
			end
		end
	end
	for i, egg in GardenConfig.EGGS do
		if egg.price == nil then
			continue -- the cart sells priced eggs only: never the starter or a login egg (X3.3)
		end
		local price = egg.price :: number
		local unlocked = GardenRules.eggUnlocked(profile, egg.id)
		local left = GardenRules.stockLeft(profile, egg.id, now)
		local c = UiKit.card(grid, "egg", if egg.mutation then UI.GOLD else eggStroke(egg.id))
		c.frame.LayoutOrder = i
		eggIcon(c, egg.id, 92)
		c.name.Text = egg.name
		text(c.name.Parent, `grows in {ClientState.clock(egg.grow)}`, 15, UI.INK_SOFT, {
			Position = UDim2.fromOffset(6, 140),
			Size = UDim2.new(1, -12, 0, 18),
		})
		if not unlocked then
			UiKit.setPill(c, `LEVEL {egg.level}`, UI.GREY)
		else
			UiKit.setPill(c, `{short(price)} coins`, UI.GOLD)
		end
		if left ~= math.huge then
			cornerTag(c, if left > 0 then `{left} left` else "SOLD OUT", if left > 0 then UI.LEAF else UI.CORAL)
		end
		c.select(selectedEgg == egg.id)
		c.frame.Activated:Connect(function()
			ClientState.sound(ClientState.SFX.tick, 0.15, nil, 2.2)
			selectedEgg = egg.id
			rerender()
		end)
	end
	-- NEW BED as the last card, like an empty slot.
	local bedCost = GardenRules.nextBedCost(profile)
	local used = 0
	for i = 1, profile.bedCount do
		if GardenRules.bedState(profile, i, now) ~= "empty" then
			used += 1
		end
	end
	local bed = UiKit.card(grid, "egg", UI.LEAF)
	bed.frame.LayoutOrder = 100
	text(bed.icon, "+", 90, UI.LEAF, { Size = UDim2.fromScale(1, 1), Outline = UI.WHITE, OutlineThickness = 4 })
	bed.name.Text = "New bed"
	text(bed.name.Parent, `Beds in use {used} / {profile.bedCount}`, 15, UI.INK_SOFT, {
		Position = UDim2.fromOffset(6, 140),
		Size = UDim2.new(1, -12, 0, 18),
	})
	local canBed = bedCost ~= nil and profile.coins >= bedCost
	UiKit.setPill(bed, if bedCost then `{short(bedCost)} coins` else "ALL BEDS", if canBed then UI.LEAF else UI.GREY)
	bed.frame.Activated:Connect(function()
		if canBed and ask("buyBed") then
			ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.5)
			toast("New garden bed unlocked!", UI.LEAF, "egg")
		end
	end)

	-- The detail strip for the selected egg: Lucky Meter, stock, BUY and ODDS.
	local egg = GardenConfig.egg(selectedEgg or "") :: GardenConfig.Egg
	local f = p.setFooter(132) :: Frame
	UiKit.eggDisc(f, egg.id, 96, { Position = UDim2.fromOffset(18, 18) })
	local price = egg.price :: number
	local left = GardenRules.stockLeft(profile, egg.id, now)
	label(f, 108, 8, -470, 30, egg.name)
	label(
		f,
		108,
		40,
		-470,
		20,
		`{short(price)} coins  ·  grows in {ClientState.clock(egg.grow)}  ·  level {egg.level}`,
		UI.INK_SOFT
	)
	label(
		f,
		108,
		62,
		-470,
		20,
		if left == math.huge
			then "Always in stock"
			elseif left > 0 then `{left} left this restock`
			else "Sold out until the next restock",
		if left > 0 then UI.LEAF else UI.CORAL
	)
	if egg.mutation then
		label(f, 108, 86, -470, 20, guarantee(egg), UI.LEAF)
	elseif egg.meter and egg.top then
		local pity = profile.pity[egg.id] or 0
		local best = GardenConfig.species(egg.top)
		label(f, 108, 84, -470, 20, `Lucky Meter {pity} / {egg.meter}: {if best then best.name else egg.top}`, UI.LILAC)
		UiKit.bar(
			f,
			{ Position = UDim2.fromOffset(108, 108), Size = UDim2.new(1, -470, 0, 12) },
			pity / egg.meter,
			UI.LILAC
		)
	end
	restockLabel = text(f, "", 18, UI.INK_SOFT, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 10),
		Size = UDim2.fromOffset(340, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local unlocked = GardenRules.eggUnlocked(profile, egg.id)
	local buyText = if not unlocked
		then `LEVEL {egg.level}`
		elseif left <= 0 then "SOLD OUT"
		elseif empty == nil then "BEDS FULL"
		else `BUY {short(price)}`
	local canBuy = unlocked and left > 0 and empty ~= nil and profile.coins >= price
	local buy = UiKit.button(f, buyText, UI.PINK, "large", 210, function()
		if ask("buyEgg", egg.id) then
			ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.8)
			toast(`{egg.name} planted in bed {empty}!`, UI.LEAF, "egg")
		else
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local far = root and (Vector3.new(root.Position.X, 0, root.Position.Z) - ClientState.CART).Magnitude > 25
			toast(
				if far then "Walk to the Egg Cart to buy eggs" else "Could not buy that egg right now",
				UI.CORAL,
				"egg"
			)
		end
	end)
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.Position = UDim2.new(1, -16, 1, -18)
	UiKit.setEnabled(buy, canBuy)
	local odds = UiKit.button(f, "ODDS", UI.LILAC, "large", 110, function()
		ClientState.oddsEgg = egg.id
		p.setTab("ODDS")
	end)
	odds.AnchorPoint = Vector2.new(1, 1)
	odds.Position = UDim2.new(1, -16 - 210 - 12, 1, -18)
end

-- ODDS: one egg (from the cart) or every egg and weather, as the server rolls them.
local function oddsTab(p: UiKit.Panel)
	local body = p.body
	local only = ClientState.oddsEgg :: string?
	local onlyEgg = only and GardenConfig.egg(only)
	local weather = ClientState.status().weather
	local chooser = cardRow(body, 0, 150)
	local all = UiKit.card(chooser, "reward", UI.LILAC)
	all.frame.LayoutOrder = 0
	UiKit.icon(all.icon, "book", 52, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	all.name.Text = "Every egg"
	UiKit.setPill(all, "ALL", UI.LILAC)
	all.select(only == nil)
	all.frame.Activated:Connect(function()
		ClientState.oddsEgg = nil
		rerender()
	end)
	for i, egg in GardenConfig.EGGS do
		if egg.price == nil and egg.exclusive == nil then
			continue
		end
		local c = UiKit.card(chooser, "reward", eggStroke(egg.id))
		c.frame.LayoutOrder = i
		eggIcon(c, egg.id, 52)
		c.name.Text = (egg.name:gsub(" Egg$", ""))
		if egg.exclusive then
			UiKit.setPill(c, "Login reward", UI.CORAL) -- never a price: not sold (X3.3)
		else
			UiKit.setPill(c, short(egg.price :: number), UI.GOLD)
		end
		c.select(only == egg.id)
		c.frame.Activated:Connect(function()
			ClientState.oddsEgg = egg.id
			rerender()
		end)
	end

	local order = 1
	for _, egg in GardenConfig.EGGS do
		if (egg.price == nil and egg.exclusive == nil) or (only and egg.id ~= only) then
			continue
		end
		order += 1
		heading(body, `{string.upper(egg.name)}{if egg.exclusive then " (LOGIN REWARD)" else ""}: CREATURES`, order)
		-- In a rare weather the table is the one with the Moth (V2.4), as the server rolls it.
		order = oddsRows(body, order + 1, HatchRules.oddsFor(egg.id, weather), speciesName, ClientState.rarityColour)
		local event = (egg :: any).event
		if event then
			local moth = GardenConfig.species(event.s)
			para(
				body,
				`{if moth then moth.name else event.s}: {HatchRules.percent(event.bp)}% from this egg only in Snowfall, Petal Storm or Thunder (taken from {speciesName(
					event.from
				)}).`,
				order,
				UI.INK_SOFT
			)
			order += 1
		end
		if egg.mutation then
			heading(body, "MUTATION", order)
			order = oddsRows(body, order + 1, { { id = egg.mutation, bp = 10000 } }, function(id)
				return `{mutationName(id)}, any weather`
			end)
			para(body, guarantee(egg), order, UI.LEAF)
			order += 1
		end
		if egg.meter and egg.top then
			local pity = profile.pity[egg.id] or 0
			local best = GardenConfig.species(egg.top)
			para(
				body,
				`Lucky Meter {pity} / {egg.meter}: {if best then best.name else egg.top} is guaranteed by hatch {egg.meter} of this egg.`,
				order,
				UI.LILAC
			)
			order += 1
		end
	end
	order += 1
	heading(body, "SIZES (EVERY EGG)", order)
	local sizes = {}
	for _, s in GardenConfig.SIZES do
		table.insert(sizes, { id = s.id, bp = s.bp })
	end
	order = oddsRows(body, order + 1, sizes, function(id)
		local s = GardenConfig.size(id)
		return if s then `{s.name}  x{s.mult} coins` else id
	end)
	for _, w in GardenConfig.WEATHERS do
		if onlyEgg and (onlyEgg.mutation or w.id ~= weather) then
			continue
		end
		order += 1
		local now = if w.id == weather then "  (NOW)" else ""
		heading(body, `MUTATIONS IN {string.upper(w.name)}{now}`, order)
		order = oddsRows(body, order + 1, w.mutation, mutationName)
	end
	-- Charm line (V2.1): only while a rare weather is on, in the published numbers.
	local charm = GardenConfig.charmFor(weather)
	if charm then
		order += 1
		para(
			body,
			`{ClientState.weatherName(weather)} now: {charm.name} x{charm.mult} charm on {HatchRules.percent(charm.bp)}% of hatches, on top of the mutation.`,
			order,
			ClientState.CHARM_COLOURS[charm.id]
		)
	end
	if not only then
		order += 1
		heading(body, "WEATHER SCHEDULE (EVERY 10 MINUTES)", order)
		local names = function(id: string): string
			return ClientState.weatherName(id)
		end
		order += 1
		heading(body, "Monday to Friday", order, UI.INK_SOFT)
		order = oddsRows(body, order + 1, GardenConfig.WEATHER_ODDS.weekday, names)
		heading(body, "Saturday and Sunday (Weekend Bloom)", order, UI.INK_SOFT)
		order = oddsRows(body, order + 1, GardenConfig.WEATHER_ODDS.weekend, names)
	end
	para(
		body,
		"These are the exact numbers the server uses. Odds never change except by weather.",
		order + 1,
		UI.INK_SOFT
	)
end

DEFS.Eggs = {
	title = "EGG CART",
	accent = ACCENT.Eggs,
	tabs = { "EGGS", "ODDS" },
	render = function(p, tab)
		if tab == "ODDS" then
			oddsTab(p)
		else
			eggsTab(p)
		end
	end,
}

-- INDEX: species rows of mutation cells (108), and the milestone cards ---------------------------------

local MUTATION_COLOURS = {
	normal = Color3.fromRGB(180, 225, 190),
	golden = Color3.fromRGB(255, 205, 70),
	moonlit = Color3.fromRGB(140, 150, 255),
	rainbow = Color3.fromRGB(255, 140, 200),
	celestial = ClientState.CELESTIAL,
}

local function indexGrid(p: UiKit.Panel)
	local body = p.body
	local found: { [string]: boolean } = {}
	for _, key in profile.index do
		found[key] = true
	end
	local top = row(body, 64, 0)
	label(top, 16, 8, -32, 26, `{#profile.index} / {GardenConfig.INDEX_SIZE} found`, UI.LEAF)
	label(
		top,
		16,
		36,
		-32,
		20,
		`Each new entry: +50 XP and +2% income forever (now +{#profile.index * 2}%)`,
		UI.INK_SOFT
	)
	local lastRarity = ""
	local order = 1
	for _, sp in GardenConfig.SPECIES do
		if sp.rarity ~= lastRarity then
			lastRarity = sp.rarity
			order += 1
			heading(body, string.upper(ClientState.rarityName(sp.id)), order, ClientState.rarityColour(sp.id))
		end
		order += 1
		local any = false
		for _, m in GardenConfig.MUTATIONS do
			any = any or found[`{sp.id}:{m.id}`] == true
		end
		local r = row(body, 104, order)
		local pic = new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(88, 88),
			BackgroundTransparency = 1,
			Parent = r,
		})
		UiKit.viewport(pic, sp.id, not any)
		label(
			r,
			104,
			10,
			-112,
			26,
			if any then sp.name else "???",
			if any then ClientState.rarityColour(sp.id) else UI.INK_SOFT
		)
		text(r, `{sp.rate} coins/s`, 16, UI.INK_SOFT, {
			Position = UDim2.fromOffset(104, 40),
			Size = UDim2.fromOffset(170, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(r, `from {eggsUsing(sp.id)}`, 14, UI.INK_SOFT, {
			Position = UDim2.fromOffset(104, 62),
			Size = UDim2.fromOffset(176, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local cells = new("Frame", {
			Position = UDim2.fromOffset(290, 10),
			Size = UDim2.new(1, -300, 0, 84),
			BackgroundTransparency = 1,
			Parent = r,
		}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
		local kinds = {}
		for _, m in GardenConfig.MUTATIONS do
			if GardenConfig.indexable(sp.id, m.id) then
				table.insert(kinds, m)
			end
		end
		for _, m in kinds do
			local has = found[`{sp.id}:{m.id}`] == true
			local cell = new("Frame", {
				Size = UDim2.new(1 / #kinds, -7, 1, 0),
				BackgroundColor3 = if has then MUTATION_COLOURS[m.id] or UI.MINT else Color3.fromRGB(110, 96, 115),
				Parent = cells,
			}, {
				new("UICorner", { CornerRadius = UDim.new(0, 14) }),
				new("UIStroke", {
					Color = if m.id == "celestial" then UI.GOLD else UI.WHITE,
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			})
			text(cell, if has then m.name else "?", 22, if has then UI.INK else UI.WHITE, {
				Position = UDim2.fromOffset(4, 6),
				Size = UDim2.new(1, -8, 0, 28),
			})
			text(
				cell,
				if has then "Found!" else weathersFor(m.id),
				14,
				if has then UI.INK else Color3.fromRGB(230, 220, 235),
				{
					Position = UDim2.fromOffset(4, 36),
					Size = UDim2.new(1, -8, 0, 42),
				}
			)
		end
	end
	for _, w in GardenConfig.WEATHERS do
		order += 1
		heading(body, `MUTATIONS IN {string.upper(w.name)}`, order)
		order = oddsRows(body, order + 1, w.mutation, mutationName)
	end
	for _, m in GardenConfig.MUTATIONS do
		local fixed = GardenConfig.fixedBy(m.id)
		if fixed then
			order += 1
			para(body, `{mutationName(m.id)}: only from the {fixed.name}, in any weather.`, order, UI.INK_SOFT)
		end
	end
end

-- Milestone CLAIM cards (V4): every milestone with its state.
local function indexMilestones(p: UiKit.Panel)
	local body = p.body
	for i, m in GardenConfig.MILESTONES do
		local claimed = profile.milestones[tostring(m.at)] == true
		local ready = not claimed and #profile.index >= m.at
		local rewards = {}
		if m.coins > 0 then
			table.insert(rewards, `{commas(m.coins)} coins`)
		end
		if m.title then
			table.insert(rewards, `the title "{m.title}"`)
		end
		if m.egg then
			local egg = GardenConfig.egg(m.egg)
			table.insert(rewards, `a free {if egg then egg.name else m.egg}`)
		end
		for _, c in GardenConfig.COSMETICS do
			if c.index == m.at then
				table.insert(rewards, `the {c.name} {c.slot}`)
			end
		end
		local r = row(body, 96, i)
		if ready then
			(r:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = UI.GOLD
		end
		local disc = new("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = if claimed then UI.GREY else UI.GOLD,
			Parent = r,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		text(
			disc,
			tostring(m.at),
			34,
			UI.WHITE,
			{ Size = UDim2.fromScale(1, 1), Outline = UI.INK, OutlineThickness = 2 }
		)
		label(r, 100, 10, -280, 28, `{m.at} Index entries`, if claimed then UI.INK_SOFT else UI.INK)
		text(r, table.concat(rewards, ", "), 18, UI.INK_SOFT, {
			Position = UDim2.fromOffset(100, 42),
			Size = UDim2.new(1, -280, 0, 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		action(
			r,
			if claimed then "CLAIMED" elseif ready then "CLAIM" else `{#profile.index} / {m.at}`,
			UI.GOLD,
			ready,
			function()
				if ask("claimMilestone", tostring(m.at)) then
					ClientState.sound(ClientState.SFX.fanfare, 0.45)
				end
			end,
			1,
			150
		)
	end
end

DEFS.Index = {
	title = "GARDEN INDEX",
	accent = ACCENT.Index,
	tabs = { "GRID", "MILESTONES" },
	render = function(p, tab)
		if tab == "MILESTONES" then
			indexMilestones(p)
		else
			indexGrid(p)
		end
	end,
}

-- ADMIN: every creature in every size, for the owner (decision 0013). Only the owner sees the strip
-- button that opens this; the server decides on GardenConfig.ADMINS ------------------------------------

local adminSize = "normal"

DEFS.Admin = {
	title = "ADMIN CATALOGUE",
	accent = ACCENT.Admin,
	render = function(p)
		local body = p.body
		local top = row(body, 64, 0)
		label(top, 16, 8, -330, 24, "Tap a creature to add it", UI.LEAF)
		label(
			top,
			16,
			36,
			-330,
			20,
			`Storage {GardenRules.storageCount(profile)} / {GardenConfig.STORAGE}`,
			UI.INK_SOFT
		)
		for i = #GardenConfig.SIZES, 1, -1 do
			local size = GardenConfig.SIZES[i]
			action(top, size.name, if size.id == adminSize then UI.PINK else UI.SKY, true, function()
				adminSize = size.id
				rerender()
			end, #GardenConfig.SIZES - i + 1, 92)
		end
		for i, sp in GardenConfig.SPECIES do
			local r = row(body, 132, i)
			local pic = new("TextButton", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(116, 116),
				BackgroundTransparency = 1,
				Text = "",
				Parent = r,
			})
			UiKit.viewport(pic, sp.id)
			-- Tapping the picture plays the species' cry, 2D (U7).
			pic.Activated:Connect(function()
				ClientState.cry(sp.id, 0.5)
			end)
			label(r, 134, 8, -144, 26, sp.name, ClientState.rarityColour(sp.id))
			label(r, 134, 36, -144, 18, ClientState.rarityName(sp.id), UI.INK_SOFT)
			local cells = new("Frame", {
				Position = UDim2.fromOffset(134, 64),
				Size = UDim2.new(1, -146, 0, 52),
				BackgroundTransparency = 1,
				Parent = r,
			}, {
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for k, m in GardenConfig.MUTATIONS do
				if not GardenConfig.indexable(sp.id, m.id) then
					continue
				end
				local rate = GardenRules.rate({ id = 0, s = sp.id, m = m.id, z = adminSize, placed = 0, fav = false })
				local b = UiKit.button(
					cells,
					`{m.name} {short(rate)}/s`,
					MUTATION_COLOURS[m.id] or UI.MINT,
					"small",
					116,
					function()
						local name = ClientState.creatureName(sp.id, m.id, adminSize)
						if ask("adminGrant", `{sp.id}:{m.id}:{adminSize}`) then
							toast(`{name} added to your garden`, UI.LEAF, "paw")
						else
							toast("Not added: your storage may be full", UI.CORAL, "paw")
						end
					end
				)
				b.LayoutOrder = k
			end
		end
	end,
}

-- CREATURES: pen, storage, release, love, name, pen pads, gate, trades -----------------------------

local function confirmRelease(message: string, onYes: () -> ())
	local m = UiKit.modal(gui, "RELEASE?", UI.CORAL, 600, 330)
	para(m.body, message, 1)
	local buttons = new("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = m.body,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UiKit.button(buttons, "KEEP", UI.LEAF, "large", 220, function()
		m.close()
	end).LayoutOrder = 1
	UiKit.button(buttons, "RELEASE", UI.CORAL, "large", 220, function()
		m.close()
		onYes()
	end).LayoutOrder = 2
	UiKit.selectFirst(m.frame) -- KEEP
end

-- NAME card (V5): a TextBox with a live count and validity from GardenRules.validName; OK sends
-- `name "<id>:<text>"` and the tag follows the profile. The server filters; this only asks.
local function openName(c: any)
	local m = UiKit.modal(gui, "NAME", UI.SKY, 640, 360)
	text(m.body, `Name your {ClientState.creatureName(c.s, c.m, c.z, c.c)}`, 24, UI.INK, {
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
	})
	local field = row(m.body, 60, 2)
	local box = new("TextBox", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 28,
		TextColor3 = UI.INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = "A name (letters, numbers, spaces, ' and -)",
		PlaceholderColor3 = UI.GREY,
		ClearTextOnFocus = false,
		Text = c.n or "",
		Parent = field,
	})
	local count = text(m.body, "", 18, UI.INK_SOFT, {
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
	})
	local buttons = new("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = m.body,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local id = tostring(c.id)
	local function send()
		local name = GardenRules.validName(box.Text)
		if name == nil then
			return
		end
		m.close()
		if not ask("name", `{id}:{name}`) then
			toast("That name could not be set right now", UI.CORAL, "paw")
		end
	end
	UiKit.button(buttons, "CANCEL", UI.CORAL, "large", 220, function()
		m.close()
	end).LayoutOrder = 1
	local ok = UiKit.button(buttons, "OK", UI.LEAF, "large", 220, send)
	ok.LayoutOrder = 2
	local function check()
		if #box.Text > GardenConfig.NAME.max then
			box.Text = box.Text:sub(1, GardenConfig.NAME.max)
		end
		local valid = GardenRules.validName(box.Text) ~= nil
		count.Text =
			`{#box.Text} / {GardenConfig.NAME.max}{if valid or box.Text == "" then "" else "  -  not allowed yet"}`
		count.TextColor3 = if valid or box.Text == "" then UI.INK_SOFT else UI.CORAL
		UiKit.setEnabled(ok, valid)
	end
	box:GetPropertyChangedSignal("Text"):Connect(check)
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed and m.frame.Parent then
			task.defer(send)
		end
	end)
	check()
	box:CaptureFocus()
end

local selectedCreature: number? = nil

-- The last 30 trades (V1.7) with UNDO while TradeRules.canUndo allows it.
local function tradeRows(parent: Instance, order: number): number
	heading(parent, "TRADES", order)
	local trades = profile.trades
	if #trades == 0 then
		para(parent, "No trades yet. Stand next to a friend and press TRADE.", order + 1, UI.INK_SOFT)
		return order + 2
	end
	local now = ClientState.now()
	for i = #trades, 1, -1 do
		local t = trades[i]
		order += 1
		local r = row(parent, 76, order)
		local with = Players:GetPlayerByUserId(t.with)
		local who = if with then with.DisplayName else `player {t.with}`
		local ok = TradeRules.canUndo(profile, t.id, now)
		label(r, 16, 8, -180, 26, `{os.date("!%d %b", t.at)}  -  with {who}{if t.undone then "  -  undone" else ""}`)
		label(
			r,
			16,
			38,
			-180,
			28,
			`Gave {ClientState.creatureName(t.gave.s, t.gave.m, t.gave.z, t.gave.c, t.gave.n)}, got {ClientState.creatureName(
				t.got.s,
				t.got.m,
				t.got.z,
				t.got.c,
				t.got.n
			)}`,
			UI.INK_SOFT
		)
		action(r, if t.undone then "UNDONE" elseif ok then "UNDO" else "DONE", UI.CORAL, ok, function()
			if not ask("tradeUndo", t.id) then
				toast("Could not undo right now", UI.CORAL, "swap")
			end
		end, 1, 130)
	end
	return order + 1
end

local function byRate(a: any, b: any): boolean
	local ra, rb = GardenRules.rate(a), GardenRules.rate(b)
	return if ra == rb then a.id < b.id else ra > rb
end

local function creatureCard(parent: Instance, c: any, order: number)
	local colour = ClientState.rarityColour(c.s)
	local card = UiKit.card(parent, "creature", colour)
	card.frame.LayoutOrder = order
	UiKit.viewport(card.icon, c.s)
	card.name.Text = if c.n ~= "" then c.n else ((GardenConfig.species(c.s) :: any) or { name = c.s }).name
	local bits = {}
	local mu, sz = GardenConfig.mutation(c.m), GardenConfig.size(c.z)
	if c.c and c.c ~= "none" then
		table.insert(bits, ClientState.charmName(c.c))
	end
	if sz and c.z ~= "normal" then
		table.insert(bits, sz.name)
	end
	if mu and c.m ~= "normal" then
		table.insert(bits, mu.name)
	end
	if #bits > 0 then
		cornerTag(card, table.concat(bits, " "), if c.m ~= "normal" then UI.GOLD else UI.LILAC)
	end
	if c.fav then
		UiKit.icon(card.icon.Parent, "heart", 30, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			ZIndex = 3,
		})
	end
	UiKit.setPill(card, `+{short(GardenRules.rate(c))}/s`, if c.placed > 0 then UI.LEAF else UI.GREY)
	card.select(selectedCreature == c.id)
	card.frame.Activated:Connect(function()
		ClientState.sound(ClientState.SFX.tick, 0.15, nil, 2.2)
		selectedCreature = c.id
		rerender()
	end)
end

-- The detail strip under the grid: the selected creature and PLACE / STORE, LOVE, NAME, RELEASE.
local function creatureFooter(p: UiKit.Panel, c: any)
	local f = p.setFooter(112) :: Frame
	local pic = new("Frame", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(100, 100),
		BackgroundTransparency = 1,
		Parent = f,
	})
	UiKit.viewport(pic, c.s)
	local name = ClientState.creatureName(c.s, c.m, c.z, c.c, c.n)
	label(f, 118, 10, -128, 30, name, ClientState.rarityColour(c.s))
	local kind = if c.n ~= "" then ClientState.creatureName(c.s, c.m, c.z, c.c) else ClientState.rarityName(c.s)
	local where = if c.placed > 0 then `pad {c.placed}` else "in storage, not earning"
	label(f, 118, 42, -128, 20, `{kind}  ·  {short(GardenRules.rate(c))} coins/s  ·  {where}`, UI.INK_SOFT)
	local id = tostring(c.id)
	local buttons = new("Frame", {
		Position = UDim2.fromOffset(118, 66),
		Size = UDim2.new(1, -128, 0, 40),
		BackgroundTransparency = 1,
		Parent = f,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local place: TextButton
	if c.placed > 0 then
		place = UiKit.button(buttons, "STORE", UI.SKY, "small", 120, function()
			ask("store", id)
		end)
		UiKit.setEnabled(place, GardenRules.storageCount(profile) < GardenConfig.STORAGE)
	else
		place = UiKit.button(buttons, "PLACE", UI.LEAF, "small", 120, function()
			if not ask("place", id) then
				toast("Your pen is full: store a creature or buy a pen slot", UI.CORAL, "paw")
			end
		end)
		UiKit.setEnabled(place, GardenRules.freePad(profile) ~= nil)
	end
	UiKit.button(buttons, if c.fav then "LOVED" else "LOVE", UI.PINK, "small", 120, function()
		ask("favourite", id)
	end).LayoutOrder =
		2
	UiKit.button(buttons, "NAME", UI.SKY, "small", 120, function()
		openName(c)
	end).LayoutOrder = 3
	local value = GardenRules.releaseValue(c)
	local release = UiKit.button(buttons, if c.fav then "LOCKED" else "RELEASE", UI.CORAL, "small", 130, function()
		confirmRelease(`Release {name} to the wild meadow?\n+{commas(value)} coins`, function()
			if ask("release", id) then
				ClientState.sound(ClientState.SFX.whoosh, 0.3, nil, 1.2)
			end
		end)
	end)
	release.LayoutOrder = 4
	UiKit.setEnabled(release, not c.fav)
end

local function creaturesTab(p: UiKit.Panel, pen: boolean)
	local body = p.body
	local list = {}
	for _, c in profile.creatures do
		if (c.placed > 0) == pen then
			table.insert(list, c)
		end
	end
	table.sort(list, byRate)
	local grid = gridBox(body, 1, 160, 180)
	local chosen: any = nil
	for _, c in list do
		if c.id == selectedCreature then
			chosen = c
		end
	end
	chosen = chosen or list[1]
	selectedCreature = if chosen then chosen.id else selectedCreature
	for i, c in list do
		creatureCard(grid, c, i)
	end
	if pen then
		local cost = GardenRules.nextPenCost(profile)
		local pad = UiKit.card(grid, "creature", UI.LEAF)
		pad.frame.LayoutOrder = 1000
		text(pad.icon, "+", 84, UI.LEAF, { Size = UDim2.fromScale(1, 1), Outline = UI.WHITE, OutlineThickness = 4 })
		pad.name.Text = `Pen {#list} / {profile.penSlots}`
		local can = cost ~= nil and profile.coins >= cost
		UiKit.setPill(pad, if cost then `NEW PAD {short(cost)}` else "ALL PADS", if can then UI.LEAF else UI.GREY)
		pad.frame.Activated:Connect(function()
			if can and ask("buyPenSlot") then
				ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.5)
				toast("New pen pad unlocked!", UI.LEAF, "paw")
			end
		end)
	end
	if #list == 0 then
		para(body, if pen then "Hatch an egg to fill your pen!" else "Storage is empty", 0, UI.INK_SOFT)
	end
	local info = row(body, 64, 2)
	label(info, 16, 8, -360, 26, `Income {short(GardenRules.income(profile))} coins/s`, UI.LEAF)
	label(
		info,
		16,
		36,
		-360,
		20,
		if pen then "Garden gate: who can water and like your garden" else `Storage {#list} / {GardenConfig.STORAGE}`,
		UI.INK_SOFT
	)
	if pen then
		for i, g in { "open", "friends", "closed" } do -- right to left
			action(info, string.upper(g), if profile.gate == g then UI.PINK else UI.SKY, profile.gate ~= g, function()
				if ask("setGate", g) then
					toast(`Gate set to {g}`, UI.LEAF, "home")
				end
			end, i, 104)
		end
	end
	if chosen then
		creatureFooter(p, chosen)
	end
end

DEFS.Creatures = {
	title = "MY CREATURES",
	accent = ACCENT.Creatures,
	tabs = { "PEN", "STORAGE", "TRADES" },
	render = function(p, tab)
		if tab == "TRADES" then
			tradeRows(p.body, 1)
		else
			creaturesTab(p, tab ~= "STORAGE")
		end
	end,
}

-- LOCKER: fences, watering cans and pads -------------------------------------------------------------

local function unlockText(c: any): string
	if c.grant then
		return "Login reward"
	elseif c.price then
		return `{short(c.price)} coins`
	elseif c.index then
		return `INDEX {c.index}`
	elseif c.level and c.level > 1 then
		return `LEVEL {c.level}`
	end
	return "Default"
end

local function swatch(parent: Instance, colours: { { number } }): Frame
	local stops = {}
	for j, col in colours do
		table.insert(
			stops,
			ColorSequenceKeypoint.new(if #colours == 1 then 0 else (j - 1) / (#colours - 1), ClientState.colour(col))
		)
	end
	if #stops == 1 then
		table.insert(stops, ColorSequenceKeypoint.new(1, stops[1].Value))
	end
	local disc = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = if #stops == 0 then UI.GREY else UI.WHITE,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", {
			Color = Color3.fromRGB(225, 210, 220), -- visible round a white swatch
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	if #stops >= 2 then
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(stops), Parent = disc })
	end
	return disc
end

local function lockerTab(p: UiKit.Panel, slot: string)
	local grid = gridBox(p.body, 1, 160, 180)
	for i, c in GardenConfig.COSMETICS do
		if c.slot ~= slot then
			continue
		end
		local unlocked = GardenProgress.isUnlocked(profile, c.id)
		local equipped = (profile :: any)[c.slot] == c.id
		local card = UiKit.card(grid, "cosmetic", if equipped then UI.LEAF else UI.LILAC)
		card.frame.LayoutOrder = i
		swatch(card.icon, c.colours)
		card.name.Text = c.name
		local onClick: (() -> ())? = nil
		if equipped then
			UiKit.setPill(card, "EQUIPPED", UI.LEAF)
		elseif unlocked then
			UiKit.setPill(card, "EQUIP", UI.PINK)
			onClick = function()
				if ask("equipCosmetic", c.id) then
					toast(`Equipped {c.name}`, UI.LEAF, "hanger")
				end
			end
		elseif c.price and not c.grant then
			local price = c.price :: number
			UiKit.setPill(card, unlockText(c), if profile.coins >= price then UI.GOLD else UI.GREY)
			if profile.coins >= price then
				onClick = function()
					if ask("buyCosmetic", c.id) then
						toast(`Bought {c.name}!`, UI.LEAF, "hanger")
						ask("equipCosmetic", c.id)
					end
				end
			end
		else
			UiKit.setPill(card, unlockText(c), if c.grant then UI.CORAL else UI.GREY)
			UiKit.icon(card.icon.Parent, "lock", 30, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 6),
				ZIndex = 3,
			})
		end
		card.frame.Activated:Connect(function()
			if onClick then
				ClientState.sound(ClientState.SFX.tick, 0.15, nil, 2.2)
				onClick()
			end
		end)
	end
end

DEFS.Locker = {
	title = "LOCKER",
	accent = ACCENT.Locker,
	tabs = { "FENCE", "CAN", "PADS" },
	render = function(p, tab)
		lockerTab(p, if tab == "CAN" then "can" elseif tab == "PADS" then "pad" else "fence")
	end,
}

-- REWARDS: the weekly and monthly login tracks (X3.5) and today's quests ----------------------------

type Track = { slots: { any }, days: number, claimed: number, ready: number }

-- What the published profile says about a track today; a stale period counts as nothing yet.
local function trackOf(track: string): Track
	local day = today()
	local login: any = profile.login
	local slots = LoginRules.slots(track, day)
	local current = login[track] == LoginRules.periodOf(track, day)
	local days = if current then login[track .. "Days"] else 0
	local claimed = if current then login[track .. "Claimed"] else 0
	local ready = 0
	for i = claimed + 1, #slots do
		if days < slots[i].count then
			break
		end
		ready += 1
	end
	return { slots = slots, days = days, claimed = claimed, ready = ready }
end

local claiming = false
local function claimAll(track: string, n: number)
	if claiming then
		return
	end
	claiming = true
	for _ = 1, n do
		if not ask("claimLogin", track) then -- ask paces the presses 0.4 s apart
			break
		end
		ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
	end
	claiming = false
end

local function loginTab(p: UiKit.Panel, track: string)
	local body = p.body
	local t = trackOf(track)
	local day = today()
	local top = row(body, 72, 1)
	local monday = (MetaRules.weekOf(day) * 7 - 3) * 86400 -- weeks start on Monday, UTC
	local headline = if track == "week"
		then `Week of Monday {tonumber(os.date("!%d", monday))} {os.date("!%b", monday)}`
		else tostring(os.date("!%B", day * 86400))
	label(top, 16, 8, -260, 28, `{headline}  ·  signed in {t.days} day{if t.days == 1 then "" else "s"}`)
	label(
		top,
		16,
		40,
		-260,
		22,
		if track == "week"
			then "Sign in on 5 days this week for the Weekly Egg. Any 5 days count."
			else "Sign in on 18 days this month for the Monthly Egg. Any days count.",
		UI.INK_SOFT
	)
	action(top, if t.ready > 1 then "CLAIM ALL" else "CLAIM", UI.LEAF, t.ready > 0 and not claiming, function()
		task.spawn(claimAll, track, t.ready)
	end, 1, 170)
	local grid = gridBox(body, 2, 96, 176)
	for i, slot in t.slots do
		local claimed = i <= t.claimed
		local ready = not claimed and i <= t.claimed + t.ready
		local stroke = if slot.egg then UI.GOLD elseif ready then UI.LEAF else Color3.fromRGB(240, 222, 230)
		local c = UiKit.card(grid, "reward", stroke)
		c.frame.LayoutOrder = i
		local caption: string
		if slot.egg then
			eggIcon(c, slot.egg, 54)
			caption = ((GardenConfig.egg(slot.egg) :: any) or { name = slot.egg }).name
		elseif slot.cosmetic then
			local cos = GardenConfig.cosmetic(slot.cosmetic)
			local disc = swatch(c.icon, if cos then cos.colours else {})
			disc.Size = UDim2.fromOffset(52, 52)
			local coins = short(GardenProgress.scaled(profile, slot.coins or 0, slot.minutes or 0))
			caption = `{if cos then cos.name else slot.cosmetic}\n+{coins} coins`
		else
			local coin = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(52, 52),
				BackgroundColor3 = UI.GOLD,
				Parent = c.icon,
			}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			UiKit.icon(coin, "coin", 46, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			caption = `{short(GardenProgress.scaled(profile, slot.coins or 0, slot.minutes or 0))} coins`
		end
		c.name.Text = if track == "week" then `Day {slot.count}` else `{slot.count} days`
		c.name.Position = UDim2.fromOffset(4, 66)
		text(c.name.Parent, caption, 16, UI.INK_SOFT, {
			Position = UDim2.fromOffset(4, 88),
			Size = UDim2.new(1, -8, 0, 40),
		})
		local need = slot.count - t.days
		if claimed then
			UiKit.setPill(c, "CLAIMED", UI.GREY)
			UiKit.icon(
				c.icon.Parent,
				"check",
				30,
				{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), ZIndex = 3 }
			)
		elseif ready then
			UiKit.setPill(c, "CLAIM", UI.LEAF)
			if not GuiService.ReducedMotionEnabled then
				local bounce = new("UIScale", { Parent = c.pill })
				TweenService:Create(
					bounce,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Scale = 1.08 }
				):Play()
			end
			c.frame.Activated:Connect(function()
				task.spawn(claimAll, track, 1) -- the server pays the next unclaimed slot
			end)
		else
			UiKit.setPill(c, if need > 0 then `{need} more day{if need == 1 then "" else "s"}` else "Soon", UI.INK_SOFT)
		end
	end
	local egg = GardenConfig.egg(if track == "week" then "weekly" else "monthly")
	if egg then
		local odds = {}
		for _, o in egg.odds do
			local sp = GardenConfig.species(o.id)
			table.insert(odds, `{if sp then sp.name else o.id} {HatchRules.percent(o.bp)}%`)
		end
		para(
			body,
			`{egg.name}: {table.concat(odds, ", ")}. Only from this egg. Plant it free from DASH.`,
			3,
			UI.INK_SOFT
		)
	end
end

local function questsTab(p: UiKit.Panel)
	local day = today()
	for i, q in GardenProgress.questsFor(day) do
		local progress = if profile.quests.day == day then profile.quests.progress[q.stat] or 0 else 0
		local claimed = profile.quests.day == day and profile.quests.claimed[q.id] == true
		local done = progress >= q.goal
		local amount = GardenProgress.scaled(profile, q.reward, (q :: any).minutes or 0)
		local r = row(p.body, 84, i)
		local disc = new("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = if done then UI.LEAF else UI.CORAL,
			Parent = r,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		UiKit.icon(disc, if claimed then "check" else "gift", 48, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		label(r, 86, 10, -270, 28, q.label)
		label(r, 86, 40, -270, 20, `{commas(amount)} coins`, ClientState.edge(UI.GOLD))
		UiKit.bar(
			r,
			{ Position = UDim2.fromOffset(86, 64), Size = UDim2.new(1, -270, 0, 12) },
			progress / q.goal,
			if done then UI.LEAF else UI.PINK
		)
		action(
			r,
			if claimed then "DONE" elseif done then "CLAIM" else `{math.min(progress, q.goal)} / {q.goal}`,
			UI.LEAF,
			done and not claimed,
			function()
				if ask("claimQuest", q.id) then
					ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
				end
			end,
			1,
			150
		)
	end
end

DEFS.Rewards = {
	title = "REWARDS",
	accent = ACCENT.Rewards,
	tabs = { "WEEKLY", "MONTHLY", "QUESTS" },
	render = function(p, tab)
		if tab == "QUESTS" then
			questsTab(p)
		else
			loginTab(p, if tab == "MONTHLY" then "month" else "week")
		end
	end,
}

-- STATS ---------------------------------------------------------------------------------------------

DEFS.Stats = {
	title = "STATS",
	accent = ACCENT.Stats,
	render = function(p)
		local body = p.body
		local best, bestRate = "None yet", -1
		for _, c in profile.creatures do
			local r = GardenRules.rate(c)
			if r > bestRate then
				best, bestRate = ClientState.creatureName(c.s, c.m, c.z, c.c, c.n), r
			end
		end
		local day = today()
		local login: any = profile.login
		local weekDays = if login.week == LoginRules.periodOf("week", day) then login.weekDays else 0
		local grid = gridBox(body, 1, 372, 52)
		for i, item in
			{
				{ "Level", tostring(GardenRules.level(profile)) },
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
				{ "Signed in this week", `{weekDays} day{if weekDays == 1 then "" else "s"}` },
				{ "Title", ClientState.title(profile) or "None yet" },
				{ "Trades today", `{TradeRules.tradesToday(profile, day)} / {GardenConfig.TRADE.perDay}` },
			}
		do
			local r = row(grid, 52, i)
			text(r, item[1], 18, UI.INK_SOFT, {
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(0.45, -16, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			text(r, item[2], 20, UI.INK, {
				Position = UDim2.fromScale(0.45, 0),
				Size = UDim2.new(0.55, -16, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
		if not player:GetAttribute("ProfileOnline") then
			para(body, "Saving is offline on this server: progress lasts this session only.", 99, UI.CORAL)
		end
		tradeRows(body, 100)
	end,
}

-- DASH: Splash Dash ready state, prizes today and the prize eggs (GDD T8, T9, X3.3) --------------------

local DASH = GardenConfig.DASH
local PRIZE = GardenConfig.egg(DASH.prizeEgg) :: GardenConfig.Egg
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

DEFS.Dash = {
	title = "SPLASH DASH",
	accent = ACCENT.Dash,
	render = function(p)
		local body = p.body
		local dash = ClientState.status().dash
		local racer = table.find(dash.racers, player.UserId) ~= nil
		local ready = table.find(dash.ready, player.UserId) ~= nil
		local tooFew = #Players:GetPlayers() < dash.need
		local head, detail = dashText(dash)
		local top = row(body, 96, 1)
		dashLine = label(top, 16, 10, -260, 34, head, UI.LEAF)
		label(top, 16, 50, -260, 24, detail, UI.INK_SOFT)
		local readyButton: TextButton
		readyButton = action(
			top,
			if dashWaiting
				then "..."
				elseif racer then "IN RACE"
				elseif ready then "NOT READY"
				elseif tooFew then `NEEDS {dash.need}`
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
					toast("Could not change that right now", UI.CORAL, "flag")
				end
			end,
			1,
			220
		)

		local got = GardenProgress.dashPrizesToday(profile, today())
		local cap = DASH.prizesPerDay
		para(
			body,
			if not player:GetAttribute("ProfileOnline")
				then "Saving is off on this server, so prizes are off this visit."
				elseif got >= cap then `{got} / {cap} prizes today. You can still race for fun and coins.`
				else `Prizes today: {got} / {cap}`,
			2,
			if not player:GetAttribute("ProfileOnline") then UI.CORAL elseif got >= cap then UI.INK_SOFT else UI.LEAF
		)

		-- Splash Dash, Petal Catch and the login tracks share this store.
		heading(body, "PRIZE EGGS", 3)
		local grid = gridBox(body, 4, 160, 200)
		local held = false
		for i, egg in GardenConfig.EGGS do
			local count = profile.prizeEggs[egg.id] or 0
			if count < 1 then
				continue
			end
			held = true
			local can = GardenRules.canPlantPrize(profile, egg.id)
			local low = GardenRules.level(profile) < egg.level
			local c = UiKit.card(grid, "egg", eggStroke(egg.id))
			c.frame.LayoutOrder = i
			eggIcon(c, egg.id, 92)
			c.name.Text = `{egg.name} x{count}`
			text(
				c.name.Parent,
				if egg.exclusive then "Login reward" else `grows in {ClientState.clock(egg.grow)}`,
				15,
				UI.INK_SOFT,
				{
					Position = UDim2.fromOffset(6, 140),
					Size = UDim2.new(1, -12, 0, 18),
				}
			)
			UiKit.setPill(
				c,
				if can then "PLANT" elseif low then `LEVEL {egg.level}` else "BEDS FULL",
				if can then UI.LEAF else UI.GREY
			)
			c.frame.Activated:Connect(function()
				if not can then
					return
				end
				local bed = GardenRules.firstEmptyBed(profile)
				if ask("plantPrize", egg.id) then
					ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.8)
					toast(`{egg.name} planted in bed {bed}!`, UI.LEAF, "egg")
				else
					toast("Could not plant that egg right now", UI.CORAL, "egg")
				end
			end)
		end
		if not held then
			grid:Destroy()
			para(body, `No prize eggs yet. Finish a race first to win a {PRIZE.name}.`, 4, UI.INK_SOFT)
		end

		heading(body, "HOW TO PLAY", 50)
		para(
			body,
			`Press READY or use the pad in the plaza. When {DASH.minPlayers} players are ready, a short countdown starts and everyone ready goes to Splash Island.`,
			51
		)
		para(
			body,
			"Walk and jump to the finish, through every checkpoint. Fall in the water and you go back to your last checkpoint. Players pass through each other.",
			52
		)
		para(
			body,
			`The first finisher wins a {PRIZE.name}, up to {cap} a day. Every other finisher earns coins. Prize eggs are kept safe until you plant them.`,
			53
		)
	end,
}

-- PATCH: Petal Catch, what it is and where (garden-wheel.md W); the wheel itself is WheelFx's -----------

local WHEEL = GardenConfig.WHEEL

DEFS.Patch = {
	title = "PETAL CATCH",
	accent = ACCENT.Patch,
	render = function(p)
		local body = p.body
		local left = WheelRules.spinsLeft(profile, today())
		para(
			body,
			if player:GetAttribute("ProfileOnline") == false
				then "Saving is off on this server: practice rounds only."
				elseif left <= 0 then `All {WHEEL.spinsPerDay} spins used today. Practice rounds are always open.`
				else `{left} spin{if left == 1 then "" else "s"} left today`,
			1,
			UI.LEAF
		)
		para(
			body,
			`Walk to the Petal Patch under the blossom tree, north-west of the plaza, and use Play at the wheel stand. Catch pink and gold petals for {WHEEL.round} seconds.`,
			2
		)
		para(
			body,
			`A score of {WHEEL.spinAt} spins the wheel; {WHEEL.luckyAt} or more spins the lucky wheel. Egg prizes wait in your prize eggs: plant them from DASH.`,
			3
		)
		heading(body, "WHEEL ODDS (STANDARD / LUCKY)", 4)
		local r = row(body, 30 * (#WHEEL.wedges + 1) + 14, 5)
		for i, w in WHEEL.wedges do
			local egg = GardenConfig.egg(w.id)
			label(r, 16, 7 + (i - 1) * 30, -280, 26, if egg then egg.name else "Coins")
			text(r, `{HatchRules.percent(w.standard)}%   /   {HatchRules.percent(w.lucky)}%`, 22, UI.INK, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, 7 + (i - 1) * 30),
				Size = UDim2.fromOffset(260, 26),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
	end,
}

-- SETTINGS and HOW TO PLAY -----------------------------------------------------------------------------

local HELP = {
	"Buy eggs at the Egg Cart in the plaza. Each egg is planted in your first empty bed.",
	"Eggs grow in real time, even when you are offline. Water them to grow faster (once a minute).",
	"When an egg is ripe, use Hatch (E, gamepad X or tap). Every creature and its odds are listed on the ODDS card.",
	"Your creatures fill coin pads in your pen. Walk over a pad to collect its coins.",
	"Weather changes every 10 minutes. Sunbeam, Moonfall and Rainbow Shower make Golden, Moonlit and Rainbow creatures more likely.",
	"The Lucky Meter on each egg guarantees its best creature within a set number of hatches.",
	"Visit other gardens to water their eggs and leave a like. Nobody can ever take what you own.",
	"Sign in on any 5 days of a week for the Weekly Egg, and on 18 days of a month for the Monthly Egg. Missing a day costs nothing. Claim them in REWARDS.",
	"Splash Dash is an optional race for 3 or more players. Open DASH to get ready and to plant prize eggs.",
	"Snowfall, Petal Storm and Thunder are rare weathers: creatures hatched then can carry a Frosted, Blooming or Stormy charm, and the Lantern Moth appears.",
	"Trading: stand next to a Roblox friend and press TRADE to swap one creature for one. Both of you press TRADE, wait 10 seconds, then CONFIRM. Either of you can undo for 10 minutes.",
	"Name a creature from CREATURES with NAME. Favourite one with LOVE and it follows you around.",
}

DEFS.Settings = {
	title = "SETTINGS",
	accent = ACCENT.Settings,
	tabs = { "GAME", "HOW TO PLAY" },
	render = function(p, tab)
		local body = p.body
		if tab == "HOW TO PLAY" then
			for i, s in HELP do
				para(body, s, i)
			end
			return
		end
		for i, item in
			{
				{ "music", "Music" },
				{ "sfx", "Sound effects" },
				{ "fastHatch", "Fast Hatch (short reveal)" },
				{ "announcements", "Hatch announcements" },
				{ "followers", "Followers (favourite pets walk beside players)" },
				{ "trades", "Trade invites from friends" },
			}
		do
			local r = row(body, 64, i)
			label(r, 16, 16, -170, 30, item[2])
			local on = (ClientState.settings :: any)[item[1]] == true
			action(r, if on then "ON" else "OFF", if on then UI.LEAF else UI.CORAL, true, function()
				ClientState.set(item[1], not on)
				rerender()
			end, 1, 120)
		end
		local r = row(body, 64, 10)
		label(r, 16, 16, -200, 30, "Every egg's odds, sizes and weathers")
		action(r, "ODDS CARD", UI.GOLD, true, function()
			ClientState.oddsEgg = nil
			openPanel("Eggs", "ODDS")
		end, 1, 170)
	end,
}

ClientState.OpenRequested:Connect(function(name: string)
	if name == "Odds" then
		ClientState.oddsEgg = nil
		openPanel("Eggs", "ODDS")
	elseif name == "Help" then
		openPanel("Settings", "HOW TO PLAY")
	else
		openPanel(name)
	end
end)

-- Start menu --------------------------------------------------------------------------------------

local hideMenu: () -> ()
local loaded = false

-- The showcase lists the newest species in SPECIES order: those only an exclusive egg hatches and
-- the weather-only ones (X1.3; v0.5: the six login exclusives and the Moth).
local function newestSpecies(): { string }
	local out = {}
	for _, sp in GardenConfig.SPECIES do
		local newest = false
		for _, egg in GardenConfig.EGGS do
			local event = (egg :: any).event
			if event and event.s == sp.id then
				newest = true
			end
			if egg.exclusive then
				for _, o in egg.odds do
					newest = newest or (o.id == sp.id and o.bp > 0)
				end
			end
		end
		if newest then
			table.insert(out, sp.id)
		end
	end
	return out
end

local start = UiKit.startMenu(gui, function()
	hideMenu()
end, {
	{
		icon = "book",
		label = "INDEX",
		onClick = function()
			openPanel("Index")
		end,
	},
	{
		icon = "hanger",
		label = "LOCKER",
		onClick = function()
			openPanel("Locker")
		end,
	},
	{
		icon = "gift",
		label = "REWARDS",
		onClick = function()
			openPanel("Rewards")
		end,
	},
	{
		icon = "chart",
		label = "STATS",
		onClick = function()
			openPanel("Stats")
		end,
	},
	{
		icon = "cog",
		label = "SETTINGS",
		onClick = function()
			openPanel("Settings")
		end,
	},
})
start.showcase(newestSpecies())

local function milestoneReady(p: any): boolean
	for _, m in GardenConfig.MILESTONES do
		if #p.index >= m.at and p.milestones[tostring(m.at)] ~= true then
			return true
		end
	end
	return false
end

local function refreshMenu()
	loaded = type(player:GetAttribute("Profile")) == "string"
	start.play.Text = if loaded then "PLAY" else "LOADING..."
	UiKit.setEnabled(start.play, loaded)
	start.setBadge("REWARDS", if loaded and ClientState.rewardsCount(profile) > 0 then 0 else nil)
	start.setBadge("INDEX", if loaded and milestoneReady(profile) then 0 else nil)
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

-- PLAY: send `play` (the server moves the character to its gate) and fly the camera there, then
-- hand it back to the character (architecture 4.7, 6.4).
hideMenu = function()
	if not loaded then
		return
	end
	ClientState.setMenu(false)
	start.frame.Visible = false
	local o = open
	if o then
		o.panel.close()
	end
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
	if not ClientState.racing then
		task.spawn(ask, "play")
	end
	if type(plot) == "number" and not ClientState.racing then
		flying = true
		UiKit.flyTo(camera, camera.CFrame, ClientState.gateLook(plot), 1.6, function()
			task.delay(0.3, finish)
		end)
	else
		finish()
	end
	ClientState.sound(ClientState.SFX.whoosh, 0.3, nil, 1.1)
end

ClientState.MenuChanged:Connect(function(isOpen: boolean)
	if isOpen and not start.frame.Visible then
		orbitStart = os.clock()
		start.frame.Visible = true
		local o = open
		if o then
			o.panel.close()
		end
		UiKit.selectFirst(start.frame)
	end
end)

-- A round starting takes the player out of any menu: the race needs the camera and the controls.
ClientState.RacingChanged:Connect(function(racing: boolean)
	if racing then
		local o = open
		if o then
			o.panel.close()
		end
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

local greeted = false
local function onProfile()
	profile = ClientState.profile()
	refreshMenu()
	if loaded and not greeted then
		greeted = true
		local n = LoginRules.claimable(profile, today())
		if n > 0 then
			toast("Login reward ready!", UI.GOLD, "gift")
		end
	end
	local name, tab = visiblePanel()
	if name and name ~= "Settings" and not (name == "Eggs" and tab == "ODDS") then
		rerender()
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

-- Restock countdown and window changes for the open cart tab (1 Hz).
local lastWindow = -1
task.spawn(function()
	while true do
		local status = ClientState.status()
		local name, tab = visiblePanel()
		if name == "Eggs" and tab == "EGGS" then
			if status.stockWindow ~= lastWindow and lastWindow ~= -1 then
				rerender()
			end
			local l = restockLabel
			if l and l.Parent then
				l.Text = `Restock in {ClientState.clock(ClientState.left(status.stockLeft))}`
			end
		elseif name == "Dash" and dashLine then
			(dashLine :: TextLabel).Text = (dashText(status.dash))
		end
		lastWindow = status.stockWindow
		task.wait(1)
	end
end)
-- The ODDS tab shows the current weather's table, so it changes only with the weather.
local oddsWeather = ClientState.status().weather
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(function()
	local weather = ClientState.status().weather
	if weather ~= oddsWeather then
		oddsWeather = weather
		local name, tab = visiblePanel()
		if name == "Eggs" and tab == "ODDS" then
			rerender()
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
			rerender()
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
UiKit.selectFirst(start.frame)
