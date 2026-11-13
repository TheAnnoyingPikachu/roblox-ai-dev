--!strict
-- Pure Animal Stations level rules (decision 0023): an endless line of levels, each an enemy team
-- of three that grows stronger, fought by the player's team of three (BattleRules). Clearing a
-- level pays coins. Draft numbers; balance comes later.

local BattleRules = require("./BattleRules")
local Rng = require("./Rng")
local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local LevelRules = {}

type Owned = StationRules.Owned

LevelRules.TEAM_SIZE = 3
LevelRules.SCALE_START = 0.6 -- level 1 enemies have 60% of their basic stats
LevelRules.SCALE_GROWTH = 1.04 -- and 4% more every level after
LevelRules.BOSS_EVERY = 10 -- every 10th level's last enemy is a variant
LevelRules.REWARD_START = 40 -- coins for clearing level 1 the first time
LevelRules.REWARD_GROWTH = 1.08
LevelRules.REPLAY_PCT = 25 -- replaying a cleared level pays this % of its reward

-- Species unlock for enemies as levels rise: commons from 1, uncommons from 5, rares from 15.
local UNLOCK = { common = 1, uncommon = 5, rare = 15 }
-- Boss variant tier by level.
local BOSS_TIER = { { level = 60, tier = "mythic" }, { level = 30, tier = "legendary" }, { level = 1, tier = "epic" } }

function LevelRules.scale(level: number): number
	return LevelRules.SCALE_START * LevelRules.SCALE_GROWTH ^ (level - 1)
end

-- The enemy team for `level`: always the same for the same level.
function LevelRules.enemies(level: number): { Owned }
	local pool = {}
	for _, sp in StationConfig.SPECIES do
		if level >= UNLOCK[sp.rarity] then
			table.insert(pool, sp)
		end
	end
	local rng = Rng.seed(level, 23)
	local k = LevelRules.scale(level)
	local team = {}
	for i = 1, LevelRules.TEAM_SIZE do
		local n
		n, rng = Rng.int(rng, 1, #pool)
		local sp = pool[n]
		local variantId: string? = nil
		if i == LevelRules.TEAM_SIZE and level % LevelRules.BOSS_EVERY == 0 then
			for _, b in BOSS_TIER do
				if level >= b.level then
					for _, va in sp.variants do
						if va.tier == b.tier then
							variantId = va.id
						end
					end
					break
				end
			end
		end
		local base = StationRules.versionStats(sp.id, variantId) :: StationConfig.Stats
		local stats = {} :: any
		for _, stat in StationConfig.STATS do
			-- enemies are not capped at STAT_MAX, so the levels never run out
			stats[stat] = math.max(StationConfig.STAT_MIN, math.floor((base :: any)[stat] * k))
		end
		table.insert(team, { s = sp.id, v = variantId, stats = stats :: StationConfig.Stats })
	end
	return team
end

-- Whether `team` clears `level`, and how many actions the battle took.
function LevelRules.fight(team: { Owned }, level: number): (boolean, number)
	return BattleRules.battle(team, LevelRules.enemies(level))
end

-- Coins for clearing `level` when the player's best cleared level is `best` (0 = none).
function LevelRules.reward(level: number, best: number): number
	local full = math.floor(LevelRules.REWARD_START * LevelRules.REWARD_GROWTH ^ (level - 1))
	return if level > best then full else math.floor(full * LevelRules.REPLAY_PCT / 100)
end

return LevelRules
