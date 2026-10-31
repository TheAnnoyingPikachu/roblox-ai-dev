--!strict
-- Weapon Tool and mask for run participants (GDD C1, H4). Display only: the Tool has
-- ManualActivationOnly and no scripts, so equipping it changes nothing the server decides.
-- The blade is coloured by the equipped Blade Art; masks are small part models welded to the head.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NightAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NightAssets"))
local NightProgress = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NightProgress"))
local Models = require(script.Parent:WaitForChild("Models"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local Gear = {}

local TOOL = "NightWeapon"
local MASK = "NightMask"
local SAYA = "NightSaya"
local OFFHAND = "NightOffhand"
local INK = Color3.fromRGB(25, 20, 28)
local GOLD = Color3.fromRGB(220, 175, 60)

-- Blade length, grip length, blade base width (WEAPONS in tools/blender/night/assets/weapons.py) and
-- display name per weapon id.
local SHAPES: { [string]: { blade: number, grip: number, width: number, name: string } } = {
	katana = { blade = 4.2, grip = 1.4, width = 0.32, name = "Katana" },
	kodachi = { blade = 2.6, grip = 1, width = 0.28, name = "Twin Kodachi" },
	nodachi = { blade = 6, grip = 2, width = 0.38, name = "Nodachi" },
}

-- The Handle part is exactly the tsuka, so its centre is the middle of the grip whatever the
-- length, and the hand closes there. PALM moves the handle axis from the hand's grip point (its
-- end) into the palm. GUARD leans the blade forward from upright; the edge then faces away from
-- the player. CombatFx bladeSweep swings about this pose.
local PALM = 0.16
local GUARD = math.rad(20)
local GRIP = (CFrame.new(0, 0, PALM) * CFrame.Angles(-GUARD, 0, 0)):Inverse()
-- The kashira hangs this far below the Handle (hero and old models alike).
local POMMEL = 0.1
-- Saya on the left hip, edge up: mouth this far ahead of the torso centre, tip this far below it
-- (a fixed drop, so a long saya sits flatter and stays off the ground).
local SAYA_FRONT = 1.1
local SAYA_DROP = 1.5

local function colours(id: string): { Color3 }
	for _, c in NightProgress.COSMETICS do
		if c.id == id then
			local list = {}
			for _, rgb in c.colours do
				table.insert(list, Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
			end
			return list
		end
	end
	return {}
end

local function sequence(list: { Color3 }): ColorSequence
	if #list == 0 then
		return ColorSequence.new(Color3.new(1, 1, 1))
	elseif #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(keys)
end

local function welded(
	parent: Instance,
	to: BasePart,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function vector(list: { number }): Vector3
	return Vector3.new(list[1], list[2], list[3])
end

-- Replaces a hero blade with the art's own blade when both are uploaded (`blade_<art>`, built at
-- katana size). It is stretched per weapon about its root, which lands on the hero blade's root.
-- Returns the new Blade part and its glow, or nil to keep the hero blade.
local function artBlade(
	parent: Instance,
	handle: BasePart,
	heroBlade: BasePart,
	weapon: string,
	art: string
): (BasePart?, BasePart?)
	local name = `blade_{art}`
	local hero, entry = NightAssets[weapon], NightAssets[name]
	if hero == nil or hero.root == nil or entry == nil or entry.root == nil then
		return nil, nil
	end
	local model = Models.night(name, parent, Vector3.zero)
	local blade = model and model:FindFirstChild(`{name}_blade`) :: BasePart?
	if model == nil or blade == nil then
		if model then
			model:Destroy()
		end
		return nil, nil
	end
	local shape = SHAPES[weapon]
	local width = shape.width / SHAPES.katana.width
	local stretch = Vector3.new(width, shape.blade / SHAPES.katana.blade, width)
	local root = blade.CFrame * CFrame.new(vector(entry.root))
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local rel = root:ToObjectSpace(p.CFrame)
			p.Size *= stretch
			p.CFrame = root * CFrame.new(rel.Position * stretch) * rel.Rotation
		end
	end
	local box = model:GetBoundingBox()
	local offset = CFrame.new(vector(hero.root) - box:PointToObjectSpace(root.Position))
	Models.attach(model, handle, handle.CFrame:ToObjectSpace(heroBlade.CFrame) * offset)
	return blade, model:FindFirstChild(`{name}_glow`) :: BasePart?
end

-- Builds the sword on `handle`: Night model (hilt, tinted blade and detail lines) or part fallback.
local function dress(parent: Instance, handle: BasePart, weapon: string, blade: string)
	local shape = SHAPES[weapon] or SHAPES.katana
	local tint = colours(blade)
	local base = handle.CFrame
	local edge: BasePart
	-- Night weapon model (NightAssets): hilt welded on the handle with the tsuka along it; its
	-- untextured blade mesh becomes the tinted Blade, and the glow lines take the second colour.
	local mesh = Models.night(if SHAPES[weapon] then weapon else "katana", parent, Vector3.zero)
	local meshBlade = mesh and mesh:FindFirstChild(`{mesh.Name}_blade`) :: BasePart?
	if mesh and meshBlade then
		local _, size = mesh:GetBoundingBox()
		Models.attach(mesh, handle, CFrame.new(0, -shape.grip / 2 - POMMEL + size.Y / 2, 0))
		handle.Transparency = 1
		local glow = mesh:FindFirstChild(`{mesh.Name}_glow`) :: BasePart?
		local swapped, swappedGlow = artBlade(parent, handle, meshBlade, weapon, blade)
		if swapped then
			meshBlade:Destroy()
			if glow then
				glow:Destroy()
			end
			meshBlade, glow = swapped, swappedGlow
		end
		meshBlade.Color = tint[1] or Color3.fromRGB(220, 225, 235)
		-- Neon bloom whites out a whole blade, so with detail lines only the lines glow.
		meshBlade.Material = if glow then Enum.Material.Metal else Enum.Material.Neon
		if glow then
			glow.Color = tint[2] or tint[1] or Color3.fromRGB(140, 150, 165)
			glow.Material = Enum.Material.Neon
		end
		edge = meshBlade
	else
		if mesh then
			mesh:Destroy()
		end
		welded(
			parent,
			handle,
			Vector3.new(0.9, 0.15, 0.6),
			base * CFrame.new(0, shape.grip / 2 + 0.07, 0),
			GOLD,
			Enum.Material.Metal
		)
		edge = welded(
			parent,
			handle,
			Vector3.new(0.12, shape.blade, 0.32),
			base * CFrame.new(0, shape.grip / 2 + 0.15 + shape.blade / 2, 0),
			tint[1] or Color3.fromRGB(220, 225, 235),
			Enum.Material.Neon
		)
	end
	edge.Name = "Blade"
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "TrailTop", "TrailBottom"
	a0.Position = Vector3.new(0, edge.Size.Y / 2, 0)
	a1.Position = Vector3.new(0, -edge.Size.Y / 2 + 0.3, 0)
	a0.Parent, a1.Parent = edge, edge
	local trail = Instance.new("Trail")
	trail.Name = "BladeTrail"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = sequence(tint)
	trail.LightEmission = 0.8
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = edge
end

local function newHandle(weapon: string): Part
	local shape = SHAPES[weapon] or SHAPES.katana
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, shape.grip, 0.35)
	handle.Color = INK
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	return handle
end

-- The Tool is the right-hand sword; `wear` adds what shows only while it is held.
local function buildTool(weapon: string, blade: string): Tool
	local shape = SHAPES[weapon] or SHAPES.katana
	local tool = Instance.new("Tool")
	tool.Name = TOOL
	tool.ToolTip = shape.name
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.RequiresHandle = true
	tool:SetAttribute("Weapon", weapon)
	tool:SetAttribute("Blade", blade)
	local handle = newHandle(weapon)
	handle.Parent = tool
	tool.Grip = GRIP
	dress(tool, handle, weapon, blade)
	return tool
end

local function unwear(character: Model)
	for _, name in { SAYA, OFFHAND } do
		local item = character:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
end

-- Saya on the left hip, edge up, mouth forward. Nil until `<weapon>_saya` is uploaded.
local function wearSaya(character: Model, weapon: string)
	local torso = (character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local saya = torso and Models.night(`{weapon}_saya`, character, torso.Position)
	if torso == nil or saya == nil then
		return
	end
	saya.Name = SAYA
	local _, size = saya:GetBoundingBox()
	local belt = if torso.Name == "Torso" then -0.75 else -0.1 -- R6 torso is one tall block
	local down = math.asin(SAYA_DROP / size.Y)
	local ahead = math.cos(down)
	-- The model's +Y runs from mouth to tip, its edge toward -Z.
	local turn = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.new(0, -math.sin(down), ahead))
	Models.attach(
		saya,
		torso,
		CFrame.new(-torso.Size.X / 2 - 0.12, belt - SAYA_DROP / 2, size.Y / 2 * ahead - SAYA_FRONT) * turn
	)
end

-- Twin Kodachi: the second blade, welded to the left hand with the same grip.
local function wearOffhand(character: Model, weapon: string, blade: string)
	local hand = (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")) :: BasePart?
	if hand == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = OFFHAND
	local handle = newHandle(weapon)
	handle.CanTouch, handle.CanQuery = false, false
	handle.Parent = model
	dress(model, handle, weapon, blade)
	local grip = hand:FindFirstChild("LeftGripAttachment") :: Attachment?
	local weld = Instance.new("Weld")
	weld.Name = "OffhandGrip"
	weld.Part0, weld.Part1 = hand, handle
	weld.C0 = if grip then grip.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	weld.C1 = GRIP
	weld.Parent = handle
	model.Parent = character
end

local function wear(tool: Tool, character: Model, weapon: string, blade: string)
	unwear(character)
	wearSaya(character, weapon)
	if weapon == "kodachi" then
		wearOffhand(character, weapon, blade)
	end
	-- A first load yields: the sword may have been put away meanwhile.
	if tool.Parent ~= character then
		unwear(character)
	end
end

type Feature = { size: Vector3, at: CFrame, colour: number, material: Enum.Material? }

-- Face plate offset from the head centre; `colour` indexes the cosmetic's colours (1 base, 2 accent).
local MASKS: { [string]: { Feature } } = {
	kitsune = {
		{ size = Vector3.new(1.1, 1, 0.2), at = CFrame.new(0, 0.05, -0.62), colour = 1 },
		{ size = Vector3.new(0.3, 0.45, 0.15), at = CFrame.new(-0.4, 0.75, -0.55), colour = 1 },
		{ size = Vector3.new(0.3, 0.45, 0.15), at = CFrame.new(0.4, 0.75, -0.55), colour = 1 },
		{
			size = Vector3.new(0.5, 0.08, 0.05),
			at = CFrame.new(0, 0.2, -0.74),
			colour = 2,
			material = Enum.Material.Neon,
		},
		{ size = Vector3.new(0.35, 0.3, 0.3), at = CFrame.new(0, -0.2, -0.82), colour = 1 },
	},
	tengu = {
		{ size = Vector3.new(1.1, 1, 0.2), at = CFrame.new(0, 0.05, -0.62), colour = 1 },
		{ size = Vector3.new(0.22, 0.22, 0.9), at = CFrame.new(0, 0, -1.15), colour = 1 },
		{ size = Vector3.new(0.9, 0.12, 0.05), at = CFrame.new(0, 0.3, -0.74), colour = 2 },
	},
	oni = {
		{ size = Vector3.new(1.1, 1, 0.2), at = CFrame.new(0, 0.05, -0.62), colour = 1 },
		{
			size = Vector3.new(0.18, 0.55, 0.18),
			at = CFrame.new(-0.35, 0.75, -0.55) * CFrame.Angles(0, 0, 0.3),
			colour = 2,
		},
		{
			size = Vector3.new(0.18, 0.55, 0.18),
			at = CFrame.new(0.35, 0.75, -0.55) * CFrame.Angles(0, 0, -0.3),
			colour = 2,
		},
		{ size = Vector3.new(0.7, 0.12, 0.05), at = CFrame.new(0, -0.3, -0.74), colour = 2 },
	},
	eclipse = {
		{ size = Vector3.new(1.1, 1.1, 0.2), at = CFrame.new(0, 0.05, -0.62), colour = 1 },
		{
			size = Vector3.new(1.3, 0.1, 0.05),
			at = CFrame.new(0, 0.6, -0.72),
			colour = 2,
			material = Enum.Material.Neon,
		},
		{
			size = Vector3.new(1.3, 0.1, 0.05),
			at = CFrame.new(0, -0.5, -0.72),
			colour = 2,
			material = Enum.Material.Neon,
		},
	},
	okame = {
		{ size = Vector3.new(1.15, 1.05, 0.25), at = CFrame.new(0, 0.05, -0.62), colour = 1 },
		{ size = Vector3.new(0.25, 0.2, 0.05), at = CFrame.new(-0.32, -0.15, -0.76), colour = 2 },
		{ size = Vector3.new(0.25, 0.2, 0.05), at = CFrame.new(0.32, -0.15, -0.76), colour = 2 },
	},
	hannya = {
		{ size = Vector3.new(1.1, 1.05, 0.2), at = CFrame.new(0, 0.05, -0.62), colour = 1 },
		{
			size = Vector3.new(0.16, 0.6, 0.16),
			at = CFrame.new(-0.4, 0.8, -0.5) * CFrame.Angles(-0.4, 0, 0.35),
			colour = 1,
		},
		{
			size = Vector3.new(0.16, 0.6, 0.16),
			at = CFrame.new(0.4, 0.8, -0.5) * CFrame.Angles(-0.4, 0, -0.35),
			colour = 1,
		},
		{ size = Vector3.new(0.75, 0.15, 0.05), at = CFrame.new(0, -0.3, -0.74), colour = 2 },
		{
			size = Vector3.new(0.3, 0.1, 0.05),
			at = CFrame.new(-0.25, 0.2, -0.74),
			colour = 2,
			material = Enum.Material.Neon,
		},
		{
			size = Vector3.new(0.3, 0.1, 0.05),
			at = CFrame.new(0.25, 0.2, -0.74),
			colour = 2,
			material = Enum.Material.Neon,
		},
	},
}

local MASK_SCALE = 0.72

local function buildMask(character: Model, mask: string)
	local features = MASKS[mask]
	local head = character:FindFirstChild("Head") :: BasePart?
	if features == nil or head == nil then
		return
	end
	local tint = colours(mask)
	-- Night mask model (NightAssets), scaled so the 1.5-stud face fits the head, chin at the old
	-- plate's bottom; its side ties end 0.39 studs (unscaled) behind the rim, so placing the back
	-- of the bounding box there puts the rim on the face (head front is z = -0.6).
	local sculpted = Models.night(`mask_{mask}`, character, head.Position, 0, MASK_SCALE)
	if sculpted then
		local _, size = sculpted:GetBoundingBox()
		Models.attach(sculpted, head, CFrame.new(0, -0.45 + size.Y / 2, -0.6 + 0.39 * MASK_SCALE - size.Z / 2))
		sculpted.Name = MASK
		sculpted:SetAttribute("Mask", mask)
		return
	end
	local model = Instance.new("Model")
	model.Name = MASK
	model:SetAttribute("Mask", mask)
	for _, f in features do
		welded(
			model,
			head,
			f.size,
			head.CFrame * f.at,
			tint[f.colour] or tint[1] or Color3.new(1, 1, 1),
			f.material or Enum.Material.SmoothPlastic
		)
	end
	model.Parent = character
end

function Gear.strip(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local tool = container and container:FindFirstChild(TOOL)
		if tool then
			tool:Destroy()
		end
	end
	local mask = player.Character and player.Character:FindFirstChild(MASK)
	if mask then
		mask:Destroy()
	end
	if player.Character then
		unwear(player.Character)
	end
end

-- Gives the profile's weapon (equipped) and mask; a no-op when the current gear already matches.
function Gear.give(player: Player)
	local profile = Profiles.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if profile == nil or character == nil or humanoid == nil then
		return
	end
	local held = character:FindFirstChild(TOOL)
		or (player:FindFirstChildOfClass("Backpack") or player):FindFirstChild(TOOL)
	local worn = character:FindFirstChild(MASK)
	local sameTool = held
		and held:GetAttribute("Weapon") == profile.weapon
		and held:GetAttribute("Blade") == profile.blade
	local sameMask = (worn and worn:GetAttribute("Mask") == profile.mask)
		or (worn == nil and MASKS[profile.mask] == nil)
	if sameTool and sameMask then
		return
	end
	Gear.strip(player)
	buildMask(character, profile.mask)
	local tool = buildTool(profile.weapon, profile.blade)
	tool.Equipped:Connect(function()
		wear(tool, character, profile.weapon, profile.blade)
	end)
	tool.Unequipped:Connect(function()
		unwear(character)
	end)
	tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	humanoid:EquipTool(tool)
end

return Gear
