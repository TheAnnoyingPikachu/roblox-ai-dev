--!strict
-- Bake Rush input. The client only asks; the server decides every outcome.
-- Placeholder controls for the pilot: E bakes, Q sells, F upgrades.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local bake = remotes:WaitForChild("Bake") :: RemoteEvent
local sell = remotes:WaitForChild("Sell") :: RemoteEvent
local upgrade = remotes:WaitForChild("Upgrade") :: RemoteEvent

local function bind(name: string, remote: RemoteEvent, key: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			remote:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, key)
end

bind("BakePastry", bake, Enum.KeyCode.E)
bind("SellPastries", sell, Enum.KeyCode.Q)
bind("UpgradeOven", upgrade, Enum.KeyCode.F)
