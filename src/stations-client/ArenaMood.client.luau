--!strict
-- The battlefield's light (decisions 0046, 0108). Walking up the road north of the hub towards the Legion's
-- battlefield fades the light from the hub's day to the picture's: a clear early afternoon with the sun
-- behind the teams, so the castle's front is lit, a violet haze on the mountains and nothing blurred in
-- the distance; walking back fades it back. It changes this player's Lighting only, never anyone
-- else's. Display only.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- the effects the world's server script put in Lighting (their names are not their classes')
local function find(class: string): any
	for _ = 1, 60 do
		local e = Lighting:FindFirstChildOfClass(class)
		if e then
			return e
		end
		task.wait(0.5)
	end
	return nil
end
local atmosphere = find("Atmosphere") :: Atmosphere?
local correction = find("ColorCorrectionEffect") :: ColorCorrectionEffect?
local bloom = find("BloomEffect") :: BloomEffect?
local rays = find("SunRaysEffect") :: SunRaysEffect?
local blur = find("DepthOfFieldEffect") :: DepthOfFieldEffect?
if atmosphere == nil or correction == nil or bloom == nil or rays == nil or blur == nil then
	return
end

-- The hub's light as the server set it, and the field's.
local DAY = {
	clock = Lighting.ClockTime,
	latitude = Lighting.GeographicLatitude,
	exposure = Lighting.ExposureCompensation,
	blur = blur.FarIntensity,
	brightness = Lighting.Brightness,
	ambient = Lighting.Ambient,
	outdoor = Lighting.OutdoorAmbient,
	density = atmosphere.Density,
	colour = atmosphere.Color,
	decay = atmosphere.Decay,
	haze = atmosphere.Haze,
	glare = atmosphere.Glare,
	saturation = correction.Saturation,
	contrast = correction.Contrast,
	tint = correction.TintColor,
	lift = correction.Brightness,
	bloom = bloom.Intensity,
	threshold = bloom.Threshold,
	rays = rays.Intensity,
}
local FIELD = {
	clock = 14.4,
	latitude = 60, -- with the clock, this puts the sun behind the teams
	exposure = -0.35,
	blur = 0,
	brightness = 2.2,
	ambient = Color3.fromRGB(104, 96, 124),
	outdoor = Color3.fromRGB(140, 134, 160),
	density = 0.3,
	colour = Color3.fromRGB(205, 190, 255),
	decay = Color3.fromRGB(150, 120, 230),
	haze = 1.4,
	glare = 0.2,
	saturation = 0.08,
	contrast = 0.1,
	tint = Color3.fromRGB(255, 250, 255),
	lift = 0,
	bloom = 0.45,
	threshold = 1.6,
	rays = DAY.rays,
}

local IN_AT, FULL_AT = 290, 420 -- how far north (studs) the field's light starts and is complete
local blend, shown = 0, -1

local function apply(k: number)
	local look = FIELD
	Lighting.GeographicLatitude = DAY.latitude + (look.latitude - DAY.latitude) * k
	Lighting.ExposureCompensation = DAY.exposure + (look.exposure - DAY.exposure) * k
	blur.FarIntensity = DAY.blur + (look.blur - DAY.blur) * k
	Lighting.ClockTime = DAY.clock + (look.clock - DAY.clock) * k
	Lighting.Brightness = DAY.brightness + (look.brightness - DAY.brightness) * k
	Lighting.Ambient = DAY.ambient:Lerp(look.ambient, k)
	Lighting.OutdoorAmbient = DAY.outdoor:Lerp(look.outdoor, k)
	atmosphere.Density = DAY.density + (look.density - DAY.density) * k
	atmosphere.Color = DAY.colour:Lerp(look.colour, k)
	atmosphere.Decay = DAY.decay:Lerp(look.decay, k)
	atmosphere.Haze = DAY.haze + (look.haze - DAY.haze) * k
	atmosphere.Glare = DAY.glare + (look.glare - DAY.glare) * k
	correction.Saturation = DAY.saturation + (look.saturation - DAY.saturation) * k
	correction.Contrast = DAY.contrast + (look.contrast - DAY.contrast) * k
	correction.TintColor = DAY.tint:Lerp(look.tint, k)
	correction.Brightness = DAY.lift + (look.lift - DAY.lift) * k
	bloom.Intensity = DAY.bloom + (look.bloom - DAY.bloom) * k
	bloom.Threshold = DAY.threshold + (look.threshold - DAY.threshold) * k
	rays.Intensity = DAY.rays + (look.rays - DAY.rays) * k
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local want = 0
	if root and math.abs(root.Position.X) < 420 and root.Position.Y < 200 then
		want = math.clamp((-root.Position.Z - IN_AT) / (FULL_AT - IN_AT), 0, 1)
	end
	blend += (want - blend) * math.min(1, dt * 2)
	if math.abs(blend - shown) > 0.002 then
		shown = blend
		apply(blend)
	end
end)
