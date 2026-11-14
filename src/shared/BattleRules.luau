--!strict
-- Pure Animal Stations wave fights (decisions 0027 to 0032): the player's team against a wave
-- of enemies, on a clock. This is for the waves only: fights between players will work
-- differently and are not designed. Each stat has one job:
--   Health    HP
--   Defence   cuts incoming damage
--   Strength  damage per attack
--   Speed     attack speed: a shorter swing
--   Stamina   a shorter rest between attacks
--   Mana      energy per attack towards the power attack
-- Roles come from the species (or the foe): Attack hits harder, Defence draws every hit and takes less,
-- Utility also heals the most hurt teammate with every attack. The Titan (the team's fourth
-- slot) has no special job. Pack and solitary animals get group bonuses.
-- Deterministic: same teams, same result, so the server can decide and replay any fight.

local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local BattleRules = {}

type Owned = StationRules.Owned
export type Fighter = {
	role: string,
	group: string?,
	hp: number,
	maxHp: number,
	dmg: number,
	def: number,
	swing: number, -- seconds an attack takes
	rest: number, -- seconds of rest before the next attack
	gain: number, -- energy per attack
	energy: number, -- the power meter
	next: number, -- when its next attack lands
	side: number,
	slot: number,
}

BattleRules.HP_BASE, BattleRules.HP_PER_HEALTH = 20, 1.5
BattleRules.DMG_BASE, BattleRules.DMG_PER_STRENGTH = 4, 0.25
BattleRules.DEF_HALF = 100 -- incoming damage x DEF_HALF / (DEF_HALF + Defence): 100 Defence halves it
-- An attack takes SWING seconds, then the animal rests REST seconds. Speed shortens the swing and
-- Stamina the rest, each by TEMPO_HALF / (TEMPO_HALF + stat): 100 of the stat halves its time.
BattleRules.SWING, BattleRules.REST, BattleRules.TEMPO_HALF = 1.5, 1.5, 100
-- Power attacks: every attack adds POWER_GAIN + Mana energy; at POWER_COST that attack's damage
-- and heal are x POWER and the cost is spent.
BattleRules.POWER_GAIN, BattleRules.POWER_COST, BattleRules.POWER = 10, 200, 2
BattleRules.ATTACK_BONUS = 1.3 -- Attack: damage x this
BattleRules.GUARD = 0.8 -- Defence: enemies must target it while it stands, and it takes damage x this
BattleRules.HEAL_PCT = 8 -- Utility: each attack also heals the most hurt teammate by this % of the healer's own max HP
BattleRules.MAX_SECONDS = 300 -- a fight this long is a loss for side 1 (heals could stall it)
BattleRules.MAX_ACTIONS = 5000 -- backstop for absurd stats; also a loss for side 1

-- One animal's battle numbers before group bonuses. Each stat feeds exactly one of them.
function BattleRules.fighter(animal: Owned, side: number, slot: number): Fighter
	local sp = StationConfig.species(animal.s) or StationConfig.foe(animal.s)
	local role = StationRules.role(animal)
	local function stat(name: StationConfig.Stat): number
		return StationRules.stat(animal, name)
	end
	local hp = BattleRules.HP_BASE + math.floor(stat("health") * BattleRules.HP_PER_HEALTH)
	local dmg = BattleRules.DMG_BASE + math.floor(stat("strength") * BattleRules.DMG_PER_STRENGTH)
	if role == "attack" then
		dmg = math.floor(dmg * BattleRules.ATTACK_BONUS)
	end
	local half = BattleRules.TEMPO_HALF
	local swing = BattleRules.SWING * half / (half + stat("speed"))
	return {
		role = role,
		group = if sp then sp.group else nil,
		hp = hp,
		maxHp = hp,
		dmg = dmg,
		def = stat("defence"),
		swing = swing,
		rest = BattleRules.REST * half / (half + stat("stamina")),
		gain = BattleRules.POWER_GAIN + stat("mana"),
		energy = 0,
		next = swing, -- the first attack lands after one swing, so the faster animal strikes first
		side = side,
		slot = slot,
	}
end

-- A whole team ready to fight, with the group bonuses on damage and HP: a pack animal gains
-- PACK_PCT % for each other pack animal, a solitary animal SOLITARY_PCT % when no teammate
-- shares its role.
function BattleRules.lineup(team: { Owned }, side: number): { Fighter }
	local out = {}
	for i, a in team do
		table.insert(out, BattleRules.fighter(a, side, i))
	end
	for _, f in out do
		local pct = 0
		if f.group == "pack" then
			for _, m in out do
				if m ~= f and m.group == "pack" then
					pct += StationConfig.PACK_PCT
				end
			end
		elseif f.group == "solitary" then
			pct = StationConfig.SOLITARY_PCT
			for _, m in out do
				if m ~= f and m.role == f.role then
					pct = 0
				end
			end
		end
		f.dmg = math.floor(f.dmg * (100 + pct) / 100)
		f.maxHp = math.floor(f.maxHp * (100 + pct) / 100)
		f.hp = f.maxHp
	end
	return out
end

local function alive(team: { Fighter }): boolean
	for _, f in team do
		if f.hp > 0 then
			return true
		end
	end
	return false
end

-- The enemy to hit: the first standing Defence animal, else the first standing animal.
local function target(foes: { Fighter }): Fighter?
	local first: Fighter? = nil
	for _, f in foes do
		if f.hp > 0 then
			if f.role == "defense" then
				return f
			end
			first = first or f
		end
	end
	return first
end

-- Fight the player's team (side 1) against a wave (side 2) on a clock: whoever's attack is due
-- next acts (ties go to side 1, then the lower slot). Returns whether the team won, how many
-- attacks happened and how many seconds the fight took.
function BattleRules.battle(one: { Owned }, two: { Owned }): (boolean, number, number)
	local sides = { BattleRules.lineup(one, 1), BattleRules.lineup(two, 2) }
	local all = table.clone(sides[1])
	for _, f in sides[2] do
		table.insert(all, f)
	end
	local actions, now = 0, 0
	while alive(sides[1]) and alive(sides[2]) and actions < BattleRules.MAX_ACTIONS do
		local f: Fighter? = nil
		for _, c in all do -- `all` is in side then slot order, so a strict < breaks ties that way
			if c.hp > 0 and (f == nil or c.next < f.next) then
				f = c
			end
		end
		local me = f :: Fighter
		if me.next > BattleRules.MAX_SECONDS then
			break
		end
		now = me.next
		local d = target(sides[3 - me.side]) :: Fighter
		local power = 1
		me.energy += me.gain
		if me.energy >= BattleRules.POWER_COST then
			me.energy -= BattleRules.POWER_COST
			power = BattleRules.POWER
		end
		local hit = me.dmg * power
		if d.role == "defense" then
			hit *= BattleRules.GUARD
		end
		-- Defence last, as one division, so exact results stay exact
		d.hp -= math.max(1, math.floor(hit * BattleRules.DEF_HALF / (BattleRules.DEF_HALF + d.def)))
		if me.role == "utility" then
			local hurt: Fighter? = nil
			for _, m in sides[me.side] do
				if m.hp > 0 and (hurt == nil or m.hp / m.maxHp < hurt.hp / hurt.maxHp) then
					hurt = m
				end
			end
			if hurt then
				local heal = math.floor(me.maxHp * BattleRules.HEAL_PCT * power / 100)
				hurt.hp = math.min(hurt.maxHp, hurt.hp + heal)
			end
		end
		actions += 1
		me.next = now + me.rest + me.swing
	end
	return alive(sides[1]) and not alive(sides[2]), actions, now
end

return BattleRules
