--!strict
-- The wave sheet, the result panel, the boon offer and the fight's top bar.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WaveRuns = require(Shared:WaitForChild("WaveRuns"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local RARITY_COLOUR = App.RARITY_COLOUR
local REFUSED = App.REFUSED
local screen = App.screen
local root = App.root
local send = App.send
local show = App.show
local coinsText = App.coinsText

-- Waves ---------------------------------------------------------------------------------------------------

S.wave = 1
-- The fight's panel: a low bar along the bottom, so it never covers the animals, centred on the screen and
-- clear of the power plates (SHANNON, 2026-11-19). What happened on the left, what to do next on the right.
local result = Style.frame(root, UDim2.new(1, -520, 0, 0), C.sand)
Style.round(result, 18)
Style.stroke(result, C.ink, 3)
result.Name = "WaveResult"
result.AutomaticSize = Enum.AutomaticSize.Y
result.AnchorPoint, result.Position, result.Visible = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -24), false
result.ZIndex = 5
Style.pad(result, 12)
local resultTitle: TextLabel, resultSub: TextLabel
local starRow: Frame, drops: Frame, boonRow: Frame, resultButtons: Frame
local starLabels: { TextLabel } = {}
do
	local resultColumns = Style.list(result, 14, true)
	resultColumns.VerticalAlignment = Enum.VerticalAlignment.Center
	local resultLimit = Instance.new("UISizeConstraint")
	resultLimit.MinSize, resultLimit.MaxSize = Vector2.new(480, 0), Vector2.new(840, 1000)
	resultLimit.Parent = result
	local function panelColumn(width: number, order: number, gap: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size, f.AutomaticSize, f.LayoutOrder = UDim2.new(width, -7, 0, 0), Enum.AutomaticSize.Y, order
		Style.list(f, gap)
		f.Parent = result
		return f
	end
	local info, act = panelColumn(0.52, 1, 4), panelColumn(0.48, 2, 8)
	-- the title, with the stars won beside it (decision 0097): three, popping in one by one
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size, titleRow.LayoutOrder = UDim2.new(1, 0, 0, 36), 1
	titleRow.Parent = info
	resultTitle = Style.text(titleRow, "", 24, C.text, UDim2.new(1, -136, 1, 0))
	starRow = Instance.new("Frame")
	starRow.BackgroundTransparency = 1
	starRow.AnchorPoint, starRow.Position, starRow.Size, starRow.Visible =
		Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0, 132, 1, 0), false
	Style.list(starRow, 4, true)
	starRow.Parent = titleRow
	for i = 1, 3 do
		local star = Style.text(starRow, "★", 34, C.off, UDim2.fromOffset(40, 36))
		star.TextXAlignment, star.LayoutOrder = Enum.TextXAlignment.Center, i
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color = 3, C.ink
		edge.Parent = star
		local size = Instance.new("UIScale")
		size.Parent = star
		starLabels[i] = star
	end
	resultSub = Style.text(info, "", 14, C.muted)
	resultSub.LayoutOrder = 2
	resultSub.TextWrapped, resultSub.AutomaticSize = true, Enum.AutomaticSize.Y
	drops = Instance.new("Frame")
	drops.BackgroundTransparency = 1
	drops.Size, drops.LayoutOrder = UDim2.new(1, 0, 0, 26), 3
	Style.list(drops, 14, true)
	drops.Parent = info
	-- after a win in a run, three boons to pick from, in a panel of their own in the middle of the screen
	-- (SHANNON, 2026-11-24): picking one starts the next wave (decision 0098)
	local boons = Style.frame(root, UDim2.fromOffset(680, 0), C.sand)
	boons.Name, boons.AutomaticSize, boons.ZIndex, boons.Visible = "BoonPanel", Enum.AutomaticSize.Y, 8, false
	boons.AnchorPoint, boons.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42)
	Style.round(boons, 20)
	Style.stroke(boons, C.ink, 3)
	Style.pad(boons, 16)
	Style.list(boons, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local boonsTitle = Style.text(boons, "Pick a boon", 26, C.text, UDim2.new(1, 0, 0, 32))
	boonsTitle.Name, boonsTitle.LayoutOrder, boonsTitle.TextXAlignment = "Title", 1, Enum.TextXAlignment.Center
	local votes = Style.text(boons, "", 14, C.muted, UDim2.new(1, 0, 0, 18))
	votes.Name, votes.LayoutOrder, votes.TextXAlignment = "Votes", 3, Enum.TextXAlignment.Center
	boonRow = Instance.new("Frame")
	boonRow.BackgroundTransparency = 1
	boonRow.Size, boonRow.LayoutOrder, boonRow.Visible = UDim2.new(1, 0, 0, 132), 2, false
	Style.list(boonRow, 10, true)
	boonRow.Parent = boons
	-- while a wave is fought: only a Skip button on the right (the wave is at the top: the stage strip)
	local skip = Style.button(root, "Skip ▶", function()
		local b = root:FindFirstChild("SkipWave")
		if b then
			(b :: GuiObject).Visible = false
		end
		send("wave_done") -- the pay is settled already: the result shows at once
	end, "ghost", UDim2.fromOffset(150, 52))
	skip.Name, skip.Visible, skip.ZIndex = "SkipWave", false, 5
	skip.AnchorPoint, skip.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.36, 0)
	resultButtons = Instance.new("Frame")
	resultButtons.BackgroundTransparency = 1
	resultButtons.Size, resultButtons.LayoutOrder = UDim2.new(1, 0, 0, 44), 2
	Style.list(resultButtons, 8, true)
	resultButtons.Parent = act
end
-- A big title that fades as a fight begins: the wave, and who is in it.
local announce: (n: number) -> ()
do -- the banner's labels are its own (the chunk's 200 locals: see Hud)
	local banner = Style.text(root, "", 56, C.text, UDim2.new(1, 0, 0, 70))
	-- high and brief (SHANNON, 2026-11-24): it must not hide the enemies walking in
	banner.AnchorPoint, banner.Position, banner.TextTransparency = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.17), 1
	banner.TextXAlignment, banner.ZIndex = Enum.TextXAlignment.Center, 6
	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Thickness, bannerStroke.Transparency = 4, 1
	bannerStroke.Parent = banner
	local bannerSub = Style.text(root, "", 22, C.muted, UDim2.new(1, 0, 0, 30))
	bannerSub.AnchorPoint, bannerSub.Position, bannerSub.TextTransparency =
		Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.17), 1
	bannerSub.TextXAlignment, bannerSub.ZIndex = Enum.TextXAlignment.Center, 6
	bannerSub.Position += UDim2.fromOffset(0, 66)
	local announced = 0
	announce = function(n: number)
		announced += 1
		local mine = announced
		local boss = n % LevelRules.BOSS_EVERY == 0
		local names = {}
		local counts, order = {}, {}
		for _, e in LevelRules.enemies(n) do
			local name = (if e.elite then "Elite " else "") .. (StationConfig.foe(e.s) :: StationConfig.Foe).name
			if counts[name] == nil then
				table.insert(order, name)
			end
			counts[name] = (counts[name] or 0) + 1
		end
		for _, name in order do
			table.insert(names, if counts[name] > 1 then `{name} x{counts[name]}` else name)
		end
		banner.Text = if boss then `BOSS WAVE {n}` else `WAVE {n}`
		banner.TextColor3 = if boss then C.bad else C.text
		bannerSub.Text = table.concat(names, "  -  ")
		banner.TextTransparency, bannerStroke.Transparency, bannerSub.TextTransparency = 0, 0, 0
		task.delay(1.1, function()
			if announced ~= mine then
				return
			end
			local fade = TweenInfo.new(0.35)
			TweenService:Create(banner, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(bannerStroke, fade, { Transparency = 1 }):Play()
			TweenService:Create(bannerSub, fade, { TextTransparency = 1 }):Play()
		end)
	end
end

-- What hatched, and how rare it is (decision 0078): its rarity pops up big in its colour, over the
-- animal's name and, for a rare find, how few eggs give one. A rarer hatch pops bigger and shakes.
local showRarity: (a: any) -> ()
do -- the reveal's labels are its own (the chunk's 200 locals: see Hud)
	local reveal = Style.text(root, "", 64, C.text, UDim2.new(1, 0, 0, 80))
	reveal.AnchorPoint, reveal.Position, reveal.TextTransparency = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.3), 1
	reveal.TextXAlignment, reveal.ZIndex = Enum.TextXAlignment.Center, 7
	local revealStroke = Instance.new("UIStroke")
	revealStroke.Thickness, revealStroke.Transparency, revealStroke.Color = 5, 1, Color3.fromRGB(20, 16, 30)
	revealStroke.Parent = reveal
	local revealScale = Instance.new("UIScale")
	revealScale.Parent = reveal
	local revealSub = Style.text(root, "", 24, C.text, UDim2.new(1, 0, 0, 60))
	revealSub.AnchorPoint, revealSub.TextTransparency = Vector2.new(0.5, 0), 1
	revealSub.Position = UDim2.new(0.5, 0, 0.3, 46)
	revealSub.TextXAlignment, revealSub.ZIndex = Enum.TextXAlignment.Center, 7
	local revealSubStroke = Instance.new("UIStroke")
	revealSubStroke.Thickness, revealSubStroke.Transparency, revealSubStroke.Color = 3, 1, Color3.fromRGB(20, 16, 30)
	revealSubStroke.Parent = revealSub
	local revealed = 0
	local BIG: { [string]: number } = {
		common = 0,
		uncommon = 0,
		rare = 1,
		epic = 1,
		legendary = 2,
		mythic = 3,
		divine = 3,
		celestial = 4,
		secret = 5,
	}
	showRarity = function(a: any)
		revealed += 1
		local mine = revealed
		local rarity = StationRules.rarity(a)
		local big = BIG[rarity] or 0
		reveal.Text = string.upper(rarity) .. string.rep("!", big)
		reveal.TextColor3 = RARITY_COLOUR[rarity] or C.text
		local lines = { StationTrade.nameOf(a) }
		local def = StationConfig.egg(a.egg or "")
		if a.v and def then
			for _, drop in def.rare do
				if drop.v == a.v then
					table.insert(
						lines,
						`Only 1 in {Format.commas(StationRules.PPM // drop.ppm)} {def.name}s hatches one`
					)
				end
			end
		end
		if StationRules.coatOf(a) then
			table.insert(lines, `A {string.lower((StationRules.coatOf(a) :: any).name)} coat!`)
		end
		revealSub.Text = table.concat(lines, "\n")
		require(script.Parent:WaitForChild("RevealCard")).show( -- the animal's picture under the words
			screen,
			StationRules.assetOf(a.s, a.v),
			a.rainbow,
			RARITY_COLOUR[rarity] or C.text,
			big,
			2.6 + big * 0.6
		)
		revealSub.TextColor3 = if StationRules.coatOf(a) then Color3.fromRGB(255, 225, 100) else C.text
		reveal.TextTransparency, revealStroke.Transparency = 0, 0
		revealSub.TextTransparency, revealSubStroke.Transparency = 1, 1
		revealScale.Scale, reveal.Rotation = 0.2, 0
		local pop = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(revealScale, pop, { Scale = 1 + big * 0.12 }):Play()
		task.delay(0.35, function()
			if revealed ~= mine then
				return
			end
			TweenService:Create(revealSub, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
			TweenService:Create(revealSubStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
			for i = 1, big * 6 do -- a rarer hatch shakes
				if revealed ~= mine then
					return
				end
				reveal.Rotation = (if i % 2 == 0 then 1 else -1) * big * 1.5 * (1 - i / (big * 6 + 1))
				task.wait(0.04)
			end
			reveal.Rotation = 0
		end)
		task.delay(2.6 + big * 0.6, function()
			if revealed ~= mine then
				return
			end
			local fade = TweenInfo.new(0.7)
			for _, x in { reveal, revealSub } do
				TweenService:Create(x, fade, { TextTransparency = 1 }):Play()
			end
			for _, x in { revealStroke, revealSubStroke } do
				TweenService:Create(x, fade, { Transparency = 1 }):Play()
			end
		end)
	end
end

local fight: (n: number) -> boolean
local began: (n: number) -> ()
local again = Style.button(resultButtons, "", function()
	fight(S.wave)
end, "primary", UDim2.new(0.5, -4, 1, 0))
local leave = Style.button(resultButtons, "Leave the arena", function()
	S.hideResult()
	S.music(nil)
	send("wave_done")
end, "ghost", UDim2.new(0.5, -4, 1, 0))
S.hideResult = function()
	result.Visible = false
	for _, name in { "BoonPanel", "SkipWave" } do
		local x = root:FindFirstChild(name)
		if x then
			(x :: GuiObject).Visible = false
		end
	end
end
local showStars: (n: number) -> ()
local coinBurst: () -> ()
local offerBoons: (ids: { string }, n: number) -> ()
local function buttons(showAgain: boolean)
	again.Visible = showAgain
	leave.Size = if showAgain then UDim2.new(0.5, -4, 1, 0) else UDim2.fromScale(1, 1)
end

-- The stars pop in one by one: gold for each won, pale for the rest (decision 0097).
showStars = function(n: number)
	starRow.Visible = true
	for i, star in starLabels do
		star.TextColor3, star.TextTransparency = C.off, 1
		local size = star:FindFirstChildOfClass("UIScale") :: UIScale
		size.Scale = 0.2
		task.delay(0.35 * i, function()
			star.TextColor3 = if i <= n then C.gold else C.off
			star.TextTransparency = 0
			TweenService:Create(size, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = if i <= n then 1.15 else 0.9,
			}):Play()
			if i <= n then
				Style.sound("tab")
			end
		end)
	end
end

-- Coins burst out of the result and fly to the coin counter (the counter itself follows the save).
coinBurst = function()
	Style.sound("claim")
	local from = result.AbsolutePosition + Vector2.new(result.AbsoluteSize.X / 2, 30)
	local to = coinsText.AbsolutePosition + Vector2.new(0, coinsText.AbsoluteSize.Y / 2)
	for i = 1, 14 do
		local coin = Instance.new("Frame")
		coin.Size, coin.AnchorPoint, coin.BackgroundColor3 = UDim2.fromOffset(18, 18), Vector2.new(0.5, 0.5), C.gold
		coin.ZIndex = 12
		Style.round(coin, 9)
		Style.stroke(coin, C.ink, 2)
		local spread = Vector2.new(math.random(-140, 140), math.random(-110, -20))
		coin.Position = UDim2.fromOffset(from.X, from.Y)
		coin.Parent = screen
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(coin, out, { Position = UDim2.fromOffset(from.X + spread.X, from.Y + spread.Y) }):Play()
		task.delay(0.3 + i * 0.035, function()
			local fly = TweenService:Create(
				coin,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(10, 10) }
			)
			fly.Completed:Once(function()
				coin:Destroy()
			end)
			fly:Play()
		end)
	end
end

-- Three boons as cards (decision 0098); a rare one is edged in gold. Picking one starts wave `n`.
offerBoons = function(ids: { string }, n: number)
	Style.clear(boonRow)
	boonRow.Visible = true
	local panel = boonRow.Parent :: GuiObject
	panel.Visible = true
	local heading = panel:FindFirstChild("Title") :: TextLabel?
	if heading then
		heading.Text = `Pick a boon for wave {n}`
	end
	local votes = panel:FindFirstChild("Votes") :: TextLabel?
	if votes then
		votes.Text = ""
	end
	for k, id in ids do
		local boon = WaveRuns.boon(id)
		if boon then
			local card = Style.button(boonRow, "", function()
				if not boonRow.Visible then -- a second click while the first is on its way
					return
				end
				-- gone the moment it is picked (SHANNON, 2026-11-24); back only if the server refuses it
				boonRow.Visible, panel.Visible, result.Visible = false, false, false -- the next wave takes a moment to walk out
				local ok, code = request:InvokeServer("boon", id)
				if not ok then
					boonRow.Visible, panel.Visible, result.Visible = true, true, true
					Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
				end
			end, if boon.rare then "primary" else "ghost", UDim2.new(1 / 3, -7, 1, 0))
			card.Name, card.LayoutOrder = boon.name, k
			local title = Style.text(card, boon.name, 20, C.text, UDim2.new(1, -12, 0, 26))
			title.Position, title.TextXAlignment = UDim2.fromOffset(6, 12), Enum.TextXAlignment.Center
			local words = Style.text(card, boon.text, 15, C.muted, UDim2.new(1, -16, 0, 52))
			words.Position, words.TextXAlignment, words.TextWrapped =
				UDim2.fromOffset(8, 42), Enum.TextXAlignment.Center, true
			local go = Style.text(card, `Wave {n} ▶`, 12, C.text, UDim2.new(1, -12, 0, 16))
			go.Position, go.TextXAlignment = UDim2.new(0, 6, 1, -20), Enum.TextXAlignment.Center
		end
	end
end

fight = function(n: number): boolean
	local ok, code = request:InvokeServer("wave", n)
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		return false
	end
	began(n)
	return true
end

began = function(n: number)
	S.wave = n
	show(nil)
	resultTitle.Text, resultSub.Text = `Wave {n}`, "The fight is on..."
	Style.clear(drops)
	Style.clear(boonRow)
	starRow.Visible, boonRow.Visible, drops.Visible = false, false, false
	S.hideResult()
	local skip = root:FindFirstChild("SkipWave")
	if skip then
		(skip :: GuiObject).Visible = true
	end
	announce(n)
	S.music(if n % LevelRules.BOSS_EVERY == 0 then "boss" else "fight")
end

-- The power plates' column, bottom right (decision 0092), with the shield at its top (decision 0097).
local plates = Instance.new("Frame")
plates.Name = "PowerPlates"
plates.BackgroundTransparency = 1
plates.AnchorPoint, plates.Position = Vector2.new(1, 1), UDim2.new(1, -14, 1, -20)
plates.Size, plates.AutomaticSize = UDim2.fromOffset(224, 0), Enum.AutomaticSize.Y
plates.Visible = false
plates.ZIndex = 4
local plateList = Style.list(plates, 12)
plateList.VerticalAlignment = Enum.VerticalAlignment.Bottom
plates.Parent = root
plateList.HorizontalAlignment = Enum.HorizontalAlignment.Center

App.result = result
App.resultTitle = resultTitle
App.resultSub = resultSub
App.drops = drops
App.boonRow = boonRow
App.showRarity = showRarity
App.fight = fight
App.began = began
App.again = again
App.leave = leave
App.showStars = showStars
App.coinBurst = coinBurst
App.offerBoons = offerBoons
App.buttons = buttons
App.plates = plates

return nil
