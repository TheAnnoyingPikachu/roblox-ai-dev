--!strict
-- Relay Rounds geometry: lobby, practice lane, stands and the per-round race course.
-- Primitive parts only (GDD F, CLAUDE.md rule 9). No game rules live here.

local Workspace = game:GetService("Workspace")

local Course = {}

Course.LEG_LENGTH = 60
Course.COURSE_Y = 30
Course.FALL_Y = Course.COURSE_Y - 10
Course.ZONE_RADIUS = 6
Course.STANDS = Vector3.new(-45, 34, 120)

local LANE_GAP = 20
local LANE_WIDTH = 10

Course.TEAM_COLOURS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Lime green"),
	BrickColor.new("New Yeller"),
}

local function part(
	parent: Instance,
	size: Vector3,
	position: Vector3,
	colour: BrickColor,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.BrickColor = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(parent: Instance, text: string, position: Vector3, size: Vector3)
	local board = part(parent, size, position, BrickColor.new("Really black"))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.Parent = gui
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

function Course.build(teamIds: { number }, legs: number, round: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "RelayCourse"
	local picks = Course.layoutsFor(round, legs)
	for _, teamId in teamIds do
		local x = Course.laneX(teamId)
		local colour = Course.TEAM_COLOURS[teamId]
		for k = 1, legs do
			local z = Course.legStart(k)
			for _, seg in LAYOUTS[picks[k]] do
				local from, to, width, rise = seg[1], seg[2], seg[3], seg[4]
				part(
					folder,
					Vector3.new(width, 1, to - from),
					Vector3.new(x, Course.COURSE_Y - 0.5 + rise, z + (from + to) / 2),
					BrickColor.new("Medium stone grey")
				)
			end
			local pad = part(
				folder,
				Vector3.new(LANE_WIDTH, 0.2, 8),
				Course.zoneCentre(teamId, k) + Vector3.new(0, 0.1, 0),
				colour,
				Enum.Material.Neon
			)
			pad.CanCollide = false
			if k == legs then
				local flag = part(
					folder,
					Vector3.new(LANE_WIDTH, 6, 0.4),
					Course.zoneCentre(teamId, k) + Vector3.new(0, 6, 4),
					colour,
					Enum.Material.Neon
				)
				flag.Transparency = 0.5
				flag.CanCollide = false
			end
		end
		sign(
			folder,
			`TEAM {teamId}`,
			Vector3.new(x, Course.COURSE_Y + 6, Course.legStart(1) - 2),
			Vector3.new(LANE_WIDTH, 4, 0.5)
		)
	end
	folder.Parent = Workspace
	return folder
end

-- Built once at server start: title sign, practice lane (every layout once, low so falls are safe) and stands.
function Course.buildLobby()
	local folder = Instance.new("Folder")
	folder.Name = "RelayLobby"
	part(
		folder,
		Vector3.new(40, 0.2, 40),
		Vector3.new(0, 0.1, 0),
		BrickColor.new("Institutional white"),
		Enum.Material.Concrete
	)
	sign(folder, "RELAY ROUNDS", Vector3.new(0, 12, -20), Vector3.new(30, 8, 1))
	sign(folder, "PRACTICE  →", Vector3.new(-20, 6, -15), Vector3.new(10, 3, 0.5))

	for i, layout in LAYOUTS do
		local z = -30 - (i - 1) * Course.LEG_LENGTH
		for _, seg in layout do
			local from, to, width, rise = seg[1], seg[2], seg[3], seg[4]
			part(
				folder,
				Vector3.new(width, 1, to - from),
				Vector3.new(-30, 0.5 + rise, z - (from + to) / 2),
				BrickColor.new("Pastel light blue")
			)
		end
	end

	local stands = Course.STANDS
	for row = 0, 3 do
		part(
			folder,
			Vector3.new(14, 1 + row * 2, 60),
			Vector3.new(stands.X - row * 4, 22 + row + 0.5, stands.Z),
			BrickColor.new("Dark stone grey"),
			Enum.Material.Concrete
		)
	end
	sign(folder, "OUT? WATCH FROM HERE", stands + Vector3.new(-6, 8, -32), Vector3.new(20, 4, 0.5))
	folder.Parent = Workspace
end

return Course
