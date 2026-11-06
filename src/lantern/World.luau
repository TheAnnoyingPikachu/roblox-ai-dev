--!strict
-- Lantern Express world (docs/architecture/lantern.md 4.1): the four track paths, rails, the stop
-- platforms, Lamplight Depot (the hub), Dawn Station, seeded decor, the weekly boards, and the base
-- Lighting and Atmosphere of the art bible (section 3; the client tweens the phases). Every piece is
-- a part fallback until src/shared/LanternAssets has its model id (Models.night returns nil).
-- Heights: the rail top is RAIL_Y, platforms and stop tiles are 2 studs above it, so the platform
-- top meets the project's SpawnLocation top (1.1).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local Rng = require(Shared:WaitForChild("Rng"))
local TrackRules = require(Shared:WaitForChild("TrackRules"))
local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))

local World = {}

local C3 = Color3.fromRGB
-- Art bible section 2.
World.PAL = {
	cream = C3(255, 238, 210),
	brick = C3(178, 84, 66),
	timber = C3(128, 84, 60),
	roof = C3(128, 70, 116),
	door = C3(56, 118, 128),
	window = C3(255, 196, 104),
	lamp = C3(255, 206, 110),
	ember = C3(255, 128, 48),
	brass = C3(196, 134, 56),
	iron = C3(64, 56, 90),
	red = C3(196, 52, 62),
	grass = C3(70, 104, 96),
	path = C3(104, 84, 92),
	fog = C3(190, 180, 210),
	rail = C3(132, 118, 164),
	bark = C3(96, 72, 70),
	pine = C3(52, 92, 84),
	birch = C3(206, 200, 190),
	leaf = C3(110, 150, 110),
	rock = C3(118, 112, 132),
}
local PAL = World.PAL

World.RAIL_Y = -0.9
World.GROUND_Y = World.RAIL_Y - 1
World.PLATFORM_Y = World.RAIL_Y + 2
World.PLATFORM_NEAR = 4 -- platform edges, studs out from the track centre (the tiles' deck: 4 to 14)
World.PLATFORM_FAR = 14
World.TILE_Y = World.RAIL_Y + 0.2 -- a stop tile's plate top (tiles.py GROUND): stop frame y = 0
World.HUB_SIDE = LanternConfig.OUTER.forest -- the Depot building's side of the hub straight (west)

World.paths = {} :: { [string]: TrackRules.Path }
for name, track in LanternConfig.TRACKS do
	World.paths[name] = TrackRules.build(track.points, track.closed)
end

local function v3(p: { x: number, y: number, z: number }): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function rightOf(forward: Vector3): Vector3
	return Vector3.new(-forward.Z, 0, forward.X).Unit -- TrackRules.right
end

-- Position (at the rail top) and forward at distance d of a track. A Dawn track before its start
-- (cars behind the engine at d < 0) reads the loop it leaves from, which it follows to 5,300.
function World.at(track: string, d: number): (Vector3, Vector3)
	local path = World.paths[track]
	if d < 0 and not path.closed then
		path = World.paths[(string.gsub(track, "Dawn$", ""))]
		d += path.length
	end
	local p, f = TrackRules.at(path, d)
	return Vector3.new(p.x, World.RAIL_Y, p.z), v3(f)
end

-- The stop site (architecture 4.4, the art's LAYOUT frame): level with the engine's front at the stop
-- distance, on the platform deck's track edge (4 studs out, on the loop's outer side) at the plate
-- top, looking at the track. Stop frame (x, y, depth) is site * Vector3.new(x, y, depth): +Z runs
-- into the stop, as in the client's stop frame.
function World.site(line: string, index: number): CFrame
	local pos, fwd = World.at(line, LanternConfig.TRACKS[line].stops[index])
	local out = rightOf(fwd) * LanternConfig.OUTER[line]
	local origin = Vector3.new(pos.X, World.TILE_Y, pos.Z) + out * World.PLATFORM_NEAR
	return CFrame.lookAt(origin, origin - out)
end

-- Where the n-th crew member stands on the hub platform, facing the train.
function World.hubSpot(n: number): CFrame
	local x = 10 + World.HUB_SIDE * (World.PLATFORM_NEAR + World.PLATFORM_FAR) / 2
	local at = Vector3.new(x, World.PLATFORM_Y + 3, 16 + (n % 8) * 6)
	return CFrame.lookAt(at, at + Vector3.new(-World.HUB_SIDE, 0, 0))
end

local folder: Folder
local boardLabels: { [string]: TextLabel } = {}

-- A platform beside the track centred at `pos`, on `side` (+1 right of `fwd`), `length` long.
local function platform(parent: Instance, pos: Vector3, fwd: Vector3, side: number, length: number)
	local mid = (World.PLATFORM_NEAR + World.PLATFORM_FAR) / 2
	local height = World.PLATFORM_Y - World.GROUND_Y
	local centre = Vector3.new(pos.X, World.GROUND_Y + height / 2, pos.Z) + rightOf(fwd) * side * mid
	local cf = CFrame.lookAt(centre, centre + fwd)
	local depth = World.PLATFORM_FAR - World.PLATFORM_NEAR
	local yaw = math.deg(math.atan2(-fwd.X, -fwd.Z))
	local copies, placed = math.ceil(length / 40), 0 -- depot_platform is 40 long
	for i = 1, copies do
		local at = centre + fwd * (i - (copies + 1) / 2) * 40 - Vector3.new(0, height / 2, 0)
		if Models.night("depot_platform", parent, at, yaw) == nil then
			break
		end
		placed += 1
	end
	if placed == 0 then
		local p = Props.part(parent, Vector3.new(depth, height, length), cf, PAL.brick, Enum.Material.Brick)
		p.Name = "Platform"
		local edge = Props.part(parent, Vector3.new(0.8, 0.1, length), cf, PAL.cream)
		edge.CFrame = cf * CFrame.new(-side * (depth / 2 - 0.5), height / 2 + 0.05, 0)
		edge.CanCollide = false
	end
end

local function lamp(parent: Instance, base: Vector3, range: number)
	local post =
		Props.part(parent, Vector3.new(0.5, 7, 0.5), base + Vector3.new(0, 3.5, 0), PAL.iron, Enum.Material.Metal)
	post.Name = "LampPost"
	local head =
		Props.part(parent, Vector3.new(1.2, 1.4, 1.2), base + Vector3.new(0, 7.6, 0), PAL.lamp, Enum.Material.Neon)
	head.Name = "Lamp"
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = 1.2
	light.Color = PAL.lamp
	light.Shadows = false
	light.Parent = head
end

-- One part fallback per 32-stud chord: a ballast bed and two rails. Shared stretches (the hub
-- straight, the Dawn tracks up to 5,300) are laid once.
local function rails(parent: Instance)
	local laid: { [string]: boolean } = {}
	for _, name in { "forest", "lake", "forestDawn", "lakeDawn" } do
		local path = World.paths[name]
		local d = 0
		while d < path.length - 1 do
			local a = World.at(name, d)
			local b = World.at(name, math.min(d + 32, path.length))
			local mid = (a + b) / 2
			local key = `{math.round(mid.X)},{math.round(mid.Z)}`
			if not laid[key] then
				laid[key] = true
				local cf = CFrame.lookAt(mid, b)
				local length = (b - a).Magnitude + 0.2
				local yaw = math.deg(math.atan2(-(b - a).X, -(b - a).Z))
				if Models.night("rail_32", parent, mid - Vector3.new(0, 1, 0), yaw) == nil then
					local bed = Props.part(parent, Vector3.new(8, 0.8, length), cf * CFrame.new(0, -0.6, 0), PAL.path)
					bed.Material = Enum.Material.Mud
					bed.Name = "Ballast"
					for _, x in { -2.4, 2.4 } do
						local r =
							Props.part(parent, Vector3.new(0.4, 0.4, length), cf * CFrame.new(x, -0.2, 0), PAL.rail)
						r.Material = Enum.Material.Metal
						r.Name = "Rail"
					end
				end
			end
			d += 32
		end
	end
end

local function house(parent: Instance, cf: CFrame, size: Vector3, colour: Color3)
	local body = Props.part(parent, size, cf * CFrame.new(0, size.Y / 2, 0), colour)
	body.Name = "Building"
	local roof =
		Props.part(parent, Vector3.new(size.X + 2, 3, size.Z + 2), cf * CFrame.new(0, size.Y + 1.5, 0), PAL.roof)
	roof.Name = "Roof"
	return body
end

local function board(parent: Instance, key: string, title: string, cf: CFrame)
	if Models.night("depot_board", parent, cf.Position, 0) == nil then
		Props.part(parent, Vector3.new(16, 10, 1.5), cf * CFrame.new(0, 5, 0), PAL.timber).Name = "BoardFrame"
	end
	local face = Props.part(parent, Vector3.new(15, 9, 0.2), cf * CFrame.new(0, 5, -0.9), PAL.cream)
	face.Name = `Board_{key}`
	face.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = face
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = PAL.iron
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = `{title}\n(no runs yet this week)`
	label:SetAttribute("Title", title)
	label.Parent = gui
	boardLabels[key] = label
end

local function hub(parent: Instance)
	local side = World.HUB_SIDE
	-- Two platforms along the hub straight (x = 10, the train parks from z = 0 to 78).
	for _, s in { -1, 1 } do
		platform(parent, Vector3.new(10, World.RAIL_Y, 40), Vector3.new(0, 0, -1), s, 110)
	end
	local back = 10 + side * (World.PLATFORM_FAR + 13)
	local base = Vector3.new(back, World.GROUND_Y, 40)
	if Models.night("depot_hub", parent, base, if side < 0 then -90 else 90) == nil then
		local cf = CFrame.lookAt(base, base + Vector3.new(-side, 0, 0))
		house(parent, cf, Vector3.new(60, 25, 24), PAL.brick).Material = Enum.Material.Brick
		local tower = Props.part(parent, Vector3.new(8, 10, 8), cf * CFrame.new(0, 30, 0), PAL.brick)
		tower.Material = Enum.Material.Brick
		local clock = Props.part(parent, Vector3.new(6, 6, 0.4), cf * CFrame.new(0, 30, -4.2), PAL.cream)
		clock.Name = "Clock"
		for _, x in { -18, -6, 6, 18 } do
			local window = Props.part(
				parent,
				Vector3.new(4, 5, 0.3),
				cf * CFrame.new(x, 12, -12.1),
				PAL.window,
				Enum.Material.Neon
			)
			window.Name = "Window"
		end
		Props.part(parent, Vector3.new(5, 8, 0.3), cf * CFrame.new(0, 7, -12.1), PAL.door).Name = "Door"
	end
	for _, z in { 4, 76 } do
		lamp(parent, Vector3.new(10 + side * (World.PLATFORM_FAR - 1.5), World.PLATFORM_Y, z), 18)
		lamp(parent, Vector3.new(10 - side * (World.PLATFORM_FAR - 1.5), World.PLATFORM_Y, z), 18)
	end
	local signal = Vector3.new(10 - side * 6, World.GROUND_Y, -14)
	if Models.night("depot_signal", parent, signal) == nil then
		Props.part(parent, Vector3.new(0.6, 12, 0.6), signal + Vector3.new(0, 6, 0), PAL.iron).Name = "Signal"
		local ball = Props.part(
			parent,
			Vector3.new(1.6, 1.6, 1.6),
			signal + Vector3.new(0, 12.5, 0),
			PAL.lamp,
			Enum.Material.Neon
		)
		ball.Shape = Enum.PartType.Ball
	end
	-- The weekly boards on the back of the Depot platform, facing the train.
	local x = 10 + side * (World.PLATFORM_FAR - 0.8)
	for i, key in { "critters", "dist" } do
		local at = Vector3.new(x, World.PLATFORM_Y, if i == 1 then 24 else 56)
		local title = if i == 1 then "MOST CRITTERS THIS WEEK" else "FARTHEST THIS WEEK"
		board(parent, key, title, CFrame.lookAt(at, at - Vector3.new(side, 0, 0)))
	end
end

local function dawnStation(parent: Instance)
	for _, line in { "forest", "lake" } do
		local track = `{line}Dawn`
		local finish = LanternConfig.TRACKS[track].finish
		local pos, fwd = World.at(track, finish - LanternConfig.TRAIN_LENGTH / 2)
		local side = LanternConfig.OUTER[line]
		platform(parent, pos, fwd, side, 90)
		local out = rightOf(fwd) * side
		local base = Vector3.new(pos.X, World.GROUND_Y, pos.Z) + out * (World.PLATFORM_FAR + 16)
		local yaw = math.deg(math.atan2(out.X, out.Z))
		if Models.night("dawn_station", parent, base, yaw) == nil then
			local cf = CFrame.lookAt(base, base - out)
			house(parent, cf, Vector3.new(60, 26, 30), PAL.cream).Name = "DawnStation"
			local dome =
				Props.part(parent, Vector3.new(14, 14, 14), cf * CFrame.new(0, 33, 0), PAL.lamp, Enum.Material.Neon)
			dome.Shape = Enum.PartType.Ball
		end
		lamp(parent, Vector3.new(pos.X, World.PLATFORM_Y, pos.Z) + out * (World.PLATFORM_FAR - 1.5), 18)
	end
end

-- Seeded scatter 30 to 150 studs from the loops, never on a track, a stop site, the hub or Dawn.
local function decor(parent: Instance)
	local blocked: { [string]: boolean } = {}
	local function cell(x: number, z: number): string
		return `{math.floor(x / 16)},{math.floor(z / 16)}`
	end
	for _, path in World.paths do
		for i = 1, #path.samples, 4 do
			local p = path.samples[i]
			for dx = -1, 1 do
				for dz = -1, 1 do
					blocked[cell(p.x + dx * 16, p.z + dz * 16)] = true
				end
			end
		end
	end
	local sites = {}
	for _, line in { "forest", "lake" } do
		for i = 1, #LanternConfig.TRACKS[line].stops do
			table.insert(sites, World.site(line, i))
		end
	end
	local clear = { Vector3.new(10, 0, 40), Vector3.new(129, 0, 25), Vector3.new(-109, 0, 25) }
	local rng = Rng.seed(LanternConfig.WEEKLY_SALT, 7)
	local used: { [string]: boolean } = {}
	for _, line in { "forest", "lake" } do
		local path = World.paths[line]
		for d = 0, path.length, 28 do
			local pos, fwd = World.at(line, d)
			for _, side in { -1, 1 } do
				local r, kind, dist
				r, rng = Rng.next(rng)
				kind, rng = Rng.next(rng)
				dist, rng = Rng.next(rng)
				local at = pos + rightOf(fwd) * side * (30 + dist * 120) + fwd * (r - 0.5) * 20
				local ok = r < 0.7 and not blocked[cell(at.X, at.Z)] and not used[cell(at.X, at.Z)]
				for _, c in clear do
					ok = ok and (Vector3.new(at.X, 0, at.Z) - c).Magnitude > 140
				end
				for _, site in sites do
					local q = site:PointToObjectSpace(Vector3.new(at.X, site.Position.Y, at.Z))
					ok = ok and not (math.abs(q.X) < 72 and q.Z > -24 and q.Z < 176)
				end
				if ok then
					used[cell(at.X, at.Z)] = true
					local base = Vector3.new(at.X, World.GROUND_Y, at.Z)
					local name = if kind < 0.5 then "decor_pine" elseif kind < 0.8 then "decor_birch" else "decor_rock"
					if Models.night(name, parent, base, r * 360) == nil then
						if name == "decor_pine" then
							Props.part(parent, Vector3.new(1.6, 6, 1.6), base + Vector3.new(0, 3, 0), PAL.bark).Name =
								"Trunk"
							for k, w in { 10, 7.5, 5 } do
								local tier = Props.part(
									parent,
									Vector3.new(6, w, w),
									CFrame.new(base + Vector3.new(0, 2 + k * 6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
									PAL.pine
								)
								tier.Shape = Enum.PartType.Cylinder
							end
						elseif name == "decor_birch" then
							Props.part(parent, Vector3.new(1.2, 14, 1.2), base + Vector3.new(0, 7, 0), PAL.birch).Name =
								"Trunk"
							local crown =
								Props.part(parent, Vector3.new(9, 9, 9), base + Vector3.new(0, 16, 0), PAL.leaf)
							crown.Shape = Enum.PartType.Ball
						else
							local rock = Props.part(
								parent,
								Vector3.new(6, 6, 6),
								base + Vector3.new(0, 1.5, 0),
								PAL.rock,
								Enum.Material.Slate
							)
							rock.Shape = Enum.PartType.Ball
						end
					end
				end
			end
		end
	end
end

local function ground(parent: Instance)
	for _, x in { -1024, 1024 } do
		for _, z in { -1024 + 640, 1024 + 640 } do
			local g = Props.part(
				parent,
				Vector3.new(2048, 2, 2048),
				Vector3.new(x, World.GROUND_Y - 1, z),
				PAL.grass,
				Enum.Material.Grass
			)
			g.Name = "Ground"
		end
	end
end

-- Art bible section 3: the dusk values (Depot and stops). The client tweens night and dawn.
local function lighting()
	local ok = pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	if not ok then
		warn("[World] Lighting.Technology is not scriptable here; set Future in the place settings")
	end
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ClockTime = 18.4
	Lighting.Brightness = 1.6
	Lighting.Ambient = C3(44, 38, 74)
	Lighting.OutdoorAmbient = C3(110, 100, 150)
	Lighting.ColorShift_Top = C3(255, 190, 150)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Color = PAL.fog
	atmosphere.Decay = C3(96, 84, 150)
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.25
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.8
	atmosphere.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.MoonAngularSize = 14
	sky.StarCount = 0
	sky.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 0.92
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.08
	grade.Contrast = 0.05
	grade.TintColor = C3(255, 246, 240)
	grade.Parent = Lighting
end

function World.build(): Folder
	folder = Instance.new("Folder")
	folder.Name = "Lantern"
	local world = Instance.new("Folder")
	world.Name = "World"
	ground(world)
	rails(world)
	for _, line in { "forest", "lake" } do
		for i, d in LanternConfig.TRACKS[line].stops do
			-- The tile brings its own deck, 54 studs either side of the engine's front; this piece
			-- carries the platform on under the rest of the 78-stud train.
			local half, back = LanternConfig.TILE_DECK.length / 2, LanternConfig.TRAIN_LENGTH + 22
			local pos, fwd = World.at(line, d - (half + back) / 2)
			platform(world, pos, fwd, LanternConfig.OUTER[line], back - half)
			local far = World.site(line, i) * CFrame.new(0, 0, World.PLATFORM_FAR - World.PLATFORM_NEAR - 1)
			lamp(world, Vector3.new(0, World.PLATFORM_Y, 0) + Vector3.new(far.X, 0, far.Z) - fwd * (back - 2), 18)
		end
	end
	hub(world)
	dawnStation(world)
	decor(world)
	world.Parent = folder
	folder.Parent = workspace
	lighting()
	return folder
end

-- The weekly boards: `lists[key]` is a list of { name, value } (top 10).
function World.boards(lists: { [string]: { { name: string, value: number } } })
	for key, label in boardLabels do
		local rows = { label:GetAttribute("Title") :: string }
		for i, row in lists[key] or {} do
			table.insert(rows, `{i}. {row.name}  {row.value}`)
		end
		if #rows == 1 then
			table.insert(rows, "(no runs yet this week)")
		end
		label.Text = table.concat(rows, "\n")
	end
end

return World
