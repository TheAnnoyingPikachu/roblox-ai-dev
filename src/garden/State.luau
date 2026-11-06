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
	visits: { [number]: boolean }, -- own pads already counted as a collect during the current visit
	friends: { [number]: boolean }, -- IsFriendsWith cache by owner UserId
	boardIncome: number, -- last floor(income) written to GardenIncome
	boardAt: number, -- os.time() of that write
	nameAt: number, -- os.clock() of the last naming (10 s cooldown, V5)
	renames: { [number]: { day: number, count: number } }, -- creature id -> renames today (filter budget)
	declined: { [number]: number }, -- UserId -> os.time() that player last declined or cancelled a trade with us
}

local State = {
	live = {} :: { [Player]: Live },
}

return State
