--!strict
-- Pure Animal Stations battles (decisions 0024, 0027): team against team, used by the endless
-- levels and later by PvP. Every animal has a role from its species: Attack hits hard, Defense
-- draws every hit and takes less damage, Utility heals the most hurt teammate. A Titan (the
-- team's fourth slot) has no special job: it is simply huge and neutral in every matchup.
-- Deterministic: same teams, same result.

local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local BattleRules = {}

type Owned = StationRules.Owned
export type Fighter = {
	role: string,
	hp: number,
	maxHp: number,
	atk: number,
	spd: number,
	side: number,
	slot: number,
}

BattleRules.ATTACK_BONUS = 1.3 -- Attack: damage x this
BattleRules.GUARD = 0.8 -- Defense: enemies must target it while it stands, and it takes damage x this
BattleRules.HEAL = 0.5 -- Utility: after attacking, heals the most hurt teammate by atk x this
BattleRules.MAX_TURNS = 1000 -- a battle this long is a loss for side 1 (heals could stall it)

-- An animal's battle numbers: HP from all four stats, attack from its best stat, speed decides
-- the order.
function BattleRules.fighter(animal: Owned, side: number, slot: number): Fighter
	local total = 0
	for _, stat in StationConfig.STATS do
		total += StationRules.stat(animal, stat)
	end
	local role = StationRules.role(animal)
	local hp = 20 + math.floor(total / 2)
	local atk = 4 + math.floor(StationRules.stat(animal, StationRules.bestStat(animal)) / 4)
	if role == "attack" then
		atk = math.floor(atk * BattleRules.ATTACK_BONUS)
	end
	return {
		role = role,
		hp = hp,
		maxHp = hp,
		atk = atk,
		spd = StationRules.stat(animal, "speed"),
		side = side,
		slot = slot,
	}
end

local function alive(team: { Fighter }): boolean
	for _, f in team do
		if f.hp > 0 then
			return true
		end
	end
	return false
end

-- The enemy to hit: the first standing Defense animal, else the first standing animal.
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

-- Fight team 1 against team 2. Each round every standing animal acts once, fastest first (ties:
-- side 1, then slot order). Returns whether side 1 won and how many actions happened.
-- In PvP the caller decides which player is side 1, since side 1 wins speed ties.
function BattleRules.battle(one: { Owned }, two: { Owned }): (boolean, number)
	local sides: { { Fighter } } = { {}, {} }
	for s, list in { one, two } do
		for i, a in list do
			table.insert(sides[s], BattleRules.fighter(a, s, i))
		end
	end
	local order = table.clone(sides[1])
	for _, f in sides[2] do
		table.insert(order, f)
	end
	table.sort(order, function(a: Fighter, b: Fighter): boolean
		if a.spd ~= b.spd then
			return a.spd > b.spd
		elseif a.side ~= b.side then
			return a.side < b.side
		end
		return a.slot < b.slot
	end)
	local turns = 0
	while alive(sides[1]) and alive(sides[2]) and turns < BattleRules.MAX_TURNS do
		for _, f in order do
			if f.hp > 0 then
				local mine, foes = sides[f.side], sides[3 - f.side]
				local d = target(foes)
				if d == nil then
					break
				end
				local guard = if d.role == "defense" then BattleRules.GUARD else 1
				d.hp -= math.max(1, math.floor(f.atk * StationRules.matchup(f.role, d.role) * guard))
				turns += 1
				if f.role == "utility" then
					local hurt: Fighter? = nil
					for _, m in mine do
						if m.hp > 0 and (hurt == nil or m.hp / m.maxHp < hurt.hp / hurt.maxHp) then
							hurt = m
						end
					end
					if hurt then
						hurt.hp = math.min(hurt.maxHp, hurt.hp + math.floor(f.atk * BattleRules.HEAL))
					end
				end
			end
		end
	end
	return alive(sides[1]) and not alive(sides[2]), turns
end

return BattleRules
