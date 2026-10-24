--!strict
local T = require("./framework")
local BakeRules = require("../src/shared/BakeRules")
local BakeConfig = require("../src/shared/BakeConfig")

local describe, it, expect = T.describe, T.it, T.expect
local config: BakeRules.Config = BakeConfig

describe("BakeRules.bake", function()
	it("adds one pastry", function()
		local result = BakeRules.bake(BakeRules.newState(), 0, config)
		expect(result.ok).toBe(true)
		expect(result.state.pastries).toBe(1)
	end)

	it("rejects a tap before the tier's bake time has passed", function()
		local first = BakeRules.bake(BakeRules.newState(), 0, config)
		local second = BakeRules.bake(first.state, 0.5, config)
		expect(second.ok).toBe(false)
		expect(second.reason).toBe("cooldown")
		expect(second.state.pastries).toBe(1)
	end)

	it("uses the faster bake time after an upgrade", function()
		local state = { coins = 50, tier = 1, pastries = 0, lastBakeAt = 0 }
		local upgraded = BakeRules.upgrade(state, config)
		local tapped = BakeRules.bake(upgraded.state, 0.8, config)
		expect(tapped.ok).toBe(true)
	end)

	it("rejects an unknown tier", function()
		local result = BakeRules.bake({ coins = 0, tier = 99, pastries = 0, lastBakeAt = nil }, 0, config)
		expect(result.reason).toBe("invalid_tier")
	end)
end)

describe("BakeRules.sell", function()
	it("sells all pastries at the tier price", function()
		local state = { coins = 0, tier = 2, pastries = 5, lastBakeAt = nil }
		local result = BakeRules.sell(state, config)
		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(10)
		expect(result.state.pastries).toBe(0)
	end)

	it("rejects selling with nothing carried", function()
		local result = BakeRules.sell(BakeRules.newState(), config)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("nothing_to_sell")
	end)

	it("caps coins at maxCoins", function()
		local state = { coins = 999_999_999, tier = 5, pastries = 10, lastBakeAt = nil }
		local result = BakeRules.sell(state, config)
		expect(result.state.coins).toBe(1_000_000_000)
	end)
end)

describe("BakeRules.upgrade", function()
	it("upgrades one tier when the player can pay", function()
		local state = { coins = 50, tier = 1, pastries = 0, lastBakeAt = nil }
		local result = BakeRules.upgrade(state, config)
		expect(result.ok).toBe(true)
		expect(result.state.tier).toBe(2)
		expect(result.state.coins).toBe(0)
	end)

	it("leaves state unchanged when coins are short", function()
		local state = { coins = 49, tier = 1, pastries = 0, lastBakeAt = nil }
		local result = BakeRules.upgrade(state, config)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("insufficient_coins")
		expect(result.state.tier).toBe(1)
		expect(result.state.coins).toBe(49)
	end)

	it("refuses to go past the last tier", function()
		local state = { coins = 1_000_000, tier = 5, pastries = 0, lastBakeAt = nil }
		local result = BakeRules.upgrade(state, config)
		expect(result.reason).toBe("max_tier")
	end)
end)
