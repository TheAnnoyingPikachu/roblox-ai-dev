--!strict
-- The animals' spells: the magic of their power attacks (SHANNON's picks, 2026-11-21), drawn on each client. Display
-- only. Creatures.client calls `step` every frame of a "magic" clip and `stop` when it ends; a spell is a function of
-- the clip's time (`Frame.t`, 0 to 1.6 s, the impact at 0.92 s) that draws the whole effect afresh each frame from a
-- kit of pooled parts (Neon balls, blocks, cylinders, corner-wedge spikes, point lights, a see-through copy of the
-- animal, a Highlight), as the concepts in tools/blender/stations/moves (magic.py, fxkit.py) did in Blender.
--
-- A spell module (a child of this one) returns function(Spells) -> { [species or asset] = draw }: a variant's spell is its
-- asset ("creature_lion_sun_forge"), its species' under the species ("lion"), and the asset's wins. The concepts'
-- offsets carry over through `Frame.V`: V(x, y, z) is x to the animal's left, y backwards, z up (Blender's axes, as
-- the concepts were written), in studs.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimalRig"))

local Spells = {}

local TAU = 2 * math.pi
local UP = Vector3.yAxis
Spells.TAU = TAU
Spells.IMPACT = 0.92 -- seconds into the clip when it lands (Creatures.client's MAGIC_IMPACT)

-- the concepts' colours (magic.py), 0 to 1
local function rgb(r: number, g: number, b: number): Color3
	return Color3.new(r, g, b)
end
Spells.C = {
	SILVER = rgb(0.8, 0.88, 1.0),
	MOON = rgb(0.55, 0.75, 1.0),
	JADE = rgb(0.25, 1.0, 0.55),
	SUN = rgb(1.0, 0.75, 0.2),
	WHITE = rgb(1, 1, 1),
	MINT = rgb(0.55, 1.0, 0.8),
	AMBER = rgb(1.0, 0.5, 0.12),
	PINK = rgb(1.0, 0.4, 0.75),
	AQUA = rgb(0.3, 0.85, 1.0),
	GOLD = rgb(1.0, 0.72, 0.15),
	LAV = rgb(0.72, 0.6, 1.0),
	VIOLET = rgb(0.6, 0.25, 1.0),
	TURQ = rgb(0.15, 1.0, 0.9),
	SAND = rgb(0.95, 0.75, 0.42),
	ROSE = rgb(1.0, 0.3, 0.5),
	SEA = rgb(0.15, 0.55, 1.0),
	LEAF = rgb(0.35, 0.9, 0.25),
	STAR = rgb(1.0, 0.88, 0.35),
	ALIEN = rgb(0.35, 1.0, 0.25),
	ELEC = rgb(0.35, 0.8, 1.0),
	YELLOW = rgb(1.0, 0.9, 0.2),
	STORM = rgb(0.55, 0.4, 1.0),
	LAVA = rgb(1.0, 0.32, 0.03),
	FIRE = rgb(1.0, 0.45, 0.08),
	FROST = rgb(0.6, 0.92, 1.0),
	EMBER = rgb(1.0, 0.25, 0.08),
	SHADOW = rgb(0.6, 0.2, 1.0),
	DIAMOND = rgb(0.45, 0.8, 1.0),
	ROCK = rgb(0.3, 0.27, 0.26),
	DARK = rgb(0.05, 0.02, 0.08),
}
Spells.RAINBOW = {
	rgb(1, 0.2, 0.2),
	rgb(1, 0.55, 0.1),
	rgb(1, 0.95, 0.2),
	rgb(0.3, 1, 0.3),
	rgb(0.2, 0.7, 1),
	rgb(0.35, 0.3, 1),
	rgb(0.85, 0.3, 1),
}

-- The Hot core look (SHANNON's pick, 2026-11-22; fxkit.HOT in the concepts): glowing balls and beams in layers, a
-- white-hot core in a coloured body in a soft glowing edge (ForceField material); glowing lines, spikes and gems with
-- a white-hot core; rings closing in on where the spell comes from as it charges; a star flash and a crisp shock ring
-- on the hit. By asset: where its charge gathers (an anchor, or "paws" between them) and in what colour. A spell not
-- listed keeps the plain look.
local C = Spells.C
Spells.HOT = {
	creature_jackal_forge = { "nose", C.AQUA },
	creature_jackal_pharaoh_forge = { "crown", C.TURQ },
	creature_jackal_sphinx_forge = { "crown", C.SAND },
	creature_tortoise_forge = { "back", C.JADE },
	creature_tortoise_gemshell_forge = { "back", C.AQUA },
	creature_tortoise_island_forge = { "chest", C.SEA },
	creature_meerkat_forge = { "paws", C.SUN },
	creature_meerkat_star_forge = { "paw_r", C.STAR },
	creature_meerkat_storm_forge = { "paw_r", C.ALIEN },
	creature_cheetah_forge = { "paw_r", C.MINT },
	creature_cheetah_lightning_forge = { "tail", C.ELEC },
	creature_cheetah_thunder_forge = { "back", C.STORM },
	creature_rhino_forge = { "horn", C.AMBER },
	creature_rhino_lava_forge = { "horn", C.LAVA },
	creature_rhino_crystal_forge = { "horn", C.DIAMOND },
	creature_flamingo_forge = { "back", C.PINK },
	creature_flamingo_peacock_forge = { "tail", C.GOLD },
	creature_lion_sahara_forge = { "nose", C.SUN },
	creature_elephant_sahara_forge = { "nose", C.SUN },
	creature_tortoise_sahara_forge = { "chest", C.SUN },
	creature_rhino_sahara_forge = { "horn", C.SUN },
} :: { [string]: { any } }
local WHITE = Color3.new(1, 1, 1)

-- Timing helpers (fxkit.py's) ------------------------------------------------------------------------------------

local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end
Spells.ease = ease

-- 0..1 through [a, b], nil outside
function Spells.seg(t: number, a: number, b: number): number?
	if t < a or t > b then
		return nil
	end
	return (t - a) / math.max(1e-6, b - a)
end

-- 0 before a, rising to 1 at b, 1 until c, falling to 0 at d
function Spells.env(t: number, a: number, b: number, c: number, d: number): number
	if t <= a or t >= d then
		return 0
	elseif t < b then
		return ease((t - a) / (b - a))
	elseif t <= c then
		return 1
	end
	return 1 - ease((t - c) / (d - c))
end

-- the quadratic curve from a through control c to b
function Spells.bez(a: Vector3, c: Vector3, b: Vector3, u: number): Vector3
	return a * (1 - u) ^ 2 + c * 2 * u * (1 - u) + b * u * u
end

function Spells.mix(a: number, b: number, u: number): number
	return a + (b - a) * u
end

function Spells.Z(z: number): Vector3
	return Vector3.new(0, z, 0)
end

-- Frames turned along lines -----------------------------------------------------------------------------------

-- x along d (a cylinder's axis)
local function along(mid: Vector3, d: Vector3): CFrame
	local x = d.Unit
	local ref = if math.abs(x.Y) < 0.95 then UP else Vector3.xAxis
	local z = x:Cross(ref).Unit
	return CFrame.fromMatrix(mid, x, z:Cross(x), z)
end

-- y along d, turned `spin` about it (a spike's axis)
local function standing(base: Vector3, d: Vector3, spin: number?): CFrame
	local y = d.Unit
	local ref = if math.abs(y.X) < 0.95 then Vector3.xAxis else Vector3.zAxis
	local x = (ref - y * ref:Dot(y)).Unit
	local frame = CFrame.fromMatrix(base, x, y, x:Cross(y))
	return if spin then frame * CFrame.Angles(0, spin, 0) else frame
end

-- The kit: pooled parts drawn afresh each frame -------------------------------------------------------------------

local SHAPES = { ball = Enum.PartType.Ball, block = Enum.PartType.Block, cyl = Enum.PartType.Cylinder }
local MAX_LIGHTS = 3 -- a spell's point lights, at most (the brightest asked for win)

type Ghost = { model: Model, bones: { { bone: Bone, turn: CFrame } }, scale: number, base: CFrame, mid: Vector3 }

type KitData = {
	folder: Folder,
	caster: Model,
	right: Vector3, -- the frame's axes, for the shapes laid in the concepts' planes
	fwd: Vector3,
	pools: { [string]: { BasePart } },
	used: { [string]: number },
	shown: { [string]: number },
	lights: { { part: Part, light: PointLight, want: number } },
	lightCount: number,
	ghosts: { [string]: Ghost },
	ghostUsed: { [string]: boolean },
	highlight: Highlight?,
	auraOn: boolean, -- (Kit.aura was called this frame)
	hot: boolean, -- drawn in the Hot core look
}

local Kit = {}
Kit.__index = Kit
export type Kit = typeof(setmetatable({} :: KitData, Kit))

local function newKit(caster: Model, right: Vector3, fwd: Vector3, hot: boolean): Kit
	local folder = Instance.new("Folder")
	folder.Name = "Spell"
	folder.Parent = Workspace
	local kit: KitData = {
		folder = folder,
		caster = caster,
		right = right,
		fwd = fwd,
		pools = {},
		used = {},
		shown = {},
		lights = {},
		lightCount = 0,
		ghosts = {},
		ghostUsed = {},
		highlight = nil,
		auraOn = false,
		hot = hot,
	}
	return setmetatable(kit, Kit)
end

function Kit.part(self: Kit, kind: string, colour: Color3, glow: number, alpha: number): BasePart
	local pool = self.pools[kind]
	if pool == nil then
		pool = {}
		self.pools[kind] = pool
	end
	local n = (self.used[kind] or 0) + 1
	self.used[kind] = n
	local p = pool[n]
	if p == nil then
		local made: BasePart
		if kind == "corner" then
			made = Instance.new("CornerWedgePart")
		elseif kind == "wedge" then
			made = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = SHAPES[kind]
			made = part
		end
		made.Anchored, made.CanCollide, made.CanQuery, made.CanTouch, made.CastShadow = true, false, false, false, false
		made.TopSurface, made.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		made.Parent = self.folder
		pool[n] = made
		p = made
	end
	p.Color = colour
	p.Material = if glow < 0
		then Enum.Material.ForceField
		elseif glow >= 1 then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	p.Transparency = 1 - math.clamp(alpha, 0, 1)
	return p
end

function Kit.begin(self: Kit)
	table.clear(self.used)
	table.clear(self.ghostUsed)
	for _, l in self.lights do
		l.want = 0
	end
	self.lightCount = 0
	self.auraOn = false
end

-- hides what this frame did not draw
function Kit.finish(self: Kit)
	for kind, pool in self.pools do
		local used = self.used[kind] or 0
		for i = used + 1, self.shown[kind] or #pool do
			pool[i].Transparency = 1
		end
		self.shown[kind] = used
	end
	for _, l in self.lights do
		l.light.Enabled = l.want > 0
	end
	for key, g in self.ghosts do
		if not self.ghostUsed[key] and g.model.Parent then
			g.model.Parent = nil
		end
	end
	if self.highlight and not self.auraOn then
		self.highlight.Enabled = false
	end
end

function Kit.destroy(self: Kit)
	self.folder:Destroy()
	for _, g in self.ghosts do
		g.model:Destroy()
	end
	if self.highlight then
		self.highlight:Destroy()
	end
end

-- -- the shapes (the concepts' fxkit.Kit, in the same order and with the same arguments) --------------------------

-- a glowing ball with a white-hot core (and a light, if `light`)
function Kit.orb(
	self: Kit,
	p: Vector3,
	r: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	core: boolean?,
	light: number?
)
	local g, a = glow or 6, alpha or 1
	if self.hot and g >= 3 and a > 0.01 then
		if core ~= false then -- a ball of energy: a white-hot core, a coloured body, a glowing edge
			local inner = self:part("ball", WHITE, g * 1.3, a)
			inner.CFrame, inner.Size = CFrame.new(p), Vector3.one * 0.84 * r
			local body = self:part("ball", colour, g, a * 0.5)
			body.CFrame, body.Size = CFrame.new(p), Vector3.one * 1.6 * r
			self:shell(p, r * 1.35, colour, a * 0.8)
		else -- a dome or a glow: its edge glows
			self:shell(p, r, colour, math.min(1, a * 1.3))
		end
	elseif core ~= false then
		local outer = self:part("ball", colour, g, a * 0.55)
		outer.CFrame, outer.Size = CFrame.new(p), Vector3.one * 2 * r
		local inner = self:part("ball", Color3.new(1, 1, 1), g * 1.6, a)
		inner.CFrame, inner.Size = CFrame.new(p), Vector3.one * r
	else
		local outer = self:part("ball", colour, g, a)
		outer.CFrame, outer.Size = CFrame.new(p), Vector3.one * 2 * r
	end
	if light and light > 0 then
		self:light(p, colour, light * r * r)
	end
end

-- a soft glowing edge round a shape (the Hot core look's): a ForceField ball
function Kit.shell(self: Kit, p: Vector3, r: number, colour: Color3, alpha: number)
	local b = self:part("ball", colour, -1, alpha)
	b.CFrame, b.Size = CFrame.new(p), Vector3.one * 2 * r
end

-- a plain ball (a rock, a puff of cloud)
function Kit.ball(self: Kit, p: Vector3, r: number, colour: Color3, glow: number?, alpha: number?)
	local b = self:part("ball", colour, glow or 0, alpha or 1)
	b.CFrame, b.Size = CFrame.new(p), Vector3.one * 2 * r
end

function Kit.spark(self: Kit, p: Vector3, r: number, colour: Color3, glow: number?, alpha: number?)
	local b = self:part("ball", colour, glow or 8, alpha or 1)
	b.CFrame, b.Size = CFrame.new(p), Vector3.one * 2 * r
end

-- sparks thrown out from p as u goes 0 -> 1, fading; the same sparks every frame (seeded)
function Kit.burst(
	self: Kit,
	p: Vector3,
	u: number?,
	n: number,
	reach: number,
	colour: Color3,
	seed: number?,
	size: number?,
	rise: number?,
	glow: number?
)
	if u == nil or u >= 1 then
		return
	end
	local rng = Random.new(seed or 1)
	local up = rise or 0.4
	for _ = 1, n do
		local d = (
			self.right * rng:NextNumber(-1, 1)
			+ self.fwd * rng:NextNumber(-1, 1)
			+ UP * (rng:NextNumber(-0.2, 1) + up)
		).Unit
		local q = p + d * reach * ease(math.min(1, u * 1.4)) * rng:NextNumber(0.5, 1) - UP * 2.5 * u * u
		self:spark(q, (size or 0.16) * (1 - 0.6 * u), colour, glow or 8, 1 - u)
	end
end

-- a box: size in the concepts' order (across, along, up), turned `yaw` about the up axis
function Kit.box(self: Kit, p: Vector3, size: { number }, colour: Color3, glow: number?, alpha: number?, yaw: number?)
	local b = self:part("block", colour, glow or 0, alpha or 1)
	local x, back = -self.right, -self.fwd -- the concepts' x and y
	if yaw and yaw ~= 0 then
		x, back = x * math.cos(yaw) + back * math.sin(yaw), back * math.cos(yaw) - x * math.sin(yaw)
	end
	b.CFrame = CFrame.fromMatrix(p, x, UP, x:Cross(UP))
	b.Size = Vector3.new(size[1], size[3], size[2])
end

-- a cylinder from a to b (and a white core in it)
function Kit.beam(
	self: Kit,
	a: Vector3,
	b: Vector3,
	r: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	core: boolean?
)
	local d = b - a
	local n = d.Magnitude
	if n < 1e-4 then
		return
	end
	local g, al = glow or 6, alpha or 1
	local frame = along((a + b) / 2, d)
	if self.hot and g >= 3 then -- a white-hot core, a coloured body, a glowing edge
		local inner = self:part("cyl", WHITE, g * 1.3, al)
		inner.CFrame, inner.Size = frame, Vector3.new(n, 0.64 * r, 0.64 * r)
		local body = self:part("cyl", colour, g, al * 0.5)
		body.CFrame, body.Size = frame, Vector3.new(n, 1.5 * r, 1.5 * r)
		local edge = self:part("cyl", colour, -1, al * 0.8)
		edge.CFrame, edge.Size = frame, Vector3.new(n, 2.6 * r, 2.6 * r)
		return
	end
	local outer = self:part("cyl", colour, g, al * (if core ~= false then 0.5 else 1))
	outer.CFrame, outer.Size = frame, Vector3.new(n, 2 * r, 2 * r)
	if core ~= false then
		local inner = self:part("cyl", Color3.new(1, 1, 1), g * 1.5, al)
		inner.CFrame, inner.Size = frame, Vector3.new(n, 0.8 * r, 0.8 * r)
	end
end

-- a four-sided spike from its base to its tip: four corner wedges, their tall corners together
local function pyramid(
	kit: Kit,
	base: Vector3,
	tip: Vector3,
	r: number,
	colour: Color3,
	glow: number,
	alpha: number,
	spin: number?
)
	local d = tip - base
	local h = d.Magnitude
	if h < 1e-4 or r < 1e-3 then
		return
	end
	local w = 1.8 * r
	local stem = standing(base, d, spin)
	for k = 0, 3 do
		local c = kit:part("corner", colour, glow, alpha)
		c.Size = Vector3.new(w / 2, h, w / 2)
		-- a corner wedge's tall corner is at +x, -z
		c.CFrame = stem * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(-w / 4, h / 2, w / 4)
	end
end

function Kit.spike(self: Kit, base: Vector3, tip: Vector3, r: number, colour: Color3, glow: number?, alpha: number?)
	pyramid(self, base, tip, r, colour, glow or 0, alpha or 1)
	if self.hot and (glow or 0) >= 4 then
		pyramid(self, base, base:Lerp(tip, 0.75), r * 0.38, WHITE, (glow or 0) * 1.3, alpha or 1)
	end
end

-- a flat triangle `thick` thick: two wedges (the concepts' filled shapes, as a fan of them)
function Kit.triangle(
	self: Kit,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	colour: Color3,
	glow: number?,
	alpha: number?,
	thick: number?
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then -- the longest side goes to bc
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local n = ac:Cross(ab)
	if n.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return
	end
	local right = n.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w = thick or 0.1
	local w1 = self:part("wedge", colour, glow or 0, alpha or 1)
	w1.Size = Vector3.new(w, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	local w2 = self:part("wedge", colour, glow or 0, alpha or 1)
	w2.Size = Vector3.new(w, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

-- a diamond: two spikes base to base, r across and h tall, along `axis` (up if none), turned `spin` about it
function Kit.diamond(
	self: Kit,
	p: Vector3,
	r: number,
	h: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	spin: number?,
	axis: Vector3?
)
	local d = (axis or UP).Unit * h / 2
	pyramid(self, p, p + d, r, colour, glow or 4, alpha or 1, spin)
	pyramid(self, p, p - d, r, colour, glow or 4, alpha or 1, spin)
	if self.hot and (glow or 4) >= 4 then
		pyramid(self, p, p + d * 0.6, r * 0.45, WHITE, (glow or 4) * 1.3, alpha or 1, spin)
		pyramid(self, p, p - d * 0.6, r * 0.45, WHITE, (glow or 4) * 1.3, alpha or 1, spin)
	end
end

-- a round tube along points (radius r, or r * taper(i / (n - 1)) along it); hot, a white core runs inside
function Kit.tube(
	self: Kit,
	pts: { Vector3 },
	r: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	closed: boolean?,
	taper: ((number) -> number)?
)
	self:rawTube(pts, r, colour, glow, alpha, closed, taper)
	if self.hot and (glow or 4) >= 4 and (alpha or 1) > 0.05 then
		self:rawTube(pts, r * 0.38, WHITE, (glow or 4) * 1.3, math.min(1, (alpha or 1) * 1.2), closed, taper)
	end
end

function Kit.rawTube(
	self: Kit,
	pts: { Vector3 },
	r: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	closed: boolean?,
	taper: ((number) -> number)?
)
	local n = #pts
	if n < 2 then
		return
	end
	local g, a = glow or 4, alpha or 1
	local last = if closed then n else n - 1
	for i = 1, last do
		local p, q = pts[i], pts[i % n + 1]
		local d = q - p
		local len = d.Magnitude
		if len > 1e-4 then
			local rr = r * (if taper then taper((i - 0.5) / math.max(1, n - 1)) else 1)
			if rr > 1e-3 then
				local c = self:part("cyl", colour, g, a)
				c.CFrame = along((p + q) / 2, d)
				c.Size = Vector3.new(len + math.min(rr, len * 0.5), 2 * rr, 2 * rr) -- overlapping at the joints
			end
		end
	end
end

-- a ring of radius R round `normal` (up), w thick, the whole way round or over `arc` = { from, to } (radians)
function Kit.ring(
	self: Kit,
	p: Vector3,
	R: number,
	w: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	normal: Vector3?,
	arc: { number }?,
	n: number?
)
	local nrm = (normal or UP).Unit
	local x = -self.right -- the concepts' x
	local a = nrm:Cross(if math.abs(nrm:Dot(x)) < 0.9 then x else -self.fwd).Unit
	local b = nrm:Cross(a)
	local a0, a1 = if arc then arc[1] else 0, if arc then arc[2] else TAU
	local closed = math.abs(a1 - a0 - TAU) < 1e-3
	local count = math.min(n or 24, 24)
	local steps = if closed then count else math.max(3, math.floor(count * (a1 - a0) / TAU) + 1)
	local pts = {}
	for i = 0, if closed then steps - 1 else steps do
		local ang = a0 + (a1 - a0) * i / steps
		table.insert(pts, p + (a * math.cos(ang) + b * math.sin(ang)) * R)
	end
	self:tube(
		pts,
		w,
		colour,
		glow or 5,
		alpha,
		closed,
		if closed
			then nil
			else function(u: number)
				return math.sin(math.pi * u) ^ 0.6 + 0.05
			end
	)
end

-- a flat disc on the ground
function Kit.disc(
	self: Kit,
	p: Vector3,
	R: number,
	colour: Color3,
	glow: number?,
	alpha: number?,
	_n: number?,
	lift: number?
)
	local d = self:part("cyl", colour, glow or 2, alpha or 0.6)
	d.CFrame = CFrame.new(p + UP * (lift or 0.03)) * CFrame.Angles(0, 0, math.pi / 2)
	d.Size = Vector3.new(0.06, 2 * R, 2 * R)
end

-- a magic circle on the ground: two rings, runes between them, spokes
function Kit.circle(
	self: Kit,
	p: Vector3,
	R: number,
	colour: Color3,
	spin: number,
	glow: number?,
	alpha: number?,
	spokes: number?
)
	local g, a, s = glow or 6, alpha or 1, spokes or 8
	p += UP * 0.05
	self:ring(p, R, 0.07 * R, colour, g, a)
	self:ring(p, R * 0.72, 0.05 * R, colour, g, a)
	local x, y = -self.right, -self.fwd
	for k = 0, s - 1 do
		local ang = spin + k / s * TAU
		local d = x * math.cos(ang) + y * math.sin(ang)
		self:box(p + d * R * 0.86, { 0.14 * R, 0.05 * R, 0.03 * R }, colour, g, a, ang)
		local a2 = -spin * 0.7 + (k + 0.5) / s * TAU
		local d2 = x * math.cos(a2) + y * math.sin(a2)
		self:tube({ p + d2 * R * 0.18, p + d2 * R * 0.7 }, 0.025 * R, colour, g, a * 0.8)
	end
end

-- a crescent blade: an arc of 220 degrees round `normal` whose middle points along `facing`
function Kit.crescent(
	self: Kit,
	p: Vector3,
	R: number,
	w: number,
	colour: Color3,
	normal: Vector3,
	facing: Vector3,
	glow: number?,
	alpha: number?
)
	local nrm = normal.Unit
	local face = (facing - nrm * facing:Dot(nrm)).Unit
	local side = nrm:Cross(face)
	local pts = {}
	for i = 0, 12 do
		local ang = -1.9 + 3.8 * i / 12
		table.insert(pts, p + (face * math.cos(ang) + side * math.sin(ang)) * R)
	end
	self:tube(pts, w, colour, glow or 6, alpha, false, function(u: number)
		return math.sin(math.pi * u) ^ 0.7 + 0.03
	end)
end

-- a jagged bolt from a to b: a white core in a coloured sheath, with `fork` short branches
function Kit.bolt(
	self: Kit,
	a: Vector3,
	b: Vector3,
	colour: Color3,
	r: number?,
	jag: number?,
	n: number?,
	seed: number?,
	glow: number?,
	alpha: number?,
	fork: number?
)
	local rr, jj, nn, g, al = r or 0.12, jag or 0.18, n or 9, glow or 10, alpha or 1
	local rng = Random.new(seed or 1)
	local d = b - a
	if d.Magnitude < 1e-4 then
		return
	end
	local side = d:Cross(if math.abs(d.Unit:Dot(UP)) < 0.9 then UP else Vector3.xAxis).Unit
	local up = side:Cross(d.Unit).Unit
	local pts = { a }
	for i = 1, nn - 1 do
		local off = (side * rng:NextNumber(-1, 1) + up * rng:NextNumber(-1, 1)) * jj * d.Magnitude
		table.insert(pts, a + d * (i / nn) + off)
	end
	table.insert(pts, b)
	self:tube(pts, rr, Color3.new(1, 1, 1), g * 1.4, al)
	self:tube(pts, rr * 2.6, colour, g, al * 0.45)
	for k = 1, fork or 0 do
		local i = rng:NextInteger(3, nn - 1)
		local dir = (side * rng:NextNumber(-1, 1) + up * rng:NextNumber(-0.6, 0.6) + d.Unit * 0.5).Unit
		self:bolt(pts[i], pts[i] + dir * d.Magnitude * 0.25, colour, rr * 0.6, jj, 4, (seed or 1) + 7 * k, g, al, 0)
	end
end

-- a flat ribbon through pts (newest first) facing the camera, thinning toward its end; hot, a white streak in it
function Kit.trail(self: Kit, pts: { Vector3 }, w: number, colour: Color3, glow: number?, alpha: number?)
	self:rawTrail(pts, w, colour, glow, alpha)
	if self.hot and (glow or 4) >= 4 then
		self:rawTrail(pts, w * 0.3, WHITE, (glow or 4) * 1.3, math.min(1, (alpha or 0.6) * 1.4))
	end
end

function Kit.rawTrail(self: Kit, pts: { Vector3 }, w: number, colour: Color3, glow: number?, alpha: number?)
	local n = #pts
	if n < 2 then
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else pts[1] + UP * 20
	for i = 1, n - 1 do
		local p, q = pts[i], pts[i + 1]
		local d = p - q
		local len = d.Magnitude
		if len > 1e-4 then
			local mid = (p + q) / 2
			local x = d.Unit
			local view = eye - mid
			local z = (view - x * view:Dot(x))
			z = if z.Magnitude > 1e-4 then z.Unit else x:Cross(UP).Unit
			local width = 2 * w * (1 - (i - 0.5) / n)
			local s = self:part("block", colour, glow or 4, alpha or 0.6)
			s.CFrame = CFrame.fromMatrix(mid, x, z:Cross(x), z)
			s.Size = Vector3.new(len + 0.05, math.max(0.05, width), 0.05)
		end
	end
end

-- n strands winding up round p, R wide at the top and H tall, turning with t
function Kit.vortex(
	self: Kit,
	p: Vector3,
	R: number,
	H: number,
	colour: Color3,
	t: number,
	n: number?,
	glow: number?,
	alpha: number?,
	turns: number?,
	w: number?
)
	local x, y = -self.right, -self.fwd
	local strands = n or 4
	for k = 0, strands - 1 do
		local pts = {}
		for i = 0, 13 do
			local u = i / 13
			local ang = t * 9 + k / strands * TAU + u * (turns or 1.6) * TAU
			local rr = R * (0.35 + 0.65 * u)
			table.insert(pts, p + (x * math.cos(ang) + y * math.sin(ang)) * rr + UP * u * H)
		end
		self:tube(pts, w or 0.12, colour, glow or 4, alpha or 0.6, false, function(u: number)
			return 0.3 + 0.7 * math.sin(math.pi * u)
		end)
	end
end

-- a cloud of nine puffs
function Kit.cloud(self: Kit, p: Vector3, R: number, colour: Color3, seed: number?, alpha: number?, glow: number?)
	local rng = Random.new(seed or 1)
	local x, y = -self.right, -self.fwd
	for _ = 1, 9 do
		local q = p + (x * rng:NextNumber(-1, 1) + y * rng:NextNumber(-0.6, 0.6) + UP * rng:NextNumber(-0.25, 0.3)) * R
		self:ball(q, R * rng:NextNumber(0.35, 0.6), colour, glow or 0.3, alpha or 1)
	end
end

-- a closed ring for the Hot core look's own rings (no core of its own)
function Kit.rawRing(
	self: Kit,
	p: Vector3,
	R: number,
	w: number,
	colour: Color3,
	glow: number,
	alpha: number,
	normal: Vector3
)
	local nrm = normal.Unit
	local a = nrm:Cross(if math.abs(nrm.X) < 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
	local b = nrm:Cross(a)
	local pts = {}
	for i = 0, 23 do
		local ang = i / 24 * TAU
		table.insert(pts, p + (a * math.cos(ang) + b * math.sin(ang)) * R)
	end
	self:rawTube(pts, w, colour, glow, alpha, true)
end

-- an impact flash: thin streaks out from p, facing the camera, long and short in turn
function Kit.star(self: Kit, p: Vector3, R: number, colour: Color3, alpha: number)
	if alpha <= 0.01 then
		return
	end
	local camera = Workspace.CurrentCamera
	local view = ((if camera then camera.CFrame.Position else p + UP * 20) - p).Unit
	local a = view:Cross(if math.abs(view.X) < 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
	local b = view:Cross(a)
	for i = 0, 7 do
		local ang = 0.3 + i / 8 * TAU
		local d = a * math.cos(ang) + b * math.sin(ang)
		local L = R * (if i % 2 == 0 then 1 else 0.5)
		pyramid(self, p, p + d * L, 0.05 * R, WHITE, 11, alpha)
		pyramid(self, p, p + d * L * 0.85, 0.11 * R, colour, 7, 0.55 * alpha)
	end
end

-- a crisp shock ring: a bright leading edge with a fainter wash behind it
function Kit.shock(self: Kit, p: Vector3, R: number, w: number, colour: Color3, alpha: number)
	if alpha <= 0.01 then
		return
	end
	self:rawRing(p, R, w, WHITE, 9, alpha, UP)
	self:rawRing(p, R * 0.94, w * 2, colour, 6, 0.55 * alpha, UP)
	self:rawRing(p, R * 0.8, w * 0.7, colour, 4, 0.25 * alpha, UP)
end

-- rings closing in on p as it charges (u 0 -> 1), facing the camera
function Kit.converge(self: Kit, p: Vector3, R: number, colour: Color3, u: number?)
	if u == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	local view = (if camera then camera.CFrame.Position else p + UP * 20) - p
	for i = 0, 2 do
		local v = (u * 2.2 + i / 3) % 1
		self:rawRing(p, R * (1 - v) + 0.05, 0.05 * R * (0.6 + v), colour, 7, v * 0.9, view)
	end
end

-- a point light (the concepts' energy, roughly); only the MAX_LIGHTS brightest of a frame are lit
function Kit.light(self: Kit, p: Vector3, colour: Color3, energy: number)
	if energy <= 0 then
		return
	end
	local slot
	if self.lightCount < MAX_LIGHTS then
		self.lightCount += 1
		slot = self.lights[self.lightCount]
		if slot == nil then
			local part = Instance.new("Part")
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.Transparency, part.Size = 1, Vector3.one * 0.2
			local light = Instance.new("PointLight")
			light.Shadows = false
			light.Parent = part
			part.Parent = self.folder
			slot = { part = part, light = light, want = 0 }
			self.lights[self.lightCount] = slot
		end
	else
		for _, l in self.lights do -- the dimmest gives way
			if slot == nil or l.want < slot.want then
				slot = l
			end
		end
		if slot == nil or slot.want >= energy then
			return
		end
	end
	slot.want = energy
	slot.part.CFrame = CFrame.new(p)
	slot.light.Color = colour
	slot.light.Range = math.clamp(6 + 3 * math.sqrt(energy), 6, 40)
	slot.light.Brightness = math.clamp(0.4 * energy, 0.5, 4)
end

-- the joint's pose as a transform in the Root's axes (Creatures.client's `turned`)
local function turned(v: { number }, scale: number): CFrame
	return CFrame.new((v[4] or 0) * scale, (v[5] or 0) * scale, (v[6] or 0) * scale)
		* CFrame.Angles(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
end

-- a see-through copy of the animal (`key` names it, so it is the same copy from frame to frame) in `pose`, moved by
-- `offset`, scaled by `scale` and turned `yaw` about its middle
function Kit.ghost(
	self: Kit,
	key: string,
	pose: { [string]: { number } },
	offset: Vector3,
	colour: Color3,
	_glow: number?,
	alpha: number?,
	scale: number?,
	yaw: number?
)
	local g = self.ghosts[key]
	local caster = self.caster
	if g == nil then
		local root = caster.PrimaryPart
		if root == nil then
			return
		end
		local copy = caster:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
				if d.Name == "Hit" or d.Transparency >= 1 then
					d.Transparency = 1
				else
					d.Material = Enum.Material.Neon
				end
			elseif d:IsA("SurfaceAppearance") or d:IsA("Highlight") or d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		end
		for _, d in { copy :: Instance, table.unpack(copy:GetDescendants()) } do -- no creature the game would take up
			for _, tag in d:GetTags() do
				d:RemoveTag(tag)
			end
		end
		local bones = {}
		local base = copy.PrimaryPart or root
		for _, d in copy:GetDescendants() do
			if d:IsA("Bone") then
				d.Transform = CFrame.identity
				table.insert(bones, { bone = d, turn = base.CFrame.Rotation:Inverse() * d.WorldCFrame.Rotation })
			end
		end
		g = {
			model = copy,
			bones = bones,
			scale = copy:GetScale(),
			base = caster:GetPivot(),
			mid = caster:GetBoundingBox().Position,
		}
		self.ghosts[key] = g
	end
	local ghost = g :: Ghost
	self.ghostUsed[key] = true
	local s = scale or 1
	if math.abs(ghost.model:GetScale() - ghost.scale * s) > 1e-3 then
		ghost.model:ScaleTo(ghost.scale * s)
	end
	local turn = CFrame.Angles(0, yaw or 0, 0)
	local at = ghost.mid + offset + turn * ((ghost.base.Position - ghost.mid) * s)
	ghost.model:PivotTo(CFrame.new(at) * turn * ghost.base.Rotation)
	local unit = ((caster:GetAttribute("Scale") :: number?) or 1) * s
	for _, b in ghost.bones do
		local v = pose[b.bone.Name]
		b.bone.Transform = if v then b.turn:Inverse() * turned(v, unit) * b.turn else CFrame.identity
	end
	local a = 1 - math.clamp((alpha or 0.4) * 1.4, 0, 0.85)
	for _, d in ghost.model:GetChildren() do
		if d:IsA("MeshPart") and d.Name ~= "Hit" and d.Transparency < 1 then
			d.Color, d.Transparency = colour, a
		end
	end
	if ghost.model.Parent == nil then
		ghost.model.Parent = self.folder
	end
end

-- the animal outlined and lit in a colour (a Highlight)
function Kit.aura(self: Kit, colour: Color3, alpha: number?, _glow: number?, _grow: number?)
	local a = alpha or 0.3
	if a <= 0.01 then
		return
	end
	local h = self.highlight
	if h == nil then
		local made = Instance.new("Highlight")
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Adornee = self.caster
		made.Parent = self.folder
		self.highlight = made
		h = made
	end
	local hl = h :: Highlight
	self.auraOn = true
	hl.Enabled = true
	hl.FillColor, hl.OutlineColor = colour, colour
	hl.FillTransparency = 1 - math.clamp(a * 1.6, 0, 0.7)
	hl.OutlineTransparency = 1 - math.clamp(a * 3, 0, 1)
end

-- Frames ------------------------------------------------------------------------------------------------------------

export type Frame = {
	t: number, -- seconds into the clip
	kit: Kit,
	model: Model,
	A: { [string]: Vector3 }, -- the anchors (AnimalRig): nose, crown, horn, trunk, paw_l/r, wing_l/r, tail, back, chest
	T: Vector3, -- the ground under the target
	TC: Vector3, -- the target's middle
	mid: Vector3, -- the animal's middle at rest
	H: number, -- its height and length, studs
	L: number,
	k: number, -- the effects' size for this animal
	sky: number, -- how high over the target the sky effects go
	fwd: Vector3, -- towards the target, level
	right: Vector3,
	V: (x: number, y: number, z: number) -> Vector3, -- a concept's offset (x its left, y backwards, z up)
}

local ALL: { [string]: (Frame) -> () } = {} -- filled at the end, from the spell modules

-- A model's spell, or (`strike`) the effects of its regular attack: a spell module's "<asset>@attack" entry
local function drawOf(model: Model, strike: boolean?): ((Frame) -> ())?
	local asset = model:GetAttribute("Asset")
	if type(asset) ~= "string" then
		return nil
	end
	if strike then
		return ALL[asset .. "@attack"]
	end
	return ALL[asset] or ALL[string.match(asset, "^creature_(%l+)") or ""]
end

type Cast = { at: number, frame: Frame, warned: boolean }
local casts: { [Model]: Cast } = {}

local function point(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

-- How big `model` stands over its built size (AnimalRig's measures are at the built size). Model:GetScale() will not
-- do: it also holds the importer's unit, about 0.01 on these models, which drew every spell at its smallest and put
-- every anchor on its bone (seen in Studio, STATION-145). The Hit box is the built size times the creature's own.
local function grown(model: Model, data: AnimalRig.Model): number
	local hit = model:FindFirstChild("Hit")
	return if hit and hit:IsA("BasePart") then hit.Size.Y / data.size[2] else 1
end

local function begin(model: Model, at: number, bones: { [string]: { bone: Bone, turn: CFrame } }): Cast?
	local root = model.PrimaryPart
	local data = AnimalRig.MODELS[(model:GetAttribute("Asset") :: string?) or ""]
	if root == nil or data == nil then
		return nil
	end
	local size = grown(model, data)
	local H, L = data.size[2] * size, data.size[3] * size
	local aim = model:GetAttribute("AimAt") -- the ground under the target (WaveShow sets it)
	local look = if typeof(aim) == "Vector3" then aim - root.CFrame.Position else root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	local fwd = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local right = fwd:Cross(UP)
	local T = if typeof(aim) == "Vector3"
		then aim
		else root.CFrame.Position + fwd * (L / 2 + math.max(0.55 * L, 1.1 * H, 6))
	local height = (model:GetAttribute("AimHeight") :: number?) or 5.2
	local body = bones.body
	local mid = if body
		then body.bone.WorldCFrame.Position + root.CFrame.Rotation * (point(data.mid) * size)
		else root.CFrame.Position + UP * H / 2
	local frame: Frame = {
		t = 0,
		kit = newKit(model, right, fwd, Spells.HOT[(model:GetAttribute("Asset") :: string?) or ""] ~= nil),
		model = model,
		A = {},
		T = T,
		TC = T + UP * math.clamp(height / 2, 1.5, 8),
		mid = mid,
		H = H,
		L = L,
		k = math.clamp(math.max(H, 0.6 * L) / 7, 1, 3),
		sky = if H < 10 then math.max(H, 5) * 1.7 else H * 1.1,
		fwd = fwd,
		right = right,
		V = function(x: number, y: number, z: number): Vector3
			return -right * x - fwd * y + UP * z
		end,
	}
	return { at = at, frame = frame, warned = false }
end

-- where each anchor is now: its rest offset carried by its bone as posed
local function anchor(cast: Cast, model: Model, bones: { [string]: { bone: Bone, turn: CFrame } })
	local f = cast.frame
	local data = AnimalRig.MODELS[(model:GetAttribute("Asset") :: string?) or ""]
	local root = model.PrimaryPart
	if data == nil or root == nil then
		return
	end
	-- a bone's `turn` is its rest frame in the Root's axes; its WorldCFrame will not do, as that already holds its
	-- parents' poses (as FoePowers)
	local size = grown(model, data)
	for name, a in data.anchors do
		local b = bones[a[1]]
		if b then
			local now = b.bone.TransformedWorldCFrame
			f.A[name] = now.Position + now.Rotation * (b.turn:Inverse() * (point(a[2]) * size))
		else
			f.A[name] = f.mid
		end
	end
end

-- Draws `model`'s spell at `t` seconds into the "magic" clip that started at `at`. False if it has none (the shared
-- charge and slam play instead).
function Spells.step(
	model: Model,
	bones: { [string]: { bone: Bone, turn: CFrame } },
	at: number,
	t: number,
	strike: boolean?
): boolean
	local draw = drawOf(model, strike)
	if draw == nil then
		Spells.stop(model) -- (a spell still showing when a plain attack starts)
		return false
	end
	local cast = casts[model]
	if cast == nil or cast.at ~= at then
		Spells.stop(model)
		cast = begin(model, at, bones)
		if cast == nil then
			return false
		end
		casts[model] = cast
	end
	local c = cast :: Cast
	c.frame.t = t
	anchor(c, model, bones)
	c.frame.kit:begin()
	local hot = if strike then nil else Spells.HOT[(model:GetAttribute("Asset") :: string?) or ""]
	local ok, err = pcall(function()
		local f = c.frame
		draw(f)
		if hot then -- rings close in on where it casts from as it charges
			local from = if hot[1] == "paws" then (f.A.paw_l + f.A.paw_r) / 2 + UP * 0.5 * f.k else f.A[hot[1]]
			f.kit:converge(from, 2.4 * f.k, hot[2], Spells.seg(t, 0.25, 0.84))
		end
	end)
	c.frame.kit:finish()
	if not ok and not c.warned then
		c.warned = true
		warn(`[Spells] {model:GetAttribute("Asset")}: {err}`)
	end
	return true
end

function Spells.stop(model: Model)
	local cast = casts[model]
	if cast then
		casts[model] = nil
		cast.frame.kit:destroy()
	end
end

function Spells.has(model: Model): boolean
	return drawOf(model) ~= nil
end

-- Shared pieces of the spells (magic.py's) ----------------------------------------------------------------------------

-- the hit at the target: a flash, a ring rolling out on the ground, sparks
function Spells.impact(f: Frame, colour: Color3, R: number?, seed: number?, ring: boolean?, flash: boolean?)
	local u = Spells.seg(f.t, Spells.IMPACT, Spells.IMPACT + 0.5)
	if u == nil then
		return
	end
	local k = f.kit
	if k.hot then -- a star flash and crisp rings
		if flash ~= false then
			k:star(f.TC, 4 * f.k * (0.6 + 0.4 * ease(math.min(1, u * 4))), colour, (1 - u) ^ 1.5)
			k:light(f.TC, colour, 8 * (1 - u) * f.k * f.k)
		end
		if ring ~= false then
			k:shock(f.T + UP * 0.08, (0.6 + (R or 3) * 1.4 * ease(u)) * f.k, 0.09 * f.k, colour, 1 - u)
		end
		k:burst(f.TC, u, 12, 4 * f.k, colour, seed or 1, 0.12 * f.k)
		return
	end
	if flash ~= false then
		k:orb(f.TC + f.V(0, 0.6, 0) * f.k, (0.4 + ease(math.min(1, u * 3))) * f.k, colour, 6, 0.75 * (1 - u) ^ 2)
		k:light(f.TC, colour, 8 * (1 - u) * f.k * f.k)
	end
	if ring ~= false then
		k:ring(f.T + UP * 0.1, (0.5 + (R or 3) * ease(u)) * f.k, 0.12 * f.k, colour, 6, 1 - u)
	end
	k:burst(f.TC, u, 16, 4 * f.k, colour, seed or 1, 0.14 * f.k)
end

-- something drawn along a curve from a to b (arching `height` up) between t0 and t1, with a trail behind it
function Spells.flight(
	f: Frame,
	a: Vector3,
	b: Vector3,
	t0: number,
	t1: number,
	height: number,
	drawAt: (Vector3, number) -> (),
	trail: { any }?,
	n: number?
): Vector3?
	local u = Spells.seg(f.t, t0, t1)
	if u == nil then
		return nil
	end
	local c = (a + b) / 2 + UP * height
	local p = Spells.bez(a, c, b, u)
	drawAt(p, u)
	if trail then
		local pts = {}
		for i = 0, (n or 8) - 1 do
			table.insert(pts, Spells.bez(a, c, b, math.max(0, u - i * 0.03)))
		end
		f.kit:trail(pts, trail[2], trail[1], 4, 0.55)
	end
	return p
end

-- the point under p on the target's ground
function Spells.ground(f: Frame, p: Vector3): Vector3
	return Vector3.new(p.X, f.T.Y, p.Z)
end

-- each spell module returns function(Spells) -> { [species or asset] = draw }
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		for key, draw in (require(child) :: any)(Spells) do
			assert(ALL[key] == nil, `two spells for {key}`)
			ALL[key] = draw
		end
	end
end

return Spells
