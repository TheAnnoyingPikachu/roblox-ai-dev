--!strict
-- Shared tuning values. Changing anything here that affects the economy needs a
-- decision record in docs/decisions/.

local Config = {
	Reward = {
		rewardAmount = 10,
		cooldownSeconds = 1,
		maxClaimsPerWindow = 30,
		windowSeconds = 60,
		maxCoins = 1_000_000_000,
	},

	AllowedRewardSources = {
		starter_pad = true,
	},
}

return table.freeze(Config)
