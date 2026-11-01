--!strict
-- src/shared/GardenAssets.luau is generated from tools/blender/garden/manifest.json; this keeps the
-- two in step (run tools/blender/write-assets-module.mjs garden after a build or an upload).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local T = require("./framework")
local GardenAssets = require("../src/shared/GardenAssets")

local describe, it, expect = T.describe, T.it, T.expect

local manifest = serde.decode("json", fs.readFile("tools/blender/garden/manifest.json"))

describe("GardenAssets", function()
	it("has exactly the manifest's assets, sizes and mesh parts", function()
		local count = 0
		for name, entry in manifest do
			count += 1
			local asset = GardenAssets[name]
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
		for _ in GardenAssets do
			total += 1
		end
		expect(total).toBe(count)
	end)

	it("uses positive whole asset ids or nil, and a texture only with a model", function()
		for _, asset in GardenAssets do
			for _, id in { asset.model, asset.decal, asset.texture } do
				expect(id == nil or (id > 0 and id == math.floor(id))).toBe(true)
			end
			if asset.model == nil then
				expect(asset.decal).toBeNil()
				expect(asset.texture).toBeNil()
			end
		end
	end)

	-- docs/architecture/garden.md section 9: the loader drops pivots and Plots.egg keeps one MeshPart.
	it("keeps the section 9 sizes and one mesh for everything posed whole", function()
		local sizes: { [string]: { number? } } = {
			dash_sweeper = { 40 },
			dash_ball = { 10, 10, 10 },
			dash_pendulum = { 8, 30, 8 },
			dash_platform = { 12, 2, 12 },
			dash_arch = { 28, 18 },
			dash_ready_pad = { 12 },
			dash_island = { 300, nil, 160 },
		}
		for name, size in sizes do
			for axis = 1, 3 do
				local want = size[axis]
				if want then
					expect(math.abs(GardenAssets[name].size[axis] - want) <= want * 0.02).toBe(true)
				end
			end
		end
		for _, name in { "dash_sweeper", "dash_ball", "dash_pendulum", "dash_platform" } do
			expect(#GardenAssets[name].parts).toBe(1)
		end
		for name, asset in GardenAssets do
			if string.sub(name, 1, 4) == "egg_" then
				expect(#asset.parts).toBe(1)
				expect(asset.size[1] <= 2.8 and asset.size[2] <= 3.3 and asset.size[3] <= 2.8).toBe(true)
			end
		end
	end)
end)
