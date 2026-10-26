--!strict
-- Neon Spire build mode (GDD K3): tower view with floor cards and the department picker, plaza view
-- with item cards, a ghost on the grid and rotation; mouse, touch and gamepad. Every price, preview
-- and disabled reason comes from SpireProgress.apply on a copy of the own profile, with
-- now = floor(GetServerTimeNow()) and the SpireStatus event (ClientState.preview), so the preview
-- is the server's answer. The client sends ids and cells only.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlazaRules = require(Shared:WaitForChild("PlazaRules"))
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireEconomy = require(Shared:WaitForChild("SpireEconomy"))
local TowerRules = require(Shared:WaitForChild("TowerRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera
local UI, FONT = ClientState.UI, ClientState.FONT
local new, text, button = ClientState.new, ClientState.text, ClientState.button
local short = ClientState.short
local PLAZA = SpireConfig.PLAZA
local CZ = TowerRules.TOWER.z

local profile: any = ClientState.me()

-- Shared helpers ----------------------------------------------------------------------------------------

local function income(p: any): number
	return SpireEconomy.income(p, ClientState.event())
end

-- Text for a price the player cannot afford yet: red, with the time to afford at current income.
local function waitText(cost: number): string
	local t = SpireEconomy.timeToAfford(profile.coins, income(profile), cost)
	return if t then `in {ClientState.clock(t)}` else "earn more first"
end

-- (ok, line): the preview line when the action would succeed, else the reason it cannot.
local function explain(action: string, arg: string, cost: number?): (boolean, string, any)
	local after, ok, code = ClientState.preview(action, arg)
	if ok then
		return true, "", after
	end
	if code == "credits" and cost then
		return false, `Need {short(cost - profile.coins)} more · {waitText(cost)}`, nil
	end
	return false, ClientState.refusal(code), nil
end

local function powerLine(before: any, after: any): string
	local d0, s0, d1, s1 =
		TowerRules.draw(before), TowerRules.supply(before), TowerRules.draw(after), TowerRules.supply(after)
	local gain = income(after) - income(before)
	local sign = if gain >= 0 then "+" else "-"
	local money = `{sign}{short(math.abs(gain))} ¢/s`
	if d0 == d1 and s0 == s1 then
		return money
	end
	return `{money} · Power {d0}/{s0} → {d1}/{s1}`
end

-- GUI ------------------------------------------------------------------------------------------------------

local gui = ClientState.gui("SpireBuild", 6)
gui.Enabled = false

-- View tabs: a column on the left edge, where the HUD's bars sit outside build mode.
local top = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.4, 0),
	Size = UDim2.fromOffset(150, 172),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 8) }) })
ClientState.autoScale(top)
local towerTab: TextButton
local plazaTab: TextButton
local setView: (string) -> ()
local exit: () -> ()
towerTab = button({ Size = UDim2.fromOffset(150, 52), Text = "TOWER", Parent = top }, function()
	setView("tower")
end)
plazaTab = button({ Size = UDim2.fromOffset(150, 52), Text = "PLAZA", Parent = top }, function()
	setView("plaza")
end)
button(
	{ Size = UDim2.fromOffset(150, 52), Text = "BACK", BackgroundColor3 = UI.MAGENTA, Outline = true, Parent = top },
	function()
		exit()
	end
)

-- Right-hand card (floor card, department picker, plaza item info).
local card = ClientState.panel({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.58, 0),
	Size = UDim2.fromOffset(430, 470),
	Parent = gui,
})
ClientState.autoScale(card)
local cardTitle = text({
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -150, 0, 30),
	Text = "",
	FontFace = FONT.display,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = card,
})
local navUp = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -72, 0, 6),
	Size = UDim2.fromOffset(58, 44),
	Text = "▲",
	Outline = true,
	Parent = card,
}, function() end)
local navDown = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 6),
	Size = UDim2.fromOffset(58, 44),
	Text = "▼",
	Outline = true,
	Parent = card,
}, function() end)
local body = new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 56),
	Size = UDim2.new(1, -20, 1, -66),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = UI.CYAN,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = card,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

-- Plaza item cards along the bottom.
local palette = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -24, 0, 128),
	Visible = false,
	Parent = gui,
}, UI.MAGENTA)
local paletteList = new("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 1, -16),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	Parent = palette,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function line(s: string, colour: Color3?, order: number, height: number?): TextLabel
	local t = text({
		Size = UDim2.new(1, -8, 0, height or 22),
		Text = s,
		TextColor3 = colour or UI.WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LayoutOrder = order,
		Parent = body,
	})
	return t
end

local function box(height: number, order: number, accent: Color3?): Frame
	return new("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = UI.STEEL,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = body,
	}, { ClientState.corner(6), ClientState.stroke(accent or UI.CYAN, 1, 0.6) })
end

-- A button with its reason underneath when it cannot succeed (K3: greyed, never hidden).
local function act(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	s: string,
	ok: boolean,
	colour: Color3?,
	onClick: () -> (),
	outline: boolean?
): TextButton
	local b = button({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 44),
		Text = s,
		BackgroundColor3 = colour or UI.CYAN,
		Outline = outline == true,
		Parent = parent,
	}, function()
		if ok then
			onClick()
		end
	end)
	ClientState.enable(b, ok)
	return b
end

-- Keeps a gamepad selection on the same place after a rebuild (Egg Garden pattern).
local function keepSelection(root: Instance, rebuild: () -> ())
	local selected = GuiService.SelectedObject
	local path = {}
	if selected and selected:IsDescendantOf(root) then
		local node: Instance = selected
		while node ~= root do
			local parent = node.Parent :: Instance
			table.insert(path, 1, table.find(parent:GetChildren(), node))
			node = parent
		end
	end
	rebuild()
	if #path > 0 then
		local node: Instance? = root
		for _, i in path do
			node = node and node:GetChildren()[i]
		end
		if node and node:IsA("GuiObject") and node.Selectable then
			GuiService.SelectedObject = node
			return
		end
	end
	if
		ClientState.gamepad()
		and (GuiService.SelectedObject == nil or not GuiService.SelectedObject:IsDescendantOf(gui))
	then
		for _, d in root:GetDescendants() do
			if d:IsA("TextButton") and d.Active then
				GuiService.SelectedObject = d
				return
			end
		end
	end
end

-- Tower view: floor card and department picker -------------------------------------------------------------

local refitting: number? = nil -- floor whose department picker is open
local sellArmed: string? = nil -- "floor:slot" or "item:uid" waiting for the second tap
local sellAt = 0

local function armed(key: string): boolean
	return sellArmed == key and os.clock() - sellAt < 3
end

local function deptPicker(n: number, refit: boolean, order: number)
	for i, d in SpireConfig.DEPTS do
		local action = if refit then "refitFloor" else "buyFloor"
		local arg = if refit then `{n}:{d.id}` else d.id
		local cost = if refit then nil else TowerRules.floorCost(n)
		local ok, why = explain(action, arg, cost)
		local colour = ClientState.DEPT_COLOURS[d.id] or UI.CYAN
		local b = box(110, order + i, colour)
		text({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 24),
			Text = string.upper(d.name),
			TextColor3 = colour,
			FontFace = FONT.display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = b,
		})
		local stats = if d.id == "fusion"
			then `{d.module}: +{SpireConfig.FUSION_SUPPLY[1]} power each · {short(d.cost)} ¢`
			else `{d.module}: {short(d.income)} ¢/s each · draws {d.draw} · {short(d.cost)} ¢`
		text({
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 0, 20),
			Text = stats,
			TextColor3 = UI.MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = b,
		})
		local allowed = TowerRules.deptAllowed(d.id, n)
		local label = if refit then "REFIT" else `BUY FLOOR {n} · {short(cost or 0)}`
		local button_ = act(b, 10, 56, 230, label, ok, colour, function()
			if ClientState.request(action, arg) then
				ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.2)
				refitting = nil
				if not refit then
					ClientState.setMode("tower", n)
				end
			end
		end)
		if not ok and cost and profile.coins < cost and allowed then
			button_.TextColor3 = UI.MAGENTA
		end
		text({
			Position = UDim2.fromOffset(248, 56),
			Size = UDim2.new(1, -258, 0, 44),
			Text = if not allowed then `Unlocks at floor {d.unlock}` else why,
			TextColor3 = UI.MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Parent = b,
		})
	end
end

local function pips(level: number): string
	return string.rep("●", level) .. string.rep("○", 5 - level)
end

local function slotRow(n: number, f: any, dept: any, slot: number, order: number)
	local level = f.m[slot]
	local event = ClientState.event()
	local b = box(118, order, if level >= 5 then UI.AMBER else nil)
	local earn = SpireEconomy.moduleIncome(f.d, level, event) * TowerRules.floorMult(profile, n, event)
	local head = if level == 0
		then `SLOT {slot} · empty`
		elseif f.d == "fusion" then `SLOT {slot} · {pips(level)} · +{SpireConfig.FUSION_SUPPLY[level]} power`
		else `SLOT {slot} · {pips(level)} · {short(earn)} ¢/s`
	text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 22),
		Text = head,
		TextColor3 = if level >= 5 then UI.AMBER else UI.WHITE,
		FontFace = FONT.mono,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = b,
	})
	local arg = `{n}:{slot}`
	local action = if level == 0 then "buyModule" else "upgradeModule"
	local cost = if level < 5 then TowerRules.moduleCost(f.d, level + 1, event) else nil
	local ok, why, after = explain(action, arg, cost)
	if not ok and action == "buyModule" and why == ClientState.refusal("power") then
		why = `Need {TowerRules.draw(profile) + dept.draw - TowerRules.supply(profile)} more power`
	end
	local label = if level >= 5
		then "MAX"
		elseif level == 0 then `BUY {short(cost or 0)}`
		else `UPGRADE {short(cost or 0)}`
	if event == "sale" and level < 5 then
		label ..= " SALE"
	end
	local main = act(b, 10, 32, 210, label, ok, if level == 0 then UI.CYAN else UI.LIME, function()
		if ClientState.request(action, arg) then
			ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1 + 0.15 * (level + 1))
		end
	end)
	if not ok and cost and profile.coins < cost then
		main.TextColor3 = UI.MAGENTA
	end
	local sellNote = ""
	if level > 0 then
		local refund = math.floor(0.5 * f.s[slot] + 1e-9)
		local key = `{n}:{slot}`
		local sellOk, sellWhy = explain("sellModule", arg, nil)
		act(b, 228, 32, 170, if armed(key) then "SURE?" else `SELL +{short(refund)}`, sellOk, UI.MAGENTA, function()
			if armed(key) then
				sellArmed = nil
				ClientState.request("sellModule", arg)
			else
				sellArmed, sellAt = key, os.clock()
				task.delay(3.1, function()
					if sellArmed == key then
						sellArmed = nil
					end
				end)
			end
		end, true)
		if not sellOk then
			sellNote = `  ·  Sell: {sellWhy}`
		end
	end
	text({
		Position = UDim2.fromOffset(10, 82),
		Size = UDim2.new(1, -20, 0, 28),
		Text = (if ok and after then `Preview: {powerLine(profile, after)}` else why) .. sellNote,
		TextColor3 = if ok then UI.LIME else UI.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = b,
	})
end

local function renderTower()
	local floors = #profile.floors
	local n = math.clamp(ClientState.focusFloor or 2, 1, math.min(floors + 1, SpireConfig.MAX_FLOORS))
	ClientState.focusFloor = n
	clear(body)
	ClientState.enable(navUp, n < math.min(floors + 1, SpireConfig.MAX_FLOORS))
	ClientState.enable(navDown, n > 1)
	if n > floors then
		cardTitle.Text = `BUY FLOOR {n}`
		cardTitle.TextColor3 = UI.CYAN
		local cost = TowerRules.floorCost(n) or 0
		line(`{short(cost)} ¢ · pick its department`, if profile.coins >= cost then UI.LIME else UI.MAGENTA, 1)
		deptPicker(n, false, 2)
		return
	end
	local f = profile.floors[n]
	if n == 1 then
		cardTitle.Text = "LOBBY"
		cardTitle.TextColor3 = UI.WHITE
		line(SpireConfig.companyName(profile.company), ClientState.brand(profile.company.trim), 1, 28)
		line("Your lift, logo wall and BUILD terminal. Tap ▲ to go to your floors.", UI.MUTED, 2, 44)
		line(`Tower income {short(income(profile))} ¢/s · {floors} floors`, UI.LIME, 3)
		return
	end
	local dept = SpireConfig.dept(f.d)
	if not dept then
		return
	end
	if refitting == n then
		cardTitle.Text = `REFIT FLOOR {n}`
		cardTitle.TextColor3 = UI.CYAN
		line("Free. Pick the new department.", UI.MUTED, 1)
		act(box(56, 2), 10, 6, 200, "CANCEL", true, UI.MAGENTA, function()
			refitting = nil
			keepSelection(body, renderTower)
		end)
		deptPicker(n, true, 3)
		return
	end
	local event = ClientState.event()
	local colour = ClientState.DEPT_COLOURS[f.d] or UI.CYAN
	cardTitle.Text = `FLOOR {n} · {string.upper(dept.name)}`
	cardTitle.TextColor3 = colour
	local mult = TowerRules.floorMult(profile, n, event)
	local boost = if f.d == "ad" or f.d == "fusion"
		then (if f.d == "ad" then "Boosts the floors above and below" else "Supplies power")
		elseif mult > 1 then `Ad boost +{math.floor((mult - 1) * 100 + 0.5)}%`
		else "No Ad boost (put an Ad Agency next to it)"
	line(
		`{short(SpireEconomy.floorIncome(profile, n, event))} ¢/s · {boost}`,
		if mult > 1 then UI.MAGENTA else UI.MUTED,
		1
	)
	for slot = 1, SpireConfig.SLOTS do
		slotRow(n, f, dept, slot, 1 + slot)
	end
	local empty = TowerRules.moduleCount(profile, n) == 0
	local r = box(56, 10)
	act(r, 10, 6, 200, "REFIT FLOOR", empty, UI.CYAN, function()
		refitting = n
		keepSelection(body, renderTower)
	end, true)
	text({
		Position = UDim2.fromOffset(220, 6),
		Size = UDim2.new(1, -230, 0, 44),
		Text = if empty then "Change this floor's department" else ClientState.refusal("modules"),
		TextColor3 = UI.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = r,
	})
end

-- Plaza view: palette, ghost and placed-item actions ----------------------------------------------------

local chosen: string? = nil -- palette item being placed
local moving: number? = nil -- uid being moved
local picked: number? = nil -- uid of a tapped placed item
local cellX, cellY, rot = 0, 0, 0

local ghostFolder = ClientState.folder("BuildGhost")
local ghost: Part? = nil
local ghostSign: TextLabel? = nil

local function ghostId(): string?
	if chosen then
		return chosen
	end
	local item = moving and PlazaRules.find(profile, moving)
	return item and item.id
end

local function ghostArg(): (string?, string?)
	local id = ghostId()
	if not id then
		return nil, nil
	end
	if moving then
		return "moveItem", `{moving}:{cellX}:{cellY}:{rot}`
	end
	return "placeItem", `{id}:{cellX}:{cellY}:{rot}`
end

-- Keeps the footprint inside the grid after a rotation or a move.
local function clampCell()
	local id = ghostId()
	if not id then
		return
	end
	local w, d = PlazaRules.footprint(id, rot)
	cellX = math.clamp(cellX, 0, PLAZA.w - w)
	cellY = math.clamp(cellY, 0, PLAZA.d - d)
end

local function drawGhost()
	local lot = ClientState.myLot()
	local frame = lot and ClientState.lotFrame(lot)
	local id = ghostId()
	local selectedItem = picked and PlazaRules.find(profile, picked)
	if not frame or (not id and not selectedItem) or ClientState.mode ~= "plaza" then
		if ghost then
			ghost.Transparency = 1
			local sign = ghost:FindFirstChildOfClass("BillboardGui")
			if sign then
				sign.Enabled = false
			end
		end
		return
	end
	if not ghost then
		local g = new("Part", {
			Name = "Ghost",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.ForceField,
			Parent = ghostFolder,
		})
		local sign = new("BillboardGui", {
			Size = UDim2.fromOffset(260, 46),
			StudsOffset = Vector3.new(0, 4, 0),
			AlwaysOnTop = true,
			Parent = g,
		})
		ghostSign = text({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = UI.ASPHALT,
			Text = "",
			Parent = sign,
		})
		ClientState.corner(6).Parent = ghostSign
		ghost = g
	end
	local g = ghost :: Part
	local sign = g:FindFirstChildOfClass("BillboardGui") :: BillboardGui
	sign.Enabled = true
	g.Transparency = 0.1
	local x, y, r, itemId = cellX, cellY, rot, id
	if not id and selectedItem then
		x, y, r, itemId = selectedItem.x, selectedItem.y, selectedItem.r, selectedItem.id
	end
	local w, d = PlazaRules.footprint(itemId :: string, r)
	local c = PlazaRules.itemCentre(itemId :: string, x, y, r)
	g.Size = Vector3.new(w * PLAZA.cell - 0.2, 3, d * PLAZA.cell - 0.2)
	g.CFrame = frame * CFrame.new(c.x, c.y + 1.5, c.z)
	local label = ghostSign :: TextLabel
	if not id then
		g.Color = UI.WHITE
		label.Text = "Selected"
		label.TextColor3 = UI.WHITE
		return
	end
	local action, arg = ghostArg()
	local def = SpireConfig.item(id)
	local ok, why = explain(action :: string, arg :: string, if action == "placeItem" and def then def.cost else nil)
	g.Color = if ok then UI.CYAN else UI.MAGENTA
	label.Text = if ok then "✓ FITS" else `✕ {why}`
	label.TextColor3 = g.Color
end

local function renderPlaza()
	clear(body)
	navUp.Visible, navDown.Visible = false, false
	local id = ghostId()
	local _, total, decor = PlazaRules.counts(profile)
	if id then
		local def = SpireConfig.item(id)
		if not def then
			return
		end
		cardTitle.Text = string.upper(def.name)
		cardTitle.TextColor3 = if def.decor then UI.ICE else UI.MAGENTA
		local action, arg = ghostArg()
		local cost = if moving then nil else def.cost
		local ok, why, after = explain(action :: string, arg :: string, cost)
		line(
			if moving
				then "Moving is free"
				else `{short(def.cost)} ¢ · {if def.decor then "Decor" else `+{def.hype} Hype`}`,
			UI.WHITE,
			1
		)
		local status = if ok and after
			then `✓ Fits here · Hype {PlazaRules.hype(profile)} → {PlazaRules.hype(after)} · {powerLine(
				profile,
				after
			)}`
			else `✕ {why}`
		line(status, if ok then UI.CYAN else UI.MAGENTA, 2, 44)
		local r = box(108, 3)
		act(r, 10, 6, 130, "ROTATE", true, UI.CYAN, function()
			rot = (rot + 1) % 4
			clampCell()
			drawGhost()
			keepSelection(body, renderPlaza)
		end, true)
		local place = act(
			r,
			148,
			6,
			240,
			if moving then "PLACE HERE" else `PLACE {short(def.cost)}`,
			ok,
			UI.CYAN,
			function()
				local a, g = ghostArg()
				if a and g and ClientState.request(a, g) then
					ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.3)
					if moving then
						moving = nil
					end
				end
			end
		)
		if not ok and cost and profile.coins < cost then
			place.TextColor3 = UI.MAGENTA
		end
		act(r, 10, 56, 130, "CANCEL", true, UI.MAGENTA, function()
			chosen, moving = nil, nil
			drawGhost()
			keepSelection(body, renderPlaza)
		end, true)
		line(
			if ClientState.touch
				then "Tap a cell to move the ghost."
				elseif ClientState.gamepad() then "D-pad moves · A place · X rotate · B cancel"
				else "Click a cell · R rotate · click again or Enter to place",
			UI.MUTED,
			4
		)
		return
	end
	local item = picked and PlazaRules.find(profile, picked)
	if item then
		local def = SpireConfig.item(item.id)
		cardTitle.Text = string.upper(if def then def.name else item.id)
		cardTitle.TextColor3 = UI.WHITE
		local refund = math.floor(0.5 * item.paid + 1e-9)
		local r = box(108, 1)
		act(r, 10, 6, 180, "MOVE", true, UI.CYAN, function()
			moving, chosen = item.u, nil
			cellX, cellY, rot = item.x, item.y, item.r
			picked = nil
			GuiService.SelectedObject = nil
			drawGhost()
			renderPlaza()
		end)
		local rotArg = `{item.u}:{item.x}:{item.y}:{(item.r + 1) % 4}`
		local rotOk, rotWhy = explain("moveItem", rotArg, nil)
		act(r, 198, 6, 180, "ROTATE", rotOk, UI.CYAN, function()
			ClientState.request("moveItem", rotArg)
		end, true)
		local key = `item:{item.u}`
		act(r, 10, 56, 180, if armed(key) then "SURE?" else `SELL +{short(refund)}`, true, UI.MAGENTA, function()
			if armed(key) then
				sellArmed = nil
				if ClientState.request("sellItem", tostring(item.u)) then
					picked = nil
				end
			else
				sellArmed, sellAt = key, os.clock()
				task.delay(3.1, function()
					if sellArmed == key then
						sellArmed = nil
						keepSelection(body, renderPlaza)
					end
				end)
			end
			keepSelection(body, renderPlaza)
		end, true)
		act(r, 198, 56, 180, "DONE", true, UI.LIME, function()
			picked = nil
			drawGhost()
			keepSelection(body, renderPlaza)
		end, true)
		if not rotOk then
			line(`Rotate: {rotWhy}`, UI.MUTED, 2)
		end
		return
	end
	cardTitle.Text = "PLAZA"
	cardTitle.TextColor3 = UI.MAGENTA
	line(
		`Hype {PlazaRules.hype(profile)} / {PlazaRules.hypeCap(profile)} · income x{string.format(
			"%.2f",
			PlazaRules.hypeMult(profile)
		)}`,
		UI.MAGENTA,
		1
	)
	line(`Items {total} / {PLAZA.maxItems} · decor {decor} / {PLAZA.maxDecor}`, UI.MUTED, 2)
	line("Pick an item card below, or tap a placed item to move, rotate or sell it.", UI.WHITE, 3, 44)
	line("The two middle columns are the walkway to your door and stay clear.", UI.MUTED, 4, 44)
end

local function renderPalette()
	clear(paletteList)
	local counts = PlazaRules.counts(profile)
	for i, def in SpireConfig.ITEMS do
		local unlocked = PlazaRules.unlocked(profile, def.id)
		local have = counts[def.id] or 0
		local afford = profile.coins >= def.cost
		local b = button({
			Size = UDim2.fromOffset(150, 104),
			Text = "",
			BackgroundColor3 = if def.decor then UI.ICE else UI.MAGENTA,
			Outline = chosen ~= def.id,
			LayoutOrder = i,
			Parent = paletteList,
		}, function()
			chosen, moving, picked = def.id, nil, nil
			rot = 0
			clampCell()
			GuiService.SelectedObject = nil
			drawGhost()
			renderPlaza()
			renderPalette()
		end)
		local fg = if chosen == def.id then UI.ASPHALT else UI.WHITE
		text({ Size = UDim2.new(1, 0, 0, 24), Text = def.name, TextColor3 = fg, FontFace = FONT.display, Parent = b })
		text({
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 20),
			Text = `{short(def.cost)} ¢`,
			TextColor3 = if afford then fg else UI.MAGENTA,
			FontFace = FONT.mono,
			Parent = b,
		})
		local w, d = PlazaRules.footprint(def.id, 0)
		local info = if def.decor then `Decor · {w}x{d}` else `+{def.hype} Hype · {w}x{d}`
		text({
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 18),
			Text = info,
			TextColor3 = fg,
			Parent = b,
		})
		local lock = if unlocked
			then (if def.max then `{have} / {def.max}` else `{have} placed`)
			elseif def.floors then `Unlocks at floor {def.floors}`
			else `Unlocks at level {def.level or 1}`
		text({
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 0, 18),
			Text = lock,
			TextColor3 = if unlocked then fg else UI.AMBER,
			Parent = b,
		})
		if not unlocked then
			b.BackgroundTransparency = 0.6
		end
	end
end

-- Grid overlay (cells, walkway marked) while the plaza view is open.
local gridFolder = ClientState.folder("BuildGrid")
local function drawGrid(on: boolean)
	gridFolder:ClearAllChildren()
	local lot = ClientState.myLot()
	local frame = lot and ClientState.lotFrame(lot)
	if not (on and frame) then
		return
	end
	for x = 0, PLAZA.w - 1 do
		for y = 0, PLAZA.d - 1 do
			local c = PlazaRules.cellCentre(x, y)
			local walk = table.find(PLAZA.walkway, x) ~= nil
			new("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Size = Vector3.new(PLAZA.cell - 0.3, 0.1, PLAZA.cell - 0.3),
				CFrame = frame * CFrame.new(c.x, c.y + 0.08, c.z),
				Color = if walk then UI.AMBER else UI.CYAN,
				Material = Enum.Material.Neon,
				Transparency = if walk then 0.85 else 0.75,
				Parent = gridFolder,
			})
		end
	end
end

-- Rendering ---------------------------------------------------------------------------------------------------

local function render()
	if ClientState.mode == "tower" then
		navUp.Visible, navDown.Visible = true, true
		keepSelection(body, renderTower)
	elseif ClientState.mode == "plaza" then
		keepSelection(body, renderPlaza)
		keepSelection(paletteList, renderPalette)
		drawGhost()
	end
end

local function focus(delta: number)
	if ClientState.mode ~= "tower" then
		return
	end
	local floors = #profile.floors
	local n = math.clamp((ClientState.focusFloor or 2) + delta, 1, math.min(floors + 1, SpireConfig.MAX_FLOORS))
	if n ~= ClientState.focusFloor then
		refitting = nil
		ClientState.setMode("tower", n)
		ClientState.sound(ClientState.SFX.click, 0.12, nil, 1.6 + n * 0.02)
	end
end
navUp.Activated:Connect(function()
	focus(1)
end)
navDown.Activated:Connect(function()
	focus(-1)
end)

setView = function(view: string)
	if ClientState.mode == view then
		return
	end
	chosen, moving, picked, refitting = nil, nil, nil, nil
	ClientState.setMode(view)
end

-- Camera -------------------------------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	if ClientState.mode == "play" then
		return
	end
	local lot = ClientState.myLot()
	local frame = lot and ClientState.lotFrame(lot)
	if not frame then
		return
	end
	local goal
	if ClientState.mode == "tower" then
		local y = TowerRules.floorY(ClientState.focusFloor or 2) + 7
		goal = CFrame.lookAt(
			frame:PointToWorldSpace(Vector3.new(48, y + 20, CZ - 56)),
			frame:PointToWorldSpace(Vector3.new(-6, y, CZ))
		)
	else
		goal = CFrame.lookAt(
			frame:PointToWorldSpace(Vector3.new(0, 70, -8)),
			frame:PointToWorldSpace(Vector3.new(0, 0, -32))
		)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camera.CFrame:Lerp(goal, math.min(1, dt * 6))
end)

-- Pointer, touch and gamepad -------------------------------------------------------------------------------------

local function rayAt(pos: Vector3 | Vector2): Ray
	return camera:ScreenPointToRay(pos.X, pos.Y)
end

-- Grid cell under a screen point (footprint centred on it), or nil off the plaza.
local function cellUnder(pos: Vector3 | Vector2): (number?, number?)
	local lot = ClientState.myLot()
	local frame = lot and ClientState.lotFrame(lot)
	if not frame then
		return nil, nil
	end
	local ray = rayAt(pos)
	local up = frame.UpVector
	local denom = ray.Direction:Dot(up)
	if math.abs(denom) < 1e-4 then
		return nil, nil
	end
	local t = (frame.Position - ray.Origin):Dot(up) / denom
	if t <= 0 then
		return nil, nil
	end
	local l = frame:PointToObjectSpace(ray.Origin + ray.Direction * t)
	return PlazaRules.cellAt({ x = l.X, y = 0, z = l.Z })
end

local function itemAt(x: number, y: number): number?
	local key = x + PLAZA.w * y
	for _, item in profile.plaza.items do
		if table.find(PlazaRules.cells(item.id, item.x, item.y, item.r), key) then
			return item.u
		end
	end
	return nil
end

local function placeGhost()
	local a, g = ghostArg()
	if a and g then
		local ok, why = explain(a, g, nil)
		if ok and ClientState.request(a, g) then
			ClientState.sound(ClientState.SFX.chime, 0.3, nil, 1.3)
			if moving then
				moving = nil
			end
		elseif not ok then
			ClientState.toast(why, UI.MAGENTA)
		end
	end
end

local function moveGhostTo(x: number, y: number)
	local id = ghostId()
	if not id then
		return
	end
	local w, d = PlazaRules.footprint(id, rot)
	local nx, ny = x - (w - 1) // 2, y - (d - 1) // 2
	if nx ~= cellX or ny ~= cellY then
		cellX, cellY = nx, ny
		clampCell()
		drawGhost()
		renderPlaza()
	end
end

local function tapWorld(pos: Vector3 | Vector2)
	if ClientState.mode == "tower" then
		local lot = ClientState.myLot()
		local towers = Workspace:FindFirstChild("SpireClient")
			and (Workspace :: any).SpireClient:FindFirstChild("Towers")
		if not (lot and towers) then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { towers }
		local ray = rayAt(pos)
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
		local node: Instance? = hit and hit.Instance
		while node and node ~= towers do
			if node:GetAttribute("Lot") == lot and node:GetAttribute("Floor") then
				refitting = nil
				ClientState.setMode("tower", node:GetAttribute("Floor") :: number)
				return
			end
			node = node.Parent
		end
	elseif ClientState.mode == "plaza" then
		local x, y = cellUnder(pos)
		if not (x and y) then
			return
		end
		if ghostId() then
			local w, d = PlazaRules.footprint(ghostId() :: string, rot)
			local nx, ny = math.clamp(x - (w - 1) // 2, 0, PLAZA.w - w), math.clamp(y - (d - 1) // 2, 0, PLAZA.d - d)
			if nx == cellX and ny == cellY and not ClientState.touch then
				placeGhost() -- a second click on the ghost places it
			else
				moveGhostTo(x, y)
			end
		else
			picked = itemAt(x, y)
			drawGhost()
			renderPlaza()
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if ClientState.mode == "play" then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.R and not processed then
		if ghostId() then
			rot = (rot + 1) % 4
			clampCell()
			drawGhost()
			renderPlaza()
		end
	elseif (key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter) and not processed then
		placeGhost()
	elseif (key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.E) and not processed then
		focus(1)
	elseif (key == Enum.KeyCode.Down or key == Enum.KeyCode.S or key == Enum.KeyCode.Q) and not processed then
		focus(-1)
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if ClientState.mode ~= "play" and not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		tapWorld(input.Position)
	end
end)

UserInputService.TouchTapInWorld:Connect(function(pos, processed)
	if ClientState.mode ~= "play" and not processed then
		tapWorld(pos)
	end
end)

local lastStick = 0
UserInputService.InputChanged:Connect(function(input, processed)
	if ClientState.mode == "play" then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		focus(if input.Position.Z > 0 then 1 else -1)
	elseif
		input.UserInputType == Enum.UserInputType.MouseMovement
		and not processed
		and ClientState.mode == "plaza"
	then
		local x, y = cellUnder(input.Position)
		if x and y then
			moveGhostTo(x, y)
		end
	elseif
		input.KeyCode == Enum.KeyCode.Thumbstick2
		and math.abs(input.Position.Y) > 0.7
		and os.clock() - lastStick > 0.25
	then
		lastStick = os.clock()
		focus(if input.Position.Y > 0 then 1 else -1)
	end
end)

UserInputService.TouchSwipe:Connect(function(direction, _, processed)
	if ClientState.mode == "tower" and not processed then
		if direction == Enum.SwipeDirection.Up then
			focus(1)
		elseif direction == Enum.SwipeDirection.Down then
			focus(-1)
		end
	end
end)

-- Gamepad: B back or cancel, Y switches view, L1/R1 floors, and with a ghost (no GUI selection)
-- the d-pad moves the cell, A places and X rotates.
local function onPad(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local k = input.KeyCode
	local ghosting = ClientState.mode == "plaza" and ghostId() ~= nil and GuiService.SelectedObject == nil
	if k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.Backspace or k == Enum.KeyCode.Escape then
		if ghostId() or picked then
			chosen, moving, picked = nil, nil, nil
			drawGhost()
			render()
		elseif refitting then
			refitting = nil
			render()
		else
			exit()
		end
		return Enum.ContextActionResult.Sink
	elseif k == Enum.KeyCode.ButtonY then
		setView(if ClientState.mode == "tower" then "plaza" else "tower")
	elseif k == Enum.KeyCode.ButtonR1 then
		focus(1)
	elseif k == Enum.KeyCode.ButtonL1 then
		focus(-1)
	elseif ghosting and k == Enum.KeyCode.ButtonA then
		placeGhost()
	elseif ghosting and k == Enum.KeyCode.ButtonX then
		rot = (rot + 1) % 4
		clampCell()
		drawGhost()
		renderPlaza()
	elseif ghosting and (k == Enum.KeyCode.DPadLeft or k == Enum.KeyCode.DPadRight) then
		cellX += if k == Enum.KeyCode.DPadRight then 1 else -1
		clampCell()
		drawGhost()
		renderPlaza()
	elseif ghosting and (k == Enum.KeyCode.DPadUp or k == Enum.KeyCode.DPadDown) then
		cellY += if k == Enum.KeyCode.DPadUp then 1 else -1
		clampCell()
		drawGhost()
		renderPlaza()
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local PAD_KEYS = {
	Enum.KeyCode.ButtonB,
	Enum.KeyCode.Backspace,
	Enum.KeyCode.Escape,
	Enum.KeyCode.ButtonY,
	Enum.KeyCode.ButtonR1,
	Enum.KeyCode.ButtonL1,
	Enum.KeyCode.ButtonA,
	Enum.KeyCode.ButtonX,
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadRight,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadDown,
}

-- Enter, leave and refresh ------------------------------------------------------------------------------------

local active = false
local walkSpeed = 16
local function enter()
	active = true
	gui.Enabled = true
	ContextActionService:BindActionAtPriority(
		"SpireBuild",
		onPad,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(PAD_KEYS)
	)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		walkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0 -- the camera is away; nothing moves the character by accident
	end
end

exit = function()
	ClientState.setMode("play")
end

local function leave()
	active = false
	gui.Enabled = false
	ContextActionService:UnbindAction("SpireBuild")
	chosen, moving, picked, refitting = nil, nil, nil, nil
	drawGhost()
	drawGrid(false)
	GuiService.SelectedObject = nil
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = walkSpeed
		camera.CameraSubject = humanoid
	end
end

local lastMode = "play"
ClientState.ModeChanged:Connect(function()
	local mode = ClientState.mode
	if mode == "play" then
		if active then
			leave()
		end
		lastMode = mode
		return
	end
	if not active then
		enter()
	end
	ClientState.enable(towerTab, mode ~= "tower")
	ClientState.enable(plazaTab, mode ~= "plaza")
	card.Visible = true
	palette.Visible = mode == "plaza"
	-- Plaza: a shorter card under the Market chip, clear of the palette.
	card.AnchorPoint = if mode == "plaza" then Vector2.new(1, 0) else Vector2.new(1, 0.5)
	card.Position = if mode == "plaza" then UDim2.new(1, -12, 0, 84) else UDim2.new(1, -12, 0.58, 0)
	card.Size = UDim2.fromOffset(430, if mode == "plaza" then 280 else 470)
	if mode ~= lastMode then
		drawGrid(mode == "plaza")
		if mode == "plaza" then
			cellX, cellY = 0, 0
		end
		GuiService.SelectedObject = nil
	end
	lastMode = mode
	render()
end)

-- Profile changes rebuild the open cards at most four times a second.
local pending = false
ClientState.ProfileChanged:Connect(function()
	if pending then
		return
	end
	pending = true
	task.delay(0.25, function()
		pending = false
		profile = ClientState.me()
		if ClientState.mode ~= "play" then
			if picked and not PlazaRules.find(profile, picked) then
				picked = nil
			end
			render()
		end
	end)
end)
-- The Market event changes prices (Flash Sale) and boosts (Neon Night, Data Boom).
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(function()
	if ClientState.mode ~= "play" then
		render()
	end
end)

-- The Terminal's Build prompt (server-side, changes nothing) opens build mode on the own lot.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	local lot = ClientState.myLot()
	local model = lot and ClientState.lotModel(lot)
	if who == player and prompt.Name == "Build" and model and prompt:IsDescendantOf(model) then
		ClientState.setMode("tower")
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
