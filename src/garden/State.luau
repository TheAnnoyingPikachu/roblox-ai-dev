--!strict
-- The single mutable live state (docs/architecture/garden.md 4.1). Saved state lives in Profiles;
-- this holds only what is never saved: plot, pad pending coins and per-session caches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenRules = require(Shared:WaitForChild("GardenRules"))

export type Live = {
	plot: number,
	pads: GardenRules.Pads, -- pad index -> pending coins (float)
	lastRequest: number, -- os.clock() of the last accepted request or prompt (0.35 s limit)
	inside: { [number]: number }, -- plot -> seconds this player has been inside it while disallowed
	friends: { [number]: boolean }, -- IsFriendsWith cache by owner UserId
	boardIncome: number, -- last floor(income) written to GardenIncome
	boardAt: number, -- os.time() of that write
}

local State = {
	live = {} :: { [Player]: Live },
}

return State
