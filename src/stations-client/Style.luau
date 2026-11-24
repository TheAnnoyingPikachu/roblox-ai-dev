--!strict
-- Animal Stations UI building blocks (decisions 0044, 0091): the colours, cards, chips, bars, buttons,
-- sounds and the menu shell every screen of the HUD is made from, in the Savanna look: sand panels,
-- white cards, a thick ink outline with a drop shadow under everything, chunky rounded buttons that
-- squash when pressed. Client only, display only. Everything is laid out in "design units" inside a
-- root frame that Hud.client scales to the screen, and every button is at least 44 units tall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GardenIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GardenIcons"))
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
-- The night side (decision 0114): a fight's glass, where gold only ever means "press this now".
Style.N = {
	glass = Color3.fromRGB(24, 14, 44),
	key = Color3.fromRGB(46, 31, 74),
	edge = Color3.fromRGB(179, 107, 255),
	lilac = Color3.fromRGB(227, 179, 255),
	text = Color3.fromRGB(244, 236, 255),
	muted = Color3.fromRGB(217, 204, 239),
	gold = Color3.fromRGB(255, 194, 58),
	good = Color3.fromRGB(124, 224, 122),
	bad = Color3.fromRGB(255, 107, 142),
	main = Color3.fromRGB(110, 43, 217),
}
local N = Style.N

-- One set of rarity colours, used for nothing else (decision 0091).
Style.RARITY = {
	common = Color3.fromRGB(201, 198, 189),
	uncommon = Color3.fromRGB(103, 199, 111),
	rare = Color3.fromRGB(79, 151, 240),
	epic = Color3.fromRGB(176, 109, 242),
	legendary = Color3.fromRGB(255, 194, 58),
	mythic = Color3.fromRGB(255, 121, 198),
	divine = Color3.fromRGB(94, 240, 216), -- decision 0110
	celestial = Color3.fromRGB(169, 155, 255),
	secret = Color3.fromRGB(255, 77, 94),
} :: { [string]: Color3 }

-- Each coat's chip colour (decision 0110); the rainbow and prismatic chips are a rainbow gradient instead.
Style.COAT = {
	ember = Color3.fromRGB(255, 154, 77),
	frost = Color3.fromRGB(168, 220, 255),
	storm = Color3.fromRGB(143, 184, 255),
	obsidian = Color3.fromRGB(201, 160, 255),
	verdant = Color3.fromRGB(142, 224, 122),
	galaxy = Color3.fromRGB(179, 164, 255),
	gilded = Color3.fromRGB(255, 194, 58),
	spectral = Color3.fromRGB(159, 245, 228),
} :: { [string]: Color3 }

-- Sounds (ForgeGUI, decision 0091; docs/assets/register.md), played on this client only.
Style.SOUNDS = {
	press = "rbxassetid://77373980508668",
	hover = "rbxassetid://95674872035214",
	denied = "rbxassetid://124276619105004",
	tab = "rbxassetid://74792139934627",
	close = "rbxassetid://97509016133658",
	claim = "rbxassetid://112913492194575",
	buy = "rbxassetid://122912592356212", -- a ka-ching for anything bought
}
local VOLUME = { buy = 0.55, hover = 0.15, press = 0.5, tab = 0.45, denied = 0.5, close = 0.35, claim = 0.6 }
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

-- The chunky drop shadow: the same rounded, outlined shape as `inst`'s face, `depth` units lower and
-- behind it, so only its bottom shows. `inst` must paint its colour on a face frame (see `surface` and
-- `Style.button`), never on itself, since a child always draws over its parent.
local DEPTH = 4
function Style.lip(inst: GuiObject, radius: number, depth: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Lip"
	f.BackgroundColor3 = INK
	f.BorderSizePixel = 0
	f.Position, f.Size = UDim2.fromOffset(0, depth or DEPTH), UDim2.fromScale(1, 1)
	f.ZIndex = -1
	Style.round(f, radius)
	Style.stroke(f, INK, 3)
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
	Style.lip(outer, radius)
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
function Style.amount(parent: Instance, kind: string, text: string, colour: Color3?): (Frame, TextLabel)
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
	local t = Style.text(f, text, 18, colour or C.text, UDim2.fromOffset(0, 26))
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
	-- on glass, in a fight (decision 0114): plain, a plate whose press is ready, the main action, press now, unavailable
	night = { N.glass, N.text },
	nightHot = { N.glass, N.text },
	nightMain = { N.main, WHITE },
	gold = { N.gold, Color3.fromRGB(42, 22, 64) },
	nightOff = { N.glass, N.muted },
}
local NIGHT_EDGE = {
	night = N.edge,
	nightHot = N.gold,
	nightMain = N.lilac,
	gold = Color3.fromRGB(255, 233, 168),
	nightOff = N.key,
}

local function paintButton(b: TextButton, kind: string)
	local colours = KIND[kind] or KIND.primary
	b.BackgroundColor3, b.TextColor3 = colours[1], colours[2] -- the face and label copy these
	b.TextStrokeColor3 = INK
	local edge = NIGHT_EDGE[kind] -- a night button: a thin bright edge on a dark lip, see-through when it is glass
	b.TextStrokeTransparency = if colours[2] == WHITE and edge == nil then 0.25 else 1
	local face, lip = b:FindFirstChild("Face") :: Frame?, b:FindFirstChild("Lip") :: Frame?
	if face and lip then
		local dark = if edge then Color3.fromRGB(12, 7, 24) else INK
		local faceEdge = face:FindFirstChildOfClass("UIStroke") :: UIStroke
		faceEdge.Color, faceEdge.Thickness = edge or INK, if edge then 2 else 3
		face.BackgroundTransparency = if colours[1] == N.glass then 0.08 else 0
		lip.BackgroundColor3 = dark;
		(lip:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = dark
	end
	b:SetAttribute("Kind", kind)
end

-- The press: the button sinks onto its shadow and springs back; a greyed-out one shakes instead.
local PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function juice(b: TextButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local moved: { GuiObject } = {}
	local function release()
		if #moved > 0 then
			for _, c in moved do
				c.Position -= UDim2.fromOffset(0, DEPTH)
			end
			table.clear(moved)
			TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
		end
	end
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and #moved == 0 then
			for _, c in b:GetChildren() do -- everything on the button sinks onto its shadow
				if c:IsA("GuiObject") and c.Name ~= "Lip" then
					c.Position += UDim2.fromOffset(0, DEPTH)
					table.insert(moved, c)
				end
			end
			TweenService:Create(scale, PRESS, { Scale = 0.97 }):Play()
		end
	end)
	b.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			release()
		end
	end)
	b.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and #moved == 0 and b:GetAttribute("Kind") ~= "off" then
			TweenService:Create(scale, PRESS, { Scale = 1.03 }):Play()
			Style.sound("hover")
		end
	end)
	b.MouseLeave:Connect(function()
		if #moved > 0 then
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
	b.BackgroundTransparency = 1 -- the face paints it
	b.TextTransparency = 1 -- the label shows it
	Style.lip(b, 12)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = 0
	Style.round(face, 12)
	Style.stroke(face, INK, 3)
	face.Parent = b
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.ZIndex = 1
	local inset = Instance.new("UIPadding")
	inset.Name = "Inset"
	inset.PaddingLeft, inset.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	inset.Parent = label
	label.Parent = b
	local function copy()
		face.BackgroundColor3 = b.BackgroundColor3
		label.Text, label.Font, label.TextSize = b.Text, b.Font, b.TextSize
		label.TextColor3, label.TextStrokeColor3, label.TextStrokeTransparency =
			b.TextColor3, b.TextStrokeColor3, b.TextStrokeTransparency
		label.TextXAlignment, label.TextYAlignment = b.TextXAlignment, b.TextYAlignment
		label.TextWrapped, label.TextTruncate = b.TextWrapped, b.TextTruncate
	end
	b.Changed:Connect(copy) -- callers set Text, TextSize, colours... on the button itself
	paintButton(b, kind or "primary")
	copy()
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

-- A button's (or card's) corner radius.
function Style.radius(b: GuiObject, r: number)
	for _, name in { "Face", "Lip" } do
		local f = b:FindFirstChild(name)
		local c = f and f:FindFirstChildOfClass("UICorner")
		if c then
			c.CornerRadius = UDim.new(0, r)
		end
	end
end

-- A message at the top of the screen: a sand pill with an icon, berry for a refusal (`kind` "bad"),
-- leaf for done ("good"), sky for anything else.
local toasts = 0
-- `image` (an uploaded picture, e.g. a reward icon) takes the place of the round sign.
function Style.toast(screen: ScreenGui, text: string, seconds: number?, kind: string?, image: string?)
	toasts += 1
	local mine = toasts
	local colour = if kind == "bad" then C.bad elseif kind == "good" then C.good else C.info
	local f = Instance.new("TextLabel")
	f.Name = "Toast"
	f.AnchorPoint, f.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 80) -- under the goal strip
	f.Size = UDim2.fromOffset(0, 46)
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.TextWrapped = true -- a long message wraps onto more lines instead of running across the screen
	local most = Instance.new("UISizeConstraint")
	most.MinSize, most.MaxSize = Vector2.new(0, 46), Vector2.new(560, math.huge)
	most.Parent = f
	f.BackgroundColor3 = C.sand
	f.Font = Ui.theme.font
	f.Text = text
	f.TextSize = 19
	f.TextColor3 = INK
	f.ZIndex = 40
	Style.round(f, 23)
	Style.stroke(f, INK, 3)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom =
		UDim.new(0, 52), UDim.new(0, 18), UDim.new(0, 8), UDim.new(0, 8)
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
	if image then
		icon.BackgroundTransparency, icon.Text = 1, ""
		icon.Size = UDim2.fromOffset(44, 44)
		for _, d in icon:GetChildren() do
			if d:IsA("UIStroke") then
				d.Enabled = false
			end
		end
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency, picture.Image = 1, image
		picture.Size, picture.ZIndex = UDim2.fromScale(1, 1), 42
		picture.Parent = icon
	end
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
	head: Frame,
	side: Frame,
	tabs: Frame,
	body: ScrollingFrame,
	title: TextLabel,
	chips: Frame,
	count: Frame,
}

local SIDE_W = 180 -- the tab column, for a menu that has tabs
local FOLD_W = 680 -- a menu narrower than this (a phone) puts its tabs in a row under the header
local HEAD_H = 64
Style.HEAD = Color3.fromRGB(251, 233, 196) -- a menu's header band: the paper, a shade warmer

-- A menu (decisions 0091, 0114; the concept boards' windows): a dimmed backdrop (tap it to close) and a
-- paper window up to `width` x 680 units. Along its top a header band: the menu's name, its `chips` (the
-- purses, the limits that matter there), its `count` on the right (what can be done now) and the berry
-- close button. Under it the `body` scrolls; a menu that puts tabs in `tabs` gets a column for them on its
-- left (a row on a phone). Hidden until the backdrop is made Visible; Style.pop plays its opening.
function Style.sheet(parent: Instance, name: string, heading: string, onClose: () -> (), width: number?): Sheet
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
	limit.MaxSize = Vector2.new(width or 1180, 680)
	limit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = frame
	local sink = Instance.new("TextButton") -- a tap inside the panel must not reach the backdrop
	sink.Size, sink.BackgroundTransparency, sink.Text = UDim2.fromScale(1, 1), 1, ""
	sink.AutoButtonColor = false
	sink.Parent = frame

	-- the header band: rounded at the top only (a square strip under its corners), an ink rule under it
	local head = Style.frame(frame, UDim2.new(1, 0, 0, HEAD_H), Style.HEAD)
	head.Name = "Head"
	Style.round(head, 18)
	local square = Style.frame(head, UDim2.new(1, 0, 0, 20), Style.HEAD)
	square.Position = UDim2.new(0, 0, 1, -20)
	local rule = Style.frame(head, UDim2.new(1, 0, 0, 3), INK)
	rule.Position = UDim2.fromScale(0, 1)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position, row.Size = UDim2.fromOffset(20, 0), UDim2.new(1, -96, 1, 0)
	row.ZIndex = 2
	local rowList = Style.list(row, 12, true)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Parent = head
	local title = Style.text(row, heading, 28, C.text, UDim2.fromOffset(0, 40))
	title.AutomaticSize, title.TextWrapped = Enum.AutomaticSize.X, false
	title.LayoutOrder = 1
	local chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.BackgroundTransparency = 1
	chips.AutomaticSize = Enum.AutomaticSize.X
	chips.Size = UDim2.fromOffset(0, 44)
	chips.LayoutOrder = 2
	Style.list(chips, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
	chips.Parent = row
	local count = Instance.new("Frame")
	count.Name = "Count"
	count.BackgroundTransparency = 1
	count.AnchorPoint, count.Position, count.Size =
		Vector2.new(1, 0.5), UDim2.new(1, -76, 0.5, 0), UDim2.fromOffset(0, 44)
	count.AutomaticSize = Enum.AutomaticSize.X
	count.ZIndex = 2
	local countList = Style.list(count, 8, true)
	countList.VerticalAlignment, countList.HorizontalAlignment =
		Enum.VerticalAlignment.Center, Enum.HorizontalAlignment.Right
	count.Parent = head

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Parent = frame
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.ScrollBarThickness = 0
	tabs.CanvasSize = UDim2.new()
	tabs.ElasticBehavior = Enum.ElasticBehavior.Never
	tabs.Size = UDim2.fromScale(1, 1)
	local tabList = Style.list(tabs, 10)
	local tabPad = Instance.new("UIPadding") -- room for the buttons' outlines and shadows
	tabPad.PaddingTop, tabPad.PaddingLeft, tabPad.PaddingRight, tabPad.PaddingBottom =
		UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 8), UDim.new(0, 8)
	tabPad.Parent = tabs
	tabs.Parent = side

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

	local close = Style.button(head, "×", onClose, "danger", UDim2.fromOffset(48, 48))
	close.AnchorPoint, close.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, -2)
	close.TextSize = 32
	close.ZIndex = 3
	Style.radius(close, 24)
	close:SetAttribute("Sound", "close")

	-- the tab column on the left (only when the menu has tabs), or (narrow) the tabs in a row on top
	local function layout()
		local rootScale = parent:FindFirstChildOfClass("UIScale")
		local units = frame.AbsoluteSize.X / math.max(scale.Scale * (if rootScale then rootScale.Scale else 1), 0.01)
		local any = tabs:FindFirstChildWhichIsA("GuiObject") ~= nil
		local top = HEAD_H + 14
		side.Visible = any
		if not any then
			body.Position, body.Size = UDim2.fromOffset(14, top), UDim2.new(1, -24, 1, -top - 10)
		elseif units < FOLD_W then
			side.Position, side.Size = UDim2.fromOffset(14, top - 4), UDim2.new(1, -28, 0, 60)
			tabList.FillDirection = Enum.FillDirection.Horizontal
			tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
			tabs.ScrollingDirection = Enum.ScrollingDirection.X
			body.Position, body.Size = UDim2.fromOffset(14, top + 60), UDim2.new(1, -24, 1, -top - 70)
		else
			side.Position, side.Size = UDim2.fromOffset(16, top - 4), UDim2.new(0, SIDE_W, 1, -top - 8)
			tabList.FillDirection = Enum.FillDirection.Vertical
			tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
			tabs.ScrollingDirection = Enum.ScrollingDirection.Y
			body.Position, body.Size = UDim2.fromOffset(SIDE_W + 28, top), UDim2.new(1, -(SIDE_W + 38), 1, -top - 10)
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	tabs.ChildAdded:Connect(function()
		task.defer(layout)
	end)
	tabs.ChildRemoved:Connect(function()
		task.defer(layout)
	end)
	layout()
	return {
		backdrop = backdrop,
		frame = frame,
		head = head,
		side = side,
		tabs = tabs,
		body = body,
		title = title,
		chips = chips,
		count = count,
	}
end

-- A tab in a menu's column: leaf green when `selected`, white otherwise; `badge` puts a berry dot on it.
function Style.tab(sh: Sheet, label: string, selected: boolean, onClick: () -> (), badge: string?): TextButton
	local b =
		Style.button(sh.tabs, label, onClick, if selected then "good" else "ghost", UDim2.fromOffset(SIDE_W - 14, 46))
	b.TextSize = 18
	b.TextXAlignment = Enum.TextXAlignment.Left
	local p = (b:FindFirstChild("Label") :: TextLabel):FindFirstChild("Inset") :: UIPadding
	p.PaddingLeft = UDim.new(0, 14)
	b:SetAttribute("Sound", "tab")
	b.LayoutOrder = #sh.tabs:GetChildren()
	if badge then
		Style.dot(b, badge)
	end
	return b
end

-- A page in the body's place that does not scroll, for a menu laid out in columns that each scroll on
-- their own (the Eggs, Animals and Waves windows). It follows the body when the tabs move it.
function Style.page(sh: Sheet): Frame
	local page = Instance.new("Frame")
	page.Name, page.BackgroundTransparency = "Page", 1
	local function follow()
		page.Position, page.Size = sh.body.Position, sh.body.Size
	end
	sh.body:GetPropertyChangedSignal("Size"):Connect(follow)
	sh.body:GetPropertyChangedSignal("Position"):Connect(follow)
	follow()
	sh.body.Visible = false
	page.Parent = sh.frame
	return page
end

-- A column of a page: across from `x`, `w` wide (each a UDim), the page's full height. It scrolls on its
-- own and lays its children out in a list (`wrap`: in rows that wrap, for a grid of cards).
function Style.column(page: Frame, x: UDim, w: UDim, order: number, gap: number?, wrap: boolean?): ScrollingFrame
	local col = Instance.new("ScrollingFrame")
	col.BackgroundTransparency, col.BorderSizePixel = 1, 0
	col.Position, col.Size = UDim2.new(x, UDim.new(0, 0)), UDim2.new(w, UDim.new(1, 0))
	col.ScrollBarThickness, col.ScrollBarImageColor3 = 5, C.muted
	col.AutomaticCanvasSize, col.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
	col.ElasticBehavior, col.LayoutOrder = Enum.ElasticBehavior.Never, order
	Style.list(col, gap or 10, wrap, wrap)
	local pad = Instance.new("UIPadding") -- room for the cards' outlines and shadows
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingBottom, pad.PaddingRight =
		UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 10), UDim.new(0, 8)
	pad.Parent = col
	col.Parent = page
	return col
end

-- The menu's opening: it pops from a little smaller with a soft paper flick. (The ForgeGUI "open" sound
-- came out like a cash register, which belongs to buying only: SHANNON, 2026-11-19.)
function Style.pop(sh: Sheet)
	local scale = sh.frame:FindFirstChild("Pop") :: UIScale
	scale.Scale = 0.9
	TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
	Style.sound("tab")
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

-- Sun and Moon (decision 0114) ---------------------------------------------------------------------------
-- The ranch and the hub keep the paper and ink above. A fight is the same shapes in dark glass with a
-- thin violet edge, and gold is its one loud colour: it always means "press this now".

-- A glass panel: dark, a little see-through, a thin violet edge.
function Style.glass(parent: Instance, size: UDim2, radius: number?): Frame
	local f = Style.frame(parent, size, N.glass)
	f.BackgroundTransparency = 0.1
	Style.round(f, radius or 14)
	Style.stroke(f, N.edge, 2)
	return f
end

-- A bar on glass: a see-through track with no outline. Returns it, its setter (0 to 1) and its fill.
function Style.track(parent: Instance, size: UDim2, colour: Color3): (Frame, (f: number) -> (), Frame)
	local back = Style.frame(parent, size, WHITE)
	back.BackgroundTransparency = 0.84
	Style.round(back, 8)
	local fill = Style.frame(back, UDim2.fromScale(0, 1), colour)
	Style.round(fill, 8)
	return back, function(f: number)
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
	end, fill
end

-- A paper pill over the world (the level, the coins, a goal, a note): a sand surface whose shadow is soft,
-- so it sits on the scenery instead of standing off it like a button.
function Style.pill(parent: Instance, size: UDim2, radius: number?): Frame
	local f = surface(parent, size, C.sand, radius or 20)
	local lip = f:FindFirstChild("Lip") :: Frame
	local edge = lip:FindFirstChildOfClass("UIStroke") :: UIStroke
	lip.BackgroundTransparency, edge.Transparency = 0.6, 0.6
	return f
end

-- Small print (Nunito, never under 12): what a number means, a hint under a title.
local SMALL = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
function Style.small(parent: Instance, text: string, size: number?, colour: Color3?, fixed: UDim2?): TextLabel
	local l = Style.text(parent, text, size or 13, colour or C.muted, fixed)
	l.FontFace = SMALL
	return l
end

-- A picture from the studio's own outlined set (Shared.GardenIcons; docs/assets/register.md, GARDEN-055):
-- paw, egg, home, gift, flag, lock, swap, check, heart, cog, chart, calendar, book.
function Style.image(name: string): string
	return `rbxthumb://type=Asset&id={GardenIcons[name] or 0}&w=150&h=150`
end

function Style.icon(parent: Instance, name: string, size: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = "Icon"
	i.BackgroundTransparency = 1
	i.Size = UDim2.fromOffset(size, size)
	i.Image = Style.image(name)
	i.ScaleType = Enum.ScaleType.Fit
	i.Parent = parent
	return i
end

-- Keys for a keyboard, tap bubbles for a touch screen (Roblox says which the player is using, and it can
-- change mid-session). A player's "UiInput" attribute ("touch" or "keys") stands in for it on a desktop.
function Style.touch(): boolean
	local forced = Players.LocalPlayer:GetAttribute("UiInput")
	if forced == "touch" or forced == "keys" then
		return forced == "touch"
	end
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

local inputWatchers: { () -> () } = {}
local keyCaps: { [GuiObject]: boolean } = {} -- until each is destroyed
local function inputChanged()
	local touch = Style.touch()
	for cap in keyCaps do
		cap.Visible = not touch
	end
	for _, fn in inputWatchers do
		fn()
	end
end
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(inputChanged)
Players.LocalPlayer:GetAttributeChangedSignal("UiInput"):Connect(inputChanged)

-- A phone's layout: a touch screen, or a screen too short for the desk layout (`height` in design units).
function Style.compact(height: number): boolean
	return Style.touch() or height < 560
end

-- Call `fn` whenever the player changes between keys and touch.
function Style.onInput(fn: () -> ())
	table.insert(inputWatchers, fn)
end

-- A key cap: the key that does what its button does. Never shown on a touch screen. `night` is the glass
-- version; paint it N.gold when its press is ready.
function Style.key(parent: Instance, text: string, night: boolean?): TextLabel
	local k = Instance.new("TextLabel")
	k.Name = "Key"
	k.Size = UDim2.fromOffset(24, 24)
	k.AutomaticSize = Enum.AutomaticSize.X
	k.BackgroundColor3 = if night then N.key else WHITE
	k.BorderSizePixel = 0
	k.Font = Ui.theme.font
	k.Text = text
	k.TextSize = 14
	k.TextColor3 = if night then N.text else INK
	k.ZIndex = 5
	Style.round(k, 7)
	Style.stroke(k, if night then N.lilac else INK, 2)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
	p.Parent = k
	k.Visible = not Style.touch()
	keyCaps[k] = true
	k.Destroying:Connect(function()
		keyCaps[k] = nil
	end)
	k.Parent = parent
	return k
end

-- A disc that fills clockwise from the top: returns it and a function that sets how full it is (0 to 1).
-- Put a smaller circle on top of it to make a ring (an XP ring round a level, a cooldown round a button).
function Style.pie(parent: Instance, size: number, colour: Color3, back: Color3): (Frame, (f: number) -> ())
	local holder = Style.frame(parent, UDim2.fromOffset(size, size), back)
	Style.round(holder, size)
	local sweeps: { UIGradient } = {}
	for side = 0, 1 do -- the right half fills first, then the left
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency, clip.ClipsDescendants = 1, true
		clip.Position, clip.Size = UDim2.fromScale(0.5 - side * 0.5, 0), UDim2.fromScale(0.5, 1)
		local disc = Style.frame(clip, UDim2.fromScale(2, 1), colour)
		disc.Position = UDim2.fromScale(side - 1, 0)
		Style.round(disc, size)
		local sweep = Instance.new("UIGradient") -- shows the half of the disc that lies behind its angle
		sweep.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sweep.Parent = disc
		sweeps[side + 1] = sweep
		clip.Parent = holder
	end
	local function set(f: number)
		f = math.clamp(f, 0, 1)
		sweeps[1].Rotation = math.min(f, 0.5) * 360
		sweeps[2].Rotation = 180 + math.max(f - 0.5, 0) * 360
	end
	set(0)
	return holder, set
end

return Style
