--!strict
-- Pure Hundred Demon Night combat rules (docs/game-design/game3-gdd.md section C): combos, hit
-- tests, damage, gauge, dash and the anti-exploit checks. No Roblox APIs, so Lune can unit-test
-- them. The server decides everything; the client only predicts VFX.

local CombatRules = {}

export type Vec3 = { x: number, y: number, z: number }

export type Weapon = {
	id: string,
	name: string,
	level: number,
	damage: { number },
	interval: number,
	window: number,
	recovery: number,
	range: number,
	arc: number,
	knockback: number,
}

export type Swing = { range: number, arc: number, band: number }
export type Target = { id: number, pos: Vec3, radius: number, mult: number }

export type Fighter = {
	weapon: string,
	step: number,
	attackAt: number,
	skillAt: number,
	dashAt: number,
	gauge: number,
	triggerUntil: number,
	guardUntil: number,
	requests: { number },
}

local WEAPONS: { Weapon } = {
	{
		id = "katana",
		name = "Katana",
		level = 1,
		damage = { 12, 12, 24 },
		interval = 0.32,
		window = 0.70,
		recovery = 0.50,
		range = 8,
		arc = 110,
		knockback = 30,
	},
	{
		id = "kodachi",
		name = "Twin Kodachi",
		level = 6,
		damage = { 8, 8, 8, 8, 18 },
		interval = 0.20,
		window = 0.60,
		recovery = 0.50,
		range = 6.5,
		arc = 140,
		knockback = 20,
	},
	{
		id = "nodachi",
		name = "Nodachi",
		level = 14,
		damage = { 20, 36 },
		interval = 0.55,
		window = 0.90,
		recovery = 0.60,
		range = 11,
		arc = 160,
		knockback = 45,
	},
}
CombatRules.WEAPONS = WEAPONS

CombatRules.SKILL = { cooldown = 5, damage = 20, range = 8, arc = 120, band = 8, airborne = 1.2, shockwaveRange = 10 }
CombatRules.ATTACK_BAND = 6
CombatRules.POINT_BLANK = 1
CombatRules.DASH = { tolerance = 0.95, invulnerable = 0.35 }
CombatRules.TRIGGER = { cost = 100, duration = 8, damage = 1.4, speed = 1.2, healPerHit = 2 }
CombatRules.AIRBORNE_DAMAGE = 1.25
CombatRules.STAGGER = 0.4
CombatRules.KNOCKBACK_TIME = 0.25
CombatRules.ARMOURED_KNOCKBACK = 0.3
CombatRules.CONTACT = { reach = 2.5, band = 5, interval = 1.0 }
CombatRules.GUARD = { distance = 12, lockout = 1.0 }
CombatRules.RATE = { count = 20, window = 1.0 }

function CombatRules.weapon(id: string): Weapon?
	for _, w in WEAPONS do
		if w.id == id then
			return w
		end
	end
	return nil
end

local function weaponOf(f: Fighter): Weapon
	return CombatRules.weapon(f.weapon) or WEAPONS[1]
end

local function copy(f: Fighter): Fighter
	local c = table.clone(f)
	c.requests = table.clone(f.requests)
	return c
end

function CombatRules.newFighter(weapon: string): Fighter
	return {
		weapon = weapon,
		step = 0,
		attackAt = -math.huge,
		skillAt = -math.huge,
		dashAt = -math.huge,
		gauge = 0,
		triggerUntil = -math.huge,
		guardUntil = -math.huge,
		requests = {},
	}
end

-- Refused ones count too, so spamming can't reset the window (C10).
function CombatRules.allowRequest(f: Fighter, t: number): (boolean, Fighter)
	local c = copy(f)
	local recent = {}
	for _, at in f.requests do
		if t - at < CombatRules.RATE.window then
			table.insert(recent, at)
		end
	end
	local ok = #recent < CombatRules.RATE.count
	table.insert(recent, t)
	c.requests = recent
	return ok, c
end

-- C1 combo rule.
function CombatRules.attack(f: Fighter, t: number): (boolean, Fighter, number)
	local w = weaponOf(f)
	local steps = #w.damage
	local since = t - f.attackAt
	if (f.step > 0 and f.step < steps and since < w.interval) or (f.step == steps and since < w.recovery) then
		return false, f, 0
	end
	local c = copy(f)
	c.step = if f.step < steps and since <= w.window then f.step + 1 else 1
	c.attackAt = t
	return true, c, c.step
end

function CombatRules.isFinisher(f: Fighter): boolean
	return f.step > 0 and f.step == #weaponOf(f).damage
end

function CombatRules.skill(f: Fighter, t: number, cooldown: number): (boolean, Fighter)
	if t - f.skillAt < cooldown then
		return false, f
	end
	local c = copy(f)
	c.skillAt = t
	return true, c
end

function CombatRules.dash(f: Fighter, t: number): (boolean, Fighter)
	if t - f.dashAt < CombatRules.DASH.tolerance then
		return false, f
	end
	local c = copy(f)
	c.dashAt = t
	return true, c
end

function CombatRules.triggerActive(f: Fighter, t: number): boolean
	return t < f.triggerUntil
end

function CombatRules.trigger(f: Fighter, t: number, duration: number): (boolean, Fighter)
	if f.gauge < CombatRules.TRIGGER.cost or CombatRules.triggerActive(f, t) then
		return false, f
	end
	local c = copy(f)
	c.gauge = 0
	c.triggerUntil = t + duration
	return true, c
end

function CombatRules.gain(f: Fighter, damageDealt: number, gaugeRate: number, t: number): Fighter
	if CombatRules.triggerActive(f, t) then
		return f
	end
	local c = copy(f)
	c.gauge = math.min(CombatRules.TRIGGER.cost, f.gauge + damageDealt / 4 * gaugeRate)
	return c
end

function CombatRules.flatDistance(a: Vec3, b: Vec3): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Teleport guard (C10): a root that moved more than 12 studs between 10 Hz samples.
function CombatRules.guard(f: Fighter, previous: Vec3, current: Vec3, t: number): Fighter
	if CombatRules.flatDistance(previous, current) <= CombatRules.GUARD.distance then
		return f
	end
	local c = copy(f)
	c.guardUntil = t + CombatRules.GUARD.lockout
	return c
end

function CombatRules.guarded(f: Fighter, t: number): boolean
	return t < f.guardUntil
end

-- Hit tests ----------------------------------------------------------------------------------

function CombatRules.attackSwing(weapon: Weapon): Swing
	return { range = weapon.range, arc = weapon.arc, band = CombatRules.ATTACK_BAND }
end

function CombatRules.skillSwing(shockwave: boolean): Swing
	local s = CombatRules.SKILL
	if shockwave then
		return { range = s.shockwaveRange, arc = 360, band = s.band }
	end
	return { range = s.range, arc = s.arc, band = s.band }
end

-- C2: vertical band, then point blank at any angle, or within range and arc / 2 of the facing.
function CombatRules.inSwing(origin: Vec3, facing: Vec3, target: Target, swing: Swing): boolean
	if math.abs(target.pos.y - origin.y) > swing.band then
		return false
	end
	local dx, dz = target.pos.x - origin.x, target.pos.z - origin.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local edge = dist - target.radius
	if edge <= CombatRules.POINT_BLANK then
		return true
	end
	if edge > swing.range then
		return false
	end
	if swing.arc >= 360 then
		return true
	end
	local flen = math.sqrt(facing.x * facing.x + facing.z * facing.z)
	if flen == 0 then
		return false
	end
	local cos = math.clamp((dx * facing.x + dz * facing.z) / (dist * flen), -1, 1)
	return math.deg(math.acos(cos)) <= swing.arc / 2 + 1e-9
end

-- Attacks cleave; a boss counts once, on its reachable part with the highest multiplier.
function CombatRules.hits(origin: Vec3, facing: Vec3, targets: { Target }, swing: Swing): { Target }
	local list: { Target } = {}
	local slot: { [number]: number } = {}
	for _, target in targets do
		if CombatRules.inSwing(origin, facing, target, swing) then
			local i = slot[target.id]
			if i == nil then
				table.insert(list, target)
				slot[target.id] = #list
			elseif target.mult > list[i].mult then
				list[i] = target
			end
		end
	end
	return list
end

-- C6, with the boss part multiplier as the last factor inside the round (night.md 7.1).
function CombatRules.damage(
	base: number,
	damageMult: number,
	airborne: boolean,
	trigger: boolean,
	partMult: number
): number
	local x = base * damageMult
	if airborne then
		x *= CombatRules.AIRBORNE_DAMAGE
	end
	if trigger then
		x *= CombatRules.TRIGGER.damage
	end
	return math.floor(x * partMult + 0.5 + 1e-9)
end

-- C7: (staggers, knockback multiplier).
function CombatRules.reaction(class: string, finisher: boolean, trigger: boolean): (boolean, number)
	if class == "normal" then
		return true, if finisher then 1 else 0
	elseif class == "armoured" then
		return finisher or trigger, if finisher then CombatRules.ARMOURED_KNOCKBACK else 0
	end
	return false, 0
end

function CombatRules.canLaunch(class: string): boolean
	return class == "normal"
end

function CombatRules.contact(enemyPos: Vec3, enemyRadius: number, playerPos: Vec3): boolean
	return math.abs(enemyPos.y - playerPos.y) <= CombatRules.CONTACT.band
		and CombatRules.flatDistance(enemyPos, playerPos) <= enemyRadius + CombatRules.CONTACT.reach
end

function CombatRules.nearSegment(a: Vec3, b: Vec3, pos: Vec3, width: number): boolean
	local abx, abz = b.x - a.x, b.z - a.z
	local len2 = abx * abx + abz * abz
	local u = if len2 == 0 then 0 else math.clamp(((pos.x - a.x) * abx + (pos.z - a.z) * abz) / len2, 0, 1)
	local px, pz = a.x + abx * u, a.z + abz * u
	return math.sqrt((pos.x - px) ^ 2 + (pos.z - pz) ^ 2) <= width
end

return CombatRules
