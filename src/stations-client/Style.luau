--!strict
-- Animal Stations UI building blocks (decision 0044): the colours, cards, chips, bars, buttons and
-- full-screen sheets every screen of the HUD is made from. Client only, display only. Everything is
-- laid out in "design units" inside a root frame that Hud.client scales to the screen, and every
-- button is at least 44 units tall for touch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Ui"))

local Style = {}

Style.C = {
	panel = Color3.fromRGB(33, 30, 52),
	card = Color3.fromRGB(47, 43, 72),
	cardHi = Color3.fromRGB(62, 57, 94),
	edge = Color3.fromRGB(92, 84, 134),
	text = Color3.fromRGB(247, 245, 255),
	muted = Color3.fromRGB(178, 172, 206),
	accent = Color3.fromRGB(255, 200, 70),
	accentText = Color3.fromRGB(46, 30, 6),
	good = Color3.fromRGB(96, 214, 128),
	bad = Color3.fromRGB(255, 92, 108),
	info = Color3.fromRGB(104, 172, 255),
	gold = Color3.fromRGB(255, 214, 90),
	hex = Color3.fromRGB(150, 255, 70),
	off = Color3.fromRGB(86, 82, 112),
}
local C = Style.C

Style.RARITY = {
	common = Color3.fromRGB(205, 205, 210),
	uncommon = Color3.fromRGB(110, 224, 120),
	rare = Color3.fromRGB(96, 164, 255),
	epic = Color3.fromRGB(196, 116, 255),
	legendary = Color3.fromRGB(255, 202, 64),
	mythic = Color3.fromRGB(255, 124, 204),
} :: { [string]: Color3 }

function Style.round(inst: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = inst
	return c
end

function Style.stroke(inst: Instance, colour: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour or C.edge
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
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
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
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

-- A rounded card with a coloured edge.
function Style.card(parent: Instance, size: UDim2, edge: Color3?): Frame
	local f = Style.frame(parent, size, C.card)
	Style.round(f)
	Style.stroke(f, edge or C.edge, 2)
	return f
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

-- A small pill with text: a rarity, a role, a status.
function Style.chip(parent: Instance, text: string, colour: Color3?, textColour: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 24)
	l.BackgroundColor3 = colour or C.cardHi
	l.BorderSizePixel = 0
	l.Font = Ui.theme.font
	l.Text = text
	l.TextSize = 14
	l.TextColor3 = textColour or C.text
	Style.round(l, 12)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	p.Parent = l
	l.Parent = parent
	return l
end

-- A round token: a coin, a sample, an XP star.
local TOKEN = { coins = C.gold, samples = C.good, xp = C.info }
function Style.amount(parent: Instance, kind: string, text: string): (Frame, TextLabel)
	local f = Instance.new("Frame")
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 24)
	f.BackgroundTransparency = 1
	Style.list(f, 5, true).VerticalAlignment = Enum.VerticalAlignment.Center
	local dot = Style.frame(f, UDim2.fromOffset(16, 16), TOKEN[kind] or C.muted)
	Style.round(dot, 8)
	Style.stroke(dot, C.panel, 2)
	dot.LayoutOrder = 1
	local t = Style.text(f, text, 17, C.text, UDim2.fromOffset(0, 24))
	t.AutomaticSize = Enum.AutomaticSize.X
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.LayoutOrder = 2
	f.Parent = parent
	return f, t
end

-- A progress bar: returns the bar and a function that sets how full it is (0 to 1).
function Style.bar(parent: Instance, size: UDim2, colour: Color3?): (Frame, (f: number) -> ())
	local back = Style.frame(parent, size, Color3.fromRGB(24, 22, 38))
	Style.round(back, 6)
	local fill = Style.frame(back, UDim2.fromScale(0, 1), colour or C.good)
	Style.round(fill, 6)
	return back, function(f: number)
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
	end
end

local KIND = {
	primary = { C.accent, C.accentText },
	good = { C.good, Color3.fromRGB(10, 40, 18) },
	danger = { C.bad, Color3.fromRGB(60, 8, 16) },
	ghost = { C.cardHi, C.text },
	off = { C.off, C.muted }, -- looks unavailable but still answers, so the refusal can explain itself
	stat = { Color3.fromRGB(64, 59, 98), C.text },
}

-- A button: `kind` is primary, good, danger, ghost, off or stat. It greys out while `onClick` runs,
-- so a double tap cannot send a request twice.
function Style.button(parent: Instance, text: string, onClick: () -> (), kind: string?, size: UDim2?): TextButton
	local colours = KIND[kind or "primary"] or KIND.primary
	local b = Instance.new("TextButton")
	b.Name = text
	b.Size = size or UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = colours[1]
	b.TextColor3 = colours[2]
	b.Font = Ui.theme.font
	b.TextSize = 18
	b.Text = text
	b.AutoButtonColor = true
	Style.round(b, 10)
	local busy = false
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		b.BackgroundTransparency = 0.4
		local ok, err = pcall(onClick)
		if not ok then
			warn(`[Style] {text}: {err}`)
		end
		b.BackgroundTransparency = 0
		busy = false
	end)
	b.Parent = parent
	return b
end

-- Restyle `b` as another kind (for a button that changes with the state of the game).
function Style.kind(b: TextButton, kind: string)
	local colours = KIND[kind] or KIND.primary
	b.BackgroundColor3, b.TextColor3 = colours[1], colours[2]
end

export type Sheet = {
	backdrop: TextButton,
	frame: Frame,
	body: ScrollingFrame,
	title: TextLabel,
	chips: Frame,
}

-- A full-screen sheet: a dimmed backdrop (tap it to close), a panel up to 780 x 720 units with a
-- title, a close button, a row for chips and a scrolling body. Hidden until `open`.
function Style.sheet(parent: Instance, name: string, heading: string, onClose: () -> ()): Sheet
	local backdrop = Instance.new("TextButton")
	backdrop.Name = name
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 10
	backdrop.Visible = false
	backdrop.Activated:Connect(onClose)
	backdrop.Parent = parent

	local frame = Style.frame(backdrop, UDim2.new(1, -24, 1, -24), C.panel)
	frame.AnchorPoint, frame.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(780, 720)
	limit.Parent = frame
	Style.round(frame, 18)
	Style.stroke(frame, C.edge, 3)
	local sink = Instance.new("TextButton") -- a tap inside the panel must not reach the backdrop
	sink.Size, sink.BackgroundTransparency, sink.Text = UDim2.fromScale(1, 1), 1, ""
	sink.AutoButtonColor = false
	sink.Parent = frame

	local title = Style.text(frame, heading, 28, C.text, UDim2.new(1, -90, 0, 36))
	title.Position = UDim2.fromOffset(18, 12)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local close = Style.button(frame, "X", onClose, "danger", UDim2.fromOffset(48, 48))
	close.AnchorPoint, close.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 10)
	close.TextSize = 24

	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Position, chips.Size = UDim2.fromOffset(18, 52), UDim2.new(1, -36, 0, 26)
	Style.list(chips, 8, true)
	chips.Parent = frame

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position, body.Size = UDim2.fromOffset(10, 88), UDim2.new(1, -20, 1, -98)
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = C.edge
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ElasticBehavior = Enum.ElasticBehavior.Never
	local inset = Instance.new("UIPadding") -- room for the cards' edges
	inset.PaddingTop, inset.PaddingBottom, inset.PaddingLeft, inset.PaddingRight =
		UDim.new(0, 4), UDim.new(0, 8), UDim.new(0, 2), UDim.new(0, 2)
	inset.Parent = body
	body.Parent = frame
	return { backdrop = backdrop, frame = frame, body = body, title = title, chips = chips }
end

-- Empty a container but keep its layout and padding objects.
function Style.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not (child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding")) then
			child:Destroy()
		end
	end
end

return Style
