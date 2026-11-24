--!strict
-- The loading cover (beta blocker 5, SHANNON's pick A): while the server waits for a save another server still
-- holds (`ProfileLoading`, kit Saves' waitBusy), the screen says so instead of showing a blank ranch. Display only.

local Players = game:GetService("Players")

local Style = require(script.Parent:WaitForChild("Style"))

local player = Players.LocalPlayer
local screen = Instance.new("ScreenGui")
screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset, screen.DisplayOrder = "StationsLoading", false, true, 50
screen.Enabled = false
local cover = Instance.new("Frame")
cover.Size, cover.BackgroundColor3, cover.BorderSizePixel = UDim2.fromScale(1, 1), Style.C.night, 0
cover.Parent = screen
local words = Style.text(cover, "Loading your ranch...", 32, Style.C.sand, UDim2.fromOffset(600, 48))
words.AnchorPoint, words.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.46)
words.TextXAlignment = Enum.TextXAlignment.Center
local hint =
	Style.text(cover, "Your save is still closing on another server.", 18, Style.C.muted, UDim2.fromOffset(600, 28))
hint.AnchorPoint, hint.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.53)
hint.TextXAlignment = Enum.TextXAlignment.Center
screen.Parent = player:WaitForChild("PlayerGui")

local function sync()
	screen.Enabled = player:GetAttribute("ProfileLoading") == true
end
player:GetAttributeChangedSignal("ProfileLoading"):Connect(sync)
sync()
