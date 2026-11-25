--!strict
-- The wave sheet, the result panel, the boon offer and the fight's top bar.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
local N = Style.N
local Hud = App.Hud
local RARITY_COLOUR = App.RARITY_COLOUR
local REFUSED = App.REFUSED
local screen = App.screen
local root = App.root
local send = App.send
local show = App.show
local coinsText = App.coinsText

-- Waves ---------------------------------------------------------------------------------------------------

S.wave = 1
-- Between waves (decision 0114, the Result board), in glass: what happened across the top, the boon cards
-- in the middle (or how the run ended), and one line along the bottom with what the wave paid, the pot and
-- the way out. `result` is that line; the head and the middle follow its Visible.
local result = Style.glass(root, UDim2.new(1, -32, 0, 60), 14)
result.Name = "WaveResult"
result.AnchorPoint, result.Position, result.Visible = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), false
result.ZIndex = 5
local resultTitle: TextLabel, resultSub: TextLabel
local starRow: Frame, drops: Frame, boonRow: Frame, resultButtons: Frame
local starLabels: { TextLabel } = {}
local pickBoon: { () -> () } = {} -- the offered cards, for the keys 1 to 3
do
	local DARK = Color3.fromRGB(42, 22, 64)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1100, 60)
	limit.Parent = result
	local function row(parent: Instance, gap: number, align: Enum.HorizontalAlignment): Frame
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		local l = Style.list(f, gap, true)
		l.VerticalAlignment, l.HorizontalAlignment = Enum.VerticalAlignment.Center, align
		f.Parent = parent
		return f
	end
	-- the head: the title, then the stars beside the time and the best hitter
	local head = Instance.new("Frame")
	head.Name, head.BackgroundTransparency, head.Visible, head.ZIndex = "WaveHead", 1, false, 5
	head.AnchorPoint, head.Position, head.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 14), UDim2.fromOffset(900, 100)
	head.Parent = root
	resultTitle = Style.text(head, "", 40, N.gold, UDim2.new(1, 0, 0, 46))
	resultTitle.TextXAlignment = Enum.TextXAlignment.Center
	Style.stroke(resultTitle, DARK, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local under = row(head, 14, Enum.HorizontalAlignment.Center)
	under.Position, under.Size = UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 44)
	starRow = row(under, 2, Enum.HorizontalAlignment.Center)
	starRow.Size, starRow.Visible, starRow.LayoutOrder = UDim2.fromOffset(104, 36), false, 1
	for i = 1, 3 do
		local star = Style.text(starRow, "★", 30, N.key, UDim2.fromOffset(32, 36))
		star.TextXAlignment, star.LayoutOrder = Enum.TextXAlignment.Center, i
		Style.stroke(star, DARK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		local size = Instance.new("UIScale")
		size.Parent = star
		starLabels[i] = star
	end
	resultSub = Style.small(under, "", 14, N.text, UDim2.fromOffset(0, 40))
	resultSub.AutomaticSize, resultSub.TextWrapped, resultSub.LayoutOrder = Enum.AutomaticSize.X, false, 2
	Style.stroke(resultSub, DARK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- the line along the bottom: what it paid, the run, then the buttons
	local paid = row(result, 18, Enum.HorizontalAlignment.Left)
	paid.Position, paid.Size, paid.ClipsDescendants = UDim2.fromOffset(16, 0), UDim2.new(1, -440, 1, 0), true
	drops = row(paid, 16, Enum.HorizontalAlignment.Left)
	drops.Size, drops.AutomaticSize, drops.LayoutOrder = UDim2.fromOffset(0, 28), Enum.AutomaticSize.X, 1
	local runLine = Style.small(paid, "", 14, N.muted, UDim2.fromOffset(0, 28))
	runLine.AutomaticSize, runLine.TextWrapped, runLine.LayoutOrder = Enum.AutomaticSize.X, false, 2
	function Hud.runLine(text: string)
		runLine.Text = text
	end
	resultButtons = row(result, 8, Enum.HorizontalAlignment.Right)
	resultButtons.AnchorPoint, resultButtons.Position = Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, 0)
	resultButtons.Size = UDim2.fromOffset(420, 44)

	-- the middle: three boons to pick from after a win in a run (decision 0098); picking one starts the next
	-- wave. A party votes for seven seconds.
	local boons = Instance.new("Frame")
	boons.Name, boons.BackgroundTransparency, boons.ZIndex, boons.Visible = "BoonPanel", 1, 8, false
	boons.AnchorPoint, boons.Position, boons.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 116), UDim2.fromOffset(880, 340)
	Style.list(boons, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
	boons.Parent = root
	local boonsTitle = Style.text(boons, "Pick a boon", 20, N.text, UDim2.new(1, 0, 0, 26))
	boonsTitle.Name, boonsTitle.LayoutOrder, boonsTitle.TextXAlignment = "Title", 1, Enum.TextXAlignment.Center
	-- a party's vote (STATION-160): a ring that empties over the vote's seconds, beside the heading
	local ring, setRing = Style.pie(boonsTitle, 34, N.gold, N.key)
	ring.Name, ring.AnchorPoint, ring.Position, ring.Visible =
		"VoteRing", Vector2.new(1, 0.5), UDim2.new(1, -150, 0.5, 0), false
	local hole = Style.frame(ring, UDim2.fromOffset(24, 24), N.glass)
	hole.AnchorPoint, hole.Position, hole.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 3
	Style.round(hole, 12)
	local ringText = Style.small(hole, "", 12, N.text, UDim2.fromScale(1, 1))
	ringText.TextXAlignment, ringText.ZIndex = Enum.TextXAlignment.Center, 4
	local ringEnd = 0
	App.voteClock = function(seconds: number) -- start the ring: it runs out in `seconds`
		ringEnd = os.clock() + seconds
		ring.Visible = true
		local total = seconds
		task.spawn(function()
			while ring.Visible and boons.Visible do
				local left = ringEnd - os.clock()
				if left <= 0 then
					break
				end
				setRing(left / total)
				ringText.Text = tostring(math.ceil(left))
				RunService.RenderStepped:Wait()
			end
			ring.Visible = false
		end)
	end
	Style.stroke(boonsTitle, DARK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	boonRow = row(boons, 16, Enum.HorizontalAlignment.Center)
	boonRow.Size, boonRow.LayoutOrder, boonRow.Visible = UDim2.new(1, 0, 0, 276), 2, false
	local votes = Style.small(boons, "", 13, N.muted, UDim2.new(1, 0, 0, 18))
	votes.Name, votes.LayoutOrder, votes.TextXAlignment = "Votes", 3, Enum.TextXAlignment.Center

	-- how a run ended, in the same place: where it stopped, what it banked, and one thing to do about it
	local over = Style.glass(root, UDim2.fromOffset(540, 232), 16)
	over.Name, over.ZIndex, over.Visible = "RunOver", 8, false
	over.AnchorPoint, over.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 130)
	local overTitle = Style.text(over, "", 24, N.text, UDim2.new(1, -150, 0, 30))
	overTitle.Position = UDim2.fromOffset(16, 12)
	local best = Style.chip(over, "NEW BEST", N.gold, DARK)
	best.AnchorPoint, best.Position = Vector2.new(1, 0), UDim2.new(1, -16, 0, 14)
	local tiles: { { big: TextLabel, small: TextLabel } } = {}
	for k = 1, 3 do
		local tile = Style.frame(over, UDim2.new(1 / 3, -16, 0, 58), Color3.new(1, 1, 1))
		tile.BackgroundTransparency = 0.93
		tile.Position = UDim2.new((k - 1) / 3, 16 - (k - 1) * 4, 0, 52)
		Style.round(tile, 10)
		local big = Style.text(tile, "", 22, Color3.fromRGB(255, 210, 122), UDim2.new(1, -20, 0, 26))
		big.Position = UDim2.fromOffset(10, 6)
		local small = Style.small(tile, "", 12, N.muted, UDim2.new(1, -20, 0, 16))
		small.Position = UDim2.fromOffset(10, 34)
		tiles[k] = { big = big, small = small }
	end
	local advice = Style.frame(over, UDim2.new(1, -32, 0, 62), C.sand)
	advice.Position = UDim2.fromOffset(16, 120)
	Style.round(advice, 12)
	Style.stroke(advice, C.ink, 3)
	Style.small(advice, "WHAT TO DO ABOUT IT", 11, C.muted, UDim2.new(1, -24, 0, 14)).Position = UDim2.fromOffset(12, 7)
	local adviceText = Style.text(advice, "", 15, C.text, UDim2.new(1, -24, 0, 36))
	adviceText.Position = UDim2.fromOffset(12, 22)
	local train = Style.button(over, "Train it now", function()
		S.hideResult()
		S.music(nil)
		send("wave_done")
		show("animals")
	end, "night", UDim2.new(1, -32, 0, 36))
	train.Position, train.TextSize = UDim2.fromOffset(16, 188), 15
	-- `stats` are three pairs of a number and what it counts; `tip` the advice; `newBest` shows the tag.
	function Hud.runOver(title: string, stats: { { string } }, tip: string, newBest: boolean)
		overTitle.Text, adviceText.Text, best.Visible = title, tip, newBest
		over.Position = UDim2.new(0.5, 0, 0, if Style.compact(root.Size.Y.Offset) then 104 else 130)
		boons.Visible = false
		for k, tile in tiles do
			tile.big.Text, tile.small.Text = stats[k][1], stats[k][2]
		end
		over.Visible = true
	end
	result:GetPropertyChangedSignal("Visible"):Connect(function()
		head.Visible = result.Visible
		if not result.Visible then
			over.Visible = false
		end
	end)

	-- while a wave is fought: only Skip, top right (the wave is at the top: the stage strip)
	local skip = Style.button(root, "Skip ▶", function()
		local b = root:FindFirstChild("SkipWave")
		if b then
			(b :: GuiObject).Visible = false
		end
		send("wave_done") -- the pay is settled already: the result shows at once
	end, "night", UDim2.fromOffset(112, 44))
	skip.Name, skip.Visible, skip.ZIndex, skip.TextSize = "SkipWave", false, 5, 16
	skip.AnchorPoint, skip.Position = Vector2.new(1, 0), UDim2.new(1, -16, 0, 16)

	UserInputService.InputBegan:Connect(function(input, typing)
		local k = table.find({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }, input.KeyCode)
		if k and not typing and boonRow.Visible and boons.Visible and pickBoon[k] then
			Style.sound("press")
			pickBoon[k]()
		end
	end)
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
local showRarity: (a: any) -> number -- how long the reveal shows
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
		eternal = 6, -- decision 0117
	}
	showRarity = function(a: any): number
		revealed += 1
		local mine = revealed
		local rarity = StationRules.rarity(a)
		local big = BIG[rarity] or 0
		reveal.Text = string.upper(rarity) .. string.rep("!", big)
		reveal.TextColor3 = RARITY_COLOUR[rarity] or C.text
		local lines = { `{StationTrade.nameOf(a)} · {App.ROLE_NAME[StationRules.role(a)] or ""}` }
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
		-- scaled by rarity (SHANNON's pick, STATION-160): a quick pop for common and uncommon, the full moment from
		-- rare, and the screen shakes from mythic
		local rank = App.RANK[rarity] or 0
		local quick = rank <= (App.RANK.uncommon or 2)
		require(script.Parent:WaitForChild("RevealCard")).show( -- the animal's picture under the words
			screen,
			StationRules.assetOf(a.s, a.v),
			a.rainbow,
			RARITY_COLOUR[rarity] or C.text,
			big,
			if quick then 1.2 else 2.6 + big * 0.6,
			quick
		)
		if rank >= (App.RANK.mythic or 6) then
			local camera = workspace.CurrentCamera
			local untilAt = os.clock() + 0.5 + big * 0.15
			RunService:BindToRenderStep("HatchShake", Enum.RenderPriority.Camera.Value + 1, function()
				local left = untilAt - os.clock()
				if left <= 0 or camera == nil then
					RunService:UnbindFromRenderStep("HatchShake")
					return
				end
				local amp = math.min(1, left * 2) * (0.15 + big * 0.05)
				camera.CFrame *= CFrame.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
			end)
		end
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
		task.delay(if quick then 1.2 else 2.6 + big * 0.6, function()
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
		return if quick then 1.9 else 3.3 + big * 0.6
	end
end

local fight: (n: number) -> boolean
local began: (n: number) -> ()
local again = Style.button(resultButtons, "", function()
	fight(S.wave)
end, "gold", UDim2.fromOffset(200, 40))
again.LayoutOrder, again.TextSize = 1, 16
local leave = Style.button(resultButtons, "Leave the arena", function()
	S.hideResult()
	S.music(nil)
	send("wave_done")
end, "night", UDim2.fromOffset(210, 40))
leave.LayoutOrder, leave.TextSize = 2, 15
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
local offerBoons: (ids: { string }, n: number, have: { string }?, twice: boolean?) -> ()
local function buttons(showAgain: boolean)
	again.Visible = showAgain
end

-- The stars pop in one by one: gold for each won, pale for the rest (decision 0097).
showStars = function(n: number)
	starRow.Visible = true
	for i, star in starLabels do
		star.TextColor3, star.TextTransparency = N.key, 1
		local size = star:FindFirstChildOfClass("UIScale") :: UIScale
		size.Scale = 0.2
		task.delay(0.35 * i, function()
			star.TextColor3 = if i <= n then N.gold else N.key
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

-- Three boons as glass cards (decision 0098): each says what it does and how many of it the run already
-- has (`have`: the boons picked so far), since a boon is small and the stack is what counts. A rare one is
-- edged in gold. Picking one (a click, or the key on its corner) starts wave `n`.
offerBoons = function(ids: { string }, n: number, have: { string }?, twice: boolean?)
	Style.clear(boonRow)
	table.clear(pickBoon)
	boonRow.Visible = true
	local short = Style.compact(root.Size.Y.Offset) -- a phone: shorter cards, so the line under them stays clear
	boonRow.Size = UDim2.new(1, 0, 0, if short then 200 else 276)
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
			local owned = 0
			for _, b in have or {} do
				owned += if b == id then 1 else 0
			end
			local adds = 1
			local function pick()
				if not boonRow.Visible then -- a second click while the first is on its way
					return
				end
				if (S.party or 1) > 1 then -- a party's vote: the cards stay to show who picked what (STATION-160)
					local ok, code = request:InvokeServer("boon", id)
					if not ok then
						Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
					end
					return
				end
				-- gone the moment it is picked (SHANNON, 2026-11-24); back only if the server refuses it
				boonRow.Visible, panel.Visible, result.Visible = false, false, false -- the next wave takes a moment to walk out
				local ok, code = request:InvokeServer("boon", id)
				if not ok then
					boonRow.Visible, panel.Visible, result.Visible = true, true, true
					Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
				end
			end
			pickBoon[k] = pick
			local ultra = boon.tier == "ultra"
			local card = Style.button(
				boonRow,
				"",
				pick,
				if boon.rare then "nightHot" else "night",
				UDim2.fromOffset(if short then 236 else 268, if short then 196 else 272)
			)
			card.Name, card.LayoutOrder = boon.name, k
			card:SetAttribute("Boon", id)
			Style.radius(card, 18)
			local dots = Instance.new("Frame") -- who voted for it (a party's vote, STATION-160)
			dots.Name, dots.BackgroundTransparency, dots.ZIndex = "Dots", 1, 5
			dots.AnchorPoint, dots.Position, dots.Size =
				Vector2.new(1, 0), UDim2.new(1, -10, 0, 10), UDim2.fromOffset(120, 28) -- top right, across from the key cap
			Style.list(dots, 4, true).HorizontalAlignment = Enum.HorizontalAlignment.Right
			dots.Parent = card
			Style.key(card, tostring(k), true).Position = UDim2.fromOffset(10, 10)
			-- the boon's picture (Style.ICONS `boon_<id>`), or its stack written large until it has one
			local side = if short then 56 else 92
			local tile = Style.frame(card, UDim2.fromOffset(side, side), if boon.rare then N.gold else N.main)
			tile.AnchorPoint, tile.Position, tile.ZIndex =
				Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, if short then 12 else 20), 2
			Style.round(tile, 20)
			local picture = Style.image(`boon_{id}`)
			if picture ~= "" then
				local icon = Style.icon(tile, `boon_{id}`, side - 10)
				icon.AnchorPoint, icon.Position, icon.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 3
			end
			local stack = Style.text(
				tile,
				`x{owned + adds}`,
				if picture ~= "" then 16 else 30,
				if boon.rare then Color3.fromRGB(42, 22, 64) else N.text,
				if picture ~= "" then UDim2.fromOffset(34, 20) else UDim2.fromScale(1, 1)
			)
			stack.TextXAlignment, stack.ZIndex = Enum.TextXAlignment.Center, 4
			if picture ~= "" then -- the stack in the picture's corner
				stack.AnchorPoint, stack.Position = Vector2.new(1, 1), UDim2.new(1, 6, 1, 4)
				Style.stroke(stack, Color3.fromRGB(42, 22, 64), 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				stack.TextColor3 = N.text
			end
			local top = if short then 72 else 120
			local title = Style.text(card, boon.name, 22, N.text, UDim2.new(1, -16, 0, 28))
			title.Position, title.TextXAlignment, title.ZIndex = UDim2.fromOffset(8, top), Enum.TextXAlignment.Center, 2
			local words = Style.text(card, boon.text, 16, Color3.fromRGB(255, 210, 122), UDim2.new(1, -24, 0, 44))
			words.Position, words.TextXAlignment, words.ZIndex =
				UDim2.fromOffset(12, top + 30), Enum.TextXAlignment.Center, 2
			local count = Style.small(
				card,
				if owned > 0
					then `You have {owned}. This makes {owned + adds}.`
					elseif twice then "Twin Picks: you pick two."
					else "Your first of these.",
				13,
				N.muted,
				UDim2.new(1, -16, 0, 18)
			)
			count.Position, count.TextXAlignment, count.ZIndex = UDim2.new(0, 8, 1, -34), Enum.TextXAlignment.Center, 2
			if boon.rare then
				local tag = Style.chip(
					card,
					if ultra then "ULTRA LUCKY" else "LUCKY",
					if ultra then Color3.new(1, 1, 1) else N.gold,
					Color3.fromRGB(42, 22, 64)
				)
				tag.AnchorPoint, tag.Position, tag.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0), 4
				if ultra then -- the rainbow (SHANNON, 2026-11-25): the chip, the picture's tile and a turning edge
					for _, on in { tag, tile } do
						local colours = Instance.new("UIGradient")
						colours.Color, colours.Rotation = App.RAINBOW, 30
						colours.Parent = on
					end
					local face = card:FindFirstChild("Face") or card -- the edge drawn is the face's (Style.button)
					local edge = face:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
					edge.Thickness, edge.ApplyStrokeMode, edge.Color =
						5, Enum.ApplyStrokeMode.Border, Color3.new(1, 1, 1)
					edge.Parent = face
					local turn = Instance.new("UIGradient")
					turn.Color = App.RAINBOW
					turn.Parent = edge
					local spin: RBXScriptConnection
					spin = RunService.RenderStepped:Connect(function()
						if card.Parent == nil then
							spin:Disconnect()
							return
						end
						turn.Rotation = (os.clock() * 90) % 360
					end)
					Style.sound("claim")
				end
			end
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

-- The team's plates, along the bottom (decision 0114): the power bar over a row of plates. HudFight fills it.
local plates = Instance.new("Frame")
plates.Name = "PowerPlates"
plates.BackgroundTransparency = 1
plates.AnchorPoint, plates.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12)
plates.Size, plates.AutomaticSize = UDim2.fromOffset(900, 0), Enum.AutomaticSize.Y
plates.Visible = false
plates.ZIndex = 4
local plateList = Style.list(plates, 16)
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
-- A party's votes (the server's "votes"): each voter's avatar as a dot on the card they picked.
App.showVotes = function(picks: { { user: number, id: string } })
	for _, card in boonRow:GetChildren() do
		local dots = card:FindFirstChild("Dots")
		if dots then
			Style.clear(dots)
			for _, p in picks do
				if p.id == card:GetAttribute("Boon") then
					local face = Instance.new("ImageLabel")
					face.Size, face.BackgroundColor3, face.ZIndex = UDim2.fromOffset(26, 26), N.key, 6
					face.Image = `rbxthumb://type=AvatarHeadShot&id={p.user}&w=48&h=48`
					Style.round(face, 13)
					Style.stroke(face, N.gold, 2)
					face.Parent = dots
				end
			end
		end
	end
end
App.buttons = buttons
App.plates = plates

return nil
