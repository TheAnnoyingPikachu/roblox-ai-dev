--!strict
-- Hundred Demon Night enemies (GDD D, docs/architecture/night.md 4.4). Each enemy is a pure
-- WaveRules.Enemy record plus a server-owned part model (at most 15 parts, no Humanoid) moved by
-- AlignPosition and AlignOrientation. WaveRules decides stats, composition, targeting and
-- stuck relocation; BossRules decides the Gashadokuro's pattern. This file only moves models,
-- times telegraphs and reports which players an attack reached (`Hurt`); RunRules applies damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossRules = require(Shared:WaitForChild("BossRules"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local WaveRules = require(Shared:WaitForChild("WaveRules"))
local Models = require(script.Parent:WaitForChild("Models"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Vec3 = CombatRules.Vec3
type Enemy = WaveRules.Enemy

export type Hurt = { userId: number, amount: number, key: string }

local Enemies = {}

local MAX_ALIVE = 32 -- GDD I2 budget, summons included
local LAUNCH_HEIGHT = 10
local PLAYER_ROOT = 3 -- an R15 root stands about 3 studs above the ground
local PIT = Vector3.new(0, 0, -65)
local BEHAVIOUR = WaveRules.BEHAVIOUR
local HOVER: { [string]: number } = { wisp = BEHAVIOUR.wisp.hover, lantern = 5, kasa = 3, oni = 4.5, general = 7 }
type Slam = { range: number, radius: number, telegraph: number, period: number }
local SLAMS: { [string]: Slam } = { oni = BEHAVIOUR.oni, general = BEHAVIOUR.general }

local function vec(v: Vector3): Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function v3(v: Vec3): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Top of the walkable surface: the kagura stage is 4 studs high (GDD I1), the courtyard is 0.
local function groundAt(x: number, z: number): number
	return if math.abs(x) <= 16 and math.abs(z) <= 16 then 4 else 0
end

local folder = Instance.new("Folder")
folder.Name = "NightEnemies"
folder.Parent = Workspace

-- Mob models ---------------------------------------------------------------------------------

type Body = { model: Model, root: Part, align: AlignPosition, orient: AlignOrientation }

type Pending = { kind: string, key: string, from: Vector3, to: Vector3 }
type Dash = { key: string, to: Vector3, endsAt: number, hit: { [number]: boolean } }

type Mob = {
	e: Enemy,
	body: Body,
	hover: number,
	attacks: number, -- attack instances so far, for Hurt keys
	pending: Pending?, -- telegraphed attack, lands at e.telegraphUntil
	dash: Dash?, -- kasa dash in flight
	knockUntil: number,
	knockTo: Vector3,
	knockSpeed: number,
	launchY: number,
	summonAt: number,
	contactAt: { [number]: number },
	last: Vector3,
}

local mobs: { [number]: Mob } = {}
local nextId = 0

local function piece(
	model: Model,
	root: BasePart,
	size: Vector3,
	offset: CFrame,
	colour: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = root.CFrame * offset
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along x; this stands them up

local function light(parent: BasePart, colour: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

-- Meshes the warm-up below has loaded. Spawns inside the tick use only these, so a mesh still
-- loading or failed falls back to parts at once instead of yielding the tick (QA m8).
local warmed: { [string]: boolean } = {}

local function warmSpawn(name: string, parent: Instance, base: Vector3, scale: number): MeshPart?
	return if warmed[name] then Models.spawn(name, parent, base, scale) else nil
end

-- Attaches a generated mesh to the root, or returns nil so the caller builds its part fallback.
local function meshOn(model: Model, root: BasePart, name: string, scale: number, offset: CFrame): MeshPart?
	local mesh = warmSpawn(name, model, root.Position, scale)
	if mesh == nil then
		return nil
	end
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Massless = true
	mesh.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = mesh
	weld.Parent = mesh
	return mesh
end

local INK = Color3.fromRGB(25, 20, 28)
local PAPER = Color3.fromRGB(245, 232, 200)
local LACQUER = Color3.fromRGB(120, 22, 26)
local GOLD = Color3.fromRGB(220, 175, 60)
local EMBER = Color3.fromRGB(255, 60, 40)

local function eye(model: Model, root: BasePart, offset: CFrame, size: number)
	piece(model, root, Vector3.one * size, offset, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(
		model,
		root,
		Vector3.one * size * 0.45,
		offset * CFrame.new(0, 0, -size * 0.4),
		INK,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
end

local BUILD: { [string]: (Model, Part) -> () } = {
	-- Hitodama: blue-white flame ball with fire and a trail (D1).
	wisp = function(model, root)
		local core = piece(
			model,
			root,
			Vector3.one * 2.2,
			CFrame.identity,
			Color3.fromRGB(200, 235, 255),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local shell = piece(
			model,
			root,
			Vector3.one * 3,
			CFrame.identity,
			Color3.fromRGB(90, 160, 255),
			Enum.Material.ForceField,
			Enum.PartType.Ball
		)
		shell.Transparency = 0.3
		local fire = Instance.new("Fire")
		fire.Color = Color3.fromRGB(110, 180, 255)
		fire.SecondaryColor = Color3.fromRGB(220, 245, 255)
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = core
		light(core, Color3.fromRGB(130, 190, 255), 10, 1.5)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.8, 0), Vector3.new(0, -0.8, 0)
		a0.Parent, a1.Parent = core, core
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = core
	end,

	-- Chōchin-obake: the generated lantern-yokai mesh, or a paper lantern of parts with one eye and a tongue.
	lantern = function(model, root)
		if meshOn(model, root, "lanternYokai", 0.75, CFrame.identity) == nil then
			piece(model, root, Vector3.new(4.6, 3.8, 3.8), UPRIGHT, PAPER, Enum.Material.Fabric, Enum.PartType.Cylinder)
			for _, y in { -1.2, 0, 1.2 } do
				piece(
					model,
					root,
					Vector3.new(0.25, 4, 4),
					CFrame.new(0, y, 0) * UPRIGHT,
					LACQUER,
					Enum.Material.Wood,
					Enum.PartType.Cylinder
				)
			end
			piece(
				model,
				root,
				Vector3.new(0.6, 2.2, 2.2),
				CFrame.new(0, 2.6, 0) * UPRIGHT,
				INK,
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			)
			eye(model, root, CFrame.new(0, 0.6, -1.8), 1.4)
			piece(
				model,
				root,
				Vector3.new(0.7, 0.2, 2.4),
				CFrame.new(0, -1, -2.6) * CFrame.Angles(math.rad(-25), 0, 0),
				Color3.fromRGB(220, 40, 60)
			)
		end
		light(root, Color3.fromRGB(255, 150, 60), 14, 2)
	end,

	-- Kasa-obake: paper umbrella of stacked discs, one leg, one eye; it hops.
	kasa = function(model, root)
		local red = Color3.fromRGB(200, 45, 40)
		piece(
			model,
			root,
			Vector3.new(0.5, 5.4, 5.4),
			CFrame.new(0, 1.2, 0) * UPRIGHT,
			red,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		piece(
			model,
			root,
			Vector3.new(0.6, 3.6, 3.6),
			CFrame.new(0, 1.7, 0) * UPRIGHT,
			PAPER,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		piece(
			model,
			root,
			Vector3.new(0.7, 1.8, 1.8),
			CFrame.new(0, 2.2, 0) * UPRIGHT,
			red,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		piece(
			model,
			root,
			Vector3.new(0.9, 0.5, 0.5),
			CFrame.new(0, 2.8, 0) * UPRIGHT,
			INK,
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		piece(
			model,
			root,
			Vector3.new(2.6, 0.4, 0.4),
			CFrame.new(0, -0.3, 0) * UPRIGHT,
			Color3.fromRGB(140, 100, 60),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		piece(model, root, Vector3.new(0.9, 0.5, 1.6), CFrame.new(0, -1.7, -0.3), Color3.fromRGB(240, 220, 190))
		eye(model, root, CFrame.new(0, 1.1, -2.2), 1.1)
		piece(
			model,
			root,
			Vector3.new(0.6, 0.15, 1.6),
			CFrame.new(0, 0.5, -2.6) * CFrame.Angles(math.rad(-30), 0, 0),
			Color3.fromRGB(220, 40, 60)
		)
	end,

	-- Possessed Yoroi: hovering empty samurai armour, horned helmet, red glow inside.
	oni = function(model, root)
		piece(model, root, Vector3.new(3.2, 3, 2.2), CFrame.new(0, 0.6, 0), LACQUER, Enum.Material.Wood)
		piece(model, root, Vector3.new(3.4, 1.4, 2.4), CFrame.new(0, -1.4, 0), INK, Enum.Material.Wood)
		for _, side in { -1, 1 } do
			piece(
				model,
				root,
				Vector3.new(1.4, 1.8, 2.4),
				CFrame.new(side * 2.3, 1.2, 0) * CFrame.Angles(0, 0, math.rad(side * -15)),
				LACQUER,
				Enum.Material.Wood
			)
			piece(
				model,
				root,
				Vector3.new(0.25, 2.2, 0.5),
				CFrame.new(side * 0.9, 4.4, -0.6) * CFrame.Angles(0, 0, math.rad(side * -25)),
				GOLD,
				Enum.Material.Metal
			)
		end
		piece(
			model,
			root,
			Vector3.new(2.6, 2, 2.6),
			CFrame.new(0, 2.9, 0),
			INK,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		piece(model, root, Vector3.new(2.8, 0.3, 2.8), CFrame.new(0, 2.4, 0), INK, Enum.Material.Metal)
		piece(
			model,
			root,
			Vector3.new(1.6, 1, 0.3),
			CFrame.new(0, 2.5, -1.3),
			Color3.fromRGB(10, 8, 10),
			Enum.Material.Metal
		)
		for _, side in { -1, 1 } do
			piece(
				model,
				root,
				Vector3.new(0.35, 0.2, 0.2),
				CFrame.new(side * 0.4, 2.7, -1.45),
				EMBER,
				Enum.Material.Neon
			)
		end
		local core = piece(
			model,
			root,
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(0, 0.6, -0.5),
			EMBER,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		light(core, EMBER, 10, 2)
	end,

	-- Oni General: the generated oni statue (reused), glowing eyes and chains of parts.
	general = function(model, root)
		if meshOn(model, root, "oni", 0.55, CFrame.new(0, -0.5, 0)) == nil then
			piece(model, root, Vector3.new(6, 8, 4), CFrame.identity, LACQUER, Enum.Material.Slate)
			piece(
				model,
				root,
				Vector3.new(4, 4, 4),
				CFrame.new(0, 5.5, 0),
				LACQUER,
				Enum.Material.Slate,
				Enum.PartType.Ball
			)
			for _, side in { -1, 1 } do
				piece(
					model,
					root,
					Vector3.new(0.6, 2.5, 0.6),
					CFrame.new(side * 1.2, 8, 0) * CFrame.Angles(0, 0, math.rad(side * -20)),
					PAPER,
					Enum.Material.Marble
				)
			end
		end
		for _, side in { -1, 1 } do
			local glowEye = piece(
				model,
				root,
				Vector3.new(0.9, 0.5, 0.3),
				CFrame.new(side * 1.1, 4.6, -3.6),
				EMBER,
				Enum.Material.Neon
			)
			light(glowEye, EMBER, 12, 2)
			for link = 0, 2 do
				piece(
					model,
					root,
					Vector3.new(0.9, 0.35, 0.35),
					CFrame.new(side * 3.6, -0.5 - link * 0.85, -1) * CFrame.Angles(0, 0, math.rad(90 + link * 30)),
					Color3.fromRGB(70, 70, 78),
					Enum.Material.Metal,
					Enum.PartType.Cylinder
				)
			end
		end
	end,
}

local function newBody(kind: string, id: number, at: Vector3, radius: number): Body
	local model = Instance.new("Model")
	model.Name = tostring(id)
	model:SetAttribute("Id", id)
	model:SetAttribute("Kind", kind)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * math.max(1, radius)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CFrame = CFrame.new(at)
	root.Parent = model
	model.PrimaryPart = root
	BUILD[kind](model, root)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = math.huge
	align.Responsiveness = 40
	align.Position = at
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = math.huge
	orient.Responsiveness = 20
	orient.CFrame = CFrame.identity
	orient.Parent = root
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return { model = model, root = root, align = align, orient = orient }
end

-- Boss model ---------------------------------------------------------------------------------

local SKULL_HOME = CFrame.new(0, 22, -78) * CFrame.Angles(0, math.pi, 0)
local SKULL_LOW = CFrame.new(0, 12, -68) * CFrame.Angles(math.rad(8), math.pi, 0)
local SKULL_BURIED = CFrame.new(0, -14, -78) * CFrame.Angles(0, math.pi, 0)
local HAND_HOME = { CFrame.new(-20, 10, -58), CFrame.new(20, 10, -58) * CFrame.Angles(0, math.pi, 0) }
local FLAT = CFrame.Angles(math.rad(-90), 0, 0) -- palm down

type Strike = { hand: BasePart, home: CFrame, uid: number?, centre: Vector3, key: string }
type Act = {
	kind: string,
	lockAt: number,
	hitAt: number,
	doneAt: number,
	landed: boolean,
	resolved: boolean,
	strikes: { Strike },
	a: Vector3,
	b: Vector3,
	sweptX: number,
	hit: { [number]: boolean },
}
type Boss = {
	e: Enemy,
	model: Model,
	skull: BasePart,
	hands: { BasePart },
	s: BossRules.State,
	act: Act?,
	attacks: number,
	low: boolean,
	readyAt: number,
}

local boss: Boss? = nil

local function tween(p: BasePart, cframe: CFrame, seconds: number, style: Enum.EasingStyle?)
	TweenService:Create(p, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), { CFrame = cframe }):Play()
end

local function bossPart(model: Model, mesh: string, name: string, part: string, fallback: Vector3): BasePart
	local p: BasePart? = warmSpawn(mesh, model, Vector3.new(0, -40, 0), 1)
	if p == nil then
		local stand = Instance.new("Part")
		stand.Anchored = true
		stand.Size = fallback
		stand.Color = Color3.fromRGB(235, 228, 210)
		stand.Material = Enum.Material.Marble
		stand.Shape = if part == "skull" then Enum.PartType.Ball else Enum.PartType.Block
		stand.Parent = model
		p = stand
	end
	local result = p :: BasePart
	result.Name = name
	result.CanCollide = false
	result.CanTouch = false
	result:SetAttribute("Part", part)
	return result
end

local function spawnBoss(e: Enemy, t: number)
	local model = Instance.new("Model")
	model.Name = tostring(e.id)
	model:SetAttribute("Id", e.id)
	model:SetAttribute("Kind", "boss")
	local skull = bossPart(model, "bossSkull", "Skull", "skull", Vector3.new(18, 18, 18))
	skull.CFrame = SKULL_BURIED
	for _, side in { -1, 1 } do
		local eyeGlow = Instance.new("Part")
		eyeGlow.Name = "EyeGlow"
		eyeGlow.Anchored = true
		eyeGlow.CanCollide = false
		eyeGlow.CanQuery = false
		eyeGlow.Transparency = 1
		eyeGlow.Size = Vector3.one
		eyeGlow.CFrame = skull.CFrame * CFrame.new(side * 3.5, 3, -9)
		light(eyeGlow, EMBER, 30, 4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = skull, eyeGlow
		weld.Parent = eyeGlow
		eyeGlow.Anchored = false
		eyeGlow.Massless = true
		eyeGlow.Parent = model
	end
	local hands = {
		bossPart(model, "boneHand", "HandL", "hand", Vector3.new(6, 14, 3)),
		bossPart(model, "boneHand", "HandR", "hand", Vector3.new(6, 14, 3)),
	}
	for i, hand in hands do
		hand.CFrame = HAND_HOME[i] - Vector3.new(0, 30, 0)
	end
	model.PrimaryPart = skull
	model.Parent = folder
	tween(skull, SKULL_HOME, BossRules.RISE, Enum.EasingStyle.Sine)
	for i, hand in hands do
		tween(hand, HAND_HOME[i], BossRules.RISE, Enum.EasingStyle.Back)
	end
	boss = {
		e = e,
		model = model,
		skull = skull,
		hands = hands,
		s = BossRules.new(t),
		act = nil,
		attacks = 0,
		low = false,
		readyAt = t + BossRules.RISE,
	}
end

-- The skull's hit point is near its jaw, so it is in reach from the ground only while lowered.
local function skullPoint(b: Boss): Vector3
	return b.skull.Position - Vector3.new(0, b.skull.Size.Y / 2 - 4, 0)
end

local function handPoint(hand: BasePart): Vector3
	return Vector3.new(hand.Position.X, math.max(PLAYER_ROOT, hand.Position.Y - 5), hand.Position.Z)
end

-- Wave state ---------------------------------------------------------------------------------

type Wave = { w: number, n: number, tier: number, queue: { WaveRules.Spawn }, index: number, nextAt: number }
local wave: Wave? = nil

type Projectile = { id: number, key: string, pos: Vector3, vel: Vector3, radius: number, dieAt: number, damage: number }
local projectiles: { Projectile } = {}

local function aliveCount(): (number, number)
	local all, counted = 0, 0
	for _, mob in mobs do
		all += 1
		if mob.e.owner == nil then
			counted += 1
		end
	end
	if boss then
		all += 1
		counted += 1
	end
	return all, counted
end

local function spawnMob(kind: string, at: Vector3, t: number, speedMult: number?, owner: number?): Mob?
	local current = wave
	if current == nil or aliveCount() >= MAX_ALIVE then
		return nil
	end
	nextId += 1
	local e = WaveRules.newEnemy(nextId, kind, current.n, current.tier, vec(at), t, speedMult, owner)
	if kind == "boss" then
		spawnBoss(e, t)
		return nil
	end
	local hover = HOVER[kind] or 3
	local start = Vector3.new(at.X, groundAt(at.X, at.Z) + hover, at.Z)
	local mob: Mob = {
		e = e,
		body = newBody(kind, e.id, start, e.radius),
		hover = hover,
		attacks = 0,
		pending = nil,
		dash = nil,
		knockUntil = 0,
		knockTo = start,
		knockSpeed = 0,
		launchY = start.Y,
		summonAt = t + (if kind == "general" then BEHAVIOUR.general.summonEvery else math.huge),
		contactAt = {},
		last = start,
	}
	mobs[e.id] = mob
	return mob
end

local function gatePoint(gate: number, jitter: number): Vector3
	local g = WaveRules.GATES[gate]
	local angle = math.random() * math.pi * 2
	return Vector3.new(g.x + math.cos(angle) * jitter, 0, g.z + math.sin(angle) * jitter)
end

local function destroyMob(id: number)
	local mob = mobs[id]
	if mob then
		mob.body.model:Destroy()
		mobs[id] = nil
	end
end

local function cancel(mob: Mob)
	mob.pending = nil
	mob.dash = nil
	mob.e.telegraphUntil = 0
end

-- Fx("kill"), remove the model, and make the dead enemy's summons vanish (GDD D3, resolution 6).
local function kill(id: number, by: number)
	local mob = mobs[id]
	local b = boss
	local at: Vector3
	if mob then
		at = mob.body.root.Position
		destroyMob(id)
	elseif b and b.e.id == id then
		at = b.skull.Position
		b.model:Destroy()
		boss = nil
	else
		return
	end
	Remotes.fx("kill", { e = id, u = by, p = at })
	for other, m in mobs do
		if m.e.owner == id then
			Remotes.fx("kill", { e = other, u = by, p = m.body.root.Position })
			destroyMob(other)
		end
	end
end

local function nextKey(mob: Mob): string
	mob.attacks += 1
	return `{mob.e.id}:{mob.attacks}`
end

-- Public API ---------------------------------------------------------------------------------

function Enemies.clear()
	for id in mobs do
		destroyMob(id)
	end
	if boss then
		boss.model:Destroy()
		boss = nil
	end
	for _, p in projectiles do
		Remotes.fx("projectileEnd", { id = p.id, p = p.pos })
	end
	table.clear(projectiles)
	wave = nil
end

function Enemies.startWave(w: number, n: number, tier: number, seed: number, t: number)
	Enemies.clear()
	wave = { w = w, n = n, tier = tier, queue = WaveRules.composition(w, n, seed), index = 1, nextAt = t }
end

-- Cleared when every enemy of the composition has spawned and died; summons do not count.
function Enemies.cleared(): boolean
	local current = wave
	if current == nil or current.index <= #current.queue then
		return false
	end
	local _, counted = aliveCount()
	return counted == 0
end

function Enemies.get(id: number): Enemy?
	local mob = mobs[id]
	if mob then
		return mob.e
	end
	local b = boss
	return if b and b.e.id == id then b.e else nil
end

function Enemies.bossFraction(): number?
	local b = boss
	if b then
		return math.clamp(b.e.hp / b.e.maxHp, 0, 1)
	end
	for _, mob in mobs do
		if mob.e.kind == "general" then
			return math.clamp(mob.e.hp / mob.e.maxHp, 0, 1)
		end
	end
	return nil
end

-- Hit targets at their live positions; the boss appears as its skull and hands under one id.
function Enemies.targets(): { CombatRules.Target }
	local list: { CombatRules.Target } = {}
	for id, mob in mobs do
		table.insert(list, { id = id, pos = vec(mob.body.root.Position), radius = mob.e.radius, mult = 1 })
	end
	local b = boss
	if b then
		local t = os.clock()
		local staggered = BossRules.staggered(b.s, t)
		table.insert(list, {
			id = b.e.id,
			pos = vec(skullPoint(b)),
			radius = WaveRules.ENEMIES.boss.radius,
			mult = BossRules.partMult("skull", staggered),
		})
		for _, hand in b.hands do
			table.insert(
				list,
				{ id = b.e.id, pos = vec(handPoint(hand)), radius = 6, mult = BossRules.partMult("hand", false) }
			)
		end
	end
	return list
end

-- Applies damage and the C7 reactions. `knockback` is the attacker's weapon finisher distance.
function Enemies.damage(
	id: number,
	amount: number,
	by: number,
	finisher: boolean,
	trigger: boolean,
	launch: boolean,
	from: Vec3,
	t: number,
	knockback: number?
): boolean
	local e = Enemies.get(id)
	if e == nil or e.hp <= 0 then
		return false
	end
	e.hp -= amount
	if e.hp <= 0 then
		kill(id, by)
		return true
	end
	local mob = mobs[id]
	if mob == nil then
		return false -- the boss never staggers or moves
	end
	local staggers, push = CombatRules.reaction(e.class, finisher, trigger)
	if staggers then
		e.staggerUntil = math.max(e.staggerUntil, t + CombatRules.STAGGER)
		cancel(mob)
	end
	if finisher and knockback and push > 0 then
		local here = mob.body.root.Position
		local away = flat(here - v3(from))
		if away.Magnitude < 0.01 then
			away = -mob.body.root.CFrame.LookVector
		end
		local distance = knockback * push
		mob.knockTo = here + flat(away).Unit * distance
		mob.knockUntil = t + CombatRules.KNOCKBACK_TIME
		mob.knockSpeed = distance / CombatRules.KNOCKBACK_TIME
	end
	if launch and CombatRules.canLaunch(e.class) then
		local here = mob.body.root.Position
		e.airborneUntil = t + CombatRules.SKILL.airborne
		mob.launchY = groundAt(here.X, here.Z) + mob.hover + LAUNCH_HEIGHT
		cancel(mob)
	end
	return false
end

-- Step helpers -------------------------------------------------------------------------------

type Candidate = WaveRules.Candidate

local function candidatesNow(): ({ Candidate }, { [number]: Vector3 })
	local list: { Candidate } = {}
	local byId: { [number]: Vector3 } = {}
	for _, p in State.run.participants do
		local pos = State.positions[p.userId]
		if not p.downed and pos then
			table.insert(list, { userId = p.userId, pos = pos })
			byId[p.userId] = v3(pos)
		end
	end
	return list, byId
end

local function spawnQueue(t: number)
	local current = wave
	if current == nil or current.index > #current.queue or t < current.nextAt then
		return
	end
	local _, counted = aliveCount()
	if counted >= WaveRules.aliveCap(current.n) then
		return
	end
	local entry = current.queue[current.index]
	local at = if entry.kind == "boss"
		then PIT
		else gatePoint(WaveRules.gateFor(current.index, WaveRules.gatesOpen(current.w)), 3)
	if entry.kind == "boss" or aliveCount() < MAX_ALIVE then
		spawnMob(entry.kind, at, t, entry.speedMult, nil)
		current.index += 1
	end
	current.nextAt = t + WaveRules.SPAWN_INTERVAL
end

local function summon(owner: number, kind: string, count: number, near: Vector3?, t: number): number
	local made = 0
	for i = 1, count do
		local at = if near
			then near + Vector3.new(math.cos(i * 2.1) * 6, 0, math.sin(i * 2.1) * 6)
			else gatePoint((i - 1) % #WaveRules.GATES + 1, 3)
		if spawnMob(kind, at, t, 1, owner) then
			made += 1
		end
	end
	return made
end

local function hurtWhere(
	hurts: { Hurt },
	candidates: { Candidate },
	key: string,
	amount: number,
	test: (Vector3) -> boolean,
	hit: { [number]: boolean }?
)
	for _, c in candidates do
		if (hit == nil or not hit[c.userId]) and test(v3(c.pos)) then
			table.insert(hurts, { userId = c.userId, amount = amount, key = key })
			if hit then
				hit[c.userId] = true
			end
		end
	end
end

-- Where a mob wants to be this tick, before separation.
local function moveGoal(mob: Mob, here: Vector3, target: Vector3?, t: number): Vector3
	local e = mob.e
	local height = groundAt(here.X, here.Z) + mob.hover
	if target == nil then
		return Vector3.new(here.X, height, here.Z)
	end
	local offset = flat(here - target)
	local distance = offset.Magnitude
	local away = if distance > 0.01 then offset / distance else Vector3.xAxis
	local goal: Vector3
	if e.kind == "lantern" then
		local b = BEHAVIOUR.lantern
		if distance < b.keepMin then
			goal = target + away * (b.keepMin + 2)
		elseif distance > b.keepMax then
			goal = target + away * ((b.keepMin + b.keepMax) / 2)
		else
			goal = here + away:Cross(Vector3.yAxis) * 3 -- drift sideways while in its band
		end
	elseif e.kind == "kasa" then
		goal = if distance > 18 then target + away * 16 else here
		height += math.abs(math.sin(t * 6)) * 1.5
	else
		goal = target + away * (e.radius + 1)
		if e.kind == "wisp" then
			height += math.sin(t * 3 + e.id) * 0.6
		end
	end
	return Vector3.new(goal.X, height, goal.Z)
end

local function startAttack(mob: Mob, here: Vector3, target: Vector3, t: number)
	local e = mob.e
	local distance = flat(target - here).Magnitude
	local kind = e.kind
	if kind == "lantern" and distance <= BEHAVIOUR.lantern.range then
		mob.pending = { kind = "fireball", key = nextKey(mob), from = here, to = target }
		e.telegraphUntil = t + BEHAVIOUR.lantern.telegraph
		e.nextAttackAt = t + BEHAVIOUR.lantern.period
		Remotes.fx("telegraph", { e = e.id, shape = "glow", p = here, r = e.radius, dur = BEHAVIOUR.lantern.telegraph })
	elseif kind == "kasa" and distance <= BEHAVIOUR.kasa.range then
		local b = BEHAVIOUR.kasa
		local dir = flat(target - here).Unit
		local from = Vector3.new(here.X, 0, here.Z)
		local to = from + dir * b.length
		mob.pending = { kind = "dash", key = nextKey(mob), from = from, to = to }
		e.telegraphUntil = t + b.telegraph
		e.nextAttackAt = t + b.period
		Remotes.fx("telegraph", { e = e.id, shape = "line", p = from, q = to, r = b.width, dur = b.telegraph })
	elseif SLAMS[kind] and distance <= SLAMS[kind].range then
		local b = SLAMS[kind]
		local centre = Vector3.new(here.X, groundAt(here.X, here.Z), here.Z)
		mob.pending = { kind = "slam", key = nextKey(mob), from = centre, to = centre }
		e.telegraphUntil = t + b.telegraph
		e.nextAttackAt = t + b.period
		Remotes.fx("telegraph", { e = e.id, shape = "circle", p = centre, r = b.radius, dur = b.telegraph })
	end
end

local function land(
	mob: Mob,
	pending: Pending,
	here: Vector3,
	target: Vector3?,
	t: number,
	candidates: { Candidate },
	hurts: { Hurt }
)
	local e = mob.e
	if pending.kind == "fireball" then
		local b = BEHAVIOUR.lantern
		local aim = (target or (here + mob.body.root.CFrame.LookVector * 10)) - here
		State.nextProjectile += 1
		local velocity = (if aim.Magnitude > 0.01 then aim.Unit else Vector3.zAxis) * b.projectileSpeed
		local life = b.range * 1.2 / b.projectileSpeed
		table.insert(projectiles, {
			id = State.nextProjectile,
			key = pending.key,
			pos = here,
			vel = velocity,
			radius = b.projectileRadius,
			dieAt = t + life,
			damage = e.attack,
		})
		Remotes.fx("projectile", {
			id = State.nextProjectile,
			what = "fireball",
			p = here,
			v = velocity,
			r = b.projectileRadius,
			life = life,
		})
	elseif pending.kind == "dash" then
		local b = BEHAVIOUR.kasa
		mob.dash = { key = pending.key, to = pending.to, endsAt = t + b.length / b.speed + 0.1, hit = {} }
		Remotes.fx("impact", { e = e.id, p = pending.from, r = b.width, what = "dash" })
	else
		local radius = SLAMS[e.kind].radius
		local centre = pending.from
		hurtWhere(hurts, candidates, pending.key, e.attack, function(pos)
			return flat(pos - centre).Magnitude <= radius and pos.Y - centre.Y < PLAYER_ROOT + 6
		end)
		Remotes.fx("impact", { e = e.id, p = centre, r = radius, what = "slam" })
	end
end

local function stepMob(
	mob: Mob,
	t: number,
	candidates: { Candidate },
	byId: { [number]: Vector3 },
	push: Vector3,
	hurts: { Hurt }
)
	local e = mob.e
	local body = mob.body
	local here = body.root.Position
	local previous = mob.last
	mob.last = here
	e.pos = vec(here)

	for _, c in candidates do
		if CombatRules.flatDistance(e.pos, c.pos) <= WaveRules.STUCK.radius then
			e.nearAt = t
			break
		end
	end
	if WaveRules.isStuck(e, t) then
		local gate = gatePoint(WaveRules.nearestGate(e.pos), 2) + Vector3.new(0, mob.hover, 0)
		body.root.CFrame = CFrame.new(gate)
		body.align.Position = gate
		mob.last = gate
		e.nearAt = t
		cancel(mob)
		return
	end
	if t >= e.retargetAt then
		e.target = WaveRules.pickTarget(e.pos, candidates)
		e.retargetAt = t + WaveRules.RETARGET
	end
	local target = e.target and byId[e.target]
	local canAct = WaveRules.canAct(e, t)
	if not canAct and (mob.pending or mob.dash) then
		cancel(mob) -- C3, C7: staggered or airborne enemies drop their telegraphed attack
	end

	local goal, speed = here, e.speed
	if t < mob.knockUntil then
		goal, speed = mob.knockTo, mob.knockSpeed
	elseif t < e.airborneUntil then
		goal, speed = Vector3.new(here.X, mob.launchY, here.Z), 45
	elseif t < e.staggerUntil then
		goal = here
	elseif mob.dash then
		local dash = mob.dash :: Dash
		goal = Vector3.new(dash.to.X, groundAt(dash.to.X, dash.to.Z) + mob.hover, dash.to.Z)
		speed = BEHAVIOUR.kasa.speed
		hurtWhere(hurts, candidates, dash.key, e.attack, function(pos)
			return CombatRules.nearSegment(vec(previous), vec(here), vec(pos), BEHAVIOUR.kasa.width)
				and math.abs(pos.Y - here.Y) <= 5
		end, dash.hit)
		if t >= dash.endsAt then
			mob.dash = nil
		end
	elseif mob.pending then
		local pending = mob.pending :: Pending
		goal = here
		if t >= e.telegraphUntil then
			mob.pending = nil
			e.telegraphUntil = 0
			land(mob, pending, here, target, t, candidates, hurts)
		end
	else
		goal = moveGoal(mob, here, target, t) + push
		if target and t >= e.nextAttackAt then
			startAttack(mob, here, target, t)
		end
		if e.kind == "general" and t >= mob.summonAt then
			local b = BEHAVIOUR.general
			mob.summonAt = t + b.summonEvery
			local own = 0
			for _, m in mobs do
				if m.e.owner == e.id then
					own += 1
				end
			end
			if summon(e.id, "wisp", math.min(b.summonCount, b.summonCap - own), here, t) > 0 then
				Remotes.fx("summon", { e = e.id, p = here })
			end
		end
	end
	body.align.Position = goal
	body.align.MaxVelocity = math.max(speed, 1)
	if target then
		local look = flat(target - here)
		if look.Magnitude > 0.1 then
			body.orient.CFrame = CFrame.lookAt(Vector3.zero, look)
		end
	end

	-- C8 contact damage, at most once per (enemy, player) pair per second; airborne enemies deal none.
	if e.contact > 0 and t >= e.airborneUntil then
		for _, c in candidates do
			local last = mob.contactAt[c.userId]
			if
				(last == nil or t - last >= CombatRules.CONTACT.interval)
				and CombatRules.contact(e.pos, e.radius, c.pos)
			then
				mob.contactAt[c.userId] = t
				table.insert(hurts, { userId = c.userId, amount = e.contact, key = `contact:{e.id}` })
			end
		end
	end
end

local function stepProjectiles(t: number, dt: number, candidates: { Candidate }, hurts: { Hurt })
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local from, to = p.pos, p.pos + p.vel * dt
		local hitSomeone = false
		for _, c in candidates do
			if
				CombatRules.nearSegment(vec(from), vec(to), c.pos, p.radius)
				and math.abs(c.pos.y - to.Y) <= p.radius + 3
			then
				table.insert(hurts, { userId = c.userId, amount = p.damage, key = p.key })
				hitSomeone = true
				break
			end
		end
		p.pos = to
		if hitSomeone or t >= p.dieAt then
			Remotes.fx("projectileEnd", { id = p.id, p = to })
			table.remove(projectiles, i)
		end
	end
end

-- Gashadokuro (GDD D3) -----------------------------------------------------------------------

local function bossKey(b: Boss): string
	b.attacks += 1
	return `{b.e.id}:{b.attacks}`
end

local function startBossAttack(
	b: Boss,
	attack: string,
	candidates: { Candidate },
	byId: { [number]: Vector3 },
	t: number
)
	local ids = {}
	for _, c in candidates do
		table.insert(ids, c.userId)
	end
	local tier = (wave :: Wave).tier
	if attack == "summon" then
		summon(b.e.id, "wisp", BossRules.SUMMON.wisp, nil, t)
		summon(b.e.id, "lantern", BossRules.SUMMON.lantern, nil, t)
		Remotes.fx("summon", { e = b.e.id, p = b.skull.Position })
		b.s = BossRules.resolved(b.s, attack, t)
		return
	end
	local act: Act = {
		kind = attack,
		lockAt = 0,
		hitAt = 0,
		doneAt = 0,
		landed = false,
		resolved = false,
		strikes = {},
		a = Vector3.zero,
		b = Vector3.zero,
		sweptX = 0,
		hit = {},
	}
	if attack == "sweep" then
		local picks
		picks, b.s = BossRules.targets(b.s, ids, 1)
		local aim = byId[picks[1]] or Vector3.zero
		local a, z = BossRules.sweepLine(vec(aim))
		act.a, act.b = Vector3.new(a.x, 0, a.z), Vector3.new(z.x, 0, z.z)
		act.sweptX = act.a.X
		act.hitAt = t + BossRules.SWEEP.telegraph
		act.doneAt = act.hitAt + 1.4
		local hand = b.hands[1]
		table.insert(act.strikes, { hand = hand, home = HAND_HOME[1], uid = nil, centre = act.a, key = bossKey(b) })
		tween(hand, CFrame.new(act.a + Vector3.new(0, 6, 0)) * CFrame.Angles(0, math.rad(90), 0), 1)
		Remotes.fx("telegraph", {
			e = b.e.id,
			shape = "line",
			p = act.a,
			q = act.b,
			r = BossRules.SWEEP.width,
			dur = BossRules.SWEEP.telegraph,
		})
	else
		local count = if attack == "double" then 2 else 1
		local picks
		picks, b.s = BossRules.targets(b.s, ids, count)
		local slam = BossRules.SLAM
		act.lockAt = t + slam.follow
		act.hitAt = act.lockAt + slam.lock
		act.doneAt = act.hitAt + 1
		for i = 1, count do
			local uid = picks[i] or picks[1]
			local handIndex = if count == 2 then i else b.attacks % 2 + 1
			local centre = byId[uid] or Vector3.zero
			table.insert(act.strikes, {
				hand = b.hands[handIndex],
				home = HAND_HOME[handIndex],
				uid = uid,
				centre = Vector3.new(centre.X, 0, centre.Z),
				key = bossKey(b),
			})
			Remotes.fx("telegraph", {
				e = b.e.id,
				shape = "circle",
				p = Vector3.new(centre.X, 0, centre.Z),
				r = slam.radius,
				dur = slam.follow + slam.lock,
				follow = uid,
			})
		end
	end
	b.act = act
	b.e.attack = WaveRules.damage(if attack == "sweep" then BossRules.SWEEP.damage else BossRules.SLAM.damage, tier)
end

local function stepBoss(b: Boss, t: number, candidates: { Candidate }, byId: { [number]: Vector3 }, hurts: { Hurt })
	b.e.pos = vec(skullPoint(b))
	local low = BossRules.staggered(b.s, t)
	if low ~= b.low then
		b.low = low
		tween(b.skull, if low then SKULL_LOW else SKULL_HOME, 0.5)
	end
	if t < b.readyAt then
		return
	end
	local act = b.act
	if act == nil then
		if #candidates > 0 then
			local attack
			attack, b.s = BossRules.next(b.s, b.e.hp, b.e.maxHp, t)
			if attack then
				startBossAttack(b, attack, candidates, byId, t)
			end
		end
		return
	end
	if act.kind == "sweep" then
		local sweep = BossRules.SWEEP
		local duration = 0.6
		if t >= act.hitAt and not act.landed then
			act.landed = true
			Remotes.fx("impact", { e = b.e.id, p = act.a, r = sweep.width, what = "sweep" })
			tween(
				act.strikes[1].hand,
				CFrame.new(act.b + Vector3.new(0, 6, 0)) * CFrame.Angles(0, math.rad(90), 0),
				duration,
				Enum.EasingStyle.Linear
			)
		end
		if act.landed and not act.resolved then
			local progress = math.clamp((t - act.hitAt) / duration, 0, 1)
			local x = act.a.X + (act.b.X - act.a.X) * progress
			local fromX, toX = math.min(act.sweptX, x) - sweep.width, math.max(act.sweptX, x) + sweep.width
			act.sweptX = x
			hurtWhere(hurts, candidates, act.strikes[1].key, b.e.attack, function(pos)
				local feet = math.max(0, pos.Y - PLAYER_ROOT)
				return pos.X >= fromX and pos.X <= toX and BossRules.sweepHit(vec(act.a), vec(act.b), vec(pos), feet)
			end, act.hit)
			if progress >= 1 then
				act.resolved = true
				b.s = BossRules.resolved(b.s, "sweep", t)
			end
		end
	else
		for _, strike in act.strikes do
			if t < act.lockAt and strike.uid and byId[strike.uid] then
				local p = byId[strike.uid]
				strike.centre = Vector3.new(p.X, 0, p.Z)
			end
			if not act.landed then
				tween(strike.hand, CFrame.new(strike.centre + Vector3.new(0, 18, 0)) * FLAT, 0.12)
			end
		end
		if t >= act.hitAt and not act.landed then
			act.landed = true
			local radius = BossRules.SLAM.radius
			for _, strike in act.strikes do
				local centre = strike.centre
				tween(strike.hand, CFrame.new(centre + Vector3.new(0, 2.5, 0)) * FLAT, 0.1)
				hurtWhere(hurts, candidates, strike.key, b.e.attack, function(pos)
					return flat(pos - centre).Magnitude <= radius and pos.Y < PLAYER_ROOT + 8
				end)
				Remotes.fx("impact", { e = b.e.id, p = centre, r = radius, what = "slam" })
			end
			b.s = BossRules.resolved(b.s, act.kind, t)
		end
	end
	if t >= act.doneAt then
		for _, strike in act.strikes do
			tween(strike.hand, strike.home, 0.8)
		end
		b.act = nil
	end
end

-- Tick step 2 (docs/architecture/night.md 4.3).
function Enemies.step(t: number, dt: number): { Hurt }
	local hurts: { Hurt } = {}
	local candidates, byId = candidatesNow()
	spawnQueue(t)

	-- Simple separation so a crowd fans out instead of stacking on one point.
	local spots: { [number]: Vector3 } = {}
	for id, mob in mobs do
		spots[id] = mob.body.root.Position
	end
	-- Iterate the snapshot: a general's summon adds to `mobs` mid-loop (QA M4).
	for id, here in spots do
		local mob = mobs[id]
		if mob then
			local push = Vector3.zero
			for other, there in spots do
				if other ~= id then
					local gap = flat(here - there)
					local room = mob.e.radius + 2
					if gap.Magnitude < room and gap.Magnitude > 0.01 then
						push += gap.Unit * (room - gap.Magnitude)
					end
				end
			end
			stepMob(mob, t, candidates, byId, push, hurts)
		end
	end
	stepProjectiles(t, dt, candidates, hurts)
	local b = boss
	if b then
		stepBoss(b, t, candidates, byId, hurts)
	end
	return hurts
end

-- Warm the mesh cache so the first lantern, general or boss does not stall a tick.
task.spawn(function()
	local holder = Instance.new("Folder")
	for _, name in { "lanternYokai", "oni", "bossSkull", "boneHand" } do
		local mesh = Models.spawn(name, holder, Vector3.zero, 1)
		if mesh then
			mesh:Destroy()
			warmed[name] = true
		end
	end
	holder:Destroy()
end)

return Enemies
