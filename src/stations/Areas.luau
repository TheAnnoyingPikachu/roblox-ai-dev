--!strict
-- The six training areas of a ranch (decision 0065): each stands in a clearing of its own beyond the
-- ranch's mountains (World.areaFrame), at the end of a pass. An area is made of the Blender models
-- `area_<station>_<first>_<last>` (tools/blender/stations/assets/areas.py): each holds what stands
-- from Training Grounds level `first` to level `last`, so a level's look is every model whose stretch
-- holds it. The models take no collisions: `SOLID` lists the unseen blocks an area needs to be walked
-- on, read off tools/blender/stations/scenes/training.py in its own numbers (x east and y north of the
-- yard's middle, z up, before the yard is grown K times): change the two together.
-- The kit that moves (decision 0067) is models of its own (`kit_*`) or a Neon piece of an area's model:
-- this stands and tags it ("Kit", with a `Kit` attribute that says how it moves), and
-- stations-client/Kit.client.luau moves it on each client.
-- Display only: no game rules live here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Props = require(script.Parent:WaitForChild("Props"))
local World = require(script.Parent:WaitForChild("World"))
local Creatures = require(script.Parent:WaitForChild("Creatures"))
local StationAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationAssets"))
local StationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationConfig"))

local Areas = {}

local K = 2.5 -- how many times an area is grown from the yard it is written as (training.py's K)
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(45, 40, 55)
local YARD = { 1, 5, -33.5, 33.5, -25.5, 25.5, 0.25 } -- every area's floor, from level 1

Areas.COLOUR = {
	speed = Color3.fromRGB(60, 150, 255),
	strength = Color3.fromRGB(235, 70, 70),
	stamina = Color3.fromRGB(170, 90, 245),
	mana = Color3.fromRGB(60, 215, 225),
	health = Color3.fromRGB(70, 205, 120),
	defence = Color3.fromRGB(255, 165, 50),
} :: { [string]: Color3 }

-- Unseen blocks from the ground up: { first level, last level, x0, x1, y0, y1, top }, or round ones:
-- { first level, last level, x, y, radius, top }.
local SOLID: { [string]: { { number } } } = {
	track = {
		YARD,
		{ 4, 5, -15, 7, 15.9, 18.1, 1.35 }, -- the stand's four rows
		{ 4, 5, -15, 7, 18.1, 20.3, 2.45 },
		{ 4, 5, -15, 7, 20.3, 22.5, 3.55 },
		{ 4, 5, -15, 7, 22.5, 24.7, 4.65 },
	},
	gym = { YARD, { 2, 5, -28, -6, 5.5, 18.5, 0.95 } }, -- the lifting deck
	pool = {
		YARD,
		{ 1, 5, -30.8, 28.6, -15.4, -8.2, 1.75 }, -- the deck, round the water
		{ 1, 5, -30.8, 28.6, 10.2, 15.4, 1.75 },
		{ 1, 5, -30.8, -24.2, -8.2, 10.2, 1.75 },
		{ 1, 5, 16.2, 28.6, -8.2, 10.2, 1.75 },
		{ 1, 5, -24.2, 16.2, -8.2, 10.2, 1.4 }, -- the water: it is stood on
		{ 1, 5, -6, 6, -16.4, -15.4, 1.75 }, -- the steps up from the gate
		{ 1, 5, -6, 6, -17.4, -16.4, 1.375 },
		{ 1, 5, -6, 6, -18.4, -17.4, 1 },
		{ 1, 5, -6, 6, -19.4, -18.4, 0.625 },
	},
	library = { YARD, { 1, 5, 0, 2, 16.6, 0.55 } }, -- the slate floor
	spring = {
		YARD,
		{ 1, 5, 0, 1, 22.6, 0.45 }, -- the terrace
		{ 1, 5, 0, 1, 6.05, 1.2 }, -- the source's basin
		{ 1, 5, -6.8, -10.78, 5.25, 1.2 }, -- the baths, two more at each of the next levels
		{ 1, 5, 6.8, -10.78, 5.25, 1.2 },
		{ 2, 5, 13.6, 1, 5.25, 1.2 },
		{ 2, 5, -13.6, 1, 5.25, 1.2 },
		{ 3, 5, 6.8, 12.78, 5.25, 1.2 },
		{ 3, 5, -6.8, 12.78, 5.25, 1.2 },
	},
	guard = {
		YARD,
		{ 1, 5, -25, 25, -19.5, 15.5, 0.37 }, -- the court
		{ 3, 5, -20, 20, 17.8, 20.2, 7.75 }, -- the wall
		{ 4, 5, -23.5, 19, 4.2, 13.35 }, -- its towers
		{ 4, 5, 23.5, 19, 4.2, 13.35 },
	},
}

-- What an animal does while it trains at a station (decision 0066), from the Training Grounds level
-- `from` on (before a kit arrives it uses what stands there): the clip it plays, then either where it
-- stands, {x, y, z, yaw} in the yard's numbers with its nose (`nose`) or its middle there, or the two
-- ends of the length it swims. `book`: what it looks at, as {how far ahead of its nose, how high above
-- where it stands}. The track's round is worked out below.
-- `kit`: the piece it works at, which moves with it. `water`: how high the water it swims in stands.
type Work = {
	from: number,
	anim: string,
	nose: boolean?,
	at: { number }?,
	ends: { { number } }?,
	book: { number }?,
	kit: string?,
	water: number?,
}
local WORK: { [string]: { Work } } = {
	track = { { from = 0, anim = "run" } },
	gym = {
		{ from = 0, anim = "heave", nose = true, at = { -11.1, -13, 0.35, 90 }, kit = "boulder" }, -- at the boulder
		{ from = 2, anim = "heave", at = { -17, 12, 0.95, 0 }, kit = "bar" }, -- under the bar
	},
	pool = {
		{ from = 0, anim = "swim", ends = { { -13, 1, 0.1 }, { 4, 1.5, 0.1 } }, water = 0.32 }, -- the pond
		{ from = 1, anim = "swim", ends = { { -24, 1, 0.6 }, { 16, 1, 0.6 } }, water = 1.4 }, -- the middle lane
	},
	library = {
		{ from = 0, anim = "study", nose = true, at = { 0, 1.4, 0.3, 180 }, book = { 0.6, 2.75 } }, -- at the book on its stand
		{ from = 1, anim = "study", nose = true, at = { 0, -1.5, 0.55, 180 }, book = { 3.5, 3.9 }, kit = "crystal" }, -- at the great book
	},
	spring = {
		{ from = 0, anim = "soak", at = { 0, 1, 0.2, 20 } }, -- in the spring
		{ from = 1, anim = "soak", at = { -6.8, -10.78, 0.55, 30 } }, -- in the first bath
	},
	guard = {
		{ from = 0, anim = "brace", nose = true, at = { -3.5, -13.6, 0.25, 180 }, kit = "dummies" }, -- at a straw man
		{ from = 1, anim = "brace", nose = true, at = { 0, 2.2, 0.37, 180 }, kit = "ram" }, -- against the first ram
	},
}

-- `splash`: how far above its feet the water it swims in stands.
export type Act = { anim: string, at: CFrame?, round: { Vector3 }?, gaze: number?, kit: string?, splash: number? }

-- What the animal training at ranch `i`'s station does at Training Grounds `level`: its clip and where
-- it stands, or the round it goes (the track's lap, the pool's length and back), and for one that
-- reads how far up (degrees) its book is from its head. `size` is the animal's, in studs (width,
-- height, length).
function Areas.act(i: number, stationId: string, level: number, size: { number }): Act
	local length = size[3]
	local k = 1
	for n, st in StationConfig.STATIONS do
		if st.id == stationId then
			k = n
		end
	end
	local cf = World.areaFrame(i, k)
	local function point(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x * K, z * K, -y * K)).Position
	end
	local work = WORK[stationId][1]
	for _, w in WORK[stationId] do
		if w.from <= level then
			work = w
		end
	end
	if stationId == "track" then -- once round the second lane; from level 2 it leaps the far straight's hurdles
		local r, z = 8.6, if level >= 1 then 0.43 else 0.35
		local round = { point(-13, -r, z), point(13, -r, z) }
		for a = -60, 60, 30 do
			table.insert(round, point(13 + r * math.cos(math.rad(a)), r * math.sin(math.rad(a)), z))
		end
		table.insert(round, point(13, r, z))
		for _, x in if level >= 2 then { 8, 0, -8 } else {} do
			table.insert(round, point(x + 2.6, r, z))
			table.insert(round, point(x, r, z + 2.3))
			table.insert(round, point(x - 2.6, r, z))
		end
		table.insert(round, point(-13, r, z))
		for a = 120, 240, 30 do
			table.insert(round, point(-13 + r * math.cos(math.rad(a)), r * math.sin(math.rad(a)), z))
		end
		return { anim = work.anim, round = round }
	elseif work.ends then -- its nose a little short of each end
		local a, b = work.ends[1], work.ends[2]
		local reach = length / K / 2 + 0.6
		local round = { point(a[1] + reach, a[2], a[3]), point(b[1] - reach, b[2], b[3]) }
		return { anim = work.anim, round = round, splash = ((work.water or a[3]) - a[3]) * K }
	end
	local at = work.at :: { number }
	local facing = cf:VectorToWorldSpace(Vector3.new(math.sin(math.rad(at[4])), 0, math.cos(math.rad(at[4]))))
	local where = point(at[1], at[2], at[3]) - (if work.nose then facing * length / 2 else Vector3.zero)
	local book = work.book
	local gaze = if book
		then math.clamp(math.deg(math.atan2(book[2] * K - size[2] * 0.85, book[1] * K + length * 0.15)), -30, 35)
		else nil
	return { anim = work.anim, at = CFrame.lookAt(where, where + facing), gaze = gaze, kit = work.kit }
end

-- The kit that is a model of its own: { model, the level it arrives at, how it moves, how far along the
-- yard's x it stands from where it was built }, and the numbers its motion needs (studs): `High`, how
-- high above the animal's floor the piece's axis rests; `Least`, how low it may come; `Rope`, a ram's.
local KIT: { [string]: { { any } } } = {
	gym = { { "kit_gym_bar", 2, "bar", 0, { High = 12, Least = 6.8 } } },
	library = { { "kit_library_crystal", 3, "crystal", 0, {} } },
	guard = {
		{ "kit_guard_ram", 1, "ram", 0, { High = 8.1, Least = 3.7, Rope = 12.5 } },
		{ "kit_guard_ram", 2, "", -17, {} }, -- the two that hang idle
		{ "kit_guard_ram", 4, "", 17, {} },
	},
}

-- What moves inside an area's own models: a whole model, or its Neon piece of a colour.
local MOVES: { [string]: { model: string?, glow: { [string]: string }? } } = {
	area_gym_0_5 = { model = "boulder" },
	area_guard_0_5 = { model = "dummies" },
	area_track_5_5 = { glow = { ["60,150,255"] = "pulse" } }, -- the arrows round the bends
	area_gym_5_5 = { glow = { ["255,150,50"] = "flicker" } }, -- braziers
	area_guard_4_5 = { glow = { ["255,150,50"] = "flicker" } },
	area_library_0_0 = { glow = { ["255,200,90"] = "flicker" } }, -- candles
	area_library_1_5 = { glow = { ["255,200,90"] = "flicker" } },
	area_library_3_5 = { glow = { ["60,215,225"] = "pulse" } }, -- the font of mana
	area_library_5_5 = { glow = { ["150,120,255"] = "spin", ["60,215,225"] = "pulse" } }, -- rings of light, runes
	area_spring_1_5 = { glow = { ["150,240,226"] = "pulse" } }, -- the channels from the source
	area_spring_2_5 = { glow = { ["150,240,226"] = "pulse" } },
	area_spring_3_5 = { glow = { ["150,240,226"] = "pulse" } },
	area_spring_5_5 = { glow = { ["150,255,170"] = "pulse", ["70,205,120"] = "pulse" } }, -- lanterns, crystals
}

-- Where steam rises in the spring: { first level, x, y, z } (its source and its baths, as in SOLID).
local STEAM = {
	{ 0, 0, 1, 0.6 },
	{ 1, -6.8, -10.78, 1.0 },
	{ 1, 6.8, -10.78, 1.0 },
	{ 2, 13.6, 1, 1.0 },
	{ 2, -13.6, 1, 1.0 },
	{ 3, 6.8, 12.78, 1.0 },
	{ 3, -6.8, 12.78, 1.0 },
}

local function tagKit(inst: Instance, how: string)
	inst:SetAttribute("Kit", how)
	CollectionService:AddTag(inst, "Kit")
end

-- Stands one of an area's models and tags what moves in it.
local function slice(name: string, cf: CFrame, f: Instance)
	local model = Creatures.still(name, cf * CFrame.Angles(0, math.pi, 0), 1, f)
	local moves = MOVES[name]
	if model == nil or moves == nil then
		return
	end
	if moves.model == "boulder" then
		model:SetAttribute("Along", cf.RightVector) -- the way the animal shoves it
		tagKit(model, "boulder")
	elseif moves.model == "dummies" then
		model:SetAttribute("Foot", (cf * CFrame.new(0, 0.25 * K, 12.5 * K)).Position) -- the line their posts stand on
		model:SetAttribute("Along", cf.RightVector)
		tagKit(model, "dummies")
	end
	for part, rgb in StationAssets[name].glow do
		local how = moves.glow and moves.glow[`{rgb[1]},{rgb[2]},{rgb[3]}`]
		local piece = model:FindFirstChild(part)
		if how and piece then
			tagKit(piece, how)
		end
	end
end

-- Stands a piece of kit that is a model of its own. A ram hangs by two ropes from its frame's beam: they
-- are drawn here, so they follow the log wherever it swings.
local function kit(spec: { any }, cf: CFrame, f: Instance)
	local name, how, dx = spec[1] :: string, spec[3] :: string, spec[4] :: number
	local model = Creatures.still(name, cf * CFrame.new(dx * K, 0, 0) * CFrame.Angles(0, math.pi, 0), 1, f)
	if model == nil then
		return
	end
	for key, value in spec[5] :: { [string]: number } do
		model:SetAttribute(key, value)
	end
	if name == "kit_guard_ram" then
		local log = model:FindFirstChild("kit_guard_ram_body") :: BasePart
		local beam = Props.part(f, Vector3.new(1, 1, 1), cf * CFrame.new(dx * K, 8.6 * K, -8 * K), WHITE)
		beam.Transparency, beam.CanCollide, beam.CastShadow, beam.Name = 1, false, false, "Ropes"
		for _, dy in { -2.4, 2.4 } do
			local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
			top.Parent, bottom.Parent = beam, log
			top.WorldPosition = (cf * CFrame.new(dx * K, 8.6 * K, -(8 + dy * 0.2) * K)).Position
			bottom.WorldPosition = (cf * CFrame.new(dx * K, 4.6 * K, -(8 + dy) * K)).Position
			local rope = Instance.new("Beam")
			rope.Attachment0, rope.Attachment1 = top, bottom
			rope.Width0, rope.Width1, rope.FaceCamera, rope.Segments = 0.45, 0.45, true, 1
			rope.Color, rope.LightInfluence = ColorSequence.new(Color3.fromRGB(86, 88, 100)), 1
			rope.Parent = beam
		end
		model:SetAttribute("Back", -cf.LookVector) -- away from the animal on its pad
	elseif name == "kit_library_crystal" then
		model:SetAttribute("Foot", (cf * CFrame.new(0, 0, -2 * K)).Position) -- the line it turns about
	end
	if how ~= "" then
		tagKit(model, how)
	end
end

-- the models of each station, with the levels each stands at
local pieces: { [string]: { { name: string, first: number, last: number } } } = {}
for name in StationAssets do
	local station, first, last = string.match(name, "^area_(%a+)_(%d)_(%d)$")
	if station then
		pieces[station] = pieces[station] or {}
		table.insert(
			pieces[station],
			{ name = name, first = tonumber(first) :: number, last = tonumber(last) :: number }
		)
	end
end

-- Stands ranch `i`'s six areas as they are at Training Grounds `level`, in `parent`: the models, the
-- unseen blocks, a pad tagged "TrainPad" (Ranch, Station) at each area's middle, and each area's
-- name over its path where that leaves the ranch.
function Areas.build(parent: Instance, i: number, level: number)
	local ranch = World.ranchFrame(i)
	for k, st in StationConfig.STATIONS do
		local cf = World.areaFrame(i, k)
		local f = Instance.new("Folder")
		f.Name = st.id
		f.Parent = parent
		for _, piece in pieces[st.id] or {} do
			if piece.first <= level and level <= piece.last then
				task.spawn(slice, piece.name, cf, f) -- each has to load
			end
		end
		for _, s in SOLID[st.id] do
			if s[1] <= level and level <= s[2] then
				local block: Part
				if #s == 6 then
					block =
						Props.pillar(f, (cf * CFrame.new(s[3] * K, 0, -s[4] * K)).Position, s[6] * K, s[5] * K, WHITE)
				else
					local size = Vector3.new((s[4] - s[3]) * K, s[7] * K, (s[6] - s[5]) * K)
					local middle = CFrame.new((s[3] + s[4]) / 2 * K, s[7] * K / 2, -(s[5] + s[6]) / 2 * K)
					block = Props.part(f, size, cf * middle, WHITE)
				end
				block.Transparency, block.CastShadow, block.Name = 1, false, "Solid"
			end
		end
		for _, spec in KIT[st.id] or {} do
			if (spec[2] :: number) <= level then
				task.spawn(kit, spec, cf, f)
			end
		end
		if st.id == "guard" and level >= 3 then -- the two throwers lob balls at the shields they face
			for _, side in { -1, 1 } do
				local at = cf * CFrame.new(side * 23.8 * K, 4.3 * K, 13 * K)
				local thrower = Props.part(f, Vector3.new(1, 1, 1), at, Areas.COLOUR.defence)
				thrower.Transparency, thrower.CanCollide, thrower.CastShadow, thrower.Name = 1, false, false, "Thrower"
				thrower:SetAttribute("To", (cf * CFrame.new(side * 18.2 * K, 3.2 * K, 13 * K)).Position)
				thrower:SetAttribute("Phase", if side > 0 then 1.6 else 0)
				tagKit(thrower, "lob")
			end
		elseif st.id == "spring" then -- steam off the water
			for _, s in STEAM do
				if s[1] <= level and (s[1] > 0 or level == 0) then
					local vent =
						Props.part(f, Vector3.new(6, 0.2, 6), cf * CFrame.new(s[2] * K, s[4] * K, -s[3] * K), WHITE)
					vent.Transparency, vent.CanCollide, vent.CastShadow, vent.Name = 1, false, false, "Steam"
					local steam = Instance.new("ParticleEmitter")
					steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
					steam.Color = ColorSequence.new(WHITE)
					steam.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.25, 0.72),
						NumberSequenceKeypoint.new(1, 1),
					})
					steam.Size = NumberSequence.new(3, 8)
					steam.Lifetime, steam.Rate = NumberRange.new(3, 5), 3
					steam.Speed, steam.SpreadAngle = NumberRange.new(1.5, 3), Vector2.new(12, 12)
					steam.RotSpeed, steam.LightEmission = NumberRange.new(-15, 15), 0.3
					steam.EmissionDirection = Enum.NormalId.Top
					steam.Parent = vent
				end
			end
		end
		local pad = Props.part(f, Vector3.new(4, 0.2, 4), cf * CFrame.new(0, 0.1, 0), WHITE)
		pad.Name, pad.Transparency, pad.CanCollide = st.id, 1, false
		pad:SetAttribute("Ranch", i)
		pad:SetAttribute("Station", st.id)
		CollectionService:AddTag(pad, "TrainPad")
		-- the sign stands over the path, a little way out of the plot's fence
		local from = (ranch * CFrame.new(World.AREA_GATE[k])).Position
		local along = ((cf.Position - cf.LookVector * 62 - from) * Vector3.new(1, 0, 1)).Unit
		local colour = Areas.COLOUR[st.stat]:Lerp(INK, 0.25)
		World.kit.signboard(f, CFrame.lookAt(from + along * 24, from), 18, st.name, colour, 9)
	end
end

return Areas
