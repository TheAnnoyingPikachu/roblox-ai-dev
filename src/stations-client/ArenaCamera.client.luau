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
local LOWER = 0.28 -- of the radius: aim low so the fight sits above the result panel
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
	local yaw = math.rad(34) + math.sin((os.clock() - started) * 0.3) * math.rad(6) -- from the dais side
	local dir = Vector3.new(math.sin(yaw) * math.cos(PITCH), math.sin(PITCH), math.cos(yaw) * math.cos(PITCH))
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
		current = (current :: CFrame):Lerp(want, 1 - math.exp(-dt * 2.5))
		cam.CFrame = current :: CFrame
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
