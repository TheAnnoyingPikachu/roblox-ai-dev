--!strict
-- The fight camera (decisions 0045, 0097; SHANNON 2026-11-22, decision 0106): an action camera on the
-- canyon's side, level with the gap between the team's front line and the enemies', panning left and right
-- from one front line to the other. While the server shows a wave in the arena it sets the player's
-- "CamFocus" attribute (stations/WaveShow.luau): this takes the camera then, and gives it back once that
-- clears. Where the lines stand is read from the fighters (the show's folder), so the shot follows the
-- enemies as they come on and fall. No cut-ins ("way less camera zooming"): only a power hit nudges the
-- view. Display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared:WaitForChild("BattleRules"))
local FightFx = require(Shared:WaitForChild("FightFx"))

local player = Players.LocalPlayer
local STEP = "StationsArenaCamera"
local FOV = 55
local PAN_SECONDS = 9 -- one sweep from a front line to the other and back
local PAN = 0.42 -- how far either way along the gap it looks (a share of the gap); it slides a third of that
local OUT, LIFT = 0.8, 0.6 -- how far out to the side (a share of the gap) and how high (a share of that)
local NEAR, FAR = 24, 40 -- studs out to the side: the canyon's walls stand about 50 out from its middle
local active = false
local started = 0
local normalFov = 70
local current: CFrame? = nil
local ours: Vector3?, front: Vector3? = nil, nil -- the two lines, eased

-- The middle of the team's standing animals and of the enemies' front line (the FRONT standing nearest).
local function lines(): (Vector3?, Vector3?)
	local folder = Workspace:FindFirstChild(`WaveShow{player.UserId}`)
	local mine: { Vector3 }, foes: { Vector3 } = {}, {}
	for _, m in if folder then folder:GetChildren() else {} do
		local hit, hp, side = m:FindFirstChild("Hit"), m:GetAttribute("Hp"), m:GetAttribute("Side")
		if hit and hit:IsA("BasePart") and type(hp) == "number" and hp > 0 then
			if side == 1 then
				table.insert(mine, hit.Position)
			elseif side == 2 then
				table.insert(foes, hit.Position)
			end
		end
	end
	if #mine == 0 then
		return nil, nil
	end
	local mid = Vector3.zero
	for _, at in mine do
		mid += at / #mine
	end
	table.sort(foes, function(a, b)
		return (a - mid).Magnitude < (b - mid).Magnitude
	end)
	local n = math.min(#foes, BattleRules.FRONT)
	if n == 0 then
		return mid, nil
	end
	local line = Vector3.zero
	for i = 1, n do
		line += foes[i] / n
	end
	return mid, line
end

local function aim(dt: number): CFrame?
	local focus = player:GetAttribute("CamFocus")
	if typeof(focus) ~= "Vector3" then
		return nil
	end
	local mine, theirs = lines()
	mine = mine or ours or focus
	-- nobody of theirs standing (between rushes): the front line stays where it was
	theirs = theirs or front or focus + (focus - (mine :: Vector3))
	local k = 1 - math.exp(-dt * 1.5) -- a knockout or a rush coming on moves the shot smoothly
	ours = if ours then ours:Lerp(mine :: Vector3, k) else mine
	front = if front then front:Lerp(theirs :: Vector3, k) else theirs
	local a, b = ours :: Vector3, front :: Vector3
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local gap = math.clamp(along.Magnitude, 12, 70)
	local u = if along.Magnitude > 0.1 then along.Unit else Vector3.new(0, 0, -1)
	local side = u:Cross(Vector3.yAxis)
	if side.X < 0 then -- the canyon's +X side: the team on the left of the screen, clear of the plates
		side = -side
	end
	local mid = a + u * (gap / 2) + Vector3.new(0, (b.Y - a.Y) / 2, 0)
	local swing = math.sin((os.clock() - started) * 2 * math.pi / PAN_SECONDS) -- -1 our line, 1 theirs
	local out = math.clamp(gap * OUT, NEAR, FAR)
	local look = mid + u * (swing * gap * PAN)
	return CFrame.lookAt(mid + side * out + Vector3.yAxis * (out * LIFT) + u * (swing * gap * PAN / 3), look)
end

local function stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(STEP)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = normalFov
		camera.CameraType = Enum.CameraType.Custom
	end
	current, ours, front = nil, nil, nil
end

local function start()
	local camera = Workspace.CurrentCamera
	if active or camera == nil then
		return
	end
	active = true
	started = os.clock()
	normalFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	current = camera.CFrame
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = Workspace.CurrentCamera
		if cam == nil or typeof(player:GetAttribute("CamFocus")) ~= "Vector3" then
			stop()
			return
		end
		local want = aim(dt)
		if want == nil then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable -- keep it ours while the fight lasts
		current = (current :: CFrame):Lerp(want, 1 - math.exp(-dt * 2.5))
		-- a jolt shakes it for a moment: a Perfect, a combo, a boss landing (the HUD sets these)
		local jolt, joltAt = player:GetAttribute("CamShake"), player:GetAttribute("CamShakeAt")
		local amount = if type(jolt) == "number" and type(joltAt) == "number"
			then FightFx.shake(os.clock() - joltAt, jolt)
			else 0
		local t = os.clock() * 40
		cam.CFrame = (current :: CFrame) * CFrame.new(math.sin(t) * amount, math.cos(t * 1.3) * amount, 0)
		-- a power hit nudges the view in a little (Creatures.client sets these on this player only)
		local strength, at = player:GetAttribute("CamPunch"), player:GetAttribute("CamPunchAt")
		local punch = if type(strength) == "number" and type(at) == "number"
			then FightFx.punch(os.clock() - at, strength)
			else 0
		cam.FieldOfView = FOV - 1.5 * punch
	end)
end

local function sync()
	if typeof(player:GetAttribute("CamFocus")) == "Vector3" then
		start()
	else
		stop()
	end
end
player:GetAttributeChangedSignal("CamFocus"):Connect(sync)
sync()
