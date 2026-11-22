--!strict
-- The fight camera (decision 0045). While the server shows a wave in the arena it sets the player's
-- "CamFocus" (the middle of the fight) and "CamRadius" (how far the fighters spread) attributes
-- (stations/WaveShow.luau). This takes the camera, stands it back and above on the dais side so both
-- teams show whatever the screen's shape, and lets it drift a little; clearing the attributes gives
-- the camera back. Display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FightFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FightFx"))
local UiLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiLayout"))

local player = Players.LocalPlayer
local STEP = "StationsArenaCamera"
local FOV = 55
local PITCH = math.rad(31) -- high enough to look over the arena walls and the gallows
local CUT_IN = 0.62 -- how far towards the target a cut-in takes the camera
-- Behind the team (decision 0097): low and only a little to the side, so the team fills the front; the
-- fight opens with a sweep in from wide and high over ENTRANCE seconds.
local YAW, LOW_PITCH, ENTRANCE = math.rad(16), math.rad(22), 2.6
local LOWER = 0.36 -- of the radius: aim low so the fight sits above the panel along the bottom
local active = false
local started = 0
local normalFov = 70
local current: CFrame? = nil

local function aim(camera: Camera): CFrame?
	local focus, radius = player:GetAttribute("CamFocus"), player:GetAttribute("CamRadius")
	if typeof(focus) ~= "Vector3" or type(radius) ~= "number" then
		return nil
	end
	local size = camera.ViewportSize
	local away = UiLayout.fightDistance(radius, FOV, size.X / math.max(1, size.Y))
	local age = os.clock() - started
	local u = math.clamp(age / ENTRANCE, 0, 1)
	local sweep = 1 - u * u * (3 - 2 * u) -- 1 at the start of the entrance, 0 once it is done
	local yaw = YAW + math.sin(age * 0.3) * math.rad(4) + sweep * math.rad(70)
	local pitch = LOW_PITCH + sweep * (PITCH - LOW_PITCH + math.rad(8))
	away *= 1 + sweep * 0.7
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	local look = focus - Vector3.new(0, radius * LOWER, 0)
	return CFrame.lookAt(look + dir * away, look)
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
	current = nil
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
		local want = aim(cam)
		if want == nil then
			return -- the radius has not arrived yet: attributes reach the client one at a time
		end
		cam.CameraType = Enum.CameraType.Scriptable -- keep it ours while the fight lasts
		-- a power hit or the killing blow cuts in towards its target and back out (Creatures.client)
		local cutAt, cutPos = player:GetAttribute("CamCutAt"), player:GetAttribute("CamCut")
		local cut = if type(cutAt) == "number" and typeof(cutPos) == "Vector3"
			then FightFx.cut(os.clock() - cutAt)
			else 0
		if cut > 0 then
			local target = cutPos :: Vector3
			want = want:Lerp(CFrame.lookAt(want.Position:Lerp(target, CUT_IN), target), cut)
		end
		current = (current :: CFrame):Lerp(want, 1 - math.exp(-dt * (2.5 + 7 * cut)))
		-- a jolt shakes it for a moment: a Perfect, a combo, a boss landing (the HUD sets these)
		local jolt, joltAt = player:GetAttribute("CamShake"), player:GetAttribute("CamShakeAt")
		local amount = if type(jolt) == "number" and type(joltAt) == "number"
			then FightFx.shake(os.clock() - joltAt, jolt)
			else 0
		local t = os.clock() * 40
		cam.CFrame = (current :: CFrame) * CFrame.new(math.sin(t) * amount, math.cos(t * 1.3) * amount, 0)
		-- a hit punches the view in for a moment (Creatures.client sets these on this player only)
		local strength, at = player:GetAttribute("CamPunch"), player:GetAttribute("CamPunchAt")
		local punch = if type(strength) == "number" and type(at) == "number"
			then FightFx.punch(os.clock() - at, strength)
			else 0
		cam.FieldOfView = FOV - 4 * punch
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
