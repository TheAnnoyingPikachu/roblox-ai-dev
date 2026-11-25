--!strict
-- The prompts in the world (STATION-162, SHANNON's pick: "a paper pill with icon and key"). Every prompt is
-- ProximityPrompt Style Custom (the server sets it), so Roblox draws nothing and this draws a paper pill over
-- the thing: the place's icon, the action and the place, and the key cap (a tap circle on a touch screen). A hold
-- fills the pill. A click or a tap on the pill holds it like the key, so a prompt works exactly as before.
-- One part of the HUD: Hud.client.luau loads the parts in order, and HudApp holds what they share.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Style = require(script.Parent:WaitForChild("Style"))
local App: any = require(script.Parent:WaitForChild("HudApp"))
local C = App.C
local player = Players.LocalPlayer

-- What each prompt's tag shows (Style.ICONS); anything else shows the paw.
local ICON_OF: { [string]: string } = {
	RanchMenu = "home",
	EggStorage = "egg",
	Egg = "egg",
	Vendor = "egg",
	Mill = "gift",
	HubGifts = "gift",
	HubTrade = "swap",
	Teleport = "travel",
	WaveGate = "shield",
}
local function iconOf(prompt: ProximityPrompt): string
	for tag, icon in ICON_OF do
		if CollectionService:HasTag(prompt, tag) then
			return icon
		end
	end
	return "paw"
end

local pills: { [ProximityPrompt]: { board: BillboardGui, links: { RBXScriptConnection } } } = {}

local function hide(prompt: ProximityPrompt)
	local shown = pills[prompt]
	pills[prompt] = nil
	if shown then
		for _, link in shown.links do
			link:Disconnect()
		end
		shown.board:Destroy()
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	hide(prompt)
	local board = Instance.new("BillboardGui")
	board.Name, board.AlwaysOnTop, board.Active = "PromptPill", true, true
	board.Size, board.StudsOffset = UDim2.fromOffset(270, 64), Vector3.new(0, 2.6, 0)
	board.Adornee = prompt.Parent :: Instance
	board.Parent = player:WaitForChild("PlayerGui")
	local links: { RBXScriptConnection } = {}
	pills[prompt] = { board = board, links = links }

	local pill = Style.pill(board, UDim2.fromOffset(262, 56), 28)
	pill.Position = UDim2.fromOffset(4, 2)
	-- the hold's progress: the pill's face fills from the left
	local fill = Style.frame(pill, UDim2.fromScale(0, 1), C.accent)
	fill.BackgroundTransparency, fill.ZIndex = 0.55, 1
	Style.round(fill, 28)
	local icon = Style.icon(pill, iconOf(prompt), 40)
	icon.Position, icon.ZIndex = UDim2.fromOffset(10, 8), 3
	local action = Style.text(pill, prompt.ActionText, 17, C.text, UDim2.new(1, -110, 0, 22))
	action.Position, action.TextTruncate, action.ZIndex = UDim2.fromOffset(58, 7), Enum.TextTruncate.AtEnd, 3
	local object = Style.small(pill, prompt.ObjectText, 12, C.muted, UDim2.new(1, -110, 0, 16))
	object.Position, object.TextTruncate, object.ZIndex = UDim2.fromOffset(58, 30), Enum.TextTruncate.AtEnd, 3
	-- the key cap; on a touch screen a tap circle instead (Style.key hides itself there)
	local key = Style.key(pill, prompt.KeyboardKeyCode.Name)
	key.AnchorPoint, key.Position, key.ZIndex = Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, 0), 4
	local tap = Style.frame(pill, UDim2.fromOffset(34, 34), C.accent)
	tap.AnchorPoint, tap.Position, tap.ZIndex, tap.Visible =
		Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0), 4, Style.touch()
	Style.round(tap, 17)
	Style.stroke(tap, C.ink, 2)

	-- a click or a tap on the pill holds the prompt, like its key
	local press = Instance.new("TextButton")
	press.BackgroundTransparency, press.Text, press.ZIndex = 1, "", 6
	press.Size = UDim2.fromScale(1, 1)
	press.Parent = pill
	press.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			prompt:InputHoldBegin()
		end
	end)
	press.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			prompt:InputHoldEnd()
		end
	end)

	local filling: Tween? = nil
	table.insert(
		links,
		prompt.PromptButtonHoldBegan:Connect(function()
			if filling then
				filling:Cancel()
			end
			fill.Size = UDim2.fromScale(0, 1)
			filling = TweenService:Create(
				fill,
				TweenInfo.new(math.max(0.05, prompt.HoldDuration), Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) }
			);
			(filling :: Tween):Play()
		end)
	)
	table.insert(
		links,
		prompt.PromptButtonHoldEnded:Connect(function()
			if filling then
				filling:Cancel()
			end
			fill.Size = UDim2.fromScale(0, 1)
		end)
	)
end)

ProximityPromptService.PromptHidden:Connect(hide)

return nil
