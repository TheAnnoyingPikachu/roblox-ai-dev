--!strict
local T = require("./framework")
local FightFx = require("../src/shared/FightFx")

local describe, it, expect = T.describe, T.it, T.expect

describe("FightFx.lead and flightTime", function()
	it("keeps a normal attack's lead and a power attack's lead as they were", function()
		expect(FightFx.lead(false, nil)).toBe(0.45)
		expect(FightFx.lead(true, nil)).toBe(0.92)
		expect(FightFx.lead(true, 0.3)).toBe(0.92) -- a power attack never fires a projectile
	end)

	it("starts a shot so its release comes one flight before the hit", function()
		local flight = FightFx.flightTime(40)
		expect(math.abs(FightFx.lead(false, flight) - flight - FightFx.RELEASE) < 1e-9).toBeTruthy()
	end)

	it("keeps a flight between 0.18 and 0.7 seconds", function()
		expect(FightFx.flightTime(0)).toBe(0.18)
		expect(FightFx.flightTime(1e6)).toBe(0.7)
		expect(FightFx.flightTime(35)).toBe(0.5)
	end)
end)

describe("FightFx hit feel", function()
	it("freezes a power hit longer than a normal one, never more than 0.1 s", function()
		expect(FightFx.hitStop(0)).toBe(0.06)
		expect(FightFx.hitStop(1)).toBe(0.1)
		expect(FightFx.hitStop(5)).toBe(0.1)
	end)

	it("flinches harder for a power hit and for a big share of health", function()
		expect(FightFx.flinch(0, 0)).toBe(1)
		expect(FightFx.flinch(1, 0) > FightFx.flinch(0, 0)).toBeTruthy()
		expect(FightFx.flinch(0, 0.2) > FightFx.flinch(0, 0.05)).toBeTruthy()
		expect(FightFx.flinch(1, 10) <= 2.2).toBeTruthy()
	end)

	it("punches the camera hardest for a power hit and lets it fade to nothing", function()
		expect(FightFx.punchStrength(1) > FightFx.punchStrength(0)).toBeTruthy()
		expect(FightFx.punch(0, 1)).toBe(1)
		expect(FightFx.punch(0.2, 1) < FightFx.punch(0.1, 1)).toBeTruthy()
		expect(FightFx.punch(FightFx.PUNCH_SECONDS + 0.01, 1)).toBe(0)
		expect(FightFx.punch(-1, 1)).toBe(0)
	end)
end)
