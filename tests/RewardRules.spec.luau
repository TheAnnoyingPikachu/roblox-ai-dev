--!strict
local T = require("./framework")
local RewardRules = require("../src/shared/RewardRules")

local describe, it, expect = T.describe, T.it, T.expect

local config: RewardRules.Config = {
	rewardAmount = 10,
	cooldownSeconds = 1,
	maxClaimsPerWindow = 3,
	windowSeconds = 60,
	maxCoins = 25,
}

local ALLOWED = { starter_pad = true }

describe("RewardRules.claim", function()
	it("awards the configured amount on a first claim", function()
		local result = RewardRules.claim(RewardRules.newState(0), 0, config)
		expect(result.ok).toBe(true)
		expect(result.awarded).toBe(10)
		expect(result.state.coins).toBe(10)
	end)

	it("does not mutate the input state", function()
		local state = RewardRules.newState(0)
		RewardRules.claim(state, 0, config)
		expect(state.coins).toBe(0)
		expect(state.lastClaimAt).toBeNil()
	end)

	it("rejects a repeat claim inside the cooldown", function()
		local first = RewardRules.claim(RewardRules.newState(0), 0, config)
		local second = RewardRules.claim(first.state, 0.5, config)
		expect(second.ok).toBe(false)
		expect(second.reason).toBe("cooldown")
		expect(second.state.coins).toBe(10)
	end)

	it("rate-limits claims within a window", function()
		local loose = table.clone(config)
		loose.maxCoins = 1000
		local state = RewardRules.newState(0)
		for i = 0, 2 do
			state = RewardRules.claim(state, i * 2, loose).state
		end
		local blocked = RewardRules.claim(state, 10, loose)
		expect(blocked.ok).toBe(false)
		expect(blocked.reason).toBe("rate_limited")
	end)

	it("resets the window after windowSeconds", function()
		local loose = table.clone(config)
		loose.maxCoins = 1000
		local state = RewardRules.newState(0)
		for i = 0, 2 do
			state = RewardRules.claim(state, i * 2, loose).state
		end
		local later = RewardRules.claim(state, 61, loose)
		expect(later.ok).toBe(true)
		expect(later.state.claimsInWindow).toBe(1)
	end)

	it("refuses to exceed the balance cap", function()
		local state = RewardRules.newState(0)
		state = RewardRules.claim(state, 0, config).state
		state = RewardRules.claim(state, 2, config).state
		local capped = RewardRules.claim(state, 4, config)
		expect(capped.ok).toBe(false)
		expect(capped.reason).toBe("balance_cap")
	end)

	it("rejects non-finite timestamps", function()
		local result = RewardRules.claim(RewardRules.newState(0), 0 / 0, config)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("invalid_time")
	end)
end)

describe("RewardRules.validateRequest", function()
	it("accepts a known source", function()
		expect(RewardRules.validateRequest({ sourceId = "starter_pad" }, ALLOWED)).toBe(true)
	end)

	it("rejects non-table payloads", function()
		local ok, reason = RewardRules.validateRequest("starter_pad", ALLOWED)
		expect(ok).toBe(false)
		expect(reason).toBe("bad_payload")
	end)

	it("rejects unknown sources", function()
		local _, reason = RewardRules.validateRequest({ sourceId = "admin_pad" }, ALLOWED)
		expect(reason).toBe("unknown_source")
	end)

	it("rejects a client-supplied amount", function()
		local _, reason = RewardRules.validateRequest({ sourceId = "starter_pad", amount = 9999 }, ALLOWED)
		expect(reason).toBe("unexpected_field")
	end)

	it("rejects oversized source ids", function()
		local _, reason = RewardRules.validateRequest({ sourceId = string.rep("a", 33) }, ALLOWED)
		expect(reason).toBe("bad_source")
	end)
end)
