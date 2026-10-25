--!strict
-- Pure enemy and wave rules for Hundred Demon Night (GDD section D): stats, scaling, seeded
-- composition, gates, spawn caps and targeting. No Roblox APIs, so Lune can unit-test them.

local CombatRules = require("./CombatRules")
local Rng = require("./Rng")

local WaveRules = {}

type Vec3 = CombatRules.Vec3

export type Stats = {
	kind: string,
	name: string,
	cost: number,
	hp: number,
	speed: number,
	contact: number,
	attack: number,
	radius: number,
	class: string,
}

export type Spawn = { kind: string, speedMult: number }

export type Enemy = {
	id: number,
	kind: string,
	class: string,
	hp: number,
	maxHp: number,
	contact: number,
	attack: number,
	speed: number,
	radius: number,
	pos: Vec3,
	target: number?,
	retargetAt: number,
	nearAt: number,
	staggerUntil: number,
	airborneUntil: number,
	nextAttackAt: number,
	telegraphUntil: number,
	owner: number?,
}

export type Candidate = { userId: number, pos: Vec3 }

local function stats(
	kind: string,
	name: string,
	cost: number,
	hp: number,
	speed: number,
	contact: number,
	attack: number,
	radius: number,
	class: string
): Stats
	return {
		kind = kind,
		name = name,
		cost = cost,
		hp = hp,
		speed = speed,
		contact = contact,
		attack = attack,
		radius = radius,
		class = class,
	}
end

WaveRules.WAVES = 10
WaveRules.ENEMIES = {
	wisp = stats("wisp", "Hitodama", 1, 24, 14, 6, 0, 1.5, "normal"),
	lantern = stats("lantern", "Chōchin-obake", 2, 50, 8, 0, 12, 2.5, "normal"),
	kasa = stats("kasa", "Kasa-obake", 2, 45, 10, 0, 15, 2.5, "normal"),
	oni = stats("oni", "Possessed Yoroi", 4, 160, 9, 6, 25, 3.5, "armoured"),
	general = stats("general", "Oni General", 0, 900, 11, 0, 30, 5, "armoured"),
	boss = stats("boss", "Gashadokuro", 0, 3000, 0, 0, 0, 9, "boss"),
} :: { [string]: Stats }
WaveRules.BEHAVIOUR = {
	wisp = { hover = 3 },
	lantern = {
		keepMin = 18,
		keepMax = 28,
		period = 3.5,
		range = 40,
		telegraph = 0.8,
		projectileSpeed = 35,
		projectileRadius = 2,
	},
	kasa = { period = 4, range = 30, telegraph = 1.0, length = 30, speed = 60, width = 3 },
	oni = { range = 8, radius = 9, telegraph = 1.2, period = 3 },
	general = { range = 10, radius = 12, telegraph = 1.0, period = 3, summonEvery = 10, summonCount = 4, summonCap = 8 },
}
WaveRules.BASE_BUDGET = { [2] = 8, [3] = 11, [4] = 14, [6] = 18, [7] = 21, [8] = 24, [9] = 28 } :: { [number]: number }
WaveRules.INTRO = { [2] = "lantern", [3] = "kasa", [4] = "oni" } :: { [number]: string }
WaveRules.TUTORIAL_SPEED = 0.7
WaveRules.GATES = {
	{ x = 60, y = 0, z = 60 },
	{ x = -60, y = 0, z = -60 },
	{ x = 60, y = 0, z = -60 },
	{ x = -60, y = 0, z = 60 },
} :: { Vec3 }
WaveRules.SPAWN_INTERVAL = 0.5
WaveRules.RETARGET = 1.0
WaveRules.STUCK = { radius = 30, time = 20 }

local function round(x: number): number
	return math.floor(x + 0.5 + 1e-9)
end

function WaveRules.budget(w: number, n: number): number
	local base = WaveRules.BASE_BUDGET[w]
	if base == nil then
		return 0
	end
	return round(base * (1 + 0.6 * (n - 1)))
end

function WaveRules.allowed(w: number): { string }
	if w == 1 then
		return { "wisp" }
	elseif w == 2 then
		return { "wisp", "lantern" }
	elseif w == 3 then
		return { "wisp", "lantern", "kasa" }
	elseif w == 5 then
		return { "general" }
	elseif w == 10 then
		return { "boss" }
	elseif w >= 4 and w <= 9 then
		return { "wisp", "lantern", "kasa", "oni" }
	end
	return {}
end

function WaveRules.gatesOpen(w: number): number
	return if w <= 1 then 1 elseif w <= 3 then 2 else 4
end

function WaveRules.oniCap(w: number, n: number): number
	return math.floor(w / 3) + math.floor((n - 1) / 2)
end

-- D4 fill rule. Wisps cost 1, so the total always lands on the budget exactly.
function WaveRules.composition(w: number, n: number, seed: Rng.State): { Spawn }
	local list: { Spawn } = {}
	if w == 1 then
		for _ = 1, 6 + 3 * (n - 1) do
			table.insert(list, { kind = "wisp", speedMult = WaveRules.TUTORIAL_SPEED })
		end
		return list
	elseif w == 5 then
		return { { kind = "general", speedMult = 1 } }
	elseif w == 10 then
		return { { kind = "boss", speedMult = 1 } }
	end
	local left = WaveRules.budget(w, n)
	local cap = WaveRules.oniCap(w, n)
	local onis = 0
	local state = seed
	local function add(kind: string)
		table.insert(list, { kind = kind, speedMult = 1 })
		left -= WaveRules.ENEMIES[kind].cost
		if kind == "oni" then
			onis += 1
		end
	end
	local intro = WaveRules.INTRO[w]
	if intro and left >= WaveRules.ENEMIES[intro].cost then
		add(intro)
	end
	while left > 0 do
		local options = {}
		for _, kind in WaveRules.allowed(w) do
			if WaveRules.ENEMIES[kind].cost <= left and (kind ~= "oni" or onis < cap) then
				table.insert(options, kind)
			end
		end
		local i
		i, state = Rng.int(state, 1, #options)
		add(options[i])
	end
	return list
end

function WaveRules.gateFor(i: number, open: number): number
	return (i - 1) % open + 1
end

function WaveRules.aliveCap(n: number): number
	return 12 + 4 * (n - 1)
end

function WaveRules.hp(kind: string, n: number, tier: number): number
	local s = WaveRules.ENEMIES[kind]
	local party = if s.class == "boss" or kind == "general" then 0.75 else 0.15
	return round(s.hp * (1 + party * (n - 1)) * (1 + 0.35 * (tier - 1)))
end

function WaveRules.damage(base: number, tier: number): number
	return round(base * (1 + 0.2 * (tier - 1)))
end

function WaveRules.newEnemy(
	id: number,
	kind: string,
	n: number,
	tier: number,
	pos: Vec3,
	t: number,
	speedMult: number?,
	owner: number?
): Enemy
	local s = WaveRules.ENEMIES[kind]
	local hp = WaveRules.hp(kind, n, tier)
	return {
		id = id,
		kind = kind,
		class = s.class,
		hp = hp,
		maxHp = hp,
		contact = WaveRules.damage(s.contact, tier),
		attack = WaveRules.damage(s.attack, tier),
		speed = s.speed * (speedMult or 1),
		radius = s.radius,
		pos = { x = pos.x, y = pos.y, z = pos.z },
		target = nil,
		retargetAt = t,
		nearAt = t,
		staggerUntil = 0,
		airborneUntil = 0,
		nextAttackAt = t,
		telegraphUntil = 0,
		owner = owner,
	}
end

-- Nearest by horizontal distance; strict < keeps ties on the earlier-joined candidate.
function WaveRules.pickTarget(pos: Vec3, candidates: { Candidate }): number?
	local best, bestDist = nil, math.huge
	for _, c in candidates do
		local d = CombatRules.flatDistance(pos, c.pos)
		if d < bestDist then
			best, bestDist = c.userId, d
		end
	end
	return best
end

function WaveRules.canAct(e: Enemy, t: number): boolean
	return t >= e.staggerUntil and t >= e.airborneUntil
end

function WaveRules.isStuck(e: Enemy, t: number): boolean
	return t - e.nearAt >= WaveRules.STUCK.time
end

function WaveRules.nearestGate(pos: Vec3): number
	local best, bestDist = 1, math.huge
	for i, gate in WaveRules.GATES do
		local d = CombatRules.flatDistance(pos, gate)
		if d < bestDist then
			best, bestDist = i, d
		end
	end
	return best
end

return WaveRules
