--!strict
-- Luau port of docs/game-design/game5-pacing-sim.py (GDD B, decision 0009), driven by the real
-- SpireConfig values and the TowerRules / PlazaRules / SpireEconomy functions, so CI fails if a
-- config change moves the pacing targets by more than 30%.
--
-- Differences from the Python sim, all to follow the shipped rules: floor costs come from the C2
-- table (3 significant figures); department and plaza unlocks use the rule functions (deptAllowed
-- on the new floor number, PlazaRules.unlocked); the run starts from SpireProgress.defaults (floor
-- 2 owned for free instead of bought for 60). Plaza items are counted by cells (80 usable) as in
-- the sim, not packed on the grid.
local T = require("./framework")
local PlazaRules = require("../src/shared/PlazaRules")
local SpireConfig = require("../src/shared/SpireConfig")
local SpireEconomy = require("../src/shared/SpireEconomy")
local SpireProgress = require("../src/shared/SpireProgress")
local TowerRules = require("../src/shared/TowerRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = SpireConfig.Profile

local ACTIVE_BONUS = 1.15 -- about half the Hot Data caught, plus events (GDD E3)
local PLAZA_CELLS = SpireConfig.PLAZA.w * SpireConfig.PLAZA.d - #SpireConfig.PLAZA.walkway * SpireConfig.PLAZA.d
local LV = SpireConfig.LV
local EVENT = "normal"
local TOLERANCE = 0.30

-- GDD B, first run (minutes).
local TARGETS = { [5] = 3.5, [10] = 18, [15] = 35, [20] = 86 }

local function dept(id: string): SpireConfig.Dept
	return SpireConfig.dept(id) :: SpireConfig.Dept
end

local function baseIncome(p: Profile, n: number): number
	local f = p.floors[n]
	local sum = 0
	for _, level in f.m do
		sum += SpireEconomy.moduleIncome(f.d, level, EVENT)
	end
	return sum
end

-- The sim's floor picker: the best income department, a Fusion Core when power runs short, and an
-- Ad Agency on every third floor once allowed.
local function pickDept(p: Profile): string
	local n = #p.floors + 1
	local newest, best = "data", -1
	for _, d in SpireConfig.DEPTS do
		if d.id ~= "fusion" and d.id ~= "ad" and TowerRules.deptAllowed(d.id, n) and d.income > best then
			newest, best = d.id, d.income
		end
	end
	if TowerRules.deptAllowed("fusion", n) and TowerRules.draw(p) + 2 * dept(newest).draw > TowerRules.supply(p) then
		local hasFusion, allMaxed = false, true
		for _, f in p.floors do
			if f.d == "fusion" then
				hasFusion = true
				for _, level in f.m do
					allMaxed = allMaxed and level == 5
				end
			end
		end
		if allMaxed or not hasFusion then
			return "fusion"
		end
	end
	if TowerRules.deptAllowed("ad", n) and (#p.floors - 1) % 3 == 2 then
		return "ad"
	end
	return newest
end

type Choice = { score: number, cost: number, kind: string, n: number, slot: number, id: string }

-- Greedy run: buys whatever gives the most income per credit, else waits. Returns the minute each
-- floor count in `marks` was first reached.
local function run(stopAt: number, maxMinutes: number): { [number]: number }
	local p = SpireProgress.defaults(0)
	local cells = 0
	local t = 0
	local reached: { [number]: number } = {}
	while t < maxMinutes * 60 and reached[stopAt] == nil do
		local supply, draw = TowerRules.supply(p), TowerRules.draw(p)
		local mult = PlazaRules.hypeMult(p) * SpireEconomy.shareMult(p)
		local best: Choice? = nil
		local function offer(score: number, cost: number, kind: string, n: number, slot: number, id: string)
			if best == nil or score > (best :: Choice).score then
				best = { score = score, cost = cost, kind = kind, n = n, slot = slot, id = id }
			end
		end

		for n = 2, #p.floors do
			local f = p.floors[n]
			local d = dept(f.d)
			local fm = TowerRules.floorMult(p, n, EVENT)
			for slot = 1, SpireConfig.SLOTS do
				local level = f.m[slot]
				if level < 5 then
					local cost = TowerRules.moduleCost(f.d, level + 1, EVENT) :: number
					local gain
					if f.d == "fusion" then
						gain = if draw + 10 > supply then 1e9 else 0
					elseif level == 0 and draw + d.draw > supply then
						gain = nil
					else
						gain = d.income * (LV[level + 1] - (if level > 0 then LV[level] else 0)) * fm * mult
						if f.d == "ad" and level == 0 and TowerRules.moduleCount(p, n) == 0 then
							for _, j in { n - 1, n + 1 } do
								local nf = p.floors[j]
								if j >= 2 and nf and nf.d ~= "ad" and nf.d ~= "fusion" then
									gain += SpireConfig.AD.boost * baseIncome(p, j) * mult
								end
							end
						end
					end
					if gain then
						offer(gain / cost, cost, "module", n, slot, "")
					end
				end
			end
		end

		if #p.floors < SpireConfig.MAX_FLOORS then
			local nd = pickDept(p)
			local cost = TowerRules.floorCost(#p.floors + 1) :: number
			local gain = if nd == "fusion" then 1e9 else dept(nd).income * mult
			local freeSlot = false
			for n = 2, #p.floors do
				local f = p.floors[n]
				for _, level in f.m do
					if level == 0 and f.d ~= "fusion" and draw + dept(f.d).draw <= supply then
						freeSlot = true
					end
				end
			end
			local score = if freeSlot and nd ~= "fusion" then 0 else gain / (cost + dept(nd).cost)
			if nd == "fusion" and draw + 10 <= supply then
				score = 0
			end
			offer(score, cost, "floor", 0, 0, nd)
		end

		if PlazaRules.hype(p) < PlazaRules.hypeCap(p) then
			local per = PlazaRules.counts(p)
			local raw = SpireEconomy.income(p, EVENT) / PlazaRules.hypeMult(p)
			for _, item in SpireConfig.ITEMS do
				if
					not item.decor
					and (per[item.id] or 0) < (item.max :: number)
					and cells + item.w * item.d <= PLAZA_CELLS
					and PlazaRules.unlocked(p, item.id)
				then
					offer(raw * item.hype / 100 / item.cost, item.cost, "plaza", 0, 0, item.id)
				end
			end
		end

		local choice = best :: Choice?
		if choice and choice.score > 0 and choice.cost <= p.coins then
			local out, ok, code
			if choice.kind == "module" then
				local level = p.floors[choice.n].m[choice.slot]
				if level == 0 then
					out, ok, code = TowerRules.buyModule(p, choice.n, choice.slot, EVENT)
				else
					out, ok, code = TowerRules.upgradeModule(p, choice.n, choice.slot, EVENT)
				end
			elseif choice.kind == "floor" then
				out, ok, code = TowerRules.buyFloor(p, choice.id)
			else
				local item = SpireConfig.item(choice.id) :: SpireConfig.PlazaItem
				out, ok = TowerRules.copy(p), true
				out.coins -= item.cost
				table.insert(
					out.plaza.items,
					{ u = out.plaza.nextUid, id = item.id, x = 0, y = 0, r = 0, paid = item.cost }
				)
				out.plaza.nextUid += 1
				cells += item.w * item.d
			end
			assert(ok, `sim chose a refused {choice.kind}: {code}`)
			p = out
		else
			local inc = SpireEconomy.income(p, EVENT) * ACTIVE_BONUS
			local dt = if inc == 0
				then 1
				else math.max(1, math.min(60, if choice then (choice.cost - p.coins) / inc else 60))
			p.coins += inc * dt
			t += dt
			for floors = 2, #p.floors do
				if reached[floors] == nil then
					reached[floors] = t / 60
				end
			end
		end
	end
	return reached
end

describe("SpireBalance", function()
	local reached = run(20, 240)
	for _, floors in { 5, 10, 15, 20 } do
		local target = TARGETS[floors]
		local got = reached[floors]
		it(
			string.format(
				"first run reaches floor %d at %s min (GDD B %g min, ±30%%)",
				floors,
				if got then string.format("%.1f", got) else "never",
				target
			),
			function()
				expect(got ~= nil).toBeTruthy()
				expect(math.abs((got :: number) / target - 1) <= TOLERANCE).toBeTruthy()
			end
		)
	end

	it("floors are reached in order", function()
		for floors = 3, 20 do
			expect(reached[floors] ~= nil and reached[floors] >= reached[floors - 1]).toBeTruthy()
		end
	end)
end)
