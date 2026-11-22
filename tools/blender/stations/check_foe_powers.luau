-- Runs every enemy power move in src/stations-client/FoePowers through its whole clip on Lune's Roblox instances
-- (their properties checked against the API), with a stand-in enemy, team and allies, and reports any error, any NaN or
-- bad size on a part, and the most parts a move draws in a frame. Not in CI (it stands in for parts of Roblox).
-- From the repo's root: lune run tools/blender/stations/check_foe_powers
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local CF, V3 = roblox.CFrame, roblox.Vector3

-- a seeded generator with Roblox's Random methods
local function newRandom(seed: number?)
	local s = math.floor((seed or 1) * 7919) % 2147483647
	if s <= 0 then
		s = 1
	end
	local function nxt()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
	return {
		NextNumber = function(_, a: number?, b: number?)
			local lo, hi = a or 0, b or 1
			return lo + (hi - lo) * nxt()
		end,
	}
end

local workspace = roblox.Instance.new("Workspace")
local warnings = {}
local collection = {
	GetTags = function()
		return {}
	end,
	RemoveTag = function() end,
}
local Anchors = luau.load(fs.readFile("src/stations-client/FoeAnchors.luau"), { debugName = "FoeAnchors" })()
local FoePowers = luau.load(fs.readFile("src/stations-client/FoePowers.luau"), {
	debugName = "FoePowers",
	environment = {
		Vector3 = V3,
		Color3 = roblox.Color3,
		CFrame = CF,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		Random = { new = newRandom },
		game = {
			GetService = function(_, name)
				return if name == "Workspace" then workspace else collection
			end,
		},
		script = { Parent = {
			WaitForChild = function()
				return {}
			end,
		} },
		require = function()
			return Anchors
		end,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
	},
})()

-- what Lune's instances lack
roblox.implementMethod("Model", "GetScale", function()
	return 1
end)
roblox.implementMethod("Model", "GetExtentsSize", function(self)
	return self:FindFirstChild("Hit").Size
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	return self.PrimaryPart.CFrame
end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	self.PrimaryPart.CFrame = cf
end)

local show = roblox.Instance.new("Folder")
-- a creature standing at (x, 0, z) looking along `look`, its Hit box w x h x d
local function standIn(asset: string, side: number, slot: number, at: any, look: any, size: any)
	local model = roblox.Instance.new("Model")
	local root = roblox.Instance.new("Part")
	root.Name = "Root"
	root.CFrame = CF.lookAt(at, at + look)
	root.Parent = model
	model.PrimaryPart = root
	local hit = roblox.Instance.new("Part")
	hit.Name, hit.Size, hit.CFrame = "Hit", size, root.CFrame * CF.new(0, size.Y / 2, 0)
	hit.Parent = model
	local mesh = roblox.Instance.new("MeshPart")
	mesh.Parent = model
	model:SetAttribute("Asset", asset)
	model:SetAttribute("Side", side)
	model:SetAttribute("Slot", slot)
	model.Parent = show
	return model
end

-- the team: four animals in a row 30 studs ahead (towards -z)
for i = 1, 4 do
	standIn("creature_rhino_forge", 1, i, V3.new((i - 2.5) * 9, 0, -30), V3.new(0, 0, 1), V3.new(5, 6, 9))
end
-- the enemy's allies (healed or raised)
for i = 2, 4 do
	standIn("foe_knight_forge", 2, i, V3.new((i - 3) * 9, 0, 8), V3.new(0, 0, -1), V3.new(3, 7, 3))
end

local failed = false
for asset, anchors in Anchors do
	local foe = standIn(asset, 2, 1, V3.zero, V3.new(0, 0, -1), V3.new(8, 10, 12))
	-- its bones: each anchor's bone 4 studs up, posed as at rest
	local bones = { head = { bone = { WorldCFrame = CF.new(0, 8, -4), TransformedWorldCFrame = CF.new(0, 8, -4) } } }
	for _, a in anchors do
		local cf = CF.new(0, 4, 0)
		bones[a[1]] = { bone = { WorldCFrame = cf, TransformedWorldCFrame = cf, Transform = CF.identity } }
	end
	for _, named in { "1", "1,2,3,4", "" } do -- one animal, all four, and nothing named (it aims ahead)
		local aim = if named ~= "" then named else nil
		foe:SetAttribute("PowerAim", aim)
		foe:SetAttribute("PowerAllies", if aim then "2,3,4" else nil)
		table.clear(warnings)
		local most, at = 0, if aim == "1" then 1 elseif aim then 2 else 3
		for f = 0, 2.4 * 60 do
			FoePowers.step(foe, bones, "magic", at, f / 60)
			local n = 0
			for _, p in workspace:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					n += 1
					local s, pos = p.Size, p.CFrame.Position
					for _, v in { s.X, s.Y, s.Z, pos.X, pos.Y, pos.Z } do
						if v ~= v or math.abs(v) > 1e4 then
							table.insert(warnings, `bad part at {f / 60}s: size {s} at {pos}`)
						end
					end
				end
			end
			most = math.max(most, n)
		end
		FoePowers.step(foe, bones, "idle", at, 0)
		local left = #workspace:GetChildren()
		if left > 0 then
			table.insert(warnings, `{left} left in the workspace after it stopped`)
		end
		print(`{asset} aim {aim or "-"}: most parts {most}{if #warnings > 0 then " FAIL" else ""}`)
		for i = 1, math.min(3, #warnings) do
			print("  " .. warnings[i])
			failed = true
		end
	end
	foe.Parent = nil
end
print(if failed then "FAILED" else "all moves ran")
