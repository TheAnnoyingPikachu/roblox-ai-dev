--!strict
-- Server entry point: creates the remotes folder, then starts each service.

local BakeService = require(script.Parent:WaitForChild("services"):WaitForChild("BakeService"))

BakeService.start()
