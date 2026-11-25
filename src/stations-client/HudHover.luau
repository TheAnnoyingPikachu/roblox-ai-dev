--!strict
-- The card under the cursor (STATION-163, the concept board "The card under the cursor"): point at an
-- animal to know it at a glance: what it is, how strong it is, what it is doing now. Paper at the ranch,
-- glass in a fight. The player's own animal gets the full trading card (a click opens it in Animals);
-- someone else's says whose it is, how it compares with the player's best and which egg it hatches from.
-- It waits a moment before it shows, sits beside the cursor (flipped at the screen's edges), and on a
-- touch screen opens on a press and hold, docked at the top.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.
-- Every model carries what the card needs as attributes: the server's `Creatures.describe` (species,
-- variant, the six stats, `AnimalId`), `Owner` on a fight's model or on the ranch it stands in, `Side`,
-- `Hp`, `MaxHp` and `Power` in a fight, `PressKey` from HudFight. The cursor finds a model by its unseen
-- "CreatureHit" box.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local StationTrade = require(Shared:WaitForChild("StationTrade"))
local Format = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Format"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local N = Style.N
local RARITY_COLOUR = App.RARITY_COLOUR
local RANK = App.RANK
local ROLE_NAME = App.ROLE_NAME
local ROLE_COLOUR = App.ROLE_COLOUR
local GROUP_NAME = App.GROUP_NAME
local STAT_SHORT = App.STAT_SHORT
local RAINBOW = App.RAINBOW
local screen = App.screen
local Hud = App.Hud
local live = App.live
local darker = App.darker
local player = Players.LocalPlayer

local PAUSE = 0.25 -- seconds on one animal before its card shows, so sweeping the mouse is quiet

local STAT_COLOUR: { [string]: Color3 } = {
	speed = C.accent,
	strength = C.bad,
	stamina = C.good,
	mana = N.edge,
	health = C.info,
	defence = C.muted,
}
local STAT_NAME: { [string]: string } = {
	speed = "Speed",
	strength = "Strength",
	stamina = "Stamina",
	mana = "Mana",
	health = "Health",
	defence = "Defence",
}
local PRESS_SHORT: { [string]: string } = { -- how its power attack is pressed (decision 0109)
	ring = "Hold its key till the ring fills",
	needle = "Press as the needle crosses the gold",
	chain = "Press the arrows in order",
	mash = "Mash Space before the bar runs out",
}

local function num(m: Instance, name: string): number?
	local x = m:GetAttribute(name)
	return if type(x) == "number" then x else nil
end

-- Whose a model is: a fight's model carries `Owner`, a ranch's animal stands in the plot that does.
local function ownerOf(m: Instance): number?
	local at: Instance? = m
	while at and at ~= Workspace do
		local o = at:GetAttribute("Owner")
		if type(o) == "number" then
			return if o ~= 0 then o else nil
		end
		at = at.Parent
	end
	return nil
end

-- The egg that gives this animal most often, and how often ("Dusk Egg", "1 in 250"); nil for none.
local function eggOf(s: string, v: string?): (string?, string?)
	local best: StationConfig.Egg?, ppm = nil, 0
	for _, egg in StationConfig.EGGS do
		local here, rareShare = 0, 0
		for _, drop in egg.rare do
			rareShare += drop.ppm
			if v and drop.s == s and drop.v == v then
				here = drop.ppm
			end
		end
		if v == nil then
			for _, o in egg.odds do
				if o.id == s then
					here = o.bp / 10000 * (StationRules.PPM - rareShare)
				end
			end
		end
		if here > ppm then
			best, ppm = egg, here
		end
	end
	if best == nil then
		return nil, nil
	end
	return best.name,
		if ppm >= 100_000
			then `{math.floor(ppm / 10_000 + 0.5)}%`
			else `1 in {Format.commas(math.floor(StationRules.PPM / ppm + 0.5))}`
end

-- The player's strongest Titan, or strongest other animal.
local function bestPower(titan: boolean): number
	local best = 0
	for _, a in if S.profile then S.profile.animals else {} do
		if (StationRules.role(a) == StationConfig.TITAN) == titan then
			best = math.max(best, BattleRules.powerOf(live(a)))
		end
	end
	return best
end

local function label(parent: Instance, text: string, size: number, colour: Color3, x: number, y: number, w: UDim)
	local l = Style.text(parent, text, size, colour, UDim2.new(w, UDim.new(0, size + 6)))
	l.Position, l.TextTruncate, l.ZIndex = UDim2.fromOffset(x, y), Enum.TextTruncate.AtEnd, 3
	return l
end

local function small(parent: Instance, text: string, colour: Color3, x: number, y: number, w: UDim)
	local l = Style.small(parent, text, 12, colour, UDim2.new(w, UDim.new(0, 16)))
	l.Position, l.TextTruncate, l.ZIndex = UDim2.fromOffset(x, y), Enum.TextTruncate.AtEnd, 3
	return l
end

local function right(l: TextLabel)
	l.AnchorPoint, l.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	l.Position = UDim2.new(1, -l.Position.X.Offset, 0, l.Position.Y.Offset)
end

-- What the model is: (its name, rarity, role, group, the stats as the attributes stand, a foe's entry).
local function whatIs(m: Model)
	local s, v = m:GetAttribute("Species"), m:GetAttribute("FoeId")
	local foe = if type(v) == "string" then StationConfig.foe(v) else nil
	local sp = if type(s) == "string" then StationConfig.species(s) else nil
	local vid = m:GetAttribute("Variant")
	local va = if sp and type(vid) == "string" then StationConfig.variant(sp.id, vid) else nil
	local stats = {}
	for _, stat in StationConfig.STATS do
		stats[stat] = num(m, stat) or 0
	end
	return {
		foe = foe,
		s = if foe then foe.id elseif sp then sp.id else nil,
		v = if va then va.id else nil,
		name = if foe then foe.name elseif va then va.name elseif sp then sp.name else "?",
		rarity = if va then va.tier elseif sp then sp.rarity else nil,
		role = if foe
			then foe.role
			elseif sp then StationRules.role({ s = sp.id, v = if va then va.id else nil } :: any)
			else nil,
		group = if foe then foe.group elseif sp then sp.group else nil,
		stats = stats,
	}
end

-- 1 · The player's own animal, away from a fight: the trading card.
local function ownCard(holder: Instance, a: any): (Frame, () -> ())
	local rarity = StationRules.rarity(a)
	local colour = RARITY_COLOUR[rarity] or C.text
	local role = StationRules.role(a)
	local sp = StationConfig.species(a.s)
	local card = Style.card(holder, UDim2.fromOffset(268, 372))
	Style.paint(card, C.sand)
	local glow = Style.stroke(card, colour, 5)
	glow.Transparency = 0.55

	local banner = Style.frame(card, UDim2.new(1, -12, 0, 108), colour)
	banner.Position, banner.ZIndex, banner.ClipsDescendants = UDim2.fromOffset(6, 6), 2, true
	Style.round(banner, 14)
	Style.stroke(banner, C.ink, 2)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.45), colour:Lerp(C.ink, 0.12))
	shade.Parent = banner
	local shine: Frame? = nil
	if (RANK[rarity] or 0) >= (RANK.legendary or 5) then -- a shine sweeps across legendary and rarer
		local f = Style.frame(banner, UDim2.new(0, 46, 1, 0), Color3.new(1, 1, 1))
		f.Rotation, f.ZIndex = 18, 3
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = f
		shine = f
	end
	local view = Portrait.new(
		banner,
		StationRules.assetOf(a.s, a.v),
		{ size = UDim2.fromOffset(86, 86), background = darker(colour), rainbow = a.rainbow }
	)
	view.AnchorPoint, view.Position, view.ZIndex = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6), 4
	(view:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0.5, 0) -- round
	Style.stroke(view, C.ink, 3)
	-- the chips sit on the banner's bottom edge, clear of the picture (SHANNON, 2026-11-25)
	local tag = Style.chip(card, string.upper(rarity), C.ink, colour)
	tag.AnchorPoint, tag.Position = Vector2.new(0, 0.5), UDim2.fromOffset(14, 114)
	tag.Size, tag.TextSize, tag.ZIndex = UDim2.fromOffset(0, 22), 12, 5
	local slot = table.find(S.profile.team, a.id)
	local where = if S.profile.titan == a.id
		then "TITAN"
		elseif a.at then "TRAINING"
		elseif slot then `TEAM · {slot}`
		else nil
	if where then
		local st = Style.chip(
			card,
			where,
			if where == "TITAN" then C.gold elseif a.at then C.info else C.good,
			if where == "TITAN" then C.ink else Color3.new(1, 1, 1)
		)
		st.AnchorPoint, st.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0, 114)
		st.Size, st.TextSize, st.ZIndex = UDim2.fromOffset(0, 22), 12, 5
	end

	label(card, StationTrade.nameOf(a), 21, C.text, 14, 136, UDim.new(1, -120))
	local power =
		label(card, `⚡ {Format.commas(BattleRules.powerOf(live(a)))}`, 18, C.text, 14, 138, UDim.new(0, 100))
	right(power)
	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position, chips.Size, chips.ZIndex = UDim2.fromOffset(14, 166), UDim2.new(1, -28, 0, 22), 3
	Style.list(chips, 5, true)
	chips.Parent = card
	local function chip(text: string, fill: Color3, ink: Color3?): TextLabel
		local c = Style.chip(chips, text, fill, ink)
		c.Size, c.TextSize, c.ZIndex = UDim2.fromOffset(0, 20), 11, 4
		return c
	end
	chip(
		string.upper(ROLE_NAME[role] or "?"),
		ROLE_COLOUR[role] or C.cardHi,
		if role == "titan" then C.ink else Color3.new(1, 1, 1)
	)
	chip(string.upper(GROUP_NAME[if sp then sp.group else ""] or "?"), Color3.new(1, 1, 1))
	local worn = StationRules.coatOf(a)
	if worn then
		local bonus = if worn.all then ` +{worn.all}%` elseif worn.pct then ` +{worn.pct}%` else ""
		local c = chip(`{string.upper(worn.name)} COAT{bonus}`, Style.COAT[worn.id] or Color3.new(1, 1, 1))
		if Style.COAT[worn.id] == nil then -- rainbow, prismatic
			local colours = Instance.new("UIGradient")
			colours.Color = RAINBOW
			colours.Parent = c
		end
	end

	-- the six stats: the value, and a bar of its level out of MAX_LEVEL (how far it is trained)
	local now = live(a)
	for i, stat in StationConfig.STATS do
		local y = 196 + (i - 1) * 18
		small(card, STAT_SHORT[stat] or stat, C.text, 14, y, UDim.new(0, 40))
		local back, set = Style.bar(card, UDim2.new(1, -112, 0, 10), STAT_COLOUR[stat])
		back.Position, back.ZIndex = UDim2.fromOffset(56, y + 3), 3
		set(StationRules.level(now, stat :: any) / StationConfig.MAX_LEVEL)
		local value = small(card, tostring(StationRules.stat(now, stat :: any)), C.text, 14, y, UDim.new(0, 44))
		right(value)
	end

	-- what it is doing now, kept up to date
	local doing = Style.frame(card, UDim2.new(1, -28, 0, 30), C.info:Lerp(Color3.new(1, 1, 1), 0.72))
	doing.Position, doing.ZIndex = UDim2.fromOffset(14, 308), 3
	Style.round(doing, 10)
	Style.stroke(doing, C.ink, 2)
	local line = label(doing, "", 13, C.text, 10, 4, UDim.new(1, -20))
	local function update()
		if a.at then
			local st = StationConfig.station(a.at)
			local stat = if st then st.stat else "speed"
			local left = string.match(Hud.statText(live(a), stat, true), "  (.+)$")
			local level = StationRules.level(live(a), stat :: any)
			line.Text = `Training {STAT_NAME[stat] or stat}`
				.. (if left then ` · level {level + 1} in {left}` else ` · level {level}`)
		elseif S.profile.titan == a.id then
			line.Text = "Your Titan, asleep in its den"
		elseif slot then
			line.Text = `In your team, slot {slot}`
		else
			line.Text = "Resting at the ranch"
		end
	end
	update()

	local how = small(card, PRESS_SHORT[BattleRules.pressOf(a)] or "", C.muted, 14, 346, UDim.new(1, -100))
	how.TextSize = 11
	local open = Instance.new("Frame")
	open.BackgroundTransparency = 1
	open.AnchorPoint, open.Position, open.Size, open.ZIndex =
		Vector2.new(1, 0), UDim2.new(1, -14, 0, 342), UDim2.fromOffset(84, 24), 3
	open.Parent = card
	local list = Style.list(open, 4, true)
	list.HorizontalAlignment, list.VerticalAlignment = Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center
	small(open, "Open", C.muted, 0, 0, UDim.new(0, 32)).TextXAlignment = Enum.TextXAlignment.Right
	Style.key(open, "Click")

	return card,
		function()
			update()
			if shine then
				local t = (os.clock() % 3.2) / 3.2
				shine.Position = UDim2.fromScale(-0.3 + 1.7 * math.min(1, t / 0.6), 0)
			end
		end
end

-- 2 · Someone else's animal (or one on show at the hub): whose it is, how it compares, its egg.
local function otherCard(holder: Instance, m: Model, what: any, owner: number?): Frame
	local colour = RARITY_COLOUR[what.rarity or ""] or C.text
	local card = Style.card(holder, UDim2.fromOffset(238, 200))
	Style.paint(card, C.sand)
	local head = Style.frame(card, UDim2.new(1, -12, 0, 40), C.cardHi)
	head.Position, head.ZIndex = UDim2.fromOffset(6, 6), 2
	Style.round(head, 12)
	local who = if owner then Players:GetPlayerByUserId(owner) else nil
	if owner then
		local face = Instance.new("ImageLabel")
		face.Size, face.Position, face.ZIndex = UDim2.fromOffset(28, 28), UDim2.fromOffset(6, 6), 3
		face.BackgroundColor3 = C.info
		face.Image = `rbxthumb://type=AvatarHeadShot&id={owner}&w=48&h=48`
		face.Parent = head
		Style.round(face, 14)
		Style.stroke(face, C.ink, 2)
	end
	label(
		head,
		if who then `{who.DisplayName}'s` elseif owner then "A player's" else "On show at the hub",
		14,
		C.text,
		if owner then 40 else 10,
		9,
		UDim.new(1, -110)
	)
	local level = if who then who:GetAttribute("Level") else nil
	if type(level) == "number" then
		right(small(head, `LEVEL {level}`, C.muted, 10, 12, UDim.new(0, 70)))
	end

	local view = Portrait.new(
		card,
		StationRules.assetOf(what.s, what.v),
		{ size = UDim2.fromOffset(74, 74), background = darker(colour), rainbow = m:GetAttribute("Rainbow") == true }
	)
	view.Position, view.ZIndex = UDim2.fromOffset(10, 54), 3
	Style.round(view, 14)
	Style.stroke(view, colour, 3)
	label(card, what.name, 18, C.text, 94, 56, UDim.new(1, -104))
	small(
		card,
		`{string.upper(what.rarity or "")} · {string.upper(ROLE_NAME[what.role] or "?")}`,
		colour:Lerp(C.ink, 0.3),
		94,
		80,
		UDim.new(1, -104)
	)
	local power = BattleRules.powerOf({ s = what.s, stats = what.stats } :: any, 1)
	label(card, `⚡ {Format.commas(power)}`, 16, C.text, 94, 100, UDim.new(1, -104))

	local words = {}
	local titan = what.role == StationConfig.TITAN
	local mine = bestPower(titan)
	if mine > 0 and owner ~= player.UserId then
		local r = power / mine
		local whose = if titan then "your Titan's" else "your best's"
		table.insert(
			words,
			if r >= 1.05
				then `{string.format("%.1f", r)}x {whose} power.`
				elseif r <= 0.95 then `{if titan then "Your Titan" else "Your best"} is {string.format(
					"%.1f",
					1 / r
				)}x as strong.`
				else `About as strong as {if titan then "your Titan" else "your best"}.`
		)
	end
	local eggName, odds = eggOf(what.s, what.v)
	table.insert(words, if eggName then `From the {eggName}, {odds}.` else "Never from an egg.")
	local box = Style.frame(card, UDim2.new(1, -20, 0, 50), C.good:Lerp(Color3.new(1, 1, 1), 0.72))
	box.Position, box.ZIndex = UDim2.fromOffset(10, 138), 3
	Style.round(box, 10)
	Style.stroke(box, C.ink, 2)
	local text = Style.text(box, table.concat(words, " "), 13, C.text, UDim2.new(1, -16, 1, -8))
	text.Position, text.ZIndex = UDim2.fromOffset(8, 4), 4
	text.TextYAlignment = Enum.TextYAlignment.Center
	return card
end

-- 3 · In a fight, on glass: health, what it hits for, its power (and the player's own key when ready).
local function fightCard(holder: Instance, m: Model, what: any, own: boolean): (Frame, () -> ())
	local foe = what.foe
	local edge = if foe then N.bad else N.edge
	local card = Style.glass(holder, UDim2.fromOffset(if foe then 236 else 206, if foe then 122 else 112), 16)
	card.ZIndex = 2
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = edge
	local name = m:GetAttribute("FoeName")
	label(card, if type(name) == "string" then name else what.name, 18, N.text, 12, 8, UDim.new(1, -84))
	local key: TextLabel? = nil
	if foe and (m:GetAttribute("Boss") == true or m:GetAttribute("Elite") == true) then
		local tag = Style.chip(card, if m:GetAttribute("Boss") == true then "BOSS" else "ELITE", N.gold, N.glass)
		tag.AnchorPoint, tag.Position, tag.Size, tag.TextSize, tag.ZIndex =
			Vector2.new(1, 0), UDim2.new(1, -10, 0, 10), UDim2.fromOffset(0, 20), 11, 4
	elseif own then
		local k = Style.key(card, "", true)
		k.AnchorPoint, k.Position = Vector2.new(1, 0), UDim2.new(1, -10, 0, 10)
		key = k
	end
	local hpBack, health = Style.track(card, UDim2.new(1, -24, 0, 12), if foe then N.bad else N.good)
	hpBack.Position = UDim2.fromOffset(12, 38)
	local hpText = small(card, "", N.muted, 12, 56, UDim.new(0.6, -12))
	local dmg = BattleRules.DMG_BASE + math.floor(what.stats.strength * BattleRules.DMG_PER_STRENGTH)
	if what.role == "attack" then
		dmg = math.floor(dmg * BattleRules.ATTACK_BONUS)
	end
	right(small(card, `hits for ~{Format.commas(dmg)}`, N.muted, 12, 56, UDim.new(0.4, 0)))
	local powerSet: ((number) -> ())? = nil
	local powerText: TextLabel
	if foe then
		local words = if foe.ability == "revive"
			then "Power: raises its fallen allies. Kill it first."
			elseif foe.ability == "sweep" then "Power: strikes your whole team at once."
			else "Power: a heavy blow each time its meter fills."
		powerText = Style.small(card, words, 12, N.lilac, UDim2.new(1, -24, 0, 34))
		powerText.Position, powerText.TextWrapped, powerText.ZIndex = UDim2.fromOffset(12, 78), true, 3
	else
		local back, set = Style.track(card, UDim2.new(1, -24, 0, 6), N.gold)
		back.Position = UDim2.fromOffset(12, 78)
		powerSet = set
		powerText = small(card, "", N.gold, 12, 88, UDim.new(1, -24))
	end
	local press = if what.s then BattleRules.pressOf({ s = what.s, v = what.v } :: any) else "ring"
	return card,
		function()
			local hp, max = num(m, "Hp") or 0, math.max(1, num(m, "MaxHp") or 1)
			health(math.max(0, hp) / max)
			hpText.Text = `{Format.commas(math.max(0, math.floor(hp)))} / {Format.commas(max)} health`
			if powerSet then
				local share = math.clamp(num(m, "Power") or 0, 0, 1)
				powerSet(share)
				local ready = share >= 1 and hp > 0
				local k = m:GetAttribute("PressKey")
				local keyText = if type(k) == "string" and k ~= "" then k else nil
				if key then
					key.Text = keyText or ""
					key.Visible = own and ready and keyText ~= nil and not Style.touch()
				end
				powerText.Text = if hp <= 0
					then "Knocked out"
					elseif not ready then `Power charging: {math.floor(share * 100)}%`
					elseif not own then "Power ready"
					elseif press == "ring" then `Power ready: hold {keyText or "its key"}`
					elseif press == "needle" then `Power ready: press {keyText or "its key"} on the gold`
					elseif press == "chain" then "Power ready: the arrows in order"
					else "Power ready: mash Space"
			end
		end
end

-- The card ------------------------------------------------------------------------------------------

local holder = Instance.new("Frame")
holder.Name = "AnimalCard"
holder.BackgroundTransparency = 1
holder.Size = UDim2.fromOffset(0, 0)
holder.ZIndex = 20
holder.Parent = screen

local card: Frame? = nil
local tick: (() -> ())? = nil
local shown: Model? = nil -- the model the card is for
local ownId: number? = nil -- the player's own animal's id, which a click opens in Animals
local hovered: Model? = nil
local hoveredSince = 0
local docked = false -- a touch's card, at the top of the screen
local dockToken = 0

local function close()
	if card then
		card:Destroy()
	end
	card, tick, shown, ownId = nil, nil, nil, nil
end

local function open(m: Model)
	close()
	local what = whatIs(m)
	if what.s == nil then
		return
	end
	local owner = ownerOf(m)
	local mine = owner == player.UserId
	if num(m, "Side") then
		card, tick = fightCard(holder, m, what, mine and num(m, "Side") == 1)
	else
		local id = num(m, "AnimalId")
		local a = nil
		for _, x in if mine and id and S.profile then S.profile.animals else {} do
			if x.id == id then
				a = x
			end
		end
		if a then
			card, tick = ownCard(holder, a)
			ownId = a.id
		else
			card = otherCard(holder, m, what, owner)
		end
	end
	shown = m
end

-- The animal at a point on the screen (`viewport`: in the viewport's numbers, with the top bar).
local function under(at: Vector2, viewport: boolean): Model?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local ray = if viewport then camera:ViewportPointToRay(at.X, at.Y) else camera:ScreenPointToRay(at.X, at.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("CreatureHit")
	local found = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local model = if found then found.Instance.Parent else nil
	return if model and model:IsA("Model") then model else nil
end

RunService.RenderStepped:Connect(function()
	local inset = if screen.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
	local at = UserInputService:GetMouseLocation()
	if not docked then
		local m = if UserInputService.MouseEnabled
				and not Style.touch()
				and S.openName == nil
			then under(at, true)
			else nil
		if m ~= hovered then
			hovered, hoveredSince = m, os.clock()
		end
		if m ~= shown and shown ~= nil then
			close()
		end
		if m and shown == nil and os.clock() - hoveredSince >= PAUSE then
			open(m)
		end
	end
	if shown and shown.Parent == nil then
		close()
	end
	local c = card
	if c == nil then
		return
	end
	if tick then
		tick()
	end
	local size, room = c.AbsoluteSize, screen.AbsoluteSize
	local x, y
	if docked then
		x, y = (room.X - size.X) / 2, 12
	else
		local p = at - inset
		x = if p.X + 22 + size.X > room.X - 8 then p.X - 22 - size.X else p.X + 22 -- flipped at the edge
		y = math.clamp(p.Y - size.Y * 0.4, 8, math.max(8, room.Y - size.Y - 8))
	end
	c.Position = UDim2.fromOffset(math.max(8, x), y)
end)

-- On a touch screen: press and hold an animal, the card docks at the top and stays a moment after.
UserInputService.TouchLongPress:Connect(function(touches: { Vector2 }, state: Enum.UserInputState, processed: boolean)
	if processed or touches[1] == nil then
		return
	end
	if state == Enum.UserInputState.Begin then
		local m = under(touches[1], false)
		if m then
			dockToken += 1
			docked = true
			open(m)
		end
	elseif docked then
		dockToken += 1
		local mine = dockToken
		task.delay(2, function()
			if dockToken == mine then
				docked = false
				close()
			end
		end)
	end
end)

-- A click on the player's own animal opens it in Animals: on the button's release, or that release would
-- land on the menu's backdrop and close it again.
local pressedOn: number? = nil
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pressedOn = if processed or S.fighting then nil else ownId
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local id = pressedOn
	pressedOn = nil
	if id and id == ownId then
		close()
		Hud.chooseAnimal(id)
	end
end)

return nil
