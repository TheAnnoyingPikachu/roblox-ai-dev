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
}
export type Boon = { id: string, name: string, text: string, weight: number, rare: boolean? }

WaveRuns.BOONS = {
	{ id = "claws", name = "Sharp Claws", text = "+5% damage", weight = 10 },
	{ id = "hide", name = "Thick Hide", text = "+5% max HP", weight = 10 },
	{ id = "quick", name = "Quick Paws", text = "Attacks 3% faster", weight = 8 },
	{ id = "charged", name = "Charged Up", text = "Power meters start half full", weight = 8 },
	{ id = "mend", name = "Second Wind", text = "Heal the team to full", weight = 8 },
	{ id = "revive", name = "Revive", text = "Knocked-out animals come back at half HP", weight = 4, rare = true },
	{ id = "lucky", name = "Lucky Find", text = "Double samples for the rest of the run", weight = 4, rare = true },
	{ id = "gold", name = "Gold Rush", text = "+25% coins for the rest of the run", weight = 4, rare = true },
} :: { Boon }
WaveRuns.STREAK_PCT, WaveRuns.STREAK_MAX = 5, 100
WaveRuns.GOLD_PCT = 25
WaveRuns.REST_HEAL = 0.2
WaveRuns.LOSS_KEEP = 50
WaveRuns.OFFER = 3
-- each stack of a boon (SHANNON, 2026-11-24: small, so wave 300 takes a good team and good stacks); the texts say so
WaveRuns.CLAWS, WaveRuns.HIDE, WaveRuns.QUICK = 1.05, 1.05, 0.97
-- in how many offers in 100 one of the rare boons stands (about one or two a stage of 10 waves)
WaveRuns.RARE_PCT = 15
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
	return n
end

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
	return {
		hp = hp,
		energy = if count(run, "charged") > 0 then 0.5 else 0,
		dmg = WaveRuns.CLAWS ^ count(run, "claws"),
		maxHp = WaveRuns.HIDE ^ count(run, "hide"),
		tempo = WaveRuns.QUICK ^ count(run, "quick"),
		clicks = true, -- a run's fight is the pit fight: clicks add strikes (decision 0106)
	}
end

-- What the pot gains from a won wave that paid `coins` and `samples`: the streak bonus and the boons'.
function WaveRuns.bonus(run: Run, coins: number, samples: number): (number, number)
	local pct = math.min(WaveRuns.STREAK_MAX, WaveRuns.STREAK_PCT * run.streak)
	if count(run, "gold") > 0 then
		pct += WaveRuns.GOLD_PCT
	end
	return coins * pct // 100, if count(run, "lucky") > 0 then samples else 0
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
	for i, share in ends do
		out.hp[i] = if share <= 0 then 0 else math.min(1, share + WaveRuns.REST_HEAL)
	end
	local rng = Rng.seed(run.seed, run.wave, 98)
	local roll
	roll, rng = Rng.int(rng, 1, 100)
	local rare = roll <= WaveRuns.RARE_PCT -- this offer's first boon is a rare one, the others common
	local pool, total = {}, 0
	for _, b in WaveRuns.BOONS do
		if (b.rare == true) == rare then
			table.insert(pool, b)
			total += b.weight
		end
	end
	out.offer = {}
	for n = 1, WaveRuns.OFFER do
		if rare and n == 2 then -- the rest are common
			pool, total = {}, 0
			for _, b in WaveRuns.BOONS do
				if not b.rare then
					table.insert(pool, b)
					total += b.weight
				end
			end
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

-- Pick boon `id` from the offer. Second Wind and Revive act at once.
function WaveRuns.pick(run: Run, id: string): (Run, boolean, string?)
	if run.offer == nil or not table.find(run.offer, id) then
		return run, false, "boon"
	end
	local out = table.clone(run)
	out.offer = nil
	out.boons = table.clone(run.boons)
	table.insert(out.boons, id)
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
	return run.pot.coins, run.pot.samples
end

return WaveRuns
