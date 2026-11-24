--!strict
-- The Legion's battlefield (decision 0108), where the wave fights happen: a trampled field under the
-- Legion's castle in the mountains, from SHANNON's picture. The castle on its rock shelf (a glowing gate,
-- towers with violet roofs, trident banners); mountains all round; a waterfall, a river with a bridge and
-- a ruined gateway; pine and oak forest; and on the field watchtowers, catapults, the Legion's tents,
-- ruined walls, stake barricades, braziers, banners, crystal rocks and the summoning circle the Legion
-- comes out of. Up to three players' teams stand on the ground at the near end (`SEATS`), each before
-- its own camp. Built once, from parts, with fixed seeds. Display only: nothing here decides anything.
-- An unseen part tagged "FieldStand" marks where the teams stand and one tagged "FieldGate" where the
-- enemies walk in from (WaveShow.luau). x is to the right and -z towards the castle. Behind the teams the
-- valley opens into the approach (`REACH` long): a road between peaks back to the hub's north edge, where
-- the field's ground stops (World.luau clears the hub's terrain to meet it).

local CollectionService = game:GetService("CollectionService")

local Battlefield = {}

-- Where each player's team stands, by how many fight: x and z from the stand, and its turn in degrees
-- (the side teams turn in towards the one crowd). A team is its animals LINE apart on its front line
-- and its Titan TITAN_BACK behind them.
Battlefield.SEATS = {
	{ { 0, 0, 0 } },
	{ { -36, -3, -8 }, { 36, -3, 8 } },
	{ { -66, -8, -15 }, { 0, 0, 0 }, { 66, -8, 15 } },
}
Battlefield.LINE, Battlefield.TITAN_BACK = 18, 34
Battlefield.CROWD_AT, Battlefield.ROW, Battlefield.FILE = 40, 14, 13 -- the crowd: its first row ahead of the stand, rows and files apart
Battlefield.REACH = 750 -- from the stand back to the end of the approach, where the hub begins
Battlefield.COLOURS = { Color3.fromRGB(255, 170, 30), Color3.fromRGB(70, 195, 85), Color3.fromRGB(70, 115, 245) }

-- Player `k`'s seat (of `players`) at `stand`: its front line's middle, looking at the crowd.
function Battlefield.seat(stand: CFrame, players: number, k: number): CFrame
	local seats = Battlefield.SEATS[math.clamp(players, 1, #Battlefield.SEATS)]
	local s = seats[math.clamp(k, 1, #seats)]
	return stand * CFrame.new(s[1], 0, s[2]) * CFrame.Angles(0, math.rad(s[3]), 0)
end

local rad = math.rad
local M = Enum.Material
local V = Vector3.new
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local C = {
	grass = rgb(86, 152, 58),
	grass2 = rgb(74, 136, 52),
	grass3 = rgb(112, 176, 66),
	stone = rgb(118, 114, 136),
	stoneD = rgb(90, 86, 110),
	stoneL = rgb(148, 144, 166),
	castle = rgb(78, 74, 98),
	castleD = rgb(58, 54, 76),
	castleL = rgb(102, 98, 124),
	wood = rgb(130, 86, 52),
	woodD = rgb(98, 62, 38),
	woodL = rgb(160, 112, 70),
	iron = rgb(52, 50, 62),
	purple = rgb(96, 50, 176),
	purpleD = rgb(64, 32, 124),
	violet = rgb(152, 108, 236),
	neon = rgb(112, 64, 255), -- bluer than it should look: a redder violet blooms to pink
	lilac = rgb(184, 156, 255),
	fire = rgb(255, 150, 40),
	fire2 = rgb(255, 216, 96),
	water = rgb(72, 176, 236),
	waterL = rgb(150, 220, 250),
	foam = rgb(236, 248, 255),
}
local PINE = { rgb(46, 120, 62), rgb(58, 140, 68), rgb(38, 104, 56) }
local OAK = { rgb(92, 172, 52), rgb(112, 192, 58), rgb(76, 152, 48) }
local STONES = { C.stone, C.stoneD, C.stoneL }

local W = CFrame.new() -- the field's frame, set by `build`
local rng = Random.new(11)

local function pick<T>(t: { T }): T
	return t[rng:NextInteger(1, #t)]
end
-- a spot on the field, turned `rot` degrees
local function at(x: number, z: number, rot: number?, y: number?): CFrame
	return W * CFrame.new(x, y or 0, z) * CFrame.Angles(0, rad(rot or 0), 0)
end
local function raw(
	class: string,
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?
): BasePart
	local p = (Instance.new(class) :: any) :: BasePart
	p.Anchored, p.CanCollide = true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = mat or M.SmoothPlastic
	p.Parent = parent
	return p
end
-- a box whose bottom middle is at (x, y, z) in cf's space
local function box(
	parent: Instance,
	cf: CFrame,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3,
	mat: Enum.Material?,
	turn: CFrame?
): BasePart
	local c = cf * CFrame.new(x, y + sy / 2, z)
	return raw("Part", parent, V(sx, sy, sz), if turn then c * turn else c, color, mat)
end
-- an upright disc, d across and h high, its bottom at y
local function disc(
	parent: Instance,
	cf: CFrame,
	x: number,
	y: number,
	z: number,
	d: number,
	h: number,
	color: Color3,
	mat: Enum.Material?
): BasePart
	local p = raw(
		"Part",
		parent,
		V(h, d, d),
		cf * CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, rad(90)),
		color,
		mat
	) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- a beam from a to b (points in cf's space), tx wide and ty high
local function beam(
	parent: Instance,
	cf: CFrame,
	a: Vector3,
	b: Vector3,
	tx: number,
	ty: number,
	color: Color3,
	mat: Enum.Material?
): BasePart
	local d = b - a
	local up = if math.abs(d.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	return raw(
		"Part",
		parent,
		V(tx, ty, d.Magnitude),
		cf * CFrame.lookAt((a + b) / 2, b, up),
		color,
		mat or M.WoodPlanks
	)
end
local function light(part: BasePart, color: Color3, range: number, bright: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, bright, false
	l.Parent = part
end
local function unlit(p: BasePart): BasePart
	p.CastShadow = false
	return p
end

-- the Legion's trident, lying in cf's XY plane, about 2.8 s tall
local function trident(parent: Instance, cf: CFrame, s: number)
	local function bit(x: number, y: number, sx: number, sy: number, a: number?)
		unlit(
			raw(
				"Part",
				parent,
				V(sx * s, sy * s, 0.2),
				cf * CFrame.new(x * s, y * s, 0) * CFrame.Angles(0, 0, rad(a or 0)),
				C.lilac,
				M.Neon
			)
		)
	end
	bit(0, -0.2, 0.24, 2.4)
	bit(0, 0.25, 1.5, 0.24)
	bit(-0.63, 0.7, 0.24, 0.9)
	bit(0.63, 0.7, 0.24, 0.9)
	bit(0, 1.15, 0.46, 0.46, 45)
	bit(-0.63, 1.25, 0.4, 0.4, 45)
	bit(0.63, 1.25, 0.4, 0.4, 45)
end

-- a banner on a pole, its cloth facing cf's +Z; `emblem` false for a plain one
local function banner(parent: Instance, cf: CFrame, h: number, w: number, color: Color3, trim: Color3, emblem: boolean)
	local ch = w * 1.55
	box(parent, cf, 0, 0, 0, 0.6, h, 0.6, C.woodD, M.WoodPlanks)
	box(parent, cf, 0, h - 1.2, 0, w + 1.2, 0.5, 0.5, C.woodD, M.WoodPlanks)
	box(parent, cf, 0, h - 1.2 - ch, 0.35, w, ch, 0.25, color)
	box(parent, cf, 0, h - 1.2 - w * 0.22, 0.42, w, w * 0.22, 0.25, trim)
	for _, sx in { -1, 1 } do
		box(parent, cf, sx * w * 0.32, h - 1.2 - ch - w * 0.3, 0.35, w * 0.36, w * 0.3, 0.25, color)
	end
	if emblem then
		trident(parent, cf * CFrame.new(0, h - 1.2 - ch * 0.52, 0.56), w * 0.27)
	end
end

local function brazier(parent: Instance, cf: CFrame, s: number, y: number)
	box(parent, cf, 0, y, 0, 2.2 * s, 2.6 * s, 2.2 * s, C.wood, M.WoodPlanks)
	box(parent, cf, 0, y + 2.6 * s, 0, 3.3 * s, 0.8 * s, 3.3 * s, C.iron)
	local f = unlit(box(parent, cf, 0, y + 3.4 * s, 0, 1.9 * s, 1.5 * s, 1.9 * s, C.fire, M.Neon))
	unlit(box(parent, cf, 0, y + 4.9 * s, 0, 1.1 * s, 1.2 * s, 1.1 * s, C.fire2, M.Neon, CFrame.Angles(0, rad(45), 0)))
	light(f, C.fire, 22 * s, 1.4)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 5 * s, 9, C.fire, C.fire2
	fire.Parent = f
end

local function crate(parent: Instance, cf: CFrame, x: number, z: number, s: number, y: number)
	box(
		parent,
		cf,
		x,
		y,
		z,
		s,
		s,
		s,
		pick({ C.wood, C.woodL }),
		M.WoodPlanks,
		CFrame.Angles(0, rad(rng:NextNumber(-25, 25)), 0)
	)
	box(parent, cf, x, y + s, z, s * 1.06, 0.3, s * 1.06, C.woodD, M.WoodPlanks)
end

local function pine(parent: Instance, cf: CFrame, s: number)
	local trunk = 5 * s
	box(parent, cf, 0, 0, 0, 1.8 * s, trunk + 2, 1.8 * s, C.woodD, M.WoodPlanks)
	local y, w = trunk, 11 * s
	for i = 1, 4 do
		local h = (4.6 - i * 0.4) * s
		box(
			parent,
			cf,
			0,
			y,
			0,
			w,
			h,
			w,
			PINE[(i % 3) + 1],
			nil,
			if i % 2 == 0 then CFrame.Angles(0, rad(45), 0) else nil
		)
		y += h * 0.82
		w *= 0.72
	end
	box(parent, cf, 0, y, 0, 1.6 * s, 2.6 * s, 1.6 * s, PINE[2])
end
local function oak(parent: Instance, cf: CFrame, s: number)
	box(parent, cf, 0, 0, 0, 2.6 * s, 9 * s, 2.6 * s, C.wood, M.WoodPlanks)
	box(parent, cf, 0, 7 * s, 0, 11 * s, 7 * s, 11 * s, OAK[1])
	box(parent, cf, 3.5 * s, 9.5 * s, 2.5 * s, 7 * s, 6 * s, 7 * s, OAK[2])
	box(parent, cf, -3.8 * s, 10.5 * s, -2 * s, 6.5 * s, 5 * s, 6.5 * s, OAK[3])
	box(parent, cf, 0.5 * s, 13 * s, -0.5 * s, 6 * s, 4 * s, 6 * s, OAK[2])
end

-- a boulder; with `crystal` a glowing shard grows out of it
local function rock(parent: Instance, cf: CFrame, s: number, crystal: boolean)
	box(parent, cf, 0, -0.5 * s, 0, 7 * s, 5.5 * s, 6 * s, C.stone, nil, CFrame.Angles(rad(8), rad(20), rad(-6)))
	box(
		parent,
		cf,
		3.6 * s,
		-0.4 * s,
		1.5 * s,
		4.6 * s,
		3.4 * s,
		4.4 * s,
		C.stoneD,
		nil,
		CFrame.Angles(rad(-6), rad(-30), rad(10))
	)
	box(
		parent,
		cf,
		-2.6 * s,
		-0.3 * s,
		2.6 * s,
		3.6 * s,
		2.6 * s,
		3.4 * s,
		C.stoneL,
		nil,
		CFrame.Angles(0, rad(35), rad(8))
	)
	if crystal then
		local shard = unlit(
			box(
				parent,
				cf,
				0.6 * s,
				3.2 * s,
				-0.4 * s,
				1.6 * s,
				6 * s,
				1.6 * s,
				C.neon,
				M.Neon,
				CFrame.Angles(rad(14), rad(30), rad(-12))
			)
		)
		unlit(
			box(
				parent,
				cf,
				-1.4 * s,
				3.4 * s,
				0.8 * s,
				1.1 * s,
				3.6 * s,
				1.1 * s,
				C.lilac,
				M.Neon,
				CFrame.Angles(rad(-18), 0, rad(20))
			)
		)
		light(shard, C.neon, 20 * s, 1.6)
	end
end

-- a ruined wall, n blocks long along cf's X, up to maxH blocks high; `rune` puts a trident on its tallest block
local function ruin(parent: Instance, cf: CFrame, n: number, maxH: number, rune: boolean)
	local tones = { C.stone, C.stone, C.stoneD, C.stoneL }
	local best, bestH = 1, 0
	for i = 1, n do
		local h = rng:NextInteger(1, maxH)
		if h > bestH then
			best, bestH = i, h
		end
		for j = 1, h do
			box(
				parent,
				cf,
				(i - (n + 1) / 2) * 4.4 + rng:NextNumber(-0.2, 0.2),
				(j - 1) * 3.2,
				rng:NextNumber(-0.35, 0.35),
				4.3,
				3.15,
				4.3,
				pick(tones)
			)
		end
	end
	for _ = 1, math.max(1, n // 3) do -- fallen blocks
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		box(
			parent,
			cf,
			rng:NextNumber(-n * 2.2, n * 2.2),
			-0.4,
			rng:NextNumber(4, 7) * side,
			3.4,
			2.6,
			3.4,
			pick(tones),
			nil,
			CFrame.Angles(rad(rng:NextNumber(-12, 12)), rad(rng:NextNumber(0, 90)), 0)
		)
	end
	if rune then
		local x = (best - (n + 1) / 2) * 4.4
		box(parent, cf, x, (bestH - 1) * 3.2, 0, 4.5, 3.3, 4.5, C.castleD)
		trident(parent, cf * CFrame.new(x, (bestH - 1) * 3.2 + 1.75, 2.36), 0.95)
	end
end

-- a line of n sharpened stakes leaning towards cf's +Z
local function barricade(parent: Instance, cf: CFrame, n: number)
	local half = n * 1.15
	for i = 1, n do
		local x = (i - (n + 1) / 2) * 2.3
		beam(parent, cf, V(x, 0, -1.8), V(x, 5.2, 1.2), 0.95, 0.95, C.wood)
		beam(parent, cf, V(x, 5.2, 1.2), V(x, 6.5, 1.95), 0.55, 0.55, C.woodL)
	end
	beam(parent, cf, V(-half - 0.6, 1.7, -0.5), V(half + 0.6, 1.7, -0.5), 0.7, 0.7, C.woodD)
	beam(parent, cf, V(-half - 0.6, 3.7, 0.65), V(half + 0.6, 3.7, 0.65), 0.7, 0.7, C.woodD)
	for _, sx in { -1, 1 } do
		beam(parent, cf, V(sx * half, 0, 3), V(sx * half, 4.2, -0.4), 0.8, 0.8, C.woodD)
	end
end

-- a tent, its ridge along cf's Z and its door towards +Z; `emblem` puts the trident on both slopes
local function tent(parent: Instance, cf: CFrame, s: number, color: Color3, trim: Color3, emblem: boolean)
	local w, h, len = 7 * s, 8 * s, 14 * s
	for _, sx in { -1, 1 } do
		-- a wedge's slope runs down towards its own -Z
		raw(
			"WedgePart",
			parent,
			V(len, h, w),
			cf * CFrame.new(sx * w / 2, h / 2, 0) * CFrame.Angles(0, rad(-90 * sx), 0),
			color
		)
		box(parent, cf, sx * (w - 0.3), 0, 0, 0.9, 0.9 * s, len + 0.6, trim)
		for _, sz in { -1, 1 } do -- the trim's stripe up the slope, at both ends
			beam(
				parent,
				cf,
				V(sx * w, 0.2, sz * len / 2),
				V(0, h + 0.1, sz * len / 2),
				0.7 * s,
				0.5,
				trim,
				M.SmoothPlastic
			)
		end
		if emblem then
			local slope = math.sqrt(w * w + h * h)
			local along, up = V(0, 0, -sx), V(-sx * w, h, 0) / slope
			local on = V(sx * w / 2, h / 2, 0) + V(sx * h, w, 0) / slope * 0.14
			trident(parent, cf * CFrame.fromMatrix(on, along, up), 1.5 * s)
		end
	end
	box(parent, cf, 0, h - 0.2, 0, 0.7, 0.7, len + 2, C.woodD, M.WoodPlanks)
	box(parent, cf, 0, 0, len / 2 + 0.05, w * 0.62, h * 0.62, 0.3, C.iron) -- the dark doorway
	box(parent, cf, 0, 0, -len / 2 - 0.05, 0.6, h, 0.6, C.woodD, M.WoodPlanks)
	box(parent, cf, 0, 0, len / 2 + 0.2, 0.6, h, 0.6, C.woodD, M.WoodPlanks)
end

-- a wooden watchtower; `canopy` gives it a purple roof, else a brazier burns on it
local function watchtower(parent: Instance, cf: CFrame, canopy: boolean)
	local H, r = 20, 4.5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			beam(parent, cf, V(sx * (r + 1.2), 0, sz * (r + 1.2)), V(sx * r, H, sz * r), 1.3, 1.3, C.wood)
			box(parent, cf, sx * (r + 1.7), H + 0.8, sz * (r + 1.7), 0.8, 3.2, 0.8, C.woodD, M.WoodPlanks)
		end
	end
	for level = 0, 1 do
		local y0, y1 = level * H / 2 + 0.6, (level + 1) * H / 2 - 0.4
		local a = r + 1.2 - level * 0.6
		for _, s in { -1, 1 } do
			beam(parent, cf, V(-a, y0, s * a), V(a, y1, s * a), 0.7, 0.7, C.woodD)
			beam(parent, cf, V(a, y0, s * a), V(-a, y1, s * a), 0.7, 0.7, C.woodD)
			beam(parent, cf, V(s * a, y0, -a), V(s * a, y1, a), 0.7, 0.7, C.woodD)
			beam(parent, cf, V(s * a, y0, a), V(s * a, y1, -a), 0.7, 0.7, C.woodD)
			beam(parent, cf, V(-a, y1, s * a), V(a, y1, s * a), 0.9, 0.9, C.wood)
			beam(parent, cf, V(s * a, y1, -a), V(s * a, y1, a), 0.9, 0.9, C.wood)
		end
	end
	local pw = r * 2 + 4.4
	box(parent, cf, 0, H, 0, pw, 0.8, pw, C.woodL, M.WoodPlanks)
	for _, s in { -1, 1 } do
		box(parent, cf, 0, H + 0.8, s * (pw / 2 - 0.3), pw, 1.7, 0.5, C.wood, M.WoodPlanks)
		box(parent, cf, s * (pw / 2 - 0.3), H + 0.8, 0, 0.5, 1.7, pw, C.wood, M.WoodPlanks)
		box(parent, cf, 0, H + 3.4, s * (pw / 2 - 0.3), pw, 0.5, 0.5, C.woodD, M.WoodPlanks)
		box(parent, cf, s * (pw / 2 - 0.3), H + 3.4, 0, 0.5, 0.5, pw, C.woodD, M.WoodPlanks)
	end
	if not canopy then
		brazier(parent, cf, 1.25, H + 0.8)
		return
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(parent, cf, sx * (r + 1.7), H + 4, sz * (r + 1.7), 0.7, 4.4, 0.7, C.woodD, M.WoodPlanks)
		end
	end
	box(parent, cf, 0, H + 8.2, 0, pw + 3, 1.2, pw + 3, C.purpleD)
	box(parent, cf, 0, H + 9.4, 0, pw - 1, 1.8, pw - 1, C.purple)
	box(parent, cf, 0, H + 11.2, 0, pw - 5.5, 1.8, pw - 5.5, C.violet)
	light(box(parent, cf, 0, H + 13, 0, 1.6, 2.6, 1.6, C.neon, M.Neon), C.neon, 26, 1.5)
	box(parent, cf, 0, H + 7.2, pw / 2 + 1.6, pw * 0.5, 1.1, 0.3, C.violet) -- the roof's scalloped front
end

-- a catapult, its arm cocked back towards cf's +Z (it throws towards -Z)
local function catapult(parent: Instance, cf: CFrame)
	for _, sx in { -1, 1 } do
		box(parent, cf, sx * 3.2, 2, 0, 1.3, 1.3, 15, C.wood, M.WoodPlanks)
		for _, sz in { -1, 1 } do
			local wheel = raw(
				"Part",
				parent,
				V(1.1, 4.6, 4.6),
				cf * CFrame.new(sx * 4.5, 2.3, sz * 5.2),
				C.woodD,
				M.WoodPlanks
			) :: Part
			wheel.Shape = Enum.PartType.Cylinder
			local hub = raw("Part", parent, V(1.3, 1.5, 1.5), cf * CFrame.new(sx * 4.5, 2.3, sz * 5.2), C.iron) :: Part
			hub.Shape = Enum.PartType.Cylinder
			beam(parent, cf, V(sx * 3.2, 3, sz * 4), V(sx * 3.2, 10, -1), 1.1, 1.1, C.wood)
		end
	end
	for _, z in { -6.5, 0, 6.5 } do
		box(parent, cf, 0, 2.1, z, 7.6, 1.1, 1.1, C.woodD, M.WoodPlanks)
	end
	box(parent, cf, 0, 9.6, -1, 8, 0.9, 0.9, C.iron)
	beam(parent, cf, V(0, 13.4, -5), V(0, 4.6, 9.5), 1.1, 1.1, C.woodL)
	box(parent, cf, 0, 3.6, 9.6, 3, 1.3, 3, C.woodD, M.WoodPlanks)
	local shot = raw("Part", parent, V(2.4, 2.4, 2.4), cf * CFrame.new(0, 6, 9.6), C.stoneD) :: Part
	shot.Shape = Enum.PartType.Ball
	box(parent, cf, 0, 11, -6.2, 3, 3.2, 2.6, C.iron)
end

-- a ruined stone gateway, its way through along cf's Z
local function arch(parent: Instance, cf: CFrame)
	local tones = { C.stone, C.stoneD, C.stoneL, C.stone }
	for _, sx in { -1, 1 } do
		for j = 0, 4 do
			box(parent, cf, sx * 9, j * 4.2, 0, 6.2 - (j % 2) * 0.4, 4.15, 6.2, pick(tones))
		end
		box(parent, cf, sx * 5.6, 16.8, 0, 3.4, 4.2, 6, pick(tones)) -- the corbel under the lintel
	end
	for i = -2, 2 do
		box(parent, cf, i * 4.9, 21, 0, 4.85, 4, 6.4, pick(tones))
	end
	box(parent, cf, -9.6, 25, 0, 5, 3.6, 6, C.stoneD)
	box(parent, cf, -4.4, 25, 0.2, 4.6, 2.6, 5.6, C.stone)
	box(parent, cf, 7.4, 25, 0, 4.4, 2.2, 6, C.stoneL)
	box(parent, cf, -9.6, 28.6, 0, 5.3, 0.5, 6.3, C.grass2)
	box(parent, cf, 7.4, 27.2, 0, 4.7, 0.5, 6.3, C.grass)
	box(parent, cf, 12.4, 0, 2, 0.6, 9, 3, C.grass2)
	box(parent, cf, 14, -0.4, 5, 3.6, 2.6, 3.6, C.stone, nil, CFrame.Angles(rad(10), rad(30), 0))
	box(parent, cf, -13.5, -0.4, -5, 3.2, 2.4, 3.2, C.stoneD, nil, CFrame.Angles(0, rad(50), rad(12)))
end

-- a peak of stacked slabs, each turned a little more: w across at its foot and h high
local function peak(parent: Instance, x: number, z: number, w: number, h: number, far: boolean)
	local c1 = if far then rgb(116, 108, 172) else rgb(92, 80, 138)
	local c2 = if far then rgb(170, 164, 222) else rgb(150, 138, 200)
	local n = 11
	local cx, cz, hh, turn = x, z, h / n, rng:NextNumber(0, 90)
	local dx, dz = rng:NextNumber(-0.03, 0.03) * w, rng:NextNumber(-0.03, 0.03) * w
	for i = 0, n - 1 do
		local t = i / n
		local ww = math.max(w * 0.05, w * (1 - t) ^ 1.45 * rng:NextNumber(0.9, 1.08))
		local color = if far and i >= n - 2 then rgb(232, 228, 250) else c1:Lerp(c2, t) -- the far ones are capped with snow
		local sunk = if i == 0 then 8 else 4
		box(
			parent,
			W,
			cx,
			i * hh - sunk,
			cz,
			ww,
			hh + sunk,
			ww * rng:NextNumber(0.8, 1),
			color,
			nil,
			CFrame.Angles(0, rad(turn), 0)
		)
		cx += dx
		cz += dz
		turn += rng:NextNumber(8, 20)
	end
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- the land: grass, the trampled field, the road down from the castle and the way to the bridge
local function ground(parent: Instance)
	local f = folder(parent, "Ground")
	-- the valley full width, and the approach no wider than the gap between the ranches' land (World.luau)
	local base = box(f, W, 0, -6, -365, 2200, 6, 1590, C.grass)
	base.Name = "Base"
	box(f, W, 0, -6, (430 + Battlefield.REACH + 2) / 2, 496, 6, Battlefield.REACH + 2 - 430, C.grass).Name = "Base"
	-- overlapping dirt patches, each a hair higher than the last so none flicker
	local y = 0.02
	local function patch(x: number, z: number, d: number, color: Color3)
		unlit(disc(f, W, x, y - 0.1, z, d, 0.12, color))
		y += 0.002
	end
	local function dirt(): Color3
		local k = rng:NextNumber(-5, 5)
		return rgb(150 + k, 108 + k, 70 + k)
	end
	for _ = 1, 110 do
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber())
		patch(math.cos(a) * r * 122, -62 + math.sin(a) * r * 138, rng:NextNumber(26, 58), dirt())
	end
	for z = -205, -150, 9 do
		patch(rng:NextNumber(-3, 3), z, rng:NextNumber(30, 36), dirt())
	end
	for x = -128, -100, 9 do
		patch(x, -40 + rng:NextNumber(-3, 3), rng:NextNumber(18, 24), dirt())
	end
	for _ = 1, 46 do -- islands of grass left standing in the dirt, with tufts
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber())
		local x, z = math.cos(a) * r * 118, -62 + math.sin(a) * r * 132
		if math.abs(x) > 20 or z > -140 then
			patch(x, z, rng:NextNumber(9, 22), pick({ C.grass, C.grass2, C.grass3 }))
			for _ = 1, 3 do
				unlit(
					box(
						f,
						W,
						x + rng:NextNumber(-5, 5),
						0,
						z + rng:NextNumber(-5, 5),
						0.7,
						rng:NextNumber(0.9, 1.8),
						0.7,
						C.grass3,
						nil,
						CFrame.Angles(0, rad(rng:NextNumber(0, 90)), 0)
					)
				)
			end
		end
	end
	for _ = 1, 50 do -- loose stones
		local s = rng:NextNumber(0.8, 2)
		box(
			f,
			W,
			rng:NextNumber(-125, 125),
			-0.2,
			rng:NextNumber(-195, 80),
			s * 1.3,
			s,
			s * 1.1,
			pick(STONES),
			nil,
			CFrame.Angles(0, rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-10, 10)))
		)
	end
	base.CanCollide = true
end

-- the castle on its rock shelf: its front edge is 205 studs up the field, and it lies towards -z from there
local function castle(parent: Instance)
	local f = folder(parent, "Castle")
	local cf = at(0, -205)
	local Y = 14 -- the shelf's top

	local function zdisc(
		x: number,
		y: number,
		z: number,
		d: number,
		t: number,
		color: Color3,
		mat: Enum.Material?
	): BasePart
		local p = box(f, cf, x, y - d / 2, z, t, d, d, color, mat, CFrame.Angles(0, rad(90), 0)) :: Part
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function crenelX(x1: number, x2: number, z: number, y: number, t: number)
		local n = math.max(2, math.floor((x2 - x1) / 5.2 + 0.5))
		for i = 0, n - 1 do
			box(f, cf, x1 + 1.3 + i * (x2 - x1 - 2.6) / (n - 1), y, z, 2.6, 3, t, C.castleL)
		end
	end
	local function crenelZ(z1: number, z2: number, x: number, y: number, t: number)
		local n = math.max(2, math.floor((z2 - z1) / 5.2 + 0.5))
		for i = 0, n - 1 do
			box(f, cf, x, y, z1 + 1.3 + i * (z2 - z1 - 2.6) / (n - 1), t, 3, 2.6, C.castleL)
		end
	end
	local function slit(x: number, y: number, z: number, warm: boolean, s: number)
		unlit(box(f, cf, x, y, z, 1.6 * s, 5 * s, 0.4, if warm then C.fire2 else C.neon, M.Neon))
	end
	local function tower(x: number, z: number, w: number, h: number, roof: boolean, lit: boolean, from: number?)
		local y0 = from or Y
		box(f, cf, x, y0, z, w, h, w, C.castle)
		box(f, cf, x, y0, z, w + 1.4, 5, w + 1.4, C.castleD)
		box(f, cf, x, y0 + h * 0.56, z, w + 0.8, 1.4, w + 0.8, C.castleL)
		box(f, cf, x, y0 + h, z, w + 4, 3, w + 4, C.castleL)
		local top, s = y0 + h + 3, w + 4
		crenelX(x - s / 2, x + s / 2, z + s / 2 - 0.7, top, 1.4)
		crenelX(x - s / 2, x + s / 2, z - s / 2 + 0.7, top, 1.4)
		crenelZ(z - s / 2, z + s / 2, x - s / 2 + 0.7, top, 1.4)
		crenelZ(z - s / 2, z + s / 2, x + s / 2 - 0.7, top, 1.4)
		slit(x, y0 + h * 0.7, z + w / 2 + 0.1, false, w / 18)
		slit(x, y0 + h * 0.33, z + w / 2 + 0.1, true, w / 18)
		if not roof then
			return
		end
		-- a stepped spire: five tiers and a glowing tip
		local t, third = w * 0.3, math.max(4, w - 7)
		box(f, cf, x, top, z, w + 1.6, t, w + 1.6, C.purpleD)
		box(f, cf, x, top + t, z, w - 2.4, t, w - 2.4, C.purple)
		box(f, cf, x, top + t * 2, z, third, t, third, C.violet)
		box(f, cf, x, top + t * 3, z, math.max(2.6, third * 0.62), t, math.max(2.6, third * 0.62), C.purple)
		box(f, cf, x, top + t * 4, z, math.max(1.8, third * 0.32), t, math.max(1.8, third * 0.32), C.violet)
		local tip = unlit(box(f, cf, x, top + t * 5, z, 1.1, t * 1.1, 1.1, C.neon, M.Neon))
		unlit(box(f, cf, x, top + t * 0.9, z + w / 2 + 0.9, w * 0.3, t * 0.5, 0.3, C.neon, M.Neon)) -- a lit dormer
		if lit then
			light(tip, C.neon, 46, 2)
		end
	end
	local function wallX(x1: number, x2: number, z: number, h: number, t: number)
		local mid, len = (x1 + x2) / 2, x2 - x1
		box(f, cf, mid, Y, z, len, h, t, C.castle)
		box(f, cf, mid, Y, z, len, 4, t + 0.9, C.castleD)
		box(f, cf, mid, Y + h, z, len, 1.6, t + 1.2, C.castleL)
		crenelX(x1, x2, z + t / 2 - 0.1, Y + h + 1.6, 1.4)
		for _ = 1, math.floor(len / 9) do -- bricks standing a little proud of the face
			box(
				f,
				cf,
				rng:NextNumber(x1 + 4, x2 - 4),
				Y + rng:NextNumber(5, h - 4),
				z + t / 2 - 0.12,
				rng:NextNumber(4, 7),
				2.4,
				0.4,
				pick({ C.castleL, C.castleD })
			)
		end
	end
	local function hang(x: number, top: number, z: number, w: number) -- a banner hung on a wall, facing +z
		local ch = w * 1.6
		box(f, cf, x, top, z + 0.3, w + 1.4, 0.7, 0.7, C.woodD, M.WoodPlanks)
		box(f, cf, x, top - ch, z + 0.25, w, ch, 0.3, C.purple)
		box(f, cf, x, top - w * 0.2, z + 0.32, w, w * 0.2, 0.3, C.violet)
		for _, sx in { -1, 1 } do
			box(f, cf, x + sx * w * 0.32, top - ch - w * 0.3, z + 0.25, w * 0.36, w * 0.3, 0.3, C.purple)
			box(f, cf, x + sx * (w / 2 - 0.25), top - ch, z + 0.3, 0.5, ch, 0.34, C.violet)
		end
		trident(f, cf * CFrame.new(x, top - ch * 0.52, z + 0.52), w * 0.27)
	end
	local function torch(x: number, y: number, z: number, lit: boolean)
		box(f, cf, x, y, z + 0.5, 0.9, 0.5, 1.4, C.iron)
		local flame = unlit(box(f, cf, x, y + 0.5, z + 1, 1.2, 1.9, 1.2, C.fire, M.Neon))
		if lit then
			light(flame, C.fire, 30, 1.6)
		end
	end

	-- the rock it stands on, its rough front, and the stairs up
	box(f, cf, 0, -2, -86, 340, Y + 2, 180, C.stoneD)
	for x = -164, 164, 12 do
		if math.abs(x) > 27 then
			box(
				f,
				cf,
				x + rng:NextNumber(-3, 3),
				-2,
				5 + rng:NextNumber(0, 6),
				rng:NextNumber(12, 19),
				rng:NextNumber(8, 16),
				rng:NextNumber(10, 17),
				pick({ C.stone, C.stoneD, C.castleL, C.stoneD }),
				nil,
				CFrame.Angles(0, rad(rng:NextNumber(-22, 22)), 0)
			)
			if rng:NextNumber() < 0.45 then
				box(
					f,
					cf,
					x + rng:NextNumber(-4, 4),
					-1,
					15 + rng:NextNumber(0, 5),
					rng:NextNumber(6, 10),
					rng:NextNumber(3, 7),
					rng:NextNumber(6, 9),
					pick({ C.stone, C.stoneL }),
					nil,
					CFrame.Angles(0, rad(rng:NextNumber(0, 60)), 0)
				)
			end
		end
	end
	for i = 1, 12 do
		box(f, cf, 0, 0, 27.6 - (i - 0.5) * 2.2, 42, i * Y / 12, 2.2, if i % 2 == 0 then C.stoneL else C.stone)
	end
	for _, sx in { -1, 1 } do
		for k = 1, 4 do
			box(f, cf, sx * 23, 0, 27.6 - (k - 0.5) * 6.6, 4, k * 3.5 + 2.4, 6.6, C.castleL)
		end
		box(f, cf, sx * 23, 0, 30.6, 5, 5, 5, C.castle)
		brazier(f, cf * CFrame.new(sx * 23, 5, 30.6), 1.2, 0)
	end

	-- the gatehouse and the gate
	box(f, cf, 0, Y, -26, 56, 54, 20, C.castle)
	box(f, cf, 0, Y, -26, 57, 4, 21, C.castleD)
	box(f, cf, 0, Y + 54, -26, 58, 1.8, 22, C.castleL)
	crenelX(-29, 29, -15.4, Y + 55.8, 1.4)
	box(f, cf, 0, Y, -15.6, 35, 25, 1.2, C.stoneL)
	zdisc(0, Y + 25, -15.6, 35, 1.2, C.stoneL)
	local glow = unlit(box(f, cf, 0, Y, -15.3, 28, 25, 1.2, C.neon, M.Neon))
	unlit(zdisc(0, Y + 25, -15.3, 28, 1.2, C.neon, M.Neon))
	light(glow, C.neon, 60, 3)
	for x = -12, 12, 4 do
		box(f, cf, x, Y, -14.5, 0.8, 25 + math.sqrt(196 - x * x), 0.6, C.castleD)
	end
	for _, y in { 7, 16, 25 } do
		box(f, cf, 0, Y + y, -14.5, 28, 0.8, 0.6, C.castleD)
	end
	trident(f, cf * CFrame.new(0, Y + 46.5, -15.85), 2.7)
	torch(-21, Y + 14, -16, true)
	torch(21, Y + 14, -16, true)
	tower(-37, -22, 18, 64, true, true)
	tower(37, -22, 18, 64, true, true)

	-- the curtain wall, its towers and banners
	wallX(-128, -46, -30, 36, 8)
	wallX(46, 128, -30, 36, 8)
	for _, sx in { -1, 1 } do
		tower(sx * 86, -28, 16, 48, false, false)
		brazier(f, cf * CFrame.new(sx * 86, Y + 51, -28), 1.7, 0)
		tower(sx * 136, -30, 26, 74, true, true)
		hang(sx * 62, Y + 33, -26, 9)
		hang(sx * 108, Y + 33, -26, 9)
		for _, x in { 50, 74, 98, 119 } do
			torch(sx * x, Y + 12, -26, false)
		end
		box(f, cf, sx * 136, Y, -90, 8, 30, 100, C.castle) -- the side wall, running back
		crenelZ(-140, -43, sx * 136, Y + 30, 8)
	end

	-- the keep, its turrets, its great banner, and the towers behind
	box(f, cf, 0, Y, -100, 84, 96, 60, C.castle)
	box(f, cf, 0, Y, -100, 85.4, 5, 61.4, C.castleD)
	box(f, cf, 0, Y + 40, -100, 85.2, 1.6, 61.2, C.castleL)
	box(f, cf, 0, Y + 96, -100, 88, 2.4, 64, C.castleL)
	crenelX(-44, 44, -68.7, Y + 98.4, 1.4)
	crenelZ(-132, -68, -43.3, Y + 98.4, 1.4)
	crenelZ(-132, -68, 43.3, Y + 98.4, 1.4)
	for _, x in { -26, -9, 9, 26 } do
		slit(x, Y + 62, -69.9, true, 1.5)
		slit(x, Y + 20, -69.9, x * x > 100, 1.5)
	end
	slit(-30, Y + 78, -69.9, false, 1.4)
	slit(30, Y + 78, -69.9, false, 1.4)
	hang(0, Y + 92, -70, 20)
	tower(-42, -70, 16, 112, true, true)
	tower(42, -70, 16, 112, true, true)
	tower(-42, -130, 16, 104, true, false)
	tower(42, -130, 16, 104, true, false)
	tower(0, -100, 28, 34, true, true, Y + 98)
	tower(-98, -100, 20, 92, true, true)
	tower(98, -100, 20, 92, true, true)
	tower(-150, -128, 22, 62, true, false)
	tower(150, -128, 22, 62, true, false)
	tower(-70, -150, 16, 76, true, false)
	tower(70, -150, 16, 76, true, false)
end

-- the river's middle line, from the pool under the fall down the field's left side
local RIVER = {
	V(-178, 0.2, -158),
	V(-170, 0.2, -110),
	V(-156, 0.2, -60),
	V(-160, 0.2, -10),
	V(-150, 0.2, 50),
	V(-166, 0.2, 120),
	V(-150, 0.2, 200),
	V(-172, 0.2, 320),
}

-- the mountains all round, and the cliff the waterfall drops from
local function mountains(parent: Instance)
	local f = folder(parent, "Mountains")
	for _, m in
		{
			{ 0, -480, 300, 430, 1 },
			{ -175, -440, 260, 330, 0 },
			{ 185, -450, 280, 360, 0 },
			{ -60, -620, 400, 540, 1 },
			{ 150, -640, 420, 500, 1 },
			{ -340, -530, 340, 410, 1 },
			{ 360, -540, 340, 430, 1 },
			{ -278, -330, 200, 230, 0 },
			{ 282, -338, 210, 250, 0 },
			{ -470, -210, 300, 310, 0 },
			{ -530, 40, 330, 350, 1 },
			{ -480, 280, 300, 260, 0 },
			{ 470, -220, 300, 330, 0 },
			{ 530, 30, 330, 310, 1 },
			{ 480, 280, 300, 280, 0 },
			{ -390, -80, 180, 170, 0 },
			{ 395, -90, 190, 180, 0 },
			{ -400, 150, 170, 150, 0 },
			{ 400, 160, 180, 160, 0 },
			-- behind the teams, either side of the approach
			{ -300, 470, 320, 300, 0 },
			{ 310, 480, 320, 320, 0 },
			{ -250, 590, 230, 260, 0 },
			{ 255, 610, 240, 250, 0 },
			{ -235, 700, 200, 200, 0 },
			{ 240, 710, 200, 210, 0 },
		}
	do
		peak(f, m[1], m[2], m[3], m[4], m[5] == 1)
	end
	local cliff = rgb(106, 98, 136)
	box(f, W, -215, -2, -216, 150, 50, 92, cliff)
	box(f, W, -215, 48, -216, 151, 1.4, 93, C.grass2)
	box(f, W, -262, -2, -150, 96, 32, 62, rgb(96, 88, 126), nil, CFrame.Angles(0, rad(8), 0))
	box(f, W, -262, 30, -150, 97, 1.4, 63, C.grass, nil, CFrame.Angles(0, rad(8), 0))
	for _ = 1, 9 do -- broken rock at its foot
		box(
			f,
			W,
			rng:NextNumber(-285, -200),
			-2,
			rng:NextNumber(-172, -160),
			rng:NextNumber(10, 18),
			rng:NextNumber(6, 16),
			rng:NextNumber(9, 15),
			pick({ cliff, C.stoneD, C.stone }),
			nil,
			CFrame.Angles(0, rad(rng:NextNumber(-25, 25)), 0)
		)
	end
end

-- the waterfall, the river, the bridge over it and the ruined gateway on the field's side of the bridge
local function water(parent: Instance)
	local f = folder(parent, "Water")
	local dry = folder(parent, "Bridge") -- what can be walked on or bumped into
	for i = 1, #RIVER - 1 do
		local a, b = RIVER[i], RIVER[i + 1]
		local along = (b - a).Unit
		local side = along:Cross(Vector3.yAxis)
		unlit(beam(f, W, a, b, 24, 0.3, C.water, M.SmoothPlastic))
		unlit(disc(f, W, b.X, 0.05, b.Z, 24, 0.3, C.water))
		for _ = 1, 4 do -- ripples
			local from = a:Lerp(b, rng:NextNumber(0.05, 0.75)) + side * rng:NextNumber(-9, 9) + V(0, 0.12, 0)
			unlit(beam(f, W, from, from + along * rng:NextNumber(5, 11), 1.1, 0.3, C.waterL, M.SmoothPlastic))
		end
		for _, bank in { -1, 1 } do -- stones on the banks
			for _ = 1, 3 do
				local on = a:Lerp(b, rng:NextNumber()) + side * bank * rng:NextNumber(12.5, 15)
				box(
					dry,
					W,
					on.X,
					-0.4,
					on.Z,
					rng:NextNumber(2.4, 4.6),
					rng:NextNumber(1.6, 3),
					rng:NextNumber(2.4, 4.2),
					pick(STONES),
					nil,
					CFrame.Angles(0, rad(rng:NextNumber(0, 90)), 0)
				)
			end
		end
	end
	unlit(box(f, W, -178, 0, -169.4, 20, 49, 1.4, C.waterL))
	for _, x in { -184, -179, -173 } do
		unlit(box(f, W, x, 0, -168.6, 2.4, 49, 0.4, C.foam, M.Neon))
	end
	unlit(box(f, W, -178, 49.2, -192, 20, 0.5, 46, C.water))
	unlit(disc(f, W, -178, 0.08, -152, 50, 0.3, C.water))
	for _ = 1, 9 do
		unlit(
			box(
				f,
				W,
				rng:NextNumber(-190, -166),
				0.2,
				rng:NextNumber(-168, -160),
				rng:NextNumber(3, 6),
				rng:NextNumber(1.2, 3),
				rng:NextNumber(3, 5),
				C.foam
			)
		)
	end
	local bc = at(-158, -40)
	local pts: { Vector3 } = {}
	for i = 0, 8 do
		pts[i + 1] = V(-22 + i * 5.5, 0.5 + 5 * math.sin(math.pi * i / 8), 0)
	end
	for i = 1, 8 do
		beam(dry, bc, pts[i], pts[i + 1], 10, 0.8, if i % 2 == 0 then C.wood else C.woodL)
		for _, sz in { -1, 1 } do
			beam(dry, bc, pts[i] + V(0, 3.2, sz * 4.6), pts[i + 1] + V(0, 3.2, sz * 4.6), 0.6, 0.6, C.woodD)
		end
	end
	for _, p in pts do
		for _, sz in { -1, 1 } do
			box(dry, bc, p.X, p.Y, sz * 4.6, 0.8, 3.6, 0.8, C.woodD, M.WoodPlanks)
		end
	end
	for _, sx in { -1, 1 } do
		box(dry, bc, sx * 23.5, -0.5, 0, 5, 2.6, 12, C.stone)
	end
	arch(dry, at(-124, -40, 90))
end

-- pine and oak round the field: nothing in the river, on the field or in a camera's way
local function forest(parent: Instance)
	local f = folder(parent, "Forest")
	local function nearRiver(x: number, z: number): boolean
		for i = 1, #RIVER - 1 do
			local a, b = RIVER[i], RIVER[i + 1]
			local t = math.clamp((V(x, 0.2, z) - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
			if (a:Lerp(b, t) - V(x, 0.2, z)).Magnitude < 20 then
				return true
			end
		end
		return false
	end
	local function plant(n: number, x1: number, x2: number, z1: number, z2: number, y: number, cliffs: boolean)
		local placed: { Vector3 } = {}
		for _ = 1, n * 30 do
			if #placed >= n then
				break
			end
			local x, z = rng:NextNumber(x1, x2), rng:NextNumber(z1, z2)
			local ok = not nearRiver(x, z)
				and not (cliffs and x < -140 and z < -118) -- the waterfall's cliff and its shelf
				and not (z > 90 and math.abs(x) < 26) -- the road out
			for _, p in placed do
				ok = ok and (p - V(x, 0, z)).Magnitude >= 17
			end
			if ok then
				table.insert(placed, V(x, 0, z))
				local cf = at(x, z, rng:NextNumber(0, 90), y)
				if rng:NextNumber() < 0.74 then
					pine(f, cf, rng:NextNumber(1.5, 2.5))
				else
					oak(f, cf, rng:NextNumber(1.5, 2.2))
				end
				if rng:NextNumber() < 0.4 then -- a bush beside it
					box(f, cf, rng:NextNumber(6, 10), 0, rng:NextNumber(-6, 6), 4.6, 3.4, 4.6, pick(OAK))
				end
			end
		end
	end
	plant(62, -350, -184, -116, 280, 0, true)
	plant(74, 148, 350, -196, 280, 0, false)
	plant(9, -286, -196, -256, -182, 49.4, false) -- on the cliff
	plant(5, -300, -226, -172, -128, 31.4, false) -- and its shelf
	plant(14, -330, -180, -400, -264, 0, false)
	plant(16, 180, 330, -400, -210, 0, false)
	plant(22, -140, 140, 150, 280, 0, false)
	for _, t in
		{
			{ -134, 96, 2.2, 1 },
			{ -138, -92, 2.1, 0 },
			{ -132, -150, 2.3, 0 },
			{ -128, 128, 2, 0 },
			{ 138, 100, 2.2, 1 },
			{ 136, 132, 2.3, 0 },
			{ 142, -170, 2.2, 0 },
		}
	do
		local cf = at(t[1], t[2], rng:NextNumber(0, 90))
		if t[4] == 1 then
			oak(f, cf, t[3])
		else
			pine(f, cf, t[3])
		end
	end
	for _ = 1, 34 do -- bushes along the field's edges
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local s = rng:NextNumber(2.6, 4.6)
		box(
			f,
			W,
			side * rng:NextNumber(124, 138),
			0,
			rng:NextNumber(-190, 140),
			s * 1.2,
			s * 0.8,
			s * 1.1,
			pick(OAK),
			nil,
			CFrame.Angles(0, rad(rng:NextNumber(0, 90)), 0)
		)
	end
end

-- what stands on the field: the Legion's siege camp, ruins and barricades, and the summoning circle
local function camp(parent: Instance)
	local f = folder(parent, "Camp")
	for _, t in { { -112, -66, 0 }, { 136, -32, 0 }, { 114, -74, 1 }, { -66, -166, 1 }, { 70, -168, 0 } } do
		watchtower(f, at(t[1], t[2], rng:NextNumber(-8, 8)), t[3] == 1)
	end
	for _, t in { { -88, -122, 170 }, { 94, -128, 195 }, { -36, -176, 184 } } do
		catapult(f, at(t[1], t[2], t[3]))
	end
	for _, t in { { 124, -148, -35 }, { 134, -108, -70 }, { -122, -128, 50 }, { 104, -186, -15 } } do
		tent(f, at(t[1], t[2], t[3]), 1.25, C.purple, C.violet, true)
	end
	for _, t in
		{
			{ -98, -20, 20, 6, 3, 0 },
			{ 100, -16, -25, 5, 3, 0 },
			{ -104, -94, 70, 5, 3, 1 },
			{ 108, -104, 100, 6, 3, 1 },
			{ -46, -144, 10, 4, 3, 1 },
			{ 48, -146, -8, 5, 3, 0 },
			{ -96, 78, 15, 4, 2, 0 },
			{ 98, 84, -10, 4, 2, 0 },
		}
	do
		ruin(f, at(t[1], t[2], t[3]), t[4], t[5], t[6] == 1)
	end
	for _, t in
		{
			{ -86, -46, 20, 7 },
			{ 86, -48, -20, 7 },
			{ -62, -116, 6, 6 },
			{ 64, -112, -8, 6 },
			{ -31, -194, 0, 5 },
			{ 31, -194, 0, 5 },
		}
	do
		barricade(f, at(t[1], t[2], t[3]), t[4])
	end
	for z = -200, -156, 7 do -- kerb stones down the road
		for _, sx in { -1, 1 } do
			box(
				f,
				W,
				sx * 19 + rng:NextNumber(-0.6, 0.6),
				-0.3,
				z + rng:NextNumber(-1, 1),
				3,
				rng:NextNumber(1.4, 2.2),
				3,
				pick(STONES),
				nil,
				CFrame.Angles(0, rad(rng:NextNumber(-15, 15)), 0)
			)
		end
	end
	for _, t in
		{
			{ -17, -168 },
			{ 17, -168 },
			{ -27, -103 },
			{ 27, -103 },
			{ -27, -151 },
			{ 27, -151 },
			{ -126, -14 },
			{ 128, -6 },
			{ 112, -134 },
			{ -106, -142 },
			{ -118, 92 },
			{ 122, 96 },
		}
	do
		brazier(f, at(t[1], t[2]), 1.15, 0)
	end
	for _, t in
		{
			{ -33, -127, 17, 5.5 },
			{ 33, -127, 17, 5.5 },
			{ 118, -124, 14, 4.5 },
			{ -112, -110, 14, 4.5 },
			{ -126, -172, 15, 5 },
			{ 128, -176, 15, 5 },
			{ -74, -64, 13, 4 },
			{ 78, -66, 13, 4 },
		}
	do
		banner(f, at(t[1], t[2], rng:NextNumber(-10, 10)), t[3], t[4], C.purple, C.violet, true)
	end
	for _, t in { { 114, -142 }, { 130, -118 }, { -80, -110 }, { -108, -134 }, { 60, -176 } } do
		local cf = at(t[1], t[2], rng:NextNumber(0, 90))
		crate(f, cf, 0, 0, 3.4, 0)
		crate(f, cf, 3.9, 0.6, 3, 0)
		crate(f, cf, 1.6, 0.4, 2.6, 3.7)
	end
	for _, t in
		{
			{ -136, -178, 1.7, 1 },
			{ 142, -62, 1.5, 1 },
			{ -134, 66, 1.4, 1 },
			{ 140, 112, 1.6, 1 },
			{ 62, -197, 1.2, 1 },
			{ -70, -199, 1.2, 1 },
			{ -130, -8, 1.2, 0 },
			{ 132, 14, 1.3, 0 },
			{ 136, -196, 1.6, 0 },
		}
	do
		rock(f, at(t[1], t[2], rng:NextNumber(0, 180)), t[3], t[4] == 1)
	end
	-- the summoning circle: the Legion walks out of it, and a boss lands on it
	local cc = at(0, -126)
	for _, r in
		{
			{ 56, 1, 0 },
			{ 50, 1.06, 1 },
			{ 45, 1.12, 2 },
			{ 34, 1.18, 1 },
			{ 30, 1.24, 0 },
			{ 14, 1.3, 1 },
			{ 10, 1.36, 2 },
		}
	do
		local ring = unlit(
			disc(
				f,
				cc,
				0,
				0,
				0,
				r[1],
				r[2],
				if r[3] == 1 then C.neon elseif r[3] == 2 then C.stoneD else C.stone,
				if r[3] == 1 then M.Neon else nil
			)
		)
		if r[1] == 34 then
			light(ring, C.neon, 60, 2.2)
		end
	end
	for i = 0, 11 do
		local a = i * math.pi / 6
		local tall = i % 3 == 0
		local cf = cc * CFrame.new(math.sin(a) * 30, 0, math.cos(a) * 30) * CFrame.Angles(0, a, 0)
		box(f, cf, 0, 0, 0, 5, if tall then 6.4 else 2.6, 3.4, if tall then C.castleD else pick({ C.stone, C.stoneL }))
		if tall then
			trident(f, cf * CFrame.new(0, 3.4, 1.82), 1.3)
		end
	end
end

-- each player's camp behind where their team stands: two banners and a tent in their colour
local function camps(parent: Instance)
	local f = folder(parent, "Camps")
	for k, colour in Battlefield.COLOURS do
		local cf = Battlefield.seat(W, #Battlefield.COLOURS, k)
		local trim = colour:Lerp(Color3.new(1, 1, 1), 0.55)
		local side = if k == 1 then -1 else 1
		for _, sx in { -1, 1 } do
			box(f, cf, sx * 29.4, 0, 55.6, 3.4, 5, 3.4, C.castleL)
			box(f, cf, sx * 29.4, 5, 55.6, 3.9, 0.9, 3.9, colour)
			banner(f, cf * CFrame.new(sx * 29.4, 5.9, 55.6), 12, 4.6, colour, trim, false)
		end
		local home = cf * CFrame.new(side * 22, 0, 76) * CFrame.Angles(0, rad(180 + side * 14), 0)
		tent(f, home, 1.05, colour, trim, false)
		crate(f, home, side * -13, 2, 3.2, 0)
		crate(f, home, side * -16.6, 3, 2.6, 0)
		brazier(f, cf * CFrame.new(side * -4, 0, 70), 1, 0)
	end
end

-- the approach: the road from the hub between the camps, the Legion's ruined gateway across it, braziers
-- and banners along it, pines up both sides
local function approach(parent: Instance)
	local f = folder(parent, "Approach")
	local far = Battlefield.REACH - 14
	for z = 96, far, 8 do -- the trodden road
		local k = rng:NextNumber(-5, 5)
		local d = rng:NextNumber(20, 25)
		unlit(disc(f, W, rng:NextNumber(-2, 2), 0.01 + (z % 3) * 0.003, z, d, 0.12, rgb(150 + k, 108 + k, 70 + k)))
	end
	arch(f, at(0, 330))
	for _, sx in { -1, 1 } do
		banner(f, at(sx * 19, 330), 16, 5.4, C.purple, C.violet, true)
		for z = 180, far - 40, 90 do
			brazier(f, at(sx * 17, z), 1, 0)
		end
	end
	watchtower(f, at(-44, 500, 12), true)
	watchtower(f, at(46, far - 60, -10), false)
	ruin(f, at(50, 420, 80), 5, 3, true)
	ruin(f, at(-52, 610, -70), 4, 2, false)
	rock(f, at(-40, 380), 2.2, true)
	rock(f, at(42, 560), 2.6, true)
	rock(f, at(-38, far - 100), 1.8, false)
	for _ = 1, 90 do -- pines up the slopes either side, clear of the towers
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = side * rng:NextNumber(34, 150), rng:NextNumber(300, far)
		if not (math.abs(x) < 70 and (math.abs(z - 500) < 22 or math.abs(z - far + 60) < 22)) then
			pine(f, at(x, z, rng:NextNumber(0, 90)), rng:NextNumber(1.4, 2.4))
		end
	end
end

-- Build the battlefield in `parent` with its stand at `frame` (the teams look towards its -Z).
function Battlefield.build(parent: Instance, frame: CFrame)
	W = frame
	rng = Random.new(11)
	ground(parent)
	castle(parent)
	mountains(parent)
	water(parent)
	forest(parent)
	camp(parent)
	camps(parent)
	approach(parent)
	-- what a player can bump into: anything big that is not a glow, the water or a flat patch
	for _, d in parent:GetDescendants() do
		if d:IsA("BasePart") and d.Material ~= M.Neon and d.Parent and d.Parent.Name ~= "Water" then
			local s = d.Size
			local thin = math.min(s.X, s.Y, s.Z)
			-- the bridge's planks are thin but walked on
			d.CanCollide = d.CanCollide or (math.max(s.X, s.Y, s.Z) >= 6 and (thin >= 2 or d.Parent.Name == "Bridge"))
		end
	end
	local function mark(name: string, tag: string, z: number)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.Transparency = name, true, false, false, 1
		p.Size, p.CFrame = Vector3.one, frame * CFrame.new(0, 0, z)
		p.Parent = parent
		CollectionService:AddTag(p, tag)
	end
	mark("Stand", "FieldStand", 0)
	mark("Gate", "FieldGate", -104) -- the near edge of the summoning circle
end

return Battlefield
