--!strict
-- Kit (Roblox side): small UI building blocks so each game's menu does not rebuild buttons,
-- panels and toasts from scratch. Client only. Text formatting is in kit/Format (tested).
--
--   local screen = Ui.screen("SpireMenu")
--   local panel = Ui.panel(screen, { size = UDim2.fromOffset(320, 200), anchor = "center" })
--   Ui.button(panel, "Buy floor", function() ... end)
--   Ui.toast(screen, "Floor 3 built")
--
-- Restyle per game by passing a theme to Ui.setTheme at start (art bible colours and fonts).
-- Every interactive element is at least 44 px tall for touch.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = {}

export type Theme = {
	font: Enum.Font,
	text: Color3,
	muted: Color3,
	panel: Color3,
	panelTransparency: number,
	accent: Color3,
	accentText: Color3,
	danger: Color3,
	radius: number,
	padding: number,
}

Ui.theme = {
	font = Enum.Font.GothamBold,
	text = Color3.fromRGB(245, 245, 250),
	muted = Color3.fromRGB(170, 175, 190),
	panel = Color3.fromRGB(20, 22, 30),
	panelTransparency = 0.15,
	accent = Color3.fromRGB(0, 200, 255),
	accentText = Color3.fromRGB(10, 12, 18),
	danger = Color3.fromRGB(255, 80, 100),
	radius = 10,
	padding = 10,
} :: Theme

function Ui.setTheme(overrides: { [string]: any })
	local t = table.clone(Ui.theme) :: any
	for k, v in overrides do
		t[k] = v
	end
	Ui.theme = t
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Ui.theme.radius)
	c.Parent = parent
end

-- A ScreenGui in the local player's PlayerGui.
function Ui.screen(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- A rounded panel with padding and a vertical list layout.
function Ui.panel(parent: Instance, options: { size: UDim2?, anchor: string?, name: string? }?): Frame
	local o = options or {}
	local t = Ui.theme
	local frame = Instance.new("Frame")
	frame.Name = o.name or "Panel"
	frame.Size = o.size or UDim2.fromOffset(300, 200)
	frame.BackgroundColor3 = t.panel
	frame.BackgroundTransparency = t.panelTransparency
	frame.BorderSizePixel = 0
	if o.anchor == "center" then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
	end
	corner(frame)
	local pad = Instance.new("UIPadding")
	local p = UDim.new(0, t.padding)
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = p, p, p, p
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, t.padding // 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = parent
	return frame
end

function Ui.label(parent: Instance, text: string, options: { size: number?, muted: boolean? }?): TextLabel
	local o = options or {}
	local t = Ui.theme
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = t.font
	label.Text = text
	label.TextColor3 = if o.muted then t.muted else t.text
	label.TextSize = o.size or 18
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.fromScale(1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- A touch-sized button. `onClick` runs on Activated; the button greys out while it runs, so a
-- double tap cannot send the same request twice.
function Ui.button(parent: Instance, text: string, onClick: () -> (), options: { danger: boolean? }?): TextButton
	local o = options or {}
	local t = Ui.theme
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = if o.danger then t.danger else t.accent
	button.TextColor3 = t.accentText
	button.Font = t.font
	button.TextSize = 18
	button.Text = text
	button.AutoButtonColor = true
	corner(button, t.radius - 2)
	local busy = false
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		button.Active = false
		button.BackgroundTransparency = 0.4
		local ok, err = pcall(onClick)
		if not ok then
			warn(`[Ui] {text}: {err}`)
		end
		button.BackgroundTransparency = 0
		button.Active = true
		busy = false
	end)
	button.Parent = parent
	return button
end

-- A short message at the top of the screen that fades out.
function Ui.toast(screen: ScreenGui, text: string, seconds: number?)
	local t = Ui.theme
	local frame = Instance.new("TextLabel")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.fromOffset(0, 40)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundColor3 = t.panel
	frame.BackgroundTransparency = t.panelTransparency
	frame.Font = t.font
	frame.Text = "  " .. text .. "  "
	frame.TextColor3 = t.text
	frame.TextSize = 18
	corner(frame)
	frame.Parent = screen
	task.delay(seconds or 2.5, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.45)
		frame:Destroy()
	end)
end

return Ui
