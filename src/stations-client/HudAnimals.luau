--!strict
-- The Animals and Eggs sheets: a card for each animal (portrait, six stat buttons, team, lock, release,
-- fuse) and for each egg, with the live text of whatever is training or hatching.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
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
local ROLE_NAME = App.ROLE_NAME
local GROUP_NAME = App.GROUP_NAME
local STAT_SHORT = App.STAT_SHORT
local RAINBOW = App.RAINBOW
local screen = App.screen
local tickers = App.tickers
local eggTickers = App.eggTickers
local Hud = App.Hud
local send = App.send
local nameOf = App.nameOf
local live = App.live
local redraw = App.redraw
local show = App.show
local animals = App.animals
local eggs = App.eggs

-- Animals (decision 0091) ---------------------------------------------------------------------------
-- Tabs filter one grid of small cards: a portrait, the name, the two best stats and a rarity band.
-- Tapping a card opens its detail in the same menu: six stat tiles (tap to train or stop) and the team.

local function darker(colour: Color3): Color3 -- a portrait's background: the rarity, pale
	return colour:Lerp(C.sand, 0.55)
end

local animalsTab = "team"
local chosen: number? = nil -- the id of the animal whose detail is open

local function corner(parent: Instance, text: string, colour: Color3)
	local b = Style.chip(parent, text, colour, Color3.new(1, 1, 1))
	b.Position, b.ZIndex = UDim2.fromOffset(8, 8), 3
	b.TextSize = 13
	b.Size = UDim2.fromOffset(0, 22)
end

function Hud.bestTwo(a: any): string
	local s = live(a)
	local order = table.clone(StationConfig.STATS)
	table.sort(order, function(x, y)
		return StationRules.stat(s, x) > StationRules.stat(s, y)
	end)
	return `{STAT_SHORT[order[1]]} {StationRules.stat(s, order[1])}  {STAT_SHORT[order[2]]} {StationRules.stat(
		s,
		order[2]
	)}`
end

function Hud.animalCard(a: any, order: number)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local inTeam = table.find(S.profile.team, a.id) ~= nil
	local card = Style.button(animals.body, "", function()
		chosen = a.id
		redraw.animals()
	end, "ghost", UDim2.fromOffset(150, 206))
	card.Name, card.LayoutOrder = nameOf(a), order
	local view = Portrait.new(
		card,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(144, 132), background = darker(colour), rainbow = a.rainbow }
	)
	view.Position = UDim2.fromOffset(3, 3)
	Style.round(view, 10)
	if S.profile.titan == a.id then
		corner(card, "Titan", C.accent)
	elseif inTeam then
		corner(card, "Team", C.good)
	elseif a.at then
		corner(card, "Training", C.info)
	end
	local worn = StationRules.coatOf(a)
	if worn then
		local coat = Style.chip(card, string.upper(worn.name), Style.COAT[worn.id] or Color3.new(1, 1, 1))
		coat.Position, coat.ZIndex, coat.TextSize = UDim2.fromOffset(8, 106), 3, 12
		if Style.COAT[worn.id] == nil then -- rainbow, prismatic
			local colours = Instance.new("UIGradient")
			colours.Color = RAINBOW
			colours.Parent = coat
		end
	end
	local power = Style.chip(card, `⚡ {Format.commas(BattleRules.powerOf(live(a)))}`, C.ink, Color3.new(1, 1, 1))
	power.AnchorPoint, power.Position, power.ZIndex, power.TextSize = Vector2.new(1, 0), UDim2.new(1, -8, 0, 8), 3, 13
	power.Size = UDim2.fromOffset(0, 22)
	local name = Style.text(card, nameOf(a), 17, C.text, UDim2.new(1, -16, 0, 22))
	name.Position, name.TextTruncate = UDim2.fromOffset(8, 138), Enum.TextTruncate.AtEnd
	local best = Style.text(card, Hud.bestTwo(a), 13, C.muted, UDim2.new(1, -16, 0, 18))
	best.Position = UDim2.fromOffset(8, 160)
	local band = Style.frame(card, UDim2.new(1, -6, 0, 12), colour)
	band.Position = UDim2.new(0, 3, 1, -15)
	Style.round(band, 6)
	local tag = Style.text(band, string.upper(rarity), 10, C.ink, UDim2.fromScale(1, 1))
	tag.TextXAlignment = Enum.TextXAlignment.Center
end

function Hud.animalDetail(a: any)
	local sp = StationConfig.species(a.s)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local role = StationRules.role(a)
	local isTitan = role == StationConfig.TITAN
	local inTeam = table.find(S.profile.team, a.id) ~= nil or S.profile.titan == a.id

	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size, head.LayoutOrder = UDim2.new(1, -8, 0, 176), 1
	head.Parent = animals.body
	local view = Portrait.new(
		head,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(176, 170), background = darker(colour), rainbow = a.rainbow }
	)
	Style.round(view, 14)
	Style.stroke(view, C.ink, 3)
	local name = Style.text(head, StationTrade.nameOf(a), 30, C.text, UDim2.new(1, -196, 0, 36))
	name.Position, name.TextTruncate = UDim2.fromOffset(194, 2), Enum.TextTruncate.AtEnd
	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position, chips.Size = UDim2.fromOffset(194, 44), UDim2.new(1, -196, 0, 28)
	Style.list(chips, 8, true)
	chips.Parent = head
	Style.chip(chips, string.upper(rarity), colour)
	Style.chip(chips, `⚡ {Format.commas(BattleRules.powerOf(live(a)))} power`, C.ink, Color3.new(1, 1, 1))
	Style.chip(chips, `{ROLE_NAME[role] or "?"} · {GROUP_NAME[if sp then sp.group else ""] or "?"}`)
	if a.at then
		Style.chip(chips, "Training", C.info, Color3.new(1, 1, 1))
	elseif inTeam then
		Style.chip(chips, if isTitan then "Your Titan" else "In your team", C.good, Color3.new(1, 1, 1))
	else
		Style.chip(chips, "Resting")
	end
	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	-- two rows when Release and Fuse join them (decision 0112)
	buttons.Position, buttons.Size = UDim2.fromOffset(194, 76), UDim2.new(1, -196, 0, 100)
	Style.list(buttons, 6, true, true)
	buttons.Parent = head
	Style.button(buttons, "‹ Back", function()
		chosen = nil
		redraw.animals()
	end, "ghost", UDim2.fromOffset(100, 46))
	Style.button(buttons, if inTeam then "Leave team" elseif isTitan then "Join as Titan" else "Join team", function()
		send("team", a.id)
	end, if inTeam then "ghost" else "good", UDim2.fromOffset(160, 46))
	-- a locked animal can never go in a trade (decision 0099)
	Style.button(buttons, if a.locked then "🔒 Locked" else "Lock", function()
		send("lock", a.id)
	end, if a.locked then "primary" else "ghost", UDim2.fromOffset(120, 46))
	-- release for a few coins (a second click confirms), or fuse four of one into the next coat (decision 0112)
	if not inTeam and not a.at and not a.locked then
		local pay = (StationProgress.RELEASE_PAY[StationRules.rarity(a)] or 0) * (if a.coat then 2 else 1)
		local sure = false
		local release: TextButton
		release = Style.button(buttons, "Release", function()
			if not sure then
				sure = true
				release.Text = `Sure? +{pay}`
				return
			end
			send("release", a.id)
			chosen = nil
		end, "ghost", UDim2.fromOffset(130, 46))
		local mates = StationProgress.fusable(S.profile, a)
		if #mates >= StationProgress.FUSE then
			Style.button(buttons, "Fuse 4 ✦", function()
				send("fuse", table.unpack(mates, 1, StationProgress.FUSE))
				chosen = nil
			end, "primary", UDim2.fromOffset(130, 46))
		end
	end

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size, grid.LayoutOrder = UDim2.new(1, -8, 0, 290), 2
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(1 / 3, -12, 0, 132)
	cells.CellPadding = UDim2.fromOffset(14, 14)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	grid.Parent = animals.body
	for i, st in StationConfig.STATIONS do
		local training = a.at == st.id
		local taken = false -- a ground trains one animal (decision 0066): another's is greyed out
		for _, other in S.profile.animals do
			taken = taken or (other.id ~= a.id and other.at == st.id)
		end
		local tile = Style.card(grid, UDim2.new(), if training then C.info else nil)
		tile.LayoutOrder = i
		local now = live(a)
		local level = StationRules.level(now, st.stat :: any)
		local value = Style.text(
			tile,
			`{STAT_SHORT[st.stat]} {StationRules.stat(now, st.stat :: any)}`,
			22,
			C.text,
			UDim2.new(1, -20, 0, 26)
		)
		value.Position = UDim2.fromOffset(12, 10)
		local lv = Style.text(tile, `Lv {level}/{StationConfig.MAX_LEVEL}`, 14, C.muted, UDim2.new(1, -20, 0, 26))
		lv.Position, lv.TextXAlignment = UDim2.fromOffset(8, 10), Enum.TextXAlignment.Right
		local bar, set = Style.bar(tile, UDim2.new(1, -24, 0, 12), if training then C.info else C.good)
		bar.Position = UDim2.fromOffset(12, 44)
		local into = if a.trained then (a.trained[st.stat] or level) - level else 0
		set(if level >= StationConfig.MAX_LEVEL then 1 else into)
		local label = if training then "Stop" elseif taken then "In use" else "Train"
		local button = Style.button(tile, label, function()
			if training then
				send("stop", a.id)
			else
				local onTeam = S.profile and (table.find(S.profile.team, a.id) or S.profile.titan == a.id)
				if send("train", a.id, st.id) and onTeam then -- a taken ground is refused, and the toast says why
					Style.toast(screen, `{nameOf(a)} left your team to train. Stop puts it back.`, nil, "info")
				end
			end
		end, if training then "info" elseif taken then "off" else "primary", UDim2.new(1, -24, 0, 44))
		button.Position, button.TextSize = UDim2.fromOffset(12, 70), 17
		if training then
			table.insert(tickers, function()
				local left = string.match(Hud.statText(live(a), st.stat, true), "  (.+)$")
				button.Text = if left then `Stop · {left}` else "Stop"
			end)
			tickers[#tickers]()
		end
	end
end

redraw.animals = function()
	Style.clear(animals.body)
	Style.clear(animals.chips)
	Style.clear(animals.tabs)
	table.clear(tickers)
	local all, team, training, rainbows = {}, {}, {}, {}
	for _, a in S.profile.animals do
		table.insert(all, a)
		if table.find(S.profile.team, a.id) or S.profile.titan == a.id then
			table.insert(team, a)
		end
		if a.at then
			table.insert(training, a)
		end
		if StationRules.coatOf(a) then
			table.insert(rainbows, a)
		end
	end
	local LISTS = {
		{ "team", `Your team  {#S.profile.team}/{StationProgress.TEAM_SIZE}`, team },
		{ "all", `All animals  {#all}`, all },
		{ "training", `Training  {#training}`, training },
		{ "rainbow", `Coats  {#rainbows}`, rainbows },
	}
	local shown = all
	for _, l in LISTS do
		Style.tab(animals, l[2], animalsTab == l[1], function()
			animalsTab, chosen = l[1], nil
			redraw.animals()
		end)
		if animalsTab == l[1] then
			shown = l[3]
		end
	end
	Style.chip(animals.chips, `Barn {#S.profile.animals}/{StationProgress.value(S.profile, "barn")}`)
	Style.chip(
		animals.chips,
		if S.profile.titan then "Titan ready" else "No Titan",
		if S.profile.titan then C.accent else nil
	)
	if chosen then
		local _, a = StationProgress.find(S.profile, chosen)
		if a then
			Hud.animalDetail(a)
			return
		end
		chosen = nil
	end
	if #shown == 0 then
		local empty = Style.card(animals.body, UDim2.new(1, -12, 0, 150))
		local words = if #S.profile.animals == 0
			then "No animals yet. Buy an egg from the egg vendor, hatch it, and your first animal joins your team."
			else "Nobody here yet."
		local t = Style.text(empty, words, 19, C.muted, UDim2.new(1, -28, 0, 60))
		t.Position = UDim2.fromOffset(14, 14)
		if #S.profile.animals == 0 then
			local b = Style.button(empty, "Open the egg vendor", function()
				show("shop")
			end, "primary", UDim2.fromOffset(240, 46))
			b.Position = UDim2.fromOffset(14, 86)
		end
	end
	table.sort(shown, function(x, y)
		local rx, ry = RANK[StationRules.rarity(x)] or 0, RANK[StationRules.rarity(y)] or 0
		if rx ~= ry then
			return rx > ry
		end
		return x.id < y.id
	end)
	for i, a in shown do
		Hud.animalCard(a, i)
	end
end

-- Eggs: start an egg and watch its timer from anywhere; open it only at the hatchery (decision 0091) ----

-- A picture of an egg: its own model (decision 0057), `side` units square.
local function eggArt(parent: Instance, eggId: string, side: number): ViewportFrame
	return Portrait.new(parent, `egg_{eggId}`, { size = UDim2.fromOffset(side, side), background = C.cardHi })
end

local eggsTab = "hatching"

-- A line drawn from the player to the nest of hatching egg `k`, for a few seconds.
function Hud.wayTo(k: number)
	local nest: BasePart? = nil
	for _, prompt in CollectionService:GetTagged("Egg") do
		if prompt:GetAttribute("Index") == k and prompt:GetAttribute("Ranch") == player:GetAttribute("Ranch") then
			local p = prompt.Parent
			nest = if p and p:IsA("BasePart")
				then p
				elseif p and p:IsA("Model") then p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
				else nil
		end
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if nest == nil or hrp == nil then
		Style.toast(screen, "Your egg is in the hatchery's nests on your ranch")
		return
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = hrp, nest
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1, beam.FaceCamera = 1.2, 1.2, true
	beam.Color = ColorSequence.new(C.accent)
	beam.Texture, beam.TextureMode, beam.TextureLength, beam.TextureSpeed =
		"rbxasset://textures/particles/sparkles_main.dds", Enum.TextureMode.Wrap, 3, 2
	beam.LightEmission, beam.Transparency = 0.6, NumberSequence.new(0.1)
	beam.Parent = hrp
	for _, x in { a0, a1, beam } do
		Debris:AddItem(x, 10)
	end
end

function Hud.eggCard(k: number, e: any, order: number)
	local def = StationConfig.egg(e.egg) :: StationConfig.Egg
	local now = Workspace:GetServerTimeNow()
	local need = StationProgress.hatchSeconds(S.profile, def) -- the Brooder shortens it
	local ready = e.since ~= nil and now >= (StationProgress.dueAt(S.profile, e) :: number)
	local card = Style.card(eggs.body, UDim2.fromOffset(212, 176), if ready then C.good else nil)
	card.LayoutOrder = order
	eggArt(card, e.egg, 68).Position = UDim2.fromOffset(10, 10)
	local name = Style.text(card, def.name, 19, C.text, UDim2.new(1, -92, 0, 24))
	name.Position, name.TextTruncate = UDim2.fromOffset(84, 12), Enum.TextTruncate.AtEnd
	local info = Style.text(card, "", 14, C.muted, UDim2.new(1, -92, 0, 40))
	info.Position = UDim2.fromOffset(84, 38)
	if e.since == nil then
		info.Text = `Takes {Format.ago(need)} to hatch`
		local nests = StationProgress.value(S.profile, "hatchery")
		local hatching = 0
		for _, x in S.profile.eggs do
			hatching += if x.since then 1 else 0
		end
		local b = Style.button(card, if hatching >= nests then "Nests full" else "Hatch it", function()
			send("hatch", k)
		end, if hatching >= nests then "off" else "primary")
		b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
	else
		local bar, set = Style.bar(card, UDim2.new(1, -24, 0, 14), C.accent)
		bar.Position = UDim2.fromOffset(12, 88)
		local b = Style.button(card, "Hatching...", function() end, "off")
		b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
		local function tick()
			local remaining = (StationProgress.dueAt(S.profile, e) :: number) - Workspace:GetServerTimeNow()
			set(1 - remaining / need)
			if remaining <= 0 then
				info.Text, info.TextColor3 = "Ready! Open it at the hatchery", C.good
				b.Text = "Show me the way"
				if b:GetAttribute("Kind") ~= "info" then
					Style.kind(b, "info")
					b.Activated:Connect(function()
						show(nil)
						Hud.wayTo(k)
					end)
				end
			else
				info.Text = `Opens in {Format.ago(remaining)}`
			end
		end
		tick()
		table.insert(eggTickers, tick)
	end
end

redraw.eggs = function()
	Style.clear(eggs.body)
	Style.clear(eggs.chips)
	Style.clear(eggs.tabs)
	table.clear(eggTickers)
	local nests, cellar = StationProgress.value(S.profile, "hatchery"), StationProgress.value(S.profile, "cellar")
	local hatching, ready, stored = {}, 0, {}
	local now = Workspace:GetServerTimeNow()
	for k, e in S.profile.eggs do
		if e.since then
			table.insert(hatching, k)
			local def = StationConfig.egg(e.egg)
			if def and now >= (StationProgress.dueAt(S.profile, e) :: number) then
				ready += 1
			end
		else
			table.insert(stored, k)
		end
	end
	Style.tab(eggs, `Hatching  {#hatching}/{nests}`, eggsTab == "hatching", function()
		eggsTab = "hatching"
		redraw.eggs()
	end, if ready > 0 then tostring(ready) else nil)
	Style.tab(eggs, `In storage  {#stored}/{cellar}`, eggsTab == "storage", function()
		eggsTab = "storage"
		redraw.eggs()
	end)
	Style.tab(eggs, "Egg vendor  ›", false, function()
		show("shop")
	end)
	Style.chip(eggs.chips, `Brooder: hatching {StationProgress.value(S.profile, "brooder")}% speed`)
	local list = if eggsTab == "hatching" then hatching else stored
	for order, k in list do
		Hud.eggCard(k, S.profile.eggs[k], order)
	end
	if eggsTab == "hatching" then
		for slot = #hatching + 1, nests do -- free nests
			local card = Style.card(eggs.body, UDim2.fromOffset(212, 176))
			card.LayoutOrder = 100 + slot
			local t = Style.text(card, `Nest {slot} is free`, 19, C.muted, UDim2.new(1, -24, 0, 24))
			t.Position = UDim2.fromOffset(12, 14)
			local hint = Style.text(card, "Start an egg from your storage", 14, C.muted, UDim2.new(1, -24, 0, 40))
			hint.Position = UDim2.fromOffset(12, 44)
			local b = Style.button(card, "Choose an egg", function()
				eggsTab = "storage"
				redraw.eggs()
			end, if #stored > 0 then "primary" else "off")
			b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
		end
		local hatchery = StationConfig.upgrade("hatchery") :: StationConfig.Upgrade
		local next = hatchery.levels[(S.profile.upgrades.hatchery or 0) + 1]
		if next then -- what the next Hatchery level adds
			local card = Style.card(eggs.body, UDim2.fromOffset(212, 176))
			card.LayoutOrder = 200
			Style.paint(card, C.sand)
			local t = Style.text(card, `Nest {nests + 1}`, 19, C.muted, UDim2.new(1, -24, 0, 24))
			t.Position = UDim2.fromOffset(12, 14)
			local hint = Style.text(
				card,
				`The Hatchery's next level hatches {next.value} at once`,
				14,
				C.muted,
				UDim2.new(1, -24, 0, 40)
			)
			hint.Position = UDim2.fromOffset(12, 44)
			local b = Style.button(card, `Upgrade: {Format.short(next.coins)}`, function()
				S.ranchTab = "eggs"
				show("ranch")
			end, "ghost")
			b.Position, b.Size = UDim2.fromOffset(12, 118), UDim2.new(1, -24, 0, 44)
		end
	elseif #stored == 0 then
		local empty = Style.card(eggs.body, UDim2.new(1, -12, 0, 130))
		local t = Style.text(
			empty,
			"No eggs in storage. Buy some from the egg vendor.",
			19,
			C.muted,
			UDim2.new(1, -28, 0, 30)
		)
		t.Position = UDim2.fromOffset(14, 14)
		local b = Style.button(empty, "Open the egg vendor", function()
			show("shop")
		end, "primary", UDim2.fromOffset(240, 46))
		b.Position = UDim2.fromOffset(14, 66)
	end
end

App.darker = darker
App.eggArt = eggArt

return nil
