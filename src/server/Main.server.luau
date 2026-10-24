--!strict
-- Server entry point: starts each service. Bake Rush owns its remotes and leaderstats.

local BakeService = require(script.Parent:WaitForChild("services"):WaitForChild("BakeService"))

BakeService.start()
