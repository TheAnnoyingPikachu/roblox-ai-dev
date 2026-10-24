--!strict
-- Client entry point. The client only asks; the server decides the outcome.
-- Placeholder input: press E to request a claim from the starter pad.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestClaim = remotes:WaitForChild("RequestClaim") :: RemoteEvent

ContextActionService:BindAction("ClaimReward", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		requestClaim:FireServer({ sourceId = "starter_pad" })
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
