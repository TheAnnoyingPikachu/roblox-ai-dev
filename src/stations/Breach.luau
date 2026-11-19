--!strict
-- The Breach (decision 0047): behind the Hexbound's gate the canyon runs on to a vast ruined portal,
-- the gateway they tore open to come into the world. A cracked, scorched road leads to it past
-- wrecked siege towers, torn banners and bone mounds; the great stone ring stands half-buried across
-- the whole canyon, broken at the top, studded with horns and runes, with seething violet-red energy
-- in it, and chunks of rock still hanging in the air round the tear. Built once from parts with a fixed
-- seed. Display only.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))

local Breach = {}

local M = Kit.M
local V, ball, glow = Kit.V, Kit.ball, Kit.glow
local STONE, DARK, ASH, IRON, BONE, CLOTH, EMBER =
	Kit.STONE, Kit.DARK, Kit.ASH, Kit.IRON, Kit.BONE, Kit.CLOTH, Kit.EMBER
local FROM, RING_AT = 200, 292 -- distances into the canyon: where the breach road starts, and the portal's ring

type Ctx = { half: number, zAt: (number) -> number, rng: Random }

local function emitter(parent: BasePart, colour0: Color3, colour1: Color3, rate: number, size0: number, size1: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(colour0, colour1)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = rate
	e.Speed = NumberRange.new(4, 9)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.LightEmission = 0.8
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Left -- a disc turned to face the hub: its left face looks at it
	e.Parent = parent
end

-- The ring of stone: 28 blocks round a circle, the lowest half-buried, a gap torn in the upper right,
-- horns round the top and runes down the face.
local function ring(f: Folder, c: Ctx, z: number, cy: number)
	local outer, inner, n = 58, 46, 28
	local mid = (outer + inner) / 2
	local tangent = 2 * math.pi * mid / n * 1.04
	local gap = { [4] = true, [5] = true, [6] = true }
	for k = 0, n - 1 do
		local a = k / n * 2 * math.pi
		local pos = V(math.cos(a) * mid, cy + math.sin(a) * mid, z)
		if pos.Y < -10 then
			continue
		end
		local turn = CFrame.Angles(0, 0, a)
		if gap[k] then -- torn out: a chunk lies at the foot, another hangs askew
			if k == 5 then
				local fallen = V(c.rng:NextNumber(-48, -30), 3, z + c.rng:NextNumber(10, 22))
				local b = Kit.box(
					f,
					V(outer - inner, tangent, 12),
					CFrame.new(fallen) * CFrame.Angles(0.4, 0.7, 1.2),
					DARK,
					M.Slate
				)
				b.CanCollide = false
			end
			continue
		end
		local askew = if k == 3 or k == 7
			then CFrame.new(0, 0, c.rng:NextNumber(3, 6)) * CFrame.Angles(0.12, 0.1, 0)
			else CFrame.identity
		local at = CFrame.new(pos) * turn * askew
		local tone = if k % 2 == 0 then DARK else STONE
		local block = Kit.soft(Kit.box(f, V(outer - inner, tangent, 12), at, tone, M.Slate))
		block.CanCollide = pos.Y < 40
		Kit.box(f, V(outer - inner + 1.6, tangent * 0.2, 13), at * CFrame.new(0, tangent * 0.5, 0), IRON, M.Metal) -- a band between blocks
		local rune =
			Kit.box(f, V(7, 0.6, 0.3), at * CFrame.new(0, 0, 6.2) * CFrame.Angles(0, 0, math.pi / 2), Kit.EYE, M.Neon)
		rune.Name = "PortalRune"
		if pos.Y > 8 and k % 2 == 0 then -- horns radiating outward
			local long = if math.sin(a) > 0.7 then 17 else 10
			Kit.box(f, V(long, 2.6, 2.6), at * CFrame.new(outer - mid + long / 2 + 1, 0, 0), BONE, M.Slate)
			Kit.box(
				f,
				V(3.6, 3.6, 3.6),
				at * CFrame.new(outer - mid + 1.5, 0, 0) * CFrame.Angles(0.8, 0.8, 0),
				IRON,
				M.Metal
			)
		end
	end
	-- a crown of five great horns over the top of the ring, and a head at its keystone
	for k = -2, 2 do
		local a = math.pi / 2 + k * 0.17
		local at = CFrame.new(math.cos(a) * (outer + 5), cy + math.sin(a) * (outer + 5), z)
			* CFrame.Angles(0, 0, a - math.pi / 2)
		Kit.box(f, V(3.6, 22 - math.abs(k) * 4, 3.6), at * CFrame.new(0, (22 - math.abs(k) * 4) / 2, 0), BONE, M.Slate)
	end
	Kit.demonHead(f, V(0, cy + outer + 2, z + 8), V(0, 0, 1), 9, Kit.EYE)
end

local function energy(f: Folder, z: number, cy: number)
	local field = Kit.soft(
		Kit.box(
			f,
			V(2, 92, 92),
			CFrame.new(0, cy, z) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(150, 40, 130),
			M.ForceField
		)
	)
	field.Shape = Enum.PartType.Cylinder
	field.Name = "BreachField"
	local deep = Kit.soft(
		Kit.box(
			f,
			V(2, 72, 72),
			CFrame.new(0, cy, z - 2) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(70, 10, 90),
			M.Neon
		)
	)
	deep.Shape = Enum.PartType.Cylinder
	deep.Transparency = 0.45
	local core = ball(f, V(0, cy, z + 2), 14, Color3.fromRGB(255, 120, 190), M.Neon)
	core.Transparency = 0.25
	glow(core, Color3.fromRGB(230, 80, 170), 60, 3)
	emitter(field, Color3.fromRGB(240, 70, 130), Color3.fromRGB(70, 20, 140), 24, 16, 34)
	emitter(deep, Color3.fromRGB(150, 60, 255), Color3.fromRGB(40, 10, 80), 14, 12, 26)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 150, 230), Color3.fromRGB(160, 70, 255))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(1.5, 3)
	sparks.Rate = 12
	sparks.Speed = NumberRange.new(6, 14)
	sparks.LightEmission = 1
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparks.EmissionDirection = Enum.NormalId.Left
	sparks.Parent = field
end

-- The rock still hanging in the air round the tear, and the stone steps up to it.
local function debris(f: Folder, c: Ctx, z: number, cy: number)
	local rng = c.rng
	for _ = 1, 18 do
		local s = rng:NextNumber(2.5, 8)
		local at = CFrame.new(rng:NextNumber(-56, 56), rng:NextNumber(10, cy + 56), z + rng:NextNumber(6, 46))
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		Kit.box(
			f,
			V(s, s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.6, 1.2)),
			at,
			if rng:NextNumber() < 0.5 then DARK else STONE,
			M.Slate
		)
		if rng:NextNumber() < 0.4 then
			Kit.box(
				f,
				V(s * 0.9, 0.3, 0.3),
				at * CFrame.new(0, s * 0.2, -s * 0.5),
				Color3.fromRGB(255, 90, 160),
				M.Neon
			)
		end
	end
	for k = 0, 5 do -- broad steps from the road up to the foot of the ring
		Kit.soft(
			Kit.box(
				f,
				V(70 - k * 4, 0.9, 5),
				V(0, 0.4 + k * 0.9, z + 22 - k * 4),
				if k % 2 == 0 then STONE else DARK,
				M.Slate
			)
		).CanCollide =
			true
	end
end

-- The scorched road from the gate to the ring, with cracks, banners, wrecks, bone mounds and boulders.
local function road(f: Folder, c: Ctx)
	local rng = c.rng
	local len = RING_AT - FROM - 8
	local mid = c.zAt(FROM + len / 2)
	Kit.box(f, V(34, 0.1, len), V(0, 0.42, mid), ASH, M.Slate)
	for _, sx in { -1, 1 } do
		Kit.box(f, V(0.8, 0.14, len), V(sx * 17, 0.46, mid), Kit.EYE, M.Neon).Transparency = 0.25
	end
	for _ = 1, 44 do -- fissures, glowing hot
		local length = rng:NextNumber(5, 20)
		Kit.box(
			f,
			V(0.4, 0.06, length),
			CFrame.new(rng:NextNumber(-48, 48), 0.5, c.zAt(rng:NextNumber(FROM, RING_AT - 6)))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			EMBER,
			M.Neon
		).Transparency =
			0.1
	end
	for _ = 1, 16 do -- scorched earth
		Kit.flat(
			f,
			V(rng:NextNumber(-48, 48), 0, c.zAt(rng:NextNumber(FROM, RING_AT - 6))),
			rng:NextNumber(8, 22),
			ASH,
			M.Slate,
			0.08
		).Transparency =
			0.15
	end
	for _, sx in { -1, 1 } do
		for d = FROM + 12, RING_AT - 10, 22 do -- torn banners on poles
			local at = V(sx * 21, 0.4, c.zAt(d))
			Kit.box(f, V(0.5, 20, 0.5), at + V(0, 10, 0), IRON, M.Metal)
			Kit.box(
				f,
				V(0.3, 11, 5),
				CFrame.new(at + V(sx * -0.3, 13, 0)) * CFrame.Angles(0, 0, sx * 0.08),
				CLOTH,
				M.Fabric
			)
			Kit.box(f, V(0.4, 3, 3), CFrame.new(at + V(sx * -0.4, 8, 1.4)) * CFrame.Angles(0.2, 0, 0), CLOTH, M.Fabric)
		end
		-- a wrecked siege tower, fallen across the verge and still burning
		local w = V(sx * 36, 0.4, c.zAt(FROM + 58))
		local tilt = CFrame.new(w + V(0, 5, 0)) * CFrame.Angles(0, sx * 0.4, sx * 0.22)
		Kit.box(f, V(11, 10, 26), tilt, Color3.fromRGB(70, 52, 40), M.Wood)
		for _, y in { -3.5, 0, 3.5 } do
			Kit.box(f, V(11.6, 0.8, 26.6), tilt * CFrame.new(0, y, 0), IRON, M.Metal)
		end
		Kit.box(
			f,
			V(2, 24, 2),
			CFrame.new(w + V(sx * 5, 3, 8)) * CFrame.Angles(0.5, 0, sx * 0.9),
			Color3.fromRGB(70, 52, 40),
			M.Wood
		)
		local wheel =
			Kit.box(f, V(1.4, 9, 9), CFrame.new(w + V(sx * -7, 4, -6)) * CFrame.Angles(0, 0.3, 0.2), IRON, M.Metal)
		wheel.Shape = Enum.PartType.Cylinder
		local fire = Kit.box(f, V(2, 2, 2), w + V(0, 10, 0), ASH, M.Slate)
		fire.Transparency = 1
		Kit.flame(fire, Color3.fromRGB(255, 150, 60), EMBER, 9)
		glow(fire, Color3.fromRGB(255, 130, 50), 40, 1.5)
		-- boulders hiding the hills beyond the walls
		for d = FROM, RING_AT - 4, 14 do
			local s = rng:NextNumber(14, 28)
			Kit.soft(
				Kit.box(
					f,
					V(s, s * rng:NextNumber(0.9, 1.6), s),
					CFrame.new(sx * (c.half + 8 + rng:NextNumber(0, 6)), s * 0.4, c.zAt(d))
						* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, 6), rng:NextNumber(0, 0.4)),
					if rng:NextNumber() < 0.5 then DARK else Color3.fromRGB(58, 52, 70),
					M.Slate
				)
			).CanCollide =
				true
			if rng:NextNumber() < 0.5 then
				Kit.box(
					f,
					V(0.4, s * 0.8, 0.3),
					CFrame.new(sx * (c.half + 3 + rng:NextNumber(0, 4)), s * 0.4, c.zAt(d)),
					EMBER,
					M.Neon
				)
			end
		end
	end
	for _ = 1, 10 do -- bone mounds with great skulls
		local at = V(rng:NextNumber(-40, 40), 0.46, c.zAt(rng:NextNumber(FROM + 6, RING_AT - 10)))
		Kit.skull(f, at + V(0, 1.4, 0), V(rng:NextNumber(-1, 1), 0.3, rng:NextNumber(-1, 1)), 1.3)
		for _ = 1, 6 do
			Kit.box(
				f,
				V(0.5, 0.5, rng:NextNumber(3, 6)),
				CFrame.new(at + V(rng:NextNumber(-2.4, 2.4), 0.4, rng:NextNumber(-2.4, 2.4)))
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), 0),
				BONE,
				M.Marble
			)
		end
	end
end

-- Two spired obelisks guarding the foot of the ring.
local function obelisks(f: Folder, c: Ctx)
	for _, sx in { -1, 1 } do
		local base = V(sx * 38, 0.4, c.zAt(RING_AT - 22))
		Kit.column(f, base, 44, 3.4, DARK)
		for k = 0, 2 do
			Kit.box(
				f,
				V(1.2, 6, 1.2),
				CFrame.new(base + V(sx * (k - 1) * 2.6, 46.5, 0)) * CFrame.Angles(0, math.rad(45), (k - 1) * 0.35),
				BONE,
				M.Slate
			)
		end
		local eye = ball(f, base + V(0, 26, 4), 2.6, Kit.EYE, M.Neon)
		glow(eye, Kit.EYE, 30, 1.4)
	end
end

function Breach.build(arena: Folder, half: number, near: number)
	local f = Instance.new("Folder")
	f.Name = "Breach"
	f.Parent = arena
	local c: Ctx = {
		half = half - 8,
		rng = Random.new(47),
		zAt = function(d: number): number
			return -(near + d)
		end,
	}
	local z, cy = c.zAt(RING_AT), 58
	road(f, c)
	ring(f, c, z, cy)
	energy(f, z, cy)
	debris(f, c, z, cy)
	obelisks(f, c)
end

return Breach
