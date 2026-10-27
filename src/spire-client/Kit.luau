--!strict
-- Neon Spire look kit (SPIRE-007), shared by the TowerView, PlazaView and City client scripts:
-- the decorative part builder, the silly billboard products (art bible 1), animated ad screens,
-- one loop for slow spins and the 0.5 Hz aircraft blink (steady with Reduce Flashing, GDD I4.6),
-- and the custom Blender models (tools/blender/spire) replicated by the server.
-- Decorative parts never collide, touch or block raycasts unless a caller turns CanQuery back on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local Kit = {}

local camera = Workspace.CurrentCamera

function Kit.part(
	parent: Instance,
	frame: CFrame,
	size: Vector3,
	colour: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = frame
	p.Size = size
	p.Color = colour
	p.Material = material
	p.Transparency = transparency or 0
	p:SetAttribute("Base", p.Transparency)
	p.Parent = parent
	return p
end

-- A cylinder lying on its side becomes a disc or a column: Roblox cylinders run along X.
function Kit.cylinder(
	parent: Instance,
	frame: CFrame,
	height: number,
	diameter: number,
	colour: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local p = Kit.part(
		parent,
		frame * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		colour,
		material,
		transparency
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Kit.ball(parent: Instance, at: CFrame, diameter: number, colour: Color3, material: Enum.Material): Part
	local p = Kit.part(parent, at, Vector3.one * diameter, colour, material)
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit.light(parent: Instance, colour: Color3, range: number, brightness: number?): PointLight
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = math.min(range, 16) -- art bible 3: range <= 16
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Billboard products (art bible 1: silly, never threatening).
Kit.ADS = {
	"SYNTH-SODA",
	"HOVER SOCKS",
	"BYTE-SIZE SNACKS",
	"NOODLE.EXE",
	"PIXEL PETS",
	"ZERO-G GUM",
	"CLOUD NAPS",
	"MEGA MOCHI",
	"LASER LATTE",
	"ROBO-WASH",
	"GLOW TOOTHPASTE",
	"TURBO TOFU",
}

local ACCENTS = {
	ClientState.UI.CYAN,
	ClientState.UI.MAGENTA,
	ClientState.UI.VIOLET,
	ClientState.UI.AMBER,
	ClientState.UI.LIME,
}
Kit.ACCENTS = ACCENTS

-- An animated ad on one face of `p`: product name over a sweeping gradient (one cycle in 4 s, well
-- under the 1 Hz sweep limit of art bible 3).
function Kit.adScreen(p: BasePart, face: Enum.NormalId, index: number, pps: number?): SurfaceGui
	local a = ACCENTS[(index - 1) % #ACCENTS + 1]
	local b = ACCENTS[index % #ACCENTS + 1]
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 12
	gui.MaxDistance = 1200
	gui.Parent = p
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BorderSizePixel = 0
	back.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, a:Lerp(Color3.new(), 0.55)),
		ColorSequenceKeypoint.new(0.5, b:Lerp(Color3.new(), 0.35)),
		ColorSequenceKeypoint.new(1, a:Lerp(Color3.new(), 0.55)),
	})
	gradient.Rotation = 20
	gradient.Offset = Vector2.new(-0.5, 0)
	gradient.Parent = back
	TweenService:Create(
		gradient,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(0.5, 0) }
	):Play()
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.FontFace = ClientState.FONT.display
	label.TextScaled = true
	label.TextColor3 = ClientState.UI.WHITE
	label.TextStrokeColor3 = a
	label.TextStrokeTransparency = 0.2
	label.Text = Kit.ADS[(index - 1) % #Kit.ADS + 1]
	label.Parent = back
	return gui
end

-- Spins and blinks ---------------------------------------------------------------------------------

type Spin = { pivot: CFrame, speed: number, angle: number }
local spins: { [PVInstance]: Spin } = setmetatable({}, { __mode = "k" }) :: any
local blinks: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Turns `target` about its own vertical axis at `speed` radians a second while it is within 300 studs
-- of the camera (further away the motion is not visible).
function Kit.spin(target: PVInstance, speed: number)
	spins[target] = { pivot = target:GetPivot(), speed = speed, angle = 0 }
end

-- Blinks at 0.5 Hz (aircraft warning light); steady when Reduce Flashing is on.
function Kit.blink(p: BasePart)
	blinks[p] = true
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	local camPos = camera.CFrame.Position
	for target, s in spins do
		if target.Parent and (s.pivot.Position - camPos).Magnitude < 300 then
			s.angle += s.speed * dt
			target:PivotTo(s.pivot * CFrame.Angles(0, s.angle, 0))
		end
	end
	local on = ClientState.settings.reduceFlashing or (clock % 2) < 1
	for p in blinks do
		p.Transparency = if on then 0 else 0.85
	end
end)

-- Blender models ------------------------------------------------------------------------------------

-- The server loads every uploaded Spire model (Models.preloadSpire) and copies it to
-- ReplicatedStorage.SpireModels. Until an asset has a model id (src/shared/SpireAssets.luau) or
-- while it is still loading, Kit.model returns nil and the caller keeps its part-built visual.
local SpireAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpireAssets"))

-- Waits (at most 15 s in all) for the uploaded models to reach the client, so views built right
-- after use them. Returns at once while no id is uploaded.
function Kit.waitModels()
	local deadline = os.clock() + 15
	for name, entry in SpireAssets do
		if entry.model then
			local folder = ReplicatedStorage:WaitForChild("SpireModels", math.max(0, deadline - os.clock()))
			if folder == nil or folder:WaitForChild(name, math.max(0, deadline - os.clock())) == nil then
				return
			end
		end
	end
end

-- A decorative copy of a Spire model standing on `base` (bounding box centred in x/z, lowest point
-- on base.Y), facing `yaw` degrees, or nil when it is not loaded. Never yields.
function Kit.model(name: string, parent: Instance, base: Vector3, yaw: number?, scale: number?): Model?
	local folder = ReplicatedStorage:FindFirstChild("SpireModels")
	local template = folder and folder:FindFirstChild(name)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local copy = template:Clone()
	if scale and scale ~= 1 then
		copy:ScaleTo(copy:GetScale() * scale)
	end
	copy:PivotTo(CFrame.new(base) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local box, size = copy:GetBoundingBox()
	copy:PivotTo(copy:GetPivot() + Vector3.new(base.X - box.X, base.Y - (box.Y - size.Y / 2), base.Z - box.Z))
	for _, p in copy:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p:SetAttribute("Base", p.Transparency)
		end
	end
	copy.Parent = parent
	return copy
end

-- The model's neon meshes (`<asset>_glow`, `_glow2`, ...), for recolouring or adding a light.
function Kit.glow(model: Model, suffix: string?): BasePart?
	return model:FindFirstChild(`{model.Name}_glow{suffix or ""}`) :: BasePart?
end

-- Yaw in degrees of a frame's look direction (for Kit.model, whose front is -Z).
function Kit.yaw(frame: CFrame): number
	local _, y = frame:ToOrientation()
	return math.deg(y)
end

return Kit
