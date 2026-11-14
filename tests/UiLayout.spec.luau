--!strict
local T = require("./framework")
local UiLayout = require("../src/shared/UiLayout")

local describe, it, expect = T.describe, T.it, T.expect

describe("UiLayout.scale", function()
	it("keeps every screen between the minimum and maximum scale", function()
		for _, size in { { 390, 844 }, { 800, 360 }, { 1024, 768 }, { 1736, 793 }, { 3840, 2160 }, { 1, 1 } } do
			local s = UiLayout.scale(size[1], size[2])
			expect(s >= UiLayout.MIN_SCALE and s <= UiLayout.MAX_SCALE).toBeTruthy()
		end
	end)

	it("gives a phone the smallest scale, a tablet and a desktop a bigger one, and the base size 1", function()
		expect(UiLayout.scale(800, 360)).toBe(UiLayout.MIN_SCALE) -- phone, landscape
		expect(UiLayout.scale(390, 844)).toBe(UiLayout.MIN_SCALE) -- phone, portrait
		expect(UiLayout.scale(UiLayout.BASE_W, UiLayout.BASE_H)).toBe(1)
		expect(UiLayout.scale(1024, 768) > UiLayout.scale(800, 360)).toBeTruthy()
		expect(UiLayout.scale(1920, 1080)).toBe(UiLayout.MAX_SCALE)
	end)

	it("leaves a phone enough room: at least 420 units across and 400 high", function()
		for _, size in { { 800, 360 }, { 390, 844 } } do
			local s = UiLayout.scale(size[1], size[2])
			expect(size[1] / s >= 420).toBeTruthy()
			expect(size[2] / s >= 400).toBeTruthy()
		end
	end)
end)

describe("UiLayout.frameDistance", function()
	it("stands further from bigger creatures, in proportion, and further with a narrower view", function()
		local small = UiLayout.frameDistance({ 2, 2, 4 }, 30)
		local big = UiLayout.frameDistance({ 4, 4, 8 }, 30)
		expect(small > 0).toBeTruthy()
		expect(math.abs(big / small - 2) < 1e-9).toBeTruthy()
		expect(UiLayout.frameDistance({ 2, 2, 4 }, 20) > small).toBeTruthy()
	end)
end)

describe("UiLayout.fightDistance", function()
	it("stands back in proportion to the fight, and further on a narrow screen", function()
		local wide = UiLayout.fightDistance(30, 55, 2.2)
		expect(math.abs(UiLayout.fightDistance(60, 55, 2.2) / wide - 2) < 1e-9).toBeTruthy()
		expect(UiLayout.fightDistance(30, 55, 0.46) > wide).toBeTruthy() -- a phone held upright
		expect(math.abs(UiLayout.fightDistance(30, 55, 5) - UiLayout.fightDistance(30, 55, 3)) < 1e-9).toBeTruthy() -- height decides
	end)
end)
