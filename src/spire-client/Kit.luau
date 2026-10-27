--!strict
-- Neon Spire look kit (SPIRE-007), shared by the TowerView, PlazaView and City client scripts:
-- the decorative part builder, the silly billboard products (art bible 1), animated ad screens,
-- one loop for slow spins and the 0.5 Hz aircraft blink (steady with Reduce Flashing, GDD I4.6),
-- and hero meshes (decision 0010 option B) through Models when it is mapped to ReplicatedStorage.
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

-- Hero meshes ---------------------------------------------------------------------------------------

-- Models.spawn when src/relay/Models.luau is mapped to ReplicatedStorage.Models (a hook for the
-- Director, spire.project.json); otherwise nil and the caller keeps its primitive build. Yields.
local models: any = nil
local modelsTried = false
function Kit.mesh(name: string, parent: Instance, base: Vector3, scale: number, yaw: number): MeshPart?
	if not modelsTried then
		modelsTried = true
		local m = ReplicatedStorage:FindFirstChild("Models")
		if m and m:IsA("ModuleScript") then
			local ok, result = pcall(require, m)
			models = if ok then result else nil
		end
	end
	if not models then
		return nil
	end
	local mesh = models.spawn(name, parent, base, scale, yaw)
	if mesh then
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh:SetAttribute("Base", 0)
	end
	return mesh
end

return Kit
