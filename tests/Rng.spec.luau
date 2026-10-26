--!strict
local T = require("./framework")
local Rng = require("../src/shared/Rng")

local describe, it, expect = T.describe, T.it, T.expect

describe("Rng", function()
	it("gives the same sequence for the same seed", function()
		local a, b = Rng.seed(12345, 2, 7), Rng.seed(12345, 2, 7)
		expect(a).toBe(b)
		for _ = 1, 100 do
			local va, vb
			va, a = Rng.next(a)
			vb, b = Rng.next(b)
			expect(va).toBe(vb)
		end
	end)

	it("gives different states for nearby seeds", function()
		local seen = {}
		for w = 0, 20 do
			local s = Rng.seed(99, 0, w)
			expect(seen[s]).toBeNil()
			seen[s] = true
		end
		expect(Rng.seed(1, 2) == Rng.seed(2, 1)).toBe(false)
	end)

	it("keeps next in [0, 1) and int in [lo, hi], reaching both ends", function()
		local s = Rng.seed(7)
		local lowSeen, highSeen = false, false
		for _ = 1, 2000 do
			local v
			v, s = Rng.next(s)
			expect(v >= 0 and v < 1).toBe(true)
			local i
			i, s = Rng.int(s, 3, 6)
			expect(i >= 3 and i <= 6 and i == math.floor(i)).toBe(true)
			lowSeen = lowSeen or i == 3
			highSeen = highSeen or i == 6
		end
		expect(lowSeen and highSeen).toBe(true)
		expect((Rng.int(s, 5, 5))).toBe(5)
	end)

	it("never gets stuck on a zero state", function()
		local v, s = Rng.next(0)
		expect(s ~= 0).toBe(true)
		expect(v > 0).toBe(true)
		expect(Rng.seed(0, 0, 0) ~= 0).toBe(true)
		expect(Rng.seed(-5, 3.7) >= 1).toBe(true)
	end)
end)
