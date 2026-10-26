--!strict
-- Shows the server's RelayStatus text at the top of the screen, plus big anime-style callouts
-- (countdown, GO!, finishes, eliminations, victory). Read-only: the client sends nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local status = ReplicatedStorage:WaitForChild("RelayStatus") :: StringValue

local gui = Instance.new("ScreenGui")
gui.Name = "RelayStatus"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 12)
label.Size = UDim2.new(0.6, 0, 0, 44)
label.BackgroundColor3 = Color3.fromRGB(20, 14, 24)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local callout = Instance.new("TextLabel")
callout.AnchorPoint = Vector2.new(0.5, 0.5)
callout.Position = UDim2.fromScale(0.5, 0.36)
callout.Size = UDim2.fromScale(0.7, 0.18)
callout.BackgroundTransparency = 1
callout.Font = Enum.Font.GothamBlack
callout.TextScaled = true
callout.TextTransparency = 1
callout.Rotation = -4
callout.Parent = gui
local calloutStroke = Instance.new("UIStroke")
calloutStroke.Thickness = 6
calloutStroke.Color = Color3.fromRGB(20, 10, 20)
calloutStroke.Transparency = 1
calloutStroke.Parent = callout
local calloutScale = Instance.new("UIScale")
calloutScale.Parent = callout

-- Slams a word onto the screen, holds it, then fades it out.
local function slam(text: string, colour: Color3, hold: number)
	callout.Text = text
	callout.TextColor3 = colour
	callout.TextTransparency = 0
	calloutStroke.Transparency = 0
	calloutScale.Scale = 2.2
	TweenService
		:Create(calloutScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local shown = text
	task.delay(hold, function()
		if callout.Text == shown then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(callout, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(calloutStroke, fade, { Transparency = 1 }):Play()
		end
	end)
end

local previous = ""
local function update()
	local text = status.Value
	label.Text = text
	local count = string.match(text, "Get ready… (%d)")
	if count then
		slam(count, Color3.fromRGB(255, 230, 120), 0.7)
	elseif string.find(text, "s left") and string.find(previous, "Get ready") then
		slam("GO!", Color3.fromRGB(255, 80, 80), 0.9)
	elseif string.find(text, "finished!") then
		slam(string.upper(text), Color3.fromRGB(120, 255, 170), 1.4)
	elseif string.find(text, "is out!") then
		slam(string.upper(text), Color3.fromRGB(255, 70, 70), 1.6)
	elseif string.find(text, "wins!") then
		slam(string.upper(text), Color3.fromRGB(255, 210, 60), 3)
	end
	previous = text
end
status:GetPropertyChangedSignal("Value"):Connect(update)
update()

gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
