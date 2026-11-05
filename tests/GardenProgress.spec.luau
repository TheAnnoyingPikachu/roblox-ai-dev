--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local HatchRules = require("../src/shared/HatchRules")
local MetaRules = require("../src/shared/MetaRules")
local Rng = require("../src/shared/Rng")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = GardenConfig.Profile

local NOW = 1_800_000_000
local DAY = MetaRules.dayOf(NOW)

local function same(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function creature(id: number, s: string, m: string, z: string, placed: number): GardenConfig.Creature
	return { id = id, s = s, m = m, z = z, placed = placed, fav = false }
end

-- Income 60.5 coins/s (GDD C3 check garden).
local function checkGarden(): Profile
	local p = GardenProgress.defaults(NOW)
	p.creatures = { creature(1, "cat", "golden", "big", 1), creature(2, "bunny", "normal", "normal", 2) }
	p.index = { "bunny:normal", "cat:golden", "frog:normal", "pup:normal", "cat:normal" }
	p.nextId = 3
	return p
end

local function ripe(p: Profile, egg: string): Profile
	local out = GardenRules.copy(p)
	out.beds[1] = { egg = egg, planted = NOW - 100_000, ready = NOW - 1, waters = 0, helps = 0, lastWater = 0 }
	return out
end

local function growing(p: Profile, egg: string): Profile
	local out = GardenRules.copy(p)
	out.beds[1] = { egg = egg, planted = NOW, ready = NOW + 3600, waters = 0, helps = 0, lastWater = 0 }
	return out
end

-- Runs `body` with GardenRules.income stubbed to `income` (GardenProgress reads it at call time).
local function withIncome(income: number, body: () -> ())
	local real = GardenRules.income
	GardenRules.income = function(_: Profile): number
		return income
	end
	local ok, err = pcall(body)
	GardenRules.income = real
	if not ok then
		error(err, 0)
	end
end

describe("GardenProgress defaults", function()
	it("starts with 100 coins, 3 beds, 6 pads and a starter egg ready 8 s after creation", function()
		local p = GardenProgress.defaults(NOW)
		expect(p.schemaVersion).toBe(2)
		expect(p.coins).toBe(100)
		expect(p.xp).toBe(0)
		expect(p.bedCount).toBe(3)
		expect(#p.beds).toBe(3)
		expect(p.penSlots).toBe(6)
		expect(p.beds[1].egg).toBe("starter")
		expect(p.beds[1].planted).toBe(NOW)
		expect(p.beds[1].ready).toBe(NOW + 8)
		expect(p.beds[2].egg .. p.beds[3].egg).toBe("")
		expect(p.lastSeen).toBe(NOW)
		expect(p.nextId).toBe(1)
		expect(p.stock.w).toBe(-1)
		expect(`{p.gate} {p.fence} {p.can}`).toBe("open picket tin")
		expect(
			p.pity.meadow + p.pity.forest + p.pity.sunset + p.pity.moon + p.pity.star + p.pity.celestial + p.pity.aurora
		).toBe(0)
		expect(next(p.prizeEggs)).toBeNil()
		expect(`{p.dash.day} {p.dash.prizes} {p.dash.coins}`).toBe("-1 0 0")
		expect(p.pity.starter).toBeNil()
		expect((p :: any).wins).toBeNil()
	end)

	it("sanitises its own defaults to themselves, with or without now", function()
		expect(same(GardenProgress.sanitize(GardenProgress.defaults(NOW), NOW), GardenProgress.defaults(NOW))).toBe(
			true
		)
		expect(same(GardenProgress.sanitize(GardenProgress.defaults(NOW)), GardenProgress.defaults(NOW))).toBe(true)
		local full = checkGarden()
		full.owned = { candy = true }
		full.fence = "candy"
		full.prizeEggs = { moon = 2 }
		full.dash = { day = DAY, prizes = 2, coins = 1 }
		expect(same(GardenProgress.sanitize(full, NOW), full)).toBe(true)
	end)
end)

describe("GardenProgress login and offline (decision 0008)", function()
	it("pays unbanked, then offline at half rate from the saved garden, and never twice", function()
		local p = checkGarden()
		p.coins = 1000
		p.unbanked = 37
		p.lastSeen = NOW - 3600
		local out, offline, unbanked = GardenProgress.login(p, NOW, DAY)
		expect(unbanked).toBe(37)
		expect(offline).toBe(108900)
		expect(out.coins).toBe(1000 + 37 + 108900)
		expect(out.unbanked).toBe(0)
		expect(out.lastSeen).toBe(NOW)
		expect(out.week.lastDay).toBe(DAY) -- MetaRules.login ran
		local again, offline2, unbanked2 = GardenProgress.login(out, NOW, DAY)
		expect(offline2 + unbanked2).toBe(0)
		expect(again.coins).toBe(out.coins)
	end)

	it("caps offline at 8 hours and pays nothing for a future lastSeen", function()
		local p = checkGarden()
		p.lastSeen = NOW - 36000
		local _, offline = GardenProgress.login(p, NOW, DAY)
		expect(offline).toBe(871200)
		p.lastSeen = NOW + 999
		local out, none = GardenProgress.login(p, NOW, DAY)
		expect(none).toBe(0)
		expect(out.lastSeen).toBe(NOW)
	end)

	it("pays exactly unbanked after a snapshot then a login 0 s later", function()
		local p = checkGarden()
		local snap = GardenProgress.snapshot(p, 42.9, NOW)
		expect(snap.unbanked).toBe(42)
		expect(snap.lastSeen).toBe(NOW)
		local out, offline, unbanked = GardenProgress.login(snap, NOW, DAY)
		expect(offline).toBe(0)
		expect(unbanked).toBe(42)
		expect(out.coins).toBe(p.coins + 42)
	end)

	it("never pays a banked coin twice after a crash", function()
		-- Online: 50 coins banked from pads, 7 still pending at the last flush, then the server dies.
		local p = GardenProgress.bank(checkGarden(), 50, 1, DAY)
		local stored = GardenProgress.snapshot(p, 7, NOW)
		local out, offline, unbanked = GardenProgress.login(stored, NOW + 60, DAY)
		expect(unbanked).toBe(7)
		expect(offline).toBe(math.floor(60.5 * 0.5 * 60 + 1e-9))
		expect(out.coins).toBe(100 + 50 + 7 + offline)
		local left = GardenProgress.leave(out, NOW + 70)
		expect(left.unbanked).toBe(0)
		expect(left.lastSeen).toBe(NOW + 70)
	end)
end)

describe("GardenProgress session lock (0008 amendment 2026-10-26)", function()
	local STALE = GardenProgress.LOCK_STALE

	it("lets a load claim a record with no lock, its own lock or a stale lock", function()
		expect(GardenProgress.canClaim(nil, "b", NOW)).toBe(true) -- new player
		expect(GardenProgress.canClaim(GardenProgress.defaults(NOW), "b", NOW)).toBe(true) -- saved before locks
		expect(GardenProgress.canClaim({ lock = { session = "b", at = NOW } }, "b", NOW)).toBe(true)
		expect(GardenProgress.canClaim({ lock = { session = "a", at = NOW - STALE } }, "b", NOW)).toBe(true)
		expect(GardenProgress.canClaim({ lock = { session = "a", at = NOW + STALE } }, "b", NOW)).toBe(true) -- garbage date
		expect(GardenProgress.canClaim({ lock = { session = "a", at = 0 / 0 } }, "b", NOW)).toBe(true)
		expect(GardenProgress.canClaim({ lock = "a" }, "b", NOW)).toBe(true)
	end)

	it("refuses a load while another session's lock is fresh", function()
		expect(GardenProgress.canClaim({ lock = { session = "a", at = NOW } }, "b", NOW)).toBe(false)
		expect(GardenProgress.canClaim({ lock = { session = "a", at = NOW - STALE + 1 } }, "b", NOW)).toBe(false)
		expect(GardenProgress.canClaim({ lock = { session = "a", at = NOW + 5 } }, "b", NOW)).toBe(false) -- clock skew
	end)

	it("writes only while this session holds the lock, stale or not", function()
		expect(GardenProgress.holds({ lock = { session = "a", at = NOW - 10 * STALE } }, "a")).toBe(true)
		expect(GardenProgress.holds({ lock = { session = "b", at = NOW } }, "a")).toBe(false) -- taken over
		expect(GardenProgress.holds(GardenProgress.defaults(NOW), "a")).toBe(false) -- released by the final write
		expect(GardenProgress.holds(nil, "a")).toBe(false)
	end)

	it("stamps or clears the lock without changing the profile, and sanitize drops it", function()
		local p = checkGarden()
		local record = GardenProgress.locked(p, "a", NOW)
		expect(record.lock.session).toBe("a")
		expect(record.lock.at).toBe(NOW)
		expect((p :: any).lock).toBeNil() -- input unchanged
		expect(GardenProgress.holds(record, "a")).toBe(true)
		expect(GardenProgress.canClaim(record, "b", NOW + 60)).toBe(false)
		expect(same(GardenProgress.sanitize(record, NOW), GardenProgress.sanitize(p, NOW))).toBe(true)
		local released = GardenProgress.locked(GardenProgress.sanitize(record, NOW), nil, NOW)
		expect(released.lock).toBeNil()
		expect(GardenProgress.canClaim(released, "b", NOW)).toBe(true)
	end)

	it("pays unbanked once across a server hop: the old final write releases, then the new load claims", function()
		-- Server A's last periodic flush stored 40 unbanked under A's lock.
		local stored = GardenProgress.locked(GardenProgress.snapshot(checkGarden(), 40, NOW), "a", NOW)
		expect(GardenProgress.canClaim(stored, "b", NOW + 5)).toBe(false) -- B cannot log in on it yet
		-- A's leave banks the 40 and releases the lock.
		local a = GardenProgress.bank(GardenProgress.sanitize(stored, NOW + 6), 40, 1, DAY)
		stored = GardenProgress.locked(GardenProgress.leave(a, NOW + 6), nil, NOW + 6)
		expect(GardenProgress.canClaim(stored, "b", NOW + 8)).toBe(true)
		local out, offline, unbanked = GardenProgress.login(GardenProgress.sanitize(stored, NOW + 8), NOW + 8, DAY)
		expect(unbanked).toBe(0)
		expect(out.coins).toBe(100 + 40 + offline)
		-- A late write from A is refused: A no longer holds the lock.
		expect(GardenProgress.holds(GardenProgress.locked(out, "b", NOW + 8), "a")).toBe(false)
		expect(GardenProgress.holds(stored, "a")).toBe(false)
	end)
end)

describe("GardenProgress banking and quest stats", function()
	it("banks coins (capped at 1e15) and counts pads with at least 1 coin as collects", function()
		local p = GardenProgress.bank(GardenProgress.defaults(NOW), 12.7, 3, DAY)
		expect(p.coins).toBe(112)
		expect(p.quests.progress.collects).toBe(3)
		local none = GardenProgress.bank(p, 0, 0, DAY)
		expect(none.quests.progress.collects).toBe(3)
		local capped = GardenRules.copy(p)
		capped.coins = 1e15 - 5
		expect(GardenProgress.bank(capped, 100, 1, DAY).coins).toBe(1e15)
	end)

	it("adds hatches, rareHatches and mutants on a hatch", function()
		local p = ripe(GardenProgress.defaults(NOW), "sunset")
		local out, ok, result = GardenProgress.hatch(
			p,
			1,
			{ egg = "sunset", s = "owl", m = "golden", z = "normal", forced = false },
			NOW,
			DAY
		)
		expect(ok).toBe(true)
		expect((result :: any).creature.s).toBe("owl")
		expect(out.quests.progress.hatches).toBe(1)
		expect(out.quests.progress.rareHatches).toBe(1)
		expect(out.quests.progress.mutants).toBe(1)
		expect(out.xp).toBe(60 + 50)
		local plain = GardenProgress.hatch(
			ripe(out, "sunset"),
			1,
			{ egg = "sunset", s = "cat", m = "normal", z = "big", forced = false },
			NOW,
			DAY
		)
		expect(plain.quests.progress.hatches).toBe(2)
		expect(plain.quests.progress.rareHatches).toBe(1)
		expect(plain.quests.progress.mutants).toBe(1)
		local _, refused = GardenProgress.hatch(
			p,
			1,
			{ egg = "moon", s = "fox", m = "normal", z = "normal", forced = false },
			NOW,
			DAY
		)
		expect(refused).toBe(false)
	end)

	it("pays 3 XP for an own water and counts the waters stat and total", function()
		local p = growing(GardenProgress.defaults(NOW), "moon")
		local out, ok = GardenProgress.ownWater(p, 1, NOW, DAY)
		expect(ok).toBe(true)
		expect(out.xp).toBe(3)
		expect(out.waters).toBe(1)
		expect(out.quests.progress.waters).toBe(1)
		expect(out.beds[1].ready).toBe(NOW + 3600 - 180)
		local _, again = GardenProgress.ownWater(out, 1, NOW + 30, DAY)
		expect(again).toBe(false) -- cooldown
	end)

	it("pays a helper 15 XP for the first 20 helper waters per UTC day only", function()
		local p = GardenProgress.defaults(NOW)
		local paid = 0
		for _ = 1, 25 do
			local xp
			p, xp = GardenProgress.helperWater(p, DAY)
			paid += xp
		end
		expect(paid).toBe(20 * 15)
		expect(p.xp).toBe(300)
		expect(p.waters).toBe(25)
		expect(p.quests.progress.waters).toBe(25)
		local _, tomorrow = GardenProgress.helperWater(p, DAY + 1)
		expect(tomorrow).toBe(15)
	end)

	it("counts releases", function()
		local p = checkGarden()
		local out, ok, coins = GardenProgress.release(p, 1, DAY)
		expect(ok).toBe(true)
		expect(coins).toBe(324)
		expect(out.quests.progress.releases).toBe(1)
		local _, refused, none = GardenProgress.release(p, 99, DAY)
		expect(refused).toBe(false)
		expect(none).toBe(0)
	end)
end)

describe("GardenProgress likes and gate (G1, G2)", function()
	it("likes each owner once per UTC day, never self, at most 30 a day", function()
		local p = GardenProgress.defaults(NOW)
		local _, self = GardenProgress.like(p, 5, 5, DAY)
		expect(self).toBe(false)
		local a, ok = GardenProgress.like(p, 100, 5, DAY)
		expect(ok).toBe(true)
		expect(select(2, GardenProgress.like(a, 100, 5, DAY))).toBe(false)
		expect(select(2, GardenProgress.like(a, 100, 5, DAY + 1))).toBe(true)
		local q = p
		for target = 1, 30 do
			local liked
			q, liked = GardenProgress.like(q, 1000 + target, 5, DAY)
			expect(liked).toBe(true)
		end
		expect(select(2, GardenProgress.like(q, 2000, 5, DAY))).toBe(false)
		local fresh = GardenProgress.like(q, 2000, 5, DAY + 1)
		expect(#fresh.liked.ids).toBe(1)
		expect(fresh.liked.day).toBe(DAY + 1)
		expect(#p.liked.ids).toBe(0) -- input unchanged
		expect(GardenProgress.receiveLike(GardenProgress.receiveLike(p)).likes).toBe(2)
	end)

	it("sets the gate to a known value and applies it to visitors", function()
		local p = GardenProgress.defaults(NOW)
		local out, ok = GardenProgress.setGate(p, "friends")
		expect(ok).toBe(true)
		expect(out.gate).toBe("friends")
		expect(select(2, GardenProgress.setGate(p, "locked"))).toBe(false)
		expect(GardenProgress.gateAllows("open", false)).toBe(true)
		expect(GardenProgress.gateAllows("friends", true)).toBe(true)
		expect(GardenProgress.gateAllows("friends", false)).toBe(false)
		expect(GardenProgress.gateAllows("closed", true)).toBe(false)
	end)
end)

describe("GardenProgress rewards (H5)", function()
	it("pays day 3 at 14,520 for 60.5 coins/s, 120 for 0.5 and 100 for 0", function()
		local function day3(p: Profile): number
			p.daily = { streak = 2, last = DAY - 1 }
			local _, ok, reward = GardenProgress.claimDaily(p, DAY)
			expect(ok).toBe(true)
			return reward
		end
		expect(day3(checkGarden())).toBe(14520)
		expect(day3(GardenProgress.defaults(NOW))).toBe(100)
		withIncome(0.5, function()
			expect(day3(GardenProgress.defaults(NOW))).toBe(120)
		end)
		local claimed = GardenProgress.claimDaily(checkGarden(), DAY)
		expect(claimed.coins).toBe(100 + 7260) -- day 1: 60.5 x 60 x 2 minutes
		expect(GardenProgress.scaled(checkGarden(), 500, 30)).toBe(108900)
	end)

	it("scales the weekly bonus (500, 30 minutes) and quest rewards", function()
		local p = GardenProgress.defaults(NOW)
		local monday = 7 * MetaRules.weekOf(DAY) - 3
		for d = monday, monday + 4 do
			p = GardenProgress.login(p, d * 86400, d)
		end
		local _, ok, reward = GardenProgress.claimWeekly(p, monday + 4)
		expect(ok).toBe(true)
		expect(reward).toBe(500)
		local rich = checkGarden()
		rich.week = p.week
		local _, _, scaled = GardenProgress.claimWeekly(rich, monday + 4)
		expect(scaled).toBe(108900)
		local quest = GardenProgress.questsFor(DAY)[1]
		local q = MetaRules.addProgress(GardenProgress.CONFIG, checkGarden(), DAY, { [quest.stat] = quest.goal })
		local _, qok, qreward = GardenProgress.claimQuest(q, DAY, quest.id)
		expect(qok).toBe(true)
		expect(qreward).toBe(math.max(quest.reward, math.floor(60.5 * 60 * (quest.minutes :: number) + 1e-9)))
		expect(#GardenProgress.questsFor(DAY)).toBe(3)
	end)

	it("unlocks, buys and equips cosmetics by level, Index count and price", function()
		local p = GardenProgress.defaults(NOW)
		expect(GardenProgress.isUnlocked(p, "picket")).toBe(true)
		expect(GardenProgress.isUnlocked(p, "bamboo")).toBe(false)
		p.xp = MetaRules.xpForLevel(3)
		expect(GardenProgress.levelFor(p.xp)).toBe(3)
		expect(GardenProgress.isUnlocked(p, "bamboo")).toBe(true)
		expect(GardenProgress.isUnlocked(p, "golden")).toBe(false)
		for i = 1, 20 do
			p.index[i] = `{GardenConfig.SPECIES[(i - 1) % 9 + 1].id}:{GardenConfig.MUTATIONS[(i - 1) // 9 + 1].id}`
		end
		expect(GardenProgress.isUnlocked(p, "golden")).toBe(true)
		local equipped, ok = GardenProgress.equipCosmetic(p, "golden")
		expect(ok).toBe(true)
		expect(equipped.fence).toBe("golden")
		expect(select(2, GardenProgress.buyCosmetic(p, "candy"))).toBe(false)
		p.coins = 1_000_000
		local bought, bok = GardenProgress.buyCosmetic(p, "candy")
		expect(bok).toBe(true)
		expect(bought.coins).toBe(0)
		expect(GardenProgress.equipCosmetic(bought, "candy").fence).toBe("candy")
		expect(select(2, GardenProgress.equipCosmetic(p, "ducky"))).toBe(false) -- level 4
	end)
end)

describe("GardenProgress schema v2 migration (decision 0012)", function()
	-- A literal v1 save: no prizeEggs, no dash, no celestial anywhere, with the session lock.
	local function v1Record(): any
		return {
			schemaVersion = 1,
			xp = 12345,
			coins = 987_654_321,
			lastSeen = NOW - 3600,
			unbanked = 42,
			nextId = 9,
			bedCount = 5,
			penSlots = 8,
			beds = {
				{
					egg = "star",
					planted = NOW - 600,
					ready = NOW + 13000,
					waters = 2,
					helps = 1,
					lastWater = NOW - 100,
				},
				{ egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "moon", planted = NOW - 4000, ready = NOW - 400, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "meadow", planted = NOW - 1, ready = NOW + 29, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 },
			},
			creatures = {
				{ id = 3, s = "cat", m = "golden", z = "big", placed = 1, fav = true },
				{ id = 5, s = "dragon", m = "rainbow", z = "huge", placed = 8, fav = false },
				{ id = 8, s = "bunny", m = "moonlit", z = "normal", placed = 0, fav = false },
			},
			pity = { meadow = 3, forest = 4, sunset = 5, moon = 6, star = 7 },
			index = { "cat:golden", "dragon:rainbow", "bunny:moonlit" },
			stock = { w = 6_000_000, bought = { forest = 2, moon = 1 } },
			hatches = 77,
			waters = 88,
			likes = 11,
			gate = "friends",
			fence = "candy",
			can = "ducky",
			owned = { candy = true },
			helped = { day = DAY, count = 4 },
			liked = { day = DAY, ids = { 111, 222 } },
			daily = { streak = 3, last = DAY - 1 },
			week = { key = 2900, days = 2, lastDay = DAY - 1, claimed = false },
			quests = { day = DAY, progress = { hatches = 2, waters = 5 }, claimed = { hatch5 = true } },
			lock = { session = "old", at = NOW - 10 },
		}
	end

	it("loads a literal v1 record with every field kept and only the new fields added", function()
		local record = v1Record()
		local p: any = GardenProgress.sanitize(record, NOW)
		expect(p.schemaVersion).toBe(2)
		expect(next(p.prizeEggs)).toBeNil()
		expect(same(p.dash, { day = -1, prizes = 0, coins = 0 })).toBe(true)
		expect(p.pity.celestial).toBe(0)
		expect(p.pity.aurora).toBe(0)
		expect(p.lock).toBeNil()
		local expected = v1Record()
		expected.pity.celestial = 0
		expected.pity.aurora = 0
		for field, value in expected do
			if field ~= "schemaVersion" and field ~= "lock" then
				expect(`{field} {same(p[field], value)}`).toBe(`{field} true`)
			end
		end
		for field in p do
			if field ~= "prizeEggs" and field ~= "dash" then
				expect(expected[field] ~= nil).toBe(true)
			end
		end
		expect(same(record, v1Record())).toBe(true) -- input unchanged
	end)

	it("pays a v1 player exactly as before on the first login", function()
		local out, offline, unbanked = GardenProgress.login(GardenProgress.sanitize(v1Record(), NOW), NOW, DAY)
		expect(unbanked).toBe(42)
		expect(out.coins).toBe(987_654_321 + 42 + offline)
		expect(out.schemaVersion).toBe(2)
	end)

	it("keeps prizeEggs and dash through the flush path", function()
		local p = GardenProgress.dashPrize(GardenProgress.sanitize(v1Record(), NOW), DAY)
		local stored = GardenProgress.locked(GardenProgress.snapshot(p, 0, NOW), "s", NOW)
		local again = GardenProgress.sanitize(stored, NOW + 7)
		expect(again.prizeEggs.moon).toBe(1)
		expect(same(again.dash, { day = DAY, prizes = 1, coins = 0 })).toBe(true)
		local logged = GardenProgress.login(again, NOW + 7, DAY)
		expect(logged.prizeEggs.moon).toBe(1)
		expect(logged.dash.prizes).toBe(1)
	end)

	it("keeps Celestial eggs, creatures and entries, and drops impossible pairs", function()
		local p = GardenProgress.sanitize({
			beds = { { egg = "celestial", planted = NOW, ready = NOW + 99999 } },
			pity = { celestial = 99 },
			stock = { w = 5, bought = { celestial = 4 } },
			creatures = {
				creature(1, "lion", "celestial", "normal", 1),
				creature(2, "bunny", "celestial", "normal", 2),
				creature(3, "dragon", "celestial", "huge", 0),
				creature(4, "turtle", "celestial", "normal", 0),
			},
			index = { "lion:celestial", "bunny:celestial", "dragon:celestial", "turtle:celestial" },
		}, NOW)
		expect(p.beds[1].egg).toBe("celestial")
		expect(p.beds[1].ready).toBe(NOW + 28800)
		expect(p.pity.celestial).toBe(10)
		expect(p.stock.bought.celestial).toBe(1)
		expect(table.concat(p.index, " ")).toBe("lion:celestial dragon:celestial")
		expect(#p.creatures).toBe(2)
		expect(GardenRules.find(p, 2)).toBeNil()
		expect(GardenRules.find(p, 4)).toBeNil()
		expect(p.nextId).toBe(4)
	end)

	it("keeps sold prize eggs only, counts of at least 1, clamped to 1,000,000", function()
		local p = GardenProgress.sanitize({
			prizeEggs = {
				moon = 2.9,
				star = 5e9,
				meadow = 0.5,
				forest = -3,
				sunset = 0 / 0,
				celestial = "x",
				starter = 4,
				nope = 7,
				[1] = 3,
			},
		}, NOW)
		expect(same(p.prizeEggs, { moon = 2, star = 1_000_000 })).toBe(true)
		expect(next(GardenProgress.sanitize({ prizeEggs = "moon" }, NOW).prizeEggs)).toBeNil()
	end)

	it("clamps dash counters to their daily caps and falls back to day -1", function()
		local p = GardenProgress.sanitize({ dash = { day = DAY + 0.5, prizes = 99, coins = 99.5 } }, NOW)
		expect(same(p.dash, { day = DAY, prizes = 3, coins = 6 })).toBe(true)
		local bad = GardenProgress.sanitize({ dash = { day = "x", prizes = -1, coins = 0 / 0 } }, NOW)
		expect(same(bad.dash, { day = -1, prizes = 0, coins = 0 })).toBe(true)
		expect(GardenProgress.sanitize({ dash = 5 }, NOW).dash.day).toBe(-1)
	end)
end)

describe("GardenProgress schema v2 unchanged by v0.3 (decision 0014)", function()
	-- A literal v2 save from before 0014: old ids only, a Celestial in a bed, prizeEggs and dash.
	local function v2Record(): any
		return {
			schemaVersion = 2,
			xp = 99_000,
			coins = 1_234_567_890,
			lastSeen = NOW - 7200,
			unbanked = 7,
			nextId = 12,
			bedCount = 6,
			penSlots = 9,
			beds = {
				{
					egg = "celestial",
					planted = NOW - 600,
					ready = NOW + 28000,
					waters = 1,
					helps = 0,
					lastWater = NOW - 500,
				},
				{ egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "star", planted = NOW - 4000, ready = NOW + 9000, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "moon", planted = NOW - 1, ready = NOW + 3599, waters = 0, helps = 0, lastWater = 0 },
				{ egg = "", planted = 0, ready = 0, waters = 0, helps = 0, lastWater = 0 },
			},
			creatures = {
				{ id = 3, s = "cat", m = "golden", z = "big", placed = 1, fav = true },
				{ id = 5, s = "dragon", m = "celestial", z = "huge", placed = 2, fav = false },
				{ id = 8, s = "lion", m = "celestial", z = "normal", placed = 9, fav = false },
				{ id = 11, s = "owl", m = "moonlit", z = "normal", placed = 0, fav = false },
			},
			pity = { meadow = 3, forest = 4, sunset = 5, moon = 6, star = 7, celestial = 8 },
			index = { "cat:golden", "dragon:celestial", "lion:celestial", "owl:moonlit", "pup:normal" },
			stock = { w = 6_000_000, bought = { forest = 2, celestial = 1 } },
			hatches = 77,
			waters = 88,
			likes = 11,
			gate = "friends",
			fence = "candy",
			can = "ducky",
			owned = { candy = true },
			helped = { day = DAY, count = 4 },
			liked = { day = DAY, ids = { 111, 222 } },
			daily = { streak = 3, last = DAY - 1 },
			week = { key = 2900, days = 2, lastDay = DAY - 1, claimed = false },
			quests = { day = DAY, progress = { hatches = 2, waters = 5 }, claimed = { hatch5 = true } },
			prizeEggs = { moon = 2 },
			dash = { day = DAY, prizes = 1, coins = 3 },
		}
	end

	it("loads a literal pre-0014 v2 record with every field kept and only pity.aurora added", function()
		local record = v2Record()
		local p: any = GardenProgress.sanitize(record, NOW)
		expect(p.schemaVersion).toBe(2)
		expect(GardenProgress.SCHEMA_VERSION).toBe(2)
		local expected = v2Record()
		expected.pity.aurora = 0
		expect(same(p, expected)).toBe(true)
		expect(same(record, v2Record())).toBe(true) -- input unchanged
		expect(same(GardenProgress.sanitize(p, NOW), p)).toBe(true)
	end)

	it("keeps a record holding whale:rainbow, an Aurora Egg and pity.aurora unchanged", function()
		local record = v2Record()
		record.beds[2] =
			{ egg = "aurora", planted = NOW - 100, ready = NOW + 43100, waters = 0, helps = 0, lastWater = 0 }
		table.insert(record.creatures, { id = 11, s = "whale", m = "rainbow", z = "huge", placed = 3, fav = false })
		record.creatures[4].id = 10
		record.creatures[4].s = "axolotl"
		table.insert(record.index, "whale:rainbow")
		table.insert(record.index, "axolotl:moonlit")
		table.insert(record.index, "phoenix:celestial")
		record.pity.aurora = 19
		record.stock.bought.aurora = 1
		local p: any = GardenProgress.sanitize(record, NOW)
		expect(same(p, record)).toBe(true)
		expect(p.schemaVersion).toBe(2)
		-- Clamps still apply to the new ids: pity at the meter, stock at max, no celestial Divine.
		record.pity.aurora = 99
		record.stock.bought.aurora = 5
		table.insert(record.index, "whale:celestial")
		table.insert(record.creatures, { id = 20, s = "kirin", m = "celestial", z = "normal", placed = 4, fav = false })
		p = GardenProgress.sanitize(record, NOW)
		expect(`{p.pity.aurora} {p.stock.bought.aurora} {#p.index} {#p.creatures}`).toBe("20 1 8 5")
	end)
end)

describe("GardenProgress.sanitize on junk", function()
	local NIL = {} -- stands for a missing value in JUNK
	local JUNK: { any } = {
		NIL,
		0,
		-1,
		1.5,
		1e308,
		-1e308,
		0 / 0,
		math.huge,
		-math.huge,
		"",
		"x",
		"moon",
		"bunny:celestial",
		"dragon:celestial",
		true,
		false,
		{},
		{ 1, 2, 3 },
		{ "x", true, {} },
		{ moon = 1e12, a = { b = {} } },
		{ { egg = "celestial", id = 1, s = "lion", m = "celestial", z = "huge" } },
	}

	-- Walks `value`, replacing about one in six of its nodes with junk.
	local function scramble(value: any, rng: number): (any, number)
		local r
		r, rng = Rng.int(rng, 1, 6)
		if r == 1 then
			r, rng = Rng.int(rng, 1, #JUNK)
			return if JUNK[r] == NIL then nil else JUNK[r], rng
		end
		if type(value) ~= "table" then
			return value, rng
		end
		local out = {}
		for k, v in value do
			out[k], rng = scramble(v, rng)
		end
		return out, rng
	end

	local function base(): Profile
		local p = checkGarden()
		p.bedCount = 4
		p.beds[2] = { egg = "celestial", planted = NOW, ready = NOW + 900, waters = 1, helps = 2, lastWater = NOW }
		p.beds[4] = { egg = "moon", planted = NOW, ready = NOW + 900, waters = 1, helps = 2, lastWater = NOW }
		table.insert(p.creatures, creature(3, "dragon", "celestial", "huge", 3))
		table.insert(p.index, "dragon:celestial")
		p.prizeEggs = { moon = 3, star = 1 }
		p.dash = { day = DAY, prizes = 2, coins = 5 }
		p.stock = { w = 6_000_000, bought = { forest = 2, celestial = 1 } }
		p.liked = { day = DAY, ids = { 1, 2, 3 } }
		p.helped = { day = DAY, count = 2 }
		p.owned = { candy = true }
		p.quests = { day = DAY, progress = { hatches = 2 }, claimed = { hatch5 = true } }
		p.daily = { streak = 2, last = DAY }
		p.week = { key = 2900, days = 3, lastDay = DAY, claimed = true }
		return p
	end

	it("never errors and is idempotent on 3,000 scrambled records, with and without now", function()
		local rng = Rng.seed(2026)
		local source = base()
		for i = 1, 3000 do
			local record
			record, rng = scramble(source, rng)
			local now = if i % 2 == 0 then NOW else nil
			local ok, first = pcall(GardenProgress.sanitize, record, now)
			if not ok then
				error(`record {i}: {first}`)
			end
			if not same(GardenProgress.sanitize(first, now), first) then
				error(`record {i}: a second sanitize changed it`)
			end
		end
	end)

	it("returns defaults for values of every wrong type", function()
		for _, value in JUNK do
			if type(value) ~= "table" then
				expect(same(GardenProgress.sanitize(value, NOW), GardenProgress.defaults(NOW))).toBe(true)
			end
		end
	end)

	it("sets every field to every junk value in turn without an error", function()
		local source = base() :: any
		for field in source do
			for _, value in JUNK do
				local record = GardenRules.copy(source);
				(record :: any)[field] = if value == NIL then nil else value
				local first = GardenProgress.sanitize(record, NOW)
				expect(`{field} {same(GardenProgress.sanitize(first, NOW), first)}`).toBe(`{field} true`)
			end
		end
	end)
end)

describe("GardenProgress Splash Dash prizes (T5, decision 0012)", function()
	it("adds a Moon Egg and counts it, at any level and with full beds", function()
		local p = GardenProgress.defaults(NOW)
		for i = 1, 3 do
			p.beds[i] = { egg = "meadow", planted = NOW, ready = NOW + 30, waters = 0, helps = 0, lastWater = 0 }
		end
		local out, ok = GardenProgress.dashPrize(p, DAY)
		expect(ok).toBe(true)
		expect(out.prizeEggs.moon).toBe(1)
		expect(same(out.dash, { day = DAY, prizes = 1, coins = 0 })).toBe(true)
		expect(GardenRules.level(out)).toBe(1)
		expect(next(p.prizeEggs)).toBeNil() -- input unchanged
		expect(p.dash.day).toBe(-1)
		-- It waits through saves, and plants once a bed and the level are there.
		local stored = GardenProgress.sanitize(GardenProgress.snapshot(out, 0, NOW), NOW)
		expect(stored.prizeEggs.moon).toBe(1)
		expect(GardenRules.canPlantPrize(stored, "moon")).toBe(false)
		stored.xp = MetaRules.xpForLevel(10)
		expect(GardenRules.canPlantPrize(stored, "moon")).toBe(false) -- beds still full
		stored.beds[2].egg = ""
		expect(GardenRules.canPlantPrize(stored, "moon")).toBe(true)
	end)

	it("goes 2 to 3 on a win, then is not eligible until the next UTC day", function()
		local p = GardenProgress.defaults(NOW)
		p.dash = { day = DAY, prizes = 2, coins = 4 }
		expect(GardenProgress.dashEligible(p, DAY)).toBe(true)
		local out, ok = GardenProgress.dashPrize(p, DAY)
		expect(ok).toBe(true)
		expect(GardenProgress.dashPrizesToday(out, DAY)).toBe(3)
		expect(GardenProgress.dashEligible(out, DAY)).toBe(false)
		local same1, refused = GardenProgress.dashPrize(out, DAY)
		expect(refused).toBe(false)
		expect(same1).toBe(out)
		expect(GardenProgress.dashPrizesToday(out, DAY + 1)).toBe(0)
		expect(GardenProgress.dashEligible(out, DAY + 1)).toBe(true)
		local tomorrow = GardenProgress.dashPrize(out, DAY + 1)
		expect(same(tomorrow.dash, { day = DAY + 1, prizes = 1, coins = 0 })).toBe(true)
		expect(tomorrow.prizeEggs.moon).toBe(2) -- the daily reset never touches the eggs
	end)

	it("resets at 00:00:00 UTC, not a second before", function()
		local midnight = (DAY + 1) * 86400
		local p = GardenProgress.defaults(NOW)
		for _ = 1, 3 do
			p = GardenProgress.dashPrize(p, MetaRules.dayOf(midnight - 1))
		end
		expect(GardenProgress.dashEligible(p, MetaRules.dayOf(midnight - 1))).toBe(false)
		expect(GardenProgress.dashEligible(p, MetaRules.dayOf(midnight))).toBe(true)
	end)

	it("gives the same result when re-applied to a copy of the stored record, and adds one egg once", function()
		local stored = GardenProgress.sanitize(GardenProgress.defaults(NOW), NOW)
		local memory = GardenProgress.dashPrize(stored, DAY)
		local written = GardenProgress.dashPrize(GardenRules.copy(stored), DAY)
		expect(same(memory, written)).toBe(true)
		expect(written.prizeEggs.moon).toBe(1)
		-- A failed UpdateAsync retries from the old record, so a retry cannot stack.
		expect(same(GardenProgress.dashPrize(GardenRules.copy(stored), DAY), written)).toBe(true)
	end)

	it("hatches a planted prize as a normal Moon Egg with its Lucky Meter and 150 XP", function()
		local p = GardenProgress.defaults(NOW)
		p.xp = MetaRules.xpForLevel(10)
		p.prizeEggs = { moon = 1 }
		p = GardenRules.plantPrize(p, "moon", NOW)
		local out, ok, r = GardenProgress.hatch(
			p,
			2,
			{ egg = "moon", s = "fox", m = "normal", z = "normal", forced = false } :: HatchRules.Outcome,
			NOW + 3600,
			DAY
		)
		expect(ok).toBe(true)
		expect((r :: any).xp).toBe(150 + 50)
		expect(out.pity.moon).toBe(1)
	end)

	it("pays 1 minute of income, at least 100: 3,630 at 60.5 coins/s, 100 at 0", function()
		local p = checkGarden()
		local out, paid = GardenProgress.dashCoins(p, DAY)
		expect(paid).toBe(3630)
		expect(out.coins).toBe(p.coins + 3630)
		expect(same(out.dash, { day = DAY, prizes = 0, coins = 1 })).toBe(true)
		local poor, base = GardenProgress.dashCoins(GardenProgress.defaults(NOW), DAY)
		expect(base).toBe(100)
		expect(poor.coins).toBe(200)
		expect(p.dash.coins).toBe(0) -- input unchanged
	end)

	it("stops at 6 coin rewards a UTC day, resets the next day, and never passes MAX_COINS", function()
		local p = GardenProgress.defaults(NOW)
		for i = 1, 6 do
			local paid
			p, paid = GardenProgress.dashCoins(p, DAY)
			expect(paid).toBe(100)
			expect(p.dash.coins).toBe(i)
		end
		local capped, none = GardenProgress.dashCoins(p, DAY)
		expect(none).toBe(0)
		expect(capped).toBe(p)
		local tomorrow, paid = GardenProgress.dashCoins(p, DAY + 1)
		expect(paid).toBe(100)
		expect(tomorrow.dash.coins).toBe(1)
		local rich = GardenProgress.defaults(NOW)
		rich.coins = 1e15 - 40
		local top, last = GardenProgress.dashCoins(rich, DAY)
		expect(top.coins).toBe(1e15)
		expect(last).toBe(40)
	end)
end)

describe("GardenProgress.sanitize (H7)", function()
	it("returns defaults for a missing record", function()
		expect(same(GardenProgress.sanitize(nil, NOW), GardenProgress.defaults(NOW))).toBe(true)
		expect(same(GardenProgress.sanitize("junk"), GardenProgress.defaults(0))).toBe(true)
	end)

	it("floors and clamps numbers", function()
		local p = GardenProgress.sanitize({
			xp = 5e9,
			coins = 2e15,
			unbanked = -3,
			hatches = 12.9,
			waters = 0 / 0,
			likes = math.huge,
			nextId = "9",
			bedCount = 40,
			penSlots = 2,
		}, NOW)
		expect(p.xp).toBe(1_000_000)
		expect(p.coins).toBe(1e15)
		expect(p.unbanked).toBe(0)
		expect(p.hatches).toBe(12)
		expect(p.waters).toBe(0)
		expect(p.likes).toBe(0)
		expect(p.nextId).toBe(1)
		expect(p.bedCount).toBe(12)
		expect(#p.beds).toBe(12)
		expect(p.penSlots).toBe(6)
		expect(GardenProgress.sanitize({ bedCount = 1, penSlots = 99 }).bedCount).toBe(3)
		expect(GardenProgress.sanitize({ penSlots = 99 }).penSlots).toBe(20)
	end)

	it("trims or pads beds, empties unknown eggs and clamps ready, waters and helps", function()
		local beds = {
			{ egg = "moon", planted = 1000, ready = 99999, waters = 9, helps = -1, lastWater = 1200 },
			{ egg = "dragonfruit", planted = 1000, ready = 1100 },
			{ egg = "meadow", planted = 1000, ready = 10 },
			{ egg = "forest", planted = 1000, ready = 1100 },
		}
		local p = GardenProgress.sanitize({ bedCount = 3, beds = beds }, NOW)
		expect(#p.beds).toBe(3)
		expect(p.beds[1].ready).toBe(1000 + 3600)
		expect(p.beds[1].waters).toBe(5)
		expect(p.beds[1].helps).toBe(0)
		expect(p.beds[1].lastWater).toBe(1200)
		expect(p.beds[2].egg).toBe("")
		expect(p.beds[2].ready).toBe(0)
		expect(p.beds[3].ready).toBe(1000)
		local padded = GardenProgress.sanitize({ bedCount = 5, beds = { beds[1] } }, NOW)
		expect(#padded.beds).toBe(5)
		expect(padded.beds[5].egg).toBe("")
		expect(GardenProgress.sanitize({ beds = "x" }, NOW).beds[1].egg).toBe("")
	end)

	it("drops unknown creatures, keeps the first of duplicate ids and unplaces bad or taken pads", function()
		local p = GardenProgress.sanitize({
			penSlots = 6,
			nextId = 2,
			creatures = {
				creature(1, "cat", "golden", "big", 1),
				creature(2, "yeti", "normal", "normal", 2),
				creature(3, "cat", "shiny", "normal", 2),
				creature(4, "cat", "normal", "tiny", 2),
				creature(1, "frog", "normal", "normal", 3),
				creature(5, "frog", "normal", "normal", 1),
				creature(6, "frog", "normal", "normal", 7),
				creature(7, "frog", "normal", "normal", -2),
				{ id = "8", s = "frog", m = "normal", z = "normal", placed = 0 },
				"junk",
				{ id = 9, s = "pup", m = "normal", z = "normal", placed = 2, fav = true },
			},
		}, NOW)
		local out = {}
		for _, c in p.creatures do
			table.insert(out, `{c.id}:{c.s}:{c.placed}:{c.fav}`)
		end
		expect(table.concat(out, " ")).toBe("1:cat:1:false 5:frog:0:false 6:frog:0:false 7:frog:0:false 9:pup:2:true")
		expect(p.nextId).toBe(10)
	end)

	it("keeps at most penSlots placed and 60 stored, dropping the lowest stored ids first", function()
		local list = {}
		for id = 1, 90 do
			table.insert(list, creature(id, "bunny", "normal", "normal", if id <= 8 then id else 0))
		end
		local p = GardenProgress.sanitize({ penSlots = 6, nextId = 91, creatures = list }, NOW)
		expect(#p.creatures).toBe(6 + 60)
		expect(GardenRules.storageCount(p)).toBe(60)
		expect(GardenRules.find(p, 1) ~= nil).toBe(true) -- placed, kept
		expect(GardenRules.find(p, 7)).toBeNil() -- pad 7 > penSlots: stored, oldest, dropped
		expect(GardenRules.find(p, 30)).toBeNil()
		expect(GardenRules.find(p, 31) ~= nil).toBe(true)
		expect(GardenRules.find(p, 90) ~= nil).toBe(true)
		expect(p.nextId).toBe(91)
	end)

	it("drops unknown and duplicate Index keys and clamps pity and stock", function()
		local p = GardenProgress.sanitize({
			index = { "cat:golden", "cat:golden", "yeti:normal", "cat:shiny", 5, "cat", "bunny:normal" },
			pity = { meadow = 999, forest = -4, sunset = 12.5, moon = "x", star = 25, starter = 3 },
			stock = { w = 6_000_000.7, bought = { forest = 99, moon = 1, meadow = 4, star = -1 } },
		}, NOW)
		expect(table.concat(p.index, " ")).toBe("cat:golden bunny:normal")
		expect(p.pity.meadow).toBe(50)
		expect(p.pity.forest).toBe(0)
		expect(p.pity.sunset).toBe(12)
		expect(p.pity.moon).toBe(0)
		expect(p.pity.star).toBe(25)
		expect(p.pity.starter).toBeNil()
		expect(p.stock.w).toBe(6_000_000)
		expect(p.stock.bought.forest).toBe(4)
		expect(p.stock.bought.moon).toBe(1)
		expect(p.stock.bought.meadow).toBeNil()
		expect(p.stock.bought.star).toBeNil()
	end)

	it("falls back for gate, locked or unknown cosmetics and unpriced owned ids", function()
		local p = GardenProgress.sanitize({
			gate = "wide",
			fence = "crystal",
			can = "teapot",
			owned = { candy = true, picket = true, bamboo = true, galaxy = "yes" },
		}, NOW)
		expect(p.gate).toBe("open")
		expect(p.fence).toBe("picket")
		expect(p.can).toBe("tin")
		expect(p.owned.candy).toBe(true)
		expect(p.owned.picket).toBeNil()
		expect(p.owned.bamboo).toBeNil()
		expect(p.owned.galaxy).toBeNil()
		expect(GardenProgress.sanitize({ gate = "closed" }).gate).toBe("closed")
		expect(GardenProgress.sanitize({ fence = "candy", owned = { candy = true } }).fence).toBe("candy")
	end)

	it("moves a future lastSeen to now, keeps at most 30 liked ids and never adds wins", function()
		local ids = {}
		for i = 1, 40 do
			ids[i] = i
		end
		ids[3] = "x" :: any
		local p = GardenProgress.sanitize({
			lastSeen = NOW + 500,
			wins = 7,
			liked = { day = DAY, ids = ids },
			helped = { day = DAY, count = 4.5 },
		}, NOW)
		expect(p.lastSeen).toBe(NOW)
		expect(GardenProgress.sanitize({ lastSeen = NOW + 500 }).lastSeen).toBe(NOW + 500) -- no now given
		expect(#p.liked.ids).toBe(30)
		expect(p.liked.ids[3]).toBe(4)
		expect(p.liked.day).toBe(DAY)
		expect(p.helped.count).toBe(4)
		expect((p :: any).wins).toBeNil()
	end)
end)
