--!strict
-- Neon Spire plaza visuals, GREYBOX (SPIRE-006; SPIRE-007 rewrites this file at final quality).
-- Every lot's plaza items from its State attribute: a steel base over the item's footprint and a
-- neon cap (magenta for Hype items, height by Hype; ice for decor). Diffed by uid, so placing,
-- moving or selling touches one item. Plazas over 400 studs from the camera are hidden (5.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlazaRules = require(Shared:WaitForChild("PlazaRules"))
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local camera = Workspace.CurrentCamera
local UI = ClientState.UI
local root = ClientState.folder("Plazas")
local CELL = SpireConfig.PLAZA.cell

type Lot = { folder: Folder, items: { [number]: { key: string, model: Model } } }
local lots: { [number]: Lot } = {}

local function part(parent: Instance, frame: CFrame, size: Vector3, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.CFrame = frame
	p.Size = size
	p.Color = colour
	p.Material = material
	p.Parent = parent
	return p
end

local function build(frame: CFrame, item: any): Model
	local m = Instance.new("Model")
	m.Name = `Item{item.u}`
	local def = SpireConfig.item(item.id)
	local w, d = PlazaRules.footprint(item.id, item.r)
	local c = PlazaRules.itemCentre(item.id, item.x, item.y, item.r)
	local hype = if def then def.hype else 0
	local h = if hype > 0 then math.min(10, 1.5 + hype * 0.25) else 1
	local size = Vector3.new(w * CELL - 0.6, h, d * CELL - 0.6)
	part(m, frame * CFrame.new(c.x, c.y + h / 2, c.z), size, UI.STEEL, Enum.Material.SmoothPlastic)
	part(
		m,
		frame * CFrame.new(c.x, c.y + h + 0.15, c.z),
		Vector3.new(size.X, 0.3, size.Z),
		if hype > 0 then UI.MAGENTA else UI.ICE,
		Enum.Material.Neon
	)
	return m
end

local function render(n: number)
	local state = ClientState.lotState(n)
	local frame = ClientState.lotFrame(n)
	local lot = lots[n]
	if not (state and frame) then
		if lot then
			lot.folder:Destroy()
			lots[n] = nil
		end
		return
	end
	if not lot then
		local folder = Instance.new("Folder")
		folder.Name = `Lot{n}`
		folder.Parent = root
		lot = { folder = folder, items = {} }
		lots[n] = lot
	end
	local l = lot :: Lot
	local seen: { [number]: boolean } = {}
	for _, item in state.items do
		local u = tonumber(item.u)
		if not u then
			continue
		end
		seen[u] = true
		local key = `{item.id}:{item.x}:{item.y}:{item.r}`
		local entry = l.items[u]
		if not entry or entry.key ~= key then
			if entry then
				entry.model:Destroy()
			end
			local m = build(frame, item)
			m.Parent = l.folder
			l.items[u] = { key = key, model = m }
			-- Pop in from flat (greybox stand-in for the K6 placement juice).
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") then
					local full = p.Size
					p.Size = Vector3.new(full.X, 0.05, full.Z)
					TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = full }):Play()
				end
			end
		end
	end
	for u, entry in l.items do
		if not seen[u] then
			entry.model:Destroy()
			l.items[u] = nil
		end
	end
end

local watched: { [Model]: boolean } = {}
task.spawn(function()
	while true do
		for n = 1, 6 do
			local m = ClientState.lotModel(n)
			if m and not watched[m] then
				watched[m] = true
				m:GetAttributeChangedSignal("State"):Connect(function()
					render(n)
				end)
				render(n)
			end
		end
		local camPos = camera.CFrame.Position
		for n, lot in lots do
			local frame = ClientState.lotFrame(n)
			if frame then
				local far = (frame:PointToWorldSpace(Vector3.new(0, 0, -30)) - camPos).Magnitude > 400
				lot.folder.Parent = if far then nil else root
			end
		end
		task.wait(0.5)
	end
end)
