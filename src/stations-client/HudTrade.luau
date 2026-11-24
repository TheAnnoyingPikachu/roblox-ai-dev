--!strict
-- Trading: the Trade sheet, the invite that pops up and the peek at the other player's animal.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local player = game:GetService("Players").LocalPlayer
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local RARITY_COLOUR = App.RARITY_COLOUR
local RANK = App.RANK
local STAT_SHORT = App.STAT_SHORT
local screen = App.screen
local Hud = App.Hud
local send = App.send
local nameOf = App.nameOf
local redraw = App.redraw
local trade = App.trade
local tradeDot = App.tradeDot
local darker = App.darker

-- Trading (decision 0084) ---------------------------------------------------------------------------------

S.tradeState = nil -- the open trade as the server last sent it (pushTrade), and `at`, when it came
S.invite = nil -- the latest request to trade: from (UserId), name, at (os.clock)
S.tradePeek = nil -- the animal whose full card is open in the trade window
local tradeDrawn = 0 -- counts redraws of the trade window, so a timer can tell it is stale

local function tradeCell(
	parent: Instance,
	order: number,
	a: any,
	label: string,
	onClick: (() -> ())?,
	picked: boolean?,
	flashFor: number?
)
	local colour = RARITY_COLOUR[StationRules.rarity(a)] or C.text
	local card = Style.card(
		parent,
		UDim2.fromOffset(108, if onClick then 150 else 118),
		if flashFor then C.bad elseif picked then C.good else C.edge
	)
	card.LayoutOrder = order
	if flashFor then -- changed just now (decision 0099): berry until the flash is over
		local mine = tradeDrawn
		task.delay(flashFor, function()
			if tradeDrawn == mine and card.Parent then
				redraw.trade()
			end
		end)
	end
	local peek = Instance.new("TextButton") -- tap the picture for its full card
	peek.BackgroundTransparency, peek.Text = 1, ""
	peek.Position, peek.Size, peek.ZIndex = UDim2.fromOffset(10, 8), UDim2.fromOffset(88, 72), 5
	peek.Activated:Connect(function()
		S.tradePeek = a
		redraw.trade()
	end)
	peek.Parent = card
	local view = Portrait.new(
		card,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(88, 72), background = darker(colour), rainbow = a.rainbow }
	)
	view.Position = UDim2.fromOffset(10, 8)
	local name = Style.text(card, label, 12, C.text, UDim2.fromOffset(100, 30))
	name.Position = UDim2.fromOffset(4, 82)
	name.TextXAlignment = Enum.TextXAlignment.Center
	if onClick then
		local b =
			Style.button(card, if picked then "Take out" else "Put in", onClick, if picked then "ghost" else "primary")
		b.Position, b.Size = UDim2.fromOffset(8, 112), UDim2.fromOffset(92, 30)
		b.TextSize = 14
	end
end

local function tradeSection(title: string, order: number, height: number): Frame
	local card = Style.card(trade.body, UDim2.new(1, -20, 0, height))
	card.LayoutOrder = order
	local t = Style.text(card, title, 16, C.muted, UDim2.new(1, -24, 0, 20))
	t.Position = UDim2.fromOffset(12, 8)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position, row.Size = UDim2.fromOffset(12, 34), UDim2.new(1, -24, 1, -42)
	Style.list(row, 8, true, true)
	row.Parent = card
	return row
end

-- The full card of the animal tapped in the trade window: version, rarity, coat, power, every stat.
function Hud.peekCard(a: any)
	local card = Style.card(trade.body, UDim2.new(1, -20, 0, 128), RARITY_COLOUR[StationRules.rarity(a)])
	card.LayoutOrder = 1
	local title = Style.text(
		card,
		`{StationTrade.nameOf(a)}  ·  {string.upper(StationRules.rarity(a))}  ·  ⚡ {Format.commas(
			BattleRules.powerOf(a)
		)}`,
		18,
		C.text,
		UDim2.new(1, -120, 0, 24)
	)
	title.Position = UDim2.fromOffset(14, 10)
	local parts = {}
	for _, stat in StationConfig.STATS do
		table.insert(
			parts,
			`{STAT_SHORT[stat]} {StationRules.stat(a, stat)} (Lv {StationRules.level(a, stat)}/{StationConfig.MAX_LEVEL})`
		)
	end
	local lines = Style.text(card, table.concat(parts, "    "), 14, C.muted, UDim2.new(1, -28, 0, 60))
	lines.Position, lines.TextWrapped = UDim2.fromOffset(14, 42), true
	local close = Style.button(card, "Close", function()
		S.tradePeek = nil
		redraw.trade()
	end, "ghost", UDim2.fromOffset(92, 40))
	close.AnchorPoint, close.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 10)
end

local function ago(at: number): string
	local d = os.time() - at
	return if d < 3600
		then `{math.max(1, d // 60)}m ago`
		elseif d < 86400 then `{d // 3600}h ago`
		else `{d // 86400}d ago`
end

redraw.trade = function()
	tradeDrawn += 1
	local drawn = tradeDrawn
	Style.clear(trade.body)
	Style.clear(trade.chips)
	Style.clear(trade.tabs)
	tradeDot.Visible = false
	local tip = Style.text(
		trade.body,
		"Only what's in this window moves, both sides at once. Nobody can give you anything outside it.",
		14,
		C.muted,
		UDim2.new(1, -20, 0, 20)
	)
	tip.LayoutOrder = 0
	if S.tradeState then
		local since = os.clock() - (S.tradeState.at or os.clock())
		local readyIn = math.max(0, (S.tradeState.readyIn or 0) - since)
		local confirmIn = math.max(0, (S.tradeState.confirmIn or 0) - since)
		local function again(after: number) -- redraw when a wait runs out
			task.delay(after, function()
				if tradeDrawn == drawn and S.openName == "trade" then
					redraw.trade()
				end
			end)
		end
		local fresh = (S.tradeState.traded or 0) == 0 or (S.tradeState.level or 0) <= StationTrade.MIN_LEVEL
		Style.chip(trade.chips, `Trading with {S.tradeState.with}`, C.accent, C.accentText)
		Style.chip(
			trade.chips,
			`Level {S.tradeState.level or "?"} · traded {S.tradeState.traded or 0} times`,
			if fresh then C.bad else nil,
			if fresh then Color3.new(1, 1, 1) else nil
		)
		Style.chip(trade.chips, `{S.tradeState.left or 0} trades left today`)
		if S.tradePeek then
			Hud.peekCard(S.tradePeek)
		end
		local flash = S.tradeState.flash
		local theirs = tradeSection(`{S.tradeState.with} gives`, 2, 170)
		if #S.tradeState.theirs == 0 then
			Style.text(theirs, "Nothing yet", 15, C.muted, UDim2.fromOffset(200, 20))
		end
		local get, give = {}, {}
		for k, a in S.tradeState.theirs do
			table.insert(get, a)
			local lit = if flash and not flash.mine and flash.id == a.id then flash.left - since else nil
			tradeCell(theirs, k, a, nameOf(a), nil, nil, if lit and lit > 0 then lit else nil)
		end
		local mine = tradeSection("You give", 3, 170)
		if #S.tradeState.mine == 0 then
			Style.text(mine, "Pick from your animals below", 15, C.muted, UDim2.fromOffset(260, 20))
		end
		for k, id in S.tradeState.mine do
			local _, a = StationProgress.find(S.profile, id)
			if a then
				table.insert(give, a)
				local lit = if flash and flash.mine and flash.id == id then flash.left - since else nil
				tradeCell(mine, k, a, nameOf(a), nil, nil, if lit and lit > 0 then lit else nil)
			end
		end
		-- the fairness meter: a guide, never a block
		local balance, uneven = StationTrade.balance(give, get)
		local meter = Style.card(trade.body, UDim2.new(1, -20, 0, if uneven then 74 else 54))
		meter.LayoutOrder = 4
		local left = Style.text(meter, "You give more", 13, C.muted, UDim2.fromOffset(110, 20))
		left.Position = UDim2.fromOffset(12, 17)
		local right = Style.text(meter, "You get more", 13, C.muted, UDim2.fromOffset(110, 20))
		right.AnchorPoint, right.Position, right.TextXAlignment =
			Vector2.new(1, 0), UDim2.new(1, -12, 0, 17), Enum.TextXAlignment.Right
		local bar = Style.frame(meter, UDim2.new(1, -260, 0, 14), C.off)
		bar.Position = UDim2.fromOffset(130, 20)
		Style.round(bar, 7)
		Style.stroke(bar, C.ink, 2)
		local mark = Style.frame(bar, UDim2.fromOffset(8, 24), C.ink)
		mark.AnchorPoint, mark.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(balance, 0.5)
		Style.round(mark, 3)
		if uneven then
			local warnText = Style.text(
				meter,
				"This trade is very uneven: check before you confirm",
				14,
				C.bad,
				UDim2.new(1, -24, 0, 20)
			)
			warnText.Position, warnText.TextXAlignment = UDim2.fromOffset(12, 46), Enum.TextXAlignment.Center
		end
		local buttons =
			Style.card(trade.body, UDim2.new(1, -20, 0, if S.tradeState.stage == "confirm" then 112 else 64))
		buttons.LayoutOrder = 5
		local main: TextButton
		if S.tradeState.stage == "confirm" then
			-- the window is locked: what goes each way, then Confirm after a moment to look
			local function list(xs: { any }): string
				local out = {}
				for _, x in xs do
					table.insert(out, StationTrade.nameOf(x))
				end
				return if #out > 0 then table.concat(out, ", ") else "nothing"
			end
			local summary = Style.text(
				buttons,
				`You give: {list(give)}\nYou get: {list(get)}`,
				15,
				C.text,
				UDim2.new(1, -24, 0, 40)
			)
			summary.Position, summary.TextWrapped = UDim2.fromOffset(12, 6), true
			local precious = false -- giving a coat or a mythic and up needs a hold
			for _, x in give do
				precious = precious
					or StationRules.coatOf(x) ~= nil
					or (RANK[StationRules.rarity(x)] or 0) >= RANK.mythic
			end
			local words = if S.tradeState.confirmed
				then `Waiting for {S.tradeState.with}...`
				elseif confirmIn > 0 then `Confirm in {math.ceil(confirmIn)}s`
				elseif precious then "Hold to confirm"
				else "Confirm trade"
			main = Style.button(buttons, words, function()
				if not precious and confirmIn <= 0 and not S.tradeState.confirmed then
					send("trade_confirm")
				end
			end, if S.tradeState.confirmed then "good" elseif confirmIn > 0 then "off" else "primary")
			main.Position, main.Size = UDim2.fromOffset(12, 56), UDim2.new(0.5, -18, 0, 44)
			if confirmIn > 0 then
				again(confirmIn - math.floor(confirmIn) + 0.02)
			elseif precious and not S.tradeState.confirmed then
				local fill = Style.frame(main, UDim2.fromScale(0, 1), C.good)
				fill.ZIndex = 0
				Style.round(fill, 12)
				local holding = 0
				main.InputBegan:Connect(function(input)
					local t = input.UserInputType
					if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
						return
					end
					holding += 1
					local press = holding
					fill.Size = UDim2.fromScale(0, 1)
					TweenService
						:Create(fill, TweenInfo.new(2, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
						:Play()
					task.delay(2, function()
						if holding == press then
							send("trade_confirm")
						end
					end)
				end)
				main.InputEnded:Connect(function(input)
					local t = input.UserInputType
					if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
						holding += 1
						fill.Size = UDim2.fromScale(0, 1)
					end
				end)
			end
		else
			local waiting = readyIn > 0 and not S.tradeState.ready
			main = Style.button(
				buttons,
				if S.tradeState.ready
					then "Ready! (tap to wait)"
					elseif waiting then `Ready in {math.ceil(readyIn)}s`
					else "Ready",
				function()
					send("trade_ready")
				end,
				if S.tradeState.ready then "good" elseif waiting then "off" else "primary"
			)
			main.Position, main.Size = UDim2.fromOffset(12, 10), UDim2.new(0.5, -18, 0, 44)
			if waiting then
				again(readyIn - math.floor(readyIn) + 0.02)
			end
		end
		local cancel = Style.button(buttons, "Cancel trade", function()
			send("trade_cancel")
		end, "ghost")
		cancel.Position, cancel.Size = main.Position + UDim2.fromScale(0.5, 0), UDim2.new(0.5, -18, 0, 44)
		if S.tradeState.stage ~= "confirm" then
			local rows = math.max(1, math.ceil(#S.profile.animals / 5))
			local own = tradeSection("Your animals (training and locked ones stay home)", 6, 50 + rows * 158)
			for k, a in S.profile.animals do
				local picked = table.find(S.tradeState.mine, a.id) ~= nil
				local label = nameOf(a) .. (if a.at then " (training)" elseif a.locked then " 🔒" else "")
				tradeCell(
					own,
					k,
					a,
					label,
					if a.at or a.locked
						then nil
						else function()
							send("trade_put", a.id)
						end,
					picked
				)
			end
		end
		return
	end
	S.tradePeek = nil
	local level = StationProgress.playerLevel(S.profile)
	local off = S.profile.trades and S.profile.trades.off
	Style.chip(trade.chips, "Swap animals with a player in this server")
	Style.chip(trade.chips, `{StationTrade.left(S.profile, os.time())} trades left today`)
	local requests = Style.button(trade.tabs, if off then "Requests: off" else "Requests: on", function()
		send("trade_off", not off)
	end, if off then "off" else "good", UDim2.fromOffset(196, 44))
	requests.LayoutOrder = 50
	if level < StationTrade.MIN_LEVEL then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64), C.gold)
		card.LayoutOrder = 1
		local t = Style.text(
			card,
			`Trading opens at player level {StationTrade.MIN_LEVEL}. You're level {level}: clear waves for XP.`,
			16,
			C.text,
			UDim2.new(1, -28, 0, 40)
		)
		t.Position, t.TextWrapped = UDim2.fromOffset(14, 12), true
	end
	if S.invite and os.clock() - S.invite.at < 30 then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 74), C.gold)
		card.LayoutOrder = 2
		local t = Style.text(card, `{S.invite.name} wants to trade`, 18, C.text, UDim2.new(0.5, 0, 0, 24))
		t.Position = UDim2.fromOffset(14, 25)
		local yes = Style.button(card, "Accept", function()
			local from = S.invite.from
			S.invite = nil
			send("trade_answer", from, true)
		end, "good")
		yes.Position, yes.Size = UDim2.new(0.5, 0, 0, 14), UDim2.new(0.25, -12, 0, 44)
		local no = Style.button(card, "Decline", function()
			local from = S.invite.from
			S.invite = nil
			send("trade_answer", from, false)
			redraw.trade()
		end, "ghost")
		no.Position, no.Size = UDim2.new(0.75, 0, 0, 14), UDim2.new(0.25, -12, 0, 44)
	end
	local others = 0
	for _, other in game:GetService("Players"):GetPlayers() do
		if other ~= player then
			others += 1
			local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64))
			card.LayoutOrder = 2 + others
			local t = Style.text(card, other.DisplayName, 18, C.text, UDim2.new(0.45, 0, 0, 24))
			t.Position = UDim2.fromOffset(14, 20)
			local ask = Style.button(card, "Ask to trade", function()
				if send("trade_ask", other.UserId) then
					Style.toast(screen, `Asked {other.DisplayName} to trade`, 2)
				end -- a refusal says why
			end, if level >= StationTrade.MIN_LEVEL then "primary" else "off")
			ask.Position, ask.Size = UDim2.new(0.45, 0, 0, 10), UDim2.new(0.33, -12, 0, 44)
			local block = Style.button(card, "Block", function()
				send("trade_block", other.UserId)
				Style.toast(screen, `{other.DisplayName} can't ask you to trade until you rejoin`, 3)
			end, "ghost")
			block.Position, block.Size = UDim2.new(0.78, 0, 0, 10), UDim2.new(0.22, -12, 0, 44)
		end
	end
	if others == 0 then
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 64))
		card.LayoutOrder = 3
		local t = Style.text(card, "Nobody else is in this server yet.", 16, C.muted, UDim2.new(1, -28, 0, 24))
		t.Position = UDim2.fromOffset(14, 20)
	end
	-- the history: the newest 20 trades
	local log = if S.profile.trades then S.profile.trades.log else {}
	if #log > 0 then
		local shown = math.min(#log, 20)
		local card = Style.card(trade.body, UDim2.new(1, -20, 0, 40 + shown * 22))
		card.LayoutOrder = 100
		local head = Style.text(card, "Your recent trades", 16, C.muted, UDim2.new(1, -24, 0, 20))
		head.Position = UDim2.fromOffset(12, 8)
		for k = 1, shown do
			local e = log[k]
			local gave = if #e.gave > 0 then table.concat(e.gave, ", ") else "nothing"
			local got = if #e.got > 0 then table.concat(e.got, ", ") else "nothing"
			local line = Style.text(
				card,
				`{ago(e.at)}, with {e.with}: gave {gave}, got {got}`,
				13,
				C.text,
				UDim2.new(1, -24, 0, 20)
			)
			line.Position, line.TextTruncate = UDim2.fromOffset(12, 10 + k * 22), Enum.TextTruncate.AtEnd
		end
	end
end

return nil
