--!strict
-- Building blocks the arena is made from (decision 0047): the palette, never-blocking decoration
-- parts, a flat disc for the floor, a flame, a small skull, a detailed demon head and a carved column.
-- Shared by Arena.luau and Breach.luau. Display only.

local Props = require(script.Parent:WaitForChild("Props"))
local part, pillar = Props.part, Props.pillar

local Kit = {}

Kit.M = Enum.Material
local M = Kit.M
Kit.STONE = Color3.fromRGB(78, 72, 96)
Kit.DARK = Color3.fromRGB(44, 38, 56)
Kit.ASH = Color3.fromRGB(28, 25, 34)
Kit.BRICK = Color3.fromRGB(64, 56, 72)
Kit.IRON = Color3.fromRGB(48, 50, 60)
Kit.BONE = Color3.fromRGB(224, 216, 192)
Kit.OLD_BONE = Color3.fromRGB(184, 174, 152)
Kit.VIOLET = Color3.fromRGB(150, 90, 255)
Kit.CLOTH = Color3.fromRGB(150, 24, 40)
Kit.EYE = Color3.fromRGB(190, 120, 255)
Kit.EMBER = Color3.fromRGB(255, 90, 50)
local STONE, DARK, IRON, BONE, OLD_BONE, VIOLET, EYE =
	Kit.STONE, Kit.DARK, Kit.IRON, Kit.BONE, Kit.OLD_BONE, Kit.VIOLET, Kit.EYE

local V = Vector3.new
Kit.V = V

-- Decorations never block a player or a ray; only walls, towers and the floor do.
function Kit.soft(p: BasePart): BasePart
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	return p
end
local soft = Kit.soft

function Kit.box(parent: Instance, size: Vector3, at: CFrame | Vector3, colour: Color3, mat: Enum.Material?): Part
	return soft(part(parent, size, at, colour, mat)) :: Part
end
local box = Kit.box

function Kit.ball(parent: Instance, at: Vector3, diameter: number, colour: Color3, mat: Enum.Material?): Part
	local p = box(parent, V(diameter, diameter, diameter), at, colour, mat)
	p.Shape = Enum.PartType.Ball
	return p
end
local ball = Kit.ball

function Kit.wedge(parent: Instance, size: Vector3, cf: CFrame, colour: Color3, mat: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size, w.CFrame, w.Color = size, cf, colour
	w.Material = mat or M.Slate
	soft(w)
	w.Parent = parent
	return w
end

function Kit.glow(p: BasePart, colour: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = colour, range, brightness, false
	l.Parent = p
end
local glow = Kit.glow

-- A flat disc lying on the floor (its top is a hair above it).
function Kit.flat(
	parent: Instance,
	at: Vector3,
	diameter: number,
	colour: Color3,
	mat: Enum.Material?,
	lift: number?
): BasePart
	return soft(pillar(parent, V(at.X, 0.4 + (lift or 0.05), at.Z), 0.02, diameter / 2, colour, mat))
end

function Kit.flame(parent: BasePart, hot: Color3, cold: Color3, size: number)
	local f = Instance.new("ParticleEmitter")
	f.Texture = "rbxasset://textures/particles/fire_main.dds"
	f.Color = ColorSequence.new(hot, cold)
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.12) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(0.7, 1.2)
	f.Rate = 16
	f.Speed = NumberRange.new(4, 7)
	f.LightEmission = 1
	f.EmissionDirection = Enum.NormalId.Top
	f.Parent = parent
end

-- A plain skull (looking along `dir`): bone dome, two dark sockets, a jaw.
function Kit.skull(parent: Instance, at: Vector3, dir: Vector3, s: number, eyes: Color3?)
	local cf = CFrame.lookAt(at, at + dir)
	ball(parent, at, 2 * s, BONE, M.Marble)
	box(parent, V(1.3 * s, 0.7 * s, 1.1 * s), cf * CFrame.new(0, -0.95 * s, -0.45 * s), BONE, M.Marble)
	for _, sx in { -1, 1 } do
		local socket = ball(
			parent,
			(cf * CFrame.new(sx * 0.42 * s, 0.12 * s, -0.8 * s)).Position,
			0.55 * s,
			eyes or Color3.fromRGB(14, 8, 22),
			if eyes then M.Neon else M.SmoothPlastic
		)
		if eyes then
			glow(socket, eyes, 14, 1.5)
		end
	end
end

-- A horned demon head, about 2.4 `s` tall, looking along `dir`: a cracked cranium crowned with thorns, a
-- heavy brow with spikes, deep sockets with glowing eyes, cheekbones and cheek spines, a nose cavity, an
-- open jaw of fangs and ridged horns that sweep out and up. About 60 parts and one light.
function Kit.demonHead(parent: Instance, at: Vector3, dir: Vector3, s: number, eyes: Color3?)
	local glowColour = eyes or EYE
	local cf = CFrame.lookAt(at, at + dir)
	local function p(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x * s, y * s, z * s)
	end
	local function rot(x: number, y: number, z: number): CFrame
		return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
	end
	ball(parent, p(0, 0.3, 0.1).Position, 2.1 * s, BONE, M.Marble) -- cranium
	for _, k in { -0.5, 0, 0.5 } do -- sutures and cracks
		box(parent, V(0.06 * s, 0.9 * s, 0.05 * s), p(k, 0.9, -0.2) * rot(-35, 0, k * 40), OLD_BONE, M.Slate)
	end
	for k = -2, 2 do -- the crown of thorns
		box(
			parent,
			V(0.2 * s, (0.8 + 0.25 * (2 - math.abs(k))) * s, 0.2 * s),
			p(k * 0.38, 1.25, 0.05) * rot(0, 0, -k * 14),
			OLD_BONE,
			M.Slate
		)
	end
	box(parent, V(2.3 * s, 0.5 * s, 0.9 * s), p(0, 0.62, -0.78) * rot(-8, 0, 0), OLD_BONE, M.Slate) -- brow
	for _, sx in { -1, 1 } do
		box(parent, V(0.32 * s, 1 * s, 0.32 * s), p(sx * 0.95, 0.95, -0.7) * rot(0, 0, sx * -30), OLD_BONE, M.Slate) -- brow spikes
		ball(parent, p(sx * 0.46, 0.3, -0.86).Position, 0.74 * s, Color3.fromRGB(10, 6, 16), M.SmoothPlastic) -- socket
		local eye = ball(parent, p(sx * 0.46, 0.3, -0.98).Position, 0.38 * s, glowColour, M.Neon)
		if sx == 1 then
			glow(eye, glowColour, 30, 2)
		end
		box(parent, V(0.55 * s, 0.36 * s, 0.8 * s), p(sx * 0.8, -0.15, -0.6) * rot(0, sx * -12, 0), BONE, M.Marble) -- cheekbone
		box(parent, V(0.24 * s, 0.8 * s, 0.24 * s), p(sx * 1.0, -0.4, -0.55) * rot(0, 0, sx * -38), OLD_BONE, M.Slate) -- cheek spine
		box(parent, V(0.34 * s, 0.6 * s, 0.5 * s), p(sx * 0.68, -0.78, -0.3), BONE, M.Marble) -- jaw hinge
	end
	box(parent, V(0.22 * s, 0.7 * s, 0.3 * s), p(0, 0.05, -1.02), BONE, M.Marble) -- nose bridge
	box(parent, V(0.34 * s, 0.4 * s, 0.34 * s), p(0, -0.22, -1.0), Color3.fromRGB(10, 6, 16), M.SmoothPlastic) -- nose cavity
	box(parent, V(1.2 * s, 0.3 * s, 0.8 * s), p(0, -0.5, -0.75), BONE, M.Marble) -- upper jaw
	for k = -4, 4 do -- upper fangs
		box(
			parent,
			V(0.12 * s, (if math.abs(k) == 4 then 0.62 else 0.32) * s, 0.12 * s),
			p(k * 0.13, -0.78 - (if math.abs(k) == 4 then 0.15 else 0), -1.05),
			BONE,
			M.Marble
		)
	end
	box(parent, V(1.05 * s, 0.32 * s, 0.85 * s), p(0, -1.2, -0.62) * rot(14, 0, 0), BONE, M.Marble) -- lower jaw, hanging open
	for k = -3, 3 do
		box(parent, V(0.12 * s, 0.3 * s, 0.12 * s), p(k * 0.14, -1.0, -0.98) * rot(14, 0, 0), BONE, M.Marble)
	end
	box(parent, V(0.16 * s, 0.9 * s, 0.1 * s), p(0, 0.95, -1.0), eyes or VIOLET, M.Neon) -- a rune on the brow
	for _, sx in { -1, 1 } do -- ridged horns: three segments sweeping out and up
		for k = 0, 2 do
			local w = (0.62 - k * 0.14) * s
			box(
				parent,
				V(w, 1.3 * s, w),
				p(sx * (1.05 + k * 0.62), 0.75 + k * 0.98, 0.05) * rot(0, 0, sx * -(32 + k * 17)),
				BONE,
				M.Slate
			)
			box(
				parent,
				V(w * 1.35, 0.14 * s, w * 1.35),
				p(sx * (1.05 + k * 0.62), 0.75 + k * 0.98, 0.05) * rot(0, 0, sx * -(32 + k * 17)),
				OLD_BONE,
				M.Slate
			)
		end
	end
end

-- A carved column standing on `base`: stepped plinth, a drum base, a fluted shaft with rings and a violet
-- rune band, and a capital with an abacus. `light` leaves out the flutes and the second plinth step.
function Kit.column(parent: Instance, base: Vector3, height: number, radius: number, shaft: Color3?, light: boolean?)
	local r = radius
	local tone = shaft or DARK
	local y = base.Y
	part(parent, V(2 * r + 2.4, 1.2, 2 * r + 2.4), base + V(0, 0.6, 0), STONE, M.Slate)
	if not light then
		part(parent, V(2 * r + 1.4, 1, 2 * r + 1.4), base + V(0, 1.7, 0), STONE, M.Slate)
	end
	local lower = if light then 1.2 else 2.2
	box(
		parent,
		V(1.2, 2 * r + 1.2, 2 * r + 1.2),
		CFrame.new(base.X, y + lower + 0.6, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
		IRON,
		M.Metal
	).Shape =
		Enum.PartType.Cylinder -- base drum
	local shaftFrom = lower + 1.2
	local shaftHeight = height - shaftFrom - 3
	part(
		parent,
		V(shaftHeight, 2 * r, 2 * r),
		CFrame.new(base.X, y + shaftFrom + shaftHeight / 2, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
		tone,
		M.Slate
	).Shape =
		Enum.PartType.Cylinder
	if not light then
		for k = 0, 7 do -- flutes
			local a = k * math.pi / 4
			box(
				parent,
				V(0.5, shaftHeight * 0.88, 0.9),
				CFrame.new(
					base.X + math.cos(a) * (r + 0.05),
					y + shaftFrom + shaftHeight / 2,
					base.Z + math.sin(a) * (r + 0.05)
				) * CFrame.Angles(0, -a, 0),
				tone:Lerp(Color3.new(0, 0, 0), 0.35),
				M.Slate
			)
		end
	end
	for _, f in { 0.28, 0.5, 0.72 } do -- rings, the middle one a violet rune band
		local ring = box(
			parent,
			V(f == 0.5 and 0.5 or 0.8, 2 * r + 1.1, 2 * r + 1.1),
			CFrame.new(base.X, y + shaftFrom + shaftHeight * f, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
			if f == 0.5 then VIOLET else IRON,
			if f == 0.5 then M.Neon else M.Metal
		)
		ring.Shape = Enum.PartType.Cylinder
	end
	local top = y + height - 3
	local cap = box(
		parent,
		V(1.4, 2 * r + 1.8, 2 * r + 1.8),
		CFrame.new(base.X, top + 0.7, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
		IRON,
		M.Metal
	)
	cap.Shape = Enum.PartType.Cylinder
	part(parent, V(2 * r + 2.8, 1.2, 2 * r + 2.8), V(base.X, top + 2.1, base.Z), STONE, M.Slate)
	part(parent, V(2 * r + 1.6, 0.6, 2 * r + 1.6), V(base.X, top + 2.8, base.Z), DARK, M.Slate)
end

return Kit
