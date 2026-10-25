--!strict
-- "Hatchling Valley" (GDD I1, I4 Clear lighting baseline): plaza and Great Egg Tree, the egg cart,
-- forecast and Top Gardens boards, the Wild Meadow gate, paths, flower meadows, the river with
-- bridges, blossom trees, windmill, barn and far scenery. Built once from parts, Roblox materials,
-- terrain and the registered meshes in Models. No game rules live here; the plots are in Plots.
-- Weather looks are client-side (HatchFx); the server only switches the lamps on for Moonfall.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local Models = require(script.Parent:WaitForChild("Models"))
local Plots = require(script.Parent:WaitForChild("Plots"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar = Props.part, Props.pillar

local World = {}

local CART = Vector3.new(0, 0, 30)
local PLAZA = 45
local RIVER = 165
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(60, 45, 40)
local WOOD = Color3.fromRGB(165, 115, 75)
local DARK_WOOD = Color3.fromRGB(110, 75, 50)
local LEAF = Color3.fromRGB(110, 185, 95)
local WARM = Color3.fromRGB(255, 205, 140)
local PASTELS = {
	Color3.fromRGB(255, 190, 215),
	Color3.fromRGB(190, 225, 255),
	Color3.fromRGB(255, 240, 170),
	Color3.fromRGB(200, 250, 200),
	Color3.fromRGB(225, 205, 255),
	Color3.fromRGB(255, 210, 170),
}
local FLOWERS = {
	Color3.fromRGB(255, 140, 185),
	Color3.fromRGB(255, 225, 100),
	Color3.fromRGB(185, 150, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 160, 110),
	Color3.fromRGB(140, 200, 255),
}
local WEATHER_ICON: { [string]: string } = { clear = "⛅", sunbeam = "☀️", moonfall = "🌙", shower = "🌈" }

local folder = Instance.new("Folder")
folder.Name = "World"
local lamps: { PointLight } = {}
local boardRows: TextLabel? = nil
local forecastRows: { TextLabel } = {}
local lastWeather = ""

-- Scenery that players and raycasts pass through.
local function decor<T>(p: T): T
	local b: BasePart = p :: any
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	return p
end

local function ball(
	parent: Instance,
	size: Vector3,
	at: CFrame | Vector3,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = part(parent, size, at, colour, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function wedge(parent: Instance, size: Vector3, cframe: CFrame, colour: Color3, material: Enum.Material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = colour
	w.Material = material
	w.Parent = parent
end

-- A light that is off until Moonfall (GDD I4).
local function lamp(p: BasePart, colour: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = range
	l.Brightness = 1.4
	l.Shadows = false
	l.Enabled = false
	l.Parent = p
	table.insert(lamps, l)
end

local function textLabel(parent: Instance, text: string, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = colour
	l.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function surface(board: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	return gui
end

local function polar(angle: number, radius: number): Vector3
	return Vector3.new(radius * math.sin(angle), 0, -radius * math.cos(angle))
end

-- Lighting (GDD I4, Clear) ------------------------------------------------------------------

local function effect(className: string, props: { [string]: any })
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		existing:Destroy()
	end
	local e = Instance.new(className)
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = Lighting
end

local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.GlobalShadows = true
	effect("Atmosphere", {
		Density = 0.28,
		Offset = 0.1,
		Color = Color3.fromRGB(200, 220, 255),
		Decay = Color3.fromRGB(110, 140, 190),
		Glare = 0.1,
		Haze = 1,
	})
	effect("BloomEffect", { Intensity = 0.35, Size = 24, Threshold = 1.6 })
	effect("ColorCorrectionEffect", { Saturation = 0.25, Contrast = 0.08, Brightness = 0 })
	effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.8 })
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.7
	clouds.Color = WHITE
	clouds.Parent = terrain
end

-- Ground, river and far hills -----------------------------------------------------------------

local function ground()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:FillBlock(CFrame.new(0, -5, 0), Vector3.new(1000, 10, 1000), Enum.Material.Grass)
	-- River ring at radius 165, 14 wide, with sandy banks.
	local segments = 96
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local at = CFrame.lookAt(polar(angle, RIVER), Vector3.zero)
		terrain:FillBlock(at * CFrame.new(0, -2.5, 0), Vector3.new(14, 5, 22), Enum.Material.Sand)
		terrain:FillBlock(at * CFrame.new(0, -3, 0), Vector3.new(13, 5, 14), Enum.Material.Water)
		terrain:FillBlock(at * CFrame.new(0, 2, 0), Vector3.new(13, 4, 16), Enum.Material.Air)
	end
	-- Rolling hills and rock outcrops beyond 260 studs.
	local rng = Random.new(4004)
	for i = 1, 28 do
		local angle = i / 28 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local at = polar(angle, rng:NextNumber(280, 400)) - Vector3.new(0, rng:NextNumber(15, 35), 0)
		terrain:FillBall(at, rng:NextNumber(45, 75), Enum.Material.Grass)
		if i % 4 == 0 then
			terrain:FillBall(at + Vector3.new(0, 30, 0), rng:NextNumber(10, 16), Enum.Material.Rock)
		end
	end
end

-- Plaza and the Great Egg Tree --------------------------------------------------------------

local function plaza()
	local ring =
		pillar(folder, Vector3.new(0, 0, 0), 0.28, PLAZA + 1.5, Color3.fromRGB(190, 120, 100), Enum.Material.Brick)
	ring.Name = "PlazaRing"
	local cobble =
		pillar(folder, Vector3.new(0, 0, 0), 0.3, PLAZA, Color3.fromRGB(225, 215, 195), Enum.Material.Cobblestone)
	cobble.Name = "Plaza"
	-- Eight lamp posts at radius 42, strung together with pastel fairy lights.
	local tops = {}
	for i = 0, 7 do
		local angle = math.rad(22.5 + i * 45)
		local foot = polar(angle, 42)
		pillar(folder, foot, 0.6, 0.9, DARK_WOOD, Enum.Material.Metal)
		pillar(folder, foot, 9, 0.3, Color3.fromRGB(70, 90, 80), Enum.Material.Metal)
		local glass = part(folder, Vector3.new(1.4, 1.8, 1.4), foot + Vector3.new(0, 9.9, 0), WARM, Enum.Material.Neon)
		glass.Name = "Lamp" -- HatchFx finds night lights by the names Lamp and HangingEgg
		lamp(glass, WARM, 16)
		part(
			folder,
			Vector3.new(2, 0.4, 2),
			foot + Vector3.new(0, 11, 0),
			Color3.fromRGB(70, 90, 80),
			Enum.Material.Metal
		)
		tops[i + 1] = foot + Vector3.new(0, 8.6, 0)
	end
	for i = 1, #tops do
		local a, b = tops[i], tops[i % #tops + 1]
		for k = 1, 5 do
			local t = k / 6
			local at = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.2, 0)
			decor(ball(folder, Vector3.new(0.5, 0.5, 0.5), at, PASTELS[(i + k) % #PASTELS + 1], Enum.Material.Neon))
		end
	end
	-- Benches around the tree, facing it.
	for i = 0, 5 do
		local at = CFrame.lookAt(polar(math.rad(30 + i * 60), 27), Vector3.zero)
		part(folder, Vector3.new(5, 0.4, 1.6), at * CFrame.new(0, 1.4, 0), WOOD, Enum.Material.WoodPlanks)
		part(folder, Vector3.new(5, 1.4, 0.3), at * CFrame.new(0, 2.3, 0.75), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -2, 2 } do
			part(folder, Vector3.new(0.4, 1.2, 1.4), at * CFrame.new(x, 0.6, 0), DARK_WOOD, Enum.Material.Metal)
		end
	end
end

local function eggTree()
	local tree = Models.spawn("eggTree", folder, Vector3.new(0, 0.3, 0), 1, 0)
	if tree == nil then
		-- Part-built stand-in: a curvy trunk and a round crown.
		pillar(folder, Vector3.new(0, 0, 0), 22, 4, Color3.fromRGB(130, 90, 60), Enum.Material.Wood)
		local rng = Random.new(77)
		for _ = 1, 7 do
			local at = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(24, 34), rng:NextNumber(-10, 10))
			ball(folder, Vector3.one * rng:NextNumber(14, 20), at, LEAF, Enum.Material.LeafyGrass)
		end
	end
	-- Six giant pastel eggs hanging from the branches, lit softly at night.
	for i = 0, 5 do
		local at = polar(math.rad(30 + i * 60), 14) + Vector3.new(0, 19 + (i % 2) * 2, 0)
		decor(
			part(
				folder,
				Vector3.new(0.2, 4, 0.2),
				at + Vector3.new(0, 3.6, 0),
				Color3.fromRGB(230, 210, 170),
				Enum.Material.Fabric
			)
		)
		local egg = decor(ball(folder, Vector3.new(3, 4, 3), at, PASTELS[i + 1], Enum.Material.SmoothPlastic))
		egg.Name = "HangingEgg"
		lamp(egg, PASTELS[i + 1], 12)
	end
end

-- Egg cart, boards, Wild Meadow gate ----------------------------------------------------------

local function cart()
	local cf = CFrame.lookAt(CART, CART + Vector3.new(0, 0, 1)) -- faces south, local -Z is the front
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local body = part(folder, Vector3.new(18, 3, 8), at(0, 3, 0), WOOD, Enum.Material.WoodPlanks)
	body.Name = "EggCart"
	part(folder, Vector3.new(18.6, 0.4, 8.6), at(0, 4.7, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	for _, x in { -6.5, 6.5 } do
		for _, z in { -4.3, 4.3 } do
			local wheel =
				part(folder, Vector3.new(0.6, 3, 3), at(x, 1.5, z), Color3.fromRGB(200, 70, 60), Enum.Material.Wood)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	-- Striped awning on four posts.
	for _, x in { -8.6, 8.6 } do
		for _, z in { -3.8, 3.8 } do
			part(folder, Vector3.new(0.5, 6, 0.5), at(x, 7.9, z), WHITE, Enum.Material.Wood)
		end
	end
	for k = 0, 7 do
		local colour = if k % 2 == 0 then Color3.fromRGB(230, 60, 70) else WHITE
		decor(
			part(
				folder,
				Vector3.new(2.4, 0.3, 10),
				at(-8.4 + k * 2.4, 11.2, 0) * CFrame.Angles(math.rad(-10), 0, 0),
				colour,
				Enum.Material.Fabric
			)
		)
	end
	-- Five pedestals with display eggs.
	local eggs = { "meadow", "forest", "sunset", "moon", "star" }
	for k, id in eggs do
		local x = -7 + (k - 1) * 3.5
		pillar(folder, (at(x, 4.9, -1.5)).Position, 1, 0.9, PASTELS[k], Enum.Material.SmoothPlastic)
		Plots.egg(folder, id, at(x, 7.4, -1.5))
	end
	-- Chalkboard sign "EGGS" on top.
	local sign = part(folder, Vector3.new(7, 2.2, 0.3), at(0, 13, -2), Color3.fromRGB(45, 60, 50), Enum.Material.Slate)
	local gui = surface(sign)
	local label = textLabel(gui, "EGGS", WHITE)
	label.Size = UDim2.fromScale(1, 1)
	-- The prompt opens the client's EGGS panel; it changes nothing on the server.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Shop"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Egg Cart"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
end

-- A wooden board on two posts facing `toward`; returns the board part.
local function boardOnPosts(at: Vector3, toward: Vector3, width: number, height: number): Part
	local cf = CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z))
	for _, x in { -width / 2 + 0.6, width / 2 - 0.6 } do
		part(
			folder,
			Vector3.new(0.7, height + 3, 0.7),
			cf * CFrame.new(x, (height + 3) / 2, 0.5),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	local board = part(
		folder,
		Vector3.new(width, height, 0.5),
		cf * CFrame.new(0, 3 + height / 2, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	return board
end

local function boards()
	-- Forecast board (GDD F): the current window and the next two.
	local forecast = boardOnPosts(Vector3.new(30, 0, 15), Vector3.new(0, 0, 40), 12, 8)
	forecast.Name = "ForecastBoard"
	local gui = surface(forecast)
	local layout = Instance.new("UIListLayout")
	layout.Parent = gui
	local title = textLabel(gui, "WEATHER", Color3.fromRGB(255, 235, 140))
	title.Size = UDim2.fromScale(1, 0.25)
	for k = 1, 3 do
		local row = textLabel(gui, "", WHITE)
		row.Size = UDim2.fromScale(1, 0.25)
		forecastRows[k] = row
	end
	-- Top Gardens board with a leaf garland.
	local top = boardOnPosts(Vector3.new(0, 0, -34), Vector3.new(0, 0, 0), 14, 10)
	top.Name = "TopGardens"
	local garland = top.CFrame * CFrame.new(0, 5.2, -0.3)
	for k = -3, 3 do
		decor(
			ball(
				folder,
				Vector3.new(1.6, 1.3, 1.3),
				garland * CFrame.new(k * 2.1, 0, 0),
				LEAF,
				Enum.Material.LeafyGrass
			)
		)
		if k % 2 == 0 then
			decor(ball(folder, Vector3.new(0.8, 0.8, 0.8), garland * CFrame.new(k * 2.1, -0.3, -0.6), FLOWERS[k + 4]))
		end
	end
	local topGui = surface(top)
	local heading = textLabel(topGui, "TOP GARDENS", Color3.fromRGB(255, 235, 140))
	heading.Size = UDim2.fromScale(1, 0.16)
	local rows = textLabel(topGui, "", WHITE)
	rows.Size = UDim2.fromScale(0.9, 0.8)
	rows.Position = UDim2.fromScale(0.05, 0.18)
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	boardRows = rows
end

local function meadowGate()
	-- Wooden arch with vines and flowers at (-30, 0, 15), leading west to the wildflower field.
	local gate = Vector3.new(-30, 0, 15)
	local field = Vector3.new(-58, 0, 9)
	local cf = CFrame.lookAt(gate, Vector3.new(field.X, 0, field.Z))
	for _, x in { -4, 4 } do
		part(folder, Vector3.new(0.9, 8, 0.9), cf * CFrame.new(x, 4, 0), WOOD, Enum.Material.Wood)
		decor(part(folder, Vector3.new(1.1, 7, 0.4), cf * CFrame.new(x, 4, -0.4), LEAF, Enum.Material.LeafyGrass))
	end
	for k = -1, 1 do
		part(
			folder,
			Vector3.new(3.4, 0.8, 1),
			cf * CFrame.new(k * 2.9, 8.4 - math.abs(k) * 0.6, 0) * CFrame.Angles(0, 0, math.rad(-k * 15)),
			WOOD,
			Enum.Material.Wood
		)
	end
	for k = -2, 2 do
		decor(
			ball(folder, Vector3.new(1, 1, 1), cf * CFrame.new(k * 1.8, 9.2 - math.abs(k) * 0.5, -0.4), FLOWERS[k + 3])
		)
	end
	local mid = (gate + field) / 2
	part(
		folder,
		Vector3.new(6, 0.2, (field - gate).Magnitude),
		CFrame.lookAt(mid + Vector3.new(0, 0.12, 0), field + Vector3.new(0, 0.12, 0)),
		Color3.fromRGB(235, 215, 165),
		Enum.Material.Sand
	)
	-- The fenced wildflower field where released creatures run off.
	local fieldFolder = Instance.new("Folder")
	fieldFolder.Name = "WildMeadow"
	fieldFolder.Parent = folder
	part(
		fieldFolder,
		Vector3.new(18, 0.2, 18),
		field + Vector3.new(0, 0.1, 0),
		Color3.fromRGB(140, 210, 110),
		Enum.Material.LeafyGrass
	)
	for _, side in { Vector3.new(0, 0, -9), Vector3.new(0, 0, 9), Vector3.new(-9, 0, 0), Vector3.new(9, 0, 0) } do
		local size = if side.X == 0 then Vector3.new(18, 0.4, 0.3) else Vector3.new(0.3, 0.4, 18)
		for _, y in { 1.2, 2.4 } do
			decor(part(fieldFolder, size, field + side + Vector3.new(0, y, 0), WHITE, Enum.Material.Wood))
		end
		part(
			fieldFolder,
			Vector3.new(0.6, 3, 0.6),
			field + side * 1 + Vector3.new(0, 1.5, 0),
			WHITE,
			Enum.Material.Wood
		)
	end
	local rng = Random.new(31)
	for _ = 1, 40 do
		local at = field + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		local h = rng:NextNumber(0.8, 1.6)
		decor(pillar(fieldFolder, at, h, 0.1, Color3.fromRGB(80, 160, 70), Enum.Material.SmoothPlastic))
		local s = rng:NextNumber(0.7, 1.1)
		decor(
			ball(
				fieldFolder,
				Vector3.new(s, s * 0.8, s),
				at + Vector3.new(0, h, 0),
				FLOWERS[rng:NextInteger(1, #FLOWERS)]
			)
		)
	end
end

-- Paths, meadows, trees ------------------------------------------------------------------------

-- True when `pos` is inside a plot (plus margin), the plaza, a path, the river or the meadow field.
local function blocked(pos: Vector3, margin: number): boolean
	local r = Vector3.new(pos.X, 0, pos.Z).Magnitude
	if r < PLAZA + margin or math.abs(r - RIVER) < 11 + margin then
		return true
	end
	for n = 1, 6 do
		local theta = math.rad((n - 1) * 60)
		local centre = polar(theta, 100)
		local frame = CFrame.lookAt(centre, Vector3.zero)
		local p = frame:PointToObjectSpace(pos)
		if math.abs(p.X) < 31 + margin and math.abs(p.Z) < 31 + margin then
			return true
		end
		-- Path from the plaza to the gate (local z from -31 to -55).
		if math.abs(p.X) < 5 + margin and p.Z < -31 and p.Z > -60 then
			return true
		end
	end
	return (pos - Vector3.new(-58, 0, 9)).Magnitude < 14 + margin or (pos - Vector3.new(-44, 0, 12)).Magnitude < 8
end

local function paths()
	for n = 1, 6 do
		local theta = math.rad((n - 1) * 60)
		local mid = polar(theta, 57)
		local cf = CFrame.lookAt(mid, Vector3.zero)
		part(
			folder,
			Vector3.new(8, 0.2, 26),
			cf * CFrame.new(0, 0.1, 0),
			Color3.fromRGB(235, 215, 165),
			Enum.Material.Sand
		)
		for _, x in { -4.5, 4.5 } do
			part(
				folder,
				Vector3.new(1, 0.35, 26),
				cf * CFrame.new(x, 0.17, 0),
				Color3.fromRGB(170, 165, 155),
				Enum.Material.Cobblestone
			)
		end
	end
end

local function meadows()
	local rng = Random.new(2024)
	local flowers = 0
	local clusters = 0
	local attempts = 0
	local meadow = Instance.new("Folder")
	meadow.Name = "Meadows"
	meadow.Parent = folder
	while clusters < 45 and flowers < 520 and attempts < 2000 do
		attempts += 1
		local centre = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(50, 150))
		if blocked(centre, 4) then
			continue
		end
		clusters += 1
		local colour = FLOWERS[rng:NextInteger(1, #FLOWERS)]
		for _ = 1, rng:NextInteger(7, 12) do
			local at = centre + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			if not blocked(at, 1) then
				local h = rng:NextNumber(0.8, 1.7)
				decor(pillar(meadow, at, h, 0.1, Color3.fromRGB(80, 160, 70), Enum.Material.SmoothPlastic))
				local s = rng:NextNumber(0.7, 1.2)
				decor(ball(meadow, Vector3.new(s, s * 0.8, s), at + Vector3.new(0, h, 0), colour))
				flowers += 1
			end
		end
		if clusters % 2 == 0 then
			local s = rng:NextNumber(3, 5)
			decor(
				ball(
					meadow,
					Vector3.new(s * 1.3, s, s * 1.3),
					centre + Vector3.new(4, s * 0.35, 3),
					LEAF,
					Enum.Material.LeafyGrass
				)
			)
		end
	end
	meadow:SetAttribute("Flowers", flowers)
end

local function blossomTrees()
	for i = 0, 15 do
		local at = polar(math.rad(11.25 + i * 22.5), 145)
		local tree = Models.spawn("sakura", folder, at, 1.5, i * 37)
		if tree then
			local petals = Instance.new("ParticleEmitter")
			petals.Color = ColorSequence.new(PASTELS[i % #PASTELS + 1]:Lerp(Color3.fromRGB(255, 190, 215), 0.5))
			petals.Size = NumberSequence.new(0.35)
			petals.Lifetime = NumberRange.new(4, 6)
			petals.Speed = NumberRange.new(1, 2)
			petals.Acceleration = Vector3.new(1.5, -1.2, 0.5)
			petals.Rotation = NumberRange.new(0, 360)
			petals.RotSpeed = NumberRange.new(-90, 90)
			petals.SpreadAngle = Vector2.new(180, 180)
			petals.Rate = 2
			petals.Parent = tree
		else
			Props.sakura(folder, at, Random.new(i))
		end
	end
end

local function bridges()
	for _, deg in { 30, 150, 270 } do
		local cf = CFrame.lookAt(polar(math.rad(deg), RIVER), Vector3.zero) -- local Z crosses the river
		for k = -1, 1 do
			local tilt = math.rad(k * 12)
			part(
				folder,
				Vector3.new(6, 0.6, 8.4),
				cf * CFrame.new(0, 1.6 - math.abs(k) * 0.9, k * 8) * CFrame.Angles(tilt, 0, 0),
				WOOD,
				Enum.Material.WoodPlanks
			)
		end
		for _, x in { -3.2, 3.2 } do
			part(folder, Vector3.new(0.4, 0.4, 24), cf * CFrame.new(x, 3.6, 0), WHITE, Enum.Material.Wood)
			for _, z in { -11, 0, 11 } do
				part(folder, Vector3.new(0.5, 3.4, 0.5), cf * CFrame.new(x, 1.9, z), WHITE, Enum.Material.Wood)
			end
		end
	end
end

local function windmill()
	local base = Vector3.new(0, 0, -215)
	local cf = CFrame.lookAt(base, Vector3.zero)
	for k = 0, 2 do
		local w = 12 - k * 2.5
		part(
			folder,
			Vector3.new(w, 10, w),
			cf * CFrame.new(0, 5 + k * 10, 0),
			Color3.fromRGB(215, 120, 95),
			Enum.Material.Brick
		)
	end
	part(folder, Vector3.new(8, 2, 8), cf * CFrame.new(0, 31, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	wedge(folder, Vector3.new(8, 5, 4), cf * CFrame.new(0, 34.5, -2), DARK_WOOD, Enum.Material.WoodPlanks)
	wedge(
		folder,
		Vector3.new(8, 5, 4),
		cf * CFrame.new(0, 34.5, 2) * CFrame.Angles(0, math.pi, 0),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	part(folder, Vector3.new(3, 5, 0.4), cf * CFrame.new(0, 2.5, -6.1), DARK_WOOD, Enum.Material.Wood)
	-- Sails, spun by CreatureFx about the pivot's Z axis (pointing at the plaza).
	local sails = Instance.new("Model")
	sails.Name = "Sails"
	local hub = pillar(sails, Vector3.zero, 2, 1.2, DARK_WOOD, Enum.Material.Wood)
	hub.Name = "Hub"
	hub.CFrame = cf * CFrame.new(0, 28, -5.5) * CFrame.Angles(0, math.pi / 2, 0)
	for k = 0, 3 do
		local arm = cf * CFrame.new(0, 28, -6.8) * CFrame.Angles(0, 0, k * math.pi / 2)
		part(sails, Vector3.new(0.6, 16, 0.4), arm * CFrame.new(0, 8, 0), WOOD, Enum.Material.Wood)
		part(
			sails,
			Vector3.new(3.2, 12, 0.2),
			arm * CFrame.new(1.9, 9, 0),
			Color3.fromRGB(250, 245, 230),
			Enum.Material.Fabric
		)
	end
	sails.WorldPivot = cf * CFrame.new(0, 28, -6.8) -- CreatureFx spins the pivot about its Z axis
	sails.Parent = folder
end

local function barn()
	local base = Vector3.new(190, 0, 60)
	local cf = CFrame.lookAt(base, Vector3.zero)
	local red = Color3.fromRGB(190, 50, 45)
	part(folder, Vector3.new(24, 14, 30), cf * CFrame.new(0, 7, 0), red, Enum.Material.Wood)
	-- Gable: a wedge's tall face is its +Z side, so each half rises toward the ridge.
	wedge(
		folder,
		Vector3.new(25, 8, 15.5),
		cf * CFrame.new(0, 18, -7.75),
		Color3.fromRGB(120, 60, 50),
		Enum.Material.WoodPlanks
	)
	wedge(
		folder,
		Vector3.new(25, 8, 15.5),
		cf * CFrame.new(0, 18, 7.75) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(120, 60, 50),
		Enum.Material.WoodPlanks
	)
	part(folder, Vector3.new(9, 10, 0.4), cf * CFrame.new(0, 5, -15.1), Color3.fromRGB(160, 40, 38), Enum.Material.Wood)
	for _, r in { 45, -45 } do
		part(
			folder,
			Vector3.new(0.6, 13, 0.3),
			cf * CFrame.new(0, 5, -15.4) * CFrame.Angles(0, 0, math.rad(r)),
			WHITE,
			Enum.Material.Wood
		)
	end
	for _, x in { -12, 12 } do
		part(folder, Vector3.new(0.6, 14, 0.6), cf * CFrame.new(x, 7, -15.1), WHITE, Enum.Material.Wood)
	end
	local silo = (cf * CFrame.new(18, 0, 6)).Position
	pillar(folder, silo, 26, 5, Color3.fromRGB(190, 195, 200), Enum.Material.Metal)
	ball(
		folder,
		Vector3.new(10, 10, 10),
		silo + Vector3.new(0, 26, 0),
		Color3.fromRGB(150, 165, 185),
		Enum.Material.Metal
	)
end

local function treeLine()
	local rng = Random.new(808)
	for i = 0, 59 do
		local angle = i / 60 * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
		local at = polar(angle, rng:NextNumber(225, 290))
		if (at - Vector3.new(0, 0, -215)).Magnitude < 25 or (at - Vector3.new(190, 0, 60)).Magnitude < 35 then
			continue
		end
		local h = rng:NextNumber(6, 10)
		decor(pillar(folder, at, h, 0.9, Color3.fromRGB(115, 80, 55), Enum.Material.Wood))
		local green = LEAF:Lerp(Color3.fromRGB(60, 130, 70), rng:NextNumber(0, 1))
		local s = rng:NextNumber(8, 12)
		decor(ball(folder, Vector3.new(s, s, s), at + Vector3.new(0, h + s * 0.3, 0), green, Enum.Material.LeafyGrass))
		decor(
			ball(
				folder,
				Vector3.new(s, s, s) * 0.65,
				at + Vector3.new(0, h + s * 0.85, 0),
				green:Lerp(WHITE, 0.1),
				Enum.Material.LeafyGrass
			)
		)
	end
end

-- Updaters -------------------------------------------------------------------------------------

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function weatherName(id: string): string
	for _, w in GardenConfig.WEATHERS do
		if w.id == id then
			return w.name
		end
	end
	return id
end

-- Top Gardens rows (Profiles.topIncome).
function World.board(rows: { { name: string, income: number } })
	if boardRows == nil then
		return
	end
	local lines = {}
	for i, row in rows do
		table.insert(lines, `{i}. {row.name}  {GardenRules.short(row.income)}/s`)
	end
	if #lines == 0 then
		table.insert(lines, "Grow your garden to join the board!")
	end
	boardRows.Text = table.concat(lines, "\n")
end

-- Forecast board and Moonfall lamps from the GardenStatus table.
function World.forecast(status: { [string]: any })
	local weather = status.weather
	if type(weather) ~= "string" then
		return
	end
	local now = os.time()
	local window = GardenConfig.WEATHER_WINDOW
	local toNext = window - now % window
	local kinds = status.forecast or {}
	local nowText = if weather == "clear"
		then `{WEATHER_ICON.clear} Now: Clear skies`
		else `{WEATHER_ICON[weather] or ""} Now: {weatherName(weather)} ({clock(status.weatherLeft or 0)})`
	if forecastRows[1] then
		forecastRows[1].Text = nowText
		forecastRows[2].Text =
			`{WEATHER_ICON[kinds[1]] or ""} Next: {weatherName(kinds[1] or "clear")} in {clock(toNext)}`
		forecastRows[3].Text =
			`{WEATHER_ICON[kinds[2]] or ""} Then: {weatherName(kinds[2] or "clear")} in {clock(toNext + window)}`
	end
	if weather ~= lastWeather then
		lastWeather = weather
		for _, l in lamps do
			l.Enabled = weather == "moonfall"
		end
	end
end

-- Builds the valley and the plots once (I4 budget: under 6,000 parts with the plots).
function World.build(): {
	cart: GardenRules.Vec3,
	board: (rows: { { name: string, income: number } }) -> (),
	forecast: (status: { [string]: any }) -> (),
}
	local root = Instance.new("Folder")
	root.Name = "Garden"
	root.Parent = Workspace
	lighting()
	ground()
	plaza()
	cart()
	boards()
	meadowGate()
	paths()
	meadows()
	bridges()
	windmill()
	barn()
	treeLine()
	folder.Parent = root
	Plots.build(root)
	eggTree() -- yields while the meshes load
	blossomTrees()
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	root:SetAttribute("Parts", parts)
	if parts > 6000 then
		warn(`[World] {parts} parts, over the 6,000 budget`)
	end
	print(`[World] Hatchling Valley built: {parts} parts`)
	World.board({})
	return {
		cart = { x = CART.X, y = CART.Y, z = CART.Z },
		board = World.board,
		forecast = World.forecast,
	}
end

return World
