--!strict
-- Headless test runner: `lune run tests/run`.
-- Writes test-results.json (machine-readable evidence) and exits 1 on any failure.
-- Every *.spec.luau in tests/ must be listed in SPECS, so a spec can't be skipped silently.
--
-- Fast loop for one task: `lune run tests/run SaveStore Kit` runs only the specs whose file name
-- contains one of the arguments (a task file's `tests` list). CI always runs everything.

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
	["ProgressRules.spec.luau"] = function()
		require("./ProgressRules.spec")
	end,
	["Rng.spec.luau"] = function()
		require("./Rng.spec")
	end,
	["CombatRules.spec.luau"] = function()
		require("./CombatRules.spec")
	end,
	["WaveRules.spec.luau"] = function()
		require("./WaveRules.spec")
	end,
	["BossRules.spec.luau"] = function()
		require("./BossRules.spec")
	end,
	["BlessingRules.spec.luau"] = function()
		require("./BlessingRules.spec")
	end,
	["RunRules.spec.luau"] = function()
		require("./RunRules.spec")
	end,
	["MetaRules.spec.luau"] = function()
		require("./MetaRules.spec")
	end,
	["NightProgress.spec.luau"] = function()
		require("./NightProgress.spec")
	end,
	["GardenConfig.spec.luau"] = function()
		require("./GardenConfig.spec")
	end,
	["WorldRules.spec.luau"] = function()
		require("./WorldRules.spec")
	end,
	["GardenRules.spec.luau"] = function()
		require("./GardenRules.spec")
	end,
	["HatchRules.spec.luau"] = function()
		require("./HatchRules.spec")
	end,
	["GardenProgress.spec.luau"] = function()
		require("./GardenProgress.spec")
	end,
	["NightAssets.spec.luau"] = function()
		require("./NightAssets.spec")
	end,
	["GardenAssets.spec.luau"] = function()
		require("./GardenAssets.spec")
	end,
	["Kit.spec.luau"] = function()
		require("./Kit.spec")
	end,
	["SaveStore.spec.luau"] = function()
		require("./SaveStore.spec")
	end,
	["Purity.spec.luau"] = function()
		require("./Purity.spec")
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

local filters = process.args
local function selected(file: string): boolean
	if #filters == 0 then
		return true
	end
	for _, f in filters do
		if string.find(file, (string.gsub(f, "%.spec%.luau$", "")), 1, true) then
			return true
		end
	end
	return false
end

local loadErrors = {}
for file, load in SPECS do
	if not selected(file) then
		continue
	end
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
		-- Non-empty means a partial run: not valid as task evidence (CLAUDE.md rule 3).
		filters = filters,
		results = results,
	}, true)
)

if failed > 0 or #loadErrors > 0 or total == 0 then
	process.exit(1)
end
