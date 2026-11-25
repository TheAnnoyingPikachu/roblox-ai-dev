--!strict
-- The moments (the Moments board): menus stay calm so these can be loud. Another player's rare hatch runs
-- across the top in ink, a new level says what it unlocked with one click to go and look, and a hatch's
-- reveal says where the animal went. (The reveal itself is HudWaves' `showRarity`; messages are
-- `Style.toast`.) One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationGoals = require(Shared:WaitForChild("StationGoals"))
local StationProgress = require(Shared:WaitForChild("StationProgress"))
local Style = require(script.Parent:WaitForChild("Style"))
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local root = App.root
local screen = App.screen
local Hud = App.Hud

local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- The server strip: "BlueRanger hatched a mythic Shadow Lion!" in ink across the top, under the goal.
local strip = Instance.new("TextLabel")
strip.Name = "ServerStrip"
strip.AnchorPoint, strip.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -80)
strip.Size, strip.AutomaticSize = UDim2.fromOffset(0, 44), Enum.AutomaticSize.X
strip.BackgroundColor3, strip.TextColor3 = C.ink, C.sand
strip.Font, strip.TextSize, strip.RichText = Enum.Font.FredokaOne, 19, true
strip.ZIndex, strip.Visible = 30, false
Style.round(strip, 22)
Style.stroke(strip, C.gold, 3)
local stripPad = Instance.new("UIPadding")
stripPad.PaddingLeft, stripPad.PaddingRight = UDim.new(0, 22), UDim.new(0, 22)
stripPad.Parent = strip
strip.Parent = root
local stripAt = 0
function Hud.announce(who: string, what: string)
	stripAt += 1
	local mine = stripAt
	local rich = string.gsub(what, "^(an?) (%a+)", function(article: string, rarity: string)
		local colour = Style.RARITY[string.lower(rarity)]
		return if colour
			then `{article} <font color="#{colour:ToHex()}">{string.upper(rarity)}</font>`
			else `{article} {rarity}`
	end)
	strip.Text = `<font color="#{C.gold:ToHex()}">{who}</font> hatched {rich}!`
	strip.Visible, strip.Position = true, UDim2.new(0.5, 0, 0, -80)
	TweenService:Create(strip, SLIDE, { Position = UDim2.new(0.5, 0, 0, 84) }):Play()
	task.delay(5, function()
		if stripAt == mine then
			TweenService:Create(strip, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
			task.wait(0.3)
			strip.Visible = stripAt ~= mine -- gone, unless a newer one came in meanwhile
		end
	end)
end

-- The level card: the new level in a gold ring, what it unlocked, and a button to go and look.
local card = Style.card(root, UDim2.fromOffset(430, 120))
card.Name, card.AnchorPoint, card.Visible = "LevelCard", Vector2.new(0.5, 0), false
card.Position, card.ZIndex = UDim2.new(0.5, 0, 0, 140), 30
local medal = Style.frame(card, UDim2.fromOffset(84, 84), C.gold)
medal.Position = UDim2.fromOffset(18, 18)
Style.round(medal, 42)
Style.stroke(medal, C.ink, 4)
local medalText = Style.text(medal, "", 38, C.ink, UDim2.fromScale(1, 1))
medalText.TextXAlignment = Enum.TextXAlignment.Center
local title = Style.text(card, "", 26, C.text, UDim2.new(1, -130, 0, 30))
title.Position = UDim2.fromOffset(118, 16)
local line = Style.small(card, "", 14, C.muted, UDim2.new(1, -130, 0, 20))
line.Position = UDim2.fromOffset(118, 48)
local look: StationConfig.Egg? = nil
local go = Style.button(card, "See what is inside", function()
	card.Visible = false
	if look then
		Hud.pickEgg(look.id)
	end
end, "primary", UDim2.fromOffset(190, 38))
go.Position, go.TextSize = UDim2.fromOffset(118, 72), 16
local cardAt = 0
function Hud.levelUp(level: number)
	cardAt += 1
	local mine = cardAt
	while S.fighting do -- waves pay mid-run: the card waits until the player is back from the field
		task.wait(0.5)
	end
	if cardAt ~= mine then
		return
	end
	local opened, nextEgg = nil, nil
	for _, d in StationConfig.EGGS do
		if d.level == level then
			opened = d
		elseif d.level and d.level > level and (nextEgg == nil or d.level < (nextEgg.level :: number)) then
			nextEgg = d
		end
	end
	look = opened
	medalText.Text, title.Text = tostring(level), `Level {level}!`
	line.Text = if opened
		then `The {opened.name} is unlocked`
		elseif nextEgg then `Next: the {nextEgg.name} at level {nextEgg.level}`
		else "Every egg is open"
	go.Visible = opened ~= nil
	card.Visible = true
	Style.sound("claim")
	local pop = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	pop.Scale, pop.Parent = 0.5, card
	TweenService:Create(pop, SLIDE, { Scale = 1 }):Play()
	task.delay(if opened then 8 else 5, function()
		if cardAt == mine then
			card.Visible = false
		end
	end)
end

-- Under a hatch's reveal: where the new animal went. A hatched animal joins the team when there is room
-- (StationProgress.crack); otherwise one click opens it in Animals to swap it in.
local choice = Instance.new("Frame")
choice.Name, choice.BackgroundTransparency, choice.Visible = "HatchChoice", 1, false
choice.AnchorPoint, choice.Position, choice.Size =
	Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, 150), UDim2.fromOffset(0, 48)
choice.AutomaticSize, choice.ZIndex = Enum.AutomaticSize.X, 45
Style.list(choice, 10, true).VerticalAlignment = Enum.VerticalAlignment.Center
choice.Parent = screen
local choiceAt = 0
function Hud.hatchChoice(a: any, seconds: number)
	choiceAt += 1
	local mine = choiceAt
	task.delay(0.6, function() -- the profile with the new animal arrives just after the reveal starts
		if choiceAt ~= mine or S.profile == nil then
			return
		end
		local born: any = nil
		for _, x in S.profile.animals do
			if x.s == a.s and x.v == a.v and (born == nil or x.id > born.id) then
				born = x
			end
		end
		Style.clear(choice)
		if born == nil then
			return
		end
		local joined = table.find(S.profile.team, born.id) ~= nil or S.profile.titan == born.id
		if joined then
			Style.chip(choice, "Joined your team", C.good, Color3.new(1, 1, 1)).TextSize = 18
		else
			local id = born.id
			Style.chip(choice, `In the barn · team full ({#S.profile.team}/{StationProgress.TEAM_SIZE})`).TextSize = 16
			Style.button(choice, "Swap it in", function()
				choice.Visible = false
				Hud.chooseAnimal(id)
			end, "primary", UDim2.fromOffset(140, 44)).TextSize =
				17
		end
		choice.Visible = true
		task.delay(seconds - 0.6, function()
			if choiceAt == mine then
				choice.Visible = false
			end
		end)
	end)
end

-- The goal log (the IntroOwn board): the goals done with what they pay, the one on screen with how far it is,
-- and the next few. Opened by clicking the goal strip.
local log = App.sheets.goals
App.redraw.goals = function()
	Style.clear(log.body)
	Style.clear(log.chips)
	Style.clear(log.count)
	local p = S.profile
	local nextGoal = StationGoals.next(p)
	local done, ahead = 0, 0
	for k, g in StationGoals.LIST do
		local got = table.find(p.goals, g.id) ~= nil
		local now = nextGoal ~= nil and g.id == nextGoal.id
		done += if got then 1 else 0
		if not got and not now then
			ahead += 1
			if ahead > 3 then
				continue
			end
		end
		local items = StationGoals.items(p, g)
		local row = Style.card(
			log.body,
			UDim2.new(1, -12, 0, if now then 84 else 64),
			if now then C.accent elseif got then C.good else nil
		)
		row.LayoutOrder = k
		if not got and not now then
			Style.paint(row, C.sand)
		end
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency = 1
		picture.Image = if got then Style.image("check") else (App.iconsOf(items))
		picture.Position, picture.Size = UDim2.fromOffset(12, 10), UDim2.fromOffset(44, 44)
		picture.Parent = row
		local name = Style.text(row, g.text, 18, C.text, UDim2.new(1, -84, 0, 22))
		name.Position = UDim2.fromOffset(66, 10)
		local words = App.rewardWords(items)
		local small = Style.small(
			row,
			if got then `Done: {words}` elseif now then `{StationGoals.label(p, g)} · pays {words}` else `Pays {words}`,
			13,
			C.muted,
			UDim2.new(1, -84, 0, 18)
		)
		small.Position = UDim2.fromOffset(66, 34)
		if now then
			local bar, set = Style.bar(row, UDim2.new(1, -84, 0, 10), C.accent)
			bar.Position = UDim2.fromOffset(66, 60)
			local f, of = StationGoals.progress(p, g)
			set(f / math.max(1, of))
		end
	end
	Style.chip(log.chips, `{done} of {#StationGoals.LIST} done`)
end

return nil
