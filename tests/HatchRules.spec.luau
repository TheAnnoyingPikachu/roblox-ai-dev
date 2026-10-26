--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local HatchRules = require("../src/shared/HatchRules")
local Rng = require("../src/shared/Rng")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = GardenConfig.Profile

local NOW = 1_800_000_000

-- A profile with a ripe `egg` in bed 1.
local function ripe(egg: string): Profile
	local p = GardenProgress.defaults(NOW - 100_000)
	p.beds[1] = { egg = egg, planted = NOW - 100_000, ready = NOW - 1, waters = 0, helps = 0, lastWater = 0 }
	return p
end

local function outcome(egg: string, s: string, m: string, z: string): HatchRules.Outcome
	return { egg = egg, s = s, m = m, z = z, forced = false }
end

local function egg(id: string): GardenConfig.Egg
	return GardenConfig.egg(id) :: GardenConfig.Egg
end

describe("HatchRules.pick", function()
	it("maps r to the first cumulative bp at the boundaries", function()
		local odds = egg("meadow").odds
		expect(HatchRules.pick(odds, 1)).toBe("bunny")
		expect(HatchRules.pick(odds, 6000)).toBe("bunny")
		expect(HatchRules.pick(odds, 6001)).toBe("frog")
		expect(HatchRules.pick(odds, 9000)).toBe("frog")
		expect(HatchRules.pick(odds, 9001)).toBe("pup")
		expect(HatchRules.pick(odds, 9900)).toBe("pup")
		expect(HatchRules.pick(odds, 9901)).toBe("cat")
		expect(HatchRules.pick(odds, 10000)).toBe("cat")
		local clear = GardenConfig.WEATHERS[1].mutation
		expect(HatchRules.pick(clear, 9990)).toBe("golden")
		expect(HatchRules.pick(clear, 9991)).toBe("rainbow") -- moonlit has 0 bp and is never picked
	end)

	it("formats percentages to two decimals, each egg totalling 100.00", function()
		expect(HatchRules.percent(6000)).toBe("60.00")
		expect(HatchRules.percent(50)).toBe("0.50")
		expect(HatchRules.percent(5)).toBe("0.05")
		for _, e in GardenConfig.EGGS do
			local total = 0
			for _, o in e.odds do
				total += tonumber(HatchRules.percent(o.bp)) :: number
			end
			expect(string.format("%.2f", total)).toBe("100.00")
		end
	end)
end)

describe("HatchRules Lucky Meter", function()
	it("forces the top species without a draw at meter - 1, and draws below it", function()
		local rng = Rng.seed(77)
		for _, e in GardenConfig.EGGS do
			if e.meter then
				local s, forced, state = HatchRules.rollSpecies(e.id, e.meter - 1, rng)
				expect(s).toBe(e.top)
				expect(forced).toBe(true)
				expect(state).toBe(rng)
				local _, notForced, drawn = HatchRules.rollSpecies(e.id, e.meter - 2, rng)
				expect(notForced).toBe(false)
				expect(drawn ~= rng).toBe(true)
			end
		end
	end)

	it("resets on the top species and increments otherwise", function()
		expect(HatchRules.nextPity("meadow", 12, "cat")).toBe(0)
		expect(HatchRules.nextPity("meadow", 12, "bunny")).toBe(13)
		expect(HatchRules.nextPity("moon", 98, "dragon")).toBe(0)
	end)

	it("guarantees the top species by hatch `meter` over long runs", function()
		for _, e in GardenConfig.EGGS do
			if e.meter then
				local p = ripe(e.id)
				local rng = Rng.seed(5, #e.id)
				local sinceTop, worst = 0, 0
				for i = 1, 600 do
					local out, ok, o
					out, ok, o = HatchRules.hatch(p, 1, NOW, "clear", rng)
					expect(ok).toBe(true)
					rng = Rng.seed(5, #e.id, i)
					sinceTop += 1
					worst = math.max(worst, sinceTop)
					expect(out.pity[e.id]).toBe(if (o :: any).s == e.top then 0 else sinceTop)
					if (o :: any).s == e.top then
						sinceTop = 0
					end
					p = ripe(e.id)
					p.pity = out.pity
				end
				expect(worst <= (e.meter :: number)).toBe(true)
			end
		end
	end)
end)

describe("HatchRules rolls", function()
	it("keeps every species within 0.5 points of its odds over 100,000 seeded rolls per egg", function()
		for position, e in GardenConfig.EGGS do
			if e.meter then
				local counts: { [string]: number } = {}
				local rng = Rng.seed(position, 31)
				for _ = 1, 100_000 do
					local s
					s, _, rng = HatchRules.rollSpecies(e.id, 0, rng)
					counts[s] = (counts[s] or 0) + 1
				end
				for _, o in e.odds do
					local pct = 100 * (counts[o.id] or 0) / 100_000
					expect(`{e.id} {o.id} {math.abs(pct - o.bp / 100) <= 0.5}`).toBe(`{e.id} {o.id} true`)
				end
			end
		end
	end)

	it("keeps mutations and sizes within 0.5 points of their odds over 100,000 rolls", function()
		for i, w in GardenConfig.WEATHERS do
			local counts: { [string]: number } = {}
			local rng = Rng.seed(i, 32)
			for _ = 1, 100_000 do
				local m
				m, rng = HatchRules.rollMutation(w.id, rng)
				counts[m] = (counts[m] or 0) + 1
			end
			for _, o in w.mutation do
				local pct = 100 * (counts[o.id] or 0) / 100_000
				expect(`{w.id} {o.id} {math.abs(pct - o.bp / 100) <= 0.5}`).toBe(`{w.id} {o.id} true`)
			end
		end
		local counts: { [string]: number } = {}
		local rng = Rng.seed(33)
		for _ = 1, 100_000 do
			local z
			z, rng = HatchRules.rollSize(rng)
			counts[z] = (counts[z] or 0) + 1
		end
		for _, z in GardenConfig.SIZES do
			expect(math.abs(100 * counts[z.id] / 100_000 - z.bp / 100) <= 0.5).toBe(true)
		end
	end)

	it("treats an unknown weather as clear", function()
		local rng = Rng.seed(9)
		expect((HatchRules.rollMutation("nope", rng))).toBe((HatchRules.rollMutation("clear", rng)))
	end)

	it("draws species, then mutation, then size from one state", function()
		local rng = Rng.seed(1234)
		local o = HatchRules.roll(ripe("sunset"), 1, NOW, "moonfall", rng) :: HatchRules.Outcome
		local s, _, state = HatchRules.rollSpecies("sunset", 0, rng)
		local m
		m, state = HatchRules.rollMutation("moonfall", state)
		local z = HatchRules.rollSize(state)
		expect(`{o.egg} {o.s} {o.m} {o.z} {o.forced}`).toBe(`sunset {s} {m} {z} false`)
	end)

	it("always hatches the starter as a Normal Normal Bumble Pup", function()
		for seed = 1, 200 do
			local o = HatchRules.roll(ripe("starter"), 1, NOW, "shower", Rng.seed(seed)) :: HatchRules.Outcome
			expect(`{o.s} {o.m} {o.z} {o.forced}`).toBe("pup normal normal false")
		end
		local p = GardenProgress.defaults(NOW)
		expect(HatchRules.roll(p, 1, NOW + 7, "clear", 1)).toBeNil() -- not ripe yet
		local out, ok, _, result = HatchRules.hatch(p, 1, NOW + 8, "clear", 1)
		expect(ok).toBe(true)
		expect(out.creatures[1].s).toBe("pup")
		expect(out.pity.meadow).toBe(0) -- the starter has no meter
		expect((result :: any).xp).toBe(10 + 50)
	end)
end)

describe("HatchRules.apply", function()
	it("empties the bed, uses nextId and the lowest free pad, and counts the hatch", function()
		local p = ripe("moon")
		p.nextId = 41
		p.creatures = { { id = 7, s = "cat", m = "normal", z = "normal", placed = 1, fav = false } }
		local out, ok, result = HatchRules.apply(p, 1, outcome("moon", "lion", "golden", "huge"), NOW)
		expect(ok).toBe(true)
		local r = result :: HatchRules.Result
		expect(r.creature.id).toBe(41)
		expect(r.creature.placed).toBe(2)
		expect(out.nextId).toBe(42)
		expect(out.beds[1].egg).toBe("")
		expect(out.hatches).toBe(1)
		expect(out.pity.moon).toBe(1)
		expect(out.xp).toBe(150 + 50)
		expect(p.beds[1].egg).toBe("moon") -- input unchanged
	end)

	it("adds a new Index entry once, with 50 XP", function()
		local p = ripe("meadow")
		local o = outcome("meadow", "bunny", "golden", "normal")
		local first, _, r1 = HatchRules.apply(p, 1, o, NOW)
		expect((r1 :: any).newEntry).toBe(true)
		expect((r1 :: any).xp).toBe(60)
		expect(first.index[1]).toBe("bunny:golden")
		first.beds[1] = p.beds[1]
		local second, _, r2 = HatchRules.apply(first, 1, o, NOW)
		expect((r2 :: any).newEntry).toBe(false)
		expect((r2 :: any).xp).toBe(10)
		expect(#second.index).toBe(1)
		expect(second.xp).toBe(70)
	end)

	it("goes to storage when the pen is full and refuses a full garden", function()
		local p = ripe("meadow")
		for i = 1, 6 do
			table.insert(p.creatures, { id = i, s = "bunny", m = "normal", z = "normal", placed = i, fav = false })
		end
		p.nextId = 7
		local out, ok, r = HatchRules.apply(p, 1, outcome("meadow", "frog", "normal", "normal"), NOW)
		expect(ok).toBe(true)
		expect((r :: any).creature.placed).toBe(0)
		expect(GardenRules.storageCount(out)).toBe(1)
		for i = 7, 66 do
			table.insert(p.creatures, { id = i, s = "bunny", m = "normal", z = "normal", placed = 0, fav = false })
		end
		expect(GardenRules.isFull(p)).toBe(true)
		expect(HatchRules.roll(p, 1, NOW, "clear", 1)).toBeNil()
		expect(select(2, HatchRules.apply(p, 1, outcome("meadow", "frog", "normal", "normal"), NOW))).toBe(false)
		expect(select(2, HatchRules.hatch(p, 1, NOW, "clear", 1))).toBe(false)
	end)

	it("gives the same creature when re-applied to a copy of the original (no re-roll)", function()
		local p = ripe("star")
		local o = HatchRules.roll(p, 1, NOW, "sunbeam", Rng.seed(4)) :: HatchRules.Outcome
		local a, _, ra = HatchRules.apply(p, 1, o, NOW)
		local b, _, rb = HatchRules.apply(GardenRules.copy(p), 1, o, NOW + 60)
		local ca, cb = (ra :: any).creature, (rb :: any).creature
		expect(`{ca.id} {ca.s} {ca.m} {ca.z} {ca.placed}`).toBe(`{cb.id} {cb.s} {cb.m} {cb.z} {cb.placed}`)
		expect(a.pity.star).toBe(b.pity.star)
		expect(a.xp).toBe(b.xp)
	end)

	it("refuses when the bed's egg differs, the bed is not ripe, or the outcome is unknown", function()
		local p = ripe("forest")
		expect(select(2, HatchRules.apply(p, 1, outcome("moon", "fox", "normal", "normal"), NOW))).toBe(false)
		expect(select(2, HatchRules.apply(p, 2, outcome("forest", "frog", "normal", "normal"), NOW))).toBe(false)
		expect(select(2, HatchRules.apply(p, 1, outcome("forest", "frog", "normal", "normal"), NOW - 2))).toBe(false)
		expect(select(2, HatchRules.apply(p, 1, outcome("forest", "yeti", "normal", "normal"), NOW))).toBe(false)
		expect(select(2, HatchRules.apply(p, 1, outcome("forest", "frog", "shiny", "normal"), NOW))).toBe(false)
		expect(select(2, HatchRules.apply(p, 1, outcome("forest", "frog", "normal", "tiny"), NOW))).toBe(false)
	end)

	it("announces Legendary and Mythic species, any Rainbow and any Huge", function()
		expect(HatchRules.announce(outcome("moon", "lion", "normal", "normal"))).toBe(true)
		expect(HatchRules.announce(outcome("moon", "dragon", "normal", "normal"))).toBe(true)
		expect(HatchRules.announce(outcome("meadow", "bunny", "rainbow", "normal"))).toBe(true)
		expect(HatchRules.announce(outcome("meadow", "bunny", "normal", "huge"))).toBe(true)
		expect(HatchRules.announce(outcome("moon", "turtle", "moonlit", "big"))).toBe(false)
	end)
end)
