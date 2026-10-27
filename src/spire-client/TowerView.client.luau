--!strict
-- Neon Spire tower visuals, GREYBOX (SPIRE-006; SPIRE-007 rewrites this file at final quality).
-- Builds every lot's tower from its State attribute with simple parts under Workspace.SpireClient:
-- per floor a slab, a brand-colour front strip, four glass walls tinted by department, four
-- pillars, a lift ring and one signature band (<= 13 parts); module boxes inside only near the
-- camera (section 5.1); a roof antenna with the company sign. Floors are diffed, so a purchase
-- rebuilds one floor, with a short fade-in sweep. In build mode the own tower turns into a
-- cross-section with ClientState.focusFloor highlighted and a ghost of the next floor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local TowerRules = require(Shared:WaitForChild("TowerRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local camera = Workspace.CurrentCamera
local UI = ClientState.UI
local root = ClientState.folder("Towers")

local SIDE = TowerRules.TOWER.size
local CZ = TowerRules.TOWER.z
-- Department module models (src/shared/SpireAssets.luau); the module box stays while nil.
local MODULES: { [string]: string } = {
	data = "server_rack",
	fusion = "fusion_cell",
	ad = "holo_projector",
	synth = "bio_printer",
	drone = "drone_dock",
	quantum = "q_mind",
	orbital = "uplink_dish",
}

type Lot = {
	folder: Folder,
	keys: { [number]: string },
	floors: { [number]: Model },
	interiors: { [number]: Model },
	state: any,
	roof: string,
	count: number,
}
local lots: { [number]: Lot } = {}

local function part(
	parent: Instance,
	frame: CFrame,
	size: Vector3,
	colour: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = frame
	p.Size = size
	p.Color = colour
	p.Material = material
	p.Transparency = transparency or 0
	p:SetAttribute("Base", p.Transparency)
	p.Parent = parent
	return p
end

local function floorHeight(n: number): number
	return if n == 1 then TowerRules.LOBBY_HEIGHT else TowerRules.FLOOR_HEIGHT
end

local function deptColour(d: string): Color3
	return ClientState.DEPT_COLOURS[d] or UI.CYAN
end

-- Exterior of floor n (lot space, then moved by the lot frame).
local function buildFloor(lot: number, frame: CFrame, n: number, f: any, trim: Color3): Model
	local m = Instance.new("Model")
	m.Name = `Floor{n}`
	m:SetAttribute("Floor", n)
	m:SetAttribute("Lot", lot)
	local y = TowerRules.floorY(n)
	local h = floorHeight(n) - 1
	local at = function(x: number, yy: number, z: number): CFrame
		return frame * CFrame.new(x, yy, z)
	end
	local tint = deptColour(f.d)
	part(m, at(0, y - 0.5, CZ), Vector3.new(SIDE, 1, SIDE), UI.STEEL, Enum.Material.SmoothPlastic).Name = "Slab"
	local allFive = f.d ~= SpireConfig.LOBBY
	for _, level in f.m do
		allFive = allFive and level >= 5
	end
	local strip = part(
		m,
		at(0, y + 0.15, CZ - SIDE / 2 - 0.2),
		Vector3.new(SIDE, 0.3, 0.3),
		if allFive then UI.AMBER else trim,
		Enum.Material.Neon
	)
	strip.Name = "Strip"
	local wy = y + h / 2
	if n == 1 then -- lobby front with a door gap at x -4..4
		for _, s in { -1, 1 } do
			part(m, at(s * 11, wy, CZ - SIDE / 2), Vector3.new(14, h, 0.4), tint, Enum.Material.Glass, 0.6).Name =
				"Wall"
		end
	else
		part(m, at(0, wy, CZ - SIDE / 2), Vector3.new(SIDE, h, 0.4), tint, Enum.Material.Glass, 0.6).Name = "Wall"
	end
	part(m, at(0, wy, CZ + SIDE / 2), Vector3.new(SIDE, h, 0.4), tint, Enum.Material.Glass, 0.6).Name = "Wall"
	part(m, at(-SIDE / 2, wy, CZ), Vector3.new(0.4, h, SIDE), tint, Enum.Material.Glass, 0.6).Name = "Wall"
	part(m, at(SIDE / 2, wy, CZ), Vector3.new(0.4, h, SIDE), tint, Enum.Material.Glass, 0.6).Name = "Wall"
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(
			m,
			at(c[1] * SIDE / 2, wy, CZ + c[2] * SIDE / 2),
			Vector3.new(1.2, h, 1.2),
			UI.STEEL,
			Enum.Material.SmoothPlastic
		)
	end
	local ring = if Kit.model("lift_ring", m, frame:PointToWorldSpace(Vector3.new(0, y, CZ)), Kit.yaw(frame))
		then nil
		else part(
			m,
			at(0, y + 0.1, CZ) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(0.2, TowerRules.LIFT.radius * 2, TowerRules.LIFT.radius * 2),
			UI.CYAN,
			Enum.Material.Neon,
			0.5
		)
	if ring then
		ring.Shape = Enum.PartType.Cylinder
		ring.Name = "Lift"
	end
	if n > 1 then
		part(m, at(0, y + h - 1, CZ - SIDE / 2 - 0.4), Vector3.new(SIDE - 4, 0.6, 0.3), tint, Enum.Material.Neon).Name =
			"Signature"
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = d.Name == "Wall" or d.Name == "Slab"
		end
	end
	return m
end

-- Module boxes (interior), built only when the LOD rule asks for them.
local function buildInterior(frame: CFrame, n: number, f: any): Model
	local m = Instance.new("Model")
	m.Name = `Interior{n}`
	for slot, level in f.m do
		if level > 0 then
			local o = TowerRules.slotPos(n, slot)
			local asset = MODULES[f.d]
			-- Grows with level (0.82 at L1 to 1.1 at L5); amber glow at L5 like the greybox.
			local model = asset
				and Kit.model(
					asset,
					m,
					frame:PointToWorldSpace(Vector3.new(o.x, o.y, o.z)),
					Kit.yaw(frame),
					0.75 + 0.07 * level
				)
			if model then
				local glow = Kit.glow(model)
				if glow and level >= 5 then
					glow.Color = UI.AMBER
				end
				continue
			end
			local h = 1.5 + level
			local p = part(
				m,
				frame * CFrame.new(o.x, o.y + h / 2, o.z),
				Vector3.new(6, h, 6),
				if level >= 5 then UI.AMBER else deptColour(f.d),
				if level >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			)
			p.CanQuery = false
		end
	end
	return m
end

local function buildRoof(lot: Lot, frame: CFrame, state: any)
	local old = lot.folder:FindFirstChild("Roof")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "Roof"
	local y = TowerRules.floorY(#state.floors + 1)
	local trim = ClientState.brand(if type(state.company) == "table" then state.company.trim else 1)
	part(m, frame * CFrame.new(0, y - 0.5, CZ), Vector3.new(SIDE, 1, SIDE), UI.STEEL, Enum.Material.SmoothPlastic)
	local antenna = Kit.model("roof_antenna", m, frame:PointToWorldSpace(Vector3.new(0, y, CZ + 8)), Kit.yaw(frame))
	local beacon: BasePart? = antenna and Kit.glow(antenna, "2")
	if beacon then
		beacon.Color = trim
	else
		part(m, frame * CFrame.new(0, y + 10, CZ + 8), Vector3.new(1, 20, 1), UI.STEEL, Enum.Material.Metal)
		local ball =
			part(m, frame * CFrame.new(0, y + 20.5, CZ + 8), Vector3.new(1.4, 1.4, 1.4), trim, Enum.Material.Neon)
		ball.Shape = Enum.PartType.Ball
		beacon = ball
	end
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	sign.MaxDistance = 900
	sign.LightInfluence = 0
	sign.Adornee = beacon
	sign.Parent = m
	local name = if type(state.company) == "table" then SpireConfig.companyName(state.company) else "Company"
	ClientState.text({
		Size = UDim2.fromScale(1, 0.65),
		Text = string.upper(name),
		TextColor3 = trim,
		FontFace = ClientState.FONT.display,
		Parent = sign,
	})
	ClientState.text({
		Position = UDim2.fromScale(0, 0.65),
		Size = UDim2.fromScale(1, 0.35),
		Text = `{#state.floors} floors · {tonumber(state.endorsements) or 0} endorsements`,
		TextColor3 = UI.WHITE,
		Parent = sign,
	})
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	m.Parent = lot.folder
end

-- Construction sweep: parts fade in bottom to top over about a second.
local function sweep(m: Model)
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			d.Transparency = 1
		end
	end
	table.sort(parts, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	for i, p in parts do
		task.delay(i * 0.05, function()
			TweenService:Create(p, TweenInfo.new(0.35), { Transparency = p:GetAttribute("Base") or 0 }):Play()
		end)
	end
end

-- Build mode: the own tower becomes a cross-section, the focused floor stands out ---------------------

local ghost: Part? = nil
local function applyMode()
	local mine = ClientState.myLot()
	local building = ClientState.mode == "tower"
	for n, lot in lots do
		for fn, m in lot.floors do
			local focus = building and n == mine and fn == ClientState.focusFloor
			for _, d in m:GetChildren() do
				if d:IsA("BasePart") then
					local base = d:GetAttribute("Base") or 0
					if d.Name == "Wall" then
						d.Transparency = if building and n == mine then (if focus then 0.35 else 0.88) else base
					elseif d.Name == "Strip" then
						d.Size = Vector3.new(SIDE, if focus then 0.8 else 0.3, if focus then 0.8 else 0.3)
					end
				end
			end
		end
	end
	local lot = mine and lots[mine]
	local frame = mine and ClientState.lotFrame(mine)
	if building and lot and frame and lot.state and #lot.state.floors < SpireConfig.MAX_FLOORS then
		local n = #lot.state.floors + 1
		local y = TowerRules.floorY(n)
		if not ghost then
			ghost = part(root, CFrame.new(), Vector3.one, UI.CYAN, Enum.Material.ForceField, 0.2)
		end
		local g = ghost :: Part
		g.Size = Vector3.new(SIDE, TowerRules.FLOOR_HEIGHT - 1, SIDE)
		g.CFrame = frame * CFrame.new(0, y + 1 + g.Size.Y / 2, CZ)
		g.Color = if ClientState.focusFloor == n then UI.WHITE else UI.CYAN
		g:SetAttribute("Floor", n)
		g:SetAttribute("Lot", mine)
		g.Name = "GhostFloor"
	elseif ghost then
		ghost:Destroy()
		ghost = nil
	end
end
ClientState.ModeChanged:Connect(applyMode)

-- State to parts ----------------------------------------------------------------------------------------

local function clearLot(n: number)
	local lot = lots[n]
	if lot then
		lot.folder:Destroy()
		lots[n] = nil
	end
end

local function render(n: number)
	local state = ClientState.lotState(n)
	local frame = ClientState.lotFrame(n)
	if not (state and frame) then
		clearLot(n)
		return
	end
	local lot = lots[n]
	if not lot then
		local folder = Instance.new("Folder")
		folder.Name = `Lot{n}`
		folder.Parent = root
		lot = { folder = folder, keys = {}, floors = {}, interiors = {}, state = nil, roof = "", count = 0 }
		lots[n] = lot
	end
	local l = lot :: Lot
	local first = l.state == nil
	l.state = state
	local trimIndex = if type(state.company) == "table" then tonumber(state.company.trim) or 1 else 1
	local trim = ClientState.brand(trimIndex)
	for fn, f in state.floors do
		local key = `{f.d}|{table.concat(f.m, ",")}|{trimIndex}`
		if l.keys[fn] ~= key then
			l.keys[fn] = key
			if l.floors[fn] then
				l.floors[fn]:Destroy()
			end
			if l.interiors[fn] then
				l.interiors[fn]:Destroy()
				l.interiors[fn] = nil
			end
			local m = buildFloor(n, frame, fn, f, trim)
			m.Parent = l.folder
			l.floors[fn] = m
			if not first and fn > l.count then
				sweep(m)
				ClientState.sound(ClientState.SFX.thud, 0.5, m:GetPivot().Position, 0.6)
			end
		end
	end
	for fn = #state.floors + 1, l.count do
		if l.floors[fn] then
			l.floors[fn]:Destroy()
			l.floors[fn] = nil
		end
		if l.interiors[fn] then
			l.interiors[fn]:Destroy()
			l.interiors[fn] = nil
		end
		l.keys[fn] = nil
	end
	l.count = #state.floors
	local roofKey =
		`{#state.floors}|{trimIndex}|{state.endorsements}|{state.company and state.company.p}|{state.company and state.company.s}`
	if roofKey ~= l.roof then
		l.roof = roofKey
		buildRoof(l, frame, state)
	end
	applyMode()
end

local watched: { [Model]: boolean } = {}
local function watch(n: number)
	local m = ClientState.lotModel(n)
	if not m or watched[m] then
		return
	end
	watched[m] = true
	m:GetAttributeChangedSignal("State"):Connect(function()
		render(n)
	end)
	m:GetAttributeChangedSignal("Owner"):Connect(function()
		render(n)
	end)
	render(n)
end

-- Hot Data spark (greybox; SPIRE-007 Fx adds the juice) ----------------------------------------------

local sparks: { [number]: Model } = {}
ClientState.fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" or type(data.lot) ~= "number" then
		return
	end
	if kind == "hot" and type(data.floor) == "number" and type(data.slot) == "number" then
		local frame = ClientState.lotFrame(data.lot)
		if not frame then
			return
		end
		if sparks[data.lot] then
			sparks[data.lot]:Destroy()
		end
		local m = Instance.new("Model")
		m.Name = "HotData"
		local o = TowerRules.slotPos(data.floor, data.slot)
		local core = part(
			m,
			frame * CFrame.new(o.x, o.y + 3, o.z) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2),
			UI.AMBER,
			Enum.Material.Neon
		)
		core.CanQuery = false
		local pillar = part(
			m,
			frame * CFrame.new(o.x, o.y + 33, o.z),
			Vector3.new(0.4, 60, 0.4),
			UI.AMBER,
			Enum.Material.Neon,
			0.5
		)
		pillar.CanQuery = false
		m.Parent = root
		sparks[data.lot] = m
		local ends = tonumber(data.ends) or 0
		task.delay(math.max(0, ends - ClientState.now()), function()
			if sparks[data.lot] == m then
				m:Destroy()
				sparks[data.lot] = nil
			end
		end)
	elseif kind == "grabbed" and sparks[data.lot] then
		sparks[data.lot]:Destroy()
		sparks[data.lot] = nil
	end
end)

-- Level of detail (section 5.1), 2 Hz ------------------------------------------------------------------

local function playerFloor(n: number, frame: CFrame, count: number): number?
	local r = ClientState.root()
	if not r then
		return nil
	end
	local l = frame:PointToObjectSpace(r.Position)
	if math.abs(l.X) > SIDE / 2 + 2 or math.abs(l.Z - CZ) > SIDE / 2 + 2 then
		return if n == ClientState.myLot() then 1 else nil
	end
	for k = count + 1, 1, -1 do
		if l.Y >= TowerRules.floorY(k) - 1 then
			return k
		end
	end
	return 1
end

task.spawn(function()
	Kit.waitModels()
	while true do
		for n = 1, 6 do
			watch(n)
		end
		local camPos = camera.CFrame.Position
		local mine = ClientState.myLot()
		for n, lot in lots do
			local frame = ClientState.lotFrame(n)
			if not (frame and lot.state) then
				continue
			end
			local top = TowerRules.floorY(lot.count + 1)
			local axis = frame:PointToWorldSpace(Vector3.new(0, 0, CZ))
			local y = math.clamp(camPos.Y, axis.Y, axis.Y + top)
			local dist = (Vector3.new(axis.X, y, axis.Z) - camPos).Magnitude
			local here = playerFloor(n, frame, lot.count)
			local low = ClientState.quality == "low"
			for fn, f in lot.state.floors do
				local want = (not low and dist < 120)
					or (here ~= nil and math.abs(fn - here) <= (if low then 0 else 2))
					or (n == mine and ClientState.mode == "tower" and math.abs(fn - (ClientState.focusFloor or 0)) <= 1)
				if want and not lot.interiors[fn] then
					local m = buildInterior(frame, fn, f)
					m.Parent = lot.folder
					lot.interiors[fn] = m
				elseif not want and lot.interiors[fn] then
					lot.interiors[fn]:Destroy()
					lot.interiors[fn] = nil
				end
				local sig = lot.floors[fn] and lot.floors[fn]:FindFirstChild("Signature") :: BasePart?
				if sig then
					sig.Transparency = if dist > 400 then 1 else 0
				end
			end
		end
		task.wait(0.5)
	end
end)
