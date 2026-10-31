-- lune run tools/place-check/check <place.rbxl> <expectations.json> [sha]
-- Checks a built place file before it is uploaded. Prints the result as JSON; exits 1 on problems.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local check = require("./checker")

local placeFile, specFile, sha = process.args[1], process.args[2], process.args[3]
if placeFile == nil or specFile == nil then
	print("usage: lune run tools/place-check/check <place.rbxl> <expectations.json> [sha]")
	process.exit(2)
end
local game = roblox.deserializePlace(fs.readFile(placeFile))
local result = check(game, serde.decode("json", fs.readFile(specFile)), if sha == "" then nil else sha)
print(serde.encode("json", result, true))
if not result.ok then
	process.exit(1)
end
