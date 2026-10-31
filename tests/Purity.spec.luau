--!strict
-- CLAUDE.md rule 5 as a test: src/shared and src/kit hold pure modules only, so Lune can run them.
-- Fails if a module there uses a Roblox global. Comments are ignored.
local fs = require("@lune/fs")
local T = require("./framework")

local describe, it, expect = T.describe, T.it, T.expect

local FORBIDDEN = {
	{ "game", "%f[%w_]game%s*[:%.]" },
	{ "workspace", "%f[%w_]workspace%f[^%w_]" },
	{ "script", "%f[%w_]script%s*[:%.]" },
	{ "Instance.new", "%f[%w_]Instance%s*%.%s*new" },
	{ "Enum", "%f[%w_]Enum%s*%." },
	{ "task library", "%f[%w_]task%s*%.%s*[%a_]+%s*%(" },
	{ "wait()", "%f[%w_.:]wait%s*%(" },
	{ "Roblox datatypes", "%f[%w_](Vector3|CFrame|Color3|UDim2)%s*%." },
}

local function code(source: string): string
	local lines = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(lines, (string.gsub(line, "%-%-.*$", "")))
	end
	return table.concat(lines, "\n")
end

local function scan(dir: string): { string }
	local problems = {}
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isFile(path) and string.match(name, "%.luau$") then
			local body = code(fs.readFile(path))
			for _, rule in FORBIDDEN do
				-- Lua patterns have no alternation: split "(A|B)" rules into one pattern each.
				local label, pattern = rule[1], rule[2]
				local alts = string.match(pattern, "%((.-)%)")
				local patterns = {}
				if alts and string.find(alts, "|", 1, true) then
					for alt in string.gmatch(alts, "[^|]+") do
						table.insert(patterns, (string.gsub(pattern, "%(.-%)", alt, 1)))
					end
				else
					table.insert(patterns, pattern)
				end
				for _, p in patterns do
					if string.find(body, p) then
						table.insert(problems, `{path}: uses {label}`)
						break
					end
				end
			end
		end
	end
	return problems
end

describe("Purity", function()
	for _, dir in { "src/shared", "src/kit" } do
		it(`{dir} has no Roblox API calls`, function()
			local problems = scan(dir)
			if #problems > 0 then
				error(table.concat(problems, "; "))
			end
			expect(#problems).toBe(0)
		end)
	end
end)
