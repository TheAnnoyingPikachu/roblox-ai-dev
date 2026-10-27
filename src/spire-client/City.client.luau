--!strict
-- Neon Spire city dressing (art bible 7, 8; docs/architecture/spire.md 5), built once on the client
-- around the server's collision: the wet Grid Plaza with its neon rings and spokes to the six lots,
-- the city crest on its dais, street lamps, puddles, steam vents, searchlights, neon frames on the
-- Top Spires and Market boards, street furniture and sign pylons between the lots, the elevated
-- maglev viaduct (radius 220, height 40) and the backdrop megacity (fixed seed, radius 290 to 820)
-- with window columns, neon bands, giant holo ads and blinking roof lights. Part budget: plaza
-- <= 800, streets <= 1,500, backdrop <= 2,500 (art bible 8); the counts are printed once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local UI = ClientState.UI
local root = ClientState.folder("City")
local part, cylinder, ball, light = Kit.part, Kit.cylinder, Kit.ball, Kit.light
local M = Enum.Material

local PLAZA_RADIUS = 104 -- server City.luau: the lots' front edges
-- Blender models replace the part builds below once uploaded (src/shared/SpireAssets.luau).
Kit.waitModels()
local LAMP_BACK = 1.65 -- street_lamp: the pole stands this far behind the model's centre
local rng = Random.new(5150)

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	return f
end

local function polar(angle: number, radius: number, y: number): Vector3
	return Vector3.new(radius * math.sin(angle), y, -radius * math.cos(angle))
end

-- Lot n sits at angle (n - 1) * 60 degrees; the gaps between lots are at 30 + 60k.
local function nearLot(angle: number, halfWidth: number): boolean
	for n = 0, 5 do
		local d = math.abs((angle - math.rad(n * 60) + math.pi) % (2 * math.pi) - math.pi)
		if d < halfWidth then
			return true
		end
	end
	return false
end

-- A ring of thin flat neon segments.
local function neonRing(parent: Instance, radius: number, y: number, count: number, colour: Color3, width: number)
	local len = 2 * math.pi * radius / count + 0.2
	for i = 0, count - 1 do
		local a = (i + 0.5) / count * 2 * math.pi
		part(
			parent,
			CFrame.lookAt(polar(a, radius, y), polar(a, radius, y) + Vector3.new(math.cos(a), 0, math.sin(a))),
			Vector3.new(width, 0.06, len),
			colour,
			M.Neon,
			0.25
		)
	end
end

local function lamp(parent: Instance, at: Vector3, facing: Vector3, colour: Color3)
	local frame = CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z))
	local model = Kit.model("street_lamp", parent, at + frame.LookVector * LAMP_BACK, Kit.yaw(frame))
	local glow = model and Kit.glow(model)
	if glow then
		glow.Color = colour
		light(glow, colour, 14, 1.2)
		return
	end
	cylinder(parent, frame * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.pi / 2), 12, 0.5, UI.STEEL, M.Metal)
	part(parent, frame * CFrame.new(0, 11.8, -1.5), Vector3.new(0.35, 0.35, 3.4), UI.STEEL, M.Metal)
	local head = part(parent, frame * CFrame.new(0, 11.5, -3), Vector3.new(1.4, 0.3, 1.8), colour, M.Neon)
	light(head, colour, 14, 1.2)
end

local counts: { [string]: number } = {}
local function count(name: string, f: Instance)
	local n = 0
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	counts[name] = n
end

-- Grid Plaza ----------------------------------------------------------------------------------------

local plaza = folder("Plaza")
-- Wet finish over the server disc (top at y = 0).
cylinder(plaza, CFrame.new(0, 0.02, 0), 0.04, PLAZA_RADIUS * 2 - 0.4, UI.ASPHALT, M.SmoothPlastic).Reflectance = 0.15
neonRing(plaza, 22, 0.06, 24, UI.CYAN, 0.35)
neonRing(plaza, 60, 0.06, 36, UI.VIOLET, 0.25)
neonRing(plaza, PLAZA_RADIUS - 2, 0.06, 56, UI.CYAN, 0.45)
-- Spokes from the inner ring to each lot's walkway, so every tower is one straight walk away.
for n = 0, 5 do
	local a = math.rad(n * 60)
	for _, side in { -1, 1 } do
		local from, to = polar(a, 23, 0.06), polar(a, PLAZA_RADIUS - 1, 0.06)
		local mid = (from + to) / 2 + Vector3.new(math.cos(a), 0, math.sin(a)) * 4.5 * side
		part(
			plaza,
			CFrame.lookAt(mid, mid + (to - from)),
			Vector3.new(0.3, 0.06, (to - from).Magnitude),
			UI.CYAN,
			M.Neon,
			0.35
		)
	end
	-- Chevrons pointing out to the lot.
	for k = 0, 2 do
		local c = polar(a, 70 + k * 8, 0.07)
		local out = polar(a, 1, 0) - polar(a, 0, 0)
		for _, side in { -1, 1 } do
			local f = CFrame.lookAt(c, c + out)
				* CFrame.Angles(0, side * math.rad(35), 0)
				* CFrame.new(side * 1.2, 0, 0)
			part(plaza, f, Vector3.new(0.5, 0.06, 3.2), UI.CYAN, M.Neon, 0.3)
		end
	end
end

-- City crest: dais, holo column and three tilted rings turning slowly (hero prop 14 when loaded).
do
	local crest = folder("Crest")
	cylinder(crest, CFrame.new(0, 0.6, 0), 1.2, 26, UI.STEEL, M.Metal)
	cylinder(crest, CFrame.new(0, 1.15, 0), 0.2, 26.6, UI.CYAN, M.Neon)
	cylinder(crest, CFrame.new(0, 1.3, 0), 0.1, 24, UI.ASPHALT, M.Glass).Reflectance = 0.3
	cylinder(crest, CFrame.new(0, 8, 0), 14, 3, UI.CYAN, M.ForceField, 0.2)
	light(part(crest, CFrame.new(0, 3, 0), Vector3.one, UI.CYAN, M.SmoothPlastic, 1), UI.CYAN, 16, 2)
	crest.Parent = plaza
	local model = Kit.model("city_crest", crest, Vector3.new(0, 1.3, 0))
	if model then
		Kit.spin(model, 0.25)
	else
		local rings = Instance.new("Model")
		rings.Name = "Rings"
		for r = 1, 3 do
			local radius = 3 + r * 2.2
			local tilt = CFrame.new(0, 12 + r * 2, 0)
				* CFrame.Angles(0, r * math.rad(60), 0)
				* CFrame.Angles(math.rad(55), 0, 0)
			local colour = ({ UI.CYAN, UI.MAGENTA, UI.VIOLET })[r]
			for i = 0, 15 do
				local a = (i + 0.5) / 16 * 2 * math.pi
				local at = tilt * CFrame.new(radius * math.cos(a), 0, radius * math.sin(a))
				part(
					rings,
					CFrame.lookAt(
						at.Position,
						at.Position + tilt:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
					),
					Vector3.new(0.6, 0.6, 2 * math.pi * radius / 16 + 0.15),
					colour,
					M.Neon
				)
			end
		end
		rings.Parent = crest
		Kit.spin(rings, 0.25)
	end
end

-- Lamps around the rim, leaving the lot walkways clear.
for i = 0, 35 do
	local a = (i + 0.5) / 36 * 2 * math.pi
	if not nearLot(a, math.rad(9)) then
		lamp(plaza, polar(a, PLAZA_RADIUS - 6, 0), Vector3.zero, if i % 3 == 0 then UI.MAGENTA else UI.ICE)
	end
end

-- Puddles (art bible 4): thin glass, reflective.
for _ = 1, 18 do
	local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(26, PLAZA_RADIUS - 10)
	local p = cylinder(plaza, CFrame.new(polar(a, r, 0.05)), 0.05, rng:NextNumber(4, 10), UI.ASPHALT, M.Glass, 0.2)
	p.Size = Vector3.new(0.05, p.Size.Y, p.Size.Z * rng:NextNumber(0.6, 1))
	p.Reflectance = 0.35
end

-- Steam vents (smoke texture already registered).
for k = 0, 2 do
	local at = polar(math.rad(30 + k * 120), 40, 0.05)
	part(plaza, CFrame.new(at), Vector3.new(4, 0.1, 4), UI.STEEL, M.DiamondPlate)
	local holder =
		part(plaza, CFrame.new(at + Vector3.new(0, 0.3, 0)), Vector3.new(3, 0.2, 3), UI.STEEL, M.SmoothPlastic, 1)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 6
	steam.Lifetime = NumberRange.new(3, 4)
	steam.Speed = NumberRange.new(3, 5)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(Color3.fromRGB(150, 140, 190))
	steam.LightInfluence = 1
	steam.Parent = holder
end

-- Searchlights: four beams sweeping slowly from the gaps between the lots.
local sweeps: { { top: Attachment, base: Vector3, phase: number } } = {}
for k = 0, 3 do
	local base = polar(math.rad(30 + k * 90), PLAZA_RADIUS - 3, 0)
	local housing = cylinder(plaza, CFrame.new(base + Vector3.new(0, 0.8, 0)), 1.6, 3.2, UI.STEEL, M.Metal)
	if Kit.model("searchlight", plaza, base, -(30 + k * 90)) then
		housing.Transparency = 1 -- keeps the beam attachment
	else
		cylinder(plaza, CFrame.new(base + Vector3.new(0, 1.7, 0)), 0.2, 2.6, UI.ICE, M.Neon)
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.8, 0, 0) -- housing local X is world up (cylinder)
	a0.Parent = housing
	local anchor = part(plaza, CFrame.new(base), Vector3.one, UI.ICE, M.SmoothPlastic, 1)
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 2.5
	beam.Width1 = 40
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(UI.ICE)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	beam.Segments = 1
	beam.Parent = housing
	table.insert(sweeps, { top = a1, base = base, phase = k * 1.7 })
end
task.spawn(function()
	while true do
		local t = os.clock() * 0.12
		for _, s in sweeps do
			local a = t + s.phase
			s.top.WorldPosition = s.base + Vector3.new(math.cos(a) * 160, 600, math.sin(a * 1.3) * 160)
		end
		task.wait(1 / 20)
	end
end)

-- Neon frames on the server's Top Spires and Market boards (16 x 10, server City.luau), so they
-- read as lit screens instead of black slabs. The boards themselves are never changed.
task.spawn(function()
	local city = Workspace:WaitForChild("Spire"):WaitForChild("City")
	for _, name in { "TopSpires", "MarketBoard" } do
		local b = city:WaitForChild(name, 30)
		-- The server put a board_frame model around it (src/spire/City.luau).
		if b and b:IsA("BasePart") and not b:GetAttribute("Framed") then
			local f, s = b.CFrame, b.Size
			local edge = if name == "TopSpires" then UI.CYAN else UI.MAGENTA
			for _, e in
				{
					{ 0, s.Y / 2 + 0.25, s.X + 1, 0.5 },
					{ 0, -s.Y / 2 - 0.25, s.X + 1, 0.5 },
					{ s.X / 2 + 0.25, 0, 0.5, s.Y },
					{ -s.X / 2 - 0.25, 0, 0.5, s.Y },
				}
			do
				part(plaza, f * CFrame.new(e[1], e[2], 0), Vector3.new(e[3], e[4], 0.8), edge, M.Neon)
			end
			part(plaza, f * CFrame.new(0, 0, 0.45), Vector3.new(s.X, s.Y, 0.2), edge, M.Neon, 0.6)
			light(part(plaza, f * CFrame.new(0, 0, -2), Vector3.one, edge, M.SmoothPlastic, 1), edge, 12, 1)
		end
	end
end)
plaza.Parent = root
count("plaza", plaza)

-- Streets: furniture and sign pylons in the six gaps between the lots ------------------------------

local streets = folder("Streets")
cylinder(streets, CFrame.new(0, -0.08, 0), 0.02, 520, UI.ASPHALT, M.SmoothPlastic).Reflectance = 0.12
for k = 0, 5 do
	local a = math.rad(30 + k * 60)
	local out = polar(a, 1, 0)
	local side = Vector3.new(math.cos(a), 0, math.sin(a))
	-- Sidewalk strip with a neon kerb on both sides.
	local mid = polar(a, 150, 0)
	local f = CFrame.lookAt(mid, mid + out)
	part(streets, f * CFrame.new(0, 0.1, 0), Vector3.new(14, 0.2, 86), UI.STEEL, M.Concrete)
	for _, s in { -1, 1 } do
		part(streets, f * CFrame.new(s * 7, 0.25, 0), Vector3.new(0.3, 0.1, 86), UI.MAGENTA, M.Neon, 0.2)
	end
	for _, r in { 125, 175 } do
		lamp(streets, polar(a, r, 0.2) + side * 5, polar(a, r, 0) - side * 20, UI.ICE)
	end
	for b = 0, 5 do
		local at = polar(a, 118 + b * 12, 0.2) - side * 5.5
		if not Kit.model("bollard", streets, at) then
			cylinder(streets, CFrame.new(at + Vector3.new(0, 0.9, 0)), 1.8, 0.8, UI.STEEL, M.Metal)
			cylinder(streets, CFrame.new(at + Vector3.new(0, 1.5, 0)), 0.2, 0.85, UI.AMBER, M.Neon)
		end
	end
	-- A tall vertical sign pylon with a product on both faces.
	local pylon = part(streets, f * CFrame.new(0, 14, 10), Vector3.new(5, 26, 1.2), UI.ASPHALT, M.SmoothPlastic)
	pylon.Size = Vector3.new(5, 26, 1.2)
	Kit.adScreen(pylon, Enum.NormalId.Front, k * 2 + 1, 10)
	Kit.adScreen(pylon, Enum.NormalId.Back, k * 2 + 2, 10)
	for _, s in { -1, 1 } do
		part(streets, f * CFrame.new(s * 2.7, 14, 10), Vector3.new(0.4, 26.4, 1.4), Kit.ACCENTS[k % 5 + 1], M.Neon)
	end
	-- Vending kiosk (Vending Bot hero prop when loaded).
	local kiosk = polar(a, 160, 0.2) + side * 4.5
	local facing = CFrame.lookAt(kiosk, kiosk - side)
	if not Kit.model("vending_bot", streets, kiosk, Kit.yaw(facing)) then
		local kf = facing * CFrame.new(0, 2.6, 0)
		part(streets, kf, Vector3.new(3, 5.2, 2.2), UI.STEEL, M.Metal)
		part(streets, kf * CFrame.new(0, 0.6, -1.12), Vector3.new(2.4, 2.6, 0.05), Kit.ACCENTS[k % 5 + 1], M.Neon, 0.2)
	end
end

-- Elevated maglev viaduct (the train is SPIRE-007 Traffic).
local VIADUCT_R, VIADUCT_Y, SEGMENTS = 220, 40, 48
for i = 0, SEGMENTS - 1 do
	local a = (i + 0.5) / SEGMENTS * 2 * math.pi
	local at = polar(a, VIADUCT_R, VIADUCT_Y)
	local f = CFrame.lookAt(at, at + Vector3.new(math.cos(a), 0, math.sin(a)))
	local len = 2 * math.pi * VIADUCT_R / SEGMENTS + 0.4
	local deck = Kit.model("viaduct_segment", streets, at - Vector3.new(0, 1, 0), Kit.yaw(f))
	local strip = deck and Kit.glow(deck)
	if strip then
		strip.Color = if i % 2 == 0 then UI.CYAN else UI.VIOLET
	else
		part(streets, f, Vector3.new(10, 2, len), UI.STEEL, M.Concrete)
		part(
			streets,
			f * CFrame.new(0, -0.6, 0),
			Vector3.new(10.4, 0.35, len),
			if i % 2 == 0 then UI.CYAN else UI.VIOLET,
			M.Neon
		)
		part(streets, f * CFrame.new(0, 1.3, 0), Vector3.new(1.2, 0.6, len), UI.STEEL, M.Metal)
	end
	if i % 2 == 0 then
		part(
			streets,
			CFrame.new(at - Vector3.new(0, VIADUCT_Y / 2 + 1, 0)),
			Vector3.new(3, VIADUCT_Y - 2, 3),
			UI.STEEL,
			M.Concrete
		)
	end
end
streets.Parent = root
count("streets", streets)

-- Backdrop megacity (built over a few frames) ----------------------------------------------------

local backdrop = folder("Backdrop")
part(backdrop, CFrame.new(0, -1.25, 0), Vector3.new(2048, 1, 2048), UI.ASPHALT, M.SmoothPlastic).Reflectance = 0.1
backdrop.Parent = root
local WINDOW = Color3.fromRGB(70, 80, 120)
local towerCount = 0
local adIndex = 0
for i = 1, 140 do
	local a = rng:NextNumber(0, 2 * math.pi)
	local r = 290 + 530 * math.sqrt(rng:NextNumber())
	local w, d = rng:NextNumber(30, 75), rng:NextNumber(30, 75)
	local h = rng:NextNumber(150, 650) * (0.6 + 0.4 * (r / 820))
	local at = polar(a, r, 0)
	local f = CFrame.lookAt(at, Vector3.zero) * CFrame.new(0, h / 2, 0)
	local tower = Instance.new("Model")
	tower.Name = `Tower{i}`
	part(tower, f, Vector3.new(w, h, d), if rng:NextNumber() < 0.25 then UI.SMOG else UI.STEEL, M.SmoothPlastic)
	-- Window columns on the face toward the plaza (local -Z).
	local cols = math.floor(w / 12)
	for c = 1, cols do
		local x = -w / 2 + c * w / (cols + 1)
		part(tower, f * CFrame.new(x, -h * 0.05, -d / 2 - 0.1), Vector3.new(1.6, h * 0.8, 0.2), WINDOW, M.Neon, 0.1)
	end
	for _ = 1, rng:NextInteger(1, 3) do
		local y = rng:NextNumber(-h / 2 + 20, h / 2 - 6)
		local band = Kit.ACCENTS[rng:NextInteger(1, #Kit.ACCENTS)]
		part(tower, f * CFrame.new(0, y, 0), Vector3.new(w + 0.6, 1.2, d + 0.6), band, M.Neon)
	end
	if h > 300 then
		Kit.blink(ball(tower, f * CFrame.new(0, h / 2 + 1.5, 0), 3, Color3.fromRGB(255, 40, 60), M.Neon))
	end
	-- Giant holo ads on every 9th tower, upper half, facing the plaza.
	if i % 9 == 0 then
		adIndex += 1
		local ad = part(
			tower,
			f * CFrame.new(0, h * 0.2, -d / 2 - 1.5),
			Vector3.new(w * 0.8, w * 0.45, 0.5),
			UI.ASPHALT,
			M.SmoothPlastic
		)
		Kit.adScreen(ad, Enum.NormalId.Front, adIndex, 4)
	end
	tower.Parent = backdrop
	towerCount += 1
	if i % 20 == 0 then
		task.wait()
	end
end
count("backdrop", backdrop)
print(`[City] parts: plaza {counts.plaza}, streets {counts.streets}, backdrop {counts.backdrop} ({towerCount} towers)`)

-- Unused unless Models is mapped; keeps the require list in one place for selene.
local _ = ReplicatedStorage
