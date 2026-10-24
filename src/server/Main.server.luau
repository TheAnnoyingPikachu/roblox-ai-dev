--!strict
-- Server entry point: creates the remotes folder, then starts each service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local services = script.Parent:WaitForChild("services")
local RewardService = require(services:WaitForChild("RewardService"))

RewardService.start(remotes)
