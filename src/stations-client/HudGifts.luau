--!strict
-- The Gifts sheet: the weekly planner, the monthly planner and the daily wheel.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationRewards = require(Shared:WaitForChild("StationRewards"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local RAINBOW = App.RAINBOW
local REFUSED = App.REFUSED
local screen = App.screen
local Hud = App.Hud
local send = App.send
local redraw = App.redraw
local gifts = App.gifts

-- Gifts (decision 0094): the weekly planner, the monthly planner and the daily wheel ----------------------

local giftsTab = "week"
local spinning = false

-- What a reward gives, in words: "930 coins, 2 Meadow Eggs".
local function rewardWords(items: any): string
	local parts = {}
	if items.coins > 0 then
		table.insert(parts, `{Format.commas(items.coins)} coins`)
	end
	if items.samples > 0 then
		table.insert(parts, `{items.samples} samples`)
	end
	local counts, order = {}, {}
	for _, id in items.eggs do
		if counts[id] == nil then
			table.insert(order, id)
		end
		counts[id] = (counts[id] or 0) + 1
	end
	for _, id in order do
		local def = StationConfig.egg(id)
		local name = if def then def.name else id
		table.insert(parts, if counts[id] > 1 then `{counts[id]} {name}s` else `a {name}`)
	end
	if items.boost then
		local what = if items.boost == "hatch" then "Hatching" else "Training"
		table.insert(parts, `{what} x2 for {Format.ago(items.seconds)}`)
	end
	if items.rainbow then
		local sp = StationConfig.species(items.rainbow)
		table.insert(parts, `a Rainbow {if sp then sp.name else items.rainbow}`)
	end
	if items.jackpot then
		table.insert(parts, "a Rainbow mythic!")
	end
	return table.concat(parts, ", ")
end

-- The reward icons (decision 0100): one picture for each kind of reward, in the Savanna look
-- (assets/stations/icons, made by tools/icons/stations_rewards.py). Eggs show their own egg.
local ICON = {
	coins = "rbxassetid://126839540915586",
	samples = "rbxassetid://109970824605063",
	meadow = "rbxassetid://102211226773835",
	wild = "rbxassetid://108812133520186",
	safari = "rbxassetid://129564996329142",
	golden = "rbxassetid://86853923413561",
	star = "rbxassetid://95586444952247",
	hatch = "rbxassetid://111148238651019",
	train = "rbxassetid://92388913223446",
	rainbow = "rbxassetid://90795860429478",
	spin = "rbxassetid://112243151972690",
	gift = "rbxassetid://91667720786022",
}

-- A reward's main picture and the small one for what comes with it.
local function iconsOf(items: any): (string, string?)
	local egg = items.eggs[1]
	local boost = if items.boost then ICON[items.boost] else nil
	if items.jackpot or items.rainbow then
		return ICON.rainbow, nil
	elseif egg then
		return ICON[egg] or ICON.meadow, boost
	elseif items.coins > 0 then
		return ICON.coins, if items.samples > 0 then ICON.samples else boost
	elseif boost then
		return boost, nil
	elseif items.samples > 0 then
		return ICON.samples, nil
	end
	return ICON.gift, nil
end

-- The picture of a reward at `size`: its main icon, a small second one at its foot, a gold star on the
-- player's best egg (`best`).
local function rewardIcon(parent: Instance, items: any, size: number, best: boolean?): Frame
	local main, extra = iconsOf(items)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	local function layer(image: string, scale: number, anchor: Vector2, at: UDim2)
		local p = Instance.new("ImageLabel")
		p.BackgroundTransparency, p.Image = 1, image
		p.AnchorPoint, p.Position, p.Size = anchor, at, UDim2.fromScale(scale, scale)
		p.Parent = holder
	end
	layer(main, 1, Vector2.zero, UDim2.new())
	if extra then
		layer(extra, 0.5, Vector2.new(1, 1), UDim2.fromScale(1.08, 1.04))
	end
	if best then
		layer(ICON.star, 0.42, Vector2.zero, UDim2.fromScale(-0.08, -0.04))
	end
	holder.Parent = parent
	return holder
end

local function giftsReady(): (boolean, boolean, boolean)
	if S.profile == nil or S.profile.rewards == nil then
		return false, false, false
	end
	local r = S.profile.rewards
	local week = r.weekGot < r.weekDays
	local month = false
	for _, d in StationRewards.MILESTONES do
		month = month or (r.monthDays >= d and not table.find(r.monthGot, d))
	end
	return week, month, StationRewards.canSpin(S.profile, Workspace:GetServerTimeNow())
end

function Hud.boostChips(parent: Instance)
	local now = Workspace:GetServerTimeNow()
	for _, b in { { "hatch", "Hatching" }, { "train", "Training" } } do
		local left = StationProgress.boostLeft(S.profile, b[1], now)
		if left > 0 then
			Style.chip(parent, `{b[2]} x2: {Format.ago(left)}`, C.info, Color3.new(1, 1, 1))
		end
	end
end

function Hud.weekView()
	local r = S.profile.rewards
	local head = Style.text(
		gifts.body,
		`Day {math.min(r.weekGot + 1, 7)} of 7 · new rewards every Monday`,
		18,
		C.muted,
		UDim2.new(1, -12, 0, 24)
	)
	head.LayoutOrder = 0
	for k, spec in StationRewards.WEEK do
		local got, ready = k <= r.weekGot, k == r.weekGot + 1 and r.weekGot < r.weekDays
		local card =
			Style.card(gifts.body, UDim2.fromOffset(150, 228), if got then C.good elseif k == 7 then C.accent else nil)
		card.LayoutOrder = k
		local t = Style.text(card, `Day {k}`, 20, C.text, UDim2.new(1, -20, 0, 24))
		t.Position = UDim2.fromOffset(10, 8)
		local items = StationRewards.resolve(S.profile, spec)
		local icon = rewardIcon(card, items, 68, spec.egg == "best")
		icon.Position = UDim2.fromOffset(41, 34)
		local words = Style.text(card, rewardWords(items), 14, C.muted, UDim2.new(1, -20, 0, 66))
		words.Position, words.TextWrapped, words.TextXAlignment =
			UDim2.fromOffset(10, 106), true, Enum.TextXAlignment.Center
		local b = Style.button(card, if got then "Claimed" elseif ready then "Claim" else "Log in more", function()
			send("claim_week")
		end, if ready then "good" else "off")
		b.Position, b.Size, b.TextSize = UDim2.fromOffset(10, 174), UDim2.new(1, -20, 0, 44), 16
	end
end

function Hud.monthView()
	local r = S.profile.rewards
	local head = Style.text(
		gifts.body,
		`Days logged this month: {r.monthDays} · a missed day never resets it`,
		18,
		C.muted,
		UDim2.new(1, -12, 0, 24)
	)
	head.LayoutOrder = 0
	for k, d in StationRewards.MILESTONES do
		local spec = StationRewards.MONTH[d]
		local got = table.find(r.monthGot, d) ~= nil
		local ready = not got and r.monthDays >= d
		local items = StationRewards.resolve(S.profile, spec, StationRewards.monthOf(Workspace:GetServerTimeNow()))
		local card =
			Style.card(gifts.body, UDim2.fromOffset(150, 228), if got then C.good elseif d == 28 then C.accent else nil)
		card.LayoutOrder = k
		local t = Style.text(card, `Day {d}`, 20, C.text, UDim2.new(1, -20, 0, 24))
		t.Position = UDim2.fromOffset(10, 8)
		if items.rainbow then -- the month's own rainbow animal
			local view = Portrait.new(
				card,
				StationRules.assetOf(items.rainbow, nil),
				{ size = UDim2.fromOffset(84, 68), rainbow = true, background = C.cardHi }
			)
			view.Position = UDim2.fromOffset(33, 34)
		else
			local icon = rewardIcon(card, items, 68, spec.egg == "best")
			icon.Position = UDim2.fromOffset(41, 34)
		end
		local words = Style.text(card, rewardWords(items), 14, C.muted, UDim2.new(1, -20, 0, 66))
		words.Position, words.TextWrapped, words.TextXAlignment =
			UDim2.fromOffset(10, 106), true, Enum.TextXAlignment.Center
		local label = if got then "Claimed" elseif ready then "Claim" else `{d - r.monthDays} more days`
		local b = Style.button(card, label, function()
			send("claim_month", d)
		end, if ready then "good" else "off")
		b.Position, b.Size, b.TextSize = UDim2.fromOffset(10, 174), UDim2.new(1, -20, 0, 44), 16
	end
end

-- The wheel: eight prize bubbles round a hub, turned so the prize won stops under the pointer.
local wheelTurn = 0
function Hud.wheelView()
	local SIZE = 380
	local n = #StationRewards.WHEEL
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size, holder.LayoutOrder = UDim2.new(1, -12, 0, SIZE + 300), 1
	holder.Parent = gifts.body

	-- the odds, below the wheel and its button, in two columns
	local odds = Instance.new("Frame")
	odds.BackgroundTransparency = 1
	odds.AnchorPoint, odds.Position, odds.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 130), UDim2.fromOffset(560, 160)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize, grid.CellPadding = UDim2.fromOffset(276, 22), UDim2.fromOffset(8, 2)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = odds
	odds.Parent = holder
	local title = Style.text(holder, "THE ODDS", 14, C.muted, UDim2.fromOffset(560, 20))
	title.AnchorPoint, title.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 106)
	title.TextXAlignment = Enum.TextXAlignment.Center
	for k, slice in StationRewards.WHEEL do
		local line =
			Style.text(odds, `{slice.name}: {slice.ppm / 10000}%`, 15, if k == n then C.bad else C.muted, UDim2.new())
		line.LayoutOrder = k
		line.TextXAlignment = Enum.TextXAlignment.Center
	end
	local pity = Style.text(
		holder,
		`After {StationRewards.PITY} spins without it, the jackpot's chance doubles.`,
		13,
		C.muted,
		UDim2.fromOffset(560, 20)
	)
	pity.AnchorPoint, pity.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 238)
	pity.TextXAlignment = Enum.TextXAlignment.Center

	local stage = holder
	-- the wheel, big, in the middle
	local disc = Instance.new("Frame")
	disc.Name = "Wheel"
	disc.AnchorPoint, disc.Position, disc.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 22), UDim2.fromOffset(SIZE, SIZE)
	disc.BackgroundColor3 = C.sand
	disc.Rotation = wheelTurn % 360
	Style.round(disc, SIZE / 2)
	Style.stroke(disc, C.ink, 6)
	disc.Parent = stage
	local colours = {
		C.cardHi,
		C.accent,
		Color3.fromRGB(201, 238, 176),
		Color3.fromRGB(166, 216, 245),
		C.info,
		Color3.fromRGB(214, 196, 247), -- lilac, so the green samples stand out
		Color3.fromRGB(247, 163, 189),
		C.gold,
	}
	for k, slice in StationRewards.WHEEL do
		local a = math.rad((k - 1) * 360 / n - 90)
		local bubble = Instance.new("TextLabel")
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.new(0.5, math.cos(a) * SIZE * 0.35, 0.5, math.sin(a) * SIZE * 0.35)
		bubble.Size = UDim2.fromOffset(SIZE * 0.25, SIZE * 0.25)
		bubble.BackgroundColor3 = colours[k]
		bubble.Font = Ui.theme.font
		bubble.Text = ""
		bubble.Rotation = (k - 1) * 360 / n
		local prize = slice.prize
		local items = StationRewards.resolve(S.profile, prize)
		local icon = rewardIcon(bubble, items, math.floor(SIZE * 0.15), prize.egg == "best")
		icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6)
		local caption = Style.text(
			bubble,
			if prize.jackpot
				then "MYTHIC!"
				elseif prize.pays then `{prize.pays} pays`
				elseif prize.boost then `x2 {Format.ago(prize.seconds or 0)}`
				elseif prize.samples then `{prize.samples} samples`
				elseif prize.egg == "best" then "Best egg"
				else "Egg",
			13,
			C.ink,
			UDim2.new(1, 0, 0, 16)
		)
		caption.AnchorPoint, caption.Position, caption.TextXAlignment =
			Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6), Enum.TextXAlignment.Center
		Style.round(bubble, SIZE * 0.125)
		Style.stroke(bubble, C.ink, 3)
		if k == n then
			local g = Instance.new("UIGradient")
			g.Color = RAINBOW
			g.Parent = bubble
		end
		bubble.Parent = disc
	end
	local hub = Style.text(disc, "", 1, C.ink, UDim2.fromOffset(SIZE * 0.22, SIZE * 0.22))
	hub.AnchorPoint, hub.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	hub.BackgroundTransparency, hub.BackgroundColor3 = 0, C.accent
	Style.round(hub, SIZE * 0.11)
	Style.stroke(hub, C.ink, 5)
	local pointer = Style.text(stage, "▼", 48, C.bad, UDim2.fromOffset(48, 48))
	pointer.AnchorPoint, pointer.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -4)
	pointer.TextXAlignment, pointer.ZIndex = Enum.TextXAlignment.Center, 5
	Style.outline(pointer)

	-- under the wheel: the button, which pops while a spin is ready, and when the next one comes
	local now = Workspace:GetServerTimeNow()
	local can = StationRewards.canSpin(S.profile, now)
	local nextIn = (StationRewards.day(now) + 1) * 86400 - now
	local b = Style.button(stage, if can then "Spin it!" else `Next spin in {Format.ago(nextIn)}`, function()
		if spinning then
			return
		end
		spinning = true
		local ok, code = request:InvokeServer("spin")
		if not ok then
			spinning = false
			Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		end
	end, if can then "primary" else "off", UDim2.fromOffset(240, 60))
	b.AnchorPoint, b.Position, b.TextSize = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, SIZE + 40), 26
	if can then
		local pop = b:FindFirstChildOfClass("UIScale") :: UIScale
		task.spawn(function() -- a gentle pulse until it is pressed or the menu redraws
			while b.Parent and not spinning do
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { Scale = 1.08 }):Play()
				task.wait(0.5)
				if not b.Parent or spinning then
					break
				end
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
				task.wait(0.5)
			end
		end)
	end
	return disc
end

local wheelDisc: Frame? = nil
redraw.gifts = function()
	if spinning then
		return -- the wheel is turning: it redraws when it stops
	end
	Style.clear(gifts.body)
	Style.clear(gifts.chips)
	Style.clear(gifts.tabs)
	local week, month, spin = giftsReady()
	for _, t in { { "week", "This week", week }, { "month", "This month", month }, { "wheel", "Daily wheel", spin } } do
		Style.tab(gifts, t[2], giftsTab == t[1], function()
			giftsTab = t[1]
			redraw.gifts()
		end, if t[3] then "!" else nil)
	end
	Hud.boostChips(gifts.chips)
	Style.chip(gifts.chips, "Resets at midnight UTC")
	wheelDisc = nil
	if giftsTab == "week" then
		Hud.weekView()
	elseif giftsTab == "month" then
		Hud.monthView()
	else
		wheelDisc = Hud.wheelView()
	end
end

-- The wheel stops on the prize the server rolled, then says what it was.
function Hud.landWheel(payload: any)
	local n = #StationRewards.WHEEL
	local slice = 360 / n
	local target = -((payload.prize - 1) * slice) + math.random(-12, 12)
	wheelTurn += 360 * 5 + ((target - wheelTurn) % 360)
	local disc = wheelDisc
	local function done()
		spinning = false
		local words = rewardWords(payload.items)
		if payload.items.jackpot and payload.mythic then
			local va = StationConfig.variant(payload.mythic.s, payload.mythic.v)
			words = `JACKPOT! A Rainbow {if va then va.name else "mythic"}!`
		end
		Style.sound("claim")
		Style.toast(screen, `You won: {words}`, 5, "good", (iconsOf(payload.items)))
		if S.openName == "gifts" then
			redraw.gifts()
		end
	end
	if disc and disc.Parent then
		local t = TweenService:Create(
			disc,
			TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Rotation = wheelTurn }
		)
		t.Completed:Connect(done)
		t:Play()
	else
		done()
	end
end

App.rewardWords = rewardWords
App.iconsOf = iconsOf
App.giftsReady = giftsReady

return nil
