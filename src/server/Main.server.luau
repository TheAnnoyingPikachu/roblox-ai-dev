--!strict
-- Server entry point: starts each service. Saves reach BakeService only through its
-- restore and getState functions, so the two services don't share state directly.

local services = script.Parent:WaitForChild("services")
local BakeService = require(services:WaitForChild("BakeService"))
local SaveService = require(services:WaitForChild("SaveService"))

BakeService.start()
SaveService.start(BakeService.restore, BakeService.getState, BakeService.release)
