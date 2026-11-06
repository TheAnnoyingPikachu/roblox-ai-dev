--!strict
-- Egg Garden creature looks (GDD I3, I4 "Life"; docs/architecture/garden.md section 6): idle bob,
-- hop and turn on every creature (local CFrame offsets, no rigs), mutation looks from the `M`
-- attribute layered on the texture (Golden, Moonlit, Rainbow and Celestial Highlights with a
-- SelectionBox fallback past the Highlight budget; Celestial adds a pulsing fill, stars, a glow and
-- a halo), idle cries, hiding a creature while HatchFx reveals it, and ambient life (windmill
-- sails, butterflies, drifting petals). Display only: sends nothing and changes nothing the server owns.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local camera = Workspace.CurrentCamera
local fxFolder = Workspace:WaitForChild("GardenClientFx", 30) or Workspace

-- Followers (FollowerFx) live here; their looks are applied like any creature's, their movement is not.
local followers = Workspace:FindFirstChild("GardenFollowers")
	or ClientState.new("Folder", { Name = "GardenFollowers", Parent = Workspace })

type View = {
	inst: Instance,
	key: string, -- "<owner>:<id>", as ClientState.hidden
	parts: { BasePart },
	base: CFrame,
	written: CFrame,
	phase: number,
	hopAt: number,
	look: Instance?,
	extras: { Instance }, -- emitters, lights and the halo, switched off during a reveal
	mutation: string,
	charm: string,
	flicker: PointLight?, -- Stormy: flashes every few seconds in the frame loop
	flashAt: number,
	follower: boolean, -- moved by FollowerFx, not here
	hidden: boolean,
	nextCry: number, -- os.clock of this creature's next idle cry (6.1)
}
local views: { [Instance]: View } = {}

local function pivot(inst: Instance): CFrame
	return if inst:IsA("BasePart") then inst.CFrame else (inst :: Model):GetPivot()
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	else
		(inst :: Model):PivotTo(cf)
	end
end

local function partsOf(inst: Instance): { BasePart }
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function emitter(parent: Instance, colour: ColorSequence, rate: number): ParticleEmitter
	return ClientState.new("ParticleEmitter", {
		Color = colour,
		Size = NumberSequence.new(0.35, 0),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(0.6, 1.4),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.8,
		Rate = rate,
		Parent = parent,
	})
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
})

-- A billboard above the creature's head, drawn in UI so it needs no asset and always faces the camera.
-- `lift` studs above the top; charms use 3.4 so they sit over the pad tag (Plots: top + 1.3, 46 px).
local function overhead(
	view: View,
	main: BasePart,
	w: number,
	h: number,
	children: { Instance },
	lift: number?
): BillboardGui
	local size = if view.inst:IsA("Model") then view.inst:GetExtentsSize() else main.Size
	return ClientState.new("BillboardGui", {
		Size = UDim2.fromScale(w, h),
		StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.5 + (lift or 1), 0),
		LightInfluence = 0,
		MaxDistance = 160,
		Adornee = main,
		Parent = main,
	}, children)
end

-- A soft ring above the creature (Celestial).
local function halo(view: View, main: BasePart): BillboardGui
	local size = if view.inst:IsA("Model") then view.inst:GetExtentsSize() else main.Size
	return overhead(view, main, math.max(size.X * 0.7, 2), 0.9, {
		ClientState.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			ClientState.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			ClientState.stroke(ClientState.CELESTIAL, 4),
		}),
	})
end

local function blob(pos: UDim2, size: UDim2, colour: Color3): Frame
	return ClientState.new(
		"Frame",
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, BackgroundColor3 = colour },
		{ ClientState.new("UICorner", { CornerRadius = UDim.new(1, 0) }) }
	)
end

-- The part extras attach to: the PrimaryPart, else the largest part by volume (6.2).
local function mainOf(view: View): BasePart?
	local primary = if view.inst:IsA("Model") then view.inst.PrimaryPart else nil
	local best, bestVolume = primary, -1
	for _, p in view.parts do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if primary == nil and v > bestVolume then
			best, bestVolume = p, v
		end
	end
	return best
end

-- A Highlight over the whole creature while `need` are free under the budget, else a SelectionBox.
local function adorn(view: View, fill: Color3, fillT: number, outline: Color3, outlineT: number, need: number): Instance
	if ClientState.highlights + need <= ClientState.HIGHLIGHT_BUDGET then
		ClientState.highlights += 1
		local h = ClientState.new("Highlight", {
			FillColor = fill,
			FillTransparency = fillT,
			OutlineColor = outline,
			OutlineTransparency = outlineT,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Adornee = view.inst,
			Parent = view.inst,
		})
		h.Destroying:Once(function()
			ClientState.highlights -= 1
		end)
		return h
	end
	-- shortcut: fallbacks stay SelectionBoxes after a Highlight frees up; re-check on respawn is enough.
	return ClientState.new("SelectionBox", {
		Color3 = outline,
		SurfaceColor3 = fill,
		SurfaceTransparency = if fill == ClientState.CELESTIAL then 0.9 else 0.85,
		LineThickness = 0.05,
		Transparency = 0.4,
		Adornee = view.inst,
		Parent = view.inst,
	})
end

-- Mutation looks (GDD U8, architecture 6.2), layered on the texture: no mutation changes TextureID,
-- Color or Material. Returns the Highlight or SelectionBox that the frame loop tints, if any.
local function mutationLook(view: View, main: BasePart): Instance?
	local m = view.mutation
	if m == "normal" then
		return nil
	end
	if m == "golden" then
		table.insert(
			view.extras,
			ClientState.new("Sparkles", { SparkleColor = Color3.fromRGB(255, 220, 120), Parent = main })
		)
		-- Golden is the common mutation: it takes a Highlight only while 8 stay free for the rarer looks.
		return adorn(view, Color3.fromRGB(255, 200, 60), 0.5, Color3.fromRGB(255, 230, 140), 0.3, 8)
	end
	local celestial = m == "celestial"
	local fill = if celestial
		then ClientState.CELESTIAL
		elseif m == "moonlit" then Color3.fromRGB(120, 140, 255)
		else Color3.fromRGB(255, 120, 200)
	if celestial then
		local stars = emitter(main, ColorSequence.new(ClientState.UI.GOLD, ClientState.UI.WHITE), 7)
		stars.Size = NumberSequence.new(0.5, 0)
		stars.Lifetime = NumberRange.new(2.2, 3.6)
		stars.Speed = NumberRange.new(0.3, 0.8)
		table.insert(view.extras, stars)
		table.insert(view.extras, halo(view, main))
		table.insert(
			view.extras,
			ClientState.new("PointLight", { Color = fill, Range = 14, Brightness = 1.4, Parent = main })
		)
		return adorn(view, fill, 0.45, fill, 0.2, 1)
	end
	table.insert(
		view.extras,
		emitter(main, if m == "moonlit" then ColorSequence.new(Color3.fromRGB(200, 210, 255)) else RAINBOW, 4)
	)
	return adorn(view, fill, 0.6, fill, 0.3, 1)
end

-- Charm looks (GDD V2.1), layered after the mutation: Frosted frost motes and a pale rim (only when
-- no mutation Highlight is there: one adornment per creature), Blooming petals and a flower on the
-- head, Stormy a dark cloud, sparks and a flickering light. Never a repaint.
local function charmLook(view: View, main: BasePart)
	local c = view.charm
	local colour = ClientState.CHARM_COLOURS[c]
	if colour == nil then
		return
	end
	if c == "frosted" then
		local motes = emitter(main, ColorSequence.new(colour, ClientState.UI.WHITE), 3)
		motes.Speed = NumberRange.new(0.2, 0.5)
		motes.Lifetime = NumberRange.new(1.8, 2.8)
		motes.Acceleration = Vector3.new(0.3, -0.3, 0)
		table.insert(view.extras, motes)
		if view.look == nil then
			view.look = adorn(view, colour, 0.75, colour, 0.35, 1)
		end
	elseif c == "blooming" then
		local petals = emitter(main, ColorSequence.new(colour, Color3.fromRGB(255, 225, 235)), 4)
		petals.Acceleration = Vector3.new(0.8, -1, 0.3)
		petals.Lifetime = NumberRange.new(1.5, 2.5)
		table.insert(view.extras, petals)
		table.insert(
			view.extras,
			overhead(view, main, 0.9, 0.9, {
				blob(UDim2.fromScale(0.5, 0.22), UDim2.fromScale(0.4, 0.4), colour),
				blob(UDim2.fromScale(0.5, 0.78), UDim2.fromScale(0.4, 0.4), colour),
				blob(UDim2.fromScale(0.22, 0.5), UDim2.fromScale(0.4, 0.4), colour),
				blob(UDim2.fromScale(0.78, 0.5), UDim2.fromScale(0.4, 0.4), colour),
				blob(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.36, 0.36), ClientState.UI.GOLD),
			}, 3.4)
		)
	elseif c == "stormy" then
		local sparks = emitter(main, ColorSequence.new(Color3.fromRGB(255, 245, 160), colour), 3)
		sparks.Size = NumberSequence.new(0.18, 0)
		sparks.Lifetime = NumberRange.new(0.25, 0.5)
		sparks.Speed = NumberRange.new(3, 6)
		table.insert(view.extras, sparks)
		table.insert(
			view.extras,
			overhead(view, main, 1.6, 0.7, {
				blob(UDim2.fromScale(0.3, 0.6), UDim2.fromScale(0.45, 0.7), colour),
				blob(UDim2.fromScale(0.55, 0.45), UDim2.fromScale(0.55, 0.9), colour),
				blob(UDim2.fromScale(0.78, 0.62), UDim2.fromScale(0.4, 0.65), colour),
			}, 3.4)
		)
		local light = ClientState.new(
			"PointLight",
			{ Color = Color3.fromRGB(230, 230, 255), Range = 8, Brightness = 0, Parent = main }
		)
		table.insert(view.extras, light)
		view.flicker = light
	end
end

-- Mutation look then charm look; returns the adornment the frame loop tints, if any.
local function applyLook(view: View): Instance?
	local main = mainOf(view)
	if main == nil then
		return nil
	end
	view.look = mutationLook(view, main)
	charmLook(view, main)
	return view.look
end

local function track(inst: Instance)
	if views[inst] or not (inst:IsA("BasePart") or inst:IsA("Model")) then
		return
	end
	local id = tonumber(inst:GetAttribute("Id")) or tonumber(inst.Name)
	local parts = partsOf(inst)
	if id == nil or #parts == 0 then
		return -- a Model whose MeshPart has not replicated yet: the sweep below retries
	end
	local base = pivot(inst)
	local follower = inst.Parent == followers
	local plot = inst.Parent and inst.Parent.Parent
	local owner = if follower then inst:GetAttribute("Owner") else plot and plot:GetAttribute("Owner")
	local view: View = {
		inst = inst,
		key = `{owner or 0}:{id}`,
		parts = parts,
		base = base,
		written = base,
		phase = math.random() * math.pi * 2,
		hopAt = os.clock() + 2 + math.random() * 6,
		look = nil,
		extras = {},
		mutation = tostring(inst:GetAttribute("M") or "normal"),
		charm = tostring(inst:GetAttribute("C") or "none"),
		flicker = nil,
		flashAt = os.clock() + 2 + math.random() * 5,
		follower = follower,
		hidden = false,
		nextCry = os.clock() + 12 + math.random() * 18, -- a full delay, so a refresh is never a chorus
	}
	view.look = applyLook(view)
	views[inst] = view
	inst.Destroying:Once(function()
		views[inst] = nil
	end)
	-- The server may write C after the model replicates: rebuild the looks when it changes.
	inst:GetAttributeChangedSignal("C"):Connect(function()
		view.charm = tostring(inst:GetAttribute("C") or "none")
		for _, extra in view.extras do
			extra:Destroy()
		end
		view.extras = {}
		if view.look then
			view.look:Destroy()
		end
		view.look, view.flicker = nil, nil
		view.look = applyLook(view)
	end)
end

-- New creatures are tracked the moment they replicate so a fresh hatch is hidden before it is seen.
task.spawn(function()
	local root = Workspace:WaitForChild("Garden")
	root.DescendantAdded:Connect(function(inst)
		if inst.Parent and inst.Parent.Name == "Creatures" then
			task.defer(track, inst) -- after the Model's MeshPart has replicated too
		end
	end)
end)
followers.ChildAdded:Connect(function(inst)
	task.defer(track, inst)
end)

-- Backup sweep of Workspace.Garden.Plots.Plot<n>.Creatures (twice a second; cheap at 120 max).
task.spawn(function()
	while true do
		local root = Workspace:FindFirstChild("Garden")
		local plots = root and root:FindFirstChild("Plots")
		for _, plot in if plots then plots:GetChildren() else {} do
			local folder = plot:FindFirstChild("Creatures")
			for _, c in if folder then folder:GetChildren() else {} do
				track(c)
			end
		end
		for inst in views do
			if not inst:IsDescendantOf(Workspace) then
				views[inst] = nil
			end
		end
		task.wait(0.5)
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local eye = camera.CFrame.Position
	for inst, view in views do
		local current = pivot(inst)
		-- The server moved or rebuilt it: take its new spot as the base.
		if
			(current.Position - view.written.Position).Magnitude > 0.01
			or current.LookVector:Dot(view.written.LookVector) < 0.999
		then
			view.base = current
		end
		local hidden = ClientState.hidden[view.key] == true
		if hidden ~= view.hidden then
			view.hidden = hidden
			for _, p in view.parts do
				p.LocalTransparencyModifier = if hidden then 1 else 0
			end
			if view.look then
				(view.look :: any).Enabled = not hidden
			end
			for _, extra in view.extras do
				(extra :: any).Enabled = not hidden
			end
		end
		local celestial = view.mutation == "celestial"
		if view.look and (celestial or view.mutation == "rainbow") and not hidden then
			local hue = if celestial
				then ClientState.CELESTIAL:Lerp(Color3.new(1, 1, 1), 0.5 + math.sin(t * 0.8 + view.phase) * 0.5)
				else Color3.fromHSV((t * 0.25 + view.phase) % 1, 0.55, 1)
			-- Celestial fill breathes 0.45 to 0.7 and back over 2.4 s (U8).
			local pulse = 0.575 + 0.125 * math.sin(2 * math.pi * t / 2.4)
			if view.look:IsA("Highlight") then
				view.look.FillColor = hue
				view.look.OutlineColor = hue
				if celestial then
					view.look.FillTransparency = pulse
				end
			elseif view.look:IsA("SelectionBox") then
				view.look.Color3 = hue
				view.look.SurfaceColor3 = hue
				if celestial then
					view.look.Transparency = pulse
				end
			end
		end
		-- Stormy: a 0.12 s flash every 3 to 8 s (the light is an extra, so a reveal switches it off too).
		local flicker = view.flicker
		if flicker and not hidden then
			if t >= view.flashAt + 0.12 then
				view.flashAt = t + 3 + math.random() * 5
			end
			flicker.Brightness = if t >= view.flashAt then 2.5 else 0
		end
		if view.follower or (view.base.Position - eye).Magnitude > 160 then
			continue
		end
		local bob = math.sin(t * 2 + view.phase) * 0.18
		if t > view.hopAt + 0.45 then
			view.hopAt = t + 3 + math.random() * 6
		end
		local h = if t >= view.hopAt then (t - view.hopAt) / 0.45 else -1
		local hop = if h >= 0 and h <= 1 then math.sin(h * math.pi) * 1.1 else 0
		local turn = math.sin(t * 0.5 + view.phase * 2) * 0.45
		local cf = view.base * CFrame.new(0, bob + hop, 0) * CFrame.Angles(0, turn, 0)
		setPivot(inst, cf)
		view.written = cf
	end
end)

-- Idle cries (GDD U7, architecture 6.1): each creature within 60 studs every 12 to 30 s, at most one
-- cry per 2 s across the garden (ClientState.idleCry), none while hidden for a reveal and none for
-- followers (FollowerFx cries on a hop); out of range it just redraws.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		local eye = camera.CFrame.Position
		for inst, view in views do
			if now < view.nextCry or view.follower then
				continue
			end
			view.nextCry = now + 12 + math.random() * 18
			if not ClientState.hidden[view.key] and (view.base.Position - eye).Magnitude <= 60 then
				ClientState.idleCry(tostring(inst:GetAttribute("S")), view.base.Position)
			end
		end
	end
end)

-- Ambient life ----------------------------------------------------------------------------------------

-- Windmill sails (World.luau; shortcut: found by the name "Sails", switch to a tag if renamed).
local sails: Instance? = nil
local sailsBase: CFrame? = nil
task.spawn(function()
	while sails == nil do
		local root = Workspace:FindFirstChild("Garden")
		local found = root and root:FindFirstChild("Sails", true)
		if found and (found:IsA("BasePart") or found:IsA("Model")) then
			sails = found
			sailsBase = pivot(found)
		end
		task.wait(3)
	end
end)

-- Butterflies wander over the plaza and meadows.
local BUTTERFLY_COLOURS = {
	Color3.fromRGB(255, 170, 200),
	Color3.fromRGB(255, 225, 120),
	Color3.fromRGB(170, 210, 255),
	Color3.fromRGB(200, 170, 255),
	Color3.fromRGB(170, 240, 190),
}
type Butterfly = { wings: { BasePart }, centre: Vector3, seed: number }
local butterflies: { Butterfly } = {}
for i = 1, 16 do
	local angle = i / 16 * math.pi * 2
	local radius = 25 + (i % 4) * 14
	local colour = BUTTERFLY_COLOURS[i % #BUTTERFLY_COLOURS + 1]
	local wings = {}
	for _ = 1, 2 do
		table.insert(
			wings,
			ClientState.new("Part", {
				Size = Vector3.new(0.5, 0.05, 0.6),
				Color = colour,
				Material = Enum.Material.Neon,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Parent = fxFolder,
			})
		)
	end
	table.insert(butterflies, {
		wings = wings,
		centre = Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius),
		seed = i * 7.3,
	})
end

-- Petals drifting down over the valley.
local petalSky = ClientState.new("Part", {
	Name = "PetalSky",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(300, 1, 300),
	Position = Vector3.new(0, 45, 0),
	Parent = fxFolder,
})
ClientState.new("ParticleEmitter", {
	Color = ColorSequence.new(Color3.fromRGB(255, 190, 215), Color3.fromRGB(255, 230, 240)),
	Size = NumberSequence.new(0.35),
	Squash = NumberSequence.new(-0.6),
	Lifetime = NumberRange.new(10, 14),
	Speed = NumberRange.new(2, 4),
	EmissionDirection = Enum.NormalId.Bottom,
	RotSpeed = NumberRange.new(-90, 90),
	Rotation = NumberRange.new(0, 360),
	Acceleration = Vector3.new(1.5, 0, 0.5),
	Rate = 10,
	Parent = petalSky,
})

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local s, base = sails, sailsBase
	if s and base and s.Parent then
		setPivot(s, base * CFrame.Angles(0, 0, t * 0.6))
	end
	for _, b in butterflies do
		local x = math.noise(b.seed, t * 0.15) * 18
		local z = math.noise(b.seed + 50, t * 0.15) * 18
		local y = 2.5 + math.noise(b.seed + 100, t * 0.3) * 2
		local pos = b.centre + Vector3.new(x, y, z)
		local ahead = b.centre
			+ Vector3.new(math.noise(b.seed, t * 0.15 + 0.05) * 18, y, math.noise(b.seed + 50, t * 0.15 + 0.05) * 18)
		local frame = CFrame.lookAt(pos, if (ahead - pos).Magnitude > 0.01 then ahead else pos + Vector3.zAxis)
		local flap = math.sin(t * 18 + b.seed) * 0.9
		b.wings[1].CFrame = frame * CFrame.Angles(0, 0, flap) * CFrame.new(-0.25, 0, 0)
		b.wings[2].CFrame = frame * CFrame.Angles(0, 0, -flap) * CFrame.new(0.25, 0, 0)
	end
end)
