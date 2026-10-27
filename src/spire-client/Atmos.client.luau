--!strict
-- Neon Spire atmosphere (art bible 3, 7; docs/architecture/spire.md 5): the permanent rainy night
-- (lighting, Atmosphere, Bloom, ColorCorrection, menu depth of field), camera-following rain with
-- ground splashes and a rain loop, the per-event grade (Data Boom tint, Neon Night bloom and rain),
-- and the music: the menu track while the start menu is open, a two-track playlist in play.
-- Lighting.Technology cannot be set from a script; spire.project.json sets it to Future.
-- Every audio ID has a docs/assets/register.md row.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local camera = Workspace.CurrentCamera
local UI = ClientState.UI

-- Lighting recipe "Normal" (art bible 3) ------------------------------------------------------------

Lighting.ClockTime = 0.3
Lighting.Brightness = 1.2
Lighting.Ambient = Color3.fromRGB(20, 18, 40)
Lighting.OutdoorAmbient = Color3.fromRGB(40, 36, 80)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.3
Lighting.FogEnd = 100000

for _, old in Lighting:GetChildren() do
	if old:IsA("PostEffect") or old:IsA("Atmosphere") or old:IsA("Sky") then
		old:Destroy()
	end
end

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = Lighting
	return inst
end

make("Sky", { StarCount = 0, CelestialBodiesShown = false })
make("Atmosphere", {
	Density = 0.38,
	Offset = 0.15,
	Color = Color3.fromRGB(60, 40, 110),
	Decay = Color3.fromRGB(20, 10, 40),
	Glare = 0.2,
	Haze = 2.2,
})
local bloom = make("BloomEffect", { Intensity = 0.9, Size = 28, Threshold = 0.92 })
local grade = make("ColorCorrectionEffect", {
	Contrast = 0.12,
	Saturation = 0.18,
	TintColor = Color3.fromRGB(235, 230, 255),
})
local dof = make("DepthOfFieldEffect", {
	Enabled = false,
	FarIntensity = 0.25,
	FocusDistance = 60,
	InFocusRadius = 40,
	NearIntensity = 0,
})

-- Rain (art bible 7): a box emitter 60 studs above the camera and splashes on the ground below it --

local RAIN_RATE = { high = 600, med = 350, low = 150 }
local folder = ClientState.folder("Atmos")

local function holder(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = folder
	return p
end

local cloud = holder("RainCloud", Vector3.new(120, 1, 120))
local rain = Instance.new("ParticleEmitter")
rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
rain.Shape = Enum.ParticleEmitterShape.Box
rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Orientation = Enum.ParticleOrientation.VelocityParallel
rain.Speed = NumberRange.new(110, 130)
rain.Lifetime = NumberRange.new(0.7, 0.9)
rain.Size = NumberSequence.new(0.12)
rain.Squash = NumberSequence.new(3)
rain.Transparency = NumberSequence.new(0.35)
rain.LightEmission = 0.4
rain.LightInfluence = 0.6
rain.Color = ColorSequence.new(UI.ICE)
rain.Parent = cloud

local puddleLayer = holder("RainSplash", Vector3.new(60, 0.2, 60))
local splash = Instance.new("ParticleEmitter")
splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
splash.Shape = Enum.ParticleEmitterShape.Box
splash.EmissionDirection = Enum.NormalId.Top
splash.Speed = NumberRange.new(3, 6)
splash.Acceleration = Vector3.new(0, -30, 0)
splash.SpreadAngle = Vector2.new(35, 35)
splash.Lifetime = NumberRange.new(0.15, 0.25)
splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05) })
splash.Transparency = NumberSequence.new(0.4)
splash.LightEmission = 0.3
splash.Color = ColorSequence.new(UI.ICE)
splash.Parent = puddleLayer

-- Audio (register rows: APMOfficial music, ProSoundEffects rain) -------------------------------------

local MUSIC = {
	menu = { "rbxassetid://9046476113" }, -- APMOfficial "Cyber Space"
	play = { "rbxassetid://9046475725", "rbxassetid://9046474891" }, -- "Biometric ID", "Cyberpunk Universe"
}
local MUSIC_VOLUME = 0.35

local rainSound = Instance.new("Sound")
rainSound.Name = "RainLoop"
rainSound.SoundId = "rbxassetid://9112855302" -- ProSoundEffects "Rain On Water 3", loop
rainSound.Looped = true
rainSound.Volume = 0
rainSound.Parent = SoundService
rainSound:Play()

local music = Instance.new("Sound")
music.Name = "SpireMusic"
music.Volume = 0
music.Parent = SoundService

local playlist = "" -- "menu" | "play"
local track = 0
local function nextTrack()
	local list = MUSIC[playlist]
	track = track % #list + 1
	music.SoundId = list[track]
	music.TimePosition = 0
	music:Play()
end
music.Ended:Connect(nextTrack)

local fading: Tween? = nil
local function fadeMusic(to: number, seconds: number)
	if fading then
		fading:Cancel()
	end
	fading = TweenService:Create(music, TweenInfo.new(seconds), { Volume = to });
	(fading :: Tween):Play()
end

local function updateMusic()
	local want = if ClientState.menuOpen then "menu" else "play"
	local volume = if ClientState.settings.music then MUSIC_VOLUME else 0
	if want ~= playlist then
		playlist = want
		track = 0
		fadeMusic(0, 0.6)
		task.delay(0.6, function()
			if playlist == want then
				nextTrack()
				fadeMusic(if ClientState.settings.music then MUSIC_VOLUME else 0, 1.5)
			end
		end)
	else
		fadeMusic(volume, 0.5)
	end
end

-- Settings, events and the menu ---------------------------------------------------------------------

local event = "normal"
local function rainRate(): number
	local rate = RAIN_RATE[ClientState.settings.rain] or RAIN_RATE.med
	if ClientState.quality == "low" then
		rate /= 2
	end
	return if event == "neon" then rate * 1.5 else rate
end

local function apply()
	rain.Rate = rainRate()
	splash.Rate = if ClientState.settings.rain == "low" then 30 else 80
	local targetRain = if ClientState.settings.sfx then 0.25 else 0
	TweenService:Create(rainSound, TweenInfo.new(1), { Volume = targetRain }):Play()
	updateMusic()
end

-- Data Boom and Neon Night grade, tweened over 3 s (art bible 3). Flash Sale is amber on the
-- boards and terminals (Fx), not a world tint.
local function applyEvent()
	local now = ClientState.event()
	if now == event then
		return
	end
	event = now
	local info = TweenInfo.new(3)
	TweenService:Create(grade, info, {
		TintColor = if event == "boom" then Color3.fromRGB(220, 255, 230) else Color3.fromRGB(235, 230, 255),
	}):Play()
	TweenService:Create(bloom, info, { Intensity = if event == "neon" then 1.2 else 0.9 }):Play()
	rain.Rate = rainRate()
end

ClientState.SettingsChanged:Connect(apply)
ClientState.QualityChanged:Connect(apply)
ClientState.MenuChanged:Connect(function()
	dof.Enabled = ClientState.menuOpen
	updateMusic()
end)
ClientState.statusValue.Changed:Connect(applyEvent)
dof.Enabled = ClientState.menuOpen
apply()
applyEvent()

-- The rain follows the camera; splashes only when the camera is near the ground.
RunService.RenderStepped:Connect(function()
	local p = camera.CFrame.Position
	cloud.CFrame = CFrame.new(p.X, p.Y + 60, p.Z)
	local low = p.Y < 80
	splash.Enabled = low
	if low then
		puddleLayer.CFrame = CFrame.new(p.X, 0.1, p.Z)
	end
end)
