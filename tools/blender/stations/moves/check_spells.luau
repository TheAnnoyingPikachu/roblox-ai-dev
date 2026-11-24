-- Runs every spell in src/stations-client/Spells through its whole clip on Lune's Roblox instances (their properties
-- checked against the API), with stand-in models and bones, and reports any error, any NaN or bad size on a part, and
-- the most parts a spell draws in a frame. Not in CI (it needs no Studio, but stands in for parts of Roblox).
-- From the repo's root: lune run tools/blender/stations/moves/check_spells
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local REPO = "."
local DIR = REPO .. "/src/stations-client/Spells"

-- a seeded generator with Roblox's Random methods
local function newRandom(seed: number?)
	local s = math.floor((seed or 1) * 7919) % 2147483647
	if s <= 0 then
		s = 1
	end
	local r = {}
	local function nxt()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
	function r.NextNumber(_, a: number?, b: number?)
		local lo, hi = a or 0, b or 1
		return lo + (hi - lo) * nxt()
	end
	function r.NextInteger(_, a: number, b: number)
		return a + math.floor(nxt() * (b - a + 1))
	end
	return r
end

local workspace = roblox.Instance.new("Workspace")
local errors, warnings = {}, {}

local function env(extra: { [string]: any })
	local e = {
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		CFrame = roblox.CFrame,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		Random = { new = newRandom },
		math = math,
		table = table,
		string = string,
		typeof = roblox.typeof or typeof,
		type = type,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		select = select,
		error = error,
		assert = assert,
		pcall = pcall,
		tostring = tostring,
		tonumber = tonumber,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		print = print,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
	}
	for k, v in extra do
		e[k] = v
	end
	return e
end

-- the spell modules, as children of the Spells script
local children = {}
for _, name in fs.readDir(DIR) do
	if name ~= "init.luau" and string.sub(name, -5) == ".luau" then
		table.insert(children, { name = name, IsA = function(_, c)
			return c == "ModuleScript"
		end })
	end
end
local AnimalRig = luau.load(fs.readFile(REPO .. "/src/shared/AnimalRig.luau"), { debugName = "AnimalRig" })()
local shared = {
	WaitForChild = function(_, name)
		return { name = name }
	end,
}
local game = {
	GetService = function(_, name)
		if name == "Workspace" then
			return workspace
		end
		return { WaitForChild = function()
			return shared
		end }
	end,
}
local function myRequire(m)
	if m.name == "AnimalRig" then
		return AnimalRig
	end
	local src = fs.readFile(DIR .. "/" .. m.name)
	return luau.load(src, { debugName = m.name, environment = env({ game = game }) })()
end
local Spells = luau.load(fs.readFile(DIR .. "/init.luau"), {
	debugName = "Spells",
	environment = env({
		game = game,
		require = myRequire,
		script = { GetChildren = function()
			return children
		end },
	}),
})()

-- a stand-in model: a Root on the ground looking along -z, a head bone in it, bones at AnimalRig's joints, no pose
local function standIn(asset: string)
	local data = AnimalRig.MODELS[asset]
	local model = roblox.Instance.new("Model")
	local root = roblox.Instance.new("Part")
	root.Name = "Root"
	root.CFrame = roblox.CFrame.new(0, 0, 0)
	root.Parent = model
	model.PrimaryPart = root
	local mesh = roblox.Instance.new("MeshPart")
	mesh.Name = asset .. "_body"
	mesh.Parent = model
	-- (no bone in it: Lune's Bone has no WorldCFrame)
	model:SetAttribute("Asset", asset)
	model:SetAttribute("Scale", 1)
	model:SetAttribute("H", data.size[2])
	model:AddTag("Creature")
	local h = data.size[2]
	local body = roblox.CFrame.new(0, h * 0.55, 0)
	local bones = {}
	for name, j in data.joints do
		local cf = body * roblox.CFrame.new(j[1], j[2], j[3])
		bones[name] = { bone = { WorldCFrame = cf, TransformedWorldCFrame = cf, Name = name }, turn = roblox.CFrame.identity }
	end
	return model, bones
end

-- Lune's Model has no PivotTo, ScaleTo or GetScale: give the copies a stand-in
local Model = roblox.Instance.new("Model")
local ok = pcall(function()
	return Model.PivotTo
end)
if not ok then
	roblox.implementMethod("Model", "PivotTo", function(self, cf)
		local p = self.PrimaryPart
		if p then
			p.CFrame = cf
		end
	end)
	roblox.implementMethod("Model", "ScaleTo", function() end)
	roblox.implementMethod("Model", "GetScale", function()
		return 1
	end)
	roblox.implementMethod("Model", "GetBoundingBox", function(self)
		local h = self:GetAttribute("H") or 4
		return roblox.CFrame.new(0, h / 2, 0), roblox.Vector3.new(h, h, h)
	end)
	roblox.implementMethod("Model", "GetPivot", function(self)
		return if self.PrimaryPart then self.PrimaryPart.CFrame else roblox.CFrame.identity
	end)
end
for _, cls in { "Part", "CornerWedgePart", "MeshPart" } do
	pcall(function()
		roblox.implementProperty(cls, "Position", function(self)
			return self.CFrame.Position
		end)
	end)
end
pcall(function()
	roblox.implementProperty("Bone", "TransformedWorldCFrame", function(self)
		return self.WorldCFrame
	end)
end)

local function bad(v): boolean
	return v ~= v or math.abs(v) > 1e5
end

local keys = {}
for _, asset in { -- every animal model's spell (the variants' own, or their species')
	"creature_jackal_forge",
	"creature_jackal_pharaoh_forge",
	"creature_jackal_sphinx_forge",
	"creature_tortoise_forge",
	"creature_tortoise_gemshell_forge",
	"creature_tortoise_island_forge",
	"creature_meerkat_forge",
	"creature_meerkat_star_forge",
	"creature_meerkat_storm_forge",
	"creature_cheetah_forge",
	"creature_cheetah_lightning_forge",
	"creature_cheetah_thunder_forge",
	"creature_rhino_forge",
	"creature_rhino_lava_forge",
	"creature_rhino_crystal_forge",
	"creature_lion_sahara_forge",
	"creature_flamingo_forge",
	"creature_flamingo_peacock_forge",
	"creature_flamingo_phoenix_forge",
	"creature_lion_forge",
	"creature_lion_sun_forge",
	"creature_lion_shadow_forge",
	"creature_giraffe_forge",
	"creature_giraffe_acacia_forge",
	"creature_giraffe_diamond_forge",
	"creature_elephant_forge",
	"creature_elephant_frost_forge",
	"creature_elephant_war_forge",
} do
	table.insert(keys, asset)
end

for _, asset in keys do
	local model, bones = standIn(asset)
	if not Spells.has(model) then
		print(`MISSING  {asset}`)
		continue
	end
	local most, problems = 0, {}
	table.clear(warnings)
	for i = 0, 64 do
		local t = i * 0.025
		local okStep, err = pcall(Spells.step, model, bones, 1, t)
		if not okStep then
			table.insert(problems, `t={t}: {err}`)
			break
		end
		local shown = 0
		for _, part in workspace:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				shown += 1
				local p, s = part.CFrame.Position, part.Size
				if bad(p.X) or bad(p.Y) or bad(p.Z) or bad(s.X) or bad(s.Y) or bad(s.Z) then
					table.insert(problems, `t={t}: a {part.ClassName} at {p} sized {s}`)
				end
			end
		end
		most = math.max(most, shown)
	end
	Spells.stop(model)
	for _, w in warnings do
		table.insert(problems, w)
	end
	if #problems > 0 then
		table.insert(errors, asset)
		print(`FAIL  {asset}: {#problems} problem(s); first: {problems[1]}`)
	else
		print(`ok    {asset}: at most {most} parts in a frame`)
	end
end
print(if #errors == 0 then "ALL OK" else `{#errors} spell(s) failed`)
