--!strict
-- Pure Bake Rush rules. No Roblox APIs, so Lune can unit-test them headlessly.
-- The server owns every value; clients only request bake, sell and upgrade.

local BakeRules = {}

export type Tier = {
	upgradeCost: number,
	bakeTime: number,
	sellPrice: number,
}

export type Config = {
	tiers: { Tier },
	maxCoins: number,
}

export type State = {
	coins: number,
	tier: number,
	pastries: number,
	lastBakeAt: number?,
}

export type Outcome = {
	ok: boolean,
	reason: string?,
	state: State,
}

function BakeRules.newState(): State
	return { coins = 0, tier = 1, pastries = 0, lastBakeAt = nil }
end

local function clampCoins(coins: number, config: Config): number
	return math.min(coins, config.maxCoins)
end

-- Bake one pastry. The tier's bake time is the cooldown between taps.
function BakeRules.bake(state: State, now: number, config: Config): Outcome
	local tier = config.tiers[state.tier]
	if tier == nil then
		return { ok = false, reason = "invalid_tier", state = state }
	end
	if state.lastBakeAt ~= nil and now - state.lastBakeAt < tier.bakeTime then
		return { ok = false, reason = "cooldown", state = state }
	end
	return {
		ok = true,
		reason = nil,
		state = {
			coins = state.coins,
			tier = state.tier,
			pastries = state.pastries + 1,
			lastBakeAt = now,
		},
	}
end

-- Sell every carried pastry at the current tier's price. No amount is accepted from the client.
function BakeRules.sell(state: State, config: Config): Outcome
	local tier = config.tiers[state.tier]
	if tier == nil then
		return { ok = false, reason = "invalid_tier", state = state }
	end
	if state.pastries == 0 then
		return { ok = false, reason = "nothing_to_sell", state = state }
	end
	return {
		ok = true,
		reason = nil,
		state = {
			coins = clampCoins(state.coins + state.pastries * tier.sellPrice, config),
			tier = state.tier,
			pastries = 0,
			lastBakeAt = state.lastBakeAt,
		},
	}
end

-- Upgrades only to the next tier, and only when the player can pay.
function BakeRules.upgrade(state: State, config: Config): Outcome
	local nextTier = config.tiers[state.tier + 1]
	if nextTier == nil then
		return { ok = false, reason = "max_tier", state = state }
	end
	if state.coins < nextTier.upgradeCost then
		return { ok = false, reason = "insufficient_coins", state = state }
	end
	return {
		ok = true,
		reason = nil,
		state = {
			coins = state.coins - nextTier.upgradeCost,
			tier = state.tier + 1,
			pastries = state.pastries,
			lastBakeAt = state.lastBakeAt,
		},
	}
end

return BakeRules
