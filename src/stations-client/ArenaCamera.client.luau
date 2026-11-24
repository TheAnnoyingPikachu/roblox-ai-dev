--!strict
-- The fight camera (decisions 0045, 0097, 0108): behind the player's own team, over its Titan and its
-- front line, looking at the crowd and the castle beyond. While the server shows a wave on the battlefield
-- it sets the player's "CamFrom" (the middle of their team's front line) and "CamFocus" (a point ahead of
-- it, the way the team looks) attributes (stations/WaveShow.luau): this takes the camera then, and gives it
-- back once they clear. "CamScale" (0.55 to 1) brings it nearer a team of small animals. Every player of a
-- shared fight has their own. It is an action camera (decision 0106, SHANNON: "pans left and right to show
-- the front lines"): it sways slowly from side to side behind the team, looks at the clash (between the team's
-- line and the nearest standing foe, so it follows a rush as it comes on) and comes a little nearer once
-- the lines meet. No cut-ins and little zoom: only a power hit nudges the view. Display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FightFx = require(Shared:WaitForChild("FightFx"))

local player = Players.LocalPlayer
local STEP = "StationsArenaCamera"
local FOV = 70
local UP, BACK, LOOK_UP = 48, 88, 2 -- how high and how far behind the front line it stands; how far above the focus it looks
local SWAY, SWAY_SECONDS = 16, 9 -- the pan: studs to either side, and the seconds for a sweep there and back
local NEAR = 0.82 -- how near it comes (of BACK and UP) once the lines meet
local active = false
local normalFov = 70
local current: CFrame? = nil

-- The nearest standing foe of the fight to `from` (later rushes wait far below the field: not those).
local function nearestFoe(from: Vector3): Vector3?
	local name = player:GetAttribute("FightFolder")
	local folder = Workspace:FindFirstChild(if type(name) == "string" then name else `WaveShow{player.UserId}`)
	if folder == nil then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in folder:GetChildren() do
		local hp = m:GetAttribute("Hp")
		if m:IsA("Model") and m:GetAttribute("Side") == 2 and (type(hp) ~= "number" or hp > 0) then
			local p = m:GetPivot().Position
			local d = ((p - from) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestD and math.abs(p.Y - from.Y) < 40 then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function aim(): CFrame?
	local from, focus = player:GetAttribute("CamFrom"), player:GetAttribute("CamFocus")
	if typeof(from) ~= "Vector3" or typeof(focus) ~= "Vector3" then
		return nil
	end
	local to = Vector3.new(focus.X - from.X, 0, focus.Z - from.Z)
	local u = if to.Magnitude > 0.1 then to.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-u.Z, 0, u.X)
	local scale = player:GetAttribute("CamScale")
	local k = if type(scale) == "number" then scale else 1
	-- the clash: halfway to the nearest foe, which the camera looks a little towards from the focus
	local foe = nearestFoe(from)
	local look, near = focus, 0
	if foe then
		local gap = ((foe - from) * Vector3.new(1, 0, 1)).Magnitude
		look = focus:Lerp(Vector3.new((from.X + foe.X) / 2, focus.Y, (from.Z + foe.Z) / 2), 0.55)
		near = math.clamp((60 - gap) / 40, 0, 1) -- from 60 studs off to 20: the lines meeting
	end
	local d = 1 - (1 - NEAR) * near
	local sway = math.sin(os.clock() * 2 * math.pi / SWAY_SECONDS) * SWAY * k
	local at = from - u * BACK * k * d + side * sway + Vector3.yAxis * UP * k * d
	return CFrame.lookAt(at, look + side * sway * 0.4 + Vector3.yAxis * LOOK_UP)
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
	normalFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	current = camera.CFrame
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local cam = Workspace.CurrentCamera
		if cam == nil or typeof(player:GetAttribute("CamFocus")) ~= "Vector3" then
			stop()
			return
		end
		local want = aim()
		if want == nil then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable -- keep it ours while the fight lasts
		current = (current :: CFrame):Lerp(want, 1 - math.exp(-dt * 2))
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
