--!strict
-- The single mutable live state (docs/architecture/spire.md 4.1). Saved state lives in Profiles;
-- this holds only what is never saved: the lot, the income fraction, the Request token bucket, the
-- Hot Data spark and per-session caches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpireProgress = require(Shared:WaitForChild("SpireProgress"))

export type Hot = { floor: number, slot: number, ends: number } -- ends = os.time() when it expires
export type Live = {
	lot: number,
	carry: number, -- income fraction (SpireEconomy.tick)
	bucket: SpireProgress.Bucket,
	hot: Hot?,
	nextHot: number, -- os.time() of the next spark
	friends: { [number]: boolean }, -- IsFriendsWith cache by UserId
	boardEarned: number, -- last value written to SpireBoard
	boardAt: number,
}

local State = {
	live = {} :: { [Player]: Live },
}

return State
