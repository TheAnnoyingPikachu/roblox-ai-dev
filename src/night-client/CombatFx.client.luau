--!strict
-- Hundred Demon Night combat input and VFX (GDD C3 to C9, docs/architecture/night.md sections 5
-- and 6). Reads Attack, Skill and Trigger input on keyboard, mouse, gamepad and touch, soft-locks
-- onto the nearest yokai, sends only Combat(action) and plays the swing at once (prediction).
-- Renders every Fx kind the server broadcasts. Nothing here changes rules: the server decides
-- hits, damage, cooldowns and kills; this script only draws them.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local BlessingRules = require(Shared:WaitForChild("BlessingRules"))
local NightProgress = require(Shared:WaitForChild("NightProgress"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local remotes = ReplicatedStorage:WaitForChild("NightRemotes")
local combat = remotes:WaitForChild("Combat") :: RemoteEvent
local fx = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera

local SFX = ClientState.SFX
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(18, 14, 24)
local RED = Color3.fromRGB(235, 45, 60)
local GOLD = Color3.fromRGB(255, 205, 80)
local CYAN = Color3.fromRGB(110, 230, 255)
local SPIRIT = Color3.fromRGB(140, 200, 255)
local TRIGGER_A = Color3.fromRGB(255, 50, 60)
local TRIGGER_B = Color3.fromRGB(60, 0, 20)
local SOFT_LOCK_RANGE = 12
local BUFFER = 0.25

local fxFolder = Instance.new("Folder")
fxFolder.Name = "NightClientFx"
fxFolder.Parent = Workspace

-- Helpers ---------------------------------------------------------------------------------------

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = fxFolder
	return p
end

-- A copy of the first mesh of a Night Blender model the server shared in
-- ReplicatedStorage.NightModels (src/relay/Models.luau), or nil before the ids are uploaded.
local function nightMesh(name: string): MeshPart?
	local shared = ReplicatedStorage:FindFirstChild("NightModels")
	local model = shared and shared:FindFirstChild(name)
	local mesh = model and model:FindFirstChildWhichIsA("MeshPart")
	if mesh == nil then
		return nil
	end
	local copy = mesh:Clone()
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CastShadow = false
	return copy
end

-- Fades a part out (optionally tweening other properties too) and destroys it.
local function fade(p: BasePart, seconds: number, goal: { [string]: any }?, delay: number?)
	local g: { [string]: any } = goal or {}
	g.Transparency = 1
	TweenService
		:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), g)
		:Play()
	task.delay(seconds + (delay or 0) + 0.05, p.Destroy, p)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
end

local function vec(v: any): Vector3?
	return if typeof(v) == "Vector3" then v else nil
end

local function rootOf(p: Player?): BasePart?
	local character = p and p.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Blade Art colours (H4) for a player's slashes; red and black while their Trigger is on.
local function bladeColours(p: Player): (Color3, Color3)
	if p:GetAttribute("Trigger") == true then
		return TRIGGER_A, TRIGGER_B
	end
	local id = p:GetAttribute("Blade")
	for _, c in NightProgress.COSMETICS do
		if c.id == id and #c.colours > 0 then
			return rgb(c.colours[1]), rgb(c.colours[#c.colours])
		end
	end
	return Color3.fromRGB(225, 240, 255), Color3.fromRGB(140, 180, 255)
end

local function flat(cf: CFrame): CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(cf.Position, cf.Position + look.Unit)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function ground(p: Vector3): Vector3
	local list: { Instance } = { fxFolder }
	local enemies = Workspace:FindFirstChild("NightEnemies")
	if enemies then
		table.insert(list, enemies)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	groundParams.FilterDescendantsInstances = list
	local hit = Workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), groundParams)
	return if hit then hit.Position else Vector3.new(p.X, 0, p.Z)
end

local function enemyModel(e: any): Model?
	local enemies = Workspace:FindFirstChild("NightEnemies")
	local m = enemies and enemies:FindFirstChild(tostring(e))
	return if m and m:IsA("Model") then m else nil
end

-- VFX building blocks ---------------------------------------------------------------------------

-- Anime slash: a tapered neon crescent with a white core, revealed along the swing in 0.08 s,
-- then flung outward as it fades. `tilt` rolls the arc (0 flat, 90 vertical).
local function slash(
	origin: CFrame,
	radius: number,
	arc: number,
	tilt: number,
	a: Color3,
	b: Color3,
	size: number,
	reverse: boolean
)
	local base = origin * CFrame.Angles(0, 0, math.rad(tilt))
	-- Night slash_arc mesh (a 130-degree crescent of radius 4, bulging forward), for arcs up to 180.
	local crescent = if arc <= 180 then nightMesh("slash_arc") else nil
	if crescent then
		local k = radius / 4
		local full = crescent.Size
		for layer = 1, 2 do
			local p = if layer == 1 then crescent else crescent:Clone()
			local s = k * (if layer == 1 then 1 else 0.96)
			p.Size = Vector3.new(full.X * s, 0.1 * size, full.Z * s)
			p.Material = Enum.Material.Neon
			p.Color = if layer == 1 then a:Lerp(b, 0.5) else WHITE
			p.Transparency = if layer == 1 then 0.15 else 0
			-- The crescent's bounding box centre sits 2.85 studs (x k) in front of its circle centre.
			p.CFrame = base * CFrame.new(0, 0, -2.85 * s)
			p.Parent = fxFolder
			fade(p, 0.22, { CFrame = base * CFrame.new(0, 0, -2.85 * s - 1.5 * size) }, 0.04)
		end
		return
	end
	local n = math.clamp(math.floor(arc / 12), 8, 30)
	local segment = 2 * radius * math.sin(math.rad(arc / n) / 2) * 1.2
	for i = 1, n do
		local f = (i - 0.5) / n
		local taper = math.sin(f * math.pi)
		local angle = math.rad(arc / 2 - arc * f)
		local spot = base * CFrame.Angles(0, angle, 0)
		local reveal = (if reverse then n - i else i) * (0.08 / n)
		for layer = 1, 2 do
			local width = (if layer == 1 then 1.6 else 0.5) * size * (0.25 + taper)
			local p = part({
				Size = Vector3.new(segment, 0.1, width),
				CFrame = spot * CFrame.new(0, 0, -(radius + (if layer == 1 then 0 else width * 0.6))),
				Color = if layer == 1 then a:Lerp(b, f) else WHITE,
				Transparency = 1,
			})
			task.delay(reveal, function()
				p.Transparency = if layer == 1 then 0.15 else 0
				fade(p, 0.22, { CFrame = spot * CFrame.new(0, 0, -(radius + 1.5 * size)) }, 0.04)
			end)
		end
	end
end

local function sparks(at: Vector3, colour: Color3, count: number, big: boolean)
	local flash = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (if big then 2.2 else 1.2),
		Position = at,
		Color = WHITE,
	})
	fade(flash, 0.14, { Size = Vector3.one * (if big then 5 else 3) })
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
		local p = part({
			Size = Vector3.new(0.18, 0.18, if big then 2 else 1.3),
			CFrame = CFrame.lookAt(at, at + dir),
			Color = if math.random() < 0.5 then colour else WHITE,
		})
		local reach = (if big then 4 else 2.5) * (0.6 + math.random() * 0.6)
		fade(
			p,
			0.18,
			{ CFrame = CFrame.lookAt(at + dir * reach, at + dir * (reach + 1)), Size = Vector3.new(0.05, 0.05, 0.4) }
		)
	end
end

local function ring(at: Vector3, from: number, to: number, colour: Color3, seconds: number, transparency: number?)
	local cf = CFrame.new(ground(at) + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local p = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, from * 2, from * 2),
		CFrame = cf,
		Color = colour,
		Transparency = transparency or 0.2,
	})
	fade(p, seconds, { Size = Vector3.new(0.05, to * 2, to * 2) })
end

-- Floating number or word at a world position (damage numbers, DODGE).
local function popText(at: Vector3, s: string, colour: Color3, height: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = at + Vector3.new((math.random() - 0.5) * 2, 2, (math.random() - 0.5) * 2)
	a.Parent = Workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.Size = UDim2.fromOffset(height * 3, height)
	bb.Adornee = a
	bb.Parent = a
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = s
	label.TextColor3 = colour
	label.Rotation = math.random(-8, 8)
	label.Parent = bb
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Color = INK
	outline.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 1.8
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(a, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = a.Position + Vector3.new(0, 3, 0),
	}):Play()
	local out = TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.45)
	TweenService:Create(label, out, { TextTransparency = 1 }):Play()
	TweenService:Create(outline, out, { Transparency = 1 }):Play()
	task.delay(0.85, a.Destroy, a)
end

local function flashModel(model: Model, colour: Color3, seconds: number)
	local h = Instance.new("Highlight")
	h.FillColor = colour
	h.FillTransparency = 0
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	task.delay(seconds, h.Destroy, h)
end

-- Hit-stop: freezes your own animations for a few frames so a landed hit feels heavy.
local function hitStop(seconds: number)
	local h = myHumanoid()
	local animator = h and h:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local frozen = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		table.insert(frozen, { track = track, speed = track.Speed })
		track:AdjustSpeed(0)
	end
	task.delay(seconds, function()
		for _, item in frozen do
			if item.track.IsPlaying and item.track.Speed == 0 then
				item.track:AdjustSpeed(item.speed)
			end
		end
	end)
end

-- Screen flash and colour pulse (kills, Trigger, being hit).
local gui = Instance.new("ScreenGui")
gui.Name = "NightCombat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local screenFlash = Instance.new("Frame")
screenFlash.Size = UDim2.fromScale(1, 1)
screenFlash.BackgroundTransparency = 1
screenFlash.BorderSizePixel = 0
screenFlash.Parent = gui

local function flashScreen(colour: Color3, strength: number, seconds: number)
	screenFlash.BackgroundColor3 = colour
	screenFlash.BackgroundTransparency = 1 - strength
	TweenService:Create(screenFlash, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
end

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "NightCombatGrade"
grade.Parent = Lighting
local function pulse(tint: Color3, contrast: number, seconds: number)
	grade.TintColor = tint
	grade.Contrast = contrast
	grade.Saturation = -0.2
	TweenService:Create(grade, TweenInfo.new(seconds), { TintColor = WHITE, Contrast = 0, Saturation = 0 }):Play()
end

-- Swings ----------------------------------------------------------------------------------------

local baseGrip: { [Tool]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

-- Built-in Slash / Lunge tool animation plus a code-driven 120-degree blade sweep (C9 fallback).
local function bladeSweep(character: Model, finisher: boolean)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool == nil then
		return
	end
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = if finisher then "Lunge" else "Slash"
	anim.Parent = tool
	local grip = baseGrip[tool] or tool.Grip
	baseGrip[tool] = grip
	-- Twin Kodachi: the left blade (Gear wearOffhand) sweeps with the right.
	local offhand = character:FindFirstChild("NightOffhand")
	local offWeld = offhand and offhand:FindFirstChild("OffhandGrip", true) :: Weld?
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local f = (os.clock() - start) / 0.15
		if f >= 1 or tool.Parent ~= character then
			tool.Grip = grip
			if offWeld then
				offWeld.C1 = grip
			end
			conn:Disconnect()
			return
		end
		tool.Grip = grip * CFrame.Angles(math.rad(-60 + 120 * f), 0, 0)
		if offWeld then
			offWeld.C1 = grip * CFrame.Angles(math.rad(60 - 120 * f), 0, 0)
		end
	end)
end

local function weaponOf(p: Player): CombatRules.Weapon
	local id = p:GetAttribute("Weapon")
	return CombatRules.weapon(if type(id) == "string" then id else "katana") or CombatRules.WEAPONS[1]
end

local function stacksOf(p: Player): BlessingRules.Stacks
	local s = ClientState.json(p:GetAttribute("Blessings"))
	return if type(s) == "table" then s else {}
end

-- Draws a swing for any player; `own` adds sounds and the Rising Slash hop.
local function drawSwing(p: Player, act: string, step: number, fin: boolean, own: boolean)
	local root = rootOf(p)
	local character = p.Character
	if root == nil or character == nil then
		return
	end
	local a, b = bladeColours(p)
	local origin = flat(root.CFrame) * CFrame.new(0, 0.4, 0)
	local volume = if own then 0.7 else 0.35
	if act == "attack" then
		local w = weaponOf(p)
		local tilt = if fin then 0 else (if step % 2 == 1 then 28 else -28)
		slash(origin, w.range * 0.62, w.arc, tilt, a, b, if fin then 1.5 else 1, step % 2 == 0)
		if fin then
			slash(origin * CFrame.new(0, 0.6, 0), w.range * 0.78, w.arc * 0.8, 8, WHITE, a, 0.6, false)
		end
		bladeSweep(character, fin)
		ClientState.sound(
			if step % 2 == 1 then SFX.swingA else SFX.swingB,
			volume,
			if own then nil else root.Position,
			(if fin then 0.85 else 1.05) + math.random() * 0.1
		)
	elseif act == "skill" then
		if (stacksOf(p).shockwave or 0) > 0 then
			slash(origin, CombatRules.SKILL.shockwaveRange * 0.7, 360, 0, a, b, 1.2, false)
			ring(root.Position, 2, CombatRules.SKILL.shockwaveRange, a, 0.3)
		else
			slash(
				origin * CFrame.new(0, 1, 0),
				CombatRules.SKILL.range * 0.55,
				CombatRules.SKILL.arc,
				90,
				a,
				b,
				1.3,
				true
			)
		end
		bladeSweep(character, true)
		ClientState.sound(SFX.whoosh, volume, if own then nil else root.Position, 0.8)
		if own then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * Workspace.Gravity * 12), v.Z)
		end
	elseif act == "trigger" then
		local burst = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4,
			Position = root.Position,
			Color = TRIGGER_A,
			Transparency = 0.2,
		})
		fade(burst, 0.5, { Size = Vector3.one * 26 })
		ring(root.Position, 2, 16, TRIGGER_A, 0.6)
		ClientState.sound(SFX.boom, volume, if own then nil else root.Position, 0.8)
		if own then
			ClientState.fovKick(22)
			ClientState.shake(0.35, 0.6)
			flashScreen(TRIGGER_A, 0.45, 0.5)
			pulse(Color3.fromRGB(255, 150, 150), 0.3, 0.8)
		end
	end
end

-- Thunder Dash path: a lightning zigzag from where the dash started to 0.35 s later.
local function thunderPath(p: Player)
	local root = rootOf(p)
	if root == nil then
		return
	end
	local from = root.Position
	task.delay(CombatRules.DASH.invulnerable, function()
		local r = rootOf(p)
		if r == nil then
			return
		end
		local to = r.Position
		local last = from
		local count = 6
		for i = 1, count do
			local point = if i == count
				then to
				else from:Lerp(to, i / count) + Vector3.new(
					(math.random() - 0.5) * 2.5,
					(math.random() - 0.5) * 2,
					(math.random() - 0.5) * 2.5
				)
			local length = (point - last).Magnitude
			if length > 0.05 then
				local seg = part({
					Size = Vector3.new(0.35, 0.35, length),
					CFrame = CFrame.lookAt((last + point) / 2, point),
					Color = if i % 2 == 0 then WHITE else CYAN,
				})
				fade(seg, 0.3, { Size = Vector3.new(0.05, 0.05, length) }, 0.05)
			end
			last = point
		end
		ClientState.sound(SFX.boom, 0.3, to, 1.6)
	end)
end

local function dashStreak(p: Player)
	local root = rootOf(p)
	if root == nil then
		return
	end
	local streak = part({
		Size = Vector3.new(0.6, 0.6, 6),
		CFrame = flat(root.CFrame) * CFrame.new(0, 0, 3),
		Color = bladeColours(p),
		Transparency = 0.3,
	})
	fade(streak, 0.25, { Size = Vector3.new(0.05, 0.05, 10) })
end

ClientState.Dashed:Connect(function(thunder: boolean)
	if thunder and ClientState.fighting() then
		thunderPath(player)
	end
end)

-- Input and prediction --------------------------------------------------------------------------

local fighter = CombatRules.newFighter("katana")
local fighterWeapon = ""
local attackQueued = 0
local triggerSentAt = -math.huge

local function syncFighter()
	local w = weaponOf(player).id
	if w ~= fighterWeapon then
		fighterWeapon = w
		fighter = CombatRules.newFighter(w)
	end
end

local function canAct(): boolean
	local h = myHumanoid()
	local hp = player:GetAttribute("HP")
	return ClientState.fighting() and h ~= nil and h.Health > 0 and not (type(hp) == "number" and hp <= 0)
end

local function ensureTool()
	local character, h = player.Character, myHumanoid()
	if character and h and character:FindFirstChildOfClass("Tool") == nil then
		local backpack = player:FindFirstChildOfClass("Backpack")
		local tool = backpack and backpack:FindFirstChildOfClass("Tool")
		if tool then
			h:EquipTool(tool)
		end
	end
end

-- Enemy aim points: each model's root, and each boss part.
local function enemyPoints(): { Vector3 }
	local points = {}
	local enemies = Workspace:FindFirstChild("NightEnemies")
	if enemies == nil then
		return points
	end
	for _, m in enemies:GetChildren() do
		if m:IsA("Model") then
			local parts = 0
			for _, child in m:GetChildren() do
				if child:IsA("BasePart") and child:GetAttribute("Part") ~= nil then
					table.insert(points, child.Position)
					parts += 1
				end
			end
			if parts == 0 then
				table.insert(points, m:GetPivot().Position)
			end
		end
	end
	return points
end

-- Soft lock (C9): turn to the nearest yokai within 12 studs and 90 degrees of the camera.
local function softLock()
	local root = rootOf(player)
	if root == nil then
		return
	end
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		return
	end
	look = look.Unit
	local best: Vector3? = nil
	local bestDistance = SOFT_LOCK_RANGE
	for _, point in enemyPoints() do
		local offset = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		local distance = offset.Magnitude
		if distance <= bestDistance and distance > 0.1 and offset.Unit:Dot(look) >= 0 then
			best, bestDistance = point, distance
		end
	end
	if best then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(best.X, root.Position.Y, best.Z))
	end
end

local function send(action: string)
	combat:FireServer(action)
	ClientState.acted(action)
end

local function tryAttack(): boolean
	if not canAct() then
		return false
	end
	syncFighter()
	local ok, nextFighter, step = CombatRules.attack(fighter, os.clock())
	if not ok then
		return false
	end
	fighter = nextFighter
	ensureTool()
	softLock()
	send("attack")
	drawSwing(player, "attack", step, CombatRules.isFinisher(fighter), true)
	return true
end

local function attack()
	if not tryAttack() and canAct() then
		attackQueued = os.clock() -- buffered: retried each frame for 0.25 s
	end
end

local function skill()
	if not canAct() then
		return
	end
	syncFighter()
	local cooldown = BlessingRules.modifiers(stacksOf(player)).risingCooldown
	local ok, nextFighter = CombatRules.skill(fighter, os.clock(), cooldown)
	if not ok then
		return
	end
	fighter = nextFighter
	ensureTool()
	softLock()
	send("skill")
	drawSwing(player, "skill", 1, true, true)
end

local function trigger()
	local gauge = player:GetAttribute("Gauge")
	if
		not canAct()
		or player:GetAttribute("Trigger") == true
		or type(gauge) ~= "number"
		or gauge < CombatRules.TRIGGER.cost
		or os.clock() - triggerSentAt < 1
	then
		return
	end
	triggerSentAt = os.clock()
	send("trigger")
	drawSwing(player, "trigger", 1, false, true)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		attack()
	end
end)

local function bind(name: string, run: () -> (), ...: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, state)
		if state ~= Enum.UserInputState.Begin or not ClientState.fighting() then
			return Enum.ContextActionResult.Pass
		end
		run()
		return Enum.ContextActionResult.Sink
	end, false, ...)
end
bind("NightSkill", skill, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
bind("NightTrigger", trigger, Enum.KeyCode.R, Enum.KeyCode.ButtonB)

-- Touch buttons: ATTACK (large), SKILL, DASH, TRIGGER on the right, beside the default jump.
local touch = Instance.new("Frame")
touch.Name = "TouchCombat"
touch.AnchorPoint = Vector2.new(1, 1)
-- Left of Roblox's jump button, which sits nearer the corner on phones than on tablets.
local function placeTouch()
	local view = camera.ViewportSize
	touch.Position = UDim2.new(1, if math.min(view.X, view.Y) < 500 then -105 else -185, 1, -12)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(placeTouch)
placeTouch()
touch.Size = UDim2.fromOffset(330, 300)
touch.BackgroundTransparency = 1
touch.Visible = false
touch.Parent = gui
ClientState.autoScale(touch)

type TouchButton = { button: TextButton, cover: Frame, gradient: UIGradient, outline: UIStroke }
local touchButtons: { [string]: TouchButton } = {}

local function touchButton(
	action: string,
	label: string,
	size: number,
	x: number,
	y: number,
	colour: Color3,
	run: () -> ()
)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = colour
	b.BackgroundTransparency = 0.15
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.Text = label
	b.Parent = touch
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local outline = Instance.new("UIStroke")
	outline.Color = WHITE
	outline.Thickness = 3
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.16, 0)
	pad.PaddingRight = UDim.new(0.16, 0)
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = b
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = INK
	textStroke.Thickness = 2
	textStroke.Parent = b
	-- Cooldown cover: a dark wipe drawn with a stepped transparency gradient.
	local cover = Instance.new("Frame")
	cover.AnchorPoint = Vector2.new(0.5, 0.5)
	cover.Position = UDim2.fromScale(0.5, 0.5)
	cover.Size = UDim2.fromOffset(size, size)
	cover.BackgroundColor3 = INK
	cover.BackgroundTransparency = 0
	cover.Visible = false
	cover.Parent = b
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = cover
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = -90
	gradient.Parent = cover
	b.Activated:Connect(run)
	touchButtons[action] = { button = b, cover = cover, gradient = gradient, outline = outline }
end
touchButton("attack", "ATTACK", 132, 200, 200, RED, attack)
touchButton("skill", "SKILL", 78, 80, 210, Color3.fromRGB(70, 90, 200), skill)
touchButton("dash", "DASH", 78, 120, 100, Color3.fromRGB(40, 150, 170), function()
	if ClientState.Dash then
		ClientState.Dash()
	end
end)
touchButton("trigger", "TRIGGER", 86, 250, 60, Color3.fromRGB(120, 20, 40), trigger)

local function setCover(b: TouchButton, fraction: number)
	b.cover.Visible = fraction > 0.01
	local f = math.clamp(fraction, 0.002, 0.998)
	b.gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(f, 0.35),
		NumberSequenceKeypoint.new(math.min(f + 0.001, 1), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Fx rendering ----------------------------------------------------------------------------------

type Projectile = { part: Part, from: Vector3, v: Vector3, born: number, life: number }
type Follow = { parts: { Part }, offsets: { Vector3 }, track: () -> Vector3?, untilT: number }
local projectiles: { [number]: Projectile } = {}
local follows: { Follow } = {}
local telegraphs: { [number]: { Part } } = {}
local markers: { [number]: { part: BasePart, light: Part } } = {}

local function own(u: any): boolean
	return u == player.UserId
end

local function clearTelegraphs(e: number)
	local list = telegraphs[e]
	telegraphs[e] = nil
	if list then
		for _, p in list do
			if p.Parent then
				p:Destroy()
			end
		end
	end
end

-- Destroyed parts are dropped as new ones arrive, so the lists stay short (QA m10).
local function remember(e: number, p: Part)
	local list = telegraphs[e] or {}
	for i = #list, 1, -1 do
		if list[i].Parent == nil then
			table.remove(list, i)
		end
	end
	table.insert(list, p)
	telegraphs[e] = list
end

-- Keeps telegraph parts on a moving point (a tracked player, a charging enemy) until `seconds`.
local function follow(parts: { Part }, centre: Vector3, track: () -> Vector3?, seconds: number)
	local offsets = {}
	for i, p in parts do
		offsets[i] = p.Position - centre
	end
	table.insert(follows, { parts = parts, offsets = offsets, track = track, untilT = os.clock() + seconds })
end

local function clearMarker(u: number)
	local m = markers[u]
	if m then
		m.part:Destroy()
		m.light:Destroy()
		markers[u] = nil
	end
end

local handlers: { [string]: (data: any) -> () } = {}

handlers.swing = function(d)
	if own(d.u) then
		return -- already predicted
	end
	local p = Players:GetPlayerByUserId(tonumber(d.u) or 0)
	if p then
		drawSwing(p, tostring(d.act), tonumber(d.step) or 1, d.fin == true, false)
	end
end

handlers.dash = function(d)
	if own(d.u) then
		return
	end
	local p = Players:GetPlayerByUserId(tonumber(d.u) or 0)
	if p then
		dashStreak(p)
		if d.thunder == true then
			thunderPath(p)
		end
	end
end

handlers.hit = function(d)
	local mine = own(d.u)
	local fin = d.fin == true
	local p = Players:GetPlayerByUserId(tonumber(d.u) or 0)
	local a = if p then bladeColours(p) else WHITE
	for _, item in (if type(d.list) == "table" then d.list else {}) do
		local at = vec(item.p)
		if at then
			sparks(at, a, if fin then 9 else 5, fin)
			if ClientState.settings.numbers then
				local amount = tostring(math.floor(tonumber(item.a) or 0))
				if mine then
					popText(at, amount, if fin then GOLD else WHITE, if fin then 46 else 34)
				else
					popText(at, amount, Color3.fromRGB(190, 185, 210), 24)
				end
			end
		end
		local model = enemyModel(item.e)
		if model then
			flashModel(model, WHITE, 0.08)
		end
	end
	if mine then
		hitStop(if fin then 0.09 else 0.05)
		ClientState.shake(if fin then 0.25 else 0.15, if fin then 0.45 else 0.25)
		ClientState.sound(SFX.thud, if fin then 0.9 else 0.6, nil, if fin then 0.8 else 1.1)
	end
end

handlers.kill = function(d)
	local at = vec(d.p)
	clearTelegraphs(tonumber(d.e) or -1)
	if at == nil then
		return
	end
	local puff = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Position = at,
		Color = Color3.fromRGB(190, 120, 255),
		Transparency = 0.25,
	})
	fade(puff, 0.4, { Size = Vector3.one * 9 })
	for _ = 1, 6 do
		local orb = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			Position = at + Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3),
			Color = SPIRIT,
		})
		fade(
			orb,
			0.9,
			{ Position = orb.Position + Vector3.new(0, 5 + math.random() * 4, 0), Size = Vector3.one * 0.15 }
		)
	end
	ClientState.sound(SFX.pop, 0.55, at, 0.9 + math.random() * 0.2)
	if own(d.u) then
		-- Slow-motion burst (C9): a frozen beat, a pale pulse and a small FOV punch.
		hitStop(0.1)
		pulse(Color3.fromRGB(220, 230, 255), 0.25, 0.25)
		ClientState.fovKick(5)
	end
end

handlers.telegraph = function(d)
	local at = vec(d.p)
	local e = tonumber(d.e) or -1
	local r = math.max(tonumber(d.r) or 4, 0.5)
	local dur = math.max(tonumber(d.dur) or 1, 0.1)
	if at == nil then
		return
	end
	local shape = d.shape
	if shape == "circle" then
		local centre = ground(at)
		local disc = CFrame.Angles(0, 0, math.rad(90))
		local outer = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, r * 2, r * 2),
			CFrame = CFrame.new(centre + Vector3.new(0, 0.1, 0)) * disc,
			Color = RED,
			Transparency = 0.7,
		})
		local edge = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, r * 2 + 0.6, r * 2 + 0.6),
			CFrame = CFrame.new(centre + Vector3.new(0, 0.06, 0)) * disc,
			Color = Color3.fromRGB(255, 120, 120),
			Transparency = 0.35,
		})
		local fill = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.14, 0.2, 0.2),
			CFrame = CFrame.new(centre + Vector3.new(0, 0.14, 0)) * disc,
			Color = RED,
			Transparency = 0.35,
		})
		TweenService
			:Create(fill, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = Vector3.new(0.14, r * 2, r * 2) })
			:Play()
		for _, p in { outer, edge, fill } do
			remember(e, p)
			task.delay(dur, function()
				if p.Parent then
					fade(p, 0.15)
				end
			end)
		end
		local tracked = tonumber(d.follow)
		if tracked then
			local target = Players:GetPlayerByUserId(tracked)
			-- Boss slam: the shadow tracks its player, then locks for the last 0.6 s.
			follow({ outer, edge, fill }, centre, function(): Vector3?
				local root = rootOf(target)
				return if root then ground(root.Position) else nil
			end, math.max(0, dur - 0.6))
		end
	elseif shape == "line" then
		local finish = vec(d.q) or at
		local a, b = ground(at), ground(finish)
		b = Vector3.new(b.X, a.Y, b.Z)
		local length = math.max((b - a).Magnitude, 0.5)
		local frame = CFrame.lookAt(a + Vector3.new(0, 0.1, 0), b + Vector3.new(0, 0.1, 0))
		local lane = part({
			Size = Vector3.new(r * 2, 0.12, length),
			CFrame = frame * CFrame.new(0, 0, -length / 2),
			Color = RED,
			Transparency = 0.65,
		})
		local fill = part({
			Size = Vector3.new(r * 2, 0.14, 0.1),
			CFrame = frame * CFrame.new(0, 0.02, -0.05),
			Color = RED,
			Transparency = 0.3,
		})
		TweenService:Create(fill, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
			Size = Vector3.new(r * 2, 0.14, length),
			CFrame = frame * CFrame.new(0, 0.02, -length / 2),
		}):Play()
		for _, p in { lane, fill } do
			remember(e, p)
			task.delay(dur, function()
				if p.Parent then
					fade(p, 0.15)
				end
			end)
		end
	else -- "glow": the enemy charges up (lantern fireball)
		local model = enemyModel(e)
		local orb = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * r,
			Position = at,
			Color = Color3.fromRGB(255, 150, 40),
			Transparency = 0.55,
		})
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 14
		light.Brightness = 3
		light.Parent = orb
		TweenService:Create(orb, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.one * r * 1.8,
			Transparency = 0.2,
		}):Play()
		remember(e, orb)
		follow({ orb }, at, function(): Vector3?
			return if model and model.Parent then model:GetPivot().Position else nil
		end, dur)
		task.delay(dur, function()
			if orb.Parent then
				fade(orb, 0.1)
			end
		end)
	end
end

handlers.impact = function(d)
	local at = vec(d.p)
	if at == nil then
		return
	end
	local r = math.max(tonumber(d.r) or 6, 1)
	local what = d.what
	local colour = if what == "dash" then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 70, 60)
	ring(at, r * 0.3, r * 1.15, colour, 0.35, 0.1)
	ring(at, r * 0.1, r * 0.8, WHITE, 0.25, 0.3)
	local floor = ground(at)
	for _ = 1, if what == "dash" then 4 else 10 do
		local rock = part({
			Size = Vector3.one * (0.5 + math.random() * 0.8),
			CFrame = CFrame.new(floor + Vector3.new((math.random() - 0.5) * r, 0.5, (math.random() - 0.5) * r))
				* CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(80, 75, 90),
		})
		fade(rock, 0.6, { Position = rock.Position + Vector3.new(0, 3 + math.random() * 4, 0) })
	end
	ClientState.sound(if what == "dash" then SFX.whoosh else SFX.boom, if what == "dash" then 0.5 else 0.8, at)
	local root = rootOf(player)
	if root and (root.Position - at).Magnitude < r + 30 then
		ClientState.shake(if what == "slam" then 0.35 else 0.2, if what == "slam" then 0.7 else 0.35)
	end
end

handlers.projectile = function(d)
	local at, v = vec(d.p), vec(d.v)
	local id = tonumber(d.id)
	if at == nil or v == nil or id == nil then
		return
	end
	local fox = d.what == "foxfire"
	local r = math.max(tonumber(d.r) or 1.5, 0.5)
	local colour = if fox then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(255, 120, 30)
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * r * 1.3, Position = at, Color = colour })
	local core = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * r * 0.7, Position = at, Color = WHITE })
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = ball, core
	weld.Parent = ball
	core.Anchored = false
	core.Massless = true
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 16
	light.Brightness = 4
	light.Parent = ball
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, r * 0.5, 0), Vector3.new(0, -r * 0.5, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(colour, WHITE)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = ball
	projectiles[id] = { part = ball, from = at, v = v, born = os.clock(), life = tonumber(d.life) or 2 }
	if not fox then
		ClientState.sound(SFX.whoosh, 0.4, at, 0.7)
	end
end

handlers.projectileEnd = function(d)
	local id = tonumber(d.id)
	local pr = id and projectiles[id]
	if pr == nil or id == nil then
		return
	end
	projectiles[id] = nil
	local at = vec(d.p) or pr.part.Position
	sparks(at, pr.part.Color, 6, false)
	pr.part:Destroy()
end

handlers.hurt = function(d)
	local at = vec(d.p)
	if at and ClientState.settings.numbers then
		popText(at, `-{math.floor(tonumber(d.a) or 0)}`, Color3.fromRGB(255, 80, 90), if own(d.u) then 36 else 24)
	end
	if own(d.u) then
		flashScreen(RED, 0.35, 0.35)
		ClientState.shake(0.2, 0.4)
		ClientState.sound(SFX.ouch, 0.6)
	end
end

handlers.dodge = function(d)
	local at = vec(d.p)
	if at then
		popText(at, "DODGE!", CYAN, if own(d.u) then 40 else 26)
	end
	if own(d.u) then
		pulse(Color3.fromRGB(180, 230, 255), 0.2, 0.3)
		ClientState.sound(SFX.whoosh, 0.5, nil, 1.4)
	end
end

handlers.down = function(d)
	local u = tonumber(d.u)
	local at = vec(d.p)
	if u == nil or at == nil then
		return
	end
	clearMarker(u)
	-- Spirit flame (G): a floating blue soul above where the player fell, with a light pillar.
	local flame: BasePart
	local soul = nightMesh("wisp")
	if soul then
		soul.Size *= 0.6
		soul.Position = at + Vector3.new(0, 4, 0)
		soul.Parent = fxFolder
		flame = soul
	else
		flame = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			Position = at + Vector3.new(0, 4, 0),
			Color = SPIRIT,
			Transparency = 0.1,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = SPIRIT
	light.Range = 18
	light.Brightness = 3
	light.Parent = flame
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(SPIRIT, WHITE)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Rate = 30
	emitter.Parent = flame
	local pillar = part({
		Size = Vector3.new(0.4, 14, 0.4),
		Position = at + Vector3.new(0, 7, 0),
		Color = SPIRIT,
		Transparency = 0.6,
	})
	markers[u] = { part = flame, light = pillar }
	ClientState.sound(SFX.bigGong, 0.4, at, 1.5)
end

handlers.revive = function(d)
	local u = tonumber(d.u)
	if u then
		clearMarker(u)
	end
	local at = vec(d.p)
	if at then
		ring(at, 1, 10, GOLD, 0.5)
		local column = part({
			Size = Vector3.new(3, 16, 3),
			Position = at + Vector3.new(0, 8, 0),
			Color = GOLD,
			Transparency = 0.3,
		})
		fade(column, 0.6, { Size = Vector3.new(0.2, 24, 0.2) })
		ClientState.sound(SFX.gong, 0.5, at, 1.3)
	end
end

handlers.summon = function(d)
	local at = vec(d.p)
	if at == nil then
		return
	end
	ring(at, 2, 18, Color3.fromRGB(170, 70, 255), 0.6)
	ring(at, 1, 10, WHITE, 0.4, 0.4)
	ClientState.sound(SFX.roar, 0.8, at)
	local root = rootOf(player)
	if root and (root.Position - at).Magnitude < 60 then
		ClientState.shake(0.4, 0.4)
	end
end

fx.OnClientEvent:Connect(function(kind: any, data: any)
	local handler = if type(kind) == "string" then handlers[kind] else nil
	if handler and type(data) == "table" then
		local ok, err = pcall(handler :: any, data)
		if not ok then
			warn("NightFx", kind, err)
		end
	end
end)

-- Trigger aura (C5): red outline, embers and demon wings on every player whose Trigger is on.
local auras: { [Player]: { character: Model, items: { Instance } } } = {}

local function removeAura(p: Player)
	local aura = auras[p]
	if aura then
		for _, item in aura.items do
			item:Destroy()
		end
		auras[p] = nil
	end
end

local function addAura(p: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if root == nil or torso == nil then
		return
	end
	local items: { Instance } = {}
	local h = Instance.new("Highlight")
	h.FillColor = TRIGGER_A
	h.FillTransparency = 0.82
	h.OutlineColor = Color3.fromRGB(255, 90, 90)
	h.Parent = character
	table.insert(items, h)
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(TRIGGER_A, Color3.fromRGB(255, 180, 80))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.5, 0)
	embers.Lifetime = NumberRange.new(0.4, 0.8)
	embers.Speed = NumberRange.new(3, 6)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Acceleration = Vector3.new(0, 8, 0)
	embers.Rate = 40
	embers.Parent = root
	table.insert(items, embers)
	for side = -1, 1, 2 do
		-- Night demon_wing mesh (one bat wing in the y/z plane serves both sides), or a wedge.
		local wing: BasePart = nightMesh("demon_wing") or Instance.new("WedgePart")
		wing.Size = if wing:IsA("MeshPart") then wing.Size else Vector3.new(0.15, 3.2, 2.6)
		wing.Anchored = false
		wing.Material = Enum.Material.Neon
		wing.Color = TRIGGER_A
		wing.Transparency = 0.25
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.CastShadow = false
		wing.Massless = true
		wing.CFrame = torso.CFrame
			* CFrame.new(side * 1.3, 0.8, 0.9)
			* CFrame.Angles(0, math.rad(side * 35), math.rad(side * -20))
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = torso, wing
		weld.Parent = wing
		wing.Parent = character
		table.insert(items, wing)
	end
	auras[p] = { character = character, items = items }
end

task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local on = p:GetAttribute("Trigger") == true and p.Character ~= nil
			local aura = auras[p]
			if aura and (not on or aura.character ~= p.Character) then
				removeAura(p)
			end
			if on and auras[p] == nil then
				addAura(p, p.Character :: Model)
			end
		end
		task.wait(0.2)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	removeAura(p)
	clearMarker(p.UserId)
end)

-- Frame loop ------------------------------------------------------------------------------------

local lastState = ""
local lastStatus: ClientState.Status? = nil
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local status = ClientState.status()

	-- A downed player who left the run keeps no spirit flame (QA m11). Checked on status updates
	-- only, so a down Fx that arrives just before the status listing that player is kept.
	if status ~= lastStatus then
		lastStatus = status
		for u in markers do
			if not table.find(status.ids, u) then
				clearMarker(u)
			end
		end
	end

	-- A new run (or a fresh join) starts a fresh fighter, as the server's Combat.join does.
	if status.state ~= lastState then
		if status.state == "Countdown" or status.state == "Idle" then
			fighter = CombatRules.newFighter(weaponOf(player).id)
			for u in markers do
				clearMarker(u)
			end
			-- Enemies removed without a kill (Defeat, the last player leaving) leave lists (QA m10).
			for e in telegraphs do
				clearTelegraphs(e)
			end
		end
		lastState = status.state
	end

	if attackQueued > 0 then
		if now - attackQueued > BUFFER or tryAttack() then
			attackQueued = 0
		end
	end

	for id, pr in projectiles do
		local age = now - pr.born
		if age > pr.life + 0.3 or pr.part.Parent == nil then
			pr.part:Destroy()
			projectiles[id] = nil
		else
			pr.part.Position = pr.from + pr.v * age
		end
	end

	for i = #follows, 1, -1 do
		local f = follows[i]
		if f.parts[1].Parent == nil or now > f.untilT then
			table.remove(follows, i)
		else
			local at = f.track()
			if at then
				for j, p in f.parts do
					p.CFrame = CFrame.new(at + f.offsets[j]) * p.CFrame.Rotation
				end
			end
		end
	end

	for u, m in markers do
		local p = Players:GetPlayerByUserId(u)
		local root = rootOf(p)
		if root then
			local bob = math.sin(now * 3) * 0.4
			m.part.Position = root.Position + Vector3.new(0, 4 + bob, 0)
			m.light.Position = root.Position + Vector3.new(0, 7, 0)
		end
	end

	-- Touch buttons with cooldown wipes; TRIGGER glows gold when the gauge is full.
	local showTouch = UserInputService.TouchEnabled and canAct()
	touch.Visible = showTouch
	if showTouch then
		local cooldown = BlessingRules.modifiers(stacksOf(player)).risingCooldown
		setCover(touchButtons.skill, 1 - (now - ClientState.sent.skill) / cooldown)
		setCover(touchButtons.dash, 1 - (now - ClientState.sent.dash) / 1)
		local gauge = tonumber(player:GetAttribute("Gauge")) or 0
		local active = player:GetAttribute("Trigger") == true
		setCover(touchButtons.trigger, if active then 0 else 1 - gauge / CombatRules.TRIGGER.cost)
		local full = gauge >= CombatRules.TRIGGER.cost and not active
		touchButtons.trigger.outline.Color = if full then GOLD else WHITE
		touchButtons.trigger.outline.Thickness = if full then 4 + math.sin(now * 10) * 2 else 3
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
