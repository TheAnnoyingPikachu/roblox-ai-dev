--!strict
-- Pure Animal Stations wave runs (decision 0098): waves fought back to back. The team's HP carries over
-- from wave to wave (each standing animal heals REST_HEAL of its max HP between them; each knocked out
-- one stays at 0 in the run and fights the next wave at WIPED_BACK: decision 0108), and after each win the player picks one of three boons that last the rest of the run.
-- Each wave pays as it always does; on top of that a streak bonus (STREAK_PCT % of the wave's coins for
-- each win in a row before it, up to STREAK_MAX %) and the rare boons' extras go into a pot, paid when
-- the player leaves the arena, LOSS_KEEP % of it when the run ends in a loss. The server keeps the run.
--
-- Shared fights (decision 0108): one run for every player in the fight. Its `hp` is all their animals', in
-- the fight's slot order; the players vote for the boon (`tally`).
-- The server keeps each player's own pot.

local BattleRules = require("./BattleRules")
local LevelRules = require("./LevelRules")
local Rng = require("./Rng")

local WaveRuns = {}

export type Run = {
	wave: number, -- the next wave to fight
	streak: number, -- waves won in a row
	hp: { number }, -- the team's HP by slot, shares of max HP (0 = knocked out)
	boons: { string },
	pot: { coins: number, samples: number },
	offer: { string }?, -- the three boons to pick from after a win
	seed: number,
	ultra: boolean?, -- an ultra lucky boon was taken: no other this run
	untilWave: { [string]: number }?, -- a timed boon (Unbreakable, Twin Picks) lasts up to this wave
	second: boolean?, -- Twin Picks: the offer is up again for this wave's second pick
}
export type Tier = "common" | "lucky" | "ultra"
export type Boon = {
	id: string,
	name: string,
	text: string,
	weight: number,
	tier: Tier,
	rare: boolean?, -- lucky or ultra lucky (the HUD's gold edge)
	cap: number?, -- the most stacks that count
	waves: number?, -- a timed boon: how many waves it lasts
}

-- SHANNON's sign-off, 2026-11-25 (the concept board "Boon concepts", decision 0120): 12 common, 9 lucky, 6 ultra lucky.
local function boon(
	tier: Tier,
	id: string,
	name: string,
	text: string,
	weight: number,
	more: { cap: number?, waves: number? }?
): Boon
	return {
		id = id,
		name = name,
		text = text,
		weight = weight,
		tier = tier,
		rare = if tier ~= "common" then true else nil,
		cap = more and more.cap,
		waves = more and more.waves,
	}
end
WaveRuns.BOONS = {
	boon("common", "claws", "Sharp Claws", "+5% damage", 10),
	boon("common", "hide", "Thick Hide", "+5% max HP", 10),
	boon("common", "quick", "Quick Paws", "Attacks 3% faster", 8),
	boon("common", "charged", "Charged Up", "Power meters start half full", 8, { cap = 1 }),
	boon("common", "mend", "Second Wind", "Heal the team to full", 8),
	boon("common", "iron", "Iron Coat", "Take 4% less damage", 9),
	boon("common", "focus", "Focus", "Power meters fill 5% faster", 9),
	boon("common", "steady", "Steady Paws", "Press windows 10% longer", 7, { cap = 3 }),
	boon("common", "taps", "Hard Taps", "Your taps strike 10% harder", 8),
	boon("common", "watch", "Watchful", "The shield is ready 1 s sooner", 7, { cap = 3 }),
	boon("common", "pack", "Pack Bond", "+2% damage for each of your animals standing", 8),
	boon("common", "rested", "Rested", "Heal 10% more between waves", 8),
	boon("lucky", "revive", "Revive", "Knocked-out animals come back at half HP", 4),
	boon("lucky", "lucky", "Lucky Find", "Double samples for the rest of the run", 4, { cap = 1 }),
	boon("lucky", "gold", "Gold Rush", "+25% coins for the rest of the run", 4, { cap = 1 }),
	boon("lucky", "phoenix", "Phoenix Feather", "Once a wave, the first animal knocked out gets back up at 30%", 4),
	boon("lucky", "overcharge", "Overcharge", "Every Perfect press gives back a quarter of the meter", 4, { cap = 1 }),
	boon("lucky", "glass", "Glass Cannon", "+20% damage, but 10% less max HP", 3),
	boon("lucky", "map", "Treasure Map", "+2 samples into the pot for every wave won", 4),
	boon("lucky", "chain", "Combo Chain", "Combos last 1 s longer and hit 10% harder", 4, { cap = 1 }),
	boon("lucky", "thorns", "Thorns", "Foes take back 8% of the damage they deal", 4),
	boon("ultra", "blessing", "Legend's Blessing", "+15% to every stat for the rest of the run", 3),
	boon("ultra", "golden", "Golden Hour", "The pot doubles when you bank it (not on a loss)", 3),
	boon("ultra", "unbreakable", "Unbreakable", "For the next 3 waves no animal drops below 1 HP", 3, { waves = 3 }),
	boon("ultra", "twin", "Twin Picks", "For the next 5 waves you take two boons from each offer", 3, { waves = 5 }),
	boon(
		"ultra",
		"roar",
		"Titan's Roar",
		"The Titan's power attack is ready at the start of every wave",
		2,
		{ cap = 1 }
	),
	boon(
		"ultra",
		"jackpot",
		"Jackpot Egg",
		"Banking the run adds your best unlocked egg to your cellar",
		2,
		{ cap = 1 }
	),
} :: { Boon }
WaveRuns.STREAK_PCT, WaveRuns.STREAK_MAX = 5, 100
WaveRuns.GOLD_PCT = 25
WaveRuns.REST_HEAL = 0.2
WaveRuns.LOSS_KEEP = 50
WaveRuns.OFFER = 3
-- each stack of a boon (SHANNON, 2026-11-24: small, so wave 300 takes a good team and good stacks); the texts say so
WaveRuns.CLAWS, WaveRuns.HIDE, WaveRuns.QUICK = 1.05, 1.05, 0.97
WaveRuns.IRON, WaveRuns.FOCUS, WaveRuns.STEADY, WaveRuns.TAPS = 0.96, 1.05, 1.1, 1.1
WaveRuns.WATCH, WaveRuns.PACK_PCT, WaveRuns.RESTED = 1, 2, 0.1
WaveRuns.PHOENIX_PCT, WaveRuns.REFUND, WaveRuns.GLASS_DMG, WaveRuns.GLASS_HP = 30, 0.25, 1.2, 0.9
WaveRuns.MAP_SAMPLES, WaveRuns.CHAIN_SECONDS, WaveRuns.CHAIN_PCT, WaveRuns.THORNS = 2, 1, 1.1, 0.08
WaveRuns.BLESSING = 1.15
-- in how many offers in 100 the first card is lucky (about one or two a stage of 10 waves), and ultra lucky
-- (at most one ultra boon a run); the first offer after a boss wave always has a lucky card
WaveRuns.RARE_PCT, WaveRuns.ULTRA_PCT = 15, 2
WaveRuns.WIPED_BACK = 0.25

function WaveRuns.boon(id: string): Boon?
	for _, b in WaveRuns.BOONS do
		if b.id == id then
			return b
		end
	end
	return nil
end

local function count(run: Run, id: string): number
	local n = 0
	for _, b in run.boons do
		if b == id then
			n += 1
		end
	end
	local def = WaveRuns.boon(id)
	return if def and def.cap then math.min(n, def.cap) else n
end
WaveRuns.count = count

-- A new run from wave `wave` for a team of `size`, with the server's random `seed`.
function WaveRuns.new(wave: number, size: number, seed: number): Run
	return {
		wave = wave,
		streak = 0,
		hp = table.create(size, 1),
		boons = {},
		pot = { coins = 0, samples = 0 },
		offer = nil,
		seed = seed,
	}
end

-- What the run's boons and carried HP do to the team's next fight.
function WaveRuns.setup(run: Run): BattleRules.Setup
	local hp = table.clone(run.hp)
	for i, share in hp do
		hp[i] = if share <= 0 then WaveRuns.WIPED_BACK else share -- the knocked out come back (decision 0108)
	end
	local bless = if count(run, "blessing") > 0 then WaveRuns.BLESSING else 1
	local glass = count(run, "glass")
	local timed = run.untilWave or {}
	return {
		hp = hp,
		energy = if count(run, "charged") > 0 then 0.5 else 0,
		dmg = WaveRuns.CLAWS ^ count(run, "claws") * WaveRuns.GLASS_DMG ^ glass * bless,
		maxHp = WaveRuns.HIDE ^ count(run, "hide") * WaveRuns.GLASS_HP ^ glass * bless,
		tempo = WaveRuns.QUICK ^ count(run, "quick") / bless,
		clicks = true, -- a run's fight is the pit fight: clicks add strikes (decision 0106)
		taken = WaveRuns.IRON ^ count(run, "iron") / bless,
		gain = WaveRuns.FOCUS ^ count(run, "focus") * bless,
		window = WaveRuns.STEADY ^ count(run, "steady"),
		clickDmg = WaveRuns.TAPS ^ count(run, "taps"),
		shieldSooner = WaveRuns.WATCH * count(run, "watch"),
		pack = WaveRuns.PACK_PCT * count(run, "pack"),
		phoenix = count(run, "phoenix"),
		refund = if count(run, "overcharge") > 0 then WaveRuns.REFUND else nil,
		comboSeconds = if count(run, "chain") > 0 then WaveRuns.CHAIN_SECONDS else nil,
		comboHit = if count(run, "chain") > 0 then WaveRuns.CHAIN_PCT else nil,
		thorns = WaveRuns.THORNS * count(run, "thorns"),
		titanReady = count(run, "roar") > 0,
		immortal = (timed.unbreakable or 0) >= run.wave,
	}
end

-- What the pot gains from a won wave that paid `coins` and `samples`: the streak bonus and the boons'.
function WaveRuns.bonus(run: Run, coins: number, samples: number): (number, number)
	local pct = math.min(WaveRuns.STREAK_MAX, WaveRuns.STREAK_PCT * run.streak)
	if count(run, "gold") > 0 then
		pct += WaveRuns.GOLD_PCT
	end
	return coins * pct // 100,
		(if count(run, "lucky") > 0 then samples else 0) + WaveRuns.MAP_SAMPLES * count(run, "map")
end

-- The run after winning its wave with the team's HP at `ends` and the wave paying `coins` and
-- `samples`: the bonus into the pot, the streak up, everyone standing a little healed, three boons on offer.
function WaveRuns.won(run: Run, ends: { number }, coins: number, samples: number): Run
	local c, s = WaveRuns.bonus(run, coins, samples)
	local out = table.clone(run)
	out.pot = { coins = run.pot.coins + c, samples = run.pot.samples + s }
	out.streak += 1
	out.wave += 1
	out.hp = {}
	local heal = WaveRuns.REST_HEAL + WaveRuns.RESTED * count(run, "rested")
	for i, share in ends do
		out.hp[i] = if share <= 0 then 0 else math.min(1, share + heal)
	end
	local rng = Rng.seed(run.seed, run.wave, 98)
	local roll
	roll, rng = Rng.int(rng, 1, 100)
	-- this offer's first card: ultra lucky (once a run), lucky (or always after a boss), else common
	local first: Tier = if not run.ultra and roll <= WaveRuns.ULTRA_PCT
		then "ultra"
		elseif roll <= WaveRuns.ULTRA_PCT + WaveRuns.RARE_PCT or run.wave % LevelRules.BOSS_EVERY == 0 then "lucky"
		else "common"
	local function poolOf(tier: Tier): ({ Boon }, number)
		local pool, total = {}, 0
		for _, b in WaveRuns.BOONS do
			if b.tier == tier then
				table.insert(pool, b)
				total += b.weight
			end
		end
		return pool, total
	end
	local pool, total = poolOf(first)
	out.offer = {}
	for n = 1, WaveRuns.OFFER do
		if n == 2 and first ~= "common" then -- the rest are common
			pool, total = poolOf("common")
		end
		local r
		r, rng = Rng.int(rng, 1, total)
		for k, b in pool do
			r -= b.weight
			if r <= 0 then
				table.insert(out.offer :: { string }, b.id)
				total -= b.weight
				table.remove(pool, k)
				break
			end
		end
	end
	return out
end

-- The boon a shared fight's players picked from `offer` (decision 0108): the one with the most of `votes`
-- (one id per player who voted; an id that is not on offer does not count), a tie picked at random
-- among the tied by the run's seed, so the same votes always give the same boon. With no vote that counts
-- every boon on offer is tied.
function WaveRuns.tally(run: Run, votes: { string }): string?
	local offer = run.offer
	if offer == nil or #offer == 0 then
		return nil
	end
	local votesFor: { [string]: number } = {}
	for _, id in votes do
		if table.find(offer, id) then
			votesFor[id] = (votesFor[id] or 0) + 1
		end
	end
	local most, tied = 0, {}
	for _, id in offer do -- in the offer's order, so a tie's list is the same every time
		local n = votesFor[id] or 0
		if n > most then
			most, tied = n, { id }
		elseif n == most then
			table.insert(tied, id)
		end
	end
	local k = Rng.int(Rng.seed(run.seed, run.wave, 108), 1, #tied)
	return tied[k]
end

-- Whether this wave's offer gives two picks (Twin Picks, decision 0120, amended 2026-11-25).
function WaveRuns.twice(run: Run): boolean
	return ((run.untilWave or {}).twin or 0) >= run.wave
end

-- Pick boon `id` from the offer. Second Wind and Revive act at once.
function WaveRuns.pick(run: Run, id: string): (Run, boolean, string?)
	if run.offer == nil or not table.find(run.offer, id) then
		return run, false, "boon"
	end
	local def = WaveRuns.boon(id) :: Boon
	local out = table.clone(run)
	out.offer = nil
	out.boons = table.clone(run.boons)
	local timed = table.clone(run.untilWave or {})
	table.insert(out.boons, id)
	-- Twin Picks (SHANNON, 2026-11-25: "take two boons", as the board drew it): the first pick of a twin wave
	-- leaves the other cards up for a second, common and lucky only; the next wave starts after the second
	out.second = nil
	if WaveRuns.twice(run) and not run.second and def.tier ~= "ultra" then
		local rest = {}
		for _, other in run.offer do
			local b = WaveRuns.boon(other)
			if other ~= id and b and b.tier ~= "ultra" then
				table.insert(rest, other)
			end
		end
		if #rest > 0 then
			out.offer, out.second = rest, true
		end
	end
	if def.waves then -- the next `waves` fights (Unbreakable), or the picks after them (Twin Picks)
		timed[id] = run.wave + def.waves - (if id == "twin" then 0 else 1)
	end
	out.untilWave = timed
	out.ultra = run.ultra or def.tier == "ultra"
	out.hp = table.clone(run.hp)
	for i, share in out.hp do
		if id == "mend" and share > 0 then
			out.hp[i] = 1
		elseif id == "revive" and share <= 0 then
			out.hp[i] = 0.5
		end
	end
	return out, true, nil
end

-- What the pot pays when the run ends: all of it on leaving, LOSS_KEEP % after a loss.
function WaveRuns.bank(run: Run, lost: boolean): (number, number)
	if lost then
		return run.pot.coins * WaveRuns.LOSS_KEEP // 100, run.pot.samples * WaveRuns.LOSS_KEEP // 100
	end
	local times = if run.boons and count(run, "golden") > 0 then 2 else 1
	return run.pot.coins * times, run.pot.samples * times
end

return WaveRuns
