--!strict
-- The arena's dusk (decision 0046). Walking into the canyon north of the hub fades the light from the
-- bright hub day to a low, violet dusk with heavier haze, deeper colour and a stronger glow, and walking
-- out fades it back. It changes this player's Lighting only, never anyone else's. Display only.

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
if atmosphere == nil or correction == nil or bloom == nil or rays == nil then
	return
end

-- The hub's light as the server set it, and the arena's.
local DAY = {
	clock = Lighting.ClockTime,
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
local DUSK = {
	clock = 17.4,
	brightness = 1.9,
	ambient = Color3.fromRGB(96, 74, 130),
	outdoor = Color3.fromRGB(130, 100, 164),
	density = 0.38,
	colour = Color3.fromRGB(150, 100, 190),
	decay = Color3.fromRGB(90, 40, 120),
	haze = 2.4,
	glare = 0,
	saturation = 0.02,
	contrast = 0.16,
	tint = Color3.fromRGB(255, 224, 255),
	lift = -0.02,
	bloom = 0.55,
	threshold = 1.4,
	rays = 0,
}

local IN_AT, FULL_AT = 306, 350 -- how far north (studs) the dusk starts and is complete
local blend, shown = 0, -1

local function apply(k: number)
	Lighting.ClockTime = DAY.clock + (DUSK.clock - DAY.clock) * k
	Lighting.Brightness = DAY.brightness + (DUSK.brightness - DAY.brightness) * k
	Lighting.Ambient = DAY.ambient:Lerp(DUSK.ambient, k)
	Lighting.OutdoorAmbient = DAY.outdoor:Lerp(DUSK.outdoor, k)
	atmosphere.Density = DAY.density + (DUSK.density - DAY.density) * k
	atmosphere.Color = DAY.colour:Lerp(DUSK.colour, k)
	atmosphere.Decay = DAY.decay:Lerp(DUSK.decay, k)
	atmosphere.Haze = DAY.haze + (DUSK.haze - DAY.haze) * k
	atmosphere.Glare = DAY.glare + (DUSK.glare - DAY.glare) * k
	correction.Saturation = DAY.saturation + (DUSK.saturation - DAY.saturation) * k
	correction.Contrast = DAY.contrast + (DUSK.contrast - DAY.contrast) * k
	correction.TintColor = DAY.tint:Lerp(DUSK.tint, k)
	correction.Brightness = DAY.lift + (DUSK.lift - DAY.lift) * k
	bloom.Intensity = DAY.bloom + (DUSK.bloom - DAY.bloom) * k
	bloom.Threshold = DAY.threshold + (DUSK.threshold - DAY.threshold) * k
	rays.Intensity = DAY.rays + (DUSK.rays - DAY.rays) * k
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local want = 0
	if root and math.abs(root.Position.X) < 90 and root.Position.Y < 80 then
		want = math.clamp((-root.Position.Z - IN_AT) / (FULL_AT - IN_AT), 0, 1)
		if root.Position.Z < -700 then
			want = 0
		end
	end
	blend += (want - blend) * math.min(1, dt * 2)
	if math.abs(blend - shown) > 0.002 then
		shown = blend
		apply(blend)
	end
end)
