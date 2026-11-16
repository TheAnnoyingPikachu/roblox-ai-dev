--!strict
local T = require("./framework")
local TrainFx = require("../src/shared/TrainFx")

local describe, it, expect = T.describe, T.it, T.expect

describe("TrainFx", function()
	it("keeps every curve between 0 and 1 and repeats it each turn", function()
		for step = 0, 400 do
			local t = step * 0.017
			local down, u = TrainFx.heave(t)
			for _, v in { down, u, TrainFx.push(t), TrainFx.brace(t), TrainFx.swing(t) } do
				expect(v >= 0 and v <= 1).toBeTruthy()
			end
			expect(math.abs(TrainFx.heave(t + TrainFx.HEAVE) - down) < 1e-6).toBeTruthy()
			expect(math.abs(TrainFx.push(t + TrainFx.HEAVE) - TrainFx.push(t)) < 1e-6).toBeTruthy()
			expect(math.abs(TrainFx.brace(t + TrainFx.BRACE) - TrainFx.brace(t)) < 1e-6).toBeTruthy()
			expect(math.abs(TrainFx.swing(t + TrainFx.BRACE) - TrainFx.swing(t)) < 1e-6).toBeTruthy()
		end
	end)

	it("lifts once a turn: standing, down at the bottom, standing again before the next", function()
		expect((TrainFx.heave(0))).toBe(0)
		expect((TrainFx.heave(0.35 * TrainFx.HEAVE))).toBe(1)
		expect((TrainFx.heave(0.7 * TrainFx.HEAVE))).toBe(0)
		expect((TrainFx.heave(0.99 * TrainFx.HEAVE))).toBe(0)
	end)

	it("moves the boulder only once the animal drives, and has it back before the next lift", function()
		for step = 0, 34 do -- while the animal sinks, the boulder rests
			expect(TrainFx.push(step / 100 * TrainFx.HEAVE)).toBe(0)
		end
		local furthest = 0
		for step = 35, 100 do
			furthest = math.max(furthest, TrainFx.push(step / 100 * TrainFx.HEAVE))
		end
		expect(furthest > 0.99).toBeTruthy()
		expect(TrainFx.push(0.99 * TrainFx.HEAVE)).toBe(0)
	end)

	it("lands the ram as the animal is thrown back: it is against the animal when the blow begins", function()
		expect(TrainFx.swing(0)).toBe(0)
		expect(TrainFx.brace(0)).toBe(0)
		expect(TrainFx.brace(0.07 * TrainFx.BRACE) > 0.99).toBeTruthy() -- thrown back at once
		expect(TrainFx.swing(0.07 * TrainFx.BRACE) < 0.25).toBeTruthy() -- the ram has barely left
		expect(TrainFx.swing(0.5 * TrainFx.BRACE) > 0.99).toBeTruthy() -- and is furthest half way
		expect(TrainFx.brace(0.5 * TrainFx.BRACE)).toBe(0) -- by when the animal is set again
	end)
end)
