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
-- coat: the coat it wears (decision 0110, StationConfig.COATS), absent on most; `stat` adds its buff.
-- rainbow = true: the rainbow coat (decision 0058); kept beside `coat = "rainbow"` so saves and code from
-- before coats read it the same.
-- `boost` is never stored: StationProgress.fighters sets it on the Titan for a wave (the Titan's Den).
-- `rush` and `elite` are a wave foe's (decision 0101): which rush it comes in, and whether it is an elite.
export type Owned = {
	s: string,
	v: string?,
	stats: Stats,
	trained: Stats?,
	rainbow: boolean?,
	coat: string?,
	boost: number?,
	rush: number?,
	elite: boolean?,
	boss: boolean?, -- a wave's boss (LevelRules.enemies, decision 0127): it stands bigger and lands on the circle
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
	local last = odds[#odds] -- none in a variant-only egg, whose rare drops always hit
	return if last then last.id else ""
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
	if va == nil then
		return nil
	end
	local out = {} :: any
	for _, stat in StationConfig.STATS do
		local x = (sp.stats :: any)[stat] * va.mult
			+ (if stat == va.twist then StationConfig.TWIST_PER * va.mult else 0)
		out[stat] = math.min(math.floor(x), StationConfig.STAT_MAX)
	end
	return out :: Stats
end

-- Hatch one animal from `eggId`. Nil for an unknown egg (the server refuses the request).
-- Draws: a basic species, the egg's rare drops (a hit replaces the species), a base level per stat,
-- the jackpot (and its stat when it hits), the coat (`coatOf`).
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
	local roll
	roll, rng = Rng.int(rng, 1, StationRules.PPM)
	local coat = StationRules.pickCoat(egg, roll)
	local stats = StationRules.versionStats(species, variantId) :: Stats
	return {
		s = species,
		v = variantId,
		stats = stats,
		trained = levels :: Stats,
		coat = coat,
		rainbow = if coat == "rainbow" then true else nil,
	},
		rng
end

-- The coat a hatch from `egg` comes out in for r in 1..PPM, or nil (decision 0110): the coats in order, each
-- `ppm` in a million, its signature coat COAT_TIMES (or `times`) as likely; from an egg with `always`, the
-- same odds scaled so every hatch has one.
function StationRules.coatWeight(egg: StationConfig.Egg, c: StationConfig.Coat): number
	return c.ppm * (if egg.coat == c.id then egg.times or StationConfig.COAT_TIMES else 1)
end
function StationRules.pickCoat(egg: StationConfig.Egg, r: number): string?
	local sum = 0
	for _, c in StationConfig.COATS do
		sum += StationRules.coatWeight(egg, c)
	end
	local at = if egg.always then r * sum / StationRules.PPM else r
	local total = 0
	for _, c in StationConfig.COATS do
		total += StationRules.coatWeight(egg, c)
		if at <= total then
			return c.id
		end
	end
	return nil
end

-- The coat `animal` wears, or nil: `coat`, or the rainbow of a save from before coats.
function StationRules.coatOf(animal: Owned): StationConfig.Coat?
	local id = animal.coat or (if animal.rainbow then "rainbow" else nil)
	return if id then StationConfig.coat(id) else nil
end

-- A version's power for its rarity (decision 0110): its six stats added up; and the rarity that power
-- earns, by StationConfig.RARITY_FLOOR (a Titan's bands TITAN_BAND wider).
function StationRules.total(stats: Stats): number
	local n = 0
	for _, stat in StationConfig.STATS do
		n += (stats :: any)[stat]
	end
	return n
end
function StationRules.powerRarity(total: number, titan: boolean): string
	local best, floor = "common", -1
	for rarity, at in StationConfig.RARITY_FLOOR do
		local need = if titan then at * StationConfig.TITAN_BAND else at
		if total >= need and at > floor then
			best, floor = rarity, at
		end
	end
	return best
end

-- An animal's role, from its species (or a foe's, from its entry): "attack", "defense", "utility"
-- or "titan".
function StationRules.role(animal: Owned): string
	local sp = StationConfig.species(animal.s) or StationConfig.foe(animal.s)
	return if sp then sp.role else "attack"
end

-- The uploaded model that shows animal `s`, or its variant `v`: a variant "<word>_<species>" is the
-- asset "creature_<species>_<word>" (StationAssets.spec keeps every one in the table).
-- A species or variant whose model is a whole ForgeGUI model skinned to the rig (decision 0102) is listed
-- in `FORGE`, by its id.
StationRules.FORGE = {
	acacia_giraffe = "creature_giraffe_acacia_forge",
	cheetah = "creature_cheetah_forge",
	crystal_rhino = "creature_rhino_crystal_forge",
	diamond_giraffe = "creature_giraffe_diamond_forge",
	elephant = "creature_elephant_forge",
	fire_cheetah = "creature_cheetah_thunder_forge", -- shown as the Thunder Cheetah (StationConfig)
	gemshell_tortoise = "creature_tortoise_gemshell_forge",
	island_tortoise = "creature_tortoise_island_forge",
	jackal = "creature_jackal_forge",
	lava_rhino = "creature_rhino_lava_forge",
	lightning_cheetah = "creature_cheetah_lightning_forge",
	lion = "creature_lion_forge",
	flamingo = "creature_flamingo_forge",
	frost_elephant = "creature_elephant_frost_forge",
	giraffe = "creature_giraffe_forge",
	meerkat = "creature_meerkat_forge",
	peacock_flamingo = "creature_flamingo_peacock_forge",
	phoenix_flamingo = "creature_flamingo_phoenix_forge",
	pharaoh_jackal = "creature_jackal_pharaoh_forge",
	rhino = "creature_rhino_forge",
	-- the Sahara Guardian (STATION-145): its model and moves only; no egg drops it until SHANNON says how it is won
	sahara_elephant = "creature_elephant_sahara_forge", -- the Sahara Mammoth: as the Guardian, in no egg
	sahara_lion = "creature_lion_sahara_forge",
	sahara_rhino = "creature_rhino_sahara_forge",
	sahara_tortoise = "creature_tortoise_sahara_forge",
	shadow_lion = "creature_lion_shadow_forge",
	sphinx_jackal = "creature_jackal_sphinx_forge",
	star_meerkat = "creature_meerkat_star_forge",
	storm_meerkat = "creature_meerkat_storm_forge",
	sun_lion = "creature_lion_sun_forge",
	tortoise = "creature_tortoise_forge",
	war_elephant = "creature_elephant_war_forge",
} :: { [string]: string }
function StationRules.assetOf(s: string, v: string?): string
	local forge = StationRules.FORGE[v or s]
	if forge then
		return forge
	end
	local word = if v then string.match(v, "^(%l+)_") else nil
	return if word then `creature_{s}_{word}` else `creature_{s}`
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

-- An animal's stat right now: the hatched value grown by its level (doubled at MAX_LEVEL), and its coat's
-- buff (decisions 0058, 0110): `all` percent more of every stat or `pct` more of its own, rounded up.
-- Whole-number maths, so a result that should be exact is never one short. Not capped: level
-- enemies have no levels but hatched stats that keep growing.
function StationRules.stat(animal: Owned, stat: StationConfig.Stat): number
	local max = StationConfig.MAX_LEVEL
	local grown = max + StationConfig.LEVEL_GROWTH * StationRules.level(animal, stat)
	local value = math.floor((animal.stats :: any)[stat] * grown / max)
	local coat = StationRules.coatOf(animal)
	local pct = if coat then coat.all or (if coat.stat == stat then coat.pct else nil) else nil
	if pct then
		value += (value * pct + 99) // 100
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
