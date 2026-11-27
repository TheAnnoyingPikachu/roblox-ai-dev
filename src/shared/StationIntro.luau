--!strict
-- The intro (decision 0116, the Intro boards): a new player's first fight is with four legends on loan
-- from the Ranger, on the real field, and cannot be lost. Then the legends go home and three starter eggs
-- hatch in seconds: one animal of each class. Pure rules, no Roblox APIs: who is lent, which wave, what the
-- fight's setup is, and what finishing (or skipping) gives. The save only records that it is done.

local BattleRules = require("./BattleRules")
local LevelRules = require("./LevelRules")
local StationConfig = require("./StationConfig")
local StationProgress = require("./StationProgress")
local StationRules = require("./StationRules")

local StationIntro = {}

type Profile = StationProgress.Profile

-- One of each class, and the Titan: real animals from real eggs, never a special version.
StationIntro.TEAM = {
	{ s = "jackal", v = "sphinx_jackal" },
	{ s = "rhino", v = "lava_rhino" },
	{ s = "flamingo", v = "phoenix_flamingo" },
	{ s = "elephant", v = "war_elephant" },
}
-- The Shadow Dragon's wave. At level 1 the legends take about a minute over it untouched; with the Ranger's
-- blessing (four times their health) none of them drops under two thirds, and `immortal` is the net under
-- that: whatever the player does or does not press, the fight is won.
StationIntro.WAVE = 40
-- `patient`: a press bubble stays until the player does it or the fight ends (SHANNON, 2026-11-24)
StationIntro.SETUP = { clicks = true, maxHp = 4, immortal = true, patient = true } :: BattleRules.Setup
-- The starter eggs: Meadow Eggs that hold one animal of each class, already hatching when they are given.
StationIntro.EGG = "meadow"
StationIntro.COINS = 300 -- with the eggs, so the first Meadow Egg can be bought at once (decision 0116, amended)
StationIntro.STARTERS = { "jackal", "tortoise", "meerkat" }

-- The loan team as fighters, each at level 1.
function StationIntro.team(): { StationRules.Owned }
	local team = {}
	for _, a in StationIntro.TEAM do
		local trained = {} :: any
		for _, stat in StationConfig.STATS do
			trained[stat] = 1
		end
		table.insert(team, {
			s = a.s,
			v = a.v,
			stats = StationRules.versionStats(a.s, a.v) :: StationConfig.Stats,
			trained = trained,
		})
	end
	return team
end

-- The Ranger's loan (decision 0119; SHANNON, 2026-11-24: "Wave 10 boss, then daily", and 2026-11-25: the player
-- picks, it replaces one animal, at max level, for one wave). The first is for the first boss (LOAN_WAVE); after
-- it has been used, one a day (UTC). The legend fights in place of one of the player's own animals (a Titan for
-- the War Elephant, never a Titan for the others) for that wave only: it is never owned, only met.
StationIntro.LOAN_WAVE = LevelRules.BOSS_EVERY

function StationIntro.today(now: number): number
	return math.floor(now / 86400)
end

-- Which loan `p` may take for `wave` now: "boss", "daily" or nil.
function StationIntro.loanFor(p: Profile, wave: number, now: number): string?
	if not p.loan.boss then
		return if wave == StationIntro.LOAN_WAVE then "boss" else nil
	end
	return if p.loan.day ~= StationIntro.today(now) then "daily" else nil
end

-- Legend `k` of TEAM as the loan lends it: every stat at MAX_LEVEL.
function StationIntro.lent(k: number): StationRules.Owned?
	local a = StationIntro.TEAM[k]
	if a == nil then
		return nil
	end
	local trained = {} :: any
	for _, stat in StationConfig.STATS do
		trained[stat] = StationConfig.STAR_FROM -- level 70, no stars: the intro was tuned for it
	end
	return { s = a.s, v = a.v, stats = StationRules.versionStats(a.s, a.v) :: StationConfig.Stats, trained = trained }
end

-- Whether legend `k` may stand in for the player's fighter `replaces` (an animal id) at `wave`: (ok, code).
function StationIntro.canLend(p: Profile, k: number, replaces: number, wave: number, now: number): (boolean, string?)
	local legend = StationIntro.lent(k)
	if legend == nil then
		return false, "loan"
	elseif StationIntro.loanFor(p, wave, now) == nil then
		return false, "loan_used"
	end
	for _, a in StationProgress.fighters(p) do
		if a.id == replaces then
			local titan = StationRules.role(legend) == StationConfig.TITAN
			if titan ~= (StationRules.role(a) == StationConfig.TITAN) then
				return false, "loan_titan"
			end
			return true, nil
		end
	end
	return false, "loan_slot"
end

-- The loan is used (when its wave starts): the boss's is done, the day is today's, the legend is met.
function StationIntro.useLoan(
	p: Profile,
	k: number,
	replaces: number,
	wave: number,
	now: number
): (Profile, boolean, string?)
	local ok, code = StationIntro.canLend(p, k, replaces, wave, now)
	if not ok then
		return p, false, code
	end
	p.loan = { boss = true, day = StationIntro.today(now) }
	local a = StationIntro.TEAM[k]
	return StationProgress.meet(p, a.s, a.v), true, nil
end

-- The animals inside the starter eggs.
function StationIntro.starters(): { StationRules.Owned }
	local out = {}
	for _, s in StationIntro.STARTERS do
		table.insert(out, { s = s, stats = StationRules.versionStats(s, nil) :: StationConfig.Stats })
	end
	return out
end

-- The intro ends for `p` at `now` (won, or skipped): it is marked done and the starter eggs go into the
-- nests, hatching (into the storage when the nests are taken; dropped only when that is full too).
function StationIntro.finish(p: Profile, now: number): (Profile, boolean, string?)
	if p.intro then
		return p, false, "intro_done"
	end
	p.intro = true
	p.coins += StationIntro.COINS
	p.eggs = table.clone(p.eggs)
	local nests = StationProgress.value(p, "hatchery") - StationProgress.hatching(p)
	local room = StationProgress.value(p, "hatchery") + StationProgress.value(p, "cellar") - #p.eggs
	for _, animal in StationIntro.starters() do
		if room > 0 then
			table.insert(p.eggs, {
				egg = StationIntro.EGG,
				since = if nests > 0 then now else nil,
				animal = animal,
				quick = true,
			})
			nests -= 1
			room -= 1
		end
	end
	return p, true, nil
end

return StationIntro
