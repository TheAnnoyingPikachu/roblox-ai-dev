--!strict
-- Live tuning (decision 0131, SHANNON's Round 2 build 8 A): a short list of values SHANNON can change on live servers
-- from the Creator Hub's Configs page (ConfigService), each kept inside a range approved once. The server reads them
-- (LiveConfig.server) and hands them to every client through ReplicatedStorage attributes; both sides call `apply`,
-- so the shared rules (prices, pay, hatch times) agree. Pure: no Roblox APIs.

local LevelRules = require("./LevelRules")
local StationConfig = require("./StationConfig")
local StationProgress = require("./StationProgress")

local LiveTuning = {}

export type Key = { default: number, min: number, max: number, set: (v: number) -> () }

-- every egg's price as built, so a multiplier is always of the original
local basePrice: { [string]: number } = {}
for _, e in StationConfig.EGGS do
	basePrice[e.id] = e.price
end

LiveTuning.KEYS = {
	-- a replayed wave's pay, percent of its first clear (decision 0121: 40)
	replayPct = {
		default = LevelRules.REPLAY_PCT,
		min = 25,
		max = 60,
		set = function(v)
			LevelRules.REPLAY_PCT = math.floor(v)
		end,
	},
	-- an event: wave coins times this (1 = no event)
	coinBoost = {
		default = 1,
		min = 1,
		max = 3,
		set = function(v)
			LevelRules.COIN_BOOST = v
		end,
	},
	-- every egg's price times this
	eggPrice = {
		default = 1,
		min = 0.5,
		max = 2,
		set = function(v)
			for _, e in StationConfig.EGGS do
				(e :: any).price = math.max(1, math.floor(basePrice[e.id] * v + 0.5))
			end
		end,
	},
	-- every egg's hatch time times this (0.5 = twice as fast)
	hatchTime = {
		default = 1,
		min = 0.25,
		max = 1,
		set = function(v)
			StationProgress.HATCH_MULT = v
		end,
	},
} :: { [string]: Key }

-- A value as it will be used: a number inside its key's range, or the default for anything else.
function LiveTuning.clamp(key: string, value: any): number
	local k = LiveTuning.KEYS[key]
	if k == nil then
		return 0
	elseif type(value) ~= "number" or value ~= value then
		return k.default
	end
	return math.clamp(value, k.min, k.max)
end

-- Apply `values` (key -> raw value; a missing key goes back to its default). Returns what was applied.
function LiveTuning.apply(values: { [string]: any }): { [string]: number }
	local used = {}
	for key, k in LiveTuning.KEYS do
		local v = if values[key] == nil then k.default else LiveTuning.clamp(key, values[key])
		k.set(v)
		used[key] = v
	end
	return used
end

return LiveTuning
