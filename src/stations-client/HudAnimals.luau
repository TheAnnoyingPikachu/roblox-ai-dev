--!strict
-- The Animals window (the Animals concept board): one window in three columns. Tabs on the left, the grid
-- in the middle, the chosen animal on the right, so nothing replaces anything and there is no Back button.
-- A card says one extra thing (training, a coat, enough to fuse); the chosen animal's stats are rows with
-- one button each; "Seen" shows what the player's eggs can still give as dark outlines.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
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
local Hud = App.Hud
local send = App.send
local nameOf = App.nameOf
local live = App.live
local redraw = App.redraw
local show = App.show
local animals = App.animals

local function darker(colour: Color3): Color3 -- a portrait's background: the rarity, pale
	return colour:Lerp(C.sand, 0.55)
end

-- A picture of an egg: its own model (decision 0057), `side` units square.
local function eggArt(parent: Instance, eggId: string, side: number): ViewportFrame
	return Portrait.new(parent, `egg_{eggId}`, { size = UDim2.fromOffset(side, side), background = C.cardHi })
end

local ROLE_COLOUR: { [string]: Color3 } = { attack = C.bad, defense = C.info, utility = C.good, titan = C.gold }
-- How each class's power attack is pressed in a fight (decision 0109), in the words of the chosen animal.
local PRESS_WORDS: { [string]: string } = {
	ring = "In a fight: hold its key until the ring fills.",
	needle = "In a fight: press as the needle crosses the gold.",
	chain = "In a fight: press the arrows in the order shown.",
	mash = "In a fight: mash Space before the bar runs out.",
}
local FULL_NAME: { [string]: string } = {
	speed = "Speed",
	strength = "Strength",
	stamina = "Stamina",
	mana = "Mana",
	health = "Health",
	defence = "Defence",
}

local animalsTab = "team"
-- how the list is sorted (SHANNON's pick: power, rarity, level, newest), one button that steps through them
local SORTS = { "power", "rarity", "level", "newest" }
local sortBy = "rarity"
local chosen: number? = nil -- the id of the animal shown on the right
local page = Style.page(animals)

-- Open Animals on animal `id` (a hatch's "Swap it in").
function Hud.chooseAnimal(id: number)
	chosen, animalsTab = id, "all"
	show("animals")
end

-- The one extra line a card carries: what matters about this animal now.
local function cardLine(a: any): (string, Color3?)
	if a.at then
		local st = StationConfig.station(a.at)
		local left = string.match(Hud.statText(live(a), if st then st.stat else "speed", true), "  (.+)$")
		return `Training {if st then FULL_NAME[st.stat] else ""}{if left then `: {left}` else ""}`, C.info
	end
	local worn = StationRules.coatOf(a)
	if worn then
		return `{worn.name} coat`, Style.COAT[worn.id] or C.gold
	end
	local mates = StationProgress.fusable(S.profile, a)
	if #mates >= StationProgress.FUSE then
		return `You have {#mates}: fuse them`, C.accent
	end
	return Hud.bestTwo(a), nil
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

local function badge(card: Instance, text: string, colour: Color3)
	local b = Style.chip(card, text, colour, if colour == C.gold then C.ink else Color3.new(1, 1, 1))
	b.Position, b.ZIndex, b.TextSize, b.Size = UDim2.fromOffset(8, 8), 3, 12, UDim2.fromOffset(0, 22)
end

function Hud.animalCard(grid: Instance, a: any, order: number)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local picked = chosen == a.id
	local card = Style.button(grid, "", function()
		chosen = a.id
		redraw.animals()
	end, if picked then "primary" else "ghost", UDim2.fromOffset(156, 196))
	card.Name, card.LayoutOrder = nameOf(a), order
	local view = Portrait.new(
		card,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(148, 118), background = darker(colour), rainbow = a.rainbow }
	)
	view.Position = UDim2.fromOffset(4, 4)
	Style.round(view, 10)
	if S.profile.titan == a.id then
		badge(card, "TITAN", C.gold)
	elseif table.find(S.profile.team, a.id) then
		badge(card, "TEAM", C.good)
	end
	local class = Style.frame(card, UDim2.fromOffset(12, 12), ROLE_COLOUR[StationRules.role(a)] or C.muted)
	class.Position = UDim2.fromOffset(10, 128)
	Style.round(class, 6)
	Style.stroke(class, C.ink, 2)
	local name = Style.text(card, nameOf(a), 16, C.text, UDim2.new(1, -36, 0, 20))
	name.Position, name.TextTruncate = UDim2.fromOffset(28, 124), Enum.TextTruncate.AtEnd
	local power =
		Style.small(card, `{Format.commas(BattleRules.powerOf(live(a)))} power`, 12, C.muted, UDim2.new(1, -20, 0, 16))
	power.Position = UDim2.fromOffset(10, 146)
	local words, tint = cardLine(a)
	local extra =
		Style.small(card, words, 12, if tint then tint:Lerp(C.ink, 0.45) else C.muted, UDim2.new(1, -20, 0, 16))
	extra.Position, extra.TextTruncate = UDim2.fromOffset(10, 164), Enum.TextTruncate.AtEnd
	local band = Style.frame(card, UDim2.new(1, -8, 0, 6), colour)
	band.Position = UDim2.new(0, 4, 1, -10)
	Style.round(band, 3)
end

-- An animal the player has not got yet, from an egg they can buy: a dark outline and where it comes from.
local function seenCard(grid: Instance, asset: string, label: string, eggName: string, order: number)
	local card = Style.card(grid, UDim2.fromOffset(156, 196))
	card.LayoutOrder = order
	Style.paint(card, C.sand)
	local view = Portrait.new(
		card,
		asset,
		{ size = UDim2.fromOffset(148, 118), background = C.cardHi, tint = Color3.fromRGB(40, 30, 24) }
	)
	view.Position = UDim2.fromOffset(4, 4)
	Style.round(view, 10)
	badge(card, "SEEN", C.ink)
	local name = Style.text(card, label, 16, C.muted, UDim2.new(1, -20, 0, 20))
	name.Position, name.TextTruncate = UDim2.fromOffset(10, 126), Enum.TextTruncate.AtEnd
	local from = Style.small(card, `From the {eggName}`, 12, C.muted, UDim2.new(1, -20, 0, 32))
	from.Position, from.TextWrapped = UDim2.fromOffset(10, 148), true
end

-- The chosen animal: its picture and name, what kind it is, how its press works, its six stats as rows
-- (value, level, one button each), then the team, lock, release and fuse.
function Hud.animalDetail(col: Instance, a: any)
	local sp = StationConfig.species(a.s)
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local role = StationRules.role(a)
	local isTitan = role == StationConfig.TITAN
	local inTeam = table.find(S.profile.team, a.id) ~= nil or S.profile.titan == a.id
	local now = live(a)

	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size, head.LayoutOrder = UDim2.new(1, -8, 0, 150), 1
	head.Parent = col
	local view = Portrait.new(
		head,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(140, 140), background = darker(colour), rainbow = a.rainbow }
	)
	Style.round(view, 14)
	Style.stroke(view, C.ink, 3)
	local name = Style.text(head, StationTrade.nameOf(a), 24, C.text, UDim2.new(1, -152, 0, 56))
	name.Position, name.TextWrapped = UDim2.fromOffset(152, 0), true
	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position, chips.Size = UDim2.fromOffset(152, 60), UDim2.new(1, -152, 0, 60)
	Style.list(chips, 6, true, true)
	chips.Parent = head
	Style.chip(chips, string.upper(rarity), colour).TextSize = 13
	Style.chip(
		chips,
		string.upper(ROLE_NAME[role] or "?"),
		ROLE_COLOUR[role] or C.cardHi,
		if role == "titan" then C.ink else Color3.new(1, 1, 1)
	).TextSize =
		13
	Style.chip(chips, string.upper(GROUP_NAME[if sp then sp.group else ""] or "?")).TextSize = 13
	local power =
		Style.text(head, `{Format.commas(BattleRules.powerOf(now))} power`, 18, C.text, UDim2.new(1, -152, 0, 22))
	power.Position = UDim2.fromOffset(152, 122)
	local press = Style.small(col, PRESS_WORDS[BattleRules.pressOf(a)] or "", 13, C.muted, UDim2.new(1, -8, 0, 18))
	press.LayoutOrder = 2
	local worn = StationRules.coatOf(a)
	if worn then
		local coat = Style.chip(col, `{string.upper(worn.name)} COAT`, Style.COAT[worn.id] or Color3.new(1, 1, 1))
		coat.LayoutOrder, coat.TextSize = 3, 13
		if Style.COAT[worn.id] == nil then -- rainbow, prismatic
			local colours = Instance.new("UIGradient")
			colours.Color = RAINBOW
			colours.Parent = coat
		end
	end

	for i, st in StationConfig.STATIONS do
		local training = a.at == st.id
		local taken = false -- a ground trains one animal (decision 0066): another's is greyed out
		for _, other in S.profile.animals do
			taken = taken or (other.id ~= a.id and other.at == st.id)
		end
		local level = StationRules.level(now, st.stat :: any)
		local row = Style.card(col, UDim2.new(1, -8, 0, 58), if training then C.info else nil)
		row.LayoutOrder = 10 + i
		local k = Style.text(row, FULL_NAME[st.stat] or st.stat, 16, C.text, UDim2.fromOffset(92, 22))
		k.Position = UDim2.fromOffset(12, 7)
		local v =
			Style.text(row, tostring(StationRules.stat(now, st.stat :: any)), 20, C.text, UDim2.fromOffset(70, 24))
		v.Position = UDim2.fromOffset(104, 6)
		local lv =
			Style.small(row, `Level {level} of {StationConfig.MAX_LEVEL}`, 12, C.muted, UDim2.fromOffset(170, 16))
		lv.Position = UDim2.fromOffset(12, 32)
		local label = if training then "Stop" elseif taken then "In use" else "Train"
		local b = Style.button(row, label, function()
			if training then
				send("stop", a.id)
			else
				local onTeam = S.profile and (table.find(S.profile.team, a.id) or S.profile.titan == a.id)
				if send("train", a.id, st.id) and onTeam then -- a taken ground is refused, and the toast says why
					Style.toast(screen, `{nameOf(a)} left your team to train. Stop puts it back.`, nil, "info")
				end
			end
		end, if training then "info" elseif taken then "off" else "primary", UDim2.fromOffset(96, 40))
		b.AnchorPoint, b.Position, b.TextSize = Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, -2), 15
		if level >= StationConfig.MAX_LEVEL and not training then
			b.Visible = false
			lv.Text = "Level 70: the top"
		end
		if training then
			table.insert(tickers, function()
				local left = string.match(Hud.statText(live(a), st.stat, true), "  (.+)$")
				lv.Text = if left then `Level {level}, next in {left}` else `Level {level}`
			end)
			tickers[#tickers]()
		end
	end

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Size, buttons.LayoutOrder = UDim2.new(1, -8, 0, 0), 30
	buttons.AutomaticSize = Enum.AutomaticSize.Y
	Style.list(buttons, 6, true, true)
	buttons.Parent = col
	Style.button(buttons, if inTeam then "Leave team" elseif isTitan then "Join as Titan" else "Join team", function()
		send("team", a.id)
	end, if inTeam then "ghost" else "good", UDim2.fromOffset(132, 44)).TextSize =
		16
	-- a locked animal can never go in a trade (decision 0099)
	Style.button(buttons, if a.locked then "Locked" else "Lock", function()
		send("lock", a.id)
	end, if a.locked then "primary" else "ghost", UDim2.fromOffset(92, 44)).TextSize =
		16
	-- release for a few coins (a second click confirms), or fuse four of one into the next coat (decision 0112)
	if not inTeam and not a.at and not a.locked then
		local pay = (StationProgress.RELEASE_PAY[StationRules.rarity(a)] or 0) * (if a.coat then 2 else 1)
		local sure = false
		local release: TextButton
		release = Style.button(buttons, `Release +{pay}`, function()
			if not sure then
				sure = true
				release.Text = `Sure? +{pay}`
				return
			end
			send("release", a.id)
			chosen = nil
		end, "ghost", UDim2.fromOffset(132, 44))
		release.TextSize = 16
		local mates = StationProgress.fusable(S.profile, a)
		if #mates >= StationProgress.FUSE then
			Style.button(buttons, `Fuse {StationProgress.FUSE}`, function()
				send("fuse", table.unpack(mates, 1, StationProgress.FUSE))
				chosen = nil
			end, "primary", UDim2.fromOffset(100, 44)).TextSize =
				16
		end
	end
end

-- What the player can still get: every species and variant in their open eggs, and the exclusive ones (decision
-- 0117, "Shop"), not owned yet.
local function unseen(): { { asset: string, name: string, egg: string, rank: number } }
	local owned = {}
	for _, a in S.profile.animals do
		owned[a.s .. "/" .. (a.v or "")] = true
	end
	local level, out, listed = StationProgress.playerLevel(S.profile), {}, {}
	for _, d in StationConfig.EGGS do
		if d.level == nil or level >= d.level then
			for _, o in d.odds do
				local sp = StationConfig.species(o.id) :: StationConfig.Species
				local key = o.id .. "/"
				if not owned[key] and not listed[key] then
					listed[key] = true
					table.insert(out, {
						asset = StationRules.assetOf(o.id, nil),
						name = sp.name,
						egg = d.name,
						rank = RANK[sp.rarity] or 0,
					})
				end
			end
			for _, drop in d.rare do
				local va = StationConfig.variant(drop.s, drop.v) :: StationConfig.Variant
				local key = drop.s .. "/" .. drop.v
				if not owned[key] and not listed[key] then
					listed[key] = true
					table.insert(out, {
						asset = StationRules.assetOf(drop.s, drop.v),
						name = va.name,
						egg = d.name,
						rank = RANK[va.tier] or 0,
					})
				end
			end
		end
	end
	for _, sp in StationConfig.SPECIES do
		for _, va in sp.variants do
			local key = sp.id .. "/" .. va.id
			if va.exclusive and not owned[key] and not listed[key] then
				listed[key] = true
				table.insert(out, {
					asset = StationRules.assetOf(sp.id, va.id),
					name = va.name,
					egg = "Shop",
					rank = RANK[va.tier] or 0,
				})
			end
		end
	end
	table.sort(out, function(x, y)
		return x.rank < y.rank
	end)
	return out
end

redraw.animals = function()
	Style.clear(page)
	Style.clear(animals.chips)
	Style.clear(animals.count)
	Style.clear(animals.tabs)
	table.clear(tickers)
	local all, team, training, coats = {}, {}, {}, {}
	local teamPower = 0
	for _, a in S.profile.animals do
		table.insert(all, a)
		if table.find(S.profile.team, a.id) or S.profile.titan == a.id then
			table.insert(team, a)
			teamPower += BattleRules.powerOf(live(a))
		end
		if a.at then
			table.insert(training, a)
		end
		if StationRules.coatOf(a) then
			table.insert(coats, a)
		end
	end
	local seen = unseen()
	local LISTS = {
		{ "team", "Team", team, `{#S.profile.team}{if S.profile.titan then " + Titan" else ""}` },
		{ "all", "All", all, tostring(#all) },
		{ "training", "Training", training, tostring(#training) },
		{ "coats", "Coats", coats, tostring(#coats) },
		{ "seen", "Seen", {}, tostring(#seen) },
	}
	local shown = all
	for _, l in LISTS do
		local tab = Style.tab(animals, l[2], animalsTab == l[1], function()
			animalsTab = l[1]
			redraw.animals()
		end)
		local n = Style.small(
			tab,
			l[4],
			13,
			if animalsTab == l[1] then Color3.new(1, 1, 1) else C.muted,
			UDim2.fromOffset(70, 20)
		)
		n.AnchorPoint, n.Position, n.TextXAlignment, n.ZIndex =
			Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0), Enum.TextXAlignment.Right, 3
		if animalsTab == l[1] then
			shown = l[3]
		end
	end
	Style.chip(animals.chips, `Barn {#S.profile.animals} / {StationProgress.value(S.profile, "barn")}`)
	Style.chip(animals.chips, `Team power {Format.commas(teamPower)}`, C.gold)
	local sorter = Style.button(animals.chips, `Sort: {sortBy}`, function()
		sortBy = SORTS[(table.find(SORTS, sortBy) or 0) % #SORTS + 1]
		redraw.animals()
	end, "ghost", UDim2.fromOffset(130, 30))
	sorter.TextSize = 14

	-- the right column belongs to the chosen animal: the first in the list when none is chosen yet
	local function key(a: any): number
		if sortBy == "power" then
			return BattleRules.powerOf(live(a))
		elseif sortBy == "level" then
			local n = 0
			for _, stat in StationConfig.STATS do
				n += StationRules.level(live(a), stat)
			end
			return n
		elseif sortBy == "newest" then
			return a.id
		end
		return RANK[StationRules.rarity(a)] or 0
	end
	table.sort(shown, function(x, y)
		local kx, ky = key(x), key(y)
		if kx ~= ky then
			return kx > ky
		end
		return x.id < y.id
	end)
	local pick = chosen and select(2, StationProgress.find(S.profile, chosen))
	if pick == nil then
		pick = shown[1] or all[1]
		chosen = pick and pick.id
	end
	local grid = Style.column(page, UDim.new(0, 0), UDim.new(1, -352), 1, 10, true)
	local right = Style.column(page, UDim.new(1, -340), UDim.new(0, 340), 2, 8)
	if animalsTab == "seen" then
		for i, x in seen do
			seenCard(grid, x.asset, x.name, x.egg, i)
		end
		if #seen == 0 then
			Style.text(
				grid,
				"You have every animal your eggs can give. A higher level opens new eggs.",
				18,
				C.muted,
				UDim2.new(1, -12, 0, 50)
			)
		end
	else
		for i, a in shown do
			Hud.animalCard(grid, a, i)
		end
		if #shown == 0 then
			local empty = Style.card(grid, UDim2.new(1, -12, 0, 140))
			local words = if #S.profile.animals == 0
				then "No animals yet. Buy an egg, hatch it, and your first animal joins your team."
				else "Nobody here yet."
			local t = Style.text(empty, words, 18, C.muted, UDim2.new(1, -28, 0, 50))
			t.Position = UDim2.fromOffset(14, 14)
			if #S.profile.animals == 0 then
				local b = Style.button(empty, "Open Eggs", function()
					show("eggs")
				end, "primary", UDim2.fromOffset(180, 46))
				b.Position = UDim2.fromOffset(14, 76)
			end
		end
	end
	if pick then
		Hud.animalDetail(right, pick)
	end
end

App.darker = darker
App.ROLE_COLOUR = ROLE_COLOUR -- the card under the cursor's class chip
App.eggArt = eggArt

return nil
