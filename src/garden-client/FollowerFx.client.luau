--!strict
-- Egg Garden pet followers and title tags (GDD V3, V4; docs/architecture/garden.md 6.3). For every
-- player whose `Follower` attribute names a creature, a visual copy of it (cloned from
-- ReplicatedStorage.GardenSpecies, scaled by size, mutation and charm looks from CreatureFx, name tag)
-- hops beside its owner under Workspace.GardenFollowers. Hidden while the owner races, during the
-- owner's hatch reveal and with the Followers setting off. Every part is anchored and never collides,
-- is queried or touched. Also draws the milestone title over each character. Display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local UI = ClientState.UI
local new, text = ClientState.new, ClientState.text
local MAX_FOLLOWERS = 6

local folder = Workspace:FindFirstChild("GardenFollowers")
	or new("Folder", { Name = "GardenFollowers", Parent = Workspace })

type View = {
	inst: Instance,
	id: number,
	species: string,
	state: ClientState.FollowerState,
	cryAt: number,
	faded: boolean?,
}
local views: { [Player]: View } = {}

-- True when `at` (a follower's centre, `radius` across) sits on the line from the camera to the head.
local function blocks(cam: Vector3, head: Vector3, at: Vector3, radius: number): boolean
	local line = head - cam
	local k = (at - cam):Dot(line) / line:Dot(line) -- NaN in first person: never blocks
	return k > 0 and k < 1 and (cam + line * k - at).Magnitude < radius
end

local function rootOf(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tag(main: BasePart, c: any, height: number)
	local colour = ClientState.rarityColour(c.s)
	local bb = new("BillboardGui", {
		Name = "Tag",
		Size = UDim2.fromOffset(170, 46),
		StudsOffset = Vector3.new(0, height / 2 + 1.3, 0),
		MaxDistance = 45,
		LightInfluence = 0,
		Parent = main,
	})
	local line1 = text({
		Size = UDim2.fromScale(1, 0.58),
		Text = ClientState.creatureName(c.s, c.m, c.z, c.c, c.n),
		TextColor3 = UI.WHITE,
		Parent = bb,
	})
	new("UIStroke", { Color = UI.INK, Thickness = 2, Transparency = 0.3, Parent = line1 })
	local line2 = text({
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.42),
		Text = ClientState.rarityName(c.s),
		TextColor3 = colour,
		Parent = bb,
	})
	new("UIStroke", { Color = Color3.fromRGB(235, 230, 255), Thickness = 2, Transparency = 0.2, Parent = line2 })
end

local function make(p: Player, c: any): View?
	local species = ReplicatedStorage:FindFirstChild("GardenSpecies")
	local source = species and species:FindFirstChild(c.s)
	if not (source and (source:IsA("BasePart") or source:IsA("Model"))) then
		return nil
	end
	local size = GardenConfig.size(c.z)
	local scale = if size then size.scale else 1
	local copy = source:Clone()
	local main: BasePart? = nil
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			main = main or part
		end
	end
	if copy:IsA("BasePart") then
		main = copy
	end
	if main == nil then
		copy:Destroy()
		return nil
	end
	if copy:IsA("Model") then
		copy:ScaleTo(copy:GetScale() * scale) -- the species model carries its own fit scale; ScaleTo is absolute
	else
		(copy :: BasePart).Size = (copy :: BasePart).Size * scale
	end
	for _, part in if copy:IsA("Model") then copy:GetDescendants() else { copy } do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	local extents = if copy:IsA("Model") then copy:GetExtentsSize() else (copy :: BasePart).Size
	local height = extents.Y
	local half = math.max(extents.X, extents.Z) / 2
	copy.Name = tostring(c.id)
	copy:SetAttribute("Id", c.id)
	copy:SetAttribute("Owner", p.UserId)
	copy:SetAttribute("S", c.s)
	copy:SetAttribute("M", c.m)
	copy:SetAttribute("Z", c.z)
	copy:SetAttribute("C", c.c)
	copy:SetAttribute("N", c.n)
	tag(main :: BasePart, c, height)
	local root = rootOf(p)
	local start = if root then root.CFrame:PointToWorldSpace(ClientState.followerOffset(half)) else Vector3.zero
	copy:PivotTo(CFrame.new(start + Vector3.new(0, height / 2, 0)))
	copy.Parent = folder -- CreatureFx tracks it from here and applies the looks
	return {
		inst = copy,
		id = c.id,
		species = c.s,
		state = { pos = start, yaw = 0, scale = scale, half = half, hopFrom = nil, hopTo = nil, hopAt = 0 },
		cryAt = -math.huge,
	}
end

local function drop(p: Player)
	local view = views[p]
	if view then
		views[p] = nil
		view.inst:Destroy()
	end
end

-- Which creature each player's follower should show now, or nil to hide it.
local function wanted(p: Player, shown: number): any
	local id = tonumber(p:GetAttribute("Follower")) or 0
	if id == 0 or not ClientState.settings.followers or shown >= MAX_FOLLOWERS then
		return nil
	end
	if (ClientState.revealing[p.UserId] or 0) > 0 or table.find(ClientState.status().dash.racers, p.UserId) then
		return nil
	end
	if rootOf(p) == nil then
		return nil
	end
	local profile = ClientState.profileOf(p)
	for _, c in if profile then profile.creatures else {} do
		if c.id == id then
			return c
		end
	end
	return nil
end

local function sync()
	local shown = 0
	for _, p in Players:GetPlayers() do
		local c = wanted(p, shown)
		local view = views[p]
		if c == nil then
			drop(p)
			continue
		end
		local same = view
			and view.id == c.id
			and view.inst:GetAttribute("S") == c.s
			and view.inst:GetAttribute("M") == c.m
			and view.inst:GetAttribute("Z") == c.z
			and view.inst:GetAttribute("C") == c.c
			and view.inst:GetAttribute("N") == c.n
		if not same then
			drop(p)
			views[p] = make(p, c)
		end
		if views[p] then
			shown += 1
		end
	end
	for p in views do
		if p.Parent == nil then
			drop(p)
		end
	end
end

task.spawn(function()
	while true do
		sync()
		task.wait(0.5)
	end
end)
ClientState.SettingsChanged:Connect(sync)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for p, view in views do
		local root = rootOf(p)
		if root == nil or view.inst.Parent == nil then
			continue
		end
		local cf, hopped = ClientState.followerStep(view.state, root.CFrame, t)
		local height = if view.inst:IsA("Model") then view.inst:GetExtentsSize().Y else (view.inst :: BasePart).Size.Y
		view.inst:PivotTo(cf * CFrame.new(0, height / 2, 0))
		-- Your own follower fades while it stands between your camera and your head (QA M3).
		local head = if p == Players.LocalPlayer and p.Character then p.Character:FindFirstChild("Head") else nil
		local camera = Workspace.CurrentCamera
		local fade = head ~= nil
			and head:IsA("BasePart")
			and camera ~= nil
			and blocks(
				camera.CFrame.Position,
				(head :: BasePart).Position,
				cf.Position + Vector3.new(0, height / 2, 0),
				math.max(view.state.half, height / 2)
			)
		if fade ~= (view.faded == true) then
			view.faded = fade
			for _, part in { view.inst, table.unpack(view.inst:GetDescendants()) } do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = if fade then 0.6 else 0
				end
			end
		end
		if
			hopped
			and t - view.cryAt >= ClientState.FOLLOWER.cryGap
			and ClientState.idleCry(view.species, cf.Position)
		then
			view.cryAt = t
		end
	end
end)

-- Title tags (V4): "Hatchling Keeper" or "Garden Legend" over the character's head.
local titles: { [Player]: TextLabel } = {}
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local head = p.Character and p.Character:FindFirstChild("Head")
			local title = ClientState.title(ClientState.profileOf(p))
			local label = titles[p]
			if label and (title == nil or head == nil or not label:IsDescendantOf(head)) then
				(label.Parent :: Instance):Destroy()
				titles[p] = nil
				label = nil
			end
			if title and head and label == nil then
				local bb = new("BillboardGui", {
					Name = "GardenTitle",
					Size = UDim2.fromOffset(160, 24),
					StudsOffset = Vector3.new(0, 3.2, 0),
					MaxDistance = 60,
					LightInfluence = 0,
					Parent = head,
				})
				label = text({ Size = UDim2.fromScale(1, 1), Text = title, TextColor3 = UI.GOLD, Parent = bb })
				new("UIStroke", { Color = UI.INK, Thickness = 2, Transparency = 0.3, Parent = label })
				titles[p] = label
			elseif label and title then
				label.Text = title
			end
		end
		for p, label in titles do
			if p.Parent == nil then
				(label.Parent :: Instance):Destroy()
				titles[p] = nil
			end
		end
		task.wait(1)
	end
end)
