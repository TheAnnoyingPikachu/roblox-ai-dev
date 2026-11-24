--!strict
-- The Eggs window (the Eggs concept board): buy, wait and open in one place. On the left the hatchery's
-- nests and the cellar, in the middle the vendor's shelf (every egg, locked ones too), on the right what
-- the chosen egg holds with every chance, and Buy 1 / Buy 3. The vendor's stall opens this window too.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local player = game:GetService("Players").LocalPlayer
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local RARITY_COLOUR = App.RARITY_COLOUR
local screen = App.screen
local eggTickers = App.eggTickers
local Hud = App.Hud
local send = App.send
local redraw = App.redraw
local show = App.show
local eggs = App.eggs
local darker = App.darker
local eggArt = App.eggArt

local page = Style.page(eggs)
local shelfEgg = 1 -- the egg whose contents show on the right
local buying = false

-- Open Eggs on egg `id` (a new level's "See what is inside").
function Hud.pickEgg(id: string)
	for k, d in StationConfig.EGGS do
		shelfEgg = if d.id == id then k else shelfEgg
	end
	show("eggs")
end

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

-- A row in the hatchery column: the egg, its name, a line under it and one button.
local function nestRow(parent: Instance, order: number, eggId: string?, title: string, sub: string, edge: Color3?)
	local card = Style.card(parent, UDim2.new(1, -8, 0, 98), edge)
	card.LayoutOrder = order
	if eggId then
		eggArt(card, eggId, 62).Position = UDim2.fromOffset(10, 18)
	else
		local empty = Style.frame(card, UDim2.fromOffset(62, 62), C.sand)
		empty.Position = UDim2.fromOffset(10, 18)
		Style.round(empty, 31)
		Style.stroke(empty, C.muted, 2).LineJoinMode = Enum.LineJoinMode.Round
	end
	local name = Style.text(card, title, 18, C.text, UDim2.new(1, -96, 0, 22))
	name.Position, name.TextTruncate = UDim2.fromOffset(84, 10), Enum.TextTruncate.AtEnd
	local line = Style.small(card, sub, 13, C.muted, UDim2.new(1, -96, 0, 18))
	line.Position = UDim2.fromOffset(84, 34)
	return card, line
end

local function rowButton(card: Frame, label: string, kind: string, onClick: () -> ()): TextButton
	local b = Style.button(card, label, onClick, kind, UDim2.fromOffset(124, 34))
	b.Position, b.TextSize = UDim2.fromOffset(84, 56), 15
	return b
end

-- The hatchery: a row for every nest (hatching, ready, or empty), then the eggs waiting in the cellar.
local function hatcheryColumn(col: Frame, stored: { number }, hatching: { number })
	local nests, cellar = StationProgress.value(S.profile, "hatchery"), StationProgress.value(S.profile, "cellar")
	local head = Style.text(col, `Your hatchery · {nests} nests`, 20, C.text, UDim2.new(1, -8, 0, 26))
	head.LayoutOrder = 0
	for order, k in hatching do
		local e = S.profile.eggs[k]
		local def = StationConfig.egg(e.egg) :: StationConfig.Egg
		local need = StationProgress.hatchSeconds(S.profile, def)
		local card, line = nestRow(col, order, e.egg, def.name, "")
		local bar, set = Style.bar(card, UDim2.new(1, -100, 0, 10), C.accent)
		bar.Position = UDim2.fromOffset(84, 66)
		local b = rowButton(card, "Show me", "info", function()
			show(nil)
			Hud.wayTo(k)
		end)
		local function tick()
			local remaining = (StationProgress.dueAt(S.profile, e) :: number) - Workspace:GetServerTimeNow()
			set(1 - remaining / need)
			local ready = remaining <= 0
			bar.Visible, b.Visible = not ready, ready
			line.Text = if ready then "Ready! Open it at its nest" else `Opens in {Format.ago(remaining)}`
			line.TextColor3 = if ready then C.good else C.muted
		end
		tick()
		table.insert(eggTickers, tick)
	end
	for slot = #hatching + 1, nests do
		local card = nestRow(
			col,
			slot,
			nil,
			"An empty nest",
			if #stored > 0 then "Start one from the cellar" else "Buy an egg to fill it"
		)
		if #stored > 0 then
			rowButton(card, "Hatch one", "primary", function()
				send("hatch", stored[1])
			end)
		end
	end
	local sub = Style.text(col, `In the cellar · {#stored} of {cellar}`, 18, C.text, UDim2.new(1, -8, 0, 24))
	sub.LayoutOrder = 100
	local counts, order = {}, {}
	for _, k in stored do
		local id = S.profile.eggs[k].egg
		if counts[id] == nil then
			table.insert(order, id)
			counts[id] = {}
		end
		table.insert(counts[id], k)
	end
	for i, id in order do
		local def = StationConfig.egg(id) :: StationConfig.Egg
		local n = #counts[id]
		local card = nestRow(col, 100 + i, id, if n > 1 then `{n} {def.name}s` else def.name, "waiting in the cellar")
		local full = #hatching >= nests
		rowButton(card, if full then "Nests full" else "Hatch one", if full then "off" else "primary", function()
			send("hatch", counts[id][1])
		end)
	end
	if #order == 0 then
		local none =
			Style.small(col, "Nothing in the cellar. Eggs you buy wait here.", 13, C.muted, UDim2.new(1, -8, 0, 20))
		none.LayoutOrder = 101
	end
end

-- A card on the vendor's shelf: the egg, its price and its wait; a locked one is dimmed with its level.
local function shelfCard(col: Instance, k: number, def: StationConfig.Egg, level: number)
	local locked = def.level ~= nil and level < def.level
	local picked = k == shelfEgg
	local card = Style.button(col, "", function()
		shelfEgg = k
		redraw.eggs()
	end, if picked then "primary" else "ghost", UDim2.fromOffset(150, 190))
	card.LayoutOrder = k
	local art = eggArt(card, def.id, 92)
	art.AnchorPoint, art.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8)
	if locked then
		art.ImageTransparency = 0.5
		local lock = Style.chip(card, `Level {def.level}`, C.ink, Color3.new(1, 1, 1))
		lock.AnchorPoint, lock.Position, lock.TextSize, lock.ZIndex =
			Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 72), 13, 3
	end
	local name = Style.text(card, def.name, 16, C.text, UDim2.new(1, -12, 0, 20))
	name.Position, name.TextXAlignment = UDim2.fromOffset(6, 104), Enum.TextXAlignment.Center
	local price = Instance.new("Frame")
	price.BackgroundTransparency = 1
	price.AnchorPoint, price.Position, price.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 126), UDim2.fromOffset(0, 26)
	price.AutomaticSize = Enum.AutomaticSize.X
	Style.list(price, 0, true)
	price.Parent = card
	Style.amount(price, "coins", Format.commas(def.price))
	local wait = Style.small(
		card,
		`Hatches in {Format.ago(StationProgress.hatchSeconds(S.profile, def))}`,
		12,
		C.muted,
		UDim2.new(1, -12, 0, 18)
	)
	wait.Position, wait.TextXAlignment = UDim2.fromOffset(6, 156), Enum.TextXAlignment.Center
end

-- What one egg holds, each with its chance: the basic animals as a share, the rare finds as "1 in N".
local function contentsColumn(col: Frame, def: StationConfig.Egg, level: number)
	local locked = def.level ~= nil and level < def.level
	local head = Style.text(col, def.name, 24, C.text, UDim2.new(1, -8, 0, 30))
	head.LayoutOrder = 0
	local line = Instance.new("Frame")
	line.BackgroundTransparency = 1
	line.Size, line.LayoutOrder = UDim2.new(1, -8, 0, 26), 1
	Style.list(line, 10, true).VerticalAlignment = Enum.VerticalAlignment.Center
	line.Parent = col
	Style.amount(line, "coins", Format.commas(def.price))
	Style.small(
		line,
		`Hatches in {Format.ago(StationProgress.hatchSeconds(S.profile, def))}`,
		13,
		C.muted,
		UDim2.fromOffset(150, 20)
	)
	if def.coat then
		local coat = StationConfig.coat(def.coat)
		local chip = Style.chip(
			col,
			`{string.upper(if coat then coat.name else def.coat)} COAT {def.times or StationConfig.COAT_TIMES}x AS LIKELY`,
			Style.COAT[def.coat] or C.cardHi
		)
		chip.LayoutOrder, chip.TextSize = 2, 13
	end
	local title = Style.small(col, "WHAT IS INSIDE", 12, C.muted, UDim2.new(1, -8, 0, 18))
	title.LayoutOrder = 3
	local rareShare = 0
	for _, drop in def.rare do
		rareShare += drop.ppm
	end
	local basic = 1 - rareShare / StationRules.PPM
	local function row(order: number, asset: string, name: string, tier: string, odds: string)
		local colour = RARITY_COLOUR[tier] or C.text
		local r = Instance.new("Frame")
		r.BackgroundTransparency = 1
		r.Size, r.LayoutOrder = UDim2.new(1, -8, 0, 46), order
		r.Parent = col
		local view = Portrait.new(r, asset, { size = UDim2.fromOffset(42, 42), background = darker(colour) })
		Style.round(view, 9)
		Style.stroke(view, colour, 2)
		local n = Style.text(r, name, 15, C.text, UDim2.new(1, -130, 0, 20))
		n.Position, n.TextTruncate = UDim2.fromOffset(52, 2), Enum.TextTruncate.AtEnd
		local t = Style.small(r, string.upper(tier), 11, colour:Lerp(C.ink, 0.35), UDim2.new(1, -130, 0, 16))
		t.Position = UDim2.fromOffset(52, 24)
		local o = Style.text(r, odds, 15, C.text, UDim2.fromOffset(74, 42))
		o.AnchorPoint, o.Position, o.TextXAlignment =
			Vector2.new(1, 0), UDim2.fromScale(1, 0), Enum.TextXAlignment.Right
	end
	for i, o in def.odds do
		local sp = StationConfig.species(o.id) :: StationConfig.Species
		local pct = o.bp / 100 * basic
		row(
			10 + i,
			StationRules.assetOf(o.id, nil),
			sp.name,
			sp.rarity,
			`{if pct >= 10 then math.floor(pct + 0.5) else math.floor(pct * 10 + 0.5) / 10}%`
		)
	end
	for i, drop in def.rare do
		local va = StationConfig.variant(drop.s, drop.v) :: StationConfig.Variant
		local odds = if drop.ppm >= 100_000
			then `{math.floor(drop.ppm / 10_000 + 0.5)}%`
			else `1 in {Format.commas(StationRules.PPM // drop.ppm)}`
		row(50 + i, StationRules.assetOf(drop.s, drop.v), va.name, va.tier, odds)
	end
	local buy = Instance.new("Frame")
	buy.BackgroundTransparency = 1
	buy.Size, buy.LayoutOrder = UDim2.new(1, -8, 0, 54), 99
	Style.list(buy, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
	buy.Parent = col
	local function buyN(n: number)
		if locked then
			Style.toast(screen, `Reach level {def.level} to unlock the {def.name}`, nil, "bad")
			return
		end
		if buying then
			return
		end
		buying = true
		for _ = 1, n do -- one request each: the server prices and checks every one
			if not send("buy", def.id) then
				break
			end
		end
		buying = false
	end
	local can = not locked and S.profile.coins >= def.price
	Style.button(buy, "Buy 1", function()
		buyN(1)
	end, if can then "primary" else "off", UDim2.fromOffset(104, 48)).TextSize =
		18
	local three = Style.button(buy, `Buy 3 · {Format.short(def.price * 3)}`, function()
		buyN(3)
	end, if not locked and S.profile.coins >= def.price * 3 then "good" else "off", UDim2.fromOffset(168, 48))
	three.TextSize = 17
	if locked then
		local why = Style.small(
			col,
			`You are level {level}. This egg opens at level {def.level}.`,
			13,
			C.bad,
			UDim2.new(1, -8, 0, 18)
		)
		why.LayoutOrder = 100
	end
end

-- An exclusive animal on the shelf (decision 0117): its picture, its name in the eternal colour and its Robux
-- price; pressing it asks Roblox to sell it. "Coming soon" while its product is not made.
local prices: { [number]: number } = {}
local function productCard(col: Instance, k: number, item: StationConfig.Product)
	local va = StationConfig.variant(item.s, item.v) :: StationConfig.Variant
	local product = item.product
	local card = Style.button(col, "", function()
		if product then
			MarketplaceService:PromptProductPurchase(player, product)
		end
	end, if product then "primary" else "ghost", UDim2.fromOffset(150, 190))
	card.LayoutOrder = 100 + k
	local view = Portrait.new(card, StationRules.assetOf(item.s, item.v), {
		size = UDim2.fromOffset(110, 92),
		background = darker(RARITY_COLOUR.eternal),
	})
	view.AnchorPoint, view.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8)
	local name = Style.text(card, va.name, 16, RARITY_COLOUR.eternal, UDim2.new(1, -12, 0, 20))
	name.Position, name.TextXAlignment = UDim2.fromOffset(6, 104), Enum.TextXAlignment.Center
	local price = Style.small(card, "Coming soon", 15, C.text, UDim2.new(1, -12, 0, 22))
	price.Position, price.TextXAlignment = UDim2.fromOffset(6, 128), Enum.TextXAlignment.Center
	if product then
		price.Text = if prices[product] then `R$ {prices[product]}` else "R$ ..."
		if prices[product] == nil then
			task.spawn(function()
				local ok, info =
					pcall(MarketplaceService.GetProductInfo, MarketplaceService, product, Enum.InfoType.Product)
				if ok and info and info.PriceInRobux then
					prices[product] = info.PriceInRobux
					if price.Parent then
						price.Text = `R$ {info.PriceInRobux}`
					end
				end
			end)
		end
	end
	local tier = Style.small(card, "ETERNAL · never in an egg", 11, C.muted, UDim2.new(1, -12, 0, 18))
	tier.Position, tier.TextXAlignment = UDim2.fromOffset(6, 156), Enum.TextXAlignment.Center
end

redraw.eggs = function()
	Style.clear(page)
	Style.clear(eggs.chips)
	Style.clear(eggs.count)
	table.clear(eggTickers)
	local level = StationProgress.playerLevel(S.profile)
	local hatching, stored, ready = {}, {}, 0
	local now = Workspace:GetServerTimeNow()
	for k, e in S.profile.eggs do
		if e.since then
			table.insert(hatching, k)
			if now >= (StationProgress.dueAt(S.profile, e) :: number) then
				ready += 1
			end
		else
			table.insert(stored, k)
		end
	end
	Style.amount(eggs.chips, "coins", Format.commas(S.profile.coins))
	local nextAt: number? = nil
	for _, d in StationConfig.EGGS do
		if d.level and d.level > level and (nextAt == nil or d.level < nextAt) then
			nextAt = d.level
		end
	end
	Style.small(
		eggs.chips,
		`You are level {level}.{if nextAt then ` The next egg opens at level {nextAt}.` else ""}`,
		13,
		C.muted,
		UDim2.fromOffset(300, 20)
	)
	if ready > 0 then
		Style.chip(eggs.count, `{ready} ready to open`, C.good, Color3.new(1, 1, 1))
	end

	hatcheryColumn(Style.column(page, UDim.new(0, 0), UDim.new(0, 300), 1, 8), stored, hatching)
	local shelf = Style.column(page, UDim.new(0, 312), UDim.new(1, -652), 2, 10, true)
	local open = 0
	for k, d in StationConfig.EGGS do
		open += if d.level == nil or level >= d.level then 1 else 0
		shelfCard(shelf, k, d, level)
	end
	local note = Style.text(
		shelf,
		`The vendor's shelf · {open} of {#StationConfig.EGGS} open`,
		20,
		C.text,
		UDim2.new(1, -12, 0, 26)
	)
	note.LayoutOrder = 0
	local special = Style.text(shelf, "Eternal animals", 20, RARITY_COLOUR.eternal, UDim2.new(1, -12, 0, 26))
	special.LayoutOrder = 100
	for k, item in StationConfig.PRODUCTS do
		productCard(shelf, k, item)
	end
	local right = Style.column(page, UDim.new(1, -330), UDim.new(0, 330), 3, 6)
	contentsColumn(right, StationConfig.EGGS[shelfEgg], level)
end

return nil
