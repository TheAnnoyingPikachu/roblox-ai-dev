--!strict
-- Egg Garden trade panel (GDD V1; docs/architecture/garden.md 5.1, 6.3), drawn only from `trade`
-- payloads: the invite card, both picks with the server's rate, the fairness line, TRADE, the 10 s
-- hold bar, CONFIRM, CANCEL, the committing spinner, the done card with UNDO, the cancelled card and
-- the four emotes. It never computes a value or a fairness result of its own: `rate` comes from the
-- payload and every outcome from the server. Sends tradeAccept, tradeCancel, tradeConfirm,
-- tradePick <id>, tradeEmote <n> and tradeUndo <id> only. G4: no countdown text but the bar, no
-- pressure words, no sound on the hold.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera
local UI = ClientState.UI
local TRADE = GardenConfig.TRADE
local new, corner, stroke, text, button =
	ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text, ClientState.button

-- Requests go out at least 0.4 s apart, as Menu does: the server refuses a second inside 0.35 s.
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
		if d:IsA("TextButton") and d.Visible and d.AutoButtonColor then
			GuiService.SelectedObject = d
			return
		end
	end
end

local EMOTES = { "NICE!", "<3", "HI!", "NO" }
local REASONS: { [string]: string } = {
	declined = "%s said no this time. That's okay!",
	cancelled = "The trade was cancelled. Nothing changed.",
	expired = "The trade ended quietly. Nothing changed.",
	apart = "You walked apart, so the trade stopped.",
	left = "%s left, so the trade stopped.",
	offline = "Trading needs saving to be on for both of you.",
	unfair = "That trade would not be fair, so it stopped.",
	limit = "One of you has done 3 trades today. More tomorrow!",
	fav = "A favourite creature cannot be traded.",
	missing = "One creature is not there any more, so the trade stopped.",
	failed = "Saving had a hiccup, so nothing changed. Try again in a moment.",
}

-- GUI ---------------------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "GardenTrade",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Small card at the top (invite, asking, done, cancelled).
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.fromOffset(460, 120),
	BackgroundColor3 = UI.CREAM,
	Visible = false,
	Parent = gui,
}, { corner(20) })
local cardStroke = stroke(UI.PINK, 4)
cardStroke.Parent = card
ClientState.autoScale(card)
local cardText = text({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -32, 0, 50),
	Text = "",
	TextWrapped = true,
	Parent = card,
})
local cardButtons = new("Frame", {
	Position = UDim2.new(0, 16, 1, -56),
	Size = UDim2.new(1, -32, 0, 46),
	BackgroundTransparency = 1,
	Parent = card,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
	}),
})
local cardToken = 0

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function showCard(message: string, colour: Color3, buttons: { { any } }, closeAfter: number?)
	cardText.Text = message
	cardStroke.Color = colour
	clear(cardButtons)
	for _, b in buttons do
		button({ Size = UDim2.fromOffset(150, 46), Text = b[1], BackgroundColor3 = b[2], Parent = cardButtons }, b[3])
	end
	card.Size = UDim2.fromOffset(460, if #buttons > 0 then 120 else 72)
	card.Visible = true
	ClientState.pop(card)
	cardToken += 1
	local token = cardToken
	if closeAfter then
		task.delay(closeAfter, function()
			if token == cardToken then
				card.Visible = false
			end
		end)
	end
	selectFirst(card)
end

-- The panel: two columns (mine, theirs), the fairness line, the action row.
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.7, 0.8),
	BackgroundColor3 = UI.PANEL,
	Visible = false,
	Parent = gui,
}, {
	corner(22),
	stroke(UI.AQUA, 4),
	new("UISizeConstraint", { MaxSize = Vector2.new(860, 620), MinSize = Vector2.new(320, 300) }),
})
local panelTitle = text({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -32, 0, 34),
	Text = "TRADE",
	TextColor3 = UI.AQUA,
	Parent = panel,
})
new("UIStroke", { Color = UI.WHITE, Thickness = 3, Parent = panelTitle })
local columns = new("Frame", {
	Position = UDim2.fromOffset(12, 50),
	Size = UDim2.new(1, -24, 1, -190),
	BackgroundTransparency = 1,
	Parent = panel,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }) })
local fairLine = text({
	Position = UDim2.new(0, 16, 1, -136),
	Size = UDim2.new(1, -32, 0, 28),
	Text = "",
	Parent = panel,
})
local emoteRow = new("Frame", {
	Position = UDim2.new(0, 16, 1, -104),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
	Parent = panel,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
	}),
})
for n, label in EMOTES do
	button({ Size = UDim2.fromOffset(86, 36), Text = label, BackgroundColor3 = UI.LILAC, Parent = emoteRow }, function()
		ask("tradeEmote", tostring(n))
	end)
end
local actions = new("Frame", {
	Position = UDim2.new(0, 16, 1, -62),
	Size = UDim2.new(1, -32, 0, 50),
	BackgroundTransparency = 1,
	Parent = panel,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
	}),
})
local holdFill: Frame? = nil
local emotePop = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.75, 0, 0, 52),
	Size = UDim2.fromOffset(120, 44),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.LILAC,
	TextColor3 = UI.WHITE,
	Text = "",
	Visible = false,
	ZIndex = 5,
	Parent = panel,
})
corner(14).Parent = emotePop
stroke(UI.WHITE, 3).Parent = emotePop
local popToken = 0

-- Pick card ---------------------------------------------------------------------------------------

local function preview(parent: Instance, species: string)
	local folder = ReplicatedStorage:FindFirstChild("GardenSpecies")
	local mesh = folder and folder:FindFirstChild(species)
	if not (mesh and (mesh:IsA("BasePart") or mesh:IsA("Model"))) then
		return
	end
	local view = new("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = UI.WHITE,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		Parent = parent,
	}, { corner(10) })
	local copy = mesh:Clone()
	local box: CFrame, size: Vector3
	if copy:IsA("Model") then
		box, size = copy:GetBoundingBox()
	else
		box, size = (copy :: BasePart).CFrame, (copy :: BasePart).Size
	end
	copy:PivotTo(copy:GetPivot() - box.Position)
	copy.Parent = view
	local eye = new("Camera", { FieldOfView = 30, Parent = view })
	eye.CFrame = CFrame.lookAt(Vector3.new(0.45, 0.25, -1).Unit * size.Magnitude * 2, Vector3.zero)
	view.CurrentCamera = eye
end

local function line(parent: Instance, y: number, h: number, s: string, colour: Color3?): TextLabel
	return text({
		Position = UDim2.fromOffset(100, y),
		Size = UDim2.new(1, -108, 0, h),
		Text = s,
		TextColor3 = colour or UI.INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

-- One side's card: the pick (name, rarity, mutation, size, charm, coins/s and a value bar against
-- the other pick's rate) or a waiting note.
local function pickCard(parent: Instance, side: any, other: any, mine: boolean)
	local c = new("Frame", {
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundColor3 = UI.CARD,
		LayoutOrder = 1,
		Parent = parent,
	}, { corner(14), stroke(if side.ready then UI.LEAF else Color3.fromRGB(245, 215, 225), 3) })
	local pick = side.pick
	if type(pick) ~= "table" then
		line(c, 8, 88, if mine then "Pick a creature below" else "Waiting for their pick...", UI.MUTED).TextWrapped =
			true
		return
	end
	preview(c, tostring(pick.s))
	local colour = ClientState.rarityColour(tostring(pick.s))
	line(c, 6, 24, ClientState.creatureName(pick.s, pick.m, pick.z, pick.c, pick.n), colour)
	local bits = { ClientState.rarityName(tostring(pick.s)) }
	local mu, sz = GardenConfig.mutation(tostring(pick.m)), GardenConfig.size(tostring(pick.z))
	if mu and pick.m ~= "normal" then
		table.insert(bits, mu.name)
	end
	if sz and pick.z ~= "normal" then
		table.insert(bits, sz.name)
	end
	local charm = GardenConfig.charm(tostring(pick.c))
	if charm then
		table.insert(bits, charm.name)
	end
	line(c, 32, 18, table.concat(bits, "  -  "), UI.MUTED)
	local rate = tonumber(pick.rate) or 0
	local otherRate = if type(other.pick) == "table" then tonumber(other.pick.rate) or 0 else 0
	line(c, 54, 22, `+{ClientState.short(rate)} coins/s`, UI.LEAF)
	local back = new("Frame", {
		Position = UDim2.fromOffset(100, 82),
		Size = UDim2.new(1, -108, 0, 12),
		BackgroundColor3 = Color3.fromRGB(245, 230, 235),
		Parent = c,
	}, { corner(6) })
	new("Frame", {
		Size = UDim2.fromScale(math.clamp(rate / math.max(rate, otherRate, 1), 0.02, 1), 1),
		BackgroundColor3 = if side.ready then UI.LEAF else UI.AQUA,
		Parent = back,
	}, { corner(6) })
end

-- My picker: own creatures by rate; favourites and the current pick greyed.
local function picker(parent: Instance, side: any)
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -112),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.AQUA,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local creatures = table.clone(ClientState.profile().creatures)
	table.sort(creatures, function(a, b)
		local ra, rb = GardenRules.rate(a), GardenRules.rate(b)
		return if ra == rb then a.id < b.id else ra > rb
	end)
	local picked = if type(side.pick) == "table" then tonumber(side.pick.id) else nil
	for i, c in creatures do
		local blocked = if c.fav then "Favourite" elseif c.id == picked then "Picked" else nil
		local b = button({
			Size = UDim2.new(1, -8, 0, 36),
			LayoutOrder = i,
			Text = `{ClientState.creatureName(c.s, c.m, c.z, c.c, c.n)}  +{ClientState.short(GardenRules.rate(c))}/s{if blocked
				then `  ({blocked})`
				else ""}`,
			BackgroundColor3 = if blocked then UI.GREY else ClientState.rarityColour(c.s),
			TextColor3 = UI.WHITE,
			Parent = list,
		}, function()
			if blocked == nil then
				ask("tradePick", tostring(c.id))
			end
		end)
		b.AutoButtonColor = blocked == nil
	end
end

local function column(side: any, other: any, mine: boolean, state: string)
	local col = new("Frame", {
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = if mine then 1 else 2,
		Parent = columns,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	text({
		Size = UDim2.new(1, 0, 0, 24),
		Text = if mine then "YOU GIVE" else `{string.upper(tostring(side.name or "THEY"))} GIVES`,
		TextColor3 = if mine then UI.PINK else UI.AQUA,
		LayoutOrder = 0,
		Parent = col,
	})
	pickCard(col, side, other, mine)
	if mine and state == "picking" then
		picker(col, side)
	end
end

local function actionButton(label: string, colour: Color3, active: boolean, onClick: () -> ()): TextButton
	local b = button({
		Size = UDim2.fromOffset(170, 50),
		Text = label,
		BackgroundColor3 = if active then colour else UI.GREY,
		Parent = actions,
	}, function()
		if active then
			onClick()
		end
	end)
	b.AutoButtonColor = active
	return b
end

local function cancelButton()
	actionButton("CANCEL", UI.CORAL, true, function()
		ask("tradeCancel")
	end)
end

-- Render -------------------------------------------------------------------------------------------

local function sides(data: any): (any, any)
	if type(data.a) == "table" and data.a.user == player.UserId then
		return data.a, data.b
	end
	return data.b, data.a
end

local function pickName(pick: any): string
	return if type(pick) == "table" then ClientState.creatureName(pick.s, pick.m, pick.z, pick.c, pick.n) else "?"
end

local function closePanel()
	panel.Visible = false
	holdFill = nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
end

local function render(data: any)
	local me, them = sides(data)
	if type(me) ~= "table" or type(them) ~= "table" then
		return
	end
	local state = tostring(data.state)
	local theirName = tostring(them.name or "your friend")
	if state == "proposed" then
		closePanel()
		if me == data.b and not ClientState.settings.trades then
			return -- invites off: no card; the invite expires quietly on the server
		elseif me == data.b then
			showCard(`{theirName} wants to trade with you`, UI.AQUA, {
				{
					"ACCEPT",
					UI.LEAF,
					function()
						ask("tradeAccept")
					end,
				},
				{
					"NO",
					UI.CORAL,
					function()
						ask("tradeCancel")
					end,
				},
			}, TRADE.invite)
		else
			showCard(`Asking {theirName}...`, UI.AQUA, {
				{
					"CANCEL",
					UI.CORAL,
					function()
						ask("tradeCancel")
					end,
				},
			}, TRADE.invite)
		end
		return
	end
	if state == "done" or state == "undone" or state == "cancelled" then
		closePanel()
		ClientState.setTrade(nil)
		if state == "done" then
			local record = data.record
			local id = tostring(data.id or (type(record) == "table" and record.id) or "")
			local got = if type(record) == "table" then pickName(record.got) else pickName(them.pick)
			showCard(`Traded! You got {got}. Changed your mind? UNDO works for 10 minutes.`, UI.LEAF, {
				{
					"UNDO",
					UI.CORAL,
					function()
						if ask("tradeUndo", id) then
							card.Visible = false
						end
					end,
				},
				{
					"OK",
					UI.LEAF,
					function()
						card.Visible = false
					end,
				},
			}, TRADE.undo)
			ClientState.sound(ClientState.SFX.chime, 0.35, nil, 1.6)
		elseif state == "undone" then
			local record = data.record
			local back = if type(record) == "table" then pickName(record.gave) else "your creature"
			showCard(`Undone: {back} came back to you.`, UI.SKY, {}, 5)
		else
			local reason = REASONS[tostring(data.reason)] or REASONS.cancelled
			showCard(string.format(reason, theirName), UI.MUTED, {}, 4)
		end
		return
	end

	-- picking, hold, confirm, committing: the panel.
	card.Visible = false
	cardToken += 1
	ClientState.setTrade(data)
	panelTitle.Text = `TRADE WITH {string.upper(theirName)}`
	local narrow = camera.ViewportSize.X < 900
	panel.Size = if narrow then UDim2.fromScale(0.96, 0.94) else UDim2.fromScale(0.7, 0.8)
	clear(columns)
	clear(actions)
	holdFill = nil
	column(me, them, true, state)
	column(them, me, false, state)
	emoteRow.Visible = state ~= "committing"

	local both = type(me.pick) == "table" and type(them.pick) == "table"
	if both then
		-- Display of the server's two rates against the published rule; the server decides at TRADE.
		local r1, r2 = tonumber(me.pick.rate) or 0, tonumber(them.pick.rate) or 0
		local fair = math.min(r1, r2) >= TRADE.fair * math.max(r1, r2)
		fairLine.Text = if fair
			then "Fair"
			else `That trade would not be fair to {if r1 > r2 then "you" else theirName}`
		fairLine.TextColor3 = if fair then UI.LEAF else UI.CORAL
	else
		fairLine.Text = "Each of you picks one creature"
		fairLine.TextColor3 = UI.MUTED
	end

	if state == "picking" then
		actionButton(if me.ready then "WAITING..." else "TRADE", UI.LEAF, both and not me.ready, function()
			ask("tradeAccept")
		end)
		cancelButton()
	elseif state == "hold" then
		fairLine.Text = "Hold on... either of you can still cancel."
		fairLine.TextColor3 = UI.INK
		local back = new("Frame", {
			Size = UDim2.fromOffset(260, 22),
			BackgroundColor3 = Color3.fromRGB(245, 230, 235),
			Parent = actions,
		}, { corner(11) })
		holdFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.AQUA, Parent = back }, {
			corner(11),
		})
		cancelButton()
	elseif state == "confirm" then
		fairLine.Text = `Give {pickName(me.pick)}, get {pickName(them.pick)}`
		fairLine.TextColor3 = UI.INK
		actionButton(if me.confirmed then "WAITING..." else "CONFIRM", UI.LEAF, not me.confirmed, function()
			ask("tradeConfirm")
		end)
		cancelButton()
	else
		fairLine.Text = "Swapping..."
		fairLine.TextColor3 = UI.MUTED
	end
	panel.Visible = true
	selectFirst(panel)
end

-- The 10 s bar from `at` (server time), nothing else counts down on screen.
RunService.Heartbeat:Connect(function()
	local data = ClientState.tradeState
	local fill = holdFill
	if fill and data and data.state == "hold" then
		local left = (tonumber(data.at) or 0) - ClientState.now()
		fill.Size = UDim2.fromScale(math.clamp(left / TRADE.hold, 0, 1), 1)
	end
	if panel.Visible and data and data.state == "committing" then
		fairLine.Text = `Swapping{string.rep(".", math.floor(os.clock() * 2) % 4)}`
	end
end)

local function showEmote(data: any)
	local n = tonumber(data.emote) or 0
	emotePop.Text = EMOTES[n] or "?"
	emotePop.Visible = true
	ClientState.pop(emotePop)
	ClientState.sound(ClientState.SFX.tick, 0.2, nil, 2.4)
	popToken += 1
	local token = popToken
	task.delay(1.5, function()
		if token == popToken then
			emotePop.Visible = false
		end
	end)
end

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "trade" then
		render(data)
	elseif kind == "tradeEmote" and panel.Visible then
		showEmote(data)
	end
end)

-- A race takes the whole screen; the server cancels the trade when the racer walks apart.
ClientState.RacingChanged:Connect(function(racing: boolean)
	if racing then
		closePanel()
		card.Visible = false
	end
end)
