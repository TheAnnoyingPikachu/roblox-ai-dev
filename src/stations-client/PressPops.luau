--!strict
-- Where the quick presses pop up (decision 0109, SHANNON's pick B): by the animal that fires. `card` draws
-- each pop-up (dark glass, a violet edge, key caps: SHANNON's reference, 2026-11-24) for the HUD's `pressOn`;
-- `attach` stands it by its animal on the screen, every frame, with no line to it (SHANNON, 2026-11-24). The cards of one player's team stand in one row just under
-- the team, pushed apart so none covers another: the camera is behind the team, so the enemies are always
-- higher on the screen and the cards never cover them (SHANNON: "try to not block the enemies"). Another player's animal with a full meter gets only a small
-- marker over its head: theirs to press, not this player's. Display only.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Style = require(script.Parent:WaitForChild("Style"))

local PressPops = {}

-- Each press belongs to one class (decision 0109: BattleRules.PRESS_OF_ROLE): its name and colour.
PressPops.CLASS = {
	ring = { name = "ATTACK", colour = Style.C.bad },
	needle = { name = "DEFENSE", colour = Style.C.info },
	chain = { name = "UTILITY", colour = Style.C.good },
	mash = { name = "TITAN", colour = Style.C.gold },
} :: { [string]: { name: string, colour: Color3 } }

local GAP = 8 -- between cards, and a third of the room left beside the team

type Pop = {
	card: GuiObject,
	model: Model,
	lift: Vector3,
	left: boolean?,
	at: Vector2?,
	slot: number?,
}
local pops: { Pop } = {}
local marks: { [Model]: { lift: Vector3, dot: TextLabel } } = {}
local gui: ScreenGui? = nil
local scale = 1

-- How far above a model's pivot its head is, measured once.
local function liftOf(model: Model): Vector3
	local cf, size = model:GetBoundingBox()
	return Vector3.new(0, cf.Position.Y + size.Y / 2 - model:GetPivot().Position.Y, 0)
end

-- Where a point of the world is on the screen, or nil behind the camera.
local function onScreen(p: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local v, visible = camera:WorldToViewportPoint(p)
	return if visible or v.Z > 0 then Vector2.new(v.X, v.Y) else nil
end

local function step()
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- drop what is gone
	for i = #pops, 1, -1 do
		local p = pops[i]
		if p.card.Parent == nil or p.model.Parent == nil then
			if p.card.Parent then
				p.card.Visible = false
			end
			table.remove(pops, i)
		end
	end
	-- beside the team (SHANNON: "appear not obstructing ... over the animals"): the camera stands behind the
	-- team with the crowd straight ahead, so over the heads is over the enemies. The cards stand on the open
	-- ground left and right of the team, at its height, the left animals' to the left and the rest to the
	-- right, each tied across to its animal.
	local heads: { [Pop]: Vector2 } = {}
	local shown: { Pop } = {}
	local lo, hi, mid = math.huge, -math.huge, 0
	for _, p in pops do
		local h = onScreen(p.model:GetPivot().Position + p.lift)
		local foot = onScreen(p.model:GetPivot().Position)
		p.card.Visible = h ~= nil
		if h and foot then
			heads[p] = h
			table.insert(shown, p)
			local half = math.abs(foot.Y - h.Y) * 0.6 -- about half the animal's width on the screen
			lo, hi, mid = math.min(lo, h.X - half), math.max(hi, h.X + half), mid + (h.Y + foot.Y) / 2
		end
	end
	if #shown > 0 then
		mid /= #shown
		-- the room left free is beside the whole team, not only the animals with a card up
		local me = Players.LocalPlayer.UserId
		for _, m in (shown[1].model.Parent :: Instance):GetChildren() do
			local owner = m:GetAttribute("Owner")
			if m:IsA("Model") and m:GetAttribute("Side") == 1 and (owner == nil or owner == me) then
				local h = onScreen(m:GetPivot().Position + liftOf(m))
				local foot = onScreen(m:GetPivot().Position)
				if h and foot then
					local half = math.abs(foot.Y - h.Y) * 0.6
					lo, hi = math.min(lo, h.X - half), math.max(hi, h.X + half)
				end
			end
		end
	end
	table.sort(shown, function(a, b)
		return heads[a].X < heads[b].X
	end)
	-- each card on its own animal's side of the team, the nearer the middle the nearer the team
	local centre = (lo + hi) / 2
	local sides: { [Pop]: boolean } = {}
	for _, p in shown do
		if p.left == nil then -- its side is settled when it pops up, so it never jumps across as its animal moves
			p.left = heads[p].X < centre
		end
		sides[p] = p.left :: boolean
	end
	for _, p in shown do
		local w, h = p.card.AbsoluteSize.X, p.card.AbsoluteSize.Y
		local onLeft = sides[p]
		if p.slot == nil then -- its place on its side, kept while it is up: a later card takes the next free one out
			local taken = {}
			for _, q in shown do
				if q ~= p and q.slot and sides[q] == onLeft then
					taken[q.slot] = true
				end
			end
			local k = 0
			while taken[k] do
				k += 1
			end
			p.slot = k
		end
		local out = p.slot :: number
		local x = if onLeft
			then lo - GAP * 3 * scale - w / 2 - out * (w + GAP * scale)
			else hi + GAP * 3 * scale + w / 2 + out * (w + GAP * scale)
		x = math.clamp(x, w / 2 + 8, view.X - w / 2 - 8)
		local y = math.clamp(mid - h / 2, 8, view.Y - h - 8)
		-- it glides after where it should be rather than jumping with every lunge of the animals
		local want = Vector2.new(x, y)
		p.at = if p.at then p.at:Lerp(want, 0.15) else want
		x, y = (p.at :: Vector2).X, (p.at :: Vector2).Y
		p.card.AnchorPoint = Vector2.new(0.5, 0)
		p.card.Position = UDim2.fromOffset(x, y)
	end
	-- the other players' markers
	for model, m in marks do
		local h = if model.Parent then onScreen(model:GetPivot().Position + m.lift) else nil
		m.dot.Visible = h ~= nil
		if h then
			m.dot.Position = UDim2.fromOffset(h.X, h.Y - 14 * scale)
		elseif model.Parent == nil then
			m.dot:Destroy()
			marks[model] = nil
		end
	end
end

-- Start: cards and markers are drawn in `screen`.
function PressPops.init(screen: ScreenGui)
	gui = screen
	RunService.RenderStepped:Connect(step)
end

local GLASS, EDGE, LILAC = Color3.fromRGB(34, 20, 58), Color3.fromRGB(179, 107, 255), Color3.fromRGB(227, 179, 255)
PressPops.GOLD, PressPops.GREEN, PressPops.EDGE = Color3.fromRGB(255, 194, 58), Color3.fromRGB(87, 224, 90), EDGE
PressPops.DIM, PressPops.LIT = Color3.fromRGB(64, 40, 104), Color3.fromRGB(208, 123, 255)

local function frame(parent: Instance, size: UDim2, at: UDim2, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel, f.AnchorPoint, f.Size, f.Position = 0, Vector2.new(0.5, 0.5), size, at
	f.BackgroundColor3, f.ZIndex = colour, z
	f.Parent = parent
	return f
end
local function corner(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end
local function edge(f: GuiObject, colour: Color3, thick: number): UIStroke
	local e = Instance.new("UIStroke")
	e.Color, e.Thickness, e.ApplyStrokeMode = colour, thick, Enum.ApplyStrokeMode.Border
	e.Parent = f
	return e
end
local function words(parent: Instance, text: string, size: number, at: UDim2, colour: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.AnchorPoint, t.Position = 1, Vector2.new(0.5, 0.5), at
	t.Size, t.Text, t.TextSize, t.Font = UDim2.new(1, 0, 0, size + 4), text, size, Enum.Font.FredokaOne
	t.TextColor3, t.ZIndex = colour, z
	t.Parent = parent
	return t
end
-- a key cap, `w` wide, its middle at `at`
local function key(parent: Instance, text: string, w: number, at: UDim2, k: number): Frame
	local long = (utf8.len(text) or 1) > 1 -- SPACE: a wide cap, smaller letters
	local cap = frame(parent, UDim2.fromOffset(if long then w * 2.6 else w, w), at, Color3.fromRGB(46, 31, 74), 8)
	corner(cap, math.floor(w * 0.24))
	edge(cap, LILAC, math.max(1, 2 * k))
	local shade = frame(
		cap,
		UDim2.new(1, 0, 0, math.max(2, 3 * k)),
		UDim2.new(0.5, 0, 1, -math.max(1, 1.5 * k)),
		Color3.fromRGB(22, 12, 40),
		8
	)
	corner(shade, math.floor(w * 0.24))
	words(
		cap,
		text,
		math.floor(w * (if long then 0.4 else 0.55)),
		UDim2.fromScale(0.5, 0.47),
		Color3.fromRGB(244, 236, 255),
		9
	)
	return cap
end

-- `fn` the moment `b` is pressed (a click or a touch), not when it is let go: the presses are timed
local function onPress(b: GuiButton, fn: () -> ())
	b.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			fn()
		end
	end)
end

-- A quick press's pop-up (decision 0109, the reference's look): a card of dark glass with a violet edge, its
-- instruction on top, and under it the press. `keys` are its keys' names (PressPops.claim: one, or the chain's three). `on.press` runs on a click of the
-- card, `on.down` / `on.up` on a mouse button held on it (the ring), `on.mark(i)` on the chain's mark i.
-- Returns the card and the parts the HUD moves: `edge` (the card's), `dots` (the ring's), `hand` (the
-- needle's), `fill` (the mash's bar), `marks` (the chain's caps).
export type Card = {
	edge: UIStroke,
	dots: { Frame },
	hand: Frame?,
	fill: Frame?,
	marks: { TextButton },
	key: Frame?,
	lit: number,
}
function PressPops.card(
	parent: Instance,
	press: string,
	keys: { string },
	k: number,
	wide: number,
	on: any
): (TextButton, Card)
	local card = Instance.new("TextButton")
	card.Name, card.Text, card.AutoButtonColor = "Press", "", false
	card.Size, card.BackgroundColor3, card.ZIndex = UDim2.fromOffset(150 * k, 132 * k), GLASS, 5
	card.Parent = parent
	corner(card, math.floor(14 * k))
	local parts: Card = { edge = edge(card, EDGE, math.max(1, 2 * k)), dots = {}, marks = {}, lit = 0 }
	local glass = Instance.new("UIGradient") -- lighter at the top, like glass
	glass.Rotation, glass.Color = 90, ColorSequence.new(Color3.fromRGB(70, 44, 112), GLASS)
	glass.Parent = card
	local inner = frame(card, UDim2.new(1, -8 * k, 1, -8 * k), UDim2.fromScale(0.5, 0.5), GLASS, 5)
	inner.BackgroundTransparency = 1
	corner(inner, math.floor(11 * k))
	edge(inner, Color3.fromRGB(120, 70, 190), 1).Transparency = 0.4
	local say = ({ ring = "HOLD THE KEY", needle = "STOP IN THE GREEN", chain = "TAP IN ORDER", mash = "MASH!" })[press]
		or "TAP!"
	words(card, say, math.floor(14 * k), UDim2.new(0.5, 0, 0, 16 * k), Color3.fromRGB(241, 214, 255), 7)
	local mid = UDim2.new(0.5, 0, 0, 78 * k)
	if press == "ring" then -- the ring fills round the key while it is held (`dots`, lit by the HUD)
		local N, R = 28, 40 * k
		for i = 1, N do
			local a = (i - 1) / N * math.pi * 2 - math.pi / 2
			local dot = frame(
				card,
				UDim2.fromOffset(7 * k, 7 * k),
				UDim2.new(0.5, math.cos(a) * R, 0, 78 * k + math.sin(a) * R),
				PressPops.DIM,
				6
			)
			corner(dot, math.floor(4 * k))
			table.insert(parts.dots, dot)
		end
		local well = frame(card, UDim2.fromOffset(62 * k, 62 * k), mid, Color3.fromRGB(26, 14, 46), 6)
		corner(well, math.floor(31 * k))
		edge(well, Color3.fromRGB(91, 62, 140), 1)
		parts.key = key(card, keys[1], 28 * k, UDim2.new(0.5, 0, 0, 72 * k), k)
		words(card, "HOLD", math.floor(10 * k), UDim2.new(0.5, 0, 0, 94 * k), Color3.fromRGB(241, 198, 255), 9)
		card.MouseButton1Down:Connect(on.down)
		card.MouseButton1Up:Connect(on.up)
		card.MouseLeave:Connect(on.up)
	elseif press == "needle" then -- the track, the green zone and the marker swinging through it (`hand`)
		local bar =
			frame(card, UDim2.new(1, -24 * k, 0, 18 * k), UDim2.new(0.5, 0, 0, 66 * k), Color3.fromRGB(22, 12, 40), 6)
		corner(bar, math.floor(9 * k))
		edge(bar, LILAC, math.max(1, 2 * k))
		bar.ClipsDescendants = true
		local green = frame(bar, UDim2.fromScale(wide, 1), UDim2.fromScale(0.5, 0.5), PressPops.GREEN, 7)
		edge(green, Color3.fromRGB(170, 255, 160), 1).Transparency = 0.5
		local hand = frame(bar, UDim2.new(0, 3 * k, 1, 0), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 8)
		parts.hand = hand
		parts.key = key(card, keys[1], 24 * k, UDim2.new(0.5, 0, 0, 104 * k), k)
		onPress(card, on.press)
	elseif press == "chain" then -- three caps with arrows, the one due in gold (`marks`)
		local row = frame(card, UDim2.new(1, 0, 0, 34 * k), UDim2.new(0.5, 0, 0, 74 * k), GLASS, 6)
		row.BackgroundTransparency = 1
		local list = Instance.new("UIListLayout")
		list.FillDirection, list.HorizontalAlignment, list.VerticalAlignment =
			Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
		list.SortOrder, list.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 2 * k)
		list.Parent = row
		for i = 1, 3 do
			local b = Instance.new("TextButton")
			b.Size, b.BackgroundColor3, b.AutoButtonColor, b.LayoutOrder, b.ZIndex =
				UDim2.fromOffset(32 * k, 32 * k), Color3.fromRGB(46, 31, 74), false, i * 2, 8
			b.Text, b.TextSize, b.Font, b.TextColor3 =
				keys[i] or tostring(i), math.floor(17 * k), Enum.Font.FredokaOne, Color3.fromRGB(244, 236, 255)
			corner(b, math.floor(8 * k))
			edge(b, if i == 1 then PressPops.GOLD else EDGE, math.max(1, 2 * k))
			b.Parent = row
			onPress(b, function()
				on.mark(i)
			end)
			table.insert(parts.marks, b)
			if i < 3 then
				local arrow = words(row, "›", math.floor(15 * k), UDim2.new(), LILAC, 8)
				arrow.Size, arrow.LayoutOrder = UDim2.fromOffset(10 * k, 20 * k), i * 2 + 1
			end
		end
		onPress(card, on.press)
	else -- mash: the key over a violet burst, the bar under it (`fill`)
		local burst = frame(card, UDim2.fromOffset(58 * k, 58 * k), UDim2.new(0.5, 0, 0, 64 * k), PressPops.LIT, 6)
		burst.BackgroundTransparency = 0.72
		corner(burst, math.floor(29 * k))
		edge(burst, PressPops.LIT, math.max(1, 2 * k)).Transparency = 0.3
		parts.key = key(card, keys[1], 32 * k, UDim2.new(0.5, 0, 0, 64 * k), k)
		local track =
			frame(card, UDim2.new(1, -28 * k, 0, 12 * k), UDim2.new(0.5, 0, 0, 108 * k), Color3.fromRGB(22, 12, 40), 6)
		corner(track, math.floor(6 * k))
		edge(track, LILAC, math.max(1, 2 * k))
		local fill = frame(track, UDim2.fromScale(0, 1), UDim2.fromScale(0, 0.5), PressPops.LIT, 7)
		fill.AnchorPoint = Vector2.new(0, 0.5)
		corner(fill, math.floor(6 * k))
		parts.fill = fill
		onPress(card, on.press)
	end
	local pop = Instance.new("UIScale")
	pop.Name, pop.Scale = "Punch", 0.4
	pop.Parent = card
	TweenService:Create(
		parts.edge,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = math.max(2, 4 * k) }
	):Play()
	TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return card, parts
end

-- Keys (SHANNON, 2026-11-24): the Titan's mash is Space, a chain three arrow keys in a random order, a ring
-- or a needle one of W A S D; no two cards up at once share a key. While a fight is on these keys press, not
-- move the character (`listen`).
local WASD = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }
local ARROWS = { Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right }
local NAMES = {
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.A] = "A",
	[Enum.KeyCode.S] = "S",
	[Enum.KeyCode.D] = "D",
	[Enum.KeyCode.Up] = "↑",
	[Enum.KeyCode.Down] = "↓",
	[Enum.KeyCode.Left] = "←",
	[Enum.KeyCode.Right] = "→",
	[Enum.KeyCode.Space] = "SPACE",
}
local taken: { [Enum.KeyCode]: boolean } = {}
local shuffle = Random.new()

-- The keys of a card for `press`, taken until `free`d.
function PressPops.claim(press: string): { Enum.KeyCode }
	if press == "mash" then
		return { Enum.KeyCode.Space }
	end
	local want = if press == "chain" then 3 else 1
	local first, second = if press == "chain" then ARROWS else WASD, if press == "chain" then WASD else ARROWS
	local function open(pool: { Enum.KeyCode }): { Enum.KeyCode }
		local out = {}
		for _, kc in pool do
			if not taken[kc] then
				table.insert(out, kc)
			end
		end
		shuffle:Shuffle(out)
		return out
	end
	local pick = open(first)
	if #pick < want then -- its own keys are in use (a second chain): the other set
		pick = open(second)
	end
	-- shortcut: three chains up at once run out of free keys and reuse arrows, a team of three utility animals only
	local extra = table.clone(ARROWS)
	shuffle:Shuffle(extra)
	while #pick < want do
		table.insert(pick, table.remove(extra) :: Enum.KeyCode)
	end
	local out = table.move(pick, 1, want, 1, {})
	for _, kc in out do
		taken[kc] = true
	end
	return out
end

function PressPops.free(keys: { Enum.KeyCode })
	for _, kc in keys do
		taken[kc] = nil
	end
end

function PressPops.names(keys: { Enum.KeyCode }): { string }
	local out = {}
	for _, kc in keys do
		table.insert(out, NAMES[kc] or "?")
	end
	return out
end

-- While `fn` is set the press keys go to it (`down` true on a press, false on a let-go) instead of the
-- character's movement and jump; nil gives them back.
function PressPops.listen(fn: ((key: Enum.KeyCode, down: boolean) -> ())?)
	ContextActionService:UnbindAction("StationsPresses")
	if fn == nil then
		return
	end
	local keys = table.clone(WASD)
	table.move(ARROWS, 1, #ARROWS, #keys + 1, keys)
	table.insert(keys, Enum.KeyCode.Space)
	ContextActionService:BindActionAtPriority("StationsPresses", function(_, state, input)
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.End then
			fn(input.KeyCode, state == Enum.UserInputState.Begin)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, table.unpack(keys))
end

-- Effects (display only) -------------------------------------------------------------------------------

-- `obj` jumps by `amount` of its size and springs back.
function PressPops.punch(obj: GuiObject, amount: number)
	local s = obj:FindFirstChild("Punch") :: UIScale?
	if s == nil then
		local made = Instance.new("UIScale")
		made.Name = "Punch"
		made.Parent = obj
		s = made
	end
	local sc = s :: UIScale
	sc.Scale = 1 + amount
	TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- A burst of light at the middle of `obj`: a ring that grows and fades, and `n` sparks flying out.
function PressPops.burst(obj: GuiObject, colour: Color3, size: number, n: number)
	if gui == nil or obj.Parent == nil then
		return
	end
	local at = obj.AbsolutePosition + obj.AbsoluteSize / 2
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency, ring.AnchorPoint, ring.ZIndex = 1, Vector2.new(0.5, 0.5), 20
	ring.Position, ring.Size = UDim2.fromOffset(at.X, at.Y), UDim2.fromOffset(size * 0.4, size * 0.4)
	corner(ring, 999)
	local e = edge(ring, colour, math.max(2, size / 14))
	ring.Parent = gui
	TweenService:Create(
		ring,
		TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(size * 1.6, size * 1.6) }
	):Play()
	TweenService:Create(e, TweenInfo.new(0.38), { Transparency = 1, Thickness = 1 }):Play()
	for i = 1, n do
		local a = (i + math.random()) / n * math.pi * 2
		local spark = Instance.new("Frame")
		spark.BorderSizePixel, spark.AnchorPoint, spark.ZIndex, spark.BackgroundColor3 =
			0, Vector2.new(0.5, 0.5), 21, colour
		local w = math.max(3, size / 16)
		spark.Size, spark.Position, spark.Rotation =
			UDim2.fromOffset(w * 2.4, w), UDim2.fromOffset(at.X, at.Y), math.deg(a)
		corner(spark, 999)
		spark.Parent = gui
		local reach = size * (0.55 + math.random() * 0.45)
		TweenService:Create(spark, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(at.X + math.cos(a) * reach, at.Y + math.sin(a) * reach),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(w, w * 0.6),
		}):Play()
		task.delay(0.45, spark.Destroy, spark)
	end
	task.delay(0.4, ring.Destroy, ring)
end

-- A press on the card (a mash's press, a chain's mark, the ring's hold starting): `obj` (a key cap or a mark)
-- jumps, a little burst goes off on it, and with `shake` the card jolts.
function PressPops.press(card: GuiObject, obj: GuiObject?, colour: Color3?, shake: boolean?)
	local target = obj or card
	PressPops.punch(target, -0.18)
	PressPops.burst(target, colour or PressPops.LIT, target.AbsoluteSize.X * 1.3, 6)
	if shake then
		card.Rotation = (math.random() - 0.5) * 7
		TweenService
			:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 })
			:Play()
	end
end

-- The ring's dots: a dot just lit pops.
function PressPops.lit(parts: Card, count: number)
	for i = parts.lit + 1, math.min(count, #parts.dots) do
		PressPops.punch(parts.dots[i], 0.9)
	end
	parts.lit = count
end

-- The press has fired: a big burst (gold when it was on time: `hot`), the card springs up and away and is gone.
function PressPops.fired(card: GuiObject, hot: boolean)
	task.delay(0.34, card.Destroy, card)
	PressPops.burst(card, if hot then PressPops.GOLD else PressPops.LIT, card.AbsoluteSize.X * 1.25, 14)
	local s = card:FindFirstChild("Punch") :: UIScale?
	if s then
		s.Scale = 1.18
		TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			:Play()
	end
end

-- Stand `card` (a quick press's pop-up) by `model` until the card is destroyed. `k` is the HUD's scale.
function PressPops.attach(card: GuiObject, model: Model?, _press: string, k: number)
	scale = k
	if model == nil or gui == nil then
		return
	end
	table.insert(pops, { card = card, model = model, lift = liftOf(model) })
	step()
end

-- Another player's animal `model`, whose press is `press`: a marker over it while `full`.
function PressPops.ally(model: Model, press: string, full: boolean)
	local m = marks[model]
	if not full then
		if m then
			m.dot:Destroy()
			marks[model] = nil
		end
		return
	end
	if m or gui == nil then
		return
	end
	local dot = Style.text(gui :: ScreenGui, "!", 22 * scale, Style.C.ink, UDim2.fromOffset(34 * scale, 34 * scale))
	dot.Name, dot.AnchorPoint, dot.ZIndex = "AllyPress", Vector2.new(0.5, 1), 4
	dot.BackgroundTransparency, dot.BackgroundColor3 = 0.1, (PressPops.CLASS[press] or PressPops.CLASS.ring).colour
	dot.TextXAlignment = Enum.TextXAlignment.Center
	Style.round(dot, 17 * scale)
	marks[model] = { lift = liftOf(model), dot = dot }
end

return PressPops
