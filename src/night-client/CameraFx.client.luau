--!strict
-- Hundred Demon Night camera (GDD C9, B6): applies ClientState shake and FOV kicks (shake only
-- when the setting is on), speed FOV from Relay's movement, and the Victory podium camera.
-- Client-only; it sends nothing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera

local BASE_FOV = 70
local PODIUM_TIME = 7

local podiumUntil = 0
local podiumFocus = Vector3.zero

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Victory: a slow low orbit around the winners, centred on the participants' average position.
local lastState = ClientState.status().state
ClientState.statusValue:GetPropertyChangedSignal("Value"):Connect(function()
	local s = ClientState.status()
	if s.state == "Victory" and lastState ~= "Victory" and ClientState.isParticipant() then
		local sum, count = Vector3.zero, 0
		for _, id in s.ids do
			local p = Players:GetPlayerByUserId(id)
			local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				sum += r.Position
				count += 1
			end
		end
		if count > 0 then
			podiumFocus = sum / count
			podiumUntil = os.clock() + PODIUM_TIME
		end
	end
	lastState = s.state
end)

local podiumWasOn = false
RunService:BindToRenderStep("NightCameraFx", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local now = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if now < podiumUntil then
		podiumWasOn = true
		camera.CameraType = Enum.CameraType.Scriptable
		local t = (PODIUM_TIME - (podiumUntil - now)) * 0.35
		local eye = podiumFocus + Vector3.new(math.cos(t) * 18, 5 + t * 1.5, math.sin(t) * 18)
		camera.CFrame = CFrame.lookAt(eye, podiumFocus + Vector3.new(0, 3, 0))
		camera.FieldOfView += (60 - camera.FieldOfView) * math.min(dt * 4, 1)
		return
	elseif podiumWasOn then
		podiumWasOn = false
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	if camera.CameraType ~= Enum.CameraType.Custom then
		return -- the start menu's orbit owns the camera
	end

	local r = myRoot()
	local speed = 0
	if r then
		local v = r.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	ClientState.fov = math.max(0, ClientState.fov - dt * 30)
	local target = BASE_FOV + math.clamp((speed - 24) * 0.45, 0, 20) + ClientState.fov
	camera.FieldOfView += (target - camera.FieldOfView) * math.min(dt * 8, 1)

	if humanoid then
		if now < ClientState.shakeUntil and ClientState.settings.shake then
			local size = ClientState.shakeSize
			humanoid.CameraOffset = Vector3.new(math.random(-10, 10) / 10 * size, math.random(-10, 10) / 10 * size, 0)
		else
			humanoid.CameraOffset = Vector3.zero
		end
	end
end)
