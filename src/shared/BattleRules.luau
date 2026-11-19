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
-- attacks happened and how many seconds the fight took. `log`, when given, is filled with one
-- entry per attack, in order, so the fight can be shown: when it landed (`t`), who hit (`side`,
-- `slot`), whom (`tside`, `tslot`), the damage dealt (`dmg`) and the target's HP after it (`hp`),
-- whether it was a power attack (`power`, and `tap` when the player fired it), the attacker's power
-- meter after it (`energy`, 0 to 1) and, for a healer, who it healed and to what HP
-- (`heal` = { slot, hp }, on the healer's own side). It never changes the result.
--
-- With `taps` (decision 0092) the player fires their team's power attacks: side 1's meters fill and
-- hold, and a power attack is an extra strike on top of the animal's own attacks, landing at a tap's
-- time `t` for the animal in `slot`, if its meter is full then (a tap at any other time does
-- nothing). A full meter nobody taps fires itself AUTO_FIRE seconds after it filled. A tap changes
-- nothing before its own time, so the server can replay a fight from the start with each new tap.
-- Without `taps` every power attack fires itself on the attack that fills the meter.
BattleRules.AUTO_FIRE = 4
export type Hit = {
	t: number,
	side: number,
	slot: number,
	tside: number,
	tslot: number,
	dmg: number,
	hp: number,
	power: boolean,
	tap: boolean?,
	energy: number,
	heal: { slot: number, hp: number }?,
}
export type Tap = { slot: number, t: number }
function BattleRules.battle(one: { Owned }, two: { Owned }, log: { Hit }?, taps: { Tap }?): (boolean, number, number)
	local sides = { BattleRules.lineup(one, 1), BattleRules.lineup(two, 2) }
	local all = table.clone(sides[1])
	for _, f in sides[2] do
		table.insert(all, f)
	end
	local held = taps ~= nil
	local queue: { Tap } = if taps then table.clone(taps) else {}
	table.sort(queue, function(a, b)
		return a.t < b.t
	end)
	local full: { [Fighter]: number } = {} -- when each held meter filled
	local actions, now = 0, 0

	-- `me` attacks at `now`; `power` x damage and heal
	local function strike(me: Fighter, power: number, tapped: boolean?)
		local d = target(sides[3 - me.side]) :: Fighter
		local hit = me.dmg * power
		if d.role == "defense" then
			hit *= BattleRules.GUARD
		end
		-- Defence last, as one division, so exact results stay exact
		local dealt = math.max(1, math.floor(hit * BattleRules.DEF_HALF / (BattleRules.DEF_HALF + d.def)))
		d.hp -= dealt
		local entry: Hit? = nil
		if log then
			entry = {
				t = now,
				side = me.side,
				slot = me.slot,
				tside = d.side,
				tslot = d.slot,
				dmg = dealt,
				hp = d.hp,
				power = power > 1,
				tap = tapped,
				energy = math.min(1, me.energy / BattleRules.POWER_COST),
			}
			table.insert(log, entry :: Hit)
		end
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
				if entry then
					entry.heal = { slot = hurt.slot, hp = hurt.hp }
				end
			end
		end
		actions += 1
	end

	while alive(sides[1]) and alive(sides[2]) and actions < BattleRules.MAX_ACTIONS do
		local f: Fighter? = nil
		for _, c in all do -- `all` is in side then slot order, so a strict < breaks ties that way
			if c.hp > 0 and (f == nil or c.next < f.next) then
				f = c
			end
		end
		local me = f :: Fighter
		-- a held power attack due first: a tap, else a meter firing itself (ties before attacks)
		local auto: Fighter?, autoAt = nil, math.huge
		for _, c in sides[1] do
			local at = full[c]
			if at and c.hp > 0 and at + BattleRules.AUTO_FIRE < autoAt then
				auto, autoAt = c, at + BattleRules.AUTO_FIRE
			end
		end
		local tap = queue[1]
		if tap and tap.t <= autoAt and tap.t <= me.next then
			table.remove(queue, 1)
			local c = sides[1][tap.slot]
			if c and c.hp > 0 and full[c] and tap.t >= full[c] then
				if tap.t > BattleRules.MAX_SECONDS then
					break
				end
				now = math.max(now, tap.t)
				full[c] = nil
				c.energy -= BattleRules.POWER_COST
				strike(c, BattleRules.POWER, true)
			end
			continue
		end
		if auto and autoAt <= me.next then
			if autoAt > BattleRules.MAX_SECONDS then
				break
			end
			now = autoAt
			full[auto] = nil
			auto.energy -= BattleRules.POWER_COST
			strike(auto, BattleRules.POWER)
			continue
		end
		if me.next > BattleRules.MAX_SECONDS then
			break
		end
		now = me.next
		local power = 1
		if held and me.side == 1 then -- fills and holds; the strike comes from a tap or AUTO_FIRE
			me.energy = math.min(BattleRules.POWER_COST, me.energy + me.gain)
			if me.energy >= BattleRules.POWER_COST and full[me] == nil then
				full[me] = now
			end
		else
			me.energy += me.gain
			if me.energy >= BattleRules.POWER_COST then
				me.energy -= BattleRules.POWER_COST
				power = BattleRules.POWER
			end
		end
		strike(me, power)
		me.next = now + me.rest + me.swing
	end
	return alive(sides[1]) and not alive(sides[2]), actions, now
end

return BattleRules
