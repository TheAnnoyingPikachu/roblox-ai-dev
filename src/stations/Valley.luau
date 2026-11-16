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
	track = M.Grass,
	gym = M.Sandstone,
	pool = M.Sand,
	library = M.Slate,
	spring = M.LeafyGrass,
	guard = M.Limestone,
}

-- The colours of the land's materials: the animals' world is bright and flat-toned.
function Valley.colours(terrain: Terrain)
	terrain:SetMaterialColor(M.Ground, Color3.fromRGB(206, 186, 150))
	terrain:SetMaterialColor(M.Sand, Color3.fromRGB(236, 220, 172))
	terrain:SetMaterialColor(M.Rock, Color3.fromRGB(132, 128, 146))
	terrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(214, 190, 142))
	terrain:SetMaterialColor(M.Limestone, Color3.fromRGB(226, 210, 172))
	terrain:SetMaterialColor(M.Slate, Color3.fromRGB(84, 86, 120))
	terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(150, 198, 118))
	terrain:SetMaterialColor(M.Snow, Color3.fromRGB(240, 244, 250))
	terrain.WaterColor = Color3.fromRGB(64, 170, 226)
	terrain.WaterTransparency, terrain.WaterReflectance = 0.25, 0.3
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

export type Kit = {
	tree: (Instance, Vector3, Random, number) -> (),
	pine: (Instance, Vector3, number, Random) -> (),
	rock: (Instance, Vector3, number, Random) -> (),
}

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
