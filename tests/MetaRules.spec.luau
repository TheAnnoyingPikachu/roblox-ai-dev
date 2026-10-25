--!strict
local T = require("./framework")
local MetaRules = require("../src/shared/MetaRules")

local describe, it, expect = T.describe, T.it, T.expect
local DAY = 20_000

-- A two-slot test game, so the generic rules are checked apart from Relay and Night.
type Profile = {
	xp: number,
	coins: number,
	wins: number,
	bestTier: number?,
	hat: string,
	cape: string,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}

local function defaults(): Profile
	return {
		xp = 0,
		coins = 0,
		wins = 0,
		bestTier = 0,
		hat = "cap",
		cape = "plain",
		owned = {},
		daily = { streak = 0, last = -1 },
		week = { key = -1, days = 0, lastDay = -1, claimed = false },
		quests = { day = -1, progress = {}, claimed = {} },
	}
end

local CONFIG: MetaRules.Config<Profile>
CONFIG = {
	cosmetics = {
		{ id = "cap", name = "Cap", slot = "hat", colours = {} },
		{ id = "crown", name = "Crown", slot = "hat", colours = {}, tier = 3 },
		{ id = "tophat", name = "Top Hat", slot = "hat", colours = {}, price = 100 },
		{ id = "plain", name = "Plain", slot = "cape", colours = {} },
		{ id = "red", name = "Red", slot = "cape", colours = {}, level = 3 },
		{ id = "champ", name = "Champ", slot = "cape", colours = {}, wins = 2 },
	},
	slots = { hat = "cap", cape = "plain" },
	quests = {
		{ id = "a", label = "A", stat = "hits", goal = 2, reward = 10 },
		{ id = "b", label = "B", stat = "hits", goal = 5, reward = 20 },
		{ id = "c", label = "C", stat = "jumps", goal = 1, reward = 30 },
	},
	daily = { 5, 10 },
	weekly = { days = 2, reward = 99 },
	sanitize = function(record: any): Profile
		local p = defaults()
		if type(record) == "table" then
			p.bestTier = MetaRules.count(record.bestTier, 5)
		end
		return MetaRules.sanitizeMeta(CONFIG, record, p)
	end,
}

describe("MetaRules.questsFor", function()
	it("gives 3 distinct quests for pool sizes 3-12 over 400 days", function()
		for size = 3, 12 do
			local pool = {}
			for i = 1, size do
				table.insert(pool, { id = `q{i}`, label = "", stat = "x", goal = 1, reward = 1 })
			end
			for d = DAY, DAY + 399 do
				local qs = MetaRules.questsFor(pool, d)
				expect(#qs).toBe(3)
				expect(qs[1] ~= nil and qs[2] ~= nil and qs[3] ~= nil).toBe(true)
				expect(qs[1].id ~= qs[2].id and qs[2].id ~= qs[3].id and qs[1].id ~= qs[3].id).toBe(true)
				expect(MetaRules.questsFor(pool, d)[3].id).toBe(qs[3].id)
			end
		end
	end)
end)

describe("MetaRules cosmetics by slot", function()
	it("unlocks by level, wins, tier and purchase", function()
		local p = defaults()
		expect(MetaRules.isUnlocked(CONFIG, p, "cap")).toBe(true)
		expect(MetaRules.isUnlocked(CONFIG, p, "red")).toBe(false)
		expect(MetaRules.isUnlocked(CONFIG, p, "crown")).toBe(false)
		expect(MetaRules.isUnlocked(CONFIG, p, "missing")).toBe(false)
		p.xp = MetaRules.xpForLevel(3)
		p.wins = 2
		p.bestTier = 3
		expect(MetaRules.isUnlocked(CONFIG, p, "red")).toBe(true)
		expect(MetaRules.isUnlocked(CONFIG, p, "champ")).toBe(true)
		expect(MetaRules.isUnlocked(CONFIG, p, "crown")).toBe(true)
		p.bestTier = nil
		expect(MetaRules.isUnlocked(CONFIG, p, "crown")).toBe(false) -- no bestTier counts as 0
	end)

	it("equips into the cosmetic's own slot only", function()
		local p = defaults()
		p.xp = MetaRules.xpForLevel(3)
		local red, ok = MetaRules.equip(CONFIG, p, "red")
		expect(ok).toBe(true)
		expect(red.cape).toBe("red")
		expect(red.hat).toBe("cap")
		expect(p.cape).toBe("plain")
		local _, locked = MetaRules.equip(CONFIG, red, "crown")
		expect(locked).toBe(false)
	end)

	it("buys once with enough coins, then equips", function()
		local p = defaults()
		local _, poor = MetaRules.buy(CONFIG, p, "tophat")
		expect(poor).toBe(false)
		p.coins = 150
		local bought, ok = MetaRules.buy(CONFIG, p, "tophat")
		expect(ok).toBe(true)
		expect(bought.coins).toBe(50)
		local _, twice = MetaRules.buy(CONFIG, bought, "tophat")
		expect(twice).toBe(false)
		local _, free = MetaRules.buy(CONFIG, p, "cap")
		expect(free).toBe(false)
		expect((MetaRules.equip(CONFIG, bought, "tophat")).hat).toBe("tophat")
	end)
end)

describe("MetaRules.sanitizeMeta", function()
	it("falls back per slot for unknown, wrong-slot or locked ids", function()
		local p = CONFIG.sanitize({ hat = "red", cape = "champ", xp = MetaRules.xpForLevel(3) })
		expect(p.hat).toBe("cap") -- red is a cape
		expect(p.cape).toBe("plain") -- champ is locked
		expect(CONFIG.sanitize({ hat = "crown", bestTier = 3 }).hat).toBe("crown")
		expect(CONFIG.sanitize({ hat = 5 }).hat).toBe("cap")
	end)

	it("clamps numbers and keeps only priced owned ids", function()
		local p = CONFIG.sanitize({
			xp = -5,
			coins = 0 / 0,
			wins = 2.9,
			owned = { tophat = true, cap = true, nope = true },
			daily = { streak = 3, last = math.huge },
		})
		expect(p.xp).toBe(0)
		expect(p.coins).toBe(0)
		expect(p.wins).toBe(2)
		expect(p.owned.tophat).toBe(true)
		expect(p.owned.cap).toBeNil()
		expect(p.owned.nope).toBeNil()
		expect(p.daily.last).toBe(-1)
		expect(MetaRules.count("7", 10)).toBe(0)
		expect(MetaRules.dayNumber(-30)).toBe(-1)
	end)
end)

describe("MetaRules rewards with a game config", function()
	it("uses the config's daily, weekly and quest amounts", function()
		local p, ok, reward = MetaRules.claimDaily(CONFIG, defaults(), DAY)
		expect(ok).toBe(true)
		expect(reward).toBe(5)
		local _, _, r2 = MetaRules.claimDaily(CONFIG, p, DAY + 1)
		expect(r2).toBe(10)
		expect(MetaRules.dailyReward(CONFIG, 9)).toBe(10)
		local monday = 7 * 3000 - 3
		local w = MetaRules.login(CONFIG, defaults(), monday)
		expect(MetaRules.canClaimWeekly(CONFIG, w, monday)).toBe(false)
		w = MetaRules.login(CONFIG, w, monday + 1)
		local _, wok, wr = MetaRules.claimWeekly(CONFIG, w, monday + 1)
		expect(wok).toBe(true)
		expect(wr).toBe(99)
	end)

	it("adds quest progress, resetting it on a new day", function()
		local p = MetaRules.addProgress(CONFIG, defaults(), DAY, { hits = 2, jumps = 1 })
		expect(p.quests.day).toBe(DAY)
		p = MetaRules.addProgress(CONFIG, p, DAY, { hits = 3 })
		expect(p.quests.progress.hits).toBe(5)
		local _, ok, reward = MetaRules.claimQuest(CONFIG, p, DAY, "b")
		expect(ok).toBe(true)
		expect(reward).toBe(20)
		local fresh = MetaRules.addProgress(CONFIG, p, DAY + 1, { hits = 1 })
		expect(fresh.quests.progress.hits).toBe(1)
		expect(fresh.quests.progress.jumps).toBeNil()
	end)

	it("shares the level curve and day maths", function()
		expect(MetaRules.levelFor(0)).toBe(1)
		expect(MetaRules.levelFor(40)).toBe(2)
		expect(MetaRules.levelFor(10 ^ 9)).toBe(50)
		expect(MetaRules.dayOf(86400 * 3 + 5)).toBe(3)
		expect(MetaRules.weekOf(4)).toBe(1) -- 5 Jan 1970 was a Monday
		expect(MetaRules.weekOf(3)).toBe(0)
	end)
end)
