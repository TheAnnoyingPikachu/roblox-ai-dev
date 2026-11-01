--!strict
-- The six garden plots (GDD I2, docs/architecture/garden.md 4.4): each plot shell is built once
-- (ground, gate, sign, 12 bed sites, 20 pad sites, decor), and `refresh` rebuilds only what changed
-- (eggs and bed locks, pad locks, creature models, sign text, fence style, prompt Enabled). Models
-- are views of the saved profile; nothing is ever read back from them. A free plot shows a small
-- display garden so the valley looks lived-in before anyone joins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar = Props.part, Props.pillar

type Profile = GardenConfig.Profile
type Vec3 = GardenRules.Vec3

local Plots = {}

local COUNT = 6
Plots.COUNT = COUNT -- GDD A: 6 players, 6 plots; Max Players must match
local HALF = 31 -- fence line; pads reach z = 30.5
local BED_ROWS = { -22, -14, -6 } -- local z, front row first
local BED_COLS = { -18, -6, 6, 18 }
local PAD_ROWS = { 7, 14, 21, 28 }
local PAD_COLS = { -20, -10, 0, 10, 20 }
local PEN_TOP = 0.3
local SOIL_TOP = 1.2
-- shortcut: generated creature fronts are assumed to be local -Z (they face the gate); the mesh
-- check shot was ambiguous, so look in Studio and set math.pi if they show their backs.
local CREATURE_YAW = 0

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(60, 45, 40)
local WOOD = Color3.fromRGB(170, 120, 80)
local SOIL = Color3.fromRGB(110, 75, 50)
local PASTELS = {
	Color3.fromRGB(255, 200, 220),
	Color3.fromRGB(200, 230, 255),
	Color3.fromRGB(255, 240, 180),
	Color3.fromRGB(210, 255, 210),
	Color3.fromRGB(230, 210, 255),
}
local FLOWERS = {
	Color3.fromRGB(255, 150, 190),
	Color3.fromRGB(255, 230, 120),
	Color3.fromRGB(190, 160, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 170, 120),
}

-- Egg looks (GDD I2): one stretched ball each; spots and sparkles are surface particles so the
-- client can scale the egg as one part.
type EggLook = { colour: Color3, material: Enum.Material, spots: Color3, glow: boolean }
local EGG_LOOKS: { [string]: EggLook } = {
	starter = {
		colour = Color3.fromRGB(255, 242, 210),
		material = Enum.Material.SmoothPlastic,
		spots = Color3.fromRGB(255, 140, 180),
		glow = false,
	},
	meadow = {
		colour = Color3.fromRGB(190, 240, 170),
		material = Enum.Material.SmoothPlastic,
		spots = WHITE,
		glow = false,
	},
	forest = {
		colour = Color3.fromRGB(110, 150, 80),
		material = Enum.Material.SmoothPlastic,
		spots = Color3.fromRGB(120, 80, 50),
		glow = false,
	},
	sunset = {
		colour = Color3.fromRGB(255, 160, 120),
		material = Enum.Material.SmoothPlastic,
		spots = Color3.fromRGB(255, 110, 170),
		glow = false,
	},
	moon = {
		colour = Color3.fromRGB(40, 50, 110),
		material = Enum.Material.SmoothPlastic,
		spots = Color3.fromRGB(255, 250, 200),
		glow = true,
	},
	star = {
		colour = Color3.fromRGB(255, 238, 180),
		material = Enum.Material.Foil,
		spots = Color3.fromRGB(255, 215, 110),
		glow = true,
	},
	celestial = {
		colour = Color3.fromRGB(255, 250, 230),
		material = Enum.Material.Foil,
		spots = Color3.fromRGB(255, 225, 140),
		glow = true,
	},
}

-- Fence styles (GDD H4).
type FenceStyle = { colours: { Color3 }, rail: Color3, material: Enum.Material, wall: boolean, round: boolean }
local FENCES: { [string]: FenceStyle } = {
	picket = { colours = { WHITE }, rail = WHITE, material = Enum.Material.Wood, wall = false, round = false },
	bamboo = {
		colours = { Color3.fromRGB(175, 195, 95), Color3.fromRGB(150, 175, 80) },
		rail = Color3.fromRGB(140, 160, 75),
		material = Enum.Material.Wood,
		wall = false,
		round = true,
	},
	stone = {
		colours = { Color3.fromRGB(160, 158, 150) },
		rail = Color3.fromRGB(190, 188, 180),
		material = Enum.Material.Cobblestone,
		wall = true,
		round = false,
	},
	hedge = {
		colours = { Color3.fromRGB(80, 150, 70) },
		rail = Color3.fromRGB(110, 175, 90),
		material = Enum.Material.LeafyGrass,
		wall = true,
		round = false,
	},
	crystal = {
		colours = { Color3.fromRGB(170, 220, 255), Color3.fromRGB(220, 190, 255) },
		rail = Color3.fromRGB(200, 235, 255),
		material = Enum.Material.Glass,
		wall = false,
		round = false,
	},
	golden = {
		colours = { Color3.fromRGB(255, 205, 70) },
		rail = Color3.fromRGB(255, 225, 120),
		material = Enum.Material.Foil,
		wall = false,
		round = true,
	},
	candy = {
		colours = { Color3.fromRGB(235, 50, 60), WHITE },
		rail = WHITE,
		material = Enum.Material.SmoothPlastic,
		wall = false,
		round = true,
	},
	rainbow = {
		colours = {
			Color3.fromRGB(255, 90, 90),
			Color3.fromRGB(255, 170, 70),
			Color3.fromRGB(255, 235, 90),
			Color3.fromRGB(110, 220, 110),
			Color3.fromRGB(90, 170, 255),
			Color3.fromRGB(150, 110, 255),
			Color3.fromRGB(230, 120, 255),
		},
		rail = WHITE,
		material = Enum.Material.SmoothPlastic,
		wall = false,
		round = true,
	},
}

-- Part-built stand-ins if a creature mesh fails to load (GDD I5): body, head and ears.
local FALLBACK: { [string]: Color3 } = {
	bunny = Color3.fromRGB(250, 240, 220),
	frog = Color3.fromRGB(120, 200, 100),
	pup = Color3.fromRGB(255, 210, 70),
	cat = Color3.fromRGB(230, 70, 80),
	owl = Color3.fromRGB(240, 140, 50),
	fox = Color3.fromRGB(110, 190, 110),
	turtle = Color3.fromRGB(70, 190, 180),
	lion = Color3.fromRGB(255, 170, 60),
	dragon = Color3.fromRGB(200, 170, 255),
}

type BedView = {
	model: Model,
	border: Part,
	soil: Part,
	lockSign: Part,
	lockGui: SurfaceGui,
	hatch: ProximityPrompt,
	water: ProximityPrompt,
	egg: BasePart?,
	eggId: string,
	eggMesh: boolean, -- `egg` was built from the Blender model
	key: string,
}
type PadView = { part: Part, coins: { Part }, gui: BillboardGui, label: TextLabel, locked: boolean?, pending: number }
type CreatureView = { key: string, model: Instance? }
type PlotView = {
	n: number,
	model: Model,
	frame: CFrame,
	beds: { BedView },
	pads: { PadView },
	padCentres: { [number]: Vec3 },
	bedCentres: { Vec3 },
	creatures: { [number]: CreatureView },
	creatureFolder: Folder,
	fence: Model,
	fenceStyle: string,
	signTitle: TextLabel,
	signInfo: TextLabel,
	signKey: string,
	ownerName: string,
}

local views: { PlotView } = {}
local holding = Instance.new("Folder") -- creatures are set up here before they replicate
-- Species whose mesh the warm-up in Plots.build loaded. Others get the part fallback at once, so a
-- failed or slow mesh never yields the 1 Hz refresh or retries (as Night's Enemies.warmed).
local warmed: { [string]: boolean } = {}
local promptEvent = Instance.new("BindableEvent")
Plots.prompts = promptEvent.Event -- (player, plot, bed, kind: "Hatch" | "Water")

local function vec(v: Vector3): Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

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

local function textLabel(parent: Instance, text: string, colour: Color3, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
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

local function surface(board: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	return gui
end

local function frameOf(n: number): CFrame
	local theta = math.rad((n - 1) * 60)
	local centre = Vector3.new(100 * math.sin(theta), 0, -100 * math.cos(theta))
	return CFrame.lookAt(centre, Vector3.zero) -- local -Z faces the plaza
end

-- The egg's Blender model at `cframe`, named Egg for HatchFx, or nil while it has no uploaded id.
-- Yields on the first load of each egg.
function Plots.eggModel(parent: Instance, id: string, cframe: CFrame): MeshPart?
	local mesh = Models.nightPart(`egg_{id}`, parent, cframe.Position)
	if mesh then
		mesh.Name = "Egg"
		mesh.CFrame = cframe
		decor(mesh)
	end
	return mesh
end

-- A new egg of kind `id` (also used for the cart's display eggs). Never yields, because
-- Plots.refresh must not: the model only once it is loaded, else the part egg.
function Plots.egg(parent: Instance, id: string, cframe: CFrame): BasePart
	if Models.nightReady(`egg_{id}`) then
		local mesh = Plots.eggModel(parent, id, cframe)
		if mesh then
			return mesh
		end
	end
	local look = EGG_LOOKS[id] or EGG_LOOKS.meadow
	local egg = decor(ball(parent, Vector3.new(2.2, 3, 2.2), cframe, look.colour, look.material))
	egg.Name = "Egg"
	local spots = Instance.new("ParticleEmitter")
	spots.Shape = Enum.ParticleEmitterShape.Sphere
	spots.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	spots.Color = ColorSequence.new(look.spots)
	spots.Size = NumberSequence.new(if look.glow then 0.18 else 0.28)
	spots.Speed = NumberRange.new(0)
	spots.Lifetime = NumberRange.new(3, 5)
	spots.Rate = 3
	spots.LockedToPart = true
	spots.LightEmission = if look.glow then 1 else 0
	spots.Parent = egg
	if id == "star" or id == "celestial" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 230, 140)
		sparkles.Parent = egg
	end
	return egg
end

-- Fence -------------------------------------------------------------------------------------

local function buildFence(view: PlotView, styleId: string)
	view.fence:ClearAllChildren()
	view.fenceStyle = styleId
	local style = FENCES[styleId] or FENCES.picket
	local segments = {
		{ Vector2.new(-HALF, -HALF), Vector2.new(-5, -HALF) },
		{ Vector2.new(5, -HALF), Vector2.new(HALF, -HALF) },
		{ Vector2.new(-HALF, HALF), Vector2.new(HALF, HALF) },
		{ Vector2.new(-HALF, -HALF), Vector2.new(-HALF, HALF) },
		{ Vector2.new(HALF, -HALF), Vector2.new(HALF, HALF) },
	}
	local colourIndex = 0
	for _, seg in segments do
		local a, b = seg[1], seg[2]
		local length = (b - a).Magnitude
		local mid = (a + b) / 2
		local alongZ = a.X == b.X
		local rotation = if alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
		local at = function(y: number): CFrame
			return view.frame * CFrame.new(mid.X, y, mid.Y) * rotation
		end
		if style.wall then
			part(view.fence, Vector3.new(length, 3.4, 1.6), at(1.9), style.colours[1], style.material)
			part(view.fence, Vector3.new(length + 0.4, 0.6, 2), at(3.9), style.rail, style.material)
		else
			local rails = { 1.5, 3.1 }
			for _, y in rails do
				decor(part(view.fence, Vector3.new(length, 0.35, 0.3), at(y), style.rail, style.material))
			end
			local count = math.ceil(length / 5.5)
			for k = 0, count do
				local p2 = a:Lerp(b, k / count)
				colourIndex += 1
				local colour = style.colours[(colourIndex - 1) % #style.colours + 1]
				local post = if style.round
					then pillar(
						view.fence,
						(view.frame * CFrame.new(p2.X, 0.2, p2.Y)).Position,
						4.2,
						0.45,
						colour,
						style.material
					)
					else part(
						view.fence,
						Vector3.new(0.8, 4.2, 0.8),
						view.frame * CFrame.new(p2.X, 2.3, p2.Y),
						colour,
						style.material
					)
				if styleId == "crystal" then
					post.Transparency = 0.25
				end
			end
		end
	end
end

-- Shell ---------------------------------------------------------------------------------------

local function buildBed(view: PlotView, beds: Folder, i: number)
	local row = math.ceil(i / 4)
	local col = (i - 1) % 4 + 1
	local x, z = BED_COLS[col], BED_ROWS[row]
	local model = Instance.new("Model")
	model.Name = `Bed{i}`
	local border =
		part(model, Vector3.new(8, 0.8, 8), view.frame * CFrame.new(x, 0.6, z), WOOD, Enum.Material.WoodPlanks)
	local soil = part(model, Vector3.new(7, 0.2, 7), view.frame * CFrame.new(x, 1.1, z), SOIL, Enum.Material.Ground)
	soil.Name = "Soil"
	local lockSign = decor(
		part(
			model,
			Vector3.new(3.4, 1.3, 0.2),
			view.frame * CFrame.new(x, 2.1, z - 3.2) * CFrame.Angles(math.rad(-15), 0, 0),
			Color3.fromRGB(250, 235, 200),
			Enum.Material.Wood
		)
	)
	local lockGui = surface(lockSign, Enum.NormalId.Front)
	textLabel(lockGui, "", Color3.fromRGB(255, 220, 90), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	local prompts = {}
	for _, kind in { "Hatch", "Water" } do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = kind
		prompt.ActionText = kind
		prompt.KeyboardKeyCode = if kind == "Hatch" then Enum.KeyCode.E else Enum.KeyCode.R
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = soil
		prompt.Triggered:Connect(function(player: Player)
			promptEvent:Fire(player, view.n, i, kind)
		end)
		prompts[kind] = prompt
	end
	model.Parent = beds
	view.beds[i] = {
		model = model,
		border = border,
		soil = soil,
		lockSign = lockSign,
		lockGui = lockGui,
		hatch = prompts.Hatch,
		water = prompts.Water,
		egg = nil,
		eggId = "",
		eggMesh = false,
		key = "",
	}
	view.bedCentres[i] = vec((view.frame * CFrame.new(x, SOIL_TOP, z)).Position)
end

local function buildPad(view: PlotView, pads: Folder, i: number)
	local row = math.ceil(i / 5)
	local col = (i - 1) % 5 + 1
	local centre = (view.frame * CFrame.new(PAD_COLS[col], PEN_TOP, PAD_ROWS[row])).Position
	local pad = pillar(pads, centre, 0.4, 2.5, PASTELS[(i - 1) % #PASTELS + 1], Enum.Material.SmoothPlastic)
	pad.Name = `Pad{i}`
	pad.CanCollide = false
	pad:SetAttribute("Pending", 0)
	local coins = {}
	for k, offset in { Vector3.new(1.4, 0, 1), Vector3.new(-1.3, 0, 1.2), Vector3.new(0.2, 0, -1.5) } do
		local coin = decor(
			pillar(
				pad,
				centre + offset + Vector3.new(0, 0.4, 0),
				0.25 * k,
				0.6,
				Color3.fromRGB(255, 200, 60),
				Enum.Material.Metal
			)
		)
		coin.Transparency = 1
		coins[k] = coin
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Parent = pad
	local label = textLabel(gui, "", Color3.fromRGB(255, 230, 120), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	view.pads[i] = { part = pad, coins = coins, gui = gui, label = label, locked = nil, pending = 0 }
	view.padCentres[i] = vec(centre + Vector3.new(0, 0.2, 0))
end

local function buildDecor(view: PlotView, parent: Instance)
	local f = view.frame
	local function at(x: number, y: number, z: number): CFrame
		return f * CFrame.new(x, y, z)
	end
	-- Ground: lawn, pen meadow and the cobble path from the gate to the pen.
	part(
		parent,
		Vector3.new(HALF * 2, 0.2, HALF * 2),
		at(0, 0.1, 0),
		Color3.fromRGB(150, 210, 120),
		Enum.Material.Grass
	)
	part(
		parent,
		Vector3.new(HALF * 2 - 2, 0.1, HALF - 1),
		at(0, 0.25, HALF / 2),
		Color3.fromRGB(125, 200, 110),
		Enum.Material.LeafyGrass
	)
	part(
		parent,
		Vector3.new(4, 0.1, HALF),
		at(0, 0.26, -HALF / 2),
		Color3.fromRGB(190, 180, 165),
		Enum.Material.Cobblestone
	)
	-- Gate arch with flowers and fairy lights.
	for _, x in { -5.5, 5.5 } do
		part(parent, Vector3.new(1, 8, 1), at(x, 4.2, -HALF), WHITE, Enum.Material.Wood)
	end
	part(parent, Vector3.new(12.5, 1, 1.2), at(0, 8.6, -HALF), WHITE, Enum.Material.Wood)
	for k = -1, 1 do
		decor(
			ball(parent, Vector3.new(1.4, 1.4, 1.4), at(k * 4, 9.3, -HALF), FLOWERS[k + 2], Enum.Material.SmoothPlastic)
		)
	end
	for k = -2, 2 do
		local sag = 7.6 - (2 - math.abs(k)) * 0.25
		decor(
			ball(
				parent,
				Vector3.new(0.45, 0.45, 0.45),
				at(k * 2.2, sag, -HALF - 0.4),
				PASTELS[k + 3],
				Enum.Material.Neon
			)
		)
	end
	-- Sign beside the gate, facing the plaza.
	for _, x in { 11, 19 } do
		part(parent, Vector3.new(0.6, 6, 0.6), at(x, 3.2, -HALF - 2.5), WOOD, Enum.Material.Wood)
	end
	local board = part(
		parent,
		Vector3.new(10, 6, 0.4),
		at(15, 5.2, -HALF - 2.5),
		Color3.fromRGB(250, 235, 200),
		Enum.Material.WoodPlanks
	)
	board.Name = "Sign"
	board.Parent = view.model -- Workspace.Garden.Plots.Plot<n>.Sign (garden.md 4.4)
	local gui = surface(board, Enum.NormalId.Front)
	view.signTitle = textLabel(gui, "", WHITE, UDim2.fromScale(0.94, 0.42), UDim2.fromScale(0.03, 0.05))
	view.signInfo =
		textLabel(gui, "", Color3.fromRGB(255, 225, 110), UDim2.fromScale(0.94, 0.42), UDim2.fromScale(0.03, 0.52))
	-- Mailbox outside the gate.
	part(parent, Vector3.new(0.5, 3.4, 0.5), at(-9, 1.9, -HALF - 2), WOOD, Enum.Material.Wood)
	part(
		parent,
		Vector3.new(1.4, 1.2, 2),
		at(-9, 4.1, -HALF - 2),
		Color3.fromRGB(120, 170, 255),
		Enum.Material.SmoothPlastic
	)
	decor(
		part(
			parent,
			Vector3.new(0.15, 0.9, 0.5),
			at(-8.2, 4.5, -HALF - 2),
			Color3.fromRGB(240, 70, 70),
			Enum.Material.SmoothPlastic
		)
	)
	-- Red shed at the back-left corner (seen from the gate).
	part(parent, Vector3.new(6.5, 5, 6), at(26.5, 2.7, 26.5), Color3.fromRGB(205, 70, 60), Enum.Material.Wood)
	for _, side in { -1, 1 } do
		local roof = Instance.new("WedgePart")
		roof.Anchored = true
		roof.Size = Vector3.new(7.5, 2.4, 3.5)
		roof.CFrame = at(26.5, 6.4, 26.5 + side * 1.75) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
		roof.Color = Color3.fromRGB(110, 80, 70)
		roof.Material = Enum.Material.WoodPlanks
		roof.Parent = parent
	end
	decor(part(parent, Vector3.new(2.2, 3.4, 0.2), at(26.5, 1.9, 23.4), WHITE, Enum.Material.Wood))
	-- Water trough between the beds and the pen.
	part(parent, Vector3.new(2.6, 1.4, 7), at(-27.5, 0.9, 0.5), WOOD, Enum.Material.WoodPlanks)
	local water = decor(
		part(parent, Vector3.new(2, 0.2, 6.4), at(-27.5, 1.5, 0.5), Color3.fromRGB(110, 185, 255), Enum.Material.Glass)
	)
	water.Transparency = 0.25
	-- Flower borders along the front and side fences.
	local rng = Random.new(view.n * 97)
	local borders = {
		{ Vector2.new(-29.5, -29.5), Vector2.new(-8, -29.5) },
		{ Vector2.new(8, -29.5), Vector2.new(29.5, -29.5) },
		{ Vector2.new(-29.5, -27), Vector2.new(-29.5, -4) },
		{ Vector2.new(29.5, -27), Vector2.new(29.5, -4) },
	}
	for _, b in borders do
		local a, c = b[1], b[2]
		local mid = (a + c) / 2
		local alongZ = a.X == c.X
		local size = if alongZ
			then Vector3.new(1.4, 0.4, (c - a).Magnitude)
			else Vector3.new((c - a).Magnitude, 0.4, 1.4)
		decor(part(parent, size, at(mid.X, 0.4, mid.Y), Color3.fromRGB(95, 65, 45), Enum.Material.Ground))
		for k = 0, 8 do
			local p2 = a:Lerp(c, k / 8)
			local s = rng:NextNumber(0.9, 1.3)
			decor(
				ball(
					parent,
					Vector3.new(s, s, s),
					at(p2.X, 0.9, p2.Y),
					FLOWERS[rng:NextInteger(1, #FLOWERS)],
					Enum.Material.SmoothPlastic
				)
			)
		end
	end
end

local function buildPlot(root: Folder, n: number)
	local model = Instance.new("Model")
	model.Name = `Plot{n}`
	model:SetAttribute("Owner", 0)
	model:SetAttribute("Gate", "open")
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = model
	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = model
	local view: PlotView = {
		n = n,
		model = model,
		frame = frameOf(n),
		beds = {},
		pads = {},
		padCentres = {},
		bedCentres = {},
		creatures = {},
		creatureFolder = creatures,
		fence = fence,
		fenceStyle = "",
		signTitle = nil :: any,
		signInfo = nil :: any,
		signKey = "",
		ownerName = "",
	}
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = model
	buildDecor(view, decorFolder)
	local beds = Instance.new("Folder")
	beds.Name = "Beds"
	beds.Parent = model
	for i = 1, GardenConfig.BEDS.max do
		buildBed(view, beds, i)
	end
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = model
	for i = 1, GardenConfig.PEN.max do
		buildPad(view, pads, i)
	end
	buildFence(view, "picket")
	model.Parent = root
	views[n] = view
end

-- Views -----------------------------------------------------------------------------------------

local function nameOf(c: GardenConfig.Creature): string
	local words = {}
	local size = GardenConfig.size(c.z)
	local mutation = GardenConfig.mutation(c.m)
	local species = GardenConfig.species(c.s)
	if size and c.z ~= "normal" then
		table.insert(words, size.name)
	end
	if mutation and c.m ~= "normal" then
		table.insert(words, mutation.name)
	end
	table.insert(words, if species then species.name else c.s)
	return table.concat(words, " ")
end

local function tag(target: BasePart, c: GardenConfig.Creature, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(170, 46)
	gui.StudsOffset = Vector3.new(0, height / 2 + 1.3, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Parent = target
	textLabel(gui, nameOf(c), WHITE, UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0))
	local rarity = GardenConfig.RARITIES[GardenConfig.rarityIndex(c.s)]
	local colour = if rarity then Color3.fromRGB(rarity.colour[1], rarity.colour[2], rarity.colour[3]) else WHITE
	textLabel(gui, if rarity then rarity.name else "", colour, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.58))
end

local function fallbackCreature(c: GardenConfig.Creature, base: Vector3, facing: CFrame, scale: number): Model
	local colour = FALLBACK[c.s] or WHITE
	local model = Instance.new("Model")
	local s = scale
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(base) * facing * CFrame.new(x * s, y * s, z * s)
	end
	local body = ball(model, Vector3.new(2.6, 2.3, 2.8) * s, at(0, 1.2, 0), colour)
	ball(model, Vector3.new(2, 2, 2) * s, at(0, 2.8, -0.9), colour)
	for _, x in { -0.6, 0.6 } do
		ball(model, Vector3.new(0.7, 0.9, 0.5) * s, at(x, 3.8, -0.9), colour:Lerp(WHITE, 0.3))
		ball(model, Vector3.new(0.35, 0.45, 0.2) * s, at(x * 0.7, 2.95, -1.85), INK)
	end
	for _, p in model:GetChildren() do
		decor(p :: BasePart)
	end
	model.PrimaryPart = body
	return model
end

local function makeCreature(view: PlotView, c: GardenConfig.Creature): Instance
	local size = GardenConfig.size(c.z)
	local scale = if size then size.scale else 1
	local centre = view.padCentres[c.placed]
	local base = Vector3.new(centre.x, centre.y, centre.z)
	local facing = view.frame.Rotation * CFrame.Angles(0, CREATURE_YAW, 0)
	local model: Instance
	local mesh = if warmed[c.s] then Models.spawn(c.s, holding, base, scale) else nil
	if mesh then
		mesh.CFrame = CFrame.new(base + Vector3.new(0, mesh.Size.Y / 2, 0)) * facing
		mesh.CanCollide = false -- the owner walks onto the pad to bank it
		mesh.CanTouch = false
		tag(mesh, c, mesh.Size.Y)
		model = mesh
	else
		local fallback = fallbackCreature(c, base, facing, scale)
		tag(fallback.PrimaryPart :: BasePart, c, 4.4 * scale)
		model = fallback
	end
	model.Name = tostring(c.id)
	model:SetAttribute("Id", c.id)
	model:SetAttribute("S", c.s)
	model:SetAttribute("M", c.m)
	model:SetAttribute("Z", c.z)
	model:SetAttribute("Pad", c.placed)
	model:SetAttribute("Hatched", Workspace:GetServerTimeNow())
	return model
end

-- The key includes whether the mesh is warmed, so a fallback built before the warm-up finished is
-- rebuilt as the mesh on the next refresh.
local function creatureKey(c: GardenConfig.Creature): string
	return `{c.s}{c.m}{c.z}{c.placed}{if warmed[c.s] then "w" else ""}`
end

local function refreshCreatures(view: PlotView, profile: Profile)
	local want: { [number]: GardenConfig.Creature } = {}
	for _, c in profile.creatures do
		if c.placed >= 1 and c.placed <= GardenConfig.PEN.max then
			want[c.id] = c
		end
	end
	for id, cv in view.creatures do
		local c = want[id]
		if c == nil or creatureKey(c) ~= cv.key then
			if cv.model then
				cv.model:Destroy()
			end
			view.creatures[id] = nil
		end
	end
	for id, c in want do
		if view.creatures[id] == nil then
			local record: CreatureView = { key = creatureKey(c), model = nil }
			view.creatures[id] = record
			local model = makeCreature(view, c)
			if view.creatures[id] == record then
				record.model = model
				model.Parent = view.creatureFolder
			else
				model:Destroy()
			end
		end
	end
end

local function refreshBed(view: PlotView, i: number, profile: Profile, now: number, owned: boolean)
	local bv = view.beds[i]
	local state = GardenRules.bedState(profile, i, now)
	local bed = profile.beds[i]
	local egg = if bed and state ~= "locked" then bed.egg else ""
	-- In the key, so a part egg built before its model loaded becomes the model on the next refresh.
	local eggMesh = Models.nightReady(`egg_{egg}`)
	local key = `{state}|{egg}|{bed and bed.planted or 0}|{bed and bed.ready or 0}|{owned}|{eggMesh}`
	if key == bv.key then
		return
	end
	bv.key = key
	local locked = state == "locked"
	bv.model:SetAttribute("Locked", locked)
	bv.model:SetAttribute("Egg", egg)
	bv.model:SetAttribute("Planted", if bed then bed.planted else 0)
	bv.model:SetAttribute("Ready", if bed then bed.ready else 0)
	bv.border.Material = if locked then Enum.Material.Fabric else Enum.Material.WoodPlanks
	bv.border.Color = if locked then Color3.fromRGB(205, 175, 120) else WOOD
	bv.soil.Color = if locked then Color3.fromRGB(150, 130, 110) else SOIL
	local cost = GardenConfig.BED_COSTS[i]
	bv.lockSign.Transparency = if locked and cost then 0 else 1
	bv.lockGui.Enabled = locked and cost ~= nil
	local label = bv.lockGui:FindFirstChildOfClass("TextLabel")
	if label and cost then
		label.Text = `{GardenRules.short(cost)} coins`
	end
	if egg ~= bv.eggId or eggMesh ~= bv.eggMesh then
		if bv.egg then
			bv.egg:Destroy()
			bv.egg = nil
		end
		bv.eggId = egg
		bv.eggMesh = eggMesh
		if egg ~= "" then
			local centre = view.bedCentres[i]
			bv.egg = Plots.egg(bv.model, egg, CFrame.new(centre.x, centre.y + 1.3, centre.z) * view.frame.Rotation)
		end
	end
	local eggConfig = GardenConfig.egg(egg)
	bv.hatch.ObjectText = if eggConfig then eggConfig.name else ""
	bv.water.ObjectText = bv.hatch.ObjectText
	bv.hatch.Enabled = owned and state == "ripe"
	bv.water.Enabled = owned and state == "growing"
end

local function refreshPads(view: PlotView, profile: Profile)
	for i, pv in view.pads do
		local locked = i > profile.penSlots
		if locked ~= pv.locked then
			pv.locked = locked
			pv.part:SetAttribute("Locked", locked)
			pv.part.Color = if locked then Color3.fromRGB(160, 160, 165) else PASTELS[(i - 1) % #PASTELS + 1]
			pv.part.Transparency = if locked then 0.5 else 0
			pv.label.Text = if locked then "🔒" else GardenRules.short(pv.pending)
			pv.gui.Enabled = locked or pv.pending > 0
		end
	end
end

-- Rebuilds the parts of a plot that changed since the last refresh.
function Plots.refresh(plot: number, profile: Profile)
	local view = views[plot]
	if view == nil then
		return
	end
	local owned = view.model:GetAttribute("Owner") ~= 0
	local now = os.time()
	view.model:SetAttribute("Gate", profile.gate)
	if profile.fence ~= view.fenceStyle then
		buildFence(view, profile.fence)
	end
	for i = 1, #view.beds do
		refreshBed(view, i, profile, now, owned)
	end
	refreshPads(view, profile)
	local title, info
	if owned then
		title = `{view.ownerName}'s Garden`
		info =
			`{GardenRules.short(math.floor(GardenRules.income(profile)))}/s   ♥ {profile.likes}   Index {#profile.index}/{GardenConfig.INDEX_SIZE}`
	else
		title, info = "Free Garden", "Join to claim it!"
	end
	local key = title .. info
	if key ~= view.signKey then
		view.signKey = key
		view.signTitle.Text = title
		view.signInfo.Text = info
	end
	refreshCreatures(view, profile)
end

-- Removes every creature and egg; the next refresh rebuilds them.
function Plots.clear(plot: number)
	local view = views[plot]
	if view == nil then
		return
	end
	for id, cv in view.creatures do
		if cv.model then
			cv.model:Destroy()
		end
		view.creatures[id] = nil
	end
	for _, bv in view.beds do
		if bv.egg then
			bv.egg:Destroy()
			bv.egg = nil
		end
		bv.eggId = ""
		bv.key = ""
		bv.hatch.Enabled = false
		bv.water.Enabled = false
	end
	for i in view.pads do
		Plots.setPending(plot, i, 0)
	end
end

-- A display garden for a free plot (never saved, never interactive).
local SHOW = {
	{ "bunny", "normal", "normal" },
	{ "cat", "golden", "big" },
	{ "frog", "normal", "normal" },
	{ "owl", "moonlit", "normal" },
	{ "pup", "normal", "normal" },
	{ "fox", "normal", "big" },
	{ "turtle", "rainbow", "normal" },
	{ "lion", "normal", "normal" },
	{ "dragon", "moonlit", "normal" },
}
local SHOW_EGGS = { "meadow", "forest", "sunset", "moon", "star" }
local SHOW_FENCES = { "picket", "bamboo", "hedge", "stone", "candy", "crystal" }

local function showcase(n: number): Profile
	local now = os.time()
	local beds = {}
	for i = 1, 4 do
		local ripe = (i + n) % 3 == 0
		beds[i] = {
			egg = SHOW_EGGS[(n + i) % #SHOW_EGGS + 1],
			planted = now - 3000,
			ready = if ripe then now - 1 else now + 3600,
			waters = 0,
			helps = 0,
			lastWater = 0,
		}
	end
	local creatures = {}
	for k = 1, 3 + n % 3 do
		local s = SHOW[(n * 2 + k) % #SHOW + 1]
		table.insert(creatures, { id = k, s = s[1], m = s[2], z = s[3], placed = k * 2 - 1, fav = false })
	end
	return {
		bedCount = 4,
		penSlots = 10,
		beds = beds,
		creatures = creatures,
		fence = SHOW_FENCES[(n - 1) % #SHOW_FENCES + 1],
		gate = "open",
		likes = 0,
		index = {},
	} :: any
end

-- Public API ------------------------------------------------------------------------------------

-- Builds the six plot shells once, each showing its display garden.
function Plots.build(root: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	for n = 1, COUNT do
		buildPlot(folder, n)
	end
	folder.Parent = root
	-- Load every creature mesh once up front; refreshes use only the ones that loaded (warmed).
	task.spawn(function()
		local warm = Instance.new("Folder")
		local species = Instance.new("Folder") -- one mesh each, for the admin catalogue's previews
		species.Name = "GardenSpecies"
		for _, s in GardenConfig.SPECIES do
			local mesh = Models.spawn(s.id, warm, Vector3.zero, 1)
			if mesh then
				warmed[s.id] = true
				mesh.Parent = species
			end
		end
		species.Parent = ReplicatedStorage
		for _, e in GardenConfig.EGGS do
			Plots.eggModel(warm, e.id, CFrame.identity)
		end
		warm:Destroy()
		for n = 1, COUNT do
			if views[n].model:GetAttribute("Owner") == 0 then
				Plots.refresh(n, showcase(n))
			end
		end
	end)
end

function Plots.assign(player: Player): number?
	for n, view in views do
		if view.model:GetAttribute("Owner") == 0 then
			view.model:SetAttribute("Owner", player.UserId)
			view.ownerName = player.DisplayName
			Plots.clear(n)
			return n
		end
	end
	return nil
end

function Plots.free(plot: number)
	local view = views[plot]
	if view == nil then
		return
	end
	view.model:SetAttribute("Owner", 0)
	view.ownerName = ""
	Plots.clear(plot)
	Plots.refresh(plot, showcase(plot))
end

function Plots.pads(plot: number): { [number]: Vec3 }
	return views[plot].padCentres
end

function Plots.bed(plot: number, bed: number): Vec3
	return views[plot].bedCentres[bed]
end

function Plots.gate(plot: number): CFrame
	local view = views[plot]
	local at = (view.frame * CFrame.new(0, 3, -HALF - 5)).Position
	return CFrame.lookAt(at, view.frame.Position + Vector3.new(0, 3, 0))
end

function Plots.contains(plot: number, pos: Vec3): boolean
	local p = views[plot].frame:PointToObjectSpace(Vector3.new(pos.x, pos.y, pos.z))
	return math.abs(p.X) <= 30 and math.abs(p.Z) <= 30 -- the 60 x 60 garden, as ClientState.plotOf
end

-- The Pending attribute, coin pile and label, only when the floored value changed.
function Plots.setPending(plot: number, pad: number, coins: number)
	local pv = views[plot].pads[pad]
	local value = math.floor(coins + 1e-9)
	if pv == nil or value == pv.pending then
		return
	end
	pv.pending = value
	pv.part:SetAttribute("Pending", value)
	local shown = if value >= 100 then 3 elseif value >= 10 then 2 elseif value >= 1 then 1 else 0
	for k, coin in pv.coins do
		coin.Transparency = if k <= shown then 0 else 1
	end
	if not pv.locked then
		pv.label.Text = GardenRules.short(value)
		pv.gui.Enabled = value > 0
	end
end

-- The plot's owner, if one is online in this server.
function Plots.owner(plot: number): Player?
	local id = views[plot] and views[plot].model:GetAttribute("Owner")
	return if type(id) == "number" and id ~= 0 then Players:GetPlayerByUserId(id) else nil
end

return Plots
