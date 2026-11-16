--!strict
-- src/shared/StationAssets.luau is generated from tools/blender/stations/manifest.json; this keeps
-- the two in step (run tools/blender/write-assets-module.mjs stations after a build or an upload).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local T = require("./framework")
local StationAssets = require("../src/shared/StationAssets")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")

local describe, it, expect = T.describe, T.it, T.expect

local manifest = serde.decode("json", fs.readFile("tools/blender/stations/manifest.json"))

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

describe("StationAssets", function()
	it("has exactly the manifest's assets, sizes, mesh parts and glow colours", function()
		for name, entry in manifest do
			local asset = StationAssets[name]
			expect(asset == nil).toBe(false)
			for i = 1, 3 do
				expect(asset.size[i]).toBe(entry.size_studs[i])
			end
			for _, part in asset.parts do
				expect(entry.parts[part] == nil).toBe(false)
			end
			expect(#asset.parts).toBe(count(entry.parts))
			expect(count(asset.glow)).toBe(count(entry.glow))
			for part in asset.glow do
				expect(entry.parts[part] == nil).toBe(false)
			end
		end
		expect(count(StationAssets)).toBe(count(manifest))
	end)

	it("has a centre for every mesh and a joint for every moving piece, as in the manifest", function()
		for name, entry in manifest do
			local asset = StationAssets[name]
			expect(count(asset.centres)).toBe(#asset.parts)
			for part, c in asset.centres do
				for i = 1, 3 do
					expect(c[i]).toBe(entry.centres[part][i])
				end
			end
			expect(count(asset.joints)).toBe(count(entry.joints))
			for part, j in asset.joints do
				expect(asset.centres[part] == nil).toBe(false)
				for i = 1, 3 do
					expect(j[i]).toBe(entry.joints[part][i])
				end
			end
		end
	end)

	it("has a still model for every egg: one painted piece, no joints", function()
		for _, egg in StationConfig.EGGS do
			local name = `egg_{egg.id}`
			local asset = StationAssets[name]
			expect(asset == nil).toBe(false)
			expect(asset.model == nil).toBe(false) -- uploaded
			expect(table.find(asset.parts, `{name}_body`) == nil).toBe(false)
			expect(asset.glow[`{name}_body`]).toBeNil()
			expect(count(asset.joints)).toBe(0)
			expect(asset.size[2] >= 3 and asset.size[2] <= 3.6).toBeTruthy() -- Ranch.luau sizes the eggs by this
		end
	end)

	it("has a rainbow coat for every animal and variant, and for nothing else", function()
		local coats = 0
		for _, sp in StationConfig.SPECIES do
			coats += 1
			expect(StationAssets[StationRules.assetOf(sp.id, nil)].rainbowDecal == nil).toBe(false)
			for _, va in sp.variants do
				coats += 1
				expect(StationAssets[StationRules.assetOf(sp.id, va.id)].rainbowDecal == nil).toBe(false)
			end
		end
		for _, asset in StationAssets do
			coats -= if asset.rainbowDecal then 1 else 0
		end
		expect(coats).toBe(0)
	end)

	it("keeps every creature a jointed body under 20,000 triangles a mesh", function()
		for name, entry in manifest do
			if string.sub(name, 1, 4) == "egg_" then
				continue
			end
			for _, piece in { "body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail" } do
				expect(entry.parts[`{name}_{piece}`] == nil).toBe(false)
			end
			for _, tris in entry.parts do
				expect(tris <= 20000).toBeTruthy()
			end
			-- every piece but the body turns on a joint; a dragon's two wings are two more
			expect(count(entry.joints)).toBe(if name == "foe_dragon" then 8 else 6)
		end
	end)

	it("has a model for every Hexbound foe, of its kind, with a sane size and tint", function()
		for _, f in StationConfig.FOES do
			expect(f.model).toBe(`foe_{f.kind}`)
			expect(StationAssets[f.model] == nil).toBe(false)
			expect(StationAssets[f.model].model == nil).toBe(false) -- uploaded
			expect(f.size == nil or (f.size >= 0.5 and f.size <= 2)).toBeTruthy()
			if f.tint then
				expect(#f.tint).toBe(3)
				for _, c in f.tint do
					expect(c >= 0 and c <= 255).toBeTruthy()
				end
			end
		end
		for _, kind in StationConfig.FOE_KINDS do
			expect(StationAssets[`foe_{kind}`] == nil).toBe(false)
		end
	end)

	it("names the model of every animal and variant, and it is in the asset table", function()
		for _, sp in StationConfig.SPECIES do
			expect(StationAssets[StationRules.assetOf(sp.id, nil)] == nil).toBe(false)
			for _, va in sp.variants do
				expect(StationAssets[StationRules.assetOf(sp.id, va.id)] == nil).toBe(false)
			end
		end
	end)
end)
