--!strict
-- The loading cover (beta blocker 5, SHANNON's pick A; its look from the Moments board): while the server waits
-- for a save another server still holds (`ProfileLoading`, kit Saves' waitBusy), the screen says so, says plainly
-- that nothing is lost, and gives a tip. Display only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Style = require(script.Parent:WaitForChild("Style"))
local C = Style.C

local TIPS = {
	"Tip: start an egg before you fight. An empty nest is wasted time.",
	"Tip: training goes on while you are away. Fill every station before you leave.",
	"Tip: play with friends. Everyone in the portal's ring joins the wave, and everyone gets full pay.",
	"Tip: four of one animal fuse into a coat of the next tier.",
}

local player = Players.LocalPlayer
local screen = Instance.new("ScreenGui")
screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset, screen.DisplayOrder = "StationsLoading", false, true, 50
screen.Enabled = false
local cover = Instance.new("Frame")
cover.Size, cover.BackgroundColor3, cover.BorderSizePixel = UDim2.fromScale(1, 1), C.night, 0
cover.Parent = screen
local card = Style.panel(cover, UDim2.fromOffset(520, 230))
card.AnchorPoint, card.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
local title = Style.text(card, "Loading your ranch", 30, C.text, UDim2.new(1, -48, 0, 38))
title.Position = UDim2.fromOffset(24, 20)
local words = Style.text(
	card,
	"Your save is still closing on another server. This takes a moment, and nothing is lost.",
	17,
	C.muted,
	UDim2.new(1, -48, 0, 46)
)
words.Position = UDim2.fromOffset(24, 62)
-- shortcut: the wait has no measure of its own, so the bar is a stripe that sweeps; give it the real share if
-- kit Saves ever reports one
local track = Style.frame(card, UDim2.new(1, -48, 0, 16), Color3.new(1, 1, 1))
track.Position, track.ClipsDescendants = UDim2.fromOffset(24, 122), true
Style.round(track, 8)
Style.stroke(track, C.ink, 2)
local stripe = Style.frame(track, UDim2.fromScale(0.3, 1), C.good)
Style.round(stripe, 8)
local tip = Style.text(card, TIPS[1], 15, C.muted, UDim2.new(1, -48, 0, 44))
tip.Position = UDim2.fromOffset(24, 154)
screen.Parent = player:WaitForChild("PlayerGui")

local sweep: RBXScriptConnection? = nil
local function sync()
	local on = player:GetAttribute("ProfileLoading") == true
	screen.Enabled = on
	if on and sweep == nil then
		tip.Text = TIPS[math.random(#TIPS)]
		local started = os.clock()
		sweep = RunService.RenderStepped:Connect(function()
			stripe.Position = UDim2.fromScale(((os.clock() - started) * 0.5) % 1.3 - 0.3, 0)
		end)
	elseif not on and sweep then
		sweep:Disconnect()
		sweep = nil
	end
end
player:GetAttributeChangedSignal("ProfileLoading"):Connect(sync)
sync()
