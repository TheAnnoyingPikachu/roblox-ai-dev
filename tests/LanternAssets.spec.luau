--!strict
-- src/shared/LanternAssets.luau is generated from tools/blender/lantern/manifest.json (run
-- tools/blender/write-assets-module.mjs lantern after a build or an upload); architecture lantern 8.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local T = require("./framework")
local GardenAssets = require("../src/shared/GardenAssets")
local LanternAssets = require("../src/shared/LanternAssets")
local NightAssets = require("../src/shared/NightAssets")

local describe, it, expect = T.describe, T.it, T.expect

local manifest = serde.decode("json", fs.readFile("tools/blender/lantern/manifest.json"))

describe("LanternAssets", function()
	it("has exactly the manifest's assets, sizes and mesh parts", function()
		local count = 0
		for name, entry in manifest do
			count += 1
			local asset = LanternAssets[name]
			expect(asset == nil).toBe(false)
			for i = 1, 3 do
				expect(asset.size[i]).toBe(entry.size_studs[i])
			end
			for _, part in asset.parts do
				expect(entry.parts[part] == nil).toBe(false)
			end
		end
		local total = 0
		for _ in LanternAssets do
			total += 1
		end
		expect(total).toBe(count)
	end)

	it("shares no name with Night or Garden (Models.luau looks them up in one table)", function()
		for name in LanternAssets do
			expect(NightAssets[name]).toBeNil()
			expect(GardenAssets[name]).toBeNil()
		end
	end)

	it("keeps critters 2.0 to 3.5 tall within 3 x 3 and every tile 120 x 160 within 2%", function()
		for name, asset in LanternAssets do
			if string.sub(name, 1, 8) == "critter_" then
				expect(asset.size[2] >= 2 and asset.size[2] <= 3.5).toBe(true)
				expect(asset.size[1] <= 3 and asset.size[3] <= 3).toBe(true)
			elseif string.sub(name, 1, 5) == "stop_" then
				expect(math.abs(asset.size[1] - 120) <= 2.4).toBe(true)
				expect(math.abs(asset.size[3] - 160) <= 3.2).toBe(true)
			end
		end
	end)

	it("gives a model id only to assets with a height, as positive whole ids", function()
		for _, asset in LanternAssets do
			for _, id in { asset.model, asset.decal, asset.texture } do
				expect(id == nil or (id > 0 and id == math.floor(id))).toBe(true)
			end
			if asset.model ~= nil then
				expect(asset.size[2] > 0).toBe(true)
			end
		end
	end)
end)
