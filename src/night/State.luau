--!strict
-- The single mutable server state (docs/architecture/night.md 4.1). Every module reads
-- `State.run` and assigns the value RunRules returns; nothing else holds run state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local RunRules = require(Shared:WaitForChild("RunRules"))

type State = {
	run: RunRules.Run,
	positions: { [number]: CombatRules.Vec3 }, -- participant roots by UserId, sampled at 10 Hz
	nextProjectile: number, -- shared id counter for fireballs and foxfire bolts
}

local State: State = {
	run = RunRules.new(),
	positions = {},
	nextProjectile = 0,
}

return State
