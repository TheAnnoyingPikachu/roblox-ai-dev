--!strict
-- Minimal dependency-free test framework for Lune. Records every result so the
-- runner can emit machine-readable evidence.

local Framework = {}

export type Result = { suite: string, name: string, passed: boolean, error: string? }

local results: { Result } = {}
local currentSuite = ""

function Framework.describe(name: string, body: () -> ())
	local previous = currentSuite
	currentSuite = if previous == "" then name else `{previous} > {name}`
	body()
	currentSuite = previous
end

function Framework.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	table.insert(results, {
		suite = currentSuite,
		name = name,
		passed = ok,
		error = if ok then nil else tostring(err),
	})
end

local function fail(message: string)
	error(message, 3)
end

function Framework.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {tostring(expected)}, got {tostring(actual)}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`expected nil, got {tostring(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected truthy, got {tostring(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected falsy, got {tostring(actual)}`)
			end
		end,
	}
end

function Framework.results(): { Result }
	return results
end

return Framework
