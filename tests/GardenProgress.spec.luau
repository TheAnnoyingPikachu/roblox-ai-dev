--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local MetaRules = require("../src/shared/MetaRules")

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
		expect(p.schemaVersion).toBe(1)
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
		expect(p.pity.meadow + p.pity.forest + p.pity.sunset + p.pity.moon + p.pity.star).toBe(0)
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
