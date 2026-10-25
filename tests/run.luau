--!strict
-- Headless test runner: `lune run tests/run`.
-- Writes test-results.json (machine-readable evidence) and exits 1 on any failure.
-- Every *.spec.luau in tests/ must be listed in SPECS, so a spec can't be skipped silently.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SPECS = {
	["RewardRules.spec.luau"] = function()
		require("./RewardRules.spec")
	end,
	["BakeRules.spec.luau"] = function()
		require("./BakeRules.spec")
	end,
	["SaveRules.spec.luau"] = function()
		require("./SaveRules.spec")
	end,
	["RelayRules.spec.luau"] = function()
		require("./RelayRules.spec")
	end,
	["StyleRules.spec.luau"] = function()
		require("./StyleRules.spec")
	end,
}

local T = require("./framework")

local unlisted = {}
for _, file in fs.readDir("tests") do
	if string.match(file, "%.spec%.luau$") and SPECS[file] == nil then
		table.insert(unlisted, file)
	end
end
if #unlisted > 0 then
	print(`ERROR: spec files not registered in tests/run.luau: {table.concat(unlisted, ", ")}`)
	process.exit(1)
end

local loadErrors = {}
for file, load in SPECS do
	local ok, err = pcall(load)
	if not ok then
		table.insert(loadErrors, `{file}: {err}`)
	end
end

local results = T.results()
local failed = 0
for _, result in results do
	if result.passed then
		print(`  PASS  {result.suite} > {result.name}`)
	else
		failed += 1
		print(`  FAIL  {result.suite} > {result.name}\n        {result.error}`)
	end
end
for _, err in loadErrors do
	print(`  ERROR {err}`)
end

local total = #results
print(`\n{total - failed}/{total} passed, {failed} failed, {#loadErrors} load errors`)

fs.writeFile(
	"test-results.json",
	serde.encode("json", {
		total = total,
		passed = total - failed,
		failed = failed,
		loadErrors = loadErrors,
		results = results,
	}, true)
)

if failed > 0 or #loadErrors > 0 or total == 0 then
	process.exit(1)
end
