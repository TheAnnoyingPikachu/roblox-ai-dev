--!strict
-- Relay Rounds custom models, built from parts and Roblox materials (CLAUDE.md rule 9):
-- torii gates, stone lanterns, cherry-blossom trees, gothic spires and the demon finish gate.

local Props = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(28, 24, 30)

function Props.part(
	parent: Instance,
	size: Vector3,
	cframe: CFrame | Vector3,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	if typeof(cframe) == "Vector3" then
		p.Position = cframe
	else
		p.CFrame = cframe
	end
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local part = Props.part

local function wedge(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = colour
	w.Material = material or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end

-- A vertical cylinder standing on `base`.
function Props.pillar(
	parent: Instance,
	base: Vector3,
	height: number,
	radius: number,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = part(
		parent,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		colour,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local pillar = Props.pillar

-- Text on both faces of a board, scaled per stud so it never stretches.
function Props.label(board: BasePart, text: string, colour: Color3?)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.TextColor3 = colour or WHITE
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.Text = text
		l.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = INK
		stroke.Parent = l
	end
end

local function glow(p: BasePart, colour: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = range
	light.Brightness = brightness
	light.Parent = p
end

-- Torii gate centred on `base`, spanning x. `colour` tints the plaque; the gate itself is vermilion and ink.
function Props.torii(parent: Instance, base: Vector3, width: number, height: number, colour: Color3, text: string?)
	local vermilion = Color3.fromRGB(196, 40, 28)
	for _, side in { -1, 1 } do
		local foot = base + Vector3.new(side * width / 2, 0, 0)
		pillar(parent, foot, 1, 1.3, INK, Enum.Material.Slate)
		pillar(parent, foot, height, 0.8, vermilion, Enum.Material.Wood)
	end
	-- Nuki (lower tie beam) and the kasagi (upturned top beam) with dark cap.
	part(
		parent,
		Vector3.new(width + 3, 0.9, 0.9),
		base + Vector3.new(0, height - 2.6, 0),
		vermilion,
		Enum.Material.Wood
	)
	part(
		parent,
		Vector3.new(width + 5, 1.1, 1.6),
		base + Vector3.new(0, height + 0.2, 0),
		vermilion,
		Enum.Material.Wood
	)
	part(parent, Vector3.new(width + 6, 0.7, 2), base + Vector3.new(0, height + 1.1, 0), INK, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		wedge(
			parent,
			Vector3.new(2, 1.2, 1.6),
			CFrame.new(base + Vector3.new(side * (width / 2 + 3.5), height + 1.3, 0))
				* CFrame.Angles(0, math.rad(side * 90), 0),
			INK,
			Enum.Material.Slate
		)
	end
	if text then
		local plaque = part(
			parent,
			Vector3.new(math.max(4, #text * 0.9), 1.6, 0.4),
			base + Vector3.new(0, height - 1.2, 0),
			INK,
			Enum.Material.Slate
		)
		plaque.CanCollide = false
		Props.label(plaque, text, colour)
	end
end

-- Stone lantern (toro) with a warm light.
function Props.lantern(parent: Instance, base: Vector3)
	local stone = Color3.fromRGB(150, 148, 140)
	part(parent, Vector3.new(2.4, 0.6, 2.4), base + Vector3.new(0, 0.3, 0), stone, Enum.Material.Slate)
	pillar(parent, base + Vector3.new(0, 0.6, 0), 2.4, 0.4, stone, Enum.Material.Slate)
	part(parent, Vector3.new(2, 0.4, 2), base + Vector3.new(0, 3.2, 0), stone, Enum.Material.Slate)
	local fire = part(
		parent,
		Vector3.new(1.3, 1.3, 1.3),
		base + Vector3.new(0, 4, 0),
		Color3.fromRGB(255, 190, 110),
		Enum.Material.Neon
	)
	glow(fire, Color3.fromRGB(255, 170, 90), 14, 1.5)
	local roof = part(parent, Vector3.new(2.8, 0.5, 2.8), base + Vector3.new(0, 4.9, 0), stone, Enum.Material.Slate)
	roof.CFrame = roof.CFrame * CFrame.Angles(0, math.rad(45), 0)
	part(parent, Vector3.new(0.6, 0.6, 0.6), base + Vector3.new(0, 5.4, 0), stone, Enum.Material.Slate)
end

-- Cherry-blossom tree with drifting petals.
function Props.sakura(parent: Instance, base: Vector3, rng: Random)
	local height = rng:NextNumber(9, 14)
	local bark = Color3.fromRGB(78, 52, 46)
	pillar(parent, base, height, 0.9, bark, Enum.Material.Wood)
	local pinks = { Color3.fromRGB(255, 183, 210), Color3.fromRGB(255, 160, 195), Color3.fromRGB(250, 205, 225) }
	for i = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = rng:NextNumber(1.5, 4.5)
		local size = rng:NextNumber(5, 8)
		local blossom = part(
			parent,
			Vector3.new(size, size * 0.8, size),
			base + Vector3.new(math.cos(angle) * reach, height + rng:NextNumber(-1, 2.5), math.sin(angle) * reach),
			pinks[rng:NextInteger(1, #pinks)],
			Enum.Material.LeafyGrass
		)
		blossom.Shape = Enum.PartType.Ball
		blossom.CanCollide = false
		if i == 1 then
			local petals = Instance.new("ParticleEmitter")
			petals.Color = ColorSequence.new(Color3.fromRGB(255, 190, 215))
			petals.Size = NumberSequence.new(0.35)
			petals.Lifetime = NumberRange.new(4, 6)
			petals.Speed = NumberRange.new(1, 2)
			petals.Acceleration = Vector3.new(1.5, -1.2, 0.5)
			petals.Rotation = NumberRange.new(0, 360)
			petals.RotSpeed = NumberRange.new(-90, 90)
			petals.SpreadAngle = Vector2.new(180, 180)
			petals.Rate = 3
			petals.Parent = blossom
		end
	end
end

-- Gothic spire: stacked tapering stone blocks with a red ember on top.
function Props.spire(parent: Instance, base: Vector3, height: number)
	local stone = Color3.fromRGB(58, 52, 62)
	local levels = 4
	for i = 0, levels - 1 do
		local w = 5 - i
		part(
			parent,
			Vector3.new(w, height / levels, w),
			base + Vector3.new(0, height / levels * (i + 0.5), 0),
			stone,
			Enum.Material.Slate
		)
	end
	for _, rot in { 0, 180 } do
		wedge(
			parent,
			Vector3.new(1.5, 4, 1.5),
			CFrame.new(base + Vector3.new(0, height + 2, 0)) * CFrame.Angles(0, math.rad(rot), 0),
			stone,
			Enum.Material.Slate
		)
	end
	local ember = part(
		parent,
		Vector3.new(1, 1, 1),
		base + Vector3.new(0, height + 4.5, 0),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	ember.Shape = Enum.PartType.Ball
	glow(ember, Color3.fromRGB(255, 50, 40), 16, 2)
end

-- The finish: a gothic demon gate with horns, fangs and burning eyes, spanning x at `base`.
function Props.demonGate(parent: Instance, base: Vector3, width: number, colour: Color3)
	local stone = Color3.fromRGB(46, 40, 50)
	local red = Color3.fromRGB(255, 35, 35)
	for _, side in { -1, 1 } do
		local foot = base + Vector3.new(side * (width / 2 + 1.5), 0, 0)
		part(parent, Vector3.new(3, 16, 3), foot + Vector3.new(0, 8, 0), stone, Enum.Material.Slate)
		Props.spire(parent, foot + Vector3.new(0, 16, 0), 6)
		-- Curved horn: three wedges sweeping out and up.
		for i = 0, 2 do
			wedge(
				parent,
				Vector3.new(1.4 - i * 0.3, 3, 2),
				CFrame.new(foot + Vector3.new(side * (2 + i * 1.6), 13 + i * 2.4, 0))
					* CFrame.Angles(0, math.rad(side * -90), math.rad(side * -25 * i)),
				Color3.fromRGB(230, 220, 200),
				Enum.Material.Marble
			)
		end
	end
	local brow = part(parent, Vector3.new(width + 6, 4, 2.5), base + Vector3.new(0, 15, 0), stone, Enum.Material.Slate)
	Props.label(brow, "FINISH", colour)
	for _, side in { -1, 1 } do
		local eye =
			part(parent, Vector3.new(2.2, 1, 0.6), base + Vector3.new(side * 3, 17.6, -1.2), red, Enum.Material.Neon)
		eye.CFrame = eye.CFrame * CFrame.Angles(0, 0, math.rad(side * -15))
		glow(eye, red, 20, 3)
	end
	for i = -2, 2 do
		wedge(
			parent,
			Vector3.new(0.8, 1.6, 0.8),
			CFrame.new(base + Vector3.new(i * 2.2, 12.2, -1)) * CFrame.Angles(math.rad(180), 0, 0),
			WHITE,
			Enum.Material.Marble
		)
	end
	local fire = Instance.new("Fire")
	fire.Color = red
	fire.SecondaryColor = Color3.fromRGB(255, 160, 40)
	fire.Size = 6
	fire.Heat = 12
	fire.Parent = brow
end

return Props
