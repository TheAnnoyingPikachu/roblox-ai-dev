--!strict
-- Relay Rounds camera moments: a sweeping intro over the start line when a round begins, and a
-- spectator camera that follows the baton carriers while you are out or waiting. Client-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local status = ReplicatedStorage:WaitForChild("RelayStatus") :: StringValue
local player = Players.LocalPlayer :: Player
local camera = Workspace.CurrentCamera

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Intro: from high over the circuit down to just behind you, during the get-ready countdown.
local flying = false
local function flyover()
	local root = myRoot()
	if flying or root == nil or player.Team == nil then
		return
	end
	flying = true
	local look = root.CFrame.LookVector
	local finish = CFrame.lookAt(root.Position - look * 12 + Vector3.new(0, 6, 0), root.Position + look * 20)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(-80, 120, -60), root.Position)
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(2.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
		{ CFrame = finish }
	)
	tween:Play()
	tween.Completed:Wait()
	camera.CameraType = Enum.CameraType.Custom
	flying = false
end

-- Spectate ------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RelaySpectate"
gui.ResetOnSpawn = false

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -48)
bar.Size = UDim2.fromOffset(420, 44)
bar.BackgroundTransparency = 1
bar.Visible = false
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local function makeButton(label: string, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 44)
	b.BackgroundColor3 = Color3.fromRGB(32, 24, 40)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.Text = label
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	b.Parent = bar
	return b
end
local spectateButton = makeButton("SPECTATE", 180)
local nextButton = makeButton("NEXT ▶", 120)
nextButton.Visible = false

local watching: Player? = nil

local function carriers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character and p.Character:FindFirstChild("Baton") then
			table.insert(list, p)
		end
	end
	return list
end

local function stopWatching()
	watching = nil
	nextButton.Visible = false
	spectateButton.Text = "SPECTATE"
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function watchNext()
	local list = carriers()
	if #list == 0 then
		stopWatching()
		return
	end
	local index = (watching and table.find(list, watching) or 0) % #list + 1
	watching = list[index]
	local humanoid = list[index].Character and list[index].Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	spectateButton.Text = `WATCHING {string.upper(list[index].DisplayName)}`
	nextButton.Visible = #list > 1
end

spectateButton.Activated:Connect(function()
	if watching then
		stopWatching()
	else
		watchNext()
	end
end)
nextButton.Activated:Connect(watchNext)

-- The bar shows mid-round whenever you are not carrying the baton yourself.
task.spawn(function()
	while true do
		task.wait(0.5)
		local racing = string.find(status.Value, "s left") ~= nil
		local carrying = player.Character ~= nil and player.Character:FindFirstChild("Baton") ~= nil
		bar.Visible = racing and not carrying and #carriers() > 0
		if watching and (not bar.Visible or not table.find(carriers(), watching)) then
			if bar.Visible then
				watchNext()
			else
				stopWatching()
			end
		end
	end
end)

status:GetPropertyChangedSignal("Value"):Connect(function()
	if string.find(status.Value, "Get ready… 3") then
		task.delay(0.05, flyover)
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
