--!strict
-- Pure Gashadokuro rules (GDD D3, night.md 7.7): phases, attack order, skull stagger, part
-- multipliers and round-robin targets. No Roblox APIs, so Lune can unit-test them.

local CombatRules = require("./CombatRules")

local BossRules = {}

type Vec3 = CombatRules.Vec3

export type State = {
	phase: number,
	index: number,
	nextAt: number,
	staggerUntil: number,
	turn: number,
}

BossRules.RISE = 3
BossRules.GAP = 2.5
BossRules.STAGGER = 4
BossRules.SEQUENCES = { { "slam", "slam", "sweep" }, { "slam", "sweep", "slam" }, { "double", "sweep", "sweep" } }
BossRules.SLAM = { radius = 10, follow = 1.5, lock = 0.6, damage = 30 }
BossRules.SWEEP = { telegraph = 1.5, width = 4, feet = 4, damage = 25, halfLength = 100 }
BossRules.SUMMON = { wisp = 6, lantern = 2 }
BossRules.PART = { hand = 1.0, skull = 1.5, staggeredSkull = 2.0 }

function BossRules.new(t: number): State
	return { phase = 1, index = 1, nextAt = t + BossRules.RISE, staggerUntil = 0, turn = 0 }
end

function BossRules.phaseFor(hp: number, maxHp: number): number
	local f = hp / maxHp
	return if f > 0.66 then 1 elseif f >= 0.33 then 2 else 3
end

-- The attack to start now, if any. Until `resolved` reports it landed, nextAt stays at infinity
-- so a long telegraph can't overlap the next attack.
function BossRules.next(s: State, hp: number, maxHp: number, t: number): (string?, State)
	if t < s.nextAt then
		return nil, s
	end
	local c = table.clone(s)
	c.nextAt = math.huge
	local phase = BossRules.phaseFor(hp, maxHp)
	if phase > s.phase then
		c.phase = phase
		c.index = 1
		return "summon", c
	end
	local sequence = BossRules.SEQUENCES[s.phase]
	c.index = s.index % #sequence + 1
	return sequence[s.index], c
end

function BossRules.resolved(s: State, attack: string, t: number): State
	local c = table.clone(s)
	if attack == "slam" or attack == "double" then
		c.staggerUntil = t + BossRules.STAGGER
	end
	c.nextAt = math.max(t + BossRules.GAP, c.staggerUntil)
	return c
end

function BossRules.staggered(s: State, t: number): boolean
	return t < s.staggerUntil
end

function BossRules.partMult(part: string, staggered: boolean): number
	if part == "skull" then
		return if staggered then BossRules.PART.staggeredSkull else BossRules.PART.skull
	end
	return BossRules.PART.hand
end

-- `ids`: not-downed participants in join order. Repeats only when there are fewer than `count`.
function BossRules.targets(s: State, ids: { number }, count: number): ({ number }, State)
	if #ids == 0 then
		return {}, s
	end
	local picks = {}
	for k = 0, count - 1 do
		table.insert(picks, ids[(s.turn + k) % #ids + 1])
	end
	local c = table.clone(s)
	c.turn = s.turn + count
	return picks, c
end

-- West to east across the arena at the target's z, on the ground.
function BossRules.sweepLine(target: Vec3): (Vec3, Vec3)
	local h = BossRules.SWEEP.halfLength
	return { x = -h, y = 0, z = target.z }, { x = h, y = 0, z = target.z }
end

function BossRules.sweepHit(a: Vec3, b: Vec3, pos: Vec3, feetHeight: number): boolean
	return feetHeight < BossRules.SWEEP.feet and CombatRules.nearSegment(a, b, pos, BossRules.SWEEP.width)
end

return BossRules
