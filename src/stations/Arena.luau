--!strict
-- The battle arena (decisions 0045, 0046): the canyon north of the hub, built as a place of dread.
-- A paved pit with violet cracks, scorch marks and a summoning circle; tall brick walls down both sides
-- with buttresses, banners, skulls, gallows cages and braziers; a dark gatehouse where players come in;
-- the team's blue dais; stone demon-knights standing guard; and, at the far end, the Hexbound's gate: a
-- fanged arch with a shimmering violet portal the enemies walk out of. Bones, spears, rubble, drifting
-- embers, falling ash and low mist finish it. Built once, from parts, with a fixed seed. Display only:
-- nothing here decides anything. The dais itself ("WaveStand") is made by World.luau; the portal is
-- tagged "ArenaGate" here for WaveShow.

local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar = Props.part, Props.pillar

local Arena = {}

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local M = Kit.M
local STONE, DARK, BRICK, IRON, BONE, VIOLET, CLOTH, ASH, EYE =
	Kit.STONE, Kit.DARK, Kit.BRICK, Kit.IRON, Kit.BONE, Kit.VIOLET, Kit.CLOTH, Kit.ASH, Kit.EYE
local V, box, ball, wedge, glow, flat, flame, skull =
	Kit.V, Kit.box, Kit.ball, Kit.wedge, Kit.glow, Kit.flat, Kit.flame, Kit.skull
local demonHead, column = Kit.demonHead, Kit.column
local Breach = require(script.Parent:WaitForChild("Breach"))

Arena.DAIS_AT = 75 -- where the team stands: World.luau puts the stand there
local DAIS_AT = Arena.DAIS_AT
local PIT_FROM, PIT_TO, GATE_AT = 6, 196, 190 -- distances into the canyon from its mouth

-- A stone demon-knight on a plinth, standing at `base` and facing `toward`.
local function statue(parent: Instance, base: Vector3, toward: Vector3)
	local cf = CFrame.lookAt(base, V(toward.X, base.Y, toward.Z))
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	part(parent, V(9, 3, 9), at(0, 1.5, 0), STONE, M.Slate)
	part(parent, V(7, 1, 7), at(0, 3.5, 0), DARK, M.Slate)
	for _, sx in { -1, 1 } do
		box(parent, V(2, 6, 2.4), at(sx * 1.4, 7, 0), IRON, M.Metal) -- legs
		box(parent, V(2.4, 2, 3), at(sx * 4.1, 15.2, 0), IRON, M.Metal) -- pauldrons
		wedge(parent, V(1.2, 4, 2), at(sx * 4.4, 17.4, 0) * CFrame.Angles(0, 0, sx * math.rad(-12)), IRON, M.Metal)
	end
	box(parent, V(6, 7, 3.4), at(0, 13, 0), IRON, M.Metal) -- chest
	box(parent, V(4, 1.6, 3), at(0, 9.4, 0), DARK, M.Metal) -- belt
	ball(parent, (at(0, 17.6, 0)).Position, 3.4, IRON, M.Metal) -- helm
	for _, sx in { -1, 1 } do -- horns
		box(parent, V(0.9, 5, 0.9), at(sx * 1.9, 19.8, 0.2) * CFrame.Angles(0, 0, sx * math.rad(-28)), BONE, M.Slate)
		local eye = box(parent, V(0.9, 0.4, 0.3), at(sx * 0.8, 17.9, -1.62), EYE, M.Neon)
		eye.Name = "StatueEye"
	end
	box(
		parent,
		V(0.7, 13, 1.4),
		at(5.4, 9.5, -2) * CFrame.Angles(math.rad(-18), 0, 0),
		Color3.fromRGB(120, 124, 140),
		M.Metal
	) -- sword
	box(parent, V(3.6, 0.7, 0.9), at(5.4, 6.6, -1.4), IRON, M.Metal)
	box(parent, V(2, 8, 0.8), at(-5.2, 11, -1.8) * CFrame.Angles(0, math.rad(20), 0), DARK, M.Metal) -- shield
end

local function floorOf(f: Folder, c: { half: number, zAt: (number) -> number, rng: Random })
	local half = c.half
	local len = PIT_TO - PIT_FROM
	local mid = c.zAt(PIT_FROM + len / 2)
	part(f, V(half * 2, 0.1, len), V(0, 0.4, mid), STONE, M.Slate)
	for d = PIT_FROM + 6, PIT_TO - 6, 12 do -- paving
		box(f, V(half * 2, 0.12, 0.5), V(0, 0.4, c.zAt(d)), DARK, M.Slate)
	end
	for x = -36, 36, 18 do
		box(f, V(0.5, 0.12, len), V(x, 0.4, mid), DARK, M.Slate)
	end
	for _, sx in { -1, 1 } do -- violet trim along both sides
		box(f, V(1, 0.2, len), V(sx * half, 0.45, mid), VIOLET, M.Neon)
	end
	for _, d in { PIT_FROM, PIT_TO } do
		box(f, V(half * 2 + 1, 0.2, 1), V(0, 0.45, c.zAt(d)), VIOLET, M.Neon)
	end
	local rng = c.rng
	for _ = 1, 24 do -- scorch marks
		flat(
			f,
			V(rng:NextNumber(-46, 46), 0, c.zAt(rng:NextNumber(12, 186))),
			rng:NextNumber(5, 13),
			ASH,
			M.Slate,
			0.06
		).Transparency =
			0.12
	end
	for _ = 1, 8 do -- old blood
		flat(
			f,
			V(rng:NextNumber(-44, 44), 0, c.zAt(rng:NextNumber(14, 180))),
			rng:NextNumber(3, 8),
			Color3.fromRGB(96, 22, 30),
			M.Slate,
			0.07
		).Transparency =
			0.3
	end
	for _ = 1, 40 do -- violet cracks leaking light
		local len2 = rng:NextNumber(5, 17)
		box(
			f,
			V(0.3, 0.06, len2),
			CFrame.new(rng:NextNumber(-48, 48), 0.47, c.zAt(rng:NextNumber(10, 188)))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			VIOLET,
			M.Neon
		).Transparency =
			0.15
	end
end

local function wallsOf(f: Folder, c: { half: number, zAt: (number) -> number, rng: Random })
	local from, to = 2, PIT_TO + 4
	local len = to - from
	local mid = c.zAt(from + len / 2)
	local x = c.half + 3.5
	for _, sx in { -1, 1 } do
		part(f, V(5, 14, len), V(sx * x, 7, mid), BRICK, M.Brick)
		part(f, V(6.4, 1.6, len), V(sx * (x - 0.3), 14.8, mid), DARK, M.Slate)
		for d = from + 3, to - 2, 7 do -- crenellations
			box(f, V(6, 3, 3.6), V(sx * (x - 0.3), 17, c.zAt(d)), BRICK, M.Brick)
		end
		for d = 14, 186, 28 do -- buttresses with horned tops
			part(f, V(7, 20, 6), V(sx * (x - 3), 10, c.zAt(d)), DARK, M.Slate)
			part(f, V(8, 2, 7), V(sx * (x - 3), 20.5, c.zAt(d)), STONE, M.Slate)
			for _, hx in { -1, 1 } do
				box(
					f,
					V(1.2, 7, 1.2),
					CFrame.new(sx * (x - 3) + hx * 2.4, 25, c.zAt(d)) * CFrame.Angles(0, 0, hx * math.rad(-24)),
					BONE,
					M.Slate
				)
			end
			local eye = ball(f, V(sx * (x - 6.6), 15, c.zAt(d)), 1.6, EYE, M.Neon)
			eye.Name = "WallEye"
		end
		for d = 40, 170, 32 do -- banners down the wall, with a violet sigil
			local at = V(sx * (x - 2.7), 10.5, c.zAt(d))
			box(f, V(0.4, 12, 5.4), at, CLOTH, M.Fabric)
			box(f, V(0.5, 1.2, 5.6), at + V(0, -6.4, 0), ASH, M.Fabric)
			local sigil = box(f, V(0.5, 3, 3), at + V(0, 1, 0), VIOLET, M.Neon)
			sigil.Shape = Enum.PartType.Cylinder
			sigil.CFrame = CFrame.new(sigil.Position) * CFrame.Angles(0, 0, 0)
			sigil.Size = V(0.3, 3, 3)
		end
		for d = 30, 180, 24 do -- skulls on the wall face
			skull(f, V(sx * (x - 2.9), 8, c.zAt(d + 12)), V(-sx, 0, 0), 1.1)
		end
		for d = 12, 190, 32 do -- stakes leaning out of the ground
			for k = -1, 1 do
				local at = V(sx * (x - 5.2 - math.abs(k) * 0.5), 0.4, c.zAt(d + k * 1.6))
				box(
					f,
					V(0.6, 8, 0.6),
					CFrame.new(at + V(-sx * 1.2, 3.6, 0)) * CFrame.Angles(0, 0, sx * math.rad(18)),
					IRON,
					M.Metal
				)
				box(
					f,
					V(0.8, 0.8, 0.8),
					CFrame.new(at + V(-sx * 2.6, 7.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
					IRON,
					M.Metal
				)
			end
		end
		for _, d in { 24, 56, 88, 120, 152, 184 } do -- braziers on stone plinths, warm near the team, violet near the gate
			local warm = d < 110
			local hot = if warm then Color3.fromRGB(255, 150, 60) else Color3.fromRGB(170, 90, 255)
			local cold = if warm then Color3.fromRGB(255, 80, 30) else Color3.fromRGB(80, 30, 160)
			local base = V(sx * (c.half - 1.4), 0.4, c.zAt(d))
			column(f, base, 7.4, 1.3, STONE, true)
			local bowl = pillar(f, base + V(0, 7.5, 0), 1, 2.5, IRON, M.Metal)
			flame(bowl, hot, cold, 4)
			glow(bowl, hot, 30, 1.2)
		end
	end
end

local function gallows(f: Folder, c: { half: number, zAt: (number) -> number }, sx: number, d: number)
	local x = c.half + 1
	local z = c.zAt(d)
	pillar(f, V(sx * x, 14.5, z), 14, 0.5, IRON, M.Metal)
	box(f, V(11, 0.9, 0.9), V(sx * (x - 5.5), 28, z), IRON, M.Metal)
	local cx = sx * (x - 10)
	pillar(f, V(cx, 21, z), 7, 0.15, IRON, M.Metal) -- chain
	box(f, V(4.2, 0.4, 4.2), V(cx, 21, z), IRON, M.Metal)
	box(f, V(4.2, 0.4, 4.2), V(cx, 15, z), IRON, M.Metal)
	for _, bx in { -1.8, -0.6, 0.6, 1.8 } do
		for _, bz in { -1.8, 1.8 } do
			pillar(f, V(cx + bx, 15, z + bz), 6, 0.14, IRON, M.Metal)
		end
	end
	local soul = ball(f, V(cx, 18, z), 1.8, EYE, M.Neon)
	soul.Transparency = 0.15
	glow(soul, EYE, 16, 1)
end

local function entranceTower(f: Folder, sx: number, z: number)
	local cx = sx * 31
	part(f, V(17, 2, 17), V(cx, 1, z), STONE, M.Slate) -- a stepped plinth
	part(f, V(15, 2, 15), V(cx, 3, z), DARK, M.Slate)
	part(f, V(12, 36, 12), V(cx, 22, z), BRICK, M.Brick)
	for _, y in { 12, 24, 36 } do -- stone bands
		box(f, V(13.6, 1.2, 13.6), V(cx, y, z), STONE, M.Slate)
	end
	for _, kx in { -1, 1 } do -- a carved column at every corner
		for _, kz in { -1, 1 } do
			column(f, V(cx + kx * 6.4, 4, z + kz * 6.4), 36, 1.25, STONE, true)
		end
	end
	for _, y in { 17, 31 } do -- arrow slits glowing from within, on the face the hub sees
		for _, dx in { -2.6, 2.6 } do
			box(f, V(1.8, 5.6, 0.6), V(cx + dx, y, z + 6.2), DARK, M.Slate)
			box(f, V(0.7, 4.6, 0.3), V(cx + dx, y, z + 6.5), VIOLET, M.Neon)
		end
	end
	part(f, V(15, 2, 15), V(cx, 41, z), STONE, M.Slate) -- the platform and its stepped overhang
	for k = -1, 1 do
		for _, side in { -1, 1 } do
			box(f, V(1.8, 2, 2.4), V(cx + k * 4.5, 39.6, z + side * 7), DARK, M.Slate)
			box(f, V(2.4, 2, 1.8), V(cx + side * 7, 39.6, z + k * 4.5), DARK, M.Slate)
		end
	end
	for k = -1, 1, 2 do
		for j = -1, 1, 2 do
			part(f, V(3, 3, 3), V(cx + k * 6, 43.5, z + j * 6), STONE, M.Slate)
		end
	end
	local bowl = pillar(f, V(cx, 42, z), 1, 3, IRON, M.Metal)
	flame(bowl, Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 60, 20), 6)
	glow(bowl, Color3.fromRGB(255, 140, 50), 40, 1.5)
	box(f, V(0.5, 24, 1.4), V(sx * 24.8, 24, z + 1), VIOLET, M.Neon)
	box(f, V(4, 1.2, 3.4), V(cx, 27.6, z + 7.4), STONE, M.Slate) -- a gargoyle on a ledge
	demonHead(f, V(cx, 30, z + 7.6), V(0, 0, 1), 1.5)
end

local function entrance(f: Folder, c: { half: number, zAt: (number) -> number })
	local z = c.zAt(3)
	for _, sx in { -1, 1 } do
		entranceTower(f, sx, z)
	end
	part(f, V(50, 9, 12), V(0, 34.5, z), STONE, M.Slate)
	part(f, V(54, 2, 13), V(0, 39.5, z), DARK, M.Slate)
	for _, y in { 31, 38 } do
		box(f, V(51, 0.8, 12.8), V(0, y, z), IRON, M.Metal)
	end
	for x = -22, 22, 4.4 do -- the portcullis, raised
		pillar(f, V(x, 22, z + 5.4), 12, 0.35, IRON, M.Metal)
		box(
			f,
			V(0.8, 0.8, 0.8),
			CFrame.new(x, 21.8, z + 5.4) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			IRON,
			M.Metal
		)
	end
	box(f, V(48, 0.8, 0.8), V(0, 28, z + 5.4), IRON, M.Metal)
	box(f, V(48, 0.8, 0.8), V(0, 25, z + 5.4), IRON, M.Metal)
	-- the great demon head over the arch, on a carved plinth
	part(f, V(26, 2, 12), V(0, 41.5, z), STONE, M.Slate)
	part(f, V(18, 2, 10), V(0, 43.5, z), DARK, M.Slate)
	demonHead(f, V(0, 51, z + 3), V(0, 0, 1), 6.5, EYE)
end

local function dais(f: Folder, c: { zAt: (number) -> number })
	local z = c.zAt(DAIS_AT)
	flat(f, V(0, 0, z), 38, STONE, M.Slate, 0.12) -- the steps
	local ring = flat(f, V(0, 0, z), 41, Color3.fromRGB(80, 170, 255), M.Neon, 0.1)
	ring.Transparency = 0.35
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local base = V(math.cos(a) * 20.5, 0.4, z + math.sin(a) * 20.5)
		pillar(f, base, 4, 0.6, STONE, M.Slate)
		local orb = ball(f, base + V(0, 4.9, 0), 1.6, Color3.fromRGB(110, 190, 255), M.Neon)
		if k % 2 == 0 then
			glow(orb, Color3.fromRGB(110, 190, 255), 24, 1)
		end
	end
end

local function gate(f: Folder, c: { half: number, zAt: (number) -> number })
	local gz = c.zAt(GATE_AT)
	for _, sx in { -1, 1 } do
		column(f, V(sx * 26, 0.4, gz), 35, 4.8, DARK) -- a great carved column
		box(f, V(1.2, 22, 0.3), V(sx * 26, 16, gz + 5.2), VIOLET, M.Neon)
		part(f, V(11, 2, 11), V(sx * 26, 36.2, gz), STONE, M.Slate)
		for k = 0, 1 do -- horns sweeping out and up
			box(
				f,
				V(1.6 - k * 0.4, 9, 1.6 - k * 0.4),
				CFrame.new(sx * (28.4 + k * 3.4), 42 + k * 7, gz) * CFrame.Angles(0, 0, sx * math.rad(-26 - k * 22)),
				BONE,
				M.Slate
			)
		end
		for _, side in { -1, 1 } do -- chains hanging beside the portal
			pillar(f, V(sx * 17.5 + side * 1.2, 20, gz + 4.6), 18, 0.2, IRON, M.Metal)
		end
		local eye = ball(f, V(sx * 26, 24, gz + 5.6), 1.8, EYE, M.Neon) -- an eye in each column
		eye.Name = "GateEye"
	end
	part(f, V(60, 8, 9), V(0, 38, gz), STONE, M.Slate)
	part(f, V(52, 2, 10), V(0, 43, gz), DARK, M.Slate)
	for _, x in { -24, -12, 12, 24 } do -- spires along the lintel
		part(f, V(3, 5, 3), V(x, 46.5, gz), DARK, M.Slate)
		box(f, V(1.6, 4, 1.6), CFrame.new(x, 50.5, gz) * CFrame.Angles(0, math.rad(45), 0), BONE, M.Slate)
	end
	part(f, V(14, 2, 8), V(0, 45, gz), STONE, M.Slate) -- a plinth for the crest
	demonHead(f, V(0, 49.5, gz + 2), V(0, 0, 1), 4.5, VIOLET)
	for x = -22, 22, 5.5 do -- fangs
		box(f, V(2.2, 4.5, 1.8), V(x, 32.6, gz + 4), BONE, M.Marble)
		box(f, V(1.2, 2.5, 1.2), V(x, 29.4, gz + 4), BONE, M.Marble)
	end
	local brow = box(f, V(12, 1.6, 3), V(0, 41.6, gz + 5.4), DARK, M.Slate)
	brow.Name = "Brow"
	local eye = ball(f, V(0, 38.4, gz + 5.2), 5.2, VIOLET, M.Neon)
	glow(eye, VIOLET, 44, 2)
	for _, sx in { -1, 1 } do -- the walls either side; the way behind the portal stays open to the breach
		part(f, V(c.half - 30.8, 50, 3), V(sx * (c.half + 30.8) / 2, 25, gz - 5), Color3.fromRGB(26, 22, 36), M.Slate)
	end
	local portal = part(f, V(44, 30, 0.6), V(0, 15.4, gz + 1), Color3.fromRGB(130, 60, 230), M.ForceField)
	portal.Name = "Portal"
	portal.CastShadow = false
	glow(portal, VIOLET, 50, 2.2)
	for _, sx in { -1, 1 } do -- its frame
		box(f, V(1.4, 31, 1.4), V(sx * 22.4, 15.5, gz + 1.2), VIOLET, M.Neon)
	end
	box(f, V(46, 1.4, 1.4), V(0, 30.6, gz + 1.2), VIOLET, M.Neon)
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(150, 80, 240), Color3.fromRGB(30, 10, 60))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 11) })
	mist.Lifetime = NumberRange.new(2, 3.5)
	mist.Rate = 26
	mist.Speed = NumberRange.new(2, 5)
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.EmissionDirection = Enum.NormalId.Back
	mist.LightEmission = 0.6
	mist.Parent = portal
	CollectionService:AddTag(portal, "ArenaGate")
	-- the summoning circle the enemies step out onto
	local cz = c.zAt(GATE_AT - 12)
	for _, ring in { { 44, 40 }, { 33, 29 }, { 22, 18 } } do
		local out = flat(f, V(0, 0, cz), ring[1], VIOLET, M.Neon, 0.07)
		out.Transparency = 0.25
		flat(f, V(0, 0, cz), ring[2], STONE, M.Slate, 0.09)
	end
	for k = 0, 7 do -- runes between the rings
		local a = k * math.pi / 4
		local mid = 25.5
		box(
			f,
			V(0.4, 0.06, 5),
			CFrame.new(math.cos(a) * mid, 0.5, cz + math.sin(a) * mid) * CFrame.Angles(0, -a, 0),
			VIOLET,
			M.Neon
		).Transparency =
			0.2
	end
end

-- Bones, spears and rubble, thrown about by a fixed seed; more at the edges than the middle.
local function litter(f: Folder, c: { half: number, zAt: (number) -> number, rng: Random })
	local rng = c.rng
	local function spot(): Vector3
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local edge = rng:NextNumber() < 0.7
		local x = if edge then side * rng:NextNumber(36, 50) else rng:NextNumber(-34, 34)
		return V(x, 0.46, c.zAt(rng:NextNumber(12, 186)))
	end
	for _ = 1, 50 do -- rubble
		local s = rng:NextNumber(0.6, 2.2)
		box(
			f,
			V(s, s * rng:NextNumber(0.4, 0.9), s * rng:NextNumber(0.7, 1.3)),
			CFrame.new(spot() + V(0, s * 0.2, 0))
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)),
			if rng:NextNumber() < 0.5 then DARK else STONE,
			M.Slate
		)
	end
	for _ = 1, 12 do -- bone piles
		local at = spot()
		skull(f, at + V(0, 0.8, 0), V(rng:NextNumber(-1, 1), 0.2, rng:NextNumber(-1, 1)), 0.7)
		for _ = 1, 4 do
			box(
				f,
				V(0.35, 0.35, rng:NextNumber(2, 3.6)),
				CFrame.new(at + V(rng:NextNumber(-1.6, 1.6), 0.25, rng:NextNumber(-1.6, 1.6)))
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), 0),
				BONE,
				M.Marble
			)
		end
	end
	for _ = 1, 16 do -- spears stuck in the floor, with torn pennants
		local at = spot()
		local lean = CFrame.new(at + V(0, 3.6, 0))
			* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6), rng:NextNumber(-0.35, 0.35))
		box(f, V(0.3, 9, 0.3), lean, Color3.fromRGB(96, 70, 52), M.Wood)
		box(
			f,
			V(0.6, 1.4, 0.6),
			lean * CFrame.new(0, 5.1, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color3.fromRGB(150, 154, 168),
			M.Metal
		)
		box(f, V(0.08, 1.6, 2), lean * CFrame.new(0, 3.2, 1.1), CLOTH, M.Fabric)
	end
end

-- Embers drifting up, ash falling and low mist crawling along the floor.
local function weather(f: Folder, c: { zAt: (number) -> number, half: number })
	local function volume(size: Vector3, at: Vector3): Part
		local p = box(f, size, at, ASH)
		p.Transparency = 1
		p.CastShadow = false
		return p
	end
	local mid = c.zAt((PIT_FROM + PIT_TO) / 2)
	local embers = volume(V(c.half * 2, 1, PIT_TO - PIT_FROM), V(0, 1, mid))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60), Color3.fromRGB(180, 40, 20))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = 11
	e.Speed = NumberRange.new(2, 5)
	e.Acceleration = Vector3.new(1, 1.5, 0.5)
	e.LightEmission = 1
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = embers
	local ash = volume(V(c.half * 2, 1, PIT_TO - PIT_FROM), V(0, 46, mid))
	local a = Instance.new("ParticleEmitter")
	a.Color = ColorSequence.new(Color3.fromRGB(70, 66, 80))
	a.Size = NumberSequence.new(0.35)
	a.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	a.Lifetime = NumberRange.new(7, 10)
	a.Rate = 14
	a.Speed = NumberRange.new(2, 4)
	a.RotSpeed = NumberRange.new(-60, 60)
	a.Acceleration = Vector3.new(0.8, 0, 0)
	a.Shape = Enum.ParticleEmitterShape.Box
	a.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	a.EmissionDirection = Enum.NormalId.Bottom
	a.Parent = ash
	for d = 30, 180, 30 do -- low mist
		local fog = volume(V(c.half * 1.7, 1, 24), V(0, 1.2, c.zAt(d)))
		local m = Instance.new("ParticleEmitter")
		m.Texture = "rbxasset://textures/particles/smoke_main.dds"
		m.Color = ColorSequence.new(Color3.fromRGB(130, 110, 160))
		m.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 20) })
		m.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		m.Lifetime = NumberRange.new(5, 8)
		m.Rate = 5
		m.Speed = NumberRange.new(0.5, 1.5)
		m.Shape = Enum.ParticleEmitterShape.Box
		m.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		m.EmissionDirection = Enum.NormalId.Top
		m.Parent = fog
	end
end

-- Dress the canyon in `arena`: `half` is the canyon's half width, `near` its distance from the
-- hub's centre to its mouth.
function Arena.build(arena: Folder, half: number, near: number)
	local f = Instance.new("Folder")
	f.Name = "Dressing"
	f.Parent = arena
	local c = {
		half = half - 8, -- the pit's own half width: the walls stand outside it
		rng = Random.new(46),
		zAt = function(d: number): number
			return -(near + d)
		end,
	}
	floorOf(f, c)
	wallsOf(f, c)
	dais(f, c)
	entrance(f, c)
	gate(f, c)
	for _, sx in { -1, 1 } do
		for _, d in { 60, 110, 160 } do
			gallows(f, c, sx, d)
		end
		statue(f, V(sx * 47, 0.4, c.zAt(110)), V(0, 0, c.zAt(110)))
		statue(f, V(sx * 40, 0.4, c.zAt(176)), V(0, 0, c.zAt(160)))
	end
	litter(f, c)
	weather(f, c)
	Breach.build(f, half, near)
end

return Arena
