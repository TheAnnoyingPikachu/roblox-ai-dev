--!strict
-- src/shared/NightAssets.luau is generated from tools/blender/night/manifest.json; this keeps the
-- two in step (run tools/blender/write-assets-module.mjs night after a build or an upload).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local T = require("./framework")
local NightAssets = require("../src/shared/NightAssets")

local describe, it, expect = T.describe, T.it, T.expect

local manifest = serde.decode("json", fs.readFile("tools/blender/night/manifest.json"))

describe("NightAssets", function()
	it("has exactly the manifest's assets, sizes and mesh parts", function()
		local count = 0
		for name, entry in manifest do
			count += 1
			local asset = NightAssets[name]
			expect(asset == nil).toBe(false)
			for i = 1, 3 do
				expect(asset.size[i]).toBe(entry.size_studs[i])
			end
			local parts = 0
			for _, part in asset.parts do
				parts += 1
				expect(entry.parts[part] == nil).toBe(false)
			end
			local expected = 0
			for _ in entry.parts do
				expected += 1
			end
			expect(parts).toBe(expected)
		end
		local total = 0
		for _ in NightAssets do
			total += 1
		end
		expect(total).toBe(count)
	end)

	it("uses positive whole asset ids or nil, and a texture only with a model", function()
		for _, asset in NightAssets do
			for _, id in { asset.model, asset.decal, asset.texture } do
				expect(id == nil or (id > 0 and id == math.floor(id))).toBe(true)
			end
			if asset.model == nil then
				expect(asset.decal).toBeNil()
				expect(asset.texture).toBeNil()
			end
		end
	end)
end)
