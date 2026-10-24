--!strict
-- Pure, server-authoritative reward rules. No Roblox APIs and no requires, so the
-- same module runs inside Roblox and headless under Lune for unit tests.
-- The server owns every value here; the client may only ask for a claim.

local RewardRules = {}

export type Config = {
	rewardAmount: number,
	cooldownSeconds: number,
	maxClaimsPerWindow: number,
	windowSeconds: number,
	maxCoins: number,
}

export type PlayerState = {
	coins: number,
	lastClaimAt: number?,
	windowStart: number,
	claimsInWindow: number,
}

export type ClaimResult = {
	ok: boolean,
	reason: string?,
	awarded: number,
	state: PlayerState,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function RewardRules.newState(now: number): PlayerState
	return {
		coins = 0,
		lastClaimAt = nil,
		windowStart = now,
		claimsInWindow = 0,
	}
end

-- Returns whether a claim at `now` is allowed, and the rejection reason if not.
function RewardRules.canClaim(state: PlayerState, now: number, config: Config): (boolean, string?)
	if not isFiniteNumber(now) then
		return false, "invalid_time"
	end
	if state.lastClaimAt ~= nil and now - state.lastClaimAt < config.cooldownSeconds then
		return false, "cooldown"
	end
	local inWindow = now - state.windowStart < config.windowSeconds
	if inWindow and state.claimsInWindow >= config.maxClaimsPerWindow then
		return false, "rate_limited"
	end
	if state.coins + config.rewardAmount > config.maxCoins then
		return false, "balance_cap"
	end
	return true, nil
end

-- Applies a claim. Never mutates `state`; the caller stores the returned state.
function RewardRules.claim(state: PlayerState, now: number, config: Config): ClaimResult
	local allowed, reason = RewardRules.canClaim(state, now, config)
	if not allowed then
		return { ok = false, reason = reason, awarded = 0, state = state }
	end

	local windowStart = state.windowStart
	local claimsInWindow = state.claimsInWindow
	if now - windowStart >= config.windowSeconds then
		windowStart = now
		claimsInWindow = 0
	end

	return {
		ok = true,
		reason = nil,
		awarded = config.rewardAmount,
		state = {
			coins = state.coins + config.rewardAmount,
			lastClaimAt = now,
			windowStart = windowStart,
			claimsInWindow = claimsInWindow + 1,
		},
	}
end

-- Validates the untrusted payload of a claim request from the client.
-- The client sends only a source id; amounts and prices are never accepted from it.
function RewardRules.validateRequest(payload: any, allowedSources: { [string]: boolean }): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "bad_payload"
	end
	local sourceId = payload.sourceId
	if type(sourceId) ~= "string" or #sourceId == 0 or #sourceId > 32 then
		return false, "bad_source"
	end
	if not allowedSources[sourceId] then
		return false, "unknown_source"
	end
	for key in payload do
		if key ~= "sourceId" then
			return false, "unexpected_field"
		end
	end
	return true, nil
end

return RewardRules
