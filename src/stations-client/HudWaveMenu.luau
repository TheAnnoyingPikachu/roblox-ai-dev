--!strict
-- The Waves window (the Waves concept board): a road to the boss, not a number picker. On the left the
-- stages (ten waves each, a boss at the end), in the middle the stage's road and the wave picked on it
-- (who is coming, the power against yours, what a first clear pays), on the right who is fighting and the
-- button. One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local LevelRules = require(Shared:WaitForChild("LevelRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationIntro = require(Shared:WaitForChild("StationIntro"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local player = Players.LocalPlayer
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local Hud = App.Hud
local send = App.send
local redraw = App.redraw
local show = App.show
local waves = App.waves
local fight = App.fight
local ICON = App.ICON

local page = Style.page(waves)
local waveDetail = false -- a phone: the picked wave full-screen instead of the road (STATION-161)
local PORTAL_RADIUS = 14 -- World.PORTAL_RADIUS: who stands this near the portal's middle joins the fight
local WHITE = Color3.new(1, 1, 1)

-- The players standing in the wave portal's ring now, the local player left out.
local function inPortal(): { Player }
	local ring: BasePart? = nil
	for _, gate in CollectionService:GetTagged("WaveGate") do
		local p = gate.Parent
		ring = if p and p:IsA("BasePart") then p else ring
	end
	local out = {}
	for _, other in Players:GetPlayers() do
		local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other ~= player and ring and hrp then
			local d = hrp.Position - ring.Position
			if Vector2.new(d.X, d.Z).Magnitude <= PORTAL_RADIUS then
				table.insert(out, other)
			end
		end
	end
	return out
end

-- An enemy's card: its picture on the night, its name, how many of it.
local function foeCard(parent: Instance, e: any, n: number)
	local foe = StationConfig.foe(e.s) :: StationConfig.Foe
	local boss = e.boss == true or foe.kind == "dragon"
	local card = Style.card(parent, UDim2.fromOffset(112, 140), if boss then C.bad else nil)
	local tint = if foe.tint then Color3.fromRGB(foe.tint[1], foe.tint[2], foe.tint[3]) else nil
	local view = Portrait.new(
		card,
		foe.model,
		{ size = UDim2.fromOffset(100, 86), background = Color3.fromRGB(34, 22, 50), tint = tint, zoom = 0.82 }
	)
	view.Position = UDim2.fromOffset(6, 6)
	Style.round(view, 10)
	local name =
		Style.small(card, `{foe.name}{if e.elite then ", elite" else ""}`, 12, C.text, UDim2.new(1, -10, 0, 34))
	name.Position, name.TextWrapped, name.TextXAlignment = UDim2.fromOffset(5, 96), true, Enum.TextXAlignment.Center
	if n > 1 then
		local many = Style.chip(card, `x{n}`, C.ink, WHITE)
		many.AnchorPoint, many.Position, many.ZIndex, many.TextSize = Vector2.new(1, 0), UDim2.new(1, -4, 0, 4), 4, 13
	end
	if boss then
		local tag = Style.chip(card, "BOSS", C.bad, WHITE)
		tag.Position, tag.ZIndex, tag.TextSize = UDim2.fromOffset(4, 4), 4, 12
	end
end

-- The stages on the left: every one reached, the one after it, and the rest folded into one line.
local function stageList(col: Instance, here: number)
	local reach = LevelRules.stage(math.min(S.profile.best + 1, LevelRules.LAST)).n
	local last = LevelRules.stage(LevelRules.LAST).n
	for n = 1, math.min(reach + 1, last) do
		local st = LevelRules.stage((n - 1) * LevelRules.STAGE + 1)
		local stars = 0
		for w = st.first, st.last do
			stars += StationProgress.starsOf(S.profile, w)
		end
		local open = n <= reach
		local note = if n == here
			then "You are here"
			elseif not open then `Beat wave {st.first - 1}`
			else `{stars} stars`
		local b = Style.button(col, "", function()
			S.wave = math.clamp(S.profile.best + 1, st.first, st.last)
			redraw.waves()
		end, if n == here then "primary" elseif open then "ghost" else "off", UDim2.new(1, -8, 0, 74))
		b.LayoutOrder = n
		local top = Style.small(b, `STAGE {n} · WAVES {st.first} TO {st.last}`, 11, C.muted, UDim2.new(1, -20, 0, 16))
		top.Position, top.ZIndex = UDim2.fromOffset(12, 8), 3
		local name = Style.text(b, st.name, 17, C.text, UDim2.new(1, -20, 0, 22))
		name.Position, name.ZIndex = UDim2.fromOffset(12, 24), 3
		local sub = Style.small(b, note, 12, C.muted, UDim2.new(1, -20, 0, 16))
		sub.Position, sub.ZIndex = UDim2.fromOffset(12, 48), 3
	end
	if reach + 1 < last then
		local rest = Style.small(
			col,
			`Stages {reach + 2} to {last}: up to wave {LevelRules.LAST}`,
			12,
			C.muted,
			UDim2.new(1, -8, 0, 30)
		)
		rest.LayoutOrder, rest.TextWrapped = 100, true
	end
end

-- The stage's road: ten waves in a row, what is behind the player, the one picked and the boss at the end.
local function road(col: Instance, st: LevelRules.Stage)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size, holder.LayoutOrder = UDim2.new(1, -8, 0, 96), 2
	holder.Parent = col
	local line = Style.frame(holder, UDim2.new(1, -40, 0, 6), C.cardHi)
	line.Position = UDim2.fromOffset(20, 28)
	Style.round(line, 3)
	local nodes = Instance.new("Frame")
	nodes.BackgroundTransparency = 1
	nodes.Size = UDim2.fromScale(1, 1)
	local cells = Instance.new("UIGridLayout")
	cells.CellSize, cells.CellPadding = UDim2.new(0.1, -4, 1, 0), UDim2.fromOffset(4, 0)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = nodes
	nodes.Parent = holder
	for w = st.first, st.last do
		local boss = w % LevelRules.BOSS_EVERY == 0
		local cleared, open = w <= S.profile.best, w <= S.profile.best + 1
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = w
		cell.Parent = nodes
		local side = if boss then 56 else 48
		local kind = if w == S.wave then "primary" elseif cleared then "good" elseif boss then "danger" else "ghost"
		local b = Style.button(cell, if boss then "BOSS" else tostring(w), function()
			if w <= S.profile.best + 1 then
				S.wave, waveDetail = w, true
				redraw.waves()
			end
		end, if open or boss then kind else "off", UDim2.fromOffset(side, side))
		b.AnchorPoint, b.Position, b.TextSize =
			Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, if boss then 2 else 6), if boss then 14 else 18
		Style.radius(b, side / 2)
		local got = StationProgress.starsOf(S.profile, w)
		local under = if w == S.profile.best + 1 and w ~= S.wave
			then "Next"
			elseif boss then (if LevelRules.boss(w) then (LevelRules.boss(w) :: StationConfig.Foe).name else "")
			else string.rep("★", got) .. string.rep("☆", if cleared then 3 - got else 0)
		local t = Style.small(
			cell,
			under,
			11,
			if got > 0 then C.accent:Lerp(C.ink, 0.25) else C.muted,
			UDim2.new(1, 4, 0, 30)
		)
		t.Position, t.TextXAlignment, t.TextWrapped = UDim2.fromOffset(-2, 62), Enum.TextXAlignment.Center, true
		t.TextYAlignment = Enum.TextYAlignment.Top
	end
end

-- The wave picked: who is coming, both sides' power in one bar and in words, and what clearing it pays.
local function wavePanel(col: Instance, team: { any })
	local card = Style.card(col, UDim2.new(1, -8, 0, 0))
	card.AutomaticSize, card.LayoutOrder = Enum.AutomaticSize.Y, 3
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size, inner.AutomaticSize = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y
	Style.list(inner, 10)
	Style.pad(inner, 14)
	inner.Parent = card
	local foes = LevelRules.enemies(S.wave)
	local crowd = LevelRules.crowd(S.wave)
	local head = Style.text(inner, `Wave {S.wave}`, 24, C.text, UDim2.new(1, 0, 0, 30))
	head.LayoutOrder = 1
	local sub = Style.small(
		inner,
		`{if crowd.rushes > 1 then `{crowd.rushes} rushes` else "One rush"}, {#foes} of the Legion`,
		13,
		C.muted,
		UDim2.new(1, 0, 0, 18)
	)
	sub.LayoutOrder = 2
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size, row.AutomaticSize, row.LayoutOrder = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y, 3
	Style.list(row, 8, true, true)
	row.Parent = inner
	local groups, kinds = {}, {}
	for _, e in foes do
		local key = e.s .. (if e.elite then "*" else "")
		if groups[key] == nil then
			groups[key] = { e = e, n = 0 }
			table.insert(kinds, key)
		end
		groups[key].n += 1
	end
	for _, key in kinds do
		foeCard(row, groups[key].e, groups[key].n)
	end

	-- the power match-up (decision 0096): the side with more power nearly always wins
	local ours, theirs = BattleRules.teamPower(team, 1), LevelRules.power(S.wave)
	local versus = Instance.new("Frame")
	versus.BackgroundTransparency = 1
	versus.Size, versus.LayoutOrder = UDim2.new(1, 0, 0, 44), 4
	versus.Parent = inner
	Style.small(versus, `Your team {Format.commas(ours)}`, 13, C.text, UDim2.new(0.5, 0, 0, 18))
	local right = Style.small(versus, `Legion {Format.commas(theirs)}`, 13, C.text, UDim2.new(0.5, 0, 0, 18))
	right.Position, right.TextXAlignment = UDim2.fromScale(0.5, 0), Enum.TextXAlignment.Right
	local bar, set = Style.bar(versus, UDim2.new(1, 0, 0, 14), C.good)
	bar.Position = UDim2.fromOffset(0, 22)
	bar.BackgroundColor3 = C.bad
	set(ours / math.max(1, ours + theirs))
	local odds = if #team == 0
		then "Your team is empty: open Animals and put one on it."
		elseif ours >= theirs * 1.1 then "You are stronger"
		elseif ours >= theirs then "A close one"
		else "They are stronger: train first, or bring a friend"
	local verdict =
		Style.text(inner, odds, 16, if ours >= theirs then C.good:Lerp(C.ink, 0.3) else C.bad, UDim2.new(1, 0, 0, 22))
	verdict.LayoutOrder = 5

	local first = S.wave > S.profile.best
	local payHead =
		Style.small(inner, if first then "FIRST CLEAR PAYS" else "A REPLAY PAYS", 12, C.muted, UDim2.new(1, 0, 0, 16))
	payHead.LayoutOrder = 6
	local coinsWon, xpWon, samplesWon = StationProgress.payout(S.profile, S.wave)
	local pay = Instance.new("Frame")
	pay.BackgroundTransparency = 1
	pay.Size, pay.LayoutOrder = UDim2.new(1, 0, 0, 26), 7
	Style.list(pay, 16, true)
	pay.Parent = inner
	Style.amount(pay, "coins", Format.commas(coinsWon))
	Style.amount(pay, "xp", `{xpWon} XP`)
	if samplesWon > 0 then
		Style.amount(pay, "samples", tostring(samplesWon))
	end
	local note = Style.small(
		inner,
		`A wave you have cleared pays {LevelRules.REPLAY_PCT}% again.`,
		12,
		C.muted,
		UDim2.new(1, 0, 0, 16)
	)
	note.LayoutOrder = 8
end

-- The Ranger's loan (decision 0119): when one is open for the wave picked, the four legends, which of the
-- player's animals the chosen one stands in for (a Titan for the War Elephant), and Take: it fights the next wave.
local loanPick, loanReplaces, loanTaken = 1, nil :: number?, false
local function loanCard(col: Instance, team: { any })
	local kind = StationIntro.loanFor(S.profile, S.wave, math.floor(Workspace:GetServerTimeNow()))
	if kind == nil or #team == 0 then
		loanTaken = false
		return
	end
	local legend = StationIntro.TEAM[loanPick]
	local legendTitan = StationRules.role(legend :: any) == StationConfig.TITAN
	local fits = {}
	for _, a in team do
		if (StationRules.role(a) == StationConfig.TITAN) == legendTitan then
			table.insert(fits, a)
		end
	end
	local chosen = nil
	for _, a in fits do
		chosen = chosen or (if a.id == loanReplaces then a else nil)
	end
	chosen = chosen or fits[1]
	loanReplaces = chosen and chosen.id
	local card = Style.card(col, UDim2.new(1, -8, 0, 214), C.gold)
	card.LayoutOrder = 5
	local title = Style.text(card, "The Ranger's loan", 17, C.text, UDim2.new(1, -20, 0, 22))
	title.Position, title.ZIndex = UDim2.fromOffset(10, 8), 3
	local sub = Style.small(
		card,
		if kind == "boss"
			then "For the boss: a legend at max level fights in place of one of yours, this wave only."
			else "Once a day: a legend at max level fights in place of one of yours, for one wave.",
		12,
		C.muted,
		UDim2.new(1, -20, 0, 32)
	)
	sub.Position, sub.TextWrapped, sub.ZIndex = UDim2.fromOffset(10, 30), true, 3
	for k, a in StationIntro.TEAM do
		local va = StationConfig.variant(a.s, a.v) :: StationConfig.Variant
		local pick = Style.button(card, "", function()
			loanPick, loanTaken = k, false
			redraw.waves()
		end, if k == loanPick then "primary" else "ghost", UDim2.fromOffset(54, 54))
		pick.Position, pick.ZIndex = UDim2.fromOffset(10 + (k - 1) * 60, 62), 3
		local view =
			Portrait.new(pick, StationRules.assetOf(a.s, a.v), { size = UDim2.fromOffset(46, 46), background = C.sand })
		view.Position, view.ZIndex = UDim2.fromOffset(4, 4), 4
		pick.Name = va.name
	end
	local swap = Style.small(
		card,
		if chosen
			then `{(StationConfig.variant(legend.s, legend.v) :: StationConfig.Variant).name} in place of:`
			else "No animal of that kind in your team",
		12,
		C.text,
		UDim2.new(1, -20, 0, 16)
	)
	swap.Position, swap.ZIndex = UDim2.fromOffset(10, 120), 3
	local row = Instance.new("Frame")
	row.BackgroundTransparency, row.ZIndex = 1, 3
	row.Position, row.Size = UDim2.fromOffset(10, 138), UDim2.new(1, -20, 0, 30)
	Style.list(row, 6, true)
	row.Parent = card
	for _, a in fits do
		local b = Style.button(row, App.nameOf(a), function()
			loanReplaces, loanTaken = a.id, false
			redraw.waves()
		end, if a.id == loanReplaces then "good" else "ghost", UDim2.fromOffset(0, 30))
		b.AutomaticSize, b.TextSize = Enum.AutomaticSize.X, 13
	end
	local take = Style.button(
		card,
		if loanTaken then "On loan for your next wave · Cancel" else "Take the loan",
		function()
			if loanTaken then
				loanTaken = not send("loan", 0, 0)
			elseif loanReplaces then
				loanTaken = send("loan", loanPick, loanReplaces) == true
			end
			redraw.waves()
		end,
		if loanTaken then "good" elseif chosen then "primary" else "off",
		UDim2.new(1, -20, 0, 36)
	)
	take.Position, take.TextSize, take.ZIndex = UDim2.fromOffset(10, 172), 15, 3
end

-- Who is fighting: the player, whoever stands in the portal's ring, and an open place for each one left.
local function partyColumn(col: Instance, team: { any })
	local head = Style.text(col, "Who is fighting", 20, C.text, UDim2.new(1, -8, 0, 26))
	head.LayoutOrder = 0
	local function place(order: number, name: string, sub: string, mark: string?, onClick: (() -> ())?, who: number?)
		local card = if onClick
			then Style.button(col, "", onClick, "ghost", UDim2.new(1, -8, 0, 64)) :: any
			else Style.card(col, UDim2.new(1, -8, 0, 64))
		card.LayoutOrder = order
		local face = Style.frame(card, UDim2.fromOffset(44, 44), if mark then C.sand else C.good)
		face.Position, face.ZIndex = UDim2.fromOffset(10, 10), 3
		Style.round(face, 22)
		Style.stroke(face, C.ink, 2)
		if who then -- their avatar's head, from Roblox's own thumbnails
			local avatar = Instance.new("ImageLabel")
			avatar.BackgroundTransparency, avatar.Size, avatar.ZIndex = 1, UDim2.fromScale(1, 1), 3
			avatar.Image = `rbxthumb://type=AvatarHeadShot&id={who}&w=150&h=150`
			Style.round(avatar, 22)
			avatar.Parent = face
		end
		if mark then
			local plus = Style.text(face, mark, 26, C.muted, UDim2.fromScale(1, 1))
			plus.TextXAlignment, plus.ZIndex = Enum.TextXAlignment.Center, 3
		end
		local n = Style.text(card, name, 16, C.text, UDim2.new(1, -72, 0, 20))
		n.Position, n.TextTruncate, n.ZIndex = UDim2.fromOffset(64, 12), Enum.TextTruncate.AtEnd, 3
		local s = Style.small(card, sub, 12, C.muted, UDim2.new(1, -72, 0, 16))
		s.Position, s.ZIndex = UDim2.fromOffset(64, 34), 3
	end
	place(1, "You", `Team power {Format.commas(BattleRules.teamPower(team, 1))}`, nil, nil, player.UserId)
	loanCard(col, team)
	local others = inPortal()
	for i, other in others do
		place(5 + i, other.DisplayName, "In the portal", nil, nil, other.UserId)
	end
	for k = #others + 2, 3 do
		place(5 + k, "An open place", "Invite a friend", "+", Hud.invite)
	end
	local how = Style.small(
		col,
		"Everyone in the portal's ring joins. The wave grows with each team, and everyone gets full pay.",
		12,
		C.muted,
		UDim2.new(1, -8, 0, 46)
	)
	how.LayoutOrder, how.TextWrapped = 10, true
	local go = Style.button(col, `Fight wave {S.wave}`, function()
		fight(S.wave)
	end, if #team > 0 then "danger" else "off", UDim2.new(1, -8, 0, 62))
	go.LayoutOrder, go.TextSize = 11, 22
	local key = Style.key(go, "B")
	key.AnchorPoint, key.Position = Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0)
	-- stars (decision 0097): the total, and a chest every StationProgress.CHEST_STARS
	local due = StationProgress.chestsDue(S.profile)
	local chest = Style.button(col, if due > 0 then "Open a star chest!" else "Star chests", function()
		if StationProgress.chestsDue(S.profile) > 0 then
			send("claim_chest")
		end
	end, if due > 0 then "primary" else "off", UDim2.new(1, -8, 0, 44))
	chest.LayoutOrder, chest.TextSize = 12, 16
	local box = Instance.new("ImageLabel") -- the star chest's picture (STATION-148)
	box.BackgroundTransparency, box.Image = 1, ICON.chest
	box.AnchorPoint, box.Position, box.Size, box.ZIndex =
		Vector2.new(0, 0.5), UDim2.new(0, 8, 0.5, -2), UDim2.fromOffset(36, 36), 3
	box.Parent = chest
end

redraw.waves = function()
	Style.clear(page)
	Style.clear(waves.chips)
	Style.clear(waves.count)
	S.wave = math.clamp(S.wave, 1, math.min(S.profile.best + 1, LevelRules.LAST))
	local st = LevelRules.stage(S.wave)
	local total = StationProgress.starTotal(S.profile)
	Style.chip(waves.chips, `Best: wave {S.profile.best}`)
	Style.chip(
		waves.chips,
		`{total} stars · next chest at {(S.profile.chests + 1) * StationProgress.CHEST_STARS}`,
		C.gold,
		C.ink
	)
	local team = StationProgress.fighters(S.profile)

	local phone = Style.compact(App.root.Size.Y.Offset)
	if phone and waveDetail then -- the picked wave and who fights it, full-screen (STATION-161)
		local col = Style.column(page, UDim.new(0, 0), UDim.new(1, 0), 1, 10)
		Style.back(col, function()
			waveDetail = false
			redraw.waves()
		end)
		wavePanel(Style.section(col, 1, 10), team)
		partyColumn(Style.section(col, 2, 8), team)
		return
	end
	local list = if phone then Style.column(page, UDim.new(0, 0), UDim.new(1, 0), 1, 12) else nil
	stageList(
		if list then Style.section(list, 2, 8) else Style.column(page, UDim.new(0, 0), UDim.new(0, 240), 1, 8),
		st.n
	)
	local mid = if list
		then Style.section(list, 1, 10)
		else Style.column(page, UDim.new(0, 252), UDim.new(1, -546), 2, 10)
	local cleared, stars = 0, 0
	for w = st.first, st.last do
		cleared += if w <= S.profile.best then 1 else 0
		stars += StationProgress.starsOf(S.profile, w)
	end
	local title = Style.text(mid, `Stage {st.n} · {st.name}`, 22, C.text, UDim2.new(1, -8, 0, 28))
	title.LayoutOrder = 0
	local sub = Style.small(
		mid,
		`{cleared} of {LevelRules.STAGE} cleared · {stars} of {LevelRules.STAGE * 3} stars`,
		13,
		C.muted,
		UDim2.new(1, -8, 0, 18)
	)
	sub.LayoutOrder = 1
	road(mid, st)
	if list then -- a phone: pick a wave on the road to see it and fight it
		local hint =
			Style.small(mid, "Tap a wave to see who is coming and fight it.", 13, C.muted, UDim2.new(1, -8, 0, 18))
		hint.LayoutOrder = 99
		return
	end
	wavePanel(mid, team)
	partyColumn(Style.column(page, UDim.new(1, -282), UDim.new(0, 282), 3, 8), team)
end

function S.openWaves()
	S.wave = if S.profile then math.min(S.profile.best + 1, LevelRules.LAST) else 1
	waveDetail = false
	show("waves")
end

return nil
