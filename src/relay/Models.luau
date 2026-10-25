--!strict
-- Generated 3D models (Roblox mesh generation, owned by the experience creator; see
-- docs/assets/register.md). Loaded at runtime by asset ID, so the repo holds IDs, not binaries.
-- If a mesh fails to load, `spawn` returns nil and callers keep their part-built fallback.

local AssetService = game:GetService("AssetService")

local Models = {}

type Entry = { mesh: string, texture: string, size: Vector3 }

local MESHES: { [string]: Entry } = {
	oni = {
		mesh = "rbxassetid://116124333528107",
		texture = "rbxassetid://100523147264116",
		size = Vector3.new(19.3, 23.5, 16),
	},
	pagoda = {
		mesh = "rbxassetid://122277590516586",
		texture = "rbxassetid://79997104777585",
		size = Vector3.new(23.7, 47.5, 24),
	},
	trophy = {
		mesh = "rbxassetid://105076361309216",
		texture = "rbxassetid://86149062997023",
		size = Vector3.new(6, 6.4, 2.7),
	},
	sakura = {
		mesh = "rbxassetid://139101786875815",
		texture = "rbxassetid://82598844088960",
		size = Vector3.new(15.4, 16.3, 16),
	},
	skull = {
		mesh = "rbxassetid://82884423323818",
		texture = "rbxassetid://121884110465590",
		size = Vector3.new(11.1, 14.4, 8),
	},
	komainu = {
		mesh = "rbxassetid://130213651134294",
		texture = "rbxassetid://73994868840361",
		size = Vector3.new(5.1, 9, 7.1),
	},
}

local cache: { [string]: MeshPart } = {}

-- A new anchored copy of a generated model, scaled by `scale` and standing on `base` (its bottom
-- face sits at base.Y), facing `yaw` degrees.
function Models.spawn(name: string, parent: Instance, base: Vector3, scale: number, yaw: number?): MeshPart?
	local entry = MESHES[name]
	if entry == nil then
		return nil
	end
	local template = cache[name]
	if template == nil then
		local ok, result = pcall(AssetService.CreateMeshPartAsync, AssetService, Content.fromUri(entry.mesh))
		if not ok then
			warn(`[Models] {name} failed to load: {tostring(result)}`)
			return nil
		end
		template = result :: MeshPart
		template.TextureID = entry.texture
		template.Anchored = true
		template.Size = entry.size
		cache[name] = template
	end
	local copy = template:Clone()
	copy.Name = name
	copy.Size = entry.size * scale
	copy.CFrame = CFrame.new(base + Vector3.new(0, copy.Size.Y / 2, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	copy.Parent = parent
	return copy
end

return Models
