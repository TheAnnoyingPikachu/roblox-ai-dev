--!strict
-- The intro (decision 0116, the Intro boards): the Ranger's offer, the lessons during the borrowed fight
-- and the goodbye. Shown to a save that has not done it; the server ends it (won or skipped).
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local StationIntro = require(Shared:WaitForChild("StationIntro"))
local StationRules = require(Shared:WaitForChild("StationRules"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))
local remotes = ReplicatedStorage:WaitForChild("StationsRemotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local App: any = require(script.Parent:WaitForChild("HudApp"))
local S = App.S
local C = App.C
local ROLE_NAME = App.ROLE_NAME
local RARITY_COLOUR = App.RARITY_COLOUR
local REFUSED = App.REFUSED
local Hud = App.Hud
local screen = App.screen
local root = App.root
local show = App.show
local N = Style.N
local player = Players.LocalPlayer

local SKIP_AFTER = 10 -- seconds before "Skip intro" shows, for players who know the game
local TAPS = 10 -- strikes the first lesson asks for

-- The offer: one card and one button. Nothing else is on screen until the intro is over.
local offer = Style.panel(root, UDim2.fromOffset(640, 356))
offer.Name, offer.Visible, offer.ZIndex = "IntroOffer", false, 9
offer.AnchorPoint, offer.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52)
do
	Style.small(offer, "THE RANGER", 13, C.muted, UDim2.fromOffset(200, 16)).Position = UDim2.fromOffset(24, 18)
	local loan = Style.chip(offer, "ON LOAN · ONE BATTLE", C.accent)
	loan.AnchorPoint, loan.Position = Vector2.new(1, 0), UDim2.new(1, -22, 0, 14)
	local says = Style.text(offer, "The Legion is at the castle. Take my team and show them.", 23, C.text)
	says.Position, says.Size, says.AutomaticSize =
		UDim2.fromOffset(24, 40), UDim2.new(1, -48, 0, 62), Enum.AutomaticSize.None
	local team = Instance.new("Frame")
	team.BackgroundTransparency = 1
	team.Position, team.Size = UDim2.fromOffset(24, 108), UDim2.new(1, -48, 0, 150)
	Style.list(team, 12, true)
	team.Parent = offer
	for k, a in StationIntro.TEAM do
		local va = StationConfig.variant(a.s, a.v) :: any
		local card = Style.card(team, UDim2.fromOffset(139, 146), RARITY_COLOUR[va.rarity])
		card.LayoutOrder = k
		local view = Portrait.new(
			card,
			StationRules.assetOf(a.s, a.v),
			{ size = UDim2.fromOffset(84, 84), background = C.cardHi }
		)
		view.AnchorPoint, view.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8)
		Style.round(view, 12)
		local name = Style.text(card, va.name, 15, C.text, UDim2.new(1, -8, 0, 18))
		name.Position, name.TextXAlignment = UDim2.fromOffset(4, 96), Enum.TextXAlignment.Center
		local role = Style.small(
			card,
			string.upper(ROLE_NAME[StationRules.role({ s = a.s, v = a.v } :: any)] or ""),
			12,
			C.muted
		)
		role.Size, role.AutomaticSize = UDim2.new(1, -8, 0, 16), Enum.AutomaticSize.None
		role.Position, role.TextXAlignment = UDim2.fromOffset(4, 118), Enum.TextXAlignment.Center
	end
end
local toBattle = Style.button(offer, "To battle", function() end, "good", UDim2.fromOffset(280, 60))
toBattle.AnchorPoint, toBattle.Position, toBattle.TextSize = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -22), 26
Style.radius(toBattle, 18)
local space = Style.key(toBattle, "Space")
space.AnchorPoint, space.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, 0)
local skip = Style.button(root, "Skip intro", function() end, "ghost", UDim2.fromOffset(120, 40))
skip.Name, skip.Visible, skip.ZIndex, skip.TextSize = "IntroSkip", false, 9, 15
skip.AnchorPoint, skip.Position = Vector2.new(1, 0), UDim2.new(1, -16, 0, 16)

-- The lessons, during the borrowed fight: four steps along the top and one paper note that says the one
-- thing to do next. They are chances, not gates: the fight goes on and cannot be lost.
local steps = Instance.new("Frame")
steps.Name, steps.BackgroundTransparency, steps.Visible, steps.ZIndex = "IntroSteps", 1, false, 7
steps.AnchorPoint, steps.Position, steps.Size =
	Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 128), UDim2.fromOffset(520, 30)
local stepList = Style.list(steps, 8, true)
stepList.HorizontalAlignment = Enum.HorizontalAlignment.Center
steps.Parent = root
local LESSONS = {
	{
		id = "tap",
		name = "Tap",
		says = "Tap the enemies: every tap is a strike on the front line",
		phone = "Tap the enemies: every tap is a strike on the front line",
	},
	{
		id = "ring",
		name = "Hold",
		says = "A gold plate means its power attack is ready: hold its key until the ring is full",
		phone = "A gold plate means its power attack is ready: hold the card until the ring is full",
	},
	{
		id = "shield",
		name = "Shield",
		says = "When the boss winds up, press F: the shield halves the hit",
		phone = "When the boss winds up, tap the shield: it halves the hit",
	},
	{
		id = "mash",
		name = "Titan",
		says = "The Titan's finisher: mash Space when its plate turns gold",
		phone = "The Titan's finisher: mash its card when its plate turns gold",
	},
}
local chips: { [string]: TextLabel } = {}
for k, lesson in LESSONS do
	local chip = Style.chip(steps, `{k}  {lesson.name}`, N.glass, N.text)
	chip.LayoutOrder, chip.BackgroundTransparency = k, 0.1
	local edge = chip:FindFirstChildOfClass("UIStroke") :: UIStroke
	edge.Color = N.edge
	chips[lesson.id] = chip
end
local note = Style.pill(root, UDim2.fromOffset(560, 54), 16)
note.Name, note.Visible, note.ZIndex = "IntroNote", false, 7
note.AnchorPoint, note.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 168) -- under the steps, clear of the press cards
local noteText = Style.text(note, "", 17, C.text, UDim2.new(1, -28, 1, 0))
noteText.Position, noteText.TextXAlignment = UDim2.fromOffset(14, 0), Enum.TextXAlignment.Center

-- The goodbye: the win is loud, the goodbye is short, and the eggs are already hatching.
local bye = Style.panel(root, UDim2.fromOffset(560, 262))
bye.Name, bye.Visible, bye.ZIndex = "IntroBye", false, 9
bye.AnchorPoint, bye.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
do
	local title = Style.text(bye, "The Legion is beaten!", 32, C.text, UDim2.new(1, -48, 0, 40))
	title.Position, title.TextXAlignment = UDim2.fromOffset(24, 18), Enum.TextXAlignment.Center
	local says = Style.text(
		bye,
		"The Ranger's team heads home. You will meet them again.",
		17,
		C.muted,
		UDim2.new(1, -48, 0, 24)
	)
	says.Position, says.TextXAlignment = UDim2.fromOffset(24, 62), Enum.TextXAlignment.Center
	local gift = Style.card(bye, UDim2.new(1, -48, 0, 70), C.accent)
	gift.Position = UDim2.fromOffset(24, 100)
	Style.icon(gift, "egg", 50).Position = UDim2.fromOffset(12, 10)
	local what = Style.text(gift, "3 Starter Eggs, already hatching", 19, C.text, UDim2.new(1, -84, 0, 24))
	what.Position = UDim2.fromOffset(72, 12)
	Style.small(
		gift,
		"One animal of each class. They open at your hatchery in seconds.",
		13,
		C.muted,
		UDim2.new(1, -84, 0, 18)
	).Position =
		UDim2.fromOffset(72, 38)
end
local home = Style.button(bye, "To my ranch", function() end, "primary", UDim2.fromOffset(260, 52))
home.AnchorPoint, home.Position, home.TextSize = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -20), 22

local shieldsAt = player:GetAttribute("ShieldAt")
local done: { [string]: boolean } = {}
local shownAt = 0

-- Who sees what: the offer until the fight starts, the lessons during it, nothing once the intro is done.
local function layout()
	local playerPills = root:FindFirstChild("Player") :: GuiObject?
	if playerPills then
		playerPills.Visible = not S.intro or S.lesson == true
	end
	Hud.navShown()
end

local function begin()
	if not offer.Visible then
		return
	end
	offer.Visible, skip.Visible = false, false
	local ok, code = request:InvokeServer("intro", "fight")
	if not ok then
		offer.Visible = true
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
		return
	end
	table.clear(done)
	S.strikes, S.fired, S.lesson = 0, {}, true
	shieldsAt = player:GetAttribute("ShieldAt")
	steps.Visible, note.Visible = true, true
	S.music("boss")
	layout()
end
toBattle.Activated:Connect(begin)
UserInputService.InputBegan:Connect(function(input, typing)
	if input.KeyCode == Enum.KeyCode.Space and not typing and offer.Visible then
		begin()
	end
end)
skip.Activated:Connect(function()
	local ok, code = request:InvokeServer("intro", "skip")
	if not ok then
		Style.toast(screen, REFUSED[code] or `Can't do that ({code})`, nil, "bad")
	end
end)
home.Activated:Connect(function()
	bye.Visible = false
	S.intro = false
	S.music(nil)
	request:InvokeServer("home") -- clears the field and walks nobody anywhere: they never left the ranch
	layout()
end)

-- The save arrived or changed: show the offer to a save that has not done the intro.
function Hud.intro()
	local due = S.profile ~= nil and not S.profile.intro
	if due and not S.intro then
		S.intro = true
		offer.Visible, shownAt = true, os.clock()
		show(nil)
	elseif not due and S.intro and not bye.Visible and not S.lesson then -- skipped, or done elsewhere
		S.intro = false
		offer.Visible, skip.Visible = false, false
	end
	layout()
end

-- The borrowed fight is won: the lessons go, the goodbye comes.
function Hud.introWon()
	S.lesson = false
	steps.Visible, note.Visible = false, false
	S.music("win")
	Style.sound("claim")
	bye.Visible = true
	layout()
end

RunService.Heartbeat:Connect(function()
	if offer.Visible then
		skip.Visible = os.clock() - shownAt > SKIP_AFTER
	end
	if not S.lesson then
		return
	end
	done.tap = done.tap or (S.strikes or 0) >= TAPS
	done.ring = done.ring or (S.fired ~= nil and S.fired.ring == true)
	done.mash = done.mash or (S.fired ~= nil and S.fired.mash == true)
	done.shield = done.shield or player:GetAttribute("ShieldAt") ~= shieldsAt
	local now: any = nil
	for _, lesson in LESSONS do
		local chip = chips[lesson.id]
		chip.BackgroundColor3 = if done[lesson.id] then N.gold else N.glass
		chip.TextColor3 = if done[lesson.id] then Color3.fromRGB(42, 22, 64) else N.text
		now = now or (if done[lesson.id] then nil else lesson)
	end
	note.Visible = now ~= nil
	if now then
		local words = if Style.touch() then now.phone else now.says
		noteText.Text = if now.id == "tap" then `{words} ({math.min(S.strikes or 0, TAPS)} of {TAPS})` else words
	end
end)

return nil
