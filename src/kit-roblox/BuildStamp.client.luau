--!strict
-- Shows the short build stamp in the bottom-right corner (SPIRE-002). A playtest note only counts
-- when it records the stamp it saw (docs/architecture/spire.md section 9). Mapped into every place
-- as StarterPlayerScripts.BuildStamp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildStamp = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("BuildStamp"))

local info = ReplicatedStorage:WaitForChild("BuildInfo", 10)
local text = if info and info:IsA("StringValue") then info.Value else nil

local gui = Instance.new("ScreenGui")
gui.Name = "BuildStamp"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -6, 1, -4)
label.Size = UDim2.fromOffset(90, 14)
label.BackgroundTransparency = 1
label.Font = Enum.Font.Code
label.TextSize = 12
label.TextColor3 = Color3.new(1, 1, 1)
label.TextTransparency = 0.5
label.TextStrokeTransparency = 0.8
label.TextXAlignment = Enum.TextXAlignment.Right
label.Text = "build " .. BuildStamp.label(text)
label.Parent = gui
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
