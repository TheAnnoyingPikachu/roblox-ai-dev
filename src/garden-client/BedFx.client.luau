--!strict
-- Egg Garden egg looks per bed (GDD V7; docs/architecture/garden.md 6.3): the particle, light and
-- Aurora Highlight each egg tier gets while it sits in a bed, read from the bed's `Egg` attribute.
-- Budgets: at most 2 emitters per bed, a light on Moon and above only, the Aurora Highlight only
-- within the shared ClientState.highlights budget, particles off beyond 40 studs from the camera,
-- everything removed when the bed empties. The cart egg is not under a bed, so it gets none of this.
-- Growth scale, ripe glow and wobble stay in HatchFx. Display only: sends nothing.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local camera = Workspace.CurrentCamera
local new = ClientState.new
local RANGE = 40

type Look = { emitters: { ParticleEmitter }, light: PointLight?, highlight: Highlight?, orbit: Attachment? }
type View = { part: BasePart, egg: string, look: Look }
local views: { [Instance]: View } = {} -- by bed model

local function emitter(
	parent: Instance,
	colour: ColorSequence,
	rate: number,
	props: { [string]: any }?
): ParticleEmitter
	local e = new("ParticleEmitter", {
		Color = colour,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.8,
		Rate = rate,
		Parent = parent,
	})
	for k, v in props or {} do
		(e :: any)[k] = v
	end
	return e
end

local function light(part: BasePart, colour: Color3, range: number, brightness: number): PointLight
	return new("PointLight", { Color = colour, Range = range, Brightness = brightness, Parent = part })
end

local CREAM = Color3.fromRGB(255, 240, 200)
local WHITE_GOLD = ClientState.CELESTIAL
local AURORA = { Color3.fromRGB(80, 220, 200), Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 240, 150) }

-- The V7 table, one builder per egg; starter and meadow have no effect.
local BUILD: { [string]: (BasePart, Look) -> () } = {
	forest = function(part, look)
		table.insert(
			look.emitters,
			emitter(part, ColorSequence.new(Color3.fromRGB(150, 200, 90), Color3.fromRGB(110, 150, 60)), 0.5, {
				Lifetime = NumberRange.new(3, 4),
				Size = NumberSequence.new(0.35, 0.2),
				Acceleration = Vector3.new(0.4, -0.6, 0.2),
				RotSpeed = NumberRange.new(-90, 90),
			})
		)
	end,
	sunset = function(part, look)
		table.insert(
			look.emitters,
			emitter(part, ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 140, 170)), 2)
		)
	end,
	moon = function(part, look)
		table.insert(
			look.emitters,
			emitter(
				part,
				ColorSequence.new(CREAM),
				1,
				{ Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0.2, 0.4) }
			)
		)
		look.light = light(part, CREAM, 6, 0.4)
	end,
	star = function(part, look)
		table.insert(look.emitters, emitter(part, ColorSequence.new(ClientState.UI.GOLD, ClientState.UI.WHITE), 3))
		look.light = light(part, ClientState.UI.GOLD, 6, 0.5)
	end,
	celestial = function(part, look)
		-- A ring of motes from an attachment that the loop orbits around the egg.
		local orbit = new("Attachment", { Position = Vector3.new(1.6, 0.4, 0), Parent = part })
		look.orbit = orbit
		table.insert(
			look.emitters,
			emitter(orbit, ColorSequence.new(WHITE_GOLD, ClientState.UI.WHITE), 6, {
				Speed = NumberRange.new(0, 0.1),
				Lifetime = NumberRange.new(0.8, 1.4),
				Size = NumberSequence.new(0.25, 0),
			})
		)
		look.light = light(part, WHITE_GOLD, 8, 0.8)
	end,
	aurora = function(part, look)
		table.insert(look.emitters, emitter(part, ColorSequence.new(AURORA[1], AURORA[2]), 3))
		look.light = light(part, AURORA[1], 8, 0.8)
		if ClientState.highlights + 1 <= ClientState.HIGHLIGHT_BUDGET then
			ClientState.highlights += 1
			local h = new("Highlight", {
				FillColor = AURORA[1],
				FillTransparency = 0.88, -- faint: the egg's texture must read through (owner)
				OutlineColor = AURORA[1],
				OutlineTransparency = 0.4,
				DepthMode = Enum.HighlightDepthMode.Occluded,
				Adornee = part,
				Parent = part,
			})
			h.Destroying:Once(function()
				ClientState.highlights -= 1
			end)
			look.highlight = h
		end
	end,
}

local function drop(bed: Instance)
	local view = views[bed]
	if view == nil then
		return
	end
	views[bed] = nil
	for _, e in view.look.emitters do
		e:Destroy()
	end
	for _, inst in { view.look.light, view.look.highlight, view.look.orbit } do
		if inst then
			inst:Destroy()
		end
	end
end

local function sweep()
	local root = Workspace:FindFirstChild("Garden")
	local plots = root and root:FindFirstChild("Plots")
	local seen: { [Instance]: boolean } = {}
	for _, plot in if plots then plots:GetChildren() else {} do
		local beds = plot:FindFirstChild("Beds")
		for _, bed in if beds then beds:GetChildren() else {} do
			local egg = bed:GetAttribute("Egg")
			local part = bed:FindFirstChild("Egg")
			if type(egg) ~= "string" or egg == "" or not (part and part:IsA("BasePart")) then
				continue
			end
			seen[bed] = true
			local view = views[bed]
			if view and (view.part ~= part or view.egg ~= egg) then
				drop(bed)
				view = nil
			end
			if view == nil then
				local look: Look = { emitters = {}, light = nil, highlight = nil, orbit = nil }
				local build = BUILD[egg]
				if build then
					build(part, look)
				end
				views[bed] = { part = part, egg = egg, look = look }
			end
		end
	end
	for bed in views do
		if not seen[bed] then
			drop(bed)
		end
	end
end

task.spawn(function()
	while true do
		sweep()
		task.wait(0.5)
	end
end)

-- Distance cut-off, the Celestial orbit and the Aurora colour cycle (teal, violet, green over 6 s).
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local eye = camera.CFrame.Position
	local k = (t / 6) % 1 * 3
	local i = math.floor(k) + 1
	local auroraColour = AURORA[i]:Lerp(AURORA[i % 3 + 1], k - math.floor(k))
	for _, view in views do
		local near = (view.part.Position - eye).Magnitude <= RANGE
		for _, e in view.look.emitters do
			if e.Enabled ~= near then
				e.Enabled = near
			end
		end
		if view.look.orbit then
			view.look.orbit.Position =
				Vector3.new(math.cos(t * 2) * 1.6, 0.4 + math.sin(t * 4) * 0.2, math.sin(t * 2) * 1.6)
		end
		if view.egg == "aurora" then
			if view.look.highlight then
				view.look.highlight.FillColor = auroraColour
				view.look.highlight.OutlineColor = auroraColour
			end
			if view.look.light then
				view.look.light.Color = auroraColour
			end
		end
	end
end)
