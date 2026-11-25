--!strict
-- The intro (decision 0116, the Intro boards): a new player's first fight is with four legends on loan
-- from the Ranger, on the real field, and cannot be lost. Then the legends go home and three starter eggs
-- hatch in seconds: one animal of each class. Pure rules, no Roblox APIs: who is lent, which wave, what the
-- fight's setup is, and what finishing (or skipping) gives. The save only records that it is done.

local BattleRules = require("./BattleRules")
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
