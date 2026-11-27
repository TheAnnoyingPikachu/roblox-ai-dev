--!strict
-- The Gifts window (the RanchGifts board): the week, the month and the daily wheel on one page.
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
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local REFUSED = App.REFUSED
local screen = App.screen
local Hud = App.Hud
local send = App.send
local redraw = App.redraw
local gifts = App.gifts

-- Gifts (decision 0094): the weekly planner, the monthly planner and the daily wheel ----------------------

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
	if items.animal then
		local sp = StationConfig.species(items.animal)
		local name = if sp then sp.name else items.animal
		table.insert(parts, if sp and sp.role == StationConfig.TITAN then `an {name}, your first Titan` else `a {name}`)
	end
	return table.concat(parts, ", ")
end

-- The reward icons (decision 0100): one picture for each kind of reward. Eggs show their own egg.
local ICON = {
	-- the ForgeGUI HUD set (STATION-146, assets/stations/icons/hud_*.png): the piles for rewards, every egg its own
	coins = "rbxassetid://94007045915732",
	samples = "rbxassetid://101522904487827",
	meadow = "rbxassetid://109046370912349",
	wild = "rbxassetid://73338336327716",
	safari = "rbxassetid://120994669025671",
	golden = "rbxassetid://84301645321779",
	dusk = "rbxassetid://115824078820759",
	oasis = "rbxassetid://75529451728673",
	ivory = "rbxassetid://122560806271529",
	legend = "rbxassetid://139891503606754",
	mythic = "rbxassetid://89504309314788",
	divine = "rbxassetid://78850863936664",
	celestial = "rbxassetid://81845873108455",
	crown = "rbxassetid://87584928608960",
	-- the second set (STATION-148)
	star = "rbxassetid://106093731909487",
	hatch = "rbxassetid://91196405828135",
	train = "rbxassetid://117835128066284",
	rainbow = "rbxassetid://77969131949083",
	spin = "rbxassetid://89760743626935",
	gift = "rbxassetid://99989753342977",
	chest = "rbxassetid://132112302967639",
	pointer = "rbxassetid://81448409287996",
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

-- The week (the RanchGifts board): a row of seven days, collected ones green, today yellow with its
-- Collect button under the row, later days paler.
function Hud.weekView()
	local r = S.profile.rewards
	local today = math.min(r.weekGot + 1, 7)
	local head = Style.text(gifts.body, `This week · day {today} of 7`, 20, C.text, UDim2.new(1, -12, 0, 26))
	head.LayoutOrder = 1
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size, row.LayoutOrder = UDim2.new(1, -12, 0, 150), 2
	local cells = Instance.new("UIGridLayout")
	cells.CellSize, cells.CellPadding = UDim2.new(1 / 7, -8, 1, -6), UDim2.fromOffset(9, 0)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = row
	row.Parent = gifts.body
	local ready = r.weekGot < r.weekDays
	for k, spec in StationRewards.WEEK do
		local got, now = k <= r.weekGot, k == r.weekGot + 1
		local items = StationRewards.resolve(S.profile, spec)
		local card = Style.card(row, UDim2.new(), if got then C.good elseif now then C.accent else nil)
		card.LayoutOrder = k
		if now then
			Style.paint(card, Color3.fromRGB(255, 233, 168)) -- today
		elseif not got then
			Style.paint(card, C.sand)
		end
		local day = Style.small(card, `DAY {k}`, 12, C.muted, UDim2.new(1, 0, 0, 18))
		day.Position, day.TextXAlignment = UDim2.fromOffset(0, 6), Enum.TextXAlignment.Center
		if got then
			local tick = Style.frame(card, UDim2.fromOffset(52, 52), C.good)
			tick.AnchorPoint, tick.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 28)
			Style.round(tick, 26)
			Style.stroke(tick, C.ink, 3)
			Style.icon(tick, "check", 30).Position = UDim2.fromOffset(11, 11)
		else
			local icon = rewardIcon(card, items, 56, spec.egg == "best")
			icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 26)
		end
		local words = Style.small(card, rewardWords(items), 12, C.text, UDim2.new(1, -10, 0, 50))
		words.Position, words.TextWrapped, words.TextXAlignment =
			UDim2.fromOffset(5, 88), true, Enum.TextXAlignment.Center
		words.TextYAlignment = Enum.TextYAlignment.Top
	end
	local b = Style.button(
		gifts.body,
		if ready then `Collect day {today}` elseif r.weekGot >= 7 then "This week is done" else "Come back tomorrow",
		function()
			send("claim_week")
		end,
		if ready then "primary" else "off",
		UDim2.fromOffset(220, 46)
	)
	b.LayoutOrder, b.TextSize = 3, 18
end

-- The month: one bar of the days played, and its prizes along it; a prize that is due is a button.
function Hud.monthView()
	local r = S.profile.rewards
	local card = Style.card(gifts.body, UDim2.new(1, -12, 0, 176))
	card.LayoutOrder = 4
	local title = Style.text(card, "This month", 20, C.text, UDim2.fromOffset(200, 26))
	title.Position = UDim2.fromOffset(14, 10)
	local sub = Style.small(
		card,
		`{r.monthDays} days played · a missed day never resets it`,
		13,
		C.muted,
		UDim2.new(1, -230, 0, 26)
	)
	sub.AnchorPoint, sub.Position, sub.TextXAlignment =
		Vector2.new(1, 0), UDim2.new(1, -14, 0, 10), Enum.TextXAlignment.Right
	local bar, set = Style.bar(card, UDim2.new(1, -28, 0, 16), C.info)
	bar.Position = UDim2.fromOffset(14, 42)
	set(r.monthDays / 28)
	local prizes = Instance.new("Frame")
	prizes.BackgroundTransparency = 1
	prizes.Position, prizes.Size = UDim2.fromOffset(14, 68), UDim2.new(1, -28, 0, 100)
	local cells = Instance.new("UIGridLayout")
	cells.CellSize, cells.CellPadding = UDim2.new(1 / #StationRewards.MILESTONES, -6, 1, 0), UDim2.fromOffset(6, 0)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = prizes
	prizes.Parent = card
	local month = StationRewards.monthOf(Workspace:GetServerTimeNow())
	for k, d in StationRewards.MILESTONES do
		local spec = StationRewards.MONTH[d]
		local got = table.find(r.monthGot, d) ~= nil
		local due = not got and r.monthDays >= d
		local items = StationRewards.resolve(S.profile, spec, month)
		local tile = Style.button(prizes, "", function()
			send("claim_month", d)
		end, if due then "primary" elseif got then "good" else "ghost", UDim2.new())
		tile.LayoutOrder = k
		local day = Style.small(tile, if got then `Day {d} ✓` else `Day {d}`, 12, C.text, UDim2.new(1, 0, 0, 16))
		day.Position, day.TextXAlignment, day.ZIndex = UDim2.fromOffset(0, 4), Enum.TextXAlignment.Center, 3
		if items.rainbow then -- the month's own rainbow animal
			local view = Portrait.new(
				tile,
				StationRules.assetOf(items.rainbow, nil),
				{ size = UDim2.fromOffset(52, 44), rainbow = true, background = C.cardHi }
			)
			view.AnchorPoint, view.Position, view.ZIndex = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 22), 3
		else
			local icon = rewardIcon(tile, items, 44, spec.egg == "best")
			icon.AnchorPoint, icon.Position, icon.ZIndex = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 22), 3
		end
		local words =
			Style.small(tile, if due then "Collect!" else rewardWords(items), 11, C.text, UDim2.new(1, -6, 0, 28))
		words.Position, words.TextWrapped, words.TextXAlignment, words.ZIndex =
			UDim2.fromOffset(3, 68), true, Enum.TextXAlignment.Center, 3
		words.TextTruncate = Enum.TextTruncate.AtEnd
	end
end

-- The wheel: eight prize bubbles round a hub, turned so the prize won stops under the pointer. One free spin
-- a day, beside what it can give and what is running now.
local wheelTurn = 0
local WHEEL = "rbxassetid://103419958133693" -- the wheel's face: eight slices, the first straight up
function Hud.wheelView()
	local SIZE = 196
	local n = #StationRewards.WHEEL
	local card = Style.card(gifts.body, UDim2.new(1, -12, 0, SIZE + 44))
	card.LayoutOrder = 5
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.Position, stage.Size = UDim2.fromOffset(18, 26), UDim2.fromOffset(SIZE, SIZE)
	stage.Parent = card
	-- the wheel's face and pointer are the ForgeGUI art (STATION-148); the prizes sit on its slices and turn with it
	local disc = Instance.new("ImageLabel")
	disc.Name = "Wheel"
	disc.BackgroundTransparency, disc.Image = 1, WHEEL
	disc.Size = UDim2.fromOffset(SIZE, SIZE)
	disc.Rotation = wheelTurn % 360
	disc.Parent = stage
	for k, slice in StationRewards.WHEEL do
		local a = math.rad((k - 1) * 360 / n - 90)
		local items = StationRewards.resolve(S.profile, slice.prize)
		local icon = rewardIcon(disc, items, math.floor(SIZE * 0.2), slice.prize.egg == "best")
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, math.cos(a) * SIZE * 0.3, 0.5, math.sin(a) * SIZE * 0.3)
		icon.Rotation = (k - 1) * 360 / n
	end
	local pointer = Instance.new("ImageLabel")
	pointer.BackgroundTransparency, pointer.Image = 1, ICON.pointer
	pointer.AnchorPoint, pointer.Position, pointer.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -34), UDim2.fromOffset(38, 66)
	pointer.ScaleType, pointer.ZIndex = Enum.ScaleType.Fit, 5
	pointer.Parent = stage

	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Position, side.Size = UDim2.fromOffset(SIZE + 44, 16), UDim2.new(1, -SIZE - 60, 1, -28)
	Style.list(side, 8)
	side.Parent = card
	Style.text(side, "The daily wheel", 20, C.text, UDim2.new(1, 0, 0, 26)).LayoutOrder = 1
	local about = Style.small(
		side,
		"One free spin a day. Coins, samples, an egg, double hatching or training for a while, or the rainbow jackpot.",
		13,
		C.muted,
		UDim2.new(1, 0, 0, 36)
	)
	about.TextWrapped, about.LayoutOrder = true, 2
	local running = Instance.new("Frame")
	running.BackgroundTransparency = 1
	running.Size, running.AutomaticSize, running.LayoutOrder = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y, 3
	Style.list(running, 6, true, true)
	running.Parent = side
	Hud.boostChips(running)
	local now = Workspace:GetServerTimeNow()
	local can = StationRewards.canSpin(S.profile, now)
	local nextIn = (StationRewards.day(now) + 1) * 86400 - now
	local b = Style.button(side, if can then "Spin it" else `Next spin in {Format.ago(nextIn)}`, function()
		if spinning then
			return
		end
		spinning = true
		local ok, code = request:InvokeServer("spin")
		if not ok then
			spinning = false
			Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		end
	end, if can then "good" else "off", UDim2.fromOffset(if can then 150 else 240, 48))
	b.LayoutOrder, b.TextSize = 4, 20
	local odds = {}
	for _, slice in StationRewards.WHEEL do
		table.insert(odds, `{slice.name} {slice.ppm / 10000}%`)
	end
	local line = Style.small(
		side,
		`{table.concat(odds, " · ")}. After {StationRewards.PITY} spins without it, the jackpot's chance doubles.`,
		11,
		C.muted,
		UDim2.new(1, 0, 0, 30)
	)
	line.TextWrapped, line.LayoutOrder = true, 5
	return disc
end

local wheelDisc: Frame? = nil
redraw.gifts = function()
	if spinning then
		return -- the wheel is turning: it redraws when it stops
	end
	Style.clear(gifts.body)
	Style.clear(gifts.chips)
	Style.clear(gifts.count)
	local now = Workspace:GetServerTimeNow()
	local midnight = (StationRewards.day(now) + 1) * 86400 - now
	Style.small(gifts.chips, `New at midnight UTC · {Format.ago(midnight)}`, 13, C.muted, UDim2.fromOffset(240, 20))
	local week, _, spin = giftsReady()
	local due = (if week then 1 else 0) + (if spin then 1 else 0)
	for _, d in StationRewards.MILESTONES do
		local r = S.profile.rewards
		due += if r.monthDays >= d and not table.find(r.monthGot, d) then 1 else 0
	end
	if due > 0 then
		Style.chip(gifts.count, `{due} to collect`, C.bad, Color3.new(1, 1, 1))
	end
	Hud.weekView()
	Hud.monthView()
	wheelDisc = Hud.wheelView()
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
App.ICON = ICON
App.iconsOf = iconsOf
App.giftsReady = giftsReady

return nil
