--!strict
-- Egg Garden trade panel (GDD V1, X1.4; docs/architecture/garden.md 5.1, 6.3, 6.4), drawn only from
-- `trade` payloads on the UI kit: the invite card, both picks with the server's rate, the fairness
-- line, TRADE, the 10 s hold bar, CONFIRM, CANCEL, the committing spinner, the done card with UNDO,
-- the cancelled card and the four emotes. It never computes a value or a fairness result of its own:
-- `rate` comes from the payload and every outcome from the server. Sends tradeAccept, tradeCancel,
-- tradeConfirm, tradePick <id>, tradeEmote <n> and tradeUndo <id> only. G4: no countdown text but the
-- bar, no pressure words, no sound on the hold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local UI = ClientState.UI
local TRADE = GardenConfig.TRADE
local ACCENT = ClientState.ACCENT.Trade
local new, text = ClientState.new, UiKit.text

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

local EMOTES = { { "NICE!", "check" }, { "<3", "heart" }, { "HI!", "paw" }, { "NO", "lock" } }
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

local gui = new("ScreenGui", {
	Name = "GardenTrade",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
UiKit.scaleRoot(gui)

-- Small card near the top (invite, asking, done, cancelled) ------------------------------------------

local card: UiKit.Panel? = nil
local cardToken = 0

local function hideCard()
	local c = card
	card = nil
	if c then
		c.close()
	end
end

local function showCard(message: string, colour: Color3, buttons: { { any } }, closeAfter: number?)
	hideCard()
	local c = UiKit.modal(gui, "TRADE", colour, 620, if #buttons > 0 then 300 else 220, false)
	c.frame.AnchorPoint = Vector2.new(0.5, 0)
	c.frame.Position = UDim2.new(0.5, 0, 0, 150)
	card = c
	text(c.body, message, 26, UI.INK, { Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 1 })
	if #buttons > 0 then
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = c.body,
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 16),
			}),
		})
		for _, b in buttons do
			UiKit.button(row, b[1], b[2], "large", 200, b[3])
		end
	end
	cardToken += 1
	local token = cardToken
	if closeAfter then
		task.delay(closeAfter, function()
			if token == cardToken then
				hideCard()
			end
		end)
	end
	UiKit.selectFirst(c.frame)
end

-- The panel ------------------------------------------------------------------------------------------

local panel: UiKit.Panel? = nil
local holdFill: Frame? = nil
local fairLine: TextLabel? = nil

local function closePanel()
	local p = panel
	panel, holdFill, fairLine = nil, nil, nil
	if p and p.frame.Parent then
		p.onClose = nil -- closed by the trade's own state, not by the player: no cancel
		p.close()
	end
end

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- One side's card: the pick (name, rarity, mutation, size, charm, coins/s and a value bar against
-- the other pick's rate) or a waiting note.
local function pickCard(parent: Instance, side: any, other: any, mine: boolean)
	local c = UiKit.row(parent, 100, 2)
	if side.ready then
		(c:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = UI.LEAF
	end
	local pick = side.pick
	if type(pick) ~= "table" then
		text(c, if mine then "Pick a creature below" else "Waiting for their pick...", 24, UI.INK_SOFT, {
			Size = UDim2.fromScale(1, 1),
		})
		return
	end
	local pic = new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		Parent = c,
	})
	UiKit.viewport(pic, tostring(pick.s))
	local function line(y: number, h: number, s: string, colour: Color3?)
		text(c, s, h - 2, colour or UI.INK, {
			Position = UDim2.fromOffset(100, y),
			Size = UDim2.new(1, -108, 0, h),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	line(
		6,
		28,
		ClientState.creatureName(pick.s, pick.m, pick.z, pick.c, pick.n),
		ClientState.rarityColour(tostring(pick.s))
	)
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
	line(34, 20, table.concat(bits, "  ·  "), UI.INK_SOFT)
	local rate = tonumber(pick.rate) or 0
	local otherRate = if type(other.pick) == "table" then tonumber(other.pick.rate) or 0 else 0
	line(56, 24, `+{ClientState.short(rate)} coins/s{if side.ready then "  ·  Ready!" else ""}`, UI.LEAF)
	UiKit.bar(c, {
		Position = UDim2.fromOffset(100, 82),
		Size = UDim2.new(1, -114, 0, 10),
	}, math.clamp(rate / math.max(rate, otherRate, 1), 0.02, 1), if side.ready then UI.LEAF else UI.AQUA)
end

-- My picker, under my pick: own creatures by rate as cards; favourites and the current pick greyed.
local function picker(col: Instance, side: any)
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -(24 + 8 + 100 + 8)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = ACCENT,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		LayoutOrder = 3,
		Parent = col,
	})
	-- The kit's 160 x 180 cards at 0.8, so two fit side by side in a column.
	local grid = new("Frame", { Size = UDim2.fromScale(1.25, 0), BackgroundTransparency = 1, Parent = list })
	new("UIScale", { Scale = 0.8, Parent = grid })
	UiKit.grid(grid, 160, 180)
	local creatures = table.clone(ClientState.profile().creatures)
	table.sort(creatures, function(a, b)
		local ra, rb = GardenRules.rate(a), GardenRules.rate(b)
		return if ra == rb then a.id < b.id else ra > rb
	end)
	local picked = if type(side.pick) == "table" then tonumber(side.pick.id) else nil
	for i, c in creatures do
		local blocked = if c.fav then "Favourite" elseif c.id == picked then "Picked" else nil
		local cc = UiKit.card(grid, "creature", ClientState.rarityColour(c.s))
		cc.frame.LayoutOrder = i
		UiKit.viewport(cc.icon, c.s)
		cc.name.Text = ClientState.creatureName(c.s, c.m, c.z, c.c, c.n)
		UiKit.setPill(
			cc,
			blocked or `+{ClientState.short(GardenRules.rate(c))}/s`,
			if blocked then UI.GREY else UI.LEAF
		)
		cc.select(c.id == picked)
		cc.frame.Activated:Connect(function()
			if blocked == nil then
				ClientState.sound(ClientState.SFX.tick, 0.15, nil, 2.2)
				ask("tradePick", tostring(c.id))
			end
		end)
	end
end

local function column(parent: Instance, side: any, other: any, mine: boolean, state: string)
	local col = new("Frame", {
		Size = UDim2.new(0.5, -8, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = if mine then 1 else 2,
		Parent = parent,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	text(
		col,
		if mine then "YOU GIVE" else `{string.upper(tostring(side.name or "THEY"))} GIVES`,
		24,
		if mine then UI.PINK else UI.AQUA,
		{
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 1,
			Outline = UI.WHITE,
			OutlineThickness = 2,
		}
	)
	pickCard(col, side, other, mine)
	if mine and state == "picking" then
		picker(col, side)
	end
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
			ClientState.setTrade(data) -- the CREATURES invite dot (Hud)
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
							hideCard()
						end
					end,
				},
				{
					"OK",
					UI.LEAF,
					function()
						hideCard()
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
			showCard(string.format(reason, theirName), UI.INK_SOFT, {}, 4)
		end
		return
	end

	-- picking, hold, confirm, committing: the panel.
	hideCard()
	ClientState.setTrade(data)
	local p = panel
	if not (p and p.frame.Parent) then
		p = UiKit.panel(gui, `TRADE WITH {string.upper(theirName)}`, ACCENT);
		(p :: UiKit.Panel).onClose = function(byUser: boolean)
			local live = ClientState.tradeState
			if byUser and live and live.state ~= "committing" then
				task.spawn(ask, "tradeCancel") -- closing the panel is CANCEL
			end
			panel = nil
		end
		panel = p
	end
	local pp = p :: UiKit.Panel
	clear(pp.body)
	holdFill = nil
	local columns = new("Frame", {
		Size = UDim2.new(1, 0, 0, if state == "picking" then 290 else 160),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = pp.body,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16) }) })
	column(columns, me, them, true, state)
	column(columns, them, me, false, state)
	local fair = text(pp.body, "", 26, UI.INK, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2 })
	fairLine = fair

	local both = type(me.pick) == "table" and type(them.pick) == "table"
	if both then
		-- Display of the server's two rates against the published rule; the server decides at TRADE.
		local r1, r2 = tonumber(me.pick.rate) or 0, tonumber(them.pick.rate) or 0
		local isFair = math.min(r1, r2) >= TRADE.fair * math.max(r1, r2)
		fair.Text = if isFair then "Fair" else `That trade would not be fair to {if r1 > r2 then "you" else theirName}`
		fair.TextColor3 = if isFair then UI.LEAF else UI.CORAL
	else
		fair.Text = "Each of you picks one creature"
		fair.TextColor3 = UI.INK_SOFT
	end

	-- The fixed strip: the emotes at the left, the hold bar and the actions at the right.
	local f = pp.setFooter(96) :: Frame
	local emotes = new("Frame", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(4 * 80, 80),
		BackgroundTransparency = 1,
		Visible = state ~= "committing",
		Parent = f,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) })
	for n, e in EMOTES do
		-- Small icon buttons: the kit's 96 px button in a holder scaled to 0.72.
		local holder = new("Frame", { Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1, Parent = emotes })
		new("UIScale", { Scale = 0.72, Parent = holder })
		UiKit.iconButton(holder, e[2], e[1], UI.LILAC, function()
			ask("tradeEmote", tostring(n))
		end)
	end
	local actions = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -3),
		Size = UDim2.new(1, -360, 0, 64),
		BackgroundTransparency = 1,
		Parent = f,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
	})
	local function actionButton(s: string, colour: Color3, active: boolean, onClick: () -> ())
		local b = UiKit.button(actions, s, colour, "large", 190, onClick)
		UiKit.setEnabled(b, active)
	end
	local function cancelButton()
		actionButton("CANCEL", UI.CORAL, true, function()
			ask("tradeCancel")
		end)
	end
	if state == "picking" then
		actionButton(if me.ready then "WAITING..." else "TRADE", UI.LEAF, both and not me.ready, function()
			ask("tradeAccept")
		end)
		cancelButton()
	elseif state == "hold" then
		fair.Text = "Hold on... either of you can still cancel."
		fair.TextColor3 = UI.INK
		holdFill = UiKit.bar(actions, { Size = UDim2.fromOffset(220, 22) }, 1, UI.AQUA):FindFirstChildOfClass("Frame")
		cancelButton()
	elseif state == "confirm" then
		fair.Text = `Give {pickName(me.pick)}, get {pickName(them.pick)}`
		fair.TextColor3 = UI.INK
		actionButton(if me.confirmed then "WAITING..." else "CONFIRM", UI.LEAF, not me.confirmed, function()
			ask("tradeConfirm")
		end)
		cancelButton()
	else
		fair.Text = "Swapping..."
		fair.TextColor3 = UI.INK_SOFT
	end
	UiKit.selectFirst(pp.frame)
end

-- The 10 s bar from `at` (server time), nothing else counts down on screen.
RunService.Heartbeat:Connect(function()
	local data = ClientState.tradeState
	local fill = holdFill
	if fill and data and data.state == "hold" then
		local left = (tonumber(data.at) or 0) - ClientState.now()
		fill.Size = UDim2.fromScale(math.clamp(left / TRADE.hold, 0, 1), 1)
	end
	local fair = fairLine
	if fair and data and data.state == "committing" then
		fair.Text = `Swapping{string.rep(".", math.floor(os.clock() * 2) % 4)}`
	end
end)

local function showEmote(data: any)
	local p = panel
	if not (p and p.frame.Parent) then
		return
	end
	local n = tonumber(data.emote) or 0
	local e = EMOTES[n]
	local pop = text(p.frame, if e then e[1] else "?", 34, UI.WHITE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.75, 0, 0, 90),
		Size = UDim2.fromOffset(160, 60),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.LILAC,
		ZIndex = 8,
		Outline = UI.INK,
		OutlineThickness = 2,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = pop })
	ClientState.pop(pop)
	ClientState.sound(ClientState.SFX.tick, 0.2, nil, 2.4)
	task.delay(1.5, pop.Destroy, pop)
end

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "trade" then
		render(data)
	elseif kind == "tradeEmote" then
		showEmote(data)
	end
end)

-- A race takes the whole screen; the server cancels the trade when the racer walks apart.
ClientState.RacingChanged:Connect(function(racing: boolean)
	if racing then
		closePanel()
		hideCard()
	end
end)
