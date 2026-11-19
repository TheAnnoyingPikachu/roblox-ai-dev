--!strict
-- Animal Stations UI building blocks (decisions 0044, 0091): the colours, cards, chips, bars, buttons,
-- sounds and the menu shell every screen of the HUD is made from, in the Savanna look: sand panels,
-- white cards, a thick ink outline with a drop shadow under everything, chunky rounded buttons that
-- squash when pressed. Client only, display only. Everything is laid out in "design units" inside a
-- root frame that Hud.client scales to the screen, and every button is at least 44 units tall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))

local Style = {}

local INK = Color3.fromRGB(58, 36, 18)
local WHITE = Color3.new(1, 1, 1)
Style.C = {
	ink = INK,
	sand = Color3.fromRGB(255, 243, 217),
	panel = Color3.fromRGB(255, 243, 217), -- sand: every menu's panel
	card = WHITE,
	cardHi = Color3.fromRGB(245, 223, 176), -- sand, darker: a quiet chip
	edge = INK,
	text = INK,
	muted = Color3.fromRGB(122, 90, 53),
	accent = Color3.fromRGB(255, 181, 46), -- sun: the main action, coins
	accentText = INK,
	good = Color3.fromRGB(92, 191, 74), -- leaf: confirm, progress, selected
	bad = Color3.fromRGB(226, 80, 122), -- berry: fights, alerts, close
	info = Color3.fromRGB(74, 166, 232), -- sky: travel, information
	gold = Color3.fromRGB(255, 194, 58),
	hex = Color3.fromRGB(150, 255, 70),
	night = Color3.fromRGB(43, 35, 64),
	off = Color3.fromRGB(230, 220, 203),
}
local C = Style.C

-- One set of rarity colours, used for nothing else (decision 0091).
Style.RARITY = {
	common = Color3.fromRGB(201, 198, 189),
	uncommon = Color3.fromRGB(103, 199, 111),
	rare = Color3.fromRGB(79, 151, 240),
	epic = Color3.fromRGB(176, 109, 242),
	legendary = Color3.fromRGB(255, 194, 58),
	mythic = Color3.fromRGB(255, 121, 198),
} :: { [string]: Color3 }

-- Sounds (ForgeGUI, decision 0091; docs/assets/register.md), played on this client only.
Style.SOUNDS = {
	press = "rbxassetid://77373980508668",
	hover = "rbxassetid://95674872035214",
	denied = "rbxassetid://124276619105004",
	tab = "rbxassetid://74792139934627",
	open = "rbxassetid://81025320537756",
	close = "rbxassetid://97509016133658",
	claim = "rbxassetid://112913492194575",
}
local VOLUME = { hover = 0.15, press = 0.5, tab = 0.45, denied = 0.5, open = 0.4, close = 0.35, claim = 0.6 }
local sounds: { [string]: Sound } = {}
function Style.sound(name: string)
	local s = sounds[name]
	if s == nil then
		local id = (Style.SOUNDS :: any)[name]
		if id == nil then
			return
		end
		s = Instance.new("Sound")
		s.Name = `Ui_{name}`
		s.SoundId = id
		s.Volume = VOLUME[name] or 0.5
		s.Parent = SoundService
		sounds[name] = s
	end
	SoundService:PlayLocalSound(s :: Sound)
end

function Style.round(inst: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = inst
	return c
end

function Style.stroke(inst: Instance, colour: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour or INK
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- The chunky drop shadow: an ink strip `depth` units deep under `inst`'s outline. A child draws over
-- its parent, so for a button (whose text is its own) the strip sits wholly below it; a card's face is
-- a separate frame, so its strip (`behind`) can run up behind the face and follow its rounded corners.
function Style.lip(inst: GuiObject, radius: number, depth: number?, behind: boolean?): Frame
	local d = depth or 4
	local f = Instance.new("Frame")
	f.Name = "Lip"
	f.BackgroundColor3 = INK
	f.BorderSizePixel = 0
	if behind then
		f.Position, f.Size = UDim2.fromOffset(-3, radius), UDim2.new(1, 6, 1, 3 + d - radius)
		f.ZIndex = -1
		Style.round(f, radius + 3)
	else
		f.Position, f.Size = UDim2.new(0, -1, 1, 1), UDim2.new(1, 2, 0, d + 2)
		Style.round(f, math.ceil((d + 2) / 2))
	end
	f.Parent = inst
	return f
end

function Style.pad(inst: Instance, n: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight =
		UDim.new(0, n), UDim.new(0, n), UDim.new(0, n), UDim.new(0, n)
	p.Parent = inst
end

-- A list layout: vertical by default, `wrap` lays fixed-size children out in rows that wrap.
function Style.list(inst: Instance, gap: number?, horizontal: boolean?, wrap: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	if wrap then
		l.Wraps = true
		l.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	l.Parent = inst
	return l
end

function Style.frame(parent: Instance, size: UDim2, colour: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.BackgroundColor3 = colour or C.card
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- A shadowed, outlined surface: `outer` is transparent and holds the lip and a face that paints the
-- colour, so content parented to `outer` sits above both.
local function surface(parent: Instance, size: UDim2, colour: Color3, radius: number): Frame
	local outer = Instance.new("Frame")
	outer.Size = size
	outer.BackgroundTransparency = 1
	outer.BorderSizePixel = 0
	Style.lip(outer, radius, 4, true)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = colour
	face.BorderSizePixel = 0
	face.ZIndex = 0
	Style.round(face, radius)
	Style.stroke(face, INK, 3)
	face.Parent = outer
	outer.Parent = parent
	return outer
end

-- The colour of a surface made by `card` or `panel` (its face).
function Style.paint(f: Frame, colour: Color3)
	local face = f:FindFirstChild("Face") :: Frame?
	if face then
		face.BackgroundColor3 = colour
	else
		f.BackgroundColor3 = colour
	end
end

-- A white card with an ink outline and a drop shadow; `edge` (a rarity, a state) tints it.
function Style.card(parent: Instance, size: UDim2, edge: Color3?): Frame
	local tint = if edge and edge ~= INK then WHITE:Lerp(edge, 0.2) else WHITE
	return surface(parent, size, tint, 14)
end

-- A sand panel, the same build as a card.
function Style.panel(parent: Instance, size: UDim2): Frame
	return surface(parent, size, C.sand, 18)
end

-- A text label. With `fixed` it keeps the size it was given, otherwise it grows downwards to fit.
function Style.text(parent: Instance, text: string, size: number?, colour: Color3?, fixed: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.theme.font
	l.Text = text
	l.TextSize = size or 18
	l.TextColor3 = colour or C.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	if fixed then
		l.Size = fixed
	else
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.fromScale(1, 0)
	end
	l.Parent = parent
	return l
end

-- White text with an ink outline, for text on a strong colour.
function Style.outline(label: TextLabel | TextButton)
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0.25
end

-- A small pill with text: a rarity, a role, a status. `colour` fills it (white by default).
function Style.chip(parent: Instance, text: string, colour: Color3?, textColour: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 26)
	l.BackgroundColor3 = colour or WHITE
	l.BorderSizePixel = 0
	l.Font = Ui.theme.font
	l.Text = text
	l.TextSize = 15
	l.TextColor3 = textColour or C.text
	if textColour == WHITE or (textColour and textColour.R > 0.9 and textColour.G > 0.9 and textColour.B > 0.9) then
		Style.outline(l)
	end
	Style.round(l, 13)
	Style.stroke(l, INK, 2)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	p.Parent = l
	l.Parent = parent
	return l
end

-- A berry dot with a count, on the top-right corner of `parent`. Returns the label (hide it to hide).
function Style.dot(parent: Instance, text: string?): TextLabel
	local d = Instance.new("TextLabel")
	d.Name = "Dot"
	d.AnchorPoint, d.Position = Vector2.new(0.5, 0.5), UDim2.new(1, -4, 0, 4)
	d.Size = UDim2.fromOffset(24, 24)
	d.AutomaticSize = Enum.AutomaticSize.X
	d.BackgroundColor3 = C.bad
	d.Font = Ui.theme.font
	d.Text = text or ""
	d.TextSize = 14
	d.TextColor3 = WHITE
	d.ZIndex = 5
	Style.outline(d)
	Style.round(d, 12)
	Style.stroke(d, INK, 2)
	d.Parent = parent
	return d
end

-- A round token: a coin, a sample, an XP star.
local TOKEN = { coins = C.accent, samples = C.good, xp = C.info }
function Style.amount(parent: Instance, kind: string, text: string): (Frame, TextLabel)
	local f = Instance.new("Frame")
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 26)
	f.BackgroundTransparency = 1
	Style.list(f, 5, true).VerticalAlignment = Enum.VerticalAlignment.Center
	local dot = Style.frame(f, UDim2.fromOffset(18, 18), TOKEN[kind] or C.muted)
	Style.round(dot, if kind == "samples" then 5 else 9)
	if kind == "samples" then
		dot.Rotation = 45
	end
	Style.stroke(dot, INK, 2)
	dot.LayoutOrder = 1
	local t = Style.text(f, text, 18, C.text, UDim2.fromOffset(0, 26))
	t.AutomaticSize = Enum.AutomaticSize.X
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.LayoutOrder = 2
	f.Parent = parent
	return f, t
end

-- A progress bar: returns the bar and a function that sets how full it is (0 to 1).
function Style.bar(parent: Instance, size: UDim2, colour: Color3?): (Frame, (f: number) -> ())
	local back = Style.frame(parent, size, WHITE)
	Style.round(back, 8)
	Style.stroke(back, INK, 2)
	local fill = Style.frame(back, UDim2.fromScale(0, 1), colour or C.good)
	Style.round(fill, 8)
	return back, function(f: number)
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
	end
end

local KIND = {
	primary = { C.accent, INK },
	good = { C.good, WHITE },
	danger = { C.bad, WHITE },
	info = { C.info, WHITE },
	ghost = { WHITE, INK },
	off = { C.off, Color3.fromRGB(154, 138, 116) }, -- looks unavailable but still answers, so the refusal can explain itself
	stat = { WHITE, INK },
}

local function paintButton(b: TextButton, kind: string)
	local colours = KIND[kind] or KIND.primary
	b.BackgroundColor3, b.TextColor3 = colours[1], colours[2]
	b.TextStrokeColor3 = INK
	b.TextStrokeTransparency = if colours[2] == WHITE then 0.25 else 1
	b:SetAttribute("Kind", kind)
end

-- The press: the button sinks onto its shadow and springs back; a greyed-out one shakes instead.
local PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function juice(b: TextButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local pad = Instance.new("UIPadding")
	pad.Parent = b
	local lip = b:FindFirstChild("Lip") :: Frame
	local down = false
	local function release()
		if down then
			down = false
			TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
			TweenService:Create(pad, SPRING, { PaddingTop = UDim.new(0, 0) }):Play()
			lip.Visible = true
		end
	end
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			down = true
			TweenService:Create(scale, PRESS, { Scale = 0.95 }):Play()
			TweenService:Create(pad, PRESS, { PaddingTop = UDim.new(0, 5) }):Play()
			lip.Visible = false
		end
	end)
	b.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			release()
		end
	end)
	b.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and not down and b:GetAttribute("Kind") ~= "off" then
			TweenService:Create(scale, PRESS, { Scale = 1.03 }):Play()
			Style.sound("hover")
		end
	end)
	b.MouseLeave:Connect(function()
		if down then
			release()
		else
			TweenService:Create(scale, PRESS, { Scale = 1 }):Play()
		end
	end)
end

local function shake(b: TextButton)
	local r = b.Rotation
	for i, a in { -3, 3, -2, 2, 0 } do
		task.delay(i * 0.04, function()
			b.Rotation = r + a
		end)
	end
end

-- A button: `kind` is primary, good, danger, info, ghost, off or stat. It greys out while `onClick`
-- runs, so a double tap cannot send a request twice. Its "Sound" attribute names the sound it makes.
function Style.button(parent: Instance, text: string, onClick: () -> (), kind: string?, size: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.Size = size or UDim2.new(1, 0, 0, 44)
	b.Font = Ui.theme.font
	b.TextSize = 18
	b.Text = text
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	paintButton(b, kind or "primary")
	Style.round(b, 12)
	Style.stroke(b, INK, 3)
	Style.lip(b, 12, 4)
	juice(b)
	local busy = false
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		if b:GetAttribute("Kind") == "off" then
			Style.sound("denied")
			shake(b)
		else
			Style.sound((b:GetAttribute("Sound") :: string?) or "press")
		end
		local was = b.BackgroundColor3
		b.BackgroundColor3 = was:Lerp(INK, 0.15)
		local ok, err = pcall(onClick)
		if not ok then
			warn(`[Style] {text}: {err}`)
		end
		if b.Parent then
			b.BackgroundColor3 = was
		end
		busy = false
	end)
	b.Parent = parent
	return b
end

-- Restyle `b` as another kind (for a button that changes with the state of the game).
function Style.kind(b: TextButton, kind: string)
	paintButton(b, kind)
end

-- A message at the top of the screen: a sand pill with an icon, berry for a refusal (`kind` "bad"),
-- leaf for done ("good"), sky for anything else.
local toasts = 0
function Style.toast(screen: ScreenGui, text: string, seconds: number?, kind: string?)
	toasts += 1
	local mine = toasts
	local colour = if kind == "bad" then C.bad elseif kind == "good" then C.good else C.info
	local f = Instance.new("TextLabel")
	f.Name = "Toast"
	f.AnchorPoint, f.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 14)
	f.Size = UDim2.fromOffset(0, 46)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = C.sand
	f.Font = Ui.theme.font
	f.Text = text
	f.TextSize = 19
	f.TextColor3 = INK
	f.ZIndex = 40
	Style.round(f, 23)
	Style.stroke(f, INK, 3)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 52), UDim.new(0, 18)
	p.Parent = f
	local icon = Instance.new("TextLabel")
	icon.AnchorPoint, icon.Position, icon.Size =
		Vector2.new(0, 0.5), UDim2.new(0, -44, 0.5, 0), UDim2.fromOffset(34, 34)
	icon.BackgroundColor3 = colour
	icon.Font = Ui.theme.font
	icon.Text = if kind == "bad" then "!" elseif kind == "good" then "✓" else "i"
	icon.TextSize = 20
	icon.TextColor3 = WHITE
	icon.ZIndex = 41
	Style.outline(icon)
	Style.round(icon, 17)
	Style.stroke(icon, INK, 2)
	icon.Parent = f
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = f
	for _, old in screen:GetChildren() do -- one at a time: a new message replaces the last
		if old.Name == "Toast" then
			old:Destroy()
		end
	end
	f.Parent = screen
	TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
	if kind == "bad" then
		Style.sound("denied")
	end
	task.delay(seconds or 2.5, function()
		if toasts ~= mine or f.Parent == nil then
			return
		end
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0.6 }):Play()
		task.wait(0.15)
		f:Destroy()
	end)
end

export type Sheet = {
	backdrop: TextButton,
	frame: Frame,
	side: Frame,
	tabs: Frame,
	body: ScrollingFrame,
	title: TextLabel,
	chips: Frame,
}

local SIDE_W = 214 -- the tab column
local FOLD_W = 680 -- a menu narrower than this (a phone held upright) puts its tabs in a row on top

-- A menu (decision 0091): a dimmed backdrop (tap it to close) and a sand panel up to 940 x 660 units.
-- On its left a column with the menu's name, its tabs (Style.tab) and, at the bottom, its chips (the
-- limit that matters there, the wallet); on its right a scrolling body; a berry close button on the
-- corner. Hidden until the backdrop is made Visible; Style.pop plays its opening.
function Style.sheet(parent: Instance, name: string, heading: string, onClose: () -> ()): Sheet
	local backdrop = Instance.new("TextButton")
	backdrop.Name = name
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
	backdrop.BackgroundTransparency = 0.55
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 10
	backdrop.Visible = false
	backdrop.Activated:Connect(onClose)
	backdrop.Parent = parent

	local frame = Style.panel(backdrop, UDim2.new(1, -40, 1, -48))
	frame.AnchorPoint, frame.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 6)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(940, 660)
	limit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = frame
	local sink = Instance.new("TextButton") -- a tap inside the panel must not reach the backdrop
	sink.Size, sink.BackgroundTransparency, sink.Text = UDim2.fromScale(1, 1), 1, ""
	sink.AutoButtonColor = false
	sink.Parent = frame

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Parent = frame
	local title = Style.text(side, heading, 32, C.text, UDim2.new(1, 0, 0, 40))
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextWrapped = false
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.ScrollBarThickness = 0
	tabs.CanvasSize = UDim2.new()
	tabs.ElasticBehavior = Enum.ElasticBehavior.Never
	local tabList = Style.list(tabs, 10)
	local tabPad = Instance.new("UIPadding") -- room for the buttons' outlines and shadows
	tabPad.PaddingTop, tabPad.PaddingLeft, tabPad.PaddingRight, tabPad.PaddingBottom =
		UDim.new(0, 12), UDim.new(0, 4), UDim.new(0, 14), UDim.new(0, 8)
	tabPad.Parent = tabs
	tabs.Parent = side
	local chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.BackgroundTransparency = 1
	chips.AutomaticSize = Enum.AutomaticSize.Y
	local chipList = Style.list(chips, 8)
	chipList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	chips.Parent = side

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = C.muted
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ElasticBehavior = Enum.ElasticBehavior.Never
	local inset = Instance.new("UIPadding") -- room for the cards' outlines and shadows
	inset.PaddingTop, inset.PaddingBottom, inset.PaddingLeft, inset.PaddingRight =
		UDim.new(0, 6), UDim.new(0, 12), UDim.new(0, 5), UDim.new(0, 12)
	inset.Parent = body
	body.Parent = frame

	local close = Style.button(frame, "×", onClose, "danger", UDim2.fromOffset(52, 52))
	close.AnchorPoint, close.Position = Vector2.new(0.5, 0.5), UDim2.new(1, -8, 0, 8)
	close.TextSize = 34
	close.ZIndex = 3
	Style.round(close, 26)
	close:SetAttribute("Sound", "close")

	-- the column on the left, or (narrow) the tabs in a row along the top
	local function layout()
		local rootScale = parent:FindFirstChildOfClass("UIScale")
		local units = frame.AbsoluteSize.X / math.max(scale.Scale * (if rootScale then rootScale.Scale else 1), 0.01)
		if units < FOLD_W then
			side.Position, side.Size = UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 150)
			tabs.Position, tabs.Size = UDim2.fromOffset(-4, 44), UDim2.new(1, 8, 0, 62)
			tabList.FillDirection = Enum.FillDirection.Horizontal
			tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
			tabs.ScrollingDirection = Enum.ScrollingDirection.X
			chips.Position, chips.Size = UDim2.fromOffset(0, 112), UDim2.new(1, 0, 0, 30)
			chipList.FillDirection = Enum.FillDirection.Horizontal
			chipList.VerticalAlignment = Enum.VerticalAlignment.Center
			body.Position, body.Size = UDim2.fromOffset(12, 168), UDim2.new(1, -24, 1, -180)
		else
			side.Position, side.Size = UDim2.fromOffset(20, 18), UDim2.new(0, SIDE_W, 1, -36)
			tabs.Position, tabs.Size = UDim2.fromOffset(-4, 48), UDim2.new(1, 8, 1, -48)
			tabList.FillDirection = Enum.FillDirection.Vertical
			tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
			tabs.ScrollingDirection = Enum.ScrollingDirection.Y
			chips.Position, chips.Size = UDim2.fromScale(0, 1), UDim2.fromScale(1, 0)
			chips.AnchorPoint = Vector2.new(0, 1)
			chipList.FillDirection = Enum.FillDirection.Vertical
			chipList.VerticalAlignment = Enum.VerticalAlignment.Bottom
			body.Position, body.Size = UDim2.fromOffset(SIDE_W + 34, 16), UDim2.new(1, -(SIDE_W + 46), 1, -28)
		end
		if units < FOLD_W then
			chips.AnchorPoint = Vector2.new(0, 0)
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	return {
		backdrop = backdrop,
		frame = frame,
		side = side,
		tabs = tabs,
		body = body,
		title = title,
		chips = chips,
	}
end

-- A tab in a menu's column: leaf green when `selected`, white otherwise; `badge` puts a berry dot on it.
function Style.tab(sh: Sheet, label: string, selected: boolean, onClick: () -> (), badge: string?): TextButton
	local b = Style.button(sh.tabs, label, onClick, if selected then "good" else "ghost", UDim2.fromOffset(196, 48))
	b.TextSize = 19
	b.TextXAlignment = Enum.TextXAlignment.Left
	local p = b:FindFirstChildOfClass("UIPadding") :: UIPadding
	p.PaddingLeft = UDim.new(0, 14)
	b:SetAttribute("Sound", "tab")
	b.LayoutOrder = #sh.tabs:GetChildren()
	if badge then
		Style.dot(b, badge)
	end
	return b
end

-- The menu's opening: it pops from a little smaller with a soft "whump".
function Style.pop(sh: Sheet)
	local scale = sh.frame:FindFirstChild("Pop") :: UIScale
	scale.Scale = 0.9
	TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
	Style.sound("open")
end

-- Empty a container but keep its layout and padding objects.
function Style.clear(container: Instance)
	for _, child in container:GetChildren() do
		if
			not (
				child:IsA("UIListLayout")
				or child:IsA("UIGridLayout")
				or child:IsA("UIPadding")
				or child:IsA("UIScale")
			)
		then
			child:Destroy()
		end
	end
end

return Style
