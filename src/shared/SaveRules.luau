--!strict
-- Pure save-data rules for Bake Rush. No Roblox APIs, so Lune can test them.
-- Stored data is untrusted when read back: every field is validated and clamped first.
-- The lock and version decisions are pure, so the save service only calls them.

local BakeConfig = require("./BakeConfig")
local BakeRules = require("./BakeRules")

local SaveRules = {}

SaveRules.SCHEMA_VERSION = 2
-- A session lock older than this may be taken over by another server (a crashed server).
SaveRules.LOCK_STALE_SECONDS = 300

export type Lock = {
	jobId: string,
	at: number,
}

export type Saved = {
	schemaVersion: number,
	coins: number,
	tier: number,
	pastries: number,
	saveCount: number,
	lock: Lock?,
}

local MAX_SAVE_COUNT = 1_000_000_000_000

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function whole(value: any, min: number, max: number, fallback: number): number
	if not isFinite(value) then
		return fallback
	end
	return math.clamp(math.floor(value), min, max)
end

local function readLock(value: any): Lock?
	if type(value) ~= "table" then
		return nil
	end
	if type(value.jobId) ~= "string" or #value.jobId == 0 or not isFinite(value.at) then
		return nil
	end
	return { jobId = value.jobId, at = value.at }
end

function SaveRules.defaults(): Saved
	return {
		schemaVersion = SaveRules.SCHEMA_VERSION,
		coins = 0,
		tier = 1,
		pastries = 0,
		saveCount = 0,
		lock = nil,
	}
end

-- Turns stored data into a safe record. Anything unusable falls back to a default.
function SaveRules.sanitize(data: any): Saved
	if type(data) ~= "table" then
		return SaveRules.defaults()
	end
	return {
		schemaVersion = SaveRules.SCHEMA_VERSION,
		coins = whole(data.coins, 0, BakeConfig.maxCoins, 0),
		tier = whole(data.tier, 1, #BakeConfig.tiers, 1),
		pastries = whole(data.pastries, 0, BakeConfig.maxPastries, 0),
		saveCount = whole(data.saveCount, 0, MAX_SAVE_COUNT, 0),
		lock = readLock(data.lock),
	}
end

-- Builds the record to store from the server's state, the save count, and the lock to hold.
function SaveRules.fromState(
	state: { coins: number, tier: number, pastries: number },
	saveCount: number,
	lock: Lock?
): Saved
	return {
		schemaVersion = SaveRules.SCHEMA_VERSION,
		coins = state.coins,
		tier = state.tier,
		pastries = state.pastries,
		saveCount = saveCount,
		lock = lock,
	}
end

-- Converts a stored record into the server's gameplay state.
function SaveRules.toState(saved: Saved): BakeRules.State
	return {
		coins = saved.coins,
		tier = saved.tier,
		pastries = saved.pastries,
		lastBakeAt = nil,
	}
end

-- Decides whether a server may take the session lock on load.
-- "locked" means another server holds a fresh lock, so this server must not load.
function SaveRules.decideClaim(existing: Saved?, jobId: string, now: number): "claim" | "locked"
	if existing == nil or existing.lock == nil then
		return "claim"
	end
	if existing.lock.jobId == jobId then
		return "claim"
	end
	if now - existing.lock.at >= SaveRules.LOCK_STALE_SECONDS then
		return "claim"
	end
	return "locked"
end

-- Decides whether a save may overwrite the stored record.
-- "reject" means another server has taken over, or stored data is newer than this server's copy.
function SaveRules.decideWrite(existing: Saved?, jobId: string, ourSaveCount: number): "write" | "reject"
	if existing == nil then
		return "write"
	end
	if existing.lock ~= nil and existing.lock.jobId ~= jobId then
		return "reject"
	end
	if existing.saveCount > ourSaveCount then
		return "reject"
	end
	return "write"
end

return SaveRules
