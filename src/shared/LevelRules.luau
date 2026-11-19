--!strict
-- Pure Animal Stations wave rules (decisions 0023, 0032, 0040): an endless line of waves ("levels"
-- in this file), each an enemy team of three Hexbound (StationConfig.FOES: evil magic knights,
-- ogres and dragons) that grows stronger, fought by the player's team (BattleRules). Clearing one
-- pays coins. Draft numbers; balance comes later.

local BattleRules = require("./BattleRules")
local Rng = require("./Rng")
local StationConfig = require("./StationConfig")
local StationRules = require("./StationRules")

local LevelRules = {}

type Owned = StationRules.Owned

LevelRules.TEAM_SIZE = 3
LevelRules.SCALE_START = 0.6 -- level 1 enemies have 60% of their basic stats
LevelRules.SCALE_GROWTH = 1.03 -- and 3% more every level after
LevelRules.BOSS_EVERY = 10 -- every 10th level's last enemy is a dragon
LevelRules.REWARD_START = 40 -- coins for clearing level 1 the first time
LevelRules.REWARD_GROWTH = 1.08
LevelRules.REPLAY_PCT = 25 -- replaying a cleared level pays this % of its reward
LevelRules.XP_START, LevelRules.XP_PER_LEVEL = 10, 4 -- player XP for a first clear: 10 + 4 per wave
LevelRules.SAMPLE_EVERY = 5 -- a first clear drops a sample per this many waves (boss waves drop double)

function LevelRules.scale(level: number): number
	return LevelRules.SCALE_START * LevelRules.SCALE_GROWTH ^ (level - 1)
end

-- The dragon that ends boss level `level`: the one with the highest `boss` threshold the level has
-- reached. Nil before the first dragon.
function LevelRules.boss(level: number): StationConfig.Foe?
	local best: StationConfig.Foe? = nil
	for _, f in StationConfig.FOES do
		if f.boss and level >= f.boss and (best == nil or f.boss > (best.boss :: number)) then
			best = f
		end
	end
	return best
end

-- The enemy team for `level`: always the same for the same level. Three foes drawn from the line
-- (knights at first, ogres from wave 5, the warlord from 15); on every 10th level the last one is
-- a dragon instead.
function LevelRules.enemies(level: number): { Owned }
	local pool: { StationConfig.Foe } = {}
	for _, f in StationConfig.FOES do
		if f.from and level >= f.from then
			table.insert(pool, f)
		end
	end
	local rng = Rng.seed(level, 23)
	local k = LevelRules.scale(level)
	local team = {}
	for i = 1, LevelRules.TEAM_SIZE do
		local n
		n, rng = Rng.int(rng, 1, #pool)
		local foe = pool[n]
		if i == LevelRules.TEAM_SIZE and level % LevelRules.BOSS_EVERY == 0 then
			foe = LevelRules.boss(level) or foe
		end
		local stats = {} :: any
		for _, stat in StationConfig.STATS do
			-- enemies are not capped at STAT_MAX, so the levels never run out
			stats[stat] = math.max(StationConfig.STAT_MIN, math.floor((foe.stats :: any)[stat] * k))
		end
		table.insert(team, { s = foe.id, stats = stats :: StationConfig.Stats })
	end
	return team
end

-- Whether `team` clears `level`, how many attacks the fight took, how many seconds, and the team's HP
-- at the end (shares by slot). With `taps` the player fires the power attacks (BattleRules.battle; `{}`
-- is a fight nobody taps in); `setup` is a run's carried HP and boons.
function LevelRules.fight(
	team: { Owned },
	level: number,
	taps: { BattleRules.Tap }?,
	setup: BattleRules.Setup?
): (boolean, number, number, { number })
	return BattleRules.battle(team, LevelRules.enemies(level), nil, taps, setup)
end

-- Stars for a fight (decision 0097): one for the win, one when none of the team was knocked out, one for
-- a win within `target` seconds (nil: any win). The target is `LevelRules.target`.
function LevelRules.stars(won: boolean, knockedOut: boolean, seconds: number, target: number?): number
	if not won then
		return 0
	end
	return 1 + (if knockedOut then 0 else 1) + (if target == nil or seconds <= target then 1 else 0)
end

-- The time to beat for the third star: STAR_TIME of `par`, the seconds the fight takes with nobody
-- tapping, or `par` itself when no power attack could be fired in it (`couldTap` false). Nil when nobody
-- tapping would lose: then any win earns it.
LevelRules.STAR_TIME = 0.95
function LevelRules.target(par: number?, couldTap: boolean): number?
	if par == nil then
		return nil
	end
	return if couldTap then par * LevelRules.STAR_TIME else par
end

-- Coins for clearing `level` when the player's best cleared level is `best` (0 = none).
function LevelRules.reward(level: number, best: number): number
	local full = math.floor(LevelRules.REWARD_START * LevelRules.REWARD_GROWTH ^ (level - 1))
	return if level > best then full else math.floor(full * LevelRules.REPLAY_PCT / 100)
end

-- Player XP for clearing `level` (the same replay cut as coins).
function LevelRules.xp(level: number, best: number): number
	local full = LevelRules.XP_START + LevelRules.XP_PER_LEVEL * level
	return if level > best then full else math.floor(full * LevelRules.REPLAY_PCT / 100)
end

-- Samples dropped by clearing `level`: none before wave 5, more as the waves go on, double from a
-- boss wave. These pay for the higher ranch upgrades.
function LevelRules.samples(level: number, best: number): number
	local full = math.floor(level / LevelRules.SAMPLE_EVERY)
	if level % LevelRules.BOSS_EVERY == 0 then
		full *= 2
	end
	return if level > best then full else math.floor(full * LevelRules.REPLAY_PCT / 100)
end

return LevelRules
