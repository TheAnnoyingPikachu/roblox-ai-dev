--!strict
-- Pure Animal Stations wave runs (decision 0098): waves fought back to back. The team's HP carries over
-- from wave to wave (each standing animal heals REST_HEAL of its max HP between them, the knocked out
-- stay down), and after each win the player picks one of three boons that last the rest of the run.
-- Each wave pays as it always does; on top of that a streak bonus (STREAK_PCT % of the wave's coins for
-- each win in a row before it, up to STREAK_MAX %) and the rare boons' extras go into a pot, paid when
-- the player leaves the arena, LOSS_KEEP % of it when the run ends in a loss. The server keeps the run.

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
	{ id = "claws", name = "Sharp Claws", text = "+20% damage", weight = 10 },
	{ id = "hide", name = "Thick Hide", text = "+20% max HP", weight = 10 },
	{ id = "quick", name = "Quick Paws", text = "Attacks 12% faster", weight = 8 },
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
	return {
		hp = run.hp,
		energy = if count(run, "charged") > 0 then 0.5 else 0,
		dmg = 1.2 ^ count(run, "claws"),
		maxHp = 1.2 ^ count(run, "hide"),
		tempo = 0.88 ^ count(run, "quick"),
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
	local pool, total = table.clone(WaveRuns.BOONS), 0
	for _, b in pool do
		total += b.weight
	end
	local rng = Rng.seed(run.seed, run.wave, 98)
	out.offer = {}
	for _ = 1, WaveRuns.OFFER do
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
