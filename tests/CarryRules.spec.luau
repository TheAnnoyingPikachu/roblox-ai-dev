--!strict
-- CarryRules (architecture lantern 3.4, 8; GDD C2, D, J): carrying, help-carry, drop, load, the
-- fog and the stop closing. The J table is checked cell by cell: an item is earned only when
-- `load` returns it, and nothing returned by `load` is ever taken back.
local T = require("./framework")
local CarryRules = require("../src/shared/CarryRules")
local LootRules = require("../src/shared/LootRules")

local describe, it, expect = T.describe, T.it, T.expect

type Stop = LootRules.Stop
type Item = LootRules.Item

local A, B, C = 101, 202, 303
local KINDS = { "coal", "parts", "oil", "supply", "critter" }

-- A stop with two of each kind: ids 1..10 in KINDS order (1, 2 coal; 3, 4 parts; ...).
local function stop(): Stop
	local items: { [number]: Item } = {}
	for k, kind in KINDS do
		for j = 1, 2 do
			local id = (k - 1) * 2 + j
			local big = kind == "supply" or kind == "critter"
			items[id] = {
				id = id,
				kind = kind :: any,
				site = id,
				big = big,
				pos = { x = 0, y = 0, z = 10 * id },
				species = if kind == "critter" then "mossmouse" else nil,
				rarity = if kind == "critter" then "common" else nil,
				state = "free",
			}
		end
	end
	return { tile = "farm", line = "forest", leg = 1, index = 1, n = 2, items = items }
end

local function idOf(kind: string): number
	return (table.find(KINDS, kind) :: number) * 2 - 1
end

local function ids(list: { Item }): string
	local out = {}
	for _, item in list do
		table.insert(out, tostring(item.id))
	end
	return table.concat(out, " ")
end

describe("CarryRules: the GDD J table, one case per cell", function()
	for _, kind in KINDS do
		local id = idOf(kind)
		it(`{kind}: carried is not earned (picked, carried by the picker, nothing loaded)`, function()
			local s, c = CarryRules.pick(stop(), {}, A, id)
			expect(`{s.items[id].state} {s.items[id].by}`).toBe(`carried {A}`)
			local _, _, loaded = CarryRules.load(s, c, B, 100)
			expect(#loaded).toBe(0) -- only the carrier loads it
		end)

		it(`{kind}: dropped lies on the ground and anyone may pick it up`, function()
			local s, c = CarryRules.pick(stop(), {}, A, id)
			s, c = CarryRules.drop(s, c, A, { x = 4, y = 0, z = 30 })
			expect(`{s.items[id].state} {s.items[id].by} {s.items[id].pos.x} {s.items[id].pos.z} {c[A]}`).toBe(
				"free nil 4 30 nil"
			)
			s = CarryRules.pick(s, c, B, id)
			expect(`{s.items[id].state} {s.items[id].by}`).toBe(`carried {B}`)
		end)

		it(`{kind}: carrier caught by the fog drops it there; it is gone for this run, never loaded`, function()
			local s, c = CarryRules.pick(stop(), {}, A, id)
			s, c = CarryRules.catch(s, c, A, { x = 0, y = 0, z = 120 })
			expect(`{s.items[id].state} {s.items[id].pos.z} {c[A]}`).toBe("free 120 nil")
			s, c = CarryRules.close(s, c)
			-- a critter crate goes back to its stop: lost here, never counted as rescued
			expect(`{s.items[id].state} {next(c)}`).toBe("lost nil")
		end)

		it(`{kind}: carrier leaves the game, it is dropped where they stood`, function()
			local s, c = CarryRules.pick(stop(), {}, A, id)
			s, c = CarryRules.drop(s, c, A, { x = -3, y = 0, z = 44 })
			expect(`{s.items[id].state} {s.items[id].pos.x} {s.items[id].pos.z} {c[A]}`).toBe("free -3 44 nil")
		end)

		it(`{kind}: left at the stop when the train leaves, it is gone for this run`, function()
			local s, c = CarryRules.pick(stop(), {}, A, id)
			s, c = CarryRules.close(s, c)
			expect(`{s.items[id].state} {s.items[id + 1].state} {s.items[id].by}`).toBe("lost lost nil")
			expect(next(c)).toBeNil()
		end)

		it(`{kind}: loaded on the train it is returned to be paid, and stays loaded through the close`, function()
			local s, c = CarryRules.pick(stop(), {}, A, id)
			local loaded
			s, c, loaded = CarryRules.load(s, c, A, 100)
			expect(`{ids(loaded)} {loaded[1].kind} {s.items[id].state} {c[A]}`).toBe(`{id} {kind} loaded nil`)
			s = CarryRules.close(s, c)
			expect(s.items[id].state).toBe("loaded")
			-- a loaded item can never be picked, dropped or loaded again
			expect(select(2, CarryRules.canPick(s, {}, B, id))).toBe("gone")
			local _, _, again = CarryRules.load(s, {}, A, 100)
			expect(#again).toBe(0)
		end)
	end
end)

describe("CarryRules: hands, help-carry and speed", function()
	it("carries 3 small items or 1 big one, with the refusal codes", function()
		local s, c = stop(), {}
		s, c = CarryRules.pick(s, c, A, 1)
		s, c = CarryRules.pick(s, c, A, 3)
		expect(select(2, CarryRules.canPick(s, c, A, 7))).toBe("big") -- small items held
		s, c = CarryRules.pick(s, c, A, 5)
		expect(#c[A].small).toBe(3)
		expect(select(2, CarryRules.canPick(s, c, A, 2))).toBe("full")
		expect(select(2, CarryRules.canPick(s, c, A, 1))).toBe("taken")
		expect(select(2, CarryRules.canPick(s, c, B, 1))).toBe("taken") -- never from another's back
		s, c = CarryRules.pick(s, c, B, 9)
		expect(select(2, CarryRules.canPick(s, c, B, 2))).toBe("hands")
		expect(select(2, CarryRules.canPick(s, c, B, 99))).toBe("gone")
		local same, sameC = CarryRules.pick(s, c, B, 2) -- refused: unchanged
		expect(same == s and sameC == c).toBe(true)
	end)

	it("lets a second player help only with a critter crate carried alone, never take it", function()
		local s, c = stop(), {}
		s, c = CarryRules.pick(s, c, A, 9) -- critter crate
		s, c = CarryRules.pick(s, c, C, 7) -- supply crate
		expect(select(2, CarryRules.canHelp(s, c, B, 7))).toBe("gone") -- not a critter crate
		expect(select(2, CarryRules.canHelp(s, c, A, 9))).toBe("taken") -- own crate
		expect(select(2, CarryRules.canHelp(s, c, C, 9))).toBe("hands")
		expect(select(2, CarryRules.canHelp(s, c, B, 10))).toBe("gone") -- not carried
		s, c = CarryRules.help(s, c, B, 9)
		expect(`{s.items[9].by} {s.items[9].helper}`).toBe(`{A} {B}`)
		expect(select(2, CarryRules.canHelp(s, c, C, 9))).toBe("taken")
		expect(select(2, CarryRules.canPick(s, c, B, 1))).toBe("hands") -- the helper's hands are full
		-- the helper never loads or drops the crate: they only let go
		local _, _, loaded = CarryRules.load(s, c, B, 100)
		expect(#loaded).toBe(0)
		local dropped = CarryRules.drop(s, c, B, { x = 0, y = 0, z = 0 })
		expect(`{dropped.items[9].state} {dropped.items[9].by} {dropped.items[9].helper}`).toBe(`carried {A} nil`)
		local let = CarryRules.letGo(s, B)
		expect(`{let.items[9].by} {let.items[9].helper}`).toBe(`{A} nil`)
		expect(CarryRules.letGo(let, B) == let).toBe(true) -- nothing to let go: unchanged
	end)

	it("sets speeds 16 / 15 / 13 / 9 / 13, and 13 for the helper", function()
		local s, c = stop(), {}
		expect(CarryRules.speed(s, c, A)).toBe(16)
		s, c = CarryRules.pick(s, c, A, 1)
		expect(CarryRules.speed(s, c, A)).toBe(15)
		s, c = CarryRules.pick(s, c, B, 7)
		expect(CarryRules.speed(s, c, B)).toBe(13)
		s, c = CarryRules.pick(s, c, C, 9)
		expect(CarryRules.speed(s, c, C)).toBe(9)
		s, c = CarryRules.help(s, c, 404, 9)
		expect(`{CarryRules.speed(s, c, C)} {CarryRules.speed(s, c, 404)}`).toBe("13 13")
	end)

	it("keeps coal sacks carried when the bunker is full, and loads only what fits", function()
		local s, c = stop(), {}
		s, c = CarryRules.pick(s, c, A, 1)
		s, c = CarryRules.pick(s, c, A, 2)
		s, c = CarryRules.pick(s, c, A, 3)
		local full, fullC, loaded = CarryRules.load(s, c, A, 0)
		expect(`{ids(loaded)} | {table.concat(fullC[A].small, " ")} | {full.items[1].state}`).toBe("3 | 1 2 | carried")
		local _, someC, some = CarryRules.load(s, c, A, 3) -- room for one sack (it may overfill to the cap)
		expect(`{ids(some)} | {table.concat(someC[A].small, " ")}`).toBe("1 3 | 2")
	end)

	it("loads a helped crate for its first carrier, which frees the helper", function()
		local s, c = stop(), {}
		s, c = CarryRules.pick(s, c, A, 9)
		s, c = CarryRules.help(s, c, B, 9)
		local out, outC, loaded = CarryRules.load(s, c, A, 0)
		expect(`{ids(loaded)} {out.items[9].state} {out.items[9].helper} {outC[A]}`).toBe("9 loaded nil nil")
		expect(CarryRules.canPick(out, outC, B, 1)).toBe(true)
	end)

	it("never mutates its inputs", function()
		local s = stop()
		local c = {}
		local s1, c1 = CarryRules.pick(s, c, A, 9)
		expect(`{s.items[9].state} {next(c)}`).toBe("free nil")
		local s2 = CarryRules.help(s1, c1, B, 9)
		expect(s1.items[9].helper).toBeNil()
		CarryRules.drop(s2, c1, A, { x = 0, y = 0, z = 0 })
		CarryRules.load(s2, c1, A, 100)
		CarryRules.close(s2, c1)
		expect(`{s2.items[9].state} {s2.items[9].helper} {c1[A].big}`).toBe(`carried {B} 9`)
	end)
end)
