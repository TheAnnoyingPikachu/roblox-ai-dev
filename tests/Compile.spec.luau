--!strict
-- Every script under src compiles (decision 0121): Studio refuses a script over Luau's 200 locals in one
-- function, and CI otherwise only lints and tests the shared modules.
local T = require("./framework")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local describe, it, expect = T.describe, T.it, T.expect

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

describe("Every script compiles", function()
	it("compiles each .luau file under src", function()
		local bad = {}
		local files = walk("src", {})
		for _, path in files do
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				table.insert(bad, `{path}: {err}`)
			end
		end
		if #bad > 0 then
			print(table.concat(bad, "\n"))
		end
		expect(#files > 100).toBeTruthy()
		expect(#bad).toBe(0)
	end)
end)
