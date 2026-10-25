--!strict
-- Pure Egg Garden hatching (GDD D3 and E, decision 0008): species, mutation and size rolls, the
-- Lucky Meter, the starter rule and the Index. `roll` draws once on the in-memory profile; `apply`
-- applies that fixed outcome, so re-applying it to the stored record never re-rolls. No Roblox APIs.

local GardenConfig = require("./GardenConfig")
local GardenRules = require("./GardenRules")
local MetaRules = require("./MetaRules")
local Rng = require("./Rng")

local HatchRules = {}

type Profile = GardenConfig.Profile

export type Outcome = { egg: string, s: string, m: string, z: string, forced: boolean } -- forced: by the Lucky Meter
export type Result = { creature: GardenConfig.Creature, xp: number, newEntry: boolean }

local LEGENDARY = 5 -- RARITIES index of "legendary"

-- First id whose cumulative basis points reach r (r in 1..10000).
function HatchRules.pick(odds: { GardenConfig.Odds }, r: number): string
	local total = 0
	for _, o in odds do
		total += o.bp
		if r <= total then
			return o.id
		end
	end
	return odds[#odds].id
end

-- No draw for the starter or when the Lucky Meter forces the top species.
function HatchRules.rollSpecies(egg: string, pity: number, rng: Rng.State): (string, boolean, Rng.State)
	local e = GardenConfig.egg(egg)
	if e == nil then
		return "", false, rng
	end
	if e.top == nil or e.meter == nil then
		return e.odds[1].id, false, rng
	end
	if pity >= e.meter - 1 then
		return e.top, true, rng
	end
	local r, state = Rng.int(rng, 1, 10000)
	return HatchRules.pick(e.odds, r), false, state
end

function HatchRules.rollMutation(weather: string, rng: Rng.State): (string, Rng.State)
	local w = GardenConfig.WEATHERS[1]
	for _, candidate in GardenConfig.WEATHERS do
		if candidate.id == weather then
			w = candidate
		end
	end
	local r, state = Rng.int(rng, 1, 10000)
	return HatchRules.pick(w.mutation, r), state
end

function HatchRules.rollSize(rng: Rng.State): (string, Rng.State)
	local r, state = Rng.int(rng, 1, 10000)
	return HatchRules.pick(GardenConfig.SIZES :: any, r), state
end

-- Nil unless the bed is ripe and the garden is not full. Draw order: species, mutation, size.
function HatchRules.roll(p: Profile, bed: number, now: number, weather: string, rng: Rng.State): Outcome?
	if GardenRules.bedState(p, bed, now) ~= "ripe" or GardenRules.isFull(p) then
		return nil
	end
	local egg = p.beds[bed].egg
	if egg == "starter" then
		return { egg = egg, s = "pup", m = "normal", z = "normal", forced = false }
	end
	local s, forced, state = HatchRules.rollSpecies(egg, p.pity[egg] or 0, rng)
	local m, z
	m, state = HatchRules.rollMutation(weather, state)
	z = HatchRules.rollSize(state)
	return { egg = egg, s = s, m = m, z = z, forced = forced }
end

function HatchRules.nextPity(egg: string, pity: number, species: string): number
	local e = GardenConfig.egg(egg)
	return if e and e.top == species then 0 else pity + 1
end

-- Applies a fixed outcome: re-checks the bed (ripe, same egg) and room, empties the bed, adds the
-- creature (lowest free pad, else storage), the Lucky Meter, the Index entry, hatches and XP.
function HatchRules.apply(p: Profile, bed: number, o: Outcome, now: number): (Profile, boolean, Result?)
	local e = GardenConfig.egg(o.egg)
	if e == nil or GardenRules.bedState(p, bed, now) ~= "ripe" or p.beds[bed].egg ~= o.egg then
		return p, false, nil
	end
	local known = GardenConfig.species(o.s) and GardenConfig.mutation(o.m) and GardenConfig.size(o.z)
	if GardenRules.isFull(p) or not known then
		return p, false, nil
	end
	local out = GardenRules.copy(p)
	out.beds[bed] = { egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 }
	local creature = { id = out.nextId, s = o.s, m = o.m, z = o.z, placed = GardenRules.freePad(out) or 0, fav = false }
	table.insert(out.creatures, creature)
	out.nextId += 1
	if e.meter then
		out.pity[o.egg] = HatchRules.nextPity(o.egg, out.pity[o.egg] or 0, o.s)
	end
	local key = `{o.s}:{o.m}`
	local newEntry = table.find(out.index, key) == nil
	if newEntry then
		table.insert(out.index, key)
	end
	local xp = e.xp + if newEntry then GardenConfig.XP.index else 0
	out.hatches = math.min(MetaRules.MAX_COUNT, out.hatches + 1)
	out.xp = math.min(MetaRules.MAX_XP, out.xp + xp)
	return out, true, { creature = table.clone(creature), xp = xp, newEntry = newEntry }
end

function HatchRules.hatch(
	p: Profile,
	bed: number,
	now: number,
	weather: string,
	rng: Rng.State
): (Profile, boolean, Outcome?, Result?)
	local o = HatchRules.roll(p, bed, now, weather, rng)
	if o == nil then
		return p, false, nil, nil
	end
	local out, ok, result = HatchRules.apply(p, bed, o, now)
	return out, ok, o, result
end

-- Server-wide banner: Legendary or Mythic species, any Rainbow, any Huge.
function HatchRules.announce(o: Outcome): boolean
	return GardenConfig.rarityIndex(o.s) >= LEGENDARY or o.m == "rainbow" or o.z == "huge"
end

-- "60.00": two decimals, for the ODDS panel.
function HatchRules.percent(bp: number): string
	return string.format("%.2f", bp / 100)
end

return HatchRules
