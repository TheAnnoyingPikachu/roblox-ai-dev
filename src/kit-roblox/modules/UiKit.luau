--!strict
-- Kit (client side): the studio UI kit (decision 0011; Egg Garden GDD X1, architecture garden 6.4,
-- generalised for Lantern Express in LANTERN-005). Every widget's geometry, colours, strokes and
-- animation in one place. Callers pass content and callbacks. Display only: no widget sends a
-- Request; the only images are the configured icon ids and ViewportFrames; every animation is
-- skipped under ReducedMotion; one panel is open at a time. Numbers are pixels at 1920 x 1080 and
-- scaleRoot scales them. A game calls UiKit.configure{...} once, before its first widget:
--
--   UiKit.configure({
--       tokens = { CREAM, PANEL, CARD, INK, INK_SOFT, MUTED, GOLD, RING, CORAL, BADGE, AQUA, MINT,
--                  LEAF, SKY, LILAC, PINK, GREY, WHITE, SHADOW (Color3s), GLASS (a transparency) },
--                  -- optional: CHIP, CHIP_TEXT, CHIP_LINE, RING_FILL, ROW_LINE, BAR_BACK, SILHOUETTE
--       fonts = { body = Enum.Font.FredokaOne, title = Enum.Font.FredokaOne },
--       icons = { [name] = decalId? },             -- nil id: the two-letter glyph
--       sound = function(name, volume, pitch) end, -- "tick" on every button and tab
--       short = function(n) return "1.2K" end,
--       rarity = { colour = function(species) end, name = function(species) end },
--       species = function(id) return "Moss Mouse" end, -- showcase card names
--       previews = "GardenSpecies",                -- ReplicatedStorage folder of preview models
--       accent = { Album = Color3 },               -- start menu side buttons by Capitalised label
--       menu = { words = { "EGG", "GARDEN" }, tagline, haze = { top, bottom }, face, faceLine, shade,
--                play, decorate = function(firstWord: Frame) end },
--   })

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

export type Config = {
	tokens: { [string]: any },
	fonts: { body: Enum.Font, title: Enum.Font },
	icons: { [string]: number? },
	sound: (name: string, volume: number, pitch: number?) -> (),
	short: (n: number) -> string,
	rarity: { colour: (species: string) -> Color3, name: (species: string) -> string },
	species: (id: string) -> string,
	previews: string?,
	accent: { [string]: Color3 }?,
	menu: {
		words: { string },
		tagline: string,
		haze: { Color3 },
		face: Color3,
		faceLine: Color3,
		shade: Color3,
		play: Color3,
		decorate: ((firstWord: Frame) -> ())?,
	},
}

-- Filled by configure: the theme tokens and the game's hooks.
local UI: { [string]: any } = {}
local cfg: Config = nil :: any

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

-- The 3D bottom edge of a button: the colour darkened 25% toward INK (Garden X1.1).
local function edge(colour: Color3): Color3
	return colour:Lerp(UI.INK, 0.25)
end

local UiKit = {}
UiKit.new = new
UiKit.edge = edge

export type Panel = {
	frame: Frame,
	body: ScrollingFrame,
	setTabs: (labels: { string }, onTab: (string) -> ()) -> (),
	setTab: (string) -> (),
	setFooter: (height: number) -> Frame?, -- a fixed strip under the body; 0 removes it
	close: () -> (),
	onClose: ((byUser: boolean) -> ())?,
	tab: string?,
}
export type Button = TextButton -- holds Text (mirrored to Face.Label); children "Edge" and "Face"
export type Card = { frame: TextButton, icon: Frame, name: TextLabel, pill: TextLabel, select: (boolean) -> () }
export type Toast = (text: string, icon: string?, colour: Color3?) -> ()

-- Small helpers ---------------------------------------------------------------------------------------

local function still(): boolean
	return GuiService.ReducedMotionEnabled
end

local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween?
	if still() then
		for k, v in props do
			(inst :: any)[k] = v
		end
		return nil
	end
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function round(): UICorner
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function stroke(colour: Color3, thickness: number): UIStroke
	return new("UIStroke", { Color = colour, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- A face lighter at the top: the fill is the lightened colour and the gradient multiplies it back
-- down to `colour` by `band` (0..1 of the height).
local function shine(f: GuiObject, colour: Color3, amount: number, band: number)
	local top = colour:Lerp(UI.WHITE, amount)
	local m =
		Color3.new(colour.R / math.max(top.R, 1e-3), colour.G / math.max(top.G, 1e-3), colour.B / math.max(top.B, 1e-3))
	f.BackgroundColor3 = top
	local g = f:FindFirstChild("Shine") :: UIGradient?
	if not g then
		g = new("UIGradient", { Name = "Shine", Rotation = 90, Parent = f })
	end
	local keys = { ColorSequenceKeypoint.new(0, UI.WHITE) }
	if band < 1 then
		table.insert(keys, ColorSequenceKeypoint.new(band, m))
	end
	table.insert(keys, ColorSequenceKeypoint.new(1, m));
	(g :: UIGradient).Color = ColorSequence.new(keys)
end

-- A Frame with a SHADOW copy offset below it: returns (container, body). The container is what a
-- layout places; the body is what shows.
local function shadowed(parent: Instance?, props: { [string]: any }, radius: number, drop: number): (Frame, Frame)
	props.BackgroundTransparency = 1
	props.Parent = parent
	local holder = new("Frame", props)
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, drop),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.SHADOW,
		BackgroundTransparency = 0.78,
		ZIndex = 0,
		Parent = holder,
	}, { corner(radius) })
	local body = new(
		"Frame",
		{ Name = "Body", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = holder },
		{ corner(radius) }
	)
	return holder, body
end

-- No text under 12 px on screen (QA M2). Under the kit's UIScale a TextScaled label's size limits are
-- on-screen px, so its floor is 12; a fixed TextSize is scaled, so its floor is 12 / the kit scale,
-- re-applied by scaleRoot from the label's KitTextSize attribute when the scale changes.
local MIN_TEXT = 12
local kitScale = 1

local function fixedSize(size: number): number
	return math.max(size, math.ceil(MIN_TEXT / kitScale))
end

-- Text: the body font at `size` px, shrinking to fit its box down to 12 px on screen. props may carry
-- `Outline` (Color3) and `OutlineThickness`.
function UiKit.text(parent: Instance?, s: string, size: number, colour: Color3?, props: { [string]: any }?): TextLabel
	local p = props or {}
	local outline = p.Outline
	local thickness = p.OutlineThickness
	p.Outline, p.OutlineThickness = nil, nil
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or cfg.fonts.body
	p.Text = s
	p.TextColor3 = colour or UI.INK
	p.TextScaled = if p.TextScaled == nil then true else p.TextScaled
	p.Size = p.Size or UDim2.new(1, 0, 0, size + 6)
	p.Parent = parent
	local label = new("TextLabel", p)
	if label.TextScaled then
		new("UITextSizeConstraint", { MaxTextSize = math.max(size, MIN_TEXT), MinTextSize = MIN_TEXT, Parent = label })
	else
		label:SetAttribute("KitTextSize", size)
		label.TextSize = fixedSize(size)
	end
	if outline then
		new("UIStroke", { Color = outline, Thickness = thickness or 1.5, Parent = label })
	end
	return label
end
local text = UiKit.text

-- Scale -------------------------------------------------------------------------------------------------

function UiKit.scaleRoot(gui: ScreenGui): UIScale
	local scale = new("UIScale", { Name = "KitScale", Parent = gui })
	local camera = Workspace.CurrentCamera
	-- The floor 0.6 keeps an 844 x 390 phone's layout inside the screen with 12 px text (QA M2).
	local function fit()
		local view = camera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / 1920, view.Y / 1080), 0.6, 1)
		kitScale = scale.Scale
		for _, d in gui:GetDescendants() do
			local size = d:GetAttribute("KitTextSize")
			if size then
				(d :: TextLabel).TextSize = fixedSize(size)
			end
		end
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	return scale
end

function UiKit.touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Buttons ------------------------------------------------------------------------------------------------

local SIZES = { large = { 64, 28 }, medium = { 52, 24 }, small = { 40, 20 } }

local function popScale(b: GuiObject, from: number)
	if still() then
		return
	end
	local s = b:FindFirstChild("Pop") :: UIScale?
	if not s then
		s = new("UIScale", { Name = "Pop", Parent = b })
	end
	(s :: UIScale).Scale = from
	TweenService:Create(s :: UIScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function paint(b: TextButton)
	local face = b:FindFirstChild("Face") :: Frame
	local label = face:FindFirstChild("Label") :: TextLabel?
	local edgeFrame = b:FindFirstChild("Edge") :: Frame
	local disabled = b:GetAttribute("Disabled") == true
	local colour = if disabled then UI.GREY else ((b:GetAttribute("Colour") :: Color3?) or UI.PINK)
	shine(face, colour, 0.18, 1)
	edgeFrame.BackgroundColor3 = edge(colour)
	edgeFrame.Visible = not disabled
	if label then
		label.TextColor3 = if disabled then UI.INK_SOFT else UI.WHITE
		local outline = label:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Enabled = not disabled
		end
	end
end

-- The 3D button: an edge frame 6 px below a gradient face; press sinks the face, release bounces.
local function makeButton(
	parent: Instance?,
	s: string,
	colour: Color3,
	w: number,
	h: number,
	radius: number,
	textSize: number,
	onClick: () -> ()
): TextButton
	local b = new("TextButton", {
		Name = s,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = s,
		TextTransparency = 1,
		AutoButtonColor = false,
		Parent = parent,
	})
	b:SetAttribute("Colour", colour)
	new("Frame", {
		Name = "Edge",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = b,
	}, { corner(radius) })
	local face = new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = b }, {
		corner(radius),
		stroke(UI.WHITE, 2),
	})
	if s ~= "" then
		local label = text(face, s, textSize, UI.WHITE, {
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -8),
			Outline = UI.INK,
			OutlineThickness = 1.5,
		})
		b:GetPropertyChangedSignal("Text"):Connect(function()
			label.Text = b.Text
		end)
	end
	paint(b)
	local down = false
	local function sink()
		down = true
		tween(face, 0.06, { Position = UDim2.fromOffset(0, 5) })
		if not still() then
			(b:FindFirstChild("Edge") :: Frame).Visible = false
		end
	end
	local function lift()
		down = false
		tween(face, 0.18, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
		paint(b)
		popScale(b, 1.06)
	end
	b.MouseButton1Down:Connect(function()
		if b:GetAttribute("Disabled") ~= true then
			sink()
		end
	end)
	b.MouseLeave:Connect(function()
		if down then
			lift()
		end
	end)
	b.MouseButton1Up:Connect(function()
		if down then
			lift()
		end
	end)
	b.Activated:Connect(function()
		if b:GetAttribute("Disabled") == true then
			return
		end
		if not down then
			lift() -- gamepad A or a tap that skipped the down event: still bounce
		end
		cfg.sound("tick", 0.15, 2.2)
		onClick()
	end)
	return b
end

function UiKit.button(
	parent: Instance?,
	s: string,
	colour: Color3,
	size: string,
	width: number,
	onClick: () -> ()
): Button
	local dims = (SIZES :: any)[size] or SIZES.medium
	return makeButton(parent, s, colour, width, dims[1], 16, dims[2], onClick)
end

function UiKit.setEnabled(b: TextButton, enabled: boolean)
	b:SetAttribute("Disabled", not enabled)
	paint(b)
end

function UiKit.setColour(b: TextButton, colour: Color3)
	b:SetAttribute("Colour", colour)
	paint(b)
end

-- An icon from the configured icons (a Decal id, shown through its asset thumbnail), with the
-- two-letter glyph under it until the image has loaded or when the id is nil.
function UiKit.icon(parent: Instance, icon: string, size: number, props: { [string]: any }?): Frame
	local p = props or {}
	p.Name = "Icon"
	p.Size = UDim2.fromOffset(size, size)
	p.BackgroundTransparency = 1
	p.Parent = parent
	local holder = new("Frame", p)
	local glyph = text(holder, string.upper(string.sub(icon, 1, 2)), math.floor(size * 0.55), UI.WHITE, {
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		Outline = UI.INK,
		OutlineThickness = 2,
	})
	local id = cfg.icons[icon]
	if id then
		local image = new("ImageLabel", {
			Name = "Image",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = `rbxthumb://type=Asset&id={id}&w=150&h=150`,
			ScaleType = Enum.ScaleType.Fit,
			Parent = holder,
		})
		glyph.Visible = not image.IsLoaded
		image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			glyph.Visible = not image.IsLoaded
		end)
	end
	return holder
end

-- An icon at the left of a kit button's face; the label moves right to make room.
function UiKit.buttonIcon(b: TextButton, icon: string, size: number?): Frame
	local face = b:FindFirstChild("Face") :: Frame
	local s = size or 36
	local label = face:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Position = UDim2.new(0.5, (s + 8) / 2, 0.5, 0)
		label.Size = UDim2.new(1, -24 - s, 1, -8)
	end
	return UiKit.icon(face, icon, s, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0) })
end

function UiKit.iconButton(parent: Instance?, icon: string, label: string, colour: Color3, onClick: () -> ()): Button
	local b = makeButton(parent, "", colour, 96, 96, 22, 18, onClick)
	b.Name = label
	b.Text = label
	local face = b:FindFirstChild("Face") :: Frame
	UiKit.icon(face, icon, 56, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8) })
	text(face, label, 18, UI.WHITE, {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 12, 0, 22), -- a little past the face: CREATURES needs 63 px at 12 px (QA M2)
		Outline = UI.INK,
		OutlineThickness = 1.5,
	})
	return b
end

-- nil: none; 0: the gold dot; n: a coral count badge.
function UiKit.setBadge(b: GuiObject, count: number?)
	local old = b:FindFirstChild("Badge")
	if old then
		old:Destroy()
	end
	b:SetAttribute("Badge", count)
	if count == nil then
		return
	end
	local n = count :: number
	local size = if n > 0 then 28 else 18
	local badge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(size, size),
		AutomaticSize = if n > 9 then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		BackgroundColor3 = if n > 0 then UI.BADGE else UI.GOLD,
		ZIndex = 5,
		Parent = b,
	}, { round(), stroke(UI.WHITE, 2) })
	if n > 0 then
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = badge })
		text(badge, if n > 99 then "99+" else tostring(n), 16, UI.WHITE, {
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = if n > 9 then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
			TextScaled = false,
			ZIndex = 6,
		})
	end
	if not still() then
		popScale(badge, 1.3)
	end
end

-- The left strip ----------------------------------------------------------------------------------------

export type StripItem = { icon: string, label: string, colour: Color3, onClick: () -> (), main: boolean? }

-- Columns of 96 px icon buttons at (24, 140). Touch: the `main` items plus MORE in 2 rows, the rest
-- in a sheet MORE opens, so the strip stays above the thumbstick.
function UiKit.strip(gui: Instance, items: { StripItem }, touch: boolean): { [string]: Button }
	local gap = if touch then 12 else 16
	-- Touch: 120, so at the 0.6 floor the two rows still end 220 above the viewport's bottom (X1.2).
	local top = if touch then 120 else 140
	local frame = new("Frame", {
		Name = "Strip",
		Position = UDim2.fromOffset(24, top),
		BackgroundTransparency = 1,
		SelectionGroup = true,
		Parent = gui,
	})
	local grid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(96, 96),
		CellPadding = UDim2.fromOffset(gap, gap),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	local sheet: Frame? = nil
	-- Touch: 2 rows (EGGS CREATURES REWARDS HOME MORE end 120 + 204 from the top, above the
	-- thumbstick on an 844 x 390 phone). Otherwise 5 rows, fewer when the screen is short, so the
	-- strip ends 220 px above the bottom where it can.
	local function fit()
		local root = frame:FindFirstAncestorWhichIsA("LayerCollector")
		local kit = root and root:FindFirstChild("KitScale") :: UIScale?
		local high = (gui :: any).AbsoluteSize and (gui :: any).AbsoluteSize.Y or 1080
		local virtual = high / (if kit then kit.Scale else 1)
		local rows = if touch then 2 else math.clamp(math.floor((virtual - top - 220 + gap) / (96 + gap)), 3, 5)
		grid.FillDirectionMaxCells = rows
		local count = 0
		for _, c in frame:GetChildren() do
			if c:IsA("GuiButton") then
				count += 1
			end
		end
		local cols = math.max(2, math.ceil(count / rows))
		frame.Size = UDim2.fromOffset(96 * cols + gap * (cols - 1), 96 * rows + gap * (rows - 1))
		if sheet then
			sheet.Position = UDim2.fromOffset(24 + frame.Size.X.Offset + 16, top)
		end
	end
	local out: { [string]: Button } = {}
	local more: TextButton? = nil
	if touch then
		local holder, body = shadowed(gui, {
			Name = "MoreSheet",
			Position = UDim2.fromOffset(24 + 96 * 3 + gap * 2 + 16, top),
			Size = UDim2.fromOffset(96 * 3 + 16 * 4, 96 * 2 + 16 * 3),
			Visible = false,
			ZIndex = 8,
		}, 24, 8)
		body.BackgroundColor3 = UI.PANEL
		stroke(UI.WHITE, 4).Parent = body
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 16),
			Parent = body,
		})
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(96, 96),
			CellPadding = UDim2.fromOffset(16, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = body,
		})
		holder.SelectionGroup = true
		sheet = holder
	end
	local function refreshMore()
		if not (sheet and more) then
			return
		end
		local any = false
		for _, b in (sheet :: Frame):GetDescendants() do
			if b:IsA("TextButton") and b:GetAttribute("Badge") ~= nil then
				any = true
			end
		end
		UiKit.setBadge(more :: TextButton, if any then 0 else nil)
	end
	for i, item in items do
		local inSheet = touch and not item.main
		local b = UiKit.iconButton(
			if inSheet then (sheet :: Frame):FindFirstChild("Body") else frame,
			item.icon,
			item.label,
			item.colour,
			function()
				if sheet then
					sheet.Visible = false
				end
				item.onClick()
			end
		)
		b.LayoutOrder = i
		out[item.label] = b
		if inSheet then
			b:GetAttributeChangedSignal("Badge"):Connect(refreshMore)
		end
	end
	if touch then
		local m = UiKit.iconButton(frame, "cog", "MORE", UI.LILAC, function()
			local s = sheet :: Frame
			s.Visible = not s.Visible
		end)
		m.LayoutOrder = #items + 1
		more = m
		out.MORE = m
		refreshMore()
	end
	fit()
	if gui:IsA("GuiObject") then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	return out
end

-- Top bar -------------------------------------------------------------------------------------------------

local function short(n: number): string
	return cfg.short(n)
end

-- Small bounce on a counter (the coin pill); none under Reduced Motion.
local function pop(target: GuiObject)
	if still() then
		return
	end
	local scale = target:FindFirstChild("Pop") :: UIScale?
	if not scale then
		scale = new("UIScale", { Name = "Pop", Parent = target })
	end
	local s = scale :: UIScale
	s.Scale = 1.18
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function UiKit.coinPill(parent: Instance): { set: (coins: number, income: number?) -> (), gain: (delta: number) -> () }
	local holder, body = shadowed(parent, {
		Name = "CoinPill",
		Position = UDim2.fromOffset(24, 20),
		Size = UDim2.fromOffset(260, 60),
	}, 30, 6)
	body.BackgroundColor3 = UI.CREAM
	stroke(UI.WHITE, 3).Parent = body
	local coin = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = UI.GOLD,
		ZIndex = 2,
		Parent = body,
	}, { round(), stroke(UI.WHITE, 2) })
	UiKit.icon(coin, "coin", 40, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local amount = text(body, "0", 30, UI.INK, {
		Position = UDim2.fromOffset(62, 2),
		Size = UDim2.new(1, -72, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})
	local income = text(body, "+0 / s", 16, UI.LEAF, {
		Position = UDim2.fromOffset(62, 34),
		Size = UDim2.new(1, -72, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})
	local float: TextLabel? = nil
	local floatAt, floatSum = 0, 0
	return {
		set = function(coins: number, perSecond: number?) -- nil: no income line (a game without income)
			amount.Text = short(coins)
			income.Text = if perSecond then `+{short(perSecond)} / s` else ""
		end,
		gain = function(delta: number)
			pop(amount)
			if still() or delta <= 0 then
				return
			end
			local now = os.clock()
			if float and float.Parent and now - floatAt < 0.5 then
				floatSum += delta
				local f = float :: TextLabel
				f.Text = `+{short(floatSum)}`
				return
			end
			floatAt, floatSum = now, delta
			local f = text(holder, `+{short(delta)}`, 24, UI.LEAF, {
				Position = UDim2.fromOffset(70, 30),
				Size = UDim2.fromOffset(180, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
				Outline = UI.INK,
				OutlineThickness = 1,
				ZIndex = 4,
			})
			float = f
			TweenService:Create(f, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
				Position = UDim2.fromOffset(70, 30 + 44),
				TextTransparency = 1,
			}):Play()
			local outline = f:FindFirstChildOfClass("UIStroke")
			if outline then
				TweenService:Create(outline, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
			task.delay(0.85, f.Destroy, f)
		end,
	}
end

-- A ring of two clipped halves: each half holds a full stroked circle whose gradient shows half of
-- it; rotating the gradients sweeps the fill clockwise from the top (no images).
function UiKit.levelRing(parent: Instance): { set: (level: number, fraction: number, xpText: string) -> () }
	local holder, body = shadowed(parent, {
		Name = "LevelRing",
		Position = UDim2.fromOffset(300, 8),
		Size = UDim2.fromOffset(84, 84),
	}, 42, 6)
	body.BackgroundColor3 = UI.CREAM;
	(body:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)
	stroke(UI.WHITE, 3).Parent = body
	local function ring(into: Instance, x: number, colour: Color3, half: boolean): UIGradient?
		local r = new("Frame", {
			Position = UDim2.fromOffset(x, 14),
			Size = UDim2.fromOffset(56, 56),
			BackgroundTransparency = 1,
			Parent = into,
		}, { round() })
		local s = stroke(colour, 10)
		s.Parent = r
		if not half then
			return nil
		end
		return new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.501, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = s,
		})
	end
	ring(body, 14, UI.RING, false)
	local function clip(x: number): Frame
		return new("Frame", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(42, 84),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = body,
		})
	end
	local fillColour = UI.RING_FILL or UI.PINK
	local left = ring(clip(0), 14, fillColour, true) :: UIGradient
	local right = ring(clip(42), 14 - 42, fillColour, true) :: UIGradient
	local levelText = text(body, "1", 30, UI.INK, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(52, 34),
		ZIndex = 3,
	})
	local bar = new("Frame", {
		Position = UDim2.fromOffset(300 + 84 + 12, 8 + 46),
		Size = UDim2.fromOffset(200, 14),
		BackgroundColor3 = UI.CREAM,
		Parent = parent,
	}, { round(), stroke(UI.WHITE, 2) })
	local fill = new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = fillColour, Parent = bar },
		{ round() }
	)
	local xp = text(parent, "", 18, UI.INK, { -- INK over the world, not INK_SOFT (QA M2, Director c)
		Position = UDim2.fromOffset(300 + 84 + 12, 8 + 22),
		Size = UDim2.fromOffset(200, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Outline = UI.WHITE,
		OutlineThickness = 1.5,
	})
	local value = Instance.new("NumberValue")
	local function draw(p: number)
		right.Rotation = math.clamp(p, 0, 0.5) * 360
		left.Rotation = math.clamp(p, 0.5, 1) * 360
	end
	value.Changed:Connect(draw)
	draw(0)
	local lastLevel: number? = nil
	return {
		set = function(level: number, fraction: number, xpText: string)
			local f = math.clamp(fraction, 0, 1)
			levelText.Text = tostring(level)
			xp.Text = xpText
			if lastLevel and level > lastLevel then
				value.Value = 0
				popScale(holder, 1.2)
			end
			lastLevel = level
			tween(value, 0.4, { Value = f })
			tween(fill, 0.4, { Size = UDim2.fromScale(f, 1) })
		end,
	}
end

function UiKit.chip(parent: Instance, w: number, h: number): Frame
	return new("Frame", {
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = UI.CHIP or UI.WHITE, -- glass: white (Garden) or dark (Lantern)
		BackgroundTransparency = UI.GLASS,
		Parent = parent,
	}, { corner(16), stroke(UI.CHIP_LINE or UI.WHITE, 2) })
end

-- Text inside a chip: 18 px CHIP_TEXT (INK) with a stroke 1 in the chip colour.
function UiKit.chipText(chip: Instance, s: string, props: { [string]: any }?): TextLabel
	local p = props or {}
	p.Position = p.Position or UDim2.fromOffset(12, 0)
	p.Size = p.Size or UDim2.new(1, -24, 1, 0)
	p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	p.Outline = UI.CHIP or UI.WHITE
	p.OutlineThickness = 1
	return text(chip, s, p.TextSize or 18, p.TextColor3 or UI.CHIP_TEXT or UI.INK, p)
end

-- Cards -------------------------------------------------------------------------------------------------

local CARDS = {
	egg = { 160, 200, 110 },
	creature = { 160, 180, 100 },
	cosmetic = { 160, 180, 100 },
	reward = { 96, 176, 56 }, -- X1.3 says 120 x 150; 7 in a row only fit an 820 px panel at 96 wide
	showcase = { 200, 240, 150 },
}

function UiKit.card(parent: Instance?, kind: string, strokeColour: Color3): Card
	local dims = (CARDS :: any)[kind] or CARDS.egg
	local w, h, iconSize = dims[1], dims[2], dims[3]
	local frame = new("TextButton", {
		Name = kind,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.SHADOW,
		BackgroundTransparency = 0.78,
		ZIndex = 0,
		Parent = frame,
	}, { corner(18) })
	local outline = stroke(strokeColour, 4)
	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.CARD,
		ZIndex = 1,
		Parent = frame,
	}, { corner(18), outline })
	local icon = new("Frame", {
		Name = "IconArea",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local name = text(body, "", if kind == "showcase" then 22 else 18, UI.INK, {
		Name = "CardName",
		Position = UDim2.fromOffset(6, iconSize + 10),
		Size = UDim2.new(1, -12, 0, if kind == "showcase" then 28 else 22),
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local pill = text(body, "", if kind == "reward" then 16 else 18, UI.WHITE, {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.GOLD,
		Outline = UI.INK,
		OutlineThickness = 1,
	})
	corner(15).Parent = pill
	local selected = false
	local hover = new("UIScale", { Name = "Hover", Parent = frame })
	local function grow(on: boolean)
		tween(hover, 0.12, { Scale = if on then 1.04 else 1 })
	end
	if kind ~= "showcase" then -- the showcase drives this scale itself (centre card 1.1)
		frame.MouseEnter:Connect(function()
			grow(true)
		end)
		frame.MouseLeave:Connect(function()
			grow(false)
		end)
		frame.SelectionGained:Connect(function()
			grow(true)
		end)
		frame.SelectionLost:Connect(function()
			grow(false)
		end)
	end
	return {
		frame = frame,
		icon = icon,
		name = name,
		pill = pill,
		select = function(on: boolean)
			selected = on
			outline.Color = if selected then UI.GOLD else strokeColour
			outline.Thickness = if selected then 6 else 4
		end,
	}
end

-- A card's state pill: WHITE text on a colour, INK_SOFT text on GREY.
function UiKit.setPill(card: Card, s: string, colour: Color3)
	card.pill.Text = s
	card.pill.BackgroundColor3 = colour
	card.pill.TextColor3 = if colour == UI.GREY then UI.INK_SOFT else UI.WHITE
	local outline = card.pill:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Enabled = colour ~= UI.GREY
	end
end

-- A white rounded row in a panel body's list.
function UiKit.row(parent: Instance, height: number, order: number): Frame
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = UI.CARD,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(18), stroke(UI.ROW_LINE or Color3.fromRGB(240, 222, 230), 3) })
end

-- A rounded progress bar, `fraction` filled in `colour`.
function UiKit.bar(parent: Instance, props: { [string]: any }, fraction: number, colour: Color3): Frame
	props.BackgroundColor3 = UI.BAR_BACK or Color3.fromRGB(245, 230, 235)
	props.Parent = parent
	local back = new("Frame", props, { round() })
	new("Frame", {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = colour,
		Parent = back,
	}, { round() })
	return back
end

function UiKit.grid(parent: Instance, cellW: number, cellH: number): UIGridLayout
	if parent:IsA("Frame") then
		parent.AutomaticSize = Enum.AutomaticSize.Y
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12), Parent = parent })
	end
	return new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellW, cellH),
		CellPadding = UDim2.fromOffset(16, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- The species' real model in a ViewportFrame, filled when the server has loaded it. `dark` draws a
-- silhouette (an undiscovered species). `folder` defaults to the configured `previews` folder.
function UiKit.viewport(parent: Instance, species: string, dark: boolean?, folder: string?): ViewportFrame
	local view = new("ViewportFrame", {
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		ImageColor3 = if dark then UI.SILHOUETTE or Color3.fromRGB(60, 45, 70) else Color3.new(1, 1, 1),
		Parent = parent,
	})
	local function fill(mesh: Instance)
		if not (mesh:IsA("BasePart") or mesh:IsA("Model")) or not view.Parent then
			return
		end
		local copy = mesh:Clone()
		local box: CFrame, size: Vector3
		if copy:IsA("Model") then
			box, size = copy:GetBoundingBox()
		else
			box, size = (copy :: BasePart).CFrame, (copy :: BasePart).Size
		end
		copy:PivotTo(copy:GetPivot() - box.Position) -- bounding box centred on the origin
		copy.Parent = view
		local eye = new("Camera", { FieldOfView = 30, Parent = view })
		eye.CFrame = CFrame.lookAt(Vector3.new(0.45, 0.25, -1).Unit * size.Magnitude * 1.9, Vector3.zero)
		view.CurrentCamera = eye
	end
	local name = folder or cfg.previews
	if name == nil then
		return view
	end
	local models = ReplicatedStorage:FindFirstChild(name)
	local mesh = models and models:FindFirstChild(species)
	if mesh then
		fill(mesh)
	else
		-- The server loads the models after join: fill the frame when this one arrives.
		task.spawn(function()
			local f = ReplicatedStorage:WaitForChild(name, 60)
			local m = f and f:WaitForChild(species, 60)
			if m then
				fill(m)
			end
		end)
	end
	return view
end

-- Panels --------------------------------------------------------------------------------------------------

local current: Panel? = nil
local modals: { Panel } = {}

-- The shell: shadow, outer INK_SOFT line, PANEL body with a WHITE stroke, the ribbon with its title
-- and the close X. Returns the panel table with the body ScrollingFrame under the ribbon.
local function shell(gui: Instance, title: string, accent: Color3, w: number, h: number, z: number): Panel
	local frame = new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 20),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		SelectionGroup = true,
		ZIndex = z,
		Parent = gui,
	})
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.SHADOW,
		BackgroundTransparency = 0.78,
		ZIndex = 1,
		Parent = frame,
	}, { corner(24) })
	new("Frame", {
		Name = "Outer",
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundColor3 = UI.INK_SOFT,
		ZIndex = 2,
		Parent = frame,
	}, { corner(30) })
	local main = new("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.PANEL,
		ZIndex = 3,
		Parent = frame,
	}, { corner(24), stroke(UI.WHITE, 4) })
	local ribbon = new("Frame", {
		Name = "Ribbon",
		Position = UDim2.fromOffset(-6, -10),
		Size = UDim2.new(1, 12, 0, 72),
		ZIndex = 4,
		Parent = frame,
	}, { corner(20), stroke(UI.WHITE, 3) })
	shine(ribbon, accent, 0.25, 16 / 72)
	text(ribbon, title, 36, UI.WHITE, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -150, 0, 44),
		Outline = UI.INK,
		OutlineThickness = 2,
	})
	local top = 76
	local footerH = 0
	local body = new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(20, top),
		Size = UDim2.new(1, -28, 1, -(top + 16)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = edge(accent),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		SelectionGroup = true,
		Parent = main,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 12),
		}),
	})
	local function layout()
		body.Position = UDim2.fromOffset(20, top)
		body.Size = UDim2.new(1, -28, 1, -(top + 16 + footerH))
	end
	local panel: Panel
	local tabRow: Frame? = nil
	local tabButtons: { [string]: TextButton } = {}
	local labels: { string } = {}
	local onTab: (string) -> () = function(_: string) end
	local function paintTabs()
		for label, b in tabButtons do
			local active = panel.tab == label
			local caption = b:FindFirstChild("Label") :: TextLabel
			b.BackgroundColor3 = if active then accent else UI.CARD
			caption.TextColor3 = if active then UI.WHITE else UI.INK;
			(b:FindFirstChild("Outline") :: UIStroke).Color = if active then edge(accent) else UI.INK_SOFT;
			(caption:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = active
		end
	end
	local closeButton: TextButton
	panel = {
		frame = frame,
		body = body,
		tab = nil,
		onClose = nil,
		setTab = function(label: string)
			panel.tab = label
			paintTabs()
			body.CanvasPosition = Vector2.zero
			onTab(label)
		end,
		setTabs = function(newLabels: { string }, handler: (string) -> ())
			labels, onTab = newLabels, handler
			if tabRow then
				tabRow:Destroy()
			end
			tabButtons = {}
			local row = new("Frame", {
				Name = "Tabs",
				Position = UDim2.fromOffset(20, top),
				Size = UDim2.new(1, -40, 0, 52),
				BackgroundTransparency = 1,
				Parent = main,
			}, {
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			tabRow = row
			for i, label in labels do
				local width = TextService:GetTextSize(label, 22, cfg.fonts.body, Vector2.new(1000, 52)).X
				local b = new("TextButton", {
					Name = label,
					Size = UDim2.fromOffset(math.max(120, width + 48), 52),
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = i,
					Parent = row,
				}, {
					corner(16),
					new("UIStroke", {
						Name = "Outline",
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				})
				text(b, label, 22, UI.INK, {
					Name = "Label",
					Size = UDim2.fromScale(1, 1),
					TextScaled = false,
					Outline = UI.INK,
					OutlineThickness = 1.5,
				})
				b.Activated:Connect(function()
					if panel.tab ~= label then
						cfg.sound("tick", 0.15, 2.2)
						panel.setTab(label)
					end
				end)
				tabButtons[label] = b
			end
			top = 76 + 52 + 12
			layout()
			paintTabs()
		end,
		setFooter = function(height: number): Frame?
			local old = main:FindFirstChild("Footer")
			if old then
				old:Destroy()
			end
			footerH = if height > 0 then height + 10 else 0
			layout()
			if height <= 0 then
				return nil
			end
			return new("Frame", {
				Name = "Footer",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 20, 1, -16),
				Size = UDim2.new(1, -40, 0, height),
				BackgroundColor3 = UI.CREAM,
				SelectionGroup = true,
				Parent = main,
			}, { corner(18), stroke(UI.WHITE, 3) })
		end,
		close = function() end,
	}
	closeButton = makeButton(frame, "X", UI.CORAL, 56, 56, 18, 30, function()
		panel.close()
	end)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 14, 0, -24)
	closeButton.ZIndex = 5
	if cfg.icons.close then -- a game with a drawn close icon shows it instead of the X
		local face = closeButton:FindFirstChild("Face") :: Frame
		(face:FindFirstChild("Label") :: TextLabel).Visible = false
		UiKit.icon(face, "close", 44, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	-- Bumpers cycle the tabs.
	(panel :: any).cycle = function(step: number)
		local i = table.find(labels, panel.tab or "") or 1
		if #labels > 1 then
			panel.setTab(labels[(i - 1 + step) % #labels + 1])
		end
	end
	local scale = new("UIScale", { Parent = frame })
	if not still() then
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	return panel
end

local function closeWith(panel: Panel, byUser: boolean)
	if not panel.frame.Parent then
		return
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(panel.frame) then
		GuiService.SelectedObject = nil
	end
	if current == panel then
		current = nil
	end
	local i = table.find(modals, panel)
	if i then
		table.remove(modals, i)
	end
	if panel.onClose then -- before the destroy, so a caller can move reusable content out
		(panel.onClose :: (boolean) -> ())(byUser)
	end
	panel.frame:Destroy()
	local shade = (panel :: any).shade
	if shade then
		shade:Destroy()
	end
end

-- The one open panel (820 x 560, centred): opening it closes the previous one.
function UiKit.panel(gui: Instance, name: string, accent: Color3): Panel
	if current then
		closeWith(current, false)
	end
	local p = shell(gui, name, accent, 820, 560, 10)
	p.close = function()
		closeWith(p, true)
	end
	current = p
	return p
end

-- A dialog over everything (release confirm, name box, welcome back, invite and result cards): a
-- shell of its own size over a soft shade; it does not close the open panel.
function UiKit.modal(gui: Instance, title: string, accent: Color3, w: number, h: number, shade: boolean?): Panel
	local shadeFrame = if shade == false
		then nil
		else new("TextButton", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = UI.SHADOW,
			BackgroundTransparency = 0.55,
			AutoButtonColor = false,
			Selectable = false,
			Text = "",
			ZIndex = 49,
			Parent = gui,
		})
	local p = shell(gui, title, accent, w, h, 50);
	(p :: any).shade = shadeFrame
	p.close = function()
		closeWith(p, true)
	end
	table.insert(modals, p)
	return p
end

function UiKit.current(): Panel?
	return current
end

UserInputService.InputBegan:Connect(function(input: InputObject)
	local key = input.KeyCode
	if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Escape then
		local top = modals[#modals] or current
		if top then
			closeWith(top, true)
		end
	elseif (key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.ButtonR1) and current and #modals == 0 then
		(current :: any).cycle(if key == Enum.KeyCode.ButtonL1 then -1 else 1)
	end
end)

function UiKit.tabs(panel: Panel, labels: { string }, onTab: (string) -> ())
	panel.setTabs(labels, onTab)
end

-- Toasts --------------------------------------------------------------------------------------------------

-- Bottom-centre, 120 px above the bottom, up to 3 stacked with the newest lowest.
function UiKit.toast(gui: Instance): Toast
	local stack = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(440, 68 * 3 + 10 * 2),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local count = 0
	return function(s: string, icon: string?, colour: Color3?)
		local accent = colour or UI.PINK
		count += 1
		local slot = new("Frame", {
			Size = UDim2.fromOffset(440, 68),
			BackgroundTransparency = 1,
			LayoutOrder = count,
			Parent = stack,
		})
		local card = new("Frame", {
			Position = UDim2.fromOffset(0, if still() then 0 else 24),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = UI.CREAM,
			Parent = slot,
		}, { corner(22), stroke(accent, 4) })
		local disc = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = accent,
			Parent = card,
		}, { round(), stroke(UI.WHITE, 2) })
		UiKit.icon(
			disc,
			icon or "gift",
			36,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }
		)
		text(card, s, 22, UI.INK, {
			Position = UDim2.fromOffset(68, 3),
			Size = UDim2.new(1, -80, 1, -6), -- three lines at 12 px on a phone (a long "saved for you")
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local slots = {}
		for _, c in stack:GetChildren() do
			if c:IsA("Frame") then
				table.insert(slots, c)
			end
		end
		table.sort(slots, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #slots - 3 do
			slots[i]:Destroy()
		end
		tween(card, 0.25, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
		task.delay(2.75, function()
			if not slot.Parent then
				return
			end
			if still() then
				slot:Destroy()
				return
			end
			for _, d in slot:GetDescendants() do
				if d:IsA("Frame") then
					TweenService:Create(d, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				elseif d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				elseif d:IsA("ImageLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end
			end
			task.delay(0.32, slot.Destroy, slot)
		end)
	end
end

-- Start menu --------------------------------------------------------------------------------------------

local function word(parent: Instance, s: string, rotation: number, order: number): Frame
	local holder = new("Frame", {
		Size = UDim2.fromOffset(0, 140),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Rotation = rotation,
		LayoutOrder = order,
		Parent = parent,
	})
	local m = cfg.menu
	for _, layer in { { 8, m.shade, m.shade, 1 }, { 0, m.face, m.faceLine, 2 } } do
		local label = new("TextLabel", {
			Position = UDim2.fromOffset(0, layer[1] :: number),
			Size = UDim2.fromOffset(0, 130),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = cfg.fonts.title,
			TextSize = 110,
			Text = s,
			TextColor3 = layer[2] :: Color3,
			ZIndex = layer[4] :: number,
			Parent = holder,
		})
		new("UIStroke", { Color = layer[3] :: Color3, Thickness = 6, Parent = label })
	end
	return holder
end

local function showcaseCard(parent: Instance, species: string): Card
	local colour = cfg.rarity.colour(species)
	local c = UiKit.card(parent, "showcase", colour)
	UiKit.viewport(c.icon, species)
	c.name.Text = cfg.species(species)
	UiKit.setPill(c, cfg.rarity.name(species), colour)
	c.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	c.frame.Selectable = false
	return c
end

function UiKit.startMenu(
	gui: Instance,
	onPlay: () -> (),
	side: { { icon: string, label: string, onClick: () -> () } }
): {
	frame: Frame,
	play: TextButton,
	showcase: (species: { string }) -> (),
	setBadge: (label: string, count: number?) -> (),
}
	local frame = new("Frame", {
		Name = "StartMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		SelectionGroup = true,
		Parent = gui,
	})
	local m = cfg.menu
	-- Soft haze behind the logo and under the showcase, so both read over the orbit.
	new("Frame", {
		Size = UDim2.fromScale(1, 0.42),
		BackgroundColor3 = m.haze[1],
		BorderSizePixel = 0,
		Parent = frame,
	}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.25, 1) }) })
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = m.haze[2],
		BorderSizePixel = 0,
		Parent = frame,
	}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.35) }) })

	local logo = new("Frame", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.083),
		Size = UDim2.fromOffset(0, 140),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 28),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, s in m.words do
		local w = word(logo, s, if i == 1 then -4 else 0, i)
		if i == 1 and m.decorate then
			m.decorate(w)
		end
	end
	text(frame, m.tagline, 26, UI.WHITE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.083, 152),
		Size = UDim2.fromOffset(700, 34),
		Outline = UI.INK,
		OutlineThickness = 2,
	})

	local holder = new("Frame", {
		Name = "PlayHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.39),
		Size = UDim2.fromOffset(380, 100),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local play = makeButton(holder, "PLAY", m.play, 380, 100, 26, 60, onPlay)
	local pulse = new("UIScale", { Name = "Pulse", Parent = holder })
	if not still() then
		TweenService:Create(
			pulse,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.04 }
		):Play()
	end

	local column = new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -32, 0.5, 0),
		Size = UDim2.fromOffset(96, 96 * #side + 16 * (#side - 1)),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local sideButtons: { [string]: TextButton } = {}
	for i, item in side do
		local key = string.upper(string.sub(item.label, 1, 1)) .. string.lower(string.sub(item.label, 2))
		local b = UiKit.iconButton(column, item.icon, item.label, (cfg.accent or {})[key] or UI.LILAC, item.onClick)
		b.LayoutOrder = i
		sideButtons[item.label] = b
	end

	-- Showcase: three cards, the centre one larger; every 4 s the row slides one species left.
	local PITCH = 224
	local row = new("Frame", {
		Name = "Showcase",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.52, 14), -- 14 px clears PLAY at the 0.6 floor (844 x 390)
		Size = UDim2.fromOffset(PITCH * 3 + 24, 290),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = frame,
	})
	local token = 0
	local function place(c: Card, k: number, animate: boolean)
		local pos = UDim2.new(0, 12 + PITCH * (k + 1.5), 0.5, 0)
		local scale = c.frame:FindFirstChild("Hover") :: UIScale
		local goal = if k == 0 then 1.1 else 1
		if animate then
			tween(c.frame, 0.4, { Position = pos })
			tween(scale, 0.4, { Scale = goal })
		else
			c.frame.Position = pos
			scale.Scale = goal
		end
	end
	local function showcase(species: { string })
		token += 1
		local mine = token
		for _, c in row:GetChildren() do
			c:Destroy()
		end
		if #species == 0 then
			return
		end
		local at = 1
		local cards: { Card } = {}
		local function pick(k: number): string
			return species[(at - 1 + k) % #species + 1]
		end
		for k = -1, 2 do
			local c = showcaseCard(row, pick(k))
			place(c, k, false)
			table.insert(cards, c)
		end
		task.spawn(function()
			while token == mine and row.Parent do
				task.wait(4)
				if token ~= mine or not frame.Visible then
					continue
				end
				at += 1
				local gone = table.remove(cards, 1) :: Card
				for i, c in cards do
					place(c, i - 2, true)
				end
				local incoming = showcaseCard(row, pick(2))
				place(incoming, 2, false)
				table.insert(cards, incoming)
				task.delay(if still() then 0 else 0.4, gone.frame.Destroy, gone.frame)
			end
		end)
	end

	return {
		frame = frame,
		play = play,
		showcase = showcase,
		setBadge = function(label: string, count: number?)
			local b = sideButtons[label]
			if b and b:GetAttribute("Badge") ~= count then
				UiKit.setBadge(b, count)
			end
		end,
	}
end

-- Gamepad and camera --------------------------------------------------------------------------------------

function UiKit.selector(): Frame
	return new("Frame", {
		Name = "KitSelector",
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
	}, { corner(20), stroke(UI.GOLD, 5) })
end

-- First selectable button or card under `root`, for a gamepad only.
function UiKit.selectFirst(root: Instance)
	if not UserInputService:GetLastInputType().Name:find("Gamepad") then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.Selectable and d.Name ~= "X" and d.Name ~= "Shade" then
			GuiService.SelectedObject = d
			return
		end
	end
end

function UiKit.flyTo(camera: Camera, from: CFrame, to: CFrame, seconds: number, done: () -> ())
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = from
	if still() or seconds <= 0 then
		camera.CFrame = to
		done()
		return
	end
	local t = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { CFrame = to })
	t.Completed:Once(done)
	t:Play()
end

-- Theme and hooks (see the top of this file). Call once, before the first widget.
function UiKit.configure(config: Config)
	assert(config.tokens and config.tokens.INK and config.fonts and config.menu, "UiKit.configure: tokens, fonts, menu")
	table.clear(UI)
	for k, v in config.tokens do
		UI[k] = v
	end
	cfg = config
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	playerGui.SelectionImageObject = UiKit.selector()
	-- Fetch every icon once at start, so the glyphs rarely show.
	task.spawn(function()
		local list = {}
		for _, id in config.icons do
			table.insert(list, `rbxthumb://type=Asset&id={id}&w=150&h=150`)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

return UiKit
