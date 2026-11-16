--!strict
-- What stands on a ranch plot (decision 0034). The plot itself (lawn, fence, gate, teleport pad)
-- is World's; this builds everything on it from the owner's upgrade levels and builds it again
-- when one changes, so every upgrade makes the ranch look bigger and better:
--   the Ranch House (at the back, facing the gate), the Barn and its yard (right of the path) and
--   the six training courts (a row across the middle) each have a look per level;
--   the sum of all levels (0 to 14) brings the rest: paved paths, lantern posts, flowers, a pond,
--   benches, a rest pavilion, a well, a fountain, flags, and more trees, bushes and rocks.
-- Upgrades are bought in the ranch menu, opened at the house door (a prompt tagged "RanchMenu").
-- Bought eggs wait on the egg storage rack (a prompt tagged "EggStorage" lets the owner choose
-- one to hatch) and hatch in the hatchery's six nests, where a finished egg is opened by its own
-- prompt (Ranch.eggs shows them all). Two vendors' stalls stand by the path (prompts tagged
-- "Vendor", attribute Kind = "eggs" or "gear"). Also tagged:
-- TrainPad (Ranch, Station), RanchSpot (Ranch, Index), RanchNest (Ranch). Display only: no game
-- rules live here.
-- Layout coordinates: x across, z from the gate (-60) to the back fence (60), y up from the
-- lawn. They are stretched by G onto the real plot (World.RANCH_HALF), so a bigger plot spreads
-- everything out while buildings keep their size.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationConfig"))
local Props = require(script.Parent:WaitForChild("Props"))
local World = require(script.Parent:WaitForChild("World"))

local part, pillar = Props.part, Props.pillar
local kit = World.kit
local disc, ball, bar, glow = kit.disc, kit.ball, kit.bar, kit.glow
local pine, bush, rock = kit.pine, kit.bush, kit.rock

local Ranch = {}

local H = World.RANCH_HALF
local G = H / 60 -- real studs per layout stud

local M = Enum.Material
local V = Vector3.new
local rad = math.rad
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(45, 40, 55)
local STONE = Color3.fromRGB(150, 146, 140)
local PATH = Color3.fromRGB(214, 198, 168)
local DIRT = Color3.fromRGB(168, 128, 86)
local LOG = Color3.fromRGB(184, 126, 74)
local WOOD = Color3.fromRGB(170, 118, 72)
local WOOD_DARK = Color3.fromRGB(112, 76, 48)
local BARK = Color3.fromRGB(96, 66, 44)
local ROOF = Color3.fromRGB(96, 70, 62)
local HAY = Color3.fromRGB(232, 196, 110)
local WARM = Color3.fromRGB(255, 214, 140)
local WATER = Color3.fromRGB(80, 170, 235)
local GLASS = Color3.fromRGB(130, 165, 190)
local COURT = Color3.fromRGB(44, 46, 60)
local GOLD = Color3.fromRGB(255, 200, 70)
local PADDOCK = Color3.fromRGB(104, 168, 72)
local HEDGE = Color3.fromRGB(70, 140, 72)
local BLADE = Color3.fromRGB(86, 150, 62)
local SHUTTER = Color3.fromRGB(66, 122, 112)
local BANNER = Color3.fromRGB(226, 78, 64)
local BLOOM = { Color3.fromRGB(255, 140, 185), Color3.fromRGB(255, 225, 100), Color3.fromRGB(185, 150, 255) }
local STAT_COLOUR: { [string]: Color3 } = {
	speed = Color3.fromRGB(60, 150, 255),
	strength = Color3.fromRGB(235, 70, 70),
	stamina = Color3.fromRGB(170, 90, 245),
	mana = Color3.fromRGB(60, 215, 225),
	health = Color3.fromRGB(70, 205, 120),
	defence = Color3.fromRGB(255, 165, 50),
}

-- Where each upgrade's pad stands, the Barn's size per level, and when the extras arrive (the
-- sum of all upgrade levels, 0 to 14).
local BARN_SCALE = { 0.62, 0.74, 0.86, 0.98, 1.1 }
local PAVED, LANTERNS, FLOWERS, POND, BENCHES, WINDMILL, MORE_LANTERNS, PAVILION, WELL, FOUNTAIN, FLAGS =
	1, 2, 3, 4, 5, 5, 6, 7, 8, 10, 12
-- Ground that is taken (x0, x1, z0, z1): scattered trees, bushes and rocks keep off all of it,
-- grass only off the hard part.
local HARD = {
	{ -6.5, 6.5, -60, 19 }, -- the path
	{ -9, 9, 17, 34 }, -- the plaza
	{ -58, 58, 7.5, 14.5 }, -- the cross path
	{ -57, 57, 12, 30.5 }, -- the courts
	{ -26, 26, 35, 60 }, -- the house
	{ -49.5, -28.5, 35.5, 56.5 }, -- the pond
	{ 28.5, 50, 39, 54 }, -- the pavilion
	{ 47, 59, 38, 50 }, -- the windmill
	{ 27, 58, -58, 0 }, -- the barn and its silos
	{ 7, 27, -58, 2 }, -- the yard: spots, nest, pads
}
local TAKEN = table.clone(HARD)
table.insert(TAKEN, { -57.5, -7, -55.5, 6.5 }) -- the roaming area

local function clear(list: { { number } }, x: number, z: number, margin: number): boolean
	for _, r in list do
		if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
			return false
		end
	end
	return true
end

-- Up to `n` free points on the plot: always the same ones in the same order for a seed, so a
-- higher level only adds to what was there.
local function scatter(seed: number, n: number, list: { { number } }, margin: number): { Vector3 }
	local rng, out = Random.new(seed), {}
	for _ = 1, 600 do
		if #out >= n then
			break
		end
		local x, z = rng:NextNumber(-57, 57), rng:NextNumber(-57, 57)
		if clear(list, x, z, margin) then
			table.insert(out, V(x, 0, z))
		end
	end
	return out
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

-- A gabled roof over a w x d box; `top` is the middle of the box's top. The ridge runs along x
-- and the eaves hang over the front and back. `gable` fills the two ends.
local function roof(f: Instance, top: CFrame, w: number, d: number, rise: number, gable: Color3?)
	for _, side in { -1, 1 } do
		local turn = CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		local half = Instance.new("WedgePart")
		half.Anchored, half.Size = true, V(w + 2, rise, d / 2 + 1)
		half.CFrame = top * CFrame.new(0, rise / 2, side * (d / 4 + 0.5)) * turn
		half.Color, half.Material = ROOF, M.Slate
		half.Parent = f
		if gable then
			for _, x in { -(w / 2 - 0.5), w / 2 - 0.5 } do
				local g = Instance.new("WedgePart")
				g.Anchored, g.Size = true, V(1, rise - 0.5, d / 2)
				g.CFrame = top * CFrame.new(x, (rise - 0.5) / 2, side * d / 4) * turn
				g.Color, g.Material = gable, M.WoodPlanks
				g.Parent = f
			end
		end
	end
end

-- Small things ---------------------------------------------------------------------------------------

local function tuft(f: Instance, at: Vector3, rng: Random)
	for _ = 1, 3 do
		local turn = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4))
		local blade =
			part(f, V(0.25, rng:NextNumber(1, 1.6), 0.25), CFrame.new(at + V(0, 0.9, 0)) * turn, BLADE, M.SmoothPlastic)
		blade.CanCollide = false
	end
end

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

local function barrel(f: Instance, base: Vector3)
	pillar(f, base, 2.8, 1.1, WOOD, M.WoodPlanks)
	for _, y in { 0.7, 2.3 } do
		disc(f, base + V(0, y, 0), 2.35, 0.25, INK, M.Metal)
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
	disc(f, centre + V(0, 0.6, 0), d + 2.6, 0.3, STONE, M.Slate)
	disc(f, centre + V(0, 0.75, 0), d, 0.25, WATER, M.Glass)
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		rock(f, centre + V(math.cos(a), 0, math.sin(a)) * (d / 2 + 1.2), rng:NextNumber(1.6, 3), rng)
	end
	for _ = 1, 4 do
		local p = centre + V(rng:NextNumber(-d / 3, d / 3), 0.85, rng:NextNumber(-d / 3, d / 3))
		disc(f, p, 1.6, 0.1, Color3.fromRGB(70, 160, 80), M.SmoothPlastic)
		ball(f, p + V(0.3, 0.15, 0), 0.5, BLOOM[1], M.SmoothPlastic)
	end
	for k = 1, 3 do -- reeds
		local a = k * 2.1
		local foot = centre + V(math.cos(a), 0, math.sin(a)) * (d / 2 - 0.6)
		pillar(f, foot + V(0, 0.6, 0), 3, 0.1, HEDGE, M.SmoothPlastic)
		pillar(f, foot + V(0, 3.2, 0), 0.9, 0.2, BARK, M.SmoothPlastic)
	end
end

-- A paved strip `w` wide and `l` long round `where` (its middle on the ground): grout with stone
-- slabs on it, each a little different.
local function paved(f: Instance, where: CFrame, w: number, l: number, rng: Random)
	part(f, V(w, 0.4, l), where * CFrame.new(0, 0.25, 0), STONE, M.Slate)
	local nx, nz = math.max(1, math.round(w / 4.4)), math.max(1, math.round(l / 4.4))
	local sx, sz = w / nx, l / nz
	for ix = 1, nx do
		for iz = 1, nz do
			local slab = where * CFrame.new(-w / 2 + (ix - 0.5) * sx, 0.42, -l / 2 + (iz - 0.5) * sz)
			part(f, V(sx - 0.3, 0.3, sz - 0.3), slab, PATH:Lerp(STONE, rng:NextNumber(0, 0.4)), M.Slate)
		end
	end
end

-- The Ranch House --------------------------------------------------------------------------------------

-- A framed window with a cross on a wall facing -z (`wall`: on the wall's face at floor level).
-- With `dressed`: shutters and a flower box.
local function window(f: Instance, wall: CFrame, x: number, lit: boolean, dressed: boolean): Part
	local y = 4.9
	local pane = part(
		f,
		V(2.6, 3, 0.3),
		wall * CFrame.new(x, y, -0.05),
		if lit then WARM else GLASS,
		if lit then M.Neon else M.Glass
	)
	part(f, V(3.3, 0.35, 0.5), wall * CFrame.new(x, y + 1.65, -0.15), WHITE, M.Wood)
	part(f, V(3.5, 0.4, 0.7), wall * CFrame.new(x, y - 1.65, -0.2), WHITE, M.Wood)
	for _, sx in { -1, 1 } do
		part(f, V(0.35, 3, 0.5), wall * CFrame.new(x + sx * 1.45, y, -0.15), WHITE, M.Wood)
	end
	part(f, V(0.18, 3, 0.4), wall * CFrame.new(x, y, -0.2), WHITE, M.Wood)
	part(f, V(2.6, 0.18, 0.4), wall * CFrame.new(x, y, -0.2), WHITE, M.Wood)
	if dressed then
		for _, sx in { -1, 1 } do
			part(f, V(0.8, 3.3, 0.25), wall * CFrame.new(x + sx * 2.05, y, -0.15), SHUTTER, M.WoodPlanks)
		end
		part(f, V(3.5, 0.7, 0.9), wall * CFrame.new(x, y - 2.2, -0.55), WOOD_DARK, M.Wood)
		for k = -1, 1 do
			ball(f, (wall * CFrame.new(x + k, y - 1.7, -0.6)).Position, 0.75, BLOOM[k + 2], M.SmoothPlastic)
		end
	end
	return pane
end

-- A log cabin that grows wider and taller with each level, and gains a porch, lit windows with
-- shutters and a door lantern (1), a chimney with smoke, a dormer and hedges (2), side wings, a
-- gold paw emblem and more windows (3), a third dormer and a flag (4). `b`: its middle on the
-- ground, facing -z.
local function house(f: Instance, b: CFrame, level: number): Part
	local w, d, h = 14 + 5 * level, 10 + 2 * level, 7 + level
	local rise = 4 + level
	local lit = level >= 1
	part(f, V(w + 1.6, 1, d + 1.6), b * CFrame.new(0, 0.5, 0), STONE, M.Cobblestone)
	part(f, V(w, h, d), b * CFrame.new(0, 1 + h / 2, 0), LOG, M.WoodPlanks)
	for _, y in { 1.3, h + 0.7 } do -- log bands round the foot and the top of the walls
		part(f, V(w + 0.5, 0.6, d + 0.5), b * CFrame.new(0, y, 0), WOOD_DARK, M.Wood)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(f, V(1.2, h, 1.2), b * CFrame.new(sx * w / 2, 1 + h / 2, sz * d / 2), WOOD_DARK, M.Wood)
		end
	end
	local top = b * CFrame.new(0, 1 + h, 0)
	roof(f, top, w, d, rise, LOG)
	part(f, V(w + 2.6, 0.5, 1.2), top * CFrame.new(0, rise, 0), INK, M.Slate) -- ridge cap
	for _, sz in { -1, 1 } do
		part(f, V(w + 2.2, 0.5, 0.5), top * CFrame.new(0, 0.1, sz * (d / 2 + 0.9)), WOOD_DARK, M.Wood) -- eave boards
	end
	local front = b * CFrame.new(0, 0, -d / 2)
	part(f, V(4.2, 6.6, 0.4), front * CFrame.new(0, 4.3, -0.05), WHITE, M.Wood)
	local door = part(f, V(3.4, 6, 0.5), front * CFrame.new(0, 4, -0.15), WOOD_DARK, M.WoodPlanks)
	part(f, V(0.4, 0.4, 0.3), front * CFrame.new(1.1, 3.8, -0.5), GOLD, M.Metal)
	for _, sx in { -1, 1 } do
		for k, x in if level == 0 then { 4.6 } elseif level >= 3 then { 6.2, 11.6 } else { 6.2 } do
			local pane = window(f, front, sx * x, lit, lit)
			if lit and k == 1 then
				glow(pane, WARM, 14, 0.8)
			end
		end
	end
	if level == 0 then
		part(f, V(4.4, 0.5, 1.6), front * CFrame.new(0, 0.5, -0.9), STONE, M.Slate) -- a doorstep
	else -- a porch with steps, posts, rails and its own roof, and a lantern by the door
		part(f, V(8.4, 0.6, 5), front * CFrame.new(0, 0.7, -2.6), WOOD, M.WoodPlanks)
		for k = 1, 2 do
			part(f, V(5, 0.35, 1.2), front * CFrame.new(0, 0.85 - 0.33 * k, -4.6 - 1.1 * k), WOOD, M.WoodPlanks)
		end
		for _, sx in { -1, 1 } do
			local post = front * CFrame.new(sx * 3.7, 0, -4.7)
			part(f, V(0.7, 6.4, 0.7), post * CFrame.new(0, 4.2, 0), WOOD_DARK, M.Wood)
			for _, y in { 2.2, 3.4 } do
				bar(
					f,
					(post * CFrame.new(0, y, 0)).Position,
					(post * CFrame.new(0, y, 4.5)).Position,
					0.16,
					WOOD_DARK,
					M.Wood
				)
				bar(
					f,
					(post * CFrame.new(0, y, 0)).Position,
					(post * CFrame.new(-sx * 1.1, y, 0)).Position,
					0.16,
					WOOD_DARK,
					M.Wood
				)
			end
		end
		part(f, V(9.6, 0.5, 5.8), front * CFrame.new(0, 7.6, -2.7) * CFrame.Angles(rad(-8), 0, 0), ROOF, M.Slate)
		local lamp = part(f, V(0.7, 1, 0.7), front * CFrame.new(-2.9, 5.6, -0.5), WARM, M.Neon)
		part(f, V(1, 0.25, 1), front * CFrame.new(-2.9, 6.2, -0.5), INK, M.Metal)
		glow(lamp, WARM, 12, 1)
	end
	if level >= 2 then -- chimney with smoke, dormers, hedges under the windows
		local tall = h + rise + 2.5
		local x = w / 2 - 3.5
		part(f, V(2.6, tall, 2.6), b * CFrame.new(x, 1 + tall / 2, d / 4), STONE, M.Cobblestone)
		local cap = part(f, V(3.2, 0.6, 3.2), b * CFrame.new(x, 1 + tall, d / 4), INK, M.Slate)
		emitter(cap, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(236, 236, 236)),
			Transparency = fade(0.55, 1),
			Size = fade(1.2, 4.2),
			Lifetime = NumberRange.new(3, 5),
			Rate = 3,
			Speed = NumberRange.new(2, 3),
			SpreadAngle = Vector2.new(12, 12),
			EmissionDirection = Enum.NormalId.Top,
		})
		for _, dx in if level == 2 then { 0 } elseif level == 3 then { -7.5, 7.5 } else { -10, 0, 10 } do
			local dormer = top * CFrame.new(dx, rise * 0.42, -(d / 4 + 0.8))
			part(f, V(3.4, 3, 3.6), dormer * CFrame.new(0, 0.3, 0), LOG, M.WoodPlanks)
			roof(f, dormer * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, rad(90), 0), 3.6, 3.4, 1.7, LOG)
			part(f, V(2, 1.9, 0.3), dormer * CFrame.new(0, 0.5, -1.85), WARM, M.Neon)
		end
		for _, sx in { -1, 1 } do
			local len = w / 2 - 4.8
			part(f, V(len, 1.8, 1.8), front * CFrame.new(sx * (4.8 + len / 2), 0.9, -2), HEDGE, M.Grass)
		end
	end
	if level >= 3 then -- wings, and a gold paw emblem over the porch
		for _, sx in { -1, 1 } do
			local wing = b * CFrame.new(sx * (w / 2 + 3.5), 0, 1)
			part(f, V(8, 1, d - 1.4), wing * CFrame.new(0, 0.5, 0), STONE, M.Cobblestone)
			part(f, V(7, h - 2.5, d - 3), wing * CFrame.new(0, 1 + (h - 2.5) / 2, 0), LOG, M.WoodPlanks)
			roof(f, wing * CFrame.new(0, h - 1.5, 0), 7, d - 3, 3, LOG)
			window(f, wing * CFrame.new(0, 0, -(d - 3) / 2), 0, true, false)
		end
		local face = front * CFrame.new(0, h - 0.6, -0.2) * CFrame.Angles(0, rad(90), 0)
		for _, dot in
			{
				{ 0, 0, 2.8, 0 },
				{ 0, -0.3, 1.1, 1 },
				{ -0.75, 0.45, 0.55, 1 },
				{ 0, 0.75, 0.55, 1 },
				{ 0.75, 0.45, 0.55, 1 },
			}
		do
			local piece = part(
				f,
				V(0.5 + dot[4] * 0.2, dot[3], dot[3]),
				face * CFrame.new(0, dot[2], dot[1]),
				if dot[4] == 0 then GOLD else INK,
				if dot[4] == 0 then M.Neon else M.SmoothPlastic
			)
			piece.Shape = Enum.PartType.Cylinder
		end
	end
	if level >= 4 then
		local foot = (front * CFrame.new(-(w / 2 + 2), 0, -7)).Position
		pillar(f, foot, 18, 0.25, WHITE, M.Metal)
		ball(f, foot + V(0, 18.2, 0), 0.8, GOLD, M.Metal)
		part(f, V(5, 3, 0.2), front * CFrame.new(-(w / 2 + 2) + 2.7, 16.2, -7), BANNER, M.SmoothPlastic)
	end
	return door
end

-- The Barn and its yard -----------------------------------------------------------------------------

-- Builds something at the origin with `build` and stands it at `where`, `scale` times as big.
local function scaled(f: Instance, scale: number, where: CFrame, build: (Instance) -> ())
	local m = Instance.new("Model")
	build(m)
	m.WorldPivot = CFrame.new()
	m:ScaleTo(scale)
	m:PivotTo(where)
	m.Parent = f
end

-- A lean-to with hay (0), then a red barn that grows with each level, with barrels and more hay
-- as it goes, a silo and a weather vane from level 2, a hay cart from 3, a second silo from 4
-- and a gold star at 5. A dirt track runs from the path to its doors.
local function barn(f: Instance, at: (number, number, number) -> CFrame, level: number)
	local where = at(38, 0, -28) * CFrame.Angles(0, rad(90), 0) -- its doors face the path
	local door = 38 * G - 9.4 -- how far the track runs from the path, in real studs
	part(f, V(door - 4.5, 0.5, 6), at((door + 4.5) / 2 / G, 0.27, -28), DIRT, M.Ground)
	if level == 0 then
		for _, sx in { -5, 5 } do
			part(f, V(0.8, 8, 0.8), where * CFrame.new(sx, 4, 3.5), WOOD_DARK, M.Wood)
			part(f, V(0.8, 6, 0.8), where * CFrame.new(sx, 3, -3.5), WOOD_DARK, M.Wood)
		end
		part(f, V(12.5, 0.5, 9), where * CFrame.new(0, 7.3, 0) * CFrame.Angles(rad(-15.5), 0, 0), ROOF, M.Slate)
		for k, o in { V(-2.5, 1.5, 1.5), V(1.8, 1.5, 2), V(-0.4, 4.5, 1.8) } do
			hay(f, where * CFrame.new(o) * CFrame.Angles(0, rad(k * 7), 0))
		end
	else
		local s = BARN_SCALE[level]
		scaled(f, s, where, function(m)
			kit.barn(m, CFrame.new())
		end)
		if level >= 2 then -- weather vane on the ridge
			local ridge = where * CFrame.new(0, 20 * s, 0)
			pillar(f, ridge.Position, 2.6, 0.12, INK, M.Metal)
			part(f, V(0.2, 0.3, 3), ridge * CFrame.new(0, 2.2, 0), INK, M.Metal)
			part(f, V(0.2, 1.1, 0.9), ridge * CFrame.new(0, 2.3, 1.3), GOLD, M.Metal)
		end
		for k, z in { -6, -50 } do
			if level >= 2 * k then
				scaled(f, 0.75 + 0.07 * level, at(51, 0, z), function(m)
					kit.silo(m, V(0, 0, 0))
				end)
			end
		end
		if level >= 5 then
			local star = ball(f, (where * CFrame.new(0, 21 * s, -8.4 * s)).Position, 2.6, GOLD, M.Neon)
			glow(star, GOLD, 18, 1.2)
		end
	end
	local stack = at(31, 0, -47.3) -- hay by the front fence
	for k, o in
		{ V(-6.2, 1.5, 0.3), V(-1.7, 1.5, -0.3), V(-4, 4.5, 0.1), V(2.8, 1.5, -0.1), V(7.2, 1.5, 0.3), V(5, 4.5, 0) }
	do
		if k <= level + 1 then
			hay(f, stack * CFrame.new(o) * CFrame.Angles(0, rad(k * 5), 0))
		end
	end
	local store = at(33, 0, -11) -- barrels behind the barn
	for k, o in { V(-2, 0, -1), V(0.6, 0, -0.2), V(-1, 0, 2), V(2.8, 0, -0.8) } do
		if k <= level then
			barrel(f, (store * CFrame.new(o)).Position)
		end
	end
	if level >= 3 then -- a hay cart
		local cart = at(38, 0, -6) * CFrame.Angles(0, rad(-12), 0)
		part(f, V(6.4, 0.5, 3.4), cart * CFrame.new(0, 2.2, 0), WOOD, M.WoodPlanks)
		for _, sz in { -1, 1 } do
			part(f, V(6.4, 1.3, 0.3), cart * CFrame.new(0, 3, sz * 1.6), WOOD, M.WoodPlanks)
			for _, x in { -1.8, 1.8 } do
				local wheel = part(
					f,
					V(0.4, 2.8, 2.8),
					cart * CFrame.new(x, 1.4, sz * 2) * CFrame.Angles(0, rad(90), 0),
					WOOD_DARK,
					M.Wood
				)
				wheel.Shape = Enum.PartType.Cylinder
			end
		end
		part(f, V(3.4, 0.3, 0.3), cart * CFrame.new(-4.8, 2.1, 0), WOOD_DARK, M.Wood)
		ball(f, (cart * CFrame.new(0, 3.5, 0)).Position, 3.4, HAY, M.Fabric)
	end
end

-- The training courts --------------------------------------------------------------------------------

-- What a stat's court trains with, from level 3.
local function gear(f: Instance, c: CFrame, stat: string, colour: Color3)
	if stat == "speed" then -- arrows down the lane and two hurdles
		for k = -1, 1 do
			for _, side in { -1, 1 } do
				local turn = CFrame.Angles(0, rad(side * 38), 0)
				part(f, V(0.7, 0.2, 3.2), c * CFrame.new(side * 1.1, 0.82, k * 3.4) * turn, colour, M.Neon)
			end
		end
		for _, z in { -1.7, 1.7 } do
			for _, sx in { -1, 1 } do
				part(f, V(0.3, 2.2, 0.3), c * CFrame.new(sx * 4.6, 1.8, z), WHITE, M.Metal)
			end
			part(f, V(9.5, 0.4, 0.3), c * CFrame.new(0, 2.8, z), colour, M.SmoothPlastic)
		end
	elseif stat == "strength" then -- a barbell on its stand, a weight stack, a kettlebell
		local a, b = (c * CFrame.new(-3.6, 2.6, 0)).Position, (c * CFrame.new(3.6, 2.6, 0)).Position
		bar(f, a, b, 0.22, Color3.fromRGB(200, 204, 212), M.Metal)
		for _, sx in { -1, 1 } do
			part(f, V(0.6, 2.4, 0.6), c * CFrame.new(sx * 1.6, 1.4, 0), INK, M.Metal)
			for k, d in { 3.4, 2.6 } do
				local plate = part(
					f,
					V(0.6, d, d),
					c * CFrame.new(sx * (2.5 + 0.7 * k), 2.6, 0),
					if k == 1 then INK else colour,
					M.Metal
				)
				plate.Shape = Enum.PartType.Cylinder
			end
		end
		for k = 0, 2 do
			part(
				f,
				V(2.6 - 0.4 * k, 0.6, 2.6 - 0.4 * k),
				c * CFrame.new(-4, 1 + 0.65 * k, -4),
				if k == 2 then colour else INK,
				M.Metal
			)
		end
		ball(f, (c * CFrame.new(4.2, 1.6, -4)).Position, 1.8, INK, M.Metal)
		part(f, V(1.2, 0.3, 0.3), c * CFrame.new(4.2, 2.7, -4), colour, M.Metal)
	elseif stat == "stamina" then -- a pool with a lane rope and a ladder
		disc(f, c.Position + V(0, 0.95, 0), 10.4, 0.5, STONE, M.Slate)
		disc(f, c.Position + V(0, 1, 0), 9, 0.3, colour:Lerp(WATER, 0.5), M.Glass)
		for k = -3, 3 do
			ball(
				f,
				(c * CFrame.new(k * 1.2, 1.15, 0)).Position,
				0.6,
				if k % 2 == 0 then WHITE else colour,
				M.SmoothPlastic
			)
		end
		for _, sx in { -1, 1 } do
			pillar(f, (c * CFrame.new(sx * 0.6, 0.9, 4.7)).Position, 2, 0.1, WHITE, M.Metal)
		end
	elseif stat == "mana" then -- a crystal on a pedestal in a ring of runes
		pillar(f, c.Position + V(0, 0.5, 0), 2, 1.2, STONE, M.Slate)
		local crystal =
			part(f, V(1.9, 3.6, 1.9), c * CFrame.new(0, 4.8, 0) * CFrame.Angles(rad(35), rad(45), 0), colour, M.Neon)
		glow(crystal, colour, 14, 1.4)
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2
			local rune = c * CFrame.new(math.cos(a) * 4.4, 0.8, math.sin(a) * 4.4) * CFrame.Angles(0, -a, 0)
			part(f, V(0.5, 0.2, 1.6), rune, colour, M.Neon)
			if k % 2 == 0 then
				part(
					f,
					V(0.6, 1.4, 0.6),
					rune * CFrame.new(0.9, 1.6 + (k % 4) * 0.4, 0) * CFrame.Angles(rad(30), rad(45), 0),
					colour,
					M.Neon
				)
			end
		end
	elseif stat == "health" then -- a two-tier spring
		disc(f, c.Position + V(0, 1.3, 0), 7.4, 0.8, STONE, M.Slate)
		disc(f, c.Position + V(0, 1.4, 0), 6.2, 0.3, WATER, M.Glass)
		pillar(f, c.Position + V(0, 1.3, 0), 1.8, 0.5, STONE, M.Slate)
		disc(f, c.Position + V(0, 3.4, 0), 3, 0.4, STONE, M.Slate)
		local jet = ball(f, c.Position + V(0, 4, 0), 1.3, colour, M.Neon)
		emitter(jet, {
			Color = ColorSequence.new(colour, WHITE),
			LightEmission = 0.6,
			Transparency = fade(0.2, 1),
			Size = fade(0.4, 0),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 12,
			Speed = NumberRange.new(4, 6),
			SpreadAngle = Vector2.new(28, 28),
			Acceleration = V(0, -14, 0),
			EmissionDirection = Enum.NormalId.Top,
		})
	else -- defence: a training dummy with a shield, and a rack of shields
		pillar(f, c.Position + V(0, 0.5, 0), 5, 0.4, WOOD_DARK, M.Wood)
		part(f, V(4.4, 0.6, 0.6), c * CFrame.new(0, 4, 0), WOOD_DARK, M.Wood)
		part(f, V(3, 3.4, 0.7), c * CFrame.new(0, 3.2, -0.7), colour, M.Metal)
		ball(f, c.Position + V(0, 6, 0), 1.7, HAY, M.Fabric)
		part(f, V(6, 0.4, 0.4), c * CFrame.new(0, 3, 4.6), WOOD_DARK, M.Wood)
		for k = -1, 1 do
			part(f, V(0.4, 3, 0.4), c * CFrame.new(k * 2.8, 2, 4.6), WOOD_DARK, M.Wood)
			if k ~= 0 then
				part(
					f,
					V(1.8, 2.2, 0.4),
					c * CFrame.new(k * 1.4, 2.4, 4.3) * CFrame.Angles(rad(-12), 0, 0),
					colour,
					M.Metal
				)
			end
		end
	end
end

-- One training court. Level 0 is a bare pad with a marker; then a floor with a border and a
-- sign (1), glowing edges and corner pylons (2), the stat's own gear (3), lights and sparkles
-- (4), a beam of light with a ring round it (5).
local function court(f: Instance, i: number, c: CFrame, st: StationConfig.Station, level: number)
	local colour = STAT_COLOUR[st.stat]
	local size = if level >= 2 then 14 else 12
	local pad: Part
	if level == 0 then
		pad = disc(f, c.Position + V(0, 0.6, 0), 8, 0.4, colour, M.SmoothPlastic)
		disc(f, c.Position + V(0, 0.5, 0), 9.4, 0.3, INK, M.SmoothPlastic)
		pillar(f, (c * CFrame.new(0, 0, 5.4)).Position, 3.4, 0.25, WOOD_DARK, M.Wood)
		part(f, V(2.6, 1.3, 0.4), c * CFrame.new(0, 3.2, 5.4), colour, M.SmoothPlastic)
	else
		pad = part(f, V(size, 0.5, size), c * CFrame.new(0, 0.45, 0), COURT, M.SmoothPlastic)
		part(f, V(size - 3.4, 0.1, size - 3.4), c * CFrame.new(0, 0.72, 0), COURT:Lerp(colour, 0.22), M.SmoothPlastic)
		local edge = if level >= 2 then M.Neon else M.SmoothPlastic
		for _, s in { -1, 1 } do
			part(f, V(size, 0.3, 0.7), c * CFrame.new(0, 0.75, s * (size / 2 - 0.35)), colour, edge)
			part(f, V(0.7, 0.3, size), c * CFrame.new(s * (size / 2 - 0.35), 0.75, 0), colour, edge)
			if level >= 2 then
				part(f, V(size - 2.6, 0.12, 0.25), c * CFrame.new(0, 0.76, s * (size / 2 - 1.4)), WHITE, M.Neon)
				part(f, V(0.25, 0.12, size - 2.6), c * CFrame.new(s * (size / 2 - 1.4), 0.76, 0), WHITE, M.Neon)
			end
		end
		kit.signboard(f, c * CFrame.new(0, 0, size / 2 + 1.6), 13, st.name, colour:Lerp(INK, 0.25), 6 + level * 0.5)
	end
	pad.Name = st.id
	pad:SetAttribute("Ranch", i)
	pad:SetAttribute("Station", st.id)
	CollectionService:AddTag(pad, "TrainPad")
	if level >= 2 then
		local tall = 2.5 + level * 0.6
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = c * CFrame.new(sx * (size / 2 - 0.1), 0, sz * (size / 2 - 0.1))
				part(f, V(1.2, tall, 1.2), corner * CFrame.new(0, 0.5 + tall / 2, 0), INK, M.Metal)
				part(f, V(1.35, 0.3, 1.35), corner * CFrame.new(0, 0.5 + tall * 0.55, 0), colour, M.Neon)
				local cap = part(f, V(1.4, 0.7, 1.4), corner * CFrame.new(0, 0.85 + tall, 0), colour, M.Neon)
				if level >= 4 then
					glow(cap, colour, 12, 1)
				end
			end
		end
	end
	if level >= 3 then
		gear(f, c, st.stat, colour)
	end
	if level >= 4 then
		emitter(pad, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(colour),
			LightEmission = 0.8,
			Transparency = fade(0, 1),
			Size = fade(0.5, 0),
			Lifetime = NumberRange.new(1.5, 2.5),
			Rate = 5,
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Top,
		})
	end
	if level >= 5 then
		local beam = part(f, V(26, 1.5, 1.5), c * CFrame.new(0, 13.8, 0) * CFrame.Angles(0, 0, rad(90)), colour, M.Neon)
		beam.Shape = Enum.PartType.Cylinder
		beam.Transparency, beam.CanCollide, beam.CastShadow = 0.78, false, false
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			local link = part(
				f,
				V(1.7, 0.3, 0.3),
				c * CFrame.new(math.cos(a) * 2.6, 10, math.sin(a) * 2.6) * CFrame.Angles(0, -a + rad(90), 0),
				colour,
				M.Neon
			)
			link.CanCollide = false
		end
	end
end

-- The rest ---------------------------------------------------------------------------------------------

local function fountain(f: Instance, centre: Vector3)
	disc(f, centre + V(0, 1.5, 0), 8, 1, STONE, M.Cobblestone)
	disc(f, centre + V(0, 1.6, 0), 6.8, 0.3, WATER, M.Glass)
	pillar(f, centre + V(0, 1.4, 0), 2.6, 0.6, STONE, M.Slate)
	disc(f, centre + V(0, 4.4, 0), 3.6, 0.5, STONE, M.Slate)
	disc(f, centre + V(0, 4.5, 0), 2.8, 0.2, WATER, M.Glass)
	local jet = ball(f, centre + V(0, 5.1, 0), 0.9, WATER, M.Neon)
	emitter(jet, {
		Color = ColorSequence.new(WATER, WHITE),
		LightEmission = 0.5,
		Transparency = fade(0.2, 1),
		Size = fade(0.4, 0),
		Lifetime = NumberRange.new(0.9, 1.3),
		Rate = 16,
		Speed = NumberRange.new(5, 7),
		SpreadAngle = Vector2.new(24, 24),
		Acceleration = V(0, -16, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
end

local function well(f: Instance, where: CFrame)
	disc(f, where.Position + V(0, 2.2, 0), 5, 2.2, STONE, M.Cobblestone)
	disc(f, where.Position + V(0, 2.3, 0), 3.8, 0.3, INK, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		part(f, V(0.5, 5, 0.5), where * CFrame.new(sx * 2.2, 4.4, 0), WOOD_DARK, M.Wood)
	end
	roof(f, where * CFrame.new(0, 6.9, 0), 4.6, 3.4, 1.8, nil)
	part(f, V(4.6, 0.3, 0.3), where * CFrame.new(0, 5.6, 0), WOOD_DARK, M.Wood)
	pillar(f, (where * CFrame.new(0, 3.6, 0)).Position, 1.2, 0.5, WOOD, M.WoodPlanks)
end

local function pavilion(f: Instance, b: CFrame)
	part(f, V(18, 0.5, 10), b * CFrame.new(0, 0.55, 0), WOOD, M.WoodPlanks)
	for _, x in { -8, 0, 8 } do
		for _, z in { -4.2, 4.2 } do
			part(f, V(0.8, 7, 0.8), b * CFrame.new(x, 4.3, z), WOOD_DARK, M.Wood)
		end
		part(f, V(3.6, 0.9, 6), b * CFrame.new(x * 0.68, 1.25, 0), HAY, M.Fabric)
		part(f, V(3, 0.5, 1.4), b * CFrame.new(x * 0.68, 1.9, 2), WHITE, M.Fabric)
	end
	roof(f, b * CFrame.new(0, 7.8, 0), 18, 10, 3.2, nil)
	for _, x in { -8, 8 } do
		local light = part(f, V(0.8, 1, 0.8), b * CFrame.new(x, 6.4, -4.9), WARM, M.Neon)
		glow(light, WARM, 12, 1)
	end
	kit.signboard(f, b * CFrame.new(0, 0, -6.2), 11, "Rest Area", Color3.fromRGB(150, 110, 80), 5)
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

-- Where the six eggs sit in the hatchery, from its middle.
local NESTS = { V(-5, 0, -2.4), V(0, 0, -2.4), V(5, 0, -2.4), V(-5, 0, 2.4), V(0, 0, 2.4), V(5, 0, 2.4) }

local function hatcheryFrame(i: number): CFrame
	return World.ranchFrame(i) * CFrame.new(21 * G, 0, -3 * G)
end

-- The hatchery: six straw nests on a stone floor under an open roof. Bought eggs wait here until
-- they open (Ranch.eggs shows them). The floor is tagged "RanchNest".
local function hatchery(f: Instance, i: number)
	local b = hatcheryFrame(i)
	local floor = part(f, V(17, 0.6, 11), b * CFrame.new(0, 0.5, 0), STONE, M.Cobblestone)
	floor.Name = "Nest"
	floor:SetAttribute("Ranch", i)
	CollectionService:AddTag(floor, "RanchNest")
	for _, n in NESTS do
		local c = (b * CFrame.new(n)).Position
		disc(f, c + V(0, 1.3, 0), 3.6, 0.5, HAY, M.Fabric)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			ball(f, c + V(math.cos(a) * 1.7, 1.3, math.sin(a) * 1.7), 1, HAY:Lerp(WOOD, 0.25), M.Fabric)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(f, V(0.8, 8, 0.8), b * CFrame.new(sx * 8, 4.8, sz * 5), WOOD_DARK, M.Wood)
		end
		local light = part(f, V(0.8, 1, 0.8), b * CFrame.new(sx * 4, 7.6, 0), WARM, M.Neon)
		glow(light, WARM, 14, 1)
	end
	roof(f, b * CFrame.new(0, 8.8, 0), 17, 11, 3.4, nil)
	local board = part(f, V(8, 1.9, 0.4), b * CFrame.new(0, 7.7, -5.4), Color3.fromRGB(96, 150, 84), M.SmoothPlastic)
	Props.label(board, "Hatchery", WHITE, 0.4)
end

-- A windmill: a stone tower with a wooden cap and four sails that turn on a motor.
local function windmill(f: Instance, b: CFrame)
	pillar(f, b.Position, 15, 3.4, STONE, M.Cobblestone)
	pillar(f, b.Position + V(0, 15, 0), 1, 3.8, WOOD_DARK, M.Wood)
	ball(f, b.Position + V(0, 16, 0), 7.4, ROOF, M.Slate)
	part(f, V(2.2, 4, 0.4), b * CFrame.new(0, 2.4, -3.3), WOOD_DARK, M.WoodPlanks)
	part(f, V(1.6, 1.6, 0.4), b * CFrame.new(0, 9, -3.3), WARM, M.Neon)
	local axle = part(f, V(1.2, 1.2, 2.6), b * CFrame.new(0, 14.4, -3.8), INK, M.Metal)
	local hub = part(f, V(1.7, 1.7, 0.8), b * CFrame.new(0, 14.4, -5.4), WOOD_DARK, M.Wood)
	hub.Anchored, hub.CanCollide = false, false
	for k = 0, 3 do
		local arm = hub.CFrame * CFrame.Angles(0, 0, k * math.pi / 2)
		for _, piece in
			{
				part(f, V(0.35, 11, 0.4), arm * CFrame.new(0, 5.6, 0), WOOD_DARK, M.Wood),
				part(f, V(2, 8.4, 0.2), arm * CFrame.new(0.9, 6.6, 0), Color3.fromRGB(246, 240, 224), M.SmoothPlastic),
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
	a0.CFrame = CFrame.new(0, 0, -1.6) * CFrame.Angles(0, rad(-90), 0)
	a1.CFrame = CFrame.Angles(0, rad(-90), 0)
	a0.Parent, a1.Parent = axle, hub
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0, hinge.Attachment1 = a0, a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity, hinge.MotorMaxTorque = 0.8, math.huge
	hinge.Parent = axle
end

-- The egg storage: a rack beside the hatchery, facing it. The first twelve stored eggs show on it.
local function rackFrame(i: number): CFrame
	return hatcheryFrame(i) * CFrame.new(11.8, 0, 0) * CFrame.Angles(0, rad(90), 0)
end

local function rackSpot(k: number): CFrame -- from the rack's frame: three shelves of four
	return CFrame.new(-3.75 + ((k - 1) % 4) * 2.5, 1.5 + ((k - 1) // 4) * 2.3, 0)
end

local function eggRack(f: Instance, i: number)
	local b = rackFrame(i)
	part(f, V(10.6, 7.6, 0.4), b * CFrame.new(0, 4.2, 1), WOOD_DARK, M.WoodPlanks)
	for _, y in { 1.2, 3.5, 5.8, 8 } do
		part(f, V(10.6, 0.4, 2.4), b * CFrame.new(0, y, 0), WOOD, M.WoodPlanks)
	end
	for _, x in { -5.3, 5.3 } do
		part(f, V(0.5, 8.2, 2.4), b * CFrame.new(x, 4.1, 0), WOOD_DARK, M.Wood)
	end
	local board = part(f, V(8, 1.6, 0.3), b * CFrame.new(0, 9.2, 0), Color3.fromRGB(150, 110, 80), M.SmoothPlastic)
	Props.label(board, "Egg Storage", WHITE, 0.3)
	local shelf = part(f, V(10, 0.4, 2), b * CFrame.new(0, 3.5, 0), WOOD, M.WoodPlanks) -- carries the prompt
	prompt(shelf, "EggStorage", "Choose an egg to hatch", "Egg storage", i)
end

-- Where the `n`th hatching egg stands in ranch `i`'s hatchery (facing out of it), and an egg type's
-- two colours: for the hatching animation.
function Ranch.nest(i: number, n: number): CFrame
	return hatcheryFrame(i) * CFrame.new(NESTS[math.clamp(n, 1, #NESTS)] + V(0, 1.3, 0))
end

function Ranch.look(kind: string): { body: Color3, spot: Color3 }
	return kit.eggLook[kind] or kit.eggLook.meadow
end

-- Show ranch `i`'s eggs: `eggs` is the profile's list, oldest first. Hatching eggs sit in the
-- hatchery's nests, each with a prompt tagged "Egg" (attributes Ranch, Index = its place in the
-- list, Due = when it can be opened); the client changes the prompt's words and turns the sparkles
-- on when the egg is ready (the prompt itself stays on: the server would refuse one it thinks is off). Stored eggs sit on the rack.
function Ranch.eggs(i: number, eggs: { { egg: string, since: number? } })
	local plot = World.root():FindFirstChild(`Ranch{i}`, true)
	if plot == nil then
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
			if NESTS[nest] then
				local shell = kit.eggModel(f, Ranch.nest(i, nest), 3, e.egg, rng)
				glow(shell, WARM, 8, 0.5)
				local open = prompt(shell, "Egg", "Hatching", egg.name, i)
				open:SetAttribute("Index", k)
				open:SetAttribute("Due", e.since + egg.hatch)
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
		elseif look then
			shelf += 1
			if shelf <= 12 then
				kit.eggModel(f, rackFrame(i) * rackSpot(shelf), 1.5, e.egg, rng) -- with its crown it still fits a shelf
			end
		end
	end
	f.Parent = plot
end

-- Build ranch `i` for these upgrade levels (missing = 0), replacing what stood there.
function Ranch.render(i: number, levels: { [string]: number })
	local plot = World.root():FindFirstChild(`Ranch{i}`, true)
	if plot == nil then
		return
	end
	local old = plot:FindFirstChild("Built")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Built"
	local cf = World.ranchFrame(i)
	local rng = Random.new(40 + i)
	local houseLevel, barnLevel, grounds = levels.house or 0, levels.barn or 0, levels.grounds or 0
	local total = houseLevel + barnLevel + grounds
	-- layout coordinates to the world: a CFrame, a point on the ground, a CFrame turned round
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x * G, y, z * G)
	end
	local function spot(x: number, z: number): Vector3
		return (cf * CFrame.new(x * G, 0, z * G)).Position
	end
	local function turned(x: number, z: number, degrees: number): CFrame
		return cf * CFrame.new(x * G, 0, z * G) * CFrame.Angles(0, rad(degrees), 0)
	end

	-- round the outside of the fence, the same at every level: pines, bushes and rocks, clear of
	-- the way in and of World's own trees (real plot coordinates)
	local wild = Random.new(900 + i)
	for k = 1, 60 do
		local a, r = wild:NextNumber(0, math.pi * 2), wild:NextNumber(H + 7, H + 34)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local near = math.abs(x) < 40 and z < 0 -- the gate, the mailbox and the flower beds
		if math.max(math.abs(x), math.abs(z)) > H + 5 and not near and math.abs(math.abs(x) - (H + 13)) > 7 then
			local where = (cf * CFrame.new(x, 0, z)).Position
			if k % 3 == 0 then
				pine(f, where, wild:NextNumber(1, 1.5), wild)
			elseif k % 3 == 1 then
				bush(f, where, wild:NextNumber(0.9, 1.4), wild)
			else
				rock(f, where, wild:NextNumber(2, 4), wild)
			end
		end
	end

	-- paths: from outside the gate to a plaza before the house, and across in front of the
	-- courts. Dirt at first, then paved. Real plot coordinates, so a path keeps its width.
	local plaza, cross = 25.5 * G, 11 * G
	local function way(x0: number, x1: number, z0: number, z1: number)
		local where = cf * CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
		if total >= PAVED then
			paved(f, where, x1 - x0, z1 - z0, rng)
		else
			part(f, V(x1 - x0, 0.5, z1 - z0), where * CFrame.new(0, 0.3, 0), DIRT, M.Ground)
		end
	end
	way(-4.5, 4.5, -H - 22, plaza - 7.4)
	way(-H + 4, -4.5, cross - 2.5, cross + 2.5)
	way(4.5, H - 4, cross - 2.5, cross + 2.5)
	if total >= PAVED then
		disc(f, spot(0, 25.5) + V(0, 0.45, 0), 15.6, 0.4, STONE, M.Slate)
		disc(f, spot(0, 25.5) + V(0, 0.57, 0), 14.4, 0.3, PATH, M.Cobblestone)
		disc(f, spot(0, 25.5) + V(0, 0.6, 0), 9, 0.1, PATH:Lerp(STONE, 0.4), M.Slate)
	else
		disc(f, spot(0, 25.5) + V(0, 0.55, 0), 15, 0.5, DIRT, M.Ground)
	end

	-- the roaming area, left of the path: a fenced paddock with a way in from the path
	part(f, V(48 * G, 0.5, 59 * G), at(-32, 0.25, -24.5), PADDOCK, M.LeafyGrass)
	for _, run in
		{
			{ V(-56, 0, -54), V(-8, 0, -54) },
			{ V(-56, 0, -54), V(-56, 0, 5) },
			{ V(-56, 0, 5), V(-8, 0, 5) },
			{ V(-8, 0, -54), V(-8, 0, -30) },
			{ V(-8, 0, -20), V(-8, 0, 5) },
			{ V(16, 0, 6), V(58, 0, 6) }, -- and one along the back of the barn yard
		}
	do
		kit.fence(f, cf, run[1] * G, run[2] * G)
	end
	kit.signboard(f, turned(-8, -25, 90), 12.4, "Roaming Area", Color3.fromRGB(70, 150, 80), 7.5)
	part(f, V(3.4, 2.2, 9), at(-53, 1.1, -3), WOOD, M.Wood) -- water trough
	part(f, V(2.6, 0.3, 8.2), at(-53, 2.1, -3), WATER, M.Glass)
	local stack = at(-50.5, 0, -50.2)
	for k, o in { V(-2, 1.5, 0.2), V(2.1, 1.5, -0.4), V(0, 4.5, 0) } do
		hay(f, stack * CFrame.new(o) * CFrame.Angles(0, rad(k * 7), 0))
	end
	local shelter = at(-52, 0, -27) -- an open shelter against the side fence
	for _, z in { -4, 4 } do
		part(f, V(0.7, 6.4, 0.7), shelter * CFrame.new(2.4, 3.2, z), WOOD_DARK, M.Wood)
		part(f, V(0.7, 7.6, 0.7), shelter * CFrame.new(-2.4, 3.8, z), WOOD_DARK, M.Wood)
	end
	part(f, V(6.6, 0.5, 10), shelter * CFrame.new(0, 7.3, 0) * CFrame.Angles(0, 0, rad(-13)), ROOF, M.Slate)
	part(f, V(4.4, 0.3, 8), shelter * CFrame.new(0, 0.6, 0), HAY, M.Fabric)
	rock(f, spot(-13, -48), 3, rng)
	rock(f, spot(-30, -3), 2.4, rng)
	if total >= POND then
		pond(f, spot(-51, -13), 6, rng)
	end

	-- the barn side, right of the path: the barn and its yard, straw spots for the animals, the
	-- egg nest inside a ring of stones
	barn(f, at, barnLevel)
	local n = 0
	for _, z in { -43, -37, -19, -13 } do
		for _, x in { 17.5, 23.5 } do
			n += 1
			local straw = disc(f, spot(x, z) + V(0, 0.55, 0), 4.6, 0.3, HAY, M.Fabric)
			straw.Name = `Spot{n}`
			straw:SetAttribute("Ranch", i)
			straw:SetAttribute("Index", n)
			CollectionService:AddTag(straw, "RanchSpot")
		end
	end
	hatchery(f, i)
	eggRack(f, i)
	-- the vendors, by the path: eggs (one of each on the counter) and gear
	local wares = stall(f, turned(10, -44, 90), Color3.fromRGB(240, 170, 60), "Egg Vendor", "eggs", i)
	for k, e in StationConfig.EGGS do
		kit.eggModel(f, wares * CFrame.new((k - 2.5) * 2.4, 0, 0), 1.9, e.id, rng)
	end
	wares = stall(f, turned(10, -16, 90), Color3.fromRGB(90, 130, 200), "Gear Vendor", "gear", i)
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

	-- the training courts: a row across the middle, three each side of the path
	for k, st in StationConfig.STATIONS do
		local side = if k <= 3 then -1 else 1
		court(f, i, at(side * (17 + 16 * ((k - 1) % 3)), 0, 20), st, grounds)
	end

	prompt(house(f, at(0, 0, 49), houseLevel), "RanchMenu", "Open", "Ranch menu", i)

	-- growing things: more with every level, and what is there stays where it is
	for _, p in scatter(i, 44 + 8 * total, HARD, 0.8) do
		tuft(f, spot(p.X, p.Z), rng)
	end
	for k, p in scatter(100 + i, 3 + total // 2, TAKEN, 3) do
		if k % 2 == 0 then
			pine(f, spot(p.X, p.Z), rng:NextNumber(0.9, 1.25), rng)
		else
			kit.tree(f, spot(p.X, p.Z), rng, rng:NextNumber(0.75, 1))
		end
	end
	for _, p in scatter(200 + i, 4 + total, TAKEN, 1.5) do
		bush(f, spot(p.X, p.Z), rng:NextNumber(0.8, 1.2), rng)
	end
	for _, p in scatter(300 + i, 3 + total // 2, TAKEN, 1.5) do
		rock(f, spot(p.X, p.Z), rng:NextNumber(1.6, 3), rng)
	end
	for _, p in { V(-55, 0, 56), V(-55, 0, 33) } do -- always two big trees at the back
		pine(f, spot(p.X, p.Z), 1.3, rng)
	end

	-- the extras that come with the ranch's total level
	if total >= LANTERNS then
		for _, z in if total >= MORE_LANTERNS then { -48, -30, -12, 16 } else { -48, -12 } do
			lantern(f, spot(-6.6, z))
			lantern(f, spot(6.6, z))
		end
	end
	if total >= FLOWERS then
		for _, p in scatter(400 + i, 3 + total, TAKEN, 1) do
			kit.flowers(f, spot(p.X, p.Z), rng, 8, 2.2)
		end
		for _, x in { 34, 44, 54 } do
			kit.flowers(f, spot(x, 3), rng, 8, 2)
		end
	end
	if total >= POND then
		pond(f, spot(-39, 46), 15, rng)
	end
	if total >= BENCHES then
		bench(f, turned(-7.4, 31, 125))
		bench(f, turned(-9.4, 20.5, 60))
	end
	if total >= WINDMILL then
		windmill(f, at(53, 0, 44))
	end
	if total >= PAVILION then
		pavilion(f, at(39, 0, 46))
	end
	if total >= WELL then
		well(f, at(-19, 0, 34))
	end
	if total >= FOUNTAIN then
		fountain(f, spot(0, 25.5))
	end
	if total >= FLAGS then
		for _, sx in { -1, 1 } do
			pillar(f, spot(sx * 12, -57), 15, 0.22, WHITE, M.Metal)
			part(f, V(4.4, 2.6, 0.2), turned(sx * 12, -57, 0) * CFrame.new(2.4, 13.4, 0), BANNER, M.SmoothPlastic)
		end
		local emblem = ball(f, spot(0, -60) + V(0, 15.4, 0), 2.6, GOLD, M.Neon)
		glow(emblem, GOLD, 16, 1)
	end

	f.Parent = plot
end

return Ranch
