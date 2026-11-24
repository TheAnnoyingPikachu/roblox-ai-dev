--!strict
-- The hatch reveal's card (SHANNON, 2026-11-24: "Reveal card with sound"): the animal's picture over a burst in its
-- rarity's colour, under the HUD's rarity words, with a chime that climbs with the rarity. Display only.

local TweenService = game:GetService("TweenService")

local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Style = require(script.Parent:WaitForChild("Style"))

local RevealCard = {}

local shown: Frame? = nil

-- Show animal `asset` (in its rainbow coat when `rainbow`) on `screen` in `colour`, `big` 0 (common) to 5 (secret),
-- for `seconds`.
function RevealCard.show(
	screen: ScreenGui,
	asset: string,
	rainbow: boolean?,
	colour: Color3,
	big: number,
	seconds: number
)
	if shown then
		shown:Destroy()
	end
	local side = 190 + big * 14
	local card = Instance.new("Frame")
	card.Name, card.BackgroundTransparency, card.AnchorPoint = "RevealCard", 1, Vector2.new(0.5, 0.5)
	card.Position, card.Size, card.ZIndex = UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(side, side), 40
	card.Parent = screen
	shown = card
	-- the burst: rays in the rarity's colour, turning slowly behind the picture
	local rays = Instance.new("Frame")
	rays.BackgroundTransparency, rays.AnchorPoint = 1, Vector2.new(0.5, 0.5)
	rays.Position, rays.Size, rays.ZIndex = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.7, 1.7), 40
	rays.Parent = card
	local spokes = 4 + big -- each spoke is two rays, through the middle, fading at both ends
	for i = 1, spokes do
		local ray = Instance.new("Frame")
		ray.BorderSizePixel, ray.AnchorPoint, ray.BackgroundColor3 = 0, Vector2.new(0.5, 0.5), colour
		ray.Position, ray.Size = UDim2.fromScale(0.5, 0.5), UDim2.new(0, 18 + big * 4, 1, 0)
		ray.Rotation, ray.BackgroundTransparency, ray.ZIndex = i * 180 / spokes, 0.15, 40
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.32, 0.05),
			NumberSequenceKeypoint.new(0.68, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = rays
	end
	TweenService:Create(rays, TweenInfo.new(seconds + 1, Enum.EasingStyle.Linear), { Rotation = 60 }):Play()
	local view = Portrait.new(card, asset, { size = UDim2.fromScale(1, 1), background = colour, rainbow = rainbow })
	view.ZIndex = 41
	local round = view:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0) -- a medallion
	round.Parent = view
	local ring = Instance.new("UIStroke")
	ring.Color, ring.Thickness = colour, 6 + big
	ring.Parent = view
	local pop = Instance.new("UIScale")
	pop.Scale = 0.2
	pop.Parent = card
	TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- the chime: higher for a rarer hatch, a second note from rare up and a third from legendary
	task.spawn(function()
		for note = 1, 1 + math.min(2, big) do
			Style.sound("claim")
			task.wait(0.18)
			if shown ~= card then
				return
			end
			if note == 2 then
				Style.sound("buy")
			end
		end
	end)
	task.delay(seconds, function()
		if shown ~= card then
			return
		end
		TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			:Play()
		task.wait(0.45)
		card:Destroy()
		if shown == card then
			shown = nil
		end
	end)
end

return RevealCard
