--!strict
-- Pure screen-fitting numbers for the Animal Stations UI (decision 0044), so phones, tablets and
-- desktops get the same layout at a size that suits them. No Roblox APIs.

local UiLayout = {}

UiLayout.BASE_W, UiLayout.BASE_H = 900, 700 -- a screen this size shows the UI at scale 1
UiLayout.MIN_SCALE, UiLayout.MAX_SCALE = 0.9, 1.2

-- The UI's scale for a screen `width` by `height` pixels: the screen's smaller side against the
-- base, kept between MIN_SCALE and MAX_SCALE. A phone gets the smallest scale (the UI is laid out
-- in about 890 x 400 units in landscape and about 430 x 940 in portrait), a desktop a little more.
function UiLayout.scale(width: number, height: number): number
	local s = math.min(width / UiLayout.BASE_W, height / UiLayout.BASE_H)
	return math.clamp(s, UiLayout.MIN_SCALE, UiLayout.MAX_SCALE)
end

-- How far a portrait camera with field of view `fov` (degrees) must stand from the middle of a
-- creature of `size` {width, height, depth} studs for all of it to be in the picture.
function UiLayout.frameDistance(size: { number }, fov: number): number
	local radius = math.sqrt(size[1] ^ 2 + size[2] ^ 2 + size[3] ^ 2) / 2
	return radius * 0.72 / math.sin(math.rad(fov / 2))
end

return UiLayout
