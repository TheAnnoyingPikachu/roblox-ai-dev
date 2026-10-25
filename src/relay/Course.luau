--!strict
-- Relay Rounds geometry: lobby plaza, practice lane, stands and the per-round race course.
-- Built from parts and Roblox materials (GDD F, CLAUDE.md rule 9). No game rules live here:
-- the server reads hazards (attribute Hazard) and the client reads pads (attributes Boost, Launch).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local Course = {}

Course.LEG_LENGTH = 120
Course.COURSE_Y = 30
Course.FALL_Y = Course.COURSE_Y - 10
Course.ZONE_RADIUS = 6
Course.STANDS = Vector3.new(14, 34, 290)

local LANE_GAP = 30
local LANE_WIDTH = 10
local WHITE = Color3.new(1, 1, 1)
local LASER = Color3.fromRGB(255, 40, 60)

Course.TEAM_COLOURS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Lime green"),
	BrickColor.new("New Yeller"),
}

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

-- Track pieces along a 120-stud leg, in leg-local studs: z from/to, sideways offset dx, height rise.
-- Every layout starts with a deck at z 0 and ends with a centred deck reaching z 120, so the
-- spawn point and the handoff pad always have ground.
type Piece = {
	kind: string, -- deck | boost | launch | vanish | laser | sweeper
	from: number,
	to: number,
	width: number?,
	dx: number?,
	rise: number?,
	power: number?, -- boost speed or launch velocity
	phase: number?, -- 0..1 offset for timed hazards and vanishing pads
	spin: number?, -- sweeper degrees per second
}

local LAYOUTS: { { name: string, pieces: { Piece } } } = {
	{
		name = "Zigzag",
		pieces = {
			{ kind = "deck", from = 0, to = 20 },
			{ kind = "deck", from = 26, to = 42, width = 8, dx = -7 },
			{ kind = "deck", from = 48, to = 64, width = 8, dx = 7 },
			{ kind = "deck", from = 70, to = 86, width = 8, dx = -7 },
			{ kind = "deck", from = 92, to = 104, width = 8, dx = 7 },
			{ kind = "deck", from = 108, to = 120 },
		},
	},
	{
		name = "Launch Tower",
		pieces = {
			{ kind = "deck", from = 0, to = 30 },
			{ kind = "launch", from = 25, to = 30, power = 110 },
			{ kind = "deck", from = 40, to = 70, rise = 22 },
			{ kind = "boost", from = 62, to = 70, rise = 22, power = 80 },
			{ kind = "deck", from = 84, to = 120 },
		},
	},
	{
		name = "Boost Gap",
		pieces = {
			{ kind = "deck", from = 0, to = 40 },
			{ kind = "boost", from = 30, to = 40, power = 85 },
			{ kind = "deck", from = 60, to = 80 },
			{ kind = "boost", from = 70, to = 80, power = 85 },
			{ kind = "deck", from = 100, to = 120 },
		},
	},
	{
		name = "Laser Hall",
		pieces = {
			{ kind = "deck", from = 0, to = 120 },
			{ kind = "laser", from = 35, to = 35, phase = 0 },
			{ kind = "laser", from = 65, to = 65, phase = 0.33 },
			{ kind = "laser", from = 95, to = 95, phase = 0.66 },
		},
	},
	{
		name = "Vanishing Steps",
		pieces = {
			{ kind = "deck", from = 0, to = 12 },
			{ kind = "vanish", from = 18, to = 24, width = 6, dx = -4, phase = 0 },
			{ kind = "vanish", from = 30, to = 36, width = 6, dx = 4, phase = 0.5 },
			{ kind = "vanish", from = 42, to = 48, width = 6, dx = -4, phase = 0 },
			{ kind = "vanish", from = 54, to = 60, width = 6, dx = 4, phase = 0.5 },
			{ kind = "vanish", from = 66, to = 72, width = 6, dx = -4, phase = 0 },
			{ kind = "vanish", from = 78, to = 84, width = 6, dx = 4, phase = 0.5 },
			{ kind = "vanish", from = 90, to = 96, width = 6, dx = -4, phase = 0 },
			{ kind = "deck", from = 102, to = 120 },
		},
	},
	{
		name = "Sweeper Beam",
		pieces = {
			{ kind = "deck", from = 0, to = 15 },
			{ kind = "deck", from = 15, to = 105, width = 3 },
			{ kind = "sweeper", from = 40, to = 40, width = 14, spin = 120 },
			{ kind = "sweeper", from = 75, to = 75, width = 14, spin = -150 },
			{ kind = "deck", from = 105, to = 120 },
		},
	},
}
Course.LAYOUT_NAMES = {}
for i, layout in LAYOUTS do
	Course.LAYOUT_NAMES[i] = layout.name
end

-- The same layouts for every team, so lanes are fair. Changes each round; round 1 opens easy.
function Course.layoutsFor(round: number, legs: number): { number }
	local rng = Random.new(round * 7919)
	local picks = {}
	for k = 1, legs do
		picks[k] = if round == 1 and k == 1 then 1 else rng:NextInteger(1, #LAYOUTS)
	end
	return picks
end

local VANISH_CYCLE = 3 -- seconds; solid for the first two thirds
local LASER_CYCLE = 2.4 -- seconds; live for the first 1.4

-- A wooden deck with team trim, under-slab and cobblestone supports down to the ground.
local function deck(parent: Instance, cf: CFrame, length: number, width: number, colour: Color3, groundY: number?): Part
	local top = part(
		parent,
		Vector3.new(width, 1, length),
		cf * CFrame.new(0, -0.5, 0),
		colour:Lerp(Color3.fromRGB(160, 120, 80), 0.55),
		Enum.Material.WoodPlanks
	)
	for _, side in { -1, 1 } do
		local trim =
			part(parent, Vector3.new(0.5, 0.5, length), cf * CFrame.new(side * (width / 2 - 0.25), 0.25, 0), colour)
		trim.CanCollide = false
	end
	part(
		parent,
		Vector3.new(width - 1, 0.6, length - 0.6),
		cf * CFrame.new(0, -1.3, 0),
		Color3.fromRGB(70, 66, 76),
		Enum.Material.Slate
	)
	if groundY then
		local spacing = math.max(length / 2, 8)
		local z = -length / 2 + 1.5
		while z <= length / 2 - 1.4 do
			local at = (cf * CFrame.new(0, 0, z)).Position
			if at.Y - 1.6 - groundY < 1 then
				break
			end
			pillar(
				parent,
				Vector3.new(at.X, groundY, at.Z),
				at.Y - 1.6 - groundY,
				math.min(width / 4, 1.1),
				Color3.fromRGB(120, 116, 124),
				Enum.Material.Cobblestone
			)
			z += spacing
		end
	end
	return top
end

local function chevrons(pad: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = pad
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.Text = "^^^"
	l.Rotation = 180
	l.Parent = gui
end

type Animated = { part: BasePart, kind: string, phase: number, spin: number, base: CFrame }

-- Builds one leg along `origin`'s local +Z. Returns pieces that need animating each frame.
local function buildLeg(
	parent: Instance,
	origin: CFrame,
	layout: number,
	colour: Color3,
	groundY: number?
): { Animated }
	local animated: { Animated } = {}
	for _, piece in LAYOUTS[layout].pieces do
		local width = piece.width or LANE_WIDTH
		local length = math.max(piece.to - piece.from, 0.5)
		local cf = origin * CFrame.new(piece.dx or 0, piece.rise or 0, (piece.from + piece.to) / 2)
		if piece.kind == "deck" then
			deck(parent, cf, length, width, colour, groundY)
		elseif piece.kind == "boost" then
			local pad = part(
				parent,
				Vector3.new(width - 1, 0.2, length),
				cf * CFrame.new(0, 0.1, 0),
				Color3.fromRGB(0, 230, 255),
				Enum.Material.Neon
			)
			pad.CanCollide = false
			pad:SetAttribute("Boost", piece.power)
			chevrons(pad)
		elseif piece.kind == "launch" then
			local pad = part(
				parent,
				Vector3.new(width - 1, 0.3, length),
				cf * CFrame.new(0, 0.15, 0),
				Color3.fromRGB(255, 140, 0),
				Enum.Material.Neon
			)
			pad.CanCollide = false
			pad:SetAttribute("Launch", piece.power)
			local ring = part(
				parent,
				Vector3.new(0.4, width - 2, width - 2),
				cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(255, 220, 120),
				Enum.Material.Neon
			)
			ring.Shape = Enum.PartType.Cylinder
			ring.Transparency = 0.5
			ring.CanCollide = false
		elseif piece.kind == "vanish" then
			local top = deck(parent, cf, length, width, colour, nil)
			top.Color = Color3.fromRGB(200, 170, 255)
			top.Material = Enum.Material.Glass
			table.insert(
				animated,
				{ part = top, kind = "vanish", phase = piece.phase or 0, spin = 0, base = top.CFrame }
			)
		elseif piece.kind == "laser" then
			for _, side in { -1, 1 } do
				part(
					parent,
					Vector3.new(1, 7, 1),
					cf * CFrame.new(side * (width / 2 + 0.5), 3.5, 0),
					Color3.fromRGB(40, 36, 44),
					Enum.Material.Metal
				)
			end
			local beam = part(parent, Vector3.new(width, 6, 0.4), cf * CFrame.new(0, 3, 0), LASER, Enum.Material.Neon)
			beam.CanCollide = false
			beam:SetAttribute("Hazard", true)
			table.insert(
				animated,
				{ part = beam, kind = "laser", phase = piece.phase or 0, spin = 0, base = beam.CFrame }
			)
		elseif piece.kind == "sweeper" then
			local hub = part(
				parent,
				Vector3.new(1.6, 3, 1.6),
				cf * CFrame.new(0, 1.5, 0),
				Color3.fromRGB(40, 36, 44),
				Enum.Material.Metal
			)
			hub.CanCollide = false
			local bar =
				part(parent, Vector3.new(width, 0.8, 0.8), cf * CFrame.new(0, 2.6, 0), LASER, Enum.Material.Neon)
			bar.CanCollide = false
			bar:SetAttribute("Hazard", true)
			table.insert(
				animated,
				{ part = bar, kind = "sweeper", phase = 0, spin = piece.spin or 120, base = bar.CFrame }
			)
		end
	end
	return animated
end

-- One Heartbeat loop per built folder; it stops when the folder is destroyed.
local function animate(folder: Instance, animated: { Animated })
	if #animated == 0 then
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if folder.Parent == nil then
			connection:Disconnect()
			return
		end
		local t = os.clock() - started
		for _, a in animated do
			if a.kind == "vanish" then
				local solid = ((t / VANISH_CYCLE + a.phase) % 1) < 0.66
				a.part.CanCollide = solid
				a.part.Transparency = if solid then 0.2 else 0.85
			elseif a.kind == "laser" then
				local live = ((t / LASER_CYCLE + a.phase) % 1) < 0.58
				a.part:SetAttribute("Active", live)
				a.part.Transparency = if live then 0.1 else 0.92
			elseif a.kind == "sweeper" then
				a.part.CFrame = a.base * CFrame.Angles(0, math.rad(t * a.spin), 0)
			end
		end
	end)
end

local function lanternPost(parent: Instance, at: Vector3, groundY: number)
	pillar(
		parent,
		Vector3.new(at.X, groundY, at.Z),
		at.Y - groundY,
		0.9,
		Color3.fromRGB(120, 116, 124),
		Enum.Material.Cobblestone
	)
	Props.lantern(parent, at)
end

function Course.build(teamIds: { number }, legs: number, round: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "RelayCourse"
	local picks = Course.layoutsFor(round, legs)
	local animated: { Animated } = {}
	local y = Course.COURSE_Y
	for _, teamId in teamIds do
		local x = Course.laneX(teamId)
		local colour = Course.TEAM_COLOURS[teamId].Color
		for k = 1, legs do
			for _, a in buildLeg(folder, CFrame.new(x, y, Course.legStart(k)), picks[k], colour, -2) do
				table.insert(animated, a)
			end
			local pad = part(
				folder,
				Vector3.new(LANE_WIDTH - 1, 0.2, 7),
				Course.zoneCentre(teamId, k) + Vector3.new(0, 0.1, 0),
				colour,
				Enum.Material.Neon
			)
			pad.CanCollide = false
			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(colour, WHITE)
			emitter.LightEmission = 0.8
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			emitter.Transparency = NumberSequence.new(0.2, 1)
			emitter.Lifetime = NumberRange.new(1, 1.8)
			emitter.Speed = NumberRange.new(3, 6)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Rate = if k == legs then 30 else 10
			emitter.Parent = pad
			if k == legs then
				Props.demonGate(folder, Course.zoneCentre(teamId, k) + Vector3.new(0, 0, 4), LANE_WIDTH + 2, colour)
			else
				Props.torii(
					folder,
					Vector3.new(x, y, Course.legStart(k + 1)),
					LANE_WIDTH + 2,
					11,
					colour,
					Course.LAYOUT_NAMES[picks[k + 1]]
				)
			end
			lanternPost(folder, Vector3.new(x - LANE_GAP / 2, y - 6, Course.legStart(k) + 60), -2)
		end
		Props.torii(folder, Vector3.new(x, y, Course.legStart(1)), LANE_WIDTH + 2, 12, colour, `TEAM {teamId}`)
	end
	folder.Parent = Workspace
	animate(folder, animated)
	return folder
end

-- Built once at server start: plaza, title gate, lanterns, benches, practice lane and stands.
function Course.buildLobby()
	local folder = Instance.new("Folder")
	folder.Name = "RelayLobby"
	local plaza =
		pillar(folder, Vector3.new(0, -0.2, 0), 0.6, 30, Color3.fromRGB(214, 200, 170), Enum.Material.Pavement)
	plaza.Name = "Plaza"
	pillar(folder, Vector3.new(0, -0.3, 0), 0.6, 32, Color3.fromRGB(150, 100, 80), Enum.Material.Brick)

	Props.torii(folder, Vector3.new(0, 0, -24), 20, 15, Color3.fromRGB(196, 40, 28), nil)
	local title =
		part(folder, Vector3.new(24, 4, 1), Vector3.new(0, 11.5, -24), Color3.fromRGB(30, 26, 34), Enum.Material.Slate)
	label(title, "RELAY ROUNDS", Color3.fromRGB(255, 200, 80))
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		Props.lantern(folder, Vector3.new(math.cos(angle) * 26, 0, math.sin(angle) * 26))
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

	-- Practice lane: three layouts at ground level heading west, so falls just land on grass.
	local practice = CFrame.new(-40, 1, -8) * CFrame.Angles(0, math.rad(-90), 0)
	local blue = Color3.fromRGB(110, 170, 230)
	Props.torii(folder, Vector3.new(-40, 1, -8), LANE_WIDTH + 4, 11, blue, "PRACTICE")
	local animated: { Animated } = {}
	for i, layout in { 2, 3, 5 } do
		for _, a in buildLeg(folder, practice * CFrame.new(0, 0, (i - 1) * Course.LEG_LENGTH), layout, blue, 0) do
			table.insert(animated, a)
		end
	end

	-- Stands: tiered seating beside the course, under a crimson roof between gothic spires.
	local s = Course.STANDS
	local rows = 4
	for row = 0, rows - 1 do
		local top = s.Y - 6 + row * 2.5
		part(
			folder,
			Vector3.new(5, top + 2, 70),
			Vector3.new(s.X - row * 5, top / 2 - 1, s.Z),
			Color3.fromRGB(70, 64, 74),
			Enum.Material.Slate
		)
		for seat = -6, 6 do
			local colour = Course.TEAM_COLOURS[(seat + row) % 4 + 1].Color
			part(folder, Vector3.new(2, 1, 3.6), Vector3.new(s.X - row * 5 - 1, top + 0.5, s.Z + seat * 5), colour)
		end
	end
	for _, z in { s.Z - 34, s.Z + 34 } do
		Props.spire(folder, Vector3.new(s.X + 2, 0, z), s.Y + 8)
		Props.spire(folder, Vector3.new(s.X - rows * 5, 0, z), s.Y + 8)
	end
	local roof = part(
		folder,
		Vector3.new(rows * 5 + 6, 0.6, 72),
		Vector3.new(s.X - rows * 2.5 + 1, s.Y + 10.3, s.Z),
		Color3.fromRGB(150, 30, 30),
		Enum.Material.Fabric
	)
	roof.Transparency = 0.1
	local board =
		part(folder, Vector3.new(28, 4, 1), Vector3.new(s.X - rows * 5 - 2, s.Y + 7, s.Z), Color3.fromRGB(30, 26, 34))
	board.CFrame = board.CFrame * CFrame.Angles(0, math.rad(90), 0)
	label(board, "THE STANDS")
	folder.Parent = Workspace
	animate(folder, animated)
end

return Course
