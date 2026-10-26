--!strict
local T = require("./framework")
local MetaRules = require("../src/shared/MetaRules")
local PlazaRules = require("../src/shared/PlazaRules")
local Rng = require("../src/shared/Rng")
local SpireConfig = require("../src/shared/SpireConfig")
local SpireEconomy = require("../src/shared/SpireEconomy")
local SpireProgress = require("../src/shared/SpireProgress")
local TowerRules = require("../src/shared/TowerRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = SpireConfig.Profile

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

local function fl(d: string, m: { number }): SpireConfig.Floor
	local s = {}
	for i = 1, 4 do
		s[i] = TowerRules.spentMax(d, m[i])
	end
	return { d = d, m = table.clone(m), s = s }
end

local function rich(): Profile
	local p = SpireProgress.defaults(NOW, 7)
	p.coins = 1e9
	p.xp = MetaRules.xpForLevel(12)
	for n = 3, 10 do
		p.floors[n] = fl(if n == 3 then "fusion" else "data", { 0, 0, 0, 0 })
	end
	return p
end

local function apply(p: Profile, action: string, arg: string?, event: string?): (Profile, boolean, string?)
	return SpireProgress.apply(p, action, arg, NOW, event or "normal")
end

-- Every field a valid profile must have, with in-range values.
local function valid(p: Profile): boolean
	if #p.floors < 2 or #p.floors > 30 or p.floors[1].d ~= "lobby" then
		return false
	end
	for n, f in p.floors do
		for slot = 1, 4 do
			local level = f.m[slot]
			if n == 1 and level ~= 0 then
				return false
			end
			if level < 0 or level > 5 or f.s[slot] < 0 or f.s[slot] > TowerRules.spentMax(f.d, level) then
				return false
			end
		end
	end
	if TowerRules.draw(p) > TowerRules.supply(p) or #p.plaza.items > 60 then
		return false
	end
	return p.coins >= 0
		and p.coins <= 1e15
		and p.shares >= 0
		and p.shares <= 500
		and table.find(SpireConfig.GATES, p.gate) ~= nil
		and SpireConfig.NAMES.prefixes[p.company.p] ~= nil
		and SpireProgress.isUnlocked(p, p.skin)
		and SpireProgress.isUnlocked(p, p.crown)
		and SpireProgress.isUnlocked(p, p.trail)
end

describe("SpireProgress", function()
	describe("profile", function()
		it("defaults: 100 credits, lobby + empty Data Farm, seeded company, slot defaults", function()
			local p = SpireProgress.defaults(NOW, 42)
			expect(p.coins).toBe(100)
			expect(#p.floors).toBe(2)
			expect(p.floors[1].d).toBe("lobby")
			expect(p.floors[2].d).toBe("data")
			expect(TowerRules.moduleCount(p, 2)).toBe(0)
			expect(p.lastSeen).toBe(NOW)
			expect(p.gate).toBe("open")
			expect(p.skin).toBe("glass")
			expect(p.trail).toBe("none")
			expect(p.bestFloors).toBe(2)
			expect(p.schemaVersion).toBe(1)
			expect(same(p.company, SpireProgress.company(42))).toBeTruthy()
			expect(valid(p)).toBeTruthy()
		end)

		it("company: 5 draws in range, deterministic per seed, varied across seeds", function()
			local names = {}
			for seed = 1, 200 do
				local c = SpireProgress.company(seed)
				expect(same(c, SpireProgress.company(seed))).toBeTruthy()
				expect(c.p >= 1 and c.p <= 24 and c.s >= 1 and c.s <= 16).toBeTruthy()
				expect(c.glyph >= 1 and c.glyph <= 12 and c.colour >= 1 and c.colour <= 8).toBeTruthy()
				expect(c.trim >= 1 and c.trim <= 8).toBeTruthy()
				names[SpireConfig.companyName(c)] = true
			end
			local distinct = 0
			for _ in names do
				distinct += 1
			end
			expect(distinct > 100).toBeTruthy()
		end)

		it("sanitize(defaults(now, s), now) == defaults(now, s)", function()
			for seed = 0, 20 do
				local d = SpireProgress.defaults(NOW, seed)
				expect(same(SpireProgress.sanitize(d, NOW), d)).toBeTruthy()
			end
			local p = rich()
			p = (apply(p, "buyModule", "2:1"))
			p = (apply(p, "placeItem", "bench:0:0:1"))
			expect(same(SpireProgress.sanitize(p, NOW), p)).toBeTruthy()
		end)

		it("sanitize: non-numbers become 0, numbers are floored and clamped", function()
			local p = SpireProgress.sanitize({
				coins = 1e20,
				xp = 5e6,
				lifetimeEarned = 1e30,
				runEarned = "lots",
				shares = 900.7,
				ipos = -4,
				hotCaught = 12.9,
				endorsements = 0 / 0,
			}, NOW)
			expect(p.coins).toBe(1e15)
			expect(p.xp).toBe(1e6)
			expect(p.lifetimeEarned).toBe(1e18)
			expect(p.runEarned).toBe(0)
			expect(p.shares).toBe(500)
			expect(p.ipos).toBe(0)
			expect(p.hotCaught).toBe(12)
			expect(p.endorsements).toBe(0)
			expect(SpireProgress.sanitize({ coins = "x" }, NOW).coins).toBe(0)
		end)

		it("sanitize: lastSeen in the future becomes now", function()
			expect(SpireProgress.sanitize({ lastSeen = NOW + 500 }, NOW).lastSeen).toBe(NOW)
			expect(SpireProgress.sanitize({ lastSeen = NOW - 500 }, NOW).lastSeen).toBe(NOW - 500)
		end)

		it("sanitize: floors 2..30, lobby always empty, missing floor 2 becomes an empty Data Farm", function()
			local p = SpireProgress.sanitize(
				{ floors = { { d = "data", m = { 5, 5, 5, 5 }, s = { 750, 750, 750, 750 } } } },
				NOW
			)
			expect(#p.floors).toBe(2)
			expect(p.floors[1].d).toBe("lobby")
			expect(p.floors[1].m[1]).toBe(0)
			expect(p.floors[2].d).toBe("data")
			local many = {}
			for n = 1, 40 do
				many[n] = { d = "data", m = { 0, 0, 0, 0 }, s = { 0, 0, 0, 0 } }
			end
			expect(#SpireProgress.sanitize({ floors = many }, NOW).floors).toBe(30)
			expect(#SpireProgress.sanitize({ floors = "x" }, NOW).floors).toBe(2)
		end)

		it("sanitize: unknown or not-allowed departments become empty Data Farms", function()
			local p = SpireProgress.sanitize({
				floors = {
					{},
					fl("data", { 1, 1, 0, 0 }),
					fl("zzz", { 0, 0, 0, 0 }),
					{ d = "synth", m = { 1, 0, 0, 0 }, s = { 8000, 0, 0, 0 } }, -- synth needs floor 8
					fl("lobby", { 0, 0, 0, 0 }),
					fl("ad", { 1, 0, 0, 0 }),
				},
			}, NOW)
			expect(#p.floors).toBe(6)
			expect(p.floors[2].m[2]).toBe(1)
			expect(p.floors[3].d).toBe("data")
			expect(p.floors[4].d).toBe("data")
			expect(p.floors[4].m[1]).toBe(0)
			expect(p.floors[5].d).toBe("data")
			expect(p.floors[6].d).toBe("ad")
		end)

		it("sanitize: slot levels 0..5, spent clamped to the undiscounted total, 0 when empty", function()
			local p = SpireProgress.sanitize({
				floors = { {}, { d = "data", m = { 9, 2.7, -1, 0 }, s = { 99999, 99999, 5, 40 } } },
			}, NOW)
			expect(p.floors[2].m[1]).toBe(5)
			expect(p.floors[2].s[1]).toBe(750)
			expect(p.floors[2].m[2]).toBe(2)
			expect(p.floors[2].s[2]).toBe(45)
			expect(p.floors[2].m[3]).toBe(0)
			expect(p.floors[2].s[3]).toBe(0)
			expect(p.floors[2].s[4]).toBe(0)
		end)

		it("sanitize: draw > supply removes the highest-draw modules, highest floor first, refunding spent", function()
			local p = SpireProgress.sanitize({
				coins = 10,
				floors = {
					{},
					fl("data", { 1, 1, 1, 1 }),
					fl("data", { 0, 0, 0, 0 }),
					fl("data", { 0, 0, 0, 0 }),
					fl("ad", { 1, 0, 0, 0 }), -- draw 2
					fl("ad", { 1, 0, 0, 0 }), -- draw 2, highest floor: removed first
				},
			}, NOW)
			expect(TowerRules.draw(p)).toBe(6)
			expect(p.floors[6].m[1]).toBe(0)
			expect(p.floors[5].m[1]).toBe(1)
			expect(p.coins).toBe(610)
		end)

		it("sanitize: plaza drops bad items in list order, keeps the rest", function()
			local items = {
				{ u = 1, id = "bench", x = 0, y = 0, r = 0, paid = 100 },
				{ u = 2, id = "nope", x = 1, y = 0, r = 0, paid = 100 },
				{ u = 3, id = "bench", x = 1, y = 0, r = 4, paid = 100 },
				{ u = 4, id = "bench", x = 12, y = 0, r = 0, paid = 100 },
				{ u = 5, id = "bench", x = 5, y = 0, r = 0, paid = 100 },
				{ u = 6, id = "bench", x = 0, y = 0, r = 0, paid = 100 }, -- overlaps u 1
				{ u = 1, id = "bench", x = 2, y = 0, r = 0, paid = 100 }, -- duplicate u
				{ u = 8, id = "idol", x = 0, y = 2, r = 0, paid = 1e12 }, -- locked by floors: kept, paid clamped
				{ u = 9, id = "maglev", x = 7, y = 0, r = 0, paid = -5 },
				{ u = 10, id = "maglev", x = 7, y = 4, r = 0, paid = 5 }, -- beyond max 1
				{ u = 11, id = "bench", x = "a", y = 0, r = 0, paid = 100 },
			}
			local p = SpireProgress.sanitize({ plaza = { nextUid = 2, items = items } }, NOW)
			local kept = {}
			for _, item in p.plaza.items do
				table.insert(kept, item.u)
			end
			expect(table.concat(kept, ",")).toBe("1,8,9")
			expect(p.plaza.items[2].paid).toBe(1_500_000_000)
			expect(p.plaza.items[3].paid).toBe(0)
			expect(p.plaza.nextUid).toBe(10)
		end)

		it("sanitize: plaza count capped at 60 and decor at 20", function()
			local items = {}
			local u = 1
			for y = 0, 7 do
				for _, x in { 0, 1, 2, 3, 4, 7, 8, 9, 10, 11 } do
					table.insert(
						items,
						{ u = u, id = if u <= 25 then "lamp" else "bench", x = x, y = y, r = 0, paid = 1 }
					)
					u += 1
				end
			end
			local p = SpireProgress.sanitize({ plaza = { items = items } }, NOW)
			local _, total, decor = PlazaRules.counts(p)
			expect(decor).toBe(20)
			expect(total).toBe(32) -- 20 lamps + the 12-bench max
			-- 61 items that each fit: the 61st is dropped by the 60-item cap
			local q = SpireProgress.defaults(NOW)
			local order =
				{ fountain = 2, arcade = 1, billboard = 2, noodle = 6, bench = 12, palm = 10, vending = 8, lamp = 20 }
			for _, id in { "fountain", "arcade", "billboard", "noodle", "bench", "palm", "vending", "lamp" } do
				for _ = 1, order[id] do
					local placed = false
					for y = 0, 7 do
						for x = 0, 11 do
							for r = 0, 1 do
								if not placed and PlazaRules.check(q, id, x, y, r) == nil then
									table.insert(
										q.plaza.items,
										{ u = #q.plaza.items + 1, id = id, x = x, y = y, r = r, paid = 1 }
									)
									placed = true
								end
							end
						end
					end
					expect(placed).toBe(true)
				end
			end
			expect(#q.plaza.items).toBe(61)
			local capped = SpireProgress.sanitize(q, NOW)
			expect(#capped.plaza.items).toBe(60)
			expect(capped.plaza.items[60].u).toBe(60)
		end)

		it("sanitize: company out of range takes the seeded default; seed names only invalid records", function()
			local good = { p = 3, s = 4, glyph = 5, colour = 6, trim = 7 }
			expect(same(SpireProgress.sanitize({ company = good }, NOW, 99).company, good)).toBeTruthy()
			local bad = { p = 25, s = 4, glyph = 5, colour = 6, trim = 7 }
			expect(same(SpireProgress.sanitize({ company = bad }, NOW, 99).company, SpireProgress.company(99))).toBeTruthy()
			expect(same(SpireProgress.sanitize({ company = { p = 1.5 } }, NOW).company, SpireProgress.company(0))).toBeTruthy()
		end)

		it("sanitize: unknown or locked cosmetics fall back to slot defaults", function()
			local p = SpireProgress.sanitize({
				xp = MetaRules.xpForLevel(5),
				skin = "chrome", -- needs 1 Share
				crown = "halo", -- level 5: kept
				lobby = "goldLobby", -- priced, not owned
				tiles = "nope",
				trail = "cyanTrail", -- level 2: kept
			}, NOW)
			expect(p.skin).toBe("glass")
			expect(p.crown).toBe("halo")
			expect(p.lobby).toBe("marble")
			expect(p.tiles).toBe("grid")
			expect(p.trail).toBe("cyanTrail")
			local q = SpireProgress.sanitize(
				{ shares = 10, skin = "carbon", crown = "satellite", owned = { goldLobby = true }, lobby = "goldLobby" },
				NOW
			)
			expect(q.skin).toBe("carbon")
			expect(q.crown).toBe("satellite")
			expect(q.lobby).toBe("goldLobby")
		end)

		it("sanitize: gate, endorsed ids, bestFloors and the lock", function()
			local ids = { 1, 2.5, "x", 3 }
			for i = 10, 50 do
				table.insert(ids, i)
			end
			local p: any = SpireProgress.sanitize({
				gate = "party",
				endorsed = { day = DAY, ids = ids },
				bestFloors = 99,
				lock = { session = "a", at = NOW },
			}, NOW)
			expect(p.gate).toBe("open")
			expect(#p.endorsed.ids).toBe(30)
			expect(p.endorsed.ids[2]).toBe(3)
			expect(p.endorsed.day).toBe(DAY)
			expect(p.bestFloors).toBe(30)
			expect(p.lock).toBeNil()
			expect(SpireProgress.sanitize({ gate = "friends" }, NOW).gate).toBe("friends")
		end)

		it("property: sanitize never errors on junk and always returns a valid profile", function()
			local state = Rng.seed(2026, 10, 26)
			local function junk(depth: number): any
				local k
				k, state = Rng.int(state, 1, 10)
				if k == 1 then
					return nil
				elseif k == 2 then
					local v
					v, state = Rng.next(state)
					return (v - 0.3) * 10 ^ (math.floor(v * 40) - 10)
				elseif k == 3 then
					return 0 / 0
				elseif k == 4 then
					return math.huge
				elseif k == 5 then
					local pool = { "data", "fusion", "ad", "lobby", "bench", "idol", "open", "chrome", "", "x" }
					local i
					i, state = Rng.int(state, 1, #pool)
					return pool[i]
				elseif k == 6 then
					return true
				end
				if depth <= 0 then
					local v
					v, state = Rng.int(state, -3, 40)
					return v
				end
				local t = {}
				local n
				n, state = Rng.int(state, 0, 8)
				for i = 1, n do
					t[i] = junk(depth - 1)
				end
				for _, key in
					{ "d", "m", "s", "u", "id", "x", "y", "r", "paid", "items", "nextUid", "ids", "day", "p", "glyph" }
				do
					local roll
					roll, state = Rng.int(state, 1, 3)
					if roll == 1 then
						t[key] = junk(depth - 1)
					end
				end
				return t
			end
			local fields = {
				"coins",
				"xp",
				"lastSeen",
				"floors",
				"plaza",
				"shares",
				"company",
				"skin",
				"crown",
				"gate",
				"endorsed",
				"owned",
				"daily",
				"week",
				"quests",
				"lock",
			}
			for _ = 1, 1000 do
				local record = {}
				for _, f in fields do
					record[f] = junk(3)
				end
				local ok, p = pcall(SpireProgress.sanitize, record, NOW, 5)
				expect(ok).toBeTruthy()
				expect(valid(p)).toBeTruthy()
				expect(same(SpireProgress.sanitize(p, NOW), p)).toBeTruthy()
			end
			for _, value in { nil, 1, "x", true, {}, { floors = {} } } do
				expect(valid(SpireProgress.sanitize(value, NOW))).toBeTruthy()
			end
		end)

		it("publicState: no paid, no credits; hype and level included", function()
			local p = rich()
			p = (apply(p, "placeItem", "bench:0:0:0"))
			local s: any = SpireProgress.publicState(p)
			expect(s.items[1].paid).toBeNil()
			expect(s.items[1].id).toBe("bench")
			expect(s.coins).toBeNil()
			expect(s.floors[2].s).toBeNil()
			expect(s.hype).toBe(1)
			expect(s.level).toBe(12)
			expect(s.company.p).toBe(p.company.p)
		end)

		it("isUnlocked adds the Shares gate to MetaRules", function()
			local p = SpireProgress.defaults(NOW)
			expect(SpireProgress.isUnlocked(p, "chrome")).toBe(false)
			p.shares = 1
			expect(SpireProgress.isUnlocked(p, "chrome")).toBe(true)
			expect(SpireProgress.isUnlocked(p, "carbon")).toBe(false)
			expect(SpireProgress.isUnlocked(p, "glass")).toBe(true)
			expect(SpireProgress.isUnlocked(p, "holoLogo")).toBe(false)
		end)

		it("levelFor and questsFor reuse MetaRules", function()
			expect(SpireProgress.levelFor(0)).toBe(1)
			expect(SpireProgress.levelFor(40)).toBe(2)
			expect(#SpireProgress.questsFor(DAY)).toBe(3)
		end)
	end)

	describe("session lock", function()
		it("claim, hold and stale after 120 s", function()
			local p = SpireProgress.defaults(NOW)
			local stored = SpireProgress.locked(p, "a", NOW)
			expect(stored.lock.session).toBe("a")
			expect(SpireProgress.canClaim(nil, "b", NOW)).toBe(true)
			expect(SpireProgress.canClaim(p, "b", NOW)).toBe(true)
			expect(SpireProgress.canClaim(stored, "a", NOW)).toBe(true)
			expect(SpireProgress.canClaim(stored, "b", NOW + 119)).toBe(false)
			expect(SpireProgress.canClaim(stored, "b", NOW + 120)).toBe(true)
			expect(SpireProgress.holds(stored, "a")).toBe(true)
			expect(SpireProgress.holds(stored, "b")).toBe(false)
			expect(SpireProgress.holds(SpireProgress.locked(p, nil, NOW), "a")).toBe(false)
			expect((SpireProgress.sanitize(stored, NOW) :: any).lock).toBeNil()
		end)
	end)

	describe("server ops", function()
		it("login pays offline income at half rate and records the day", function()
			local p = SpireProgress.defaults(NOW - 3600)
			p.floors[2] = fl("data", { 1, 1, 1, 1 })
			local out, offline = SpireProgress.login(p, NOW)
			expect(offline).toBe(7_200)
			expect(out.coins).toBe(7_300)
			expect(out.lifetimeEarned).toBe(7_200)
			expect(out.lastSeen).toBe(NOW)
			expect(out.week.days).toBe(1)
			expect(out.quests.day).toBe(DAY)
		end)

		it("login, snapshot, login after 0 s pays 0 offline", function()
			local p = SpireProgress.defaults(NOW - 100)
			p.floors[2] = fl("data", { 1, 1, 1, 1 })
			local a = SpireProgress.login(p, NOW)
			local b = SpireProgress.snapshot(a, NOW)
			local _, offline = SpireProgress.login(b, NOW)
			expect(offline).toBe(0)
		end)

		it("snapshot sets only lastSeen", function()
			local p = SpireProgress.defaults(NOW - 50)
			local out = SpireProgress.snapshot(p, NOW)
			expect(out.lastSeen).toBe(NOW)
			expect(p.lastSeen).toBe(NOW - 50)
			out.lastSeen = p.lastSeen
			expect(same(out, p)).toBeTruthy()
		end)

		it("earn adds to coins and both earned totals with caps, and counts earnSeconds", function()
			local p = SpireProgress.defaults(NOW)
			local out = SpireProgress.earn(p, 50.9, 1, DAY)
			expect(out.coins).toBe(150)
			expect(out.lifetimeEarned).toBe(50)
			expect(out.runEarned).toBe(50)
			expect(out.quests.progress.earnSeconds).toBe(1)
			out.coins = 1e15 - 1
			out.lifetimeEarned = 1e18
			out = SpireProgress.earn(out, 10, 0, DAY)
			expect(out.coins).toBe(1e15)
			expect(out.lifetimeEarned).toBe(1e18)
			expect(out.quests.progress.earnSeconds).toBe(1)
		end)

		it("grabHot: pays, counts, 5 XP, hot +1 and earnSeconds +30", function()
			local p = SpireProgress.defaults(NOW)
			local out = SpireProgress.grabHot(p, 1_053, DAY)
			expect(out.coins).toBe(1_153)
			expect(out.hotCaught).toBe(1)
			expect(out.xp).toBe(5)
			expect(out.quests.progress.hot).toBe(1)
			expect(out.quests.progress.earnSeconds).toBe(30)
		end)

		it("receiveEndorse and gateAllows", function()
			expect(SpireProgress.receiveEndorse(SpireProgress.defaults(NOW)).endorsements).toBe(1)
			expect(SpireProgress.gateAllows("open", false)).toBe(true)
			expect(SpireProgress.gateAllows("friends", false)).toBe(false)
			expect(SpireProgress.gateAllows("friends", true)).toBe(true)
			expect(SpireProgress.gateAllows("closed", true)).toBe(false)
		end)

		it("scaled rewards: max(base, floor(income x 60 x minutes))", function()
			local p = SpireProgress.defaults(NOW)
			expect(SpireProgress.scaled(p, 300, 5)).toBe(300)
			p.floors[2] = fl("data", { 5, 5, 5, 5 }) -- 64 ¢/s
			expect(SpireProgress.scaled(p, 300, 5)).toBe(19_200)
		end)
	end)

	describe("Request contract", function()
		it("check: unknown action, args to no-arg actions, missing args and pattern misses", function()
			expect(SpireProgress.check("nope", nil)).toBe("action")
			expect(SpireProgress.check(5 :: any, nil)).toBe("action")
			expect(SpireProgress.check("home", nil)).toBeNil()
			expect(SpireProgress.check("home", "x")).toBe("arg")
			expect(SpireProgress.check("buyFloor", nil)).toBe("arg")
			expect(SpireProgress.check("buyFloor", "Data")).toBe("arg")
			expect(SpireProgress.check("buyFloor", "data")).toBeNil()
			expect(SpireProgress.check("lift", "roof")).toBeNil()
		end)

		it("parse rejects 3:5, x:1, 1:1:1 for buyModule and any 41-character arg", function()
			for _, arg in { "3:5", "x:1", "1:1:1", "3:0", ":1", "3:1 " } do
				expect(SpireProgress.parse("buyModule", arg)).toBeNil()
			end
			expect(SpireProgress.parse("sellItem", string.rep("1", 41))).toBeNil()
			expect(SpireProgress.parse("sellItem", string.rep("1", 40))).toBeTruthy()
			expect(SpireProgress.parse("claimQuest", string.rep("a", 41))).toBeNil()
			local a = SpireProgress.parse("buyModule", "12:3") :: { any }
			expect(a[1]).toBe(12)
			expect(a[2]).toBe(3)
			local b = SpireProgress.parse("placeItem", "idol:7:5:3") :: { any }
			expect(b[1]).toBe("idol")
			expect(b[4]).toBe(3)
			expect(#(SpireProgress.parse("claimDaily", nil) :: { any })).toBe(0)
		end)

		it("apply refuses lift and home, bad args, and returns the input unchanged on refusal", function()
			local p = rich()
			for _, case in
				{
					{ "lift", "1", "action" },
					{ "home", nil, "action" },
					{ "nope", nil, "action" },
					{ "buyModule", "1:9", "arg" },
				}
			do
				local out, ok, code = apply(p, case[1] :: string, case[2] :: string?)
				expect(ok).toBe(false)
				expect(code).toBe(case[3])
				expect(out).toBe(p)
			end
			local out, ok, code = apply(p, "buyModule", "11:1")
			expect(ok).toBe(false)
			expect(code).toBe("floor")
			expect(out).toBe(p)
		end)

		it("buyFloor: 10 x tier XP, floors stat and bestFloors", function()
			local p = rich()
			local out, ok = apply(p, "buyFloor", "synth")
			expect(ok).toBe(true)
			expect(#out.floors).toBe(11)
			expect(out.xp - p.xp).toBe(30)
			expect(out.quests.progress.floors).toBe(1)
			expect(out.bestFloors).toBe(11)
			expect(out.coins).toBe(p.coins - 58_900)
		end)

		it("buyModule 2 XP; upgrade 2 x new level XP; maxed on level 5", function()
			local p = rich()
			local out = apply(p, "buyModule", "2:1", "sale")
			expect(out.xp - p.xp).toBe(2)
			expect(out.floors[2].s[1]).toBe(11)
			expect(out.quests.progress.modules).toBe(1)
			for level = 2, 5 do
				local before = out
				out = apply(out, "upgradeModule", "2:1")
				expect(out.xp - before.xp).toBe(2 * level)
			end
			expect(out.quests.progress.upgrades).toBe(4)
			expect(out.quests.progress.maxed).toBe(1)
			local sold, ok = apply(out, "sellModule", "2:1")
			expect(ok).toBe(true)
			expect(sold.coins - out.coins).toBe(math.floor((11 + 30 + 75 + 180 + 450) / 2))
			expect(sold.xp).toBe(out.xp)
		end)

		it("placeItem: 5 XP for hype items only, placed stat; move and sell", function()
			local p = rich()
			local a = apply(p, "placeItem", "bench:0:0:0")
			expect(a.xp - p.xp).toBe(5)
			expect(a.quests.progress.placed).toBe(1)
			local b = apply(a, "placeItem", "lamp:1:0:0")
			expect(b.xp).toBe(a.xp)
			expect(b.quests.progress.placed).toBe(2)
			local c, ok = apply(b, "moveItem", "1:7:7:2")
			expect(ok).toBe(true)
			expect(c.plaza.items[1].x).toBe(7)
			local d, ok2 = apply(c, "sellItem", "2")
			expect(ok2).toBe(true)
			expect(d.coins - c.coins).toBe(75)
			expect(select(3, apply(d, "placeItem", "bench:5:0:0"))).toBe("walkway")
		end)

		it("refitFloor through apply", function()
			local p = rich()
			local out, ok = apply(p, "refitFloor", "4:fusion")
			expect(ok).toBe(true)
			expect(out.floors[4].d).toBe("fusion")
			expect(out.xp).toBe(p.xp)
		end)

		it("endorse: once per target per day, 30 a day, 3 XP for the first 10", function()
			local p = rich()
			local out, ok = apply(p, "endorse", "123")
			expect(ok).toBe(true)
			expect(out.xp - p.xp).toBe(3)
			expect(out.quests.progress.endorse).toBe(1)
			expect(select(3, apply(out, "endorse", "123"))).toBe("done")
			for id = 1, 29 do
				out = apply(out, "endorse", tostring(1000 + id))
			end
			expect(#out.endorsed.ids).toBe(30)
			expect(out.xp - p.xp).toBe(30)
			expect(select(3, apply(out, "endorse", "5"))).toBe("max")
			-- a new day starts a new list
			local tomorrow = SpireProgress.apply(out, "endorse", "123", NOW + 86400, "normal")
			expect(#tomorrow.endorsed.ids).toBe(1)
		end)

		it("setGate and setCompany", function()
			local p = rich()
			expect(select(3, apply(p, "setGate", "open"))).toBe("same")
			expect(select(3, apply(p, "setGate", "party"))).toBe("unknown")
			expect((apply(p, "setGate", "closed")).gate).toBe("closed")
			local c = p.company
			local same5 = `{c.p}:{c.s}:{c.glyph}:{c.colour}:{c.trim}`
			expect(select(3, apply(p, "setCompany", same5))).toBe("same")
			expect(select(3, apply(p, "setCompany", "25:1:1:1:1"))).toBe("unknown")
			expect(select(3, apply(p, "setCompany", "1:1:1:1:9"))).toBe("unknown")
			expect(select(3, apply(p, "setCompany", "0:1:1:1:1"))).toBe("unknown")
			local out = apply(p, "setCompany", "24:16:12:8:8")
			expect(SpireConfig.companyName(out.company)).toBe("Zero Interactive")
		end)

		it("claims: daily, weekly, quests; refused as claimed", function()
			local p = rich()
			local out, ok = apply(p, "claimDaily", nil)
			expect(ok).toBe(true)
			expect(out.coins - p.coins).toBe(100)
			expect(select(3, apply(out, "claimDaily", nil))).toBe("claimed")
			expect(select(3, apply(p, "claimWeekly", nil))).toBe("claimed")
			expect(select(3, apply(p, "claimQuest", "nope"))).toBe("claimed")
			local quest = SpireProgress.questsFor(DAY)[1]
			local done = MetaRules.addProgress(SpireProgress.CONFIG, p, DAY, { [quest.stat] = quest.goal })
			local claimed, ok2 = apply(done, "claimQuest", quest.id)
			expect(ok2).toBe(true)
			expect(claimed.coins > done.coins).toBeTruthy()
		end)

		it("cosmetics: buy and equip refusals in order", function()
			local p = rich()
			expect(select(3, apply(p, "buyCosmetic", "nope"))).toBe("unknown")
			expect(select(3, apply(p, "buyCosmetic", "halo"))).toBe("locked") -- not priced
			expect(select(3, apply(p, "buyCosmetic", "chrome"))).toBe("locked")
			local poor = rich()
			poor.coins = 10
			expect(select(3, apply(poor, "buyCosmetic", "holoLogo"))).toBe("credits")
			local bought, ok = apply(p, "buyCosmetic", "holoLogo")
			expect(ok).toBe(true)
			expect(p.coins - bought.coins).toBe(2_000_000)
			expect(select(3, apply(bought, "buyCosmetic", "holoLogo"))).toBe("owned")
			local worn = apply(bought, "equipCosmetic", "holoLogo")
			expect(worn.crown).toBe("holoLogo")
			expect(select(3, apply(worn, "equipCosmetic", "holoLogo"))).toBe("same")
			expect(select(3, apply(p, "equipCosmetic", "chrome"))).toBe("locked")
			expect(select(3, apply(p, "equipCosmetic", "circuit"))).toBe("locked") -- level 15
			expect(select(3, apply(p, "equipCosmetic", "nope"))).toBe("unknown")
			expect((apply(p, "equipCosmetic", "needle")).crown).toBe("needle")
		end)

		it("ipo: locked until the feature flag, then floors 20 and 1 Share needed", function()
			local p = rich()
			expect(select(3, apply(p, "ipo", nil))).toBe("locked")
			SpireConfig.FEATURES.ipo = true
			local ok1, err = pcall(function()
				expect(select(3, apply(p, "ipo", nil))).toBe("ipo")
				for n = 11, 20 do
					p.floors[n] = fl("data", { 1, 1, 1, 1 })
				end
				expect(select(3, apply(p, "ipo", nil))).toBe("ipo") -- runEarned 0
				p.runEarned = 1.13e9
				p.shares = 495
				p = (apply(p, "placeItem", "bench:0:0:0"))
				local out, ok = apply(p, "ipo", nil)
				expect(ok).toBe(true)
				expect(out.shares).toBe(500)
				expect(out.ipos).toBe(1)
				expect(out.coins).toBe(100)
				expect(#out.floors).toBe(2)
				expect(out.runEarned).toBe(0)
				expect(out.xp).toBe(p.xp)
				expect(#out.plaza.items).toBe(1)
				expect(out.bestFloors).toBe(p.bestFloors)
			end)
			SpireConfig.FEATURES.ipo = false
			expect(ok1).toBe(true)
			if not ok1 then
				error(err)
			end
		end)

		it("apply is deterministic: twice on copies of one profile gives equal results", function()
			local base = rich()
			base = (apply(base, "buyModule", "2:1"))
			base = (apply(base, "placeItem", "palm:0:0:0"))
			local cases = {
				{ "buyFloor", "data" },
				{ "buyModule", "4:2" },
				{ "upgradeModule", "2:1" },
				{ "sellModule", "2:1" },
				{ "placeItem", "bench:8:3:1" },
				{ "moveItem", "1:9:6:2" },
				{ "sellItem", "1" },
				{ "endorse", "77" },
				{ "setGate", "friends" },
				{ "setCompany", "1:2:3:4:5" },
				{ "claimDaily", nil },
				{ "buyCosmetic", "chromeTiles" },
				{ "equipCosmetic", "halo" },
			}
			for _, case in cases do
				for _, event in { "normal", "sale", "boom" } do
					local a, okA, codeA = apply(TowerRules.copy(base), case[1] :: string, case[2] :: string?, event)
					local b, okB, codeB = apply(TowerRules.copy(base), case[1] :: string, case[2] :: string?, event)
					expect(okA).toBe(true)
					expect(okA == okB and codeA == codeB and same(a, b)).toBeTruthy()
					expect(valid(a)).toBeTruthy()
				end
			end
		end)
	end)

	describe("token bucket", function()
		it("starts full at 6, refills 4 per second, refusals take nothing", function()
			local b: SpireProgress.Bucket = { tokens = 6, at = 0 }
			local ok
			for _ = 1, 6 do
				b, ok = SpireProgress.take(b, 0)
				expect(ok).toBe(true)
			end
			b, ok = SpireProgress.take(b, 0)
			expect(ok).toBe(false)
			expect(b.tokens).toBe(0)
			b, ok = SpireProgress.take(b, 0.25)
			expect(ok).toBe(true)
			b, ok = SpireProgress.take(b, 100)
			expect(b.tokens).toBe(5)
			b = SpireProgress.take(b, 99) -- clock going back refills nothing
			expect(b.tokens).toBe(4)
		end)

		it("never accepts more than 6 + 4t over t seconds", function()
			local state = Rng.seed(4, 4)
			for _ = 1, 50 do
				local b: SpireProgress.Bucket = { tokens = 6, at = 0 }
				local clock, accepted = 0, 0
				for _ = 1, 500 do
					local v
					v, state = Rng.next(state)
					clock += v * 0.2
					local ok
					b, ok = SpireProgress.take(b, clock)
					if ok then
						accepted += 1
					end
					expect(accepted <= 6 + 4 * clock + 1e-9).toBeTruthy()
				end
			end
		end)
	end)

	it("worth helper agrees with the E4 offline payout path", function()
		local p = SpireProgress.defaults(NOW - 10)
		p.floors[2] = fl("data", { 2, 0, 0, 0 })
		expect(SpireEconomy.offline(p, NOW)).toBe(10)
	end)
end)
