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

local function fl(d: string, m: { number }): SpireConfig.Floor
	local s = {}
	for i = 1, 4 do
		s[i] = TowerRules.spentMax(d, m[i])
	end
	return { d = d, m = table.clone(m), s = s }
end

local function addItems(p: Profile, id: string, n: number)
	for _ = 1, n do
		table.insert(p.plaza.items, { u = p.plaza.nextUid, id = id, x = 0, y = 0, r = 0, paid = 0 })
		p.plaza.nextUid += 1
	end
end

-- GDD E1 check tower: 27 ¢/s before Hype, 30 Hype, 0 Shares.
local function checkTower(): Profile
	local p = SpireProgress.defaults(NOW, 1)
	p.floors[2] = fl("data", { 2, 2, 2, 2 })
	p.floors[3] = fl("fusion", { 1, 0, 0, 0 })
	p.floors[4] = fl("ad", { 1, 1, 0, 0 })
	p.floors[5] = fl("data", { 1, 1, 1, 1 })
	p.floors[6] = fl("data", { 1, 1, 0, 0 })
	addItems(p, "bench", 12)
	addItems(p, "palm", 9)
	return p
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

describe("SpireEconomy", function()
	it("C4 checks: a L5 Server Rack earns 16 ¢/s, a L3 Bio-Printer 160 ¢/s", function()
		expect(SpireEconomy.moduleIncome("data", 5, "normal")).toBe(16)
		expect(SpireEconomy.moduleIncome("synth", 3, "normal")).toBe(160)
		expect(SpireEconomy.moduleIncome("fusion", 3, "normal")).toBe(0)
		expect(SpireEconomy.moduleIncome("data", 0, "normal")).toBe(0)
	end)

	it("Data Boom doubles data and quantum only", function()
		expect(SpireEconomy.moduleIncome("data", 2, "boom")).toBe(4)
		expect(SpireEconomy.moduleIncome("quantum", 1, "boom")).toBe(3_200)
		expect(SpireEconomy.moduleIncome("synth", 1, "boom")).toBe(40)
		expect(SpireEconomy.moduleIncome("data", 2, "neon")).toBe(2)
	end)

	it("C6 check: 4 racks L3 between two active ad floors earn 24 ¢/s before Hype", function()
		local p = SpireProgress.defaults(NOW, 1)
		p.floors[2] = fl("ad", { 1, 0, 0, 0 })
		p.floors[3] = fl("data", { 3, 3, 3, 3 })
		p.floors[4] = fl("ad", { 1, 0, 0, 0 })
		expect(SpireEconomy.floorIncome(p, 3, "normal")).toBe(24)
		expect(SpireEconomy.floorIncome(p, 2, "normal")).toBe(6) -- ad floors get no boost
	end)

	it("E1 check: the six-floor tower earns 35.1 ¢/s", function()
		local p = checkTower()
		expect(PlazaRules.hype(p)).toBe(30)
		expect(SpireEconomy.floorIncome(p, 2, "normal")).toBe(8)
		expect(SpireEconomy.floorIncome(p, 3, "normal")).toBe(0)
		expect(SpireEconomy.floorIncome(p, 4, "normal")).toBe(12)
		expect(SpireEconomy.floorIncome(p, 5, "normal")).toBe(5)
		expect(SpireEconomy.floorIncome(p, 6, "normal")).toBe(2)
		expect(near(SpireEconomy.income(p, "normal"), 35.1)).toBeTruthy()
		-- Neon Night: floor 5 gets +50%
		expect(near(SpireEconomy.income(p, "neon"), (8 + 12 + 6 + 2) * 1.3)).toBeTruthy()
		-- Data Boom doubles every data floor
		expect(near(SpireEconomy.income(p, "boom"), (16 + 12 + 10 + 4) * 1.3)).toBeTruthy()
	end)

	it("Shares multiply income by 1 + 0.10 x shares", function()
		local p = checkTower()
		p.shares = 10
		expect(SpireEconomy.shareMult(p)).toBe(2)
		expect(near(SpireEconomy.income(p, "normal"), 70.2)).toBeTruthy()
	end)

	it("E4 check: 35.1 ¢/s away 1 h pays 63,180; away 12 h pays 505,440 (8 h cap)", function()
		local p = checkTower()
		p.lastSeen = NOW - 3600
		expect(SpireEconomy.offline(p, NOW)).toBe(63_180)
		p.lastSeen = NOW - 12 * 3600
		expect(SpireEconomy.offline(p, NOW)).toBe(505_440)
		p.lastSeen = NOW + 50
		expect(SpireEconomy.offline(p, NOW)).toBe(0)
	end)

	it("offline ignores the current event (uses normal income)", function()
		local p = checkTower()
		p.lastSeen = NOW - 100
		expect(SpireEconomy.offline(p, NOW)).toBe(math.floor(35.1 * 0.5 * 100 + 1e-9))
	end)

	it("Hot Data pays floor(30 x income)", function()
		local p = checkTower()
		expect(SpireEconomy.hotBonus(p, "normal")).toBe(1_053)
	end)

	it("tick: the fraction carry sums exactly over 1,000 ticks", function()
		for _, income in { 35.1, 0.3, 1 / 3, 12_345.678, 0.0001 } do
			local carry, paid = 0, 0
			for _ = 1, 1000 do
				local whole
				whole, carry = SpireEconomy.tick(income, carry, 1)
				expect(whole == math.floor(whole) and whole >= 0).toBeTruthy()
				paid += whole
			end
			expect(paid).toBe(math.floor(income * 1000 + 1e-6))
			expect(carry >= 0 and carry < 1 + 1e-9).toBeTruthy()
		end
		local whole, carry = SpireEconomy.tick(0, 0.5, 1)
		expect(whole).toBe(0)
		expect(carry).toBe(0.5)
	end)

	it("H checks: runEarned 1.13e9 gives 10 Shares, 1.08e10 gives 32", function()
		local p = SpireProgress.defaults(NOW)
		p.runEarned = 1.13e9
		expect(SpireEconomy.ipoShares(p)).toBe(10)
		p.runEarned = 1.08e10
		expect(SpireEconomy.ipoShares(p)).toBe(32)
		p.runEarned = 1e7
		expect(SpireEconomy.ipoShares(p)).toBe(1)
		p.runEarned = 9_999_999
		expect(SpireEconomy.ipoShares(p)).toBe(0)
	end)

	it("worth: credits plus half of every spent and paid amount", function()
		local p = checkTower()
		p.coins = 7
		p.plaza.items[1].paid = 101
		-- racks: 4 x L2 (45) + fusion 150 + 2 ads 600 + 6 racks L1 (15)
		local modules = 4 * 22 + 75 + 2 * 300 + 6 * 7
		expect(SpireEconomy.worth(p)).toBe(7 + modules + 50)
	end)

	it("timeToAfford", function()
		expect(SpireEconomy.timeToAfford(100, 0, 50)).toBe(0)
		expect(SpireEconomy.timeToAfford(0, 0, 50)).toBeNil()
		expect(SpireEconomy.timeToAfford(0, 3, 10)).toBe(4)
		expect(SpireEconomy.timeToAfford(4, 3, 10)).toBe(2)
	end)

	it("short format", function()
		expect(SpireEconomy.short(999)).toBe("999")
		expect(SpireEconomy.short(1_250)).toBe("1.2K")
		expect(SpireEconomy.short(3_400_000)).toBe("3.4M")
		expect(SpireEconomy.short(5_600_000_000)).toBe("5.6B")
		expect(SpireEconomy.short(7.8e12)).toBe("7.8T")
		expect(SpireEconomy.short(9.1e15)).toBe("9.1Qa")
		expect(SpireEconomy.short(1e18)).toBe("1Qi")
		expect(SpireEconomy.short(2_000)).toBe("2K")
		expect(SpireEconomy.short(35.1)).toBe("35")
	end)

	it("property: no buy/upgrade/sell/place/move/sell sequence raises worth (10,000 seeded runs)", function()
		local start = SpireProgress.defaults(NOW, 1)
		start.coins = 5_000_000
		start.xp = MetaRules.xpForLevel(10)
		local depts = { "data", "fusion", "data", "ad", "data", "synth", "data", "fusion", "synth", "data", "data" }
		for i, d in depts do
			start.floors[i + 1] = { d = d, m = { 0, 0, 0, 0 }, s = { 0, 0, 0, 0 } }
		end
		local ids = {}
		for _, item in SpireConfig.ITEMS do
			if PlazaRules.unlocked(start, item.id) then
				table.insert(ids, item.id)
			end
		end
		local events = { "normal", "boom", "neon", "sale" }
		local rises, accepted = 0, 0
		for run = 1, 10_000 do
			local state = Rng.seed(run, 31337)
			local p = start
			local worth = SpireEconomy.worth(p)
			for _ = 1, 12 do
				local op, e, n, slot, x, y, r, k
				op, state = Rng.int(state, 1, 6)
				e, state = Rng.int(state, 1, 4)
				n, state = Rng.int(state, 2, #p.floors)
				slot, state = Rng.int(state, 1, 4)
				x, state = Rng.int(state, 0, 11)
				y, state = Rng.int(state, 0, 7)
				r, state = Rng.int(state, 0, 3)
				k, state = Rng.int(state, 1, #ids)
				local items = p.plaza.items
				local uid = if #items > 0 then items[(k - 1) % #items + 1].u else 1
				local out, ok
				if op == 1 then
					out, ok = TowerRules.buyModule(p, n, slot, events[e])
				elseif op == 2 then
					out, ok = TowerRules.upgradeModule(p, n, slot, events[e])
				elseif op == 3 then
					out, ok = TowerRules.sellModule(p, n, slot)
				elseif op == 4 then
					out, ok = PlazaRules.placeItem(p, ids[k], x, y, r)
				elseif op == 5 then
					out, ok = PlazaRules.moveItem(p, uid, x, y, r)
				else
					out, ok = PlazaRules.sellItem(p, uid)
				end
				local after = SpireEconomy.worth(out)
				if after > worth then
					rises += 1
				end
				if ok then
					accepted += 1
				end
				p, worth = out, after
			end
		end
		expect(rises).toBe(0)
		expect(accepted > 40_000).toBeTruthy() -- most ops land, so the property is exercised
	end)
end)
