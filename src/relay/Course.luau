--!strict
-- Relay Rounds circuit: one shared ground-level race track that every team runs. The lap is split
-- into one sector per leg; each team has a coloured handoff box at every sector line.
-- Built from parts and Roblox materials (GDD F, CLAUDE.md rule 9). No game rules live here:
-- the server reads hazards (attribute Hazard) and the client reads pads (attributes Boost, Launch).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar, label = Props.part, Props.pillar, Props.label

local Course = {}

Course.TRACK_WIDTH = 32
Course.ROAD_Y = 0.4 -- top of the road surface
Course.FALL_Y = -20
Course.ZONE_RADIUS = 4.5
Course.STANDS = Vector3.new(90, 14, -184)
Course.LOBBY = Vector3.new(70, 0, -10)

local WHITE = Color3.new(1, 1, 1)
local LASER = Color3.fromRGB(255, 40, 60)
local LAVA = Color3.fromRGB(255, 90, 20)
local ASPHALT = Color3.fromRGB(58, 56, 62)
local UP = Vector3.yAxis

Course.TEAM_COLOURS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Lime green"),
	BrickColor.new("New Yeller"),
}

-- The circuit centre line, driven in order and closed back to the first point.
local WAYPOINTS = {
	Vector3.new(-40, 0, -140),
	Vector3.new(200, 0, -140), -- main straight past the grandstand
	Vector3.new(260, 0, -90),
	Vector3.new(260, 0, 40),
	Vector3.new(200, 0, 100),
	Vector3.new(110, 0, 100),
	Vector3.new(60, 0, 140), -- chicane
	Vector3.new(-60, 0, 140),
	Vector3.new(-120, 0, 80),
	Vector3.new(-120, 0, -80),
}
local START_OFFSET = 40 -- the start line sits this far along the main straight

type Segment = { a: Vector3, b: Vector3, dir: Vector3, length: number, from: number }
local segments: { Segment } = {}
local rawLength = 0
for i, a in WAYPOINTS do
	local b = WAYPOINTS[i % #WAYPOINTS + 1]
	local length = (b - a).Magnitude
	table.insert(segments, { a = a, b = b, dir = (b - a).Unit, length = length, from = rawLength })
	rawLength += length
end
Course.LAP_LENGTH = rawLength

-- Position and heading at `s` studs along the lap, measured from the start line.
local function along(s: number): (Vector3, Vector3)
	local raw = (s + START_OFFSET) % rawLength
	for _, seg in segments do
		if raw <= seg.from + seg.length then
			return seg.a + seg.dir * (raw - seg.from), seg.dir
		end
	end
	return segments[1].a, segments[1].dir
end

-- The point between s0 and s1 that sits deepest inside one straight, for placing obstacles.
local function bestStraight(s0: number, s1: number): number
	local best, bestRoom = (s0 + s1) / 2, -1
	for s = s0 + 10, s1 - 10, 4 do
		local raw = (s + START_OFFSET) % rawLength
		for _, seg in segments do
			if raw >= seg.from and raw <= seg.from + seg.length then
				local room = math.min(raw - seg.from, seg.from + seg.length - raw)
				if room > bestRoom then
					best, bestRoom = s, room
				end
				break
			end
		end
	end
	return best
end

-- A frame at `s` whose local +Z points along the track (so forward is -LookVector), Y up.
local function frameAt(s: number, lateral: number, height: number): CFrame
	local pos, dir = along(s)
	local side = UP:Cross(dir)
	return CFrame.fromMatrix(pos + side * lateral + Vector3.new(0, height, 0), side, UP, dir)
end

-- How far along the lap (from the start line) the point nearest to `position` lies.
function Course.progress(position: Vector3): number
	local flat = Vector3.new(position.X, 0, position.Z)
	local best, bestDist = 0, math.huge
	for _, seg in segments do
		local t = math.clamp((flat - seg.a):Dot(seg.dir), 0, seg.length)
		local dist = (seg.a + seg.dir * t - flat).Magnitude
		if dist < bestDist then
			best, bestDist = seg.from + t, dist
		end
	end
	return (best - START_OFFSET) % rawLength
end

function Course.sectorLength(legs: number): number
	return rawLength / legs
end

local function laneOffset(teamId: number): number
	return (teamId - 2.5) * 7
end

-- Leg k runs from sector line k-1 to sector line k (line 0 is the start/finish).
function Course.zoneCentre(teamId: number, k: number, legs: number): Vector3
	return frameAt(k * Course.sectorLength(legs) - 5, laneOffset(teamId), Course.ROAD_Y).Position
end

function Course.legSpawn(teamId: number, k: number, legs: number): Vector3
	return frameAt((k - 1) * Course.sectorLength(legs) + 3, laneOffset(teamId), Course.ROAD_Y).Position
end

-- Where a runner starts leg k, facing along the track.
function Course.spawnFrame(teamId: number, k: number, legs: number): CFrame
	local f = frameAt((k - 1) * Course.sectorLength(legs) + 3, laneOffset(teamId), Course.ROAD_Y)
	return CFrame.lookAt(f.Position, f.Position + f.ZVector)
end

-- Studs of track left before the runner's handoff line.
function Course.distanceLeft(position: Vector3, k: number, legs: number): number
	return (k * Course.sectorLength(legs) - Course.progress(position)) % rawLength
end

-- Static track ----------------------------------------------------------------------------------

local function flatAlong(at: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(at, at + dir)
end

local function wallAlong(parent: Instance, seg: Segment, side: number)
	local offset = UP:Cross(seg.dir) * side * (Course.TRACK_WIDTH / 2 + 1)
	local mid = (seg.a + seg.b) / 2 + offset + Vector3.new(0, 1.5, 0)
	local wall = part(parent, Vector3.new(1, 3, seg.length), flatAlong(mid, seg.dir), WHITE, Enum.Material.Concrete)
	wall.Name = "Barrier"
	-- Red and white kerb blocks along the road edge.
	for i = 0, math.floor(seg.length / 6) - 1 do
		local at = seg.a
			+ seg.dir * (i * 6 + 3)
			+ UP:Cross(seg.dir) * side * (Course.TRACK_WIDTH / 2 - 1.2)
			+ Vector3.new(0, Course.ROAD_Y + 0.05, 0)
		local kerb = part(
			parent,
			Vector3.new(2.4, 0.3, 6),
			flatAlong(at, seg.dir),
			if i % 2 == 0 then Color3.fromRGB(220, 30, 30) else WHITE
		)
		kerb.CanCollide = false
	end
end

-- Road, corner discs, barriers, kerbs, start line and grandstand. Built once at server start.
function Course.buildTrack()
	local folder = Instance.new("Folder")
	folder.Name = "RelayTrack"
	for _, seg in segments do
		local mid = (seg.a + seg.b) / 2
		part(
			folder,
			Vector3.new(Course.TRACK_WIDTH, 0.8, seg.length),
			flatAlong(mid, seg.dir),
			ASPHALT,
			Enum.Material.Asphalt
		)
		for d = 4, seg.length - 4, 12 do
			local dash = part(
				folder,
				Vector3.new(0.5, 0.05, 6),
				flatAlong(seg.a + seg.dir * d + Vector3.new(0, Course.ROAD_Y + 0.02, 0), seg.dir),
				Color3.fromRGB(235, 235, 235)
			)
			dash.CanCollide = false
		end
		wallAlong(folder, seg, 1)
		wallAlong(folder, seg, -1)
	end
	for _, w in WAYPOINTS do
		pillar(folder, w - Vector3.new(0, 0.4, 0), 0.8, Course.TRACK_WIDTH / 2, ASPHALT, Enum.Material.Asphalt)
	end

	-- Chequered start/finish line.
	for row = 0, 1 do
		for col = 0, 7 do
			local square = part(
				folder,
				Vector3.new(Course.TRACK_WIDTH / 8, 0.06, 2),
				frameAt(-1 + row * 2, (col - 3.5) * Course.TRACK_WIDTH / 8, Course.ROAD_Y + 0.03),
				if (row + col) % 2 == 0 then WHITE else Color3.fromRGB(20, 20, 24)
			)
			square.CanCollide = false
		end
	end

	-- Komainu guardians either side of the start/finish line.
	for _, side in { -1, 1 } do
		local at = frameAt(0, side * (Course.TRACK_WIDTH / 2 + 5), 0).Position
		Models.spawn("komainu", folder, at, 1.1, if side < 0 then 0 else 180)
	end

	-- Grandstand facing the main straight.
	local s = Course.STANDS
	for row = 0, 5 do
		local top = 1 + row * 2
		part(
			folder,
			Vector3.new(140, top + 1, 5),
			Vector3.new(s.X, top / 2, s.Z - row * 5),
			Color3.fromRGB(70, 64, 74),
			Enum.Material.Slate
		)
		for seat = -13, 13 do
			local colour = Course.TEAM_COLOURS[(seat + row) % 4 + 1].Color
			part(folder, Vector3.new(3.6, 1, 2), Vector3.new(s.X + seat * 5, top + 0.5, s.Z - row * 5 - 1), colour)
		end
	end
	for _, x in { s.X - 72, s.X + 72 } do
		Props.spire(folder, Vector3.new(x, 0, s.Z - 12), 22)
	end
	local roof = part(
		folder,
		Vector3.new(146, 0.6, 34),
		Vector3.new(s.X, 20, s.Z - 13),
		Color3.fromRGB(150, 30, 30),
		Enum.Material.Fabric
	)
	roof.Transparency = 0.1
	local board = part(
		folder,
		Vector3.new(60, 6, 1),
		Vector3.new(s.X, 24, s.Z - 2),
		Color3.fromRGB(30, 26, 34),
		Enum.Material.Slate
	)
	label(board, "RELAY ROUNDS GRAND PRIX", Color3.fromRGB(255, 200, 80))
	folder.Parent = Workspace
end

local PODIUM = {
	{ offset = Vector3.new(0, 0, 14), height = 4, colour = Color3.fromRGB(255, 200, 60) },
	{ offset = Vector3.new(6.5, 0, 14), height = 2.8, colour = Color3.fromRGB(200, 205, 215) },
	{ offset = Vector3.new(-6.5, 0, 14), height = 1.8, colour = Color3.fromRGB(205, 130, 70) },
}
local confetti: Part? = nil
local boardText: TextLabel? = nil

-- Infield lobby: plaza, title torii, lanterns, benches, podium, leaderboard and statues.
function Course.buildLobby()
	local folder = Instance.new("Folder")
	folder.Name = "RelayLobby"
	local c = Course.LOBBY
	local plaza =
		pillar(folder, c + Vector3.new(0, -0.2, 0), 0.6, 30, Color3.fromRGB(214, 200, 170), Enum.Material.Pavement)
	plaza.Name = "Plaza"
	pillar(folder, c + Vector3.new(0, -0.3, 0), 0.6, 32, Color3.fromRGB(150, 100, 80), Enum.Material.Brick)
	Props.torii(folder, c + Vector3.new(0, 0, -24), 20, 15, Color3.fromRGB(196, 40, 28), nil)
	local title = part(
		folder,
		Vector3.new(17, 2.4, 0.6),
		c + Vector3.new(0, 13.9, -23.4),
		Color3.fromRGB(30, 26, 34),
		Enum.Material.Slate
	)
	label(title, "RELAY ROUNDS", Color3.fromRGB(255, 200, 80))
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		Props.lantern(folder, c + Vector3.new(math.cos(angle) * 26, 0, math.sin(angle) * 26))
	end
	for _, spot in
		{ Vector3.new(-14, 0, 12), Vector3.new(14, 0, 12), Vector3.new(-14, 0, -12), Vector3.new(14, 0, -12) }
	do
		part(
			folder,
			Vector3.new(6, 0.5, 2),
			c + spot + Vector3.new(0, 1.6, 0),
			Color3.fromRGB(140, 95, 60),
			Enum.Material.WoodPlanks
		)
		for _, side in { -1, 1 } do
			part(
				folder,
				Vector3.new(0.4, 1.4, 1.6),
				c + spot + Vector3.new(side * 2.6, 0.7, 0),
				Color3.fromRGB(45, 45, 52),
				Enum.Material.Metal
			)
		end
	end
	local sign = part(
		folder,
		Vector3.new(30, 3, 0.6),
		c + Vector3.new(0, 4, 29),
		Color3.fromRGB(30, 26, 34),
		Enum.Material.Slate
	)
	label(sign, "Run the circuit to practise between matches!")

	-- Winners' podium: 1st in the middle and highest, the generated trophy behind it.
	for i, step in PODIUM do
		local block = part(
			folder,
			Vector3.new(6, step.height, 6),
			c + step.offset + Vector3.new(0, step.height / 2, 0),
			step.colour,
			Enum.Material.Marble
		)
		block.Name = `Podium{i}`
		local number =
			part(folder, Vector3.new(3, 2, 0.2), c + step.offset + Vector3.new(0, step.height / 2, -3.05), WHITE)
		number.CanCollide = false
		label(number, tostring(i), step.colour)
	end
	pillar(folder, c + Vector3.new(0, 0, 20), 9, 2, Color3.fromRGB(235, 235, 240), Enum.Material.Marble)
	local trophy = Models.spawn("trophy", folder, c + Vector3.new(0, 9, 20), 1.2, 180)
	if trophy then
		trophy.CanCollide = false
	end
	confetti = part(folder, Vector3.new(16, 1, 6), c + Vector3.new(0, 16, 14), WHITE)
	confetti.Transparency = 1
	confetti.CanCollide = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 140)),
	})
	emitter.Size = NumberSequence.new(0.35)
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Rate = 0
	emitter.Parent = confetti

	-- Global wins leaderboard on the east side of the plaza, facing the centre.
	local boardPart =
		part(folder, Vector3.new(1, 16, 20), c + Vector3.new(31, 9, 0), Color3.fromRGB(30, 26, 34), Enum.Material.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = boardPart
	local list = Instance.new("TextLabel")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.TextColor3 = WHITE
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "TOP RACERS\n\nloading…"
	list.Parent = gui
	boardText = list
	for _, z in { -11, 11 } do
		Props.lantern(folder, c + Vector3.new(31, 0, z))
	end

	-- Generated statues: oni guardians either side of the torii, a pagoda in the infield.
	Models.spawn("oni", folder, c + Vector3.new(-30, 0, -34), 0.7, 180)
	Models.spawn("oni", folder, c + Vector3.new(30, 0, -34), 0.7, 180)
	Models.spawn("pagoda", folder, Vector3.new(185, 0, 30), 1, 200)
	folder.Parent = Workspace
end

-- Where podium place `i` stands (4th and later line up in front).
function Course.podiumSpot(i: number): Vector3
	local c = Course.LOBBY
	local step = PODIUM[i]
	if step then
		return c + step.offset + Vector3.new(0, step.height, 0)
	end
	return c + Vector3.new((i - 5) * 3, 0, 8)
end

-- Five seconds of confetti over the podium.
function Course.celebrate()
	local emitter = confetti and confetti:FindFirstChild("Confetti") :: ParticleEmitter?
	if emitter then
		emitter.Rate = 120
		task.delay(5, function()
			emitter.Rate = 0
		end)
	end
end

function Course.updateBoard(rows: { { name: string, wins: number } })
	if boardText == nil then
		return
	end
	local lines = { "TOP RACERS", "" }
	for i, row in rows do
		table.insert(lines, `{i}. {row.name}  {row.wins}`)
	end
	if #rows == 0 then
		table.insert(lines, "Win a match to get on the board!")
	end
	boardText.Text = table.concat(lines, "\n")
end

-- Per-round obstacles -----------------------------------------------------------------------------

local W = Course.TRACK_WIDTH
type Animated = { part: BasePart, kind: string, phase: number, spin: number, base: CFrame }

local function lava(parent: Instance, cf: CFrame, length: number): Part
	local pit = part(parent, Vector3.new(W, 0.2, length), cf * CFrame.new(0, 0.1, 0), LAVA, Enum.Material.Neon)
	pit.CanCollide = false
	pit:SetAttribute("Hazard", true)
	local fire = Instance.new("ParticleEmitter")
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 40, 0))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(0.8, 0)
	fire.Lifetime = NumberRange.new(0.6, 1.2)
	fire.Speed = NumberRange.new(2, 5)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Rate = 25
	fire.Parent = pit
	return pit
end

local function boostPad(parent: Instance, cf: CFrame, power: number)
	local pad = part(
		parent,
		Vector3.new(6, 0.2, 8),
		cf * CFrame.new(0, 0.12, 0),
		Color3.fromRGB(0, 230, 255),
		Enum.Material.Neon
	)
	pad.CanCollide = false
	pad:SetAttribute("Boost", power)
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

-- Obstacle sets, built across the full track width in a frame whose local +Z runs along the track.
local OBSTACLES: { { name: string, build: (Instance, CFrame, { Animated }) -> () } } = {
	{
		name = "Boost Alley",
		build = function(parent, cf, _)
			for i = -1, 1 do
				for j = 0, 1 do
					boostPad(parent, cf * CFrame.new(i * 10, 0, -20 + j * 40 + i * 6), 70)
				end
			end
		end,
	},
	{
		name = "Lava Leap",
		build = function(parent, cf, _)
			for _, lane in { -12, 0, 12 } do
				boostPad(parent, cf * CFrame.new(lane, 0, -16), 60)
			end
			lava(parent, cf * CFrame.new(0, 0, 4), 18)
		end,
	},
	{
		name = "Laser Gates",
		build = function(parent, cf, animated)
			for i, z in { -18, 2, 22 } do
				for _, side in { -1, 1 } do
					part(
						parent,
						Vector3.new(1.4, 8, 1.4),
						cf * CFrame.new(side * (W / 2 + 1), 4, z),
						Color3.fromRGB(40, 36, 44),
						Enum.Material.Metal
					)
				end
				local beam = part(parent, Vector3.new(W, 6, 0.4), cf * CFrame.new(0, 3.4, z), LASER, Enum.Material.Neon)
				beam.CanCollide = false
				beam:SetAttribute("Hazard", true)
				table.insert(
					animated,
					{ part = beam, kind = "laser", phase = (i - 1) / 3, spin = 0, base = beam.CFrame }
				)
			end
		end,
	},
	{
		name = "Sweepers",
		build = function(parent, cf, animated)
			for i, z in { -14, 14 } do
				local hub = part(
					parent,
					Vector3.new(2, 3.4, 2),
					cf * CFrame.new(0, 1.7, z),
					Color3.fromRGB(40, 36, 44),
					Enum.Material.Metal
				)
				hub.CanCollide = false
				local bar =
					part(parent, Vector3.new(W - 4, 1, 1), cf * CFrame.new(0, 2.8, z), LASER, Enum.Material.Neon)
				bar.CanCollide = false
				bar:SetAttribute("Hazard", true)
				table.insert(
					animated,
					{ part = bar, kind = "sweeper", phase = 0, spin = if i == 1 then 110 else -140, base = bar.CFrame }
				)
			end
		end,
	},
	{
		name = "Hurdles",
		build = function(parent, cf, _)
			-- Each row is a full-width hurdle with one 7-stud gap, alternating sides.
			for i, z in { -20, -6, 8, 22 } do
				local gap = if i % 2 == 0 then 8 else -8
				local left, right = -W / 2, W / 2
				for _, span in { { left, gap - 3.5 }, { gap + 3.5, right } } do
					local width = span[2] - span[1]
					local x = (span[1] + span[2]) / 2
					part(parent, Vector3.new(width, 2.6, 1), cf * CFrame.new(x, 1.3, z), WHITE).Name = "Hurdle"
					local stripe = part(
						parent,
						Vector3.new(width, 0.6, 1.05),
						cf * CFrame.new(x, 2.3, z),
						Color3.fromRGB(220, 30, 30)
					)
					stripe.CanCollide = false
				end
			end
		end,
	},
	{
		name = "Glass Bridge",
		build = function(parent, cf, animated)
			lava(parent, cf, 44)
			for row = 0, 4 do
				for col = -1, 1 do
					local tile = part(
						parent,
						Vector3.new(7, 0.6, 6),
						cf * CFrame.new(col * 10 + (row % 2) * 4 - 2, 0.6, -18 + row * 9),
						Color3.fromRGB(200, 170, 255),
						Enum.Material.Glass
					)
					table.insert(
						animated,
						{ part = tile, kind = "vanish", phase = ((row + col) % 2) * 0.5, spin = 0, base = tile.CFrame }
					)
				end
			end
		end,
	},
}
Course.OBSTACLE_NAMES = {}
for i, o in OBSTACLES do
	Course.OBSTACLE_NAMES[i] = o.name
end

-- The obstacle for each sector this round; round 1 opens with Boost Alley.
function Course.obstaclesFor(round: number, legs: number): { number }
	local rng = Random.new(round * 7919)
	local picks = {}
	for k = 1, legs do
		picks[k] = if round == 1 and k == 1 then 1 else rng:NextInteger(1, #OBSTACLES)
	end
	return picks
end

local VANISH_CYCLE = 3 -- seconds; solid for the first two thirds
local LASER_CYCLE = 2.4 -- seconds; live for the first 1.4

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

-- Gate models are built spanning world X; turn the ones just built to stand across the track.
local function placeAcross(folder: Instance, base: Vector3, dir: Vector3)
	local pivot = CFrame.new(base)
	local turn = pivot * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and not child:GetAttribute("Placed") then
			child.CFrame = turn * pivot:ToObjectSpace(child.CFrame)
			child:SetAttribute("Placed", true)
		end
	end
end

local function markPlaced(folder: Instance)
	for _, child in folder:GetChildren() do
		child:SetAttribute("Placed", true)
	end
end

-- This round's sector gates, handoff boxes and obstacles.
function Course.build(teamIds: { number }, legs: number, round: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "RelayCourse"
	local sector = Course.sectorLength(legs)
	local picks = Course.obstaclesFor(round, legs)
	local animated: { Animated } = {}
	for k = 1, legs do
		local lineS = k * sector
		local base, dir = along(lineS)
		if k == legs then
			Props.demonGate(folder, base, W, Color3.fromRGB(255, 200, 80))
		else
			Props.torii(
				folder,
				base,
				W + 2,
				13,
				Color3.fromRGB(255, 200, 80),
				`SECTOR {k + 1}: {Course.OBSTACLE_NAMES[picks[k + 1]]}`
			)
		end
		placeAcross(folder, base, dir)
		for _, teamId in teamIds do
			local box = part(
				folder,
				Vector3.new(6.5, 0.2, 8),
				frameAt(lineS - 5, laneOffset(teamId), Course.ROAD_Y + 0.08),
				Course.TEAM_COLOURS[teamId].Color,
				Enum.Material.Neon
			)
			box.CanCollide = false
			box.Transparency = 0.15
			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(box.Color, WHITE)
			emitter.LightEmission = 0.8
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			emitter.Transparency = NumberSequence.new(0.2, 1)
			emitter.Lifetime = NumberRange.new(1, 1.6)
			emitter.Speed = NumberRange.new(3, 6)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Rate = if k == legs then 30 else 12
			emitter.Parent = box
		end
		-- The obstacle sits on the longest straight in this sector.
		OBSTACLES[picks[k]].build(
			folder,
			frameAt(bestStraight((k - 1) * sector, k * sector), 0, Course.ROAD_Y),
			animated
		)
		markPlaced(folder)
	end
	folder.Parent = Workspace
	animate(folder, animated)
	return folder
end

return Course
