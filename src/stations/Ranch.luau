--!strict
-- What stands on a ranch's homestead (decisions 0034 and 0072): an open round green, not a fenced plot.
-- The lawn, the gate and the teleport pad are World's; this builds everything on the lawn from the
-- owner's upgrade levels and builds it again when one changes:
--   the herd's meadow in the middle, inside a ring path;
--   round the path the eight buildings of the ranch's upgrades (the Ranch House, Barn, Hatchery, Egg
--   Cellar, Brooder, Windmill, Trophy Lodge and Titan's Den), each a Blender model in one of three
--   looks for its level, or a staked plot while it is not bought;
--   the two vendors' stalls by the way in, the paths, and the six training areas (Areas.luau);
--   the sum of all levels brings the rest: paving, benches, lamps, an orchard, flowers, a field, a
--   well, a shelter, a garden, a fire, hives, flags, and more trees, bushes and rocks.
-- Upgrades are bought in the ranch menu, opened at the house door (a prompt tagged "RanchMenu").
-- Bought eggs wait on the egg rack at the Egg Cellar (a prompt tagged "EggStorage" lets the owner
-- choose one to hatch) and hatch in the Hatchery's nests, as many as its level gives, where a
-- finished egg is opened by its own prompt (Ranch.eggs shows them all). The stalls carry prompts
-- tagged "Vendor" (attribute Kind = "eggs" or "gear"), and the Windmill's till one tagged "Mill": the
-- owner collects its coins there. Also tagged: TrainPad (Ranch, Station), RanchNest (Ranch). Display
-- only: no game rules live here.
--
-- Places are polar: studs from the homestead's middle, and degrees where 0 is to the right and 90 is
-- away from the hub (ValleyMap's plan). A building's own numbers (its size, where its door, nests or
-- sails are) are those of tools/blender/stations/scenes/homestead.py, x to its right and y to its
-- back, its front to the middle: change the two together.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationConfig = require(Shared:WaitForChild("StationConfig"))
local ValleyMap = require(Shared:WaitForChild("ValleyMap"))
local Props = require(script.Parent:WaitForChild("Props"))
local World = require(script.Parent:WaitForChild("World"))
local Areas = require(script.Parent:WaitForChild("Areas"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))

local part, pillar = Props.part, Props.pillar
local kit = World.kit
local disc, ball, glow = kit.disc, kit.ball, kit.glow
local pine, bush, rock = kit.pine, kit.bush, kit.rock

local Ranch = {}

local LAWN = World.LAWN -- the lawn's top, above the homestead's ground: everything here stands on it
local HOME = ValleyMap.HOME
local MEADOW, RING0, RING1 = 34, 37, ValleyMap.RING -- the meadow's radius, the ring path's two edges

local M = Enum.Material
local V = Vector3.new
local rad = math.rad
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(45, 40, 55)
local STONE = Color3.fromRGB(150, 146, 140)
local PATH = Color3.fromRGB(214, 198, 168)
local DIRT = Color3.fromRGB(168, 128, 86)
local WOOD = Color3.fromRGB(170, 118, 72)
local WOOD_DARK = Color3.fromRGB(112, 76, 48)
local BARK = Color3.fromRGB(96, 66, 44)
local ROOF = Color3.fromRGB(96, 70, 62)
local HAY = Color3.fromRGB(232, 196, 110)
local WARM = Color3.fromRGB(255, 214, 140)
local WATER = Color3.fromRGB(80, 170, 235)
local GOLD = Color3.fromRGB(255, 200, 70)
local HEDGE = Color3.fromRGB(70, 140, 72)
local BANNER = Color3.fromRGB(226, 78, 64)
local BLOOM = { Color3.fromRGB(255, 140, 185), Color3.fromRGB(255, 225, 100), Color3.fromRGB(185, 150, 255) }

-- Where each upgrade's building stands: how far out, at what angle. The vendors' stalls too.
local PLACE: { [string]: { number } } = {
	house = { 84, 86 },
	barn = { 84, 238 },
	hatchery = { 70, 37.5 },
	cellar = { 98, 52 },
	brooder = { 98, 25.5 }, -- its boiler stands on its left, clear of the track's path
	windmill = { 86, 349 },
	lodge = { 82, 182 },
	den = { ValleyMap.DEN.face, ValleyMap.DEN.deg }, -- its front on the face of its hill (decision 0075)
}
local MARKET = { 62, 298 }
-- The size of the plot staked out for a building that a new ranch does not have.
local PLOT: { [string]: { number } } = {
	brooder = { 18, 11 },
	windmill = { 18, 16 },
	lodge = { 26, 15 },
	den = { 30, 24 },
}
-- The buildings' sizes in their three looks: (width, depth, wall height) unless said.
-- the farmhouse (decision 0074): its blocks { x, y, foot, width, depth, height }, and its door { x, y, sill }
local HOUSE = {
	{
		blocks = { { 0, 0, 0, 21.2, 15.2, 9.8 }, { 0, -9.5, 0, 9.2, 5, 1.75 }, { 11.7, 1, 0, 4, 3.8, 17 } },
		door = { 0, -7, 1.75 },
	},
	{
		blocks = { { 0, 0, 0, 28, 18, 11.8 }, { 0, -12.2, 0, 29, 6.4, 1.75 }, { -15.8, 1.5, 0, 4.4, 3.8, 22 } },
		door = { 0, -9, 1.75 },
	},
	{
		blocks = {
			{ -5, 0, 0, 30, 20, 17.2 },
			{ 14.5, -3.5, 0, 13, 19, 16 },
			{ -7.6, -13.3, 0, 26, 6.6, 1.75 },
			{ -21.8, 2, 0, 4.4, 3.8, 28 },
		},
		door = { -1, -10, 1.75 },
	},
}
local BARN = { { 18, 14, 8 }, { 26, 20, 11 }, { 34, 24, 14 } }
local CELLAR = { {}, { 9, 8, 6, 11 }, { 11, 9, 7.5, 16 } } -- the mound's half sizes, its front's width
local BROODER = { { 10, 7 }, { 15, 9 }, { 20, 11 } }
local MILL = { { 4.5, 15 }, { 6.5, 22 }, { 7.5, 28 } } -- (foot radius, height)
local SAILS = { { 5.4, 12.2, 18, 4 }, { 5.89, 20.5, 26, 4 }, { 6.55, 26.5, 34, 8 } } -- their hub (in front, high), span, arms
local LODGE = { {}, { 20, 12, 8 }, { 28, 15, 10 } }
-- How near a scattered tree, bush or rock may come to each building's middle.
local ROOM: { [string]: number } =
	{ house = 30, barn = 34, hatchery = 22, cellar = 28, brooder = 18, windmill = 24, lodge = 23, den = 12 }

-- When the extras arrive: the sum of all upgrade levels (0 to 44).
local PAVED, BENCHES, LANTERNS, ORCHARD, FLOWERS, FIELD, WELL, SHELTER, MORE_LANTERNS, GARDEN, FIRE, HIVES, FLAGS =
	2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 26, 30
-- Decor that stands at a fixed place (how far out, angle, how much room it takes): the scattered things keep off.
local FIXED = {
	{ 58, 100, 7 }, -- the well
	{ 87, 1.75, 20 }, -- the orchard
	{ 91, 299, 17 }, -- the field
	{ 82, 287.5, 9 }, -- the garden
	{ 92, 313.5, 11 }, -- the fire
	{ 97, 165.5, 8 }, -- the hives
	{ 98.5, 280, 9 }, -- World's teleport pad
}
local HUB_WAY = 270

-- Which of its three looks a building has at `level`; 0 for the plot of one that is not bought yet.
local function lookOf(id: string, level: number): number
	local first = if PLOT[id] then 1 else 0
	if level < first then
		return 0
	end
	local n = #(StationConfig.upgrade(id) :: StationConfig.Upgrade).levels
	return 1 + math.min(2, (level - first) * 3 // (n - first + 1))
end

-- The point `r` studs out at `deg` degrees, in a ranch frame's own numbers.
local function polar(r: number, deg: number): Vector3
	return V(math.cos(rad(deg)) * r, 0, math.sin(rad(deg)) * r)
end

-- How far apart two angles are, in degrees (0 to 180).
local function apart(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

local function emitter(p: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = p
	return e
end

local function fade(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

-- A gabled roof over a w x d box; `top` is the middle of the box's top. The ridge runs along x.
local function roof(f: Instance, top: CFrame, w: number, d: number, rise: number)
	for _, side in { -1, 1 } do
		local half = Instance.new("WedgePart")
		half.Anchored, half.Size = true, V(w + 2, rise, d / 2 + 1)
		half.CFrame = top
			* CFrame.new(0, rise / 2, side * (d / 4 + 0.5))
			* CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		half.Color, half.Material = ROOF, M.Slate
		half.Parent = f
	end
end

-- Small things ---------------------------------------------------------------------------------------

-- A short wooden post with a hanging lantern.
local function lantern(f: Instance, base: Vector3)
	pillar(f, base, 5.4, 0.28, WOOD_DARK, M.Wood)
	part(f, V(1.6, 0.3, 0.3), base + V(0.6, 5.1, 0), WOOD_DARK, M.Wood)
	local light = part(f, V(0.9, 1.2, 0.9), base + V(1.2, 4.2, 0), WARM, M.Neon)
	part(f, V(1.25, 0.25, 1.25), base + V(1.2, 4.95, 0), INK, M.Metal)
	glow(light, WARM, 16, 1.1)
end

local function hay(f: Instance, where: CFrame)
	part(f, V(4.2, 3, 3), where, HAY, M.Fabric)
	for _, x in { -1.2, 1.2 } do
		part(f, V(0.25, 3.1, 3.1), where * CFrame.new(x, 0, 0), WOOD_DARK, M.Fabric)
	end
end

local function bench(f: Instance, where: CFrame)
	part(f, V(6, 0.4, 1.8), where * CFrame.new(0, 1.6, 0), WOOD, M.Wood)
	part(f, V(6, 1.4, 0.3), where * CFrame.new(0, 2.6, 0.85), WOOD, M.Wood)
	for _, x in { -2.5, 2.5 } do
		part(f, V(0.4, 1.6, 1.6), where * CFrame.new(x, 0.8, 0), INK, M.Metal)
	end
end

local function pond(f: Instance, centre: Vector3, d: number, rng: Random)
	disc(f, centre + V(0, 0.3, 0), d + 2.6, 0.3, STONE, M.Slate)
	disc(f, centre + V(0, 0.45, 0), d, 0.25, WATER, M.Glass)
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		rock(f, centre + V(math.cos(a), 0, math.sin(a)) * (d / 2 + 1.2), rng:NextNumber(1.6, 3), rng)
	end
	for _ = 1, 4 do
		local p = centre + V(rng:NextNumber(-d / 3, d / 3), 0.55, rng:NextNumber(-d / 3, d / 3))
		disc(f, p, 1.6, 0.1, Color3.fromRGB(70, 160, 80), M.SmoothPlastic)
		ball(f, p + V(0.3, 0.15, 0), 0.5, BLOOM[1], M.SmoothPlastic)
	end
	for k = 1, 3 do -- reeds
		local a = k * 2.1
		local foot = centre + V(math.cos(a), 0, math.sin(a)) * (d / 2 - 0.6)
		pillar(f, foot + V(0, 0.3, 0), 3, 0.1, HEDGE, M.SmoothPlastic)
		pillar(f, foot + V(0, 2.9, 0), 0.9, 0.2, BARK, M.SmoothPlastic)
	end
end

-- A strip of path `w` wide and `l` long round `where` (its middle on the lawn, its length along z):
-- dirt on a new ranch, then grout with stone slabs on it, each a little different.
local function way(f: Instance, where: CFrame, w: number, l: number, paved: boolean, rng: Random)
	if not paved then
		part(f, V(w, 0.3, l), where * CFrame.new(0, 0.05, 0), DIRT, M.Ground)
		return
	end
	part(f, V(w, 0.3, l), where * CFrame.new(0, 0, 0), STONE, M.Slate)
	local nx, nz = math.max(1, math.round(w / 4.4)), math.max(1, math.round(l / 4.4))
	local sx, sz = w / nx, l / nz
	for ix = 1, nx do
		for iz = 1, nz do
			local slab = where * CFrame.new(-w / 2 + (ix - 0.5) * sx, 0.12, -l / 2 + (iz - 0.5) * sz)
			part(f, V(sx - 0.3, 0.2, sz - 0.3), slab, PATH:Lerp(STONE, rng:NextNumber(0, 0.4)), M.Slate)
		end
	end
end

local function well(f: Instance, where: CFrame)
	disc(f, where.Position + V(0, 2.2, 0), 5, 2.2, STONE, M.Cobblestone)
	disc(f, where.Position + V(0, 2.3, 0), 3.8, 0.3, INK, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		part(f, V(0.5, 5, 0.5), where * CFrame.new(sx * 2.2, 4.4, 0), WOOD_DARK, M.Wood)
	end
	roof(f, where * CFrame.new(0, 6.9, 0), 4.6, 3.4, 1.8)
	part(f, V(4.6, 0.3, 0.3), where * CFrame.new(0, 5.6, 0), WOOD_DARK, M.Wood)
	pillar(f, (where * CFrame.new(0, 3.6, 0)).Position, 1.2, 0.5, WOOD, M.WoodPlanks)
end

-- A prompt on `p` for the client to act on: the tag says what it opens.
local function prompt(p: BasePart, tag: string, action: string, object: string, i: number): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText, pr.ObjectText = action, object
	pr.HoldDuration = 0.2
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Ranch", i)
	pr.Parent = p
	CollectionService:AddTag(pr, tag)
	return pr
end

-- A vendor's stall facing -z: a counter under a striped awning, a name board and a keeper behind
-- the counter. Returns the middle of the counter top, to stand the wares on.
local function stall(f: Instance, b: CFrame, stripe: Color3, name: string, kind: string, i: number): CFrame
	part(f, V(11, 0.5, 8), b * CFrame.new(0, 0.5, 0), WOOD, M.WoodPlanks)
	local counter = part(f, V(10, 3, 1.8), b * CFrame.new(0, 2.25, -2.6), WOOD_DARK, M.Wood)
	part(f, V(10.6, 0.4, 2.4), b * CFrame.new(0, 3.95, -2.6), WOOD, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(f, V(0.7, 9, 0.7), b * CFrame.new(sx * 5, 5.2, sz * 3.4), WOOD_DARK, M.Wood)
		end
	end
	for k = 0, 5 do -- the awning, sloping down to the front
		local strip = b * CFrame.new(-4.9 + k * 1.96, 9.7, -0.6) * CFrame.Angles(rad(-10), 0, 0)
		part(f, V(1.95, 0.4, 9.4), strip, if k % 2 == 0 then stripe else WHITE, M.SmoothPlastic)
	end
	local board = part(f, V(9, 2.2, 0.4), b * CFrame.new(0, 11.6, -3.4), stripe:Lerp(INK, 0.4), M.SmoothPlastic)
	Props.label(board, name, WHITE, 0.4)
	part(f, V(2, 2.6, 1.2), b * CFrame.new(0, 3.8, 0.4), stripe:Lerp(WHITE, 0.2), M.SmoothPlastic) -- the keeper
	ball(f, (b * CFrame.new(0, 6, 0.4)).Position, 1.9, Color3.fromRGB(255, 214, 170), M.SmoothPlastic)
	part(f, V(2.6, 0.3, 2.6), b * CFrame.new(0, 6.9, 0.4), WOOD_DARK, M.SmoothPlastic)
	part(f, V(1.6, 0.9, 1.6), b * CFrame.new(0, 7.4, 0.4), WOOD_DARK, M.SmoothPlastic)
	prompt(counter, "Vendor", "Talk", name, i):SetAttribute("Kind", kind)
	return b * CFrame.new(0, 4.15, -2.6)
end

-- The buildings ----------------------------------------------------------------------------------------

-- What the game keeps of each ranch's homestead for the eggs and the Titan: where the Hatchery's nests
-- are, the egg rack and how many it shows, where the Titan stands in its den.
type Home = { nests: { CFrame }, rack: CFrame?, cols: number, rows: number, den: CFrame? }
local homes: { [number]: Home } = {}

-- An unseen block where a building's model is solid (the models take no collisions): its middle (x, y)
-- and foot z, then its size, in the building's own numbers.
local function block(f: Instance, b: CFrame, x: number, y: number, z: number, sx: number, sy: number, sz: number): Part
	local p = part(f, V(sx, sz, sy), b * CFrame.new(x, z + sz / 2, -y), WHITE)
	p.Transparency, p.CastShadow, p.Name = 1, false, "Solid"
	return p
end

-- Where the Hatchery's `n` nests are, in its own numbers: a row or two under the canvas, a ring in the
-- pavilion, a ring round a smaller one in the great pavilion.
local function nestSpots(look: number, n: number): { Vector3 }
	local out = {}
	if look == 1 then
		local rows = if n <= 3 then 1 else 2
		local per = math.ceil(n / rows)
		for k = 0, n - 1 do
			local row, col = k // per, k % per
			local inRow = math.min(per, n - row * per)
			table.insert(out, V((col - (inRow - 1) / 2) * 4.2, (row - (rows - 1) / 2) * 4.4, 0.5))
		end
		return out
	end
	local function ring(count: number, r: number, turn: number)
		for k = 0, count - 1 do
			local p = polar(if count == 1 then 0 else r, turn + k * 360 / count)
			table.insert(out, V(p.X, p.Z, 0.75))
		end
	end
	if look == 2 then
		ring(n, 6.5, 90)
	else
		ring(math.min(n, 6), 9.5, 90)
		ring(n - math.min(n, 6), 4, 0)
	end
	return out
end

-- The Hatchery's nests: straw rings on its floor. Bought eggs wait in them until they open.
local function nests(f: Instance, b: CFrame, look: number, n: number, home: Home)
	for _, spot in nestSpots(look, n) do
		local c = b * CFrame.new(spot.X, spot.Z + 0.5, -spot.Y)
		disc(f, c.Position, 3.6, 0.5, HAY, M.Fabric)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			ball(f, c.Position + V(math.cos(a) * 1.7, 0, math.sin(a) * 1.7), 1, HAY:Lerp(WOOD, 0.25), M.Fabric)
		end
		table.insert(home.nests, c * CFrame.Angles(0, math.pi, 0)) -- an egg in it faces the middle
	end
end

local function rackSpot(home: Home, k: number): CFrame -- from the rack's frame: shelves of `cols` eggs
	return CFrame.new(-(home.cols - 1) * 1.25 + ((k - 1) % home.cols) * 2.5, 1.5 + ((k - 1) // home.cols) * 2.3, 0)
end

-- The egg storage: a rack of shelves at the Egg Cellar, its front (-z) to the middle. The stored eggs
-- show on it, as many as it has places; the rest are down in the cellar.
local function eggRack(f: Instance, b: CFrame, home: Home, i: number)
	local w, top = home.cols * 2.5 + 0.6, 1.2 + home.rows * 2.3
	part(f, V(w, top - 0.5, 0.4), b * CFrame.new(0, top / 2 + 0.3, 1), WOOD_DARK, M.WoodPlanks)
	for row = 0, home.rows do
		part(f, V(w, 0.4, 2.4), b * CFrame.new(0, 1.2 + row * 2.3, 0), WOOD, M.WoodPlanks)
	end
	for _, x in { -w / 2, w / 2 } do
		part(f, V(0.5, top + 0.2, 2.4), b * CFrame.new(x, top / 2 + 0.1, 0), WOOD_DARK, M.Wood)
	end
	local board =
		part(f, V(8, 1.6, 0.3), b * CFrame.new(0, top + 1.2, 0), Color3.fromRGB(150, 110, 80), M.SmoothPlastic)
	Props.label(board, "Egg Storage", WHITE, 0.3)
	local shelf = part(f, V(w - 0.6, 0.4, 2), b * CFrame.new(0, 3.5, 0), WOOD, M.WoodPlanks) -- carries the prompt
	prompt(shelf, "EggStorage", "Choose an egg to hatch", "Egg storage", i)
	home.rack = b
end

-- The Windmill's sails, which its model leaves out: they turn on a motor.
local function sails(f: Instance, b: CFrame, look: number)
	local ahead, high, span, arms = SAILS[look][1], SAILS[look][2], SAILS[look][3], SAILS[look][4]
	local front = b * CFrame.Angles(0, math.pi, 0) -- its -z is towards the middle, like the model's front
	local axle = part(f, V(1.2, 1.2, 1.6), front * CFrame.new(0, high, -ahead + 0.8), INK, M.Metal)
	local hub = part(f, V(1.7, 1.7, 0.8), front * CFrame.new(0, high, -ahead - 0.6), WOOD_DARK, M.Wood)
	hub.Anchored, hub.CanCollide = false, false
	for k = 0, arms - 1 do
		local arm = hub.CFrame * CFrame.Angles(0, 0, k * math.pi * 2 / arms + 0.35)
		local len = span / 2
		for _, piece in
			{
				part(f, V(0.35, len, 0.4), arm * CFrame.new(0, len / 2, 0), WOOD_DARK, M.Wood),
				part(
					f,
					V(if arms == 4 then 2.4 else 1.9, len * 0.76, 0.2),
					arm * CFrame.new(1, len * 0.6, 0),
					Color3.fromRGB(246, 240, 224),
					M.SmoothPlastic
				),
			}
		do
			piece.Anchored, piece.CanCollide, piece.Massless = false, false, true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = hub, piece
			weld.Parent = piece
		end
	end
	-- a hinge turns about its attachments' x axis: point that along the axle
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.CFrame = CFrame.new(0, 0, -1.4) * CFrame.Angles(0, rad(-90), 0)
	a1.CFrame = CFrame.Angles(0, rad(-90), 0)
	a0.Parent, a1.Parent = axle, hub
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0, hinge.Attachment1 = a0, a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity, hinge.MotorMaxTorque = 0.6 + 0.2 * look, math.huge
	hinge.Parent = axle
end

-- The plot of a building that is not bought yet: four stakes, a rope, its name on a board.
local function stakes(f: Instance, b: CFrame, id: string)
	local w, d = PLOT[id][1], PLOT[id][2]
	part(f, V(w - 3, 0.2, d - 3), b * CFrame.new(0, 0.15, 0), DIRT, M.Ground)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(f, V(0.6, 2.6, 0.6), b * CFrame.new(sx * w / 2, 1.3, sz * d / 2), WOOD_DARK, M.Wood)
		end
		part(f, V(0.18, 0.18, d), b * CFrame.new(sx * w / 2, 2.1, 0), HAY, M.Fabric)
		part(f, V(w, 0.18, 0.18), b * CFrame.new(0, 2.1, sx * d / 2), HAY, M.Fabric)
		part(f, V(0.5, 6.4, 0.5), b * CFrame.new(sx * 4.6, 3.2, d / 2 + 3), WOOD_DARK, M.Wood)
	end
	local board = part(f, V(10.4, 2.4, 0.4), b * CFrame.new(0, 5.4, d / 2 + 3), WOOD, M.WoodPlanks)
	Props.label(board, (StationConfig.upgrade(id) :: StationConfig.Upgrade).name, WHITE, 0.4)
	local note = part(f, V(10.4, 1.3, 0.4), b * CFrame.new(0, 3.5, d / 2 + 3), INK, M.SmoothPlastic)
	Props.label(note, "Buy it in the ranch menu", GOLD, 0.25)
end

-- Stands building `id` in its look for `level` at its place: its model, the unseen blocks where it is
-- solid, and what the game adds to it (the door's prompt, nests, the egg rack, sails).
local function building(f: Instance, cf: CFrame, id: string, level: number, home: Home, i: number)
	local at = polar(PLACE[id][1], PLACE[id][2])
	local middle = cf * (at + V(0, LAWN - 0.1, 0))
	local b = CFrame.lookAt(middle, middle + cf:VectorToWorldSpace(at)) -- its back to the outside
	local look = lookOf(id, level)
	if look == 0 then
		stakes(f, if id == "den" then b * CFrame.new(0, 0, -14) else b, id) -- the den's plot is inside its cave
		return
	end
	-- its model has to load: it must not hold the rebuild up, or a second rebuild would start beside this one
	task.spawn(Creatures.still, `home_{id}_{look}`, b * CFrame.Angles(0, math.pi, 0), 1, f)
	if id == "house" then
		for _, s in HOUSE[look].blocks do
			block(f, b, s[1], s[2], s[3], s[4], s[5], s[6])
		end
		local x, y, sill = HOUSE[look].door[1], HOUSE[look].door[2], HOUSE[look].door[3]
		local door = part(f, V(4.4, 7, 0.6), b * CFrame.new(x, sill + 3.5, -y + 0.3), WHITE)
		door.Transparency, door.CanCollide, door.CastShadow, door.Name = 1, false, false, "Door"
		prompt(door, "RanchMenu", "Open", "Ranch menu", i)
	elseif id == "barn" then
		local w, d, h = BARN[look][1], BARN[look][2], BARN[look][3]
		block(f, b, 0, 0, 0, w, d, h + 0.3)
		if look >= 2 then
			block(f, b, w / 2 + 6, 2, 0, 7.6, 7.6, h + 7)
		end
		if look == 3 then
			block(f, b, w / 2 + 5.4, -9, 0, 6.4, 6.4, h + 2)
		end
	elseif id == "hatchery" then
		local side = ({ 12, 16, 19.6 })[look]
		local floor = block(f, b, 0, 0, 0, side, side, if look == 1 then 0.5 else 0.75)
		floor.Name = "Nest"
		floor:SetAttribute("Ranch", i)
		CollectionService:AddTag(floor, "RanchNest")
		local u = StationConfig.upgrade(id) :: StationConfig.Upgrade
		nests(f, b, look, if level > 0 then u.levels[level].value else u.base, home)
	elseif id == "cellar" then
		home.cols, home.rows = if look == 1 then 4 else 6, if look == 1 then 3 else 4
		local x, y = 0, 0
		if look >= 2 then
			local mw, md, mh, fw = CELLAR[look][1], CELLAR[look][2], CELLAR[look][3], CELLAR[look][4]
			block(f, b, 0, 4, 0, mw * 1.5, md * 1.5, mh * 0.9)
			x, y = -(fw / 2 + 9), 4 - md * 0.72 - 1 -- on its left, away from the guard yard's path
		end
		local rack = cf:ToObjectSpace(b * CFrame.new(x, 0, -y)).Position * V(1, 0, 1)
		eggRack(f, CFrame.lookAt(cf * rack, cf * (rack * 0.5)), home, i) -- on the ranch's ground, front to the middle
	elseif id == "brooder" then
		block(f, b, 0, 0, 0, BROODER[look][1], BROODER[look][2], 0.75)
		if look == 3 then
			block(f, b, -BROODER[look][1] / 2 - 3.2, 1, 0, 4, 4, 7)
		end
	elseif id == "windmill" then
		local foot, tall = MILL[look][1], MILL[look][2]
		if look == 1 then
			block(f, b, 0, 0, 6, 9, 9, 9) -- the mill's body, up on its legs
		else
			block(f, b, 0, 0, 0, foot * 1.6, foot * 1.6, tall)
		end
		if look == 3 then
			block(f, b, -foot - 8, 3, 0, 10, 8, 6)
		end
		sails(f, b, look)
		-- the till, left of the door: what the mill holds is collected here. The owner's client writes
		-- the sum on its board (a prompt tagged "Mill").
		local till = b * CFrame.new(-foot * 0.5 - 2.6, 0.1, foot + 2.6)
		part(f, V(3.4, 2.4, 2.4), till * CFrame.new(0, 1.2, 0), WOOD_DARK, M.WoodPlanks)
		part(f, V(3.7, 0.4, 2.7), till * CFrame.new(0, 2.6, 0), WOOD, M.Wood)
		for k, o in { V(-0.8, 3.1, 0.2), V(0.5, 3.1, -0.3), V(0, 3.6, 0.1) } do
			ball(f, (till * CFrame.new(o)).Position, 1.1 - k * 0.1, GOLD, M.Metal)
		end
		for _, sx in { -1, 1 } do
			part(f, V(0.4, 6.4, 0.4), till * CFrame.new(sx * 2.9, 3.2, -1.6), WOOD_DARK, M.Wood)
		end
		local board = part(f, V(7, 1.8, 0.4), till * CFrame.new(0, 5.6, -1.6), INK, M.SmoothPlastic)
		board.Name = "Till"
		Props.label(board, "Windmill", GOLD, 0.3)
		prompt(board, "Mill", "Collect", "Windmill", i)
	elseif id == "lodge" then
		if look == 1 then
			block(f, b, 0, 0, 0, 2.6, 2.6, 2.3)
		else
			local w, d, h = LODGE[look][1], LODGE[look][2], LODGE[look][3]
			block(f, b, 0, 0, 0, w + 2, d + 2, 0.75)
			block(f, b, 0, d / 2 - 0.6, 0.75, w, 1.2, h)
		end
	elseif id == "den" then -- the hall is the hill's rock (Valley.den): only the gate is solid
		local half, tall = ValleyMap.DEN.half, ValleyMap.DEN.tall
		if look >= 2 then
			for _, sx in { -1, 1 } do
				block(f, b, sx * (half + 1.5), 0.6, 0, 9, 4, tall + 4)
			end
			block(f, b, 0, 0.6, tall - 2, half * 2 + 21, 4, 6)
		end
		local stand = cf:ToObjectSpace(b * CFrame.new(0, 0, -(ValleyMap.DEN.back - ValleyMap.DEN.face) * 0.55)).Position
			* V(1, 0, 1)
		home.den = CFrame.lookAt(cf * (stand + V(0, LAWN + 0.45, 0)), cf * V(0, LAWN + 0.45, 0)) -- the Titan faces out of it
	end
end

-- Where the `n`th hatching egg stands in ranch `i`'s hatchery (facing out of it), and an egg type's
-- two colours: for the hatching animation.
function Ranch.nest(i: number, n: number): CFrame
	local home = homes[i]
	local list = if home then home.nests else {}
	return list[math.clamp(n, 1, math.max(1, #list))] or World.ranchFrame(i)
end

function Ranch.look(kind: string): { body: Color3, spot: Color3 }
	return kit.eggLook[kind] or kit.eggLook.meadow
end

-- Where ranch `i`'s Titan stands in its den, looking out of it; nil while the den is not built.
function Ranch.den(i: number): CFrame?
	return homes[i] and homes[i].den
end

-- A spot in ranch `i`'s meadow for one of the herd to walk to: clear of the pond and the tree.
function Ranch.somewhere(i: number, rng: Random): Vector3
	for _ = 1, 20 do
		local p = polar(MEADOW * math.sqrt(rng:NextNumber(0.02, 0.8)), rng:NextNumber(0, 360))
		if (p - V(-10, 0, 6)).Magnitude > 11.5 and (p - V(12, 0, -7)).Magnitude > 5 then
			return World.ranchFrame(i) * (p + V(0, LAWN + 0.05, 0))
		end
	end
	return World.ranchFrame(i) * V(0, LAWN + 0.05, -18)
end

-- Show ranch `i`'s eggs: `eggs` is the profile's list, oldest first, each with `due`: when it can be
-- opened. Hatching eggs sit in the hatchery's nests, each with a prompt tagged "Egg" (attributes Ranch,
-- Index = its place in the list, Due); the client changes the prompt's words and turns the sparkles on
-- when the egg is ready (the prompt itself stays on: the server would refuse one it thinks is off).
-- Stored eggs sit on the rack.
function Ranch.eggs(i: number, eggs: { { egg: string, since: number?, due: number? } })
	local plot = World.root():FindFirstChild(`Ranch{i}`, true)
	local home = homes[i]
	if plot == nil or home == nil then
		return
	end
	local old = plot:FindFirstChild("Eggs")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Eggs"
	local rng = Random.new(7)
	local nest, shelf = 0, 0
	for k, e in eggs do
		local look, egg = kit.eggLook[e.egg], StationConfig.egg(e.egg)
		if look and egg and e.since then
			nest += 1
			if home.nests[nest] then
				local shell = kit.eggModel(f, home.nests[nest], 3, e.egg, rng)
				glow(shell, WARM, 8, 0.5)
				local open = prompt(shell, "Egg", "Hatching", egg.name, i)
				open:SetAttribute("Index", k)
				open:SetAttribute("Due", e.due or e.since + egg.hatch)
				emitter(shell, {
					Texture = "rbxasset://textures/particles/sparkles_main.dds",
					Color = ColorSequence.new(GOLD),
					LightEmission = 0.8,
					Transparency = fade(0, 1),
					Size = fade(0.5, 0),
					Lifetime = NumberRange.new(0.8, 1.4),
					Rate = 10,
					Speed = NumberRange.new(2, 4),
					SpreadAngle = Vector2.new(60, 60),
					Enabled = false,
				})
			end
		elseif look and home.rack then
			shelf += 1
			if shelf <= home.cols * home.rows then
				kit.eggModel(f, home.rack * rackSpot(home, shelf), 1.5, e.egg, rng) -- with its crown it still fits a shelf
			end
		end
	end
	f.Parent = plot
end

-- Up to `n` free spots on the lawn outside the ring path: always the same ones in the same order for a
-- seed, so a higher level only adds to what was there. They keep `margin` clear of every way, building,
-- plot and piece of fixed decor.
local function scatter(seed: number, n: number, margin: number): { Vector3 }
	local rng, out = Random.new(seed), {}
	local ways = { HUB_WAY, ValleyMap.DEN.deg } -- and the way into the den
	for _, g in ValleyMap.GROUNDS do
		table.insert(ways, math.deg(math.atan2(g.z, g.x)))
	end
	for _ = 1, 900 do
		if #out >= n then
			break
		end
		local r, a = rng:NextNumber(RING1 + 6, HOME - 8), rng:NextNumber(0, 360)
		local p = polar(r, a)
		local free = true
		for _, w in ways do
			free = free and math.sin(rad(math.min(apart(a, w), 90))) * r > 8 + margin
		end
		for id, where in PLACE do
			free = free and (p - polar(where[1], where[2])).Magnitude > ROOM[id] + margin
		end
		free = free and (p - polar(MARKET[1], MARKET[2])).Magnitude > 16 + margin
		for _, d in FIXED do
			free = free and (p - polar(d[1], d[2])).Magnitude > d[3] + margin
		end
		if free then
			table.insert(out, p)
		end
	end
	return out
end

-- Build ranch `i` for these upgrade levels (missing = 0), replacing what stood there.
function Ranch.render(i: number, levels: { [string]: number })
	local plot = World.root():FindFirstChild(`Ranch{i}`, true)
	if plot == nil then
		return
	end
	for _, old in plot:GetChildren() do -- nothing below may wait: the old ranch goes and the new one stands at once
		if old.Name == "Built" then
			old:Destroy()
		end
	end
	local f = Instance.new("Folder")
	f.Name = "Built"
	local cf = World.ranchFrame(i)
	local rng = Random.new(40 + i)
	local total = 0
	for _, u in StationConfig.UPGRADES do
		total += levels[u.id] or 0
	end
	local home: Home = { nests = {}, cols = 4, rows = 3 }
	homes[i] = home
	-- a place on the lawn: a point, and a frame there looking out from the middle (or turned from that)
	local function spot(r: number, deg: number): Vector3
		return cf * (polar(r, deg) + V(0, LAWN, 0))
	end
	local function out(r: number, deg: number, turn: number?): CFrame
		local p = polar(r, deg) + V(0, LAWN, 0)
		return CFrame.lookAt(cf * p, cf * (p + polar(1, deg))) * CFrame.Angles(0, rad(turn or 0), 0)
	end
	local paved = total >= PAVED

	-- the herd's meadow: leafy grass inside a low kerb with a gap at every way, a pond, a shade tree, a
	-- trough and hay. The ring path lies round it.
	for k = 0, 29 do -- the ring path, in thirty pieces; the meadow inside it is the valley's own grass
		local piece = out((RING0 + RING1) / 2, k * 12) * CFrame.new(0, 0.08, 0)
		local colour = if paved then PATH:Lerp(STONE, rng:NextNumber(0, 0.35)) else DIRT
		part(f, V(RING1 * rad(12) + 0.3, 0.24, RING1 - RING0), piece, colour, if paved then M.Cobblestone else M.Ground)
	end
	local ways = { HUB_WAY }
	for _, g in ValleyMap.GROUNDS do
		table.insert(ways, (math.deg(math.atan2(g.z, g.x)) + 360) % 360)
	end
	table.sort(ways)
	for k, a in ways do
		local b = if k == #ways then ways[1] + 360 else ways[k + 1]
		local n = math.max(1, math.round((b - a - 22) / 8))
		for s = 0, n - 1 do
			local deg = a + 11 + (s + 0.5) * (b - a - 22) / n
			local len = rad((b - a - 22) / n) * (MEADOW + 1.1) + 0.3
			part(f, V(len, 1.4, 1.5), out(MEADOW + 1.1, deg) * CFrame.new(0, 0.7, 0), STONE, M.Cobblestone)
		end
	end
	pond(f, spot(11.7, 149), 16, rng)
	kit.tree(f, spot(13.9, -30), rng, 2.1)
	local trough = out(19, 71.6, 104)
	part(f, V(8, 2, 3), trough * CFrame.new(0, 1.1, 0), WOOD, M.Wood)
	part(f, V(7.2, 0.3, 2.2), trough * CFrame.new(0, 2.05, 0), WATER, M.Glass)
	for k, o in { V(-2, 1.5, 0.2), V(2.1, 1.5, -0.4), V(0, 4.5, 0) } do
		hay(f, out(28, 178, 20) * CFrame.new(o) * CFrame.Angles(0, rad(k * 7), 0))
	end
	rock(f, spot(24, 20), 2.6, rng)
	rock(f, spot(26, 250), 2.2, rng)
	if total >= SHELTER then -- an open shelter in the meadow
		local shelter = out(25.8, 215.5, 35)
		for _, x in { -5, 5 } do
			for _, z in { -3.6, 3.6 } do
				part(f, V(0.7, 6.6, 0.7), shelter * CFrame.new(x, 3.3, z), WOOD_DARK, M.Wood)
			end
		end
		roof(f, shelter * CFrame.new(0, 6.6, 0), 11, 8, 2.6)
		part(f, V(8, 0.3, 5.4), shelter * CFrame.new(0, 0.25, 0), HAY, M.Fabric)
	end

	-- the paths: the road in from the hub, a way out to each training ground, a short one to every
	-- building's door. Dirt at first, then paved.
	local function strip(deg: number, r0: number, r1: number, w: number)
		way(f, out((r0 + r1) / 2, deg) * CFrame.new(0, 0.1, 0), w, r1 - r0, paved, rng)
	end
	strip(HUB_WAY, RING1 - 0.5, World.RANCH_GATE + 22, 10)
	for _, g in ValleyMap.GROUNDS do
		strip(math.deg(math.atan2(g.z, g.x)), RING1 - 0.5, HOME - 2, 9)
	end
	for id, where in PLACE do
		strip(where[2], RING1 - 0.5, where[1] - ROOM[id] * 0.36, 6)
	end
	strip(MARKET[2], RING1 - 0.5, MARKET[1] - 5, 6)

	-- the eight buildings, each in its look for its level, or its plot
	for id in PLACE do
		building(f, cf, id, levels[id] or 0, home, i)
	end

	-- the vendors, by the way in: eggs (one of each on the counter) and gear
	local market = out(MARKET[1], MARKET[2], 180) -- their counters to the middle
	local wares = stall(f, market * CFrame.new(-6.5, -LAWN, 0), Color3.fromRGB(240, 170, 60), "Egg Vendor", "eggs", i)
	for k, e in StationConfig.EGGS do
		kit.eggModel(f, wares * CFrame.new((k - 2.5) * 2.4, 0, 0), 1.9, e.id, rng)
	end
	wares = stall(f, market * CFrame.new(6.5, -LAWN, 0), Color3.fromRGB(90, 130, 200), "Gear Vendor", "gear", i)
	local steel = Color3.fromRGB(190, 196, 206)
	part(
		f,
		V(1.7, 2.1, 0.3),
		wares * CFrame.new(-3, 1.1, 0) * CFrame.Angles(rad(-14), 0, 0),
		Color3.fromRGB(200, 70, 60),
		M.Metal
	)
	ball(f, (wares * CFrame.new(-0.4, 0.7, 0)).Position, 1.5, steel, M.Metal)
	part(f, V(0.3, 0.7, 1.2), wares * CFrame.new(-0.4, 1.5, 0), Color3.fromRGB(200, 70, 60), M.SmoothPlastic)
	part(f, V(0.3, 3, 0.12), wares * CFrame.new(2.4, 1.5, 0) * CFrame.Angles(0, 0, rad(18)), steel, M.Metal)
	part(f, V(1.1, 0.25, 0.3), wares * CFrame.new(2.75, 0.5, 0) * CFrame.Angles(0, 0, rad(18)), WOOD_DARK, M.Wood)

	-- the training areas, each on its ground in the valley, as far on as the Training Grounds
	Areas.build(f, i, levels.grounds or 0)

	-- the rim of the lawn, the same at every level: bushes and rocks, none across a way, and two trees
	-- where each way leaves
	local wild = Random.new(900 + i)
	for a = 0, 352, 8 do
		local clear = apart(a, ValleyMap.DEN.deg) > 12 -- nor across the way into the den
		for _, w in ways do
			clear = clear and apart(a, w) > 9
		end
		if clear then
			local where = spot(HOME - 3 + wild:NextNumber(-3, 1), a + wild:NextNumber(-2, 2))
			if wild:NextNumber() < 0.7 then
				bush(f, where, wild:NextNumber(1.2, 1.9), wild)
			else
				rock(f, where, wild:NextNumber(2, 3.6), wild)
			end
		end
	end
	for _, w in ways do
		if w ~= HUB_WAY then
			for _, side in { -1, 1 } do
				local where = cf * (polar(HOME - 5, w) + polar(13 * side, w + 90) + V(0, LAWN, 0))
				if w > 100 and w < 220 then
					pine(f, where, 1.5, wild)
				else
					kit.tree(f, where, wild, 1.2)
				end
			end
		end
	end
	for k = 0, 2 do -- an avenue up the road from the hub
		for _, side in { -1, 1 } do
			kit.tree(f, cf * (polar(58 + k * 13, HUB_WAY) + polar(13 * side, HUB_WAY + 90) + V(0, LAWN, 0)), wild, 1.1)
		end
	end

	-- growing things between the buildings: more with every level, and what is there stays where it is
	for k, p in scatter(100 + i, 3 + total // 3, 5) do
		if k % 2 == 0 then
			pine(f, cf * (p + V(0, LAWN, 0)), rng:NextNumber(0.9, 1.25), rng)
		else
			kit.tree(f, cf * (p + V(0, LAWN, 0)), rng, rng:NextNumber(0.75, 1))
		end
	end
	for _, p in scatter(200 + i, 5 + total // 2, 2) do
		bush(f, cf * (p + V(0, LAWN, 0)), rng:NextNumber(0.8, 1.2), rng)
	end
	for _, p in scatter(300 + i, 3 + total // 4, 2) do
		rock(f, cf * (p + V(0, LAWN, 0)), rng:NextNumber(1.6, 3), rng)
	end

	-- the extras that come with the ranch's total level
	if total >= BENCHES then
		for _, a in if total >= LANTERNS then { 0, 74, 122, 170, 222, 310 } else { 74, 310 } do
			bench(f, out(RING1 + 3, a, 180))
		end
	end
	if total >= LANTERNS then
		for _, where in PLACE do
			lantern(f, spot(RING1 + 2, where[2] + 12))
			if total >= MORE_LANTERNS then
				lantern(f, spot(RING1 + 2, where[2] - 12))
			end
		end
	end
	if total >= ORCHARD then -- between the windmill and the track's path (the mill's store is on its other side)
		for k = 0, 7 do
			local where = spot(72 + (k // 2) * 10, 358.5 + (k % 2) * 6.5)
			kit.tree(f, where, rng, 0.8)
			ball(f, where + V(1.6, 6.4, -1), 0.9, Color3.fromRGB(226, 60, 50), M.SmoothPlastic)
		end
	end
	if total >= FLOWERS then
		for _, p in scatter(400 + i, 3 + total // 3, 1) do
			kit.flowers(f, cf * (p + V(0, LAWN, 0)), rng, 8, 2.2)
		end
		for _ = 1, 6 do
			kit.flowers(f, spot(rng:NextNumber(8, 30), rng:NextNumber(0, 360)), rng, 7, 2)
		end
	end
	if total >= FIELD then -- behind the market
		for row = 0, 3 do
			local a = 295.5 + row * 2.4
			part(f, V(2, 0.3, 28), out(90, a) * CFrame.new(0, 0.1, 0), DIRT, M.Ground)
			for k = 0, 5 do
				local green = if row % 2 == 0 then Color3.fromRGB(232, 140, 50) else Color3.fromRGB(110, 180, 80)
				ball(f, spot(78 + k * 4.8, a) + V(0, 0.7, 0), 1.7, green, M.SmoothPlastic)
			end
		end
		local scare = spot(106, 299)
		pillar(f, scare, 7, 0.25, WOOD_DARK, M.Wood)
		part(f, V(6, 0.4, 0.4), out(106, 299) * CFrame.new(0, 5, 0), WOOD_DARK, M.Wood)
		ball(f, scare + V(0, 7.6, 0), 1.8, HAY, M.Fabric)
	end
	if total >= WELL then
		well(f, out(58, 100) * CFrame.new(0, -LAWN, 0))
	end
	if total >= GARDEN then -- between the road and the field
		local bed = spot(82, 287.5)
		disc(f, bed + V(0, 0.5, 0), 13, 0.5, DIRT, M.Ground)
		for k = 0, 6 do
			local where = bed + polar(if k == 0 then 0 else 4, k * 60) + V(0, 0.5, 0)
			kit.flowers(f, where, rng, 9, 1.7)
		end
		pillar(f, bed + V(0, 0.5, 0), 3, 0.5, STONE, M.Marble)
		disc(f, bed + V(0, 3.9, 0), 2.6, 0.4, STONE, M.Marble)
	end
	if total >= FIRE then -- a fire to sit round, between the field and the pool's path
		local fire = spot(92, 313.5)
		disc(f, fire + V(0, 0.4, 0), 7.2, 0.4, STONE, M.Cobblestone)
		local flame = ball(f, fire + V(0, 1.6, 0), 2.6, Color3.fromRGB(255, 150, 60), M.Neon)
		glow(flame, Color3.fromRGB(255, 170, 80), 22, 1.4)
		emitter(flame, {
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 90, 40)),
			LightEmission = 0.7,
			Transparency = fade(0.2, 1),
			Size = fade(2.4, 0.4),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 14,
			Speed = NumberRange.new(3, 5),
			SpreadAngle = Vector2.new(12, 12),
			EmissionDirection = Enum.NormalId.Top,
		})
		for k = 0, 4 do
			local log = CFrame.lookAt(fire + polar(7.4, k * 72 + 20), fire)
			part(f, V(4.6, 1.2, 1.3), log * CFrame.new(0, 0.6, 0), BARK, M.Wood)
		end
	end
	if total >= HIVES then
		for k = 0, 2 do
			local hive = out(92 + k * 5, 165.5)
			part(f, V(2.6, 0.5, 2.6), hive * CFrame.new(0, 0.25, 0), WOOD_DARK, M.Wood)
			part(f, V(2.2, 2.6, 2.2), hive * CFrame.new(0, 1.8, 0), Color3.fromRGB(240, 210, 110), M.WoodPlanks)
			part(f, V(3, 0.5, 3), hive * CFrame.new(0, 3.35, 0), WOOD, M.Wood)
		end
	end
	if total >= FLAGS then -- flags either side of the way in, and a gold emblem over it
		for _, sx in { -1, 1 } do
			local pole = cf * V(sx * 12, 0, -World.RANCH_GATE + 3)
			pillar(f, pole, 15, 0.22, WHITE, M.Metal)
			part(
				f,
				V(4.4, 2.6, 0.2),
				cf * CFrame.new(sx * 12 + 2.4, 13.4, -World.RANCH_GATE + 3),
				BANNER,
				M.SmoothPlastic
			)
		end
		local emblem = ball(f, cf * V(0, 15.4, -World.RANCH_GATE), 2.6, GOLD, M.Neon)
		glow(emblem, GOLD, 16, 1)
	end

	f.Parent = plot
end

return Ranch
