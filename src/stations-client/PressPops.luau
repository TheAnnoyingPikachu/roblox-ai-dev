--!strict
-- Where the quick presses pop up (decision 0109, SHANNON's pick B): over the animal that fires. The HUD makes
-- each pop-up card (Hud.client: `pressOn`); this stands it over its animal on the screen, every frame, tied to
-- the animal by a line in its class's colour. The cards of one player's team stand in one row just under
-- the team, pushed apart so none covers another: the camera is behind the team, so the enemies are always
-- higher on the screen and the cards never cover them (SHANNON: "try to not block the enemies"). Another player's animal with a full meter gets only a small
-- marker over its head: theirs to press, not this player's. Display only.

local RunService = game:GetService("RunService")
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

local GAP, DROP = 10, 26 -- between cards; how far under the lowest animal's middle the row's top is

type Pop = { card: GuiObject, model: Model, line: Frame }
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

local function line(from: Vector2, to: Vector2, frame: Frame)
	local d = to - from
	frame.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
	frame.Size = UDim2.fromOffset(d.Magnitude, math.max(2, 3 * scale))
	frame.Rotation = math.deg(math.atan2(d.Y, d.X))
end

local function step()
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- drop what is gone
	for i = #pops, 1, -1 do
		local p = pops[i]
		if p.card.Parent == nil or p.model.Parent == nil then
			p.line:Destroy()
			if p.card.Parent then
				p.card.Visible = false
			end
			table.remove(pops, i)
		end
	end
	-- the row: under the lowest animal, cards side by side in the order of their animals across the screen
	local heads: { [Pop]: Vector2 } = {}
	local shown: { Pop } = {}
	local rowY = -math.huge
	for _, p in pops do
		local h = onScreen(p.model:GetPivot().Position)
		p.card.Visible, p.line.Visible = h ~= nil, h ~= nil
		if h then
			heads[p] = h
			table.insert(shown, p)
			rowY = math.max(rowY, h.Y + DROP * scale)
		end
	end
	table.sort(shown, function(a, b)
		return heads[a].X < heads[b].X
	end)
	local xs, mean = {}, 0
	for i, p in shown do
		local w = p.card.AbsoluteSize.X
		xs[i] = if i == 1
			then heads[p].X
			else math.max(heads[p].X, xs[i - 1] + (w + shown[i - 1].card.AbsoluteSize.X) / 2 + GAP * scale)
		mean += xs[i] - heads[p].X
	end
	local back = if #shown > 0 then mean / #shown else 0 -- keep the row centred over the team
	for i, p in shown do
		local w, h = p.card.AbsoluteSize.X, p.card.AbsoluteSize.Y
		local x = math.clamp(xs[i] - back, w / 2 + 8, view.X - w / 2 - 8)
		local y = math.clamp(rowY, 0, view.Y - h - 8)
		p.card.AnchorPoint = Vector2.new(0.5, 0)
		p.card.Position = UDim2.fromOffset(x, y)
		line(Vector2.new(x, y), heads[p], p.line)
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

-- Stand `card` (a quick press's pop-up, `press` its kind) over `model` until the card is destroyed. `k` is
-- the HUD's scale.
function PressPops.attach(card: GuiObject, model: Model?, press: string, k: number)
	scale = k
	local class = PressPops.CLASS[press] or PressPops.CLASS.ring
	-- its class: the card's edge in the class's colour and a tag on its top edge
	local face = card:FindFirstChild("Face")
	local edge = if face then face:FindFirstChildOfClass("UIStroke") else nil
	if edge then
		edge.Color, edge.Thickness = class.colour, 5
	end
	local tag = Style.text(card, class.name, 16 * k, Style.C.card, UDim2.fromOffset(104 * k, 24 * k))
	tag.Name, tag.AnchorPoint, tag.Position = "Class", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0)
	tag.BackgroundTransparency, tag.BackgroundColor3, tag.ZIndex = 0, class.colour, card.ZIndex + 3
	tag.TextXAlignment = Enum.TextXAlignment.Center
	Style.round(tag, 12 * k)
	if model == nil or gui == nil then
		return
	end
	local l = Instance.new("Frame")
	l.Name, l.BorderSizePixel, l.BackgroundColor3, l.AnchorPoint = "Tether", 0, class.colour, Vector2.new(0.5, 0.5)
	l.ZIndex = math.max(1, card.ZIndex - 1)
	l.Parent = gui
	table.insert(pops, { card = card, model = model, line = l })
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
