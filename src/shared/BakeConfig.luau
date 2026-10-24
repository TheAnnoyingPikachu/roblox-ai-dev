--!strict
-- Bake Rush tuning. Values match docs/game-design/bake-rush-gdd.md section C.
-- Changing them needs a decision record in docs/decisions/.

local config = {
	tiers = {
		{ upgradeCost = 0, bakeTime = 1.0, sellPrice = 1 },
		{ upgradeCost = 50, bakeTime = 0.8, sellPrice = 2 },
		{ upgradeCost = 200, bakeTime = 0.6, sellPrice = 3 },
		{ upgradeCost = 800, bakeTime = 0.5, sellPrice = 5 },
		{ upgradeCost = 3000, bakeTime = 0.4, sellPrice = 8 },
	},
	maxCoins = 1_000_000_000,
}

return table.freeze(config)
