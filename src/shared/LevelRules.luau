--!strict
-- Pure Animal Stations wave rules (decisions 0023, 0032, 0040): a line of LAST waves ("levels"
-- in this file, decision 0107), each an enemy team of three of the Shadow Legion (StationConfig.FOES: knights,
-- archers, mages, ogres, cavalry, golems and dragons) that grows stronger, fought by the player's team (BattleRules). Clearing one
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
LevelRules.REWARD_GROWTH = 1.055 -- SHANNON, 2026-11-24: was 1.08 (394 billion for wave 300); eggs repriced with it (0110)
LevelRules.REPLAY_PCT = 40 -- replaying a cleared level pays this % of its reward (decision 0121: was 25)
LevelRules.XP_START, LevelRules.XP_PER_LEVEL = 10, 4 -- player XP for a first clear: 10 + 4 per wave
LevelRules.SAMPLE_EVERY = 5 -- a first clear drops a sample per this many waves (boss waves drop double)

-- The last wave, and the steep waves before it (decision 0107). Up to STEEP_FROM every stat grows
-- SCALE_GROWTH a wave. After it the Legion gets no faster (speed, stamina, mana and defence hold: left to
-- grow, a swing shrinks to nothing and a fight is a blur) and health and strength grow instead: by
-- STEEP_GROWTH on the first steep wave and by more on every wave after (twice the exponent STEEP_BEND / 2
-- waves on), so however fast a run's boons stack (WaveRuns), the waves outgrow them and end in a wall.
LevelRules.LAST = 300
LevelRules.STEEP_FROM, LevelRules.STEEP_GROWTH, LevelRules.STEEP_BEND = 100, 1.013, 200 -- retuned for the small boons (0110)
LevelRules.STEEP_STATS = { health = true, strength = true } :: { [string]: boolean }
-- The last wall (decision 0121, SHANNON: wave 300 stays out of reach): after END_FROM health and strength
-- also grow END_GROWTH a wave on top, so the best runs end before 300 and everything up to END_FROM is as it was.
LevelRules.END_FROM, LevelRules.END_GROWTH = 250, 1.08

-- What every stat of a foe is multiplied by at `level`.
function LevelRules.scale(level: number): number
	return LevelRules.SCALE_START * LevelRules.SCALE_GROWTH ^ (math.min(level, LevelRules.STEEP_FROM) - 1)
end

-- What its health and strength (STEEP_STATS) are multiplied by on top of that: 1 up to STEEP_FROM.
function LevelRules.might(level: number): number
	local n = math.max(0, level - LevelRules.STEEP_FROM)
	local e = math.max(0, level - LevelRules.END_FROM)
	return LevelRules.STEEP_GROWTH ^ (n * (1 + n / LevelRules.STEEP_BEND)) * LevelRules.END_GROWTH ^ e
end

-- Stages (decision 0106, display only): STAGE waves each, so every stage ends on a boss wave. Stage 6 and
-- every one after it is The Ancient.
LevelRules.STAGE = LevelRules.BOSS_EVERY
LevelRules.STAGE_NAMES = { "The Vanguard", "The Charge", "The Siege", "The Dark Host", "The Dark Host" }
export type Stage = { n: number, name: string, first: number, last: number }
function LevelRules.stage(level: number): Stage
	local n = (math.max(1, level) - 1) // LevelRules.STAGE + 1
	return {
		n = n,
		name = LevelRules.STAGE_NAMES[n] or "The Ancient",
		first = (n - 1) * LevelRules.STAGE + 1,
		last = n * LevelRules.STAGE,
	}
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

-- The three-foe wave of decision 0040 for `level`: always the same for the same level. Three foes drawn
-- from the line (knights at first, ogres from wave 5, the warlord from 15); on every 10th level the last
-- one is a dragon instead. The swarm waves (`enemies`) are matched to its power.
function LevelRules.classic(level: number): { Owned }
	local pool: { StationConfig.Foe } = {}
	for _, f in StationConfig.FOES do
		if f.from and level >= f.from and not f.minion then
			table.insert(pool, f)
		end
	end
	local rng = Rng.seed(level, 23)
	local k, might = LevelRules.scale(level), LevelRules.might(level)
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
			-- enemies are not capped at STAT_MAX
			local mult = if LevelRules.STEEP_STATS[stat] then k * might else k
			stats[stat] = math.max(StationConfig.STAT_MIN, math.floor((foe.stats :: any)[stat] * mult))
		end
		table.insert(team, { s = foe.id, stats = stats :: StationConfig.Stats })
	end
	return team
end

-- Swarm waves (decision 0101): how many foes a wave sends, in how many rushes, how many of them are elites
-- (a regular x ELITE in every stat, shown in gold) and how many minions (none since the Gloom Imp left
-- with the Hexbound, decision 0104: the crowd is all regulars). The row with the
-- highest `from` the wave has reached applies. `power` is the swarm's power over the classic wave's: a
-- crowd's power sum is worth less against the team's splash, crowd power attacks and the front line, so
-- bigger crowds carry more to stay as hard (set so 98% of test fights end as against the classic waves).
LevelRules.CROWDS = {
	{ from = 1, count = 4, rushes = 1, elites = 0, minions = 0, power = 1 },
	{ from = 5, count = 6, rushes = 1, elites = 0, minions = 0, power = 1.1 },
	{ from = 10, count = 8, rushes = 2, elites = 0, minions = 0, power = 1.4 },
	{ from = 20, count = 12, rushes = 2, elites = 1, minions = 0, power = 1.75 },
	{ from = 40, count = 16, rushes = 3, elites = 2, minions = 0, power = 2.1 },
}
LevelRules.ELITE = 1.6
LevelRules.CROWD_POWER = 1 -- a swarm wave's power over the classic wave's
LevelRules.MATCH = 0.05 -- how close (a share) the swarm's power must come to that
-- Shared fights (decision 0108): for two and three players' teams the crowd has PARTY_COUNT times the foes
-- (and elites) and PARTY_POWER times the power. The power grows by less than a whole wave's for each
-- player, so a wave is easier fought together.
LevelRules.PARTY_COUNT = { 1, 1.5, 2 }
LevelRules.PARTY_POWER = { 1, 1.6, 2.1 }

export type Crowd = { from: number, count: number, rushes: number, elites: number, minions: number, power: number? }
function LevelRules.crowd(level: number): Crowd
	local row = LevelRules.CROWDS[1]
	for _, r in LevelRules.CROWDS do
		if level >= r.from then
			row = r
		end
	end
	return row
end

local function scaled(foe: StationConfig.Foe, mult: number, might: number): StationConfig.Stats
	local stats = {} :: any
	for _, stat in StationConfig.STATS do
		local by = if LevelRules.STEEP_STATS[stat] then mult * might else mult
		stats[stat] = math.max(StationConfig.STAT_MIN, math.floor((foe.stats :: any)[stat] * by))
	end
	return stats
end

-- The enemy team for `level`: always the same for the same level. LevelRules.crowd says how many; each
-- rush sends its minions first, then its regulars (drawn from the classic line), elites last; a boss
-- wave's dragon comes last of all. Every stat is then scaled by one number so the wave's power
-- (BattleRules.teamPower) is within MATCH of CROWD_POWER x the classic wave's. For `players` teams (1 to 3,
-- decision 0108) the crowd is PARTY_COUNT times as many and PARTY_POWER times as strong, with one boss.
function LevelRules.enemies(level: number, players: number?): { Owned }
	local party = math.clamp(players or 1, 1, #LevelRules.PARTY_COUNT)
	local row = table.clone(LevelRules.crowd(level))
	row.count = math.floor(row.count * LevelRules.PARTY_COUNT[party] + 0.5)
	row.elites = math.floor(row.elites * LevelRules.PARTY_COUNT[party] + 0.5)
	local pool: { StationConfig.Foe } = {}
	local imp: StationConfig.Foe? = nil
	for _, f in StationConfig.FOES do
		if f.minion then
			imp = imp or f
		elseif f.from and level >= f.from then
			table.insert(pool, f)
		end
	end
	local rng = Rng.seed(level, 41)
	local members: { { foe: StationConfig.Foe, rush: number, elite: boolean } } = {}
	local regulars = row.count - row.minions
	for r = 1, row.rushes do
		local function share(total: number): number -- this rush's part of `total`, spread evenly
			return (total * r) // row.rushes - (total * (r - 1)) // row.rushes
		end
		for _ = 1, share(row.minions) do
			table.insert(members, { foe = imp :: StationConfig.Foe, rush = r, elite = false })
		end
		local mine, elites = share(regulars), share(row.elites)
		for i = 1, mine do
			local n
			n, rng = Rng.int(rng, 1, #pool)
			table.insert(members, { foe = pool[n], rush = r, elite = i > mine - elites })
		end
	end
	if level % LevelRules.BOSS_EVERY == 0 then
		local dragon = LevelRules.boss(level)
		if dragon then -- the boss takes the last regular's place
			members[#members] = { foe = dragon, rush = row.rushes, elite = false }
		end
	end
	local k, might = LevelRules.scale(level), LevelRules.might(level)
	local function build(m: number): { Owned }
		local team = {}
		for _, x in members do
			local mult = k * m * (if x.elite then LevelRules.ELITE else 1)
			table.insert(team, {
				s = x.foe.id,
				stats = scaled(x.foe, mult, might),
				rush = x.rush,
				elite = if x.elite then true else nil,
			})
		end
		return team
	end
	-- one number for every stat, found by halving, so the swarm is as strong as the wave it replaces
	local want = BattleRules.teamPower(LevelRules.classic(level), 2)
		* (row.power or LevelRules.CROWD_POWER)
		* LevelRules.PARTY_POWER[party]
	local lo, hi = 0.02, 8
	local best, bestGap = build(1), math.huge
	for _ = 1, 40 do
		local mid = (lo + hi) / 2
		local team = build(mid)
		local got = BattleRules.teamPower(team, 2)
		local gap = math.abs(got - want) / math.max(1, want)
		if gap < bestGap then
			best, bestGap = team, gap
		end
		if gap <= LevelRules.MATCH / 2 then
			break
		elseif got < want then
			lo = mid
		else
			hi = mid
		end
	end
	return best
end

-- How strong wave `level` is, as a power score to weigh a team against (decision 0096): the classic
-- wave's, which its swarm is as hard as.
function LevelRules.power(level: number): number
	return BattleRules.teamPower(LevelRules.classic(level), 2)
end

-- Whether `team` clears `level`, how many attacks the fight took, how many seconds, and the team's HP
-- at the end (shares by slot). With `taps` the player fires the power attacks (BattleRules.battle; `{}`
-- is a fight nobody taps in); `setup` is a run's carried HP and boons. A team of several players' teams
-- (BattleRules.players) meets the crowd for that many.
function LevelRules.fight(
	team: { Owned },
	level: number,
	taps: { BattleRules.Tap }?,
	setup: BattleRules.Setup?
): (boolean, number, number, { number })
	return BattleRules.battle(team, LevelRules.enemies(level, BattleRules.players(team)), nil, taps, setup)
end

-- Stars for a fight (decision 0097): one for the win, one when none of the team was knocked out, one when
-- the player fired every power attack themselves (none fired itself, `missed` 0). A fight that ends
-- before a meter fills earns it too: there was nothing to fire.
function LevelRules.stars(won: boolean, knockedOut: boolean, missed: number): number
	if not won then
		return 0
	end
	return 1 + (if knockedOut then 0 else 1) + (if missed == 0 then 1 else 0)
end

-- How many of the team's power attacks in `log` were left to run out (BattleRules.AUTO_FIRE) instead of
-- being tapped.
function LevelRules.missed(log: { BattleRules.Hit }): number
	local n = 0
	for _, e in log do
		if e.side == 1 and (e.power or e.fail) and not e.tap then
			n += 1
		end
	end
	return n
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
