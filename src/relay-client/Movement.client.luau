--!strict
-- Relay Rounds movement kit and style meter (GDD C2, G). Runs on the client because Roblox
-- characters are client-simulated; it sends nothing to the server. The server still decides
-- legs, hazards and wins, and the style meter is cosmetic.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local StyleRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StyleRules"))

local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera

local DOUBLE_JUMP_SPEED = 52
local DASH_SPEED = 95
local DASH_COOLDOWN = 1
local BOOST_HOP = 38
local BASE_FOV = 70

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local airborneSince = 0
local doubleUsed = false
local dashUsed = false
local lastDash = -math.huge
local lastPad = -math.huge
local fovKick = 0
local shakeUntil = 0
local lastPosition: Vector3? = nil
local hadBaton = false
local style = StyleRules.new()
-- Humanoids brake horizontal speed back to WalkSpeed within a few frames, so dashes and pads
-- hold their velocity for a short window (easing to half) instead of setting it once.
local carryVel: Vector3? = nil
local carryStart = 0
local carryTime = 0

local function carry(velocity: Vector3, duration: number)
	carryVel, carryStart, carryTime = velocity, os.clock(), duration
end

-- UI ------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RelayMovement"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local lines = Instance.new("Frame")
lines.Size = UDim2.fromScale(1, 1)
lines.BackgroundTransparency = 1
lines.Parent = gui
local streaks: { Frame } = {}
for i = 1, 32 do
	local angle = (i / 32) * math.pi * 2
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Size = UDim2.new(0, 3, 0.16, 0)
	f.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.46, 0.5 + math.sin(angle) * 0.46)
	f.Rotation = math.deg(angle) + 90
	f.BackgroundTransparency = 1
	f.Parent = lines
	streaks[i] = f
end

local meter = Instance.new("Frame")
meter.AnchorPoint = Vector2.new(1, 0.5)
meter.Position = UDim2.new(1, -24, 0.42, 0)
meter.Size = UDim2.fromOffset(220, 150)
meter.BackgroundTransparency = 1
meter.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = meter
local letter = Instance.new("TextLabel")
letter.Size = UDim2.new(1, 0, 0, 96)
letter.BackgroundTransparency = 1
letter.Font = Enum.Font.GothamBlack
letter.TextScaled = true
letter.TextXAlignment = Enum.TextXAlignment.Right
letter.Text = "D"
letter.Parent = meter
local letterStroke = Instance.new("UIStroke")
letterStroke.Thickness = 4
letterStroke.Parent = letter
local rankName = Instance.new("TextLabel")
rankName.Position = UDim2.fromOffset(0, 92)
rankName.Size = UDim2.new(1, 0, 0, 28)
rankName.BackgroundTransparency = 1
rankName.Font = Enum.Font.GothamBold
rankName.TextScaled = true
rankName.TextXAlignment = Enum.TextXAlignment.Right
rankName.TextColor3 = Color3.new(1, 1, 1)
rankName.Text = "Dull"
rankName.Parent = meter
Instance.new("UIStroke").Parent = rankName
local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(40, 126)
barBack.Size = UDim2.new(1, -40, 0, 8)
barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
barBack.BackgroundTransparency = 0.3
barBack.BorderSizePixel = 0
barBack.Parent = meter
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BorderSizePixel = 0
bar.Parent = barBack

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -12)
hint.Size = UDim2.fromOffset(520, 22)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextTransparency = 0.25
hint.Text = "JUMP twice to double jump  ·  Q / SHIFT to air dash  ·  ride the glowing pads"
hint.Parent = gui
Instance.new("UIStroke").Parent = hint

local RANK_COLOURS = {
	Color3.fromRGB(170, 170, 180),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(110, 255, 140),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 60, 90),
	Color3.fromRGB(255, 60, 220),
}
local shownRank = 1

local function refreshMeter()
	local index = StyleRules.rank(style.points)
	local r = StyleRules.RANKS[index]
	letter.Text = r.letter
	rankName.Text = r.name
	letter.TextColor3 = RANK_COLOURS[index]
	bar.BackgroundColor3 = RANK_COLOURS[index]
	local nextMin = if StyleRules.RANKS[index + 1] then StyleRules.RANKS[index + 1].min else StyleRules.MAX
	bar.Size = UDim2.fromScale(math.clamp((style.points - r.min) / math.max(nextMin - r.min, 1), 0, 1), 1)
	meter.Visible = style.points > 0.5
	if index > shownRank then
		scale.Scale = 1.5
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	shownRank = index
end

local function score(event: string)
	style = StyleRules.add(style, event)
	refreshMeter()
end

-- Effects -------------------------------------------------------------------------------------

-- Glowing afterimage of the character that fades in place.
local function afterimage()
	if character == nil then
		return
	end
	for _, item in character:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			local ghost = Instance.new("Part")
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CastShadow = false
			ghost.Size = item.Size
			ghost.CFrame = item.CFrame
			ghost.Material = Enum.Material.Neon
			ghost.Color = item.Color
			ghost.Transparency = 0.45
			ghost.Parent = Workspace
			TweenService:Create(ghost, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			task.delay(0.4, ghost.Destroy, ghost)
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Movement ------------------------------------------------------------------------------------

local function onCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	rayParams.FilterDescendantsInstances = { newCharacter }
	doubleUsed, dashUsed, lastPosition = false, false, nil
	style = StyleRules.reset()
	refreshMeter();
	(humanoid :: Humanoid).StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
			if airborneSince == 0 then
				airborneSince = os.clock()
			end
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airborneSince, doubleUsed, dashUsed = 0, false, false
		end
	end)
end

UserInputService.JumpRequest:Connect(function()
	local h, r = humanoid, root
	if h == nil or r == nil or h.Health <= 0 or doubleUsed then
		return
	end
	if h.FloorMaterial == Enum.Material.Air and airborneSince > 0 and os.clock() - airborneSince > 0.15 then
		doubleUsed = true
		local v = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(v.X, DOUBLE_JUMP_SPEED, v.Z)
		afterimage()
		score("doubleJump")
	end
end)

local function dash(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local h, r = humanoid, root
	if state ~= Enum.UserInputState.Begin or h == nil or r == nil or h.Health <= 0 then
		return Enum.ContextActionResult.Pass
	end
	local airborne = h.FloorMaterial == Enum.Material.Air
	if os.clock() - lastDash < DASH_COOLDOWN or (airborne and dashUsed) then
		return Enum.ContextActionResult.Sink
	end
	lastDash = os.clock()
	dashUsed = airborne
	local dir = h.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = r.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	r.AssemblyLinearVelocity = dir * DASH_SPEED + Vector3.new(0, 12, 0)
	carry(dir * DASH_SPEED, 0.25)
	fovKick = 14
	for i = 0, 3 do
		task.delay(i * 0.05, afterimage)
	end
	score("dash")
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("RelayDash", dash, true, Enum.KeyCode.Q, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("RelayDash", "DASH")
ContextActionService:SetPosition("RelayDash", UDim2.new(1, -170, 1, -150))

local statusValue = ReplicatedStorage:WaitForChild("RelayStatus") :: StringValue

RunService.RenderStepped:Connect(function(dt)
	local h, r = humanoid, root
	if h == nil or r == nil or r.Parent == nil then
		return
	end

	local carried = carryVel
	if carried then
		local t = (os.clock() - carryStart) / carryTime
		if t < 1 then
			local v = r.AssemblyLinearVelocity
			local f = 1 - t * 0.5
			r.AssemblyLinearVelocity = Vector3.new(carried.X * f, v.Y, carried.Z * f)
		else
			carryVel = nil
		end
	end

	-- Launch and boost pads under your feet (marked by the server with attributes).
	local hit = Workspace:Raycast(r.Position, Vector3.new(0, -4.5, 0), rayParams)
	if hit and os.clock() - lastPad > 0.5 then
		local launch = hit.Instance:GetAttribute("Launch") :: number?
		local boost = hit.Instance:GetAttribute("Boost") :: number?
		if launch then
			lastPad = os.clock()
			local forward = -hit.Instance.CFrame.LookVector
			r.AssemblyLinearVelocity = forward * 22 + Vector3.new(0, launch, 0)
			carry(forward * 22, 0.9)
			shakeUntil = os.clock() + 0.3
			fovKick = 18
			score("launch")
		elseif boost then
			lastPad = os.clock()
			local forward = -hit.Instance.CFrame.LookVector
			r.AssemblyLinearVelocity = forward * boost + Vector3.new(0, BOOST_HOP, 0)
			carry(forward * boost, 0.7)
			fovKick = 16
			afterimage()
			score("boost")
		end
	end

	-- A sudden jump in position means the server sent you back (fall or hazard): style resets.
	if lastPosition and (r.Position - lastPosition).Magnitude > 40 then
		style = StyleRules.reset()
		refreshMeter()
	end
	lastPosition = r.Position

	-- Passing or finishing with the baton counts as a clean leg.
	local holding = character ~= nil and character:FindFirstChild("Baton") ~= nil
	if hadBaton and not holding and h.Health > 0 and not string.find(statusValue.Value, "out") then
		score("legClear")
	end
	hadBaton = holding

	if h.FloorMaterial == Enum.Material.Air and airborneSince > 0 and os.clock() - airborneSince > 0.5 then
		style = StyleRules.airtime(style, dt)
	else
		style = StyleRules.decay(style, dt)
	end
	refreshMeter()

	-- Speed lines and FOV from horizontal speed; camera shake after launches.
	local v = r.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local intensity = math.clamp((speed - 32) / 40, 0, 1)
	for _, f in streaks do
		f.BackgroundTransparency = 1 - intensity * math.random(25, 70) / 100
	end
	fovKick = math.max(0, fovKick - dt * 30)
	local target = BASE_FOV + math.clamp((speed - 24) * 0.45, 0, 20) + fovKick
	camera.FieldOfView += (target - camera.FieldOfView) * math.min(dt * 8, 1)
	if os.clock() < shakeUntil then
		h.CameraOffset = Vector3.new(math.random(-10, 10) / 40, math.random(-10, 10) / 40, 0)
	else
		h.CameraOffset = Vector3.zero
	end
end)

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
gui.Parent = player:WaitForChild("PlayerGui")
