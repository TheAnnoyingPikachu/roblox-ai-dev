--!strict
-- Lantern Express lamp turrets and the night (GDD E, C4, L; decision 0018 section 3; architecture
-- lantern 6). While this player sits in a turret seat the camera sits behind the lamp head and the
-- mouse, a touch drag or the right stick swings the beam. The aim is kept in the train frame and
-- sent on `Aim` as a direction only (at most 10 a second, and again before the server's 0.5 s
-- staleness); the local beam draws at once. Other players' beams follow their turret heads. Wisps
-- and the Lampeater are drawn from their Fx spawn records with WispRules.pos and lampeaterPos, so
-- clients match the server's own positions; they puff, dim and dive only on the server's Fx.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local WispRules = require(Shared:WaitForChild("WispRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))

local UI = ClientState.UI
local new = UiKit.new
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local BEAM = LanternConfig.BEAM

local aimRemote: UnreliableRemoteEvent? = nil
task.spawn(function()
	aimRemote = ReplicatedStorage:WaitForChild("LanternRemotes"):WaitForChild("Aim") :: UnreliableRemoteEvent
end)

local function lampColour(p: Player): Color3
	local c = LanternConfig.cosmetic(tostring(p:GetAttribute("Lamp") or "warm"))
	return if c and c.slot == "lamp" then ClientState.colour(c.colours[1]) else Color3.fromRGB(255, 200, 120)
end

-- A beam: a cone (Beam between two attachments) in the lamp colour, a SpotLight and dust motes.
type Lamp = { part: Part, tip: Attachment, beam: Beam, light: SpotLight, motes: ParticleEmitter }
local function makeLamp(name: string): Lamp
	local part = new("Part", {
		Name = name,
		Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = Workspace,
	})
	local base = new("Attachment", { Name = "Base", Parent = part })
	local tip = new("Attachment", { Name = "Tip", Parent = part })
	local beam = new("Beam", {
		Attachment0 = base,
		Attachment1 = tip,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Width0 = 1.2,
		Segments = 4,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.6, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = part,
	})
	local light = new(
		"SpotLight",
		{ Angle = BEAM.halfAngle * 2 + 6, Brightness = 3, Shadows = false, Face = Enum.NormalId.Front, Parent = part }
	)
	local motes = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Size = NumberSequence.new(0.15),
		LightEmission = 1,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(BEAM.halfAngle, BEAM.halfAngle),
		EmissionDirection = Enum.NormalId.Front,
		Rate = if ClientState.still() then 0 else 10,
		Parent = part,
	})
	return { part = part, tip = tip, beam = beam, light = light, motes = motes }
end

local function drawLamp(l: Lamp, origin: Vector3, dir: Vector3, range: number, colour: Color3)
	l.part.CFrame = CFrame.lookAt(origin, origin + dir)
	l.tip.Position = Vector3.new(0, 0, -range)
	l.beam.Width1 = 2 * range * math.tan(math.rad(BEAM.halfAngle))
	l.beam.Color = ColorSequence.new(colour)
	l.light.Color = colour
	l.light.Range = math.min(range, 60)
	l.motes.Color = ColorSequence.new(colour)
end

local function setLampVisible(l: Lamp, on: boolean)
	l.beam.Enabled, l.light.Enabled, l.motes.Enabled = on, on, on
end

-- Turret heads (server models named after the asset) and the seat each one belongs to.
local function turretSeat(humanoid: Humanoid?): Seat?
	local s = humanoid and humanoid.SeatPart
	return if s and s:IsA("Seat") and s:GetAttribute("Kind") == "turret" then s else nil
end
local heads: { [BasePart]: BasePart | false } = {}
local function headNear(seat: BasePart): BasePart?
	local cached = heads[seat]
	if cached ~= nil and (cached == false or (cached :: BasePart).Parent) then
		return cached or nil
	end
	local best, bestD = nil, 6
	local car = seat.Parent
	for _, d in if car and car ~= Workspace then car:GetDescendants() else {} do
		local part = if d:IsA("BasePart")
				and (d.Name == "lamp_turret_head" or (d.Parent and d.Parent.Name == "lamp_turret_head"))
			then d
			else nil
		if part then
			local dist = (part.Position - seat.Position).Magnitude
			if dist < bestD then
				best, bestD = part, dist
			end
		end
	end
	heads[seat] = best or false
	return best
end

-- This player's turret control ------------------------------------------------------------------------------

local yaw, pitch = 0, math.rad(10) -- in the train frame: yaw 0 looks forward (-z), positive turns right
local lastSent, lastDir = 0, Vector3.zero
local myLamp = makeLamp("MyLamp")
setLampVisible(myLamp, false)
local onTurret = false
local dragging: InputObject? = nil

local function aimTrain(): LanternConfig.Vec3
	local c = math.cos(pitch)
	return { x = math.sin(yaw) * c, y = math.sin(pitch), z = -math.cos(yaw) * c }
end

local function turn(dx: number, dy: number)
	yaw += dx
	pitch = math.clamp(pitch + dy, math.rad(BEAM.pitchMin), math.rad(BEAM.pitchMax))
end

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not onTurret then
		return
	end
	if
		input.UserInputType == Enum.UserInputType.MouseMovement
		and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	then
		turn(input.Delta.X * 0.004, -input.Delta.Y * 0.004)
	elseif input.UserInputType == Enum.UserInputType.Touch and dragging == input then
		turn(input.Delta.X * 0.006, -input.Delta.Y * 0.006)
	end
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if onTurret and not processed and input.UserInputType == Enum.UserInputType.Touch and dragging == nil then
		dragging = input
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if dragging == input then
		dragging = nil
	end
end)

local function myRange(): number
	return BEAM.range[math.clamp(ClientState.run().Lamps or 1, 1, 3)]
end

local function updateTurret(dt: number, humanoid: Humanoid?)
	local seat = turretSeat(humanoid)
	local was = onTurret
	onTurret = seat ~= nil
	if not onTurret then
		if was then
			setLampVisible(myLamp, false)
			camera.CameraType = Enum.CameraType.Custom
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		return
	end
	local panelOpen = UiKit.current() ~= nil or ClientState.menuOpen or ClientState.wheelOpen
	if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = if panelOpen then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	end
	-- right stick: 140 degrees a second at full tilt
	for _, s in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if s.KeyCode == Enum.KeyCode.Thumbstick2 and s.Position.Magnitude > 0.15 then
			turn(s.Position.X * math.rad(140) * dt, s.Position.Y * math.rad(140) * dt)
		end
	end
	local head = headNear(seat :: Seat)
	local origin = if head then head.Position else (seat :: Seat).Position + Vector3.new(0, 2.5, 0)
	local dirTrain = aimTrain()
	local dir = ClientState.dirToWorld(dirTrain).Unit
	drawLamp(myLamp, origin + dir * 1.5, dir, myRange(), lampColour(player))
	setLampVisible(myLamp, true)
	camera.CameraType = Enum.CameraType.Scriptable
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	camera.CFrame = CFrame.lookAt(origin - flat * 9 + Vector3.new(0, 4, 0), origin + dir * 40)
	-- send: on a change over 0.5 degrees at most 10 a second, and every 0.3 s so the aim never goes stale
	local v = Vector3.new(dirTrain.x, dirTrain.y, dirTrain.z)
	local now = os.clock()
	local changed = lastDir.Magnitude == 0 or math.deg(math.acos(math.clamp(v:Dot(lastDir), -1, 1))) > 0.5
	local remote = aimRemote
	if remote and now - lastSent >= 0.1 and (changed or now - lastSent >= 0.3) then
		lastSent, lastDir = now, v
		remote:FireServer(v)
	end
end

-- Other players' beams follow their turret heads ------------------------------------------------------------

local others: { [Player]: Lamp } = {}
local function updateOthers()
	local night = ClientState.run().Phase == "night"
	for _, p in Players:GetPlayers() do
		if p == player then
			continue
		end
		local character = p.Character
		local seat = turretSeat(character and character:FindFirstChildOfClass("Humanoid"))
		if seat and night then
			local lamp = others[p] or makeLamp("Lamp_" .. p.UserId)
			others[p] = lamp
			local head = headNear(seat)
			local cf = if head then head.CFrame else seat.CFrame
			drawLamp(
				lamp,
				cf.Position + Vector3.new(0, if head then 0 else 2.5, 0),
				cf.LookVector,
				myRange(),
				lampColour(p)
			)
			setLampVisible(lamp, true)
		elseif others[p] then
			others[p].part:Destroy()
			others[p] = nil
		end
	end
end
Players.PlayerRemoving:Connect(function(p)
	if others[p] then
		others[p].part:Destroy()
		others[p] = nil
	end
end)

-- Wisps (shadow_wisp: a soft indigo puff with two glowing eyes; art bible 9) -----------------------------

type Drawn = { rec: WispRules.Wisp, model: Model, ends: number, swell: number }
local wisps: { [number]: Drawn } = {}
local folder = new("Folder", { Name = "LanternNight", Parent = Workspace })

local function wispModel(): Model
	local m = ClientState.model("shadow_wisp")
	if m then
		return m
	end
	local model = new("Model", { Name = "shadow_wisp" })
	local body = ClientState.ball(model, "Body", Vector3.new(2.5, 2.3, 2.5), Color3.fromRGB(46, 38, 104), Vector3.zero)
	body.Transparency = 0.1
	for _, x in { -0.45, 0.45 } do
		local eye = ClientState.ball(
			model,
			"Eye",
			Vector3.new(0.45, 0.55, 0.3),
			UI.RING,
			Vector3.new(x, 0.25, -1.1),
			Enum.Material.Neon
		)
		eye.Transparency = 0
	end
	model.PrimaryPart = body
	return model
end

local function place(model: Model, at: Vector3, face: Vector3, scale: number)
	local cf = CFrame.lookAt(at, at + face)
	model:PivotTo(cf)
	if math.abs(model:GetScale() - scale) > 0.01 then
		model:ScaleTo(scale)
	end
end

local function sparkle(at: Vector3, colour: Color3, count: number)
	local a = new("Attachment", { Parent = Workspace.Terrain })
	a.WorldPosition = at
	local e = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(colour, UI.CREAM),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = a,
	})
	e:Emit(count)
	task.delay(1.2, a.Destroy, a)
end

local PASTELS = { UI.PINK, UI.RING, UI.MINT, UI.SKY, UI.LILAC }
local function removeWisp(id: number, puff: boolean)
	local w = wisps[id]
	if not w then
		return
	end
	wisps[id] = nil
	local at = w.model:GetPivot().Position
	w.model:Destroy()
	if puff then
		sparkle(at, PASTELS[id % #PASTELS + 1], 24) -- pastel sparkles, never a burst (art bible 9)
		ClientState.sound("puff", 0.4, at, 1.3)
		ClientState.sound("chime", 0.15, at, 1.8)
	end
end

local function addWisps(list: { any })
	for _, r in list do
		local id = tonumber(r.id)
		if not id or wisps[id] then
			continue
		end
		local rec: WispRules.Wisp = {
			id = id,
			born = tonumber(r.born) or ClientState.now(),
			from = ClientState.vec(r.from),
			target = ClientState.vec(r.target),
			speed = tonumber(r.speed) or LanternConfig.WAVES.speed,
			phase = tonumber(r.phase) or 0,
			lit = 0,
			state = "drift",
		}
		local dx, dy, dz = rec.target.x - rec.from.x, rec.target.y - rec.from.y, rec.target.z - rec.from.z
		local travel = math.sqrt(dx * dx + dy * dy + dz * dz) / math.max(0.1, rec.speed)
		local model = wispModel()
		model.Parent = folder
		wisps[id] = { rec = rec, model = model, ends = rec.born + travel + 4, swell = 1 }
	end
end

-- The Lampeater (a soft majestic moth; announced 3 s ahead; never a lunge at the camera) -----------------

type Moth = { state: WispRules.Lampeater, model: Model, wingL: BasePart, wingR: BasePart, leaving: number? }
local moth: Moth? = nil
local warned = false

local function mothModel(): (Model, BasePart, BasePart)
	local model = new("Model", { Name = "Lampeater" })
	local body = ClientState.model("lampeater_body")
	local core: BasePart
	if body then
		body.Parent = model
		core = body:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		core = new("Part", {
			Name = "lampeater_body",
			Size = Vector3.new(6, 6, 16),
			Color = Color3.fromRGB(150, 130, 200),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		for _, x in { -1.5, 1.5 } do
			ClientState.ball(model, "Eye", Vector3.new(1.6, 1.6, 1), UI.GOLD, Vector3.new(x, 1, -8), Enum.Material.Neon)
		end
	end
	local function wing(name: string): BasePart
		local m = ClientState.model(name)
		if m then
			m.Parent = model
			return m:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		end
		return new("WedgePart", {
			Name = name,
			Size = Vector3.new(1.5, 12, 18),
			Color = Color3.fromRGB(120, 96, 190),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	local l, r = wing("lampeater_wing_l"), wing("lampeater_wing_r")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	model.PrimaryPart = core
	return model, l, r
end

local function drawMoth(now: number, t: number)
	local m = moth :: Moth
	local p = ClientState.toWorld(WispRules.lampeaterPos(m.state, now))
	if m.leaving then
		p += Vector3.new(0, (t - m.leaving) * 20, 0) -- fed: spirals up to the moon
	end
	local ahead = ClientState.toWorld(WispRules.lampeaterPos(m.state, now + 0.2))
	local face = if (ahead - p).Magnitude > 0.01 then (ahead - p).Unit else Vector3.zAxis
	local cf = CFrame.lookAt(p, p + face)
	m.model.PrimaryPart.CFrame = cf
	local flap = if ClientState.still() then 0.2 else math.sin(t * 3) * 0.5
	m.wingL.CFrame = cf * CFrame.new(-11, 0, 0) * CFrame.Angles(0, 0, flap)
	m.wingR.CFrame = cf * CFrame.new(11, 0, 0) * CFrame.Angles(0, 0, -flap)
end

local function dropMoth()
	if moth then
		moth.model:Destroy()
		moth = nil
	end
end

-- Every frame -------------------------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt: number)
	local character = player.Character
	updateTurret(dt, character and character:FindFirstChildOfClass("Humanoid"))
	updateOthers()
	local r = ClientState.run()
	local now = ClientState.now()
	local t = os.clock()
	if r.Phase ~= "night" then
		for id in wisps do
			removeWisp(id, false)
		end
		dropMoth()
		warned = false
		return
	end
	-- the 3 s warning before the Lampeater rises (GDD E4: every big moment announced)
	if
		(r.Leg or 1) >= 3
		and not warned
		and now >= (r.PhaseAt or now) + LanternConfig.LAMPEATER.at - LanternConfig.LAMPEATER.warn
	then
		warned = true
		ClientState.toast("Something big is coming...", "lantern", UI.LILAC)
	end
	local myBeam: WispRules.Beam? = nil
	if onTurret then
		local o = ClientState.toTrain(myLamp.part.Position)
		myBeam = { origin = o, dir = aimTrain() }
	end
	local range = myRange()
	for id, w in wisps do
		if now > w.ends then
			removeWisp(id, false)
			continue
		end
		local local3 = WispRules.pos(w.rec, now)
		-- a wisp in this player's beam swells while the server counts its light (display only)
		local goal = if myBeam and WispRules.lit(myBeam, local3, range) then 1.35 else 1
		w.swell += (goal - w.swell) * math.min(1, dt * 6)
		local at = ClientState.toWorld(local3)
		place(w.model, at, camera.CFrame.Position - at, if ClientState.still() then 1 else w.swell)
	end
	if moth then
		drawMoth(now, t)
	end
end)

ClientState.Fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "wisps" and type(data.list) == "table" then
		addWisps(data.list)
	elseif kind == "puff" and type(data.ids) == "table" then
		for _, id in data.ids do
			removeWisp(tonumber(id) or -1, true)
		end
	elseif kind == "dim" then
		local w = wisps[tonumber(data.id) or -1]
		if w then
			sparkle(w.model:GetPivot().Position, UI.FOG, 8) -- the wisp melts into the lantern, which gutters
			removeWisp(w.rec.id, false)
		end
	elseif kind == "lampeater" then
		dropMoth()
		local model, l, r = mothModel()
		model.Parent = folder
		local born = tonumber(data.born) or ClientState.now()
		moth = {
			state = {
				born = born,
				fed = 0,
				need = 0,
				nextDive = born + LanternConfig.LAMPEATER.every,
				dive = nil,
				gone = nil,
			},
			model = model,
			wingL = l,
			wingR = r,
		}
	elseif kind == "dive" and moth then
		moth.state.dive =
			{ at = tonumber(data.at) or ClientState.now(), target = ClientState.vec(data.target), lit = 0 }
	elseif kind == "shoo" and moth then
		sparkle(moth.model:GetPivot().Position, UI.RING, 16)
	elseif kind == "fed" and moth then
		moth.leaving = os.clock()
		sparkle(moth.model:GetPivot().Position, UI.GOLD, 40)
		ClientState.toast("The Lampeater purrs and flies to the moon!", "lantern", UI.GOLD)
		task.delay(5, dropMoth)
	end
end)
