--!strict
-- Hundred Demon Night movement kit (GDD C4), copied from Relay: double jump, dash with
-- afterimages, Ninja animations and speed lines. Launch and boost pads and the local style
-- meter are gone (the meter is server-side). A dash also sends Combat("dash"); the server
-- decides whether it grants invulnerability. FOV and shake are applied by CameraFx.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local combat = ReplicatedStorage:WaitForChild("NightRemotes"):WaitForChild("Combat") :: RemoteEvent

local player = Players.LocalPlayer :: Player

local DOUBLE_JUMP_SPEED = 52
local DASH_SPEED = 95
local DASH_COOLDOWN = 1

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local airborneSince = 0
local doubleUsed = false
local dashUsed = false
local lastDash = -math.huge
-- Humanoids brake horizontal speed back to WalkSpeed within a few frames, so dashes hold their
-- velocity for a short window (easing to half) instead of setting it once.
local carryVel: Vector3? = nil
local carryStart = 0
local carryTime = 0

local function carry(velocity: Vector3, duration: number)
	carryVel, carryStart, carryTime = velocity, os.clock(), duration
end

-- UI ------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "NightMovement"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

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
			ghost.Color = if player:GetAttribute("Trigger") == true then Color3.fromRGB(255, 60, 70) else item.Color
			ghost.Transparency = 0.45
			ghost.Parent = Workspace
			TweenService:Create(ghost, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			task.delay(0.4, ghost.Destroy, ghost)
		end
	end
end

-- Roblox's own Ninja animation pack (R15), for an anime run. Asset IDs are in docs/assets/register.md.
local NINJA = {
	run = { RunAnim = "rbxassetid://656118852" },
	walk = { WalkAnim = "rbxassetid://656121766" },
	jump = { JumpAnim = "rbxassetid://656117878" },
	fall = { FallAnim = "rbxassetid://656115606" },
	climb = { ClimbAnim = "rbxassetid://656114359" },
	idle = { Animation1 = "rbxassetid://656117400", Animation2 = "rbxassetid://656117400" },
}

local function ninja(newCharacter: Model)
	local h = newCharacter:FindFirstChildOfClass("Humanoid")
	local animate = newCharacter:WaitForChild("Animate", 5)
	if h == nil or animate == nil or h.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	for setName, anims in NINJA do
		local set = animate:FindFirstChild(setName)
		for animName, id in anims do
			local anim = set and set:FindFirstChild(animName)
			if anim and anim:IsA("Animation") then
				anim.AnimationId = id
			end
		end
	end
end

-- Movement ------------------------------------------------------------------------------------

local function downed(): boolean
	local hp = player:GetAttribute("HP")
	return ClientState.isParticipant() and type(hp) == "number" and hp <= 0
end

local function onCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	doubleUsed, dashUsed = false, false
	task.spawn(ninja, newCharacter);
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
	if h == nil or r == nil or h.Health <= 0 or doubleUsed or downed() then
		return
	end
	if h.FloorMaterial == Enum.Material.Air and airborneSince > 0 and os.clock() - airborneSince > 0.15 then
		doubleUsed = true
		local v = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(v.X, DOUBLE_JUMP_SPEED, v.Z)
		afterimage()
		ClientState.sound(ClientState.SFX.whoosh, 0.6)
	end
end)

local function dash(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local h, r = humanoid, root
	if state ~= Enum.UserInputState.Begin or h == nil or r == nil or h.Health <= 0 or downed() then
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
	ClientState.fovKick(14)
	for i = 0, 3 do
		task.delay(i * 0.05, afterimage)
	end
	ClientState.sound(ClientState.SFX.dash, 0.7)
	local stacks = ClientState.json(player:GetAttribute("Blessings"))
	local thunder = type(stacks) == "table" and (tonumber(stacks.thunder) or 0) > 0
	if ClientState.fighting() then
		combat:FireServer("dash")
	end
	ClientState.dashed(thunder)
	return Enum.ContextActionResult.Sink
end
-- Touch DASH is drawn by CombatFx with the other combat buttons, so no CAS touch button here.
ContextActionService:BindAction("NightDash", dash, false, Enum.KeyCode.Q, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonX)
ClientState.Dash = function()
	local _ = dash("NightDash", Enum.UserInputState.Begin)
end

RunService.RenderStepped:Connect(function()
	local r = root
	if r == nil or r.Parent == nil then
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

	-- Speed lines from horizontal speed.
	local v = r.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local intensity = math.clamp((speed - 32) / 40, 0, 1)
	for _, f in streaks do
		f.BackgroundTransparency = 1 - intensity * math.random(25, 70) / 100
	end
end)

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
gui.Parent = player:WaitForChild("PlayerGui")
