--!strict
-- Relay Rounds geometry: lobby plaza, practice lane, stands and the per-round race course.
-- Primitive parts and Roblox materials only (GDD F, CLAUDE.md rule 9). No game rules live here.

local Workspace = game:GetService("Workspace")

local Course = {}

Course.LEG_LENGTH = 60
Course.COURSE_Y = 30
Course.FALL_Y = Course.COURSE_Y - 10
Course.ZONE_RADIUS = 6
Course.STANDS = Vector3.new(16, 34, 150)

local LANE_GAP = 20
local LANE_WIDTH = 10
local WHITE = Color3.new(1, 1, 1)

Course.TEAM_COLOURS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Lime green"),
	BrickColor.new("New Yeller"),
}

local function part(
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

-- A vertical cylinder standing on `base`.
local function pillar(
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

local function label(board: BasePart, text: string, colour: Color3)
	-- Text on both faces, so the board reads from either side.
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
		l.TextColor3 = colour
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.Text = text
		l.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(30, 30, 40)
		stroke.Parent = l
	end
end

-- Two posts and a lintel with text, spanning `width` across x at `centre`.
local function arch(parent: Instance, centre: Vector3, width: number, height: number, colour: Color3, text: string?)
	for _, side in { -1, 1 } do
		pillar(
			parent,
			centre + Vector3.new(side * width / 2, 0, 0),
			height,
			0.9,
			Color3.fromRGB(235, 235, 240),
			Enum.Material.Marble
		)
		local cap = part(
			parent,
			Vector3.new(2.6, 0.8, 2.6),
			centre + Vector3.new(side * width / 2, height + 0.4, 0),
			colour,
			Enum.Material.Neon
		)
		cap.CanCollide = false
	end
	local beam = part(parent, Vector3.new(width + 3, 3, 1.2), centre + Vector3.new(0, height + 1.5, 0), colour)
	if text then
		label(beam, text, WHITE)
	end
	return beam
end

local function lamp(parent: Instance, base: Vector3)
	pillar(parent, base, 11, 0.35, Color3.fromRGB(45, 45, 52), Enum.Material.Metal)
	local bulb = part(
		parent,
		Vector3.new(1.8, 1.8, 1.8),
		base + Vector3.new(0, 11.6, 0),
		Color3.fromRGB(255, 235, 180),
		Enum.Material.Neon
	)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Parent = bulb
end

local function flag(parent: Instance, base: Vector3, colour: Color3)
	pillar(parent, base, 14, 0.2, Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	local cloth = part(parent, Vector3.new(0.2, 3, 5), base + Vector3.new(0, 12.3, 2.6), colour, Enum.Material.Fabric)
	cloth.CanCollide = false
end

local function sparkles(pad: BasePart, colour: Color3, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(colour, WHITE)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = rate
	emitter.Parent = pad
end

function Course.laneX(teamId: number): number
	return 40 + (teamId - 1) * LANE_GAP
end

-- Leg k runs from z = legStart(k) to legStart(k + 1); handoff pad k sits at the end of leg k.
function Course.legStart(k: number): number
	return 50 + (k - 1) * Course.LEG_LENGTH
end

function Course.zoneCentre(teamId: number, k: number): Vector3
	return Vector3.new(Course.laneX(teamId), Course.COURSE_Y, Course.legStart(k + 1) - 4)
end

function Course.legSpawn(teamId: number, k: number): Vector3
	return Vector3.new(Course.laneX(teamId), Course.COURSE_Y, Course.legStart(k) + 3)
end

-- Obstacle layouts, as segments along a 60-stud leg. Each is { from, to, width, rise }.
-- The last segment always ends at the leg end so the handoff pad has ground under it.
local LAYOUTS: { { { number } } } = {
	{ { 0, 22, LANE_WIDTH, 0 }, { 26, 40, LANE_WIDTH, 0 }, { 44, 60, LANE_WIDTH, 0 } }, -- gaps
	{ { 0, 12, LANE_WIDTH, 0 }, { 12, 48, 3, 0 }, { 48, 60, LANE_WIDTH, 0 } }, -- balance beam
	{
		{ 0, 8, LANE_WIDTH, 0 },
		{ 12, 18, 6, 2 },
		{ 22, 28, 6, 4 },
		{ 32, 38, 6, 2 },
		{ 42, 48, 6, 0 },
		{ 50, 60, LANE_WIDTH, 0 },
	}, -- steps
	{ { 0, 14, LANE_WIDTH, 0 }, { 18, 30, 4, 0 }, { 34, 46, 4, 0 }, { 50, 60, LANE_WIDTH, 0 } }, -- narrow gaps
}

-- The same layouts for every team, so lanes are fair. Changes each round.
function Course.layoutsFor(round: number, legs: number): { number }
	local rng = Random.new(round * 7919)
	local picks = {}
	for k = 1, legs do
		picks[k] = if round == 1 and k == 1 then 1 else rng:NextInteger(1, #LAYOUTS)
	end
	return picks
end

-- A wooden deck with team-coloured trim, standing on stone pillars down to the ground.
local function deck(parent: Instance, x: number, y: number, zFrom: number, zTo: number, width: number, colour: Color3)
	local length = zTo - zFrom
	local zMid = (zFrom + zTo) / 2
	part(
		parent,
		Vector3.new(width, 1, length),
		Vector3.new(x, y - 0.5, zMid),
		colour:Lerp(Color3.fromRGB(160, 120, 80), 0.55),
		Enum.Material.WoodPlanks
	)
	for _, side in { -1, 1 } do
		local trim = part(
			parent,
			Vector3.new(0.5, 0.5, length),
			Vector3.new(x + side * (width / 2 - 0.25), y + 0.25, zMid),
			colour
		)
		trim.CanCollide = false
	end
	part(
		parent,
		Vector3.new(width - 1, 0.6, length - 0.6),
		Vector3.new(x, y - 1.3, zMid),
		Color3.fromRGB(90, 90, 98),
		Enum.Material.Slate
	)
	local spacing = math.max(length / 2, 6)
	local z = zFrom + 1.5
	while z <= zTo - 1.4 do
		pillar(
			parent,
			Vector3.new(x, -2, z),
			y + 0.4,
			math.min(width / 4, 1.1),
			Color3.fromRGB(150, 150, 158),
			Enum.Material.Cobblestone
		)
		z += spacing
	end
end

function Course.build(teamIds: { number }, legs: number, round: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "RelayCourse"
	local picks = Course.layoutsFor(round, legs)
	local y = Course.COURSE_Y
	for _, teamId in teamIds do
		local x = Course.laneX(teamId)
		local colour = Course.TEAM_COLOURS[teamId].Color
		for k = 1, legs do
			local z = Course.legStart(k)
			for _, seg in LAYOUTS[picks[k]] do
				deck(folder, x, y + seg[4], z + seg[1], z + seg[2], seg[3], colour)
			end
			local pad = part(
				folder,
				Vector3.new(LANE_WIDTH - 1, 0.2, 7),
				Course.zoneCentre(teamId, k) + Vector3.new(0, 0.1, 0),
				colour,
				Enum.Material.Neon
			)
			pad.CanCollide = false
			sparkles(pad, colour, if k == legs then 30 else 8)
			if k == legs then
				arch(folder, Course.zoneCentre(teamId, k) + Vector3.new(0, 0, 3), LANE_WIDTH + 2, 12, colour, "FINISH")
			else
				arch(folder, Vector3.new(x, y, Course.legStart(k + 1)), LANE_WIDTH + 2, 9, colour, `LEG {k + 1}`)
			end
		end
		arch(folder, Vector3.new(x, y, Course.legStart(1)), LANE_WIDTH + 2, 10, colour, `TEAM {teamId}`)
		flag(folder, Vector3.new(x - LANE_WIDTH / 2 - 2, y, Course.legStart(1) + 8), colour)
	end
	folder.Parent = Workspace
	return folder
end

-- A low practice lane with every layout once, so falls only drop you onto the grass.
local function practiceLane(parent: Instance)
	local colour = Color3.fromRGB(110, 170, 230)
	arch(parent, Vector3.new(-30, 0, -26), LANE_WIDTH + 2, 9, colour, "PRACTICE")
	for i, layout in LAYOUTS do
		local z0 = -30 - (i - 1) * Course.LEG_LENGTH
		for _, seg in layout do
			local from, to = z0 - seg[2], z0 - seg[1]
			local length = to - from
			part(
				parent,
				Vector3.new(seg[3], 1 + seg[4], length),
				Vector3.new(-30, 0.5 + seg[4] / 2, (from + to) / 2),
				colour:Lerp(Color3.fromRGB(160, 120, 80), 0.5),
				Enum.Material.WoodPlanks
			)
		end
	end
end

-- Covered tiered seating beside the course for eliminated teams.
local function stands(parent: Instance)
	local s = Course.STANDS
	local rows = 4
	for row = 0, rows - 1 do
		local top = s.Y - 6 + row * 2.5
		part(
			parent,
			Vector3.new(5, top + 2, 70),
			Vector3.new(s.X - row * 5, top / 2 - 1, s.Z),
			Color3.fromRGB(120, 120, 128),
			Enum.Material.Concrete
		)
		for seat = -6, 6 do
			local colour = Course.TEAM_COLOURS[(seat + row) % 4 + 1].Color
			part(parent, Vector3.new(2, 1, 3.6), Vector3.new(s.X - row * 5 - 1, top + 0.5, s.Z + seat * 5), colour)
		end
	end
	for _, z in { s.Z - 34, s.Z + 34 } do
		pillar(parent, Vector3.new(s.X + 2, 0, z), s.Y + 10, 0.8, Color3.fromRGB(230, 230, 235), Enum.Material.Metal)
		pillar(
			parent,
			Vector3.new(s.X - rows * 5, 0, z),
			s.Y + 10,
			0.8,
			Color3.fromRGB(230, 230, 235),
			Enum.Material.Metal
		)
	end
	local roof = part(
		parent,
		Vector3.new(rows * 5 + 6, 0.6, 72),
		Vector3.new(s.X - rows * 2.5 + 1, s.Y + 10.3, s.Z),
		Color3.fromRGB(240, 240, 245),
		Enum.Material.Fabric
	)
	roof.Transparency = 0.15
	local board =
		part(parent, Vector3.new(28, 4, 1), Vector3.new(s.X - rows * 5 - 2, s.Y + 7, s.Z), Color3.fromRGB(35, 35, 45))
	board.CFrame = board.CFrame * CFrame.Angles(0, math.rad(90), 0)
	label(board, "THE STANDS", WHITE)
end

-- Built once at server start: plaza, title arch, lamps, benches, flags, practice lane and stands.
function Course.buildLobby()
	local folder = Instance.new("Folder")
	folder.Name = "RelayLobby"
	local plaza =
		pillar(folder, Vector3.new(0, -0.2, 0), 0.6, 30, Color3.fromRGB(214, 200, 170), Enum.Material.Pavement)
	plaza.Name = "Plaza"
	pillar(folder, Vector3.new(0, -0.3, 0), 0.6, 32, Color3.fromRGB(150, 100, 80), Enum.Material.Brick)

	local title = arch(folder, Vector3.new(0, 0, -24), 26, 14, Color3.fromRGB(255, 170, 40), nil)
	title.Size = Vector3.new(30, 6, 1.5)
	title.Position = Vector3.new(0, 17, -24)
	label(title, "RELAY ROUNDS", WHITE)

	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		lamp(folder, Vector3.new(math.cos(angle) * 27, 0, math.sin(angle) * 27))
	end
	for i, colour in Course.TEAM_COLOURS do
		local angle = math.rad(i * 90)
		flag(folder, Vector3.new(math.cos(angle) * 22, 0, math.sin(angle) * 22), colour.Color)
	end
	for _, spot in
		{ Vector3.new(-14, 0, 12), Vector3.new(14, 0, 12), Vector3.new(-14, 0, -12), Vector3.new(14, 0, -12) }
	do
		part(
			folder,
			Vector3.new(6, 0.5, 2),
			spot + Vector3.new(0, 1.6, 0),
			Color3.fromRGB(140, 95, 60),
			Enum.Material.WoodPlanks
		)
		for _, side in { -1, 1 } do
			part(
				folder,
				Vector3.new(0.4, 1.4, 1.6),
				spot + Vector3.new(side * 2.6, 0.7, 0),
				Color3.fromRGB(45, 45, 52),
				Enum.Material.Metal
			)
		end
	end
	practiceLane(folder)
	stands(folder)
	folder.Parent = Workspace
end

return Course
