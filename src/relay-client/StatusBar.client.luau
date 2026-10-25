--!strict
-- Shows the server's RelayStatus text at the top of the screen. Read-only: the client sends nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local status = ReplicatedStorage:WaitForChild("RelayStatus") :: StringValue

local gui = Instance.new("ScreenGui")
gui.Name = "RelayStatus"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 12)
label.Size = UDim2.new(0.6, 0, 0, 44)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.4
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local function update()
	label.Text = status.Value
end
status:GetPropertyChangedSignal("Value"):Connect(update)
update()

gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
