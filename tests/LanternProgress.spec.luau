--!strict
-- LanternProgress (architecture lantern 3.8, 8; decision 0018 section 4; GDD H, J): the v1 save,
-- shares, loads, the album and milestones, quests saved for you, the login tracks, bests, badges,
-- and the rule that nothing earned is ever lost.
local T = require("./framework")
local LanternConfig = require("../src/shared/LanternConfig")
local LanternProgress = require("../src/shared/LanternProgress")
local LoginRules = require("../src/shared/LoginRules")
local MetaRules = require("../src/shared/MetaRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = LanternProgress.Profile
type Loaded = LanternProgress.Loaded

local NOW = 1_762_400_000 -- Thursday 2025-11-06 03:33 UTC
local TODAY = MetaRules.dayOf(NOW)
local MONDAY = 20759 -- 2026-11-02, a Monday and the 2nd of the month (as LoginRules.spec)

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

local function critter(id: string): Loaded
	local c = LanternConfig.critter(id) :: LanternConfig.Critter
	return { kind = "critter", species = id, rarity = c.rarity :: any }
end

local function fresh(): Profile
	return LanternProgress.defaults(NOW)
end

local ROLLABLE = {
	"mossmouse",
	"puddlefrog",
	"wickmole",
	"burrbun",
	"lanternbeetle",
	"fogpup",
	"acornowlet",
	"teapotcat",
	"reedfox",
	"mistfawn",
	"bellturtle",
	"moonhare",
}

describe("LanternProgress: the v1 save", function()
	it("starts at schema 1 with default slots, empty album and zero stats", function()
		local p = fresh()
		expect(`{p.schemaVersion} {p.xp} {p.coins} {p.lastSeen} {#p.index} {p.livery} {p.lamp} {p.badge} {p.follower}`).toBe(
			`1 0 0 {NOW} 0 classic warm  `
		)
		for _, key in LanternProgress.STATS do
			expect(p.stats[key]).toBe(0)
		end
		expect(same(p.login, LoginRules.defaults())).toBe(true)
		expect(`{p.weekBest.week} {p.quests.day}`).toBe("-1 -1")
	end)

	it("sanitises numbers: floored, clamped to the 0018 caps, junk to zero", function()
		local p = LanternProgress.sanitize({
			xp = 2e9,
			coins = 99.9,
			stats = { puffs = 5.7, loads = -3, runs = 0 / 0, stokes = math.huge, junk = 9 },
			best = { critters = 3.5, dist = 99999 },
			rescues = { mossmouse = 2.9 },
		}, NOW)
		expect(`{p.xp} {p.coins} {p.stats.puffs} {p.stats.loads} {p.stats.runs} {p.stats.stokes} {p.stats.junk}`).toBe(
			"1000000 99 5 0 0 0 nil"
		)
		expect(`{p.best.critters} {p.best.dist} {p.rescues.mossmouse}`).toBe("3 20000 2")
		expect(LanternProgress.sanitize({ coins = 2e9 }).coins).toBe(10000000)
		expect(same(LanternProgress.sanitize(nil, NOW), fresh())).toBe(true)
		expect(same(LanternProgress.sanitize("x", NOW), fresh())).toBe(true)
	end)

	it("keeps the album consistent: unknown species dropped, counted species indexed in id order", function()
		local p = LanternProgress.sanitize({
			index = { "fogpup", "dragon", "mossmouse", "fogpup", "reedfox", 7 },
			rescues = { fogpup = 1, mossmouse = 3, dragon = 2, teapotcat = 1, acornowlet = 2, reedfox = 0 },
		}, NOW)
		-- reedfox has no count: out of the index; teapotcat and acornowlet appended in id order
		expect(table.concat(p.index, " ")).toBe("fogpup mossmouse acornowlet teapotcat")
		expect(`{p.rescues.dragon} {p.rescues.reedfox} {p.rescues.acornowlet}`).toBe("nil nil 2")
	end)

	it("checks follower, slots, badge, owned and milestones against the album, level and stats", function()
		local p = LanternProgress.sanitize({
			xp = MetaRules.xpForLevel(5),
			rescues = { mossmouse = 1 },
			follower = "fogpup",
			livery = "fern", -- level 10
			lamp = "mint", -- level 3: unlocked
			badge = "stoker",
			stats = { stokes = 29 },
			owned = { brass = true, ember = true, midnight = true, nope = true, sky = "yes" },
			milestones = { ["4"] = true, ["5"] = true, ["12"] = "yes" },
		}, NOW)
		expect(`{p.follower} {p.livery} {p.lamp} {p.badge}`).toBe(" classic mint ")
		local owned = {}
		for id in p.owned do
			table.insert(owned, id)
		end
		table.sort(owned)
		expect(table.concat(owned, " ")).toBe("brass midnight")
		expect(`{p.milestones["4"]} {p.milestones["5"]} {p.milestones["12"]}`).toBe("true nil nil")
		local q = LanternProgress.sanitize({
			rescues = { fogpup = 1 },
			follower = "fogpup",
			livery = "brass",
			owned = { brass = true },
			badge = "stoker",
			stats = { stokes = 30 },
		}, NOW)
		expect(`{q.follower} {q.livery} {q.badge}`).toBe("fogpup brass stoker")
		expect(LanternProgress.sanitize({ livery = "brass" }, NOW).livery).toBe("classic") -- not owned
	end)

	it(
		"moves a future lastSeen to now, resets an old weekBest, keeps this week's, and loads any record as v1",
		function()
			local week = MetaRules.weekOf(TODAY)
			local p = LanternProgress.sanitize(
				{ lastSeen = NOW + 999, weekBest = { week = week - 1, critters = 9, dist = 900 } },
				NOW
			)
			expect(`{p.lastSeen} {p.weekBest.week} {p.weekBest.critters} {p.weekBest.dist}`).toBe(`{NOW} {week} 0 0`)
			local q = LanternProgress.sanitize({ weekBest = { week = week, critters = 9, dist = 900 } }, NOW)
			expect(`{q.weekBest.critters} {q.weekBest.dist}`).toBe("9 900")
			expect(LanternProgress.sanitize({ xp = 5 }, NOW).schemaVersion).toBe(1)
			expect(LanternProgress.sanitize({ schemaVersion = 7 }, NOW).schemaVersion).toBe(1)
			local login = LanternProgress.sanitize({ login = { week = 2960.7, weekDays = 40 } }, NOW).login
			expect(same(login, LoginRules.sanitize({ week = 2960.7, weekDays = 40 }))).toBe(true)
			local quests = LanternProgress.sanitize(
				{ quests = { day = TODAY, progress = { rescues = 2.5 }, claimed = { rescue3 = true } } },
				NOW
			)
			expect(`{quests.quests.day} {quests.quests.progress.rescues} {quests.quests.claimed.rescue3}`).toBe(
				`{TODAY} 2 true`
			)
		end
	)

	it("flags a newer save as read-only (isNewer) and snapshots lastSeen", function()
		expect(
			`{LanternProgress.isNewer({ schemaVersion = 2 })} {LanternProgress.isNewer({ schemaVersion = 1 })} {LanternProgress.isNewer({})} {LanternProgress.isNewer(
				"x"
			)}`
		).toBe("true false false false")
		local p = fresh()
		local s = LanternProgress.snapshot(p, NOW + 60)
		expect(`{s.lastSeen} {p.lastSeen}`).toBe(`{NOW + 60} {NOW}`)
	end)
end)

describe("LanternProgress: loads and payouts", function()
	it("shares a load's Tickets as ceil(v (1 + 0.1 (n - 1)) / n)", function()
		local rows = {}
		for _, v in { 1, 8, 10, 100 } do
			local row = {}
			for n = 1, 6 do
				table.insert(row, LanternProgress.share(v, n))
			end
			table.insert(rows, table.concat(row, " "))
		end
		expect(table.concat(rows, " | ")).toBe("1 1 1 1 1 1 | 8 5 4 3 3 2 | 10 6 4 4 3 3 | 100 55 40 33 28 25")
	end)

	it("pays the first rescue of GDD K: +10 Tickets, +75 XP, level 2, NEW! in the album", function()
		local p, paid = LanternProgress.load(fresh(), { critter("mossmouse") }, true, 1, TODAY)
		expect(`{paid.tickets} {paid.xp} {table.concat(paid.new, " ")} {p.coins} {p.xp} {MetaRules.levelFor(p.xp)}`).toBe(
			"10 75 mossmouse 10 75 2"
		)
		expect(`{p.index[1]} {p.rescues.mossmouse} {p.stats.rescues} {p.stats.loads} {p.quests.progress.rescues}`).toBe(
			"mossmouse 1 1 1 1"
		)
		expect(paid.text).toBe("NEW! Moss Mouse · +10 Tickets · +75 XP")
	end)

	it(
		"levels by the shared curve as GDD P: 1,053 XP a run is level 6, 9, 17, 29, 50 after 1, 3, 10, 30, 100 runs",
		function()
			local levels = {}
			for _, runs in { 1, 3, 10, 30, 100 } do
				table.insert(levels, MetaRules.levelFor(1053 * runs))
			end
			expect(table.concat(levels, " ")).toBe("6 9 17 29 50")
		end
	)

	it("gives small and big XP only to the carrier, rescue XP to everyone, a new species once", function()
		local items: { Loaded } = { { kind = "coal" }, { kind = "parts" }, { kind = "supply" }, critter("teapotcat") }
		local mine, paidMine = LanternProgress.load(fresh(), items, true, 3, TODAY)
		local theirs, paidTheirs = LanternProgress.load(fresh(), items, false, 3, TODAY)
		-- Tickets: 1 + 1 + ceil(8 * 1.2 / 3) + ceil(25 * 1.2 / 3) = 1 + 1 + 4 + 10
		expect(`{paidMine.tickets} {paidMine.xp} {mine.stats.loads}`).toBe("16 84 4") -- 2 + 2 + 5 + 5 + 20 + 50
		expect(`{paidTheirs.tickets} {paidTheirs.xp} {theirs.stats.loads}`).toBe("16 70 0") -- 20 + 50
		expect(`{theirs.stats.rareRescues} {theirs.quests.progress.rareRescues}`).toBe("1 1")
		local again, paidAgain = LanternProgress.load(mine, { critter("teapotcat") }, false, 1, TODAY)
		expect(`{paidAgain.xp} {#paidAgain.new} {again.rescues.teapotcat} {#again.index}`).toBe("20 0 2 1")
	end)

	it("pays album milestones 4, 8 and 12 once each, with the Mossback and Moonlit grants", function()
		local p = fresh()
		local coinsAt = {}
		for i, id in ROLLABLE do
			local paid
			p, paid = LanternProgress.load(p, { critter(id) }, false, 1, TODAY)
			coinsAt[i] = paid.tickets
				- (LanternConfig.CRITTER_TICKETS :: any)[(LanternConfig.critter(id) :: any).rarity]
		end
		expect(`{coinsAt[3]} {coinsAt[4]} {coinsAt[8]} {coinsAt[12]}`).toBe("0 200 0 1000")
		expect(`{p.owned.mossback} {p.owned.moonlit} {p.milestones["4"]} {p.milestones["8"]} {p.milestones["12"]}`).toBe(
			"true true true true true"
		)
		local again, paid = LanternProgress.load(p, { critter("mossmouse") }, false, 1, TODAY)
		expect(`{paid.tickets} {again.coins - p.coins}`).toBe("10 10")
		expect(LanternProgress.equip(p, "mossback").livery).toBe("mossback")
		expect(select(2, LanternProgress.buy(p, "mossback"))).toBe(false) -- granted, never sold
	end)

	it("pays the Depot, Dawn, the Lampeater, leftover Parts and stop XP to whoever is aboard", function()
		local p = fresh()
		local rows = {}
		for _, kind in { "depot", "dawn", "fed", "parts", "stop" } do
			local paid
			p, paid = LanternProgress.award(p, kind :: any, 7, TODAY)
			table.insert(rows, `{kind}:{paid.tickets}:{paid.xp}`)
		end
		expect(table.concat(rows, " ")).toBe("depot:30:40 dawn:150:150 fed:50:0 parts:7:0 stop:0:5")
		expect(`{p.coins} {p.xp} {p.stats.depots} {p.stats.dawns} {p.stats.legs} {p.stats.fed}`).toBe("237 195 1 1 2 1")
		expect(`{p.quests.progress.depots} {p.quests.progress.dawns}`).toBe("1 1")
		local same0, paid0 = LanternProgress.award(p, "bogus" :: any, 5, TODAY)
		expect(`{same0 == p} {paid0.tickets}`).toBe("true 0")
	end)

	it("counts puffs (2 XP), stokes (1), mends (3) and catches (0) with quest progress", function()
		local p = LanternProgress.count(fresh(), "puffs", 3, TODAY)
		p = LanternProgress.count(p, "stokes", 2, TODAY)
		p = LanternProgress.count(p, "mends", 1, TODAY)
		p = LanternProgress.count(p, "caught", 1, TODAY)
		expect(`{p.xp} {p.stats.puffs} {p.stats.stokes} {p.stats.mends} {p.stats.caught}`).toBe("11 3 2 1 1")
		expect(`{p.quests.progress.puffs} {p.quests.progress.stokes}`).toBe("3 2")
		expect(LanternProgress.count(p, "puffs", 0, TODAY) == p).toBe(true)
	end)

	it("keeps all-time and weekly bests, resets the week, and caps a Dawn finish at three legs", function()
		local p, up = LanternProgress.runEnd(fresh(), 6, 9000, 100, false)
		expect(`{p.best.critters} {p.best.dist} {p.weekBest.week} {p.weekBest.critters} {up.critters} {up.dist}`).toBe(
			"6 9000 100 6 true true"
		)
		p, up = LanternProgress.runEnd(p, 4, 12000, 100, false)
		expect(`{p.best.critters} {p.best.dist} {p.weekBest.critters} {p.weekBest.dist} {up.critters} {up.dist}`).toBe(
			"6 12000 6 12000 false true"
		)
		p, up = LanternProgress.runEnd(p, 2, 300, 101, false)
		expect(`{p.weekBest.week} {p.weekBest.critters} {p.weekBest.dist} {up.critters}`).toBe("101 2 300 true")
		p, up = LanternProgress.runEnd(p, 1, 50, nil, true)
		expect(`{p.best.dist} {p.weekBest.dist} {up.dist} {p.stats.runs}`).toBe("17100 300 false 4")
	end)

	it("earns role badges at 30 / 300 / 1,500 stokes and follows only album species", function()
		local p = LanternProgress.sanitize({ stats = { stokes = 299, puffs = 5000 }, rescues = { fogpup = 1 } }, NOW)
		expect(
			`{LanternProgress.tier(p, "stoker")} {LanternProgress.tier(p, "lamplighter")} {LanternProgress.tier(
				p,
				"mender"
			)}`
		).toBe("1 3 0")
		expect(select(2, LanternProgress.setBadge(p, "mender"))).toBe(false)
		local b = LanternProgress.setBadge(p, "stoker")
		expect(b.badge).toBe("stoker")
		expect(LanternProgress.setBadge(b, "none").badge).toBe("")
		expect(select(2, LanternProgress.setFollower(p, "mossmouse"))).toBe(false)
		local f = LanternProgress.setFollower(p, "fogpup")
		expect(`{f.follower} {LanternProgress.setFollower(f, "none").follower}`).toBe("fogpup ")
	end)
end)

-- LANTERN-017 (QA r5): a paused session shows nothing until its save is claimed, then what its
-- changes added to the real save.
describe("LanternProgress.gained", function()
	local function rescue(p: Profile, ids: { string }): Profile
		for _, id in ids do
			p = (LanternProgress.load(p, { critter(id) }, true, 1, TODAY))
		end
		return p
	end

	it("shows what the changes added to the real save, never what defaults would have paid", function()
		local real = rescue(fresh(), { "mossmouse", "puddlefrog", "fogpup", "teapotcat" }) -- milestone 4 paid
		local _, onDefaults = LanternProgress.load(fresh(), { critter("mossmouse") }, true, 1, TODAY)
		expect(onDefaults.text).toBe("NEW! Moss Mouse · +10 Tickets · +75 XP") -- what r5 showed while paused
		local after = LanternProgress.count(rescue(real, { "mossmouse" }), "puffs", 3, TODAY)
		expect(LanternProgress.gained(real, after).text).toBe("+10 Tickets · +31 XP")
	end)

	it("names new species and the milestone cosmetics and Tickets they reached", function()
		local real = rescue(fresh(), { "mossmouse", "puddlefrog", "fogpup", "teapotcat", "wickmole", "burrbun" })
		local after = rescue(real, { "reedfox", "mistfawn", "mossmouse" })
		local got = LanternProgress.gained(real, after)
		expect(`{table.concat(got.new, " ")} {got.tickets}`).toBe(`reedfox mistfawn {after.coins - real.coins}`)
		expect(got.text).toBe(`NEW! Reed Fox, Mist Fawn · Mossback · +{got.tickets} Tickets · +{got.xp} XP`)
		expect(LanternProgress.gained(after, after).text).toBe("")
	end)
end)

describe("LanternProgress: quests and login tracks (nothing earned expires)", function()
	it("pays a completed, unclaimed quest of the stored day once at the next day, never twice", function()
		local quest = MetaRules.questsFor(LanternConfig.QUESTS, TODAY)[1]
		local p = fresh()
		p.quests = { day = TODAY, progress = { [quest.stat] = quest.goal }, claimed = {} }
		local same0, none = LanternProgress.dayTick(p, TODAY)
		expect(`{same0 == p} {none}`).toBe("true ")
		local paid, text = LanternProgress.dayTick(p, TODAY + 1)
		expect(`{paid.coins} {text} {paid.quests.day}`).toBe(
			`{quest.reward} {quest.reward} Tickets (saved for you) {TODAY + 1}`
		)
		local twice, again = LanternProgress.dayTick(paid, TODAY + 1)
		expect(`{twice.coins} {again}`).toBe(`{quest.reward} `)
		local claimed = table.clone(p)
		claimed.quests = { day = TODAY, progress = { [quest.stat] = quest.goal }, claimed = { [quest.id] = true } }
		expect(LanternProgress.dayTick(claimed, TODAY + 3).coins).toBe(0) -- already paid by the claim
		local behind = LanternProgress.dayTick(p, TODAY - 1)
		expect(behind == p).toBe(true) -- a clock behind changes nothing
		-- any reward function that takes `today` pays it first
		local viaLoad = LanternProgress.load(p, { { kind = "coal" } }, true, 1, TODAY + 1)
		expect(viaLoad.coins).toBe(quest.reward + 1)
	end)

	it("claims a quest through MetaRules once the goal is met", function()
		local quest = MetaRules.questsFor(LanternConfig.QUESTS, TODAY)[1]
		local p = fresh()
		p.quests = { day = TODAY, progress = { [quest.stat] = quest.goal - 1 }, claimed = {} }
		expect(select(2, LanternProgress.claimQuest(p, TODAY, quest.id))).toBe(false)
		p.quests.progress[quest.stat] = quest.goal
		local out, ok, reward = LanternProgress.claimQuest(p, TODAY, quest.id)
		expect(`{ok} {reward} {out.coins}`).toBe(`true {quest.reward} {quest.reward}`)
		expect(select(2, LanternProgress.claimQuest(out, TODAY, quest.id))).toBe(false)
	end)

	it("claims weekly slots in order (40, 60, ...), re-apply safe, nothing before its day", function()
		local p = LanternProgress.join(fresh(), MONDAY)
		expect(`{LanternProgress.claimable(p, MONDAY)} {LanternProgress.canClaimLogin(p, "week", MONDAY)}`).toBe(
			"1 true"
		)
		local out, ok, text = LanternProgress.claimLogin(p, "week", MONDAY, 1)
		expect(`{ok} {text} {out.coins}`).toBe("true 40 Tickets 40")
		local again, okAgain = LanternProgress.claimLogin(out, "week", MONDAY, 1)
		expect(`{okAgain} {again.coins}`).toBe("false 40") -- the same request twice pays once
		expect(select(2, LanternProgress.claimLogin(out, "week", MONDAY))).toBe(false) -- slot 2 needs day 2
		expect(select(2, LanternProgress.claimLogin(out, "year", MONDAY))).toBe(false)
		for day = MONDAY + 1, MONDAY + 4 do
			out = LanternProgress.join(out, day)
		end
		local slots = {}
		for _ = 2, 5 do
			local t
			out, _, t = LanternProgress.claimLogin(out, "week", MONDAY + 4)
			table.insert(slots, t)
		end
		expect(table.concat(slots, ", ")).toBe("60 Tickets, 80 Tickets, 100 Tickets, Midnight Express")
		expect(`{out.owned.midnight} {out.coins}`).toBe("true 280")
	end)

	it("pays earned, unclaimed slots at the rollover once; an owned exclusive pays its Tickets", function()
		local p = fresh()
		p.owned.midnight = true
		for day = MONDAY, MONDAY + 6 do
			p = LanternProgress.join(p, day)
		end
		local nextWeek, text = LanternProgress.join(p, MONDAY + 7)
		-- 40 + 60 + 80 + 100 + 150 (the owned livery) + 120 + 150
		expect(`{nextWeek.coins} {text}`).toBe("700 700 Tickets (saved for you)")
		local twice, again = LanternProgress.loginTick(nextWeek, MONDAY + 7)
		expect(`{twice.coins} {again} {same(twice, nextWeek)}`).toBe("700  true")
		local behind = LanternProgress.loginTick(nextWeek, MONDAY)
		expect(`{behind.coins} {behind.login.week}`).toBe(`700 {nextWeek.login.week}`)
	end)

	it(
		"puts the Ember Kit in the album at 18 monthly sign-ins, counting for milestones; once owned it pays 250",
		function()
			local p = fresh()
			for i, id in { "mossmouse", "fogpup", "reedfox" } do
				p = LanternProgress.load(p, { critter(id) }, false, 1, MONDAY - 1 + i * 0)
			end
			local first = MONDAY - 1 -- Sunday 1 November 2026
			for day = first, first + 17 do
				p = LanternProgress.join(p, day)
			end
			local month = p.login.monthClaimed
			local texts = {}
			for _ = 1, 4 do
				local t
				p, _, t = LanternProgress.claimLogin(p, "month", first + 17)
				table.insert(texts, t)
			end
			expect(`{month} {table.concat(texts, ", ")}`).toBe(
				"0 100 Tickets, 150 Tickets, 200 Tickets, Ember Kit + 200 Tickets"
			)
			expect(`{p.rescues.emberkit} {table.find(p.index, "emberkit") ~= nil} {#p.index} {p.milestones["4"]}`).toBe(
				"1 true 4 true"
			)
			-- next month (December 2026) the same slot pays its 250 Tickets instead
			local dec1 = first + 30
			for day = dec1, dec1 + 17 do
				p = LanternProgress.join(p, day)
			end
			local before = p.coins
			for _ = 1, 4 do
				p = LanternProgress.claimLogin(p, "month", dec1 + 17)
			end
			expect(`{p.coins - before} {p.rescues.emberkit}`).toBe("700 1")
		end
	)

	it("puts the month's last slot at the month's length and pays Aurora plus 400 Tickets", function()
		local feb1 = MONDAY + 91 -- 2027-02-01
		expect(select(2, LoginRules.monthOf(feb1))).toBe(28)
		local p = fresh()
		for day = feb1, feb1 + 27 do
			p = LanternProgress.join(p, day)
		end
		expect(LanternProgress.claimable(p, feb1 + 27)).toBe(14) -- 7 month slots and this week's 7
		local before = p.coins -- (week rollovers already paid February's earlier weeks)
		local last = ""
		for _ = 1, 7 do
			p, _, last = LanternProgress.claimLogin(p, "month", feb1 + 27)
		end
		expect(`{last} {p.owned.aurora} {p.coins - before}`).toBe("Aurora Beam + 400 Tickets true 1400")
	end)
end)

describe("LanternProgress: nothing earned is ever lost (GDD J)", function()
	it("never lowers Tickets, XP, the album, milestones, owned cosmetics or bests outside a purchase", function()
		local p = fresh()
		p = LanternProgress.load(p, { critter("mossmouse"), { kind = "coal" } }, true, 2, TODAY)
		p = LanternProgress.load(p, { critter("fogpup"), critter("reedfox"), critter("teapotcat") }, false, 2, TODAY)
		p = LanternProgress.award(p, "depot", 0, TODAY)
		p = LanternProgress.runEnd(p, 4, 5000, MetaRules.weekOf(TODAY), false)
		local function keeps(before: Profile, after: Profile, what: string)
			local ok = after.coins >= before.coins
				and after.xp >= before.xp
				and #after.index >= #before.index
				and after.best.critters >= before.best.critters
				and after.best.dist >= before.best.dist
			for id, n in before.rescues do
				ok = ok and (after.rescues[id] or 0) >= n
			end
			for key in before.milestones do
				ok = ok and after.milestones[key] == true
			end
			for id in before.owned do
				ok = ok and after.owned[id] == true
			end
			for key, n in before.stats do
				ok = ok and (after.stats[key] or 0) >= n
			end
			expect(`{what} {ok}`).toBe(`{what} true`)
		end
		local steps: { [string]: (Profile) -> Profile } = {
			dayTick = function(q)
				return (LanternProgress.dayTick(q, TODAY + 5))
			end,
			loginTick = function(q)
				return (LanternProgress.loginTick(q, TODAY + 40))
			end,
			join = function(q)
				return (LanternProgress.join(q, TODAY + 1))
			end,
			sanitize = function(q)
				return LanternProgress.sanitize(q, NOW + 86400 * 30)
			end,
			snapshot = function(q)
				return LanternProgress.snapshot(q, NOW + 5)
			end,
			runEndWorse = function(q)
				return (LanternProgress.runEnd(q, 0, 0, MetaRules.weekOf(TODAY) + 1, false))
			end,
			count = function(q)
				return LanternProgress.count(q, "caught", 1, TODAY)
			end,
			award = function(q)
				return (LanternProgress.award(q, "parts", 0, TODAY))
			end,
			claimQuestRefused = function(q)
				return (LanternProgress.claimQuest(q, TODAY, "nope"))
			end,
			buyRefused = function(q)
				return (LanternProgress.buy(q, "ivory"))
			end,
			equip = function(q)
				return (LanternProgress.equip(q, "warm"))
			end,
			setFollower = function(q)
				return (LanternProgress.setFollower(q, "fogpup"))
			end,
			loadEmpty = function(q)
				return (LanternProgress.load(q, {}, true, 6, TODAY))
			end,
		}
		for name, f in steps do
			keeps(p, f(p), name)
		end
		-- the only spend is a Locker purchase the player makes
		local rich = table.clone(p)
		rich.coins = 3000
		local bought, ok = LanternProgress.buy(rich, "brass")
		expect(`{ok} {bought.coins} {bought.owned.brass}`).toBe("true 500 true")
	end)

	it("never mutates the profile it is given and never touches another player's", function()
		local p = fresh()
		local copy = LanternProgress.snapshot(p, p.lastSeen)
		LanternProgress.load(p, { critter("mossmouse") }, true, 1, TODAY)
		LanternProgress.award(p, "dawn", 0, TODAY)
		LanternProgress.count(p, "puffs", 4, TODAY)
		LanternProgress.join(p, MONDAY)
		LanternProgress.runEnd(p, 3, 3000, 1, true)
		expect(same(p, copy)).toBe(true)
	end)
end)
