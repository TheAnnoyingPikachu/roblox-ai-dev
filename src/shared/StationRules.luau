--!strict
-- Pure Animal Stations rules (decisions 0019 to 0032): hatch an animal (species, then a
-- rare variant roll, then a base level for each stat), level its stats, and its role.
-- The server owns the Rng state and the clock; the client never sends stats or times.

local Rng = require("./Rng")
local StationConfig = require("./StationConfig")

local StationRules = {}

type Stats = StationConfig.Stats
-- One hatched animal: v nil = basic; stats = its version's numbers; trained = each stat's level
-- (rolled at hatch, then trained up to MAX_LEVEL) with the progress to the next as the fraction.
-- rainbow = true: it wears the rainbow coat (decision 0058), which adds to every stat (`stat`); absent
-- on every other animal.
-- `boost` is never stored: StationProgress.fighters sets it on the Titan for a wave (the Titan's Den).
-- `rush` and `elite` are a wave foe's (decision 0101): which rush it comes in, and whether it is an elite.
export type Owned = {
	s: string,
	v: string?,
	stats: Stats,
	trained: Stats?,
	rainbow: boolean?,
	boost: number?,
	rush: number?,
	elite: boolean?,
}

StationRules.PPM = 1_000_000
-- The share of the base level roll that gives `level`: BASE_TOP at BASE_MAX, BASE_STEP more for
-- every level below it.
local function baseWeight(level: number): number
	return StationConfig.BASE_TOP + StationConfig.BASE_STEP * (StationConfig.BASE_MAX - level)
end
StationRules.BASE_ROLL = 0 -- size of the base level roll (630)
for level = 1, StationConfig.BASE_MAX do
	StationRules.BASE_ROLL += baseWeight(level)
end
StationRules.ZERO = { speed = 0, strength = 0, stamina = 0, mana = 0, health = 0, defence = 0 } :: Stats

-- First id whose cumulative basis points reach r (r in 1..10000).
function StationRules.pick(odds: { StationConfig.Odds }, r: number): string
	local total = 0
	for _, o in odds do
		total += o.bp
		if r <= total then
			return o.id
		end
	end
	return odds[#odds].id
end

-- An egg's rare drop for r in 1..PPM, in the order the egg lists them, or nil for a basic animal.
function StationRules.pickRare(rare: { StationConfig.Rare }, r: number): StationConfig.Rare?
	local total = 0
	for _, row in rare do
		total += row.ppm
		if r <= total then
			return row
		end
	end
	return nil
end

-- The base level for r in 1..BASE_ROLL: 1 is the most likely and each higher number less so.
function StationRules.baseLevel(r: number): number
	local total = 0
	for level = 1, StationConfig.BASE_MAX do
		total += baseWeight(level)
		if r <= total then
			return level
		end
	end
	return StationConfig.BASE_MAX
end

-- A version's stats at level 0: basic stats, or basic x mult + twist for a variant. Nil for an
-- unknown species or a variant of another species.
function StationRules.versionStats(speciesId: string, variantId: string?): Stats?
	local sp = StationConfig.species(speciesId)
	if sp == nil then
		return nil
	end
	if variantId == nil then
		return table.clone(sp.stats)
	end
	local va = StationConfig.variant(speciesId, variantId)
	local tier = va and StationConfig.tier(va.tier)
	if va == nil or tier == nil then
		return nil
	end
	local out = {} :: any
	for _, stat in StationConfig.STATS do
		local x = (sp.stats :: any)[stat] * tier.mult + (if stat == va.twist then tier.twist else 0)
		out[stat] = math.min(math.floor(x), StationConfig.STAT_MAX)
	end
	return out :: Stats
end

-- Hatch one animal from `eggId`. Nil for an unknown egg (the server refuses the request).
-- Draws: a basic species, the egg's rare drops (a hit replaces the species), a base level per stat,
-- the jackpot (and its stat when it hits), the rainbow coat.
function StationRules.hatch(eggId: string, rng: Rng.State): (Owned?, Rng.State)
	local egg = StationConfig.egg(eggId)
	if egg == nil then
		return nil, rng
	end
	local r, t
	r, rng = Rng.int(rng, 1, 10000)
	local species = StationRules.pick(egg.odds, r)
	t, rng = Rng.int(rng, 1, StationRules.PPM)
	local variantId: string? = nil
	local rare = StationRules.pickRare(egg.rare, t)
	if rare then -- a variant is a drop of its own (decision 0056): it sets the species too
		species, variantId = rare.s, rare.v
	end
	local levels = {} :: any
	for _, stat in StationConfig.STATS do
		local roll
		roll, rng = Rng.int(rng, 1, StationRules.BASE_ROLL)
		levels[stat] = StationRules.baseLevel(roll)
	end
	local jackpot
	jackpot, rng = Rng.int(rng, 1, StationRules.PPM)
	if jackpot <= StationConfig.JACKPOT_PPM then
		local which
		which, rng = Rng.int(rng, 1, #StationConfig.STATS)
		levels[StationConfig.STATS[which]] = StationConfig.MAX_LEVEL
	end
	local coat
	coat, rng = Rng.int(rng, 1, StationRules.PPM)
	local stats = StationRules.versionStats(species, variantId) :: Stats
	return {
		s = species,
		v = variantId,
		stats = stats,
		trained = levels :: Stats,
		rainbow = if coat <= StationConfig.RAINBOW_PPM then true else nil,
	},
		rng
end

-- An animal's role, from its species (or a foe's, from its entry): "attack", "defense", "utility"
-- or "titan".
function StationRules.role(animal: Owned): string
	local sp = StationConfig.species(animal.s) or StationConfig.foe(animal.s)
	return if sp then sp.role else "attack"
end

-- The uploaded model that shows animal `s`, or its variant `v`: a variant "<word>_<species>" is the
-- asset "creature_<species>_<word>" (StationAssets.spec keeps every one in the table).
-- A species whose model is a whole ForgeGUI model skinned to the rig (decision 0102) is listed in `FORGE`.
StationRules.FORGE = { lion = "creature_lion_forge" } :: { [string]: string }
function StationRules.assetOf(s: string, v: string?): string
	local word = if v then string.match(v, "^(%l+)_") else nil
	return if word then `creature_{s}_{word}` else StationRules.FORGE[s] or `creature_{s}`
end

-- Display rarity: the variant's tier, or the species' basic rarity.
function StationRules.rarity(animal: Owned): string
	if animal.v then
		local va = StationConfig.variant(animal.s, animal.v)
		if va then
			return va.tier
		end
	end
	local sp = StationConfig.species(animal.s)
	return if sp then sp.rarity else "common"
end

-- A stat's level, 0 (untrained) to MAX_LEVEL.
function StationRules.level(animal: Owned, stat: StationConfig.Stat): number
	return if animal.trained then math.floor((animal.trained :: any)[stat]) else 0
end

-- An animal's stat right now: the hatched value grown by its level (doubled at MAX_LEVEL), and for
-- an animal in a rainbow coat RAINBOW_BONUS percent more, rounded up (decision 0058).
-- Whole-number maths, so a result that should be exact is never one short. Not capped: level
-- enemies have no levels but hatched stats that keep growing.
function StationRules.stat(animal: Owned, stat: StationConfig.Stat): number
	local max = StationConfig.MAX_LEVEL
	local grown = max + StationConfig.LEVEL_GROWTH * StationRules.level(animal, stat)
	local value = math.floor((animal.stats :: any)[stat] * grown / max)
	if animal.rainbow then
		value += (value * StationConfig.RAINBOW_BONUS + 99) // 100
	end
	if animal.boost then -- the Titan's Den: this many percent of the stat, rounded down
		value = value * animal.boost // 100
	end
	return value
end

-- Seconds of training to go from level n - 1 to level n: LEVEL_FIRST for level 1, growing by the
-- same factor each level to one day at LEVEL_DAY, then by a smaller factor to LEVEL_LAST at
-- MAX_LEVEL. Whole seconds, so sums of levels are exact.
function StationRules.levelSeconds(n: number): number
	local c, day = StationConfig, 24 * 3600
	local seconds
	if n <= c.LEVEL_DAY then
		seconds = c.LEVEL_FIRST * (day / c.LEVEL_FIRST) ^ ((n - 1) / (c.LEVEL_DAY - 1))
	else
		seconds = day * (c.LEVEL_LAST / day) ^ ((n - c.LEVEL_DAY) / (c.MAX_LEVEL - c.LEVEL_DAY))
	end
	return math.floor(seconds + 0.5)
end

-- `animal` after `seconds` on `stationId`: a copy with that station's stat levelled, never past
-- MAX_LEVEL. Unknown station or no time: unchanged.
function StationRules.train(animal: Owned, stationId: string, seconds: number): Owned
	local st = StationConfig.station(stationId)
	if st == nil or seconds <= 0 then
		return animal
	end
	local trained = if animal.trained then table.clone(animal.trained) else table.clone(StationRules.ZERO)
	local lv = (trained :: any)[st.stat] :: number
	while seconds > 0 and lv < StationConfig.MAX_LEVEL do
		local whole = math.floor(lv)
		local cost = StationRules.levelSeconds(whole + 1)
		local need = (whole + 1 - lv) * cost -- seconds left in this level
		if seconds >= need then
			lv, seconds = whole + 1, seconds - need
		else
			lv, seconds = lv + seconds / cost, 0
		end
	end
	(trained :: any)[st.stat] = math.min(lv, StationConfig.MAX_LEVEL)
	local out = table.clone(animal)
	out.trained = trained
	return out
end

return StationRules
