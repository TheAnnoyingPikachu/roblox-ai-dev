--!strict
-- Pure save-data rules for Bake Rush. No Roblox APIs, so Lune can test them.
-- Saved data is untrusted when read back: every field is validated and clamped
-- before the server uses it.

local BakeConfig = require("./BakeConfig")

local SaveRules = {}

SaveRules.SCHEMA_VERSION = 1

export type Saved = {
	schemaVersion: number,
	coins: number,
	tier: number,
	pastries: number,
}

local function whole(value: any, min: number, max: number, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	local n = math.floor(value)
	return math.clamp(n, min, max)
end

-- Turns a loaded table into a safe state. Unknown or malformed fields fall back to defaults.
function SaveRules.sanitize(data: any, maxCoins: number, tierCount: number): Saved
	if type(data) ~= "table" then
		return { schemaVersion = SaveRules.SCHEMA_VERSION, coins = 0, tier = 1, pastries = 0 }
	end
	return {
		schemaVersion = SaveRules.SCHEMA_VERSION,
		coins = whole(data.coins, 0, maxCoins, 0),
		tier = whole(data.tier, 1, tierCount, 1),
		pastries = whole(data.pastries, 0, 1_000_000, 0),
	}
end

-- Builds the record to save from the server's current state.
function SaveRules.fromState(state: { coins: number, tier: number, pastries: number }): Saved
	return {
		schemaVersion = SaveRules.SCHEMA_VERSION,
		coins = state.coins,
		tier = state.tier,
		pastries = state.pastries,
	}
end

function SaveRules.defaults(): Saved
	return SaveRules.sanitize(nil, BakeConfig.maxCoins, #BakeConfig.tiers)
end

return SaveRules
