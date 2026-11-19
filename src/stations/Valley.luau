--!strict
-- A ranch's valley in the world (decision 0070): writes the land of src/shared/ValleyMap.luau into the
-- terrain (its lake and stream as water), and dresses it: trees, the waterfall behind the spring,
-- bridges where a path crosses the stream. Display only: no game rules live here.
--
-- Smooth terrain stands two studs above what a column is filled to (measured in Studio: a top voxel
-- that is a quarter full stands at its bottom + 3, a full one at its bottom + 6), so a column is
-- filled to its height less two.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ValleyMap = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ValleyMap"))
local Props = require(script.Parent:WaitForChild("Props"))

local Valley = {}

local M = Enum.Material
local VOXEL, SIDE = 4, 16 -- a voxel's size, and how many columns a side are written at once
local DEPTH = 44 -- how far under the homestead the land is solid
local MATERIAL: { [string]: Enum.Material } = {
	grass = M.Grass,
	path = M.Ground,
	sand = M.Sand,
	rock = M.Rock,
	snow = M.Snow,
	-- the floor of each training ground
	track = M.LeafyGrass, -- no grass blades up through its lanes and pond (decision 0086)
	gym = M.Sandstone,
	pool = M.Sand,
	library = M.Slate,
	spring = M.LeafyGrass,
	guard = M.Limestone,
}

local LEDGE = { Color3.fromRGB(150, 142, 132), Color3.fromRGB(136, 128, 120), Color3.fromRGB(164, 154, 140) } -- the mountains' greys
local GRASS = Color3.fromRGB(108, 168, 72)

-- The colours of the land's materials: the animals' world is bright and flat-toned.
function Valley.colours(terrain: Terrain)
	-- decision 0085: warm grey stone, deeper greens, a deeper blue water
	terrain:SetMaterialColor(M.Ground, Color3.fromRGB(176, 150, 112))
	terrain:SetMaterialColor(M.Sand, Color3.fromRGB(232, 214, 168))
	terrain:SetMaterialColor(M.Rock, Color3.fromRGB(138, 138, 124))
	terrain:SetMaterialColor(M.Basalt, Color3.fromRGB(110, 106, 100))
	terrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(214, 190, 142))
	terrain:SetMaterialColor(M.Limestone, Color3.fromRGB(226, 210, 172))
	terrain:SetMaterialColor(M.Slate, Color3.fromRGB(118, 120, 112))
	terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(104, 164, 70)) -- close to Grass: it lies under floors and ponds
	terrain:SetMaterialColor(M.Snow, Color3.fromRGB(246, 248, 252))
	terrain.WaterColor = Color3.fromRGB(48, 150, 196)
	terrain.WaterTransparency, terrain.WaterReflectance = 0.35, 0.45
	terrain.WaterWaveSize, terrain.WaterWaveSpeed = 0.1, 6
end

-- Writes the valley of the ranch whose frame is `frame` (its middle on the homestead's ground, looking
-- at the hub; turned a whole number of quarter turns, so the plan's axes lie along the world's).
function Valley.write(terrain: Terrain, frame: CFrame)
	local origin, right, away = frame.Position, frame.RightVector, -frame.LookVector
	local half = ValleyMap.HALF
	local bottom = origin.Y - 2 - DEPTH
	terrain:FillBlock(CFrame.new(origin + Vector3.new(0, 150, 0)), Vector3.new(half * 2, 396, half * 2), M.Air)
	local span = SIDE * VOXEL
	for cx = -half, half - span, span do
		for cz = -half, half - span, span do
			local x0, z0 = origin.X + cx, origin.Z + cz -- this block of columns, in the world
			-- heights at each column's middle, one further each way for the slope
			local hs = table.create((SIDE + 1) * (SIDE + 1), 0)
			local low, high = math.huge, -math.huge
			for i = 0, SIDE do
				for j = 0, SIDE do
					local d = Vector3.new(cx + i * VOXEL + 2, 0, cz + j * VOXEL + 2)
					local world = Vector3.new(d.X, 0, d.Z)
					local px, pz = world:Dot(right), world:Dot(away)
					local h = ValleyMap.height(px, pz)
					hs[i * (SIDE + 1) + j + 1] = h
					if i < SIDE and j < SIDE then
						low, high = math.min(low, h), math.max(high, h)
					end
				end
			end
			-- rock below, then a band of voxels the land's top and its water lie in
			local y0 = math.max(bottom, math.floor((origin.Y + low - 2) / VOXEL) * VOXEL - VOXEL)
			local y1 = math.ceil((origin.Y + math.max(high, ValleyMap.LAKE) + 2) / VOXEL) * VOXEL + VOXEL
			if y0 > bottom then
				local mid = Vector3.new(x0 + span / 2, (bottom + y0) / 2, z0 + span / 2)
				terrain:FillBlock(CFrame.new(mid), Vector3.new(span, y0 - bottom, span), M.Rock)
			end
			local layers = (y1 - y0) // VOXEL
			local mats, occs = table.create(SIDE), table.create(SIDE)
			for i = 1, SIDE do
				local matX, occX = table.create(layers), table.create(layers)
				for k = 1, layers do
					matX[k], occX[k] = table.create(SIDE, M.Air), table.create(SIDE, 0)
				end
				mats[i], occs[i] = matX, occX
			end
			for i = 0, SIDE - 1 do
				for j = 0, SIDE - 1 do
					local at = i * (SIDE + 1) + j + 1
					local h = hs[at]
					local steep = (math.abs(hs[at + SIDE + 1] - h) + math.abs(hs[at + 1] - h)) / (2 * VOXEL)
					local d = Vector3.new(cx + i * VOXEL + 2, 0, cz + j * VOXEL + 2)
					local px, pz = d:Dot(right), d:Dot(away)
					local material = MATERIAL[ValleyMap.kind(px, pz, h, steep)]
					local fill = origin.Y + h - 2
					local wet = ValleyMap.water(px, pz, h)
					local pour = if wet then origin.Y + wet - 2 else -math.huge
					for k = 1, layers do
						local y = y0 + (k - 1) * VOXEL
						local solid = math.clamp((fill - y) / VOXEL, 0, 1)
						if solid >= 0.5 or (solid > 0 and pour <= y) then
							mats[i + 1][k][j + 1], occs[i + 1][k][j + 1] = material, solid
						elseif pour > y then
							mats[i + 1][k][j + 1], occs[i + 1][k][j + 1] = M.Water, math.clamp((pour - y) / VOXEL, 0, 1)
						end
					end
				end
			end
			-- WriteVoxels takes its cells as [x][y][z] along the world's axes: turn this block's (i, j)
			-- into them (i runs along the world's x and j along its z already)
			terrain:WriteVoxels(
				Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + span, y1, z0 + span)),
				VOXEL,
				mats,
				occs
			)
		end
	end
end

-- Cuts the Titan's Den's hall out of the hill ValleyMap raises behind it (decision 0075): heights cannot
-- hold a cave, so the hall is emptied after the land is written. Its floor is the homestead's ground.
function Valley.den(terrain: Terrain, frame: CFrame)
	local den = ValleyMap.DEN
	local out = Vector3.new(math.cos(math.rad(den.deg)), 0, math.sin(math.rad(den.deg)))
	local mid = (den.face - 4 + den.back) / 2
	local centre = frame * (out * mid + Vector3.new(0, (den.tall - 2) / 2, 0)) -- from 2 below the ground (a voxel's top)
	local look = CFrame.lookAt(centre, centre + frame:VectorToWorldSpace(out))
	terrain:FillBlock(look, Vector3.new(den.half * 2, den.tall + 2, den.back - den.face + 4), Enum.Material.Air)
end

export type Kit = {
	tree: (Instance, Vector3, Random, number) -> (),
	pine: (Instance, Vector3, number, Random) -> (),
	rock: (Instance, Vector3, number, Random) -> (),
	bush: (Instance, Vector3, number, Random) -> (),
}

-- Whether (x, z) in the plan is clear for a tree round a training ground: off the paths, the stream,
-- the water, the homestead, the den's hill and every ground.
local function wild(x: number, z: number, h: number): boolean
	if x * x + z * z < (ValleyMap.HOME + 12) ^ 2 or ValleyMap.stream(x, z) < 12 or ValleyMap.water(x, z, h) then
		return false
	end
	for _, g in ValleyMap.GROUNDS do
		if (x - g.x) ^ 2 + (z - g.z) ^ 2 < (ValleyMap.PAD + 4) ^ 2 then
			return false
		end
	end
	for _, w in ValleyMap.WAYS do
		local dx, dz = w.bx - w.sx, w.bz - w.sz
		local t = math.clamp(((x - w.sx) * dx + (z - w.sz) * dz) / (dx * dx + dz * dz), 0, 1)
		if (x - w.sx - dx * t) ^ 2 + (z - w.sz - dz * t) ^ 2 < 16 * 16 then
			return false
		end
	end
	local den = ValleyMap.DEN
	local ox, oz = math.cos(math.rad(den.deg)), math.sin(math.rad(den.deg))
	local along, across = x * ox + z * oz, math.abs(z * ox - x * oz)
	return not (along > den.face - 12 and along < den.back + 40 and across < den.half + 30)
end

-- The rock round the training grounds (decision 0087), on a fixed grid: calls `fn(x, z, s, gx, gz)` for
-- each spot of bare rock clear of everything (`wild`), with its slope `s` over 12 studs and the way
-- downhill (gx, gz). A spot with `s` under TOP is a grassy top; steeper, it may hold a ledge.
local TOP = 0.9
local function rocky(fn: (number, number, number, number, number) -> ())
	for _, g in ValleyMap.GROUNDS do
		for r = ValleyMap.PAD + 10, ValleyMap.PAD + 94, 8 do
			local n = math.floor(2 * math.pi * r / 10)
			for k = 0, n - 1 do
				local a = k / n * 2 * math.pi
				local x, z = g.x + math.cos(a) * r, g.z + math.sin(a) * r
				local h = ValleyMap.height(x, z)
				local fine = (math.abs(ValleyMap.height(x + 4, z) - h) + math.abs(ValleyMap.height(x, z + 4) - h)) / 8
				if h < 100 and ValleyMap.kind(x, z, h, fine) == "rock" and wild(x, z, h) then
					local gx = (ValleyMap.height(x - 6, z) - ValleyMap.height(x + 6, z)) / 12
					local gz = (ValleyMap.height(x, z - 6) - ValleyMap.height(x, z + 6)) / 12
					fn(x, z, math.sqrt(gx * gx + gz * gz), gx, gz)
				end
			end
		end
	end
end

-- Turns the rock to grass where it lies nearly flat round the training grounds (decision 0087). Called
-- after `Valley.write`.
function Valley.tops(terrain: Terrain, frame: CFrame)
	rocky(function(x, z, s)
		if s < TOP then
			local at = (frame * CFrame.new(x, ValleyMap.height(x, z), z)).Position
			local box = Region3.new(at - Vector3.new(6, 6, 6), at + Vector3.new(6, 3, 6)):ExpandToGrid(VOXEL)
			terrain:ReplaceMaterial(box, VOXEL, M.Rock, M.LeafyGrass)
		end
	end)
end

-- Dresses the valley of `frame`: trees and rocks on its slopes, the waterfall behind the spring, a
-- bridge where a path crosses the stream.
function Valley.dress(parent: Instance, frame: CFrame, rng: Random, kit: Kit)
	local function on(x: number, z: number, up: number?): Vector3
		return (frame * CFrame.new(x, ValleyMap.height(x, z) + (up or 0), z)).Position
	end
	local planted, tries = 0, 0
	while planted < 90 and tries < 1500 do
		tries += 1
		local x, z = rng:NextNumber(-400, 400), rng:NextNumber(-400, 400)
		local h = ValleyMap.height(x, z)
		local steep = (math.abs(ValleyMap.height(x + 4, z) - h) + math.abs(ValleyMap.height(x, z + 4) - h)) / 8
		local clear = x * x + z * z > 128 * 128 and ValleyMap.stream(x, z) > 12 and not (z < -75 and math.abs(x) < 46)
		if clear and steep < 0.3 and h > -6 and h < 100 and ValleyMap.kind(x, z, h, steep) == "grass" then
			for _, g in ValleyMap.GROUNDS do
				clear = clear and (x - g.x) ^ 2 + (z - g.z) ^ 2 > (ValleyMap.PAD + 6) ^ 2
			end
			for _, w in ValleyMap.WAYS do
				local dx, dz = w.bx - w.sx, w.bz - w.sz
				local t = math.clamp(((x - w.sx) * dx + (z - w.sz) * dz) / (dx * dx + dz * dz), 0, 1)
				clear = clear and (x - w.sx - dx * t) ^ 2 + (z - w.sz - dz * t) ^ 2 > 14 * 14
			end
			if clear then
				planted += 1
				local at = on(x, z)
				local roll = rng:NextNumber()
				if roll < 0.45 then
					kit.tree(parent, at, rng, rng:NextNumber(1.3, 2))
				elseif roll < 0.8 then
					kit.pine(parent, at, rng:NextNumber(1.4, 2.2), rng)
				else
					kit.rock(parent, at, rng:NextNumber(3, 6), rng)
				end
			end
		end
	end

	-- the rock round the training grounds (decision 0087): a pine on some grassy tops, and on the steep
	-- faces stone ledges with grass on them, set into the face so none stands out over a gap
	rocky(function(x, z, s, gx, gz)
		if s < TOP then
			if rng:NextNumber() < 0.3 then
				kit.pine(parent, on(x, z, -1), rng:NextNumber(1.3, 1.9), rng)
			end
		elseif s < 3.5 and rng:NextNumber() < 0.2 then -- about 220 a ranch, three parts each
			local top = on(x, z)
			local out = frame:VectorToWorldSpace(Vector3.new(gx, 0, gz)).Unit
			local w, deep = rng:NextNumber(12, 24), rng:NextNumber(7, 11)
			local shelf = CFrame.lookAt(top, top + out)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4)))
				* CFrame.new(0, -1.4, deep / 2 - 3) -- mostly into the face: 3 studs stand out
			Props.part(parent, Vector3.new(w, 3.4, deep), shelf, LEDGE[rng:NextInteger(1, #LEDGE)], M.Slate)
			local under = shelf * CFrame.new(rng:NextNumber(-2, 2), -2.4, 0.6)
			Props.part(parent, Vector3.new(w * 0.8, 2.6, deep * 0.8), under, LEDGE[rng:NextInteger(1, #LEDGE)], M.Slate)
			Props.part(parent, Vector3.new(w - 0.6, 0.7, deep - 0.6), shelf * CFrame.new(0, 2, 0), GRASS, M.Grass)
			local roll, spot =
				rng:NextNumber(), (shelf * CFrame.new(rng:NextNumber(-w / 3, w / 3), 2.3, -deep / 2 + 2)).Position
			if roll < 0.45 then
				kit.bush(parent, spot, rng:NextNumber(1, 1.5), rng)
			elseif roll < 0.75 then
				kit.pine(parent, spot, rng:NextNumber(0.9, 1.4), rng)
			end
		end
	end)

	-- round each training ground (decision 0086): a border of bushes and rocks on its rim, open where its
	-- path comes in (no flower clumps: twelve parts each), and woods up the slopes behind (trees where it
	-- is gentle, pines steeper)
	for _, g in ValleyMap.GROUNDS do
		local home = math.deg(math.atan2(-g.z, -g.x)) -- the way its path comes in from
		for a = 0, 359, 9 do
			if math.abs((a - home + 180) % 360 - 180) > 16 then
				local r = ValleyMap.PAD + 2 + rng:NextNumber(-3, 5)
				local x, z = g.x + math.cos(math.rad(a)) * r, g.z + math.sin(math.rad(a)) * r
				if not ValleyMap.water(x, z, ValleyMap.height(x, z)) and ValleyMap.stream(x, z) > 8 then
					if rng:NextNumber() < 0.6 then
						kit.bush(parent, on(x, z), rng:NextNumber(1.1, 1.7), rng)
					else
						kit.rock(parent, on(x, z), rng:NextNumber(2, 4), rng)
					end
				end
			end
		end
		for _ = 1, 260 do -- about half land: the rest is on a path, the water or another ground
			local a, r = rng:NextNumber(0, 360), rng:NextNumber(ValleyMap.PAD + 6, ValleyMap.PAD + 75)
			local x, z = g.x + math.cos(math.rad(a)) * r, g.z + math.sin(math.rad(a)) * r
			local h = ValleyMap.height(x, z)
			local steep = (math.abs(ValleyMap.height(x + 4, z) - h) + math.abs(ValleyMap.height(x, z + 4) - h)) / 8
			if math.abs((a - home + 180) % 360 - 180) > 22 and steep < 1.2 and h < 100 and wild(x, z, h) then
				if steep < 0.35 and rng:NextNumber() < 0.55 then
					kit.tree(parent, on(x, z), rng, rng:NextNumber(1.1, 1.6))
				else
					kit.pine(parent, on(x, z, -1), rng:NextNumber(1.3, 2.1), rng)
				end
			end
		end
	end

	-- the waterfall: down the slope behind the spring, into its basin
	local spring = ValleyMap.GROUNDS[5]
	local away = Vector3.new(spring.x, 0, spring.z).Unit
	local top, foot = ValleyMap.PAD + 46, ValleyMap.PAD - 4
	local last: Vector3? = nil
	for step = 0, 6 do
		local d = top + (foot - top) * step / 6
		local p = on(spring.x + away.X * d, spring.z + away.Z * d, 1.2)
		if last then
			local fall = Props.part(
				parent,
				Vector3.new(12, 1.2, (p - last).Magnitude + 1),
				CFrame.lookAt((p + last) / 2, p),
				Color3.fromRGB(186, 230, 250),
				M.Glass
			)
			fall.Transparency, fall.CanCollide, fall.CastShadow, fall.Name = 0.3, false, false, "Waterfall"
		end
		last = p
	end
	for k = 0, 9 do -- foam round the waterfall's foot (decision 0085)
		local a = k / 10 * math.pi * 2
		local p = (last :: Vector3) + Vector3.new(math.cos(a) * 6.5, 0.4, math.sin(a) * 6.5)
		local foam = Props.part(
			parent,
			Vector3.new(4.5, 0.6, 3),
			CFrame.new(p) * CFrame.Angles(0, -a, 0),
			Color3.fromRGB(240, 248, 255),
			M.SmoothPlastic
		)
		foam.Transparency, foam.CanCollide, foam.CastShadow, foam.Name = 0.25, false, false, "Foam"
	end
	local pool = Props.part(parent, Vector3.new(16, 1, 16), CFrame.new(last :: Vector3), Color3.new(1, 1, 1), M.Neon)
	pool.Transparency, pool.CanCollide, pool.CastShadow, pool.Name = 1, false, false, "Mist"
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
	mist.Transparency = NumberSequence.new(0.55, 1)
	mist.Size = NumberSequence.new(4, 10)
	mist.Lifetime, mist.Rate = NumberRange.new(1.5, 3), 10
	mist.Speed, mist.SpreadAngle = NumberRange.new(3, 7), Vector2.new(50, 50)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Parent = pool

	-- a plank bridge where a path crosses the stream
	for _, w in ValleyMap.WAYS do
		local best, at = 4, nil :: number?
		for step = 0, 120 do
			local t = step / 120
			local d = ValleyMap.stream(w.sx + (w.bx - w.sx) * t, w.sz + (w.bz - w.sz) * t)
			if d < best then
				best, at = d, t
			end
		end
		if at then
			local dx, dz = w.bx - w.sx, w.bz - w.sz
			local x, z = w.sx + dx * at, w.sz + dz * at
			local len = math.sqrt(dx * dx + dz * dz)
			local ux, uz = dx / len, dz / len
			local a, b = on(x - ux * 13, z - uz * 13, 0.5), on(x + ux * 13, z + uz * 13, 0.5)
			local deck = CFrame.lookAt((a + b) / 2, b)
			Props.part(
				parent,
				Vector3.new(13, 0.8, (b - a).Magnitude + 2),
				deck,
				Color3.fromRGB(170, 118, 72),
				M.WoodPlanks
			)
			for _, side in { -6, 6 } do
				local rail = Vector3.new(0.6, 0.6, (b - a).Magnitude + 2)
				Props.part(parent, rail, deck * CFrame.new(side, 2.6, 0), Color3.fromRGB(196, 64, 54), M.Wood)
				for _, along in { -11, 0, 11 } do
					local post = deck * CFrame.new(side, 1.3, along)
					Props.part(parent, Vector3.new(0.7, 2.6, 0.7), post, Color3.fromRGB(112, 76, 48), M.Wood)
				end
			end
		end
	end
end

return Valley
