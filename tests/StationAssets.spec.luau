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
			expect(asset.lift or 0).toBe(entry.lift or 0)
			for part, j in asset.joints do
				-- a skinned model's joints are bones in its one mesh (decision 0102), not meshes of their own
				expect(asset.centres[part] == nil).toBe(asset.skinned == true)
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
			-- Ranch.luau sizes the eggs by their shell (World's EGG_BUILT); a crown or a horn on top may stand up to 4.5
			-- (decision 0110: the Crown Egg's crown)
			expect(asset.size[2] >= 3 and asset.size[2] <= 4.5).toBeTruthy()
		end
	end)

	it("has a still model for every piece of the hub's centre that World.luau stands there", function()
		local pieces = 0
		for name in string.gmatch(fs.readFile("src/stations/World.luau"), '"(hub_[%w_]+)"') do
			pieces += 1
			local asset = StationAssets[name]
			expect(asset == nil).toBe(false)
			expect(asset.model == nil).toBe(false) -- uploaded
			expect(table.find(asset.parts, `{name}_body`) == nil).toBe(false)
			expect(count(asset.joints)).toBe(0)
			for _, tris in manifest[name].parts do
				expect(tris <= 20000).toBeTruthy()
			end
		end
		expect(pieces).toBe(8)
		for name in manifest do -- and nothing is built for the hub that is not used
			if string.sub(name, 1, 4) == "hub_" then
				pieces -= 1
			end
		end
		expect(pieces).toBe(0)
	end)

	it("has models for every station's training area at every Training Grounds level", function()
		local levels = #(StationConfig.upgrade("grounds") :: StationConfig.Upgrade).levels
		local known = 0
		for _, st in StationConfig.STATIONS do
			local shown = table.create(levels + 1, 0)
			for name, asset in StationAssets do
				local station, first, last = string.match(name, "^area_(%a+)_(%d)_(%d)$")
				if station == st.id then
					known += 1
					expect(asset.model == nil).toBe(false) -- uploaded
					expect(table.find(asset.parts, `{name}_body`) == nil).toBe(false)
					expect(count(asset.joints)).toBe(0)
					expect((tonumber(last) :: number) <= levels).toBeTruthy()
					for level = tonumber(first) :: number, tonumber(last) :: number do
						shown[level + 1] += 1
					end
					for _, tris in manifest[name].parts do
						expect(tris <= 20000).toBeTruthy()
					end
				end
			end
			for level = 0, levels do
				expect(shown[level + 1] > 0).toBeTruthy()
			end
		end
		for name in manifest do -- and every area's model belongs to a station
			if string.sub(name, 1, 5) == "area_" then
				known -= 1
			end
		end
		expect(known).toBe(0)
	end)

	it("has a model for every piece of moving kit that Areas.luau stands", function()
		local used: { [string]: boolean } = {}
		for name in string.gmatch(fs.readFile("src/stations/Areas.luau"), '"(kit_[%w_]+)"') do
			used[name] = true
			local asset = StationAssets[name]
			expect(asset == nil).toBe(false)
			expect(asset.model == nil).toBe(false) -- uploaded
			expect(table.find(asset.parts, `{name}_body`) == nil).toBe(false)
			expect(count(asset.joints)).toBe(0)
		end
		expect(count(used)).toBe(3)
		for name in manifest do -- and no kit is built that is not stood
			if string.sub(name, 1, 4) == "kit_" then
				expect(used[name]).toBe(true)
			end
		end
	end)

	it("has three looks of a model for every ranch upgrade's building, and no other homestead model", function()
		local looks: { [string]: boolean } = {}
		for _, u in StationConfig.UPGRADES do
			if u.id ~= "grounds" then -- the Training Grounds are the six areas
				for look = 1, 3 do
					local name = `home_{u.id}_{look}`
					looks[name] = true
					local asset = StationAssets[name]
					expect(asset == nil).toBe(false)
					expect(table.find(asset.parts, `{name}_body`) == nil).toBe(false)
					expect(count(asset.joints)).toBe(0)
				end
			end
		end
		expect(count(looks)).toBe(24)
		for name in manifest do
			if string.sub(name, 1, 5) == "home_" then
				expect(looks[name]).toBe(true)
			end
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
		for id in StationRules.FORGE do -- the jointed model a ForgeGUI one replaced keeps its coat as the fallback
			local word, s = string.match(id, "^(%l+)_(%l+)$") -- a variant's id is "<word>_<species>"
			local old = StationAssets[if word then `creature_{s}_{word}` else `creature_{id}`] -- none for a new variety
			coats += if old and old.rainbowDecal then 1 else 0
		end
		expect(coats).toBe(0)
	end)

	it("keeps every creature a jointed body under 20,000 triangles a mesh", function()
		for name, entry in manifest do
			local kind = string.sub(name, 1, 4)
			if
				kind == "egg_"
				or kind == "hub_"
				or kind == "area"
				or kind == "kit_"
				or kind == "home"
				or kind == "scen"
			then
				continue -- scenery_: still props (decision 0085)
			end
			for _, piece in { "body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail" } do
				-- a skinned model is one mesh: its pieces are bones, named by its joints (decision 0102)
				local here = if entry.skinned
					then piece == "body" or entry.joints[`{name}_{piece}`] ~= nil
					else entry.parts[`{name}_{piece}`] ~= nil
				expect(here).toBe(true)
			end
			for _, tris in entry.parts do
				expect(tris <= 20000).toBeTruthy()
			end
			-- every piece but the body turns on a joint; a dragon's two wings are two more. A held weapon's
			-- "tip" and "neck" bones (for its trail) ride on its arm and do not count, nor do an arm's elbow bones,
			-- nor the more a chain has (the Dark Drake's neck base, jaw, wing hands and its tail's middle and end)
			local turning = 0
			for part in entry.joints do
				if
					string.find(part, "_tip$") == nil
					and string.find(part, "_neck$") == nil
					and string.find(part, "_elbow_[lr]$") == nil
					and string.find(part, "_arrow$") == nil -- (nor a stowed arrow's)
					and string.find(part, "_neck_base$") == nil
					and string.find(part, "_jaw$") == nil
					and string.find(part, "_hand_[lr]$") == nil
					and string.find(part, "_tail_mid$") == nil
					and string.find(part, "_tail_end$") == nil
					and string.find(part, "_weapon$") == nil -- (nor a weapon turning in its fist)
				then
					turning += 1
				end
			end
			expect(turning).toBe(if string.find(name, "^foe_dragon") then 8 else 6)
		end
	end)

	it("has a model for every Hexbound foe, of its kind, with a sane size and tint", function()
		for _, f in StationConfig.FOES do
			-- SHANNON's ForgeGUI model of its kind (decision 0104)
			expect(string.find(f.model, `^foe_{f.kind}`) ~= nil and string.find(f.model, "_forge$") ~= nil).toBe(true)
			expect(StationAssets[f.model] == nil).toBe(false)
			expect(StationAssets[f.model].model == nil).toBe(false) -- uploaded
			expect(f.size == nil or f.size >= 0.5).toBeTruthy()
			-- as big as it likes, but its wings pass the arena gate's 42-stud opening (Arena.luau)
			expect(StationAssets[f.model].size[1] * (f.size or 1) <= 42).toBe(true)
			if f.tint then
				expect(#f.tint).toBe(3)
				for _, c in f.tint do
					expect(c >= 0 and c <= 255).toBeTruthy()
				end
			end
		end
		for _, kind in StationConfig.FOE_KINDS do -- every kind has an enemy
			local any = false
			for _, f in StationConfig.FOES do
				any = any or f.kind == kind
			end
			expect(any).toBe(true)
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
